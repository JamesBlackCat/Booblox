--[[
╔══════════════════════════════════════════════════════════════════╗
║              ROBLOX ANIMATION STUDIO  v1.0                      ║
║         Complete In-Game Animation Operating System             ║
╠══════════════════════════════════════════════════════════════════╣
║  PLACEMENT:  StarterPlayerScripts  →  LocalScript               ║
║  No external requires. Self-contained single file.              ║
╚══════════════════════════════════════════════════════════════════╝

FEATURES:
  • Import animations, emotes, animation packs
  • Extract animations from models and scripts
  • Full animation editor with timeline and keyframes
  • Floating emote buttons (draggable, lockable)
  • Dynamic playback speed scaling (velocity-based)
  • Save/load via DataStore
  • Accessory attachment and grouping system
  • Undo/redo (PC: Ctrl+Z/Y  Mobile: buttons)
  • R6 + R15 support
  • PC, Mobile, and Tablet optimized
]]

-- ════════════════════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════════════════════
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local InsertService     = game:GetService("InsertService")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── GUARD: must run as a LocalScript ──────────────────
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[AnimStudio] ERROR: This script must run as a LocalScript inside StarterPlayerScripts. Place it there and try again.")
    return
end

-- Wait for character system and camera to be ready
if not game:IsLoaded() then game.Loaded:Wait() end
local camera = workspace.CurrentCamera
if not camera then workspace:GetPropertyChangedSignal("CurrentCamera"):Wait(); camera = workspace.CurrentCamera end

-- ════════════════════════════════════════════════════════
--  MODULE: UIUtils
-- ════════════════════════════════════════════════════════
local UIUtils = (function()
    local M = {}

    M.Colors = {
        Background   = Color3.fromRGB(12,  12,  18),
        Surface      = Color3.fromRGB(20,  20,  30),
        SurfaceAlt   = Color3.fromRGB(26,  26,  40),
        Border       = Color3.fromRGB(40,  40,  60),
        BorderHover  = Color3.fromRGB(80,  80, 120),
        Accent       = Color3.fromRGB(99, 102, 241),
        AccentHover  = Color3.fromRGB(129, 132, 255),
        AccentDim    = Color3.fromRGB(60,  62, 150),
        Success      = Color3.fromRGB(34, 197,  94),
        Warning      = Color3.fromRGB(234, 179,   8),
        Danger       = Color3.fromRGB(239,  68,  68),
        TextPrimary  = Color3.fromRGB(240, 240, 255),
        TextSecondary= Color3.fromRGB(160, 160, 190),
        TextMuted    = Color3.fromRGB(90,  90, 120),
        Overlay      = Color3.fromRGB(0,    0,   0),
        Gold         = Color3.fromRGB(250, 204,  21),
        Highlight    = Color3.fromRGB(55,  55,  80),
    }

    M.Font = {
        Bold    = Enum.Font.GothamBold,
        Medium  = Enum.Font.GothamMedium,
        Regular = Enum.Font.Gotham,
        Mono    = Enum.Font.Code,
    }

    M.TweenInfo = {
        Fast      = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
        Normal    = TweenInfo.new(0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
        Smooth    = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        Spring    = TweenInfo.new(0.40, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
        Slow      = TweenInfo.new(0.60, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out),
        Cinematic = TweenInfo.new(0.80, Enum.EasingStyle.Expo,  Enum.EasingDirection.Out),
    }

    function M.Tween(inst, props, ti, cb)
        local t = TweenService:Create(inst, ti or M.TweenInfo.Normal, props)
        if cb then t.Completed:Once(cb) end
        t:Play(); return t
    end

    function M.FadeIn(frame, dur, cb)
        frame.BackgroundTransparency = 1
        frame.Visible = true
        M.Tween(frame, {BackgroundTransparency = 0}, TweenInfo.new(dur or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), cb)
    end

    function M.FadeOut(frame, dur, cb)
        M.Tween(frame, {BackgroundTransparency = 1}, TweenInfo.new(dur or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), function()
            frame.Visible = false; if cb then cb() end
        end)
    end

    function M.SlideIn(frame, dir, dist, dur)
        dir = dir or "Bottom"; dist = dist or 40; dur = dur or 0.30
        local orig = frame.Position
        local offsets = {
            Bottom = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale, orig.Y.Offset + dist),
            Top    = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale, orig.Y.Offset - dist),
            Left   = UDim2.new(orig.X.Scale, orig.X.Offset - dist, orig.Y.Scale, orig.Y.Offset),
            Right  = UDim2.new(orig.X.Scale, orig.X.Offset + dist, orig.Y.Scale, orig.Y.Offset),
        }
        frame.Position = offsets[dir]; frame.BackgroundTransparency = 1; frame.Visible = true
        M.Tween(frame, {Position = orig, BackgroundTransparency = 0}, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
    end

    function M.ScalePop(frame, cb)
        frame.Size = UDim2.new(0,0,0,0); frame.Visible = true
        M.Tween(frame, {Size = UDim2.new(1,0,1,0)}, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), cb)
    end

    function M.AddHoverEffect(btn, hoverColor, defaultColor)
        hoverColor   = hoverColor   or M.Colors.SurfaceAlt
        defaultColor = defaultColor or btn.BackgroundColor3
        btn.MouseEnter:Connect(function() M.Tween(btn, {BackgroundColor3 = hoverColor},   M.TweenInfo.Fast) end)
        btn.MouseLeave:Connect(function() M.Tween(btn, {BackgroundColor3 = defaultColor}, M.TweenInfo.Fast) end)
    end

    function M.AddPressEffect(btn)
        btn.MouseButton1Down:Connect(function()
            M.Tween(btn, {Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset, btn.Size.Y.Scale, btn.Size.Y.Offset-2)}, M.TweenInfo.Fast)
        end)
        btn.MouseButton1Up:Connect(function()
            M.Tween(btn, {Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset, btn.Size.Y.Scale, btn.Size.Y.Offset+2)}, M.TweenInfo.Fast)
        end)
    end

    function M.MakeFrame(p)
        local f = Instance.new("Frame")
        f.BackgroundColor3 = p.Color or M.Colors.Surface
        f.BorderSizePixel  = 0
        f.Size             = p.Size  or UDim2.new(1,0,1,0)
        f.Position         = p.Position or UDim2.new(0,0,0,0)
        f.Name             = p.Name  or "Frame"
        f.ClipsDescendants = p.ClipsDescendants or false
        if p.Transparency then f.BackgroundTransparency = p.Transparency end
        if p.ZIndex then f.ZIndex = p.ZIndex end
        if p.Parent then f.Parent = p.Parent end
        return f
    end

    function M.MakeCorner(r, parent)
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = parent; return c
    end

    function M.MakeStroke(parent, color, thick, trans)
        local s = Instance.new("UIStroke")
        s.Color = color or M.Colors.Border; s.Thickness = thick or 1; s.Transparency = trans or 0; s.Parent = parent; return s
    end

    function M.MakeLabel(p)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Text        = p.Text   or ""
        l.TextColor3  = p.Color  or M.Colors.TextPrimary
        l.Font        = p.Font   or M.Font.Regular
        l.TextSize    = p.Size2  or p.Size and 14 or 14
        l.Size        = p.Frame  or UDim2.new(1,0,0,20)
        l.Position    = p.Position or UDim2.new(0,0,0,0)
        l.TextXAlignment = p.XAlign or Enum.TextXAlignment.Left
        l.TextYAlignment = p.YAlign or Enum.TextYAlignment.Center
        l.TextWrapped = p.Wrap   or false
        l.Name        = p.Name   or "Label"
        if p.Parent then l.Parent = p.Parent end
        return l
    end

    function M.MakeButton(p)
        local b = Instance.new("TextButton")
        b.BackgroundColor3 = p.Color or M.Colors.Accent
        b.BorderSizePixel  = 0
        b.Text       = p.Text     or "Button"
        b.TextColor3 = p.TextColor or M.Colors.TextPrimary
        b.Font       = p.Font     or M.Font.Medium
        b.TextSize   = p.TextSize or 14
        b.Size       = p.Size     or UDim2.new(0,100,0,36)
        b.Position   = p.Position or UDim2.new(0,0,0,0)
        b.Name       = p.Name     or "Button"
        b.AutoButtonColor = false
        M.MakeCorner(p.Radius or 8, b)
        if p.Parent then b.Parent = p.Parent end
        M.AddHoverEffect(b, p.HoverColor or M.Colors.AccentHover, p.Color or M.Colors.Accent)
        M.AddPressEffect(b)
        return b
    end

    function M.MakeIconButton(p)
        local b = Instance.new("ImageButton")
        b.BackgroundColor3 = p.Color or M.Colors.SurfaceAlt
        b.BorderSizePixel  = 0
        b.Image            = p.Icon  or ""
        b.ImageColor3      = p.IconColor or M.Colors.TextPrimary
        b.Size             = p.Size  or UDim2.new(0,36,0,36)
        b.Position         = p.Position or UDim2.new(0,0,0,0)
        b.Name             = p.Name  or "IconButton"
        b.AutoButtonColor  = false
        M.MakeCorner(p.Radius or 8, b)
        if p.Parent then b.Parent = p.Parent end
        return b
    end

    function M.MakeDivider(parent, yPos)
        local d = Instance.new("Frame")
        d.BackgroundColor3 = M.Colors.Border; d.BorderSizePixel = 0
        d.Size = UDim2.new(1,-16,0,1); d.Position = UDim2.new(0,8,0,yPos or 0); d.Name = "Divider"; d.Parent = parent; return d
    end

    function M.MakeScrollFrame(p)
        local s = Instance.new("ScrollingFrame")
        s.BackgroundColor3     = p.Color or M.Colors.Surface
        s.BorderSizePixel      = 0
        s.ScrollBarThickness   = p.ScrollWidth or 4
        s.ScrollBarImageColor3 = M.Colors.Accent
        s.ScrollBarImageTransparency = 0.4
        s.CanvasSize           = p.CanvasSize or UDim2.new(0,0,0,0)
        s.AutomaticCanvasSize  = p.AutoCanvas or Enum.AutomaticSize.Y
        s.Size                 = p.Size or UDim2.new(1,0,1,0)
        s.Position             = p.Position or UDim2.new(0,0,0,0)
        s.Name                 = p.Name or "ScrollFrame"
        s.ElasticBehavior      = Enum.ElasticBehavior.Always
        s.ScrollingDirection   = p.Direction or Enum.ScrollingDirection.Y
        if p.Parent then s.Parent = p.Parent end
        return s
    end

    function M.MakeListLayout(parent, p)
        p = p or {}
        local l = Instance.new("UIListLayout")
        l.Padding             = p.Padding   or UDim.new(0,6)
        l.FillDirection       = p.Direction or Enum.FillDirection.Vertical
        l.HorizontalAlignment = p.HAlign    or Enum.HorizontalAlignment.Left
        l.VerticalAlignment   = p.VAlign    or Enum.VerticalAlignment.Top
        l.SortOrder           = Enum.SortOrder.LayoutOrder
        l.Parent              = parent; return l
    end

    function M.MakePadding(parent, p)
        p = p or {}
        local pad = Instance.new("UIPadding")
        pad.PaddingTop    = p.Top    or UDim.new(0,8)
        pad.PaddingBottom = p.Bottom or UDim.new(0,8)
        pad.PaddingLeft   = p.Left   or UDim.new(0,8)
        pad.PaddingRight  = p.Right  or UDim.new(0,8)
        pad.Parent        = parent; return pad
    end

    function M.MakeInput(p)
        local b = M.MakeFrame({Color=p.Color or M.Colors.SurfaceAlt, Size=p.Size or UDim2.new(1,0,0,36),
            Position=p.Position or UDim2.new(0,0,0,0), Name=p.Name or "InputFrame", Parent=p.Parent})
        M.MakeCorner(6, b); M.MakeStroke(b, M.Colors.Border, 1)
        local tb = Instance.new("TextBox")
        tb.BackgroundTransparency = 1; tb.Text = p.Default or ""
        tb.PlaceholderText = p.Placeholder or ""; tb.TextColor3 = M.Colors.TextPrimary
        tb.PlaceholderColor3 = M.Colors.TextMuted; tb.Font = M.Font.Regular
        tb.TextSize = p.TextSize or 14; tb.Size = UDim2.new(1,-12,1,0)
        tb.Position = UDim2.new(0,6,0,0); tb.ClearTextOnFocus = false; tb.Name = "Input"; tb.Parent = b
        tb.Focused:Connect(function()
            M.Tween(b, {BackgroundColor3=M.Colors.Highlight}, M.TweenInfo.Fast)
            for _, s in ipairs(b:GetChildren()) do
                if s:IsA("UIStroke") then M.Tween(s, {Color=M.Colors.Accent}, M.TweenInfo.Fast) end
            end
        end)
        tb.FocusLost:Connect(function()
            M.Tween(b, {BackgroundColor3=M.Colors.SurfaceAlt}, M.TweenInfo.Fast)
            for _, s in ipairs(b:GetChildren()) do
                if s:IsA("UIStroke") then M.Tween(s, {Color=M.Colors.Border}, M.TweenInfo.Fast) end
            end
        end)
        return b, tb
    end

    function M.MakeToggle(p)
        local track = M.MakeFrame({Size=p.Size or UDim2.new(0,44,0,24), Color=M.Colors.Border, Name=p.Name or "Toggle", Parent=p.Parent})
        M.MakeCorner(12, track)
        local thumb = M.MakeFrame({Color=M.Colors.TextPrimary, Size=UDim2.new(0,18,0,18), Position=UDim2.new(0,3,0.5,-9), Parent=track})
        M.MakeCorner(9, thumb)
        local state = false
        local button = Instance.new("TextButton"); button.Size = UDim2.new(1,0,1,0)
        button.BackgroundTransparency = 1; button.Text = ""; button.Name = "ToggleButton"; button.Parent = track
        button.MouseButton1Click:Connect(function()
            state = not state
            if state then
                M.Tween(track, {BackgroundColor3=M.Colors.Accent}, M.TweenInfo.Fast)
                M.Tween(thumb, {Position=UDim2.new(1,-21,0.5,-9)}, M.TweenInfo.Fast)
            else
                M.Tween(track, {BackgroundColor3=M.Colors.Border}, M.TweenInfo.Fast)
                M.Tween(thumb, {Position=UDim2.new(0,3,0.5,-9)}, M.TweenInfo.Fast)
            end
            if p.OnChange then p.OnChange(state) end
        end)
        return track, function() return state end
    end

    function M.Toast(parent, message, kind, duration)
        kind = kind or "info"; duration = duration or 3
        local colorMap = {info=M.Colors.Accent,success=M.Colors.Success,warning=M.Colors.Warning,error=M.Colors.Danger}
        local toast = M.MakeFrame({Name="Toast",Color=M.Colors.SurfaceAlt,
            Size=UDim2.new(0,280,0,48), Position=UDim2.new(0.5,-140,1,60), Parent=parent})
        toast.ZIndex = 100
        M.MakeCorner(8, toast); M.MakeStroke(toast, colorMap[kind] or M.Colors.Accent, 1.5)
        local accent = M.MakeFrame({Name="Accent",Color=colorMap[kind] or M.Colors.Accent,Size=UDim2.new(0,4,1,0),Parent=toast})
        M.MakeCorner(4, accent)
        local lbl = M.MakeLabel({Text=message,Size=UDim2.new(1,-18,1,0),Position=UDim2.new(0,12,0,0),Wrap=true,Color=M.Colors.TextPrimary,Font=M.Font.Medium,Parent=toast})
        lbl.TextSize = 13
        M.Tween(toast, {Position=UDim2.new(0.5,-140,1,-60)}, M.TweenInfo.Spring)
        task.delay(duration, function()
            M.Tween(toast, {Position=UDim2.new(0.5,-140,1,80)}, M.TweenInfo.Normal, function() toast:Destroy() end)
        end)
        return toast
    end

    function M.Confirm(parent, config, callback)
        local overlay = M.MakeFrame({Name="ModalOverlay",Color=M.Colors.Overlay,Transparency=0.5,Size=UDim2.new(1,0,1,0),Parent=parent})
        overlay.ZIndex = 200
        local card = M.MakeFrame({Name="ModalCard",Color=M.Colors.Surface,Size=UDim2.new(0,340,0,160),Position=UDim2.new(0.5,-170,0.5,-80),Parent=overlay})
        card.ZIndex = 201; M.MakeCorner(12, card); M.MakeStroke(card, M.Colors.Border, 1); M.ScalePop(card)
        local title = M.MakeLabel({Text=config.Title or "Confirm",Size=UDim2.new(1,-16,0,40),Position=UDim2.new(0,8,0,4),Font=M.Font.Bold,Parent=card})
        title.TextSize = 16
        local body = M.MakeLabel({Text=config.Body or "",Size=UDim2.new(1,-16,0,50),Position=UDim2.new(0,8,0,46),Wrap=true,Color=M.Colors.TextSecondary,Parent=card})
        body.TextSize = 13
        local btnRow = M.MakeFrame({Name="ButtonRow",Color=M.Colors.Surface,Transparency=1,Size=UDim2.new(1,-16,0,36),Position=UDim2.new(0,8,1,-44),Parent=card})
        M.MakeListLayout(btnRow, {Direction=Enum.FillDirection.Horizontal, HAlign=Enum.HorizontalAlignment.Right, Padding=UDim.new(0,6)})
        local kindColors = {primary=M.Colors.Accent, danger=M.Colors.Danger, ghost=M.Colors.SurfaceAlt}
        local function dismiss()
            M.Tween(overlay, {BackgroundTransparency=1}, M.TweenInfo.Normal, function() overlay:Destroy() end)
        end
        for _, btn in ipairs(config.Buttons or {{Text="OK",Kind="primary",Value=true}}) do
            local b = M.MakeButton({Text=btn.Text, Color=kindColors[btn.Kind] or M.Colors.Accent, Size=UDim2.new(0,90,0,34), Parent=btnRow})
            b.LayoutOrder = btn.Order or 0
            b.MouseButton1Click:Connect(function() dismiss(); if callback then callback(btn.Value) end end)
        end
        return overlay
    end

    function M.MakeDraggable(handle, target, snapToEdge)
        target = target or handle
        local dragging, dragStart, startPos = false, nil, nil
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = target.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                if snapToEdge and target.Parent then
                    local pSize = target.Parent.AbsoluteSize
                    local snapX = target.AbsolutePosition.X < pSize.X/2 and 10 or (pSize.X - target.AbsoluteSize.X - 10)
                    M.Tween(target, {Position=UDim2.new(0,snapX,0,target.AbsolutePosition.Y)}, M.TweenInfo.Spring)
                end
            end
        end)
    end

    function M.GetScale()
        local vp = workspace.CurrentCamera.ViewportSize
        local s  = math.min(vp.X, vp.Y)
        return s < 500 and 0.75 or s < 768 and 0.88 or 1
    end

    function M.IsTouch()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

    function M.IsMobile()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: AnimUtils
