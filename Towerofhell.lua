--[[
    TOWER OF HELL - FULL FEATURE SUITE
    LocalScript — Run via Executor
    
    FEATURES:
    [ASSIST]   Jump Trajectory, Remove Walls, Camera Phase-Through,
               Remove UI, Invisible Players, Render Distance,
               Kill Part Texture/Color Randomizer
    [FUN MODES] Laps, Race, Streak, Epilepsy, Jumpscare Kick,
               Fog, Flood Escape, OH NO MR EVIL!, Red Light Green Light,
               Annoying/Distraction Mode
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local UserInputService= game:GetService("UserInputService")
local Lighting        = game:GetService("Lighting")
local SoundService    = game:GetService("SoundService")
local StarterGui      = game:GetService("StarterGui")
local HttpService     = game:GetService("HttpService")

local lp             = Players.LocalPlayer
local cam            = workspace.CurrentCamera
local char           = lp.Character or lp.CharacterAdded:Wait()
local humanoid       = char:WaitForChild("Humanoid")
local hrp            = char:WaitForChild("HumanoidRootPart")

-- ============================================================
-- STATE
-- ============================================================
local State = {
    removeWalls       = false,
    cameraPhase       = false,
    removeUI          = { timer = false, levels = false },
    invisPlayers      = false,
    invisWhitelist    = {},
    invisRandom       = 0,
    renderDist        = 100,
    killTexture       = false,
    killColor         = false,
    jumpTraj          = false,
    lapsMode          = false,
    lapCount          = 0,
    raceMode          = false,
    raceTarget        = nil,
    streakMode        = false,
    streakCount       = 0,
    epilepsyMode      = false,
    epilepsyType      = "bw",
    jumpscareMode     = false,
    fogMode           = false,
    floodMode         = false,
    mrEvilMode        = false,
    redLightMode      = false,
    annoyingMode      = false,
}

local removedWalls       = {}
local phasedParts        = {}
local trajParts          = {}
local floodPart          = nil
local mrEvil             = nil
local mrEvilTheme        = nil
local floodTheme         = nil
local epilepsyConn       = nil
local redLightConn       = nil
local annoyConn          = nil
local floodConn          = nil
local mrEvilConn         = nil
local lapConn            = nil
local raceConn           = nil
local streakConn         = nil
local cameraConn         = nil
local trajConn           = nil
local originalFog        = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor }
local originalTextures   = {}
local originalColors     = {}

-- ============================================================
-- UTILITY
-- ============================================================
local function safeSound(id, parent)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Parent = parent or SoundService
    return s
end

local function playSound(id, volume, parent)
    local s = safeSound(id, parent or SoundService)
    s.Volume = volume or 1
    s:Play()
    game:GetService("Debris"):AddItem(s, 20)
    return s
end

local function getTower()
    return workspace:FindFirstChild("tower")
end

local function getFinishes()
    local tower = getTower()
    if not tower then return {} end
    local finishes = tower:FindFirstChild("finishes")
    if not finishes then return {} end
    local parts = {}
    for _, v in ipairs(finishes:GetDescendants()) do
        if v:IsA("BasePart") then table.insert(parts, v) end
    end
    return parts
end

local function notify(msg, duration)
    StarterGui:SetCore("SendNotification", {
        Title   = "TOH Suite",
        Text    = msg,
        Duration = duration or 3,
    })
end

-- ============================================================
-- MAIN GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TOHSuite"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = lp.PlayerGui

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 380, 0, 520)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -260)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(110, 40, 200)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0.5, 0)
titleFix.Position = UDim2.new(0, 0, 0.5, 0)
titleFix.BackgroundColor3 = Color3.fromRGB(110, 40, 200)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🏰  TOH Suite"
titleLabel.TextColor3 = Color3.new(1,1,1)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Minimize/Close
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
minimizeBtn.Position = UDim2.new(1, -62, 0.5, -13)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(60,60,75)
minimizeBtn.Text = "—"
minimizeBtn.TextColor3 = Color3.new(1,1,1)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 14
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0,6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0.5, -13)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

local contentVisible = true
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Size = UDim2.new(1, -8, 1, -44)
contentFrame.Position = UDim2.new(0, 4, 0, 40)
contentFrame.BackgroundTransparency = 1
contentFrame.ScrollBarThickness = 4
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(110,40,200)
contentFrame.CanvasSize = UDim2.new(0,0,0,0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = contentFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0,4)
padding.PaddingLeft = UDim.new(0,2)
padding.PaddingRight = UDim.new(0,2)
padding.Parent = contentFrame

minimizeBtn.MouseButton1Click:Connect(function()
    contentVisible = not contentVisible
    contentFrame.Visible = contentVisible
    mainFrame.Size = contentVisible and UDim2.new(0,380,0,520) or UDim2.new(0,380,0,40)
end)
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Drag
local dragging, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = inp.Position
        startPos = mainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local delta = inp.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
-- GUI BUILDER HELPERS
-- ============================================================
local function sectionLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -4, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(150,100,255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order or 0
    lbl.Parent = contentFrame
    return lbl
end

local function makeToggle(label, order, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(28,28,38)
    row.BorderSizePixel = 0
    row.LayoutOrder = order or 0
    row.Parent = contentFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-60,1,0)
    lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220,220,230)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,46,0,22)
    btn.Position = UDim2.new(1,-54,0.5,-11)
    btn.BackgroundColor3 = Color3.fromRGB(60,60,75)
    btn.Text = "OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)

    local active = false
    btn.MouseButton1Click:Connect(function()
        active = not active
        btn.Text = active and "ON" or "OFF"
        btn.BackgroundColor3 = active and Color3.fromRGB(110,40,200) or Color3.fromRGB(60,60,75)
        onToggle(active)
    end)

    return row, btn, function() return active end
