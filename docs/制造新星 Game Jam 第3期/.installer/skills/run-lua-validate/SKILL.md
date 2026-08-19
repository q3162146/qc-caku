---
name: run-lua-validate
description: "用 UrhoXRuntime 验证 Lua 脚本：检测运行时报错（validate 模式）或截图验证渲染效果（surfaceless 模式）。Use when (1) 需要检查 Lua 脚本是否运行时报错/crash, (2) 需要截图看渲染效果是否正确, (3) 用户说\"验证一下\"/\"跑一下看看\"/\"截个图\"/\"validate\"/\"有没有报错\", (4) 修改了游戏脚本后想确认没有 regression, (5) 需要自动化测试 Lua 游戏逻辑。SKIP when 用户只需要程序化生成/批处理（用 run-lua-headless），或只需要本地 LSP 检查语法。"
---

# run-lua-validate — 验证 Lua 脚本 + 截图

## 两种模式

| 模式 | 用途 | 关键参数 | 产出 |
|------|------|---------|------|
| **validate**（逻辑验证） | 检查脚本是否运行时报错/crash | `-graphicsheadless -validate` | exit code + stdout 日志 |
| **screenshot**（截图验证） | 看渲染效果是否正确 | `-graphicssurfaceless -screenshot=` | PNG 截图文件 |

两种模式使用**同一个二进制**，运行时通过参数选择。

## 🔴 限制：仅支持单机模式

**本 skill 只能验证单机游戏脚本**。联网多人游戏（`<项目根>/.project/settings.json` 中 `multiplayer.enabled: true`）**不可用**——validate/screenshot 模式下没有服务端，网络连接会失败，导致报错或非预期行为（卡在连接、空场景、逻辑不触发等）。

判断方法：
```bash
cat <项目根>/.project/settings.json | grep -o '"enabled":[^,]*' | head -1
```

联网游戏的测试需要完整的 client + server 环境，不在本 skill 覆盖范围内。

## 安装 / 自动更新（每次调用前跑一次）

```bash
python3 <项目根>/.cli/install-urhox-runtime.py --dest <项目根>/.cli
```

脚本自动检测平台，从 CDN 下载 UrhoXRuntime.zip（含 binary + 运行时 .so + pak）并原子解压。
幂等：首次下载约 35MB；后续未更新约 50ms 跳过（304）。

默认安装目录：`<项目根>/.cli/`。

---

## 模式 1: Validate（逻辑验证）

检查脚本能否正常启动、运行 N 帧无 crash/error。**不产出渲染像素**（Noop 渲染器）。

### 基本用法

```bash
timeout 30 <项目根>/.cli/UrhoXRuntime main.lua \
  -tapcode_dir=<项目根> \
  -tool_mode \
  -graphicsheadless \
  -validate \
  -validate-frames=60 \
  -skip_login
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `main.lua` | 第一个位置参数，相对 `<项目根>/scripts/` 的入口脚本 |
| `-tapcode_dir=<项目根>` | 项目根目录 |
| `-tool_mode` | 资源从 Autoload/*.pak 加载，不依赖散文件目录（必须） |
| `-graphicsheadless` | 使用 Noop 渲染器（无像素输出，极快） |
| `-validate` | 启用 validate 模式（跑完指定帧数自动退出） |
| `-validate-frames=60` | 运行 60 帧后退出（通常 1-3 秒） |
| `-skip_login` | 跳过登录（必须） |

### 判断结果

| 信号 | 含义 |
|------|------|
| exit code = 0 | 脚本正常运行完指定帧数，无 crash |
| exit code ≠ 0 | 有 crash 或严重错误 |
| stdout 含 `ERROR` | 有运行时错误（即使 exit 0 也要关注） |
| exit code = 124 | timeout 超时——脚本卡死或帧数设太大 |

### 输出解析

```bash
output=$(timeout 30 <项目根>/.cli/UrhoXRuntime main.lua \
  -tapcode_dir=<项目根> -tool_mode -graphicsheadless -validate \
  -validate-frames=60 -skip_login 2>&1) || true

