#!/bin/zsh
# Downloads the static arm64 ffmpeg that Croc bundles into Resources/bin (git-ignored).
# Builds by Martin Riedl (https://ffmpeg.martin-riedl.de), GPLv3, with libx264, libvpx and libopus.
# To update: change VERSION, BUILD and SHA256 to a newer release from that page.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=9.0.2
BUILD=1789931890
SHA256=c8ed4c4e6978a03c485edbfe4e0a5dc2380f8a30bba5150531b31b094492d924
URL="https://ffmpeg.martin-riedl.de/download/macos/arm64/${BUILD}_${VERSION}/ffmpeg.zip"
DEST=Resources/bin

if [[ -x $DEST/ffmpeg ]] && $DEST/ffmpeg -hide_banner -version | head -1 | grep -q "version $VERSION-"; then
  echo "ffmpeg $VERSION is already in $DEST"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "Downloading ffmpeg $VERSION…"
curl -fsSL "$URL" -o "$TMP/ffmpeg.zip"
echo "$SHA256  $TMP/ffmpeg.zip" | shasum -a 256 -c --quiet
unzip -q "$TMP/ffmpeg.zip" -d "$TMP"
mkdir -p "$DEST"
mv "$TMP/ffmpeg" "$DEST/ffmpeg"
chmod +x "$DEST/ffmpeg"
xattr -c "$DEST/ffmpeg"
echo "Fetched $DEST/ffmpeg"
