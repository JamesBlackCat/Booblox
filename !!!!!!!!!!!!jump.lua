-- ============================================================
--  Mobile Layout Editor  v2
--  - Tap any game UI element to SELECT it (shows highlight)
--  - DRAG the selected element to reposition it
--  - Use the panel to resize and set transparency
--  - Cancel / Done / Undo / Reset all work correctly
-- ============================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
--  GAME VERIFICATION
-- ============================================================
local GAME_PLACE_ID = game.PlaceId
local GAME_LINK     = "https://www.roblox.com/games/" .. tostring(GAME_PLACE_ID)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

Rayfield:Notify({
    Title   = "Layout Editor – Loaded",
    Content = "Place ID: " .. tostring(GAME_PLACE_ID),
    Duration = 5,
    Image    = 4483362458,
})

-- ============================================================
--  PERSISTENT STORAGE
-- ============================================================
local SAVE_FILE = "MobileLayoutEditor_v2.json"

local layoutData = { placeId = GAME_PLACE_ID, gameLink = GAME_LINK, layouts = {} }

pcall(function()
    local raw  = readfile(SAVE_FILE)
    local data = HttpService:JSONDecode(raw)
    if data and data.placeId == GAME_PLACE_ID then
        layoutData = data
    end
end)

local function saveLayoutData()
    pcall(function()
        writefile(SAVE_FILE, HttpService:JSONEncode(layoutData))
    end)
end

-- ============================================================
--  ROOT GUI  (UserInputService passthrough so game elements
--             can still be tapped in edit mode)
-- ============================================================
local RootGui = Instance.new("ScreenGui")
RootGui.Name            = "MobileLayoutEditor"
RootGui.ResetOnSpawn    = false
RootGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
RootGui.IgnoreGuiInset  = true
RootGui.DisplayOrder    = 999
RootGui.Parent          = PlayerGui

-- ============================================================
--  GUI HELPERS
-- ============================================================
local function addCorner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 8)
    c.Parent = p
    return c
end

local function addStroke(p, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color     or Color3.fromRGB(70, 70, 90)
    s.Thickness = thickness or 1
    s.Parent    = p
    return s
end

local function mkFrame(parent, size, pos, bg, z)
    local f = Instance.new("Frame")
    f.Size             = size
    f.Position         = pos
    f.BackgroundColor3 = bg or Color3.fromRGB(18, 18, 26)
    f.BorderSizePixel  = 0
    f.ZIndex           = z or 10
    f.Parent           = parent
    addCorner(f)
    addStroke(f)
    return f
end

local function mkLabel(parent, text, size, pos, color, fs, z)
    local l = Instance.new("TextLabel")
    l.Size             = size
    l.Position         = pos
    l.BackgroundTransparency = 1
    l.TextColor3       = color or Color3.fromRGB(220, 220, 235)
    l.Text             = text
    l.Font             = Enum.Font.GothamBold
    l.TextSize         = fs or 13
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.TextWrapped      = true
    l.ZIndex           = z or 11
    l.Parent           = parent
    return l
end

local function mkButton(parent, text, size, pos, bg, z)
    local b = Instance.new("TextButton")
    b.Size             = size
    b.Position         = pos
    b.BackgroundColor3 = bg or Color3.fromRGB(30, 120, 230)
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Text             = text
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 13
    b.BorderSizePixel  = 0
    b.ZIndex           = z or 11
    b.Parent           = parent
    addCorner(b)
    return b
end

local function mkInput(parent, placeholder, startText, size, pos, z)
    local tb = Instance.new("TextBox")
    tb.Size                = size
    tb.Position            = pos
    tb.BackgroundColor3    = Color3.fromRGB(36, 36, 50)
    tb.TextColor3          = Color3.fromRGB(240, 240, 255)
    tb.PlaceholderColor3   = Color3.fromRGB(100, 100, 125)
    tb.PlaceholderText     = placeholder or ""
    tb.Text                = startText or ""
    tb.Font                = Enum.Font.Code
    tb.TextSize            = 13
    tb.BorderSizePixel     = 0
    tb.ClearTextOnFocus    = false
    tb.ZIndex              = z or 11
    tb.Parent              = parent
    addCorner(tb, UDim.new(0, 6))
    return tb
end

local function divider(parent, y, z)
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(0.88, 0, 0, 1)
    d.Position         = UDim2.new(0.06, 0, 0, y)
    d.BackgroundColor3 = Color3.fromRGB(50, 50, 68)
    d.BorderSizePixel  = 0
    d.ZIndex           = z or 11
    d.Parent           = parent
    return d
end

-- Make a frame draggable, optionally by a handle
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(inp)
        local t = inp.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(inp)
        local t = inp.UserInputType
        if dragging and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseMovement) then
            local d = inp.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- ============================================================
