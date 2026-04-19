--[[
    FlyScript.lua  v3
    Rayfield UI Fly Script
    Fixes: crosshair/aim-based flight, falling anim suppressed, mobile thumbstick camera-relative
]]

-- ============================================================
--  SERVICES
-- ============================================================
local Rayfield          = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")
local SoundService      = game:GetService("SoundService")
local Camera            = workspace.CurrentCamera

local LocalPlayer       = Players.LocalPlayer
local function getCharParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil, nil end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildWhichIsA("Humanoid")
    local anim = hum and hum:FindFirstChildWhichIsA("Animator")
    return char, hrp, hum, anim
end

-- ============================================================
--  STATE
-- ============================================================
local State = {
    enabled        = false,
    floating       = false,
    flying         = false,
    boostActive    = false,
    boostCD        = false,
    boostCDLeft    = 0,
    defaultFOV     = Camera.FieldOfView,
    lerpSpeed      = 0,
    shiftlock      = false,   -- character body follows camera yaw; mouse locked on PC
    autoPilot      = false,   -- auto-pilot: fly forward with no input needed
    autoPilotDir   = Vector3.new(0, 0, -1), -- direction captured when auto-pilot is turned on
    freecam        = false,   -- spectator / freecam mode
}

-- ============================================================
--  DEFAULTS / SETTINGS
-- ============================================================
local D = {
    flySpeed             = 50,
    flyAnimId            = "134861929761233",
    floatIdleAnimId      = "126351819085633",
    floatMoveAnimId      = "73017334485905",
    floatMoveSpeed       = 20,
    flyAnimEnabled       = true,
    floatAccel           = 5,
    flyAccel             = 8,
    accelEnabled         = true,   -- false = instant speed (no lerp)
    boostPct             = 200,
    boostDuration        = 3,
    boostCooldown        = 8,
    boostAccel           = 20,     -- acceleration ramp while boost is active
    boostFovPct          = 150,    -- % of fovMax to use as target during boost
    fovEnabled           = true,
    fovMax               = 100,
    fovRate              = 30,
    -- Music
    musicId              = "",
    musicVolume          = 50,
    musicEnabled         = false,
    musicDist            = 100,
    musicFade            = true,
    -- Sound Effects
    sfxFlyId             = "",     -- loops while flying
    sfxFlyVolume         = 70,
    sfxFlyDist           = 100,
    sfxFlyFade           = true,
    sfxBoostHitId        = "",     -- one-shot when boost triggers
    sfxBoostHitVolume    = 80,
    sfxBoostHitDist      = 100,
    sfxBoostHitFade      = true,
    sfxBoostLoopId       = "",     -- loops while boost is active
    sfxBoostLoopVolume   = 70,
    sfxBoostLoopDist     = 100,
    sfxBoostLoopFade     = true,
    sfxNearFlyId         = "",     -- loops while flying near a player
    sfxNearFlyVolume     = 70,
    sfxNearFlyDist       = 100,
    sfxNearFlyFade       = true,
    nearPlayerRadius     = 50,     -- studs radius to trigger near-player SFX
    sfxFlySpeedMin       = 10,     -- speed threshold at which fly SFX begins fading in
    -- Keybinds
    floatKey             = Enum.KeyCode.F,
    flyKey               = Enum.KeyCode.G,
    boostKey             = Enum.KeyCode.X,
    shiftlockKey         = Enum.KeyCode.V,
    floatKey2            = nil,
    flyKey2              = nil,
    autoPilotKey         = Enum.KeyCode.H,
    autoPilotOnStart     = true,
    autoPilotOnStartDur  = 5,
    floatTilt            = 1,
    floatBtnPos          = UDim2.new(0.82, 0, 0.80, 0),
    flyBtnPos            = UDim2.new(0.82, 0, 0.65, 0),
    boostBtnPos          = UDim2.new(0.66, 0, 0.80, 0),
    autoPilotBtnPos      = UDim2.new(0.50, 0, 0.65, 0),
    btnSize              = UDim2.new(0, 72, 0, 72),
}
local S = {}
for k, v in pairs(D) do S[k] = v end

-- ============================================================
--  ANIMATIONS
--  Catalog emote items are WRAPPER assets — the actual animation
--  lives inside them. We use game:GetObjects() to unpack the
--  real AnimationId before loading the track on the Animator.
-- ============================================================
local tracks = { floatIdle = nil, floatMove = nil, fly = nil }

local function stopAllTracks()
    for _, t in pairs(tracks) do
        if t and t.IsPlaying then t:Stop(0.2) end
    end
end

-- Resolve a catalog emote ID (or plain animation ID) to an actual animation ID.
-- Returns the string numeric ID to use in "rbxassetid://..." 
local function resolveAnimId(rawId)
    local numId = tostring(rawId):match("%d+")
    if not numId then return nil end

    -- Attempt to load the asset via GetObjects — this unpacks catalog emote bundles
    local ok, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. numId)
    end)

    if ok and objects then
        for _, obj in ipairs(objects) do
            -- The object itself might be an Animation
            if obj:IsA("Animation") then
                local inner = obj.AnimationId:match("%d+")
                if inner and inner ~= "0" then return inner end
            end
            -- Or the Animation lives inside a folder/model (emote bundle layout)
            local found = obj:FindFirstChildOfClass("Animation")
                       or obj:FindFirstChildWhichIsA("Animation", true)
            if found then
                local inner = found.AnimationId:match("%d+")
                if inner and inner ~= "0" then return inner end
            end
        end
    end

    -- Fall back: treat the ID as a direct animation asset
    return numId
end

local function loadAnim(rawId, animr)
    if not animr then return nil end

    local resolvedId = resolveAnimId(rawId)
    if not resolvedId then return nil end

    local a = Instance.new("Animation")
    a.AnimationId = "rbxassetid://" .. resolvedId

    -- Priority 4 so emote plays over default idle/walk tracks
    local ok, track = pcall(function()
        local t = animr:LoadAnimation(a)
        t.Priority = Enum.AnimationPriority.Action4
        return t
    end)
    a:Destroy()

    if ok and track then return track end
    return nil
end

local function reloadAnims()
    stopAllTracks()
    local _, _, _, animr = getCharParts()
    if not animr then return end
    tracks.floatIdle = loadAnim(S.floatIdleAnimId, animr)
    tracks.floatMove = loadAnim(S.floatMoveAnimId, animr)
    tracks.fly       = loadAnim(S.flyAnimId, animr)
end

reloadAnims()

-- ============================================================
--  SOUND SYSTEM
-- ============================================================
local Sounds = { music = nil, fly = nil, boostHit = nil, boostLoop = nil, nearFly = nil }

--[[
    makeSound — creates a 3D spatial Sound on the character's HumanoidRootPart.
    dist  = RollOffMaxDistance (how far others can hear it)
    fade  = true  → volume fades linearly from ~10 studs to dist
            false → full volume up to dist, then silence (RollOffMin = dist)
--]]
local function makeSound(name, looped, volume, id, dist, fade, parent)
    local s = Instance.new("Sound")
    s.Name               = name
    s.Looped             = looped
    s.Volume             = volume / 100
    s.RollOffMaxDistance = dist or 100
    s.RollOffMode        = Enum.RollOffMode.Linear
    if not fade then
        s.RollOffMinDistance = dist or 100  -- flat volume → sudden cutoff
    else
        s.RollOffMinDistance = 10           -- fade from 10 studs onward
    end
    if id and id ~= "" then
        s.SoundId = "rbxassetid://" .. tostring(id):match("%d+")
    end
    s.Parent = parent or SoundService
    return s
end

local function getSoundParent()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    return hrp or SoundService  -- fallback until character loads
end

local function buildSounds()
    for _, s in pairs(Sounds) do pcall(function() s:Destroy() end) end
    local p = getSoundParent()
    Sounds.music    = makeSound("FSMusic",     true,  S.musicVolume,       S.musicId,       S.musicDist,       S.musicFade,       p)
    Sounds.fly      = makeSound("FSFlyLoop",   true,  S.sfxFlyVolume,      S.sfxFlyId,      S.sfxFlyDist,      S.sfxFlyFade,      p)
    Sounds.boostHit = makeSound("FSBoostHit",  false, S.sfxBoostHitVolume, S.sfxBoostHitId, S.sfxBoostHitDist, S.sfxBoostHitFade, p)
    Sounds.boostLoop= makeSound("FSBoostLoop", true,  S.sfxBoostLoopVolume,S.sfxBoostLoopId,S.sfxBoostLoopDist,S.sfxBoostLoopFade,p)
    Sounds.nearFly  = makeSound("FSNearFly",   true,  S.sfxNearFlyVolume,  S.sfxNearFlyId,  S.sfxNearFlyDist,  S.sfxNearFlyFade,  p)
    if S.musicEnabled and S.musicId ~= "" then Sounds.music:Play() end
