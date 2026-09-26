"""Reading the addon's colour strip from the screen.

Only the screen image is read (the same thing a screenshot or a streaming app
reads). Nothing touches the game process: no memory reading, no injection,
no key presses.

Windows uses GDI through ctypes (no extra packages). Other systems fall back
to Pillow's ImageGrab if it is installed (experimental).
"""

from __future__ import annotations

import re
import sys
import time
from typing import List, Optional, Tuple

from . import protocol

RGB = Tuple[int, int, int]


class Screen:
    """A source of screen pixels. `order` is "BGR" or "RGB"."""

    order = "BGR"

    def bounds(self) -> Tuple[int, int, int, int]:
        raise NotImplementedError

    def grab(self, x: int, y: int, w: int, h: int) -> Tuple[bytes, int]:
        """Return (pixel bytes, row stride). 3 bytes per pixel, top row first."""
        raise NotImplementedError


class WindowsScreen(Screen):
    order = "BGR"

    def __init__(self) -> None:
        import ctypes
        from ctypes import wintypes

        self.ctypes = ctypes
        user32 = ctypes.windll.user32
        gdi32 = ctypes.windll.gdi32

        # Physical pixels, never scaled: without this, a 150% Windows display
        # scale would make every coordinate wrong.
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(2)
        except Exception:
            try:
                user32.SetProcessDPIAware()
            except Exception:
                pass

        # Handles are pointer sized: declare types so 64-bit Python does not
        # truncate them.
        HANDLE = ctypes.c_void_p
        user32.GetDC.restype = HANDLE
        user32.GetDC.argtypes = [HANDLE]
        user32.ReleaseDC.argtypes = [HANDLE, HANDLE]
        user32.GetSystemMetrics.argtypes = [ctypes.c_int]
        gdi32.CreateCompatibleDC.restype = HANDLE
        gdi32.CreateCompatibleDC.argtypes = [HANDLE]
        gdi32.CreateCompatibleBitmap.restype = HANDLE
        gdi32.CreateCompatibleBitmap.argtypes = [HANDLE, ctypes.c_int, ctypes.c_int]
        gdi32.SelectObject.restype = HANDLE
        gdi32.SelectObject.argtypes = [HANDLE, HANDLE]
        gdi32.DeleteObject.argtypes = [HANDLE]
        gdi32.DeleteDC.argtypes = [HANDLE]
        gdi32.BitBlt.argtypes = [HANDLE, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                 HANDLE, ctypes.c_int, ctypes.c_int, wintypes.DWORD]
        gdi32.GetDIBits.argtypes = [HANDLE, HANDLE, wintypes.UINT, wintypes.UINT, ctypes.c_void_p,
                                    ctypes.c_void_p, wintypes.UINT]

        class BITMAPINFOHEADER(ctypes.Structure):
            _fields_ = [("biSize", wintypes.DWORD), ("biWidth", ctypes.c_long), ("biHeight", ctypes.c_long),
                        ("biPlanes", wintypes.WORD), ("biBitCount", wintypes.WORD),
                        ("biCompression", wintypes.DWORD), ("biSizeImage", wintypes.DWORD),
                        ("biXPelsPerMeter", ctypes.c_long), ("biYPelsPerMeter", ctypes.c_long),
                        ("biClrUsed", wintypes.DWORD), ("biClrImportant", wintypes.DWORD)]

        self.user32, self.gdi32, self.BIH = user32, gdi32, BITMAPINFOHEADER

    def bounds(self) -> Tuple[int, int, int, int]:
        m = self.user32.GetSystemMetrics
        # SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN, SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN
        return m(76), m(77), m(78), m(79)

    def grab(self, x: int, y: int, w: int, h: int) -> Tuple[bytes, int]:
        ct, user32, gdi32 = self.ctypes, self.user32, self.gdi32
        hdc = user32.GetDC(None)
        mdc = gdi32.CreateCompatibleDC(hdc)
        bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
        old = gdi32.SelectObject(mdc, bmp)
        try:
            gdi32.BitBlt(mdc, 0, 0, w, h, hdc, x, y, 0x00CC0020)  # SRCCOPY
            gdi32.SelectObject(mdc, old)   # a bitmap must not be selected while reading it
            bih = self.BIH()
            bih.biSize = ct.sizeof(self.BIH)
            bih.biWidth, bih.biHeight = w, -h                # negative = top row first
            bih.biPlanes, bih.biBitCount, bih.biCompression = 1, 24, 0
            stride = ((w * 3 + 3) // 4) * 4
            buf = ct.create_string_buffer(stride * h)
            gdi32.GetDIBits(mdc, bmp, 0, h, buf, ct.byref(bih), 0)
            return buf.raw, stride
        finally:
            gdi32.DeleteObject(bmp)
            gdi32.DeleteDC(mdc)
            user32.ReleaseDC(None, hdc)


class PillowScreen(Screen):
    order = "RGB"

    def __init__(self) -> None:
        from PIL import ImageGrab  # noqa: F401  (optional dependency)
        self.ImageGrab = ImageGrab

    def bounds(self) -> Tuple[int, int, int, int]:
        img = self.ImageGrab.grab(all_screens=True)
        return 0, 0, img.width, img.height

    def grab(self, x: int, y: int, w: int, h: int) -> Tuple[bytes, int]:
        img = self.ImageGrab.grab(bbox=(x, y, x + w, y + h), all_screens=True).convert("RGB")
        return img.tobytes(), img.width * 3


def default_screen() -> Optional[Screen]:
    if sys.platform == "win32":
        try:
            return WindowsScreen()
        except Exception:
            pass
    try:
        return PillowScreen()
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Finding and reading the strip
# ---------------------------------------------------------------------------

def _hi(v: int) -> bool:
    return v >= 200


def _lo(v: int) -> bool:
    return v <= 60


class Image:
    def __init__(self, buf: bytes, stride: int, width: int, height: int, order: str):
        self.buf, self.stride, self.width, self.height, self.order = buf, stride, width, height, order

    def px(self, col: int, row: int) -> RGB:
        o = row * self.stride + col * 3
        a, b, c = self.buf[o], self.buf[o + 1], self.buf[o + 2]
        return (c, b, a) if self.order == "BGR" else (a, b, c)


def _is_mag(p: RGB) -> bool:
    return _hi(p[0]) and _lo(p[1]) and _hi(p[2])


def _is_green(p: RGB) -> bool:
    return _lo(p[0]) and _hi(p[1]) and _lo(p[2])


def _is_cyan(p: RGB) -> bool:
    return _lo(p[0]) and _hi(p[1]) and _hi(p[2])


# two magenta pixels in a row (magenta has the same bytes in RGB and BGR)
_MAGENTA2 = re.compile(rb"(?=[\xc8-\xff][\x00-\x3c][\xc8-\xff][\xc8-\xff][\x00-\x3c][\xc8-\xff])", re.S)


def find_strip(img: Image) -> Optional[Tuple[int, int, int]]:
    """Locate the sync pattern. Returns (col, row, block_size) in image
    coordinates, with row at the vertical centre of the strip."""
    for m in _MAGENTA2.finditer(img.buf):
        off = m.start()
        row, rem = divmod(off, img.stride)
        if rem % 3 or row >= img.height:
            continue
        col = rem // 3
        if col + 2 > img.width:
            continue
        c = col
        while c > 0 and _is_mag(img.px(c - 1, row)):
            c -= 1
        b = 0
        while c + b < img.width and _is_mag(img.px(c + b, row)):
            b += 1
        if b < 2 or b > 16 or c + protocol.BLOCKS * b > img.width:
            continue
        mid = b // 2
        if not (_is_green(img.px(c + b + mid, row)) and _is_mag(img.px(c + 2 * b + mid, row))
                and _is_cyan(img.px(c + 3 * b + mid, row))):
            continue
        dark, bright = img.px(c + 4 * b + mid, row), img.px(c + 7 * b + mid, row)
        if not (max(dark) <= 60 and min(bright) >= 200):
            continue
        x = c + mid
        top = row
        while top > 0 and _is_mag(img.px(x, top - 1)):
            top -= 1
        bottom = row
        while bottom < img.height - 1 and _is_mag(img.px(x, bottom + 1)):
            bottom += 1
        return c, (top + bottom) // 2, b
    return None


def sample_row(img: Image, col: int, row: int, block: int) -> List[RGB]:
    mid = block // 2
    return [img.px(col + i * block + mid, row) for i in range(protocol.BLOCKS)]


class LinkReader:
    """Keeps track of the strip and turns screen captures into messages."""

    SCAN_INTERVAL = 1.5      # seconds between searches while not connected
    LOST_AFTER = 1.5         # seconds of unreadable frames before searching again

    def __init__(self, screen: Screen):
        self.screen = screen
        self.assembler = protocol.Assembler()
        self.loc: Optional[Tuple[int, int, int]] = None   # screen x, y, block
        self.last_scan = 0.0
        self.last_good = 0.0
        self.frames = 0
        self.status = "searching"

    def _scan(self) -> None:
        self.last_scan = time.time()
        bx, by, bw, bh = self.screen.bounds()
        buf, stride = self.screen.grab(bx, by, bw, bh)
        found = find_strip(Image(buf, stride, bw, bh, self.screen.order))
        if found:
            col, row, block = found
            self.loc = (bx + col, by + row, block)
            self.last_good = time.time()
            self.status = "connected"

    def poll(self) -> List[protocol.ChatMessage]:
        now = time.time()
        if self.loc is None:
            if now - self.last_scan >= self.SCAN_INTERVAL:
                self._scan()
            if self.loc is None:
                self.status = "searching"
                return []
        x, y, block = self.loc
        buf, stride = self.screen.grab(x, y, protocol.BLOCKS * block, 1)
        img = Image(buf, stride, protocol.BLOCKS * block, 1, self.screen.order)
        levels = protocol.classify(sample_row(img, 0, 0, block))
        frame = protocol.decode_levels(levels) if levels else None
        if frame is None:
            if now - self.last_good > self.LOST_AFTER:
                self.loc = None
                self.status = "lost"
            return []
        self.last_good = now
        self.status = "connected"
        self.frames += 1
        return self.assembler.feed(frame, now)
