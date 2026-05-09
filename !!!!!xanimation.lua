--[[
    AnimationStudio.lua  v3.0  —  Exploit / Executor Script
    Paste and execute in your exploit executor (Synapse X, KRNL, etc.)

    ARCHITECTURE:
    Completely disables Roblox's built-in Animate LocalScript and runs its
    own animation state machine.  All looping, transitions, dynamic speed
    scaling and Idle2 are handled internally — no dependency on Animate.
]]

-- =====================================================================
-- GUARD
-- =====================================================================
if _G.AnimStudioRunning then
    pcall(function() _G.AnimStudioRunning:Destroy() end)
    _G.AnimStudioRunning = nil
end
if _G.AnimStudioCtrl then
    pcall(function() _G.AnimStudioCtrl:Destroy() end)
    _G.AnimStudioCtrl = nil
end

-- =====================================================================
-- SERVICES
-- =====================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local LP     = Players.LocalPlayer
local PGui   = LP:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- =====================================================================
-- SESSION DATA
-- =====================================================================
SavedAnims  = {}
local Packs  = {}
local Emotes = {}
local UndoStack = {}
local RedoStack = {}

-- =====================================================================
-- SLOT DEFINITIONS
-- "Land" replaced by "Idle2" (special timed idle)
-- =====================================================================
local SLOT_NAMES = {"Idle","Walk","Run","Jump","Fall","Swim","Float","Climb","Sit","Idle2"}

local DEFAULT_IDS = {
    Idle  = "507766388",
    Walk  = "507777826",
    Run   = "507767714",
    Jump  = "507765000",
    Fall  = "507767968",
    Swim  = "507784897",
    Float = "507770453",
    Climb = "507765644",
    Sit   = "2506281703",
    Idle2 = "",   -- user-defined; no Roblox default
}

-- Slots that loop continuously
local LOOPED = {Idle=true,Walk=true,Run=true,Swim=true,Float=true,Climb=true,Sit=true,Idle2=true}
-- Slots whose speed scales with movement speed
local SPEED_SCALED = {Walk=true, Run=true, Swim=true}

for _, s in ipairs(SLOT_NAMES) do SavedAnims[s] = "" end

-- =====================================================================
-- PLAYBACK SETTINGS
-- =====================================================================
local PlaybackMode = "Dynamic"   -- "Dynamic" | "Static"
local PlaybackMult = 1.0

-- =====================================================================
-- UNDO / REDO
-- =====================================================================
local function pushUndo(a)
    table.insert(UndoStack, a)
    if #UndoStack > 50 then table.remove(UndoStack, 1) end
    RedoStack = {}
end
local function doUndo()
    if #UndoStack == 0 then return end
    local a = table.remove(UndoStack)
    table.insert(RedoStack, a)
    if a.undo then pcall(a.undo) end
end
local function doRedo()
    if #RedoStack == 0 then return end
    local a = table.remove(RedoStack)
    table.insert(UndoStack, a)
    if a.redo then pcall(a.redo) end
end

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if inp.KeyCode == Enum.KeyCode.Z then doUndo() end
        if inp.KeyCode == Enum.KeyCode.Y then doRedo() end
    end
end)

-- =====================================================================
-- ANIMATION CONTROLLER
-- Replaces Roblox's Animate LocalScript with our own state machine.
-- =====================================================================
local AC = {}   -- AnimController
AC.Animator    = nil
AC.Tracks      = {}       -- slot -> AnimationTrack
AC.CurrentSlot = nil
AC.Hum         = nil
AC.HRP         = nil
AC.AnimScript  = nil
AC.Connections = {}       -- cleanup list
AC.Idle2Timer  = nil

local function resolveId(slot)
    local id = SavedAnims[slot]
    if not id or id == "" then id = DEFAULT_IDS[slot] end
    return (id and id ~= "") and id or nil
end

function AC:_loadTrack(slot)
    -- Destroy any old track for this slot
    if self.Tracks[slot] then
        pcall(function() self.Tracks[slot]:Stop(0) end)
        self.Tracks[slot] = nil
    end

    local id = resolveId(slot)
    if not id or not self.Animator then return end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. id

    local ok, track = pcall(function()
        return self.Animator:LoadAnimation(anim)
    end)
    if ok and track then
        track.Looped = LOOPED[slot] == true
        self.Tracks[slot] = track
    end
end

function AC:LoadAll()
    for _, slot in ipairs(SLOT_NAMES) do
        self:_loadTrack(slot)
    end
end

-- Play a slot, fading from whatever is currently playing
function AC:Play(slot, fade)
    local id = resolveId(slot)
    if not id and slot ~= "Idle2" then
        -- No custom and no default — skip
        return
    end
    -- Idle2 with no ID: silently skip
    if slot == "Idle2" and not id then return end

    fade = fade or 0.2

    -- Already playing this slot and the track is still going? No-op.
    local cur = self.Tracks[self.CurrentSlot]
    if self.CurrentSlot == slot and cur and cur.IsPlaying then return end

    -- Fade out current
    if self.CurrentSlot and self.CurrentSlot ~= slot then
        local old = self.Tracks[self.CurrentSlot]
        if old and old.IsPlaying then
            pcall(function() old:Stop(fade) end)
        end
    end

    -- Make sure the track for the new slot is loaded
    if not self.Tracks[slot] then
        self:_loadTrack(slot)
    end

    local track = self.Tracks[slot]
    if track then
        track.Looped = LOOPED[slot] == true
        pcall(function() track:Play(fade) end)
        self.CurrentSlot = slot
    end
end

-- Stop every track immediately
function AC:StopAll()
    for _, track in pairs(self.Tracks) do
        pcall(function() track:Stop(0) end)
    end
    self.CurrentSlot = nil
end

-- Reload one slot and, if it was active, restart it
function AC:Reload(slot)
    local wasActive = (self.CurrentSlot == slot)
    self:_loadTrack(slot)
    if wasActive then
        self.CurrentSlot = nil
        self:Play(slot, 0.15)
    end
end

-- Determine which slot should play for a given HumanoidState
local function stateToSlot(hs, speed)
    if hs == Enum.HumanoidStateType.Jumping        then return "Jump"
    elseif hs == Enum.HumanoidStateType.Freefall   then return "Fall"
    elseif hs == Enum.HumanoidStateType.Climbing   then return "Climb"
    elseif hs == Enum.HumanoidStateType.Seated     then return "Sit"
    elseif hs == Enum.HumanoidStateType.Swimming   then
        return (speed and speed < 0.5) and "Float" or "Swim"
    elseif hs == Enum.HumanoidStateType.Running
        or hs == Enum.HumanoidStateType.RunningNoPhysics then
        if speed and speed > 0.5 then
            return "Walk"   -- state machine uses Walk; Run is triggered separately
        else
            return "Idle"
        end
    elseif hs == Enum.HumanoidStateType.Landed
        or hs == Enum.HumanoidStateType.Standing   then return "Idle"
    end
    return "Idle"
end

function AC:StartStateMachine()
    local hum = self.Hum
    local hrp = self.HRP
    if not hum then return end

    -- Idle2 timed: every 40 s, play Idle2 for 15 s then return to Idle
    local idle2Playing = false
    self.Idle2Timer = task.spawn(function()
        while true do
            task.wait(40)
            if self.CurrentSlot == "Idle" and not idle2Playing then
                local id2 = resolveId("Idle2")
                if id2 then
                    idle2Playing = true
                    self:Play("Idle2", 0.5)
                    task.wait(15)
                    if self.CurrentSlot == "Idle2" then
                        self:Play("Idle", 0.5)
                    end
                    idle2Playing = false
                end
            end
        end
    end)

    -- State-change listener
    local sc = hum.StateChanged:Connect(function(_, new)
        if idle2Playing and new ~= Enum.HumanoidStateType.Jumping
           and new ~= Enum.HumanoidStateType.Freefall then
            return  -- don't interrupt Idle2 unless leaving ground
        end
        if idle2Playing then idle2Playing = false end

        local spd = 0
        if hrp then
            local v = hrp.Velocity
            spd = Vector3.new(v.X, 0, v.Z).Magnitude
        end
        local slot = stateToSlot(new, spd)
        self:Play(slot, 0.2)
    end)
    table.insert(self.Connections, sc)

    -- Heartbeat: handle Walk vs Run split and dynamic speed
    local hb = RunService.Heartbeat:Connect(function()
        if not self.Hum or not self.HRP then return end
        if not self.Animator then return end

        local vel  = self.HRP.Velocity
        local spd  = Vector3.new(vel.X, 0, vel.Z).Magnitude
        local hs   = self.Hum:GetState()

        -- Walk ↔ Run split based on speed threshold (70 % of WalkSpeed = Run)
        if hs == Enum.HumanoidStateType.Running
        or hs == Enum.HumanoidStateType.RunningNoPhysics then
            if idle2Playing then
                -- interrupt Idle2 if player starts moving
                if spd > 0.5 then
                    idle2Playing = false
                    self:Play("Walk", 0.2)
                end
            else
                local ws     = math.max(self.Hum.WalkSpeed, 1)
                local runThr = ws * 0.7
                if spd > runThr and self.CurrentSlot ~= "Run" and resolveId("Run") then
                    self:Play("Run", 0.18)
                elseif spd > 0.5 and spd <= runThr and self.CurrentSlot ~= "Walk" then
                    self:Play("Walk", 0.18)
                elseif spd <= 0.5 and self.CurrentSlot ~= "Idle" and self.CurrentSlot ~= "Idle2" then
                    self:Play("Idle", 0.25)
                end
            end
        end

        -- Dynamic playback speed for movement slots
        if PlaybackMode == "Dynamic" then
            local slot = self.CurrentSlot
            if slot and SPEED_SCALED[slot] then
                local track = self.Tracks[slot]
                if track and track.IsPlaying then
                    local ws    = math.max(self.Hum.WalkSpeed, 1)
                    local ratio = math.clamp(spd / ws, 0.2, 3.0) * PlaybackMult
                    pcall(function() track:AdjustSpeed(ratio) end)
                end
            end
        elseif PlaybackMode == "Static" then
            local slot = self.CurrentSlot
            if slot and SPEED_SCALED[slot] then
                local track = self.Tracks[slot]
                if track and track.IsPlaying then
                    pcall(function() track:AdjustSpeed(PlaybackMult) end)
                end
            end
        end
    end)
    table.insert(self.Connections, hb)
