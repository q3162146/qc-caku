# 引擎与 AI Dev Kit 说明

当需要把生成的 voxel JSON 集成到 TapMaker/UrhoX 项目时，读取本参考。

## 项目结构

UrhoX AI Dev Kit 项目以项目根目录作为工作目录：

```text
project/
  scripts/
  assets/
```

用户 Lua 代码放在 `scripts/` 下。纹理、模型文件、生成的 JSON、配置等运行时资源放在 `assets/` 下。

## 资源路径

本地运行时，`UrhoXRuntime.exe main.lua -tapcode_dir=<project> -skip_login` 会把 `<project>/scripts` 和 `<project>/assets` 都加入 `ResourceCache`。

Lua 内部引用资源时，路径相对于这些资源根目录：

```lua
cache:GetResource("Texture2D", "Textures/player.png") -- assets/Textures/player.png
cache:GetResource("Model", "Models/Box.mdl")          -- assets/Models/Box.mdl
```

不要在引擎资源路径里写 `assets/Textures/player.png`。

## 本地运行命令

最小本地运行命令：

```powershell
UrhoXRuntime.exe main.lua -tapcode_dir="C:\path\to\project" -skip_login
```

脚本文件必须是第一个位置参数，并且相对于 `scripts/` 解析。不要使用不存在的 `-script=` 或 `-project=` 参数。

## AI Dev Kit 中的 Skills

可移植 skill 放在：

```text
ai-dev-kit/skills/<skill-name>/
```

`ai-dev-kit/tools/install-skills.ps1 codex` 或 `install-skills.sh codex` 会把这些 skill 链接到 `.codex/skills/`。同一份源目录也可以链接到 `.claude/skills/`、`.cursor/skills/` 和 `.gemini/skills/`。

## 体素渲染侧

本 skill 只生成 voxel JSON。TapMaker 项目仍然需要 Lua 代码来读取并渲染这个 JSON。推荐的项目侧结构是：

```text
scripts/higgsfield/VoxelSceneLoader.lua
scripts/higgsfield/VoxelSceneRenderer.lua
scripts/main.lua
assets/voxels/model_voxel.json
```

Loader 应通过引擎资源路径从 `assets/` 读取 JSON，默认路径形如 `voxels/model_voxel.json`。
