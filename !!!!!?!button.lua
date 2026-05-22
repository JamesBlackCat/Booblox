-- ============================================================
--  UI Layout Editor — Rayfield Edition
--  Theme: Black Haze + Blue
-- ============================================================

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local PLACE_ID  = tostring(game.PlaceId)
local GAME_URL  = "roblox.com/games/" .. PLACE_ID
local SAVE_FILE = "UILayoutEditor_Layouts.json"

-- ============================================================
--  LOAD RAYFIELD
-- ============================================================

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ============================================================
--  CUSTOM THEME  (Black Haze + Blue)
-- ============================================================

Rayfield:SetCustomTheme({
    TextColor                     = Color3.fromRGB(230, 235, 255),
    Background                    = Color3.fromRGB(8,   8,  16),
    Topbar                        = Color3.fromRGB(12,  12,  22),
    Shadow                        = Color3.fromRGB(0,    0,   0),
    NotificationBackground        = Color3.fromRGB(12,  12,  22),
    NotificationActionsBackground = Color3.fromRGB(18,  18,  32),
    TabBackground                 = Color3.fromRGB(10,  10,  20),
    TabStroke                     = Color3.fromRGB(22,  22,  40),
    TabBackgroundSelected         = Color3.fromRGB(16,  16,  30),
    TabTextColor                  = Color3.fromRGB(110, 110, 140),
    SelectedTabTextColor          = Color3.fromRGB(60,  180, 255),
    ElementBackground             = Color3.fromRGB(14,  14,  26),
    ElementBackgroundHover        = Color3.fromRGB(20,  20,  36),
    SecondaryElementBackground    = Color3.fromRGB(10,  10,  20),
    ElementStroke                 = Color3.fromRGB(26,  26,  46),
    SecondaryElementStroke        = Color3.fromRGB(20,  20,  36),
    SliderBackground              = Color3.fromRGB(14,  14,  26),
    SliderProgress                = Color3.fromRGB(30,  160, 255),
    SliderStroke                  = Color3.fromRGB(26,  26,  46),
    ToggleBackground              = Color3.fromRGB(26,  26,  46),
    ToggleEnabled                 = Color3.fromRGB(30,  160, 255),
    ToggleDisabled                = Color3.fromRGB(44,  44,  66),
    ToggleEnabledStroke           = Color3.fromRGB(20,  130, 220),
    ToggleDisabledStroke          = Color3.fromRGB(36,  36,  58),
    ToggleEnabledOuterStroke      = Color3.fromRGB(10,  100, 190),
    ToggleDisabledOuterStroke     = Color3.fromRGB(26,  26,  46),
    DropdownSelected              = Color3.fromRGB(30,  160, 255),
    DropdownUnselected            = Color3.fromRGB(110, 110, 140),
    InputBackground               = Color3.fromRGB(10,  10,  20),
    InputStroke                   = Color3.fromRGB(26,  26,  46),
    PlaceholderColor              = Color3.fromRGB(70,  70,  100),
})

-- ============================================================
--  WINDOW
-- ============================================================

local Window = Rayfield:CreateWindow({
    Name             = "UI Layout Editor",
    Icon             = 0,
    LoadingTitle     = "UI Layout Editor",
    LoadingSubtitle  = "Game: " .. PLACE_ID,
    Theme            = "Custom",
    DisableRayfieldPrompts  = false,
    DisableBuildWarnings    = true,
    ConfigurationSaving     = { Enabled = false },
    Discord                 = { Enabled = false },
    KeySystem               = false,
})

-- ============================================================
--  PERSISTENCE
-- ============================================================

local layouts = {}

local function loadLayouts()
    if readfile then
        local ok, raw = pcall(readfile, SAVE_FILE)
        if ok and raw and raw ~= "" then
            local ok2, t = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok2 and type(t) == "table" then layouts = t end
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
--  DRAG UTILITY  (for custom floating panels)
--    makeDraggable(frame, onTap?)
--    Uses UIS global events — reliable on mobile touch
-- ============================================================

