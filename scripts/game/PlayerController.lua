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
---@type ThirdPersonCameraInstance|nil
local tpCamera_ = nil
---@type number
local yaw_ = 0
---@type number
local pitch_ = 0
---@type function|nil
local blossomHandler_ = nil

local MOUSE_SENSITIVITY = 0.15   -- 鼠标灵敏度（度/像素）
local PITCH_LIMIT = 80.0
local PICKUP_RADIUS = 1.1        -- 走近拾取/交互半径（米）

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

    -- 视觉：球体身体（白模，后续换正式模型）
    -- R12（2026-08-22）：视觉球体缩小（胶囊 0.7×1.8 仅作碰撞，视觉约 1.2m 高），
    --   修复真机复核「玩家占屏 1/4~1/3、遮挡无涕桃与前进路线」
    local modelNode = playerNode_:CreateChild("ModelNode")
    local bodyModel = modelNode:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    bodyModel:SetMaterial(WhiteBoxCreatePlayerMaterial())
    bodyModel.castShadows = true
    modelNode.scale = Vector3(0.45, 0.6, 0.45)
    modelNode.position = Vector3(0, 0.65, 0)

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

    -- 角色组件（只处理物理移动）
    character_ = playerNode_:CreateComponent("CharacterComponent")
    character_:SetAirControlFactor(0.6)
    character_:SetEnableWalkMode(true)      -- 默认步行，Shift 跑步
    character_.autoRotateToMoveDir = true   -- 探索模式：面向移动方向
    character_.rotationSpeed = 1440.0

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

    -- 鼠标相对模式（视角控制）
    InputManager.SetRelativeMouseMode()

    -- 真机触屏控制（GameHUD）：虚拟摇杆(移动) + 触摸视角；PC 端摇杆 keyBinding=WASD + 鼠标视角
    -- 平台默认屏上摇杆在 InputManager.Initialize 时已启（main.lua 已关，避免与 GameHUD 双摇杆）
    GameHUD.Initialize()
    GameHUD.SetControls(character_.controls)
    GameHUD.Create({ enableJump = true, enableRun = true })
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
        playerNode_.position = Vector3(position.x, 0.6, position.z)
    end
end

--- 注册桃花收集回调（FlowController 注入）
---@param handler function|nil function(key: string, node: Node)
function PlayerController.SetBlossomHandler(handler)
    blossomHandler_ = handler
end

--- 每帧更新：输入 → 规则（移动/视角）
---@param timeStep number
function PlayerController.Update(timeStep)
    if character_ == nil then return end

    -- 相机视角：触摸端由 GameHUD.EnableTouchLook 写 controls.yaw/pitch；PC 端鼠标增量叠加（移动端鼠标增量恒 0，不干扰）
    local mouseX, mouseY = InputManager.GetMouseDelta()
    if mouseX ~= 0 or mouseY ~= 0 then
        character_.controls.yaw = character_.controls.yaw + mouseX * MOUSE_SENSITIVITY
        character_.controls.pitch = Clamp(character_.controls.pitch + mouseY * MOUSE_SENSITIVITY,
            -PITCH_LIMIT, PITCH_LIMIT)
    end
    yaw_ = character_.controls.yaw
    pitch_ = character_.controls.pitch

    -- 移动：GameHUD 摇杆写入 controls（真机），键盘 WASD 作 PC 兜底（OR 叠加，不覆盖摇杆值）
    local controls = character_.controls
    controls:Set(CTRL_FORWARD, controls:IsDown(CTRL_FORWARD) or InputManager.IsKeyDown(KEY_W) or InputManager.IsKeyDown(KEY_UP))
    controls:Set(CTRL_BACK,    controls:IsDown(CTRL_BACK) or InputManager.IsKeyDown(KEY_S) or InputManager.IsKeyDown(KEY_DOWN))
    controls:Set(CTRL_LEFT,    controls:IsDown(CTRL_LEFT) or InputManager.IsKeyDown(KEY_A) or InputManager.IsKeyDown(KEY_LEFT))
    controls:Set(CTRL_RIGHT,   controls:IsDown(CTRL_RIGHT) or InputManager.IsKeyDown(KEY_D) or InputManager.IsKeyDown(KEY_RIGHT))
    controls:Set(CTRL_RUN,     controls:IsDown(CTRL_RUN) or InputManager.IsKeyDown(KEY_LSHIFT) or InputManager.IsKeyDown(KEY_RSHIFT))

    -- 跳跃（空格兜底；GameHUD 跳跃按钮也设 CTRL_JUMP）
    if character_.onGround and InputManager.IsKeyPress(KEY_SPACE) then
        controls:Set(CTRL_JUMP, true)
    end

    -- 走近拾取/交互：真机 KCC 驱动不触发全局碰撞事件，故改用距离轮询识别 Blossom_/Int_ 标记。
    if blossomHandler_ ~= nil and scene_ ~= nil and playerNode_ ~= nil then
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
                if dx * dx + dz * dz <= PICKUP_RADIUS * PICKUP_RADIUS then
                    print("[PlayerController] 拾取标记: " .. key)
                    local beacon = scene_:GetChild("Beacon_" .. key, true)
                    if beacon ~= nil then beacon:Remove() end
                    child:Remove()
                    blossomHandler_(key, child)
                    break   -- 一次只收一个（防对话中连续触发）
                end
            end
        end
    end
end

--- 对话/菜单打开时锁定移动（防 GameHUD 摇杆在对话中串台移动角色）
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

--- PostUpdate：更新第三人称相机
---@param timeStep number
function PlayerController.PostUpdate(timeStep)
    if playerNode_ ~= nil and tpCamera_ ~= nil then
        tpCamera_:Update(timeStep, playerNode_, yaw_, pitch_)
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