end

function AC:Init(char)
    -- Tear down previous connections
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    self:StopAll()
    self.Tracks = {}
    self.CurrentSlot = nil

    self.Hum       = char:WaitForChild("Humanoid", 10)
    self.HRP       = char:WaitForChild("HumanoidRootPart", 10)
    self.AnimScript= char:FindFirstChild("Animate")

    if not self.Hum then return end

    -- Disable Roblox's default Animate LocalScript
    if self.AnimScript then
        pcall(function() self.AnimScript.Disabled = true end)
    end

    -- Ensure Animator exists
    self.Animator = self.Hum:FindFirstChildOfClass("Animator")
    if not self.Animator then
        self.Animator = Instance.new("Animator")
        self.Animator.Parent = self.Hum
    end

    -- Stop any tracks still playing from the old Animate script
    for _, tr in ipairs(self.Animator:GetPlayingAnimationTracks()) do
        pcall(function() tr:Stop(0) end)
    end

    self:LoadAll()
    self:StartStateMachine()

    -- Play initial idle
    task.delay(0.1, function()
        self:Play("Idle", 0.3)
    end)
end

function AC:Destroy()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    self:StopAll()
    -- Re-enable default Animate script on cleanup
    if self.AnimScript then
        pcall(function() self.AnimScript.Disabled = false end)
    end
end

-- Public applyAnim: swap out an ID and immediately reload the track
function applyAnim(slot, id)
    SavedAnims[slot] = id
    if AC.Animator then
        AC:Reload(slot)
        return true
    end
    return false
end

_G.AnimStudioCtrl = AC

-- =====================================================================
-- CHARACTER BINDING
-- =====================================================================
local function bindCharacter(c)
    task.wait(0.5)
    AC:Init(c)
    -- Reapply saved custom IDs on top of defaults
    for slot, id in pairs(SavedAnims) do
        if id and id ~= "" then
            AC:Reload(slot)
        end
    end
end

local initChar = LP.Character or LP.CharacterAdded:Wait()
task.spawn(function() bindCharacter(initChar) end)

LP.CharacterAdded:Connect(function(c)
    task.spawn(function() bindCharacter(c) end)
end)

LP.CharacterRemoving:Connect(function()
    AC:Destroy()
end)

-- =====================================================================
-- LINK PARSER
-- =====================================================================
local function extractId(s)
    if not s or s == "" then return nil end
    s = tostring(s):match("^%s*(.-)%s*$")
    return s:match("rbxassetid://(%d+)")
        or s:match("roblox%.com/[^/]+/(%d+)")
        or s:match("create%.roblox%.com/store/asset/(%d+)")
        or (s:match("^%d+$") and s)
        or nil
end

local function detectType(s)
    local l = s:lower()
    if l:find("pack") or l:find("bundle") or l:find("collection") then return "Pack" end
    if l:find("emote") or l:find("dance") or l:find("wave") then return "Emote" end
    return "Animation"
end

-- =====================================================================
-- THEME
-- =====================================================================
local T = {
    Bg      = Color3.fromRGB(12, 12, 18),
    Surface = Color3.fromRGB(20, 20, 30),
    Card    = Color3.fromRGB(28, 28, 42),
    Border  = Color3.fromRGB(52, 52, 75),
    Accent  = Color3.fromRGB(99, 102, 241),
    AccHov  = Color3.fromRGB(130, 133, 255),
    AccDark = Color3.fromRGB(67, 70, 190),
    OK      = Color3.fromRGB(34, 197, 94),
    Warn    = Color3.fromRGB(234, 179, 8),
    Bad     = Color3.fromRGB(239, 68, 68),
    Text    = Color3.fromRGB(232, 232, 255),
    Sub     = Color3.fromRGB(150, 150, 180),
    Muted   = Color3.fromRGB(85, 85, 115),
}

-- =====================================================================
-- UI HELPERS
-- =====================================================================
local function vp() return Camera.ViewportSize end

local function tw(obj, props, t)
    pcall(function()
        TweenService:Create(obj,
            TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            props):Play()
    end)
end

local function mkCorner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end
local function mkStroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or T.Border
    s.Thickness = th or 1
    s.Parent = p
end
local function mkPad(p, t, r, b, l)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 8)
    u.PaddingRight  = UDim.new(0, r or 8)
    u.PaddingBottom = UDim.new(0, b or 8)
    u.PaddingLeft   = UDim.new(0, l or 8)
    u.Parent = p
end
local function mkFrame(par, sz, pos, col, name)
    local f = Instance.new("Frame")
    f.Size = sz or UDim2.new(1,0,1,0)
    f.Position = pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3 = col or T.Surface
    f.BorderSizePixel = 0
    if name then f.Name = name end
    f.Parent = par
    return f
end
local function mkLabel(par, txt, sz, pos, col, fs, name)
    local l = Instance.new("TextLabel")
    l.Size = sz or UDim2.new(1,0,0,22)
    l.Position = pos or UDim2.new(0,0,0,0)
    l.BackgroundTransparency = 1
    l.TextColor3 = col or T.Text
    l.TextSize = fs or 14
    l.Font = Enum.Font.GothamMedium
    l.Text = txt or ""
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    if name then l.Name = name end
    l.Parent = par
    return l
end
local function mkBtn(par, txt, sz, pos, col, name)
    local b = Instance.new("TextButton")
    b.Size = sz or UDim2.new(1,0,0,36)
    b.Position = pos or UDim2.new(0,0,0,0)
    b.BackgroundColor3 = col or T.Accent
    b.TextColor3 = T.Text
    b.TextSize = 14
    b.Font = Enum.Font.GothamBold
    b.Text = txt or "Button"
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    if name then b.Name = name end
    mkCorner(b, 8)
    local orig = col or T.Accent
    b.MouseEnter:Connect(function() tw(b, {BackgroundColor3 = T.AccHov}, 0.1) end)
    b.MouseLeave:Connect(function() tw(b, {BackgroundColor3 = orig}, 0.1) end)
    b.Parent = par
    return b
end
local function mkBox(par, ph, sz, pos, name)
    local t = Instance.new("TextBox")
    t.Size = sz or UDim2.new(1,0,0,36)
    t.Position = pos or UDim2.new(0,0,0,0)
    t.BackgroundColor3 = T.Card
    t.TextColor3 = T.Text
    t.PlaceholderColor3 = T.Muted
    t.PlaceholderText = ph or ""
    t.TextSize = 14
    t.Font = Enum.Font.Gotham
    t.Text = ""
    t.BorderSizePixel = 0
    t.ClearTextOnFocus = false
    if name then t.Name = name end
    mkCorner(t, 8)
    mkStroke(t, T.Border, 1)
    mkPad(t, 0, 10, 0, 10)
    t.Parent = par
    return t
end

