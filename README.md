# WoW Translate

**Read and write chat in other languages in World of Warcraft: Forever.**

Someone whispers you in Russian, the trade channel is full of Chinese, your new guildmate only speaks Spanish. WoW Translate turns those messages into your language, right in your chat window. It can also translate what you write, so you can answer them.

<p align="center">
  <img src="https://img.shields.io/badge/WoW-Forever-blue" alt="WoW: Forever">
  <img src="https://img.shields.io/badge/version-3.0.0-green" alt="Version 3.0.0">
  <img src="https://img.shields.io/github/license/sanjaygbhat/wow-translate" alt="MIT License">
  <a href="https://github.com/sponsors/sanjaygbhat"><img src="https://img.shields.io/badge/%E2%9D%A4%20Sponsor-ea4aaa?logo=githubsponsors&logoColor=white" alt="Sponsor"></a>
</p>

---

## What it looks like

| Someone writes | You see |
|---|---|
| `[Trade] Li: 出 附魔材料 便宜 M我` | `[Trade] [T] Li: WTS enchanting materials cheap whisper me` |
| `[Whisper] Ivan: го в мк, нужен хил` | `[Whisper] [T] Ivan: Go in Molten Core, need a healer` |
| `[Party] Klaus: Hallo, wir brauchen noch einen Heiler` | `[Party] [T] Klaus: Hello, we need a healer` |

(These are real results from Quick mode, the free mode.)

The small **[T]** means "translated". Point your mouse at it to see the original message. Click it to print the original in chat.

---

## Two ways to translate

You pick one. You can switch at any time by typing `/wt`.

