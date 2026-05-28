-- ═══════════════════════════════════════════════════════
-- HUD SCRIPT — Auto Farm & Cheats + ESP + Anti Death + Easy Mode
-- ═══════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ═══════════════════════════════════════════════════════
-- DATA DEFINITIONS  (used by both UI and logic)
-- ═══════════════════════════════════════════════════════

local NPC_DEFS = {
    { name = "Rotologist", enabled = true, renderDist = 100 },
    { name = "Shannon",    enabled = true, renderDist = 100 },
    { name = "Tom Cruise", enabled = true, renderDist = 100 },
}

local ROOM_DEFS = {
    { name = "Libary",      label = "Library",     danger = false, enabled = true },
    { name = "Fan",         label = "Fan Room",    danger = true,  enabled = true },
    { name = "PillarRoom1", label = "Pillar Room", danger = true,  enabled = true },
    { name = "FunRoom",     label = "Fun Room",    danger = true,  enabled = true },
    { name = "Chapel",      label = "Chapel",      danger = false, enabled = true },
    { name = "Cafeteria",   label = "Cafeteria",   danger = false, enabled = true },
}

local HITBOX_TARGETS = { "Tom Cruise", "Shannon", "Rotologist" }

-- ═══════════════════════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MainHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui

-- ═══════════════════════════════════════════════════════
-- DRAGGING UTILITY
-- ═══════════════════════════════════════════════════════

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end

-- ═══════════════════════════════════════════════════════
-- CIRCULAR TOGGLE BUTTON
-- ═══════════════════════════════════════════════════════

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name             = "ToggleBtn"
toggleBtn.Size             = UDim2.new(0, 54, 0, 54)
toggleBtn.Position         = UDim2.new(0, 18, 0.5, -27)
toggleBtn.BackgroundColor3 = Color3.fromRGB(72, 72, 78)
toggleBtn.BorderSizePixel  = 0
toggleBtn.Text             = "☰"
toggleBtn.TextColor3       = Color3.fromRGB(215, 215, 220)
toggleBtn.TextSize         = 22
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.AutoButtonColor  = false
toggleBtn.ZIndex           = 5
toggleBtn.Parent           = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
local tbStroke = Instance.new("UIStroke", toggleBtn)
tbStroke.Color = Color3.fromRGB(110, 110, 120); tbStroke.Thickness = 1.5
makeDraggable(toggleBtn)

-- ═══════════════════════════════════════════════════════
-- MAIN MENU FRAME
-- ═══════════════════════════════════════════════════════

local mainMenu = Instance.new("Frame")
mainMenu.Name             = "MainMenu"
mainMenu.Size             = UDim2.new(0.42, 0, 0, 520)
mainMenu.Position         = UDim2.new(0.29, 0, 0.08, 0)
mainMenu.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
mainMenu.BorderSizePixel  = 0
mainMenu.Visible          = false
mainMenu.Active           = true
mainMenu.ZIndex           = 4
mainMenu.Parent           = screenGui
Instance.new("UICorner", mainMenu).CornerRadius = UDim.new(0, 12)
local menuStroke = Instance.new("UIStroke", mainMenu)
menuStroke.Color = Color3.fromRGB(50, 50, 62); menuStroke.Thickness = 1

-- ── Title bar ────────────────────────────────────────

local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 5
titleBar.Parent           = mainMenu
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)
local tbFix = Instance.new("Frame")
tbFix.Size = UDim2.new(1, 0, 0.5, 0); tbFix.Position = UDim2.new(0, 0, 0.5, 0)
tbFix.BackgroundColor3 = Color3.fromRGB(22, 22, 28); tbFix.BorderSizePixel = 0
tbFix.ZIndex = 5; tbFix.Parent = titleBar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -96, 1, 0); titleLbl.Position = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "HUD Menu"
titleLbl.TextColor3 = Color3.fromRGB(225, 225, 232); titleLbl.TextSize = 15
titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 6; titleLbl.Parent = titleBar

local closeMenuBtn = Instance.new("TextButton")
closeMenuBtn.Size = UDim2.new(0, 28, 0, 28); closeMenuBtn.Position = UDim2.new(1, -36, 0, 8)
closeMenuBtn.BackgroundColor3 = Color3.fromRGB(175, 50, 50); closeMenuBtn.Text = "✕"
closeMenuBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeMenuBtn.TextSize = 13
closeMenuBtn.Font = Enum.Font.GothamBold; closeMenuBtn.BorderSizePixel = 0
closeMenuBtn.ZIndex = 6; closeMenuBtn.Parent = titleBar
Instance.new("UICorner", closeMenuBtn).CornerRadius = UDim.new(0, 6)
closeMenuBtn.MouseButton1Click:Connect(function() mainMenu.Visible = false end)
makeDraggable(mainMenu, titleBar)

-- ═══════════════════════════════════════════════════════
-- SIDEBAR (vertical scrollable category list)
-- ═══════════════════════════════════════════════════════
-- Layout: title(44) | middle(520-44-84=392) | bottom(84)
-- Sidebar: left 112px of middle area

local SIDEBAR_W   = 112
local TITLE_H     = 44
local BOTTOM_H    = 84  -- anti-death section + padding

local sidebar = Instance.new("ScrollingFrame")
sidebar.Name                  = "Sidebar"
sidebar.Size                  = UDim2.new(0, SIDEBAR_W, 1, -(TITLE_H + BOTTOM_H))
sidebar.Position              = UDim2.new(0, 0, 0, TITLE_H)
sidebar.BackgroundColor3      = Color3.fromRGB(20, 20, 26)
sidebar.BorderSizePixel       = 0
sidebar.ScrollBarThickness    = 0
sidebar.ScrollingDirection    = Enum.ScrollingDirection.Y
sidebar.CanvasSize            = UDim2.new(0, 0, 0, 0)
sidebar.AutomaticCanvasSize   = Enum.AutomaticSize.Y
sidebar.ClipsDescendants      = true
sidebar.ZIndex                = 5
sidebar.Parent                = mainMenu

local sidebarLayout = Instance.new("UIListLayout", sidebar)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Padding   = UDim.new(0, 2)

local sidebarPad = Instance.new("UIPadding", sidebar)
sidebarPad.PaddingTop    = UDim.new(0, 6)
sidebarPad.PaddingLeft   = UDim.new(0, 6)
sidebarPad.PaddingRight  = UDim.new(0, 6)
sidebarPad.PaddingBottom = UDim.new(0, 6)

-- Sidebar divider
local sidebarDivider = Instance.new("Frame")
sidebarDivider.Size             = UDim2.new(0, 1, 1, -(TITLE_H + BOTTOM_H))
sidebarDivider.Position         = UDim2.new(0, SIDEBAR_W, 0, TITLE_H)
sidebarDivider.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
sidebarDivider.BorderSizePixel  = 0
sidebarDivider.ZIndex           = 5
sidebarDivider.Parent           = mainMenu

-- ── Sidebar category button factory ──────────────────

local sidebarBtns = {}

local function newSidebarBtn(label, order)
    local btn = Instance.new("TextButton")
    btn.Name             = "Cat_" .. label
    btn.Size             = UDim2.new(1, 0, 0, 52)
    btn.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    btn.BorderSizePixel  = 0
    btn.Text             = label
    btn.TextColor3       = Color3.fromRGB(145, 145, 158)
    btn.TextSize         = 11
    btn.Font             = Enum.Font.GothamSemibold
    btn.TextWrapped      = true
    btn.LayoutOrder      = order
    btn.ZIndex           = 6
    btn.Parent           = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    sidebarBtns[label] = btn
    return btn
end

local catAFBtn  = newSidebarBtn("Auto Farm\n& Cheats", 1)
local catESPBtn = newSidebarBtn("ESP", 2)

-- ═══════════════════════════════════════════════════════
-- CONTENT SCROLL FRAME (right of sidebar)
-- ═══════════════════════════════════════════════════════

local CONTENT_X = SIDEBAR_W + 2

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                  = "ContentScroll"
scrollFrame.Size                  = UDim2.new(1, -(CONTENT_X + 12), 1, -(TITLE_H + BOTTOM_H))
scrollFrame.Position              = UDim2.new(0, CONTENT_X, 0, TITLE_H)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel       = 0
scrollFrame.ScrollBarThickness    = 3
scrollFrame.ScrollBarImageColor3  = Color3.fromRGB(70, 70, 85)
scrollFrame.CanvasSize            = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize   = Enum.AutomaticSize.Y
scrollFrame.ClipsDescendants      = true
scrollFrame.ZIndex                = 5
scrollFrame.Parent                = mainMenu

-- ═══════════════════════════════════════════════════════
-- SHARED UI HELPERS
-- ═══════════════════════════════════════════════════════

