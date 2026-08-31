-- ============================================================================
-- game/Backdrop.lua
-- D 阶段 D1：三场景水墨远景 Skybox（全景图转 cubemap，postopaque 渲染不吃雾）
--
--   素材链：assets/textures/pano_*.png（21:9 水墨画水平镜像拼接）
--           → UrhoXCLI convert-panorama → skybox_*.dds（512/face + mips）
--   运行时：Skybox 组件 + DiffSkybox.xml（天空与雾解耦，远景不被雾染色）
--   回退：DDS 加载失败 → SkyUtils 渐变天空（按 mood 配色），保玩法不破
-- ============================================================================

local SkyUtils = require "urhox-libs.Rendering.SkyUtils"

local Backdrop = {}

--- 场景键 → cubemap 路径（assets/ 为资源根，路径从 textures/ 起）
local SKYBOX_MAP = {
    chaoyang_gukou  = "textures/skybox_chaoyang.dds",
    gu_nei_taolin   = "textures/skybox_taolin.dds",
    luoshui_yinshan = "textures/skybox_yinshan.dds",
}

--- 应用远景天空盒（场景切换时调用；节点挂在 scene 根，不随 SceneRoot 销毁）
---@param scene Scene
---@param sceneName string 场景键（见 SKYBOX_MAP）
---@param mood table|nil SCENE_MOOD 项（提供渐变回退配色 zenith/horizon）
---@return boolean 是否用上 cubemap（false = 回退渐变天空或未配置）
function Backdrop.Apply(scene, sceneName, mood)
    -- 移除旧天空节点（cubemap 节点名 SkyBackdrop / 渐变回退节点名 Sky）
    local old = scene:GetChild("SkyBackdrop", false)
    if old ~= nil then old:Remove() end
    old = scene:GetChild("Sky", false)
    if old ~= nil then old:Remove() end

    local path = SKYBOX_MAP[sceneName]
    if path == nil then
        print("[Backdrop] 场景未配置远景: " .. tostring(sceneName))
        return false
    end

    local tex = cache:GetResource("TextureCube", path)
    if tex == nil then
        print("[Backdrop] 警告：cubemap 加载失败，回退渐变天空: " .. path)
    else
        -- 注意：pano_*.png 已做 sRGB→线性预补偿（引擎按线性解读老式 DDS），
        -- 此处不能再 SetSRGB，否则双重解码变暗
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffSkybox.xml"))
        mat:SetTexture(TU_DIFFUSE, tex)
        mat:SetCullMode(CULL_NONE)
        local skyNode = scene:CreateChild("SkyBackdrop")
        -- 全景图水平镜像拼接的两个接缝在 panorama u=0/0.5，默认落在视野/正后方；
        -- 节点绕 Y 转 90° 把接缝甩到 ±X 两侧（水平 FOV 52° 视野外）
        skyNode:SetRotation(Quaternion(90, Vector3.UP))
        local skybox = skyNode:CreateComponent("Skybox")
        skybox:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        skybox:SetMaterial(mat)
        print("[Backdrop] 远景 Skybox 已加载: " .. path)
        return true
    end

    -- 回退：渐变天空（配色取自 mood， horizon 建议与雾色一致）
    if mood ~= nil and mood.skyZenith ~= nil and mood.skyHorizon ~= nil then
        SkyUtils.CreateGradientSky(scene, {
            zenith  = mood.skyZenith,
            horizon = mood.skyHorizon,
            skyExp  = 0.5,
        })
        print("[Backdrop] 渐变天空回退已创建: " .. tostring(sceneName))
    end
    return false
end

return Backdrop
