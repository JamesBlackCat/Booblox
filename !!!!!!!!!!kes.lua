--[[
    MobileUIScript.lua
    Executor-compatible: Delta, Synapse X, Script-Ware, KRNL, Fluxus, and others
    Client-sided | Saves via executor file I/O (writefile / readfile)

    FEATURES:
      - Draggable entry button
      - Main menu (40% screen)
        > Crosshair: toggle + custom decal ID
        > Keyboard menu access
      - Keyboard menu
        > Keyboard Buttons: bind keys as on-screen virtual buttons (draggable during setup)
        > Edit Layout: reposition existing buttons
        > Settings > Saves: named save slots with load / rename / update / delete
      - All state persists via local executor file
]]

-- ─────────────────────────────────────────────────────────────
-- SERVICES
-- ─────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────
-- FILE SAVE / LOAD  (executor file I/O)
-- ─────────────────────────────────────────────────────────────
local SAVE_FILE = "MobileUIScript_Data.json"

local function defaultData()
    return {
        crosshairEnabled  = true,
        crosshairDecalId  = "",
        activeKeybinds    = {},   -- { {key="E", x=0.5, y=0.5}, ... }
        saves             = {}    -- { {name="Slot1", keybinds={...}}, ... }
    }
end

local function persistSave(data)
    pcall(function()
        if writefile then
            writefile(SAVE_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function persistLoad()
    local ok, result = pcall(function()
        if isfile and isfile(SAVE_FILE) and readfile then
            return HttpService:JSONDecode(readfile(SAVE_FILE))
        end
    end)
    if ok and type(result) == "table" then
        -- fill missing keys with defaults
        local def = defaultData()
        for k, v in pairs(def) do
            if result[k] == nil then result[k] = v end
        end
        return result
    end
    return defaultData()
end

local Data = persistLoad()

-- ─────────────────────────────────────────────────────────────
-- CLEANUP  (re-execution safety)
-- ─────────────────────────────────────────────────────────────
for _, name in ipairs({ "MUIS_Main", "MUIS_Crosshair", "MUIS_Keybinds" }) do
    local old = PlayerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

-- ─────────────────────────────────────────────────────────────
-- SCREEN GUI CONTAINERS
-- ─────────────────────────────────────────────────────────────
local function makeGui(name, displayOrder, ignoreInset)
    local g = Instance.new("ScreenGui")
    g.Name             = name
    g.ResetOnSpawn     = false
    g.IgnoreGuiInset   = ignoreInset or false
    g.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
    g.DisplayOrder     = displayOrder or 100
    g.Parent           = PlayerGui
    return g
end

local MainGui      = makeGui("MUIS_Main",      100)
local CrosshairGui = makeGui("MUIS_Crosshair",  99, true)
local KeybindGui   = makeGui("MUIS_Keybinds",   98)

-- ─────────────────────────────────────────────────────────────
-- UI HELPERS
-- ─────────────────────────────────────────────────────────────
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local FONT_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local C = {
    bg       = Color3.fromRGB(22,  22,  22),
    panel    = Color3.fromRGB(30,  30,  30),
    item     = Color3.fromRGB(38,  38,  38),
    border   = Color3.fromRGB(55,  55,  55),
    text     = Color3.fromRGB(220, 220, 220),
    subtext  = Color3.fromRGB(140, 140, 140),
    green    = Color3.fromRGB(72,  199, 142),
    blue     = Color3.fromRGB(55,  130, 210),
    red      = Color3.fromRGB(200, 70,  70),
    accent   = Color3.fromRGB(255, 255, 255),
}

local function uiCorner(parent, r)
    local c = Instance.new("UICorner")
    c.Name = "UICorner"
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function uiStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or C.border
    s.Thickness = thickness or 1
    s.Parent    = parent
    return s
end

local function uiPadding(parent, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = parent
    return p
end

local function frame(parent, size, pos, color, trans, name, zi)
    local f = Instance.new("Frame")
    f.Size                  = size  or UDim2.new(1,0,1,0)
    f.Position              = pos   or UDim2.new(0,0,0,0)
    f.BackgroundColor3      = color or C.bg
    f.BackgroundTransparency= trans or 0
    f.BorderSizePixel       = 0
    f.Active                = true
    if name then f.Name = name end
    if zi   then f.ZIndex = zi  end
    f.Parent = parent
    return f
end

local function label(parent, text, size, pos, color, fs, xa)
    local l = Instance.new("TextLabel")
    l.Size                  = size or UDim2.new(1,0,0,20)
    l.Position              = pos  or UDim2.new(0,0,0,0)
    l.Text                  = text or ""
    l.TextColor3            = color or C.text
    l.BackgroundTransparency= 1
    l.BorderSizePixel       = 0
    l.FontFace              = FONT
    l.TextSize              = fs or 13
    l.TextXAlignment        = xa or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function btn(parent, text, size, pos, bg, tc, fs)
    local b = Instance.new("TextButton")
    b.Size                  = size or UDim2.new(0,80,0,30)
    b.Position              = pos  or UDim2.new(0,0,0,0)
    b.Text                  = text or ""
    b.TextColor3            = tc   or C.text
    b.BackgroundColor3      = bg   or C.item
    b.BorderSizePixel       = 0
    b.FontFace              = FONT
    b.TextSize              = fs   or 13
    b.AutoButtonColor       = false
    b.Parent = parent
    uiCorner(b, 6)
    -- subtle press tween
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = (bg or C.item):Lerp(Color3.new(1,1,1), 0.12)}):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = bg or C.item}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = bg or C.item}):Play()
    end)
    return b
