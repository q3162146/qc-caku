-- ====================================================================
-- rendering/texturepacks/ClassicPack.lua
-- 经典材质包 - 像素化 Minecraft 风格纹理
-- ====================================================================

local TexturePackBase = require("rendering.texturepacks.TexturePackBase")

---@class ClassicPack : TexturePackBase
local ClassicPack = TexturePackBase.new({
    name = "classic",
    displayName = "Classic (16x16)",
    tileSize = 16,
    atlasSize = 256,
    tilesPerRow = 16,
})

---重写 getFilterMode，使用 FILTER_NEAREST 保持像素锐利
---@return number 滤波模式
function ClassicPack:getFilterMode()
    return FILTER_NEAREST
end

---创建图像（重写基类方法）
---@return Image 生成的图像
function ClassicPack:createImage()
    print("[ClassicPack] Creating texture atlas...")
    
    local image = Image()
    image:SetSize(self.atlasSize, self.atlasSize, 4)  -- RGBA
    
    local tileSize = self.tileSize
    
    -- Row 0: Grass top, Grass side, Dirt, Stone
    self:generateGrassTop(image, 0, 0, tileSize)
    self:generateGrassSide(image, tileSize, 0, tileSize)
    self:generateDirt(image, tileSize * 2, 0, tileSize)
    self:generateStone(image, tileSize * 3, 0, tileSize)
    
    -- Row 1: Wood top, Wood side, Leaves, Sand
    local row1Y = tileSize
    self:generateWoodTop(image, 0, row1Y, tileSize)
    self:generateWoodSide(image, tileSize, row1Y, tileSize)
    self:generateLeaves(image, tileSize * 2, row1Y, tileSize)
    self:generateSand(image, tileSize * 3, row1Y, tileSize)
    
    -- Row 2: Water, TallGrass, Torch, Flowers
    local row2Y = tileSize * 2
    self:generateWater(image, 0, row2Y, tileSize)
    self:generateTallGrass(image, tileSize, row2Y, tileSize)
    self:generateTorch(image, tileSize * 2, row2Y, tileSize)
    -- 花纹理：Rose at {2,3}, Yellow at {2,4}, Blue at {2,5}
    self:generateFlower(image, tileSize * 3, row2Y, tileSize, {r=0.9, g=0.15, b=0.15})   -- Rose
    self:generateFlower(image, tileSize * 4, row2Y, tileSize, {r=1.0, g=0.9, b=0.1})     -- Yellow
    self:generateFlower(image, tileSize * 5, row2Y, tileSize, {r=0.2, g=0.4, b=1.0})     -- Blue
    
    -- 填充未使用的区域
    self:fillUnusedTiles(image, tileSize)
    
    print("[ClassicPack] Texture atlas created!")
    return image
end

-- ============================================
-- 纹理生成方法（从 TextureAtlas.lua 迁移）
-- ============================================

---生成草地顶部纹理
function ClassicPack:generateGrassTop(image, startX, startY, tileSize)
    math.randomseed(42)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local noise = (math.random() - 0.5) * 0.3
            local r = 0.35 + noise * 0.2
            local g = 0.75 + noise * 0.1
            local b = 0.25 + noise * 0.15
            image:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
        end
    end
end

---生成草地侧面纹理
function ClassicPack:generateGrassSide(image, startX, startY, tileSize)
    math.randomseed(43)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            if y < 4 then
                local grassHeight = 3 + (math.sin(x * 0.8) > 0.3 and 1 or 0)
                if y < grassHeight then
                    local noise = (math.random() - 0.5) * 0.2
                    image:SetPixel(startX + x, startY + y, Color(0.35 + noise, 0.75 + noise * 0.5, 0.25 + noise * 0.3, 1.0))
                else
                    local noise = (math.random() - 0.5) * 0.25
                    image:SetPixel(startX + x, startY + y, Color(0.55 + noise, 0.38 + noise * 0.7, 0.22 + noise * 0.5, 1.0))
                end
            else
                local noise = (math.random() - 0.5) * 0.25
                image:SetPixel(startX + x, startY + y, Color(0.55 + noise, 0.38 + noise * 0.7, 0.22 + noise * 0.5, 1.0))
            end
        end
    end
end

---生成泥土纹理
function ClassicPack:generateDirt(image, startX, startY, tileSize)
    math.randomseed(123)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local noise = (math.random() - 0.5) * 0.3
            image:SetPixel(startX + x, startY + y, Color(0.55 + noise, 0.38 + noise * 0.7, 0.22 + noise * 0.5, 1.0))
        end
    end
end

