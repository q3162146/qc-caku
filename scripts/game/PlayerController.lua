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
--   使用官方 DefaultMale 原始 Bip001 动画，由引擎 RuntimeRetargeter 驱动）
local SUNU_RIG_MODEL = "model/3a5478a7-95aa-5840-a4c5-713c57214e20/Meshes/rig-1-a7be4e0a-6cd7-4e64-adc7-376f75cb5064.mdl"
local SUNU_RIG_MATERIAL = "model/3a5478a7-95aa-5840-a4c5-713c57214e20/Materials/rig-1-a7be4e0a-6cd7-4e64-adc7-376f75cb5064_00_tripo_material_a7ec7f07-66d8-4f3f-8f49-69d441544492.xml"
-- DWP 下载扩展保留给其他运行时资源；动画本身走本地官方资源。
require "urhox-libs.Engine.ResourceCacheExtensions"

-- FSM 引用的素女动画：使用官方原始 Bip001 .ani，由引擎 RuntimeRetargeter
-- 按 AnimationsMappings.json 自动映射到目标 Tripo 41 骨；不要替换成离线伪重定向产物。
local SUNU_ANIM_LOCAL = {
    "animation/DefaultMale_Idle.ani",         -- 官方站立待机
    "animation/DefaultMale_WalkForward.ani",  -- 官方向前行走
    "animation/DefaultMale_RunForward.ani",   -- 官方向前跑步
}
-- 旧静态素女（rig 模型加载失败时的回退视觉，保玩法不破）
local SUNU_MODEL = "model/57c4a9a5cfae45a89f9895d411d0fd40/Meshes/texture-2-9736947c-8d44-4e7a-b250-7183fdba3619.mdl"
local SUNU_MATERIAL = "model/57c4a9a5cfae45a89f9895d411d0fd40/Materials/texture-2-9736947c-8d44-4e7a-b250-7183fdba3619_00_tripo_node_cec0a95c-7f56-4e3e-94df-78c87bc56e1b_material.xml"
local SUNU_HEIGHT = 1.6          -- 目标身高（米），与胶囊 1.8 视觉匹配

---@type AnimationController|nil
local sunuController_ = nil
---@type AnimatedModel|nil 素女骨骼模型引用（诊断与状态查询用）
local sunuModel_ = nil

-- ── 动画诊断（官方原始 Bip001 .ani → 引擎 RuntimeRetargeter）────────────
---@type number
local diagTime_ = 0.0
---@type boolean
local diagOneShot_ = false
---@type number
local diag3Accum_ = 0.0
---@type table<string, boolean>
local diagReported_ = {}
---@type integer
local sunuAnimationIndex_ = 1
---@type Vector3
local prevPlayerPosition_ = Vector3.ZERO

--- 统计官方动画原始轨道；运行时由 RuntimeRetargeter 按 source/target 骨架映射，不以同名轨道数判断重定向结果。
---@param anim Animation
---@param skel Skeleton
---@return integer directTracks
---@return integer totalTracks
local function CountBoundTracks(anim, skel)
    local directTracks, totalTracks = 0, anim:GetNumTracks()
    for i = 0, totalTracks - 1 do
        local tr = anim:GetTrack(i)
        if tr ~= nil and skel:GetBone(tr.name) ~= nil then
            directTracks = directTracks + 1
        end
    end
    return directTracks, totalTracks
end

--- 使用官方原始动画，由引擎 RuntimeRetargeter 负责 Bip001 -> Tripo 41 骨映射。
---@param modelNode Node
local function StartSunuAnimation(modelNode)
    local controller = modelNode:GetOrCreateComponent("AnimationController")
    sunuController_ = controller
    controller:PlayExclusive(SUNU_ANIM_LOCAL[1], 0, true, 0.0)
    sunuAnimationIndex_ = 1
    print("[PlayerController] 素女动画控制器已启动（RuntimeRetargeter）: " .. SUNU_ANIM_LOCAL[1])
end