end

buildSounds()

-- Safely update just one sound's SoundId
local function reloadSoundId(key, newId)
    local s = Sounds[key]
    if not s then return end
    local wasPlaying = s.IsPlaying
    s:Stop()
    if newId ~= "" then
        s.SoundId = "rbxassetid://" .. tostring(newId):match("%d+")
        if wasPlaying then s:Play() end
    else
        s.SoundId = ""
    end
end

-- Apply distance + fade settings to a live Sound instance
local function applyRollOff(s, dist, fade)
    if not s then return end
    s.RollOffMaxDistance = dist
    s.RollOffMode        = Enum.RollOffMode.Linear
    s.RollOffMinDistance = fade and 10 or dist
end

-- ============================================================
--  BODY MOVERS
-- ============================================================
local BV, BG  -- BodyVelocity, BodyGyro

local function createMovers(hrp)
    if BV then BV:Destroy() end
    if BG then BG:Destroy() end

    BV = Instance.new("BodyVelocity")
    BV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    BV.Velocity  = Vector3.zero
    BV.P         = 1e4
    BV.Parent    = hrp

    BG = Instance.new("BodyGyro")
    BG.MaxTorque = Vector3.new(5e5, 5e5, 5e5)
    BG.D         = 100
    BG.P         = 1e5
    BG.CFrame    = hrp.CFrame
    BG.Parent    = hrp
end

local function destroyMovers()
    if BV then BV:Destroy(); BV = nil end
    if BG then BG:Destroy(); BG = nil end
end

-- ============================================================
--  MOVEMENT DIRECTION  — Camera-directed / Crosshair-based
--
--  W/S  → move along the FULL camera LookVector (including pitch up/down)
--  A/D  → strafe along camera RightVector
--  E/Space → rise straight up   Q → sink straight down
--  Mobile thumbstick forward   → camera LookVector (full 3D pitch included)
--  Mobile thumbstick side      → camera RightVector
--
--  Result: wherever your crosshair points, that's where you fly.
--  You can look around freely without it changing direction until
--  you press a movement key — just like Iron Man / Anthem flight.
-- ============================================================

-- Store the raw thumbstick values updated by the mobile hook below
local mobileStick = Vector2.zero   -- X = strafe, Y = forward

local function getMoveDir()
    -- Auto-pilot: fly in the direction that was captured when auto-pilot was enabled
    if State.autoPilot then
        return State.autoPilotDir
    end

    local camCF   = Camera.CFrame
    -- Full 3D camera vectors — NOT flattened to horizontal
    local camLook  = camCF.LookVector
    local camRight = camCF.RightVector
    local worldUp  = Vector3.new(0, 1, 0)

    local v = Vector3.zero

    -- ---- Keyboard (PC + tablet keyboards) ----
    local anyKey = false
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then v += camLook;  anyKey = true end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then v -= camLook;  anyKey = true end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then v -= camRight; anyKey = true end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then v += camRight; anyKey = true end
    if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then v += worldUp;  anyKey = true end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q)                                                   then v -= worldUp;  anyKey = true end

    -- ---- Mobile thumbstick (updated below by hookMobileThumbstick) ----
    -- Forward/back: camera full LookVector so tilting camera up aims flight upward
    -- Strafe:       camera RightVector
    if mobileStick.Magnitude > 0.08 then
        v += camLook  * mobileStick.Y
        v += camRight * mobileStick.X
    end

    -- ---- Gamepad (controller) ----
    local pads = UserInputService:GetConnectedGamepads()
    if #pads > 0 then
        local st = UserInputService:GetGamepadState(pads[1])
        for _, inp in ipairs(st) do
            if inp.KeyCode == Enum.KeyCode.Thumbstick1 then
                v += camLook  * inp.Position.Y
                v += camRight * inp.Position.X
            end
        end
    end

    if v.Magnitude > 0.001 then return v.Unit end
    return Vector3.zero
end

-- Hook the Roblox PlayerModule thumbstick for iOS/Android.
-- Humanoid.MoveDirection is set by the mobile PlayerModule each frame.
-- We convert it to camera-relative and store in mobileStick.
local function hookMobileThumbstick()
    task.spawn(function()
        while true do
            task.wait(0.05)
            local _, _, hum, _ = getCharParts()
            if hum and State.floating then
                local md = hum.MoveDirection  -- world-space, set by mobile thumbstick
                if md.Magnitude > 0.05 then
                    -- Project onto camera flat plane to get stick XY
                    local camCF    = Camera.CFrame
                    local flatLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
                    local flatRight= Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
                    if flatLook.Magnitude > 0.001  then flatLook  = flatLook.Unit  end
                    if flatRight.Magnitude > 0.001 then flatRight = flatRight.Unit end
                    local fwd  = md:Dot(flatLook)
                    local side = md:Dot(flatRight)
                    mobileStick = Vector2.new(side, fwd)
                else
                    mobileStick = Vector2.zero
                end
            else
                mobileStick = Vector2.zero
            end
        end
    end)
end
hookMobileThumbstick()

-- ============================================================
--  START / STOP FLOAT
-- ============================================================
-- Forward declaration so stopFloat can call setShiftlock even though it's defined later
local setShiftlock

-- States we suppress to prevent Roblox's Animate script playing fall/jump anims
local SUPPRESSED_STATES = {
    Enum.HumanoidStateType.Freefall,
    Enum.HumanoidStateType.Jumping,
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.GettingUp,
}

local function suppressFallAnims(hum)
    for _, s in ipairs(SUPPRESSED_STATES) do
        pcall(function() hum:SetStateEnabled(s, false) end)
    end
    -- Force the humanoid into Running state so the Animate LocalScript
    -- never switches to "fall" or "jump" tracks
    task.defer(function()
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end)
end

local function restoreFallAnims(hum)
    for _, s in ipairs(SUPPRESSED_STATES) do
        pcall(function() hum:SetStateEnabled(s, true) end)
    end
end

-- Find and pause Roblox's built-in Animate LocalScript tracks while we fly.
-- This stops the default idle/walk/fall animations from fighting our emote anims.
local animScriptConn = nil
local function pauseDefaultAnimate(char)
    if not char then return end
    local animScript = char:FindFirstChild("Animate")
    if animScript then
        -- Disable it so it can't override our animation tracks
        animScript.Disabled = true
    end
end
local function resumeDefaultAnimate(char)
    if not char then return end
    local animScript = char:FindFirstChild("Animate")
    if animScript then
        animScript.Disabled = false
    end
end

local function startFloat()
    if State.floating then return end
    local char, hrp, hum, _ = getCharParts()
    if not hrp or not hum then return end

    State.floating  = true
    State.flying    = false
    State.lerpSpeed = 0

    hum.AutoRotate = false
    hum.WalkSpeed  = 0
    hum.JumpPower  = 0

    -- Suppress default fall/jump animations
    suppressFallAnims(hum)
    pauseDefaultAnimate(char)

    createMovers(hrp)
    stopAllTracks()
    if S.flyAnimEnabled and tracks.floatIdle then
        tracks.floatIdle:Play()
    end
end

local function stopFloat()
    if not State.floating then return end
    State.floating  = false
    State.flying    = false
    State.lerpSpeed = 0

    -- Turn off shiftlock when landing
    if State.shiftlock then
        setShiftlock(false)
    end

    local char, _, hum, _ = getCharParts()
    if hum then
        hum.AutoRotate = true
        hum.WalkSpeed  = 16
        hum.JumpPower  = 50
        restoreFallAnims(hum)
    end

    resumeDefaultAnimate(char)
    stopAllTracks()
    destroyMovers()
    TweenService:Create(Camera, TweenInfo.new(0.5), { FieldOfView = State.defaultFOV }):Play()
end

-- ============================================================
--  START / STOP FLY
-- ============================================================
local function startFly()
    if not State.floating then startFloat() end
    State.flying = true
    -- Zero velocity so pressing fly doesn't lurch the character forward
    if BV then BV.Velocity = Vector3.zero end
    stopAllTracks()
    if S.flyAnimEnabled and tracks.fly then
        tracks.fly:Play()
    end
    -- Auto-pilot on start: fly in the camera direction for a short burst
    if S.autoPilotOnStart then
        State.autoPilotDir = Camera.CFrame.LookVector.Unit  -- launch in camera direction
        State.autoPilot    = true
        task.delay(S.autoPilotOnStartDur, function()
            if State.autoPilot and State.flying then
                State.autoPilot = false
            end
        end)
    end
end

local function stopFly()
    -- Stopping fly returns to float (Land [F] is what fully lands)
    State.autoPilot = false
    State.flying = false
    stopAllTracks()
    if State.floating and S.flyAnimEnabled and tracks.floatIdle then
        tracks.floatIdle:Play()
    end
end

