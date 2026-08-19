-- ====================================================================
-- world/World.lua
-- 世界管理 - 方块数据存储和访问（优化版）
-- 使用按区块的一维数组存储，支持高度范围优化和稀疏区块
-- ====================================================================
--
-- 键类型设计说明：
-- - chunkData: 使用数值键 (chunkX * 65536 + chunkZ) - 高频访问，性能优先
-- - chunks/dirtyChunks: 使用字符串键 "x,z" - 低频访问，需要用于节点命名
--
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")

-- 常量本地化（热路径优化）
local CHUNK_SIZE = Config.World.CHUNK_SIZE
local WORLD_HEIGHT = Config.World.WORLD_HEIGHT
local BLOCK_SIZE = Config.World.BLOCK_SIZE
local BLOCKS_PER_CHUNK = CHUNK_SIZE * WORLD_HEIGHT * CHUNK_SIZE
local AIR = Blocks.AIR

-- 数学函数本地化
local floor = math.floor
local min = math.min
local max = math.max

---@class World
---@field chunkData table<integer, table>
---@field chunks table<string, Node>
---@field dirtyChunks table<string, table>
local World = {}
World.__index = World

---创建新的世界实例
---@return table World实例
function World.new()
    local self = setmetatable({}, World)
    self.chunkData = {}      -- [numericKey] = ChunkData { blocks = array, minY = n, maxY = n }
    self.chunks = {}         -- [stringKey] = chunkNode（渲染节点，用于节点命名）
    self.dirtyChunks = {}    -- [stringKey] = { x, z }（需要重建的区块）
    return self
end

-- ====================================================================
-- 键转换辅助方法（避免混淆）
-- ====================================================================

---从区块坐标获取字符串键（用于渲染节点）
---@param chunkX number 区块 X
---@param chunkZ number 区块 Z
---@return string chunkKey
function World:getStringKey(chunkX, chunkZ)
    return chunkX .. "," .. chunkZ
end

---从区块坐标获取数值键（用于方块数据存储）
---@param chunkX number 区块 X
---@param chunkZ number 区块 Z
---@return number chunkKey
function World:getNumericKey(chunkX, chunkZ)
    return chunkX * 65536 + chunkZ
end

---从世界坐标获取区块坐标
---@param x number 世界坐标 X
---@param z number 世界坐标 Z
---@return number chunkX, number chunkZ
function World:getChunkCoords(x, z)
    return floor(x / CHUNK_SIZE), floor(z / CHUNK_SIZE)
end

-- 兼容性别名
World.chunkCoordsToKey = World.getNumericKey

-- ====================================================================
-- 区块数据访问
-- ====================================================================

---计算方块在区块中的一维索引
---@param localX number 区块内 X (0-15)
---@param y number 世界高度 Y (0-WORLD_HEIGHT-1)
---@param localZ number 区块内 Z (0-15)
---@return number 一维索引
function World:getBlockIndex(localX, y, localZ)
    return y * 256 + localZ * 16 + localX
end

---确保区块数据存在（按需创建）
---@param numericKey number 数值键
---@return table chunkData
function World:ensureChunkData(numericKey)
    local chunkData = self.chunkData[numericKey]
    if not chunkData then
        chunkData = {
            blocks = {},
            minY = WORLD_HEIGHT,
            maxY = 0
        }
        self.chunkData[numericKey] = chunkData
    end
    return chunkData
end

---获取区块数据（不自动创建）
---@param numericKey number 数值键
---@return table|nil chunkData
function World:getChunkData(numericKey)
    return self.chunkData[numericKey]
end

---获取方块（高度优化版本）
---@param x number 世界坐标 X
---@param y number 世界坐标 Y
---@param z number 世界坐标 Z
---@return number blockType
function World:getBlock(x, y, z)
    if y < 0 or y >= WORLD_HEIGHT then
        return AIR
    end
    
    local chunkX = floor(x / CHUNK_SIZE)
    local chunkZ = floor(z / CHUNK_SIZE)
    local numericKey = chunkX * 65536 + chunkZ
    local chunkData = self.chunkData[numericKey]
    
    if not chunkData then
        return AIR
    end
    
    local blocks = chunkData.blocks
    if not blocks then
        return AIR
    end
    
    local localX = x - chunkX * CHUNK_SIZE
    local localZ = z - chunkZ * CHUNK_SIZE
    local idx = y * 256 + localZ * 16 + localX
    
    return blocks[idx] or AIR
