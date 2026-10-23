#!/usr/bin/env bash
# Build Himal, install it on the running emulator or phone, launch it with extras, and save a screenshot.
# Usage: tools/android-shot.sh OUT_PNG [extras for `am start`...]
# Example: tools/android-shot.sh /tmp/nagarkot.png --ed lat 27.7172 --ed lon 85.52 --ed heading 77
# Needs JDK 17 (JAVA_HOME), the Android SDK (ANDROID_HOME), one device in `adb devices`,
# and shared/data/nepal-dem.i16 from tools/build-data.py.
set -euo pipefail

out="$1"
shift
root="$(cd "$(dirname "$0")/.." && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 17 2>/dev/null || echo /opt/homebrew/opt/openjdk@17)}"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
package=com.shanpanta.himal

(cd "$root/android" && ./gradlew :app:installDebug --console=plain -q)
adb shell pm grant "$package" android.permission.ACCESS_FINE_LOCATION
adb shell pm grant "$package" android.permission.CAMERA
adb shell am force-stop "$package"
adb shell am start -n "$package/.HimalActivity" "$@" >/dev/null
sleep "${HIMAL_WAIT:-6}"
adb exec-out screencap -p > "$out"
echo "saved $out"
