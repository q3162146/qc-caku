-- ============================================================================
-- game/PlayerController.lua
-- 玩家控制器：第三人称移动 + 相机 + 基础碰撞 + 桃花收集触发
--
-- 规范（快速开工包 ④）：
--   - 输入用 KEY_*/MOUSEB_* 枚举，禁止数字常量；
--   - 世界单位米、Y 轴向上；角色胶囊高 1.8（约 1.6~1.8 米人形尺度）；
--   - 碰撞层：GROUND=1 / PLAYER=2 / TRIGGER=4（与 WhiteBox 一致）；
--   - 收集触发用 PhysicsCollisionStart（一次性），不在 Update 里轮询。
-- ============================================================================

local ThirdPersonCamera = require "urhox-libs.Camera.ThirdPersonCamera"
local InputManager = require "game.InputManager"
local WhiteBox = require "game.WhiteBox"
local GameHUD = require "urhox-libs.UI.GameHUD"

local PlayerController = {}

---@type Scene|nil
local scene_ = nil
---@type Node|nil
local playerNode_ = nil
---@type CharacterComponent|nil
local character_ = nil
---@type KinematicCharacterController|nil
local kcc_ = nil
---@type ThirdPersonCameraInstance|nil
local tpCamera_ = nil
---@type number
local yaw_ = 0
---@type number
local pitch_ = 0
---@type function|nil
local blossomHandler_ = nil
---@type boolean 是否启用作近拾取（仅当前流段为 explore 时 true，由 FlowController 维护）
local pickupsEnabled_ = false
---@type table 已上报"进入半径"的标记节点（边沿触发，离开半径即重置，防每帧刷屏）
local inRadius_ = {}
---@class PlayerBounds
---@field minX number
---@field maxX number
---@field minZ number
---@field maxZ number
---@type PlayerBounds|nil 场景可走边界硬钳制（LoadScene 传入；nil=不钳制）
local bounds_ = nil

local MOUSE_SENSITIVITY = 0.15   -- 鼠标灵敏度（度/像素）
local PITCH_LIMIT = 80.0
local PICKUP_RADIUS = 1.6        -- 走近拾取/交互半径（米；真机摇杆走近需略大于白模球体）

-- 移动速度倍数（D 阶段真机测试曾临时 ×4，已恢复 1.0 正式值）
local DEBUG_MOVE_SPEED_MULTIPLIER = 1.0

-- 素女 3D 模型（D3 角色动画：官方库带骨骼古风女性，41 骨 Tripo Rig 标准骨架，
--   可自动重定向官方 DefaultMale 人形动画（idle/walk/run），FSM 驱动）
local SUNU_RIG_MODEL = "model/3a5478a7-95aa-5840-a4c5-713c57214e20/Meshes/rig-1-a7be4e0a-6cd7-4e64-adc7-376f75cb5064.mdl"
local SUNU_RIG_MATERIAL = "model/3a5478a7-95aa-5840-a4c5-713c57214e20/Materials/rig-1-a7be4e0a-6cd7-4e64-adc7-376f75cb5064_00_tripo_material_a7ec7f07-66d8-4f3f-8f49-69d441544492.xml"
local SUNU_FSM_FILE = "FSM/Sunu.fsm"
-- DWP 下载扩展（把 DownloadResources 等装到 cache；真机/预览按需下载 uuid 动画必需）
require "urhox-libs.Engine.ResourceCacheExtensions"

