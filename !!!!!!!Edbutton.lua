-- ============================================================
--  UI Layout Editor — Roblox Exploit Script  v2
--  Mobile-first | Touch-reliable drag + tap system
-- ============================================================

local Players          = game:GetService("Players")
local UIS              = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
--  CONSTANTS
-- ============================================================

local PLACE_ID  = tostring(game.PlaceId)
local GAME_URL  = "roblox.com/games/" .. PLACE_ID
local SAVE_FILE = "UILayoutEditor_Layouts.json"

local C = {
    ACCENT     = Color3.fromRGB(0,   212, 255),
    ACCENT_DIM = Color3.fromRGB(0,    60,  80),
    BG_DARK    = Color3.fromRGB(10,   10,  20),
    BG_MID     = Color3.fromRGB(18,   18,  32),
    BG_LIGHT   = Color3.fromRGB(30,   30,  50),
    WHITE      = Color3.fromRGB(255, 255, 255),
    DIM        = Color3.fromRGB(130, 130, 155),
    RED        = Color3.fromRGB(239,  68,  68),
    RED_DIM    = Color3.fromRGB( 45,  10,  10),
    WARN       = Color3.fromRGB(250, 170,   0),
}

local TAP_THRESHOLD = 14   -- pixels of movement before a press becomes a drag

-- ============================================================
--  PERSISTENCE
-- ============================================================

local layouts = {}

local function loadLayouts()
    if readfile then
        local ok, raw = pcall(readfile, SAVE_FILE)
        if ok and raw and raw ~= "" then
            local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok2 and type(parsed) == "table" then layouts = parsed end
        end
    end
end

local function saveLayouts()
    if writefile then
        local ok, data = pcall(HttpService.JSONEncode, HttpService, layouts)
        if ok then pcall(writefile, SAVE_FILE, data) end
    end
end

loadLayouts()

-- ============================================================
--  DRAG UTILITY
--  makeDraggable(frame, onTap?)
--    • Drags the frame freely within the viewport
--    • Calls onTap() when released with < TAP_THRESHOLD movement
-- ============================================================

local function makeDraggable(frame, onTap)
    local active    = false
    local startTouch = nil
    local startOff   = nil

    frame.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        active     = true
        startTouch = Vector2.new(input.Position.X, input.Position.Y)
        startOff   = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
    end)

    UIS.InputChanged:Connect(function(input)
        if not active then return end
        if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local vp = workspace.CurrentCamera.ViewportSize
        local dx = input.Position.X - startTouch.X
        local dy = input.Position.Y - startTouch.Y
        local nx = math.clamp(startOff.X + dx, 0, vp.X - frame.AbsoluteSize.X)
        local ny = math.clamp(startOff.Y + dy, 0, vp.Y - frame.AbsoluteSize.Y)
        frame.Position = UDim2.fromOffset(nx, ny)
    end)

    UIS.InputEnded:Connect(function(input)
        if not active then return end
        if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        active = false
        if startTouch then
            local dx = math.abs(input.Position.X - startTouch.X)
            local dy = math.abs(input.Position.Y - startTouch.Y)
            if onTap and dx < TAP_THRESHOLD and dy < TAP_THRESHOLD then
                task.defer(onTap)   -- defer so drag state is cleared first
            end
        end
        startTouch = nil
    end)
end

-- ============================================================
--  GUI HELPERS
-- ============================================================

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = p
end

local function pad(p, t, b, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 10)
    u.PaddingBottom = UDim.new(0, b or t or 10)
    u.PaddingLeft   = UDim.new(0, l or t or 10)
    u.PaddingRight  = UDim.new(0, r or l or t or 10)
    u.Parent = p
end

local function stroke(p, color, alpha, thick)
    local s = Instance.new("UIStroke")
    s.Color        = color or C.WHITE
    s.Transparency = alpha or 0.75
    s.Thickness    = thick or 1
    s.Parent       = p
end

local function vlist(p, gap)
    local l = Instance.new("UIListLayout")
    l.Padding               = UDim.new(0, gap or 8)
    l.SortOrder             = Enum.SortOrder.LayoutOrder
    l.FillDirection         = Enum.FillDirection.Vertical
    l.HorizontalAlignment   = Enum.HorizontalAlignment.Left
    l.Parent                = p
    return l
end

