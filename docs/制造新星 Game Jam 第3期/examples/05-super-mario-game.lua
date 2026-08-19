-- ====================================================================
-- SuperMario.lua - 超级马里奥兄弟克隆版
-- ====================================================================
-- 
-- 这是一个完整的超级马里奥游戏实现，展示如何使用 NanoVG 和瓦片地图
-- 构建一个复杂的 2D 平台游戏
-- 
-- 【架构说明】:
-- 
-- 1. 碰撞检测方式:
--    本游戏使用**瓦片地图碰撞检测**而不是 Box2D 物理系统
--    原因: 超级马里奥的碰撞是基于网格的，瓦片地图更合适
--    
-- 2. 坐标系统:
--    - 世界坐标: 像素为单位 (x, y)
--    - 瓦片坐标: 网格索引 (tileX, tileY)，从 1 开始（Lua 数组）
--    - 屏幕坐标: 世界坐标 - cameraX
-- 
-- 3. 游戏状态机:
--    STATE_MENU -> STATE_PLAYING -> STATE_GAMEOVER/STATE_WIN
-- 
-- 4. 渲染方式:
--    使用 NanoVG 绘制所有图形（像素风格的马里奥精灵）
--    渲染在 NanoVGRender 事件中
-- 
-- 【关键注意事项】:
-- 
-- ⚠️ Lua 数组索引从 1 开始:
--    - level[1][1] 是左上角
--    - 像素坐标转瓦片坐标需要 +1: math.floor(x / TILE_SIZE) + 1
--    - 瓦片坐标转像素坐标需要 -1: (tileX - 1) * TILE_SIZE
-- 
-- ⚠️ eventData 访问方式:
--    - 正确: eventData["Key"]:GetInt()
--    - 错误: eventData:GetInt("Key")
-- 
-- ⚠️ NanoVG 字体初始化:
--    - 必须先 nvgCreateFont() 再使用 nvgText()
--    - 每次绘制前调用 nvgFontFace() 设置字体
-- 
-- 【复杂度说明】:
-- 
-- 本示例是一个**完整的游戏实现** (2000+ 行)，复杂度较高
-- 如果你是新手，建议先学习：
-- - Box2DPlatformer.lua (物理系统基础)
-- - FlappyBird.lua (简单游戏循环)
-- 
-- ====================================================================

-- 本游戏是完全独立的实现，不依赖 Sample.lua
-- （如果你的游戏需要 Sample.lua 的功能，如创建 Logo、Console 等，可以引用它）

-- 虚拟控件库（移动端触摸支持）
require "urhox-libs.UI.VirtualControls"

-- ====================================================================
-- 游戏常量
-- ====================================================================
local GRAVITY = 1800
local MARIO_SPEED = 200
local MARIO_JUMP_SPEED = 706  -- Reduced by 30% (1008 * 0.7) with double jump support
local MARIO_RUN_SPEED = 300
local ENEMY_SPEED = 50
local TILE_SIZE = 40  -- Increased from 32 to make everything bigger

-- Screen dimensions (will be updated dynamically)
local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720

-- Game states
local STATE_MENU = 0
local STATE_PLAYING = 1
local STATE_GAMEOVER = 2
local STATE_WIN = 3

-- Global game variables
local gameState = STATE_MENU
local score = 0
local coins = 0
local lives = 3
local time = 400
local timeCounter = 0
local cameraX = 0
local cameraY = 0

-- Mario state
local mario = {}

-- Level data
local level = {}
local levelWidth = 200
local levelHeight = 22  -- Will be recalculated based on screen height
local groundLevel = 0    -- Will be set dynamically
local pipes = {}
local questionBlocks = {}
local flagPole = {}
local flagY = 8

-- Entities
local entities = {}
local coins_entities = {}
local powerups = {}
local particles = {}

-- Input
local input_state = {
    left = false,
    right = false,
    jump = false,
    run = false,
    jumpPressed = false
}

-- Virtual controls (for mobile/touch)
local vc_joystick = nil
local vc_jumpBtn = nil
local vc_runBtn = nil
local vc_jumpWasPressed = false  -- Track previous frame state for edge detection

-- NanoVG Context
local nvgContext = nil

function Start()
    print("Starting Super Mario game...")

    -- Create NanoVG context
    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end
    print("NanoVG context created successfully")

    -- Load font for NanoVG (use full path)
    local fontPath = fileSystem:GetProgramDir() .. "Data/Fonts/MiSans-Regular.ttf"
    print("Loading font from: " .. fontPath)

    if nvgCreateFont(nvgContext, "sans", fontPath) == -1 then
        print("ERROR: Could not load font from " .. fontPath)
        return
    end

    -- Create bold font alias (same font)
    nvgCreateFont(nvgContext, "sans-bold", fontPath)

    print("Fonts loaded successfully")

    -- Initialize game state
    gameState = STATE_MENU
    score = 0
    coins = 0
    lives = 3
    time = 400
    timeCounter = 0
    cameraX = 0
    cameraY = 0

    -- Initialize level first (to calculate groundLevel)
    CreateLevel()

    -- Initialize Mario (place him at ground level)
    local marioHeight = 42  -- Increased by 50% (28 * 1.5)
    mario = {
        x = 100,
        y = (groundLevel - 1) * TILE_SIZE - marioHeight, -- Place above ground (subtract mario height)
        vx = 0,
        vy = 0,
        width = 36,  -- Increased by 50% (24 * 1.5) for larger sprite
        height = marioHeight,
        onGround = false,
        facing = 1,
        powerup = 0,
        invincible = 0,
        dead = false,
        animFrame = 0,
        animTime = 0,
        jumpsLeft = 2  -- Total jump count: 2 jumps before needing to land
    }

    SpawnEnemies()

    -- Subscribe to events
    SubscribeToEvent("Update", "HandleUpdate")
    -- 通过 NanoVGRender 事件渲染，让 NanoVGAdapter 管理渲染顺序
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("KeyUp", "HandleKeyUp")

    -- Create virtual controls for touch/mobile support
    CreateVirtualControls()

    print("Super Mario game started!")
end

function CreateVirtualControls()
    -- Initialize VirtualControls system
    VirtualControls.Initialize()

    -- Left side: Joystick for movement (left/right only)
    vc_joystick = VirtualControls.CreateJoystick({
        position = Vector2(150, -150),
        alignment = {HA_LEFT, VA_BOTTOM},
        baseRadius = 80,
        knobRadius = 35,
        moveRadius = 50,
        deadZone = 0.2,
        opacity = 0.6,
        activeOpacity = 0.9,
        keyBinding = "WASD",  -- PC keyboard support
    })

    -- Right side: Jump button (bottom)
    vc_jumpBtn = VirtualControls.CreateButton({
        position = Vector2(-100, -100),
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = 50,
        label = "Jump",
        opacity = 0.6,
        activeOpacity = 0.9,
        color = {100, 200, 255},
        pressedColor = {150, 230, 255},
        keyBinding = "SPACE",
    })

    -- Right side: Run button (above jump button, toggle mode)
    vc_runBtn = VirtualControls.CreateButton({
        position = Vector2(-100, -230),
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = 40,
        label = "Run",
        opacity = 0.5,
        activeOpacity = 0.85,
        color = {255, 180, 100},
        pressedColor = {255, 220, 150},
        toggle = true,  -- Toggle mode: tap to enable/disable
        keyBinding = {key = KEY_LSHIFT, label = "Shift"},
    })

    print("[SuperMario] Virtual controls created")
end