-- FSM 引用的素女动画：本地 .ani 优先（真机必播保底，不依赖 DWP/uuid），
-- 与 Sunu.fsm / SunuMoveBlend.blendspace 的 _animationPaths 一一对应。
-- 来源：官方 AnimSet_DefaultMale 同名动画（CDN 下载，UANI 魔数校验通过）
local SUNU_ANIM_LOCAL = {
    "animation/DefaultMale_Idle.ani",         -- 站立待机
    "animation/DefaultMale_WalkForward.ani",  -- 向前行走
    "animation/DefaultMale_RunForward.ani",   -- 向前跑步
}
-- DWP 预案：本地 .ani 缺失时回退的官方动画 uuid（DWP 按需下载）
local SUNU_ANIM_URIS = {
    "uuid://HIPCWSBd61v8PRI972Yksxzh",  -- 站立待机
    "uuid://HhyjGZvHN9uF8lRsGnN_J7jc",  -- 向前行走
    "uuid://FshxoWge4mzIJ-wmBu0GK6Vs",  -- 向前跑步
}
-- 旧静态素女（rig 模型加载失败时的回退视觉，保玩法不破）
local SUNU_MODEL = "model/57c4a9a5cfae45a89f9895d411d0fd40/Meshes/texture-2-9736947c-8d44-4e7a-b250-7183fdba3619.mdl"
local SUNU_MATERIAL = "model/57c4a9a5cfae45a89f9895d411d0fd40/Materials/texture-2-9736947c-8d44-4e7a-b250-7183fdba3619_00_tripo_node_cec0a95c-7f56-4e3e-94df-78c87bc56e1b_material.xml"
local SUNU_HEIGHT = 1.6          -- 目标身高（米），与胶囊 1.8 视觉匹配

---@type AnimationStateMachine|nil
local sunuFsm_ = nil
---@type AnimatedModel|nil 素女骨骼模型引用（诊断②动画状态数查询用）
local sunuModel_ = nil

-- ── 四线诊断 + 手动兜底（真机"人物动画僵直"排查，2026-09-02）─────────────
---@type number 诊断累计时间（秒）
local diagTime_ = 0.0
---@type boolean 诊断②一次性输出标记（~1 秒后，动画状态已建立）
local diagOneShot_ = false
---@type boolean 看门狗是否已判定（~3 秒后一次性）
local watchdogFired_ = false
---@type number 诊断③周期性输出计时（每 1 秒一行）
local diag3Accum_ = 0.0
-- 诊断④ 骨架绑定统计（动画轨道名 ∩ 模型骨骼名）
--- @param anim Animation
--- @param skel Skeleton
--- @return integer bound
--- @return integer total
local function CountBoundTracks(anim, skel)
    local bound, total = 0, anim:GetNumTracks()
    for i = 0, total - 1 do
        local tr = anim:GetTrack(i)
        if tr ~= nil and skel:GetBone(tr.name) ~= nil then
            bound = bound + 1
        end
    end
    return bound, total
end

---@type integer 诊断/看门狗帧计数（PostUpdate 每帧 +1）
local diagFrames_ = 0
---@type integer 手动兜底模式当前播放的动画索引（1=待机 2=走 3=跑）
local manualClipIndex_ = 0
---@type boolean 手动兜底是否已激活（FSM 无输出时接管）
local manualDriveActive_ = false
---@type AnimationController|nil
local manualController_ = nil
---@type AnimationStateMachine|nil 兜底激活前先移除的 FSM 组件引用
local fsmToRemove_ = nil

--- 激活手动兜底（方案 D）：移除 AnimationStateMachine（文档明令二者不可同节点并用），
--- 用 AnimationController 按 moveSpeed 手动切 idle/walk/run。只在 FSM 失效时调用一次。
local function ActivateManualDrive()
    if manualDriveActive_ then return end
    manualDriveActive_ = true
    if fsmToRemove_ ~= nil then
        fsmToRemove_:Remove()
        fsmToRemove_ = nil
    end
    sunuFsm_ = nil
    if playerNode_ ~= nil then
        local modelNode = playerNode_:GetChild("ModelNode")
        if modelNode ~= nil then
            manualController_ = modelNode:GetOrCreateComponent("AnimationController")
        end
    end
    manualClipIndex_ = 0
    print("[诊断②] 手动兜底已激活（移除FSM，AnimationController 接管）")
    if manualController_ ~= nil then
        manualController_:PlayExclusive(SUNU_ANIM_LOCAL[1], 0, true, 0.25)
        manualClipIndex_ = 1
    end
end

--- 手动兜底（方案 D）：AnimationController 按 moveSpeed 直接切
--- idle/walk/run（PlayExclusive + 淡入），不依赖 FSM/BlendSpace，真机必播。
---@param speed number
local function ManualDriveTick(speed)
    if manualController_ == nil then return end
    local idx = 1
    if speed >= 3.5 then
        idx = 3
    elseif speed >= 0.5 then
        idx = 2
    end
    if idx ~= manualClipIndex_ then
        manualClipIndex_ = idx
        local path = SUNU_ANIM_LOCAL[idx]
        if path ~= nil then
            manualController_:PlayExclusive(path, 0, true, 0.25)
            print("[诊断②] 手动兜底切换动画 -> " .. path)
        end
    end
