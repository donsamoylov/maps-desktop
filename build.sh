#!/bin/zsh
# Сборка Maps Desktop. Нужны только Command Line Tools (или Xcode).
#   ./build.sh                 — собрать build/Maps Desktop.app
#   ./build.sh --install       — и поставить в ~/Applications
#   ./build.sh --zip           — и упаковать build/MapsDesktop.zip для релиза
# Переменные: VERSION (1.2.0), BUILD (номер сборки), SIGN_ID (имя сертификата подписи; по умолчанию ad-hoc).
set -euo pipefail
cd "${0:A:h}"
VERSION=${VERSION:-0.0.0}
BUILD=${BUILD:-0}
APP="build/Maps Desktop.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset

# Универсальная сборка: Apple Silicon и Intel.
for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos14 -framework AppKit -framework WebKit -framework CoreLocation \
    Sources/*.swift -o build/MapsDesktop-$arch
done
lipo -create build/MapsDesktop-arm64 build/MapsDesktop-x86_64 -output "$APP/Contents/MacOS/MapsDesktop"
rm build/MapsDesktop-arm64 build/MapsDesktop-x86_64

swift make_icon.swift build/AppIcon.iconset >/dev/null
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
sed "s/__VERSION__/$VERSION/; s/__BUILD__/$BUILD/" Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
# Расширение для Chrome — внутри приложения, при запуске копируется в папку, откуда его читает Chrome.
ditto chrome-extension "$APP/Contents/Resources/ChromeExtension"

# Подпись. Постоянный сертификат нужен, чтобы после обновлений macOS помнил разрешения (геолокация).
codesign --force --timestamp=none --sign "${SIGN_ID:--}" "$APP"
codesign --verify --strict "$APP"
# Копия в build/ не должна числиться у macOS отдельным приложением — иначе ссылки могут уйти ей.
$LSREGISTER -u "$PWD/$APP" 2>/dev/null || true

for arg in "$@"; do
  case $arg in
    --install)
      rm -rf ~/Applications/"Maps Desktop.app"
      cp -R "$APP" ~/Applications/
      $LSREGISTER -f ~/Applications/"Maps Desktop.app"
      echo "Установлено: ~/Applications/Maps Desktop.app"
      ;;
    --zip)
      ditto -c -k --keepParent "$APP" build/MapsDesktop.zip
      echo "Архив: build/MapsDesktop.zip"
      ;;
  esac
done
