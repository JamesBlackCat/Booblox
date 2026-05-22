-- ============================================================
--  UI Layout Editor — Roblox Exploit Script
--  Mobile-optimized | Drag & edit any ScreenGui element
-- ============================================================

local Players         = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local HttpService     = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
--  CONSTANTS
-- ============================================================

local PLACE_ID   = tostring(game.PlaceId)
local GAME_URL   = "roblox.com/games/" .. PLACE_ID
local SAVE_FILE  = "UILayoutEditor_Layouts.json"

local C = {
    ACCENT     = Color3.fromRGB(0,   212, 255),
    ACCENT_DIM = Color3.fromRGB(0,    80, 100),
    BG_DARK    = Color3.fromRGB(10,   10,  20),
    BG_MID     = Color3.fromRGB(18,   18,  32),
    BG_LIGHT   = Color3.fromRGB(28,   28,  46),
    WHITE      = Color3.fromRGB(255, 255, 255),
    DIM        = Color3.fromRGB(140, 140, 165),
    RED        = Color3.fromRGB(239,  68,  68),
    RED_DIM    = Color3.fromRGB( 50,  10,  10),
    WARN       = Color3.fromRGB(250, 170,   0),
}

-- ============================================================
--  STATE
-- ============================================================

local editMode       = false
local selectedElem   = nil
local highlightMap   = {}   -- elem -> UIStroke
local originalStates = {}   -- elem -> {size, position, transparency}
local undoStates     = {}   -- elem -> {size, position, transparency}
local layouts        = {}

-- ============================================================
--  PERSISTENCE
-- ============================================================

local function loadLayouts()
    if readfile then
        local ok, raw = pcall(readfile, SAVE_FILE)
        if ok and raw and raw ~= "" then
            local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok2 and type(parsed) == "table" then
                layouts = parsed
            end
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
--  GUI HELPERS
-- ============================================================

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = parent
    return c
end

local function padding(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 10)
    p.PaddingBottom = UDim.new(0, b or t or 10)
    p.PaddingLeft   = UDim.new(0, l or t or 10)
    p.PaddingRight  = UDim.new(0, r or l or t or 10)
    p.Parent = parent
    return p
end

local function stroke(parent, color, alpha, thick)
    local s = Instance.new("UIStroke")
    s.Color        = color or C.WHITE
    s.Transparency = alpha or 0.75
    s.Thickness    = thick or 1
    s.Parent       = parent
    return s
end

local function listLayout(parent, pad, align)
    local l = Instance.new("UIListLayout")
    l.Padding         = UDim.new(0, pad or 8)
    l.SortOrder       = Enum.SortOrder.LayoutOrder
    l.FillDirection   = Enum.FillDirection.Vertical
    l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
    l.Parent          = parent
    return l
end

local function gridLayout(parent, cellW, cellH, padX, padY)
    local g = Instance.new("UIGridLayout")
    g.CellSize    = cellW
    g.CellPadding = UDim2.new(0, padX or 6, 0, padY or 6)
    g.SortOrder   = Enum.SortOrder.LayoutOrder
    g.Parent      = parent
    return g
end

local function separator(parent, order)
    local f = Instance.new("Frame")
    f.Size                 = UDim2.new(1, 0, 0, 1)
    f.BackgroundColor3     = C.WHITE
    f.BackgroundTransparency = 0.85
    f.BorderSizePixel      = 0
    f.LayoutOrder          = order or 99
    f.Parent               = parent
    return f
end

local function label(parent, text, size, color, bold, order)
    local l = Instance.new("TextLabel")
    l.Text             = text
    l.TextSize         = size or 13
    l.TextColor3       = color or C.WHITE
    l.Font             = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.BackgroundTransparency = 1
    l.Size             = UDim2.new(1, 0, 0, (size or 13) + 6)
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.LayoutOrder      = order or 0
    l.Parent           = parent
    return l
end

local function button(parent, text, bg, fg, h, order)
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
    b.Parent = parent
    return b
end

-- Auto-resize a Frame to fit its UIListLayout content
local function autosize(frame, layoutInst, extraH, minW)
    task.defer(function()
        frame.Size = UDim2.new(
            0, minW or frame.Size.X.Offset,
            0, layoutInst.AbsoluteContentSize.Y + (extraH or 24)
        )
    end)
end