--  SELECTION HIGHLIGHT  (drawn over the tapped element)
-- ============================================================
local Highlight = Instance.new("Frame")
Highlight.Name             = "SelectionHighlight"
Highlight.BackgroundTransparency = 1
Highlight.BorderSizePixel  = 0
Highlight.ZIndex           = 500
Highlight.Visible          = false
Highlight.Parent           = RootGui

local hlStroke = Instance.new("UIStroke")
hlStroke.Color     = Color3.fromRGB(30, 180, 255)
hlStroke.Thickness = 2
hlStroke.LineJoinMode = Enum.LineJoinMode.Round
hlStroke.Parent    = Highlight

-- Resize handles shown at corners
local function syncHighlight(el)
    if not el or not el.Parent then Highlight.Visible = false; return end
    local ap = el.AbsolutePosition
    local as = el.AbsoluteSize
    Highlight.Position = UDim2.fromOffset(ap.X, ap.Y)
    Highlight.Size     = UDim2.fromOffset(as.X, as.Y)
    Highlight.Visible  = true
end

-- ============================================================
--  UNDO STACK  &  STATE
-- ============================================================
local State = {
    editMode  = false,
    selected  = nil,          -- current GuiObject being edited
    undoStack = {},           -- list of { element, size, position, transparency }
    origProps = {},           -- keyed by element: { size, position, transparency }
}

local function pushUndo(el)
    local trans = 0
    pcall(function() trans = el.BackgroundTransparency end)
    table.insert(State.undoStack, {
        element      = el,
        size         = el.Size,
        position     = el.Position,
        transparency = trans,
    })
end

local function popUndoFor(el)
    for i = #State.undoStack, 1, -1 do
        if State.undoStack[i].element == el then
            return table.remove(State.undoStack, i)
        end
    end
    return nil
end

-- ============================================================
--  TOGGLE BUTTON
-- ============================================================
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size             = UDim2.fromOffset(56, 56)
ToggleBtn.Position         = UDim2.new(0, 18, 0.5, -28)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(22, 115, 225)
ToggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
ToggleBtn.Text             = "☰"
ToggleBtn.Font             = Enum.Font.GothamBold
ToggleBtn.TextSize         = 24
ToggleBtn.BorderSizePixel  = 0
ToggleBtn.ZIndex           = 900
ToggleBtn.Parent           = RootGui
addCorner(ToggleBtn, UDim.new(1, 0))
addStroke(ToggleBtn, Color3.fromRGB(80, 170, 255), 2)
makeDraggable(ToggleBtn)

-- ============================================================
--  MAIN MENU
-- ============================================================
local MainMenu = mkFrame(RootGui,
    UDim2.fromOffset(230, 168),
    UDim2.new(0.5, -115, 0.5, -84),
    Color3.fromRGB(18, 18, 26), 100)
MainMenu.Visible = false

do
    local title = Instance.new("TextLabel")
    title.Size                  = UDim2.new(1, 0, 0, 40)
    title.Position              = UDim2.new(0, 0, 0, 4)
    title.BackgroundTransparency= 1
    title.Text                  = "Layout Editor"
    title.Font                  = Enum.Font.GothamBold
    title.TextSize              = 16
    title.TextColor3            = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment        = Enum.TextXAlignment.Center
    title.ZIndex                = 101
    title.Parent                = MainMenu
    divider(MainMenu, 44, 101)
end

local EditLayoutBtn   = mkButton(MainMenu, "EDIT LAYOUT",
    UDim2.new(0.84, 0, 0, 44), UDim2.new(0.08, 0, 0, 54),
    Color3.fromRGB(22, 115, 225), 101)

local LayoutBtnsBtn   = mkButton(MainMenu, "LAYOUT BUTTONS",
    UDim2.new(0.84, 0, 0, 44), UDim2.new(0.08, 0, 0, 106),
    Color3.fromRGB(44, 44, 60), 101)

