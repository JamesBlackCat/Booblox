-- ============================================================
-- SCHIZOPHRENIA | Client-sided LocalScript
-- Place inside StarterPlayerScripts or StarterCharacterScripts
-- ============================================================

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    EventCooldownMin    = 30,    -- minimum seconds between schizo events
    EventCooldownMax    = 120,   -- maximum seconds between schizo events
    BotDurationMin      = 1,     -- minimum seconds a bot stays alive
    BotDurationMax      = 25,    -- maximum seconds a bot stays alive
    NearbyRadius        = 60,    -- studs radius considered "nearby"
    MajorityEventChance = 0.08,  -- 8% chance event hits 90–100% of all players
    BotFastWalkChance   = 0.20,  -- 20% chance bot walks slightly faster
    BotStareChance      = 0.10,  -- 10% chance a bot has stare behaviour
    BotChatChance       = 0.35,  -- 35% chance bot sends a message during its life
    BotMirrorChatChance = 0.12,  -- 12% of those: mirrors a real player chat instead
    BotChatDelayMin     = 3,     -- minimum seconds before bot speaks
    BotChatDelayMax     = 8,     -- maximum seconds before bot speaks
    NodeDropInterval    = 1,     -- seconds between waypoint drops
    NodeExpiry          = 1200,  -- 20 minutes — nodes live this long in seconds
    NodeGridSize        = 4,     -- studs between each grid part around anchor
    WallRayLength       = 20,    -- length of each face raycast
    FreeRouteChance     = 0.15,  -- 15% chance bot ignores node system and pathfinds freely
    NormalWalkMin       = 12,    -- normal walk speed range
    NormalWalkMax       = 16,
    FastWalkMin         = 18,    -- fast walk speed range
    FastWalkMax         = 24,
}

-- ============================================================
-- EERIE CHAT PHRASES
-- ============================================================
local BOT_PHRASES = {
    "did you see that",
    "...",
    "where did they go",
    "lol",
    "wait what",
    "hm",
    "hello?",
    "i was just here",
    "guys",
    "what just happened",
    "never mind",
    "ok",
    "did i just",
    "why is everyone",
    "oh",
    "nvm",
    "bro what",
    "that was weird",
    "i think i saw something",
    "hey",
    "huh",
    "hold on",
    "wait",
    "???",
    "no way",
}

-- ============================================================
-- STATE
-- ============================================================
local nodes            = {}   -- array of { anchor=Part, grid={Part,...}, timestamp=number }
local activeBots       = {}   -- array of { bot=Model, realPlayer=Player, active=bool, isStaring=bool }
local recentChats      = {}   -- [Player] = most recent chat string
local eventOnCooldown  = false
local isInitialized    = false
local lastNodeDrop     = 0

-- ============================================================
-- LOADING SCREEN
-- ============================================================
local function showLoadingScreen()
    local gui = Instance.new("ScreenGui")
    gui.Name              = "SchizoLoader"
    gui.IgnoreGuiInset    = true
    gui.ResetOnSpawn      = false
    gui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
    gui.Parent            = LocalPlayer.PlayerGui

    local bg = Instance.new("Frame")
    bg.Size                 = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3     = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel      = 0
    bg.Parent               = gui

    local label = Instance.new("TextLabel")
    label.Size                = UDim2.new(0.6, 0, 0.2, 0)
    label.Position            = UDim2.new(0.2, 0, 0.4, 0)
    label.BackgroundTransparency = 1
    label.Text                = "Schizophrenia"
    label.TextColor3          = Color3.fromRGB(255, 255, 255)
    label.TextScaled          = true
    label.Font                = Enum.Font.GothamBold
    label.TextTransparency    = 1
    label.Parent              = bg

    -- Fade text in
    TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 0
    }):Play()

    task.wait(0.9)

    -- Fade text and background out together
    TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1
    }):Play()
    local bgFade = TweenService:Create(bg, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        BackgroundTransparency = 1
    })
    bgFade:Play()
    bgFade.Completed:Wait()

    gui:Destroy()
end

-- ============================================================
-- UTILITY
-- ============================================================
local function getHRP(player)
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function setLocalTransparency(character, t)
    for _, part in ipairs(character:GetDescendants()) do
        if (part:IsA("BasePart") or part:IsA("MeshPart")) and part.Name ~= "HumanoidRootPart" then
            part.LocalTransparencyModifier = t
        end
    end
end

