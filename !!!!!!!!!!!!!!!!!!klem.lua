--[[
    MobileUIScript.lua  v2
    Executor-compatible: Delta, Synapse X, Script-Ware, KRNL, Fluxus
    Client-sided | Saves via executor file I/O (writefile / readfile)

    FEATURES:
      · Draggable entry button → main menu (40 % screen)
      · Crosshair  – fixed aim point (NOT locked to centre)
          Toggle on/off  ·  Drag to any screen position (Edit mode)
          Custom decal ID  ·  Position is saved
      · Keyboard menu
          Key Picker – full computer keyboard layout + search bar
          Edit Layout – drag existing buttons around
          Settings → Saves – named slots with Load / Rename / Update / Delete
      · All state persists to  MobileUIScript_Data.json
]]

-- ─────────────────────────────────────────────────────────────
-- SERVICES
-- ─────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local LP      = Players.LocalPlayer
local PGui    = LP:WaitForChild("PlayerGui")
local Camera  = workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────
-- SAVE / LOAD  (executor file I/O)
-- ─────────────────────────────────────────────────────────────
local SAVE_FILE = "MobileUIScript_Data.json"

local function defaultData()
    return {
        crosshairEnabled = true,
        crosshairDecalId = "",
        crosshairX       = 0.5,   -- screen-scale anchor, 0.5 = centre
        crosshairY       = 0.5,
        activeKeybinds   = {},    -- { {key="E", x=0.5, y=0.5}, … }
        saves            = {},    -- { {name="…", keybinds={…}}, … }
    }
end

local function persist(data)
    pcall(function()
        if writefile then writefile(SAVE_FILE, HttpService:JSONEncode(data)) end
    end)
end

local function load()
    local ok, r = pcall(function()
        if isfile and isfile(SAVE_FILE) and readfile then
            return HttpService:JSONDecode(readfile(SAVE_FILE))
        end
    end)
    if ok and type(r) == "table" then
        local def = defaultData()
        for k, v in pairs(def) do if r[k] == nil then r[k] = v end end
        return r
    end
    return defaultData()
end

local Data = load()

-- ─────────────────────────────────────────────────────────────
-- CLEANUP  (re-run safety)
-- ─────────────────────────────────────────────────────────────
for _, n in ipairs({"MUIS_Main","MUIS_CH","MUIS_KB"}) do
    local g = PGui:FindFirstChild(n)
    if g then g:Destroy() end
end

-- ─────────────────────────────────────────────────────────────
-- SCREEN GUI CONTAINERS
-- ─────────────────────────────────────────────────────────────
local function makeGui(name, order, inset)
    local g = Instance.new("ScreenGui")
    g.Name, g.ResetOnSpawn, g.IgnoreGuiInset =
        name, false, inset or false
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    g.DisplayOrder   = order or 100
    g.Parent = PGui
    return g
end

local MainGui = makeGui("MUIS_Main", 100)
local CHGui   = makeGui("MUIS_CH",   99, true)
local KBGui   = makeGui("MUIS_KB",   98)

-- ─────────────────────────────────────────────────────────────
-- COLOUR PALETTE
-- ─────────────────────────────────────────────────────────────
local C = {
    bg      = Color3.fromRGB(20,  20,  20),
    panel   = Color3.fromRGB(29,  29,  29),
    item    = Color3.fromRGB(38,  38,  38),
    border  = Color3.fromRGB(55,  55,  55),
    text    = Color3.fromRGB(218, 218, 218),
    sub     = Color3.fromRGB(135, 135, 135),
    green   = Color3.fromRGB(68,  196, 138),
    blue    = Color3.fromRGB(55,  128, 210),
    red     = Color3.fromRGB(195, 65,  65),
    orange  = Color3.fromRGB(210, 140, 50),
    white   = Color3.fromRGB(255, 255, 255),
}

local FONT      = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local FONT_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

-- ─────────────────────────────────────────────────────────────
-- UI PRIMITIVES
-- ─────────────────────────────────────────────────────────────
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.Name, c.CornerRadius = "UICorner", UDim.new(0, r or 8)
    c.Parent = p; return c
end

local function stroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color, s.Thickness = col or C.border, th or 1
    s.Parent = p; return s
end

local function pad(p, l, r, t, b)
    local u = Instance.new("UIPadding")
    u.PaddingLeft, u.PaddingRight = UDim.new(0,l or 0), UDim.new(0,r or 0)
    u.PaddingTop,  u.PaddingBottom= UDim.new(0,t or 0), UDim.new(0,b or 0)
    u.Parent = p; return u
end

local function frm(parent, size, pos, col, tr, name, zi)
    local f = Instance.new("Frame")
    f.Size, f.Position       = size or UDim2.new(1,0,1,0), pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3       = col or C.bg
    f.BackgroundTransparency = tr or 0
    f.BorderSizePixel        = 0
    f.Active                 = true
    if name then f.Name = name end
    if zi   then f.ZIndex = zi  end
    f.Parent = parent; return f
end

local function lbl(parent, text, size, pos, col, fs, xa)
    local l = Instance.new("TextLabel")
    l.Size, l.Position       = size or UDim2.new(1,0,0,20), pos or UDim2.new(0,0,0,0)
    l.Text, l.TextColor3     = text or "", col or C.text
    l.BackgroundTransparency = 1
    l.BorderSizePixel        = 0
    l.FontFace               = FONT
    l.TextSize               = fs or 13
    l.TextXAlignment         = xa or Enum.TextXAlignment.Left
    l.Parent = parent; return l