end

local function makeButton(label, order, onClick, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,-4,0,34)
    btn.BackgroundColor3 = color or Color3.fromRGB(110,40,200)
    btn.Text = label
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order or 0
    btn.Parent = contentFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

local function makeSlider(label, order, min, max, default, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-4,0,50)
    row.BackgroundColor3 = Color3.fromRGB(28,28,38)
    row.BorderSizePixel = 0
    row.LayoutOrder = order or 0
    row.Parent = contentFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-10,0,20)
    lbl.Position = UDim2.new(0,10,0,4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. tostring(default)
    lbl.TextColor3 = Color3.fromRGB(220,220,230)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-20,0,6)
    track.Position = UDim2.new(0,10,0,32)
    track.BackgroundColor3 = Color3.fromRGB(60,60,75)
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(0,3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(110,40,200)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,3)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0,14,0,14)
    knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = UDim2.new((default-min)/(max-min),0,0.5,0)
    knob.BackgroundColor3 = Color3.fromRGB(170,80,255)
    knob.Text = ""
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local value = default
    local draggingSlider = false

    knob.MouseButton1Down:Connect(function() draggingSlider = true end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if draggingSlider and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local pos = track.AbsolutePosition
            local size = track.AbsoluteSize
            local rel = math.clamp((inp.Position.X - pos.X)/size.X, 0, 1)
            value = math.floor(min + rel*(max-min))
            fill.Size = UDim2.new(rel,0,1,0)
            knob.Position = UDim2.new(rel,0,0.5,0)
            lbl.Text = label .. ": " .. tostring(value)
            onChange(value)
        end
    end)
    return row
end

local function makeInput(label, order, placeholder, onSubmit)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-4,0,60)
    row.BackgroundColor3 = Color3.fromRGB(28,28,38)
    row.BorderSizePixel = 0
    row.LayoutOrder = order or 0
    row.Parent = contentFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-10,0,20)
    lbl.Position = UDim2.new(0,10,0,4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220,220,230)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1,-20,0,24)
    box.Position = UDim2.new(0,10,0,28)
    box.BackgroundColor3 = Color3.fromRGB(40,40,55)
    box.Text = ""
    box.PlaceholderText = placeholder or ""
    box.TextColor3 = Color3.new(1,1,1)
    box.PlaceholderColor3 = Color3.fromRGB(120,120,140)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = true
    box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,5)

    box.FocusLost:Connect(function(enter)
        if enter then onSubmit(box.Text) end
    end)
    return row, box
end

-- ============================================================
-- SECTION: ASSIST TOOLS
-- ============================================================
sectionLabel("── ASSIST TOOLS ──", 1)

-- 1. Jump Trajectory Visualizer
makeToggle("Jump Trajectory Visualizer", 2, function(on)
    State.jumpTraj = on
    if not on then
        for _, p in ipairs(trajParts) do pcall(function() p:Destroy() end) end
        trajParts = {}
    end
end)

RunService.Heartbeat:Connect(function()
    if not State.jumpTraj then return end
    char = lp.Character
    if not char then return end
    hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, p in ipairs(trajParts) do pcall(function() p:Destroy() end) end
    trajParts = {}

    local vel = hrp.Velocity
    local gravity = Vector3.new(0, -workspace.Gravity, 0)
    local pos = hrp.Position
    local dt = 0.05
    local steps = 40

    for i = 1, steps do
        local t = i * dt
        local futurePos = pos + vel * t + 0.5 * gravity * t * t
        local dot = Instance.new("Part")
        dot.Size = Vector3.new(0.2, 0.2, 0.2)
        dot.Shape = Enum.PartType.Ball
        dot.Position = futurePos
        dot.Anchored = true
        dot.CanCollide = false
        dot.Material = Enum.Material.Neon
        dot.Color = Color3.fromHSV(i/steps * 0.33, 1, 1)
        dot.CastShadow = false
        dot.Parent = workspace
        game:GetService("Debris"):AddItem(dot, dt * steps + 0.1)
        table.insert(trajParts, dot)
    end
end)