-- ScrollingFrame with built-in mouse + touch drag scrolling
local function mkScroll(par, sz, pos, name)
    local s = Instance.new("ScrollingFrame")
    s.Size = sz or UDim2.new(1,0,1,0)
    s.Position = pos or UDim2.new(0,0,0,0)
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 6
    s.ScrollBarImageColor3 = T.Accent
    s.CanvasSize = UDim2.new(0,0,0,0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.ScrollingEnabled = true
    if name then s.Name = name end
    s.Parent = par

    -- Mouse drag + momentum scrolling
    local dragging   = false
    local dragStartY = 0
    local canvasStartY= 0
    local lastDeltaY = 0
    local lastTime   = 0
    local velocity   = 0

    s.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton2
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging    = true
            dragStartY  = inp.Position.Y
            canvasStartY= s.CanvasPosition.Y
            velocity    = 0
            lastDeltaY  = 0
            lastTime    = tick()
        end
    end)
    s.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                      or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = dragStartY - inp.Position.Y
            local now   = tick()
            local dt    = now - lastTime
            if dt > 0 then
                velocity = (inp.Position.Y - (dragStartY - lastDeltaY)) / dt
            end
            lastDeltaY = delta
            lastTime   = now
            local newY = math.clamp(canvasStartY + delta, 0,
                math.max(0, s.CanvasSize.Y.Offset - s.AbsoluteSize.Y))
            s.CanvasPosition = Vector2.new(0, newY)
        end
    end)
    local function endDrag()
        if not dragging then return end
        dragging = false
        -- Momentum: fling after release
        local momentum = -velocity
        task.spawn(function()
            while math.abs(momentum) > 0.5 do
                task.wait(0.016)
                momentum = momentum * 0.88
                local ny = math.clamp(s.CanvasPosition.Y + momentum,
                    0, math.max(0, s.CanvasSize.Y.Offset - s.AbsoluteSize.Y))
                s.CanvasPosition = Vector2.new(0, ny)
            end
        end)
    end
    s.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.MouseButton2
        or inp.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then endDrag() end
    end)

    return s
end

local function mkList(par, gap)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, gap or 6)
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.Parent = par
end
local function mkGrid(par, cellSz, cellPad)
    local g = Instance.new("UIGridLayout")
    g.CellSize = cellSz or UDim2.new(0,110,0,110)
    g.CellPaddingSize = cellPad or UDim2.new(0,8,0,8)
    g.SortOrder = Enum.SortOrder.LayoutOrder
    g.Parent = par
end

-- =====================================================================
-- DRAGGABLE  (threshold so tap != drag)
-- =====================================================================
local DRAG_MIN = 8

local function makeDraggable(handle, target, onDragEnd)
    local active, moved, mStart, pStart = false, false, nil, nil
    local function xy(inp) return Vector2.new(inp.Position.X, inp.Position.Y) end
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            active = true; moved = false
            mStart = xy(inp); pStart = target.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not active then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            local d = xy(inp) - mStart
            if not moved and d.Magnitude < DRAG_MIN then return end
            moved = true
            target.Position = UDim2.new(
                pStart.X.Scale, pStart.X.Offset + d.X,
                pStart.Y.Scale, pStart.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if not active then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            local wasMoved = moved
            active = false; moved = false
            if wasMoved and onDragEnd then onDragEnd() end
        end
    end)
end

-- =====================================================================
-- SCREEN GUI
-- =====================================================================
local GUI = Instance.new("ScreenGui")
GUI.Name           = "AnimStudio"
GUI.ResetOnSpawn   = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.IgnoreGuiInset = true
GUI.DisplayOrder   = 999
GUI.Parent         = PGui
_G.AnimStudioRunning = GUI

-- =====================================================================
-- NOTIFICATIONS
-- =====================================================================
local NotifHost = mkFrame(GUI,
    UDim2.new(0,290,0.5,0), UDim2.new(1,-300,0,10), T.Bg, "Notifs")
NotifHost.BackgroundTransparency = 1
NotifHost.ZIndex = 50
mkList(NotifHost, 5)

local function notify(msg, kind, dur)
    dur = dur or 3.5
    local col = (kind=="success" and T.OK) or (kind=="warning" and T.Warn)
             or (kind=="error"   and T.Bad) or T.Accent
    local n = mkFrame(NotifHost, UDim2.new(1,-8,0,52), UDim2.new(0,4,0,0), T.Card, "N")
    n.ZIndex = 51; n.LayoutOrder = tick()
    mkCorner(n, 10); mkStroke(n, col, 2)
    local dot = mkLabel(n, "●", UDim2.new(0,16,1,0), UDim2.new(0,8,0,0), col, 18)
    dot.TextXAlignment = Enum.TextXAlignment.Center
    local lbl = mkLabel(n, msg, UDim2.new(1,-30,1,0), UDim2.new(0,26,0,0), T.Text, 12)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    n.Position = UDim2.new(1,10,0,0)
    tw(n, {Position = UDim2.new(0,4,0,0)}, 0.28)
    task.delay(dur, function()
        tw(n, {Position = UDim2.new(1,10,0,0)}, 0.22)
        task.wait(0.25); pcall(function() n:Destroy() end)
    end)
end

-- =====================================================================
-- CONFIRM DIALOG
-- =====================================================================
local function confirmDlg(title, msg, onSave, onDiscard)
    local ov  = mkFrame(GUI, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.new(0,0,0), "Ov")
    ov.BackgroundTransparency = 0.45; ov.ZIndex = 60
    local dlg = mkFrame(GUI, UDim2.new(0,380,0,190), UDim2.new(0.5,-190,0.5,-95), T.Surface, "Dlg")
    dlg.ZIndex = 61; mkCorner(dlg,12); mkStroke(dlg,T.Border,1); mkPad(dlg,18,18,18,18)
    mkLabel(dlg, title, UDim2.new(1,0,0,28), UDim2.new(0,0,0,0), T.Accent, 17).Font = Enum.Font.GothamBold
    mkLabel(dlg, msg,   UDim2.new(1,0,0,42), UDim2.new(0,0,0,32), T.Text, 14).TextWrapped = true
    local function cl() pcall(function() ov:Destroy() dlg:Destroy() end) end
    local row = mkFrame(dlg, UDim2.new(1,0,0,36), UDim2.new(0,0,1,-36), T.Surface)
    row.BackgroundTransparency = 1
    local sv = mkBtn(row,"Save",   UDim2.new(0,100,1,0),UDim2.new(0,  0,0,0),T.OK)
    local di = mkBtn(row,"Discard",UDim2.new(0,100,1,0),UDim2.new(0,108,0,0),T.Bad)
    local ca = mkBtn(row,"Cancel", UDim2.new(0,100,1,0),UDim2.new(0,216,0,0),T.Card)
    sv.MouseButton1Click:Connect(function() cl() if onSave    then pcall(onSave)    end end)
    di.MouseButton1Click:Connect(function() cl() if onDiscard then pcall(onDiscard) end end)
    ca.MouseButton1Click:Connect(cl)
end

-- =====================================================================
-- ASSET INSPECTOR
-- =====================================================================
local function inspectCard(raw, onImport, slotName)
    local id = extractId(raw)
    local ov = mkFrame(GUI,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.new(0,0,0),"IOv")
    ov.BackgroundTransparency = 0.45; ov.ZIndex = 55
    local card = mkFrame(GUI,UDim2.new(0,430,0,280),UDim2.new(0.5,-215,0.5,-140),T.Surface,"ICard")
    card.ZIndex = 56; mkCorner(card,14); mkStroke(card,T.Border,1); mkPad(card,18,18,18,18)
    local function close() pcall(function() ov:Destroy() card:Destroy() end) end
    mkLabel(card,"Asset Inspector",UDim2.new(1,0,0,28),UDim2.new(0,0,0,0),T.Accent,17).Font=Enum.Font.GothamBold
    if not id then
        mkLabel(card,"Could not extract a valid Asset ID.\nAccepted: Roblox URL, rbxassetid://, or plain number.",
            UDim2.new(1,0,0,50),UDim2.new(0,0,0,34),T.Bad,13).TextWrapped=true
        mkBtn(card,"Close",UDim2.new(1,0,0,36),UDim2.new(0,0,1,-36),T.Bad).MouseButton1Click:Connect(close)
        return
    end
    local aType = detectType(raw)
    local fmt = raw:find("roblox%.com") and "Roblox URL" or raw:find("rbxassetid") and "rbxassetid://" or "Numeric ID"
    local rows = {{"Extracted ID:",id},{"Input Format:",fmt},{"Detected Type:",aType},{"Target Slot:",slotName or "?"}}
    for i,r in ipairs(rows) do
        mkLabel(card,r[1],UDim2.new(0.44,0,0,20),UDim2.new(0,0,0,32+(i-1)*26),T.Sub,13)
        mkLabel(card,r[2],UDim2.new(0.54,0,0,20),UDim2.new(0.44,0,0,32+(i-1)*26),T.Text,13)
    end
    if aType == "Pack" then
        mkLabel(card,"⚠  This looks like an Animation PACK.\nImport each ID individually.",
            UDim2.new(1,0,0,44),UDim2.new(0,0,0,138),T.Warn,13).TextWrapped=true
        mkBtn(card,"OK — Understood",UDim2.new(1,0,0,36),UDim2.new(0,0,1,-36),T.Bad).MouseButton1Click:Connect(close)
    else
        local impB = mkBtn(card,"✔  Import to "..(slotName or "slot"),UDim2.new(0.58,0,0,36),UDim2.new(0,0,1,-36),T.OK)
        local canB = mkBtn(card,"Cancel",UDim2.new(0.38,0,0,36),UDim2.new(0.62,0,1,-36),T.Bad)
        impB.MouseButton1Click:Connect(function() close() if onImport then pcall(onImport,id,aType) end end)
        canB.MouseButton1Click:Connect(close)
    end