local TAP_PX = 14

local function makeDraggable(frame, onTap)
    local active     = false
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
        frame.Position = UDim2.fromOffset(
            math.clamp(startOff.X + dx, 0, vp.X - frame.AbsoluteSize.X),
            math.clamp(startOff.Y + dy, 0, vp.Y - frame.AbsoluteSize.Y)
        )
    end)

    UIS.InputEnded:Connect(function(input)
        if not active then return end
        if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        active = false
        if startTouch then
            local dx = math.abs(input.Position.X - startTouch.X)
            local dy = math.abs(input.Position.Y - startTouch.Y)
            if onTap and dx < TAP_PX and dy < TAP_PX then task.defer(onTap) end
        end
        startTouch = nil
    end)
end

-- ============================================================
--  ROOT SCREENGUI  (for custom panels only)
-- ============================================================

if PlayerGui:FindFirstChild("UILayoutEditor") then
    PlayerGui.UILayoutEditor:Destroy()
end

local Root = Instance.new("ScreenGui")
Root.Name            = "UILayoutEditor"
Root.ResetOnSpawn    = false
Root.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
Root.IgnoreGuiInset  = true
Root.DisplayOrder    = 998
Root.Parent          = PlayerGui

-- Custom panel colors
local BG   = Color3.fromRGB(10,  10,  20)
local BGL  = Color3.fromRGB(18,  18,  32)
local BGLL = Color3.fromRGB(26,  26,  44)
local BLUE = Color3.fromRGB(30,  160, 255)
local BLUD = Color3.fromRGB(8,   50,  90)
local WHT  = Color3.fromRGB(230, 235, 255)
local DIM  = Color3.fromRGB(110, 110, 140)
local RED  = Color3.fromRGB(235, 65,  65)
local REDD = Color3.fromRGB(42,  10,  10)

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 12); c.Parent = p
end
local function stroke(p, col, alpha, thick)
    local s = Instance.new("UIStroke"); s.Color = col or WHT; s.Transparency = alpha or 0.75
    s.Thickness = thick or 1; s.Parent = p
end
local function pad(p, t, b, l, r)
    local u = Instance.new("UIPadding"); u.PaddingTop = UDim.new(0, t or 10)
    u.PaddingBottom = UDim.new(0, b or t or 10); u.PaddingLeft = UDim.new(0, l or t or 10)
    u.PaddingRight = UDim.new(0, r or l or t or 10); u.Parent = p