local COL_ROW = Color3.fromRGB(22, 22, 30)
local COL_OFF = Color3.fromRGB(52, 52, 64)
local COL_ON  = Color3.fromRGB(38, 155, 78)
local COL_TXT = Color3.fromRGB(200, 200, 212)
local COL_DIM = Color3.fromRGB(140, 140, 155)

local function applyToggleVisual(btn, state)
    if state then
        btn.BackgroundColor3 = COL_ON
        btn.Text             = "ON"
        btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    else
        btn.BackgroundColor3 = COL_OFF
        btn.Text             = "OFF"
        btn.TextColor3       = Color3.fromRGB(180, 180, 192)
    end
end

local function makeToggleRow(parent, label, yOrder, extraH)
    extraH = extraH or 0
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 40 + extraH)
    row.BackgroundColor3 = COL_ROW
    row.BorderSizePixel  = 0
    row.LayoutOrder      = yOrder
    row.ZIndex           = 6
    row.Parent           = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -88, 0, 40); lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = label
    lbl.TextColor3 = COL_TXT; lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamSemibold; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7; lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 56, 0, 26); btn.Position = UDim2.new(1, -64, 0, 7)
    btn.BackgroundColor3 = COL_OFF; btn.Text = "OFF"
    btn.TextColor3 = Color3.fromRGB(180, 180, 192); btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold; btn.BorderSizePixel = 0
    btn.ZIndex = 7; btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn, row
end

local function addSubLabel(row, text, yOffset)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.55, 0, 0, 20); lbl.Position = UDim2.new(0, 12, 0, yOffset)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.TextColor3 = COL_DIM; lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7; lbl.Parent = row
    return lbl
end

local function addInputBox(row, default, yOffset)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 76, 0, 22); box.Position = UDim2.new(1, -86, 0, yOffset)
    box.BackgroundColor3 = Color3.fromRGB(28, 28, 36); box.Text = tostring(default)
    box.TextColor3 = Color3.fromRGB(220, 220, 232); box.TextSize = 11
    box.Font = Enum.Font.Gotham; box.ClearTextOnFocus = false; box.BorderSizePixel = 0
    box.ZIndex = 7; box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
    local s = Instance.new("UIStroke", box)
    s.Color = Color3.fromRGB(55, 55, 70); s.Thickness = 1
    return box
end

-- ═══════════════════════════════════════════════════════
-- AUTO FARM & CHEATS PANEL
-- ═══════════════════════════════════════════════════════

local afPanel = Instance.new("Frame")
afPanel.Size = UDim2.new(1, 0, 0, 0); afPanel.AutomaticSize = Enum.AutomaticSize.Y
afPanel.BackgroundTransparency = 1; afPanel.ZIndex = 6; afPanel.Parent = scrollFrame

local afPanelLayout = Instance.new("UIListLayout", afPanel)
afPanelLayout.SortOrder = Enum.SortOrder.LayoutOrder; afPanelLayout.Padding = UDim.new(0, 6)

local afPanelPad = Instance.new("UIPadding", afPanel)
afPanelPad.PaddingTop = UDim.new(0, 6); afPanelPad.PaddingBottom = UDim.new(0, 6)

-- Status row
local afStatusRow = Instance.new("Frame")
afStatusRow.Size = UDim2.new(1, 0, 0, 34); afStatusRow.BackgroundColor3 = COL_ROW
afStatusRow.BorderSizePixel = 0; afStatusRow.LayoutOrder = 0; afStatusRow.ZIndex = 6
afStatusRow.Parent = afPanel
Instance.new("UICorner", afStatusRow).CornerRadius = UDim.new(0, 8)

local afStatusLbl = Instance.new("TextLabel")
afStatusLbl.Size = UDim2.new(1, -16, 1, 0); afStatusLbl.Position = UDim2.new(0, 12, 0, 0)
afStatusLbl.BackgroundTransparency = 1; afStatusLbl.Text = "Status: Idle"
afStatusLbl.TextColor3 = COL_DIM; afStatusLbl.TextSize = 11
afStatusLbl.Font = Enum.Font.Gotham; afStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
afStatusLbl.ZIndex = 7; afStatusLbl.Parent = afStatusRow

-- Toggles
local afToggleBtn,  _  = makeToggleRow(afPanel, "Auto Farm",            1)
local afAutoSellBtn, _ = makeToggleRow(afPanel, "Auto Sell (10 items)", 2)

-- Sell All
local afSellRow = Instance.new("Frame")
afSellRow.Size = UDim2.new(1, 0, 0, 38); afSellRow.BackgroundColor3 = Color3.fromRGB(130, 38, 38)
afSellRow.BorderSizePixel = 0; afSellRow.LayoutOrder = 3; afSellRow.ZIndex = 6
afSellRow.Parent = afPanel
Instance.new("UICorner", afSellRow).CornerRadius = UDim.new(0, 8)
local afSellAllBtn = Instance.new("TextButton")
afSellAllBtn.Size = UDim2.new(1, 0, 1, 0); afSellAllBtn.BackgroundTransparency = 1
afSellAllBtn.Text = "Sell All"; afSellAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
afSellAllBtn.TextSize = 13; afSellAllBtn.Font = Enum.Font.GothamBold
afSellAllBtn.BorderSizePixel = 0; afSellAllBtn.ZIndex = 7; afSellAllBtn.Parent = afSellRow

-- Easy Mode (toggle + HP input)
local easyModeBtn, easyModeRow = makeToggleRow(afPanel, "Easy Mode", 4, 32)
addSubLabel(easyModeRow, "TP at HP ≤", 41)
local easyModeHPInput = addInputBox(easyModeRow, 50, 39)
easyModeHPInput.PlaceholderText = "HP"

-- TP to Safe button
local tpSafeRow = Instance.new("Frame")
tpSafeRow.Size = UDim2.new(1, 0, 0, 38); tpSafeRow.BackgroundColor3 = Color3.fromRGB(38, 80, 160)
tpSafeRow.BorderSizePixel = 0; tpSafeRow.LayoutOrder = 5; tpSafeRow.ZIndex = 6
tpSafeRow.Parent = afPanel
Instance.new("UICorner", tpSafeRow).CornerRadius = UDim.new(0, 8)
local tpSafeBtn = Instance.new("TextButton")
tpSafeBtn.Size = UDim2.new(1, 0, 1, 0); tpSafeBtn.BackgroundTransparency = 1
tpSafeBtn.Text = "⟵ Teleport to Safe Spot"; tpSafeBtn.TextColor3 = Color3.fromRGB(200, 220, 255)
tpSafeBtn.TextSize = 13; tpSafeBtn.Font = Enum.Font.GothamBold
tpSafeBtn.BorderSizePixel = 0; tpSafeBtn.ZIndex = 7; tpSafeBtn.Parent = tpSafeRow

-- ── Hitbox Section ────────────────────────────────────

local hitboxSection = Instance.new("Frame")
hitboxSection.Size = UDim2.new(1, 0, 0, 0); hitboxSection.AutomaticSize = Enum.AutomaticSize.Y
hitboxSection.BackgroundColor3 = COL_ROW; hitboxSection.BorderSizePixel = 0
hitboxSection.LayoutOrder = 6; hitboxSection.ZIndex = 6; hitboxSection.Parent = afPanel
Instance.new("UICorner", hitboxSection).CornerRadius = UDim.new(0, 8)

local hitboxSectionLayout = Instance.new("UIListLayout", hitboxSection)
hitboxSectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
hitboxSectionLayout.Padding = UDim.new(0, 0)

-- Hitbox top row (toggle)
local hitboxTopRow = Instance.new("Frame")
hitboxTopRow.Size = UDim2.new(1, 0, 0, 40); hitboxTopRow.BackgroundTransparency = 1
hitboxTopRow.LayoutOrder = 0; hitboxTopRow.ZIndex = 6; hitboxTopRow.Parent = hitboxSection

local hitboxLabel = Instance.new("TextLabel")
hitboxLabel.Size = UDim2.new(1, -88, 0, 40); hitboxLabel.Position = UDim2.new(0, 12, 0, 0)
hitboxLabel.BackgroundTransparency = 1; hitboxLabel.Text = "Hitbox"
hitboxLabel.TextColor3 = COL_TXT; hitboxLabel.TextSize = 12
hitboxLabel.Font = Enum.Font.GothamSemibold; hitboxLabel.TextXAlignment = Enum.TextXAlignment.Left
hitboxLabel.ZIndex = 7; hitboxLabel.Parent = hitboxTopRow