end

local function tbx(parent, hint, size, pos)
    local t = Instance.new("TextBox")
    t.Size, t.Position       = size or UDim2.new(1,0,0,28), pos or UDim2.new(0,0,0,0)
    t.PlaceholderText        = hint or ""
    t.Text                   = ""
    t.TextColor3             = C.text
    t.PlaceholderColor3      = C.sub
    t.BackgroundColor3       = Color3.fromRGB(15,15,15)
    t.BorderSizePixel        = 0
    t.FontFace               = FONT
    t.TextSize               = 12
    t.ClearTextOnFocus       = false
    t.Parent = parent
    corner(t, 5); stroke(t, C.border, 1)
    return t
end

local function mkBtn(parent, text, size, pos, bg, tc, fs)
    bg = bg or C.item
    local b = Instance.new("TextButton")
    b.Size, b.Position       = size or UDim2.new(0,80,0,30), pos or UDim2.new(0,0,0,0)
    b.Text, b.TextColor3     = text or "", tc or C.text
    b.BackgroundColor3       = bg
    b.BorderSizePixel        = 0
    b.FontFace               = FONT
    b.TextSize               = fs or 13
    b.AutoButtonColor        = false
    b.Parent = parent
    corner(b, 6)
    local hi = bg:Lerp(C.white, 0.13)
    b.MouseButton1Down:Connect(function() TweenService:Create(b, TweenInfo.new(0.07), {BackgroundColor3=hi}):Play() end)
    b.MouseButton1Up:Connect(function()   TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=bg}):Play() end)
    b.MouseLeave:Connect(function()       TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=bg}):Play() end)
    return b
end

-- ─────────────────────────────────────────────────────────────
-- DRAGGABLE
-- ─────────────────────────────────────────────────────────────
local function makeDraggable(dragTarget, handle)
    handle = handle or dragTarget
    handle.Active = true
    local drag, dinp, dstart, dpos = false, nil, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag, dstart, dpos = true, i.Position, dragTarget.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then dinp = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i == dinp and drag then
            local d = i.Position - dstart
            dragTarget.Position = UDim2.new(dpos.X.Scale, dpos.X.Offset+d.X, dpos.Y.Scale, dpos.Y.Offset+d.Y)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- TOGGLE WIDGET  →  returns (frame, getState, setState)
-- ─────────────────────────────────────────────────────────────
local function mkToggle(parent, pos, init, onChange)
    local ON, OFF = C.green, Color3.fromRGB(60,60,60)
    local bg = frm(parent, UDim2.new(0,46,0,24), pos, init and ON or OFF, 0, "TGL")
    corner(bg, 12)
    local knob = frm(bg, UDim2.new(0,18,0,18),
        init and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9), C.white, 0, "Knob")
    corner(knob, 9)
    local hit = Instance.new("TextButton")
    hit.Size, hit.BackgroundTransparency, hit.Text, hit.ZIndex =
        UDim2.new(1,0,1,0), 1, "", (bg.ZIndex or 1)+1
    hit.Parent = bg
    local state = init
    hit.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(bg,   TweenInfo.new(0.15), {BackgroundColor3 = state and ON or OFF}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)}):Play()
        if onChange then onChange(state) end
    end)
    return bg,
        function() return state end,
        function(s)
            state = s
            bg.BackgroundColor3 = s and ON or OFF
            knob.Position = s and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
        end
end

-- ─────────────────────────────────────────────────────────────
-- PANEL HEADER  (drag handle)
-- ─────────────────────────────────────────────────────────────
local function mkHeader(parent, title, dragTarget)
    local h = frm(parent, UDim2.new(1,0,0,36), UDim2.new(0,0,0,0), C.panel, 0, "Hdr")
    corner(h, 8)
    lbl(h, "  "..title, UDim2.new(1,-80,1,0), UDim2.new(0,0,0,0), C.text, 14)
    if dragTarget then makeDraggable(dragTarget, h) end
    return h
end

-- menu-row button shorthand
local function rowBtn(parent, icon, labelText, yOff)
    local b = mkBtn(parent, icon.."  "..labelText,
        UDim2.new(1,-16,0,36), UDim2.new(0,8,0,yOff), C.item, C.text, 13)
    b.TextXAlignment = Enum.TextXAlignment.Left
    pad(b, 10)
    return b
end

-- ═════════════════════════════════════════════════════════════
-- CROSSHAIR  (fixed aim-point, draggable position)
-- ═════════════════════════════════════════════════════════════

-- One container frame centred at saved position
-- AnchorPoint 0.5, 0.5  →  Position scale = screen fraction of the aim point
local chHolder = frm(CHGui, UDim2.new(0,44,0,44), UDim2.new(0,0,0,0),
    C.white, 1, "CHHolder", 10)
chHolder.AnchorPoint = Vector2.new(0.5, 0.5)
chHolder.Position    = UDim2.new(Data.crosshairX or 0.5, 0, Data.crosshairY or 0.5, 0)

-- Ring (default – no decal)
local chRing = frm(chHolder, UDim2.new(0,26,0,26), UDim2.new(0.5,-13,0.5,-13),
    C.white, 1, "Ring", 11)
corner(chRing, 13)
local rStroke = Instance.new("UIStroke")
rStroke.Color, rStroke.Thickness = C.white, 2.5
rStroke.Parent = chRing