end

--- 本地 .ani 是否全部可加载（真机必播保底的判据；入包资源走本地缓存，不依赖网络）
---@return boolean
local function AreLocalAnimsReady()
    local ready = true
    for _, path in ipairs(SUNU_ANIM_LOCAL) do
        ---@type Animation|nil
        local anim = cache:GetResource("Animation", path)
        if anim == nil then
            print("[PlayerController] 警告：本地动画缺失: " .. path)
            ready = false
        else
            print("[PlayerController] 本地动画就绪: " .. path)
        end
    end
    return ready
end

--- 启动素女动画 FSM（本地 .ani 就绪后调用；FSM 动画路径指向本地虚拟路径，
--- 不依赖 DWP/uuid，真机走/跑/停必播）
---@param modelNode Node
local function StartSunuFSM(modelNode)
    modelNode:GetOrCreateComponent("AnimationController")
    local fsm = modelNode:CreateComponent("AnimationStateMachine")
    ---@type JSONFile|nil
    local fsmFile = cache:GetResource("JSONFile", SUNU_FSM_FILE)
    if fsmFile ~= nil then
        local loaded = fsm:LoadFromJSONFile(fsmFile)
        fsm:Start()
        sunuFsm_ = fsm
        fsmToRemove_ = fsm
        print("[PlayerController] 素女动画 FSM 已启动(load=" .. tostring(loaded)
            .. " layers=" .. fsm:GetNumLayers() .. "): " .. SUNU_FSM_FILE)
    else
        print("[PlayerController] 警告：FSM 文件加载失败，模型静态: " .. SUNU_FSM_FILE)
    end
end

