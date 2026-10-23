#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
mkdir -p build docs/images
gallery_work=$(mktemp -d "$PWD/build/.gallery.XXXXXX")
trap 'rm -rf "$gallery_work"' EXIT
# Compile the actual app views with deterministic demo data, without changing the app.
cat Sources/DaylightCore/Countdown.swift Sources/DaylightCore/DayGrid.swift \
    Sources/Daylight/Palette.swift Sources/Daylight/DayGridView.swift \
    Sources/Daylight/CountdownFace.swift scripts/render-gallery.swift \
    | sed '/^import DaylightCore$/d' > "$gallery_work/Gallery.swift"
swiftc -Xfrontend -disable-sandbox -parse-as-library "$gallery_work/Gallery.swift" -o "$gallery_work/render"
"$gallery_work/render" "$PWD/docs/images/countdown-styles.png"
