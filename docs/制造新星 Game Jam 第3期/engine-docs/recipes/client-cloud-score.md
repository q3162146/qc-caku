# 客户端云变量与排行榜指南（客户端专用）

> **clientCloud API 快速参考**
>
> ⚠️ **本文档的 `clientCloud` API 仅限客户端（Standalone / Client 模式）使用**。服务端（Server 模式）有独立的 `serverCloud` API，见 [server-cloud-score.md](server-cloud-score.md)。

---

## API 概览

### 单个操作

| 方法 | 用途 | 数据存储 |
|------|------|---------|
| `clientCloud:Set(key, value, events)` | 写入任意类型 | → values |
| `clientCloud:SetInt(key, value, events)` | 写入整数 | → iscores |
| `clientCloud:Add(key, delta, events)` | 整数增量 | → iscores |
| `clientCloud:Get(key, events)` | 读取 | ← (values, iscores) |

### 批量操作（链式调用）

| 方法 | 用途 |
|------|------|
| `clientCloud:BatchSet()` | 返回批量写入构建器 |
| `:Set(key, value)` / `:SetInt(key, value)` / `:Add(key, delta)` / `:Delete(key)` | 链式追加操作 |
| `:Save(description, events?)` | 提交批量写入 |
| `clientCloud:BatchGet()` | 返回批量读取构建器 |
| `:Key(key)` | 链式追加要读取的 key |
| `:Fetch(events)` | 执行批量读取 |

### 排行榜

| 方法 | 用途 | 数据存储 |
|------|------|---------|
| `clientCloud:GetRankList(key, start, count, [orderAsc,] events, otherKey...)` | 排行榜列表 | 基于 iscores |
| `clientCloud:GetUserRank(userId, key, events)` | 用户排名 | - |
| `clientCloud:GetRankTotal(key, events)` | 排行榜总人数 | - |

### 用户昵称

| 方法 | 用途 | 说明 |
|------|------|------|
| `GetUserNickname({ userIds, onSuccess, onError })` | 批量查询用户昵称 | 全局函数，客户端/服务端通用 |
| `lobby:GetMyUserId()` | 获取当前用户 ID | 同步 |

> ⚠️ **昵称不存储在云变量中！** 不要用 `clientCloud:Set("player_name", ...)` 存昵称。
> 昵称由 TapTap 账号系统管理，通过 `GetUserNickname()` 查询。

---

## 数据类型说明

| 存储表 | 写入方法 | 读取位置 | 用途 |
|--------|----------|----------|------|
| **values** | `Set()` | 回调第 1 参数 | 任意类型（字符串、表等） |
| **iscores** | `SetInt()` / `Add()` | 回调第 2 参数 | 整数，**可排行榜排序** |

> ⚠️ `sscores` 已废弃，不再使用

---

## 快速开始

### 写入数据

```lua
-- 写入配置/装备等复杂数据（任意类型）→ values
clientCloud:Set("game_config", { difficulty = "hard", music = true })
clientCloud:Set("equipment", { weapon = "sword_01", armor = "plate_02" })

-- 写入整数（可排行榜）→ iscores
clientCloud:SetInt("high_score", 9999)

-- 整数增量
clientCloud:Add("gold", 100)    -- 增加
clientCloud:Add("gold", -50)    -- 减少
```

### 读取数据

```lua
-- ⚠️ Get 只返回你请求的 key 相关数据
-- 如果要同时读取多个 key，请使用 BatchGet
clientCloud:Get("gold", {
    ok = function(values, iscores)
        local gold = iscores.gold or 0
        print("金币:", gold)
    end,
    error = function(code, reason)
        print("错误:", reason)
    end
})
```

### 批量操作

```lua
-- 批量写入
clientCloud:BatchSet()
    :Set("game_config", { difficulty = "normal" })  -- 任意类型 → values
    :SetInt("gold", 100)                             -- 整数 → iscores
    :Add("play_count", 1)                            -- 增量 → iscores
    :Save("游戏奖励", { ok = function() print("OK") end })

-- 批量读取（推荐：比多次 Get 更高效）
clientCloud:BatchGet()
    :Key("gold")
    :Key("game_config")
    :Fetch({
        ok = function(values, iscores)
            print("金币:", iscores.gold)
            local config = values.game_config
            if config then
                print("难度:", config.difficulty)
            end
        end
    })
```

---

## 排行榜

排行榜**只能基于 iscores 中的整数**排序。

### 排行榜 item 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `item.player` | number | 用户 ID |
| `item.iscore` | table | `{ key = intValue, ... }` —— 整数云变量（通过 SetInt/Add 写入） |
| `item.score` | table | `{ key = value, ... }` —— 通过 Set() 写入的云变量。table/数组会自动 JSON 编解码，字符串保持原样 |
| `item.sscore` | table | 已废弃，通常为空 `{}` |

> ⚠️ **排行榜不包含昵称！** 需要昵称请用 `GetUserNickname()`

### 基本用法