-- ============================================================
--  AUTO-PILOT TOGGLE
--  Captures the character's current facing direction the moment
--  auto-pilot is turned ON so the flight direction is locked to
--  where the character WAS facing, not where the camera looks.
-- ============================================================
local function setAutoPilot(on)
    if on and not State.autoPilot then
        local _, hrp = getCharParts()
        if hrp and hrp.CFrame.LookVector.Magnitude > 0.01 then
            State.autoPilotDir = hrp.CFrame.LookVector.Unit
        else
            State.autoPilotDir = Camera.CFrame.LookVector.Unit
        end
    end
    State.autoPilot = on
end

-- ============================================================
--  BOOST
-- ============================================================
local function triggerBoost()
    if not State.enabled  then return end
    if not State.flying   then return end
    if State.boostCD      then return end
    if State.boostActive  then return end

    -- One-shot boost hit SFX
    if Sounds.boostHit and S.sfxBoostHitId ~= "" then
        Sounds.boostHit:Play()
    end
    -- Start boost loop SFX
    if Sounds.boostLoop and S.sfxBoostLoopId ~= "" then
        Sounds.boostLoop:Play()
    end

    State.boostActive = true
    task.delay(S.boostDuration, function()
        State.boostActive = false
        -- Stop boost loop SFX
        if Sounds.boostLoop then Sounds.boostLoop:Stop() end
        State.boostCD     = true
        State.boostCDLeft = S.boostCooldown
        task.spawn(function()
            while State.boostCDLeft > 0 do
                task.wait(1)
                State.boostCDLeft -= 1
            end
            State.boostCD = false
        end)
    end)
end

-- ============================================================
--  HEARTBEAT — movement, tilt, animations, FOV
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    if not State.enabled  then return end
    if not State.floating then return end

    local _, hrp, hum, _ = getCharParts()
    if not hrp or not hum then return end
    if not BV or not BG   then return end

    local moveDir  = getMoveDir()
    local isMoving = moveDir.Magnitude > 0.01

    -- Speed lerp
    local targetSpeed = State.flying and S.flySpeed or S.floatMoveSpeed
    if State.boostActive and State.flying then
        targetSpeed = targetSpeed * (S.boostPct / 100)
    end

    local accel = State.flying
        and (State.boostActive and S.boostAccel or S.flyAccel)
        or S.floatAccel
    if S.accelEnabled then
        State.lerpSpeed = State.lerpSpeed + (targetSpeed - State.lerpSpeed) * math.min(dt * accel, 1)
    else
        State.lerpSpeed = targetSpeed
    end

    -- Apply velocity
    if isMoving then
        BV.Velocity = moveDir * State.lerpSpeed
    else
        State.lerpSpeed = State.lerpSpeed * math.max(0, 1 - dt * accel * 0.8)
        BV.Velocity = BV.Velocity * math.max(0, 1 - dt * accel * 0.8)
    end

    -- -------------------------------------------------------
    --  BODY TILT — Camera-directed (crosshair steering)
    --
    --  The character's body faces the exact direction of travel
    --  (full 3D — including up/down pitch from camera).
    --  A banking roll is added when strafing sideways.
    --  This is visible to other players via BodyGyro replication.
    -- -------------------------------------------------------
    local targetCF

    -- When shiftlock is on the body faces the camera direction.
    -- While just flying (without shiftlock) the camera is FREE — you can look
    -- around without changing where the character is going.
    local facingDir
    if State.shiftlock then
        local camLook = Camera.CFrame.LookVector
        if camLook.Magnitude > 0.01 then
            facingDir = camLook.Unit
        end
    end

    if isMoving then
        if facingDir then
            -- Flying or shiftlock: body tracks full camera direction (pitch included)
            targetCF = CFrame.new(hrp.Position, hrp.Position + facingDir)
            -- Banking roll based on strafe amount relative to camera
            if State.flying then
                local speedFrac  = math.clamp(State.lerpSpeed / math.max(S.flySpeed, 1), 0, 1)
                local camRight   = Camera.CFrame.RightVector
                local sideAmount = moveDir:Dot(camRight)
                local rollAngle  = math.rad(28) * sideAmount * speedFrac
                targetCF = targetCF * CFrame.Angles(0, 0, rollAngle)
            end
        else
            -- Shiftlock off, not flying: body faces movement direction (crosshair steering)
            local flatForward = Vector3.new(moveDir.X, 0, moveDir.Z)

            if flatForward.Magnitude < 0.2 then
                local useUp = Camera.CFrame.RightVector:Cross(moveDir)
                if useUp.Magnitude < 0.01 then useUp = Vector3.new(0, 1, 0) end
                useUp = useUp.Unit
            end

            targetCF = CFrame.new(hrp.Position, hrp.Position + moveDir)

            if State.flying then
                local speedFrac  = math.clamp(State.lerpSpeed / math.max(S.flySpeed, 1), 0, 1)
                local camRight   = Camera.CFrame.RightVector
                local sideAmount = moveDir:Dot(camRight)
                local rollAngle  = math.rad(28) * sideAmount * speedFrac
                targetCF = targetCF * CFrame.Angles(0, 0, rollAngle)
            elseif State.floating then
                local speedFrac = math.clamp(State.lerpSpeed / math.max(S.floatMoveSpeed, 1), 0, 1)
                local flatFace  = Vector3.new(moveDir.X, 0, moveDir.Z)
                if flatFace.Magnitude > 0.01 then
                    targetCF = CFrame.new(hrp.Position, hrp.Position + flatFace)
                else
                    targetCF = CFrame.new(hrp.Position, hrp.Position + Vector3.new(
                        hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z))
                end
                targetCF = targetCF * CFrame.Angles(math.rad(-12 * S.floatTilt) * speedFrac, 0, 0)
            end
        end
    else
        -- Not moving — keep current facing, or track camera if flying/shiftlock on
        if facingDir then
            targetCF = CFrame.new(hrp.Position, hrp.Position + facingDir)
        else
            local curLook  = hrp.CFrame.LookVector
            local flatLook = Vector3.new(curLook.X, 0, curLook.Z)
            if flatLook.Magnitude > 0.01 then
                targetCF = CFrame.new(hrp.Position, hrp.Position + flatLook)
            else
                local _, yaw, _ = hrp.CFrame:ToEulerAnglesYXZ()
                targetCF = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
            end
        end
    end

    if targetCF then
        BG.CFrame = targetCF
    end

    -- -------------------------------------------------------
    --  ANIMATION SWITCHING
    -- -------------------------------------------------------
    if S.flyAnimEnabled then
        if State.flying then
            if isMoving then
                -- Moving while flying: play fly animation
                if tracks.fly and not tracks.fly.IsPlaying then
                    stopAllTracks()
                    tracks.fly:Play()
                end
            else
                -- Still while flying: hover with float idle
                if tracks.floatIdle and not tracks.floatIdle.IsPlaying then
                    stopAllTracks()
                    tracks.floatIdle:Play()
                end
            end
        else
            -- Floating (not flying)
            if isMoving then
                if tracks.floatMove and not tracks.floatMove.IsPlaying then
                    if tracks.floatIdle and tracks.floatIdle.IsPlaying then tracks.floatIdle:Stop(0.2) end
                    tracks.floatMove:Play()
                end
            else
                if tracks.floatIdle and not tracks.floatIdle.IsPlaying then
                    if tracks.floatMove and tracks.floatMove.IsPlaying then tracks.floatMove:Stop(0.2) end
                    tracks.floatIdle:Play()
                end
            end
        end
    end

    -- -------------------------------------------------------
    --  FOV ACCELERATION
    -- -------------------------------------------------------
    if S.fovEnabled and State.flying then
        local maxSpeed  = S.flySpeed * (S.boostPct / 100)
        local frac      = math.clamp(State.lerpSpeed / math.max(maxSpeed, 1), 0, 1)
        -- During boost, push FOV higher by boostFovPct% of the max
        local effectMax = State.boostActive
            and math.min(500, S.fovMax * (S.boostFovPct / 100))
            or  S.fovMax
        local targetFOV = State.defaultFOV + (effectMax - State.defaultFOV) * frac
        local lerpRate  = math.min(dt * (S.fovRate / 20), 1)
        Camera.FieldOfView = Camera.FieldOfView + (targetFOV - Camera.FieldOfView) * lerpRate
    else
        if math.abs(Camera.FieldOfView - State.defaultFOV) > 0.3 then
            Camera.FieldOfView = Camera.FieldOfView + (State.defaultFOV - Camera.FieldOfView) * math.min(dt * 5, 1)
        end
    end

    -- -------------------------------------------------------
    --  SOUND MANAGEMENT  — speed-driven fade in / fade out
    -- -------------------------------------------------------
    -- Fly loop SFX: fades in as speed climbs above sfxFlySpeedMin,
    -- fades out (and stops) when the player slows back below it.
    if Sounds.fly and S.sfxFlyId ~= "" then
        local speedRatio = 0
        if State.flying then
            local span = math.max(S.flySpeed - S.sfxFlySpeedMin, 1)
            speedRatio = math.clamp((State.lerpSpeed - S.sfxFlySpeedMin) / span, 0, 1)
        end
        local targetVol = speedRatio * (S.sfxFlyVolume / 100)
        local curVol    = Sounds.fly.Volume
        local newVol    = curVol + (targetVol - curVol) * math.min(dt * 4, 1)
        if newVol > 0.002 then
            Sounds.fly.Volume = newVol
            if not Sounds.fly.IsPlaying then Sounds.fly:Play() end
        else
            Sounds.fly.Volume = 0
            if Sounds.fly.IsPlaying then Sounds.fly:Stop() end
        end
    end

    -- Near-player fly SFX: play only while flying and a player is within nearPlayerRadius studs
    if Sounds.nearFly and S.sfxNearFlyId ~= "" and State.flying then
        local char = LocalPlayer.Character
        local hrp2 = char and char:FindFirstChild("HumanoidRootPart")
        local nearby = false
        if hrp2 then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local orp = p.Character:FindFirstChild("HumanoidRootPart")
                    if orp and (orp.Position - hrp2.Position).Magnitude <= S.nearPlayerRadius then
                        nearby = true
                        break
                    end
                end
            end
        end
        if nearby then
            if not Sounds.nearFly.IsPlaying then Sounds.nearFly:Play() end
        else
            if Sounds.nearFly.IsPlaying then Sounds.nearFly:Stop() end
        end
    elseif Sounds.nearFly and Sounds.nearFly.IsPlaying then
        Sounds.nearFly:Stop()
    end
