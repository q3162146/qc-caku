from PIL import Image
import glob

frames = sorted(glob.glob('/media/pc/机械/nong/制造新星 Game Jam 第3期/素女篇-准备期素材包/真机录屏-2026-08-22/帧分析/f_*.png'))
def darkmask(im, th=70):
    return im.point(lambda p: 255 if p < th else 0)

def zone_dark(mask, box):
    c = mask.crop(box)
    return sum(c.histogram()[128:])

# 1) 挖孔区 (0,0,150,108) 与状态栏区 (0,108,1080,160) 的暗像素
print("=== 挖孔区/状态栏区暗像素（1080x2400，挖孔 x<150 y<108） ===")
print(f"{'t(s)':>5} {'punchDark':>9} {'statusDark':>10}  说明")
for fp in frames:
    t = int(fp.split('_')[-1].split('.')[0])*2
    im = Image.open(fp).convert('L')
    m = darkmask(im)
    pd = zone_dark(m, (0,0,150,108))
    sd = zone_dark(m, (0,108,1080,160))
    tag = ''
    if pd > 500: tag += ' <-- 挖孔区有大量暗像素!'
    if t >= 100 and t <= 160: tag += ' [对话期]'
    print(f"{t:>5} {pd:>9} {sd:>10}{tag}")

# 2) 顶部面板行扫描：对话期帧，y 0-400 每行暗像素数，找面板顶边
print()
print("=== 对话期帧 顶部行扫描（y=每行暗像素数，只显示暗像素>10的行区间） ===")
for fp in frames:
    t = int(fp.split('_')[-1].split('.')[0])*2
    if not (104 <= t <= 160): continue
    im = Image.open(fp).convert('L')
    m = darkmask(im)
    rows = []
    for y in range(0, 420):
        c = m.crop((0, y, 1080, y+1))
        n = sum(c.histogram()[128:])
        rows.append(n)
    # 找连续暗行区间
    segs = []
    start = None
    for y, n in enumerate(rows):
        if n > 10 and start is None: start = y
        elif n <= 10 and start is not None:
            segs.append((start, y-1)); start = None
    if start is not None: segs.append((start, 419))
    segs = [s for s in segs if s[1]-s[0] >= 3]
    print(f"t={t:>3}s 顶部暗行区间: {segs if segs else '无'}")
