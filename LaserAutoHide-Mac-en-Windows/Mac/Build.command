#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Installeer eerst de Apple Command Line Tools: xcode-select --install'
  exit 1
fi
mkdir -p LaserAutoHide.app/Contents/MacOS
echo 'LaserAutoHide bouwen voor deze Mac…'
xcrun swiftc -swift-version 5 -O -framework Cocoa -framework Carbon -framework ApplicationServices LaserAutoHide.swift -o LaserAutoHide.app/Contents/MacOS/LaserAutoHide
cp Info.plist LaserAutoHide.app/Contents/Info.plist
codesign --force --sign - LaserAutoHide.app
echo 'Gereed. Verplaats LaserAutoHide.app naar Programmas en open de app daar.'
echo 'Geef de app toegang tot Toegankelijkheid en tot PowerPoint (Automatisering).'
