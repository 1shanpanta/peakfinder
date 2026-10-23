#!/usr/bin/env bash
# Build Himal for the booted simulator, launch it with launch arguments, and save a screenshot.
# Usage: tools/ios-sim-shot.sh OUT_PNG [launch args...]
# Example: tools/ios-sim-shot.sh /tmp/nagarkot.png -lat 27.7172 -lon 85.52 -heading 78 -fov 40
# Needs a booted simulator, `xcodegen`, and shared/data/nepal-dem.i16 from tools/build-data.py.
set -euo pipefail

out="$1"
shift
root="$(cd "$(dirname "$0")/.." && pwd)"
derived="${HIMAL_DERIVED:-$HOME/Library/Caches/himal-derived}"

(cd "$root/ios" && xcodegen generate --quiet)
xcodebuild -project "$root/ios/Himal.xcodeproj" -scheme Himal -configuration Debug -derivedDataPath "$derived" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet \
  | grep -E "error:|BUILD" || true

app="$derived/Build/Products/Debug-iphonesimulator/Himal.app"
xcrun simctl install booted "$app"
xcrun simctl privacy booted grant location com.shanpanta.himal
xcrun simctl privacy booted grant camera com.shanpanta.himal
xcrun simctl terminate booted com.shanpanta.himal 2>/dev/null || true
xcrun simctl launch booted com.shanpanta.himal "$@" >/dev/null
sleep "${HIMAL_WAIT:-6}"
xcrun simctl io booted screenshot "$out" 2>/dev/null
echo "saved $out"
