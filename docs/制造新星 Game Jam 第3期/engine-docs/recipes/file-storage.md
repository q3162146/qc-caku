# 本地文件存储（游戏存档）

> ⚠️ **客户端云端存档**请参考 [`clientCloud` API](client-cloud-score.md)，本文档仅涉及本地文件存储。

## 目录隔离

UrhoX 的文件 API 与标准 Urho3D 一致（`File`、`FileSystem` 用法不变），**核心区别是引擎自动提供项目+用户双重隔离**：

- **项目隔离**：项目 A 无法访问项目 B 的数据
- **用户隔离**：同一项目内，用户 A 的存档与用户 B 互不可见

隔离完全透明，脚本只需使用相对路径：

```lua
-- 直接写文件名，引擎自动存到当前项目、当前用户的专属目录下
local file = File("save.json", FILE_WRITE)
```

## 主要用途

### 游戏存档（JSON 推荐）

```lua
-- 保存
local file = File("save.json", FILE_WRITE)
if file:IsOpen() then
    file:WriteString(cjson.encode({ level = 5, score = 1200, inventory = {"sword", "shield"} }))
    file:Close()
end

-- 读取
if fileSystem:FileExists("save.json") then
    local file = File("save.json", FILE_READ)
    if file:IsOpen() then
        local ok, data = pcall(cjson.decode, file:ReadString())
        file:Close()
        if ok then
            print("Level:", data.level)
        end
    end
end
```

### 多存档槽位

```lua
fileSystem:CreateDir("saves")

-- 保存到槽位
local file = File("saves/slot" .. slotId .. ".json", FILE_WRITE)
if file:IsOpen() then
    file:WriteString(cjson.encode(saveData))
    file:Close()
end

-- 列出所有存档
local files = fileSystem:ScanDir("saves/", "*.json", SCAN_FILES, false)
for _, name in ipairs(files) do
    print("Found save:", name)
end
```

## 注意事项

| 事项 | 说明 |
|------|------|
| **WASM 平台** | savedata 存在内存文件系统中，**刷新页面即丢失**。需要持久化请用 `clientCloud` 云存档 |
| **服务端模式** | 服务端（Server 模式）**完全屏蔽**文件读写，所有操作返回 nil/false。存档逻辑只能放客户端 |

## 不可用的 API

以下标准 Lua/Urho3D API 已被沙箱移除：

| API | 替代方案 |
|-----|---------|
| `io` 库 | 使用 `File` |
| `loadfile()` / `dofile()` | 使用 `require` |
| `os.execute()` / `os.remove()` / `os.rename()` | `os.clock`/`os.time`/`os.date` 仍可用 |
| `NamedPipe` / `PackageFile` | — |
| `FileSystem:SystemCommand()` 等系统命令 | — |
| `FileSystem:GetProgramDir()` 等路径 getter | 返回空字符串 |