end

---设置方块（仅数据，不标记脏区块，不更新高度范围）
---用于世界生成等批量操作
---@param x number 世界坐标 X
---@param y number 世界坐标 Y
---@param z number 世界坐标 Z
---@param blockType number 方块类型
---@return boolean success
function World:setBlockRaw(x, y, z, blockType)
    if y < 0 or y >= WORLD_HEIGHT then
        return false
    end
    
    local chunkX = floor(x / CHUNK_SIZE)
    local chunkZ = floor(z / CHUNK_SIZE)
    local numericKey = chunkX * 65536 + chunkZ
    local chunkData = self:ensureChunkData(numericKey)
    
    local localX = x - chunkX * CHUNK_SIZE
    local localZ = z - chunkZ * CHUNK_SIZE
    local idx = y * 256 + localZ * 16 + localX
    
    chunkData.blocks[idx] = blockType
    return true
end

---设置方块（并标记区块为脏，更新高度范围）
---用于玩家交互（破坏/放置方块）
---@param x number 世界坐标 X
---@param y number 世界坐标 Y
---@param z number 世界坐标 Z
---@param blockType number 方块类型
---@return boolean success
function World:setBlock(x, y, z, blockType)
    local oldBlock = self:getBlock(x, y, z)   -- L4: 记录旧方块以判断光照变化
    if not self:setBlockRaw(x, y, z, blockType) then
        return false
    end

    local chunkX = floor(x / CHUNK_SIZE)
    local chunkZ = floor(z / CHUNK_SIZE)
    local numericKey = chunkX * 65536 + chunkZ
    local chunkData = self.chunkData[numericKey]

    -- 增量更新高度范围（仅在放置非空气方块时扩展）
    if chunkData and blockType ~= AIR then
        chunkData.minY = min(chunkData.minY or y, y)
        chunkData.maxY = max(chunkData.maxY or y, y)
    end
    -- 注意：删除方块时不主动收缩范围，由 buildChunk 时修正（见 updateChunkHeightRange）

    -- L4: 编辑增量光照（天光重灌该列 + 方块光 add/remove），须在 markChunkDirty 前更新好数据
    self:updateLightingForEdit(x, y, z, oldBlock, blockType)

    self:markChunkDirty(x, y, z)
    return true
end

-- ====================================================================
-- 光照场访问（M1 逐方块光照）
-- skyLight / blockLight 各 0-15，与 blocks 同形稀疏数组、同 getBlockIndex 索引。
-- 稀疏存储：值 0 存为 nil 省内存（读取端统一 `or 0`）。lazy 创建数组，不改 ensureChunkData。
-- ====================================================================

---内部：读光照值
---@param field string "skyLight" | "blockLight"
---@return number 0-15（越界 / 无数据 = 0）
function World:getLight(field, x, y, z)
    if y < 0 or y >= WORLD_HEIGHT then return 0 end
    local chunkX = floor(x / CHUNK_SIZE)
    local chunkZ = floor(z / CHUNK_SIZE)
    local chunkData = self.chunkData[chunkX * 65536 + chunkZ]
    if not chunkData then return 0 end
    local arr = chunkData[field]
    if not arr then return 0 end
    local localX = x - chunkX * CHUNK_SIZE
    local localZ = z - chunkZ * CHUNK_SIZE
    return arr[y * 256 + localZ * 16 + localX] or 0
end

---内部：写光照值（按需创建 chunkData 与数组），value 钳制到 0-15
---@param field string "skyLight" | "blockLight"
---@return boolean success
function World:setLight(field, x, y, z, value)
    if y < 0 or y >= WORLD_HEIGHT then return false end
    if value < 0 then value = 0 elseif value > 15 then value = 15 end
    local chunkX = floor(x / CHUNK_SIZE)
    local chunkZ = floor(z / CHUNK_SIZE)
    local chunkData = self:ensureChunkData(chunkX * 65536 + chunkZ)
    local arr = chunkData[field]
    if not arr then
        arr = {}
        chunkData[field] = arr
    end
    local localX = x - chunkX * CHUNK_SIZE
    local localZ = z - chunkZ * CHUNK_SIZE
    local idx = y * 256 + localZ * 16 + localX
    arr[idx] = (value > 0) and value or nil   -- 0 存 nil（稀疏）
    return true
