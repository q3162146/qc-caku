-- ====================================================================
-- world/ChunkMeshBuilder.lua
-- 区块网格构建器 - 生成区块的可视网格（优化版）
-- 使用高度范围优化，只遍历有方块的高度层
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local TexturePackManager = require("rendering.texturepacks.TexturePackManager")
local TempPool = require("utils.TempPool")

-- 常量本地化（热路径优化）
local CHUNK_SIZE = Config.World.CHUNK_SIZE
local WORLD_HEIGHT = Config.World.WORLD_HEIGHT
local BLOCK_SIZE = Config.World.BLOCK_SIZE
local AIR = Blocks.AIR
local WATER = Blocks.WATER

-- 函数本地化
local pairs = pairs
local floor = math.floor
local tempVec3 = TempPool.tempVec3
local tempVec2 = TempPool.tempVec2

-- 预计算 crossMesh 查找表（避免循环中调用 Blocks:isCrossMesh）
local crossMeshLUT = {}
for id, block in pairs(Blocks.blocks) do
    crossMeshLUT[id] = block.crossMesh or false
end

-- 本地化 Blocks.blocks 用于快速查找
local BlocksData = Blocks.blocks

-- UV 缓存（在 refreshTexturePack 时重建）
-- uvCache[blockType][faceType] = { u0, v0, u1, v1 }
local uvCache = {}
local uvCacheBuilt = false

---@class ChunkMeshBuilder
---@field world World
---@field scene Scene
---@field chunkMaterial Material
---@field waterMaterial Material
---@field crossMeshMaterial Material
---@field textures table
local ChunkMeshBuilder = {}
ChunkMeshBuilder.__index = ChunkMeshBuilder

-- 预分配的颜色常量（避免在循环中创建）
local COLOR_WHITE = Color(1, 1, 1, 1)
local COLOR_WATER = Color(1, 1, 1, 0.7)

-- 立方体面定义（包含切线用于 PBR 法线贴图）
-- tangent.w = 1 表示副切线方向（bitangent = cross(normal, tangent) * tangent.w）
local CUBE_FACES = {
    -- +X 面 (右) - side 纹理
    { normal = Vector3(1, 0, 0), tangent = Vector4(0, 0, -1, 1), faceType = "side", check = {1, 0, 0}, vertices = {
        { pos = { 1, 0, 0 }, uv = { 1, 1 } },
        { pos = { 1, 1, 0 }, uv = { 1, 0 } },
        { pos = { 1, 1, 1 }, uv = { 0, 0 } },
        { pos = { 1, 0, 0 }, uv = { 1, 1 } },
        { pos = { 1, 1, 1 }, uv = { 0, 0 } },
        { pos = { 1, 0, 1 }, uv = { 0, 1 } }
    }},
    -- -X 面 (左)
    { normal = Vector3(-1, 0, 0), tangent = Vector4(0, 0, 1, 1), faceType = "side", check = {-1, 0, 0}, vertices = {
        { pos = { 0, 0, 1 }, uv = { 1, 1 } },
        { pos = { 0, 1, 1 }, uv = { 1, 0 } },
        { pos = { 0, 1, 0 }, uv = { 0, 0 } },
        { pos = { 0, 0, 1 }, uv = { 1, 1 } },
        { pos = { 0, 1, 0 }, uv = { 0, 0 } },
        { pos = { 0, 0, 0 }, uv = { 0, 1 } }
    }},
    -- +Y 面 (顶) - top 纹理
    { normal = Vector3(0, 1, 0), tangent = Vector4(1, 0, 0, 1), faceType = "top", check = {0, 1, 0}, vertices = {
        { pos = { 0, 1, 0 }, uv = { 0, 0 } },
        { pos = { 0, 1, 1 }, uv = { 0, 1 } },
        { pos = { 1, 1, 1 }, uv = { 1, 1 } },
        { pos = { 0, 1, 0 }, uv = { 0, 0 } },
        { pos = { 1, 1, 1 }, uv = { 1, 1 } },
        { pos = { 1, 1, 0 }, uv = { 1, 0 } }
    }},
    -- -Y 面 (底) - bottom 纹理
    { normal = Vector3(0, -1, 0), tangent = Vector4(1, 0, 0, 1), faceType = "bottom", check = {0, -1, 0}, vertices = {
        { pos = { 0, 0, 1 }, uv = { 0, 1 } },
        { pos = { 0, 0, 0 }, uv = { 0, 0 } },
        { pos = { 1, 0, 0 }, uv = { 1, 0 } },
        { pos = { 0, 0, 1 }, uv = { 0, 1 } },
        { pos = { 1, 0, 0 }, uv = { 1, 0 } },
        { pos = { 1, 0, 1 }, uv = { 1, 1 } }
    }},
    -- +Z 面 (前)
    { normal = Vector3(0, 0, 1), tangent = Vector4(1, 0, 0, 1), faceType = "side", check = {0, 0, 1}, vertices = {
        { pos = { 0, 0, 1 }, uv = { 0, 1 } },
        { pos = { 1, 0, 1 }, uv = { 1, 1 } },
        { pos = { 1, 1, 1 }, uv = { 1, 0 } },
        { pos = { 0, 0, 1 }, uv = { 0, 1 } },
        { pos = { 1, 1, 1 }, uv = { 1, 0 } },
        { pos = { 0, 1, 1 }, uv = { 0, 0 } }
    }},
    -- -Z 面 (后)
    { normal = Vector3(0, 0, -1), tangent = Vector4(-1, 0, 0, 1), faceType = "side", check = {0, 0, -1}, vertices = {
        { pos = { 1, 0, 0 }, uv = { 0, 1 } },
        { pos = { 0, 0, 0 }, uv = { 1, 1 } },
        { pos = { 0, 1, 0 }, uv = { 1, 0 } },
        { pos = { 1, 0, 0 }, uv = { 0, 1 } },
        { pos = { 0, 1, 0 }, uv = { 1, 0 } },
        { pos = { 1, 1, 0 }, uv = { 0, 0 } }
    }}
}

-- 交叉网格面定义（X形，用于装饰草等）
-- 两个对角交叉的面片，材质使用 CULL_NONE 实现双面渲染
-- 只需要2个面，不需要正反面（避免 Z-fighting 闪烁）
local CROSS_HEIGHT = 0.7 -- 草/花的高度

-- 正确的交叉网格：两个面从方块对角穿过，在中心 (0.5, y, 0.5) 相交
local CROSS_MESH_FACES = {
    -- 对角面1 (从 (0,0) 到 (1,1)) - 穿过方块中心
    { normal = Vector3(0.707, 0, 0.707), tangent = Vector4(0.707, 0, -0.707, 1), faceType = "side", vertices = {
        { pos = { 0, 0, 0 }, uv = { 0, 1 } },
        { pos = { 1, 0, 1 }, uv = { 1, 1 } },
        { pos = { 1, CROSS_HEIGHT, 1 }, uv = { 1, 0 } },
        { pos = { 0, 0, 0 }, uv = { 0, 1 } },
        { pos = { 1, CROSS_HEIGHT, 1 }, uv = { 1, 0 } },
        { pos = { 0, CROSS_HEIGHT, 0 }, uv = { 0, 0 } }
    }},
    -- 对角面2 (从 (1,0) 到 (0,1)) - 与面1在中心相交
    { normal = Vector3(0.707, 0, -0.707), tangent = Vector4(0.707, 0, 0.707, 1), faceType = "side", vertices = {
        { pos = { 1, 0, 0 }, uv = { 0, 1 } },
        { pos = { 0, 0, 1 }, uv = { 1, 1 } },
        { pos = { 0, CROSS_HEIGHT, 1 }, uv = { 1, 0 } },
        { pos = { 1, 0, 0 }, uv = { 0, 1 } },
        { pos = { 0, CROSS_HEIGHT, 1 }, uv = { 1, 0 } },
        { pos = { 1, CROSS_HEIGHT, 0 }, uv = { 0, 0 } }
    }}
}

