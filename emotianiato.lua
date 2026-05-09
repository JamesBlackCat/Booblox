--[[
    ROBLOX ANIMATION STUDIO v2.0
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Executor-compatible  |  CoreGui  |  R6 + R15
    No server required  |  Flat Lua 5.1 syntax

    HOW TO USE:
      Execute this script in any Roblox executor.
      A toggle button (▶) appears on the right side of your screen.
      Drag it anywhere, click it to open/close the studio.

    FEATURES:
      • 10 animation slots  (Idle, Walk, Run, Jump, Fall …)
      • R6 + R15 auto-detection
      • Built-in animation packs  +  save your own
      • Emotes library  (search, favorites, add by ID)
      • Draggable floating emote buttons
      • Dynamic speed scaling  /  static multiplier
      • Saves settings with writefile when available
]]

-- ════════════════════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════════════════════
local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local UIS             = game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local CoreGui         = game:GetService("CoreGui")
local StarterGui      = game:GetService("StarterGui")

-- ════════════════════════════════════════════════════════
--  LOCAL PLAYER GUARD
-- ════════════════════════════════════════════════════════
local LP = Players.LocalPlayer
if not LP then
    for _ = 1, 20 do
        task.wait(0.1)
        LP = Players.LocalPlayer
        if LP then break end
    end
end
if not LP then
    error("[AnimStudio] LocalPlayer unavailable — run inside a live game session.")
end

-- Remove any previous instance (re-execution safe)
pcall(function()
    local old = CoreGui:FindFirstChild("AnimStudio_v2")
    if old then old:Destroy() end
end)

-- ════════════════════════════════════════════════════════
--  CONSTANTS
-- ════════════════════════════════════════════════════════
local C = {
    Bg        = Color3.fromRGB(14,  14,  20),
    Surface   = Color3.fromRGB(22,  22,  30),
    Card      = Color3.fromRGB(30,  30,  42),
    CardHov   = Color3.fromRGB(40,  40,  56),
    Border    = Color3.fromRGB(50,  50,  70),
    Accent    = Color3.fromRGB(100, 140, 255),
    AccentDk  = Color3.fromRGB(60,  90,  180),
    AccentDim = Color3.fromRGB(25,  40,  90),
    Success   = Color3.fromRGB(60,  200, 100),
    Warn      = Color3.fromRGB(240, 180, 40),
    Danger    = Color3.fromRGB(230, 70,  70),
    Text      = Color3.fromRGB(220, 220, 235),
    TextSub   = Color3.fromRGB(160, 160, 180),
    TextMuted = Color3.fromRGB(100, 100, 120),
    Gold      = Color3.fromRGB(255, 200, 40),
    White     = Color3.new(1, 1, 1),
}

local FB  = Enum.Font.GothamBold
local FM  = Enum.Font.GothamSemibold
local FR  = Enum.Font.Gotham
local TIF = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TIM = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TIS = TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local SLOTS     = {"Idle","Idle2","Walk","Run","Jump","Fall","Swim","Float","Climb","Sit"}
local WIN_W     = 780
local WIN_H     = 520
local SAVE_FILE = "AnimStudio_save.json"

local DEFAULT_IDS = {
    R15 = {
        Idle  = "507766388", Idle2 = "507766666",
        Walk  = "507777826", Run   = "507767714",
        Jump  = "507765000", Fall  = "507767968",
        Swim  = "507784897", Float = "507770239",
        Climb = "507765644", Sit   = "2506281703",
    },
    R6 = {
        Idle  = "180435571", Idle2 = "180435571",
        Walk  = "180426354", Run   = "180426354",
        Jump  = "125750702", Fall  = "180436148",
        Swim  = "180436334", Float = "180436148",
        Climb = "180436334", Sit   = "178130996",
    },
}

local BUILTIN_EMOTES = {
    {name="Wave",       id="507770239"},
    {name="Point",      id="507770453"},
    {name="Dance",      id="507771019"},
    {name="Dance 2",    id="507776043"},
    {name="Dance 3",    id="507776898"},
    {name="Laugh",      id="507770818"},
    {name="Cheer",      id="507770677"},
    {name="Salute",     id="3360689775"},
    {name="Shrug",      id="3351547819"},
    {name="Breakdance", id="507776271"},
    {name="Headbang",   id="4352187505"},
    {name="Facepalm",   id="4352189961"},
    {name="Stadium",    id="3360686498"},
    {name="Lean Back",  id="2639299498"},
    {name="Air Guitar", id="5915693819"},
    {name="Spin",       id="507769368"},
    {name="Tilt",       id="3360692915"},
    {name="Ninja Run",  id="616010382"},
}

-- ════════════════════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════════════════════
local S = {
    char          = nil,
    humanoid      = nil,
    animator      = nil,
    rigType       = "R15",
    slots         = {},   -- [slotName] = {id=""}
    activeTracks  = {},   -- [slotName] = AnimationTrack
    emoteTracks   = {},   -- currently-playing emote tracks
    favEmotes     = {},   -- {[id]=true}
    customEmotes  = {},   -- user-added {name,id}
    packs         = {},   -- saved packs {name, slots={}}
    floatBtns     = {},   -- [emoteId] = {frame}
    speedMode     = "Dynamic",
    speedMult     = 1.0,
}

-- ════════════════════════════════════════════════════════
--  UI HELPERS
-- ════════════════════════════════════════════════════════
local function tw(inst, props, ti)
    TweenService:Create(inst, ti or TIF, props):Play()
end

local function mkFrame(props)
    local f = Instance.new("Frame")
    f.BackgroundColor3      = props.Color or C.Surface
    f.BackgroundTransparency = props.Transparency or 0
    f.BorderSizePixel       = 0
    f.Size                  = props.Size or UDim2.new(1,0,1,0)
    f.Position              = props.Position or UDim2.new(0,0,0,0)
    f.ClipsDescendants      = props.Clip or false
    f.ZIndex                = props.ZIndex or 1
    if props.Name   then f.Name   = props.Name   end
    if props.Parent then f.Parent = props.Parent end
    return f
end

local function mkCorner(r, p)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local function mkStroke(color, thick, p)
    local s = Instance.new("UIStroke")
    s.Color     = color or C.Border
    s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function mkPad(t, b, l, r, p)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, t or 8)
    pad.PaddingBottom = UDim.new(0, b or 8)
    pad.PaddingLeft   = UDim.new(0, l or 8)
    pad.PaddingRight  = UDim.new(0, r or 8)
    pad.Parent = p
    return pad
end

local function mkList(dir, gap, p)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.Padding       = UDim.new(0, gap or 4)
    l.Parent = p
    return l
end

local function mkLabel(text, size, color, font, p)
    local l = Instance.new("TextLabel")
    l.Text               = text or ""
    l.TextSize           = size or 13
    l.TextColor3         = color or C.Text
    l.Font               = font or FR
    l.BackgroundTransparency = 1
    l.BorderSizePixel    = 0
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.TextWrapped        = false
    l.Size               = UDim2.new(1,0,1,0)
    if p then l.Parent = p end
    return l
end

local function mkBtn(text, color, hov, p)
    local b = Instance.new("TextButton")
    b.Text             = text or ""
    b.TextColor3       = C.White
    b.Font             = FM
    b.TextSize         = 13
    b.BackgroundColor3 = color or C.Card
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    mkCorner(6, b)
    b.MouseEnter:Connect(function() tw(b, {BackgroundColor3 = hov or C.CardHov}) end)
    b.MouseLeave:Connect(function() tw(b, {BackgroundColor3 = color or C.Card}) end)
    if p then b.Parent = p end
    return b
end

