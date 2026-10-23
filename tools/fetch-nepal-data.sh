#!/usr/bin/env bash
# Download Nepal terrain (Copernicus GLO-30 tiles) and the Nepal OSM extract, then cut out the peaks.
# Usage: tools/fetch-nepal-data.sh [data-dir]
# data-dir defaults to $PEAKFINDER_DATA, else ../peakfinder-data. Resumable: rerun after a break.
set -u

data="${1:-${PEAKFINDER_DATA:-$(dirname "$0")/../../peakfinder-data}}"
mkdir -p "$data/dem" "$data/osm"

# Tiles are named by their lower-left corner. Nepal spans N26-N30, E080-E088.
for lat in 26 27 28 29 30; do
  for lon in 080 081 082 083 084 085 086 087 088; do
    name="Copernicus_DSM_COG_10_N${lat}_00_E${lon}_00_DEM"
    curl -sfL -C - -o "$data/dem/$name.tif" \
      "https://copernicus-dem-30m.s3.amazonaws.com/$name/$name.tif" || echo "MISS $name"
  done
done
echo "DEM done"

curl -sfL -C - -o "$data/osm/nepal.osm.pbf" https://download.geofabrik.de/asia/nepal-latest.osm.pbf \
  && echo "OSM done" || { echo "OSM FAILED"; exit 1; }

# Needs `osmium` (brew install osmium-tool). Keeps only the peak points.
mkdir -p "$data/peaks"
osmium tags-filter "$data/osm/nepal.osm.pbf" n/natural=peak -o "$data/peaks/nepal-peaks.osm.pbf" --overwrite
osmium export "$data/peaks/nepal-peaks.osm.pbf" -f geojson -o "$data/peaks/nepal-peaks.geojson" --overwrite
echo "peaks done"