---生成石头纹理
function ClassicPack:generateStone(image, startX, startY, tileSize)
    math.randomseed(456)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local noise = (math.random() - 0.5) * 0.25
            local baseGray = 0.5 + noise
            local crack = 0
            if (x + y) % 7 == 0 or (x * 2 + y) % 11 == 0 then
                crack = -0.1
            end
            image:SetPixel(startX + x, startY + y, Color(baseGray + crack, baseGray + crack, baseGray + crack + 0.02, 1.0))
        end
    end
end

---生成木头顶部纹理（年轮）
function ClassicPack:generateWoodTop(image, startX, startY, tileSize)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local centerX, centerY = tileSize / 2, tileSize / 2
            local dx, dy = x - centerX, y - centerY
            local dist = math.sqrt(dx * dx + dy * dy)
            local ringDist = dist % 4
            
            local baseColor = Color(0.65, 0.52, 0.32)
            if ringDist < 1.2 and dist > 2 then
                baseColor = Color(0.45, 0.32, 0.18)
            end
            
            local noise = (math.random() - 0.5) * 0.1
            image:SetPixel(startX + x, startY + y, Color(baseColor.r + noise, baseColor.g + noise, baseColor.b + noise, 1.0))
        end
    end
end

---生成木头侧面纹理（树皮）
function ClassicPack:generateWoodSide(image, startX, startY, tileSize)
    math.randomseed(789)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local stripeIntensity = (x % 4 < 2) and 0.0 or 0.08
            local noise = (math.random() - 0.5) * 0.15
            image:SetPixel(startX + x, startY + y, Color(
                0.4 + stripeIntensity + noise,
                0.28 + stripeIntensity * 0.7 + noise * 0.7,
                0.15 + stripeIntensity * 0.5 + noise * 0.5,
                1.0
            ))
        end
    end
end

---生成树叶纹理（改进版：减少密集感，使用更大的色块）
function ClassicPack:generateLeaves(image, startX, startY, tileSize)
    math.randomseed(101112)
    
    -- 基础绿色
    local baseR, baseG, baseB = 0.22, 0.58, 0.18
    
    -- 第一遍：用 2x2 或 3x3 的块来生成基础变化，避免逐像素噪点
    local blockSize = 2  -- 2x2 像素块
    for by = 0, math.ceil(tileSize / blockSize) - 1 do
        for bx = 0, math.ceil(tileSize / blockSize) - 1 do
            -- 每个块有一个基础变化值
            local blockNoise = (math.random() - 0.5) * 0.15
            -- 10% 概率是暗块（而不是15%的单像素）
            local isDark = math.random() < 0.10
            local darkAmount = isDark and -0.12 or 0
            
            -- 填充整个块
            for dy = 0, blockSize - 1 do
                for dx = 0, blockSize - 1 do
                    local px = bx * blockSize + dx
                    local py = by * blockSize + dy
                    if px < tileSize and py < tileSize then
                        -- 块内部微小变化
                        local microNoise = (math.random() - 0.5) * 0.05
                        local r = baseR + blockNoise * 0.3 + darkAmount + microNoise
                        local g = baseG + blockNoise * 0.2 + darkAmount + microNoise
                        local b = baseB + blockNoise * 0.2 + darkAmount + microNoise
                        image:SetPixel(startX + px, startY + py, Color(r, g, b, 1.0))
                    end
                end
            end
        end
    end
    
    -- 第二遍：添加一些亮点（高光），让树叶更有层次感
    for i = 1, math.floor(tileSize * 0.8) do
        local hx = math.random(0, tileSize - 2)
        local hy = math.random(0, tileSize - 2)
        -- 1x1 或 2x1 的亮点
        local highlightR = baseR + 0.15
        local highlightG = baseG + 0.12
        local highlightB = baseB + 0.08
        image:SetPixel(startX + hx, startY + hy, Color(highlightR, highlightG, highlightB, 1.0))
    end
end

---生成沙子纹理
function ClassicPack:generateSand(image, startX, startY, tileSize)
    math.randomseed(131415)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local noise = (math.random() - 0.5) * 0.2
            local grain = math.random() > 0.9 and -0.1 or 0
            image:SetPixel(startX + x, startY + y, Color(
                0.85 + noise + grain,
                0.78 + noise * 0.9 + grain,
                0.55 + noise * 0.7 + grain,
                1.0
            ))
        end
    end
end

---生成水纹理
function ClassicPack:generateWater(image, startX, startY, tileSize)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local wave = math.sin(x * 0.4 + y * 0.2) * 0.1
            local noise = (math.random() - 0.5) * 0.1
            image:SetPixel(startX + x, startY + y, Color(
                0.2 + wave + noise,
                0.4 + wave + noise,
                0.8 + wave * 0.5,
                0.8  -- 半透明
            ))
        end
    end
