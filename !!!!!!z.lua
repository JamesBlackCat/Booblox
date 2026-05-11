--[[
╔═══════════════════════════════════════════════════════════════════════╗
║  AnimationStudio.lua  v5.0  —  Exploit / Executor Script             ║
║  Paste and execute in Synapse X, KRNL, or any compatible executor.   ║
╠═══════════════════════════════════════════════════════════════════════╣
║  PIPELINE                                                             ║
║  Parse → Detect Link → Extract ID → Detect Category                  ║
║  → Compatibility Switch → Convert → Validate Load → Apply            ║
║                                                                       ║
║  PLAYBACK                                                             ║
║  • Animation.Priority set on object BEFORE LoadAnimation()            ║
║  • All Animate tracks purged before controller starts                 ║
║  • AnimationTrack references held to prevent GC                       ║
║  • R6 / R15 auto-detected; correct default IDs per rig               ║
║  • Idle2 auto-timer 40 s / 15 s; dynamic speed scaling               ║
╚═══════════════════════════════════════════════════════════════════════╝
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
SavedAnims         = {}
local Packs        = {}
local Emotes       = {}
local UndoStack    = {}
local RedoStack    = {}
local ValidatedIds = {}   -- slot -> id confirmed live by pipeline

-- =====================================================================
-- SLOT DEFINITIONS
-- =====================================================================
local SLOT_NAMES = {"Idle","Walk","Run","Jump","Fall","Swim","Float","Climb","Sit","Idle2"}

-- Priority per slot — set on Animation OBJECT before LoadAnimation()
local SLOT_PRIORITY = {
    Idle  = Enum.AnimationPriority.Idle,
    Walk  = Enum.AnimationPriority.Movement,
    Run   = Enum.AnimationPriority.Movement,
    Jump  = Enum.AnimationPriority.Action,
    Fall  = Enum.AnimationPriority.Action,
    Swim  = Enum.AnimationPriority.Movement,
    Float = Enum.AnimationPriority.Movement,
    Climb = Enum.AnimationPriority.Movement,
    Sit   = Enum.AnimationPriority.Action,
    Idle2 = Enum.AnimationPriority.Action,
}

-- R15 official Roblox defaults
local DEFAULT_R15 = {
    Idle  = "507766388",  Walk  = "507777826",  Run   = "507767714",
    Jump  = "507765000",  Fall  = "507767968",  Swim  = "507784897",
    Float = "507770453",  Climb = "507765644",  Sit   = "2506281703",
    Idle2 = "",
}
-- R6 official Roblox defaults
local DEFAULT_R6 = {
    Idle  = "180435571",  Walk  = "180426354",  Run   = "180426354",
    Jump  = "125750702",  Fall  = "180436148",  Swim  = "180436334",
    Float = "180436334",  Climb = "180436334",  Sit   = "178130996",
    Idle2 = "",
}

local DEFAULT_IDS  = DEFAULT_R15   -- swapped on char init
local LOOPED       = {Idle=true,Walk=true,Run=true,Swim=true,Float=true,Climb=true,Sit=true,Idle2=true}
local SPEED_SCALED = {Walk=true,Run=true,Swim=true}

for _, s in ipairs(SLOT_NAMES) do SavedAnims[s] = "" end

-- =====================================================================
-- PLAYBACK SETTINGS
-- =====================================================================
local PlaybackMode = "Dynamic"
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
    local a = table.remove(UndoStack); table.insert(RedoStack, a)
    if a.undo then pcall(a.undo) end
end
local function doRedo()
    if #RedoStack == 0 then return end
    local a = table.remove(RedoStack); table.insert(UndoStack, a)
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
-- ╔══════════════════════════════════════════════════════════════════╗
-- ║   ASSET DETECTION & COMPATIBILITY PIPELINE                      ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
--  Step 1  Parse Input             → strip / trim raw string
--  Step 2  Detect Link Type        → URL kind, rbxassetid, numeric
--  Step 3  Extract Candidate ID    → single numeric string
--  Step 4  Detect Asset Category   → Animation/Emote/Catalog/Pack/…
--  Step 5  Compatibility Switch    → Playable / Attempt / Blocked / Reject
--  Step 6  Convert to AnimId       → "rbxassetid://XXXXXXX"
--  Step 7  Live Validation Load    → Animator:LoadAnimation() test
--  Step 8  Apply Resolved ID       → stored in SavedAnims, controller reloads
-- =====================================================================

local LINK_DISPLAY = {
    LIBRARY   = "Library Link",
    CATALOG   = "Catalog Link",
    CREATE    = "Create Store Link",
    ANIMATION = "Animation Link",
    RBXASSET  = "rbxassetid://",
    NUMERIC   = "Numeric ID",
    MULTI_ID  = "Multiple IDs  (Pack?)",
    INVALID   = "Unrecognised format",
}
local CAT_DISPLAY = {
    ANIMATION = "Animation",
    EMOTE     = "Emote  (resolves → Animation)",
    CATALOG   = "Catalog Item",
    MODEL     = "Model",
    PACK      = "Animation Pack",
    INVALID   = "Invalid Asset",
    UNKNOWN   = "Unknown",
}

-- Step 1+2 — Parse and detect link format
local function detectLinkType(s)
    if s:find("create%.roblox%.com/store/asset") then return "CREATE"    end
    if s:find("roblox%.com/catalog")              then return "CATALOG"   end
    if s:find("roblox%.com/library")              then return "LIBRARY"   end
    if s:find("roblox%.com/animation")            then return "ANIMATION" end
    if s:find("rbxassetid://")                    then return "RBXASSET"  end
    if s:match("^%s*%d+%s*$")                     then return "NUMERIC"   end
    local n = 0
    for _ in s:gmatch("%d%d%d%d%d+") do n += 1 end
    if n >= 2 then return "MULTI_ID" end
    return "INVALID"
end

-- Step 3 — Extract numeric asset ID
local function extractId(s)
    if not s or s == "" then return nil end
    s = tostring(s):match("^%s*(.-)%s*$")
    return s:match("rbxassetid://(%d+)")
        or s:match("roblox%.com/[^/]+/(%d+)")
        or s:match("create%.roblox%.com/store/asset/(%d+)")
        or (s:match("^%d+$") and s)
        or nil
end

-- Step 4 — Classify asset category
local function classifyCategory(raw, linkType)
    local low = raw:lower()
    if linkType == "MULTI_ID"  then return "PACK"    end
    if linkType == "INVALID"   then return "INVALID" end
    if low:find("pack") or low:find("bundle") or low:find("collection") then return "PACK" end
    if linkType == "CATALOG"   then return "CATALOG" end
    if low:find("emote") or low:find("dance") or low:find("wave")
    or low:find("cheer") or low:find("taunt") or low:find("celebrate") then
        return "EMOTE"
    end
    if linkType == "LIBRARY" or linkType == "CREATE"
    or linkType == "ANIMATION" or linkType == "RBXASSET"
    or linkType == "NUMERIC" then
        return "ANIMATION"
    end
    return "UNKNOWN"
end

-- Step 5 — Compatibility switch
local function compatSwitch(category)
    -- PLAYABLE  → attempt as-is
    -- ATTEMPT   → try but may fail (catalog items often aren't animations)
    -- BLOCKED   → refuse immediately (packs)
    -- REJECTED  → refuse immediately (invalid)
    if category == "ANIMATION" or category == "EMOTE" or category == "UNKNOWN" then
        return "PLAYABLE"
    elseif category == "CATALOG" then
        return "ATTEMPT"
    elseif category == "PACK" then
        return "BLOCKED"
    else
        return "REJECTED"
    end
end

--[[
    runPipeline(rawInput, slot, onStep, onComplete)

    onStep(stepNum, stepName, resultText, ok)
        — called synchronously at each stage, ok=nil means in-progress
    onComplete(success, resolvedId, category, errorMessage)
        — called once at the end; if success=false, resolvedId is nil
]]
local function runPipeline(rawInput, slot, onStep, onComplete)
    local function S(n, name, result, ok)
        if onStep then onStep(n, name, tostring(result or ""), ok) end
        task.wait(0.06)   -- brief pause so the UI can render each step
    end

    -- ── Step 1: Parse ────────────────────────────────────────────────
    local raw = rawInput and rawInput:match("^%s*(.-)%s*$") or ""
    S(1, "Parse Input", raw == "" and "(empty)" or raw:sub(1, 55), raw ~= "")
    if raw == "" then
        return onComplete(false, nil, "INVALID",
            "Input is empty. Paste an animation ID, rbxassetid://, or a Roblox URL.")
    end

    -- ── Step 2: Detect link type ─────────────────────────────────────
    local linkType = detectLinkType(raw)
    S(2, "Detect Link Type", LINK_DISPLAY[linkType] or linkType, linkType ~= "INVALID")

    -- ── Step 3: Extract candidate ID ─────────────────────────────────
    local candidateId = extractId(raw)
    S(3, "Extract Asset ID", candidateId or "NOT FOUND — no numeric ID in input", candidateId ~= nil)
    if not candidateId then
        return onComplete(false, nil, "INVALID",
            "Could not extract a numeric Asset ID from your input.\n\n"..
            "Accepted formats:\n"..
            "• Numeric ID:       507766388\n"..
            "• rbxassetid://:   rbxassetid://507766388\n"..
            "• Library URL:     roblox.com/library/507766388\n"..
            "• Create URL:      create.roblox.com/store/asset/507766388")
    end

    -- ── Step 4: Classify category ────────────────────────────────────
    local category = classifyCategory(raw, linkType)
    S(4, "Detect Asset Category",
        (CAT_DISPLAY[category] or category) ..
        (category == "EMOTE" and " → will load as Animation" or ""),
        category ~= "INVALID" and category ~= "PACK")

    -- ── Step 5: Compatibility switch ─────────────────────────────────
    local compat = compatSwitch(category)
    local compatDesc = {
        PLAYABLE = "Playable — proceeding to load test",
        ATTEMPT  = "Catalog item — will attempt animation load (may not be an animation)",
        BLOCKED  = "BLOCKED — Animation Pack detected",
        REJECTED = "REJECTED — asset type is not supported",
    }
    S(5, "Compatibility Switch", compatDesc[compat] or compat,
        compat == "PLAYABLE" or compat == "ATTEMPT")

    if compat == "BLOCKED" then
        return onComplete(false, nil, "PACK",
            "⚠  Animation Pack Detected\n\n"..
            "This asset appears to be a full animation pack containing multiple animations.\n"..
            "Animation packs cannot be imported as a single slot.\n\n"..
            "To use this pack: open the individual animation URLs from the pack page\n"..
            "and import each one into its corresponding slot (Idle, Walk, Run, etc.).")
    end
    if compat == "REJECTED" then
        return onComplete(false, nil, "INVALID",
            "This asset type is not supported by the animation system.\n"..
            "Only Animation assets can be imported.")
    end

    -- ── Step 6: Convert to final AnimationId string ──────────────────
    local finalAnimId = "rbxassetid://" .. candidateId
    S(6, "Convert Format", finalAnimId, true)

    -- ── Step 7: Live validation — attempt Animator:LoadAnimation() ───
    -- This is the ONLY way to confirm whether the asset is a real
    -- Roblox Animation. The Animator will error on any other asset type.
    local ctrl = _G.AnimStudioCtrl
    local animator = ctrl and ctrl.Animator
    if not animator then
        S(7, "Live Validation Load", "SKIPPED — no Animator (character not loaded yet)", false)
        -- Accept the ID anyway; it will be validated when character loads
        S(8, "Apply to Slot → " .. slot, candidateId .. " (pending character load)", true)
        return onComplete(true, candidateId, category,
            "⚠  Saved without live validation — character Animator not ready.\n"..
            "Animation will be validated and applied on next spawn.")
    end

    -- Build Animation object with correct priority BEFORE loading
    local testAnim = Instance.new("Animation")
    testAnim.AnimationId = finalAnimId
    -- Set priority on the object — this propagates to the loaded track
    pcall(function()
        testAnim.Priority = SLOT_PRIORITY[slot] or Enum.AnimationPriority.Movement
    end)

    local loadOk, testTrack = pcall(function()
        return animator:LoadAnimation(testAnim)
    end)

    -- Immediately stop and destroy the test track — we only needed to confirm validity
    if loadOk and testTrack then
        pcall(function() testTrack:Stop(0) end)
        -- Give the engine one frame to release the test track cleanly
        task.wait(0.05)
    end

    if not loadOk or not testTrack then
        local reason = ""
        if category == "CATALOG" then
            reason = "\nCatalog items are typically clothing, accessories, or bundles — not animations."
        elseif category == "EMOTE" then
            reason = "\nThis emote link may point to a bundle rather than a bare animation ID."
        end
        S(7, "Live Validation Load",
            "FAILED — Roblox Animator rejected this asset" .. reason, false)
        return onComplete(false, nil, category,
            "❌  Animation Load Failed\n\n"..
            "The Roblox Animator rejected asset ID " .. candidateId .. "." .. reason .. "\n\n"..
            "Possible reasons:\n"..
            "• The ID belongs to a non-Animation asset (model, gear, clothing)\n"..
            "• The animation is private or has been deleted\n"..
            "• The game's HTTP policy blocks this animation")
    end

    S(7, "Live Validation Load", "✓  Valid Roblox Animation asset confirmed", true)

    -- ── Step 8: Apply ────────────────────────────────────────────────
    S(8, "Apply to Slot → " .. slot, candidateId, true)
    return onComplete(true, candidateId, category, nil)
end

-- =====================================================================
-- ╔══════════════════════════════════════════════════════════════════╗
-- ║   ANIMATION CONTROLLER  v5.0                                    ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
--  KEY FACTS ABOUT ROBLOX ANIMATION PRIORITY (fixes stiff bug):
--
--  • AnimationTrack.Priority is READ-ONLY after LoadAnimation()
--  • The only way to set priority is on the Animation OBJECT
--    BEFORE calling Animator:LoadAnimation()
--  • After Animate is disabled all its internal tracks must be
--    explicitly Stopped — not just the Animator's GetPlayingTracks()
--  • A track that has never been played will NOT animate joints
--    even if IsPlaying returns false — always call :Play()
-- =====================================================================
local AC         = {}
AC.Animator      = nil
AC.Hum           = nil
AC.HRP           = nil
AC.AnimScript    = nil
AC.RigType       = "R15"
AC.Tracks        = {}      -- slot -> AnimationTrack (strong reference)
AC.CurrentSlot   = nil
AC.Connections   = {}
AC.Idle2Spawned  = false

-- Resolve which ID to use for a given slot (custom > default)
local function acId(slot)
    local id = SavedAnims[slot]
    if not id or id == "" then id = DEFAULT_IDS[slot] end
    return (id and id ~= "") and id or nil
end

-- Build an Animation object with priority pre-set for this slot
local function makeAnimObj(slot, id)
    local a = Instance.new("Animation")
    a.AnimationId = "rbxassetid://" .. id
    pcall(function()
        a.Priority = SLOT_PRIORITY[slot] or Enum.AnimationPriority.Movement
    end)
    return a
end

-- Load (or reload) one slot's track, discarding the old one safely
function AC:_loadTrack(slot)
    -- Stop and release old track
    local old = self.Tracks[slot]
    if old then
        pcall(function() old:Stop(0) end)
        self.Tracks[slot] = nil
    end

    local id = acId(slot)
    if not id then return end
    if not self.Animator then return end

    local anim = makeAnimObj(slot, id)
    local ok, track = pcall(function() return self.Animator:LoadAnimation(anim) end)
    if ok and track then
        -- Looped must be set before first play; re-set here just in case
        track.Looped = LOOPED[slot] == true
        self.Tracks[slot] = track   -- strong reference prevents GC
    end
end

-- Load every slot
function AC:LoadAll()
    for _, slot in ipairs(SLOT_NAMES) do
        self:_loadTrack(slot)
    end
end

-- Play a slot with fade-in; fade out the previously active slot
function AC:Play(slot, fade)
    if slot == "Idle2" and not acId("Idle2") then return end
    fade = fade or 0.2

    local prevSlot = self.CurrentSlot

    -- If same slot and it's already playing, nothing to do
    if prevSlot == slot then
        local t = self.Tracks[slot]
        if t and t.IsPlaying then return end
    end

    -- Fade out the previous slot
    if prevSlot and prevSlot ~= slot then
        local ot = self.Tracks[prevSlot]
        if ot then pcall(function() ot:Stop(fade) end) end
    end

    -- Lazily load if track is missing
    if not self.Tracks[slot] then
        self:_loadTrack(slot)
    end

    local track = self.Tracks[slot]
    if not track then return end   -- no ID available

    -- Ensure looped flag is set before playing
    track.Looped = LOOPED[slot] == true
    pcall(function() track:Play(fade) end)
    self.CurrentSlot = slot
end

-- Stop all tracks cleanly
function AC:StopAll()
    for _, tr in pairs(self.Tracks) do
        pcall(function() tr:Stop(0) end)
    end
    self.CurrentSlot = nil
end

-- Hot-reload one slot: replaces its track and restarts if it was active
function AC:Reload(slot)
    local wasPlaying = (self.CurrentSlot == slot)
    local wasSlot    = self.CurrentSlot
    if wasPlaying then
        -- Temporarily unset so Play() doesn't think it's already running
        self.CurrentSlot = nil
    end
    self:_loadTrack(slot)
    if wasPlaying then
        self:Play(slot, 0.15)
    end
end

-- Determine which slot should be active given humanoid state + speed
local function stateToSlot(hs, spd, ws)
    if hs == Enum.HumanoidStateType.Jumping  then return "Jump"  end
    if hs == Enum.HumanoidStateType.Freefall then return "Fall"  end
    if hs == Enum.HumanoidStateType.Climbing then return "Climb" end
    if hs == Enum.HumanoidStateType.Seated   then return "Sit"   end
    if hs == Enum.HumanoidStateType.Swimming then
        return (spd and spd < 0.5) and "Float" or "Swim"
    end
    if hs == Enum.HumanoidStateType.Running
    or hs == Enum.HumanoidStateType.RunningNoPhysics then
        if spd and spd > 0.5 then
            return (spd >= (ws or 8) * 0.75) and "Run" or "Walk"
        end
        return "Idle"
    end
    if hs == Enum.HumanoidStateType.Landed
    or hs == Enum.HumanoidStateType.Standing then return "Idle" end
    return nil
end

function AC:StartStateMachine()
    local hum = self.Hum
    local hrp = self.HRP
    if not hum then return end

    -- Idle2 auto-timer (runs in its own thread for the lifetime of this character)
    if not self.Idle2Spawned then
        self.Idle2Spawned = true
        task.spawn(function()
            while hum and hum.Parent do
                task.wait(40)
                -- Only trigger when idle and Idle2 has an ID
                if self.CurrentSlot == "Idle" and acId("Idle2") then
                    self:Play("Idle2", 0.5)
                    task.wait(15)
                    if self.CurrentSlot == "Idle2" then
                        self:Play("Idle", 0.5)
                    end
                end
            end
        end)
    end

    -- State machine: respond to HumanoidState changes
    local function getSpeed()
        if not hrp then return 0 end
        local v = hrp.Velocity
        return Vector3.new(v.X, 0, v.Z).Magnitude
    end

    local scConn = hum.StateChanged:Connect(function(_, newState)
        local spd  = getSpeed()
        local slot = stateToSlot(newState, spd, hum.WalkSpeed)
        -- Interrupt Idle2 if player leaves idle state
        if self.CurrentSlot == "Idle2" and slot ~= "Idle" and slot ~= nil then
            self:Play(slot, 0.2)
            return
        end
        if slot then self:Play(slot, 0.2) end
    end)
    table.insert(self.Connections, scConn)

    -- Heartbeat: Walk/Run split refinement + dynamic speed scaling
    local hbConn = RunService.Heartbeat:Connect(function()
        if not self.Hum or not self.HRP then return end

        local vel  = self.HRP.Velocity
        local spd  = Vector3.new(vel.X, 0, vel.Z).Magnitude
        local ws   = math.max(self.Hum.WalkSpeed, 1)
        local hs   = self.Hum:GetState()
        local slot = self.CurrentSlot

        -- Ground movement — handle Walk / Run split with hysteresis
        if hs == Enum.HumanoidStateType.Running
        or hs == Enum.HumanoidStateType.RunningNoPhysics then
            if slot == "Idle2" and spd > 0.5 then
                -- Interrupt Idle2 if player starts moving
                self:Play("Walk", 0.18)
            elseif spd > ws * 0.75 and slot ~= "Run" then
                self:Play("Run", 0.18)
            elseif spd > 0.5 and spd <= ws * 0.75 and slot ~= "Walk" and slot ~= "Run" then
                self:Play("Walk", 0.18)
            elseif spd <= 0.5 and (slot == "Walk" or slot == "Run") then
                self:Play("Idle", 0.25)
            end
        end

        -- Dynamic speed scaling on movement tracks
        if slot and SPEED_SCALED[slot] then
            local track = self.Tracks[slot]
            if track and track.IsPlaying then
                local ratio
                if PlaybackMode == "Dynamic" then
                    ratio = math.clamp(spd / ws, 0.2, 3.0) * PlaybackMult
                else
                    ratio = math.max(PlaybackMult, 0.01)
                end
                pcall(function() track:AdjustSpeed(ratio) end)
            end
        end
    end)
    table.insert(self.Connections, hbConn)
end

function AC:Init(char)
    -- ── 1. Tear down previous connections and tracks ─────────────────
    for _, c in ipairs(self.Connections) do
        pcall(function() c:Disconnect() end)
    end
    self.Connections  = {}
    self.Idle2Spawned = false
    self:StopAll()
    self.Tracks      = {}
    self.CurrentSlot = nil

    -- ── 2. Locate character components ───────────────────────────────
    self.Hum       = char:WaitForChild("Humanoid", 10)
    self.HRP       = char:WaitForChild("HumanoidRootPart", 10)
    self.AnimScript = char:FindFirstChild("Animate")

    if not self.Hum then
        warn("[AnimStudio] Humanoid not found — controller not started")
        return
    end

    -- ── 3. Detect rig type and set correct default IDs ───────────────
    if self.Hum.RigType == Enum.HumanoidRigType.R6 then
        self.RigType = "R6"
        DEFAULT_IDS  = DEFAULT_R6
    else
        self.RigType = "R15"
        DEFAULT_IDS  = DEFAULT_R15
    end

    -- ── 4. Disable Roblox's Animate LocalScript ───────────────────────
    -- We disable BEFORE touching the Animator so Animate's own tracks
    -- do not restart while we are clearing them.
    if self.AnimScript then
        pcall(function() self.AnimScript.Disabled = true end)
    end
    -- Wait one frame — this lets Animate's heartbeat / loop finish
    -- and stops it queuing any more Track:Play() calls.
    task.wait(0.05)

    -- ── 5. Locate or create Animator ─────────────────────────────────
    self.Animator = self.Hum:FindFirstChildOfClass("Animator")
    if not self.Animator then
        self.Animator = Instance.new("Animator")
        self.Animator.Parent = self.Hum
    end

    -- ── 6. Purge every track the Animator is currently running ────────
    -- This is the critical step that prevents the "stiff T-pose" bug.
    -- Animate's tracks are internal; GetPlayingAnimationTracks() returns
    -- all of them regardless of origin.
    local purgeAttempts = 0
    repeat
        local playing = self.Animator:GetPlayingAnimationTracks()
        for _, tr in ipairs(playing) do
            pcall(function() tr:Stop(0) end)
        end
        task.wait(0.04)
        purgeAttempts += 1
    until #self.Animator:GetPlayingAnimationTracks() == 0 or purgeAttempts >= 5

    -- ── 7. Load all tracks with correct priorities ────────────────────
    self:LoadAll()

    -- ── 8. Start state machine ────────────────────────────────────────
    self:StartStateMachine()

    -- ── 9. Play initial Idle ──────────────────────────────────────────
    -- Slight delay so the first Heartbeat can sync character speed info
    task.delay(0.1, function()
        if self.Hum and self.Hum.Parent then
            self:Play("Idle", 0.3)
        end
    end)
end

function AC:Destroy()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    self:StopAll()
    -- Re-enable Animate so the character behaves normally after script removal
    if self.AnimScript then
        pcall(function() self.AnimScript.Disabled = false end)
    end
end

_G.AnimStudioCtrl = AC

-- =====================================================================
-- applyAnim  — called by UI after pipeline has confirmed a valid ID
-- =====================================================================
function applyAnim(slot, id)
    SavedAnims[slot] = id or ""
    if AC.Animator then AC:Reload(slot) end
end

-- =====================================================================
-- CHARACTER BINDING
-- =====================================================================
local function bindChar(char)
    task.wait(0.5)   -- give the character a moment to fully assemble
    AC:Init(char)
    -- Re-apply any IDs that were imported before this spawn
    for slot, id in pairs(SavedAnims) do
        if id and id ~= "" then AC:Reload(slot) end
    end
end

task.spawn(function() bindChar(LP.Character or LP.CharacterAdded:Wait()) end)
LP.CharacterAdded:Connect(function(c) task.spawn(function() bindChar(c) end) end)
LP.CharacterRemoving:Connect(function() AC:Destroy() end)

-- =====================================================================
-- THEME
-- =====================================================================
local T = {
    Bg      = Color3.fromRGB(11, 11, 17),
    Surface = Color3.fromRGB(19, 19, 29),
    Card    = Color3.fromRGB(26, 26, 40),
    Border  = Color3.fromRGB(50, 50, 72),
    Accent  = Color3.fromRGB(99, 102, 241),
    AccHov  = Color3.fromRGB(128, 132, 255),
    AccDark = Color3.fromRGB(65, 68, 190),
    OK      = Color3.fromRGB(34, 197, 94),
    Warn    = Color3.fromRGB(234, 179, 8),
    Bad     = Color3.fromRGB(239, 68, 68),
    Info    = Color3.fromRGB(56, 189, 248),
    Text    = Color3.fromRGB(230, 230, 252),
    Sub     = Color3.fromRGB(148, 148, 178),
    Muted   = Color3.fromRGB(82, 82, 112),
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
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p
end
local function mkStroke(p, col, th)
    local s = Instance.new("UIStroke"); s.Color = col or T.Border; s.Thickness = th or 1; s.Parent = p; return s
end
local function mkPad(p, t, r, b, l)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 8); u.PaddingRight  = UDim.new(0, r or 8)
    u.PaddingBottom = UDim.new(0, b or 8); u.PaddingLeft   = UDim.new(0, l or 8); u.Parent = p
end
local function mkFrame(par, sz, pos, col, name)
    local f = Instance.new("Frame"); f.Size = sz or UDim2.new(1,0,1,0)
    f.Position = pos or UDim2.new(0,0,0,0); f.BackgroundColor3 = col or T.Surface
    f.BorderSizePixel = 0; if name then f.Name = name end; f.Parent = par; return f
end
local function mkLabel(par, txt, sz, pos, col, fs, name)
    local l = Instance.new("TextLabel"); l.Size = sz or UDim2.new(1,0,0,22)
    l.Position = pos or UDim2.new(0,0,0,0); l.BackgroundTransparency = 1
    l.TextColor3 = col or T.Text; l.TextSize = fs or 14; l.Font = Enum.Font.GothamMedium
    l.Text = txt or ""; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextWrapped = true
    if name then l.Name = name end; l.Parent = par; return l
end
local function mkBtn(par, txt, sz, pos, col, name)
    local b = Instance.new("TextButton"); b.Size = sz or UDim2.new(1,0,0,36)
    b.Position = pos or UDim2.new(0,0,0,0); b.BackgroundColor3 = col or T.Accent
    b.TextColor3 = T.Text; b.TextSize = 13; b.Font = Enum.Font.GothamBold
    b.Text = txt or "Button"; b.BorderSizePixel = 0; b.AutoButtonColor = false
    if name then b.Name = name end; mkCorner(b, 8)
    local orig = col or T.Accent
    b.MouseEnter:Connect(function() tw(b, {BackgroundColor3 = T.AccHov}, 0.1) end)
    b.MouseLeave:Connect(function() tw(b, {BackgroundColor3 = orig},     0.1) end)
    b.Parent = par; return b
end
local function mkBox(par, ph, sz, pos, name)
    local t = Instance.new("TextBox"); t.Size = sz or UDim2.new(1,0,0,36)
    t.Position = pos or UDim2.new(0,0,0,0); t.BackgroundColor3 = T.Card
    t.TextColor3 = T.Text; t.PlaceholderColor3 = T.Muted; t.PlaceholderText = ph or ""
    t.TextSize = 13; t.Font = Enum.Font.Gotham; t.Text = ""; t.BorderSizePixel = 0
    t.ClearTextOnFocus = false; if name then t.Name = name end
    mkCorner(t, 8); mkStroke(t, T.Border, 1); mkPad(t, 0, 10, 0, 10); t.Parent = par; return t
end

-- ScrollingFrame with mouse + touch drag + momentum
local function mkScroll(par, sz, pos, name)
    local s = Instance.new("ScrollingFrame")
    s.Size = sz or UDim2.new(1,0,1,0); s.Position = pos or UDim2.new(0,0,0,0)
    s.BackgroundTransparency = 1; s.BorderSizePixel = 0; s.ScrollBarThickness = 5
    s.ScrollBarImageColor3 = T.Accent; s.CanvasSize = UDim2.new(0,0,0,0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y; s.ScrollingEnabled = true
    if name then s.Name = name end; s.Parent = par
    local dragging, startY, startCanvas, vel, lt, lastDelta = false, 0, 0, 0, 0, 0
    s.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; startY = inp.Position.Y; startCanvas = s.CanvasPosition.Y
            vel = 0; lt = tick(); lastDelta = 0
        end
    end)
    s.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local now = tick(); local dt = now - lt
            if dt > 0 then vel = (inp.Position.Y - (startY - lastDelta)) / dt end
            lastDelta = startY - inp.Position.Y; lt = now
            local maxY = math.max(0, s.CanvasSize.Y.Offset - s.AbsoluteSize.Y)
            s.CanvasPosition = Vector2.new(0, math.clamp(startCanvas + lastDelta, 0, maxY))
        end
    end)
    local function endDrag()
        if not dragging then return end; dragging = false
        local m = -vel
        task.spawn(function()
            while math.abs(m) > 0.5 do
                task.wait(0.016); m = m * 0.86
                local maxY = math.max(0, s.CanvasSize.Y.Offset - s.AbsoluteSize.Y)
                s.CanvasPosition = Vector2.new(0, math.clamp(s.CanvasPosition.Y + m, 0, maxY))
            end
        end)
    end
    s.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then endDrag() end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then endDrag() end
    end)
    return s
end

local function mkList(par, gap)
    local l = Instance.new("UIListLayout"); l.Padding = UDim.new(0, gap or 6)
    l.FillDirection = Enum.FillDirection.Vertical; l.SortOrder = Enum.SortOrder.LayoutOrder
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center; l.Parent = par
end
local function mkGrid(par, cs, cp)
    local g = Instance.new("UIGridLayout"); g.CellSize = cs or UDim2.new(0,110,0,110)
    g.CellPaddingSize = cp or UDim2.new(0,8,0,8); g.SortOrder = Enum.SortOrder.LayoutOrder; g.Parent = par
end

-- =====================================================================
-- DRAGGABLE  (handles drag vs tap threshold)
-- =====================================================================
local DRAG_MIN = 8
local function makeDraggable(handle, target, onDragEnd)
    local active, moved, mStart, pStart = false, false, nil, nil
    local function xy(i) return Vector2.new(i.Position.X, i.Position.Y) end
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            active = true; moved = false; mStart = xy(i); pStart = target.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not active then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = xy(i) - mStart
            if not moved and d.Magnitude < DRAG_MIN then return end
            moved = true
            target.Position = UDim2.new(pStart.X.Scale, pStart.X.Offset + d.X,
                                        pStart.Y.Scale, pStart.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if not active then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            local was = moved; active = false; moved = false
            if was and onDragEnd then onDragEnd() end
        end
    end)
end

-- =====================================================================
-- SCREEN GUI
-- =====================================================================
local GUI = Instance.new("ScreenGui")
GUI.Name = "AnimStudio"; GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.IgnoreGuiInset = true; GUI.DisplayOrder = 999; GUI.Parent = PGui
_G.AnimStudioRunning = GUI

-- =====================================================================
-- NOTIFICATIONS
-- =====================================================================
local NHost = mkFrame(GUI, UDim2.new(0, 290, 0.5, 0), UDim2.new(1, -300, 0, 10), T.Bg, "Notifs")
NHost.BackgroundTransparency = 1; NHost.ZIndex = 50; mkList(NHost, 4)

local function notify(msg, kind, dur)
    dur = dur or 3.5
    local col = (kind=="success" and T.OK) or (kind=="warning" and T.Warn)
             or (kind=="error"   and T.Bad) or (kind=="info"    and T.Info) or T.Accent
    local n = mkFrame(NHost, UDim2.new(1,-6,0,50), UDim2.new(0,3,0,0), T.Card, "N")
    n.ZIndex = 51; n.LayoutOrder = tick(); mkCorner(n, 9); mkStroke(n, col, 2)
    local dot = mkLabel(n, "●", UDim2.new(0,14,1,0), UDim2.new(0,7,0,0), col, 16)
    dot.TextXAlignment = Enum.TextXAlignment.Center
    mkLabel(n, msg, UDim2.new(1,-26,1,0), UDim2.new(0,22,0,0), T.Text, 11).TextWrapped = true
    n.Position = UDim2.new(1, 10, 0, 0); tw(n, {Position = UDim2.new(0, 3, 0, 0)}, 0.26)
    task.delay(dur, function()
        tw(n, {Position = UDim2.new(1, 10, 0, 0)}, 0.2)
        task.wait(0.22); pcall(function() n:Destroy() end)
    end)
end

-- =====================================================================
-- ╔══════════════════════════════════════════════════════════════════╗
-- ║   PIPELINE DIALOG  — 8-step visual progress                     ║
-- ╚══════════════════════════════════════════════════════════════════╝
-- =====================================================================
local PIPELINE_STEP_NAMES = {
    "Parse Input",
    "Detect Link Type",
    "Extract Asset ID",
    "Detect Asset Category",
    "Compatibility Switch",
    "Convert Format",
    "Live Validation Load",
    "Apply to Slot",
}

local function showPipelineDialog(rawInput, slotName, onDone)
    -- Overlay
    local ov = mkFrame(GUI, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.new(0,0,0), "PipeOv")
    ov.BackgroundTransparency = 0.48; ov.ZIndex = 70

    -- Main dialog card
    local dlg = mkFrame(GUI, UDim2.new(0,480,0,510), UDim2.new(0.5,-240,0.5,-255), T.Surface, "PipeDlg")
    dlg.ZIndex = 71; mkCorner(dlg, 14); mkStroke(dlg, T.Border, 1)

    local function close() pcall(function() ov:Destroy(); dlg:Destroy() end) end

    -- Header
    mkPad(dlg, 16, 16, 14, 16)
    local hdr = mkLabel(dlg, "Asset Detection Pipeline", UDim2.new(1,-32,0,22), UDim2.new(0,0,0,0), T.Accent, 15)
    hdr.Font = Enum.Font.GothamBold
    mkLabel(dlg, "Slot: "..slotName.."   ·   Input: "..rawInput:sub(1,38),
        UDim2.new(1,-32,0,15), UDim2.new(0,0,0,24), T.Sub, 11)
    local clBtn = mkBtn(dlg, "✕", UDim2.new(0,28,0,28), UDim2.new(1,-32,0,2), T.Bad)
    clBtn.TextSize = 12; clBtn.MouseButton1Click:Connect(close)

    -- Step rows
    local ROW_H   = 36
    local ROW_Y0  = 44
    local stepUI  = {}   -- stepUI[i] = {frame, statusDot, resultLbl, stroke}

    for i, name in ipairs(PIPELINE_STEP_NAMES) do
        local y    = ROW_Y0 + (i - 1) * (ROW_H + 3)
        local row  = mkFrame(dlg, UDim2.new(1,0,0,ROW_H), UDim2.new(0,0,0,y), T.Card, "SR"..i)
        mkCorner(row, 7)
        local st = mkStroke(row, T.Border, 1)

        -- Step number
        local num = mkLabel(row, string.format("%d", i),
            UDim2.new(0,20,1,0), UDim2.new(0,6,0,0), T.Muted, 11)
        num.TextXAlignment = Enum.TextXAlignment.Center; num.Font = Enum.Font.GothamBold

        -- Spinner / status dot
        local dot = mkLabel(row, "○",
            UDim2.new(0,16,1,0), UDim2.new(0,28,0,0), T.Muted, 13)
        dot.TextXAlignment = Enum.TextXAlignment.Center

        -- Step name
        mkLabel(row, name,
            UDim2.new(0.38,0,1,0), UDim2.new(0,46,0,0), T.Text, 11).Font = Enum.Font.GothamSemibold

        -- Result text (right side)
        local res = mkLabel(row, "waiting…",
            UDim2.new(0.56,-8,1,0), UDim2.new(0.42,0,0,0), T.Muted, 10)
        res.TextXAlignment = Enum.TextXAlignment.Right

        stepUI[i] = {frame = row, dot = dot, result = res, stroke = st, num = num}
    end

    -- Result card at bottom
    local resY    = ROW_Y0 + #PIPELINE_STEP_NAMES * (ROW_H + 3) + 4
    local resCard = mkFrame(dlg, UDim2.new(1,0,0,50), UDim2.new(0,0,0,resY), T.Card, "RC")
    mkCorner(resCard, 10)
    local resSt   = mkStroke(resCard, T.Border, 1)
    local resLbl  = mkLabel(resCard, "Running pipeline…",
        UDim2.new(1,-16,1,0), UDim2.new(0,8,0,0), T.Muted, 12)
    resLbl.TextXAlignment  = Enum.TextXAlignment.Center
    resLbl.TextWrapped     = true

    -- Action buttons (shown only after completion)
    local btnY   = resY + 54
    local btnRow = mkFrame(dlg, UDim2.new(1,0,0,32), UDim2.new(0,0,0,btnY), T.Bg, "BR")
    btnRow.BackgroundTransparency = 1; btnRow.Visible = false
    local impBtn = mkBtn(btnRow, "✔  Import Animation",
        UDim2.new(0.58,0,1,0), UDim2.new(0,0,0,0), T.OK)
    impBtn.TextSize = 11
    local canBtn = mkBtn(btnRow, "✕  Cancel",
        UDim2.new(0.38,0,1,0), UDim2.new(0.62,0,0,0), T.Bad)
    canBtn.TextSize = 11; canBtn.MouseButton1Click:Connect(close)

    -- Track which step we're on
    local currentStep = 0

    -- onStep callback — called synchronously from runPipeline
    local function onStep(stepNum, stepName, resultText, success)
        currentStep = stepNum
        local ui = stepUI[stepNum]
        if not ui then return end
        if success == true then
            ui.dot.Text           = "✓"
            ui.dot.TextColor3     = T.OK
            ui.result.Text        = resultText
            ui.result.TextColor3  = T.OK
            ui.stroke.Color       = T.OK
            ui.frame.BackgroundColor3 = Color3.fromRGB(18, 34, 22)
        elseif success == false then
            ui.dot.Text           = "✗"
            ui.dot.TextColor3     = T.Bad
            ui.result.Text        = resultText
            ui.result.TextColor3  = T.Bad
            ui.stroke.Color       = T.Bad
            ui.frame.BackgroundColor3 = Color3.fromRGB(34, 14, 14)
        else
            -- In-progress
            ui.dot.Text           = "→"
            ui.dot.TextColor3     = T.Warn
            ui.result.Text        = resultText
            ui.result.TextColor3  = T.Warn
            ui.stroke.Color       = T.Warn
        end
    end

    -- onComplete callback
    local function onComplete(success, resolvedId, category, errMsg)
        if success then
            resLbl.Text       = "✔  Valid "..(CAT_DISPLAY[category] or category).."  ·  ID: "..tostring(resolvedId)
            resLbl.TextColor3 = T.OK; resSt.Color = T.OK
            resCard.BackgroundColor3 = Color3.fromRGB(14, 30, 18)
            btnRow.Visible = true
            impBtn.MouseButton1Click:Connect(function()
                close()
                if onDone then onDone(true, resolvedId, category) end
            end)
        else
            -- Show multi-line error inside result card
            resLbl.Text       = errMsg or "Pipeline failed."
            resLbl.TextColor3 = T.Bad; resSt.Color = T.Bad
            resCard.BackgroundColor3 = Color3.fromRGB(34, 12, 12)
            -- Expand the card for long messages
            resCard.Size = UDim2.new(1, 0, 0, 80)
            btnRow.Visible = true; impBtn.Visible = false
            canBtn.Text = "Close"; canBtn.Size = UDim2.new(1,0,1,0); canBtn.Position = UDim2.new(0,0,0,0)
        end
    end

    -- Run pipeline asynchronously so dialog renders first
    task.spawn(function()
        task.wait(0.05)   -- one frame for the dialog to fully render
        runPipeline(rawInput, slotName, onStep, onComplete)
    end)
end

-- =====================================================================
-- CONFIRM DIALOG
-- =====================================================================
local function confirmDlg(title, msg, onSave, onDiscard)
    local ov  = mkFrame(GUI,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.new(0,0,0),"Ov")
    ov.BackgroundTransparency = 0.45; ov.ZIndex = 60
    local dlg = mkFrame(GUI,UDim2.new(0,380,0,188),UDim2.new(0.5,-190,0.5,-94),T.Surface,"Dlg")
    dlg.ZIndex = 61; mkCorner(dlg,12); mkStroke(dlg,T.Border,1); mkPad(dlg,16,16,16,16)
    mkLabel(dlg,title,UDim2.new(1,0,0,26),UDim2.new(0,0,0,0),T.Accent,16).Font=Enum.Font.GothamBold
    mkLabel(dlg,msg,UDim2.new(1,0,0,40),UDim2.new(0,0,0,30),T.Text,13).TextWrapped=true
    local function cl() pcall(function() ov:Destroy() dlg:Destroy() end) end
    local row = mkFrame(dlg,UDim2.new(1,0,0,34),UDim2.new(0,0,1,-34),T.Bg); row.BackgroundTransparency=1
    local sv = mkBtn(row,"Save",   UDim2.new(0,96,1,0),UDim2.new(0,  0,0,0),T.OK)
    local di = mkBtn(row,"Discard",UDim2.new(0,96,1,0),UDim2.new(0,104,0,0),T.Bad)
    local ca = mkBtn(row,"Cancel", UDim2.new(0,96,1,0),UDim2.new(0,208,0,0),T.Card)
    sv.MouseButton1Click:Connect(function() cl(); if onSave    then pcall(onSave)    end end)
    di.MouseButton1Click:Connect(function() cl(); if onDiscard then pcall(onDiscard) end end)
    ca.MouseButton1Click:Connect(cl)
end

-- =====================================================================
-- TOGGLE BUTTON
-- =====================================================================
local Tbtn = Instance.new("TextButton")
Tbtn.Name = "StudioToggle"; Tbtn.Size = UDim2.new(0,56,0,56)
Tbtn.Position = UDim2.new(0.5,-28,0.5,-28); Tbtn.BackgroundColor3 = T.Accent
Tbtn.Text = "AS"; Tbtn.TextColor3 = Color3.new(1,1,1); Tbtn.TextSize = 12
Tbtn.Font = Enum.Font.GothamBold; Tbtn.BorderSizePixel = 0; Tbtn.AutoButtonColor = false
Tbtn.ZIndex = 100; mkCorner(Tbtn, 18); Tbtn.Parent = GUI
Tbtn.MouseEnter:Connect(function() tw(Tbtn,{BackgroundColor3=T.AccHov},0.1) end)
Tbtn.MouseLeave:Connect(function() tw(Tbtn,{BackgroundColor3=T.Accent},0.1) end)
makeDraggable(Tbtn, Tbtn, function()
    local v=vp(); local ap=Tbtn.AbsolutePosition; local as=Tbtn.AbsoluteSize
    local ny = math.clamp(ap.Y, 10, v.Y - as.Y - 10)
    if ap.X + as.X/2 < v.X/2 then tw(Tbtn,{Position=UDim2.new(0,10,0,ny)},0.18)
    else tw(Tbtn,{Position=UDim2.new(0,v.X-as.X-10,0,ny)},0.18) end
end)

-- =====================================================================
-- MAIN WINDOW
-- =====================================================================
local Win = mkFrame(GUI, UDim2.new(0.87,0,0.87,0), UDim2.new(0.065,0,0.065,0), T.Bg, "MainWin")
Win.Visible = false; Win.ZIndex = 10; mkCorner(Win,14); mkStroke(Win,T.Border,1)

local TBar = mkFrame(Win, UDim2.new(1,0,0,44), UDim2.new(0,0,0,0), T.Surface, "TBar")
mkCorner(TBar,14); mkFrame(TBar,UDim2.new(1,0,0.55,0),UDim2.new(0,0,0.45,0),T.Surface)
local TLbl = mkLabel(TBar,"  ✦ Animation Studio  v5.0",UDim2.new(1,-48,1,0),UDim2.new(0,0,0,0),T.Accent,15)
TLbl.Font = Enum.Font.GothamBold
local CloseBtn = mkBtn(TBar,"✕",UDim2.new(0,32,0,32),UDim2.new(1,-38,0,6),T.Bad)
CloseBtn.TextSize = 13; makeDraggable(TBar, Win)

local TabBar = mkFrame(Win,UDim2.new(1,0,0,38),UDim2.new(0,0,0,44),T.Surface,"TabBar")
local TABS   = {"Home","Packs","Emotes","Explorer","Editor"}
local TabBtns = {}; local tW = 1/#TABS
for i, name in ipairs(TABS) do
    local b = mkBtn(TabBar, name,
        UDim2.new(tW,-6,1,-8), UDim2.new((i-1)*tW+0.005,0,0,4), T.Card, "Tab_"..name)
    b.TextSize = 11; mkStroke(b,T.Border,1); TabBtns[name] = b
end

local Content = mkFrame(Win,UDim2.new(1,0,1,-84),UDim2.new(0,0,0,82),T.Bg,"Content")
local SBar    = mkFrame(Win,UDim2.new(1,0,0,18),UDim2.new(0,0,1,-18),T.Surface,"SBar")
local SLbl    = mkLabel(SBar,"  Ready",UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),T.Muted,11)
SLbl.TextXAlignment = Enum.TextXAlignment.Left
local function setStatus(s) SLbl.Text = "  "..s end

