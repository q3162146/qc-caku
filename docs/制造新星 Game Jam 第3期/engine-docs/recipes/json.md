# UrhoX Lua JSON API (AI Agent 参考)

## cjson (推荐，唯一推荐方案)

> `cjson` 是引擎内置的**全局变量**，启动时自动注册，无需 `require`，直接使用即可。
> 
> **对于所有 JSON 需求（HTTP、配置、序列化、数据存储），统一使用 `cjson`。**

```lua
-- 编解码
local str = cjson.encode({name = "Player", items = {"sword", "shield"}})
local tbl = cjson.decode('{"name": "Test", "value": 42}')
print(tbl.name, tbl.value)  -- "Test", 42
print(tbl.items[1])         -- Lua 1-based 索引

-- 错误处理
local ok, data = pcall(cjson.decode, jsonStr)
if not ok then print("解析失败") end
```

## JSONFile / JSONValue (底层 C++ API，不推荐)

> ⚠️ **不推荐使用**。`JSONFile`/`JSONValue` 是 Urho3D 引擎的 C++ JSON API，通过 tolua++ 绑定到 Lua。
> 该绑定层在 Lua 侧存在已知 bug，且 API 繁琐（0-based 索引、手动类型转换）。
>
> **`cjson` 可以完全覆盖 UGC 游戏开发的所有 JSON 需求，不需要使用此 API。**
>
> 仅在以下引擎内部场景才需要用到 `JSONFile` 对象：
> - `AnimationStateMachine:LoadFromJSONFile(jsonFile)` — 加载 FSM 配置
> - `Node:LoadJSON(jsonValue)` — 从 JSON 加载场景节点
> - `Localization:LoadJSON(jsonValue)` — 加载多语言配置
