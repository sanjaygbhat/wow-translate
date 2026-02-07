# WoWTranslate v0.1

Real-time Chinese to English translation addon for World of Warcraft 1.12 (Vanilla/Turtle WoW).

## Features

- **Automatic Chinese Detection** - Detects Chinese characters in chat messages
- **WoW-Specific Glossary** - 500+ gaming terms translated accurately (raids, bosses, slang)
- **Google Translate API** - Falls back to Google API for conversational text
- **Permanent Caching** - Translations saved forever in SavedVariables
- **Async Translation** - Non-blocking translation requests
- **Read-Only Design** - Never modifies chat frames or player names

## Architecture

```
Chat Message → Lua Addon → Check Glossary → Check Cache → DLL → Google API
                  ↓                                              ↓
           Display Translation ←────────────────────────────────┘
```

## Requirements

- WoW 1.12 client with UnitXP DLL support (Turtle WoW)
- Google Cloud Translation API key
- TurtleSilicon (macOS) or Windows client

## Quick Start (TurtleSilicon on macOS)

### Option 1: Automated Install

```bash
# Clone or download the repository, then:
./scripts/install-turtlesilicon.sh ~/Downloads/twmoa_1180
```

### Option 2: Manual Install

1. Download pre-built DLL from [GitHub Releases](../../releases)
2. Copy `WoWTranslate.dll` to your WoW folder (next to WoW.exe)
3. Add `WoWTranslate.dll` to `dlls.txt`
4. Copy `Interface/AddOns/WoWTranslate` folder to `Interface/AddOns/`

## Installation (Detailed)

### Step 1: Get the DLL

**Option A: Download pre-built** (Recommended)
- Download from [GitHub Releases](../../releases)

**Option B: Build from source** (Windows only)
```bash
cd dll
build.bat
# Output: build/bin/Release/WoWTranslate.dll
```

**Option C: GitHub Actions** (Automatic)
- Push to main branch triggers automatic build
- Download artifact from Actions tab

### Step 2: Install to Game

```bash
# Your Turtle WoW folder (adjust path as needed)
GAME_DIR=~/Downloads/twmoa_1180

# Copy DLL
cp WoWTranslate.dll "$GAME_DIR/"

# Add to dlls.txt
echo "WoWTranslate.dll" >> "$GAME_DIR/dlls.txt"

# Copy addon
cp -r Interface/AddOns/WoWTranslate "$GAME_DIR/Interface/AddOns/"
```

### Step 3: Get Google Cloud Translation API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)

2. Create a new project (or select existing):
   - Click "Select a project" → "New Project"
   - Name it (e.g., "WoWTranslate")
   - Click "Create"

3. Enable Cloud Translation API:
   - Go to "APIs & Services" → "Library"
   - Search for "Cloud Translation API"
   - Click "Enable"

4. Create API Key:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "API Key"
   - Copy the key (looks like: `AIzaSy...`)

5. (Recommended) Restrict the key:
   - Click on the API key to edit
   - Under "API restrictions", select "Restrict key"
   - Select only "Cloud Translation API"
   - Save

6. Enable Billing (required for API usage):
   - Go to "Billing" in the left menu
   - Link a billing account
   - Note: Free tier includes 500,000 characters/month

### Step 4: Configure In-Game

1. Launch Turtle WoW via TurtleSilicon
2. Log in to a character
3. Set your API key:
   ```
   /wt key YOUR_API_KEY_HERE
   ```
4. Verify it's working:
   ```
   /wt status
   /wt test 你好
   ```

## Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/wt` | Show help |
| `/wt on` | Enable translation |
| `/wt off` | Disable translation |
| `/wt key <apikey>` | Set Google API key |
| `/wt status` | Show status and statistics |
| `/wt test [text]` | Test translation |
| `/wt clearcache` | Clear translation cache |
| `/wt debug` | Toggle debug mode |
| `/wt log` | Show recent debug log |

### How It Works

1. **Glossary First** - WoW-specific terms are translated instantly with 100% accuracy
   - "老克" → "Kel'Thuzad" (not "Old gram")
   - "金团" → "GDKP" (not "Gold group")
   - "奶德" → "Resto Druid"

2. **Cache Second** - Previously translated phrases are instant

3. **API Last** - Conversational text goes to Google Translate

## TurtleSilicon Compatibility

WoWTranslate is fully compatible with TurtleSilicon on macOS:

- DLL loading works via Wine's DLL system
- Place `WoWTranslate.dll` in your game folder
- Add to `dlls.txt` file
- Works alongside other mods (SuperWoW, VanillaFixes, etc.)

**Note**: The DLL is built for Windows but runs via Wine/Rosetta in TurtleSilicon.

## Project Structure

