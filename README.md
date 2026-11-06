# auxia-mobile

Field app of **AuxIA**, the disaster response platform by Waqta Labs. It is the
"App de Campo" container of the AuxIA architecture, built with Flutter for
Android and iOS, and it works **offline-first**: everything is saved on the
device first and synchronized with the AuxIA backend when the signal returns.

| Role | What the app does |
|---|---|
| Citizen | One-tap SOS without signal, optional emergency detail, and the status of each report. |
| Field brigade | Missions prioritized by AI, navigation to the zone, and delivery verification (QR, signature, photo) anchored on Blockchain. |

## Requirements

- Flutter 3.44 (stable) with Dart 3.12
- Android SDK (API 21 or later) for Android builds
- Xcode on macOS for iOS builds

## Run

```bash
flutter pub get
flutter run
```

The app talks to the AuxIA backend deployed on Azure
(`https://auxia-backend.azurewebsites.net`). To use another backend, for
example one running on your machine from the Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## Verify

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

GitHub Actions runs the first three on every pull request to `develop` and
`main`.

## Project structure

The code follows the bounded contexts of the AuxIA backend, each with the
`domain`, `application`, `infrastructure` and `interfaces` layers:

```text
lib/
├── core/        # config, DI, HTTP client, routing, theme, localization
├── shared/      # widgets and value objects shared by the contexts
└── l10n/        # Spanish (default) and English texts
```

## Design

The interface implements the approved mobile mock-ups of the AuxIA report
(screens A_01 to A_10) and its Design System: the AuxIA palette, the Inter
typeface (bundled under the SIL Open Font License), an 8 pt grid and 48 × 48
touch targets. Spanish is the default language and English is available.

## Branching

GitFlow: work happens on `feature/*` branches created from `develop` and is
integrated through pull requests. `main` only receives releases.
