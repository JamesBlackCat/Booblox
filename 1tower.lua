--[[
    TOWER OF HELL - FULL FEATURE SUITE v2
    LocalScript — Run via Executor
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local SoundService     = game:GetService("SoundService")
local StarterGui       = game:GetService("StarterGui")
local Debris           = game:GetService("Debris")

local lp  = Players.LocalPlayer
local cam = workspace.CurrentCamera
local char, humanoid, hrp

local function refreshChar()
    char     = lp.Character
    humanoid = char and char:FindFirstChildOfClass("Humanoid")
    hrp      = char and char:FindFirstChild("HumanoidRootPart")
end
refreshChar()
lp.CharacterAdded:Connect(function(c)
    char     = c
    humanoid = c:WaitForChild("Humanoid")
    hrp      = c:WaitForChild("HumanoidRootPart")
end)

-- ============================================================
-- STATE
-- ============================================================
local State = {
    jumpTraj      = false,
    removeWalls   = false,
    cameraPhase   = false,
    invisPlayers  = false,
    invisWhitelist= {},
    killColor     = false,
    killColorPick = Color3.fromRGB(255,50,50),
    killTexture   = false,
    killMatPick   = Enum.Material.Neon,
    fogMode       = false,
    lapsMode      = false, lapCount = 0,
    raceTarget    = nil,
    streakMode    = false, streakCount = 0,
    epilepsyMode  = false,
    floodMode     = false, floodSpeed = 1,
    mrEvilMode    = false,
    redLightMode  = false,
    annoyingMode  = false,
}

local removedWalls    = {}
local phasedParts     = {}
local trajParts       = {}
local floodPart       = nil
local mrEvil          = nil
local mrEvilTheme     = nil
local mrEvilCatchSound= nil
local floodTheme      = nil
local floodBlur       = nil
local floodCC         = nil
local epilepsyConn    = nil
local redLightConn    = nil
local annoyConn       = nil
local floodConn       = nil
local mrEvilConn      = nil
local lapConn         = nil
local raceConn        = nil
local originalFog     = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor }
local originalTextures= {}
local originalColors  = {}

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
    Debris:AddItem(s, 20)
    return s
end

local function notify(msg, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = "TOH Suite",
            Text     = msg,
            Duration = duration or 3,
        })
    end)
end

local function getTower()   return workspace:FindFirstChild("tower") end

local function getFinishes()
    local tower = getTower()
    if not tower then return {} end
    local fin = tower:FindFirstChild("finishes")
    if not fin then return {} end
    local parts = {}
    for _, v in ipairs(fin:GetDescendants()) do
        if v:IsA("BasePart") then table.insert(parts, v) end
    end
    return parts
end

local function getKillParts()
    local tower = getTower()
    if not tower then return {} end
    local parts = {}
    for _, d in ipairs(tower:GetDescendants()) do
        if d:IsA("BasePart") then
            local ti = d:FindFirstChildOfClass("TouchTransmitter") or d:FindFirstChild("TouchInterest")
            if ti then table.insert(parts, d) end
        end
    end
    return parts
end

-- Cleanup everything and restore
local function cleanupAll()
    -- Walls
    for _, data in ipairs(removedWalls) do
        pcall(function() data.part.Transparency = data.trans; data.part.CanCollide = true end)
    end
    removedWalls = {}

    -- Phased parts
    for part, _ in pairs(phasedParts) do
        pcall(function() part.LocalTransparencyModifier = 0 end)
    end
    phasedParts = {}

    -- Kill parts
    for _, p in ipairs(getKillParts()) do
        if originalColors[p] then pcall(function() p.Color = originalColors[p] end) end
        if originalTextures[p] then pcall(function() p.Material = originalTextures[p] end) end
        local m = p:FindFirstChildOfClass("SpecialMesh")
        if m then m:Destroy() end
    end
    originalColors = {}; originalTextures = {}

    -- Fog
    Lighting.FogStart = originalFog.FogStart
    Lighting.FogEnd   = originalFog.FogEnd
    Lighting.FogColor = originalFog.FogColor

    -- Lighting
    pcall(function() Lighting.Brightness = 1; Lighting.ColorShift_Top = Color3.new(0,0,0) end)

    -- Flood
    if floodConn   then floodConn:Disconnect()   floodConn = nil end
    if floodTheme  then floodTheme:Stop();  floodTheme:Destroy();  floodTheme = nil end
    if floodPart   then floodPart:Destroy();   floodPart = nil end
    if floodBlur   then floodBlur:Destroy();   floodBlur = nil end
    if floodCC     then floodCC:Destroy();     floodCC   = nil end

    -- Mr Evil
    if mrEvilConn  then mrEvilConn:Disconnect()  mrEvilConn = nil end
    if mrEvilTheme then mrEvilTheme:Stop(); mrEvilTheme:Destroy(); mrEvilTheme = nil end
    if mrEvilCatchSound then mrEvilCatchSound:Stop(); mrEvilCatchSound:Destroy(); mrEvilCatchSound = nil end
    if mrEvil      then mrEvil:Destroy();      mrEvil = nil end

    -- Red light
    if redLightConn then redLightConn:Disconnect() redLightConn = nil end

    -- Annoy
    if annoyConn   then annoyConn:Disconnect()   annoyConn = nil end

    -- Epilepsy
    if epilepsyConn then epilepsyConn:Disconnect() epilepsyConn = nil end

    -- Lap / race
    if lapConn     then lapConn:Disconnect()     lapConn = nil end
    if raceConn    then raceConn:Disconnect()     raceConn = nil end

    -- Players visible again
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            for _, p in ipairs(plr.Character:GetDescendants()) do
                pcall(function()
                    if p:IsA("BasePart") or p:IsA("Decal") then
                        p.LocalTransparencyModifier = 0
                    end
                    if p:IsA("BillboardGui") then p.Enabled = true end
                end)
            end
        end
    end

    -- Destroy any leftover overlay GUIs
    local pg = lp:FindFirstChild("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetChildren()) do
            if g.Name == "RLGLOverlay" or g.Name == "AnnoyPopup" or g.Name == "EpiGUI" then
                g:Destroy()
            end
        end
    end

    notify("TOH Suite closed. Everything restored.", 4)
end

-- ============================================================
-- MAIN GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name              = "TOHSuite"
screenGui.ResetOnSpawn      = false
screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset    = true
screenGui.Parent            = lp.PlayerGui

-- Mobile toggle button (always visible)
local mobileToggle = Instance.new("TextButton")
mobileToggle.Size             = UDim2.new(0, 52, 0, 52)
mobileToggle.Position         = UDim2.new(0, 8, 0.5, -26)
mobileToggle.BackgroundColor3 = Color3.fromRGB(110, 40, 200)
mobileToggle.Text             = "☰"
mobileToggle.TextColor3       = Color3.new(1,1,1)
mobileToggle.Font             = Enum.Font.GothamBold
mobileToggle.TextSize         = 22
mobileToggle.BorderSizePixel  = 0
mobileToggle.ZIndex           = 200
mobileToggle.Parent           = screenGui
Instance.new("UICorner", mobileToggle).CornerRadius = UDim.new(0, 10)

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Size            = UDim2.new(0, 400, 0, 560)
mainFrame.Position        = UDim2.new(0, 70, 0.5, -280)
mainFrame.BackgroundColor3= Color3.fromRGB(14, 14, 20)
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex          = 100
mainFrame.Parent          = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

-- Drop shadow
local shadow = Instance.new("Frame")
shadow.Size              = UDim2.new(1, 16, 1, 16)
shadow.Position          = UDim2.new(0, -8, 0, -8)
shadow.BackgroundColor3  = Color3.new(0,0,0)
shadow.BackgroundTransparency = 0.6
shadow.BorderSizePixel   = 0
shadow.ZIndex            = 99
shadow.Parent            = mainFrame
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 16)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(100, 30, 190)
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 101
titleBar.Parent           = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local titleFix = Instance.new("Frame")
titleFix.Size             = UDim2.new(1, 0, 0.5, 0)
titleFix.Position         = UDim2.new(0, 0, 0.5, 0)
titleFix.BackgroundColor3 = Color3.fromRGB(100, 30, 190)
titleFix.BorderSizePixel  = 0
titleFix.ZIndex           = 101
titleFix.Parent           = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size              = UDim2.new(1, -90, 1, 0)
titleLabel.Position          = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text              = "TOH Suite"
titleLabel.TextColor3        = Color3.new(1,1,1)
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 16
titleLabel.TextXAlignment    = Enum.TextXAlignment.Left
titleLabel.ZIndex            = 102
titleLabel.Parent            = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size             = UDim2.new(0, 30, 0, 30)
minimizeBtn.Position         = UDim2.new(1, -68, 0.5, -15)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
minimizeBtn.Text             = "—"
minimizeBtn.TextColor3       = Color3.new(1,1,1)
minimizeBtn.Font             = Enum.Font.GothamBold
minimizeBtn.TextSize         = 15
minimizeBtn.BorderSizePixel  = 0
minimizeBtn.ZIndex           = 102
minimizeBtn.Parent           = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0,6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 30, 0, 30)
closeBtn.Position         = UDim2.new(1, -34, 0.5, -15)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,40,40)
closeBtn.Text             = "X"
closeBtn.TextColor3       = Color3.new(1,1,1)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 15
closeBtn.BorderSizePixel  = 0
closeBtn.ZIndex           = 102
closeBtn.Parent           = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

