-- ============================================================
--  UI Layout Editor  |  Rayfield  |  v3
--  Mobile-first  |  Black Haze + Blue theme
-- ============================================================

-- ============================================================
--  SERVICES
-- ============================================================
local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local PLACE_ID  = tostring(game.PlaceId)
local GAME_URL  = "roblox.com/games/" .. PLACE_ID
local SAVE_FILE = "UILayoutEditor_v3.json"

-- ============================================================
--  LOAD RAYFIELD
-- ============================================================
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    warn("[UILayoutEditor] Failed to load Rayfield: " .. tostring(Rayfield))
    return
end

-- ============================================================
--  CUSTOM THEME  (Black Haze + Blue)
-- ============================================================
Rayfield:SetCustomTheme({
    TextColor                     = Color3.fromRGB(225, 230, 255),
    Background                    = Color3.fromRGB(8,   8,  16),
    Topbar                        = Color3.fromRGB(11,  11,  21),
    Shadow                        = Color3.fromRGB(0,   0,   0),
    NotificationBackground        = Color3.fromRGB(11,  11,  21),
    NotificationActionsBackground = Color3.fromRGB(17,  17,  31),
    TabBackground                 = Color3.fromRGB(9,   9,  18),
    TabStroke                     = Color3.fromRGB(22,  22,  40),
    TabBackgroundSelected         = Color3.fromRGB(15,  15,  28),
    TabTextColor                  = Color3.fromRGB(100, 100, 135),
    SelectedTabTextColor          = Color3.fromRGB(55,  165, 255),
    ElementBackground             = Color3.fromRGB(14,  14,  26),
    ElementBackgroundHover        = Color3.fromRGB(20,  20,  36),
    SecondaryElementBackground    = Color3.fromRGB(10,  10,  20),
    ElementStroke                 = Color3.fromRGB(24,  24,  44),
    SecondaryElementStroke        = Color3.fromRGB(18,  18,  34),
    SliderBackground              = Color3.fromRGB(14,  14,  26),
    SliderProgress                = Color3.fromRGB(35,  155, 255),
    SliderStroke                  = Color3.fromRGB(24,  24,  44),
    ToggleBackground              = Color3.fromRGB(24,  24,  44),
    ToggleEnabled                 = Color3.fromRGB(35,  155, 255),
    ToggleDisabled                = Color3.fromRGB(42,  42,  64),
    ToggleEnabledStroke           = Color3.fromRGB(20,  125, 220),
    ToggleDisabledStroke          = Color3.fromRGB(34,  34,  56),
    ToggleEnabledOuterStroke      = Color3.fromRGB(10,   95, 185),
    ToggleDisabledOuterStroke     = Color3.fromRGB(24,  24,  44),
    DropdownSelected              = Color3.fromRGB(35,  155, 255),
    DropdownUnselected            = Color3.fromRGB(100, 100, 135),
    InputBackground               = Color3.fromRGB(10,  10,  20),
    InputStroke                   = Color3.fromRGB(24,  24,  44),
    PlaceholderColor              = Color3.fromRGB(65,  65,  95),
})

-- ============================================================
--  RAYFIELD WINDOW
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name                   = "UI Layout Editor",
    Icon                   = 0,
    LoadingTitle           = "UI Layout Editor",
    LoadingSubtitle        = "Game: " .. PLACE_ID,
    Theme                  = "Custom",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = true,
    ConfigurationSaving    = { Enabled = false },
    Discord                = { Enabled = false },
    KeySystem              = false,
})

-- ============================================================
--  PERSISTENCE
-- ============================================================
local layouts = {}

local function loadLayouts()
    if readfile then
        local ok2, raw = pcall(readfile, SAVE_FILE)
        if ok2 and raw and raw ~= "" then
            local ok3, t = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok3 and type(t) == "table" then layouts = t end
        end
    end
end

local function saveLayouts()
    if writefile then
        local ok2, data = pcall(HttpService.JSONEncode, HttpService, layouts)
        if ok2 then pcall(writefile, SAVE_FILE, data) end
    end
end

loadLayouts()

