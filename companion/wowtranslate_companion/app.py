"""WoW Translate Companion: the window.

A small always-on-top window that shows accurate translations of the chat
lines the addon sends, plus a box to translate your reply and copy it so you
can paste it into WoW.
"""

from __future__ import annotations

import queue
import threading
import time
import tkinter as tk
import webbrowser
from tkinter import ttk
from typing import Dict, Optional

from . import __version__
from .capture import LinkReader, default_screen
from .config import Config
from .protocol import ChatMessage
from .providers import PROVIDERS, ProviderError, make_provider
from .translator import Translator, target_from_hello

HELP_URL = "https://github.com/sanjaygbhat/wow-translate#accurate-mode"
REPLY_HINT = "Type your reply, press Enter to translate and copy"

BG, PANEL, FG, DIM, ACCENT, ERR = "#15171c", "#1d2027", "#e9e9e9", "#8b8f98", "#33ccff", "#ff6b6b"

CHANNEL_COLORS = {
    "WHISPER": "#ff80ff", "PARTY": "#aaaaff", "RAID": "#ff7f00", "INSTANCE": "#ff7f00",
    "GUILD": "#40ff40", "SAY": "#ffffff", "YELL": "#ff4040", "CHANNEL": "#ffc0a0", "EMOTE": "#ff8040",
}
CHANNEL_NAMES = {
    "WHISPER": "Whisper", "PARTY": "Party", "RAID": "Raid", "INSTANCE": "Instance", "GUILD": "Guild",
    "SAY": "Say", "YELL": "Yell", "CHANNEL": "Channel", "EMOTE": "Emote",
}

# (code, label) for "translate into" and reply choices
LANGUAGES = [
    ("en", "English"), ("de", "Deutsch"), ("fr", "Français"), ("es", "Español"), ("pt", "Português"),
    ("ru", "Русский"), ("ko", "한국어"), ("zh-Hant", "中文 (繁體)"), ("zh-Hans", "中文 (简体)"),
    ("ja", "日本語"), ("it", "Italiano"), ("pl", "Polski"), ("tr", "Türkçe"),
]
LANG_LABEL = dict(LANGUAGES)

PROVIDER_HELP = {
    "deepl": "Most natural translations. Free: 500,000 characters a month with a free DeepL API account, then paid.",
    "google": "Very good. Free: 500,000 characters a month, then about $20 per million characters.",
    "openai": "ChatGPT or any service with the same API (OpenRouter, a local model...). Paid per use.",
    "google_free": "No key needed, good for trying it out. Unofficial and less accurate: it can slow down or stop working.",
}
PROVIDER_ORDER = ["deepl", "google", "openai", "google_free"]


def norm_lang(code: str) -> str:
    c = (code or "").lower()
    if c in ("zh-tw", "zh-hant", "zh_tw"):
        return "zh-Hant"
    if c.startswith("zh"):
        return "zh-Hans"
    return c.split("-")[0]