-- Content
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Size                = UDim2.new(1, -8, 1, -48)
contentFrame.Position            = UDim2.new(0, 4, 0, 44)
contentFrame.BackgroundTransparency = 1
contentFrame.ScrollBarThickness  = 4
contentFrame.ScrollBarImageColor3= Color3.fromRGB(110,40,200)
contentFrame.CanvasSize          = UDim2.new(0,0,0,0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.ZIndex              = 101
contentFrame.Parent              = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0, 4)
listLayout.Parent    = contentFrame

local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop   = UDim.new(0, 4)
uiPadding.PaddingLeft  = UDim.new(0, 2)
uiPadding.PaddingRight = UDim.new(0, 2)
uiPadding.PaddingBottom= UDim.new(0, 6)
uiPadding.Parent       = contentFrame

-- Toggle visibility
local guiVisible = true
local minimized  = false

mobileToggle.MouseButton1Click:Connect(function()
    guiVisible = not guiVisible
    mainFrame.Visible = guiVisible
end)

minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    contentFrame.Visible = not minimized
    mainFrame.Size = minimized and UDim2.new(0,400,0,44) or UDim2.new(0,400,0,560)
end)

closeBtn.MouseButton1Click:Connect(function()
    cleanupAll()
    screenGui:Destroy()
end)

-- Drag (works for both mouse and touch)
local dragging, dragStart, startPos = false, nil, nil
local function beginDrag(pos)
    dragging = true
    dragStart = pos
    startPos  = mainFrame.Position
end
local function updateDrag(pos)
    if not dragging then return end
    local delta = pos - dragStart
    mainFrame.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end
local function endDrag() dragging = false end

titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        beginDrag(inp.Position)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
        updateDrag(inp.Position)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        endDrag()
    end
end)

-- Also make the mobile toggle draggable
local mobDrag, mobStart, mobBtnStart = false, nil, nil
mobileToggle.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        mobDrag = true; mobStart = inp.Position
        mobBtnStart = mobileToggle.Position
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not mobDrag then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
        local delta = inp.Position - mobStart
        mobileToggle.Position = UDim2.new(
            mobBtnStart.X.Scale, mobBtnStart.X.Offset + delta.X,
            mobBtnStart.Y.Scale, mobBtnStart.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        mobDrag = false
    end
end)

-- ============================================================
-- GUI HELPERS
-- ============================================================
local function sectionLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1,-4,0,22)
    lbl.BackgroundTransparency = 1
    lbl.Text               = text
    lbl.TextColor3         = Color3.fromRGB(160,90,255)
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 12
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.LayoutOrder        = order or 0
    lbl.ZIndex             = 101
    lbl.Parent             = contentFrame
    return lbl
end

local function makeToggle(label, order, onToggle)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,-4,0,36)
    row.BackgroundColor3 = Color3.fromRGB(24,24,34)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order or 0
    row.ZIndex           = 101
    row.Parent           = contentFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1,-64,1,0)
    lbl.Position           = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = label
    lbl.TextColor3         = Color3.fromRGB(220,220,230)
    lbl.Font               = Enum.Font.Gotham
    lbl.TextSize           = 13
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 102
    lbl.Parent             = row

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0,50,0,24)
    btn.Position         = UDim2.new(1,-58,0.5,-12)
    btn.BackgroundColor3 = Color3.fromRGB(55,55,72)
    btn.Text             = "OFF"
    btn.TextColor3       = Color3.new(1,1,1)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 11
    btn.BorderSizePixel  = 0
    btn.ZIndex           = 102
    btn.Parent           = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)

    local active = false
    btn.MouseButton1Click:Connect(function()
        active = not active
        btn.Text             = active and "ON" or "OFF"
        btn.BackgroundColor3 = active and Color3.fromRGB(110,40,200) or Color3.fromRGB(55,55,72)
        onToggle(active)
    end)
    return row, btn
end

local function makeButton(label, order, onClick, color)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1,-4,0,36)
    btn.BackgroundColor3 = color or Color3.fromRGB(110,40,200)
    btn.Text             = label
    btn.TextColor3       = Color3.new(1,1,1)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 13
    btn.BorderSizePixel  = 0
    btn.LayoutOrder      = order or 0
    btn.ZIndex           = 101
    btn.Parent           = contentFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

local function makeSlider(label, order, minV, maxV, default, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,-4,0,54)
    row.BackgroundColor3 = Color3.fromRGB(24,24,34)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order or 0
    row.ZIndex           = 101
    row.Parent           = contentFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1,-10,0,22)
    lbl.Position           = UDim2.new(0,10,0,4)
    lbl.BackgroundTransparency = 1
    lbl.Text               = label .. ": " .. tostring(default)
    lbl.TextColor3         = Color3.fromRGB(220,220,230)
    lbl.Font               = Enum.Font.Gotham
    lbl.TextSize           = 12
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 102
    lbl.Parent             = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1,-20,0,8)
    track.Position         = UDim2.new(0,10,0,34)
    track.BackgroundColor3 = Color3.fromRGB(55,55,72)
    track.BorderSizePixel  = 0
    track.ZIndex           = 102
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(0,4)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new((default-minV)/(maxV-minV),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(110,40,200)
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 103
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,4)

    local knob = Instance.new("TextButton")
    knob.Size             = UDim2.new(0,16,0,16)
    knob.AnchorPoint      = Vector2.new(0.5,0.5)
    knob.Position         = UDim2.new((default-minV)/(maxV-minV),0,0.5,0)
    knob.BackgroundColor3 = Color3.fromRGB(180,90,255)
    knob.Text             = ""
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 104
    knob.Parent           = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local value = default
    local draggingSlider = false
    knob.MouseButton1Down:Connect(function() draggingSlider = true end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if draggingSlider and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local pos  = track.AbsolutePosition
            local size = track.AbsoluteSize
            local rel  = math.clamp((inp.Position.X - pos.X)/size.X, 0, 1)
            value = math.floor(minV + rel*(maxV-minV))
            fill.Size     = UDim2.new(rel,0,1,0)
            knob.Position = UDim2.new(rel,0,0.5,0)
            lbl.Text      = label .. ": " .. tostring(value)
            onChange(value)
        end
    end)
    return row