-- ════════════════════════════════════════════════════════
local AnimUtils = (function()
    local M = {}

    M.DefaultAnimIDs = {
        R15 = {Idle={"507766388"},Idle2={"507766388"},Walk={"507777826"},Run={"507767714"},
               Jump={"507765000"},Fall={"507767968"},Climb={"507765644"},Swim={"507784897"},Float={"507770239"},Sit={"2506281703"}},
        R6  = {Idle={"180435571"},Idle2={"180435571"},Walk={"180426354"},Run={"180426354"},
               Jump={"125750702"},Fall={"180436148"},Climb={"180436334"},Swim={"180436334"},Float={"180436148"},Sit={"178130996"}},
    }

    M.SlotOrder = {"Idle","Idle2","Walk","Run","Jump","Fall","Swim","Float","Climb","Sit"}

    M.SlotIcons = {Idle="rbxassetid://7072725342",Idle2="rbxassetid://7072725342",Walk="rbxassetid://7072726518",
        Run="rbxassetid://7072727112",Jump="rbxassetid://7072726094",Fall="rbxassetid://7072725571",
        Swim="rbxassetid://7072726820",Float="rbxassetid://7072725571",Climb="rbxassetid://7072724919",Sit="rbxassetid://7072726094"}

    M.RefWalkSpeed = 16

    function M.GetRigType(char)
        if not char then return "R15" end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.RigType == Enum.HumanoidRigType.R6 then return "R6" end
        return "R15"
    end

    function M.IsR6(char) return M.GetRigType(char) == "R6" end

    function M.GetMotor6Ds(char)
        local motors = {}
        if not char then return motors end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Motor6D") and d.Part1 then motors[d.Name] = d end
        end
        return motors
    end

    function M.IsValidAssetID(id)
        if type(id) ~= "string" then id = tostring(id) end
        id = id:gsub("rbxassetid://",""):match("^%d+$")
        return id ~= nil
    end

    function M.NormalizeID(id)
        if type(id) ~= "string" then id = tostring(id) end
        return id:gsub("rbxassetid://",""):match("%d+") or ""
    end

    function M.BuildAssetURL(id) return "rbxassetid://" .. M.NormalizeID(id) end

    function M.LoadAnimation(humanoid, id)
        if not humanoid then return nil end
        local cleanID = M.NormalizeID(id)
        if cleanID == "" then return nil end
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. cleanID
        local ok, track = pcall(function() return humanoid.Animator:LoadAnimation(anim) end)
        anim:Destroy()
        return ok and track or nil
    end

    function M.PlayAnimation(humanoid, id, priority, looped, speed)
        local track = M.LoadAnimation(humanoid, id)
        if not track then return nil end
        track.Priority = priority or Enum.AnimationPriority.Action
        track.Looped   = looped ~= false
        if speed then track:AdjustSpeed(speed) end
        track:Play(); return track
    end

    function M.StopAll(humanoid, fade)
        if not humanoid then return end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return end
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(fade or 0.2) end
    end

    function M.CalcPlaybackSpeed(currentSpeed, refSpeed)
        refSpeed = refSpeed or M.RefWalkSpeed
        return refSpeed == 0 and 1 or math.clamp(currentSpeed/refSpeed, 0.1, 5.0)
    end

    function M.CFrameToEuler(cf)
        local rx,ry,rz = cf:ToEulerAnglesXYZ()
        return Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
    end

    function M.ExtractIDsFromScript(src)
        local ids = {}
        for id in src:gmatch("rbxassetid://(%d+)") do ids[id] = true end
        for id in src:gmatch('[Aa]nimation[Ii]d%s*=%s*"(%d+)"') do ids[id] = true end
        for id in src:gmatch('"(%d%d%d%d%d%d%d+)"') do ids[id] = true end
        local result = {}; for id in pairs(ids) do table.insert(result, id) end; return result
    end

    function M.ScanForAnimations(root)
        local found = {AnimationObjects={}, Scripts={}, AnimationTracks={}}
        if not root then return found end
        for _, desc in ipairs(root:GetDescendants()) do
            if desc:IsA("Animation") then
                table.insert(found.AnimationObjects, {instance=desc, id=M.NormalizeID(desc.AnimationId), name=desc.Name})
            elseif desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
                local ok, src = pcall(function() return desc.Source end)
                if ok and src then
                    local ids = M.ExtractIDsFromScript(src)
                    if #ids > 0 then table.insert(found.Scripts, {instance=desc, ids=ids, name=desc.Name}) end
                end
            end
        end
        return found
    end

    function M.MakePack(name, slots)
        return {name=name, slots=slots or {}, emotes={}, created=os.time(), modified=os.time()}
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: AssetUtils
-- ════════════════════════════════════════════════════════
local AssetUtils = (function()
    local M = {}

    function M.GetAnimThumbnail(animId)
        return "rbxthumb://type=Asset&id=" .. tostring(animId):match("%d+") .. "&w=420&h=420"
    end

    function M.GetThumbnailURL(assetId)
        return "rbxthumb://type=Asset&id=" .. tostring(assetId):match("%d+") .. "&w=420&h=420"
    end

    function M.LoadModel(assetId)
        local cleanId = tostring(assetId):match("%d+")
        if not cleanId then return nil, "Invalid ID" end
        local ok, model = pcall(function() return InsertService:LoadAsset(tonumber(cleanId)) end)
        return ok and model or nil, ok and nil or tostring(model)
    end

    function M.CloneCharacter(character, parent)
        if not character then return nil end
        local clone = character:Clone()
        for _, desc in ipairs(clone:GetDescendants()) do
            if desc:IsA("Script") or desc:IsA("LocalScript") then desc.Enabled = false end
        end
        local root = clone:FindFirstChild("HumanoidRootPart")
        if root then root.Anchored = true end
        clone.Parent = parent; return clone
    end

    function M.ParseLink(link)
        if not link then return nil end
        return link:match("rbxassetid://(%d+)") or
               link:match("roblox%.com/library/(%d+)") or
               link:match("roblox%.com/catalog/(%d+)") or
               link:match("^(%d+)$")
    end

    M.RobloxEmotes = {
        {name="Wave",       id="507770239", tags={"wave","greeting"}},
        {name="Point",      id="507770453", tags={"point"}},
        {name="Dance",      id="507771019", tags={"dance"}},
        {name="Dance 2",    id="507776043", tags={"dance"}},
        {name="Dance 3",    id="507777268", tags={"dance"}},
        {name="Laugh",      id="507770818", tags={"laugh","funny"}},
        {name="Cheer",      id="507770677", tags={"cheer","celebrate"}},
        {name="Salute",     id="3360689775",tags={"salute"}},
        {name="Hello",      id="3579537881",tags={"hello","greeting"}},
        {name="Agree",      id="4935478808",tags={"agree","yes"}},
        {name="Disagree",   id="4935469342",tags={"disagree","no"}},
        {name="Shocked",    id="4935471468",tags={"shocked","surprised"}},
        {name="Sleep",      id="6881660712",tags={"sleep","idle"}},
        {name="HeadBob",    id="7715583166",tags={"dance","music"}},
        {name="Ninja Run",  id="656118852", tags={"run","ninja"}},
        {name="Superhero",  id="616163682", tags={"superhero"}},
        {name="Robot",      id="608936119", tags={"robot","dance"}},
        {name="Zombie",     id="616006778", tags={"zombie"}},
        {name="Astronaut",  id="616035778", tags={"astronaut","space"}},
        {name="Snowball",   id="616074909", tags={"snowball","throw"}},
        {name="Tilt",       id="3360692915",tags={"tilt"}},
        {name="Stadium",    id="3360686498",tags={"stadium","celebrate"}},
    }

    function M.SearchEmotes(query, list)
        query = query:lower(); local results = {}
        for _, e in ipairs(list or M.RobloxEmotes) do
            local hit = e.name:lower():find(query,1,true) or e.id:find(query,1,true)
            if not hit then
                for _, t in ipairs(e.tags or {}) do if t:find(query,1,true) then hit=true break end end
            end
            if hit then table.insert(results, e) end
        end
        return results
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: UndoRedo
-- ════════════════════════════════════════════════════════
local UndoRedo = (function()
    local M = {}; M.__index = M
    M.ActionType = {MOVE="Move",ROTATE="Rotate",KF_ADD="KeyframeAdd",KF_DELETE="KeyframeDelete",
        KF_MODIFY="KeyframeModify",ATTACH="Attach",GROUP="Group",ANIM_SET="AnimationSet",CUSTOM="Custom"}
    local MAX_HISTORY = 100

    function M.new()
        return setmetatable({_undoStack={},_redoStack={},_onChange=nil}, M)
    end

    function M:OnChange(fn) self._onChange = fn end
    function M:_notify() if self._onChange then self._onChange(#self._undoStack,#self._redoStack) end end

    function M:Push(action)
        table.insert(self._undoStack, action)
        while #self._undoStack > MAX_HISTORY do table.remove(self._undoStack,1) end
        self._redoStack = {}; self:_notify()
    end

    function M:Undo()
        local a = table.remove(self._undoStack); if not a then return false end
        a.revert(); table.insert(self._redoStack, a); self:_notify(); return a.label or a.type
    end

    function M:Redo()
        local a = table.remove(self._redoStack); if not a then return false end
        a.apply(); table.insert(self._undoStack, a); self:_notify(); return a.label or a.type
    end

    function M:PushMotorChange(motor, oldC0, newC0, label)
        self:Push({type=M.ActionType.MOVE, label=label or ("Move "..motor.Name),
            apply=function() motor.C0=newC0 end, revert=function() motor.C0=oldC0 end})
    end

    function M:PushCustom(label, applyFn, revertFn)
        self:Push({type=M.ActionType.CUSTOM, label=label, apply=applyFn, revert=revertFn})
    end

    function M:PushAttach(accessory, oldParent, newParent, oldCF, newCF)
        self:Push({type=M.ActionType.ATTACH, label="Attach "..accessory.Name,
            apply=function() accessory.Parent=newParent; if accessory:FindFirstChild("Handle") and newCF then accessory.Handle.CFrame=newCF end end,
            revert=function() accessory.Parent=oldParent; if accessory:FindFirstChild("Handle") and oldCF then accessory.Handle.CFrame=oldCF end end})
    end

    function M:CanUndo() return #self._undoStack > 0 end
    function M:CanRedo() return #self._redoStack > 0 end
    function M:UndoLabel() local a=self._undoStack[#self._undoStack]; return a and (a.label or a.type) end
    function M:RedoLabel() local a=self._redoStack[#self._redoStack]; return a and (a.label or a.type) end
    function M:Clear() self._undoStack={}; self._redoStack={}; self:_notify() end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: InputHandler
-- ════════════════════════════════════════════════════════
local InputHandler = (function()
    local M = {}
    local _bindings, _connections, _justFired = {}, {}, {}

    function M.IsTouch()    return UserInputService.TouchEnabled end
    function M.IsMobile()   return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled end
    function M.IsPC()       return UserInputService.KeyboardEnabled end

    function M.BindKey(id, keys, callback)
        _bindings[id] = {keys=keys, callback=callback}
    end

    function M.UnbindKey(id) _bindings[id] = nil end

    local function keysMatch(keys)
        for i = 1, #keys-1 do if not UserInputService:IsKeyDown(keys[i]) then return false end end
        return UserInputService:IsKeyDown(keys[#keys])
    end

    function M.SetupEditorShortcuts(cbs)
        local ctrl = Enum.KeyCode.LeftControl
        local shift = Enum.KeyCode.LeftShift
        M.BindKey("Undo",      {ctrl, Enum.KeyCode.Z},        cbs.Undo)
        M.BindKey("Redo",      {ctrl, Enum.KeyCode.Y},        cbs.Redo)
        M.BindKey("RedoAlt",   {ctrl, shift, Enum.KeyCode.Z}, cbs.Redo)
        M.BindKey("Save",      {ctrl, Enum.KeyCode.S},        cbs.Save)
        M.BindKey("Delete",    {Enum.KeyCode.Delete},          cbs.Delete)
        M.BindKey("Duplicate", {ctrl, Enum.KeyCode.D},        cbs.Duplicate or function()end)
        M.BindKey("Escape",    {Enum.KeyCode.Escape},          cbs.Escape)
        M.BindKey("ToolQ",     {Enum.KeyCode.Q},               cbs.ToolSelect or function()end)
        M.BindKey("ToolW",     {Enum.KeyCode.W},               cbs.ToolMove   or function()end)
        M.BindKey("ToolE",     {Enum.KeyCode.E},               cbs.ToolRotate or function()end)
        M.BindKey("Play",      {Enum.KeyCode.Space},            cbs.Play       or function()end)
    end

    local function onInputBegan(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            for id, binding in pairs(_bindings) do
                if not _justFired[id] and keysMatch(binding.keys) then
                    _justFired[id] = true; binding.callback()
                end
            end
        end
    end

    local function onInputEnded(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            for id, binding in pairs(_bindings) do
                if input.KeyCode == binding.keys[#binding.keys] then _justFired[id] = nil end
            end
        end
    end

    function M.Start()
        table.insert(_connections, UserInputService.InputBegan:Connect(onInputBegan))
        table.insert(_connections, UserInputService.InputEnded:Connect(onInputEnded))
    end

    function M.Stop()
        for _, c in ipairs(_connections) do c:Disconnect() end
        _connections = {}; _bindings = {}; _justFired = {}
    end

    function M.MakeDraggable(handle, target, onEnd)
        target = target or handle
        local dragging, dragStart, startPos = false, nil, nil
        local conns = {}
        table.insert(conns, handle.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging=true; dragStart=inp.Position; startPos=target.Position end
        end))
        table.insert(conns, UserInputService.InputChanged:Connect(function(inp)
            if not dragging then return end
            if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                local d = inp.Position - dragStart
                target.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
            end
        end))
        table.insert(conns, UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging=false; if onEnd then onEnd(target.Position) end
            end
        end))
        return function() for _,c in ipairs(conns) do c:Disconnect() end end
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: SaveLoad  (client-side only in LocalScript)
-- ════════════════════════════════════════════════════════
local SaveLoad = (function()
    local M = {}
    local _cache, _dirty = {}, {}
    local AUTO_SAVE_INTERVAL = 60
    local _remotes = nil

    M.Keys = {AnimSlots="AnimStudio_Slots_v1",Packs="AnimStudio_Packs_v1",Folders="AnimStudio_Folders_v1",
              Favorites="AnimStudio_Favorites_v1",FloatEmotes="AnimStudio_Float_v1",
              UIState="AnimStudio_UIState_v1",Timeline="AnimStudio_Timeline_v1"}

    local function GetRemotes()
        if _remotes then return _remotes end
        _remotes = ReplicatedStorage:FindFirstChild("AnimStudioRemotes")
        return _remotes
    end

    function M.Init()
        local remotes = GetRemotes()
        if not remotes then return false end
        local loadAll = remotes:FindFirstChild("LoadAll")
        if loadAll then
            local ok, data = pcall(function() return loadAll:InvokeServer() end)
            if ok and data then for key, blob in pairs(data) do _cache[key] = blob end end
        end
        M.StartClientAutoSave(); return true
    end

    function M.Get(key)   return _cache[key] end
    function M.Set(key,v) _cache[key]=v; _dirty[key]=true end

    function M.Flush()
        local remotes = GetRemotes(); if not remotes then return end
        local saveRemote = remotes:FindFirstChild("AutoSave")
        if saveRemote and next(_dirty) then
            local payload = {}
            for key in pairs(_dirty) do payload[key] = _cache[key] end
            pcall(function() saveRemote:FireServer(payload) end)
            _dirty = {}
        end
    end

    function M.StartClientAutoSave()
        task.spawn(function()
            while true do task.wait(AUTO_SAVE_INTERVAL); M.Flush() end
        end)
    end

    function M.DefaultSlots()
        return {Idle=nil,Idle2=nil,Walk=nil,Run=nil,Jump=nil,Fall=nil,Swim=nil,Float=nil,Climb=nil,Sit=nil}
    end
    function M.DefaultUIState()
        return {toggleBtnPos={x=0,y=300}, activeTab="Home", playbackMode="Dynamic"}
    end
    function M.DefaultFloatEmotes() return {} end
    function M.DefaultFavorites()   return {} end

    function M.EnsureDefaults()
        if not _cache.AnimSlots   then _cache.AnimSlots   = M.DefaultSlots()      end
        if not _cache.FloatEmotes then _cache.FloatEmotes = M.DefaultFloatEmotes() end
        if not _cache.UIState     then _cache.UIState     = M.DefaultUIState()    end
        if not _cache.Favorites   then _cache.Favorites   = M.DefaultFavorites()  end
        if not _cache.Packs       then _cache.Packs       = {}                     end
        if not _cache.Folders     then _cache.Folders     = {}                     end
        if not _cache.Timeline    then _cache.Timeline    = {}                     end
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: AnimationManager
-- ════════════════════════════════════════════════════════
local AnimationManager = (function()
    local M = {}; M.__index = M

    function M.new(character)
        local self = setmetatable({}, M)
        self._character   = character
        self._humanoid    = character and character:FindFirstChildOfClass("Humanoid")
        self._rigType     = AnimUtils.GetRigType(character)
        self._slots       = {}
        self._activeTracks= {}
        self._connections = {}
        self._onChange    = nil
        return self
    end

    function M:BindCharacter(char)
        self:StopAll()
        self._character = char
        self._humanoid  = char and char:FindFirstChildOfClass("Humanoid")
        self._rigType   = AnimUtils.GetRigType(char)
    end

    function M:SetSlot(slotName, data)
        self._slots[slotName] = {id=data.id or "",source=data.source or "Custom",
            name=data.name or slotName,description=data.description or "",modified=true}
        if self._onChange then self._onChange(slotName, self._slots[slotName]) end
    end

    function M:GetSlot(slotName) return self._slots[slotName] end

    function M:ClearSlot(slotName)
        self:StopSlot(slotName); self._slots[slotName] = nil
        if self._onChange then self._onChange(slotName, nil) end
    end

    function M:GetAllSlots() return self._slots end
    function M:OnChange(fn)  self._onChange = fn end
    function M:IsUsingDefault(slotName) local s=self._slots[slotName]; return not s or not s.id or s.id=="" end

    function M:PlaySlot(slotName, priority, looped, speed, fadeTime)
        local slot = self._slots[slotName]
        local id   = slot and slot.id
        if not id or id == "" then
            local defs = AnimUtils.DefaultAnimIDs[self._rigType]
            local list = defs and defs[slotName]
            if list and list[1] then id = list[1] end
        end
        if not id or id == "" then return nil end
        self:StopSlot(slotName, fadeTime)
        local track = AnimUtils.LoadAnimation(self._humanoid, id)
        if not track then return nil end
        track.Priority = priority or Enum.AnimationPriority.Action
        track.Looped   = looped ~= false
        if speed then track:AdjustSpeed(speed) end
        track:Play(fadeTime or 0.1)
        self._activeTracks[slotName] = track; return track
    end

    function M:StopSlot(slotName, fadeTime)
        local track = self._activeTracks[slotName]
        if track and track.IsPlaying then track:Stop(fadeTime or 0.2) end
        self._activeTracks[slotName] = nil
    end

    function M:StopAll(fadeTime)
        for slotName in pairs(self._activeTracks) do self:StopSlot(slotName, fadeTime) end
    end

    function M:ApplyPack(pack)
        if not pack or not pack.slots then return end
        for slotName, id in pairs(pack.slots) do
            self:SetSlot(slotName,{id=id,source="Pack",name=pack.name.."/"..slotName})
        end
    end

    function M:Preview(slotName, onEnd)
        local track = self:PlaySlot(slotName, Enum.AnimationPriority.Action4, false, 1)
        if track then track.Stopped:Once(function() if onEnd then onEnd() end end) end
        return track
    end

    function M:SetSpeed(slotName, speed)
        local t = self._activeTracks[slotName]; if t then t:AdjustSpeed(speed) end
    end

    function M:SetAllSpeeds(speed)
        for _, t in pairs(self._activeTracks) do if t.IsPlaying then t:AdjustSpeed(speed) end end
    end

    function M:SerializeSlots()
        local out = {}
        for name, data in pairs(self._slots) do
            out[name] = {id=data.id,source=data.source,name=data.name,description=data.description}
        end
        return out
    end

    function M:DeserializeSlots(data)
        if not data then return end
        for name, slot in pairs(data) do self._slots[name] = slot end
    end

    function M:Destroy()
        self:StopAll()
        for _, c in ipairs(self._connections) do c:Disconnect() end
        self._connections = {}
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: PlaybackSystem
-- ════════════════════════════════════════════════════════
local PlaybackSystem = (function()
    local M = {}; M.__index = M
    local LOCOMOTION_SLOTS = {"Walk","Run","Swim","Climb","Float"}
    local SMOOTHING = 0.15

    function M.new(animManager)
        return setmetatable({_animManager=animManager,_mode="Dynamic",_staticSpeed=1.0,
            _multiplier=1.0,_currentSpeed=1.0,_targetSpeed=1.0,_connection=nil,
            _enabled=false,_refSpeed=AnimUtils.RefWalkSpeed,_onSpeedChange=nil}, M)
    end

    function M:SetMode(mode)
        self._mode = mode
        if mode == "Static" then self:_applySpeed(self._staticSpeed*self._multiplier) end
    end
    function M:GetMode()         return self._mode end
    function M:SetStaticSpeed(s) self._staticSpeed=math.clamp(s,0.1,10); if self._mode=="Static" then self:_applySpeed(self._staticSpeed*self._multiplier) end end
    function M:SetMultiplier(m)  self._multiplier=math.clamp(m,0.1,10) end
    function M:SetRefSpeed(s)    self._refSpeed=s>0 and s or AnimUtils.RefWalkSpeed end
    function M:OnSpeedChange(fn) self._onSpeedChange=fn end

    function M:_applySpeed(speed)
        speed = math.clamp(speed,0.05,10)
        local am = self._animManager; if not am then return end
        for _, slot in ipairs(LOCOMOTION_SLOTS) do am:SetSpeed(slot, speed) end
        if self._onSpeedChange then self._onSpeedChange(speed) end
    end

    function M:Start()
        if self._connection then return end
        self._enabled = true
        self._connection = RunService.Heartbeat:Connect(function()
            if not self._enabled or self._mode ~= "Dynamic" then return end
            local char = self._animManager and self._animManager._character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not hum or not root then return end
            local vel   = root.AssemblyLinearVelocity
            local speed = Vector2.new(vel.X,vel.Z).Magnitude
            if hum:GetState() == Enum.HumanoidStateType.Swimming then speed = vel.Magnitude end
            self._targetSpeed  = speed > 0.5 and AnimUtils.CalcPlaybackSpeed(speed,self._refSpeed)*self._multiplier or 0
            self._currentSpeed = self._currentSpeed + (self._targetSpeed - self._currentSpeed)*SMOOTHING
            self:_applySpeed(self._currentSpeed)
        end)
    end

    function M:Stop()
        self._enabled = false
        if self._connection then self._connection:Disconnect(); self._connection=nil end
        self:_applySpeed(1)
    end

    function M:Serialize()
        return {mode=self._mode,staticSpeed=self._staticSpeed,multiplier=self._multiplier,refSpeed=self._refSpeed}
    end

    function M:Deserialize(d)
        if not d then return end
        self._mode=d.mode or "Dynamic"; self._staticSpeed=d.staticSpeed or 1.0
        self._multiplier=d.multiplier or 1.0; self._refSpeed=d.refSpeed or AnimUtils.RefWalkSpeed
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: ToggleButton
-- ════════════════════════════════════════════════════════
local ToggleButton = (function()
    local M = {}; M.__index = M

    function M.new(screenGui, onToggle)
        local self = setmetatable({_gui=screenGui,_onToggle=onToggle,_open=false,_hidden=false}, M)
        self:_build(); return self
    end

    function M:_build()
        local btn = UIUtils.MakeFrame({Name="ToggleButton",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,52,0,52),Position=UDim2.new(0.88,0,0.42,0),Parent=self._gui})
        btn.AnchorPoint = Vector2.new(0.5,0.5)
        UIUtils.MakeCorner(16, btn)

        local icon = Instance.new("ImageLabel")
        icon.Size=UDim2.new(0,26,0,26); icon.Position=UDim2.new(0.5,-13,0.5,-13)
        icon.BackgroundTransparency=1; icon.Image="rbxassetid://7072725342"
        icon.ImageColor3=Color3.new(1,1,1); icon.Parent=btn

        local dot = UIUtils.MakeFrame({Name="NotifDot",Color=UIUtils.Colors.Danger,Size=UDim2.new(0,10,0,10),Position=UDim2.new(1,-8,0,-2),Parent=btn})
        dot.Visible=false; UIUtils.MakeCorner(5,dot)

        local clickBtn = Instance.new("TextButton"); clickBtn.Name="ClickCapture"
        clickBtn.Size=UDim2.new(1,0,1,0); clickBtn.BackgroundTransparency=1; clickBtn.Text=""
        clickBtn.ZIndex=10; clickBtn.Parent=btn

        self._btn=btn; self._dot=dot; self._icon=icon

        local dragging,hasMoved,dragStart,startPos = false,false,nil,nil
        clickBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                dragging=true; hasMoved=false; dragStart=inp.Position; startPos=btn.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if not dragging then return end
            if inp.UserInputType~=Enum.UserInputType.MouseMovement and inp.UserInputType~=Enum.UserInputType.Touch then return end
            local d = inp.Position - dragStart
            if d.Magnitude > 6 then hasMoved=true end
            btn.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if not dragging then return end
            if inp.UserInputType~=Enum.UserInputType.MouseButton1 and inp.UserInputType~=Enum.UserInputType.Touch then return end
            dragging=false
            if hasMoved then self:_snap() else self:_toggle() end
        end)
        clickBtn.MouseEnter:Connect(function() UIUtils.Tween(btn,{BackgroundColor3=UIUtils.Colors.AccentHover,Size=UDim2.new(0,56,0,56)},UIUtils.TweenInfo.Fast) end)
        clickBtn.MouseLeave:Connect(function() UIUtils.Tween(btn,{BackgroundColor3=UIUtils.Colors.Accent,Size=UDim2.new(0,52,0,52)},UIUtils.TweenInfo.Fast) end)
    end

    function M:_toggle()
        self._open = not self._open
        UIUtils.Tween(self._icon, {Rotation=self._open and 90 or 0}, UIUtils.TweenInfo.Spring)
        UIUtils.Tween(self._btn, {BackgroundColor3=self._open and UIUtils.Colors.AccentDim or UIUtils.Colors.Accent}, UIUtils.TweenInfo.Normal)
        if self._onToggle then self._onToggle(self._open) end
    end

    function M:_snap()
        local pSize = self._gui.AbsoluteSize; local bSize = self._btn.AbsoluteSize
        local absX  = self._btn.AbsolutePosition.X; local absY = self._btn.AbsolutePosition.Y
        local clampY = math.clamp(absY, pSize.Y*0.10, pSize.Y*0.80)
        local snapX  = absX < pSize.X/2 and 14 or (pSize.X - bSize.X - 14)
        UIUtils.Tween(self._btn, {Position=UDim2.new(0,snapX,0,clampY)}, UIUtils.TweenInfo.Spring)
    end

    function M:HideForEditor()
        if self._hidden then return end; self._hidden=true
        UIUtils.Tween(self._btn,{BackgroundTransparency=1,Size=UDim2.new(0,0,0,0)},UIUtils.TweenInfo.Normal,function() self._btn.Visible=false end)
    end

    function M:ShowFromEditor()
        if not self._hidden then return end; self._hidden=false; self._btn.Visible=true; self._btn.Size=UDim2.new(0,0,0,0)
        UIUtils.Tween(self._btn,{BackgroundTransparency=0,Size=UDim2.new(0,52,0,52)},UIUtils.TweenInfo.Spring)
    end

    function M:SetUnsaved(v) self._dot.Visible = v == true end

    function M:GetPosition() return {x=self._btn.Position.X.Offset,y=self._btn.Position.Y.Offset} end
    function M:SetPosition(pos) if pos then self._btn.Position=UDim2.new(0,pos.x or 0,0,pos.y or 300) end end
    function M:SetOpen(state) if self._open~=state then self:_toggle() end end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: FloatingEmoteSystem
-- ════════════════════════════════════════════════════════
local FloatingEmoteSystem = (function()
    local M = {}; M.__index = M
    local DEFAULT_SIZE = 52

    function M.new(screenGui, context)
        local self = setmetatable({_gui=screenGui,_ctx=context,_buttons={},_panel=nil,_panelOpen=false}, M)
        self:_buildPanel(); return self
    end

    function M:_buildPanel()
        local panel = UIUtils.MakeFrame({Name="FloatPanel",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,220,0,260),Position=UDim2.new(0.5,-110,0.5,-130),Parent=self._gui})
        panel.Visible=false; panel.ZIndex=80
        UIUtils.MakeCorner(12,panel); UIUtils.MakeStroke(panel,UIUtils.Colors.Border,1)
        self._panel = panel

        local titleBar = UIUtils.MakeFrame({Name="TitleBar",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,36),Parent=panel})
        UIUtils.MakeCorner(12,titleBar)
        local tLbl = UIUtils.MakeLabel({Text="Floating Emotes",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,-40,1,0),Position=UDim2.new(0,10,0,0),Parent=titleBar})
        tLbl.TextSize=14
        local closeBtn = UIUtils.MakeIconButton({Icon="rbxassetid://7072705748",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,28,0,28),Position=UDim2.new(1,-34,0.5,-14),Parent=titleBar})
        closeBtn.MouseButton1Click:Connect(function() self:TogglePanel() end)
        UIUtils.MakeDraggable(titleBar, panel)

        local scroll = UIUtils.MakeScrollFrame({Name="FloatList",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,1,-36),Position=UDim2.new(0,0,0,36),AutoCanvas=Enum.AutomaticSize.Y,Parent=panel})
        UIUtils.MakePadding(scroll,{Top=UDim.new(0,4),Left=UDim.new(0,6),Right=UDim.new(0,6),Bottom=UDim.new(0,4)})
        UIUtils.MakeListLayout(scroll,{Padding=UDim.new(0,4)})
        self._panelScroll=scroll

        local emptyLbl = UIUtils.MakeLabel({Text='Float emotes from the Emotes tab.',Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,40),Wrap=true,XAlign=Enum.TextXAlignment.Center,Parent=scroll})
        emptyLbl.TextSize=11; self._emptyLbl=emptyLbl
    end

    function M:TogglePanel()
        self._panelOpen = not self._panelOpen
        if self._panelOpen then self._panel.Visible=true; UIUtils.ScalePop(self._panel)
        else UIUtils.FadeOut(self._panel, 0.18) end
    end

    function M:AddFloatEmote(emote)
        if self._buttons[emote.id] then return end
        local count = 0; for _ in pairs(self._buttons) do count=count+1 end
        local pos = UDim2.new(1, -70-(count%3)*58, 0, 80+math.floor(count/3)*62)

        local btnFrame = UIUtils.MakeFrame({Name="FloatBtn_"..emote.id,Color=UIUtils.Colors.AccentDim,Size=UDim2.new(0,DEFAULT_SIZE,0,DEFAULT_SIZE),Position=pos,Parent=self._gui})
        btnFrame.ZIndex=70; UIUtils.MakeCorner(14,btnFrame); UIUtils.MakeStroke(btnFrame,UIUtils.Colors.Accent,1.5)

        local thumb = Instance.new("ImageLabel"); thumb.Size=UDim2.new(1,-8,1,-18); thumb.Position=UDim2.new(0,4,0,4)
        thumb.BackgroundTransparency=1; thumb.Image="rbxassetid://"..emote.id; thumb.ScaleType=Enum.ScaleType.Fit; thumb.Parent=btnFrame

        local nameLbl = UIUtils.MakeLabel({Text=emote.name,Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,0,0,14),Position=UDim2.new(0,0,1,-14),XAlign=Enum.TextXAlignment.Center,Parent=btnFrame})
        nameLbl.TextSize=8; nameLbl.TextTruncate=Enum.TextTruncate.AtEnd

        local playBtn = Instance.new("TextButton"); playBtn.Size=UDim2.new(1,0,1,0)
        playBtn.BackgroundTransparency=1; playBtn.Text=""; playBtn.ZIndex=71; playBtn.Parent=btnFrame

        local optBtn = Instance.new("TextButton"); optBtn.Size=UDim2.new(0,18,0,18)
        optBtn.Position=UDim2.new(1,-20,0,2); optBtn.BackgroundColor3=UIUtils.Colors.Surface
        optBtn.BackgroundTransparency=0.4; optBtn.BorderSizePixel=0; optBtn.Text="⋮"
        optBtn.TextColor3=UIUtils.Colors.TextPrimary; optBtn.TextSize=11; optBtn.Font=UIUtils.Font.Bold
        optBtn.ZIndex=72; UIUtils.MakeCorner(4,optBtn); optBtn.Parent=btnFrame

        local state = {emote=emote,frame=btnFrame,locked=false,size=DEFAULT_SIZE}
        self._buttons[emote.id] = state

        local dragging,hasMoved,dragStart,startPos = false,false,nil,nil
        playBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                if not state.locked then dragging=true; hasMoved=false; dragStart=inp.Position; startPos=btnFrame.Position end
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if not dragging then return end
            if inp.UserInputType~=Enum.UserInputType.MouseMovement and inp.UserInputType~=Enum.UserInputType.Touch then return end
            local d = inp.Position - dragStart; if d.Magnitude>6 then hasMoved=true end
            btnFrame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                dragging=false; if not hasMoved then self:_playEmote(emote) end
            end
        end)

        playBtn.MouseEnter:Connect(function() UIUtils.Tween(btnFrame,{Size=UDim2.new(0,state.size+6,0,state.size+6)},UIUtils.TweenInfo.Fast) end)
        playBtn.MouseLeave:Connect(function() UIUtils.Tween(btnFrame,{Size=UDim2.new(0,state.size,0,state.size)},UIUtils.TweenInfo.Fast) end)

        optBtn.MouseButton1Click:Connect(function()
            self:_showFloatOptions(state, optBtn)
        end)

        self:_addPanelEntry(emote, state)
        self:_updateEmpty()
    end

    function M:_addPanelEntry(emote, state)
        local row = UIUtils.MakeFrame({Name="PR_"..emote.id,Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,36),Parent=self._panelScroll})
        UIUtils.MakeCorner(6,row)
        local lbl=UIUtils.MakeLabel({Text=emote.name,Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,-66,1,0),Position=UDim2.new(0,8,0,0),Parent=row})
        lbl.TextSize=12
        local lockBtn=UIUtils.MakeButton({Text="🔒",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,26,0,26),Position=UDim2.new(1,-60,0.5,-13),Parent=row})
        lockBtn.TextSize=12
        lockBtn.MouseButton1Click:Connect(function()
            state.locked=not state.locked
            lockBtn.BackgroundColor3=state.locked and UIUtils.Colors.AccentDim or UIUtils.Colors.Surface
        end)
        local delBtn=UIUtils.MakeButton({Text="✕",Color=UIUtils.Colors.Danger,Size=UDim2.new(0,26,0,26),Position=UDim2.new(1,-30,0.5,-13),Parent=row})
        delBtn.TextSize=12
        delBtn.MouseButton1Click:Connect(function()
            self:RemoveFloatEmote(emote.id); row:Destroy(); self:_updateEmpty()
        end)
    end

    function M:_updateEmpty() self._emptyLbl.Visible = next(self._buttons)==nil end

    function M:_showFloatOptions(state, anchor)
        for _, c in ipairs(self._gui:GetChildren()) do if c.Name=="FloatOptMenu" then c:Destroy() end end
        local absPos = anchor.AbsolutePosition
        local menu = UIUtils.MakeFrame({Name="FloatOptMenu",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,150,0,140),Position=UDim2.new(0,absPos.X+22,0,absPos.Y),Parent=self._gui})
        menu.ZIndex=90; UIUtils.MakeCorner(8,menu); UIUtils.MakeStroke(menu,UIUtils.Colors.Border,1)
        UIUtils.MakeListLayout(menu,{Padding=UDim.new(0,2)}); UIUtils.MakePadding(menu,{Top=UDim.new(0,4),Bottom=UDim.new(0,4),Left=UDim.new(0,4),Right=UDim.new(0,4)})
        UIUtils.SlideIn(menu,"Left",10,0.14)
        local blocker=Instance.new("TextButton"); blocker.Size=UDim2.new(1,0,1,0); blocker.BackgroundTransparency=1
        blocker.Text=""; blocker.ZIndex=89; blocker.Parent=self._gui
        blocker.MouseButton1Click:Connect(function() menu:Destroy(); blocker:Destroy() end)
        local function mBtn(txt,fn,danger)
            local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,26); b.BackgroundColor3=UIUtils.Colors.Surface
            b.BackgroundTransparency=1; b.BorderSizePixel=0; b.Text=txt; b.TextColor3=danger and UIUtils.Colors.Danger or UIUtils.Colors.TextPrimary
            b.Font=UIUtils.Font.Medium; b.TextSize=11; b.TextXAlignment=Enum.TextXAlignment.Left; b.AutoButtonColor=false; b.ZIndex=91
            UIUtils.MakeCorner(5,b); UIUtils.MakePadding(b,{Left=UDim.new(0,8)}); UIUtils.AddHoverEffect(b,UIUtils.Colors.SurfaceAlt,UIUtils.Colors.Surface)
            b.MouseButton1Click:Connect(function() menu:Destroy(); blocker:Destroy(); fn() end); b.Parent=menu
        end
        mBtn("▶ Play",       function() self:_playEmote(state.emote) end)
        mBtn(state.locked and "🔓 Unlock" or "🔒 Lock", function() state.locked=not state.locked end)
        mBtn("⊟ Shrink",    function() state.size=math.max(36,state.size-10); state.frame.Size=UDim2.new(0,state.size,0,state.size) end)
        mBtn("⊞ Grow",      function() state.size=math.min(100,state.size+10); state.frame.Size=UDim2.new(0,state.size,0,state.size) end)
        mBtn("✕ Unfloat",   function() self:RemoveFloatEmote(state.emote.id) end, true)
    end

    function M:_playEmote(emote)
        local char = self._ctx and self._ctx.character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then AnimUtils.PlayAnimation(hum, emote.id, Enum.AnimationPriority.Action4, false, 1) end
    end

    function M:RemoveFloatEmote(emoteId)
        local state = self._buttons[emoteId]
        if state then UIUtils.FadeOut(state.frame,0.18,function() state.frame:Destroy() end) end
        self._buttons[emoteId] = nil
        local row = self._panelScroll:FindFirstChild("PR_"..emoteId)
        if row then row:Destroy() end
        self:_updateEmpty()
    end

    function M:Serialize()
        local out = {}
        for id, state in pairs(self._buttons) do
            out[id]={emote=state.emote,locked=state.locked,size=state.size,
                posX=state.frame.Position.X.Offset, posY=state.frame.Position.Y.Offset}
        end
        return out
    end

    function M:Deserialize(data)
        if not data then return end
        for _, entry in pairs(data) do
            if entry.emote then
                self:AddFloatEmote(entry.emote)
                local state = self._buttons[entry.emote.id]
                if state then
                    state.locked=entry.locked; state.size=entry.size or DEFAULT_SIZE
                    state.frame.Size=UDim2.new(0,state.size,0,state.size)
                    state.frame.Position=UDim2.new(0,entry.posX or 0,0,entry.posY or 80)
                end
            end
        end
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: HomeTab
-- ════════════════════════════════════════════════════════
local HomeTab = (function()
    local M = {}; M.__index = M

    function M.new(frame, ctx)
        local self = setmetatable({_frame=frame,_ctx=ctx,_selected=nil,_slotBtns={}}, M)
        self:_build(); return self
    end

    function M:_build()
        local leftPanel = UIUtils.MakeFrame({Name="SlotPanel",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,148,1,0),Parent=self._frame})
        local sTitle = UIUtils.MakeLabel({Text="ANIMATION SLOTS",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,-16,0,28),Position=UDim2.new(0,8,0,0),Parent=leftPanel})
        sTitle.TextSize=10
        local scroll = UIUtils.MakeScrollFrame({Name="SlotScroll",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,1,-28),Position=UDim2.new(0,0,0,28),AutoCanvas=Enum.AutomaticSize.Y,ScrollWidth=3,Parent=leftPanel})
        UIUtils.MakePadding(scroll,{Top=UDim.new(0,4),Bottom=UDim.new(0,4),Left=UDim.new(0,6),Right=UDim.new(0,6)})
        UIUtils.MakeListLayout(scroll,{Padding=UDim.new(0,3)})
        UIUtils.MakeFrame({Name="Div",Color=UIUtils.Colors.Border,Size=UDim2.new(0,1,1,0),Position=UDim2.new(0,148,0,0),Parent=self._frame})
        for i, sn in ipairs(AnimUtils.SlotOrder) do self:_makeSlotBtn(scroll, sn, i) end
        local right = UIUtils.MakeFrame({Name="Detail",Color=UIUtils.Colors.Background,Size=UDim2.new(1,-149,1,0),Position=UDim2.new(0,149,0,0),Parent=self._frame})
        self._rightPanel = right; self:_buildDetail(right); self:_selectSlot("Idle")
    end

    function M:_makeSlotBtn(parent, slotName, order)
        local btn = Instance.new("TextButton"); btn.Name="Slot_"..slotName
        btn.Size=UDim2.new(1,0,0,40); btn.BackgroundColor3=UIUtils.Colors.SurfaceAlt
        btn.BackgroundTransparency=1; btn.BorderSizePixel=0; btn.Text=""
        btn.LayoutOrder=order; btn.AutoButtonColor=false; UIUtils.MakeCorner(8,btn); btn.Parent=parent
        local icon = Instance.new("ImageLabel"); icon.Size=UDim2.new(0,16,0,16)
        icon.Position=UDim2.new(0,8,0.5,-8); icon.BackgroundTransparency=1
        icon.Image=AnimUtils.SlotIcons[slotName] or "rbxassetid://7072725342"; icon.ImageColor3=UIUtils.Colors.TextMuted; icon.Parent=btn
        local lbl=UIUtils.MakeLabel({Text=slotName,Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextSecondary,Frame=UDim2.new(1,-34,0.6,0),Position=UDim2.new(0,30,0,4),Parent=btn})
        lbl.TextSize=13
        local dot=UIUtils.MakeFrame({Color=UIUtils.Colors.TextMuted,Size=UDim2.new(0,6,0,6),Position=UDim2.new(0,30,0.5,6),Parent=btn}); UIUtils.MakeCorner(3,dot)
        local selBar=UIUtils.MakeFrame({Name="SelBar",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,3,0.7,0),Position=UDim2.new(0,0,0.15,0),Parent=btn}); UIUtils.MakeCorner(2,selBar); selBar.Visible=false
        self._slotBtns[slotName]={btn=btn,dot=dot,selBar=selBar,icon=icon,lbl=lbl}
        btn.MouseButton1Click:Connect(function() self:_selectSlot(slotName) end)
        btn.MouseEnter:Connect(function() if self._selected~=slotName then UIUtils.Tween(btn,{BackgroundTransparency=0.5},UIUtils.TweenInfo.Fast) end end)
        btn.MouseLeave:Connect(function() if self._selected~=slotName then UIUtils.Tween(btn,{BackgroundTransparency=1},UIUtils.TweenInfo.Fast) end end)
    end

    function M:_buildDetail(parent)
        UIUtils.MakePadding(parent,{Top=UDim.new(0,12),Bottom=UDim.new(0,12),Left=UDim.new(0,14),Right=UDim.new(0,14)})
        local hdr=UIUtils.MakeLabel({Text="Select a slot",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,0,0,28),Parent=parent}); hdr.TextSize=18; self._slotHeader=hdr
        local badge=UIUtils.MakeFrame({Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,210,0,22),Position=UDim2.new(0,0,0,32),Parent=parent}); UIUtils.MakeCorner(6,badge)
        local bTxt=UIUtils.MakeLabel({Text="Using Roblox Default Animation",Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,-8,1,0),Position=UDim2.new(0,6,0,0),Parent=badge}); bTxt.TextSize=11
        self._statusBadge=badge; self._statusText=bTxt
        local thumbFrame=UIUtils.MakeFrame({Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,120,0,120),Position=UDim2.new(1,-120,0,0),Parent=parent}); UIUtils.MakeCorner(10,thumbFrame); UIUtils.MakeStroke(thumbFrame,UIUtils.Colors.Border,1)
        local thumbImg=Instance.new("ImageLabel"); thumbImg.Size=UDim2.new(1,-8,1,-8); thumbImg.Position=UDim2.new(0,4,0,4)
        thumbImg.BackgroundTransparency=1; thumbImg.ScaleType=Enum.ScaleType.Fit; thumbImg.Parent=thumbFrame
        local noPreview=UIUtils.MakeLabel({Text="No Preview",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,1,0),XAlign=Enum.TextXAlignment.Center,YAlign=Enum.TextYAlignment.Center,Parent=thumbFrame}); noPreview.TextSize=11
        self._thumbImg=thumbImg; self._noPreview=noPreview
        local nameLbl=UIUtils.MakeLabel({Text="",Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextSecondary,Frame=UDim2.new(1,-136,0,18),Position=UDim2.new(0,0,0,60),Parent=parent}); nameLbl.TextSize=12; self._nameLabel=nameLbl
        local descLbl=UIUtils.MakeLabel({Text="",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,-136,0,34),Position=UDim2.new(0,0,0,80),Wrap=true,Parent=parent}); descLbl.TextSize=11; self._descLabel=descLbl
        UIUtils.MakeLabel({Text="Animation ID",Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextSecondary,Frame=UDim2.new(1,0,0,18),Position=UDim2.new(0,0,0,130),Parent=parent}).TextSize=12
        local idFrame,idBox=UIUtils.MakeInput({Placeholder="Enter Animation ID or leave blank for default",Size=UDim2.new(1,0,0,36),Position=UDim2.new(0,0,0,150),Parent=parent}); self._idBox=idBox
        local srcLbl=UIUtils.MakeLabel({Text="Source: —",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,18),Position=UDim2.new(0,0,0,192),Parent=parent}); srcLbl.TextSize=11; self._sourceLabel=srcLbl
        local btnRow=UIUtils.MakeFrame({Color=UIUtils.Colors.Background,Transparency=1,Size=UDim2.new(1,0,0,36),Position=UDim2.new(0,0,0,218),Parent=parent})
        UIUtils.MakeListLayout(btnRow,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8)})
        local prevBtn=UIUtils.MakeButton({Text="Preview",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,90,0,34),Parent=btnRow}); prevBtn.LayoutOrder=1
        local editBtn=UIUtils.MakeButton({Text="Edit",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,90,0,34),Parent=btnRow}); editBtn.LayoutOrder=2
        local rstBtn=UIUtils.MakeButton({Text="Reset Default",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,110,0,34),Parent=btnRow}); rstBtn.LayoutOrder=3; UIUtils.AddHoverEffect(rstBtn,UIUtils.Colors.Danger,UIUtils.Colors.SurfaceAlt)
        local applyBtn=UIUtils.MakeButton({Text="Apply ID",Color=UIUtils.Colors.Success,Size=UDim2.new(0,90,0,34),Parent=btnRow}); applyBtn.LayoutOrder=4
        prevBtn.MouseButton1Click:Connect(function() self:_previewSelected() end)
        editBtn.MouseButton1Click:Connect(function() if self._ctx and self._ctx.onOpenEditor then self._ctx.onOpenEditor(self._selected) end end)
        rstBtn.MouseButton1Click:Connect(function() self:_resetSelected() end)
        applyBtn.MouseButton1Click:Connect(function() self:_applyID() end)
        idBox:GetPropertyChangedSignal("Text"):Connect(function() self:_updateStatus(idBox.Text) end)
    end

    function M:_selectSlot(slotName)
        if self._selected then
            local old=self._slotBtns[self._selected]
            if old then UIUtils.Tween(old.btn,{BackgroundTransparency=1},UIUtils.TweenInfo.Fast); old.selBar.Visible=false
                UIUtils.Tween(old.lbl,{TextColor3=UIUtils.Colors.TextSecondary},UIUtils.TweenInfo.Fast)
                UIUtils.Tween(old.icon,{ImageColor3=UIUtils.Colors.TextMuted},UIUtils.TweenInfo.Fast) end
        end
        self._selected=slotName
        local els=self._slotBtns[slotName]
        if els then UIUtils.Tween(els.btn,{BackgroundTransparency=0},UIUtils.TweenInfo.Fast); els.btn.BackgroundColor3=UIUtils.Colors.SurfaceAlt
            els.selBar.Visible=true; UIUtils.Tween(els.lbl,{TextColor3=UIUtils.Colors.TextPrimary},UIUtils.TweenInfo.Fast)
            UIUtils.Tween(els.icon,{ImageColor3=UIUtils.Colors.Accent},UIUtils.TweenInfo.Fast) end
        self:_refreshDetail(slotName)
    end

    function M:_refreshDetail(slotName)
        self._slotHeader.Text=slotName
        local am=self._ctx and self._ctx.animManager
        local slot=am and am:GetSlot(slotName)
        local id=slot and slot.id or ""; local name=slot and slot.name or slotName.." (Default)"
        local desc=slot and slot.description or "Roblox default animation."; local source=slot and slot.source or "Default"
        self._idBox.Text=id; self._nameLabel.Text=name; self._descLabel.Text=desc; self._sourceLabel.Text="Source: "..source
        if id~="" then self._thumbImg.Image=AssetUtils.GetAnimThumbnail(id); self._thumbImg.Visible=true; self._noPreview.Visible=false
        else self._thumbImg.Image=""; self._thumbImg.Visible=false; self._noPreview.Visible=true end
        self:_updateStatus(id)
    end

    function M:_updateStatus(id)
        if not id or id=="" then
            self._statusText.Text="Using Roblox Default Animation"; self._statusBadge.BackgroundColor3=UIUtils.Colors.SurfaceAlt
            UIUtils.Tween(self._statusText,{TextColor3=UIUtils.Colors.TextMuted},UIUtils.TweenInfo.Fast)
        else
            self._statusText.Text="Custom Animation Active"; self._statusBadge.BackgroundColor3=UIUtils.Colors.AccentDim
            UIUtils.Tween(self._statusText,{TextColor3=UIUtils.Colors.Accent},UIUtils.TweenInfo.Fast)
        end
    end

    function M:_previewSelected()
        local am=self._ctx and self._ctx.animManager; if am then am:Preview(self._selected) end
    end

    function M:_resetSelected()
        local am=self._ctx and self._ctx.animManager; if am then am:ClearSlot(self._selected) end
        self._idBox.Text=""; self:_refreshDetail(self._selected)
        local els=self._slotBtns[self._selected]
        if els then UIUtils.Tween(els.dot,{BackgroundColor3=UIUtils.Colors.TextMuted},UIUtils.TweenInfo.Fast) end
    end

    function M:_applyID()
        if not self._selected then return end
        local id=self._idBox.Text
        if not AnimUtils.IsValidAssetID(id) and id~="" then
            if self._ctx and self._ctx.studio then self._ctx.studio:Notify("Invalid animation ID","error") end; return
        end
        local am=self._ctx and self._ctx.animManager
        if am then am:SetSlot(self._selected,{id=AnimUtils.NormalizeID(id),source=id=="" and "Default" or "Custom ID",name=self._selected.." (Custom)"}) end
        self:_refreshDetail(self._selected)
        local els=self._slotBtns[self._selected]
        if els then UIUtils.Tween(els.dot,{BackgroundColor3=id~="" and UIUtils.Colors.Success or UIUtils.Colors.TextMuted},UIUtils.TweenInfo.Fast) end
    end

    function M:OnActivate() if self._selected then self:_refreshDetail(self._selected) end end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: PacksTab