-- 预计算数组长度（避免循环中重复计算）
local CUBE_FACES_COUNT = #CUBE_FACES
local CROSS_MESH_FACES_COUNT = #CROSS_MESH_FACES
local VERTICES_PER_FACE = 6  -- 每个面固定 6 个顶点

-- ====================================================================
-- 顶点环境光遮蔽 (Ambient Occlusion)
-- 经典 Minecraft 风格：每个面的角顶点按"面外一层"相邻 3 个方块（2 边 + 1 对角）
-- 的遮挡算 0-3 档，烘焙进顶点色。LitSolid.glsl 中顶点色乘 albedo，故同时调制
-- 环境光与直射光。不增加顶点数 / draw call，纯改顶点色。
-- ====================================================================
local AO_ENABLED = true

-- AO 档位 → 亮度系数（留最低值，避免凹角纯黑）。0=完全夹角最暗，3=无遮挡
local AO_COLORS = {
    [0] = Color(0.25, 0.25, 0.25, 1),
    [1] = Color(0.50, 0.50, 0.50, 1),
    [2] = Color(0.75, 0.75, 0.75, 1),
    [3] = Color(1.00, 1.00, 1.00, 1),
}

-- 为每个立方体面预计算 AO 采样轴：面内两个切向轴的单位偏移 {dx,dy,dz} 及其在 pos 中的分量下标(1=x,2=y,3=z)
for _, face in ipairs(CUBE_FACES) do
    local c = face.check
    if c[1] ~= 0 then          -- 法线沿 X → 切向 Y,Z
        face.aoTanA = { 0, 1, 0 }; face.aoAxisA = 2
        face.aoTanB = { 0, 0, 1 }; face.aoAxisB = 3
    elseif c[2] ~= 0 then      -- 法线沿 Y → 切向 X,Z
        face.aoTanA = { 1, 0, 0 }; face.aoAxisA = 1
        face.aoTanB = { 0, 0, 1 }; face.aoAxisB = 3
    else                       -- 法线沿 Z → 切向 X,Y
        face.aoTanA = { 1, 0, 0 }; face.aoAxisA = 1
        face.aoTanB = { 0, 1, 0 }; face.aoAxisB = 2
    end
end

-- 每个面 6 顶点 AO 颜色的复用缓冲（避免每面分配 table；单线程顺序消费，安全）
local _aoColorBuf = { COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE }

local CHUNK_SIZE_M1_AO = CHUNK_SIZE - 1

---采样 (lx,lz,y) 处方块类型，封装跨 chunk 边界寻址（替代各处内联 seam 逻辑）。
---lx/lz 可越界 -1..CHUNK_SIZE：单边界访问邻接 chunk；对角同时越界则近似为 AIR（不预加载对角 chunk）。
---@return number blockType
local function sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, lx, lz, y)
    if y < 0 or y >= WORLD_HEIGHT then return AIR end
    local xOut = (lx < 0) and -1 or ((lx > CHUNK_SIZE_M1_AO) and 1 or 0)
    local zOut = (lz < 0) and -1 or ((lz > CHUNK_SIZE_M1_AO) and 1 or 0)
    if xOut ~= 0 and zOut ~= 0 then
        return AIR  -- 对角跨界：近似不遮挡（边界角 AO 的可接受误差）
    elseif xOut < 0 then
        return blocksNX and (blocksNX[y * 256 + lz * 16 + CHUNK_SIZE_M1_AO] or AIR) or AIR
    elseif xOut > 0 then
        return blocksPX and (blocksPX[y * 256 + lz * 16] or AIR) or AIR
    elseif zOut < 0 then
        return blocksNZ and (blocksNZ[y * 256 + CHUNK_SIZE_M1_AO * 16 + lx] or AIR) or AIR
    elseif zOut > 0 then
        return blocksPZ and (blocksPZ[y * 256 + lx] or AIR) or AIR
    else
        return blocks[y * 256 + lz * 16 + lx] or AIR
    end
end

---方块是否构成 AO 遮挡（不透明固体；空气/水/交叉网格草不遮挡）
local function isAOOccluder(blockType)
    return blockType ~= AIR and blockType ~= WATER and not crossMeshLUT[blockType]
end

---经典顶点 AO：s1/s2=两条边邻居遮挡，cnr=对角邻居遮挡 → 0(最暗)..3(无遮挡)
local function vertexAOLevel(s1, s2, cnr)
    if s1 and s2 then return 0 end
    return 3 - ((s1 and 1 or 0) + (s2 and 1 or 0) + (cnr and 1 or 0))
end

---计算一个 solid 面 6 个顶点的 AO 颜色，填入复用缓冲并返回。两条 build 路径共用，避免逻辑分叉。
---优化：面外一层的 8 个邻居（4 边 + 4 角）只采样一次，各角复用 —— 与逐顶点采样 bit 等价，采样 18→8。
local function computeFaceAO(face, lx, lz, y, blocks, blocksNX, blocksPX, blocksNZ, blocksPZ)
    local c = face.check
    local cx, cy, cz = lx + c[1], y + c[2], lz + c[3]   -- 面外一层中心（正对面的那一格，恒为空气）
    local tA, tB = face.aoTanA, face.aoTanB
    local axisA, axisB = face.aoAxisA, face.aoAxisB
    -- 8 邻居遮挡（沿切向 A/B 的 +/-）；注意 sampleBlock 形参顺序为 (.., lx, lz, y)
    local eAp = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx + tA[1], cz + tA[3], cy + tA[2]))
    local eAn = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx - tA[1], cz - tA[3], cy - tA[2]))
    local eBp = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx + tB[1], cz + tB[3], cy + tB[2]))
    local eBn = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx - tB[1], cz - tB[3], cy - tB[2]))
    local cPP = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx + tA[1] + tB[1], cz + tA[3] + tB[3], cy + tA[2] + tB[2]))
    local cPN = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx + tA[1] - tB[1], cz + tA[3] - tB[3], cy + tA[2] - tB[2]))
    local cNP = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx - tA[1] + tB[1], cz - tA[3] + tB[3], cy - tA[2] + tB[2]))
    local cNN = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx - tA[1] - tB[1], cz - tA[3] - tB[3], cy - tA[2] - tB[2]))
    local vertices = face.vertices
    for vi = 1, VERTICES_PER_FACE do
        local vpos = vertices[vi].pos
        -- 用 if/else 直接选（邻居是 boolean，不能用 and/or 三元，否则 false 邻居会被误判）
        local s1, s2, cnr
        if vpos[axisA] == 1 then
            s1 = eAp
            if vpos[axisB] == 1 then s2 = eBp; cnr = cPP else s2 = eBn; cnr = cPN end
        else
            s1 = eAn
            if vpos[axisB] == 1 then s2 = eBp; cnr = cNP else s2 = eBn; cnr = cNN end
        end
        _aoColorBuf[vi] = AO_COLORS[vertexAOLevel(s1, s2, cnr)]
    end
    return _aoColorBuf