echo "$output" | grep -i "ERROR\|EXCEPTION\|Lua runtime error\|stack traceback"
```

常见错误模式：
- `[Script] ERROR: ...` — Lua 运行时错误（空指针、API 调用错误）
- `Lua runtime error:` — Lua 脚本异常
- `stack traceback:` — Lua 调用栈（紧跟在 error 后面）

---

## 模式 2: Screenshot（截图验证，仅 Linux）

用真实 GLES 渲染器（Mesa llvmpipe 软渲染）输出**真实像素**，截图后用视觉能力判断效果。

### 基本用法

```bash
LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe EGL_PLATFORM=surfaceless \
timeout 60 <项目根>/.cli/UrhoXRuntime main.lua \
  -tapcode_dir=<项目根> \
  -tool_mode \
  -graphicssurfaceless \
  -screenshot=<项目根>/screenshots/shot.png \
  -screenshot-frame=120 \
  -x 800 -y 600 \
  -skip_login
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `-graphicssurfaceless` | 使用真实 GLES 渲染器（surfaceless EGL，无窗口） |
| `-screenshot=<项目根>/screenshots/shot.png` | 截图输出路径 |
| `-screenshot-frame=120` | 在第 120 帧截图（截完自动退出） |
| `-x 800 -y 600` | 渲染分辨率（默认 800×600，竖屏用 `-x 1080 -y 1920`） |
| 环境变量 `LIBGL_ALWAYS_SOFTWARE=1` | 强制 Mesa 软渲染（无需 GPU） |
| 环境变量 `GALLIUM_DRIVER=llvmpipe` | 指定 llvmpipe 驱动 |
| 环境变量 `EGL_PLATFORM=surfaceless` | 指定 surfaceless EGL 平台 |

### 判断结果

1. 检查 exit code（非 0 = crash）
2. 检查截图文件是否存在且非空
3. **用 `Read` 工具读取 PNG 文件**，用视觉能力判断渲染是否正确

```bash
ls -la <项目根>/screenshots/shot.png
```

然后用 Read 工具读取 `<项目根>/screenshots/shot.png` 来看图。

---

## 序列帧 / 运动验证（旋转、动画、物理轨迹）

**单帧判不了运动。** 凡是"随时间/角度变化"的问题——旋转朝哪转、是"左右摆"还是"360°公转"、动画播得对不对、物理轨迹——都要**多帧**：跑 N 次、每次渲染一个**受控值**，再拼成 GIF（给用户看）+ contact sheet（给你自己 Read 判断）。

**两条必须记住的点：**

1. **contact sheet（网格拼图）给 AI 自己看，GIF 给用户看。** 你能 `Read` 一张 PNG 判断，但**看不了 GIF 动**（读进来只是静态）。所以要判运动对错，**必须**把 N 帧拼成一张 contact sheet PNG 再 `Read`。
2. **用"确定性扫参"，别靠实时帧计时。** 软渲染速度不定，"第 N 帧是什么状态"不可复现。把要变的量（角度/状态）**冻结**在受控值、每次 run 截一帧，才对得齐、可复现。

```bash
mkdir -p <项目根>/screenshots/frames
for A in $(seq 0 15 345); do   # 例：一整圈 24 帧，脚本里 local ANGLE = 0.0 逐值替换
  sed "s/^local ANGLE = 0.0/local ANGLE = ${A}.0/" <项目根>/scripts/scene.lua > <项目根>/scripts/_seq.lua
  LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe EGL_PLATFORM=surfaceless \
    timeout 60 <项目根>/.cli/UrhoXRuntime _seq.lua -tapcode_dir=<项目根> -tool_mode \
    -graphicssurfaceless -screenshot=$(printf <项目根>/screenshots/frames/f%03d.png "$A") \
    -screenshot-frame=120 -skip_login >/dev/null 2>&1
done
```

```python
# 拼接：GIF（人）+ contact sheet（AI 自己 Read）
from PIL import Image; import glob
fs=sorted(glob.glob('<项目根>/screenshots/frames/f*.png')); ims=[Image.open(f).convert('RGB') for f in fs]
g=[im.resize((420,322)) for im in ims]
g[0].save('<项目根>/screenshots/motion.gif', save_all=True, append_images=g[1:], duration=90, loop=0, optimize=True)
c,r,tw,th=6,(len(ims)+5)//6,210,161
sheet=Image.new('RGB',(c*tw,r*th),(20,20,28))
for i,im in enumerate(ims): sheet.paste(im.resize((tw,th)),((i%c)*tw,(i//c)*th))
sheet.save('<项目根>/screenshots/motion_sheet.png', optimize=True)   # <- Read 这张判运动
```

给追踪点一个亮色 marker，看它在各帧的轨迹：画一整圈=公转；只在一条线上来回=摆。