end
local function vlist(p, gap)
    local l = Instance.new("UIListLayout"); l.Padding = UDim.new(0, gap or 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder; l.FillDirection = Enum.FillDirection.Vertical
    l.HorizontalAlignment = Enum.HorizontalAlignment.Left; l.Parent = p; return l
end
local function grid2(p, h, gx)
    local g = Instance.new("UIGridLayout"); g.CellSize = UDim2.new(0.5, -(gx or 6)/2, 0, h or 38)
    g.CellPadding = UDim2.new(0, gx or 6, 0, 6); g.SortOrder = Enum.SortOrder.LayoutOrder; g.Parent = p
end
local function fitH(frame, list, extra)
    task.defer(function()
        frame.Size = UDim2.fromOffset(frame.AbsoluteSize.X, list.AbsoluteContentSize.Y + (extra or 24))
    end)
end

-- ============================================================
--  STATE
-- ============================================================

local editMode       = false
local highlightMap   = {}
local originalStates = {}
local undoStates     = {}
local selectedElem   = nil

local EditPanel  = nil
local ExitBtn    = nil
local ActiveDlg  = nil

local selectedDropdownLayout = nil  -- name of layout selected in dropdown

-- ============================================================
--  TABS
-- ============================================================

local LayoutsTab = Window:CreateTab("Layouts",   4483362458)
local EditTab    = Window:CreateTab("Edit Mode",  4483366917)

-- ============================================================
--  HELPERS: rebuild the layouts dropdown
-- ============================================================

local LayoutDropdown = nil

local function layoutNames()
    local names = {}
    for _, l in ipairs(layouts) do
        table.insert(names, l.name .. (l.placeId ~= PLACE_ID and "  ⚠" or ""))
    end
    return names
end

local function findLayoutByDisplayName(displayName)
    for i, l in ipairs(layouts) do
        local dn = l.name .. (l.placeId ~= PLACE_ID and "  ⚠" or "")
        if dn == displayName then return i, l end
    end
    return nil, nil
end

local function refreshDropdown()
    if LayoutDropdown then
        local names = layoutNames()
        LayoutDropdown:Refresh(names, false)
        if #names > 0 then
            LayoutDropdown:Set(names[1])
            selectedDropdownLayout = names[1]
        else
            selectedDropdownLayout = nil
        end
    end
end

-- ============================================================
--  LAYOUTS TAB CONTENT
-- ============================================================

LayoutsTab:CreateSection("Button Layouts")

LayoutDropdown = LayoutsTab:CreateDropdown({
    Name              = "Saved Layouts",
    Options           = layoutNames(),
    CurrentOption     = {},
    MultipleOptions   = false,
    Flag              = "SelectedLayout",
    Callback          = function(value)
        selectedDropdownLayout = value
    end,
})

LayoutsTab:CreateButton({
    Name     = "Load Selected Layout",
    Callback = function()
        if not selectedDropdownLayout then
            Rayfield:Notify({ Title = "No Layout Selected", Content = "Select a layout from the dropdown first.", Duration = 3 })
            return
        end
        local _, layout = findLayoutByDisplayName(selectedDropdownLayout)
        if not layout then return end
        if layout.placeId ~= PLACE_ID then
            Rayfield:Notify({
                Title   = "Incompatible Layout",
                Content = "This layout was saved for game ID: " .. (layout.placeId or "?"),
                Duration = 4,
            })
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
        Rayfield:Notify({ Title = "Layout Loaded", Content = "\"" .. layout.name .. "\" applied.", Duration = 3 })
    end,
})

LayoutsTab:CreateSection("Manage Selected")

local RenameInput = LayoutsTab:CreateInput({
    Name              = "Rename Layout",
    CurrentValue      = "",
    PlaceholderText   = "New layout name...",
    RemoveTextAfterFocusLost = false,
    Flag              = "RenameValue",
    Callback          = function(_) end,
})

LayoutsTab:CreateButton({
    Name     = "Apply Rename",
    Callback = function()
        if not selectedDropdownLayout then
            Rayfield:Notify({ Title = "No Layout Selected", Content = "Select a layout first.", Duration = 3 }); return
        end
        local newName = Rayfield.Flags["RenameValue"]
        if not newName or newName == "" then
            Rayfield:Notify({ Title = "Empty Name", Content = "Type a new name in the input above.", Duration = 3 }); return
        end
        local i, _ = findLayoutByDisplayName(selectedDropdownLayout)
        if not i then return end
        layouts[i].name = newName
        saveLayouts(); refreshDropdown()
        Rayfield:Notify({ Title = "Renamed", Content = "Layout renamed to \"" .. newName .. "\".", Duration = 3 })
    end,
})

LayoutsTab:CreateButton({
    Name     = "Delete Selected Layout",
    Callback = function()
        if not selectedDropdownLayout then
            Rayfield:Notify({ Title = "No Layout Selected", Content = "Select a layout first.", Duration = 3 }); return
        end
        local i, layout = findLayoutByDisplayName(selectedDropdownLayout)
        if not i then return end
        local name = layout.name
        table.remove(layouts, i)
        saveLayouts(); refreshDropdown()
        Rayfield:Notify({ Title = "Deleted", Content = "\"" .. name .. "\" has been removed.", Duration = 3 })
    end,
})

-- ============================================================
--  EDIT MODE TAB CONTENT
-- ============================================================

EditTab:CreateSection("Layout Editing")

local statusLabel = EditTab:CreateLabel("Status: Idle  —  Tap 'Enter Edit Mode' to start")

EditTab:CreateButton({
    Name     = "Enter Edit Mode",
    Callback = function()
        if editMode then
            Rayfield:Notify({ Title = "Already Active", Content = "Edit mode is already on.", Duration = 2 }); return
        end
        Rayfield:Notify({
            Title   = "Edit Mode Active",
            Content = "Tap any GUI element on screen to edit it. Use the red X to exit.",
            Duration = 4,
        })
        enterEditMode()
    end,
})

EditTab:CreateSection("How It Works")
EditTab:CreateLabel("1.  Tap 'Enter Edit Mode'")
EditTab:CreateLabel("2.  Tap any game GUI element")
EditTab:CreateLabel("3.  Adjust Size & Transparency")
EditTab:CreateLabel("4.  Press the red X to save/exit")
EditTab:CreateLabel("Game ID: " .. PLACE_ID)

-- ============================================================
--  SLIDER HELPER  (for the custom edit panel)
-- ============================================================

local function makeSlider(parent, order, labelText, initVal, minVal, maxVal, fmt, onChange)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 56); wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = order; wrap.Parent = parent

    local hRow = Instance.new("Frame")
    hRow.Size = UDim2.new(1, 0, 0, 16); hRow.BackgroundTransparency = 1; hRow.Parent = wrap

    local l = Instance.new("TextLabel")
    l.Text = labelText; l.TextSize = 9; l.Font = Enum.Font.GothamBold; l.TextColor3 = DIM
    l.BackgroundTransparency = 1; l.Size = UDim2.new(0.6, 0, 1, 0); l.LetterSpacing = 1
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = hRow

    local valLbl = Instance.new("TextLabel")
    valLbl.Text = string.format(fmt, initVal); valLbl.TextSize = 9
    valLbl.Font = Enum.Font.GothamBold; valLbl.TextColor3 = BLUE
    valLbl.BackgroundTransparency = 1; valLbl.Size = UDim2.new(0.4, 0, 1, 0)
    valLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.Parent = hRow

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 28); track.Position = UDim2.fromOffset(0, 20)
    track.BackgroundColor3 = BGLL; track.BorderSizePixel = 0; corner(track, 8); track.Parent = wrap

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((initVal - minVal) / (maxVal - minVal), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = BLUE; fill.BorderSizePixel = 0; corner(fill, 8); fill.Parent = track

    local held = false
    local function apply(px)
        local rel = math.clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        local val = minVal + rel * (maxVal - minVal)
        valLbl.Text = string.format(fmt, val); onChange(val)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        held = true; apply(i.Position.X)
    end)
    UIS.InputChanged:Connect(function(i)
        if not held then return end
        if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        apply(i.Position.X)
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then held = false end
    end)
