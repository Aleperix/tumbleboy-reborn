#!/usr/bin/env python3
# gen_packs.py — Genera los packs "Números" y "Letras" para TumbleBoy Reborn.
#
# Cada glifo (B..Z, 0,2,4,6,8,10) se renderiza con DejaVuSans-Bold y se
# convierte en un nivel cuyo corredor traza el contorno "neón" del glifo:
#   - contorno = borde de la forma rellena (exterior + ojos interiores),
#   - el contorno se engrosa a ~3 tiles para formar el suelo del corredor,
#   - los bucles interiores (ojos de A/B/D/O/P/Q/R/0/4/6/8/9) se unen al
#     bucle exterior con puentes, de modo que todo el suelo queda conectado,
#   - el resto del mapa es muro, con $ (inicio) y 1 (meta) en los extremos
#     más lejanos del corredor (ruta larga garantizada con BFS),
#   - decoración fácil: 1 bumper y/o 1 rampa sobre tramos rectos, lejos de
#     inicio y meta (transitables, nunca rompen la pasabilidad).
#
# Emite en packs/:
#   numeros.zip, numeros.png, letras.zip, letras.png
# y en /tmp/opencode/packbuild/ los .txt, manifiestos y la hoja de preview.

import json
import os
import zipfile
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKS_DIR = os.path.join(ROOT, "packs")
BUILD_DIR = "/tmp/opencode/packbuild"

DEJAVU_BOLD = "DejaVuSans-Bold.ttf"

GLYPH_H = 40
MARGIN = 6

PASSABLE = {"-", "$", "1", "@", "<", ">"}

NUMEROS = ["0", "2", "4", "6", "8", "10"]
LETRAS = ["B", "D", "F", "H", "J", "L", "N", "P", "R", "T", "V", "X", "Z"]

NOMBRE_NUMERO = {"0": "El cero", "2": "El dos", "4": "El cuatro",
                 "6": "El seis", "8": "El ocho", "10": "El diez"}
NOMBRE_LETRA = {c: "La " + c for c in LETRAS}

NEON_BG = (10, 12, 24)


def _neighbors(y, x, h, w):
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ny, nx = y + dy, x + dx
        if 0 <= ny < h and 0 <= nx < w:
            yield ny, nx


def glyph_mask(text, height=GLYPH_H):
    probe = ImageFont.truetype(DEJAVU_BOLD, 200)
    pb = probe.getbbox(text)
    ph = max(1, pb[3] - pb[1])
    size = int(200 * height / ph)
    font = ImageFont.truetype(DEJAVU_BOLD, size)
    bb = font.getbbox(text)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    W, H = w + 2 * MARGIN, h + 2 * MARGIN
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    d.text((MARGIN - bb[0], MARGIN - bb[1]), text, font=font, fill=255)
    return np.asarray(img) > 128


def label_components(arr, conn8=False):
    h, w = arr.shape
    labels = np.zeros((h, w), dtype=np.int32)
    stack = []
    next_label = 0
    deltas = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1),
              (1, -1), (1, 0), (1, 1)] if conn8 else [(-1, 0), (1, 0), (0, -1), (0, 1)]
    for y in range(h):
        for x in range(w):
            if arr[y, x] and labels[y, x] == 0:
                next_label += 1
                labels[y, x] = next_label
                stack.append((y, x))
                while stack:
                    cy, cx = stack.pop()
                    for dy, dx in deltas:
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and arr[ny, nx] and labels[ny, nx] == 0:
                            labels[ny, nx] = next_label
                            stack.append((ny, nx))
    return labels, next_label


def component_tiles(labels, lab):
    return np.argwhere(labels == lab)


def draw_thick_line(mask, y1, x1, y2, x2, thickness=3):
    """Línea gruesa (Bresenham con estampilla cuadrada) que une dos puntos."""
    h, w = mask.shape
    r = thickness // 2
    dx = abs(x2 - x1)
    dy = -abs(y2 - y1)
    sx = 1 if x1 < x2 else -1
    sy = 1 if y1 < y2 else -1
    err = dx + dy
    x, y = x1, y1
    while True:
        y0, y1b = max(0, y - r), min(h, y + r + 1)
        x0, x1b = max(0, x - r), min(w, x + r + 1)
        mask[y0:y1b, x0:x1b] = True
        if x == x2 and y == y2:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy


def ensure_connected_mask(mask):
    """Une con líneas gruesas las partes sueltas del glifo (p. ej. '1' y '0')."""
    labels, n = label_components(mask, conn8=True)
    while n > 1:
        sizes = [(int((labels == lab).sum()), lab) for lab in range(1, n + 1)]
        sizes.sort(reverse=True)
        main = sizes[0][1]
        other = sizes[1][1]
        main_tiles = component_tiles(labels, main)
        other_tiles = component_tiles(labels, other)
        best = None
        for y1, x1 in main_tiles:
            for y2, x2 in other_tiles:
                d = abs(int(y1) - int(y2)) + abs(int(x1) - int(x2))
                if best is None or d < best[0]:
                    best = (d, int(y1), int(x1), int(y2), int(x2))
        _, y1, x1, y2, x2 = best
        draw_thick_line(mask, y1, x1, y2, x2)
        labels, n = label_components(mask, conn8=True)
    return mask