| | **Quick** (free) | **Accurate** (uses a paid service) |
|---|---|---|
| **How good is it?** | Gives you the general meaning, phrase by phrase. Good for trade chat, group calls and short messages. Often clumsy, sometimes wrong. | Real, natural sentences. Understands slang and context. |
| **Where do translations show?** | Right in your chat window. | In a small window next to your chat (the WoW Translate Companion app). |
| **What do I need?** | Nothing. It works as soon as you log in. | The free Companion app on your PC, plus an account with a translation service. |
| **Does it cost money?** | No. | The services give you a free amount every month, then charge you. Most players stay in the free amount. [See costs](#costs) |

Here is the same message both ways:

| Original (Chinese) | Quick | Accurate |
|---|---|---|
| 法师拉仇恨了，快撤！ | Mage pull aggro, fast run away! | The mage has drawn aggro, retreat quickly! |
| 萨满快给我加血，我要死了哈哈 | Shaman fast heal me, I want dead haha | Shaman, heal me! I'm dying, haha! |

**Why can't the addon do accurate translations by itself?** Blizzard doesn't let addons use the internet, and good translation needs a translation service on the internet. So Accurate mode uses a small app that runs next to the game. More on that [below](#accurate-mode).

---

## Install

**With the CurseForge app (easiest)**

1. Open CurseForge and choose **World of Warcraft**.
2. Make sure your game version is **WoW: Forever** (during the beta, pick the Forever beta install).
3. Search for **WoW Translate** and click **Install**.

**By hand**

1. Download the latest `WoWTranslate-x.x.x.zip` from [Releases](https://github.com/sanjaygbhat/wow-translate/releases).
2. Unzip it into your WoW: Forever addons folder, so you end up with a folder called `WoWTranslate` inside `AddOns`:
   - During the beta this is usually `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\`
3. Restart the game. On the character screen, click **AddOns** and make sure **WoW Translate** is ticked.

---

## Getting started

There's nothing to set up. When you log in you'll see:

> WoW Translate: Quick mode is on. Messages in other languages are translated into English.

From then on, messages in other languages are translated into your game's language.

- Type **`/wt`** (or click the minimap button) to open the options.
- Click **Try it** in the options to see some example translations.
- Right-click the minimap button to turn translation on or off quickly.

**Languages it understands:** English, German, French, Spanish, Portuguese, Russian, Korean, Chinese (simplified and traditional) and Japanese. You can translate into any of these.

**The addon itself** is also available in German, French, Spanish, Portuguese, Russian, Korean and Chinese. It uses your game's language automatically.

---

## Answering people in their language

1. Open `/wt` and tick **Translate what I write**.
2. Leave **Write in** on **Their language (auto)**.

Now, when someone writes to you in Russian, your reply to them is translated into Russian before it's sent. If nobody has written to you in another language, your message is sent exactly as you typed it.

Your message gets a short tag like `(перевод)` at the front, so the other player knows a machine translated it. You can turn the tag off.

Tips for better results:
- Keep sentences short and simple: "need a tank", "where are you?", "thanks, good run".
- Quick mode is word-by-word, so long sentences come out rough. For your own messages, the Companion app gives much better results: type your reply there, it translates it and copies it, and you paste it into WoW with **Ctrl+V**.

You can choose which channels this works in (whispers, party, raid and so on). Guild, yell and trade chat are off by default.

---

## Accurate mode

Accurate mode gives you proper translations. It needs two things: the Companion app, and an account with a translation service.

### 1. Get the Companion app

Download **WoWTranslateCompanion.exe** from [Releases](https://github.com/sanjaygbhat/wow-translate/releases) and run it. There's nothing to install. Windows may warn you that the app is from an unknown publisher: click **More info**, then **Run anyway**.

The Companion app is for Windows. On a Mac it works only if you run it from the source code (see [the technical guide](docs/TECHNICAL.md)), and screen reading there is still experimental.

### 2. Choose a translation service

When the app starts, it asks you to pick one:

| Service | Quality | Cost |
|---|---|---|
| **DeepL** (recommended) | The most natural translations. | Free for 500,000 characters a month, then paid. |
| **Google Cloud** | Very good. | Free for 500,000 characters a month, then about $20 per million characters. |
| **OpenAI-compatible** (ChatGPT and similar) | Very good, understands gamer slang well. | Paid per use. |
| **Google (free, no key)** | Good enough to try things out. | Free, but unofficial: it can slow down or stop working at any time. |

For DeepL or Google you need a **key**, which is like a password that lets the app use your account. Getting one takes about 10 minutes:

<details>
<summary><b>How to get a DeepL key</b></summary>

1. Go to [deepl.com/pro-api](https://www.deepl.com/pro-api) and sign up for **DeepL API Free**. They ask for a card to check you're a real person, but the free plan doesn't charge you.
2. Once you're logged in, open your **Account** page and find **API Keys**.
3. Copy the key (it ends in `:fx`).
4. In the Companion app, open **Settings**, pick **DeepL**, paste the key, click **Test**, then **Save**.
</details>

<details>
<summary><b>How to get a Google Cloud key</b></summary>

1. Go to [console.cloud.google.com](https://console.cloud.google.com/) and sign in.
2. Create a new project (call it anything, like "WoW Translate").
3. Search for **Cloud Translation API** and click **Enable**. Google asks you to add a billing account; the first 500,000 characters each month are free.
4. Go to **APIs & Services**, then **Credentials**, then **Create credentials**, then **API key**. Copy the key.
5. Recommended: click the key, choose **Restrict key**, and allow only **Cloud Translation API**. You can also set a monthly budget alert so you never get a surprise bill.
6. In the Companion app, open **Settings**, pick **Google Cloud**, paste the key, click **Test**, then **Save**.
</details>

Your key stays on your PC. On Windows, the app stores it encrypted so only your Windows account can read it.

### 3. Connect the game

1. Play WoW in **Windowed** or **Windowed (Fullscreen)** mode (in the game's System > Graphics options). The app reads your screen, which doesn't work in exclusive fullscreen.
2. In the game, type `/wt` and pick **Accurate**. You'll see a thin line of coloured squares in the top-left corner of your screen. That's how the addon sends chat to the app, so leave it visible.
3. Click **Send a test** in the options. The app should show a test message within a second, and the light at the top of the app turns green.

That's it. Translations now appear in the Companion window. Drag it next to your chat and make it as small or see-through as you like (in the app's **Settings**).

**Replying:** type in the box at the bottom of the app and press **Enter**. It translates into the language of the last person who wrote, copies the result, and you paste it into WoW with **Ctrl+V**.

### Costs

A character is one letter, space or symbol. As a rough example, a chat message is about 40 characters, so 500,000 characters is around 12,000 messages a month. Only messages in other languages are sent, and repeated messages are remembered instead of being sent again. The app shows how much you've used this month in **Settings**.

If you watch a busy trade channel all day, you may go over the free amount. To stay safe, set a budget limit in your DeepL or Google account.

---

## Is it safe? Can I get banned?

- **The addon** is a normal addon. It only uses the tools Blizzard gives every addon: it reads chat, changes how chat lines look, and draws a few squares on screen.
- **The Companion app** only looks at your screen, the same way a screenshot or streaming app does. It never reads the game's memory, never changes game files, and never presses keys or clicks for you.
- The old vanilla (1.12) version of WoW Translate used a DLL loaded into the game. **This version doesn't.** Don't use DLL-based tools on WoW: Forever.

Blizzard doesn't officially approve any third-party app, so we can't promise anything on their behalf. WoW Translate is built to stay within what normal addons and screen-reading apps do.

**If you stream:** the coloured line in Accurate mode is your chat written as colours. Someone with the app could decode it from your stream, including whispers. Switch to Quick mode while streaming if that matters to you.

---

## Good to know (WoW: Forever beta)

- **The beta forgets addon settings when you restart the game.** This is a Blizzard bug that affects every addon. To keep your settings, tick **Remember my settings after restart** in `/wt`. This stores them in one macro called `WoWTranslate`. If Blizzard fixes the bug, the addon notices and removes the macro.
- **Boss fights and rated matches:** during these, Blizzard hides other players' chat from all addons. Those lines are shown untouched, and translation starts again when the fight ends.
- **Item, quest and spell links** are shown with their names in your language, using the game's own data, so those are always exact. If you haven't seen an item before, its name might stay in the other language the first time.
- **Player names** written in other alphabets (like 小明 or Иван) show how to read them in Latin letters in their tooltip, for example "» Xiao Ming". This uses a feature built into the game client; if your client doesn't have it, nothing extra is shown. Their real name is never changed, so whispering and inviting still work.

---

## Commands

| Command | What it does |
|---|---|
| `/wt` | Open the options |
| `/wt on` / `/wt off` | Turn translation on or off |
| `/wt quick` / `/wt accurate` | Pick a mode |
| `/wt to de` | Translate into a language (`auto`, `en`, `de`, `fr`, `es`, `pt`, `ru`, `ko`, `zh`, `ja`) |
| `/wt write on` / `/wt write off` | Translate what you write |
| `/wt test <text>` | See how a message would be translated |
| `/wt link` | Help with Accurate mode (`/wt link test` sends a test to the app) |
| `/wt remember` | Keep settings after restarting the game |
| `/wt status` | Show what's on |

---

## Something's not working?

**Nothing gets translated.**
Type `/wt status`. Check that translation is on and the channel is ticked in `/wt`. Messages that are already in your language are left alone. Very short messages like "ok" or "gg" are left alone too.

**The translation is weird.**
In Quick mode that happens, since it translates phrase by phrase. Point at the [T] to see the original, or use Accurate mode.

**The Companion app says "Looking for WoW...".**
Make sure Accurate mode is on (`/wt accurate`), the game is in Windowed or Windowed (Fullscreen) mode, and the coloured line in the corner of the screen isn't covered by another window. If you use a big UI scale or a custom UI, try `/wt link size 4` to make the squares bigger, or `/wt link corner tr` to move them to another corner.

**The app says my key was refused.**
Copy the key again, without spaces. For Google, make sure the Cloud Translation API is enabled for your project.

**My settings reset every time I start the game.**
That's the beta bug described above. Tick **Remember my settings after restart** in `/wt`.

---

## Looking for the vanilla (1.12) version?

The original WoW 1.12 edition, with its DLL, is kept in [`legacy/vanilla`](legacy/vanilla/README.md). It isn't needed for WoW: Forever and shouldn't be used there.

---

## For developers

How it works, the WoW: Forever API details it relies on, the Companion link format, tests and the release process are in **[docs/TECHNICAL.md](docs/TECHNICAL.md)**.

---

## Support

WoW Translate is free and open source. If it helps you make friends across languages, you can support it through [GitHub Sponsors](https://github.com/sponsors/sanjaygbhat).

## License

MIT. See [LICENSE](LICENSE).