class App:
    def __init__(self, root: tk.Tk, cfg: Config, demo: bool = False):
        self.root, self.cfg, self.demo = root, cfg, demo
        self.events: "queue.Queue" = queue.Queue()
        self.addon_target: Optional[str] = None
        self.last_lang: Optional[str] = None
        self.line_id = 0
        self.last_error = ("", 0.0)
        self.link_status = "searching"
        self.running = True

        self.translator = Translator(self._provider(), self._result_from_worker, self._error_from_worker,
                                     self._count_usage)
        self._build()
        self._apply_window_prefs()
        self.root.after(40, self._pump)
        self.root.protocol("WM_DELETE_WINDOW", self.quit)

        screen = None if demo else default_screen()
        self.reader = LinkReader(screen) if screen else None
        if self.reader:
            threading.Thread(target=self._read_loop, daemon=True).start()
        elif demo:
            threading.Thread(target=self._demo_loop, daemon=True).start()
        else:
            self._system("Screen reading isn't available on this computer. You can still translate replies below.")

        if cfg["first_run"]:
            self.root.after(300, lambda: self.open_settings(first_run=True))

    # ------------------------------------------------------------------ setup
    def _provider(self):
        pid = self.cfg["provider"]
        return make_provider(pid, self.cfg.get_key(pid), endpoint=self.cfg["openai_endpoint"],
                             model=self.cfg["openai_model"])

    def _target(self) -> str:
        t = self.cfg["target"]
        if t and t != "auto":
            return t
        return self.addon_target or "en"

    def _build(self) -> None:
        r = self.root
        r.title("WoW Translate Companion")
        r.configure(bg=BG)
        r.minsize(360, 220)
        style = ttk.Style(r)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("TCombobox", fieldbackground=PANEL, background=PANEL, foreground=FG, arrowcolor=FG)
        style.map("TCombobox", fieldbackground=[("readonly", PANEL)], foreground=[("readonly", FG)],
                  selectbackground=[("readonly", PANEL)], selectforeground=[("readonly", FG)])
        r.option_add("*TCombobox*Listbox.background", PANEL)
        r.option_add("*TCombobox*Listbox.foreground", FG)

        top = tk.Frame(r, bg=PANEL)
        top.pack(side="top", fill="x")
        self.dot = tk.Canvas(top, width=12, height=12, bg=PANEL, highlightthickness=0)
        self.dot.pack(side="left", padx=(8, 4), pady=6)
        self.dot_item = self.dot.create_oval(2, 2, 11, 11, fill="#888", outline="")
        self.status = tk.Label(top, text="Starting...", bg=PANEL, fg=FG, font=("Segoe UI", 9))
        self.status.pack(side="left")
        for text, cmd in (("⚙ Settings", self.open_settings), ("Clear", self.clear)):
            tk.Button(top, text=text, command=cmd, bg=PANEL, fg=FG, activebackground=BG, activeforeground=ACCENT,
                      relief="flat", bd=0, padx=8, font=("Segoe UI", 9)).pack(side="right", padx=2)

        bottom = tk.Frame(r, bg=PANEL)
        bottom.pack(side="bottom", fill="x")
        row = tk.Frame(bottom, bg=PANEL)
        row.pack(fill="x", padx=6, pady=(6, 2))
        self.reply = tk.Entry(row, bg=BG, fg=FG, insertbackground=FG, relief="flat", font=("Segoe UI", 10))
        self.reply.pack(side="left", fill="x", expand=True, ipady=3)
        self.reply.bind("<Return>", lambda e: self.translate_reply())
        self._placeholder(self.reply, REPLY_HINT)
        choices = ["Their language"] + [label for _, label in LANGUAGES]
        self.reply_lang = ttk.Combobox(row, values=choices, width=14, state="readonly")
        self.reply_lang.set("Their language")
        self.reply_lang.pack(side="left", padx=4)
        tk.Button(row, text="Copy", command=self.translate_reply, bg=ACCENT, fg="#000", relief="flat",
                  padx=10, font=("Segoe UI", 9, "bold")).pack(side="left")
        self.info = tk.Label(bottom, text="", bg=PANEL, fg=DIM, anchor="w", font=("Segoe UI", 8))
        self.info.pack(fill="x", padx=8, pady=(0, 5))

        # Packed last so the reply bar above keeps its space when the window is small.
        body = tk.Frame(r, bg=BG)
        body.pack(side="top", fill="both", expand=True)
        self.text = tk.Text(body, bg=BG, fg=FG, wrap="word", bd=0, highlightthickness=0, padx=8, pady=6,
                            state="disabled", cursor="arrow", width=40, height=8)
        sb = tk.Scrollbar(body, command=self.text.yview)
        self.text.configure(yscrollcommand=sb.set)
        sb.pack(side="right", fill="y")
        self.text.pack(side="left", fill="both", expand=True)
        self._fonts()

    def _fonts(self) -> None:
        size = int(self.cfg["font_size"])
        t = self.text
        t.configure(font=("Segoe UI", size))
        t.tag_configure("orig", foreground=DIM, font=("Segoe UI", max(8, size - 2)))
        t.tag_configure("system", foreground=ACCENT, font=("Segoe UI", max(8, size - 1), "italic"))
        t.tag_configure("error", foreground=ERR, font=("Segoe UI", max(8, size - 1)))
        t.tag_configure("pending", foreground=DIM)
        for ch, color in CHANNEL_COLORS.items():
            t.tag_configure("ch_" + ch, foreground=color)
            t.tag_configure("name_" + ch, foreground=color, font=("Segoe UI", size, "bold"))

    def _placeholder(self, entry: tk.Entry, hint: str) -> None:
        def show(_=None):
            if not entry.get():
                entry.insert(0, hint)
                entry.configure(fg=DIM)
                entry.is_hint = True

        def hide(_=None):
            if getattr(entry, "is_hint", False) or entry.get() == hint:
                entry.delete(0, "end")
                entry.configure(fg=FG)
                entry.is_hint = False

        entry.bind("<FocusIn>", hide)
        entry.bind("<FocusOut>", show)
        show()

    def _apply_window_prefs(self) -> None:
        r = self.root
        try:
            r.attributes("-topmost", bool(self.cfg["on_top"]))
            r.attributes("-alpha", float(self.cfg["opacity"]))
        except tk.TclError:
            pass
        geo = self.cfg["geometry"]
        r.geometry(geo if geo else "440x320")

    # --------------------------------------------------------------- threads
    def _read_loop(self) -> None:
        last_status = None
        while self.running:
            try:
                msgs = self.reader.poll()
            except Exception as e:
                msgs = []
                self.events.put(("status", "error", "Screen reading failed: %s" % e))
                time.sleep(2)
            for m in msgs:
                self.events.put(("msg", m))
            if self.reader.status != last_status:
                last_status = self.reader.status
                self.events.put(("status", last_status, ""))
            time.sleep(0.025)

    def _demo_loop(self) -> None:
        samples = [
            ("CHANNEL", "2. Trade", "Wang", "zh", "出售 [亚麻布] 5金一组，要的密我"),
            ("WHISPER", "", "Ivan", "ru", "Привет! Пойдешь с нами в Мертвые копи? Нам нужен хил."),
            ("PARTY", "", "Klaus", "de", "Moment, ich muss kurz afk, bin gleich wieder da"),
            ("GUILD", "", "Minsu", "ko", "오늘 레이드 몇 시에 시작해요?"),
            ("SAY", "", "Lucia", "es", "¿Alguien sabe dónde está el entrenador de cocina?"),
        ]
        self.events.put(("status", "connected", ""))
        self.events.put(("msg", ChatMessage("H", ["demo", "en", "en", "enUS"])))
        i = 0
        while self.running:
            ch, cname, who, lang, text = samples[i % len(samples)]
            self.events.put(("msg", ChatMessage("C", [], ch, cname, who, lang, text)))
            i += 1
            time.sleep(3)

    def _result_from_worker(self, ctx, text, translated, detected) -> None:
        self.events.put(("result", ctx, text, translated, detected))

    def _error_from_worker(self, ctx, text, err) -> None:
        self.events.put(("error", ctx, text, err))

    def _count_usage(self, chars: int) -> None:
        self.events.put(("usage", chars))

    # ------------------------------------------------------------ main loop
    def _pump(self) -> None:
        try:
            while True:
                ev = self.events.get_nowait()
                kind = ev[0]
                if kind == "msg":
                    self._on_message(ev[1])
                elif kind == "result":
                    self._on_result(*ev[1:])
                elif kind == "error":
                    self._on_error(*ev[1:])
                elif kind == "status":
                    self._on_status(ev[1], ev[2])
                elif kind == "usage":
                    self.cfg.add_usage(ev[1])
                elif kind == "reply_ok":
                    self._reply_ok(ev[1])
                elif kind == "reply_err":
                    self.info.configure(text=ev[1], fg=ERR)
                elif kind == "call":
                    try:
                        ev[1]()
                    except tk.TclError:
                        pass          # the window it wanted to update was closed
        except queue.Empty:
            pass
        if self.running:
            self.root.after(40, self._pump)

    def _on_status(self, status: str, detail: str) -> None:
        self.link_status = status
        colors = {"connected": "#3ddc84", "searching": "#f0b429", "lost": "#f0b429", "error": ERR}
        texts = {
            "connected": "Connected to WoW",
            "searching": "Looking for WoW... (turn on Accurate mode in the addon: /wt accurate)",
            "lost": "Lost the link. Is WoW visible and in Accurate mode?",
            "error": detail or "Error",
        }
        self.dot.itemconfigure(self.dot_item, fill=colors.get(status, "#888"))
        self.status.configure(text=texts.get(status, status))

    def _append(self, parts, see=True) -> None:
        t = self.text
        t.configure(state="normal")
        for text, tags in parts:
            t.insert("end", text, tags)
        lines = int(t.index("end-1c").split(".")[0])
        if lines > 600:
            t.delete("1.0", "%d.0" % (lines - 500))
        t.configure(state="disabled")
        if see:
            t.see("end")

    def _system(self, text: str, tag: str = "system") -> None:
        self._append([(text + "\n", (tag,))])

    def _on_message(self, m: ChatMessage) -> None:
        if m.kind == "H":
            lang = m.fields[1] if len(m.fields) > 1 else "en"
            target = m.fields[2] if len(m.fields) > 2 else lang
            locale = m.fields[3] if len(m.fields) > 3 else ""
            self.addon_target = target_from_hello(target, locale)
            self._system("Connected to the WoW Translate addon %s. Translating into %s."
                         % (m.fields[0] if m.fields else "", LANG_LABEL.get(self._target(), self._target())))
            return
        if m.kind == "T":
            self._system("✓ Test message received from the addon: the link works!")
            m.channel, m.author = "SAY", "WoW Translate"
        if m.lang:
            self.last_lang = norm_lang(m.lang)
        self.line_id += 1
        tag = "line%d" % self.line_id
        ch = m.channel if m.channel in CHANNEL_COLORS else "SAY"
        label = m.channel_name or CHANNEL_NAMES.get(ch, ch)
        parts = [("[%s] " % label, ("ch_" + ch,)), ("%s: " % (m.author.split("-")[0] or "?"), ("name_" + ch,)),
                 ("translating...", ("pending", tag + "_t")), ("\n", ())]
        if self.cfg["show_original"]:
            parts.append(("   " + m.text + "\n", ("orig",)))
        self._append(parts)
        self.translator.submit(m.text, self._target(), context=(tag, ch))

    def _replace_pending(self, ctx, new_text: str, tags) -> None:
        tag = ctx[0] + "_t"
        t = self.text
        rng = t.tag_ranges(tag)
        if not rng:
            return
        t.configure(state="normal")
        t.delete(rng[0], rng[1])
        t.insert(rng[0], new_text, tags)
        t.configure(state="disabled")
        t.see("end")

    def _on_result(self, ctx, text, translated, detected) -> None:
        if detected:
            self.last_lang = norm_lang(detected)
        if isinstance(ctx, tuple):
            self._replace_pending(ctx, translated, ())

    def _on_error(self, ctx, text, err) -> None:
        if isinstance(ctx, tuple):
            self._replace_pending(ctx, text, ("orig",))
        last, when = self.last_error
        if err != last or time.time() - when > 20:
            self.last_error = (err, time.time())
            self._system(err, "error")

    # --------------------------------------------------------------- actions
    def clear(self) -> None:
        self.text.configure(state="normal")
        self.text.delete("1.0", "end")
        self.text.configure(state="disabled")

    def _reply_target(self) -> Optional[str]:
        choice = self.reply_lang.get()
        for code, label in LANGUAGES:
            if label == choice:
                return code
        return self.last_lang if self.last_lang and self.last_lang != self._target() else None

    def translate_reply(self) -> None:
        text = self.reply.get().strip()
        if not text or text == REPLY_HINT:
            return
        target = self._reply_target()
        if not target:
            self.info.configure(text="Pick a language on the right (nobody has written in another language yet).", fg=ERR)
            return
        self.info.configure(text="Translating...", fg=DIM)

        # Worker threads never touch Tk: results go through the event queue.
        def work():
            try:
                out, _ = self.translator.translate_now(text, target)
                self.events.put(("reply_ok", out))
            except ProviderError as e:
                self.events.put(("reply_err", str(e)))
            except Exception as e:
                self.events.put(("reply_err", "Unexpected error: %s" % e))

        threading.Thread(target=work, daemon=True).start()

    def _reply_ok(self, out: str) -> None:
        self.root.clipboard_clear()
        self.root.clipboard_append(out)
        self.info.configure(text="Copied! In WoW press Enter, then Ctrl+V to paste:  " + out, fg="#3ddc84")
        self.reply.delete(0, "end")

    def quit(self) -> None:
        self.running = False
        try:
            self.cfg["geometry"] = self.root.geometry()
            self.cfg.save()
        except Exception:
            pass
        self.root.destroy()

    # -------------------------------------------------------------- settings
    def open_settings(self, first_run: bool = False) -> None:
        SettingsDialog(self, first_run)