local function mkInput(placeholder, p)
    local frame = mkFrame({Color = C.Bg, Size = UDim2.new(1,0,0,34)})
    mkCorner(6, frame)
    local stroke = mkStroke(C.Border, 1, frame)
    local box = Instance.new("TextBox")
    box.Size              = UDim2.new(1,-12,1,-4)
    box.Position          = UDim2.new(0,6,0,2)
    box.BackgroundTransparency = 1
    box.BorderSizePixel   = 0
    box.Text              = ""
    box.PlaceholderText   = placeholder or ""
    box.TextColor3        = C.Text
    box.PlaceholderColor3 = C.TextMuted
    box.Font              = FR
    box.TextSize          = 12
    box.ClearTextOnFocus  = false
    box.TextXAlignment    = Enum.TextXAlignment.Left
    box.Parent            = frame
    box.Focused:Connect(function()
        tw(stroke, {Color = C.Accent})
        tw(frame,  {BackgroundColor3 = Color3.fromRGB(20,20,30)})
    end)
    box.FocusLost:Connect(function()
        tw(stroke, {Color = C.Border})
        tw(frame,  {BackgroundColor3 = C.Bg})
    end)
    if p then frame.Parent = p end
    return frame, box
end

local function mkScroll(p)
    local s = Instance.new("ScrollingFrame")
    s.BackgroundTransparency = 1
    s.BorderSizePixel        = 0
    s.ScrollBarThickness     = 3
    s.ScrollBarImageColor3   = C.Accent
    s.CanvasSize             = UDim2.new(0,0,0,0)
    s.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    s.ElasticBehavior        = Enum.ElasticBehavior.Never
    if p then s.Parent = p end
    return s
end

local function mkDraggable(handle, target)
    local drag, ds, sp = false, nil, nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            drag = true
            ds   = inp.Position
            sp   = target.Position
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not drag then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = inp.Position - ds
        target.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X,
                                     sp.Y.Scale, sp.Y.Offset + d.Y)
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  SCREEN GUI  (CoreGui — executor-safe)
-- ════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name           = "AnimStudio_v2"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
pcall(function() if protect_gui then protect_gui(gui) end end)
gui.Parent = CoreGui

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)

-- ════════════════════════════════════════════════════════
--  TOAST NOTIFICATION
-- ════════════════════════════════════════════════════════
local function toast(msg, kind)
    local col = C.Accent
    if kind == "success" then col = C.Success
    elseif kind == "error" then col = C.Danger
    elseif kind == "warn"  then col = C.Warn
    end
    local t = mkFrame({Color = col,
        Size     = UDim2.new(0,280,0,36),
        Position = UDim2.new(0.5,-140,1,10),
        ZIndex   = 200, Parent = gui})
    mkCorner(8, t)
    t.ZIndex = 200
    local lbl = mkLabel(msg, 13, C.White, FM, t)
    lbl.Size             = UDim2.new(1,-16,1,0)
    lbl.Position         = UDim2.new(0,8,0,0)
    lbl.TextXAlignment   = Enum.TextXAlignment.Center
    lbl.ZIndex           = 201
    tw(t, {Position = UDim2.new(0.5,-140,1,-48)}, TIM)
    task.delay(2.5, function()
        tw(t, {Position = UDim2.new(0.5,-140,1,10)}, TIM)
        task.delay(0.3, function() pcall(function() t:Destroy() end) end)
    end)
end

-- ════════════════════════════════════════════════════════
--  ANIMATION HELPERS
-- ════════════════════════════════════════════════════════
local function normID(id)
    if not id then return "" end
    local s = tostring(id):gsub("rbxassetid://","")
    return s:match("%d+") or ""
end

local function validID(id)
    local n = normID(id)
    return n ~= "" and #n >= 5
end

local function ensureAnimator()
    if not S.humanoid then return nil end
    local a = S.humanoid:FindFirstChildOfClass("Animator")
    if not a then
        a = Instance.new("Animator")
        a.Parent = S.humanoid
    end
    S.animator = a
    return a
end

local function loadTrack(id)
    local animator = ensureAnimator()
    if not animator then return nil end
    local clean = normID(id)
    if clean == "" then return nil end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. clean
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    anim:Destroy()
    if ok and track then return track end
    return nil
end

local function stopSlot(name)
    local t = S.activeTracks[name]
    if t then
        pcall(function() t:Stop(0.2) end)
        S.activeTracks[name] = nil
    end
end

local function playSlot(name)
    if not S.humanoid or S.humanoid.Health <= 0 then
        toast("No character loaded", "error"); return
    end
    local slot = S.slots[name] or {id=""}
    local id   = slot.id or ""
    if id == "" then
        local defs = DEFAULT_IDS[S.rigType] or DEFAULT_IDS.R15
        id = defs[name] or ""
    end
    if id == "" then toast("No ID for " .. name, "warn"); return end
    stopSlot(name)
    local track = loadTrack(id)
    if not track then toast("Failed to load: " .. id, "error"); return end
    track.Priority = Enum.AnimationPriority.Action
    track.Looped   = true
    track:Play(0.1)
    S.activeTracks[name] = track
end

local function stopAllSlots()
    for _, n in ipairs(SLOTS) do stopSlot(n) end
end

local function playEmote(id)
    for i = #S.emoteTracks, 1, -1 do
        pcall(function() S.emoteTracks[i]:Stop(0.1) end)
        table.remove(S.emoteTracks, i)
    end
    if not S.humanoid then toast("No character", "error"); return end
    local track = loadTrack(id)
    if not track then toast("Could not load emote", "error"); return end
    track.Priority = Enum.AnimationPriority.Action4
    track.Looped   = false
    track:Play(0.1)
    table.insert(S.emoteTracks, track)
end

