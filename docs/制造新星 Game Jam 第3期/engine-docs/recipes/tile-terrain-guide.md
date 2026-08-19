# 瓦片地形指南

> **程序化生成瓦片地形并在 UrhoX 场景中加载**

> 🔴 **环境要求（重要）**：本指南依赖托管/Linux 工具链 `TileTerrainCLI` 与配套的瓦片资源包，
> 由打包流程部署到沙箱的 `.cli/` 目录。**本地开源环境（尤其 Windows / macOS）通常不具备该工具链，此功能不可用。**
> 下文中的 `/workspace/.cli/...`、`/workspace/assets/...` 等绝对路径是托管沙箱布局；
> 在自有项目根目录下请相应替换为你的项目路径。

---

## 一、如何生成瓦片地形

### Python 脚本固定头部

所有调用 `TileTerrainCLI` 的 Python 脚本**必须**以以下固定头部开始：

```python
#!/usr/bin/env python3
import subprocess

# 确保地形资源已就绪（必须保留，勿删）
subprocess.run(['python3', '/workspace/.cli/download_tile_resources.py'], check=True)

# === 以下写地形生成逻辑 ===
```

### TileTerrainCLI 路径

```
/workspace/.cli/TileTerrainCLI
```

### 地形系统概述

地形以**二维网格**组织，由 W×H 个**格子（Grid）**组成：

- **顶点（Point）**：存储离散高度值和地表类型标记（陆地 / 水域）
- **边（Edge）**：存储连接标记（路径 / 裂缝），影响相邻格子间过渡
- **格子（Grid）**：关联一个 TileSet（瓦片集）和可选子风格（SubStyle）

默认尺寸：每格子 2.56m × 2.56m，每高度层 1.28m。

### 可用瓦片集（TileSet）

| TileSet | 说明 |
|---------|------|
| `me_tiles_field` | 田野/草地 |
| `me_tiles_snow` | 雪地 |
| `me_tiles_ds` | 沙漠 |
| `me_tiles_dg` | 地宫/洞穴 |
| `me_tiles_chinoiserie` | 中式风格 |
| `me_tiles_temple` | 寺庙 |
| `me_tiles_ts` | 科技风 |

### 瓦片资源（pak）

地形生成需要 pak 资源文件，由 `download_tile_resources.py` 自动下载到：

```
/workspace/.cli/terrain-res/<uuid>-<hash>.pak
```

在 `generate --type hlod` 时通过 `--pak` 参数传入，例如：

```bash
--pak /workspace/.cli/terrain-res/<uuid>-<hash>.pak
```

---

### 命令参考

#### create — 创建空白地形

```bash
/workspace/.cli/TileTerrainCLI create --width <W> --height <H> --tileset <名称> --output <路径>
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--width` | 10 | 地形宽度（格子数） |
| `--height` | 10 | 地形高度（格子数） |
| `--tileset` | "me_tiles_field" | 初始 TileSet 名称 |
| `--output` | "terrain.json" | 输出文件路径 |

```bash
/workspace/.cli/TileTerrainCLI create --width 64 --height 32 --tileset me_tiles_field --output /tmp/terrain.json
```

---

#### modify — 修改地形数据

```bash
/workspace/.cli/TileTerrainCLI modify --input <路径> [--output <路径>] [--raw] <操作...>
```

**顶点操作**：

| 操作 | 格式 | 说明 |
|------|------|------|
| `--set-height` | `x,y,h` | 设置单个顶点高度 |
| `--fill-height` | `x,y,w,h,height` | 批量填充矩形区域高度 |
| `--set-mark` | `x,y,land/water` | 设置顶点地表类型（水域标记用 `water`）。**水域标记应出现在盆地（比周围陆地低的区域）**，水面 decoration 会略高于瓦片表面，只有在低洼处才能与岸边自然衔接 |

**边操作**：

| 操作 | 格式 | 说明 |
|------|------|------|
| `--set-edge` | `gx,gy,方向,标记` | 方向：top/bottom/left/right；标记：path/crack/none |

**格子操作**：

| 操作 | 格式 | 说明 |
|------|------|------|
| `--set-tileset` | `gx,gy,名称` | 设置单个格子的 TileSet |
| `--fill-tileset` | `x,y,w,h,名称` | 批量设置矩形区域 TileSet |
| `--set-substyle` | `gx,gy,名称` | 设置单个格子子风格 |
| `--fill-substyle` | `x,y,w,h,名称` | 批量设置矩形区域子风格 |

可在一次调用中组合多个操作，按顺序执行。

---

#### validate — 验证地形一致性

```bash
/workspace/.cli/TileTerrainCLI validate --input <路径>
```

退出码：0 = 验证通过，1 = 存在错误。

---

#### info — 显示地形信息

```bash
/workspace/.cli/TileTerrainCLI info --input <路径>
```

