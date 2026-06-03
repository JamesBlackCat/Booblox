--[[
    ESP Manager — NPC & Player ESP
    Executor LocalScript

    Features:
    - NPC Game Folders with path input or full scan
    - NPC grouping by name with per-group ESP settings
    - NPC Spawn Notifier (⚠️ on new spawn)
    - Player ESP with individual toggles + global settings
    - Player HELP Notify (green body + "HELP" label on low HP)
    - ESP Types: Name, Distance, Outline, Full Body
    - 9 preset colors, font picker, fade/opacity settings
    - Persistence via writefile/readfile
    - Red / Black / White professional theme
--]]

-- ══════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════
--  SAVE FILE
-- ══════════════════════════════════════════
local SAVE_FILE = "ESP_Manager_Data.json"

-- ══════════════════════════════════════════
--  THEME  (Red / Black / White)
-- ══════════════════════════════════════════
local T = {
    bg          = Color3.fromRGB(10,  4,   4),
    panel       = Color3.fromRGB(18,  6,   6),
    titlebar    = Color3.fromRGB(28,  4,   4),
    item        = Color3.fromRGB(26,  10,  10),
    itemHover   = Color3.fromRGB(40,  14,  14),
    accent      = Color3.fromRGB(210, 35,  35),
    accentDark  = Color3.fromRGB(150, 20,  20),
    accentBright= Color3.fromRGB(235, 55,  55),
    danger      = Color3.fromRGB(230, 60,  60),
    text        = Color3.new(1, 1, 1),
    subtext     = Color3.fromRGB(200, 165, 165),
    stroke      = Color3.fromRGB(90,  22,  22),
    scroll      = Color3.fromRGB(120, 35,  35),
    tog_on      = Color3.fromRGB(210, 40,  40),
    tog_off     = Color3.fromRGB(50,  20,  20),
    tab_active  = Color3.fromRGB(200, 35,  35),
    tab_idle    = Color3.fromRGB(30,  8,   8),
    help_green  = Color3.fromRGB(40,  210, 90),
}

-- ══════════════════════════════════════════
--  PRESET COLORS (9 swatches)
-- ══════════════════════════════════════════
local PRESET_COLORS = {
    Color3.fromRGB(235, 55,  55),   -- 1 Red
    Color3.fromRGB(255, 145, 0),    -- 2 Orange
    Color3.fromRGB(245, 225, 0),    -- 3 Yellow
    Color3.fromRGB(55,  215, 85),   -- 4 Green
    Color3.fromRGB(0,   215, 215),  -- 5 Cyan
    Color3.fromRGB(65,  105, 255),  -- 6 Blue
    Color3.fromRGB(175, 60,  255),  -- 7 Purple
    Color3.fromRGB(255, 105, 185),  -- 8 Pink
    Color3.fromRGB(255, 255, 255),  -- 9 White
}

-- ══════════════════════════════════════════
--  FONTS
-- ══════════════════════════════════════════
local FONTS = {
    "GothamBold","Gotham","GothamMedium",
    "Arial","ArialBold",
    "SourceSans","SourceSansBold",
    "RobotoMono","Code","Nunito",
}

-- ══════════════════════════════════════════
--  DEFAULT GROUP SETTINGS
-- ══════════════════════════════════════════
local function defaultGroupSettings()
    return {
        espEnabled            = false,
        espName               = true,
        espDistance           = true,
        espOutline            = false,
        espFullBody           = false,
        colorIndex            = 1,
        font                  = "GothamBold",
        fadeStudDist          = 200,
        fadeNameDist          = 200,
        fadeCloseDist         = 8,
        fadeCloseNameDist     = 8,
        maxOpacity            = 1.0,
        helpEnabled           = false,
        helpHP                = 30,
        helpFadeDist          = 150,
        spawnEnabled          = false,
        spawnEmoji            = "⚠️",
        spawnDuration         = 5,
        spawnFadeDist         = 150,
        spawnFont             = "GothamBold",
        spawnColorIndex       = 3,
    }
end

local function defaultPlayerSettings()
    return {
        selected              = false,
        espEnabled            = false,
        espName               = true,
        espDistance           = true,
        espOutline            = false,
        espFullBody           = false,
        colorIndex            = 5,
        font                  = "GothamBold",
        fadeStudDist          = 200,
        fadeNameDist          = 200,
        fadeCloseDist         = 8,
        fadeCloseNameDist     = 8,
        maxOpacity            = 1.0,
        helpEnabled           = false,
        helpHP                = 30,
        helpFadeDist          = 150,
    }
end

-- ══════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════
-- NpcGames = { { name, path, groups = { [groupName] = settings } } }
-- PlayerData = { [userId_str] = settings }
local NpcGames   = {}
local PlayerData = {}

-- Live tracking
local NpcBills   = {}  -- "gi_gname_modelPtr" -> {bill, highlight, spawnBill}
local PlayerBills = {} -- userId -> {bill, highlight, helpBill, helpHighlight}
local SpawnTimers = {} -- key -> expireTime (for spawn notify fade-out)
local KnownNpcs  = {} -- gi -> { [gname] -> { [model] = true } }

-- Page state
local CurrentTab    = "npc"   -- "npc" | "players"
local CurrentPage   = "npc_list"
local PageStack     = {}
local CurrentGameIdx = nil
local CurrentGroup  = nil  -- group name string
local MenuOpen      = false
local Minimized     = false

-- ══════════════════════════════════════════
--  PERSISTENCE
-- ══════════════════════════════════════════
local function saveData()
    local ok, enc = pcall(HttpService.JSONEncode, HttpService, {
        npcGames   = NpcGames,
        playerData = PlayerData,
    })
    if ok then pcall(writefile, SAVE_FILE, enc) end
end

local function loadData()
    local ok, raw = pcall(readfile, SAVE_FILE)
    if ok and raw and raw ~= "" then
        local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok2 and data then
            NpcGames   = data.npcGames   or {}
            PlayerData = data.playerData or {}
        end
    end
    -- Ensure all ESP starts OFF
    for _, g in ipairs(NpcGames) do
        for _, grp in pairs(g.groups or {}) do
            grp.espEnabled = false
        end
    end
    for _, pd in pairs(PlayerData) do
        pd.espEnabled = false
    end
    -- Fill missing fields
    for _, g in ipairs(NpcGames) do
        g.groups = g.groups or {}
        for _, grp in pairs(g.groups) do
            local def = defaultGroupSettings()
            for k, v in pairs(def) do
                if grp[k] == nil then grp[k] = v end
            end
        end
    end
end

loadData()

-- ══════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════
local function corner(r, p)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    if p then c.Parent = p end
    return c
end

local function mkStroke(thick, col, p)
    local s = Instance.new("UIStroke")
    s.Thickness = thick
    s.Color     = col or T.stroke
    if p then s.Parent = p end
    return s
end

local function pad(t, b, l, r, p)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 0)
    u.PaddingBottom = UDim.new(0, b or 0)
    u.PaddingLeft   = UDim.new(0, l or 0)
    u.PaddingRight  = UDim.new(0, r or 0)
    if p then u.Parent = p end
end

local function listLayout(spacing, p)
    local l = Instance.new("UIListLayout")
    l.Padding       = UDim.new(0, spacing or 6)
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.FillDirection = Enum.FillDirection.Vertical
    if p then l.Parent = p end
    return l
end

local function scrollFrame(parent, topOff, botOff)
    local s = Instance.new("ScrollingFrame")
    s.Size                  = UDim2.new(1, 0, 1, -(topOff or 0) - (botOff or 0))
    s.Position              = UDim2.new(0, 0, 0, topOff or 0)
    s.BackgroundTransparency = 1
    s.BorderSizePixel       = 0
    s.ScrollBarThickness    = 4
    s.ScrollBarImageColor3  = T.scroll
    s.CanvasSize            = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    s.ScrollingDirection    = Enum.ScrollingDirection.Y
    if parent then s.Parent = parent end
    return s
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local drag, ds, sp = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true ; ds = i.Position ; sp = frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement
                  or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
        end
    end)
end

local function getFont(name)
    local ok, f = pcall(function() return Enum.Font[name or "GothamBold"] end)
    return ok and f or Enum.Font.GothamBold
end

