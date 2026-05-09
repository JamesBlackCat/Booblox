--[[
    AnimationStudio.lua
    Place as a LocalScript inside StarterCharacterScripts

    PURPOSE:
    This script hooks into Roblox's built-in Animate LocalScript and replaces
    the animation IDs for each animation state (Idle, Walk, Run, Jump, etc.)
    with custom ones chosen by the user. The Roblox animation system (blending,
    transitions, state machine) remains completely intact — we only swap the IDs.

    FEATURES:
    - Draggable floating toggle button (snaps to edge)
    - Home tab: per-slot animation replacement with full link support
    - Packs tab: save/load animation sets
    - Emotes tab: play emotes instantly, float them on screen
    - Explorer tab: scan scripts and Animation objects in Workspace
    - Editor tab: isolated studio room, timeline, keyframes, undo/redo
    - Supports: Roblox links, rbxassetid://, raw IDs
    - Auto-detects Packs and warns instead of importing
    - DataStore save/load with auto-save
    - Dynamic playback speed scaling (Walk/Run/Swim)
    - R6 + R15 compatible
    - Mobile + PC compatible
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local DataStoreService  = game:GetService("DataStoreService")

local LocalPlayer   = Players.LocalPlayer
local PlayerGui     = LocalPlayer:WaitForChild("PlayerGui")
local Camera        = workspace.CurrentCamera

-- ============================================================
-- WAIT FOR CHARACTER
-- ============================================================
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid  = Character:WaitForChild("Humanoid")
local HRP       = Character:WaitForChild("HumanoidRootPart")

-- The built-in Animate script Roblox puts in every character
local AnimateScript = Character:WaitForChild("Animate", 10)

-- ============================================================
-- CONSTANTS
-- ============================================================
local VERSION        = "2.0"
local SAVE_KEY       = "AnimStudio_v2_" .. LocalPlayer.UserId
local AUTOSAVE_DELAY = 30

--[[
    Slot -> path inside the Animate script
    These are the animation objects Roblox uses internally.
    We modify their AnimationId to replace animations.
]]
local SLOT_MAP = {
    Idle    = {"idle",  {"Animation1", "Animation2"}},
    Walk    = {"walk",  {"WalkAnim"}},
    Run     = {"run",   {"RunAnim"}},
    Jump    = {"jump",  {"JumpAnim"}},
    Fall    = {"fall",  {"FallAnim"}},
    Swim    = {"swim",  {"Swim"}},
    Float   = {"swimidle", {"SwimIdle"}},
    Climb   = {"climb", {"ClimbAnim"}},
    Sit     = {"sit",   {"SitAnim"}},
    Land    = {"land",  {"LandAnim"}},
    Emote   = {"emote", {}},
}

local SLOT_NAMES = {"Idle","Walk","Run","Jump","Fall","Swim","Float","Climb","Sit","Land"}

local DEFAULT_IDS = {
    Idle  = "507766388",
    Walk  = "507777826",
    Run   = "507767714",
    Jump  = "507765000",
    Fall  = "507767968",
    Swim  = "507784897",
    Float = "507770453",
    Climb = "507765644",
    Sit   = "2506281703",
    Land  = "507768817",
}

local THEME = {
    Bg          = Color3.fromRGB(14, 14, 20),
    Surface     = Color3.fromRGB(22, 22, 32),
    Card        = Color3.fromRGB(30, 30, 44),
    Border      = Color3.fromRGB(55, 55, 78),
    Accent      = Color3.fromRGB(99, 102, 241),
    AccentHov   = Color3.fromRGB(129, 132, 255),
    AccentDark  = Color3.fromRGB(67, 70, 190),
    Success     = Color3.fromRGB(34, 197, 94),
    Warning     = Color3.fromRGB(234, 179, 8),
    Danger      = Color3.fromRGB(239, 68, 68),
    Text        = Color3.fromRGB(235, 235, 255),
    TextSub     = Color3.fromRGB(155, 155, 185),
    TextMuted   = Color3.fromRGB(90, 90, 120),
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    UIOpen       = false,
    ActiveTab    = "Home",
    SelectedSlot = "Idle",
    CustomAnims  = {},      -- slot -> animId string (just the number)
    Packs        = {},      -- list of {name, folder, anims={}}
    Emotes       = {},      -- list of {id, name, favorited}
    FloatEmotes  = {},      -- live floating buttons
    UndoStack    = {},
    RedoStack    = {},
    EditorOpen   = false,
    EditorDirty  = false,
    PlaybackMode = "Dynamic",
    PlaybackMult = 1.0,
    Keyframes    = {},
    StudioModel  = nil,
    ClonedChar   = nil,
    OrigCFrame   = nil,
    IsEditing    = false,
    IsPlaying    = false,
    EditTime     = 0,
}

for _, slot in ipairs(SLOT_NAMES) do
    State.CustomAnims[slot] = ""
end

-- ============================================================
-- ANIMATION REPLACEMENT (CORE)
-- ============================================================

--[[
    applyAnimation(slot, animId)
    Replaces the animation ID inside the Roblox Animate script for
    the given slot. The existing Roblox animation state machine keeps
    running — we only update the ID so next time it plays, it uses ours.
]]
local function applyAnimation(slot, animId)
    if not AnimateScript then return false end

    local mapping = SLOT_MAP[slot]
    if not mapping then return false end

    local folder = AnimateScript:FindFirstChild(mapping[1])
    if not folder then return false end

    local applied = false
    for _, animName in ipairs(mapping[2]) do
        local animObj = folder:FindFirstChild(animName)
        if animObj and animObj:IsA("Animation") then
            animObj.AnimationId = "rbxassetid://" .. animId
            applied = true
        end
    end

    -- Also stop current playing tracks so new ID takes effect immediately
    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local id = track.Animation.AnimationId:match("%d+")
            if id == DEFAULT_IDS[slot] or
               (State.CustomAnims[slot] ~= "" and id == State.CustomAnims[slot]) then
                track:Stop(0.2)
            end
        end
    end

    return applied
end

--[[
    applyAllAnimations()
    Re-applies every saved custom animation ID on respawn or reload.
]]
local function applyAllAnimations()
    for slot, animId in pairs(State.CustomAnims) do
        if animId and animId ~= "" then
            applyAnimation(slot, animId)
        end
    end
end

-- Re-apply on character respawn
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character    = newChar
    Humanoid     = newChar:WaitForChild("Humanoid")
    HRP          = newChar:WaitForChild("HumanoidRootPart")
    AnimateScript= newChar:WaitForChild("Animate", 10)
    task.wait(1)
    applyAllAnimations()
end)

-- ============================================================
-- LINK / ID PARSER
-- ============================================================
local function extractId(input)
    if not input or input == "" then return nil end
    input = tostring(input):gsub("^%s+", ""):gsub("%s+$", "")

    local fromRbx    = input:match("rbxassetid://(%d+)")
    if fromRbx then return fromRbx end

    local fromRoblox = input:match("roblox%.com/[^/]+/(%d+)")
    if fromRoblox then return fromRoblox end

    local fromCreate = input:match("create%.roblox%.com/store/asset/(%d+)")
    if fromCreate then return fromCreate end

    if input:match("^%d+$") then return input end

    return nil
end

local function detectInputType(rawInput)
    local lower = rawInput:lower()
    if lower:find("pack") or lower:find("bundle") or lower:find("collection") then
        return "Pack"
    elseif lower:find("emote") or lower:find("dance") or lower:find("wave") then
        return "Emote"
    elseif lower:find("model") then
        return "Model"
    end
    return "Animation"
end

-- ============================================================
-- SAVE / LOAD
-- ============================================================
local DataStore
pcall(function()
    DataStore = DataStoreService:GetDataStore("AnimStudio_v2")
end)

local function doSave()
    if not DataStore then return end
    local ok, err = pcall(function()
        DataStore:SetAsync(SAVE_KEY, HttpService:JSONEncode({
            CustomAnims  = State.CustomAnims,
            Packs        = State.Packs,
            Emotes       = State.Emotes,
            PlaybackMode = State.PlaybackMode,
            PlaybackMult = State.PlaybackMult,
        }))
    end)
    if not ok then warn("[AnimStudio] Save error:", err) end
end

local function doLoad()
    if not DataStore then return end
    local ok, raw = pcall(function()
        return DataStore:GetAsync(SAVE_KEY)
    end)
    if ok and raw then
        local d = HttpService:JSONDecode(raw)
        if d.CustomAnims  then for k,v in pairs(d.CustomAnims) do State.CustomAnims[k]=v end end
        if d.Packs        then State.Packs        = d.Packs        end
        if d.Emotes       then State.Emotes       = d.Emotes       end
        if d.PlaybackMode then State.PlaybackMode = d.PlaybackMode end
        if d.PlaybackMult then State.PlaybackMult = d.PlaybackMult end
    end
end

-- Auto-save loop
task.spawn(function()
    while true do
        task.wait(AUTOSAVE_DELAY)
        doSave()
    end
end)

-- ============================================================
-- UNDO / REDO
-- ============================================================
local function pushUndo(action)
    table.insert(State.UndoStack, action)
    if #State.UndoStack > 50 then table.remove(State.UndoStack, 1) end
    State.RedoStack = {}
end

local function doUndo()
    if #State.UndoStack == 0 then return end
    local a = table.remove(State.UndoStack)
    table.insert(State.RedoStack, a)
    if a.undo then a.undo() end
end

local function doRedo()
    if #State.RedoStack == 0 then return end
    local a = table.remove(State.RedoStack)
    table.insert(State.UndoStack, a)
    if a.redo then a.redo() end
end

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if inp.KeyCode == Enum.KeyCode.Z then doUndo() end
        if inp.KeyCode == Enum.KeyCode.Y then doRedo() end
    end
end)