local Panels = {}
for _, name in ipairs(TABS) do
    local p = mkFrame(Content,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),T.Bg,"P_"..name)
    p.Visible = false; Panels[name] = p
end

local ActiveTab = "Home"
local function switchTab(name)
    ActiveTab = name
    for n, p in pairs(Panels)  do p.Visible              = (n==name) end
    for n, b in pairs(TabBtns) do b.BackgroundColor3      = (n==name) and T.Accent or T.Card end
    setStatus("Tab: "..name)
end
for _, name in ipairs(TABS) do
    TabBtns[name].MouseButton1Click:Connect(function() switchTab(name) end)
end

local UIOpen = false
local function openUI()
    UIOpen = true; Win.Visible = true; Win.BackgroundTransparency = 1
    tw(Win,{BackgroundTransparency=0},0.2); switchTab(ActiveTab)
    setStatus("v5.0 | Rig: "..(AC.RigType or "?"))
end
local function closeUI()
    UIOpen = false; tw(Win,{BackgroundTransparency=1},0.18)
    task.delay(0.22, function() if not UIOpen then Win.Visible = false end end)
end
do  -- Toggle button tap vs drag
    local bd, bm, bs = false, false, Vector2.zero
    Tbtn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            bd=true; bm=false; bs=Vector2.new(i.Position.X,i.Position.Y)
        end
    end)
    Tbtn.InputChanged:Connect(function(i)
        if not bd then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch then
            if (Vector2.new(i.Position.X,i.Position.Y)-bs).Magnitude > DRAG_MIN then bm=true end
        end
    end)
    Tbtn.InputEnded:Connect(function(i)
        if not bd then return end
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            bd = false
            if not bm then if UIOpen then closeUI() else openUI() end end
        end
    end)
