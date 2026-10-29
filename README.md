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
- Peaks: OpenStreetMap `natural=peak` points with a Latin or Devanagari name. 619 peaks. A peak with no `ele` tag in OSM takes its height from the terrain data.
- Engine: shoots 3600 rays from the viewpoint. It keeps the steepest angle on each ray, after Earth curvature and refraction.
- A peak is visible when its summit angle is not below the steepest ground in front of it.
- Both engines follow the same rules, and both test suites check the same facts.

## Setup

Requirements: macOS 14 or newer (the scripts and `swift test` assume it), `brew install osmium-tool xcodegen uv`, Xcode 16 or newer, JDK 17 (set `JAVA_HOME`), and the Android SDK (set `ANDROID_HOME`, or put `sdk.dir` in `android/local.properties`).

1. Run `tools/fetch-nepal-data.sh`. It downloads about 2.1 GB (1.7 GB of terrain, the rest the Nepal OSM extract) to `../peakfinder-data`, then cuts the peaks with `osmium`. The tracked `shared/data/nepal-peaks.json` is a 619-peak snapshot. A rebuild from the latest extract can differ.
2. Run `uv run tools/build-data.py`. It writes the packed files to `shared/data`.
3. iOS: change `bundleIdPrefix` and `PRODUCT_BUNDLE_IDENTIFIER` in `ios/project.yml` to an id you own, because Apple ids are unique. Run `xcodegen generate` in `ios`, open `ios/Himal.xcodeproj`, pick your Apple ID under Signing, then run on the phone. Each `xcodegen generate` clears the Signing choice, so pick it again. A free Apple ID expires the app after 7 days.
4. Android: in `android`, run `./gradlew :app:assembleRelease`. The signed APK lands in `android/app/build/outputs/apk/release`. Install it with `adb install -r app/build/outputs/apk/release/app-release.apk`. The release build uses the debug key, so it is for sideloading only.

## Test

- iOS engine: `swift test` in `ios/PeakCore`. The Nepal sightline tests skip when the packed data is missing.
- iOS screen: `tools/ios-sim-shot.sh OUT.png -lat 27.7172 -lon 85.52 -heading 77` builds, launches and screenshots the booted simulator. It builds for an `iPhone 17 Pro` simulator and uses the id `com.shanpanta.himal`. Edit the `-destination` and the id in the script if you use another simulator or changed the id in Setup step 3.
- Android engine: `./gradlew :core:test` in `android`. It runs on the JVM with no emulator. The Nepal sightline tests skip when the packed data is missing.
- Android screen: `tools/android-shot.sh OUT.png --ed lat 27.7172 --ed lon 85.52 --ed heading 77` builds, installs, launches and screenshots the device in `adb devices`.

## Not verified yet

- Live compass and camera alignment on a real phone, iOS and Android. Simulators and emulators only fake them.
- Landscape layout and pinch to zoom.
- Accuracy against a real photo.

## Limits

- Only 619 named peaks. OSM has no English name for most Nepali peaks.
- The terrain model includes roofs and trees. Ground less than 25 m above the eye within 2 km is ignored.
- Bearings use a sphere, which is up to 0.15 degrees off the WGS84 geodesic.

## Data credits

- Contains data (c) OpenStreetMap contributors, available under the Open Database Licence (ODbL).
- Contains Copernicus DEM GLO-30, produced using Copernicus WorldDEM-30 (c) DLR e.V. 2010-2014 and (c) Airbus Defence and Space GmbH 2014-2018, provided under COPERNICUS by the European Union and ESA. All rights reserved.
- The full notices sit in `shared/data/NOTICE`. The screenshots above draw on both sources.

## Decisions log

- Shell changed from the web page recommendation to native Swift.
- Own build kept after the prior art search. UI follows PeakFinder, ideas come from Peak.
- iOS pitch and roll use gravity, not the attitude matrix. Apple documents the matrix frame in conflicting ways.
- Android is native Kotlin, not Expo. A JavaScript engine without a JIT ran 28 times slower than V8 with one on the same loop, and the terrain file is 130 MB.
