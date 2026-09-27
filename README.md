# EasyBuy — Android & iOS app

Flutter app for [easybuy.com.bd](https://easybuy.com.bd). It talks only to
the site's `/api/v1` (Laravel, in `htdocs/easybuy.com.bd`); the API contract
and its status live in that repo's `docs/mobile-app.md`.

- App id / bundle id: `bd.com.easybuy.app`
- State: Riverpod · HTTP: Dio · Navigation: go_router
- Money is never computed here: every figure is the server's decimal string,
  formatted by `lib/core/money.dart`.

## Layout

```
lib/core      config, HTTP client + error envelope, session (keystore), push, theme
lib/data      models (defensive JSON parsing) and api.dart (one method per endpoint)
lib/state     signed-in customer and cart
lib/ui        screens and shared widgets
test/         unit + widget tests; live_contract_test.dart hits the real API
```

## Checks (run on the server)

```bash
flutter analyze
flutter test
flutter test --tags live --run-skipped   # read-only calls to the live API
```

## Codemagic (how the app is built)

`codemagic.yaml` has three workflows, all started by hand from Codemagic:

| Workflow | Output |
|---|---|
| `android-test` | a signed APK to install on Android phones for testing (e-mailed link) |
| `android-play` | the Play Store bundle, sent to the internal testing track as a draft |
| `ios-testflight` | the iOS build, sent to TestFlight |

Every workflow runs `flutter analyze` and `flutter test` first and stops on
any failure. The build number is Codemagic's `PROJECT_BUILD_NUMBER`; the
version name comes from `pubspec.yaml`.

One-time setup in Codemagic (nothing here goes into git):

1. **Connect the repository** (a private GitHub/GitLab/Bitbucket repo holding
   this directory).
2. **Android upload key** — Team settings → Code signing identities →
   Android keystores: create or upload one, reference name
   `easybuy_upload`. Keep a copy somewhere safe: Play needs the same key for
   every future update.
3. **Firebase** — app Environment variables, group `firebase`:
   `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_ANDROID_APP_ID`,
   `FIREBASE_ANDROID_API_KEY`, `FIREBASE_IOS_APP_ID`, `FIREBASE_IOS_API_KEY`
   (from the Firebase console's app settings). Without them push is off.
4. **iOS** — Team settings → Integrations → App Store Connect: an API key
   named `EasyBuy App Store Connect`; the App ID `bd.com.easybuy.app` with
   the Push Notifications capability, and the app record created in App
   Store Connect. Codemagic then fetches or creates the signing files.
5. **Play** — group `google_play` with `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`
   (a Google Cloud service account invited to the Play Console). Play takes
   an app's first upload only through its own console: upload the first
   `.aab` from the `android-play` artifacts by hand.

## Building for phones (needs a Mac for iOS, or a cloud builder)

```bash
flutter build apk --release          # Android, sideload / testing
flutter build appbundle --release    # Android, Play Store
flutter build ipa --release          # iOS, needs Xcode + an Apple developer team
```

Point at another server with `--dart-define=API_BASE=https://…/api/v1`.

Before a store release:

1. **Signing.** On Codemagic, as above. On a developer machine, Android can
   read `android/key.properties` (never committed).
2. **Push.** The Firebase settings arrive as `--dart-define`s (Codemagic
   group `firebase`, above) — no google-services.json / plist files. iOS also
   needs an APNs key uploaded to Firebase; the push entitlement is already in
   `ios/Runner/Runner.entitlements`. The server needs the project's
   service-account key too (see the site's docs/mobile-app.md).
3. **Icon.** Generated from the site's 512 px icon; the 1024 px App Store
   icon is an upscale — replace it with a sharp 1024 px original.
