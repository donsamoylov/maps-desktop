# Chrome Web Store listing — Open in Maps Desktop

Everything to paste into the [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/devconsole).
Upload package: `build/maps-desktop-chrome-extension.zip` (made by `tools/pack_extension.sh`, also attached to every GitHub release).

## Store listing

**Name** (from the manifest): Open in Maps Desktop

**Summary** (≤132 chars, from the manifest):
Mac only. Open Google Maps links in the free Maps Desktop app instead of a browser tab. One click to pause.

**Description:**

Open Google Maps links in a real Mac app instead of yet another browser tab.

For Mac only: Maps Desktop is a macOS app, so on Windows, Linux and ChromeOS this extension does nothing.

Open in Maps Desktop is the companion extension for Maps Desktop — a free, open-source Google Maps app for macOS with a dark mode, natural trackpad gestures and its own window in the Dock. When you click a Google Maps link in Chrome — in Gmail, Slack, Telegram Web, a search result or a shared place — the extension hands it to Maps Desktop and the place, search or route opens there.

✔ Works with all Google Maps links: google.com/maps, maps.google.com, maps.app.goo.gl short links, places, searches, directions and coordinates
✔ Apple Maps links (maps.apple.com) open as the same place in Google Maps
✔ Reload a Google Maps tab to send it to the app too
✔ Click Cancel in Chrome’s prompt and the map simply opens in Chrome
✔ Optionally closes the Chrome tab once the map is open in the app — asked once, change it in the extension options
✔ Your default browser stays Chrome — nothing else changes
✔ One click on the toolbar button pauses or resumes it
✔ Want a map in Chrome after all? Use File ▸ Open in Browser in the app — the extension leaves that tab alone
✔ No data collection, no network requests, no tracking. Open source.

Requires the free Maps Desktop app for Mac (macOS 14 or later):
https://github.com/donsamoylov/maps-desktop/releases/latest

Right after you add the extension, a welcome page walks you through it: download Maps Desktop, click Connect, done. No app on this Mac yet? Instead of failing silently, the extension offers to download it or to open the map in Chrome.

Source code of the app and this extension, questions and bug reports:
https://github.com/donsamoylov/maps-desktop

When you click Connect (or the first map link), Chrome asks “Open Maps Desktop?” — tick “Always allow” and click Open.

Maps Desktop is an independent project and is not affiliated with, endorsed by or sponsored by Google LLC. Google Maps is a trademark of Google LLC.

**Category:** Productivity → Tools
**Language:** English

**Graphics** (in `store/`):
- Store icon 128×128: `chrome-extension/icons/128.png`
- Screenshots 1280×800: `store/screenshot-1.png`, `store/screenshot-2.png`
- Small promo tile 440×280: `store/promo-small.png`

**Website:** https://github.com/donsamoylov/maps-desktop
**Support:** https://github.com/donsamoylov/maps-desktop/issues

## Privacy tab

**Single purpose:**
Opens Google Maps links in the Maps Desktop app for Mac instead of a browser tab.

**Permission justification:**
- `webNavigation` — to notice when a tab starts navigating to a Google Maps or Apple Maps link, so that link can be passed to the Maps Desktop app before the page loads.
- `tabs` — to read the addresses of tabs that were already open when the extension started (so a tab where the user is already working with Google Maps is left alone) and to redirect the link to the app.
- `storage` — to remember one setting: whether the extension is turned on or off.

**Remote code:** No, I am not using remote code. All code is in the package.

**Data usage:** The extension does not collect or use any user data. Tick none of the data types. Certify:
- I do not sell or transfer user data to third parties, outside of the approved use cases
- I do not use or transfer user data for purposes that are unrelated to my item's single purpose
- I do not use or transfer user data to determine creditworthiness or for lending purposes

**Privacy policy URL:** https://github.com/donsamoylov/maps-desktop/blob/main/PRIVACY.md

## Distribution

Visibility: Public. Regions: All regions. Pricing: Free.

## Store page

https://chromewebstore.google.com/detail/open-in-maps-desktop/hnbhfnadfajjbilkkmpennlmlkbhjefa — linked from the app
(`ChromeExtension.storeURL`, menu Help) and the README.