-- ════════════════════════════════════════════════════════
local PacksTab = (function()
    local M = {}; M.__index = M
    local CATEGORIES = {"Default","Custom","Edited"}

    function M.new(frame, ctx)
        local self = setmetatable({_frame=frame,_ctx=ctx,_folders={},_expanded={},_activeCat="Custom",_catBtns={}}, M)
        self:_build(); return self
    end

    function M:_build()
        local topBar=UIUtils.MakeFrame({Name="TopBar",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,0,46),Parent=self._frame})
        UIUtils.MakePadding(topBar,{Top=UDim.new(0,6),Bottom=UDim.new(0,6),Left=UDim.new(0,8),Right=UDim.new(0,8)})
        UIUtils.MakeListLayout(topBar,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8)})
        local tLbl=UIUtils.MakeLabel({Text="Animation Packs",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(0,160,1,0),Parent=topBar}); tLbl.TextSize=15; tLbl.LayoutOrder=1
        local nfBtn=UIUtils.MakeButton({Text="+ New Folder",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,110,0,32),Parent=topBar}); nfBtn.LayoutOrder=2
        local npBtn=UIUtils.MakeButton({Text="+ Save Pack",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,110,0,32),Parent=topBar}); npBtn.LayoutOrder=3

        local catBar=UIUtils.MakeFrame({Name="CatBar",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,0,34),Position=UDim2.new(0,0,0,46),Parent=self._frame})
        UIUtils.MakePadding(catBar,{Left=UDim.new(0,8),Right=UDim.new(0,8),Top=UDim.new(0,4),Bottom=UDim.new(0,4)})
        UIUtils.MakeListLayout(catBar,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6)})
        for _, cat in ipairs(CATEGORIES) do
            local cb=UIUtils.MakeButton({Text=cat,Color=cat==self._activeCat and UIUtils.Colors.Accent or UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,80,0,26),Parent=catBar})
            cb.TextSize=12; self._catBtns[cat]=cb
            cb.MouseButton1Click:Connect(function() self:_switchCat(cat) end)
        end

        local scroll=UIUtils.MakeScrollFrame({Name="PackScroll",Color=UIUtils.Colors.Background,Size=UDim2.new(1,0,1,-80),Position=UDim2.new(0,0,0,80),AutoCanvas=Enum.AutomaticSize.Y,Parent=self._frame})
        UIUtils.MakePadding(scroll,{Top=UDim.new(0,8),Bottom=UDim.new(0,8),Left=UDim.new(0,8),Right=UDim.new(0,8)})
        UIUtils.MakeListLayout(scroll,{Padding=UDim.new(0,6)}); self._scroll=scroll

        nfBtn.MouseButton1Click:Connect(function() self:_newFolder() end)
        npBtn.MouseButton1Click:Connect(function() self:_savePack() end)

        for _, cat in ipairs(CATEGORIES) do
            self._folders[cat]={}
            if cat=="Default" then
                self._folders[cat]["Built-in"]={packs={{name="Default R15",slots=AnimUtils.DefaultAnimIDs.R15},{name="Default R6",slots=AnimUtils.DefaultAnimIDs.R6}}}
            else self._folders[cat]["General"]={packs={}} end
        end
        self:_render()
    end

    function M:_switchCat(cat)
        self._activeCat=cat
        for id,btn in pairs(self._catBtns) do UIUtils.Tween(btn,{BackgroundColor3=id==cat and UIUtils.Colors.Accent or UIUtils.Colors.SurfaceAlt},UIUtils.TweenInfo.Fast) end
        self:_render()
    end

    function M:_render()
        for _, c in ipairs(self._scroll:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
        for folderName, folderData in pairs(self._folders[self._activeCat] or {}) do
            self:_makeFolderRow(folderName, folderData)
        end
    end

    function M:_makeFolderRow(folderName, folderData)
        local fKey = self._activeCat.."_"..folderName
        local header=UIUtils.MakeFrame({Name="Folder_"..folderName,Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,38),Parent=self._scroll})
        UIUtils.MakeCorner(8,header)
        local arrow=UIUtils.MakeLabel({Text=self._expanded[fKey]~=false and "▾" or "▸",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.Accent,Frame=UDim2.new(0,20,1,0),Position=UDim2.new(0,8,0,0),Parent=header}); arrow.TextSize=14
        local fLbl=UIUtils.MakeLabel({Text="📁  "..folderName,Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,-100,1,0),Position=UDim2.new(0,30,0,0),Parent=header}); fLbl.TextSize=13
        local cntLbl=UIUtils.MakeLabel({Text=tostring(#(folderData.packs or {})).." packs",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(0,60,1,0),Position=UDim2.new(1,-110,0,0),XAlign=Enum.TextXAlignment.Right,Parent=header}); cntLbl.TextSize=11
        local dotBtn=UIUtils.MakeIconButton({Icon="rbxassetid://7072706620",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,28,0,28),Position=UDim2.new(1,-36,0.5,-14),Parent=header})
        dotBtn.MouseButton1Click:Connect(function() self:_showCtxMenu({{label="Rename",action=function() end},{label="Delete",action=function() self._folders[self._activeCat][folderName]=nil; self:_render() end,danger=true}},dotBtn) end)
        local cc=Instance.new("TextButton"); cc.Size=UDim2.new(1,-40,1,0); cc.BackgroundTransparency=1; cc.Text=""; cc.Parent=header
        cc.MouseButton1Click:Connect(function()
            self._expanded[fKey]=not (self._expanded[fKey]~=false); arrow.Text=self._expanded[fKey]~=false and "▾" or "▸"; self:_render()
        end)
        if self._expanded[fKey]~=false then
            for _, pack in ipairs(folderData.packs or {}) do self:_makePackRow(pack, folderName) end
        end
    end

    function M:_makePackRow(pack, folderName)
        local row=UIUtils.MakeFrame({Name="Pack_"..pack.name,Color=UIUtils.Colors.Surface,Size=UDim2.new(1,-16,0,44),Parent=self._scroll})
        UIUtils.MakeCorner(8,row); UIUtils.MakeStroke(row,UIUtils.Colors.Border,1)
        local acc=UIUtils.MakeFrame({Color=UIUtils.Colors.Accent,Size=UDim2.new(0,3,0.6,0),Position=UDim2.new(0,0,0.2,0),Parent=row}); UIUtils.MakeCorner(2,acc)
        local nLbl=UIUtils.MakeLabel({Text=pack.name,Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,-80,0.55,0),Position=UDim2.new(0,12,0,4),Parent=row}); nLbl.TextSize=13
        local cnt=0; for _ in pairs(pack.slots or {}) do cnt=cnt+1 end
        local iLbl=UIUtils.MakeLabel({Text=cnt.." slots",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,-80,0.45,0),Position=UDim2.new(0,12,0.55,0),Parent=row}); iLbl.TextSize=11
        local useBtn=UIUtils.MakeButton({Text="Use",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,48,0,28),Position=UDim2.new(1,-88,0.5,-14),Parent=row})
        useBtn.MouseButton1Click:Connect(function() local am=self._ctx and self._ctx.animManager; if am then am:ApplyPack(pack) end end)
        local dotBtn=UIUtils.MakeIconButton({Icon="rbxassetid://7072706620",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,28,0,28),Position=UDim2.new(1,-36,0.5,-14),Parent=row})
        dotBtn.MouseButton1Click:Connect(function()
            self:_showCtxMenu({
                {label="Use",      action=function() local am=self._ctx and self._ctx.animManager; if am then am:ApplyPack(pack) end end},
                {label="Duplicate",action=function() local dup={name=pack.name.." (Copy)",slots={},emotes={}}; for k,v in pairs(pack.slots or {}) do dup.slots[k]=v end; table.insert(self._folders[self._activeCat][folderName].packs,dup); self:_render() end},
                {label="Delete",   action=function()
                    local f=self._folders[self._activeCat][folderName]
                    if f then for i,p in ipairs(f.packs) do if p==pack then table.remove(f.packs,i) break end end end; self:_render()
                end, danger=true},
            }, dotBtn)
        end)
    end

    function M:_showCtxMenu(items, anchor)
        for _, c in ipairs(self._frame:GetChildren()) do if c.Name=="ContextMenu" then c:Destroy() end end
        local absPos=anchor.AbsolutePosition
        local menu=UIUtils.MakeFrame({Name="ContextMenu",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,160,0,#items*34+8),Position=UDim2.new(0,absPos.X-self._frame.AbsolutePosition.X-165,0,absPos.Y-self._frame.AbsolutePosition.Y+36),Parent=self._frame})
        menu.ZIndex=50; UIUtils.MakeCorner(8,menu); UIUtils.MakeStroke(menu,UIUtils.Colors.Border,1)
        UIUtils.MakeListLayout(menu,{Padding=UDim.new(0,2)}); UIUtils.MakePadding(menu,{Top=UDim.new(0,4),Bottom=UDim.new(0,4),Left=UDim.new(0,4),Right=UDim.new(0,4)})
        UIUtils.SlideIn(menu,"Top",10,0.15)
        local blocker=Instance.new("TextButton"); blocker.Size=UDim2.new(1,0,1,0); blocker.BackgroundTransparency=1; blocker.Text=""; blocker.ZIndex=49; blocker.Parent=self._frame
        blocker.MouseButton1Click:Connect(function() menu:Destroy(); blocker:Destroy() end)
        for i,item in ipairs(items) do
            local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,30); b.BackgroundColor3=UIUtils.Colors.Surface; b.BackgroundTransparency=1
            b.BorderSizePixel=0; b.Text=item.label; b.TextColor3=item.danger and UIUtils.Colors.Danger or UIUtils.Colors.TextPrimary
            b.Font=UIUtils.Font.Medium; b.TextSize=13; b.TextXAlignment=Enum.TextXAlignment.Left; b.AutoButtonColor=false; b.ZIndex=51; b.LayoutOrder=i
            UIUtils.MakeCorner(6,b); UIUtils.MakePadding(b,{Left=UDim.new(0,8)}); UIUtils.AddHoverEffect(b,UIUtils.Colors.SurfaceAlt,UIUtils.Colors.Surface)
            b.MouseButton1Click:Connect(function() menu:Destroy(); blocker:Destroy(); item.action() end); b.Parent=menu
        end
    end

    function M:_newFolder()
        local cat=self._activeCat; local name="New Folder "..tostring(os.time()):sub(-4)
        if not self._folders[cat] then self._folders[cat]={} end
        self._folders[cat][name]={packs={}}; self:_render()
        if self._ctx and self._ctx.studio then self._ctx.studio:Notify('Folder "'..name..'" created',"success") end
    end

    function M:_savePack()
        local am=self._ctx and self._ctx.animManager; if not am then return end
        local slots=am:SerializeSlots(); local pack=AnimUtils.MakePack("My Pack "..tostring(os.time()):sub(-4),slots)
        local cat="Custom"; if not self._folders[cat] then self._folders[cat]={} end
        if not self._folders[cat]["General"] then self._folders[cat]["General"]={packs={}} end
        table.insert(self._folders[cat]["General"].packs,pack); self:_switchCat(cat)
        if self._ctx and self._ctx.studio then self._ctx.studio:Notify("Pack saved!","success") end
    end

    function M:GetFolders() return self._folders end
    function M:SetFolders(d) self._folders=d or {}; self:_render() end
    function M:OnActivate() self:_render() end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: EmotesTab
-- ════════════════════════════════════════════════════════
local EmotesTab = (function()
    local M = {}; M.__index = M

    function M.new(frame, ctx)
        local self=setmetatable({_frame=frame,_ctx=ctx,_favorites={},_emotes={},_filtered={},_showFavs=false,_activeTrack=nil},M)
        self:_loadEmotes(); self:_build(); return self
    end

    function M:_loadEmotes()
        for _,e in ipairs(AssetUtils.RobloxEmotes) do
            table.insert(self._emotes,{name=e.name,id=e.id,tags=e.tags,source="Roblox Emote",fav=false})
        end
        self._filtered=self._emotes
    end

    function M:_build()
        local topBar=UIUtils.MakeFrame({Name="TopBar",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,0,48),Parent=self._frame})
        UIUtils.MakePadding(topBar,{Top=UDim.new(0,6),Bottom=UDim.new(0,6),Left=UDim.new(0,8),Right=UDim.new(0,8)})
        UIUtils.MakeListLayout(topBar,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6)})
        local sf,sb=UIUtils.MakeInput({Placeholder="Search emotes, IDs, tags...",Size=UDim2.new(0,220,0,34),Parent=topBar}); sf.LayoutOrder=1; self._searchBox=sb
        local favBtn=UIUtils.MakeButton({Text="★ Favorites",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,100,0,34),Parent=topBar}); favBtn.LayoutOrder=2
        local floatBtn=UIUtils.MakeButton({Text="⊞ Float",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,80,0,34),Parent=topBar}); floatBtn.LayoutOrder=3
        local addBtn=UIUtils.MakeButton({Text="+ Add ID",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,80,0,34),Parent=topBar}); addBtn.LayoutOrder=4

        local grid=UIUtils.MakeScrollFrame({Name="EmoteGrid",Color=UIUtils.Colors.Background,Size=UDim2.new(1,0,1,-48),Position=UDim2.new(0,0,0,48),AutoCanvas=Enum.AutomaticSize.Y,Parent=self._frame})
        UIUtils.MakePadding(grid,{Top=UDim.new(0,10),Bottom=UDim.new(0,10),Left=UDim.new(0,10),Right=UDim.new(0,10)})
        local gl=Instance.new("UIGridLayout"); gl.CellSize=UDim2.new(0,110,0,130); gl.CellPadding=UDim2.new(0,8,0,8)
        gl.FillDirection=Enum.FillDirection.Horizontal; gl.SortOrder=Enum.SortOrder.LayoutOrder; gl.Parent=grid
        self._grid=grid

        sb:GetPropertyChangedSignal("Text"):Connect(function() self:_filter(sb.Text) end)
        favBtn.MouseButton1Click:Connect(function()
            self._showFavs=not self._showFavs
            UIUtils.Tween(favBtn,{BackgroundColor3=self._showFavs and UIUtils.Colors.Gold or UIUtils.Colors.SurfaceAlt},UIUtils.TweenInfo.Fast)
            self:_filter(sb.Text)
        end)
        floatBtn.MouseButton1Click:Connect(function() if self._ctx and self._ctx.floatSystem then self._ctx.floatSystem:TogglePanel() end end)
        addBtn.MouseButton1Click:Connect(function() self:_promptAdd() end)
        self:_renderGrid()
    end

    function M:_filter(query)
        if (not query or query=="") and not self._showFavs then self._filtered=self._emotes
        else
            local results=AssetUtils.SearchEmotes(query or "",self._emotes)
            if self._showFavs then
                local fo={}; for _,e in ipairs(results) do if self._favorites[e.id] then table.insert(fo,e) end end; self._filtered=fo
            else self._filtered=results end
        end
        self:_renderGrid()
    end

    function M:_renderGrid()
        for _, c in ipairs(self._grid:GetChildren()) do if not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then c:Destroy() end end
        if #self._filtered==0 then
            local e=UIUtils.MakeLabel({Text="No emotes found.",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(0,200,0,40),XAlign=Enum.TextXAlignment.Center,Parent=self._grid}); e.TextSize=13; return
        end
        for i,emote in ipairs(self._filtered) do self:_makeCard(emote,i) end
    end

    function M:_makeCard(emote, order)
        local card=UIUtils.MakeFrame({Name="E_"..emote.id,Color=UIUtils.Colors.Surface,Parent=self._grid}); card.LayoutOrder=order
        UIUtils.MakeCorner(10,card); UIUtils.MakeStroke(card,UIUtils.Colors.Border,1)
        local thumb=Instance.new("ImageLabel"); thumb.Size=UDim2.new(1,-8,0,72); thumb.Position=UDim2.new(0,4,0,4)
        thumb.BackgroundColor3=UIUtils.Colors.SurfaceAlt; thumb.BorderSizePixel=0
        thumb.Image=AssetUtils.GetAnimThumbnail(emote.id); thumb.ScaleType=Enum.ScaleType.Fit; UIUtils.MakeCorner(7,thumb); thumb.Parent=card
        local noThumb=UIUtils.MakeLabel({Text="No Preview",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,1,0),XAlign=Enum.TextXAlignment.Center,YAlign=Enum.TextYAlignment.Center,Parent=thumb}); noThumb.TextSize=9
        local nLbl=UIUtils.MakeLabel({Text=emote.name,Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,-8,0,18),Position=UDim2.new(0,4,0,80),Parent=card}); nLbl.TextSize=11; nLbl.TextTruncate=Enum.TextTruncate.AtEnd
        local sLbl=UIUtils.MakeLabel({Text=emote.source or "Emote",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,-22,0,14),Position=UDim2.new(0,4,0,100),Parent=card}); sLbl.TextSize=9
        local fav=Instance.new("TextButton"); fav.Size=UDim2.new(0,18,0,18); fav.Position=UDim2.new(1,-22,0,80)
        fav.BackgroundTransparency=1; fav.Text=self._favorites[emote.id] and "★" or "☆"
        fav.TextColor3=self._favorites[emote.id] and UIUtils.Colors.Gold or UIUtils.Colors.TextMuted; fav.TextSize=14; fav.Font=UIUtils.Font.Bold; fav.Parent=card
        fav.MouseButton1Click:Connect(function()
            self._favorites[emote.id]=not self._favorites[emote.id]; fav.Text=self._favorites[emote.id] and "★" or "☆"
            fav.TextColor3=self._favorites[emote.id] and UIUtils.Colors.Gold or UIUtils.Colors.TextMuted
        end)
        local dot=Instance.new("TextButton"); dot.Size=UDim2.new(0,20,0,20); dot.Position=UDim2.new(1,-24,0,4)
        dot.BackgroundTransparency=1; dot.Text="⋮"; dot.TextColor3=UIUtils.Colors.TextMuted; dot.TextSize=16; dot.Font=UIUtils.Font.Bold; dot.Parent=card
        dot.MouseButton1Click:Connect(function() self:_showMenu(emote,dot) end)
        local cc=Instance.new("TextButton"); cc.Size=UDim2.new(1,-24,0,76); cc.Position=UDim2.new(0,0,0,4)
        cc.BackgroundTransparency=1; cc.Text=""; cc.Parent=card
        cc.MouseButton1Click:Connect(function() self:_play(emote) end)
        cc.MouseEnter:Connect(function() UIUtils.Tween(card,{BackgroundColor3=UIUtils.Colors.SurfaceAlt},UIUtils.TweenInfo.Fast) end)
        cc.MouseLeave:Connect(function() UIUtils.Tween(card,{BackgroundColor3=UIUtils.Colors.Surface},UIUtils.TweenInfo.Fast) end)
    end

    function M:_showMenu(emote, anchor)
        for _,c in ipairs(self._frame:GetChildren()) do if c.Name=="ContextMenu" then c:Destroy() end end
        local absPos=anchor.AbsolutePosition
        local menu=UIUtils.MakeFrame({Name="ContextMenu",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,150,0,188),Position=UDim2.new(0,absPos.X-self._frame.AbsolutePosition.X-155,0,absPos.Y-self._frame.AbsolutePosition.Y+24),Parent=self._frame})
        menu.ZIndex=60; UIUtils.MakeCorner(8,menu); UIUtils.MakeStroke(menu,UIUtils.Colors.Border,1)
        UIUtils.MakeListLayout(menu,{Padding=UDim.new(0,2)}); UIUtils.MakePadding(menu,{Top=UDim.new(0,4),Bottom=UDim.new(0,4),Left=UDim.new(0,4),Right=UDim.new(0,4)})
        UIUtils.SlideIn(menu,"Top",8,0.14)
        local blocker=Instance.new("TextButton"); blocker.Size=UDim2.new(1,0,1,0); blocker.BackgroundTransparency=1; blocker.Text=""; blocker.ZIndex=59; blocker.Parent=self._frame
        blocker.MouseButton1Click:Connect(function() menu:Destroy(); blocker:Destroy() end)
        local items={
            {label="Play",      fn=function() self:_play(emote) end},
            {label="Favorite",  fn=function() self._favorites[emote.id]=not self._favorites[emote.id]; self:_renderGrid() end},
            {label="Float",     fn=function() if self._ctx and self._ctx.floatSystem then self._ctx.floatSystem:AddFloatEmote(emote) end end},
            {label="Duplicate", fn=function() local d={name=emote.name.." (Copy)",id=emote.id,tags=emote.tags,source=emote.source,fav=false}; table.insert(self._emotes,d); self:_filter("") end},
            {label="Delete",    fn=function() for i,e in ipairs(self._emotes) do if e==emote then table.remove(self._emotes,i) break end end; self:_filter("") end, danger=true},
        }
        for i,item in ipairs(items) do
            local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,28); b.BackgroundColor3=UIUtils.Colors.Surface
            b.BackgroundTransparency=1; b.BorderSizePixel=0; b.Text=item.label
            b.TextColor3=item.danger and UIUtils.Colors.Danger or UIUtils.Colors.TextPrimary
            b.Font=UIUtils.Font.Medium; b.TextSize=12; b.TextXAlignment=Enum.TextXAlignment.Left; b.AutoButtonColor=false; b.ZIndex=61; b.LayoutOrder=i
            UIUtils.MakeCorner(6,b); UIUtils.MakePadding(b,{Left=UDim.new(0,8)}); UIUtils.AddHoverEffect(b,UIUtils.Colors.SurfaceAlt,UIUtils.Colors.Surface)
            b.MouseButton1Click:Connect(function() menu:Destroy(); blocker:Destroy(); item.fn() end); b.Parent=menu
        end
    end

    function M:_play(emote)
        local char=self._ctx and self._ctx.character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if self._activeTrack then self._activeTrack:Stop(0.2); self._activeTrack=nil end
        self._activeTrack=AnimUtils.PlayAnimation(hum,emote.id,Enum.AnimationPriority.Action4,false,1)
    end

    function M:_promptAdd()
        UIUtils.Confirm(self._frame,{
            Title="Add Custom Emote",Body="Paste the Animation ID below.",
            Buttons={{Text="Add",Kind="primary",Value=true},{Text="Cancel",Kind="ghost",Value=false}}
        },function(val)
            if val then
                local id="507770239"
                self:AddEmoteByID(id,"Custom Emote "..tostring(#self._emotes+1))
            end
        end)
    end

    function M:AddEmoteByID(id, name)
        if not AnimUtils.IsValidAssetID(id) then return false end
        table.insert(self._emotes,{name=name or ("Emote "..id),id=AnimUtils.NormalizeID(id),tags={"imported"},source="Custom ID",fav=false})
        self:_filter(""); return true
    end

    function M:Serialize()
        local custom={}
        for _,e in ipairs(self._emotes) do if e.source=="Custom ID" or e.source=="Imported" then table.insert(custom,e) end end
        return {customEmotes=custom,favorites=self._favorites}
    end

    function M:Deserialize(d)
        if not d then return end
        for _,e in ipairs(d.customEmotes or {}) do table.insert(self._emotes,e) end
        self._favorites=d.favorites or {}; self:_filter("")
    end

    function M:OnActivate() self:_renderGrid() end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: ExplorerTab
-- ════════════════════════════════════════════════════════
local ExplorerTab = (function()
    local M = {}; M.__index = M

    function M.new(frame, ctx)
        local self=setmetatable({_frame=frame,_ctx=ctx,_loaded=nil,_scanData=nil,_selected=nil,_activeInspTab="Animations",_inspFrames={},_inspBtns={}},M)
        self:_build(); return self
    end

    function M:_build()
        local topBar=UIUtils.MakeFrame({Name="TopBar",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,0,52),Parent=self._frame})
        UIUtils.MakePadding(topBar,{Top=UDim.new(0,8),Bottom=UDim.new(0,8),Left=UDim.new(0,8),Right=UDim.new(0,8)})
        UIUtils.MakeListLayout(topBar,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8)})
        local _,inputBox=UIUtils.MakeInput({Placeholder="Paste asset/model/animation link or ID...",Size=UDim2.new(0,300,0,36),Parent=topBar}); inputBox.Parent.LayoutOrder=1; self._inputBox=inputBox
        local loadBtn=UIUtils.MakeButton({Text="Load Asset",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,100,0,36),Parent=topBar}); loadBtn.LayoutOrder=2
        local clrBtn=UIUtils.MakeButton({Text="Clear",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,70,0,36),Parent=topBar}); clrBtn.LayoutOrder=3

        local notifBar=UIUtils.MakeFrame({Name="NotifBar",Color=UIUtils.Colors.AccentDim,Size=UDim2.new(1,0,0,26),Position=UDim2.new(0,0,0,52),Parent=self._frame}); notifBar.Visible=false
        local notifLbl=UIUtils.MakeLabel({Text="",Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,-16,1,0),Position=UDim2.new(0,8,0,0),Parent=notifBar}); notifLbl.TextSize=12
        self._notifBar=notifBar; self._notifLbl=notifLbl

        local bodyY=78
        local treePanel=UIUtils.MakeFrame({Name="TreePanel",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,180,1,-bodyY),Position=UDim2.new(0,0,0,bodyY),Parent=self._frame})
        local tLbl=UIUtils.MakeLabel({Text="HIERARCHY",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,22),Position=UDim2.new(0,8,0,0),Parent=treePanel}); tLbl.TextSize=9
        local treeScroll=UIUtils.MakeScrollFrame({Name="TreeScroll",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,1,-24),Position=UDim2.new(0,0,0,24),AutoCanvas=Enum.AutomaticSize.Y,Parent=treePanel})
        UIUtils.MakePadding(treeScroll,{Top=UDim.new(0,4),Left=UDim.new(0,4),Right=UDim.new(0,4),Bottom=UDim.new(0,4)}); UIUtils.MakeListLayout(treeScroll,{Padding=UDim.new(0,2)}); self._treeScroll=treeScroll

        local prevPanel=UIUtils.MakeFrame({Name="PreviewPanel",Color=UIUtils.Colors.Background,Size=UDim2.new(1,-450,1,-bodyY),Position=UDim2.new(0,180,0,bodyY),Parent=self._frame}); UIUtils.MakeStroke(prevPanel,UIUtils.Colors.Border,1)
        local prevImg=Instance.new("ImageLabel"); prevImg.Size=UDim2.new(0.8,0,0.8,0); prevImg.Position=UDim2.new(0.1,0,0.1,0); prevImg.BackgroundTransparency=1; prevImg.ScaleType=Enum.ScaleType.Fit; prevImg.Parent=prevPanel; self._previewImg=prevImg
        local prevEmpty=UIUtils.MakeLabel({Text="Load an asset to preview",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,1,0),XAlign=Enum.TextXAlignment.Center,YAlign=Enum.TextYAlignment.Center,Parent=prevPanel}); prevEmpty.TextSize=13; self._previewEmpty=prevEmpty

        local inspector=UIUtils.MakeFrame({Name="Inspector",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,270,1,-bodyY),Position=UDim2.new(1,-270,0,bodyY),Parent=self._frame})
        local inspTabBar=UIUtils.MakeFrame({Name="InspTabBar",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,30),Parent=inspector})
        UIUtils.MakeListLayout(inspTabBar,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,2)}); UIUtils.MakePadding(inspTabBar,{Left=UDim.new(0,4),Right=UDim.new(0,4),Top=UDim.new(0,4),Bottom=UDim.new(0,4)})
        local inspContent=UIUtils.MakeFrame({Name="InspContent",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,1,-30),Position=UDim2.new(0,0,0,30),ClipsDescendants=true,Parent=inspector})

        local inspTabs={"Scripts","Animations","Assets","Properties"}
        for i,tabName in ipairs(inspTabs) do
            local tb=UIUtils.MakeButton({Text=tabName,Color=tabName==self._activeInspTab and UIUtils.Colors.Accent or UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,58,1,0),Parent=inspTabBar}); tb.TextSize=10; tb.LayoutOrder=i
            self._inspBtns[tabName]=tb
            local tf=UIUtils.MakeFrame({Name="Insp_"..tabName,Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,1,0),Parent=inspContent}); tf.Visible=tabName==self._activeInspTab; self._inspFrames[tabName]=tf
            tb.MouseButton1Click:Connect(function()
                self._activeInspTab=tabName
                for id,frame in pairs(self._inspFrames) do frame.Visible=id==tabName end
                for id,btn in pairs(self._inspBtns) do UIUtils.Tween(btn,{BackgroundColor3=id==tabName and UIUtils.Colors.Accent or UIUtils.Colors.SurfaceAlt},UIUtils.TweenInfo.Fast) end
            end)
        end

        -- Build script list scroll
        UIUtils.MakePadding(self._inspFrames["Scripts"],{Top=UDim.new(0,6),Left=UDim.new(0,6),Right=UDim.new(0,6),Bottom=UDim.new(0,6)})
        local scriptScroll=UIUtils.MakeScrollFrame({Name="SScroll",Color=UIUtils.Colors.Background,Size=UDim2.new(1,0,1,0),AutoCanvas=Enum.AutomaticSize.Y,Parent=self._inspFrames["Scripts"]})
        UIUtils.MakeListLayout(scriptScroll,{Padding=UDim.new(0,4)}); UIUtils.MakePadding(scriptScroll,{Top=UDim.new(0,4),Left=UDim.new(0,4),Right=UDim.new(0,4),Bottom=UDim.new(0,4)}); self._scriptScroll=scriptScroll
        local scriptEmpty=UIUtils.MakeLabel({Text="No scripts loaded.",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,50),XAlign=Enum.TextXAlignment.Center,YAlign=Enum.TextYAlignment.Center,Wrap=true,Parent=scriptScroll}); scriptEmpty.TextSize=11; self._scriptEmpty=scriptEmpty

        UIUtils.MakePadding(self._inspFrames["Animations"],{Top=UDim.new(0,4),Left=UDim.new(0,4),Right=UDim.new(0,4),Bottom=UDim.new(0,4)})
        local animScroll=UIUtils.MakeScrollFrame({Name="AScroll",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,1,0),AutoCanvas=Enum.AutomaticSize.Y,Parent=self._inspFrames["Animations"]})
        UIUtils.MakeListLayout(animScroll,{Padding=UDim.new(0,4)}); UIUtils.MakePadding(animScroll,{Top=UDim.new(0,4),Left=UDim.new(0,4),Right=UDim.new(0,4),Bottom=UDim.new(0,4)}); self._animScroll=animScroll

        loadBtn.MouseButton1Click:Connect(function() self:_loadAsset(inputBox.Text) end)
        clrBtn.MouseButton1Click:Connect(function() self:_clear() end)
    end

    function M:_populateScripts(scripts)
        for _,c in ipairs(self._scriptScroll:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
        self._scriptEmpty.Visible=#scripts==0
        for _,si in ipairs(scripts) do
            local card=UIUtils.MakeFrame({Name="SC_"..si.name,Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,64),Parent=self._scriptScroll}); UIUtils.MakeCorner(6,card)
            local nLbl=UIUtils.MakeLabel({Text="📄 "..si.name,Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,-8,0,20),Position=UDim2.new(0,6,0,4),Parent=card}); nLbl.TextSize=12
            local iLbl=UIUtils.MakeLabel({Text="Found "..#si.ids.." animation IDs",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.Accent,Frame=UDim2.new(1,-8,0,16),Position=UDim2.new(0,6,0,24),Parent=card}); iLbl.TextSize=11
            local impBtn=UIUtils.MakeButton({Text="Import All",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,80,0,24),Position=UDim2.new(0,6,0,36),Parent=card}); impBtn.TextSize=11
            impBtn.MouseButton1Click:Connect(function()
                for _,id in ipairs(si.ids) do if self._ctx and self._ctx.emoteSystem then self._ctx.emoteSystem:AddEmoteByID(id) end end
                if self._ctx and self._ctx.studio then self._ctx.studio:Notify("Imported "..#si.ids.." animations","success") end
            end)
        end
    end

    function M:_populateAnimations(anims)
        for _,c in ipairs(self._animScroll:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
        if #anims==0 then UIUtils.MakeLabel({Text="No animation objects found.",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,30),XAlign=Enum.TextXAlignment.Center,Parent=self._animScroll}).TextSize=11; return end
        for _,anim in ipairs(anims) do
            local row=UIUtils.MakeFrame({Name="AN_"..anim.id,Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,48),Parent=self._animScroll}); UIUtils.MakeCorner(6,row)
            UIUtils.MakeLabel({Text=anim.name,Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,-80,0,20),Position=UDim2.new(0,6,0,4),Parent=row}).TextSize=12
            UIUtils.MakeLabel({Text="ID: "..anim.id,Font=UIUtils.Font.Mono,Color=UIUtils.Colors.Accent,Frame=UDim2.new(1,-80,0,16),Position=UDim2.new(0,6,0,24),Parent=row}).TextSize=10
            local impBtn=UIUtils.MakeButton({Text="Import",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,64,0,26),Position=UDim2.new(1,-72,0.5,-13),Parent=row}); impBtn.TextSize=11
            impBtn.MouseButton1Click:Connect(function()
                if self._ctx and self._ctx.emoteSystem then self._ctx.emoteSystem:AddEmoteByID(anim.id,anim.name) end
                UIUtils.Tween(impBtn,{BackgroundColor3=UIUtils.Colors.Success},UIUtils.TweenInfo.Fast); impBtn.Text="✓"
            end)
        end
    end

    function M:_buildTree(root, depth)
        depth = depth or 0; if depth > 6 then return end
        for _,child in ipairs(root:GetChildren()) do
            local isAnim=child:IsA("Animation"); local isScript=child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript")
            local row=Instance.new("TextButton"); row.Size=UDim2.new(1,0,0,22); row.BackgroundColor3=UIUtils.Colors.Surface
            row.BackgroundTransparency=1; row.BorderSizePixel=0
            row.Text=string.rep("  ",depth)..(isAnim and "🎬 " or isScript and "📜 " or "▸ ")..child.Name
            row.TextColor3=isAnim and UIUtils.Colors.Accent or isScript and UIUtils.Colors.Warning or UIUtils.Colors.TextSecondary
            row.Font=UIUtils.Font.Regular; row.TextSize=11; row.TextXAlignment=Enum.TextXAlignment.Left; row.AutoButtonColor=false; row.Parent=self._treeScroll
            row.MouseButton1Click:Connect(function()
                if isAnim then self._previewImg.Image=AssetUtils.GetAnimThumbnail(AnimUtils.NormalizeID(child.AnimationId)); self._previewEmpty.Visible=false end
            end)
            UIUtils.AddHoverEffect(row,UIUtils.Colors.SurfaceAlt,UIUtils.Colors.Surface)
            if #child:GetChildren()>0 then self:_buildTree(child,depth+1) end
        end
    end

    function M:_loadAsset(link)
        local id=AssetUtils.ParseLink(link)
        if not id then UIUtils.Toast(self._frame,"Invalid asset link or ID","error"); return end
        UIUtils.Toast(self._frame,"Loading asset "..id.."...","info",2)
        task.spawn(function()
            local model,err=AssetUtils.LoadModel(id)
            if not model then UIUtils.Toast(self._frame,"Failed: "..(err or "Unknown error"),"error"); return end
            self._loaded=model; model.Parent=workspace
            for _,c in ipairs(self._treeScroll:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
            self._scanData=AnimUtils.ScanForAnimations(model)
            self:_buildTree(model)
            self:_populateScripts(self._scanData.Scripts)
            self:_populateAnimations(self._scanData.AnimationObjects)
            self._previewImg.Image=AssetUtils.GetThumbnailURL(id); self._previewEmpty.Visible=false
            local sc,ac=#self._scanData.Scripts,#self._scanData.AnimationObjects
            if sc>0 or ac>0 then
                self._notifLbl.Text=sc.." scripts | "..ac.." animation objects found"; self._notifBar.Visible=true
            end
            task.delay(0.1,function() if model and model.Parent then model.Parent=nil end end)
        end)
    end

    function M:_clear()
        self._notifBar.Visible=false; self._previewImg.Image=""; self._previewEmpty.Visible=true; self._inputBox.Text=""
        for _,c in ipairs(self._treeScroll:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
        self:_populateScripts({}); self:_populateAnimations({})
    end

    function M:OnActivate() end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: StudioInterface
-- ════════════════════════════════════════════════════════
local StudioInterface = (function()
    local M = {}; M.__index = M

    local TABS = {
        {id="Home",     label="Home",   icon="rbxassetid://7072725342"},
        {id="Packs",    label="Packs",  icon="rbxassetid://7072706620"},
        {id="Emotes",   label="Emotes", icon="rbxassetid://7072726094"},
        {id="Explorer", label="Assets", icon="rbxassetid://7072706514"},
        {id="Editor",   label="Editor", icon="rbxassetid://7072726518"},
    }

    function M.new(screenGui, ctx)
        local self=setmetatable({_gui=screenGui,_ctx=ctx,_activeTab=nil,_tabFrames={},_tabButtons={},_modules={},_visible=false},M)
        self:_build(); return self
    end

    function M:_build()
        local vp=self._gui.AbsoluteSize
        local W=math.min(880,vp.X*0.92); local H=math.min(580,vp.Y*0.88)
        local root=UIUtils.MakeFrame({Name="StudioRoot",Color=UIUtils.Colors.Background,Size=UDim2.new(0,W,0,H),Position=UDim2.new(0.5,-W/2,0.5,-H/2),Parent=self._gui})
        root.Visible=false; UIUtils.MakeCorner(14,root); UIUtils.MakeStroke(root,UIUtils.Colors.Border,1.5); self._root=root

        local titleBar=UIUtils.MakeFrame({Name="TitleBar",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,0,46),Parent=root}); UIUtils.MakeCorner(14,titleBar)
        local tLbl=UIUtils.MakeLabel({Text="  Animation Studio",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(0,220,1,0),Parent=titleBar}); tLbl.TextSize=15
        local stripe=UIUtils.MakeFrame({Color=UIUtils.Colors.Accent,Size=UDim2.new(0,3,0.6,0),Position=UDim2.new(0,0,0.2,0),Parent=titleBar}); UIUtils.MakeCorner(2,stripe)
        local closeBtn=UIUtils.MakeIconButton({Icon="rbxassetid://7072705748",IconColor=UIUtils.Colors.TextMuted,Color=UIUtils.Colors.Background,Size=UDim2.new(0,32,0,32),Position=UDim2.new(1,-40,0.5,-16),Parent=titleBar})
        closeBtn.MouseButton1Click:Connect(function() self:Hide() end); UIUtils.AddHoverEffect(closeBtn,UIUtils.Colors.Danger,UIUtils.Colors.Background)

        local tabBar=UIUtils.MakeFrame({Name="TabBar",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,110,1,-46),Position=UDim2.new(0,0,0,46),Parent=root})
        UIUtils.MakePadding(tabBar,{Top=UDim.new(0,8),Bottom=UDim.new(0,8),Left=UDim.new(0,6),Right=UDim.new(0,6)}); UIUtils.MakeListLayout(tabBar,{Padding=UDim.new(0,4)})
        UIUtils.MakeFrame({Color=UIUtils.Colors.Border,Size=UDim2.new(0,1,1,-46),Position=UDim2.new(0,110,0,46),Parent=root})

        local content=UIUtils.MakeFrame({Name="ContentArea",Color=UIUtils.Colors.Background,Size=UDim2.new(1,-111,1,-46),Position=UDim2.new(0,111,0,46),ClipsDescendants=true,Parent=root}); self._content=content

        for i,tabDef in ipairs(TABS) do
            local tb=Instance.new("TextButton"); tb.Name="Tab_"..tabDef.id; tb.Size=UDim2.new(1,0,0,44)
            tb.BackgroundColor3=UIUtils.Colors.Background; tb.BackgroundTransparency=1; tb.BorderSizePixel=0
            tb.Text=""; tb.LayoutOrder=i; tb.AutoButtonColor=false; UIUtils.MakeCorner(8,tb); tb.Parent=tabBar

            local indicator=UIUtils.MakeFrame({Color=UIUtils.Colors.Accent,Size=UDim2.new(0,3,0.6,0),Position=UDim2.new(0,0,0.2,0),Parent=tb}); UIUtils.MakeCorner(2,indicator); indicator.Visible=false
            local icon=Instance.new("ImageLabel"); icon.Size=UDim2.new(0,18,0,18); icon.Position=UDim2.new(0,10,0.5,-9)
            icon.BackgroundTransparency=1; icon.Image=tabDef.icon; icon.ImageColor3=UIUtils.Colors.TextMuted; icon.Parent=tb
            local lbl=UIUtils.MakeLabel({Text=tabDef.label,Size=UDim2.new(1,-34,1,0),Position=UDim2.new(0,32,0,0),Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextMuted,Parent=tb}); lbl.TextSize=12

            self._tabButtons[tabDef.id]={btn=tb,icon=icon,lbl=lbl,indicator=indicator}
            local tabFrame=UIUtils.MakeFrame({Name="TC_"..tabDef.id,Color=UIUtils.Colors.Background,Size=UDim2.new(1,0,1,0),Parent=content}); tabFrame.Visible=false; self._tabFrames[tabDef.id]=tabFrame

            tb.MouseButton1Click:Connect(function() self:SwitchTab(tabDef.id) end)
            tb.MouseEnter:Connect(function() if self._activeTab~=tabDef.id then UIUtils.Tween(tb,{BackgroundTransparency=0.7},UIUtils.TweenInfo.Fast); UIUtils.Tween(icon,{ImageColor3=UIUtils.Colors.TextSecondary},UIUtils.TweenInfo.Fast) end end)
            tb.MouseLeave:Connect(function() if self._activeTab~=tabDef.id then UIUtils.Tween(tb,{BackgroundTransparency=1},UIUtils.TweenInfo.Fast); UIUtils.Tween(icon,{ImageColor3=UIUtils.Colors.TextMuted},UIUtils.TweenInfo.Fast) end end)
        end

        local statusBar=UIUtils.MakeFrame({Color=UIUtils.Colors.Surface,Size=UDim2.new(1,-111,0,24),Position=UDim2.new(0,111,1,-24),Parent=root}); UIUtils.MakeCorner(8,statusBar)
        local statusLbl=UIUtils.MakeLabel({Text="Ready",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,-8,1,0),Position=UDim2.new(0,8,0,0),Parent=statusBar}); statusLbl.TextSize=11; self._statusLabel=statusLbl

        UIUtils.MakeDraggable(titleBar, root, false)
        self:_initModules()
        self:SwitchTab("Home", true)
    end

    function M:_initModules()
        local ctx=self._ctx
        self._modules.Home     = HomeTab.new(self._tabFrames["Home"],     ctx)
        self._modules.Packs    = PacksTab.new(self._tabFrames["Packs"],   ctx)
        self._modules.Emotes   = EmotesTab.new(self._tabFrames["Emotes"], ctx)
        self._modules.Explorer = ExplorerTab.new(self._tabFrames["Explorer"], ctx)
        ctx.emoteSystem = self._modules.Emotes
    end

    function M:SwitchTab(tabId, skipAnim)
        if self._activeTab==tabId then return end
        for id,els in pairs(self._tabButtons) do
            local active=id==tabId; els.indicator.Visible=active
            UIUtils.Tween(els.btn,{BackgroundTransparency=active and 0 or 1},UIUtils.TweenInfo.Fast)
            UIUtils.Tween(els.icon,{ImageColor3=active and UIUtils.Colors.Accent or UIUtils.Colors.TextMuted},UIUtils.TweenInfo.Fast)
            UIUtils.Tween(els.lbl,{TextColor3=active and UIUtils.Colors.TextPrimary or UIUtils.Colors.TextMuted},UIUtils.TweenInfo.Fast)
            if active then els.btn.BackgroundColor3=UIUtils.Colors.SurfaceAlt end
        end
        if self._activeTab then
            local old=self._tabFrames[self._activeTab]
            if old and not skipAnim then
                UIUtils.Tween(old,{Position=UDim2.new(-0.1,0,0,0)},UIUtils.TweenInfo.Normal,function() old.Visible=false; old.Position=UDim2.new(0,0,0,0) end)
            elseif old then old.Visible=false end
        end
        self._activeTab=tabId
        local newFrame=self._tabFrames[tabId]
        if newFrame then
            if not skipAnim then newFrame.Position=UDim2.new(0.08,0,0,0); newFrame.Visible=true; UIUtils.Tween(newFrame,{Position=UDim2.new(0,0,0,0)},UIUtils.TweenInfo.Normal)
            else newFrame.Position=UDim2.new(0,0,0,0); newFrame.Visible=true end
        end
        local mod=self._modules[tabId]; if mod and mod.OnActivate then mod:OnActivate() end
        self:SetStatus("Tab: "..tabId)
    end

    function M:Show()
        if self._visible then return end; self._visible=true; self._root.Visible=true; self._root.Size=UDim2.new(0,0,0,0); self._root.BackgroundTransparency=1
        local vp=self._gui.AbsoluteSize; local W=math.min(880,vp.X*0.92); local H=math.min(580,vp.Y*0.88)
        self._root.Position=UDim2.new(0.5,-W/2,0.5,-H/2)
        UIUtils.Tween(self._root,{Size=UDim2.new(0,W,0,H),BackgroundTransparency=0},UIUtils.TweenInfo.Spring)
    end

    function M:Hide()
        if not self._visible then return end; self._visible=false
        UIUtils.Tween(self._root,{Size=UDim2.new(0,0,0,0),BackgroundTransparency=1},UIUtils.TweenInfo.Normal,function() self._root.Visible=false end)
    end

    function M:IsVisible() return self._visible end
    function M:SetStatus(msg) if self._statusLabel then self._statusLabel.Text=msg or "Ready" end end
    function M:Notify(msg,kind) UIUtils.Toast(self._gui,msg,kind or "info",3) end
    function M:Confirm(title,body,cb)
        UIUtils.Confirm(self._gui,{Title=title,Body=body,Buttons={{Text="Save",Kind="primary",Value="save",Order=1},{Text="Discard",Kind="danger",Value="discard",Order=2},{Text="Cancel",Kind="ghost",Value="cancel",Order=3}}},cb)
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: EditorEnvironment
-- ════════════════════════════════════════════════════════
local EditorEnvironment = (function()
    local M = {}; M.__index = M

    local ENV_POS     = Vector3.new(0,5000,0)
    local ROOM_SIZE   = Vector3.new(50,30,50)
    local FLOOR_COLOR = Color3.fromRGB(16,16,24)
    local GRID_COLOR  = Color3.fromRGB(30,30,46)
    local BG_COLOR    = Color3.fromRGB(8,8,14)
    local SPOT_COLOR  = Color3.fromRGB(255,245,220)

    function M.new()
        return setmetatable({_parts={},_cloneChar=nil,_camera=workspace.CurrentCamera,
            _origCamCF=nil,_origCamType=nil,_active=false,_connection=nil,_onReady=nil,_folder=nil},M)
    end

    function M:Build(character)
        if self._active then return end; self._active=true
        self._origCamCF=self._camera.CFrame; self._origCamType=self._camera.CameraType
        local folder=Instance.new("Folder"); folder.Name="AnimStudioEnv"; folder.Parent=workspace; self._folder=folder
        self:_buildRoom(folder)
        if character then
            self._cloneChar=AssetUtils.CloneCharacter(character,folder)
            local root=self._cloneChar:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame=CFrame.new(ENV_POS+Vector3.new(0,3,0)) end
        end
        self:_transitionCamera()
        if self._onReady then task.delay(0.8,self._onReady) end
    end

    function M:_buildRoom(folder)
        local cx,cy,cz = ENV_POS.X,ENV_POS.Y,ENV_POS.Z
        self:_p(folder,{Vector3.new(ROOM_SIZE.X,1,ROOM_SIZE.Z),CFrame.new(cx,cy,cz),FLOOR_COLOR,"StudioFloor"})
        local step=4
        for i=-math.floor(ROOM_SIZE.X/2/step),math.floor(ROOM_SIZE.X/2/step) do
            self:_p(folder,{Vector3.new(0.05,0.05,ROOM_SIZE.Z),CFrame.new(cx+i*step,cy+0.55,cz),GRID_COLOR,"GridX"})
        end
        for i=-math.floor(ROOM_SIZE.Z/2/step),math.floor(ROOM_SIZE.Z/2/step) do
            self:_p(folder,{Vector3.new(ROOM_SIZE.X,0.05,0.05),CFrame.new(cx,cy+0.55,cz+i*step),GRID_COLOR,"GridZ"})
        end
        self:_p(folder,{Vector3.new(ROOM_SIZE.X,1,ROOM_SIZE.Z),CFrame.new(cx,cy+ROOM_SIZE.Y,cz),BG_COLOR,"Ceiling"})
        for _,w in ipairs({
            {Vector3.new(1,ROOM_SIZE.Y,ROOM_SIZE.Z),Vector3.new(cx-ROOM_SIZE.X/2,cy+ROOM_SIZE.Y/2,cz)},
            {Vector3.new(1,ROOM_SIZE.Y,ROOM_SIZE.Z),Vector3.new(cx+ROOM_SIZE.X/2,cy+ROOM_SIZE.Y/2,cz)},
            {Vector3.new(ROOM_SIZE.X,ROOM_SIZE.Y,1),Vector3.new(cx,cy+ROOM_SIZE.Y/2,cz-ROOM_SIZE.Z/2)},
            {Vector3.new(ROOM_SIZE.X,ROOM_SIZE.Y,1),Vector3.new(cx,cy+ROOM_SIZE.Y/2,cz+ROOM_SIZE.Z/2)},
        }) do self:_p(folder,{w[1],CFrame.new(w[2]),BG_COLOR,"Wall"}) end
        for i,pos in ipairs({Vector3.new(cx-6,cy+ROOM_SIZE.Y-2,cz-6),Vector3.new(cx+6,cy+ROOM_SIZE.Y-2,cz-6),Vector3.new(cx,cy+ROOM_SIZE.Y-2,cz+8)}) do
            local sp=self:_p(folder,{Vector3.new(0.5,0.5,0.5),CFrame.new(pos)*CFrame.Angles(math.rad(90),0,0),Color3.fromRGB(20,20,30),"SpotPart"})
            local sl=Instance.new("SpotLight"); sl.Angle=45; sl.Brightness=2.5; sl.Color=SPOT_COLOR; sl.Range=30; sl.Face=Enum.NormalId.Bottom; sl.Shadows=true; sl.Parent=sp
        end
        local rim=self:_p(folder,{Vector3.new(0.3,0.3,0.3),CFrame.new(cx-10,cy+8,cz+10),Color3.fromRGB(10,10,20),"RimLight"})
        local pl=Instance.new("PointLight"); pl.Color=Color3.fromRGB(80,100,255); pl.Brightness=3; pl.Range=25; pl.Parent=rim
    end

    function M:_p(parent,data)
        local p=Instance.new("Part"); p.Size=data[1]; p.CFrame=data[2]; p.Color=data[3]
        p.Anchored=true; p.CanCollide=false; p.CastShadow=false; p.Name=data[4] or "Part"; p.Parent=parent
        table.insert(self._parts,p); return p
    end

    function M:_transitionCamera()
        self._camera.CameraType=Enum.CameraType.Scriptable
        local cx,cy,cz=ENV_POS.X,ENV_POS.Y,ENV_POS.Z
        local targetCF=CFrame.new(Vector3.new(cx,cy+6,cz+10),Vector3.new(cx,cy+3,cz))
        local startCF=self._camera.CFrame; local t=0
        self._connection=RunService.RenderStepped:Connect(function(dt)
            t=t+dt; local a=math.min(t/0.9,1); a=a*a*(3-2*a)
            self._camera.CFrame=startCF:Lerp(targetCF,a)
            if a>=1 then self._connection:Disconnect(); self._connection=nil end
        end)
    end

    function M:StartOrbitCamera()
        local pivot=ENV_POS+Vector3.new(0,4,0); local dist,yaw,pitch=10,0,20
        self._orbitConn=RunService.RenderStepped:Connect(function()
            local cf=CFrame.new(pivot)*CFrame.Angles(0,math.rad(yaw),0)*CFrame.Angles(math.rad(-pitch),0,0)*CFrame.new(0,0,dist)
            self._camera.CFrame=CFrame.new(cf.Position,pivot)
        end)
        return {SetYaw=function(v)yaw=v end,SetPitch=function(v)pitch=math.clamp(v,-80,80)end,SetDist=function(v)dist=math.clamp(v,3,30)end,GetYaw=function()return yaw end,GetPitch=function()return pitch end,GetDist=function()return dist end}
    end

    function M:StopOrbitCamera()
        if self._orbitConn then self._orbitConn:Disconnect(); self._orbitConn=nil end
    end

    function M:GetCloneCharacter() return self._cloneChar end
    function M:GetCloneHumanoid()  return self._cloneChar and self._cloneChar:FindFirstChildOfClass("Humanoid") end
    function M:OnReady(fn) self._onReady=fn end

    function M:Destroy()
        if not self._active then return end; self._active=false
        if self._connection then self._connection:Disconnect(); self._connection=nil end
        self:StopOrbitCamera()
        if self._folder then self._folder:Destroy(); self._folder=nil end
        self._parts={}; self._cloneChar=nil
        if self._origCamType then self._camera.CameraType=self._origCamType end
        if self._origCamCF then TweenService:Create(self._camera,TweenInfo.new(0.7,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=self._origCamCF}):Play() end
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: TimelineSystem
-- ════════════════════════════════════════════════════════
local TimelineSystem = (function()
    local M = {}; M.__index = M
    local TRACK_H=28; local HDR_W=100; local PPX=80

    function M.new(frame, undoRedo, ctx)
        local self=setmetatable({_frame=frame,_undoRedo=undoRedo,_ctx=ctx,_duration=1,_time=0,_playing=false,
            _looping=false,_speed=1,_tracks={},_selected={},_playConn=nil,_onTimeChange=nil,_onKeyChange=nil,_scrubbing=false},M)
        self:_build(); return self
    end

    function M:_build()
        local ctrl=UIUtils.MakeFrame({Name="Ctrl",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,0,44),Parent=self._frame})
        UIUtils.MakePadding(ctrl,{Top=UDim.new(0,5),Bottom=UDim.new(0,5),Left=UDim.new(0,8),Right=UDim.new(0,8)})
        UIUtils.MakeListLayout(ctrl,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6)})

        local function cBtn(txt,fn)
            local b=UIUtils.MakeButton({Text=txt,Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,34,0,30),Parent=ctrl}); b.TextSize=14; b.MouseButton1Click:Connect(fn); return b
        end

        cBtn("⏮",function() self:SetTime(0) end)
        local playBtn=cBtn("▶",function() if self._playing then self:Pause() else self:Play() end end); self._playBtn=playBtn
        cBtn("⏹",function() self:Stop() end)
        local loopBtn=cBtn("↺",function() self._looping=not self._looping; UIUtils.Tween(loopBtn,{BackgroundColor3=self._looping and UIUtils.Colors.Accent or UIUtils.Colors.SurfaceAlt},UIUtils.TweenInfo.Fast) end)
        UIUtils.MakeFrame({Color=UIUtils.Colors.Border,Size=UDim2.new(0,1,0.7,0),Parent=ctrl})
        local akBtn=cBtn("+KF",function() self:AddKeyframeAtCurrentTime() end); akBtn.TextSize=11
        local dkBtn=cBtn("✕KF",function() self:DeleteSelectedKeyframes() end); dkBtn.TextSize=11
        UIUtils.MakeFrame({Color=UIUtils.Colors.Border,Size=UDim2.new(0,1,0.7,0),Parent=ctrl})
        local timeLbl=UIUtils.MakeLabel({Text="0.000s",Font=UIUtils.Font.Mono,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(0,60,1,0),XAlign=Enum.TextXAlignment.Center,Parent=ctrl}); timeLbl.TextSize=13; self._timeLabel=timeLbl
        UIUtils.MakeLabel({Text="/",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(0,10,1,0),XAlign=Enum.TextXAlignment.Center,Parent=ctrl}).TextSize=13
        local _,durBox=UIUtils.MakeInput({Default="1.000",Size=UDim2.new(0,60,0,28),Parent=ctrl}); durBox.Parent.LayoutOrder=99; self._durBox=durBox
        durBox.FocusLost:Connect(function() local v=tonumber(durBox.Text); if v then self._duration=math.clamp(v,0.1,30); durBox.Text=string.format("%.3f",self._duration); self:_rebuildRuler() end end)
        UIUtils.MakeLabel({Text="Speed:",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(0,44,1,0),XAlign=Enum.TextXAlignment.Right,Parent=ctrl}).TextSize=11
        local _,speedBox=UIUtils.MakeInput({Default="1.0",Size=UDim2.new(0,44,0,28),Parent=ctrl}); speedBox.Parent.LayoutOrder=100; self._speedBox=speedBox
        speedBox.FocusLost:Connect(function() local v=tonumber(speedBox.Text); if v then self._speed=math.clamp(v,0.1,10); speedBox.Text=string.format("%.1f",self._speed) end end)

        local area=UIUtils.MakeFrame({Name="TimelineArea",Color=UIUtils.Colors.Background,Size=UDim2.new(1,0,1,-44),Position=UDim2.new(0,0,0,44),ClipsDescendants=true,Parent=self._frame})
        local hdrs=UIUtils.MakeScrollFrame({Name="Headers",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,HDR_W,1,0),AutoCanvas=Enum.AutomaticSize.Y,ScrollWidth=0,Parent=area})
        UIUtils.MakeListLayout(hdrs,{Padding=UDim.new(0,1)}); self._headers=hdrs
        local trackArea=UIUtils.MakeScrollFrame({Name="TrackArea",Color=UIUtils.Colors.Background,Size=UDim2.new(1,-HDR_W,1,0),Position=UDim2.new(0,HDR_W,0,0),Direction=Enum.ScrollingDirection.X,AutoCanvas=Enum.AutomaticSize.None,Parent=area})
        trackArea.CanvasSize=UDim2.new(0,self._duration*PPX+100,0,0); self._trackArea=trackArea
        local ruler=UIUtils.MakeFrame({Name="Ruler",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,20),Parent=trackArea}); self._ruler=ruler; self:_buildRuler()
        local rows=UIUtils.MakeFrame({Name="Rows",Color=UIUtils.Colors.Background,Transparency=1,Size=UDim2.new(1,0,1,-20),Position=UDim2.new(0,0,0,20),Parent=trackArea})
        UIUtils.MakeListLayout(rows,{Padding=UDim.new(0,1)}); self._rows=rows
        local ph=UIUtils.MakeFrame({Name="Playhead",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,2,1,0),Parent=trackArea}); ph.ZIndex=10; self._playhead=ph
        local tip=UIUtils.MakeFrame({Color=UIUtils.Colors.Accent,Size=UDim2.new(0,10,0,10),Position=UDim2.new(0,-4,0,0),Parent=ph}); UIUtils.MakeCorner(3,tip)

        local rulerBtn=Instance.new("TextButton"); rulerBtn.Size=UDim2.new(1,0,1,0); rulerBtn.BackgroundTransparency=1; rulerBtn.Text=""; rulerBtn.Parent=ruler
        rulerBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then self._scrubbing=true end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if not self._scrubbing then return end
            local relX=inp.Position.X-trackArea.AbsolutePosition.X+trackArea.CanvasPosition.X
            self:SetTime(math.clamp(relX/PPX,0,self._duration))
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then self._scrubbing=false end
        end)
    end

    function M:_buildRuler()
        for _,c in ipairs(self._ruler:GetChildren()) do if not c:IsA("TextButton") then c:Destroy() end end
        local t=0
        while t<=self._duration+0.25 do
            local x=t*PPX; local big=math.abs(t-math.round(t))<0.01
            UIUtils.MakeFrame({Color=big and UIUtils.Colors.TextMuted or UIUtils.Colors.Border,Size=UDim2.new(0,1,0,big and 14 or 8),Position=UDim2.new(0,x,1,big and -14 or -8),Parent=self._ruler})
            if big then UIUtils.MakeLabel({Text=string.format("%.0fs",t),Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(0,28,0,12),Position=UDim2.new(0,x+2,0,0),Parent=self._ruler}).TextSize=9 end
            t=t+0.25
        end
    end

    function M:_rebuildRuler() self._trackArea.CanvasSize=UDim2.new(0,self._duration*PPX+100,0,0); self:_buildRuler() end

    function M:AddTrack(partName)
        if self._tracks[partName] then return end
        local hdr=UIUtils.MakeFrame({Name="H_"..partName,Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,0,TRACK_H),Parent=self._headers})
        UIUtils.MakeLabel({Text=partName,Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextSecondary,Frame=UDim2.new(1,-6,1,0),Position=UDim2.new(0,4,0,0),Parent=hdr}).TextSize=11
        local row=UIUtils.MakeFrame({Name="R_"..partName,Color=UIUtils.Colors.Background,Size=UDim2.new(1,0,0,TRACK_H),Parent=self._rows}); UIUtils.MakeStroke(row,UIUtils.Colors.Border,0.5)
        self._tracks[partName]={keyframes={},header=hdr,row=row}
    end

    function M:_makeKFDiamond(row,time,partName,kfData)
        local x=time*PPX; local S=10
        local kff=UIUtils.MakeFrame({Color=UIUtils.Colors.Accent,Size=UDim2.new(0,S,0,S),Position=UDim2.new(0,x-S/2,0.5,-S/2),Parent=row}); kff.Rotation=45; kff.ZIndex=5
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,S+8,0,S+8); btn.Position=UDim2.new(0,-4,0,-4)
        btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=6; btn.Parent=kff
        btn.MouseEnter:Connect(function() UIUtils.Tween(kff,{BackgroundColor3=UIUtils.Colors.Gold,Size=UDim2.new(0,13,0,13)},UIUtils.TweenInfo.Fast) end)
        btn.MouseLeave:Connect(function() UIUtils.Tween(kff,{BackgroundColor3=kfData.selected and UIUtils.Colors.Gold or UIUtils.Colors.Accent,Size=UDim2.new(0,S,0,S)},UIUtils.TweenInfo.Fast) end)
        btn.MouseButton1Click:Connect(function()
            kfData.selected=not kfData.selected
            UIUtils.Tween(kff,{BackgroundColor3=kfData.selected and UIUtils.Colors.Gold or UIUtils.Colors.Accent},UIUtils.TweenInfo.Fast)
            if kfData.selected then self._selected[kfData]=true else self._selected[kfData]=nil end
            self:SetTime(time)
        end)
        kfData.frame=kff
    end

    function M:AddKeyframeAtCurrentTime(cf)
        for partName,track in pairs(self._tracks) do
            local kfData={time=self._time,cf=cf or CFrame.new(),selected=false,frame=nil}
            table.insert(track.keyframes,kfData); table.sort(track.keyframes,function(a,b)return a.time<b.time end)
            self:_makeKFDiamond(track.row,self._time,partName,kfData)
        end
        if self._onKeyChange then self._onKeyChange() end
    end

    function M:AddKeyframe(partName,time,cf)
        if not self._tracks[partName] then self:AddTrack(partName) end
        local track=self._tracks[partName]
        local kfData={time=time,cf=cf or CFrame.new(),selected=false,frame=nil}
        table.insert(track.keyframes,kfData); table.sort(track.keyframes,function(a,b)return a.time<b.time end)
        self:_makeKFDiamond(track.row,time,partName,kfData); if self._onKeyChange then self._onKeyChange() end; return kfData
    end

    function M:DeleteSelectedKeyframes()
        for kfData in pairs(self._selected) do
            for _,track in pairs(self._tracks) do
                for i,kf in ipairs(track.keyframes) do if kf==kfData then table.remove(track.keyframes,i); if kf.frame then kf.frame:Destroy() end break end end
            end
        end
        self._selected={}; if self._onKeyChange then self._onKeyChange() end
    end

    function M:Play()
        if self._playing then return end; self._playing=true; self._playBtn.Text="⏸"
        self._playConn=RunService.Heartbeat:Connect(function(dt)
            if not self._playing then return end
            self._time=self._time+dt*self._speed
            if self._time>=self._duration then if self._looping then self._time=0 else self._time=self._duration; self:Pause() end end
            self:_updatePlayhead(); if self._onTimeChange then self._onTimeChange(self._time) end
        end)
    end

    function M:Pause() self._playing=false; self._playBtn.Text="▶"; if self._playConn then self._playConn:Disconnect(); self._playConn=nil end end
    function M:Stop() self:Pause(); self:SetTime(0) end
    function M:SetTime(t) self._time=math.clamp(t,0,self._duration); self:_updatePlayhead(); if self._onTimeChange then self._onTimeChange(self._time) end end
    function M:_updatePlayhead() self._playhead.Position=UDim2.new(0,self._time*PPX,0,0); self._timeLabel.Text=string.format("%.3fs",self._time) end
    function M:OnTimeChange(fn) self._onTimeChange=fn end
    function M:OnKeyChange(fn)  self._onKeyChange=fn end

    function M:Serialize()
        local out={duration=self._duration,tracks={}}
        for pn,track in pairs(self._tracks) do
            local kfs={}; for _,kf in ipairs(track.keyframes) do table.insert(kfs,{time=kf.time,cf={kf.cf:GetComponents()}}) end
            out.tracks[pn]=kfs
        end
        return out
    end

    function M:Deserialize(data)
        if not data then return end; self._duration=data.duration or 1; self._durBox.Text=string.format("%.3f",self._duration); self:_rebuildRuler()
        for pn,kfs in pairs(data.tracks or {}) do for _,kf in ipairs(kfs) do self:AddKeyframe(pn,kf.time,CFrame.new(table.unpack(kf.cf or {}))) end end
    end

    function M:Destroy() self:Stop() end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: KeyframeEditor