end

local function makeInput(label, order, placeholder, onSubmit)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,-4,0,62)
    row.BackgroundColor3 = Color3.fromRGB(24,24,34)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order or 0
    row.ZIndex           = 101
    row.Parent           = contentFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1,-10,0,22)
    lbl.Position           = UDim2.new(0,10,0,4)
    lbl.BackgroundTransparency = 1
    lbl.Text               = label
    lbl.TextColor3         = Color3.fromRGB(220,220,230)
    lbl.Font               = Enum.Font.Gotham
    lbl.TextSize           = 12
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 102
    lbl.Parent             = row

    local box = Instance.new("TextBox")
    box.Size             = UDim2.new(1,-20,0,26)
    box.Position         = UDim2.new(0,10,0,28)
    box.BackgroundColor3 = Color3.fromRGB(36,36,50)
    box.Text             = ""
    box.PlaceholderText  = placeholder or ""
    box.TextColor3       = Color3.new(1,1,1)
    box.PlaceholderColor3= Color3.fromRGB(110,110,130)
    box.Font             = Enum.Font.Gotham
    box.TextSize         = 12
    box.BorderSizePixel  = 0
    box.ClearTextOnFocus = true
    box.ZIndex           = 102
    box.Parent           = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)

    box.FocusLost:Connect(function(enter) if enter then onSubmit(box.Text) end end)
    return row, box
end

-- Full-screen overlay helper (oversized so nothing bleeds through)
local function makeOverlay(color, alpha)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(3, 0, 3, 0)
    f.Position         = UDim2.new(-1, 0, -1, 0)
    f.BackgroundColor3 = color or Color3.new(0,0,0)
    f.BackgroundTransparency = alpha or 0
    f.BorderSizePixel  = 0
    f.ZIndex           = 500
    f.Parent           = screenGui
    return f
end

-- ============================================================
-- SECTION: ASSIST TOOLS
-- ============================================================
sectionLabel("── ASSIST TOOLS ──", 1)

-- 1. Jump Trajectory
makeToggle("Jump Trajectory Visualizer", 2, function(on)
    State.jumpTraj = on
    if not on then
        for _, p in ipairs(trajParts) do pcall(function() p:Destroy() end) end
        trajParts = {}
    end
end)