class SettingsDialog:
    def __init__(self, app: App, first_run: bool):
        self.app, cfg = app, app.cfg
        self.win = w = tk.Toplevel(app.root)
        w.title("Settings - WoW Translate Companion")
        w.configure(bg=BG, padx=14, pady=10)
        w.transient(app.root)
        try:
            w.attributes("-topmost", True)
        except tk.TclError:
            pass

        def label(parent, text, **kw):
            return tk.Label(parent, text=text, bg=BG, fg=kw.pop("fg", FG), justify="left", anchor="w", **kw)

        if first_run:
            label(w, "Welcome! Pick the service that will translate chat for you.\n"
                     "You can change this at any time.", fg=ACCENT, font=("Segoe UI", 10, "bold")).pack(fill="x", pady=(0, 8))

        label(w, "Translation service", font=("Segoe UI", 10, "bold")).pack(fill="x")
        self.provider = tk.StringVar(value=cfg["provider"])
        for pid in PROVIDER_ORDER:
            f = tk.Frame(w, bg=BG)
            f.pack(fill="x", pady=1)
            tk.Radiobutton(f, text=PROVIDERS[pid].name, variable=self.provider, value=pid, command=self._refresh,
                           bg=BG, fg=FG, selectcolor=PANEL, activebackground=BG, activeforeground=ACCENT,
                           bd=0, highlightthickness=0, font=("Segoe UI", 9, "bold")).pack(anchor="w")
            label(f, PROVIDER_HELP[pid], fg=DIM, wraplength=420, font=("Segoe UI", 8)).pack(fill="x", padx=24)

        self.keyrow = tk.Frame(w, bg=BG)
        self.keyrow.pack(fill="x", pady=(8, 0))
        label(self.keyrow, "API key:").pack(side="left")
        self.key = tk.Entry(self.keyrow, show="•", bg=PANEL, fg=FG, insertbackground=FG, relief="flat", width=40,
                            disabledbackground=BG, disabledforeground=DIM)
        self.key.pack(side="left", padx=6, fill="x", expand=True)
        self.showkey = tk.BooleanVar(value=False)
        tk.Checkbutton(self.keyrow, text="show", variable=self.showkey, bg=BG, fg=DIM, selectcolor=PANEL,
                       activebackground=BG, bd=0, highlightthickness=0, command=lambda: self.key.configure(show="" if self.showkey.get() else "•")
                       ).pack(side="left")
        link = label(w, "Where do I get a key? (opens the guide)", fg=ACCENT, cursor="hand2", font=("Segoe UI", 8, "underline"))
        link.pack(fill="x")
        link.bind("<Button-1>", lambda e: webbrowser.open(HELP_URL))

        self.airow = tk.Frame(w, bg=BG)
        label(self.airow, "Address:").grid(row=0, column=0, sticky="w")
        self.endpoint = tk.Entry(self.airow, bg=PANEL, fg=FG, insertbackground=FG, relief="flat", width=44)
        self.endpoint.grid(row=0, column=1, sticky="we", padx=6, pady=1)
        self.endpoint.insert(0, cfg["openai_endpoint"])
        label(self.airow, "Model:").grid(row=1, column=0, sticky="w")
        self.model = tk.Entry(self.airow, bg=PANEL, fg=FG, insertbackground=FG, relief="flat", width=44)
        self.model.grid(row=1, column=1, sticky="we", padx=6, pady=1)
        self.model.insert(0, cfg["openai_model"])

        label(w, "Translate chat into", font=("Segoe UI", 10, "bold")).pack(fill="x", pady=(10, 0))
        self.target = ttk.Combobox(w, state="readonly", width=30,
                                   values=["Same as my game (auto)"] + [l for _, l in LANGUAGES])
        cur = cfg["target"]
        self.target.set(LANG_LABEL.get(cur, "Same as my game (auto)"))
        self.target.pack(anchor="w")

        label(w, "Window", font=("Segoe UI", 10, "bold")).pack(fill="x", pady=(10, 0))
        opts = tk.Frame(w, bg=BG)
        opts.pack(fill="x")
        self.show_orig = tk.BooleanVar(value=bool(cfg["show_original"]))
        self.on_top = tk.BooleanVar(value=bool(cfg["on_top"]))
        for text, var in (("Show the original text under each translation", self.show_orig),
                          ("Keep this window on top of the game", self.on_top)):
            tk.Checkbutton(opts, text=text, variable=var, bg=BG, fg=FG, selectcolor=PANEL, activebackground=BG,
                           bd=0, highlightthickness=0).pack(anchor="w")
        sizes = tk.Frame(opts, bg=BG)
        sizes.pack(fill="x")
        label(sizes, "Text size").pack(side="left")
        self.font = tk.Spinbox(sizes, from_=8, to=20, width=4, bg=PANEL, fg=FG, buttonbackground=PANEL)
        self.font.delete(0, "end")
        self.font.insert(0, str(cfg["font_size"]))
        self.font.pack(side="left", padx=6)
        label(sizes, "See-through").pack(side="left", padx=(12, 0))
        self.alpha = tk.Scale(sizes, from_=40, to=100, orient="horizontal", showvalue=False, length=120,
                              bg=BG, fg=FG, troughcolor=PANEL, highlightthickness=0)
        self.alpha.set(int(float(cfg["opacity"]) * 100))
        self.alpha.pack(side="left")

        self.usage = label(w, "", fg=DIM, font=("Segoe UI", 8))
        self.usage.pack(fill="x", pady=(10, 0))
        self.result = label(w, "", fg=DIM, wraplength=440, font=("Segoe UI", 9))
        self.result.pack(fill="x", pady=(4, 0))

        btns = tk.Frame(w, bg=BG)
        btns.pack(fill="x", pady=(10, 0))
        tk.Button(btns, text="Test", command=self.test, bg=PANEL, fg=FG, relief="flat", padx=12).pack(side="left")
        tk.Button(btns, text="Save", command=self.save, bg=ACCENT, fg="#000", relief="flat", padx=16,
                  font=("Segoe UI", 9, "bold")).pack(side="right")
        tk.Button(btns, text="Cancel", command=w.destroy, bg=PANEL, fg=FG, relief="flat", padx=12).pack(side="right", padx=6)
        self._refresh()

    def _refresh(self) -> None:
        pid = self.provider.get()
        cls = PROVIDERS[pid]
        self.key.delete(0, "end")
        self.key.insert(0, self.app.cfg.get_key(pid))
        state = "normal" if cls.needs_key or pid == "openai" else "disabled"
        self.key.configure(state=state)
        if pid == "openai":
            self.airow.pack(fill="x", pady=(4, 0), after=self.keyrow)
        else:
            self.airow.pack_forget()
        used = self.app.cfg.usage_this_month()
        self.usage.configure(text="Sent for translation this month: {:,} characters".format(used))

    def _collect(self):
        pid = self.provider.get()
        return pid, self.key.get().strip()

    def test(self) -> None:
        pid, key = self._collect()
        provider = make_provider(pid, key, endpoint=self.endpoint.get().strip(), model=self.model.get().strip())
        self.result.configure(text="Testing...", fg=DIM)

        def work():
            try:
                out, _ = provider.translate(["¡Hola! ¿Quieres ir a la mazmorra con nosotros?"], "en")[0]
                msg, color = "It works! \"%s\"" % out, "#3ddc84"
            except ProviderError as e:
                msg, color = str(e), ERR
            except Exception as e:
                msg, color = "Unexpected error: %s" % e, ERR
            self.app.events.put(("call", lambda: self.result.configure(text=msg, fg=color)))

        threading.Thread(target=work, daemon=True).start()

    def save(self) -> None:
        cfg = self.app.cfg
        pid, key = self._collect()
        cfg["provider"] = pid
        if PROVIDERS[pid].needs_key or pid == "openai":
            cfg.set_key(pid, key)
        cfg["openai_endpoint"] = self.endpoint.get().strip() or cfg["openai_endpoint"]
        cfg["openai_model"] = self.model.get().strip() or cfg["openai_model"]
        choice = self.target.get()
        cfg["target"] = next((c for c, l in LANGUAGES if l == choice), "auto")
        cfg["show_original"] = bool(self.show_orig.get())
        cfg["on_top"] = bool(self.on_top.get())
        try:
            cfg["font_size"] = max(8, min(20, int(self.font.get())))
        except ValueError:
            pass
        cfg["opacity"] = max(0.4, min(1.0, self.alpha.get() / 100.0))
        cfg["first_run"] = False
        cfg.save()
        self.app.translator.set_provider(self.app._provider())
        self.app._fonts()
        self.app._apply_window_prefs()
        self.app._system("Settings saved. Using %s." % PROVIDERS[pid].name)
        self.win.destroy()


def run(demo: bool = False, config_path: str = "") -> None:
    root = tk.Tk()
    App(root, Config(config_path), demo=demo)
    root.mainloop()
