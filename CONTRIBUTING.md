# Contributing to Daylight

Use macOS 14+ and Xcode 26.6+ (Swift 6.3+). Open `Package.swift` in Xcode, or use the scripts below.

```sh
./scripts/test.sh
./scripts/build.sh
```

Keep UI and macOS integration in `Sources/Daylight`; keep testable domain behavior in `Sources/DaylightCore`. Add or update tests when changing that behavior. Avoid adding packages unless they solve a clear need.

Before opening a pull request, describe the problem, the change, and how you verified it. For UI changes, include a screenshot using demo data and manually check the relevant widget sizes. Core tests do not verify native dragging, login items, audio, or Gatekeeper.

## Isolated manual testing

Quit the development app before rebuilding its bundle. `DAYLIGHT_DATA_DIR` selects a separate data directory; `--demo` disables file reads and writes. Test profiles do not automatically register login items.

```sh
./scripts/build.sh
./scripts/prepare-qa.sh
open build/qa/DaylightCheck.app
```

The QA app stores data in `/private/tmp/daylight-multi-qa`. Local reports and screenshots can go in `docs/evidence/`, which is ignored by Git. Do not commit real user data. Use `docs/images/` for deliberately selected, privacy-reviewed screenshots intended for the public README.

## Releases

See [the publishing guide](docs/releasing.md). Release tags must match `CFBundleShortVersionString` in `Resources/Info.plist`.