local hitboxBtn = Instance.new("TextButton")
hitboxBtn.Size = UDim2.new(0, 56, 0, 26); hitboxBtn.Position = UDim2.new(1, -64, 0, 7)
hitboxBtn.BackgroundColor3 = COL_OFF; hitboxBtn.Text = "OFF"
hitboxBtn.TextColor3 = Color3.fromRGB(180, 180, 192); hitboxBtn.TextSize = 12
hitboxBtn.Font = Enum.Font.GothamBold; hitboxBtn.BorderSizePixel = 0
hitboxBtn.ZIndex = 7; hitboxBtn.Parent = hitboxTopRow
Instance.new("UICorner", hitboxBtn).CornerRadius = UDim.new(0, 6)

-- Hitbox divider
local hbDiv = Instance.new("Frame")
hbDiv.Size = UDim2.new(1, -24, 0, 1); hbDiv.Position = UDim2.new(0, 12, 0, 0)
hbDiv.BackgroundColor3 = Color3.fromRGB(38, 38, 52); hbDiv.BorderSizePixel = 0
hbDiv.LayoutOrder = 1; hbDiv.ZIndex = 7; hbDiv.Parent = hitboxSection

-- Hitbox size row
local hitboxSizeRow = Instance.new("Frame")
hitboxSizeRow.Size = UDim2.new(1, 0, 0, 34); hitboxSizeRow.BackgroundTransparency = 1
hitboxSizeRow.LayoutOrder = 2; hitboxSizeRow.ZIndex = 6; hitboxSizeRow.Parent = hitboxSection

local hitboxSizeLbl = Instance.new("TextLabel")
hitboxSizeLbl.Size = UDim2.new(0.5, 0, 1, 0); hitboxSizeLbl.Position = UDim2.new(0, 12, 0, 0)
hitboxSizeLbl.BackgroundTransparency = 1; hitboxSizeLbl.Text = "Size"
hitboxSizeLbl.TextColor3 = COL_DIM; hitboxSizeLbl.TextSize = 11
hitboxSizeLbl.Font = Enum.Font.Gotham; hitboxSizeLbl.TextXAlignment = Enum.TextXAlignment.Left
hitboxSizeLbl.ZIndex = 7; hitboxSizeLbl.Parent = hitboxSizeRow

local hitboxSizeInput = Instance.new("TextBox")
hitboxSizeInput.Size = UDim2.new(0, 76, 0, 22); hitboxSizeInput.Position = UDim2.new(1, -86, 0, 6)
hitboxSizeInput.BackgroundColor3 = Color3.fromRGB(28, 28, 36); hitboxSizeInput.Text = "10"
hitboxSizeInput.TextColor3 = Color3.fromRGB(220, 220, 232); hitboxSizeInput.TextSize = 11
hitboxSizeInput.Font = Enum.Font.Gotham; hitboxSizeInput.ClearTextOnFocus = false
hitboxSizeInput.BorderSizePixel = 0; hitboxSizeInput.ZIndex = 7; hitboxSizeInput.Parent = hitboxSizeRow
Instance.new("UICorner", hitboxSizeInput).CornerRadius = UDim.new(0, 5)
local hbSizeStroke = Instance.new("UIStroke", hitboxSizeInput)
hbSizeStroke.Color = Color3.fromRGB(55, 55, 70); hbSizeStroke.Thickness = 1

-- Hitbox transparency row
local hitboxTransRow = Instance.new("Frame")
hitboxTransRow.Size = UDim2.new(1, 0, 0, 34); hitboxTransRow.BackgroundTransparency = 1
hitboxTransRow.LayoutOrder = 3; hitboxTransRow.ZIndex = 6; hitboxTransRow.Parent = hitboxSection

local hitboxTransLbl = Instance.new("TextLabel")
hitboxTransLbl.Size = UDim2.new(0.5, 0, 1, 0); hitboxTransLbl.Position = UDim2.new(0, 12, 0, 0)
hitboxTransLbl.BackgroundTransparency = 1; hitboxTransLbl.Text = "Transparency (0–1)"
hitboxTransLbl.TextColor3 = COL_DIM; hitboxTransLbl.TextSize = 11
hitboxTransLbl.Font = Enum.Font.Gotham; hitboxTransLbl.TextXAlignment = Enum.TextXAlignment.Left
hitboxTransLbl.ZIndex = 7; hitboxTransLbl.Parent = hitboxTransRow

local hitboxTransInput = Instance.new("TextBox")
hitboxTransInput.Size = UDim2.new(0, 76, 0, 22); hitboxTransInput.Position = UDim2.new(1, -86, 0, 6)
hitboxTransInput.BackgroundColor3 = Color3.fromRGB(28, 28, 36); hitboxTransInput.Text = "0.5"
hitboxTransInput.TextColor3 = Color3.fromRGB(220, 220, 232); hitboxTransInput.TextSize = 11
hitboxTransInput.Font = Enum.Font.Gotham; hitboxTransInput.ClearTextOnFocus = false
hitboxTransInput.BorderSizePixel = 0; hitboxTransInput.ZIndex = 7; hitboxTransInput.Parent = hitboxTransRow
Instance.new("UICorner", hitboxTransInput).CornerRadius = UDim.new(0, 5)
local hbTransStroke = Instance.new("UIStroke", hitboxTransInput)
hbTransStroke.Color = Color3.fromRGB(55, 55, 70); hbTransStroke.Thickness = 1

-- Bottom padding for hitbox section
local hbBottomPad = Instance.new("Frame")
hbBottomPad.Size = UDim2.new(1, 0, 0, 6); hbBottomPad.BackgroundTransparency = 1
hbBottomPad.LayoutOrder = 4; hbBottomPad.Parent = hitboxSection

-- ═══════════════════════════════════════════════════════
-- ESP PANEL
-- ═══════════════════════════════════════════════════════

local espPanel = Instance.new("Frame")
espPanel.Size = UDim2.new(1, 0, 0, 0); espPanel.AutomaticSize = Enum.AutomaticSize.Y
espPanel.BackgroundTransparency = 1; espPanel.Visible = false
espPanel.ZIndex = 6; espPanel.Parent = scrollFrame

local espPanelLayout = Instance.new("UIListLayout", espPanel)
espPanelLayout.SortOrder = Enum.SortOrder.LayoutOrder; espPanelLayout.Padding = UDim.new(0, 6)

local espPanelPad = Instance.new("UIPadding", espPanel)
espPanelPad.PaddingTop = UDim.new(0, 6); espPanelPad.PaddingBottom = UDim.new(0, 6)

-- ESP Player
local espPlayerBtn, espPlayerRow = makeToggleRow(espPanel, "ESP Player", 1, 30)
addSubLabel(espPlayerRow, "Max render (studs):", 40)
local espCapInput = addInputBox(espPlayerRow, 200, 38)

-- ── ESP NPC section (toggle + per-NPC filters) ────────

local espNPCSection = Instance.new("Frame")
espNPCSection.Size = UDim2.new(1, 0, 0, 0); espNPCSection.AutomaticSize = Enum.AutomaticSize.Y
espNPCSection.BackgroundColor3 = COL_ROW; espNPCSection.BorderSizePixel = 0
espNPCSection.LayoutOrder = 2; espNPCSection.ZIndex = 6; espNPCSection.Parent = espPanel
Instance.new("UICorner", espNPCSection).CornerRadius = UDim.new(0, 8)

local espNPCSectionLayout = Instance.new("UIListLayout", espNPCSection)
espNPCSectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
espNPCSectionLayout.Padding = UDim.new(0, 0)

-- ESP NPC top toggle row
local espNPCTopRow = Instance.new("Frame")
espNPCTopRow.Size = UDim2.new(1, 0, 0, 40); espNPCTopRow.BackgroundTransparency = 1
espNPCTopRow.LayoutOrder = 0; espNPCTopRow.ZIndex = 6; espNPCTopRow.Parent = espNPCSection

local espNPCLbl = Instance.new("TextLabel")
espNPCLbl.Size = UDim2.new(1, -88, 0, 40); espNPCLbl.Position = UDim2.new(0, 12, 0, 0)
espNPCLbl.BackgroundTransparency = 1; espNPCLbl.Text = "ESP NPC"
espNPCLbl.TextColor3 = COL_TXT; espNPCLbl.TextSize = 12
espNPCLbl.Font = Enum.Font.GothamSemibold; espNPCLbl.TextXAlignment = Enum.TextXAlignment.Left
espNPCLbl.ZIndex = 7; espNPCLbl.Parent = espNPCTopRow

local espNPCBtn = Instance.new("TextButton")
espNPCBtn.Size = UDim2.new(0, 56, 0, 26); espNPCBtn.Position = UDim2.new(1, -64, 0, 7)
espNPCBtn.BackgroundColor3 = COL_OFF; espNPCBtn.Text = "OFF"
espNPCBtn.TextColor3 = Color3.fromRGB(180, 180, 192); espNPCBtn.TextSize = 12
espNPCBtn.Font = Enum.Font.GothamBold; espNPCBtn.BorderSizePixel = 0
espNPCBtn.ZIndex = 7; espNPCBtn.Parent = espNPCTopRow
Instance.new("UICorner", espNPCBtn).CornerRadius = UDim.new(0, 6)