end

local function textbox(parent, placeholder, size, pos)
    local tb = Instance.new("TextBox")
    tb.Size                  = size or UDim2.new(1,0,0,28)
    tb.Position              = pos  or UDim2.new(0,0,0,0)
    tb.PlaceholderText       = placeholder or ""
    tb.Text                  = ""
    tb.TextColor3            = C.text
    tb.PlaceholderColor3     = C.subtext
    tb.BackgroundColor3      = Color3.fromRGB(18,18,18)
    tb.BorderSizePixel       = 0
    tb.FontFace              = FONT
    tb.TextSize              = 12
    tb.ClearTextOnFocus      = false
    tb.Parent = parent
    uiCorner(tb, 5)
    uiStroke(tb, C.border, 1)
    return tb
end

-- ─────────────────────────────────────────────────────────────
-- DRAGGABLE
-- ─────────────────────────────────────────────────────────────
local function makeDraggable(dragFrame, handle)
    handle = handle or dragFrame
    handle.Active = true
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = dragFrame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragInput = inp
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if inp == dragInput and dragging then
            local d = inp.Position - dragStart
            dragFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- TOGGLE WIDGET
-- ─────────────────────────────────────────────────────────────
--  Returns: (rootFrame, getState, setState)
local function makeToggle(parent, pos, initState, onChange)
    local BG_ON  = C.green
    local BG_OFF = Color3.fromRGB(65, 65, 65)

    local bg = frame(parent, UDim2.new(0,46,0,24), pos,
        initState and BG_ON or BG_OFF, 0, "ToggleBG")
    uiCorner(bg, 12)

    local knob = frame(bg, UDim2.new(0,18,0,18),
        initState and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9),
        C.accent, 0, "Knob")
    uiCorner(knob, 9)

    local hit = Instance.new("TextButton")
    hit.Size, hit.BackgroundTransparency, hit.Text, hit.ZIndex =
        UDim2.new(1,0,1,0), 1, "", bg.ZIndex + 1
    hit.Parent = bg

    local state = initState
    hit.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(bg,   TweenInfo.new(0.15), {BackgroundColor3 = state and BG_ON or BG_OFF}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)}):Play()
        if onChange then onChange(state) end
    end)

    local function getState() return state end
    local function setState(s)
        state = s
        bg.BackgroundColor3 = s and BG_ON or BG_OFF
        knob.Position = s and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
    end

    return bg, getState, setState
end

-- ─────────────────────────────────────────────────────────────
-- SECTION HEADER HELPER  (title bar that also acts as drag handle)
-- ─────────────────────────────────────────────────────────────
local function makeHeader(parent, title, dragTarget)
    local h = frame(parent, UDim2.new(1,0,0,36), UDim2.new(0,0,0,0), C.panel, 0, "Header")
    uiCorner(h, 8)
    label(h, "  " .. title, UDim2.new(1,-80,1,0), UDim2.new(0,0,0,0), C.text, 14)
    if dragTarget then makeDraggable(dragTarget, h) end
    return h
end

-- ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════
-- CROSSHAIR
-- ══════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────