RunService.Heartbeat:Connect(function()
    if not State.jumpTraj then return end
    local c = lp.Character
    if not c then return end
    local h = c:FindFirstChild("HumanoidRootPart")
    if not h then return end

    for _, p in ipairs(trajParts) do pcall(function() p:Destroy() end) end
    trajParts = {}

    local vel     = h.Velocity
    local gravity = Vector3.new(0, -workspace.Gravity, 0)
    local pos     = h.Position
    local step    = 0.06
    local steps   = 35

    for i = 1, steps do
        local t = i * step
        local fp = pos + vel * t + 0.5 * gravity * t * t
        local dot = Instance.new("Part")
        dot.Size        = Vector3.new(0.25, 0.25, 0.25)
        dot.Shape       = Enum.PartType.Ball
        dot.Position    = fp
        dot.Anchored    = true
        dot.CanCollide  = false
        dot.Material    = Enum.Material.Neon
        dot.Color       = Color3.fromHSV(i/steps * 0.33, 1, 1)
        dot.CastShadow  = false
        dot.Parent      = workspace
        Debris:AddItem(dot, step * steps + 0.1)
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
        for _, d in ipairs(sections:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = d.Name:lower()
                if n:find("wall") or n:find("side") or n:find("border") or n:find("fence") then
                    table.insert(removedWalls, {part=d, trans=d.Transparency, col=d.CanCollide})
                    d.Transparency = 1
                    d.CanCollide   = false
                end
            end
        end
        notify("Walls hidden (" .. #removedWalls .. " parts)")
    else
        for _, data in ipairs(removedWalls) do
            pcall(function() data.part.Transparency = data.trans; data.part.CanCollide = data.col end)
        end
        removedWalls = {}
        notify("Walls restored")
    end
end)

-- 3. Camera Phase-Through
makeToggle("Camera Phase-Through", 4, function(on)
    State.cameraPhase = on
    if not on then
        for part, _ in pairs(phasedParts) do
            pcall(function() part.LocalTransparencyModifier = 0 end)
        end
        phasedParts = {}
    end
end)

RunService.RenderStepped:Connect(function()
    if not State.cameraPhase then return end
    local c = lp.Character
    if not c then return end
    local h = c:FindFirstChild("HumanoidRootPart")
    if not h then return end

    local origin = cam.CFrame.Position
    local target = h.Position
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {c}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ray = workspace:Raycast(origin, (target - origin).Unit * (target - origin).Magnitude, params)

    for part, _ in pairs(phasedParts) do
        pcall(function() part.LocalTransparencyModifier = 0 end)
    end
    phasedParts = {}

    if ray and ray.Instance and ray.Instance:IsA("BasePart") then
        local part = ray.Instance
        phasedParts[part] = 0
        part.LocalTransparencyModifier = 0.88
    end
end)

-- 4. Remove UI Elements
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

makeToggle("  Hide Height Meter", 8, function(on)
    local t = pg:FindFirstChild("heightMeter")
    if t then t.Enabled = not on end
end)

-- 5. Invisible Players
makeToggle("Invisible Other Players", 9, function(on)
    State.invisPlayers = on
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            for _, p in ipairs(plr.Character:GetDescendants()) do
                pcall(function()
                    if p:IsA("BasePart") or p:IsA("Decal") then
                        p.LocalTransparencyModifier = on and 1 or 0
                    end
                    -- Hide overhead nametag BillboardGui
                    if p:IsA("BillboardGui") then
                        p.Enabled = not on
                    end
                end)
            end
        end
    end
end)

makeInput("Whitelist Player Name", 10, "Player name, then Enter...", function(name)
    if name == "" then return end
    table.insert(State.invisWhitelist, name)
    notify("Whitelisted: " .. name)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name == name and plr.Character then
            for _, p in ipairs(plr.Character:GetDescendants()) do
                pcall(function()
                    if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end
                    if p:IsA("BillboardGui") then p.Enabled = true end
                end)
            end
        end
    end
end)

-- 6. Render Distance
makeSlider("Render Distance %", 11, 1, 100, 100, function(val)
    State.renderDist = val
    pcall(function() workspace.StreamingTargetRadius = math.max(64, val * 5) end)
    pcall(function() settings().Rendering.QualityLevel = math.ceil(val / 10) end)
end)

-- ============================================================
-- KILL PART COLOR PICKER
-- ============================================================
sectionLabel("Kill Part Color Picker", 12)

local colorRow = Instance.new("Frame")
colorRow.Size             = UDim2.new(1,-4,0,44)
colorRow.BackgroundColor3 = Color3.fromRGB(24,24,34)
colorRow.BorderSizePixel  = 0
colorRow.LayoutOrder      = 13
colorRow.ZIndex           = 101
colorRow.Parent           = contentFrame
Instance.new("UICorner", colorRow).CornerRadius = UDim.new(0,8)

local colorListLayout = Instance.new("UIListLayout")
colorListLayout.FillDirection  = Enum.FillDirection.Horizontal
colorListLayout.Padding        = UDim.new(0,4)
colorListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
colorListLayout.Parent         = colorRow
Instance.new("UIPadding", colorRow).PaddingLeft = UDim.new(0,6)

local colorChoices = {
    {Color3.fromRGB(255,50,50),   "Red"},
    {Color3.fromRGB(255,165,0),   "Org"},
    {Color3.fromRGB(255,230,0),   "Yel"},
    {Color3.fromRGB(50,220,50),   "Grn"},
    {Color3.fromRGB(50,150,255),  "Blu"},
    {Color3.fromRGB(180,50,255),  "Pur"},
    {Color3.fromRGB(255,80,200),  "Pnk"},
    {Color3.fromRGB(255,255,255), "Wht"},
    {Color3.fromRGB(0,0,0),       "Blk"},
    {Color3.fromRGB(0,255,200),   "Cyn"},
}

local selectedColorBtn = nil
for _, pair in ipairs(colorChoices) do
    local col, label = pair[1], pair[2]
    local cb = Instance.new("TextButton")
    cb.Size             = UDim2.new(0,32,0,32)
    cb.BackgroundColor3 = col
    cb.Text             = ""
    cb.BorderSizePixel  = 2
    cb.BorderColor3     = Color3.new(1,1,1)
    cb.ZIndex           = 102
    cb.Parent           = colorRow
    Instance.new("UICorner", cb).CornerRadius = UDim.new(0,6)

    local tip = Instance.new("TextLabel")
    tip.Size               = UDim2.new(1,0,0,10)
    tip.Position           = UDim2.new(0,0,1,1)
    tip.BackgroundTransparency = 1
    tip.Text               = label
    tip.TextColor3         = Color3.new(1,1,1)
    tip.Font               = Enum.Font.Gotham
    tip.TextSize           = 8
    tip.ZIndex             = 102
    tip.Parent             = cb

    cb.MouseButton1Click:Connect(function()
        State.killColorPick = col
        if selectedColorBtn then selectedColorBtn.BorderColor3 = Color3.fromRGB(100,100,100) end
        cb.BorderColor3 = Color3.new(1,1,1)
        selectedColorBtn = cb
        notify("Kill part color: " .. label)
        -- Apply immediately if toggle is on
        if State.killColor then
            for _, p in ipairs(getKillParts()) do
                pcall(function() p.Color = col end)
            end
        end
    end)
end

makeToggle("Apply Kill Part Color", 14, function(on)
    State.killColor = on
    local parts = getKillParts()
    if on then
        for _, p in ipairs(parts) do
            originalColors[p] = p.Color
            p.Color = State.killColorPick
        end
    else
        for _, p in ipairs(parts) do
            if originalColors[p] then pcall(function() p.Color = originalColors[p] end) end
        end
        originalColors = {}
    end
end)

-- ============================================================
-- KILL PART TEXTURE / MATERIAL PICKER
-- ============================================================
sectionLabel("Kill Part Material Picker", 15)

local matRow = Instance.new("Frame")
matRow.Size             = UDim2.new(1,-4,0,44)
matRow.BackgroundColor3 = Color3.fromRGB(24,24,34)
matRow.BorderSizePixel  = 0
matRow.LayoutOrder      = 16
matRow.ZIndex           = 101
matRow.Parent           = contentFrame
Instance.new("UICorner", matRow).CornerRadius = UDim.new(0,8)

local matListLayout = Instance.new("UIListLayout")
matListLayout.FillDirection    = Enum.FillDirection.Horizontal
matListLayout.Padding          = UDim.new(0,4)
matListLayout.VerticalAlignment= Enum.VerticalAlignment.Center
matListLayout.Parent           = matRow
Instance.new("UIPadding", matRow).PaddingLeft = UDim.new(0,6)

local materialChoices = {
    {Enum.Material.Neon,         "Neon",  Color3.fromRGB(255,200,255)},
    {Enum.Material.SmoothPlastic,"Smth",  Color3.fromRGB(180,180,180)},
    {Enum.Material.Metal,        "Metl",  Color3.fromRGB(140,140,160)},
    {Enum.Material.Glass,        "Glas",  Color3.fromRGB(140,200,230)},
    {Enum.Material.Ice,          "Ice",   Color3.fromRGB(180,220,255)},
    {Enum.Material.Wood,         "Wood",  Color3.fromRGB(160,100,60)},
    {Enum.Material.Grass,        "Gras",  Color3.fromRGB(80,160,60)},
    {Enum.Material.Granite,      "Gran",  Color3.fromRGB(120,110,100)},
    {Enum.Material.DiamondPlate, "Dmnd",  Color3.fromRGB(180,200,220)},
    {Enum.Material.Foil,         "Foil",  Color3.fromRGB(200,200,100)},
}

local selectedMatBtn = nil
for _, trio in ipairs(materialChoices) do
    local mat, lbl, col = trio[1], trio[2], trio[3]
    local mb = Instance.new("TextButton")
    mb.Size             = UDim2.new(0,32,0,32)
    mb.BackgroundColor3 = col
    mb.Text             = ""
    mb.BorderSizePixel  = 2
    mb.BorderColor3     = Color3.fromRGB(100,100,100)
    mb.ZIndex           = 102
    mb.Parent           = matRow
    Instance.new("UICorner", mb).CornerRadius = UDim.new(0,6)

    local tip2 = Instance.new("TextLabel")
    tip2.Size               = UDim2.new(1,0,0,10)
    tip2.Position           = UDim2.new(0,0,1,1)
    tip2.BackgroundTransparency = 1
    tip2.Text               = lbl
    tip2.TextColor3         = Color3.new(1,1,1)
    tip2.Font               = Enum.Font.Gotham
    tip2.TextSize           = 8
    tip2.ZIndex             = 102
    tip2.Parent             = mb

    mb.MouseButton1Click:Connect(function()
        State.killMatPick = mat
        if selectedMatBtn then selectedMatBtn.BorderColor3 = Color3.fromRGB(100,100,100) end
        mb.BorderColor3 = Color3.new(1,1,1)
        selectedMatBtn = mb
        notify("Kill part material: " .. lbl)
        if State.killTexture then
            for _, p in ipairs(getKillParts()) do
                pcall(function() p.Material = mat end)
            end
        end
    end)
end

makeToggle("Apply Kill Part Material", 17, function(on)
    State.killTexture = on
    local parts = getKillParts()
    if on then
        for _, p in ipairs(parts) do
            originalTextures[p] = p.Material
            p.Material = State.killMatPick
        end
    else
        for _, p in ipairs(parts) do
            if originalTextures[p] then pcall(function() p.Material = originalTextures[p] end) end
        end
        originalTextures = {}
    end
end)

-- ============================================================
-- ENVIRONMENT
-- ============================================================
sectionLabel("── ENVIRONMENT ──", 20)

makeToggle("Fog Mode", 21, function(on)
    State.fogMode = on
    if on then
        Lighting.FogStart = 0
        Lighting.FogEnd   = 55
        Lighting.FogColor = Color3.fromRGB(170,185,195)
    else
        Lighting.FogStart = originalFog.FogStart
        Lighting.FogEnd   = originalFog.FogEnd
        Lighting.FogColor = originalFog.FogColor
    end
end)

-- ============================================================
-- FUN GAME MODES
-- ============================================================
sectionLabel("── FUN GAME MODES ──", 30)

-- Laps
local lapInfo = Instance.new("TextLabel")
lapInfo.Size               = UDim2.new(1,-4,0,24)
lapInfo.BackgroundTransparency = 1
lapInfo.Text               = "Laps: 0"
lapInfo.TextColor3         = Color3.fromRGB(180,180,200)
lapInfo.Font               = Enum.Font.GothamBold
lapInfo.TextSize           = 13
lapInfo.LayoutOrder        = 31
lapInfo.ZIndex             = 101
lapInfo.Parent             = contentFrame

makeToggle("Laps Mode", 32, function(on)
    State.lapsMode = on
    State.lapCount = 0
    lapInfo.Text   = "Laps: 0"
    if lapConn then lapConn:Disconnect() lapConn = nil end
    if not on then return end

    local lapDebounce = false
    lapConn = RunService.Heartbeat:Connect(function()
        if lapDebounce then return end
        local c = lp.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        for _, part in ipairs(getFinishes()) do
            if (h.Position - part.Position).Magnitude < 10 then
                lapDebounce = true
                State.lapCount += 1
                lapInfo.Text = "Laps: " .. State.lapCount
                task.spawn(function()
                    task.wait(0.3)
                    local c2 = lp.Character
                    if c2 then
                        local hum = c2:FindFirstChildOfClass("Humanoid")
                        if hum then hum:ChangeState(Enum.HumanoidStateType.Dead) end
                    end
                    task.wait(2.5)
                    lapDebounce = false
                end)
                break
            end
        end
    end)
end)

-- Race
local raceInfo = Instance.new("TextLabel")
raceInfo.Size               = UDim2.new(1,-4,0,22)
raceInfo.BackgroundTransparency = 1
raceInfo.Text               = "Race target: none"
raceInfo.TextColor3         = Color3.fromRGB(180,180,200)
raceInfo.Font               = Enum.Font.Gotham
raceInfo.TextSize           = 12
raceInfo.LayoutOrder        = 33
raceInfo.ZIndex             = 101
raceInfo.Parent             = contentFrame

makeInput("Race Mode — Enter Opponent Name", 34, "Player name, then Enter...", function(name)
    if name == "" then return end
    local target = Players:FindFirstChild(name)
    if not target then notify("Player not found: " .. name) return end
    State.raceTarget = target
    raceInfo.Text = "Race target: " .. name
    notify("Racing: " .. name)

    if raceConn then raceConn:Disconnect() end
    local raceDebounce = false
    raceConn = RunService.Heartbeat:Connect(function()
        if raceDebounce or not State.raceTarget then return end
        local tc = State.raceTarget.Character
        if not tc then return end
        local th = tc:FindFirstChild("HumanoidRootPart")
        if not th then return end
        for _, part in ipairs(getFinishes()) do
            if (th.Position - part.Position).Magnitude < 10 then
                raceDebounce = true
                notify(State.raceTarget.Name .. " finished first! You lose!")
                task.spawn(function()
                    local c2 = lp.Character
                    if c2 then
                        local hum = c2:FindFirstChildOfClass("Humanoid")
                        if hum then hum:ChangeState(Enum.HumanoidStateType.Dead) end
                    end
                    task.wait(2)
                    if raceConn then raceConn:Disconnect() raceConn = nil end
                end)
                break
            end
        end
    end)
end)

-- Streak
local streakInfo = Instance.new("TextLabel")
streakInfo.Size               = UDim2.new(1,-4,0,24)
streakInfo.BackgroundTransparency = 1
streakInfo.Text               = "Streak: 0"
streakInfo.TextColor3         = Color3.fromRGB(255,200,80)
streakInfo.Font               = Enum.Font.GothamBold
streakInfo.TextSize           = 13
streakInfo.LayoutOrder        = 35
streakInfo.ZIndex             = 101
streakInfo.Parent             = contentFrame

makeToggle("Streak Mode (1 Life)", 36, function(on)
    State.streakMode = on
    if not on then return end

    local function hookChar(c)
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        hum.Died:Connect(function()
            if not State.streakMode then return end
            State.streakCount = 0
            streakInfo.Text   = "Streak: 0  (LOST)"
            notify("Streak broken! Back to 0.")
        end)
        local sDebounce = false
        RunService.Heartbeat:Connect(function()
            if not State.streakMode or sDebounce then return end
            local h = c:FindFirstChild("HumanoidRootPart")
            if not h then return end
            for _, part in ipairs(getFinishes()) do
                if (h.Position - part.Position).Magnitude < 10 then
                    sDebounce = true
                    State.streakCount += 1
                    streakInfo.Text = "Streak: " .. State.streakCount .. " WIN"
                    notify("Tower complete! Streak: " .. State.streakCount)
                    task.spawn(function() task.wait(3) sDebounce = false end)
                    break
                end
            end
        end)
    end

    hookChar(lp.Character or lp.CharacterAdded:Wait())
    lp.CharacterAdded:Connect(hookChar)
end)

-- ============================================================
-- CHAOS MODES
-- ============================================================
sectionLabel("── CHAOS MODES ──", 40)

-- Epilepsy
local epilepsyWarned = false
makeButton("Epilepsy Mode (B&W / Color)", 41, function()
    if not epilepsyWarned then
        notify("WARNING: Rapid flashing ahead. Tap again to confirm.", 5)
        epilepsyWarned = true
        return
    end
    epilepsyWarned = false

    if State.epilepsyMode then
        State.epilepsyMode = false
        if epilepsyConn then epilepsyConn:Disconnect() epilepsyConn = nil end
        Lighting.Brightness       = 1
        Lighting.ColorShift_Top   = Color3.new(0,0,0)
        local eg = screenGui:FindFirstChild("EpiGUI")
        if eg then eg:Destroy() end
        return
    end

    local epiGui = Instance.new("Frame")
    epiGui.Name            = "EpiGUI"
    epiGui.Size            = UDim2.new(3,0,3,0)
    epiGui.Position        = UDim2.new(-1,0,-1,0)
    epiGui.BackgroundColor3= Color3.new(0,0,0)
    epiGui.BackgroundTransparency = 1
    epiGui.ZIndex          = 400
    epiGui.Parent          = screenGui

    local bwBtn2 = Instance.new("TextButton")
    bwBtn2.Size             = UDim2.new(0,100,0,40)
    bwBtn2.Position         = UDim2.new(0.5,-105,0.5,-20)
    bwBtn2.AnchorPoint      = Vector2.new(0,0)
    bwBtn2.BackgroundColor3 = Color3.fromRGB(200,200,200)
    bwBtn2.Text             = "B & W"
    bwBtn2.TextColor3       = Color3.new(0,0,0)
    bwBtn2.Font             = Enum.Font.GothamBold
    bwBtn2.TextSize         = 14
    bwBtn2.ZIndex           = 401
    bwBtn2.Parent           = epiGui
    Instance.new("UICorner",bwBtn2).CornerRadius = UDim.new(0,8)

    local colBtn2 = Instance.new("TextButton")
    colBtn2.Size             = UDim2.new(0,100,0,40)
    colBtn2.Position         = UDim2.new(0.5,5,0.5,-20)
    colBtn2.BackgroundColor3 = Color3.fromRGB(180,50,200)
    colBtn2.Text             = "COLOR"
    colBtn2.TextColor3       = Color3.new(1,1,1)
    colBtn2.Font             = Enum.Font.GothamBold
    colBtn2.TextSize         = 14
    colBtn2.ZIndex           = 401
    colBtn2.Parent           = epiGui
    Instance.new("UICorner",colBtn2).CornerRadius = UDim.new(0,8)

    local function startEpi(epType)
        epiGui:Destroy()
        State.epilepsyMode = true
        local t = 0
        epilepsyConn = RunService.RenderStepped:Connect(function(dt)
            if not State.epilepsyMode then return end
            t = t + dt * 12
            if epType == "bw" then
                local v = (math.sin(t) > 0) and 1 or 0
                Lighting.Brightness     = v * 6
                Lighting.ColorShift_Top = Color3.new(v, v, v)
            else
                Lighting.ColorShift_Top = Color3.fromHSV(t % 1, 1, 1)
                Lighting.Brightness     = 2 + math.sin(t) * 2
            end
        end)
    end
    bwBtn2.MouseButton1Click:Connect(function() startEpi("bw") end)
    colBtn2.MouseButton1Click:Connect(function() startEpi("color") end)
end, Color3.fromRGB(170,70,40))

-- Jumpscare Death
local jumpscareActive = false
makeButton("Jumpscare Death Mode", 42, function()
    jumpscareActive = not jumpscareActive
    notify(jumpscareActive and "Jumpscare ON!" or "Jumpscare OFF")
    if not jumpscareActive then return end

    local function doJumpscare()
        local ov = makeOverlay(Color3.new(0,0,0), 0)
        local img = Instance.new("ImageLabel")
        img.Size               = UDim2.new(3,0,3,0)
        img.Position           = UDim2.new(-1,0,-1,0)
        img.Image              = "rbxassetid://128595216960250"
        img.BackgroundTransparency = 1
        img.ZIndex             = 501
        img.Parent             = screenGui
        playSound(96443758876586, 1)
        task.delay(3, function()
            pcall(function() ov:Destroy() end)
            pcall(function() img:Destroy() end)
        end)
        task.delay(1.5, function()
            local bl = makeOverlay(Color3.new(0,0,0), 0)
            task.delay(9, function() pcall(function() bl:Destroy() end) end)
        end)
    end

    local function hookChar2(c)
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum then hum.Died:Connect(function() if jumpscareActive then doJumpscare() end end) end
    end
    hookChar2(lp.Character or lp.CharacterAdded:Wait())
    lp.CharacterAdded:Connect(hookChar2)
end, Color3.fromRGB(110,15,15))

-- Flood Escape
makeInput("Flood Rise Speed (studs/s)", 43, "Default: 1", function(val)
    State.floodSpeed = tonumber(val) or 1
end)

local floodBtn = makeButton("START Flood Escape", 44, function() end, Color3.fromRGB(0,75,155))
floodBtn.MouseButton1Click:Connect(function()
    if State.floodMode then
        State.floodMode = false
        if floodConn   then floodConn:Disconnect()   floodConn = nil end
        if floodPart   then floodPart:Destroy();      floodPart = nil end
        if floodTheme  then floodTheme:Stop();  floodTheme:Destroy();  floodTheme = nil end
        if floodBlur   then floodBlur:Destroy();  floodBlur = nil end
        if floodCC     then floodCC:Destroy();    floodCC   = nil end
        floodBtn.Text = "START Flood Escape"
        notify("Flood stopped.")
        return
    end

    State.floodMode = true
    floodBtn.Text   = "STOP Flood Escape"
    notify("Flood starts in 10 seconds!")

    local speed = State.floodSpeed or 1

    floodTheme = safeSound(71991763100641, workspace)
    floodTheme.Looped  = true
    floodTheme.Volume  = 0.7
    floodTheme:Play()

    -- Underwater visual effects
    floodBlur = Instance.new("BlurEffect")
    floodBlur.Size   = 0
    floodBlur.Parent = Lighting

    floodCC = Instance.new("ColorCorrectionEffect")
    floodCC.TintColor    = Color3.fromRGB(80, 140, 255)
    floodCC.Brightness   = -0.1
    floodCC.Saturation   = 0.3
    floodCC.Enabled      = false
    floodCC.Parent       = Lighting

    task.delay(10, function()
        if not State.floodMode then return end
        local c = lp.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end

        floodPart = Instance.new("Part")
        floodPart.Size        = Vector3.new(1000, 20, 1000)
        floodPart.Position    = Vector3.new(h.Position.X, h.Position.Y - 10, h.Position.Z)
        floodPart.Anchored    = true
        floodPart.CanCollide  = false
        floodPart.Material    = Enum.Material.Neon
        floodPart.Color       = Color3.fromRGB(0, 100, 210)
        floodPart.Transparency= 0.35
        floodPart.Name        = "FloodWater"
        floodPart.Parent      = workspace

        local lastDmg = tick()

        floodConn = RunService.Heartbeat:Connect(function(dt)
            if not State.floodMode or not floodPart then return end
            local c2 = lp.Character
            if not c2 then return end
            local h2  = c2:FindFirstChild("HumanoidRootPart")
            local hum2= c2:FindFirstChildOfClass("Humanoid")
            if not h2 or not hum2 then return end

            local playerY  = h2.Position.Y
            local floodTopY= floodPart.Position.Y + 10

            -- Speed logic: far away = fast catch-up
            local dist = playerY - floodTopY
            local curSpeed = speed
            if dist > 70 then
                curSpeed = speed * 3
            elseif dist > 30 then
                curSpeed = speed * 2
            end

            floodPart.Position = floodPart.Position + Vector3.new(0, curSpeed * dt, 0)

            -- Underwater blur effect: when flood top reaches player's head (Y+2.5)
            local headY = playerY + 2.5
            local isUnder = floodTopY >= headY
            if floodCC then floodCC.Enabled = isUnder end
            if floodBlur then floodBlur.Size = isUnder and 14 or 0 end

            -- Damage every 2s if submerged
            if floodTopY >= headY then
                if tick() - lastDmg >= 2 then
                    lastDmg = tick()
                    hum2:TakeDamage(40)
                end
            end

            -- Finish check
            for _, part in ipairs(getFinishes()) do
                if (h2.Position - part.Position).Magnitude < 10 then
                    notify("You escaped the flood!")
                    playSound(9126104501, 1)
                    State.floodMode = false
                    if floodTheme then floodTheme:Stop() end
                    if floodCC    then floodCC.Enabled = false end
                    if floodBlur  then floodBlur.Size  = 0 end
                    if floodConn  then floodConn:Disconnect() floodConn = nil end
                    floodBtn.Text = "START Flood Escape"
                    local fp2 = floodPart
                    local dConn
                    dConn = RunService.Heartbeat:Connect(function(dt2)
                        if not fp2 or not fp2.Parent then if dConn then dConn:Disconnect() end return end
                        fp2.Position = fp2.Position - Vector3.new(0, 10*dt2, 0)
                        if fp2.Position.Y < h2.Position.Y - 300 then
                            fp2:Destroy() floodPart = nil
                            dConn:Disconnect()
                        end
                    end)
                    return
                end
            end

            -- Death check
            if hum2.Health <= 0 then
                State.floodMode = false
                if floodConn  then floodConn:Disconnect()  floodConn = nil end
                if floodPart  then floodPart:Destroy();    floodPart = nil end
                if floodTheme then floodTheme:Stop() end
                if floodCC    then floodCC.Enabled = false end
                if floodBlur  then floodBlur.Size  = 0 end
                floodBtn.Text = "START Flood Escape"
                notify("You drowned! Press Start to retry.")
            end
        end)
    end)
end)

-- ============================================================
-- OH NO MR EVIL
-- ============================================================
local mrEvilBtn = makeButton("OH NO MR EVIL!", 50, function() end, Color3.fromRGB(70,0,0))
mrEvilBtn.MouseButton1Click:Connect(function()
    if mrEvil then
        if mrEvilConn  then mrEvilConn:Disconnect()  mrEvilConn = nil end
        if mrEvilTheme then mrEvilTheme:Stop(); mrEvilTheme:Destroy(); mrEvilTheme = nil end
        if mrEvilCatchSound then mrEvilCatchSound:Stop(); mrEvilCatchSound:Destroy(); mrEvilCatchSound = nil end
        if mrEvil      then mrEvil:Destroy();      mrEvil = nil end
        mrEvilBtn.Text = "OH NO MR EVIL!"
        notify("Mr Evil dismissed.")
        return
    end

    mrEvilBtn.Text = "STOP MR EVIL"
    notify("Mr Evil appears in 10 seconds...")

    task.delay(10, function()
        local c = lp.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end

        -- Build model
        local evil = Instance.new("Model")
        evil.Name   = "MrEvil"
        evil.Parent = workspace
        mrEvil = evil

        local body = Instance.new("Part")
        body.Size        = Vector3.new(4, 8, 1)
        body.Transparency= 1
        body.CanCollide  = false
        body.Anchored    = true
        body.CastShadow  = false
        body.Position    = h.Position + Vector3.new(30, 0, 0)
        body.Name        = "HumanoidRootPart"
        body.Parent      = evil
        evil.PrimaryPart = body

        -- Face billboard — AlwaysOnTop so walls don't block it
        local billboard = Instance.new("BillboardGui")
        billboard.Size          = UDim2.new(0, 320, 0, 320)
        billboard.StudsOffset   = Vector3.new(0, 0, 0)
        billboard.AlwaysOnTop   = true
        billboard.LightInfluence= 0
        billboard.Parent        = body

        local faceImg = Instance.new("ImageLabel")
        faceImg.Size               = UDim2.new(1,0,1,0)
        faceImg.Image              = "rbxassetid://128595216960250"
        faceImg.BackgroundTransparency = 1
        faceImg.ImageColor3        = Color3.new(1,1,1)
        faceImg.ZIndex             = 2
        faceImg.Parent             = billboard

        -- Dense black SQUARE particles (2x player size = ~12 studs)
        local att = Instance.new("Attachment", body)
        local particles = Instance.new("ParticleEmitter", att)
        particles.Texture     = "rbxassetid://243660364"  -- white square, recolored black
        particles.Color       = ColorSequence.new(Color3.new(0,0,0), Color3.new(0.05,0,0.08))
        particles.LightEmission = 0
        particles.LightInfluence= 0
        particles.Rate        = 200
        particles.Rotation    = NumberRange.new(0,360)
        particles.RotSpeed    = NumberRange.new(-90,90)
        particles.Speed       = NumberRange.new(4, 10)
        particles.SpreadAngle = Vector2.new(180, 180)
        particles.Lifetime    = NumberRange.new(0.6, 1.4)
        particles.Size        = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 12),
            NumberSequenceKeypoint.new(0.5, 8),
            NumberSequenceKeypoint.new(1, 0),
        })
        particles.Transparency= NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })

        -- Sounds
        mrEvilTheme = safeSound(70601819363531, workspace)
        mrEvilTheme.Looped  = true
        mrEvilTheme.Volume  = 0.6
        mrEvilTheme:Play()

        local teleportChance = 12
        local lastTeleport   = tick()
        local burstMode      = false
        local burstCount     = 0
        local caught         = false

        local function catchPlayer()
            if caught then return end
            caught = true
            if mrEvilTheme then mrEvilTheme:Stop() end
            -- Play catch sound ONCE, track it so we can stop it
            mrEvilCatchSound = safeSound(96443758876586, workspace)
            mrEvilCatchSound.Volume = 1
            mrEvilCatchSound:Play()

            local bl = makeOverlay(Color3.new(0,0,0), 0)
            task.delay(10, function()
                pcall(function() bl:Destroy() end)
                if mrEvilCatchSound then
                    mrEvilCatchSound:Stop()
                    mrEvilCatchSound:Destroy()
                    mrEvilCatchSound = nil
                end
                if mrEvil      then mrEvil:Destroy();      mrEvil = nil end
                if mrEvilConn  then mrEvilConn:Disconnect() mrEvilConn = nil end
                mrEvilBtn.Text = "OH NO MR EVIL!"
            end)
        end

        local function teleportEvil(studs)
            if caught or not mrEvil or not mrEvil.Parent then return false end
            local c2 = lp.Character
            if not c2 then return false end
            local h2 = c2:FindFirstChild("HumanoidRootPart")
            if not h2 then return false end

            playSound(133537522827881, 0.7, workspace)
            local dir  = (h2.Position - body.Position).Unit
            local dist = (h2.Position - body.Position).Magnitude
            body.Position = body.Position + dir * math.min(studs, dist)

            if (body.Position - h2.Position).Magnitude < 5 then
                catchPlayer()
                return true
            end
            return false
        end

        mrEvilConn = RunService.Heartbeat:Connect(function()
            if caught then return end
            if not mrEvil or not mrEvil.Parent then return end
            local c2 = lp.Character
            if not c2 then return end
            local h2 = c2:FindFirstChild("HumanoidRootPart")
            local hum2 = c2:FindFirstChildOfClass("Humanoid")
            if not h2 then return end

            -- If player dies in mr evil mode, stop sounds
            if hum2 and hum2.Health <= 0 then
                if mrEvilCatchSound then mrEvilCatchSound:Stop() end
                if mrEvilTheme then mrEvilTheme:Stop() end
                return
            end

            local now  = tick()
            local dist = (h2.Position - body.Position).Magnitude

            -- Interval: constant fast teleport when > 70 studs, normal when <= 70
            local interval = (dist > 70) and 0.4 or 1.5
            if math.random(100) <= 30 then interval = interval + 0.5 end

            local studsRange = (dist <= 15)
                and {min=4, max=6}  -- close (+1 from 3-5)
                or  {min=5, max=9}  -- far  (+1 from 4-8)

            if burstMode then return end

            if now - lastTeleport >= interval then
                lastTeleport = now
                local studs = math.random(studsRange.min, studsRange.max)
                if teleportEvil(studs) then return end

                teleportChance = teleportChance + 4
                if math.random(100) <= teleportChance then
                    teleportChance = 12
                    burstMode  = true
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
                        teleportEvil(math.random(5, 9))
                        task.delay(5/4, doBurst)
                    end
                    task.delay(0.5, doBurst)
                end
            end

            -- Finish check
            for _, part in ipairs(getFinishes()) do
                if (h2.Position - part.Position).Magnitude < 10 then
                    if mrEvilTheme then mrEvilTheme:Stop() end
                    playSound(130220195052699, 0.8, workspace)
                    task.delay(2, function() playSound(133007160723578, 1, workspace) end)
                    local tw = TweenService:Create(faceImg, TweenInfo.new(3), {ImageTransparency=1})
                    tw:Play()
                    task.spawn(function()
                        for i = 200, 0, -7 do
                            if particles and particles.Parent then particles.Rate = i end
                            task.wait(3/30)
                        end
                    end)
                    if mrEvilConn then mrEvilConn:Disconnect() mrEvilConn = nil end
                    mrEvilBtn.Text = "OH NO MR EVIL!"
                    task.delay(3.5, function()
                        if mrEvil then mrEvil:Destroy() mrEvil = nil end
                    end)
                    return
                end
            end
        end)
    end)
