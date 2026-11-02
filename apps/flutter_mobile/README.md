# StorageHub Flutter Mobile

Customer app for facility discovery, reservations, payments and storage contracts.

## Run

```powershell
flutter pub get
flutter run
```

The default API address targets the backend on the Android emulator host. Set `API_BASE_URL` to a reachable host for other environments.

## Build Android debug APK

```powershell
flutter build apk --debug
```

The default API base URL is the Render production backend (`https://self-storage-system-be.onrender.com`). Override `API_BASE_URL` with `--dart-define` only when intentionally targeting another environment. Do not use production credentials for testing.

## Quality checks

```powershell
flutter analyze
flutter test
```

See [the Flutter architecture guide](../../../docs/flutter/ARCHITECTURE.md), [API integration map](../../../docs/flutter/API-INTEGRATION.md), and [feature/test status](../../../docs/flutter/FEATURE-STATUS.md).
