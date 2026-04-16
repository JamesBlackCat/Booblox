repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local settings = {
    -- Aimbot
    silentAim = false,
    triggerBot = false,
    autoShoot = false,
    maxCharge = false,
    fov = 200,
    -- Combat
    instantFireRate = false,
    infiniteAmmo = false,
    -- ESP
    espEnabled = false,
    espEnemyOnly = false,
    espTeamOnly = false,
    espBoxes = true,
    espNames = true,
    espDistance = true,
    espHealth = true,
    espTracers = false,
    espMaxDistance = 1000,
    espEnemyColor = Color3.fromRGB(255, 50, 50),
    espTeamColor = Color3.fromRGB(50, 255, 50),
    -- Visuals
    fovCircle = true,
    targetHighlight = false,
    knifeTracers = false,
}

local m_GameCharacterController = require(ReplicatedStorage.Client.Controllers.GameCharacterController)
local m_CombatClient = require(ReplicatedStorage.Client.Madwork.CombatClient)
local m_BackpackClient = require(ReplicatedStorage.Client.Madwork.BackpackClient)
local m_ToolUsageClient = require(ReplicatedStorage.Client.Madwork.ToolUsageClient)
local m_MadFSM = require(ReplicatedStorage.Shared.Madwork.MadFSM)
local m_MadworkCaster = require(ReplicatedStorage.Shared.Madwork.MadworkCaster)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function IsVisible(head)
    local localChar = LocalPlayer.Character
    if not localChar then return false end
    local rootPart = localChar:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    rayParams.FilterDescendantsInstances = {localChar}
    local result = workspace:Raycast(rootPart.Position, head.Position - rootPart.Position, rayParams)
    if result then
        return result.Instance:IsDescendantOf(head.Parent)
    end
    return false
end

local function GetClosestHead()
    local mousePos = UserInputService:GetMouseLocation()
    local closest = nil
    local closestDist = settings.fov
    local closestPlayer = nil
    local closestGameChar = nil

    for _, gameChar in ipairs(m_GameCharacterController.GetGameCharacters()) do
        if gameChar.Player == LocalPlayer then continue end
        if gameChar.GamePlayer:GetLocalRelationship() ~= "Enemy" then continue end
        local char = gameChar.Character
        if not char or not char.IsAlive then continue end
        local model = char.Model
        local head = model:FindFirstChild("Head")
        local humanoid = model:FindFirstChild("Humanoid")
        if head and humanoid and humanoid.Health > 0 then
            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = head
                    closestPlayer = gameChar.Player
                    closestGameChar = gameChar
                end
            end
        end
    end

    return closest, closestPlayer, closestGameChar
end

-- Silent Aim
m_CombatClient.OnLocalEvent:Connect(function(combatEvent)
    if not settings.silentAim then return end
    local head = GetClosestHead()
    if not head then return end
    local throwPos = combatEvent.GameAction.Position
    combatEvent.GameAction.Direction = (head.Position - throwPos).Unit
    if settings.maxCharge then
        combatEvent.GameAction.Charge = 1
    end
end)

-- Infinite Ammo
local useClipHooked = false
local function HookUseClip()
    if useClipHooked then return end
    local upvalues = getupvalues(m_ToolUsageClient.NewToolUsage)
    for i, v in pairs(upvalues) do
        if type(v) == "table" and v.UseClip ~= nil then
            local original_UseClip = v.UseClip
            v.UseClip = function(self)
                if settings.infiniteAmmo then
                    self.Clip = self.Clip + 1
                end
                return original_UseClip(self)
            end
            useClipHooked = true
            break
        end
    end
end
HookUseClip()

-- FSM
local function PatchFSM(fsm)
    if not fsm or not fsm._states then return end
    for name, state in pairs(fsm._states) do
        if name == "Fire" or name == "Throw" or name == "Reload" then
            state.Duration = 0
            state.Leaving = nil
            state.Entering = nil
        end
    end
end