end)

-- ============================================================
--  SHIFTLOCK TOGGLE
-- ============================================================
local shiftlockBtnObj  -- forward ref, assigned after makeButton calls below

setShiftlock = function(on)
    State.shiftlock = on

    if on then
        -- PC: lock cursor to screen center so camera orbits freely
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end)
    else
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end)
    end

    -- Update button label if it exists
    if shiftlockBtnObj then
        shiftlockBtnObj.lbl.Text = on and "Look [V] ON" or "Look [V]"
        shiftlockBtnObj.frame.BackgroundColor3 = on
            and Color3.fromRGB(120, 20, 180)
            or  Color3.fromRGB(70, 20, 120)
    end
end

-- ============================================================
--  FREECAM / SPECTATOR
-- ============================================================
local FC = {
    pos   = Vector3.zero,
    yaw   = 0,
    pitch = 0,
    speed = 32,
    conn  = nil,
}

-- GUIs that were hidden so we can restore them exactly
local _hiddenGuis = {}

local CORE_TYPES = {
    Enum.CoreGuiType.Health,
    Enum.CoreGuiType.PlayerList,
    Enum.CoreGuiType.Backpack,
    Enum.CoreGuiType.Chat,
    Enum.CoreGuiType.EmotesMenu,
}

-- Names to always keep visible during freecam
local KEEP_VISIBLE = { Rayfield = true, FlyScriptUI = true }

local function hideHUD()
    _hiddenGuis = {}
    for _, t in ipairs(CORE_TYPES) do
        pcall(function() StarterGui:SetCoreGuiEnabled(t, false) end)
    end
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled and not KEEP_VISIBLE[gui.Name] then
            gui.Enabled = false
            table.insert(_hiddenGuis, gui)
        end
    end
end

local function showHUD()
    for _, t in ipairs(CORE_TYPES) do
        pcall(function() StarterGui:SetCoreGuiEnabled(t, true) end)
    end
    for _, gui in ipairs(_hiddenGuis) do
        if gui and gui.Parent then gui.Enabled = true end
    end
    _hiddenGuis = {}
end

local function startFreecam()
    if State.freecam then return end
    State.freecam = true

    -- Seed camera from current view
    local cf      = Camera.CFrame
    FC.pos        = cf.Position
    local _, y, _ = cf:ToEulerAnglesYXZ()
    FC.yaw        = y
    FC.pitch      = math.asin(math.clamp(-cf.LookVector.Y, -1, 1))

    Camera.CameraType              = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

    hideHUD()

    FC.conn = RunService.RenderStepped:Connect(function(dt)
        -- Look (mouse / touch drag)
        local delta = UserInputService:GetMouseDelta()
        FC.yaw   = FC.yaw   - math.rad(delta.X * 0.35)
        FC.pitch = math.clamp(
            FC.pitch - math.rad(delta.Y * 0.35),
            -math.pi / 2 + 0.02,
             math.pi / 2 - 0.02
        )

        local camCF = CFrame.Angles(0, FC.yaw, 0) * CFrame.Angles(FC.pitch, 0, 0)
        local fwd   = camCF.LookVector
        local right = camCF.RightVector
        local up    = Vector3.new(0, 1, 0)

        -- Keyboard movement (PC)
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then move += fwd   end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then move -= fwd   end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then move -= right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then move += right end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += up    end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q)                                                   then move -= up    end

        -- Mobile thumbstick (uses camera-relative vectors, same as fly logic)
        if mobileStick.Magnitude > 0.05 then
            move += fwd   * mobileStick.Y
            move += right * mobileStick.X
        end

        if move.Magnitude > 0.001 then
            FC.pos = FC.pos + move.Unit * FC.speed * dt
        end

        Camera.CFrame = CFrame.new(FC.pos)
                      * CFrame.Angles(0, FC.yaw, 0)
                      * CFrame.Angles(FC.pitch, 0, 0)
    end)

    Rayfield:Notify({
        Title   = "Freecam ON",
        Content = "WASD / E / Q to move\nPC: press M to exit  •  Mobile: open menu to exit",
        Duration = 5,
    })
end

local function stopFreecam()
    if not State.freecam then return end
    State.freecam = false

    if FC.conn then FC.conn:Disconnect(); FC.conn = nil end

    Camera.CameraType              = Enum.CameraType.Custom
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default

    showHUD()

    Rayfield:Notify({ Title = "Freecam OFF", Content = "Camera restored.", Duration = 2 })
end

-- PC: M key toggles freecam (works regardless of State.enabled)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.M then
        if State.freecam then stopFreecam() else startFreecam() end
    end
end)

-- ============================================================
--  KEYBINDS  (single clean handler)
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not State.enabled then return end
    local k = input.KeyCode

    -- Float toggle
    if k == S.floatKey or (S.floatKey2 and k == S.floatKey2) then
        if State.floating then stopFloat() else startFloat() end
        return
    end
    -- Fly toggle
    if k == S.flyKey or (S.flyKey2 and k == S.flyKey2) then
        if not State.floating then return end
        if State.flying then stopFly() else startFly() end
        return
    end
    -- Shiftlock
    if k == S.shiftlockKey then
        if State.floating then setShiftlock(not State.shiftlock) end
        return
    end
    -- Boost
    if k == S.boostKey then
        triggerBoost()
    end
    -- Auto-pilot toggle
    if k == S.autoPilotKey then
        if State.floating then
            setAutoPilot(not State.autoPilot)
        end
    end
end)

-- Restore mouse on script-disable
UserInputService.InputBegan:Connect(function(input)
    if not State.enabled and State.shiftlock then
        setShiftlock(false)
    end
end)

-- ============================================================
--  SCREEN GUI  (mobile buttons)
-- ============================================================
local SG = Instance.new("ScreenGui")
SG.Name            = "FlyScriptUI"
SG.ResetOnSpawn    = false
SG.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset  = true
SG.DisplayOrder    = 10
SG.Parent          = LocalPlayer.PlayerGui

-- editActive must be declared here so makeButton closures below can see it
local editActive = false

-- ============================================================
--  ATTRIBUTION PANEL  — "Fly Animation Script / Made by DanielCheeseSauce"
-- ============================================================
local attrFrame = Instance.new("Frame")
attrFrame.Name                  = "Attribution"
attrFrame.Size                  = UDim2.new(0, 270, 0, 90)
attrFrame.Position              = UDim2.new(0, 16, 0, 16)
attrFrame.BackgroundColor3      = Color3.fromRGB(12, 12, 12)
attrFrame.BackgroundTransparency = 0.25
attrFrame.BorderSizePixel       = 0
attrFrame.ZIndex                = 5
attrFrame.Parent                = SG

do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = attrFrame end
do
    local s = Instance.new("UIStroke")
    s.Color        = Color3.fromRGB(255, 220, 50)
    s.Thickness    = 1.5
    s.Transparency = 0.35
    s.Parent       = attrFrame
end

-- Cheese image
-- NOTE: Upload your cheese image to Roblox, then replace 0000000000 with the real asset ID
local attrImg = Instance.new("ImageLabel")
attrImg.Size                 = UDim2.new(0, 70, 0, 70)
attrImg.Position             = UDim2.new(0, 10, 0, 10)
attrImg.BackgroundTransparency = 1
attrImg.Image                = "rbxassetid://0000000000"
attrImg.ScaleType            = Enum.ScaleType.Fit
attrImg.ZIndex               = 6
attrImg.Parent               = attrFrame
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = attrImg end