end

---发射一个 solid 面（6 顶点，含 AO 顶点色），返回新增顶点数。
---F1：sync(buildChunk) / async(buildChunkRows) 两条路径共用同一发射逻辑，
---后续 Phase B 接入光照只需改这一处，消除双副本分叉风险。
-- L2 光照：最低环境光系数，防止凹处/地下全黑（无昼夜时白天 sky=15→shade=1，地下 sky=0→MIN_AMBIENT）
local MIN_AMBIENT = 0.05

local function emitSolidFace(geometry, face, worldBaseX, worldBaseY, worldBaseZ,
                            blockType, lx, lz, y, blocks, blocksNX, blocksPX, blocksNZ, blocksPZ,
                            world, startX, startZ)
    local uv = uvCache[blockType][face.faceType]
    local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
    local vertices = face.vertices
    local faceNormal = face.normal
    local faceTangent = face.tangent
    -- 顶点 AO：按相邻方块算每个角的遮挡，烘焙进顶点色
    local aoCols = AO_ENABLED
        and computeFaceAO(face, lx, lz, y, blocks, blocksNX, blocksPX, blocksNZ, blocksPZ)
        or nil
    -- L2 光照：取面外一层格的 skyLight/blockLight 作面级亮度（avg4 平滑留待后续）
    local c = face.check
    local nbx, nby, nbz = startX + lx + c[1], y + c[2], startZ + lz + c[3]
    local lv = world:getSkyLight(nbx, nby, nbz) * (world.sunFactor or 1)  -- L5: 天光随昼夜缩放
    local bl = world:getBlockLight(nbx, nby, nbz)                         -- 方块光(火把)不随昼夜
    if bl > lv then lv = bl end                 -- max(sky×sun, block)
    if lv > 15 then lv = 15 end                 -- sunFactor>1 时钳制，防顶点色分量溢出/过曝
    local shade = lv / 15
    if shade < MIN_AMBIENT then shade = MIN_AMBIENT end
    -- 无 AO 时预算一个 shaded white 常量，避免顶点循环内每顶点分配 Color
    -- （AO 开启时各顶点档色不同，无法预算，仍需逐顶点构造）
    local shadedWhite = (not aoCols) and Color(shade, shade, shade, 1) or nil
    for vi = 1, VERTICES_PER_FACE do
        local v = vertices[vi]
        local vpos, vuv = v.pos, v.uv
        geometry:DefineVertex(tempVec3(
            worldBaseX + vpos[1] * BLOCK_SIZE,
            worldBaseY + vpos[2] * BLOCK_SIZE,
            worldBaseZ + vpos[3] * BLOCK_SIZE
        ))
        geometry:DefineNormal(faceNormal)
        geometry:DefineTangent(faceTangent)
        geometry:DefineTexCoord(tempVec2(
            u0 + vuv[1] * (u1 - u0),
            v0 + vuv[2] * (v1 - v0)
        ))
        -- AO 档色 × 光照 shade（合流：LitSolid 顶点色乘 albedo，等价同时调制环境光+直射光）
        if aoCols then
            local ao = aoCols[vi]
            geometry:DefineColor(Color(ao.r * shade, ao.g * shade, ao.b * shade, 1))
        else
            geometry:DefineColor(shadedWhite)
        end
    end
    return VERTICES_PER_FACE
end

---创建区块网格构建器
---@param world table World实例
---@param scene Node 场景节点
---@return table ChunkMeshBuilder实例
function ChunkMeshBuilder.new(world, scene)
    local self = setmetatable({}, ChunkMeshBuilder)
    self.world = world
    self.scene = scene
    self.chunkMaterial = nil
    self.waterMaterial = nil
    self.crossMeshMaterial = nil  -- 交叉网格材质（支持透明）
    self.textures = nil  -- { diffuse, normal, specular }
    return self
end

---获取纹理图集UV坐标（从当前材质包获取）
---@param row number 行
---@param col number 列
---@return number u0
---@return number v0
---@return number u1
---@return number v1
function ChunkMeshBuilder:getTileUV(row, col)
    return TexturePackManager:getCurrent():getTileUV(row, col)
end

---获取方块面的UV坐标
---@param blockType number 方块类型
---@param faceType string 面类型 ("top", "side", "bottom")
---@return number u0
---@return number v0
---@return number u1
---@return number v1
function ChunkMeshBuilder:getBlockFaceUV(blockType, faceType)
    local block = Blocks:get(blockType)
    if not block or not block.textures then
        return self:getTileUV(0, 2)  -- 默认泥土纹理
    end

    local tilePos = block.textures[faceType] or block.textures.side
    return self:getTileUV(tilePos[1], tilePos[2])
end