-- Divider
local npcDiv = Instance.new("Frame")
npcDiv.Size = UDim2.new(1, -24, 0, 1); npcDiv.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
npcDiv.BorderSizePixel = 0; npcDiv.LayoutOrder = 1; npcDiv.ZIndex = 7; npcDiv.Parent = espNPCSection

-- Per-NPC filter rows (name toggle + render dist input)
for i, def in ipairs(NPC_DEFS) do
    local npcRow = Instance.new("Frame")
    npcRow.Size = UDim2.new(1, 0, 0, 36); npcRow.BackgroundTransparency = 1
    npcRow.LayoutOrder = i + 1; npcRow.ZIndex = 6; npcRow.Parent = espNPCSection

    local npcFilterBtn = Instance.new("TextButton")
    npcFilterBtn.Size = UDim2.new(0.46, -4, 0, 24); npcFilterBtn.Position = UDim2.new(0, 10, 0, 6)
    npcFilterBtn.BackgroundColor3 = COL_ON; npcFilterBtn.Text = def.name
    npcFilterBtn.TextColor3 = Color3.fromRGB(255, 255, 255); npcFilterBtn.TextSize = 11
    npcFilterBtn.Font = Enum.Font.GothamSemibold; npcFilterBtn.BorderSizePixel = 0
    npcFilterBtn.ZIndex = 7; npcFilterBtn.Parent = npcRow
    Instance.new("UICorner", npcFilterBtn).CornerRadius = UDim.new(0, 6)

    local rdLbl = Instance.new("TextLabel")
    rdLbl.Size = UDim2.new(0, 30, 0, 24); rdLbl.Position = UDim2.new(0.46, 2, 0, 6)
    rdLbl.BackgroundTransparency = 1; rdLbl.Text = "Dist:"
    rdLbl.TextColor3 = COL_DIM; rdLbl.TextSize = 10
    rdLbl.Font = Enum.Font.Gotham; rdLbl.TextXAlignment = Enum.TextXAlignment.Left
    rdLbl.ZIndex = 7; rdLbl.Parent = npcRow

    local rdInput = Instance.new("TextBox")
    rdInput.Size = UDim2.new(0, 58, 0, 22); rdInput.Position = UDim2.new(1, -66, 0, 7)
    rdInput.BackgroundColor3 = Color3.fromRGB(28, 28, 36); rdInput.Text = tostring(def.renderDist)
    rdInput.TextColor3 = Color3.fromRGB(220, 220, 232); rdInput.TextSize = 11
    rdInput.Font = Enum.Font.Gotham; rdInput.ClearTextOnFocus = false; rdInput.BorderSizePixel = 0
    rdInput.ZIndex = 7; rdInput.Parent = npcRow
    Instance.new("UICorner", rdInput).CornerRadius = UDim.new(0, 5)
    local rdS = Instance.new("UIStroke", rdInput)
    rdS.Color = Color3.fromRGB(55, 55, 70); rdS.Thickness = 1

    -- Capture index in closures
    local idx = i
    npcFilterBtn.MouseButton1Click:Connect(function()
        NPC_DEFS[idx].enabled = not NPC_DEFS[idx].enabled
        if NPC_DEFS[idx].enabled then
            npcFilterBtn.BackgroundColor3 = COL_ON
            npcFilterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            npcFilterBtn.BackgroundColor3 = Color3.fromRGB(130, 38, 38)
            npcFilterBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end)

    rdInput.FocusLost:Connect(function()
        local v = tonumber(rdInput.Text)
        if v and v > 0 then NPC_DEFS[idx].renderDist = v
        else rdInput.Text = tostring(NPC_DEFS[idx].renderDist) end
    end)
end

-- Bottom padding for NPC section
local npcSectionPad = Instance.new("Frame")
npcSectionPad.Size = UDim2.new(1, 0, 0, 6); npcSectionPad.BackgroundTransparency = 1
npcSectionPad.LayoutOrder = #NPC_DEFS + 3; npcSectionPad.Parent = espNPCSection

-- ESP Items + Exit
local espItemsBtn, _ = makeToggleRow(espPanel, "ESP Items", 3)
local espExitBtn,  _ = makeToggleRow(espPanel, "ESP Exit",  4)

-- ── ESP Rooms section ─────────────────────────────────

local espRoomsSection = Instance.new("Frame")
espRoomsSection.Size = UDim2.new(1, 0, 0, 0); espRoomsSection.AutomaticSize = Enum.AutomaticSize.Y
espRoomsSection.BackgroundColor3 = COL_ROW; espRoomsSection.BorderSizePixel = 0
espRoomsSection.LayoutOrder = 5; espRoomsSection.ZIndex = 6; espRoomsSection.Parent = espPanel
Instance.new("UICorner", espRoomsSection).CornerRadius = UDim.new(0, 8)

local espRoomsSectionLayout = Instance.new("UIListLayout", espRoomsSection)
espRoomsSectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
espRoomsSectionLayout.Padding = UDim.new(0, 0)

-- Rooms top row (toggle + render distance)
local espRoomsTopRow = Instance.new("Frame")
espRoomsTopRow.Size = UDim2.new(1, 0, 0, 40); espRoomsTopRow.BackgroundTransparency = 1
espRoomsTopRow.LayoutOrder = 0; espRoomsTopRow.ZIndex = 6; espRoomsTopRow.Parent = espRoomsSection

local espRoomsLbl = Instance.new("TextLabel")
espRoomsLbl.Size = UDim2.new(1, -170, 0, 40); espRoomsLbl.Position = UDim2.new(0, 12, 0, 0)
espRoomsLbl.BackgroundTransparency = 1; espRoomsLbl.Text = "ESP Rooms"
espRoomsLbl.TextColor3 = COL_TXT; espRoomsLbl.TextSize = 12
espRoomsLbl.Font = Enum.Font.GothamSemibold; espRoomsLbl.TextXAlignment = Enum.TextXAlignment.Left
espRoomsLbl.ZIndex = 7; espRoomsLbl.Parent = espRoomsTopRow

local roomRenderLbl = Instance.new("TextLabel")
roomRenderLbl.Size = UDim2.new(0, 30, 0, 26); roomRenderLbl.Position = UDim2.new(1, -152, 0, 7)
roomRenderLbl.BackgroundTransparency = 1; roomRenderLbl.Text = "Dist:"
roomRenderLbl.TextColor3 = COL_DIM; roomRenderLbl.TextSize = 10
roomRenderLbl.Font = Enum.Font.Gotham; roomRenderLbl.TextXAlignment = Enum.TextXAlignment.Left
roomRenderLbl.ZIndex = 7; roomRenderLbl.Parent = espRoomsTopRow

local roomRenderInput = Instance.new("TextBox")
roomRenderInput.Size = UDim2.new(0, 52, 0, 22); roomRenderInput.Position = UDim2.new(1, -124, 0, 9)
roomRenderInput.BackgroundColor3 = Color3.fromRGB(28, 28, 36); roomRenderInput.Text = "150"
roomRenderInput.TextColor3 = Color3.fromRGB(220, 220, 232); roomRenderInput.TextSize = 11
roomRenderInput.Font = Enum.Font.Gotham; roomRenderInput.ClearTextOnFocus = false
roomRenderInput.BorderSizePixel = 0; roomRenderInput.ZIndex = 7; roomRenderInput.Parent = espRoomsTopRow
Instance.new("UICorner", roomRenderInput).CornerRadius = UDim.new(0, 5)
local rrS = Instance.new("UIStroke", roomRenderInput)
rrS.Color = Color3.fromRGB(55, 55, 70); rrS.Thickness = 1

local espRoomsBtn = Instance.new("TextButton")
espRoomsBtn.Size = UDim2.new(0, 56, 0, 26); espRoomsBtn.Position = UDim2.new(1, -64, 0, 7)
espRoomsBtn.BackgroundColor3 = COL_OFF; espRoomsBtn.Text = "OFF"
espRoomsBtn.TextColor3 = Color3.fromRGB(180, 180, 192); espRoomsBtn.TextSize = 12
espRoomsBtn.Font = Enum.Font.GothamBold; espRoomsBtn.BorderSizePixel = 0
espRoomsBtn.ZIndex = 7; espRoomsBtn.Parent = espRoomsTopRow
Instance.new("UICorner", espRoomsBtn).CornerRadius = UDim.new(0, 6)