end

-- =====================================================================
-- TOGGLE BUTTON
-- =====================================================================
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name             = "StudioToggle"
ToggleBtn.Size             = UDim2.new(0,58,0,58)
ToggleBtn.Position         = UDim2.new(0.5,-29,0.5,-29)
ToggleBtn.BackgroundColor3 = T.Accent
ToggleBtn.Text             = "AS"
ToggleBtn.TextColor3       = Color3.new(1,1,1)
ToggleBtn.TextSize         = 13
ToggleBtn.Font             = Enum.Font.GothamBold
ToggleBtn.BorderSizePixel  = 0
ToggleBtn.AutoButtonColor  = false
ToggleBtn.ZIndex           = 100
mkCorner(ToggleBtn, 18)
ToggleBtn.Parent = GUI

ToggleBtn.MouseEnter:Connect(function() tw(ToggleBtn, {BackgroundColor3=T.AccHov}, 0.1) end)
ToggleBtn.MouseLeave:Connect(function() tw(ToggleBtn, {BackgroundColor3=T.Accent}, 0.1) end)

makeDraggable(ToggleBtn, ToggleBtn, function()
    local v = vp(); local ap = ToggleBtn.AbsolutePosition; local as = ToggleBtn.AbsoluteSize
    local ny = math.clamp(ap.Y, 10, v.Y - as.Y - 10)
    if ap.X + as.X/2 < v.X/2 then tw(ToggleBtn,{Position=UDim2.new(0,10,0,ny)},0.18)
    else tw(ToggleBtn,{Position=UDim2.new(0,v.X-as.X-10,0,ny)},0.18) end
end)

-- =====================================================================
-- MAIN WINDOW  (87% screen, centered)
-- =====================================================================
local Win = mkFrame(GUI, UDim2.new(0.87,0,0.87,0), UDim2.new(0.065,0,0.065,0), T.Bg, "MainWin")
Win.Visible = false; Win.ZIndex = 10
mkCorner(Win, 14); mkStroke(Win, T.Border, 1)

-- Title bar
local TBar = mkFrame(Win, UDim2.new(1,0,0,46), UDim2.new(0,0,0,0), T.Surface, "TBar")
mkCorner(TBar, 14)
mkFrame(TBar, UDim2.new(1,0,0.55,0), UDim2.new(0,0,0.45,0), T.Surface)
local TitleLbl = mkLabel(TBar,"  ✦ Animation Studio  v3.0",UDim2.new(1,-52,1,0),UDim2.new(0,0,0,0),T.Accent,15)
TitleLbl.Font = Enum.Font.GothamBold
local CloseBtn = mkBtn(TBar,"✕",UDim2.new(0,34,0,34),UDim2.new(1,-40,0,6),T.Bad,"CloseBtn")
CloseBtn.TextSize = 14
makeDraggable(TBar, Win)

-- Tab bar
local TabBar = mkFrame(Win, UDim2.new(1,0,0,40), UDim2.new(0,0,0,46), T.Surface, "TabBar")
local TABS   = {"Home","Packs","Emotes","Explorer","Editor"}
local TabBtns= {}
local tW = 1 / #TABS
for i, name in ipairs(TABS) do
    local b = mkBtn(TabBar, name,
        UDim2.new(tW,-6,1,-8), UDim2.new((i-1)*tW+0.005,0,0,4), T.Card, "Tab_"..name)
    b.TextSize = 12; mkStroke(b, T.Border, 1)
    TabBtns[name] = b
end

-- Content
local Content  = mkFrame(Win, UDim2.new(1,0,1,-90), UDim2.new(0,0,0,86), T.Bg, "Content")
-- Status bar
local SBar = mkFrame(Win, UDim2.new(1,0,0,20), UDim2.new(0,0,1,-20), T.Surface, "SBar")
local SLbl = mkLabel(SBar,"  Ready",UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),T.Muted,11)
SLbl.TextXAlignment = Enum.TextXAlignment.Left
local function setStatus(s) SLbl.Text="  "..s end

-- Panels
local Panels = {}
for _, name in ipairs(TABS) do
    local p = mkFrame(Content, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), T.Bg, "P_"..name)
    p.Visible = false; Panels[name] = p
end

local ActiveTab = "Home"
local function switchTab(name)
    ActiveTab = name
    for n,p in pairs(Panels) do p.Visible = (n==name) end
    for n,b in pairs(TabBtns) do b.BackgroundColor3 = (n==name) and T.Accent or T.Card end
    setStatus("Tab: "..name)
end
for _, name in ipairs(TABS) do
    TabBtns[name].MouseButton1Click:Connect(function() switchTab(name) end)
end

-- =====================================================================
-- OPEN / CLOSE
-- =====================================================================
local UIOpen = false
local function openUI()
    UIOpen = true; Win.Visible = true
    Win.BackgroundTransparency = 1
    tw(Win, {BackgroundTransparency=0}, 0.2)
    switchTab(ActiveTab)
    setStatus("Animation Studio v3.0 — Ready")
end
local function closeUI()
    UIOpen = false
    tw(Win, {BackgroundTransparency=1}, 0.18)
    task.delay(0.22, function() if not UIOpen then Win.Visible=false end end)
end

-- Toggle: InputBegan/InputEnded with drag threshold
do
    local btnDown, btnMoved = false, false
    local bStart = Vector2.zero
    ToggleBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            btnDown=true; btnMoved=false
            bStart=Vector2.new(inp.Position.X,inp.Position.Y)
        end
    end)
    ToggleBtn.InputChanged:Connect(function(inp)
        if not btnDown then return end
        if inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch then
            if (Vector2.new(inp.Position.X,inp.Position.Y)-bStart).Magnitude > DRAG_MIN then
                btnMoved=true
            end
        end
    end)
    ToggleBtn.InputEnded:Connect(function(inp)
        if not btnDown then return end
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            btnDown=false
            if not btnMoved then if UIOpen then closeUI() else openUI() end end
        end
    end)
end
CloseBtn.MouseButton1Click:Connect(closeUI)

-- =====================================================================
-- HOME TAB
-- =====================================================================
local HP = Panels["Home"]
mkPad(HP,8,8,8,8)

-- Slot list (left)
local SlotPanel = mkFrame(HP,UDim2.new(0,200,1,-4),UDim2.new(0,0,0,0),T.Surface,"SlotPanel")
mkCorner(SlotPanel,10); mkStroke(SlotPanel,T.Border,1)
mkLabel(SlotPanel,"Animation Slots",UDim2.new(1,-12,0,24),UDim2.new(0,6,0,5),T.Accent,13).Font=Enum.Font.GothamBold
local SlotScroll = mkScroll(SlotPanel,UDim2.new(1,-6,1,-34),UDim2.new(0,3,0,32))
mkList(SlotScroll,3)

-- Detail panel (right)
local Detail = mkFrame(HP,UDim2.new(1,-212,1,-4),UDim2.new(0,208,0,0),T.Surface,"Detail")
mkCorner(Detail,10); mkStroke(Detail,T.Border,1); mkPad(Detail,12,12,12,12)

local DTitle  = mkLabel(Detail,"Select a slot →",UDim2.new(1,0,0,26),UDim2.new(0,0,0,0),T.Text,17)
DTitle.Font = Enum.Font.GothamBold
local DStatus = mkLabel(Detail,"",UDim2.new(1,0,0,18),UDim2.new(0,0,0,28),T.Muted,12)
local DDefLbl = mkLabel(Detail,"",UDim2.new(1,0,0,16),UDim2.new(0,0,0,48),T.Muted,11)

mkLabel(Detail,"Animation ID or Roblox Link:",UDim2.new(1,0,0,16),UDim2.new(0,0,0,70),T.Sub,12)
local IdBox = mkBox(Detail,"Paste ID, rbxassetid://, or link…",UDim2.new(1,0,0,34),UDim2.new(0,0,0,88))

-- Buttons row
local ARow = mkFrame(Detail,UDim2.new(1,0,0,32),UDim2.new(0,0,0,130),T.Bg)
ARow.BackgroundTransparency=1
local ImpBtn = mkBtn(ARow,"⬇ Import", UDim2.new(0.33,-3,1,0),UDim2.new(0,0,0,0),     T.OK)
local PrvBtn = mkBtn(ARow,"▶ Preview",UDim2.new(0.33,-3,1,0),UDim2.new(0.335,3,0,0), T.Accent)
local RstBtn = mkBtn(ARow,"↺ Reset",  UDim2.new(0.32,-2,1,0),UDim2.new(0.675,3,0,0), T.Bad)
ImpBtn.TextSize=12; PrvBtn.TextSize=12; RstBtn.TextSize=12

