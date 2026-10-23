#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
if [[ -n "${1:-}" && "$1" != "v$version" ]]; then
    print -u2 "Tag $1 does not match app version v$version"
    exit 1
fi
./scripts/build.sh --universal
app="$PWD/build/release/Daylight.app"
mkdir -p dist
archive="$PWD/dist/Daylight-macOS-universal.zip"
# A configured keychain profile enables local signing + notarization.
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]] || { print -u2 'Notarization requires DEVELOPER_ID_APPLICATION'; exit 1; }
    submission=$(mktemp -d "$PWD/build/.notary.XXXXXX")
    trap 'rm -rf "$submission"' EXIT
    ditto -c -k --sequesterRsrc --keepParent "$app" "$submission/Daylight.zip"
    xcrun notarytool submit "$submission/Daylight.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose "$app"
fi
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
./scripts/create-dmg.sh
(cd dist && shasum -a 256 Daylight-macOS-universal.dmg Daylight-macOS-universal.zip > SHA256SUMS.txt)
print "Packaged Daylight $version: $archive"