makeDraggable(MainMenu)

local menuOpen = false
ToggleBtn.MouseButton1Click:Connect(function()
    if not State.editMode then
        menuOpen = not menuOpen
        MainMenu.Visible = menuOpen
    end
end)

-- ============================================================
--  EDIT MODE  –  X button & banner
-- ============================================================
local EditCloseBtn = Instance.new("TextButton")
EditCloseBtn.Size             = UDim2.fromOffset(46, 46)
EditCloseBtn.Position         = UDim2.new(1, -56, 0, 8)
EditCloseBtn.BackgroundColor3 = Color3.fromRGB(190, 36, 36)
EditCloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
EditCloseBtn.Text             = "✕"
EditCloseBtn.Font             = Enum.Font.GothamBold
EditCloseBtn.TextSize         = 18
EditCloseBtn.BorderSizePixel  = 0
EditCloseBtn.ZIndex           = 900
EditCloseBtn.Visible          = false
EditCloseBtn.Parent           = RootGui
addCorner(EditCloseBtn, UDim.new(1, 0))
addStroke(EditCloseBtn, Color3.fromRGB(255, 90, 90), 2)
makeDraggable(EditCloseBtn)

local EditBanner = mkFrame(RootGui,
    UDim2.fromOffset(240, 34),
    UDim2.new(0.5, -120, 0, 8),
    Color3.fromRGB(18, 18, 26), 850)
EditBanner.Visible = false
mkLabel(EditBanner,
    "✎  Tap a UI element to select",
    UDim2.new(1, -10, 1, 0), UDim2.new(0, 8, 0, 0),
    Color3.fromRGB(180, 210, 255), 11, 851)

-- ============================================================
--  PROPERTY EDITOR PANEL
-- ============================================================
local EditorPanel = nil

local function closeEditor()
    if EditorPanel then
        EditorPanel:Destroy()
        EditorPanel = nil
    end
    Highlight.Visible = false
    State.selected    = nil
end