-- ════════════════════════════════════════════════════════
local KeyframeEditor = (function()
    local M = {}; M.__index = M

    M.Tool = {SELECT="Select",MOVE="Move",ROTATE="Rotate",ATTACH="Attach"}

    function M.new(editorEnv, timeline, undoRedo, screenGui, ctx)
        local self=setmetatable({_env=editorEnv,_timeline=timeline,_undoRedo=undoRedo,_gui=screenGui,_ctx=ctx,
            _tool=M.Tool.SELECT,_selected=nil,_motors={},_gizmos={},_connections={},_toolBtns={},_rotSliders={}},M)
        self:_buildToolPanel(); self:_buildPropsPanel(); self:_setupPicker(); return self
    end

    function M:_buildToolPanel()
        local panel=UIUtils.MakeFrame({Name="ToolPanel",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,48,0,220),Position=UDim2.new(0,8,0.5,-110),Parent=self._gui})
        panel.ZIndex=20; UIUtils.MakeCorner(10,panel); UIUtils.MakeStroke(panel,UIUtils.Colors.Border,1)
        UIUtils.MakePadding(panel,{Top=UDim.new(0,6),Bottom=UDim.new(0,6),Left=UDim.new(0,6),Right=UDim.new(0,6)}); UIUtils.MakeListLayout(panel,{Padding=UDim.new(0,4)})
        for _,t in ipairs({{M.Tool.SELECT,"⊕"},{M.Tool.MOVE,"⊹"},{M.Tool.ROTATE,"↻"},{M.Tool.ATTACH,"⚓"}}) do
            local btn=UIUtils.MakeButton({Text=t[2],Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,34),Parent=panel}); btn.TextSize=18; self._toolBtns[t[1]]=btn
            btn.MouseButton1Click:Connect(function() self:SetTool(t[1]) end)
        end
        UIUtils.MakeDivider(panel,0)
        local undoBtn=UIUtils.MakeButton({Text="↩",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,34),Parent=panel}); undoBtn.TextSize=18
        undoBtn.MouseButton1Click:Connect(function() if self._undoRedo then self._undoRedo:Undo() end end)
        local redoBtn=UIUtils.MakeButton({Text="↪",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,34),Parent=panel}); redoBtn.TextSize=18
        redoBtn.MouseButton1Click:Connect(function() if self._undoRedo then self._undoRedo:Redo() end end)
    end

    function M:_buildPropsPanel()
        local panel=UIUtils.MakeFrame({Name="PropsPanel",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,200,0,320),Position=UDim2.new(1,-208,0,8),Parent=self._gui})
        panel.ZIndex=20; UIUtils.MakeCorner(10,panel); UIUtils.MakeStroke(panel,UIUtils.Colors.Border,1)
        UIUtils.MakePadding(panel,{Top=UDim.new(0,8),Bottom=UDim.new(0,8),Left=UDim.new(0,8),Right=UDim.new(0,8)})
        UIUtils.MakeLabel({Text="PROPERTIES",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,20),Parent=panel}).TextSize=10
        local scroll=UIUtils.MakeScrollFrame({Name="PS",Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,1,-24),Position=UDim2.new(0,0,0,24),AutoCanvas=Enum.AutomaticSize.Y,Parent=panel})
        UIUtils.MakeListLayout(scroll,{Padding=UDim.new(0,4)}); UIUtils.MakePadding(scroll,{Top=UDim.new(0,4),Left=UDim.new(0,2),Right=UDim.new(0,2),Bottom=UDim.new(0,4)})
        self._selLabel=UIUtils.MakeLabel({Text="Nothing selected",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,30),Wrap=true,XAlign=Enum.TextXAlignment.Center,Parent=scroll}); self._selLabel.TextSize=12
        for _,axis in ipairs({"X","Y","Z"}) do
            local row=UIUtils.MakeFrame({Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,42),Parent=scroll}); UIUtils.MakeCorner(6,row)
            UIUtils.MakeLabel({Text=axis.." Rotation",Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextSecondary,Frame=UDim2.new(1,0,0,16),Position=UDim2.new(0,6,0,4),Parent=row}).TextSize=11
            local slider=Instance.new("Frame"); slider.Size=UDim2.new(1,-12,0,16); slider.Position=UDim2.new(0,6,0,22)
            slider.BackgroundColor3=UIUtils.Colors.Background; slider.BorderSizePixel=0; UIUtils.MakeCorner(4,slider); slider.Parent=row
            local fill=UIUtils.MakeFrame({Color=UIUtils.Colors.Accent,Size=UDim2.new(0.5,0,1,0),Parent=slider}); UIUtils.MakeCorner(4,fill)
            local thumb=Instance.new("Frame"); thumb.Size=UDim2.new(0,14,0,14); thumb.Position=UDim2.new(0.5,-7,0.5,-7)
            thumb.BackgroundColor3=UIUtils.Colors.TextPrimary; thumb.BorderSizePixel=0; UIUtils.MakeCorner(7,thumb); thumb.Parent=slider
            self._rotSliders[axis]={slider=slider,fill=fill,thumb=thumb,value=0}
            local dragging=false; local sb=Instance.new("TextButton"); sb.Size=UDim2.new(1,0,1,0); sb.BackgroundTransparency=1; sb.Text=""; sb.Parent=slider
            sb.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=true end end)
            UserInputService.InputChanged:Connect(function(inp)
                if not dragging then return end
                local relX=inp.Position.X-slider.AbsolutePosition.X; local frac=math.clamp(relX/slider.AbsoluteSize.X,0,1)
                local deg=(frac-0.5)*360; self._rotSliders[axis].value=deg; fill.Size=UDim2.new(frac,0,1,0); thumb.Position=UDim2.new(frac,-7,0.5,-7)
                self:_applySliders()
            end)
            UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
        end
        local addKFBtn=UIUtils.MakeButton({Text="+ Add Keyframe Here",Color=UIUtils.Colors.Accent,Size=UDim2.new(1,0,0,32),Parent=scroll}); addKFBtn.TextSize=12
        addKFBtn.MouseButton1Click:Connect(function() if self._timeline then self._timeline:AddKeyframeAtCurrentTime(self:_getCurrentCF()) end end)
    end

    function M:_setupPicker()
        local camera=workspace.CurrentCamera
        local conn=UserInputService.InputBegan:Connect(function(inp,processed)
            if processed then return end
            if inp.UserInputType~=Enum.UserInputType.MouseButton1 and inp.UserInputType~=Enum.UserInputType.Touch then return end
            local unitRay=camera:ScreenPointToRay(inp.Position.X,inp.Position.Y)
            local result=workspace:Raycast(unitRay.Origin,unitRay.Direction*100)
            if result and result.Instance then
                local hit=result.Instance; local cloneChar=self._env:GetCloneCharacter()
                if cloneChar then
                    local ancestor=hit
                    while ancestor and ancestor~=cloneChar do ancestor=ancestor.Parent end
                    if ancestor==cloneChar then self:_selectPart(hit) end
                end
            end
        end)
        table.insert(self._connections, conn)
    end

    function M:_selectPart(part)
        self._selected=part.Name; self._selLabel.Text="Selected: "..part.Name
        self:_clearGizmos(); self:_showGizmos(part)
        local cloneChar=self._env:GetCloneCharacter()
        if cloneChar then
            local motors=AnimUtils.GetMotor6Ds(cloneChar); local motor=motors[part.Name]
            if motor then self:_updateSliders(AnimUtils.CFrameToEuler(motor.C0)) end
        end
    end

    function M:_showGizmos(part)
        if self._tool==M.Tool.SELECT then return end
        local cloneChar=self._env:GetCloneCharacter(); if not cloneChar then return end
        local targetPart=cloneChar:FindFirstChild(self._selected); if not targetPart or not targetPart:IsA("BasePart") then return end
        for axis,color in pairs({X=Color3.fromRGB(220,60,60),Y=Color3.fromRGB(60,200,60),Z=Color3.fromRGB(60,60,220)}) do
            local handle=Instance.new("Part"); handle.Name="Gizmo_"..axis
            handle.Size=Vector3.new(axis=="X" and 2 or 0.1,axis=="Y" and 2 or 0.1,axis=="Z" and 2 or 0.1)
            handle.CFrame=targetPart.CFrame+(axis=="X" and Vector3.new(1.2,0,0) or axis=="Y" and Vector3.new(0,1.2,0) or Vector3.new(0,0,1.2))
            handle.Color=color; handle.Material=Enum.Material.Neon; handle.Anchored=true; handle.CanCollide=false; handle.CastShadow=false
            handle.Parent=self._env._folder; table.insert(self._gizmos,handle)
        end
    end

    function M:_clearGizmos() for _,g in ipairs(self._gizmos) do if g and g.Parent then g:Destroy() end end; self._gizmos={} end

    function M:SetTool(toolId)
        self._tool=toolId
        for id,btn in pairs(self._toolBtns) do UIUtils.Tween(btn,{BackgroundColor3=id==toolId and UIUtils.Colors.Accent or UIUtils.Colors.SurfaceAlt},UIUtils.TweenInfo.Fast) end
        self:_clearGizmos(); if self._selected then
            local cloneChar=self._env:GetCloneCharacter()
            if cloneChar then local p=cloneChar:FindFirstChild(self._selected); if p then self:_showGizmos(p) end end
        end
    end

    function M:_applySliders()
        local cloneChar=self._env:GetCloneCharacter(); if not cloneChar or not self._selected then return end
        local motors=AnimUtils.GetMotor6Ds(cloneChar); local motor=motors[self._selected]; if not motor then return end
        local rx=math.rad(self._rotSliders.X.value); local ry=math.rad(self._rotSliders.Y.value); local rz=math.rad(self._rotSliders.Z.value)
        local oldC0=motor.C0; local newC0=CFrame.new(oldC0.Position)*CFrame.Angles(rx,ry,rz)
        if self._undoRedo then self._undoRedo:PushMotorChange(motor,oldC0,newC0) end; motor.C0=newC0
    end

    function M:_updateSliders(euler)
        for _,axis in ipairs({"X","Y","Z"}) do
            local s=self._rotSliders[axis]; if not s then continue end
            local deg=euler[axis] or 0; local frac=(deg/360)+0.5
            s.value=deg; s.fill.Size=UDim2.new(frac,0,1,0); s.thumb.Position=UDim2.new(frac,-7,0.5,-7)
        end
    end

    function M:_getCurrentCF()
        local cloneChar=self._env:GetCloneCharacter(); if not cloneChar or not self._selected then return CFrame.new() end
        local motors=AnimUtils.GetMotor6Ds(cloneChar); local motor=motors[self._selected]; return motor and motor.C0 or CFrame.new()
    end

    function M:LoadCharacter()
        local cloneChar=self._env:GetCloneCharacter(); if not cloneChar or not self._timeline then return end
        local motors=AnimUtils.GetMotor6Ds(cloneChar)
        for name in pairs(motors) do self._motors[name]=motors[name]; self._timeline:AddTrack(name) end
    end

    function M:Destroy()
        self:_clearGizmos()
        for _,c in ipairs(self._connections) do c:Disconnect() end; self._connections={}
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: GroupAttachment
-- ════════════════════════════════════════════════════════
local GroupAttachment = (function()
    local M = {}; M.__index = M

    function M.new(editorEnv, undoRedo, screenGui, ctx)
        local self=setmetatable({_env=editorEnv,_undoRedo=undoRedo,_gui=screenGui,_ctx=ctx,_groups={},_attached={},_nextGID=1,_mode="Attach",_modeBtns={}},M)
        self:_build(); return self
    end

    function M:_build()
        local panel=UIUtils.MakeFrame({Name="AttachPanel",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,220,0,280),Position=UDim2.new(1,-232,0,240),Parent=self._gui})
        panel.ZIndex=20; UIUtils.MakeCorner(10,panel); UIUtils.MakeStroke(panel,UIUtils.Colors.Border,1)
        UIUtils.MakePadding(panel,{Top=UDim.new(0,8),Bottom=UDim.new(0,8),Left=UDim.new(0,8),Right=UDim.new(0,8)})
        UIUtils.MakeLabel({Text="ACCESSORIES & GROUPS",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,18),Parent=panel}).TextSize=9
        local modeRow=UIUtils.MakeFrame({Color=UIUtils.Colors.Background,Transparency=1,Size=UDim2.new(1,0,0,30),Position=UDim2.new(0,0,0,22),Parent=panel})
        UIUtils.MakeListLayout(modeRow,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4)})
        for _,mode in ipairs({"Attach","Group","Lock"}) do
            local btn=UIUtils.MakeButton({Text=mode,Color=mode=="Attach" and UIUtils.Colors.Accent or UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,62,0,26),Parent=modeRow}); btn.TextSize=11; self._modeBtns[mode]=btn
            btn.MouseButton1Click:Connect(function() self:SetMode(mode) end)
        end
        UIUtils.MakeLabel({Text="Attach to bone:",Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextSecondary,Frame=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,0,58),Parent=panel}).TextSize=11
        local _,boneBox=UIUtils.MakeInput({Placeholder="e.g. RightHand",Size=UDim2.new(1,0,0,30),Position=UDim2.new(0,0,0,76),Parent=panel}); self._boneBox=boneBox
        UIUtils.MakeLabel({Text="Position Offset (X Y Z):",Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextSecondary,Frame=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,0,112),Parent=panel}).TextSize=11
        self._offsetInputs={}
        for i,ax in ipairs({"X","Y","Z"}) do
            UIUtils.MakeLabel({Text=ax,Font=UIUtils.Font.Bold,Color=UIUtils.Colors.Accent,Frame=UDim2.new(0,14,0,28),Position=UDim2.new(0,(i-1)*64,0,130),Parent=panel}).TextSize=12
            local _,inp=UIUtils.MakeInput({Default="0",Size=UDim2.new(0,50,0,28),Position=UDim2.new(0,14+(i-1)*64,0,130),Parent=panel}); inp.Parent.Size=UDim2.new(0,50,0,28); self._offsetInputs[ax]=inp
        end
        local actBtn=UIUtils.MakeButton({Text="Attach Part",Color=UIUtils.Colors.Accent,Size=UDim2.new(1,0,0,32),Position=UDim2.new(0,0,0,168),Parent=panel}); actBtn.TextSize=13; self._actionBtn=actBtn
        actBtn.MouseButton1Click:Connect(function()
            if self._mode=="Attach" then self:_attachSelected() elseif self._mode=="Group" then self:_groupSelected() end
        end)
        UIUtils.MakeLabel({Text="GROUPS",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,0,208),Parent=panel}).TextSize=9
        local gScroll=UIUtils.MakeScrollFrame({Name="GS",Color=UIUtils.Colors.Background,Size=UDim2.new(1,0,0,50),Position=UDim2.new(0,0,0,226),AutoCanvas=Enum.AutomaticSize.Y,Parent=panel})
        UIUtils.MakeListLayout(gScroll,{Padding=UDim.new(0,3)}); UIUtils.MakePadding(gScroll,{Top=UDim.new(0,3),Left=UDim.new(0,3),Right=UDim.new(0,3),Bottom=UDim.new(0,3)}); self._groupScroll=gScroll
    end

    function M:SetMode(mode)
        self._mode=mode
        for id,btn in pairs(self._modeBtns) do UIUtils.Tween(btn,{BackgroundColor3=id==mode and UIUtils.Colors.Accent or UIUtils.Colors.SurfaceAlt},UIUtils.TweenInfo.Fast) end
        self._actionBtn.Text=mode=="Attach" and "Attach Part" or mode=="Group" and "Create Group" or "Lock Selection"
    end

    function M:_attachSelected()
        local cloneChar=self._env:GetCloneCharacter(); if not cloneChar then return end
        local boneName=self._boneBox.Text; local bone=cloneChar:FindFirstChild(boneName)
        if not bone then UIUtils.Toast(self._gui,"Bone not found: "..boneName,"error"); return end
        local ox=tonumber(self._offsetInputs.X.Text) or 0; local oy=tonumber(self._offsetInputs.Y.Text) or 0; local oz=tonumber(self._offsetInputs.Z.Text) or 0
        local offset=CFrame.new(ox,oy,oz)
        for _,acc in ipairs(cloneChar:GetChildren()) do
            if acc:IsA("Accessory") or acc:IsA("Tool") then
                local handle=acc:FindFirstChild("Handle")
                if handle then
                    local oldParent=acc.Parent; local oldCF=handle.CFrame; local newCF=bone.CFrame*offset
                    if self._undoRedo then self._undoRedo:PushAttach(acc,oldParent,bone,oldCF,newCF) end
                    local weld=Instance.new("WeldConstraint"); weld.Part0=bone; weld.Part1=handle; weld.Parent=handle; handle.CFrame=newCF
                    self._attached[acc.Name]={target=boneName,offset=offset,weld=weld}
                    UIUtils.Toast(self._gui,"Attached "..acc.Name.." to "..boneName,"success")
                end
            end
        end
    end

    function M:_groupSelected()
        local id="Group_"..self._nextGID; self._nextGID=self._nextGID+1; self._groups[id]={parts={},locked=false}
        local row=UIUtils.MakeFrame({Name=id,Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(1,0,0,26),Parent=self._groupScroll}); UIUtils.MakeCorner(5,row)
        UIUtils.MakeLabel({Text=id,Font=UIUtils.Font.Medium,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(1,-60,1,0),Position=UDim2.new(0,6,0,0),Parent=row}).TextSize=11
        local lBtn=UIUtils.MakeButton({Text="🔒",Color=UIUtils.Colors.Surface,Size=UDim2.new(0,24,0,22),Position=UDim2.new(1,-54,0.5,-11),Parent=row}); lBtn.TextSize=10
        lBtn.MouseButton1Click:Connect(function() local g=self._groups[id]; if g then g.locked=not g.locked; lBtn.BackgroundColor3=g.locked and UIUtils.Colors.AccentDim or UIUtils.Colors.Surface end end)
        local dBtn=UIUtils.MakeButton({Text="✕",Color=UIUtils.Colors.Danger,Size=UDim2.new(0,24,0,22),Position=UDim2.new(1,-28,0.5,-11),Parent=row}); dBtn.TextSize=10
        dBtn.MouseButton1Click:Connect(function() self._groups[id]=nil; row:Destroy() end)
        UIUtils.Toast(self._gui,"Created "..id,"success")
    end

    function M:Serialize()
        local out={attached={},groups={}}
        for name,data in pairs(self._attached) do out.attached[name]={target=data.target,offset={data.offset:GetComponents()}} end
        for id,g in pairs(self._groups) do out.groups[id]={locked=g.locked,parts=g.parts} end
        return out
    end

    function M:Destroy()
        for _,data in pairs(self._attached) do if data.weld and data.weld.Parent then data.weld:Destroy() end end
        self._attached={}; self._groups={}
    end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MODULE: AnimEditorTab  (Full-screen editor session)