-- Tiny centre dot
local chDot = frm(chHolder, UDim2.new(0,4,0,4), UDim2.new(0.5,-2,0.5,-2),
    C.white, 0, "Dot", 12)
corner(chDot, 2)

-- Image (custom decal)
local chImg = Instance.new("ImageLabel")
chImg.Size, chImg.AnchorPoint    = UDim2.new(1,0,1,0), Vector2.new(0.5,0.5)
chImg.Position                   = UDim2.new(0.5,0,0.5,0)
chImg.BackgroundTransparency, chImg.ZIndex = 1, 12
chImg.Parent = chHolder

local function applyChPosition()
    chHolder.Position = UDim2.new(Data.crosshairX or 0.5, 0, Data.crosshairY or 0.5, 0)
end

local function refreshCH()
    local has = Data.crosshairDecalId ~= ""
    if Data.crosshairEnabled then
        if has then
            chImg.Image, chImg.Visible = "rbxassetid://"..Data.crosshairDecalId, true
            chRing.Visible, chDot.Visible = false, false
        else
            chImg.Visible = false
            chRing.Visible, chDot.Visible = true, true
        end
    else
        chImg.Visible, chRing.Visible, chDot.Visible = false, false, false
    end
end

applyChPosition()
refreshCH()

-- ─── Crosshair Edit Mode ─────────────────────────────────────
-- A floating "edit bar" appears; the crosshair becomes draggable.

local chEditBar = frm(MainGui, UDim2.new(0,290,0,40), UDim2.new(0.5,-145,0,10),
    C.panel, 0, "CHEditBar", 30)
chEditBar.Visible = false
corner(chEditBar, 8); stroke(chEditBar, C.orange, 1.5)

lbl(chEditBar, "  ✛  Drag crosshair to aim point",
    UDim2.new(1,-90,1,0), UDim2.new(0,0,0,0), C.orange, 12)

local chEditDoneBtn = mkBtn(chEditBar, "Done",
    UDim2.new(0,72,0,28), UDim2.new(1,-78,0.5,-14), C.green, C.text, 12)

local chDragConns = {}

local function beginChEdit()
    chHolder.Size = UDim2.new(0,50,0,50) -- slightly bigger hit area
    stroke(chHolder, C.orange, 2)
    chHolder.BackgroundTransparency = 0.85

    -- connect drag directly on chHolder
    local drag, dinp, dstart, dpos = false, nil, nil, nil
    chDragConns[1] = chHolder.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag, dstart, dpos = true, i.Position, chHolder.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    chDragConns[2] = chHolder.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then dinp = i end
    end)
    chDragConns[3] = UserInputService.InputChanged:Connect(function(i)
        if i == dinp and drag then
            local d = i.Position - dstart
            chHolder.Position = UDim2.new(dpos.X.Scale, dpos.X.Offset+d.X,
                                           dpos.Y.Scale, dpos.Y.Offset+d.Y)
        end
    end)

    chEditBar.Visible = true
end

local function endChEdit(save)
    for _, c in ipairs(chDragConns) do c:Disconnect() end
    chDragConns = {}

    if save then
        local vp = Camera.ViewportSize
        local ap, as = chHolder.AbsolutePosition, chHolder.AbsoluteSize
        Data.crosshairX = (ap.X + as.X*0.5) / vp.X
        Data.crosshairY = (ap.Y + as.Y*0.5) / vp.Y
        persist(Data)
    else
        applyChPosition()
    end

    -- restore normal size / appearance
    chHolder.Size = UDim2.new(0,44,0,44)
    chHolder.BackgroundTransparency = 1
    local ex = chHolder:FindFirstChildOfClass("UIStroke")
    if ex then ex:Destroy() end
    chEditBar.Visible = false
end

chEditDoneBtn.MouseButton1Click:Connect(function() endChEdit(true) end)

-- ═════════════════════════════════════════════════════════════
-- VIRTUAL KEYBIND BUTTONS
-- ═════════════════════════════════════════════════════════════
local kbButtons = {}  -- { {frame, key} }

local function fireKey(kc)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true,  kc, false, workspace)
        task.delay(0.06, function()
            pcall(function() VirtualInputManager:SendKeyEvent(false, kc, false, workspace) end)
        end)
    end)
end

local function clearKBBtns()
    for _, e in ipairs(kbButtons) do
        if e.frame and e.frame.Parent then e.frame:Destroy() end
    end
    kbButtons = {}
end

local function spawnKBBtn(keyName, xs, ys, draggable, firing)
    local kc; pcall(function() kc = Enum.KeyCode[keyName] end)
    local b = Instance.new("TextButton")
    b.Size                  = UDim2.new(0,58,0,58)
    b.Position              = UDim2.new(xs,-29, ys,-29)
    b.Text                  = keyName
    b.TextColor3            = C.text
    b.BackgroundColor3      = Color3.fromRGB(16,16,16)
    b.BackgroundTransparency= 0.12
    b.BorderSizePixel       = 0
    b.FontFace              = FONT_BOLD
    b.TextSize              = 12
    b.ZIndex                = 6
    b.Parent                = KBGui
    corner(b, 10); stroke(b, Color3.fromRGB(85,85,85), 1.5)

    if draggable then
        makeDraggable(b)
        local dot = frm(b, UDim2.new(0,5,0,5), UDim2.new(1,-8,0,3), C.sub, 0, "DD", b.ZIndex+1)
        corner(dot, 3)
    end
    if firing then
        b.MouseButton1Down:Connect(function()
            if kc then
                fireKey(kc)
                TweenService:Create(b, TweenInfo.new(0.05), {BackgroundColor3=C.green}):Play()
            end
        end)
        b.MouseButton1Up:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(16,16,16)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(16,16,16)}):Play()
        end)
    end
    return b