local function GetAllTools()
    local tools = {}
    local upvals = getupvalues(m_BackpackClient.GetToolById)
    for i, v in pairs(upvals) do
        if type(v) == "table" then
            for id, tool in pairs(v) do
                if type(tool) == "table" and tool.Store then
                    table.insert(tools, tool)
                end
            end
        end
    end
    return tools
end

local function IsKnifeTool(tool)
    return tool.Setup and tool.Setup.ToolBehaviour == "Knife"
end

local orig = m_MadFSM.NewMadFSM
m_MadFSM.NewMadFSM = function()
    local fsm = orig()
    local origDef = fsm.DefineStates
    fsm.DefineStates = function(self, states)
        for _, name in ipairs({"Fire", "Throw", "Reload"}) do
            if states[name] and settings.instantFireRate then
                states[name].Duration = 0
                states[name].Leaving = nil
                states[name].Entering = nil
            end
        end
        return origDef(self, states)
    end
    return fsm
end

local patched = {}
task.spawn(function()
    while true do
        task.wait(0.1)
        for _, tool in ipairs(GetAllTools()) do
            local fsm = tool.Store.FSM
            if fsm then
                if not patched[fsm] then
                    patched[fsm] = true
                    PatchFSM(fsm)
                end
                if settings.instantFireRate then
                    if fsm.State == "Fire" or fsm.State == "Throw" or fsm.State == "Reload" then
                        fsm.Progress = 1
                        fsm.Duration = 0
                        fsm.StartTime = 0
                    end
                end
            end
        end
    end
end)

local function TryFire()
    for _, tool in ipairs(GetAllTools()) do
        if tool.Equipped and tool.Store.FSM and IsKnifeTool(tool) then
            local fsm = tool.Store.FSM
            if fsm.State == "Idle" or fsm.State == "Throw" or fsm.State == "Fire" then
                fsm:Set("Throw")
            end
        end
    end
end

-- Triggerbot (knife only)
task.spawn(function()
    while true do
        task.wait(0.05)
        if settings.triggerBot then
            local head = GetClosestHead()
            if head and IsVisible(head) then
                TryFire()
            end
        end
    end
end)

-- Auto Shoot (knife only)
task.spawn(function()
    while true do
        task.wait(0.05)
        if settings.autoShoot then
            local head = GetClosestHead()
            if head then
                TryFire()
            end
        end
    end
end)

-- ESP Drawing
local espObjects = {}

local function NewDrawing(type, props)
    local d = Drawing.new(type)
    for k, v in pairs(props) do
        d[k] = v
    end
    return d
end

local function CreateESPForChar(gameChar)
    if gameChar.Player == LocalPlayer then return end
    if espObjects[gameChar] then return end

    local box = NewDrawing("Square", {Thickness = 1, Filled = false, Visible = false})
    local boxOutline = NewDrawing("Square", {Thickness = 3, Color = Color3.fromRGB(0,0,0), Filled = false, Visible = false})
    local healthBarBg = NewDrawing("Square", {Thickness = 0, Color = Color3.fromRGB(0,0,0), Filled = true, Visible = false})
    local healthBar = NewDrawing("Square", {Thickness = 0, Filled = true, Visible = false})
    local label = NewDrawing("Text", {Size = 13, Center = true, Outline = true, Font = Drawing.Fonts.GothamBold, Visible = false})
    local tracer = NewDrawing("Line", {Thickness = 1, Visible = false})

    espObjects[gameChar] = {
        box = box,
        boxOutline = boxOutline,
        healthBarBg = healthBarBg,
        healthBar = healthBar,
        label = label,
        tracer = tracer
    }
end

local function RemoveESPForChar(gameChar)
    local esp = espObjects[gameChar]
    if not esp then return end
    for _, d in pairs(esp) do d:Remove() end
    espObjects[gameChar] = nil
end

local function GetCharColor(gameChar)
    local rel = gameChar.GamePlayer:GetLocalRelationship()
    return rel == "Enemy" and settings.espEnemyColor or settings.espTeamColor
end