```lua
-- 获取排行榜（前 10 名，默认降序）
-- events 参数之后可传入额外 key 名，同时获取附加字段
clientCloud:GetRankList("high_score", 0, 10, {
    ok = function(rankList)
        for i, item in ipairs(rankList) do
            local score = item.iscore.high_score or 0
            local playCount = item.iscore.play_count or 0  -- 附加字段
            local isMe = item.userId == clientCloud.userId
            print(string.format("#%d  用户:%s  分数:%d  场次:%d%s",
                i, tostring(item.userId), score, playCount,
                isMe and " (我)" or ""))
        end
    end
}, "play_count")  -- ← 附加字段: 同时获取 play_count

-- 获取排行榜（升序排列）
clientCloud:GetRankList("high_score", 0, 10, true, {
    ok = function(rankList)
        -- orderAsc=true 时按分数从低到高排列
    end
})

-- 获取用户排名
clientCloud:GetUserRank(clientCloud.userId, "high_score", {
    ok = function(rank, scoreValue)
        if rank then
            print("排名:", rank, "分数:", scoreValue)
        else
            print("未上榜")
        end
    end
})

-- 获取排行榜总人数
clientCloud:GetRankTotal("high_score", {
    ok = function(total)
        print("共", total, "人上榜")
    end
})
```

---

## 获取用户昵称

昵称由 TapTap 账号系统管理，通过全局函数 `GetUserNickname()` 查询（客户端异步，服务端同步）。

```lua
-- 查询昵称（支持批量，回调方式，无需手动订阅事件）
local myUserId = lobby:GetMyUserId()

GetUserNickname({
    userIds = { myUserId },
    onSuccess = function(nicknames)
        for _, info in ipairs(nicknames) do
            print(info.userId, info.nickname)
        end
    end,
    onError = function(errorCode)
        print("查询失败, errorCode=" .. tostring(errorCode))
    end
})
```

### 排行榜 + 昵称（完整示例）

```lua
function ShowLeaderboard(topN, callback)
    clientCloud:GetRankList("high_score", 0, topN or 10, {
        ok = function(rankList)
            local leaderboard = {}
            local userIds = {}
            for i, item in ipairs(rankList) do
                table.insert(leaderboard, {
                    rank = i, userId = item.userId,
                    score = item.iscore.high_score or 0,
                    playCount = item.iscore.play_count or 0,
                    isMe = item.userId == clientCloud.userId
                })
                table.insert(userIds, item.userId)
            end

            if #userIds == 0 then
                if callback then callback(leaderboard) end
                return
            end

            -- 使用统一接口查询昵称，无需手动订阅/取消事件
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local map = {}
                    for _, info in ipairs(nicknames) do
                        map[info.userId] = info.nickname or ""
                    end
                    for _, entry in ipairs(leaderboard) do
                        entry.nickname = map[entry.userId] or "未知"
                    end
                    if callback then callback(leaderboard) end
                end,
                onError = function(errorCode)
                    -- 昵称查询失败，仍返回排行榜数据（昵称为空）
                    if callback then callback(leaderboard) end
                end
            })
        end
    }, "play_count")
end
```

---

## 属性

```lua
local userId = clientCloud.userId    -- 当前用户 ID
local mapName = clientCloud.mapName  -- 当前地图名称
```

---

## 常见场景

### 保存游戏进度

```lua
function SaveProgress(level, score, coins)
    clientCloud:BatchSet()
        :SetInt("level", level)
        :SetInt("high_score", score)
        :SetInt("coins", coins)
        :Set("last_save", os.date())
        :Save("保存进度")
end
```

### 更新最高分

```lua
function UpdateHighScore(newScore)
    clientCloud:Get("high_score", {
        ok = function(values, iscores)
            if newScore > (iscores.high_score or 0) then
                clientCloud:SetInt("high_score", newScore, {
                    ok = function() print("新纪录!") end
                })
            end
        end
    })
end
```

### 消费金币

```lua
function SpendCoins(amount)
    clientCloud:Add("coins", -amount, {
        ok = function() print("消费成功") end,
        error = function(code, reason) print("失败:", reason) end
    })
end
```

---

## 回调结构

所有 API 的 `events` 参数结构：

```lua
{
    ok = function(...)      -- 成功回调
    end,
    error = function(code, reason)  -- 错误回调
    end,
    timeout = function()    -- 超时回调（可选）
    end
}
```

---

## 使用限制

| 限制项 | 值 | 超限行为 |
|--------|-----|---------|
| 读请求频率 | 300 次/分钟 | error 回调, code=-429 |
| 写请求频率 | 300 次/分钟 | error 回调, code=-429 |
| 数据量 | 48 MB/分钟 | error 回调, code=-429 |

超限时 error 回调参数：`error(-429, "send failed")`

---

## 要点速记

1. **Set** = 任意类型 → values（配置、装备等复杂数据）
2. **SetInt / Add** = 整数 → iscores（可排行榜）
3. **回调参数** = `(values, iscores)`，无 sscores
4. **排行榜 item** = `item.userId`
5. **昵称** = `GetUserNickname()` 查询（全局函数，客户端/服务端通用），不存储在云变量中
6. **附加字段** = `GetRankList` 的 events 之后可传额外 key 名
7. **客户端专用** = `clientCloud` 仅 Standalone / Client 模式可用；服务端用 `serverCloud`（见 [server-cloud-score.md](server-cloud-score.md)）

---
