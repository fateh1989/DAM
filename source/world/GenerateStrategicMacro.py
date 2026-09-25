#!/usr/bin/env python3
import io
import math
import os
import random
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

try:
    import osmium
except Exception:
    osmium = None

PBF = sys.argv[1] if len(sys.argv) > 1 else "/tmp/syria.osm.pbf"
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else "source/world/generated"

WEST, EAST = 35.55, 42.45
NORTH, SOUTH = 37.35, 32.25
ZOOM = 8
TILE = 256
SIZE = 2048
MAX_HEIGHT_M = 4000.0

PALETTE = {
    "grass": np.array([0x4A, 0x6B, 0x3D], dtype=np.float32),
    "dry": np.array([0xA6, 0x92, 0x58], dtype=np.float32),
    "soil": np.array([0x6B, 0x4F, 0x3A], dtype=np.float32),
    "rock": np.array([0x5A, 0x62, 0x68], dtype=np.float32),
    "forest": (43, 66, 36),
    "orchard": (85, 107, 47),
    "farmland": (139, 126, 72),
}

def tile_xy(lon, lat, z):
    n = 2 ** z
    x = (lon + 180.0) / 360.0 * n
    r = math.radians(max(-85.05112878, min(85.05112878, lat)))
    y = (1.0 - math.asinh(math.tan(r)) / math.pi) * 0.5 * n
    return x, y

def download_tile(z, x, y):
    url = f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
    req = urllib.request.Request(url, headers={"User-Agent": "DAM-RTS/0.3"})
    last = None
    for _ in range(3):
        try:
            with urllib.request.urlopen(req, timeout=25) as response:
                return Image.open(io.BytesIO(response.read())).convert("RGB")
        except Exception as exc:
            last = exc
    raise RuntimeError(f"failed DEM tile {z}/{x}/{y}: {last}")

def decode_terrarium(img):
    a = np.asarray(img, dtype=np.float32)
    return a[:, :, 0] * 256.0 + a[:, :, 1] + a[:, :, 2] / 256.0 - 32768.0

def build_elevation():
    xw, yn = tile_xy(WEST, NORTH, ZOOM)
    xe, ys = tile_xy(EAST, SOUTH, ZOOM)
    x0, x1 = math.floor(xw), math.floor(xe)
    y0, y1 = math.floor(yn), math.floor(ys)

    mosaic = np.zeros(((y1-y0+1)*TILE, (x1-x0+1)*TILE), dtype=np.float32)
    for ty in range(y0, y1+1):
        for tx in range(x0, x1+1):
            tile = decode_terrarium(download_tile(ZOOM, tx, ty))
            oy, ox = (ty-y0)*TILE, (tx-x0)*TILE
            mosaic[oy:oy+TILE, ox:ox+TILE] = tile

    # Equirectangular output: UV maps linearly to Syria lon/lat in DAM.
    lons = np.linspace(WEST, EAST, SIZE, dtype=np.float64)
    lats = np.linspace(NORTH, SOUTH, SIZE, dtype=np.float64)
    xs = np.array([tile_xy(float(lon), NORTH, ZOOM)[0] for lon in lons])
    ys = np.array([tile_xy(WEST, float(lat), ZOOM)[1] for lat in lats])
    xp = np.clip((xs - x0) * TILE, 0, mosaic.shape[1]-1.001)
    yp = np.clip((ys - y0) * TILE, 0, mosaic.shape[0]-1.001)

    # Horizontal resample first.
    xbase = np.arange(mosaic.shape[1], dtype=np.float64)
    horiz = np.empty((mosaic.shape[0], SIZE), dtype=np.float32)
    for row in range(mosaic.shape[0]):
        horiz[row, :] = np.interp(xp, xbase, mosaic[row, :])

    # Vertical bilinear resample.
    y0i = np.floor(yp).astype(np.int32)
    y1i = np.minimum(y0i + 1, horiz.shape[0]-1)
    yf = (yp - y0i).astype(np.float32)[:, None]
    elevation = horiz[y0i, :] * (1.0-yf) + horiz[y1i, :] * yf
    return elevation