def find_bridge(c_tiles, floor, mask, main_floor, h, w):
    """Corta un puente de suelo desde un bucle interior hasta el bucle principal
    atravesando solo el cuerpo del glifo (donde mask=True y aún no hay suelo)."""
    dist = np.full((h, w), -1, dtype=np.int64)
    prev = {}
    q = deque()
    for y, x in c_tiles:
        if dist[y, x] == -1:
            dist[y, x] = 0
            q.append((y, x))
    target = None
    while q:
        y, x = q.popleft()
        for ny, nx in _neighbors(y, x, h, w):
            if dist[ny, nx] != -1:
                continue
            if main_floor[ny, nx]:
                dist[ny, nx] = dist[y, x] + 1
                prev[(ny, nx)] = (y, x)
                target = (ny, nx)
                q.clear()
                break
            if mask[ny, nx] and not floor[ny, nx]:
                dist[ny, nx] = dist[y, x] + 1
                prev[(ny, nx)] = (y, x)
                q.append((ny, nx))
        if target is not None:
            break
    if target is None:
        return None
    path = []
    cur = target
    while cur is not None:
        path.append(cur)
        cur = prev.get(cur)
    return path


def bfs_dist(start_tiles, passable, h, w):
    dist = np.full((h, w), -1, dtype=np.int64)
    q = deque()
    for y, x in start_tiles:
        dist[y, x] = 0
        q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in _neighbors(y, x, h, w):
            if dist[ny, nx] == -1 and passable[ny, nx]:
                dist[ny, nx] = dist[y, x] + 1
                q.append((ny, nx))
    return dist


def farthest_pair(passable, h, w):
    ys, xs = np.where(passable)
    if len(ys) == 0:
        return None
    d0 = bfs_dist([(int(ys[0]), int(xs[0]))], passable, h, w)
    p1 = np.unravel_index(int(np.argmax(d0)), d0.shape)
    d1 = bfs_dist([(int(p1[0]), int(p1[1]))], passable, h, w)
    p2 = np.unravel_index(int(np.argmax(d1)), d1.shape)
    return (int(p1[0]), int(p1[1])), (int(p2[0]), int(p2[1]))