-- ====================================================================
-- 创建关卡
-- ====================================================================
-- 
-- 瓦片地图说明:
-- - level[y][x]: 二维数组，存储瓦片类型
-- - 0 = 空气, 1 = 地面, 2 = 砖块, 3 = 问号方块, 4 = 管道, 5 = 云朵
-- 
-- ⚠️ 重要: Lua 数组索引从 1 开始
-- - level[1][1] 是左上角第一个瓦片
-- - 循环必须用 for y = 1, height do (不是 0, height-1)
-- 
function CreateLevel()
    -- 根据屏幕高度计算关卡高度
    local graphics = GetGraphics()
    local screenHeight = graphics:GetHeight()
    levelHeight = math.floor(screenHeight / TILE_SIZE)
    groundLevel = levelHeight - 2  -- 地面从底部向上第3行开始

    -- 初始化空关卡（全部填充为 0 = 空气）
    level = {}
    for y = 1, levelHeight do  -- ⚠️ 从 1 开始，不是 0
        level[y] = {}
        for x = 1, levelWidth do
            level[y][x] = 0
        end
    end

    -- Ground level (bottom 3 rows)
    for x = 1, levelWidth do
        level[groundLevel][x] = 1
        level[groundLevel + 1][x] = 1
        level[groundLevel + 2][x] = 1
    end

    -- Add pits
    for x = 70, 74 do
        level[groundLevel][x] = 0
        level[groundLevel + 1][x] = 0
        level[groundLevel + 2][x] = 0
    end

    for x = 155, 158 do
        level[groundLevel][x] = 0
        level[groundLevel + 1][x] = 0
        level[groundLevel + 2][x] = 0
    end

    -- Question blocks and bricks (relative to ground)
    local platformHeight = groundLevel - 5
    for x = 20, 23 do
        level[platformHeight][x] = 2
    end
    level[platformHeight][22] = 3

    level[platformHeight][80] = 3
    level[platformHeight][85] = 3
    level[platformHeight - 4][83] = 3

    -- Brick stairs
    for i = 0, 7 do
        for j = 0, i do
            level[groundLevel - 1 - j][135 + i] = 2
        end
    end

    for i = 0, 7 do
        for j = 0, 7 - i do
            level[groundLevel - 1 - j][143 + i] = 2
        end
    end

    -- Floating platforms
    for x = 45, 48 do
        level[platformHeight - 1][x] = 2
    end

    for x = 55, 57 do
        level[platformHeight - 3][x] = 2
    end

    for x = 95, 98 do
        level[platformHeight - 2][x] = 2
    end

    -- Pipes (relative to ground)
    pipes = {
        {x = 30, y = groundLevel - 2, height = 2},
        {x = 40, y = groundLevel - 3, height = 3},
        {x = 60, y = groundLevel - 3, height = 3},
        {x = 180, y = groundLevel - 2, height = 2}
    }

    for _, pipe in ipairs(pipes) do
        for h = 0, pipe.height - 1 do
            level[pipe.y + h][pipe.x] = 4
            level[pipe.y + h][pipe.x + 1] = 4
        end
    end

    -- Clouds decoration
    local cloudPositions = {{15, 5}, {35, 4}, {55, 6}, {75, 5}, {95, 4}, {115, 5}}
    for _, pos in ipairs(cloudPositions) do
        for dx = 0, 3 do
            level[pos[2]][pos[1] + dx] = 5
        end
    end

    -- Flag pole at end (relative to ground)
    local flagHeight = math.floor((groundLevel - 5) * 0.6)
    flagPole = {x = 195, y = flagHeight, height = groundLevel - flagHeight}
    flagY = flagPole.y

    -- Question block data (using dynamic coordinates)
    questionBlocks = {}
    questionBlocks["22_" .. platformHeight] = {type = "coin", used = false}
    questionBlocks["80_" .. platformHeight] = {type = "powerup", used = false}
    questionBlocks["85_" .. platformHeight] = {type = "coin", used = false}
    questionBlocks["83_" .. (platformHeight - 4)] = {type = "coin", used = false}
end

function SpawnEnemies()
    entities = {}
    local enemyHeight = 28
    local groundY = (groundLevel - 1) * TILE_SIZE - enemyHeight -- Y position above ground (subtract enemy height)
    local enemyData = {
        {x = 600, y = groundY, type = "goomba", dir = -1},
        {x = 800, y = groundY, type = "goomba", dir = 1},
        {x = 1000, y = groundY, type = "koopa", dir = -1},
        {x = 1300, y = groundY, type = "goomba", dir = 1},
        {x = 1500, y = groundY, type = "goomba", dir = -1},
        {x = 1800, y = groundY, type = "koopa", dir = 1},
        {x = 2200, y = groundY, type = "goomba", dir = -1},
        {x = 2500, y = groundY, type = "goomba", dir = 1},
        {x = 2900, y = groundY, type = "koopa", dir = -1},
        {x = 3500, y = groundY, type = "goomba", dir = 1},
        {x = 4000, y = groundY, type = "koopa", dir = -1}
    }

    for _, e in ipairs(enemyData) do
        table.insert(entities, {
            x = e.x,
            y = e.y,
            vx = e.dir * ENEMY_SPEED,  -- Use specified direction
            vy = 0,
            width = 24,  -- Reduced from 32 to make collision more forgiving
            height = 28, -- Reduced from 32 to make collision more forgiving
            type = e.type,
            dead = false,
            stomped = false,
            animFrame = 0,
            animTime = 0
        })
    end
end

-- ====================================================================
-- 输入处理
-- ====================================================================

function HandleKeyDown(eventType, eventData)
    -- ✅ 正确的 eventData 访问方式: eventData["字段名"]:Get类型()
    local key = eventData["Key"]:GetInt()

    if gameState == STATE_MENU then
        if key == KEY_SPACE or key == KEY_RETURN then
            gameState = STATE_PLAYING
        end
    elseif gameState == STATE_PLAYING then
        if key == KEY_LEFT or key == KEY_A then
            input_state.left = true
        end
        if key == KEY_RIGHT or key == KEY_D then
            input_state.right = true
        end
        if key == KEY_SPACE or key == KEY_W or key == KEY_UP then
            -- Set jump flag (will be consumed in UpdateGame)
            input_state.jump = true
            input_state.jumpPressed = true
        end
        if key == KEY_LSHIFT or key == KEY_RSHIFT then
            input_state.run = true
        end
    elseif gameState == STATE_GAMEOVER or gameState == STATE_WIN then
        if key == KEY_R then
            RestartGame()
        end
    end

    if key == KEY_ESCAPE then
        engine:Exit()
    end
end