> ⚠️ 这套只覆盖**单机/单场景**的运动（本 skill 不支持联机）。**联机后的运动**（网络插值、client/server 分裂导致的抖/摆）在单机截图里复现不出来——它只在真实 server+client 跑起来时才出现，不在本 skill 覆盖范围内。

---

## ⚠️ 陷阱

| 陷阱 | 说明 |
|------|------|
| **screenshot-frame 太小** | frame < 100 可能截到 bootstrap loading 画面（深色 + spinner），有效截图 **≥ 120** |
| **用错渲染参数** | `-graphicsheadless` 是 Noop（无像素），截图必须用 `-graphicssurfaceless` |
| **忘了环境变量** | 截图模式必须设 `LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe EGL_PLATFORM=surfaceless` |
| **PNG 无压缩** | 800×600 截图约 1.9MB（裸 RGBA），正常现象 |
| **超时** | llvmpipe 是 CPU 软渲染，120 帧约 5-15 秒。timeout 建议 60s |
| **一次只截一帧** | 要多帧对比（动画/物理），跑多次换 `-screenshot-frame` |
| **validate + screenshot 组合** | 可以同时传 `-validate -validate-frames=200 -screenshot=<项目根>/screenshots/s.png -screenshot-frame=120`，此时 validate-frames 必须 > screenshot-frame |

---

## 标准工作流

### 场景 A：修改了 Lua 脚本，快速检查有没有报错

```bash
python3 <项目根>/.cli/install-urhox-runtime.py --dest <项目根>/.cli

output=$(timeout 30 <项目根>/.cli/UrhoXRuntime main.lua \
  -tapcode_dir=<项目根> -tool_mode -graphicsheadless -validate \
  -validate-frames=60 -skip_login 2>&1)
ec=$?

if [ $ec -ne 0 ]; then
  echo "❌ Crash (exit $ec)"
  echo "$output" | tail -30
else
  errors=$(echo "$output" | grep -i "ERROR\|Lua runtime error" || true)
  if [ -n "$errors" ]; then
    echo "⚠️ Runtime errors:"
    echo "$errors"
  else
    echo "✅ 60 frames OK, no errors"
  fi
fi
```

### 场景 B：截图验证渲染效果

```bash
python3 <项目根>/.cli/install-urhox-runtime.py --dest <项目根>/.cli
mkdir -p <项目根>/screenshots

LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe EGL_PLATFORM=surfaceless \
timeout 60 <项目根>/.cli/UrhoXRuntime main.lua \
  -tapcode_dir=<项目根> -tool_mode -graphicssurfaceless \
  -screenshot=<项目根>/screenshots/shot.png -screenshot-frame=120 \
  -x 800 -y 600 -skip_login 2>&1

if [ -s <项目根>/screenshots/shot.png ]; then
  echo "✅ Screenshot saved: $(ls -lh <项目根>/screenshots/shot.png | awk '{print $5}')"
else
  echo "❌ Screenshot failed"
fi
```

### 场景 C：validate + 同时截图

```bash
python3 <项目根>/.cli/install-urhox-runtime.py --dest <项目根>/.cli
mkdir -p <项目根>/screenshots

LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe EGL_PLATFORM=surfaceless \
timeout 60 <项目根>/.cli/UrhoXRuntime main.lua \
  -tapcode_dir=<项目根> -tool_mode -graphicssurfaceless \
  -validate -validate-frames=200 \
  -screenshot=<项目根>/screenshots/shot.png -screenshot-frame=120 \
  -x 800 -y 600 -skip_login 2>&1
```

这会跑 200 帧，第 120 帧截图，同时输出 validate 报告（JSON）。

---

## 与 run-lua-headless 的区别

| 维度 | run-lua-headless | run-lua-validate |
|------|-----------------|-----------------|
| 用途 | 程序化生成/批处理 | 测试游戏脚本 |
| 入口模式 | `-tool_mode`（脚本做完事调 `engine:Exit()`） | `-validate`（跑 N 帧自动退出） |
| 渲染 | 无（纯 CPU） | 可选：Noop（逻辑）或真实 GLES（截图） |
| 典型产物 | PNG/JSON/XML 文件 | exit code + 日志 + 可选截图 |
| 脚本要求 | 必须有 `engine:Exit()` | 普通游戏脚本即可（有 `Start()` + Update 循环） |

---

## 超时建议

| 场景 | 超时 |
|------|------|
| validate 60 帧（Noop） | 15s |
| validate 200 帧（Noop） | 30s |
| screenshot 120 帧（surfaceless） | 60s |
| screenshot 300 帧（surfaceless） | 90s |
