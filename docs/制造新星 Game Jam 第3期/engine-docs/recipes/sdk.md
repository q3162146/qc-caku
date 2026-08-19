# SDK 接口使用指南


## 📢 激励视频广告

### API

```lua
sdk:ShowRewardVideoAd(callback) -> boolean
```

**回调参数 `result`：**
- `success` (boolean): 广告播放是否成功
- `msg` (string): 结果消息
- `extra` (string): 广告 SDK 返回的扩展信息 JSON，未返回时为空字符串

**返回值：**
- `true`：本次广告展示请求已被受理，最终结果以回调的 `result.success` 为准
- `false`：请求未被受理，例如命中 3 秒防抖、冷却未结束、已有广告请求进行中、
  宿主/JNI/SDK 不可用或缺少广告位配置

返回值不代表广告是否完整观看。返回 `false` 时，失败回调可能在当前调用栈内同步触发，
也可能完全不触发；调用方必须同时处理返回值和回调，并用一次性完成状态避免重复恢复 UI
或重复发奖。

### 示例

```lua
local function watchAdForReward()
    local completed = false
    local callbackFired = false

    local function finish(result)
        if completed then
            return
        end
        completed = true

        if result and result.success then
            playerCoins = playerCoins + 100
            showMessage("获得 100 金币！")
        else
            showMessage("广告播放失败: " ..
                tostring(result and result.msg or "广告暂不可用"))
        end
    end

    local accepted = sdk:ShowRewardVideoAd(function(result)
        callbackFired = true
        finish(result)
    end)

    if accepted == false and not callbackFired then
        finish({ success = false, msg = "广告暂不可用，请稍后重试" })
    end
end
```

### 回调 `result.msg` 取值说明

| msg | success | 含义 |
|-----|---------|------|
| `"embed success"` | `true` | 广告完整观看，可发放奖励 |
| `"embed manual close"` | `false` | 用户在广告播放完成前**主动关闭**，不应发放奖励 |
| `"unsupported platform"` | `false` | 非嵌入式环境或平台不支持广告 |
| 其他字符串 | `false` | TapSDK 内部错误，值为错误描述 |

> **`embed manual close`**：仅出现在 iOS Embed 模式下。表示广告 `onClose` 回调触发时 `finished = false`，即用户未完整观看即手动关闭。此时**不应给予奖励**，可提示用户"需完整观看广告才能获得奖励"。

### 注意事项
- 只有在 `result.success` 为 `true` 时才给予玩家奖励
- 遵循平台广告约束：
  - 用户体验优先，禁止生成用户在无预期下需要强制观看的广告
  - 尽可能贴合游戏原本的设计，较为自然地接入广告
  - 鼓励使用激励形式，用户观看广告后可以获得一些奖励

---

## 📳 设备震动

在移动端宿主环境中运行时，可以通过 `sdk` 触发短震动或长震动。非支持平台会静默返回 `false`，不会抛错。

### API

```lua
sdk:VibrateShort(type) -> boolean
sdk:VibrateLong() -> boolean
```

`VibrateShort` 的 `type` 可省略，默认 `"medium"`：

| type | 说明 |
|------|------|
| `"light"` | 轻震 |
| `"medium"` | 中震 |
| `"heavy"` | 重震 |

> Web/WASM 当前会忽略 `type`，三种取值均使用相同的震动时长。

### 示例

```lua
sdk:VibrateShort()
sdk:VibrateShort("light")
sdk:VibrateLong()
```

### 返回值

- `true`：当前平台/宿主已接受震动请求
- `false`：参数非法、平台不支持、宿主未提供震动能力，或浏览器拒绝震动

### 注意事项

- `sdk:VibrateShort("bad")`、`sdk:VibrateShort(1)` 会返回 `false`
- Web/WASM 使用浏览器 `navigator.vibrate`，支持情况由浏览器决定
- Windows/macOS 等桌面环境默认返回 `false`

---

## 🚪 宿主退出按钮位置

在 TapTap 宿主环境中运行时，平台会在屏幕上显示一个退出胶囊。游戏可以通过此接口获取胶囊位置，避免自身 UI 与之重叠（`urhox-libs/UI` 的 `SafeAreaView` 已自动避让，直接用即可）。

### API

```lua
sdk:GetNativeExitMenuRect() -> table | nil
```

**返回值：**
- 有胶囊：`table { left, top, right, bottom }` — 归一化坐标 (0~1)，左上角为原点
- 无胶囊：`nil`

| 字段 | 类型 | 说明 |
|------|------|------|
| `left` | number | 矩形左边缘 x (0~1) |
| `top` | number | 矩形上边缘 y (0~1) |
| `right` | number | 矩形右边缘 x (0~1) |
| `bottom` | number | 矩形下边缘 y (0~1) |

### 示例

```lua
local rect = sdk:GetNativeExitMenuRect()
if rect then
    -- rect ≈ {left=0.92, top=0.01, right=0.99, bottom=0.05}
    -- 避免在该区域放置游戏 UI
end
```

### 注意事项
- 坐标为 **归一化值 (0~1)**，与设备分辨率无关
- 调用方应统一按"返回 nil = 没有胶囊"处理，不需要做平台分支
- 建议在 `Start()` 中调用一次并缓存结果，胶囊位置在运行期间不会变化

---
