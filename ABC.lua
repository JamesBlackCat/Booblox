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
local Lighting          = game:GetService("Lighting")
local PhysicsService    = game:GetService("PhysicsService")
local InsertService     = game:GetService("InsertService")
local Camera            = workspace.CurrentCamera

-- Collision groups: keep impact debris from ever pushing the player
local FX_GROUP     = "FlyScriptFX"
local PLAYER_GROUP = "FlyScriptPlayer"
pcall(function() PhysicsService:RegisterCollisionGroup(FX_GROUP) end)
pcall(function() PhysicsService:RegisterCollisionGroup(PLAYER_GROUP) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable(FX_GROUP, PLAYER_GROUP, false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable(FX_GROUP, FX_GROUP, false) end)

local function applyPlayerGroup(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p.CollisionGroup = PLAYER_GROUP end)
        end
    end
    char.DescendantAdded:Connect(function(p)
        if p:IsA("BasePart") then
            pcall(function() p.CollisionGroup = PLAYER_GROUP end)
        end
    end)
end

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
    -- Speed-freeze (pause acceleration at threshold then continue)
    freezeActive    = false,
    freezeDone      = false,
    freezeStartTime = 0,
}

-- ============================================================
--  DEFAULTS / SETTINGS
-- ============================================================
local D = {
    flySpeed             = 50,
    flyAnimId            = "134861929761233",
    floatIdleAnimId      = "126351819085633",
    floatMoveAnimId      = "73017334485905",
    -- Directional fly anims (empty = falls back to fly / floatIdle)
    flyForwardAnimId     = "",
    flyBackwardAnimId    = "",
    flyLeftAnimId        = "",
    flyRightAnimId       = "",
    directionalAnimsEnabled = true,
    directionalTilt      = 1,         -- multiplier for body tilt during directional movement
    -- Speed-freeze settings (pauses acceleration at threshold for a short beat)
    speedFreezeEnabled   = true,
    speedFreezeAt        = 100,
    speedFreezeDuration  = 0.6,
    -- Cinematic camera (subtle additive effects only â€” does NOT replace camera)
    cinematicEnabled     = false,
    cinematicLag         = 1,         -- 0..3 strength of lateral/vertical lag
    cinematicRoll        = 1,         -- 0..3 strength of roll during strafing
    cinematicFovBoost    = 6,         -- extra FOV at top speed while cinematic is on
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
    -- Environmental ambience SFX (loops in the world while script is on)
    sfxEnvId             = "",
    sfxEnvVolume         = 60,
    sfxEnvDist           = 200,
    sfxEnvFade           = true,
    sfxEnvEnabled        = false,
    -- â”€â”€ Client Impacts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    impactsEnabled            = false, -- master toggle (off by default; user must enable)
    impactMinSpeed            = 40,
    impactSlideEnabled        = false,
    impactSlideRate           = 0.05,
    impactSpeedScaleStart     = 200,
    impactSpeedScaleMaxSpeed  = 10000,
    impactMaxRadius           = 2000,
    impactBaseRadius          = 6,
    -- per-effect enable toggles (all off by default)
    fxShockwaveEnabled        = false,
    fxDebrisEnabled           = false,
    fxCracksEnabled           = false,
    fxDustEnabled             = false,
    fxEnergyPulseEnabled      = false,
    fxSpeedTrailEnabled       = false,
    -- per-effect size multipliers (1 = normal)
    fxShockwaveSize           = 1,
    fxDebrisSize              = 1,
    fxCracksSize              = 1,
    fxDustSize                = 1,
    fxEnergyPulseSize         = 1,
    -- speed thresholds
    fxShockwaveTrigger        = 50,
    fxDebrisTrigger           = 60,
    fxCracksTrigger           = 100,
    fxDustTrigger             = 30,
    fxEnergyPulseTrigger      = 150,
    fxSpeedTrailTrigger       = 250,
    -- per-impact sound ids + volumes (one-shot at impact position)
    sfxShockwaveId            = "",
    sfxShockwaveVol           = 80,
    sfxDebrisId               = "",
    sfxDebrisVol              = 80,
    sfxCracksId               = "",
    sfxCracksVol              = 80,
    sfxDustId                 = "",
    sfxDustVol                = 80,
    sfxEnergyPulseId          = "",
    sfxEnergyPulseVol         = 80,
    sfxSpeedTrailId           = "",
    sfxSpeedTrailVol          = 60,
    sfxSlideId                = "",
    sfxSlideVol               = 60,
    sfxCraterId               = "",
    sfxCraterVol              = 80,
    sfxDigId                  = "",
    sfxDigVol                 = 60,
    sfxPhaseId                = "",
    sfxPhaseVol               = 80,
    -- debris settings
    debrisChunksMax           = 12,
    debrisSmallCount          = 6,
    debrisMediumCount         = 3,
    debrisLargeCount          = 1,
    debrisDespawnSec          = 5,
    debrisCanCollide          = false, -- OFF by default to prevent player from being flung
    debrisGlobalMax           = 80,    -- hard cap on simultaneous debris parts (oldest culled)
    -- crater / digging
    craterEnabled             = false,
    craterDepthMul            = 1,
    -- Crater on bricks: when a hard land hits a part whose smallest axis is
    -- â‰¥ craterPartMinSize, the part is split into many smaller pieces forming
    -- a crater pattern instead of just leaving a crack decal.
    craterPartEnabled         = false,
    craterPartMinSize         = 8,     -- studs â€” only parts whose LARGEST axis is â‰¥ this get craterized
                                        -- (use largest axis so thin huge baseplates still qualify)
    craterPartMaxSize         = 2000,  -- studs â€” don't try to craterize ridiculously big parts
    craterPartChunkSize       = 4,     -- studs â€” approx voxel chunk size when splitting
    craterPartMinSpeed        = 60,    -- only at hard impact speeds
    digTerrainWhileFlying     = false,
    digMinSpeed               = 80,
    impactAffectParts         = true,
    -- phase-through small parts (now uses an adjustable HITBOX, not a thin ray)
    phaseEnabled              = false,
    phaseMaxPartSize          = 12,
    phaseLeaveHole            = true,
    phaseMinSpeed             = 60,
    phaseHitboxSize           = 20,    -- studs â€” size of the box around player used to detect parts
    -- map reset
    autoRefreshMapEnabled     = false,
    autoRefreshMinutes        = 10,    -- 1..120
    -- â”€â”€ Acceleration enhancement â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    accelPhase1Cap            = 100,   -- speed below which accel is "normal"
    accelAbove100Mul          = 1,     -- 1 = normal slow-climb, lower = even slower above 100
    -- â”€â”€ Secret: Stages â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    stagesEnabled             = true,  -- master enable for the secret system
    stage1ToStage2Studs       = 100000,
    stage2ToStage3Studs       = 20000,
    stage3ToStage4Studs       = 20000,
    farFromMapDist            = 500,   -- studs â€” distance from any workspace part to count as "far away"
    earthReturnDist           = 800,   -- studs â€” touch range to return to stage 1 from stage 2
    solarReturnDist           = 1500,  -- touch range to return to stage 2 from stage 3
    planetExitDist            = 400,   -- touch range in stage 4 â†’ respawn at spawn
    showStudsHud              = false, -- legacy: HUD is now off by default; use Studs button notification instead
    -- â”€â”€ Secret: World mode (Robloxia / Alien) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    -- Unlocked after passing through the Stage 4 alien planet.
    -- When alienWorldActive = true: green lighting, other players wear alien hat + play alien chat SFX.
    alienWorldUnlocked        = false, -- becomes true once user passes through the alien planet
    alienWorldActive          = false, -- toggle in Settings â–¸ World â–¸ Alien World
    -- â”€â”€ Aimlock â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    aimlockEnabled            = false,
    aimlockFOV                = 200,   -- screen-space pixel radius the lock can grab targets in
    aimlockRange              = 1000,  -- max world distance to consider a target
    aimlockTeamCheck          = true,
    aimlockFriendCheck        = true,  -- skip Roblox friends (bypassed for Lock-List players)
    aimlockWallCheck          = true,
    aimlockShowFOV            = true,  -- draw the FOV circle on screen when aimlock is on
    aimlockPart               = "Head",-- target part name
    aimlockCrosshairPos       = UDim2.new(0.5, 0, 0.5, 0),
    aimlockKey                = Enum.KeyCode.P,
    aimlockBtnPos             = UDim2.new(0.34, 0, 0.80, 0),
    -- Sticky lock: once a target is acquired, KEEP locking them until aimlock
    -- is turned off OR they die. Ignores anyone else, even closer to crosshair.
    aimlockStickyLock         = true,
    -- Smart AI: predicts target position from their velocity so a moving
    -- player isn't behind your reticle. Strength 0 = no lead, 1 = full lead.
    aimlockSmartAI            = true,
    aimlockPredictStrength    = 1.0,
    -- Smoothing: 1 = instant snap, 0.05 = very gentle / human-like camera glide.
    aimlockSmoothing          = 0.55,
    -- Max degrees the camera can rotate per frame (anti-snap; 0 disables limit).
    aimlockMaxDegPerFrame     = 0,
    -- Auto-reacquire if Sticky lock loses sight (wall/out of range) for N seconds.
    aimlockReacquireDelay     = 0.6,
    -- CURSOR MODE â€” when on, target lands exactly at the crosshair pixel
    -- (camera rotates so the target is under the cursor, not center). When
    -- off, the camera centers the target like classic aimbots.
    aimlockCursorMode         = true,
    -- Hold-to-aim â€” when on, aimlock only engages while the keybind is held
    -- (or the on-screen button is being touched). Off = toggle behavior.
    aimlockHoldToAim          = false,
    -- Body-part priority chain. First valid one is used.
    aimlockPartChain          = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" },
    -- Humanizer â€” random small pixel offset added to the aim each frame so the
    -- aim doesn't look mechanically perfect (0 = robot precision).
    aimlockHumanize           = 0,        -- pixels of random jitter (default off â€” was causing visible aim shake)
    -- Acceleration prediction â€” adds a half-aÂ²tÂ² term using cached velocity diff.
    aimlockPredictAccel       = false,    -- default off â€” noisy accel readings amplify shake
    -- Hit-chance â€” ignore aiming on this percentage of frames (anti-detection).
    aimlockMissChance         = 0,        -- 0..40 %
    -- FOV ring color
    aimlockFOVColorR          = 255,
    aimlockFOVColorG          = 60,
    aimlockFOVColorB          = 60,
    -- Target Lock (priority list: targets listed here are preferred over anyone else inside the FOV,
    -- even if friend-check is on)
    targetLockEnabled         = false,
    targetLockList            = {},  -- map of [lowercase player name] = true
    -- Customisable image IDs (overridable in Edit Controls / settings)
    aimlockCrosshairImg       = "rbxassetid://107058246184363",
    aimlockOffImg             = "rbxassetid://124959989742325",
    aimlockOnImg              = "rbxassetid://119279898696244",
    -- Alien world skybox (space)
    alienSkyboxId             = 136402262,
    -- â”€â”€ Studs Notification button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    studsBtnPos               = UDim2.new(0.18, 0, 0.80, 0),
    studsBtnImg               = "rbxassetid://6034973115", -- info icon (overridable)
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
--  Catalog emote items are WRAPPER assets â€” the actual animation
--  lives inside them. We use game:GetObjects() to unpack the
--  real AnimationId before loading the track on the Animator.
-- ============================================================
local tracks = {
    floatIdle   = nil,
    floatMove   = nil,
    fly         = nil,
    flyForward  = nil,
    flyBackward = nil,
    flyLeft     = nil,
    flyRight    = nil,
}

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

    -- Attempt to load the asset via GetObjects â€” this unpacks catalog emote bundles
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

    local raw = tostring(rawId or "")
    if raw == "" then return nil end
    local numId = raw:match("%d+")
    if not numId then return nil end

    -- Try to unwrap the asset.  It might be:
    --   â€¢ a direct Animation
    --   â€¢ a catalog emote bundle (Folder/Model containing an Animation)
    --   â€¢ a Roblox animation package (Model with nested Animations)
    -- We always extract the inner AnimationId string and load a fresh
    -- Animation we own, which is the most reliable across executors.
    local resolvedId = numId

    local ok, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. numId)
    end)
    if ok and objects then
        for _, obj in ipairs(objects) do
            local animObj
            if obj:IsA("Animation") then
                animObj = obj
            else
                animObj = obj:FindFirstChildOfClass("Animation")
                       or obj:FindFirstChildWhichIsA("Animation", true)
            end
            if animObj then
                local inner = tostring(animObj.AnimationId or ""):match("%d+")
                if inner and inner ~= "0" then
                    resolvedId = inner
                    break
                end
            end
        end
    end

    local a = Instance.new("Animation")
    a.AnimationId = "rbxassetid://" .. resolvedId

    local ok2, track = pcall(function()
        local t = animr:LoadAnimation(a)
        t.Priority = Enum.AnimationPriority.Action4
        return t
    end)
    a:Destroy()

    if ok2 and track then return track end
    return nil
end

local function reloadAnims()
    stopAllTracks()
    local _, _, _, animr = getCharParts()
    if not animr then return end
    tracks.floatIdle   = loadAnim(S.floatIdleAnimId,  animr)
    tracks.floatMove   = loadAnim(S.floatMoveAnimId,  animr)
    tracks.fly         = loadAnim(S.flyAnimId,        animr)
    tracks.flyForward  = S.flyForwardAnimId  ~= "" and loadAnim(S.flyForwardAnimId,  animr) or nil
    tracks.flyBackward = S.flyBackwardAnimId ~= "" and loadAnim(S.flyBackwardAnimId, animr) or nil
    tracks.flyLeft     = S.flyLeftAnimId     ~= "" and loadAnim(S.flyLeftAnimId,     animr) or nil
    tracks.flyRight    = S.flyRightAnimId    ~= "" and loadAnim(S.flyRightAnimId,    animr) or nil
end

reloadAnims()

-- ============================================================
--  SOUND SYSTEM
-- ============================================================
local Sounds = { music = nil, fly = nil, boostHit = nil, boostLoop = nil, nearFly = nil, env = nil }

--[[
    makeSound â€” creates a 3D spatial Sound on the character's HumanoidRootPart.
    dist  = RollOffMaxDistance (how far others can hear it)
    fade  = true  â†’ volume fades linearly from ~10 studs to dist
            false â†’ full volume up to dist, then silence (RollOffMin = dist)
--]]
local function makeSound(name, looped, volume, id, dist, fade, parent)
    local s = Instance.new("Sound")
    s.Name               = name
    s.Looped             = looped
    s.Volume             = volume / 100
    s.RollOffMaxDistance = dist or 100
    s.RollOffMode        = Enum.RollOffMode.Linear
    if not fade then
        s.RollOffMinDistance = dist or 100  -- flat volume â†’ sudden cutoff
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
    Sounds.env      = makeSound("FSEnv",        true,  S.sfxEnvVolume,      S.sfxEnvId,      S.sfxEnvDist,      S.sfxEnvFade,      p)
    if S.musicEnabled and S.musicId ~= "" then Sounds.music:Play() end
    if S.sfxEnvEnabled and S.sfxEnvId ~= "" then Sounds.env:Play() end
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
--  MOVEMENT DIRECTION  â€” Camera-directed / Crosshair-based
--
--  W/S  â†’ move along the FULL camera LookVector (including pitch up/down)
--  A/D  â†’ strafe along camera RightVector
--  E/Space â†’ rise straight up   Q â†’ sink straight down
--  Mobile thumbstick forward   â†’ camera LookVector (full 3D pitch included)
--  Mobile thumbstick side      â†’ camera RightVector
--
--  Result: wherever your crosshair points, that's where you fly.
--  You can look around freely without it changing direction until
--  you press a movement key â€” just like Iron Man / Anthem flight.
-- ============================================================

-- Store the raw thumbstick values updated by the mobile hook below
local mobileStick = Vector2.zero   -- X = strafe, Y = forward