-- ============================================================
--  DRAGGABLE
-- ============================================================

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging    = false
    local dragStart   = Vector3.new()
    local startPos    = UDim2.new()
    local moved       = false
    local THRESHOLD   = 6

    local function getXY(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local t = input.Position
            return t.X, t.Y
        end
        return input.Position.X, input.Position.Y
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging  = true
        moved     = false
        dragStart = input.Position
        startPos  = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end)

    local lastInput
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
            lastInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input ~= lastInput then return end
        local ix, iy = getXY(input)
        local dx = ix - dragStart.X
        local dy = iy - dragStart.Y
        if math.abs(dx) > THRESHOLD or math.abs(dy) > THRESHOLD then
            moved = true
        end
        if not moved then return end
        local vp = workspace.CurrentCamera.ViewportSize
        local fw = frame.AbsoluteSize.X
        local fh = frame.AbsoluteSize.Y
        local nx = math.clamp(startPos.X.Offset + dx, 0, vp.X - fw)
        local ny = math.clamp(startPos.Y.Offset + dy, 0, vp.Y - fh)
        frame.Position = UDim2.fromOffset(nx, ny)
    end)

    -- Return a function that tells callers whether the last press was a drag
    return function() return moved end
end

-- ============================================================
--  ROOT SCREENGUI
-- ============================================================

local existing = PlayerGui:FindFirstChild("UILayoutEditor")
if existing then existing:Destroy() end

