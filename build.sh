#!/bin/bash
# Usage:
#   ./build.sh            build build/ClipShelf.app
#   ./build.sh test       build and run the test suite
#   ./build.sh install    build, copy to /Applications and launch
#
# Uses swiftc directly so it works with just the Command Line Tools, even when SwiftPM doesn't.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ClipShelf.app"
ARCH="$(uname -m)"
TARGET="$ARCH-apple-macos14.0"

# Pick an SDK the compiler can use. Try the default first, then installed SDKs newest-first,
# since Command Line Tools sometimes ship an SDK newer than the compiler supports.
find_sdk() {
    local candidates=("$(xcrun --show-sdk-path)")
    for sdk in $(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV); do
        candidates+=("$sdk")
    done
    mkdir -p build
    echo 'import AppKit' > build/sdk-probe.swift
    for sdk in "${candidates[@]}"; do
        if swiftc -typecheck -target "$TARGET" -sdk "$sdk" build/sdk-probe.swift 2>/dev/null; then
            echo "$sdk"
            return
        fi
    done
    echo "No usable macOS SDK found" >&2
    exit 1
}

SDK="$(find_sdk)"
SWIFTC=(swiftc -target "$TARGET" -sdk "$SDK")

# build_core <outdir> <extra flags...>: compiles ClipShelfCore into a static library + module.
build_core() {
    local out="$1"; shift
    mkdir -p "$out"
    "${SWIFTC[@]}" "$@" -parse-as-library -emit-library -static \
        -module-name ClipShelfCore -emit-module -emit-module-path "$out/ClipShelfCore.swiftmodule" \
        Sources/ClipShelfCore/*.swift -o "$out/libClipShelfCore.a"
}

build_app() {
    echo "Building ClipShelf ($(basename "$SDK"))…"
    build_core build/release -O
    "${SWIFTC[@]}" -O -I build/release -L build/release -lClipShelfCore \
        -module-name ClipShelf Sources/ClipShelf/*.swift -o build/release/ClipShelf

    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    cp build/release/ClipShelf "$APP/Contents/MacOS/ClipShelf"
    cp Resources/Info.plist "$APP/Contents/Info.plist"
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    codesign --force --sign - --identifier com.lokabhiram.ClipShelf "$APP"
    echo "Built $APP"
}

run_tests() {
    echo "Building tests ($(basename "$SDK"))…"
    build_core build/test -Onone -enable-testing
    "${SWIFTC[@]}" -Onone -I build/test -L build/test -lClipShelfCore \
        -module-name ClipShelfTests Tests/ClipShelfTests/*.swift -o build/test/ClipShelfTests
    build/test/ClipShelfTests
}

case "${1:-}" in
    test)
        run_tests
        ;;
    install|--install)
        build_app
        pkill -x ClipShelf 2>/dev/null || true
        rm -rf /Applications/ClipShelf.app
        cp -R "$APP" /Applications/
        open /Applications/ClipShelf.app
        echo "Installed to /Applications/ClipShelf.app"
        ;;
    "")
        build_app
        ;;
    *)
        echo "Usage: $0 [test|install]" >&2
        exit 1
        ;;
esac
