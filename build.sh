#!/bin/bash
# Builds Croc.app from source. Needs Xcode or the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

scripts/fetch-ffmpeg.sh
scripts/fetch-sparkle.sh
SPARKLE=vendor/sparkle-2.10.0

echo "Compiling…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Croc"

APP="build/Croc.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Croc"
cp Resources/bin/ffmpeg "$APP/Contents/MacOS/ffmpeg"   # GPLv3, see scripts/fetch-ffmpeg.sh
cp Info.plist "$APP/Contents/Info.plist"
# Where the app looks for updates; CROC_FEED_URL overrides it (e.g. for testing an update locally).
if [[ -n ${CROC_FEED_URL:-} ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUFeedURL $CROC_FEED_URL" "$APP/Contents/Info.plist"
fi
ditto "$SPARKLE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"   # MIT
mkdir -p "$APP/Contents/Resources/Licenses/Sparkle"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Licenses/Sparkle/"
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"   # Figtree, SIL Open Font License (OFL.txt)

echo "Making the icon…"
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "Signing (ad hoc, for this Mac)…"
# Inside out: Sparkle's helpers, the framework, ffmpeg, then the app.
S="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --sign - "$S/XPCServices/Installer.xpc" "$S/XPCServices/Downloader.xpc" "$S/Autoupdate" "$S/Updater.app"
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP/Contents/MacOS/ffmpeg"
codesign --force --sign - "$APP"

echo
echo "Done: $(pwd)/$APP"
echo "Install it with:  rm -rf /Applications/Croc.app && mv \"$APP\" /Applications/ && open /Applications/Croc.app"