local function ShouldShowESP(gameChar)
    if not settings.espEnabled then return false end
    local rel = gameChar.GamePlayer:GetLocalRelationship()
    if settings.espEnemyOnly and rel ~= "Enemy" then return false end
    if settings.espTeamOnly and rel ~= "Friendly" then return false end

    -- Distance check
    local localChar = LocalPlayer.Character
    if localChar and localChar:FindFirstChild("HumanoidRootPart") then
        local rootPart = gameChar.Character and gameChar.Character.RootPart
        if rootPart then
            local dist = (rootPart.Position - localChar.HumanoidRootPart.Position).Magnitude
            if dist > settings.espMaxDistance then return false end
        end
    end
    return true
end

for _, gameChar in ipairs(m_GameCharacterController.GetGameCharacters()) do
    CreateESPForChar(gameChar)
end
m_GameCharacterController.GameCharacterAdded:Connect(CreateESPForChar)

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Filled = false
fovCircle.Transparency = 0.8
fovCircle.NumSides = 64
fovCircle.Visible = false

-- Target Highlight
local currentHighlight = nil
local lastTarget = nil

local function ClearHighlight()
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
    lastTarget = nil
end

local function ApplyHighlight(model)
    if lastTarget == model then return end
    ClearHighlight()
    local h = Instance.new("Highlight")
    h.FillColor = Color3.fromRGB(255, 50, 50)
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0
    h.Adornee = model
    h.Parent = model
    currentHighlight = h
    lastTarget = model
end

-- Knife Tracers
local original_NewCaster = m_MadworkCaster.NewCaster
m_MadworkCaster.NewCaster = function(params)
    local caster = original_NewCaster(params)
    if settings.knifeTracers then
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color = Color3.fromRGB(255, 200, 0)
        line.Transparency = 0.3
        line.Visible = false
        local startPos = params.Position
        caster:OnUpdate(function()
            if not settings.knifeTracers then line.Visible = false return end
            local s, on1 = Camera:WorldToViewportPoint(startPos)
            local e, on2 = Camera:WorldToViewportPoint(caster.Position)
            line.From = Vector2.new(s.X, s.Y)
            line.To = Vector2.new(e.X, e.Y)
            line.Visible = on1 and on2
        end)
        caster:OnSolve(function() line:Remove() end)
    end
    return caster
end

