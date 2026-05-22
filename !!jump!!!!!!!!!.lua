-- ============================================================
--  Mobile Layout Editor
--  Uses Rayfield UI for notifications + menus
--  All draggable elements use custom Roblox GUI
--  Designed for mobile players
-- ============================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
--  GAME VERIFICATION
-- ============================================================
local GAME_PLACE_ID = game.PlaceId
local GAME_LINK     = "https://www.roblox.com/games/" .. tostring(GAME_PLACE_ID)

-- ============================================================
--  RAYFIELD
-- ============================================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- Startup verification notification
Rayfield:Notify({
    Title   = "Layout Editor – Game Verified",
    Content = "Place ID: " .. tostring(GAME_PLACE_ID) .. "\n" .. GAME_LINK,
    Duration = 6,
    Image    = 4483362458,
})

-- ============================================================
--  PERSISTENT STORAGE
-- ============================================================
local SAVE_FILE = "MobileLayoutEditor_data.json"

local layoutData = {
    placeId   = GAME_PLACE_ID,
    gameLink  = GAME_LINK,
    layouts   = {},
}

-- Try loading saved data
pcall(function()
    local raw  = readfile(SAVE_FILE)
    local data = HttpService:JSONDecode(raw)
    -- Only load if it belongs to this game
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
--  ROOT SCREENGUI
-- ============================================================
local RootGui = Instance.new("ScreenGui")
RootGui.Name            = "MobileLayoutEditor"
RootGui.ResetOnSpawn    = false
RootGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
RootGui.IgnoreGuiInset  = true
RootGui.DisplayOrder    = 999
RootGui.Parent          = PlayerGui

-- ============================================================
--  SHARED STATE
-- ============================================================
local State = {
    editMode       = false,
    undoStack      = {},          -- { element, size, transparency }
    originalProps  = {},          -- keyed by element
}

-- ============================================================
--  GUI HELPERS
-- ============================================================
local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius or UDim.new(0, 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or Color3.fromRGB(70, 70, 85)
    s.Thickness = thickness or 1
    s.Parent    = parent
    return s
end

local function mkFrame(parent, size, pos, bgColor, bgTrans, zIndex)
    local f = Instance.new("Frame")
    f.Size                  = size
    f.Position              = pos
    f.BackgroundColor3      = bgColor   or Color3.fromRGB(22, 22, 30)
    f.BackgroundTransparency= bgTrans   or 0
    f.BorderSizePixel       = 0
    f.ZIndex                = zIndex    or 10
    f.Parent                = parent
    corner(f, UDim.new(0, 10))
    stroke(f)
    return f
end

local function mkLabel(parent, text, size, pos, color, fontSize, zIndex)
    local l = Instance.new("TextLabel")
    l.Size                  = size
    l.Position              = pos
    l.BackgroundTransparency= 1
    l.TextColor3            = color     or Color3.fromRGB(255, 255, 255)
    l.Text                  = text
    l.Font                  = Enum.Font.GothamBold
    l.TextSize              = fontSize  or 14
    l.TextXAlignment        = Enum.TextXAlignment.Center
    l.TextWrapped           = true
    l.ZIndex                = zIndex    or 11
    l.Parent                = parent
    return l
end

local function mkButton(parent, text, size, pos, bgColor, textColor, zIndex)
    local b = Instance.new("TextButton")
    b.Size             = size
    b.Position         = pos
    b.BackgroundColor3 = bgColor   or Color3.fromRGB(35, 120, 220)
    b.TextColor3       = textColor or Color3.fromRGB(255, 255, 255)
    b.Text             = text
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 13
    b.BorderSizePixel  = 0
    b.ZIndex           = zIndex    or 11
    b.Parent           = parent
    corner(b, UDim.new(0, 8))
    return b
end

local function mkTextBox(parent, placeholder, size, pos, zIndex)
    local tb = Instance.new("TextBox")
    tb.Size                   = size
    tb.Position               = pos
    tb.BackgroundColor3       = Color3.fromRGB(40, 40, 55)
    tb.TextColor3             = Color3.fromRGB(255, 255, 255)
    tb.PlaceholderColor3      = Color3.fromRGB(120, 120, 140)
    tb.PlaceholderText        = placeholder or ""
    tb.Text                   = ""
    tb.Font                   = Enum.Font.Gotham
    tb.TextSize               = 13
    tb.BorderSizePixel        = 0
    tb.ClearTextOnFocus       = false
    tb.ZIndex                 = zIndex or 11
    tb.Parent                 = parent
    corner(tb, UDim.new(0, 6))
    return tb
end

local function divider(parent, yOffset, zIndex)
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(0.88, 0, 0, 1)
    d.Position         = UDim2.new(0.06, 0, 0, yOffset)
    d.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    d.BorderSizePixel  = 0
    d.ZIndex           = zIndex or 11
    d.Parent           = parent
    return d
end

-- Make any Frame draggable via a handle (defaults to itself)
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging  = false
    local dragStart = nil
    local startPos  = nil

    local function onInputBegan(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end

    local function onInputChanged(input)
        local t = input.UserInputType
        if dragging and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseMovement) then
            local d  = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,  startPos.X.Offset + d.X,
                startPos.Y.Scale,  startPos.Y.Offset + d.Y
            )
        end
    end

    handle.InputBegan:Connect(onInputBegan)
    handle.InputChanged:Connect(onInputChanged)
end

-- ============================================================
--  TOGGLE BUTTON  (always visible, draggable)
-- ============================================================
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size             = UDim2.new(0, 58, 0, 58)
ToggleBtn.Position         = UDim2.new(0, 18, 0.5, -29)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(25, 120, 230)
ToggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
ToggleBtn.Text             = "☰"
ToggleBtn.Font             = Enum.Font.GothamBold
ToggleBtn.TextSize         = 26
ToggleBtn.BorderSizePixel  = 0
ToggleBtn.ZIndex           = 200
ToggleBtn.Parent           = RootGui
corner(ToggleBtn, UDim.new(1, 0))
stroke(ToggleBtn, Color3.fromRGB(80, 170, 255), 2)
makeDraggable(ToggleBtn)

-- ============================================================
--  MAIN MENU
-- ============================================================
local MainMenu = mkFrame(RootGui,
    UDim2.new(0, 230, 0, 170),
    UDim2.new(0.5, -115, 0.5, -85),
    Color3.fromRGB(18, 18, 26), 0, 100)
MainMenu.Visible = false

mkLabel(MainMenu, "Layout Editor",
    UDim2.new(1, 0, 0, 38), UDim2.new(0, 0, 0, 6),
    Color3.fromRGB(255, 255, 255), 16, 101)

divider(MainMenu, 46, 101)

local EditLayoutBtn = mkButton(MainMenu, "EDIT LAYOUT",
    UDim2.new(0.84, 0, 0, 44), UDim2.new(0.08, 0, 0, 56),
    Color3.fromRGB(25, 120, 230), nil, 101)

local LayoutBtnsBtn = mkButton(MainMenu, "LAYOUT BUTTONS",
    UDim2.new(0.84, 0, 0, 44), UDim2.new(0.08, 0, 0, 108),
    Color3.fromRGB(45, 45, 60), nil, 101)

makeDraggable(MainMenu)

-- Toggle menu
local menuOpen = false
ToggleBtn.MouseButton1Click:Connect(function()
    if not State.editMode then
        menuOpen = not menuOpen
        MainMenu.Visible = menuOpen
    end
end)

-- ============================================================
--  FORWARD DECLARATIONS
-- ============================================================
local openLayoutButtonsPage  -- defined later
local elementEditorFrame     -- current open editor

-- ============================================================
--  EDIT-MODE  "X" CLOSE BUTTON
-- ============================================================
local EditCloseBtn = Instance.new("TextButton")
EditCloseBtn.Size             = UDim2.new(0, 48, 0, 48)
EditCloseBtn.Position         = UDim2.new(1, -58, 0, 10)
EditCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
EditCloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
EditCloseBtn.Text             = "✕"
EditCloseBtn.Font             = Enum.Font.GothamBold
EditCloseBtn.TextSize         = 18
EditCloseBtn.BorderSizePixel  = 0
EditCloseBtn.ZIndex           = 200
EditCloseBtn.Visible          = false
EditCloseBtn.Parent           = RootGui
corner(EditCloseBtn, UDim.new(1, 0))
stroke(EditCloseBtn, Color3.fromRGB(255, 100, 100), 2)
makeDraggable(EditCloseBtn)

-- Edit-mode status bar
local EditBanner = mkFrame(RootGui,
    UDim2.new(0, 230, 0, 36),
    UDim2.new(0.5, -115, 0, 10),
    Color3.fromRGB(25, 120, 230), 0, 100)
EditBanner.Visible = false
mkLabel(EditBanner, "✎  Tap any UI element to edit",
    UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(255, 255, 255), 12, 101)

-- ============================================================
--  ELEMENT EDITOR POPUP
-- ============================================================
local function buildElementEditor(element)
    if elementEditorFrame then
        elementEditorFrame:Destroy()
        elementEditorFrame = nil
    end

    local origSize  = element.Size
    local origTrans = 0
    pcall(function() origTrans = element.BackgroundTransparency end)

    -- Snapshot for undo
    State.originalProps[element] = { size = origSize, transparency = origTrans }

    local editorW, editorH = 290, 295
    elementEditorFrame = mkFrame(RootGui,
        UDim2.new(0, editorW, 0, editorH),
        UDim2.new(0.5, -editorW/2, 0.5, -editorH/2),
        Color3.fromRGB(18, 18, 26), 0, 150)

    -- Title bar (also drag handle)
    local titleBar = Instance.new("Frame")
    titleBar.Size             = UDim2.new(1, 0, 0, 38)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    titleBar.BorderSizePixel  = 0
    titleBar.ZIndex           = 151
    titleBar.Parent           = elementEditorFrame
    corner(titleBar, UDim.new(0, 10))

    mkLabel(titleBar, "✎  " .. element.Name,
        UDim2.new(1, -10, 1, 0), UDim2.new(0, 5, 0, 0),
        Color3.fromRGB(255, 255, 255), 13, 152)

    makeDraggable(elementEditorFrame, titleBar)
    divider(elementEditorFrame, 40, 151)

    -- ---- Width ----
    mkLabel(elementEditorFrame, "Width (px)",
        UDim2.new(0.45, 0, 0, 22), UDim2.new(0.05, 0, 0, 50),
        Color3.fromRGB(180, 180, 200), 12, 151)
    local widthInput = mkTextBox(elementEditorFrame, "width",
        UDim2.new(0.42, 0, 0, 32), UDim2.new(0.53, 0, 0, 47), 152)
    widthInput.Text = tostring(math.floor(element.AbsoluteSize.X))

    -- ---- Height ----
    mkLabel(elementEditorFrame, "Height (px)",
        UDim2.new(0.45, 0, 0, 22), UDim2.new(0.05, 0, 0, 90),
        Color3.fromRGB(180, 180, 200), 12, 151)
    local heightInput = mkTextBox(elementEditorFrame, "height",
        UDim2.new(0.42, 0, 0, 32), UDim2.new(0.53, 0, 0, 87), 152)
    heightInput.Text = tostring(math.floor(element.AbsoluteSize.Y))

    -- ---- Transparency ----
    mkLabel(elementEditorFrame, "Transparency  (0 – 1)",
        UDim2.new(0.88, 0, 0, 22), UDim2.new(0.06, 0, 0, 130),
        Color3.fromRGB(180, 180, 200), 12, 151)
    local transInput = mkTextBox(elementEditorFrame, "0.0",
        UDim2.new(0.42, 0, 0, 32), UDim2.new(0.53, 0, 0, 127), 152)
    transInput.Text = tostring(origTrans)

    divider(elementEditorFrame, 170, 151)

    -- ---- Action buttons ----
    local function readInputs()
        return
            tonumber(widthInput.Text)  or element.AbsoluteSize.X,
            tonumber(heightInput.Text) or element.AbsoluteSize.Y,
            math.clamp(tonumber(transInput.Text) or origTrans, 0, 1)
    end

    local function applyToElement(w, h, t)
        element.Size = UDim2.new(
            element.Size.X.Scale, w,
            element.Size.Y.Scale, h
        )
        pcall(function() element.BackgroundTransparency = t end)
    end

    -- Cancel
    local cancelBtn = mkButton(elementEditorFrame, "Cancel",
        UDim2.new(0.21, 0, 0, 36), UDim2.new(0.02, 0, 0, 182),
        Color3.fromRGB(70, 70, 85), nil, 151)
    cancelBtn.TextSize = 12
    cancelBtn.MouseButton1Click:Connect(function()
        local orig = State.originalProps[element]
        if orig then
            element.Size = orig.size
            pcall(function() element.BackgroundTransparency = orig.transparency end)
        end
        elementEditorFrame:Destroy()
        elementEditorFrame = nil
        State.selectedElement = nil
    end)

    -- Done
    local doneBtn = mkButton(elementEditorFrame, "Done",
        UDim2.new(0.21, 0, 0, 36), UDim2.new(0.26, 0, 0, 182),
        Color3.fromRGB(25, 120, 230), nil, 151)
    doneBtn.TextSize = 12
    doneBtn.MouseButton1Click:Connect(function()
        local w, h, t = readInputs()
        -- push undo entry
        table.insert(State.undoStack, {
            element = element,
            size    = element.Size,
            transparency = origTrans,
        })
        applyToElement(w, h, t)
        elementEditorFrame:Destroy()
        elementEditorFrame = nil
        State.selectedElement = nil
    end)

    -- Undo
    local undoBtn = mkButton(elementEditorFrame, "Undo",
        UDim2.new(0.21, 0, 0, 36), UDim2.new(0.50, 0, 0, 182),
        Color3.fromRGB(190, 130, 20), nil, 151)
    undoBtn.TextSize = 12
    undoBtn.MouseButton1Click:Connect(function()
        for i = #State.undoStack, 1, -1 do
            if State.undoStack[i].element == element then
                local entry = table.remove(State.undoStack, i)
                element.Size = entry.size
                pcall(function() element.BackgroundTransparency = entry.transparency end)
                widthInput.Text  = tostring(math.floor(element.AbsoluteSize.X))
                heightInput.Text = tostring(math.floor(element.AbsoluteSize.Y))
                transInput.Text  = tostring(entry.transparency)
                break
            end
        end
    end)

    -- Reset by default
    local resetBtn = mkButton(elementEditorFrame, "Reset",
        UDim2.new(0.21, 0, 0, 36), UDim2.new(0.75, 0, 0, 182),
        Color3.fromRGB(190, 40, 40), nil, 151)
    resetBtn.TextSize = 12
    resetBtn.MouseButton1Click:Connect(function()
        local orig = State.originalProps[element]
        if orig then
            element.Size = orig.size
            pcall(function() element.BackgroundTransparency = orig.transparency end)
            widthInput.Text  = tostring(math.floor(element.AbsoluteSize.X))
            heightInput.Text = tostring(math.floor(element.AbsoluteSize.Y))
            transInput.Text  = tostring(orig.transparency)
        end
    end)

    local function makeHint(text, yOff)
        mkLabel(elementEditorFrame, text,
            UDim2.new(0.5, 0, 0, 18), UDim2.new(0.26, 0, 0, yOff),
            Color3.fromRGB(100, 100, 120), 10, 151)
    end
    makeHint("Cancel  |  Done  |  Undo  |  Reset", 230)
end

-- ============================================================
--  EDIT MODE  –  touch detection
-- ============================================================
local touchConnection

local function startEditMode()
    State.editMode = true
    menuOpen = false
    MainMenu.Visible = false
    EditCloseBtn.Visible = true
    EditBanner.Visible   = true

    touchConnection = UserInputService.TouchStarted:Connect(function(touch, _)
        if elementEditorFrame then return end

        local tp = Vector2.new(touch.Position.X, touch.Position.Y)

        -- Walk all ScreenGuis except ours
        for _, sg in ipairs(PlayerGui:GetChildren()) do
            if sg:IsA("ScreenGui") and sg ~= RootGui then
                local candidates = {}
                for _, el in ipairs(sg:GetDescendants()) do
                    if (el:IsA("GuiButton") or el:IsA("Frame")) and el.Visible then
                        local ap = el.AbsolutePosition
                        local as = el.AbsoluteSize
                        if tp.X >= ap.X and tp.X <= ap.X + as.X
                        and tp.Y >= ap.Y and tp.Y <= ap.Y + as.Y then
                            table.insert(candidates, el)
                        end
                    end
                end
                -- Pick the smallest (most specific) element
                if #candidates > 0 then
                    table.sort(candidates, function(a, b)
                        return (a.AbsoluteSize.X * a.AbsoluteSize.Y)
                             < (b.AbsoluteSize.X * b.AbsoluteSize.Y)
                    end)
                    State.selectedElement = candidates[1]
                    buildElementEditor(candidates[1])
                    break
                end
            end
        end
    end)
end

local function stopEditMode()
    State.editMode = false
    EditCloseBtn.Visible = false
    EditBanner.Visible   = false
    if touchConnection then
        touchConnection:Disconnect()
        touchConnection = nil
    end
    if elementEditorFrame then
        elementEditorFrame:Destroy()
        elementEditorFrame = nil
    end
    State.selectedElement = nil
end

-- ============================================================
--  SAVE / CANCEL DIALOG
-- ============================================================
local function showConfirmDialog(question, yesText, noText, onYes, onNo)
    local dlg = mkFrame(RootGui,
        UDim2.new(0, 270, 0, 148),
        UDim2.new(0.5, -135, 0.5, -74),
        Color3.fromRGB(18, 18, 26), 0, 190)

    mkLabel(dlg, question,
        UDim2.new(1, -20, 0, 58), UDim2.new(0, 10, 0, 12),
        Color3.fromRGB(230, 230, 240), 13, 191)

    local yBtn = mkButton(dlg, yesText,
        UDim2.new(0.42, 0, 0, 42), UDim2.new(0.04, 0, 0, 92),
        Color3.fromRGB(25, 120, 230), nil, 191)

    local nBtn = mkButton(dlg, noText,
        UDim2.new(0.42, 0, 0, 42), UDim2.new(0.52, 0, 0, 92),
        Color3.fromRGB(70, 70, 85), nil, 191)

    yBtn.MouseButton1Click:Connect(function() dlg:Destroy(); onYes() end)
    nBtn.MouseButton1Click:Connect(function() dlg:Destroy(); onNo()  end)
end

-- X close button click
EditCloseBtn.MouseButton1Click:Connect(function()
    showConfirmDialog(
        "Save your layout changes?",
        "💾  Save", "✕  Cancel",
        function() -- Save
            stopEditMode()
            openLayoutButtonsPage()
        end,
        function() -- Cancel – ask if sure
            showConfirmDialog(
                "Are you sure?\nAll unsaved changes will be lost.",
                "Yes, Discard", "Go Back",
                function() -- discard
                    stopEditMode()
                end,
                function() -- go back  →  reopen save dialog
                    EditCloseBtn:GetPropertyChangedSignal("Visible"):Wait() -- tiny yield
                    EditCloseBtn.Visible = true
                end
            )
        end
    )
end)

-- EDIT LAYOUT button in main menu
EditLayoutBtn.MouseButton1Click:Connect(function()
    menuOpen = false
    MainMenu.Visible = false
    startEditMode()
end)

-- ============================================================
--  LAYOUT BUTTONS PAGE
-- ============================================================
local layoutBtnsPage  -- current open frame

function openLayoutButtonsPage()
    if layoutBtnsPage then
        layoutBtnsPage:Destroy()
    end

    local pageW, pageH = 310, 420
    layoutBtnsPage = mkFrame(RootGui,
        UDim2.new(0, pageW, 0, pageH),
        UDim2.new(0.5, -pageW/2, 0.5, -pageH/2),
        Color3.fromRGB(18, 18, 26), 0, 100)

    makeDraggable(layoutBtnsPage)

    -- Title bar
    mkLabel(layoutBtnsPage, "Layout Buttons",
        UDim2.new(1, 0, 0, 38), UDim2.new(0, 0, 0, 4),
        Color3.fromRGB(255, 255, 255), 16, 101)

    mkLabel(layoutBtnsPage,
        "🔒  Locked to Place ID: " .. tostring(GAME_PLACE_ID),
        UDim2.new(0.9, 0, 0, 20), UDim2.new(0.05, 0, 0, 43),
        Color3.fromRGB(100, 170, 255), 10, 101)

    divider(layoutBtnsPage, 65, 101)

    -- Scroll list
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                  = UDim2.new(0.9, 0, 0, 210)
    scroll.Position              = UDim2.new(0.05, 0, 0, 72)
    scroll.BackgroundTransparency= 1
    scroll.BorderSizePixel       = 0
    scroll.ScrollBarThickness    = 4
    scroll.ScrollBarImageColor3  = Color3.fromRGB(100, 100, 140)
    scroll.ZIndex                = 101
    scroll.Parent                = layoutBtnsPage

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding   = UDim.new(0, 6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent    = scroll

    local function refreshList()
        for _, c in ipairs(scroll:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end

        if #layoutData.layouts == 0 then
            mkLabel(scroll,
                "No saved layouts yet.\nTap  +  to create one.",
                UDim2.new(1, -10, 0, 60), UDim2.new(0, 5, 0, 0),
                Color3.fromRGB(120, 120, 145), 12, 102)
        else
            for i, layout in ipairs(layoutData.layouts) do
                local row = Instance.new("Frame")
                row.Size             = UDim2.new(1, -8, 0, 52)
                row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
                row.BorderSizePixel  = 0
                row.ZIndex           = 102
                row.LayoutOrder      = i
                row.Parent           = scroll
                corner(row, UDim.new(0, 8))

                mkLabel(row, layout.name or ("Layout " .. i),
                    UDim2.new(0.65, 0, 0, 26), UDim2.new(0.02, 0, 0, 4),
                    Color3.fromRGB(255, 255, 255), 13, 103)

                mkLabel(row, os.date("%d %b %Y", layout.savedAt or 0),
                    UDim2.new(0.65, 0, 0, 18), UDim2.new(0.02, 0, 0, 30),
                    Color3.fromRGB(110, 110, 135), 10, 103)

                local delBtn = mkButton(row, "✕",
                    UDim2.new(0, 34, 0, 34), UDim2.new(1, -40, 0.5, -17),
                    Color3.fromRGB(180, 38, 38), nil, 103)
                delBtn.TextSize = 14
                delBtn.MouseButton1Click:Connect(function()
                    showConfirmDialog(
                        "Delete layout '" .. (layout.name or "Layout") .. "'?",
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

        scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
    end

    refreshList()

    divider(layoutBtnsPage, 290, 101)

    -- ---- Capture current state helper ----
    local function captureCurrentState()
        local elements = {}
        for _, sg in ipairs(PlayerGui:GetChildren()) do
            if sg:IsA("ScreenGui") and sg ~= RootGui then
                for _, el in ipairs(sg:GetDescendants()) do
                    if el:IsA("GuiObject") then
                        local entry = {
                            path  = el:GetFullName(),
                            sizeX = el.AbsoluteSize.X,
                            sizeY = el.AbsoluteSize.Y,
                        }
                        pcall(function() entry.transparency = el.BackgroundTransparency end)
                        table.insert(elements, entry)
                    end
                end
            end
        end
        return elements
    end

    -- ---- Name dialog helper ----
    local function showNameDialog(onConfirm)
        local dlg = mkFrame(RootGui,
            UDim2.new(0, 280, 0, 155),
            UDim2.new(0.5, -140, 0.5, -77),
            Color3.fromRGB(18, 18, 26), 0, 200)

        mkLabel(dlg, "Enter a name for this layout:",
            UDim2.new(0.9, 0, 0, 28), UDim2.new(0.05, 0, 0, 8),
            Color3.fromRGB(220, 220, 235), 13, 201)

        local nameBox = mkTextBox(dlg, "My Layout",
            UDim2.new(0.84, 0, 0, 36), UDim2.new(0.08, 0, 0, 42), 201)

        local okBtn = mkButton(dlg, "Save Layout",
            UDim2.new(0.44, 0, 0, 40), UDim2.new(0.04, 0, 0, 100),
            Color3.fromRGB(25, 120, 230), nil, 201)

        local cxBtn = mkButton(dlg, "Cancel",
            UDim2.new(0.44, 0, 0, 40), UDim2.new(0.52, 0, 0, 100),
            Color3.fromRGB(70, 70, 85), nil, 201)

        okBtn.MouseButton1Click:Connect(function()
            local name = nameBox.Text ~= "" and nameBox.Text or ("Layout " .. (#layoutData.layouts + 1))
            dlg:Destroy()
            onConfirm(name)
        end)
        cxBtn.MouseButton1Click:Connect(function() dlg:Destroy() end)
    end

    -- ---- + Create new layout ----
    local addBtn = mkButton(layoutBtnsPage, "+  Create New Layout",
        UDim2.new(0.88, 0, 0, 44), UDim2.new(0.06, 0, 0, 300),
        Color3.fromRGB(25, 120, 230), nil, 101)
    addBtn.TextSize = 13

    addBtn.MouseButton1Click:Connect(function()
        showNameDialog(function(name)
            local newEntry = {
                name      = name,
                placeId   = GAME_PLACE_ID,
                gameLink  = GAME_LINK,
                savedAt   = os.time(),
                elements  = captureCurrentState(),
            }
            table.insert(layoutData.layouts, newEntry)
            saveLayoutData()
            refreshList()
            Rayfield:Notify({
                Title   = "Layout Saved",
                Content = "'" .. name .. "' saved for Place ID " .. tostring(GAME_PLACE_ID),
                Duration = 3,
                Image    = 4483362458,
            })
        end)
    end)

    -- ---- Replace layout ----
    local replaceBtn = mkButton(layoutBtnsPage, "⟳  Replace Existing Layout",
        UDim2.new(0.88, 0, 0, 44), UDim2.new(0.06, 0, 0, 352),
        Color3.fromRGB(45, 45, 62), nil, 101)
    replaceBtn.TextSize = 13

    replaceBtn.MouseButton1Click:Connect(function()
        if #layoutData.layouts == 0 then
            Rayfield:Notify({
                Title   = "No Layouts",
                Content = "Create a layout first, then you can replace it.",
                Duration = 3,
            })
            return
        end

        -- Build a picker
        local picker = mkFrame(RootGui,
            UDim2.new(0, 290, 0, 320),
            UDim2.new(0.5, -145, 0.5, -160),
            Color3.fromRGB(18, 18, 26), 0, 200)

        makeDraggable(picker)
        mkLabel(picker, "Choose layout to replace:",
            UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 4),
            Color3.fromRGB(255, 255, 255), 14, 201)
        divider(picker, 42, 201)

        local pScroll = Instance.new("ScrollingFrame")
        pScroll.Size                  = UDim2.new(0.9, 0, 0, 220)
        pScroll.Position              = UDim2.new(0.05, 0, 0, 50)
        pScroll.BackgroundTransparency= 1
        pScroll.BorderSizePixel       = 0
        pScroll.ScrollBarThickness    = 4
        pScroll.ZIndex                = 201
        pScroll.Parent                = picker

        local pList = Instance.new("UIListLayout")
        pList.Padding = UDim.new(0, 5)
        pList.Parent  = pScroll

        for i, layout in ipairs(layoutData.layouts) do
            local pBtn = mkButton(pScroll,
                (layout.name or ("Layout " .. i)),
                UDim2.new(1, -8, 0, 46), UDim2.new(0, 0, 0, 0),
                Color3.fromRGB(30, 30, 42), nil, 202)
            pBtn.TextXAlignment = Enum.TextXAlignment.Left
            pBtn.TextSize = 13

            local inner = Instance.new("UIPadding")
            inner.PaddingLeft = UDim.new(0, 10)
            inner.Parent = pBtn

            pBtn.MouseButton1Click:Connect(function()
                layoutData.layouts[i].elements = captureCurrentState()
                layoutData.layouts[i].savedAt  = os.time()
                saveLayoutData()
                picker:Destroy()
                refreshList()
                Rayfield:Notify({
                    Title   = "Layout Replaced",
                    Content = "'" .. (layout.name or "Layout") .. "' updated.",
                    Duration = 3,
                    Image    = 4483362458,
                })
            end)
        end

        pScroll.CanvasSize = UDim2.new(0, 0, 0, pList.AbsoluteContentSize.Y + 8)

        local pClose = mkButton(picker, "Cancel",
            UDim2.new(0.5, 0, 0, 36), UDim2.new(0.25, 0, 0, 278),
            Color3.fromRGB(70, 70, 85), nil, 201)
        pClose.MouseButton1Click:Connect(function() picker:Destroy() end)
    end)

    -- Close page
    local closePageBtn = mkButton(layoutBtnsPage, "✕  Close",
        UDim2.new(0.4, 0, 0, 36), UDim2.new(0.3, 0, 1, -44),
        Color3.fromRGB(60, 60, 78), nil, 101)
    closePageBtn.TextSize = 12
    closePageBtn.MouseButton1Click:Connect(function()
        layoutBtnsPage:Destroy()
        layoutBtnsPage = nil
    end)
end

-- LAYOUT BUTTONS button in main menu
LayoutBtnsBtn.MouseButton1Click:Connect(function()
    menuOpen = false
    MainMenu.Visible = false
    openLayoutButtonsPage()
end)

-- ============================================================
--  MOBILE CHECK
-- ============================================================
if not UserInputService.TouchEnabled then
    Rayfield:Notify({
        Title   = "⚠ PC Detected",
        Content = "This script is designed for mobile. Touch-tap editing won't work on PC.",
        Duration = 6,
    })
end

-- ============================================================
print("[MobileLayoutEditor] Loaded | PlaceId: " .. tostring(GAME_PLACE_ID))
