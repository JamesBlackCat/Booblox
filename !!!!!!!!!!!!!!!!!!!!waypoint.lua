--[[
    Waypoint Manager
    Executor LocalScript
    
    Features:
    - Draggable toggle button (PC + Mobile)
    - Double-B keybind to toggle menu
    - Game entry tabs with waypoints
    - 3D BillboardGui waypoints with fade logic
    - Settings: fade distances, opacity, font, color picker
    - Minimize / Close (with confirmation)
    - Persistence via writefile/readfile (JSON)
    - Waypoints load as OFF by default each session
--]]

-- ══════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera    = workspace.CurrentCamera

-- ══════════════════════════════════════════
--  CONSTANTS
-- ══════════════════════════════════════════
local SAVE_FILE       = "WaypointManager_Data.json"
local DOUBLE_B_WINDOW = 0.35   -- seconds between two B presses

local COLORS = {
    bg          = Color3.fromRGB(18,  18,  26),
    panel       = Color3.fromRGB(26,  26,  36),
    titlebar    = Color3.fromRGB(30,  30,  44),
    item        = Color3.fromRGB(34,  34,  48),
    itemHover   = Color3.fromRGB(44,  44,  60),
    accent      = Color3.fromRGB(88,  138, 255),
    accentDark  = Color3.fromRGB(60,  100, 210),
    danger      = Color3.fromRGB(220, 70,  70),
    text        = Color3.new(1, 1, 1),
    subtext     = Color3.fromRGB(160, 160, 185),
    stroke      = Color3.fromRGB(60,  60,  85),
    scrollbar   = Color3.fromRGB(80,  80,  110),
    toggle_on   = Color3.fromRGB(80,  200, 120),
    toggle_off  = Color3.fromRGB(70,  70,  90),
}

local FONTS = {
    "GothamBold", "Gotham", "GothamMedium",
    "Arial", "ArialBold",
    "SourceSans", "SourceSansBold",
    "RobotoMono",
    "Code",
    "Nunito",
    "Antique",
}

-- ══════════════════════════════════════════
--  DEFAULT SETTINGS
-- ══════════════════════════════════════════
local DefaultSettings = {
    fadeStudDistance        = 300,
    fadeNameDistance        = 300,
    fadeClosingDistance     = 8,
    fadeClosingNameDistance = 8,
    maxOpacity              = 1.0,
    font                    = "GothamBold",
    colorR                  = 1.0,
    colorG                  = 1.0,
    colorB                  = 1.0,
}

-- ══════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════
local Settings       = {}
local Games          = {}   -- [{name, waypoints=[{name,x,y,z,enabled}]}]
local ActiveBills    = {}   -- "gI_wI" -> BillboardGui
local MenuOpen       = false
local Minimized      = false
local CurrentPage    = "main"   -- "main" | "waypoints" | "settings"
local CurrentGameIdx = nil
local lastBPress     = 0

-- ══════════════════════════════════════════
--  PERSISTENCE
-- ══════════════════════════════════════════
local function saveData()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, {
        settings = Settings,
        games    = Games,
    })
    if ok then pcall(writefile, SAVE_FILE, encoded) end
end

local function loadData()
    local ok, raw = pcall(readfile, SAVE_FILE)
    if ok and raw and raw ~= "" then
        local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok2 and data then
            Settings = data.settings or {}
            Games    = data.games    or {}
        end
    end
    for k, v in pairs(DefaultSettings) do
        if Settings[k] == nil then Settings[k] = v end
    end
    -- Always load waypoints as OFF
    for _, g in ipairs(Games) do
        for _, wp in ipairs(g.waypoints or {}) do
            wp.enabled = false
        end
    end
end

loadData()

-- ══════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════
local function corner(r, parent)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    if parent then c.Parent = parent end
    return c
end

local function stroke(thickness, color, parent)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness
    s.Color     = color or COLORS.stroke
    if parent then s.Parent = parent end
    return s
end

local function padding(t, b, l, r, parent)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    if parent then p.Parent = parent end
    return p
end

local function listLayout(pad, parent)
    local l = Instance.new("UIListLayout")
    l.Padding    = UDim.new(0, pad or 6)
    l.SortOrder  = Enum.SortOrder.LayoutOrder
    l.FillDirection = Enum.FillDirection.Vertical
    if parent then l.Parent = parent end
    return l
end