end

local function loadKBBtns(data, drag, fire)
    clearKBBtns()
    for _, kb in ipairs(data or {}) do
        local b = spawnKBBtn(kb.key, kb.x or 0.5, kb.y or 0.5, drag, fire)
        table.insert(kbButtons, {frame=b, key=kb.key})
    end
end

local function captureKBPos()
    local vp, out = Camera.ViewportSize, {}
    for _, e in ipairs(kbButtons) do
        if e.frame and e.frame.Parent then
            local ap, as = e.frame.AbsolutePosition, e.frame.AbsoluteSize
            table.insert(out, {key=e.key, x=(ap.X+as.X*.5)/vp.X, y=(ap.Y+as.Y*.5)/vp.Y})
        end
    end
    return out
end

loadKBBtns(Data.activeKeybinds, false, true)

-- ═════════════════════════════════════════════════════════════
-- ENTRY BUTTON
-- ═════════════════════════════════════════════════════════════
local entryBtn = mkBtn(MainGui, "☰",
    UDim2.new(0,46,0,46), UDim2.new(0,10,0.5,-23),
    Color3.fromRGB(26,26,26), C.text, 18)
entryBtn.ZIndex = 20
stroke(entryBtn, C.border, 1)
makeDraggable(entryBtn)

-- ═════════════════════════════════════════════════════════════
-- MAIN MENU  (40 % screen width)
-- ═════════════════════════════════════════════════════════════
local mainMenu = frm(MainGui, UDim2.new(0.4,0,0,210),
    UDim2.new(0.3,0,0.3,0), C.bg, 0, "MainMenu", 15)
mainMenu.Visible = false
corner(mainMenu, 10); stroke(mainMenu, C.border, 1)

local mmHdr   = mkHeader(mainMenu, "UI Script", mainMenu)
local mmClose = mkBtn(mmHdr, "✕", UDim2.new(0,28,0,28), UDim2.new(1,-32,0.5,-14),
    Color3.fromRGB(70,30,30), C.text, 11)

-- ── Crosshair section ────────────────────────────────────────
local chSec = frm(mainMenu, UDim2.new(1,-16,0,96), UDim2.new(0,8,0,44), C.panel, 0, "ChSec")
corner(chSec, 7); stroke(chSec, C.border, 1)

lbl(chSec, "Crosshair", UDim2.new(0,80,0,22), UDim2.new(0,10,0,4), C.text, 13)

-- Toggle
makeToggle(chSec, UDim2.new(1,-100,0,6), Data.crosshairEnabled, function(s)
    Data.crosshairEnabled = s; refreshCH(); persist(Data)
end)

-- Edit position button
local chEditBtn = mkBtn(chSec, "✎ Edit",
    UDim2.new(0,56,0,22), UDim2.new(1,-60,0,8),
    C.orange, C.text, 11)
chEditBtn.MouseButton1Click:Connect(function()
    mainMenu.Visible = false
    beginChEdit()
end)

-- Decal ID row
lbl(chSec, "Decal ID", UDim2.new(0,55,0,18), UDim2.new(0,10,0,38), C.sub, 11)
local decalTB = tbx(chSec, "Asset ID (blank = ring)", UDim2.new(1,-84,0,26), UDim2.new(0,66,0,34))
decalTB.Text = Data.crosshairDecalId or ""
local applyDecalBtn = mkBtn(chSec, "✓", UDim2.new(0,24,0,26), UDim2.new(1,-28,0,34), C.green, C.text, 13)

local function applyDecal()
    Data.crosshairDecalId = decalTB.Text; refreshCH(); persist(Data)
end
applyDecalBtn.MouseButton1Click:Connect(applyDecal)
decalTB.FocusLost:Connect(applyDecal)

-- Keyboard open button
local openKBBtn = rowBtn(mainMenu, "⌨", "Keyboard", 148)
openKBBtn.BackgroundColor3 = C.blue

-- Wiring
mmClose.MouseButton1Click:Connect(function() mainMenu.Visible = false end)
entryBtn.MouseButton1Click:Connect(function() mainMenu.Visible = not mainMenu.Visible end)

-- ═════════════════════════════════════════════════════════════
-- KEYBOARD MENU
-- ═════════════════════════════════════════════════════════════
local kbMenu = frm(MainGui, UDim2.new(0.4,0,0,192),
    UDim2.new(0.56,0,0.26,0), C.bg, 0, "KBMenu", 15)
kbMenu.Visible = false
corner(kbMenu, 10); stroke(kbMenu, C.border, 1)

local kbHdr   = mkHeader(kbMenu, "Keyboard", kbMenu)
local kbBack  = mkBtn(kbHdr, "←", UDim2.new(0,28,0,28), UDim2.new(0,4,0.5,-14), C.item, C.text, 14)
local kbClose = mkBtn(kbHdr, "✕", UDim2.new(0,28,0,28), UDim2.new(1,-32,0.5,-14), Color3.fromRGB(70,30,30), C.text, 11)

local kbAddBtn  = rowBtn(kbMenu, "＋", "Keyboard Buttons",  44)
local kbEditBtn = rowBtn(kbMenu, "✎", "Edit Layout",         86)
local kbSettBtn = rowBtn(kbMenu, "⚙", "Settings",           128)

