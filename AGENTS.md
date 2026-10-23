# Himal

Nepal-only iOS app that names the peaks around you. See `README.md` for how it works and how to run it.

- Contact address for this project: `ispanta03@gmail.com`.
- Fetch OSM data from a Geofabrik extract. Never send bulk Overpass queries.
- Do not commit App Store screenshots or other copyrighted assets.
- Do not copy code from Fry19/peak. It has no license.
- `App/Himal/Resources/nepal-dem.i16` is 130 MB and stays out of git. Rebuild it with `tools/build-data.py`.
- Engine tests: `swift test` in `Packages/PeakCore`. App build: `tools/sim-shot.sh`.
- Pitch and roll come from gravity. Do not use the CoreMotion rotation matrix without a device test.