-- ============================================================
--  DRAG UTILITY
--  makeDraggable(frame, onTap?)
--  • Drags the frame within the viewport using UIS global events
--  • Fires onTap() when released with movement < TAP_PX (i.e. a tap, not a drag)
-- ============================================================
local TAP_PX = 12

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
        local nx = math.clamp(startOff.X + (input.Position.X - startTouch.X), 0, vp.X - frame.AbsoluteSize.X)
        local ny = math.clamp(startOff.Y + (input.Position.Y - startTouch.Y), 0, vp.Y - frame.AbsoluteSize.Y)
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
            if onTap and dx < TAP_PX and dy < TAP_PX then task.defer(onTap) end
        end
        startTouch = nil
    end)
end

-- ============================================================
--  CUSTOM SCREENGUI  (for floating panels only — not Rayfield)
-- ============================================================
if PlayerGui:FindFirstChild("UILayoutEditor_Panels") then
    PlayerGui.UILayoutEditor_Panels:Destroy()
end
local PanelRoot = Instance.new("ScreenGui")
PanelRoot.Name            = "UILayoutEditor_Panels"
PanelRoot.ResetOnSpawn    = false
PanelRoot.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
PanelRoot.IgnoreGuiInset  = true
PanelRoot.DisplayOrder    = 997
PanelRoot.Parent          = PlayerGui

-- Panel colours
local BG   = Color3.fromRGB(9,   9,  18)
local BGL  = Color3.fromRGB(16,  16, 30)
local BGLL = Color3.fromRGB(24,  24, 44)
local BLUE = Color3.fromRGB(35, 155, 255)
local BLUD = Color3.fromRGB(8,   45,  85)
local WHT  = Color3.fromRGB(225, 230, 255)
local DIM  = Color3.fromRGB(100, 100, 135)
local RED  = Color3.fromRGB(235,  62,  62)
local REDD = Color3.fromRGB(40,   9,   9)

-- Tiny GUI helpers
local function uicorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 12); c.Parent = p
end
local function uistroke(p, col, alpha, thick)
    local s = Instance.new("UIStroke"); s.Color = col; s.Transparency = alpha or 0.75
    s.Thickness = thick or 1; s.Parent = p
