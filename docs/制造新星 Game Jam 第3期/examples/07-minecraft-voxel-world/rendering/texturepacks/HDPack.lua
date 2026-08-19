-- ====================================================================
-- rendering/texturepacks/HDPack.lua
-- HD 高清材质包 - PBR 渲染支持
-- 采用合并生成方案：一次遍历同时生成 Diffuse + Normal + Specular
-- ====================================================================

local TexturePackBase = require("rendering.texturepacks.TexturePackBase")

---@class HDPack : TexturePackBase
local HDPack = TexturePackBase.new({
    name = "hd",
    displayName = "HD PBR (32x32)",
    tileSize = 32,
    atlasSize = 512,
    tilesPerRow = 16,
    isPBR = true,  -- 标记为 PBR 材质包
})

-- 纹理缓存（避免重复生成）
HDPack._cachedTextures = nil

---重写 getFilterMode
---使用 FILTER_BILINEAR（不启用 mipmap）避免采样到相邻 tile
---FILTER_TRILINEAR 会在远处 mipmap 采样时扩展到相邻纹理
---@return number 滤波模式
function HDPack:getFilterMode()
    return FILTER_BILINEAR
end

---重写 generate()，合并生成三张贴图
---使用缓存避免重复生成
---@return table { diffuse: Texture2D, normal: Texture2D, specular: Texture2D }
function HDPack:generate()
    -- 检查缓存，避免重复生成纹理图集
    if self._cachedTextures then
        return self._cachedTextures
    end
    
    print("[HDPack] Creating HD PBR texture atlas...")
    
    -- 创建三张 Image
    local images = {
        diffuse = Image(),
        normal = Image(),
        specular = Image(),
    }
    images.diffuse:SetSize(self.atlasSize, self.atlasSize, 4)
    images.normal:SetSize(self.atlasSize, self.atlasSize, 4)
    images.specular:SetSize(self.atlasSize, self.atlasSize, 4)
    
    local tileSize = self.tileSize
    
    -- 先填充未使用区域（用中性色）
    self:fillUnusedTiles(images)
    
    -- Row 0: Grass top, Grass side, Dirt, Stone
    self:generateGrassTop(images, 0, 0, tileSize)
    self:generateGrassSide(images, tileSize, 0, tileSize)
    self:generateDirt(images, tileSize * 2, 0, tileSize)
    self:generateStone(images, tileSize * 3, 0, tileSize)
    
    -- Row 1: Wood top, Wood side, Leaves, Sand
    self:generateWoodTop(images, 0, tileSize, tileSize)
    self:generateWoodSide(images, tileSize, tileSize, tileSize)
    self:generateLeaves(images, tileSize * 2, tileSize, tileSize)
    self:generateSand(images, tileSize * 3, tileSize, tileSize)
    
    -- Row 2: Water, TallGrass, Torch
    self:generateWater(images, 0, tileSize * 2, tileSize)
    self:generateTallGrass(images, tileSize, tileSize * 2, tileSize)
    self:generateTorch(images, tileSize * 2, tileSize * 2, tileSize)
    
    -- Row 2: Flowers (Rose, Yellow, Blue) - 使用纯色
    -- Rose at {2,3} - 纯红色
    self:generateFlower(images, tileSize * 3, tileSize * 2, tileSize, {r=1.0, g=0.15, b=0.15}, "rose")
    -- Yellow Flower at {2,4} - 纯黄色
    self:generateFlower(images, tileSize * 4, tileSize * 2, tileSize, {r=1.0, g=0.9, b=0.1}, "simple")
    -- Blue Flower at {2,5} - 纯蓝色
    self:generateFlower(images, tileSize * 5, tileSize * 2, tileSize, {r=0.2, g=0.4, b=1.0}, "bulb")
    
    -- 不使用边缘挤出（会覆盖相邻 tile）
    -- 改用 UV padding 方案
    
    print("[HDPack] HD PBR texture atlas created!")
    
    -- 缓存生成的纹理，避免重复生成
    self._cachedTextures = {
        diffuse = self:createTexture(images.diffuse, true),
        normal = self:createTexture(images.normal, false),
        specular = self:createTexture(images.specular, false),
    }
    
    return self._cachedTextures