local function getMoveDir()
    -- Auto-pilot: fly in the direction that was captured when auto-pilot was enabled
    if State.autoPilot then
        return State.autoPilotDir
    end

    local camCF   = Camera.CFrame
    -- Full 3D camera vectors â€” NOT flattened to horizontal
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
    -- Reset speed-freeze so each new fly session re-triggers it once
    State.freezeActive    = false
    State.freezeDone      = false
    State.freezeStartTime = 0
    State.lerpSpeed       = 0
    -- Zero velocity so pressing fly doesn't lurch the character forward
    if BV then BV.Velocity = Vector3.zero end
    stopAllTracks()
    if S.flyAnimEnabled and tracks.fly then
        tracks.fly:Play()
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
--  HEARTBEAT â€” movement, tilt, animations, FOV
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

    local rawAccel = State.flying
        and (State.boostActive and S.boostAccel or S.flyAccel)
        or S.floatAccel
    -- Acceleration normalization: 50 on the slider == 100% (1.0Ã— baseline).
    -- Two-phase ramp:
    --   Phase 1 (lerpSpeed < accelPhase1Cap)  â†’ full normal acceleration up to the cap
    --   Phase 2 (lerpSpeed â‰¥ accelPhase1Cap)  â†’ slow climb beyond the cap, scaled by
    --                                            accelAbove100Mul Ã— (cap / targetSpeed)
    local accelMul     = rawAccel / 50
    local cap          = S.accelPhase1Cap or 100
    local effectiveTarget
    local speedSlowdown = 1
    if targetSpeed <= cap then
        effectiveTarget = targetSpeed
    elseif State.lerpSpeed < cap then
        -- Still climbing through Phase 1 â†’ cap interim target at `cap`
        effectiveTarget = cap
    else
        -- Phase 2: gradual climb from cap â†’ targetSpeed
        effectiveTarget = targetSpeed
        speedSlowdown   = math.clamp((cap / targetSpeed) * (S.accelAbove100Mul or 1), 0.02, 1)
    end
    local accel = 8 * accelMul * speedSlowdown

    -- Speed-freeze: while flying with a high target speed, briefly hold the
    -- lerp at the freeze threshold before continuing up to the real target.
    -- Only triggers once per fly session and is skipped during boost.
    if State.flying and S.speedFreezeEnabled and not State.freezeDone
        and not State.boostActive and S.flySpeed > S.speedFreezeAt then
        if State.freezeActive then
            if tick() - State.freezeStartTime >= S.speedFreezeDuration then
                State.freezeActive = false
                State.freezeDone   = true
            else
                State.lerpSpeed   = S.speedFreezeAt
                effectiveTarget   = S.speedFreezeAt
            end
        elseif State.lerpSpeed >= S.speedFreezeAt - 0.5 then
            -- Just hit the threshold â€” freeze for the configured duration
            State.freezeActive    = true
            State.freezeStartTime = tick()
            State.lerpSpeed       = S.speedFreezeAt
            effectiveTarget       = S.speedFreezeAt
        else
            -- Climbing toward the threshold â€” clamp target so we don't overshoot
            effectiveTarget = S.speedFreezeAt
        end
    end

    if S.accelEnabled then
        State.lerpSpeed = State.lerpSpeed + (effectiveTarget - State.lerpSpeed) * math.min(dt * accel, 1)
    else
        State.lerpSpeed = effectiveTarget
    end

    -- Apply velocity
    if isMoving then
        BV.Velocity = moveDir * State.lerpSpeed
    else
        State.lerpSpeed = State.lerpSpeed * math.max(0, 1 - dt * accel * 0.8)
        BV.Velocity = BV.Velocity * math.max(0, 1 - dt * accel * 0.8)
    end

    -- -------------------------------------------------------
    --  BODY TILT â€” Camera-directed (crosshair steering)
    --
    --  The character's body faces the exact direction of travel
    --  (full 3D â€” including up/down pitch from camera).
    --  A banking roll is added when strafing sideways.
    --  This is visible to other players via BodyGyro replication.
    -- -------------------------------------------------------
    local targetCF

    -- When shiftlock is on the body faces the camera direction.
    -- While just flying (without shiftlock) the camera is FREE â€” you can look
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
                local camLook    = Camera.CFrame.LookVector
                -- Negated: matches visual expectation (move left â†’ lean left).
                local sideAmount = -moveDir:Dot(camRight)
                local backAmount = -moveDir:Dot(camLook)  -- positive when moving backward
                local tiltMul    = State.shiftlock and (S.directionalTilt or 1) or 1
                local rollAngle  = math.rad(28) * sideAmount * speedFrac * tiltMul
                local pitchBack  = math.rad(20) * math.max(backAmount, 0) * speedFrac * tiltMul
                targetCF = targetCF * CFrame.Angles(pitchBack, 0, rollAngle)
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
                local camLook    = Camera.CFrame.LookVector
                local sideAmount = -moveDir:Dot(camRight)
                local backAmount = -moveDir:Dot(camLook)
                local rollAngle  = math.rad(28) * sideAmount * speedFrac * (S.directionalTilt or 1)
                local pitchBack  = math.rad(20) * math.max(backAmount, 0) * speedFrac * (S.directionalTilt or 1)
                targetCF = targetCF * CFrame.Angles(pitchBack, 0, rollAngle)
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
        -- Not moving â€” keep current facing, or track camera if flying/shiftlock on
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
    --  ANIMATION SWITCHING (with directional locomotion system)
    --  Picks one "desired" track based on current state and movement
    --  direction relative to the camera, then crossfades into it.
    --
    --  When flying + directionalAnimsEnabled, movement direction is
    --  classified as forward / backward / left / right and the matching
    --  custom anim plays.  If that direction has no anim ID set, it
    --  falls back to the regular fly anim (and ultimately to floatIdle).
    -- -------------------------------------------------------
    if S.flyAnimEnabled then
        local desired = nil

        if State.flying then
            if isMoving then
                desired = tracks.fly  -- default while moving + flying
                -- Directional anims only apply in Look mode (shiftlock)
                if S.directionalAnimsEnabled and State.shiftlock then
                    local camCF   = Camera.CFrame
                    local fwdDot  = moveDir:Dot(camCF.LookVector)
                    local rightDot= moveDir:Dot(camCF.RightVector)
                    -- Whichever axis dominates picks the directional anim
                    if math.abs(rightDot) > math.abs(fwdDot) then
                        if rightDot > 0 then
                            desired = tracks.flyRight or desired
                        else
                            desired = tracks.flyLeft or desired
                        end
                    else
                        if fwdDot >= 0 then
                            desired = tracks.flyForward or desired
                        else
                            desired = tracks.flyBackward or desired
                        end
                    end
                end
            else
                desired = tracks.floatIdle  -- hover in place
            end
        else
            -- Floating (not flying)
            desired = isMoving and (tracks.floatMove or tracks.floatIdle) or tracks.floatIdle
        end

        -- Crossfade: stop anything else, play desired
        if desired then
            for _, t in pairs(tracks) do
                if t and t ~= desired and t.IsPlaying then
                    t:Stop(0.2)
                end
            end
            if not desired.IsPlaying then
                desired:Play(0.2)
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
    --  SOUND MANAGEMENT  â€” speed-driven fade in / fade out
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
--  FE IMPACTS  (modular landing impact system)
--
--  Effects: shockwave, debris burst, ground cracks, dust explosion,
--  energy pulse, and a continuous speed-based trail.
--
--  Sizes scale linearly with the player's current speed:
--    speed <= impactSpeedScaleStart   â†’  base radius
--    speed >= impactSpeedScaleMaxSpeed â†’ impactMaxRadius
--
--  Works on both terrain and BasePart surfaces.
--  Also handles terrain-digging and small-part phase-through.
-- ============================================================
local ImpactBin = Instance.new("Folder")
ImpactBin.Name   = "FlyImpactFX"
ImpactBin.Parent = workspace

-- One-shot sound at world position (despawns automatically)
local function playImpactSound(id, volume, pos)
    if not id or id == "" then return end
    local numId = tostring(id):match("%d+")
    if not numId then return end
    local emitter = Instance.new("Part")
    emitter.Anchored      = true
    emitter.CanCollide    = false
    emitter.CanQuery      = false
    emitter.CanTouch      = false
    emitter.Transparency  = 1
    emitter.Size          = Vector3.new(0.2, 0.2, 0.2)
    emitter.CFrame        = CFrame.new(pos)
    pcall(function() emitter.CollisionGroup = FX_GROUP end)
    emitter.Parent        = ImpactBin
    local s = Instance.new("Sound")
    s.SoundId             = "rbxassetid://" .. numId
    s.Volume              = math.clamp((volume or 80) / 100, 0, 10)
    s.RollOffMaxDistance  = 500
    s.RollOffMode         = Enum.RollOffMode.Linear
    s.Parent              = emitter
    s:Play()
    s.Ended:Connect(function()
        if emitter then emitter:Destroy() end
    end)
    task.delay(8, function()
        if emitter and emitter.Parent then emitter:Destroy() end
    end)
end

-- Helper: returns the offset position where FX should spawn so they don't
-- overlap the player's character (which used to fling them)
local function fxSpawnPos(pos, normal, distFromPlayer)
    local _, hrp = getCharParts()
    distFromPlayer = distFromPlayer or 4
    if hrp then
        local toPlayer = hrp.Position - pos
        if toPlayer.Magnitude < distFromPlayer then
            -- shove the spawn site outward along the normal
            return pos + (normal or Vector3.new(0,1,0)) * (distFromPlayer + 1)
        end
    end
    return pos
end

local function fxScale(speed)
    -- Returns a scalar 0..1 mapping current speed to size growth
    local lo  = S.impactSpeedScaleStart
    local hi  = S.impactSpeedScaleMaxSpeed
    if speed <= lo then return 0 end
    if speed >= hi then return 1 end
    return (speed - lo) / math.max(hi - lo, 1)
end

local function fxRadius(speed, sizeMul)
    local s = fxScale(speed)
    local r = S.impactBaseRadius + (S.impactMaxRadius - S.impactBaseRadius) * s
    return r * (sizeMul or 1)
end

local function safeDestroy(inst, sec)
    if not inst then return end
    task.delay(math.clamp(sec or 1, 0.05, 600), function()
        if inst and inst.Parent then inst:Destroy() end
    end)
end

-- â”€â”€ Debris registry + global cap (anti-lag) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Every transient flung debris part is tracked here; when the count
-- exceeds debrisGlobalMax, the OLDEST parts are destroyed first so the
-- game can never accumulate hundreds of physics chunks at once.
local _debrisQueue = {}     -- list of { part = Part, t = tick() }
local function registerDebris(part)
    if not part then return end
    -- Force these chunks into the FX collision group so they NEVER push
    -- the player (which was causing violent spinning).
    pcall(function() part.CollisionGroup = FX_GROUP end)
    part.CanQuery = false
    part.CanTouch = false
    table.insert(_debrisQueue, { part = part, t = tick() })
    local cap = math.max(10, S.debrisGlobalMax or 80)
    while #_debrisQueue > cap do
        local old = table.remove(_debrisQueue, 1)
        if old and old.part and old.part.Parent then
            pcall(function() old.part:Destroy() end)
        end
    end
end
-- Periodic prune of dead refs
task.spawn(function()
    while true do
        task.wait(2)
        for i = #_debrisQueue, 1, -1 do
            local e = _debrisQueue[i]
            if not e or not e.part or not e.part.Parent then
                table.remove(_debrisQueue, i)
            end
        end
    end
end)

-- Fade a part's transparency from t0..1 over `dur` then destroy it
local function fadeAndDestroy(part, dur, startT)
    if not part then return end
    local info = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local goal = { Transparency = 1, Size = part.Size * 1.6 }
    pcall(function()
        TweenService:Create(part, info, goal):Play()
    end)
    safeDestroy(part, dur + 0.1)
end

-- â”€â”€ Shockwave â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function fxShockwave(pos, normal, radius)
    if not S.fxShockwaveEnabled then return end
    pos = fxSpawnPos(pos, normal, 3)
    local ring = Instance.new("Part")
    ring.Anchored      = true
    ring.CanCollide    = false
    ring.CanQuery      = false
    ring.CanTouch      = false
    ring.Massless      = true
    ring.Material      = Enum.Material.Neon
    ring.Color         = Color3.fromRGB(255, 220, 140)
    ring.Transparency  = 0.2
    ring.Shape         = Enum.PartType.Cylinder
    ring.Size          = Vector3.new(0.5, 2, 2)
    ring.CFrame        = CFrame.new(pos, pos + normal) * CFrame.Angles(0, math.rad(90), 0)
    pcall(function() ring.CollisionGroup = FX_GROUP end)
    ring.Parent        = ImpactBin

    local target = math.clamp(radius * 2, 4, 8000)
    local dur    = math.clamp(0.4 + radius * 0.002, 0.3, 1.6)
    TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size         = Vector3.new(0.5, target, target),
        Transparency = 1,
    }):Play()
    safeDestroy(ring, dur + 0.1)
    playImpactSound(S.sfxShockwaveId, S.sfxShockwaveVol, pos)
end

-- â”€â”€ Dust Explosion â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function fxDust(pos, normal, radius)
    if not S.fxDustEnabled then return end
    pos = fxSpawnPos(pos, normal, 3)
    local emitter = Instance.new("Part")
    emitter.Anchored     = true
    emitter.CanCollide   = false
    emitter.CanQuery     = false
    emitter.CanTouch     = false
    emitter.Massless     = true
    emitter.Transparency = 1
    emitter.Size         = Vector3.new(1, 1, 1)
    emitter.CFrame       = CFrame.new(pos)
    pcall(function() emitter.CollisionGroup = FX_GROUP end)
    emitter.Parent       = ImpactBin

    local pe = Instance.new("ParticleEmitter")
    pe.Texture       = "rbxasset://textures/particles/smoke_main.dds"
    pe.LightEmission = 0.1
    pe.Rate          = 0
    pe.Lifetime      = NumberRange.new(0.6, 1.4)
    pe.Speed         = NumberRange.new(radius * 0.4, radius * 0.9)
    pe.SpreadAngle   = Vector2.new(180, 180)
    pe.Size          = NumberSequence.new({
        NumberSequenceKeypoint.new(0, math.max(1, radius * 0.15)),
        NumberSequenceKeypoint.new(1, math.max(2, radius * 0.4)),
    })
    pe.Transparency  = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Color = ColorSequence.new(Color3.fromRGB(200, 195, 180))
    pe.Parent = emitter
    pe:Emit(math.clamp(math.floor(20 + radius * 0.6), 12, 400))
    safeDestroy(emitter, 2)
    playImpactSound(S.sfxDustId, S.sfxDustVol, pos)
end

-- â”€â”€ Ground Cracks â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function fxCracks(pos, normal, radius)
    if not S.fxCracksEnabled then return end
    pos = fxSpawnPos(pos, normal, 3)
    local count = math.clamp(math.floor(3 + radius * 0.05), 3, 24)
    for i = 1, count do
        local crack = Instance.new("Part")
        crack.Anchored      = true
        crack.CanCollide    = false
        crack.CanQuery      = false
        crack.CanTouch      = false
        crack.Massless      = true
        pcall(function() crack.CollisionGroup = FX_GROUP end)
        crack.Material      = Enum.Material.Slate
        crack.Color         = Color3.fromRGB(40, 40, 45)
        crack.Size          = Vector3.new(radius * (0.4 + math.random() * 0.6), 0.05, math.max(0.2, radius * 0.05))
        local angle         = math.rad((360 / count) * i + math.random(-15, 15))
        crack.CFrame        = CFrame.new(pos, pos + normal)
                            * CFrame.Angles(math.rad(90), 0, 0)
                            * CFrame.Angles(0, angle, 0)
                            * CFrame.new(crack.Size.X * 0.5, 0, 0)
        crack.Transparency  = 0.05
        crack.Parent        = ImpactBin
        TweenService:Create(crack, TweenInfo.new(math.clamp(2 + radius * 0.005, 2, 8)), {
            Transparency = 1,
        }):Play()
        safeDestroy(crack, 8)
    end
    playImpactSound(S.sfxCracksId, S.sfxCracksVol, pos)
end

-- â”€â”€ Energy Pulse â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function fxEnergyPulse(pos, radius)
    if not S.fxEnergyPulseEnabled then return end
    pos = fxSpawnPos(pos, Vector3.new(0,1,0), 3)
    local orb = Instance.new("Part")
    orb.Anchored      = true
    orb.CanCollide    = false
    orb.CanQuery      = false
    orb.CanTouch      = false
    orb.Massless      = true
    pcall(function() orb.CollisionGroup = FX_GROUP end)
    orb.Shape         = Enum.PartType.Ball
    orb.Material      = Enum.Material.Neon
    orb.Color         = Color3.fromRGB(120, 200, 255)
    orb.Size          = Vector3.new(2, 2, 2)
    orb.CFrame        = CFrame.new(pos)
    orb.Transparency  = 0.1
    orb.Parent        = ImpactBin
    local target = math.clamp(radius * 1.4, 4, 6000)
    TweenService:Create(orb, TweenInfo.new(math.clamp(0.5 + radius * 0.0015, 0.4, 1.5), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size         = Vector3.new(target, target, target),
        Transparency = 1,
    }):Play()
    safeDestroy(orb, 1.8)
    playImpactSound(S.sfxEnergyPulseId, S.sfxEnergyPulseVol, pos)
end

-- â”€â”€ Debris Burst â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function fxDebris(pos, normal, radius, surfaceColor, surfaceMaterial)
    if not S.fxDebrisEnabled then return end
    -- Spawn debris OFFSET from the player so it never overlaps and flings them
    pos = fxSpawnPos(pos, normal, 5)
    local sizeMul   = S.fxDebrisSize or 1
    local smallN    = math.floor(S.debrisSmallCount  * sizeMul)
    local mediumN   = math.floor(S.debrisMediumCount * sizeMul)
    local largeN    = math.floor(S.debrisLargeCount  * sizeMul)
    local total     = math.min(smallN + mediumN + largeN, S.debrisChunksMax * 3)
    local color     = surfaceColor or Color3.fromRGB(120, 110, 100)
    local material  = surfaceMaterial or Enum.Material.Slate
    local categories = {
        { count = smallN,  size = math.max(0.4, radius * 0.04) },
        { count = mediumN, size = math.max(0.8, radius * 0.08) },
        { count = largeN,  size = math.max(1.4, radius * 0.16) },
    }
    local emitted = 0
    for _, cat in ipairs(categories) do
        for _ = 1, cat.count do
            if emitted >= total then break end
            emitted = emitted + 1
            local p = Instance.new("Part")
            p.Size       = Vector3.new(cat.size, cat.size, cat.size) * (0.6 + math.random() * 0.8)
            p.Material   = material
            p.Color      = color
            p.CanCollide = S.debrisCanCollide
            p.CanQuery   = false
            p.CanTouch   = false
            p.Massless   = true            -- never push the player even if collisions are on
            pcall(function() p.CollisionGroup = FX_GROUP end)
            -- Spread spawn position so chunks don't all start in the same spot
            local spawnOffset = (normal + Vector3.new(
                (math.random() - 0.5) * 2,
                math.random() * 0.5 + 0.3,
                (math.random() - 0.5) * 2
            )).Unit * (radius * 0.05 + math.random() * 2)
            p.CFrame     = CFrame.new(pos + spawnOffset)
                        * CFrame.Angles(math.rad(math.random(0, 360)),
                                        math.rad(math.random(0, 360)),
                                        math.rad(math.random(0, 360)))
            p.Parent     = ImpactBin
            local launch = (normal + Vector3.new(
                (math.random() - 0.5) * 1.6,
                math.random() * 0.8 + 0.4,
                (math.random() - 0.5) * 1.6
            )).Unit * (radius * (0.5 + math.random()))
            p.AssemblyLinearVelocity  = launch
            p.AssemblyAngularVelocity = Vector3.new(
                math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
            registerDebris(p)
            safeDestroy(p, S.debrisDespawnSec)
        end
    end
    playImpactSound(S.sfxDebrisId, S.sfxDebrisVol, pos)
end

-- â”€â”€ Crater (terrain or part) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function fxCrater(pos, normal, radius)
    if not S.craterEnabled then return end
    local depth = math.clamp(radius * 0.3 * (S.craterDepthMul or 1), 1, 200)
    local size  = Vector3.new(radius * 1.4, depth * 2, radius * 1.4)
    local cf    = CFrame.new(pos - normal * (depth * 0.4))
    pcall(function()
        workspace.Terrain:FillBlock(cf, size, Enum.Material.Air)
    end)
    playImpactSound(S.sfxCraterId, S.sfxCraterVol, pos)
end

-- â”€â”€ Crater on a BRICK (deformation) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Splits a hit part into a grid of small chunks and removes the chunks
-- inside an impact-radius hemisphere, producing a real-looking crater
-- on the brick surface. Original part is backed up via _destroyedParts so
-- "Reset Map" can restore it.
local _craterCooldown = {}  -- [Part] = expireTime, throttle re-impacts
local function fxCraterOnPart(part, pos, normal, radius, speed)
    if not S.craterPartEnabled then return end
    if not part or not part:IsA("BasePart") or not part.Parent then return end
    if part.Anchored == false then return end                       -- only static geometry
    if part:IsDescendantOf(ImpactBin) then return end
    if speed < (S.craterPartMinSpeed or 80) then return end
    -- Throttle: same part can't be re-craterized for 0.5s
    local now = tick()
    if _craterCooldown[part] and _craterCooldown[part] > now then return end
    _craterCooldown[part] = now + 0.5

    local sz = part.Size
    local maxAxis = math.max(sz.X, sz.Y, sz.Z)
    -- Use LARGEST axis so thin huge baseplates (Y=1, X=Z=512) still qualify.
    if maxAxis < (S.craterPartMinSize or 8) then return end
    if maxAxis > (S.craterPartMaxSize or 2000) then return end

    local chunk    = math.max(1, S.craterPartChunkSize or 4)
    local craterR  = math.max(chunk, radius * 0.4)

    -- Backup so Map Reset can restore the original part.
    -- (_destroyedParts is declared further down; we look it up at call time
    --  by walking the parent chain â€” fall back gracefully if unavailable.)
    if rawget(_G, "__FlyScript_BackupPart") then
        pcall(_G.__FlyScript_BackupPart, part)
    end

    local mat   = part.Material
    local color = part.Color
    local trans = part.Transparency
    local refl  = part.Reflectance
    local cgrp  = nil
    pcall(function() cgrp = part.CollisionGroup end)
    -- Original brick's collision group is preserved on the chunks so they
    -- behave the same toward the world. The player still won't get spun
    -- because the launched/ flung chunks below use FX_GROUP (no player col).

    local origCF   = part.CFrame
    local origSize = sz
    local nx = math.max(1, math.floor(origSize.X / chunk))
    local ny = math.max(1, math.floor(origSize.Y / chunk))
    local nz = math.max(1, math.floor(origSize.Z / chunk))
    local cx, cy, cz = origSize.X / nx, origSize.Y / ny, origSize.Z / nz
    local container = ImpactBin

    -- Replace original; spawn the chunk grid in its place
    part:Destroy()

    for ix = 0, nx - 1 do
        for iy = 0, ny - 1 do
            for iz = 0, nz - 1 do
                local localPos = Vector3.new(
                    -origSize.X * 0.5 + (ix + 0.5) * cx,
                    -origSize.Y * 0.5 + (iy + 0.5) * cy,
                    -origSize.Z * 0.5 + (iz + 0.5) * cz
                )
                local worldPos = (origCF * CFrame.new(localPos)).Position
                local d = (worldPos - pos).Magnitude
                if d > craterR then
                    -- Outside crater radius â€” keep this chunk as static debris
                    local p = Instance.new("Part")
                    p.Anchored   = true
                    p.CanCollide = true
                    p.CanQuery   = false
                    p.CanTouch   = false
                    p.Size       = Vector3.new(cx, cy, cz)
                    p.CFrame       = origCF * CFrame.new(localPos)
                    p.Material     = mat
                    p.Color        = color
                    p.Transparency = trans
                    p.Reflectance  = refl
                    if cgrp then pcall(function() p.CollisionGroup = cgrp end) end
                    p.Parent       = container
                else
                    -- Inside the crater â€” fling a few chunks for impact spectacle,
                    -- delete the rest to leave a hole.
                    if math.random() < 0.18 then
                        local p = Instance.new("Part")
                        p.Size       = Vector3.new(cx, cy, cz)
                        p.CFrame     = origCF * CFrame.new(localPos)
                        p.Material   = mat
                        p.Color      = color
                        p.CanCollide = false
                        p.CanQuery   = false
                        p.CanTouch   = false
                        p.Massless   = true
                        pcall(function() p.CollisionGroup = FX_GROUP end)
                        p.Parent     = container
                        local launch = (normal + Vector3.new(
                            (math.random() - 0.5) * 1.5,
                            math.random() * 0.6 + 0.3,
                            (math.random() - 0.5) * 1.5
                        )).Unit * (radius * (0.4 + math.random() * 0.6))
                        p.AssemblyLinearVelocity  = launch
                        p.AssemblyAngularVelocity = Vector3.new(
                            math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))
                        registerDebris(p)
                        safeDestroy(p, S.debrisDespawnSec or 5)
                    end
                end
            end
        end
    end
    playImpactSound(S.sfxCraterId, S.sfxCraterVol, pos)
