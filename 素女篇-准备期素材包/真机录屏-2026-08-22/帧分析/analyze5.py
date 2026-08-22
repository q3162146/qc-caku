from PIL import Image
import glob

frames = sorted(glob.glob('/media/pc/机械/nong/制造新星 Game Jam 第3期/素女篇-准备期素材包/真机录屏-2026-08-22/帧分析/f_*.png'))
def rowdark(im, y0, y1, th=70):
    m = im.point(lambda p: 255 if p < th else 0)
    out = []
    for y in range(y0, y1):
        c = m.crop((0, y, 1080, y+1))
        out.append(sum(c.histogram()[128:]))
    return out

for fp in frames:
    t = int(fp.split('_')[-1].split('.')[0])*2
    if not (100 <= t <= 164): continue
    im = Image.open(fp).convert('L')
    top = rowdark(im, 0, 300)
    bot = rowdark(im, 2100, 2400)
    # 顶部连续暗段
    tseg = []; s=None
    for y,n in enumerate(top):
        if n>20 and s is None: s=y
        elif n<=20 and s is not None: tseg.append((s,y-1)); s=None
    if s is not None: tseg.append((s,299))
    # 底部连续暗段
    bseg = []; s=None
    for y,n in enumerate(bot):
        if n>100 and s is None: s=y+2100
        elif n<=100 and s is not None: bseg.append((s,y-1+2100)); s=None
    if s is not None: bseg.append((s,2399))
    # 顶段暗像素总量
    tsum = sum(top)
    print(f"t={t:>3}s 顶暗段(y):{tseg if tseg else '-'} 顶暗px={tsum:>6} 底暗段(y):{bseg if bseg else '-'}")
