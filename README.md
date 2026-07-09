# WoWTranslate 2.0

Real-time chat translation for World of Warcraft 1.12 clients, including Turtle/CapyCraft 1.18.1-style installs.

WoWTranslate is two parts:

- A WoW 1.12 Lua addon in `Interface/AddOns/WoWTranslate`
- A 32-bit Windows DLL, `WoWTranslate.dll`, loaded by the client through `dlls.txt`

Version 2.0 does not use a WoWTranslate-hosted server. The DLL calls your configured translation provider directly over HTTPS from your local machine. Google Cloud Translation Basic v2 is the default provider, and each player supplies their own Google API key locally.

## Features

- Incoming chat translation with channel filters
- Optional outgoing translation before sending chat
- Google Cloud Translation Basic v2 by default
- OpenAI-compatible `/v1/chat/completions` provider support
- Generic HTTPS JSON provider support
- Local persistent translation cache
- WoW glossary preprocessing for common raid, class, item, and server terms
- Item and quest hyperlink preservation
- Optional `WoWTranslate.ini` next to the DLL so keys do not need to be typed in chat

## Install

Download the latest release package from GitHub Releases, then copy the files into your WoW folder:

```text
YourWoWFolder/
  WoW.exe
  WoWTranslate.dll
  dlls.txt
  Interface/
    AddOns/
      WoWTranslate/
```

If `dlls.txt` does not exist, create it next to `WoW.exe` and put this line in it:

```text
WoWTranslate.dll
```

On macOS/Wine installs, you can use the helper script:

```bash
scripts/install-macos.sh /path/to/your/wow-folder
```

Then launch WoW and run:

```text
/wt provider google
/wt googlekey YOUR_GOOGLE_CLOUD_TRANSLATION_API_KEY
/wt test 你好
```

## Get A Google API Key

Google Cloud Translation Basic v2 supports API-key authentication. Advanced v3 uses different authentication and is not what WoWTranslate 2.0 targets.

1. Open https://console.cloud.google.com/ and sign in.
2. Click the project selector at the top of the page.
3. Click `New Project`.
4. Name it `WoWTranslate`.
5. Click `Create`.
6. Make sure the `WoWTranslate` project is selected.
7. Open `APIs & Services` -> `Library`.
8. Search for `Cloud Translation API`.
9. Open `Cloud Translation API`.
10. Click `Enable`.
11. Enable billing when Google asks. The API will not work without billing.
12. Open `APIs & Services` -> `Credentials`.
13. Click `Create credentials` -> `API key`.
14. Copy the new API key somewhere temporary.
15. Open the API key details page.
16. Under `API restrictions`, choose `Restrict key`.
17. Select `Cloud Translation API`.
18. Save.
19. Optional but recommended: open the Cloud Translation API quotas page and set a low daily character or request cap that matches your budget.
20. Optional but recommended: set a Google Cloud budget alert for the project.
21. Launch WoW.
22. Run `/wt provider google`.
23. Run `/wt googlekey YOUR_KEY_HERE`.
24. Run `/wt test 你好`.
25. If it fails, run `/wt status` and check the provider state and last error.

## Commands

```text
/wt show
/wt status
/wt test <text>
/wt on
/wt off
/wt outgoing on|off
/wt provider google|openai|custom
/wt googlekey <key>
/wt key <key>                  Deprecated alias for /wt googlekey when provider is google
/wt openaikey <key>
/wt openaiendpoint <url>
/wt openaimodel <model>
/wt customendpoint <url>
/wt customkey <key>
/wt customauth <header> <scheme>
/wt customtemplate <json>
/wt custompath <path>
/wt clearcache
```

`/wt status` shows DLL loaded state, provider, configured/ready state, last error, incoming/outgoing state, cache entries, cache hit rate, and pending requests.

## OpenAI-Compatible Provider

Use this for OpenAI or any service that implements a compatible chat completions API.

```text
/wt provider openai
/wt openaiendpoint https://api.openai.com/v1/chat/completions
/wt openaimodel gpt-4.1-mini
/wt openaikey YOUR_KEY
/wt test 你好
```

The DLL sends a chat completion request with temperature `0` and a system instruction to translate only, preserve URLs/placeholders exactly, and return no commentary. It reads `choices[0].message.content`.

## Custom HTTPS JSON Provider

Use this for any HTTPS JSON translation service.

```text
/wt provider custom
/wt customendpoint https://example.com/translate
/wt customkey YOUR_KEY
/wt customauth Authorization Bearer
/wt customtemplate {"text":"{text}","source":"{source}","target":"{target}"}
/wt custompath data.translation
/wt test 你好
```

Placeholders available in the request template:

- `{text}`
- `{source}`
- `{target}`

Response paths support object fields and array indexes, for example:

```text
translation
data.translation
choices[0].message.content
```

The configuration panel exposes the common custom fields. The full JSON body template is intentionally slash-command or INI-only because it is too long for the WoW 1.12 settings panel.

## Optional WoWTranslate.ini

Place `WoWTranslate.ini` next to `WoWTranslate.dll` if you prefer not to type keys in chat. This file is local and ignored by git.

```ini
[provider]
type=google

[google]
api_key=AIza...

[openai]
endpoint=https://api.openai.com/v1/chat/completions
api_key=sk-...
model=gpt-4.1-mini
temperature=0

[custom]
endpoint=https://example.com/translate
api_key=...
auth_header=Authorization
auth_scheme=Bearer
request_template={"text":"{text}","source":"{source}","target":"{target}"}
response_path=translation
```

Valid provider types are `google`, `openai`, and `custom`.

## Security

API keys are stored locally in plaintext if you save them through WoW SavedVariables or `WoWTranslate.ini`. Do not share your SavedVariables or INI file.

For Google keys, restrict the key to `Cloud Translation API`. Application restrictions are harder for a desktop game DLL because browser and mobile app restrictions do not apply; IP restrictions only work well if you have a stable public IP. Use API restrictions plus low usage caps and budget alerts.

## Build From Source

Requirements:

- Windows
- Visual Studio 2022 with C++ workload
- CMake 3.20+

```bat
cd dll
build.bat
```

Manual build:

```bat
cd dll
mkdir build
cd build
cmake .. -G "Visual Studio 17 2022" -A Win32
cmake --build . --config Release
```

Output:

```text
dll/build/bin/Release/WoWTranslate.dll
```

GitHub Actions also builds the 32-bit DLL on pushes to `main` and uploads an artifact named `WoWTranslate-dll`.

## License

MIT License