kbBack.MouseButton1Click:Connect(function() kbMenu.Visible=false; mainMenu.Visible=true end)
kbClose.MouseButton1Click:Connect(function() kbMenu.Visible=false end)
openKBBtn.MouseButton1Click:Connect(function() mainMenu.Visible=false; kbMenu.Visible=true end)

-- ═════════════════════════════════════════════════════════════
-- FULL KEYBOARD PICKER  (draggable panel, search bar, all keys)
-- ═════════════════════════════════════════════════════════════

-- ── All keys organised by row ────────────────────────────────
local LAYOUT = {
    { cat="Function Keys", keys={
        {"Escape","Esc"},{"F1","F1"},{"F2","F2"},{"F3","F3"},{"F4","F4"},
        {"F5","F5"},{"F6","F6"},{"F7","F7"},{"F8","F8"},{"F9","F9"},
        {"F10","F10"},{"F11","F11"},{"F12","F12"},
    }},
    { cat="Number Row", keys={
        {"BackQuote","`"},{"One","1"},{"Two","2"},{"Three","3"},{"Four","4"},
        {"Five","5"},{"Six","6"},{"Seven","7"},{"Eight","8"},{"Nine","9"},
        {"Zero","0"},{"Minus","–"},{"Equals","="},{"Backspace","Bksp"},
    }},
    { cat="QWERTY Row", keys={
        {"Tab","Tab"},{"Q","Q"},{"W","W"},{"E","E"},{"R","R"},{"T","T"},
        {"Y","Y"},{"U","U"},{"I","I"},{"O","O"},{"P","P"},
        {"LeftBracket","["},{"RightBracket","]"},{"Backslash","\\"},
    }},
    { cat="Home Row", keys={
        {"CapsLock","Caps"},{"A","A"},{"S","S"},{"D","D"},{"F","F"},
        {"G","G"},{"H","H"},{"J","J"},{"K","K"},{"L","L"},
        {"Semicolon",";"},{"Quote","'"},{"Return","Enter"},
    }},
    { cat="Bottom Row", keys={
        {"LeftShift","LShft"},{"Z","Z"},{"X","X"},{"C","C"},{"V","V"},
        {"B","B"},{"N","N"},{"M","M"},{"Comma",","},{"Period","."},
        {"Slash","/"},{"RightShift","RShft"},
    }},
    { cat="Modifiers", keys={
        {"LeftControl","LCtrl"},{"LeftMeta","Win"},{"LeftAlt","LAlt"},
        {"Space","Space"},{"RightAlt","RAlt"},{"RightControl","RCtrl"},
    }},
    { cat="Navigation", keys={
        {"Insert","Ins"},{"Home","Home"},{"PageUp","PgUp"},
        {"Delete","Del"},{"End","End"},{"PageDown","PgDn"},
        {"Up","↑"},{"Down","↓"},{"Left","←"},{"Right","→"},
    }},
    { cat="Numpad", keys={
        {"NumLock","NmLk"},{"KeypadDivide","KP/"},{"KeypadMultiply","KP*"},{"KeypadMinus","KP–"},
        {"KeypadSeven","KP7"},{"KeypadEight","KP8"},{"KeypadNine","KP9"},{"KeypadPlus","KP+"},
        {"KeypadFour","KP4"},{"KeypadFive","KP5"},{"KeypadSix","KP6"},
        {"KeypadOne","KP1"},{"KeypadTwo","KP2"},{"KeypadThree","KP3"},{"KeypadEnter","KPEnt"},
        {"KeypadZero","KP0"},{"KeypadDot","KP."},
    }},
}

-- flat list for search
local ALL_KEYS_FLAT = {}
for _, section in ipairs(LAYOUT) do
    for _, k in ipairs(section.keys) do
        table.insert(ALL_KEYS_FLAT, {name=k[1], display=k[2], cat=section.cat})
    end
end

-- ── Picker Panel ─────────────────────────────────────────────
local pickerPanel = frm(MainGui, UDim2.new(0.5,0,0,380),
    UDim2.new(0.25,0,0.08,0), C.bg, 0, "PickerPanel", 25)
pickerPanel.Visible = false
corner(pickerPanel, 10); stroke(pickerPanel, C.border, 1)
makeDraggable(pickerPanel)

local picHdr   = mkHeader(pickerPanel, "Key Picker", pickerPanel)
local picClose = mkBtn(picHdr, "✕", UDim2.new(0,28,0,28), UDim2.new(1,-32,0.5,-14),
    Color3.fromRGB(70,30,30), C.text, 11)

-- Search bar
local searchBox = tbx(pickerPanel, "🔍  Search key name or shortcut (e.g. E, F1, Space)…",
    UDim2.new(1,-16,0,30), UDim2.new(0,8,0,44))

-- Scroll content area
local picScroll = Instance.new("ScrollingFrame")
picScroll.Size                  = UDim2.new(1,-16,1,-84)
picScroll.Position              = UDim2.new(0,8,0,82)
picScroll.BackgroundTransparency= 1
picScroll.BorderSizePixel       = 0
picScroll.ScrollBarThickness    = 5
picScroll.ScrollBarImageColor3  = Color3.fromRGB(70,70,70)
picScroll.CanvasSize            = UDim2.new(0,0,0,0)
picScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
picScroll.Parent = pickerPanel