function HandleKeyUp(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_LEFT or key == KEY_A then
        input_state.left = false
    end
    if key == KEY_RIGHT or key == KEY_D then
        input_state.right = false
    end
    if key == KEY_SPACE or key == KEY_W or key == KEY_UP then
        input_state.jump = false
        input_state.jumpPressed = false
    end
    if key == KEY_LSHIFT or key == KEY_RSHIFT then
        input_state.run = false
    end
end

function RestartGame()
    gameState = STATE_PLAYING
    score = 0
    coins = 0
    lives = 3
    time = 400
    timeCounter = 0

    mario.x = 100
    mario.y = (groundLevel - 1) * TILE_SIZE - mario.height
    mario.vx = 0
    mario.vy = 0
    mario.onGround = false
    mario.powerup = 0
    mario.invincible = 0
    mario.dead = false
    mario.animFrame = 0
    mario.animTime = 0
    mario.jumpsLeft = 2  -- Reset to 2 jumps

    cameraX = 0

    SpawnEnemies()

    coins_entities = {}
    powerups = {}
    particles = {}

    -- Reset question blocks
    for key, block in pairs(questionBlocks) do
        block.used = false
    end
end

-- ====================================================================
-- 主更新循环
-- ====================================================================

function HandleUpdate(eventType, eventData)
    -- ✅ 正确的 eventData 访问方式
    local timeStep = eventData["TimeStep"]:GetFloat()

    if gameState == STATE_PLAYING then
        UpdateGame(timeStep)
    elseif gameState == STATE_MENU then
        -- Touch/button support for starting game
        if vc_jumpBtn and vc_jumpBtn.isPressed and not vc_jumpWasPressed then
            gameState = STATE_PLAYING
        end
        vc_jumpWasPressed = vc_jumpBtn and vc_jumpBtn.isPressed or false
    elseif gameState == STATE_GAMEOVER or gameState == STATE_WIN then
        -- Touch/button support for restarting game
        if vc_jumpBtn and vc_jumpBtn.isPressed and not vc_jumpWasPressed then
            RestartGame()
        end
        vc_jumpWasPressed = vc_jumpBtn and vc_jumpBtn.isPressed or false
    end
end

function UpdateGame(dt)
    -- Update timer
    timeCounter = timeCounter + dt
    if timeCounter >= 1.0 then
        time = time - 1
        timeCounter = 0

        if time <= 0 then
            KillMario()
        end
    end

    if mario.dead then
        mario.vy = mario.vy + GRAVITY * dt
        mario.y = mario.y + mario.vy * dt

        if mario.y > 800 then
            lives = lives - 1
            if lives <= 0 then
                gameState = STATE_GAMEOVER
            else
                RestartGame()
            end
        end
        return
    end

    -- Read virtual controls input
    if vc_joystick then
        -- Joystick directly controls left/right state each frame
        input_state.left = vc_joystick.x < -0.3
        input_state.right = vc_joystick.x > 0.3
    end

    if vc_jumpBtn then
        -- Edge detection: trigger jump only on press, not hold
        local jumpPressed = vc_jumpBtn.isPressed
        if jumpPressed and not vc_jumpWasPressed then
            input_state.jumpPressed = true
        end
        vc_jumpWasPressed = jumpPressed
    end

    if vc_runBtn then
        -- Toggle mode: isToggled indicates run state
        input_state.run = vc_runBtn.isToggled
    end

    -- Mario input
    mario.vx = 0
    local speed = MARIO_SPEED
    if input_state.run then
        speed = MARIO_RUN_SPEED
    end

    if input_state.left then
        mario.vx = -speed
        mario.facing = -1
    end
    if input_state.right then
        mario.vx = speed
        mario.facing = 1
    end

    -- Reset jumps when landing (do this BEFORE jump check)
    if mario.onGround then
        if mario.jumpsLeft < 2 then
            mario.jumpsLeft = 2
            print("DEBUG: Landed, reset jumpsLeft to 2")
        end
    end

    -- Mario jump (2 total jumps before landing)
    if input_state.jumpPressed then
        if mario.jumpsLeft > 0 then
            -- Can jump
            print("DEBUG: Jump! jumpsLeft before=" .. mario.jumpsLeft .. " onGround=" .. tostring(mario.onGround))
            mario.vy = -MARIO_JUMP_SPEED
            mario.onGround = false
            mario.jumpsLeft = mario.jumpsLeft - 1
            input_state.jumpPressed = false

            -- Show blue particle for second jump only
            if mario.jumpsLeft == 0 then
                print("DEBUG: Second jump with particles!")
                CreateParticles(mario.x + mario.width/2, mario.y + mario.height, {100, 200, 255})
            end
        else
            input_state.jumpPressed = false
        end
    end

    -- Apply gravity
    if not mario.onGround then
        mario.vy = mario.vy + GRAVITY * dt
    end

    -- Limit fall speed
    if mario.vy > 600 then
        mario.vy = 600
    end

    -- Update mario position
    mario.x = mario.x + mario.vx * dt
    mario.y = mario.y + mario.vy * dt

    -- Update animation
    mario.animTime = mario.animTime + dt
    if math.abs(mario.vx) > 10 then
        -- Walking animation (3 frames)
        if mario.animTime > 0.12 then
            mario.animFrame = (mario.animFrame + 1) % 3
            mario.animTime = 0
        end
    else
        -- Idle
        mario.animFrame = 0
        mario.animTime = 0
    end

    -- Collision detection
    CheckMarioCollision()

    -- Check if mario fell off (use dynamic threshold based on level height)
    local deathY = (levelHeight + 5) * TILE_SIZE
    if mario.y > deathY then
        KillMario()
    end

    -- Update invincibility
    if mario.invincible > 0 then
        mario.invincible = mario.invincible - dt
    end

    -- Update camera
    local targetCameraX = mario.x - SCREEN_WIDTH / 2
    if targetCameraX < 0 then
        targetCameraX = 0
    end
    if targetCameraX > levelWidth * TILE_SIZE - SCREEN_WIDTH then
        targetCameraX = levelWidth * TILE_SIZE - SCREEN_WIDTH
    end
    cameraX = targetCameraX

    -- Update enemies
    for i = #entities, 1, -1 do
        local enemy = entities[i]

        if not enemy.stomped then
            enemy.x = enemy.x + enemy.vx * dt
            enemy.vy = enemy.vy + GRAVITY * dt
            enemy.y = enemy.y + enemy.vy * dt

            enemy.animTime = enemy.animTime + dt
            if enemy.animTime > 0.2 then
                enemy.animFrame = (enemy.animFrame + 1) % 2
                enemy.animTime = 0
            end

            CheckEnemyCollision(enemy)

            -- Enemy to enemy collision (prevent stacking)
            for j = 1, #entities do
                if i ~= j and not entities[j].stomped then
                    local other = entities[j]
                    if CheckCollision(enemy, other) then
                        -- Push enemies apart or reverse direction
                        if enemy.x < other.x then
                            enemy.vx = -math.abs(enemy.vx)
                            other.vx = math.abs(other.vx)
                        else
                            enemy.vx = math.abs(enemy.vx)
                            other.vx = -math.abs(other.vx)
                        end
                    end
                end
            end

            -- Enemy collision with mario
            if CheckCollision(mario, enemy) then
                -- More forgiving stomp detection: if mario is falling and roughly above enemy
                if mario.vy > 0 and mario.y + mario.height - 16 < enemy.y + enemy.height/2 then
                    -- Stomp enemy
                    enemy.stomped = true
                    enemy.stompTime = 0.5
                    mario.vy = -250
                    score = score + 100
                    CreateParticles(enemy.x + enemy.width/2, enemy.y, {255, 255, 0})
                else
                    -- Only take damage if not invincible
                    if mario.invincible <= 0 then
                        if mario.powerup > 0 then
                            mario.powerup = mario.powerup - 1
                            mario.invincible = 2.0
                        else
                            KillMario()
                        end
                    end
                end
            end
        else
            enemy.stompTime = enemy.stompTime - dt
            if enemy.stompTime <= 0 then
                table.remove(entities, i)
            end
        end
    end

    -- Update coins
    for i = #coins_entities, 1, -1 do
        local coin = coins_entities[i]
        coin.vy = coin.vy + GRAVITY * dt * 0.5
        coin.y = coin.y + coin.vy * dt
        coin.lifetime = coin.lifetime - dt

        if coin.lifetime <= 0 then
            table.remove(coins_entities, i)
        end
    end

    -- Update powerups
    for i = #powerups, 1, -1 do
        local powerup = powerups[i]
        powerup.x = powerup.x + powerup.vx * dt
        powerup.vy = powerup.vy + GRAVITY * dt
        powerup.y = powerup.y + powerup.vy * dt

        CheckPowerupCollision(powerup)

        if CheckCollision(mario, powerup) then
            if mario.powerup < 1 then
                mario.powerup = 1
            end
            score = score + 1000
            table.remove(powerups, i)
            CreateParticles(powerup.x + powerup.width/2, powerup.y, {255, 100, 100})
        end
    end

    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.lifetime = p.lifetime - dt
        p.alpha = p.lifetime / 1.0

        if p.lifetime <= 0 then
            table.remove(particles, i)
        end
    end

    -- Check flag pole
    local flagX = flagPole.x * TILE_SIZE
    if mario.x + mario.width > flagX and mario.x < flagX + TILE_SIZE then
        gameState = STATE_WIN
        score = score + 5000
    end
end

-- ====================================================================
-- 马里奥碰撞检测（手动瓦片碰撞）
-- ====================================================================
-- 
-- 为什么不用 Box2D？
-- - 超级马里奥的碰撞是基于网格的，瓦片地图更合适
-- - Box2D 对于大量静态瓦片不如直接查询高效
-- - 游戏需要精确的瓦片交互（顶砖块、踩管道等）
-- 
-- 碰撞检测步骤:
-- 1. 计算马里奥占据的瓦片范围
-- 2. 遍历这些瓦片，检查是否是固体
-- 3. 计算重叠量，找出最小重叠方向
-- 4. 沿最小重叠方向推出马里奥
-- 
function CheckMarioCollision()
    local wasOnGround = mario.onGround
    mario.onGround = false

    -- ⚠️ 像素坐标转瓦片坐标: floor(像素 / TILE_SIZE) + 1
    -- +1 是因为 Lua 数组索引从 1 开始
    local leftTile = math.floor(mario.x / TILE_SIZE) + 1
    local rightTile = math.floor((mario.x + mario.width) / TILE_SIZE) + 1
    local topTile = math.floor(mario.y / TILE_SIZE) + 1
    local bottomTile = math.floor((mario.y + mario.height) / TILE_SIZE) + 1

    for y = topTile, bottomTile do
        for x = leftTile, rightTile do
            if y >= 1 and y <= levelHeight and x >= 1 and x <= levelWidth then
                local tile = level[y][x]

                if tile == 1 or tile == 2 or tile == 3 or tile == 4 then
                    local tileX = (x - 1) * TILE_SIZE
                    local tileY = (y - 1) * TILE_SIZE

                    if mario.x < tileX + TILE_SIZE and
                       mario.x + mario.width > tileX and
                       mario.y < tileY + TILE_SIZE and
                       mario.y + mario.height > tileY then

                        local overlapLeft = mario.x + mario.width - tileX
                        local overlapRight = tileX + TILE_SIZE - mario.x
                        local overlapTop = mario.y + mario.height - tileY
                        local overlapBottom = tileY + TILE_SIZE - mario.y

                        local minOverlap = math.min(overlapLeft, overlapRight, overlapTop, overlapBottom)

                        if minOverlap == overlapTop and mario.vy >= 0 then
                            -- Landing on top of tile
                            mario.y = tileY - mario.height
                            mario.vy = 0
                            mario.onGround = true
                            mario.jumpsLeft = 1  -- Reset double jump when landing
                        elseif minOverlap == overlapBottom and mario.vy < 0 then
                            mario.y = tileY + TILE_SIZE
                            mario.vy = 0

                            if tile == 3 then
                                local key = x .. "_" .. y
                                if questionBlocks[key] and not questionBlocks[key].used then
                                    questionBlocks[key].used = true
                                    level[y][x] = 2

                                    if questionBlocks[key].type == "coin" then
                                        coins = coins + 1
                                        score = score + 200
                                        table.insert(coins_entities, {
                                            x = tileX,
                                            y = tileY - TILE_SIZE,
                                            vy = -200,
                                            lifetime = 0.5
                                        })
                                    elseif questionBlocks[key].type == "powerup" then
                                        table.insert(powerups, {
                                            x = tileX,
                                            y = tileY - TILE_SIZE,
                                            vx = 80,
                                            vy = -50,
                                            width = 28,
                                            height = 28,
                                            type = "mushroom"
                                        })
                                    end
                                end
                            elseif tile == 2 then
                                -- Any mario can break bricks (removed powerup requirement)
                                level[y][x] = 0
                                score = score + 50
                                CreateParticles(tileX + TILE_SIZE/2, tileY + TILE_SIZE/2, {200, 100, 50})
                            end
                        elseif minOverlap == overlapLeft and mario.vx > 0 then
                            mario.x = tileX - mario.width
                        elseif minOverlap == overlapRight and mario.vx < 0 then
                            mario.x = tileX + TILE_SIZE
                        end
                    end
                end
            end
        end
    end
end

function CheckEnemyCollision(enemy)
    local leftTile = math.floor(enemy.x / TILE_SIZE) + 1
    local rightTile = math.floor((enemy.x + enemy.width) / TILE_SIZE) + 1
    local topTile = math.floor(enemy.y / TILE_SIZE) + 1
    local bottomTile = math.floor((enemy.y + enemy.height) / TILE_SIZE) + 1

    local onGround = false

    for y = topTile, bottomTile do
        for x = leftTile, rightTile do
            if y >= 1 and y <= levelHeight and x >= 1 and x <= levelWidth then
                local tile = level[y][x]

                if tile == 1 or tile == 2 or tile == 3 or tile == 4 then
                    local tileX = (x - 1) * TILE_SIZE
                    local tileY = (y - 1) * TILE_SIZE

                    if enemy.x < tileX + TILE_SIZE and
                       enemy.x + enemy.width > tileX and
                       enemy.y < tileY + TILE_SIZE and
                       enemy.y + enemy.height > tileY then

                        local overlapLeft = enemy.x + enemy.width - tileX
                        local overlapRight = tileX + TILE_SIZE - enemy.x
                        local overlapTop = enemy.y + enemy.height - tileY

                        local minOverlap = math.min(overlapLeft, overlapRight, overlapTop)

                        if minOverlap == overlapTop and enemy.vy > 0 then
                            enemy.y = tileY - enemy.height
                            enemy.vy = 0
                            onGround = true
                        elseif minOverlap == overlapLeft and enemy.vx > 0 then
                            enemy.x = tileX - enemy.width
                            enemy.vx = -enemy.vx
                        elseif minOverlap == overlapRight and enemy.vx < 0 then
                            enemy.x = tileX + TILE_SIZE
                            enemy.vx = -enemy.vx
                        end
                    end
                end
            end
        end
    end

    -- Check for edge detection (prevent falling into pits)
    if onGround then
        local checkX = enemy.vx > 0 and (enemy.x + enemy.width + 2) or (enemy.x - 2)
        local checkTileX = math.floor(checkX / TILE_SIZE) + 1
        local checkTileY = math.floor((enemy.y + enemy.height + TILE_SIZE) / TILE_SIZE) + 1

        if checkTileX >= 1 and checkTileX <= levelWidth and checkTileY >= 1 and checkTileY <= levelHeight then
            local tileBelow = level[checkTileY][checkTileX]
            -- If no ground ahead, turn around
            if tileBelow == 0 then
                enemy.vx = -enemy.vx
            end
        end
    end
end

function CheckPowerupCollision(powerup)
    local leftTile = math.floor(powerup.x / TILE_SIZE) + 1
    local rightTile = math.floor((powerup.x + powerup.width) / TILE_SIZE) + 1
    local topTile = math.floor(powerup.y / TILE_SIZE) + 1
    local bottomTile = math.floor((powerup.y + powerup.height) / TILE_SIZE) + 1

    for y = topTile, bottomTile do
        for x = leftTile, rightTile do
            if y >= 1 and y <= levelHeight and x >= 1 and x <= levelWidth then
                local tile = level[y][x]

                if tile == 1 or tile == 2 or tile == 3 or tile == 4 then
                    local tileX = (x - 1) * TILE_SIZE
                    local tileY = (y - 1) * TILE_SIZE

                    if powerup.x < tileX + TILE_SIZE and
                       powerup.x + powerup.width > tileX and
                       powerup.y < tileY + TILE_SIZE and
                       powerup.y + powerup.height > tileY then

                        local overlapLeft = powerup.x + powerup.width - tileX
                        local overlapRight = tileX + TILE_SIZE - powerup.x
                        local overlapTop = powerup.y + powerup.height - tileY

                        local minOverlap = math.min(overlapLeft, overlapRight, overlapTop)

                        if minOverlap == overlapTop and powerup.vy > 0 then
                            powerup.y = tileY - powerup.height
                            powerup.vy = 0
                        elseif minOverlap == overlapLeft and powerup.vx > 0 then
                            powerup.x = tileX - powerup.width
                            powerup.vx = -powerup.vx
                        elseif minOverlap == overlapRight and powerup.vx < 0 then
                            powerup.x = tileX + TILE_SIZE
                            powerup.vx = -powerup.vx
                        end
                    end
                end
            end
        end
    end
end

function CheckCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function KillMario()
    if not mario.dead then
        mario.dead = true
        mario.vy = -400
        CreateParticles(mario.x + mario.width/2, mario.y + mario.height/2, {255, 0, 0})
    end
end

function CreateParticles(x, y, color)
    for i = 1, 15 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(50, 150)
        table.insert(particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 100,
            lifetime = 1.0,
            alpha = 1.0,
            color = color,
            size = math.random(3, 6)
        })
    end