local function getNearbyPlayers(radius)
    local localHRP = getHRP(LocalPlayer)
    if not localHRP then return {} end
    local result = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local hrp = getHRP(p)
            if hrp and (localHRP.Position - hrp.Position).Magnitude <= radius then
                table.insert(result, p)
            end
        end
    end
    return result
end

local function getOtherPlayers()
    local result = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(result, p) end
    end
    return result
end

local function isBotVisible(botHRP)
    if not botHRP then return false end
    local _, onScreen = Camera:WorldToScreenPoint(botHRP.Position)
    if not onScreen then return false end
    local origin    = Camera.CFrame.Position
    local direction = botHRP.Position - origin
    local params    = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { workspace:FindFirstChild("SchizoNodes") or Instance.new("Folder") }
    local hit = workspace:Raycast(origin, direction, params)
    return hit == nil  -- no wall blocking = visible
end

local function playerLookingAt(botHRP)
    if not botHRP then return false end
    local toBot  = (botHRP.Position - Camera.CFrame.Position).Unit
    return Camera.CFrame.LookVector:Dot(toBot) > 0.5
end

-- ============================================================
-- NODE / WAYPOINT SYSTEM
-- ============================================================
local nodeFolder = Instance.new("Folder")
nodeFolder.Name   = "SchizoNodes"
nodeFolder.Parent = workspace

local GRID_OFFSETS = {
    Vector3.new(-1, 0, -1), Vector3.new(0, 0, -1), Vector3.new(1, 0, -1),
    Vector3.new(-1, 0,  0),                          Vector3.new(1, 0,  0),
    Vector3.new(-1, 0,  1), Vector3.new(0, 0,  1),  Vector3.new(1, 0,  1),
}

local function dropNode(position)
    local anchor = Instance.new("Part")
    anchor.Size         = Vector3.new(1, 0.1, 1)
    anchor.CFrame       = CFrame.new(position)
    anchor.Anchored     = true
    anchor.CanCollide   = false
    anchor.Transparency = 1
    anchor.Name         = "SchizoAnchor"
    anchor.Parent       = nodeFolder

    local grid = {}
    for _, offset in ipairs(GRID_OFFSETS) do
        local gp = Instance.new("Part")
        gp.Size         = Vector3.new(1, 0.1, 1)
        gp.CFrame       = CFrame.new(position + offset * CONFIG.NodeGridSize)
        gp.Anchored     = true
        gp.CanCollide   = false
        gp.Transparency = 1
        gp.Name         = "SchizoNode"
        gp.Parent       = nodeFolder
        table.insert(grid, gp)
    end

    table.insert(nodes, { anchor = anchor, grid = grid, timestamp = os.time() })
end

local function cleanNodes()
    local now = os.time()
    local i   = 1
    while i <= #nodes do
        local nd = nodes[i]
        if now - nd.timestamp >= CONFIG.NodeExpiry then
            nd.anchor:Destroy()
            for _, gp in ipairs(nd.grid) do gp:Destroy() end
            table.remove(nodes, i)
        else
            i = i + 1
        end
    end
end

