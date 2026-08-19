-- Flappy Bird Game with NanoVG
-- A beautiful, smooth Flappy Bird implementation using vector graphics
-- Features: Gradients, animations, particle effects, smooth movement

require "LuaScripts/Utilities/Sample"
local UI = require("urhox-libs/UI")

local nvgContext = nil

-- Game state
local gameState = "menu"  -- menu, playing, gameover
local bird = {
    x = 0,  -- Will be set in Start()
    y = 0,
    velocity = 0,
    rotation = 0,
    radius = 18
}

local pipes = {}
local pipeGap = 200  -- Increased for portrait mode
local pipeWidth = 90  -- Wider pipes for portrait
local pipeSpeed = 150  -- Slower for portrait
local pipeSpawnTimer = 0
local pipeSpawnInterval = 2.2  -- Longer interval for portrait
local groundHeight = 60  -- Ground height for portrait mode

local score = 0
local highScore = 0
local gravity = 800
local jumpStrength = -350

-- Particles for effects
local particles = {}

-- Animation
local time = 0
local groundOffset = 0

function Start()
    local graphics = GetGraphics()
    graphics:SetMode(450, 800)

    SampleStart()

    nvgContext = nvgCreate(1)

    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    -- Load font for NanoVG
    local fontPath = "Fonts/MiSans-Regular.ttf"
    if nvgCreateFont(nvgContext, "sans", fontPath) == -1 then
        print("ERROR: Could not load font: " .. fontPath)
        return
    end

    print("Flappy Bird started - Click to play!")

    -- Initialize bird position for portrait mode
    local graphics = GetGraphics()
    bird.x = graphics:GetWidth() / 3  -- Position bird at 1/3 from left
    bird.y = graphics:GetHeight() / 2

    CreateInstructions()
    SampleInitMouseMode(MM_FREE)

    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleMouseClick")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

function Stop()
    UI.Shutdown()
    if nvgContext ~= nil then
        nvgDelete(nvgContext)
        nvgContext = nil
    end
end

function CreateInstructions()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        paddingTop = 10,
        alignItems = "center",
        children = {
            UI.Label {
                text = "Flappy Bird - Click or SPACE to flap!",
                fontSize = 15,
                fontColor = { 255, 255, 255, 255 },
            },
        }
    })
end

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    time = time + timeStep

    if gameState == "playing" then
        UpdateGame(timeStep)
    end
end

function UpdateGame(timeStep)
    -- Update bird physics
    bird.velocity = bird.velocity + gravity * timeStep
    bird.y = bird.y + bird.velocity * timeStep

    -- Update bird rotation based on velocity
    bird.rotation = math.max(-30, math.min(90, bird.velocity * 0.08))

    -- Update ground scroll
    groundOffset = (groundOffset + pipeSpeed * timeStep) % 50

    -- Update pipes
    pipeSpawnTimer = pipeSpawnTimer + timeStep
    if pipeSpawnTimer >= pipeSpawnInterval then
        pipeSpawnTimer = 0
        SpawnPipe()
    end

    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()

    for i = #pipes, 1, -1 do
        local pipe = pipes[i]
        pipe.x = pipe.x - pipeSpeed * timeStep

        -- Check if pipe passed bird (score)
        if not pipe.scored and pipe.x + pipeWidth < bird.x then
            pipe.scored = true
            score = score + 1
            CreateScoreParticles()
        end

        -- Remove off-screen pipes
        if pipe.x + pipeWidth < 0 then
            table.remove(pipes, i)
        end

        -- Collision detection
        if CheckCollision(pipe) then
            GameOver()
        end
    end

    -- Check ground/ceiling collision
    if bird.y - bird.radius < 0 or bird.y + bird.radius > height - groundHeight then
        GameOver()
    end

    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - timeStep
        p.x = p.x + p.vx * timeStep
        p.y = p.y + p.vy * timeStep
        p.vy = p.vy + 300 * timeStep

        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

function SpawnPipe()
    local graphics = GetGraphics()
    local height = graphics:GetHeight()
    local width = graphics:GetWidth()

    local minHeight = 100
    local maxHeight = height - groundHeight - pipeGap - 100
    local topHeight = math.random(minHeight, maxHeight)

    table.insert(pipes, {
        x = width,
        topHeight = topHeight,
        scored = false
    })