-- ════════════════════════════════════════════════════════
local AnimEditorTab = (function()
    local M = {}; M.__index = M

    function M.new(screenGui, ctx)
        return setmetatable({_gui=screenGui,_ctx=ctx,_active=false,_slotName=nil,_env=nil,_timeline=nil,_kfEditor=nil,_groupSys=nil,_shell=nil},M)
    end

    function M:Enter(slotName)
        if self._active then return end; self._active=true; self._slotName=slotName
        if self._ctx.onEditorEnter then self._ctx.onEditorEnter() end
        if self._ctx.studio then self._ctx.studio:Hide() end
        local fade=UIUtils.MakeFrame({Name="EditorFade",Color=UIUtils.Colors.Overlay,Size=UDim2.new(1,0,1,0),Transparency=1,Parent=self._gui})
        fade.ZIndex=150; fade.Visible=true
        UIUtils.Tween(fade,{BackgroundTransparency=0},UIUtils.TweenInfo.Slow,function()
            self._env=EditorEnvironment.new()
            self._env:OnReady(function() self:_buildShell() end)
            self._env:Build(self._ctx.character)
            task.delay(0.3,function() UIUtils.Tween(fade,{BackgroundTransparency=1},UIUtils.TweenInfo.Slow,function() fade:Destroy() end) end)
        end)
    end

    function M:_buildShell()
        local shell=UIUtils.MakeFrame({Name="EditorShell",Color=UIUtils.Colors.Background,Transparency=1,Size=UDim2.new(1,0,1,0),Parent=self._gui})
        shell.ZIndex=10; self._shell=shell

        -- Top bar
        local topBar=UIUtils.MakeFrame({Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,0,44),Parent=shell}); topBar.ZIndex=11
        UIUtils.MakeStroke(topBar,UIUtils.Colors.Border,1)
        UIUtils.MakePadding(topBar,{Left=UDim.new(0,10),Right=UDim.new(0,10),Top=UDim.new(0,6),Bottom=UDim.new(0,6)})
        UIUtils.MakeListLayout(topBar,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8)})
        local backBtn=UIUtils.MakeButton({Text="← Exit Editor",Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,110,0,32),Parent=topBar}); backBtn.TextSize=12; backBtn.LayoutOrder=1
        backBtn.MouseButton1Click:Connect(function() self:_confirmExit() end)
        local sLbl=UIUtils.MakeLabel({Text="Editing: "..(self._slotName or "Animation"),Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextPrimary,Frame=UDim2.new(0,200,1,0),Parent=topBar}); sLbl.TextSize=14; sLbl.LayoutOrder=2
        UIUtils.MakeFrame({Color=UIUtils.Colors.Surface,Transparency=1,Size=UDim2.new(1,-600,1,0),Parent=topBar}).LayoutOrder=3
        local expBtn=UIUtils.MakeButton({Text="Export Animation",Color=UIUtils.Colors.Accent,Size=UDim2.new(0,140,0,32),Parent=topBar}); expBtn.TextSize=12; expBtn.LayoutOrder=4
        expBtn.MouseButton1Click:Connect(function() self:_export() end)
        local saveBtn=UIUtils.MakeButton({Text="Save Pack",Color=UIUtils.Colors.Success,Size=UDim2.new(0,90,0,32),Parent=topBar}); saveBtn.TextSize=12; saveBtn.LayoutOrder=5
        saveBtn.MouseButton1Click:Connect(function() self:_saveToPack() end)

        -- Timeline (bottom)
        local tlH=UIUtils.IsMobile() and 200 or 160
        local tlFrame=UIUtils.MakeFrame({Color=UIUtils.Colors.Surface,Size=UDim2.new(1,0,0,tlH),Position=UDim2.new(0,0,1,-tlH),Parent=shell}); tlFrame.ZIndex=11; UIUtils.MakeStroke(tlFrame,UIUtils.Colors.Border,1)

        -- Camera controls (top center)
        local camCtrl=UIUtils.MakeFrame({Color=UIUtils.Colors.Surface,Size=UDim2.new(0,160,0,110),Position=UDim2.new(0.5,-80,0,52),Parent=shell})
        camCtrl.ZIndex=11; UIUtils.MakeCorner(10,camCtrl); UIUtils.MakeStroke(camCtrl,UIUtils.Colors.Border,1)
        UIUtils.MakePadding(camCtrl,{Top=UDim.new(0,6),Bottom=UDim.new(0,6),Left=UDim.new(0,6),Right=UDim.new(0,6)})
        UIUtils.MakeLabel({Text="CAMERA",Font=UIUtils.Font.Bold,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(1,0,0,16),XAlign=Enum.TextXAlignment.Center,Parent=camCtrl}).TextSize=9
        local orbitCtrl=nil
        local btnRow=UIUtils.MakeFrame({Color=UIUtils.Colors.Surface,Transparency=1,Size=UDim2.new(1,0,0,34),Position=UDim2.new(0,0,0,20),Parent=camCtrl})
        UIUtils.MakeListLayout(btnRow,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4)})
        for _,d in ipairs({{"←",-15,0},{"↑",0,-10},{"↓",0,10},{"→",15,0}}) do
            local b=UIUtils.MakeButton({Text=d[1],Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,30,0,28),Parent=btnRow}); b.TextSize=14
            b.MouseButton1Click:Connect(function() if orbitCtrl then if d[2]~=0 then orbitCtrl.SetYaw(orbitCtrl.GetYaw()+d[2]) end if d[3]~=0 then orbitCtrl.SetPitch(orbitCtrl.GetPitch()+d[3]) end end end)
        end
        local zoomRow=UIUtils.MakeFrame({Color=UIUtils.Colors.Surface,Transparency=1,Size=UDim2.new(1,0,0,30),Position=UDim2.new(0,0,0,58),Parent=camCtrl})
        UIUtils.MakeListLayout(zoomRow,{Direction=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4),HAlign=Enum.HorizontalAlignment.Center})
        local function zBtn(t,fn) local b=UIUtils.MakeButton({Text=t,Color=UIUtils.Colors.SurfaceAlt,Size=UDim2.new(0,30,0,26),Parent=zoomRow}); b.TextSize=12; b.MouseButton1Click:Connect(fn) end
        zBtn("−",function() if orbitCtrl then orbitCtrl.SetDist(orbitCtrl.GetDist()+2) end end)
        UIUtils.MakeLabel({Text="Zoom",Font=UIUtils.Font.Regular,Color=UIUtils.Colors.TextMuted,Frame=UDim2.new(0,40,1,0),XAlign=Enum.TextXAlignment.Center,Parent=zoomRow}).TextSize=10
        zBtn("+",function() if orbitCtrl then orbitCtrl.SetDist(orbitCtrl.GetDist()-2) end end)

        -- Init subsystems
        local undoRedo=self._ctx.undoRedo
        self._timeline=TimelineSystem.new(tlFrame,undoRedo,self._ctx)
        self._kfEditor=KeyframeEditor.new(self._env,self._timeline,undoRedo,shell,self._ctx)
        self._groupSys=GroupAttachment.new(self._env,undoRedo,shell,self._ctx)
        orbitCtrl=self._env:StartOrbitCamera()
        self._kfEditor:LoadCharacter()

        InputHandler.SetupEditorShortcuts({
            Undo=function() undoRedo:Undo() end,
            Redo=function() undoRedo:Redo() end,
            Save=function() self:_saveToPack() end,
            Delete=function() self._timeline:DeleteSelectedKeyframes() end,
            Escape=function() self:_confirmExit() end,
            ToolSelect=function() self._kfEditor:SetTool(KeyframeEditor.Tool.SELECT) end,
            ToolMove=function()   self._kfEditor:SetTool(KeyframeEditor.Tool.MOVE)   end,
            ToolRotate=function() self._kfEditor:SetTool(KeyframeEditor.Tool.ROTATE) end,
            Play=function() if self._timeline._playing then self._timeline:Pause() else self._timeline:Play() end end,
        })
        InputHandler.Start()
        UIUtils.SlideIn(shell,"Bottom",30,0.4)
    end

    function M:_confirmExit()
        UIUtils.Confirm(self._gui,{
            Title="Exit Animation Editor",Body="Save changes to "..(self._slotName or "animation").."?",
            Buttons={{Text="Save",Kind="primary",Value="save",Order=1},{Text="Discard",Kind="danger",Value="discard",Order=2},{Text="Cancel",Kind="ghost",Value="cancel",Order=3}}
        },function(val)
            if val=="cancel" then return end
            if val=="save" then self:_saveToPack() end
            self:Exit()
        end)
    end

    function M:_saveToPack()
        if self._timeline then
            local data=self._timeline:Serialize(); local am=self._ctx.animManager
            if am and self._slotName then am:SetSlot(self._slotName,{id="",source="Edited",name=self._slotName.." (Edited)",timeline=data}) end
        end
        UIUtils.Toast(self._gui,"Animation saved!","success")
    end

    function M:_export()
        local data=self._timeline and self._timeline:Serialize()
        if data then
            local tc,kc=0,0; for _,kfs in pairs(data.tracks or {}) do tc=tc+1; kc=kc+#kfs end
            UIUtils.Toast(self._gui,string.format("Export ready: %d tracks, %d keyframes, %.2fs",tc,kc,data.duration or 0),"success",4)
        end
    end

    function M:Exit()
        if not self._active then return end
        local fade=UIUtils.MakeFrame({Name="EditorFadeOut",Color=UIUtils.Colors.Overlay,Size=UDim2.new(1,0,1,0),Transparency=1,Parent=self._gui})
        fade.ZIndex=150; fade.Visible=true
        UIUtils.Tween(fade,{BackgroundTransparency=0},UIUtils.TweenInfo.Normal,function()
            if self._kfEditor  then self._kfEditor:Destroy()  end
            if self._groupSys  then self._groupSys:Destroy()  end
            if self._timeline  then self._timeline:Destroy()  end
            if self._env       then self._env:Destroy()       end
            if self._shell     then self._shell:Destroy(); self._shell=nil end
            self._active=false; self._env=nil; self._timeline=nil; self._kfEditor=nil; self._groupSys=nil
            InputHandler.Stop()
            if self._ctx.studio then self._ctx.studio:Show() end
            if self._ctx.onEditorExit then self._ctx.onEditorExit() end
            task.delay(0.2,function() UIUtils.Tween(fade,{BackgroundTransparency=1},UIUtils.TweenInfo.Normal,function() fade:Destroy() end) end)
        end)
    end

    function M:IsActive() return self._active end

    return M