local attrTitle = Instance.new("TextLabel")
attrTitle.Size               = UDim2.new(1, -94, 0, 36)
attrTitle.Position           = UDim2.new(0, 88, 0, 14)
attrTitle.BackgroundTransparency = 1
attrTitle.TextColor3         = Color3.fromRGB(255, 220, 50)
attrTitle.TextSize           = 15
attrTitle.Font               = Enum.Font.GothamBold
attrTitle.Text               = "Fly Animation Script"
attrTitle.TextXAlignment     = Enum.TextXAlignment.Left
attrTitle.TextWrapped        = true
attrTitle.ZIndex             = 6
attrTitle.Parent             = attrFrame

local attrAuthor = Instance.new("TextLabel")
attrAuthor.Size              = UDim2.new(1, -94, 0, 28)
attrAuthor.Position          = UDim2.new(0, 88, 0, 50)
attrAuthor.BackgroundTransparency = 1
attrAuthor.TextColor3        = Color3.fromRGB(200, 200, 200)
attrAuthor.TextSize          = 12
attrAuthor.Font              = Enum.Font.Gotham
attrAuthor.Text              = "Made by DanielCheeseSauce"
attrAuthor.TextXAlignment    = Enum.TextXAlignment.Left
attrAuthor.TextWrapped       = true
attrAuthor.ZIndex            = 6
attrAuthor.Parent            = attrFrame

-- Fade out the panel after 5 seconds
task.delay(5, function()
    local fadeInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(attrFrame, fadeInfo, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(attrImg,   fadeInfo, { ImageTransparency      = 1 }):Play()
    TweenService:Create(attrTitle, fadeInfo, { TextTransparency       = 1 }):Play()
    TweenService:Create(attrAuthor,fadeInfo, { TextTransparency       = 1 }):Play()
    -- Also fade the stroke
    for _, child in ipairs(attrFrame:GetChildren()) do
        if child:IsA("UIStroke") then
            TweenService:Create(child, fadeInfo, { Transparency = 1 }):Play()
        end
    end
    task.delay(1.3, function() attrFrame:Destroy() end)
end)


-- ============================================================
--  BUTTON FACTORY
--  Tap-vs-drag detection so mobile drag works correctly:
--    • Touch moves < DRAG_THRESH px  → fires callback (tap)
--    • Touch moves >= DRAG_THRESH px → drags the button
-- ============================================================
local DRAG_THRESH = 12  -- pixels of movement before drag kicks in
local WING_ICON   = "rbxassetid://14578418956"

local allButtons = {}

local function makeButton(name, initPos, initSize, label, color, callback)
    local frame = Instance.new("Frame")
    frame.Name                  = name
    frame.Size                  = initSize
    frame.Position              = initPos
    frame.BackgroundColor3      = color
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel       = 0
    frame.Active                = true
    frame.Parent                = SG

    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.18, 0); c.Parent = frame end
    do
        local s = Instance.new("UIStroke")
        s.Color        = Color3.new(1,1,1)
        s.Transparency = 0.65
        s.Thickness    = 1.5
        s.Parent       = frame
    end

    -- Wing icon
    local icon = Instance.new("ImageLabel")
    icon.Size               = UDim2.new(0.52, 0, 0.52, 0)
    icon.Position           = UDim2.new(0.5, 0, 0.22, 0)
    icon.AnchorPoint        = Vector2.new(0.5, 0)
    icon.BackgroundTransparency = 1
    icon.Image              = WING_ICON
    icon.ImageColor3        = Color3.new(1,1,1)
    icon.ScaleType          = Enum.ScaleType.Fit
    icon.Parent             = frame

    local lbl = Instance.new("TextLabel")
    lbl.Name                = "Lbl"
    lbl.Size                = UDim2.new(1, 0, 0.36, 0)
    lbl.Position            = UDim2.new(0, 0, 0.64, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = label
    lbl.TextColor3          = Color3.new(1,1,1)
    lbl.TextScaled          = true
    lbl.Font                = Enum.Font.GothamBold
    lbl.Parent              = frame

    -- --------------------------------------------------------
    -- Input handling via TextButton (catches mobile touches)
    -- --------------------------------------------------------
    local btn = Instance.new("TextButton")
    btn.Size                = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text                = ""
    btn.ZIndex              = 5
    btn.Parent              = frame

    -- Per-touch tracking for drag-vs-tap
    local activeTouches     = {}   -- [InputObject] = {startPos, startFramePos, dragging}
    local currentDragTouch  = nil

    -- Pinch state (two-finger resize)
    local pinchStartDist    = nil
    local pinchStartSize    = nil

    local function getTouchList()
        local list = {}
        for inp, _ in pairs(activeTouches) do table.insert(list, inp) end
        return list
    end

    btn.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        activeTouches[input] = {
            startPos      = input.Position,
            startFramePos = frame.Position,
            dragging      = false,
        }

        -- Check for two-finger pinch start
        local list = getTouchList()
        if #list == 2 then
            pinchStartDist = (list[1].Position - list[2].Position).Magnitude
            pinchStartSize = frame.Size
        end
    end)

    btn.InputChanged:Connect(function(input)
        local info = activeTouches[input]
        if not info then return end

        local list = getTouchList()

        -- Two-finger pinch resize (only in edit mode)
        if #list == 2 and pinchStartDist and pinchStartDist > 0 and editActive then
            local newDist = (list[1].Position - list[2].Position).Magnitude
            local scale   = newDist / pinchStartDist
            local px      = math.clamp((pinchStartSize.X.Offset > 0 and pinchStartSize.X.Offset or 72) * scale, 48, 128)
            frame.Size    = UDim2.new(0, px, 0, px)
            return
        end

        -- Single-finger drag (only allowed in edit mode)
        local delta = input.Position - info.startPos
        if not info.dragging and delta.Magnitude >= DRAG_THRESH and editActive then
            info.dragging   = true
            currentDragTouch = input
        end

        if info.dragging and currentDragTouch == input and editActive then
            frame.Position = UDim2.new(
                info.startFramePos.X.Scale,
                info.startFramePos.X.Offset + delta.X,
                info.startFramePos.Y.Scale,
                info.startFramePos.Y.Offset + delta.Y
            )
        end
    end)

    btn.InputEnded:Connect(function(input)
        local info = activeTouches[input]
        if not info then return end

        -- It was a tap (not a drag) — fire callback
        if not info.dragging then
            callback()
        end

        activeTouches[input] = nil
        if currentDragTouch == input then currentDragTouch = nil end

        local list = getTouchList()
        if #list < 2 then
            pinchStartDist = nil
            pinchStartSize = nil
        end
    end)

    -- PC click
    btn.MouseButton1Click:Connect(function()
        -- Only fire if no touch active (avoids double-fire on mobile)
        if not next(activeTouches) then
            callback()
        end
    end)

    local obj = { frame = frame, lbl = lbl, icon = icon }
    table.insert(allButtons, obj)
    return obj
end

-- ============================================================
--  CREATE BUTTONS
-- ============================================================
local floatBtnObj, flyBtnObj, boostBtnObj, autoPilotBtnObj

floatBtnObj = makeButton("FloatBtn", S.floatBtnPos, S.btnSize, "Float [F]",
    Color3.fromRGB(20, 75, 190),
    function()
        if not State.enabled then return end
        if State.floating then stopFloat() else startFloat() end
    end)

flyBtnObj = makeButton("FlyBtn", S.flyBtnPos, S.btnSize, "Fly [G]",
    Color3.fromRGB(12, 135, 65),
    function()
        if not State.enabled then return end
        if not State.floating then return end
        if State.flying then stopFly() else startFly() end
    end)
flyBtnObj.frame.Visible = false

boostBtnObj = makeButton("BoostBtn", S.boostBtnPos, S.btnSize, "Boost [X]",
    Color3.fromRGB(185, 80, 10),
    function()
        triggerBoost()
    end)
boostBtnObj.frame.Visible = false

-- Shiftlock / Look-around button
-- Positioned left of the boost button by default
shiftlockBtnObj = makeButton("ShiftlockBtn",
    UDim2.new(0.50, 0, 0.80, 0),
    S.btnSize,
    "Look [V]",
    Color3.fromRGB(70, 20, 120),
    function()
        if not State.enabled then return end
        if not State.floating then return end
        setShiftlock(not State.shiftlock)
    end)
shiftlockBtnObj.frame.Visible = false

autoPilotBtnObj = makeButton("AutoPilotBtn",
    S.autoPilotBtnPos,
    S.btnSize,
    "Auto [H]",
    Color3.fromRGB(10, 100, 140),
    function()
        if not State.enabled then return end
        if not State.floating then return end
        setAutoPilot(not State.autoPilot)
    end)
