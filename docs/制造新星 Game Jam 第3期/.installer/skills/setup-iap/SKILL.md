---
name: setup-iap
description: "引导用户为 UrhoX 游戏接入内购（IAP）功能。Use when users need to (1) 接入内购, (2) 添加商城/商品购买, (3) setup IAP, (4) 配置支付, (5) 用户想让玩家购买游戏内道具。"
---

# 内购（IAP）接入指南

> ⚠️ **前提条件：必须是联网游戏**
>
> IAP 发货逻辑运行在服务端（`Shop.onDeliver`），**单机游戏无法接入内购**。
> 接入前请先确认项目已开启联网模式：检查 `.project/settings.json` 中
> `@runtime.multiplayer.enabled` 是否为 `true`。
> 如果还没有联网，先完成联网改造再回来接入内购。

> ⚠️ **平台限制：仅支持 Android 和 iOS**

内购接入分五步：**开通功能 → 配置商品 → 实现发货逻辑 → 沙箱测试 → 提审上架**。

---

## 第一步：开通内购功能

调用 MCP 工具一键初始化支付配置（幂等，可重复执行）：

```
iap: init_payment_config
```

该操作自动完成：检查开通状态、生成/复用签名密钥、配置发货回调 URL、同步密钥到支付服务器等一系列复杂步骤，**无需用户手动操作任何配置文件**。

**失败时**：引导用户到 TapTap 开发者后台开通小游戏内购功能，完成后重新执行。
- 未发布的游戏：游戏包管理 → 小游戏管理 → 开放能力 → 小游戏内购
- 已发布的游戏：游戏包管理 → 星火小游戏管理 → 小游戏内购

---

## 第二步：配置商品

**向用户收集每个商品的信息**：

| 字段 | 说明 | 示例 |
|------|------|------|
| 商品名称 | 展示给玩家的名称 | `"60钻石礼包"` |
| 售价（元） | 人民币定价 | `6` |
| merchant_sku_id | 商品唯一 ID，用于匹配发货 | `"gem_pack_60"` |
| 发货道具 | 购买后发放的道具列表 | `[{key="gems", amount=60}]` |

然后通过 MCP 工具创建商品并写入发货配置，全程无需用户接触任何配置文件。

### 2.1 创建商品

```
# 创建商品并填写信息（名称、价格、merchant_sku_id、发货道具）
iap: create_sandbox_product
```

> **创建后商品状态说明：**
> - 刚创建的商品处于**沙箱测试阶段**（未提审/未上架），只能在测试环境中购买，不影响正式玩家

### 2.2 实现商城界面（客户端）

商品和发货配置由 MCP 工具自动管理，无需手动编辑任何配置文件。**商城 UI 由游戏自行实现**，通过客户端接口 `Shop.getProducts()` 获取商品列表后展示：

```lua
local Shop = require("urhox-libs/Shop")

-- 获取商品列表，返回 nil 表示 IAP 未开通
-- 格式: [{sku_id, name, price(元), delivery=[{key,amount}]}]
local products = Shop.getProducts()

if products then
    for _, p in ipairs(products) do
        -- 根据 p.name / p.price 渲染商品卡片
        -- 玩家点击购买时：
        Shop.purchase(p.sku_id, function(result)
            if not result.ok then
                UI.Toast.Show("购买失败: " .. tostring(result.message), { variant = "error" })
            end
            -- result.ok == true 表示支付弹窗已拉起，发货由服务端异步完成
        end)
    end
end
```

> 回调在支付弹窗**拉起后**立即触发（不等待支付结果）。发货由服务端 `Shop.onDeliver` 异步完成，客户端无需处理发货结果。

---

## 第三步：实现发货逻辑

在服务端执行路径的 `Start()` 函数中注册 `Shop.onDeliver` 回调（通常是 `scripts/network/Server.lua`，具体取决于项目结构）。**发货必须通过 `serverCloud:BatchCommit` 写入云变量**，传入 `orderId` 让云变量服在同一事务原子更新订单状态，幂等且不会重复发货。

