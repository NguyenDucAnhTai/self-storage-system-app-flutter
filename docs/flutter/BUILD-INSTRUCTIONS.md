# Build Instructions

From `apps/flutter_mobile`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The default API URL is `https://self-storage-system-be.onrender.com`. Pass `--dart-define=API_BASE_URL=https://<approved-staging-host>` only when selecting another environment. The debug APK is emitted at `build/app/outputs/flutter-apk/app-debug.apk`. Debug builds allow cleartext for local development; release does not.

On Windows, Flutter builds Android APKs. iOS build/signing requires macOS and Xcode. Backend credentials and test account setup are separate; never put secrets in `--dart-define` values that are committed or shared.
