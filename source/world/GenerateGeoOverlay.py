#!/usr/bin/env python3
import json
import math
import os
import sys
from collections import defaultdict

import osmium

PBF = sys.argv[1] if len(sys.argv) > 1 else "/tmp/syria.osm.pbf"
OUT = sys.argv[2] if len(sys.argv) > 2 else "source/world/generated/syria_geo_overlay.json"

WEST, EAST = 35.45, 42.55
NORTH, SOUTH = 37.45, 32.15
ADMIN_LEVELS = {2, 4, 6, 8}
PLACE_TYPES = {"city", "town", "village", "hamlet", "suburb", "neighbourhood", "locality"}


def in_bounds(lon, lat):
    return WEST <= lon <= EAST and SOUTH <= lat <= NORTH


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


class RelationCollector(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.way_levels = {}
        self.admin_labels = []
        self.label_node_ids = set()

    def relation(self, r):
        tags = dict(r.tags)
        if tags.get("boundary") != "administrative":
            return
        try:
            level = int(tags.get("admin_level", "0"))
        except ValueError:
            return
        if level not in ADMIN_LEVELS:
            return

        name = tags.get("name:ar") or tags.get("name") or ""
        label_ref = None
        admin_ref = None

        for m in r.members:
            mtype = str(m.type)
            if mtype == "w":
                old = self.way_levels.get(int(m.ref))
                if old is None or level < old:
                    self.way_levels[int(m.ref)] = level
            elif mtype == "n":
                role = str(m.role)
                if role == "label":
                    label_ref = int(m.ref)
                elif role == "admin_centre":
                    admin_ref = int(m.ref)

        chosen = label_ref if label_ref is not None else admin_ref
        if chosen is not None and name:
            self.label_node_ids.add(chosen)
            self.admin_labels.append({
                "node": chosen,
                "level": level,
                "name": name,
            })


class WayCollector(osmium.SimpleHandler):
    def __init__(self, wanted):
        super().__init__()
        self.wanted = wanted
        self.ways = {}
        self.node_ids = set()

    def way(self, w):
        wid = int(w.id)
        if wid not in self.wanted:
            return
        refs = [int(n.ref) for n in w.nodes]
        if len(refs) < 2:
            return
        self.ways[wid] = refs
        self.node_ids.update(refs)


class NodeCollector(osmium.SimpleHandler):
    def __init__(self, wanted_nodes):
        super().__init__()
        self.wanted_nodes = wanted_nodes
        self.coords = {}
        self.places = []

    def node(self, n):
        if not n.location.valid():
            return
        lon = float(n.location.lon)
        lat = float(n.location.lat)

        nid = int(n.id)
        if nid in self.wanted_nodes:
            self.coords[nid] = (lon, lat)

        tags = dict(n.tags)
        place = tags.get("place", "")
        if place not in PLACE_TYPES or not in_bounds(lon, lat):
            return
        name = tags.get("name:ar") or tags.get("name") or ""
        if not name:
            return
        self.places.append({
            "type": place,
            "name": name,
            "lon": round(lon, 6),
            "lat": round(lat, 6),
        })


def min_zoom_for_place(place):
    return {
        "city": 6,
        "town": 7,
        "village": 9,
        "hamlet": 10,
        "suburb": 9,
        "neighbourhood": 10,
        "locality": 10,
    }.get(place, 10)


def main():
    rel = RelationCollector()
    rel.apply_file(PBF)

    ways = WayCollector(set(rel.way_levels.keys()))
    ways.apply_file(PBF)

    wanted_nodes = set(ways.node_ids) | set(rel.label_node_ids)
    nodes = NodeCollector(wanted_nodes)
    nodes.apply_file(PBF)

    boundaries = []
    tolerances = {2: 0.0040, 4: 0.0020, 6: 0.0010, 8: 0.0005}

    for wid, refs in ways.ways.items():
        level = int(rel.way_levels[wid])
        pts = []
        for ref in refs:
            pos = nodes.coords.get(ref)
            if pos is None:
                continue
            lon, lat = pos
            if WEST - 0.15 <= lon <= EAST + 0.15 and SOUTH - 0.15 <= lat <= NORTH + 0.15:
                pts.append((lon, lat))
        if len(pts) < 2:
            continue

        pts = rdp(pts, tolerances[level])
        boundaries.append({
            "level": level,
            "points": [[round(lon, 6), round(lat, 6)] for lon, lat in pts],
        })

    labels = []
    seen = set()
    for item in rel.admin_labels:
        pos = nodes.coords.get(int(item["node"]))
        if pos is None:
            continue
        lon, lat = pos
        if not in_bounds(lon, lat):
            continue
        key = ("admin", item["level"], item["name"], round(lon, 4), round(lat, 4))
        if key in seen:
            continue
        seen.add(key)
        labels.append({
            "kind": "admin",
            "level": int(item["level"]),
            "name": item["name"],
            "lon": round(lon, 6),
            "lat": round(lat, 6),
            "min_zoom": {2: 6, 4: 6, 6: 7, 8: 9}[int(item["level"])],
        })

    for p in nodes.places:
        key = ("place", p["name"], round(p["lon"], 4), round(p["lat"], 4))
        if key in seen:
            continue
        seen.add(key)
        q = dict(p)
        q["kind"] = "place"
        q["min_zoom"] = min_zoom_for_place(p["type"])
        labels.append(q)

    output = {
        "source": "OpenStreetMap",
        "bounds": [WEST, SOUTH, EAST, NORTH],
        "boundaries": boundaries,
        "labels": labels,
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, separators=(",", ":"))

    print("DAM geo overlay:", len(boundaries), "boundary segments,", len(labels), "labels")
    print("bytes:", os.path.getsize(OUT))


if __name__ == "__main__":
    main()
