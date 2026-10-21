#!/bin/bash
# Build OmniLife Android APKs inside WSL2 (native Windows Gradle is broken on this machine).
# Usage (run inside WSL as root): android-build-wsl.sh [debug] [release]   (default: both)
# Env: SRC (default /mnt/d/OmniLife), WORK (default /root/omnilife-build)
set -euo pipefail
SRC="${SRC:-/mnt/d/OmniLife}"
WORK="${WORK:-/root/omnilife-build}"
SDK=/opt/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=$SDK ANDROID_SDK_ROOT=$SDK
export GRADLE_USER_HOME=/root/.gradle-wsl
export GRADLE_OPTS="-Djava.net.preferIPv4Stack=true -Dorg.gradle.daemon=false"
export PUB_CACHE=/root/.pub-cache
export PATH=/opt/flutter/bin:$JAVA_HOME/bin:$SDK/platform-tools:$PATH
export CI=true
MODES=("$@"); [ ${#MODES[@]} -eq 0 ] && MODES=(release aab)

mkdir -p "$WORK"
rsync -a --delete \
  --exclude='/build/' --exclude='.dart_tool/' --exclude='.git/' --exclude='/.agents/' \
  --exclude='/android/.gradle/' --exclude='/android/local.properties' --exclude='/android/app/.cxx/' \
  --exclude='/windows/' --exclude='/web/' --exclude='/linux/' --exclude='/macos/' --exclude='/ios/' \
  --exclude='.flutter-plugins-dependencies' --exclude='.flutter-plugins' --exclude='.packages' \
  --exclude='/.claude/' --exclude='/tools/' \
  "$SRC"/ "$WORK"/
[ -f "$SRC/android/app/google-services.json" ] && cp "$SRC/android/app/google-services.json" "$WORK/android/app/"
cat > "$WORK/android/local.properties" <<EOP
sdk.dir=$SDK
flutter.sdk=/opt/flutter
EOP
cd "$WORK"
flutter pub get
OUT="$SRC/build/app/outputs/flutter-apk"; mkdir -p "$OUT"
DEFINES=()
[ -f "$WORK/.env" ] && DEFINES=(--dart-define-from-file=.env)
for m in "${MODES[@]}"; do
  if [ "$m" = "aab" ]; then
    flutter build appbundle --release "${DEFINES[@]}"
    BUNDLE="$SRC/build/app/outputs/bundle/release"; mkdir -p "$BUNDLE"
    cp -v "$WORK/build/app/outputs/bundle/release/app-release.aab" "$BUNDLE/"
    ls -lh "$BUNDLE"
  else
    flutter build apk --$m "${DEFINES[@]}"
    cp -v "$WORK/build/app/outputs/flutter-apk/app-$m.apk" "$OUT/"
  fi
done
ls -lh "$OUT"