end

-- ====================================================================
-- NanoVG 渲染
-- ====================================================================
-- 
-- ⚠️ 重要: NanoVG 渲染通过 NanoVGRender 事件
-- 这样可以让 NanoVGAdapter 管理多个 NanoVG 上下文的渲染顺序
--
function HandleNanoVGRender(eventType, eventData)
    if nvgContext == nil then
        return
    end

    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()

    -- 动态更新屏幕尺寸
    SCREEN_WIDTH = width
    SCREEN_HEIGHT = height

    -- ✅ NanoVG 绘制流程: BeginFrame -> 绘制操作 -> EndFrame
    nvgBeginFrame(nvgContext, width, height, 1.0)

    if gameState == STATE_MENU then
        DrawMenu(nvgContext)
    elseif gameState == STATE_PLAYING then
        DrawGame(nvgContext)
    elseif gameState == STATE_GAMEOVER then
        DrawGameOver(nvgContext)
    elseif gameState == STATE_WIN then
        DrawWin(nvgContext)
    end

    nvgEndFrame(nvgContext)
end

function DrawMenu(vg)
    -- Background gradient (sky to lighter blue)
    local gradient = nvgLinearGradient(vg, 0, 0, 0, SCREEN_HEIGHT,
                                       nvgRGBA(100, 180, 255, 255),
                                       nvgRGBA(150, 220, 255, 255))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    nvgFillPaint(vg, gradient)
    nvgFill(vg)

    -- Animated clouds in background
    local time = os.clock()
    for i = 1, 5 do
        local cloudX = (SCREEN_WIDTH * 0.2 * i + time * 20 * i) % (SCREEN_WIDTH + 100) - 50
        local cloudY = 100 + i * 60
        DrawCloud(vg, cloudX, cloudY)
    end

    -- Title with multiple shadows for depth
    nvgFontSize(vg, 100)
    nvgFontFace(vg, "sans-bold")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- Shadow layers
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 100))
    nvgText(vg, SCREEN_WIDTH/2 + 6, SCREEN_HEIGHT/2 - 150 + 6, "SUPER MARIO", nil)

    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    nvgText(vg, SCREEN_WIDTH/2 + 3, SCREEN_HEIGHT/2 - 150 + 3, "SUPER MARIO", nil)

    -- Main title with outline effect
    nvgFillColor(vg, nvgRGBA(255, 50, 50, 255))
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 150, "SUPER MARIO", nil)

    -- Subtitle with glow
    nvgFontSize(vg, 36)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 80, "URHO3D EDITION", nil)

    -- Pulsing "Press SPACE" text
    local pulse = math.sin(time * 3) * 0.3 + 0.7
    nvgFontSize(vg, 32)
    nvgFillColor(vg, nvgRGBA(255, 255, 100 * pulse, 255 * pulse))
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 50, "Press SPACE or Tap Jump to Start", nil)

    -- Controls section with background box
    local controlsY = SCREEN_HEIGHT/2 + 140
    nvgBeginPath(vg)
    nvgRoundedRect(vg, SCREEN_WIDTH/2 - 180, controlsY - 30, 360, 130, 10)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 100))
    nvgFill(vg)

    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(255, 255, 200, 255))
    nvgText(vg, SCREEN_WIDTH/2, controlsY, "Controls:", nil)

    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(220, 220, 220, 255))
    nvgText(vg, SCREEN_WIDTH/2, controlsY + 30, "Arrow Keys / WASD - Move", nil)
    nvgText(vg, SCREEN_WIDTH/2, controlsY + 55, "Space - Jump", nil)
    nvgText(vg, SCREEN_WIDTH/2, controlsY + 80, "Shift - Run Faster", nil)

    -- Animated mario (bouncing)
    local marioX = SCREEN_WIDTH/2 - 100
    local marioY = SCREEN_HEIGHT/2 - 20 + math.sin(time * 2) * 15
    DrawMarioSprite(vg, marioX, marioY, 1, math.floor(time * 5) % 4, false, false)

    -- Decorative ground strip at bottom
    nvgBeginPath(vg)
    nvgRect(vg, 0, SCREEN_HEIGHT - 60, SCREEN_WIDTH, 60)
    nvgFillColor(vg, nvgRGBA(139, 90, 43, 255))
    nvgFill(vg)

    -- Ground pattern
    for i = 0, math.floor(SCREEN_WIDTH / TILE_SIZE) do
        nvgBeginPath(vg)
        nvgRect(vg, i * TILE_SIZE, SCREEN_HEIGHT - 60, TILE_SIZE, TILE_SIZE)
        nvgStrokeColor(vg, nvgRGBA(100, 60, 30, 255))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
    end

    -- Floating coins animation
    for i = 1, 3 do
        local coinX = SCREEN_WIDTH/2 + 150 + i * 40
        local coinY = SCREEN_HEIGHT/2 - 50 + math.sin(time * 3 + i) * 20
        nvgBeginPath(vg)
        nvgCircle(vg, coinX, coinY, 12)
        nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
        nvgFill(vg)

        nvgBeginPath(vg)
        nvgCircle(vg, coinX, coinY, 8)
        nvgStrokeColor(vg, nvgRGBA(180, 140, 0, 255))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
    end
