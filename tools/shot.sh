#!/bin/zsh
# Отладка без доступа к экрану: выполнить скрипт в странице приложения и сохранить снимок страницы.
# tools/shot.sh имя 'js' [пауза_сек] → build/имя.png и build/имя.png.txt (адрес страницы)
cd "${0:A:h}/.."
S=$PWD/build/$1.png; rm -f $S $S.txt
defaults write io.github.donsamoylov.mapsdesktop GMSnapshot -string $S
defaults write io.github.donsamoylov.mapsdesktop GMEval -string "$2"
swift -e "import Foundation; let c = DistributedNotificationCenter.default(); c.postNotificationName(.init(\"io.github.donsamoylov.mapsdesktop.dev.eval\"), object: nil, userInfo: nil, deliverImmediately: true); RunLoop.main.run(until: Date().addingTimeInterval(${3:-3})); c.postNotificationName(.init(\"io.github.donsamoylov.mapsdesktop.dev.snapshot\"), object: nil, userInfo: nil, deliverImmediately: true); RunLoop.main.run(until: Date().addingTimeInterval(1))"
for i in $(seq 20); do [ -f $S ] && break; sleep 0.5; done
defaults delete io.github.donsamoylov.mapsdesktop GMEval
defaults delete io.github.donsamoylov.mapsdesktop GMSnapshot
