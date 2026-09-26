#!/usr/bin/env python3
import json
import math
import os
import re
import sys
from collections import defaultdict

import osmium

PBF = sys.argv[1] if len(sys.argv) > 1 else "/tmp/syria.osm.pbf"
OUT = sys.argv[2] if len(sys.argv) > 2 else "source/world/data/syria_hydrology.json"

WEST, EAST = 35.45, 42.55
NORTH, SOUTH = 37.45, 32.15
RIVER_TYPES = {"river", "canal"}
GRID_DEG = 0.05


def in_bounds(lon, lat, margin=0.1):
    return WEST - margin <= lon <= EAST + margin and SOUTH - margin <= lat <= NORTH + margin


def point_segment_distance(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    if dx == 0.0 and dy == 0.0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    qx, qy = ax + t * dx, ay + t * dy
    return math.hypot(px - qx, py - qy)


def rdp(points, epsilon):
    if len(points) <= 2:
        return points
    a, b = points[0], points[-1]
    max_d = -1.0
    index = 0
    for i in range(1, len(points) - 1):
        d = point_segment_distance(points[i], a, b)
        if d > max_d:
            max_d = d
            index = i
    if max_d > epsilon:
        left = rdp(points[: index + 1], epsilon)
        right = rdp(points[index:], epsilon)
        return left[:-1] + right
    return [a, b]


def width_m(raw):
    if not raw:
        return 0.0
    match = re.search(r"\d+(?:\.\d+)?", str(raw).replace(",", "."))
    return float(match.group(0)) if match else 0.0


def canonical_river_group(name, name_en, waterway, way_id):
    combined = ("%s %s" % (name or "", name_en or "")).strip().lower()
    aliases = (
        (("euphrates", "الفرات"), "river:euphrates"),
        (("tigris", "دجلة"), "river:tigris"),
        (("khabur", "khabour", "خابور", "الخابور"), "river:khabur"),
        (("orontes", "العاصي"), "river:orontes"),
    )
    for needles, group in aliases:
        if any(needle in combined for needle in needles):
            return group
    normalized = re.sub(r"[^0-9a-z\u0600-\u06ff]+", "-", combined).strip("-")
    if normalized:
        return "%s:%s" % (waterway, normalized)
    return "way:%d" % int(way_id)


def xy_km(lon, lat, ref_lat):
    return (lon * 111.32 * math.cos(math.radians(ref_lat)), lat * 111.32)


def nearest_on_segment_geo(p, a, b):
    ref_lat = (p[1] + a[1] + b[1]) / 3.0
    px, py = xy_km(p[0], p[1], ref_lat)
    ax, ay = xy_km(a[0], a[1], ref_lat)
    bx, by = xy_km(b[0], b[1], ref_lat)
    dx, dy = bx - ax, by - ay
    if dx == 0.0 and dy == 0.0:
        return a, math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    lon = a[0] + (b[0] - a[0]) * t
    lat = a[1] + (b[1] - a[1]) * t
    qx, qy = xy_km(lon, lat, ref_lat)
    return (lon, lat), math.hypot(px - qx, py - qy)


def grid_cell(lon, lat):
    return (int(math.floor((lon - WEST) / GRID_DEG)), int(math.floor((lat - SOUTH) / GRID_DEG)))


def bridge_geometry_metadata(points):
    if len(points) < 2:
        return 0.0, 0.0
    ref_lat = sum(p[1] for p in points) / float(len(points))
    east_total = 0.0
    north_total = 0.0
    length_km = 0.0
    for i in range(len(points) - 1):
        ax, ay = xy_km(points[i][0], points[i][1], ref_lat)
        bx, by = xy_km(points[i + 1][0], points[i + 1][1], ref_lat)
        east = bx - ax
        north = by - ay
        east_total += east
        north_total += north
        length_km += math.hypot(east, north)
    heading_rad = math.atan2(-east_total, north_total) if abs(east_total) + abs(north_total) > 1e-9 else 0.0
    return heading_rad, length_km * 1000.0


class HydrologyCollector(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.rivers = []
        self.bridge_ways = []
        self.ford_nodes = []

    def node(self, n):
        if not n.location.valid():
            return
        tags = dict(n.tags)
        if not (tags.get("ford") not in (None, "", "no") or tags.get("highway") == "ford"):
            return
        lon = float(n.location.lon)
        lat = float(n.location.lat)
        if not in_bounds(lon, lat):
            return
        self.ford_nodes.append({
            "node_id": int(n.id),
            "lon": lon,
            "lat": lat,
            "name": tags.get("name:ar") or tags.get("name") or "",
        })

    def way(self, w):
        tags = dict(w.tags)
        waterway = tags.get("waterway", "")
        is_bridge = "highway" in tags and tags.get("bridge") not in (None, "", "no")
        if waterway not in RIVER_TYPES and not is_bridge:
            return

        geom = []
        try:
            for nr in w.nodes:
                if not nr.location.valid():
                    continue
                lon = float(nr.location.lon)
                lat = float(nr.location.lat)
                if in_bounds(lon, lat):
                    geom.append((lon, lat))
        except Exception:
            return
        if len(geom) < 2:
            return

        if waterway in RIVER_TYPES:
            simplified = rdp(geom, 0.00035 if waterway == "river" else 0.00025)
            river_name = tags.get("name:ar") or tags.get("name") or ""
            river_name_en = tags.get("name:en") or ""
            self.rivers.append({
                "id": "way:%d" % int(w.id),
                "river_group": canonical_river_group(river_name, river_name_en, waterway, int(w.id)),
                "name": river_name,
                "name_en": river_name_en,
                "waterway": waterway,
                "width_m": round(width_m(tags.get("width")), 2),
                "blocking": waterway == "river",
                "points": simplified,
            })

        if is_bridge:
            self.bridge_ways.append({
                "way_id": int(w.id),
                "name": tags.get("name:ar") or tags.get("name") or "",
                "highway": tags.get("highway", ""),
                "points": geom,
            })


def build_segment_index(rivers):
    index = defaultdict(list)
    for river_index, river in enumerate(rivers):
        if not river["blocking"]:
            continue
        pts = river["points"]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            min_lon, max_lon = sorted((a[0], b[0]))
            min_lat, max_lat = sorted((a[1], b[1]))
            c0 = grid_cell(min_lon, min_lat)
            c1 = grid_cell(max_lon, max_lat)
            record = (river_index, a, b)
            for gx in range(c0[0], c1[0] + 1):
                for gy in range(c0[1], c1[1] + 1):
                    index[(gx, gy)].append(record)
    return index


def nearest_river(point, rivers, segment_index, max_km):
    cell = grid_cell(point[0], point[1])
    best = None
    seen = set()
    for gx in range(cell[0] - 1, cell[0] + 2):
        for gy in range(cell[1] - 1, cell[1] + 2):
            for river_index, a, b in segment_index.get((gx, gy), []):
                key = (river_index, a, b)
                if key in seen:
                    continue
                seen.add(key)
                q, distance = nearest_on_segment_geo(point, a, b)
                if distance <= max_km and (best is None or distance < best[0]):
                    best = (distance, river_index, q)
    return best


def add_crossing(result, item):
    for old in result:
        if old["river_id"] != item["river_id"]:
            continue
        _, d = nearest_on_segment_geo(
            (item["lon"], item["lat"]),
            (old["lon"], old["lat"]),
            (old["lon"], old["lat"]),
        )
        if d < 0.18:
            if old["kind"] == "ford" and item["kind"] == "bridge":
                old.update(item)
            return
    result.append(item)


def main():
    handler = HydrologyCollector()
    handler.apply_file(PBF, locations=True, idx="flex_mem")

    segment_index = build_segment_index(handler.rivers)
    crossings = []

    for bridge in handler.bridge_ways:
        pts = bridge["points"]
        midpoint = pts[len(pts) // 2]
        nearest = nearest_river(midpoint, handler.rivers, segment_index, 0.35)
        if nearest is None:
            continue
        _, river_index, q = nearest
        river = handler.rivers[river_index]
        heading_rad, bridge_length_m = bridge_geometry_metadata(pts)
        add_crossing(crossings, {
            "kind": "bridge",
            "river_id": river["id"],
            "river_name": river["name"],
            "name": bridge["name"],
            "road_class": bridge["highway"],
            "source_id": "way:%d" % bridge["way_id"],
            "lon": round(q[0], 6),
            "lat": round(q[1], 6),
            "heading_rad": round(heading_rad, 6),
            "bridge_length_m": round(bridge_length_m, 1),
        })

    for ford in handler.ford_nodes:
        point = (ford["lon"], ford["lat"])
        nearest = nearest_river(point, handler.rivers, segment_index, 0.25)
        if nearest is None:
            continue
        _, river_index, q = nearest
        river = handler.rivers[river_index]
        add_crossing(crossings, {
            "kind": "ford",
            "river_id": river["id"],
            "river_name": river["name"],
            "name": ford["name"],
            "source_id": "node:%d" % ford["node_id"],
            "lon": round(q[0], 6),
            "lat": round(q[1], 6),
        })

    clean_rivers = []
    for river in handler.rivers:
        if len(river["points"]) < 2:
            continue
        item = dict(river)
        item["points"] = [[round(lon, 6), round(lat, 6)] for lon, lat in river["points"]]
        clean_rivers.append(item)

    payload = {
        "source": "OpenStreetMap",
        "bounds": [WEST, SOUTH, EAST, NORTH],
        "rivers": clean_rivers,
        "crossings": crossings,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))

    blocking = sum(1 for river in clean_rivers if river["blocking"])
    print("DAM hydrology:", len(clean_rivers), "waterways,", blocking, "blocking rivers,", len(crossings), "legal crossings")
    print("bytes:", os.path.getsize(OUT))


if __name__ == "__main__":
    main()
