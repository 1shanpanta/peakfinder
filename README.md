# Himal

A Nepal-only app that names the peaks around you. It draws a flat panorama of the ridges with a tilted label on each peak. A camera mode puts the same labels over the live camera. It works offline.

The idea comes from the PeakFinder app. Himal is a personal build, sideloaded to one phone. It is not for any app store.

## Screenshots

Same viewpoint on both apps: Nagarkot, looking east at heading 77 degrees, with Mount Everest in view.

| iOS | Android |
|---|---|
| ![Himal on iOS, Nagarkot, heading 77 degrees](docs/images/ios-nagarkot.png) | ![Himal on Android, Nagarkot, heading 77 degrees](docs/images/android-nagarkot.png) |

## Layout

| Folder | Holds |
|---|---|
| `ios/` | The iOS app (SwiftUI) and `ios/PeakCore`, the Swift engine package. |
| `android/` | The Android app (Kotlin, Compose). `android/core` is the engine. |
| `shared/data/` | The packed Nepal peaks and terrain header. Both apps bundle these files. The 130 MB terrain file is built locally. |
| `tools/` | Scripts that fetch and pack the data, and take simulator screenshots. |
| `docs/images/` | The screenshots in this file. |

## How it works

- Terrain: Copernicus GLO-30 heights, packed at 3 arc-seconds (about 90 m). Each cell keeps the highest source cell, so summits survive.
- Peaks: OpenStreetMap `natural=peak` points with a Latin or Devanagari name. 619 peaks.
- Engine: shoots 3600 rays from the viewpoint. It keeps the steepest angle on each ray, after Earth curvature and refraction.
- A peak is visible when its summit angle is not below the steepest ground in front of it.
- Both engines follow the same rules, and both test suites check the same facts.

## Setup

1. Run `tools/fetch-nepal-data.sh`. It downloads 1.7 GB of terrain and the Nepal OSM extract to `../peakfinder-data`, then cuts the peaks with `osmium`.
2. Run `uv run tools/build-data.py`. It writes the packed files to `shared/data`.
3. iOS: run `xcodegen generate` in `ios`, open `ios/Himal.xcodeproj`, pick your Apple ID under Signing, then run on the phone. A free Apple ID expires the app after 7 days.
4. Android: needs JDK 17 and the Android SDK. In `android`, run `./gradlew :app:assembleRelease`. The signed APK lands in `android/app/build/outputs/apk/release`. Install it with `adb install -r app-release.apk`. The release build uses the debug key, so it is for sideloading only.

## Test

- iOS engine: `swift test` in `ios/PeakCore`. The Nepal sightline tests skip when the packed data is missing.
- iOS screen: `tools/ios-sim-shot.sh OUT.png -lat 27.7172 -lon 85.52 -heading 77` builds, launches and screenshots the simulator.
- Android engine: `./gradlew :core:test` in `android`. It runs on the JVM with no emulator. The Nepal sightline tests skip when the packed data is missing.
- Android screen: `tools/android-shot.sh OUT.png --ed lat 27.7172 --ed lon 85.52 --ed heading 77` builds, installs, launches and screenshots the device in `adb devices`.

## Not verified yet

- Live compass and camera alignment on a real phone, iOS and Android. Simulators and emulators only fake them.
- Landscape layout and pinch to zoom.
- Accuracy against a real photo.

## Limits

- Only 619 named peaks. OSM has no English name for most Nepali peaks.
- The terrain model includes roofs and trees. Ground under 25 m within 2 km is ignored.
- Bearings use a sphere, which is up to 0.15 degrees off the WGS84 geodesic.

## Decisions log

- Shell changed from the web page recommendation to native Swift.
- Own build kept after the prior art search. UI follows PeakFinder, ideas come from Peak.
- iOS pitch and roll use gravity, not the attitude matrix. Apple documents the matrix frame in conflicting ways.
- Android is native Kotlin, not Expo. A JavaScript engine without a JIT ran 28 times slower than V8 with one on the same loop, and the terrain file is 130 MB.