local function randomNodePos()
    if #nodes == 0 then return nil end
    local nd   = nodes[math.random(1, #nodes)]
    local pool = { nd.anchor }
    for _, gp in ipairs(nd.grid) do table.insert(pool, gp) end
    local chosen = pool[math.random(1, #pool)]
    return chosen.Position + Vector3.new(0, 3, 0)
end

-- ============================================================
-- WALL / FACE RAYCASTS
-- ============================================================
local FACE_ANGLES = { -20, -10, 0, 10, 20 }

local function pathClear(fromHRP, toPos)
    local origin = fromHRP.Position + Vector3.new(0, 1, 0)
    local base   = (toPos - origin).Unit
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { nodeFolder }
    local clear = 0
    for _, angle in ipairs(FACE_ANGLES) do
        local rotated = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(angle)) * base
        if not workspace:Raycast(origin, rotated * CONFIG.WallRayLength, params) then
            clear += 1
        end
    end
    return clear >= 2  -- at least 2 of 5 rays unobstructed = passable
end

-- ============================================================
-- BOT CHAT BUBBLE
-- ============================================================
local function showBubble(botModel, message)
    local hrp = botModel:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bb = Instance.new("BillboardGui")
    bb.Size          = UDim2.new(0, 220, 0, 55)
    bb.StudsOffset   = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop   = false
    bb.Parent        = hrp

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = bb

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent       = bg

    local txt = Instance.new("TextLabel")
    txt.Size                 = UDim2.new(1, -8, 1, -4)
    txt.Position             = UDim2.new(0, 4, 0, 2)
    txt.BackgroundTransparency = 1
    txt.TextColor3           = Color3.fromRGB(20, 20, 20)
    txt.TextScaled           = true
    txt.Font                 = Enum.Font.Gotham
    txt.Text                 = message
    txt.Parent               = bg

    task.delay(4, function()
        if bb and bb.Parent then bb:Destroy() end
    end)
end

local function scheduleBotChat(player, botModel)
    if math.random() > CONFIG.BotChatChance then return end
    local delay = math.random(CONFIG.BotChatDelayMin, CONFIG.BotChatDelayMax)
    task.delay(delay, function()
        if not botModel or not botModel.Parent then return end
        local msg
        if math.random() < CONFIG.BotMirrorChatChance and recentChats[player] then
            msg = recentChats[player]
        else
            msg = BOT_PHRASES[math.random(1, #BOT_PHRASES)]
        end
        showBubble(botModel, msg)
    end)
end

-- ============================================================
-- BOT MOVEMENT
-- ============================================================
local function navigateBot(bot, speed)
    local hrp      = bot:FindFirstChild("HumanoidRootPart")
    local humanoid = bot:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.WalkSpeed = speed

    local freeRoute = math.random() < CONFIG.FreeRouteChance
    local target    = randomNodePos()

    if freeRoute or not target then
        -- PathfindingService free route
        local dest = target or (hrp.Position + Vector3.new(math.random(-30, 30), 0, math.random(-30, 30)))
        local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
        local ok   = pcall(function() path:ComputeAsync(hrp.Position, dest) end)
        if ok and path.Status == Enum.PathStatus.Success then
            for _, wp in ipairs(path:GetWaypoints()) do
                if not bot.Parent then break end
                humanoid:MoveTo(wp.Position)
                humanoid.MoveToFinished:Wait()
            end
        else
            humanoid:MoveTo(dest)
            task.wait(2)
        end
        return
    end

    -- Node-based route with wall check
    if pathClear(hrp, target) then
        humanoid:MoveTo(target)
        local t0 = tick()
        while bot.Parent and (hrp.Position - target).Magnitude > 4 do
            if tick() - t0 > 8 then break end
            task.wait(0.2)
        end
    else
        -- Try an alternate node as a shortcut
        local alt = randomNodePos()
        if alt then
            humanoid:MoveTo(alt)
            task.wait(2)
        end
    end
end

-- ============================================================
-- STARE BEHAVIOUR
-- ============================================================
local function handleStare(bot, data)
    local botHRP = bot:FindFirstChild("HumanoidRootPart")
    if not botHRP then return end

    if not playerLookingAt(botHRP) then
        -- Player has looked away — bot rotates to face them
        local localHRP = getHRP(LocalPlayer)
        if localHRP then
            local dir = Vector3.new(
                localHRP.Position.X - botHRP.Position.X,
                0,
                localHRP.Position.Z - botHRP.Position.Z
            ).Unit
            botHRP.CFrame = CFrame.new(botHRP.Position, botHRP.Position + dir)
        end
        data.isStaring = true
    elseif data.isStaring then
        -- Player looked back — resume normal
        data.isStaring = false
    end
end

-- ============================================================
-- CLONE BUILDER
-- ============================================================
local function buildClone(player)
    local char = player.Character
    if not char then return nil end
    local clone = char:Clone()
    clone.Name = "SchizoBot_" .. player.Name
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("ModuleScript") then
            v:Destroy()
        end
    end
    local anim = clone:FindFirstChildOfClass("Animator")
    if anim then anim:Destroy() end
    clone.Parent = workspace
    return clone
end

-- ============================================================
-- SCHIZO SEQUENCE (per targeted player)
-- ============================================================
local function runSequence(player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Hide real character locally
    setLocalTransparency(char, 1)

    local bot = buildClone(player)
    if not bot then
        setLocalTransparency(char, 0)
        return
    end

    local humanoid = bot:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.Health = humanoid.MaxHealth end

    local duration  = math.random(CONFIG.BotDurationMin, CONFIG.BotDurationMax)
    local isFast    = math.random() < CONFIG.BotFastWalkChance
    local speed     = isFast
        and math.random(CONFIG.FastWalkMin, CONFIG.FastWalkMax)
        or  math.random(CONFIG.NormalWalkMin, CONFIG.NormalWalkMax)
    local canStare  = math.random() < CONFIG.BotStareChance

    local data = { bot = bot, realPlayer = player, active = true, isStaring = false }
    table.insert(activeBots, data)

    scheduleBotChat(player, bot)

    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < duration do
            if not bot or not bot.Parent then break end

            if canStare then
                handleStare(bot, data)
            end

            if not data.isStaring then
                navigateBot(bot, speed)
            end

            task.wait(0.3)
        end

        data.active = false

        -- Wait until player cannot see the bot before removing it
        local botHRP  = bot:FindFirstChild("HumanoidRootPart")
        local waited  = 0
        while isBotVisible(botHRP) and waited < 12 do
            task.wait(0.1)
            waited += 0.1
        end

        if bot and bot.Parent then bot:Destroy() end

        -- Restore real character visibility
        if char and char.Parent then
            setLocalTransparency(char, 0)
        end

        -- Remove from tracker
        for i, d in ipairs(activeBots) do
            if d.realPlayer == player then
                table.remove(activeBots, i)
                break
            end
        end
    end)
end

-- ============================================================
-- SCHIZO EVENT TRIGGER
-- ============================================================
local function triggerEvent()
    if eventOnCooldown then return end
    eventOnCooldown = true

    local allOthers = getOtherPlayers()
    local targets   = {}

    if math.random() < CONFIG.MajorityEventChance and #allOthers > 0 then
        -- Hit 90–100% of all players
        local ratio = math.random(90, 100) / 100
        local count = math.max(1, math.floor(#allOthers * ratio))
        -- Shuffle
        local pool = table.move(allOthers, 1, #allOthers, 1, {})
        for i = #pool, 2, -1 do
            local j = math.random(1, i)
            pool[i], pool[j] = pool[j], pool[i]
        end
        for i = 1, count do table.insert(targets, pool[i]) end
    else
        targets = getNearbyPlayers(CONFIG.NearbyRadius)
        if #targets == 0 then targets = allOthers end
    end

    if #targets == 0 then
        -- No one to clone; reset cooldown sooner
        task.delay(10, function() eventOnCooldown = false end)
        return
    end

    -- Randomly pick how many player clones to spawn this event
    local cloneCount = math.random(1, #targets)
    -- Shuffle targets for variety
    for i = #targets, 2, -1 do
        local j = math.random(1, i)
        targets[i], targets[j] = targets[j], targets[i]
    end
    for i = 1, cloneCount do
        task.spawn(function() runSequence(targets[i]) end)
    end

    local cooldown = math.random(CONFIG.EventCooldownMin, CONFIG.EventCooldownMax)
    task.delay(cooldown, function() eventOnCooldown = false end)
end

-- ============================================================
-- RANDOM EVENT SCHEDULER
-- ============================================================
local function scheduleNext()
    local wait = math.random(CONFIG.EventCooldownMin, CONFIG.EventCooldownMax)
    task.delay(wait, function()
        triggerEvent()
        scheduleNext()
    end)
end

-- ============================================================
-- HEARTBEAT — node drops + cleanup
-- ============================================================
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastNodeDrop >= CONFIG.NodeDropInterval then
        lastNodeDrop = now
        for _, p in ipairs(Players:GetPlayers()) do
            local hrp = getHRP(p)
            if hrp then dropNode(hrp.Position) end
        end
        cleanNodes()
    end
end)

-- ============================================================
-- CHAT LISTENER — capture recent player messages for mirror
-- ============================================================
local function setupChat()
    -- Modern TextChatService
    local ok = pcall(function()
        local TCS = game:GetService("TextChatService")
        TCS.MessageReceived:Connect(function(msg)
            local src = msg.TextSource
            if src then
                local p = Players:GetPlayerByUserId(src.UserId)
                if p and p ~= LocalPlayer then
                    recentChats[p] = msg.Text
                end
            end
        end)
    end)
    if not ok then
        -- Legacy chat fallback
        local function hookPlayer(p)
            p.Chatted:Connect(function(msg)
                recentChats[p] = msg
            end)
        end
        for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
        Players.PlayerAdded:Connect(hookPlayer)
    end
    Players.PlayerRemoving:Connect(function(p) recentChats[p] = nil end)
end

-- ============================================================
-- INIT
-- ============================================================
local function init()
    if isInitialized then return end
    isInitialized = true

    showLoadingScreen()
    task.wait(0.1)
    setupChat()
    scheduleNext()
end

-- Start when character is ready
if LocalPlayer.Character then
    init()
else
    LocalPlayer.CharacterAdded:Once(function()
        init()
    end)
end