end)

-- ============================================================
-- RED LIGHT GREEN LIGHT
-- ============================================================
local rlglBtn = makeButton("Red Light Green Light", 51, function() end, Color3.fromRGB(150,15,15))
rlglBtn.MouseButton1Click:Connect(function()
    if State.redLightMode then
        State.redLightMode = false
        if redLightConn then redLightConn:Disconnect() redLightConn = nil end
        local g = lp.PlayerGui:FindFirstChild("RLGLOverlay")
        if g then g:Destroy() end
        rlglBtn.Text = "Red Light Green Light"
        notify("Red Light Green Light stopped.")
        return
    end

    State.redLightMode = true
    rlglBtn.Text = "STOP Red/Green Light"
    notify("Red Light Green Light! Don't move on RED!")

    local overlayGui = Instance.new("ScreenGui")
    overlayGui.Name           = "RLGLOverlay"
    overlayGui.ResetOnSpawn   = false
    overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    overlayGui.IgnoreGuiInset = true
    overlayGui.Parent         = lp.PlayerGui

    local flash = Instance.new("Frame")
    flash.Size             = UDim2.new(3,0,3,0)
    flash.Position         = UDim2.new(-1,0,-1,0)
    flash.BackgroundColor3 = Color3.new(0,1,0)
    flash.BackgroundTransparency = 0.25
    flash.ZIndex           = 300
    flash.Visible          = false
    flash.Parent           = overlayGui

    local flashLbl = Instance.new("TextLabel")
    flashLbl.Size              = UDim2.new(1,0,0.15,0)
    flashLbl.Position          = UDim2.new(0,0,0.42,0)
    flashLbl.BackgroundTransparency = 1
    flashLbl.Text              = "GREEN LIGHT"
    flashLbl.TextColor3        = Color3.new(1,1,1)
    flashLbl.Font              = Enum.Font.GothamBold
    flashLbl.TextSize          = 80
    flashLbl.ZIndex            = 301
    flashLbl.TextStrokeColor3  = Color3.new(0,0,0)
    flashLbl.TextStrokeTransparency = 0.5
    flashLbl.Parent            = overlayGui

    local isRed   = false
    local lastPos = nil
    local phaseEnd= tick() + math.random(3,6)

    redLightConn = RunService.Heartbeat:Connect(function()
        if not State.redLightMode then
            pcall(function() overlayGui:Destroy() end)
            return
        end
        local c2  = lp.Character
        if not c2 then return end
        local h2  = c2:FindFirstChild("HumanoidRootPart")
        local hum2= c2:FindFirstChildOfClass("Humanoid")
        if not h2 or not hum2 then return end

        for _, part in ipairs(getFinishes()) do
            if (h2.Position - part.Position).Magnitude < 10 then
                State.redLightMode = false
                pcall(function() overlayGui:Destroy() end)
                if redLightConn then redLightConn:Disconnect() redLightConn = nil end
                rlglBtn.Text = "Red Light Green Light"
                notify("Finished! Red Light Green Light ends.")
                return
            end
        end

        local now = tick()
        if now >= phaseEnd then
            isRed     = not isRed
            phaseEnd  = now + math.random(2,5)
            lastPos   = h2.Position
            flash.Visible = true
            if isRed then
                flash.BackgroundColor3  = Color3.new(1,0,0)
                flashLbl.Text           = "RED LIGHT!"
                flashLbl.TextColor3     = Color3.new(1,1,0)
                playSound(112538636639786, 1)
            else
                flash.BackgroundColor3  = Color3.new(0,1,0)
                flashLbl.Text           = "GREEN LIGHT"
                flashLbl.TextColor3     = Color3.new(1,1,1)
                playSound(96443758876586, 0.5)
            end
            task.delay(0.6, function() pcall(function() flash.Visible = false end) end)
        end

        if isRed and lastPos then
            if (h2.Position - lastPos).Magnitude > 1.5 then
                notify("CAUGHT MOVING!")
                hum2:TakeDamage(hum2.MaxHealth)
                lastPos = h2.Position
            end
        end
    end)
end)