local function getPresetColor(idx)
    return PRESET_COLORS[math.clamp(idx or 1, 1, #PRESET_COLORS)]
end

local function tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

-- ══════════════════════════════════════════
--  SCREEN GUI
-- ══════════════════════════════════════════
if PlayerGui:FindFirstChild("ESPManager") then
    PlayerGui.ESPManager:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name            = "ESPManager"
Gui.ResetOnSpawn    = false
Gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
Gui.DisplayOrder    = 998
Gui.IgnoreGuiInset  = true
Gui.Parent          = PlayerGui

-- ══════════════════════════════════════════
--  TOGGLE BUTTON
-- ══════════════════════════════════════════
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Text             = "👁"
ToggleBtn.Size             = UDim2.new(0, 52, 0, 52)
ToggleBtn.Position         = UDim2.new(0, 80, 0.5, -26)
ToggleBtn.BackgroundColor3 = T.panel
ToggleBtn.TextColor3       = T.text
ToggleBtn.Font             = Enum.Font.GothamBold
ToggleBtn.TextSize         = 24
ToggleBtn.ZIndex           = 10
ToggleBtn.AutoButtonColor  = false
ToggleBtn.Parent           = Gui
corner(14, ToggleBtn)
mkStroke(1.5, T.stroke, ToggleBtn)
makeDraggable(ToggleBtn)

-- ══════════════════════════════════════════
--  MAIN MENU
-- ══════════════════════════════════════════
local Menu = Instance.new("Frame")
Menu.Name               = "Menu"
Menu.Size               = UDim2.new(0.42, 0, 0.60, 0)
Menu.Position           = UDim2.new(0.29, 0, 0.20, 0)
Menu.BackgroundColor3   = T.bg
Menu.BorderSizePixel    = 0
Menu.Visible            = false
Menu.ZIndex             = 5
Menu.Parent             = Gui
corner(12, Menu)
mkStroke(1.5, T.stroke, Menu)

-- Title bar
local TBar = Instance.new("Frame")
TBar.Size             = UDim2.new(1, 0, 0, 42)
TBar.BackgroundColor3 = T.titlebar
TBar.BorderSizePixel  = 0
TBar.ZIndex           = 6
TBar.Parent           = Menu
corner(12, TBar)

-- patch bottom corners
local tbp = Instance.new("Frame")
tbp.Size              = UDim2.new(1, 0, 0.5, 0)
tbp.Position          = UDim2.new(0, 0, 0.5, 0)
tbp.BackgroundColor3  = T.titlebar
tbp.BorderSizePixel   = 0
tbp.ZIndex            = 6
tbp.Parent            = TBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Text           = "  👁  ESP Manager"
TitleLbl.Size           = UDim2.new(1, -118, 1, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3     = T.text
TitleLbl.Font           = Enum.Font.GothamBold
TitleLbl.TextSize       = 13
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.ZIndex         = 7
TitleLbl.Parent         = TBar

makeDraggable(Menu, TBar)

local function makeTitleBtn(icon, rx)
    local b = Instance.new("TextButton")
    b.Text             = icon
    b.Size             = UDim2.new(0, 28, 0, 28)
    b.Position         = UDim2.new(1, rx, 0.5, -14)
    b.BackgroundColor3 = T.item
    b.TextColor3       = T.text
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 12
    b.ZIndex           = 8
    b.AutoButtonColor  = true
    b.Parent           = TBar
    corner(7, b)
    return b
end

local BtnClose    = makeTitleBtn("✕",  -8)
local BtnMinimize = makeTitleBtn("─", -40)
local BtnSettings = makeTitleBtn("⚙", -72)
local BtnBack     = makeTitleBtn("←",-104)
BtnBack.Visible   = false

-- Red separator line under title
local sep = Instance.new("Frame")
sep.Size              = UDim2.new(1, 0, 0, 1)
sep.Position          = UDim2.new(0, 0, 0, 42)
sep.BackgroundColor3  = T.accent
sep.BorderSizePixel   = 0
sep.ZIndex            = 6
sep.Parent            = Menu

-- Tab bar
local TabBar = Instance.new("Frame")
TabBar.Size             = UDim2.new(1, 0, 0, 34)
TabBar.Position         = UDim2.new(0, 0, 0, 43)
TabBar.BackgroundColor3 = T.panel
TabBar.BorderSizePixel  = 0
TabBar.ZIndex           = 6
TabBar.Parent           = Menu

local function makeTab(label, xPos)
    local b = Instance.new("TextButton")
    b.Text             = label
    b.Size             = UDim2.new(0.5, 0, 1, 0)
    b.Position         = UDim2.new(xPos, 0, 0, 0)
    b.BackgroundColor3 = T.tab_idle
    b.TextColor3       = T.text
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 12
    b.ZIndex           = 7
    b.AutoButtonColor  = false
    b.BorderSizePixel  = 0
    b.Parent           = TabBar
    return b
end

local TabNPC     = makeTab("  🤖  NPCs",     0)
local TabPlayers = makeTab("  👤  Players", 0.5)
-- Active indicator bar
local TabIndic = Instance.new("Frame")
TabIndic.Size             = UDim2.new(0.5, 0, 0, 3)
TabIndic.Position         = UDim2.new(0, 0, 1, -3)
TabIndic.BackgroundColor3 = T.accent
TabIndic.BorderSizePixel  = 0
TabIndic.ZIndex           = 8
TabIndic.Parent           = TabBar

-- Content area
local Content = Instance.new("Frame")
Content.Name               = "Content"
Content.Size               = UDim2.new(1, -14, 1, -84)
Content.Position           = UDim2.new(0, 7, 0, 80)
Content.BackgroundTransparency = 1
Content.ClipsDescendants   = true
Content.ZIndex             = 6
Content.Parent             = Menu

-- ══════════════════════════════════════════
--  PAGE HELPERS
-- ══════════════════════════════════════════
local Pages = {}

local function newPage(name)
    local f = Instance.new("Frame")
    f.Name               = name
    f.Size               = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible            = false
    f.ZIndex             = 6
    f.Parent             = Content
    Pages[name]          = f
    return f
end

local function showPage(name)
    for _, f in pairs(Pages) do f.Visible = false end
    if Pages[name] then Pages[name].Visible = true end
    CurrentPage = name
    BtnBack.Visible = (name ~= "npc_list" and name ~= "players")
end

-- ══════════════════════════════════════════
--  PAGE: NPC LIST
-- ══════════════════════════════════════════
local PgNpcList = newPage("npc_list")

local NpcListHeader = Instance.new("Frame")
NpcListHeader.Size             = UDim2.new(1, 0, 0, 32)
NpcListHeader.BackgroundTransparency = 1
NpcListHeader.ZIndex           = 7
NpcListHeader.Parent           = PgNpcList

local NpcListTitle = Instance.new("TextLabel")
NpcListTitle.Text           = "Game Folders"
NpcListTitle.Size           = UDim2.new(1, -40, 1, 0)
NpcListTitle.BackgroundTransparency = 1
NpcListTitle.TextColor3     = T.subtext
NpcListTitle.Font           = Enum.Font.GothamBold
NpcListTitle.TextSize       = 11
NpcListTitle.TextXAlignment = Enum.TextXAlignment.Left
NpcListTitle.ZIndex         = 7
NpcListTitle.Parent         = NpcListHeader

local AddFolderBtn = Instance.new("TextButton")
AddFolderBtn.Text            = "+"
AddFolderBtn.Size            = UDim2.new(0, 30, 0, 30)
AddFolderBtn.Position        = UDim2.new(1, -30, 0, 1)
AddFolderBtn.BackgroundColor3 = T.accent
AddFolderBtn.TextColor3      = T.text
AddFolderBtn.Font            = Enum.Font.GothamBold
AddFolderBtn.TextSize        = 20
AddFolderBtn.ZIndex          = 7
AddFolderBtn.AutoButtonColor = true
AddFolderBtn.Parent          = NpcListHeader
corner(8, AddFolderBtn)

local NpcListScroll = scrollFrame(PgNpcList, 36)
listLayout(6, NpcListScroll)

-- ══════════════════════════════════════════
--  PAGE: NPC FOLDER (groups inside a game)
-- ══════════════════════════════════════════
local PgNpcFolder = newPage("npc_folder")

local FolderTopRow = Instance.new("Frame")
FolderTopRow.Size              = UDim2.new(1, 0, 0, 52)
FolderTopRow.BackgroundTransparency = 1
FolderTopRow.ZIndex            = 7
FolderTopRow.Parent            = PgNpcFolder

local FolderNameLbl = Instance.new("TextLabel")
FolderNameLbl.Text           = "Game Folder"
FolderNameLbl.Size           = UDim2.new(1, 0, 0, 18)
FolderNameLbl.BackgroundTransparency = 1
FolderNameLbl.TextColor3     = T.text
FolderNameLbl.Font           = Enum.Font.GothamBold
FolderNameLbl.TextSize       = 13
FolderNameLbl.TextXAlignment = Enum.TextXAlignment.Left
FolderNameLbl.ZIndex         = 7
FolderNameLbl.Parent         = FolderTopRow

-- Path input row
local PathRow = Instance.new("Frame")
PathRow.Size             = UDim2.new(1, 0, 0, 30)
PathRow.Position         = UDim2.new(0, 0, 0, 20)
PathRow.BackgroundTransparency = 1
PathRow.ZIndex           = 7
PathRow.Parent           = FolderTopRow

local PathBox = Instance.new("TextBox")
PathBox.PlaceholderText   = "Script path  e.g. workspace.Map.Enemies"
PathBox.Text              = ""
PathBox.Size              = UDim2.new(1, -82, 1, 0)
PathBox.BackgroundColor3  = T.item
PathBox.TextColor3        = T.text
PathBox.PlaceholderColor3 = T.subtext
PathBox.Font              = Enum.Font.Gotham
PathBox.TextSize          = 11
PathBox.ClearTextOnFocus  = false
PathBox.ZIndex            = 8
PathBox.Parent            = PathRow
corner(6, PathBox)
pad(0, 0, 8, 0, PathBox)

local ScanBtn = Instance.new("TextButton")
ScanBtn.Text             = "⟳ Scan"
ScanBtn.Size             = UDim2.new(0, 74, 1, 0)
ScanBtn.Position         = UDim2.new(1, -74, 0, 0)
ScanBtn.BackgroundColor3 = T.accent
ScanBtn.TextColor3       = T.text
ScanBtn.Font             = Enum.Font.GothamBold
ScanBtn.TextSize         = 11
ScanBtn.ZIndex           = 8
ScanBtn.AutoButtonColor  = true
ScanBtn.Parent           = PathRow
corner(6, ScanBtn)

local ScanStatus = Instance.new("TextLabel")
ScanStatus.Text           = ""
ScanStatus.Size           = UDim2.new(1, 0, 0, 14)
ScanStatus.Position       = UDim2.new(0, 0, 0, 54)
ScanStatus.BackgroundTransparency = 1
ScanStatus.TextColor3     = T.subtext
ScanStatus.Font           = Enum.Font.Gotham
ScanStatus.TextSize       = 10
ScanStatus.TextXAlignment = Enum.TextXAlignment.Left
ScanStatus.ZIndex         = 7
ScanStatus.Parent         = PgNpcFolder

local GroupListLabel = Instance.new("TextLabel")
GroupListLabel.Text           = "NPC GROUPS"
GroupListLabel.Size           = UDim2.new(1, 0, 0, 16)
GroupListLabel.Position       = UDim2.new(0, 0, 0, 70)
GroupListLabel.BackgroundTransparency = 1
GroupListLabel.TextColor3     = T.subtext
GroupListLabel.Font           = Enum.Font.GothamBold
GroupListLabel.TextSize       = 10
GroupListLabel.TextXAlignment = Enum.TextXAlignment.Left
GroupListLabel.ZIndex         = 7
GroupListLabel.Parent         = PgNpcFolder

local GroupScroll = scrollFrame(PgNpcFolder, 88)
listLayout(6, GroupScroll)

-- ══════════════════════════════════════════
--  PAGE: NPC GROUP SETTINGS
-- ══════════════════════════════════════════
local PgGroupSettings = newPage("npc_group")

local GroupSettingsTitle = Instance.new("TextLabel")
GroupSettingsTitle.Text           = "Group Settings"
GroupSettingsTitle.Size           = UDim2.new(1, 0, 0, 20)
GroupSettingsTitle.BackgroundTransparency = 1
GroupSettingsTitle.TextColor3     = T.text
GroupSettingsTitle.Font           = Enum.Font.GothamBold
GroupSettingsTitle.TextSize       = 13
GroupSettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
GroupSettingsTitle.ZIndex         = 7
GroupSettingsTitle.Parent         = PgGroupSettings

local GroupSettingsScroll = scrollFrame(PgGroupSettings, 24)
listLayout(8, GroupSettingsScroll)

-- ══════════════════════════════════════════
--  PAGE: PLAYERS
-- ══════════════════════════════════════════
local PgPlayers = newPage("players")

local PlayerHeader = Instance.new("Frame")
PlayerHeader.Size              = UDim2.new(1, 0, 0, 32)
PlayerHeader.BackgroundTransparency = 1
PlayerHeader.ZIndex            = 7
PlayerHeader.Parent            = PgPlayers

local SelectAllBtn = Instance.new("TextButton")
SelectAllBtn.Text            = "Select All"
SelectAllBtn.Size            = UDim2.new(0, 80, 0, 26)
SelectAllBtn.BackgroundColor3 = T.item
SelectAllBtn.TextColor3      = T.text
SelectAllBtn.Font            = Enum.Font.GothamBold
SelectAllBtn.TextSize        = 11
SelectAllBtn.ZIndex          = 7
SelectAllBtn.AutoButtonColor = true
SelectAllBtn.Parent          = PlayerHeader
corner(6, SelectAllBtn)
mkStroke(1, T.stroke, SelectAllBtn)

local PlayerSettingsBtn = Instance.new("TextButton")
PlayerSettingsBtn.Text            = "⚙ Settings"
PlayerSettingsBtn.Size            = UDim2.new(0, 90, 0, 26)
PlayerSettingsBtn.Position        = UDim2.new(1, -90, 0, 3)
PlayerSettingsBtn.BackgroundColor3 = T.accent
PlayerSettingsBtn.TextColor3      = T.text
PlayerSettingsBtn.Font            = Enum.Font.GothamBold
PlayerSettingsBtn.TextSize        = 11
PlayerSettingsBtn.ZIndex          = 7
PlayerSettingsBtn.AutoButtonColor = true
PlayerSettingsBtn.Parent          = PlayerHeader
corner(6, PlayerSettingsBtn)

local PlayerListScroll = scrollFrame(PgPlayers, 36)
listLayout(5, PlayerListScroll)

-- ══════════════════════════════════════════
--  PAGE: PLAYER ESP SETTINGS
-- ══════════════════════════════════════════
local PgPlayerSettings = newPage("player_settings")

local PSTitle = Instance.new("TextLabel")
PSTitle.Text           = "Player ESP Settings"
PSTitle.Size           = UDim2.new(1, 0, 0, 20)
PSTitle.BackgroundTransparency = 1
PSTitle.TextColor3     = T.text
PSTitle.Font           = Enum.Font.GothamBold
PSTitle.TextSize       = 13
PSTitle.TextXAlignment = Enum.TextXAlignment.Left
PSTitle.ZIndex         = 7
PSTitle.Parent         = PgPlayerSettings

local PSScroll = scrollFrame(PgPlayerSettings, 24)
listLayout(8, PSScroll)

-- ══════════════════════════════════════════
--  MODAL
-- ══════════════════════════════════════════
local ModalOverlay = Instance.new("Frame")
ModalOverlay.Size               = UDim2.new(1, 0, 1, 0)
ModalOverlay.BackgroundColor3   = Color3.new(0, 0, 0)
ModalOverlay.BackgroundTransparency = 0.5
ModalOverlay.Visible            = false
ModalOverlay.ZIndex             = 20
ModalOverlay.Parent             = Gui

local ModalBox = Instance.new("Frame")
ModalBox.Size             = UDim2.new(0, 280, 0, 155)
ModalBox.Position         = UDim2.new(0.5, -140, 0.5, -77)
ModalBox.BackgroundColor3 = T.panel
ModalBox.BorderSizePixel  = 0
ModalBox.Visible          = false
ModalBox.ZIndex           = 21
ModalBox.Parent           = Gui
corner(12, ModalBox)
mkStroke(1.5, T.stroke, ModalBox)

local ModalTitleLbl = Instance.new("TextLabel")
ModalTitleLbl.Size              = UDim2.new(1, -16, 0, 32)
ModalTitleLbl.Position          = UDim2.new(0, 8, 0, 8)
ModalTitleLbl.BackgroundTransparency = 1
ModalTitleLbl.TextColor3        = T.text
ModalTitleLbl.Font              = Enum.Font.GothamBold
ModalTitleLbl.TextSize          = 13
ModalTitleLbl.TextXAlignment    = Enum.TextXAlignment.Left
ModalTitleLbl.ZIndex            = 22
ModalTitleLbl.Parent            = ModalBox

local ModalInput = Instance.new("TextBox")
ModalInput.Size             = UDim2.new(1, -16, 0, 30)
ModalInput.Position         = UDim2.new(0, 8, 0, 46)
ModalInput.BackgroundColor3 = T.item
ModalInput.TextColor3       = T.text
ModalInput.PlaceholderColor3 = T.subtext
ModalInput.Font             = Enum.Font.Gotham
ModalInput.TextSize         = 12
ModalInput.ClearTextOnFocus = false
ModalInput.ZIndex           = 22
ModalInput.Parent           = ModalBox
corner(6, ModalInput)
pad(0, 0, 10, 0, ModalInput)

local ModalOK = Instance.new("TextButton")
ModalOK.Text             = "OK"
ModalOK.Size             = UDim2.new(0.48, 0, 0, 30)
ModalOK.Position         = UDim2.new(0.52, 0, 1, -38)
ModalOK.BackgroundColor3 = T.accent
ModalOK.TextColor3       = T.text
ModalOK.Font             = Enum.Font.GothamBold
ModalOK.TextSize         = 12
ModalOK.ZIndex           = 22
ModalOK.AutoButtonColor  = true
ModalOK.Parent           = ModalBox
corner(8, ModalOK)

local ModalCancel = Instance.new("TextButton")
ModalCancel.Text            = "Cancel"
ModalCancel.Size            = UDim2.new(0.48, 0, 0, 30)
ModalCancel.Position        = UDim2.new(0, 0, 1, -38)
ModalCancel.BackgroundColor3 = T.item
ModalCancel.TextColor3      = T.text
ModalCancel.Font            = Enum.Font.GothamBold
ModalCancel.TextSize        = 12
ModalCancel.ZIndex          = 22
ModalCancel.AutoButtonColor = true
ModalCancel.Parent          = ModalBox
corner(8, ModalCancel)

local mConn1, mConn2
local function openModal(title, placeholder, onOK, okLabel)
    ModalTitleLbl.Text         = title
    ModalInput.PlaceholderText = placeholder or ""
    ModalInput.Text            = ""
    ModalOK.Text               = okLabel or "OK"
    ModalOverlay.Visible       = true
    ModalBox.Visible           = true
    ModalInput:CaptureFocus()
    if mConn1 then mConn1:Disconnect() end
    if mConn2 then mConn2:Disconnect() end
    mConn1 = ModalOK.MouseButton1Click:Connect(function()
        local t = ModalInput.Text
        ModalBox.Visible     = false
        ModalOverlay.Visible = false
        if onOK then onOK(t) end
    end)
    mConn2 = ModalCancel.MouseButton1Click:Connect(function()
        ModalBox.Visible     = false
        ModalOverlay.Visible = false
    end)
end

-- Confirm dialog
local ConfOv = Instance.new("Frame")
ConfOv.Size               = UDim2.new(1,0,1,0)
ConfOv.BackgroundColor3   = Color3.new(0,0,0)
ConfOv.BackgroundTransparency = 0.5
ConfOv.Visible            = false
ConfOv.ZIndex             = 30
ConfOv.Parent             = Gui

local ConfBox = Instance.new("Frame")
ConfBox.Size              = UDim2.new(0, 285, 0, 130)
ConfBox.Position          = UDim2.new(0.5,-142,0.5,-65)
ConfBox.BackgroundColor3  = T.panel
ConfBox.BorderSizePixel   = 0
ConfBox.Visible           = false
ConfBox.ZIndex            = 31
ConfBox.Parent            = Gui
corner(12, ConfBox)
mkStroke(1.5, T.stroke, ConfBox)

local ConfMsg = Instance.new("TextLabel")
ConfMsg.Text              = "Close ESP Manager?\nAll active ESP will be removed."
ConfMsg.Size              = UDim2.new(1,-20,0,60)
ConfMsg.Position          = UDim2.new(0,10,0,10)
ConfMsg.BackgroundTransparency = 1
ConfMsg.TextColor3        = T.text
ConfMsg.Font              = Enum.Font.Gotham
ConfMsg.TextSize          = 12
ConfMsg.TextWrapped       = true
ConfMsg.ZIndex            = 32
ConfMsg.Parent            = ConfBox

local ConfYes = Instance.new("TextButton")
ConfYes.Text              = "Close"
ConfYes.Size              = UDim2.new(0.48,0,0,30)
ConfYes.Position          = UDim2.new(0.52,0,1,-38)
ConfYes.BackgroundColor3  = T.danger
ConfYes.TextColor3        = T.text
ConfYes.Font              = Enum.Font.GothamBold
ConfYes.TextSize          = 12
ConfYes.ZIndex            = 32
ConfYes.AutoButtonColor   = true
ConfYes.Parent            = ConfBox
corner(8, ConfYes)

local ConfNo = Instance.new("TextButton")
ConfNo.Text               = "Cancel"
ConfNo.Size               = UDim2.new(0.48,0,0,30)
ConfNo.Position           = UDim2.new(0,0,1,-38)
ConfNo.BackgroundColor3   = T.item
ConfNo.TextColor3         = T.text
ConfNo.Font               = Enum.Font.GothamBold
ConfNo.TextSize           = 12
ConfNo.ZIndex             = 32
ConfNo.AutoButtonColor    = true
ConfNo.Parent             = ConfBox
corner(8, ConfNo)

ConfNo.MouseButton1Click:Connect(function()
    ConfOv.Visible  = false
    ConfBox.Visible = false
end)

-- Context menu
local CtxMenu = Instance.new("Frame")
CtxMenu.Size             = UDim2.new(0, 128, 0, 68)
CtxMenu.BackgroundColor3 = T.panel
CtxMenu.BorderSizePixel  = 0
CtxMenu.Visible          = false
CtxMenu.ZIndex           = 35
CtxMenu.Parent           = Gui
corner(8, CtxMenu)
mkStroke(1.5, T.stroke, CtxMenu)
listLayout(0, CtxMenu)

local function ctxItem(label, col)
    local b = Instance.new("TextButton")
    b.Text             = label
    b.Size             = UDim2.new(1,0,0,34)
    b.BackgroundColor3 = T.panel
    b.TextColor3       = col or T.text
    b.Font             = Enum.Font.Gotham
    b.TextSize         = 12
    b.ZIndex           = 36
    b.AutoButtonColor  = true
    b.Parent           = CtxMenu
    b.TextXAlignment   = Enum.TextXAlignment.Left
    pad(0,0,12,0,b)
    return b
end
local CtxRename = ctxItem("✏  Rename")
local CtxDelete = ctxItem("🗑  Delete", T.danger)

local function closeCtx() CtxMenu.Visible = false end

UserInputService.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        task.wait()
        if CtxMenu.Visible then
            local mp = i.Position
            local ap = CtxMenu.AbsolutePosition
            local as = CtxMenu.AbsoluteSize
            if mp.X < ap.X or mp.X > ap.X+as.X or mp.Y < ap.Y or mp.Y > ap.Y+as.Y then
                closeCtx()
            end
        end
    end
end)

-- ══════════════════════════════════════════
--  ESP RENDERING HELPERS
-- ══════════════════════════════════════════
local function getCharRoot(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChildWhichIsA("BasePart")
end

local function getHumanoid(model)
    return model:FindFirstChildWhichIsA("Humanoid")
end

local function makeHighlight(parent, fillCol, outlineCol, fillTrans, outlineTrans)
    local h = Instance.new("Highlight")
    h.FillColor           = fillCol     or Color3.new(1,1,1)
    h.OutlineColor        = outlineCol  or Color3.new(1,1,1)
    h.FillTransparency    = fillTrans   or 0.6
    h.OutlineTransparency = outlineTrans or 0
    h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent              = parent
    return h
end

local function makeBillboard(root, espName, espDist, color, font)
    if not root then return nil end
    local bill = Instance.new("BillboardGui")
    bill.Size        = UDim2.new(0, 160, 0, 52)
    bill.StudsOffset = Vector3.new(0, 3.2, 0)
    bill.AlwaysOnTop = true
    bill.LightInfluence = 0
    bill.Parent      = root

    if espName then
        local nl = Instance.new("TextLabel")
        nl.Name              = "NameLbl"
        nl.Size              = UDim2.new(1,0,0.55,0)
        nl.BackgroundTransparency = 1
        nl.TextColor3        = color or Color3.new(1,1,1)
        nl.Font              = font  or Enum.Font.GothamBold
        nl.TextSize          = 15
        nl.TextStrokeTransparency = 0.5
        nl.TextStrokeColor3  = Color3.new(0,0,0)
        nl.Text              = root.Parent and root.Parent.Name or "?"
        nl.ZIndex            = 2
        nl.Parent            = bill
    end

    if espDist then
        local dl = Instance.new("TextLabel")
        dl.Name              = "DistLbl"
        dl.Size              = UDim2.new(1,0,0.45,0)
        dl.Position          = UDim2.new(0,0,0.55,0)
        dl.BackgroundTransparency = 1
        dl.TextColor3        = color or Color3.new(1,1,1)
        dl.Font              = font  or Enum.Font.GothamBold
        dl.TextSize          = 12
        dl.TextStrokeTransparency = 0.6
        dl.TextStrokeColor3  = Color3.new(0,0,0)
        dl.Text              = "0 studs"
        dl.ZIndex            = 2
        dl.Parent            = bill
    end

    return bill
end

-- Notification billboard (spawn notify / help)
local function makeNotifyBill(root, text, color, font, yOffset)
    if not root then return nil end
    local bill = Instance.new("BillboardGui")
    bill.Size        = UDim2.new(0, 140, 0, 36)
    bill.StudsOffset = Vector3.new(0, yOffset or 5.5, 0)
    bill.AlwaysOnTop = true
    bill.LightInfluence = 0
    bill.Parent      = root

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3        = color or Color3.new(1,1,1)
    lbl.Font              = font  or Enum.Font.GothamBold
    lbl.TextSize          = 18
    lbl.TextStrokeTransparency = 0.4
    lbl.TextStrokeColor3  = Color3.new(0,0,0)
    lbl.Text              = text or "⚠️"
    lbl.ZIndex            = 2
    lbl.Parent            = bill

    return bill
end

local function applyFade(bill, highlight, dist, settings, isHelp)
    local maxOp  = settings.maxOpacity  or 1
    local farD   = isHelp and (settings.helpFadeDist or 150) or (settings.fadeStudDist or 200)
    local farND  = settings.fadeNameDist  or farD
    local closeD = settings.fadeCloseDist or 8
    local closeND = settings.fadeCloseNameDist or closeD

    local function calcAlpha(d, farDist, closeDist)
        if d > farDist then return 1 end
        if closeDist > 0 and d < closeDist then
            return math.clamp(1 - (d / closeDist * maxOp), 0, 1)
        end
        if d > farDist * 0.8 then
            return math.clamp((d - farDist*0.8) / (farDist*0.2), 0, 1)
        end
        return 1 - maxOp
    end

    local baseA = calcAlpha(dist, farD, closeD)
    local nameA = calcAlpha(dist, farND, closeND)

    if bill then
        local nl = bill:FindFirstChild("NameLbl")
        local dl = bill:FindFirstChild("DistLbl")
        if nl then
            nl.TextTransparency       = nameA
            nl.TextStrokeTransparency = math.min(nameA + 0.4, 1)
        end
        if dl then
            dl.TextTransparency       = baseA
            dl.TextStrokeTransparency = math.min(baseA + 0.4, 1)
        end
        -- single label bills (notify)
        local sl = bill:FindFirstChildWhichIsA("TextLabel")
        if sl and not nl and not dl then
            sl.TextTransparency       = baseA
            sl.TextStrokeTransparency = math.min(baseA + 0.4, 1)
        end
    end

    if highlight then
        highlight.FillTransparency    = math.clamp(baseA + 0.4, 0, 1)
        highlight.OutlineTransparency = math.clamp(baseA - 0.05, 0, 1)
    end
end

-- ══════════════════════════════════════════
--  NPC SCANNING
-- ══════════════════════════════════════════
local playerChars = {}
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c) playerChars[c] = true end)
    p.CharacterRemoving:Connect(function(c) playerChars[c] = nil end)
    if p.Character then playerChars[p.Character] = true end
end)
Players.PlayerRemoving:Connect(function(p)
    if p.Character then playerChars[p.Character] = nil end
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then playerChars[p.Character] = true end
    p.CharacterAdded:Connect(function(c) playerChars[c] = true end)
end

local function isPlayerChar(model)
    return playerChars[model] == true
end

local function scanForNpcs(root)
    local found = {} -- { [name] = { model, model, ... } }
    local function recurse(inst)
        if inst:IsA("Model") and not isPlayerChar(inst) then
            local hum = inst:FindFirstChildWhichIsA("Humanoid")
            if hum then
                local n = inst.Name
                if not found[n] then found[n] = {} end
                table.insert(found[n], inst)
                return -- don't recurse into found model
            end
        end
        for _, c in ipairs(inst:GetChildren()) do
            recurse(c)
        end
    end
    recurse(root)
    return found
end

local function resolveScriptPath(pathStr)
    if not pathStr or pathStr == "" then return nil end
    local result = game
    for part in string.gmatch(pathStr, "[^%.]+") do
        if part == "game" then
            result = game
        else
            local ok, child = pcall(function() return result:FindFirstChild(part) end)
            if ok and child then
                result = child
            else
                return nil
            end
        end
    end
    return result
end

-- ══════════════════════════════════════════
--  ACTIVE ESP TRACKING
-- ══════════════════════════════════════════
-- NPC ESP: keyed by "gi_gname" -> table of {model, bill, highlight, spawnBill}
local NpcESPActive    = {} -- "gi_gname" -> { [model] = { bill, hl, helpBill, helpHl } }
local SpawnKnown      = {} -- "gi_gname" -> { [model] = true }
local SpawnNotifBills = {} -- model -> {bill, expireAt}

local function removeNpcESP(gi, gname)
    local key = tostring(gi).."_"..gname
    if NpcESPActive[key] then
        for model, data in pairs(NpcESPActive[key]) do
            if data.bill       and data.bill.Parent       then data.bill:Destroy() end
            if data.hl         and data.hl.Parent         then data.hl:Destroy() end
            if data.helpBill   and data.helpBill.Parent   then data.helpBill:Destroy() end
            if data.helpHl     and data.helpHl.Parent     then data.helpHl:Destroy() end
        end
        NpcESPActive[key] = nil
    end
end

local function removeAllNpcESP()
    for key, tbl in pairs(NpcESPActive) do
        for _, data in pairs(tbl) do
            pcall(function()
                if data.bill     then data.bill:Destroy() end
                if data.hl       then data.hl:Destroy() end
                if data.helpBill then data.helpBill:Destroy() end
                if data.helpHl   then data.helpHl:Destroy() end
            end)
        end
    end
    NpcESPActive = {}
    for _, b in pairs(SpawnNotifBills) do
        pcall(function() if b.bill then b.bill:Destroy() end end)
    end
    SpawnNotifBills = {}
end

local function removeAllPlayerESP()
    for uid, data in pairs(PlayerBills) do
        pcall(function()
            if data.bill     then data.bill:Destroy() end
            if data.hl       then data.hl:Destroy() end
            if data.helpBill then data.helpBill:Destroy() end
            if data.helpHl   then data.helpHl:Destroy() end
        end)
    end
    PlayerBills = {}
end

local function applyNpcGroupESP(gi, gname, models)
    local g   = NpcGames[gi]
    if not g then return end
    local grp = g.groups and g.groups[gname]
    if not grp or not grp.espEnabled then return end

    local key    = tostring(gi).."_"..gname
    if not NpcESPActive[key] then NpcESPActive[key] = {} end

    local color  = getPresetColor(grp.colorIndex)
    local font   = getFont(grp.font)

    for _, model in ipairs(models) do
        if not NpcESPActive[key][model] then
            local root = getCharRoot(model)
            if root then
                local bill, hl
                if grp.espName or grp.espDistance then
                    bill = makeBillboard(root, grp.espName, grp.espDistance, color, font)
                    if bill and grp.espName then
                        local nl = bill:FindFirstChild("NameLbl")
                        if nl then nl.Text = model.Name end
                    end
                end
                if grp.espOutline or grp.espFullBody then
                    local ft = grp.espFullBody and 0.5 or 1
                    hl = makeHighlight(model, color, color, ft, 0)
                end
                NpcESPActive[key][model] = { bill=bill, hl=hl, helpBill=nil, helpHl=nil }
                -- cleanup on remove
                model.AncestryChanged:Connect(function()
                    if not model.Parent then
                        local d = NpcESPActive[key] and NpcESPActive[key][model]
                        if d then
                            pcall(function() if d.bill   then d.bill:Destroy()   end end)
                            pcall(function() if d.hl     then d.hl:Destroy()     end end)
                            pcall(function() if d.helpBill then d.helpBill:Destroy() end end)
                            pcall(function() if d.helpHl   then d.helpHl:Destroy()   end end)
                            if NpcESPActive[key] then NpcESPActive[key][model] = nil end
                        end
                    end
                end)
            end
        end
    end
end

-- ══════════════════════════════════════════
--  SETTINGS PANEL BUILDER (shared for NPC groups and Player)
-- ══════════════════════════════════════════
local function sectionLbl(text, parent)
    local l = Instance.new("TextLabel")
    l.Text           = text
    l.Size           = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.TextColor3     = T.accent
    l.Font           = Enum.Font.GothamBold
    l.TextSize       = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex         = 7
    l.Parent         = parent
    return l
end

local function makeToggleRow(label, initState, parent, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,38)
    row.BackgroundColor3 = T.item
    row.BorderSizePixel  = 0
    row.ZIndex           = 7
    row.Parent           = parent
    corner(8, row)

    local lbl = Instance.new("TextLabel")
    lbl.Text             = label
    lbl.Size             = UDim2.new(1,-56,1,0)
    lbl.Position         = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3       = T.text
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 12
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 8
    lbl.Parent           = row

    local togBg = Instance.new("Frame")
    togBg.Size             = UDim2.new(0,36,0,20)
    togBg.Position         = UDim2.new(1,-46,0.5,-10)
    togBg.BackgroundColor3 = initState and T.tog_on or T.tog_off
    togBg.BorderSizePixel  = 0
    togBg.ZIndex           = 8
    togBg.Parent           = row
    corner(10, togBg)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0,16,0,16)
    dot.Position         = UDim2.new(initState and 1 or 0, initState and -18 or 2, 0.5,-8)
    dot.BackgroundColor3 = Color3.new(1,1,1)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 9
    dot.Parent           = togBg
    corner(8, dot)

    local state = initState
    local btn = Instance.new("TextButton")
    btn.Size               = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text               = ""
    btn.ZIndex             = 10
    btn.Parent             = togBg
    btn.MouseButton1Click:Connect(function()
        state = not state
        togBg.BackgroundColor3 = state and T.tog_on or T.tog_off
        tw(dot, {Position = UDim2.new(state and 1 or 0, state and -18 or 2, 0.5,-8)}, 0.12)
        if onChange then onChange(state) end
    end)
    return row
