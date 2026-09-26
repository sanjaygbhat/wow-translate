"""Translation services.

Every provider takes a list of texts and returns a list of
(translated_text, detected_language) pairs. Only the Python standard library
is used, so the app has no extra dependencies.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Dict, List, Optional, Tuple

USER_AGENT = "WoWTranslateCompanion/3.0"
TIMEOUT = 12

Result = Tuple[str, str]


class ProviderError(Exception):
    """A problem worth showing to the player, in plain words."""


def _request(url: str, data: Optional[bytes] = None, headers: Optional[Dict[str, str]] = None,
             method: Optional[str] = None) -> bytes:
    h = {"User-Agent": USER_AGENT}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", "replace")[:300]
        except Exception:
            pass
        raise ProviderError(_friendly_http(e.code, body)) from None
    except urllib.error.URLError as e:
        raise ProviderError("Can't reach the translation service. Check your internet connection. (%s)" % e.reason) from None
    except TimeoutError:
        raise ProviderError("The translation service took too long to answer.") from None


def _friendly_http(code: int, body: str) -> str:
    if code in (401, 403):
        return "Your API key was refused. Check that it is copied correctly and that the service is enabled."
    if code == 456:
        return "Your monthly free amount is used up (DeepL). Translations resume next month, or upgrade your plan."
    if code == 429:
        return "Too many requests. Slowing down for a moment."
    if code == 400:
        return "The service rejected the request (%s)." % body[:120]
    if 500 <= code < 600:
        return "The translation service is having problems right now (error %d)." % code
    return "Translation failed (error %d)." % code


class Provider:
    id = "base"
    name = "Base"
    needs_key = True

    def __init__(self, key: str = "", **options: str):
        self.key = (key or "").strip()
        self.options = options

    def translate(self, texts: List[str], target: str) -> List[Result]:
        raise NotImplementedError


# Our language codes: en de fr es pt ru ko ja zh-Hans zh-Hant it pl tr ...

class DeepL(Provider):
    id = "deepl"
    name = "DeepL"
    TARGETS = {"en": "EN-US", "pt": "PT-BR", "zh-Hans": "ZH-HANS", "zh-Hant": "ZH-HANT", "zh": "ZH"}

    def translate(self, texts: List[str], target: str) -> List[Result]:
        if not self.key:
            raise ProviderError("Add your DeepL API key in Settings.")
        host = "api-free.deepl.com" if self.key.endswith(":fx") else "api.deepl.com"
        body = json.dumps({
            "text": texts,
            "target_lang": self.TARGETS.get(target, target.upper()),
            "preserve_formatting": True,
        }).encode("utf-8")
        raw = _request("https://%s/v2/translate" % host, body, {
            "Authorization": "DeepL-Auth-Key " + self.key,
            "Content-Type": "application/json",
        })
        data = json.loads(raw)
        return [(t.get("text", ""), (t.get("detected_source_language") or "").lower())
                for t in data.get("translations", [])]


class GoogleCloud(Provider):
    id = "google"
    name = "Google Cloud Translation"
    TARGETS = {"zh-Hans": "zh-CN", "zh-Hant": "zh-TW", "zh": "zh-CN"}

    def translate(self, texts: List[str], target: str) -> List[Result]:
        if not self.key:
            raise ProviderError("Add your Google Cloud API key in Settings.")
        url = "https://translation.googleapis.com/language/translate/v2?key=" + urllib.parse.quote(self.key)
        body = json.dumps({"q": texts, "target": self.TARGETS.get(target, target), "format": "text"}).encode("utf-8")
        raw = _request(url, body, {"Content-Type": "application/json"})
        data = json.loads(raw)
        out = []
        for t in data.get("data", {}).get("translations", []):
            out.append((t.get("translatedText", ""), (t.get("detectedSourceLanguage") or "").lower()))
        return out


LANG_NAMES = {
    "en": "English", "de": "German", "fr": "French", "es": "Spanish", "pt": "Brazilian Portuguese",
    "ru": "Russian", "ko": "Korean", "ja": "Japanese", "zh-Hans": "Simplified Chinese",
    "zh-Hant": "Traditional Chinese", "zh": "Chinese", "it": "Italian", "pl": "Polish", "tr": "Turkish",
}

SYSTEM_PROMPT = (
    "You translate World of Warcraft chat messages into {lang}. Write it the way a player would say it. "
    "Keep gamer terms that players use as-is (LFG, LFM, WTS, WTB, DPS, AFK, GG), keep anything in "
    "[square brackets], player names and numbers unchanged. Reply with only the translation, nothing else."
)


class OpenAICompatible(Provider):
    id = "openai"
    name = "OpenAI-compatible (ChatGPT, OpenRouter, local models)"

    def translate(self, texts: List[str], target: str) -> List[Result]:
        endpoint = self.options.get("endpoint") or "https://api.openai.com/v1/chat/completions"
        model = self.options.get("model") or "gpt-4.1-mini"
        headers = {"Content-Type": "application/json"}
        if self.key:
            headers["Authorization"] = "Bearer " + self.key
        out = []
        for text in texts:
            body = json.dumps({
                "model": model,
                "temperature": 0,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT.format(lang=LANG_NAMES.get(target, target))},
                    {"role": "user", "content": text},
                ],
            }).encode("utf-8")
            data = json.loads(_request(endpoint, body, headers))
            try:
                content = data["choices"][0]["message"]["content"]
            except (KeyError, IndexError, TypeError):
                raise ProviderError("The AI service sent back an answer I couldn't read.") from None
            out.append((content.strip(), ""))
        return out


class GoogleFree(Provider):
    """Google's public web endpoint. No key, but unofficial: it can be slow,
    rate limited, or stop working at any time."""
    id = "google_free"
    name = "Google (free, no key, unofficial)"
    needs_key = False
    TARGETS = {"zh-Hans": "zh-CN", "zh-Hant": "zh-TW", "zh": "zh-CN"}

    def translate(self, texts: List[str], target: str) -> List[Result]:
        out = []
        for text in texts:
            q = urllib.parse.urlencode({"client": "gtx", "sl": "auto", "tl": self.TARGETS.get(target, target),
                                        "dt": "t", "q": text})
            raw = _request("https://translate.googleapis.com/translate_a/single?" + q)
            out.append(parse_google_free(raw))
        return out


def parse_google_free(raw: bytes) -> Result:
    try:
        data = json.loads(raw)
        text = "".join(seg[0] for seg in data[0] if seg and seg[0])
        detected = data[2] if len(data) > 2 and isinstance(data[2], str) else ""
        return text, detected.lower()
    except Exception:
        raise ProviderError("The free Google service sent back something unexpected. It may be blocked right now.") from None


PROVIDERS = {cls.id: cls for cls in (DeepL, GoogleCloud, OpenAICompatible, GoogleFree)}


def make_provider(provider_id: str, key: str = "", **options: str) -> Provider:
    cls = PROVIDERS.get(provider_id) or GoogleFree
    return cls(key, **options)
