#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build -c release -debug-info-format none --disable-sandbox --cache-path "$PWD/.build/cache"
QA_APP="$PWD/build/qa/DaylightCheck.app"
mkdir -p "$QA_APP/Contents/MacOS" "$QA_APP/Contents/Resources" /private/tmp/daylight-multi-qa
cp .build/release/Daylight "$QA_APP/Contents/MacOS/Daylight"
cp Resources/Info.plist "$QA_APP/Contents/Info.plist"
cp build/AppIcon.icns "$QA_APP/Contents/Resources/AppIcon.icns"
cp Resources/TimerChime.wav "$QA_APP/Contents/Resources/TimerChime.wav"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.local.daylight.countdown.qa-fixed' "$QA_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName DaylightCheck' "$QA_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName DaylightCheck' "$QA_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSEnvironment dict' "$QA_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSEnvironment:DAYLIGHT_DATA_DIR string /private/tmp/daylight-multi-qa' "$QA_APP/Contents/Info.plist"
codesign --force --sign - "$QA_APP"
print "QA app: $QA_APP"
