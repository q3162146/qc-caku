#### Sprite (预览版)

序列帧（sprite-sheet）动画控件，播放帧动画或显示静态帧。像 CSS `<img>` 一样按 `objectFit` 缩放，多动画按名切换。

> **图集来源**：推荐用官方 **sprite-gen** 生成（产出下方“目录结构与加载”的 `sprites/<name>/` 结构）；来源不是 sprite-gen 的，需自行转换成本格式。Sprite 只负责加载与播放。

```lua
UI.Sprite {
    src = "sprites/hero/sprite.json",   -- sprite-gen 入口，自动注册该角色全部动画（见“目录结构与加载”）
    defaultAnimation = "idle",          -- 挂载时自动播哪个；缺省播第一个动画
    -- loop = false,                    -- 覆盖当前动画的循环；不填则按各动画数据里的 repeat（idle 无限、jump 播一次…）
    -- width = 156, height = 256,       -- 不给则按当前动画的 sourceSize 自适应（像 <img>）
    -- speed = 1.5,                     -- 播放速度倍率（缺省 1.0），负数 = 倒放
    -- autoPlay = false,                -- 默认 true；为 false 则停在首帧
    -- objectFit = "contain",           -- contain | cover | fill | none（缺省 contain）
    -- objectPosition = "center",       -- center|top|bottom|left|right|{x,y}（缺省 center）；独立于 pivot
    -- flipX = true, flipY = true,      -- 翻转
    -- frame = "idle_0001",             -- 静态显示单帧（按帧 key {anim}_{num}），忽略 autoPlay
    -- applyPivotInAbsolute = true,     -- 绝对布局下支点钉 left/top + rotate/scale 绕支点（见“支点”）
    -- onComplete = function(animName) end,
    -- onLoop = function(count) end,
    -- onFrameChange = function(frame, localFrame) end,
    -- onPlay = function(name, prevName) end, -- 切动画后触发：此刻 GetSourceSize/支点/盒已是新动画值，可重排布局
}
```

**目录结构与加载**：sprite-gen 给每个角色产出一个目录 `sprites/<name>/`，文件名固定：

```
sprites/hero/
├── sprite.json          # 虚拟入口：meta.relatedMultiPacks 递归聚合各动画（推荐 src；纹理按页懒加载）
├── idle/spritesheet.json
└── jump/spritesheet.json # 一动画一文件（独立图集）
```

每个图集 json 的顶层 `animations` 数组定义动画（`[{name, frames=[帧key...], repeat, fps, pivot}]`）。Sprite 把加载到的动画**按注册顺序**汇总，不填 `defaultAnimation` 则播第一个。两种 `src` 入口：

```lua
-- ① 虚拟入口 sprite.json（推荐）：一句 src 注册全部动画；纹理按页懒加载——没播到的动画 png 不下载
UI.Sprite { src = "sprites/hero/sprite.json", defaultAnimation = "walk" }

-- ② 手动挑多文件：只用某几个独立动画图集时
UI.Sprite {
    animations = {                              -- 名→路径 map（也可 { {name="idle", src=".."}, ... } 数组）
        idle = "sprites/hero/idle/spritesheet.json",
        jump = "sprites/hero/jump/spritesheet.json",
    },
    defaultAnimation = "idle",                  -- map 无序，建议显式指定
}
```

> `source_size_mode`：`canvas`（所有动画共享同一画布尺寸）或 `bbox-per-anim`（每动画各自紧包围盒，更省空间、尺寸不同）。

**播放控制**：

```lua
sprite:Play("jump", { loop = false, speed = 2,
    direction = "pingpong",           -- forward | reverse | pingpong
    onComplete = function(name) sprite:Play("idle") end })
sprite:Stop(); sprite:Pause(); sprite:Resume()
sprite:SetSpeed(0.5)                  -- 负数倒放
sprite:GotoAndStop("idle_0003")       -- 跳到帧并停：字符串=帧 key，数字=动画内 0-based 序号
sprite:GotoAndPlay(2)                 -- 跳到动画内第 2 帧并播（0-based）
sprite:Chain("attack"):Chain("idle")  -- 队列：当前播完接着播下一个
sprite:ClearChain()
```

