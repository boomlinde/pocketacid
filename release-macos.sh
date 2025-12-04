#!/bin/bash

set -e

NAME=pocketacid
VERSION="$(git describe --always)"
ZIG_VERSION=0.14.1

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    ZIG_ARCH="aarch64"
    MACOS_TARGET="aarch64-macos"
else
    ZIG_ARCH="x86_64"
    MACOS_TARGET="x86_64-macos"
fi

[ ! -d prereqs ] && mkdir prereqs
[ -d release ] && rm -rf release

pushd prereqs

# Get SDL2 via Homebrew
if ! brew list sdl2 &>/dev/null; then
    brew install sdl2
fi

if [ ! -d zig ]; then
    # Get Zig for macOS
    curl -LO "https://ziglang.org/download/$ZIG_VERSION/zig-$ZIG_ARCH-macos-$ZIG_VERSION.tar.xz"
    tar xf "zig-$ZIG_ARCH-macos-$ZIG_VERSION.tar.xz"
    rm "zig-$ZIG_ARCH-macos-$ZIG_VERSION.tar.xz"
    mv "zig-$ZIG_ARCH-macos-$ZIG_VERSION" zig
fi

popd

mkdir -p "release/$NAME-$VERSION"
prereqs/zig/zig build -Doptimize=ReleaseFast -Dtarget="$MACOS_TARGET" --verbose

cp "zig-out/bin/$NAME" "release/$NAME-$VERSION/"

mkdir -p "release/$NAME-$VERSION/licenses"
cp prereqs/zig/LICENSE "release/$NAME-$VERSION/licenses/zig.license.txt"
cp COPYING "release/$NAME-$VERSION/licenses/pocketacid.license.txt"

cp README.md "release/$NAME-$VERSION/README.txt"

(cd release && zip -r "$NAME-$VERSION.macos-$ZIG_ARCH.zip" "$NAME-$VERSION")
rm -rf "release/$NAME-$VERSION"