-- ============================================================
-- DYNAMIC PLAYBACK SPEED
-- ============================================================
local dynamicSlots = {Walk=true, Run=true, Swim=true}

RunService.Heartbeat:Connect(function()
    if not Humanoid or not HRP then return end

    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local vel     = HRP.Velocity
    local hSpeed  = Vector3.new(vel.X, 0, vel.Z).Magnitude
    local wsMax   = math.max(Humanoid.WalkSpeed, 1)
    local ratio   = math.clamp(hSpeed / wsMax, 0.5, 2.5) * State.PlaybackMult

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        -- Find which slot this track belongs to
        local trackId = track.Animation.AnimationId:match("%d+")
        local isMovement = false
        for slot, _ in pairs(dynamicSlots) do
            local custom = State.CustomAnims[slot]
            if custom ~= "" and trackId == custom then isMovement = true break end
            if trackId == DEFAULT_IDS[slot] then isMovement = true break end
        end

        if State.PlaybackMode == "Dynamic" and isMovement then
            track:AdjustSpeed(ratio)
        elseif State.PlaybackMode == "Static" then
            track:AdjustSpeed(State.PlaybackMult)
        end
    end
end)

-- ============================================================
-- UI HELPERS
-- ============================================================
local function vp() return Camera.ViewportSize end

local function tween(obj, props, t, style, dir)
    local ti = TweenInfo.new(t or 0.2,
        style or Enum.EasingStyle.Quad,
        dir   or Enum.EasingDirection.Out)
    TweenService:Create(obj, ti, props):Play()
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local function stroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color     = col or THEME.Border
    s.Thickness = th  or 1
    s.Parent    = p
end

local function pad(p, t, r, b, l)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 8)
    u.PaddingRight  = UDim.new(0, r or 8)
    u.PaddingBottom = UDim.new(0, b or 8)
    u.PaddingLeft   = UDim.new(0, l or 8)
    u.Parent = p
end

local function frame(parent, size, pos, color, name)
    local f = Instance.new("Frame")
    f.Size             = size  or UDim2.new(1,0,1,0)
    f.Position         = pos   or UDim2.new(0,0,0,0)
    f.BackgroundColor3 = color or THEME.Surface
    f.BorderSizePixel  = 0
    f.Name             = name  or "Frame"
    f.Parent           = parent
    return f
end

local function label(parent, text, size, pos, color, fs, name)
    local l = Instance.new("TextLabel")
    l.Size             = size  or UDim2.new(1,0,0,24)
    l.Position         = pos   or UDim2.new(0,0,0,0)
    l.BackgroundTransparency = 1
    l.TextColor3       = color or THEME.Text
    l.TextSize         = fs    or 14
    l.Font             = Enum.Font.GothamMedium
    l.Text             = text  or ""
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.TextWrapped      = true
    l.Name             = name  or "Label"
    l.Parent           = parent
    return l
end

local function btn(parent, text, size, pos, color, name)
    local b = Instance.new("TextButton")
    b.Size             = size  or UDim2.new(1,0,0,36)
    b.Position         = pos   or UDim2.new(0,0,0,0)
    b.BackgroundColor3 = color or THEME.Accent
    b.TextColor3       = THEME.Text
    b.TextSize         = 14
    b.Font             = Enum.Font.GothamBold
    b.Text             = text  or "Button"
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.Name             = name  or "Button"
    corner(b, 8)
    local origColor = color or THEME.Accent
    b.MouseEnter:Connect(function()
        tween(b, {BackgroundColor3 = THEME.AccentHov}, 0.12)
    end)
    b.MouseLeave:Connect(function()
        tween(b, {BackgroundColor3 = origColor}, 0.12)
    end)
    b.Parent = parent
    return b
end

local function textbox(parent, placeholder, size, pos, name)
    local t = Instance.new("TextBox")
    t.Size                = size        or UDim2.new(1,0,0,36)
    t.Position            = pos         or UDim2.new(0,0,0,0)
    t.BackgroundColor3    = THEME.Card
    t.TextColor3          = THEME.Text
    t.PlaceholderColor3   = THEME.TextMuted
    t.PlaceholderText     = placeholder or ""
    t.TextSize            = 14
    t.Font                = Enum.Font.Gotham
    t.Text                = ""
    t.BorderSizePixel      = 0
    t.ClearTextOnFocus    = false
    t.Name                = name        or "TextBox"
    corner(t, 8)
    stroke(t, THEME.Border, 1)
    pad(t, 0, 10, 0, 10)
    t.Parent = parent
    return t
end

local function scroll(parent, size, pos, name)
    local s = Instance.new("ScrollingFrame")
    s.Size                   = size or UDim2.new(1,0,1,0)
    s.Position               = pos  or UDim2.new(0,0,0,0)
    s.BackgroundTransparency = 1
    s.BorderSizePixel        = 0
    s.ScrollBarThickness     = 4
    s.ScrollBarImageColor3   = THEME.Accent
    s.CanvasSize             = UDim2.new(0,0,0,0)
    s.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    s.Name                   = name or "Scroll"
    s.Parent                 = parent
    return s
end

local function listLayout(parent, padding, dir)
    local l = Instance.new("UIListLayout")
    l.Padding           = UDim.new(0, padding or 6)
    l.FillDirection     = dir or Enum.FillDirection.Vertical
    l.SortOrder         = Enum.SortOrder.LayoutOrder
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.Parent            = parent
    return l
end

local function gridLayout(parent, cellSize, cellPad)
    local g = Instance.new("UIGridLayout")
    g.CellSize        = cellSize or UDim2.new(0,110,0,110)
    g.CellPaddingSize = cellPad  or UDim2.new(0,8,0,8)
    g.SortOrder       = Enum.SortOrder.LayoutOrder
    g.Parent          = parent
end

-- ============================================================
-- DRAGGABLE
-- ============================================================
local function makeDraggable(handle, target, onReleased)
    local dragging = false
    local startMouse, startPos

    local function pos(input)
        return Vector2.new(input.Position.X, input.Position.Y)
    end

    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or
           inp.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            startMouse = pos(inp)
            startPos   = target.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or
           inp.UserInputType == Enum.UserInputType.Touch then
            local delta = pos(inp) - startMouse
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or
           inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if onReleased then onReleased() end
        end
    end)
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
local GUI = Instance.new("ScreenGui")
GUI.Name           = "AnimationStudio"
GUI.ResetOnSpawn   = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.IgnoreGuiInset = true
GUI.Parent         = PlayerGui

-- ============================================================
-- NOTIFICATION
-- ============================================================
local NotifContainer = frame(GUI, UDim2.new(0,320,0.6,0), UDim2.new(1,-334,0.4,0), THEME.Bg, "Notifs")
NotifContainer.BackgroundTransparency = 1
NotifContainer.ZIndex = 30
listLayout(NotifContainer, 6)

local function notify(msg, kind, dur)
    dur  = dur  or 3.5
    kind = kind or "info"
    local col = kind=="success" and THEME.Success
             or kind=="warning" and THEME.Warning
             or kind=="error"   and THEME.Danger
             or THEME.Accent

    local n = frame(NotifContainer, UDim2.new(1,-8,0,56), UDim2.new(0,4,0,0), THEME.Card, "Notif")
    n.ZIndex = 31
    corner(n, 10)
    stroke(n, col, 2)
    n.LayoutOrder = tick()

    local dot = label(n, "●", UDim2.new(0,18,1,0), UDim2.new(0,8,0,0), col, 18, "Dot")
    dot.TextXAlignment = Enum.TextXAlignment.Center
    local lbl = label(n, msg, UDim2.new(1,-34,1,0), UDim2.new(0,28,0,0), THEME.Text, 13, "Msg")
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true

    n.Position = UDim2.new(1, 10, 0, 0)
    tween(n, {Position = UDim2.new(0,4,0,0)}, 0.3)
    task.delay(dur, function()
        tween(n, {Position = UDim2.new(1,10,0,0)}, 0.25)
        task.wait(0.3)
        pcall(function() n:Destroy() end)
    end)