end

function CheckCollision(pipe)
    local bx, by, br = bird.x, bird.y, bird.radius
    local px, pw = pipe.x, pipeWidth
    local topHeight = pipe.topHeight
    local graphics = GetGraphics()
    local height = graphics:GetHeight()
    local bottomY = topHeight + pipeGap

    -- Check if bird is in pipe's x range
    if bx + br > px and bx - br < px + pw then
        -- Check if bird hit top or bottom pipe
        if by - br < topHeight or by + br > bottomY then
            return true
        end
    end

    return false
end

function CreateScoreParticles()
    for i = 1, 10 do
        local angle = math.random() * math.pi * 2
        local speed = 100 + math.random() * 100
        table.insert(particles, {
            x = bird.x,
            y = bird.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 100,
            life = 0.5,
            maxLife = 0.5,
            color = {255, 255, 100 + math.random(155)}
        })
    end
end

function CreateDeathParticles()
    for i = 1, 30 do
        local angle = math.random() * math.pi * 2
        local speed = 150 + math.random() * 150
        table.insert(particles, {
            x = bird.x,
            y = bird.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 150,
            life = 1.0,
            maxLife = 1.0,
            color = {255, 100 + math.random(100), 50}
        })
    end
end

function GameOver()
    if gameState ~= "playing" then return end

    gameState = "gameover"
    CreateDeathParticles()

    if score > highScore then
        highScore = score
    end
end

function ResetGame()
    local graphics = GetGraphics()
    bird.x = graphics:GetWidth() / 3  -- Reset bird x position for portrait
    bird.y = graphics:GetHeight() / 2
    bird.velocity = 0
    bird.rotation = 0
    pipes = {}
    particles = {}
    score = 0
    pipeSpawnTimer = 0
    gameState = "playing"
end

function HandleMouseClick(eventType, eventData)
    if gameState == "menu" then
        ResetGame()
    elseif gameState == "playing" then
        bird.velocity = jumpStrength
    elseif gameState == "gameover" then
        ResetGame()
    end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if key == KEY_SPACE then
        if gameState == "menu" then
            ResetGame()
        elseif gameState == "playing" then
            bird.velocity = jumpStrength
        elseif gameState == "gameover" then
            ResetGame()
        end
    end
end

function HandleRender(eventType, eventData)
    if nvgContext == nil then return end

    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()

    nvgBeginFrame(nvgContext, width, height, 1.0)

    -- Draw everything
    DrawBackground(nvgContext, width, height)
    DrawPipes(nvgContext, width, height)
    DrawGround(nvgContext, width, height)
    DrawBird(nvgContext)
    DrawParticles(nvgContext)
    DrawUI(nvgContext, width, height)

    nvgEndFrame(nvgContext)
end

function DrawBackground(ctx, width, height)
    -- Sky gradient
    local bg = nvgLinearGradient(ctx, 0, 0, 0, height,
        nvgRGBA(135, 206, 235, 255),  -- Sky blue
        nvgRGBA(176, 224, 230, 255))  -- Powder blue

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, bg)
    nvgFill(ctx)

    -- Clouds
    local cloudTime = time * 20
    for i = 0, 2 do
        local x = ((cloudTime + i * 300) % (width + 200)) - 100
        local y = 80 + i * 60
        DrawCloud(ctx, x, y)
    end

    -- Sun
    local sunGlow = nvgRadialGradient(ctx, width - 100, 100, 30, 60,
        nvgRGBA(255, 255, 100, 100),
        nvgRGBA(255, 255, 100, 0))

    nvgBeginPath(ctx)
    nvgCircle(ctx, width - 100, 100, 60)
    nvgFillPaint(ctx, sunGlow)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, width - 100, 100, 30)
    nvgFillColor(ctx, nvgRGBA(255, 255, 100, 255))
    nvgFill(ctx)
end