--- DWP 预案（保底诊断通道）：本地 .ani 意外缺失时，尝试下载官方动画 uuid，
--- 结果写日志（真机排查 "cannot resolve/skip" 用）；FSM 已指向本地路径，
--- 下载成功与否都不再影响动画播放逻辑，动画保持静态回退不崩溃。
local function FallbackDwpAnimDownload()
    if cache.DownloadResources == nil then
        print("[PlayerController] 无 DWP 下载 API，跳过动画 uuid 预案下载")
        return
    end
    print("[PlayerController] 本地动画缺失 → 触发 uuid 预案下载（诊断通道，"
        .. #SUNU_ANIM_URIS .. " 个）")
    cache:DownloadResources(SUNU_ANIM_URIS, function(success, failed)
        print("[PlayerController] uuid 预案下载结果: success=" .. tostring(success)
            .. " failed=" .. tostring(failed))
    end)
end

--- 创建玩家与相机
---@param scene Scene
---@return boolean
function PlayerController.Create(scene)
    scene_ = scene
    if playerNode_ ~= nil then
        return true
    end

    -- 玩家节点
    playerNode_ = scene:CreateChild("Player")

    -- 视觉：素女 3D 模型。D3 优先带骨骼版（AnimatedModel + FSM 播 idle/walk/run），
    --   加载失败回退旧静态网格（随节点整体转向/移动），再失败回退白模球，保玩法不破
    local modelNode = playerNode_:CreateChild("ModelNode")
    local rigModel = cache:GetResource("Model", SUNU_RIG_MODEL)
    local rigMat = cache:GetResource("Material", SUNU_RIG_MATERIAL)
    local rigLoaded = false
    if rigModel ~= nil and rigModel:GetSkeleton() ~= nil
        and rigModel:GetSkeleton():GetNumBones() > 0 then
        ---@type AnimatedModel
        local bodyModel = modelNode:CreateComponent("AnimatedModel")
        bodyModel:SetModel(rigModel)
        if rigMat ~= nil then
            bodyModel:SetMaterial(rigMat)
        end
        bodyModel.castShadows = true
        -- 视锥外/遮挡时仍推进动画（真机第三人称背身偶尔被树冠遮挡不至于冻结）
        bodyModel:SetUpdateInvisible(true)
        sunuModel_ = bodyModel
        -- rig 包围盒高 ≈1.0 且 Min Y=0 → 等比缩放即脚底落地
        modelNode.scale = Vector3(SUNU_HEIGHT, SUNU_HEIGHT, SUNU_HEIGHT)
        -- rig 网格视觉正面在 -Z（D3 截图实测：+90° 呈左侧脸 → 反推正面 -Z）；
        -- 节点前向 +Z，绕 Y 180° 使正面朝前、第三人称相机看背影
        modelNode:SetRotation(Quaternion(180, Vector3.UP))
        -- 重定向防飘移：禁用 Root/Hip（3D 角色管线标准做法）
        local skel = bodyModel:GetSkeleton()
        if skel ~= nil then
            local rootBone = skel:GetBone("Root")
            if rootBone ~= nil then rootBone.animated = false end
            local hipBone = skel:GetBone("Hip")
            if hipBone ~= nil then hipBone.animated = false end
        end
        -- 诊断①/④（一次性）：模型类型 + 每支本地动画轨道与骨架的绑定统计
        print(string.format("[诊断①] 模型=AnimatedModel 骨骼数=%d rig=%s",
            skel ~= nil and skel:GetNumBones() or -1, SUNU_RIG_MODEL))
        if skel ~= nil then
            for _, path in ipairs(SUNU_ANIM_LOCAL) do
                ---@type Animation|nil
                local anim = cache:GetResource("Animation", path)
                if anim == nil then
                    print("[诊断④] 动画缺失 -> " .. path)
                else
                    local bound, total = CountBoundTracks(anim, skel)
                    print(string.format("[诊断④] 轨道绑定 %d/%d (%s) len=%.2fs",
                        bound, total, path, anim:GetLength()))
                    if bound == 0 then
                        print("[诊断④] 警告：该动画与骨架零绑定 → 播了也不动（僵直根因）")
                    end
                end
            end
        end
        -- 动画状态机：idle(0)/walk(2)/run(5) BlendSpace，按 moveSpeed 混合。
        -- 真机修复②：FSM 动画路径指向【本地入包 .ani】（项目 CDN，与模型同源可达），
        -- 不再依赖 uuid 跨源解析（旧根因：uuid DWP 真机解析失败 → FSM 空动画 → 静态）。
        -- Animation 为 DWP 占位热替换类型：立即启动 FSM，动画到包后自动热替换开播；
        -- 资源彻底缺失则空动画静态回退（不崩）。不再用下载回调做启动门槛。
        if AreLocalAnimsReady() then
            -- 本地 .ani 入包资源走 ResourceCache 本地加载，不经 DWP 下载
            -- （DWP 只解析远程资源，本地路径会报 cannot resolve，故不发起下载）
            StartSunuFSM(modelNode)
        else
            -- 本地 .ani 不在包内（构建异常）：保留 uuid DWP 预案作诊断通道，
            -- 同时仍启动 FSM（路径解析不到 → 空动画静态，保底不崩）
            FallbackDwpAnimDownload()
            StartSunuFSM(modelNode)
        end
        rigLoaded = true
        print("[PlayerController] 素女骨骼模型已加载: " .. SUNU_RIG_MODEL)
    else
        print("[PlayerController] 警告：带骨骼素女加载失败，回退静态模型")
        print("[诊断①] 模型=回退路径（rig 资源不可用，骨骼数为 0）")
    end

    if not rigLoaded then
        local sunuModel = cache:GetResource("Model", SUNU_MODEL)
        local sunuMat = cache:GetResource("Material", SUNU_MATERIAL)
        if sunuModel ~= nil then
            print("[诊断①] 模型=StaticModel（旧静态素女，无动画）")
            local bodyModel = modelNode:CreateComponent("StaticModel")
            bodyModel:SetModel(sunuModel)
            if sunuMat ~= nil then
                bodyModel:SetMaterial(sunuMat)
            end
            bodyModel.castShadows = true
            -- 静态版包围盒 ≈1.0m 高且中心居中（Min Y ≈ -0.5）→ 上移半身高使脚底落地
            modelNode.scale = Vector3(SUNU_HEIGHT, SUNU_HEIGHT, SUNU_HEIGHT)
            modelNode.position = Vector3(0, SUNU_HEIGHT / 2, 0)
            modelNode:SetRotation(Quaternion(90, Vector3.UP))
        else
            print("[PlayerController] 警告：素女模型加载失败，回退白模球")
            local bodyModel = modelNode:CreateComponent("StaticModel")
            bodyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
            bodyModel:SetMaterial(WhiteBoxCreatePlayerMaterial())
            bodyModel.castShadows = true
            modelNode.scale = Vector3(0.45, 0.6, 0.45)
            modelNode.position = Vector3(0, 0.65, 0)
        end
    end

    -- 刚体（运动学角色：KCC 驱动，RigidBody 只负责碰撞事件）
    local body = playerNode_:CreateComponent("RigidBody")
    body:SetCollisionLayerAndMask(WhiteBox.LAYER_PLAYER,
        WhiteBox.LAYER_GROUND | WhiteBox.LAYER_TRIGGER)
    body:SetMass(1)
    body:SetLinearFactor(Vector3.ZERO)
    body:SetAngularFactor(Vector3.ZERO)
    body:SetCollisionEventMode(COLLISION_ALWAYS)

    -- 胶囊碰撞（直径 0.7，高 1.8，底部贴近节点原点）
    local shape = playerNode_:CreateComponent("CollisionShape")
    shape:SetCapsule(0.7, 1.8, Vector3(0.0, 0.86, 0.0))

    -- 运动学角色控制器
    local kcc = playerNode_:CreateComponent("KinematicCharacterController")
    kcc:SetCollisionLayerAndMask(WhiteBox.LAYER_PLAYER, WhiteBox.LAYER_GROUND)
    kcc:SetJumpSpeed(8.0)
    kcc_ = kcc

    -- 角色组件（只处理物理移动）
    character_ = playerNode_:CreateComponent("CharacterComponent")
    character_:SetAirControlFactor(0.6)
    character_:SetEnableWalkMode(true)      -- 默认步行，Shift 跑步
    character_.autoRotateToMoveDir = true   -- 探索模式：面向移动方向
    character_.rotationSpeed = 1440.0

    -- ⚠️ D 阶段真机测试临时提速（发布前恢复：DEBUG_MOVE_SPEED_MULTIPLIER = 1.0）
    if DEBUG_MOVE_SPEED_MULTIPLIER ~= 1.0 then
        local w = character_.walkSpeed * DEBUG_MOVE_SPEED_MULTIPLIER
        local r = character_.runSpeed * DEBUG_MOVE_SPEED_MULTIPLIER
        character_:SetWalkSpeed(w)
        character_:SetRunSpeed(r)
        print("[PlayerController] 临时提速 x" .. DEBUG_MOVE_SPEED_MULTIPLIER
            .. " walk=" .. w .. " run=" .. r)
    end

    -- 第三人称相机
    -- R12（2026-08-22）：拉远 + 抬升 + 加宽视角，缩小玩家占屏（真机复核占屏 1/4~1/3 → 修复）
    tpCamera_ = ThirdPersonCamera.Create(scene, {
        modes = {
            normal = { distance = 6.8, offset = Vector3(0, 2.3, 0), fov = 52.0 },
        },
        transitionSpeed = 8.0,
        farClip = 300.0,
    })
    renderer:SetViewport(0, Viewport:new(scene, tpCamera_:GetCamera()))

    -- 鼠标相对模式（PC 视角）
    InputManager.SetRelativeMouseMode()

    -- 真机触屏：仅移动摇杆 + 滑动视角；不创建 Run/Jump（验收要求清掉调试感按钮）
    GameHUD.Initialize()
    GameHUD.SetControls(character_.controls)
    GameHUD.Create()
    GameHUD.EnableTouchLook({ camera = tpCamera_:GetNode() })

    -- 拾取/交互改用 Update 内距离轮询（真机 KCC 驱动不触发 PhysicsCollisionStart，见 Update）
    -- 不再订阅全局碰撞事件，避免与轮询重复触发。

    print("[PlayerController] 玩家已创建")
    return true
end

--- 创建玩家白色材质（无光照，便于辨识）
function WhiteBoxCreatePlayerMaterial()
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.95, 0.88, 0.78, 1)))
    return mat