--- 按移动意图切换官方原始动画；GetMoveSpeed 在真机上可能不反映 KCC 实际移动。
---@param movingIntent boolean
---@param runningIntent boolean
local function UpdateSunuAnimation(movingIntent, runningIntent)
    if sunuController_ == nil then return end
    local index = 1
    if movingIntent then
        -- 移动动画优先由摇杆/WASD 意图决定，避免真机 GetMoveSpeed=0 时穿 Idle。
        index = runningIntent and 3 or 2
    end
    local path = SUNU_ANIM_LOCAL[index]
    if path ~= nil and index ~= sunuAnimationIndex_ then
        sunuAnimationIndex_ = index
        sunuController_:PlayExclusive(path, 0, true, 0.2)
        if not diagReported_[path] then
            diagReported_[path] = true
            print("[诊断②] 控制器切换 -> " .. path .. " weight=" .. string.format("%.2f", sunuController_:GetWeight(path)))
        end
    end
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
    prevPlayerPosition_ = playerNode_.worldPosition

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
        -- 节点前向 +Z 与网格前向一致：autoRotateToMoveDir=true 时脸朝移动方向，第三人称相机看到背影
        modelNode:SetRotation(Quaternion(0, Vector3.UP))
        -- 重定向防飘移：禁用 Root/Hip（3D 角色管线标准做法）
        local skel = bodyModel:GetSkeleton()
        if skel ~= nil then
            local rootBone = skel:GetBone("Root")
            if rootBone ~= nil then rootBone.animated = false end
            local hipBone = skel:GetBone("Hip")
            if hipBone ~= nil then hipBone.animated = false end
        end
        -- 诊断①：确认 AnimatedModel、目标骨骼和官方 RuntimeRetargeter 输入资源
        print(string.format("[诊断①] 模型=AnimatedModel 骨骼数=%d rig=%s retarget=RuntimeRetargeter",
            skel ~= nil and skel:GetNumBones() or -1, SUNU_RIG_MODEL))
        if skel ~= nil then
            for _, path in ipairs(SUNU_ANIM_LOCAL) do
                ---@type Animation|nil
                local anim = cache:GetResource("Animation", path)
                if anim == nil then
                    print("[诊断④] 官方动画缺失 -> " .. path)
                else
                    local direct, total = CountBoundTracks(anim, skel)
                    print(string.format("[诊断④] 官方轨道直连 %d/%d（其余由 RuntimeRetargeter 映射） (%s) len=%.2fs",
                        direct, total, path, anim:GetLength()))
                end
            end
        end
        StartSunuAnimation(modelNode)
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
        prevPlayerPosition_ = playerNode_.worldPosition
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
    -- 计算实际节点位移速度：CharacterComponent:GetMoveSpeed() 在真机 KCC 路径上可能始终为 0。
    -- 以物理步进后节点的位置为准，动画再结合 controls 的移动意图判定。
    local actualSpeed = 0.0
    local movingIntent = false
    local runningIntent = false
    -- 先读取输入意图，再结合实际位移速度驱动动画。
    if playerNode_ ~= nil then
        local currentPosition = playerNode_.worldPosition
        if timeStep > 0.0 then
            actualSpeed = (currentPosition - prevPlayerPosition_):Length() / timeStep
        end
        prevPlayerPosition_ = currentPosition
    end
    if character_ ~= nil then
        local controls = character_.controls
        movingIntent = controls:IsDown(CTRL_FORWARD)
            or controls:IsDown(CTRL_BACK)
            or controls:IsDown(CTRL_LEFT)
            or controls:IsDown(CTRL_RIGHT)
        runningIntent = movingIntent and controls:IsDown(CTRL_RUN)
    end
    UpdateSunuAnimation(actualSpeed, movingIntent, runningIntent)

    -- 诊断②：读取 AnimationController 实际动画状态权重和时间，不读取不存在的 FSM 状态。
    diagTime_ = diagTime_ + timeStep
    if not diagOneShot_ and diagTime_ >= 1.0 then
        diagOneShot_ = true
        local animationCount = sunuController_ ~= nil and sunuController_:GetNumAnimations() or 0
        local activeName = "无"
        local activeWeight = 0.0
        local activeTime = 0.0
        if sunuController_ ~= nil then
            for i = 0, animationCount - 1 do
                local control = sunuController_:GetAnimation(i)
                if control ~= nil then
                    local weight = sunuController_:GetWeight(control.name)
                    if weight > activeWeight then
                        activeWeight = weight
                        activeName = control.name
                        activeTime = sunuController_:GetTime(control.name)
                    end
                end
            end
        end
        print(string.format("[诊断②] AnimatedModel状态=%d | 当前=%s weight=%.2f time=%.2f | 驱动=AnimationController",
            sunuModel_ ~= nil and sunuModel_:GetNumAnimationStates() or 0,
            activeName, activeWeight, activeTime))
    end

    -- 诊断③：周期性回传移动速度和当前动画。
    diag3Accum_ = diag3Accum_ + timeStep
    if diag3Accum_ >= 1.0 then
        diag3Accum_ = diag3Accum_ - 1.0
        local currentAnimation = "无"
        if sunuController_ ~= nil and sunuController_:GetNumAnimations() > 0 then
            local currentControl = sunuController_:GetAnimation(0)
            if currentControl ~= nil then currentAnimation = currentControl.name end
        end
        print(string.format("[诊断③] moveSpeed=%.2f | 意图=%s 跑步=%s | 当前动画=%s | grounded=%s",
            actualSpeed, tostring(movingIntent), tostring(runningIntent), currentAnimation,
            character_ ~= nil and tostring(character_:IsOnGround()) or "false"))
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
