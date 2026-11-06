# auxia-mobile

Field app of **AuxIA**, the disaster response platform by Waqta Labs. It is the
"App de Campo" container of the AuxIA architecture, built with Flutter for
Android and iOS, and it works **offline-first**: everything is saved on the
device first and synchronized with the AuxIA backend when the signal returns.

## What it does

| Role | Screens | What the user can do |
|---|---|---|
| Citizen | SOS · Mis reportes · Ajustes | Ask for help with a one-tap SOS (Médico, Rescate, Víveres) even without signal, add an optional detail (people, access conditions, 5 s audio, photo) and follow each report: Guardado → Transmitiendo → Priorizado por IA → Brigada en camino. |
| Brigade member | Misiones · Entrega · Ajustes | Sign in with the institutional account, see the missions of the brigade on a map with their Urgency Score and why they have that priority, start navigation, and verify the delivery in three steps (package QR, signature and reception photo, Blockchain seal). |

Both roles have *Red y almacenamiento*: offline maps by region, the figures of
the encrypted local database, "Sincronizar ahora", language (Spanish or
English), sign out and change role.

## Offline-first

- Every write (SOS, delivery) is saved in an encrypted SQLite database
  (SQLCipher, key in the Keystore / Keychain) and queued in an outbox with an
  id generated on the device.
- A sync engine sends the queue when the network comes back, every minute and
  on demand, with exponential backoff. Refused writes keep their reason; an
  expired session pauses the queue until the brigadist signs in again.
- Missions are cached for offline work, and map regions can be downloaded so
  the missions map works without signal.
- The app never talks to the Blockchain: the backend hashes the delivery
  record without personal data and anchors it on Sepolia.

## Backend

The app uses the AuxIA backend deployed on Azure
(`https://auxia-backend.azurewebsites.net/api/v1`):

| Feature | Endpoints |
|---|---|
| Brigade sign-in | `POST /auth/sign-in` |
| Missions | `GET /brigades`, `/brigades/{id}`, `/distribution-plans/{id}`, `/zones/{id}`, `/zones/{id}/score`, `/deliveries?zoneId=`, `/inventories` |
| Delivery | `POST /deliveries/{id}/registration` (multipart), `GET /deliveries/{id}` |
| Citizen SOS (proposed) | `POST /public/field-reports`, `GET /public/field-reports/{clientReportId}` |

The public endpoints for citizen reports do not exist in the backend yet. The
app already implements them; while the backend answers 404, the SOS reports
stay queued on the device and are sent as soon as the endpoints are
published.

## Requirements

- Flutter 3.44 (stable) with Dart 3.12
- Android SDK (API 21 or later) for Android builds
- Xcode on macOS for iOS builds

## Run

```bash
flutter pub get
flutter run
```

To use another backend, for example one running on your machine from the
Android emulator:

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
`main`. The suite covers the domain rules, the backend gateways against fake
HTTP answers, the local database and the sync engine, the cubits, every
screen, full widget flows of both roles, and accessibility (48 px touch
targets, labels, text contrast, small phones with large text).

## Project structure

The code follows the bounded contexts of the AuxIA backend, each with the
`domain`, `application`, `infrastructure` and `interfaces` layers:

```text
lib/
├── core/                 # config, DI, HTTP client, local database, sync engine,
│                         # connectivity, location, offline maps, routing, theme
├── shared/               # widgets and value objects shared by the contexts
├── identityaccess/       # registration, role, brigade credential and sign-in
├── emergencymanagement/  # citizen SOS, emergency detail and my reports
├── resourcemanagement/   # brigade missions and map
├── traceability/         # delivery verification and Blockchain evidence
├── networkstorage/       # network and storage settings, offline maps
└── l10n/                 # Spanish (default) and English texts
```

## Permissions

| Permission | Why |
|---|---|
| Internet and network state | Sync with the backend when there is signal. |
| Location | GPS of the SOS and of the delivery; distance to the missions. |
| Camera | Package QR, reception photo, emergency photo and ID card. |
| Microphone | 5 second audio of the emergency detail. |
| Vibration | Haptic confirmation of the SOS, the QR scan and the Blockchain seal. |

## Design and credits

The interface implements the approved mobile mock-ups of the AuxIA report
(screens A_01 to A_10) and its Design System: the AuxIA palette, the Inter
typeface (bundled under the SIL Open Font License), an 8 pt grid and 48 × 48
touch targets. Maps use © OpenStreetMap contributors data with © CARTO tiles.

## Branching

GitFlow: work happens on `feature/*` branches created from `develop` and is
integrated through pull requests. `main` only receives releases.