end

function DrawGame(vg)
    -- Sky gradient
    local gradient = nvgLinearGradient(vg, 0, 0, 0, SCREEN_HEIGHT, nvgRGBA(100, 180, 255, 255), nvgRGBA(150, 220, 255, 255))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    nvgFillPaint(vg, gradient)
    nvgFill(vg)

    -- Draw clouds (parallax)
    local cloudOffset = cameraX * 0.3
    for y = 1, levelHeight do
        for x = 1, levelWidth do
            if level[y][x] == 5 then
                local screenX = (x - 1) * TILE_SIZE - cloudOffset
                local screenY = (y - 1) * TILE_SIZE

                if screenX > -TILE_SIZE and screenX < SCREEN_WIDTH + TILE_SIZE then
                    DrawCloud(vg, screenX, screenY)
                end
            end
        end
    end

    -- Draw level
    for y = 1, levelHeight do
        for x = 1, levelWidth do
            local tile = level[y][x]
            local screenX = (x - 1) * TILE_SIZE - cameraX
            local screenY = (y - 1) * TILE_SIZE

            if screenX > -TILE_SIZE and screenX < SCREEN_WIDTH + TILE_SIZE then
                if tile == 1 then
                    DrawGround(vg, screenX, screenY)
                elseif tile == 2 then
                    DrawBrick(vg, screenX, screenY)
                elseif tile == 3 then
                    local key = x .. "_" .. y
                    local used = questionBlocks[key] and questionBlocks[key].used
                    DrawQuestionBlock(vg, screenX, screenY, used)
                elseif tile == 4 then
                    DrawPipe(vg, screenX, screenY)
                end
            end
        end
    end

    -- Draw flag pole
    local flagScreenX = flagPole.x * TILE_SIZE - cameraX
    if flagScreenX > -TILE_SIZE and flagScreenX < SCREEN_WIDTH + TILE_SIZE then
        DrawFlagPole(vg, flagScreenX, flagPole.y * TILE_SIZE)
    end

    -- Draw powerups
    for _, powerup in ipairs(powerups) do
        local screenX = powerup.x - cameraX
        if screenX > -50 and screenX < SCREEN_WIDTH + 50 then
            DrawMushroom(vg, screenX, powerup.y)
        end
    end

    -- Draw coins
    for _, coin in ipairs(coins_entities) do
        local screenX = coin.x - cameraX
        if screenX > -50 and screenX < SCREEN_WIDTH + 50 then
            DrawCoin(vg, screenX, coin.y, coin.lifetime)
        end
    end

    -- Draw enemies (offset to center sprite over smaller hitbox)
    for _, enemy in ipairs(entities) do
        local screenX = enemy.x - cameraX - 4  -- Center the sprite
        local screenY = enemy.y - 2
        if screenX > -50 and screenX < SCREEN_WIDTH + 50 then
            if enemy.stomped then
                DrawStompedEnemy(vg, screenX, screenY, enemy.type)
            else
                if enemy.type == "goomba" then
                    DrawGoomba(vg, screenX, screenY, enemy.animFrame)
                else
                    DrawKoopa(vg, screenX, screenY, enemy.animFrame)
                end
            end
        end
    end

    -- Draw mario (offset to center the sprite over the hitbox)
    if not mario.dead then
        local screenX = mario.x - cameraX - 6  -- Center the 48px sprite over 36px hitbox
        local screenY = mario.y - 3  -- Center vertically (48-42)/2
        local blinking = mario.invincible > 0 and (math.floor(mario.invincible * 10) % 2 == 0)
        DrawMarioSprite(vg, screenX, screenY, mario.facing, mario.animFrame, mario.powerup > 0, blinking)
    else
        local screenX = mario.x - cameraX - 6
        local screenY = mario.y - 3
        DrawDeadMario(vg, screenX, screenY)
    end

    -- Draw particles
    for _, p in ipairs(particles) do
        local screenX = p.x - cameraX
        nvgBeginPath(vg)
        nvgCircle(vg, screenX, p.y, p.size)
        nvgFillColor(vg, nvgRGBA(p.color[1], p.color[2], p.color[3], p.alpha * 255))
        nvgFill(vg)
    end

    -- Draw UI
    DrawUI(vg)
end