-- Ring (default when no decal)
local chRing = frame(CrosshairGui, UDim2.new(0,28,0,28), UDim2.new(0.5,-14,0.5,-14),
    C.accent, 1, "CHRing", 10)
uiCorner(chRing, 14)
local ringStroke = Instance.new("UIStroke")
ringStroke.Color, ringStroke.Thickness = C.accent, 2
ringStroke.Parent = chRing

-- Image (custom decal)
local chImage = Instance.new("ImageLabel")
chImage.Size, chImage.AnchorPoint = UDim2.new(0,36,0,36), Vector2.new(0.5,0.5)
chImage.Position, chImage.BackgroundTransparency, chImage.ZIndex =
    UDim2.new(0.5,0,0.5,0), 1, 10
chImage.Parent = CrosshairGui

local function refreshCrosshair()
    local hasImg = Data.crosshairDecalId ~= ""
    if Data.crosshairEnabled then
        if hasImg then
            chImage.Image   = "rbxassetid://" .. tostring(Data.crosshairDecalId)
            chImage.Visible = true
            chRing.Visible  = false
        else
            chImage.Visible = false
            chRing.Visible  = true
        end
    else
        chImage.Visible = false
        chRing.Visible  = false
    end
end

refreshCrosshair()

-- ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════
-- VIRTUAL KEYBIND BUTTONS
-- ══════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────

local keybindButtons = {}  -- { { frame=btn, key="E" }, ... }

-- Fire key via VirtualInputManager (works in most executors)
local function fireKey(keyCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true,  keyCode, false, workspace)
        task.delay(0.06, function()
            pcall(function()
                VirtualInputManager:SendKeyEvent(false, keyCode, false, workspace)
            end)
        end)
    end)
end

local function clearKeybindButtons()
    for _, entry in ipairs(keybindButtons) do
        if entry.frame and entry.frame.Parent then
            entry.frame:Destroy()
        end
    end
    keybindButtons = {}
end

--[[
    Creates one on-screen keybind button.
    draggable = true  →  can be repositioned (setup / edit mode)
    firing    = true  →  pressing it fires the key
]]
local function spawnKeybindButton(keyName, xScale, yScale, draggable, firing)
    local keyCode
    pcall(function() keyCode = Enum.KeyCode[keyName] end)

    local b = Instance.new("TextButton")
    b.Size                  = UDim2.new(0, 56, 0, 56)
    b.Position              = UDim2.new(xScale, -28, yScale, -28)
    b.Text                  = keyName
    b.TextColor3            = C.text
    b.BackgroundColor3      = Color3.fromRGB(18, 18, 18)
    b.BackgroundTransparency= 0.15
    b.BorderSizePixel       = 0
    b.FontFace              = FONT_BOLD
    b.TextSize              = 13
    b.ZIndex                = 6
    b.Parent                = KeybindGui
    uiCorner(b, 10)
    uiStroke(b, Color3.fromRGB(90, 90, 90), 1.5)

    if draggable then
        makeDraggable(b)
        -- visual drag indicator
        local dragDot = frame(b, UDim2.new(0,6,0,6), UDim2.new(1,-9,0,3),
            C.subtext, 0, "DragDot", b.ZIndex + 1)
        uiCorner(dragDot, 3)
    end

    if firing then
        b.MouseButton1Down:Connect(function()
            if keyCode then
                fireKey(keyCode)
                TweenService:Create(b, TweenInfo.new(0.05), {BackgroundColor3 = C.green}):Play()
            end
        end)
        b.MouseButton1Up:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(18,18,18)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(18,18,18)}):Play()
        end)
    end

    return b
end

local function loadKeybinds(kbData, draggable, firing)
    clearKeybindButtons()
    for _, kb in ipairs(kbData or {}) do
        local b = spawnKeybindButton(kb.key, kb.x or 0.5, kb.y or 0.5, draggable, firing)
        table.insert(keybindButtons, { frame = b, key = kb.key })
    end
end

local function captureKeybindPositions()
    local vp = Camera.ViewportSize
    local out = {}
    for _, entry in ipairs(keybindButtons) do
        if entry.frame and entry.frame.Parent then
            local ap = entry.frame.AbsolutePosition
            local as = entry.frame.AbsoluteSize
            table.insert(out, {
                key = entry.key,
                x   = (ap.X + as.X * 0.5) / vp.X,
                y   = (ap.Y + as.Y * 0.5) / vp.Y,
            })
        end
    end
    return out
