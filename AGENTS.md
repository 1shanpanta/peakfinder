# Himal

Nepal-only app that names the peaks around you, on iOS (`ios/`) and Android (`android/`). See `README.md` for the layout, setup and tests.

- Contact address for this project: `ispanta03@gmail.com`.
- Fetch OSM data from a Geofabrik extract. Never send bulk Overpass queries.
- Do not commit App Store screenshots or other copyrighted assets.
- Do not copy code from Fry19/peak. It has no license.
- `shared/data/nepal-dem.i16` is 130 MB and stays out of git. Rebuild it with `tools/build-data.py`.
- The two engines must agree. Change a rule in one, then change the other and its tests.
- iOS engine tests: `swift test` in `ios/PeakCore`. iOS app build: `tools/ios-sim-shot.sh`.
- Android needs `JAVA_HOME` (JDK 17) and `ANDROID_HOME` set by hand. Engine tests: `./gradlew :core:test` in `android`. App build: `tools/android-shot.sh`.
- Put no redirect to a `$VARIABLE` path in a Bash command. A hook blocks it. Write the full temp path or use a script.
- Android pose comes from the rotation vector sensor, which Android documents. Magnetic heading plus declination gives true heading.
- iOS pitch and roll come from gravity. Do not use the CoreMotion rotation matrix without a device test.
- Never leave long builds or caches in the session scratchpad. It gets wiped. Use `~/Library/Caches`.
