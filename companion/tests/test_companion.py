"""Companion tests (standard library only):  python -m unittest discover -s companion/tests"""

import json
import os
import random
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from wowtranslate_companion import protocol, providers  # noqa: E402
from wowtranslate_companion.capture import Image, LinkReader, Screen, find_strip, sample_row  # noqa: E402
from wowtranslate_companion.config import Config, protect_key, unprotect_key  # noqa: E402
from wowtranslate_companion.translator import target_from_hello  # noqa: E402

FRAMES_FILE = os.path.join(HERE, "..", "..", "tests", "link_frames.txt")


def encode(seq, payload):
    """Python mirror of CompanionLink.EncodeFrame, used to build test images."""
    blocks = [(3, 0, 3), (0, 3, 0), (3, 0, 3), (0, 3, 3)] + [(i, i, i) for i in range(4)]
    sx = [seq % 64, len(payload) // 64, len(payload) % 64]
    for j in range(0, len(payload), 3):
        b = list(payload[j:j + 3]) + [0, 0]
        n = (b[0] << 16) | (b[1] << 8) | b[2]
        sx += [(n >> 18) & 63, (n >> 12) & 63, (n >> 6) & 63, n & 63]
    cs = protocol.checksum([sx[0], sx[1], sx[2], *payload])
    sx += [cs // 64, cs % 64]
    sx += [0] * (protocol.DATA - len(sx))
    return blocks + [(v >> 4, (v >> 2) & 3, v & 3) for v in sx]


def render(levels, block, width, height, x0, y0, gamma=1.0, order="BGR"):
    """Draw a strip into a fake screenshot (3 bytes per pixel)."""
    stride = width * 3
    buf = bytearray(os.urandom(stride * height))           # noisy background
    for i, (r, g, b) in enumerate(levels):
        rgb = [round(255 * ((v / 3) ** gamma)) for v in (r, g, b)]
        px = bytes(rgb[::-1]) if order == "BGR" else bytes(rgb)
        for yy in range(y0, y0 + block):
            for xx in range(x0 + i * block, x0 + (i + 1) * block):
                o = yy * stride + xx * 3
                buf[o:o + 3] = px
    return bytes(buf), stride


class FakeScreen(Screen):
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.buf, self.stride = bytes(w * h * 3), w * 3

    def show(self, levels, block, x0, y0):
        self.buf, self.stride = render(levels, block, self.w, self.h, x0, y0)

    def bounds(self):
        return 0, 0, self.w, self.h

    def grab(self, x, y, w, h):
        rows = [self.buf[(y + r) * self.stride + x * 3:(y + r) * self.stride + (x + w) * 3] for r in range(h)]
        return b"".join(rows), w * 3


class ProtocolTests(unittest.TestCase):
    def test_lua_frames_decode(self):
        """Frames written by the real Lua encoder (tests/harness.lua) decode here."""
        if not os.path.exists(FRAMES_FILE):
            self.skipTest("run lua5.1 tests/harness.lua first")
        with open(FRAMES_FILE, encoding="utf-8") as f:
            lines = [l.split() for l in f if l.strip()]
        self.assertGreaterEqual(len(lines), 3)
        for parts in lines:
            seq = int(parts[0])
            if len(parts) == 2:           # empty payload: no hex column
                hexs, cells = "", parts[1]
            else:
                hexs, cells = parts[1], parts[2]
            levels = [tuple(int(c) for c in cell) for cell in cells.split(",")]
            frame = protocol.decode_levels(levels)
            self.assertIsNotNone(frame, "frame %d failed to decode" % seq)
            self.assertEqual(frame.seq, seq % 64)
            self.assertEqual(frame.payload, bytes.fromhex(hexs))

    def test_roundtrip_and_corruption(self):
        payload = "Привет, как дела? 你好 👋".encode("utf-8")
        levels = encode(7, payload)
        self.assertEqual(protocol.decode_levels(levels).payload, payload)
        bad = list(levels)
        bad[12] = (3, 3, 3)
        self.assertIsNone(protocol.decode_levels(bad))
        torn = list(levels)
        torn[150] = (1, 0, 0)
        self.assertIsNone(protocol.decode_levels(torn))

    def test_assembler_multipart_and_duplicates(self):
        text = "1\x1fC\x1fWHISPER\x1f\x1fIvan-Forever\x1fru\x1f" + "Привет! " * 60
        raw = text.encode("utf-8")
        chunk = protocol.MAX_PAYLOAD - 2
        parts = [raw[i:i + chunk] for i in range(0, len(raw), chunk)]
        asm = protocol.Assembler()
        got = []
        for i, p in enumerate(parts):
            frame = protocol.Frame(i + 1, bytes([9, i * 16 + len(parts)]) + p)
            got += asm.feed(frame, now=100.0)
            got += asm.feed(frame, now=100.0)      # the same frame captured twice
        self.assertEqual(len(got), 1)
        m = got[0]
        self.assertEqual((m.kind, m.channel, m.author, m.lang), ("C", "WHISPER", "Ivan-Forever", "ru"))
        self.assertTrue(m.text.startswith("Привет!"))

    def test_hello_and_test_messages(self):
        m = protocol.parse_message("1\x1fH\x1f3.0.0\x1fzh\x1fzh\x1fzhTW".encode())
        self.assertEqual(m.kind, "H")
        self.assertEqual(target_from_hello(m.fields[2], m.fields[3]), "zh-Hant")
        self.assertEqual(target_from_hello("zh", "zhCN"), "zh-Hans")
        self.assertEqual(target_from_hello("de", "deDE"), "de")
        self.assertEqual(protocol.parse_message("1\x1fT\x1fhello".encode()).text, "hello")
        self.assertIsNone(protocol.parse_message(b"junk"))


class CaptureTests(unittest.TestCase):
    def test_find_and_read_with_gamma_and_noise(self):
        payload = bytes([3, 0 * 16 + 1]) + "1\x1fT\x1fhello from the addon".encode()
        for block, gamma, order in ((3, 1.0, "BGR"), (2, 1.25, "BGR"), (5, 0.8, "RGB")):
            levels = encode(11, payload)
            w, h = protocol.BLOCKS * block + 400, 120
            buf, stride = render(levels, block, w, h, 137, 40, gamma=gamma, order=order)
            img = Image(buf, stride, w, h, order)
            found = find_strip(img)
            self.assertIsNotNone(found, "strip not found (block %d)" % block)
            col, row, b = found
            self.assertEqual((col, b), (137, block))
            self.assertTrue(40 <= row < 40 + block)
            lv = protocol.classify(sample_row(img, col, row, b))
            frame = protocol.decode_levels(lv)
            self.assertIsNotNone(frame)
            self.assertEqual(frame.payload, payload)

    def test_no_false_positive_on_noise(self):
        random.seed(1)
        w, h = 800, 200
        buf = bytes(random.getrandbits(8) for _ in range(w * h * 3))
        self.assertIsNone(find_strip(Image(buf, w * 3, w, h, "BGR")))

    def test_link_reader_end_to_end(self):
        screen = FakeScreen(1000, 60)
        reader = LinkReader(screen)
        reader.SCAN_INTERVAL = 0
        text = "1\x1fC\x1fCHANNEL\x1f2. Trade\x1fWang\x1fzh\x1f出售亚麻布 5金一组"
        screen.show(encode(1, bytes([1, 0x01]) + text.encode()), 3, 10, 5)
        msgs = reader.poll()                      # finds the strip and reads it
        self.assertEqual(reader.status, "connected")
        self.assertEqual([m.text for m in msgs], ["出售亚麻布 5金一组"])
        self.assertEqual(reader.poll(), [])       # same frame again: ignored
        screen.show(encode(2, b""), 3, 10, 5)      # idle frame
        self.assertEqual(reader.poll(), [])
        self.assertEqual(reader.status, "connected")


class ProviderTests(unittest.TestCase):
    def test_google_free_parse(self):
        raw = json.dumps([[["Hello, ", "Hola, ", None], ["friend", "amigo", None]], None, "es"]).encode()
        self.assertEqual(providers.parse_google_free(raw), ("Hello, friend", "es"))
        with self.assertRaises(providers.ProviderError):
            providers.parse_google_free(b"<html>blocked</html>")

    def test_friendly_errors(self):
        self.assertIn("refused", providers._friendly_http(403, ""))
        self.assertIn("monthly", providers._friendly_http(456, ""))

    def test_missing_keys_are_explained(self):
        with self.assertRaises(providers.ProviderError):
            providers.DeepL("").translate(["hi"], "en")
        with self.assertRaises(providers.ProviderError):
            providers.GoogleCloud("").translate(["hi"], "en")

    def test_deepl_request_shape(self):
        seen = {}

        def fake(url, data=None, headers=None, method=None):
            seen.update(url=url, body=json.loads(data), headers=headers)
            return json.dumps({"translations": [{"detected_source_language": "DE", "text": "Hello"}]}).encode()

        orig = providers._request
        providers._request = fake
        try:
            out = providers.DeepL("abc:fx").translate(["Hallo"], "zh-Hant")
        finally:
            providers._request = orig
        self.assertEqual(out, [("Hello", "de")])
        self.assertIn("api-free.deepl.com", seen["url"])
        self.assertEqual(seen["body"]["target_lang"], "ZH-HANT")
        self.assertEqual(seen["headers"]["Authorization"], "DeepL-Auth-Key abc:fx")


class ConfigTests(unittest.TestCase):
    def test_keys_and_usage(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            cfg = Config(os.path.join(d, "c.json"))
            cfg.set_key("deepl", " secret:fx ")
            cfg.add_usage(120)
            cfg.save()
            cfg2 = Config(os.path.join(d, "c.json"))
            self.assertEqual(cfg2.get_key("deepl"), "secret:fx")
            self.assertEqual(cfg2.usage_this_month(), 120)
        self.assertEqual(unprotect_key(protect_key("k")), "k")


if __name__ == "__main__":
    unittest.main()