end)()

-- ════════════════════════════════════════════════════════
--  MAIN CONTROLLER
-- ════════════════════════════════════════════════════════

-- ── Screen GUI ────────────────────────────────────────
-- Remove any previous instance so re-execution works
local existingGui = LocalPlayer:FindFirstChild("PlayerGui") and
    LocalPlayer.PlayerGui:FindFirstChild("AnimationStudioGui")
if existingGui then existingGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "AnimationStudioGui"
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = true
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder    = 10

-- Parent: try PlayerGui first, fall back to CoreGui (executor context)
local guiParent = nil
pcall(function()
    guiParent = LocalPlayer:WaitForChild("PlayerGui", 5)
end)
if not guiParent then
    guiParent = game:GetService("CoreGui")
end
screenGui.Parent = guiParent

-- ── Error display helper (shown on screen if init fails) ──
local function showFatalError(msg)
    local errLbl = Instance.new("TextLabel")
    errLbl.Size               = UDim2.new(1, -20, 0, 80)
    errLbl.Position           = UDim2.new(0, 10, 0.4, 0)
    errLbl.BackgroundColor3   = Color3.fromRGB(30, 10, 10)
    errLbl.BorderSizePixel    = 0
    errLbl.Text               = "[AnimStudio ERROR]\n" .. tostring(msg)
    errLbl.TextColor3         = Color3.fromRGB(255, 100, 100)
    errLbl.Font               = Enum.Font.Code
    errLbl.TextSize           = 13
    errLbl.TextWrapped        = true
    errLbl.ZIndex             = 999
    errLbl.Parent             = screenGui
    warn("[AnimStudio] FATAL: " .. tostring(msg))