-- Rooms divider
local roomsDiv = Instance.new("Frame")
roomsDiv.Size = UDim2.new(1, -24, 0, 1); roomsDiv.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
roomsDiv.BorderSizePixel = 0; roomsDiv.LayoutOrder = 1; roomsDiv.ZIndex = 7
roomsDiv.Parent = espRoomsSection

-- Per-room toggle rows
for i, def in ipairs(ROOM_DEFS) do
    local roomRow = Instance.new("Frame")
    roomRow.Size = UDim2.new(1, 0, 0, 34); roomRow.BackgroundTransparency = 1
    roomRow.LayoutOrder = i + 1; roomRow.ZIndex = 6; roomRow.Parent = espRoomsSection

    local dangerColor = def.danger
        and Color3.fromRGB(200, 65, 65)
        or  Color3.fromRGB(55, 185, 90)

    local roomNameBtn = Instance.new("TextButton")
    roomNameBtn.Size = UDim2.new(1, -90, 0, 24); roomNameBtn.Position = UDim2.new(0, 10, 0, 5)
    roomNameBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38); roomNameBtn.BorderSizePixel = 0
    roomNameBtn.Text = (def.danger and "⚠ " or "✔ ") .. def.label
    roomNameBtn.TextColor3 = dangerColor; roomNameBtn.TextSize = 11
    roomNameBtn.Font = Enum.Font.GothamSemibold; roomNameBtn.TextXAlignment = Enum.TextXAlignment.Left
    roomNameBtn.ZIndex = 7; roomNameBtn.Parent = roomRow
    Instance.new("UICorner", roomNameBtn).CornerRadius = UDim.new(0, 6)
    local rnPad = Instance.new("UIPadding", roomNameBtn)
    rnPad.PaddingLeft = UDim.new(0, 8)

    local roomToggleBtn = Instance.new("TextButton")
    roomToggleBtn.Size = UDim2.new(0, 52, 0, 24); roomToggleBtn.Position = UDim2.new(1, -62, 0, 5)
    roomToggleBtn.BackgroundColor3 = COL_ON; roomToggleBtn.Text = "ON"
    roomToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255); roomToggleBtn.TextSize = 11
    roomToggleBtn.Font = Enum.Font.GothamBold; roomToggleBtn.BorderSizePixel = 0
    roomToggleBtn.ZIndex = 7; roomToggleBtn.Parent = roomRow
    Instance.new("UICorner", roomToggleBtn).CornerRadius = UDim.new(0, 6)

    local idx = i
    roomToggleBtn.MouseButton1Click:Connect(function()
        ROOM_DEFS[idx].enabled = not ROOM_DEFS[idx].enabled
        if ROOM_DEFS[idx].enabled then
            roomToggleBtn.BackgroundColor3 = COL_ON
            roomToggleBtn.Text = "ON"
            roomToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            roomToggleBtn.BackgroundColor3 = COL_OFF
            roomToggleBtn.Text = "OFF"
            roomToggleBtn.TextColor3 = Color3.fromRGB(180, 180, 192)
        end
    end)
end

local roomsSectionPad = Instance.new("Frame")
roomsSectionPad.Size = UDim2.new(1, 0, 0, 6); roomsSectionPad.BackgroundTransparency = 1
roomsSectionPad.LayoutOrder = #ROOM_DEFS + 3; roomsSectionPad.Parent = espRoomsSection

-- ═══════════════════════════════════════════════════════
-- CONSTANTS & STATE
-- ═══════════════════════════════════════════════════════

local SAFE_POS = Vector3.new(-671, 672, -91)

local autoFarmOn     = false
local autoSellOn     = false
local farmTask       = nil
local itemsCollected = 0

local character = player.Character or player.CharacterAdded:Wait()
local hrp       = character:FindFirstChild("HumanoidRootPart")

local stuckItems    = {}
local lastPos       = nil
local stuckSince    = nil
local STUCK_TIMEOUT = 2.5

local BANNED_ANCESTORS = { "MeatMountain" }
local PRIORITY_NAMES   = { "Watch", "Blueprint" }
local NORMAL_NAMES     = { "Documents", "Document", "EightBall", "Eightball", "Disc" }

-- ═══════════════════════════════════════════════════════
-- FARM HELPERS
-- ═══════════════════════════════════════════════════════

local function isBanned(obj)
    local cur = obj.Parent
    while cur and cur ~= workspace do
        for _, ban in ipairs(BANNED_ANCESTORS) do
            if cur.Name == ban then return true end
        end
        cur = cur.Parent
    end
    return false
end

local function matchesAny(name, list)
    local low = name:lower()
    for _, n in ipairs(list) do
        if low == n:lower() or low:find(n:lower(), 1, true) then return true end
    end
    return false
end

