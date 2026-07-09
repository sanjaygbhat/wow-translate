# WoWTranslate 2.0

<p align="center">
  <strong>Real-time chat translation for World of Warcraft 1.12</strong><br>
  Local provider keys, direct HTTPS translation, and no WoWTranslate-hosted server
</p>

<p align="center">
  <img src="https://img.shields.io/badge/WoW-1.12-blue" alt="WoW 1.12">
  <img src="https://img.shields.io/badge/version-2.0-green" alt="Version 2.0">
  <img src="https://img.shields.io/github/license/sanjaygbhat/wow-translate" alt="License">
  <img src="https://img.shields.io/badge/server-not%20required-brightgreen" alt="No server required">
  <img src="https://img.shields.io/badge/providers-Google%20%7C%20OpenAI%20%7C%20Custom-informational" alt="Google, OpenAI-compatible, and custom providers">
  <img src="https://img.shields.io/badge/LibreTranslate-custom%20HTTPS-orange" alt="LibreTranslate through the custom HTTPS provider">
  <a href="https://github.com/sponsors/sanjaygbhat"><img src="https://img.shields.io/badge/%E2%9D%A4%20Sponsor-ea4aaa?logo=githubsponsors&logoColor=white" alt="Sponsor sanjaygbhat on GitHub"></a>
</p>

---

WoWTranslate translates chat for World of Warcraft 1.12 clients, including Turtle/CapyCraft 1.18.1-style installs.

Version 2.0 is two local pieces:

- A WoW 1.12 Lua addon in `Interface/AddOns/WoWTranslate`
- A 32-bit Windows DLL, `WoWTranslate.dll`, loaded by the client through `dlls.txt`

The DLL calls your configured translation provider directly over HTTPS from your local machine. Google Cloud Translation Basic v2 is the default provider, and each player supplies their own provider key or self-hosted HTTPS endpoint locally.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🌍 **Incoming Translation** | Translate incoming chat with language and channel controls. |
| 💬 **Optional Outgoing Translation** | Translate your own messages before they are sent. Off by default. |
| 🔌 **Direct Providers** | Use Google Cloud Translation Basic v2, an OpenAI-compatible `/v1/chat/completions` endpoint, or a custom HTTPS JSON service. |
| 🆓 **Free LibreTranslate Path** | Use LibreTranslate through the custom HTTPS provider; self-host for a no-billing option. |
| 🚫 **No Hosted Server** | WoWTranslate 2.0 calls providers directly from your machine; you bring a provider key or HTTPS endpoint you control. |
| 📚 **WoW Glossary** | Preprocesses common raid, class, item, and server terms before provider translation. |
| 🔗 **Hyperlink Safe** | Preserves item, quest, player, and other WoW hyperlinks so links stay clickable. |
| ⚡ **Local Cache** | Repeated translations are served from a persistent local cache instead of calling the provider again. |
| 🧰 **Flexible Config** | Configure in game with `/wt` commands or keep provider keys in `WoWTranslate.ini` next to the DLL. |
| 🗺️ **In-Game Panel** | `/wt show` opens the configuration panel for providers, languages, channels, cache, and outgoing settings. |

---

## 🚀 Quick Start

### 1. Download

Download the release package from **[GitHub Releases](../../releases)**. The package should contain the addon folder and `WoWTranslate.dll`.

### 2. Install on Windows

Extract the package, then copy the files into your WoW folder:

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

### 3. Install on macOS/Wine

For macOS/Wine installs, use the helper script from the repo:

```bash
scripts/install-macos.sh /path/to/your/wow-folder
```

The script installs the addon, copies `WoWTranslate.dll` if it can find a downloaded or built DLL, and adds `WoWTranslate.dll` to `dlls.txt`.

### 4. Configure In Game

Launch WoW and run:

```text
/wt provider google
/wt googlekey YOUR_GOOGLE_CLOUD_TRANSLATION_API_KEY
/wt test 你好
```

Open the settings panel anytime with:

```text
/wt show
```

---

## 🔑 Get a Google API Key

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

---

## 💰 Cost

WoWTranslate does not sell keys or translation time. Your configured provider bills your own account directly.