end

---生成装饰草纹理（交叉网格用）
---像素风格：底部连接，向上分叉的草丛
function ClassicPack:generateTallGrass(image, startX, startY, tileSize)
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            image:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
        end
    end
    
    -- 草的颜色
    local darkGreen = { r = 0.28, g = 0.65, b = 0.20 }   -- 底部深绿
    local midGreen = { r = 0.35, g = 0.75, b = 0.25 }    -- 中间绿
    local lightGreen = { r = 0.42, g = 0.85, b = 0.30 }  -- 顶部亮绿
    
    -- 底部连接的高度（占总高度的比例）
    local baseHeight = math.floor(tileSize * 0.25)  -- 底部25%是连接的
    local totalHeight = math.floor(tileSize * 0.85) -- 总高度85%
    
    -- 草叶宽度
    local bladeWidth = math.max(2, math.floor(tileSize / 8))
    
    -- 定义草叶（从底部连接处分叉出去）
    local bladeCount = 4
    local blades = {}
    for i = 1, bladeCount do
        local centerX = math.floor((i - 0.5) * tileSize / bladeCount)
        -- 高度交错：两边稍矮
        local heightMult = 1 - math.abs(i - (bladeCount + 1) / 2) / bladeCount * 0.4
        local height = math.floor((totalHeight - baseHeight) * heightMult)
        table.insert(blades, { x = centerX, height = height })
    end
    
    -- 1. 绘制底部连接部分（横向连续）
    local baseLeft = blades[1].x - 1
    local baseRight = blades[#blades].x + bladeWidth
    for y = tileSize - 1, tileSize - baseHeight, -1 do
        local heightRatio = (tileSize - 1 - y) / baseHeight
        -- 颜色从深到中
        local r = darkGreen.r + (midGreen.r - darkGreen.r) * heightRatio
        local g = darkGreen.g + (midGreen.g - darkGreen.g) * heightRatio
        local b = darkGreen.b + (midGreen.b - darkGreen.b) * heightRatio
        
        for x = baseLeft, baseRight do
            if x >= 0 and x < tileSize then
                image:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            end
        end
    end
    
    -- 2. 绘制每根草叶（从底部连接处向上延伸）
    for i, blade in ipairs(blades) do
        for y = tileSize - baseHeight - 1, tileSize - baseHeight - blade.height, -1 do
            local heightRatio = (tileSize - baseHeight - 1 - y) / blade.height
            
            -- 颜色从中绿到亮绿
            local r = midGreen.r + (lightGreen.r - midGreen.r) * heightRatio
            local g = midGreen.g + (lightGreen.g - midGreen.g) * heightRatio
            local b = midGreen.b + (lightGreen.b - midGreen.b) * heightRatio
            
            -- 草叶宽度（顶部变尖）
            local currentWidth = bladeWidth
            if heightRatio > 0.7 then
                currentWidth = math.max(1, bladeWidth - 1)
            end
            
            -- 绘制草叶
            for w = 0, currentWidth - 1 do
                local px = blade.x + w
                if px >= 0 and px < tileSize then
                    -- 边缘稍暗
                    local edgeDark = (w == 0 or w == currentWidth - 1) and 0.92 or 1.0
                    image:SetPixel(startX + px, startY + y, Color(r * edgeDark, g * edgeDark, b * edgeDark, 1.0))
                end
            end
        end
    end
end

---生成花纹理（用于交叉网格渲染）
---@param baseColor table {r, g, b} 花朵主色调
function ClassicPack:generateFlower(image, startX, startY, tileSize, baseColor)
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            image:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
        end
    end
    
    -- 颜色定义
    local stemColor = { r = 0.25, g = 0.60, b = 0.18 }   -- 茎绿色
    local leafColor = { r = 0.35, g = 0.75, b = 0.22 }   -- 叶子亮绿
    
    -- 花朵尺寸
    local flowerSize = math.max(4, math.floor(tileSize * 0.4))
    local stemWidth = math.max(1, math.floor(tileSize / 8))
    local stemHeight = math.floor(tileSize * 0.6)
    local centerX = math.floor(tileSize / 2)
    
    -- 绘制茎（从底部往上）
    local stemStartY = tileSize - 1
    local stemEndY = tileSize - stemHeight
    for y = stemStartY, stemEndY, -1 do
        for dx = 0, stemWidth - 1 do
            local px = centerX - math.floor(stemWidth / 2) + dx
            if px >= 0 and px < tileSize then
                local noise = (math.random() - 0.5) * 0.05
                image:SetPixel(startX + px, startY + y, Color(
                    stemColor.r + noise,
                    stemColor.g + noise,
                    stemColor.b + noise,
                    1.0
                ))
            end
        end
        
        -- 添加叶子（茎的中部两侧）
        local midStem = (stemStartY + stemEndY) / 2
        if math.abs(y - midStem) < 2 then
            -- 左叶
            local lx = centerX - math.floor(stemWidth / 2) - 1
            if lx >= 0 then
                image:SetPixel(startX + lx, startY + y, Color(leafColor.r, leafColor.g, leafColor.b, 1.0))
            end
            -- 右叶
            local rx = centerX + math.floor(stemWidth / 2) + 1
            if rx < tileSize then
                image:SetPixel(startX + rx, startY + y, Color(leafColor.r, leafColor.g, leafColor.b, 1.0))
            end
        end
    end
    
    -- 绘制花朵（简单圆形）
    local flowerCenterY = stemEndY - math.floor(flowerSize / 2)
    local radius = math.floor(flowerSize / 2)
    
    for dy = -radius, radius do
        for dx = -radius, radius do
            local distSq = dx * dx + dy * dy
            if distSq <= radius * radius then
                local px = centerX + dx
                local py = flowerCenterY + dy
                if px >= 0 and px < tileSize and py >= 0 and py < tileSize then
                    -- 中心稍亮
                    local distFactor = math.sqrt(distSq) / radius
                    local brightness = 1.0 - distFactor * 0.2
                    image:SetPixel(startX + px, startY + py, Color(
                        baseColor.r * brightness,
                        baseColor.g * brightness,
                        baseColor.b * brightness,
                        1.0
                    ))
                end
            end
        end
    end
end

---生成火把纹理（用于纹理图集，实际手持渲染使用顶点色）
function ClassicPack:generateTorch(image, startX, startY, tileSize)
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            image:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
        end
    end
    
    -- 火把参数
    local centerX = math.floor(tileSize / 2)
    local stickWidth = math.max(2, math.floor(tileSize / 8))
    local stickHeight = math.floor(tileSize * 0.6)
    local flameHeight = math.floor(tileSize * 0.35)
    
    -- 木棍颜色
    local stickColor = Color(0.5, 0.3, 0.15, 1.0)
    -- 火焰颜色
    local flameOrange = Color(1.0, 0.6, 0.1, 1.0)
    local flameYellow = Color(1.0, 0.9, 0.3, 1.0)
    
    -- 绘制木棍（从底部往上）
    local stickStartY = tileSize - 1
    local stickEndY = tileSize - stickHeight
    for y = stickStartY, stickEndY, -1 do
        for dx = -stickWidth/2, stickWidth/2 do
            local px = centerX + math.floor(dx)
            if px >= 0 and px < tileSize then
                -- 木棍颜色有轻微变化
                local noise = (math.random() - 0.5) * 0.1
                image:SetPixel(startX + px, startY + y, Color(
                    stickColor.r + noise,
                    stickColor.g + noise * 0.5,
                    stickColor.b + noise * 0.3,
                    1.0
                ))
            end
        end
    end
    
    -- 绘制火焰（从木棍顶部往上）
    local flameStartY = stickEndY
    local flameEndY = stickEndY - flameHeight
    local flameMaxWidth = math.floor(tileSize / 4)
    
    for y = flameStartY, flameEndY, -1 do
        local progress = (flameStartY - y) / flameHeight
        -- 火焰逐渐变细
        local currentWidth = math.max(1, math.floor(flameMaxWidth * (1 - progress * 0.7)))
        
        -- 颜色从橙色渐变到黄色
        local r = flameOrange.r + (flameYellow.r - flameOrange.r) * progress
        local g = flameOrange.g + (flameYellow.g - flameOrange.g) * progress
        local b = flameOrange.b + (flameYellow.b - flameOrange.b) * progress
        
        for dx = -currentWidth, currentWidth do
            local px = centerX + dx
            if px >= 0 and px < tileSize then
                -- 添加一些随机性使火焰更自然
                local noise = (math.random() - 0.5) * 0.1
                image:SetPixel(startX + px, startY + y, Color(
                    math.min(1, r + noise),
                    math.min(1, g + noise * 0.5),
                    b,
                    1.0
                ))
            end
        end
    end
end

---填充未使用的格子
function ClassicPack:fillUnusedTiles(image, tileSize)
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
                        image:SetPixel(startX + x, startY + y, Color(0.3, 0.3, 0.3, 1.0))
                    end
                end
            end
        end
    end
end

return ClassicPack
