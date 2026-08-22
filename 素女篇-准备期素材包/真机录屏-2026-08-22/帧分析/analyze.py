from PIL import Image
import glob

frames = sorted(glob.glob('/media/pc/机械/nong/制造新星 Game Jam 第3期/素女篇-准备期素材包/真机录屏-2026-08-22/帧分析/f_*.png'))
print('frames:', len(frames))
W,H = Image.open(frames[0]).size
print('size:', W, 'x', H, '  punch-zone(x<60,y<43)@432尺度')
punch = (0,0,60,43)
print(f"{'t(s)':>5} {'mean':>5} {'cdark%':>6} {'panelBB':>16} {'punchDark':>9} {'BLmean':>6} {'BRmean':>6} {'botRow':>6}")
for fp in frames:
    t = int(fp.split('_')[-1].split('.')[0])*2
    im = Image.open(fp).convert('L')
    w,h = im.size
    dark = im.point(lambda p: 255 if p<70 else 0)
    cw0,cw1,ch0,ch1 = int(w*0.2), int(w*0.8), int(h*0.25), int(h*0.7)
    c = dark.crop((cw0,ch0,cw1,ch1))
    cd = sum(c.histogram()[128:])
    cratio = cd/(c.size[0]*c.size[1])
    bb = dark.getbbox()
    pd = sum(dark.crop(punch).histogram()[128:])
    bl = sum(im.crop((0,int(h*0.82),int(w*0.34),h)).histogram()[0:128])/(int(w*0.34)*(h-int(h*0.82)))
    br = sum(im.crop((int(w*0.66),int(h*0.82),w,h)).histogram()[0:128])/( (w-int(w*0.66))*(h-int(h*0.82)))
    bot = im.crop((int(w*0.25),h-14,int(w*0.75),h-4))
    botmean = sum(bot.histogram()[0:128])/(bot.size[0]*bot.size[1])
    flag = 'D' if cratio>0.08 else '.'
    print(f"{t:>5} {sum(im.histogram()[0:128])/(w*h):>5.0f} {cratio*100:>5.1f}% {str(bb):>16} {pd:>9} {bl:>6.0f} {br:>6.0f} {botmean:>6.0f} {flag}")
