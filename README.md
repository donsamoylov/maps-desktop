<p align="center">
  <img src="docs/icon.png" width="160" alt="Maps Desktop icon — dark Google Maps app for Mac">
</p>

<h1 align="center">Maps Desktop — Google Maps app for Mac with dark mode</h1>

<p align="center">
  <b>The Google Maps desktop app macOS never had.</b><br>
  Full Google Maps in a native Mac window, with a real dark mode, trackpad gestures and map links that open right in the app.
</p>

<p align="center">
  <a href="https://github.com/donsamoylov/maps-desktop/releases/latest/download/MapsDesktop.zip"><img src="https://img.shields.io/github/v/release/donsamoylov/maps-desktop?label=Download%20for%20Mac&style=for-the-badge&labelColor=2f6fe4&color=5b8cff" alt="Download Maps Desktop for Mac"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-141b2e" alt="macOS 14 Sonoma or later">
  <img src="https://img.shields.io/badge/Apple%20Silicon%20%26%20Intel-universal-141b2e" alt="Universal app for Apple Silicon and Intel Macs">
</p>

---

Google has no official Google Maps app for Mac, and the website in a browser tab has no dark mode, swallows trackpad swipes and gets lost among other tabs. **Maps Desktop** puts the complete Google Maps website — search, directions, Street View, reviews, saved places and your Google account — into its own lightweight Mac app and fixes exactly those things.

## Features

- 🌙 **Dark mode for Google Maps** — a dark theme for the whole interface and the map, with cool night-blue map colours. Photos, satellite view and Street View keep their real colours. Follows the macOS appearance automatically, or pick Light / Dark in the **Appearance** menu.
- 🖐 **Trackpad gestures that make sense** — two-finger swipe pans the map like on a phone, pinch zooms, lists and panels scroll normally. In a browser, two-finger scroll only zooms Google Maps.
- 🔗 **Open Google Maps links in the app** — `google.com/maps`, `maps.google.com`, `maps.app.goo.gl` short links and even Apple Maps links clicked in Chrome open in Maps Desktop, as do `comgooglemaps://` and `geo:` links from any app. Links to other sites from inside the map open in your usual browser.
- 🧩 **Chrome extension** — that's what sends Chrome's map links to the app; your default browser stays the same.
- 📍 **My Location works** — Maps Desktop asks macOS for location access and passes your position to Google Maps, so the “show my location” button works on a Mac.
- 🔄 **Automatic updates** — new versions are downloaded from GitHub Releases and checked against a cryptographic signature before installing.
- 🌐 **Your language** — the app follows the macOS language (English and Russian included); Google Maps itself uses your system language too.
- 🪶 **Native and light** — under 2 MB, built with Swift, AppKit and WebKit. No Electron, no tracking, no API keys.
- ⌨️ **Mac keyboard shortcuts** — ⌘L / ⌘F search, ⇧⌘C copy link to the current place, ⇧⌘O open in browser, ⌘R reload, ⌘[ / ⌘] back and forward.

## Download and install