local function resolveBasePart(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model")    then return obj:FindFirstChildWhichIsA("BasePart") end
    return nil
end

local function findFarmItems()
    local priority, normal = {}, {}
    local seenParts = {}

    local function addTo(list, part)
        if seenParts[part] or stuckItems[part] then return end
        seenParts[part] = true
        table.insert(list, part)
    end

    for _, pName in ipairs(PRIORITY_NAMES) do
        local obj = workspace:FindFirstChild(pName)
        if obj then
            local part = resolveBasePart(obj)
            if part and not isBanned(part) then addTo(priority, part) end
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            if parent then
                local part = resolveBasePart(parent)
                if part and not stuckItems[part] and not isBanned(part) then
                    if matchesAny(parent.Name, PRIORITY_NAMES) then addTo(priority, part)
                    elseif matchesAny(parent.Name, NORMAL_NAMES) then addTo(normal, part) end
                end
            end
        elseif obj:IsA("BasePart") or obj:IsA("Model") then
            local part = resolveBasePart(obj)
            if part and not stuckItems[part] and not isBanned(part) then
                if matchesAny(obj.Name, PRIORITY_NAMES) then addTo(priority, part)
                elseif matchesAny(obj.Name, NORMAL_NAMES) then addTo(normal, part) end
            end
        end
    end

    local all = {}
    for _, v in ipairs(priority) do table.insert(all, v) end
    for _, v in ipairs(normal)   do table.insert(all, v) end
    return all
end

local function getClosest()
    if not hrp then return nil, math.huge end
    local items = findFarmItems()
    local best, bestDist = nil, math.huge
    for _, item in ipairs(items) do
        if item and item.Parent then
            local d = (hrp.Position - item.Position).Magnitude
            if d < bestDist then bestDist = d; best = item end
        end
    end
    return best, bestDist
end

local function tpToItem(item)
    if not item or not hrp then return end
    local hum = character:FindFirstChild("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Physics) end
    pcall(function()
        hrp.CFrame = CFrame.new(item.Position + Vector3.new(0, 3, 0))
        hrp.Velocity = Vector3.zero
    end)
    task.wait(0.05)
    if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
end

local function collectItem(item)
    if not item or not item.Parent or not item:IsA("BasePart") then
        stuckItems[item] = true; return false
    end
    local prompt  = item:FindFirstChildWhichIsA("ProximityPrompt")
    local clicker = item:FindFirstChildWhichIsA("ClickDetector")
    if prompt then
        prompt.HoldDuration = 0; prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 100; fireproximityprompt(prompt)
    elseif clicker then
        fireclickdetector(clicker)
    elseif item.CanTouch then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            firetouchinterest(root, item, 0); task.wait(0.04); firetouchinterest(root, item, 1)
        end
    else
        stuckItems[item] = true; return false
    end
    task.wait(0.28)
    return not item.Parent
end

-- ─── Sell ─────────────────────────────────────────────

local function sellAll()
    local remote = nil
    for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name:lower():find("sell") then
            remote = obj; break
        end
    end
    if remote then
        remote:FireServer("sellAll")
        afStatusLbl.Text = "Status: Sold!"
        itemsCollected = 0
    else
        afStatusLbl.Text = "Status: No sell remote"
    end
end

afSellAllBtn.MouseButton1Click:Connect(sellAll)
afAutoSellBtn.MouseButton1Click:Connect(function()
    autoSellOn = not autoSellOn; applyToggleVisual(afAutoSellBtn, autoSellOn)
end)

-- ─── Stuck check ──────────────────────────────────────

local function checkStuck()
    if not hrp then return false end
    local cur = hrp.Position
    if lastPos then
        if (cur - lastPos).Magnitude < 1 then
            if not stuckSince then stuckSince = tick()
            elseif tick() - stuckSince > STUCK_TIMEOUT then return true end
        else stuckSince = nil end
    end
    lastPos = cur
    return false
end

local function startFarming()
    if farmTask then task.cancel(farmTask); farmTask = nil end
    farmTask = task.spawn(function()
        while autoFarmOn do
            character = player.Character
            if not character then task.wait(0.5); continue end
            hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then task.wait(0.5); continue end

            if checkStuck() then
                afStatusLbl.Text = "Status: Unsticking..."
                pcall(function() hrp.CFrame = hrp.CFrame + Vector3.new(0, 12, 0) end)
                task.wait(0.5); lastPos = nil; stuckSince = nil
            end

            local item, dist = getClosest()
            if item then
                afStatusLbl.Text = "Status: Farming " .. item.Name .. " (" .. itemsCollected .. ")"
                if dist > 5 then tpToItem(item); task.wait(0.05) end
                local ok = collectItem(item)
                if ok then
                    itemsCollected = itemsCollected + 1
                    if autoSellOn and itemsCollected >= 10 then
                        afStatusLbl.Text = "Status: Auto-selling..."
                        sellAll(); task.wait(0.5)
                    end
                elseif dist < 3 then
                    stuckItems[item] = true
                end
            else
                afStatusLbl.Text = "Status: No items found (" .. itemsCollected .. " held)"
                task.wait(1)
            end
            task.wait(0.05)
        end
    end)
end

afToggleBtn.MouseButton1Click:Connect(function()
    autoFarmOn = not autoFarmOn; applyToggleVisual(afToggleBtn, autoFarmOn)
    if autoFarmOn then
        stuckItems = {}; afStatusLbl.Text = "Status: Active"; startFarming()
    else
        afStatusLbl.Text = "Status: Idle"
        if farmTask then task.cancel(farmTask); farmTask = nil end
    end
end)

-- TP to Safe
tpSafeBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then pcall(function() root.CFrame = CFrame.new(SAFE_POS) end) end
end)

-- ═══════════════════════════════════════════════════════
-- EASY MODE  (Anchored + Heartbeat — reliable in executor)
-- ═══════════════════════════════════════════════════════

local easyModeOn             = false
local easyModeHPThreshold    = 50
local easyModeParts          = {}   -- { part = Part, conn = RBXScriptConnection }
local easyModeRefreshPending = false

local EASY_TARGETS = {
    {
        find = function()
            local fan = workspace:FindFirstChild("Fan")
            if not fan then return nil end
            return fan:FindFirstChild("Fan_Blade")
        end,
        watchName = "Fan_Blade", watchParentName = "Fan",
    },
    {
        find = function()
            local fan = workspace:FindFirstChild("Fan")
            if not fan then return nil end
            return fan:GetChildren()[36]
        end,
        watchName = nil, watchParentName = "Fan",
    },
    {
        find = function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name == "Tenderizer" then
                    local m = obj:FindFirstChild("Main")
                    if m then return m end
                end
            end
            local ws = workspace:GetChildren()
            local p330 = ws[330]
            if p330 then
                local t = p330:FindFirstChild("Tenderizer")
                if t then return t:FindFirstChild("Main") end
            end
            return nil
        end,
        watchName = "Main", watchParentName = "Tenderizer",
    },
    {
        find = function()
            local pr = workspace:FindFirstChild("PillarRoom1")
            if not pr then return nil end
            local parts = pr:FindFirstChild("Parts")
            if not parts then return nil end
            return parts:FindFirstChild("Floor")
        end,
        watchName = "Floor", watchParentName = "Parts",
    },
}

local function clearEasyModeParts()
    for _, entry in ipairs(easyModeParts) do
        if entry.conn then pcall(function() entry.conn:Disconnect() end) end
        pcall(function()
            if entry.part and entry.part.Parent then entry.part:Destroy() end
        end)
    end
    easyModeParts = {}
end

local function setupEasyModeParts()
    clearEasyModeParts()
    if not easyModeOn then return end

    for _, def in ipairs(EASY_TARGETS) do
        local ok, targetPart = pcall(def.find)
        if not ok or not targetPart then continue end
        if not targetPart:IsA("BasePart") then continue end

        local partOk, ep = pcall(function()
            local p = Instance.new("Part")
            p.Size         = Vector3.new(targetPart.Size.X, targetPart.Size.Y * 2, targetPart.Size.Z)
            p.CFrame       = targetPart.CFrame
            p.Transparency = 1
            p.CanCollide   = false
            p.CanTouch     = true
            p.Anchored     = true
            p.Name         = "_EasyModePart"
            p.Parent       = workspace
            return p
        end)

        if not partOk or not ep then continue end

        -- Heartbeat: keep part snapped to target even as it moves
        local heartConn = RunService.Heartbeat:Connect(function()
            if not ep or not ep.Parent then return end
            if not targetPart or not targetPart.Parent then
                ep:Destroy()
                return
            end
            ep.CFrame = targetPart.CFrame
        end)

        -- Touched: teleport player to safe spot
        local touchConn; touchConn = ep.Touched:Connect(function(hit)
            if not easyModeOn then return end
            local char = player.Character
            if not char then return end
            if not hit:IsDescendantOf(char) then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then pcall(function() root.CFrame = CFrame.new(SAFE_POS) end) end
        end)

        table.insert(easyModeParts, { part = ep, conn = heartConn })
    end
end

local function scheduleEasyModeRefresh()
    if easyModeRefreshPending then return end
    easyModeRefreshPending = true
    task.delay(2, function()
        easyModeRefreshPending = false
        if easyModeOn then setupEasyModeParts() end
    end)
end

workspace.DescendantAdded:Connect(function(desc)
    if not easyModeOn then return end
    local dName = desc.Name
    local pName = desc.Parent and desc.Parent.Name or ""
    for _, def in ipairs(EASY_TARGETS) do
        if (def.watchName and dName == def.watchName) or
           (def.watchParentName and (dName == def.watchParentName or pName == def.watchParentName)) then
            scheduleEasyModeRefresh(); return
        end
    end
end)

workspace.ChildAdded:Connect(function()
    if easyModeOn then scheduleEasyModeRefresh() end
end)

easyModeBtn.MouseButton1Click:Connect(function()
    easyModeOn = not easyModeOn
    applyToggleVisual(easyModeBtn, easyModeOn)
    if easyModeOn then setupEasyModeParts() else clearEasyModeParts() end
end)

easyModeHPInput.FocusLost:Connect(function()
    local v = tonumber(easyModeHPInput.Text)
    if v and v > 0 and v <= 100 then easyModeHPThreshold = v
    else easyModeHPInput.Text = tostring(easyModeHPThreshold) end
end)

-- ═══════════════════════════════════════════════════════
-- HITBOX
-- ═══════════════════════════════════════════════════════

local hitboxOn           = false
local hitboxSize         = 10
local hitboxTransparency = 0.5
local hitboxOriginals    = {}   -- [HumanoidRootPart] = { Size, Transparency, CanCollide }

local function applyHitbox()
    for _, npcName in ipairs(HITBOX_TARGETS) do
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == npcName then
                local npcHRP = obj:FindFirstChild("HumanoidRootPart")
                if npcHRP then
                    if not hitboxOriginals[npcHRP] then
                        hitboxOriginals[npcHRP] = {
                            Size         = npcHRP.Size,
                            Transparency = npcHRP.Transparency,
                            CanCollide   = npcHRP.CanCollide,
                        }
                    end
                    pcall(function()
                        npcHRP.Size         = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                        npcHRP.Transparency = hitboxTransparency
                        npcHRP.CanCollide   = false
                    end)
                end
            end
        end
    end
end

local function restoreHitbox()
    for npcHRP, orig in pairs(hitboxOriginals) do
        pcall(function()
            if npcHRP and npcHRP.Parent then
                npcHRP.Size         = orig.Size
                npcHRP.Transparency = orig.Transparency
                npcHRP.CanCollide   = orig.CanCollide
            end
        end)
    end
    hitboxOriginals = {}
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if hitboxOn then applyHitbox() end
    end
end)

hitboxBtn.MouseButton1Click:Connect(function()
    hitboxOn = not hitboxOn
    applyToggleVisual(hitboxBtn, hitboxOn)
    if not hitboxOn then restoreHitbox() end
end)

hitboxSizeInput.FocusLost:Connect(function()
    local v = tonumber(hitboxSizeInput.Text)
    if v and v > 0 then hitboxSize = v
    else hitboxSizeInput.Text = tostring(hitboxSize) end
end)

hitboxTransInput.FocusLost:Connect(function()
    local v = tonumber(hitboxTransInput.Text)
    if v and v >= 0 and v <= 1 then hitboxTransparency = v
    else hitboxTransInput.Text = tostring(hitboxTransparency) end
end)

-- ═══════════════════════════════════════════════════════
-- ESP STATE
-- ═══════════════════════════════════════════════════════

local espPlayerOn       = false
local espNPCOn          = false
local espItemsOn        = false
local espExitOn         = false
local espRoomsOn        = false
local espPlayerMaxStuds = 200
local roomRenderDist    = 150