end

-- ============================================================
-- CONFIRM DIALOG
-- ============================================================
local function confirm(title, msg, onSave, onDiscard)
    local ov = frame(GUI, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.new(0,0,0), "Overlay")
    ov.BackgroundTransparency = 0.45
    ov.ZIndex = 40

    local dlg = frame(GUI, UDim2.new(0,380,0,192), UDim2.new(0.5,-190,0.5,-96), THEME.Surface, "Dlg")
    dlg.ZIndex = 41
    corner(dlg, 12)
    stroke(dlg, THEME.Border, 1)
    pad(dlg, 18,18,18,18)

    local t = label(dlg, title, UDim2.new(1,0,0,28), UDim2.new(0,0,0,0), THEME.Accent, 17, "T")
    t.Font = Enum.Font.GothamBold
    local m = label(dlg, msg,   UDim2.new(1,0,0,42), UDim2.new(0,0,0,32), THEME.Text, 14, "M")
    m.TextWrapped = true

    local function cleanup() ov:Destroy() dlg:Destroy() end

    local bRow = frame(dlg, UDim2.new(1,0,0,36), UDim2.new(0,0,1,-36), THEME.Surface)
    bRow.BackgroundTransparency = 1

    local sv = btn(bRow, "Save",    UDim2.new(0,100,1,0), UDim2.new(0,0,0,0),   THEME.Success)
    local di = btn(bRow, "Discard", UDim2.new(0,100,1,0), UDim2.new(0,108,0,0), THEME.Danger)
    local ca = btn(bRow, "Cancel",  UDim2.new(0,100,1,0), UDim2.new(0,216,0,0), THEME.Card)

    sv.MouseButton1Click:Connect(function() cleanup() if onSave    then onSave()    end end)
    di.MouseButton1Click:Connect(function() cleanup() if onDiscard then onDiscard() end end)
    ca.MouseButton1Click:Connect(function() cleanup() end)
end

-- ============================================================
-- ASSET INSPECT CARD
-- ============================================================
local function inspectCard(rawInput, onImport)
    local id = extractId(rawInput)

    local ov = frame(GUI, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.new(0,0,0), "Overlay")
    ov.BackgroundTransparency = 0.45
    ov.ZIndex = 35

    local card = frame(GUI, UDim2.new(0,430,0,290), UDim2.new(0.5,-215,0.5,-145), THEME.Surface, "Card")
    card.ZIndex = 36
    corner(card, 14)
    stroke(card, THEME.Border, 1)
    pad(card, 18,18,18,18)

    local function close() ov:Destroy() card:Destroy() end

    label(card, "Asset Inspector", UDim2.new(1,0,0,28), UDim2.new(0,0,0,0), THEME.Accent, 17, "H").Font = Enum.Font.GothamBold

    if not id then
        label(card, "Could not extract a valid Asset ID from input.\nMake sure it is a Roblox link or a numeric ID.",
            UDim2.new(1,0,0,54), UDim2.new(0,0,0,34), THEME.Danger, 13, "Err").TextWrapped = true
        btn(card, "Close", UDim2.new(1,0,0,36), UDim2.new(0,0,1,-36), THEME.Danger).MouseButton1Click:Connect(close)
        return
    end

    local inputType = detectInputType(rawInput)
    local inputFmt  = rawInput:find("roblox%.com") and "Roblox URL"
                   or rawInput:find("rbxassetid")  and "rbxassetid://"
                   or "Numeric ID"

    local rows = {
        {"Extracted ID:",  id},
        {"Input Format:",  inputFmt},
        {"Detected Type:", inputType},
    }
    for i, r in ipairs(rows) do
        label(card, r[1], UDim2.new(0.44,0,0,22), UDim2.new(0,0,0,34+(i-1)*28), THEME.TextSub, 13)
        label(card, r[2], UDim2.new(0.54,0,0,22), UDim2.new(0.44,0,0,34+(i-1)*28), THEME.Text, 13)
    end

    if inputType == "Pack" then
        local w = label(card,
            "⚠  This looks like an Animation PACK.\n"..
            "This system imports single animations only.\n"..
            "To use a pack, import each animation ID separately.",
            UDim2.new(1,0,0,60), UDim2.new(0,0,0,122), THEME.Warning, 13, "Warn")
        w.TextWrapped = true
        btn(card, "OK — Got it", UDim2.new(1,0,0,36), UDim2.new(0,0,1,-36), THEME.Danger).MouseButton1Click:Connect(close)
    else
        local imp = btn(card, "✔  Import to Slot: "..State.SelectedSlot,
            UDim2.new(0.58,0,0,36), UDim2.new(0,0,1,-36), THEME.Success)
        local can = btn(card, "Cancel",
            UDim2.new(0.38,0,0,36), UDim2.new(0.62,0,1,-36), THEME.Danger)

        imp.MouseButton1Click:Connect(function()
            close()
            if onImport then onImport(id, inputType) end
        end)
        can.MouseButton1Click:Connect(close)
    end
end

-- ============================================================
-- TOGGLE BUTTON
-- ============================================================
local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Name             = "StudioToggle"
ToggleBtn.Size             = UDim2.new(0, 58, 0, 58)
ToggleBtn.Position         = UDim2.new(0, 14, 0.5, -29)
ToggleBtn.BackgroundColor3 = THEME.Accent
ToggleBtn.Image            = "rbxassetid://7059346373"
ToggleBtn.ImageColor3      = Color3.new(1,1,1)
ToggleBtn.ImageTransparency= 0.05
ToggleBtn.ZIndex           = 10
corner(ToggleBtn, 18)
ToggleBtn.Parent = GUI

ToggleBtn.MouseEnter:Connect(function()
    tween(ToggleBtn, {BackgroundColor3 = THEME.AccentHov, Size = UDim2.new(0,62,0,62)}, 0.12)
end)
ToggleBtn.MouseLeave:Connect(function()
    tween(ToggleBtn, {BackgroundColor3 = THEME.Accent, Size = UDim2.new(0,58,0,58)}, 0.12)
end)

-- Snap to edges on release
makeDraggable(ToggleBtn, ToggleBtn, function()
    local vSize = vp()
    local ap    = ToggleBtn.AbsolutePosition
    local as    = ToggleBtn.AbsoluteSize
    local cx    = ap.X + as.X / 2
    if cx < vSize.X / 2 then
        tween(ToggleBtn, {Position = UDim2.new(0, 12, 0, ap.Y)}, 0.2)
    else
        tween(ToggleBtn, {Position = UDim2.new(0, vSize.X - as.X - 12, 0, ap.Y)}, 0.2)
    end
end)

-- ============================================================
-- MAIN WINDOW
-- ============================================================
local Win = frame(GUI,
    UDim2.new(0, 880, 0, 600),
    UDim2.new(0.5, -440, 0.5, -300),
    THEME.Bg, "MainWindow")
Win.Visible = false
Win.ZIndex  = 5
corner(Win, 14)
stroke(Win, THEME.Border, 1)

-- Title bar
local TitleBar = frame(Win, UDim2.new(1,0,0,50), UDim2.new(0,0,0,0), THEME.Surface, "TitleBar")
corner(TitleBar, 14)
frame(TitleBar, UDim2.new(1,0,0.5,0), UDim2.new(0,0,0.5,0), THEME.Surface, "Fill")  -- cover bottom corners
local TitleLbl = label(TitleBar, "  ✦ Animation Studio  v"..VERSION,
    UDim2.new(1,-80,1,0), UDim2.new(0,0,0,0), THEME.Accent, 16, "Title")
TitleLbl.Font = Enum.Font.GothamBold
local CloseWin = btn(TitleBar, "✕", UDim2.new(0,36,0,36), UDim2.new(1,-42,0,7), THEME.Danger, "CloseBtn")
CloseWin.TextSize = 15
makeDraggable(TitleBar, Win)

-- Tab bar
local TabBar = frame(Win, UDim2.new(1,0,0,44), UDim2.new(0,0,0,50), THEME.Surface, "TabBar")
local TABS   = {"Home","Packs","Emotes","Explorer","Editor"}
local TabBtns = {}
local tW = 1 / #TABS
for i, name in ipairs(TABS) do
    local b = btn(TabBar, name,
        UDim2.new(tW,-6,1,-8),
        UDim2.new((i-1)*tW+0.005,0,0,4),
        THEME.Card, "Tab_"..name)
    b.TextSize = 13
    stroke(b, THEME.Border, 1)
    TabBtns[name] = b
end

-- Content
local ContentArea = frame(Win, UDim2.new(1,0,1,-98), UDim2.new(0,0,0,94), THEME.Bg, "Content")