def stylize(elev):
    h, w = elev.shape
    lon_t = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :]
    lat_t = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]

    # Red-Alert-like military macro palette, while elevation stays geographic truth.
    eastness = np.clip((lon_t - 0.35) / 0.65, 0.0, 1.0)
    west_green = np.clip((0.58 - lon_t) / 0.45, 0.0, 1.0)
    north_green = np.clip((0.70 - lat_t) / 0.70, 0.0, 1.0)
    green_weight = west_green * (0.45 + 0.55 * north_green)

    dry = PALETTE["dry"]
    grass = PALETTE["grass"]
    soil = PALETTE["soil"]
    rock = PALETTE["rock"]

    base = np.zeros((h, w, 3), dtype=np.float32)
    desert_mix = eastness[..., None]
    base[:] = dry
    base = base * (1.0 - desert_mix * 0.28) + np.array([0xC2,0xA6,0x76],dtype=np.float32) * (desert_mix * 0.28)
    gw = green_weight[..., None] * np.clip((700.0 - elev[...,None]) / 700.0, 0.0, 1.0)
    base = base * (1.0 - gw * 0.55) + grass * (gw * 0.55)

    mid = np.clip((elev - 350.0) / 850.0, 0.0, 1.0)[..., None]
    base = base * (1.0 - mid * 0.38) + soil * (mid * 0.38)
    high = np.clip((elev - 950.0) / 1200.0, 0.0, 1.0)[..., None]
    base = base * (1.0 - high * 0.72) + rock * (high * 0.72)

    # Global NW hillshade baked into the single macro map.
    gy, gx = np.gradient(elev)
    nx = -gx * 0.012
    ny = np.ones_like(elev)
    nz = -gy * 0.012
    norm = np.sqrt(nx*nx + ny*ny + nz*nz)
    nx, ny, nz = nx/norm, ny/norm, nz/norm
    light = np.array([0.50, 0.80, -0.50], dtype=np.float32)
    light /= np.linalg.norm(light)
    shade = np.clip(nx*light[0] + ny*light[1] + nz*light[2], 0.0, 1.0)
    shade = 0.66 + 0.48 * shade
    base *= shade[..., None]

    return np.clip(base, 0, 255).astype(np.uint8)

def overlay_osm(rgb):
    if osmium is None or not os.path.isfile(PBF):
        return rgb

    canvas = Image.fromarray(rgb, "RGB")
    overlays = {
        "forest": Image.new("L", (SIZE, SIZE), 0),
        "orchard": Image.new("L", (SIZE, SIZE), 0),
        "farmland": Image.new("L", (SIZE, SIZE), 0),
    }
    draws = {k: ImageDraw.Draw(v) for k, v in overlays.items()}

    def classify(tags):
        landuse = tags.get("landuse", "")
        natural = tags.get("natural", "")
        if natural == "wood" or landuse == "forest":
            return "forest"
        if landuse == "orchard":
            return "orchard"
        if landuse in ("farmland", "farm"):
            return "farmland"
        return None

    def px(lon, lat):
        x = (lon - WEST) / (EAST - WEST) * (SIZE - 1)
        y = (NORTH - lat) / (NORTH - SOUTH) * (SIZE - 1)
        return (x, y)

    class Handler(osmium.SimpleHandler):
        def way(self, w):
            tags = dict(w.tags)
            kind = classify(tags)
            if kind is None:
                return
            pts = []
            try:
                for nr in w.nodes:
                    if not nr.location.valid():
                        continue
                    lon, lat = float(nr.location.lon), float(nr.location.lat)
                    if WEST-0.05 <= lon <= EAST+0.05 and SOUTH-0.05 <= lat <= NORTH+0.05:
                        pts.append(px(lon, lat))
            except Exception:
                return
            if len(pts) >= 4:
                draws[kind].polygon(pts, fill=255)

    Handler().apply_file(PBF, locations=True, idx="flex_mem")

    colors = {
        "forest": PALETTE["forest"],
        "orchard": PALETTE["orchard"],
        "farmland": PALETTE["farmland"],
    }
    strengths = {"forest":0.58, "orchard":0.52, "farmland":0.30}
    arr = np.asarray(canvas, dtype=np.float32)
    for kind, mask in overlays.items():
        m = np.asarray(mask.filter(ImageFilter.GaussianBlur(radius=1.4)), dtype=np.float32) / 255.0
        a = (m * strengths[kind])[..., None]
        col = np.array(colors[kind], dtype=np.float32)
        arr = arr * (1.0-a) + col * a
    return np.clip(arr, 0, 255).astype(np.uint8)

def build_variation():
    random.seed(1989)
    small = np.zeros((64,64), dtype=np.uint8)
    for y in range(64):
        for x in range(64):
            small[y,x] = random.randint(210,255)
    img = Image.fromarray(small, "L").resize((512,512), Image.Resampling.BICUBIC)
    img = img.filter(ImageFilter.GaussianBlur(radius=7.0))
    return Image.merge("RGB", (img,img,img))

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    elev = build_elevation()
    rgb = stylize(elev)
    rgb = overlay_osm(rgb)

    macro = Image.fromarray(rgb, "RGB")
    macro.save(os.path.join(OUT_DIR, "syria_macro.png"), optimize=True)

    normalized = np.clip(elev / MAX_HEIGHT_M, 0.0, 1.0)
    height16 = np.round(normalized * 65535.0).astype(np.uint16)
    Image.fromarray(height16, mode="I;16").save(os.path.join(OUT_DIR, "syria_macro_height.png"), optimize=True)

    build_variation().save(os.path.join(OUT_DIR, "syria_macro_variation.png"), optimize=True)

    print("DAM strategic macro generated:", macro.size)
    print("Elevation range m:", float(elev.min()), float(elev.max()))

if __name__ == "__main__":
    main()