autoPilotBtnObj.frame.Visible = false

-- ============================================================
--  BUTTON STATE UPDATE LOOP
-- ============================================================
RunService.Heartbeat:Connect(function()
    floatBtnObj.frame.Visible      = State.enabled
    flyBtnObj.frame.Visible        = State.enabled and State.floating
    boostBtnObj.frame.Visible      = State.enabled and State.flying
    shiftlockBtnObj.frame.Visible  = State.enabled and State.floating
    autoPilotBtnObj.frame.Visible  = State.enabled and State.floating

    floatBtnObj.lbl.Text = State.floating and "Land [F]" or "Float [F]"
    flyBtnObj.lbl.Text   = State.flying   and "Stop [G]" or "Fly [G]"
    shiftlockBtnObj.lbl.Text = State.shiftlock and "Look ON [V]" or "Look [V]"
    shiftlockBtnObj.frame.BackgroundColor3 = State.shiftlock
        and Color3.fromRGB(120, 20, 180)
        or  Color3.fromRGB(70, 20, 120)
    autoPilotBtnObj.lbl.Text = State.autoPilot and "Auto ON [H]" or "Auto [H]"
    autoPilotBtnObj.frame.BackgroundColor3 = State.autoPilot
        and Color3.fromRGB(0, 180, 220)
        or  Color3.fromRGB(10, 100, 140)

    if State.boostCD then
        boostBtnObj.lbl.Text               = "CD " .. State.boostCDLeft .. "s"
        boostBtnObj.frame.BackgroundColor3 = Color3.fromRGB(100, 55, 10)
    elseif State.boostActive then
        boostBtnObj.lbl.Text               = "BOOST!"
        boostBtnObj.frame.BackgroundColor3 = Color3.fromRGB(220, 170, 0)
    else
        boostBtnObj.lbl.Text               = "Boost [X]"
        boostBtnObj.frame.BackgroundColor3 = Color3.fromRGB(185, 80, 10)
    end
end)

-- ============================================================
--  BUTTON LAYOUT HELPERS
-- ============================================================
local function saveLayout()
    S.floatBtnPos = floatBtnObj.frame.Position
    S.flyBtnPos   = flyBtnObj.frame.Position
    S.boostBtnPos = boostBtnObj.frame.Position
    S.btnSize     = floatBtnObj.frame.Size
end

local function resetLayout()
    floatBtnObj.frame.Position  = D.floatBtnPos
    floatBtnObj.frame.Size      = D.btnSize
    flyBtnObj.frame.Position    = D.flyBtnPos
    flyBtnObj.frame.Size        = D.btnSize
    boostBtnObj.frame.Position  = D.boostBtnPos
    boostBtnObj.frame.Size      = D.btnSize
    saveLayout()
end

-- ============================================================
--  EDIT-LAYOUT MODE
--  Hides Rayfield, shows overlay with Save/Reset/Cancel
-- ============================================================
local function enterEditMode(onDone)
    if editActive then return end
    editActive = true

    local overlay = Instance.new("Frame")
    overlay.Size               = UDim2.new(1,0,1,0)
    overlay.BackgroundTransparency = 1
    overlay.ZIndex             = 20
    overlay.Parent             = SG

    local hint = Instance.new("TextLabel")
    hint.Size               = UDim2.new(0.72, 0, 0.07, 0)
    hint.Position           = UDim2.new(0.14, 0, 0.04, 0)
    hint.BackgroundColor3   = Color3.new(0,0,0)
    hint.BackgroundTransparency = 0.45
    hint.TextColor3         = Color3.new(1,1,1)
    hint.Text               = "Drag to move  |  Pinch to resize"
    hint.TextScaled         = true
    hint.Font               = Enum.Font.GothamSemibold
    hint.ZIndex             = 21
    hint.Parent             = overlay
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.25,0); c.Parent=hint end

    local function makeCtrlBtn(label, xPos, bg, cb)
        local b = Instance.new("TextButton")
        b.Size              = UDim2.new(0.22,0,0.055,0)
        b.Position          = UDim2.new(xPos,0,0.91,0)
        b.BackgroundColor3  = bg
        b.TextColor3        = Color3.new(1,1,1)
        b.Text              = label
        b.TextScaled        = true
        b.Font              = Enum.Font.GothamBold
        b.ZIndex            = 21
        b.Parent            = overlay
        do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.3,0); c.Parent=b end
        b.MouseButton1Click:Connect(cb)
        b.TouchTap:Connect(cb)
    end

    makeCtrlBtn("Save",   0.08, Color3.fromRGB(30,160,60), function()
        saveLayout()
        overlay:Destroy()
        editActive = false
        onDone(true)
    end)
    makeCtrlBtn("Reset",  0.39, Color3.fromRGB(160,120,10), function()
        resetLayout()
        overlay:Destroy()
        editActive = false
        onDone(false)
    end)
    makeCtrlBtn("Cancel", 0.70, Color3.fromRGB(175,30,30), function()
        overlay:Destroy()
        editActive = false
        onDone(false)
    end)
end

-- ============================================================
--  RAYFIELD UI
-- ============================================================
local Window
local RayfieldActive = true

