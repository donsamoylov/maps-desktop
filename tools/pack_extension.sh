#!/bin/zsh
# Упаковывает расширение для Chrome Web Store и релизов: build/maps-desktop-chrome-extension.zip
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p build
rm -f build/maps-desktop-chrome-extension.zip
(cd chrome-extension && zip -qrX ../build/maps-desktop-chrome-extension.zip manifest.json background.js handoff.html handoff.js common.js welcome.html welcome.js options.html options.js _locales icons -x '.*')
echo "Архив расширения: build/maps-desktop-chrome-extension.zip"
