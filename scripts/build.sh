#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
export MACOSX_DEPLOYMENT_TARGET=14.0
mode="${1:-native}"
if [[ "$mode" != native && "$mode" != --universal ]]; then
    print -u2 'Usage: ./scripts/build.sh [--universal]'
    exit 1
fi
output="$PWD/build"
[[ "$mode" == --universal ]] && output="$output/release"
mkdir -p "$output"
staging=$(mktemp -d "$output/.bundle.XXXXXX")
trap 'rm -rf "$staging"' EXIT
APP="$staging/Daylight.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ "$mode" == --universal ]]; then
    binaries=()
    for arch in arm64 x86_64; do
        build_args=(-c release -debug-info-format none --disable-sandbox --cache-path "$PWD/.build/cache" --triple "$arch-apple-macosx14.0" --scratch-path "$PWD/.build/release-$arch")
        swift build "${build_args[@]}"
        bin_dir=$(swift build "${build_args[@]}" --show-bin-path)
        binaries+=("$bin_dir/Daylight")
    done
    lipo -create "${binaries[@]}" -output "$APP/Contents/MacOS/Daylight"
    lipo "$APP/Contents/MacOS/Daylight" -verify_arch arm64
    lipo "$APP/Contents/MacOS/Daylight" -verify_arch x86_64
else
    build_args=(-c release -debug-info-format none --disable-sandbox --cache-path "$PWD/.build/cache")
    swift build "${build_args[@]}"
    bin_dir=$(swift build "${build_args[@]}" --show-bin-path)
    cp "$bin_dir/Daylight" "$APP/Contents/MacOS/Daylight"
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/make-icon.swift "$output"
cp "$output/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp Resources/TimerChime.wav "$APP/Contents/Resources/TimerChime.wav"
if [[ -f LICENSE ]]; then
    cp LICENSE "$APP/Contents/Resources/LICENSE"
fi
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
else
    codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
# Replace only this script's output bundle, after a successful build and signature.
rm -rf "$output/Daylight.app"
mv "$APP" "$output/Daylight.app"
print "Built: $output/Daylight.app"