end
local function uipad(p, t, b, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop = UDim.new(0, t); u.PaddingBottom = UDim.new(0, b or t)
    u.PaddingLeft = UDim.new(0, l or t); u.PaddingRight = UDim.new(0, r or l or t)
    u.Parent = p
end
local function uivlist(p, gap)
    local l = Instance.new("UIListLayout"); l.Padding = UDim.new(0, gap or 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder; l.FillDirection = Enum.FillDirection.Vertical
    l.HorizontalAlignment = Enum.HorizontalAlignment.Left; l.Parent = p; return l
end
local function uigrid2(p, h, gx)
    local g = Instance.new("UIGridLayout")
    g.CellSize = UDim2.new(0.5, -math.ceil((gx or 6)/2), 0, h or 38)
    g.CellPadding = UDim2.new(0, gx or 6, 0, 6); g.SortOrder = Enum.SortOrder.LayoutOrder; g.Parent = p
end
local function fitHeight(frame, list, extra)
    task.defer(function()
        frame.Size = UDim2.fromOffset(frame.AbsoluteSize.X, list.AbsoluteContentSize.Y + (extra or 24))
    end)
end
local function uisep(p, order)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 1)
    f.BackgroundColor3 = WHT; f.BackgroundTransparency = 0.85
    f.BorderSizePixel = 0; f.LayoutOrder = order; f.Parent = p
end

-- ============================================================
--  STATE
-- ============================================================
local editMode       = false
local highlightMap   = {}   -- GuiObject → UIStroke
local originalStates = {}   -- GuiObject → {size, pos, trans}
local undoStates     = {}   -- GuiObject → {size, pos, trans}  (snapshot at tap time)
local EditPanel      = nil
local ExitBtn        = nil
local ActiveDlg      = nil

-- ============================================================
--  TABS
-- ============================================================
local LayoutsTab = Window:CreateTab("Layouts",  4483362458)
local EditTab    = Window:CreateTab("Edit Layout", 4483366917)

-- ============================================================
--  LAYOUTS TAB
-- ============================================================
LayoutsTab:CreateSection("Button Layouts")

-- We'll keep references to dynamically-created layout elements so we can rebuild
local layoutElements = {}  -- list of {label, dotMenu}  — rebuilt on renderLayouts()

local statusLabel    -- forward reference, defined in EditTab section below

local function renderLayouts()
    -- Destroy old dynamic elements
    for _, refs in ipairs(layoutElements) do
        for _, ref in ipairs(refs) do
            if ref and ref.Destroy then pcall(function() ref:Destroy() end) end
        end
    end
    layoutElements = {}

    if #layouts == 0 then
        local noLbl = LayoutsTab:CreateLabel("No layouts saved yet.")
        table.insert(layoutElements, {noLbl})
        return
    end

    for i, layout in ipairs(layouts) do
        local compat = layout.placeId == PLACE_ID
        local displayName = layout.name .. (not compat and "  ⚠ wrong game" or "")

        -- Section per layout (Rayfield's section acts as a visual divider/header)
        local sec = LayoutsTab:CreateSection(displayName)

        local loadBtn = LayoutsTab:CreateButton({
            Name = "Load  \"" .. layout.name .. "\"",
            Callback = function()
                if not compat then
                    Rayfield:Notify({
                        Title   = "Wrong Game",
                        Content = "Saved for ID: " .. (layout.placeId or "?") .. ". Current: " .. PLACE_ID,
                        Duration = 4,
                    }); return
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

        local renameInput = LayoutsTab:CreateInput({
            Name              = "Rename",
            CurrentValue      = "",
            PlaceholderText   = "New name...",
            RemoveTextAfterFocusLost = false,
            Flag              = "Rename_" .. i,
            Callback          = function(_) end,
        })

        local renameBtn = LayoutsTab:CreateButton({
            Name = "Apply Rename",
            Callback = function()
                local newName = Rayfield.Flags["Rename_" .. i]
                if not newName or newName == "" then
                    Rayfield:Notify({ Title = "Empty", Content = "Type a name first.", Duration = 2 }); return
                end
                layouts[i].name = newName; saveLayouts()
                Rayfield:Notify({ Title = "Renamed", Content = "Now called: \"" .. newName .. "\"", Duration = 3 })
                renderLayouts()
            end,
        })

        local deleteBtn = LayoutsTab:CreateButton({
            Name = "Delete  \"" .. layout.name .. "\"",
            Callback = function()
                local name = layouts[i].name
                table.remove(layouts, i); saveLayouts()
                Rayfield:Notify({ Title = "Deleted", Content = "\"" .. name .. "\" removed.", Duration = 3 })
                renderLayouts()
            end,
        })

        table.insert(layoutElements, {sec, loadBtn, renameInput, renameBtn, deleteBtn})
    end
end

-- ============================================================
--  EDIT LAYOUT TAB
-- ============================================================
EditTab:CreateSection("Edit Mode")

statusLabel = EditTab:CreateLabel("Idle  —  press Enter Edit Mode below")

EditTab:CreateButton({
    Name     = "Enter Edit Mode",
    Callback = function()
        if editMode then
            Rayfield:Notify({ Title = "Already Active", Content = "Edit mode is already on.", Duration = 2 })
            return
        end
        enterEditMode()
    end,
})

EditTab:CreateSection("Info")
EditTab:CreateLabel("1. Press Enter Edit Mode")
EditTab:CreateLabel("2. Drag any highlighted element to move it")
EditTab:CreateLabel("3. Tap (don't drag) an element to edit size/transparency")
EditTab:CreateLabel("4. Press the red X when done")
EditTab:CreateLabel("Game ID: " .. PLACE_ID)

-- ============================================================
--  CUSTOM SLIDER (used in the floating edit panel)
-- ============================================================
local function makeSlider(parent, order, labelText, initVal, minVal, maxVal, fmt, onChange)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 56); wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = order; wrap.Parent = parent

    local hRow = Instance.new("Frame")
    hRow.Size = UDim2.new(1, 0, 0, 16); hRow.BackgroundTransparency = 1; hRow.Parent = wrap

    local lbl = Instance.new("TextLabel")
    lbl.Text = labelText; lbl.TextSize = 9; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = DIM
    lbl.BackgroundTransparency = 1; lbl.Size = UDim2.new(0.6, 0, 1, 0); lbl.LetterSpacing = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = hRow

    local valLbl = Instance.new("TextLabel")
    valLbl.Text = string.format(fmt, initVal); valLbl.TextSize = 9; valLbl.Font = Enum.Font.GothamBold
    valLbl.TextColor3 = BLUE; valLbl.BackgroundTransparency = 1
    valLbl.Size = UDim2.new(0.4, 0, 1, 0); valLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.Parent = hRow

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 28); track.Position = UDim2.fromOffset(0, 20)
    track.BackgroundColor3 = BGLL; track.BorderSizePixel = 0; uicorner(track, 8); track.Parent = wrap

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((initVal - minVal) / (maxVal - minVal), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = BLUE; fill.BorderSizePixel = 0; uicorner(fill, 8); fill.Parent = track

    local held = false
    local function apply(px)
        local rel = math.clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valLbl.Text = string.format(fmt, minVal + rel * (maxVal - minVal))
        onChange(minVal + rel * (maxVal - minVal))
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
--  ELEMENT EDIT PANEL  (floating, draggable)
-- ============================================================
local function destroyEditPanel()
    if EditPanel and EditPanel.Parent then EditPanel:Destroy() end
    EditPanel = nil
end

local function showEditPanel(elem)
    destroyEditPanel()

    -- Save undo snapshot (state at the moment user taps)
    undoStates[elem] = {
        size  = elem.Size,
        pos   = elem.Position,
        trans = elem.BackgroundTransparency,
    }

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(274, 10)
    panel.Position = UDim2.new(0.5, -137, 0.5, -120)
    panel.BackgroundColor3 = BG; panel.BackgroundTransparency = 0.05; panel.ZIndex = 50
    uicorner(panel, 14); uistroke(panel, BLUE, 0.36, 1.5)
    panel.Parent = PanelRoot; EditPanel = panel

    -- Panel itself is draggable
    makeDraggable(panel)

    local pList = uivlist(panel, 8)
    uipad(panel, 12, 14, 12, 12)

    -- Title row (element name + close X)
    local titleRow = Instance.new("Frame")
    titleRow.Size = UDim2.new(1, 0, 0, 22); titleRow.BackgroundTransparency = 1
    titleRow.LayoutOrder = 0; titleRow.Parent = panel

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Text = elem.Name; titleLbl.TextSize = 13; titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextColor3 = WHT; titleLbl.BackgroundTransparency = 1
    titleLbl.Size = UDim2.new(1, -26, 1, 0); titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 51; titleLbl.Parent = titleRow

    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "✕"; closeBtn.TextSize = 14; closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = DIM; closeBtn.BackgroundTransparency = 1
    closeBtn.Size = UDim2.fromOffset(22, 22); closeBtn.Position = UDim2.new(1, -22, 0, 0)
    closeBtn.ZIndex = 51; closeBtn.Parent = titleRow
    closeBtn.Activated:Connect(function()
        -- Cancel = revert to undo snapshot
        local s = undoStates[elem]
        if s then elem.Size = s.size; elem.Position = s.pos; elem.BackgroundTransparency = s.trans end
        destroyEditPanel()
    end)

    uisep(panel, 1)

    -- Sliders
    makeSlider(panel, 2, "SIZE", math.max(elem.Size.X.Scale, 0.5), 0.5, 2.0, "%.0f%%",
        function(v) elem.Size = UDim2.new(v, elem.Size.X.Offset, v, elem.Size.Y.Offset) end)

    makeSlider(panel, 3, "TRANSPARENCY", elem.BackgroundTransparency, 0, 1, "%.0f%%",
        function(v) elem.BackgroundTransparency = v end)

    uisep(panel, 4)

    -- 2×2 action buttons
    local gridFrame = Instance.new("Frame")
    gridFrame.Size = UDim2.new(1, 0, 0, 88); gridFrame.BackgroundTransparency = 1
    gridFrame.LayoutOrder = 5; gridFrame.Parent = panel
    uigrid2(gridFrame, 38, 6)

    local function pBtn(text, bg, fg, order)
        local b = Instance.new("TextButton"); b.Text = text; b.TextSize = 12
        b.Font = Enum.Font.GothamBold; b.TextColor3 = fg; b.BackgroundColor3 = bg
        b.AutoButtonColor = false; b.LayoutOrder = order; b.ZIndex = 51
        uicorner(b, 9); b.Parent = gridFrame; return b
    end

    local cancelBtn = pBtn("Cancel",  BGL,  DIM,  1)
    local doneBtn   = pBtn("Done",    BLUD, BLUE, 2)
    local undoBtn   = pBtn("Undo",    BGL,  DIM,  3)
    local resetBtn  = pBtn("Default", BGL,  DIM,  4)
    uistroke(doneBtn, BLUE, 0.42, 1)

    -- Cancel: revert to undo snapshot
    cancelBtn.Activated:Connect(function()
        local s = undoStates[elem]
        if s then elem.Size = s.size; elem.Position = s.pos; elem.BackgroundTransparency = s.trans end
        destroyEditPanel()
    end)
    -- Done: keep current changes
    doneBtn.Activated:Connect(function() destroyEditPanel() end)
    -- Undo: revert to undo snapshot but keep panel open
    undoBtn.Activated:Connect(function()
        local s = undoStates[elem]
        if s then elem.Size = s.size; elem.Position = s.pos; elem.BackgroundTransparency = s.trans end
    end)
    -- Default: restore original state from BEFORE edit mode started
    resetBtn.Activated:Connect(function()
        local o = originalStates[elem]
        if o then elem.Size = o.size; elem.Position = o.pos; elem.BackgroundTransparency = o.trans end
    end)

    fitHeight(panel, pList, 28)
end

-- ============================================================
--  HIGHLIGHT + MAKE ELEMENTS DRAGGABLE IN EDIT MODE
-- ============================================================
local function clearHighlights()
    for _, s in pairs(highlightMap) do if s and s.Parent then s:Destroy() end end
    highlightMap = {}; originalStates = {}
end

local function highlightAll()
    local function scan(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("GuiObject") and not obj:IsDescendantOf(PanelRoot) then

                -- Save original state (for Reset to Default)
                originalStates[obj] = {
                    size  = obj.Size,
                    pos   = obj.Position,
                    trans = obj.BackgroundTransparency,
                }

                -- Blue dashed highlight stroke
                local s = Instance.new("UIStroke")
                s.Color = BLUE; s.Transparency = 0.35; s.Thickness = 2; s.Parent = obj
                highlightMap[obj] = s

                -- Invisible hitbox on top: handles BOTH drag-to-move and tap-to-edit
                local hitbox = Instance.new("TextButton")
                hitbox.Size = UDim2.fromScale(1, 1); hitbox.Text = ""
                hitbox.BackgroundTransparency = 1; hitbox.ZIndex = obj.ZIndex + 5
                hitbox.Parent = obj

                -- Drag-to-move the game element itself
                -- Tap (no drag) opens the edit panel
                local hActive     = false
                local hStart      = nil
                local hStartObjPos = nil

                hitbox.InputBegan:Connect(function(input)
                    if not editMode then return end
                    if input.UserInputType ~= Enum.UserInputType.Touch
                    and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    hActive      = true
                    hStart       = Vector2.new(input.Position.X, input.Position.Y)
                    hStartObjPos = Vector2.new(obj.Position.X.Offset, obj.Position.Y.Offset)
                end)

                UIS.InputChanged:Connect(function(input)
                    if not hActive then return end
                    if input.UserInputType ~= Enum.UserInputType.Touch
                    and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                    local vp = workspace.CurrentCamera.ViewportSize
                    local dx = input.Position.X - hStart.X
                    local dy = input.Position.Y - hStart.Y
                    -- Keep scale, only move offset
                    local nx = math.clamp(hStartObjPos.X + dx, 0, vp.X - obj.AbsoluteSize.X)
                    local ny = math.clamp(hStartObjPos.Y + dy, 0, vp.Y - obj.AbsoluteSize.Y)
                    obj.Position = UDim2.new(obj.Position.X.Scale, nx, obj.Position.Y.Scale, ny)
                end)

                UIS.InputEnded:Connect(function(input)
                    if not hActive then return end
                    if input.UserInputType ~= Enum.UserInputType.Touch
                    and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    hActive = false
                    if hStart then
                        local dx = math.abs(input.Position.X - hStart.X)
                        local dy = math.abs(input.Position.Y - hStart.Y)
                        if dx < TAP_PX and dy < TAP_PX then
                            -- Tap → open edit panel
                            task.defer(function() showEditPanel(obj) end)
                        end
                    end
                    hStart = nil
                end)

                scan(obj)
            end
        end
    end

    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui ~= PanelRoot and gui:IsA("ScreenGui") then scan(gui) end
    end
end

-- ============================================================
--  DIALOGS  (custom floating panels — shown over everything)
-- ============================================================
local function closeDialog()
    if ActiveDlg and ActiveDlg.Parent then ActiveDlg:Destroy() end
    ActiveDlg = nil
end

local function makeDialog(borderCol)
    closeDialog()
    local d = Instance.new("Frame")
    d.Size = UDim2.fromOffset(272, 10); d.Position = UDim2.new(0.5, -136, 0.5, -80)
    d.BackgroundColor3 = BG; d.BackgroundTransparency = 0.04; d.ZIndex = 90
    uicorner(d, 14); uistroke(d, borderCol or WHT, 0.72, 1.5)
    ActiveDlg = d; d.Parent = PanelRoot; return d
end

local function mkDlgBtn(parent, text, bg, fg, order)
    local b = Instance.new("TextButton"); b.Text = text; b.TextSize = 12
    b.Font = Enum.Font.GothamBold; b.TextColor3 = fg; b.BackgroundColor3 = bg
    b.AutoButtonColor = false; b.LayoutOrder = order; b.ZIndex = 91
    uicorner(b, 9); b.Parent = parent; return b
end

local function mkDlgLbl(parent, text, size, color, order)
    local l = Instance.new("TextLabel"); l.Text = text
    l.TextSize = size or 13; l.Font = (size and size < 13) and Enum.Font.Gotham or Enum.Font.GothamBold
    l.TextColor3 = color or WHT; l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 0, (size or 13) + 6); l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order; l.ZIndex = 91; l.Parent = parent; return l
end

-- Forward-declare so dialogs can call each other
local showExitDialog

local function showDiscardConfirm(onBack)
    local d = makeDialog(RED)
    local dList = uivlist(d, 10); uipad(d, 14, 14, 14, 14)
    mkDlgLbl(d, "⚠   Are you sure?",                       14, RED,  0)
    mkDlgLbl(d, "All unsaved edits will be lost forever.",  11, DIM,  1)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38); row.BackgroundTransparency = 1
    row.LayoutOrder = 2; row.Parent = d; uigrid2(row, 38, 8)
    local backB = mkDlgBtn(row, "Go Back", BGL,  DIM, 1)
    local discB = mkDlgBtn(row, "Discard", REDD, RED, 2)
    uistroke(discB, RED, 0.42, 1); fitHeight(d, dList, 28)

    backB.Activated:Connect(function() closeDialog(); if onBack then onBack() end end)
    discB.Activated:Connect(function()
        -- Revert all edited elements
        for elem, orig in pairs(originalStates) do
            if elem and elem.Parent then
                elem.Size = orig.size; elem.Position = orig.pos; elem.BackgroundTransparency = orig.trans
            end
        end
        closeDialog(); clearHighlights(); destroyEditPanel()
        if ExitBtn and ExitBtn.Parent then ExitBtn:Destroy(); ExitBtn = nil end
        undoStates = {}; editMode = false
        statusLabel:Set("Idle  —  press Enter Edit Mode below")
    end)
end

local function showSaveDialog(elemData)
    local d = makeDialog(BLUE)
    local dList = uivlist(d, 10); uipad(d, 14, 14, 14, 14)
    mkDlgLbl(d, "Name Your Layout",                                  14, WHT, 0)
    mkDlgLbl(d, "Game ID " .. PLACE_ID .. " will be locked to it.",  10, DIM, 1)

    local box = Instance.new("TextBox")
    box.PlaceholderText = "Layout " .. (#layouts + 1); box.Text = ""
    box.TextSize = 13; box.Font = Enum.Font.Gotham; box.TextColor3 = WHT
    box.PlaceholderColor3 = DIM; box.BackgroundColor3 = BGL
    box.Size = UDim2.new(1, 0, 0, 40); box.LayoutOrder = 2
    box.ClearTextOnFocus = false; box.ZIndex = 92
    uicorner(box, 9); uistroke(box, BLUE, 0.42, 1); box.Parent = d

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38); row.BackgroundTransparency = 1
    row.LayoutOrder = 3; row.Parent = d; uigrid2(row, 38, 8)
    local cancelB = mkDlgBtn(row, "Cancel", BGL,  DIM,  1)
    local saveB   = mkDlgBtn(row, "Save",   BLUD, BLUE, 2)
    uistroke(saveB, BLUE, 0.38, 1); fitHeight(d, dList, 28)
    task.defer(function() pcall(function() box:CaptureFocus() end) end)

    local function doSave()
        local name = box.Text ~= "" and box.Text or ("Layout " .. (#layouts + 1))
        table.insert(layouts, {
            name    = name, placeId = PLACE_ID, gameUrl = GAME_URL,
            savedAt = os.time(), elements = elemData,
        })
        saveLayouts(); renderLayouts()
        closeDialog(); clearHighlights(); destroyEditPanel()
        if ExitBtn and ExitBtn.Parent then ExitBtn:Destroy(); ExitBtn = nil end
        undoStates = {}; editMode = false
        statusLabel:Set("Idle  —  press Enter Edit Mode below")
        Rayfield:Notify({ Title = "Saved", Content = "\"" .. name .. "\" stored.", Duration = 3 })
    end

    cancelB.Activated:Connect(function()
        closeDialog(); clearHighlights(); destroyEditPanel()
        if ExitBtn and ExitBtn.Parent then ExitBtn:Destroy(); ExitBtn = nil end
        undoStates = {}; editMode = false
        statusLabel:Set("Idle  —  press Enter Edit Mode below")
    end)
    saveB.Activated:Connect(doSave)
    box.FocusLost:Connect(function(enter) if enter then doSave() end end)
end

showExitDialog = function()
    local d = makeDialog(WHT)
    local dList = uivlist(d, 10); uipad(d, 14, 14, 14, 14)
    mkDlgLbl(d, "Exit Edit Mode",                              14, WHT, 0)
    mkDlgLbl(d, "Save your layout or discard all changes.",    11, DIM, 1)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38); row.BackgroundTransparency = 1
    row.LayoutOrder = 2; row.Parent = d; uigrid2(row, 38, 8)
    local discOpt = mkDlgBtn(row, "Discard",     BGL,  DIM,  1)
    local saveOpt = mkDlgBtn(row, "Save Layout", BLUD, BLUE, 2)
    uistroke(saveOpt, BLUE, 0.38, 1); fitHeight(d, dList, 28)

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
        closeDialog(); showSaveDialog(elemData)
    end)
end

-- ============================================================
--  ENTER EDIT MODE
-- ============================================================
function enterEditMode()
    editMode = true
    statusLabel:Set("Editing  —  drag elements to move  |  tap to edit")
    highlightAll()

    -- Draggable red X button
    local xb = Instance.new("Frame")
    xb.Name = "ExitEditBtn"; xb.Size = UDim2.fromOffset(54, 54)
    xb.Position = UDim2.new(0.5, -27, 0, 22)
    xb.BackgroundColor3 = REDD; xb.ZIndex = 60
    uicorner(xb, 27); uistroke(xb, RED, 0.34, 1.5)
    xb.Parent = PanelRoot; ExitBtn = xb

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
renderLayouts()

Rayfield:Notify({
    Title    = "UI Layout Editor",
    Content  = "Ready  |  Game " .. PLACE_ID,
    Duration = 4,
})

print("[UILayoutEditor v3] Loaded — Place ID: " .. PLACE_ID)
