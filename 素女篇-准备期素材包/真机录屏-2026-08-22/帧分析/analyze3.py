from PIL import Image
import glob

frames = sorted(glob.glob('/media/pc/机械/nong/制造新星 Game Jam 第3期/素女篇-准备期素材包/真机录屏-2026-08-22/帧分析/f_*.png'))
# 底部控件区（1080x2400）：
# 摇杆区 左下 x0-400 y1950-2400；跳跃区 右下 x680-1080 y1950-2400；手势条区 底部中央 x320-760 y2370-2400
ZONES = {
    '摇杆区(左下)': (0, 1950, 400, 2400),
    '跳跃区(右下)': (680, 1950, 1080, 2400),
    '手势条区(底中)': (320, 2370, 760, 2400),
    '左下角圆角区': (0, 2280, 200, 2400),
    '右下角圆角区': (880, 2280, 1080, 2400),
}
print(f"{'t(s)':>5} " + " ".join(f"{k.split('(')[0]:>6}" for k in ZONES) + "  说明")
for fp in frames:
    t = int(fp.split('_')[-1].split('.')[0])*2
    im = Image.open(fp).convert('L')
    vals = []
    for k, box in ZONES.items():
        c = im.crop(box)
        hist = c.histogram()
        # 中等偏暗像素比例（<150）：半透明控件底
        mid = sum(hist[:150]) / (c.size[0]*c.size[1])
        vals.append(f"{mid*100:>5.1f}%")
    tag = '对话期' if 104 <= t <= 160 else ('游玩期' if 20 <= t <= 100 else '')
    print(f"{t:>5} " + " ".join(vals) + f"  {tag}")