end

-- ============================================================
--  ELEMENT EDIT PANEL  (custom draggable panel)
-- ============================================================

local function destroyEditPanel()
    if EditPanel and EditPanel.Parent then EditPanel:Destroy() end
    EditPanel = nil; selectedElem = nil
end

local function showEditPanel(elem)
    destroyEditPanel()
    selectedElem = elem
    undoStates[elem] = {
        size = elem.Size, pos = elem.Position, trans = elem.BackgroundTransparency
    }

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(272, 10)
    panel.Position = UDim2.new(0.5, -136, 0.5, -115)
    panel.BackgroundColor3 = BG; panel.BackgroundTransparency = 0.04
    panel.ZIndex = 50
    corner(panel, 14); stroke(panel, BLUE, 0.38, 1.5)
    panel.Parent = Root; EditPanel = panel
    makeDraggable(panel)

    local pList = vlist(panel, 8); pad(panel, 12, 14, 12, 12)

    -- Title + close X
    local titleRow = Instance.new("Frame")
    titleRow.Size = UDim2.new(1, 0, 0, 22); titleRow.BackgroundTransparency = 1
    titleRow.LayoutOrder = 0; titleRow.Parent = panel

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Text = elem.Name; titleLbl.TextSize = 13; titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextColor3 = WHT; titleLbl.BackgroundTransparency = 1
    titleLbl.Size = UDim2.new(1, -26, 1, 0); titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 51; titleLbl.Parent = titleRow

    local closeX = Instance.new("TextButton")
    closeX.Text = "✕"; closeX.TextSize = 14; closeX.Font = Enum.Font.GothamBold
    closeX.TextColor3 = DIM; closeX.BackgroundTransparency = 1
    closeX.Size = UDim2.fromOffset(22, 22); closeX.Position = UDim2.new(1, -22, 0, 0)
    closeX.ZIndex = 51; closeX.Parent = titleRow
    closeX.Activated:Connect(function()
        local s = undoStates[elem]
        if s then elem.Size = s.size; elem.Position = s.pos; elem.BackgroundTransparency = s.trans end
        destroyEditPanel()
    end)

    -- Separator
    local sep = Instance.new("Frame"); sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = WHT; sep.BackgroundTransparency = 0.84
    sep.BorderSizePixel = 0; sep.LayoutOrder = 1; sep.Parent = panel

    -- Sliders
    makeSlider(panel, 2, "SIZE", math.max(elem.Size.X.Scale, 0.5), 0.5, 2.0, "%.0f%%",
        function(v) elem.Size = UDim2.new(v, elem.Size.X.Offset, v, elem.Size.Y.Offset) end)

    makeSlider(panel, 3, "TRANSPARENCY", elem.BackgroundTransparency, 0, 1, "%.0f%%",
        function(v) elem.BackgroundTransparency = v end)

    local sep2 = Instance.new("Frame"); sep2.Size = UDim2.new(1, 0, 0, 1)
    sep2.BackgroundColor3 = WHT; sep2.BackgroundTransparency = 0.84
    sep2.BorderSizePixel = 0; sep2.LayoutOrder = 4; sep2.Parent = panel

    -- 2×2 action buttons
    local gridFrame = Instance.new("Frame")
    gridFrame.Size = UDim2.new(1, 0, 0, 88); gridFrame.BackgroundTransparency = 1
    gridFrame.LayoutOrder = 5; gridFrame.Parent = panel
    grid2(gridFrame, 38, 6)

    local function pBtn(text, bg, fg, order)
        local b = Instance.new("TextButton"); b.Text = text; b.TextSize = 12
        b.Font = Enum.Font.GothamBold; b.TextColor3 = fg; b.BackgroundColor3 = bg
        b.AutoButtonColor = false; b.LayoutOrder = order; b.ZIndex = 51
        corner(b, 9); b.Parent = gridFrame; return b
    end

    local cancelBtn = pBtn("Cancel",  BGL,  DIM,  1)
    local doneBtn   = pBtn("Done",    BLUD, BLUE, 2)
    local undoBtn   = pBtn("Undo",    BGL,  DIM,  3)
    local resetBtn  = pBtn("Default", BGL,  DIM,  4)
    stroke(doneBtn, BLUE, 0.45, 1)

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

    fitH(panel, pList, 28)