end

-- Load saved active keybinds on startup
loadKeybinds(Data.activeKeybinds, false, true)

-- ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════
-- ENTRY BUTTON
-- ══════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────

local entryBtn = btn(MainGui, "☰",
    UDim2.new(0,46,0,46), UDim2.new(0,10,0.5,-23),
    Color3.fromRGB(28,28,28), C.text, 18)
entryBtn.ZIndex = 20
uiStroke(entryBtn, C.border, 1)
makeDraggable(entryBtn)

-- ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════
-- MAIN MENU  (40% screen width)
-- ══════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────

local mainMenu = frame(MainGui, UDim2.new(0.4,0,0,195),
    UDim2.new(0.3,0,0.3,0), C.bg, 0, "MainMenu", 15)
mainMenu.Visible = false
uiCorner(mainMenu, 10)
uiStroke(mainMenu, C.border, 1)

-- header / drag handle
local mmHeader = makeHeader(mainMenu, "UI Script", mainMenu)
local mmClose = btn(mmHeader, "✕",
    UDim2.new(0,28,0,28), UDim2.new(1,-32,0.5,-14),
    Color3.fromRGB(70,35,35), C.text, 11)

-- ── Crosshair section ───────────────────────────────────────
local chSection = frame(mainMenu, UDim2.new(1,-16,0,88),
    UDim2.new(0,8,0,44), C.panel, 0, "CrossSection")
uiCorner(chSection, 7)
uiStroke(chSection, C.border, 1)

label(chSection, "Crosshair",
    UDim2.new(1,-60,0,22), UDim2.new(0,10,0,4), C.text, 13)

makeToggle(chSection, UDim2.new(1,-54,0,6), Data.crosshairEnabled,
    function(s)
        Data.crosshairEnabled = s
        refreshCrosshair()
        persistSave(Data)
    end)

label(chSection, "Decal ID",
    UDim2.new(0,55,0,18), UDim2.new(0,10,0,36), C.subtext, 11)

local decalInput = textbox(chSection, "Enter decal asset ID…",
    UDim2.new(1,-82,0,26), UDim2.new(0,66,0,32))
decalInput.Text = Data.crosshairDecalId or ""

local applyBtn = btn(chSection, "✓",
    UDim2.new(0,24,0,26), UDim2.new(1,-28,0,32),
    C.green, C.text, 13)

local function applyDecal()
    Data.crosshairDecalId = decalInput.Text
    refreshCrosshair()
    persistSave(Data)
end
applyBtn.MouseButton1Click:Connect(applyDecal)
decalInput.FocusLost:Connect(applyDecal)

-- ── Keyboard button ─────────────────────────────────────────
local openKbBtn = btn(mainMenu, "  ⌨  Keyboard",
    UDim2.new(1,-16,0,34), UDim2.new(0,8,0,140),
    C.blue, C.text, 13)
openKbBtn.TextXAlignment = Enum.TextXAlignment.Left
uiPadding(openKbBtn, 8)

-- wiring
mmClose.MouseButton1Click:Connect(function()
    mainMenu.Visible = false
end)

entryBtn.MouseButton1Click:Connect(function()
    mainMenu.Visible = not mainMenu.Visible
end)

-- ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════
-- KEYBOARD MENU
-- ══════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────

local kbMenu = frame(MainGui, UDim2.new(0.4,0,0,196),
    UDim2.new(0.55,0,0.25,0), C.bg, 0, "KbMenu", 15)
kbMenu.Visible = false
uiCorner(kbMenu, 10)
uiStroke(kbMenu, C.border, 1)

local kbHeader = makeHeader(kbMenu, "Keyboard", kbMenu)

local kbBackBtn = btn(kbHeader, "←",
    UDim2.new(0,28,0,28), UDim2.new(0,4,0.5,-14),
    C.item, C.text, 14)
local kbClose = btn(kbHeader, "✕",
    UDim2.new(0,28,0,28), UDim2.new(1,-32,0.5,-14),
    Color3.fromRGB(70,35,35), C.text, 11)

local function menuRow(parent, yOffset, icon, labelText)
    local r = btn(parent, icon .. "  " .. labelText,
        UDim2.new(1,-16,0,36), UDim2.new(0,8,0,yOffset),
        C.item, C.text, 13)
    r.TextXAlignment = Enum.TextXAlignment.Left
    uiPadding(r, 10)
    return r
