#!/usr/bin/env python3
import json, math, sys

path = sys.argv[1] if len(sys.argv) > 1 else "source/world/data/aleppo_osm.json"
ALEPPO_LAT = 36.201241
ALEPPO_LON = 37.161173
MAX_BUILDINGS = 1400

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

roads, water, places, buildings = [], [], [], []

def compact_geom(geom):
    out = []
    for p in geom or []:
        if "lat" in p and "lon" in p:
            out.append({"lat": round(float(p["lat"]), 6), "lon": round(float(p["lon"]), 6)})
    return out

for e in data.get("elements", []):
    if not isinstance(e, dict):
        continue
    tags = e.get("tags") or {}
    typ = e.get("type")

    if typ == "node" and tags.get("place") in {"city","town","village"}:
        if "lat" in e and "lon" in e:
            places.append({
                "type":"node",
                "lat":round(float(e["lat"]),6),
                "lon":round(float(e["lon"]),6),
                "tags":{k:tags[k] for k in ("place","name","name:ar") if k in tags}
            })
        continue

    geom = compact_geom(e.get("geometry"))
    if len(geom) < 2:
        continue

    if "highway" in tags:
        roads.append({"type":"way","geometry":geom,"tags":{"highway":tags.get("highway","road")}})
    elif "building" in tags and len(geom) >= 4:
        lat = sum(p["lat"] for p in geom) / len(geom)
        lon = sum(p["lon"] for p in geom) / len(geom)
        d2 = (lat-ALEPPO_LAT)**2 + ((lon-ALEPPO_LON)*0.81)**2
        keep_tags = {k:tags[k] for k in ("building","height","building:levels") if k in tags}
        buildings.append((d2, {"type":"way","geometry":geom,"tags":keep_tags}))
    elif "waterway" in tags or tags.get("natural") == "water":
        keep_tags = {k:tags[k] for k in ("waterway","natural") if k in tags}
        water.append({"type":"way","geometry":geom,"tags":keep_tags})

buildings.sort(key=lambda x: x[0])
selected_buildings = [e for _, e in buildings[:MAX_BUILDINGS]]
out = {"elements": roads + water + places + selected_buildings}

with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",",":"))

print("compact Aleppo:",
      "roads", len(roads),
      "water", len(water),
      "places", len(places),
      "buildings", len(selected_buildings))
