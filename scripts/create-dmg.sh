#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
app="$PWD/build/release/Daylight.app"
[[ -d "$app" ]] || { print -u2 'Build the universal app first with ./scripts/build.sh --universal'; exit 1; }
codesign --verify --strict "$app"
mkdir -p build dist
dmg_stage=$(mktemp -d "$PWD/build/.dmg.XXXXXX")
trap 'rm -rf "$dmg_stage"' EXIT
ditto "$app" "$dmg_stage/Daylight.app"
ln -s /Applications "$dmg_stage/Applications"
cat > "$dmg_stage/How to install.txt" <<'NOTES'
Welcome to Daylight

1. Drag Daylight.app onto the Applications folder shortcut.
2. Eject this disk image.
3. Open Daylight from Applications.

Updating? Quit Daylight first, then replace the existing app.
Your saved countdowns stay on your Mac.

This app is not notarized by Apple. If macOS blocks the first launch
and you trust your download, try opening the installed app, then use
System Settings > Privacy & Security > Open Anyway.

https://github.com/jplonghi/Daylight
NOTES
hdiutil create -volname Daylight -srcfolder "$dmg_stage" -format UDZO -fs HFS+ \
    -ov "$PWD/dist/Daylight-macOS-universal.dmg"
hdiutil verify "$PWD/dist/Daylight-macOS-universal.dmg"