-- Playback controls
mkLabel(Detail,"Playback Mode:",UDim2.new(0.44,0,0,18),UDim2.new(0,0,0,174),T.Sub,12)
local PbModeBtn = mkBtn(Detail,"Mode: Dynamic",UDim2.new(0.54,0,0,28),UDim2.new(0.45,0,0,170),T.Card)
PbModeBtn.TextSize=11

mkLabel(Detail,"Speed Multiplier:",UDim2.new(0.44,0,0,18),UDim2.new(0,0,0,210),T.Sub,12)
local SpeedBox = mkBox(Detail,"1.0",UDim2.new(0.34,0,0,28),UDim2.new(0.55,0,0,206))
SpeedBox.Text="1.0"; SpeedBox.TextSize=12

-- Idle2 info banner (shown when Idle2 slot selected)
local I2Banner = mkFrame(Detail,UDim2.new(1,0,0,38),UDim2.new(0,0,0,248),T.Card,"I2Banner")
mkCorner(I2Banner,8); mkStroke(I2Banner,T.Warn,1)
local I2Lbl = mkLabel(I2Banner,
    "  ★ Idle 2 auto-plays every 40 s for 15 s, then returns to Idle",
    UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),T.Warn,11)
I2Lbl.TextXAlignment = Enum.TextXAlignment.Left
I2Banner.Visible = false

-- Slot buttons
local SelectedSlot = "Idle"
local SlotBtns     = {}

local function refreshDetail()
    local slot   = SelectedSlot
    local custom = SavedAnims[slot]
    DTitle.Text   = slot == "Idle2" and "Idle 2 Animation" or slot.." Animation"
    DDefLbl.Text  = "Default ID: "..(DEFAULT_IDS[slot] ~= "" and DEFAULT_IDS[slot] or "None (user-defined)")
    I2Banner.Visible = (slot == "Idle2")
    if custom and custom ~= "" then
        DStatus.Text       = "✔  Custom Active — "..custom
        DStatus.TextColor3 = T.OK
        IdBox.Text         = custom
    else
        DStatus.Text       = slot=="Idle2" and "No Idle 2 animation set yet" or "Using Roblox Default"
        DStatus.TextColor3 = T.Muted
        IdBox.Text         = ""
    end
    PbModeBtn.Text = "Mode: "..PlaybackMode
end

for i, slot in ipairs(SLOT_NAMES) do
    local label = slot == "Idle2" and "Idle 2  ★" or slot
    local b = mkBtn(SlotScroll, label,
        UDim2.new(1,-6,0,36), UDim2.new(0,3,0,0), T.Card, "S_"..slot)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.LayoutOrder = i; b.TextSize = 13
    mkPad(b,0,0,0,10)
    SlotBtns[slot] = b
    b.MouseButton1Click:Connect(function()
        if SlotBtns[SelectedSlot] then SlotBtns[SelectedSlot].BackgroundColor3=T.Card end
        SelectedSlot = slot; b.BackgroundColor3 = T.AccDark
        refreshDetail()
    end)
end

ImpBtn.MouseButton1Click:Connect(function()
    local raw = IdBox.Text
    if raw=="" then notify("Enter an ID or link first.","warning") return end
    inspectCard(raw, function(id, kind)
        local slot = SelectedSlot
        local old  = SavedAnims[slot]
        applyAnim(slot, id)
        pushUndo({
            undo=function() applyAnim(slot,old) refreshDetail() end,
            redo=function() applyAnim(slot,id)  refreshDetail() end,
        })
        refreshDetail()
        notify("Imported → "..slot.." (ID: "..id..")","success",4)
    end, SelectedSlot)
end)

PrvBtn.MouseButton1Click:Connect(function()
    local id = SavedAnims[SelectedSlot]
    if id=="" then id=DEFAULT_IDS[SelectedSlot] end
    if not id or id=="" then notify("No animation to preview.","warning") return end
    local hum = AC.Hum
    if not hum then notify("Character not ready.","error") return end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://"..id
    local ok, tr = pcall(function() return AC.Animator:LoadAnimation(anim) end)
    if ok and tr then tr:Play() notify("Previewing "..SelectedSlot.." — "..id,"info",2)
    else notify("Could not load animation. Check the ID.","error") end
end)

RstBtn.MouseButton1Click:Connect(function()
    local slot = SelectedSlot
    confirmDlg("Reset Animation","Reset '"..slot.."' to default?",
        function()
            local old = SavedAnims[slot]
            applyAnim(slot,"")
            pushUndo({
                undo=function() applyAnim(slot,old) refreshDetail() end,
                redo=function() applyAnim(slot,"")  refreshDetail() end,
            })
            refreshDetail()
            notify("Reset "..slot.." to default.","success")
        end, nil)
end)

PbModeBtn.MouseButton1Click:Connect(function()
    PlaybackMode = PlaybackMode=="Dynamic" and "Static" or "Dynamic"
    PbModeBtn.Text = "Mode: "..PlaybackMode
    notify("Playback: "..PlaybackMode,"info",2)
end)

SpeedBox.FocusLost:Connect(function()
    local v = tonumber(SpeedBox.Text)
    if v and v>0 then PlaybackMult=v
    else SpeedBox.Text=tostring(PlaybackMult) end
end)

refreshDetail()
if SlotBtns["Idle"] then SlotBtns["Idle"].BackgroundColor3=T.AccDark end

-- =====================================================================
-- PACKS TAB
-- =====================================================================
local PP = Panels["Packs"]
mkPad(PP,10,10,10,10)
mkLabel(PP,"Animation Packs",UDim2.new(1,0,0,26),UDim2.new(0,0,0,0),T.Accent,16).Font=Enum.Font.GothamBold
mkLabel(PP,"Save your current slot setup as a named pack and reapply anytime.",
    UDim2.new(1,0,0,16),UDim2.new(0,0,0,28),T.Sub,12)
local PkSearch = mkBox(PP,"Search packs…",UDim2.new(0.62,0,0,32),UDim2.new(0,0,0,50))
PkSearch.TextSize=12
local NewPkBtn = mkBtn(PP,"+ Save Current as Pack",UDim2.new(0.36,-4,0,32),UDim2.new(0.64,4,0,50),T.Accent)
NewPkBtn.TextSize=11
local PkScroll = mkScroll(PP,UDim2.new(1,0,1,-92),UDim2.new(0,0,0,92))
mkList(PkScroll,6)