end

---天光 0-15（露天 15，向下/横向衰减）
function World:getSkyLight(x, y, z) return self:getLight("skyLight", x, y, z) end
function World:setSkyLight(x, y, z, v) return self:setLight("skyLight", x, y, z, v) end
---方块光 0-15（火把等光源向外 BFS 衰减）
function World:getBlockLight(x, y, z) return self:getLight("blockLight", x, y, z) end
function World:setBlockLight(x, y, z, v) return self:setLight("blockLight", x, y, z, v) end

---对单个区块做天光垂直灌注：每列从顶向下，透明方块（空气/水/草/叶）受天光=15，
---遇第一个不透明方块停止（其下不受直接天光）。
---列在区块内垂直完整，无需邻区块——demo 是 heightmap 地形（无洞穴/悬垂），
---垂直灌注即足够；横向 BFS（光绕射进洞口）留待 3D 地形或玩家挖洞（L4 增量传播）。
---@param chunkData table
function World:propagateSkyLightChunk(chunkData)
    local blocks = chunkData.blocks
    if not blocks then return end
    local sky = chunkData.skyLight
    if not sky then
        sky = {}
        chunkData.skyLight = sky
    end
    local CS_M1 = CHUNK_SIZE - 1
    for lz = 0, CS_M1 do
        for lx = 0, CS_M1 do
            local base = lz * 16 + lx
            for y = WORLD_HEIGHT - 1, 0, -1 do
                local idx = y * 256 + base
                if Blocks:isTransparent(blocks[idx] or AIR) then
                    sky[idx] = 15
                else
                    break  -- 不透明：其下不受直接天光
                end
            end
        end
    end
end

---对所有已生成区块灌注天光（同步生成路径用；异步路径在分帧循环内逐 chunk 调）
function World:propagateSkyLight()
    for _, chunkData in pairs(self.chunkData) do
        self:propagateSkyLightChunk(chunkData)
    end
end

-- 6 邻方向（blockLight BFS 复用，避免每次分配）
local LIGHT_DIRS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }

---共享：从扁平队列(每 4 元素 x,y,z,level 一节点)做 blockLight 增益 BFS 传播。
---每格向 6 透明邻 -1，仅当邻居更暗时写入。addBlockLight 与 removeBlockLight 的重照共用，
---避免两份近似的传播逻辑分叉（参照 emitSolidFace F1 抽取的教训）。
---@param queue table 扁平四元组队列，调用前已含初始种子
---@param head number 起始读指针（通常 1）
---@param seen table|nil 受影响 chunk 收集表（numericKey→{cx,cz}），供 BFS 后统一标脏
local function floodAddLight(self, queue, head, seen)
    while head <= #queue do
        local cx, cy, cz, cl = queue[head], queue[head + 1], queue[head + 2], queue[head + 3]
        head = head + 4
        if cl > 1 then
            local nl = cl - 1
            for i = 1, 6 do
                local d = LIGHT_DIRS[i]
                local nx, ny, nz = cx + d[1], cy + d[2], cz + d[3]
                if Blocks:isTransparent(self:getBlock(nx, ny, nz)) and self:getBlockLight(nx, ny, nz) < nl then
                    self:setBlockLight(nx, ny, nz, nl)
                    if seen then
                        local ccx, ccz = floor(nx / CHUNK_SIZE), floor(nz / CHUNK_SIZE)
                        local k = ccx * 65536 + ccz
                        if not seen[k] then seen[k] = { ccx, ccz } end
                    end
                    local n = #queue
                    queue[n + 1] = nx; queue[n + 2] = ny; queue[n + 3] = nz; queue[n + 4] = nl
                end
            end
        end
    end
end