end
CloseBtn.MouseButton1Click:Connect(closeUI)

-- =====================================================================
-- HOME TAB
-- =====================================================================
local HP = Panels["Home"]; mkPad(HP, 7, 7, 7, 7)

local SlotPanel = mkFrame(HP, UDim2.new(0,196,1,-2), UDim2.new(0,0,0,0), T.Surface, "SlotPanel")
mkCorner(SlotPanel,10); mkStroke(SlotPanel,T.Border,1)
mkLabel(SlotPanel,"Animation Slots",UDim2.new(1,-10,0,22),UDim2.new(0,5,0,5),T.Accent,12).Font=Enum.Font.GothamBold
local SlotScroll = mkScroll(SlotPanel,UDim2.new(1,-6,1,-32),UDim2.new(0,3,0,30))
mkList(SlotScroll,3)

local Detail = mkFrame(HP,UDim2.new(1,-204,1,-2),UDim2.new(0,200,0,0),T.Surface,"Detail")
mkCorner(Detail,10); mkStroke(Detail,T.Border,1); mkPad(Detail,11,11,10,11)

local DTitle   = mkLabel(Detail,"Select a slot →",UDim2.new(1,0,0,23),UDim2.new(0,0,0,0),T.Text,16)
DTitle.Font    = Enum.Font.GothamBold
local DStatus  = mkLabel(Detail,"",UDim2.new(1,0,0,15),UDim2.new(0,0,0,25),T.Muted,11)
local DRig     = mkLabel(Detail,"",UDim2.new(1,0,0,14),UDim2.new(0,0,0,42),T.Sub,11)
local DDefault = mkLabel(Detail,"",UDim2.new(1,0,0,14),UDim2.new(0,0,0,57),T.Muted,11)

