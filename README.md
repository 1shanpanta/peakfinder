# peakfinder

Local replica of the PeakFinder iOS app. It labels mountain peaks on a 360 degree panorama.

## Frozen decisions

- Platform: native Swift iOS app. Xcode 26.6, Swift 6.3.3.
- Region: Nepal only.
- v1 scope: GPS position, compass heading, flat panorama with peak names and heights, camera overlay, fully offline.
- UI target is PeakFinder: a flat horizon outline, slanted name and height labels on vertical leader lines, a compass dial with the heading, and a location chip.
- Out of v1: map pick, sun and moon paths, telescope, "show me", fly mode, skyline matching.
- Prior art: Fry19/peak has no license. Read it for ideas only. Never copy its code.
- Terrain: Copernicus GLO-30 (30 m), cut to Nepal.
- Peak names: OpenStreetMap `natural=peak`, from a Geofabrik extract.
- Distribution: sideload to one phone. No App Store release.
- Testing: real iPhone on a cable. The simulator has no compass, tilt or camera.

## Parked unknowns

- Data packing: one preprocessed grid file or tiles. Decide after the first horizon render.
- Horizon method: ray march or heightmap sweep. Decide after a Python prototype.
- Rendering: SwiftUI Canvas or Metal.
- App name: not "PeakFinder" if it ever ships.

## Decisions log

- Shell changed from the web page recommendation to native Swift, by Ishan.
- Own build kept after the prior art search. UI follows PeakFinder, ideas come from Peak, by Ishan.