-- ════════════════════════════════════════════════════════
--  SAVE / LOAD  (writefile/readfile when available)
-- ════════════════════════════════════════════════════════
local function jsonEnc(v)
    local t = type(v)
    if t == "nil"     then return "null"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number"  then
        if v ~= v then return "0" end
        return tostring(v)
    elseif t == "string" then
        v = v:gsub("\\","\\\\"):gsub('"','\\"')
               :gsub("\n","\\n"):gsub("\r","\\r")
        return '"' .. v .. '"'
    elseif t == "table" then
        if #v > 0 then
            local parts = {}
            for _, item in ipairs(v) do
                parts[#parts+1] = jsonEnc(item)
            end
            return "[" .. table.concat(parts,",") .. "]"
        else
            local parts = {}
            for k, val in pairs(v) do
                if type(k) == "string" then
                    parts[#parts+1] = jsonEnc(k) .. ":" .. jsonEnc(val)
                end
            end
            return "{" .. table.concat(parts,",") .. "}"
        end
    end
    return "null"
end

local function jsonDec(s)
    local hs
    pcall(function() hs = game:GetService("HttpService") end)
    if hs then
        local ok, r = pcall(function() return hs:JSONDecode(s) end)
        if ok then return r end
    end
    return nil
end

local function saveData()
    local data = {
        slots        = {},
        favEmotes    = {},
        customEmotes = S.customEmotes,
        packs        = S.packs,
        speedMode    = S.speedMode,
        speedMult    = S.speedMult,
    }
    for name, slot in pairs(S.slots) do
        if slot.id and slot.id ~= "" then
            data.slots[name] = {id = slot.id}
        end
    end
    for id, v in pairs(S.favEmotes) do
        if v then table.insert(data.favEmotes, id) end
    end
    if type(writefile) == "function" then
        pcall(function() writefile(SAVE_FILE, jsonEnc(data)) end)
    end
end

local function loadData()
    if type(readfile) ~= "function" then return false end
    local ok, content = pcall(function() return readfile(SAVE_FILE) end)
    if not ok or not content or content == "" then return false end
    local data = jsonDec(content)
    if type(data) ~= "table" then return false end
    if type(data.slots) == "table" then
        for name, slot in pairs(data.slots) do
            S.slots[name] = {id = slot.id or ""}
        end
    end
    if type(data.favEmotes) == "table" then
        for _, id in ipairs(data.favEmotes) do
            S.favEmotes[id] = true
        end
    end
    if type(data.customEmotes) == "table" then S.customEmotes = data.customEmotes end
    if type(data.packs)        == "table" then S.packs        = data.packs        end
    if data.speedMode then S.speedMode = data.speedMode end
    if data.speedMult then S.speedMult = tonumber(data.speedMult) or 1.0 end
    return true
end

local function initSlots()
    for _, name in ipairs(SLOTS) do
        if not S.slots[name] then
            S.slots[name] = {id = ""}
        end
    end
end

-- ════════════════════════════════════════════════════════
--  CHARACTER BINDING
-- ════════════════════════════════════════════════════════
local rigBadgeLbl  -- forward ref, set after UI build

local function detectRig()
    if not S.char then return "R15" end
    local h = S.char:FindFirstChildOfClass("Humanoid")
    if h and h.RigType == Enum.HumanoidRigType.R6 then return "R6" end
    return "R15"
end

local function onCharAdded(char)
    S.char     = char
    S.humanoid = char:WaitForChild("Humanoid", 10)
    S.rigType  = detectRig()
    ensureAnimator()
    initSlots()
    if rigBadgeLbl then rigBadgeLbl.Text = S.rigType end
    toast("Character ready: " .. S.rigType, "success")
end

-- ════════════════════════════════════════════════════════
--  TOGGLE BUTTON
-- ════════════════════════════════════════════════════════
local toggleOuter = mkFrame({
    Color    = C.AccentDk,
    Size     = UDim2.new(0,50,0,50),
    Position = UDim2.new(1,-62,0.5,80),
    ZIndex   = 100, Parent = gui,
})
mkCorner(14, toggleOuter)
mkStroke(C.Accent, 1.5, toggleOuter)

local toggleIcon = mkLabel("▶", 20, C.White, FB, toggleOuter)
toggleIcon.TextXAlignment = Enum.TextXAlignment.Center
toggleIcon.ZIndex         = 101

local toggleHit = Instance.new("TextButton")
toggleHit.Size               = UDim2.new(1,0,1,0)
toggleHit.BackgroundTransparency = 1
toggleHit.Text               = ""
toggleHit.ZIndex             = 102
toggleHit.Parent             = toggleOuter

mkDraggable(toggleOuter, toggleOuter)

-- ════════════════════════════════════════════════════════
--  MAIN WINDOW
-- ════════════════════════════════════════════════════════
local win = mkFrame({
    Color = C.Bg,
    Size  = UDim2.new(0,WIN_W,0,WIN_H),
    Position = UDim2.new(0.5,-WIN_W/2, 0.5,-WIN_H/2),
    ZIndex = 10, Clip = true, Parent = gui,
})
win.Visible = false
mkCorner(14, win)
mkStroke(C.Border, 1.5, win)

-- ── Title bar ──────────────────────────────────────────
local titleBar = mkFrame({
    Color    = C.Surface,
    Size     = UDim2.new(1,0,0,46),
    ZIndex   = 11, Parent = win,
})
mkCorner(14, titleBar)

local stripe = mkFrame({
    Color    = C.Accent,
    Size     = UDim2.new(0,3,0,28),
    Position = UDim2.new(0,0,0.5,-14),
    ZIndex   = 12, Parent = titleBar,
})
mkCorner(2, stripe)

local titleLbl = mkLabel("  Animation Studio", 15, C.Text, FB, titleBar)
titleLbl.Size     = UDim2.new(0,220,1,0)
titleLbl.Position = UDim2.new(0,4,0,0)
titleLbl.ZIndex   = 12

local rigBadge = mkFrame({
    Color    = C.AccentDim,
    Size     = UDim2.new(0,44,0,22),
    Position = UDim2.new(0,228,0.5,-11),
    ZIndex   = 12, Parent = titleBar,
})
mkCorner(6, rigBadge)
rigBadgeLbl = mkLabel("R15", 11, C.Accent, FM, rigBadge)
rigBadgeLbl.TextXAlignment = Enum.TextXAlignment.Center
rigBadgeLbl.ZIndex         = 13

local winCloseBtn = mkBtn("✕", C.Surface, C.Danger, titleBar)
winCloseBtn.Size     = UDim2.new(0,32,0,32)
winCloseBtn.Position = UDim2.new(1,-40,0.5,-16)
winCloseBtn.TextSize = 15
winCloseBtn.ZIndex   = 12

mkDraggable(titleBar, win)

-- ── Left sidebar ───────────────────────────────────────
local sidebar = mkFrame({
    Color    = C.Surface,
    Size     = UDim2.new(0,110,1,-46),
    Position = UDim2.new(0,0,0,46),
    ZIndex   = 11, Parent = win,
})
mkPad(8,8,6,6,sidebar)
mkList(Enum.FillDirection.Vertical,4,sidebar)

mkFrame({Color=C.Border, Size=UDim2.new(0,1,1,-46), Position=UDim2.new(0,110,0,46), ZIndex=11, Parent=win})

-- ── Content area ───────────────────────────────────────
local contentArea = mkFrame({
    Color    = C.Bg,
    Size     = UDim2.new(1,-111,1,-46),
    Position = UDim2.new(0,111,0,46),
    Clip     = true, ZIndex = 11, Parent = win,
})

-- ── Status bar ─────────────────────────────────────────
local statusBar = mkFrame({
    Color    = C.Surface,
    Size     = UDim2.new(1,-111,0,22),
    Position = UDim2.new(0,111,1,-22),
    ZIndex   = 12, Parent = win,
})
mkPad(0,0,8,8,statusBar)
local statusLbl = mkLabel("Ready", 11, C.TextMuted, FR, statusBar)
statusLbl.ZIndex = 13

local function setStatus(msg) statusLbl.Text = msg or "Ready" end

-- ════════════════════════════════════════════════════════
--  TAB SYSTEM
-- ════════════════════════════════════════════════════════
local tabDefs = {
    {id="Home",   label="Home",   icon="🏠"},
    {id="Packs",  label="Packs",  icon="📦"},
    {id="Emotes", label="Emotes", icon="✨"},
}

local tabData    = {}   -- [id] = {btn, indicator, iconL, nameL, frame}
local activeTabId = nil

for i, def in ipairs(tabDefs) do
    local btn = Instance.new("TextButton")
    btn.Name               = "Tab_" .. def.id
    btn.Size               = UDim2.new(1,0,0,44)
    btn.BackgroundColor3   = C.Card
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel    = 0
    btn.Text               = ""
    btn.LayoutOrder        = i
    btn.AutoButtonColor    = false
    mkCorner(8, btn)
    btn.Parent = sidebar

    local indicator = mkFrame({
        Color    = C.Accent,
        Size     = UDim2.new(0,3,0.6,0),
        Position = UDim2.new(0,0,0.2,0),
        ZIndex   = 12, Parent = btn,
    })
    mkCorner(2, indicator)
    indicator.Visible = false

    local iconL = mkLabel(def.icon, 15, C.TextMuted, FR, btn)
    iconL.Size     = UDim2.new(0,28,1,0)
    iconL.Position = UDim2.new(0,6,0,0)
    iconL.TextXAlignment = Enum.TextXAlignment.Center
    iconL.ZIndex   = 12

    local nameL = mkLabel(def.label, 12, C.TextMuted, FM, btn)
    nameL.Size     = UDim2.new(1,-36,1,0)
    nameL.Position = UDim2.new(0,36,0,0)
    nameL.ZIndex   = 12

    local frame = mkFrame({
        Color  = C.Bg,
        Size   = UDim2.new(1,0,1,-22),
        ZIndex = 11, Parent = contentArea,
    })
    frame.Visible = false

    tabData[def.id] = {
        btn = btn, indicator = indicator,
        iconL = iconL, nameL = nameL, frame = frame,
    }
end

local function switchTab(id)
    if activeTabId == id then return end
    if activeTabId and tabData[activeTabId] then
        local old = tabData[activeTabId]
        old.indicator.Visible = false
        old.frame.Visible     = false
        tw(old.btn,   {BackgroundTransparency = 1})
        tw(old.iconL, {TextColor3 = C.TextMuted})
        tw(old.nameL, {TextColor3 = C.TextMuted})
    end
    activeTabId = id
    local cur = tabData[id]
    cur.indicator.Visible    = true
    cur.frame.Visible        = true
    cur.btn.BackgroundColor3 = C.Card
    tw(cur.btn,   {BackgroundTransparency = 0})
    tw(cur.iconL, {TextColor3 = C.Accent})
    tw(cur.nameL, {TextColor3 = C.Text})
    setStatus("Tab: " .. id)
end

for _, def in ipairs(tabDefs) do
    local tid = def.id
    tabData[tid].btn.MouseButton1Click:Connect(function() switchTab(tid) end)
    tabData[tid].btn.MouseEnter:Connect(function()
        if activeTabId ~= tid then
            tw(tabData[tid].btn, {BackgroundTransparency = 0.7})
        end
    end)
    tabData[tid].btn.MouseLeave:Connect(function()
        if activeTabId ~= tid then
            tw(tabData[tid].btn, {BackgroundTransparency = 1})
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  HOME TAB — ANIMATION SLOTS
-- ════════════════════════════════════════════════════════
local homeFrame   = tabData["Home"].frame
local selSlot     = nil
local slotEls     = {}   -- [slotName] = {btn,indicator,lbl,dot}

-- Left: slot list panel
local slotPanel = mkFrame({Color=C.Surface, Size=UDim2.new(0,148,1,0), ZIndex=12, Parent=homeFrame})

local slotTitleL = mkLabel("ANIMATION SLOTS", 10, C.TextMuted, FM, slotPanel)
slotTitleL.Size     = UDim2.new(1,-16,0,26)
slotTitleL.Position = UDim2.new(0,8,0,0)
slotTitleL.ZIndex   = 13

mkFrame({Color=C.Border, Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,0,26), ZIndex=12, Parent=slotPanel})

local slotScroll = mkScroll(slotPanel)
slotScroll.Size     = UDim2.new(1,0,1,-27)
slotScroll.Position = UDim2.new(0,0,0,27)
slotScroll.ZIndex   = 12
mkPad(4,4,5,5,slotScroll)
mkList(Enum.FillDirection.Vertical,3,slotScroll)

-- Right: detail panel
mkFrame({Color=C.Border, Size=UDim2.new(0,1,1,0), Position=UDim2.new(0,148,0,0), ZIndex=12, Parent=homeFrame})
local detailPanel = mkFrame({Color=C.Bg, Size=UDim2.new(1,-149,1,0), Position=UDim2.new(0,149,0,0), ZIndex=12, Parent=homeFrame})
mkPad(14,14,16,16,detailPanel)

local detSlotName = mkLabel("Select a slot", 18, C.Text, FB, detailPanel)
detSlotName.Size     = UDim2.new(1,0,0,28)
detSlotName.Position = UDim2.new(0,0,0,0)
detSlotName.ZIndex   = 13

local detStatusF = mkFrame({Color=C.Card, Size=UDim2.new(0,230,0,22), Position=UDim2.new(0,0,0,32), ZIndex=13, Parent=detailPanel})
mkCorner(6, detStatusF)
local detStatusL = mkLabel("Using Roblox Default", 11, C.TextMuted, FR, detStatusF)
detStatusL.Size     = UDim2.new(1,-10,1,0)
detStatusL.Position = UDim2.new(0,6,0,0)
detStatusL.ZIndex   = 14

local idRowLabel = mkLabel("Animation ID", 12, C.TextSub, FM, detailPanel)
idRowLabel.Size     = UDim2.new(1,0,0,18)
idRowLabel.Position = UDim2.new(0,0,0,62)
idRowLabel.ZIndex   = 13

local idIF, idBox = mkInput("Enter Animation ID  (blank = use default)", detailPanel)
idIF.Size     = UDim2.new(1,0,0,34)
idIF.Position = UDim2.new(0,0,0,82)
idIF.ZIndex   = 13
idBox.ZIndex  = 14

local sourceL = mkLabel("Default ID: —", 11, C.TextMuted, FR, detailPanel)
sourceL.Size     = UDim2.new(1,0,0,16)
sourceL.Position = UDim2.new(0,0,0,120)
sourceL.ZIndex   = 13

-- Button row
local detBtnRow = mkFrame({Color=C.Bg, Transparency=1, Size=UDim2.new(1,0,0,36), Position=UDim2.new(0,0,0,142), ZIndex=13, Parent=detailPanel})
mkList(Enum.FillDirection.Horizontal,8,detBtnRow)

local applyBtn   = mkBtn("Apply ID",  C.Accent,  C.AccentDk,  detBtnRow)
applyBtn.Size        = UDim2.new(0,90,0,34)
applyBtn.LayoutOrder = 1; applyBtn.ZIndex = 14

local previewBtn = mkBtn("Preview",   C.Card,    C.CardHov,   detBtnRow)
previewBtn.Size      = UDim2.new(0,90,0,34)
previewBtn.LayoutOrder = 2; previewBtn.ZIndex = 14

local stopSlotBtn = mkBtn("Stop",     C.Card,    C.Danger,    detBtnRow)
stopSlotBtn.Size     = UDim2.new(0,68,0,34)
stopSlotBtn.LayoutOrder = 3; stopSlotBtn.ZIndex = 14

local resetSlotBtn = mkBtn("Reset",   C.Card,    C.Danger,    detBtnRow)
resetSlotBtn.Size    = UDim2.new(0,68,0,34)
resetSlotBtn.LayoutOrder = 4; resetSlotBtn.ZIndex = 14

local stopAllBtn = mkBtn("■ Stop All Animations", C.Card, C.Danger, detailPanel)
stopAllBtn.Size     = UDim2.new(0,192,0,32)
stopAllBtn.Position = UDim2.new(0,0,0,186)
stopAllBtn.ZIndex   = 13

-- Speed section
local speedTitleL = mkLabel("Playback Speed", 12, C.TextSub, FM, detailPanel)
speedTitleL.Size     = UDim2.new(1,0,0,18)
speedTitleL.Position = UDim2.new(0,0,0,228)
speedTitleL.ZIndex   = 13

local speedModeRow = mkFrame({Color=C.Bg, Transparency=1, Size=UDim2.new(1,0,0,34), Position=UDim2.new(0,0,0,248), ZIndex=13, Parent=detailPanel})
mkList(Enum.FillDirection.Horizontal,6,speedModeRow)

local dynBtn  = mkBtn("Dynamic", C.Accent, C.AccentDk,  speedModeRow)
dynBtn.Size        = UDim2.new(0,90,0,32)
dynBtn.LayoutOrder = 1; dynBtn.ZIndex = 14

local statBtn = mkBtn("Static",  C.Card,   C.CardHov,   speedModeRow)
statBtn.Size       = UDim2.new(0,90,0,32)
statBtn.LayoutOrder = 2; statBtn.ZIndex = 14

local multL = mkLabel("Multiplier: 1.0x", 11, C.TextMuted, FR, detailPanel)
multL.Size     = UDim2.new(1,0,0,16)
multL.Position = UDim2.new(0,0,0,288)
multL.ZIndex   = 13

local sliderFrame = mkFrame({Color=C.Card, Size=UDim2.new(0,200,0,10), Position=UDim2.new(0,0,0,308), ZIndex=13, Parent=detailPanel})
mkCorner(5, sliderFrame)
local sliderFill = mkFrame({Color=C.Accent, Size=UDim2.new(0.33,0,1,0), ZIndex=14, Parent=sliderFrame})
mkCorner(5, sliderFill)

-- Detail refresh
local function refreshDetail(name)
    if not name then return end
    detSlotName.Text = name
    local slot = S.slots[name] or {id=""}
    idBox.Text = slot.id or ""
    local defs = DEFAULT_IDS[S.rigType] or DEFAULT_IDS.R15
    if slot.id and slot.id ~= "" then
        detStatusL.Text      = "Custom ID Active"
        detStatusL.TextColor3 = C.Accent
        tw(detStatusF, {BackgroundColor3 = C.AccentDim})
        sourceL.Text = "Custom: " .. slot.id
    else
        detStatusL.Text      = "Using Roblox Default"
        detStatusL.TextColor3 = C.TextMuted
        tw(detStatusF, {BackgroundColor3 = C.Card})
        sourceL.Text = "Default ID: " .. (defs[name] or "none")
    end
end

local function selectSlot(name)
    if selSlot and slotEls[selSlot] then
        local el = slotEls[selSlot]
        el.indicator.Visible = false
        tw(el.btn, {BackgroundTransparency = 1})
        tw(el.lbl, {TextColor3 = C.TextSub})
    end
    selSlot = name
    if slotEls[name] then
        local el = slotEls[name]
        el.btn.BackgroundColor3 = C.Card
        el.indicator.Visible    = true
        tw(el.btn, {BackgroundTransparency = 0})
        tw(el.lbl, {TextColor3 = C.Text})
    end
    refreshDetail(name)
end

-- Build slot buttons
for i, name in ipairs(SLOTS) do
    local btn = Instance.new("TextButton")
    btn.Name               = "Slot_" .. name
    btn.Size               = UDim2.new(1,0,0,38)
    btn.BackgroundColor3   = C.Card
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel    = 0
    btn.Text               = ""
    btn.LayoutOrder        = i
    btn.AutoButtonColor    = false
    btn.ZIndex             = 13
    mkCorner(6, btn)
    btn.Parent = slotScroll

    local indicator = mkFrame({Color=C.Accent, Size=UDim2.new(0,3,0.6,0), Position=UDim2.new(0,0,0.2,0), ZIndex=14, Parent=btn})
    mkCorner(2, indicator)
    indicator.Visible = false

    local lbl = mkLabel(name, 13, C.TextSub, FM, btn)
    lbl.Size     = UDim2.new(1,-30,0.6,0)
    lbl.Position = UDim2.new(0,10,0,5)
    lbl.ZIndex   = 14

    local dot = mkFrame({Color=C.TextMuted, Size=UDim2.new(0,6,0,6), Position=UDim2.new(0,10,0.5,4), ZIndex=14, Parent=btn})
    mkCorner(3, dot)

    slotEls[name] = {btn=btn, indicator=indicator, lbl=lbl, dot=dot}

    local sn = name
    btn.MouseButton1Click:Connect(function() selectSlot(sn) end)
    btn.MouseEnter:Connect(function()
        if selSlot ~= sn then tw(btn,{BackgroundTransparency=0.7}) end
    end)
    btn.MouseLeave:Connect(function()
        if selSlot ~= sn then tw(btn,{BackgroundTransparency=1}) end
    end)
end

applyBtn.MouseButton1Click:Connect(function()
    if not selSlot then return end
    local id = idBox.Text
    if id ~= "" and not validID(id) then toast("Invalid ID", "error"); return end
    S.slots[selSlot] = {id = normID(id)}
    local dot = slotEls[selSlot] and slotEls[selSlot].dot
    if dot then tw(dot, {BackgroundColor3 = id ~= "" and C.Success or C.TextMuted}) end
    refreshDetail(selSlot)
    toast("Applied to " .. selSlot, "success")
    saveData()
end)

previewBtn.MouseButton1Click:Connect(function()
    if not selSlot then return end
    playSlot(selSlot)
    toast("Playing: " .. selSlot, "success")
end)

stopSlotBtn.MouseButton1Click:Connect(function()
    if not selSlot then return end
    stopSlot(selSlot)
    toast("Stopped: " .. selSlot, "warn")
end)

resetSlotBtn.MouseButton1Click:Connect(function()
    if not selSlot then return end
    S.slots[selSlot] = {id = ""}
    stopSlot(selSlot)
    local dot = slotEls[selSlot] and slotEls[selSlot].dot
    if dot then tw(dot, {BackgroundColor3 = C.TextMuted}) end
    refreshDetail(selSlot)
    toast("Reset: " .. selSlot, "warn")
    saveData()
end)

stopAllBtn.MouseButton1Click:Connect(function()
    stopAllSlots()
    toast("All animations stopped", "warn")
end)

local function updateSpeedUI()
    if S.speedMode == "Dynamic" then
        tw(dynBtn,  {BackgroundColor3 = C.Accent})
        tw(statBtn, {BackgroundColor3 = C.Card})
    else
        tw(dynBtn,  {BackgroundColor3 = C.Card})
        tw(statBtn, {BackgroundColor3 = C.Accent})
    end
    multL.Text = "Multiplier: " .. string.format("%.1f", S.speedMult) .. "x"
    tw(sliderFill, {Size = UDim2.new(S.speedMult / 3, 0, 1, 0)})
end

dynBtn.MouseButton1Click:Connect(function()
    S.speedMode = "Dynamic"; updateSpeedUI()
end)
statBtn.MouseButton1Click:Connect(function()
    S.speedMode = "Static"; updateSpeedUI()
end)

-- Speed slider
do
    local spDrag = false
    sliderFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            spDrag = true
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not spDrag then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local rel  = inp.Position.X - sliderFrame.AbsolutePosition.X
        local frac = math.clamp(rel / math.max(sliderFrame.AbsoluteSize.X, 1), 0, 1)
        S.speedMult = math.clamp(frac * 3, 0.1, 3.0)
        updateSpeedUI()
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            spDrag = false
        end
    end)
end

selectSlot("Idle")
updateSpeedUI()

-- ════════════════════════════════════════════════════════
--  PACKS TAB
-- ════════════════════════════════════════════════════════
local packsFrame  = tabData["Packs"].frame

local packsTopBar = mkFrame({Color=C.Surface, Size=UDim2.new(1,0,0,46), ZIndex=12, Parent=packsFrame})
mkPad(6,6,8,8,packsTopBar)
mkList(Enum.FillDirection.Horizontal,8,packsTopBar)

local packsTitleL = mkLabel("Animation Packs", 15, C.Text, FB, packsTopBar)
packsTitleL.Size        = UDim2.new(0,160,0,32)
packsTitleL.LayoutOrder = 1
packsTitleL.ZIndex      = 13

local savePackBtn = mkBtn("+ Save Current", C.Accent, C.AccentDk, packsTopBar)
savePackBtn.Size        = UDim2.new(0,130,0,32)
savePackBtn.LayoutOrder = 2
savePackBtn.ZIndex      = 13

local packsScroll = mkScroll(packsFrame)
packsScroll.Size     = UDim2.new(1,0,1,-46)
packsScroll.Position = UDim2.new(0,0,0,46)
packsScroll.ZIndex   = 12
mkPad(8,8,8,8,packsScroll)
mkList(Enum.FillDirection.Vertical,8,packsScroll)

local function renderPacks()
    for _, c in ipairs(packsScroll:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end

    -- Built-in section header
    local hdr = mkLabel("── Built-in Defaults ──", 11, C.TextMuted, FR, packsScroll)
    hdr.Size              = UDim2.new(1,0,0,20)
    hdr.LayoutOrder       = 1
    hdr.TextXAlignment    = Enum.TextXAlignment.Center
    hdr.ZIndex            = 13

    local builtins = {
        {name="Default R15", slots=DEFAULT_IDS.R15},
        {name="Default R6",  slots=DEFAULT_IDS.R6},
    }

    for bi, pack in ipairs(builtins) do
        local row = mkFrame({Color=C.Card, Size=UDim2.new(1,0,0,48), ZIndex=13, Parent=packsScroll})
        row.LayoutOrder = bi + 1
        mkCorner(8,row); mkStroke(C.Border,1,row)

        local abar = mkFrame({Color=C.Accent, Size=UDim2.new(0,3,0.6,0), Position=UDim2.new(0,0,0.2,0), ZIndex=14, Parent=row})
        mkCorner(2,abar)

        local nl = mkLabel(pack.name, 13, C.Text, FM, row)
        nl.Size     = UDim2.new(1,-100,0.6,0)
        nl.Position = UDim2.new(0,12,0,4); nl.ZIndex = 14

        local cnt = 0
        for _ in pairs(pack.slots) do cnt = cnt + 1 end
        local il = mkLabel(tostring(cnt) .. " slots", 11, C.TextMuted, FR, row)
        il.Size     = UDim2.new(1,-100,0.4,0)
        il.Position = UDim2.new(0,12,0.6,0); il.ZIndex = 14

        local ub = mkBtn("Use", C.Accent, C.AccentDk, row)
        ub.Size     = UDim2.new(0,56,0,30)
        ub.Position = UDim2.new(1,-68,0.5,-15)
        ub.ZIndex   = 14
        local packRef = pack
        ub.MouseButton1Click:Connect(function()
            for sn, id in pairs(packRef.slots) do
                S.slots[sn] = {id = id}
                if slotEls[sn] then tw(slotEls[sn].dot,{BackgroundColor3=C.Success}) end
            end
            refreshDetail(selSlot)
            toast("Applied: " .. packRef.name, "success")
            saveData()
        end)
    end

    -- User packs
    if #S.packs > 0 then
        local uhdr = mkLabel("── Saved Packs ──", 11, C.TextMuted, FR, packsScroll)
        uhdr.Size           = UDim2.new(1,0,0,20)
        uhdr.LayoutOrder    = 10
        uhdr.TextXAlignment = Enum.TextXAlignment.Center
        uhdr.ZIndex         = 13

        for pi, pack in ipairs(S.packs) do
            local row = mkFrame({Color=C.Card, Size=UDim2.new(1,0,0,48), ZIndex=13, Parent=packsScroll})
            row.LayoutOrder = 10 + pi
            mkCorner(8,row); mkStroke(C.Border,1,row)

            local abar2 = mkFrame({Color=C.Success, Size=UDim2.new(0,3,0.6,0), Position=UDim2.new(0,0,0.2,0), ZIndex=14, Parent=row})
            mkCorner(2,abar2)

            local nl2 = mkLabel(pack.name, 13, C.Text, FM, row)
            nl2.Size     = UDim2.new(1,-120,0.6,0)
            nl2.Position = UDim2.new(0,12,0,4); nl2.ZIndex = 14

            local cnt2 = 0
            for _ in pairs(pack.slots or {}) do cnt2 = cnt2 + 1 end
            local il2 = mkLabel(tostring(cnt2) .. " slots", 11, C.TextMuted, FR, row)
            il2.Size     = UDim2.new(1,-120,0.4,0)
            il2.Position = UDim2.new(0,12,0.6,0); il2.ZIndex = 14

            local ub2 = mkBtn("Use", C.Accent, C.AccentDk, row)
            ub2.Size     = UDim2.new(0,48,0,28)
            ub2.Position = UDim2.new(1,-106,0.5,-14)
            ub2.ZIndex   = 14
            local packRef2 = pack
            ub2.MouseButton1Click:Connect(function()
                for sn, id in pairs(packRef2.slots or {}) do
                    S.slots[sn] = {id = id}
                    if slotEls[sn] then tw(slotEls[sn].dot,{BackgroundColor3=C.Success}) end
                end
                refreshDetail(selSlot)
                toast("Applied: " .. packRef2.name, "success")
            end)

            local db2 = mkBtn("✕", C.Card, C.Danger, row)
            db2.Size     = UDim2.new(0,28,0,28)
            db2.Position = UDim2.new(1,-54,0.5,-14)
            db2.ZIndex   = 14
            local pidx = pi
            db2.MouseButton1Click:Connect(function()
                table.remove(S.packs, pidx)
                renderPacks(); saveData()
            end)
        end
    end
end

savePackBtn.MouseButton1Click:Connect(function()
    local pack = {name = "Pack " .. tostring(#S.packs + 1), slots = {}}
    for name, slot in pairs(S.slots) do
        if slot.id and slot.id ~= "" then
            pack.slots[name] = slot.id
        end
    end
    table.insert(S.packs, pack)
    renderPacks()
    toast("Pack saved!", "success")
    saveData()
end)

-- ════════════════════════════════════════════════════════
--  EMOTES TAB
-- ════════════════════════════════════════════════════════
local emotesFrame = tabData["Emotes"].frame

local eTopBar = mkFrame({Color=C.Surface, Size=UDim2.new(1,0,0,50), ZIndex=12, Parent=emotesFrame})
mkPad(7,7,8,8,eTopBar)
mkList(Enum.FillDirection.Horizontal,6,eTopBar)

local eSF, eSBox = mkInput("Search emotes...", eTopBar)
eSF.Size = UDim2.new(0,200,0,34); eSF.LayoutOrder = 1; eSF.ZIndex = 13

local favTogBtn = mkBtn("★ Favs", C.Card, C.Gold, eTopBar)
favTogBtn.Size = UDim2.new(0,80,0,34); favTogBtn.LayoutOrder = 2; favTogBtn.ZIndex = 13

local addEBtn = mkBtn("+ Add ID", C.Accent, C.AccentDk, eTopBar)
addEBtn.Size = UDim2.new(0,90,0,34); addEBtn.LayoutOrder = 3; addEBtn.ZIndex = 13

local floatPanelOpenBtn = mkBtn("⊞ Floats", C.Card, C.CardHov, eTopBar)
floatPanelOpenBtn.Size = UDim2.new(0,80,0,34); floatPanelOpenBtn.LayoutOrder = 4; floatPanelOpenBtn.ZIndex = 13

-- Add-emote input row (hidden by default)
local addRow = mkFrame({Color=C.Surface, Size=UDim2.new(1,0,0,46), Position=UDim2.new(0,0,0,50), ZIndex=12, Parent=emotesFrame})
addRow.Visible = false
mkPad(6,6,8,8,addRow)
mkList(Enum.FillDirection.Horizontal,6,addRow)

local addIF, addIBox = mkInput("Paste Animation ID...", addRow)
addIF.Size = UDim2.new(0,220,0,32); addIF.LayoutOrder = 1; addIF.ZIndex = 13

local addNF, addNBox = mkInput("Name (optional)", addRow)
addNF.Size = UDim2.new(0,160,0,32); addNF.LayoutOrder = 2; addNF.ZIndex = 13

local confirmAddBtn = mkBtn("Add", C.Success, C.Accent, addRow)
confirmAddBtn.Size = UDim2.new(0,60,0,32); confirmAddBtn.LayoutOrder = 3; confirmAddBtn.ZIndex = 13

-- Grid
local eGrid = mkScroll(emotesFrame)
eGrid.Size     = UDim2.new(1,0,1,-50)
eGrid.Position = UDim2.new(0,0,0,50)
eGrid.ZIndex   = 12
mkPad(10,10,10,10,eGrid)

local gridL = Instance.new("UIGridLayout")
gridL.CellSize            = UDim2.new(0,112,0,128)
gridL.CellPadding         = UDim2.new(0,8,0,8)
gridL.FillDirection       = Enum.FillDirection.Horizontal
gridL.HorizontalAlignment = Enum.HorizontalAlignment.Left
gridL.SortOrder           = Enum.SortOrder.LayoutOrder
gridL.Parent              = eGrid

local showFavs      = false
local allEmotes     = {}
local filteredEmotes = {}

local function buildAllEmotes()
    allEmotes = {}
    for _, e in ipairs(BUILTIN_EMOTES) do
        table.insert(allEmotes, {name=e.name, id=e.id, source="Built-in"})
    end
    for _, e in ipairs(S.customEmotes) do
        table.insert(allEmotes, e)
    end
end

local function filterEmotes(q)
    filteredEmotes = {}
    q = (q or ""):lower()
    for _, e in ipairs(allEmotes) do
        local favOk  = not showFavs or S.favEmotes[e.id]
        local nameOk = q == "" or e.name:lower():find(q, 1, true)
        local idOk   = q == "" or e.id:find(q, 1, true)
        if favOk and (nameOk or idOk) then
            table.insert(filteredEmotes, e)
        end
    end
end

local function renderEmotes()
    for _, c in ipairs(eGrid:GetChildren()) do
        if not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end

    for ord, emote in ipairs(filteredEmotes) do
        local card = mkFrame({Color=C.Card, ZIndex=13, Parent=eGrid})
        card.LayoutOrder = ord
        mkCorner(10, card); mkStroke(C.Border, 1, card)

        local nL = mkLabel(emote.name, 11, C.Text, FM, card)
        nL.Size     = UDim2.new(1,-22,0,18)
        nL.Position = UDim2.new(0,4,1,-42)
        nL.ZIndex   = 14
        nL.TextTruncate = Enum.TextTruncate.AtEnd

        local iL = mkLabel(emote.id, 9, C.TextMuted, FR, card)
        iL.Size     = UDim2.new(1,-8,0,14)
        iL.Position = UDim2.new(0,4,1,-22)
        iL.ZIndex   = 14
        iL.TextTruncate = Enum.TextTruncate.AtEnd

        -- Star
        local eid    = emote.id
        local starB  = Instance.new("TextButton")
        starB.Size               = UDim2.new(0,18,0,18)
        starB.Position           = UDim2.new(1,-20,1,-42)
        starB.BackgroundTransparency = 1
        starB.Text               = S.favEmotes[eid] and "★" or "☆"
        starB.TextColor3         = S.favEmotes[eid] and C.Gold or C.TextMuted
        starB.Font               = FB
        starB.TextSize           = 13
        starB.ZIndex             = 15
        starB.Parent             = card
        starB.MouseButton1Click:Connect(function()
            S.favEmotes[eid]   = not S.favEmotes[eid]
            starB.Text         = S.favEmotes[eid] and "★" or "☆"
            starB.TextColor3   = S.favEmotes[eid] and C.Gold or C.TextMuted
            saveData()
        end)

        -- Float icon button
        local floatIB = Instance.new("TextButton")
        floatIB.Size               = UDim2.new(0,18,0,18)
        floatIB.Position           = UDim2.new(0,2,0,2)
        floatIB.BackgroundColor3   = C.AccentDim
        floatIB.BackgroundTransparency = 0.5
        floatIB.BorderSizePixel    = 0
        floatIB.Text               = "⊞"
        floatIB.TextColor3         = C.Accent
        floatIB.Font               = FB
        floatIB.TextSize           = 10
        floatIB.ZIndex             = 15
        mkCorner(4, floatIB)
        floatIB.Parent             = card
        local emRef = emote
        floatIB.MouseButton1Click:Connect(function()
            addFloatEmote(emRef)
            toast("Floated: " .. emRef.name, "success")
        end)

        -- Main click area
        local clickB = Instance.new("TextButton")
        clickB.Size               = UDim2.new(1,0,1,-44)
        clickB.BackgroundTransparency = 1
        clickB.Text               = ""
        clickB.ZIndex             = 14
        clickB.Parent             = card
        local emRef2 = emote
        clickB.MouseButton1Click:Connect(function()
            playEmote(emRef2.id)
            toast("Playing: " .. emRef2.name, "success")
        end)
        clickB.MouseEnter:Connect(function() tw(card,{BackgroundColor3=C.CardHov}) end)
        clickB.MouseLeave:Connect(function() tw(card,{BackgroundColor3=C.Card})    end)
    end

    if #filteredEmotes == 0 then
        local el = mkLabel("No emotes found.", 13, C.TextMuted, FR, eGrid)
        el.Size             = UDim2.new(0,200,0,40)
        el.ZIndex           = 13
        el.TextXAlignment   = Enum.TextXAlignment.Center
    end
end

eSBox:GetPropertyChangedSignal("Text"):Connect(function()
    filterEmotes(eSBox.Text); renderEmotes()
end)

favTogBtn.MouseButton1Click:Connect(function()
    showFavs = not showFavs
    tw(favTogBtn, {BackgroundColor3 = showFavs and C.Gold or C.Card})
    favTogBtn.TextColor3 = showFavs and Color3.fromRGB(20,20,20) or C.White
    filterEmotes(eSBox.Text); renderEmotes()
end)

local addRowOpen = false
addEBtn.MouseButton1Click:Connect(function()
    addRowOpen = not addRowOpen
    addRow.Visible = addRowOpen
    if addRowOpen then
        eGrid.Size     = UDim2.new(1,0,1,-96)
        eGrid.Position = UDim2.new(0,0,0,96)
    else
        eGrid.Size     = UDim2.new(1,0,1,-50)
        eGrid.Position = UDim2.new(0,0,0,50)
    end
end)

confirmAddBtn.MouseButton1Click:Connect(function()
    local id = normID(addIBox.Text)
    if not validID(id) then toast("Invalid ID", "error"); return end
    local name = addNBox.Text ~= "" and addNBox.Text or ("Custom " .. id:sub(1,8))
    table.insert(S.customEmotes, {name=name, id=id, source="Custom"})
    addIBox.Text = ""; addNBox.Text = ""
    addRow.Visible = false; addRowOpen = false
    eGrid.Size     = UDim2.new(1,0,1,-50)
    eGrid.Position = UDim2.new(0,0,0,50)
    buildAllEmotes(); filterEmotes(eSBox.Text); renderEmotes()
    toast("Added: " .. name, "success"); saveData()
end)

-- ════════════════════════════════════════════════════════
--  FLOATING EMOTE PANEL
-- ════════════════════════════════════════════════════════
local floatPanel = mkFrame({
    Color    = C.Surface,
    Size     = UDim2.new(0,220,0,260),
    Position = UDim2.new(0.5,-110,0.5,-130),
    ZIndex   = 80, Parent = gui,
})
floatPanel.Visible = false
mkCorner(12,floatPanel); mkStroke(C.Border,1,floatPanel)

local fpTitle = mkFrame({Color=C.Card, Size=UDim2.new(1,0,0,36), ZIndex=81, Parent=floatPanel})
mkCorner(12,fpTitle)
local fpTitleL = mkLabel("Floating Emotes", 14, C.Text, FB, fpTitle)
fpTitleL.Size = UDim2.new(1,-42,1,0); fpTitleL.Position = UDim2.new(0,10,0,0); fpTitleL.ZIndex = 82
local fpCloseB = mkBtn("✕", C.Card, C.Danger, fpTitle)
fpCloseB.Size     = UDim2.new(0,28,0,28)
fpCloseB.Position = UDim2.new(1,-34,0.5,-14)
fpCloseB.TextSize = 13; fpCloseB.ZIndex = 82
fpCloseB.MouseButton1Click:Connect(function() floatPanel.Visible = false end)
mkDraggable(fpTitle, floatPanel)

local fpScroll = mkScroll(floatPanel)
fpScroll.Size     = UDim2.new(1,0,1,-36)
fpScroll.Position = UDim2.new(0,0,0,36)
fpScroll.ZIndex   = 81
mkPad(4,4,6,6,fpScroll)
mkList(Enum.FillDirection.Vertical,4,fpScroll)

local fpEmptyL = mkLabel("Add emotes using the ⊞ button in the Emotes tab.", 11, C.TextMuted, FR, fpScroll)
fpEmptyL.Size = UDim2.new(1,0,0,44); fpEmptyL.ZIndex = 82; fpEmptyL.TextWrapped = true

floatPanelOpenBtn.MouseButton1Click:Connect(function()
    floatPanel.Visible = not floatPanel.Visible
end)

-- addFloatEmote — global so emote card buttons can call it
function addFloatEmote(emote)
    if S.floatBtns[emote.id] then return end

    local cnt = 0
    for _ in pairs(S.floatBtns) do cnt = cnt + 1 end
    local xOff = -70 - (cnt % 3) * 58
    local yOff =  80 + math.floor(cnt / 3) * 62

    local fbF = mkFrame({
        Color    = C.AccentDim,
        Size     = UDim2.new(0,52,0,52),
        Position = UDim2.new(1,xOff,0,yOff),
        ZIndex   = 70, Parent = gui,
    })
    mkCorner(14,fbF); mkStroke(C.Accent,1.5,fbF)

    local fbL = mkLabel(emote.name, 8, C.Text, FM, fbF)
    fbL.Size     = UDim2.new(1,0,0,13)
    fbL.Position = UDim2.new(0,0,1,-13)
    fbL.TextXAlignment = Enum.TextXAlignment.Center
    fbL.TextTruncate   = Enum.TextTruncate.AtEnd
    fbL.ZIndex   = 71

    local fbHit = Instance.new("TextButton")
    fbHit.Size               = UDim2.new(1,0,1,0)
    fbHit.BackgroundTransparency = 1
    fbHit.Text               = ""
    fbHit.ZIndex             = 72
    fbHit.Parent             = fbF

    local fbRem = Instance.new("TextButton")
    fbRem.Size               = UDim2.new(0,16,0,16)
    fbRem.Position           = UDim2.new(1,-18,0,2)
    fbRem.BackgroundColor3   = C.Danger
    fbRem.BackgroundTransparency = 0.3
    fbRem.BorderSizePixel    = 0
    fbRem.Text               = "✕"
    fbRem.TextColor3         = C.White
    fbRem.Font               = FB
    fbRem.TextSize           = 9
    fbRem.ZIndex             = 73
    mkCorner(4,fbRem)
    fbRem.Parent             = fbF

    -- Drag logic with tap detection
    local fbDrag, fbDS, fbSP, fbMoved = false, nil, nil, false

    fbHit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            fbDrag  = true
            fbMoved = false
            fbDS    = inp.Position
            fbSP    = fbF.Position
        end
    end)

    UIS.InputChanged:Connect(function(inp)
        if not fbDrag then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = inp.Position - fbDS
        if d.Magnitude > 6 then fbMoved = true end
        fbF.Position = UDim2.new(fbSP.X.Scale, fbSP.X.Offset + d.X,
                                  fbSP.Y.Scale, fbSP.Y.Offset + d.Y)
    end)

    UIS.InputEnded:Connect(function(inp)
        if not fbDrag then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        fbDrag = false
        if not fbMoved then
            playEmote(emote.id)
            toast(emote.name, "success")
        end
    end)

    local function removeFloat()
        S.floatBtns[emote.id] = nil
        fbF:Destroy()
        local row = fpScroll:FindFirstChild("FPRow_" .. emote.id)
        if row then row:Destroy() end
        fpEmptyL.Visible = (next(S.floatBtns) == nil)
    end

    fbRem.MouseButton1Click:Connect(removeFloat)

    S.floatBtns[emote.id] = {frame = fbF}
    fpEmptyL.Visible = false

    -- Panel list row
    local fpRow = mkFrame({Color=C.Card, Size=UDim2.new(1,0,0,32), ZIndex=82, Parent=fpScroll})
    fpRow.Name = "FPRow_" .. emote.id
    mkCorner(6, fpRow)

    local fpRowL = mkLabel(emote.name, 12, C.Text, FM, fpRow)
    fpRowL.Size     = UDim2.new(1,-36,1,0)
    fpRowL.Position = UDim2.new(0,8,0,0)
    fpRowL.ZIndex   = 83

    local fpRowRem = mkBtn("✕", C.Card, C.Danger, fpRow)
    fpRowRem.Size     = UDim2.new(0,26,0,26)
    fpRowRem.Position = UDim2.new(1,-30,0.5,-13)
    fpRowRem.TextSize = 11; fpRowRem.ZIndex = 83
    fpRowRem.MouseButton1Click:Connect(removeFloat)
end

-- ════════════════════════════════════════════════════════
--  TOGGLE WINDOW OPEN / CLOSE
-- ════════════════════════════════════════════════════════
local winOpen = false

local function openWin()
    if winOpen then return end
    winOpen = true
    win.Size    = UDim2.new(0,0,0,0)
    win.Position = UDim2.new(0.5,0,0.5,0)
    win.Visible  = true
    tw(win, {Size = UDim2.new(0,WIN_W,0,WIN_H), Position = UDim2.new(0.5,-WIN_W/2,0.5,-WIN_H/2)}, TIS)
    toggleIcon.Text = "✕"
    tw(toggleOuter, {BackgroundColor3 = C.Danger})
    renderPacks()
end

local function closeWin()
    if not winOpen then return end
    winOpen = false
    tw(win, {Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0)}, TIM)
    task.delay(0.27, function()
        if not winOpen then win.Visible = false end
    end)
    toggleIcon.Text = "▶"
    tw(toggleOuter, {BackgroundColor3 = C.AccentDk})
end

toggleHit.MouseButton1Click:Connect(function()
    if winOpen then closeWin() else openWin() end
end)

winCloseBtn.MouseButton1Click:Connect(closeWin)

-- ════════════════════════════════════════════════════════
--  DYNAMIC PLAYBACK SPEED LOOP
-- ════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if S.speedMode ~= "Dynamic" then return end
    if not S.char then return end
    local root = S.char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local vel   = root.AssemblyLinearVelocity
    local speed = Vector2.new(vel.X, vel.Z).Magnitude
    if speed <= 0.5 then return end
    local scaled = math.clamp(speed / 16, 0.1, 3.0) * S.speedMult
    for _, n in ipairs({"Walk","Run","Swim","Climb","Float"}) do
        local t = S.activeTracks[n]
        if t and t.IsPlaying then
            pcall(function() t:AdjustSpeed(scaled) end)
        end
    end
end)

-- ════════════════════════════════════════════════════════
--  INIT
-- ════════════════════════════════════════════════════════
task.spawn(function()
    local ok = loadData()
    initSlots()

    -- Refresh slot dot colors from loaded data
    for name, slot in pairs(S.slots) do
        if slotEls[name] and slot.id and slot.id ~= "" then
            tw(slotEls[name].dot, {BackgroundColor3 = C.Success})
        end
    end

    buildAllEmotes()
    filterEmotes("")
    renderEmotes()
    updateSpeedUI()

    if ok then
        toast("Settings loaded ✓", "success")
    else
        toast("Animation Studio ready!", "success")
    end
end)

-- Character binding
if LP.Character then
    task.spawn(function() onCharAdded(LP.Character) end)
end

LP.CharacterAdded:Connect(function(char)
    task.spawn(function() onCharAdded(char) end)
end)

-- Auto-save every 30 s
task.spawn(function()
    while task.wait(30) do
        saveData()
    end
end)

-- Start on Home tab
switchTab("Home")

print("[AnimStudio v2] Loaded — toggle button on the right side of your screen.")
