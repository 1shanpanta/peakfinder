# /// script
# requires-python = ">=3.11"
# dependencies = ["rasterio", "numpy"]
# ///
"""Pack the downloaded Nepal data into the two files the app bundles.

Usage: uv run tools/build-data.py [data-dir] [out-dir]   (out-dir defaults to shared/data)
Reads  <data-dir>/dem/*.tif and <data-dir>/peaks/nepal-peaks.geojson (see fetch-nepal-data.sh).
Writes <out-dir>/nepal-dem.i16 (int16 little-endian, north row first), nepal-dem.json (grid header)
and nepal-peaks.json. Each 3 arc-second cell keeps the HIGHEST of its 3x3 source cells so summits survive.
"""
import json
import re
import sys
from pathlib import Path

import numpy as np
import rasterio

SOUTH, NORTH, WEST, EAST = 26, 31, 80, 89
CELLS_PER_DEG = 1200  # 3 arc-seconds

data = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "peakfinder-data")
out = Path(sys.argv[2] if len(sys.argv) > 2 else Path(__file__).resolve().parents[1] / "shared/data")
out.mkdir(parents=True, exist_ok=True)

rows, cols = (NORTH - SOUTH) * CELLS_PER_DEG, (EAST - WEST) * CELLS_PER_DEG
grid = np.zeros((rows, cols), dtype=np.int16)
for lat in range(SOUTH, NORTH):
    for lon in range(WEST, EAST):
        tile = data / "dem" / f"Copernicus_DSM_COG_10_N{lat:02d}_00_E{lon:03d}_00_DEM.tif"
        with rasterio.open(tile) as src:
            full = src.read(1)
        if full.shape != (3 * CELLS_PER_DEG, 3 * CELLS_PER_DEG):
            raise SystemExit(f"{tile.name}: unexpected shape {full.shape}")
        block = full.reshape(CELLS_PER_DEG, 3, CELLS_PER_DEG, 3).max(axis=(1, 3))
        r0 = (NORTH - 1 - lat) * CELLS_PER_DEG
        c0 = (lon - WEST) * CELLS_PER_DEG
        grid[r0 : r0 + CELLS_PER_DEG, c0 : c0 + CELLS_PER_DEG] = np.rint(block).astype(np.int16)

(out / "nepal-dem.i16").write_bytes(grid.astype("<i2").tobytes())
(out / "nepal-dem.json").write_text(
    json.dumps({"north": NORTH, "west": WEST, "rows": rows, "cols": cols, "cellsPerDegree": CELLS_PER_DEG})
)
print(f"dem {rows}x{cols}, max {grid.max()} m, min {grid.min()} m")

LATIN = re.compile(r"[A-Za-z]")
DEVANAGARI = re.compile(r"[ऀ-ॿ]+")


def label(tags: dict) -> str:
    for key in ("name:en", "int_name"):
        value = tags.get(key, "").strip().rstrip("?").strip()
        if LATIN.search(value):
            return value
    name = tags.get("name", "").strip()
    latin_words = [w for w in name.split() if LATIN.search(w) and all(ord(c) < 0x250 for c in w)]
    if latin_words:
        return " ".join(latin_words)
    for candidate in (tags.get("name:ne", ""), name):
        match = DEVANAGARI.search(candidate)
        if match:
            return match.group(0)
    return ""


def height_at(lat: float, lon: float) -> int:
    row = min(rows - 1, max(0, int((NORTH - lat) * CELLS_PER_DEG)))
    col = min(cols - 1, max(0, int((lon - WEST) * CELLS_PER_DEG)))
    return int(grid[row, col])


peaks = []
for feature in json.load(open(data / "peaks/nepal-peaks.geojson"))["features"]:
    if feature["geometry"]["type"] != "Point":
        continue
    tags = feature["properties"]
    name = label(tags).rstrip("? ")
    if not name:
        continue
    lon, lat = feature["geometry"]["coordinates"]
    try:
        elevation = round(float(tags["ele"]))
    except (KeyError, ValueError):
        elevation = height_at(lat, lon)
    peaks.append({"name": name, "ele": elevation, "lat": round(lat, 5), "lon": round(lon, 5)})

peaks.sort(key=lambda p: -p["ele"])
(out / "nepal-peaks.json").write_text(json.dumps(peaks, ensure_ascii=False, separators=(",", ":")))
print(f"peaks {len(peaks)}; top: {[p['name'] for p in peaks[:5]]}")