local function openEditor(el)
    closeEditor()
    State.selected = el

    -- Snapshot original properties the first time this element is selected
    if not State.origProps[el] then
        local trans = 0
        pcall(function() trans = el.BackgroundTransparency end)
        State.origProps[el] = {
            size         = el.Size,
            position     = el.Position,
            transparency = trans,
        }
    end

    local orig = State.origProps[el]
    syncHighlight(el)

    local PW, PH = 300, 320
    EditorPanel = mkFrame(RootGui,
        UDim2.fromOffset(PW, PH),
        UDim2.new(0.5, -PW/2, 0.5, -PH/2),
        Color3.fromRGB(18, 18, 26), 800)

    -- Title / drag handle
    local titleBar = Instance.new("Frame")
    titleBar.Size             = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
    titleBar.BorderSizePixel  = 0
    titleBar.ZIndex           = 801
    titleBar.Parent           = EditorPanel
    addCorner(titleBar)

    -- square off the bottom of the title bar
    local tbFill = Instance.new("Frame")
    tbFill.Size             = UDim2.new(1, 0, 0, 10)
    tbFill.Position         = UDim2.new(0, 0, 1, -10)
    tbFill.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
    tbFill.BorderSizePixel  = 0
    tbFill.ZIndex           = 801
    tbFill.Parent           = titleBar

    mkLabel(titleBar,
        "✎  " .. el.Name .. "  (" .. el.ClassName .. ")",
        UDim2.new(1, -10, 1, 0), UDim2.new(0, 10, 0, 0),
        Color3.fromRGB(255, 255, 255), 12, 802)

    makeDraggable(EditorPanel, titleBar)
    divider(EditorPanel, 42, 801)

    -- Helper: labeled row (label left, textbox right)
    local function row(labelTxt, startVal, yOff)
        mkLabel(EditorPanel, labelTxt,
            UDim2.new(0.44, 0, 0, 26), UDim2.new(0.04, 0, 0, yOff),
            Color3.fromRGB(160, 160, 185), 12, 801)
        local inp = mkInput(EditorPanel, labelTxt, startVal,
            UDim2.new(0.46, 0, 0, 32), UDim2.new(0.5, 0, 0, yOff - 2), 802)
        return inp
    end

    -- Current absolute pixel values (easy for the user to understand)
    local curW   = math.floor(el.AbsoluteSize.X)
    local curH   = math.floor(el.AbsoluteSize.Y)
    local curX   = math.floor(el.AbsolutePosition.X)
    local curY   = math.floor(el.AbsolutePosition.Y)
    local curT   = 0
    pcall(function() curT = el.BackgroundTransparency end)

    local inputW = row("Width (px)",         tostring(curW), 52)
    local inputH = row("Height (px)",        tostring(curH), 92)
    local inputX = row("Pos X (px)",         tostring(curX), 132)
    local inputY = row("Pos Y (px)",         tostring(curY), 172)
    local inputT = row("Transparency 0–1",   tostring(curT), 212)

    divider(EditorPanel, 252, 801)

    -- ---- Apply helper ----
    local function applyValues()
        local w = tonumber(inputW.Text) or el.AbsoluteSize.X
        local h = tonumber(inputH.Text) or el.AbsoluteSize.Y
        local x = tonumber(inputX.Text) or el.AbsolutePosition.X
        local y = tonumber(inputY.Text) or el.AbsolutePosition.Y
        local t = math.clamp(tonumber(inputT.Text) or 0, 0, 1)

        pushUndo(el)

        -- Use pure offset sizing and positioning so the values are predictable
        el.Size     = UDim2.fromOffset(w, h)
        el.Position = UDim2.fromOffset(x, y)
        pcall(function() el.BackgroundTransparency = t end)

        syncHighlight(el)
    end

    -- ---- Buttons ----
    local BW = 0.21
    local function actionBtn(lbl, xScale, bg)
        local b = mkButton(EditorPanel, lbl,
            UDim2.new(BW, -4, 0, 36),
            UDim2.new(xScale, 2, 0, 265),
            bg, 801)
        b.TextSize = 11
        return b
    end

    local cancelBtn = actionBtn("Cancel", 0.02,  Color3.fromRGB(70, 70, 90))
    local doneBtn   = actionBtn("Done",   0.26,  Color3.fromRGB(22, 115, 225))
    local undoBtn   = actionBtn("Undo",   0.50,  Color3.fromRGB(180, 120, 20))
    local resetBtn  = actionBtn("Reset",  0.74,  Color3.fromRGB(175, 35, 35))

    cancelBtn.MouseButton1Click:Connect(function()
        -- restore to what it was BEFORE this edit session started
        local orig2 = State.origProps[el]
        if orig2 then
            el.Size     = orig2.size
            el.Position = orig2.position
            pcall(function() el.BackgroundTransparency = orig2.transparency end)
        end
        closeEditor()
    end)

    doneBtn.MouseButton1Click:Connect(function()
        applyValues()
        closeEditor()
    end)

    undoBtn.MouseButton1Click:Connect(function()
        local entry = popUndoFor(el)
        if entry then
            el.Size     = entry.size
            el.Position = entry.position
            pcall(function() el.BackgroundTransparency = entry.transparency end)
            -- refresh input fields
            inputW.Text = tostring(math.floor(el.AbsoluteSize.X))
            inputH.Text = tostring(math.floor(el.AbsoluteSize.Y))
            inputX.Text = tostring(math.floor(el.AbsolutePosition.X))
            inputY.Text = tostring(math.floor(el.AbsolutePosition.Y))
            local t2 = 0
            pcall(function() t2 = el.BackgroundTransparency end)
            inputT.Text = tostring(t2)
            syncHighlight(el)
        end
    end)

    resetBtn.MouseButton1Click:Connect(function()
        local orig2 = State.origProps[el]
        if orig2 then
            el.Size     = orig2.size
            el.Position = orig2.position
            pcall(function() el.BackgroundTransparency = orig2.transparency end)
            inputW.Text = tostring(math.floor(el.AbsoluteSize.X))
            inputH.Text = tostring(math.floor(el.AbsoluteSize.Y))
            inputX.Text = tostring(math.floor(el.AbsolutePosition.X))
            inputY.Text = tostring(math.floor(el.AbsolutePosition.Y))
            local t2 = 0
            pcall(function() t2 = orig2.transparency end)
            inputT.Text = tostring(t2)
            syncHighlight(el)
        end
    end)

    -- Keep highlight synced while panel is open (element might move due to tweens)
    local hConn
    hConn = RunService.RenderStepped:Connect(function()
        if not EditorPanel or not EditorPanel.Parent then
            hConn:Disconnect(); return
        end
        syncHighlight(el)
    end)