```
WoWTranslate/
├── dll/                              # C++ DLL source
│   ├── src/
│   │   ├── dllmain.cpp              # Entry point
│   │   ├── lua_interface.cpp        # UnitXP hook
│   │   ├── translator_core.cpp      # Google API client
│   │   ├── logging.cpp              # Debug logging
│   │   └── utils.cpp                # Utilities
│   ├── include/                      # Header files
│   ├── third_party/                  # MinHook library
│   ├── CMakeLists.txt
│   └── build.bat
│
├── Interface/AddOns/WoWTranslate/    # Lua addon
│   ├── WoWTranslate.toc
│   ├── WoWTranslate.lua             # Main addon
│   ├── WoWTranslate_API.lua         # DLL communication
│   ├── WoWTranslate_Cache.lua       # Caching system
│   └── WoWTranslate_Glossary.lua    # 500+ WoW terms
│
├── scripts/
│   └── install-turtlesilicon.sh     # macOS installer
│
├── .github/workflows/
│   └── build.yml                    # Auto-build on push
│
└── README.md
```

## Glossary Categories

| Category | Count | Examples |
|----------|-------|----------|
| Raids | 30+ | MC, BWL, Naxx, AQ40, ZG |
| Dungeons | 50+ | SM, DM, Strat, Scholo, BRD |
| Classes | 40+ | All classes with specs |
| Bosses | 80+ | All major raid bosses |
| Chat Slang | 50+ | LFG, LFM, GDKP, Wipe |
| World Buffs | 15+ | Ony Head, Songflower |
| Items | 40+ | Thunderfury, T2, BiS |
| Locations | 50+ | All major cities/zones |
| Stats | 30+ | Hit, Crit, AP, SP |
| Expressions | 60+ | Greetings, responses |

## Cost Estimate

Google Cloud Translation: $20 per million characters

| Usage Pattern | Cost |
|--------------|------|
| Initial (no cache) | ~$1/day |
| After 1 week (90%+ cache) | ~$3/month |
| Free tier | 500k chars/month |

## Troubleshooting

### DLL Not Loading

1. Check `WoWTranslate.dll` is in WoW folder (next to WoW.exe)
2. Verify `dlls.txt` contains `WoWTranslate.dll`
3. Check `WoWTranslate_debug.log` for errors
4. Try restarting TurtleSilicon

### "DLL: Not loaded" in /wt status

- The DLL isn't being loaded by Wine
- Check dlls.txt has the correct entry
- Verify the DLL file exists and isn't corrupted

### API Errors

1. Verify API key is correct: `/wt key YOUR_KEY`
2. Check Google Cloud Console for:
   - API is enabled
   - Billing is set up
   - Quota not exceeded
3. Enable debug mode: `/wt debug`

### No Translations Appearing

1. Check addon is enabled: `/wt on`
2. Verify DLL status: `/wt status`
3. Test manually: `/wt test 你好`
4. Check if message contains Chinese characters

### Glossary Not Working

- Glossary translations should be instant (no API call)
- Test: `/wt test 老克` should return "Kel'Thuzad"
- If returning different result, check WoWTranslate_Glossary.lua

### DLL Not Loading with Game Launcher

**Issue:** WoWTranslate.dll loads when running WoW.exe directly but NOT when using a game launcher.

**Cause:** Some launchers may not load the DLL for translation unless it's specifically whitelisted. This could manifest as:
- The launcher overwriting `dlls.txt` during updates
- DLL loading options only available for pre-approved mods
- No custom DLL support in the launcher at all

**Solution:** Run WoW.exe directly instead of using the launcher:

1. Navigate to your game installation folder
2. Ensure `dlls.txt` contains `WoWTranslate.dll`
3. Double-click **WoW.exe** directly (not the launcher)
4. The game's integrated sideloader will load WoWTranslate.dll

**After game updates:** If you use the launcher to update the game, you may need to re-add `WoWTranslate.dll` to dlls.txt afterward.

## Log Files

| File | Location | Purpose |
|------|----------|---------|
| DLL Log | `WoWTranslate_debug.log` (game folder) | C++ side: API calls, errors |
| Lua Log | `WTF/Account/.../SavedVariables/WoWTranslate.lua` | Translations cache + debug |

## Building from Source

### Requirements (Windows)
- Visual Studio 2022 with C++ workload
- CMake 3.20+
- Windows SDK

### Build Steps
```bash
cd dll
mkdir build && cd build
cmake .. -G "Visual Studio 17 2022" -A Win32
cmake --build . --config Release
```

Output: `build/bin/Release/WoWTranslate.dll`

## License

MIT License

## Credits

- Based on [CET (Chinese English Translator)](https://github.com/bnizz/cet)
- Uses [MinHook](https://github.com/TsudaKageyu/minhook) for function hooking
- Google Cloud Translation API
- [TurtleSilicon](https://github.com/henhouse/TurtleSilicon) for macOS support