---把光照 BFS 触及的所有 chunk 标脏（含跨边界写入的邻 chunk）。
---修复：blockLight 传播半径可达 lightRadius 格、跨越多个 chunk，仅靠 markChunkDirty 的
---"编辑方块边界判断"无法覆盖光的实际传播范围；必须按实际写入位置标脏，否则邻 chunk
---光照数据已变而 mesh 不重建，出现光照接缝断层（Greptile PR #1935 指出）。
---@param seen table numericKey→{cx,cz}
function World:markLightChunksDirty(seen)
    for _, c in pairs(seen) do
        self.dirtyChunks[self:getStringKey(c[1], c[2])] = { x = c[1], z = c[2] }
    end
end

---注入一个方块光源并向外 BFS 衰减传播（写 blockLight 场）：每格向 6 邻 -1，遇不透明方块停止。
---火把（TORCH lightRadius）等光源用此注入。BFS 触及的所有 chunk 自动标脏（含跨界邻 chunk）。
---@param level number 光源亮度 1-15
function World:addBlockLight(x, y, z, level)
    if level <= 0 then return end
    if self:getBlockLight(x, y, z) >= level then return end
    self:setBlockLight(x, y, z, level)
    local cx0, cz0 = floor(x / CHUNK_SIZE), floor(z / CHUNK_SIZE)
    local seen = { [cx0 * 65536 + cz0] = { cx0, cz0 } }
    floodAddLight(self, { x, y, z, level }, 1, seen)
    self:markLightChunksDirty(seen)
end

---移除 (x,y,z) 处方块光（挖掉光源 / 放不透明方块挡光后调用）：先 removal BFS 清除
---由该点供光的格子，沿途把"被其它独立光源照亮"的边界格收集为重照种子，再 flood 补回。
---经典 Minecraft light-removal 算法（参考 fogleman/Craft, MIT；0fps 通用做法）。
---L4 编辑增量传播的核心：挖方块让光透入、放方块挡光、挖掉火把熄灭均经此。
---清除 + 重照 BFS 触及的所有 chunk 自动标脏（含跨界邻 chunk）。
function World:removeBlockLight(x, y, z)
    local old = self:getBlockLight(x, y, z)
    if old == 0 then return end
    self:setBlockLight(x, y, z, 0)
    local cx0, cz0 = floor(x / CHUNK_SIZE), floor(z / CHUNK_SIZE)
    local seen = { [cx0 * 65536 + cz0] = { cx0, cz0 } }
    local relight = {}                    -- 边界独立光源（重照种子）扁平四元组
    local queue = { x, y, z, old }
    local head = 1
    while head <= #queue do
        local cx, cy, cz, cl = queue[head], queue[head + 1], queue[head + 2], queue[head + 3]
        head = head + 4
        for i = 1, 6 do
            local d = LIGHT_DIRS[i]
            local nx, ny, nz = cx + d[1], cy + d[2], cz + d[3]
            local nl = self:getBlockLight(nx, ny, nz)
            if nl ~= 0 then
                -- nl < cl 表示该邻格由本链供光，应清除；但若该格本身是光源方块（hasLight），
                -- 其亮度是独立的（如相邻的另一把火把），不能当依赖格清 0，否则永久抹除其光
                -- （Greptile PR #1935 P1）→ 归入重照种子。
                if nl < cl and not Blocks:hasLight(self:getBlock(nx, ny, nz)) then
                    -- 由 (cx,cy,cz) 供光且自身非光源 → 清 0 并继续移除传播
                    self:setBlockLight(nx, ny, nz, 0)
                    local ccx, ccz = floor(nx / CHUNK_SIZE), floor(nz / CHUNK_SIZE)
                    local k = ccx * 65536 + ccz
                    if not seen[k] then seen[k] = { ccx, ccz } end
                    local n = #queue
                    queue[n + 1] = nx; queue[n + 2] = ny; queue[n + 3] = nz; queue[n + 4] = nl
                else
                    -- nl >= cl（独立更强/相等光源）或自身是光源方块 → 记为重照种子（其值不动）
                    local m = #relight
                    relight[m + 1] = nx; relight[m + 2] = ny; relight[m + 3] = nz; relight[m + 4] = nl
                end
            end
        end
    end
    -- 重照：所有边界独立光源重新 flood（种子值已正确，从其邻居补回被清空的区域），同样收集受影响 chunk
    floodAddLight(self, relight, 1, seen)
    self:markLightChunksDirty(seen)
end