function DrawCloud(ctx, x, y)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, 25)
    nvgCircle(ctx, x + 20, y - 5, 30)
    nvgCircle(ctx, x + 40, y, 25)
    nvgCircle(ctx, x + 25, y + 10, 20)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 180))
    nvgFill(ctx)
end

function DrawPipes(ctx, width, height)
    for _, pipe in ipairs(pipes) do
        -- Top pipe
        DrawPipe(ctx, pipe.x, 0, pipeWidth, pipe.topHeight, false)

        -- Bottom pipe
        local bottomY = pipe.topHeight + pipeGap
        DrawPipe(ctx, pipe.x, bottomY, pipeWidth, height - groundHeight - bottomY, true)
    end
end

function DrawPipe(ctx, x, y, w, h, isBottom)
    -- Pipe body gradient
    local pipeGradient = nvgLinearGradient(ctx, x, y, x + w, y,
        nvgRGBA(80, 200, 80, 255),
        nvgRGBA(50, 170, 50, 255))

    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, pipeGradient)
    nvgFill(ctx)

    -- Pipe outline
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgStrokeColor(ctx, nvgRGBA(40, 140, 40, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    -- Pipe cap
    local capH = 30
    local capW = w + 10
    local capX = x - 5
    local capY = isBottom and y or (y + h - capH)

    local capGradient = nvgLinearGradient(ctx, capX, capY, capX + capW, capY,
        nvgRGBA(100, 220, 100, 255),
        nvgRGBA(60, 180, 60, 255))

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, capX, capY, capW, capH, 5)
    nvgFillPaint(ctx, capGradient)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, capX, capY, capW, capH, 5)
    nvgStrokeColor(ctx, nvgRGBA(40, 140, 40, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    -- Highlight
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 5, y + 5, 8, h - 10)
    nvgFillColor(ctx, nvgRGBA(120, 255, 120, 80))
    nvgFill(ctx)
end

function DrawGround(ctx, width, height)
    local groundY = height - groundHeight

    -- Ground gradient
    local groundGradient = nvgLinearGradient(ctx, 0, groundY, 0, height,
        nvgRGBA(210, 180, 140, 255),  -- Tan
        nvgRGBA(160, 130, 90, 255))   -- Dark tan

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, groundY, width, groundHeight)
    nvgFillPaint(ctx, groundGradient)
    nvgFill(ctx)

    -- Grass pattern
    for i = 0, math.ceil(width / 50) do
        local x = (i * 50 - groundOffset)
        nvgBeginPath(ctx)
        for j = 0, 5 do
            nvgRect(ctx, x + j * 8, groundY - 5, 3, 5)
        end
        nvgFillColor(ctx, nvgRGBA(100, 180, 100, 255))
        nvgFill(ctx)
    end

    -- Ground line
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, groundY)
    nvgLineTo(ctx, width, groundY)
    nvgStrokeColor(ctx, nvgRGBA(100, 150, 100, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)
end

function DrawBird(ctx)
    nvgSave(ctx)

    -- Transform to bird position and rotation
    nvgTranslate(ctx, bird.x, bird.y)
    nvgRotate(ctx, bird.rotation * math.pi / 180)

    -- Bird body (gradient)
    local bodyGradient = nvgRadialGradient(ctx, 0, 0, 5, bird.radius,
        nvgRGBA(255, 220, 100, 255),
        nvgRGBA(255, 180, 50, 255))

    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, 0, bird.radius)
    nvgFillPaint(ctx, bodyGradient)
    nvgFill(ctx)

    -- Bird outline
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, 0, bird.radius)
    nvgStrokeColor(ctx, nvgRGBA(200, 120, 0, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    -- Wing (animated)
    local wingAngle = math.sin(time * 10) * 20
    nvgSave(ctx)
    nvgRotate(ctx, wingAngle * math.pi / 180)

    local wingGradient = nvgLinearGradient(ctx, -5, -5, 5, 5,
        nvgRGBA(255, 200, 80, 255),
        nvgRGBA(255, 150, 30, 255))

    nvgBeginPath(ctx)
    nvgEllipse(ctx, -bird.radius + 5, 0, 12, 8)
    nvgFillPaint(ctx, wingGradient)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgEllipse(ctx, -bird.radius + 5, 0, 12, 8)
    nvgStrokeColor(ctx, nvgRGBA(200, 120, 0, 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    nvgRestore(ctx)

    -- Eye white
    nvgBeginPath(ctx)
    nvgCircle(ctx, 8, -5, 5)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgFill(ctx)

    -- Eye pupil
    nvgBeginPath(ctx)
    nvgCircle(ctx, 9, -5, 3)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 255))
    nvgFill(ctx)

    -- Beak
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, bird.radius - 5, 0)
    nvgLineTo(ctx, bird.radius + 8, 0)
    nvgLineTo(ctx, bird.radius - 2, 4)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(255, 140, 0, 255))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, bird.radius - 5, 0)
    nvgLineTo(ctx, bird.radius + 8, 0)
    nvgLineTo(ctx, bird.radius - 2, 4)
    nvgClosePath(ctx)
    nvgStrokeColor(ctx, nvgRGBA(200, 100, 0, 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    nvgRestore(ctx)
end

function DrawParticles(ctx)
    for _, p in ipairs(particles) do
        local alpha = (p.life / p.maxLife) * 255
        nvgBeginPath(ctx)
        nvgCircle(ctx, p.x, p.y, 3)
        nvgFillColor(ctx, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
        nvgFill(ctx)
    end
end

function DrawUI(ctx, width, height)
    if gameState == "menu" then
        -- Title
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 60)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, width / 2, height / 2 - 50, "Flappy Bird", nil)

        -- Subtitle
        nvgFontSize(ctx, 30)
        nvgFillColor(ctx, nvgRGBA(255, 255, 200, 255))
        nvgText(ctx, width / 2, height / 2 + 20, "Click to Start", nil)

    elseif gameState == "playing" then
        -- Score
        DrawScore(ctx, width / 2, 80, score)

    elseif gameState == "gameover" then
        -- Game Over panel (adjusted for portrait mode)
        local panelW = math.min(360, width - 40)  -- Fit panel to screen width
        local panelH = 280
        local panelX = (width - panelW) / 2
        local panelY = (height - panelH) / 2

        -- Panel shadow
        local shadow = nvgBoxGradient(ctx, panelX, panelY + 2, panelW, panelH,
            10, 10, nvgRGBA(0, 0, 0, 128), nvgRGBA(0, 0, 0, 0))
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, panelX - 5, panelY - 5, panelW + 10, panelH + 10, 12)
        nvgFillPaint(ctx, shadow)
        nvgFill(ctx)

        -- Panel background
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, panelX, panelY, panelW, panelH, 10)
        nvgFillColor(ctx, nvgRGBA(50, 50, 50, 240))
        nvgFill(ctx)

        -- Panel border
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, panelX, panelY, panelW, panelH, 10)
        nvgStrokeColor(ctx, nvgRGBA(255, 200, 100, 255))
        nvgStrokeWidth(ctx, 3)
        nvgStroke(ctx)

        -- Game Over text
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 50)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 100, 100, 255))
        nvgText(ctx, width / 2, panelY + 60, "Game Over!", nil)

        -- Score
        nvgFontSize(ctx, 30)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, width / 2, panelY + 120, "Score: " .. score, nil)

        -- High score
        nvgFontSize(ctx, 25)
        nvgFillColor(ctx, nvgRGBA(255, 220, 100, 255))
        nvgText(ctx, width / 2, panelY + 160, "Best: " .. highScore, nil)

        -- Restart hint
        nvgFontSize(ctx, 20)
        nvgFillColor(ctx, nvgRGBA(200, 200, 200, 255))
        nvgText(ctx, width / 2, panelY + 210, "Click to Restart", nil)
    end
end

function DrawScore(ctx, x, y, value)
    local scoreStr = tostring(value)

    -- Score shadow
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 70)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 100))
    nvgText(ctx, x + 3, y + 3, scoreStr, nil)

    -- Score
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgText(ctx, x, y, scoreStr, nil)

    -- Score outline
    nvgStrokeColor(ctx, nvgRGBA(0, 0, 0, 200))
    nvgStrokeWidth(ctx, 3)
    nvgText(ctx, x, y, scoreStr, nil)
end

function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end
