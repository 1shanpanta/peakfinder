# Himal

A Nepal-only iOS app that names the peaks around you. It draws a flat panorama of the ridges with a tilted label on each peak. A camera mode puts the same labels over the live camera. It works offline.

The idea comes from the PeakFinder app. Himal is a personal build, sideloaded to one phone. It is not for the App Store.

## How it works

- Terrain: Copernicus GLO-30 heights, packed at 3 arc-seconds (about 90 m). Each cell keeps the highest source cell, so summits survive.
- Peaks: OpenStreetMap `natural=peak` points with a Latin or Devanagari name. 619 peaks.
- Engine: `Packages/PeakCore` shoots 3600 rays from the viewpoint. It keeps the steepest angle on each ray, after Earth curvature and refraction.
- A peak is visible when its summit angle is not below the steepest ground in front of it.
- Heading comes from the compass. Pitch and roll come from the gravity vector.

## Setup

1. Run `tools/fetch-nepal-data.sh`. It downloads 1.7 GB of terrain and the Nepal OSM extract to `../peakfinder-data`, then cuts the peaks with `osmium`.
2. Run `uv run tools/build-data.py`. It writes the packed files to `App/Himal/Resources`.
3. Run `xcodegen generate` in `App`.
4. Open `App/Himal.xcodeproj`. Pick your Apple ID under Signing, then run on the phone.

A free Apple ID expires the app after 7 days. Run it again from Xcode to renew it.

## Test

- Engine: `swift test` in `Packages/PeakCore`. The Nepal sightline tests skip when the packed data is missing.
- Screen: `tools/sim-shot.sh OUT.png -lat 27.7172 -lon 85.52 -heading 77` builds, launches and screenshots the simulator.

## Not verified yet

- Live compass and camera alignment on a real phone. The simulator has neither.
- Landscape layout.
- Accuracy against a real photo.

## Limits

- Only 619 named peaks. OSM has no English name for most Nepali peaks.
- The terrain model includes roofs and trees. Ground under 25 m within 2 km is ignored.
- Bearings use a sphere, which is up to 0.15 degrees off the WGS84 geodesic.

## Decisions log

- Shell changed from the web page recommendation to native Swift, by Ishan.
- Own build kept after the prior art search. UI follows PeakFinder, ideas come from Peak, by Ishan.
- Pitch and roll use gravity, not the attitude matrix. Apple documents the matrix frame in conflicting ways.