-- Detected category badge
local CatBadge = mkFrame(Detail,UDim2.new(0,160,0,20),UDim2.new(0,0,0,75),T.Card,"CB")
mkCorner(CatBadge,6); CatBadge.Visible = false
local CatLbl   = mkLabel(CatBadge,"",UDim2.new(1,0,1,0),UDim2.new(0,6,0,0),T.Info,10)
CatLbl.TextXAlignment = Enum.TextXAlignment.Left

mkLabel(Detail,"Animation ID / rbxassetid:// / Roblox URL:",
    UDim2.new(1,0,0,13),UDim2.new(0,0,0,100),T.Sub,11)
local IdBox = mkBox(Detail,"Paste here…",UDim2.new(1,0,0,32),UDim2.new(0,0,0,114))
IdBox.TextSize = 12

-- Live hint line
local HintLbl = mkLabel(Detail,"",UDim2.new(1,0,0,14),UDim2.new(0,0,0,148),T.Muted,10)

-- Action row
local ARow = mkFrame(Detail,UDim2.new(1,0,0,28),UDim2.new(0,0,0,166),T.Bg)
ARow.BackgroundTransparency = 1
local ImpBtn = mkBtn(ARow,"⬇  Import via Pipeline",UDim2.new(0.53,-3,1,0),UDim2.new(0,0,0,0),T.OK)
ImpBtn.TextSize = 10
local PrvBtn = mkBtn(ARow,"▶  Preview",UDim2.new(0.23,-2,1,0),UDim2.new(0.55,3,0,0),T.Accent)
PrvBtn.TextSize = 10
local RstBtn = mkBtn(ARow,"↺  Reset",  UDim2.new(0.20,-2,1,0),UDim2.new(0.79,3,0,0),T.Bad)
RstBtn.TextSize = 10