end

local function makeNumberRow(label, initVal, parent, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,50)
    row.BackgroundColor3 = T.item
    row.BorderSizePixel  = 0
    row.ZIndex           = 7
    row.Parent           = parent
    corner(8, row)

    local lbl = Instance.new("TextLabel")
    lbl.Text             = label
    lbl.Size             = UDim2.new(1,-12,0,18)
    lbl.Position         = UDim2.new(0,12,0,5)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3       = T.subtext
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 10
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 8
    lbl.Parent           = row

    local box = Instance.new("TextBox")
    box.Text             = tostring(initVal)
    box.Size             = UDim2.new(1,-24,0,24)
    box.Position         = UDim2.new(0,12,0,22)
    box.BackgroundColor3 = T.bg
    box.TextColor3       = T.text
    box.Font             = Enum.Font.Gotham
    box.TextSize         = 12
    box.ZIndex           = 8
    box.Parent           = row
    corner(6, box)
    pad(0,0,8,0,box)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            box.Text = tostring(n)
            if onChange then onChange(n) end
        else
            box.Text = tostring(initVal)
        end
    end)
    return row
end

local function makeColorRow(label, initIdx, parent, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,52)
    row.BackgroundColor3 = T.item
    row.BorderSizePixel  = 0
    row.ZIndex           = 7
    row.Parent           = parent
    corner(8, row)

    local lbl = Instance.new("TextLabel")
    lbl.Text             = label
    lbl.Size             = UDim2.new(1,-12,0,16)
    lbl.Position         = UDim2.new(0,12,0,4)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3       = T.subtext
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 10
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 8
    lbl.Parent           = row

    local swatchRow = Instance.new("Frame")
    swatchRow.Size             = UDim2.new(1,-24,0,22)
    swatchRow.Position         = UDim2.new(0,12,0,22)
    swatchRow.BackgroundTransparency = 1
    swatchRow.ZIndex           = 8
    swatchRow.Parent           = row

    local swatches = {}
    for i, col in ipairs(PRESET_COLORS) do
        local sw = Instance.new("TextButton")
        sw.Size             = UDim2.new(0, 18, 1, 0)
        sw.Position         = UDim2.new(0, (i-1)*22, 0, 0)
        sw.BackgroundColor3 = col
        sw.Text             = i == initIdx and "✓" or ""
        sw.TextColor3       = Color3.new(0,0,0)
        sw.Font             = Enum.Font.GothamBold
        sw.TextSize         = 10
        sw.ZIndex           = 9
        sw.AutoButtonColor  = false
        sw.Parent           = swatchRow
        corner(4, sw)
        if i == initIdx then mkStroke(2, Color3.new(1,1,1), sw) end
        swatches[i] = sw
        local ci = i
        sw.MouseButton1Click:Connect(function()
            for j, s2 in ipairs(swatches) do
                s2.Text = ""
                local st = s2:FindFirstChildWhichIsA("UIStroke")
                if st then st:Destroy() end
            end
            sw.Text = "✓"
            mkStroke(2, Color3.new(1,1,1), sw)
            if onChange then onChange(ci) end
        end)
    end
    return row