espCapInput.FocusLost:Connect(function()
    local v = tonumber(espCapInput.Text)
    if v and v > 0 then espPlayerMaxStuds = v
    else espCapInput.Text = tostring(espPlayerMaxStuds) end
end)

roomRenderInput.FocusLost:Connect(function()
    local v = tonumber(roomRenderInput.Text)
    if v and v > 0 then roomRenderDist = v
    else roomRenderInput.Text = tostring(roomRenderDist) end
end)

local espHL = { players = {}, npcs = {}, items = {}, exits = {} }
local roomESPGuis = {}

local function clearESP(cat)
    for _, h in ipairs(espHL[cat]) do
        if h and h.Parent then h:Destroy() end
    end
    espHL[cat] = {}
end

local function clearRoomESP()
    for _, bb in pairs(roomESPGuis) do
        if bb and bb.Parent then bb:Destroy() end
    end
    roomESPGuis = {}
end

local ITEM_NAMES = { "Watch", "Disc", "Blueprint", "Documents", "EightBall" }

local function nameInListFuzzy(name, list)
    local low = name:lower()
    for _, n in ipairs(list) do
        if low == n:lower() then return true end
    end
    return false
end

local CLOSE_STUD_THRESHOLD = 20

local function playerFillTrans(dist, maxD)
    if dist >= maxD then return 1 end
    if dist <= CLOSE_STUD_THRESHOLD then return 0.90 end
    local t = (dist - CLOSE_STUD_THRESHOLD) / (maxD - CLOSE_STUD_THRESHOLD)
    return 0.80 + 0.20 * t
end

local function playerTextTrans(dist, maxD)
    return math.clamp(playerFillTrans(dist, maxD), 0, 0.9)
end

local function npcFillTrans(dist)
    local t = math.clamp((dist - 5) / 65, 0, 1)
    return t * 0.90
end

-- ═══════════════════════════════════════════════════════
-- ESP UPDATE FUNCTIONS
-- ═══════════════════════════════════════════════════════

local function updatePlayerESP()
    clearESP("players")
    if not espPlayerOn then return end
    local myChar = player.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")

    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        local char = p.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        local dist = (myRoot and root)
            and (myRoot.Position - root.Position).Magnitude or 999
        if dist > espPlayerMaxStuds then continue end

        local ft  = playerFillTrans(dist, espPlayerMaxStuds)
        local ot  = math.clamp(ft + 0.15, 0, 1)
        local txt = playerTextTrans(dist, espPlayerMaxStuds)

        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(55, 115, 255); hl.OutlineColor = Color3.fromRGB(110, 160, 255)
        hl.FillTransparency = ft; hl.OutlineTransparency = ot
        hl.Adornee = char; hl.Parent = char
        table.insert(espHL.players, hl)

        local adornee = root or char:FindFirstChildWhichIsA("BasePart")
        if not adornee then continue end

        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 150, 0, 48); bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true; bb.Adornee = adornee; bb.Parent = char
        table.insert(espHL.players, bb)

        local tool = char:FindFirstChildWhichIsA("Tool")
        if tool then
            local itemLbl = Instance.new("TextLabel")
            itemLbl.Size = UDim2.new(1, 0, 0.5, 0); itemLbl.BackgroundTransparency = 1
            itemLbl.Text = "[" .. tool.Name .. "]"; itemLbl.TextColor3 = Color3.fromRGB(195, 218, 255)
            itemLbl.TextSize = 11; itemLbl.Font = Enum.Font.Gotham
            itemLbl.TextStrokeTransparency = 0.4; itemLbl.TextTransparency = txt
            itemLbl.Parent = bb
        end

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, 0, 0.5, 0)
        nameLbl.Position = UDim2.new(0, 0, tool and 0.5 or 0.25, 0)
        nameLbl.BackgroundTransparency = 1; nameLbl.Text = p.Name
        nameLbl.TextColor3 = Color3.fromRGB(140, 185, 255); nameLbl.TextSize = 13
        nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextStrokeTransparency = 0.4
        nameLbl.TextTransparency = txt; nameLbl.Parent = bb
    end
end

local function updateNPCESP()
    clearESP("npcs")
    if not espNPCOn then return end
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, obj in ipairs(workspace:GetDescendants()) do
        if not obj:IsA("Model") then continue end
        for _, def in ipairs(NPC_DEFS) do
            if obj.Name == def.name and def.enabled then
                local npcRoot = obj:FindFirstChild("HumanoidRootPart") or
                                obj:FindFirstChildWhichIsA("BasePart")
                local dist = (myRoot and npcRoot)
                    and (myRoot.Position - npcRoot.Position).Magnitude or 0
                if dist > def.renderDist then continue end

                local ft = npcFillTrans(dist)
                local hl = Instance.new("Highlight")
                hl.FillColor = Color3.fromRGB(215, 45, 45); hl.OutlineColor = Color3.fromRGB(255, 75, 75)
                hl.FillTransparency = ft; hl.OutlineTransparency = math.max(0, ft - 0.12)
                hl.Adornee = obj; hl.Parent = obj
                table.insert(espHL.npcs, hl)
            end
        end
    end
end

local function updateItemESP()
    clearESP("items")
    if not espItemsOn then return end
    local seen = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if seen[obj] then continue end
        if nameInListFuzzy(obj.Name, ITEM_NAMES) then
            local adornee = (obj:IsA("BasePart") or obj:IsA("Model")) and obj or nil
            if adornee and not seen[adornee] then
                seen[adornee] = true
                local hl = Instance.new("Highlight")
                hl.FillColor = Color3.fromRGB(45, 195, 75); hl.OutlineColor = Color3.fromRGB(75, 255, 100)
                hl.FillTransparency = 0.30; hl.OutlineTransparency = 0
                hl.Adornee = adornee; hl.Parent = adornee
                table.insert(espHL.items, hl)
            end
        end
    end
end

