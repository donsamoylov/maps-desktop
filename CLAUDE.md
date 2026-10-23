# Maps Desktop

Mac-приложение для сайта Google Карт: Swift + AppKit + WebKit, без Xcode-проекта. Неофициальное —
в имени и иконке нет слова и логотипа Google, «for Google Maps» только в описаниях.

## Сборка и релиз

- `./build.sh [--install] [--zip]` — универсальная сборка (arm64 + x86_64) в `build/Maps Desktop.app`,
  нужны только Command Line Tools. Переменные: `VERSION`, `BUILD`, `SIGN_ID`.
- Релиз: `git tag vX.Y.Z && git push origin vX.Y.Z` — GitHub Actions (`.github/workflows/release.yml`)
  подписывает сертификатом «Maps Desktop Developer», кладет `MapsDesktop.zip`, `MapsDesktop.zip.sig`
  и `maps-desktop-chrome-extension.zip`. Приложения обновляются сами (`Sources/Updater.swift`).
- После релиза проверять: скачать, `swift tools/update_key.swift verify …`, `codesign -dvv`, версия.
- Ключи — `~/Developer/MapsDesktop-keys`, в репозиторий не класть. Секреты в GitHub (`MAPSDESKTOP_*`)
  вводит владелец сам.
- GitHub с этого Мака открывается только с включенным VPN; `git push`/`gh` запускать вне песочницы.

## Как устроено

- `Sources/DarkTheme.swift` — темная тема: интерфейс — инверсией `invert(0.9) hue-rotate(180deg)`, фото
  переворачиваются обратно. Холст карты стоит вне фильтра страницы: фильтр получают соседи цепочки
  предков холста (`gm-chain`, `gm-flt`; прозрачные static-обертки пропускаются, чтобы панели с z-index
  оставались над картой), поэтому цвет на холсте — ровно цвет на экране. Темную схему рисуют шейдеры
  Google: в шейдеры карты дописан перевод цвета (таблица цветов iPhone, затененное — по ближайшему
  оттенку, насыщенное — как в светлой теме, остальное — как при инверсии), в шейдер значков — пастель,
  в шейдер космоса — темный фон, в шейдер текстур — приглушенная сетка загрузки; копирование на экран и
  плашка над маршрутом не трогаются. Фреймы чужого источника (карточка аккаунта Google) затемняются изнутри.
- `Sources/MapWebView.swift` — свайп двумя пальцами по карте превращается в перетаскивание, инерция —
  от macOS; щипок передается Google как прокрутка с Ctrl, как это делает Chrome. Сайту приложение
  представляется Chrome (`MapWindow.swift`): так у Google не моргают подписи.
- `Sources/LocationBridge.swift` — геолокация страницы берется у macOS.
- `chrome-extension/` — расширение «Open in Maps Desktop»: ссылки на карты из Chrome →
  `mapsdesktop://open?url=…`. Лежит внутри приложения, при запуске копируется в
  `~/Library/Application Support/Maps Desktop/Chrome Extension` (`Sources/ChromeExtension.swift`).
- `store/` и `PRIVACY.md` — пакет для Chrome Web Store.

## Отладка без доступа к экрану

`tools/shot.sh имя 'js' [пауза]` — выполнить скрипт в странице запущенного приложения и сохранить
снимок `build/имя.png` (+ адрес и счетчики в `.txt`). Снимок не показывает фильтры поверх
фреймов чужого источника — карточку аккаунта проверять по скриншоту владельца.
Расширение в Chrome — через MCP `chrome-devtools` (`.mcp.json`), владелец включает
`chrome://inspect/#remote-debugging`.

## Тексты

Интерфейс на языке системы: ключи — английский текст, переводы в `Resources/*.lproj`.
В русских текстах не использовать букву «ё».