local function grid2(p, h, gapX, gapY)
    local g = Instance.new("UIGridLayout")
    g.CellSize    = UDim2.new(0.5, -(gapX or 6) / 2, 0, h or 38)
    g.CellPadding = UDim2.new(0, gapX or 6, 0, gapY or 6)
    g.SortOrder   = Enum.SortOrder.LayoutOrder
    g.Parent      = p
end

local function sep(p, order)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, 1)
    f.BackgroundColor3 = C.WHITE
    f.BackgroundTransparency = 0.84
    f.BorderSizePixel  = 0
    f.LayoutOrder      = order or 99
    f.Parent           = p
end

local function lbl(p, text, sz, color, bold, order)
    local t = Instance.new("TextLabel")
    t.Text             = text
    t.TextSize         = sz or 13
    t.TextColor3       = color or C.WHITE
    t.Font             = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    t.BackgroundTransparency = 1
    t.Size             = UDim2.new(1, 0, 0, (sz or 13) + 6)
    t.TextXAlignment   = Enum.TextXAlignment.Left
    t.LayoutOrder      = order or 0
    t.Parent           = p
    return t
end

local function btn(p, text, bg, fg, h, order)
    local b = Instance.new("TextButton")
    b.Text             = text
    b.TextSize         = 13
    b.Font             = Enum.Font.GothamBold
    b.TextColor3       = fg or C.WHITE
    b.BackgroundColor3 = bg or C.BG_LIGHT
    b.Size             = UDim2.new(1, 0, 0, h or 40)
    b.AutoButtonColor  = false
    b.LayoutOrder      = order or 0
    corner(b, 10)
    b.Parent = p
    return b
end

-- Fit a Frame's height to its UIListLayout children
local function fitHeight(frame, list, extra)
    task.defer(function()
        frame.Size = UDim2.fromOffset(
            frame.AbsoluteSize.X,
            list.AbsoluteContentSize.Y + (extra or 24)
        )
    end)
end

-- ============================================================
--  ROOT SCREENGUI
-- ============================================================

if PlayerGui:FindFirstChild("UILayoutEditor") then
    PlayerGui.UILayoutEditor:Destroy()
end

local Root = Instance.new("ScreenGui")
Root.Name           = "UILayoutEditor"
Root.ResetOnSpawn   = false
Root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Root.IgnoreGuiInset = true
Root.DisplayOrder   = 999
Root.Parent         = PlayerGui

-- ============================================================
--  STARTUP NOTIFICATION
-- ============================================================
do
    local f = Instance.new("Frame")
    f.Size             = UDim2.fromOffset(320, 64)
    f.Position         = UDim2.new(0.5, -160, 0, 14)
    f.BackgroundColor3 = C.BG_DARK
    f.ZIndex           = 200
    corner(f, 14)
    stroke(f, C.ACCENT, 0.3, 1.5)
    pad(f, 10, 10, 14, 14)
    f.Parent = Root

    local t1 = Instance.new("TextLabel")
    t1.Text  = "UI Layout Editor  —  Ready"
    t1.TextSize = 13; t1.Font = Enum.Font.GothamBold
    t1.TextColor3 = C.ACCENT; t1.BackgroundTransparency = 1
    t1.Size = UDim2.new(1, 0, 0, 18); t1.ZIndex = 201
    t1.TextXAlignment = Enum.TextXAlignment.Left; t1.Parent = f

    local t2 = Instance.new("TextLabel")
    t2.Text  = "Game ID: " .. PLACE_ID .. "  |  " .. GAME_URL
    t2.TextSize = 10; t2.Font = Enum.Font.Gotham
    t2.TextColor3 = C.DIM; t2.BackgroundTransparency = 1
    t2.Size = UDim2.new(1, 0, 0, 14); t2.Position = UDim2.fromOffset(0, 22)
    t2.ZIndex = 201; t2.TextXAlignment = Enum.TextXAlignment.Left
    t2.TextTruncate = Enum.TextTruncate.AtEnd; t2.Parent = f

    task.delay(3.5, function()
        local ti = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
        TweenService:Create(f,  ti, {BackgroundTransparency = 1}):Play()
        TweenService:Create(t1, ti, {TextTransparency = 1}):Play()
        TweenService:Create(t2, ti, {TextTransparency = 1}):Play()
        task.wait(0.6); f:Destroy()
    end)
end

-- ============================================================
--  STATE
-- ============================================================

local editMode        = false
local selectedElem    = nil
local highlightMap    = {}
local originalStates  = {}
local undoStates      = {}

-- ============================================================
--  MAIN TOGGLE BUTTON
-- ============================================================