end

-- ============================================================
--  DRAG-TO-MOVE SELECTED ELEMENT
--  While in edit mode and an element is selected, dragging
--  OUTSIDE the editor panel will move the element itself.
-- ============================================================
local dragEl       = nil
local dragElStart  = nil
local touchStart   = nil

-- ============================================================
--  EDIT MODE  –  START / STOP
-- ============================================================
local touchConn

local function startEditMode()
    State.editMode  = true
    menuOpen        = false
    MainMenu.Visible  = false
    EditCloseBtn.Visible = true
    EditBanner.Visible   = true

    -- We intercept touch at the UserInputService level so we see the raw screen position
    touchConn = UserInputService.TouchStarted:Connect(function(touch, _gameProc)
        local tp = Vector2.new(touch.Position.X, touch.Position.Y)

        -- If the editor panel is open and the touch is inside it, let it handle itself
        if EditorPanel and EditorPanel.Visible then
            local ep = EditorPanel.AbsolutePosition
            local es = EditorPanel.AbsoluteSize
            if tp.X >= ep.X and tp.X <= ep.X + es.X
            and tp.Y >= ep.Y and tp.Y <= ep.Y + es.Y then
                return  -- let the panel buttons work normally
            end
        end

        -- If touch is inside the toggle or close button, skip
        for _, reservedBtn in ipairs({ ToggleBtn, EditCloseBtn }) do
            local rp = reservedBtn.AbsolutePosition
            local rs = reservedBtn.AbsoluteSize
            if tp.X >= rp.X and tp.X <= rp.X + rs.X
            and tp.Y >= rp.Y and tp.Y <= rp.Y + rs.Y then
                return
            end
        end

        -- Find which game element was tapped (smallest area wins = most specific)
        local candidates = {}
        for _, sg in ipairs(PlayerGui:GetChildren()) do
            if sg:IsA("ScreenGui") and sg ~= RootGui then
                for _, el in ipairs(sg:GetDescendants()) do
                    if el:IsA("GuiObject") and el.Visible then
                        local ap = el.AbsolutePosition
                        local as = el.AbsoluteSize
                        if as.X > 0 and as.Y > 0
                        and tp.X >= ap.X and tp.X <= ap.X + as.X
                        and tp.Y >= ap.Y and tp.Y <= ap.Y + as.Y then
                            table.insert(candidates, el)
                        end
                    end
                end
            end
        end

        if #candidates == 0 then
            closeEditor()
            return
        end

        table.sort(candidates, function(a, b)
            return (a.AbsoluteSize.X * a.AbsoluteSize.Y)
                 < (b.AbsoluteSize.X * b.AbsoluteSize.Y)
        end)

        local picked = candidates[1]

        -- Same element tapped again → start drag-to-move
        if picked == State.selected then
            dragEl      = picked
            dragElStart = picked.Position
            touchStart  = tp

            -- Track movement until touch ends
            local moveConn, endConn
            moveConn = UserInputService.TouchMoved:Connect(function(t2)
                if dragEl then
                    local d  = Vector2.new(t2.Position.X, t2.Position.Y) - touchStart
                    local cx = dragElStart.X.Offset + d.X
                    local cy = dragElStart.Y.Offset + d.Y
                    dragEl.Position = UDim2.new(dragElStart.X.Scale, cx, dragElStart.Y.Scale, cy)
                    syncHighlight(dragEl)
                    -- keep inputs up to date
                    if EditorPanel then
                        for _, inp in ipairs(EditorPanel:GetDescendants()) do
                            -- intentionally skip; user can press Done to commit
                        end
                    end
                end
            end)
            endConn = UserInputService.TouchEnded:Connect(function()
                dragEl     = nil
                touchStart = nil
                moveConn:Disconnect()
                endConn:Disconnect()
            end)
        else
            -- New element → open editor for it
            openEditor(picked)
        end
    end)
end

local function stopEditMode()
    State.editMode = false
    EditCloseBtn.Visible = false
    EditBanner.Visible   = false
    closeEditor()
    if touchConn then touchConn:Disconnect(); touchConn = nil end
    dragEl = nil