end

-- â”€â”€ Speed-based continuous trail (high speed only) â”€â”€â”€â”€â”€â”€â”€â”€â”€
local _trailEmitter
local function ensureTrailEmitter()
    local _, hrp = getCharParts()
    if not hrp then return nil end
    if _trailEmitter and _trailEmitter.Parent == hrp then return _trailEmitter end
    if _trailEmitter then pcall(function() _trailEmitter:Destroy() end) end
    local pe = Instance.new("ParticleEmitter")
    pe.Name         = "FlySpeedTrail"
    pe.Texture      = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate         = 0
    pe.LightEmission= 0.6
    pe.Lifetime     = NumberRange.new(0.3, 0.8)
    pe.Speed        = NumberRange.new(2, 6)
    pe.SpreadAngle  = Vector2.new(20, 20)
    pe.Color        = ColorSequence.new(Color3.fromRGB(140, 200, 255))
    pe.Size         = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = hrp
    _trailEmitter = pe
    return pe
end

-- Master emitter â€” calls every applicable effect
-- True if `part` belongs to any Player / NPC character (anything with a
-- Humanoid in its ancestry). Used to make sure impacts only fire on real
-- map geometry â€” never on rigs, zombies, or other characters.
local function isCharacterPart(part)
    if not part then return false end
    -- Fast path: explicit Player character
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and part:IsDescendantOf(p.Character) then return true end
    end
    -- Generic NPC / rig: any model with a Humanoid as ancestor
    local m = part:FindFirstAncestorOfClass("Model")
    while m do
        if m:FindFirstChildOfClass("Humanoid") then return true end
        m = m:FindFirstAncestorOfClass("Model")
    end
    return false
end

local function emitImpact(pos, normal, speed, surfacePart)
    if not S.impactsEnabled then return end
    if speed < S.impactMinSpeed then return end
    -- Ignore hits on players / rigs / NPCs â€” impacts only on bricks/parts.
    if isCharacterPart(surfacePart) then return end

    local color, material
    if surfacePart and surfacePart:IsA("BasePart") then
        color    = surfacePart.Color
        material = surfacePart.Material
    end

    if speed >= S.fxShockwaveTrigger    then fxShockwave   (pos, normal, fxRadius(speed, S.fxShockwaveSize)) end
    if speed >= S.fxDustTrigger         then fxDust        (pos, normal, fxRadius(speed, S.fxDustSize))      end
    if speed >= S.fxCracksTrigger       then fxCracks      (pos, normal, fxRadius(speed, S.fxCracksSize))    end
    if speed >= S.fxEnergyPulseTrigger  then fxEnergyPulse (pos,         fxRadius(speed, S.fxEnergyPulseSize)) end
    if speed >= S.fxDebrisTrigger       then fxDebris      (pos, normal, fxRadius(speed, S.fxDebrisSize), color, material) end
    fxCrater(pos, normal, fxRadius(speed, 1))
    -- Brick deformation crater (only fires for big static parts at hard speeds)
    fxCraterOnPart(surfacePart, pos, normal, fxRadius(speed, 1), speed)
end

-- â”€â”€ Phase-through small parts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Backup table so "Reset Map" can restore destroyed parts
local _destroyedParts = {}  -- list of { clone = Part, parent = Instance }
-- Hook used by fxCraterOnPart (declared earlier) to back up the original
-- brick before it gets shredded into chunks, so Reset Map can restore it.
_G.__FlyScript_BackupPart = function(part)
    if part and part.Parent then
        table.insert(_destroyedParts, { clone = part:Clone(), parent = part.Parent })
    end
end
local _phaseCooldown  = {}  -- [Part] = expireTime, prevents double-hit per frame
local function tryPhasePart(part, hrp, speed)
    if not S.phaseEnabled then return end
    if speed < S.phaseMinSpeed then return end
    if not part or not part:IsA("BasePart") then return end
    local longest = math.max(part.Size.X, part.Size.Y, part.Size.Z)
    if longest > S.phaseMaxPartSize then return end
    if part:IsDescendantOf(LocalPlayer.Character) then return end
    if part:IsDescendantOf(ImpactBin) then return end
    -- NEVER phase parts that belong to ANY character/NPC (any model with a
    -- Humanoid). Without this, flying through another player's body would
    -- destroy their limbs and they "disappear" client-side.
    if isCharacterPart and isCharacterPart(part) then return end
    if _phaseCooldown[part] and _phaseCooldown[part] > tick() then return end
    _phaseCooldown[part] = tick() + 0.5

    -- Sound
    playImpactSound(S.sfxPhaseId, S.sfxPhaseVol, part.Position)
    -- Visual burst at the part
    emitImpact(part.Position, (hrp.Position - part.Position).Unit, speed, part)
    if S.phaseLeaveHole then
        pcall(function()
            -- Stash a backup so Reset Map can restore it
            local clone = part:Clone()
            table.insert(_destroyedParts, { clone = clone, parent = part.Parent })
            part:Destroy()
        end)
    end
end

-- â”€â”€ Slide / landing detector heartbeat â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local _wasGrounded   = false
local _lastSlideTime = 0
local _phaseCleanT   = 0

RunService.Heartbeat:Connect(function(dt)
    if not S.impactsEnabled then return end
    local _, hrp, hum = getCharParts()
    if not hrp or not hum then return end

    local speed = hrp.AssemblyLinearVelocity.Magnitude

    -- Trail emitter (speed-based)
    local pe = (S.fxSpeedTrailEnabled and State.flying) and ensureTrailEmitter() or _trailEmitter
    if pe then
        if S.fxSpeedTrailEnabled and State.flying and speed >= S.fxSpeedTrailTrigger then
            local intensity = math.clamp((speed - S.fxSpeedTrailTrigger) / 500, 0.1, 4)
            pe.Rate = 80 * intensity
        else
            pe.Rate = 0
        end
    end

    -- Periodic cleanup of phase cooldown table
    if tick() - _phaseCleanT > 5 then
        _phaseCleanT = tick()
        local now = tick()
        for k, t in pairs(_phaseCooldown) do
            if t < now then _phaseCooldown[k] = nil end
        end
    end

    -- Raycast downward and forward to detect ground / phase candidates
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, ImpactBin }
    rayParams.IgnoreWater = false

    -- Phase-through hitbox (now SPHERICAL â€” radius = phaseHitboxSize / 2)
    if State.flying and S.phaseEnabled and speed >= S.phaseMinSpeed then
        local radius  = math.max(1, (S.phaseHitboxSize or 20) * 0.5)
        local fwd     = hrp.AssemblyLinearVelocity
        local center  = hrp.Position
        if fwd.Magnitude > 0.01 then
            -- Push the sphere slightly forward so we phase what's ahead, not behind us
            center = center + fwd.Unit * (radius * 0.8)
        end
        local overlap = OverlapParams.new()
        overlap.FilterType                  = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances  = { LocalPlayer.Character, ImpactBin }
        overlap.MaxParts                    = 100
        local parts = workspace:GetPartBoundsInRadius(center, radius, overlap)
        for _, p in ipairs(parts) do
            tryPhasePart(p, hrp, speed)
        end
    end

    -- Ground detection (down 4 studs from HRP)
    local downHit = workspace:Raycast(hrp.Position, Vector3.new(0, -4.5, 0), rayParams)
    local grounded = downHit ~= nil

    -- Landing impact (transition from airborne â†’ grounded while moving fast)
    if grounded and not _wasGrounded and speed >= S.impactMinSpeed then
        local pos    = downHit.Position
        local normal = downHit.Normal
        emitImpact(pos, normal, speed, downHit.Instance)
    end

    -- Continuous violent slide impact while grounded + moving fast
    if grounded and S.impactSlideEnabled and State.flying and speed >= S.impactMinSpeed then
        if tick() - _lastSlideTime >= S.impactSlideRate then
            _lastSlideTime = tick()
            local pos    = downHit.Position
            local normal = downHit.Normal
            local r = fxRadius(speed, 0.5)
            if S.fxDustEnabled    and speed >= S.fxDustTrigger    then fxDust    (pos, normal, r) end
            if S.fxDebrisEnabled  and speed >= S.fxDebrisTrigger  then
                fxDebris(pos, normal, r,
                    downHit.Instance and downHit.Instance:IsA("BasePart") and downHit.Instance.Color or nil,
                    downHit.Instance and downHit.Instance:IsA("BasePart") and downHit.Instance.Material or nil)
            end
            if S.fxCracksEnabled  and speed >= S.fxCracksTrigger  then fxCracks  (pos, normal, r) end
            playImpactSound(S.sfxSlideId, S.sfxSlideVol, pos)
        end
    end

    -- Continuous terrain dig while flying through it
    -- Now uses a SPHERICAL hitbox and writes voxels manually so we can
    -- skip Water cells (per user request â€” no draining oceans).
    if State.flying and S.digTerrainWhileFlying and speed >= S.digMinSpeed then
        local terrain  = workspace.Terrain
        local digRadius = math.clamp(2 + speed * 0.005, 2, 40)
        local center    = hrp.Position
        -- Push the dig sphere slightly forward so we tunnel through what's ahead
        local fwdv = hrp.AssemblyLinearVelocity
        if fwdv.Magnitude > 0.01 then
            center = center + fwdv.Unit * (digRadius * 0.5)
        end
        pcall(function()
            -- Read the voxel region around the sphere, then write Air
            -- everywhere EXCEPT cells already containing Water.
            local VOX = 4   -- terrain voxel resolution (studs)
            local pad = digRadius + VOX
            local regMin = Vector3.new(center.X - pad, center.Y - pad, center.Z - pad)
            local regMax = Vector3.new(center.X + pad, center.Y + pad, center.Z + pad)
            local region = Region3.new(regMin, regMax):ExpandToGrid(VOX)
            local mats, occ = terrain:ReadVoxels(region, VOX)
            local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
            local origin = region.CFrame.Position - region.Size * 0.5
            local r2 = digRadius * digRadius
            for x = 1, sx do
                for y = 1, sy do
                    for z = 1, sz do
                        local cur = mats[x][y][z]
                        if cur ~= Enum.Material.Water and cur ~= Enum.Material.Air then
                            local dx = origin.X + (x - 0.5) * VOX - center.X
                            local dy = origin.Y + (y - 0.5) * VOX - center.Y
                            local dz = origin.Z + (z - 0.5) * VOX - center.Z
                            if dx*dx + dy*dy + dz*dz <= r2 then
                                mats[x][y][z] = Enum.Material.Air
                                occ[x][y][z]  = 0
                            end
                        end
                    end
                end
            end
            terrain:WriteVoxels(region, VOX, mats, occ)
        end)
        if math.random() < 0.05 then
            playImpactSound(S.sfxDigId, S.sfxDigVol, hrp.Position)
        end
    end

    _wasGrounded = grounded
end)

-- ============================================================
--  MAP SNAPSHOT / RESET
--  Snapshots BasePart CFrames at script start so "Reset Map"
--  can restore positions and recreate destroyed parts.
-- ============================================================
local _mapSnapshot = {}  -- { [Part] = originalCFrame } for parts still in workspace at startup
local function snapshotMap()
    _mapSnapshot = {}
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("BasePart") and not inst:IsDescendantOf(ImpactBin) then
            -- Skip player characters
            local isCharPart = false
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character and inst:IsDescendantOf(plr.Character) then
                    isCharPart = true; break
                end
            end
            if not isCharPart then
                _mapSnapshot[inst] = inst.CFrame
            end
        end
    end
end
task.spawn(snapshotMap)  -- snapshot in background to avoid blocking startup

local function resetMap()
    -- 1. Clear all FX
    if ImpactBin then
        for _, c in ipairs(ImpactBin:GetChildren()) do
            pcall(function() c:Destroy() end)
        end
    end
    -- 2. Restore destroyed parts (from phase-through)
    for _, entry in ipairs(_destroyedParts) do
        if entry.clone and entry.parent then
            pcall(function()
                local copy = entry.clone:Clone()
                copy.Parent = entry.parent
            end)
        end
    end
    _destroyedParts = {}
    -- 3. Restore moved parts to original CFrames
    local restored = 0
    for part, cf in pairs(_mapSnapshot) do
        if part and part.Parent then
            pcall(function()
                if not part.Anchored then
                    part.AssemblyLinearVelocity  = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
                part.CFrame = cf
                restored = restored + 1
            end)
        end
    end
    -- 4. Re-snapshot to capture any newly added parts
    task.spawn(snapshotMap)
    Rayfield:Notify({ Title = "Map Reset", Content = "Restored " .. restored .. " parts.", Duration = 3 })
end

-- Auto-refresh loop
task.spawn(function()
    while true do
        if S.autoRefreshMapEnabled then
            local mins = math.clamp(S.autoRefreshMinutes or 10, 1, 120)
            task.wait(mins * 60)
            if S.autoRefreshMapEnabled then resetMap() end
        else
            task.wait(5)
        end
    end
end)

-- ============================================================
--  SECRET: STAGES
--  Tracks distance flown while "far from the map" and steps
--  the player through 4 themed stages with custom skyboxes
--  and large celestial models. Resets per stage.
-- ============================================================
local Stages = {
    current        = 1,
    distInStage    = 0,           -- legacy cumulative (kept for transition trigger)
    lastPos        = nil,
    stageObjects   = nil,  -- folder for stage props
    activeSkybox   = nil,  -- Sky cloned into Lighting
    earthModel     = nil,
    solarModel     = nil,
    planetModel    = nil,
    arrowGui       = nil,
    studsGui       = nil,
    studsLabel     = nil,
    stageLabel     = nil,
    greenLightingActive = false,
    origLighting   = nil,  -- backup of Lighting properties before going green
    spawnCFrame    = nil,
    -- Reference point used for distance-from-anchor display per stage:
    --   stage 1 â†’ recorded spawn position
    --   stage 2 â†’ earth position
    --   stage 3 â†’ solar system position
    --   stage 4 â†’ alien planet position
    --   stage 6 â†’ "where am i" â€” distance from arrival point
    refPos         = nil,
    refLabel       = "spawn",
    -- 5-press unlock tracker
    studsPressTimes = {},
    fivePressUnlocked = false,
}

local STAGE_ASSETS = {
    [2] = { skybox = 136402262,    body = 5114510418,  bodyDist = 6000,  bodySize = 4000  },
    [3] = { skybox = 154909249,    body = 8819437776,  bodyDist = 8000,  bodySize = 5000  },
    [4] = { skybox = 15619750970,  body = 8547250340,  bodyDist = 1500,  bodySize = 2000  },
}