def build_level(text):
    mask = glyph_mask(text)
    mask = ensure_connected_mask(mask)
    h, w = mask.shape

    im = Image.fromarray((mask * 255).astype(np.uint8))
    eroded = np.asarray(im.filter(ImageFilter.MinFilter(3))) > 128
    outline = mask & ~eroded
    dil = Image.fromarray((outline * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
    floor = np.asarray(dil) > 128

    labels, n = label_components(floor)
    if n == 0:
        return None
    sizes = [(int((labels == lab).sum()), lab) for lab in range(1, n + 1)]
    sizes.sort(reverse=True)
    main = sizes[0][1]
    main_floor = labels == main
    for lab in range(1, n + 1):
        if lab == main:
            continue
        path = find_bridge(component_tiles(labels, lab), floor, mask, main_floor, h, w)
        if path is not None:
            for y, x in path:
                floor[y, x] = True

    passable = floor.copy()
    pair = farthest_pair(passable, h, w)
    if pair is None:
        return None
    (sy, sx), (gy, gx) = pair

    grid = np.where(floor, "-", "#")

    dist_from_start = bfs_dist([(sy, sx)], passable, h, w)
    max_d = max(1, int(dist_from_start.max()))

    candidates = []
    for y in range(h):
        for x in range(w):
            if not floor[y, x]:
                continue
            if (y, x) == (sy, sx) or (y, x) == (gy, gx):
                continue
            if abs(y - sy) + abs(x - sx) < 8 or abs(y - gy) + abs(x - gx) < 8:
                continue
            if x > 0 and x < w - 1 and floor[y, x - 1] and floor[y, x + 1]:
                candidates.append((int(dist_from_start[y, x]), int(y), int(x)))

    if candidates:
        candidates.sort()
        at_idx = min(range(len(candidates)), key=lambda i: abs(candidates[i][0] - max_d * 0.4))
        ramp_idx = min(range(len(candidates)), key=lambda i: abs(candidates[i][0] - max_d * 0.7))
        if ramp_idx == at_idx:
            ramp_idx = min(range(len(candidates)),
                           key=lambda i: abs(candidates[i][0] - max_d * 0.75))
        _, by, bx = candidates[at_idx]
        grid[by, bx] = "@"
        if ramp_idx != at_idx:
            _, ry, rx = candidates[ramp_idx]
            grid[ry, rx] = "<" if (ry + rx) % 2 else ">"

    grid[sy, sx] = "$"
    grid[gy, gx] = "1"

    passable_check = np.isin(grid, list(PASSABLE))
    d = bfs_dist([(sy, sx)], passable_check, h, w)
    if d[gy, gx] < 0:
        return None

    return grid


def level_text(level_name, author, grid):
    h, w = grid.shape
    rows = []
    for y in range(h):
        rows.append("".join(str(c) for c in grid[y]) + " ")
    body = "\n".join(rows)
    return ".name {%s}\n.author {%s}\n!!!\n%s\n!!!\n" % (level_name, author, body)


def make_pack(pack_id, pack_name, description, symbols, name_map, thumb_text, thumb_color):
    out = os.path.join(BUILD_DIR, pack_id)
    os.makedirs(out, exist_ok=True)
    levels = []
    for sym in symbols:
        fname = ("%02d.txt" % (symbols.index(sym) + 1)) if pack_id == "numeros" else (sym + ".txt")
        grid = build_level(sym)
        if grid is None:
            raise RuntimeError("nivel no construible: %s %s" % (pack_id, sym))
        txt = level_text(name_map[sym], "Aleperix", grid)
        with open(os.path.join(out, fname), "w") as f:
            f.write(txt)
        levels.append("levels/" + fname)
        np.save(os.path.join(BUILD_DIR, pack_id + "_" + sym + ".npy"), grid)

    manifest = {
        "name": pack_name,
        "author": "Aleperix",
        "description": description,
        "levels": levels,
    }
    manifest_path = os.path.join(out, "manifest.json")
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    thumb_bytes = make_thumbnail(thumb_text, thumb_color)
    with open(os.path.join(PACKS_DIR, pack_id + ".png"), "wb") as f:
        f.write(thumb_bytes)

    zip_path = os.path.join(PACKS_DIR, pack_id + ".zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_STORED) as z:
        z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
        z.writestr("thumbnail.png", thumb_bytes)
        for rel in levels:
            with open(os.path.join(out, os.path.basename(rel)), "r") as f:
                z.writestr(rel, f.read())
    print("  %s: %d niveles, zip %s -> %s" % (pack_name, len(levels), zip_path,
                                              os.path.getsize(zip_path)))
    return levels, manifest


def make_thumbnail(text, color):
    img = Image.new("RGB", (128, 128), NEON_BG)
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(DEJAVU_BOLD, 84 if len(text) == 1 else 40)
    bb = font.getbbox(text)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((128 - tw) / 2 - bb[0], (128 - th) / 2 - bb[1]), text, font=font, fill=color)
    buf = os.path.join(BUILD_DIR, "thumb_" + ("a" if len(text) > 1 else "n") + ".png")
    img.save(buf)
    return open(buf, "rb").read()


def render_map_preview(grid, scale=4):
    h, w = grid.shape
    pal = {"#": (14, 18, 38), "-": (0, 200, 240), "$": (80, 255, 120),
           "1": (255, 90, 90), "@": (255, 220, 60), "<": (255, 150, 60),
           ">": (255, 150, 60)}
    img = Image.new("RGB", (w * scale, h * scale), (6, 6, 12))
    px = img.load()
    for y in range(h):
        for x in range(w):
            c = pal.get(str(grid[y, x]), (6, 6, 12))
            for dy in range(scale):
                for dx in range(scale):
                    px[x * scale + dx, y * scale + dy] = c
    return img


def main():
    os.makedirs(BUILD_DIR, exist_ok=True)
    os.makedirs(PACKS_DIR, exist_ok=True)

    packs = [
        ("numeros", "Números", "Los números pares del 0 al 10 en trazos de neón.",
         NUMEROS, NOMBRE_NUMERO, "#", (0, 229, 255)),
        ("letras", "Letras", "Las letras de la B a la Z en trazos de neón.",
         LETRAS, NOMBRE_LETRA, "A-Z", (255, 60, 210)),
    ]

    index = []
    for pack_id, name, desc, symbols, name_map, thumb_text, thumb_color in packs:
        levels, manifest = make_pack(pack_id, name, desc, symbols, name_map, thumb_text, thumb_color)
        index.append({
            "id": pack_id,
            "name": name,
            "author": "Aleperix",
            "description": desc,
            "thumbnail": "packs/" + pack_id + ".png",
        })

    with open(os.path.join(PACKS_DIR, "index.json"), "w") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    tiles = []
    labels = []
    for pack_id, _, _, symbols, _, _, _ in packs:
        for sym in symbols:
            grid = np.load(os.path.join(BUILD_DIR, pack_id + "_" + sym + ".npy"))
            tiles.append(render_map_preview(grid))
            labels.append(pack_id + "/" + sym)

    cell = max(t.size[0] for t in tiles)
    rows = 6
    cols = (len(tiles) + rows - 1) // rows
    sheet = Image.new("RGB", (cols * (cell + 8) + 8, rows * (cell + 20) + 8), (20, 22, 40))
    sd = ImageDraw.Draw(sheet)
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        ox = 8 + c * (cell + 8)
        oy = 8 + r * (cell + 20)
        sheet.paste(t, (ox, oy))
        sd.text((ox + 2, oy + t.size[1] + 2), labels[i], fill=(200, 210, 240))
    preview = os.path.join(BUILD_DIR, "preview.png")
    sheet.save(preview)
    print("preview ->", preview)
    print("index.json ->", os.path.join(PACKS_DIR, "index.json"))


if __name__ == "__main__":
    main()