end

local function makeFontRow(label, initFont, parent, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,42)
    row.BackgroundColor3 = T.item
    row.BorderSizePixel  = 0
    row.ZIndex           = 7
    row.Parent           = parent
    corner(8, row)

    local idx = 1
    for i, f in ipairs(FONTS) do if f == initFont then idx = i break end end

    local lbl = Instance.new("TextLabel")
    lbl.Text             = "Font: " .. (initFont or "GothamBold")
    lbl.Size             = UDim2.new(1,-70,1,0)
    lbl.Position         = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3       = T.text
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 12
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 8
    lbl.Parent           = row

    local prev = Instance.new("TextButton")
    prev.Text             = "◀"
    prev.Size             = UDim2.new(0,26,0,26)
    prev.Position         = UDim2.new(1,-60,0.5,-13)
    prev.BackgroundColor3 = T.bg
    prev.TextColor3       = T.text
    prev.Font             = Enum.Font.GothamBold
    prev.TextSize         = 13
    prev.ZIndex           = 8
    prev.AutoButtonColor  = true
    prev.Parent           = row
    corner(6, prev)

    local nxt = Instance.new("TextButton")
    nxt.Text             = "▶"
    nxt.Size             = UDim2.new(0,26,0,26)
    nxt.Position         = UDim2.new(1,-30,0.5,-13)
    nxt.BackgroundColor3 = T.bg
    nxt.TextColor3       = T.text
    nxt.Font             = Enum.Font.GothamBold
    nxt.TextSize         = 13
    nxt.ZIndex           = 8
    nxt.AutoButtonColor  = true
    nxt.Parent           = row
    corner(6, nxt)

    prev.MouseButton1Click:Connect(function()
        idx = ((idx-2) % #FONTS)+1
        lbl.Text = "Font: "..FONTS[idx]
        if onChange then onChange(FONTS[idx]) end
    end)
    nxt.MouseButton1Click:Connect(function()
        idx = (idx % #FONTS)+1
        lbl.Text = "Font: "..FONTS[idx]
        if onChange then onChange(FONTS[idx]) end
    end)
    return row
end

local function makeESPTypeRow(grp, parent, onAnyChange)
    local types = {
        {key="espName",     label="Name"},
        {key="espDistance", label="Distance"},
        {key="espOutline",  label="Outline"},
        {key="espFullBody", label="Full Body"},
    }
    local outer = Instance.new("Frame")
    outer.Size             = UDim2.new(1,0,0,38)
    outer.BackgroundColor3 = T.item
    outer.BorderSizePixel  = 0
    outer.ZIndex           = 7
    outer.Parent           = parent
    corner(8, outer)

    local lbl = Instance.new("TextLabel")
    lbl.Text           = "ESP Type"
    lbl.Size           = UDim2.new(0,60,1,0)
    lbl.Position       = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3     = T.subtext
    lbl.Font           = Enum.Font.Gotham
    lbl.TextSize       = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex         = 8
    lbl.Parent         = outer

    for i, t in ipairs(types) do
        local pill = Instance.new("TextButton")
        pill.Text             = t.label
        pill.Size             = UDim2.new(0, 60, 0, 22)
        pill.Position         = UDim2.new(0, 64 + (i-1)*66, 0.5, -11)
        pill.BackgroundColor3 = grp[t.key] and T.accent or T.bg
        pill.TextColor3       = T.text
        pill.Font             = Enum.Font.GothamBold
        pill.TextSize         = 10
        pill.ZIndex           = 8
        pill.AutoButtonColor  = false
        pill.Parent           = outer
        corner(6, pill)
        local key = t.key
        pill.MouseButton1Click:Connect(function()
            grp[key] = not grp[key]
            pill.BackgroundColor3 = grp[key] and T.accent or T.bg
            if onAnyChange then onAnyChange() end
        end)
    end
    return outer
end

-- Build full settings panel for a group/player settings table
local function buildSettingsPanel(scrollParent, settings, isPlayer, onChanged)
    for _, c in ipairs(scrollParent:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end

    sectionLbl("  ESP", scrollParent)

    makeToggleRow("Enable ESP", settings.espEnabled, scrollParent, function(v)
        settings.espEnabled = v
        if onChanged then onChanged() end
    end)

    makeESPTypeRow(settings, scrollParent, function()
        saveData()
        if onChanged then onChanged() end
    end)

    makeColorRow("ESP Color", settings.colorIndex, scrollParent, function(idx)
        settings.colorIndex = idx ; saveData()
        if onChanged then onChanged() end
    end)

    makeFontRow("Font", settings.font, scrollParent, function(f)
        settings.font = f ; saveData()
        if onChanged then onChanged() end
    end)

    sectionLbl("  FADE & OPACITY", scrollParent)

    makeNumberRow("Fade Stud Distance (fully hidden beyond X studs)", settings.fadeStudDist, scrollParent, function(v)
        settings.fadeStudDist = v ; saveData()
    end)
    makeNumberRow("Fade Name Distance (name hidden beyond X studs)", settings.fadeNameDist, scrollParent, function(v)
        settings.fadeNameDist = v ; saveData()
    end)
    makeNumberRow("Fade Closing Distance (fades when closer than X studs)", settings.fadeCloseDist, scrollParent, function(v)
        settings.fadeCloseDist = v ; saveData()
    end)
    makeNumberRow("Fade Closing Name Distance", settings.fadeCloseNameDist, scrollParent, function(v)
        settings.fadeCloseNameDist = v ; saveData()
    end)
    makeNumberRow("Max Opacity  (0.0 – 1.0)", settings.maxOpacity, scrollParent, function(v)
        settings.maxOpacity = math.clamp(v, 0, 1) ; saveData()
    end)

    if isPlayer then
        -- HELP notify (green body + HELP label)
        sectionLbl("  PLAYER HELP NOTIFY", scrollParent)
        makeToggleRow("Enable Help Notify", settings.helpEnabled, scrollParent, function(v)
            settings.helpEnabled = v ; saveData()
        end)
        makeNumberRow("HP Threshold (notify when HP below X)", settings.helpHP, scrollParent, function(v)
            settings.helpHP = v ; saveData()
        end)
        makeNumberRow("Help Fade Distance (studs)", settings.helpFadeDist, scrollParent, function(v)
            settings.helpFadeDist = v ; saveData()
        end)
    else
        -- NPC Help notify
        sectionLbl("  NPC HELP NOTIFY", scrollParent)
        makeToggleRow("Enable Help Notify", settings.helpEnabled, scrollParent, function(v)
            settings.helpEnabled = v ; saveData()
        end)
        makeNumberRow("HP Threshold (notify when HP below X)", settings.helpHP, scrollParent, function(v)
            settings.helpHP = v ; saveData()
        end)
        makeNumberRow("Help Fade Distance (studs)", settings.helpFadeDist, scrollParent, function(v)
            settings.helpFadeDist = v ; saveData()
        end)

        -- Spawn notify
        sectionLbl("  NPC SPAWN NOTIFIER", scrollParent)
        makeToggleRow("Enable Spawn Notify", settings.spawnEnabled, scrollParent, function(v)
            settings.spawnEnabled = v ; saveData()
        end)

        local emojiRow = Instance.new("Frame")
        emojiRow.Size             = UDim2.new(1,0,0,42)
        emojiRow.BackgroundColor3 = T.item
        emojiRow.BorderSizePixel  = 0
        emojiRow.ZIndex           = 7
        emojiRow.Parent           = scrollParent
        corner(8, emojiRow)
        local eLabel = Instance.new("TextLabel")
        eLabel.Text           = "Spawn Emoji"
        eLabel.Size           = UDim2.new(0.5,0,0,16)
        eLabel.Position       = UDim2.new(0,12,0,4)
        eLabel.BackgroundTransparency = 1
        eLabel.TextColor3     = T.subtext
        eLabel.Font           = Enum.Font.Gotham
        eLabel.TextSize       = 10
        eLabel.TextXAlignment = Enum.TextXAlignment.Left
        eLabel.ZIndex         = 8
        eLabel.Parent         = emojiRow
        local eBox = Instance.new("TextBox")
        eBox.Text             = settings.spawnEmoji or "⚠️"
        eBox.Size             = UDim2.new(0,60,0,24)
        eBox.Position         = UDim2.new(0,12,0,16)
        eBox.BackgroundColor3 = T.bg
        eBox.TextColor3       = T.text
        eBox.Font             = Enum.Font.Gotham
        eBox.TextSize         = 14
        eBox.ZIndex           = 8
        eBox.Parent           = emojiRow
        corner(6, eBox)
        pad(0,0,6,0,eBox)
        eBox.FocusLost:Connect(function()
            settings.spawnEmoji = eBox.Text ~= "" and eBox.Text or "⚠️"
            saveData()
        end)

        makeNumberRow("Spawn Notify Duration (seconds)", settings.spawnDuration, scrollParent, function(v)
            settings.spawnDuration = math.max(v, 1) ; saveData()
        end)
        makeNumberRow("Spawn Notify Fade Distance (studs)", settings.spawnFadeDist, scrollParent, function(v)
            settings.spawnFadeDist = v ; saveData()
        end)
        makeColorRow("Spawn Notify Color", settings.spawnColorIndex, scrollParent, function(idx)
            settings.spawnColorIndex = idx ; saveData()
        end)
        makeFontRow("Spawn Notify Font", settings.spawnFont, scrollParent, function(f)
            settings.spawnFont = f ; saveData()
        end)
    end
end

-- ══════════════════════════════════════════
--  RENDER: NPC LIST PAGE
-- ══════════════════════════════════════════
local function renderNpcList()
    for _, c in ipairs(NpcListScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for gi, g in ipairs(NpcGames) do
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1,0,0,44)
        row.BackgroundColor3 = T.item
        row.BorderSizePixel  = 0
        row.ZIndex           = 7
        row.Parent           = NpcListScroll
        corner(8, row)

        -- Red left accent bar
        local bar = Instance.new("Frame")
        bar.Size             = UDim2.new(0,3,1,-8)
        bar.Position         = UDim2.new(0,0,0,4)
        bar.BackgroundColor3 = T.accent
        bar.BorderSizePixel  = 0
        bar.ZIndex           = 8
        bar.Parent           = row
        corner(2, bar)

        local nameLbl = Instance.new("TextButton")
        nameLbl.Text           = "📁  "..g.name
        nameLbl.Size           = UDim2.new(1,-42,0.6,0)
        nameLbl.Position       = UDim2.new(0,12,0,4)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextColor3     = T.text
        nameLbl.Font           = Enum.Font.GothamBold
        nameLbl.TextSize       = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ZIndex         = 8
        nameLbl.AutoButtonColor = false
        nameLbl.Parent         = row

        local grpCount = 0
        for _ in pairs(g.groups or {}) do grpCount = grpCount + 1 end
        local subLbl = Instance.new("TextLabel")
        subLbl.Text           = tostring(grpCount).." group"..(grpCount~=1 and "s" or "")
        subLbl.Size           = UDim2.new(1,-42,0.4,0)
        subLbl.Position       = UDim2.new(0,12,0.6,0)
        subLbl.BackgroundTransparency = 1
        subLbl.TextColor3     = T.subtext
        subLbl.Font           = Enum.Font.Gotham
        subLbl.TextSize       = 10
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.ZIndex         = 8
        subLbl.Parent         = row

        local dotsBtn = Instance.new("TextButton")
        dotsBtn.Text           = "⋮"
        dotsBtn.Size           = UDim2.new(0,32,1,0)
        dotsBtn.Position       = UDim2.new(1,-32,0,0)
        dotsBtn.BackgroundTransparency = 1
        dotsBtn.TextColor3     = T.subtext
        dotsBtn.Font           = Enum.Font.GothamBold
        dotsBtn.TextSize       = 18
        dotsBtn.ZIndex         = 8
        dotsBtn.AutoButtonColor = false
        dotsBtn.Parent         = row

        local cgi = gi
        nameLbl.MouseButton1Click:Connect(function()
            CurrentGameIdx = cgi
            FolderNameLbl.Text = "📁  "..NpcGames[cgi].name
            PathBox.Text       = NpcGames[cgi].path or ""
            ScanStatus.Text    = ""
            showPage("npc_folder")
            renderGroupList()
        end)

        dotsBtn.MouseButton1Click:Connect(function()
            local ap = dotsBtn.AbsolutePosition
            CtxMenu.Position = UDim2.new(0, ap.X-128, 0, ap.Y+30)
            CtxMenu.Visible  = true
            closeCtx() ; CtxMenu.Visible = true
            local rc = CtxRename.MouseButton1Click:Connect(function()
                closeCtx()
                openModal("Rename Folder", "New name...", function(n)
                    if n ~= "" then
                        NpcGames[cgi].name = n ; saveData() ; renderNpcList()
                    end
                end)
            end)
            local dc = CtxDelete.MouseButton1Click:Connect(function()
                closeCtx()
                removeNpcESP(cgi, "*")
                for gn in pairs(NpcGames[cgi].groups or {}) do
                    removeNpcESP(cgi, gn)
                end
                table.remove(NpcGames, cgi)
                saveData() ; renderNpcList()
            end)
        end)
    end
end

-- ══════════════════════════════════════════
--  RENDER: GROUP LIST (inside folder)
-- ══════════════════════════════════════════
function renderGroupList()
    if not CurrentGameIdx then return end
    for _, c in ipairs(GroupScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local g = NpcGames[CurrentGameIdx]
    if not g then return end

    local groupCount = 0
    for gname, grp in pairs(g.groups or {}) do
        groupCount = groupCount + 1
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1,0,0,44)
        row.BackgroundColor3 = T.item
        row.BorderSizePixel  = 0
        row.ZIndex           = 7
        row.Parent           = GroupScroll
        corner(8, row)

        -- Colored dot
        local dot = Instance.new("Frame")
        dot.Size             = UDim2.new(0,8,0,8)
        dot.Position         = UDim2.new(0,10,0.5,-4)
        dot.BackgroundColor3 = getPresetColor(grp.colorIndex)
        dot.BorderSizePixel  = 0
        dot.ZIndex           = 8
        dot.Parent           = row
        corner(4, dot)

        local nameLbl = Instance.new("TextButton")
        nameLbl.Text           = gname
        nameLbl.Size           = UDim2.new(1,-80,0.6,0)
        nameLbl.Position       = UDim2.new(0,26,0,4)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextColor3     = T.text
        nameLbl.Font           = Enum.Font.GothamBold
        nameLbl.TextSize       = 12
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ZIndex         = 8
        nameLbl.AutoButtonColor = false
        nameLbl.Parent         = row

        local stateLbl = Instance.new("TextLabel")
        stateLbl.Text         = grp.espEnabled and "● ON" or "○ OFF"
        stateLbl.Size         = UDim2.new(1,-80,0.4,0)
        stateLbl.Position     = UDim2.new(0,26,0.6,0)
        stateLbl.BackgroundTransparency = 1
        stateLbl.TextColor3   = grp.espEnabled and T.tog_on or T.subtext
        stateLbl.Font         = Enum.Font.GothamBold
        stateLbl.TextSize     = 10
        stateLbl.TextXAlignment = Enum.TextXAlignment.Left
        stateLbl.ZIndex       = 8
        stateLbl.Parent       = row

        local dotsBtn = Instance.new("TextButton")
        dotsBtn.Text           = "⋮"
        dotsBtn.Size           = UDim2.new(0,32,1,0)
        dotsBtn.Position       = UDim2.new(1,-32,0,0)
        dotsBtn.BackgroundTransparency = 1
        dotsBtn.TextColor3     = T.subtext
        dotsBtn.Font           = Enum.Font.GothamBold
        dotsBtn.TextSize       = 18
        dotsBtn.ZIndex         = 8
        dotsBtn.AutoButtonColor = false
        dotsBtn.Parent         = row

        local cgi = CurrentGameIdx
        local cgn = gname

        nameLbl.MouseButton1Click:Connect(function()
            CurrentGroup = cgn
            GroupSettingsTitle.Text = "  🤖  "..cgn.." Settings"
            buildSettingsPanel(GroupSettingsScroll, NpcGames[cgi].groups[cgn], false, function()
                -- Refresh ESP if enabled state changed
            end)
            showPage("npc_group")
        end)

        dotsBtn.MouseButton1Click:Connect(function()
            local ap = dotsBtn.AbsolutePosition
            CtxMenu.Position = UDim2.new(0, ap.X-128, 0, ap.Y+30)
            CtxMenu.Visible  = true
            closeCtx() ; CtxMenu.Visible = true
            local rc = CtxRename.MouseButton1Click:Connect(function()
                closeCtx()
                openModal("Rename Group", "New name...", function(n)
                    if n ~= "" and n ~= cgn then
                        local g2 = NpcGames[cgi]
                        g2.groups[n] = g2.groups[cgn]
                        g2.groups[cgn] = nil
                        saveData() ; renderGroupList()
                    end
                end)
            end)
            local dc = CtxDelete.MouseButton1Click:Connect(function()
                closeCtx()
                removeNpcESP(cgi, cgn)
                NpcGames[cgi].groups[cgn] = nil
                saveData() ; renderGroupList()
            end)
        end)
    end

    if groupCount == 0 then
        local empty = Instance.new("TextLabel")
        empty.Text           = "No groups yet. Use Scan or enter a path above."
        empty.Size           = UDim2.new(1,0,0,40)
        empty.BackgroundTransparency = 1
        empty.TextColor3     = T.subtext
        empty.Font           = Enum.Font.Gotham
        empty.TextSize       = 11
        empty.TextWrapped    = true
        empty.ZIndex         = 7
        empty.Parent         = GroupScroll
    end
end

-- ══════════════════════════════════════════
--  RENDER: PLAYER LIST
-- ══════════════════════════════════════════
local function renderPlayerList()
    for _, c in ipairs(PlayerListScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local uid  = tostring(p.UserId)
        if not PlayerData[uid] then
            PlayerData[uid] = defaultPlayerSettings()
        end
        local pd   = PlayerData[uid]

        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1,0,0,40)
        row.BackgroundColor3 = T.item
        row.BorderSizePixel  = 0
        row.ZIndex           = 7
        row.Parent           = PlayerListScroll
        corner(8, row)

        -- Color dot
        local dot = Instance.new("Frame")
        dot.Size             = UDim2.new(0,8,0,8)
        dot.Position         = UDim2.new(0,10,0.5,-4)
        dot.BackgroundColor3 = getPresetColor(pd.colorIndex)
        dot.BorderSizePixel  = 0
        dot.ZIndex           = 8
        dot.Parent           = row
        corner(4, dot)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Text           = p.DisplayName ~= p.Name
            and p.DisplayName.." ("..p.Name..")"
            or p.Name
        nameLbl.Size           = UDim2.new(1,-80,0.6,0)
        nameLbl.Position       = UDim2.new(0,26,0,2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextColor3     = T.text
        nameLbl.Font           = Enum.Font.GothamBold
        nameLbl.TextSize       = 12
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ZIndex         = 8
        nameLbl.Parent         = row

        local espStateLbl = Instance.new("TextLabel")
        espStateLbl.Text      = pd.espEnabled and "● ESP ON" or "○ OFF"
        espStateLbl.Size      = UDim2.new(1,-80,0.4,0)
        espStateLbl.Position  = UDim2.new(0,26,0.6,0)
        espStateLbl.BackgroundTransparency = 1
        espStateLbl.TextColor3 = pd.espEnabled and T.tog_on or T.subtext
        espStateLbl.Font      = Enum.Font.GothamBold
        espStateLbl.TextSize  = 10
        espStateLbl.TextXAlignment = Enum.TextXAlignment.Left
        espStateLbl.ZIndex    = 8
        espStateLbl.Parent    = row

        -- Checkbox toggle
        local togBg = Instance.new("Frame")
        togBg.Size             = UDim2.new(0,34,0,18)
        togBg.Position         = UDim2.new(1,-42,0.5,-9)
        togBg.BackgroundColor3 = pd.selected and T.tog_on or T.tog_off
        togBg.BorderSizePixel  = 0
        togBg.ZIndex           = 8
        togBg.Parent           = row
        corner(9, togBg)
        local tdot = Instance.new("Frame")
        tdot.Size             = UDim2.new(0,14,0,14)
        tdot.Position         = UDim2.new(pd.selected and 1 or 0, pd.selected and -16 or 2, 0.5,-7)
        tdot.BackgroundColor3 = Color3.new(1,1,1)
        tdot.BorderSizePixel  = 0
        tdot.ZIndex           = 9
        tdot.Parent           = togBg
        corner(7, tdot)

        local tbtn = Instance.new("TextButton")
        tbtn.Size               = UDim2.new(1,0,1,0)
        tbtn.BackgroundTransparency = 1
        tbtn.Text               = ""
        tbtn.ZIndex             = 10
        tbtn.Parent             = togBg

        local cp = p
        local cuid = uid
        tbtn.MouseButton1Click:Connect(function()
            pd.selected = not pd.selected
            togBg.BackgroundColor3 = pd.selected and T.tog_on or T.tog_off
            tw(tdot, {Position = UDim2.new(pd.selected and 1 or 0, pd.selected and -16 or 2, 0.5,-7)}, 0.12)
            saveData()
        end)
    end
end

-- ══════════════════════════════════════════
--  SCAN BUTTON HANDLER
-- ══════════════════════════════════════════
ScanBtn.MouseButton1Click:Connect(function()
    if not CurrentGameIdx then return end
    local g = NpcGames[CurrentGameIdx]
    if not g then return end

    ScanStatus.Text = "Scanning..."
    task.wait(0.05)

    local root
    local pathStr = PathBox.Text
    if pathStr and pathStr ~= "" then
        root = resolveScriptPath(pathStr)
        if not root then
            ScanStatus.Text = "⚠  Path not found. Using full scan."
            root = workspace
        else
            g.path = pathStr
        end
    else
        root = workspace
    end

    local found  = scanForNpcs(root)
    local added  = 0
    g.groups     = g.groups or {}

    for gname, models in pairs(found) do
        if not g.groups[gname] then
            g.groups[gname] = defaultGroupSettings()
            added = added + 1
        end
        -- Update known spawn tracking
        local key = tostring(CurrentGameIdx).."_"..gname
        if not SpawnKnown[key] then SpawnKnown[key] = {} end
        for _, m in ipairs(models) do
            SpawnKnown[key][m] = true
        end
    end

    saveData()
    ScanStatus.Text = "✓  Found "..added.." new group"..(added~=1 and "s" or "").." ("..
        (function() local n=0 for _ in pairs(found) do n=n+1 end return n end()).." total)"
    renderGroupList()
end)

-- ══════════════════════════════════════════
--  PLAYER TRACKING (auto add/remove)
-- ══════════════════════════════════════════
Players.PlayerAdded:Connect(function(p)
    task.wait(1)
    if CurrentPage == "players" then renderPlayerList() end
end)
Players.PlayerRemoving:Connect(function(p)
    local uid = tostring(p.UserId)
    local data = PlayerBills[uid]
    if data then
        pcall(function()
            if data.bill     then data.bill:Destroy()     end
            if data.hl       then data.hl:Destroy()       end
            if data.helpBill then data.helpBill:Destroy() end
            if data.helpHl   then data.helpHl:Destroy()   end
        end)
        PlayerBills[uid] = nil
    end
    if CurrentPage == "players" then renderPlayerList() end
end)

-- ══════════════════════════════════════════
--  RENDER LOOP
-- ══════════════════════════════════════════
local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local hrpRef = char:WaitForChild("HumanoidRootPart", 5)

LocalPlayer.CharacterAdded:Connect(function(c)
    char = c
    hrpRef = c:WaitForChild("HumanoidRootPart", 5)
end)

RunService.RenderStepped:Connect(function()
    local hrp = hrpRef
    if not hrp or not hrp.Parent then return end
    local myPos = hrp.Position

    -- ── NPC ESP ──
    for gi, g in ipairs(NpcGames) do
        for gname, grp in pairs(g.groups or {}) do
            if not grp.espEnabled then continue end
            local key = tostring(gi).."_"..gname
            local active = NpcESPActive[key]
            if not active then continue end

            for model, data in pairs(active) do
                if not model or not model.Parent then continue end
                local root = getCharRoot(model)
                if not root then continue end

                local dist = (myPos - root.Position).Magnitude

                -- Update distance label
                if data.bill then
                    local dl = data.bill:FindFirstChild("DistLbl")
                    if dl then dl.Text = math.floor(dist+0.5).." studs" end
                end

                -- Fade
                applyFade(data.bill, data.hl, dist, grp, false)

                -- Help Notify
                if grp.helpEnabled then
                    local hum = getHumanoid(model)
                    local hp  = hum and hum.Health or 999
                    if hp < grp.helpHP then
                        if not data.helpBill then
                            data.helpBill = makeNotifyBill(root, "⚠️ LOW HP", T.help_green, getFont(grp.font), 5.5)
                            data.helpHl   = makeHighlight(model, T.help_green, T.help_green, 0.55, 0.1)
                        end
                        applyFade(data.helpBill, data.helpHl, dist, {
                            fadeStudDist=grp.helpFadeDist, fadeNameDist=grp.helpFadeDist,
                            fadeCloseDist=grp.fadeCloseDist, fadeCloseNameDist=grp.fadeCloseNameDist,
                            maxOpacity=grp.maxOpacity
                        }, true)
                    else
                        if data.helpBill then
                            data.helpBill:Destroy() ; data.helpBill = nil
                        end
                        if data.helpHl then
                            data.helpHl:Destroy() ; data.helpHl = nil
                        end
                    end
                end
            end
        end
    end

    -- ── Spawn Notify fade ──
    local now = tick()
    for model, nb in pairs(SpawnNotifBills) do
        if not model or not model.Parent then
            pcall(function() nb.bill:Destroy() end)
            SpawnNotifBills[model] = nil
        elseif nb.bill and nb.bill.Parent then
            local root = getCharRoot(model)
            if root then
                local dist = (myPos - root.Position).Magnitude
                local timeLeft = nb.expireAt - now
                if timeLeft <= 0 then
                    nb.bill:Destroy()
                    SpawnNotifBills[model] = nil
                else
                    local timeFade = math.clamp(1 - (timeLeft / 1.5), 0, 1)
                    local sl = nb.bill:FindFirstChildWhichIsA("TextLabel")
                    if sl then
                        local fd = nb.fadeDist or 150
                        local distAlpha = dist > fd and 1 or 0
                        if dist > fd * 0.8 then
                            distAlpha = (dist - fd*0.8)/(fd*0.2)
                        end
                        sl.TextTransparency = math.max(distAlpha, timeFade)
                    end
                end
            end
        end
    end

    -- ── Player ESP ──
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local uid = tostring(p.UserId)
        local pd  = PlayerData[uid]
        if not pd or not pd.selected or not pd.espEnabled then
            -- Clean up if not selected/enabled
            local data = PlayerBills[uid]
            if data then
                pcall(function()
                    if data.bill     then data.bill:Destroy()     end
                    if data.hl       then data.hl:Destroy()       end
                    if data.helpBill then data.helpBill:Destroy() end
                    if data.helpHl   then data.helpHl:Destroy()   end
                end)
                PlayerBills[uid] = nil
            end
            continue
        end

        local pchar = p.Character
        local phrp  = pchar and pchar:FindFirstChild("HumanoidRootPart")
        if not pchar or not phrp then continue end

        local color = getPresetColor(pd.colorIndex)
        local font  = getFont(pd.font)

        if not PlayerBills[uid] then
            local bill, hl
            if pd.espName or pd.espDistance then
                bill = makeBillboard(phrp, pd.espName, pd.espDistance, color, font)
                if bill then
                    local nl = bill:FindFirstChild("NameLbl")
                    if nl then nl.Text = p.Name end
                end
            end
            if pd.espOutline or pd.espFullBody then
                local ft = pd.espFullBody and 0.5 or 1
                hl = makeHighlight(pchar, color, color, ft, 0)
            end
            PlayerBills[uid] = { bill=bill, hl=hl, helpBill=nil, helpHl=nil }
        end

        local data = PlayerBills[uid]
        local dist = (myPos - phrp.Position).Magnitude

        if data.bill then
            local dl = data.bill:FindFirstChild("DistLbl")
            if dl then dl.Text = math.floor(dist+0.5).." studs" end
        end
        applyFade(data.bill, data.hl, dist, pd, false)

        -- Player HELP notify: green body + "HELP" label
        if pd.helpEnabled then
            local hum = pchar:FindFirstChildWhichIsA("Humanoid")
            local hp  = hum and hum.Health or 999
            if hp < pd.helpHP then
                if not data.helpBill then
                    data.helpBill = makeNotifyBill(phrp, "HELP", T.help_green, getFont(pd.font), 5.5)
                    data.helpHl   = makeHighlight(pchar, T.help_green, T.help_green, 0.4, 0.05)
                end
                applyFade(data.helpBill, data.helpHl, dist, {
                    fadeStudDist=pd.helpFadeDist, fadeNameDist=pd.helpFadeDist,
                    fadeCloseDist=pd.fadeCloseDist, fadeCloseNameDist=pd.fadeCloseNameDist,
                    maxOpacity=pd.maxOpacity
                }, true)
            else
                if data.helpBill then data.helpBill:Destroy(); data.helpBill = nil end
                if data.helpHl   then data.helpHl:Destroy();  data.helpHl   = nil end
            end
        end
    end
end)

-- ══════════════════════════════════════════
--  SPAWN NOTIFY POLLING LOOP
-- ══════════════════════════════════════════
task.spawn(function()
    while Gui.Parent do
        task.wait(1)
        for gi, g in ipairs(NpcGames) do
            for gname, grp in pairs(g.groups or {}) do
                if not grp.spawnEnabled then continue end
                local key = tostring(gi).."_"..gname
                if not SpawnKnown[key] then SpawnKnown[key] = {} end

                -- Find all current models with this name
                local root
                if g.path and g.path ~= "" then
                    root = resolveScriptPath(g.path) or workspace
                else
                    root = workspace
                end

                local found = scanForNpcs(root)
                local current = found[gname] or {}

                for _, model in ipairs(current) do
                    if not SpawnKnown[key][model] then
                        -- NEW spawn detected
                        SpawnKnown[key][model] = true
                        local root2 = getCharRoot(model)
                        if root2 then
                            local col  = getPresetColor(grp.spawnColorIndex)
                            local fnt  = getFont(grp.spawnFont)
                            local bill = makeNotifyBill(root2, grp.spawnEmoji.." SPAWNED", col, fnt, 5.5)
                            if bill then
                                SpawnNotifBills[model] = {
                                    bill     = bill,
                                    expireAt = tick() + (grp.spawnDuration or 5),
                                    fadeDist = grp.spawnFadeDist or 150,
                                }
                            end
                        end
                    end
                end

                -- Prune despawned from known
                for m in pairs(SpawnKnown[key]) do
                    if not m.Parent then
                        SpawnKnown[key][m] = nil
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════
--  NPC ESP APPLY LOOP (keep fresh)
-- ══════════════════════════════════════════
task.spawn(function()
    while Gui.Parent do
        task.wait(2)
        for gi, g in ipairs(NpcGames) do
            for gname, grp in pairs(g.groups or {}) do
                if not grp.espEnabled then continue end
                local root
                if g.path and g.path ~= "" then
                    root = resolveScriptPath(g.path) or workspace
                else
                    root = workspace
                end
                local found = scanForNpcs(root)
                local models = found[gname] or {}
                applyNpcGroupESP(gi, gname, models)
            end
        end
    end
end)

-- ══════════════════════════════════════════
--  MENU TOGGLE
-- ══════════════════════════════════════════
local function toggleMenu()
    if Minimized then
        Minimized    = false
        Menu.Visible = true
        return
    end
    MenuOpen     = not MenuOpen
    Menu.Visible = MenuOpen
    if MenuOpen then
        if CurrentTab == "npc" then
            showPage("npc_list")
            renderNpcList()
        else
            showPage("players")
            renderPlayerList()
        end
    end
end

-- ══════════════════════════════════════════
--  TAB WIRING
-- ══════════════════════════════════════════
local function setTab(tab)
    CurrentTab = tab
    if tab == "npc" then
        TabNPC.BackgroundColor3     = T.tab_active
        TabPlayers.BackgroundColor3 = T.tab_idle
        tw(TabIndic, {Position = UDim2.new(0,0,1,-3)}, 0.15)
        showPage("npc_list")
        renderNpcList()
    else
        TabPlayers.BackgroundColor3 = T.tab_active
        TabNPC.BackgroundColor3     = T.tab_idle
        tw(TabIndic, {Position = UDim2.new(0.5,0,1,-3)}, 0.15)
        showPage("players")
        renderPlayerList()
    end
end

TabNPC.MouseButton1Click:Connect(function() setTab("npc") end)
TabPlayers.MouseButton1Click:Connect(function() setTab("players") end)

-- ══════════════════════════════════════════
--  TITLE BAR BUTTONS
-- ══════════════════════════════════════════
ToggleBtn.MouseButton1Click:Connect(toggleMenu)

BtnClose.MouseButton1Click:Connect(function()
    ConfOv.Visible  = true
    ConfBox.Visible = true
end)

ConfYes.MouseButton1Click:Connect(function()
    removeAllNpcESP()
    removeAllPlayerESP()
    Gui:Destroy()
end)

BtnMinimize.MouseButton1Click:Connect(function()
    Minimized    = true
    Menu.Visible = false
end)

BtnSettings.MouseButton1Click:Connect(function()
    -- does nothing standalone — settings are per group/player
    -- Could navigate to global defaults in future
end)

BtnBack.MouseButton1Click:Connect(function()
    if CurrentPage == "npc_group" then
        showPage("npc_folder")
        renderGroupList()
    elseif CurrentPage == "npc_folder" then
        showPage("npc_list")
        renderNpcList()
    elseif CurrentPage == "player_settings" then
        showPage("players")
        renderPlayerList()
    end
end)

-- ══════════════════════════════════════════
--  ADD FOLDER BUTTON
-- ══════════════════════════════════════════
AddFolderBtn.MouseButton1Click:Connect(function()
    openModal("New Game Folder", "Folder name...", function(n)
        if n ~= "" then
            table.insert(NpcGames, { name=n, path="", groups={} })
            saveData()
            renderNpcList()
        end
    end, "Add")
end)

-- ══════════════════════════════════════════
--  SELECT ALL BUTTON
-- ══════════════════════════════════════════
SelectAllBtn.MouseButton1Click:Connect(function()
    local allSelected = true
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local uid = tostring(p.UserId)
        if not PlayerData[uid] or not PlayerData[uid].selected then
            allSelected = false ; break
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local uid = tostring(p.UserId)
        if not PlayerData[uid] then PlayerData[uid] = defaultPlayerSettings() end
        PlayerData[uid].selected = not allSelected
    end
    saveData()
    renderPlayerList()
end)

-- ══════════════════════════════════════════
--  PLAYER SETTINGS BUTTON
-- ══════════════════════════════════════════
-- Global template settings for all selected players
local GlobalPlayerSettings = defaultPlayerSettings()

PlayerSettingsBtn.MouseButton1Click:Connect(function()
    PSTitle.Text = "  👤  Player ESP Settings"
    buildSettingsPanel(PSScroll, GlobalPlayerSettings, true, function()
        -- Apply to all selected players
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local uid = tostring(p.UserId)
            if PlayerData[uid] and PlayerData[uid].selected then
                for k, v in pairs(GlobalPlayerSettings) do
                    if k ~= "selected" then
                        PlayerData[uid][k] = v
                    end
                end
            end
        end
        -- Rebuild ESP for affected players
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local uid = tostring(p.UserId)
            local d = PlayerBills[uid]
            if d then
                pcall(function()
                    if d.bill   then d.bill:Destroy()   end
                    if d.hl     then d.hl:Destroy()     end
                    if d.helpBill then d.helpBill:Destroy() end
                    if d.helpHl   then d.helpHl:Destroy()   end
                end)
                PlayerBills[uid] = nil
            end
        end
        saveData()
    end)
    showPage("player_settings")
end)

-- ══════════════════════════════════════════
--  INIT
-- ══════════════════════════════════════════
setTab("npc")