输出网格尺寸、高度范围、水域顶点数、TileSet 分布等统计信息。

---

#### generate — 生成 HLOD 流式场景

```bash
/workspace/.cli/TileTerrainCLI generate --type hlod \
  --input <terrain.json> \
  --pak /workspace/.cli/terrain-res/<uuid>-<hash>.pak \
  --tileset-dir TileSets \
  --output <输出目录> \
  [--weightmap <权重图.bin>]
```

**参数说明**：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--input` | **必填** | 地形文件 |
| `--pak` | **必填** | 瓦片资源包，路径为 `/workspace/.cli/terrain-res/<uuid>-<hash>.pak` |
| `--tileset-dir` | **必填** | 填 `TileSets`（相对于 pak 内路径） |
| `--output` | **必填** | 输出目录，必须是 `/workspace/assets/` 的子目录 |
| `--weightmap` | 自动生成 | 权重图文件。省略时自动生成全图统一纹理（layer 由 `TileSets/TerrainMix/config.json` 的 `defaultLayer` 决定） |
| `--l0-range` | 100.0 | L0 加载距离（米） |
| `--l1-range` | 250.0 | L1 加载距离（米） |
| `--l2-range` | 500.0 | L2 加载距离（米） |

---

#### init-weightmap — 初始化权重图

```bash
/workspace/.cli/TileTerrainCLI init-weightmap --terrain <terrain.json> --output <路径>
```

---

#### paint-texture — 绘制地表纹理

```bash
/workspace/.cli/TileTerrainCLI paint-texture \
  --weightmap <权重图.bin> \
  --pos <x,z> \
  --layer <纹理ID> \
  [--radius <半径>] \
  [--strength <强度>] \
  [--output <路径>]
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--pos` | **必填** | 世界坐标（x,z） |
| `--layer` | 0 | 纹理层 ID（0-255） |
| `--radius` | 10.0 | 笔刷半径（米） |
| `--strength` | 1.0 | 绘制强度（0.0-1.0） |

---

#### bake-controlmap — 烘焙控制图

```bash
/workspace/.cli/TileTerrainCLI bake-controlmap --weightmap <权重图.bin> --output <路径>
```

> `generate --type hlod` 指定 `--weightmap` 时会自动执行烘焙，通常无需单独调用。

---

### 典型工作流

```python
#!/usr/bin/env python3
import subprocess, glob, os

# 固定头部：确保地形资源已就绪
subprocess.run(['python3', '/workspace/.cli/download_tile_resources.py'], check=True)

CLI = '/workspace/.cli/TileTerrainCLI'
pak = glob.glob('/workspace/.cli/terrain-res/*.pak')[0]  # 取已下载的 pak

# 中间产物放在 /workspace/.tmp/ 下
os.makedirs('/workspace/.tmp', exist_ok=True)

# 1. 创建地形
subprocess.run([CLI, 'create', '--width', '64', '--height', '64',
    '--tileset', 'me_tiles_field', '--output', '/workspace/.tmp/terrain.json'], check=True)

# 2. 编辑地形
subprocess.run([CLI, 'modify', '--input', '/workspace/.tmp/terrain.json',
    '--fill-height', '20,20,10,10,3'], check=True)

# 3. 生成 HLOD 场景
#    省略 --weightmap 时自动生成统一纹理（layer 由 TileSets/TerrainMix/config.json 配置）
#    需要多纹理混合时才手动 init-weightmap + paint-texture + --weightmap
subprocess.run([CLI, 'generate', '--type', 'hlod',
    '--input', '/workspace/.tmp/terrain.json',
    '--pak', pak,
    '--tileset-dir', 'TileSets',
    '--output', '/workspace/assets/terrain/my-map'], check=True)
```

> **多纹理混合**（可选）：需要不同区域使用不同地表纹理时，在 `generate` 前执行 `init-weightmap` + `paint-texture`，然后传 `--weightmap`。

---

## 二、如何加载瓦片地形

### 输出路径要求

调用 `TileTerrainCLI generate` 时，`--output` 必须是 `/workspace/assets/` 下的**子目录**：

```
/workspace/assets/terrain/my-map/    ✅
/workspace/assets/                   ❌ 不能直接用根目录
```

### 生成产物

```
/workspace/assets/terrain/my-map/
├── scene.xml         ← UrhoX 标准场景文件
├── scene.xml.meta    ← 包含 scene.xml 的 UUID
└── ...               （其他地形资源文件）
```

### 在 Lua 中加载场景

**方式 1：虚拟路径**（相对于 `/workspace/assets/`）

```lua
scene_:LoadXML("terrain/my-map/scene.xml")
```

**方式 2：UUID**（从 `scene.xml.meta` 文件中读取）

```lua
scene_:LoadXML("uuid://xxxxxxxxxxxxxxxxxxxxxxxx")
```
