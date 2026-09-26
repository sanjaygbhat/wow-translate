"""Decoder for the WoW Translate screen link ("WTL1").

The addon draws one row of 200 coloured squares. Layout (see the addon's
Features/CompanionLink.lua, which is the reference implementation):

  blocks 0-3   sync pattern: magenta, green, magenta, cyan
  blocks 4-7   calibration greys at levels 0, 1, 2, 3
  blocks 8..   data: every square carries 6 bits, 2 bits per colour channel
               (levels 0/85/170/255): seq, length (2 sextets), payload bytes
               packed 3 -> 4 sextets, a 12-bit checksum, then zero padding.

Each payload starts with a message id byte and a part byte
(part_index * 16 + part_count), so one chat message can span several frames.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Iterable, List, Optional, Sequence, Tuple

BLOCKS = 200
HEADER = 8
DATA = BLOCKS - HEADER
MAX_PAYLOAD = ((DATA - 3 - 2) // 4) * 3  # 138
SYNC_LEVELS = [(3, 0, 3), (0, 3, 0), (3, 0, 3), (0, 3, 3)]
SEP = "\x1f"

Level = Tuple[int, int, int]
RGB = Tuple[int, int, int]


def checksum(values: Iterable[int]) -> int:
    s = 0
    for v in values:
        s = (s * 257 + v + 1) % 4093
    return s


@dataclass
class Frame:
    seq: int
    payload: bytes


def decode_levels(levels: Sequence[Level]) -> Optional[Frame]:
    """Decode 200 colour levels (0..3 per channel) into a frame, or None."""
    if len(levels) < BLOCKS:
        return None
    if [tuple(levels[i]) for i in range(4)] != SYNC_LEVELS:
        return None
    for i in range(4):
        if tuple(levels[4 + i]) != (i, i, i):
            return None
    sx = [r * 16 + g * 4 + b for (r, g, b) in levels[HEADER:BLOCKS]]
    seq, length = sx[0], sx[1] * 64 + sx[2]
    if length > MAX_PAYLOAD:
        return None
    out = bytearray()
    k = 3
    while len(out) < length:
        n = (sx[k] << 18) | (sx[k + 1] << 12) | (sx[k + 2] << 6) | sx[k + 3]
        k += 4
        for b in ((n >> 16) & 255, (n >> 8) & 255, n & 255):
            if len(out) < length:
                out.append(b)
    cs = sx[k] * 64 + sx[k + 1]
    if cs != checksum([sx[0], sx[1], sx[2], *out]):
        return None
    if any(sx[k + 2:]):          # torn frame: the rest must be empty
        return None
    return Frame(seq, bytes(out))


def classify(pixels: Sequence[RGB]) -> Optional[List[Level]]:
    """Turn sampled block colours into levels using the calibration greys.

    Works even if the game's gamma or brightness shifted the colours a bit:
    each channel is matched to the nearest of the four measured greys.
    """
    if len(pixels) < BLOCKS:
        return None
    refs = [[pixels[4 + i][ch] for i in range(4)] for ch in range(3)]
    for ch in range(3):
        r = refs[ch]
        if not (r[0] < r[1] < r[2] < r[3]) or r[3] - r[0] < 120:
            return None
    levels: List[Level] = []
    for px in pixels[:BLOCKS]:
        lv = []
        for ch in range(3):
            v = px[ch]
            r = refs[ch]
            best, bestd = 0, abs(v - r[0])
            for i in (1, 2, 3):
                d = abs(v - r[i])
                if d < bestd:
                    best, bestd = i, d
            lv.append(best)
        levels.append((lv[0], lv[1], lv[2]))
    return levels


@dataclass
class ChatMessage:
    kind: str                     # "C" chat, "H" hello, "T" test
    fields: List[str]
    channel: str = ""
    channel_name: str = ""
    author: str = ""
    lang: str = ""
    text: str = ""
    received: float = field(default_factory=time.time)


def parse_message(raw: bytes) -> Optional[ChatMessage]:
    text = raw.decode("utf-8", errors="replace")
    parts = text.split(SEP)
    if len(parts) < 2 or parts[0] != "1":
        return None
    kind = parts[1]
    msg = ChatMessage(kind=kind, fields=parts[2:])
    if kind == "C" and len(parts) >= 7:
        msg.channel, msg.channel_name, msg.author, msg.lang = parts[2], parts[3], parts[4], parts[5]
        msg.text = SEP.join(parts[6:])
    elif kind == "T" and len(parts) >= 3:
        msg.text = parts[2]
    elif kind != "H":
        return None
    return msg


class Assembler:
    """Collects frames into whole messages. Duplicate captures of the same
    frame (same seq) are ignored; half-received messages expire."""

    def __init__(self, timeout: float = 4.0):
        self.last_seq: Optional[int] = None
        self.partial: dict = {}
        self.timeout = timeout

    def feed(self, frame: Frame, now: Optional[float] = None) -> List[ChatMessage]:
        now = time.time() if now is None else now
        if frame.seq == self.last_seq:
            return []
        self.last_seq = frame.seq
        for mid in [m for m, p in self.partial.items() if now - p["t"] > self.timeout]:
            del self.partial[mid]
        if len(frame.payload) < 2:
            return []
        mid, part = frame.payload[0], frame.payload[1]
        idx, count = part >> 4, part & 15
        if count == 0 or idx >= count:
            return []
        chunk = frame.payload[2:]
        if count == 1:
            m = parse_message(chunk)
            return [m] if m else []
        entry = self.partial.get(mid)
        if entry is None or entry["count"] != count:
            entry = {"count": count, "parts": {}, "t": now}
            self.partial[mid] = entry
        entry["parts"][idx] = chunk
        entry["t"] = now
        if len(entry["parts"]) == count:
            del self.partial[mid]
            m = parse_message(b"".join(entry["parts"][i] for i in range(count)))
            return [m] if m else []
        return []
