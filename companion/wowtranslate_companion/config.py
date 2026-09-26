"""Settings file for the companion app.

API keys are encrypted with Windows' own per-user protection (DPAPI) when it
is available, so the file is useless to anyone else who copies it. Elsewhere
they are stored as plain text in a file only you can read.
"""

from __future__ import annotations

import base64
import json
import os
import sys
import time
from typing import Any, Dict

DEFAULTS: Dict[str, Any] = {
    "provider": "google_free",
    "keys": {},                 # provider id -> (protected) key
    "openai_endpoint": "https://api.openai.com/v1/chat/completions",
    "openai_model": "gpt-4.1-mini",
    "target": "auto",           # "auto" = language the addon reports, else a code
    "reply_lang": "auto",
    "show_original": True,
    "font_size": 11,
    "opacity": 0.92,
    "on_top": True,
    "geometry": "",
    "usage": {},                # "YYYY-MM" -> characters sent
    "first_run": True,
}


def config_dir() -> str:
    if sys.platform == "win32":
        base = os.environ.get("APPDATA") or os.path.expanduser("~")
        return os.path.join(base, "WoWTranslateCompanion")
    if sys.platform == "darwin":
        return os.path.expanduser("~/Library/Application Support/WoWTranslateCompanion")
    return os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "wowtranslate-companion")


def _dpapi(data: bytes, protect: bool) -> bytes:
    import ctypes
    from ctypes import wintypes

    class BLOB(ctypes.Structure):
        _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]

    crypt32, kernel32 = ctypes.windll.crypt32, ctypes.windll.kernel32
    src = BLOB(len(data), ctypes.cast(ctypes.create_string_buffer(data, len(data)), ctypes.POINTER(ctypes.c_char)))
    dst = BLOB()
    fn = crypt32.CryptProtectData if protect else crypt32.CryptUnprotectData
    ok = fn(ctypes.byref(src), None, None, None, None, 0, ctypes.byref(dst))
    if not ok:
        raise OSError("DPAPI failed")
    try:
        return ctypes.string_at(dst.pbData, dst.cbData)
    finally:
        kernel32.LocalFree(dst.pbData)


def protect_key(key: str) -> str:
    if not key:
        return ""
    if sys.platform == "win32":
        try:
            return "dpapi:" + base64.b64encode(_dpapi(key.encode("utf-8"), True)).decode("ascii")
        except Exception:
            pass
    return "plain:" + key


def unprotect_key(stored: str) -> str:
    if not stored:
        return ""
    if stored.startswith("dpapi:"):
        try:
            return _dpapi(base64.b64decode(stored[6:]), False).decode("utf-8")
        except Exception:
            return ""
    if stored.startswith("plain:"):
        return stored[6:]
    return stored


class Config:
    def __init__(self, path: str = ""):
        self.path = path or os.path.join(config_dir(), "config.json")
        self.data: Dict[str, Any] = json.loads(json.dumps(DEFAULTS))
        self.load()

    def load(self) -> None:
        try:
            with open(self.path, "r", encoding="utf-8") as f:
                stored = json.load(f)
            if isinstance(stored, dict):
                self.data.update(stored)
        except (OSError, ValueError):
            pass

    def save(self) -> None:
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self.data, f, ensure_ascii=False, indent=2)
        os.replace(tmp, self.path)
        if sys.platform != "win32":
            try:
                os.chmod(self.path, 0o600)
            except OSError:
                pass

    def __getitem__(self, k: str) -> Any:
        return self.data.get(k, DEFAULTS.get(k))

    def __setitem__(self, k: str, v: Any) -> None:
        self.data[k] = v

    def get_key(self, provider: str) -> str:
        return unprotect_key(self.data.get("keys", {}).get(provider, ""))

    def set_key(self, provider: str, key: str) -> None:
        self.data.setdefault("keys", {})[provider] = protect_key(key.strip())

    def add_usage(self, chars: int) -> None:
        month = time.strftime("%Y-%m")
        usage = self.data.setdefault("usage", {})
        usage[month] = int(usage.get(month, 0)) + int(chars)

    def usage_this_month(self) -> int:
        return int(self.data.get("usage", {}).get(time.strftime("%Y-%m"), 0))
