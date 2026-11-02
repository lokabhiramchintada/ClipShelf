#!/bin/bash
# Usage:
#   ./build.sh            build build/ClipShelf.app for this Mac
#   ./build.sh test       build and run the test suite
#   ./build.sh install    build, copy to /Applications and launch
#   ./build.sh release    build a universal (Apple Silicon + Intel) app and zip it for distribution
#
# Uses swiftc directly so it works with just the Command Line Tools, even when SwiftPM doesn't.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ClipShelf.app"
MIN_MACOS="14.0"
NATIVE_ARCH="$(uname -m)"

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
        if swiftc -typecheck -target "$NATIVE_ARCH-apple-macos$MIN_MACOS" -sdk "$sdk" build/sdk-probe.swift 2>/dev/null; then
            echo "$sdk"
            return
        fi
    done
    echo "No usable macOS SDK found" >&2
    exit 1
}

SDK="$(find_sdk)"

# swiftc_for <arch> <args...>
swiftc_for() {
    local arch="$1"; shift
    swiftc -target "$arch-apple-macos$MIN_MACOS" -sdk "$SDK" "$@"
}

# build_core <arch> <outdir> <extra flags...>: compiles ClipShelfCore into a static library + module.
build_core() {
    local arch="$1" out="$2"; shift 2
    mkdir -p "$out"
    swiftc_for "$arch" "$@" -parse-as-library -emit-library -static \
        -module-name ClipShelfCore -emit-module -emit-module-path "$out/ClipShelfCore.swiftmodule" \
        Sources/ClipShelfCore/*.swift -o "$out/libClipShelfCore.a"
}

# build_app <archs...>: builds the executable for each arch, merges them and assembles the .app.
build_app() {
    local binaries=()
    for arch in "$@"; do
        echo "Building ClipShelf for $arch ($(basename "$SDK"))…"
        local out="build/release/$arch"
        build_core "$arch" "$out" -O
        swiftc_for "$arch" -O -I "$out" -L "$out" -lClipShelfCore \
            -module-name ClipShelf Sources/ClipShelf/*.swift -o "$out/ClipShelf"
        binaries+=("$out/ClipShelf")
    done

    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    lipo -create "${binaries[@]}" -output "$APP/Contents/MacOS/ClipShelf"
    cp Resources/Info.plist "$APP/Contents/Info.plist"
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    codesign --force --sign - --identifier com.lokabhiram.ClipShelf "$APP"
    echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/ClipShelf"))"
}

run_tests() {
    echo "Building tests ($(basename "$SDK"))…"
    build_core "$NATIVE_ARCH" build/test -Onone -enable-testing
    swiftc_for "$NATIVE_ARCH" -Onone -I build/test -L build/test -lClipShelfCore \
        -module-name ClipShelfTests Tests/ClipShelfTests/*.swift -o build/test/ClipShelfTests
    build/test/ClipShelfTests
}

case "${1:-}" in
    test)
        run_tests
        ;;
    install|--install)
        build_app "$NATIVE_ARCH"
        pkill -x ClipShelf 2>/dev/null || true
        rm -rf /Applications/ClipShelf.app
        cp -R "$APP" /Applications/
        open /Applications/ClipShelf.app
        echo "Installed to /Applications/ClipShelf.app"
        ;;
    release)
        run_tests
        build_app arm64 x86_64
        VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
        ZIP="build/ClipShelf-$VERSION.zip"
        rm -f "$ZIP"
        ditto -c -k --keepParent "$APP" "$ZIP"
        echo "Packaged $ZIP"
        ;;
    "")
        build_app "$NATIVE_ARCH"
        ;;
    *)
        echo "Usage: $0 [test|install|release]" >&2
        exit 1
        ;;
esac