end

local kbAddBtn    = menuRow(kbMenu,  44, "＋", "Keyboard Buttons")
local kbEditBtn   = menuRow(kbMenu,  86, "✎", "Edit Layout")
local kbSettBtn   = menuRow(kbMenu, 128, "⚙", "Settings")

kbBackBtn.MouseButton1Click:Connect(function()
    kbMenu.Visible = false
    mainMenu.Visible = true
end)

kbClose.MouseButton1Click:Connect(function()
    kbMenu.Visible = false
end)

openKbBtn.MouseButton1Click:Connect(function()
    mainMenu.Visible = false
    kbMenu.Visible   = true
end)

-- ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════
-- SETUP OVERLAY  (add new keybind buttons)
-- ══════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────

local setupOverlay = frame(MainGui, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    Color3.new(0,0,0), 0.55, "SetupOverlay", 22)
setupOverlay.Visible = false

-- Prompt card
local setupCard = frame(setupOverlay, UDim2.new(0,290,0,0),
    UDim2.new(0.5,-145,0,14), C.bg, 0, "SetupCard", 23)
setupCard.AutomaticSize = Enum.AutomaticSize.Y
uiCorner(setupCard, 10)
uiStroke(setupCard, C.border, 1)
uiPadding(setupCard, 12, 12, 10, 12)

local setupLayout = Instance.new("UIListLayout")
setupLayout.Padding, setupLayout.SortOrder =
    UDim.new(0,8), Enum.SortOrder.LayoutOrder
setupLayout.Parent = setupCard

local function cardLabel(txt, color, fs, lo)
    local l = Instance.new("TextLabel")
    l.Size, l.BackgroundTransparency = UDim2.new(1,0,0,20), 1
    l.Text, l.TextColor3, l.FontFace, l.TextSize =
        txt, color or C.text, FONT, fs or 13
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.LayoutOrder = lo or 0
    l.Parent = setupCard
    return l
end

cardLabel("⬤  Keybind Setup", C.text, 14, 1)
cardLabel("Press any keyboard key  —  or pick below:", C.subtext, 11, 2)

-- Mobile key picker
local pickerWrap = frame(setupCard, UDim2.new(1,0,0,66), UDim2.new(0,0,0,0),
    Color3.new(0,0,0), 1, "PickerWrap")
pickerWrap.LayoutOrder = 3
pickerWrap.AutomaticSize = Enum.AutomaticSize.Y

local pickerScroll = Instance.new("ScrollingFrame")
pickerScroll.Size                 = UDim2.new(1,0,0,66)
pickerScroll.BackgroundTransparency = 1
pickerScroll.BorderSizePixel      = 0
pickerScroll.ScrollBarThickness   = 4
pickerScroll.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)
pickerScroll.ScrollingDirection   = Enum.ScrollingDirection.X
pickerScroll.CanvasSize           = UDim2.new(0,0,1,0)
pickerScroll.AutomaticCanvasSize  = Enum.AutomaticSize.X
pickerScroll.Parent = pickerWrap

local pickerLayout = Instance.new("UIListLayout")
pickerLayout.FillDirection = Enum.FillDirection.Horizontal
pickerLayout.Padding       = UDim.new(0, 5)
pickerLayout.Parent        = pickerScroll

local QUICK_KEYS = {
    "E","F","Q","R","G","H","Z","X","C","V","B","T","Y","U","I",
    "Space","LeftShift","LeftControl","One","Two","Three","Four"
}

local function shortKeyName(k)
    local map = { Space="SPC", LeftShift="SHF", LeftControl="CTL",
        One="1", Two="2", Three="3", Four="4" }
    return map[k] or k
end

local function addKeyToSetup(keyName)
    local vp = Camera.ViewportSize
    local b  = spawnKeybindButton(keyName, 0.5, 0.35, true, false)
    table.insert(keybindButtons, { frame = b, key = keyName })
end

for _, kn in ipairs(QUICK_KEYS) do
    local kb = btn(pickerScroll, shortKeyName(kn),
        UDim2.new(0,40,0,52), UDim2.new(0,0,0,0),
        Color3.fromRGB(38,38,38), C.text, 11)
    kb.MouseButton1Click:Connect(function() addKeyToSetup(kn) end)
end

-- Done / Cancel row
local setupBtnWrap = frame(setupCard, UDim2.new(1,0,0,36),
    UDim2.new(0,0,0,0), Color3.new(0,0,0), 1, "BtnWrap")