local picLayout = Instance.new("UIListLayout")
picLayout.Padding, picLayout.SortOrder = UDim.new(0,6), Enum.SortOrder.LayoutOrder
picLayout.Parent = picScroll

-- helper: build one key chip button inside a parent
local function keyChip(parent, display, keyName, order)
    local b = mkBtn(parent, display,
        UDim2.new(0,0,0,32), UDim2.new(0,0,0,0),
        Color3.fromRGB(36,36,36), C.text, 11)
    b.Size = UDim2.new(0, math.clamp(#display * 8 + 16, 36, 72), 0, 32)
    b.LayoutOrder = order or 0
    b.TextWrapped = false
    b.MouseButton1Click:Connect(function()
        -- add key as draggable button in setup mode
        local vp = Camera.ViewportSize
        local b2 = spawnKBBtn(keyName, 0.5, 0.35, true, false)
        table.insert(kbButtons, {frame=b2, key=keyName})
    end)
    return b
end

-- build categorised rows in the scroll frame
local function buildPickerFull()
    for _, c in ipairs(picScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    local lo = 0
    for _, section in ipairs(LAYOUT) do
        lo += 1
        local catLbl = lbl(picScroll, section.cat,
            UDim2.new(1,0,0,18), UDim2.new(0,0,0,0), C.sub, 10)
        catLbl.LayoutOrder = lo

        lo += 1
        local row = frm(picScroll, UDim2.new(1,0,0,0),
            UDim2.new(0,0,0,0), Color3.new(0,0,0), 1, "Row_"..section.cat)
        row.LayoutOrder = lo
        row.AutomaticSize = Enum.AutomaticSize.Y

        local fl = Instance.new("UIListLayout")
        fl.FillDirection = Enum.FillDirection.Horizontal
        fl.Wraps, fl.Padding = true, UDim.new(0,4)
        fl.Parent = row
        pad(row, 0, 0, 0, 4)

        for ki, k in ipairs(section.keys) do
            keyChip(row, k[2], k[1], ki)
        end
    end
end

-- filtered flat list
local function buildPickerFiltered(query)
    for _, c in ipairs(picScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    local q = query:lower()
    local lo = 0
    local found = 0
    for _, k in ipairs(ALL_KEYS_FLAT) do
        if k.name:lower():find(q, 1, true)
        or k.display:lower():find(q, 1, true)
        or k.cat:lower():find(q, 1, true) then
            lo += 1; found += 1
            local row = frm(picScroll, UDim2.new(1,0,0,36),
                UDim2.new(0,0,0,0), C.panel, 0, "SR_"..k.name)
            row.LayoutOrder = lo
            corner(row, 5)
            lbl(row, k.display, UDim2.new(0,60,1,0), UDim2.new(0,8,0,0), C.text, 13)
            lbl(row, k.name,    UDim2.new(0,160,1,0), UDim2.new(0,70,0,0), C.sub, 11)
            lbl(row, k.cat,     UDim2.new(0,100,1,0), UDim2.new(1,-105,0,0), C.sub, 10, Enum.TextXAlignment.Right)
            local addB = mkBtn(row, "+ Add",
                UDim2.new(0,54,0,26), UDim2.new(1,-60,0.5,-13), C.green, C.text, 11)
            local kn = k.name
            addB.MouseButton1Click:Connect(function()
                local b2 = spawnKBBtn(kn, 0.5, 0.35, true, false)
                table.insert(kbButtons, {frame=b2, key=kn})
            end)
        end
    end
    if found == 0 then
        local nl = lbl(picScroll, "No keys match  \""..query.."\"",
            UDim2.new(1,0,0,40), UDim2.new(0,0,0,0), C.sub, 12, Enum.TextXAlignment.Center)
        nl.LayoutOrder = 1
    end
end

buildPickerFull()

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local t = searchBox.Text
    if t == "" then buildPickerFull() else buildPickerFiltered(t) end
end)

picClose.MouseButton1Click:Connect(function()
    pickerPanel.Visible = false
end)

-- Done / cancel bar (appears alongside picker during setup)
local setupBar = frm(MainGui, UDim2.new(0,280,0,40), UDim2.new(0.5,-140,0,10),
    C.panel, 0, "SetupBar", 26)
setupBar.Visible = false
corner(setupBar, 8); stroke(setupBar, C.green, 1.5)
lbl(setupBar, "  Setup mode – pick keys & drag to position",
    UDim2.new(1,-90,1,0), UDim2.new(0,0,0,0), C.green, 11)
local setupDoneBtn   = mkBtn(setupBar, "Done",   UDim2.new(0,62,0,28), UDim2.new(1,-68,0.5,-14), C.green, C.text, 12)

local setupInputConn = nil

local function beginSetupMode()
    mainMenu.Visible, kbMenu.Visible = false, false

    clearKBBtns()
    for _, kb in ipairs(Data.activeKeybinds) do
        local b = spawnKBBtn(kb.key, kb.x, kb.y, true, false)
        table.insert(kbButtons, {frame=b, key=kb.key})
    end

    searchBox.Text = ""
    buildPickerFull()
    pickerPanel.Visible = true
    setupBar.Visible    = true

    -- physical keyboard
    if setupInputConn then setupInputConn:Disconnect() end
    setupInputConn = UserInputService.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.UserInputType == Enum.UserInputType.Keyboard then
            local kn = i.KeyCode.Name
            if kn ~= "Unknown" then
                local b2 = spawnKBBtn(kn, 0.5, 0.35, true, false)
                table.insert(kbButtons, {frame=b2, key=kn})
            end
        end
    end)
end

local function endSetupMode(save)
    if setupInputConn then setupInputConn:Disconnect(); setupInputConn=nil end
    pickerPanel.Visible = false
    setupBar.Visible    = false
    if save then
        Data.activeKeybinds = captureKBPos()
        persist(Data)
    end
    loadKBBtns(Data.activeKeybinds, false, true)
    kbMenu.Visible = true
end

kbAddBtn.MouseButton1Click:Connect(beginSetupMode)
setupDoneBtn.MouseButton1Click:Connect(function() endSetupMode(true)  end)

-- ═════════════════════════════════════════════════════════════
-- EDIT LAYOUT MODE
-- ═════════════════════════════════════════════════════════════
local editBar = frm(MainGui, UDim2.new(0,260,0,40), UDim2.new(0.5,-130,0,10),
    C.panel, 0, "EditBar", 22)
editBar.Visible = false
corner(editBar, 8); stroke(editBar, C.blue, 1.5)
lbl(editBar, "  Edit mode – drag buttons to reposition",
    UDim2.new(1,-90,1,0), UDim2.new(0,0,0,0), C.blue, 11)
local editDoneBtn = mkBtn(editBar, "Done",
    UDim2.new(0,62,0,28), UDim2.new(1,-68,0.5,-14), C.green, C.text, 12)

local function beginEditMode()
    mainMenu.Visible, kbMenu.Visible = false, false
    clearKBBtns()
    for _, kb in ipairs(Data.activeKeybinds) do
        local b = spawnKBBtn(kb.key, kb.x, kb.y, true, false)
        table.insert(kbButtons, {frame=b, key=kb.key})
    end
    editBar.Visible = true
end

local function endEditMode()
    editBar.Visible         = false
    Data.activeKeybinds     = captureKBPos()
    persist(Data)
    loadKBBtns(Data.activeKeybinds, false, true)
    kbMenu.Visible = true
end

kbEditBtn.MouseButton1Click:Connect(beginEditMode)
editDoneBtn.MouseButton1Click:Connect(endEditMode)

-- ═════════════════════════════════════════════════════════════
-- SAVES PANEL
-- ═════════════════════════════════════════════════════════════
local savesPanel = frm(MainGui, UDim2.new(0.44,0,0,310),
    UDim2.new(0.53,0,0.17,0), C.bg, 0, "SavesPanel", 15)
savesPanel.Visible = false
corner(savesPanel, 10); stroke(savesPanel, C.border, 1)
makeDraggable(savesPanel)

local spHdr    = mkHeader(savesPanel, "Saves", savesPanel)
local spBack   = mkBtn(spHdr, "←", UDim2.new(0,28,0,28), UDim2.new(0,4,0.5,-14), C.item, C.text, 14)
local spAddBtn = mkBtn(spHdr, "+", UDim2.new(0,28,0,28), UDim2.new(1,-32,0.5,-14), C.green, C.text, 16)

local spScroll = Instance.new("ScrollingFrame")
spScroll.Size                  = UDim2.new(1,-16,1,-44)
spScroll.Position              = UDim2.new(0,8,0,42)
spScroll.BackgroundTransparency= 1
spScroll.BorderSizePixel       = 0
spScroll.ScrollBarThickness    = 5
spScroll.ScrollBarImageColor3  = Color3.fromRGB(70,70,70)
spScroll.CanvasSize            = UDim2.new(0,0,0,0)
spScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
spScroll.Parent = savesPanel

local spListLayout = Instance.new("UIListLayout")
spListLayout.Padding, spListLayout.SortOrder = UDim.new(0,5), Enum.SortOrder.LayoutOrder
spListLayout.Parent = spScroll

spBack.MouseButton1Click:Connect(function() savesPanel.Visible=false; kbMenu.Visible=true end)
kbSettBtn.MouseButton1Click:Connect(function() kbMenu.Visible=false; savesPanel.Visible=true end)

-- ── Context menu (⋯) ─────────────────────────────────────────
local ctxMenu = frm(MainGui, UDim2.new(0,136,0,120),
    UDim2.new(0,0,0,0), C.bg, 0, "CtxMenu", 35)
ctxMenu.Visible = false
corner(ctxMenu, 7); stroke(ctxMenu, Color3.fromRGB(65,65,65), 1)
local ctxInnerLayout = Instance.new("UIListLayout")
ctxInnerLayout.Padding, ctxInnerLayout.SortOrder = UDim.new(0,3), Enum.SortOrder.LayoutOrder
ctxInnerLayout.Parent = ctxMenu
pad(ctxMenu, 4, 4, 4, 4)

local function ctxRow(text, bg, lo)
    local b = mkBtn(ctxMenu, text,
        UDim2.new(1,0,0,26), UDim2.new(0,0,0,0), bg, C.text, 12)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.LayoutOrder    = lo
    pad(b, 8)
    return b
end
local ctxLoad   = ctxRow("▶  Load",   C.blue,                  1)
local ctxRename = ctxRow("✎  Rename", C.item,                  2)
local ctxUpdate = ctxRow("↺  Update", C.item,                  3)
local ctxDelete = ctxRow("⊘  Delete", Color3.fromRGB(80,28,28), 4)

local ctxIdx = 0

UserInputService.InputBegan:Connect(function(i)
    if (i.UserInputType == Enum.UserInputType.MouseButton1
     or i.UserInputType == Enum.UserInputType.Touch) and ctxMenu.Visible then
        task.defer(function() ctxMenu.Visible = false end)
    end
end)

-- ── Name dialog ───────────────────────────────────────────────
local nameDlg = frm(MainGui, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    Color3.new(0,0,0), 0.62, "NameDlg", 32)
nameDlg.Visible = false

local nameCard = frm(nameDlg, UDim2.new(0,270,0,124),
    UDim2.new(0.5,-135,0.38,-62), C.bg, 0, "NameCard", 33)
corner(nameCard, 10); stroke(nameCard, C.border, 1)

local nameTitleL = lbl(nameCard, "Name this save:",
    UDim2.new(1,-20,0,22), UDim2.new(0,10,0,8), C.text, 14, Enum.TextXAlignment.Center)
local nameInput    = tbx(nameCard, "Type a name…", UDim2.new(1,-20,0,30), UDim2.new(0,10,0,38))
local nameConfirm  = mkBtn(nameCard, "Confirm", UDim2.new(0,112,0,30), UDim2.new(0.5,-120,0,82), C.green,  C.text, 13)
local nameCancel   = mkBtn(nameCard, "Cancel",  UDim2.new(0,80,0,30),  UDim2.new(0.5,12,0,82),  Color3.fromRGB(72,28,28), C.text, 12)

local dlgMode, dlgIdx = "new", 0

-- ── Refresh saves list ────────────────────────────────────────
local function refreshSaves()
    for _, c in ipairs(spScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    if #Data.saves == 0 then
        local el = lbl(spScroll, "No saves yet.  Press + to create one.",
            UDim2.new(1,0,0,40), UDim2.new(0,0,0,0), C.sub, 12, Enum.TextXAlignment.Center)
        el.LayoutOrder = 1
        return
    end
    for i, sv in ipairs(Data.saves) do
        local row = frm(spScroll, UDim2.new(1,0,0,42), UDim2.new(0,0,0,0), C.panel, 0, "SvRow"..i)
        row.LayoutOrder = i
        corner(row, 6)
        lbl(row, sv.name or ("Save "..i),
            UDim2.new(1,-90,1,0), UDim2.new(0,10,0,0), C.text, 13)
        local dotB = mkBtn(row, "⋯",
            UDim2.new(0,30,0,30), UDim2.new(1,-36,0.5,-15),
            C.item, C.text, 14)
        local idx = i
        dotB.MouseButton1Click:Connect(function()
            ctxIdx = idx
            local ap = dotB.AbsolutePosition
            ctxMenu.Position = UDim2.new(0, ap.X-130, 0, ap.Y+34)
            ctxMenu.Visible  = true
        end)
    end
end

-- ── ctx actions ──────────────────────────────────────────────
ctxLoad.MouseButton1Click:Connect(function()
    ctxMenu.Visible = false
    local sv = Data.saves[ctxIdx]; if not sv then return end
    Data.activeKeybinds = {}
    for _, kb in ipairs(sv.keybinds or {}) do
        table.insert(Data.activeKeybinds, {key=kb.key, x=kb.x, y=kb.y})
    end
    persist(Data)
    loadKBBtns(Data.activeKeybinds, false, true)
    savesPanel.Visible=false; kbMenu.Visible=true
end)

ctxRename.MouseButton1Click:Connect(function()
    ctxMenu.Visible = false
    dlgMode, dlgIdx = "rename", ctxIdx
    nameTitleL.Text  = "Rename save:"
    nameInput.Text   = Data.saves[ctxIdx] and Data.saves[ctxIdx].name or ""
    nameDlg.Visible  = true
end)

ctxUpdate.MouseButton1Click:Connect(function()
    ctxMenu.Visible = false
    local sv = Data.saves[ctxIdx]; if not sv then return end
    local kbs = captureKBPos()
    if #kbs == 0 then
        for _, kb in ipairs(Data.activeKeybinds) do
            table.insert(kbs, {key=kb.key, x=kb.x, y=kb.y})
        end
    end
    sv.keybinds = kbs
    persist(Data); refreshSaves()
end)

ctxDelete.MouseButton1Click:Connect(function()
    ctxMenu.Visible = false
    table.remove(Data.saves, ctxIdx)
    persist(Data); refreshSaves()
end)

-- ── + new save ────────────────────────────────────────────────
spAddBtn.MouseButton1Click:Connect(function()
    dlgMode = "new"
    nameTitleL.Text = "Name this save:"
    nameInput.Text  = ""
    nameDlg.Visible = true
end)

nameConfirm.MouseButton1Click:Connect(function()
    local name = nameInput.Text ~= "" and nameInput.Text or ("Save "..(#Data.saves+1))
    if dlgMode == "rename" then
        if Data.saves[dlgIdx] then Data.saves[dlgIdx].name = name end
    else
        local kbs = {}
        for _, kb in ipairs(Data.activeKeybinds) do
            table.insert(kbs, {key=kb.key, x=kb.x, y=kb.y})
        end
        table.insert(Data.saves, {name=name, keybinds=kbs})
    end
    persist(Data); refreshSaves()
    nameDlg.Visible = false
end)

nameCancel.MouseButton1Click:Connect(function() nameDlg.Visible=false end)

-- initial render
refreshSaves()

-- ═════════════════════════════════════════════════════════════
print("[MobileUIScript v2] ✓  File →  "..SAVE_FILE)