local Root = Instance.new("ScreenGui")
Root.Name            = "UILayoutEditor"
Root.ResetOnSpawn    = false
Root.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
Root.IgnoreGuiInset  = true
Root.DisplayOrder    = 999
Root.Parent          = PlayerGui

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
    padding(f, 10, 10, 14, 14)
    f.Parent = Root

    local t1 = Instance.new("TextLabel")
    t1.Text              = "UI Layout Editor  —  Loaded"
    t1.TextSize          = 13
    t1.Font              = Enum.Font.GothamBold
    t1.TextColor3        = C.ACCENT
    t1.BackgroundTransparency = 1
    t1.Size              = UDim2.new(1, 0, 0, 18)
    t1.TextXAlignment    = Enum.TextXAlignment.Left
    t1.ZIndex            = 201
    t1.Parent            = f

    local t2 = Instance.new("TextLabel")
    t2.Text              = "Game ID: " .. PLACE_ID .. "  |  " .. GAME_URL
    t2.TextSize          = 10
    t2.Font              = Enum.Font.Gotham
    t2.TextColor3        = C.DIM
    t2.BackgroundTransparency = 1
    t2.Size              = UDim2.new(1, 0, 0, 14)
    t2.Position          = UDim2.fromOffset(0, 22)
    t2.TextXAlignment    = Enum.TextXAlignment.Left
    t2.TextTruncate      = Enum.TextTruncate.AtEnd
    t2.ZIndex            = 201
    t2.Parent            = f

    task.delay(3.5, function()
        local tw = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
        TweenService:Create(f,  tw, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(t1, tw, { TextTransparency = 1 }):Play()
        TweenService:Create(t2, tw, { TextTransparency = 1 }):Play()
        task.wait(0.55)
        f:Destroy()
    end)
end

-- ============================================================
--  MAIN TOGGLE BUTTON
-- ============================================================

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name             = "ToggleBtn"
ToggleBtn.Size             = UDim2.fromOffset(54, 54)
ToggleBtn.Position         = UDim2.new(0, 16, 0.5, -27)
ToggleBtn.BackgroundColor3 = C.BG_MID
ToggleBtn.Text             = "☰"
ToggleBtn.TextSize         = 24
ToggleBtn.TextColor3       = C.WHITE
ToggleBtn.Font             = Enum.Font.GothamBold
ToggleBtn.AutoButtonColor  = false
ToggleBtn.ZIndex           = 10
corner(ToggleBtn, 27)
stroke(ToggleBtn, C.WHITE, 0.78, 1)
ToggleBtn.Parent = Root

local toggleWasDrag = makeDraggable(ToggleBtn)

-- ============================================================
--  MAIN MENU
-- ============================================================

local MainMenu = Instance.new("Frame")
MainMenu.Name             = "MainMenu"
MainMenu.Size             = UDim2.fromOffset(240, 10)
MainMenu.Position         = UDim2.fromOffset(80, 200)
MainMenu.BackgroundColor3 = C.BG_DARK
MainMenu.BackgroundTransparency = 0.04
MainMenu.Visible          = false
MainMenu.ZIndex           = 20
corner(MainMenu, 14)
stroke(MainMenu, C.WHITE, 0.8, 1)
MainMenu.Parent = Root
makeDraggable(MainMenu)

local menuList = listLayout(MainMenu, 8)
padding(MainMenu, 12, 12, 12, 12)

-- Header
local menuHeader = label(MainMenu, "UI LAYOUT EDITOR", 10, C.ACCENT, true, 0)
menuHeader.LetterSpacing = 2
menuHeader.Size = UDim2.new(1, 0, 0, 16)

separator(MainMenu, 1)

-- "BUTTON LAYOUTS" sub-header
local layoutsHeader = label(MainMenu, "BUTTON LAYOUTS", 9, C.DIM, true, 2)
layoutsHeader.LetterSpacing = 2
layoutsHeader.Size = UDim2.new(1, 0, 0, 15)

-- Layouts scroll area
local LayoutsScroll = Instance.new("ScrollingFrame")
LayoutsScroll.Size                  = UDim2.new(1, 0, 0, 0)
LayoutsScroll.BackgroundTransparency = 1
LayoutsScroll.BorderSizePixel       = 0
LayoutsScroll.ScrollBarThickness    = 2
LayoutsScroll.ScrollBarImageColor3  = C.ACCENT
LayoutsScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
LayoutsScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
LayoutsScroll.ClipsDescendants      = true
LayoutsScroll.LayoutOrder           = 3
LayoutsScroll.Parent                = MainMenu

listLayout(LayoutsScroll, 4)

separator(MainMenu, 4)

-- Edit Layout button
local EditLayoutBtn = button(MainMenu, "✎   Edit Layout", C.BG_LIGHT, C.ACCENT, 42, 5)
stroke(EditLayoutBtn, C.ACCENT, 0.55, 1.2)

local function refreshMenuSize()
    task.defer(function()
        MainMenu.Size = UDim2.fromOffset(240, menuList.AbsoluteContentSize.Y + 24)
    end)
end

-- ============================================================
--  THREE-DOT CONTEXT MENU
-- ============================================================

local activeDotMenu = nil

local function closeDotMenu()
    if activeDotMenu and activeDotMenu.Parent then
        activeDotMenu:Destroy()
    end
    activeDotMenu = nil
end

-- ============================================================
--  RENDER LAYOUTS LIST
-- ============================================================

local function renderLayouts()
    -- Clear old items
    for _, c in ipairs(LayoutsScroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end

    if #layouts == 0 then
        local empty = Instance.new("TextLabel")
        empty.Text             = "No layouts saved yet"
        empty.TextSize         = 11
        empty.Font             = Enum.Font.Gotham
        empty.TextColor3       = C.DIM
        empty.BackgroundTransparency = 1
        empty.Size             = UDim2.new(1, 0, 0, 28)
        empty.TextXAlignment   = Enum.TextXAlignment.Center
        empty.Parent           = LayoutsScroll
        LayoutsScroll.Size = UDim2.new(1, 0, 0, 28)
        refreshMenuSize()
        return
    end

    for i, layout in ipairs(layouts) do
        local compatible = layout.placeId == PLACE_ID

        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3 = C.BG_LIGHT
        row.BorderSizePixel  = 0
        row.LayoutOrder      = i
        corner(row, 8)
        row.Parent = LayoutsScroll

        -- Name button
        local nameLbl = Instance.new("TextButton")
        nameLbl.Text           = layout.name .. (not compatible and " ⚠" or "")
        nameLbl.TextSize       = 12
        nameLbl.Font           = Enum.Font.Gotham
        nameLbl.TextColor3     = compatible and C.WHITE or C.WARN
        nameLbl.BackgroundTransparency = 1
        nameLbl.Size           = UDim2.new(1, -38, 1, 0)
        nameLbl.Position       = UDim2.fromOffset(10, 0)
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate   = Enum.TextTruncate.AtEnd
        nameLbl.ZIndex         = 21
        nameLbl.Parent         = row

        -- Load layout on tap
        nameLbl.Activated:Connect(function()
            if not compatible then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title    = "Incompatible Layout",
                        Text     = "Saved for game ID: " .. (layout.placeId or "?"),
                        Duration = 3,
                    })
                end)
                return
            end
            for elemName, data in pairs(layout.elements) do
                local elem = PlayerGui:FindFirstChild(elemName, true)
                if elem and elem:IsA("GuiObject") then
                    elem.Size = UDim2.new(data.sXS, data.sXO, data.sYS, data.sYO)
                    elem.Position = UDim2.new(data.pXS, data.pXO, data.pYS, data.pYO)
                    elem.BackgroundTransparency = data.trans or 0
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
        dotBtn.Size            = UDim2.fromOffset(36, 38)
        dotBtn.Position        = UDim2.new(1, -36, 0, 0)
        dotBtn.ZIndex          = 21
        dotBtn.Parent          = row

        dotBtn.Activated:Connect(function()
            closeDotMenu()

            local dm = Instance.new("Frame")
            dm.Size             = UDim2.fromOffset(130, 80)
            dm.BackgroundColor3 = Color3.fromRGB(16, 16, 28)
            dm.BorderSizePixel  = 0
            dm.ZIndex           = 60
            corner(dm, 10)
            stroke(dm, C.WHITE, 0.78, 1)
            dm.Parent = Root
            activeDotMenu = dm

            -- Position near the dot button
            local abs = dotBtn.AbsolutePosition
            local vp  = workspace.CurrentCamera.ViewportSize
            local px  = math.clamp(abs.X - 100, 4, vp.X - 138)
            local py  = math.clamp(abs.Y + 34, 4, vp.Y - 86)
            dm.Position = UDim2.fromOffset(px, py)

            listLayout(dm, 0)

            local function dmOption(text, fg, order)
                local opt = Instance.new("TextButton")
                opt.Text            = text
                opt.TextSize        = 12
                opt.Font            = Enum.Font.Gotham
                opt.TextColor3      = fg
                opt.BackgroundTransparency = 1
                opt.Size            = UDim2.new(1, 0, 0, 40)
                opt.AutoButtonColor = false
                opt.LayoutOrder     = order
                opt.ZIndex          = 61
                opt.Parent          = dm
                -- Hover tint
                opt.MouseEnter:Connect(function()
                    opt.BackgroundTransparency = 0.88
                    opt.BackgroundColor3 = C.WHITE
                end)
                opt.MouseLeave:Connect(function()
                    opt.BackgroundTransparency = 1
                end)
                return opt
            end

            local renameOpt = dmOption("  Rename", C.WHITE, 1)
            local deleteOpt = dmOption("  Delete", C.RED,   2)

            -- Rename: swap label for TextBox in the row
            renameOpt.Activated:Connect(function()
                closeDotMenu()
                nameLbl.Visible = false

                local box = Instance.new("TextBox")
                box.Text             = layout.name
                box.TextSize         = 12
                box.Font             = Enum.Font.Gotham
                box.TextColor3       = C.WHITE
                box.BackgroundColor3 = C.BG_MID
                box.Size             = UDim2.new(1, -48, 1, -8)
                box.Position         = UDim2.new(0, 8, 0, 4)
                box.ClearTextOnFocus = false
                box.ZIndex           = 25
                corner(box, 6)
                stroke(box, C.ACCENT, 0.45, 1)
                box.Parent = row

                local function commit()
                    local v = box.Text ~= "" and box.Text or layout.name
                    layouts[i].name = v
                    saveLayouts()
                    box:Destroy()
                    nameLbl.Visible = true
                    nameLbl.Text    = v .. (not compatible and " ⚠" or "")
                end

                box.FocusLost:Connect(commit)
                task.defer(function() pcall(function() box:CaptureFocus() end) end)
            end)

            deleteOpt.Activated:Connect(function()
                closeDotMenu()
                table.remove(layouts, i)
                saveLayouts()
                renderLayouts()
                refreshMenuSize()
            end)
        end)
    end

    -- Height: max 5 visible rows
    local rowH   = 38
    local gapH   = 4
    local visibleH = math.min(#layouts, 5) * (rowH + gapH)
    LayoutsScroll.Size = UDim2.new(1, 0, 0, visibleH)
    refreshMenuSize()
end

-- ============================================================
--  TOGGLE BUTTON LOGIC
-- ============================================================

local menuOpen = false

ToggleBtn.Activated:Connect(function()
    if toggleWasDrag() then return end
    if editMode then return end
    menuOpen = not menuOpen
    MainMenu.Visible = menuOpen
    if menuOpen then
        -- Snap menu next to toggle button
        local abs = ToggleBtn.AbsolutePosition
        local vp  = workspace.CurrentCamera.ViewportSize
        local mx  = math.clamp(abs.X + 60, 4, vp.X - 248)
        local my  = math.clamp(abs.Y, 4, vp.Y - MainMenu.AbsoluteSize.Y - 4)
        MainMenu.Position = UDim2.fromOffset(mx, my)
        renderLayouts()
    end
end)

-- ============================================================
--  SLIDER HELPER
-- ============================================================

local function makeSlider(parent, order, labelText, initVal, minVal, maxVal, fmt, onChange)
    local wrap = Instance.new("Frame")
    wrap.Size             = UDim2.new(1, 0, 0, 54)
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder      = order
    wrap.Parent           = parent

    local headerRow = Instance.new("Frame")
    headerRow.Size             = UDim2.new(1, 0, 0, 16)
    headerRow.BackgroundTransparency = 1
    headerRow.Parent           = wrap

    local lbl = Instance.new("TextLabel")
    lbl.Text           = labelText
    lbl.TextSize       = 9
    lbl.Font           = Enum.Font.GothamBold
    lbl.TextColor3     = C.DIM
    lbl.BackgroundTransparency = 1
    lbl.Size           = UDim2.new(0.6, 0, 1, 0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LetterSpacing  = 1
    lbl.Parent         = headerRow

    local valLbl = Instance.new("TextLabel")
    valLbl.Text          = string.format(fmt, initVal)
    valLbl.TextSize      = 9
    valLbl.Font          = Enum.Font.GothamBold
    valLbl.TextColor3    = C.ACCENT
    valLbl.BackgroundTransparency = 1
    valLbl.Size          = UDim2.new(0.4, 0, 1, 0)
    valLbl.Position      = UDim2.new(0.6, 0, 0, 0)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent         = headerRow

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, 0, 0, 28)
    track.Position         = UDim2.fromOffset(0, 20)
    track.BackgroundColor3 = C.BG_LIGHT
    track.BorderSizePixel  = 0
    corner(track, 8)
    track.Parent = wrap

    local fill = Instance.new("Frame")
    local initRel = (initVal - minVal) / (maxVal - minVal)
    fill.Size             = UDim2.new(math.clamp(initRel, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = C.ACCENT
    fill.BorderSizePixel  = 0
    corner(fill, 8)
    fill.Parent = track

    local function applyX(absX)
        local rel = math.clamp((absX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        fill.Size  = UDim2.new(rel, 0, 1, 0)
        local val  = minVal + rel * (maxVal - minVal)
        valLbl.Text = string.format(fmt, val)
        onChange(val)
    end

    local held = false
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            held = true
            applyX(inp.Position.X)
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then held = false end
            end)
        end
    end)
    track.InputChanged:Connect(function(inp)
        if held and (inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseMovement) then
            applyX(inp.Position.X)
        end
    end)

    return wrap, valLbl
end

-- ============================================================
--  ELEMENT EDIT PANEL
-- ============================================================

local EditPanel = nil

local function destroyEditPanel()
    if EditPanel and EditPanel.Parent then
        EditPanel:Destroy()
    end
    EditPanel = nil
end

local function showEditPanel(elem)
    destroyEditPanel()
    selectedElem = elem

    -- Save undo snapshot
    undoStates[elem] = {
        size         = elem.Size,
        position     = elem.Position,
        transparency = elem.BackgroundTransparency,
    }

    local panel = Instance.new("Frame")
    panel.Size             = UDim2.fromOffset(270, 10)
    panel.Position         = UDim2.new(0.5, -135, 0.5, -120)
    panel.BackgroundColor3 = C.BG_DARK
    panel.BackgroundTransparency = 0.04
    panel.ZIndex           = 40
    corner(panel, 14)
    stroke(panel, C.ACCENT, 0.45, 1.5)
    panel.Parent = Root
    EditPanel    = panel

    makeDraggable(panel)

    local pList = listLayout(panel, 8)
    padding(panel, 12, 14, 12, 12)

    -- Title row
    local titleRow = Instance.new("Frame")
    titleRow.Size             = UDim2.new(1, 0, 0, 22)
    titleRow.BackgroundTransparency = 1
    titleRow.LayoutOrder      = 0
    titleRow.Parent           = panel

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Text          = elem.Name
    titleLbl.TextSize      = 14
    titleLbl.Font          = Enum.Font.GothamBold
    titleLbl.TextColor3    = C.WHITE
    titleLbl.BackgroundTransparency = 1
    titleLbl.Size          = UDim2.new(1, 0, 1, 0)
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent        = titleRow

    separator(panel, 1)

    -- Size slider (scale 0.5 -> 2.0, display as %)
    makeSlider(panel, 2, "SIZE", elem.Size.X.Scale, 0.5, 2.0, "%.0f%%",
        function(val)
            elem.Size = UDim2.new(val, elem.Size.X.Offset, val, elem.Size.Y.Offset)
        end
    )

    -- Transparency slider
    makeSlider(panel, 3, "TRANSPARENCY", elem.BackgroundTransparency, 0, 1, "%.0f%%",
        function(val)
            elem.BackgroundTransparency = val
        end
    )

    separator(panel, 4)

    -- Action buttons (2x2 grid)
    local btnGrid = Instance.new("Frame")
    btnGrid.Size             = UDim2.new(1, 0, 0, 84)
    btnGrid.BackgroundTransparency = 1
    btnGrid.LayoutOrder      = 5
    btnGrid.Parent           = panel

    gridLayout(btnGrid, UDim2.new(0.5, -4, 0, 36), nil, 8, 8)

    local function panelBtn(text, bg, fg, order)
        local b = Instance.new("TextButton")
        b.Text            = text
        b.TextSize        = 12
        b.Font            = Enum.Font.GothamBold
        b.TextColor3      = fg
        b.BackgroundColor3 = bg
        b.AutoButtonColor = false
        b.LayoutOrder     = order
        b.ZIndex          = 41
        corner(b, 9)
        b.Parent = btnGrid
        return b
    end

    local cancelBtn = panelBtn("Cancel", C.BG_LIGHT, C.DIM, 1)
    local doneBtn   = panelBtn("Done",   C.ACCENT_DIM, C.ACCENT, 2)
    local undoBtn   = panelBtn("Undo",   C.BG_LIGHT, C.DIM, 3)
    local resetBtn  = panelBtn("Default", C.BG_LIGHT, C.DIM, 4)

    stroke(doneBtn, C.ACCENT, 0.5, 1)

    cancelBtn.Activated:Connect(function()
        -- Revert to snapshot before this edit session
        local snap = undoStates[elem]
        if snap then
            elem.Size                = snap.size
            elem.Position            = snap.position
            elem.BackgroundTransparency = snap.transparency
        end
        destroyEditPanel()
        selectedElem = nil
    end)

    doneBtn.Activated:Connect(function()
        destroyEditPanel()
        selectedElem = nil
    end)

    undoBtn.Activated:Connect(function()
        local snap = undoStates[elem]
        if snap then
            elem.Size                = snap.size
            elem.Position            = snap.position
            elem.BackgroundTransparency = snap.transparency
        end
    end)

    resetBtn.Activated:Connect(function()
        local orig = originalStates[elem]
        if orig then
            elem.Size                = orig.size
            elem.Position            = orig.position
            elem.BackgroundTransparency = orig.transparency
        end
    end)

    autosize(panel, pList, 26, 270)
end

-- ============================================================
--  HIGHLIGHT EDITABLE ELEMENTS
-- ============================================================

local function clearHighlights()
    for elem, s in pairs(highlightMap) do
        if s and s.Parent then s:Destroy() end
    end
    highlightMap   = {}
    originalStates = {}
end

local function highlightAll()
    local function scan(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("GuiObject") and not obj:IsDescendantOf(Root) then
                originalStates[obj] = {
                    size         = obj.Size,
                    position     = obj.Position,
                    transparency = obj.BackgroundTransparency,
                }
                local s = Instance.new("UIStroke")
                s.Color        = C.ACCENT
                s.Transparency = 0.4
                s.Thickness    = 2
                s.Parent       = obj
                highlightMap[obj] = s

                -- Make tappable for edit
                obj.InputBegan:Connect(function(input)
                    if not editMode then return end
                    if input.UserInputType ~= Enum.UserInputType.Touch
                    and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    showEditPanel(obj)
                end)

                scan(obj)
            end
        end
    end

    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui ~= Root and gui:IsA("ScreenGui") then
            scan(gui)
        end
    end
end

-- ============================================================
--  EXIT BUTTON (red X, shown during edit mode)
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

local function makeDialog(w, h)
    closeDialog()
    local d = Instance.new("Frame")
    d.Size             = UDim2.fromOffset(w or 268, h or 10)
    d.Position         = UDim2.new(0.5, -((w or 268) / 2), 0.5, -80)
    d.BackgroundColor3 = C.BG_DARK
    d.BackgroundTransparency = 0.04
    d.ZIndex           = 80
    corner(d, 14)
    ActiveDialog = d
    d.Parent = Root
    return d
end

-- Discard-confirmation dialog
local function showDiscardConfirm(onBack)
    local d = makeDialog(268)
    stroke(d, C.RED, 0.4, 1.5)

    local dList = listLayout(d, 10)
    padding(d, 14, 14, 14, 14)

    label(d, "⚠   Are you sure?", 14, C.RED, true, 0)
    label(d, "All unsaved edits will be permanently lost.", 11, C.DIM, false, 1)

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 38)
    row.BackgroundTransparency = 1
    row.LayoutOrder      = 2
    row.Parent           = d

    gridLayout(row, UDim2.new(0.5, -4, 1, 0), nil, 8)

    local backBtn    = button(row, "Go Back",  C.BG_LIGHT, C.DIM,   38, 1)
    local discardBtn = button(row, "Discard",  C.RED_DIM,  C.RED,   38, 2)
    stroke(discardBtn, C.RED, 0.5, 1)

    autosize(d, dList, 28, 268)

    backBtn.Activated:Connect(function()
        closeDialog()
        if onBack then onBack() end
    end)

    discardBtn.Activated:Connect(function()
        -- Revert everything
        for elem, orig in pairs(originalStates) do
            if elem and elem.Parent then
                elem.Size                = orig.size
                elem.Position            = orig.position
                elem.BackgroundTransparency = orig.transparency
            end
        end
        closeDialog()
        clearHighlights()
        destroyEditPanel()
        destroyExitBtn()
        undoStates = {}
        editMode = false
        selectedElem = nil
    end)
end

-- Save-name dialog (shown when player taps "Save Layout")
local function showSaveNameDialog(elementsData)
    local d = makeDialog(268)
    stroke(d, C.ACCENT, 0.45, 1.5)

    local dList = listLayout(d, 10)
    padding(d, 14, 14, 14, 14)

    label(d, "Name Your Layout", 14, C.WHITE, true, 0)
    label(d, "Game ID " .. PLACE_ID .. " will be saved with this layout.", 10, C.DIM, false, 1)

    local box = Instance.new("TextBox")
    box.PlaceholderText  = "Layout " .. (#layouts + 1)
    box.Text             = ""
    box.TextSize         = 13
    box.Font             = Enum.Font.Gotham
    box.TextColor3       = C.WHITE
    box.PlaceholderColor3 = C.DIM
    box.BackgroundColor3 = C.BG_LIGHT
    box.Size             = UDim2.new(1, 0, 0, 40)
    box.LayoutOrder      = 2
    box.ClearTextOnFocus = false
    box.ZIndex           = 82
    corner(box, 9)
    stroke(box, C.ACCENT, 0.5, 1)
    box.Parent = d

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 38)
    row.BackgroundTransparency = 1
    row.LayoutOrder      = 3
    row.Parent           = d

    gridLayout(row, UDim2.new(0.5, -4, 1, 0), nil, 8)

    local cancelBtn2 = button(row, "Cancel",      C.BG_LIGHT,   C.DIM,   38, 1)
    local saveBtn2   = button(row, "Save",         C.ACCENT_DIM, C.ACCENT, 38, 2)
    stroke(saveBtn2, C.ACCENT, 0.5, 1)

    autosize(d, dList, 28, 268)

    task.defer(function() pcall(function() box:CaptureFocus() end) end)

    local function doSave()
        local name = box.Text ~= "" and box.Text or ("Layout " .. (#layouts + 1))
        table.insert(layouts, {
            name      = name,
            placeId   = PLACE_ID,
            gameUrl   = GAME_URL,
            savedAt   = os.time(),
            elements  = elementsData,
        })
        saveLayouts()
        closeDialog()
        clearHighlights()
        destroyEditPanel()
        destroyExitBtn()
        undoStates = {}
        editMode = false
        selectedElem = nil
        -- Open menu on layouts section
        renderLayouts()
        MainMenu.Visible = true
        menuOpen = true
        local abs = ToggleBtn.AbsolutePosition
        local vp  = workspace.CurrentCamera.ViewportSize
        MainMenu.Position = UDim2.fromOffset(
            math.clamp(abs.X + 60, 4, vp.X - 248),
            math.clamp(abs.Y, 4, vp.Y - 300)
        )
    end

    cancelBtn2.Activated:Connect(function()
        closeDialog()
        clearHighlights()
        destroyEditPanel()
        destroyExitBtn()
        undoStates = {}
        editMode = false
        selectedElem = nil
    end)

    saveBtn2.Activated:Connect(doSave)
    box.FocusLost:Connect(function(enter) if enter then doSave() end end)
end

-- Exit-edit-mode dialog (Save or Cancel)
local function showExitDialog()
    local d = makeDialog(268)
    stroke(d, C.WHITE, 0.78, 1)

    local dList = listLayout(d, 10)
    padding(d, 14, 14, 14, 14)

    label(d, "Exit Edit Mode", 14, C.WHITE, true, 0)
    label(d, "Save your layout, or discard all changes.", 11, C.DIM, false, 1)

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 38)
    row.BackgroundTransparency = 1
    row.LayoutOrder      = 2
    row.Parent           = d

    gridLayout(row, UDim2.new(0.5, -4, 1, 0), nil, 8)

    local discardOpt = button(row, "Discard",      C.BG_LIGHT,   C.DIM,   38, 1)
    local saveOpt    = button(row, "Save Layout",  C.ACCENT_DIM, C.ACCENT, 38, 2)
    stroke(saveOpt, C.ACCENT, 0.5, 1)

    autosize(d, dList, 28, 268)

    discardOpt.Activated:Connect(function()
        closeDialog()
        showDiscardConfirm(showExitDialog)
    end)

    saveOpt.Activated:Connect(function()
        -- Collect all current element states
        local elemData = {}
        for elem in pairs(highlightMap) do
            if elem and elem.Parent then
                elemData[elem.Name] = {
                    sXS  = elem.Size.X.Scale,
                    sXO  = elem.Size.X.Offset,
                    sYS  = elem.Size.Y.Scale,
                    sYO  = elem.Size.Y.Offset,
                    pXS  = elem.Position.X.Scale,
                    pXO  = elem.Position.X.Offset,
                    pYS  = elem.Position.Y.Scale,
                    pYO  = elem.Position.Y.Offset,
                    trans = elem.BackgroundTransparency,
                }
            end
        end
        closeDialog()
        showSaveNameDialog(elemData)
    end)
end

-- ============================================================
--  ENTER EDIT MODE
-- ============================================================

local function enterEditMode()
    editMode = true
    MainMenu.Visible = false
    menuOpen = false
    destroyEditPanel()
    closeDotMenu()
    highlightAll()

    -- Red X button
    local xb = Instance.new("TextButton")
    xb.Name             = "ExitEditBtn"
    xb.Size             = UDim2.fromOffset(54, 54)
    xb.Position         = UDim2.new(0.5, -27, 0, 18)
    xb.BackgroundColor3 = C.RED_DIM
    xb.Text             = "✕"
    xb.TextSize         = 22
    xb.TextColor3       = C.RED
    xb.Font             = Enum.Font.GothamBold
    xb.AutoButtonColor  = false
    xb.ZIndex           = 30
    corner(xb, 27)
    stroke(xb, C.RED, 0.4, 1.5)
    xb.Parent = Root
    ExitBtn   = xb

    local xWasDrag = makeDraggable(xb)

    xb.Activated:Connect(function()
        if xWasDrag() then return end
        showExitDialog()
    end)
end

EditLayoutBtn.Activated:Connect(enterEditMode)

-- ============================================================
--  DISMISS DOT MENUS ON TAP ELSEWHERE
-- ============================================================

Root.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if activeDotMenu and not input.Position:FuzzyEq(Vector3.new(), 0) then
            task.defer(closeDotMenu)
        end
    end
end)

-- ============================================================
--  INITIAL STATE
-- ============================================================

renderLayouts()
refreshMenuSize()

print("[UILayoutEditor] Loaded — Place ID: " .. PLACE_ID)