-- Status bar
local StatusBar = frame(Win, UDim2.new(1,0,0,22), UDim2.new(0,0,1,-22), THEME.Surface, "Status")
local StatusLbl = label(StatusBar, "  Ready", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), THEME.TextMuted, 12, "StatusLbl")
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

local function setStatus(s) StatusLbl.Text = "  " .. s end

-- ============================================================
-- PANELS
-- ============================================================
local Panels = {}
for _, name in ipairs(TABS) do
    local p = frame(ContentArea, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), THEME.Bg, "Panel_"..name)
    p.Visible = false
    Panels[name] = p
end

local function switchTab(name)
    State.ActiveTab = name
    for n, p in pairs(Panels) do p.Visible = (n == name) end
    for n, b in pairs(TabBtns) do
        b.BackgroundColor3 = (n == name) and THEME.Accent or THEME.Card
    end
    setStatus("Tab: "..name)
end

for _, name in ipairs(TABS) do
    TabBtns[name].MouseButton1Click:Connect(function() switchTab(name) end)
end

-- ============================================================
-- HOME TAB
-- ============================================================
local HP = Panels["Home"]

-- Left: slot list
local SlotPanel = frame(HP, UDim2.new(0,210,1,-12), UDim2.new(0,6,0,6), THEME.Surface, "SlotPanel")
corner(SlotPanel, 10)
stroke(SlotPanel, THEME.Border, 1)

label(SlotPanel, "Animation Slots",
    UDim2.new(1,-12,0,26), UDim2.new(0,6,0,6), THEME.Accent, 14, "SlotH").Font = Enum.Font.GothamBold

local SlotScroll = scroll(SlotPanel, UDim2.new(1,-8,1,-40), UDim2.new(0,4,0,38), "SlotScroll")
listLayout(SlotScroll, 4)

-- Right: detail
local Detail = frame(HP, UDim2.new(1,-228,1,-12), UDim2.new(0,222,0,6), THEME.Surface, "Detail")
corner(Detail, 10)
stroke(Detail, THEME.Border, 1)
pad(Detail, 14,14,14,14)

local DTitle  = label(Detail, "Select a slot →", UDim2.new(1,0,0,30), UDim2.new(0,0,0,0), THEME.Text, 18, "DTitle")
DTitle.Font = Enum.Font.GothamBold
local DStatus = label(Detail, "", UDim2.new(1,0,0,22), UDim2.new(0,0,0,34), THEME.TextMuted, 13, "DStatus")
local DDefault= label(Detail, "", UDim2.new(1,0,0,20), UDim2.new(0,0,0,58), THEME.TextMuted, 12, "DDefault")

label(Detail, "Animation ID or Roblox Link:",
    UDim2.new(1,0,0,20), UDim2.new(0,0,0,84), THEME.TextSub, 13)
local IdBox = textbox(Detail, "Paste ID, rbxassetid://, or full Roblox link…",
    UDim2.new(1,0,0,36), UDim2.new(0,0,0,106), "IdBox")

-- Action row
local ActRow = frame(Detail, UDim2.new(1,0,0,36), UDim2.new(0,0,0,152), THEME.Bg)
ActRow.BackgroundTransparency = 1
local ImpBtn = btn(ActRow, "⬇  Import",   UDim2.new(0.33,-4,1,0), UDim2.new(0,0,0,0),        THEME.Success, "Import")
local PrvBtn = btn(ActRow, "▶  Preview",  UDim2.new(0.33,-4,1,0), UDim2.new(0.335,0,0,0),    THEME.Accent,  "Preview")
local RstBtn = btn(ActRow, "↺  Reset",    UDim2.new(0.33,-2,1,0), UDim2.new(0.670,2,0,0),    THEME.Danger,  "Reset")

-- Playback settings
label(Detail, "Playback Mode:", UDim2.new(0.48,0,0,20), UDim2.new(0,0,0,200), THEME.TextSub, 13)
local PbModeBtn = btn(Detail, "Mode: "..State.PlaybackMode,
    UDim2.new(0.5,0,0,30), UDim2.new(0.5,0,0,196), THEME.Card, "PbMode")
PbModeBtn.TextSize = 12

label(Detail, "Speed Multiplier:", UDim2.new(0.48,0,0,20), UDim2.new(0,0,0,238), THEME.TextSub, 13)
local SpeedBox = textbox(Detail, "1.0", UDim2.new(0.4,0,0,30), UDim2.new(0.55,0,0,234), "SpeedBox")
SpeedBox.Text = "1.0"

-- Slot refresh
local SlotBtns = {}

local function refreshDetail()
    local slot    = State.SelectedSlot
    local custom  = State.CustomAnims[slot]
    local hasCustom = custom and custom ~= ""

    DTitle.Text  = slot .. " Animation"
    DDefault.Text= "Default ID: " .. (DEFAULT_IDS[slot] or "N/A")

    if hasCustom then
        DStatus.Text       = "Custom Animation Active — ID: " .. custom
        DStatus.TextColor3 = THEME.Success
        IdBox.Text         = custom
    else
        DStatus.Text       = "Using Roblox Default Animation"
        DStatus.TextColor3 = THEME.TextMuted
        IdBox.Text         = ""
    end
end

for i, slot in ipairs(SLOT_NAMES) do
    local b = btn(SlotScroll, slot,
        UDim2.new(1,-8,0,40), UDim2.new(0,4,0,0), THEME.Card, "Slot_"..slot)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.LayoutOrder    = i
    pad(b, 0,0,0,12)
    SlotBtns[slot] = b

    b.MouseButton1Click:Connect(function()
        if SlotBtns[State.SelectedSlot] then
            SlotBtns[State.SelectedSlot].BackgroundColor3 = THEME.Card
        end
        State.SelectedSlot = slot
        b.BackgroundColor3 = THEME.AccentDark
        refreshDetail()
    end)
end

-- Import
ImpBtn.MouseButton1Click:Connect(function()
    local raw = IdBox.Text
    if raw == "" then notify("Enter an ID or link first.", "warning") return end
    inspectCard(raw, function(id, kind)
        local slot = State.SelectedSlot
        local old  = State.CustomAnims[slot]
        State.CustomAnims[slot] = id

        -- Apply immediately to Animate script
        local applied = applyAnimation(slot, id)
        pushUndo({
            undo = function()
                State.CustomAnims[slot] = old
                if old ~= "" then applyAnimation(slot, old)
                else applyAnimation(slot, DEFAULT_IDS[slot] or "") end
                refreshDetail()
            end,
            redo = function()
                State.CustomAnims[slot] = id
                applyAnimation(slot, id)
                refreshDetail()
            end,
        })
        refreshDetail()
        doSave()
        notify("Imported " .. kind .. " → " .. slot .. " (ID: "..id..")", "success")
        if not applied then
            notify("Note: Animate slot '"..slot.."' not found in character. Animation saved for next spawn.", "warning", 5)
        end
    end)
end)

-- Preview: play the animation track directly
PrvBtn.MouseButton1Click:Connect(function()
    local slot   = State.SelectedSlot
    local custom = State.CustomAnims[slot]
    local id     = (custom and custom ~= "") and custom or DEFAULT_IDS[slot]
    if not id then notify("No animation to preview.", "warning") return end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. id
    local ok, track = pcall(function() return Humanoid:LoadAnimation(anim) end)
    if ok and track then
        track:Play()
        notify("Previewing: "..slot.." — "..id, "info", 2)
    else
        notify("Could not load animation. Check the ID.", "error")
    end
end)

-- Reset
RstBtn.MouseButton1Click:Connect(function()
    local slot = State.SelectedSlot
    confirm("Reset Animation",
        "Reset '"..slot.."' back to the Roblox default animation?",
        function()
            local old = State.CustomAnims[slot]
            State.CustomAnims[slot] = ""
            applyAnimation(slot, DEFAULT_IDS[slot] or "")
            pushUndo({
                undo = function()
                    State.CustomAnims[slot] = old
                    if old ~= "" then applyAnimation(slot, old) end
                    refreshDetail()
                end,
                redo = function()
                    State.CustomAnims[slot] = ""
                    applyAnimation(slot, DEFAULT_IDS[slot] or "")
                    refreshDetail()
                end,
            })
            refreshDetail()
            doSave()
            notify("Reset "..slot.." to default.", "success")
        end, nil)
end)

PbModeBtn.MouseButton1Click:Connect(function()
    State.PlaybackMode = State.PlaybackMode == "Dynamic" and "Static" or "Dynamic"
    PbModeBtn.Text = "Mode: "..State.PlaybackMode
    notify("Playback: "..State.PlaybackMode, "info", 2)
end)

SpeedBox.FocusLost:Connect(function()
    local v = tonumber(SpeedBox.Text)
    if v and v > 0 then State.PlaybackMult = v
    else SpeedBox.Text = tostring(State.PlaybackMult) end
end)