end

-- ── Core systems ──────────────────────────────────────
local undoRedo, animManager, playbackSys
local ok, err = pcall(function()
    undoRedo    = UndoRedo.new()
    animManager = AnimationManager.new(nil)
    playbackSys = PlaybackSystem.new(animManager)
end)
if not ok then showFatalError("Core init failed: " .. tostring(err)); return end

-- ── Shared context ────────────────────────────────────
local ctx = {
    animManager   = animManager,
    undoRedo      = undoRedo,
    saveLoad      = SaveLoad,
    playbackSys   = playbackSys,
    character     = nil,
    studio        = nil,
    floatSystem   = nil,
    emoteSystem   = nil,
    onOpenEditor  = nil,
    onEditorEnter = nil,
    onEditorExit  = nil,
}

-- ── UI systems ────────────────────────────────────────
local studio, floatSystem, animEditor, toggleBtn
ok, err = pcall(function()
    studio      = StudioInterface.new(screenGui, ctx)
    ctx.studio  = studio

    floatSystem    = FloatingEmoteSystem.new(screenGui, ctx)
    ctx.floatSystem = floatSystem

    animEditor  = AnimEditorTab.new(screenGui, ctx)

    toggleBtn = ToggleButton.new(screenGui, function(isOpen)
        if isOpen then studio:Show() else studio:Hide() end
    end)
end)
if not ok then showFatalError("UI init failed: " .. tostring(err)); return end