---重灌单列天光（垂直 top-down）：编辑方块改变该列透光性后调用。从顶向下，
---透明且仍受光=15，遇第一个不透明起其下全 0（清除旧值）。与 L1 列灌注同构、无横向 BFS。
function World:recomputeSkyColumn(x, z)
    local lit = true
    for y = WORLD_HEIGHT - 1, 0, -1 do
        if lit and Blocks:isTransparent(self:getBlock(x, y, z)) then
            self:setSkyLight(x, y, z, 15)
        else
            lit = false
            self:setSkyLight(x, y, z, 0)
        end
    end
end

---L4 编辑增量光照：放/破坏方块后更新光场（天光重灌列 + 方块光 add/remove）。
---挖洞→天光透下变亮、放方块→挡光变暗、放火把→照亮一圈、挖火把→熄灭并由邻光补回。
---@param oldBlock number 旧方块 id
---@param newBlock number 新方块 id
function World:updateLightingForEdit(x, y, z, oldBlock, newBlock)
    -- 1) 天光：编辑改变该列透光性 → 重灌该列
    self:recomputeSkyColumn(x, z)

    -- 2) 方块光
    local oldTrans = Blocks:isTransparent(oldBlock)
    local newTrans = Blocks:isTransparent(newBlock)
    local oldLit = Blocks:hasLight(oldBlock)
    local newLit = Blocks:hasLight(newBlock)

    -- 挖掉光源、或放不透明方块挡住原有光 → 移除该格光并重照周边
    if (oldLit and not newLit) or (oldTrans and not newTrans) then
        if self:getBlockLight(x, y, z) > 0 then
            self:removeBlockLight(x, y, z)
        end
    end

    -- 挖开不透明方块（透光）→ 邻居最强光 -1 透入并 flood
    if (not oldTrans) and newTrans then
        local maxN = 0
        for i = 1, 6 do
            local d = LIGHT_DIRS[i]
            local nl = self:getBlockLight(x + d[1], y + d[2], z + d[3])
            if nl > maxN then maxN = nl end
        end
        if maxN > 1 then self:addBlockLight(x, y, z, maxN - 1) end
    end

    -- 放置新光源（火把等）
    if newLit then
        local block = Blocks:get(newBlock)
        self:addBlockLight(x, y, z, (block and block.lightRadius) or 8)
    end
end

-- ====================================================================
-- 高度范围管理
-- ====================================================================

---计算区块高度范围
---@param chunkData table 区块数据
---@return number minY, number maxY
function World:computeHeightRange(chunkData)
    if not chunkData or not chunkData.blocks then
        return WORLD_HEIGHT, 0
    end
    
    local minY, maxY = WORLD_HEIGHT, 0
    local blocks = chunkData.blocks
    
    for y = 0, WORLD_HEIGHT - 1 do
        for lz = 0, CHUNK_SIZE - 1 do
            for lx = 0, CHUNK_SIZE - 1 do
                local idx = y * 256 + lz * 16 + lx
                local block = blocks[idx]
                if block and block ~= AIR then
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                end
            end
        end
    end
    
    return minY <= maxY and minY or 0, maxY
end

---计算所有区块的高度范围（世界生成完成后调用）
function World:computeAllChunkHeightRanges()
    local count = 0
    for numericKey, chunkData in pairs(self.chunkData) do
        if chunkData.blocks then
            chunkData.minY, chunkData.maxY = self:computeHeightRange(chunkData)
            count = count + 1
        end
    end
    print(string.format("[World] Computed height ranges for %d chunks", count))
end

---更新单个区块的高度范围（由 ChunkMeshBuilder 在重建时调用）
---解决删除方块后高度范围不收缩的问题
---@param chunkX number 区块 X
---@param chunkZ number 区块 Z
---@param actualMinY number 实际最小 Y
---@param actualMaxY number 实际最大 Y
function World:updateChunkHeightRange(chunkX, chunkZ, actualMinY, actualMaxY)
    local numericKey = self:getNumericKey(chunkX, chunkZ)
    local chunkData = self.chunkData[numericKey]
    if chunkData then
        chunkData.minY = actualMinY
        chunkData.maxY = actualMaxY
    end
end

-- ====================================================================
-- 脏区块管理（使用字符串键）
-- ====================================================================