1. **[Download MapsDesktop.zip](https://github.com/donsamoylov/maps-desktop/releases/latest/download/MapsDesktop.zip)** — always the latest version, about 1 MB. Open it and macOS unzips **Maps Desktop.app** next to it.
2. Drag **Maps Desktop.app** into **Applications**.
3. Open it. The first time, macOS says it can't verify the developer, because Maps Desktop isn't notarized by Apple. Click **Done**, open **System Settings ▸ Privacy & Security**, scroll down and click **Open Anyway**. Or run once:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Maps Desktop.app"
   ```
4. Sign in to your Google account inside Maps Desktop to see saved places and history.
5. Using Chrome? Accept the offer to add the **Open in Maps Desktop** extension, and Google Maps links you click in Chrome will open in the app ([details below](#open-google-maps-links-from-chrome)).

Updates install themselves from then on; to check right away, choose **Maps Desktop ▸ Check for Updates…**. Older versions are on the [Releases](../../releases) page.

### Open Google Maps links from Chrome

The **Open in Maps Desktop** extension hands Google Maps links you click in Chrome — in Gmail, Slack, Telegram Web, search results or links other apps open in Chrome — to the app. Your default browser stays the same. Like the app, it's for Mac only: on Windows, Linux or ChromeOS it does nothing.

**[Install Open in Maps Desktop from the Chrome Web Store](https://chromewebstore.google.com/detail/open-in-maps-desktop/hnbhfnadfajjbilkkmpennlmlkbhjefa)**

How the app and the extension find each other:

1. **From the app.** On first launch (if Chrome is installed) Maps Desktop offers the extension; later it's in **Maps Desktop ▸ Install Chrome Extension…** and **Help ▸ Chrome Extension in Chrome Web Store**. **Install…** opens the extension in the Chrome Web Store — click **Add to Chrome**.
2. **From the extension.** Right after it's added, the extension opens a welcome page with a **Download Maps Desktop** button for those who don't have the app yet, and **Connect**. Connect opens the app: Chrome asks “Open Maps Desktop?” — tick **Always allow** and click **Open** — and Maps Desktop confirms that Chrome is connected.
3. **Then** just click Google Maps links in Chrome. If the app isn't on this Mac, the extension doesn't fail silently: it offers to download Maps Desktop or to open the map in Chrome.

The extension's source is in [`chrome-extension/`](chrome-extension).

The first time a map opens in the app, the extension asks whether to close the Chrome tab from then on; change the answer in the extension's options. Click the extension's toolbar button to pause or resume it. **File ▸ Open in Browser** in the app opens the current map in Chrome, and the extension leaves that tab alone.

## FAQ

**Is there an official Google Maps app for Mac?**
No. Google offers Google Maps on the web, iPhone and Android only. Maps Desktop is an unofficial desktop app that shows the real Google Maps website.

**How do I open Google Maps links in an app instead of a browser on Mac?**
Install the [Open in Maps Desktop](https://chromewebstore.google.com/detail/open-in-maps-desktop/hnbhfnadfajjbilkkmpennlmlkbhjefa) extension for Chrome — see above.

**How do I get Google Maps dark mode on a Mac?**
The Google Maps website has no dark mode on desktop. Maps Desktop adds one that switches together with macOS.

**Does it need a Google Maps API key?**
No. It is the regular Google Maps website, so search, directions, Street View and your account work as usual.

**Why does a two-finger swipe move the map instead of zooming?**
That's the point: in Maps Desktop the trackpad behaves like in Apple Maps. Pinch to zoom.

**Is it safe?**
The source code is here, builds run on GitHub Actions, and every update is signed — the app refuses an update whose signature doesn't match.

## Build from source

Requires macOS 14+ and the Xcode Command Line Tools.

```bash
git clone https://github.com/donsamoylov/maps-desktop.git
cd maps-desktop
./build.sh --install
```

Releases are built by GitHub Actions when a `v*` tag is pushed — see [`.github/workflows/release.yml`](.github/workflows/release.yml).

## По-русски

**Maps Desktop — Google Карты для Mac с темной темой.** Полноценные Google Карты в отдельном окне macOS: темная тема в холодных тонах, которая переключается вместе с системой; свайп двумя пальцами двигает карту, щипок масштабирует; ссылки на Google Карты из Chrome (через расширение), Telegram, почты и других приложений открываются прямо в приложении; работает «Где я»; обновления приходят сами. Приложение при первом запуске предлагает поставить расширение для Chrome, а расширение сразу после установки помогает скачать приложение и подключить его одной кнопкой. Язык интерфейса — как в системе.

Приложение и расширение — только для Mac.

**Установка:** [скачайте Maps Desktop для Mac](https://github.com/donsamoylov/maps-desktop/releases/latest/download/MapsDesktop.zip), откройте архив и перенесите **Maps Desktop.app** в **Программы**. В первый раз macOS не даст открыть приложение от непроверенного разработчика: нажмите **Готово**, затем **Системные настройки ▸ Конфиденциальность и безопасность ▸ Все равно открыть**.

---

<sub>Maps Desktop is an independent open-source project. It is not affiliated with, endorsed by or sponsored by Google LLC. Google Maps is a trademark of Google LLC; the app simply displays the public Google Maps website, and its use is subject to Google's terms.</sub>