-- Playback mode / speed row
local PbRow = mkFrame(Detail,UDim2.new(1,0,0,46),UDim2.new(0,0,0,200),T.Card)
mkCorner(PbRow,8); mkStroke(PbRow,T.Border,1); mkPad(PbRow,5,8,5,8)
mkLabel(PbRow,"Playback Mode:",UDim2.new(0.42,0,0.5,0),UDim2.new(0,0,0,0),T.Sub,10)
local PbModeBtn=mkBtn(PbRow,"Mode: Dynamic",UDim2.new(0.54,0,0,22),UDim2.new(0.44,0,0,2),T.Card)
PbModeBtn.TextSize=9
mkLabel(PbRow,"Speed Mult:",UDim2.new(0.38,0,0.5,0),UDim2.new(0,0,0.5,0),T.Sub,10)
local SpeedBox=mkBox(PbRow,"1.0",UDim2.new(0.28,0,0,20),UDim2.new(0.56,0,0.52,3))
SpeedBox.Text="1.0"; SpeedBox.TextSize=11

-- Idle2 banner
local I2Banner = mkFrame(Detail,UDim2.new(1,0,0,30),UDim2.new(0,0,0,252),T.Card,"I2B")
mkCorner(I2Banner,8); mkStroke(I2Banner,T.Warn,1); I2Banner.Visible=false
mkLabel(I2Banner,"  ★ Idle 2 — auto-plays every 40 s for 15 s, then returns to Idle.",
    UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),T.Warn,10).TextWrapped=true

-- Slot buttons
local SelectedSlot   = "Idle"
local SlotBtns       = {}
local SlotCategories = {}   -- last pipeline-confirmed category per slot

local function refreshDetail()
    local slot   = SelectedSlot
    local custom = SavedAnims[slot]
    DTitle.Text   = (slot=="Idle2") and "Idle 2 Animation" or slot.." Animation"
    DRig.Text     = "Rig: "..(AC.RigType or "?").."  |  Priority: "..(SLOT_PRIORITY[slot] and tostring(SLOT_PRIORITY[slot]):match("%.(.+)") or "?")
    DDefault.Text = "Default: "..(DEFAULT_IDS[slot] ~= "" and DEFAULT_IDS[slot] or "none (user-defined)")
    I2Banner.Visible = (slot == "Idle2")
    if custom ~= "" then
        DStatus.Text       = "✔  Custom active  — "..custom
        DStatus.TextColor3 = T.OK; IdBox.Text = custom
    elseif slot == "Idle2" then
        DStatus.Text       = "No Idle 2 set — paste an animation ID below"
        DStatus.TextColor3 = T.Warn; IdBox.Text = ""
    else
        DStatus.Text       = "Using Roblox default"; DStatus.TextColor3 = T.Muted; IdBox.Text = ""
    end
    local cat = SlotCategories[slot]
    if cat then
        CatBadge.Visible = true
        CatLbl.Text = "Detected: "..(CAT_DISPLAY[cat] or cat)
    else CatBadge.Visible = false end
    PbModeBtn.Text = "Mode: "..PlaybackMode
end