setupBtnWrap.LayoutOrder = 4

local setupDoneBtn = btn(setupBtnWrap, "Done",
    UDim2.new(0,120,0,32), UDim2.new(0.5,-62,0.5,-16), C.green, C.text, 13)
local setupCancelBtn = btn(setupBtnWrap, "Cancel",
    UDim2.new(0,60,0,32), UDim2.new(0.5,66,0.5,-16),
    Color3.fromRGB(70,35,35), C.text, 12)

local setupInputConn = nil

local function beginSetupMode()
    mainMenu.Visible = false
    kbMenu.Visible   = false

    -- reload existing keybinds as draggable (no fire yet)
    clearKeybindButtons()
    for _, kb in ipairs(Data.activeKeybinds) do
        local b = spawnKeybindButton(kb.key, kb.x, kb.y, true, false)
        table.insert(keybindButtons, { frame = b, key = kb.key })
    end

    setupOverlay.Visible = true

    -- listen for physical keyboard input
    if setupInputConn then setupInputConn:Disconnect() end
    setupInputConn = UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            local kn = inp.KeyCode.Name
            if kn ~= "Unknown" then addKeyToSetup(kn) end
        end
    end)
end

local function endSetupMode(save)
    if setupInputConn then setupInputConn:Disconnect() setupInputConn = nil end
    setupOverlay.Visible = false

    if save then
        Data.activeKeybinds = captureKeybindPositions()
        persistSave(Data)
    end

    -- reload buttons for normal gameplay (fire=true, drag=false)
    loadKeybinds(Data.activeKeybinds, false, true)
    kbMenu.Visible = true
end

kbAddBtn.MouseButton1Click:Connect(beginSetupMode)
setupDoneBtn.MouseButton1Click:Connect(function()   endSetupMode(true)  end)
setupCancelBtn.MouseButton1Click:Connect(function() endSetupMode(false) end)

-- ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════
-- EDIT LAYOUT MODE
-- ══════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────

local editBar = frame(MainGui, UDim2.new(0,260,0,42),
    UDim2.new(0.5,-130,0,8), C.bg, 0, "EditBar", 22)
editBar.Visible = false
uiCorner(editBar, 8)
uiStroke(editBar, C.border, 1)

label(editBar, "Drag to reposition",
    UDim2.new(0,150,1,0), UDim2.new(0,10,0,0), C.subtext, 11)

local editDoneBtn = btn(editBar, "Done",
    UDim2.new(0,72,0,30), UDim2.new(1,-80,0.5,-15), C.green, C.text, 12)

local function beginEditMode()
    mainMenu.Visible = false
    kbMenu.Visible   = false

    clearKeybindButtons()
    for _, kb in ipairs(Data.activeKeybinds) do
        local b = spawnKeybindButton(kb.key, kb.x, kb.y, true, false)
        table.insert(keybindButtons, { frame = b, key = kb.key })
    end

    editBar.Visible = true
end

local function endEditMode()
    editBar.Visible         = false
    Data.activeKeybinds     = captureKeybindPositions()
    persistSave(Data)
    loadKeybinds(Data.activeKeybinds, false, true)
    kbMenu.Visible = true
end

kbEditBtn.MouseButton1Click:Connect(beginEditMode)
editDoneBtn.MouseButton1Click:Connect(endEditMode)

-- ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════
-- SAVES PANEL
-- ══════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────

local savesPanel = frame(MainGui, UDim2.new(0.42,0,0,300),
    UDim2.new(0.52,0,0.18,0), C.bg, 0, "SavesPanel", 15)
savesPanel.Visible = false
uiCorner(savesPanel, 10)
uiStroke(savesPanel, C.border, 1)
makeDraggable(savesPanel)

local spHeader = makeHeader(savesPanel, "Saves", savesPanel)

local spBack = btn(spHeader, "←",
    UDim2.new(0,28,0,28), UDim2.new(0,4,0.5,-14), C.item, C.text, 14)
local addSaveBtn = btn(spHeader, "+",
    UDim2.new(0,28,0,28), UDim2.new(1,-32,0.5,-14), C.green, C.text, 16)

