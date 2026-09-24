#!/usr/bin/env python3
import json
import math
import os
import sys
import osmium

PBF = sys.argv[1] if len(sys.argv) > 1 else "/tmp/syria.osm.pbf"
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else "source/world/data"

# First-pass detailed urban sectors: one real sector for each Syrian governorate.
# These are intentionally compact enough for Android; later we expand sectors
# until every governorate becomes continuous.
GOVERNORATES = [
    {"slug":"damascus","name_ar":"دمشق","name_en":"Damascus","lat":33.5138,"lon":36.2765},
    {"slug":"rif_dimashq","name_ar":"ريف دمشق","name_en":"Rif Dimashq","lat":33.5723,"lon":36.4027},
    {"slug":"aleppo","name_ar":"حلب","name_en":"Aleppo","lat":36.201241,"lon":37.161173},
    {"slug":"homs","name_ar":"حمص","name_en":"Homs","lat":34.7324,"lon":36.7137},
    {"slug":"hama","name_ar":"حماة","name_en":"Hama","lat":35.1318,"lon":36.7578},
    {"slug":"latakia","name_ar":"اللاذقية","name_en":"Latakia","lat":35.5317,"lon":35.7901},
    {"slug":"tartus","name_ar":"طرطوس","name_en":"Tartus","lat":34.8959,"lon":35.8867},
    {"slug":"idlib","name_ar":"إدلب","name_en":"Idlib","lat":35.9306,"lon":36.6339},
    {"slug":"raqqa","name_ar":"الرقة","name_en":"Raqqa","lat":35.9594,"lon":39.0079},
    {"slug":"deir_ez_zor","name_ar":"دير الزور","name_en":"Deir ez-Zor","lat":35.3359,"lon":40.1408},
    {"slug":"hasakah","name_ar":"الحسكة","name_en":"Al-Hasakah","lat":36.5024,"lon":40.7477},
    {"slug":"daraa","name_ar":"درعا","name_en":"Daraa","lat":32.6189,"lon":36.1021},
    {"slug":"suwayda","name_ar":"السويداء","name_en":"As-Suwayda","lat":32.7089,"lon":36.5695},
    {"slug":"quneitra","name_ar":"القنيطرة","name_en":"Quneitra","lat":33.1259,"lon":35.8246},
]

HALF_LAT = 0.032
HALF_LON = 0.040
MAX_ROADS = 2600
MAX_BUILDINGS = 1500
MAX_WATER = 350
MAX_PLACES = 120

for g in GOVERNORATES:
    g["south"] = g["lat"] - HALF_LAT
    g["north"] = g["lat"] + HALF_LAT
    g["west"] = g["lon"] - HALF_LON
    g["east"] = g["lon"] + HALF_LON
    g["roads"] = []
    g["buildings"] = []
    g["water"] = []
    g["places"] = []


def in_bbox(lat, lon, g):
    return g["south"] <= lat <= g["north"] and g["west"] <= lon <= g["east"]


def distance2(lat, lon, g):
    dx = (lon - g["lon"]) * math.cos(math.radians(g["lat"]))
    dy = lat - g["lat"]
    return dx * dx + dy * dy


def compact_tags(tags, keys):
    return {k: tags[k] for k in keys if k in tags}


class SyriaHandler(osmium.SimpleHandler):
    def node(self, n):
        tags = dict(n.tags)
        place = tags.get("place")
        if place not in {"city","town","village","hamlet","suburb","neighbourhood"}:
            return
        try:
            lat = float(n.location.lat)
            lon = float(n.location.lon)
        except Exception:
            return
        for g in GOVERNORATES:
            if in_bbox(lat, lon, g):
                item = {
                    "type":"node",
                    "lat":round(lat, 6),
                    "lon":round(lon, 6),
                    "tags":compact_tags(tags, ("place","name","name:ar")),
                }
                g["places"].append((distance2(lat, lon, g), item))

    def way(self, w):
        tags = dict(w.tags)
        relevant = (
            "highway" in tags
            or "building" in tags
            or "waterway" in tags
            or tags.get("natural") == "water"
        )
        if not relevant:
            return

        geom = []
        min_lat = 90.0
        max_lat = -90.0
        min_lon = 180.0
        max_lon = -180.0
        try:
            for nr in w.nodes:
                loc = nr.location
                if not loc.valid():
                    continue
                lat = float(loc.lat)
                lon = float(loc.lon)
                geom.append({"lat":round(lat,6),"lon":round(lon,6)})
                min_lat = min(min_lat, lat)
                max_lat = max(max_lat, lat)
                min_lon = min(min_lon, lon)
                max_lon = max(max_lon, lon)
        except Exception:
            return

        if len(geom) < 2:
            return

        center_lat = (min_lat + max_lat) * 0.5
        center_lon = (min_lon + max_lon) * 0.5

        for g in GOVERNORATES:
            intersects = not (
                max_lat < g["south"] or min_lat > g["north"]
                or max_lon < g["west"] or min_lon > g["east"]
            )
            if not intersects:
                continue

            if "highway" in tags:
                item = {
                    "type":"way",
                    "geometry":geom,
                    "tags":{"highway":tags.get("highway","road")},
                }
                g["roads"].append((distance2(center_lat, center_lon, g), item))
            elif "building" in tags and len(geom) >= 4:
                item = {
                    "type":"way",
                    "geometry":geom,
                    "tags":compact_tags(tags, ("building","height","building:levels")),
                }
                g["buildings"].append((distance2(center_lat, center_lon, g), item))
            elif "waterway" in tags or tags.get("natural") == "water":
                item = {
                    "type":"way",
                    "geometry":geom,
                    "tags":compact_tags(tags, ("waterway","natural")),
                }
                g["water"].append((distance2(center_lat, center_lon, g), item))


def take_nearest(items, limit):
    items.sort(key=lambda x: x[0])
    return [x[1] for x in items[:limit]]


os.makedirs(OUT_DIR, exist_ok=True)
handler = SyriaHandler()
handler.apply_file(PBF, locations=True, idx="flex_mem")

manifest = []
for g in GOVERNORATES:
    roads = take_nearest(g["roads"], MAX_ROADS)
    buildings = take_nearest(g["buildings"], MAX_BUILDINGS)
    water = take_nearest(g["water"], MAX_WATER)
    places = take_nearest(g["places"], MAX_PLACES)

    payload = {
        "meta":{
            "slug":g["slug"],
            "name_ar":g["name_ar"],
            "name_en":g["name_en"],
            "center":[g["lat"],g["lon"]],
            "sector_bbox":[g["south"],g["west"],g["north"],g["east"]],
        },
        "elements": roads + water + places + buildings,
    }

    path = os.path.join(OUT_DIR, f"syria_{g['slug']}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",",":"))

    size = os.path.getsize(path)
    print(
        g["slug"],
        "roads",len(roads),
        "buildings",len(buildings),
        "water",len(water),
        "places",len(places),
        "bytes",size
    )
    manifest.append({
        "slug":g["slug"],
        "name_ar":g["name_ar"],
        "name_en":g["name_en"],
        "lat":g["lat"],
        "lon":g["lon"],
        "file":f"syria_{g['slug']}.json",
        "bytes":size,
    })

with open(os.path.join(OUT_DIR, "syria_manifest.json"), "w", encoding="utf-8") as f:
    json.dump({"governorates":manifest}, f, ensure_ascii=False, separators=(",",":"))

print("compiled governorates:", len(manifest))
