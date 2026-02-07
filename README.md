# WoWTranslate

<p align="center">
  <strong>Real-time chat translation for World of Warcraft 1.12</strong><br>
  Break the language barrier on multilingual private servers
</p>

<p align="center">
  <img src="https://img.shields.io/badge/WoW-1.12-blue" alt="WoW 1.12">
  <img src="https://img.shields.io/badge/version-0.10-green" alt="Version 0.10">
  <img src="https://img.shields.io/github/license/sanjaygbhat/wow-translate" alt="License">
</p>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🌍 **Multi-Language** | Chinese, Japanese, Korean, Russian → English (and reverse) |
| 📚 **WoW Glossary** | 500+ gaming terms translated correctly ("老克" → "Kel'Thuzad", not "Old gram") |
| ⚡ **Instant Cache** | Previously seen translations are instant and free |
| 💬 **Outgoing Translation** | Type in English, send in Chinese (or other languages) |
| 🔗 **Hyperlink Safe** | Player names, items, and quests stay clickable |

---

## 🚀 Quick Start

### 1. Download

**[⬇️ Download Latest Release](../../releases/latest)** — or grab from [Actions](../../actions) (click latest build → `WoWTranslate-vXXX`)

The download includes everything: DLL + Addon in one package.

### 2. Install

Extract and copy to your WoW folder:

```
YourWoWFolder/
├── WoW.exe
├── WoWTranslate.dll        ← From the download
├── dlls.txt                ← Add "WoWTranslate.dll" to this file
└── Interface/
    └── AddOns/
        └── WoWTranslate/   ← From the download
```

> **Note:** If `dlls.txt` doesn't exist, create it and add `WoWTranslate.dll` on the first line.

### 3. Get API Key

Contact the addon maintainer to receive a WoWTranslate API key with credits.

### 4. Configure In-Game

```
/wt key WT-XXXX-XXXX        Set your API key
/wt show                     Open settings panel
```

**Done!** Chat messages will now appear translated.

---

## 📖 Commands

| Command | Description |
|---------|-------------|
| `/wt show` | Open configuration panel |
| `/wt on` / `/wt off` | Enable/disable translation |
| `/wt key <key>` | Set your API key |
| `/wt status` | Show status and credits |
| `/wt test 你好` | Test translation |
| `/wt outgoing on` | Enable outgoing translation |
| `/wt clearcache` | Clear translation cache |

---

## 💰 Pricing

| Rate | Details |
|------|---------|
| **$30 / million characters** | ~0.003¢ per character |
| **Cache hits are FREE** | Repeated messages cost nothing |
| **Typical usage** | $1-3/month for active players |

Check your balance anytime with `/wt status` or `/wt show`.

---

## 🔧 How It Works

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Glossary   │ →  │    Cache    │ →  │  Translate  │
│  (instant)  │    │   (free)    │    │  (credits)  │
└─────────────┘    └─────────────┘    └─────────────┘
```

1. **Glossary** — WoW terms translated instantly (raids, bosses, slang)
2. **Cache** — Seen before? Instant and free
3. **API** — New text uses credits

---

## 🎮 Language Settings

Open settings with `/wt show`:

- **Incoming**: What language to translate FROM (Chinese, Japanese, Korean, Russian)
- **Outgoing**: Enable translation for Say, Party, Guild, Whisper, etc.

---

## ❓ Troubleshooting

| Problem | Solution |
|---------|----------|
| DLL not loading | Ensure `WoWTranslate.dll` is next to `WoW.exe` and listed in `dlls.txt` |
| "Out of credits" | Contact maintainer to add credits to your API key |
| No translations | Run `/wt status` to check DLL loaded, then `/wt test 你好` |
| Launcher issues | Run `WoW.exe` directly instead of through a launcher |

---

## 🛠️ Building from Source

<details>
<summary>Click to expand</summary>

**Requirements:** Windows, Visual Studio 2022, CMake 3.20+

```bash
cd dll && mkdir build && cd build
cmake .. -G "Visual Studio 17 2022" -A Win32
cmake --build . --config Release
```

Or just push to main — GitHub Actions builds automatically.

</details>

---

## 📄 License

MIT License

---

<p align="center">
  <sub>Made for the WoW 1.12 private server community</sub>
</p>
