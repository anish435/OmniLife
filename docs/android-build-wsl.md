# Android builds via WSL2

Native Windows Gradle fails on this machine (`Unable to establish loopback connection`,
JDK `Selector.open()` AF_UNIX sockets are broken), so APKs are built inside WSL2 Ubuntu.

## One-time setup (already done on this PC)
In WSL distro `Ubuntu`, as root:
- OpenJDK 17 (`/usr/lib/jvm/java-17-openjdk-amd64`), `rsync`, `unzip`, cmake, ninja
- Flutter at `/opt/flutter` (git `safe.directory` configured)
- Linux Android SDK at `/opt/android-sdk` (cmdline-tools, platform-tools, platforms;android-36,
  build-tools 35/36; Gradle auto-installs other platforms/CMake). NDK r28c is symlinked into `ndk/`.
- Gradle home `/root/.gradle-wsl` (never put SDK/Gradle home on /mnt/*: drvfs has no symlinks)
- `android/app/google-services.json` must exist in the Windows repo (gitignored)

## Daily use
```
tools\android-build.cmd            :: debug + release
tools\android-build.cmd debug      :: debug only
tools\android-build.cmd release    :: release only
```
(Git Bash: `MSYS_NO_PATHCONV=1 wsl -d Ubuntu -u root -- bash /mnt/d/OmniLife/tools/android-build-wsl.sh debug`)

The script rsyncs the project to `/root/omnilife-build`, writes a Linux `local.properties`,
runs `flutter pub get` there, builds, and copies APKs to
`build\app\outputs\flutter-apk\app-{debug,release}.apk`. First build ~15 min; later ones are faster.
Never build in /mnt/d directly.

## Emulator (Windows SDK, WHPX acceleration)
AVD `OmniLife` (hand-written under `%USERPROFILE%\.android\avd`, Pixel 6 profile, API 36.1 Play image):
```
emulator -avd OmniLife -no-snapshot -no-audio -gpu swiftshader_indirect
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p com.omnilife.omnilife -c android.intent.category.LAUNCHER 1
adb logcat -d | findstr /i "FATAL flutter Firebase"
```
Use the Windows `adb.exe` from `%LOCALAPPDATA%\Android\sdk\platform-tools`.
