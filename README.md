# StorageHub — Frontend Monorepo

StorageHub's frontend is a Turborepo and pnpm monorepo for the Next.js web portal and shared TypeScript packages. The customer mobile application is being migrated from Expo/React Native to a standalone Flutter project.

## Structure

```text
self-storage-system-fe/
├── apps/
│   ├── web/                 # Next.js web portal (pnpm workspace)
│   └── flutter_mobile/      # Flutter app (independent of pnpm)
├── packages/
│   └── shared/              # Shared TypeScript models, schemas and utilities
├── package.json
├── pnpm-workspace.yaml
└── turbo.json
```

`apps/flutter_mobile` uses Flutter and Dart's own package manager. It is intentionally excluded from the JavaScript workspace. The `packages/shared` TypeScript package remains available to the web app; Flutter will use Dart models when mobile features are added.

## Requirements

- Node.js 20 or later
- pnpm 11
- Flutter SDK (stable channel) with Android Studio / Android SDK for Android development
- Xcode on macOS for iOS builds

## Web development

```bash
pnpm install
pnpm dev:web
```

Configure `apps/web/.env.local` as needed:

```env
NEXT_PUBLIC_API_BASE_URL=http://localhost:5000/
NEXT_PUBLIC_DEFAULT_LOCALE=vi
```

## Flutter development

```bash
cd apps/flutter_mobile
flutter pub get
flutter run
```

Select an Android emulator or connected device before running. On Windows, Flutter can build Android apps; iOS builds require macOS and Xcode.

The Flutter mobile project contains customer flows for authentication, Explore, reservations, payments, profile, notifications and contracts. Current coverage, backend blockers and verification evidence are documented in [docs/flutter/FEATURE-STATUS.md](docs/flutter/FEATURE-STATUS.md).

Reusable starter images, font, and Vietnamese/English translation JSON files are stored under `apps/flutter_mobile/assets/`.

## Monorepo checks

Run these from the repository root:

```bash
pnpm install
pnpm type-check
pnpm build
```

`pnpm dev:web` runs the web app. Use the Flutter CLI from `apps/flutter_mobile` for mobile commands; Flutter is not a Turbo or pnpm workspace.