-- ── Editor callbacks ──────────────────────────────────
ctx.onOpenEditor  = function(slotName) studio:Hide(); animEditor:Enter(slotName) end
ctx.onEditorEnter = function() toggleBtn:HideForEditor() end
ctx.onEditorExit  = function() toggleBtn:ShowFromEditor(); studio:Show() end

-- ── Character binding ─────────────────────────────────
local function onCharacterAdded(character)
    pcall(function()
        character:WaitForChild("HumanoidRootPart", 10)
        character:WaitForChild("Humanoid", 10)
        ctx.character = character
        animManager:BindCharacter(character)
        playbackSys:Stop()
        playbackSys:Start()
        local savedSlots = SaveLoad.Get("AnimSlots")
        if savedSlots then animManager:DeserializeSlots(savedSlots) end
        undoRedo:OnChange(function(undoCount)
            toggleBtn:SetUnsaved(undoCount > 0)
        end)
    end)
end

if LocalPlayer.Character then
    task.spawn(onCharacterAdded, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ── Save / Load init (async, non-blocking) ────────────
task.spawn(function()
    SaveLoad.EnsureDefaults()
    local loadOk = pcall(function() SaveLoad.Init() end)
    local uiState = SaveLoad.Get("UIState")
    if uiState then
        pcall(function() toggleBtn:SetPosition(uiState.toggleBtnPos) end)
        pcall(function() if uiState.activeTab then studio:SwitchTab(uiState.activeTab, true) end end)
        pcall(function() if uiState.playbackMode then playbackSys:Deserialize({mode=uiState.playbackMode}) end end)
    end
    local floatData = SaveLoad.Get("FloatEmotes")
    if floatData then pcall(function() floatSystem:Deserialize(floatData) end) end
    pcall(function() studio:Notify("Animation Studio loaded!", "success") end)
end)

-- ── Auto-save loop ────────────────────────────────────
task.spawn(function()
    while task.wait(45) do
        pcall(function()
            SaveLoad.Set("AnimSlots",   animManager:SerializeSlots())
            SaveLoad.Set("FloatEmotes", floatSystem:Serialize())
            SaveLoad.Set("UIState", {
                toggleBtnPos = toggleBtn:GetPosition(),
                activeTab    = studio._activeTab or "Home",
                playbackMode = playbackSys:GetMode(),
            })
            SaveLoad.Flush()
        end)
    end
end)

-- ── Camera viewport resize ────────────────────────────
pcall(function()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if studio and studio:IsVisible() then
            studio:Hide()
            task.delay(0.05, function() studio:Show() end)
        end
    end)
end)

-- ── Suppress default Roblox HUD if needed ─────────────
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
