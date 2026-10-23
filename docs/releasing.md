# Publishing Daylight

## What belongs where

Keep this folder as the working repository. Git includes source, tests, resources, scripts, workflows, and public documentation. `.build/`, `build/`, `dist/`, and local `docs/evidence/` are ignored; there is no need to move them or manually copy source into another upload folder.

GitHub Releases hold the built app ZIP and checksum. GitHub's automatically generated source archives are for developers and cannot be installed as an app.

## First upload

Daylight uses the MIT license in `LICENSE`. The repository and README download URLs use `jplonghi/Daylight`.

Review the upload set before committing:

```sh
git status --short --untracked-files=all
./scripts/test.sh
./scripts/package-release.sh v2.6.2
```

If the repository has not already been created:

```sh
git add .
git commit -m "Prepare Daylight for open source distribution"
git branch -M main
gh repo create jplonghi/Daylight --public --source=. --remote=origin --push
```

These commands publish the project publicly. Authenticate with `gh auth login` first if needed. Enable GitHub Actions for the repository.

## Publish a version

1. Update `CFBundleShortVersionString` in `Resources/Info.plist` and increment `CFBundleVersion`. Keep the existing bundle identifier stable so installed apps retain their identity.
2. Run tests and commit the change. Push the commit to `main`.
3. Push a matching tag, such as `v2.6.2` for the initial release:

   ```sh
   git tag v2.6.2
   git push origin v2.6.2
   ```

4. GitHub Actions tests the app, builds both architectures, combines them into a universal app, and creates a **draft** release with `Daylight-macOS-universal.zip` and `SHA256SUMS.txt`.
5. Inspect the workflow result and download the draft ZIP. Check launch, countdown creation, timer audio, and quit/relaunch. Core tests do not replace these checks. Before claiming runtime support on both architectures, test on both Apple silicon and Intel hardware; cross-compilation alone is not runtime testing.
6. Edit the draft's notes to describe the changes, then **Publish release** and mark it as the latest stable release.

The README's stable download URL automatically follows the latest published release:

`https://github.com/jplonghi/Daylight/releases/latest/download/Daylight-macOS-universal.zip`

Draft releases are not publicly downloadable. Keep the asset name stable. Do not replace an existing public tag; use a new version for fixes. If a workflow rerun encounters an existing draft, inspect that draft and remove it before rerunning; the workflow intentionally does not overwrite releases.

[GitHub documents latest-release links here](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases).

## Local packaging and verification

```sh
./scripts/package-release.sh v2.6.2
(cd dist && shasum -a 256 -c SHA256SUMS.txt)
lipo -info build/release/Daylight.app/Contents/MacOS/Daylight
codesign --verify --strict build/release/Daylight.app
```

The optional tag argument must match the app version. The release build does not replace the normal development bundle at `build/Daylight.app`.

## Signing later

The default GitHub workflow needs no Apple credentials. Its ad-hoc signature protects bundle integrity but does not identify a trusted developer, and Apple has not notarized these releases. The README and release notes explain the first-launch warning and link to [Apple's Open Anyway instructions](https://support.apple.com/en-us/102445).

For a smoother installation experience, enroll in the Apple Developer Program, obtain a Developer ID Application certificate, and configure a notarytool keychain profile on your Mac. Then package locally with:

```sh
DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='daylight-notary' \
./scripts/package-release.sh v2.6.2
```

The script signs with hardened runtime, submits to Apple, staples and validates the ticket, assesses the app with Gatekeeper, then creates the final ZIP and checksum. This optional path requires real credentials and has not been verified without them. Upload both resulting files in place of the draft's ad-hoc assets, and update the README and release notes to describe the actual signing status before publishing.

Never commit signing certificates, private keys, or passwords. Automated notarization would require a separate GitHub Secrets configuration; the included workflow does not perform it. See [Apple's Developer ID guidance](https://developer.apple.com/developer-id/).

## Updates and uninstalling

Users quit Daylight and replace its app in Applications with the newest download. There is no automatic updater or Homebrew formula yet. Local data remains under `~/Library/Application Support/Daylight/`.

To uninstall, disable Launch at login, quit the app, and remove it from Applications. Deleting the separate data folder is optional and permanently removes saved countdowns.