local ToggleBtn = Instance.new("Frame")  -- Frame, not TextButton, avoids button event conflicts
ToggleBtn.Name             = "ToggleBtn"
ToggleBtn.Size             = UDim2.fromOffset(54, 54)
ToggleBtn.Position         = UDim2.new(0, 16, 0.5, -27)
ToggleBtn.BackgroundColor3 = C.BG_MID
ToggleBtn.ZIndex           = 10
corner(ToggleBtn, 27)
stroke(ToggleBtn, C.WHITE, 0.76, 1)
ToggleBtn.Parent = Root

local toggleIcon = Instance.new("TextLabel")
toggleIcon.Text           = "☰"
toggleIcon.TextSize       = 24
toggleIcon.Font           = Enum.Font.GothamBold
toggleIcon.TextColor3     = C.WHITE
toggleIcon.BackgroundTransparency = 1
toggleIcon.Size           = UDim2.fromScale(1, 1)
toggleIcon.TextXAlignment = Enum.TextXAlignment.Center
toggleIcon.ZIndex         = 11
toggleIcon.Parent         = ToggleBtn

-- ============================================================
--  MAIN MENU PANEL
-- ============================================================

local MainMenu = Instance.new("Frame")
MainMenu.Name             = "MainMenu"
MainMenu.Size             = UDim2.fromOffset(244, 10)
MainMenu.Position         = UDim2.fromOffset(80, 200)
MainMenu.BackgroundColor3 = C.BG_DARK
MainMenu.BackgroundTransparency = 0.04
MainMenu.Visible          = false
MainMenu.ZIndex           = 20
corner(MainMenu, 14)
stroke(MainMenu, C.WHITE, 0.78, 1)
MainMenu.Parent = Root
makeDraggable(MainMenu)

local menuList = vlist(MainMenu, 8)
pad(MainMenu, 12, 14, 12, 12)

-- Title
local mTitle = lbl(MainMenu, "UI LAYOUT EDITOR", 10, C.ACCENT, true, 0)
mTitle.LetterSpacing = 2; mTitle.Size = UDim2.new(1, 0, 0, 16)

sep(MainMenu, 1)

-- "BUTTON LAYOUTS" header
local blHeader = lbl(MainMenu, "BUTTON LAYOUTS", 9, C.DIM, true, 2)
blHeader.LetterSpacing = 2; blHeader.Size = UDim2.new(1, 0, 0, 14)

-- Layouts scroll
local LayoutsScroll = Instance.new("ScrollingFrame")
LayoutsScroll.BackgroundTransparency = 1
LayoutsScroll.BorderSizePixel       = 0
LayoutsScroll.ScrollBarThickness    = 2
LayoutsScroll.ScrollBarImageColor3  = C.ACCENT
LayoutsScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
LayoutsScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
LayoutsScroll.ClipsDescendants      = true
LayoutsScroll.LayoutOrder           = 3
LayoutsScroll.Parent                = MainMenu
vlist(LayoutsScroll, 4)

sep(MainMenu, 4)

local EditLayoutBtn = btn(MainMenu, "✎   Edit Layout", C.BG_LIGHT, C.ACCENT, 44, 5)
stroke(EditLayoutBtn, C.ACCENT, 0.5, 1.2)

local function refreshMenuHeight()
    task.defer(function()
        MainMenu.Size = UDim2.fromOffset(244, menuList.AbsoluteContentSize.Y + 26)
    end)
end

-- ============================================================
--  THREE-DOT MENU
-- ============================================================

local activeDotMenu = nil
local function closeDotMenu()
    if activeDotMenu and activeDotMenu.Parent then activeDotMenu:Destroy() end
    activeDotMenu = nil
end

-- ============================================================
--  RENDER LAYOUTS LIST
-- ============================================================