function DrawGround(vg, x, y)
    nvgBeginPath(vg)
    nvgRect(vg, x, y, TILE_SIZE, TILE_SIZE)
    nvgFillColor(vg, nvgRGBA(139, 90, 43, 255))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRect(vg, x, y, TILE_SIZE, 4)
    nvgFillColor(vg, nvgRGBA(180, 120, 60, 255))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRect(vg, x, y, TILE_SIZE, TILE_SIZE)
    nvgStrokeColor(vg, nvgRGBA(100, 60, 30, 255))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
end

function DrawBrick(vg, x, y)
    nvgBeginPath(vg)
    nvgRect(vg, x, y, TILE_SIZE, TILE_SIZE)
    nvgFillColor(vg, nvgRGBA(200, 100, 50, 255))
    nvgFill(vg)

    nvgStrokeColor(vg, nvgRGBA(150, 75, 35, 255))
    nvgStrokeWidth(vg, 2)

    nvgBeginPath(vg)
    nvgMoveTo(vg, x, y + TILE_SIZE/2)
    nvgLineTo(vg, x + TILE_SIZE, y + TILE_SIZE/2)
    nvgStroke(vg)

    nvgBeginPath(vg)
    nvgMoveTo(vg, x + TILE_SIZE/2, y)
    nvgLineTo(vg, x + TILE_SIZE/2, y + TILE_SIZE/2)
    nvgStroke(vg)

    nvgBeginPath(vg)
    nvgMoveTo(vg, x + TILE_SIZE/4, y + TILE_SIZE/2)
    nvgLineTo(vg, x + TILE_SIZE/4, y + TILE_SIZE)
    nvgStroke(vg)

    nvgBeginPath(vg)
    nvgMoveTo(vg, x + TILE_SIZE*3/4, y + TILE_SIZE/2)
    nvgLineTo(vg, x + TILE_SIZE*3/4, y + TILE_SIZE)
    nvgStroke(vg)
end

function DrawQuestionBlock(vg, x, y, used)
    if used then
        nvgBeginPath(vg)
        nvgRect(vg, x, y, TILE_SIZE, TILE_SIZE)
        nvgFillColor(vg, nvgRGBA(150, 130, 100, 255))
        nvgFill(vg)
    else
        local pulse = math.sin(os.clock() * 4) * 0.1 + 0.9
        nvgBeginPath(vg)
        nvgRect(vg, x, y, TILE_SIZE, TILE_SIZE)
        nvgFillColor(vg, nvgRGBA(255 * pulse, 200 * pulse, 0, 255))
        nvgFill(vg)

        nvgFontSize(vg, 24)
        nvgFontFace(vg, "sans-bold")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, x + TILE_SIZE/2, y + TILE_SIZE/2, "?", nil)
    end

    nvgBeginPath(vg)
    nvgRect(vg, x, y, TILE_SIZE, TILE_SIZE)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 0, 255))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)
end

function DrawPipe(vg, x, y)
    -- Check if this is the left or right part of a pipe, and if it's the top
    local screenX = x + cameraX
    local tileX = math.floor(screenX / TILE_SIZE) + 1
    local tileY = math.floor(y / TILE_SIZE) + 1

    -- Determine pipe position
    local isPipeLeft = false
    local isPipeRight = false
    local isPipeTop = false

    for _, pipe in ipairs(pipes) do
        if tileX == pipe.x and tileY >= pipe.y and tileY < pipe.y + pipe.height then
            isPipeLeft = true
            if tileY == pipe.y then
                isPipeTop = true
            end
        elseif tileX == pipe.x + 1 and tileY >= pipe.y and tileY < pipe.y + pipe.height then
            isPipeRight = true
            if tileY == pipe.y then
                isPipeTop = true
            end
        end
    end

    local pipeWidth = TILE_SIZE * 2  -- Pipe is 2 tiles wide
    local pipeBaseX = isPipeLeft and x or (x - TILE_SIZE)  -- Start of the 2-tile pipe

    if isPipeLeft or isPipeRight then
        if isPipeTop then
            -- Draw pipe top "hat" (突出的帽子)
            nvgBeginPath(vg)
            nvgRect(vg, pipeBaseX - 4, y - 2, pipeWidth + 8, 12)
            nvgFillColor(vg, nvgRGBA(88, 216, 84, 255))
            nvgFill(vg)

            -- Top hat border
            nvgBeginPath(vg)
            nvgRect(vg, pipeBaseX - 4, y - 2, pipeWidth + 8, 12)
            nvgStrokeColor(vg, nvgRGBA(0, 0, 0, 255))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)

            -- Inner shadow of pipe opening (深绿色洞口)
            nvgBeginPath(vg)
            nvgRect(vg, pipeBaseX + 4, y + 10, pipeWidth - 8, 12)
            nvgFillColor(vg, nvgRGBA(30, 100, 30, 255))
            nvgFill(vg)
        end

        -- Pipe body (main green)
        nvgBeginPath(vg)
        nvgRect(vg, x, isPipeTop and (y + 10) or y, TILE_SIZE, isPipeTop and (TILE_SIZE - 10) or TILE_SIZE)
        nvgFillColor(vg, nvgRGBA(56, 168, 56, 255))
        nvgFill(vg)

        if isPipeLeft then
            -- Left side highlight
            nvgBeginPath(vg)
            nvgRect(vg, x + 8, isPipeTop and (y + 10) or y, 12, isPipeTop and (TILE_SIZE - 10) or TILE_SIZE)
            nvgFillColor(vg, nvgRGBA(88, 216, 84, 255))
            nvgFill(vg)

            -- Left border
            nvgBeginPath(vg)
            nvgMoveTo(vg, pipeBaseX, isPipeTop and (y + 10) or y)
            nvgLineTo(vg, pipeBaseX, y + TILE_SIZE)
            nvgStrokeColor(vg, nvgRGBA(0, 0, 0, 255))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        else
            -- Right side shadow
            nvgBeginPath(vg)
            nvgRect(vg, x + TILE_SIZE - 20, isPipeTop and (y + 10) or y, 12, isPipeTop and (TILE_SIZE - 10) or TILE_SIZE)
            nvgFillColor(vg, nvgRGBA(40, 140, 40, 255))
            nvgFill(vg)

            -- Right border
            nvgBeginPath(vg)
            nvgMoveTo(vg, x + TILE_SIZE, isPipeTop and (y + 10) or y)
            nvgLineTo(vg, x + TILE_SIZE, y + TILE_SIZE)
            nvgStrokeColor(vg, nvgRGBA(0, 0, 0, 255))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        end
    end
end

function DrawCloud(vg, x, y)
    nvgBeginPath(vg)
    nvgCircle(vg, x + 10, y + 10, 8)
    nvgCircle(vg, x + 20, y + 8, 10)
    nvgCircle(vg, x + 32, y + 10, 8)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)
end

-- Mario animation frames
function DrawMarioSprite(vg, x, y, facing, animFrame, isBig, blinking)
    if blinking then
        return
    end

    local pixelSize = 3  -- Each pixel is 3x3 screen pixels (50% larger)

    nvgSave(vg)

    -- Determine which frame to draw based on state
    -- Use velocity to determine if jumping (more stable than onGround)
    local isJumping = mario.vy < -50 or mario.vy > 50  -- Significant vertical movement
    local isWalking = math.abs(mario.vx) > 10

    if isJumping then
        DrawMarioJump(vg, x, y, facing, pixelSize)
    elseif isWalking then
        DrawMarioWalk(vg, x, y, facing, animFrame, pixelSize)
    else
        DrawMarioIdle(vg, x, y, facing, pixelSize)
    end

    nvgRestore(vg)
end

-- Helper function to draw a pixel
local function drawPixel(vg, px, py, r, g, b, pixelSize)
    nvgBeginPath(vg)
    nvgRect(vg, px * pixelSize, py * pixelSize, pixelSize, pixelSize)
    nvgFillColor(vg, nvgRGBA(r, g, b, 255))
    nvgFill(vg)
end

-- Colors
local RED = {169, 59, 59}
local SKIN = {226, 168, 105}
local BROWN = {139, 90, 43}
local BLUE = {0, 100, 200}

