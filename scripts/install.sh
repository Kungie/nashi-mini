#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Build outside the repository: codesign rejects the attributes iCloud Drive adds to synced folders.
build=${NASHI_MINI_BUILD:-"$HOME/Library/Caches/nashi-mini-build"}
target="/Applications/Nashi Mini.app"
scripts/setup-exiftool.sh
swift build -c release --product NashiMini --scratch-path "$build"
binaries=$(swift build -c release --product NashiMini --scratch-path "$build" --show-bin-path)
stage="$build/Nashi Mini.app"
contents="$stage/Contents"
rm -rf "$stage"
mkdir -p "$contents/MacOS" "$contents/Resources/Tools"
cp "$binaries/NashiMini" "$contents/MacOS/NashiMini"
/usr/bin/strip -S "$contents/MacOS/NashiMini"
cp Resources/Info.plist "$contents/Info.plist"
cp Resources/NashiIcon.icns Resources/PagesInterop.js Resources/PDFLib.js Resources/PDFInterop.js Resources/THIRD-PARTY-NOTICES.txt "$contents/Resources/"
ditto Resources/Sounds "$contents/Resources/Sounds"
ditto Resources/licenses "$contents/Resources/licenses"
ditto "$binaries/NashiMini_NashiCore.bundle" "$contents/Resources/NashiMini_NashiCore.bundle"
ditto Tools/ExifTool "$contents/Resources/Tools/ExifTool"
xattr -cr "$stage"
codesign --force --sign - --options 0 --timestamp=none "$stage"
pkill -x NashiMini || true
rm -rf "$target"
ditto "$stage" "$target"
codesign --verify --deep --strict "$target"
open "$target"
print "Installed $target"