end

-- ============================================================
--  SAVE / CANCEL DIALOG
-- ============================================================
local function showDialog(question, yesLabel, noLabel, onYes, onNo)
    local dlg = mkFrame(RootGui,
        UDim2.fromOffset(270, 148),
        UDim2.new(0.5, -135, 0.5, -74),
        Color3.fromRGB(18, 18, 26), 950)

    local ql = Instance.new("TextLabel")
    ql.Size             = UDim2.new(1, -20, 0, 56)
    ql.Position         = UDim2.new(0, 10, 0, 12)
    ql.BackgroundTransparency = 1
    ql.Text             = question
    ql.Font             = Enum.Font.Gotham
    ql.TextSize         = 13
    ql.TextColor3       = Color3.fromRGB(220, 220, 240)
    ql.TextWrapped      = true
    ql.TextXAlignment   = Enum.TextXAlignment.Center
    ql.ZIndex           = 951
    ql.Parent           = dlg

    local yBtn = mkButton(dlg, yesLabel,
        UDim2.new(0.44, 0, 0, 42), UDim2.new(0.04, 0, 0, 92),
        Color3.fromRGB(22, 115, 225), 951)
    local nBtn = mkButton(dlg, noLabel,
        UDim2.new(0.44, 0, 0, 42), UDim2.new(0.52, 0, 0, 92),
        Color3.fromRGB(60, 60, 80), 951)

    yBtn.MouseButton1Click:Connect(function() dlg:Destroy(); onYes() end)
    nBtn.MouseButton1Click:Connect(function() dlg:Destroy(); onNo()  end)
end

-- ============================================================
--  FORWARD DECLARE  openLayoutButtonsPage
-- ============================================================
local openLayoutButtonsPage

-- Edit close (X) button
EditCloseBtn.MouseButton1Click:Connect(function()
    showDialog(
        "Save your layout changes?",
        "💾  Save", "✕  Discard",
        function()
            stopEditMode()
            openLayoutButtonsPage()
        end,
        function()
            showDialog(
                "Are you sure?\nAll changes will be lost.",
                "Yes, Discard", "Go Back",
                function() stopEditMode() end,
                function() EditCloseBtn.Visible = true end
            )
        end
    )
end)

EditLayoutBtn.MouseButton1Click:Connect(function()
    menuOpen = false
    MainMenu.Visible = false
    startEditMode()
end)

-- ============================================================
--  LAYOUT BUTTONS PAGE
-- ============================================================
local layoutBtnsPage

