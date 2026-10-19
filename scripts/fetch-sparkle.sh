#!/bin/zsh
# Downloads Sparkle (the update framework and its signing tools) into vendor/ (git-ignored), like Joey.
# https://sparkle-project.org, MIT license.
# To update: change VERSION and SHA256 (of Sparkle-$VERSION.tar.xz), and the path in Package.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=2.10.0
SHA256=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
URL="https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz"
DEST=vendor/sparkle-$VERSION

[[ -d $DEST/Sparkle.framework ]] && exit 0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "Downloading Sparkle $VERSION…"
curl -fsSL "$URL" -o "$TMP/sparkle.tar.xz"
echo "$SHA256  $TMP/sparkle.tar.xz" | shasum -a 256 -c --quiet
mkdir -p "$DEST"
tar -xJf "$TMP/sparkle.tar.xz" -C "$DEST"
echo "Fetched $DEST"