end

-- ============================================================
--  HIGHLIGHT ALL EDITABLE ELEMENTS
-- ============================================================

local function clearHighlights()
    for _, s in pairs(highlightMap) do if s and s.Parent then s:Destroy() end end
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
                s.Color = BLUE; s.Transparency = 0.38; s.Thickness = 2; s.Parent = obj
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
--  DIALOGS  (custom, shown over everything)
-- ============================================================

local function closeDialog()
    if ActiveDlg and ActiveDlg.Parent then ActiveDlg:Destroy() end
    ActiveDlg = nil
end

local function makeDialog(borderColor)
    closeDialog()
    local d = Instance.new("Frame")
    d.Size = UDim2.fromOffset(272, 10)
    d.Position = UDim2.new(0.5, -136, 0.5, -80)
    d.BackgroundColor3 = BG; d.BackgroundTransparency = 0.04; d.ZIndex = 90
    corner(d, 14); stroke(d, borderColor or WHT, 0.74, 1.5)
    ActiveDlg = d; d.Parent = Root; return d
end

local function dlgRow(parent, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38); row.BackgroundTransparency = 1
    row.LayoutOrder = order; row.Parent = parent
    grid2(row, 38, 8); return row
end

local function dlgBtn(parent, text, bg, fg, order)
    local b = Instance.new("TextButton"); b.Text = text; b.TextSize = 12
    b.Font = Enum.Font.GothamBold; b.TextColor3 = fg; b.BackgroundColor3 = bg
    b.AutoButtonColor = false; b.LayoutOrder = order; b.ZIndex = 91
    corner(b, 9); b.Parent = parent; return b
