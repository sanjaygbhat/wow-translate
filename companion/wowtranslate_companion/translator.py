"""Background translation: keeps the window responsive, remembers recent
translations so repeated lines cost nothing, and counts characters sent."""

from __future__ import annotations

import queue
import threading
import time
from collections import OrderedDict
from typing import Callable, Optional, Tuple

from .providers import Provider, ProviderError

# Chat languages the addon can name, mapped to the codes providers use.
ADDON_LANG = {"en": "en", "de": "de", "fr": "fr", "es": "es", "pt": "pt", "ru": "ru",
              "ko": "ko", "ja": "ja", "zh": "zh-Hans"}


def target_from_hello(lang: str, locale: str) -> str:
    """Pick the output language from what the addon told us."""
    if lang == "zh":
        return "zh-Hant" if locale == "zhTW" else "zh-Hans"
    return ADDON_LANG.get(lang, "en")


class Translator:
    def __init__(self, provider: Provider, on_result: Callable, on_error: Callable,
                 count_usage: Callable[[int], None], workers: int = 2):
        self.provider = provider
        self.on_result = on_result
        self.on_error = on_error
        self.count_usage = count_usage
        self.jobs: "queue.Queue[Tuple]" = queue.Queue()
        self.cache: "OrderedDict[Tuple[str, str], Tuple[str, str]]" = OrderedDict()
        self.lock = threading.Lock()
        self.backoff_until = 0.0
        self.stopped = False
        for _ in range(workers):
            threading.Thread(target=self._run, daemon=True).start()

    def set_provider(self, provider: Provider) -> None:
        with self.lock:
            self.provider = provider
            self.cache.clear()

    def submit(self, text: str, target: str, context=None) -> None:
        text = (text or "").strip()
        if not text:
            return
        with self.lock:
            hit = self.cache.get((text, target))
            if hit:
                self.cache.move_to_end((text, target))
        if hit:
            self.on_result(context, text, hit[0], hit[1])
            return
        self.jobs.put((text, target, context))

    def translate_now(self, text: str, target: str) -> Tuple[str, str]:
        """Blocking call used for the reply box and the Test button."""
        result = self.provider.translate([text], target)[0]
        self.count_usage(len(text))
        return result

    def _run(self) -> None:
        while not self.stopped:
            text, target, context = self.jobs.get()
            wait = self.backoff_until - time.time()
            if wait > 0:
                time.sleep(wait)
            try:
                with self.lock:
                    provider = self.provider
                translated, detected = provider.translate([text], target)[0]
                self.count_usage(len(text))
                with self.lock:
                    self.cache[(text, target)] = (translated, detected)
                    while len(self.cache) > 2000:
                        self.cache.popitem(last=False)
                self.on_result(context, text, translated, detected)
            except ProviderError as e:
                if "Too many requests" in str(e):
                    self.backoff_until = time.time() + 5
                self.on_error(context, text, str(e))
            except Exception as e:  # never let a worker die
                self.on_error(context, text, "Unexpected error: %s" % e)
