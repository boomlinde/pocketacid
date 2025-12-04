#!/bin/bash

set -e

NAME=pocketacid
VERSION="$(git describe --always)"
ZIG_VERSION=0.14.1
SDL2_WINDOWS_VERSION=2.32.6

[ ! -d prereqs ] && mkdir prereqs
[ -d release ] && rm -rf release

pushd prereqs

if [ ! -d SDL2 ]; then
	# Get SDL2 windows devel release
	wget https://github.com/libsdl-org/SDL/releases/download/release-$SDL2_WINDOWS_VERSION/SDL2-devel-$SDL2_WINDOWS_VERSION-VC.zip
	unzip SDL2-devel-$SDL2_WINDOWS_VERSION-VC.zip
	rm SDL2-devel-$SDL2_WINDOWS_VERSION-VC.zip
	mv SDL2-$SDL2_WINDOWS_VERSION SDL2
fi

if [ ! -d zig ]; then
	# Get Zig
	wget https://ziglang.org/download/$ZIG_VERSION/zig-x86_64-linux-$ZIG_VERSION.tar.xz
	tar xf zig-x86_64-linux-$ZIG_VERSION.tar.xz
	rm zig-x86_64-linux-$ZIG_VERSION.tar.xz
	mv zig-x86_64-linux-$ZIG_VERSION zig
fi

popd

mkdir -p release/$NAME-$VERSION
prereqs/zig/zig build -Dcpu=core2 -Doptimize=ReleaseFast -Dtarget=x86_64-windows --verbose
cp zig-out/bin/$NAME.exe release/$NAME-$VERSION/
cp prereqs/SDL2/lib/x64/SDL2.dll release/$NAME-$VERSION/

mkdir release/$NAME-$VERSION/licenses
cp prereqs/SDL2/README-SDL.txt release/$NAME-$VERSION/licenses/
cp prereqs/zig/LICENSE release/$NAME-$VERSION/licenses/zig.license.txt
cp COPYING release/$NAME-$VERSION/licenses/pocketacid.license.txt

cp README.md release/$NAME-$VERSION/README.txt
(cd release && zip -r $NAME-$VERSION.win64.zip "$NAME-$VERSION")
rm -rf release/$NAME-$VERSION

(
	export PKG_CONFIG_PATH=$PWD/r36xx/usr/lib/pkgconfig
	export PKG_CONFIG_SYSROOT_DIR=$PWD/r36xx/
	prereqs/zig/zig build \
		-Doptimize=ReleaseFast \
		-Dtarget=aarch64-linux-gnu \
		-Dcpu=cortex_a35 \
		--search-prefix $PWD/r36xx/usr/

	mkdir -p release/portmaster
	cp -rf portmaster/* release/portmaster
	cp zig-out/bin/$NAME release/portmaster/$NAME/$NAME.aarch64
	cp README.md release/portmaster/$NAME/
	mkdir release/portmaster/$NAME/licenses/
	cp prereqs/zig/LICENSE release/portmaster/$NAME/licenses/zig.license.txt
	cp README-SDL.txt release/portmaster/$NAME/licenses/
	cp COPYING release/portmaster/$NAME/licenses/$NAME.license.txt
	cp README.md release/portmaster/$NAME/
	(cd release/portmaster && zip -r ../$NAME-$VERSION.portmaster.zip .)
	rm -rf release/portmaster
)
