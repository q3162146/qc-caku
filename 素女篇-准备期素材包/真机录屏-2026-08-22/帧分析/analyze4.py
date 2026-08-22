from PIL import Image

# 游玩期代表帧 t=36（f_018.png，摇杆 23%）、t=48（f_024.png 跳跃 24%）、t=82（f_041.png 跳跃 18.7%）
for name, fp, th in [('t36', 'f_018.png', 150), ('t48', 'f_024.png', 150), ('t82', 'f_041.png', 150)]:
    im = Image.open(f'/media/pc/机械/nong/制造新星 Game Jam 第3期/素女篇-准备期素材包/真机录屏-2026-08-22/帧分析/{fp}').convert('L')
    w,h = im.size
    # 摇杆区暗斑
    joystick = im.crop((0, 1950, 400, 2400))
    m = joystick.point(lambda p: 255 if p < th else 0)
    bb = m.getbbox()
    if bb:
        cx = (bb[0]+bb[2])/2; cy = 1950+(bb[1]+bb[3])/2
        print(f"{name} 摇杆暗斑bbox(区内)={bb} → 屏幕坐标中心≈({cx:.0f},{cy:.0f}) 尺寸{bb[2]-bb[0]}x{bb[3]-bb[1]}")
    else:
        print(f"{name} 摇杆区无暗斑")
    # 跳跃区：统计亮像素环（>200）与暗(<150)
    jump = im.crop((680, 1950, 1080, 2400))
    hist = jump.histogram()
    n = jump.size[0]*jump.size[1]
    print(f"{name} 跳跃区 暗(<150)={sum(hist[:150])/n*100:.1f}% 亮(>200)={sum(hist[200:])/n*100:.1f}% 均={sum(i*c for i,c in enumerate(hist))/n:.0f}")

# 手势条：t=36 底部中央 y2360-2400 行均值 vs 上方 y2320-2360
im = Image.open('/media/pc/机械/nong/制造新星 Game Jam 第3期/素女篇-准备期素材包/真机录屏-2026-08-22/帧分析/f_018.png').convert('L')
for y0,y1 in [(2360,2370),(2370,2380),(2380,2390),(2390,2400),(2320,2360)]:
    c = im.crop((300, y0, 780, y1))
    hist = c.histogram()
    mean = sum(i*cnt for i,cnt in enumerate(hist))/(c.size[0]*c.size[1])
    print(f"y{y0}-{y1} 中央条均值={mean:.0f}")