end

local function dlgLbl(parent, text, size, color, order)
    local l = Instance.new("TextLabel"); l.Text = text; l.TextSize = size or 13
    l.Font = size and Enum.Font.Gotham or Enum.Font.GothamBold
    l.TextColor3 = color or WHT; l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 0, (size or 13) + 6); l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order; l.ZIndex = 91; l.Parent = parent; return l
end

local showExitDialog  -- forward

local function showDiscardConfirm(onBack)
    local d = makeDialog(RED)
    local dList = vlist(d, 10); pad(d, 14, 14, 14, 14)
    dlgLbl(d, "⚠   Are you sure?", 14, RED, 0)
    dlgLbl(d, "All unsaved edits will be permanently lost.", 11, DIM, 1)
    local row = dlgRow(d, 2)
    local backB = dlgBtn(row, "Go Back", BGL,  DIM, 1)
    local discB = dlgBtn(row, "Discard", REDD, RED, 2)
    stroke(discB, RED, 0.45, 1); fitH(d, dList, 28)

    backB.Activated:Connect(function() closeDialog(); if onBack then onBack() end end)
    discB.Activated:Connect(function()
        for elem, orig in pairs(originalStates) do
            if elem and elem.Parent then
                elem.Size = orig.size; elem.Position = orig.pos; elem.BackgroundTransparency = orig.trans
            end
        end
        closeDialog(); clearHighlights(); destroyEditPanel()
        if ExitBtn and ExitBtn.Parent then ExitBtn:Destroy(); ExitBtn = nil end
        undoStates = {}; editMode = false; selectedElem = nil
        statusLabel:Set("Status: Idle  —  Tap 'Enter Edit Mode' to start")
    end)
end