local function scrollFrame(parent, yOffset)
    local s = Instance.new("ScrollingFrame")
    s.Size                 = UDim2.new(1, 0, 1, -(yOffset or 0))
    s.Position             = UDim2.new(0, 0, 0, yOffset or 0)
    s.BackgroundTransparency = 1
    s.BorderSizePixel      = 0
    s.ScrollBarThickness   = 4
    s.ScrollBarImageColor3 = COLORS.scrollbar
    s.CanvasSize           = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    s.ScrollingDirection   = Enum.ScrollingDirection.Y
    if parent then s.Parent = parent end
    return s
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (
            inp.UserInputType == Enum.UserInputType.MouseMovement or
            inp.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = inp.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function tween(obj, props, t, style, dir)
    TweenService:Create(obj,
        TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

local function getWpKey(gi, wi) return tostring(gi) .. "_" .. tostring(wi) end

local function getFont()
    local ok, f = pcall(function() return Enum.Font[Settings.font] end)
    return ok and f or Enum.Font.GothamBold
end

local function getColor()
    return Color3.new(Settings.colorR, Settings.colorG, Settings.colorB)
end

-- ══════════════════════════════════════════
--  SCREEN GUI
-- ══════════════════════════════════════════
-- Remove existing instance if re-executed
if PlayerGui:FindFirstChild("WaypointManager") then
    PlayerGui:FindFirstChild("WaypointManager"):Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name              = "WaypointManager"
Gui.ResetOnSpawn      = false
Gui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
Gui.DisplayOrder      = 999
Gui.IgnoreGuiInset    = true
Gui.Parent            = PlayerGui

-- ══════════════════════════════════════════
--  TOGGLE BUTTON
-- ══════════════════════════════════════════
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name            = "ToggleBtn"
ToggleBtn.Text            = "📍"
ToggleBtn.Size            = UDim2.new(0, 52, 0, 52)
ToggleBtn.Position        = UDim2.new(0, 20, 0.5, -26)
ToggleBtn.BackgroundColor3 = COLORS.panel
ToggleBtn.TextColor3      = COLORS.text
ToggleBtn.Font            = Enum.Font.GothamBold
ToggleBtn.TextSize        = 24
ToggleBtn.ZIndex          = 10
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent          = Gui
corner(14, ToggleBtn)
stroke(1.5, COLORS.stroke, ToggleBtn)
makeDraggable(ToggleBtn)

-- ══════════════════════════════════════════
--  MAIN MENU FRAME
-- ══════════════════════════════════════════
local Menu = Instance.new("Frame")
Menu.Name               = "Menu"
Menu.Size               = UDim2.new(0.40, 0, 0.56, 0)
Menu.Position           = UDim2.new(0.30, 0, 0.22, 0)
Menu.BackgroundColor3   = COLORS.bg
Menu.BorderSizePixel    = 0
Menu.Visible            = false
Menu.ZIndex             = 5
Menu.Parent             = Gui
corner(12, Menu)
stroke(1.5, COLORS.stroke, Menu)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name             = "TitleBar"
TitleBar.Size             = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = COLORS.titlebar
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 6
TitleBar.Parent           = Menu
corner(12, TitleBar)

-- Patch bottom corners of title bar
local tbPatch = Instance.new("Frame")
tbPatch.Size            = UDim2.new(1, 0, 0.5, 0)
tbPatch.Position        = UDim2.new(0, 0, 0.5, 0)
tbPatch.BackgroundColor3 = COLORS.titlebar
tbPatch.BorderSizePixel = 0
tbPatch.ZIndex          = 6
tbPatch.Parent          = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text              = "  📍 Waypoint Manager"
TitleLabel.TextSize          = 13
TitleLabel.Font              = Enum.Font.GothamBold
TitleLabel.TextColor3        = COLORS.text
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size              = UDim2.new(1, -115, 1, 0)
TitleLabel.TextXAlignment    = Enum.TextXAlignment.Left
TitleLabel.ZIndex            = 7
TitleLabel.Parent            = TitleBar

makeDraggable(Menu, TitleBar)

-- Title bar icon buttons
local function makeTitleIconBtn(icon, rightOffset)
    local b = Instance.new("TextButton")
    b.Text            = icon
    b.Size            = UDim2.new(0, 28, 0, 28)
    b.Position        = UDim2.new(1, rightOffset, 0.5, -14)
    b.BackgroundColor3 = COLORS.item
    b.TextColor3      = COLORS.text
    b.Font            = Enum.Font.GothamBold
    b.TextSize        = 12
    b.ZIndex          = 8
    b.AutoButtonColor = true
    b.Parent          = TitleBar
    corner(7, b)
    return b
end

local BtnClose    = makeTitleIconBtn("✕", -8)
local BtnMinimize = makeTitleIconBtn("─", -40)
local BtnSettings = makeTitleIconBtn("⚙", -72)
local BtnBack     = makeTitleIconBtn("←", -104)
BtnBack.Visible   = false

-- Content area (lives below title bar)
local Content = Instance.new("Frame")
Content.Name               = "Content"
Content.Size               = UDim2.new(1, -14, 1, -50)
Content.Position           = UDim2.new(0, 7, 0, 46)
Content.BackgroundTransparency = 1
Content.ZIndex             = 6
Content.ClipsDescendants   = true
Content.Parent             = Menu

-- ══════════════════════════════════════════
--  PAGE: MAIN (Game List)
-- ══════════════════════════════════════════
local PageMain = Instance.new("Frame")
PageMain.Name               = "PageMain"
PageMain.Size               = UDim2.new(1, 0, 1, 0)
PageMain.BackgroundTransparency = 1
PageMain.ZIndex             = 6
PageMain.Parent             = Content

-- Search bar row
local SearchRow = Instance.new("Frame")
SearchRow.Size              = UDim2.new(1, 0, 0, 34)
SearchRow.BackgroundTransparency = 1
SearchRow.ZIndex            = 7
SearchRow.Parent            = PageMain

local SearchBox = Instance.new("TextBox")
SearchBox.PlaceholderText   = "🔍  Search games..."
SearchBox.Text              = ""
SearchBox.Size              = UDim2.new(1, -42, 1, 0)
SearchBox.BackgroundColor3  = COLORS.item
SearchBox.TextColor3        = COLORS.text
SearchBox.PlaceholderColor3 = COLORS.subtext
SearchBox.Font              = Enum.Font.Gotham
SearchBox.TextSize          = 12
SearchBox.ClearTextOnFocus  = false
SearchBox.ZIndex            = 7
SearchBox.Parent            = SearchRow
corner(8, SearchBox)
padding(0, 0, 10, 0, SearchBox)

local AddGameBtn = Instance.new("TextButton")
AddGameBtn.Text             = "+"
AddGameBtn.Size             = UDim2.new(0, 34, 1, 0)
AddGameBtn.Position         = UDim2.new(1, -34, 0, 0)
AddGameBtn.BackgroundColor3 = COLORS.accent
AddGameBtn.TextColor3       = COLORS.text
AddGameBtn.Font             = Enum.Font.GothamBold
AddGameBtn.TextSize         = 22
AddGameBtn.ZIndex           = 7
AddGameBtn.AutoButtonColor  = true
AddGameBtn.Parent           = SearchRow
corner(8, AddGameBtn)

local GameScroll = scrollFrame(PageMain, 40)
GameScroll.ZIndex = 6
listLayout(6, GameScroll)

-- ══════════════════════════════════════════
--  PAGE: WAYPOINTS
-- ══════════════════════════════════════════
local PageWaypoints = Instance.new("Frame")
PageWaypoints.Name               = "PageWaypoints"
PageWaypoints.Size               = UDim2.new(1, 0, 1, 0)
PageWaypoints.BackgroundTransparency = 1
PageWaypoints.Visible            = false
PageWaypoints.ZIndex             = 6
PageWaypoints.Parent             = Content

local WPTitleLabel = Instance.new("TextLabel")
WPTitleLabel.Text               = "Waypoints"
WPTitleLabel.Size               = UDim2.new(1, 0, 0, 28)
WPTitleLabel.BackgroundTransparency = 1
WPTitleLabel.TextColor3         = COLORS.text
WPTitleLabel.Font               = Enum.Font.GothamBold
WPTitleLabel.TextSize           = 13
WPTitleLabel.TextXAlignment     = Enum.TextXAlignment.Left
WPTitleLabel.ZIndex             = 7
WPTitleLabel.Parent             = PageWaypoints

local AddWPBtn = Instance.new("TextButton")
AddWPBtn.Text             = "+ Add Waypoint"
AddWPBtn.Size             = UDim2.new(1, 0, 0, 30)
AddWPBtn.Position         = UDim2.new(0, 0, 0, 32)
AddWPBtn.BackgroundColor3 = COLORS.accent
AddWPBtn.TextColor3       = COLORS.text
AddWPBtn.Font             = Enum.Font.GothamBold
AddWPBtn.TextSize         = 12
AddWPBtn.ZIndex           = 7
AddWPBtn.AutoButtonColor  = true
AddWPBtn.Parent           = PageWaypoints
corner(8, AddWPBtn)

local WPScroll = scrollFrame(PageWaypoints, 68)
WPScroll.ZIndex = 6
listLayout(6, WPScroll)

-- ══════════════════════════════════════════
--  PAGE: SETTINGS
-- ══════════════════════════════════════════
local PageSettings = Instance.new("Frame")
PageSettings.Name               = "PageSettings"
PageSettings.Size               = UDim2.new(1, 0, 1, 0)
PageSettings.BackgroundTransparency = 1
PageSettings.Visible            = false
PageSettings.ZIndex             = 6
PageSettings.Parent             = Content

local SettingsScroll = scrollFrame(PageSettings, 0)
SettingsScroll.ZIndex = 6
local SettingsLayout = listLayout(10, SettingsScroll)
padding(4, 8, 0, 0, SettingsScroll)

-- ══════════════════════════════════════════
--  MODAL OVERLAY
-- ══════════════════════════════════════════
local Overlay = Instance.new("Frame")
Overlay.Name               = "Overlay"
Overlay.Size               = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3   = Color3.new(0, 0, 0)
Overlay.BackgroundTransparency = 0.5
Overlay.Visible            = false
Overlay.ZIndex             = 20
Overlay.Parent             = Gui

local Modal = Instance.new("Frame")
Modal.Name               = "Modal"
Modal.Size               = UDim2.new(0, 280, 0, 160)
Modal.Position           = UDim2.new(0.5, -140, 0.5, -80)
Modal.BackgroundColor3   = COLORS.panel
Modal.BorderSizePixel    = 0
Modal.ZIndex             = 21
Modal.Parent             = Gui
Modal.Visible            = false
corner(12, Modal)
stroke(1.5, COLORS.stroke, Modal)

local ModalTitle = Instance.new("TextLabel")
ModalTitle.Text              = "Title"
ModalTitle.Size              = UDim2.new(1, -16, 0, 36)
ModalTitle.Position          = UDim2.new(0, 8, 0, 8)
ModalTitle.BackgroundTransparency = 1
ModalTitle.TextColor3        = COLORS.text
ModalTitle.Font              = Enum.Font.GothamBold
ModalTitle.TextSize          = 14
ModalTitle.TextXAlignment    = Enum.TextXAlignment.Left
ModalTitle.ZIndex            = 22
ModalTitle.Parent            = Modal

local ModalInput = Instance.new("TextBox")
ModalInput.PlaceholderText  = ""
ModalInput.Text             = ""
ModalInput.Size             = UDim2.new(1, -16, 0, 32)
ModalInput.Position         = UDim2.new(0, 8, 0, 50)
ModalInput.BackgroundColor3 = COLORS.item
ModalInput.TextColor3       = COLORS.text
ModalInput.PlaceholderColor3 = COLORS.subtext
ModalInput.Font             = Enum.Font.Gotham
ModalInput.TextSize         = 12
ModalInput.ZIndex           = 22
ModalInput.Parent           = Modal
corner(8, ModalInput)
padding(0, 0, 10, 0, ModalInput)

local ModalConfirmBtn = Instance.new("TextButton")
ModalConfirmBtn.Text            = "Confirm"
ModalConfirmBtn.Size            = UDim2.new(0.48, 0, 0, 30)
ModalConfirmBtn.Position        = UDim2.new(0.52, 0, 1, -38)
ModalConfirmBtn.BackgroundColor3 = COLORS.accent
ModalConfirmBtn.TextColor3      = COLORS.text
ModalConfirmBtn.Font            = Enum.Font.GothamBold
ModalConfirmBtn.TextSize        = 12
ModalConfirmBtn.ZIndex          = 22
ModalConfirmBtn.AutoButtonColor = true
ModalConfirmBtn.Parent          = Modal
corner(8, ModalConfirmBtn)

local ModalCancelBtn = Instance.new("TextButton")
ModalCancelBtn.Text             = "Cancel"
ModalCancelBtn.Size             = UDim2.new(0.48, 0, 0, 30)
ModalCancelBtn.Position         = UDim2.new(0, 0, 1, -38)
ModalCancelBtn.BackgroundColor3 = COLORS.item
ModalCancelBtn.TextColor3       = COLORS.text
ModalCancelBtn.Font             = Enum.Font.GothamBold
ModalCancelBtn.TextSize         = 12
ModalCancelBtn.ZIndex           = 22
ModalCancelBtn.AutoButtonColor  = true
ModalCancelBtn.Parent           = Modal
corner(8, ModalCancelBtn)

-- ══════════════════════════════════════════
--  CONTEXT MENU (Three-dot popup)
-- ══════════════════════════════════════════
local CtxMenu = Instance.new("Frame")
CtxMenu.Name               = "CtxMenu"
CtxMenu.Size               = UDim2.new(0, 130, 0, 70)
CtxMenu.BackgroundColor3   = COLORS.panel
CtxMenu.BorderSizePixel    = 0
CtxMenu.Visible            = false
CtxMenu.ZIndex             = 30
CtxMenu.Parent             = Gui
corner(8, CtxMenu)
stroke(1.5, COLORS.stroke, CtxMenu)
listLayout(0, CtxMenu)

local function makeCtxItem(text, color)
    local b = Instance.new("TextButton")
    b.Text             = text
    b.Size             = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = COLORS.panel
    b.TextColor3       = color or COLORS.text
    b.Font             = Enum.Font.Gotham
    b.TextSize         = 12
    b.ZIndex           = 31
    b.AutoButtonColor  = true
    b.Parent           = CtxMenu
    padding(0, 0, 12, 0, b)
    b.TextXAlignment = Enum.TextXAlignment.Left
    return b
end

local CtxRename = makeCtxItem("✏  Rename")
local CtxDelete = makeCtxItem("🗑  Delete", COLORS.danger)

-- Close ctx when clicking elsewhere
local function closeCtx()
    CtxMenu.Visible = false
end

-- ══════════════════════════════════════════
--  CONFIRM DIALOG (separate from modal for close)
-- ══════════════════════════════════════════
local ConfirmOverlay = Instance.new("Frame")
ConfirmOverlay.Size               = UDim2.new(1, 0, 1, 0)
ConfirmOverlay.BackgroundColor3   = Color3.new(0, 0, 0)
ConfirmOverlay.BackgroundTransparency = 0.45
ConfirmOverlay.Visible            = false
ConfirmOverlay.ZIndex             = 40
ConfirmOverlay.Parent             = Gui

local ConfirmBox = Instance.new("Frame")
ConfirmBox.Size             = UDim2.new(0, 290, 0, 140)
ConfirmBox.Position         = UDim2.new(0.5, -145, 0.5, -70)
ConfirmBox.BackgroundColor3 = COLORS.panel
ConfirmBox.BorderSizePixel  = 0
ConfirmBox.ZIndex           = 41
ConfirmBox.Parent           = Gui
ConfirmBox.Visible          = false
corner(12, ConfirmBox)
stroke(1.5, COLORS.stroke, ConfirmBox)

local ConfirmMsg = Instance.new("TextLabel")
ConfirmMsg.Text              = "Are you sure you want to close?\nAll active waypoints will be turned off."
ConfirmMsg.Size              = UDim2.new(1, -20, 0, 70)
ConfirmMsg.Position          = UDim2.new(0, 10, 0, 12)
ConfirmMsg.BackgroundTransparency = 1
ConfirmMsg.TextColor3        = COLORS.text
ConfirmMsg.Font              = Enum.Font.Gotham
ConfirmMsg.TextSize          = 12
ConfirmMsg.TextWrapped       = true
ConfirmMsg.ZIndex            = 42
ConfirmMsg.Parent            = ConfirmBox

local ConfirmYes = Instance.new("TextButton")
ConfirmYes.Text             = "Close Script"
ConfirmYes.Size             = UDim2.new(0.48, 0, 0, 30)
ConfirmYes.Position         = UDim2.new(0.52, 0, 1, -38)
ConfirmYes.BackgroundColor3 = COLORS.danger
ConfirmYes.TextColor3       = COLORS.text
ConfirmYes.Font             = Enum.Font.GothamBold
ConfirmYes.TextSize         = 12
ConfirmYes.ZIndex           = 42
ConfirmYes.AutoButtonColor  = true
ConfirmYes.Parent           = ConfirmBox
corner(8, ConfirmYes)

local ConfirmNo = Instance.new("TextButton")
ConfirmNo.Text              = "Cancel"
ConfirmNo.Size              = UDim2.new(0.48, 0, 0, 30)
ConfirmNo.Position          = UDim2.new(0, 0, 1, -38)
ConfirmNo.BackgroundColor3  = COLORS.item
ConfirmNo.TextColor3        = COLORS.text
ConfirmNo.Font              = Enum.Font.GothamBold
ConfirmNo.TextSize          = 12
ConfirmNo.ZIndex            = 42
ConfirmNo.AutoButtonColor   = true
ConfirmNo.Parent            = ConfirmBox
corner(8, ConfirmNo)

-- ══════════════════════════════════════════
--  BILLBOARDGUI MANAGEMENT
-- ══════════════════════════════════════════
local function destroyBillboard(key)
    if ActiveBills[key] then
        ActiveBills[key]:Destroy()
        ActiveBills[key] = nil
    end
end

local function createBillboard(gi, wi)
    local g  = Games[gi]
    local wp = g and g.waypoints and g.waypoints[wi]
    if not wp then return end
    local key = getWpKey(gi, wi)
    destroyBillboard(key)

    local pos = Vector3.new(wp.x or 0, wp.y or 0, wp.z or 0)
    local part = Instance.new("Part")
    part.Anchored    = true
    part.CanCollide  = false
    part.Transparency = 1
    part.Size        = Vector3.new(0.1, 0.1, 0.1)
    part.Position    = pos
    part.Name        = "WP_" .. key
    part.Parent      = workspace

    local bill = Instance.new("BillboardGui")
    bill.Size          = UDim2.new(0, 180, 0, 60)
    bill.StudsOffset   = Vector3.new(0, 3, 0)
    bill.AlwaysOnTop   = true
    bill.LightInfluence = 0
    bill.Parent        = part

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name              = "NameLabel"
    nameLabel.Size              = UDim2.new(1, 0, 0.55, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3        = getColor()
    nameLabel.Font              = getFont()
    nameLabel.TextSize          = 16
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextStrokeColor3  = Color3.new(0, 0, 0)
    nameLabel.Text              = wp.name or "Waypoint"
    nameLabel.ZIndex            = 2
    nameLabel.Parent            = bill

    local distLabel = Instance.new("TextLabel")
    distLabel.Name              = "DistLabel"
    distLabel.Size              = UDim2.new(1, 0, 0.45, 0)
    distLabel.Position          = UDim2.new(0, 0, 0.55, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3        = getColor()
    distLabel.Font              = getFont()
    distLabel.TextSize          = 13
    distLabel.TextStrokeTransparency = 0.6
    distLabel.TextStrokeColor3  = Color3.new(0, 0, 0)
    distLabel.Text              = "0 studs"
    distLabel.ZIndex            = 2
    distLabel.Parent            = bill

    -- marker dot below name
    local dot = Instance.new("Frame")
    dot.Size               = UDim2.new(0, 10, 0, 10)
    dot.Position           = UDim2.new(0.5, -5, 1, 2)
    dot.BackgroundColor3   = getColor()
    dot.BorderSizePixel    = 0
    dot.ZIndex             = 2
    dot.Parent             = bill
    corner(5, dot)

    ActiveBills[key] = part
end

local function toggleWaypoint(gi, wi, enabled)
    local g  = Games[gi]
    local wp = g and g.waypoints and g.waypoints[wi]
    if not wp then return end
    wp.enabled = enabled
    local key  = getWpKey(gi, wi)
    if enabled then
        createBillboard(gi, wi)
    else
        destroyBillboard(key)
    end
    saveData()
end

local function removeAllBillboards()
    for key, part in pairs(ActiveBills) do
        part:Destroy()
        ActiveBills[key] = nil
    end
end

-- Update billboard appearance (after settings change)
local function refreshBillboard(gi, wi)
    local key = getWpKey(gi, wi)
    if ActiveBills[key] then
        local bill = ActiveBills[key]:FindFirstChildOfClass("BillboardGui")
        if bill then
            local nl = bill:FindFirstChild("NameLabel")
            local dl = bill:FindFirstChild("DistLabel")
            local dot = bill:FindFirstChildWhichIsA("Frame")
            local col = getColor()
            local fnt = getFont()
            if nl then nl.TextColor3 = col ; nl.Font = fnt end
            if dl then dl.TextColor3 = col ; dl.Font = fnt end
            if dot then dot.BackgroundColor3 = col end
        end
    end
end

local function refreshAllBillboards()
    for gi, g in ipairs(Games) do
        for wi, wp in ipairs(g.waypoints or {}) do
            if wp.enabled then refreshBillboard(gi, wi) end
        end
    end
end

-- ══════════════════════════════════════════
--  RENDER LOOP (Fade Logic)
-- ══════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    local char = Player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local camPos = Camera.CFrame.Position

    for gi, g in ipairs(Games) do
        for wi, wp in ipairs(g.waypoints or {}) do
            if wp.enabled then
                local key  = getWpKey(gi, wi)
                local part = ActiveBills[key]
                if part then
                    local bill = part:FindFirstChildOfClass("BillboardGui")
                    if bill then
                        local nl  = bill:FindFirstChild("NameLabel")
                        local dl  = bill:FindFirstChild("DistLabel")
                        local dot = bill:FindFirstChildWhichIsA("Frame")

                        local wpPos  = Vector3.new(wp.x, wp.y, wp.z)
                        local dist   = (hrp.Position - wpPos).Magnitude
                        local distRounded = math.floor(dist + 0.5)

                        -- Update distance text
                        if dl then dl.Text = distRounded .. " studs" end

                        local maxOp = Settings.maxOpacity
                        local farD  = Settings.fadeStudDistance
                        local farND = Settings.fadeNameDistance
                        local closeD  = Settings.fadeClosingDistance
                        local closeND = Settings.fadeClosingNameDistance

                        -- Far fade (waypoint icon + dot)
                        local dotAlpha, billAlpha
                        if dist >= farD then
                            dotAlpha  = 1.0
                            billAlpha = 1.0
                        elseif dist <= closeD then
                            dotAlpha  = 1.0
                            billAlpha = 1.0
                        else
                            -- Normal visible range
                            dotAlpha  = 1 - maxOp
                            billAlpha = 1 - maxOp
                        end

                        -- Far fade override (fade out when too far)
                        if dist > farD then
                            dotAlpha  = 1.0
                            billAlpha = 1.0
                        else
                            dotAlpha  = 1 - maxOp
                            billAlpha = 1 - maxOp
                        end

                        -- Close fade (fade when very near)
                        if dist < closeD and closeD > 0 then
                            local ratio = dist / closeD
                            local fadeT = 1 - (ratio * maxOp)
                            dotAlpha  = math.clamp(fadeT, 0, 1)
                            billAlpha = math.clamp(fadeT, 0, 1)
                        end

                        -- Far fade (fade when too far)
                        if dist > farD then
                            dotAlpha  = 1.0
                            billAlpha = 1.0
                        elseif dist > (farD * 0.8) then
                            local ratio = (dist - farD * 0.8) / (farD * 0.2)
                            local fadeT = ratio
                            dotAlpha  = math.max(dotAlpha, math.clamp(fadeT, 0, 1))
                            billAlpha = math.max(billAlpha, math.clamp(fadeT, 0, 1))
                        end

                        -- Name far fade
                        local nameAlpha
                        if dist > farND then
                            nameAlpha = 1.0
                        elseif dist > (farND * 0.8) then
                            local ratio = (dist - farND * 0.8) / (farND * 0.2)
                            nameAlpha = math.clamp(ratio, 0, 1)
                        elseif dist < closeND and closeND > 0 then
                            local ratio = dist / closeND
                            nameAlpha = math.clamp(1 - (ratio * maxOp), 0, 1)
                        else
                            nameAlpha = 1 - maxOp
                        end

                        if nl  then nl.TextTransparency  = nameAlpha  end
                        if nl  then nl.TextStrokeTransparency = math.min(nameAlpha + 0.4, 1) end
                        if dl  then dl.TextTransparency  = billAlpha  end
                        if dl  then dl.TextStrokeTransparency = math.min(billAlpha + 0.4, 1) end
                        if dot then dot.BackgroundTransparency = dotAlpha end
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════
--  PAGE NAVIGATION
-- ══════════════════════════════════════════
local prevPage = "main"

local function showPage(name)
    prevPage    = CurrentPage
    CurrentPage = name
    PageMain.Visible      = (name == "main")
    PageWaypoints.Visible = (name == "waypoints")
    PageSettings.Visible  = (name == "settings")
    BtnBack.Visible       = (name ~= "main")
    closeCtx()
end

-- ══════════════════════════════════════════
--  MODAL HELPERS
-- ══════════════════════════════════════════
local modalConn1, modalConn2

local function openModal(title, placeholder, onConfirm, onCancel, confirmText)
    ModalTitle.Text           = title
    ModalInput.PlaceholderText = placeholder or ""
    ModalInput.Text           = ""
    ModalConfirmBtn.Text      = confirmText or "Confirm"
    Overlay.Visible           = true
    Modal.Visible             = true
    ModalInput:CaptureFocus()

    if modalConn1 then modalConn1:Disconnect() end
    if modalConn2 then modalConn2:Disconnect() end

    modalConn1 = ModalConfirmBtn.MouseButton1Click:Connect(function()
        local text = ModalInput.Text
        Modal.Visible   = false
        Overlay.Visible = false
        if onConfirm then onConfirm(text) end
    end)
    modalConn2 = ModalCancelBtn.MouseButton1Click:Connect(function()
        Modal.Visible   = false
        Overlay.Visible = false
        if onCancel then onCancel() end
    end)
end

local function openConfirmClose()
    ConfirmOverlay.Visible = true
    ConfirmBox.Visible     = true
end

ConfirmNo.MouseButton1Click:Connect(function()
    ConfirmOverlay.Visible = false
    ConfirmBox.Visible     = false
end)

ConfirmYes.MouseButton1Click:Connect(function()
    removeAllBillboards()
    Gui:Destroy()
end)

-- ══════════════════════════════════════════
--  GAME LIST RENDERING
-- ══════════════════════════════════════════
local function renderGameList(filter)
    for _, c in ipairs(GameScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end

    for gi, g in ipairs(Games) do
        if filter and filter ~= "" then
            if not string.lower(g.name or ""):find(string.lower(filter), 1, true) then
                continue
            end
        end

        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 40)
        row.BackgroundColor3 = COLORS.item
        row.BorderSizePixel  = 0
        row.ZIndex           = 7
        row.Parent           = GameScroll
        corner(8, row)

        local nameBtn = Instance.new("TextButton")
        nameBtn.Text             = g.name or ("Game " .. gi)
        nameBtn.Size             = UDim2.new(1, -36, 1, 0)
        nameBtn.BackgroundTransparency = 1
        nameBtn.TextColor3       = COLORS.text
        nameBtn.Font             = Enum.Font.Gotham
        nameBtn.TextSize         = 13
        nameBtn.TextXAlignment   = Enum.TextXAlignment.Left
        nameBtn.ZIndex           = 8
        nameBtn.AutoButtonColor  = false
        nameBtn.Parent           = row
        padding(0, 0, 12, 0, nameBtn)

        local wpCount = #(g.waypoints or {})
        local sub = Instance.new("TextLabel")
        sub.Text              = tostring(wpCount) .. " waypoint" .. (wpCount ~= 1 and "s" or "")
        sub.Size              = UDim2.new(1, -36, 0, 14)
        sub.Position          = UDim2.new(0, 12, 1, -16)
        sub.BackgroundTransparency = 1
        sub.TextColor3        = COLORS.subtext
        sub.Font              = Enum.Font.Gotham
        sub.TextSize          = 10
        sub.TextXAlignment    = Enum.TextXAlignment.Left
        sub.ZIndex            = 8
        sub.Parent            = row

        local dotsBtn = Instance.new("TextButton")
        dotsBtn.Text            = "⋮"
        dotsBtn.Size            = UDim2.new(0, 30, 1, 0)
        dotsBtn.Position        = UDim2.new(1, -32, 0, 0)
        dotsBtn.BackgroundTransparency = 1
        dotsBtn.TextColor3      = COLORS.subtext
        dotsBtn.Font            = Enum.Font.GothamBold
        dotsBtn.TextSize        = 18
        dotsBtn.ZIndex          = 8
        dotsBtn.AutoButtonColor = false
        dotsBtn.Parent          = row

        -- Capture gi in closure
        local capturedGi = gi
        nameBtn.MouseButton1Click:Connect(function()
            CurrentGameIdx          = capturedGi
            WPTitleLabel.Text       = Games[capturedGi].name or "Waypoints"
            showPage("waypoints")
            -- rebuild waypoint list
            for _, c2 in ipairs(WPScroll:GetChildren()) do
                if c2:IsA("Frame") then c2:Destroy() end
            end
            renderWaypointList()
        end)

        dotsBtn.MouseButton1Click:Connect(function()
            local abs = dotsBtn.AbsolutePosition
            CtxMenu.Position = UDim2.new(0, abs.X - 130, 0, abs.Y + 30)
            CtxMenu.Visible  = true
            closeCtx()
            CtxMenu.Visible = true

            if modalConn1 then modalConn1:Disconnect() end
            if modalConn2 then modalConn2:Disconnect() end

            local r = CtxRename.MouseButton1Click:Connect(function()
                closeCtx()
                openModal("Rename Game", "New name...", function(newName)
                    if newName and newName ~= "" then
                        Games[capturedGi].name = newName
                        saveData()
                        renderGameList(SearchBox.Text)
                    end
                end)
            end)
            local d = CtxDelete.MouseButton1Click:Connect(function()
                closeCtx()
                -- remove all waypoint billboards for this game
                for wi = 1, #(Games[capturedGi].waypoints or {}) do
                    destroyBillboard(getWpKey(capturedGi, wi))
                end
                table.remove(Games, capturedGi)
                saveData()
                renderGameList(SearchBox.Text)
            end)
            -- auto-disconnect after one use handled by closeCtx reconnect
        end)
    end
end

-- ══════════════════════════════════════════
--  WAYPOINT LIST RENDERING
-- ══════════════════════════════════════════
function renderWaypointList()
    if not CurrentGameIdx then return end
    for _, c in ipairs(WPScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    local g = Games[CurrentGameIdx]
    if not g then return end

    for wi, wp in ipairs(g.waypoints or {}) do
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 44)
        row.BackgroundColor3 = COLORS.item
        row.BorderSizePixel  = 0
        row.ZIndex           = 7
        row.Parent           = WPScroll
        corner(8, row)

        -- Toggle
        local togFrame = Instance.new("Frame")
        togFrame.Size             = UDim2.new(0, 36, 0, 20)
        togFrame.Position         = UDim2.new(0, 10, 0.5, -10)
        togFrame.BackgroundColor3 = wp.enabled and COLORS.toggle_on or COLORS.toggle_off
        togFrame.BorderSizePixel  = 0
        togFrame.ZIndex           = 8
        togFrame.Parent           = row
        corner(10, togFrame)

        local togDot = Instance.new("Frame")
        togDot.Size             = UDim2.new(0, 16, 0, 16)
        togDot.Position         = UDim2.new(wp.enabled and 1 or 0, wp.enabled and -18 or 2, 0.5, -8)
        togDot.BackgroundColor3 = Color3.new(1, 1, 1)
        togDot.BorderSizePixel  = 0
        togDot.ZIndex           = 9
        togDot.Parent           = togFrame
        corner(8, togDot)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Text            = wp.name or "Waypoint"
        nameLabel.Size            = UDim2.new(1, -90, 0.6, 0)
        nameLabel.Position        = UDim2.new(0, 56, 0, 4)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3      = COLORS.text
        nameLabel.Font            = Enum.Font.Gotham
        nameLabel.TextSize        = 12
        nameLabel.TextXAlignment  = Enum.TextXAlignment.Left
        nameLabel.ZIndex          = 8
        nameLabel.Parent          = row

        local posLabel = Instance.new("TextLabel")
        local px, py, pz = math.floor(wp.x or 0), math.floor(wp.y or 0), math.floor(wp.z or 0)
        posLabel.Text             = px .. ", " .. py .. ", " .. pz
        posLabel.Size             = UDim2.new(1, -90, 0.4, 0)
        posLabel.Position         = UDim2.new(0, 56, 0.6, 0)
        posLabel.BackgroundTransparency = 1
        posLabel.TextColor3       = COLORS.subtext
        posLabel.Font             = Enum.Font.Gotham
        posLabel.TextSize         = 10
        posLabel.TextXAlignment   = Enum.TextXAlignment.Left
        posLabel.ZIndex           = 8
        posLabel.Parent           = row

        local dotsBtn = Instance.new("TextButton")
        dotsBtn.Text              = "⋮"
        dotsBtn.Size              = UDim2.new(0, 30, 1, 0)
        dotsBtn.Position          = UDim2.new(1, -32, 0, 0)
        dotsBtn.BackgroundTransparency = 1
        dotsBtn.TextColor3        = COLORS.subtext
        dotsBtn.Font              = Enum.Font.GothamBold
        dotsBtn.TextSize          = 18
        dotsBtn.ZIndex            = 8
        dotsBtn.AutoButtonColor   = false
        dotsBtn.Parent            = row

        local capturedGi = CurrentGameIdx
        local capturedWi = wi

        -- Toggle click
        local togBtn = Instance.new("TextButton")
        togBtn.Size               = UDim2.new(1, 0, 1, 0)
        togBtn.BackgroundTransparency = 1
        togBtn.Text               = ""
        togBtn.ZIndex             = 10
        togBtn.Parent             = togFrame

        togBtn.MouseButton1Click:Connect(function()
            local wp2 = Games[capturedGi] and Games[capturedGi].waypoints and Games[capturedGi].waypoints[capturedWi]
            if not wp2 then return end
            local newState = not wp2.enabled
            toggleWaypoint(capturedGi, capturedWi, newState)
            togFrame.BackgroundColor3 = newState and COLORS.toggle_on or COLORS.toggle_off
            tween(togDot, {Position = UDim2.new(newState and 1 or 0, newState and -18 or 2, 0.5, -8)}, 0.12)
        end)

        -- Three-dot menu
        dotsBtn.MouseButton1Click:Connect(function()
            local abs = dotsBtn.AbsolutePosition
            CtxMenu.Position = UDim2.new(0, abs.X - 130, 0, abs.Y + 30)
            CtxMenu.Visible  = true

            local rc = CtxRename.MouseButton1Click:Connect(function()
                closeCtx()
                openModal("Rename Waypoint", "New name...", function(newName)
                    if newName and newName ~= "" then
                        local wp2 = Games[capturedGi] and Games[capturedGi].waypoints and Games[capturedGi].waypoints[capturedWi]
                        if wp2 then
                            wp2.name = newName
                            saveData()
                            -- Update billboard if active
                            local key  = getWpKey(capturedGi, capturedWi)
                            local part = ActiveBills[key]
                            if part then
                                local bill = part:FindFirstChildOfClass("BillboardGui")
                                if bill then
                                    local nl = bill:FindFirstChild("NameLabel")
                                    if nl then nl.Text = newName end
                                end
                            end
                            renderWaypointList()
                        end
                    end
                end)
            end)

            local dc = CtxDelete.MouseButton1Click:Connect(function()
                closeCtx()
                local wp2 = Games[capturedGi] and Games[capturedGi].waypoints and Games[capturedGi].waypoints[capturedWi]
                if wp2 and wp2.enabled then
                    destroyBillboard(getWpKey(capturedGi, capturedWi))
                end
                table.remove(Games[capturedGi].waypoints, capturedWi)
                saveData()
                renderWaypointList()
                -- Also refresh game list subtitle count
            end)
        end)
    end
end

-- ══════════════════════════════════════════
--  SETTINGS PAGE BUILDER
-- ══════════════════════════════════════════
local function makeSettingRow(labelText, parent)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = COLORS.item
    row.BorderSizePixel  = 0
    row.ZIndex           = 7
    row.Parent           = parent
    corner(8, row)

    local lbl = Instance.new("TextLabel")
    lbl.Text             = labelText
    lbl.Size             = UDim2.new(1, -12, 0, 18)
    lbl.Position         = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3       = COLORS.subtext
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 11
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 8
    lbl.Parent           = row

    return row, lbl
end

local function makeNumberInput(parent, defaultVal, yPos, onChange)
    local box = Instance.new("TextBox")
    box.Text             = tostring(defaultVal)
    box.Size             = UDim2.new(1, -24, 0, 26)
    box.Position         = UDim2.new(0, 12, 0, yPos or 22)
    box.BackgroundColor3 = COLORS.bg
    box.TextColor3       = COLORS.text
    box.Font             = Enum.Font.Gotham
    box.TextSize         = 12
    box.ZIndex           = 9
    box.Parent           = parent
    corner(6, box)
    padding(0, 0, 8, 0, box)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            box.Text = tostring(n)
            if onChange then onChange(n) end
        else
            box.Text = tostring(defaultVal)
        end
    end)
    return box
end

local function buildSettingsPage()
    for _, c in ipairs(SettingsScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end

    -- Section header helper
    local function sectionHeader(text)
        local lbl = Instance.new("TextLabel")
        lbl.Text             = text
        lbl.Size             = UDim2.new(1, 0, 0, 22)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3       = COLORS.accent
        lbl.Font             = Enum.Font.GothamBold
        lbl.TextSize         = 12
        lbl.TextXAlignment   = Enum.TextXAlignment.Left
        lbl.ZIndex           = 7
        lbl.Parent           = SettingsScroll
        return lbl
    end

    -- ── Fade Settings ──
    sectionHeader("  FADE SETTINGS")

    local row1, _ = makeSettingRow("Fade Stud Distance  (fully fades when farther than X studs)", SettingsScroll)
    makeNumberInput(row1, Settings.fadeStudDistance, 24, function(v)
        Settings.fadeStudDistance = v ; saveData()
    end)

    local row2, _ = makeSettingRow("Fade Name Distance  (name text fades beyond X studs)", SettingsScroll)
    makeNumberInput(row2, Settings.fadeNameDistance, 24, function(v)
        Settings.fadeNameDistance = v ; saveData()
    end)

    local row3, _ = makeSettingRow("Fade Closing Distance  (fades when closer than X studs)", SettingsScroll)
    makeNumberInput(row3, Settings.fadeClosingDistance, 24, function(v)
        Settings.fadeClosingDistance = v ; saveData()
    end)

    local row4, _ = makeSettingRow("Fade Closing Name Distance  (name fades when closer than X studs)", SettingsScroll)
    makeNumberInput(row4, Settings.fadeClosingNameDistance, 24, function(v)
        Settings.fadeClosingNameDistance = v ; saveData()
    end)

    -- ── Opacity ──
    sectionHeader("  OPACITY")

    local row5, _ = makeSettingRow("Max Opacity  (0.0 = invisible · 1.0 = fully visible)", SettingsScroll)
    makeNumberInput(row5, Settings.maxOpacity, 24, function(v)
        Settings.maxOpacity = math.clamp(v, 0, 1) ; saveData()
    end)

    -- ── Font ──
    sectionHeader("  TEXT FONT")

    local fontRow = Instance.new("Frame")
    fontRow.Size             = UDim2.new(1, 0, 0, 44)
    fontRow.BackgroundColor3 = COLORS.item
    fontRow.BorderSizePixel  = 0
    fontRow.ZIndex           = 7
    fontRow.Parent           = SettingsScroll
    corner(8, fontRow)

    local fontLabel = Instance.new("TextLabel")
    fontLabel.Text           = "Current: " .. Settings.font
    fontLabel.Size           = UDim2.new(1, -100, 1, 0)
    fontLabel.Position       = UDim2.new(0, 12, 0, 0)
    fontLabel.BackgroundTransparency = 1
    fontLabel.TextColor3     = COLORS.text
    fontLabel.Font           = Enum.Font.Gotham
    fontLabel.TextSize       = 12
    fontLabel.TextXAlignment = Enum.TextXAlignment.Left
    fontLabel.ZIndex         = 8
    fontLabel.Parent         = fontRow

    local fontIdx = 1
    for i, f in ipairs(FONTS) do if f == Settings.font then fontIdx = i break end end

    local prevFontBtn = Instance.new("TextButton")
    prevFontBtn.Text            = "◀"
    prevFontBtn.Size            = UDim2.new(0, 28, 0, 28)
    prevFontBtn.Position        = UDim2.new(1, -64, 0.5, -14)
    prevFontBtn.BackgroundColor3 = COLORS.bg
    prevFontBtn.TextColor3      = COLORS.text
    prevFontBtn.Font            = Enum.Font.GothamBold
    prevFontBtn.TextSize        = 14
    prevFontBtn.ZIndex          = 8
    prevFontBtn.AutoButtonColor = true
    prevFontBtn.Parent          = fontRow
    corner(6, prevFontBtn)

    local nextFontBtn = Instance.new("TextButton")
    nextFontBtn.Text            = "▶"
    nextFontBtn.Size            = UDim2.new(0, 28, 0, 28)
    nextFontBtn.Position        = UDim2.new(1, -32, 0.5, -14)
    nextFontBtn.BackgroundColor3 = COLORS.bg
    nextFontBtn.TextColor3      = COLORS.text
    nextFontBtn.Font            = Enum.Font.GothamBold
    nextFontBtn.TextSize        = 14
    nextFontBtn.ZIndex          = 8
    nextFontBtn.AutoButtonColor = true
    nextFontBtn.Parent          = fontRow
    corner(6, nextFontBtn)

    prevFontBtn.MouseButton1Click:Connect(function()
        fontIdx = ((fontIdx - 2) % #FONTS) + 1
        Settings.font = FONTS[fontIdx]
        fontLabel.Text = "Current: " .. Settings.font
        saveData()
        refreshAllBillboards()
    end)

    nextFontBtn.MouseButton1Click:Connect(function()
        fontIdx = (fontIdx % #FONTS) + 1
        Settings.font = FONTS[fontIdx]
        fontLabel.Text = "Current: " .. Settings.font
        saveData()
        refreshAllBillboards()
    end)

    -- ── Color Picker ──
    sectionHeader("  WAYPOINT COLOR")

    local colorRow = Instance.new("Frame")
    colorRow.Size             = UDim2.new(1, 0, 0, 200)
    colorRow.BackgroundColor3 = COLORS.item
    colorRow.BorderSizePixel  = 0
    colorRow.ZIndex           = 7
    colorRow.Parent           = SettingsScroll
    corner(8, colorRow)

    -- HSV Picker: Hue bar + SV square
    -- SV square (Saturation horizontal, Value vertical)
    local svSize = 120
    local svSquare = Instance.new("ImageLabel")
    svSquare.Size             = UDim2.new(0, svSize, 0, svSize)
    svSquare.Position         = UDim2.new(0, 12, 0, 12)
    svSquare.BackgroundColor3 = Color3.new(1, 0, 0)
    svSquare.BorderSizePixel  = 0
    svSquare.ZIndex           = 8
    svSquare.Image            = "rbxassetid://0"
    svSquare.Parent           = colorRow
    corner(6, svSquare)

    -- White gradient (left→right = white→transparent overlay)
    local svWhite = Instance.new("ImageLabel")
    svWhite.Size   = UDim2.new(1, 0, 1, 0)
    svWhite.BackgroundTransparency = 1
    svWhite.Image  = "rbxassetid://2615689976" -- horizontal white-to-transparent
    svWhite.ZIndex = 9
    svWhite.Parent = svSquare

    -- Black gradient (bottom dark overlay)
    local svBlack = Instance.new("ImageLabel")
    svBlack.Size   = UDim2.new(1, 0, 1, 0)
    svBlack.BackgroundTransparency = 1
    svBlack.Image  = "rbxassetid://2615689975" -- vertical transparent-to-black
    svBlack.ZIndex = 10
    svBlack.Parent = svSquare

    -- SV cursor
    local svCursor = Instance.new("Frame")
    svCursor.Size             = UDim2.new(0, 10, 0, 10)
    svCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    svCursor.BorderSizePixel  = 0
    svCursor.ZIndex           = 11
    svCursor.Parent           = svSquare
    corner(5, svCursor)
    stroke(1.5, Color3.new(0, 0, 0), svCursor)

    -- Hue bar
    local hueBar = Instance.new("ImageLabel")
    hueBar.Size             = UDim2.new(0, 18, 0, svSize)
    hueBar.Position         = UDim2.new(0, 12 + svSize + 8, 0, 12)
    hueBar.BackgroundColor3 = Color3.new(1, 0, 0)
    hueBar.BorderSizePixel  = 0
    hueBar.Image            = "rbxassetid://2615689973" -- vertical hue spectrum
    hueBar.ZIndex           = 8
    hueBar.Parent           = colorRow
    corner(4, hueBar)

    local hueCursor = Instance.new("Frame")
    hueCursor.Size             = UDim2.new(1, 4, 0, 4)
    hueCursor.Position         = UDim2.new(0, -2, 0, 0)
    hueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    hueCursor.BorderSizePixel  = 0
    hueCursor.ZIndex           = 9
    hueCursor.Parent           = hueBar
    corner(2, hueCursor)
    stroke(1.5, Color3.new(0, 0, 0), hueCursor)

    -- Preview swatch
    local swatch = Instance.new("Frame")
    swatch.Size             = UDim2.new(0, svSize - 30, 0, 30)
    swatch.Position         = UDim2.new(0, 12, 0, 12 + svSize + 8)
    swatch.BackgroundColor3 = getColor()
    swatch.BorderSizePixel  = 0
    swatch.ZIndex           = 8
    swatch.Parent           = colorRow
    corner(6, swatch)

    local hexLabel = Instance.new("TextLabel")
    hexLabel.Size             = UDim2.new(0, 60, 0, 30)
    hexLabel.Position         = UDim2.new(0, 12 + svSize - 28, 0, 12 + svSize + 8)
    hexLabel.BackgroundColor3 = COLORS.bg
    hexLabel.TextColor3       = COLORS.text
    hexLabel.Font             = Enum.Font.Code
    hexLabel.TextSize         = 11
    hexLabel.ZIndex           = 8
    hexLabel.Parent           = colorRow
    corner(6, hexLabel)

    local function colorToHex(c)
        return string.format("#%02X%02X%02X",
            math.floor(c.R * 255),
            math.floor(c.G * 255),
            math.floor(c.B * 255)
        )
    end

    -- HSV state for picker
    local h, s, v = Color3.new(Settings.colorR, Settings.colorG, Settings.colorB):ToHSV()

    local function applyHSV()
        local col = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = col
        hexLabel.Text = colorToHex(col)
        svSquare.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        -- Update cursor positions
        svCursor.Position = UDim2.new(s, -5, 1 - v, -5)
        hueCursor.Position = UDim2.new(0, -2, 1 - h, -2)
        -- Save
        Settings.colorR = col.R
        Settings.colorG = col.G
        Settings.colorB = col.B
        saveData()
        refreshAllBillboards()
    end

    applyHSV()

    -- Dragging state for SV square
    local draggingSV, draggingHue = false, false

    local svBtn = Instance.new("TextButton")
    svBtn.Size               = UDim2.new(1, 0, 1, 0)
    svBtn.BackgroundTransparency = 1
    svBtn.Text               = ""
    svBtn.ZIndex             = 12
    svBtn.Parent             = svSquare

    svBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSV = true
        end
    end)
    svBtn.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSV = false
        end
    end)

    local hueBtn = Instance.new("TextButton")
    hueBtn.Size               = UDim2.new(1, 0, 1, 0)
    hueBtn.BackgroundTransparency = 1
    hueBtn.Text               = ""
    hueBtn.ZIndex             = 9
    hueBtn.Parent             = hueBar

    hueBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
        end
    end)
    hueBtn.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            draggingHue = false
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end

        if draggingSV then
            local rel = inp.Position - svSquare.AbsolutePosition
            s = math.clamp(rel.X / svSquare.AbsoluteSize.X, 0, 1)
            v = math.clamp(1 - (rel.Y / svSquare.AbsoluteSize.Y), 0, 1)
            applyHSV()
        elseif draggingHue then
            local rel = inp.Position - hueBar.AbsolutePosition
            h = math.clamp(1 - (rel.Y / hueBar.AbsoluteSize.Y), 0, 1)
            applyHSV()
        end
    end)
end

-- ══════════════════════════════════════════
--  MENU TOGGLE
-- ══════════════════════════════════════════
local function toggleMenu()
    if Minimized then
        Minimized  = false
        Menu.Visible = true
        return
    end
    MenuOpen = not MenuOpen
    Menu.Visible = MenuOpen
    if MenuOpen then
        renderGameList(SearchBox.Text)
        showPage("main")
    end
end

-- ══════════════════════════════════════════
--  BUTTON WIRING
-- ══════════════════════════════════════════
ToggleBtn.MouseButton1Click:Connect(toggleMenu)

BtnClose.MouseButton1Click:Connect(openConfirmClose)

BtnMinimize.MouseButton1Click:Connect(function()
    Minimized    = true
    Menu.Visible = false
end)

BtnSettings.MouseButton1Click:Connect(function()
    if CurrentPage ~= "settings" then
        buildSettingsPage()
        showPage("settings")
    end
end)

BtnBack.MouseButton1Click:Connect(function()
    if CurrentPage == "settings" then
        showPage(prevPage == "settings" and "main" or prevPage)
    elseif CurrentPage == "waypoints" then
        showPage("main")
        renderGameList(SearchBox.Text)
    end
end)

-- Search filter
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    renderGameList(SearchBox.Text)
end)

-- Add Game
AddGameBtn.MouseButton1Click:Connect(function()
    openModal("Add Game", "Enter game name...", function(name)
        if name and name ~= "" then
            table.insert(Games, { name = name, waypoints = {} })
            saveData()
            renderGameList(SearchBox.Text)
        end
    end, nil, "Add")
end)

-- Add Waypoint
AddWPBtn.MouseButton1Click:Connect(function()
    openModal("Add Waypoint", "Enter waypoint name...", function(name)
        if name and name ~= "" then
            local char = Player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local pos   = hrp and hrp.Position or Vector3.new(0, 0, 0)
            local g     = Games[CurrentGameIdx]
            if g then
                table.insert(g.waypoints, {
                    name    = name,
                    x       = pos.X,
                    y       = pos.Y,
                    z       = pos.Z,
                    enabled = false,
                })
                saveData()
                renderWaypointList()
            end
        end
    end, nil, "Add")
end)

-- Close context menu when clicking elsewhere
UserInputService.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        -- Small delay so button handlers fire first
        task.wait()
        if CtxMenu.Visible then
            local mx, my = inp.Position.X, inp.Position.Y
            local ap = CtxMenu.AbsolutePosition
            local as = CtxMenu.AbsoluteSize
            if mx < ap.X or mx > ap.X + as.X or my < ap.Y or my > ap.Y + as.Y then
                closeCtx()
            end
        end
    end
end)

-- ══════════════════════════════════════════
--  DOUBLE-B KEYBIND
-- ══════════════════════════════════════════
UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.KeyCode == Enum.KeyCode.B then
        local now = tick()
        if (now - lastBPress) <= DOUBLE_B_WINDOW then
            toggleMenu()
            lastBPress = 0
        else
            lastBPress = now
        end
    end
end)

-- ══════════════════════════════════════════
--  INITIAL RENDER
-- ══════════════════════════════════════════
renderGameList("")
showPage("main")
