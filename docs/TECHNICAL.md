# WoW Translate: technical guide

This is the developer-facing companion to the player README. It covers what
the WoW: Forever client allows, how the addon and the Companion app work,
the screen-link wire format, tests, and releases.

## 1. The platform: what WoW: Forever changes

WoW: Forever (beta opened 2026-09-17) is **not** a Classic client even though
it reports a Classic-range version. Facts this project relies on, each
checked against the live client's UI source (`Gethe/wow-ui-source`, branch
`forever`, build 1.60.1.70009) or a captured API dump
(`Thunderz96/forever-addon-kit`, `data/forever_api.json`, build 69893):

| Fact | Consequence here |
|---|---|
| Interface **16001**, game type **camelot**. The client loads `<Addon>_Camelot.toc`. | We ship only `WoWTranslate_Camelot.toc` with `## Interface: 16001`. The BigWigs packager maps 16xxx to the `forever` flavour (CurseForge game version type 88568). |
| It runs the **modern Midnight-era API** (`WOW_PROJECT_MAINLINE`, 269 `C_*` namespaces). Many Classic globals are gone (`GetItemInfo`, `GetSpellInfo` ...). Common templates such as `BasicFrameTemplateWithInset` are gone too. | Only modern calls: `C_Item.GetItemNameByID`, `C_Spell.GetSpellName`, `C_QuestLog.GetTitleForQuestID`, `C_AddOns.GetAddOnMetadata`, `ButtonFrameTemplate`. Everything optional is feature-tested. |
| `select(4, GetBuildInfo()) >= 100000` is the usual "modern client" check and returns **false** on Forever. | Never used. `WT.IsForeverClient()` checks the 16xxx range. |
| **Addons have no network access**, and injecting DLLs into a Blizzard client violates the ToS and is detectable. | The vanilla edition's DLL is gone. Accurate translation runs outside the game (Companion app). |
| **Secret values**: during encounters, rated PvP and similar "chat lockdown", other players' chat arrives as secret values. `C_ChatInfo.InChatMessagingLockdown()` reports it. | `ChatFrameUtil.AddMessageEventFilter` already skips filters when `canaccessvalue(...)` is false, so those lines are shown untouched. We also check `issecretvalue` before touching unit names, and leave outgoing text alone during lockdown. |
| **Registering an unknown event throws** and aborts the file. | `WT.RegisterEvent` wraps `RegisterEvent` in `pcall`. |
| **SavedVariables are written but never loaded** (Blizzard beta bug, confirmed by several authors; still present on 70009 as of 2026-09-25). Macros created with `CreateMacro` do survive restarts. CVars registered by addons do not. | Opt-in "Remember my settings": one account macro `WoWTranslate` whose body is `/wt restore <data>`. Real SavedVariables win when they load; then the macro is deleted automatically. Writes wait for combat to end and never happen before the macro list has loaded. Macro bodies come back with trailing whitespace, so the reader never anchors to the end. |
| **Opening an addon dropdown in the Settings panel can crash the client** on build 70009 (`ldebug.c:747` assertion, forever-bugs #157). | No dropdown menus anywhere: the options window uses `< value >` cyclers and checkboxes. The Settings > AddOns entry is a canvas with one button. |
| `ReloadUI()` is protected. | Never called. |
| After 100 Lua errors in a session, the client stops reporting errors. | Every event handler and chat filter runs under `pcall`; the test harness fuzzes the pipeline. |
| Official hook points exist for exactly what we need: `ChatFrameUtil.AddMessageEventFilter`, `EventRegistry` events `ChatFrame.OnEditBoxPreSendText` ("for user addons to perform any final edits to chat text contents before sending"), `ChatFrame.OnHyperlinkEnter/Leave`, `SetItemRef` for `addon:` links, `TooltipDataProcessor.AddTooltipPostCall`, the Addon Compartment. | No global function replacement and no `SendChatMessage` hook (both taint the send path, which can block chat during lockdown). |
| `C_Intl` exposes ICU: `FoldCase`, `ToLower`, `Transliterate`, `FindBreaks`. | `FoldCase` for case-insensitive matching (Lua fallback included), `Transliterate("Any-Latin; Latin-ASCII")` for romanized names (falls back silently if the client's ICU has no transliterators). |
| Forever has language-matched pools (EN, ES, PT, DE, FR, RU, KO, zhTW clients). | UI localized for those plus zhCN; the default target is the client language. |

## 2. Layout

```
Interface/AddOns/WoWTranslate/     the addon (what CurseForge ships)
  WoWTranslate_Camelot.toc
  Core.lua                         namespace, settings, events, helpers
  Locales/*.lua                    UI strings (enUS base + 8 locales)
  Engine/Text.lua                  UTF-8, case/accent folding, scripts
  Engine/Detect.lua                language detection
  Engine/Dictionary.lua            lazy dictionary indexes
  Engine/Translate.lua             Quick mode engine
  Engine/Links.lua                 escape codes, hyperlinks, link names
  Dictionaries/<lang>_1..3.lua     offline phrase dictionaries
  Features/Incoming.lua            chat filter, [T] marker, hover/click
  Features/Outgoing.lua            pre-send translation
  Features/Names.lua               romanized names in tooltips
  Features/Persist.lua             settings-in-a-macro workaround
  Features/CompanionLink.lua       screen link encoder (Accurate mode)
  UI/                              options window, widgets, minimap
  Commands.lua                     /wt, demo, greeting
companion/                         WoW Translate Companion (Python, stdlib only)
tests/                             Lua harness + dictionary checks
scripts/                           packaging and CurseForge upload
legacy/vanilla/                    the old 1.12 edition with its DLL
```

## 3. Quick mode engine

* **Detection** (`Detect.lua`): Hangul, kana, Han and Cyrillic are decisive.
  Latin-script languages are scored with distinctive stop words and accent
  marks; ties and weak evidence return `nil`, so "gg", "ok", "+1" are never
  touched.
* **Dictionaries**: each entry is `"english|form1|form2|..."`. All forms map
  to the English text; the first form is used for English -> that language.
  Indexes are built the first time a language is seen, then the raw lines are
  released. Keys are normalized (fullwidth -> ASCII, case fold, accent fold for
  Latin/Cyrillic languages, `ё` -> `е`).
* **Matching**: languages with spaces use longest phrase match (up to 12
  words), then the single word, then Korean particle stripping or a light
  suffix stemmer (ru/de/fr/es/pt). Chinese and Japanese use greedy longest
  character match (up to 12 characters); unknown runs are kept as-is. ASCII
  keys never match inside a Latin word, and number slang ("88", "666") only
  matches when it stands alone, so prices like `88金` are safe.
* **Pivot**: X -> Y goes X -> English -> Y.
* **Scores**: every translation returns the share of recognised words.
  Incoming lines below 25% are left untouched; outgoing text below 50% is
  sent as typed, so players are never sent word salad.
* **Links and codes** (`Links.lua`): messages are split into text and code
  segments. Hyperlinks, colours (`|cff..`, `|cn..:`), textures, atlases,
  protected `|K..|k` strings and `{rt1}` icons pass through byte-for-byte.
  Item/quest/spell/achievement link names are replaced with the client's own
  localized names when cached (uncached items are requested with
  `C_Item.RequestLoadItemDataByID`, which is safe on this client; the vanilla
  client crashed on uncached `SetHyperlink`, which is why the old code never
  queried).

Performance: filters run once per chat window, so results are memoized per
chat `lineID`. The harness measures about 0.1 ms per line (3000 lines x 2 chat
windows in ~0.3 s on the CI machine), with no `OnUpdate` handlers.

## 4. Accurate mode and the screen link

Addons cannot talk to other programs, and the obvious alternatives are poor:

* `WoWChatLog.txt` is written through a ~4 KB buffer and flushes minutes late.
* SavedVariables are only written on logout/reload (and not read back at all
  on the beta).
* Reading game memory (as some tools do) is exactly what Blizzard's EULA
  prohibits.

So the addon **draws** the data and the app **looks** at the screen, like any
screen recorder. The addon's only action is setting texture colours.

### Wire format "WTL1"

One row of 200 square blocks, `block` physical pixels each (default 3; the
frame ignores UI scale and parent alpha and sizes itself from
`GetPhysicalScreenSize`). Anchored to a screen corner (default top-left).

| Blocks | Meaning |
|---|---|
| 0-3 | sync: magenta (3,0,3), green (0,3,0), magenta, cyan (0,3,3) |
| 4-7 | calibration greys, levels 0, 1, 2, 3 |
| 8-199 | 192 data sextets; block colour = 2 bits per channel, levels 0/85/170/255; value = r*16 + g*4 + b |

Data sextets: `seq` (mod 64), length hi, length lo (bytes, max 138), payload
packed 3 bytes -> 4 sextets (big-endian), 12-bit checksum
`s = (s*257 + v + 1) mod 4093` over `[seq, lenHi, lenLo, payload bytes...]`,
then zero padding (a non-zero pad means a torn capture and is rejected).

Payload: `msgId` byte, `partIndex*16 + partCount` byte, then up to 136 bytes
of the message. Messages are UTF-8 fields joined by `\x1f`:

* `1 C <channel> <channelName> <author> <lang> <text>`: a chat line
* `1 H <addonVersion> <clientLang> <targetLang> <locale>`: hello (sent when
  Accurate mode turns on and every 30 s while idle)
* `1 T <text>`: test message

The addon shows each frame for `hold` seconds (0.12 by default); an idle frame
(length 0) stays up when the queue is empty. The app samples the row at about
40 Hz, deduplicates by `seq`, and reassembles parts (incomplete messages
expire after 4 s).

The app finds the strip by scanning for two pure-magenta pixels, then checks
the full sync/calibration pattern (no false positives on random noise in the
tests). It classifies every channel against the four measured greys, so game
gamma or brightness changes do not break decoding. It enables per-monitor DPI
awareness so coordinates are physical pixels, and declares GDI handle types
so 64-bit Python does not truncate them.

### Companion app

`companion/wowtranslate_companion/` (Python 3.10+, standard library only):

* `capture.py`: GDI capture (Windows), Pillow fallback elsewhere, strip finder and `LinkReader`
* `protocol.py`: frame decoding and message assembly
* `providers.py`: DeepL (free/pro endpoint chosen from the key), Google Cloud v2, OpenAI-compatible chat completions, Google's unofficial free endpoint
* `translator.py`: worker threads, 2000-entry cache, back-off on HTTP 429
* `config.py`: `%APPDATA%\WoWTranslateCompanion\config.json`; keys encrypted with DPAPI on Windows
* `app.py`: Tk window; worker threads never touch Tk (everything goes through one queue)

Run from source: `cd companion && python -m wowtranslate_companion` (add
`--demo` to see sample chat without the game).

## 5. Tests

```
lua5.1 tests/check_dictionaries.lua      # format + collisions for all dictionaries
lua5.1 tests/harness.lua                 # loads the real addon in a mocked Forever client
python -m unittest discover -s companion/tests
```

The harness mocks the Forever pieces we depend on (chat filter registry with
Blizzard's secret-value semantics, `EventRegistry`, macros, `C_Intl`, timers)
and checks: incoming translation, own/disabled/AFK/secret lines, hyperlink and
`|K` preservation, native link names, the [T] tooltip and click, outgoing
translation incl. lockdown and slash commands, 255-byte limit, name
romanization, the macro settings store (incl. combat deferral), the link
encoder (round trip, corruption, torn frames), every slash command, UI
construction, 3000 random byte strings, and throughput. It also writes
`tests/link_frames.txt`, which the Python tests decode, so the Lua encoder and
Python decoder are tested against each other.

## 6. Releases and CurseForge

* `python scripts/package_addon.py` builds `dist/WoWTranslate-<version>.zip`
  with a single `WoWTranslate/` folder. It fails if the TOC lists a missing
  file or if a non-addon file type would be packaged.
* Pushing a tag `vX.Y.Z` runs `.github/workflows/release.yml`: tests, the
  addon zip, `WoWTranslateCompanion.exe` (PyInstaller, Windows runner), and a
  GitHub release with both.
* CurseForge: create the project once on the website (upload the zip by hand,
  game version **WoW: Forever 1.60.1**). Then add a repository secret
  `CF_API_KEY` and a variable `CF_PROJECT_ID`; later tags upload automatically
  via `scripts/curseforge_upload.py`, which tags the file with the Forever
  game version (type 88568), like the BigWigs packager does.
* Listing text for the project page is in [CURSEFORGE.md](CURSEFORGE.md).

## 7. Known limits

* Quick mode is dictionary-based: it gives the gist. Grammar, idioms and
  unknown words come through literally.
* Lines hidden by chat lockdown (encounters, rated PvP) cannot be translated
  by any addon.
* The screen link needs the game to be visible (windowed or borderless). Its
  colours can be decoded by anyone who sees the screen, including stream
  viewers.
* The Companion app is Windows-first; the Pillow capture path is experimental.
