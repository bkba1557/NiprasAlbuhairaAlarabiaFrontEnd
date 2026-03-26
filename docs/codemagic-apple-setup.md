# Codemagic iOS Setup

## What is ready

- `codemagic.yaml` builds a signed iOS `IPA` (downloadable from build artifacts).
- `ios-app-store-release` is configured for App Store signing, but the App Store Connect upload is currently commented out in `codemagic.yaml`.
- `ios-ad-hoc-ipa` builds an Ad Hoc `IPA` for direct device installation (requires an Ad Hoc provisioning profile with your device UDIDs).
- `codemagic.yaml` regenerates the iOS icons before each build.
- `scripts/generate_ios_app_icons.sh` generates `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- The iOS bundle identifier is set to `com.albuhaira.nipras`.

## Replace these placeholders

- In `codemagic.yaml`, replace `YOUR_APP_STORE_CONNECT_KEY_NAME` with the App Store Connect key name you save in Codemagic UI.
- In `codemagic.yaml`, replace `APP_STORE_APPLE_ID` with the numeric Apple ID of the app from App Store Connect.

## Add these items in Codemagic UI

- App Store Connect API key:
  Add the `.p8` key, `Key ID`, and `Issuer ID` in Codemagic Team settings under Apple Developer Portal integration.
- iOS signing files:
  Upload or fetch the `Apple Distribution` certificate and the `App Store` provisioning profile in Codemagic code signing settings.

## Current icon source

- The generated iOS app icon source is `assets/icons/ios_app_icon_source.png`.
- The current Apple icon source was composed from `assets/icons/icon-app.png` on a dark navy background (`#081A33`).
- Codemagic regenerates `Assets.xcassets` from this file on every iOS release build using `scripts/generate_ios_app_icons.sh`.

## Important note before first release

- The first App Store version often still needs App Store Connect metadata to be complete manually, such as screenshots, category, and privacy information.
- After that, `ios-app-store-release` is ready to build the `IPA` and send it directly to App Store Connect (then install via TestFlight).