-- Main render loop
RunService.Heartbeat:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    local viewportSize = Camera.ViewportSize
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

    -- FOV Circle
    fovCircle.Position = mousePos
    fovCircle.Radius = settings.fov
    fovCircle.Visible = settings.fovCircle

    -- Target Highlight
    if settings.targetHighlight then
        local head, _, gameChar = GetClosestHead()
        if gameChar and gameChar.Character and gameChar.Character.IsAlive then
            ApplyHighlight(gameChar.Character.Model)
        else
            ClearHighlight()
        end
    else
        ClearHighlight()
    end

    -- ESP
    for gameChar, esp in pairs(espObjects) do
        local show = ShouldShowESP(gameChar)
        local char = gameChar.Character
        local alive = char and char.IsAlive

        if not show or not alive then
            for _, d in pairs(esp) do d.Visible = false end
            continue
        end

        local model = char.Model
        local rootPart = model:FindFirstChild("HumanoidRootPart")
        local headPart = model:FindFirstChild("Head")
        local humanoid = model:FindFirstChild("Humanoid")
        if not rootPart or not headPart then
            for _, d in pairs(esp) do d.Visible = false end
            continue
        end

        local topWorld = headPart.Position + Vector3.new(0, headPart.Size.Y / 2, 0)
        local botWorld = rootPart.Position - Vector3.new(0, 3.5, 0)
        local topScreen, onScreen1 = Camera:WorldToViewportPoint(topWorld)
        local botScreen, onScreen2 = Camera:WorldToViewportPoint(botWorld)

        if not onScreen1 or not onScreen2 then
            for _, d in pairs(esp) do d.Visible = false end
            continue
        end

        local color = GetCharColor(gameChar)
        local hp = gameChar.DamageReceiver and gameChar.DamageReceiver.Health or 0
        local maxHp = gameChar.DamageReceiver and gameChar.DamageReceiver.MaxHealth or 100
        local hpFrac = math.clamp(hp / maxHp, 0, 1)
        local hpColor = Color3.fromRGB(255 * (1 - hpFrac), 255 * hpFrac, 0)

        local height = math.abs(topScreen.Y - botScreen.Y)
        local width = height * 0.5
        local boxX = topScreen.X - width / 2
        local boxY = topScreen.Y

        -- Distance
        local dist = localRoot and math.floor((rootPart.Position - localRoot.Position).Magnitude) or 0

        -- Label: Name | Distance | HP all on one line
        local labelParts = {}
        if settings.espNames then table.insert(labelParts, gameChar.Player.Name) end
        if settings.espDistance then table.insert(labelParts, dist .. "m") end
        if settings.espHealth then table.insert(labelParts, math.floor(hp) .. "hp") end
        esp.label.Text = table.concat(labelParts, " | ")
        esp.label.Position = Vector2.new(topScreen.X, boxY - 18)
        esp.label.Color = color
        esp.label.Visible = #labelParts > 0

        -- Box outline
        if settings.espBoxes then
            esp.boxOutline.Size = Vector2.new(width + 2, height + 2)
            esp.boxOutline.Position = Vector2.new(boxX - 1, boxY - 1)
            esp.boxOutline.Visible = true
            esp.box.Size = Vector2.new(width, height)
            esp.box.Position = Vector2.new(boxX, boxY)
            esp.box.Color = color
            esp.box.Visible = true
        else
            esp.box.Visible = false
            esp.boxOutline.Visible = false
        end

        -- Health bar
        local barX = boxX - 6
        esp.healthBarBg.Size = Vector2.new(4, height)
        esp.healthBarBg.Position = Vector2.new(barX, boxY)
        esp.healthBarBg.Visible = settings.espHealth
        local barH = height * hpFrac
        esp.healthBar.Size = Vector2.new(4, barH)
        esp.healthBar.Position = Vector2.new(barX, boxY + (height - barH))
        esp.healthBar.Color = hpColor
        esp.healthBar.Visible = settings.espHealth

        -- Tracer
        if settings.espTracers then
            esp.tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
            esp.tracer.To = Vector2.new(botScreen.X, botScreen.Y)
            esp.tracer.Color = color
            esp.tracer.Visible = true
        else
            esp.tracer.Visible = false
        end
    end
end)

-- Venyx UI
local Venyx = loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/Venyx-UI-Library/main/source2.lua"))()
local UI = Venyx.new({ title = "SHARP" })

local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

if UIS.TouchEnabled then
    task.wait(1)

    local venyxGui
    for _,v in pairs(CoreGui:GetChildren()) do
        if v:IsA("ScreenGui") and v.Name:lower():find("venyx") then
            venyxGui = v
            break
        end
    end

    if venyxGui then
        local mainFrame = venyxGui:FindFirstChildWhichIsA("Frame", true)

        -- DRAG MAIN WINDOW
        local dragging = false
        local dragStart
        local startPos

        mainFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = mainFrame.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        UIS.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                mainFrame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)

        -- FLOATING TOGGLE BUTTON
        local toggleGui = Instance.new("ScreenGui")
        toggleGui.Name = "SharpMobileToggle"
        toggleGui.ResetOnSpawn = false
        toggleGui.Parent = CoreGui

        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0,70,0,70)
        toggle.Position = UDim2.new(0,60,0.5,0)
        toggle.BackgroundColor3 = Color3.fromRGB(30,30,30)
        toggle.Text = "SHARP"
        toggle.TextScaled = true
        toggle.TextColor3 = Color3.new(1,1,1)
        toggle.Parent = toggleGui

        Instance.new("UICorner", toggle).CornerRadius = UDim.new(1,0)

        -- DRAG BUTTON
        local btnDragging = false
        local btnStart
        local btnPos

        toggle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                btnDragging = true
                btnStart = input.Position
                btnPos = toggle.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        btnDragging = false
                    end
                end)
            end
        end)

        UIS.InputChanged:Connect(function(input)
            if btnDragging and input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - btnStart
                toggle.Position = UDim2.new(
                    btnPos.X.Scale,
                    btnPos.X.Offset + delta.X,
                    btnPos.Y.Scale,
                    btnPos.Y.Offset + delta.Y
                )
            end
        end)

        -- OPEN / CLOSE MENU
        local opened = true
        toggle.Activated:Connect(function()
            opened = not opened
            mainFrame.Visible = opened
        end)
    end
