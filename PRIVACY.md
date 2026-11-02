# Privacy Policy — Maps Desktop and its Chrome extension

_Last updated: November 2, 2026_

Maps Desktop (the Mac app) and Dark Maps by Maps Desktop (the Chrome extension) are open-source projects. Their full source code is published at <https://github.com/donsamoylov/maps-desktop>.

## The Chrome extension

- **What it does.** When a tab is about to open a Google Maps link (for example `google.com/maps/…`, `maps.google.com`, `maps.app.goo.gl/…`) or an Apple Maps link, the extension passes that one address to the Maps Desktop app installed on the same Mac, using the app's local link scheme `mapsdesktop://`. It may close the empty tab that was opened only for that link.
- **Dark theme.** On Google Maps pages (`www.google.com/maps`) the extension runs a script that changes how the page looks: it recolours the interface and the map. The script works inside the page only; it does not collect or send what you search, type or see.
- **What it reads.** Only the address of the page a tab is navigating to, and whether that tab is empty — to recognise map links. Apart from restyling Google Maps pages, it does not access page contents, form data, cookies, passwords or browsing history.
- **What it stores.** A few settings in Chrome's local extension storage: whether opening links in the app is on, the Google Maps theme, and whether to close the tab after a map opens in the app.
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
