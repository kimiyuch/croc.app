#!/bin/zsh
# Builds Croc.app and packages it as build/Croc.dmg (drag-to-Applications installer).
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

STAGING=build/dmg
DMG=build/Croc.dmg
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R build/Croc.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname Croc -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"
echo "Built $DMG"
