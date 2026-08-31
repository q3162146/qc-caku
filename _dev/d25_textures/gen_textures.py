#!/usr/bin/env python3
# D2.5 场景补全：生成无缝地面/撒点/远山雾带贴图（numpy 周期噪声，PIL 落盘）
# 产物：assets/textures/{ground,scatter,fogband}_{chaoyang,taolin,yinshan}.png
import numpy as np
from PIL import Image
import os, json, secrets, string

OUT = "/workspace/assets/textures"
os.makedirs(OUT, exist_ok=True)

ALPHA64 = string.ascii_letters + string.digits + "-_"
def new_uuid():
    return "".join(secrets.choice(ALPHA64) for _ in range(22))

def write_meta(path):
    if not os.path.exists(path + ".meta"):
        with open(path + ".meta", "w") as f:
            json.dump({"uuid": new_uuid()}, f)

# ---------- 周期值噪声 ----------
def periodic_value_noise(W, cells, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((cells, cells))
    xs = np.arange(W) * cells / W
    x0 = np.floor(xs).astype(int) % cells
    x1 = (x0 + 1) % cells
    fx = xs - np.floor(xs)
    sx = fx * fx * (3 - 2 * fx)
    X, Y = np.meshgrid(xs, xs)
    x0g = np.floor(X).astype(int) % cells
    x1g = (x0g + 1) % cells
    y0g = np.floor(Y).astype(int) % cells
    y1g = (y0g + 1) % cells
    fxg = X - np.floor(X); fyg = Y - np.floor(Y)
    sxg = fxg * fxg * (3 - 2 * fxg)
    syg = fyg * fyg * (3 - 2 * fyg)
    v00 = g[y0g, x0g]; v10 = g[y0g, x1g]
    v01 = g[y1g, x0g]; v11 = g[y1g, x1g]
    a = v00 * (1 - sxg) + v10 * sxg
    b = v01 * (1 - sxg) + v11 * sxg
    return a * (1 - syg) + b * syg

def fbm(W, seed, octaves=((4, 0.5), (8, 0.25), (16, 0.15), (32, 0.10))):
    acc = np.zeros((W, W))
    tot = 0.0
    for cells, amp in octaves:
        acc += amp * periodic_value_noise(W, cells, seed + cells)
        tot += amp
    return acc / tot

def fbm1(W, seed, octaves=((4, 0.55), (8, 0.28), (16, 0.17))):
    acc = np.zeros(W)
    tot = 0.0
    rng = np.random.default_rng(seed)
    for cells, amp in octaves:
        g = rng.random(cells)
        xs = np.arange(W) * cells / W
        x0 = np.floor(xs).astype(int) % cells
        x1 = (x0 + 1) % cells
        fx = xs - np.floor(xs)
        sx = fx * fx * (3 - 2 * fx)
        acc += amp * (g[x0] * (1 - sx) + g[x1] * sx)
        tot += amp
    return acc / tot

def lerp3(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return np.array(a)[None, None, :] * (1 - t) + np.array(b)[None, None, :] * t

def add_blob(img_rgb, alpha, cx, cy, r, col, strength, W, rng):
    # 环绕平铺的椭圆色斑
    for ox in (-W, 0, W):
        for oy in (-W, 0, W):
            x = int(cx + ox); y = int(cy + oy)
            if x + r < 0 or x - r >= W or y + r < 0 or y - r >= W:
                continue
            ys = np.arange(max(0, y - r), min(W, y + r))
            xs = np.arange(max(0, x - r), min(W, x + r))
            if len(xs) == 0 or len(ys) == 0:
                continue
            X, Y = np.meshgrid(xs, ys)
            d = np.sqrt((X - x) ** 2 + (Y - y) ** 2) / max(1.0, r)
            m = np.clip(1 - d, 0, 1) ** 1.5 * strength
            sel = m > 0.01
            if not sel.any():
                continue
            yy = (ys[:, None] * np.ones(len(xs), int)[None, :]).astype(int)
            xx = (xs[None, :] * np.ones(len(ys), int)[:, None]).astype(int)
            for c in range(3):
                img_rgb[yy[sel], xx[sel], c] = (
                    img_rgb[yy[sel], xx[sel], c] * (1 - m[sel]) + col[c] * m[sel])

# ---------- 地面贴图 ----------
GROUND = {
    "chaoyang": dict(seed=11, colA=(0.45, 0.35, 0.21), colB=(0.68, 0.57, 0.38),
                     specks=[((0.93, 0.62, 0.70), 110, (2, 5)), ((0.30, 0.24, 0.16), 90, (1, 3)),
                             ((0.80, 0.72, 0.52), 70, (1, 3))]),
    "taolin":   dict(seed=22, colA=(0.18, 0.28, 0.16), colB=(0.38, 0.47, 0.30),
                     specks=[((0.90, 0.58, 0.66), 100, (2, 4)), ((0.12, 0.20, 0.10), 90, (2, 5)),
                             ((0.45, 0.36, 0.22), 60, (1, 3))]),
    "yinshan":  dict(seed=33, colA=(0.10, 0.11, 0.16), colB=(0.22, 0.25, 0.32),
                     specks=[((0.36, 0.40, 0.48), 110, (1, 4)), ((0.06, 0.07, 0.10), 90, (1, 3)),
                             ((0.52, 0.57, 0.65), 50, (1, 2))]),
}
for key, cfg in GROUND.items():
    W = 512
    n = fbm(W, cfg["seed"])
    n2 = fbm(W, cfg["seed"] + 7, octaves=((16, 0.4), (32, 0.35), (64, 0.25)))
    rgb = lerp3(cfg["colA"], cfg["colB"], n * 0.8 + n2 * 0.4)
    rng = np.random.default_rng(cfg["seed"] + 99)
    for col, cnt, (r0, r1) in cfg["specks"]:
        for _ in range(cnt):
            add_blob(rgb, None, rng.uniform(0, W), rng.uniform(0, W),
                     rng.uniform(r0, r1), col, rng.uniform(0.35, 0.8), W, rng)
    rgb = np.clip(rgb, 0, 1)
    img = Image.fromarray((rgb * 255).astype(np.uint8), "RGB")
    p = os.path.join(OUT, f"ground_{key}.png")
    img.save(p)
    write_meta(p)
    print("wrote", p)

# ---------- 撒点贴花（透明） ----------
SCATTER = {
    "chaoyang": dict(seed=41, petals=((0.95, 0.70, 0.76), (0.98, 0.85, 0.88), (0.90, 0.55, 0.62)),
                     grass=(0.55, 0.52, 0.30), n_petals=26, n_grass=30),
    "taolin":   dict(seed=52, petals=((0.93, 0.62, 0.70), (0.97, 0.82, 0.86), (0.85, 0.50, 0.58)),
                     grass=(0.35, 0.48, 0.28), n_petals=20, n_grass=42),
    "yinshan":  dict(seed=63, petals=((0.40, 0.43, 0.50), (0.28, 0.30, 0.36), (0.52, 0.55, 0.62)),
                     grass=(0.25, 0.26, 0.30), n_petals=22, n_grass=14),
}
for key, cfg in SCATTER.items():
    W = 256
    rng = np.random.default_rng(cfg["seed"])
    rgba = np.zeros((W, W, 4))
    # 草叶：短线条
    for _ in range(cfg["n_grass"]):
        cx, cy = rng.uniform(8, W - 8), rng.uniform(8, W - 8)
        ang = rng.uniform(0, 2 * np.pi)
        L = rng.uniform(4, 9)
        col = np.array(cfg["grass"]) * rng.uniform(0.8, 1.2)
        for t in np.linspace(0, 1, int(L)):
            x = int((cx + np.cos(ang) * t * L * 0.4 + np.sin(t * 6) * 1.2)) % W
            y = int((cy + np.sin(ang) * t * L * 0.4)) % W
            rgba[y, x, :3] = np.clip(col, 0, 1)
            rgba[y, x, 3] = 0.9
    # 花瓣/碎石：小椭圆带 alpha
    for _ in range(cfg["n_petals"]):
        col = np.array(cfg["petals"][rng.integers(0, len(cfg["petals"]))])
        r = rng.uniform(2.5, 6.0)
        cx, cy = rng.uniform(0, W), rng.uniform(0, W)
        rot = rng.uniform(0, np.pi)
        for ox in (-W, 0, W):
            for oy in (-W, 0, W):
                x = cx + ox; y = cy + oy
                if x + r < 0 or x - r >= W or y + r < 0 or y - r >= W:
                    continue
                ys = np.arange(max(0, int(y - r)), min(W, int(y + r) + 1))
                xs = np.arange(max(0, int(x - r)), min(W, int(x + r) + 1))
                if len(xs) == 0 or len(ys) == 0:
                    continue
                X, Y = np.meshgrid(xs - x, ys - y)
                xr = X * np.cos(rot) + Y * np.sin(rot)
                yr = -X * np.sin(rot) + Y * np.cos(rot)
                d = np.sqrt((xr / r) ** 2 + (yr / (r * 0.7)) ** 2)
                m = np.clip(1 - d, 0, 1)
                sel = m > 0.05
                if not sel.any():
                    continue
                gy = (ys[:, None] * np.ones(len(xs), int)[None, :])[sel]
                gx = (xs[None, :] * np.ones(len(ys), int)[:, None])[sel]
                mm = m[sel]
                for c in range(3):
                    rgba[gy, gx, c] = np.maximum(rgba[gy, gx, c], col[c] * rng.uniform(0.85, 1.1))
                rgba[gy, gx, 3] = np.maximum(rgba[gy, gx, 3], mm)
    rgba[..., :3] = np.clip(rgba[..., :3], 0, 1)
    img = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")
    p = os.path.join(OUT, f"scatter_{key}.png")
    img.save(p)
    write_meta(p)
    print("wrote", p)

# ---------- 远山/树线雾带（底部不透明→顶部透明，水平无缝） ----------
FOG = {
    "chaoyang": dict(seed=71, col=(0.74, 0.65, 0.52), hi=(0.88, 0.82, 0.70)),
    "taolin":   dict(seed=82, col=(0.48, 0.56, 0.48), hi=(0.66, 0.72, 0.64)),
    "yinshan":  dict(seed=93, col=(0.26, 0.30, 0.38), hi=(0.42, 0.47, 0.55)),
}
W, H = 512, 256
for key, cfg in FOG.items():
    # 山脊轮廓：中高频周期噪声（锯齿远山），列高 0.5~0.95
    h = 0.50 + 0.45 * fbm1(W, cfg["seed"], octaves=((5, 0.45), (10, 0.3), (20, 0.18), (40, 0.07)))
    shade = 0.75 + 0.4 * fbm1(W, cfg["seed"] + 5)   # 列明暗
    v = (np.arange(H) / (H - 1))[:, None]           # v: 0 底 → 1 顶（数组行 0 = 底）
    hcol = h[None, :]
    # 近二元 alpha：山脊线以下不透明，以上窄带（6% 高度）速隐，避免半透明"金幕"
    fade = np.clip((hcol - v) / 0.06, 0, 1)
    base = np.array(cfg["col"])[None, None, :] * shade[None, :, None]
    top_mix = np.clip((v - (hcol - 0.3)) * 4, 0, 1)[..., None]
    rgb = base * (1 - top_mix * 0.35) + np.array(cfg["hi"])[None, None, :] * (top_mix * 0.35)
    rgba = np.concatenate([np.clip(rgb, 0, 1), fade[..., None]], axis=2)
    # bandtest 实测：引擎把 PNG 行0 采样到立面上缘 → 数组行0(底/不透明)不翻转时
    # 渲染后恰落在底缘。勿翻转（此前误翻导致透明在下）。
    img = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")
    p = os.path.join(OUT, f"fogband_{key}.png")
    img.save(p)
    write_meta(p)
    print("wrote", p)

print("done")