---构建 UV 缓存（材质包加载后调用一次）
function ChunkMeshBuilder:buildUVCache()
    uvCache = {}
    local faceTypes = { "top", "side", "bottom" }

    for id, block in pairs(Blocks.blocks) do
        uvCache[id] = {}
        for _, faceType in ipairs(faceTypes) do
            local u0, v0, u1, v1 = self:getBlockFaceUV(id, faceType)
            uvCache[id][faceType] = { u0, v0, u1, v1 }
        end
    end

    uvCacheBuilt = true
    print("[ChunkMeshBuilder] UV cache built for " .. #Blocks.blocks .. " block types")
end

---从缓存获取 UV（快速路径）
---@param blockType number 方块类型
---@param faceType string 面类型
---@return number u0
---@return number v0
---@return number u1
---@return number v1
function ChunkMeshBuilder:getCachedUV(blockType, faceType)
    local blockUV = uvCache[blockType]
    if blockUV then
        local uv = blockUV[faceType]
        if uv then
            return uv[1], uv[2], uv[3], uv[4]
        end
    end
    -- 回退到原始方法
    return self:getBlockFaceUV(blockType, faceType)
end

---设置贴图集合
---@param textures table { diffuse: Texture2D, normal: Texture2D|nil, specular: Texture2D|nil }
function ChunkMeshBuilder:setTextures(textures)
    self.textures = textures
end

---获取或创建区块材质
---@return Material 区块材质
function ChunkMeshBuilder:getChunkMaterial()
    if self.chunkMaterial then
        return self.chunkMaterial
    end
    
    self.chunkMaterial = Material:new()
    
    -- 根据是否有 normal 贴图选择 technique
    local isPBR = self.textures and self.textures.normal
    local techniquePath = isPBR 
        and "Techniques/PBR/PBRMetallicRoughDiffNormalSpecVCol.xml"
        or "Techniques/DiffVCol.xml"
    
    local technique = cache:GetResource("Technique", techniquePath)
    if not technique then
        technique = cache:GetResource("Technique", "Techniques/Diff.xml")
    end
    self.chunkMaterial:SetTechnique(0, technique)
    
    -- 绑定贴图
    if self.textures then
        self.chunkMaterial:SetTexture(TU_DIFFUSE, self.textures.diffuse)
        if isPBR then
            self.chunkMaterial:SetTexture(TU_NORMAL, self.textures.normal)
            self.chunkMaterial:SetTexture(TU_SPECULAR, self.textures.specular)
        end
    end
    
    -- 基础颜色
    self.chunkMaterial:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    
    -- PBR 参数
    if isPBR then
        self.chunkMaterial:SetShaderParameter("MatSpecColor", Variant(Color(1, 1, 1, 1)))
        -- 注意：METALLIC technique 下 roughness/metallic 取自 specular 纹理 × TextureRoughness/MetallicFactor，
        --       Roughness/Metallic 这两个材质参数（cRoughness/cMetallic）走的是 #else 死分支，从不被读取
    end
    
    return self.chunkMaterial
end

---获取或创建水材质
---@return Material 水材质
function ChunkMeshBuilder:getWaterMaterial()
    if self.waterMaterial then
        return self.waterMaterial
    end
    
    local sharedWater = cache:GetResource("Material", "Materials/SingleLayerWater.xml")
    if not sharedWater then
        self.waterMaterial = Material:new()
        local technique = cache:GetResource("Technique", "Techniques/DiffAlpha.xml")
        self.waterMaterial:SetTechnique(0, technique)
        self.waterMaterial:SetShaderParameter("MatDiffColor", Variant(Color(0.0, 0.6, 1.0)))
    else
        -- Clone 后再改：cache:GetResource 返回的是共享实例，原地 mutate 会污染所有用到该材质的对象
        self.waterMaterial = sharedWater:Clone()
        self.waterMaterial:SetShaderParameter("WaterTint", Variant(Blocks:getColor(WATER)))
    end
    
    return self.waterMaterial
end

---获取或创建交叉网格材质（支持透明度 + PBR）
---@return Material 交叉网格材质
function ChunkMeshBuilder:getCrossMeshMaterial()
    if self.crossMeshMaterial then
        return self.crossMeshMaterial
    end
    
    self.crossMeshMaterial = Material:new()
    
    -- 根据是否有 normal 贴图选择 PBR 或普通技术
    -- 使用带 VCol + AlphaMask 的 technique，确保：
    -- 1. 有完整的渲染 pass（base, light 等）
    -- 2. 支持 alpha test（裁剪透明像素）
    local isPBR = self.textures and self.textures.normal
    local techniquePath = isPBR
        and "Techniques/PBR/PBRMetallicRoughDiffNormalSpecVColMask.xml"  -- PBR + VCol + AlphaMask
        or "Techniques/DiffVColAlphaMask.xml"
    
    local technique = cache:GetResource("Technique", techniquePath)
    if not technique then
        technique = cache:GetResource("Technique", "Techniques/DiffVCol.xml")
    end
    self.crossMeshMaterial:SetTechnique(0, technique)
    
    -- 绑定贴图
    if self.textures then
        self.crossMeshMaterial:SetTexture(TU_DIFFUSE, self.textures.diffuse)
        if isPBR then
            self.crossMeshMaterial:SetTexture(TU_NORMAL, self.textures.normal)
            self.crossMeshMaterial:SetTexture(TU_SPECULAR, self.textures.specular)
        end
    end
    
    -- 禁用背面剔除（双面渲染）
    self.crossMeshMaterial:SetCullMode(CULL_NONE)
    
    -- 基础颜色
    self.crossMeshMaterial:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    
    -- PBR 参数
    if isPBR then
        self.crossMeshMaterial:SetShaderParameter("MatSpecColor", Variant(Color(1, 1, 1, 1)))
        -- (同 getChunkMaterial：METALLIC technique 下 Roughness/Metallic 参数从不被读取，无需设置)
    end
    
    return self.crossMeshMaterial
end

---检查是否应该渲染面（相邻方块透明或非实心）
---@param bx number 方块X
---@param by number 方块Y
---@param bz number 方块Z
---@param dx number X偏移
---@param dy number Y偏移
---@param dz number Z偏移
---@return boolean 是否渲染
function ChunkMeshBuilder:shouldRenderFace(bx, by, bz, dx, dy, dz)
    local adjacentBlock = self.world:getBlock(bx + dx, by + dy, bz + dz)
    -- 如果相邻方块是空气、水或交叉网格（装饰草等），则渲染当前面
    return adjacentBlock == AIR or adjacentBlock == WATER or Blocks:isCrossMesh(adjacentBlock)
end

---检查是否应该渲染水面
---@param bx number 方块X
---@param by number 方块Y
---@param bz number 方块Z
---@param dx number X偏移
---@param dy number Y偏移
---@param dz number Z偏移
---@return boolean 是否渲染
function ChunkMeshBuilder:shouldRenderWaterFace(bx, by, bz, dx, dy, dz)
    local adjacentBlock = self.world:getBlock(bx + dx, by + dy, bz + dz)
    return adjacentBlock == AIR
end

---构建区块网格
---@param chunkX number 区块X坐标
---@param chunkZ number 区块Z坐标
function ChunkMeshBuilder:buildChunk(chunkX, chunkZ)
    -- 确保 UV 缓存已建立
    if not uvCacheBuilt then
        self:buildUVCache()
    end

    local chunkKey = chunkX .. "," .. chunkZ
    local world = self.world

    -- 移除现有区块
    world:removeChunk(chunkKey)

    -- 创建区块节点（使用 LOCAL 模式，单机和客户端都适用）
    local chunkNode = self.scene:CreateChild("Chunk_" .. chunkKey, LOCAL)
    world:registerChunk(chunkKey, chunkNode)

    -- 创建实体方块几何体
    local geometry = chunkNode:CreateComponent("CustomGeometry", LOCAL)
    geometry:BeginGeometry(0, TRIANGLE_LIST)

    -- 创建水几何体
    local waterNode = chunkNode:CreateChild("Water", LOCAL)
    local waterGeometry = waterNode:CreateComponent("CustomGeometry", LOCAL)
    waterGeometry:BeginGeometry(0, TRIANGLE_LIST)

    -- 创建交叉网格几何体（装饰草等）
    local crossNode = chunkNode:CreateChild("CrossMesh", LOCAL)
    local crossGeometry = crossNode:CreateComponent("CustomGeometry", LOCAL)
    crossGeometry:BeginGeometry(0, TRIANGLE_LIST)

    local startX = chunkX * CHUNK_SIZE
    local startZ = chunkZ * CHUNK_SIZE
    local vertexCount = 0
    local waterVertexCount = 0
    local crossVertexCount = 0

    -- ====================================================================
    -- 优化：直接访问 blocks 数组，避免每次调用 world:getBlock
    -- ====================================================================
    local numericChunkKey = chunkX * 65536 + chunkZ
    local chunkData = world.chunkData[numericChunkKey]
    local blocks = chunkData and chunkData.blocks or {}
    local minY = chunkData and chunkData.minY or 0
    local maxY = chunkData and chunkData.maxY or (WORLD_HEIGHT - 1)

    -- 预加载相邻区块的 blocks 数组（用于边界面检查）
    local chunkDataPX = world.chunkData[(chunkX + 1) * 65536 + chunkZ]
    local chunkDataNX = world.chunkData[(chunkX - 1) * 65536 + chunkZ]
    local chunkDataPZ = world.chunkData[chunkX * 65536 + (chunkZ + 1)]
    local chunkDataNZ = world.chunkData[chunkX * 65536 + (chunkZ - 1)]
    local blocksPX = chunkDataPX and chunkDataPX.blocks or nil
    local blocksNX = chunkDataNX and chunkDataNX.blocks or nil
    local blocksPZ = chunkDataPZ and chunkDataPZ.blocks or nil
    local blocksNZ = chunkDataNZ and chunkDataNZ.blocks or nil

    -- 追踪实际高度范围（用于修正删除方块后的范围）
    local actualMinY = WORLD_HEIGHT
    local actualMaxY = 0

    -- 本地化常用变量
    local CHUNK_SIZE_M1 = CHUNK_SIZE - 1

    for lx = 0, CHUNK_SIZE_M1 do
        for lz = 0, CHUNK_SIZE_M1 do
            -- 优化：只遍历有方块的高度范围
            for y = minY, maxY do
                -- 直接索引访问（避免 getBlock 的重复计算）
                local idx = y * 256 + lz * 16 + lx
                local blockType = blocks[idx] or AIR

                -- 更新实际高度范围
                if blockType ~= AIR then
                    if y < actualMinY then actualMinY = y end
                    if y > actualMaxY then actualMaxY = y end
                end

                -- 渲染交叉网格方块（装饰草等）
                if crossMeshLUT[blockType] then
                    local uv = uvCache[blockType]["side"]
                    local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
                    local worldBaseX = (startX + lx) * BLOCK_SIZE
                    local worldBaseY = y * BLOCK_SIZE
                    local worldBaseZ = (startZ + lz) * BLOCK_SIZE

                    for fi = 1, CROSS_MESH_FACES_COUNT do
                        local face = CROSS_MESH_FACES[fi]
                        local vertices = face.vertices
                        local faceNormal = face.normal
                        local faceTangent = face.tangent
                        for vi = 1, VERTICES_PER_FACE do
                            local v = vertices[vi]
                            local vpos, vuv = v.pos, v.uv

                            crossGeometry:DefineVertex(tempVec3(
                                worldBaseX + vpos[1] * BLOCK_SIZE,
                                worldBaseY + vpos[2] * BLOCK_SIZE,
                                worldBaseZ + vpos[3] * BLOCK_SIZE
                            ))
                            crossGeometry:DefineNormal(faceNormal)
                            crossGeometry:DefineTangent(faceTangent)
                            crossGeometry:DefineTexCoord(tempVec2(
                                u0 + vuv[1] * (u1 - u0),
                                v0 + vuv[2] * (v1 - v0)
                            ))
                            crossGeometry:DefineColor(COLOR_WHITE)

                            crossVertexCount = crossVertexCount + 1
                        end
                    end

                -- 渲染实体方块
                elseif blockType ~= AIR and blockType ~= WATER then
                    local worldBaseX = (startX + lx) * BLOCK_SIZE
                    local worldBaseY = y * BLOCK_SIZE
                    local worldBaseZ = (startZ + lz) * BLOCK_SIZE

                    -- ====================================================================
                    -- 内联面检查：直接索引访问相邻方块
                    -- ====================================================================
                    for fi = 1, CUBE_FACES_COUNT do
                        local face = CUBE_FACES[fi]
                        local check = face.check
                        local dx, dy, dz = check[1], check[2], check[3]

                        -- 获取相邻方块
                        local adjBlock
                        local adjLx, adjLz = lx + dx, lz + dz
                        local adjY = y + dy

                        if adjY < 0 or adjY >= WORLD_HEIGHT then
                            -- Y 越界：视为空气
                            adjBlock = AIR
                        elseif adjLx < 0 then
                            -- -X 边界：访问相邻区块
                            if blocksNX then
                                adjBlock = blocksNX[adjY * 256 + lz * 16 + CHUNK_SIZE_M1] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLx > CHUNK_SIZE_M1 then
                            -- +X 边界
                            if blocksPX then
                                adjBlock = blocksPX[adjY * 256 + lz * 16 + 0] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLz < 0 then
                            -- -Z 边界
                            if blocksNZ then
                                adjBlock = blocksNZ[adjY * 256 + CHUNK_SIZE_M1 * 16 + lx] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLz > CHUNK_SIZE_M1 then
                            -- +Z 边界
                            if blocksPZ then
                                adjBlock = blocksPZ[adjY * 256 + 0 * 16 + lx] or AIR
                            else
                                adjBlock = AIR
                            end
                        else
                            -- 内部方块：直接索引
                            adjBlock = blocks[adjY * 256 + adjLz * 16 + adjLx] or AIR
                        end

                        -- 判断是否渲染面（相邻为空气、水或交叉网格）
                        if adjBlock == AIR or adjBlock == WATER or crossMeshLUT[adjBlock] then
                            vertexCount = vertexCount + emitSolidFace(geometry, face,
                                worldBaseX, worldBaseY, worldBaseZ, blockType,
                                lx, lz, y, blocks, blocksNX, blocksPX, blocksNZ, blocksPZ,
                                world, startX, startZ)
                        end
                    end

                -- 渲染水方块
                elseif blockType == WATER then
                    local worldBaseX = (startX + lx) * BLOCK_SIZE
                    local worldBaseY = y * BLOCK_SIZE
                    local worldBaseZ = (startZ + lz) * BLOCK_SIZE

                    for fi = 1, CUBE_FACES_COUNT do
                        local face = CUBE_FACES[fi]
                        local check = face.check
                        local dx, dy, dz = check[1], check[2], check[3]

                        -- 获取相邻方块（水只检查是否为空气）
                        local adjBlock
                        local adjLx, adjLz = lx + dx, lz + dz
                        local adjY = y + dy

                        if adjY < 0 or adjY >= WORLD_HEIGHT then
                            adjBlock = AIR
                        elseif adjLx < 0 then
                            if blocksNX then
                                adjBlock = blocksNX[adjY * 256 + lz * 16 + CHUNK_SIZE_M1] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLx > CHUNK_SIZE_M1 then
                            if blocksPX then
                                adjBlock = blocksPX[adjY * 256 + lz * 16 + 0] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLz < 0 then
                            if blocksNZ then
                                adjBlock = blocksNZ[adjY * 256 + CHUNK_SIZE_M1 * 16 + lx] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLz > CHUNK_SIZE_M1 then
                            if blocksPZ then
                                adjBlock = blocksPZ[adjY * 256 + 0 * 16 + lx] or AIR
                            else
                                adjBlock = AIR
                            end
                        else
                            adjBlock = blocks[adjY * 256 + adjLz * 16 + adjLx] or AIR
                        end

                        -- 水面只在相邻为空气时渲染
                        if adjBlock == AIR then
                            local uv = uvCache[WATER][face.faceType]
                            local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
                            local vertices = face.vertices
                            local faceNormal = face.normal
                            local isTopFace = dy == 1

                            for vi = 1, VERTICES_PER_FACE do
                                local v = vertices[vi]
                                local vpos, vuv = v.pos, v.uv
                                local wy = worldBaseY + vpos[2] * BLOCK_SIZE
                                if isTopFace then
                                    wy = wy - 0.1
                                end

                                waterGeometry:DefineVertex(tempVec3(
                                    worldBaseX + vpos[1] * BLOCK_SIZE,
                                    wy,
                                    worldBaseZ + vpos[3] * BLOCK_SIZE
                                ))
                                waterGeometry:DefineNormal(faceNormal)
                                waterGeometry:DefineTexCoord(tempVec2(
                                    u0 + vuv[1] * (u1 - u0),
                                    v0 + vuv[2] * (v1 - v0)
                                ))
                                waterGeometry:DefineColor(COLOR_WATER)

                                waterVertexCount = waterVertexCount + 1
                            end
                        end
                    end
                end
            end
        end
    end

    -- 提交实体几何体
    if vertexCount > 0 then
        geometry:Commit()
        geometry.material = self:getChunkMaterial()
        geometry.castShadows = true
    end
    
    -- 提交水几何体
    if waterVertexCount > 0 then
        waterGeometry:Commit()
        waterGeometry.material = self:getWaterMaterial()
        waterGeometry.castShadows = false
    else
        waterNode:Remove()
    end
    
    -- 提交交叉网格几何体
    if crossVertexCount > 0 then
        crossGeometry:Commit()
        crossGeometry.material = self:getCrossMeshMaterial()
        crossGeometry.castShadows = false
    else
        crossNode:Remove()
    end

    -- 修正区块高度范围（解决删除方块后范围不收缩的问题）
    if actualMinY <= actualMaxY then
        world:updateChunkHeightRange(chunkX, chunkZ, actualMinY, actualMaxY)
    else
        -- 区块变为全空气
        world:updateChunkHeightRange(chunkX, chunkZ, WORLD_HEIGHT, 0)
    end
end

-- ====================================================================
-- 异步区块重建系统（类 Minecraft 实现）
-- 
-- 核心思想：
-- 1. 分帧构建顶点数据（每帧处理部分 Y 层，不阻塞）
-- 2. 保留旧 Mesh 直到新 Mesh 完成（避免闪烁）
-- 3. 相关区块（边界敲击产生的相邻区块）在同一帧 Commit（避免漏洞）
-- ====================================================================

-- 异步重建状态
local asyncRebuildState = {
    active = false,           -- 是否有异步重建进行中
    batch = {},               -- 当前批次的区块 { chunkKey = { x, z, tempNode, geometry, ... } }
    currentChunk = nil,       -- 当前正在构建的区块 key
    currentY = 0,             -- 当前构建到的 Y 层
    rowsPerFrame = 16,        -- 每帧处理的 Y 层数（可调整）
}

---重建脏区块（异步版本）
---@param maxRebuilds number|nil 最大重建数（默认从配置读取）
function ChunkMeshBuilder:rebuildDirtyChunks(maxRebuilds)
    local state = asyncRebuildState
    
    -- ====================================================================
    -- 阶段 1：如果有进行中的异步重建，继续处理
    -- ====================================================================
    if state.active then
        self:continueAsyncRebuild()
        return
    end
    
    -- ====================================================================
    -- 阶段 2：收集新的脏区块批次
    -- ====================================================================
    local dirtyChunks = self.world:getDirtyChunks()
    local count = 0
    for _ in pairs(dirtyChunks) do
        count = count + 1
    end
    
    if count == 0 then
        return
    end
    
    -- 收集本批次所有脏区块（边界敲击会产生 2-3 个相关区块）
    state.batch = {}
    for chunkKey, chunk in pairs(dirtyChunks) do
        state.batch[chunkKey] = {
            x = chunk.x,
            z = chunk.z,
            tempNode = nil,       -- 临时节点（构建中）
            geometry = nil,       -- 主几何体
            waterNode = nil,
            waterGeometry = nil,
            crossNode = nil,
            crossGeometry = nil,
            vertexCount = 0,
            waterVertexCount = 0,
            crossVertexCount = 0,
            actualMinY = WORLD_HEIGHT,
            actualMaxY = 0,
            completed = false,    -- 是否构建完成
        }
        self.world:clearDirtyChunk(chunkKey)
    end
    
    -- 开始异步重建
    state.active = true
    state.currentChunk = nil
    state.currentY = 0
    
    -- 为每个区块创建临时节点和几何体（准备阶段）
    for chunkKey, chunkInfo in pairs(state.batch) do
        self:prepareAsyncChunk(chunkKey, chunkInfo)
    end
    
    -- 选择第一个区块开始构建
    for chunkKey, _ in pairs(state.batch) do
        state.currentChunk = chunkKey
        local chunkData = self.world.chunkData[state.batch[chunkKey].x * 65536 + state.batch[chunkKey].z]
        state.currentY = chunkData and chunkData.minY or 0
        break
    end
end

---准备异步区块构建（创建临时节点）
---@param chunkKey string
---@param chunkInfo table
function ChunkMeshBuilder:prepareAsyncChunk(chunkKey, chunkInfo)
    -- 确保 UV 缓存已建立
    if not uvCacheBuilt then
        self:buildUVCache()
    end
    
    -- 创建临时区块节点（不替换旧的，构建完成后再替换）
    local tempNode = self.scene:CreateChild("Chunk_Temp_" .. chunkKey, LOCAL)
    
    -- 创建实体方块几何体
    local geometry = tempNode:CreateComponent("CustomGeometry", LOCAL)
    geometry:BeginGeometry(0, TRIANGLE_LIST)
    
    -- 创建水几何体
    local waterNode = tempNode:CreateChild("Water", LOCAL)
    local waterGeometry = waterNode:CreateComponent("CustomGeometry", LOCAL)
    waterGeometry:BeginGeometry(0, TRIANGLE_LIST)
    
    -- 创建交叉网格几何体
    local crossNode = tempNode:CreateChild("CrossMesh", LOCAL)
    local crossGeometry = crossNode:CreateComponent("CustomGeometry", LOCAL)
    crossGeometry:BeginGeometry(0, TRIANGLE_LIST)
    
    -- 保存到 chunkInfo
    chunkInfo.tempNode = tempNode
    chunkInfo.geometry = geometry
    chunkInfo.waterNode = waterNode
    chunkInfo.waterGeometry = waterGeometry
    chunkInfo.crossNode = crossNode
    chunkInfo.crossGeometry = crossGeometry
end

---继续异步重建（每帧调用）
function ChunkMeshBuilder:continueAsyncRebuild()
    local state = asyncRebuildState
    
    if not state.currentChunk then
        -- 所有区块构建完成，执行批量提交
        self:commitAsyncBatch()
        return
    end
    
    local chunkInfo = state.batch[state.currentChunk]
    local chunkX, chunkZ = chunkInfo.x, chunkInfo.z
    
    -- 获取区块数据
    local numericKey = chunkX * 65536 + chunkZ
    local chunkData = self.world.chunkData[numericKey]
    local blocks = chunkData and chunkData.blocks or {}
    local minY = chunkData and chunkData.minY or 0
    local maxY = chunkData and chunkData.maxY or (WORLD_HEIGHT - 1)
    
    -- 计算本帧处理的 Y 范围
    local startY = state.currentY
    local endY = math.min(startY + state.rowsPerFrame - 1, maxY)
    
    -- 构建这几层的顶点
    self:buildChunkRows(chunkInfo, chunkX, chunkZ, startY, endY, blocks)
    
    -- 更新进度
    state.currentY = endY + 1
    
    -- 检查当前区块是否完成
    if state.currentY > maxY then
        chunkInfo.completed = true
        
        -- 选择下一个未完成的区块
        state.currentChunk = nil
        for chunkKey, info in pairs(state.batch) do
            if not info.completed then
                state.currentChunk = chunkKey
                local nextChunkData = self.world.chunkData[info.x * 65536 + info.z]
                state.currentY = nextChunkData and nextChunkData.minY or 0
                break
            end
        end
    end
end

---构建区块的若干 Y 层（内部方法）
---@param chunkInfo table 区块信息
---@param chunkX number 区块 X
---@param chunkZ number 区块 Z
---@param startY number 起始 Y
---@param endY number 结束 Y
---@param blocks table 方块数据
function ChunkMeshBuilder:buildChunkRows(chunkInfo, chunkX, chunkZ, startY, endY, blocks)
    local world = self.world
    local geometry = chunkInfo.geometry
    local waterGeometry = chunkInfo.waterGeometry
    local crossGeometry = chunkInfo.crossGeometry
    
    local startX = chunkX * CHUNK_SIZE
    local startZ = chunkZ * CHUNK_SIZE
    local CHUNK_SIZE_M1 = CHUNK_SIZE - 1
    
    -- 预加载相邻区块数据
    local chunkDataPX = world.chunkData[(chunkX + 1) * 65536 + chunkZ]
    local chunkDataNX = world.chunkData[(chunkX - 1) * 65536 + chunkZ]
    local chunkDataPZ = world.chunkData[chunkX * 65536 + (chunkZ + 1)]
    local chunkDataNZ = world.chunkData[chunkX * 65536 + (chunkZ - 1)]
    local blocksPX = chunkDataPX and chunkDataPX.blocks or nil
    local blocksNX = chunkDataNX and chunkDataNX.blocks or nil
    local blocksPZ = chunkDataPZ and chunkDataPZ.blocks or nil
    local blocksNZ = chunkDataNZ and chunkDataNZ.blocks or nil
    
    for lx = 0, CHUNK_SIZE_M1 do
        for lz = 0, CHUNK_SIZE_M1 do
            for y = startY, endY do
                local idx = y * 256 + lz * 16 + lx
                local blockType = blocks[idx] or AIR
                
                -- 更新实际高度范围
                if blockType ~= AIR then
                    if y < chunkInfo.actualMinY then chunkInfo.actualMinY = y end
                    if y > chunkInfo.actualMaxY then chunkInfo.actualMaxY = y end
                end
                
                -- 渲染交叉网格方块
                if crossMeshLUT[blockType] then
                    local uv = uvCache[blockType]["side"]
                    local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
                    local worldBaseX = (startX + lx) * BLOCK_SIZE
                    local worldBaseY = y * BLOCK_SIZE
                    local worldBaseZ = (startZ + lz) * BLOCK_SIZE
                    
                    for fi = 1, CROSS_MESH_FACES_COUNT do
                        local face = CROSS_MESH_FACES[fi]
                        local vertices = face.vertices
                        local faceNormal = face.normal
                        local faceTangent = face.tangent
                        for vi = 1, VERTICES_PER_FACE do
                            local v = vertices[vi]
                            local vpos, vuv = v.pos, v.uv
                            crossGeometry:DefineVertex(tempVec3(
                                worldBaseX + vpos[1] * BLOCK_SIZE,
                                worldBaseY + vpos[2] * BLOCK_SIZE,
                                worldBaseZ + vpos[3] * BLOCK_SIZE
                            ))
                            crossGeometry:DefineNormal(faceNormal)
                            crossGeometry:DefineTangent(faceTangent)
                            crossGeometry:DefineTexCoord(tempVec2(
                                u0 + vuv[1] * (u1 - u0),
                                v0 + vuv[2] * (v1 - v0)
                            ))
                            crossGeometry:DefineColor(COLOR_WHITE)
                            chunkInfo.crossVertexCount = chunkInfo.crossVertexCount + 1
                        end
                    end
                    
                -- 渲染实体方块
                elseif blockType ~= AIR and blockType ~= WATER then
                    local worldBaseX = (startX + lx) * BLOCK_SIZE
                    local worldBaseY = y * BLOCK_SIZE
                    local worldBaseZ = (startZ + lz) * BLOCK_SIZE
                    
                    for fi = 1, CUBE_FACES_COUNT do
                        local face = CUBE_FACES[fi]
                        local check = face.check
                        local dx, dy, dz = check[1], check[2], check[3]
                        
                        -- 获取相邻方块
                        local adjBlock
                        local adjLx, adjLz = lx + dx, lz + dz
                        local adjY = y + dy
                        
                        if adjY < 0 or adjY >= WORLD_HEIGHT then
                            adjBlock = AIR
                        elseif adjLx < 0 then
                            if blocksNX then
                                adjBlock = blocksNX[adjY * 256 + lz * 16 + CHUNK_SIZE_M1] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLx > CHUNK_SIZE_M1 then
                            if blocksPX then
                                adjBlock = blocksPX[adjY * 256 + lz * 16 + 0] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLz < 0 then
                            if blocksNZ then
                                adjBlock = blocksNZ[adjY * 256 + CHUNK_SIZE_M1 * 16 + lx] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLz > CHUNK_SIZE_M1 then
                            if blocksPZ then
                                adjBlock = blocksPZ[adjY * 256 + 0 * 16 + lx] or AIR
                            else
                                adjBlock = AIR
                            end
                        else
                            adjBlock = blocks[adjY * 256 + adjLz * 16 + adjLx] or AIR
                        end
                        
                        -- 判断是否渲染面
                        if adjBlock == AIR or adjBlock == WATER or crossMeshLUT[adjBlock] then
                            chunkInfo.vertexCount = chunkInfo.vertexCount + emitSolidFace(geometry, face,
                                worldBaseX, worldBaseY, worldBaseZ, blockType,
                                lx, lz, y, blocks, blocksNX, blocksPX, blocksNZ, blocksPZ,
                                world, startX, startZ)
                        end
                    end
                    
                -- 渲染水方块
                elseif blockType == WATER then
                    local worldBaseX = (startX + lx) * BLOCK_SIZE
                    local worldBaseY = y * BLOCK_SIZE
                    local worldBaseZ = (startZ + lz) * BLOCK_SIZE
                    
                    for fi = 1, CUBE_FACES_COUNT do
                        local face = CUBE_FACES[fi]
                        local check = face.check
                        local dx, dy, dz = check[1], check[2], check[3]
                        
                        local adjBlock
                        local adjLx, adjLz = lx + dx, lz + dz
                        local adjY = y + dy
                        
                        if adjY < 0 or adjY >= WORLD_HEIGHT then
                            adjBlock = AIR
                        elseif adjLx < 0 then
                            if blocksNX then
                                adjBlock = blocksNX[adjY * 256 + lz * 16 + CHUNK_SIZE_M1] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLx > CHUNK_SIZE_M1 then
                            if blocksPX then
                                adjBlock = blocksPX[adjY * 256 + lz * 16 + 0] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLz < 0 then
                            if blocksNZ then
                                adjBlock = blocksNZ[adjY * 256 + CHUNK_SIZE_M1 * 16 + lx] or AIR
                            else
                                adjBlock = AIR
                            end
                        elseif adjLz > CHUNK_SIZE_M1 then
                            if blocksPZ then
                                adjBlock = blocksPZ[adjY * 256 + 0 * 16 + lx] or AIR
                            else
                                adjBlock = AIR
                            end
                        else
                            adjBlock = blocks[adjY * 256 + adjLz * 16 + adjLx] or AIR
                        end
                        
                        if adjBlock == AIR then
                            local uv = uvCache[WATER][face.faceType]
                            local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
                            local vertices = face.vertices
                            local faceNormal = face.normal
                            local isTopFace = dy == 1
                            
                            for vi = 1, VERTICES_PER_FACE do
                                local v = vertices[vi]
                                local vpos, vuv = v.pos, v.uv
                                local wy = worldBaseY + vpos[2] * BLOCK_SIZE
                                if isTopFace then wy = wy - 0.1 end
                                
                                waterGeometry:DefineVertex(tempVec3(
                                    worldBaseX + vpos[1] * BLOCK_SIZE,
                                    wy,
                                    worldBaseZ + vpos[3] * BLOCK_SIZE
                                ))
                                waterGeometry:DefineNormal(faceNormal)
                                waterGeometry:DefineTexCoord(tempVec2(
                                    u0 + vuv[1] * (u1 - u0),
                                    v0 + vuv[2] * (v1 - v0)
                                ))
                                waterGeometry:DefineColor(COLOR_WATER)
                                chunkInfo.waterVertexCount = chunkInfo.waterVertexCount + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

---批量提交所有异步构建的区块（同帧替换，避免漏洞）
function ChunkMeshBuilder:commitAsyncBatch()
    local state = asyncRebuildState
    local world = self.world
    
    -- 同帧提交所有区块
    for chunkKey, chunkInfo in pairs(state.batch) do
        -- 1. 提交几何体
        if chunkInfo.vertexCount > 0 then
            chunkInfo.geometry:Commit()
            chunkInfo.geometry.material = self:getChunkMaterial()
            chunkInfo.geometry.castShadows = true
        end
        
        if chunkInfo.waterVertexCount > 0 then
            chunkInfo.waterGeometry:Commit()
            chunkInfo.waterGeometry.material = self:getWaterMaterial()
            chunkInfo.waterGeometry.castShadows = false
        else
            chunkInfo.waterNode:Remove()
        end
        
        if chunkInfo.crossVertexCount > 0 then
            chunkInfo.crossGeometry:Commit()
            chunkInfo.crossGeometry.material = self:getCrossMeshMaterial()
            chunkInfo.crossGeometry.castShadows = false
        else
            chunkInfo.crossNode:Remove()
        end
        
        -- 2. 原子替换：删除旧节点，注册新节点
        world:removeChunk(chunkKey)
        chunkInfo.tempNode.name = "Chunk_" .. chunkKey
        world:registerChunk(chunkKey, chunkInfo.tempNode)
        
        -- 3. 更新高度范围
        if chunkInfo.actualMinY <= chunkInfo.actualMaxY then
            world:updateChunkHeightRange(chunkInfo.x, chunkInfo.z, chunkInfo.actualMinY, chunkInfo.actualMaxY)
        else
            world:updateChunkHeightRange(chunkInfo.x, chunkInfo.z, WORLD_HEIGHT, 0)
        end
    end
    
    -- 重置状态
    state.active = false
    state.batch = {}
    state.currentChunk = nil
end

---检查是否有异步重建进行中
---@return boolean
function ChunkMeshBuilder:isAsyncRebuildActive()
    return asyncRebuildState.active
end

---获取异步重建进度信息（调试用）
---@return table { active, batchSize, currentChunk, currentY }
function ChunkMeshBuilder:getAsyncRebuildStatus()
    local state = asyncRebuildState
    local batchSize = 0
    for _ in pairs(state.batch) do
        batchSize = batchSize + 1
    end
    return {
        active = state.active,
        batchSize = batchSize,
        currentChunk = state.currentChunk,
        currentY = state.currentY,
    }
end

---渲染可见区块
---@param playerPos Vector3 玩家位置
function ChunkMeshBuilder:renderVisibleChunks(playerPos)
    local RENDER_DISTANCE = Config.World.RENDER_DISTANCE

    local playerChunkX = math.floor(playerPos.x / (CHUNK_SIZE * BLOCK_SIZE))
    local playerChunkZ = math.floor(playerPos.z / (CHUNK_SIZE * BLOCK_SIZE))

    for cx = playerChunkX - RENDER_DISTANCE, playerChunkX + RENDER_DISTANCE do
        for cz = playerChunkZ - RENDER_DISTANCE, playerChunkZ + RENDER_DISTANCE do
            local chunkKey = cx .. "," .. cz
            if not self.world:getChunk(chunkKey) then
                self:buildChunk(cx, cz)
            end
        end
    end
end

---异步渲染可见区块（协程版本）
---每构建若干个区块后 yield，让主线程可以刷新 UI
---@param playerPos Vector3 玩家位置
---@param onProgress function|nil 进度回调 function(current, total)
---@return thread 协程对象
function ChunkMeshBuilder:renderVisibleChunksAsync(playerPos, onProgress)
    return coroutine.create(function()
        local RENDER_DISTANCE = Config.World.RENDER_DISTANCE
        local CHUNKS_PER_FRAME = 2  -- 每帧构建区块数

        local playerChunkX = math.floor(playerPos.x / (CHUNK_SIZE * BLOCK_SIZE))
        local playerChunkZ = math.floor(playerPos.z / (CHUNK_SIZE * BLOCK_SIZE))

        -- 收集需要构建的区块
        local chunksToBuild = {}
        for cx = playerChunkX - RENDER_DISTANCE, playerChunkX + RENDER_DISTANCE do
            for cz = playerChunkZ - RENDER_DISTANCE, playerChunkZ + RENDER_DISTANCE do
                local chunkKey = cx .. "," .. cz
                if not self.world:getChunk(chunkKey) then
                    table.insert(chunksToBuild, { x = cx, z = cz })
                end
            end
        end

        local totalChunks = #chunksToBuild
        local builtCount = 0

        print(string.format("[ChunkMeshBuilder] Building %d chunks (async)...", totalChunks))

        for i, chunk in ipairs(chunksToBuild) do
            self:buildChunk(chunk.x, chunk.z)
            builtCount = builtCount + 1

            if builtCount % CHUNKS_PER_FRAME == 0 then
                if onProgress then
                    onProgress(builtCount, totalChunks)
                end
                coroutine.yield()
            end
        end

        -- 确保最终进度报告
        if onProgress then
            onProgress(totalChunks, totalChunks)
        end

        print("[ChunkMeshBuilder] Chunk building complete (async)!")
    end)
end

---刷新材质包（切换材质包时调用）
function ChunkMeshBuilder:refreshTexturePack()
    local pack = TexturePackManager:getCurrent()
    self.textures = pack:generate()

    -- 重新创建材质（technique 可能不同）
    self.chunkMaterial = nil
    self.crossMeshMaterial = nil
    self:getChunkMaterial()
    self:getCrossMeshMaterial()

    -- 重建 UV 缓存
    self:buildUVCache()

    -- 标记所有区块为脏，触发重建
    self.world:markAllChunksDirty()

    local packType = self.textures.normal and "PBR" or "Diffuse"
    print("[ChunkMeshBuilder] Texture pack refreshed: " .. pack.displayName .. " (" .. packType .. ")")
end

return ChunkMeshBuilder
