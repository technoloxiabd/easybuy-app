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

## Building for phones (needs a Mac for iOS, or a cloud builder)

```bash
flutter build apk --release          # Android, sideload / testing
flutter build appbundle --release    # Android, Play Store
flutter build ipa --release          # iOS, needs Xcode + an Apple developer team
```

Point at another server with `--dart-define=API_BASE=https://…/api/v1`.

Before a store release:

1. **Signing.** Android: create an upload keystore and a `key.properties`
   (never commit either); iOS: set the team in Xcode.
2. **Push.** From the Firebase project: `android/app/google-services.json`
   and `ios/Runner/GoogleService-Info.plist` (added to the Runner target in
   Xcode), plus an APNs key uploaded to Firebase and the *Push Notifications*
   capability enabled in Xcode. Without these files the app runs with push
   off. The server needs the project's service-account key too (see the
   site's docs/mobile-app.md).
3. **Icon.** Generated from the site's 512 px icon; the 1024 px App Store
   icon is an upscale — replace it with a sharp 1024 px original.