local function renderLayouts()
    for _, c in ipairs(LayoutsScroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end

    if #layouts == 0 then
        local e = Instance.new("TextLabel")
        e.Text = "No layouts saved yet"; e.TextSize = 11
        e.Font = Enum.Font.Gotham; e.TextColor3 = C.DIM
        e.BackgroundTransparency = 1
        e.Size = UDim2.new(1, 0, 0, 28)
        e.TextXAlignment = Enum.TextXAlignment.Center
        e.Parent = LayoutsScroll
        LayoutsScroll.Size = UDim2.new(1, 0, 0, 28)
        refreshMenuHeight(); return
    end

    for i, layout in ipairs(layouts) do
        local compat = layout.placeId == PLACE_ID

        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 40)
        row.BackgroundColor3 = C.BG_LIGHT
        row.BorderSizePixel  = 0
        row.LayoutOrder      = i
        corner(row, 8)
        row.Parent = LayoutsScroll

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Text           = layout.name .. (not compat and " ⚠" or "")
        nameLbl.TextSize       = 12
        nameLbl.Font           = Enum.Font.Gotham
        nameLbl.TextColor3     = compat and C.WHITE or C.WARN
        nameLbl.BackgroundTransparency = 1
        nameLbl.Size           = UDim2.new(1, -42, 1, 0)
        nameLbl.Position       = UDim2.fromOffset(10, 0)
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate   = Enum.TextTruncate.AtEnd
        nameLbl.ZIndex         = 21
        nameLbl.Parent         = row

        -- Tap name to load
        local nameHitbox = Instance.new("TextButton")
        nameHitbox.Size              = UDim2.new(1, -42, 1, 0)
        nameHitbox.Position          = UDim2.fromOffset(0, 0)
        nameHitbox.BackgroundTransparency = 1
        nameHitbox.Text              = ""
        nameHitbox.ZIndex            = 22
        nameHitbox.Parent            = row

        nameHitbox.Activated:Connect(function()
            if not compat then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Incompatible Layout",
                        Text  = "Saved for game ID: " .. (layout.placeId or "?"),
                        Duration = 3,
                    })
                end)
                return
            end
            for elemName, d in pairs(layout.elements) do
                local elem = PlayerGui:FindFirstChild(elemName, true)
                if elem and elem:IsA("GuiObject") then
                    elem.Size     = UDim2.new(d.sXS, d.sXO, d.sYS, d.sYO)
                    elem.Position = UDim2.new(d.pXS, d.pXO, d.pYS, d.pYO)
                    elem.BackgroundTransparency = d.trans or 0
                end
            end
            MainMenu.Visible = false
        end)

        -- Three-dot button
        local dotBtn = Instance.new("TextButton")
        dotBtn.Text            = "⋯"
        dotBtn.TextSize        = 18
        dotBtn.Font            = Enum.Font.GothamBold
        dotBtn.TextColor3      = C.DIM
        dotBtn.BackgroundTransparency = 1
        dotBtn.Size            = UDim2.fromOffset(40, 40)
        dotBtn.Position        = UDim2.new(1, -40, 0, 0)
        dotBtn.ZIndex          = 22
        dotBtn.Parent          = row

        dotBtn.Activated:Connect(function()
            closeDotMenu()
            local dm = Instance.new("Frame")
            dm.Size             = UDim2.fromOffset(130, 80)
            dm.BackgroundColor3 = Color3.fromRGB(16, 16, 28)
            dm.BorderSizePixel  = 0
            dm.ZIndex           = 60
            corner(dm, 10)
            stroke(dm, C.WHITE, 0.76, 1)
            dm.Parent = Root
            activeDotMenu = dm

            local abs = dotBtn.AbsolutePosition
            local vp  = workspace.CurrentCamera.ViewportSize
            dm.Position = UDim2.fromOffset(
                math.clamp(abs.X - 94, 4, vp.X - 136),
                math.clamp(abs.Y + 36, 4, vp.Y - 86)
            )

            vlist(dm, 0)

            local function dmOpt(text, fg, order)
                local o = Instance.new("TextButton")
                o.Text = text; o.TextSize = 12; o.Font = Enum.Font.Gotham
                o.TextColor3 = fg; o.BackgroundTransparency = 1
                o.Size = UDim2.new(1, 0, 0, 40); o.AutoButtonColor = false
                o.LayoutOrder = order; o.ZIndex = 61
                o.TextXAlignment = Enum.TextXAlignment.Left
                pad(o, 0, 0, 12, 0)
                o.Parent = dm
                o.MouseEnter:Connect(function()
                    o.BackgroundColor3 = C.WHITE; o.BackgroundTransparency = 0.9
                end)
                o.MouseLeave:Connect(function() o.BackgroundTransparency = 1 end)
                return o
            end

            local renameOpt = dmOpt("Rename", C.WHITE, 1)
            local deleteOpt = dmOpt("Delete", C.RED,   2)

            renameOpt.Activated:Connect(function()
                closeDotMenu()
                nameLbl.Visible = false
                local box = Instance.new("TextBox")
                box.Text = layout.name; box.TextSize = 12; box.Font = Enum.Font.Gotham
                box.TextColor3 = C.WHITE; box.BackgroundColor3 = C.BG_MID
                box.Size = UDim2.new(1, -48, 1, -8); box.Position = UDim2.new(0, 8, 0, 4)
                box.ClearTextOnFocus = false; box.ZIndex = 25
                corner(box, 6); stroke(box, C.ACCENT, 0.4, 1)
                box.Parent = row
                local function commit()
                    local v = box.Text ~= "" and box.Text or layout.name
                    layouts[i].name = v; saveLayouts()
                    box:Destroy(); nameLbl.Visible = true
                    nameLbl.Text = v .. (not compat and " ⚠" or "")
                end
                box.FocusLost:Connect(commit)
                task.defer(function() pcall(function() box:CaptureFocus() end) end)
            end)

            deleteOpt.Activated:Connect(function()
                closeDotMenu()
                table.remove(layouts, i)
                saveLayouts(); renderLayouts(); refreshMenuHeight()
            end)
        end)
    end

    local rowH = 40 + 4
    LayoutsScroll.Size = UDim2.new(1, 0, 0, math.min(#layouts, 5) * rowH)
    refreshMenuHeight()
end

-- ============================================================
--  TOGGLE BUTTON TAP → OPEN/CLOSE MENU
-- ============================================================

local menuOpen = false

makeDraggable(ToggleBtn, function()
    if editMode then return end
    menuOpen = not menuOpen
    MainMenu.Visible = menuOpen
    if menuOpen then
        local abs = ToggleBtn.AbsolutePosition
        local vp  = workspace.CurrentCamera.ViewportSize
        MainMenu.Position = UDim2.fromOffset(
            math.clamp(abs.X + 60, 4, vp.X - 248),
            math.clamp(abs.Y,       4, vp.Y - 300)
        )
        renderLayouts()
    end
    closeDotMenu()
end)

-- ============================================================
--  SLIDER HELPER
-- ============================================================

local function makeSlider(parent, order, labelText, initVal, minVal, maxVal, fmt, onChange)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 56); wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = order; wrap.Parent = parent

    local hRow = Instance.new("Frame")
    hRow.Size = UDim2.new(1, 0, 0, 16); hRow.BackgroundTransparency = 1; hRow.Parent = wrap

    local l = Instance.new("TextLabel")
    l.Text = labelText; l.TextSize = 9; l.Font = Enum.Font.GothamBold
    l.TextColor3 = C.DIM; l.BackgroundTransparency = 1
    l.Size = UDim2.new(0.6, 0, 1, 0); l.LetterSpacing = 1
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = hRow

    local valLbl = Instance.new("TextLabel")
    valLbl.Text = string.format(fmt, initVal); valLbl.TextSize = 9
    valLbl.Font = Enum.Font.GothamBold; valLbl.TextColor3 = C.ACCENT
    valLbl.BackgroundTransparency = 1; valLbl.Size = UDim2.new(0.4, 0, 1, 0)
    valLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.Parent = hRow

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 28); track.Position = UDim2.fromOffset(0, 20)
    track.BackgroundColor3 = C.BG_LIGHT; track.BorderSizePixel = 0
    corner(track, 8); track.Parent = wrap

    local fill = Instance.new("Frame")
    local initRel = (initVal - minVal) / (maxVal - minVal)
    fill.Size = UDim2.new(math.clamp(initRel, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = C.ACCENT; fill.BorderSizePixel = 0
    corner(fill, 8); fill.Parent = track

    local held = false
    local function apply(posX)
        local rel = math.clamp((posX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        local val = minVal + rel * (maxVal - minVal)
        valLbl.Text = string.format(fmt, val)
        onChange(val)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        held = true; apply(input.Position.X)
    end)

    UIS.InputChanged:Connect(function(input)
        if not held then return end
        if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        apply(input.Position.X)
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            held = false
        end
    end)
end

-- ============================================================
--  EDIT PANEL
-- ============================================================

local EditPanel = nil
local function destroyEditPanel()
    if EditPanel and EditPanel.Parent then EditPanel:Destroy() end
    EditPanel = nil; selectedElem = nil
end

local function showEditPanel(elem)
    destroyEditPanel()
    selectedElem = elem
    undoStates[elem] = {
        size  = elem.Size, pos = elem.Position, trans = elem.BackgroundTransparency
    }

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(272, 10)
    panel.Position = UDim2.new(0.5, -136, 0.5, -120)
    panel.BackgroundColor3 = C.BG_DARK
    panel.BackgroundTransparency = 0.04
    panel.ZIndex = 40
    corner(panel, 14)
    stroke(panel, C.ACCENT, 0.42, 1.5)
    panel.Parent = Root
    EditPanel = panel
    makeDraggable(panel)

    local pList = vlist(panel, 8)
    pad(panel, 12, 14, 12, 12)

    -- Title
    local titleRow = Instance.new("Frame")
    titleRow.Size = UDim2.new(1, 0, 0, 22); titleRow.BackgroundTransparency = 1
    titleRow.LayoutOrder = 0; titleRow.Parent = panel
    lbl(titleRow, elem.Name, 14, C.WHITE, true).Size = UDim2.new(1, 0, 1, 0)

    sep(panel, 1)

    -- Size slider (0.5 – 2.0 displayed as %)
    makeSlider(panel, 2, "SIZE", math.max(elem.Size.X.Scale, 0.5), 0.5, 2.0, "%.0f%%",
        function(v) elem.Size = UDim2.new(v, elem.Size.X.Offset, v, elem.Size.Y.Offset) end)

    -- Transparency slider
    makeSlider(panel, 3, "TRANSPARENCY", elem.BackgroundTransparency, 0, 1, "%.0f%%",
        function(v) elem.BackgroundTransparency = v end)

    sep(panel, 4)

    -- 2×2 action buttons
    local gridFrame = Instance.new("Frame")
    gridFrame.Size = UDim2.new(1, 0, 0, 88); gridFrame.BackgroundTransparency = 1
    gridFrame.LayoutOrder = 5; gridFrame.Parent = panel
    grid2(gridFrame, 38, 6, 6)

    local function pBtn(text, bg, fg, order)
        local b = Instance.new("TextButton")
        b.Text = text; b.TextSize = 12; b.Font = Enum.Font.GothamBold
        b.TextColor3 = fg; b.BackgroundColor3 = bg
        b.AutoButtonColor = false; b.LayoutOrder = order; b.ZIndex = 41
        corner(b, 9); b.Parent = gridFrame; return b
    end

    local cancelBtn = pBtn("Cancel",  C.BG_LIGHT,   C.DIM,    1)
    local doneBtn   = pBtn("Done",    C.ACCENT_DIM, C.ACCENT, 2)
    local undoBtn   = pBtn("Undo",    C.BG_LIGHT,   C.DIM,    3)
    local resetBtn  = pBtn("Default", C.BG_LIGHT,   C.DIM,    4)
    stroke(doneBtn, C.ACCENT, 0.45, 1)

    cancelBtn.Activated:Connect(function()
        local s = undoStates[elem]
        if s then elem.Size = s.size; elem.Position = s.pos; elem.BackgroundTransparency = s.trans end
        destroyEditPanel()
    end)

    doneBtn.Activated:Connect(function() destroyEditPanel() end)

    undoBtn.Activated:Connect(function()
        local s = undoStates[elem]
        if s then elem.Size = s.size; elem.Position = s.pos; elem.BackgroundTransparency = s.trans end
    end)

    resetBtn.Activated:Connect(function()
        local o = originalStates[elem]
        if o then elem.Size = o.size; elem.Position = o.pos; elem.BackgroundTransparency = o.trans end
    end)

    fitHeight(panel, pList, 28)
end

-- ============================================================
--  HIGHLIGHT ALL EDITABLE ELEMENTS
-- ============================================================

local function clearHighlights()
    for elem, s in pairs(highlightMap) do
        if s and s.Parent then s:Destroy() end
    end
    highlightMap = {}; originalStates = {}
end

local function highlightAll()
    local function scan(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("GuiObject") and not obj:IsDescendantOf(Root) then
                originalStates[obj] = {
                    size = obj.Size, pos = obj.Position, trans = obj.BackgroundTransparency
                }
                local s = Instance.new("UIStroke")
                s.Color = C.ACCENT; s.Transparency = 0.4; s.Thickness = 2; s.Parent = obj
                highlightMap[obj] = s

                local hitbox = Instance.new("TextButton")
                hitbox.Size = UDim2.fromScale(1, 1); hitbox.Text = ""
                hitbox.BackgroundTransparency = 1; hitbox.ZIndex = obj.ZIndex + 1
                hitbox.Parent = obj

                hitbox.Activated:Connect(function()
                    if editMode then showEditPanel(obj) end
                end)

                scan(obj)
            end
        end
    end
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui ~= Root and gui:IsA("ScreenGui") then scan(gui) end
    end
end

-- ============================================================
--  EXIT BUTTON (shown during edit mode)
-- ============================================================

local ExitBtn = nil
local function destroyExitBtn()
    if ExitBtn and ExitBtn.Parent then ExitBtn:Destroy() end
    ExitBtn = nil
end

-- ============================================================
--  DIALOGS
-- ============================================================

local ActiveDialog = nil
local function closeDialog()
    if ActiveDialog and ActiveDialog.Parent then ActiveDialog:Destroy() end
    ActiveDialog = nil
end

local function makeDialog(w)
    closeDialog()
    local d = Instance.new("Frame")
    d.Size = UDim2.fromOffset(w or 272, 10)
    d.Position = UDim2.new(0.5, -((w or 272) / 2), 0.5, -80)
    d.BackgroundColor3 = C.BG_DARK
    d.BackgroundTransparency = 0.04
    d.ZIndex = 80
    corner(d, 14)
    ActiveDialog = d
    d.Parent = Root
    return d
end

local function makeDialogButtons(parent, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38); row.BackgroundTransparency = 1
    row.LayoutOrder = order or 10; row.Parent = parent
    grid2(row, 38, 8)
    return row
end

-- Forward declaration
local showExitDialog

local function showDiscardConfirm(onBack)
    local d = makeDialog()
    stroke(d, C.RED, 0.4, 1.5)
    local dList = vlist(d, 10); pad(d, 14, 14, 14, 14)
    lbl(d, "⚠   Are you sure?", 14, C.RED, true, 0)
    lbl(d, "All unsaved edits will be permanently lost.", 11, C.DIM, false, 1)
    local row = makeDialogButtons(d, 2)
    local backB    = btn(row, "Go Back", C.BG_LIGHT,   C.DIM,   38, 1)
    local discardB = btn(row, "Discard", C.RED_DIM,    C.RED,   38, 2)
    stroke(discardB, C.RED, 0.5, 1)
    fitHeight(d, dList, 28)

    backB.Activated:Connect(function()
        closeDialog(); if onBack then onBack() end
    end)
    discardB.Activated:Connect(function()
        for elem, orig in pairs(originalStates) do
            if elem and elem.Parent then
                elem.Size = orig.size; elem.Position = orig.pos
                elem.BackgroundTransparency = orig.trans
            end
        end
        closeDialog(); clearHighlights(); destroyEditPanel(); destroyExitBtn()
        undoStates = {}; editMode = false; selectedElem = nil
    end)
end

local function showSaveNameDialog(elemData)
    local d = makeDialog()
    stroke(d, C.ACCENT, 0.42, 1.5)
    local dList = vlist(d, 10); pad(d, 14, 14, 14, 14)
    lbl(d, "Name Your Layout", 14, C.WHITE, true, 0)
    lbl(d, "Game ID " .. PLACE_ID .. " will be locked to this layout.", 10, C.DIM, false, 1)

    local box = Instance.new("TextBox")
    box.PlaceholderText = "Layout " .. (#layouts + 1); box.Text = ""
    box.TextSize = 13; box.Font = Enum.Font.Gotham
    box.TextColor3 = C.WHITE; box.PlaceholderColor3 = C.DIM
    box.BackgroundColor3 = C.BG_LIGHT
    box.Size = UDim2.new(1, 0, 0, 40); box.LayoutOrder = 2
    box.ClearTextOnFocus = false; box.ZIndex = 82
    corner(box, 9); stroke(box, C.ACCENT, 0.5, 1); box.Parent = d

    local row = makeDialogButtons(d, 3)
    local cancelB = btn(row, "Cancel",    C.BG_LIGHT,   C.DIM,    38, 1)
    local saveB   = btn(row, "Save",      C.ACCENT_DIM, C.ACCENT, 38, 2)
    stroke(saveB, C.ACCENT, 0.45, 1)
    fitHeight(d, dList, 28)
    task.defer(function() pcall(function() box:CaptureFocus() end) end)

    local function doSave()
        local name = box.Text ~= "" and box.Text or ("Layout " .. (#layouts + 1))
        table.insert(layouts, {
            name    = name,
            placeId = PLACE_ID,
            gameUrl = GAME_URL,
            savedAt = os.time(),
            elements = elemData,
        })
        saveLayouts()
        closeDialog(); clearHighlights(); destroyEditPanel(); destroyExitBtn()
        undoStates = {}; editMode = false; selectedElem = nil
        -- Open menu at layouts page
        renderLayouts()
        local abs = ToggleBtn.AbsolutePosition
        local vp  = workspace.CurrentCamera.ViewportSize
        MainMenu.Position = UDim2.fromOffset(
            math.clamp(abs.X + 60, 4, vp.X - 248),
            math.clamp(abs.Y,       4, vp.Y - 300)
        )
        MainMenu.Visible = true; menuOpen = true
    end

    cancelB.Activated:Connect(function()
        closeDialog(); clearHighlights(); destroyEditPanel(); destroyExitBtn()
        undoStates = {}; editMode = false; selectedElem = nil
    end)
    saveB.Activated:Connect(doSave)
    box.FocusLost:Connect(function(enter) if enter then doSave() end end)
end

showExitDialog = function()
    local d = makeDialog()
    stroke(d, C.WHITE, 0.78, 1)
    local dList = vlist(d, 10); pad(d, 14, 14, 14, 14)
    lbl(d, "Exit Edit Mode", 14, C.WHITE, true, 0)
    lbl(d, "Save your layout or discard all changes.", 11, C.DIM, false, 1)
    local row = makeDialogButtons(d, 2)
    local discardOpt = btn(row, "Discard",     C.BG_LIGHT,   C.DIM,    38, 1)
    local saveOpt    = btn(row, "Save Layout", C.ACCENT_DIM, C.ACCENT, 38, 2)
    stroke(saveOpt, C.ACCENT, 0.45, 1)
    fitHeight(d, dList, 28)

    discardOpt.Activated:Connect(function()
        closeDialog(); showDiscardConfirm(showExitDialog)
    end)

    saveOpt.Activated:Connect(function()
        local elemData = {}
        for elem in pairs(highlightMap) do
            if elem and elem.Parent then
                elemData[elem.Name] = {
                    sXS = elem.Size.X.Scale,     sXO = elem.Size.X.Offset,
                    sYS = elem.Size.Y.Scale,     sYO = elem.Size.Y.Offset,
                    pXS = elem.Position.X.Scale, pXO = elem.Position.X.Offset,
                    pYS = elem.Position.Y.Scale, pYO = elem.Position.Y.Offset,
                    trans = elem.BackgroundTransparency,
                }
            end
        end
        closeDialog(); showSaveNameDialog(elemData)
    end)
end

-- ============================================================
--  ENTER EDIT MODE
-- ============================================================

local function enterEditMode()
    editMode = true
    MainMenu.Visible = false; menuOpen = false
    destroyEditPanel(); closeDotMenu()
    highlightAll()

    local xb = Instance.new("Frame")
    xb.Name = "ExitEditBtn"; xb.Size = UDim2.fromOffset(54, 54)
    xb.Position = UDim2.new(0.5, -27, 0, 18)
    xb.BackgroundColor3 = C.RED_DIM; xb.ZIndex = 30
    corner(xb, 27); stroke(xb, C.RED, 0.38, 1.5)
    xb.Parent = Root; ExitBtn = xb

    local xIcon = Instance.new("TextLabel")
    xIcon.Text = "✕"; xIcon.TextSize = 22; xIcon.Font = Enum.Font.GothamBold
    xIcon.TextColor3 = C.RED; xIcon.BackgroundTransparency = 1
    xIcon.Size = UDim2.fromScale(1, 1); xIcon.ZIndex = 31
    xIcon.TextXAlignment = Enum.TextXAlignment.Center; xIcon.Parent = xb

    makeDraggable(xb, function()
        showExitDialog()
    end)
end

EditLayoutBtn.Activated:Connect(enterEditMode)

-- ============================================================
--  CLOSE DOT MENU ON TAP ELSEWHERE
-- ============================================================

Root.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        task.defer(function()
            if activeDotMenu then
                -- Only close if the tap wasn't ON the dot menu
                local abs = activeDotMenu.AbsolutePosition
                local sz  = activeDotMenu.AbsoluteSize
                local px, py = input.Position.X, input.Position.Y
                if px < abs.X or px > abs.X + sz.X or py < abs.Y or py > abs.Y + sz.Y then
                    closeDotMenu()
                end
            end
        end)
    end
end)

-- ============================================================
--  INIT
-- ============================================================

renderLayouts()
refreshMenuHeight()
print("[UILayoutEditor v2] Loaded — Place ID: " .. PLACE_ID)