end

-- ============================================
-- PBR 方块生成方法
-- 合并生成 Diffuse + Normal + Specular
-- ============================================

---生成草地顶部 - PBR（四方连续）
function HDPack:generateGrassTop(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.9
    local normalStrength = 0.3
    
    -- 第一遍：生成 Diffuse + 记录高度 + 写 Specular
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 使用周期性噪声，确保边缘连续
            local noise = self:periodicSmoothNoise(x, y, tileSize, 42) * 0.08
            
            local r = 0.32 + noise
            local g = 0.72 + noise * 0.5
            local b = 0.22 + noise * 0.3
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    -- 第二遍：从高度图计算法线（已支持周期性边界）
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成草地侧面 - PBR（带垂挂草叶装饰）
function HDPack:generateGrassSide(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.9
    local normalStrength = 0.4
    local grassHeight = math.floor(tileSize * 0.15)  -- 顶部 15% 是草地层
    
    -- 生成草叶位置和长度（周期性，确保 X 轴连续）
    local grassBlades = {}
    local numBlades = math.floor(tileSize * 0.6)  -- 约 60% 密度的草叶
    for i = 1, numBlades do
        local bladeX = (i * 2 + math.floor(self:periodicNoise(i, 1, numBlades, 888) * 3)) % tileSize
        local bladeLength = math.floor(2 + self:periodicNoise(i, 2, numBlades, 999) * 0.5 * tileSize * 0.2)
        grassBlades[bladeX] = grassBlades[bladeX] or {}
        table.insert(grassBlades[bladeX], bladeLength)
    end
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- X轴使用周期性噪声
            local noise = self:periodicSmoothNoise(x, 0, tileSize, 43 + y) * 0.06
            local r, g, b
            local isGrassBlade = false
            
            -- 检查是否是草叶位置
            if grassBlades[x] then
                for _, bladeLen in ipairs(grassBlades[x]) do
                    if y >= grassHeight and y < grassHeight + bladeLen then
                        isGrassBlade = true
                        break
                    end
                end
            end
            
            if y < grassHeight then
                -- 顶部草地层
                local fade = y / grassHeight
                r = 0.30 + fade * 0.05 + noise
                g = 0.70 - fade * 0.05 + noise * 0.3
                b = 0.20 + noise * 0.2
            elseif isGrassBlade then
                -- 垂挂的草叶（绿色，稍暗）
                local bladeDepth = (y - grassHeight) / (tileSize * 0.3)
                r = 0.25 + noise * 0.5
                g = 0.55 - bladeDepth * 0.15 + noise * 0.3
                b = 0.15 + noise * 0.2
            else
                -- 泥土层
                local depth = (y - grassHeight) / (tileSize - grassHeight)
                r = 0.52 - depth * 0.08 + noise
                g = 0.36 - depth * 0.06 + noise * 0.5
                b = 0.20 - depth * 0.04 + noise * 0.3
            end
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成泥土 - PBR（四方连续）
function HDPack:generateDirt(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.95
    local normalStrength = 0.5
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 使用周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 123) * 0.1
            
            local r = 0.52 + noise
            local g = 0.36 + noise * 0.6
            local b = 0.20 + noise * 0.4
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成石头 - PBR（四方连续，明显凹凸）
function HDPack:generateStone(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.7
    local normalStrength = 2.0
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 使用周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 456) * 0.08
            local baseGray = 0.55 + noise
            
            -- 周期性裂缝（使用周期为 tileSize 的 sin/cos）
            local crack = 0
            local px = (x / tileSize) * 2 * math.pi * 2  -- 2 个周期
            local py = (y / tileSize) * 2 * math.pi * 2
            local crackPattern = math.sin(px) * math.cos(py)
            if math.abs(crackPattern) > 0.9 then
                crack = -0.05
            end
            
            local brightness = baseGray + crack
            images.diffuse:SetPixel(startX + x, startY + y, Color(brightness, brightness, brightness + 0.02, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = brightness
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成木头顶部（年轮） - PBR（年轮本身是圆心对称的）
function HDPack:generateWoodTop(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.6
    local normalStrength = 0.5
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            local centerX, centerY = tileSize / 2, tileSize / 2
            local dx, dy = x - centerX, y - centerY
            local dist = math.sqrt(dx * dx + dy * dy)
            
            local ringDist = dist % 6
            local ringIntensity = math.sin(ringDist * math.pi / 3) * 0.5 + 0.5
            
            local r = self:lerp(0.55, 0.70, ringIntensity)
            local g = self:lerp(0.40, 0.55, ringIntensity)
            local b = self:lerp(0.25, 0.35, ringIntensity)
            
            -- 使用周期性噪声添加细节
            local noise = self:periodicSmoothNoise(x, y, tileSize, 150) * 0.04
            images.diffuse:SetPixel(startX + x, startY + y, Color(r + noise, g + noise, b + noise, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = ringIntensity
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成木头侧面（木纹） - PBR（X轴四方连续）
function HDPack:generateWoodSide(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.6
    local normalStrength = 0.8
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 使用周期性条纹（确保 X 轴连续）
            local px = (x / tileSize) * 2 * math.pi * 4  -- 4 个完整周期
            local stripePhase = math.sin(px) * 0.5 + 0.5
            -- X轴周期性噪声
            local noise = self:periodicSmoothNoise(x, 0, tileSize, 789 + y) * 0.05
            
            local r = self:lerp(0.38, 0.48, stripePhase) + noise
            local g = self:lerp(0.26, 0.34, stripePhase) + noise * 0.7
            local b = self:lerp(0.14, 0.20, stripePhase) + noise * 0.5
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = stripePhase
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成树叶 - PBR（四方连续）
function HDPack:generateLeaves(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.85
    local normalStrength = 0.2
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 101112) * 0.15
            -- 周期性图案
            local px = (x / tileSize) * 2 * math.pi * 3
            local py = (y / tileSize) * 2 * math.pi * 3
            local pattern = math.sin(px) * math.cos(py) * 0.1
            
            local r = 0.18 + pattern + noise * 0.2
            local g = 0.52 + pattern + noise * 0.1
            local b = 0.14 + pattern + noise * 0.15
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成沙子 - PBR（四方连续）
function HDPack:generateSand(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.95
    local normalStrength = 0.4
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 131415) * 0.08
            
            local r = 0.88 + noise
            local g = 0.80 + noise * 0.8
            local b = 0.58 + noise * 0.5
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成水 - PBR（四方连续，低粗糙度，反光）
function HDPack:generateWater(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.1
    local normalStrength = 0.1
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 周期性波纹
            local px = (x / tileSize) * 2 * math.pi * 2
            local py = (y / tileSize) * 2 * math.pi * 2
            local wave = math.sin(px + py * 0.5) * 0.05
            -- 周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 200) * 0.03
            
            local r = 0.18 + wave + noise
            local g = 0.42 + wave + noise
            local b = 0.78 + wave * 0.3
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 0.85))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = wave + 0.5
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成装饰草 - PBR（交叉网格用，带透明通道）
---经典 Minecraft 风格：模仿原版像素布局，适配 32x32 分辨率
function HDPack:generateTallGrass(images, startX, startY, tileSize)
    local metallic, roughness = 0.0, 0.85
    
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            images.diffuse:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
            images.normal:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 1.0, 0.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 0.0))
        end
    end
    
    -- 高度图
    local heightMap = {}
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            heightMap[y][x] = 0.5
        end
    end
    
    -- 颜色调色板 (基于草地顶部颜色优化，更清爽，匹配 HD 草地)
    local colors = {
        [1] = { r = 0.25, g = 0.60, b = 0.18 }, -- 深绿 (阴影)
        [2] = { r = 0.32, g = 0.72, b = 0.22 }, -- 基底绿 (匹配草地)
        [3] = { r = 0.40, g = 0.80, b = 0.28 }, -- 亮绿 (高光)
        [4] = { r = 0.48, g = 0.88, b = 0.35 }, -- 顶端嫩绿
    }
    
    -- 定义像素图案 (16x16网格，会自动放大到32x32)
    -- 0=空, 1-4=颜色索引
    -- 模仿原版草的杂乱像素分布
    local pattern16x16 = {
        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}, -- Row 0 (Top)
        {0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0},
        {0,0,0,4,0,0,4,0,0,0,0,0,0,0,0,0},
        {4,0,0,3,0,0,4,0,0,0,0,4,0,4,0,0},
        {4,0,4,3,0,0,3,4,0,0,0,4,0,4,0,0}, -- Row 4
        {3,0,3,2,0,4,3,3,0,0,4,3,0,3,0,0},
        {3,0,3,2,0,3,2,3,0,0,3,3,0,3,0,0},
        {3,0,3,2,0,3,2,3,4,0,3,2,0,2,0,0},
        {3,0,2,1,0,3,2,2,3,4,2,2,0,2,0,0}, -- Row 8
        {2,0,2,1,0,3,2,2,3,3,2,1,0,2,4,0},
        {2,0,2,1,4,2,1,2,3,3,2,1,0,2,3,0},
        {2,0,2,1,3,2,1,2,2,3,2,1,0,2,3,0},
        {2,0,1,1,2,2,1,1,2,2,1,1,0,1,2,0}, -- Row 12
        {2,0,1,1,2,2,1,1,2,2,1,1,0,1,2,0},
        {1,0,1,1,2,1,1,1,1,2,1,1,0,1,1,4},
        {1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,3}, -- Row 15 (Bottom)
    }
    
    -- 缩放因子 (32/16 = 2)
    local scale = math.floor(tileSize / 16)
    
    -- 绘制像素
    for py = 0, 15 do
        for px = 0, 15 do
            local colorIdx = pattern16x16[py + 1][px + 1]
            if colorIdx > 0 then
                local color = colors[colorIdx]
                
                -- 在 32x32 图上绘制 2x2 的块
                for dy = 0, scale - 1 do
                    for dx = 0, scale - 1 do
                        local x = px * scale + dx
                        local y = py * scale + dy
                        
                        -- 添加一点点随机杂色，让大像素不那么单调
                        local noise = (math.random() - 0.5) * 0.05
                        local r = math.max(0, math.min(1, color.r + noise))
                        local g = math.max(0, math.min(1, color.g + noise))
                        local b = math.max(0, math.min(1, color.b + noise))
                        
                        -- 边缘像素稍微暗一点点
                        if dx == 0 or dx == scale - 1 or dy == 0 or dy == scale - 1 then
                            r = r * 0.95
                            g = g * 0.95
                            b = b * 0.95
                        end
                        
                        if x >= 0 and x < tileSize and y >= 0 and y < tileSize then
                            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
                            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
                            
                            -- 高度图：根据颜色索引决定高度（越亮越高）
                            heightMap[y][x] = 0.4 + colorIdx * 0.1
                        end
                    end
                end
            end
        end
    end
    
    -- 计算法线
    local normalStrength = 0.3
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local diffuseColor = images.diffuse:GetPixel(startX + x, startY + y)
            if diffuseColor.a > 0.5 then
                local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
                images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
            end
        end
    end
end

---生成火把纹理 - PBR（用于纹理图集，实际手持渲染使用模型）
function HDPack:generateTorch(images, startX, startY, tileSize)
    local metallic, roughness = 0.0, 0.85
    
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            images.diffuse:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
            images.normal:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 1.0, 0.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 0.0))
        end
    end
    
    -- 火把参数
    local centerX = math.floor(tileSize / 2)
    local stickWidth = math.max(2, math.floor(tileSize / 6))
    local stickHeight = math.floor(tileSize * 0.55)
    local flameHeight = math.floor(tileSize * 0.35)
    
    -- 木棍颜色
    local stickColor = { r = 0.5, g = 0.3, b = 0.15 }
    -- 火焰颜色
    local flameColors = {
        { r = 1.0, g = 0.3, b = 0.05 },  -- 外焰（橙红）
        { r = 1.0, g = 0.6, b = 0.1 },   -- 中焰（橙）
        { r = 1.0, g = 0.9, b = 0.3 },   -- 内焰（黄）
    }
    
    -- 绘制木棍（从底部往上）
    local stickStartY = tileSize - 1
    local stickEndY = tileSize - stickHeight
    for y = stickStartY, stickEndY, -1 do
        for dx = -stickWidth/2, stickWidth/2 do
            local px = centerX + math.floor(dx)
            if px >= 0 and px < tileSize then
                math.randomseed(px * 1234 + y * 5678)
                local noise = (math.random() - 0.5) * 0.1
                images.diffuse:SetPixel(startX + px, startY + y, Color(
                    stickColor.r + noise,
                    stickColor.g + noise * 0.5,
                    stickColor.b + noise * 0.3,
                    1.0
                ))
                images.normal:SetPixel(startX + px, startY + y, Color(0.5, 0.5, 1.0, 1.0))
                images.specular:SetPixel(startX + px, startY + y, Color(0.9, 0.0, 1.0, 1.0))
            end
        end
    end
    
    -- 绘制火焰（从木棍顶部往上）
    local flameStartY = stickEndY
    local flameEndY = stickEndY - flameHeight
    local flameMaxWidth = math.floor(tileSize / 3)
    
    for y = flameStartY, flameEndY, -1 do
        local progress = (flameStartY - y) / flameHeight
        -- 火焰逐渐变细
        local currentWidth = math.floor(flameMaxWidth * (1 - progress * 0.7))
        
        for dx = -currentWidth, currentWidth do
            local px = centerX + dx
            if px >= 0 and px < tileSize then
                -- 根据到中心的距离选择颜色
                local distFromCenter = math.abs(dx) / math.max(1, currentWidth)
                local colorIdx
                if distFromCenter > 0.6 then
                    colorIdx = 1  -- 外焰
                elseif distFromCenter > 0.3 then
                    colorIdx = 2  -- 中焰
                else
                    colorIdx = 3  -- 内焰
                end
                
                local fc = flameColors[colorIdx]
                images.diffuse:SetPixel(startX + px, startY + y, Color(fc.r, fc.g, fc.b, 1.0))
                images.normal:SetPixel(startX + px, startY + y, Color(0.5, 0.5, 1.0, 1.0))
                -- 火焰是自发光的，设置高发光
                images.specular:SetPixel(startX + px, startY + y, Color(0.2, 0.0, 1.0, 1.0))
            end
        end
    end
end

---生成花朵 - PBR
---@param baseColor table {r,g,b} 花朵主色调
---@param shape string 花朵形状 "rose", "simple", "bulb"
function HDPack:generateFlower(images, startX, startY, tileSize, baseColor, shape)
    local metallic, roughness = 0.0, 0.8
    
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            images.diffuse:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
            images.normal:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 1.0, 0.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 0.0))
        end
    end

    local heightMap = {}
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            heightMap[y][x] = 0.5
        end
    end

    -- 调色板 - 使用纯色，不做暗化处理
    local colors = {
        [1] = { r = 0.20, g = 0.55, b = 0.15 }, -- 茎绿色
        [2] = { r = 0.30, g = 0.70, b = 0.20 }, -- 叶亮绿
        [3] = { r = baseColor.r, g = baseColor.g, b = baseColor.b }, -- 花瓣主色
        [4] = { r = baseColor.r, g = baseColor.g, b = baseColor.b }, -- 花瓣主色
        [5] = { r = math.min(1, baseColor.r + 0.15), g = math.min(1, baseColor.g + 0.15), b = math.min(1, baseColor.b + 0.15) }, -- 花瓣高光（稍亮）
    }

    -- 图案定义 (16x16) - 所有图案以 px=7-8 为中心（16像素纹理的正中心）
    local pattern16x16 = {}
    
    if shape == "rose" then
        -- 玫瑰：居中版本，花瓣和茎都以 px=7-8 为中心
        pattern16x16 = {
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,3,4,4,3,0,0,0,0,0,0},
            {0,0,0,0,0,3,4,5,5,4,3,0,0,0,0,0},
            {0,0,0,0,0,4,5,5,5,5,4,0,0,0,0,0},
            {0,0,0,0,0,3,4,5,5,4,3,0,0,0,0,0},
            {0,0,0,0,0,0,3,4,4,3,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
        }
    elseif shape == "simple" then
        -- 简单花：居中版本，四瓣花以 px=7-8 为中心
        pattern16x16 = {
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,4,5,5,4,0,0,0,0,0,0},
            {0,0,0,0,0,4,5,4,4,5,4,0,0,0,0,0},
            {0,0,0,0,0,4,5,4,4,5,4,0,0,0,0,0},
            {0,0,0,0,0,0,4,5,5,4,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
        }
    else -- bulb
        -- 花苞：居中版本，以 px=7-8 为中心
        pattern16x16 = {
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,4,5,5,4,0,0,0,0,0,0},
            {0,0,0,0,0,4,5,5,5,5,4,0,0,0,0,0},
            {0,0,0,0,0,4,4,3,3,4,4,0,0,0,0,0},
            {0,0,0,0,0,0,4,3,3,4,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
        }
    end

    -- 缩放因子
    local scale = math.floor(tileSize / 16)
    
    -- 绘制像素
    for py = 0, 15 do
        for px = 0, 15 do
            local colorIdx = pattern16x16[py + 1][px + 1]
            if colorIdx > 0 then
                local color = colors[colorIdx]
                
                -- 在 32x32 图上绘制 2x2 的块
                for dy = 0, scale - 1 do
                    for dx = 0, scale - 1 do
                        local x = px * scale + dx
                        local y = py * scale + dy
                        
                        -- 直接使用纯色，不添加噪声
                        local r = color.r
                        local g = color.g
                        local b = color.b
                        
                        if x >= 0 and x < tileSize and y >= 0 and y < tileSize then
                            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
                            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
                            heightMap[y][x] = 0.4 + colorIdx * 0.1
                        end
                    end
                end
            end
        end
    end
    
    -- 计算法线
    local normalStrength = 0.3
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local diffuseColor = images.diffuse:GetPixel(startX + x, startY + y)
            if diffuseColor.a > 0.5 then
                local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
                images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
            end
        end
    end
end

---填充未使用的格子（使用中性色而非紫色）
function HDPack:fillUnusedTiles(images)
    local tileSize = self.tileSize
    for row = 0, self.tilesPerRow - 1 do
        for col = 0, self.tilesPerRow - 1 do
            -- 跳过已生成的格子
            -- Row 0: col 0-3 (Grass top/side, Dirt, Stone)
            -- Row 1: col 0-3 (Wood top/side, Leaves, Sand)
            -- Row 2: col 0-5 (Water, TallGrass, Torch, Rose, YellowFlower, BlueFlower)
            if not ((row == 0 and col < 4) or (row == 1 and col < 4) or (row == 2 and col < 6)) then
                local startX = col * tileSize
                local startY = row * tileSize
                for y = 0, tileSize - 1 do
                    for x = 0, tileSize - 1 do
                        -- 使用中性灰色而非紫色（防止 mipmap 采样问题）
                        images.diffuse:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 0.5, 1.0))
                        -- 默认平面法线
                        images.normal:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 1.0, 1.0))
                        -- 默认粗糙度 1.0
                        images.specular:SetPixel(startX + x, startY + y, Color(1.0, 0.0, 1.0, 1.0))
                    end
                end
            end
        end
    end
end

return HDPack