local function showSaveNameDialog(elemData)
    local d = makeDialog(BLUE)
    local dList = vlist(d, 10); pad(d, 14, 14, 14, 14)
    dlgLbl(d, "Name Your Layout", 14, WHT, 0)
    dlgLbl(d, "Game ID " .. PLACE_ID .. " will be locked to this layout.", 10, DIM, 1)

    local box = Instance.new("TextBox")
    box.PlaceholderText = "Layout " .. (#layouts + 1); box.Text = ""
    box.TextSize = 13; box.Font = Enum.Font.Gotham; box.TextColor3 = WHT
    box.PlaceholderColor3 = DIM; box.BackgroundColor3 = BGL
    box.Size = UDim2.new(1, 0, 0, 40); box.LayoutOrder = 2
    box.ClearTextOnFocus = false; box.ZIndex = 92
    corner(box, 9); stroke(box, BLUE, 0.45, 1); box.Parent = d

    local row = dlgRow(d, 3)
    local cancelB = dlgBtn(row, "Cancel", BGL,  DIM,  1)
    local saveB   = dlgBtn(row, "Save",   BLUD, BLUE, 2)
    stroke(saveB, BLUE, 0.4, 1); fitH(d, dList, 28)
    task.defer(function() pcall(function() box:CaptureFocus() end) end)

    local function doSave()
        local name = box.Text ~= "" and box.Text or ("Layout " .. (#layouts + 1))
        table.insert(layouts, {
            name = name, placeId = PLACE_ID, gameUrl = GAME_URL,
            savedAt = os.time(), elements = elemData,
        })
        saveLayouts(); refreshDropdown()
        closeDialog(); clearHighlights(); destroyEditPanel()
        if ExitBtn and ExitBtn.Parent then ExitBtn:Destroy(); ExitBtn = nil end
        undoStates = {}; editMode = false; selectedElem = nil
        statusLabel:Set("Status: Idle  —  Tap 'Enter Edit Mode' to start")
        Rayfield:Notify({ Title = "Layout Saved", Content = "\"" .. name .. "\" saved successfully.", Duration = 3 })
    end

    cancelB.Activated:Connect(function()
        closeDialog(); clearHighlights(); destroyEditPanel()
        if ExitBtn and ExitBtn.Parent then ExitBtn:Destroy(); ExitBtn = nil end
        undoStates = {}; editMode = false; selectedElem = nil
        statusLabel:Set("Status: Idle  —  Tap 'Enter Edit Mode' to start")
    end)
    saveB.Activated:Connect(doSave)
    box.FocusLost:Connect(function(enter) if enter then doSave() end end)
end

showExitDialog = function()
    local d = makeDialog(WHT)
    local dList = vlist(d, 10); pad(d, 14, 14, 14, 14)
    dlgLbl(d, "Exit Edit Mode", 14, WHT, 0)
    dlgLbl(d, "Save your layout or discard all changes.", 11, DIM, 1)
    local row = dlgRow(d, 2)
    local discOpt = dlgBtn(row, "Discard",     BGL,  DIM,  1)
    local saveOpt = dlgBtn(row, "Save Layout", BLUD, BLUE, 2)
    stroke(saveOpt, BLUE, 0.4, 1); fitH(d, dList, 28)

    discOpt.Activated:Connect(function() closeDialog(); showDiscardConfirm(showExitDialog) end)
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

function enterEditMode()
    editMode = true
    statusLabel:Set("Status: Editing  —  Tap any GUI element")
    highlightAll()

    -- Draggable red X exit button
    local xb = Instance.new("Frame")
    xb.Name = "ExitEditBtn"; xb.Size = UDim2.fromOffset(54, 54)
    xb.Position = UDim2.new(0.5, -27, 0, 22)
    xb.BackgroundColor3 = REDD; xb.ZIndex = 60
    corner(xb, 27); stroke(xb, RED, 0.36, 1.5); xb.Parent = Root; ExitBtn = xb

    local xIcon = Instance.new("TextLabel")
    xIcon.Text = "✕"; xIcon.TextSize = 22; xIcon.Font = Enum.Font.GothamBold
    xIcon.TextColor3 = RED; xIcon.BackgroundTransparency = 1
    xIcon.Size = UDim2.fromScale(1, 1); xIcon.ZIndex = 61
    xIcon.TextXAlignment = Enum.TextXAlignment.Center; xIcon.Parent = xb

    makeDraggable(xb, function() showExitDialog() end)
end

-- ============================================================
--  INIT
-- ============================================================

refreshDropdown()

Rayfield:Notify({
    Title   = "UI Layout Editor",
    Content = "Loaded  |  Game ID: " .. PLACE_ID,
    Duration = 4,
})

print("[UILayoutEditor] Loaded — Place ID: " .. PLACE_ID)