local function updateExitESP()
    clearESP("exits")
    if not espExitOn then return end
    local elevRoom = workspace:FindFirstChild("ElevatorRoom1")
    if not elevRoom then return end
    for _, obj in ipairs(elevRoom:GetChildren()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local hl = Instance.new("Highlight")
            hl.FillColor = Color3.fromRGB(45, 215, 100); hl.OutlineColor = Color3.fromRGB(75, 255, 130)
            hl.FillTransparency = 0.32; hl.OutlineTransparency = 0
            hl.Adornee = obj; hl.Parent = obj
            table.insert(espHL.exits, hl)
        end
    end
end

local function updateRoomESP()
    if not espRoomsOn then
        clearRoomESP(); return
    end
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, def in ipairs(ROOM_DEFS) do
        -- Remove if disabled
        if not def.enabled then
            if roomESPGuis[def.name] then
                roomESPGuis[def.name]:Destroy()
                roomESPGuis[def.name] = nil
            end
            continue
        end

        local roomModel = workspace:FindFirstChild(def.name)
        if not roomModel then
            if roomESPGuis[def.name] then
                roomESPGuis[def.name]:Destroy()
                roomESPGuis[def.name] = nil
            end
            continue
        end

        -- Find adornee part within the room model
        local adornee = nil
        if roomModel:IsA("BasePart") then
            adornee = roomModel
        elseif roomModel:IsA("Model") then
            adornee = roomModel.PrimaryPart or roomModel:FindFirstChildWhichIsA("BasePart", true)
        end
        if not adornee then continue end

        local dist = myRoot and (myRoot.Position - adornee.Position).Magnitude or 9999

        -- Beyond render distance — hide
        if dist > roomRenderDist then
            if roomESPGuis[def.name] then roomESPGuis[def.name].Enabled = false end
            continue
        end

        -- Opacity: fade out within 60 studs (closer = more transparent)
        local textTrans = 0
        if dist < 60 then
            textTrans = 1 - (dist / 60)  -- 0 at 60 studs, 1 at 0 studs
        end

        -- Create billboard if needed (or if adornee changed after map reload)
        local bb = roomESPGuis[def.name]
        if not bb or not bb.Parent or bb.Adornee ~= adornee then
            if bb then pcall(function() bb:Destroy() end) end
            bb = Instance.new("BillboardGui")
            bb.Size        = UDim2.new(0, 140, 0, 44)
            bb.StudsOffset = Vector3.new(0, 8, 0)
            bb.AlwaysOnTop = true
            bb.Adornee     = adornee
            bb.Parent      = adornee

            local lbl = Instance.new("TextLabel")
            lbl.Name               = "Label"
            lbl.Size               = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font               = Enum.Font.GothamBold
            lbl.TextSize           = 14
            lbl.TextStrokeTransparency = 0.3
            lbl.TextWrapped        = true
            lbl.Parent             = bb

            roomESPGuis[def.name] = bb
        end

        bb.Enabled = true
        local lbl = bb:FindFirstChild("Label")
        if lbl then
            local color = def.danger
                and Color3.fromRGB(255, 80, 80)
                or  Color3.fromRGB(80, 255, 120)
            lbl.TextColor3       = color
            lbl.Text             = def.label .. "\n" .. math.floor(dist) .. " studs"
            lbl.TextTransparency = textTrans
        end
    end
end

-- ESP toggle buttons
espPlayerBtn.MouseButton1Click:Connect(function()
    espPlayerOn = not espPlayerOn; applyToggleVisual(espPlayerBtn, espPlayerOn)
    if not espPlayerOn then clearESP("players") end
end)

espNPCBtn.MouseButton1Click:Connect(function()
    espNPCOn = not espNPCOn; applyToggleVisual(espNPCBtn, espNPCOn)
    if not espNPCOn then clearESP("npcs") end
end)

espItemsBtn.MouseButton1Click:Connect(function()
    espItemsOn = not espItemsOn; applyToggleVisual(espItemsBtn, espItemsOn)
    if not espItemsOn then clearESP("items") end
end)

espExitBtn.MouseButton1Click:Connect(function()
    espExitOn = not espExitOn; applyToggleVisual(espExitBtn, espExitOn)
    if not espExitOn then clearESP("exits") end
end)

espRoomsBtn.MouseButton1Click:Connect(function()
    espRoomsOn = not espRoomsOn; applyToggleVisual(espRoomsBtn, espRoomsOn)
    if not espRoomsOn then clearRoomESP() end
end)

-- ─── Staggered ESP loop (prevents frame spikes) ───────
task.spawn(function()
    local cycle = 0
    while true do
        cycle = cycle + 1

        if espPlayerOn  then updatePlayerESP(); task.wait(0.04) end

        -- Heavier scans every other cycle
        if cycle % 2 == 0 then
            if espNPCOn   then updateNPCESP();   task.wait(0.04) end
            if espItemsOn then updateItemESP();  task.wait(0.04) end
            if espExitOn  then updateExitESP();  task.wait(0.04) end
            if espRoomsOn then updateRoomESP();  task.wait(0.04) end
        end

        task.wait(1.2)
    end
end)

-- ═══════════════════════════════════════════════════════
-- ANTI DEATH SECTION  (pinned at bottom of menu)
-- ═══════════════════════════════════════════════════════

local adSection = Instance.new("Frame")
adSection.Size = UDim2.new(1, -24, 0, 72); adSection.Position = UDim2.new(0, 12, 1, -84)
adSection.BackgroundColor3 = Color3.fromRGB(20, 20, 26); adSection.BorderSizePixel = 0
adSection.ZIndex = 5; adSection.Parent = mainMenu
Instance.new("UICorner", adSection).CornerRadius = UDim.new(0, 8)
local adStroke = Instance.new("UIStroke", adSection)
adStroke.Color = Color3.fromRGB(50, 50, 62); adStroke.Thickness = 1

local adLabel = Instance.new("TextLabel")
adLabel.Size = UDim2.new(0.55, 0, 0, 36); adLabel.Position = UDim2.new(0, 12, 0, 4)
adLabel.BackgroundTransparency = 1; adLabel.Text = "Anti Death"
adLabel.TextColor3 = COL_TXT; adLabel.TextSize = 13; adLabel.Font = Enum.Font.GothamSemibold
adLabel.TextXAlignment = Enum.TextXAlignment.Left; adLabel.ZIndex = 6; adLabel.Parent = adSection

local antiDeathOn = false
local adToggle = Instance.new("TextButton")
adToggle.Size = UDim2.new(0, 56, 0, 26); adToggle.Position = UDim2.new(1, -64, 0, 10)
adToggle.BackgroundColor3 = COL_OFF; adToggle.Text = "OFF"
adToggle.TextColor3 = Color3.fromRGB(180, 180, 192); adToggle.TextSize = 12
adToggle.Font = Enum.Font.GothamBold; adToggle.BorderSizePixel = 0
adToggle.ZIndex = 6; adToggle.Parent = adSection
Instance.new("UICorner", adToggle).CornerRadius = UDim.new(0, 6)
adToggle.MouseButton1Click:Connect(function()
    antiDeathOn = not antiDeathOn; applyToggleVisual(adToggle, antiDeathOn)
end)

local tpRowLabel = Instance.new("TextLabel")
tpRowLabel.Size = UDim2.new(0.55, 0, 0, 26); tpRowLabel.Position = UDim2.new(0, 12, 0, 42)
tpRowLabel.BackgroundTransparency = 1; tpRowLabel.Text = "TP at HP ≤"
tpRowLabel.TextColor3 = COL_DIM; tpRowLabel.TextSize = 11; tpRowLabel.Font = Enum.Font.Gotham
tpRowLabel.TextXAlignment = Enum.TextXAlignment.Left; tpRowLabel.ZIndex = 6; tpRowLabel.Parent = adSection

local tpThreshold = 20
local tpInput = Instance.new("TextBox")
tpInput.Size = UDim2.new(0, 76, 0, 22); tpInput.Position = UDim2.new(1, -86, 0, 46)
tpInput.BackgroundColor3 = Color3.fromRGB(28, 28, 36); tpInput.Text = "20"
tpInput.TextColor3 = Color3.fromRGB(220, 220, 232); tpInput.TextSize = 11
tpInput.Font = Enum.Font.Gotham; tpInput.ClearTextOnFocus = false; tpInput.BorderSizePixel = 0
tpInput.PlaceholderText = "HP"; tpInput.ZIndex = 6; tpInput.Parent = adSection
Instance.new("UICorner", tpInput).CornerRadius = UDim.new(0, 5)
local tpStroke = Instance.new("UIStroke", tpInput)
tpStroke.Color = Color3.fromRGB(55, 55, 70); tpStroke.Thickness = 1

tpInput.FocusLost:Connect(function()
    local v = tonumber(tpInput.Text)
    if v then tpThreshold = v else tpInput.Text = tostring(tpThreshold) end
end)

-- ─── Combined HP monitor (Anti Death + Easy Mode HP) ──
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = player.Character
        if char then
            local hum  = char:FindFirstChild("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                if antiDeathOn and hum.Health <= tpThreshold then
                    pcall(function() root.CFrame = CFrame.new(SAFE_POS) end)
                elseif easyModeOn and easyModeHPThreshold > 0
                       and hum.Health <= easyModeHPThreshold then
                    pcall(function() root.CFrame = CFrame.new(SAFE_POS) end)
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════
-- SIDEBAR SWITCHING
-- ═══════════════════════════════════════════════════════

local function switchCategory(cat)
    local isAF = (cat == "af")
    afPanel.Visible  = isAF
    espPanel.Visible = not isAF

    -- Reset sidebar button states
    for _, btn in pairs(sidebarBtns) do
        btn.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
        btn.TextColor3       = Color3.fromRGB(145, 145, 158)
    end

    local activeBtn = isAF and catAFBtn or catESPBtn
    activeBtn.BackgroundColor3 = Color3.fromRGB(38, 50, 72)
    activeBtn.TextColor3       = Color3.fromRGB(200, 218, 255)
end

catAFBtn.MouseButton1Click:Connect(function()  switchCategory("af")  end)
catESPBtn.MouseButton1Click:Connect(function() switchCategory("esp") end)
switchCategory("af")

-- ═══════════════════════════════════════════════════════
-- TOGGLE BUTTON — open/close menu (tap or keybind B)
-- ═══════════════════════════════════════════════════════

local menuOpen     = false
local tbDragOrigin = nil
local tbDragMoved  = false

toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        tbDragOrigin = input.Position; tbDragMoved = false
    end
end)

toggleBtn.InputChanged:Connect(function(input)
    if tbDragOrigin and (
        input.UserInputType == Enum.UserInputType.MouseMovement or
        input.UserInputType == Enum.UserInputType.Touch
    ) then
        if (input.Position - tbDragOrigin).Magnitude > 6 then tbDragMoved = true end
    end
end)

toggleBtn.MouseButton1Click:Connect(function()
    if not tbDragMoved then
        menuOpen = not menuOpen; mainMenu.Visible = menuOpen
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.B then
        menuOpen = not menuOpen; mainMenu.Visible = menuOpen
    end
end)

-- ═══════════════════════════════════════════════════════
-- CHARACTER RESPAWN
-- ═══════════════════════════════════════════════════════

player.CharacterAdded:Connect(function(newChar)
    character  = newChar
    task.wait(0.5)
    hrp        = character:FindFirstChild("HumanoidRootPart")
    lastPos    = nil; stuckSince = nil
    if autoFarmOn then
        stuckItems = {}; startFarming()
    end
    if hitboxOn then
        hitboxOriginals = {}
    end
    if easyModeOn then
        task.wait(0.5); setupEasyModeParts()
    end
end)