end

--- 设置玩家位置（场景切换时调用）
---@param position Vector3
function PlayerController.SetPosition(position)
    if playerNode_ ~= nil and position ~= nil then
        local target = Vector3(position.x, 0.6, position.z)
        playerNode_.position = target
        -- KCC 内部运动学状态不会跟随节点直接赋值，首帧物理步进会把玩家拉回旧位
        -- （出生点落在无涕桃树冠内等碰撞体时表现尤为明显）；Warp 同步 KCC 状态。
        if kcc_ ~= nil then
            kcc_:Warp(target)
        end
    end
end

--- 调试：设置第三人称相机朝向（截图/直切场景用）
---@param yaw number
---@param pitch number
function PlayerController.SetLook(yaw, pitch)
    yaw_ = yaw or 0
    pitch_ = pitch or 0
    if character_ ~= nil then
        character_.controls.yaw = yaw_
        character_.controls.pitch = Clamp(pitch_, -PITCH_LIMIT, PITCH_LIMIT)
    end
end

--- 注册桃花收集回调（FlowController 注入）
---@param handler function|nil function(key: string, node: Node)
function PlayerController.SetBlossomHandler(handler)
    blossomHandler_ = handler
end

--- 设置场景可走边界硬钳制（真机修复 ②：×4 提速下防 KCC 隧穿/摇杆拉出界）
---@param b PlayerBounds|nil nil = 不钳制
function PlayerController.SetBounds(b)
    bounds_ = b
