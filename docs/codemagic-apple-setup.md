# Codemagic iOS Setup

## What is ready

- `codemagic.yaml` builds a signed iOS `IPA` (downloadable from build artifacts).
- `ios-app-store-release` builds and uploads the build to App Store Connect (for TestFlight) using `app-store-connect publish` with retry/backoff (helps with Apple 429/409 upload errors).
- `ios-ad-hoc-ipa` builds an Ad Hoc `IPA` for direct device installation (requires an Ad Hoc provisioning profile with your device UDIDs).
- `codemagic.yaml` regenerates the iOS icons before each build.
- `scripts/generate_ios_app_icons.sh` generates `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- `scripts/generate_ios_app_icons.sh` also regenerates `ios/Runner/Assets.xcassets/LaunchImage.imageset` to avoid the default placeholder launch image warning.
- The iOS bundle identifier is set to `com.albuhaira.nipras`.

## Update identifiers (if needed)

- Bundle identifier: `com.albuhaira.nipras` (in `codemagic.yaml`).
- App Store Apple ID: `6759683802` (in `codemagic.yaml`).

## Add these items in Codemagic UI

- App Store Connect API key:
  Add the `.p8` key, `Key ID`, and `Issuer ID` in Codemagic Team settings (App Store Connect integration).
- iOS signing files:
  Upload or fetch the `Apple Distribution` certificate and the needed provisioning profile in Codemagic code signing settings:
  - App Store/TestFlight: `App Store` provisioning profile.
  - Direct device install: `Ad Hoc` provisioning profile (must include device UDIDs).

## Direct iPhone install (Ad Hoc)

- Add the iPhone UDID to your Apple Developer account (Devices).
- Create an `Ad Hoc` provisioning profile for the app id `com.albuhaira.nipras` that includes the device UDID(s).
- Upload the `Apple Distribution` certificate + the `Ad Hoc` provisioning profile to Codemagic.
- Run the `ios-ad-hoc-ipa` workflow and download `build/ios/ipa/*.ipa` from artifacts.

## Current icon source

- The generated iOS app icon source is `assets/icons/ios_app_icon_source.png`.
- The current Apple icon source was composed from `assets/icons/icon-app.png` on a dark navy background (`#081A33`).
- Codemagic regenerates `Assets.xcassets` from this file on every iOS release build using `scripts/generate_ios_app_icons.sh`.

## Important note before first release

- The first App Store version often still needs App Store Connect metadata to be complete manually, such as screenshots, category, and privacy information.
- The `ios-app-store-release` workflow uploads to App Store Connect automatically.