-- Scroll area for save rows
local savesScroll = Instance.new("ScrollingFrame")
savesScroll.Size                  = UDim2.new(1,-16,1,-44)
savesScroll.Position              = UDim2.new(0,8,0,42)
savesScroll.BackgroundTransparency= 1
savesScroll.BorderSizePixel       = 0
savesScroll.ScrollBarThickness    = 4
savesScroll.ScrollBarImageColor3  = Color3.fromRGB(80,80,80)
savesScroll.CanvasSize            = UDim2.new(0,0,0,0)
savesScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
savesScroll.Parent = savesPanel

local savesListLayout = Instance.new("UIListLayout")
savesListLayout.Padding    = UDim.new(0, 5)
savesListLayout.SortOrder  = Enum.SortOrder.LayoutOrder
savesListLayout.Parent     = savesScroll

spBack.MouseButton1Click:Connect(function()
    savesPanel.Visible = false
    kbMenu.Visible     = true
end)

kbSettBtn.MouseButton1Click:Connect(function()
    kbMenu.Visible     = false
    savesPanel.Visible = true
end)

-- ─────────────────────────────────────────────────────────────
-- CONTEXT MENU  (three dots)
-- ─────────────────────────────────────────────────────────────

local ctxMenu = frame(MainGui, UDim2.new(0,130,0,98),
    UDim2.new(0,0,0,0), C.bg, 0, "CtxMenu", 30)
ctxMenu.Visible = false
uiCorner(ctxMenu, 7)
uiStroke(ctxMenu, Color3.fromRGB(70,70,70), 1)

local ctxLayout = Instance.new("UIListLayout")
ctxLayout.Padding, ctxLayout.SortOrder =
    UDim.new(0,4), Enum.SortOrder.LayoutOrder
ctxLayout.Parent = ctxMenu
uiPadding(ctxMenu, 5, 5, 5, 5)

local function ctxRow(txt, bg, lo)
    local b = btn(ctxMenu, txt,
        UDim2.new(1,0,0,26), UDim2.new(0,0,0,0), bg, C.text, 12)
    b.LayoutOrder  = lo
    b.TextXAlignment = Enum.TextXAlignment.Left
    uiPadding(b, 8)
    return b
end

local ctxLoad   = ctxRow("▶  Load",   C.blue,                1)
local ctxRename = ctxRow("✎  Rename", C.item,                2)
local ctxUpdate = ctxRow("↺  Update", C.item,                3)
local ctxDelete = ctxRow("⊘  Delete", Color3.fromRGB(80,30,30), 4)

local ctxTargetIdx = 0