local function buildUI()
    Window = Rayfield:CreateWindow({
        Name                   = "FlyScript",
        Icon                   = 0,
        LoadingTitle           = "FlyScript  v3",
        LoadingSubtitle        = "Float  •  Fly  •  Boost",
        Theme                  = "Default",
        DisableRayfieldPrompts = false,
        DisableBuildWarnings   = false,
        KeySystem              = false,
        ConfigurationSaving    = {
            Enabled    = true,
            FolderName = "FlyScript",
            FileName   = "Config",
        },
        Discord       = { Enabled = false },
        MenuKeybind   = "RightControl",
    })

    -- ────────────────────────────────
    --  MAIN TAB
    -- ────────────────────────────────
    local T = Window:CreateTab("Main", 4483362458)

    T:CreateToggle({
        Name         = "Enable Script",
        CurrentValue = false,
        Callback     = function(v)
            State.enabled = v
            if not v and State.floating then stopFloat() end
        end,
    })

    T:CreateSection("Quick Actions")

    T:CreateButton({ Name = "Toggle Float  [F]", Callback = function()
        if not State.enabled then
            Rayfield:Notify({ Title = "Disabled", Content = "Enable the script first.", Duration = 2 })
            return
        end
        if State.floating then stopFloat() else startFloat() end
    end})

    T:CreateButton({ Name = "Toggle Fly  [G]", Callback = function()
        if not State.enabled then return end
        if not State.floating then
            Rayfield:Notify({ Title = "Not Floating", Content = "Start floating first (F).", Duration = 2 })
            return
        end
        if State.flying then stopFly() else startFly() end
    end})

    T:CreateButton({ Name = "Boost  [X]", Callback = function() triggerBoost() end})

    T:CreateButton({ Name = "Toggle Look-Around / Shiftlock  [V]", Callback = function()
        if not State.enabled then return end
        if not State.floating then
            Rayfield:Notify({ Title = "Not Floating", Content = "Start floating first (F).", Duration = 2 })
            return
        end
        setShiftlock(not State.shiftlock)
    end})

    -- ────────────────────────────────
    --  FLY SETTINGS TAB
    -- ────────────────────────────────
    local FT = Window:CreateTab("Fly Settings", 4483362458)

    FT:CreateSection("Speed")
    FT:CreateSlider({ Name = "Fly Speed",          Range = {5,1000}, Increment = 5,  Suffix = "/s", CurrentValue = S.flySpeed,       Flag = "FlySpeed",  Callback = function(v) S.flySpeed = v end })
    FT:CreateSlider({ Name = "Float Speed",        Range = {2,1000}, Increment = 2,  Suffix = "/s", CurrentValue = S.floatMoveSpeed, Flag = "FloatSpd",  Callback = function(v) S.floatMoveSpeed = v end })

    FT:CreateSection("Acceleration")
    FT:CreateToggle({ Name = "Acceleration (off = instant)", CurrentValue = S.accelEnabled, Flag = "AccelOn",
        Callback = function(v) S.accelEnabled = v end })
    FT:CreateSlider({ Name = "Fly Accel  (1=very slow → 50=very fast)", Range = {1,50}, Increment = 1, CurrentValue = S.flyAccel,   Flag = "FlyAccel",  Callback = function(v) S.flyAccel = v end })
    FT:CreateSlider({ Name = "Float Accel (1=very slow → 50=very fast)",Range = {1,50}, Increment = 1, CurrentValue = S.floatAccel, Flag = "FloatAccel",Callback = function(v) S.floatAccel = v end })

    FT:CreateSection("Tilt")
    FT:CreateSlider({ Name = "Tilt Float", Range = {0, 5}, Increment = 1, CurrentValue = S.floatTilt, Flag = "FloatTilt",
        Callback = function(v) S.floatTilt = v end })

    FT:CreateSection("Animations")
    FT:CreateToggle({ Name = "Play Animations", CurrentValue = S.flyAnimEnabled, Flag = "AnimOn",
        Callback = function(v)
            S.flyAnimEnabled = v
            if not v then stopAllTracks() end
        end
    })

    FT:CreateInput({ Name = "Fly Anim ID",        PlaceholderText = S.flyAnimId,        RemoveTextAfterFocusLost = false, Flag = "FlyAnimId",
        Callback = function(v) if v ~= "" then S.flyAnimId = v; reloadAnims(); Rayfield:Notify({Title="Reloaded",Content="Fly anim updated.",Duration=2}) end end })
    FT:CreateInput({ Name = "Float Idle Anim ID", PlaceholderText = S.floatIdleAnimId,  RemoveTextAfterFocusLost = false, Flag = "FloatIdleId",
        Callback = function(v) if v ~= "" then S.floatIdleAnimId = v; reloadAnims(); Rayfield:Notify({Title="Reloaded",Content="Float idle updated.",Duration=2}) end end })
    FT:CreateInput({ Name = "Float Move Anim ID", PlaceholderText = S.floatMoveAnimId,  RemoveTextAfterFocusLost = false, Flag = "FloatMoveId",
        Callback = function(v) if v ~= "" then S.floatMoveAnimId = v; reloadAnims(); Rayfield:Notify({Title="Reloaded",Content="Float move updated.",Duration=2}) end end })

    -- ────────────────────────────────
    --  BOOST TAB
    -- ────────────────────────────────
    local BT = Window:CreateTab("Boost", 4483362458)
    BT:CreateSection("Boost Settings")
    BT:CreateSlider({ Name = "Boost %",              Range = {110,600}, Increment = 10, Suffix = "%",  CurrentValue = S.boostPct,      Flag = "BoostPct",   Callback = function(v) S.boostPct = v end })
    BT:CreateSlider({ Name = "Duration (sec)",        Range = {1,20},    Increment = 1,  Suffix = "s",  CurrentValue = S.boostDuration, Flag = "BoostDur",   Callback = function(v) S.boostDuration = v end })
    BT:CreateSlider({ Name = "Cooldown (sec)",        Range = {1,30},    Increment = 1,  Suffix = "s",  CurrentValue = S.boostCooldown, Flag = "BoostCD",    Callback = function(v) S.boostCooldown = v end })
    BT:CreateSlider({ Name = "Boost Acceleration",    Range = {1,50},    Increment = 1,               CurrentValue = S.boostAccel,    Flag = "BoostAccel", Callback = function(v) S.boostAccel = v end })
    BT:CreateSlider({ Name = "Boost FOV %  (of Max)", Range = {100,400}, Increment = 5,  Suffix = "%",  CurrentValue = S.boostFovPct,   Flag = "BoostFovPct",Callback = function(v) S.boostFovPct = v end })

    -- ────────────────────────────────
    --  EFFECTS TAB
    -- ────────────────────────────────
    local ET = Window:CreateTab("Effects", 4483362458)
    ET:CreateSection("FOV Acceleration")
    ET:CreateToggle({ Name = "Enable FOV Acceleration", CurrentValue = S.fovEnabled, Flag = "FOVOn",
        Callback = function(v)
            S.fovEnabled = v
            if not v then TweenService:Create(Camera, TweenInfo.new(0.5), { FieldOfView = State.defaultFOV }):Play() end
        end
    })
    ET:CreateSlider({ Name = "Max FOV",        Range = {70,500}, Increment = 5,  CurrentValue = S.fovMax,  Flag = "FOVMax",  Callback = function(v) S.fovMax = v end })
    ET:CreateSlider({ Name = "FOV Accel Rate", Range = {5,100},  Increment = 5,  CurrentValue = S.fovRate, Flag = "FOVRate", Callback = function(v) S.fovRate = v end })

    -- ────────────────────────────────
    --  MUSIC TAB
    -- ────────────────────────────────
    local MT = Window:CreateTab("Music", 4483362458)
    MT:CreateSection("Background Music")
    MT:CreateToggle({ Name = "Enable Music", CurrentValue = S.musicEnabled, Flag = "MusicOn",
        Callback = function(v)
            S.musicEnabled = v
            if v and S.musicId ~= "" then
                Sounds.music:Play()
            else
                Sounds.music:Stop()
            end
        end
    })
    MT:CreateInput({ Name = "Music ID  (Roblox sound ID)", PlaceholderText = "e.g. 1837244335", RemoveTextAfterFocusLost = false, Flag = "MusicId",
        Callback = function(v)
            S.musicId = v
            reloadSoundId("music", v)
            if S.musicEnabled and v ~= "" then Sounds.music:Play() end
            Rayfield:Notify({ Title = "Music", Content = v == "" and "Music ID cleared." or "Music ID set.", Duration = 2 })
        end
    })
    MT:CreateSlider({ Name = "Music Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.musicVolume, Flag = "MusicVol",
        Callback = function(v) S.musicVolume = v; if Sounds.music then Sounds.music.Volume = v / 100 end end })
    MT:CreateSlider({ Name = "Music Distance (studs)", Range = {10,500}, Increment = 10, Suffix = " st", CurrentValue = S.musicDist, Flag = "MusicDist",
        Callback = function(v) S.musicDist = v; applyRollOff(Sounds.music, v, S.musicFade) end })
    MT:CreateToggle({ Name = "Music Fade (gets louder as you approach)", CurrentValue = S.musicFade, Flag = "MusicFade",
        Callback = function(v) S.musicFade = v; applyRollOff(Sounds.music, S.musicDist, v) end })

    -- ────────────────────────────────
    --  SOUND EFFECTS TAB
    -- ────────────────────────────────
    local SE = Window:CreateTab("Sound FX", 4483362458)

    -- ── Fly Sound ──────────────────────────────────────────────
    SE:CreateSection("Fly Sound  (fades in while flying, fades out when you stop)")
    SE:CreateInput({ Name = "Fly SFX ID", PlaceholderText = "Roblox sound ID", RemoveTextAfterFocusLost = false, Flag = "SFXFlyId",
        Callback = function(v) S.sfxFlyId = v; reloadSoundId("fly", v); Rayfield:Notify({ Title = "Fly SFX", Content = v == "" and "Cleared." or "Set!", Duration = 2 }) end })
    SE:CreateSlider({ Name = "Fly SFX Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxFlyVolume, Flag = "SFXFlyVol",
        Callback = function(v) S.sfxFlyVolume = v end })
    SE:CreateSlider({ Name = "Fly SFX Distance (studs)", Range = {10,500}, Increment = 10, Suffix = " st", CurrentValue = S.sfxFlyDist, Flag = "SFXFlyDist",
        Callback = function(v) S.sfxFlyDist = v; applyRollOff(Sounds.fly, v, S.sfxFlyFade) end })
    SE:CreateToggle({ Name = "Fly SFX Fade (louder the closer you are)", CurrentValue = S.sfxFlyFade, Flag = "SFXFlyFade",
        Callback = function(v) S.sfxFlyFade = v; applyRollOff(Sounds.fly, S.sfxFlyDist, v) end })
    SE:CreateSlider({ Name = "Fly Speed Trigger  (sound starts fading in at this speed)", Range = {0,200}, Increment = 5, Suffix = "/s", CurrentValue = S.sfxFlySpeedMin, Flag = "SFXFlySpd",
        Callback = function(v) S.sfxFlySpeedMin = v end })

    -- ── Boost Hit ──────────────────────────────────────────────
    SE:CreateSection("Boost Hit  (plays once when boost activates)")
    SE:CreateInput({ Name = "Boost Hit SFX ID", PlaceholderText = "Roblox sound ID", RemoveTextAfterFocusLost = false, Flag = "SFXBoostHitId",
        Callback = function(v) S.sfxBoostHitId = v; reloadSoundId("boostHit", v); Rayfield:Notify({ Title = "Boost Hit SFX", Content = v == "" and "Cleared." or "Set!", Duration = 2 }) end })
    SE:CreateSlider({ Name = "Boost Hit Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxBoostHitVolume, Flag = "SFXBoostHitVol",
        Callback = function(v) S.sfxBoostHitVolume = v; if Sounds.boostHit then Sounds.boostHit.Volume = v / 100 end end })
    SE:CreateSlider({ Name = "Boost Hit Distance (studs)", Range = {10,500}, Increment = 10, Suffix = " st", CurrentValue = S.sfxBoostHitDist, Flag = "SFXBHDist",
        Callback = function(v) S.sfxBoostHitDist = v; applyRollOff(Sounds.boostHit, v, S.sfxBoostHitFade) end })
    SE:CreateToggle({ Name = "Boost Hit Fade (louder the closer you are)", CurrentValue = S.sfxBoostHitFade, Flag = "SFXBHFade",
        Callback = function(v) S.sfxBoostHitFade = v; applyRollOff(Sounds.boostHit, S.sfxBoostHitDist, v) end })

    -- ── Boost Loop ─────────────────────────────────────────────
    SE:CreateSection("Boost Loop  (loops while boost is active)")
    SE:CreateInput({ Name = "Boost Loop SFX ID", PlaceholderText = "Roblox sound ID", RemoveTextAfterFocusLost = false, Flag = "SFXBoostLoopId",
        Callback = function(v) S.sfxBoostLoopId = v; reloadSoundId("boostLoop", v); Rayfield:Notify({ Title = "Boost Loop SFX", Content = v == "" and "Cleared." or "Set!", Duration = 2 }) end })
    SE:CreateSlider({ Name = "Boost Loop Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxBoostLoopVolume, Flag = "SFXBoostLoopVol",
        Callback = function(v) S.sfxBoostLoopVolume = v; if Sounds.boostLoop then Sounds.boostLoop.Volume = v / 100 end end })
    SE:CreateSlider({ Name = "Boost Loop Distance (studs)", Range = {10,500}, Increment = 10, Suffix = " st", CurrentValue = S.sfxBoostLoopDist, Flag = "SFXBLDist",
        Callback = function(v) S.sfxBoostLoopDist = v; applyRollOff(Sounds.boostLoop, v, S.sfxBoostLoopFade) end })
    SE:CreateToggle({ Name = "Boost Loop Fade (louder the closer you are)", CurrentValue = S.sfxBoostLoopFade, Flag = "SFXBLFade",
        Callback = function(v) S.sfxBoostLoopFade = v; applyRollOff(Sounds.boostLoop, S.sfxBoostLoopDist, v) end })

    -- ── Near-Player Fly ────────────────────────────────────────
    SE:CreateSection("Near-Player Fly  (plays when close to other players while flying)")
    SE:CreateInput({ Name = "Near-Player SFX ID", PlaceholderText = "Roblox sound ID", RemoveTextAfterFocusLost = false, Flag = "SFXNearFlyId",
        Callback = function(v) S.sfxNearFlyId = v; reloadSoundId("nearFly", v); Rayfield:Notify({ Title = "Near-Player SFX", Content = v == "" and "Cleared." or "Set!", Duration = 2 }) end })
    SE:CreateSlider({ Name = "Near-Player SFX Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxNearFlyVolume, Flag = "SFXNearVol",
        Callback = function(v) S.sfxNearFlyVolume = v; if Sounds.nearFly then Sounds.nearFly.Volume = v / 100 end end })
    SE:CreateSlider({ Name = "Near-Player Distance (studs)", Range = {10,500}, Increment = 10, Suffix = " st", CurrentValue = S.sfxNearFlyDist, Flag = "SFXNearDist",
        Callback = function(v) S.sfxNearFlyDist = v; applyRollOff(Sounds.nearFly, v, S.sfxNearFlyFade) end })
    SE:CreateToggle({ Name = "Near-Player Fade (louder the closer you are)", CurrentValue = S.sfxNearFlyFade, Flag = "SFXNearFade",
        Callback = function(v) S.sfxNearFlyFade = v; applyRollOff(Sounds.nearFly, S.sfxNearFlyDist, v) end })
    SE:CreateSlider({ Name = "Trigger Radius (studs)", Range = {5,200}, Increment = 5, Suffix = " st", CurrentValue = S.nearPlayerRadius, Flag = "NearRadius",
        Callback = function(v) S.nearPlayerRadius = v end })

    -- ────────────────────────────────
    --  SETTINGS TAB
    -- ────────────────────────────────
    local ST = Window:CreateTab("Settings", 4483362458)

    ST:CreateSection("Keybinds")
    ST:CreateKeybind({ Name = "Float Key", CurrentKeybind = "F", HoldToInteract = false, Flag = "FloatKey",
        Callback = function(k) local kc = Enum.KeyCode[k]; if kc then S.floatKey = kc end end })
    ST:CreateKeybind({ Name = "Fly Key (while floating)", CurrentKeybind = "G", HoldToInteract = false, Flag = "FlyKey",
        Callback = function(k) local kc = Enum.KeyCode[k]; if kc then S.flyKey = kc end end })
    ST:CreateKeybind({ Name = "Boost Key", CurrentKeybind = "X", HoldToInteract = false, Flag = "BoostKey",
        Callback = function(k) local kc = Enum.KeyCode[k]; if kc then S.boostKey = kc end end })
    ST:CreateKeybind({ Name = "Look-Around / Shiftlock Key", CurrentKeybind = "V", HoldToInteract = false, Flag = "ShiftlockKey",
        Callback = function(k) local kc = Enum.KeyCode[k]; if kc then S.shiftlockKey = kc end end })

    ST:CreateKeybind({ Name = "Auto-Pilot Key", CurrentKeybind = "H", HoldToInteract = false, Flag = "AutoPilotKey",
        Callback = function(k) local kc = Enum.KeyCode[k]; if kc then S.autoPilotKey = kc end end })

    ST:CreateSection("Auto-Pilot On Fly Press")
    ST:CreateToggle({ Name = "Auto-Pilot on Fly Start", CurrentValue = S.autoPilotOnStart, Flag = "AutoPilotOnStart",
        Callback = function(v) S.autoPilotOnStart = v end })
    ST:CreateSlider({ Name = "Auto-Pilot Duration (sec)", Range = {1, 60}, Increment = 1, Suffix = "s",
        CurrentValue = S.autoPilotOnStartDur, Flag = "AutoPilotDur",
        Callback = function(v) S.autoPilotOnStartDur = v end })

    ST:CreateSection("Double Keybind (Secondary Key)")
    ST:CreateInput({ Name = "Float Secondary Key", PlaceholderText = "e.g. RightShift", RemoveTextAfterFocusLost = false, Flag = "FloatKey2",
        Callback = function(v)
            if v == "" then S.floatKey2 = nil; return end
            local kc = Enum.KeyCode[v]
            if kc then S.floatKey2 = kc; Rayfield:Notify({Title="Set",Content=v.." = secondary Float key",Duration=2})
            else Rayfield:Notify({Title="Invalid",Content=v.." is not a valid KeyCode",Duration=2}) end
        end
    })
    ST:CreateInput({ Name = "Fly Secondary Key", PlaceholderText = "e.g. RightAlt", RemoveTextAfterFocusLost = false, Flag = "FlyKey2",
        Callback = function(v)
            if v == "" then S.flyKey2 = nil; return end
            local kc = Enum.KeyCode[v]
            if kc then S.flyKey2 = kc; Rayfield:Notify({Title="Set",Content=v.." = secondary Fly key",Duration=2})
            else Rayfield:Notify({Title="Invalid",Content=v.." is not a valid KeyCode",Duration=2}) end
        end
    })

    ST:CreateSection("Button Layout")
    ST:CreateButton({ Name = "Edit Buttons (drag & resize)", Callback = function()
        enterEditMode(function(_)
            Rayfield:Notify({ Title = "Layout", Content = "Changes saved.", Duration = 2 })
        end)
    end})
    ST:CreateButton({ Name = "Reset Button Positions", Callback = function()
        resetLayout()
        Rayfield:Notify({ Title = "Reset", Content = "Buttons returned to default.", Duration = 2 })
    end})

    ST:CreateSection("Freecam / Spectator")
    ST:CreateButton({ Name = "Toggle Freecam  [M on PC]", Callback = function()
        if State.freecam then stopFreecam() else startFreecam() end
    end})
    ST:CreateSlider({ Name = "Freecam Speed", Range = {5, 200}, Increment = 5, Suffix = "/s",
        CurrentValue = FC.speed, Flag = "FreecamSpeed",
        Callback = function(v) FC.speed = v end })

    ST:CreateSection("Script")
    ST:CreateButton({ Name = "Destroy Script", Callback = function()
        if State.floating then stopFloat() end
        if State.freecam then stopFreecam() end
        SG:Destroy()
        Rayfield:Destroy()
    end})
end

-- ============================================================
--  RESPAWN HANDLER
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.6)   -- wait for character to fully load

    State.floating  = false
    State.flying    = false
    State.boostActive = false
    State.boostCD   = false
    State.lerpSpeed = 0
    mobileStick     = Vector2.zero

    destroyMovers()
    reloadAnims()

    -- Rebuild sounds on the new character's HumanoidRootPart
    buildSounds()
end)

-- ============================================================
--  LAUNCH
-- ============================================================
buildUI()

Rayfield:Notify({
    Title   = "FlyScript v3 Ready",
    Content = "F = Float  |  G = Fly  |  X = Boost  |  V = Look-Around  |  H = Auto-Pilot\nAim crosshair to steer  •  Emote anims loaded",
    Duration = 7,
})
