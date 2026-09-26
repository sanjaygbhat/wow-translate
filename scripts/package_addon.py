"""Build the CurseForge-ready addon zip.

    python scripts/package_addon.py            -> dist/WoWTranslate-<version>.zip

The zip holds exactly one top-level folder, "WoWTranslate", which is what
CurseForge and manual installs expect. The script refuses to package files
that are not addon files (CurseForge rejects executables and the like), and
checks that every file listed in the TOC exists.
"""

from __future__ import annotations

import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "Interface", "AddOns", "WoWTranslate")
TOC = os.path.join(ADDON, "WoWTranslate_Camelot.toc")
ALLOWED = {".lua", ".toc", ".xml", ".tga", ".blp", ".txt", ".md"}


def main() -> int:
    with open(TOC, encoding="utf-8") as f:
        toc = f.read()
    m = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    version = m.group(1) if m else "dev"
    if "## Interface: 16001" not in toc:
        print("TOC must target interface 16001 (WoW: Forever)")
        return 1

    listed = [l.strip().replace("\\", "/") for l in toc.splitlines() if l.strip() and not l.startswith("#")]
    missing = [p for p in listed if not os.path.isfile(os.path.join(ADDON, p))]
    if missing:
        print("TOC lists missing files:", ", ".join(missing))
        return 1

    files = []
    for dirpath, _, names in os.walk(ADDON):
        for n in sorted(names):
            path = os.path.join(dirpath, n)
            ext = os.path.splitext(n)[1].lower()
            if ext not in ALLOWED:
                print("Refusing to package", os.path.relpath(path, ROOT))
                return 1
            files.append(path)
    for extra in ("LICENSE",):
        files.append(os.path.join(ROOT, extra))

    os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
    out = os.path.join(ROOT, "dist", "WoWTranslate-%s.zip" % version)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for path in files:
            if path.startswith(ADDON):
                arc = "WoWTranslate/" + os.path.relpath(path, ADDON).replace(os.sep, "/")
            else:
                arc = "WoWTranslate/" + os.path.basename(path) + (".txt" if not os.path.splitext(path)[1] else "")
            z.write(path, arc)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