end

local CombatPage = UI:addPage({ title = "Combat", icon = 5012544693 })
local VisualPage = UI:addPage({ title = "Visuals", icon = 5012544693 })

local Aimbot = CombatPage:addSection({ title = "Aimbot" })
local Combat = CombatPage:addSection({ title = "Combat" })
local ESPSection = VisualPage:addSection({ title = "ESP" })
local ESPToggles = VisualPage:addSection({ title = "ESP Options" })
local ESPColors = VisualPage:addSection({ title = "ESP Colors" })
local WorldSection = VisualPage:addSection({ title = "World" })

-- Aimbot
Aimbot:addToggle({ title = "Silent Aim", callback = function(v) settings.silentAim = v end })
Aimbot:addToggle({ title = "Triggerbot (Knife)", callback = function(v) settings.triggerBot = v end })
Aimbot:addToggle({ title = "Auto Shoot (Knife)", callback = function(v) settings.autoShoot = v end })
Aimbot:addToggle({ title = "Max Charge", callback = function(v) settings.maxCharge = v end })
Aimbot:addSlider({ title = "FOV", default = 200, min = 50, max = 600, callback = function(v) settings.fov = v end })

-- Combat
Combat:addToggle({ title = "Instant Fire Rate", callback = function(v)
    settings.instantFireRate = v
    if v then patched = {} end
end })
Combat:addToggle({ title = "Infinite Ammo", callback = function(v) settings.infiniteAmmo = v end })
Combat:addButton({ title = "Throw At Target Now", callback = function() TryFire() end })

-- ESP Main
ESPSection:addToggle({ title = "Enable ESP", callback = function(v) settings.espEnabled = v end })
ESPSection:addToggle({ title = "Enemy Only", callback = function(v)
    settings.espEnemyOnly = v
    if v then settings.espTeamOnly = false end
end })
ESPSection:addToggle({ title = "Team Only", callback = function(v)
    settings.espTeamOnly = v
    if v then settings.espEnemyOnly = false end
end })
ESPSection:addSlider({ title = "Max Distance", default = 1000, min = 50, max = 2000, callback = function(v)
    settings.espMaxDistance = v
end })

-- ESP Toggles
ESPToggles:addToggle({ title = "Boxes", callback = function(v) settings.espBoxes = v end })
ESPToggles:addToggle({ title = "Names", callback = function(v) settings.espNames = v end })
ESPToggles:addToggle({ title = "Distance", callback = function(v) settings.espDistance = v end })
ESPToggles:addToggle({ title = "Health", callback = function(v) settings.espHealth = v end })
ESPToggles:addToggle({ title = "Tracers", callback = function(v) settings.espTracers = v end })

-- ESP Colors
ESPColors:addColorPicker({ title = "Enemy Color", default = Color3.fromRGB(255, 50, 50), callback = function(v)
    settings.espEnemyColor = v
end })
ESPColors:addColorPicker({ title = "Team Color", default = Color3.fromRGB(50, 255, 50), callback = function(v)
    settings.espTeamColor = v
end })

-- World
WorldSection:addToggle({ title = "FOV Circle", callback = function(v) settings.fovCircle = v end })
WorldSection:addColorPicker({ title = "FOV Color", default = Color3.fromRGB(255,255,255), callback = function(v)
    fovCircle.Color = v
end })
WorldSection:addToggle({ title = "Target Highlight", callback = function(v)
    settings.targetHighlight = v
    if not v then ClearHighlight() end
end })
WorldSection:addToggle({ title = "Knife Tracers", callback = function(v) settings.knifeTracers = v end })
WorldSection:addColorPicker({ title = "Knife Tracer Color", default = Color3.fromRGB(255,200,0), callback = function(v)
    -- stored for new tracers
    settings.knifeTracerColor = v
end })

UI:SelectPage({ page = UI.pages[1], toggle = true })
