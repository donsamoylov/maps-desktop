# Privacy Policy — Maps Desktop and “Open in Maps Desktop”

_Last updated: October 22, 2026_

Maps Desktop (the Mac app) and Open in Maps Desktop (the Chrome extension) are open-source projects. Their full source code is published at <https://github.com/donsamoylov/maps-desktop>.

## The Chrome extension

- **What it does.** When a tab is about to open a Google Maps link (for example `google.com/maps/…`, `maps.google.com`, `maps.app.goo.gl/…`) or an Apple Maps link, the extension passes that one address to the Maps Desktop app installed on the same Mac, using the app's local link scheme `mapsdesktop://`. It may close the empty tab that was opened only for that link.
- **What it reads.** Only the address of the page a tab is navigating to, and whether that tab is empty — to recognise map links. It does not read page contents, form data, cookies, passwords or browsing history.
- **What it stores.** One setting in Chrome's local extension storage: whether the extension is turned on or off.
- **What it sends.** Nothing. The extension makes no network requests and has no servers, analytics, ads or tracking. The map link goes only to the Maps Desktop app on your own computer.
- **Sharing.** No data is sold, shared or transferred to anyone.

## The Mac app

- The app shows the public Google Maps website in a native window. What you do on Google Maps is handled by Google under [Google's Privacy Policy](https://policies.google.com/privacy).
- **Location.** If you allow it in macOS, the app passes your location to the Google Maps page only when that page asks for it (for example when you press “Show your location”).
- **Updates.** The app checks `api.github.com` for a newer release of Maps Desktop and downloads it from GitHub. No personal data is sent; GitHub receives a standard request like any web browser would make.
- The app has no analytics, ads or tracking of its own.

## Contact

Questions or concerns: open an issue at <https://github.com/donsamoylov/maps-desktop/issues>.

Maps Desktop is not affiliated with, endorsed by or sponsored by Google LLC. Google Maps is a trademark of Google LLC.