**外观与变换**：

```lua
sprite:SetObjectFit("cover")          -- 缩放模式
sprite:SetObjectPosition("bottom")    -- 盒内对齐（留白时内容贴哪），CSS object-position
sprite:SetFlipX(true); sprite:SetFlipY(true)
```

> `objectFit`（缩放）和 `objectPosition`（盒内对齐）都**独立于 pivot**，互不影响。

**支点 pivot**（纯数据）：

```lua
local p = sprite:GetPivot()           -- 归一化 {x,y}（优先级 custom→帧→当前动画→meta→0.5,0.5）；作者可自取做特殊布局
sprite:SetCustomPivot(0.5, 1.0)       -- 运行时覆盖（最高优先级）；传 nil 清除
local ss = sprite:GetSourceSize()     -- 当前帧的 sourceSize {w,h}
```

**`applyPivotInAbsolute`（绝对布局按支点对齐坐标）**：在 `position="absolute"` 下打开后，组件每帧把支点钉到 `left/top`，**并自动接管 `transformOrigin="top-left"`，使 `rotate`/`scale` 绕支点旋转/缩放**——无需手动维护（切动画、换尺寸都不用重设）。支点取自图集数据（动画 / meta 的 pivot），也可 `SetCustomPivot(0.5, 1.0)` 把支点设到底边中点（如角色脚底）。

```lua
UI.Sprite { position = "absolute", left = 100, top = 300, rotate = 15,
            applyPivotInAbsolute = true, src = "sprites/hero/sprite.json", defaultAnimation = "idle" }
```

**查询**：`IsPlaying()`、`IsPaused()`、`IsStopped()`、`GetCurrentAnimation()`、`GetCurrentFrame()`、`GetLocalFrame()`、`GetCurrentFrameKey()`、`GetFrameCount()`、`GetProgress()`、`GetAnimationNames()`、`GetDuration(name)`（秒）、`GetSheet()`、`GetSourceSize()`

**典型用法**：

```lua
-- 角色多动画 + 按名切换（不 pin 尺寸 → 盒跟当前动画，bbox-per-anim 切换缩放一致）
local hero = UI.Sprite { src = "sprites/hero/sprite.json", defaultAnimation = "idle" }
-- 玩法里：hero:Play("run") / hero:Play("attack", { loop = false, onComplete = function() hero:Play("idle") end })

-- 地图角色支点对齐地面（绝对布局）：支点锚在 (x, groundY)，切动画/跳跃时支点不动（脚踩地不漂移）
UI.Sprite { position = "absolute", left = x, top = groundY, applyPivotInAbsolute = true,
            src = "sprites/hero/sprite.json", defaultAnimation = "idle" }

-- 静态显示某一帧（不播放），帧 key 形如 {anim}_{num}
UI.Sprite { src = "sprites/hero/sprite.json", frame = "idle_0001" }
```

**⚠️ 注意**：
- `objectFit`/`objectPosition` 与 `pivot` 是不同层，互不影响：缩放/对齐用前两者，旋转/缩放中心或落点对齐用 pivot。
- **不给 `width/height`** → 固有盒跟**当前动画**的 sourceSize；`bbox-per-anim` 下切到不同尺寸动画盒会随之变（绝对布局靠支点锚定、大动画如 jump 自然往上探；流式布局以**预览**为主，不建议切逻辑动画）。
- **给了固定 `width/height` + `bbox-per-anim` 多动画 + `contain`** → 切动画会有**缩放跳变**（各动画 bbox 不同、缩进同一固定盒比例不同）。要一致：别 pin 尺寸（走固有盒），或让工具产出 `canvas` 模式。
- DWP：动画 json 在加载入口时全部解析（注册全部动画），但**纹理 png 按页懒加载**——没播到的动画 png 不下载；首次出现时走引擎系统级淡入（无需自己做淡入）。
- 帧 key 全局唯一；`animations` 用 map 时无序，建议显式 `defaultAnimation`。
- `sheet` 与 `src` 互斥（同时给则忽略 `src`）；`animations` 总是叠加在 `sheet`/`src` 之上。