```lua
-- 服务端：Shop 是全局对象，不需要 require

function Start()
    Shop.onDeliver(function(ctx)
        local product  = cjson.decode(ctx.productJson)
        local delivery = product.delivery or {}  -- [{key, amount}] 平铺数组
        local userId   = ctx.userId
        local orderId  = ctx.orderId

        local batch = serverCloud:BatchCommit("IAP 发货: " .. ctx.productId)
        for _, item in ipairs(delivery) do
            batch:MoneyAdd(userId, item.key, item.amount)
        end

        batch:Commit({ orderId = orderId }, {
            ok = function()
                print("[Server] 发货成功: orderId=" .. orderId .. " userId=" .. userId)
                -- 建议通过远程事件通知客户端刷新道具/UI，ctx.conn 为玩家当前连接（离线时为 nil）
                -- 远程事件用法参考：engine-docs/recipes/network-game-guide.md §4 远程事件
            end,
            err = function(code, msg)
                print("[Server] 发货失败: orderId=" .. orderId .. " err=" .. tostring(msg))
            end,
        })
    end)
end
```

**ctx 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `ctx.orderId` | string | 平台订单 ID |
| `ctx.userId` | number | 玩家 userId |
| `ctx.productId` | string | 商品 merchant_sku_id |
| `ctx.productJson` | string | 完整商品 JSON（含 delivery） |
| `ctx.conn` | Connection\|nil | 玩家当前连接，离线时为 nil。**不要在回调中直接引用 `ctx.conn`**（`ctx` 表在 `onDeliver` 返回后可能被回收）；需要在回调中使用时，应在同步体内先 `local conn = ctx.conn` 捕获，再在回调中使用 `conn`（Connection 是引用计数对象，持有引用即不会释放） |

**关键规则：**
- 发货**必须**使用服务端云变量（`serverCloud:BatchCommit`），不能用客户端云变量（`clientCloud`）。服务端云变量使用文档详见 [server-cloud-score.md]
- `batch:Commit({ orderId }, { ok, err })` — 第一个参数传 orderId，第二个参数传回调表
- 云变量写入失败时 `err` 回调触发，订单仍处于**待发货状态**，下次玩家登录时会再次触发 `onDeliver` 自动补发，无需额外处理
- 幂等：云变量服按 `orderId` 做原子 UPDATE，重复调用安全
- ⚠️ **已上线游戏注意**：若 `delivery` 中的 key 在历史版本里已被以其他类型（如字符串）写过，正式环境发货时可能因类型冲突失败，上线前需确认 key 的类型一致。新游戏无此风险。

---

## 第四步：沙箱测试

1. 通过 MCP 工具查询当前沙箱白名单：`iap: list_test_users`
   - 若白名单**已有用户**，跳过添加步骤
   - 若白名单**为空**，询问用户提供 TapTap ID，然后执行 `iap: save_test_user` 加入白名单
2. 在 Maker 中生成**测试码**（预览二维码）
3. 用 Android 设备扫码启动游戏（目前仅支持 Android）
4. 触发购买流程，支付弹窗拉起后完成支付（不真实扣款）
5. 读取云变量数值，确认道具已到账（发货成功的最直接验证）

> ⚠️ **内购测试必须在手机上进行**：支付弹窗仅在 Android 真机上可以拉起，PC 端或网页端无法触发支付流程。测试时必须用 Android 手机扫 Maker 生成的测试码二维码启动游戏，不能通过其他方式运行。
>
> 沙箱测试环境的云变量数据与正式环境**完全隔离**，测试期间写入的道具不会影响正式玩家的数据。

---

## 第五步：提审上架

沙箱测试通过后：

```
# 提交商品审核
iap: submit_product_for_review
```

审核通过后商品**自动上架**，正式环境即可对所有玩家开放购买。

审核状态查询：
- MCP 工具：`iap: list_products`
- 开发者后台：游戏包管理 → 星火小游戏管理 → 小游戏内购

> ⚠️ 商品正式上架后，沙箱测试环境将**不可用**，后续无法再通过测试码测试支付流程。

> ⚠️ **发布顺序**：必须确保商品已审核通过并上架**之后**，再更新或发布游戏版本。若游戏已发布但商品尚未上架，线上玩家将无法完成购买（建单会失败）。