---标记区块为脏（需要重建）
---优化：只有当相邻区块边界有实心方块时才标记相邻区块
---@param blockX number 方块X坐标
---@param blockY number 方块Y坐标
---@param blockZ number 方块Z坐标
function World:markChunkDirty(blockX, blockY, blockZ)
    local chunkX = floor(blockX / CHUNK_SIZE)
    local chunkZ = floor(blockZ / CHUNK_SIZE)
    local stringKey = self:getStringKey(chunkX, chunkZ)
    
    -- 当前区块总是标记
    self.dirtyChunks[stringKey] = { x = chunkX, z = chunkZ }
    
    -- 边界处理：只有相邻区块边界有实心方块才标记
    -- 优化：检查 blockY 及 ±1 层，覆盖透明方块（玻璃、树叶）的边缘情况
    local localX = blockX - chunkX * CHUNK_SIZE
    local localZ = blockZ - chunkZ * CHUNK_SIZE
    
    -- 辅助函数：检查相邻区块在指定位置是否有非空气方块（检查 y, y-1, y+1）
    local function hasAdjacentSolid(adjX, y, adjZ)
        if self:getBlock(adjX, y, adjZ) ~= AIR then return true end
        if y > 0 and self:getBlock(adjX, y - 1, adjZ) ~= AIR then return true end
        if y < WORLD_HEIGHT - 1 and self:getBlock(adjX, y + 1, adjZ) ~= AIR then return true end
        return false
    end
    
    -- -X 边界：检查相邻区块 (chunkX-1) 的 X=15 位置
    if localX == 0 then
        local adjX = (chunkX - 1) * CHUNK_SIZE + (CHUNK_SIZE - 1)
        if hasAdjacentSolid(adjX, blockY, blockZ) then
            local adjKey = self:getStringKey(chunkX - 1, chunkZ)
            self.dirtyChunks[adjKey] = { x = chunkX - 1, z = chunkZ }
        end
    -- +X 边界：检查相邻区块 (chunkX+1) 的 X=0 位置
    elseif localX == CHUNK_SIZE - 1 then
        local adjX = (chunkX + 1) * CHUNK_SIZE
        if hasAdjacentSolid(adjX, blockY, blockZ) then
            local adjKey = self:getStringKey(chunkX + 1, chunkZ)
            self.dirtyChunks[adjKey] = { x = chunkX + 1, z = chunkZ }
        end
    end
    
    -- -Z 边界：检查相邻区块 (chunkZ-1) 的 Z=15 位置
    if localZ == 0 then
        local adjZ = (chunkZ - 1) * CHUNK_SIZE + (CHUNK_SIZE - 1)
        if hasAdjacentSolid(blockX, blockY, adjZ) then
            local adjKey = self:getStringKey(chunkX, chunkZ - 1)
            self.dirtyChunks[adjKey] = { x = chunkX, z = chunkZ - 1 }
        end
    -- +Z 边界：检查相邻区块 (chunkZ+1) 的 Z=0 位置
    elseif localZ == CHUNK_SIZE - 1 then
        local adjZ = (chunkZ + 1) * CHUNK_SIZE
        if hasAdjacentSolid(blockX, blockY, adjZ) then
            local adjKey = self:getStringKey(chunkX, chunkZ + 1)
            self.dirtyChunks[adjKey] = { x = chunkX, z = chunkZ + 1 }
        end
    end

    -- L4: 对角 chunk（角落编辑时光会绕角影响对角区块；AO 旧逻辑只标正交 4 邻、漏对角，
    -- 光照传播必须补上，否则对角接缝处会出现光照断层）。角落编辑频率低，保守标。
    if (localX == 0 or localX == CHUNK_SIZE - 1) and (localZ == 0 or localZ == CHUNK_SIZE - 1) then
        local dcx = (localX == 0) and (chunkX - 1) or (chunkX + 1)
        local dcz = (localZ == 0) and (chunkZ - 1) or (chunkZ + 1)
        local adjKey = self:getStringKey(dcx, dcz)
        self.dirtyChunks[adjKey] = { x = dcx, z = dcz }
    end
end

---获取脏区块列表
---@return table 脏区块表
function World:getDirtyChunks()
    return self.dirtyChunks
end

---清除脏区块标记
---@param stringKey string 字符串键
function World:clearDirtyChunk(stringKey)
    self.dirtyChunks[stringKey] = nil