-- Frame 0: Idle/Standing (original working version)
function DrawMarioIdle(vg, x, y, facing, pixelSize)
    local w = 16 * pixelSize
    local h = 16 * pixelSize

    nvgTranslate(vg, x + w/2, y + h/2)
    if facing < 0 then nvgScale(vg, -1, 1) end
    nvgTranslate(vg, -w/2, -h/2)

    -- Row 0: Hat
    drawPixel(vg, 5, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 0, RED[1], RED[2], RED[3], pixelSize)

    -- Row 1: Hat
    drawPixel(vg, 4, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 1, RED[1], RED[2], RED[3], pixelSize)

    -- Row 2: Hair and face
    drawPixel(vg, 4, 2, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 2, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 10, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 3: Hair and face
    drawPixel(vg, 3, 3, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 5, 3, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 9, 3, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 12, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 4: Face details
    drawPixel(vg, 3, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 4, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 5, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 4, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 4, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 11, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 5: Face
    drawPixel(vg, 4, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 5, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 9, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 10, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 6: Mustache
    drawPixel(vg, 4, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 7, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 8, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 7: Shirt
    drawPixel(vg, 5, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 7, RED[1], RED[2], RED[3], pixelSize)

    -- Row 8: Arms and body
    drawPixel(vg, 3, 8, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 9, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 8, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 9: Body
    drawPixel(vg, 2, 9, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 3, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 4, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 13, 9, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 10: Body
    drawPixel(vg, 2, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 3, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 4, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 13, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 11: Body and overalls
    drawPixel(vg, 2, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 3, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 4, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 13, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 12: Legs
    drawPixel(vg, 3, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 12, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 12, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 12, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 12, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 12, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 12, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 12, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 13: Legs
    drawPixel(vg, 3, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 11, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 12, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 14: Shoes
    drawPixel(vg, 2, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 3, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 11, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 12, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 13, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 15: Shoes
    drawPixel(vg, 2, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 3, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 11, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 12, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 13, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
end

-- Walking animation frames (based on idle, only legs move)
function DrawMarioWalk(vg, x, y, facing, frame, pixelSize)
    local w = 16 * pixelSize
    local h = 16 * pixelSize

    nvgTranslate(vg, x + w/2, y + h/2)
    if facing < 0 then nvgScale(vg, -1, 1) end
    nvgTranslate(vg, -w/2, -h/2)

    local walkFrame = frame % 3  -- 3 walking frames

    -- Row 0: Hat
    drawPixel(vg, 5, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 0, RED[1], RED[2], RED[3], pixelSize)

    -- Row 1: Hat
    drawPixel(vg, 4, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 1, RED[1], RED[2], RED[3], pixelSize)

    -- Row 2-11: Same as idle (upper body)
    drawPixel(vg, 4, 2, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 2, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 10, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    drawPixel(vg, 3, 3, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 5, 3, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 9, 3, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 12, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    drawPixel(vg, 3, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 4, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 5, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 4, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 4, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 11, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    drawPixel(vg, 4, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 5, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 9, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 10, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    drawPixel(vg, 4, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 7, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 8, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    drawPixel(vg, 5, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 7, RED[1], RED[2], RED[3], pixelSize)

    drawPixel(vg, 3, 8, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 9, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 8, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    drawPixel(vg, 2, 9, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 3, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 4, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 13, 9, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    drawPixel(vg, 2, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 3, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 4, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 13, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    drawPixel(vg, 2, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 3, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 4, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 13, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 12-15: Animated legs (different for each frame)
    if walkFrame == 0 then
        -- Frame 0: Left leg forward
        drawPixel(vg, 3, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 4, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 5, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 6, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 7, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 9, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 10, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 11, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 12, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)

        drawPixel(vg, 2, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 3, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 4, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 5, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 10, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 11, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)

        drawPixel(vg, 2, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 3, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 4, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 5, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 10, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 11, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)

        drawPixel(vg, 2, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 3, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 4, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 5, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 10, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 11, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    elseif walkFrame == 1 then
        -- Frame 1: Idle pose (legs together)
        drawPixel(vg, 3, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 4, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 5, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 6, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 7, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 8, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 9, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 10, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 11, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 12, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)

        drawPixel(vg, 3, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 4, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 5, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 6, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 9, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 10, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 11, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 12, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)

        drawPixel(vg, 2, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 3, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 4, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 5, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 10, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 11, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 12, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 13, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)

        drawPixel(vg, 2, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 3, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 4, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 5, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 10, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 11, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 12, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 13, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    else
        -- Frame 2: Right leg forward
        drawPixel(vg, 3, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 4, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 6, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 7, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 8, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 9, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 10, 12, RED[1], RED[2], RED[3], pixelSize)
        drawPixel(vg, 11, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 12, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)

        drawPixel(vg, 4, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 5, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 9, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 10, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 11, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 12, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)

        drawPixel(vg, 10, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 11, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 12, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 13, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)

        drawPixel(vg, 10, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 11, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 12, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
        drawPixel(vg, 13, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    end
end

-- Jumping pose (complete pixel art)
function DrawMarioJump(vg, x, y, facing, pixelSize)
    local w = 16 * pixelSize
    local h = 16 * pixelSize

    nvgTranslate(vg, x + w/2, y + h/2)
    if facing < 0 then nvgScale(vg, -1, 1) end
    nvgTranslate(vg, -w/2, -h/2)

    -- Row 0: Hat
    drawPixel(vg, 5, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 0, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 0, RED[1], RED[2], RED[3], pixelSize)

    -- Row 1: Hat
    drawPixel(vg, 4, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 1, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 1, RED[1], RED[2], RED[3], pixelSize)

    -- Row 2: Hair and face
    drawPixel(vg, 4, 2, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 2, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 10, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 2, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 3: Hair and face
    drawPixel(vg, 3, 3, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 5, 3, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 9, 3, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 11, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 12, 3, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 4: Face details
    drawPixel(vg, 3, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 4, 4, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 5, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 4, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 4, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 11, 4, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 5: Face
    drawPixel(vg, 4, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 5, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 6, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 7, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 8, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 9, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 10, 5, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 6: Mustache
    drawPixel(vg, 4, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 7, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 8, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 6, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 7: Shirt
    drawPixel(vg, 5, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 7, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 7, RED[1], RED[2], RED[3], pixelSize)

    -- Row 8: Arms extended and body
    drawPixel(vg, 1, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 2, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 3, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 4, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 8, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 13, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 14, 8, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 9: Arms and body
    drawPixel(vg, 1, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 2, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 3, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 4, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 9, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 13, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 14, 9, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 10: Body
    drawPixel(vg, 2, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 3, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 4, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 10, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 13, 10, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 11: Body
    drawPixel(vg, 2, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 3, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 4, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 5, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 6, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 10, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 11, 11, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 12, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)
    drawPixel(vg, 13, 11, SKIN[1], SKIN[2], SKIN[3], pixelSize)

    -- Row 12: Legs bent together (jumping pose)
    drawPixel(vg, 4, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 12, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 7, 12, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 8, 12, RED[1], RED[2], RED[3], pixelSize)
    drawPixel(vg, 9, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 12, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 13: Legs
    drawPixel(vg, 4, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 8, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 13, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 14: Shoes
    drawPixel(vg, 4, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 8, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 14, BROWN[1], BROWN[2], BROWN[3], pixelSize)

    -- Row 15: Shoes
    drawPixel(vg, 4, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 5, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 6, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 8, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 9, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
    drawPixel(vg, 10, 15, BROWN[1], BROWN[2], BROWN[3], pixelSize)
end

function DrawDeadMario(vg, x, y)
    nvgSave(vg)
    nvgTranslate(vg, x + 14, y + 16)
    nvgRotate(vg, math.pi)
    nvgTranslate(vg, -14, -16)

    DrawMarioSprite(vg, 0, 0, 1, 0, false, false)

    nvgRestore(vg)
end

function DrawGoomba(vg, x, y, animFrame)
    local scale = 1.15  -- Scale up the goomba

    -- Body
    nvgBeginPath(vg)
    nvgRect(vg, x + 2*scale, y + 10*scale, 24*scale, 18*scale)
    nvgFillColor(vg, nvgRGBA(139, 90, 43, 255))
    nvgFill(vg)

    -- Head
    nvgBeginPath(vg)
    nvgCircle(vg, x + 14*scale, y + 8*scale, 12*scale)
    nvgFillColor(vg, nvgRGBA(160, 100, 50, 255))
    nvgFill(vg)

    -- Eyes
    nvgBeginPath(vg)
    nvgCircle(vg, x + 9*scale, y + 8*scale, 4*scale)
    nvgCircle(vg, x + 19*scale, y + 8*scale, 4*scale)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)

    local pupilOffset = animFrame == 0 and 0 or 1
    nvgBeginPath(vg)
    nvgCircle(vg, x + (9 + pupilOffset)*scale, y + 8*scale, 2*scale)
    nvgCircle(vg, x + (19 + pupilOffset)*scale, y + 8*scale, 2*scale)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
    nvgFill(vg)

    -- Eyebrows
    nvgStrokeColor(vg, nvgRGBA(80, 50, 20, 255))
    nvgStrokeWidth(vg, 2*scale)
    nvgBeginPath(vg)
    nvgMoveTo(vg, x + 6*scale, y + 4*scale)
    nvgLineTo(vg, x + 12*scale, y + 6*scale)
    nvgStroke(vg)

    nvgBeginPath(vg)
    nvgMoveTo(vg, x + 22*scale, y + 4*scale)
    nvgLineTo(vg, x + 16*scale, y + 6*scale)
    nvgStroke(vg)

    -- Feet
    local footOffset = animFrame == 0 and 0 or 2
    nvgBeginPath(vg)
    nvgCircle(vg, x + (6 - footOffset)*scale, y + 26*scale, 4*scale)
    nvgCircle(vg, x + (22 + footOffset)*scale, y + 26*scale, 4*scale)
    nvgFillColor(vg, nvgRGBA(120, 80, 40, 255))
    nvgFill(vg)
end

function DrawKoopa(vg, x, y, animFrame)
    local scale = 1.15  -- Scale up the koopa

    -- Shell
    nvgBeginPath(vg)
    nvgCircle(vg, x + 14*scale, y + 18*scale, 14*scale)
    nvgFillColor(vg, nvgRGBA(0, 200, 0, 255))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, x + 14*scale, y + 18*scale, 10*scale)
    nvgFillColor(vg, nvgRGBA(255, 255, 0, 255))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, x + 14*scale, y + 18*scale, 6*scale)
    nvgFillColor(vg, nvgRGBA(0, 200, 0, 255))
    nvgFill(vg)

    -- Head
    nvgBeginPath(vg)
    nvgCircle(vg, x + 14*scale, y + 6*scale, 8*scale)
    nvgFillColor(vg, nvgRGBA(255, 255, 100, 255))
    nvgFill(vg)

    -- Eyes
    nvgBeginPath(vg)
    nvgCircle(vg, x + 11*scale, y + 6*scale, 2*scale)
    nvgCircle(vg, x + 17*scale, y + 6*scale, 2*scale)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
    nvgFill(vg)

    -- Feet
    local footOffset = animFrame == 0 and 0 or 2
    nvgBeginPath(vg)
    nvgCircle(vg, x + (5 - footOffset)*scale, y + 26*scale, 3*scale)
    nvgCircle(vg, x + (23 + footOffset)*scale, y + 26*scale, 3*scale)
    nvgFillColor(vg, nvgRGBA(200, 180, 0, 255))
    nvgFill(vg)
end

function DrawStompedEnemy(vg, x, y, enemyType)
    nvgBeginPath(vg)
    nvgRect(vg, x + 2, y + 22, 24, 6)
    nvgFillColor(vg, nvgRGBA(100, 60, 30, 255))
    nvgFill(vg)
end

function DrawCoin(vg, x, y, lifetime)
    local alpha = lifetime * 2
    if alpha > 1 then alpha = 1 end

    nvgBeginPath(vg)
    nvgCircle(vg, x + TILE_SIZE/2, y + TILE_SIZE/2, 8)
    nvgFillColor(vg, nvgRGBA(255, 215, 0, alpha * 255))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, x + TILE_SIZE/2, y + TILE_SIZE/2, 5)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 0, alpha * 255))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)
end

function DrawMushroom(vg, x, y)
    -- Cap
    nvgBeginPath(vg)
    nvgCircle(vg, x + 14, y + 8, 12)
    nvgFillColor(vg, nvgRGBA(255, 0, 0, 255))
    nvgFill(vg)

    -- Spots
    nvgBeginPath(vg)
    nvgCircle(vg, x + 10, y + 6, 3)
    nvgCircle(vg, x + 18, y + 6, 3)
    nvgCircle(vg, x + 14, y + 10, 2)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)

    -- Stem
    nvgBeginPath(vg)
    nvgRect(vg, x + 10, y + 14, 8, 12)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)

    -- Eyes
    nvgBeginPath(vg)
    nvgCircle(vg, x + 10, y + 18, 2)
    nvgCircle(vg, x + 18, y + 18, 2)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
    nvgFill(vg)
end

function DrawFlagPole(vg, x, y)
    -- Pole
    nvgBeginPath(vg)
    nvgRect(vg, x + TILE_SIZE/2 - 2, y, 4, flagPole.height * TILE_SIZE)
    nvgFillColor(vg, nvgRGBA(100, 100, 100, 255))
    nvgFill(vg)

    -- Flag
    nvgBeginPath(vg)
    nvgRect(vg, x + TILE_SIZE/2 + 2, flagY * TILE_SIZE, 20, 16)
    nvgFillColor(vg, nvgRGBA(0, 200, 0, 255))
    nvgFill(vg)

    -- Top ornament
    nvgBeginPath(vg)
    nvgCircle(vg, x + TILE_SIZE/2, y - 4, 6)
    nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
    nvgFill(vg)
end

function DrawUI(vg)
    -- Top bar
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, SCREEN_WIDTH, 50)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    nvgFill(vg)

    nvgFontSize(vg, 20)
    nvgFontFace(vg, "sans-bold")
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, 20, 25, "SCORE", nil)
    nvgText(vg, 120, 25, string.format("%07d", score), nil)

    nvgText(vg, 280, 25, "COINS", nil)
    nvgText(vg, 360, 25, string.format("%02d", coins), nil)

    nvgText(vg, 480, 25, "LIVES", nil)
    nvgText(vg, 560, 25, string.format("%d", lives), nil)

    nvgText(vg, 680, 25, "TIME", nil)
    nvgText(vg, 760, 25, string.format("%03d", time), nil)

    if mario.powerup == 1 then
        nvgText(vg, 900, 25, "BIG", nil)
    elseif mario.powerup == 2 then
        nvgText(vg, 900, 25, "FIRE", nil)
    end
end

function DrawGameOver(vg)
    -- Dim background
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 200))
    nvgFill(vg)

    nvgFontSize(vg, 80)
    nvgFontFace(vg, "sans-bold")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFillColor(vg, nvgRGBA(255, 0, 0, 255))
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 50, "GAME OVER", nil)

    nvgFontSize(vg, 30)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 50, string.format("Final Score: %d", score), nil)

    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(255, 255, 100, 255))
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 120, "Press R or Tap Jump to Restart", nil)
end

function DrawWin(vg)
    -- Victory background
    local gradient = nvgLinearGradient(vg, 0, 0, 0, SCREEN_HEIGHT,
                                       nvgRGBA(255, 215, 0, 255), nvgRGBA(255, 140, 0, 255))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    nvgFillPaint(vg, gradient)
    nvgFill(vg)

    nvgFontSize(vg, 80)
    nvgFontFace(vg, "sans-bold")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 80, "VICTORY!", nil)

    nvgFontSize(vg, 40)
    nvgFillColor(vg, nvgRGBA(50, 50, 50, 255))
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2, string.format("Score: %d", score), nil)
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 50, string.format("Coins: %d", coins), nil)

    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(100, 50, 0, 255))
    nvgText(vg, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 130, "Press R or Tap Jump to Play Again", nil)

    -- Animated stars
    for i = 1, 20 do
        local time = os.clock()
        local angle = (i / 20) * math.pi * 2 + time
        local radius = 200 + math.sin(time + i) * 50
        local starX = SCREEN_WIDTH/2 + math.cos(angle) * radius
        local starY = SCREEN_HEIGHT/2 + math.sin(angle) * radius
        local size = 5 + math.sin(time * 3 + i) * 3

        nvgBeginPath(vg)
        nvgCircle(vg, starX, starY, size)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
        nvgFill(vg)
    end
end

function Stop()
    -- Clean up NanoVG context
    if nvgContext ~= nil then
        nvgDelete(nvgContext)
        nvgContext = nil
        print("NanoVG context deleted")
    end
    print("Super Mario game stopped")
end