-- Helper: load asset via insert/get-objects, returns first instance
local function loadAsset(id)
    local objs
    local ok = pcall(function()
        objs = game:GetObjects("rbxassetid://" .. tostring(id))
    end)
    if (not ok or not objs or #objs == 0) and InsertService then
        pcall(function()
            local model = InsertService:LoadAsset(id)
            if model then objs = model:GetChildren() end
        end)
    end
    return objs
end

local function clearSkybox()
    if Stages.activeSkybox then
        pcall(function() Stages.activeSkybox:Destroy() end)
        Stages.activeSkybox = nil
    end
end

local function applySkybox(assetId)
    clearSkybox()
    local objs = loadAsset(assetId)
    if not objs then return end
    -- Remove existing Sky in Lighting first (only client-side, not the game's)
    -- We DON'T destroy game's Sky, we just parent ours which overrides display
    for _, obj in ipairs(objs) do
        local sky = obj:IsA("Sky") and obj or obj:FindFirstChildWhichIsA("Sky")
        if sky then
            local copy = sky:Clone()
            copy.Name = "FlyScriptSky"
            copy.Parent = Lighting
            Stages.activeSkybox = copy
            return
        end
    end
end

local function clearStageProps()
    if Stages.stageObjects then
        pcall(function() Stages.stageObjects:Destroy() end)
        Stages.stageObjects = nil
    end
    Stages.earthModel  = nil
    Stages.solarModel  = nil
    Stages.planetModel = nil
end

local function spawnBody(assetId, atCFrame, sizeStuds)
    local objs = loadAsset(assetId)
    if not objs or #objs == 0 then return nil end
    local model = objs[1]
    if not model then return nil end
    -- Make a container if needed
    local container
    if model:IsA("Model") then
        container = model
    else
        container = Instance.new("Model")
        container.Name = "FlyScriptBody"
        for _, c in ipairs(objs) do c.Parent = container end
    end
    container.Parent = Stages.stageObjects

    -- Anchor everything and resize
    local primary = container.PrimaryPart
    if not primary then
        for _, d in ipairs(container:GetDescendants()) do
            if d:IsA("BasePart") then primary = d; break end
        end
        if primary then container.PrimaryPart = primary end
    end
    if primary then
        -- Compute current largest size, scale to target
        local extents
        pcall(function() extents = container:GetExtentsSize() end)
        if extents then
            local maxAxis = math.max(extents.X, extents.Y, extents.Z)
            local scale   = sizeStuds / math.max(maxAxis, 0.1)
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Anchored   = true
                    d.CanCollide = false
                    d.CanQuery   = false
                    d.CanTouch   = false
                    pcall(function() d.CollisionGroup = FX_GROUP end)
                    d.Massless   = true
                    d.Size       = d.Size * scale
                end
            end
        end
        container:PivotTo(atCFrame)
    end
    return container
end

local function makeStudsGui()
    if Stages.studsGui then return end
    local sg = Instance.new("ScreenGui")
    sg.Name             = "FlyScriptStudsHUD"
    sg.IgnoreGuiInset   = true
    sg.ResetOnSpawn     = false
    sg.Parent           = LocalPlayer:WaitForChild("PlayerGui")
    local frame = Instance.new("Frame")
    frame.Size              = UDim2.new(0, 220, 0, 60)
    frame.Position          = UDim2.new(0.5, -110, 0, 10)
    frame.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.4
    frame.BorderSizePixel   = 0
    frame.Parent            = sg
    local stage = Instance.new("TextLabel")
    stage.Size              = UDim2.new(1, 0, 0, 22)
    stage.Position          = UDim2.new(0, 0, 0, 4)
    stage.BackgroundTransparency = 1
    stage.TextColor3        = Color3.fromRGB(120, 220, 255)
    stage.Font              = Enum.Font.GothamBold
    stage.TextSize          = 16
    stage.Text              = "Stage 1"
    stage.Parent            = frame
    local studs = Instance.new("TextLabel")
    studs.Size              = UDim2.new(1, 0, 0, 28)
    studs.Position          = UDim2.new(0, 0, 0, 28)
    studs.BackgroundTransparency = 1
    studs.TextColor3        = Color3.fromRGB(255, 255, 255)
    studs.Font              = Enum.Font.GothamMedium
    studs.TextSize          = 18
    studs.Text              = "0 studs"
    studs.Parent            = frame
    Stages.studsGui   = sg
    Stages.studsLabel = studs
    Stages.stageLabel = stage
end

local function destroyStudsGui()
    if Stages.studsGui then
        pcall(function() Stages.studsGui:Destroy() end)
        Stages.studsGui = nil
        Stages.studsLabel = nil
        Stages.stageLabel = nil
    end
end

local function makeArrowGui(targetGetter)
    if Stages.arrowGui then return end
    local sg = Instance.new("ScreenGui")
    sg.Name           = "FlyScriptArrow"
    sg.ResetOnSpawn   = false
    sg.Parent         = LocalPlayer:WaitForChild("PlayerGui")
    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(0, 80, 0, 80)
    lbl.AnchorPoint        = Vector2.new(0.5, 0.5)
    lbl.Position           = UDim2.new(0.5, 0, 0.5, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3         = Color3.fromRGB(80, 255, 120)
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 64
    lbl.Text               = "â†‘"
    lbl.Parent             = sg
    Stages.arrowGui = sg
    -- Continuously orient towards target
    task.spawn(function()
        while sg.Parent do
            local target = targetGetter()
            local _, hrp = getCharParts()
            if target and hrp then
                local screenPos, onScreen = Camera:WorldToViewportPoint(target)
                local viewport = Camera.ViewportSize
                if onScreen and screenPos.Z > 0 then
                    lbl.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
                    lbl.Rotation = 0
                    lbl.Text = "â†’ HERE â†"
                    lbl.TextSize = 28
                else
                    -- Off-screen: pin to edge with a directional arrow
                    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
                    local dir2D  = Vector2.new(screenPos.X - center.X, screenPos.Y - center.Y)
                    if screenPos.Z < 0 then dir2D = -dir2D end
                    if dir2D.Magnitude < 0.01 then dir2D = Vector2.new(0, -1) end
                    local edge = center + dir2D.Unit * (math.min(viewport.X, viewport.Y) * 0.4)
                    lbl.Position = UDim2.new(0, edge.X, 0, edge.Y)
                    lbl.Rotation = math.deg(math.atan2(dir2D.Y, dir2D.X)) + 90
                    lbl.Text = "â†‘"
                    lbl.TextSize = 64
                end
            end
            task.wait(0.05)
        end
    end)
end

local function destroyArrowGui()
    if Stages.arrowGui then
        pcall(function() Stages.arrowGui:Destroy() end)
        Stages.arrowGui = nil
    end
end

local function setGreenLighting(on)
    if on and not Stages.greenLightingActive then
        Stages.origLighting = {
            Ambient            = Lighting.Ambient,
            OutdoorAmbient     = Lighting.OutdoorAmbient,
            FogColor           = Lighting.FogColor,
            FogStart           = Lighting.FogStart,
            FogEnd             = Lighting.FogEnd,
            ColorShift_Top     = Lighting.ColorShift_Top,
            ColorShift_Bottom  = Lighting.ColorShift_Bottom,
            ClockTime          = Lighting.ClockTime,
            Brightness         = Lighting.Brightness,
        }
        -- HARD GREEN â€” fully saturated alien atmosphere
        Lighting.Ambient           = Color3.fromRGB(0, 90, 0)
        Lighting.OutdoorAmbient    = Color3.fromRGB(0, 160, 0)
        Lighting.FogColor          = Color3.fromRGB(0, 220, 30)
        Lighting.FogStart          = 0
        Lighting.FogEnd            = 800
        Lighting.ColorShift_Top    = Color3.fromRGB(0, 200, 0)
        Lighting.ColorShift_Bottom = Color3.fromRGB(0, 140, 0)
        Lighting.ClockTime         = 0          -- night, lets the green dominate
        Lighting.Brightness        = 1
        -- Space skybox (or whatever was set in S.alienSkyboxId)
        pcall(function() applySkybox(S.alienSkyboxId or 136402262) end)
        Stages.greenLightingActive = true
    elseif (not on) and Stages.greenLightingActive then
        for k, v in pairs(Stages.origLighting or {}) do
            pcall(function() Lighting[k] = v end)
        end
        clearSkybox()
        Stages.greenLightingActive = false
    end
end

-- Helper: pick a body part position from a model for ref-distance math
local function bodyPos(model)
    if not model then return nil end
    if model.PrimaryPart then return model.PrimaryPart.Position end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then return d.Position end
    end
end

local function enterStage(n)
    local prev = Stages.current
    Stages.current     = n
    Stages.distInStage = 0
    local _, hrp = getCharParts()
    Stages.lastPos = hrp and hrp.Position or Vector3.new()

    -- Cleanup previous stage
    clearStageProps()
    clearSkybox()
    destroyArrowGui()
    -- Green lighting is ONLY for the alien world (stage 6).
    -- Always clear it on any other stage transition.
    if n ~= 6 then setGreenLighting(false) end

    if n == 1 then
        if Stages.stageLabel then Stages.stageLabel.Text = "Stage 1 â€” World" end
        -- Anchor stage 1 reference at current player pos (treated as "spawn")
        local sp = workspace:FindFirstChildOfClass("SpawnLocation")
        Stages.refPos   = (sp and sp.Position) or (hrp and hrp.Position) or Vector3.new()
        Stages.refLabel = "spawn"
        return
    end

    if n == 6 then
        -- ===== STAGE 6: WHERE AM I? =====
        -- Apply the alien world: green lighting, alien hats + chat sounds for others.
        S.alienWorldUnlocked = true
        S.alienWorldActive   = true
        setGreenLighting(true)
        Stages.refPos   = hrp and hrp.Position or Vector3.new()
        Stages.refLabel = "the unknown"
        if Stages.stageLabel then Stages.stageLabel.Text = "Stage 6 â€” ???" end
        Rayfield:Notify({
            Title    = "WHERE AM I?",
            Content  = "Something feels differentâ€¦",
            Duration = 6,
        })
        -- Refresh hooked players so the alien hat/SFX kick in immediately
        if _G.__FlyScript_RefreshAlienHooks then
            pcall(_G.__FlyScript_RefreshAlienHooks)
        end
        return
    end

    -- Make a stage prop folder
    Stages.stageObjects = Instance.new("Folder")
    Stages.stageObjects.Name = "FlyScriptStageProps"
    Stages.stageObjects.Parent = workspace

    local data = STAGE_ASSETS[n]
    if not data then return end

    pcall(function() applySkybox(data.skybox) end)

    local body
    if hrp then
        -- Place body BEHIND the player (negative look direction) so they have to turn around to see it
        local lookDir = hrp.CFrame.LookVector
        local bodyCF  = CFrame.new(hrp.Position - lookDir * data.bodyDist)
        body = spawnBody(data.body, bodyCF, data.bodySize)
        if n == 2 then Stages.earthModel  = body end
        if n == 3 then Stages.solarModel  = body end
        if n == 4 then Stages.planetModel = body end
    end

    -- Set distance reference to the body so notifications read
    -- "X studs away from earth/solar system/planet"
    Stages.refPos   = bodyPos(body) or (hrp and hrp.Position) or Vector3.new()
    Stages.refLabel = (n == 2 and "earth")
                  or (n == 3 and "the solar system")
                  or (n == 4 and "the alien planet")
                  or "ref"

    if Stages.stageLabel then
        Stages.stageLabel.Text = "Stage " .. n .. (
            n == 2 and " â€” Space" or
            n == 3 and " â€” Outside Solar System" or
            n == 4 and " â€” The Final Planet" or "")
    end

    if n == 4 then
        -- Stage 4 still gets the directional arrow toward the planet,
        -- but the GREEN LIGHTING / aliens only activate AFTER going through it (â†’ stage 6).
        makeArrowGui(function()
            if Stages.planetModel then return bodyPos(Stages.planetModel) end
        end)
    end

    Rayfield:Notify({
        Title    = "Stage " .. n,
        Content  = (n == 2 and "You drifted into space.")
                or (n == 3 and "You left the solar system.")
                or (n == 4 and "You found something at the end of the universe.")
                or "",
        Duration = 5,
    })
end

local function farFromMap(pos)
    -- "Far from map" = no original snapshot part within farFromMapDist
    local dist = S.farFromMapDist or 500
    local d2   = dist * dist
    for part, _ in pairs(_mapSnapshot) do
        if part and part.Parent then
            local dx = part.Position - pos
            if dx.X * dx.X + dx.Y * dx.Y + dx.Z * dx.Z < d2 then
                return false
            end
        end
    end
    return true
end

-- Distance from the per-stage anchor point (spawn / earth / solar / planet / unknown).
-- This is what the Studs notification reports â€” fixes the bug where the old
-- HUD read 87000 at spawn (it was accumulating flight distance forever).
local function distFromRef()
    local _, hrp = getCharParts()
    if not hrp or not Stages.refPos then return 0 end
    return (hrp.Position - Stages.refPos).Magnitude
end

-- Builds the per-stage notification text shown when the Studs button is tapped.
local function studsMessage()
    local d   = math.floor(distFromRef())
    local cur = Stages.current
    if cur == 1 then return ("Stage 1 â€” You're %d studs away from spawn."):format(d) end
    if cur == 2 then return ("Stage 2 â€” You're %d studs away from earth."):format(d) end
    if cur == 3 then return ("Stage 3 â€” You're %d studs away from the solar system."):format(d) end
    if cur == 4 then return ("Stage 4 â€” You're very far away but you see a planet.") end
    if cur == 6 then return "WHERE AM I?" end
    return ("You're %d studs away from %s."):format(d, Stages.refLabel or "spawn")
end

-- Tap counter for the secret "press studs 5x in 10s" unlock.
local function recordStudsPress()
    local now = os.clock()
    table.insert(Stages.studsPressTimes, now)
    -- prune anything older than 10s
    local i = 1
    while i <= #Stages.studsPressTimes do
        if now - Stages.studsPressTimes[i] > 10 then
            table.remove(Stages.studsPressTimes, i)
        else
            i = i + 1
        end
    end
    if #Stages.studsPressTimes >= 5 and not Stages.fivePressUnlocked then
        Stages.fivePressUnlocked = true
        Rayfield:Notify({
            Title    = "Secret Unlocked",
            Content  = "You found it. Check Settings â–¸ World for a hidden option.",
            Duration = 6,
        })
    end
end

-- Public: triggered by the Studs mobile button / hotkey
local function showStudsNotification()
    recordStudsPress()
    Rayfield:Notify({
        Title    = "Studs",
        Content  = studsMessage(),
        Duration = 4,
    })
end
_G.__FlyScript_ShowStuds = showStudsNotification  -- exposed for the button factory

-- Stages heartbeat: ref-distance based transitions
RunService.Heartbeat:Connect(function()
    if not S.stagesEnabled then
        if Stages.studsGui then destroyStudsGui() end
        return
    end
    -- Legacy on-screen HUD is OFF by default per user request.
    -- We only build it if someone manually re-enables it in Settings.
    if S.showStudsHud then makeStudsGui() else destroyStudsGui() end

    local _, hrp = getCharParts()
    if not hrp then return end
    local pos = hrp.Position
    Stages.lastPos = pos

    -- Live HUD label (only when manually enabled)
    if Stages.studsLabel then
        Stages.studsLabel.Text = math.floor(distFromRef()) .. " studs"
    end

    -- ===== Transitions are now distance-from-anchor, not cumulative flight =====
    -- This fixes the "87000 at spawn" bug: stand still, distance is 0.
    if Stages.current == 1 then
        if distFromRef() >= S.stage1ToStage2Studs then
            enterStage(2)
        end
    elseif Stages.current == 2 then
        -- Touching earth â†’ back to stage 1
        if Stages.earthModel then
            local ep = bodyPos(Stages.earthModel)
            if ep then
                local dE = (pos - ep).Magnitude
                local extents = pcall(function() return Stages.earthModel:GetExtentsSize() end)
                                and Stages.earthModel:GetExtentsSize() or Vector3.new()
                if dE < (S.earthReturnDist + extents.Magnitude * 0.5) then
                    enterStage(1)
                    return
                end
                if dE >= S.stage2ToStage3Studs then enterStage(3) end
            end
        end
    elseif Stages.current == 3 then
        if Stages.solarModel then
            local sp = bodyPos(Stages.solarModel)
            if sp then
                local dS = (pos - sp).Magnitude
                local extents = pcall(function() return Stages.solarModel:GetExtentsSize() end)
                                and Stages.solarModel:GetExtentsSize() or Vector3.new()
                if dS < (S.solarReturnDist + extents.Magnitude * 0.5) then
                    enterStage(2)
                    return
                end
                if dS >= S.stage3ToStage4Studs then enterStage(4) end
            end
        end
    elseif Stages.current == 4 then
        if Stages.planetModel then
            local pp = bodyPos(Stages.planetModel)
            if pp then
                local dP = (pos - pp).Magnitude
                local extents = pcall(function() return Stages.planetModel:GetExtentsSize() end)
                                and Stages.planetModel:GetExtentsSize() or Vector3.new()
                if dP < (S.planetExitDist + extents.Magnitude * 0.5) then
                    -- Going through the alien planet â†’ enter Stage 6 (alien world)
                    -- BEFORE teleporting to spawn, so green lighting + alien hooks
                    -- become active for the rest of the session.
                    local spawnLoc = workspace:FindFirstChildOfClass("SpawnLocation")
                    if spawnLoc and hrp then
                        hrp.CFrame = spawnLoc.CFrame + Vector3.new(0, 5, 0)
                    end
                    enterStage(6)
                    return
                end
            end
        end
    end
end)

-- ============================================================
--  OTHER PLAYERS: alien hat + chat sound  (visible to local client only)
--  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
--  GATED behind S.alienWorldActive (set true on stage 6 entry, or
--  via Settings â–¸ World â–¸ Alien World).  Previously this fired for
--  every player as soon as the script loaded â€” that was the bug.
-- ============================================================
local ALIEN_HAT_ID    = 20908888
local OTHER_CHAT_SFX  = 93774663737357

-- Cache the loaded hat parts so we don't hit InsertService once per player.
local _alienHatTemplate = nil
-- Build / fetch the alien hat template. Asset 20908888 is a legacy "Hat"
-- with a child Handle. We always return a real Accessory wrapping that
-- Handle so Humanoid:AddAccessory works on every Roblox version.
local function getAlienHatTemplate()
    if _alienHatTemplate then return _alienHatTemplate end

    local objs = loadAsset(ALIEN_HAT_ID)
    -- Helper to wrap a BasePart "Handle" into a fresh Accessory.
    local function wrapHandle(handle, mesh)
        local acc = Instance.new("Accessory")
        acc.Name = "AlienHat"
        local h = handle:Clone()
        h.Name       = "Handle"
        h.Anchored   = false
        h.CanCollide = false
        h.Massless   = true
        if mesh and not h:FindFirstChildWhichIsA("SpecialMesh") then
            local m = mesh:Clone(); m.Parent = h
        end
        h.Parent = acc
        -- Attachment on the Handle that lines up with the head's HatAttachment
        local att = Instance.new("Attachment")
        att.Name     = "HatAttachment"
        att.Position = Vector3.new(0, 0.4, 0)
        att.Parent   = h
        return acc
    end

    if objs then
        -- Real Accessory present?
        for _, obj in ipairs(objs) do
            if obj:IsA("Accessory") then _alienHatTemplate = obj; return obj end
            local acc = obj:FindFirstChildWhichIsA("Accessory")
            if acc then _alienHatTemplate = acc; return acc end
        end
        -- Old-style Hat (or any container) with a Handle
        for _, obj in ipairs(objs) do
            local handle = obj:IsA("BasePart") and obj
                        or obj:FindFirstChild("Handle", true)
                        or obj:FindFirstChildWhichIsA("BasePart", true)
            if handle then
                local mesh = handle:FindFirstChildWhichIsA("SpecialMesh")
                _alienHatTemplate = wrapHandle(handle, mesh)
                return _alienHatTemplate
            end
        end
    end

    -- Last-resort fallback: build the Classic Alien hat manually from its
    -- known mesh + texture asset IDs so it ALWAYS appears, even when the
    -- executor blocks GetObjects/InsertService.
    local h = Instance.new("Part")
    h.Name        = "Handle"
    h.Size        = Vector3.new(2, 2, 2)
    h.CanCollide  = false
    h.Massless    = true
    h.Color       = Color3.fromRGB(80, 200, 80)
    local mesh    = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId   = "rbxassetid://20571982"     -- Classic Alien mesh
    mesh.TextureId= "rbxassetid://20571945"     -- Classic Alien texture
    mesh.Scale    = Vector3.new(1.05, 1.05, 1.05)
    mesh.Parent   = h
    _alienHatTemplate = wrapHandle(h, nil)
    h:Destroy()
    return _alienHatTemplate
end

-- Apply hat to a single character. Uses Humanoid:AddAccessory if available;
-- otherwise welds the Handle to the head directly so it doesn't fall to the baseplate.
local function applyAlienHatToChar(char)
    if not char or not char.Parent then return end
    if char:FindFirstChild("FlyScriptAlienHat") then return end
    local hum  = char:FindFirstChildWhichIsA("Humanoid")
    local head = char:FindFirstChild("Head")
    if not hum or not head then return end
    local template = getAlienHatTemplate()
    if not template then return end
    local clone = template:Clone()
    clone.Name = "FlyScriptAlienHat"
    -- Make sure the handle physics won't drop it
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored   = false
            d.CanCollide = false
            d.Massless   = true
        end
    end
    local ok = pcall(function() hum:AddAccessory(clone) end)
    if not ok or not clone.Parent then
        -- Manual weld fallback
        clone.Parent = char
        local handle = clone:FindFirstChild("Handle") or clone:FindFirstChildWhichIsA("BasePart", true)
        if handle then
            local weld = Instance.new("Weld")
            weld.Part0 = head
            weld.Part1 = handle
            weld.C0   = CFrame.new(0, head.Size.Y * 0.5 + 0.4, 0)
            weld.Parent = handle
        end
    end
end

local function removeAlienHatFromChar(char)
    if not char then return end
    local h = char:FindFirstChild("FlyScriptAlienHat")
    if h then h:Destroy() end
end

local function playOtherPlayerChatSound(plr)
    if plr == LocalPlayer then return end
    if not S.alienWorldActive then return end  -- gated
    local char = plr.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local s = Instance.new("Sound")
    s.SoundId            = "rbxassetid://" .. tostring(OTHER_CHAT_SFX)
    s.Volume             = 1
    s.RollOffMaxDistance = 200
    s.RollOffMode        = Enum.RollOffMode.Linear
    s.Parent             = hrp
    s:Play()
    s.Ended:Connect(function() s:Destroy() end)
    task.delay(10, function() if s and s.Parent then s:Destroy() end end)
end

-- Per-player connections. We hook chat once and check the gate inside.
local function hookPlayer(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        -- Apply ASAP, then retry until Head exists (some servers stream parts in slowly)
        task.spawn(function()
            for _ = 1, 20 do
                if S.alienWorldActive and char.Parent and char:FindFirstChild("Head") then
                    applyAlienHatToChar(char)
                    return
                end
                task.wait(0.25)
            end
        end)
    end)
    plr.Chatted:Connect(function() playOtherPlayerChatSound(plr) end)
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)

-- Push hat to / remove hat from every existing character. Called whenever
-- the alien world is toggled on/off, and once when stage 6 is entered.
local function refreshAlienHooks()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            if S.alienWorldActive then
                applyAlienHatToChar(p.Character)
            else
                removeAlienHatFromChar(p.Character)
            end
        end
    end
end
_G.__FlyScript_RefreshAlienHooks = refreshAlienHooks

-- Safety net: every 1.5s while alien world is active, scan everyone and make
-- sure the hat is on. Fixes any case where the hat fell off / character respawned
-- before our CharacterAdded retry loop fired.
task.spawn(function()
    while true do
        task.wait(1.5)
        if S.alienWorldActive then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character
                and not p.Character:FindFirstChild("FlyScriptAlienHat") then
                    pcall(function() applyAlienHatToChar(p.Character) end)
                end
            end
        end
    end
end)

-- ============================================================
--  CHAT COMMANDS  ( !stage2 / !stage3 / !stage4 )
-- ============================================================
LocalPlayer.Chatted:Connect(function(msg)
    local lower = string.lower(msg)
    if lower == "!stage2" then enterStage(2)
    elseif lower == "!stage3" then enterStage(3)
    elseif lower == "!stage4" then enterStage(4)
    elseif lower == "!stage6" or lower == "!alien" then enterStage(6)
    elseif lower == "!stage1" or lower == "!reset" then enterStage(1)
    elseif lower == "!robloxia" then
        S.alienWorldActive = false
        setGreenLighting(false)
        if _G.__FlyScript_RefreshAlienHooks then _G.__FlyScript_RefreshAlienHooks() end
        Rayfield:Notify({ Title = "World", Content = "Robloxia restored.", Duration = 3 })
    elseif lower == "!alienworld" then
        S.alienWorldUnlocked = true
        S.alienWorldActive   = true
        setGreenLighting(true)
        if _G.__FlyScript_RefreshAlienHooks then _G.__FlyScript_RefreshAlienHooks() end
        Rayfield:Notify({ Title = "World", Content = "Alien world active.", Duration = 3 })
    end
end)

-- ============================================================
--  CINEMATIC CAMERA  (subtle additive effects â€” does NOT replace
--  the default Roblox camera; only nudges position/roll/FOV)
--
--  Bound at Camera + 1 priority so we apply AFTER the default
--  camera updates each frame.  When disabled or in freecam, the
--  hook resets its accumulated offsets to zero so nothing leaks.
-- ============================================================
local cineState = { posOffset = Vector3.zero, rollOffset = 0 }

RunService:BindToRenderStep("FlyCinematicCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not S.cinematicEnabled or State.freecam then
        cineState.posOffset  = Vector3.zero
        cineState.rollOffset = 0
        return
    end

    local _, hrp = getCharParts()
    if not hrp then return end

    local vel      = hrp.AssemblyLinearVelocity
    local camCF    = Camera.CFrame
    local localVel = camCF:VectorToObjectSpace(vel)
    local lag      = math.clamp(S.cinematicLag  or 1, 0, 3)
    local rollAmt  = math.clamp(S.cinematicRoll or 1, 0, 3)

    -- Lateral / vertical lag â€” camera trails sideways and vertical motion
    local targetPos = Vector3.new(
        -localVel.X * 0.012 * lag,
        -localVel.Y * 0.006 * lag,
         0
    )
    cineState.posOffset = cineState.posOffset:Lerp(targetPos, math.min(dt * 5, 1))

    -- Roll â€” bank slightly into strafe direction
    local targetRoll = math.rad(math.clamp(-localVel.X * 0.05 * rollAmt, -8, 8))
    cineState.rollOffset = cineState.rollOffset
        + (targetRoll - cineState.rollOffset) * math.min(dt * 5, 1)

    -- Speed-based subtle FOV bump (additive to existing FOV system)
    if not State.boostActive then
        local speed     = vel.Magnitude
        local speedFrac = math.clamp(speed / math.max(S.flySpeed, 1), 0, 1)
        local targetFOV = State.defaultFOV + (S.cinematicFovBoost or 0) * speedFrac
        Camera.FieldOfView = Camera.FieldOfView
            + (targetFOV - Camera.FieldOfView) * math.min(dt * 2, 1)
    end

    -- Apply offsets on top of whatever the default camera produced
    Camera.CFrame = Camera.CFrame
        * CFrame.new(cineState.posOffset)
        * CFrame.Angles(0, 0, cineState.rollOffset)
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
        Content = "WASD / E / Q to move\nPC: press M to exit  â€¢  Mobile: open menu to exit",
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
--  AIMLOCK
--  Acquires the player closest to the configurable on-screen
--  crosshair (within S.aimlockFOV pixels) and snaps the camera
--  to look at their target part each frame. Honours team check
--  and wall check options, and respects S.aimlockRange world dist.
--
--  Toggle:
--    PC      â†’ S.aimlockKey (default P)
--    Mobile  â†’ on-screen "Aimlock" button (created below)
-- ============================================================
local Aimlock = {
    target           = nil,      -- the currently locked Player
    targetLostAt     = 0,        -- tick() when target became unreachable; used by reacquire delay
    crosshairGui     = nil,
    crosshairImg     = nil,
    fovCircle        = nil,      -- ImageLabel showing the FOV ring
    statusLabel      = nil,      -- "Locked: Name" small HUD line under crosshair
    friendCache      = {},       -- [userId] = bool
    _holdActive      = false,    -- true while user holds key/button in Hold-to-Aim mode
}

local function isFriend(plr)
    if not plr or plr == LocalPlayer then return false end
    local cached = Aimlock.friendCache[plr.UserId]
    if cached ~= nil then return cached end
    local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(plr.UserId) end)
    if ok then
        Aimlock.friendCache[plr.UserId] = res
        return res
    end
    return false
end
Players.PlayerRemoving:Connect(function(p) Aimlock.friendCache[p.UserId] = nil end)

-- True if `plr` appears in the user's Lock List. Listed players bypass the
-- friend check (per spec) but still respect wall/team checks unless overridden.
local function isOnLockList(plr)
    if not plr then return false end
    return S.targetLockList[string.lower(plr.Name)] == true
end

local function getAimPart(plr)
    local char = plr.Character
    if not char then return nil end
    -- Try the user-specified part first, then walk the priority chain.
    if S.aimlockPart and S.aimlockPart ~= "" then
        local p = char:FindFirstChild(S.aimlockPart)
        if p and p:IsA("BasePart") then return p end
    end
    for _, name in ipairs(S.aimlockPartChain or {"Head","HumanoidRootPart"}) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    return char:FindFirstChildWhichIsA("BasePart")
end

local function isAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    return hum and hum.Health > 0
end

local function wallBlocked(fromPos, toPart)
    if not S.aimlockWallCheck then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = { LocalPlayer.Character }
    if toPart and toPart.Parent then table.insert(exclude, toPart.Parent) end
    rp.FilterDescendantsInstances = exclude
    rp.IgnoreWater = true
    local dir = toPart.Position - fromPos
    local hit = workspace:Raycast(fromPos, dir, rp)
    return hit ~= nil
end

local function crosshairScreenPos()
    local vp = Camera.ViewportSize
    local pos = S.aimlockCrosshairPos or UDim2.new(0.5, 0, 0.5, 0)
    return Vector2.new(
        pos.X.Scale * vp.X + pos.X.Offset,
        pos.Y.Scale * vp.Y + pos.Y.Offset
    )
end

-- Per-target velocity cache used to estimate acceleration between frames.
local _velCache = {}   -- [Player] = { v = Vector3, t = tick() }
Players.PlayerRemoving:Connect(function(p) _velCache[p] = nil end)

-- Predicted aim point for `plr` â€” Smart-AI lead based on velocity (and, if
-- enabled, acceleration) plus a nominal projectile travel-time. Falls back
-- to raw position when Smart AI is off.
local function predictedAimPoint(plr, hrp)
    local part = getAimPart(plr)
    if not part then return nil end
    if not S.aimlockSmartAI then return part.Position, part end
    local v   = part.AssemblyLinearVelocity
    local now = tick()
    local accel = Vector3.zero
    local cache = _velCache[plr]
    if cache then
        local dt = math.max(now - cache.t, 1e-3)
        accel = (v - cache.v) / dt
        -- clamp absurd accel from physics glitches
        if accel.Magnitude > 500 then accel = accel.Unit * 500 end
    end
    _velCache[plr] = { v = v, t = now }
    if v.Magnitude < 0.5 and accel.Magnitude < 0.5 then return part.Position, part end
    local dist  = (part.Position - (hrp and hrp.Position or Camera.CFrame.Position)).Magnitude
    local leadT = math.clamp(dist / 1000, 0, 1.5) * (S.aimlockPredictStrength or 1)
    local lead  = v * leadT
    if S.aimlockPredictAccel then
        lead = lead + accel * (0.5 * leadT * leadT)
    end
    return part.Position + lead, part
end

-- Returns true if `plr` is a valid (alive, in-range, not blocked, allowed by checks) target.
-- `requireInFOV` â€” if true, also require the player to be inside the screen FOV ring.
local function isValidTarget(plr, requireInFOV, cross)
    if not plr or plr == LocalPlayer then return false end
    if not isAlive(plr) then return false end
    local part = getAimPart(plr); if not part then return false end
    local _, hrp = getCharParts(); if not hrp then return false end
    if (part.Position - hrp.Position).Magnitude > S.aimlockRange then return false end
    if wallBlocked(hrp.Position, part) then return false end
    -- Lock-list bypasses friend check; team check still respected unless we
    -- decide otherwise. Here we let listed players bypass team check too â€”
    -- otherwise the list is half-useless in team games.
    local listed = isOnLockList(plr)
    if not listed then
        if S.aimlockTeamCheck and p_team_eq(plr) then return false end
        if S.aimlockFriendCheck and isFriend(plr) then return false end
    end
    if requireInFOV and cross then
        local sp, on = Camera:WorldToViewportPoint(part.Position)
        if not on or sp.Z <= 0 then return false end
        local dx, dy = sp.X - cross.X, sp.Y - cross.Y
        if (dx*dx + dy*dy) > (S.aimlockFOV * S.aimlockFOV) then return false end
    end
    return true
end

-- Helper extracted so isValidTarget reads clean
function p_team_eq(plr)
    return plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
end

-- Acquire a NEW target from the FOV ring. Lock-list players are preferred.
local function acquireTarget()
    local _, hrp = getCharParts(); if not hrp then return nil end
    local cross = crosshairScreenPos()
    local bestListed, bestListedDist = nil, math.huge
    local bestAny,    bestAnyDist    = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if isValidTarget(p, true, cross) then
            local part = getAimPart(p)
            local sp = Camera:WorldToViewportPoint(part.Position)
            local dx, dy = sp.X - cross.X, sp.Y - cross.Y
            local pixD2 = dx*dx + dy*dy
            if isOnLockList(p) then
                if pixD2 < bestListedDist then bestListedDist, bestListed = pixD2, p end
            else
                if pixD2 < bestAnyDist then bestAnyDist, bestAny = pixD2, p end
            end
        end
    end
    return bestListed or bestAny
end

-- Crosshair GUI â€” visible while aimlock is enabled.
local function makeCrosshairGui()
    if Aimlock.crosshairGui then return end
    local sg = Instance.new("ScreenGui")
    sg.Name           = "FlyScriptAimlockCrosshair"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.Parent         = LocalPlayer:WaitForChild("PlayerGui")

    -- FOV RING â€” drawn as a Frame + UIStroke so it's GUARANTEED to render on
    -- every device (mobile included) without depending on an asset id load.
    local ring = Instance.new("Frame")
    ring.Name              = "FOVRing"
    ring.AnchorPoint       = Vector2.new(0.5, 0.5)
    ring.Position          = S.aimlockCrosshairPos
    ring.Size              = UDim2.new(0, S.aimlockFOV * 2, 0, S.aimlockFOV * 2)
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel   = 0
    ring.Visible           = S.aimlockShowFOV == true
    ring.Parent            = sg
    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(0.5, 0); ringCorner.Parent = ring
    local ringStroke = Instance.new("UIStroke")
    ringStroke.Name        = "Stroke"
    ringStroke.Thickness   = 2
    ringStroke.Color       = Color3.fromRGB(S.aimlockFOVColorR or 255, S.aimlockFOVColorG or 60, S.aimlockFOVColorB or 60)
    ringStroke.Transparency= 0.15
    ringStroke.Parent      = ring
    Aimlock.fovCircle = ring
    Aimlock.fovStroke = ringStroke

    -- CROSSHAIR DOT â€” solid red circle drawn as a Frame+UICorner. No asset
    -- needed; visible on every device. Editable via the X/Y position sliders.
    local img = Instance.new("Frame")
    img.Name               = "CrosshairDot"
    img.Size               = UDim2.new(0, 14, 0, 14)
    img.AnchorPoint        = Vector2.new(0.5, 0.5)
    img.Position           = S.aimlockCrosshairPos
    img.BackgroundColor3   = Color3.fromRGB(255, 40, 40)
    img.BackgroundTransparency = 0
    img.BorderSizePixel    = 0
    img.Parent             = sg
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(0.5, 0); dotCorner.Parent = img
    local dotStroke = Instance.new("UIStroke")
    dotStroke.Thickness    = 2
    dotStroke.Color        = Color3.fromRGB(255, 255, 255)
    dotStroke.Transparency = 0.2
    dotStroke.Parent       = img

    -- Tiny status line just under the crosshair
    local lbl = Instance.new("TextLabel")
    lbl.AnchorPoint        = Vector2.new(0.5, 0)
    lbl.Position           = UDim2.new(S.aimlockCrosshairPos.X.Scale, 0,
                                       S.aimlockCrosshairPos.Y.Scale, 28)
    lbl.Size               = UDim2.new(0, 220, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextScaled         = true
    lbl.TextColor3         = Color3.fromRGB(255, 80, 80)
    lbl.TextStrokeTransparency = 0.4
    lbl.Text               = ""
    lbl.Parent             = sg

    Aimlock.crosshairGui = sg
    Aimlock.crosshairImg = img
    Aimlock.statusLabel  = lbl
end

local function destroyCrosshairGui()
    if Aimlock.crosshairGui then
        pcall(function() Aimlock.crosshairGui:Destroy() end)
        Aimlock.crosshairGui = nil
        Aimlock.crosshairImg = nil
        Aimlock.fovCircle    = nil
        Aimlock.statusLabel  = nil
    end
end

local function setAimlock(on)
    S.aimlockEnabled = on
    if on then
        makeCrosshairGui()
    else
        destroyCrosshairGui()
        Aimlock.target = nil
        Aimlock.targetLostAt = 0
    end
    if _G.__FlyScript_UpdateAimlockBtn then pcall(_G.__FlyScript_UpdateAimlockBtn) end
end
_G.__FlyScript_SetAimlock = setAimlock

-- Per-frame: keep the camera looking at the target's aim part, with smoothing
-- and Smart-AI lead. Sticky lock keeps the same target until they die or
-- become unreachable for `aimlockReacquireDelay` seconds.
RunService:BindToRenderStep("FlyAimlock", Enum.RenderPriority.Camera.Value + 2, function()
    if not S.aimlockEnabled then return end

    -- Hold-to-aim: bail out if the toggle is on but the user isn't actually
    -- holding the keybind / mobile button this frame.
    if S.aimlockHoldToAim and not Aimlock._holdActive then
        if Aimlock.statusLabel then Aimlock.statusLabel.Text = "" end
        return
    end

    -- Live-update GUI from settings
    if Aimlock.crosshairImg then
        Aimlock.crosshairImg.Position = S.aimlockCrosshairPos
    end
    if Aimlock.fovCircle then
        Aimlock.fovCircle.Visible  = S.aimlockShowFOV == true
        Aimlock.fovCircle.Position = S.aimlockCrosshairPos
        Aimlock.fovCircle.Size     = UDim2.new(0, S.aimlockFOV * 2, 0, S.aimlockFOV * 2)
        if Aimlock.fovStroke then
            Aimlock.fovStroke.Color = Color3.fromRGB(
                S.aimlockFOVColorR or 255, S.aimlockFOVColorG or 60, S.aimlockFOVColorB or 60)
        end
    end
    if Aimlock.statusLabel then
        Aimlock.statusLabel.Position = UDim2.new(S.aimlockCrosshairPos.X.Scale, 0,
                                                 S.aimlockCrosshairPos.Y.Scale, 28)
    end

    -- Miss-chance: skip the camera adjustment on N% of frames so the aim
    -- doesn't look like 100% pixel-perfect superhuman tracking.
    local missPct = math.clamp(S.aimlockMissChance or 0, 0, 90)
    if missPct > 0 and math.random(1, 100) <= missPct then return end

    local _, hrp = getCharParts()
    if not hrp then return end
    local cross = crosshairScreenPos()
    -- Apply humanizer jitter to the effective crosshair position
    local hum = math.max(0, S.aimlockHumanize or 0)
    if hum > 0 then
        cross = Vector2.new(
            cross.X + (math.random() - 0.5) * 2 * hum,
            cross.Y + (math.random() - 0.5) * 2 * hum)
    end

    -- Sticky lock validation
    local cur = Aimlock.target
    local keep = false
    if cur and S.aimlockStickyLock then
        if isValidTarget(cur, false, cross) then
            keep = true
            Aimlock.targetLostAt = 0
        else
            -- Brief grace period so wall-flicker doesn't drop the lock instantly.
            if Aimlock.targetLostAt == 0 then Aimlock.targetLostAt = tick() end
            if (tick() - Aimlock.targetLostAt) < (S.aimlockReacquireDelay or 0.6)
            and cur and cur.Parent and isAlive(cur) then
                keep = true   -- hold the lock briefly while we wait
            else
                Aimlock.target = nil
                Aimlock.targetLostAt = 0
            end
        end
    end

    -- Acquire if nothing held
    if not keep or not Aimlock.target then
        Aimlock.target = acquireTarget()
        Aimlock.targetLostAt = 0
    end

    local t = Aimlock.target
    if not t then
        if Aimlock.statusLabel then Aimlock.statusLabel.Text = "" end
        return
    end

    -- Predict where to aim
    local aimPos = predictedAimPoint(t, hrp)
    if not aimPos then
        if Aimlock.statusLabel then Aimlock.statusLabel.Text = "" end
        return
    end

    -- â”€â”€ CROSSHAIR-AWARE AIMING (always on) â”€â”€
    -- Build a camera CFrame such that `aimPos` projects to the CROSSHAIR
    -- pixel (not screen center). Compute the angular offset from screen
    -- center to the crosshair, build a "look at" CFrame, then rotate it
    -- so the target shifts off-center to land under the crosshair / FOV ring.
    -- Drives directly off S.aimlockCrosshairPos â€” wherever the user puts the
    -- red dot is where the target will be locked.
    local camPos   = Camera.CFrame.Position
    local lookCF   = CFrame.lookAt(camPos, aimPos)
    local vp       = Camera.ViewportSize
    local fovY     = math.rad(Camera.FieldOfView)
    local focal    = (vp.Y * 0.5) / math.tan(fovY * 0.5)
    local pxOffX   = cross.X - vp.X * 0.5
    local pxOffY   = cross.Y - vp.Y * 0.5
    local yawOff   = math.atan(pxOffX / focal)
    local pitchOff = math.atan(pxOffY / focal)
    local targetCF = lookCF * CFrame.Angles(pitchOff, yawOff, 0)

    local smooth    = math.clamp(S.aimlockSmoothing or 1, 0.05, 1)
    local newCF     = Camera.CFrame:Lerp(targetCF, smooth)

    local maxDeg = S.aimlockMaxDegPerFrame or 0
    if maxDeg > 0 then
        local curLook = Camera.CFrame.LookVector
        local newLook = newCF.LookVector
        local dot     = math.clamp(curLook:Dot(newLook), -1, 1)
        local angDeg  = math.deg(math.acos(dot))
        if angDeg > maxDeg then
            local f = maxDeg / angDeg
            newCF = Camera.CFrame:Lerp(newCF, f)
        end
    end
    Camera.CFrame = newCF

    if Aimlock.statusLabel then
        local tag = isOnLockList(t) and " [LIST]" or ""
        Aimlock.statusLabel.Text = "Locked: " .. t.Name .. tag
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
    -- Aimlock toggle (default P) â€” in Hold-to-aim mode the key arms _holdActive
    -- only; in classic mode it toggles the feature on/off.
    if k == S.aimlockKey then
        if S.aimlockHoldToAim then
            Aimlock._holdActive = true
            if not S.aimlockEnabled then setAimlock(true) end
        else
            setAimlock(not S.aimlockEnabled)
        end
    end
end)

-- Release Hold-to-aim when the keybind is released.
UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if S.aimlockHoldToAim and input.KeyCode == S.aimlockKey then
        Aimlock._holdActive = false
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
--  ATTRIBUTION PANEL  â€” "Fly Animation Script / Made by DanielCheeseSauce"
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
--    â€¢ Touch moves < DRAG_THRESH px  â†’ fires callback (tap)
--    â€¢ Touch moves >= DRAG_THRESH px â†’ drags the button
-- ============================================================
local DRAG_THRESH = 12  -- pixels of movement before drag kicks in
local WING_ICON   = "rbxassetid://14578418956"

local allButtons = {}

local function makeButton(name, initPos, initSize, label, color, callback)
    local frame = Instance.new("Frame")
    frame.Name                  = name
    frame.Size                  = initSize
    frame.Position              = initPos
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel       = 0
    frame.Active                = true
    frame.Parent                = SG

    -- Full-frame image (replaces the old wing icon + text style)
    local icon = Instance.new("ImageLabel")
    icon.Size               = UDim2.new(1, 0, 1, 0)
    icon.Position           = UDim2.new(0, 0, 0, 0)
    icon.AnchorPoint        = Vector2.new(0, 0)
    icon.BackgroundTransparency = 1
    icon.Image              = ""
    icon.ImageColor3        = Color3.new(1, 1, 1)
    icon.ScaleType          = Enum.ScaleType.Fit
    icon.Parent             = frame

    -- Hidden label kept so existing code referencing .lbl doesn't error
    local lbl = Instance.new("TextLabel")
    lbl.Name                = "Lbl"
    lbl.Size                = UDim2.new(1, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = ""
    lbl.TextTransparency    = 1
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

        -- It was a tap (not a drag) â€” fire callback
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

-- â”€â”€ Studs notification button (per user spec: tap â†’ notification) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Also doubles as the 5-presses-in-10s secret unlock trigger.
-- Studs mobile button removed per user request â€” the action lives inside
-- Settings â–¸ Stages now ("Show Studs Notification"). Kept the global hook
-- (__FlyScript_ShowStuds) so the Settings button and the secret 5-press
-- counter still work from a single code path.

-- â”€â”€ Aimlock toggle button (mobile users / quick toggle on PC) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local aimlockBtnObj = makeButton("AimlockBtn",
    S.aimlockBtnPos,
    S.btnSize,
    "Aimlock [P]",
    Color3.fromRGB(180, 30, 30),
    function()
        -- In Hold-to-aim mode the click handler is a no-op; press/release
        -- below drives _holdActive instead.
        if S.aimlockHoldToAim then return end
        if _G.__FlyScript_SetAimlock then _G.__FlyScript_SetAimlock(not S.aimlockEnabled) end
    end)
-- Hold-to-aim wiring for the on-screen button (touch + mouse).
do
    local function isHoldInput(input)
        return input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
    end
    aimlockBtnObj.frame.InputBegan:Connect(function(input)
        if not S.aimlockHoldToAim then return end
        if not isHoldInput(input) then return end
        Aimlock._holdActive = true
        if not S.aimlockEnabled and _G.__FlyScript_SetAimlock then
            _G.__FlyScript_SetAimlock(true)
        end
    end)
    aimlockBtnObj.frame.InputEnded:Connect(function(input)
        if not S.aimlockHoldToAim then return end
        if not isHoldInput(input) then return end
        Aimlock._holdActive = false
    end)
end
aimlockBtnObj.icon.Image                  = S.aimlockOffImg or ""
aimlockBtnObj.frame.BackgroundColor3      = Color3.fromRGB(40, 20, 20)
aimlockBtnObj.frame.BackgroundTransparency = 0.2
aimlockBtnObj.frame.Visible               = true
do
    local r = Instance.new("UICorner")
    r.CornerRadius = UDim.new(0.5, 0); r.Parent = aimlockBtnObj.frame
end
-- Fallback text label so even if the icon fails to load, the button is still
-- visible and tappable on mobile.
do
    local fb = Instance.new("TextLabel")
    fb.Name                  = "Fallback"
    fb.Size                  = UDim2.new(1, 0, 1, 0)
    fb.BackgroundTransparency= 1
    fb.Text                  = "AIM"
    fb.TextScaled            = true
    fb.Font                  = Enum.Font.GothamBold
    fb.TextColor3            = Color3.fromRGB(255, 220, 220)
    fb.TextStrokeTransparency= 0.4
    fb.ZIndex                = aimlockBtnObj.icon.ZIndex - 1
    fb.Parent                = aimlockBtnObj.frame
end

-- Public hook used by setAimlock() to swap the button icon and tint
_G.__FlyScript_UpdateAimlockBtn = function()
    if not aimlockBtnObj then return end
    if S.aimlockEnabled then
        aimlockBtnObj.icon.Image            = S.aimlockOnImg or ""
        aimlockBtnObj.frame.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    else
        aimlockBtnObj.icon.Image            = S.aimlockOffImg or ""
        aimlockBtnObj.frame.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    end
end

-- ============================================================
--  BUTTON STATE UPDATE LOOP
-- ============================================================
RunService.Heartbeat:Connect(function()
    floatBtnObj.frame.Visible      = State.enabled
    flyBtnObj.frame.Visible        = State.enabled and State.floating
    boostBtnObj.frame.Visible      = State.enabled and State.flying
    shiftlockBtnObj.frame.Visible  = State.enabled and State.floating
    autoPilotBtnObj.frame.Visible  = State.enabled and State.floating

    -- Float button
    floatBtnObj.icon.Image = State.floating
        and "rbxthumb://type=Asset&id=99282157892103&w=420&h=420"
        or  "rbxthumb://type=Asset&id=107043944446897&w=420&h=420"

    -- Fly button
    flyBtnObj.icon.Image = State.flying
        and "rbxthumb://type=Asset&id=83365742847607&w=420&h=420"
        or  "rbxthumb://type=Asset&id=110447319415120&w=420&h=420"

    -- Boost button
    if State.boostCD or State.boostActive then
        boostBtnObj.icon.Image = "rbxthumb://type=Asset&id=100154015228522&w=420&h=420"
    else
        boostBtnObj.icon.Image = "rbxthumb://type=Asset&id=82335352657772&w=420&h=420"
    end

    -- Look / Shiftlock button
    shiftlockBtnObj.icon.Image = State.shiftlock
        and "rbxthumb://type=Asset&id=75499482931389&w=420&h=420"
        or  "rbxthumb://type=Asset&id=113215936327929&w=420&h=420"

    -- Auto-Pilot button
    autoPilotBtnObj.icon.Image = State.autoPilot
        and "rbxthumb://type=Asset&id=76493728917963&w=420&h=420"
        or  "rbxthumb://type=Asset&id=75924365902198&w=420&h=420"
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

local enableToggles = {}  -- collected enable-style toggles (forced OFF after build)

local function buildUI()
    enableToggles = {}
    Window = Rayfield:CreateWindow({
        Name                   = "FlyScript",
        Icon                   = 0,
        LoadingTitle           = "FlyScript  v3",
        LoadingSubtitle        = "Float  â€¢  Fly  â€¢  Boost",
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

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  MAIN TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  FLY SETTINGS TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local FT = Window:CreateTab("Fly Settings", 4483362458)

    FT:CreateSection("Speed")
    FT:CreateSlider({ Name = "Fly Speed",          Range = {5,2500}, Increment = 5,  Suffix = "/s", CurrentValue = S.flySpeed,       Flag = "FlySpeed",  Callback = function(v) S.flySpeed = v end })
    FT:CreateSlider({ Name = "Float Speed",        Range = {2,2500}, Increment = 2,  Suffix = "/s", CurrentValue = S.floatMoveSpeed, Flag = "FloatSpd",  Callback = function(v) S.floatMoveSpeed = v end })

    FT:CreateSection("Acceleration  (50 = 100% baseline; >100 speed slows the climb)")
    FT:CreateToggle({ Name = "Acceleration (off = instant)", CurrentValue = S.accelEnabled, Flag = "AccelOn",
        Callback = function(v) S.accelEnabled = v end })
    FT:CreateSlider({ Name = "Fly Accel  (50 = 100%)",  Range = {1,50}, Increment = 1, CurrentValue = S.flyAccel,   Flag = "FlyAccel",  Callback = function(v) S.flyAccel = v end })
    FT:CreateSlider({ Name = "Float Accel (50 = 100%)", Range = {1,50}, Increment = 1, CurrentValue = S.floatAccel, Flag = "FloatAccel",Callback = function(v) S.floatAccel = v end })

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

    FT:CreateSection("Directional Movement Anims  (strafe / yaw / locomotion)")
    FT:CreateToggle({ Name = "Enable Directional Anims", CurrentValue = S.directionalAnimsEnabled, Flag = "DirAnimOn",
        Callback = function(v) S.directionalAnimsEnabled = v end })
    FT:CreateSlider({ Name = "Directional Tilt", Range = {0,3}, Increment = 1, CurrentValue = S.directionalTilt, Flag = "DirTilt",
        Callback = function(v) S.directionalTilt = v end })
    FT:CreateInput({ Name = "Forward Anim ID  (Roblox anim or model â€” empty = fallback)", PlaceholderText = "blank = uses Fly Anim", RemoveTextAfterFocusLost = false, Flag = "FlyFwdId",
        Callback = function(v) S.flyForwardAnimId = v; reloadAnims() end })
    FT:CreateInput({ Name = "Backward Anim ID", PlaceholderText = "blank = uses Fly Anim", RemoveTextAfterFocusLost = false, Flag = "FlyBackId",
        Callback = function(v) S.flyBackwardAnimId = v; reloadAnims() end })
    FT:CreateInput({ Name = "Strafe Left Anim ID", PlaceholderText = "blank = uses Fly Anim", RemoveTextAfterFocusLost = false, Flag = "FlyLeftId",
        Callback = function(v) S.flyLeftAnimId = v; reloadAnims() end })
    FT:CreateInput({ Name = "Strafe Right Anim ID", PlaceholderText = "blank = uses Fly Anim", RemoveTextAfterFocusLost = false, Flag = "FlyRightId",
        Callback = function(v) S.flyRightAnimId = v; reloadAnims() end })

    FT:CreateSection("Speed-Freeze  (pause acceleration at threshold then continue)")
    FT:CreateToggle({ Name = "Enable Speed-Freeze", CurrentValue = S.speedFreezeEnabled, Flag = "FreezeOn",
        Callback = function(v) S.speedFreezeEnabled = v end })
    FT:CreateSlider({ Name = "Freeze At  (lerp pauses when it reaches this speed)", Range = {20,500}, Increment = 5, Suffix = "/s", CurrentValue = S.speedFreezeAt, Flag = "FreezeAt",
        Callback = function(v) S.speedFreezeAt = v end })
    FT:CreateSlider({ Name = "Freeze Duration", Range = {0,3}, Increment = 1, Suffix = "s", CurrentValue = S.speedFreezeDuration, Flag = "FreezeDur",
        Callback = function(v) S.speedFreezeDuration = v end })

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  CINEMATIC CAMERA TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local CT = Window:CreateTab("Cinematic Cam", 4483362458)
    CT:CreateSection("Cinematic Camera  (subtle additive â€” keeps default Roblox camera)")
    CT:CreateToggle({ Name = "Enable Cinematic Camera", CurrentValue = S.cinematicEnabled, Flag = "CineOn",
        Callback = function(v) S.cinematicEnabled = v end })
    CT:CreateSlider({ Name = "Lateral Lag Strength", Range = {0,3}, Increment = 1, CurrentValue = S.cinematicLag, Flag = "CineLag",
        Callback = function(v) S.cinematicLag = v end })
    CT:CreateSlider({ Name = "Strafe Roll Strength", Range = {0,3}, Increment = 1, CurrentValue = S.cinematicRoll, Flag = "CineRoll",
        Callback = function(v) S.cinematicRoll = v end })
    CT:CreateSlider({ Name = "Speed FOV Bump", Range = {0,40}, Increment = 1, CurrentValue = S.cinematicFovBoost, Flag = "CineFov",
        Callback = function(v) S.cinematicFovBoost = v end })

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  BOOST TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local BT = Window:CreateTab("Boost", 4483362458)
    BT:CreateSection("Boost Settings")
    BT:CreateSlider({ Name = "Boost %",              Range = {1,1000},  Increment = 1,  Suffix = "%",  CurrentValue = S.boostPct,      Flag = "BoostPct",   Callback = function(v) S.boostPct = v end })
    BT:CreateSlider({ Name = "Duration (sec)",        Range = {1,20},    Increment = 1,  Suffix = "s",  CurrentValue = S.boostDuration, Flag = "BoostDur",   Callback = function(v) S.boostDuration = v end })
    BT:CreateSlider({ Name = "Cooldown (sec)",        Range = {1,30},    Increment = 1,  Suffix = "s",  CurrentValue = S.boostCooldown, Flag = "BoostCD",    Callback = function(v) S.boostCooldown = v end })
    BT:CreateSlider({ Name = "Boost Acceleration",    Range = {1,50},    Increment = 1,               CurrentValue = S.boostAccel,    Flag = "BoostAccel", Callback = function(v) S.boostAccel = v end })
    BT:CreateSlider({ Name = "Boost FOV %  (of Max)", Range = {100,400}, Increment = 5,  Suffix = "%",  CurrentValue = S.boostFovPct,   Flag = "BoostFovPct",Callback = function(v) S.boostFovPct = v end })

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  EFFECTS TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local ET = Window:CreateTab("Effects", 4483362458)
    ET:CreateSection("FOV Acceleration")
    ET:CreateToggle({ Name = "Enable FOV Acceleration", CurrentValue = S.fovEnabled, Flag = "FOVOn",
        Callback = function(v)
            S.fovEnabled = v
            if not v then TweenService:Create(Camera, TweenInfo.new(0.5), { FieldOfView = State.defaultFOV }):Play() end
        end
    })
    ET:CreateSlider({ Name = "Max FOV  (up to 500%)", Range = {70,500}, Increment = 5, Suffix = "Â°", CurrentValue = S.fovMax, Flag = "FOVMax", Callback = function(v) S.fovMax = v end })
    ET:CreateSlider({ Name = "FOV Accel Rate", Range = {5,100},  Increment = 5,  CurrentValue = S.fovRate, Flag = "FOVRate", Callback = function(v) S.fovRate = v end })

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  MUSIC TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  SOUND EFFECTS TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local SE = Window:CreateTab("Sound FX", 4483362458)

    -- â”€â”€ Fly Sound â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€ Boost Hit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    SE:CreateSection("Boost Hit  (plays once when boost activates)")
    SE:CreateInput({ Name = "Boost Hit SFX ID", PlaceholderText = "Roblox sound ID", RemoveTextAfterFocusLost = false, Flag = "SFXBoostHitId",
        Callback = function(v) S.sfxBoostHitId = v; reloadSoundId("boostHit", v); Rayfield:Notify({ Title = "Boost Hit SFX", Content = v == "" and "Cleared." or "Set!", Duration = 2 }) end })
    SE:CreateSlider({ Name = "Boost Hit Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxBoostHitVolume, Flag = "SFXBoostHitVol",
        Callback = function(v) S.sfxBoostHitVolume = v; if Sounds.boostHit then Sounds.boostHit.Volume = v / 100 end end })
    SE:CreateSlider({ Name = "Boost Hit Distance (studs)", Range = {10,500}, Increment = 10, Suffix = " st", CurrentValue = S.sfxBoostHitDist, Flag = "SFXBHDist",
        Callback = function(v) S.sfxBoostHitDist = v; applyRollOff(Sounds.boostHit, v, S.sfxBoostHitFade) end })
    SE:CreateToggle({ Name = "Boost Hit Fade (louder the closer you are)", CurrentValue = S.sfxBoostHitFade, Flag = "SFXBHFade",
        Callback = function(v) S.sfxBoostHitFade = v; applyRollOff(Sounds.boostHit, S.sfxBoostHitDist, v) end })

    -- â”€â”€ Boost Loop â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    SE:CreateSection("Boost Loop  (loops while boost is active)")
    SE:CreateInput({ Name = "Boost Loop SFX ID", PlaceholderText = "Roblox sound ID", RemoveTextAfterFocusLost = false, Flag = "SFXBoostLoopId",
        Callback = function(v) S.sfxBoostLoopId = v; reloadSoundId("boostLoop", v); Rayfield:Notify({ Title = "Boost Loop SFX", Content = v == "" and "Cleared." or "Set!", Duration = 2 }) end })
    SE:CreateSlider({ Name = "Boost Loop Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxBoostLoopVolume, Flag = "SFXBoostLoopVol",
        Callback = function(v) S.sfxBoostLoopVolume = v; if Sounds.boostLoop then Sounds.boostLoop.Volume = v / 100 end end })
    SE:CreateSlider({ Name = "Boost Loop Distance (studs)", Range = {10,500}, Increment = 10, Suffix = " st", CurrentValue = S.sfxBoostLoopDist, Flag = "SFXBLDist",
        Callback = function(v) S.sfxBoostLoopDist = v; applyRollOff(Sounds.boostLoop, v, S.sfxBoostLoopFade) end })
    SE:CreateToggle({ Name = "Boost Loop Fade (louder the closer you are)", CurrentValue = S.sfxBoostLoopFade, Flag = "SFXBLFade",
        Callback = function(v) S.sfxBoostLoopFade = v; applyRollOff(Sounds.boostLoop, S.sfxBoostLoopDist, v) end })

    -- â”€â”€ Near-Player Fly â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€ Environmental Sound â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    SE:CreateSection("Environmental Sound  (looping ambient SFX in the world)")
    SE:CreateToggle({ Name = "Enable Environmental SFX", CurrentValue = S.sfxEnvEnabled, Flag = "SFXEnvOn",
        Callback = function(v)
            S.sfxEnvEnabled = v
            if Sounds.env then
                if v and S.sfxEnvId ~= "" then Sounds.env:Play() else Sounds.env:Stop() end
            end
        end })
    SE:CreateInput({ Name = "Environmental SFX ID", PlaceholderText = "Roblox sound ID", RemoveTextAfterFocusLost = false, Flag = "SFXEnvId",
        Callback = function(v)
            S.sfxEnvId = v; reloadSoundId("env", v)
            if S.sfxEnvEnabled and v ~= "" and Sounds.env then Sounds.env:Play() end
            Rayfield:Notify({ Title = "Env SFX", Content = v == "" and "Cleared." or "Set!", Duration = 2 })
        end })
    SE:CreateSlider({ Name = "Env SFX Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxEnvVolume, Flag = "SFXEnvVol",
        Callback = function(v) S.sfxEnvVolume = v; if Sounds.env then Sounds.env.Volume = v / 100 end end })
    SE:CreateSlider({ Name = "Env SFX Distance (studs)", Range = {10,1000}, Increment = 10, Suffix = " st", CurrentValue = S.sfxEnvDist, Flag = "SFXEnvDist",
        Callback = function(v) S.sfxEnvDist = v; applyRollOff(Sounds.env, v, S.sfxEnvFade) end })
    SE:CreateToggle({ Name = "Env SFX Fade (louder the closer you are)", CurrentValue = S.sfxEnvFade, Flag = "SFXEnvFade",
        Callback = function(v) S.sfxEnvFade = v; applyRollOff(Sounds.env, S.sfxEnvDist, v) end })

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  CLIENT IMPACTS TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local IT = Window:CreateTab("Client Impacts", 4483362458)

    -- Helper: register an "enable" toggle that won't auto-restore on script load
    local function addEnableToggle(tab, name, getter, setter)
        local tog = tab:CreateToggle({
            Name         = name,
            CurrentValue = false,   -- always start OFF
            Callback     = function(v) setter(v) end,
        })
        table.insert(enableToggles, tog)
        return tog
    end
    -- Helper: input row for sound id (numeric)
    local function addSoundIdRow(tab, label, getter, setter)
        tab:CreateInput({
            Name                     = label,
            PlaceholderText          = "Sound ID (numeric)",
            RemoveTextAfterFocusLost = false,
            Flag                     = "SID_" .. label:gsub("%s","_"):gsub("%W",""),
            Callback                 = function(v) setter(v) end,
        })
    end

    IT:CreateSection("Master")
    addEnableToggle(IT, "Enable Impact System",
        function() return S.impactsEnabled end,
        function(v) S.impactsEnabled = v end)
    IT:CreateSlider({ Name = "Min Impact Speed", Range = {5,500}, Increment = 5, Suffix = "/s", CurrentValue = S.impactMinSpeed, Flag = "ImpactMinSpd",
        Callback = function(v) S.impactMinSpeed = v end })
    IT:CreateSlider({ Name = "Size Scale Start  (speed where sizes start growing)", Range = {50,2000}, Increment = 10, Suffix = "/s", CurrentValue = S.impactSpeedScaleStart, Flag = "ImpactSizeStart",
        Callback = function(v) S.impactSpeedScaleStart = v end })
    IT:CreateSlider({ Name = "Size Scale Max Speed  (speed that produces max radius)", Range = {500,20000}, Increment = 100, Suffix = "/s", CurrentValue = S.impactSpeedScaleMaxSpeed, Flag = "ImpactSizeMax",
        Callback = function(v) S.impactSpeedScaleMaxSpeed = v end })
    IT:CreateSlider({ Name = "Max Impact Radius (studs)", Range = {50,10000}, Increment = 50, Suffix = " st", CurrentValue = S.impactMaxRadius, Flag = "ImpactMaxR",
        Callback = function(v) S.impactMaxRadius = v end })
    IT:CreateSlider({ Name = "Base Impact Radius (studs)", Range = {1,200}, Increment = 1, Suffix = " st", CurrentValue = S.impactBaseRadius, Flag = "ImpactBaseR",
        Callback = function(v) S.impactBaseRadius = v end })
    IT:CreateToggle({ Name = "Affect Bricks/Parts (cracks/decals on parts too)", CurrentValue = S.impactAffectParts, Flag = "ImpactParts",
        Callback = function(v) S.impactAffectParts = v end })

    IT:CreateSection("Slide Impact  (violent ongoing impact while sliding ground)")
    addEnableToggle(IT, "Enable Slide Impact",
        function() return S.impactSlideEnabled end,
        function(v) S.impactSlideEnabled = v end)
    IT:CreateSlider({ Name = "Slide Emit Rate (sec between bursts)", Range = {1,100}, Increment = 1, Suffix = " (Ã—0.01s)", CurrentValue = math.floor(S.impactSlideRate * 100), Flag = "SlideRate",
        Callback = function(v) S.impactSlideRate = v / 100 end })
    addSoundIdRow(IT, "Slide Sound ID", function() return S.sfxSlideId end, function(v) S.sfxSlideId = v end)
    IT:CreateSlider({ Name = "Slide Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxSlideVol, Flag = "SlideVol",
        Callback = function(v) S.sfxSlideVol = v end })

    IT:CreateSection("Shockwave")
    addEnableToggle(IT, "Enable Shockwave",
        function() return S.fxShockwaveEnabled end,
        function(v) S.fxShockwaveEnabled = v end)
    IT:CreateSlider({ Name = "Shockwave Trigger Speed", Range = {0,2000}, Increment = 5, Suffix = "/s", CurrentValue = S.fxShockwaveTrigger, Flag = "FXShockTrig",
        Callback = function(v) S.fxShockwaveTrigger = v end })
    IT:CreateSlider({ Name = "Shockwave Size Multiplier", Range = {1,10}, Increment = 1, CurrentValue = S.fxShockwaveSize, Flag = "FXShockSize",
        Callback = function(v) S.fxShockwaveSize = v end })
    addSoundIdRow(IT, "Shockwave Sound ID", function() return S.sfxShockwaveId end, function(v) S.sfxShockwaveId = v end)
    IT:CreateSlider({ Name = "Shockwave Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxShockwaveVol, Flag = "ShockVol",
        Callback = function(v) S.sfxShockwaveVol = v end })

    IT:CreateSection("Debris Burst  (player walks/flies through debris)")
    addEnableToggle(IT, "Enable Debris",
        function() return S.fxDebrisEnabled end,
        function(v) S.fxDebrisEnabled = v end)
    IT:CreateSlider({ Name = "Debris Trigger Speed", Range = {0,2000}, Increment = 5, Suffix = "/s", CurrentValue = S.fxDebrisTrigger, Flag = "FXDebrisTrig",
        Callback = function(v) S.fxDebrisTrigger = v end })
    IT:CreateSlider({ Name = "Debris Size Multiplier", Range = {1,10}, Increment = 1, CurrentValue = S.fxDebrisSize, Flag = "FXDebrisSize",
        Callback = function(v) S.fxDebrisSize = v end })
    IT:CreateSlider({ Name = "Max Chunks Cap", Range = {1,200}, Increment = 1, CurrentValue = S.debrisChunksMax, Flag = "DebrisCap",
        Callback = function(v) S.debrisChunksMax = v end })
    IT:CreateSlider({ Name = "Small Chunks Count", Range = {0,50}, Increment = 1, CurrentValue = S.debrisSmallCount, Flag = "DebrisSmall",
        Callback = function(v) S.debrisSmallCount = v end })
    IT:CreateSlider({ Name = "Medium Chunks Count", Range = {0,50}, Increment = 1, CurrentValue = S.debrisMediumCount, Flag = "DebrisMed",
        Callback = function(v) S.debrisMediumCount = v end })
    IT:CreateSlider({ Name = "Large Chunks Count", Range = {0,30}, Increment = 1, CurrentValue = S.debrisLargeCount, Flag = "DebrisLarge",
        Callback = function(v) S.debrisLargeCount = v end })
    IT:CreateToggle({ Name = "Debris Collides With World (player always passes through)", CurrentValue = S.debrisCanCollide, Flag = "DebrisColl",
        Callback = function(v) S.debrisCanCollide = v end })
    IT:CreateSlider({ Name = "Max Debris On Screen (anti-lag cap)", Range = {10, 400}, Increment = 10,
        CurrentValue = S.debrisGlobalMax, Flag = "DebrisGlobalMax",
        Callback = function(v) S.debrisGlobalMax = v end })
    IT:CreateInput({ Name = "Debris Despawn (seconds)  1..600", PlaceholderText = tostring(S.debrisDespawnSec), RemoveTextAfterFocusLost = true, Flag = "DebrisDespawn",
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 1 and n <= 600 then
                S.debrisDespawnSec = n
                Rayfield:Notify({ Title = "Debris", Content = "Despawn = " .. n .. "s", Duration = 2 })
            else
                Rayfield:Notify({ Title = "Invalid", Content = "Enter a number 1..600.", Duration = 2 })
            end
        end })
    addSoundIdRow(IT, "Debris Sound ID", function() return S.sfxDebrisId end, function(v) S.sfxDebrisId = v end)
    IT:CreateSlider({ Name = "Debris Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxDebrisVol, Flag = "DebrisVol",
        Callback = function(v) S.sfxDebrisVol = v end })

    IT:CreateSection("Ground Cracks")
    addEnableToggle(IT, "Enable Cracks",
        function() return S.fxCracksEnabled end,
        function(v) S.fxCracksEnabled = v end)
    IT:CreateSlider({ Name = "Cracks Trigger Speed", Range = {0,2000}, Increment = 5, Suffix = "/s", CurrentValue = S.fxCracksTrigger, Flag = "FXCracksTrig",
        Callback = function(v) S.fxCracksTrigger = v end })
    IT:CreateSlider({ Name = "Cracks Size Multiplier", Range = {1,10}, Increment = 1, CurrentValue = S.fxCracksSize, Flag = "FXCracksSize",
        Callback = function(v) S.fxCracksSize = v end })
    addSoundIdRow(IT, "Cracks Sound ID", function() return S.sfxCracksId end, function(v) S.sfxCracksId = v end)
    IT:CreateSlider({ Name = "Cracks Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxCracksVol, Flag = "CracksVol",
        Callback = function(v) S.sfxCracksVol = v end })

    IT:CreateSection("Dust Explosion")
    addEnableToggle(IT, "Enable Dust",
        function() return S.fxDustEnabled end,
        function(v) S.fxDustEnabled = v end)
    IT:CreateSlider({ Name = "Dust Trigger Speed", Range = {0,2000}, Increment = 5, Suffix = "/s", CurrentValue = S.fxDustTrigger, Flag = "FXDustTrig",
        Callback = function(v) S.fxDustTrigger = v end })
    IT:CreateSlider({ Name = "Dust Size Multiplier", Range = {1,10}, Increment = 1, CurrentValue = S.fxDustSize, Flag = "FXDustSize",
        Callback = function(v) S.fxDustSize = v end })
    addSoundIdRow(IT, "Dust Sound ID", function() return S.sfxDustId end, function(v) S.sfxDustId = v end)
    IT:CreateSlider({ Name = "Dust Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxDustVol, Flag = "DustVol",
        Callback = function(v) S.sfxDustVol = v end })

    IT:CreateSection("Energy Pulse")
    addEnableToggle(IT, "Enable Energy Pulse",
        function() return S.fxEnergyPulseEnabled end,
        function(v) S.fxEnergyPulseEnabled = v end)
    IT:CreateSlider({ Name = "Pulse Trigger Speed", Range = {0,2000}, Increment = 5, Suffix = "/s", CurrentValue = S.fxEnergyPulseTrigger, Flag = "FXPulseTrig",
        Callback = function(v) S.fxEnergyPulseTrigger = v end })
    IT:CreateSlider({ Name = "Pulse Size Multiplier", Range = {1,10}, Increment = 1, CurrentValue = S.fxEnergyPulseSize, Flag = "FXPulseSize",
        Callback = function(v) S.fxEnergyPulseSize = v end })
    addSoundIdRow(IT, "Pulse Sound ID", function() return S.sfxEnergyPulseId end, function(v) S.sfxEnergyPulseId = v end)
    IT:CreateSlider({ Name = "Pulse Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxEnergyPulseVol, Flag = "PulseVol",
        Callback = function(v) S.sfxEnergyPulseVol = v end })

    IT:CreateSection("Speed Trail  (continuous high-speed effect)")
    addEnableToggle(IT, "Enable Speed Trail",
        function() return S.fxSpeedTrailEnabled end,
        function(v) S.fxSpeedTrailEnabled = v end)
    IT:CreateSlider({ Name = "Speed Trail Trigger Speed", Range = {0,2000}, Increment = 5, Suffix = "/s", CurrentValue = S.fxSpeedTrailTrigger, Flag = "FXTrailTrig",
        Callback = function(v) S.fxSpeedTrailTrigger = v end })
    addSoundIdRow(IT, "Speed Trail Sound ID", function() return S.sfxSpeedTrailId end, function(v) S.sfxSpeedTrailId = v end)
    IT:CreateSlider({ Name = "Speed Trail Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxSpeedTrailVol, Flag = "TrailVol",
        Callback = function(v) S.sfxSpeedTrailVol = v end })

    IT:CreateSection("Crater  (fills terrain with Air at the impact site)")
    addEnableToggle(IT, "Enable Crater",
        function() return S.craterEnabled end,
        function(v) S.craterEnabled = v end)
    IT:CreateSlider({ Name = "Crater Depth Multiplier", Range = {1,10}, Increment = 1, CurrentValue = S.craterDepthMul, Flag = "CraterDepth",
        Callback = function(v) S.craterDepthMul = v end })
    addSoundIdRow(IT, "Crater Sound ID", function() return S.sfxCraterId end, function(v) S.sfxCraterId = v end)
    IT:CreateSlider({ Name = "Crater Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxCraterVol, Flag = "CraterVol",
        Callback = function(v) S.sfxCraterVol = v end })

    IT:CreateSection("Crater on Bricks  (deforms big static parts on hard impact)")
    IT:CreateToggle({ Name = "Enable Brick Crater", CurrentValue = S.craterPartEnabled, Flag = "CraterPartOn",
        Callback = function(v) S.craterPartEnabled = v end })
    IT:CreateSlider({ Name = "Min Brick Size (smallest axis, studs)", Range = {2, 200}, Increment = 1, Suffix = " st",
        CurrentValue = S.craterPartMinSize, Flag = "CraterPartMin",
        Callback = function(v) S.craterPartMinSize = v end })
    IT:CreateSlider({ Name = "Max Brick Size (longest axis, studs)", Range = {50, 5000}, Increment = 25, Suffix = " st",
        CurrentValue = S.craterPartMaxSize, Flag = "CraterPartMax",
        Callback = function(v) S.craterPartMaxSize = v end })
    IT:CreateSlider({ Name = "Chunk Size (smaller = finer crater, slower)", Range = {1, 20}, Increment = 1, Suffix = " st",
        CurrentValue = S.craterPartChunkSize, Flag = "CraterPartChunk",
        Callback = function(v) S.craterPartChunkSize = v end })
    IT:CreateSlider({ Name = "Min Impact Speed for Brick Crater", Range = {20, 2000}, Increment = 10, Suffix = "/s",
        CurrentValue = S.craterPartMinSpeed, Flag = "CraterPartSpd",
        Callback = function(v) S.craterPartMinSpeed = v end })

    IT:CreateSection("Terrain Dig  (continuous tunnel while flying through terrain)")
    addEnableToggle(IT, "Enable Terrain Dig",
        function() return S.digTerrainWhileFlying end,
        function(v) S.digTerrainWhileFlying = v end)
    IT:CreateSlider({ Name = "Min Dig Speed", Range = {20,2000}, Increment = 10, Suffix = "/s", CurrentValue = S.digMinSpeed, Flag = "DigMinSpd",
        Callback = function(v) S.digMinSpeed = v end })
    addSoundIdRow(IT, "Dig Sound ID", function() return S.sfxDigId end, function(v) S.sfxDigId = v end)
    IT:CreateSlider({ Name = "Dig Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxDigVol, Flag = "DigVol",
        Callback = function(v) S.sfxDigVol = v end })

    IT:CreateSection("Phase-Through  (player flies through bricks inside the hitbox)")
    addEnableToggle(IT, "Enable Phase-Through",
        function() return S.phaseEnabled end,
        function(v) S.phaseEnabled = v end)
    IT:CreateSlider({ Name = "Hitbox Size (studs)", Range = {2,200}, Increment = 1, Suffix = " st", CurrentValue = S.phaseHitboxSize, Flag = "PhaseHitbox",
        Callback = function(v) S.phaseHitboxSize = v end })
    IT:CreateSlider({ Name = "Max Part Size to Phase (longest axis)", Range = {1,500}, Increment = 1, Suffix = " st", CurrentValue = S.phaseMaxPartSize, Flag = "PhaseMaxSz",
        Callback = function(v) S.phaseMaxPartSize = v end })
    IT:CreateSlider({ Name = "Min Phase Speed", Range = {10,2000}, Increment = 5, Suffix = "/s", CurrentValue = S.phaseMinSpeed, Flag = "PhaseMinSpd",
        Callback = function(v) S.phaseMinSpeed = v end })
    IT:CreateToggle({ Name = "Leave Hole (destroy the part on entry)", CurrentValue = S.phaseLeaveHole, Flag = "PhaseHole",
        Callback = function(v) S.phaseLeaveHole = v end })
    addSoundIdRow(IT, "Phase Sound ID", function() return S.sfxPhaseId end, function(v) S.sfxPhaseId = v end)
    IT:CreateSlider({ Name = "Phase Sound Volume", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = S.sfxPhaseVol, Flag = "PhaseVol",
        Callback = function(v) S.sfxPhaseVol = v end })

    IT:CreateSection("Map Reset")
    IT:CreateButton({ Name = "Reset Map  (restore moved/destroyed parts and clear FX)", Callback = function()
        resetMap()
    end })
    IT:CreateToggle({ Name = "Auto Refresh Map", CurrentValue = S.autoRefreshMapEnabled, Flag = "AutoRefMap",
        Callback = function(v) S.autoRefreshMapEnabled = v end })
    IT:CreateSlider({ Name = "Auto Refresh Interval (minutes)", Range = {1,120}, Increment = 1, Suffix = " min", CurrentValue = S.autoRefreshMinutes, Flag = "AutoRefMin",
        Callback = function(v) S.autoRefreshMinutes = v end })

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  SETTINGS TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        if ImpactBin then pcall(function() ImpactBin:Destroy() end) end
        if _trailEmitter then pcall(function() _trailEmitter:Destroy() end) end
        destroyStudsGui(); destroyArrowGui(); clearStageProps(); clearSkybox(); setGreenLighting(false)
        SG:Destroy()
        Rayfield:Destroy()
    end})

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  WORLD TAB  (Robloxia / Alien â€” gated behind the secret unlock)
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local WT = Window:CreateTab("World", 4483362458)
    WT:CreateSection("World Mode")
    WT:CreateLabel("Press the Studs button 5 times in 10 seconds, or reach Stage 6, to unlock the alien world.")
    local worldDropdown = WT:CreateDropdown({
        Name = "Active World",
        Options = { "Robloxia", "Alien" },
        CurrentOption = (S.alienWorldActive and "Alien") or "Robloxia",
        Flag = "ActiveWorld",
        Callback = function(opt)
            local pick = type(opt) == "table" and opt[1] or opt
            if pick == "Alien" then
                if not (S.alienWorldUnlocked or Stages.fivePressUnlocked) then
                    Rayfield:Notify({ Title = "Locked", Content = "Find the secret to unlock this.", Duration = 4 })
                    return
                end
                S.alienWorldActive = true
                setGreenLighting(true)
                if _G.__FlyScript_RefreshAlienHooks then _G.__FlyScript_RefreshAlienHooks() end
            else
                S.alienWorldActive = false
                setGreenLighting(false)
                if _G.__FlyScript_RefreshAlienHooks then _G.__FlyScript_RefreshAlienHooks() end
            end
        end,
    })
    WT:CreateButton({ Name = "Force Enter Stage 6 (alien world)", Callback = function() enterStage(6) end })

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  AIMLOCK TAB
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local AT = Window:CreateTab("Aimlock", 4483362458)
    AT:CreateSection("Master  (works locally â€” PC keybind [P], mobile uses on-screen button)")
    AT:CreateToggle({ Name = "Enable Aimlock System", CurrentValue = S.aimlockEnabled, Flag = "AimlockOn",
        Callback = function(v) if _G.__FlyScript_SetAimlock then _G.__FlyScript_SetAimlock(v) end end })

    AT:CreateSection("FOV / Range")
    AT:CreateSlider({ Name = "FOV Scaling (pixel radius)", Range = {20, 600}, Increment = 5, Suffix = " px",
        CurrentValue = S.aimlockFOV, Flag = "AimFOV",
        Callback = function(v) S.aimlockFOV = v end })
    AT:CreateToggle({ Name = "Show FOV Ring", CurrentValue = S.aimlockShowFOV, Flag = "AimShowFOV",
        Callback = function(v) S.aimlockShowFOV = v end })
    AT:CreateSlider({ Name = "Range (studs)", Range = {50, 5000}, Increment = 25, Suffix = " st",
        CurrentValue = S.aimlockRange, Flag = "AimRange",
        Callback = function(v) S.aimlockRange = v end })

    AT:CreateSection("Behavior")
    AT:CreateToggle({ Name = "Lock Player (sticky â€” keep target until aimlock off / target dies)",
        CurrentValue = S.aimlockStickyLock, Flag = "AimSticky",
        Callback = function(v) S.aimlockStickyLock = v end })
    AT:CreateToggle({ Name = "Smart AI (lead moving targets â€” predicts position)",
        CurrentValue = S.aimlockSmartAI, Flag = "AimSmartAI",
        Callback = function(v) S.aimlockSmartAI = v end })
    AT:CreateSlider({ Name = "Smart AI Strength (0 = none, 2 = aggressive)", Range = {0, 200}, Increment = 5, Suffix = " %",
        CurrentValue = math.floor((S.aimlockPredictStrength or 1) * 100), Flag = "AimPredict",
        Callback = function(v) S.aimlockPredictStrength = v / 100 end })
    AT:CreateSlider({ Name = "Smoothing (1% = silky-slow, 100% = instant snap)", Range = {5, 100}, Increment = 1, Suffix = " %",
        CurrentValue = math.floor((S.aimlockSmoothing or 0.55) * 100), Flag = "AimSmooth",
        Callback = function(v) S.aimlockSmoothing = v / 100 end })
    AT:CreateSlider({ Name = "Max Camera Turn / Frame (0 = no limit)", Range = {0, 90}, Increment = 1, Suffix = "Â°",
        CurrentValue = S.aimlockMaxDegPerFrame, Flag = "AimMaxDeg",
        Callback = function(v) S.aimlockMaxDegPerFrame = v end })
    AT:CreateSlider({ Name = "Reacquire Delay (sticky lock grace)", Range = {0, 30}, Increment = 1, Suffix = " Ã—0.1s",
        CurrentValue = math.floor((S.aimlockReacquireDelay or 0.6) * 10), Flag = "AimReac",
        Callback = function(v) S.aimlockReacquireDelay = v / 10 end })
    AT:CreateInput({ Name = "Target Body Part (blank = use priority chain Headâ†’Torsoâ†’HRP)",
        PlaceholderText = "Head / HumanoidRootPart / UpperTorso / Torso",
        RemoveTextAfterFocusLost = false, Flag = "AimPart",
        Callback = function(v) S.aimlockPart = v or "" end })
    AT:CreateToggle({ Name = "Hold-to-Aim (engage only while keybind/button is held)",
        CurrentValue = S.aimlockHoldToAim, Flag = "AimHold",
        Callback = function(v) S.aimlockHoldToAim = v; Aimlock._holdActive = false end })
    AT:CreateToggle({ Name = "Predict Acceleration (use aÂ²tÂ² lead in addition to velocity)",
        CurrentValue = S.aimlockPredictAccel, Flag = "AimAccel",
        Callback = function(v) S.aimlockPredictAccel = v end })
    AT:CreateSlider({ Name = "Humanizer Jitter (pixels of random offset; 0 = robot)",
        Range = {0, 25}, Increment = 1, Suffix = " px",
        CurrentValue = S.aimlockHumanize or 0, Flag = "AimHum",
        Callback = function(v) S.aimlockHumanize = v end })
    AT:CreateSlider({ Name = "Miss Chance (skip aiming on N% of frames â€” looks human)",
        Range = {0, 40}, Increment = 1, Suffix = " %",
        CurrentValue = S.aimlockMissChance or 0, Flag = "AimMiss",
        Callback = function(v) S.aimlockMissChance = v end })

    AT:CreateSection("FOV Ring Color")
    AT:CreateSlider({ Name = "FOV Color R", Range = {0,255}, Increment = 5, Suffix = "",
        CurrentValue = S.aimlockFOVColorR or 255, Flag = "AimFOVR",
        Callback = function(v) S.aimlockFOVColorR = v end })
    AT:CreateSlider({ Name = "FOV Color G", Range = {0,255}, Increment = 5, Suffix = "",
        CurrentValue = S.aimlockFOVColorG or 60, Flag = "AimFOVG",
        Callback = function(v) S.aimlockFOVColorG = v end })
    AT:CreateSlider({ Name = "FOV Color B", Range = {0,255}, Increment = 5, Suffix = "",
        CurrentValue = S.aimlockFOVColorB or 60, Flag = "AimFOVB",
        Callback = function(v) S.aimlockFOVColorB = v end })

    AT:CreateSection("Safety Checks")
    AT:CreateToggle({ Name = "Wall Check (skip targets behind walls)", CurrentValue = S.aimlockWallCheck, Flag = "AimWall",
        Callback = function(v) S.aimlockWallCheck = v end })
    AT:CreateToggle({ Name = "Friend Check (skip Roblox friends)", CurrentValue = S.aimlockFriendCheck, Flag = "AimFriend",
        Callback = function(v) S.aimlockFriendCheck = v; Aimlock.friendCache = {} end })
    AT:CreateToggle({ Name = "Team Check (skip teammates)", CurrentValue = S.aimlockTeamCheck, Flag = "AimTeam",
        Callback = function(v) S.aimlockTeamCheck = v end })

    AT:CreateSection("Crosshair & Button Icons  (paste a Roblox asset id; blank to keep current)")
    AT:CreateInput({ Name = "Crosshair Image ID", PlaceholderText = "107058246184363",
        RemoveTextAfterFocusLost = true, Flag = "AimCrossImg",
        Callback = function(v)
            local id = (v or ""):match("%d+")
            if id then
                S.aimlockCrosshairImg = "rbxassetid://" .. id
                if Aimlock.crosshairImg then
                    Aimlock.crosshairImg.Image = S.aimlockCrosshairImg
                end
            end
        end })
    AT:CreateInput({ Name = "Aimlock Button Icon (OFF)", PlaceholderText = tostring(S.aimlockOffImg or ""),
        RemoveTextAfterFocusLost = true, Flag = "AimOffImg",
        Callback = function(v)
            local id = (v or ""):match("%d+")
            if id then
                S.aimlockOffImg = "rbxassetid://" .. id
                if _G.__FlyScript_UpdateAimlockBtn then _G.__FlyScript_UpdateAimlockBtn() end
            end
        end })
    AT:CreateInput({ Name = "Aimlock Button Icon (ON)", PlaceholderText = tostring(S.aimlockOnImg or ""),
        RemoveTextAfterFocusLost = true, Flag = "AimOnImg",
        Callback = function(v)
            local id = (v or ""):match("%d+")
            if id then
                S.aimlockOnImg = "rbxassetid://" .. id
                if _G.__FlyScript_UpdateAimlockBtn then _G.__FlyScript_UpdateAimlockBtn() end
            end
        end })

    AT:CreateSection("Crosshair Position")
    AT:CreateSlider({ Name = "Crosshair X (% of screen)", Range = {0, 100}, Increment = 1, Suffix = " %",
        CurrentValue = math.floor((S.aimlockCrosshairPos.X.Scale or 0.5) * 100), Flag = "AimCX",
        Callback = function(v)
            S.aimlockCrosshairPos = UDim2.new(v/100, 0, S.aimlockCrosshairPos.Y.Scale, 0)
        end })
    AT:CreateSlider({ Name = "Crosshair Y (% of screen)", Range = {0, 100}, Increment = 1, Suffix = " %",
        CurrentValue = math.floor((S.aimlockCrosshairPos.Y.Scale or 0.5) * 100), Flag = "AimCY",
        Callback = function(v)
            S.aimlockCrosshairPos = UDim2.new(S.aimlockCrosshairPos.X.Scale, 0, v/100, 0)
        end })

    AT:CreateSection("Lock Player List  (tap a name to add/remove. Listed = friend-check ignored.)")
    -- Multi-select dropdown showing every player in the server. Selecting a name
    -- adds them; tapping again removes them. The list IS the lock list.
    local lpDD
    local function _serverList()
        local out = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(out, p.Name) end
        end
        table.sort(out)
        return out
    end
    local function _currentlySelected()
        local out = {}
        for nameLower, _ in pairs(S.targetLockList) do
            -- Find matching player to get correct casing
            for _, p in ipairs(Players:GetPlayers()) do
                if string.lower(p.Name) == nameLower then
                    table.insert(out, p.Name); break
                end
            end
        end
        return out
    end
    lpDD = AT:CreateDropdown({
        Name = "Lock Player List (tap to toggle â€” multi-select)",
        Options = _serverList(),
        CurrentOption = _currentlySelected(),
        MultipleOptions = true,
        Flag = "LockList",
        Callback = function(opts)
            -- Rebuild the lock list from the dropdown's selection
            local newList = {}
            if type(opts) == "table" then
                for _, name in ipairs(opts) do
                    if type(name) == "string" and name ~= "" then
                        newList[string.lower(name)] = true
                    end
                end
            end
            S.targetLockList = newList
        end,
    })
    AT:CreateButton({ Name = "Refresh Server Player List", Callback = function()
        if lpDD and lpDD.Refresh then
            pcall(function() lpDD:Refresh(_serverList(), false) end)
        end
        Rayfield:Notify({ Title = "Lock List", Content = "Player list refreshed.", Duration = 2 })
    end })
    AT:CreateButton({ Name = "Clear Lock List", Callback = function()
        S.targetLockList = {}
        if lpDD and lpDD.Refresh then
            pcall(function() lpDD:Refresh(_serverList(), false) end)
        end
        Rayfield:Notify({ Title = "Lock List", Content = "List cleared.", Duration = 2 })
    end })
    -- Auto-refresh dropdown when players join/leave the server
    Players.PlayerAdded:Connect(function()
        if lpDD and lpDD.Refresh then pcall(function() lpDD:Refresh(_serverList(), false) end) end
    end)
    Players.PlayerRemoving:Connect(function()
        if lpDD and lpDD.Refresh then pcall(function() lpDD:Refresh(_serverList(), false) end) end
    end)

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  STAGES TAB  (the secret system, but exposed for control)
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local SGT = Window:CreateTab("Stages", 4483362458)
    SGT:CreateSection("Master")
    SGT:CreateToggle({ Name = "Enable Stages System", CurrentValue = S.stagesEnabled, Flag = "StagesOn",
        Callback = function(v)
            S.stagesEnabled = v
            if not v then
                destroyStudsGui(); destroyArrowGui()
                clearStageProps(); clearSkybox(); setGreenLighting(false)
                Stages.current = 1; Stages.distInStage = 0
            end
        end })
    SGT:CreateToggle({ Name = "Show Studs HUD", CurrentValue = S.showStudsHud, Flag = "StagesHud",
        Callback = function(v) S.showStudsHud = v end })
    -- Replaces the old on-screen Studs button. Tapping fires the same
    -- notification (and counts toward the 5-press secret unlock).
    SGT:CreateButton({ Name = "Show Studs Notification (tap to read distance)",
        Callback = function()
            if _G.__FlyScript_ShowStuds then _G.__FlyScript_ShowStuds() end
        end })

    SGT:CreateSection("Stage Distances")
    SGT:CreateSlider({ Name = "Stage 1 â†’ 2 (studs)", Range = {1000, 1000000}, Increment = 1000, Suffix = " st",
        CurrentValue = S.stage1ToStage2Studs, Flag = "S12",
        Callback = function(v) S.stage1ToStage2Studs = v end })
    SGT:CreateSlider({ Name = "Stage 2 â†’ 3 (studs)", Range = {1000, 200000}, Increment = 500, Suffix = " st",
        CurrentValue = S.stage2ToStage3Studs, Flag = "S23",
        Callback = function(v) S.stage2ToStage3Studs = v end })
    SGT:CreateSlider({ Name = "Stage 3 â†’ 4 (studs)", Range = {1000, 200000}, Increment = 500, Suffix = " st",
        CurrentValue = S.stage3ToStage4Studs, Flag = "S34",
        Callback = function(v) S.stage3ToStage4Studs = v end })
    SGT:CreateSlider({ Name = "â€œFar From Mapâ€ Distance", Range = {100, 5000}, Increment = 50, Suffix = " st",
        CurrentValue = S.farFromMapDist, Flag = "FarMap",
        Callback = function(v) S.farFromMapDist = v end })

    SGT:CreateSection("Manual Jump")
    SGT:CreateButton({ Name = "Go To Stage 1 (World)",                  Callback = function() enterStage(1) end })
    SGT:CreateButton({ Name = "Go To Stage 2 (Space + Earth)",          Callback = function() enterStage(2) end })
    SGT:CreateButton({ Name = "Go To Stage 3 (Outside Solar System)",   Callback = function() enterStage(3) end })
    SGT:CreateButton({ Name = "Go To Stage 4 (Final Planet)",           Callback = function() enterStage(4) end })
    SGT:CreateLabel("Chat: !stage1 / !stage2 / !stage3 / !stage4")
end

-- After Rayfield restores saved config, force every "enable" toggle OFF so
-- nothing turns itself on without the user explicitly enabling it again.
local _origBuildUI = buildUI
buildUI = function()
    _origBuildUI()
    task.delay(0.5, function()
        for _, tog in ipairs(enableToggles) do
            pcall(function() if tog and tog.Set then tog:Set(false) end end)
        end
    end)
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

    -- Reset impact-system state tied to the old character
    _trailEmitter   = nil
    _wasGrounded    = false
    _phaseCooldown  = {}

    -- Re-apply collision group so debris/FX never push the player
    applyPlayerGroup(char)
    Stages.lastPos = nil
end)

-- Apply collision group to existing character at script load
if LocalPlayer.Character then applyPlayerGroup(LocalPlayer.Character) end

-- ============================================================
--  LAUNCH
-- ============================================================
buildUI()

Rayfield:Notify({
    Title   = "FlyScript v3 Ready",
    Content = "F = Float  |  G = Fly  |  X = Boost  |  V = Look-Around  |  H = Auto-Pilot\nAim crosshair to steer  â€¢  Emote anims loaded",
    Duration = 7,
})