---

## 常见问题

| 问题 | 原因 / 解决 |
|------|-------------|
| `init_payment_config` 报"未开通" | 先在 TapTap 开发者后台完成财务开通流程 |
| `ctx.conn` 为 nil | 玩家已离线，跳过推送，`batch:Commit` 仍正常发起即可 |
| 担心重复发货 | 平台 `Commit` 会关联订单号走原子 UPDATE（幂等） |
| `result.error == "platform_not_supported"` | IAP 仅在安卓/iOS平台下支持，其他平台应隐藏商城入口 |
| 支付弹窗拉起后显示"数据加载失败" | **沙箱环境**：检查当前 TapTap 账号是否已加入沙箱白名单（`iap: list_test_users`）；**正式环境**：检查商品是否已审核通过并上架（`iap: list_products` 或开发者后台查看商品状态） |
| 手机测试时出现连入服务器异常 | 手机扫码和 Maker 网页预览登录的很可能是同一个 TapTap 账号，两端会互相挤号。**测试内购前建议先关闭 Maker 的网页预览**，确保同一账号只有手机端在线 |

---

## 常见相关需求示例：玩家连入时同步道具余额

客户端每次连入展示最新余额，标准做法是：玩家连入时客户端主动请求，服务端从云变量读取后通过远程事件推送回来。

**客户端 Start() 中直接发送请求**

```lua
-- scripts/network/Client.lua

function Start()
    network:RegisterRemoteEvent("RequestInventory")
    network:RegisterRemoteEvent("InventorySync")

    local conn = network:GetServerConnection()
    if conn then
        conn:SendRemoteEvent("RequestInventory", true)
    end

    SubscribeToEvent("InventorySync", "HandleInventorySync")
end

-- 收到服务端推送，更新 UI
function HandleInventorySync(eventType, eventData)
    local gems = eventData["gems"]:GetInt()
    local gold = eventData["gold"]:GetInt()
    -- 更新商城/HUD 显示
end
```

**服务端响应请求并在发货后复用推送**

```lua
-- scripts/network/Server.lua
local function syncInventory(conn, userId)
    serverCloud:BatchGet(userId):Key("gems"):Key("gold"):Fetch({
        ok = function(data)
            if not conn:IsConnected() then return end  -- Fetch 是异步的，推送前需再次检查
            local vm = VariantMap()
            vm["gems"] = Variant(data.gems or 0)
            vm["gold"] = Variant(data.gold or 0)
            conn:SendRemoteEvent("InventorySync", true, vm)
        end,
    })
end

function HandleRequestInventory(eventType, eventData)
    local conn   = eventData["Connection"]:GetPtr("Connection")
    local userId = conn:GetIdentity()
    syncInventory(conn, userId)
end

function Start()
    network:RegisterRemoteEvent("RequestInventory")
    network:RegisterRemoteEvent("InventorySync")
    SubscribeToEvent("RequestInventory", "HandleRequestInventory")

    -- 发货成功后重新查询云变量推送最新余额
    Shop.onDeliver(function(ctx)
        local product  = cjson.decode(ctx.productJson)
        local delivery = product.delivery or {}
        local userId   = ctx.userId
        local orderId  = ctx.orderId
        local conn     = ctx.conn  -- 同步体内提前捕获；Connection 是引用计数对象，不会被释放

        local batch = serverCloud:BatchCommit("IAP 发货: " .. ctx.productId)
        for _, item in ipairs(delivery) do
            batch:MoneyAdd(userId, item.key, item.amount)
        end

        batch:Commit({ orderId = orderId }, {
            ok = function()
                if conn and conn:IsConnected() then
                    syncInventory(conn, userId)  -- 重新查询，推送最新余额
                end
            end,
            err = function(code, msg)
                print("[Server] 发货失败: orderId=" .. orderId .. " err=" .. tostring(msg))
            end,
        })
    end)
end
```

> 发货后客户端收到 `InventorySync` 推送最新余额。离线补单触发的 `onDeliver` 因 `conn` 为 nil 不会推送，玩家下次连入时由 `RequestInventory` 流程自动同步。