for i, slot in ipairs(SLOT_NAMES) do
    local label = (slot=="Idle2") and "Idle 2  ★" or slot
    local b = mkBtn(SlotScroll, label,
        UDim2.new(1,-6,0,33), UDim2.new(0,3,0,0), T.Card, "S_"..slot)
    b.TextXAlignment = Enum.TextXAlignment.Left; b.LayoutOrder = i
    b.TextSize = 12; mkPad(b,0,0,0,10); SlotBtns[slot] = b
    b.MouseButton1Click:Connect(function()
        if SlotBtns[SelectedSlot] then SlotBtns[SelectedSlot].BackgroundColor3 = T.Card end
        SelectedSlot = slot; b.BackgroundColor3 = T.AccDark; refreshDetail()
    end)
end

-- Live input hint
IdBox:GetPropertyChangedSignal("Text"):Connect(function()
    local raw = IdBox.Text
    if raw == "" then HintLbl.Text = ""; return end
    local lt  = detectLinkType(raw)
    local id  = extractId(raw)
    local cat = id and classifyCategory(raw, lt) or "INVALID"
    HintLbl.Text = "→ "..(LINK_DISPLAY[lt] or lt).."  |  Category: "..(CAT_DISPLAY[cat] or cat)
    HintLbl.TextColor3 = (cat=="INVALID" or cat=="PACK") and T.Bad
        or cat=="CATALOG" and T.Warn or T.OK
end)

ImpBtn.MouseButton1Click:Connect(function()
    local raw = IdBox.Text
    if raw == "" then notify("Paste an ID or link first.","warning") return end
    local slot = SelectedSlot
    local old  = SavedAnims[slot]
    showPipelineDialog(raw, slot, function(ok, id, category)
        if ok then
            SlotCategories[slot] = category
            applyAnim(slot, id)
            pushUndo({
                undo = function() applyAnim(slot,old); SlotCategories[slot]=nil; refreshDetail() end,
                redo = function() applyAnim(slot,id);  SlotCategories[slot]=category; refreshDetail() end,
            })
            refreshDetail()
            notify("Imported "..slot.." · "..(CAT_DISPLAY[category] or category).." · "..id,"success",5)
        end
    end)
end)

PrvBtn.MouseButton1Click:Connect(function()
    local id = SavedAnims[SelectedSlot]
    if id=="" then id=DEFAULT_IDS[SelectedSlot] end
    if not id or id=="" then notify("No animation to preview.","warning") return end
    if not AC.Animator then notify("Character not ready.","error") return end
    local a = Instance.new("Animation"); a.AnimationId = "rbxassetid://"..id
    pcall(function() a.Priority = SLOT_PRIORITY[SelectedSlot] or Enum.AnimationPriority.Action end)
    local ok, tr = pcall(function() return AC.Animator:LoadAnimation(a) end)
    if ok and tr then
        tr:Play(); notify("Previewing "..SelectedSlot.." — "..id,"info",2)
    else
        notify("Could not load — confirm this is a valid Animation asset ID.","error")
    end
end)

RstBtn.MouseButton1Click:Connect(function()
    local slot = SelectedSlot
    confirmDlg("Reset Animation","Reset '"..slot.."' to Roblox default?",
        function()
            local old = SavedAnims[slot]
            applyAnim(slot, ""); SlotCategories[slot] = nil
            pushUndo({
                undo=function() applyAnim(slot,old); refreshDetail() end,
                redo=function() applyAnim(slot,"");  refreshDetail() end,
            })
            refreshDetail(); notify("Reset "..slot.." to default.","success")
        end, nil)
end)

PbModeBtn.MouseButton1Click:Connect(function()
    PlaybackMode = PlaybackMode=="Dynamic" and "Static" or "Dynamic"
    PbModeBtn.Text = "Mode: "..PlaybackMode
    notify("Playback: "..PlaybackMode,"info",2)
end)
SpeedBox.FocusLost:Connect(function()
    local v = tonumber(SpeedBox.Text)
    if v and v>0 then PlaybackMult = v else SpeedBox.Text = tostring(PlaybackMult) end
end)

refreshDetail()
if SlotBtns["Idle"] then SlotBtns["Idle"].BackgroundColor3 = T.AccDark end

-- =====================================================================
-- PACKS TAB
-- =====================================================================
local PP = Panels["Packs"]; mkPad(PP,9,9,9,9)
mkLabel(PP,"Animation Packs",UDim2.new(1,0,0,24),UDim2.new(0,0,0,0),T.Accent,14).Font=Enum.Font.GothamBold
mkLabel(PP,"Save your current slot setup as a named pack.",
    UDim2.new(1,0,0,14),UDim2.new(0,0,0,26),T.Sub,11)
local PkSearch = mkBox(PP,"Search packs…",UDim2.new(0.62,0,0,30),UDim2.new(0,0,0,44))
PkSearch.TextSize=11
local NewPkBtn = mkBtn(PP,"+ Save Current as Pack",UDim2.new(0.36,-4,0,30),UDim2.new(0.64,4,0,44),T.Accent)
NewPkBtn.TextSize=10
local PkScroll = mkScroll(PP,UDim2.new(1,0,1,-82),UDim2.new(0,0,0,82)); mkList(PkScroll,5)