-- 2. Remove Walls
makeToggle("Remove Walls", 3, function(on)
    local tower = getTower()
    if not tower then notify("Tower not found!") return end
    local sections = tower:FindFirstChild("sections")
    if not sections then notify("Sections not found!") return end

    if on then
        for _, desc in ipairs(sections:GetDescendants()) do
            if desc:IsA("BasePart") then
                local name = desc.Name:lower()
                if name:find("wall") or name:find("side") or name:find("border") then
                    table.insert(removedWalls, {part = desc, trans = desc.Transparency})
                    desc.Transparency = 1
                    desc.CanCollide = false
                end
            end
        end
        notify("Walls hidden (" .. #removedWalls .. " parts)")
    else
        for _, data in ipairs(removedWalls) do
            pcall(function()
                data.part.Transparency = data.trans
                data.part.CanCollide = true
            end)
        end
        removedWalls = {}
        notify("Walls restored")
    end
end)

-- 3. Camera Phase-Through (lock cam, fade blocking parts)
makeToggle("Camera Phase-Through", 4, function(on)
    State.cameraPhase = on
    if not on then
        for part, trans in pairs(phasedParts) do
            pcall(function() part.LocalTransparencyModifier = trans end)
        end
        phasedParts = {}
        cam.CameraType = Enum.CameraType.Custom
    else
        cam.CameraType = Enum.CameraType.Custom
    end
end)

if not cameraConn then
    cameraConn = RunService.RenderStepped:Connect(function()
        if not State.cameraPhase then return end
        char = lp.Character
        if not char then return end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local origin = cam.CFrame.Position
        local target = hrp.Position

        local ray = workspace:Raycast(origin, (target - origin), RaycastParams.new())

        for part, _ in pairs(phasedParts) do
            pcall(function() part.LocalTransparencyModifier = 0 end)
        end
        phasedParts = {}

        if ray then
            local part = ray.Instance
            if part and not char:IsAncestorOf(part) then
                phasedParts[part] = part.LocalTransparencyModifier
                local tw = TweenService:Create(part, TweenInfo.new(0.15), {LocalTransparencyModifier = 0.85})
                tw:Play()
            end
        end
    end)
end

-- 4. Remove UI
sectionLabel("Remove UI Elements", 5)
local pg = lp:WaitForChild("PlayerGui")

makeToggle("  Hide Timer", 6, function(on)
    local t = pg:FindFirstChild("timer")
    if t then t.Enabled = not on end
end)

makeToggle("  Hide Stage Levels", 7, function(on)
    local t = pg:FindFirstChild("levels")
    if t then t.Enabled = not on end
end)

-- 5. Invisible Players
makeToggle("Invisible Other Players", 8, function(on)
    State.invisPlayers = on
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            for _, part in ipairs(plr.Character:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") then
                    part.LocalTransparencyModifier = on and 1 or 0
                end
            end
        end
    end
end)

makeButton("  Whitelist Player (type name below)", 9, function()
    notify("Type player name in the box below, then press Enter", 4)
end, Color3.fromRGB(40,40,55))

makeInput("Whitelist Name", 10, "Player name...", function(name)
    if name == "" then return end
    table.insert(State.invisWhitelist, name)
    notify("Whitelisted: " .. name)
    if State.invisPlayers then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == name and plr.Character then
                for _, part in ipairs(plr.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.LocalTransparencyModifier = 0
                    end
                end
            end
        end
    end
end)

-- 6. Render Distance
makeSlider("Render Distance %", 11, 1, 100, 100, function(val)
    State.renderDist = val
    local dist = val * 10
    cam.MaxAxisExtents = dist
end)

-- 7 & 8. Kill Part Texture/Color
sectionLabel("Kill Part Modifiers", 12)

local textures = {
    "rbxassetid://142939267",
    "rbxassetid://263915477",
    "rbxassetid://151353138",
    "rbxassetid://1531833728",
    "rbxassetid://6372755229",
}

local function getKillParts()
    local tower = getTower()
    if not tower then return {} end
    local parts = {}
    for _, desc in ipairs(tower:GetDescendants()) do
        if desc:IsA("BasePart") then
            local hasTouch = desc:FindFirstChildOfClass("TouchTransmitter") or desc:FindFirstChild("TouchInterest")
            local mat = desc.Material
            if hasTouch and mat ~= Enum.Material.Neon then
                table.insert(parts, desc)
            end
        end
    end
    return parts
end

makeToggle("Randomize Kill Part Textures", 13, function(on)
    State.killTexture = on
    local parts = getKillParts()
    if on then
        for _, p in ipairs(parts) do
            originalTextures[p] = p.Material
            p.Material = Enum.Material.SmoothPlastic
            local existing = p:FindFirstChildOfClass("SpecialMesh")
            if not existing then
                local m = Instance.new("SpecialMesh")
                m.MeshType = Enum.MeshType.Brick
                m.TextureId = textures[math.random(1, #textures)]
                m.Parent = p
            else
                existing.TextureId = textures[math.random(1, #textures)]
            end
        end
    else
        for _, p in ipairs(parts) do
            if originalTextures[p] then
                pcall(function() p.Material = originalTextures[p] end)
            end
            local m = p:FindFirstChildOfClass("SpecialMesh")
            if m then m:Destroy() end
        end
        originalTextures = {}
    end
end)

makeToggle("Randomize Kill Part Colors", 14, function(on)
    State.killColor = on
    local parts = getKillParts()
    if on then
        for _, p in ipairs(parts) do
            originalColors[p] = p.Color
            p.Color = Color3.fromHSV(math.random(), 0.9, 1)
        end
    else
        for _, p in ipairs(parts) do
            if originalColors[p] then
                pcall(function() p.Color = originalColors[p] end)
            end
        end
        originalColors = {}
    end
end)

-- ============================================================
-- SECTION: ENVIRONMENT
-- ============================================================
sectionLabel("── ENVIRONMENT ──", 20)

-- Fog Mode
makeToggle("Fog Mode", 21, function(on)
    State.fogMode = on
    if on then
        Lighting.FogStart = 0
        Lighting.FogEnd = 60
        Lighting.FogColor = Color3.fromRGB(180, 190, 200)
    else
        Lighting.FogStart = originalFog.FogStart
        Lighting.FogEnd = originalFog.FogEnd
        Lighting.FogColor = originalFog.FogColor
    end
end)

-- ============================================================
-- SECTION: FUN GAME MODES
-- ============================================================
sectionLabel("── FUN GAME MODES ──", 30)

-- Laps Mode
local lapInfo = Instance.new("TextLabel")
lapInfo.Size = UDim2.new(1,-4,0,24)
lapInfo.BackgroundTransparency = 1
lapInfo.Text = "Laps: 0"
lapInfo.TextColor3 = Color3.fromRGB(180,180,200)
lapInfo.Font = Enum.Font.GothamBold
lapInfo.TextSize = 13
lapInfo.LayoutOrder = 31
lapInfo.Parent = contentFrame

makeToggle("Laps Mode", 31, function(on)
    State.lapsMode = on
    State.lapCount = 0
    lapInfo.Text = "Laps: 0"
    if lapConn then lapConn:Disconnect() lapConn = nil end
    if not on then return end

    lapConn = RunService.Heartbeat:Connect(function()
        char = lp.Character
        if not char then return end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        for _, part in ipairs(getFinishes()) do
            if (hrp.Position - part.Position).Magnitude < 10 then
                State.lapCount += 1
                lapInfo.Text = "Laps: " .. State.lapCount
                task.wait(0.5)
                if char then
                    char:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead)
                end
                task.wait(1)
                break
            end
        end
    end)
end)

-- Race Mode
local raceInfo = Instance.new("TextLabel")
raceInfo.Size = UDim2.new(1,-4,0,24)
raceInfo.BackgroundTransparency = 1
raceInfo.Text = "Race target: none"
raceInfo.TextColor3 = Color3.fromRGB(180,180,200)
raceInfo.Font = Enum.Font.Gotham
raceInfo.TextSize = 12
raceInfo.LayoutOrder = 32
raceInfo.Parent = contentFrame

makeInput("Race Mode — Target Player", 33, "Enter opponent name...", function(name)
    if name == "" then return end
    local target = Players:FindFirstChild(name)
    if not target then notify("Player not found: " .. name) return end
    State.raceTarget = target
    raceInfo.Text = "Race target: " .. name
    notify("Racing against: " .. name)

    if raceConn then raceConn:Disconnect() end
    raceConn = RunService.Heartbeat:Connect(function()
        if not State.raceTarget then return end
        local tc = State.raceTarget.Character
        if not tc then return end
        local thrp = tc:FindFirstChild("HumanoidRootPart")
        if not thrp then return end
        for _, part in ipairs(getFinishes()) do
            if (thrp.Position - part.Position).Magnitude < 10 then
                notify(State.raceTarget.Name .. " finished! You lose this lap!")
                char = lp.Character
                if char then
                    char:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead)
                end
                raceConn:Disconnect()
                raceConn = nil
                task.wait(2)
                break
            end
        end
    end)
end)

-- Streak Mode
local streakInfo = Instance.new("TextLabel")
streakInfo.Size = UDim2.new(1,-4,0,24)
streakInfo.BackgroundTransparency = 1
streakInfo.Text = "Streak: 0"
streakInfo.TextColor3 = Color3.fromRGB(255, 200, 80)
streakInfo.Font = Enum.Font.GothamBold
streakInfo.TextSize = 13
streakInfo.LayoutOrder = 34
streakInfo.Parent = contentFrame

makeToggle("Streak Mode (1 Life)", 35, function(on)
    State.streakMode = on
    if not on then
        if streakConn then streakConn:Disconnect() streakConn = nil end
        return
    end

    local function hookChar(c)
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        hum.Died:Connect(function()
            if not State.streakMode then return end
            State.streakCount = 0
            streakInfo.Text = "Streak: 0 (LOST)"
            notify("Streak broken! Back to 0.")
        end)

        RunService.Heartbeat:Connect(function()
            if not State.streakMode then return end
            local hrp2 = c:FindFirstChild("HumanoidRootPart")
            if not hrp2 then return end
            for _, part in ipairs(getFinishes()) do
                if (hrp2.Position - part.Position).Magnitude < 10 then
                    State.streakCount += 1
                    streakInfo.Text = "Streak: " .. State.streakCount .. " 🔥"
                    notify("Tower complete! Streak: " .. State.streakCount)
                    task.wait(1)
                    break
                end
            end
        end)
    end

    hookChar(lp.Character or lp.CharacterAdded:Wait())
    lp.CharacterAdded:Connect(hookChar)
end)

-- ============================================================
-- EPILEPSY MODE
-- ============================================================
sectionLabel("── CHAOS MODES ──", 40)

local epilepsyWarned = false
makeButton("⚠ Epilepsy Mode (B&W / Color)", 41, function()
    if not epilepsyWarned then
        notify("WARNING: This mode causes rapid flashing. Tap again to confirm.", 5)
        epilepsyWarned = true
        return
    end
    epilepsyWarned = false

    if State.epilepsyMode then
        State.epilepsyMode = false
        if epilepsyConn then epilepsyConn:Disconnect() epilepsyConn = nil end
        Lighting.Brightness = 1
        Lighting.ColorShift_Top = Color3.new(0,0,0)
        return
    end

    -- Ask type
    local typeFrame = Instance.new("Frame")
    typeFrame.Size = UDim2.new(0,200,0,80)
    typeFrame.Position = UDim2.new(0.5,-100,0.5,-40)
    typeFrame.BackgroundColor3 = Color3.fromRGB(28,28,38)
    typeFrame.BorderSizePixel = 0
    typeFrame.ZIndex = 10
    typeFrame.Parent = screenGui
    Instance.new("UICorner", typeFrame).CornerRadius = UDim.new(0,8)

    local bwBtn = Instance.new("TextButton")
    bwBtn.Size = UDim2.new(0.5,-6,0,36)
    bwBtn.Position = UDim2.new(0,4,0.5,-18)
    bwBtn.BackgroundColor3 = Color3.fromRGB(200,200,200)
    bwBtn.Text = "B&W"
    bwBtn.TextColor3 = Color3.new(0,0,0)
    bwBtn.Font = Enum.Font.GothamBold
    bwBtn.TextSize = 13
    bwBtn.BorderSizePixel = 0
    bwBtn.Parent = typeFrame
    Instance.new("UICorner", bwBtn).CornerRadius = UDim.new(0,6)

    local colBtn = Instance.new("TextButton")
    colBtn.Size = UDim2.new(0.5,-6,0,36)
    colBtn.Position = UDim2.new(0.5,2,0.5,-18)
    colBtn.BackgroundColor3 = Color3.fromRGB(180,50,200)
    colBtn.Text = "COLOR"
    colBtn.TextColor3 = Color3.new(1,1,1)
    colBtn.Font = Enum.Font.GothamBold
    colBtn.TextSize = 13
    colBtn.BorderSizePixel = 0
    colBtn.Parent = typeFrame
    Instance.new("UICorner", colBtn).CornerRadius = UDim.new(0,6)

    local function startEpilepsy(epType)
        typeFrame:Destroy()
        State.epilepsyMode = true
        State.epilepsyType = epType
        local t = 0
        epilepsyConn = RunService.RenderStepped:Connect(function(dt)
            if not State.epilepsyMode then return end
            t = t + dt * 10
            if epType == "bw" then
                local v = (math.sin(t) > 0) and 1 or 0
                Lighting.Brightness = v * 5
                Lighting.ColorShift_Top = Color3.new(v, v, v)
            else
                Lighting.ColorShift_Top = Color3.fromHSV(t % 1, 1, 1)
                Lighting.Brightness = 2 + math.sin(t) * 2
            end
        end)
    end

    bwBtn.MouseButton1Click:Connect(function() startEpilepsy("bw") end)
    colBtn.MouseButton1Click:Connect(function() startEpilepsy("color") end)
end, Color3.fromRGB(180,80,50))

-- ============================================================
-- JUMPSCARE KICK MODE
-- ============================================================
local jumpscareActive = false
makeButton("☠ Jumpscare Death Mode", 42, function()
    jumpscareActive = not jumpscareActive
    notify(jumpscareActive and "Jumpscare ON — Streak mode also activated!" or "Jumpscare OFF")
    if not jumpscareActive then return end

    local function doJumpscare()
        local overlay = Instance.new("Frame")
        overlay.Size = UDim2.new(1,0,1,0)
        overlay.BackgroundColor3 = Color3.new(0,0,0)
        overlay.BackgroundTransparency = 0
        overlay.ZIndex = 100
        overlay.Parent = lp.PlayerGui:FindFirstChild("TOHSuite") or screenGui

        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(0.6,0,0.6,0)
        img.Position = UDim2.new(0.2,0,0.2,0)
        img.Image = "rbxassetid://128595216960250"
        img.BackgroundTransparency = 1
        img.ZIndex = 101
        img.Parent = overlay

        playSound(96443758876586, 1)

        task.delay(3, function()
            overlay:Destroy()
        end)

        task.delay(1.5, function()
            -- Simulate crash visual
            local blackout = Instance.new("Frame")
            blackout.Size = UDim2.new(1,0,1,0)
            blackout.BackgroundColor3 = Color3.new(0,0,0)
            blackout.ZIndex = 200
            blackout.Parent = screenGui
            task.delay(8, function() blackout:Destroy() end)
        end)
    end

    local function hookChar2(c)
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Died:Connect(function()
                if jumpscareActive then doJumpscare() end
            end)
        end
    end
    hookChar2(lp.Character or lp.CharacterAdded:Wait())
    lp.CharacterAdded:Connect(hookChar2)
end, Color3.fromRGB(120,20,20))

-- ============================================================
-- FLOOD ESCAPE MODE
-- ============================================================
local floodSpeedInput = nil
local _, floodSpeedBox = makeInput("Flood Rise Speed (studs/s, default 1)", 43, "1", function(val)
    State.floodSpeed = tonumber(val) or 1
end)
State.floodSpeed = 1

makeButton("▶ Start Flood Escape", 44, function()
    if State.floodMode then
        -- Stop flood
        State.floodMode = false
        if floodConn then floodConn:Disconnect() floodConn = nil end
        if floodPart then floodPart:Destroy() floodPart = nil end
        if floodTheme then floodTheme:Stop() floodTheme:Destroy() floodTheme = nil end
        notify("Flood stopped.")
        return
    end

    State.floodMode = true
    notify("Flood starts in 10 seconds!")

    local speed = State.floodSpeed or 1

    floodTheme = safeSound(71991763100641, workspace)
    floodTheme.Looped = true
    floodTheme.Volume = 0.7
    floodTheme:Play()

    task.delay(10, function()
        if not State.floodMode then return end

        char = lp.Character
        if not char then return end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        floodPart = Instance.new("Part")
        floodPart.Size = Vector3.new(500, 10, 500)
        floodPart.Position = Vector3.new(hrp.Position.X, hrp.Position.Y - 10, hrp.Position.Z)
        floodPart.Anchored = true
        floodPart.CanCollide = false
        floodPart.Material = Enum.Material.Neon
        floodPart.Color = Color3.fromRGB(0, 100, 200)
        floodPart.Transparency = 0.4
        floodPart.Name = "FloodKillPart"
        floodPart.Parent = workspace

        local damage = 0
        local lastDmg = tick()

        floodConn = RunService.Heartbeat:Connect(function(dt)
            if not State.floodMode or not floodPart then return end
            char = lp.Character
            if not char then return end
            hrp = char:FindFirstChild("HumanoidRootPart")
            local hum2 = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum2 then return end

            local currentSpeed = speed
            local dist = hrp.Position.Y - floodPart.Position.Y

            if dist < 90 and dist > 30 then
                currentSpeed = speed * 2
            elseif dist <= 30 then
                currentSpeed = speed
            end

            floodPart.Position = floodPart.Position + Vector3.new(0, currentSpeed * dt, 0)

            -- Damage if flood reaches head
            local headPos = hrp.Position + Vector3.new(0, 2, 0)
            if floodPart.Position.Y >= headPos.Y then
                if tick() - lastDmg >= 2 then
                    lastDmg = tick()
                    hum2:TakeDamage(40)
                end
            end

            -- Check finish
            for _, part in ipairs(getFinishes()) do
                if (hrp.Position - part.Position).Magnitude < 10 then
                    notify("You escaped the flood!")
                    playSound(9126104501, 1)
                    -- Descend flood
                    State.floodMode = false
                    if floodTheme then floodTheme:Stop() end
                    if floodConn then floodConn:Disconnect() floodConn = nil end
                    local descConn
                    descConn = RunService.Heartbeat:Connect(function(dt2)
                        if not floodPart then descConn:Disconnect() return end
                        floodPart.Position = floodPart.Position - Vector3.new(0, 8 * dt2, 0)
                        if floodPart.Position.Y < hrp.Position.Y - 200 then
                            floodPart:Destroy() floodPart = nil
                            descConn:Disconnect()
                        end
                    end)
                    break
                end
            end

            -- If player dies, stop
            if hum2.Health <= 0 then
                State.floodMode = false
                if floodConn then floodConn:Disconnect() floodConn = nil end
                if floodPart then floodPart:Destroy() floodPart = nil end
                if floodTheme then floodTheme:Stop() end
                notify("You died! Press Start Flood to retry.")
            end
        end)
    end)
end, Color3.fromRGB(0, 80, 160))

-- ============================================================
-- OH NO MR EVIL!
-- ============================================================
makeButton("👁 OH NO MR EVIL!", 50, function()
    if mrEvil then
        mrEvil:Destroy()
        mrEvil = nil
        if mrEvilTheme then mrEvilTheme:Stop() mrEvilTheme:Destroy() mrEvilTheme = nil end
        if mrEvilConn then mrEvilConn:Disconnect() mrEvilConn = nil end
        notify("Mr Evil gone.")
        return
    end

    notify("Mr Evil will appear in 10 seconds...")

    task.delay(10, function()
        char = lp.Character
        if not char then return end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Build Mr Evil rig
        local evil = Instance.new("Model")
        evil.Name = "MrEvil"
        evil.Parent = workspace
        mrEvil = evil

        local body = Instance.new("Part")
        body.Size = Vector3.new(2, 3.5, 0.5)
        body.Transparency = 1
        body.CanCollide = false
        body.Anchored = true
        body.Position = hrp.Position + Vector3.new(20, 0, 0)
        body.Name = "HumanoidRootPart"
        body.Parent = evil
        evil.PrimaryPart = body

        -- Face billboard
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 200, 0, 200)
        billboard.StudsOffset = Vector3.new(0, 0, 0)
        billboard.AlwaysOnTop = false
        billboard.Parent = body

        local faceImg = Instance.new("ImageLabel")
        faceImg.Size = UDim2.new(1,0,1,0)
        faceImg.Image = "rbxassetid://128595216960250"
        faceImg.BackgroundTransparency = 1
        faceImg.Parent = billboard

        -- Black particles
        local attachment = Instance.new("Attachment", body)
        local particles = Instance.new("ParticleEmitter", attachment)
        particles.Color = ColorSequence.new(Color3.new(0,0,0), Color3.new(0.1,0,0.1))
        particles.LightEmission = 0.2
        particles.Rate = 60
        particles.Rotation = NumberRange.new(0, 360)
        particles.Speed = NumberRange.new(2, 5)
        particles.SpreadAngle = Vector2.new(180, 180)
        particles.Lifetime = NumberRange.new(0.5, 1.5)
        particles.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0),
        })

        -- Theme music
        mrEvilTheme = safeSound(70601819363531, workspace)
        mrEvilTheme.Looped = true
        mrEvilTheme.Volume = 0.6
        mrEvilTheme:Play()

        local teleportChance = 12
        local lastTeleport = tick()
        local burstMode = false
        local burstCount = 0

        local function teleportEvil(studs)
            if not mrEvil or not mrEvil.Parent then return end
            char = lp.Character
            if not char then return end
            hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            playSound(133537522827881, 0.7, workspace)
            local dir = (hrp.Position - body.Position).Unit
            local dist = (hrp.Position - body.Position).Magnitude
            local moveDist = math.min(studs, dist)
            body.Position = body.Position + dir * moveDist

            -- Catch check
            if (body.Position - hrp.Position).Magnitude < 4 then
                -- Caught!
                playSound(96443758876586, 1)
                local blackScreen = Instance.new("Frame")
                blackScreen.Size = UDim2.new(1,0,1,0)
                blackScreen.BackgroundColor3 = Color3.new(0,0,0)
                blackScreen.ZIndex = 200
                blackScreen.Parent = screenGui
                if mrEvilTheme then mrEvilTheme:Stop() end
                task.delay(10, function()
                    blackScreen:Destroy()
                    if mrEvil then mrEvil:Destroy() mrEvil = nil end
                    if mrEvilConn then mrEvilConn:Disconnect() mrEvilConn = nil end
                end)
                return true
            end
            return false
        end

        mrEvilConn = RunService.Heartbeat:Connect(function()
            if not mrEvil or not mrEvil.Parent then return end
            char = lp.Character
            if not char then return end
            hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local now = tick()
            local dist = (hrp.Position - body.Position).Magnitude
            local interval = 1.5
            local useShort = (math.random(100) <= 30)
            if useShort then interval = 2 end

            local studsRange = (dist <= 15)
                and { min = 3, max = 5 }
                or  { min = 4, max = 8 }

            if burstMode then return end

            if now - lastTeleport >= interval then
                lastTeleport = now
                local studs = math.random(studsRange.min, studsRange.max)
                teleportEvil(studs)

                teleportChance = teleportChance + 4
                if math.random(100) <= teleportChance then
                    teleportChance = 12
                    burstMode = true
                    burstCount = 0
                    playSound(98203059769693, 0.8, workspace)
                    notify("MR EVIL IS CHARGING!")

                    local function doBurst()
                        if burstCount >= 4 then
                            burstMode = false
                            lastTeleport = tick()
                            return
                        end
                        burstCount += 1
                        teleportEvil(math.random(4, 8))
                        task.delay(5/4, doBurst)
                    end
                    task.delay(0.5, doBurst)
                end
            end

            -- Check if player finished
            for _, part in ipairs(getFinishes()) do
                if (hrp.Position - part.Position).Magnitude < 10 then
                    -- Mr Evil defeated!
                    if mrEvilTheme then mrEvilTheme:Stop() end
                    playSound(130220195052699, 0.8, workspace)
                    task.delay(2, function() playSound(133007160723578, 1, workspace) end)

                    local tw = TweenService:Create(faceImg, TweenInfo.new(3), {ImageTransparency = 1})
                    tw:Play()
                    TweenService:Create(particles, TweenInfo.new(3), {Rate = 0}):Play()
                    if mrEvilConn then mrEvilConn:Disconnect() mrEvilConn = nil end
                    task.delay(3, function()
                        if mrEvil then mrEvil:Destroy() mrEvil = nil end
                    end)
                    break
                end
            end
        end)
    end)
end, Color3.fromRGB(80, 0, 0))

-- ============================================================
-- RED LIGHT GREEN LIGHT
-- ============================================================
makeButton("🚦 Red Light Green Light", 51, function()
    if State.redLightMode then
        State.redLightMode = false
        if redLightConn then redLightConn:Disconnect() redLightConn = nil end
        notify("Red Light Green Light stopped.")
        return
    end

    State.redLightMode = true
    notify("Red Light Green Light started! Don't move on RED!")

    local overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "RLGLOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    overlayGui.Parent = lp.PlayerGui

    local colorFlash = Instance.new("Frame")
    colorFlash.Size = UDim2.new(1,0,1,0)
    colorFlash.BackgroundTransparency = 0.6
    colorFlash.BackgroundColor3 = Color3.new(0,1,0)
    colorFlash.ZIndex = 50
    colorFlash.Visible = false
    colorFlash.Parent = overlayGui

    local flashLabel = Instance.new("TextLabel")
    flashLabel.Size = UDim2.new(1,0,0.2,0)
    flashLabel.Position = UDim2.new(0,0,0.4,0)
    flashLabel.BackgroundTransparency = 1
    flashLabel.Text = "GREEN LIGHT"
    flashLabel.TextColor3 = Color3.new(1,1,1)
    flashLabel.Font = Enum.Font.GothamBold
    flashLabel.TextSize = 60
    flashLabel.ZIndex = 51
    flashLabel.Parent = overlayGui

    local isRed = false
    local lastPos = nil
    local phaseEnd = tick() + math.random(3, 6)

    redLightConn = RunService.Heartbeat:Connect(function()
        if not State.redLightMode then
            overlayGui:Destroy()
            return
        end

        char = lp.Character
        if not char then return end
        hrp = char:FindFirstChild("HumanoidRootPart")
        local hum2 = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum2 then return end

        -- Check finish
        for _, part in ipairs(getFinishes()) do
            if (hrp.Position - part.Position).Magnitude < 10 then
                State.redLightMode = false
                overlayGui:Destroy()
                if redLightConn then redLightConn:Disconnect() redLightConn = nil end
                notify("You finished! Red Light Green Light ends.")
                return
            end
        end

        local now = tick()
        if now >= phaseEnd then
            isRed = not isRed
            phaseEnd = now + math.random(2, 5)
            lastPos = hrp.Position

            colorFlash.Visible = true
            if isRed then
                colorFlash.BackgroundColor3 = Color3.new(1,0,0)
                flashLabel.Text = "RED LIGHT!"
                flashLabel.TextColor3 = Color3.new(1,1,0)
                playSound(112538636639786, 1)
                task.delay(0.5, function() colorFlash.Visible = false end)
            else
                colorFlash.BackgroundColor3 = Color3.new(0,1,0)
                flashLabel.Text = "GREEN LIGHT"
                flashLabel.TextColor3 = Color3.new(1,1,1)
                playSound(96443758876586, 0.5)
                task.delay(0.5, function() colorFlash.Visible = false end)
            end
        end

        if isRed and lastPos then
            local moved = (hrp.Position - lastPos).Magnitude
            if moved > 1.5 then
                notify("CAUGHT MOVING! You die!")
                hum2:TakeDamage(hum2.MaxHealth)
                lastPos = hrp.Position
            end
        end
    end)
end, Color3.fromRGB(160, 20, 20))

-- ============================================================
-- ANNOYING / DISTRACTION MODE
-- ============================================================
makeButton("😈 Annoying / Distraction Mode", 52, function()
    State.annoyingMode = not State.annoyingMode
    notify(State.annoyingMode and "Annoying Mode ON!" or "Annoying Mode OFF")

    if not State.annoyingMode then
        if annoyConn then annoyConn:Disconnect() annoyConn = nil end
        return
    end

    local popupChance = 30
    local lastPopupCheck = tick()
    local popupActive = false

    local function spawnPopup()
        if popupActive then return end
        popupActive = true
        playSound(130988530651697, 0.8)

        local popupGui = Instance.new("ScreenGui")
        popupGui.Name = "AnnoyPopup"
        popupGui.ResetOnSpawn = false
        popupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        popupGui.Parent = lp.PlayerGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 260, 0, 180)
        frame.Position = UDim2.new(
            math.random(10,70)/100, 0,
            math.random(10,60)/100, 0
        )
        frame.BackgroundColor3 = Color3.fromRGB(192, 192, 192)
        frame.BorderSizePixel = 2
        frame.ZIndex = 80
        frame.Parent = popupGui
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0,4)

        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(1,0,1,0)
        img.Image = "rbxassetid://4519042263"
        img.BackgroundTransparency = 1
        img.ZIndex = 81
        img.Parent = frame

        local closeBtn2 = Instance.new("TextButton")
        closeBtn2.Size = UDim2.new(0,20,0,20)
        closeBtn2.Position = UDim2.new(1,-22,0,2)
        closeBtn2.BackgroundColor3 = Color3.fromRGB(200,50,50)
        closeBtn2.Text = "X"
        closeBtn2.TextColor3 = Color3.new(1,1,1)
        closeBtn2.Font = Enum.Font.GothamBold
        closeBtn2.TextSize = 11
        closeBtn2.ZIndex = 82
        closeBtn2.BorderSizePixel = 0
        closeBtn2.Parent = frame
        Instance.new("UICorner", closeBtn2).CornerRadius = UDim.new(0,3)

        closeBtn2.MouseButton1Click:Connect(function()
            popupGui:Destroy()
            popupActive = false
        end)
    end

    annoyConn = RunService.Heartbeat:Connect(function()
        if not State.annoyingMode then return end
        char = lp.Character
        if not char then return end

        local now = tick()
        if now - lastPopupCheck >= 10 then
            lastPopupCheck = now
            if math.random(100) <= popupChance and not popupActive then
                spawnPopup()
                popupChance = popupChance + 4
                -- Burst popup chance
                if math.random(100) <= 10 then
                    popupChance = popupChance + 4
                    for i = 1, 5 do
                        task.delay(i * 0.7, function()
                            if State.annoyingMode then spawnPopup() end
                        end)
                    end
                end
            end
        end
    end)

    -- Random character movements
    task.spawn(function()
        while State.annoyingMode do
            task.wait(math.random(8, 20))
            if not State.annoyingMode then break end
            char = lp.Character
            if not char then continue end
            local hum2 = char:FindFirstChildOfClass("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
            if not hum2 or not hrp then continue end

            local event = math.random(3)
            if event == 1 then
                -- Random jump
                hum2.Jump = true
            elseif event == 2 then
                -- Look around
                local angles = {0, 45, 90, 180, 270, 315}
                local a = angles[math.random(#angles)]
                cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.Angles(0, math.rad(a), 0)
            elseif event == 3 then
                -- /e laugh on death is handled below
            end
        end
    end)

    -- /e laugh on death
    local function hookAnnoyChar(c)
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        if hum2 then
            hum2.Died:Connect(function()
                if State.annoyingMode then
                    task.wait(0.5)
                    local args = { [1] = "laugh" }
                    game:GetService("Players").LocalPlayer:GetMouse()
                    pcall(function()
                        game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("SayMessageRequest"):FireServer("/e laugh", "All")
                    end)
                end
            end)
        end
    end
    hookAnnoyChar(lp.Character or lp.CharacterAdded:Wait())
    lp.CharacterAdded:Connect(hookAnnoyChar)
end, Color3.fromRGB(160, 100, 10))

-- ============================================================
-- CHARACTER RESPAWN HOOK
-- ============================================================
lp.CharacterAdded:Connect(function(newChar)
    char = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    hrp = newChar:WaitForChild("HumanoidRootPart")

    -- Reapply invisible players
    if State.invisPlayers then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character then
                local isWhitelisted = false
                for _, n in ipairs(State.invisWhitelist) do
                    if plr.Name == n then isWhitelisted = true break end
                end
                if not isWhitelisted then
                    for _, part in ipairs(plr.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.LocalTransparencyModifier = 1
                        end
                    end
                end
            end
        end
    end
end)

notify("TOH Suite loaded! " .. #Players:GetPlayers() .. " player(s) in server.", 5)
