"""Upload the addon zip to CurseForge, tagged for WoW: Forever.

    CF_API_KEY=... CF_PROJECT_ID=... python scripts/curseforge_upload.py dist/WoWTranslate-3.0.0.zip [changelog.md]

Mirrors what the BigWigs packager does: look up the "Forever" game version
id (game version type 88568) and POST the file with its metadata to the
CurseForge upload API. The first version of a project must be created on the
CurseForge website; after that, releases can be uploaded with this script.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
import uuid

SITE = "https://wow.curseforge.com"
FOREVER_TYPE_ID = 88568


def api(path: str, token: str, data: bytes = None, content_type: str = None) -> bytes:
    req = urllib.request.Request(SITE + path, data=data, headers={"x-api-token": token})
    if content_type:
        req.add_header("Content-Type", content_type)
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main() -> int:
    token, project = os.environ.get("CF_API_KEY"), os.environ.get("CF_PROJECT_ID")
    if not token or not project or len(sys.argv) < 2:
        print("Set CF_API_KEY and CF_PROJECT_ID and pass the zip path. Skipping CurseForge upload.")
        return 0
    zip_path = sys.argv[1]
    changelog = ""
    if len(sys.argv) > 2 and os.path.exists(sys.argv[2]):
        with open(sys.argv[2], encoding="utf-8") as f:
            changelog = f.read()

    versions = json.loads(api("/api/game/wow/versions", token))
    forever = [v for v in versions if v.get("gameVersionTypeID") == FOREVER_TYPE_ID]
    if not forever:
        print("CurseForge has no WoW: Forever game version yet.")
        return 1
    wanted = os.environ.get("CF_GAME_VERSION", "1.60.1")
    match = [v for v in forever if v.get("name") == wanted] or sorted(forever, key=lambda v: v["id"])[-1:]
    version_ids = [match[0]["id"]]
    print("Tagging for WoW: Forever", match[0].get("name"))

    name = os.path.basename(zip_path)
    metadata = {
        "displayName": os.path.splitext(name)[0],
        "gameVersions": version_ids,
        "releaseType": os.environ.get("CF_RELEASE_TYPE", "release"),
        "changelog": changelog or "See the project page for details.",
        "changelogType": "markdown",
    }
    boundary = uuid.uuid4().hex
    with open(zip_path, "rb") as f:
        file_bytes = f.read()
    body = (
        ("--%s\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n%s\r\n" % (boundary, json.dumps(metadata))).encode()
        + ("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\n"
           "Content-Type: application/zip\r\n\r\n" % (boundary, name)).encode()
        + file_bytes + ("\r\n--%s--\r\n" % boundary).encode()
    )
    result = api("/api/projects/%s/upload-file" % project, token, body, "multipart/form-data; boundary=" + boundary)
    print("Uploaded:", result.decode("utf-8", "replace"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
