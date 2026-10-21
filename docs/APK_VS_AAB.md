# APK versus AAB

## The short answer

- APK (Android Package) is the finished app file. You can copy it to a phone
  and install it directly. It contains the code and resources for every
  supported device type, so it is larger.
- AAB (Android App Bundle) is a publishing format that only Google Play
  accepts. A phone cannot install an AAB directly. Google Play uses the AAB
  to generate small APKs tailored to each user's device (screen density,
  CPU architecture, language).

| | APK | AAB |
|---|---|---|
| Installable on a phone | Yes, directly | No, Play Store only |
| Used for | Testing, demos, sharing with the team | Uploading to Google Play |
| Contains | Everything for all devices | Code and resources split into modules; Play builds the APKs |
| Size | Larger (all architectures and densities in one file) | Smaller download for the user, because Play delivers only what the device needs |
| Signing | Signed by us | We sign the upload; Google re-signs the delivered APKs with the app signing key |
| File | `app-release.apk` | `app-release.aab` |

## Build commands

```bash
flutter build apk --release --dart-define-from-file=.env
flutter build appbundle --release --dart-define-from-file=.env
```

Output paths:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

On the Windows development machine run the builds through WSL2 with
`tools\android-build.cmd release` (see `docs/android-build-wsl.md`).

Optional: `flutter build apk --split-per-abi` produces one smaller APK per CPU
architecture (arm64-v8a, armeabi-v7a, x86_64) if a single universal APK is too
big to share.

## Sizes to show in the viva

Fill these in from the build that is demonstrated (the files are not
committed, so check them on the build machine):

| File | Size (MB) | Command to read it |
|---|---|---|
| app-release.apk | ______ | `ls -lh build/app/outputs/flutter-apk/app-release.apk` |
| app-release.aab | ______ | `ls -lh build/app/outputs/bundle/release/app-release.aab` |

Flutter also prints the size at the end of each build ("Built ... (xx.xMB)").
The AAB file itself is usually similar to or larger than the universal APK,
because it carries every architecture; the saving is in what the user
downloads from Play.

## Signing

Every APK and AAB must be signed. The upload keystore and
`android/key.properties` are never committed (they are in `.gitignore`).
At present the release build in `android/app/build.gradle.kts` still uses
the debug signing key, which is fine for demos and sideloading but is not
acceptable for Play. For publishing: create a keystore with `keytool`, put
its path and passwords in `android/key.properties`, and point the release
`signingConfig` at it.

## Install an APK with adb

```bash
adb devices                                  # phone must be listed (USB debugging on)
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` reinstalls and keeps the app data. Alternatively copy the APK to the
phone and open it, allowing "install unknown apps" for the file manager.

To check what an AAB will produce locally, Google's `bundletool` can build
APKs from it (`bundletool build-apks --bundle=app-release.aab --output=app.apks`).