local function refreshPacks()
    for _,c in ipairs(PkScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local f = PkSearch.Text:lower()
    for i, pk in ipairs(Packs) do
        if f~="" and not pk.name:lower():find(f,1,true) then continue end
        local r = mkFrame(PkScroll,UDim2.new(1,-8,0,50),UDim2.new(0,4,0,0),T.Card)
        r.LayoutOrder=i; mkCorner(r,8); mkStroke(r,T.Border,1); mkPad(r,7,7,7,10)
        mkLabel(r,pk.name,UDim2.new(0.64,0,0.5,0),UDim2.new(0,0,0,0),T.Text,13).Font=Enum.Font.GothamSemibold
        local n=0; for _ in pairs(pk.anims) do n+=1 end
        mkLabel(r,n.." slot(s)",UDim2.new(0.64,0,0.5,0),UDim2.new(0,0,0.5,0),T.Muted,10)
        local ub=mkBtn(r,"Apply",UDim2.new(0,56,0,24),UDim2.new(1,-122,0,13),T.Accent); ub.TextSize=11
        ub.MouseButton1Click:Connect(function()
            for slot,id in pairs(pk.anims) do applyAnim(slot,id) end
            refreshDetail(); notify("Applied pack: "..pk.name,"success")
        end)
        local db=mkBtn(r,"Delete",UDim2.new(0,56,0,24),UDim2.new(1,-62,0,13),T.Bad); db.TextSize=11
        db.MouseButton1Click:Connect(function() table.remove(Packs,i); refreshPacks() end)
    end
end
NewPkBtn.MouseButton1Click:Connect(function()
    local anims={}
    for slot,id in pairs(SavedAnims) do if id~="" then anims[slot]=id end end
    if not next(anims) then notify("No custom animations set yet.","warning") return end
    table.insert(Packs,{name="Pack "..(#Packs+1),anims=anims})
    refreshPacks(); notify("Saved as Pack "..(#Packs),"success")
end)
PkSearch:GetPropertyChangedSignal("Text"):Connect(refreshPacks)
refreshPacks()

-- =====================================================================
-- EMOTES TAB
-- =====================================================================
local EP = Panels["Emotes"]; mkPad(EP,8,8,8,8)
local EmTop = mkFrame(EP,UDim2.new(1,0,0,32),UDim2.new(0,0,0,0),T.Bg); EmTop.BackgroundTransparency=1
local EmSearch  = mkBox(EmTop,"Search emotes…",UDim2.new(0.54,-4,1,-4),UDim2.new(0,0,0,2)); EmSearch.TextSize=11
local FavToggle = mkBtn(EmTop,"★ Favs",UDim2.new(0.22,-4,1,-4),UDim2.new(0.55,4,0,2),T.Card); FavToggle.TextSize=10
local AddEmBtn  = mkBtn(EmTop,"+ Add", UDim2.new(0.21,-2,1,-4),UDim2.new(0.78,4,0,2),T.Accent); AddEmBtn.TextSize=10
local showFavs  = false
FavToggle.MouseButton1Click:Connect(function()
    showFavs=not showFavs; FavToggle.BackgroundColor3=showFavs and T.Warn or T.Card
    FavToggle.Text=showFavs and "★ All" or "★ Favs"
end)
local EmScroll=mkScroll(EP,UDim2.new(1,0,1,-42),UDim2.new(0,0,0,40))
mkGrid(EmScroll,UDim2.new(0,106,0,106),UDim2.new(0,6,0,6)); mkPad(EmScroll,4,4,4,4)

local function refreshEmotes()
    for _,c in ipairs(EmScroll:GetChildren()) do
        if not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    local f = EmSearch.Text:lower()
    for i, em in ipairs(Emotes) do
        if showFavs and not em.favorited then continue end
        if f~="" and not em.name:lower():find(f,1,true) then continue end
        local card=mkFrame(EmScroll,UDim2.new(0,106,0,106),UDim2.new(0,0,0,0),T.Card)
        card.LayoutOrder=i; mkCorner(card,10); mkStroke(card,T.Border,1)
        local th=mkFrame(card,UDim2.new(1,-4,0,63),UDim2.new(0,2,0,2),T.Surface); mkCorner(th,8)
        mkLabel(th,"No Preview",UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),T.Muted,10).TextXAlignment=Enum.TextXAlignment.Center
        mkLabel(card,em.name,UDim2.new(1,-4,0,13),UDim2.new(0,2,0,68),T.Text,10).TextXAlignment=Enum.TextXAlignment.Center
        local pb=mkBtn(card,"▶",UDim2.new(0.5,-2,0,18),UDim2.new(0,1,1,-20),T.Accent); pb.TextSize=11
        pb.MouseButton1Click:Connect(function()
            if not AC.Animator then return end
            local a=Instance.new("Animation"); a.AnimationId="rbxassetid://"..em.id
            pcall(function() a.Priority=Enum.AnimationPriority.Action end)
            local ok,tr=pcall(function() return AC.Animator:LoadAnimation(a) end)
            if ok and tr then tr:Play(); notify("Playing: "..em.name,"info",2) end
        end)
        local fl=mkBtn(card,"⊞",UDim2.new(0.5,-2,0,18),UDim2.new(0.5,1,1,-20),T.Card); fl.TextSize=11
        fl.MouseButton1Click:Connect(function()
            local fb=Instance.new("TextButton")
            fb.Size=UDim2.new(0,66,0,66); fb.Position=UDim2.new(0.5,-33,0.5,-33)
            fb.BackgroundColor3=T.AccDark; fb.TextColor3=T.Text
            fb.Text=em.name:sub(1,6).."\n▶"; fb.TextSize=10; fb.Font=Enum.Font.GothamBold
            fb.ZIndex=90; fb.BorderSizePixel=0; fb.AutoButtonColor=false
            mkCorner(fb,14); mkStroke(fb,T.AccHov,2); fb.Parent=GUI
            makeDraggable(fb,fb,function()
                local v=vp(); local ap=fb.AbsolutePosition; local as=fb.AbsoluteSize
                local nx=ap.X+as.X/2<v.X/2 and 8 or v.X-as.X-8
                tw(fb,{Position=UDim2.new(0,nx,0,math.clamp(ap.Y,8,v.Y-as.Y-8))},0.18)
            end)
            fb.MouseButton1Click:Connect(function()
                if not AC.Animator then return end
                local a2=Instance.new("Animation"); a2.AnimationId="rbxassetid://"..em.id
                pcall(function() a2.Priority=Enum.AnimationPriority.Action end)
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
    local dlg=mkFrame(GUI,UDim2.new(0,348,0,192),UDim2.new(0.5,-174,0.5,-96),T.Surface,"ADlg")
    dlg.ZIndex=71; mkCorner(dlg,12); mkStroke(dlg,T.Border,1); mkPad(dlg,14,14,14,14)
    mkLabel(dlg,"Add Emote",UDim2.new(1,0,0,24),UDim2.new(0,0,0,0),T.Accent,15).Font=Enum.Font.GothamBold
    mkLabel(dlg,"Name:",UDim2.new(1,0,0,14),UDim2.new(0,0,0,28),T.Sub,11)
    local nb=mkBox(dlg,"Emote name…",UDim2.new(1,0,0,30),UDim2.new(0,0,0,44)); nb.TextSize=11
    mkLabel(dlg,"ID or Link:",UDim2.new(1,0,0,14),UDim2.new(0,0,0,80),T.Sub,11)
    local ib=mkBox(dlg,"ID or Roblox link…",UDim2.new(1,0,0,30),UDim2.new(0,0,0,96)); ib.TextSize=11
    local function cl2() pcall(function() ov:Destroy() dlg:Destroy() end) end
    local addB=mkBtn(dlg,"Add",   UDim2.new(0.48,0,0,30),UDim2.new(0,0,1,-30),T.OK); addB.TextSize=11
    local canB=mkBtn(dlg,"Cancel",UDim2.new(0.48,0,0,30),UDim2.new(0.52,0,1,-30),T.Bad); canB.TextSize=11
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
local XP = Panels["Explorer"]; mkPad(XP,9,9,9,9)
mkLabel(XP,"Explorer — Script & Animation Scanner",
    UDim2.new(1,0,0,23),UDim2.new(0,0,0,0),T.Accent,14).Font=Enum.Font.GothamBold
mkLabel(XP,"Scans Workspace for Animations + scripts containing animation IDs.\nAll imports go through the full pipeline.",
    UDim2.new(1,0,0,26),UDim2.new(0,0,0,25),T.Sub,11).TextWrapped=true

local XRow    = mkFrame(XP,UDim2.new(1,0,0,30),UDim2.new(0,0,0,56),T.Bg); XRow.BackgroundTransparency=1
local XBox    = mkBox(XRow,"Optional filter ID",UDim2.new(0.79,-4,1,-4),UDim2.new(0,0,0,2)); XBox.TextSize=11
local ScanBtn = mkBtn(XRow,"Scan",UDim2.new(0.19,-2,1,-4),UDim2.new(0.81,4,0,2),T.Accent); ScanBtn.TextSize=11
local XScroll = mkScroll(XP,UDim2.new(1,0,1,-92),UDim2.new(0,0,0,90)); mkList(XScroll,4)

local function showScriptViewer(obj)
    local ov=mkFrame(GUI,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.new(0,0,0),"SOv")
    ov.BackgroundTransparency=0.45; ov.ZIndex=72
    local win=mkFrame(GUI,UDim2.new(0.82,0,0.82,0),UDim2.new(0.09,0,0.09,0),T.Surface,"SVWin")
    win.ZIndex=73; mkCorner(win,12); mkStroke(win,T.Border,1)
    local function cv() pcall(function() ov:Destroy() win:Destroy() end) end
    mkLabel(win,"  [READ ONLY]  "..obj.Name,
        UDim2.new(1,-44,0,30),UDim2.new(0,4,0,6),T.Accent,12).Font=Enum.Font.GothamBold
    local cl2=mkBtn(win,"✕",UDim2.new(0,28,0,28),UDim2.new(1,-34,0,5),T.Bad); cl2.TextSize=12
    cl2.MouseButton1Click:Connect(cv)
    local sb=Instance.new("TextBox")
    sb.Size=UDim2.new(1,-16,1,-40); sb.Position=UDim2.new(0,8,0,38)
    sb.BackgroundColor3=T.Card; sb.TextColor3=T.Text; sb.TextSize=11
    sb.Font=Enum.Font.RobotoMono; sb.MultiLine=true; sb.TextEditable=false
    sb.TextXAlignment=Enum.TextXAlignment.Left; sb.TextYAlignment=Enum.TextYAlignment.Top
    sb.BorderSizePixel=0; sb.ZIndex=74; mkCorner(sb,8); mkPad(sb,8,8,8,8)
    local src="[Source not accessible — "..obj:GetFullName().."]"
    pcall(function() if obj.Source and #obj.Source>0 then src=obj.Source end end)
    sb.Text=src; sb.Parent=win
    local found={}
    for id in src:gmatch("rbxassetid://(%d+)") do table.insert(found,id) end
    if #found>0 then notify(#found.." ID(s) found in "..obj.Name,"warning",5) end
end

ScanBtn.MouseButton1Click:Connect(function()
    for _,c in ipairs(XScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    local scripts,anims,scriptIds={},{},{}
    local function scanRoot(root)
        if not root then return end
        pcall(function()
            for _,obj in ipairs(root:GetDescendants()) do
                if obj:IsA("BaseScript") then
                    table.insert(scripts,obj)
                    local src=""; pcall(function() src=obj.Source end)
                    for id in src:gmatch("rbxassetid://(%d+)") do
                        table.insert(scriptIds,{id=id,script=obj.Name,path=obj:GetFullName()})
                    end
                elseif obj:IsA("Animation") then
                    table.insert(anims,obj)
                end
            end
        end)
    end
    scanRoot(workspace); if LP.Character then scanRoot(LP.Character) end
    local ord=0
    local function hdr(txt, col)
        local l=mkLabel(XScroll,txt,UDim2.new(1,-8,0,18),UDim2.new(0,4,0,0),col,11)
        l.Font=Enum.Font.GothamBold; l.LayoutOrder=ord; ord+=1
    end
    local function importBtn(parent, id)
        local ib=mkBtn(parent,"Import",UDim2.new(0,58,0,22),UDim2.new(1,-64,0,9),T.OK); ib.TextSize=10
        ib.MouseButton1Click:Connect(function()
            local slot=SelectedSlot; local old=SavedAnims[slot]
            showPipelineDialog(id, slot, function(ok,rid,cat)
                if ok then
                    applyAnim(slot,rid); SlotCategories[slot]=cat
                    pushUndo({undo=function() applyAnim(slot,old); refreshDetail() end,
                              redo=function() applyAnim(slot,rid); refreshDetail() end})
                    refreshDetail(); notify("Imported to "..slot..": "..rid,"success")
                end
            end)
        end)
    end
    hdr("Scripts ("..#scripts..")", T.Warn)
    for _,sc in ipairs(scripts) do
        local r=mkFrame(XScroll,UDim2.new(1,-8,0,38),UDim2.new(0,4,0,0),T.Card)
        r.LayoutOrder=ord; ord+=1; mkCorner(r,8); mkStroke(r,T.Border,1); mkPad(r,4,4,4,8)
        local icon=sc:IsA("LocalScript") and "[L]" or sc:IsA("ModuleScript") and "[M]" or "[S]"
        mkLabel(r,icon.."  "..sc.Name,UDim2.new(0.6,0,0.5,0),UDim2.new(0,0,0,0),T.Text,11).Font=Enum.Font.GothamSemibold
        mkLabel(r,sc:GetFullName(),UDim2.new(0.6,0,0.5,0),UDim2.new(0,0,0.5,0),T.Muted,9)
        local vb=mkBtn(r,"View",UDim2.new(0,50,0,22),UDim2.new(1,-56,0,8),T.Accent); vb.TextSize=10
        vb.MouseButton1Click:Connect(function() showScriptViewer(sc) end)
    end
    if #scriptIds>0 then
        hdr("IDs in Scripts ("..#scriptIds..")", T.Info)
        for _,sid in ipairs(scriptIds) do
            local r=mkFrame(XScroll,UDim2.new(1,-8,0,38),UDim2.new(0,4,0,0),T.Card)
            r.LayoutOrder=ord; ord+=1; mkCorner(r,8); mkStroke(r,T.Info,1); mkPad(r,4,4,4,8)
            mkLabel(r,"ID: "..sid.id,UDim2.new(0.52,0,0.5,0),UDim2.new(0,0,0,0),T.Text,11).Font=Enum.Font.GothamSemibold
            mkLabel(r,"in "..sid.script,UDim2.new(0.52,0,0.5,0),UDim2.new(0,0,0.5,0),T.Muted,9)
            importBtn(r, sid.id)
        end
    end
    hdr("Animation Objects ("..#anims..")", T.OK)
    for _,an in ipairs(anims) do
        local pid=extractId(an.AnimationId) or an.AnimationId
        local r=mkFrame(XScroll,UDim2.new(1,-8,0,40),UDim2.new(0,4,0,0),T.Card)
        r.LayoutOrder=ord; ord+=1; mkCorner(r,8); mkStroke(r,T.Border,1); mkPad(r,4,4,4,8)
        mkLabel(r,an.Name,UDim2.new(0.52,0,0.5,0),UDim2.new(0,0,0,0),T.Text,11).Font=Enum.Font.GothamSemibold
        mkLabel(r,"ID: "..pid,UDim2.new(0.52,0,0.5,0),UDim2.new(0,0,0.5,0),T.Muted,9)
        importBtn(r, pid)
    end
    if #scripts==0 and #anims==0 then
        local e=mkLabel(XScroll,"Nothing found in Workspace.",
            UDim2.new(1,-8,0,24),UDim2.new(0,4,0,0),T.Muted,13)
        e.TextXAlignment=Enum.TextXAlignment.Center; e.LayoutOrder=ord
    end
    setStatus("Scan: "..#scripts.." script(s) | "..#anims.." animation(s) | "..#scriptIds.." IDs in scripts")
end)

-- =====================================================================
-- EDITOR TAB
-- =====================================================================
local EdP=Panels["Editor"]; mkPad(EdP,9,9,9,9)
mkLabel(EdP,"Animation Editor",UDim2.new(1,0,0,24),UDim2.new(0,0,0,0),T.Accent,14).Font=Enum.Font.GothamBold
mkLabel(EdP,"Isolated studio room — cloned character copy. Your real character stays hidden.",
    UDim2.new(1,0,0,14),UDim2.new(0,0,0,26),T.Sub,11).TextWrapped=true
local RigBtn=mkBtn(EdP,"Rig: R15",UDim2.new(0.18,0,0,28),UDim2.new(0,0,0,46),T.Card); RigBtn.TextSize=11
local rigType="R15"
RigBtn.MouseButton1Click:Connect(function()
    rigType=rigType=="R15" and "R6" or "R15"; RigBtn.Text="Rig: "..rigType
end)
local EnterBtn=mkBtn(EdP,"▶  Enter Animation Studio",UDim2.new(0.55,0,0,40),UDim2.new(0.225,0,0,82),T.Accent)
EnterBtn.TextSize=13
local EdStatus=mkLabel(EdP,"",UDim2.new(1,0,0,18),UDim2.new(0,0,0,128),T.Muted,11)
local TL=mkFrame(EdP,UDim2.new(1,0,0,120),UDim2.new(0,0,1,-134),T.Surface,"TL")
TL.Visible=false; mkCorner(TL,10); mkStroke(TL,T.Border,1); mkPad(TL,7,7,7,7)
mkLabel(TL,"Timeline",UDim2.new(0.3,0,0,16),UDim2.new(0,0,0,0),T.Accent,12).Font=Enum.Font.GothamBold
local TrackBar=mkFrame(TL,UDim2.new(1,0,0,38),UDim2.new(0,0,0,18),T.Card,"Track")
mkCorner(TrackBar,6); mkStroke(TrackBar,T.Border,1)
local KfCount=0
local function addKfMark(pct,name)
    pct=math.clamp(pct,0,0.97)
    local mk=mkFrame(TrackBar,UDim2.new(0,9,0.7,0),UDim2.new(pct,-4,0.15,0),T.Accent); mkCorner(mk,3)
    mkLabel(mk,name or "",UDim2.new(0,46,0,12),UDim2.new(0,-3,0,-13),T.Text,8).TextXAlignment=Enum.TextXAlignment.Center
end
local PbRow2=mkFrame(TL,UDim2.new(1,0,0,26),UDim2.new(0,0,0,70),T.Bg); PbRow2.BackgroundTransparency=1
local function pbB2(txt,x,col)
    local b=mkBtn(PbRow2,txt,UDim2.new(0,40,1,-2),UDim2.new(0,x,0,1),col or T.Accent); b.TextSize=11; return b
end
local PlayBtn2=pbB2("▶",0); local PauseBtn2=pbB2("⏸",44,T.Card); local StopBtn2=pbB2("■",88,T.Bad)
local AddKfBtn=mkBtn(PbRow2,"+ KF",UDim2.new(0,50,1,-2),UDim2.new(0,134,0,1),T.OK); AddKfBtn.TextSize=10
local UndoBtn2=mkBtn(PbRow2,"↩",UDim2.new(0,34,1,-2),UDim2.new(0,190,0,1),T.Card)
local RedoBtn2=mkBtn(PbRow2,"↪",UDim2.new(0,34,1,-2),UDim2.new(0,228,0,1),T.Card)
UndoBtn2.MouseButton1Click:Connect(doUndo); RedoBtn2.MouseButton1Click:Connect(doRedo)
local PropsPanel=mkFrame(EdP,UDim2.new(0.28,-4,1,-46),UDim2.new(0.72,4,0,44),T.Surface,"Props")
PropsPanel.Visible=false; mkCorner(PropsPanel,10); mkStroke(PropsPanel,T.Border,1); mkPad(PropsPanel,8,8,8,8)
mkLabel(PropsPanel,"Motor6D / Properties",UDim2.new(1,0,0,18),UDim2.new(0,0,0,0),T.Accent,11).Font=Enum.Font.GothamBold
local PropScroll=mkScroll(PropsPanel,UDim2.new(1,0,1,-26),UDim2.new(0,0,0,24)); mkList(PropScroll,4)
local StudioModel,EdClone,EdDirty,EdActive,EdPlaying,EdTime=nil,nil,false,false,false,0
local function buildStudio()
    local m=Instance.new("Model"); m.Name="AnimStudio_Env"
    local fl=Instance.new("Part"); fl.Size=Vector3.new(50,1,50); fl.Position=Vector3.new(0,-0.5,0)
    fl.Anchored=true; fl.Material=Enum.Material.SmoothPlastic; fl.Color=Color3.fromRGB(20,20,32)
    fl.CanCollide=true; fl.Parent=m
    for i=-12,12,3 do for _,h in ipairs({true,false}) do
        local g=Instance.new("Part")
        g.Size=h and Vector3.new(50,.02,.06) or Vector3.new(.06,.02,50)
        g.Position=h and Vector3.new(0,.01,i) or Vector3.new(i,.01,0)
        g.Anchored=true; g.CanCollide=false; g.Material=Enum.Material.Neon
        g.Color=Color3.fromRGB(50,50,100); g.CastShadow=false; g.Parent=m
    end end
    local sp=Instance.new("Part"); sp.Size=Vector3.new(1,1,1); sp.Position=Vector3.new(0,14,0)
    sp.Anchored=true; sp.Transparency=1; sp.CanCollide=false; sp.Parent=m
    local sl=Instance.new("SpotLight"); sl.Brightness=6; sl.Range=22; sl.Angle=50
    sl.Color=Color3.fromRGB(210,210,255); sl.Face=Enum.NormalId.Bottom; sl.Parent=sp
    m.Parent=workspace; return m
end
local function enterEditor()
    if EdActive then return end
    EdActive=true; Tbtn.Visible=false
    EdStatus.Text="Entering…"; EdStatus.TextColor3=T.Warn
    local fade=mkFrame(GUI,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.new(0,0,0),"Fade")
    fade.BackgroundTransparency=1; fade.ZIndex=95; tw(fade,{BackgroundTransparency=0},0.5); task.wait(0.6)
    StudioModel=buildStudio()
    if LP.Character then
        EdClone=LP.Character:Clone()
        for _,s in ipairs(EdClone:GetDescendants()) do if s:IsA("BaseScript") then s.Disabled=true end end
        EdClone:PivotTo(CFrame.new(0,1.5,0)); EdClone.Parent=workspace
        for _,p in ipairs(LP.Character:GetDescendants()) do if p:IsA("BasePart") then p.Transparency=1 end end
        local rH=LP.Character:FindFirstChild("HumanoidRootPart"); if rH then rH.Anchored=true end
    end
    Camera.CameraType=Enum.CameraType.Scriptable
    tw(Camera,{CFrame=CFrame.new(0,6,14)*CFrame.Angles(math.rad(-18),0,0)},0.5)
    tw(fade,{BackgroundTransparency=1},0.4); task.wait(0.45); pcall(function() fade:Destroy() end)
    TL.Visible=true; PropsPanel.Visible=true
    PropScroll:ClearAllChildren(); mkList(PropScroll,4)
    if EdClone then
        for _,m6 in ipairs(EdClone:GetDescendants()) do
            if m6:IsA("Motor6D") then
                local row=mkFrame(PropScroll,UDim2.new(1,-4,0,26),UDim2.new(0,2,0,0),T.Card); mkCorner(row,6)
                mkLabel(row,m6.Name,UDim2.new(0.5,0,1,0),UDim2.new(0,4,0,0),T.Sub,10)
                local vb=mkBox(row,"0, 0, 0",UDim2.new(0.46,0,0.8,0),UDim2.new(0.52,0,0.1,0))
                vb.TextSize=10; vb.Text="0, 0, 0"
                vb.FocusLost:Connect(function() EdDirty=true; EdStatus.Text="Unsaved"; EdStatus.TextColor3=T.Warn end)
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
        fade.BackgroundTransparency=1; fade.ZIndex=95; tw(fade,{BackgroundTransparency=0},0.4); task.wait(0.5)
        if StudioModel then pcall(function() StudioModel:Destroy() end); StudioModel=nil end
        if EdClone     then pcall(function() EdClone:Destroy()     end); EdClone=nil end
        if LP.Character then
            for _,p in ipairs(LP.Character:GetDescendants()) do if p:IsA("BasePart") then p.Transparency=0 end end
            local rH=LP.Character:FindFirstChild("HumanoidRootPart"); if rH then rH.Anchored=false end
        end
        pcall(function() Camera.CameraType=Enum.CameraType.Custom end)
        TL.Visible=false; PropsPanel.Visible=false; EdActive=false; EdDirty=false; EdPlaying=false; EdTime=0
        EnterBtn.Text="▶  Enter Animation Studio"; EnterBtn.BackgroundColor3=T.Accent
        EdStatus.Text="Exited."; EdStatus.TextColor3=T.Muted
        tw(fade,{BackgroundTransparency=1},0.35); task.wait(0.4); pcall(function() fade:Destroy() end)
        Tbtn.Visible=true; notify("Exited Animation Studio.","info")
    end
    if EdDirty then confirmDlg("Exit Studio","Unsaved changes. Discard?",nil,doExit) else doExit() end
end
EnterBtn.MouseButton1Click:Connect(function() if EdActive then exitEditor() else enterEditor() end end)
PlayBtn2.MouseButton1Click:Connect(function()
    EdPlaying=true
    if EdClone then
        local h2=EdClone:FindFirstChildOfClass("Humanoid"); if not h2 then return end
        local id=SavedAnims[SelectedSlot]; if not id or id=="" then return end
        local a=Instance.new("Animation"); a.AnimationId="rbxassetid://"..id
        pcall(function() a.Priority=SLOT_PRIORITY[SelectedSlot] or Enum.AnimationPriority.Action end)
        local ok,tr=pcall(function() return h2:LoadAnimation(a) end); if ok and tr then tr:Play() end
    end
end)
PauseBtn2.MouseButton1Click:Connect(function()
    EdPlaying=false
    if EdClone then local h2=EdClone:FindFirstChildOfClass("Humanoid"); if h2 then
        local an=h2:FindFirstChildOfClass("Animator"); if an then
            for _,tr in ipairs(an:GetPlayingAnimationTracks()) do pcall(function() tr:AdjustSpeed(0) end) end
        end
    end end
end)
StopBtn2.MouseButton1Click:Connect(function()
    EdPlaying=false; EdTime=0
    if EdClone then local h2=EdClone:FindFirstChildOfClass("Humanoid"); if h2 then
        local an=h2:FindFirstChildOfClass("Animator"); if an then
            for _,tr in ipairs(an:GetPlayingAnimationTracks()) do pcall(function() tr:Stop(0) end) end
        end
    end end
end)
AddKfBtn.MouseButton1Click:Connect(function()
    KfCount+=1; local name="KF"..KfCount
    addKfMark(math.min((KfCount-1)*0.09,0.95),name); EdDirty=true
    EdStatus.Text="Unsaved"; EdStatus.TextColor3=T.Warn; notify("Added "..name,"success",2)
end)
RunService.Heartbeat:Connect(function(dt) if EdActive and EdPlaying then EdTime+=dt end end)

-- =====================================================================
-- CLEANUP
-- =====================================================================
LP.CharacterRemoving:Connect(function()
    AC:Destroy()
    if EdActive then
        if StudioModel then pcall(function() StudioModel:Destroy() end) end
        if EdClone     then pcall(function() EdClone:Destroy()     end) end
        EdActive=false; TL.Visible=false; PropsPanel.Visible=false
    end
end)

-- =====================================================================
-- DEFAULT EMOTES + INITIAL RENDER
-- =====================================================================
for _, e in ipairs({
    {"507770239","Wave"},{"507771019","Point"},
    {"507769814","Cheer"},{"507770818","Laugh"},{"507771508","Dance"},
}) do
    table.insert(Emotes,{id=e[1],name=e[2],favorited=false})
end
refreshEmotes()

-- =====================================================================
-- DONE
-- =====================================================================
notify("Animation Studio v5.0 — tap AS to open.","success",6)
print("[AnimStudio v5.0] Custom controller active. Click the AS button (center screen) to open.")