end

--- 物理步进后把玩家 XZ 钳回可走边界（超界才写位置 + Warp 同步 KCC 内部状态）
local function ClampToBounds()
    if bounds_ == nil or playerNode_ == nil then return end
    local p = playerNode_.position
    local cx = math.max(bounds_.minX, math.min(bounds_.maxX, p.x))
    local cz = math.max(bounds_.minZ, math.min(bounds_.maxZ, p.z))
    if cx ~= p.x or cz ~= p.z then
        local np = Vector3(cx, p.y, cz)
        playerNode_.position = np
        if kcc_ ~= nil then
            kcc_:Warp(np)   -- 同步 KCC，防下一帧把玩家拉回超界旧位
        end
        print("[PlayerController] 边界钳制 -> " .. tostring(cx) .. ", " .. tostring(cz))
    end
end

--- 是否启用作近拾取/交互（仅当前流段为 explore 时 true，FlowController 进入段落时维护）
---@param enabled boolean
function PlayerController.SetPickupsEnabled(enabled)
    pickupsEnabled_ = enabled ~= false
    if not pickupsEnabled_ then
        inRadius_ = {}   -- 退出 explore 时清空进入半径记录
    end
end

--- 每帧更新：输入 → 规则（移动/视角）
---@param timeStep number
function PlayerController.Update(timeStep)
    if character_ == nil then return end

    -- 相机视角：触摸端由 GameHUD.EnableTouchLook 写 controls.yaw/pitch；PC 端鼠标增量叠加
    local mouseX, mouseY = InputManager.GetMouseDelta()
    if mouseX ~= 0 or mouseY ~= 0 then
        character_.controls.yaw = character_.controls.yaw + mouseX * MOUSE_SENSITIVITY
        character_.controls.pitch = Clamp(character_.controls.pitch + mouseY * MOUSE_SENSITIVITY,
            -PITCH_LIMIT, PITCH_LIMIT)
    end
    yaw_ = character_.controls.yaw
    pitch_ = character_.controls.pitch

    -- 移动：GameHUD 摇杆写入 controls（真机），键盘 WASD 作 PC 兜底
    local controls = character_.controls
    controls:Set(CTRL_FORWARD, controls:IsDown(CTRL_FORWARD) or InputManager.IsKeyDown(KEY_W) or InputManager.IsKeyDown(KEY_UP))
    controls:Set(CTRL_BACK,    controls:IsDown(CTRL_BACK) or InputManager.IsKeyDown(KEY_S) or InputManager.IsKeyDown(KEY_DOWN))
    controls:Set(CTRL_LEFT,    controls:IsDown(CTRL_LEFT) or InputManager.IsKeyDown(KEY_A) or InputManager.IsKeyDown(KEY_LEFT))
    controls:Set(CTRL_RIGHT,   controls:IsDown(CTRL_RIGHT) or InputManager.IsKeyDown(KEY_D) or InputManager.IsKeyDown(KEY_RIGHT))
    controls:Set(CTRL_RUN,     controls:IsDown(CTRL_RUN) or InputManager.IsKeyDown(KEY_LSHIFT) or InputManager.IsKeyDown(KEY_RSHIFT))

    -- 跳跃（空格兜底）
    if character_.onGround and InputManager.IsKeyPress(KEY_SPACE) then
        controls:Set(CTRL_JUMP, true)
    end

    -- 走近拾取/交互：真机 KCC 驱动不触发全局碰撞事件，故改用距离轮询识别 Blossom_/Int_ 标记。
    -- 仅当前流段为 explore 时启用（pickupsEnabled_，由 FlowController 维护）；且"进入半径"边沿触发（离开重置，防每帧刷屏/非 explore 不刷屏）。
    -- 标记/光柱的移除由 FlowController.OnBlossomCollected 在确认采集后执行（对话中不消费，节点保留）。
    if pickupsEnabled_ and blossomHandler_ ~= nil and scene_ ~= nil and playerNode_ ~= nil then
        local px, pz = playerNode_.worldPosition.x, playerNode_.worldPosition.z
        local children = scene_:GetChildren(true)
        for _, child in ipairs(children) do
            local key = string.match(child.name, "^Blossom_(%w+)$")
            if key == nil then
                key = string.match(child.name, "^Int_(%w+)$")
            end
            if key ~= nil then
                local wx, wz = child.worldPosition.x, child.worldPosition.z
                local dx, dz = wx - px, wz - pz
                local inR = (dx * dx + dz * dz <= PICKUP_RADIUS * PICKUP_RADIUS)
                if inR and not inRadius_[child] then
                    inRadius_[child] = true   -- 进入半径：边沿触发，只上报一次
                    print("[PlayerController] 拾取标记: " .. key)
                    blossomHandler_(key, child)
                elseif not inR then
                    inRadius_[child] = nil   -- 离开半径：重置，下次进入再上报
                end
            end
        end
    end