refreshDetail()
if SlotBtns[SLOT_NAMES[1]] then SlotBtns[SLOT_NAMES[1]].BackgroundColor3 = THEME.AccentDark end

-- ============================================================
-- PACKS TAB
-- ============================================================
local PP = Panels["Packs"]
pad(PP, 10,10,10,10)

label(PP, "Animation Packs", UDim2.new(1,0,0,28), UDim2.new(0,0,0,0), THEME.Accent, 17, "PH").Font = Enum.Font.GothamBold
label(PP, "Save your current slot setup as a named pack, then apply it anytime.",
    UDim2.new(1,0,0,20), UDim2.new(0,0,0,30), THEME.TextSub, 13, "PSub")

local PkSearch = textbox(PP, "Search packs…", UDim2.new(0.62,0,0,34), UDim2.new(0,0,0,56), "PkSearch")
local NewPkBtn = btn(PP, "+ Save Current as Pack", UDim2.new(0.36,-4,0,34), UDim2.new(0.64,4,0,56), THEME.Accent)
NewPkBtn.TextSize = 12

local PkScroll = scroll(PP, UDim2.new(1,0,1,-100), UDim2.new(0,0,0,100), "PkScroll")
listLayout(PkScroll, 6)

local function refreshPacks()
    for _, c in ipairs(PkScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local f = PkSearch.Text:lower()
    for i, pk in ipairs(State.Packs) do
        if f ~= "" and not pk.name:lower():find(f, 1, true) then continue end

        local r = frame(PkScroll, UDim2.new(1,-8,0,58), UDim2.new(0,4,0,0), THEME.Card, "Pk")
        r.LayoutOrder = i
        corner(r, 8)
        stroke(r, THEME.Border, 1)
        pad(r, 8,8,8,12)

        label(r, pk.name,        UDim2.new(0.6,0,0.5,0), UDim2.new(0,0,0,0),   THEME.Text, 15).Font = Enum.Font.GothamSemibold
        label(r, pk.folder or "Default", UDim2.new(0.6,0,0.5,0), UDim2.new(0,0,0.5,0), THEME.TextMuted, 12)

        local useB = btn(r, "Apply", UDim2.new(0,68,0,30), UDim2.new(1,-148,0,14), THEME.Accent)
        useB.TextSize = 13
        useB.MouseButton1Click:Connect(function()
            for slot, animId in pairs(pk.anims) do
                State.CustomAnims[slot] = animId
                applyAnimation(slot, animId)
            end
            refreshDetail()
            doSave()
            notify("Applied pack: "..pk.name, "success")
        end)

        local delB = btn(r, "Delete", UDim2.new(0,68,0,30), UDim2.new(1,-76,0,14), THEME.Danger)
        delB.TextSize = 13
        delB.MouseButton1Click:Connect(function()
            table.remove(State.Packs, i)
            doSave()
            refreshPacks()
        end)
    end
end

NewPkBtn.MouseButton1Click:Connect(function()
    local anims = {}
    for slot, id in pairs(State.CustomAnims) do
        if id and id ~= "" then anims[slot] = id end
    end
    if next(anims) == nil then
        notify("No custom animations set — nothing to save as a pack.", "warning")
        return
    end
    local pk = {name="Pack "..(#State.Packs+1), folder="Custom", anims=anims}
    table.insert(State.Packs, pk)
    doSave()
    refreshPacks()
    notify("Saved as: "..pk.name, "success")
end)

PkSearch:GetPropertyChangedSignal("Text"):Connect(refreshPacks)
refreshPacks()

-- ============================================================
-- EMOTES TAB
-- ============================================================
local EP = Panels["Emotes"]
pad(EP, 10,10,10,10)

-- Top bar
local EmTop = frame(EP, UDim2.new(1,0,0,38), UDim2.new(0,0,0,0), THEME.Bg)
EmTop.BackgroundTransparency = 1
local EmSearch = textbox(EmTop, "Search emotes…", UDim2.new(0.56,-4,1,-4), UDim2.new(0,0,0,2))
local FavToggle= btn(EmTop, "★ Favorites",      UDim2.new(0.21,-4,1,-4), UDim2.new(0.57,4,0,2), THEME.Card)
local AddEmBtn = btn(EmTop, "+ Add",             UDim2.new(0.20,-2,1,-4), UDim2.new(0.79,4,0,2), THEME.Accent)
FavToggle.TextSize = 13
AddEmBtn.TextSize  = 13

local showFavs = false
FavToggle.MouseButton1Click:Connect(function()
    showFavs = not showFavs
    FavToggle.BackgroundColor3 = showFavs and THEME.Warning or THEME.Card
    FavToggle.Text = showFavs and "★ All" or "★ Favorites"
end)

local EmScroll = scroll(EP, UDim2.new(1,0,1,-50), UDim2.new(0,0,0,46), "EmScroll")
gridLayout(EmScroll, UDim2.new(0,114,0,114), UDim2.new(0,7,0,7))
pad(EmScroll, 6,6,6,6)

local function refreshEmotes()
    for _, c in ipairs(EmScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
    local f = EmSearch.Text:lower()
    for i, em in ipairs(State.Emotes) do
        if showFavs and not em.favorited then continue end
        if f ~= "" and not em.name:lower():find(f, 1, true) then continue end

        local card = frame(EmScroll, UDim2.new(0,114,0,114), UDim2.new(0,0,0,0), THEME.Card)
        card.LayoutOrder = i
        corner(card, 10)
        stroke(card, THEME.Border, 1)

        local thumb = frame(card, UDim2.new(1,-4,0,72), UDim2.new(0,2,0,2), THEME.Surface)
        corner(thumb, 8)
        local tl = label(thumb, "No Preview", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), THEME.TextMuted, 11)
        tl.TextXAlignment = Enum.TextXAlignment.Center

        local nl = label(card, em.name, UDim2.new(1,-4,0,16), UDim2.new(0,2,0,78), THEME.Text, 11)
        nl.TextXAlignment = Enum.TextXAlignment.Center

        local playB = btn(card, "▶", UDim2.new(0.5,-2,0,18), UDim2.new(0,1,1,-20), THEME.Accent)
        playB.TextSize = 12
        playB.MouseButton1Click:Connect(function()
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://"..em.id
            local ok, tr = pcall(function() return Humanoid:LoadAnimation(anim) end)
            if ok and tr then tr:Play() notify("Playing: "..em.name, "info", 2) end
        end)

        local floatB = btn(card, "⊞", UDim2.new(0.5,-2,0,18), UDim2.new(0.5,1,1,-20), THEME.Card)
        floatB.TextSize = 12
        floatB.MouseButton1Click:Connect(function()
            -- Create floating draggable button on screen
            local fb = Instance.new("TextButton")
            fb.Size             = UDim2.new(0,72,0,72)
            fb.Position         = UDim2.new(0.5,-36,0.5,-36)
            fb.BackgroundColor3 = THEME.AccentDark
            fb.TextColor3       = THEME.Text
            fb.Text             = em.name:sub(1,8).."\n▶"
            fb.TextSize         = 11
            fb.Font             = Enum.Font.GothamBold
            fb.ZIndex           = 20
            corner(fb, 14)
            stroke(fb, THEME.AccentHov, 2)
            fb.Parent = GUI

            makeDraggable(fb, fb, function()
                local v   = vp()
                local ap  = fb.AbsolutePosition
                local as  = fb.AbsoluteSize
                if ap.X + as.X / 2 < v.X / 2 then
                    tween(fb, {Position = UDim2.new(0,8,0,ap.Y)}, 0.2)
                else
                    tween(fb, {Position = UDim2.new(0,v.X-as.X-8,0,ap.Y)}, 0.2)
                end
            end)

            fb.MouseButton1Click:Connect(function()
                local anim2 = Instance.new("Animation")
                anim2.AnimationId = "rbxassetid://"..em.id
                local ok2, tr2 = pcall(function() return Humanoid:LoadAnimation(anim2) end)
                if ok2 and tr2 then tr2:Play() end
            end)

            table.insert(State.FloatEmotes, {id=em.id, name=em.name, btn=fb})
            notify("Floating: "..em.name, "success", 2)
        end)
    end
end

AddEmBtn.MouseButton1Click:Connect(function()
    local ov  = frame(GUI, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.new(0,0,0), "Ov")
    ov.BackgroundTransparency = 0.45
    ov.ZIndex = 38
    local dlg = frame(GUI, UDim2.new(0,380,0,210), UDim2.new(0.5,-190,0.5,-105), THEME.Surface, "AddDlg")
    dlg.ZIndex = 39
    corner(dlg, 12)
    stroke(dlg, THEME.Border, 1)
    pad(dlg, 16,16,16,16)

    label(dlg, "Add Emote", UDim2.new(1,0,0,28), UDim2.new(0,0,0,0), THEME.Accent, 17).Font = Enum.Font.GothamBold
    label(dlg, "Name:", UDim2.new(1,0,0,18), UDim2.new(0,0,0,32), THEME.TextSub, 13)
    local nb = textbox(dlg, "Emote name…", UDim2.new(1,0,0,34), UDim2.new(0,0,0,52))
    label(dlg, "Animation ID or Link:", UDim2.new(1,0,0,18), UDim2.new(0,0,0,96), THEME.TextSub, 13)
    local ib = textbox(dlg, "ID or Roblox link…", UDim2.new(1,0,0,34), UDim2.new(0,0,0,116))

    local addB = btn(dlg, "Add",    UDim2.new(0.48,0,0,34), UDim2.new(0,0,1,-34), THEME.Success)
    local canB = btn(dlg, "Cancel", UDim2.new(0.48,0,0,34), UDim2.new(0.52,0,1,-34), THEME.Danger)

    local function close2() ov:Destroy() dlg:Destroy() end
    canB.MouseButton1Click:Connect(close2)
    addB.MouseButton1Click:Connect(function()
        local id2 = extractId(ib.Text)
        if not id2 then notify("Invalid ID or link.", "error") return end
        local n2  = nb.Text ~= "" and nb.Text or ("Emote "..(#State.Emotes+1))
        table.insert(State.Emotes, {id=id2, name=n2, favorited=false})
        doSave()
        refreshEmotes()
        notify("Added emote: "..n2, "success")
        close2()
    end)
end)

EmSearch:GetPropertyChangedSignal("Text"):Connect(refreshEmotes)
refreshEmotes()

-- ============================================================
-- EXPLORER TAB
-- ============================================================
local XP = Panels["Explorer"]
pad(XP, 10,10,10,10)

label(XP, "Explorer — Script & Animation Scanner", UDim2.new(1,0,0,28), UDim2.new(0,0,0,0), THEME.Accent, 16, "XH").Font = Enum.Font.GothamBold
label(XP,
    "Scans the Workspace for Animation objects and scripts that reference animation IDs.\n"..
    "Scripts are shown in read-only mode. Animations can be imported directly.",
    UDim2.new(1,0,0,36), UDim2.new(0,0,0,30), THEME.TextSub, 13).TextWrapped = true

local XRow = frame(XP, UDim2.new(1,0,0,36), UDim2.new(0,0,0,74), THEME.Bg)
XRow.BackgroundTransparency = 1
local XBox    = textbox(XRow, "Paste asset link or ID (optional — press Scan to inspect Workspace)",
    UDim2.new(0.79,-4,1,-4), UDim2.new(0,0,0,2))
local ScanBtn = btn(XRow, "Scan", UDim2.new(0.19,-2,1,-4), UDim2.new(0.81,4,0,2), THEME.Accent)

local XScroll = scroll(XP, UDim2.new(1,0,1,-120), UDim2.new(0,0,0,118), "XScroll")
listLayout(XScroll, 6)

local function showScriptViewer(scriptObj)
    local ov  = frame(GUI, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.new(0,0,0), "ScOv")
    ov.BackgroundTransparency = 0.45
    ov.ZIndex = 42

    local win = frame(GUI, UDim2.new(0,660,0,500), UDim2.new(0.5,-330,0.5,-250), THEME.Surface, "ScWin")
    win.ZIndex = 43
    corner(win, 12)
    stroke(win, THEME.Border, 1)

    local function closeV() ov:Destroy() win:Destroy() end

    label(win, "  [READ ONLY] — "..scriptObj.Name,
        UDim2.new(1,-46,0,36), UDim2.new(0,4,0,6), THEME.Accent, 15).Font = Enum.Font.GothamBold
    local cl = btn(win, "✕", UDim2.new(0,34,0,34), UDim2.new(1,-40,0,4), THEME.Danger)
    cl.MouseButton1Click:Connect(closeV)

    local srcBox = Instance.new("TextBox")
    srcBox.Size             = UDim2.new(1,-16,1,-52)
    srcBox.Position         = UDim2.new(0,8,0,46)
    srcBox.BackgroundColor3 = THEME.Card
    srcBox.TextColor3       = THEME.Text
    srcBox.TextSize         = 13
    srcBox.Font             = Enum.Font.RobotoMono
    srcBox.MultiLine        = true
    srcBox.TextEditable     = false   -- READ ONLY
    srcBox.TextXAlignment   = Enum.TextXAlignment.Left
    srcBox.TextYAlignment   = Enum.TextYAlignment.Top
    srcBox.BorderSizePixel  = 0
    srcBox.ZIndex           = 44
    corner(srcBox, 8)
    pad(srcBox, 8,8,8,8)

    local src = "[Source not accessible in-game. Showing script path only.]\n\nFull path: "..scriptObj:GetFullName()
    pcall(function() if scriptObj.Source and #scriptObj.Source > 0 then src = scriptObj.Source end end)
    srcBox.Text = src
    srcBox.Parent = win

    -- Detect animation IDs in source
    local found = {}
    for id in src:gmatch("rbxassetid://(%d+)") do table.insert(found, id) end
    for id in src:gmatch('[%s"\'%(](%d%d%d%d%d%d+)[%s"\'%)]') do table.insert(found, id) end

    if #found > 0 then
        notify(#found.." animation reference(s) found in "..scriptObj.Name, "warning")
    end
end

ScanBtn.MouseButton1Click:Connect(function()
    for _, c in ipairs(XScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end

    local scripts = {}
    local anims   = {}

    local function scan(root)
        if not root then return end
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("BaseScript") then
                table.insert(scripts, obj)
            elseif obj:IsA("Animation") then
                table.insert(anims, obj)
            end
        end
    end

    scan(workspace)
    if LocalPlayer.Character then scan(LocalPlayer.Character) end

    local order = 0

    -- Scripts header
    local sHdr = label(XScroll,
        "Scripts ("..#scripts..")",
        UDim2.new(1,-8,0,24), UDim2.new(0,4,0,0), THEME.Warning, 13, "SH")
    sHdr.Font = Enum.Font.GothamBold
    sHdr.LayoutOrder = order
    order += 1

    for _, sc in ipairs(scripts) do
        local r = frame(XScroll, UDim2.new(1,-8,0,46), UDim2.new(0,4,0,0), THEME.Card, "ScRow")
        r.LayoutOrder = order; order += 1
        corner(r, 8)
        stroke(r, THEME.Border, 1)
        pad(r, 6,6,6,10)

        local icon = sc:IsA("LocalScript") and "[L]" or sc:IsA("ModuleScript") and "[M]" or "[S]"
        label(r, icon.."  "..sc.Name, UDim2.new(0.65,0,0.5,0), UDim2.new(0,0,0,0), THEME.Text, 13).Font = Enum.Font.GothamSemibold
        label(r, sc:GetFullName(),    UDim2.new(0.65,0,0.5,0), UDim2.new(0,0,0.5,0), THEME.TextMuted, 11)

        local vBtn = btn(r, "View", UDim2.new(0,62,0,28), UDim2.new(1,-70,0,9), THEME.Accent)
        vBtn.TextSize = 12
        vBtn.MouseButton1Click:Connect(function() showScriptViewer(sc) end)
    end

    -- Animations header
    local aHdr = label(XScroll,
        "Animation Objects ("..#anims..")",
        UDim2.new(1,-8,0,24), UDim2.new(0,4,0,0), THEME.Success, 13, "AH")
    aHdr.Font = Enum.Font.GothamBold
    aHdr.LayoutOrder = order; order += 1

    for _, an in ipairs(anims) do
        local parsedId = extractId(an.AnimationId) or an.AnimationId
        local r = frame(XScroll, UDim2.new(1,-8,0,50), UDim2.new(0,4,0,0), THEME.Card, "AnRow")
        r.LayoutOrder = order; order += 1
        corner(r, 8)
        stroke(r, THEME.Border, 1)
        pad(r, 6,6,6,10)

        label(r, an.Name,         UDim2.new(0.55,0,0.5,0), UDim2.new(0,0,0,0),   THEME.Text,    13).Font = Enum.Font.GothamSemibold
        label(r, "ID: "..parsedId,UDim2.new(0.55,0,0.5,0), UDim2.new(0,0,0.5,0), THEME.TextMuted,11)

        local impB = btn(r, "Import", UDim2.new(0,72,0,28), UDim2.new(1,-80,0,11), THEME.Success)
        impB.TextSize = 12
        impB.MouseButton1Click:Connect(function()
            local slot = State.SelectedSlot
            local old  = State.CustomAnims[slot]
            State.CustomAnims[slot] = parsedId
            applyAnimation(slot, parsedId)
            pushUndo({
                undo = function()
                    State.CustomAnims[slot] = old
                    if old ~= "" then applyAnimation(slot, old) end
                    refreshDetail()
                end,
                redo = function()
                    State.CustomAnims[slot] = parsedId
                    applyAnimation(slot, parsedId)
                    refreshDetail()
                end,
            })
            refreshDetail()
            doSave()
            notify("Imported to "..slot..": "..parsedId, "success")
        end)
    end

    if #scripts == 0 and #anims == 0 then
        local empty = label(XScroll,
            "No scripts or Animation objects found.",
            UDim2.new(1,-8,0,30), UDim2.new(0,4,0,0), THEME.TextMuted, 14)
        empty.LayoutOrder = order
    end

    setStatus("Scan: "..#scripts.." script(s), "..#anims.." animation(s) found")
end)

-- ============================================================
-- EDITOR TAB
-- ============================================================
local EdP = Panels["Editor"]
pad(EdP, 10,10,10,10)

label(EdP, "Animation Editor", UDim2.new(1,0,0,28), UDim2.new(0,0,0,0), THEME.Accent, 17, "EH").Font = Enum.Font.GothamBold
label(EdP,
    "Enter an isolated animation studio with a cloned copy of your character.\n"..
    "Use the timeline to add keyframes, adjust Motor6D rotations, and preview.",
    UDim2.new(1,0,0,40), UDim2.new(0,0,0,30), THEME.TextSub, 13).TextWrapped = true

label(EdP, "Rig:", UDim2.new(0.12,0,0,22), UDim2.new(0,0,0,76), THEME.TextSub, 13)
local RigBtn = btn(EdP, "R15", UDim2.new(0.12,0,0,30), UDim2.new(0.13,0,0,72), THEME.Card)
RigBtn.TextSize = 13
local rigType = "R15"
RigBtn.MouseButton1Click:Connect(function()
    rigType = rigType == "R15" and "R6" or "R15"
    RigBtn.Text = rigType
end)

local EnterBtn = btn(EdP, "▶  Enter Animation Studio",
    UDim2.new(0.55,0,0,44), UDim2.new(0.225,0,0,120), THEME.Accent, "EnterEditor")
EnterBtn.TextSize = 15

local EdStatus = label(EdP, "", UDim2.new(1,0,0,24), UDim2.new(0,0,0,174), THEME.TextMuted, 13, "EdSt")

-- Timeline
local Timeline = frame(EdP, UDim2.new(1,0,0,148), UDim2.new(0,0,1,-162), THEME.Surface, "Timeline")
Timeline.Visible = false
corner(Timeline, 10)
stroke(Timeline, THEME.Border, 1)
pad(Timeline, 8,8,8,8)

label(Timeline, "Timeline", UDim2.new(0.3,0,0,20), UDim2.new(0,0,0,0), THEME.Accent, 13).Font = Enum.Font.GothamBold

-- Track bar
local TrackBar = frame(Timeline, UDim2.new(1,0,0,50), UDim2.new(0,0,0,24), THEME.Card, "Track")
corner(TrackBar, 6)
stroke(TrackBar, THEME.Border, 1)

local KfScroll = scroll(TrackBar, UDim2.new(1,-4,1,-4), UDim2.new(0,2,0,2), "KfScroll")
KfScroll.ScrollBarThickness = 3

local KeyframeCount = 0
local function addKfMarker(normalizedPos, kfName)
    local mk = frame(KfScroll, UDim2.new(0,12,0.8,0), UDim2.new(normalizedPos,-6,0.1,0), THEME.Accent, "KF")
    corner(mk, 3)
    local kl = label(mk, kfName or "", UDim2.new(0,60,0,16), UDim2.new(0,-6,0,-18), THEME.Text, 9)
    kl.TextXAlignment = Enum.TextXAlignment.Center
    return mk
end

-- Playback row
local PbRow = frame(Timeline, UDim2.new(1,0,0,32), UDim2.new(0,0,0,84), THEME.Bg)
PbRow.BackgroundTransparency = 1

local function pbBtn(text, xOff, col)
    local b = btn(PbRow, text, UDim2.new(0,48,1,-2), UDim2.new(0,xOff,0,1), col or THEME.Accent)
    b.TextSize = 13
    return b
end

local PlayBtn  = pbBtn("▶",  0)
local PauseBtn = pbBtn("⏸", 52, THEME.Card)
local StopBtn  = pbBtn("■", 104, THEME.Danger)
local LoopBtn  = pbBtn("↺", 156, THEME.Card)
local AddKfBtn = btn(PbRow, "+ KF",   UDim2.new(0,60,1,-2), UDim2.new(0,210,0,1), THEME.Success)
local UndoBtn2 = btn(PbRow, "↩ Undo", UDim2.new(0,72,1,-2), UDim2.new(0,276,0,1), THEME.Card)
local RedoBtn2 = btn(PbRow, "↪ Redo", UDim2.new(0,72,1,-2), UDim2.new(0,352,0,1), THEME.Card)
AddKfBtn.TextSize = 12
UndoBtn2.TextSize = 12
RedoBtn2.TextSize = 12

UndoBtn2.MouseButton1Click:Connect(doUndo)
RedoBtn2.MouseButton1Click:Connect(doRedo)

-- Props panel (shown in editor)
local PropsPanel = frame(EdP, UDim2.new(0.28,-4,1,-50), UDim2.new(0.72,4,0,48), THEME.Surface, "Props")
PropsPanel.Visible = false
corner(PropsPanel, 10)
stroke(PropsPanel, THEME.Border, 1)
pad(PropsPanel, 8,8,8,8)
label(PropsPanel, "Motor6D Properties", UDim2.new(1,0,0,22), UDim2.new(0,0,0,0), THEME.Accent, 13, "PH").Font = Enum.Font.GothamBold
local PropScroll = scroll(PropsPanel, UDim2.new(1,0,1,-30), UDim2.new(0,0,0,28), "PropScroll")
listLayout(PropScroll, 4)

-- Editor studio room
local StudioRoom = nil
local ClonedChar = nil
local IsEditing  = false
local PlaybackT  = 0
local IsPlaying  = false

local function buildStudio()
    local model = Instance.new("Model")
    model.Name = "AnimStudio_Env"

    -- Floor
    local fl = Instance.new("Part")
    fl.Name       = "Floor"
    fl.Size       = Vector3.new(50, 1, 50)
    fl.Position   = Vector3.new(0, -0.5, 0)
    fl.Anchored   = true
    fl.Material   = Enum.Material.SmoothPlastic
    fl.Color      = Color3.fromRGB(24, 24, 36)
    fl.CanCollide = true
    fl.Parent     = model

    -- Grid
    for i = -12, 12, 3 do
        for _, horizontal in ipairs({true, false}) do
            local g = Instance.new("Part")
            g.Size       = horizontal and Vector3.new(50,0.02,0.06) or Vector3.new(0.06,0.02,50)
            g.Position   = horizontal and Vector3.new(0,0.01,i) or Vector3.new(i,0.01,0)
            g.Anchored   = true
            g.CanCollide = false
            g.Material   = Enum.Material.Neon
            g.Color      = Color3.fromRGB(55,55,110)
            g.CastShadow = false
            g.Parent     = model
        end
    end

    -- Spot light rig
    local sp = Instance.new("Part")
    sp.Size        = Vector3.new(1,1,1)
    sp.Position    = Vector3.new(0,14,0)
    sp.Anchored    = true
    sp.Transparency= 1
    sp.CanCollide  = false
    sp.Parent      = model
    local sLight   = Instance.new("SpotLight")
    sLight.Brightness = 6
    sLight.Range   = 22
    sLight.Angle   = 50
    sLight.Color   = Color3.fromRGB(210, 210, 255)
    sLight.Face    = Enum.NormalId.Bottom
    sLight.Parent  = sp

    model.Parent = workspace
    return model
end

local function enterEditor()
    if IsEditing then return end
    IsEditing = true
    State.EditorOpen = true
    ToggleBtn.Visible = false

    EdStatus.Text       = "Entering studio…"
    EdStatus.TextColor3 = THEME.Warning

    -- Fade
    local fade = frame(GUI, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.new(0,0,0), "Fade")
    fade.BackgroundTransparency = 1
    fade.ZIndex = 50
    tween(fade, {BackgroundTransparency=0}, 0.55)
    task.wait(0.65)

    StudioRoom = buildStudio()

    -- Clone character
    if LocalPlayer.Character then
        ClonedChar = LocalPlayer.Character:Clone()
        for _, s in ipairs(ClonedChar:GetDescendants()) do
            if s:IsA("BaseScript") then s.Disabled = true end
        end
        ClonedChar:PivotTo(CFrame.new(0, 1.5, 0))
        ClonedChar.Parent = workspace

        -- Hide real character
        for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.Transparency = 1 end
        end
        local rHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if rHRP then rHRP.Anchored = true end
    end

    Camera.CameraType = Enum.CameraType.Scriptable
    tween(Camera, {CFrame = CFrame.new(0, 6, 14) * CFrame.Angles(math.rad(-18), 0, 0)}, 0.55)

    tween(fade, {BackgroundTransparency=1}, 0.45)
    task.wait(0.5)
    pcall(function() fade:Destroy() end)

    Timeline.Visible   = true
    PropsPanel.Visible = true

    -- Populate props with Motor6Ds
    PropScroll:ClearAllChildren()
    listLayout(PropScroll, 4)
    if ClonedChar then
        for _, m in ipairs(ClonedChar:GetDescendants()) do
            if m:IsA("Motor6D") then
                local row = frame(PropScroll, UDim2.new(1,-4,0,26), UDim2.new(0,2,0,0), THEME.Card)
                corner(row, 6)
                label(row, m.Name, UDim2.new(0.5,0,1,0), UDim2.new(0,4,0,0), THEME.TextSub, 11)
                local vbox = textbox(row, "C0 Rotation", UDim2.new(0.48,0,0.8,0), UDim2.new(0.5,0,0.1,0))
                vbox.TextSize = 11
                vbox.Text = "0, 0, 0"
                vbox.FocusLost:Connect(function()
                    State.EditorDirty = true
                    EdStatus.Text       = "Unsaved changes"
                    EdStatus.TextColor3 = THEME.Warning
                end)
            end
        end
    end

    EdStatus.Text       = "Studio active ("..rigType.." rig)"
    EdStatus.TextColor3 = THEME.Success
    EnterBtn.Text       = "✕  Exit Studio"
    EnterBtn.BackgroundColor3 = THEME.Danger
end

local function exitEditor()
    if not IsEditing then return end

    local function doExit()
        local fade = frame(GUI, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.new(0,0,0), "Fade")
        fade.BackgroundTransparency = 1
        fade.ZIndex = 50
        tween(fade, {BackgroundTransparency=0}, 0.5)
        task.wait(0.6)

        if StudioRoom then StudioRoom:Destroy(); StudioRoom = nil end
        if ClonedChar then ClonedChar:Destroy(); ClonedChar = nil end

        -- Restore character
        if LocalPlayer.Character then
            for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
                if p:IsA("BasePart") then p.Transparency = 0 end
            end
            local rHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if rHRP then rHRP.Anchored = false end
        end

        Camera.CameraType = Enum.CameraType.Custom

        Timeline.Visible   = false
        PropsPanel.Visible = false
        IsEditing          = false
        State.EditorOpen   = false
        State.EditorDirty  = false
        IsPlaying          = false
        PlaybackT          = 0

        EnterBtn.Text             = "▶  Enter Animation Studio"
        EnterBtn.BackgroundColor3 = THEME.Accent
        EdStatus.Text             = "Exited studio."
        EdStatus.TextColor3       = THEME.TextMuted

        tween(fade, {BackgroundTransparency=1}, 0.4)
        task.wait(0.45)
        pcall(function() fade:Destroy() end)

        ToggleBtn.Visible = true
        doSave()
        notify("Exited Animation Studio.", "info")
    end

    if State.EditorDirty then
        confirm("Exit Studio",
            "You have unsaved changes. Save before exiting?",
            function()
                State.Keyframes = {}  -- save keyframe data here if needed
                doSave()
                doExit()
            end,
            doExit)
    else
        doExit()
    end
end

EnterBtn.MouseButton1Click:Connect(function()
    if IsEditing then exitEditor() else enterEditor() end
end)

-- Playback buttons
PlayBtn.MouseButton1Click:Connect(function()
    IsPlaying = true
    if ClonedChar then
        local hum2 = ClonedChar:FindFirstChildOfClass("Humanoid")
        if hum2 then
            -- Play the currently selected slot animation on the clone
            local slot  = State.SelectedSlot
            local id    = State.CustomAnims[slot]
            if id and id ~= "" then
                local anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://"..id
                local ok, tr = pcall(function() return hum2:LoadAnimation(anim) end)
                if ok and tr then tr:Play() end
            end
        end
    end
    notify("Playback started.", "info", 1.5)
end)
PauseBtn.MouseButton1Click:Connect(function()
    IsPlaying = false
    if ClonedChar then
        local hum2 = ClonedChar:FindFirstChildOfClass("Humanoid")
        if hum2 then
            local anim2 = hum2:FindFirstChildOfClass("Animator")
            if anim2 then
                for _, tr in ipairs(anim2:GetPlayingAnimationTracks()) do
                    tr:AdjustSpeed(0)
                end
            end
        end
    end
end)
StopBtn.MouseButton1Click:Connect(function()
    IsPlaying = false
    PlaybackT = 0
    if ClonedChar then
        local hum2 = ClonedChar:FindFirstChildOfClass("Humanoid")
        if hum2 then
            local anim2 = hum2:FindFirstChildOfClass("Animator")
            if anim2 then
                for _, tr in ipairs(anim2:GetPlayingAnimationTracks()) do
                    tr:Stop(0)
                end
            end
        end
    end
end)
AddKfBtn.MouseButton1Click:Connect(function()
    KeyframeCount += 1
    local kfName = "KF"..KeyframeCount
    table.insert(State.Keyframes, {time=PlaybackT, name=kfName})
    addKfMarker(math.clamp(PlaybackT / math.max(#State.Keyframes * 0.5, 1), 0, 0.98), kfName)
    State.EditorDirty   = true
    EdStatus.Text       = "Unsaved changes"
    EdStatus.TextColor3 = THEME.Warning
    local prevCount = KeyframeCount
    pushUndo({
        undo = function()
            table.remove(State.Keyframes)
            KeyframeCount = prevCount - 1
        end,
        redo = function()
            table.insert(State.Keyframes, {time=PlaybackT, name=kfName})
            KeyframeCount = prevCount
        end,
    })
    notify("Added "..kfName, "success", 2)
end)

-- Heartbeat for editor playback timer
RunService.Heartbeat:Connect(function(dt)
    if IsEditing and IsPlaying then
        PlaybackT += dt
    end
end)

-- ============================================================
-- OPEN / CLOSE WINDOW
-- ============================================================
local function openUI()
    State.UIOpen   = true
    Win.Visible    = true
    Win.BackgroundTransparency = 1
    tween(Win, {BackgroundTransparency=0}, 0.22)
    switchTab(State.ActiveTab)
    setStatus("Animation Studio v"..VERSION.." — Ready")
end

local function closeUI()
    if State.EditorDirty then
        confirm("Close", "You have unsaved changes. Save before closing?",
            function() doSave() end, nil)
    end
    State.UIOpen = false
    tween(Win, {BackgroundTransparency=1}, 0.2)
    task.delay(0.22, function()
        if not State.UIOpen then Win.Visible = false end
    end)
end

ToggleBtn.MouseButton1Click:Connect(function()
    if State.UIOpen then closeUI() else openUI() end
end)
CloseWin.MouseButton1Click:Connect(closeUI)

-- ============================================================
-- INIT
-- ============================================================
task.spawn(function()
    doLoad()
    applyAllAnimations()
    refreshDetail()
    refreshPacks()
    refreshEmotes()

    -- Default emotes if none saved
    if #State.Emotes == 0 then
        local defaults = {
            {"507770239","Wave"}, {"507771019","Point"},
            {"507769814","Cheer"},{"507770818","Laugh"},
            {"507771508","Dance"},
        }
        for _, e in ipairs(defaults) do
            table.insert(State.Emotes, {id=e[1], name=e[2], favorited=false})
        end
        refreshEmotes()
    end

    notify("Animation Studio v"..VERSION.." ready!", "success", 3)
    setStatus("Loaded — v"..VERSION)
end)

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local vSize = vp()
    local ap    = Win.AbsolutePosition
    local as    = Win.AbsoluteSize
    if ap.X < 0 then Win.Position = UDim2.new(0,4,Win.Position.Y.Scale,Win.Position.Y.Offset) end
    if ap.Y < 0 then Win.Position = UDim2.new(Win.Position.X.Scale,Win.Position.X.Offset,0,4) end
    if ap.X+as.X > vSize.X then Win.Position = UDim2.new(0,vSize.X-as.X-4,Win.Position.Y.Scale,Win.Position.Y.Offset) end
end)

LocalPlayer.CharacterRemoving:Connect(function()
    if IsEditing then
        if StudioRoom then pcall(function() StudioRoom:Destroy() end) end
        if ClonedChar then pcall(function() ClonedChar:Destroy() end) end
        IsEditing  = false
        Timeline.Visible   = false
        PropsPanel.Visible = false
    end
end)

print("[AnimationStudio] v"..VERSION.." initialized.")