-- ============================================================
-- ANNOYING MODE
-- ============================================================
local annoyBtn = makeButton("Annoying / Distraction Mode", 52, function() end, Color3.fromRGB(150,90,5))
annoyBtn.MouseButton1Click:Connect(function()
    State.annoyingMode = not State.annoyingMode
    annoyBtn.Text = State.annoyingMode and "STOP Annoying Mode" or "Annoying / Distraction Mode"
    notify(State.annoyingMode and "Annoying Mode ON!" or "Annoying Mode OFF")

    if not State.annoyingMode then
        if annoyConn then annoyConn:Disconnect() annoyConn = nil end
        return
    end

    local popupChance   = 30
    local lastCheck     = tick()
    local popupActive   = false

    local function spawnPopup()
        if popupActive then return end
        popupActive = true
        playSound(130988530651697, 0.8)

        local pGui = Instance.new("ScreenGui")
        pGui.Name           = "AnnoyPopup"
        pGui.ResetOnSpawn   = false
        pGui.IgnoreGuiInset = true
        pGui.Parent         = lp.PlayerGui

        local frame = Instance.new("Frame")
        frame.Size             = UDim2.new(0,260,0,180)
        frame.Position         = UDim2.new(math.random(5,65)/100,0, math.random(10,60)/100,0)
        frame.BackgroundColor3 = Color3.fromRGB(192,192,192)
        frame.BorderSizePixel  = 2
        frame.ZIndex           = 280
        frame.Parent           = pGui
        Instance.new("UICorner",frame).CornerRadius = UDim.new(0,4)

        local img2 = Instance.new("ImageLabel")
        img2.Size               = UDim2.new(1,0,1,0)
        img2.Image              = "rbxassetid://4519042263"
        img2.BackgroundTransparency = 1
        img2.ZIndex             = 281
        img2.Parent             = frame

        local xBtn = Instance.new("TextButton")
        xBtn.Size             = UDim2.new(0,22,0,22)
        xBtn.Position         = UDim2.new(1,-24,0,2)
        xBtn.BackgroundColor3 = Color3.fromRGB(200,40,40)
        xBtn.Text             = "X"
        xBtn.TextColor3       = Color3.new(1,1,1)
        xBtn.Font             = Enum.Font.GothamBold
        xBtn.TextSize         = 12
        xBtn.ZIndex           = 282
        xBtn.BorderSizePixel  = 0
        xBtn.Parent           = frame
        Instance.new("UICorner",xBtn).CornerRadius = UDim.new(0,4)
        xBtn.MouseButton1Click:Connect(function()
            pGui:Destroy()
            popupActive = false
        end)
    end

    annoyConn = RunService.Heartbeat:Connect(function()
        if not State.annoyingMode then return end
        local now = tick()
        if now - lastCheck >= 10 then
            lastCheck = now
            if math.random(100) <= popupChance and not popupActive then
                spawnPopup()
                popupChance = popupChance + 4
                if math.random(100) <= 10 then
                    popupChance = popupChance + 4
                    for i = 1, 5 do
                        task.delay(i*0.7, function()
                            if State.annoyingMode then spawnPopup() end
                        end)
                    end
                end
            end
        end
    end)

    task.spawn(function()
        while State.annoyingMode do
            task.wait(math.random(8,20))
            if not State.annoyingMode then break end
            local c2 = lp.Character
            if c2 then
                local hum2 = c2:FindFirstChildOfClass("Humanoid")
                if hum2 then
                    local ev = math.random(2)
                    if ev == 1 then
                        hum2.Jump = true
                    else
                        cam.CFrame = CFrame.new(cam.CFrame.Position)
                            * CFrame.Angles(0, math.rad(({0,90,180,270})[math.random(4)]), 0)
                    end
                end
            end
        end
    end)

    local function hookAnnoy(c2)
        local hum2 = c2:FindFirstChildOfClass("Humanoid")
        if hum2 then
            hum2.Died:Connect(function()
                if not State.annoyingMode then return end
                task.wait(0.5)
                pcall(function()
                    game:GetService("ReplicatedStorage")
                        :WaitForChild("DefaultChatSystemChatEvents")
                        :WaitForChild("SayMessageRequest")
                        :FireServer("/e laugh","All")
                end)
            end)
        end
    end
    hookAnnoy(lp.Character or lp.CharacterAdded:Wait())
    lp.CharacterAdded:Connect(hookAnnoy)
end)

-- ============================================================
-- RESPAWN HOOK — reapply invisibility on respawn
-- ============================================================
lp.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    if State.invisPlayers then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character then
                local isWhitelisted = false
                for _, n in ipairs(State.invisWhitelist) do
                    if plr.Name == n then isWhitelisted = true break end
                end
                if not isWhitelisted then
                    for _, p in ipairs(plr.Character:GetDescendants()) do
                        pcall(function()
                            if p:IsA("BasePart") or p:IsA("Decal") then
                                p.LocalTransparencyModifier = 1
                            end
                            if p:IsA("BillboardGui") then p.Enabled = false end
                        end)
                    end
                end
            end
        end
    end
end)

notify("TOH Suite v2 loaded! " .. #Players:GetPlayers() .. " players online.", 5)