end

--- 对话/菜单打开时锁定移动（防摇杆在对话中串台移动角色）
function PlayerController.ClearMovement()
    if character_ == nil then return end
    local c = character_.controls
    c:Set(CTRL_FORWARD, false)
    c:Set(CTRL_BACK, false)
    c:Set(CTRL_LEFT, false)
    c:Set(CTRL_RIGHT, false)
    c:Set(CTRL_JUMP, false)
    c:Set(CTRL_RUN, false)
end

--- PostUpdate：更新第三人称相机 + 素女动画 FSM 参数
---@param timeStep number
function PlayerController.PostUpdate(timeStep)
    -- 边界硬钳制：物理步进后、相机更新前（相机跟随钳制后位置，防视角甩出界）
    ClampToBounds()
    if playerNode_ ~= nil and tpCamera_ ~= nil then
        tpCamera_:Update(timeStep, playerNode_, yaw_, pitch_)
    end
    -- 喂 FSM：实际速度按临时提速倍数归一化，对齐 BlendSpace 点（0 待机/2 走/5 跑）
    local speed = 0.0
    if character_ ~= nil then
        speed = character_:GetMoveSpeed() / DEBUG_MOVE_SPEED_MULTIPLIER
        if speed > 5.0 then speed = 5.0 end
    end
    if sunuFsm_ ~= nil and character_ ~= nil then
        sunuFsm_:SetFloat("moveSpeed", speed)
        sunuFsm_:SetBool("isGrounded", character_:IsOnGround())
    end

    -- ── 诊断②③ + 看门狗（手动兜底方案 D）────────────────────────────
    diagTime_ = diagTime_ + timeStep
    diagFrames_ = diagFrames_ + 1

    -- 诊断②（一次性，~1 秒后）：AnimatedModel 动画状态数 + 状态名/权重
    if not diagOneShot_ and diagTime_ >= 1.0 then
        diagOneShot_ = true
        local states = sunuModel_ ~= nil and sunuModel_:GetNumAnimationStates() or 0
        local curState = sunuFsm_ ~= nil and tostring(sunuFsm_:GetCurrentState(0)) or "无FSM"
        local stateTime = sunuFsm_ ~= nil and sunuFsm_:GetStateTime(0) or -1
        local w = -1.0
        local ctrl = sunuModel_ ~= nil and sunuModel_:GetNode():GetComponent("AnimationController") or nil
        if ctrl ~= nil and ctrl:GetNumAnimations() > 0 then
            local ac = ctrl:GetAnimation(0)
            if ac ~= nil then w = ctrl:GetWeight(ac.name) end
        end
        print(string.format("[诊断②] 动画状态=%d | FSM当前=%s stateTime=%.2f | 控制器动画数=%d 权重=%.2f",
            states, curState, stateTime,
            ctrl ~= nil and ctrl:GetNumAnimations() or 0, w))
    end

    -- 诊断③（周期 1 秒）：moveSpeed + FSM 状态/时间推进
    diag3Accum_ = diag3Accum_ + timeStep
    if diag3Accum_ >= 1.0 then
        diag3Accum_ = diag3Accum_ - 1.0
        if sunuFsm_ ~= nil and character_ ~= nil then
            print(string.format("[诊断③] moveSpeed=%.2f | 状态=%s stateTime=%.2f norm=%.2f | grounded=%s",
                speed, tostring(sunuFsm_:GetCurrentState(0)), sunuFsm_:GetStateTime(0),
                sunuFsm_:GetNormalizedTime(0), tostring(character_:IsOnGround())))
        elseif manualDriveActive_ then
            print(string.format("[诊断③] moveSpeed=%.2f | 手动兜底播放中 clip=%d", speed, manualClipIndex_))
        end
    end

    -- 看门狗（一次性，~3 秒后）：检查 AnimatedModel 是否有真正在播的动画状态。
    -- 判据：动画状态数 >= 1 且存在权重 > 0.1 的状态 = 有声播出；否则判定僵死 → 手动兜底接管。
    -- （FSM stateTime 会照常推进，不能当判据——旧事故就是"时间在走但骨头不动"）
    if not watchdogFired_ and diagTime_ >= 3.0 then
        watchdogFired_ = true
        if sunuModel_ ~= nil then
            local nStates = sunuModel_:GetNumAnimationStates()
            local maxW = 0.0
            local ctrl = sunuModel_:GetNode():GetComponent("AnimationController")
            if ctrl ~= nil then
                for i = 0, ctrl:GetNumAnimations() - 1 do
                    local ac = ctrl:GetAnimation(i)
                    if ac ~= nil then
                        local w = ctrl:GetWeight(ac.name)
                        if w > maxW then maxW = w end
                    end
                end
            end
            if nStates >= 1 and maxW > 0.1 then
                print(string.format("[诊断②] 看门狗：动画状态=%d 最大权重=%.2f → 正常，保留 FSM",
                    nStates, maxW))
            else
                print(string.format(
                    "[诊断②] 看门狗：动画状态=%d 最大权重=%.2f → 判定无声播出，切换手动兜底",
                    nStates, maxW))
                ActivateManualDrive()
            end
        end
    end

    -- 手动兜底驱动（激活后每帧按速度切动画）
    if manualDriveActive_ then
        ManualDriveTick(speed)
    end
end

--- 获取玩家节点（供流程/调试）
---@return Node|nil
function PlayerController.GetNode()
    return playerNode_
end

--- 全局碰撞回调：桃花收集
---@param eventType string
---@param eventData VariantMap
function PlayerController_HandleCollisionStart(eventType, eventData)
    if playerNode_ == nil then return end

    local nodeA = eventData["NodeA"]:GetPtr("Node")
    local nodeB = eventData["NodeB"]:GetPtr("Node")
    local isTrigger = eventData["Trigger"]:GetBool()
    if not isTrigger then return end

    -- 找"非玩家"的另一方
    local other = nil
    if nodeA == playerNode_ then
        other = nodeB
    elseif nodeB == playerNode_ then
        other = nodeA
    end
    if other == nil then return end

    -- 按节点名识别标记：Blossom_<key>（桃花收集）/ Int_<key>（交互点，如走近守桃老人）
    local key = string.match(other.name, "^Blossom_(%w+)$")
    if key == nil then
        key = string.match(other.name, "^Int_(%w+)$")
    end
    if key == nil then return end

    print("[PlayerController] 拾取标记: " .. key)
    other:Remove()

    if blossomHandler_ ~= nil then
        blossomHandler_(key, other)
    end
end

return PlayerController
