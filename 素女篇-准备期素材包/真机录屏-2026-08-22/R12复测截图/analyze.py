from PIL import Image
import glob

target=(242,224,199); tol=16
for fp in sorted(glob.glob('/media/pc/机械/nong/制造新星 Game Jam 第3期/素女篇-准备期素材包/真机录屏-2026-08-22/R12复测截图/r12_*.jpg')):
    im=Image.open(fp).convert('RGB'); w,h=im.size
    px=im.load()
    mask=[[False]*w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r,g,b=px[x,y]
            if abs(r-target[0])<=tol and abs(g-target[1])<=tol and abs(b-target[2])<=tol:
                mask[y][x]=True
    # BFS 最大连通块（只在下半部搜，玩家在 y>55%）
    from collections import deque
    best_comp=None; best_n=0
    seen=[[False]*w for _ in range(h)]
    for y in range(int(h*0.5), h):
        for x in range(w):
            if mask[y][x] and not seen[y][x]:
                q=deque([(x,y)]); seen[y][x]=True; pts=[]
                while q:
                    cx,cy=q.popleft(); pts.append((cx,cy))
                    for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                        nx,ny=cx+dx,cy+dy
                        if 0<=nx<w and 0<=ny<h and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx]=True; q.append((nx,ny))
                if len(pts)>best_n:
                    best_n=len(pts); best_comp=pts
    name=fp.split('/')[-1]
    if best_comp:
        xs=[p[0] for p in best_comp]; ys=[p[1] for p in best_comp]
        bw=max(xs)-min(xs)+1; bh=max(ys)-min(ys)+1
        cx=(max(xs)+min(xs))/2; cy=(max(ys)+min(ys))/2
        print(f"{name}: 球体bbox {bw}x{bh}px @{w}x{h} | 高度占屏={bh/h*100:.1f}% | 中心=({cx/w*100:.0f}%,{cy/h*100:.0f}%) | 像素数={best_n}")
    else:
        print(f"{name}: 未检测到球体")