local function refreshPacks()
    for _,c in ipairs(PkScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local f=PkSearch.Text:lower()
    for i,pk in ipairs(Packs) do
        if f~="" and not pk.name:lower():find(f,1,true) then continue end
        local r=mkFrame(PkScroll,UDim2.new(1,-8,0,54),UDim2.new(0,4,0,0),T.Card)
        r.LayoutOrder=i; mkCorner(r,8); mkStroke(r,T.Border,1); mkPad(r,8,8,8,12)
        mkLabel(r,pk.name,UDim2.new(0.65,0,0.5,0),UDim2.new(0,0,0,0),T.Text,14).Font=Enum.Font.GothamSemibold
        local n=0; for _ in pairs(pk.anims) do n+=1 end
        mkLabel(r,n.." slot(s)",UDim2.new(0.65,0,0.5,0),UDim2.new(0,0,0.5,0),T.Muted,11)
        local ub=mkBtn(r,"Apply",UDim2.new(0,60,0,28),UDim2.new(1,-134,0,13),T.Accent); ub.TextSize=12
        ub.MouseButton1Click:Connect(function()
            for slot,id in pairs(pk.anims) do applyAnim(slot,id) end
            refreshDetail(); notify("Applied pack: "..pk.name,"success")
        end)
        local db=mkBtn(r,"Delete",UDim2.new(0,60,0,28),UDim2.new(1,-70,0,13),T.Bad); db.TextSize=12
        db.MouseButton1Click:Connect(function() table.remove(Packs,i); refreshPacks() end)
    end
end

NewPkBtn.MouseButton1Click:Connect(function()
    local anims={}
    for slot,id in pairs(SavedAnims) do if id and id~="" then anims[slot]=id end end
    if not next(anims) then notify("No custom animations set yet.","warning") return end
    table.insert(Packs,{name="Pack "..(#Packs+1),anims=anims})
    refreshPacks(); notify("Saved as Pack "..(#Packs),"success")
end)
PkSearch:GetPropertyChangedSignal("Text"):Connect(refreshPacks)
refreshPacks()

-- =====================================================================
-- EMOTES TAB
-- =====================================================================
local EP = Panels["Emotes"]
mkPad(EP,8,8,8,8)
local EmTop=mkFrame(EP,UDim2.new(1,0,0,36),UDim2.new(0,0,0,0),T.Bg)
EmTop.BackgroundTransparency=1
local EmSearch =mkBox(EmTop,"Search emotes…",UDim2.new(0.56,-4,1,-4),UDim2.new(0,0,0,2))
EmSearch.TextSize=12
local FavToggle=mkBtn(EmTop,"★ Favs",UDim2.new(0.21,-4,1,-4),UDim2.new(0.57,4,0,2),T.Card)
FavToggle.TextSize=12
local AddEmBtn =mkBtn(EmTop,"+ Add", UDim2.new(0.20,-2,1,-4),UDim2.new(0.79,4,0,2),T.Accent)
AddEmBtn.TextSize=12

local showFavs=false
FavToggle.MouseButton1Click:Connect(function()
    showFavs=not showFavs
    FavToggle.BackgroundColor3=showFavs and T.Warn or T.Card
    FavToggle.Text=showFavs and "★ All" or "★ Favs"
end)

local EmScroll=mkScroll(EP,UDim2.new(1,0,1,-46),UDim2.new(0,0,0,44))
mkGrid(EmScroll,UDim2.new(0,110,0,110),UDim2.new(0,7,0,7))
mkPad(EmScroll,4,4,4,4)

local function refreshEmotes()
    for _,c in ipairs(EmScroll:GetChildren()) do
        if not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    local f=EmSearch.Text:lower()
    for i,em in ipairs(Emotes) do
        if showFavs and not em.favorited then continue end
        if f~="" and not em.name:lower():find(f,1,true) then continue end
        local card=mkFrame(EmScroll,UDim2.new(0,110,0,110),UDim2.new(0,0,0,0),T.Card)
        card.LayoutOrder=i; mkCorner(card,10); mkStroke(card,T.Border,1)
        local thumb=mkFrame(card,UDim2.new(1,-4,0,68),UDim2.new(0,2,0,2),T.Surface)
        mkCorner(thumb,8)
        local tl=mkLabel(thumb,"No Preview",UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),T.Muted,10)
        tl.TextXAlignment=Enum.TextXAlignment.Center
        local nl=mkLabel(card,em.name,UDim2.new(1,-4,0,14),UDim2.new(0,2,0,74),T.Text,10)
        nl.TextXAlignment=Enum.TextXAlignment.Center
        local playB=mkBtn(card,"▶",UDim2.new(0.5,-2,0,18),UDim2.new(0,1,1,-20),T.Accent)
        playB.TextSize=11
        playB.MouseButton1Click:Connect(function()
            local hum=AC.Hum; if not hum then return end
            local anim=Instance.new("Animation"); anim.AnimationId="rbxassetid://"..em.id
            local ok,tr=pcall(function() return AC.Animator:LoadAnimation(anim) end)
            if ok and tr then tr:Play(); notify("Playing: "..em.name,"info",2) end
        end)
        local floatB=mkBtn(card,"⊞",UDim2.new(0.5,-2,0,18),UDim2.new(0.5,1,1,-20),T.Card)
        floatB.TextSize=11
        floatB.MouseButton1Click:Connect(function()
            local fb=Instance.new("TextButton")
            fb.Size=UDim2.new(0,70,0,70); fb.Position=UDim2.new(0.5,-35,0.5,-35)
            fb.BackgroundColor3=T.AccDark; fb.TextColor3=T.Text
            fb.Text=em.name:sub(1,7).."\n▶"; fb.TextSize=10; fb.Font=Enum.Font.GothamBold
            fb.ZIndex=90; fb.BorderSizePixel=0; fb.AutoButtonColor=false
            mkCorner(fb,14); mkStroke(fb,T.AccHov,2); fb.Parent=GUI
            makeDraggable(fb,fb,function()
                local v=vp(); local ap=fb.AbsolutePosition; local as=fb.AbsoluteSize
                local nx=ap.X+as.X/2<v.X/2 and 8 or v.X-as.X-8
                tw(fb,{Position=UDim2.new(0,nx,0,math.clamp(ap.Y,8,v.Y-as.Y-8))},0.18)
            end)
            fb.MouseButton1Click:Connect(function()
                local hum=AC.Hum; if not hum then return end
                local a2=Instance.new("Animation"); a2.AnimationId="rbxassetid://"..em.id
                local ok2,tr2=pcall(function() return AC.Animator:LoadAnimation(a2) end)
                if ok2 and tr2 then tr2:Play() end
            end)
            notify("Floating: "..em.name,"success",2)
        end)
    end
end

AddEmBtn.MouseButton1Click:Connect(function()
    local ov=mkFrame(GUI,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.new(0,0,0),"Ov")
    ov.BackgroundTransparency=0.45; ov.ZIndex=70
    local dlg=mkFrame(GUI,UDim2.new(0,360,0,200),UDim2.new(0.5,-180,0.5,-100),T.Surface,"ADlg")
    dlg.ZIndex=71; mkCorner(dlg,12); mkStroke(dlg,T.Border,1); mkPad(dlg,14,14,14,14)
    mkLabel(dlg,"Add Emote",UDim2.new(1,0,0,26),UDim2.new(0,0,0,0),T.Accent,16).Font=Enum.Font.GothamBold
    mkLabel(dlg,"Name:",UDim2.new(1,0,0,16),UDim2.new(0,0,0,30),T.Sub,12)
    local nb=mkBox(dlg,"Emote name…",UDim2.new(1,0,0,32),UDim2.new(0,0,0,48)); nb.TextSize=12
    mkLabel(dlg,"ID or Link:",UDim2.new(1,0,0,16),UDim2.new(0,0,0,86),T.Sub,12)
    local ib=mkBox(dlg,"ID or Roblox link…",UDim2.new(1,0,0,32),UDim2.new(0,0,0,104)); ib.TextSize=12
    local function cl2() pcall(function() ov:Destroy() dlg:Destroy() end) end
    local addB=mkBtn(dlg,"Add",   UDim2.new(0.48,0,0,32),UDim2.new(0,0,1,-32),T.OK)
    local canB=mkBtn(dlg,"Cancel",UDim2.new(0.48,0,0,32),UDim2.new(0.52,0,1,-32),T.Bad)
    canB.MouseButton1Click:Connect(cl2)
    addB.MouseButton1Click:Connect(function()
        local id2=extractId(ib.Text)
        if not id2 then notify("Invalid ID or link.","error") return end
        local n2=nb.Text~="" and nb.Text or ("Emote "..(#Emotes+1))
        table.insert(Emotes,{id=id2,name=n2,favorited=false})
        refreshEmotes(); notify("Added: "..n2,"success"); cl2()
    end)
end)
EmSearch:GetPropertyChangedSignal("Text"):Connect(refreshEmotes)

-- =====================================================================
-- EXPLORER TAB
-- =====================================================================
local XP = Panels["Explorer"]
mkPad(XP,10,10,10,10)
mkLabel(XP,"Explorer — Script & Animation Scanner",UDim2.new(1,0,0,26),UDim2.new(0,0,0,0),T.Accent,15).Font=Enum.Font.GothamBold
mkLabel(XP,"Scans Workspace for Animation objects and scripts with animation IDs.",
    UDim2.new(1,0,0,16),UDim2.new(0,0,0,28),T.Sub,12).TextWrapped=true
local XRow=mkFrame(XP,UDim2.new(1,0,0,34),UDim2.new(0,0,0,50),T.Bg)
XRow.BackgroundTransparency=1
local XBox   =mkBox(XRow,"Optional: paste a link or ID to inspect",UDim2.new(0.79,-4,1,-4),UDim2.new(0,0,0,2))
XBox.TextSize=12
local ScanBtn=mkBtn(XRow,"Scan",UDim2.new(0.19,-2,1,-4),UDim2.new(0.81,4,0,2),T.Accent)
ScanBtn.TextSize=12
local XScroll=mkScroll(XP,UDim2.new(1,0,1,-94),UDim2.new(0,0,0,90))
mkList(XScroll,5)

local function showScriptViewer(obj)
    local ov=mkFrame(GUI,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.new(0,0,0),"SOv")
    ov.BackgroundTransparency=0.45; ov.ZIndex=72
    local win=mkFrame(GUI,UDim2.new(0.8,0,0.8,0),UDim2.new(0.1,0,0.1,0),T.Surface,"SVWin")
    win.ZIndex=73; mkCorner(win,12); mkStroke(win,T.Border,1)
    local function closeV() pcall(function() ov:Destroy() win:Destroy() end) end
    mkLabel(win,"  [READ ONLY] "..obj.Name,UDim2.new(1,-46,0,34),UDim2.new(0,4,0,6),T.Accent,13).Font=Enum.Font.GothamBold
    local cl=mkBtn(win,"✕",UDim2.new(0,32,0,32),UDim2.new(1,-38,0,5),T.Bad)
    cl.MouseButton1Click:Connect(closeV)
    local sb=Instance.new("TextBox")
    sb.Size=UDim2.new(1,-16,1,-46); sb.Position=UDim2.new(0,8,0,42)
    sb.BackgroundColor3=T.Card; sb.TextColor3=T.Text; sb.TextSize=12
    sb.Font=Enum.Font.RobotoMono; sb.MultiLine=true; sb.TextEditable=false
    sb.TextXAlignment=Enum.TextXAlignment.Left; sb.TextYAlignment=Enum.TextYAlignment.Top
    sb.BorderSizePixel=0; sb.ZIndex=74
    mkCorner(sb,8); mkPad(sb,8,8,8,8)
    local src="[Source not accessible — "..obj:GetFullName().."]"
    pcall(function() if obj.Source and #obj.Source>0 then src=obj.Source end end)
    sb.Text=src; sb.Parent=win
    local found={}
    for id in src:gmatch("rbxassetid://(%d+)") do table.insert(found,id) end
    if #found>0 then notify(#found.." animation ID(s) found in "..obj.Name,"warning") end
end

ScanBtn.MouseButton1Click:Connect(function()
    for _,c in ipairs(XScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    local scripts,anims={},{}
    local function scanRoot(root)
        if not root then return end
        pcall(function()
            for _,obj in ipairs(root:GetDescendants()) do
                if obj:IsA("BaseScript") then table.insert(scripts,obj)
                elseif obj:IsA("Animation") then table.insert(anims,obj) end
            end
        end)
    end
    scanRoot(workspace)
    if LP.Character then scanRoot(LP.Character) end
    local order=0
    local sHdr=mkLabel(XScroll,"Scripts ("..#scripts..")",UDim2.new(1,-8,0,20),UDim2.new(0,4,0,0),T.Warn,12)
    sHdr.Font=Enum.Font.GothamBold; sHdr.LayoutOrder=order; order+=1
    for _,sc in ipairs(scripts) do
        local r=mkFrame(XScroll,UDim2.new(1,-8,0,42),UDim2.new(0,4,0,0),T.Card)
        r.LayoutOrder=order; order+=1; mkCorner(r,8); mkStroke(r,T.Border,1); mkPad(r,6,6,6,10)
        local icon=sc:IsA("LocalScript") and "[L]" or sc:IsA("ModuleScript") and "[M]" or "[S]"
        mkLabel(r,icon.."  "..sc.Name,UDim2.new(0.65,0,0.5,0),UDim2.new(0,0,0,0),T.Text,12).Font=Enum.Font.GothamSemibold
        mkLabel(r,sc:GetFullName(),UDim2.new(0.65,0,0.5,0),UDim2.new(0,0,0.5,0),T.Muted,10)
        local vb=mkBtn(r,"View",UDim2.new(0,56,0,24),UDim2.new(1,-62,0,9),T.Accent); vb.TextSize=11
        vb.MouseButton1Click:Connect(function() showScriptViewer(sc) end)
    end
    local aHdr=mkLabel(XScroll,"Animations ("..#anims..")",UDim2.new(1,-8,0,20),UDim2.new(0,4,0,0),T.OK,12)
    aHdr.Font=Enum.Font.GothamBold; aHdr.LayoutOrder=order; order+=1
    for _,an in ipairs(anims) do
        local pid=extractId(an.AnimationId) or an.AnimationId
        local r=mkFrame(XScroll,UDim2.new(1,-8,0,46),UDim2.new(0,4,0,0),T.Card)
        r.LayoutOrder=order; order+=1; mkCorner(r,8); mkStroke(r,T.Border,1); mkPad(r,6,6,6,10)
        mkLabel(r,an.Name,UDim2.new(0.55,0,0.5,0),UDim2.new(0,0,0,0),T.Text,12).Font=Enum.Font.GothamSemibold
        mkLabel(r,"ID: "..pid,UDim2.new(0.55,0,0.5,0),UDim2.new(0,0,0.5,0),T.Muted,10)
        local ib2=mkBtn(r,"Import",UDim2.new(0,66,0,24),UDim2.new(1,-72,0,11),T.OK); ib2.TextSize=11
        ib2.MouseButton1Click:Connect(function()
            local slot=SelectedSlot; local old=SavedAnims[slot]
            applyAnim(slot,pid)
            pushUndo({undo=function() applyAnim(slot,old); refreshDetail() end,
                      redo=function() applyAnim(slot,pid); refreshDetail() end})
            refreshDetail(); notify("Imported to "..slot..": "..pid,"success")
        end)
    end
    if #scripts==0 and #anims==0 then
        local e=mkLabel(XScroll,"Nothing found in Workspace.",UDim2.new(1,-8,0,26),UDim2.new(0,4,0,0),T.Muted,13)
        e.TextXAlignment=Enum.TextXAlignment.Center; e.LayoutOrder=order
    end
    setStatus("Scan: "..#scripts.." script(s), "..#anims.." animation(s)")
end)

-- =====================================================================
-- EDITOR TAB
-- =====================================================================
local EdP = Panels["Editor"]
mkPad(EdP,10,10,10,10)
mkLabel(EdP,"Animation Editor",UDim2.new(1,0,0,26),UDim2.new(0,0,0,0),T.Accent,16).Font=Enum.Font.GothamBold
mkLabel(EdP,"Enters an isolated studio room with a cloned copy of your character.",
    UDim2.new(1,0,0,16),UDim2.new(0,0,0,28),T.Sub,12).TextWrapped=true
local RigBtn=mkBtn(EdP,"Rig: R15",UDim2.new(0.18,0,0,30),UDim2.new(0,0,0,50),T.Card); RigBtn.TextSize=12
local rigType="R15"
RigBtn.MouseButton1Click:Connect(function()
    rigType=rigType=="R15" and "R6" or "R15"; RigBtn.Text="Rig: "..rigType
end)
local EnterBtn=mkBtn(EdP,"▶  Enter Animation Studio",UDim2.new(0.55,0,0,42),UDim2.new(0.225,0,0,88),T.Accent)
EnterBtn.TextSize=14
local EdStatus=mkLabel(EdP,"",UDim2.new(1,0,0,20),UDim2.new(0,0,0,140),T.Muted,12)

-- Timeline
local TL=mkFrame(EdP,UDim2.new(1,0,0,130),UDim2.new(0,0,1,-144),T.Surface,"TL")
TL.Visible=false; mkCorner(TL,10); mkStroke(TL,T.Border,1); mkPad(TL,8,8,8,8)
mkLabel(TL,"Timeline",UDim2.new(0.3,0,0,18),UDim2.new(0,0,0,0),T.Accent,12).Font=Enum.Font.GothamBold
local TrackBar=mkFrame(TL,UDim2.new(1,0,0,44),UDim2.new(0,0,0,20),T.Card,"Track")
mkCorner(TrackBar,6); mkStroke(TrackBar,T.Border,1)
local KfCount=0
local function addKfMark(pct,name)
    pct=math.clamp(pct,0,0.97)
    local mk=mkFrame(TrackBar,UDim2.new(0,10,0.7,0),UDim2.new(pct,-5,0.15,0),T.Accent)
    mkCorner(mk,3)
    local kl=mkLabel(mk,name or "",UDim2.new(0,50,0,12),UDim2.new(0,-3,0,-14),T.Text,8)
    kl.TextXAlignment=Enum.TextXAlignment.Center
end
local PbRow=mkFrame(TL,UDim2.new(1,0,0,28),UDim2.new(0,0,0,78),T.Bg)
PbRow.BackgroundTransparency=1
local function pbB(txt,x,col)
    local b=mkBtn(PbRow,txt,UDim2.new(0,42,1,-2),UDim2.new(0,x,0,1),col or T.Accent); b.TextSize=12
    return b
end
local PlayBtn2  = pbB("▶",  0)
local PauseBtn2 = pbB("⏸", 46, T.Card)
local StopBtn2  = pbB("■",  92, T.Bad)
local AddKfBtn  = mkBtn(PbRow,"+ KF",UDim2.new(0,52,1,-2),UDim2.new(0,140,0,1),T.OK); AddKfBtn.TextSize=11
local UndoBtn2  = mkBtn(PbRow,"↩",  UDim2.new(0,36,1,-2),UDim2.new(0,196,0,1),T.Card)
local RedoBtn2  = mkBtn(PbRow,"↪",  UDim2.new(0,36,1,-2),UDim2.new(0,236,0,1),T.Card)
UndoBtn2.MouseButton1Click:Connect(doUndo)
RedoBtn2.MouseButton1Click:Connect(doRedo)

-- Props panel
local PropsPanel=mkFrame(EdP,UDim2.new(0.28,-4,1,-50),UDim2.new(0.72,4,0,46),T.Surface,"Props")
PropsPanel.Visible=false; mkCorner(PropsPanel,10); mkStroke(PropsPanel,T.Border,1); mkPad(PropsPanel,8,8,8,8)
mkLabel(PropsPanel,"Motor6D / Properties",UDim2.new(1,0,0,20),UDim2.new(0,0,0,0),T.Accent,12).Font=Enum.Font.GothamBold
local PropScroll=mkScroll(PropsPanel,UDim2.new(1,0,1,-28),UDim2.new(0,0,0,24))
mkList(PropScroll,4)

local StudioModel,EdClone,EdDirty,EdActive,EdPlaying,EdTime=nil,nil,false,false,false,0

local function buildStudio()
    local m=Instance.new("Model"); m.Name="AnimStudio_Env"
    local fl=Instance.new("Part")
    fl.Size=Vector3.new(50,1,50); fl.Position=Vector3.new(0,-0.5,0)
    fl.Anchored=true; fl.Material=Enum.Material.SmoothPlastic
    fl.Color=Color3.fromRGB(20,20,32); fl.CanCollide=true; fl.Parent=m
    for i=-12,12,3 do
        for _,h in ipairs({true,false}) do
            local g=Instance.new("Part")
            g.Size=h and Vector3.new(50,.02,.06) or Vector3.new(.06,.02,50)
            g.Position=h and Vector3.new(0,.01,i) or Vector3.new(i,.01,0)
            g.Anchored=true; g.CanCollide=false; g.Material=Enum.Material.Neon
            g.Color=Color3.fromRGB(50,50,100); g.CastShadow=false; g.Parent=m
        end
    end
    local sp=Instance.new("Part")
    sp.Size=Vector3.new(1,1,1); sp.Position=Vector3.new(0,14,0)
    sp.Anchored=true; sp.Transparency=1; sp.CanCollide=false; sp.Parent=m
    local sl=Instance.new("SpotLight")
    sl.Brightness=6; sl.Range=22; sl.Angle=50
    sl.Color=Color3.fromRGB(210,210,255); sl.Face=Enum.NormalId.Bottom; sl.Parent=sp
    m.Parent=workspace; return m
end

local function enterEditor()
    if EdActive then return end
    EdActive=true; ToggleBtn.Visible=false
    EdStatus.Text="Entering studio…"; EdStatus.TextColor3=T.Warn
    local fade=mkFrame(GUI,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.new(0,0,0),"Fade")
    fade.BackgroundTransparency=1; fade.ZIndex=95
    tw(fade,{BackgroundTransparency=0},0.5); task.wait(0.6)
    StudioModel=buildStudio()
    if LP.Character then
        EdClone=LP.Character:Clone()
        for _,s in ipairs(EdClone:GetDescendants()) do if s:IsA("BaseScript") then s.Disabled=true end end
        EdClone:PivotTo(CFrame.new(0,1.5,0)); EdClone.Parent=workspace
        for _,p in ipairs(LP.Character:GetDescendants()) do if p:IsA("BasePart") then p.Transparency=1 end end
        local rHRP=LP.Character:FindFirstChild("HumanoidRootPart")
        if rHRP then rHRP.Anchored=true end
    end
    Camera.CameraType=Enum.CameraType.Scriptable
    tw(Camera,{CFrame=CFrame.new(0,6,14)*CFrame.Angles(math.rad(-18),0,0)},0.5)
    tw(fade,{BackgroundTransparency=1},0.4); task.wait(0.45)
    pcall(function() fade:Destroy() end)
    TL.Visible=true; PropsPanel.Visible=true
    PropScroll:ClearAllChildren(); mkList(PropScroll,4)
    if EdClone then
        for _,m6 in ipairs(EdClone:GetDescendants()) do
            if m6:IsA("Motor6D") then
                local row=mkFrame(PropScroll,UDim2.new(1,-4,0,26),UDim2.new(0,2,0,0),T.Card)
                mkCorner(row,6)
                mkLabel(row,m6.Name,UDim2.new(0.5,0,1,0),UDim2.new(0,4,0,0),T.Sub,10)
                local vbox=mkBox(row,"Rotation",UDim2.new(0.46,0,0.8,0),UDim2.new(0.52,0,0.1,0))
                vbox.TextSize=10; vbox.Text="0, 0, 0"
                vbox.FocusLost:Connect(function()
                    EdDirty=true; EdStatus.Text="Unsaved changes"; EdStatus.TextColor3=T.Warn
                end)
            end
        end
    end
    EdStatus.Text="Studio active ("..rigType..")"; EdStatus.TextColor3=T.OK
    EnterBtn.Text="✕  Exit Studio"; EnterBtn.BackgroundColor3=T.Bad
end

local function exitEditor()
    if not EdActive then return end
    local function doExit()
        local fade=mkFrame(GUI,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.new(0,0,0),"Fade")
        fade.BackgroundTransparency=1; fade.ZIndex=95
        tw(fade,{BackgroundTransparency=0},0.4); task.wait(0.5)
        if StudioModel then pcall(function() StudioModel:Destroy() end); StudioModel=nil end
        if EdClone    then pcall(function() EdClone:Destroy()     end); EdClone=nil end
        if LP.Character then
            for _,p in ipairs(LP.Character:GetDescendants()) do if p:IsA("BasePart") then p.Transparency=0 end end
            local rHRP=LP.Character:FindFirstChild("HumanoidRootPart")
            if rHRP then rHRP.Anchored=false end
        end
        pcall(function() Camera.CameraType=Enum.CameraType.Custom end)
        TL.Visible=false; PropsPanel.Visible=false
        EdActive=false; EdDirty=false; EdPlaying=false; EdTime=0
        EnterBtn.Text="▶  Enter Animation Studio"; EnterBtn.BackgroundColor3=T.Accent
        EdStatus.Text="Exited."; EdStatus.TextColor3=T.Muted
        tw(fade,{BackgroundTransparency=1},0.35); task.wait(0.4)
        pcall(function() fade:Destroy() end)
        ToggleBtn.Visible=true; notify("Exited Animation Studio.","info")
    end
    if EdDirty then
        confirmDlg("Exit Studio","Unsaved changes. Discard and exit?",nil,doExit)
    else doExit() end
end

EnterBtn.MouseButton1Click:Connect(function()
    if EdActive then exitEditor() else enterEditor() end
end)

PlayBtn2.MouseButton1Click:Connect(function()
    EdPlaying=true
    if EdClone then
        local hum2=EdClone:FindFirstChildOfClass("Humanoid")
        if hum2 then
            local id=SavedAnims[SelectedSlot]
            if id and id~="" then
                local a=Instance.new("Animation"); a.AnimationId="rbxassetid://"..id
                local ok,tr=pcall(function() return hum2:LoadAnimation(a) end)
                if ok and tr then tr:Play() end
            end
        end
    end
end)
PauseBtn2.MouseButton1Click:Connect(function()
    EdPlaying=false
    if EdClone then
        local h2=EdClone:FindFirstChildOfClass("Humanoid")
        if h2 then
            local an=h2:FindFirstChildOfClass("Animator")
            if an then for _,tr in ipairs(an:GetPlayingAnimationTracks()) do pcall(function() tr:AdjustSpeed(0) end) end end
        end
    end
end)
StopBtn2.MouseButton1Click:Connect(function()
    EdPlaying=false; EdTime=0
    if EdClone then
        local h2=EdClone:FindFirstChildOfClass("Humanoid")
        if h2 then
            local an=h2:FindFirstChildOfClass("Animator")
            if an then for _,tr in ipairs(an:GetPlayingAnimationTracks()) do pcall(function() tr:Stop(0) end) end end
        end
    end
end)
AddKfBtn.MouseButton1Click:Connect(function()
    KfCount+=1; local name="KF"..KfCount
    addKfMark(math.min((KfCount-1)*0.09,0.95),name)
    EdDirty=true; EdStatus.Text="Unsaved changes"; EdStatus.TextColor3=T.Warn
    notify("Added "..name,"success",2)
end)
RunService.Heartbeat:Connect(function(dt)
    if EdActive and EdPlaying then EdTime+=dt end
end)

-- =====================================================================
-- DEFAULT EMOTES
-- =====================================================================
local defaultEmotes={
    {"507770239","Wave"},{"507771019","Point"},
    {"507769814","Cheer"},{"507770818","Laugh"},{"507771508","Dance"},
}
for _,e in ipairs(defaultEmotes) do
    table.insert(Emotes,{id=e[1],name=e[2],favorited=false})
end
refreshEmotes()

-- =====================================================================
-- CLEANUP ON CHARACTER REMOVAL
-- =====================================================================
LP.CharacterRemoving:Connect(function()
    if EdActive then
        if StudioModel then pcall(function() StudioModel:Destroy() end) end
        if EdClone then pcall(function() EdClone:Destroy() end) end
        EdActive=false; TL.Visible=false; PropsPanel.Visible=false
    end
end)

-- =====================================================================
-- DONE
-- =====================================================================
notify("Animation Studio v3.0 loaded! Tap AS to open.","success",5)
print("[AnimStudio v3.0] Custom controller active. Click the AS button to open.")