For Google Cloud Translation Basic v2, Google currently lists the first 500,000 characters per month as free, then roughly `$20` per million characters after that. Check the [Google Cloud Translation pricing page](https://cloud.google.com/translate/pricing) for current rates.

Provider tradeoffs:

| Provider | Best For | Cost and Billing | Setup |
|----------|----------|------------------|-------|
| **Google Cloud Translation Basic v2** | Best translation quality and language coverage. | Requires a linked Google Cloud billing account. The first 500,000 characters/month are currently free, then usage is paid. | `/wt provider google` plus a Google Cloud Translation API key. |
| **OpenAI-compatible** | OpenAI or any service with an OpenAI-style chat completions API. | Requires an OpenAI-style API key. Billing depends on the provider account. | `/wt provider openai` plus endpoint, model, and key. |
| **LibreTranslate (custom)** | Free, no-billing translation when you self-host. | Free and open-source. Self-host for reliability; public community mirrors can be rate-limited or unreliable. | `/wt provider custom` plus the LibreTranslate endpoint, template, and response path below. |

Ways to keep cost under your control:

- Set a daily quota cap for the Cloud Translation API.
- Set a Google Cloud budget alert on the project.
- Leave outgoing translation off unless you need it.
- Keep the local cache enabled so repeated messages do not call the provider again.
- Glossary replacements and cache hits are local and do not call the provider.

---

## 🆓 Free Option (No Billing): LibreTranslate

LibreTranslate is free and open-source. WoWTranslate uses it through the existing custom HTTPS JSON provider, so no code changes are needed. The endpoint must be HTTPS because `WoWTranslate.dll` only accepts HTTPS custom endpoints.

### In-Game Slash Commands

```text
/wt provider custom
/wt customendpoint https://YOUR-LIBRETRANSLATE-HOST/translate
/wt customtemplate {"q":"{text}","source":"{source}","target":"{target}","format":"text"}
/wt custompath translatedText
/wt test 你好
```

### WoWTranslate.ini

Place this in `WoWTranslate.ini` next to `WoWTranslate.dll`:

```ini
[provider]
type=custom

[custom]
endpoint=https://YOUR-LIBRETRANSLATE-HOST/translate
request_template={"q":"{text}","source":"{source}","target":"{target}","format":"text"}
response_path=translatedText
```

### API Keys

The official hosted `libretranslate.com` endpoint requires an API key. If any LibreTranslate instance needs a key, LibreTranslate expects it in the request body as `api_key`, not as an auth header. Add it inside the template:

```ini
request_template={"q":"{text}","source":"{source}","target":"{target}","format":"text","api_key":"YOUR_LT_KEY"}
```

Do not use `/wt customkey` or `/wt customauth` for LibreTranslate API keys.

### Self-Hosting

For a truly free, unlimited, reliable option, self-host LibreTranslate with Docker:

```bash
docker run -ti --rm -p 5000:5000 libretranslate/libretranslate
```

That starts LibreTranslate on local HTTP port `5000`. Put HTTPS in front of it with a reverse proxy or tunnel, then configure WoWTranslate with the public `https://.../translate` URL. Public community mirrors exist, but they are usually rate-limited and can be unreliable; self-hosting is the dependable free path.

---

## 📖 Commands

All commands work through `/wt`; `/wowtranslate` is also registered as a longer alias.

| Command | Description |
|---------|-------------|
| `/wt show` | Open the configuration panel. Aliases: `/wt config`, `/wt options`. |
| `/wt hide` | Close the configuration panel. |
| `/wt status` | Show DLL loaded state, provider, configured/ready state, last error, incoming/outgoing state, cache entries, cache hit rate, and pending requests. |
| `/wt test <text>` | Test an incoming translation request. Defaults to `你好` when no text is supplied. |
| `/wt on` / `/wt off` | Enable or disable incoming translation. Aliases: `/wt enable`, `/wt disable`. |
| `/wt outgoing on/off` | Enable or disable outgoing translation. |
| `/wt outchannel [type]` | Show or toggle outgoing channels: `WHISPER`, `PARTY`, `GUILD`, `RAID`, `SAY`, `YELL`, `BATTLEGROUND`, `CHANNEL`. |
| `/wt prefix <text>` | Set the prefix used on outgoing translated messages. |
| `/wt testout <text>` | Test outgoing translation without sending a chat message. |
| `/wt provider google/openai/custom` | Select the active provider. |
| `/wt googlekey <key>` | Store and apply a Google Cloud Translation API key. |
| `/wt key <key>` | Deprecated alias for `/wt googlekey` when the active provider is Google. |
| `/wt openaikey <key>` | Store an OpenAI-compatible provider key and switch to the OpenAI-compatible provider. |
| `/wt openaiendpoint <url>` | Set the OpenAI-compatible chat completions endpoint. |
| `/wt openaimodel <model>` | Set the OpenAI-compatible model. |
| `/wt customendpoint <url>` | Set the custom HTTPS JSON provider endpoint. |
| `/wt customkey <key>` | Store a custom provider key. |
| `/wt customauth <header> <scheme>` | Set the custom provider auth header and scheme, such as `Authorization Bearer`. |
| `/wt customtemplate <json>` | Set the custom provider request JSON template. |
| `/wt custompath <path>` | Set the response path used to read translated text from a custom provider response. |
| `/wt clearcache` | Clear the local translation cache. |
| `/wt debug` | Toggle debug mode. |
| `/wt log` | Print recent debug log entries. |
| `/wt clearlog` | Clear the debug log. |
| `/wt testlink` | Test hyperlink parsing. |
| `/wt testitem [itemId]` | Test item hyperlink localization using client-cached item data. |
| `/wt testquest [questId]` | Test quest hyperlink localization when a pfQuest database is available. |

---

## 🔧 How It Works

```text
WoW chat
  -> Lua addon
  -> glossary preprocessing
  -> hyperlink preservation
  -> local cache lookup
  -> 32-bit WoWTranslate.dll
  -> your configured HTTPS provider
  -> translated chat display
```

The Lua addon handles chat events, channel settings, language settings, outgoing hooks, glossary preprocessing, hyperlink handling, cache lookups, and the in-game configuration panel.

`WoWTranslate.dll` is loaded by the client through `dlls.txt`. It receives provider settings from the addon, performs HTTPS JSON requests from your local machine, and returns translated text to the addon. There is no WoWTranslate-hosted translation server in version 2.0.

---

## 🎮 Language Settings

Open settings with `/wt show`.

| Setting | Details |
|---------|---------|
| **Provider** | Choose Google, OpenAI-compatible, or Custom HTTP. |
| **Incoming Languages** | Defaults to Chinese -> English, configurable in the panel. |
| **Outgoing Languages** | Defaults to English -> Chinese, configurable in the panel. |
| **Incoming Channels** | Toggle Say, Yell, Whisper, Party, Guild, Raid, Battleground, and World/Local. |
| **Outgoing Channels** | Toggle Whisper, Party, Guild, Raid, Say, Yell, Battleground, and World/Local. |
| **AFK Behavior** | `Disable while AFK` is available in the panel and is enabled by default. |
| **System Messages** | System/emote translation is available in the panel and is disabled by default. |

The panel includes common provider fields. The full custom JSON body template is intentionally slash-command or INI-only because it is too long for the WoW 1.12 settings panel.

---

## 🤖 OpenAI-Compatible Provider

Use this for OpenAI or any service that implements a compatible chat completions API.

```text
/wt provider openai
/wt openaiendpoint https://api.openai.com/v1/chat/completions
/wt openaimodel gpt-4.1-mini
/wt openaikey YOUR_KEY
/wt test 你好
```

The DLL sends a chat completion request with temperature `0` and a system instruction to translate only, preserve URLs/placeholders exactly, and return no commentary. It reads `choices[0].message.content`.

---

## 🧩 Custom HTTPS JSON Provider

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

| Placeholder | Meaning |
|-------------|---------|
| `{text}` | Text to translate. |
| `{source}` | Source language code. |
| `{target}` | Target language code. |

Response paths support object fields and array indexes, for example:

```text
translation
data.translation
choices[0].message.content
```

---

## 📝 Optional WoWTranslate.ini

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

---

## 🔐 Security

API keys are stored locally in plaintext if you save them through WoW SavedVariables or `WoWTranslate.ini`. Do not share your SavedVariables or INI file.

For Google keys, restrict the key to `Cloud Translation API`. Application restrictions are harder for a desktop game DLL because browser and mobile app restrictions do not apply; IP restrictions only work well if you have a stable public IP. Use API restrictions plus low usage caps and budget alerts.

---

## ❓ Troubleshooting

| Problem | Check |
|---------|-------|
| DLL not loaded | Make sure `WoWTranslate.dll` is next to `WoW.exe` and listed in `dlls.txt`, then run `/wt status`. |
| Google request fails | Confirm the Cloud Translation API is enabled, billing is enabled, the key is restricted to `Cloud Translation API`, and your quota has not been exhausted. |
| Provider not ready | Run `/wt status` and check provider, configured/ready state, endpoint, HTTP status, and last error. |
| No incoming translations | Run `/wt on`, check incoming language/channel settings in `/wt show`, then test with `/wt test 你好`. |
| Outgoing translation does nothing | Run `/wt outgoing on`, confirm the target channel is enabled with `/wt outchannel`, and check that the DLL is loaded. |
| Custom provider returns blank text | Verify `/wt custompath <path>` points to the translated text field in the JSON response. |
| Costs are higher than expected | Set a Google quota cap and budget alert, leave outgoing translation off by default, and keep the local cache enabled. |

---

## 🛠️ Building from Source

### Windows local build

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

### macOS/Homebrew MinGW cross-compile

For local cross-compiles, use the MinGW helper:

```bash
bash dll/build-mingw.sh
```

The script builds a 32-bit PE DLL with MinGW, verifies the output, and writes:

```text
dll/build/WoWTranslate.dll
```

It expects the MinGW toolchain to be available and, as written, copies the final DLL to the local client path configured inside the script.

### GitHub Actions

The Windows CI workflows build the 32-bit DLL on pushes and pull requests:

- `.github/workflows/build-dll.yml` builds and packages `WoWTranslate.dll`, then uploads release/package artifacts.
- `.github/workflows/build.yml` builds the DLL and uploads DLL/full-addon artifacts.

Both workflows use the Visual Studio 2022 Win32 CMake path and produce `WoWTranslate.dll` from `dll/build/bin/Release/WoWTranslate.dll`.

---

## ❤️ Support

WoWTranslate is free and open source. If it makes your cross-language adventures better,
you can support development through
[GitHub Sponsors](https://github.com/sponsors/sanjaygbhat) — one-time or monthly, and 100%
of personal sponsorships go to the developer.

---

## 📄 License

MIT License

---

<p align="center">
  <sub>Made for the WoW 1.12 community. Bring your own provider key, keep control of your own bill.</sub>
</p>