-- Close ctx when clicking outside
UserInputService.InputBegan:Connect(function(inp)
    if (inp.UserInputType == Enum.UserInputType.MouseButton1
     or inp.UserInputType == Enum.UserInputType.Touch)
    and ctxMenu.Visible then
        task.defer(function() ctxMenu.Visible = false end)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- NAME INPUT DIALOG  (for + new save and rename)
-- ─────────────────────────────────────────────────────────────

local nameDialog = frame(MainGui, UDim2.new(1,0,1,0),
    UDim2.new(0,0,0,0), Color3.new(0,0,0), 0.6, "NameDialog", 28)
nameDialog.Visible = false

local nameCard = frame(nameDialog, UDim2.new(0,270,0,126),
    UDim2.new(0.5,-135,0.38,-63), C.bg, 0, "NameCard", 29)
uiCorner(nameCard, 10)
uiStroke(nameCard, C.border, 1)

local nameTitleLbl = label(nameCard, "Name this save:",
    UDim2.new(1,-20,0,22), UDim2.new(0,10,0,10), C.text, 14,
    Enum.TextXAlignment.Center)

local nameInput = textbox(nameCard, "Type a name…",
    UDim2.new(1,-20,0,30), UDim2.new(0,10,0,40))

local nameConfirm = btn(nameCard, "Confirm",
    UDim2.new(0,110,0,30), UDim2.new(0.5,-118,0,82), C.green, C.text, 13)
local nameCancel  = btn(nameCard, "Cancel",
    UDim2.new(0,80,0,30),  UDim2.new(0.5,8,0,82),
    Color3.fromRGB(70,35,35), C.text, 12)

local dialogMode   = "new"   -- "new" | "rename"
local renameTarget = 0

-- ── Refresh save list ────────────────────────────────────────
local function refreshSaves()
    for _, c in ipairs(savesScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    if #Data.saves == 0 then
        local el = label(savesScroll,
            "No saves yet.  Press  +  to create one.",
            UDim2.new(1,0,0,40), UDim2.new(0,0,0,0),
            C.subtext, 12, Enum.TextXAlignment.Center)
        el.LayoutOrder = 1
        return
    end

    for i, sv in ipairs(Data.saves) do
        local row = frame(savesScroll, UDim2.new(1,0,0,40),
            UDim2.new(0,0,0,0), C.panel, 0, "SaveRow_"..i)
        row.LayoutOrder = i
        uiCorner(row, 6)

        label(row, sv.name or ("Save "..i),
            UDim2.new(1,-90,1,0), UDim2.new(0,10,0,0), C.text, 13)

        local dotsBtn = btn(row, "⋯",
            UDim2.new(0,30,0,30), UDim2.new(1,-36,0.5,-15),
            C.item, C.text, 14)
        local idx = i
        dotsBtn.MouseButton1Click:Connect(function()
            ctxTargetIdx = idx
            -- position context menu near the dots button
            local ap = dotsBtn.AbsolutePosition
            ctxMenu.Position = UDim2.new(0, ap.X - 130, 0, ap.Y + 34)
            ctxMenu.ZIndex = 32
            for _, ch in ipairs(ctxMenu:GetDescendants()) do
                if ch:IsA("GuiObject") then ch.ZIndex = 32 end
            end
            ctxMenu.Visible = true
        end)
    end
end

-- ── Context menu actions ─────────────────────────────────────
ctxLoad.MouseButton1Click:Connect(function()
    ctxMenu.Visible = false
    local sv = Data.saves[ctxTargetIdx]
    if not sv then return end
    Data.activeKeybinds = {}
    for _, kb in ipairs(sv.keybinds or {}) do
        table.insert(Data.activeKeybinds, { key=kb.key, x=kb.x, y=kb.y })
    end
    persistSave(Data)
    loadKeybinds(Data.activeKeybinds, false, true)
    savesPanel.Visible = false
    kbMenu.Visible     = true
end)

ctxRename.MouseButton1Click:Connect(function()
    ctxMenu.Visible  = false
    dialogMode       = "rename"
    renameTarget     = ctxTargetIdx
    nameTitleLbl.Text = "Rename save:"
    nameInput.Text   = Data.saves[ctxTargetIdx] and Data.saves[ctxTargetIdx].name or ""
    nameDialog.Visible = true
end)

ctxUpdate.MouseButton1Click:Connect(function()
    ctxMenu.Visible = false
    local sv = Data.saves[ctxTargetIdx]
    if not sv then return end
    sv.keybinds = captureKeybindPositions()
    -- also use current active keybinds if none on-screen
    if #sv.keybinds == 0 then
        for _, kb in ipairs(Data.activeKeybinds) do
            table.insert(sv.keybinds, { key=kb.key, x=kb.x, y=kb.y })
        end
    end
    persistSave(Data)
    refreshSaves()
end)

ctxDelete.MouseButton1Click:Connect(function()
    ctxMenu.Visible = false
    table.remove(Data.saves, ctxTargetIdx)
    persistSave(Data)
    refreshSaves()
end)

-- ── Add new save (+) ─────────────────────────────────────────
addSaveBtn.MouseButton1Click:Connect(function()
    dialogMode        = "new"
    nameTitleLbl.Text = "Name this save:"
    nameInput.Text    = ""
    nameDialog.Visible = true
end)

nameConfirm.MouseButton1Click:Connect(function()
    local name = nameInput.Text ~= "" and nameInput.Text
        or ("Save " .. (#Data.saves + 1))

    if dialogMode == "rename" then
        if Data.saves[renameTarget] then
            Data.saves[renameTarget].name = name
        end
    else
        -- snapshot current active keybinds
        local kbs = {}
        for _, kb in ipairs(Data.activeKeybinds) do
            table.insert(kbs, { key=kb.key, x=kb.x, y=kb.y })
        end
        table.insert(Data.saves, { name = name, keybinds = kbs })
    end

    persistSave(Data)
    refreshSaves()
    nameDialog.Visible = false
end)

nameCancel.MouseButton1Click:Connect(function()
    nameDialog.Visible = false
end)

-- Initial render
refreshSaves()

-- ─────────────────────────────────────────────────────────────
-- DONE
-- ─────────────────────────────────────────────────────────────
print("[MobileUIScript] ✓ Loaded  |  File: " .. SAVE_FILE)