function openLayoutButtonsPage()
    if layoutBtnsPage then layoutBtnsPage:Destroy() end

    local PW, PH = 318, 430
    layoutBtnsPage = mkFrame(RootGui,
        UDim2.fromOffset(PW, PH),
        UDim2.new(0.5, -PW/2, 0.5, -PH/2),
        Color3.fromRGB(18, 18, 26), 100)

    makeDraggable(layoutBtnsPage)

    do
        local t = Instance.new("TextLabel")
        t.Size             = UDim2.new(1, 0, 0, 38)
        t.BackgroundTransparency = 1
        t.Text             = "Layout Buttons"
        t.Font             = Enum.Font.GothamBold
        t.TextSize         = 16
        t.TextColor3       = Color3.fromRGB(255, 255, 255)
        t.TextXAlignment   = Enum.TextXAlignment.Center
        t.ZIndex           = 101
        t.Parent           = layoutBtnsPage

        mkLabel(layoutBtnsPage,
            "🔒  Place ID: " .. tostring(GAME_PLACE_ID),
            UDim2.new(0.9, 0, 0, 18), UDim2.new(0.05, 0, 0, 40),
            Color3.fromRGB(90, 155, 255), 10, 101)
    end

    divider(layoutBtnsPage, 62, 101)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                  = UDim2.new(0.92, 0, 0, 218)
    scroll.Position              = UDim2.new(0.04, 0, 0, 70)
    scroll.BackgroundTransparency= 1
    scroll.BorderSizePixel       = 0
    scroll.ScrollBarThickness    = 4
    scroll.ScrollBarImageColor3  = Color3.fromRGB(80, 80, 115)
    scroll.ZIndex                = 101
    scroll.Parent                = layoutBtnsPage

    local ll = Instance.new("UIListLayout")
    ll.Padding   = UDim.new(0, 6)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent    = scroll

    local function refreshList()
        for _, c in ipairs(scroll:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end
        if #layoutData.layouts == 0 then
            mkLabel(scroll, "No saved layouts.\nTap  +  to create one.",
                UDim2.new(1, -8, 0, 60), UDim2.new(0, 4, 0, 0),
                Color3.fromRGB(110, 110, 140), 12, 102)
        else
            for i, layout in ipairs(layoutData.layouts) do
                local row = Instance.new("Frame")
                row.Size             = UDim2.new(1, -6, 0, 54)
                row.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
                row.BorderSizePixel  = 0
                row.ZIndex           = 102
                row.LayoutOrder      = i
                row.Parent           = scroll
                addCorner(row)

                mkLabel(row, layout.name or ("Layout " .. i),
                    UDim2.new(0.68, 0, 0, 26), UDim2.new(0.02, 0, 0, 6),
                    Color3.fromRGB(240, 240, 255), 13, 103)

                mkLabel(row, os.date("%d %b %Y", layout.savedAt or 0),
                    UDim2.new(0.68, 0, 0, 18), UDim2.new(0.02, 0, 0, 32),
                    Color3.fromRGB(100, 100, 130), 10, 103)

                local del = mkButton(row, "✕",
                    UDim2.fromOffset(34, 34), UDim2.new(1, -40, 0.5, -17),
                    Color3.fromRGB(175, 35, 35), 103)
                del.TextSize = 14
                del.MouseButton1Click:Connect(function()
                    showDialog(
                        "Delete '" .. (layout.name or "Layout") .. "'?",
                        "Delete", "Keep",
                        function()
                            table.remove(layoutData.layouts, i)
                            saveLayoutData()
                            refreshList()
                        end,
                        function() end
                    )
                end)
            end
        end
        scroll.CanvasSize = UDim2.fromOffset(0, ll.AbsoluteContentSize.Y + 8)
    end

    refreshList()
    divider(layoutBtnsPage, 296, 101)

    local function captureState()
        local els = {}
        for _, sg in ipairs(PlayerGui:GetChildren()) do
            if sg:IsA("ScreenGui") and sg ~= RootGui then
                for _, el in ipairs(sg:GetDescendants()) do
                    if el:IsA("GuiObject") then
                        local e = {
                            path  = el:GetFullName(),
                            sizeX = el.AbsoluteSize.X,
                            sizeY = el.AbsoluteSize.Y,
                            posX  = el.AbsolutePosition.X,
                            posY  = el.AbsolutePosition.Y,
                        }
                        pcall(function() e.transparency = el.BackgroundTransparency end)
                        table.insert(els, e)
                    end
                end
            end
        end
        return els
    end

    local function showNameDialog(cb)
        local dlg = mkFrame(RootGui,
            UDim2.fromOffset(280, 155),
            UDim2.new(0.5, -140, 0.5, -77),
            Color3.fromRGB(18, 18, 26), 200)

        mkLabel(dlg, "Name this layout:",
            UDim2.new(0.9, 0, 0, 26), UDim2.new(0.05, 0, 0, 10),
            Color3.fromRGB(210, 210, 230), 13, 201)

        local nb = mkInput(dlg, "My Layout", "",
            UDim2.new(0.84, 0, 0, 36), UDim2.new(0.08, 0, 0, 42), 201)

        local ok = mkButton(dlg, "Save", UDim2.new(0.44, 0, 0, 40), UDim2.new(0.04, 0, 0, 100), Color3.fromRGB(22, 115, 225), 201)
        local cx = mkButton(dlg, "Cancel", UDim2.new(0.44, 0, 0, 40), UDim2.new(0.52, 0, 0, 100), Color3.fromRGB(60, 60, 80), 201)

        ok.MouseButton1Click:Connect(function()
            local name = (nb.Text ~= "" and nb.Text) or ("Layout " .. (#layoutData.layouts + 1))
            dlg:Destroy()
            cb(name)
        end)
        cx.MouseButton1Click:Connect(function() dlg:Destroy() end)
    end

    -- + Create
    local addBtn = mkButton(layoutBtnsPage, "+  Create New Layout",
        UDim2.new(0.88, 0, 0, 44), UDim2.new(0.06, 0, 0, 306),
        Color3.fromRGB(22, 115, 225), 101)
    addBtn.TextSize = 13
    addBtn.MouseButton1Click:Connect(function()
        showNameDialog(function(name)
            table.insert(layoutData.layouts, {
                name     = name,
                placeId  = GAME_PLACE_ID,
                gameLink = GAME_LINK,
                savedAt  = os.time(),
                elements = captureState(),
            })
            saveLayoutData()
            refreshList()
            Rayfield:Notify({
                Title   = "Layout Saved",
                Content = "'" .. name .. "'  •  Place ID " .. tostring(GAME_PLACE_ID),
                Duration = 3,
                Image    = 4483362458,
            })
        end)
    end)

    -- Replace
    local repBtn = mkButton(layoutBtnsPage, "⟳  Replace Existing Layout",
        UDim2.new(0.88, 0, 0, 44), UDim2.new(0.06, 0, 0, 358),
        Color3.fromRGB(42, 42, 60), 101)
    repBtn.TextSize = 13
    repBtn.MouseButton1Click:Connect(function()
        if #layoutData.layouts == 0 then
            Rayfield:Notify({ Title = "No Layouts", Content = "Create one first.", Duration = 3 })
            return
        end
        local picker = mkFrame(RootGui, UDim2.fromOffset(290, 330), UDim2.new(0.5, -145, 0.5, -165), Color3.fromRGB(18, 18, 26), 200)
        makeDraggable(picker)
        mkLabel(picker, "Pick a layout to overwrite:",
            UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 4),
            Color3.fromRGB(255, 255, 255), 14, 201)
        divider(picker, 42, 201)
        local ps = Instance.new("ScrollingFrame")
        ps.Size = UDim2.new(0.9, 0, 0, 228); ps.Position = UDim2.new(0.05, 0, 0, 50)
        ps.BackgroundTransparency = 1; ps.BorderSizePixel = 0; ps.ScrollBarThickness = 4; ps.ZIndex = 201; ps.Parent = picker
        local pl = Instance.new("UIListLayout"); pl.Padding = UDim.new(0, 5); pl.Parent = ps
        for i, layout in ipairs(layoutData.layouts) do
            local pb = mkButton(ps, layout.name or ("Layout " .. i),
                UDim2.new(1, -8, 0, 46), nil, Color3.fromRGB(28, 28, 40), 202)
            pb.TextXAlignment = Enum.TextXAlignment.Left
            pb.TextSize = 13
            local p2 = Instance.new("UIPadding"); p2.PaddingLeft = UDim.new(0, 10); p2.Parent = pb
            pb.MouseButton1Click:Connect(function()
                layoutData.layouts[i].elements = captureState()
                layoutData.layouts[i].savedAt  = os.time()
                saveLayoutData()
                picker:Destroy()
                refreshList()
                Rayfield:Notify({ Title = "Replaced", Content = "'" .. (layout.name or "Layout") .. "' updated.", Duration = 3, Image = 4483362458 })
            end)
        end
        ps.CanvasSize = UDim2.fromOffset(0, pl.AbsoluteContentSize.Y + 8)
        local pcx = mkButton(picker, "Cancel", UDim2.new(0.5, 0, 0, 36), UDim2.new(0.25, 0, 0, 286), Color3.fromRGB(60, 60, 80), 201)
        pcx.MouseButton1Click:Connect(function() picker:Destroy() end)
    end)

    -- Close
    local clsBtn = mkButton(layoutBtnsPage, "✕  Close",
        UDim2.new(0.4, 0, 0, 36), UDim2.new(0.3, 0, 1, -44),
        Color3.fromRGB(55, 55, 74), 101)
    clsBtn.TextSize = 12
    clsBtn.MouseButton1Click:Connect(function()
        layoutBtnsPage:Destroy()
        layoutBtnsPage = nil
    end)
end

LayoutBtnsBtn.MouseButton1Click:Connect(function()
    menuOpen = false
    MainMenu.Visible = false
    openLayoutButtonsPage()
end)

-- ============================================================
if not UserInputService.TouchEnabled then
    Rayfield:Notify({
        Title   = "⚠ PC Detected",
        Content = "This script targets mobile. Touch editing won't work on PC.",
        Duration = 5,
    })
end

print("[MobileLayoutEditor v2] Ready | PlaceId:", GAME_PLACE_ID)
