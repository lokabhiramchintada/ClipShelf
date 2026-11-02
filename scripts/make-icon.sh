#!/bin/bash
# Regenerates Resources/AppIcon.icns and docs/icon.png from scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

SDK="${SDK:-}"
if [[ -z "$SDK" ]]; then
    for candidate in "$(xcrun --show-sdk-path)" $(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV); do
        if swiftc -sdk "$candidate" scripts/make-icon.swift -o build/make-icon 2>/dev/null; then SDK="$candidate"; break; fi
    done
else
    swiftc -sdk "$SDK" scripts/make-icon.swift -o build/make-icon
fi
[[ -n "$SDK" ]] || { echo "Could not compile make-icon.swift" >&2; exit 1; }

mkdir -p build docs
build/make-icon build/icon-1024.png

ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size build/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) build/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
sips -z 256 256 build/icon-1024.png --out docs/icon.png >/dev/null
echo "Wrote Resources/AppIcon.icns and docs/icon.png"