end

---获取脏区块数量
---@return number 脏区块数量
function World:getDirtyChunkCount()
    local count = 0
    for _ in pairs(self.dirtyChunks) do
        count = count + 1
    end
    return count
end

---标记所有区块为脏（用于材质包切换等场景）
function World:markAllChunksDirty()
    for stringKey, node in pairs(self.chunks) do
        local chunkX, chunkZ = stringKey:match("(-?%d+),(-?%d+)")
        chunkX, chunkZ = tonumber(chunkX), tonumber(chunkZ)
        self.dirtyChunks[stringKey] = { x = chunkX, z = chunkZ }
    end
end

---标记指定区域内的区块为脏，并重新计算高度范围
---用于批量放置方块后（如建筑生成）需要更新渲染
---@param x1 number 左边界（世界坐标）
---@param z1 number 前边界（世界坐标）
---@param x2 number 右边界（世界坐标）
---@param z2 number 后边界（世界坐标）
function World:markAreaDirtyAndRecalcHeight(x1, z1, x2, z2)
    local chunkX1 = floor(x1 / CHUNK_SIZE)
    local chunkZ1 = floor(z1 / CHUNK_SIZE)
    local chunkX2 = floor(x2 / CHUNK_SIZE)
    local chunkZ2 = floor(z2 / CHUNK_SIZE)
    
    local count = 0
    for cx = chunkX1, chunkX2 do
        for cz = chunkZ1, chunkZ2 do
            -- 标记区块为脏
            local stringKey = self:getStringKey(cx, cz)
            self.dirtyChunks[stringKey] = { x = cx, z = cz }
            
            -- 重新计算该区块的高度范围
            -- setBlockRaw 不会更新高度范围，导致新放置的高处方块不被渲染
            local numericKey = self:getNumericKey(cx, cz)
            local chunkData = self.chunkData[numericKey]
            if chunkData and chunkData.blocks then
                chunkData.minY, chunkData.maxY = self:computeHeightRange(chunkData)
                count = count + 1
            end
        end
    end
    
    return count
end

-- ====================================================================
-- 渲染区块管理（使用字符串键）
-- ====================================================================

---注册区块节点
---@param stringKey string 字符串键
---@param node Node 区块节点
function World:registerChunk(stringKey, node)
    self.chunks[stringKey] = node
end

---获取区块节点
---@param stringKey string 字符串键
---@return Node|nil 区块节点
function World:getChunk(stringKey)
    return self.chunks[stringKey]
end

---移除区块节点
---@param stringKey string 字符串键
function World:removeChunk(stringKey)
    if self.chunks[stringKey] then
        self.chunks[stringKey]:Remove()
        self.chunks[stringKey] = nil
    end
end

---获取区块数量
---@return number 区块数量
function World:getChunkCount()
    local count = 0
    for _ in pairs(self.chunks) do
        count = count + 1
    end
    return count
end

-- ====================================================================
-- 坐标转换
-- ====================================================================

---获取地面高度
---@param x number 世界坐标 X
---@param z number 世界坐标 Z
---@return number height 地面高度
function World:getGroundHeight(x, z)
    for y = WORLD_HEIGHT - 1, 0, -1 do
        if Blocks:isSolid(self:getBlock(x, y, z)) then
            return y + 1
        end
    end
    return 0
end

---世界坐标转换为方块坐标
---@param worldPos Vector3 世界坐标
---@return number, number, number 方块坐标 (bx, by, bz)
function World:worldToBlock(worldPos)
    return floor(worldPos.x / BLOCK_SIZE),
           floor(worldPos.y / BLOCK_SIZE),
           floor(worldPos.z / BLOCK_SIZE)
end

---方块坐标转换为世界坐标（方块中心）
---@param bx number 方块X坐标
---@param by number 方块Y坐标
---@param bz number 方块Z坐标
---@return Vector3 世界坐标
function World:blockToWorld(bx, by, bz)
    return Vector3(
        bx * BLOCK_SIZE + BLOCK_SIZE * 0.5,
        by * BLOCK_SIZE + BLOCK_SIZE * 0.5,
        bz * BLOCK_SIZE + BLOCK_SIZE * 0.5
    )
end

return World
