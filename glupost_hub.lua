local getgenv_ = getgenv or function() return shared end
local loadstring_ = loadstring or load
local gethui_ = gethui

if getgenv_()._GlupostUnload then pcall(getgenv_()._GlupostUnload) end
if getgenv_()._GlupostHubActive then return end

if type(loadstring_) ~= "function" then
    warn("[glupost] нет loadstring/load — Obsidian не загрузить")
    return
end

local hasDrawing = (function()
    local ok, f = pcall(function() return Drawing and Drawing.new end)
    if not (ok and type(f) == "function") then return false end
    local ok2 = pcall(function() local t = Drawing.new("Circle") t:Remove() end)
    return ok2
end)()
if not hasDrawing then
    warn("[glupost] нет рабочего Drawing API")
    return
end

local hasTriangle = (function()
    local ok = pcall(function()
        local t = Drawing.new("Triangle")
        t.PointA = Vector2.new(0, 0)
        t.PointB = Vector2.new(1, 0)
        t.PointC = Vector2.new(0, 1)
        t:Remove()
    end)
    return ok
end)()

getgenv_()._GlupostHubActive = true

local VERSION = "v20.2.0"

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local HttpSvc      = game:GetService("HttpService")
local Lighting     = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris       = game:GetService("Debris")
local StatsSvc     = game:GetService("Stats")

local LP = Players.LocalPlayer

local v2, v3, cfNew, cfAng, rgb, hsv, clock = Vector2.new, Vector3.new, CFrame.new, CFrame.Angles, Color3.fromRGB, Color3.fromHSV, os.clock
local floor, sin, cos, abs, min, max, sqrt = math.floor, math.sin, math.cos, math.abs, math.min, math.max, math.sqrt
local tclear, tinsert, tremove = table.clear, table.insert, table.remove

local C = {
    VIS_INTERVAL      = 0.2,
    VALIDATE_INTERVAL = 1 / 30,
    TEXT_INTERVAL     = 0.05,
    POOL_STAT         = 0.5,
    WATERMARK_TICK    = 0.25,
    MAX_CHAMS         = 28,
    HAT_SEGMENTS      = 16,
    RING_SEGMENTS     = 24,
    STEP_SEGMENTS     = 16,
    MAX_JUMP_RINGS    = 6,
    MAX_DMG_POPUPS    = 24,
}

local BLACK      = Color3.new(0, 0, 0)
local WHITE      = Color3.new(1, 1, 1)
local GRAY       = Color3.fromRGB(205, 205, 205)
local TOOL_COLOR = Color3.fromRGB(150, 200, 255)
local HP_RED     = Color3.fromRGB(255, 65, 75)
local HP_GREEN   = Color3.fromRGB(70, 255, 130)

local FONTS = { UI = 0, System = 1, Plex = 2, Monospace = 3 }

local SOUND_PRESETS = {
    ["Ping (Classic)"] = "rbxassetid://12221990",
    ["Notification"]   = "rbxassetid://4590657391",
    ["UI Beep"]        = "rbxassetid://12221967",
    ["Bass Thump"]     = "rbxassetid://12221831",
    ["Snap"]           = "rbxassetid://12222140",
    ["Hit"]            = "rbxassetid://12222046",
}

local WORLD_PRESETS = {
    ["Clean Night"] = {
        TimeEnabled = true, Time = 23.5, Brightness = 1.55, Exposure = 0.08,
        ColorShiftTop = Color3.fromRGB(45, 65, 115),
        Grading = true, Saturation = 0.08, Contrast = 0.14, Tint = Color3.fromRGB(214, 228, 255),
        AmbientEnabled = true, Ambient = Color3.fromRGB(80, 92, 125), OutdoorAmbient = Color3.fromRGB(100, 116, 152),
        BloomEnabled = true, BloomIntensity = 0.35, BloomSize = 16, BloomThreshold = 1.1,
    },
    ["Cyberpunk"] = {
        TimeEnabled = true, Time = 21.2, Brightness = 1.65, Exposure = 0.12,
        ColorShiftTop = Color3.fromRGB(165, 60, 230),
        Grading = true, Saturation = 0.30, Contrast = 0.20, Tint = Color3.fromRGB(224, 202, 255),
        AmbientEnabled = true, Ambient = Color3.fromRGB(98, 60, 140), OutdoorAmbient = Color3.fromRGB(72, 122, 165),
        BloomEnabled = true, BloomIntensity = 0.48, BloomSize = 18, BloomThreshold = 0.98,
    },
    ["Cold Frost"] = {
        TimeEnabled = true, Time = 10.5, Brightness = 2.0, Exposure = 0.02,
        ColorShiftTop = Color3.fromRGB(170, 215, 255),
        Grading = true, Saturation = -0.12, Contrast = 0.12, Tint = Color3.fromRGB(210, 235, 255),
        AmbientEnabled = true, Ambient = Color3.fromRGB(118, 138, 165), OutdoorAmbient = Color3.fromRGB(148, 174, 200),
        BloomEnabled = true, BloomIntensity = 0.28, BloomSize = 15, BloomThreshold = 1.15,
    },
    ["Warm Sunset"] = {
        TimeEnabled = true, Time = 18.2, Brightness = 1.85, Exposure = 0.08,
        ColorShiftTop = Color3.fromRGB(255, 150, 90),
        Grading = true, Saturation = 0.24, Contrast = 0.15, Tint = Color3.fromRGB(255, 222, 195),
        AmbientEnabled = true, Ambient = Color3.fromRGB(132, 94, 84), OutdoorAmbient = Color3.fromRGB(178, 124, 98),
        BloomEnabled = true, BloomIntensity = 0.38, BloomSize = 18, BloomThreshold = 1.05,
    },
    ["Blood Moon"] = {
        TimeEnabled = true, Time = 23.0, Brightness = 1.35, Exposure = 0.0,
        ColorShiftTop = Color3.fromRGB(195, 42, 62),
        Grading = true, Saturation = 0.22, Contrast = 0.18, Tint = Color3.fromRGB(255, 182, 188),
        AmbientEnabled = true, Ambient = Color3.fromRGB(102, 36, 46), OutdoorAmbient = Color3.fromRGB(132, 50, 62),
        BloomEnabled = true, BloomIntensity = 0.45, BloomSize = 18, BloomThreshold = 1.0,
    },
    ["Emerald Matrix"] = {
        TimeEnabled = true, Time = 23.8, Brightness = 1.45, Exposure = 0.05,
        ColorShiftTop = Color3.fromRGB(30, 170, 95),
        Grading = true, Saturation = 0.26, Contrast = 0.22, Tint = Color3.fromRGB(185, 255, 210),
        AmbientEnabled = true, Ambient = Color3.fromRGB(35, 90, 58), OutdoorAmbient = Color3.fromRGB(45, 118, 78),
        BloomEnabled = true, BloomIntensity = 0.42, BloomSize = 16, BloomThreshold = 1.02,
    },
    ["Solar Gold"] = {
        TimeEnabled = true, Time = 17.4, Brightness = 2.05, Exposure = 0.14,
        ColorShiftTop = Color3.fromRGB(255, 205, 95),
        Grading = true, Saturation = 0.28, Contrast = 0.14, Tint = Color3.fromRGB(255, 240, 196),
        AmbientEnabled = true, Ambient = Color3.fromRGB(150, 118, 65), OutdoorAmbient = Color3.fromRGB(195, 155, 88),
        BloomEnabled = true, BloomIntensity = 0.46, BloomSize = 20, BloomThreshold = 1.0,
    },
    ["Tokyo Neon"] = {
        TimeEnabled = true, Time = 22.0, Brightness = 1.5, Exposure = 0.10,
        ColorShiftTop = Color3.fromRGB(0, 195, 255),
        Grading = true, Saturation = 0.34, Contrast = 0.22, Tint = Color3.fromRGB(202, 234, 255),
        AmbientEnabled = true, Ambient = Color3.fromRGB(48, 62, 118), OutdoorAmbient = Color3.fromRGB(115, 58, 155),
        BloomEnabled = true, BloomIntensity = 0.56, BloomSize = 20, BloomThreshold = 0.94,
    },
    ["Sakura Dusk"] = {
        TimeEnabled = true, Time = 17.8, Brightness = 1.92, Exposure = 0.10,
        ColorShiftTop = Color3.fromRGB(255, 145, 205),
        Grading = true, Saturation = 0.24, Contrast = 0.12, Tint = Color3.fromRGB(255, 224, 240),
        AmbientEnabled = true, Ambient = Color3.fromRGB(135, 92, 128), OutdoorAmbient = Color3.fromRGB(185, 128, 168),
        BloomEnabled = true, BloomIntensity = 0.44, BloomSize = 20, BloomThreshold = 1.02,
    },
    ["Crimson Void"] = {
        TimeEnabled = true, Time = 0.2, Brightness = 1.25, Exposure = -0.02,
        ColorShiftTop = Color3.fromRGB(190, 25, 55),
        Grading = true, Saturation = 0.28, Contrast = 0.24, Tint = Color3.fromRGB(255, 175, 190),
        AmbientEnabled = true, Ambient = Color3.fromRGB(75, 22, 34), OutdoorAmbient = Color3.fromRGB(110, 32, 48),
        BloomEnabled = true, BloomIntensity = 0.52, BloomSize = 20, BloomThreshold = 0.96,
    },
    ["Golden Dawn"] = {
        TimeEnabled = true, Time = 6.4, Brightness = 1.98, Exposure = 0.12,
        ColorShiftTop = Color3.fromRGB(255, 195, 110),
        Grading = true, Saturation = 0.24, Contrast = 0.12, Tint = Color3.fromRGB(255, 236, 205),
        AmbientEnabled = true, Ambient = Color3.fromRGB(142, 112, 82), OutdoorAmbient = Color3.fromRGB(188, 146, 102),
        BloomEnabled = true, BloomIntensity = 0.42, BloomSize = 18, BloomThreshold = 1.02,
    },
    ["Midnight Mist"] = {
        TimeEnabled = true, Time = 2.0, Brightness = 1.40, Exposure = 0.04,
        ColorShiftTop = Color3.fromRGB(75, 110, 210),
        Grading = true, Saturation = 0.14, Contrast = 0.18, Tint = Color3.fromRGB(198, 218, 255),
        AmbientEnabled = true, Ambient = Color3.fromRGB(58, 72, 115), OutdoorAmbient = Color3.fromRGB(82, 102, 150),
        BloomEnabled = true, BloomIntensity = 0.44, BloomSize = 22, BloomThreshold = 1.02,
    },
}

local function isPartValid(p)
    return p ~= nil and typeof(p) == "Instance" and p:IsA("BasePart") and p.Parent ~= nil
end

local function safeDestroy(o)
    if not o then return end
    pcall(function()
        local t = typeof(o)
        if t == "Instance" then o:Destroy()
        elseif t == "RBXScriptConnection" then if o.Connected then o:Disconnect() end
        elseif t == "RBXScriptSignal" then o:Disconnect()
        else
            if o.Remove then o:Remove()
            elseif o.Destroy then o:Destroy()
            elseif o.Visible ~= nil then o.Visible = false end
        end
    end)
end

local function clamp(v, a, b) return math.clamp(v, a, b) end

local function healthColor(p) return HP_RED:Lerp(HP_GREEN, clamp(p, 0, 1)) end

local function healthText(fmt, hp, max)
    hp, max = math.floor(hp), math.max(math.floor(max), 1)
    if fmt == "Fraction" then return string.format("%d/%d", hp, max)
    elseif fmt == "Percent" then return string.format("%d%%", math.floor(hp / max * 100))
    elseif fmt == "Both" then return string.format("%d/%d (%d%%)", hp, max, math.floor(hp / max * 100)) end
    return string.format("HP %d", hp)
end

local function utf8Trunc(str, maxChars)
    str = tostring(str or "")
    if maxChars <= 0 or str == "" then return "" end
    local ok, len = pcall(utf8.len, str)
    if ok and len then
        if len <= maxChars then return str end
        local off = utf8.offset(str, maxChars + 1)
        return off and string.sub(str, 1, off - 1) or str
    end
    if #str <= maxChars then return str end
    return string.sub(str, 1, maxChars)
end

local HAS_RCF = pcall(function()
    local p = Instance.new("Part")
    local _ = p:GetRenderCFrame()
    p:Destroy()
end)
local useRCF = false
local function partCF(p)
    if useRCF then return p:GetRenderCFrame() end
    return p.CFrame
end
local function partPos(p)
    if useRCF then return p:GetRenderCFrame().Position end
    return p.Position
end

local Module = (function()
    local function charInWorkspacePlayers(plr)
        local f = workspace:FindFirstChild("Players")
        return f and f:FindFirstChild(plr.Name)
    end
    local builtin = {
        [2950983942] = { CustomCharacter = charInWorkspacePlayers },
        [4691401390] = { CustomCharacter = charInWorkspacePlayers },
    }
    local function pickMod(t) return t and (t[game.PlaceId] or t[game.GameId]) end
    return pickMod(getgenv_().GlupostModules) or pickMod(builtin) or {}
end)()

local function getRootPart(char)
    if not char then return nil end
    if Module.RootPartName then
        local p = char:FindFirstChild(Module.RootPartName)
        if p then return p end
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local Profile = {
    ESP = {
        Enabled = false, BoxType = "Corner", BoxThickness = 1,
        MinDistance = 0, MaxDistance = 25000, UnlimitedDistance = false,
        HideTeammates = true, VisibleCheck = false,
        PriorityTarget = false, PriorityMarker = true, ShowThreatScore = false,
        BoxFit = "Fixed", SmartVisCheck = true, SmoothCF = true,
        AdaptiveLOD = true, SyncWithESP = true,
        Outline = true, BoxFill = false, FillOpacity = 0.08,
        HealthBar = true, HealthTrail = false, HeadDot = false,
        LookLine = false, LookRaycast = true, LookLength = 5,
        Rainbow = false, DistanceFade = false,
        TeamColors = false, HeadDotFilled = true,
        ShowName = true, ShowHealth = true, ShowDistance = true, ShowTool = true, ShowState = false,
        DamageNumbers = false,
        TextSize = 13, FontName = "Plex",
        TextOutline = true, NameYOffset = 0, HealthFormat = "HP", HideDefaultTags = false,
        Skeleton = false, SkeletonThickness = 1, SkeletonOutline = true,
        ShowTracer = false, TracerThickness = 1, TracerOrigin = "Bottom",
        TracerOutline = true, TracerFade = true,
        OffscreenArrows = false, ArrowSize = 15,
        Chams = false, ChamsTransparency = 0.45, ChamsOutlineTransparency = 0,
        Colors = {
            Enemy = Color3.fromRGB(255, 78, 98), Ally = Color3.fromRGB(78, 232, 165),
            Priority = Color3.fromRGB(255, 204, 70), Visible = Color3.fromRGB(78, 240, 168),
            Occluded = Color3.fromRGB(255, 140, 75), Skeleton = Color3.fromRGB(230, 238, 255),
            Tracer = Color3.fromRGB(165, 205, 255), Arrow = Color3.fromRGB(255, 195, 75),
            Look = Color3.fromRGB(145, 215, 255), LookAlert = Color3.fromRGB(255, 60, 90),
            Damage = Color3.fromRGB(255, 105, 115),
            ChamsVis = Color3.fromRGB(75, 240, 165), ChamsOcc = Color3.fromRGB(255, 75, 105),
        },
    },
    Radar = {
        Enabled = false, Size = 148, Range = 180, Position = "BottomLeft",
        PosX = -1, PosY = -1,
        Opacity = 0.72, DotSize = 3, ShowLookDir = true, Sweep = true,
    },
    Crosshair = {
        Enabled = false, Style = "Classic", Size = 6, Gap = 3, Thickness = 1,
        Dot = true, Outline = true, Rainbow = false, Dynamic = false, Spin = false,
        Color = Color3.fromRGB(235, 245, 255),
    },
    Hitmarker = {
        Enabled = false, Style = "Cross", Size = 8, Thickness = 2, Duration = 0.24, KillEffect = false,
        Color = Color3.fromRGB(240, 248, 255), KillColor = Color3.fromRGB(255, 70, 95),
    },
    Overlay = {
        Watermark = false,
        Keybinds = false,
        KeybindsX = -1, KeybindsY = -1,
        TargetHUD = false,
        TargetHUDPos = "BottomCenter",
        TargetHUDX = -1, TargetHUDY = -1,
        DragHUD = false,
        Speedometer = false,
        SpeedometerMax = 65,
        SpeedLines = false,
        SpeedLinesMinSpeed = 20,
        SpeedLinesOpacity = 0.65,
        SpeedLinesRainbow = false,
        SpeedLinesColor = Color3.fromRGB(165, 235, 255),
        Accent = Color3.fromRGB(100, 185, 255),
    },
    World = {
        Preset = "None",
        SkyPreset = "Auto",
        Weather = "None",
        WeatherIntensity = 0.6,
        TimeEnabled = false, Time = 14,
        FOVEnabled = false, FOV = 90,
        SpeedFOV = false, SpeedFOVMax = 15, SpeedFOVSens = 1.0,
        NoFog = false,
        AmbientEnabled = false,
        Ambient = Color3.fromRGB(100, 110, 135),
        OutdoorAmbient = Color3.fromRGB(130, 140, 165),
        Grading = false, Saturation = 0.2, Contrast = 0.1,
        Tint = Color3.fromRGB(255, 255, 255),
        BloomEnabled = false, BloomIntensity = 0.4, BloomSize = 18, BloomThreshold = 1.0,
    },
    Objects = {
        Enabled = false, Filter = "", MaxCount = 35, MaxDistance = 1200, UnlimitedDistance = false,
        Interval = 2, ShowDistance = true, ShowTracer = false,
        Color = Color3.fromRGB(85, 235, 255),
    },
    SelfChams = {
        Enabled = false, Style = "Liquid Glass", FillTransparency = 0.58,
        OutlineTransparency = 0.22, AnimationSpeed = 0.9,
        IncludeTools = true, IncludeViewmodel = false,
        FillColor = Color3.fromRGB(135, 218, 255),
        OutlineColor = Color3.fromRGB(235, 250, 255),
    },
    Vignette = {
        LowHP = false, LowHPThreshold = 35,
        KillFlash = false, Intensity = 0.78,
        LowHPColor = Color3.fromRGB(255, 50, 75),
        KillColor = Color3.fromRGB(95, 225, 255),
    },
    ThirdPerson = {
        Enabled = false, Distance = 9, OffsetX = 1.5, OffsetY = 0.4,
        ShowBody = true, ForceCamera = false, ScrollZoom = true,
    },
    ChinaHat = {
        Enabled = false, Shape = "Halo", Style = "Aurora", Size = 1.45, Height = 0.55,
        Opacity = 0.62, HideFirstPerson = true, Color = Color3.fromRGB(115, 205, 255),
    },
    JumpRings = {
        Enabled = false, Style = "Aurora", MaxRadius = 5.2, Lifetime = 0.7, Sparks = true,
        Color = Color3.fromRGB(95, 225, 255),
    },
    FootstepRings = {
        Enabled = false, Style = "Pulse", MaxDistance = 110, MaxRings = 10,
        MaxRadius = 3.4, Lifetime = 0.58, HideTeammates = true,
        Color = Color3.fromRGB(255, 110, 85),
    },
    Proximity = {
        Enabled = false, Distance = 90, SoundPreset = "Ping (Classic)",
        SoundId = "rbxassetid://12221990",
        Volume = 0.7, Cooldown = 2.0, Direction = "Any Direction",
        SpatialSound = true, IgnoreTeammates = true,
    },
    LookingAlert = {
        Enabled = false, MaxDistance = 300, Angle = 14, Radius = 76, RequireLoS = true,
        HideTeammates = true, Color = Color3.fromRGB(255, 70, 95),
    },
    PlayerAura = {
        Enabled = false, Shape = "Orbitals", Style = "Aurora", Size = 2.6, Transparency = 0.72,
        Particles = true, GlowLight = false, Color = Color3.fromRGB(95, 225, 255),
    },
    ParticleTrail = {
        Enabled = false, Mode = "Orbit", Pattern = "Smooth", Style = "Aurora",
        Lifetime = 0.48, Width = 0.14, Speed = 1.0, Sparks = false,
        Color = Color3.fromRGB(95, 225, 255),
    },
    Afterimage = {
        Enabled = false, Style = "Sandevistan", Material = "Neon",
        TriggerMode = "Moving", FadeMode = "Static", SolidGlow = true,
        ConnectArc = false,
        Interval = 0.04, Lifetime = 0.48, Transparency = 0.38,
        MinSpeed = 4, MaxCopies = 14, IncludeAccessories = true,
        Color = Color3.fromRGB(35, 255, 185),
    },
    Satellites = {
        Enabled = false, Count = 3, Shape = "Crystal", Style = "Aurora",
        Radius = 3.2, Height = 0.8, Speed = 1.4, Size = 0.45, Trails = true,
        Color = Color3.fromRGB(95, 225, 255),
    },
    Misc = { JoinLeave = false },
    UI = {
        BgEnabled = false,
        BgId = "",
        BgOpacity = 0.65,
        BgPanelOpacity = 0.78,
        BgScale = "Crop",
        BgTint = Color3.fromRGB(255, 255, 255),
    },
    ThreatWeights = { Visibility = 0.4, LookAtMe = 0.3, Distance = 0.2, Health = 0.1 },
}

local function cfg() return Profile end

local playersData, connections, renderData = {}, {}, {}
local isUnloaded, cleaned = false, false
local ticks = { val = 0, txt = 0, pool = 0, wm = 0, mod = 0, tags = 0, esp = Profile.ESP.Enabled }

local cameraCF, cameraPos = cfNew(), v3()
local fps, poolUsed = 60, 0
local rainbow = Color3.new(1, 0, 0)
local currentPriorityRd = nil

local renderConn, inputBeginConn, inputChangedConn, inputEndedConn, playerAddedConn, playerRemovingConn
local hudState = { kbHeight = 0, rects = {}, drag = nil, offX = 0, offY = 0 }
local rectPool = {
    radar = { x = 0, y = 0, w = 0, h = 0 },
    th = { x = 0, y = 0, w = 0, h = 0 },
    kb = { x = 0, y = 0, w = 0, h = 0 },
}
local function setHudRect(id, x, y, w, h)
    local r = rectPool[id]
    r.x, r.y, r.w, r.h = x, y, w, h
    hudState.rects[id] = r
end

local function updateRainbow()
    rainbow = hsv((clock() * 0.2) % 1, 0.8, 1)
end

local POOLS = {}
for _, cls in ipairs({ "Line", "Text", "Circle", "Square" }) do
    POOLS[cls] = { cls = cls, free = {}, created = 0 }
end
if hasTriangle then
    POOLS.Triangle = { cls = "Triangle", free = {}, created = 0 }
end

local function poolGet(cls)
    local p = POOLS[cls]
    local o = table.remove(p.free)
    if not o then
        o = Drawing.new(cls)
        p.created += 1
    end
    o.Visible = false
    return o
end

local function poolPut(cls, o)
    if not o then return end
    o.Visible = false
    tinsert(POOLS[cls].free, o)
end

local function freeRing(r)
    for _, o in ipairs(r.glow) do poolPut("Line", o) end
    for _, o in ipairs(r.lines) do poolPut("Line", o) end
    if r.glow2 then for _, o in ipairs(r.glow2) do poolPut("Line", o) end end
    if r.lines2 then for _, o in ipairs(r.lines2) do poolPut("Line", o) end end
    if r.sparks then for _, sp in ipairs(r.sparks) do poolPut("Line", sp.line) end end
end

local function numSeq(pts)
    local kps = {}
    for i = 1, #pts do kps[i] = NumberSequenceKeypoint.new(pts[i][1], pts[i][2]) end
    return NumberSequence.new(kps)
end

local function makeEmitter(parent, def)
    local em = Instance.new("ParticleEmitter")
    em.Name = def.Name or "GlupostParticles"
    em.Texture = def.Texture or "rbxasset://textures/particles/sparkles_main.dds"
    em.Rate = def.Rate or 20
    em.Lifetime = NumberRange.new(def.LifeMin, def.LifeMax)
    em.Speed = NumberRange.new(def.SpdMin, def.SpdMax)
    em.SpreadAngle = def.Spread or v2(180, 180)
    if def.Accel then em.Acceleration = def.Accel end
    if def.Dir then em.EmissionDirection = def.Dir end
    if def.Orient then em.Orientation = def.Orient end
    if def.Squash then
        em.Squash = type(def.Squash) == "table" and numSeq(def.Squash) or NumberSequence.new(def.Squash)
    end
    if def.Rot then em.Rotation = def.Rot end
    if def.RotSpd then em.RotSpeed = def.RotSpd end
    if def.Drag then em.Drag = def.Drag end
    if def.VelInherit then em.VelocityInheritance = def.VelInherit end
    if def.ZOffset then em.ZOffset = def.ZOffset end
    if def.volShape then pcall(function() em.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end) end
    em.LightEmission = def.Light ~= nil and def.Light or 1
    if def.Color then em.Color = def.Color end
    em.Size = type(def.Size) == "table" and numSeq(def.Size) or NumberSequence.new(def.Size or 0.2)
    em.Transparency = numSeq(def.Tr)
    em.Parent = parent
    return em
end

local function poolCreated()
    local n = 0
    for _, p in pairs(POOLS) do n += p.created end
    return n
end

local KEYCLS = {
    fill = "Square", outline = "Line",
    hpbg = "Square", hptrail = "Square", hpfill = "Square",
    lines = "Line", corners = "Line", lines3dbg = "Line", lines3d = "Line",
    skeletonbg = "Line", skeleton = "Line",
    look = "Line", lookdot = "Circle",
    tracer = "Line", tracerbg = "Line",
    arrows = "Line", arrowbg = hasTriangle and "Triangle" or "Line", arrowtri = hasTriangle and "Triangle" or "Line", arrowglow = "Line",
    headdot = "Circle", headdotring = "Circle",
    priomarkbg = "Line", priomark = "Line",
    radarbg = "Circle", radar = "Circle", radarlook = "Line", radarprio = "Circle",
    texts = "Text",
}
local ZI = {
    fill = 1, outline = 2, lines3dbg = 2,
    hpbg = 3, tracerbg = 3, skeletonbg = 3, arrowbg = 3, priomarkbg = 3,
    hptrail = 4, lines = 4, corners = 4, lines3d = 4, skeleton = 4, look = 4, tracer = 4, arrows = 4, arrowtri = 4, headdotring = 4, priomark = 4, radarbg = 4,
    hpfill = 5, headdot = 5, lookdot = 5, arrowglow = 5, radar = 5, radarlook = 5,
    texts = 6, radarprio = 6,
}

local function newObj(key)
    local o = poolGet(KEYCLS[key])
    local z = ZI[key]
    if z then pcall(function() o.ZIndex = z end) end
    return o
end

local visParams = RaycastParams.new()
local okFilter = pcall(function()
    visParams.FilterType = Enum.RaycastFilterType.Exclude
end)
if not okFilter then
    pcall(function() visParams.FilterType = Enum.RaycastFilterType.Blacklist end)
end
local visIgnore = {}

local function rawRay(origin, dir, params)
    local ok, res = pcall(workspace.Raycast, workspace, origin, dir, params)
    return ok and res or nil
end

local function styleColors(style, base, speed, offset)
    if style == "Custom" or not style then
        local col = base or rgb(80, 220, 255)
        return col, col:Lerp(WHITE, 0.45)
    end
    local phase = clock() * (speed or 1) + (offset or 0)
    if style == "Rainbow" then
        local h = (phase * 0.16) % 1
        return hsv(h, 0.85, 1), hsv((h + 0.12) % 1, 0.45, 1)
    elseif style == "Holographic" then
        local h = (0.53 + sin(phase * 0.75) * 0.13) % 1
        return hsv(h, 0.55, 1), hsv((h + 0.14) % 1, 0.25, 1)
    elseif style == "Cyber" then
        local k = (sin(phase * 1.4) + 1) * 0.5
        return rgb(0, 240, 255):Lerp(rgb(255, 40, 210), k), rgb(245, 250, 255)
    elseif style == "Aurora" then
        local a, b, c = rgb(45, 255, 205), rgb(105, 115, 255), rgb(205, 85, 255)
        local k = (sin(phase * 0.7) + 1) * 0.5
        return k < 0.5 and a:Lerp(b, k * 2) or b:Lerp(c, (k - 0.5) * 2), rgb(215, 255, 245):Lerp(c, k * 0.35)
    elseif style == "Flame" then
        local k = (sin(phase * 1.6) + 1) * 0.5
        return rgb(255, 210, 55):Lerp(rgb(255, 45, 35), k), rgb(255, 120, 40)
    elseif style == "Void" then
        local k = (sin(phase * 1.1) + 1) * 0.5
        return rgb(115, 35, 255):Lerp(rgb(255, 45, 180), k), rgb(220, 175, 255)
    elseif style == "Frost" then
        local k = (sin(phase * 0.9) + 1) * 0.5
        return rgb(120, 225, 255):Lerp(rgb(235, 250, 255), k), WHITE
    elseif style == "Sakura" then
        local k = (sin(phase * 0.85) + 1) * 0.5
        return rgb(255, 195, 225):Lerp(rgb(255, 95, 165), k), rgb(255, 240, 248)
    elseif style == "Matrix" then
        local k = (sin(phase * 1.25) + 1) * 0.5
        return rgb(30, 255, 120):Lerp(rgb(15, 165, 85), k), rgb(195, 255, 215)
    elseif style == "Sunset" then
        local k = (sin(phase * 0.95) + 1) * 0.5
        return rgb(255, 190, 75):Lerp(rgb(255, 75, 130), k), rgb(255, 235, 190)
    elseif style == "Gold" then
        local k = (sin(phase * 1.05) + 1) * 0.5
        return rgb(255, 225, 95):Lerp(rgb(255, 165, 35), k), rgb(255, 248, 210)
    end
    local col = base or rgb(80, 220, 255)
    return col, col:Lerp(WHITE, 0.45)
end

local Fx = (function()
local selfChamsHighlight, selfChamsCharacter
local selfVmHighlights = {}
local scSavedParts, scSavedDecals, scSavedClothes, scSavedMeshes, scSavedSurf = {}, {}, {}, {}, {}
local scSeenParts, scSeenDecals, scSeenClothes, scSeenMeshes, scSeenSurf = {}, {}, {}, {}, {}
local scHasSaved, scForceScan, scLastScan = false, true, 0
local scLastChar, scLastStyle, scLastTools, scLastVM = nil, nil, nil, nil
local scChildConn, scChildRemConn = nil, nil
local vmActiveMap = {}
local auraAttachment, auraEmitter, auraLight
local trailObjects, trailAttachments, trailEmitters, trailOrbitPairs = {}, {}, {}, {}
local trailModeCur, trailPatternCur, trailSparksCur, trailWidthCur = nil, nil, nil, nil
local afterimages, afterArcLines = {}, {}
local lastAfterimage = 0
local lastEffectCharacter
local auraDrawOuter, auraDrawGlow, auraDrawInner, auraDrawNodes = {}, {}, {}, {}
local auraAngle = 0
local hatLines, hatGlow, hatTris, hatNodes = {}, {}, {}, {}
local hatPts, hatZ, hatOk, crownBasePts, crownTipPts = {}, {}, {}, {}, {}
local lastHatShape = nil
local jumpRings = {}
local lastFloorMaterial = nil
local lastJumpTime = 0
local satItems, satShapeCur, satCountCur, satTrailsCur, satSizeCur = {}, nil, 0, nil, 0
local auraSeqC1, auraSeqC2, auraSeq = nil, nil, nil
local trailSeqC1, trailSeqC2, trailSeq = nil, nil, nil
local DOWN_14 = Vector3.new(0, -14, 0)
local UP_005 = Vector3.new(0, 0.05, 0)
local DEF_DROP = Vector3.new(0, 2.8, 0)
local VEC3_ONE = Vector3.new(1, 1, 1)
local groundParams = RaycastParams.new()
groundParams.FilterType = visParams.FilterType
local groundIgnore, lastGroundChar, lastGroundCam = {}, nil, nil

local function colorDelta(a, b)
    return abs(a.R - b.R) + abs(a.G - b.G) + abs(a.B - b.B)
end

local function selfChamsColor(t)
    local e = cfg().SelfChams
    local style = e.Style
    local phase = t * math.max(e.AnimationSpeed, 0.05)

    if style == "Pulse" then
        local pulse = (math.sin(phase * 2.2) + 1) * 0.5
        return e.FillColor:Lerp(WHITE, pulse * 0.34), e.OutlineColor:Lerp(WHITE, pulse * 0.2)
    elseif style == "Energy Rim" then
        local pulse = (math.sin(phase * 2.6) + 1) * 0.5
        local rim = e.OutlineColor:Lerp(Color3.fromRGB(165, 245, 255), pulse * 0.45)
        return e.FillColor, rim
    elseif style == "Scanline" then
        local wave = (math.sin(phase * 3.1) + 1) * 0.5
        local cA = e.FillColor
        local cB = e.OutlineColor
        return cA:Lerp(cB, wave * 0.55), cB:Lerp(WHITE, wave * 0.4)
    elseif style == "Liquid Glass" or style == "Glass" then
        local shimmer = (math.sin(phase * 1.35) + 1) * 0.5
        local baseTint = e.FillColor:Lerp(Color3.fromRGB(210, 242, 255), 0.32 + shimmer * 0.24)
        local rim = e.OutlineColor:Lerp(WHITE, 0.35 + shimmer * 0.25)
        return baseTint, rim
    elseif style == "ForceField" then
        local pulse = (math.sin(phase * 1.8) + 1) * 0.5
        return e.FillColor:Lerp(Color3.fromRGB(165, 245, 255), pulse * 0.25), e.OutlineColor
    elseif style == "Custom" then
        return e.FillColor, e.OutlineColor
    end
    return styleColors(style, e.FillColor, math.max(e.AnimationSpeed, 0.05))
end

local function restoreSinglePart(p, orig)
    if p and p.Parent then
        pcall(function()
            p.Material = orig.mat
            p.Color = orig.col
            p.Transparency = orig.tr
            p.Reflectance = orig.refl
            p.CastShadow = orig.cast
            if orig.tex ~= nil and p:IsA("MeshPart") then
                p.TextureID = orig.tex
            end
        end)
    end
end

local function restoreSelfMaterials()
    for p, orig in pairs(scSavedParts) do
        restoreSinglePart(p, orig)
    end
    table.clear(scSavedParts)

    for d, origTr in pairs(scSavedDecals) do
        if d and d.Parent then pcall(function() d.Transparency = origTr end) end
    end
    table.clear(scSavedDecals)

    for obj, orig in pairs(scSavedClothes) do
        if obj and obj.Parent then pcall(function() obj[orig.prop] = orig.val end) end
    end
    table.clear(scSavedClothes)

    for m, orig in pairs(scSavedMeshes) do
        if m and m.Parent then
            pcall(function()
                m.TextureId = orig.tex
                m.VertexColor = orig.vc
            end)
        end
    end
    table.clear(scSavedMeshes)

    for sa, origParent in pairs(scSavedSurf) do
        if origParent and origParent.Parent then
            pcall(function() sa.Parent = origParent end)
        else
            safeDestroy(sa)
        end
    end
    table.clear(scSavedSurf)
    scHasSaved = false
end

local function clearScCharConns()
    if scChildConn then safeDestroy(scChildConn) scChildConn = nil end
    if scChildRemConn then safeDestroy(scChildRemConn) scChildRemConn = nil end
    scLastChar = nil
end

local function destroySelfChams()
    if selfChamsHighlight then safeDestroy(selfChamsHighlight) end
    selfChamsHighlight, selfChamsCharacter = nil, nil
    for _, hl in pairs(selfVmHighlights) do safeDestroy(hl) end
    table.clear(selfVmHighlights)
    clearScCharConns()
    scForceScan = true
    restoreSelfMaterials()
end

local function hideRingDrawings()
    for _, o in ipairs(auraDrawGlow) do o.Visible = false end
    for _, o in ipairs(auraDrawOuter) do o.Visible = false end
    for _, o in ipairs(auraDrawInner) do o.Visible = false end
    for _, o in ipairs(auraDrawNodes) do o.Visible = false end
end

local function clearAura()
    safeDestroy(auraAttachment)
    safeDestroy(auraLight)
    auraAttachment, auraEmitter, auraLight = nil, nil, nil
    auraSeqC1, auraSeqC2, auraSeq = nil, nil, nil
    for _, o in ipairs(auraDrawGlow) do poolPut("Line", o) end
    for _, o in ipairs(auraDrawOuter) do poolPut("Line", o) end
    for _, o in ipairs(auraDrawInner) do poolPut("Line", o) end
    for _, o in ipairs(auraDrawNodes) do poolPut("Circle", o) end
    table.clear(auraDrawGlow)
    table.clear(auraDrawOuter)
    table.clear(auraDrawInner)
    table.clear(auraDrawNodes)
end

local function clearTrail()
    for _, tr in ipairs(trailObjects) do safeDestroy(tr) end
    for _, em in ipairs(trailEmitters) do safeDestroy(em) end
    for _, a in ipairs(trailAttachments) do safeDestroy(a) end
    table.clear(trailObjects)
    table.clear(trailEmitters)
    table.clear(trailAttachments)
    table.clear(trailOrbitPairs)
    trailModeCur, trailPatternCur, trailSparksCur, trailWidthCur = nil, nil, nil, nil
    trailSeqC1, trailSeqC2, trailSeq = nil, nil, nil
end

local function clearAfterimages()
    for _, item in ipairs(afterimages) do
        safeDestroy(item.model)
    end
    table.clear(afterimages)
    for _, ln in ipairs(afterArcLines) do poolPut("Line", ln) end
    table.clear(afterArcLines)
end

local function clearHat()
    for _, o in ipairs(hatGlow) do poolPut("Line", o) end
    for _, o in ipairs(hatLines) do poolPut("Line", o) end
    for _, o in ipairs(hatTris) do poolPut("Triangle", o) end
    for _, o in ipairs(hatNodes) do poolPut("Circle", o) end
    table.clear(hatGlow)
    table.clear(hatLines)
    table.clear(hatTris)
    table.clear(hatNodes)
    lastHatShape = nil
end

local function hideHat()
    for _, o in ipairs(hatGlow) do o.Visible = false end
    for _, o in ipairs(hatLines) do o.Visible = false end
    for _, o in ipairs(hatTris) do o.Visible = false end
    for _, o in ipairs(hatNodes) do o.Visible = false end
end

local function clearJumpRings()
    for _, r in ipairs(jumpRings) do freeRing(r) end
    tclear(jumpRings)
end

local function clearSatellites()
    for _, item in ipairs(satItems) do
        safeDestroy(item.part)
    end
    tclear(satItems)
    satShapeCur, satCountCur, satTrailsCur, satSizeCur = nil, 0, nil, 0
end

local function clearLocalEffects()
    clearAura()
    clearTrail()
    clearAfterimages()
    clearHat()
    clearJumpRings()
    clearSatellites()
    lastEffectCharacter = nil
    lastFloorMaterial = nil
end

local AURA_EM_DEF = {
    Name = "GlupostAuraParticles", Rate = 22, LifeMin = 0.65, LifeMax = 1.25, SpdMin = 1.2, SpdMax = 3.0,
    Accel = v3(0, 2.2, 0), Drag = 1.6,
    Size = { {0, 0}, {0.25, 0.22}, {1, 0} }, Tr = { {0, 0.1}, {1, 1} },
}
local function ensureAuraParticles(root)
    if auraAttachment and auraAttachment.Parent == root then return end
    safeDestroy(auraAttachment)
    auraSeq = nil
    local att = Instance.new("Attachment")
    att.Name, att.Position, att.Parent = "GlupostAuraAttachment", v3(0, 0.25, 0), root
    auraAttachment = att
    auraEmitter = makeEmitter(att, AURA_EM_DEF)
end

local function ensureAuraLight(root)
    if auraLight and auraLight.Parent == root then return end
    safeDestroy(auraLight)
    local pl = Instance.new("PointLight")
    pl.Name, pl.Shadows, pl.Brightness, pl.Range, pl.Parent = "GlupostAuraLight", false, 1.6, 10, root
    auraLight = pl
end

local TRAIL_PATTERNS = {
    Pulse = { br = 3.4, mode = Enum.TextureMode.Stretch, w = { {0,1},{0.2,0.35},{0.4,0.95},{0.65,0.25},{0.85,0.7},{1,0} }, t = { {0,0.04},{0.25,0.72},{0.5,0.12},{0.75,0.78},{1,1} } },
    Starlight = { br = 3.8, mode = Enum.TextureMode.Wrap, tex = "rbxasset://textures/particles/sparkles_main.dds", tlen = 1.6, w = { {0,1.15},{0.4,0.85},{1,0} }, t = { {0,0.05},{0.6,0.35},{1,1} } },
    Blade = { br = 4.0, mode = Enum.TextureMode.Stretch, w = { {0,1.35},{0.18,1.05},{0.65,0.35},{1,0} }, t = { {0,0},{0.22,0.12},{0.75,0.68},{1,1} } },
    ["Neon Core"] = { br = 4.6, mode = Enum.TextureMode.Stretch, w = { {0,1.15},{0.55,0.95},{0.85,0.55},{1,0} }, t = { {0,0.02},{0.7,0.25},{1,1} } },
    Smooth = { br = 2.8, mode = Enum.TextureMode.Stretch, w = { {0,1},{0.28,0.72},{0.7,0.25},{1,0} }, t = { {0,0.06},{0.5,0.45},{1,1} } },
}
local TRAIL_SPARK_DEF = {
    Name = "GlupostTrailSparks", Rate = 14, LifeMin = 0.22, LifeMax = 0.52, SpdMin = 0.5, SpdMax = 1.9,
    Drag = 2.0, Size = { {0, 0.14}, {0.4, 0.1}, {1, 0} }, Tr = { {0, 0.1}, {1, 1} },
}

local function makeRibbonPair(parentPart, posA, posB, lifetime, pattern, withSparks)
    local a0 = Instance.new("Attachment")
    a0.Name, a0.Position, a0.Parent = "GlupostTrailA", posA, parentPart
    local a1 = Instance.new("Attachment")
    a1.Name, a1.Position, a1.Parent = "GlupostTrailB", posB, parentPart
    local pat = TRAIL_PATTERNS[pattern] or TRAIL_PATTERNS.Smooth
    local tr = Instance.new("Trail")
    tr.Name, tr.Enabled = "GlupostEnergyRibbon", false
    tr.Attachment0, tr.Attachment1 = a0, a1
    tr.FaceCamera, tr.LightEmission, tr.MinLength, tr.Lifetime = true, 1, 0.03, lifetime
    tr.Brightness, tr.TextureMode = pat.br, pat.mode
    if pat.tex then tr.Texture, tr.TextureLength = pat.tex, pat.tlen end
    tr.WidthScale, tr.Transparency = numSeq(pat.w), numSeq(pat.t)
    tr.Parent = parentPart
    if withSparks then
        tinsert(trailEmitters, makeEmitter(a0, TRAIL_SPARK_DEF))
    end
    tinsert(trailAttachments, a0)
    tinsert(trailAttachments, a1)
    tinsert(trailObjects, tr)
    return a0, a1
end

local function trailLimb(char, root, n1, n2, fbOff, limbOff, hw, lifetime, pattern, withSparks)
    local p = char:FindFirstChild(n1) or char:FindFirstChild(n2) or root
    local off = (p == root) and fbOff or limbOff
    makeRibbonPair(p, off + v3(0, hw, 0), off - v3(0, hw, 0), lifetime, pattern, withSparks)
end

local function ensureTrail(char, root, mode, pattern, width, lifetime, withSparks)
    if #trailObjects > 0 and trailModeCur == mode and trailPatternCur == pattern
        and trailSparksCur == withSparks and trailWidthCur and abs(trailWidthCur - width) <= 0.005 then
        local valid = true
        for _, tr in ipairs(trailObjects) do
            if not tr or not tr.Parent then valid = false break end
        end
        if valid then return end
    end
    clearTrail()
    trailModeCur, trailPatternCur, trailSparksCur, trailWidthCur = mode, pattern, withSparks, width
    local hw = clamp(width or 0.16, 0.05, 0.6) * 0.5
    if mode == "Hands" or mode == "Full" then
        trailLimb(char, root, "LeftHand", "Left Arm", v3(-1.3, 0.2, 0), v3(0, -0.25, 0), hw, lifetime, pattern, withSparks)
        trailLimb(char, root, "RightHand", "Right Arm", v3(1.3, 0.2, 0), v3(0, -0.25, 0), hw, lifetime, pattern, withSparks)
    end
    if mode == "Feet" or mode == "Full" then
        trailLimb(char, root, "LeftFoot", "Left Leg", v3(-0.55, -2.5, 0), v3(0, -0.15, 0), hw, lifetime, pattern, withSparks)
        trailLimb(char, root, "RightFoot", "Right Leg", v3(0.55, -2.5, 0), v3(0, -0.15, 0), hw, lifetime, pattern, withSparks)
    end
    if mode == "Hands" or mode == "Feet" or mode == "Full" then return end
    if mode == "Void Slash" then
        for _, p in ipairs({ v3(-1.75, 1.35, 0.65), v3(1.75, 1.35, 0.65), v3(-1.1, -0.4, 0.85), v3(1.1, -0.4, 0.85) }) do
            makeRibbonPair(root, p + v3(0, hw, 0), p - v3(0, hw, 0), lifetime, pattern, withSparks)
        end
    elseif mode == "Orbit" or mode == "Helix" or mode == "Spiral Halo" then
        local cnt = (mode == "Orbit") and 3 or 2
        local defPos = (mode == "Orbit") and v3(2.2, 0, 0) or (mode == "Helix" and v3(1.5, 0, 0) or v3(1.2, 2.2, 0))
        local kind = (mode == "Spiral Halo") and "Halo" or mode
        for k = 1, cnt do
            local a0, a1 = makeRibbonPair(root, defPos, defPos + v3(0, hw * 2, 0), lifetime, pattern, withSparks)
            trailOrbitPairs[k] = { a0 = a0, a1 = a1, phase = (k - 1) * ((math.pi * 2) / cnt), hw = hw, kind = kind }
        end
    else
        makeRibbonPair(root, v3(-1.45, 0.55 + hw, 0.35), v3(-1.45, 0.55 - hw, 0.35), lifetime, pattern, withSparks)
        makeRibbonPair(root, v3(1.45, 0.55 + hw, 0.35), v3(1.45, 0.55 - hw, 0.35), lifetime, pattern, withSparks)
    end
end

local SANDEVISTAN_STOPS = {
    { 0.00, Color3.fromRGB(35, 255, 175) },
    { 0.22, Color3.fromRGB(0, 215, 255) },
    { 0.45, Color3.fromRGB(70, 95, 255) },
    { 0.68, Color3.fromRGB(215, 45, 255) },
    { 0.85, Color3.fromRGB(255, 50, 75) },
    { 1.00, Color3.fromRGB(255, 185, 35) },
}

local function sandevistanColor(prog, style, customCol, spawnHue)
    if style == "Sandevistan" then
        for i = 1, #SANDEVISTAN_STOPS - 1 do
            local a, b = SANDEVISTAN_STOPS[i], SANDEVISTAN_STOPS[i + 1]
            if prog <= b[1] then
                local span = math.max(b[1] - a[1], 0.001)
                return a[2]:Lerp(b[2], clamp((prog - a[1]) / span, 0, 1))
            end
        end
        return SANDEVISTAN_STOPS[#SANDEVISTAN_STOPS][2]
    elseif style == "Phantom" then
        if prog < 0.45 then
            return Color3.fromRGB(235, 250, 255):Lerp(Color3.fromRGB(85, 225, 255), prog / 0.45)
        end
        return Color3.fromRGB(85, 225, 255):Lerp(Color3.fromRGB(30, 65, 145), (prog - 0.45) / 0.55)
    elseif style == "Inferno" then
        if prog < 0.4 then
            return Color3.fromRGB(255, 235, 110):Lerp(Color3.fromRGB(255, 125, 25), prog / 0.4)
        end
        return Color3.fromRGB(255, 125, 25):Lerp(Color3.fromRGB(190, 20, 40), (prog - 0.4) / 0.6)
    elseif style == "Void" then
        return Color3.fromRGB(165, 90, 255):Lerp(Color3.fromRGB(255, 35, 165), prog)
    elseif style == "Cyber" then
        return Color3.fromRGB(0, 245, 255):Lerp(Color3.fromRGB(255, 35, 200), prog)
    elseif style == "Rainbow" then
        return Color3.fromHSV((spawnHue + prog * 0.45) % 1, 0.88, 1)
    elseif style == "Sakura" then
        return Color3.fromRGB(255, 225, 240):Lerp(Color3.fromRGB(255, 90, 165), prog)
    elseif style == "Matrix" then
        return Color3.fromRGB(145, 255, 180):Lerp(Color3.fromRGB(15, 185, 80), prog)
    elseif style == "Sunset" then
        return Color3.fromRGB(255, 215, 90):Lerp(Color3.fromRGB(230, 60, 145), prog)
    elseif style == "Gold" then
        return Color3.fromRGB(255, 245, 175):Lerp(Color3.fromRGB(245, 160, 25), prog)
    end
    return customCol or Color3.fromRGB(0, 255, 190)
end

local function cloneGhostPart(src, mat, col, tr, model, solidGlow)
    if not isPartValid(src) or src.Transparency >= 1 then return nil end
    local ok, ghost = pcall(function() return src:Clone() end)
    if not ok or not ghost then return nil end
    for _, child in ipairs(ghost:GetDescendants()) do
        if not child:IsA("SpecialMesh") and not child:IsA("BlockMesh") and not child:IsA("CylinderMesh") then
            safeDestroy(child)
        elseif child:IsA("SpecialMesh") then
            pcall(function()
                child.TextureId = ""
                child.VertexColor = Vector3.new(1, 1, 1)
            end)
        end
    end
    pcall(function() ghost.TextureID = "" end)
    if solidGlow and ghost:IsA("MeshPart") then
        local hasTex = false
        pcall(function() hasTex = (ghost.TextureID ~= "") end)
        if hasTex then
            safeDestroy(ghost)
            local box = Instance.new("Part")
            box.Size = src.Size
            ghost = box
        end
    end
    ghost.Name = "GhostPart"
    ghost.Anchored = true
    ghost.CanCollide, ghost.CanTouch, ghost.CanQuery = false, false, false
    ghost.CastShadow = false
    ghost.Massless = true
    pcall(function() ghost.LocalTransparencyModifier = 0 end)
    ghost.Material = mat
    ghost.Color = col
    ghost.Transparency = tr
    ghost.CFrame = partCF(src)
    ghost.Parent = model
    return ghost
end

local function makeAfterimage(char)
    local e = cfg().Afterimage
    local maxCopies = clamp(math.floor(e.MaxCopies or 16), 4, 24)
    while #afterimages >= maxCopies do
        local old = table.remove(afterimages, 1)
        safeDestroy(old.model)
    end

    local model = Instance.new("Model")
    model.Name = "GlupostSandevistanGhost"
    local matMode = e.Material or "Neon"
    local isWire = (matMode == "Wireframe")
    local mat = Enum.Material.SmoothPlastic
    if matMode == "Neon" then mat = Enum.Material.Neon
    elseif matMode == "ForceField" or isWire then mat = Enum.Material.ForceField
    elseif matMode == "Glass" then mat = Enum.Material.Glass
    elseif e.SolidGlow and matMode ~= "SmoothPlastic" then mat = Enum.Material.Neon end

    local baseTr = clamp(e.Transparency, 0.1, 0.92)
    local partBaseTr = isWire and clamp(baseTr + 0.38, 0.62, 0.95) or baseTr
    local spawnHue = (clock() * 0.55) % 1
    local startCol = sandevistanColor(0, e.Style, e.Color, spawnHue)
    local clonedParts, boxes = {}, {}

    for _, src in ipairs(char:GetChildren()) do
        if src:IsA("BasePart") and src.Name ~= "HumanoidRootPart" and #clonedParts < 18 then
            local g = cloneGhostPart(src, mat, startCol, partBaseTr, model, e.SolidGlow)
            if g then
                table.insert(clonedParts, g)
                if isWire and #boxes < 12 then
                    local sb = Instance.new("SelectionBox")
                    sb.Name = "GlupostWireGhost"
                    sb.Adornee = g
                    sb.Color3 = startCol
                    sb.SurfaceColor3 = startCol
                    sb.LineThickness = 0.025
                    sb.SurfaceTransparency = 0.88
                    sb.Transparency = baseTr
                    sb.Parent = g
                    table.insert(boxes, sb)
                end
            end
        elseif e.IncludeAccessories and src:IsA("Accessory") and #clonedParts < 26 then
            local handle = src:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local g = cloneGhostPart(handle, mat, startCol, partBaseTr, model, e.SolidGlow)
                if g then table.insert(clonedParts, g) end
            end
        end
    end

    if #clonedParts == 0 then
        safeDestroy(model)
        return
    end

    model.Parent = workspace.CurrentCamera or workspace
    local rootP = getRootPart(char)
    local originPos = isPartValid(rootP) and partPos(rootP) or Vector3.new()
    local baseCFs = {}
    for idx, gp in ipairs(clonedParts) do
        baseCFs[idx] = gp.CFrame
    end
    table.insert(afterimages, {
        model = model,
        parts = clonedParts,
        boxes = boxes,
        baseCFs = baseCFs,
        originPos = originPos,
        born = clock(),
        life = clamp(e.Lifetime, 0.12, 2.0),
        baseTr = baseTr,
        isWire = isWire,
        style = e.Style,
        fadeMode = e.FadeMode or "Static",
        customCol = e.Color,
        spawnHue = spawnHue,
        seed = math.random() * 10,
    })
end

local function updateAfterimages(cam, root)
    if #afterimages == 0 then
        for _, ln in ipairs(afterArcLines) do ln.Visible = false end
        return
    end
    local now = clock()
    local e = cfg().Afterimage
    for i = #afterimages, 1, -1 do
        local item = afterimages[i]
        local elapsed = now - item.born
        if elapsed >= item.life or not item.model or not item.model.Parent then
            safeDestroy(item.model)
            table.remove(afterimages, i)
        else
            local prog = clamp(elapsed / item.life, 0, 1)
            local tr = item.baseTr + (1 - item.baseTr) * (prog * prog)
            local col = sandevistanColor(prog, item.style, item.customCol, item.spawnHue)
            local fm = item.fadeMode
            if fm == "Glitch" then
                local flick = (math.sin(now * 58 + (item.seed or i) * 3.1) > 0.35) and 0.16 or 0
                tr = clamp(tr + flick, item.baseTr, 0.98)
            end
            local partTr = item.isWire and clamp(tr + 0.38, 0.62, 0.99) or tr
            for idx, p in ipairs(item.parts) do
                if p and p.Parent then
                    p.Color = col
                    p.Transparency = partTr
                    local bcf = item.baseCFs[idx]
                    if bcf then
                        if fm == "Ascend" then
                            p.CFrame = bcf + Vector3.new(0, prog * 1.75, 0)
                        elseif fm == "Expand" then
                            local out = bcf.Position - item.originPos
                            local push = out.Magnitude > 0.05 and out.Unit * (prog * 0.85) or Vector3.new()
                            p.CFrame = bcf + push
                        elseif fm == "Implode" then
                            local out = bcf.Position - item.originPos
                            p.CFrame = bcf - out * (prog * 0.65)
                        elseif fm == "Glitch" then
                            local jx = math.sin(now * 62 + idx * 5.7 + i) * 0.24 * prog
                            local jz = math.cos(now * 54 + idx * 4.3 + i) * 0.24 * prog
                            local jy = (math.sin(now * 41 + i * 2) > 0.5) and (0.14 * prog) or 0
                            p.CFrame = bcf + Vector3.new(jx, jy, jz)
                        elseif fm == "Spiral" then
                            local out = bcf.Position - item.originPos
                            local theta = prog * math.pi * 1.5
                            local cs, sn = math.cos(theta), math.sin(theta)
                            local rx = out.X * cs - out.Z * sn
                            local rz = out.X * sn + out.Z * cs
                            local targetPos = item.originPos + Vector3.new(rx, out.Y + prog * 1.25, rz)
                            p.CFrame = (bcf - bcf.Position) + targetPos
                        end
                    end
                end
            end
            if item.boxes then
                for _, sb in ipairs(item.boxes) do
                    if sb and sb.Parent then
                        sb.Color3 = col
                        sb.SurfaceColor3 = col
                        sb.Transparency = tr
                        sb.SurfaceTransparency = clamp(0.88 + prog * 0.12, 0.88, 1)
                    end
                end
            end
        end
    end

    local usedArc = 0
    if e.ConnectArc and cam and isPartValid(root) and #afterimages >= 1 then
        local rootSp = cam:WorldToViewportPoint(partPos(root))
        local prevPt = (rootSp.Z > 0.1) and Vector2.new(rootSp.X, rootSp.Y) or nil
        for i = #afterimages, 1, -1 do
            local item = afterimages[i]
            local sp = cam:WorldToViewportPoint(item.originPos)
            local curPt = (sp.Z > 0.1) and Vector2.new(sp.X, sp.Y) or nil
            if prevPt and curPt then
                usedArc += 1
                local ln = afterArcLines[usedArc]
                if not ln then
                    ln = poolGet("Line")
                    pcall(function() ln.ZIndex = 4 end)
                    afterArcLines[usedArc] = ln
                end
                local p = clamp((now - item.born) / item.life, 0, 1)
                local c = sandevistanColor(p, item.style, item.customCol, item.spawnHue)
                ln.From, ln.To = prevPt, curPt
                ln.Color, ln.Thickness, ln.Transparency, ln.Visible = c, 1.8, (1 - p) * 0.88, true
            end
            prevPt = curPt
        end
    end
    for k = usedArc + 1, #afterArcLines do
        afterArcLines[k].Visible = false
    end
end

local function rayGroundPos(char, root)
    local origin = partPos(root)
    local cam = workspace.CurrentCamera
    if char ~= lastGroundChar or cam ~= lastGroundCam then
        lastGroundChar, lastGroundCam = char, cam
        table.clear(groundIgnore)
        groundIgnore[1] = char
        if cam then groundIgnore[2] = cam end
        groundParams.FilterDescendantsInstances = groundIgnore
    end
    local res = rawRay(origin, DOWN_14, groundParams)
    if res then
        return res.Position + UP_005
    end
    return origin - DEF_DROP
end

local function setRingPair(glowArr, lineArr, idx, p1, p2, vis, col, glowCol, alpha, thick)
    local gl = glowArr[idx]
    if not gl then gl = poolGet("Line") pcall(function() gl.ZIndex = 2 end) glowArr[idx] = gl end
    local ln = lineArr[idx]
    if not ln then ln = poolGet("Line") pcall(function() ln.ZIndex = 3 end) lineArr[idx] = ln end
    if vis then
        gl.From, gl.To, gl.Color, gl.Thickness, gl.Transparency, gl.Visible = p1, p2, glowCol, thick + 3, alpha * 0.24, true
        ln.From, ln.To, ln.Color, ln.Thickness, ln.Transparency, ln.Visible = p1, p2, col, thick, alpha, true
    else
        gl.Visible, ln.Visible = false, false
    end
end

local function drawRing(cam, origin, isCF, radius, angleOff, segments, glowArr, lineArr, slotOff, col, glowCol, alpha, thick)
    local step = (math.pi * 2) / segments
    local prevPt, prevOk, firstPt, firstOk = nil, false, nil, false
    for i = 0, segments - 1 do
        local a = angleOff + i * step
        local off = v3(cos(a) * radius, 0, sin(a) * radius)
        local sp = cam:WorldToViewportPoint(isCF and origin:PointToWorldSpace(off) or (origin + off))
        local ok = sp.Z > 0.1
        local pt = ok and v2(sp.X, sp.Y) or nil
        if i == 0 then
            firstPt, firstOk = pt, ok
        else
            setRingPair(glowArr, lineArr, slotOff + i, prevPt, pt, ok and prevOk, col, glowCol, alpha, thick)
        end
        prevPt, prevOk = pt, ok
    end
    setRingPair(glowArr, lineArr, slotOff + segments, prevPt, firstPt, prevOk and firstOk, col, glowCol, alpha, thick)
end

local function drawWorldRing(cam, centerPos, radius, angleOff, segments, glowArr, lineArr, col, glowCol, alpha, thick)
    drawRing(cam, centerPos, false, radius, angleOff, segments, glowArr, lineArr, 0, col, glowCol, alpha, thick)
end

local function spawnJumpRing(pos)
    local jr = cfg().JumpRings
    if #jumpRings >= C.MAX_JUMP_RINGS then
        freeRing(tremove(jumpRings, 1))
    end
    local col1, col2 = styleColors(jr.Style, jr.Color, 1)
    local sparks = {}
    if jr.Sparks ~= false then
        for s = 1, 8 do
            local ln = poolGet("Line")
            pcall(function() ln.ZIndex = 4 end)
            sparks[s] = {
                ang = (s - 1) * (math.pi * 0.25) + (math.random() - 0.5) * 0.25,
                rad = 0.65 + math.random() * 0.45,
                ht = 1.6 + math.random() * 1.4,
                line = ln,
            }
        end
    end
    tinsert(jumpRings, {
        pos = pos, born = clock(), life = clamp(jr.Lifetime, 0.2, 2.0), maxR = clamp(jr.MaxRadius, 2, 12),
        col = col1, glowCol = col2, glow = {}, lines = {}, glow2 = {}, lines2 = {}, sparks = sparks,
    })
end

local function updateJumpRings(cam, char, root, humanoid)
    local jr = cfg().JumpRings
    if not jr.Enabled then
        if #jumpRings > 0 then clearJumpRings() end
        lastFloorMaterial = humanoid and humanoid.FloorMaterial or nil
        return
    end

    local now = clock()
    if humanoid and isPartValid(root) then
        local curMat = humanoid.FloorMaterial
        if lastFloorMaterial ~= nil then
            local jumped = (lastFloorMaterial ~= Enum.Material.Air and curMat == Enum.Material.Air and humanoid:GetState() == Enum.HumanoidStateType.Jumping)
            local landed = (lastFloorMaterial == Enum.Material.Air and curMat ~= Enum.Material.Air)
            if (jumped or landed) and (now - lastJumpTime >= 0.18) then
                lastJumpTime = now
                spawnJumpRing(rayGroundPos(char, root))
            end
        end
        lastFloorMaterial = curMat
    end

    for i = #jumpRings, 1, -1 do
        local r = jumpRings[i]
        local elapsed = now - r.born
        if elapsed >= r.life then
            freeRing(r)
            tremove(jumpRings, i)
        else
            local t = elapsed / r.life
            local ease = 1 - (1 - t) * (1 - t)
            local curR = 0.45 + (r.maxR - 0.45) * ease
            local alpha = (1 - t) * 0.92
            drawRing(cam, r.pos, false, curR, t * 1.4, C.RING_SEGMENTS, r.glow, r.lines, 0, r.col, r.glowCol, alpha, 1.8)
            if jr.Sparks ~= false then
                local r2 = 0.3 + (r.maxR * 0.66 - 0.3) * min(ease * 1.15, 1)
                drawRing(cam, r.pos + v3(0, 0.25 * ease, 0), false, r2, -t * 1.9, C.RING_SEGMENTS, r.glow2, r.lines2, 0, r.glowCol, r.col, alpha * 0.72, 1.1)
                for _, sp in ipairs(r.sparks) do
                    local dRad = (0.4 + sp.rad * curR * 0.48) * (1 + ease * 0.16)
                    local yB = sp.ht * (t * 0.72)
                    local yT = yB + sp.ht * 0.56 * (1 - t * 0.55)
                    local cx, sz = cos(sp.ang), sin(sp.ang)
                    local p1 = cam:WorldToViewportPoint(r.pos + v3(cx * dRad, yB, sz * dRad))
                    local p2 = cam:WorldToViewportPoint(r.pos + v3(cx * (dRad * (1.12 + ease * 0.18)), yT, sz * (dRad * (1.12 + ease * 0.18))))
                    if p1.Z > 0.1 and p2.Z > 0.1 then
                        local sparkCol = (t < 0.25) and WHITE:Lerp(r.glowCol, t / 0.25) or r.glowCol
                        sp.line.From, sp.line.To = v2(p1.X, p1.Y), v2(p2.X, p2.Y)
                        sp.line.Color, sp.line.Thickness, sp.line.Transparency, sp.line.Visible = sparkCol, 1.6, alpha, true
                    else
                        sp.line.Visible = false
                    end
                end
            else
                for _, o in ipairs(r.glow2) do o.Visible = false end
                for _, o in ipairs(r.lines2) do o.Visible = false end
                for _, sp in ipairs(r.sparks) do sp.line.Visible = false end
            end
        end
    end
end

local hatSegOrder = {}
for i = 1, C.HAT_SEGMENTS do
    hatSegOrder[i] = { i = i, j = (i % C.HAT_SEGMENTS) + 1, z = 0 }
end
local crownBaseBotPts, crownBaseZ, crownTipZ, crownOrder = {}, {}, {}, {}
for i = 1, 8 do crownOrder[i] = { i = i, j = (i % 8) + 1, z = 0 } end
local crysEqPts, crysEqZ, crysEqOk = {}, {}, {}
local crysFaces = {}
for i = 1, 8 do crysFaces[i] = { idx = i, upper = (i <= 4), s1 = ((i - 1) % 4) + 1, s2 = (i % 4) + 1, z = 0 } end
local function sortHatSegDesc(a, b) return a.z > b.z end

local function setHatEdge(idx, a2, b2, cEdge, cGlow, rimAlpha)
    local gl = hatGlow[idx]
    if not gl then gl = poolGet("Line") pcall(function() gl.ZIndex = 18 end) hatGlow[idx] = gl end
    local ln = hatLines[idx]
    if not ln then ln = poolGet("Line") pcall(function() ln.ZIndex = 19 end) hatLines[idx] = ln end
    if a2 and b2 then
        gl.From, gl.To, gl.Color, gl.Thickness, gl.Transparency, gl.Visible = a2, b2, cGlow, 4, rimAlpha * 0.28, true
        ln.From, ln.To, ln.Color, ln.Thickness, ln.Transparency, ln.Visible = a2, b2, cEdge, 1.5, rimAlpha, true
    else
        gl.Visible, ln.Visible = false, false
    end
end

local function updateChinaHat(cam, char)
    local ch = cfg().ChinaHat
    local head = char and char:FindFirstChild("Head")
    if not ch.Enabled or not isPartValid(head) then
        hideHat()
        return
    end
    local headPos = partPos(head)
    if ch.HideFirstPerson and (cam.CFrame.Position - headPos).Magnitude < 2.2 then
        hideHat()
        return
    end

    local t = clock()
    local col, rimCol = styleColors(ch.Style, ch.Color, 1)
    local segs = C.HAT_SEGMENTS
    local step = (math.pi * 2) / segs
    local spin = t * 0.55
    local rimAlpha = clamp(ch.Opacity + 0.35, 0.2, 1)

    local shapeChanged = (lastHatShape ~= ch.Shape)
    lastHatShape = ch.Shape

    if ch.Shape == "Halo" then
        for _, o in ipairs(hatTris) do o.Visible = false end
        local haloPos = headPos + v3(0, 0.7 + ch.Height * 0.55 + sin(t * 2.4) * 0.05, 0)
        local tilt1 = cfNew(haloPos) * cfAng(sin(t * 1.1) * 0.16, spin, cos(t * 0.9) * 0.14)
        local tilt2 = cfNew(haloPos + v3(0, 0.08, 0)) * cfAng(-sin(t * 1.1) * 0.18, -spin * 1.4, -cos(t * 0.9) * 0.16)
        drawRing(cam, tilt1, true, ch.Size * 0.64, 0, segs, hatGlow, hatLines, 0, rimCol, col, rimAlpha, 1.8)
        drawRing(cam, tilt2, true, ch.Size * 0.46, 0, segs, hatGlow, hatLines, segs, col, rimCol, rimAlpha * 0.78, 1.2)
        for idx = segs * 2 + 1, #hatGlow do hatGlow[idx].Visible = false end
        for idx = segs * 2 + 1, #hatLines do hatLines[idx].Visible = false end
        local nodeTint = WHITE:Lerp(rimCol, 0.35)
        for n = 1, 8 do
            local nd = hatNodes[n]
            if not nd then
                nd = poolGet("Circle")
                pcall(function() nd.ZIndex = 20 end)
                hatNodes[n] = nd
            end
            local isOuter = (n <= 4)
            local na = ((n - 1) % 4) * (math.pi * 0.5) + (isOuter and 0 or (math.pi * 0.25))
            local rad = isOuter and (ch.Size * 0.64) or (ch.Size * 0.46)
            local cf = isOuter and tilt1 or tilt2
            local sp = cam:WorldToViewportPoint(cf:PointToWorldSpace(v3(cos(na) * rad, 0, sin(na) * rad)))
            if sp.Z > 0.1 then
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = v2(sp.X, sp.Y), isOuter and 2.6 or 1.8, 10, true
                nd.Color, nd.Transparency, nd.Visible = isOuter and nodeTint or col, isOuter and rimAlpha or (rimAlpha * 0.85), true
            else
                nd.Visible = false
            end
        end
        for n = 9, #hatNodes do hatNodes[n].Visible = false end
        return
    elseif ch.Shape == "CyberRing" then
        for _, o in ipairs(hatTris) do o.Visible = false end
        local ringCenter = headPos + v3(0, 0.74 + ch.Height * 0.48 + sin(t * 2.2) * 0.05, 0)
        local hStep = (math.pi * 2) / 6
        local rOut, rIn = ch.Size * 0.72, ch.Size * 0.48
        local isCustom = (ch.Style == "Custom")
        local cfOut = cfNew(ringCenter) * cfAng(sin(t * 0.9) * 0.12, spin * 1.15, cos(t * 0.8) * 0.10)
        local cfIn = cfNew(ringCenter + v3(0, 0.12, 0)) * cfAng(-sin(t * 0.9) * 0.14, -spin * 1.65, -cos(t * 0.8) * 0.12)
        for i = 1, 6 do
            local a = (i - 1) * hStep
            local pO = cam:WorldToViewportPoint(cfOut:PointToWorldSpace(v3(cos(a) * rOut, 0, sin(a) * rOut)))
            local pI = cam:WorldToViewportPoint(cfIn:PointToWorldSpace(v3(cos(a) * rIn, 0, sin(a) * rIn)))
            crownBasePts[i] = (pO.Z > 0.1) and v2(pO.X, pO.Y) or nil
            crownTipPts[i] = (pI.Z > 0.1) and v2(pI.X, pI.Y) or nil
            local nd = hatNodes[i]
            if not nd then
                nd = poolGet("Circle")
                pcall(function() nd.ZIndex = 20 end)
                hatNodes[i] = nd
            end
            if crownBasePts[i] then
                local _, sr = col, rimCol
                if not isCustom then _, sr = styleColors(ch.Style, ch.Color, 1, i * 0.35) end
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = crownBasePts[i], 2.4, 10, true
                nd.Color, nd.Transparency, nd.Visible = sr, rimAlpha, true
            else
                nd.Visible = false
            end
        end
        for n = 7, #hatNodes do hatNodes[n].Visible = false end
        local eIdx = 0
        for i = 1, 6 do
            local j = (i % 6) + 1
            local sc, sr = col, rimCol
            if not isCustom then sc, sr = styleColors(ch.Style, ch.Color, 1, i * 0.45) end
            eIdx += 1; setHatEdge(eIdx, crownBasePts[i], crownBasePts[j], sr, sc, rimAlpha)
            eIdx += 1; setHatEdge(eIdx, crownTipPts[i], crownTipPts[j], sc, sr, rimAlpha * 0.85)
            eIdx += 1; setHatEdge(eIdx, crownBasePts[i], crownTipPts[i], sr, sc, rimAlpha * 0.65)
        end
        for k = eIdx + 1, #hatGlow do hatGlow[k].Visible = false end
        for k = eIdx + 1, #hatLines do hatLines[k].Visible = false end
        return
    elseif ch.Shape == "Crown" then
        local cSegs = 8
        local cStep = (math.pi * 2) / cSegs
        local rad = ch.Size * 0.56
        local radBot = rad * 0.94
        local baseY = headPos + v3(0, 0.58 + sin(t * 2.2) * 0.04, 0)
        local spikeH = max(0.35, ch.Height * 0.96)
        local fillAlpha = clamp(ch.Opacity, 0.1, 0.9)
        local isCustom = (ch.Style == "Custom")
        for i = 1, cSegs do
            local a = spin + (i - 1) * cStep
            local cx, cz = cos(a), sin(a)
            local bp = cam:WorldToViewportPoint(baseY + v3(cx * rad, 0, cz * rad))
            crownBaseZ[i] = bp.Z
            crownBasePts[i] = (bp.Z > 0.1) and v2(bp.X, bp.Y) or nil
            local bb = cam:WorldToViewportPoint(baseY + v3(cx * radBot, -0.12, cz * radBot))
            crownBaseBotPts[i] = (bb.Z > 0.1) and v2(bb.X, bb.Y) or nil
            local ta = a + cStep * 0.5
            local isMajor = (i % 2 == 1)
            local tipH = isMajor and (spikeH * 1.06) or (spikeH * 0.62)
            local tipR = isMajor and (rad * 1.15) or (rad * 1.07)
            local tp = cam:WorldToViewportPoint(baseY + v3(cos(ta) * tipR, tipH, sin(ta) * tipR))
            crownTipZ[i] = tp.Z
            crownTipPts[i] = (tp.Z > 0.1) and v2(tp.X, tp.Y) or nil

            local nd = hatNodes[i]
            if not nd then
                nd = poolGet("Circle")
                pcall(function() nd.ZIndex = 20 end)
                hatNodes[i] = nd
            end
            if crownTipPts[i] then
                local sc, sr = col, rimCol
                if not isCustom then sc, sr = styleColors(ch.Style, ch.Color, 1, (i - 1) * 0.4) end
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = crownTipPts[i], isMajor and 2.8 or 2.0, 10, true
                nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(isMajor and sr or sc, 0.45), rimAlpha, true
            else
                nd.Visible = false
            end
        end
        for n = cSegs + 1, #hatNodes do hatNodes[n].Visible = false end

        for i = 1, cSegs do
            local ord = crownOrder[i]
            local p1, p2, pt = crownBasePts[i], crownBasePts[ord.j], crownTipPts[i]
            ord.z = (p1 and p2 and pt) and ((crownBaseZ[i] + crownBaseZ[ord.j] + crownTipZ[i]) / 3) or -9999
        end
        table.sort(crownOrder, sortHatSegDesc)

        for rank = 1, cSegs do
            local ord = crownOrder[rank]
            local i, j = ord.i, ord.j
            local p1, p2, pt = crownBasePts[i], crownBasePts[j], crownTipPts[i]
            local sc, sr = col, rimCol
            if not isCustom then sc, sr = styleColors(ch.Style, ch.Color, 1, (i - 1) * 0.4) end
            if hasTriangle then
                local tri = hatTris[rank]
                if not tri then
                    tri = poolGet("Triangle")
                    pcall(function() tri.ZIndex = 1 + rank end)
                    hatTris[rank] = tri
                elseif shapeChanged then
                    pcall(function() tri.ZIndex = 1 + rank end)
                end
                if p1 and p2 and pt then
                    tri.PointA, tri.PointB, tri.PointC = pt, p1, p2
                    tri.Filled, tri.Color, tri.Transparency, tri.Visible = true, (i % 2 == 1) and sc or sc:Lerp(sr, 0.22), fillAlpha, true
                else
                    tri.Visible = false
                end
            end
        end
        for k = cSegs + 1, #hatTris do hatTris[k].Visible = false end

        local lIdx = 0
        for i = 1, cSegs do
            local j = (i % cSegs) + 1
            local p1, p2, pt = crownBasePts[i], crownBasePts[j], crownTipPts[i]
            local pb1, pb2 = crownBaseBotPts[i], crownBaseBotPts[j]
            local sc, sr = col, rimCol
            if not isCustom then sc, sr = styleColors(ch.Style, ch.Color, 1, (i - 1) * 0.4) end
            lIdx += 1; setHatEdge(lIdx, p1, p2, sr, sc, rimAlpha)
            lIdx += 1; setHatEdge(lIdx, pb1, pb2, sc, sr, rimAlpha * 0.85)
            lIdx += 1; setHatEdge(lIdx, p1, pt, sr, sc, rimAlpha)
            lIdx += 1; setHatEdge(lIdx, p2, pt, sr, sc, rimAlpha)
        end
        for k = lIdx + 1, #hatGlow do hatGlow[k].Visible = false end
        for k = lIdx + 1, #hatLines do hatLines[k].Visible = false end
        return
    elseif ch.Shape == "Crystal" then
        local center = headPos + v3(0, 0.92 + ch.Height * 0.72 + sin(t * 2.5) * 0.08, 0)
        local rad = ch.Size * 0.44
        local halfH = max(0.32, ch.Height * 0.82)
        local topSp = cam:WorldToViewportPoint(center + v3(0, halfH, 0))
        local botSp = cam:WorldToViewportPoint(center - v3(0, halfH, 0))
        local midSp = cam:WorldToViewportPoint(center)
        local topOk, botOk = topSp.Z > 0.1, botSp.Z > 0.1
        local top2 = topOk and v2(topSp.X, topSp.Y) or nil
        local bot2 = botOk and v2(botSp.X, botSp.Y) or nil
        local mid2 = (midSp.Z > 0.1) and v2(midSp.X, midSp.Y) or nil
        local cSpin = t * 1.15
        for i = 1, 4 do
            local a = cSpin + (i - 1) * (math.pi * 0.5)
            local sp = cam:WorldToViewportPoint(center + v3(cos(a) * rad, 0, sin(a) * rad))
            crysEqOk[i] = sp.Z > 0.1
            crysEqZ[i] = sp.Z
            crysEqPts[i] = crysEqOk[i] and v2(sp.X, sp.Y) or nil
        end
        for f = 1, 8 do
            local cf = crysFaces[f]
            local az, aOk = cf.upper and topSp.Z or botSp.Z, cf.upper and topOk or botOk
            cf.z = (aOk and crysEqOk[cf.s1] and crysEqOk[cf.s2]) and ((az + crysEqZ[cf.s1] + crysEqZ[cf.s2]) / 3) or -9999
        end
        table.sort(crysFaces, sortHatSegDesc)
        local fillAlpha = clamp(ch.Opacity, 0.1, 0.9)
        local isCustom = (ch.Style == "Custom")
        for rank = 1, 8 do
            local cf = crysFaces[rank]
            local pApex = cf.upper and top2 or bot2
            local p1, p2 = crysEqPts[cf.s1], crysEqPts[cf.s2]
            if hasTriangle then
                local tri = hatTris[rank]
                if not tri then
                    tri = poolGet("Triangle")
                    pcall(function() tri.ZIndex = 1 + rank end)
                    hatTris[rank] = tri
                elseif shapeChanged then
                    pcall(function() tri.ZIndex = 1 + rank end)
                end
                if pApex and p1 and p2 then
                    local sc, sr = col, rimCol
                    if not isCustom then sc, sr = styleColors(ch.Style, ch.Color, 1, cf.idx * 0.35) end
                    tri.PointA, tri.PointB, tri.PointC = pApex, p1, p2
                    tri.Filled, tri.Color, tri.Transparency, tri.Visible = true, cf.upper and sc:Lerp(sr, 0.25) or sc, fillAlpha, true
                else
                    tri.Visible = false
                end
            end
        end
        for k = 9, #hatTris do hatTris[k].Visible = false end
        local eIdx = 0
        for i = 1, 4 do
            local j = (i % 4) + 1
            local sc, sr = col, rimCol
            if not isCustom then sc, sr = styleColors(ch.Style, ch.Color, 1, i * 0.4) end
            eIdx += 1; setHatEdge(eIdx, crysEqPts[i], crysEqPts[j], sr, sc, rimAlpha)
            eIdx += 1; setHatEdge(eIdx, top2, crysEqPts[i], sr, sc, rimAlpha)
            eIdx += 1; setHatEdge(eIdx, bot2, crysEqPts[i], sr, sc, rimAlpha)
        end
        for k = eIdx + 1, #hatGlow do hatGlow[k].Visible = false end
        for k = eIdx + 1, #hatLines do hatLines[k].Visible = false end
        local nodeCoords = { top2, bot2, mid2 }
        for n = 1, 3 do
            local nd = hatNodes[n]
            if not nd then
                nd = poolGet("Circle")
                pcall(function() nd.ZIndex = 20 end)
                hatNodes[n] = nd
            end
            local np = nodeCoords[n]
            if np then
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = np, (n == 3) and 3.0 or 2.1, 10, true
                nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(rimCol, (n == 3) and 0.25 or 0.5), (n == 3) and (rimAlpha * 0.72) or rimAlpha, true
            else
                nd.Visible = false
            end
        end
        for n = 4, #hatNodes do hatNodes[n].Visible = false end
        return
    end

    local apexWorld = headPos + v3(0, 0.55 + ch.Height, 0)
    local apexSp = cam:WorldToViewportPoint(apexWorld)
    if apexSp.Z <= 0.1 then
        hideHat()
        return
    end
    local apex2 = v2(apexSp.X, apexSp.Y)
    local baseCenter = headPos + v3(0, 0.52, 0)
    local fillAlpha = clamp(ch.Opacity, 0.1, 0.9)
    local isCustom = (ch.Style == "Custom")

    for i = 1, segs do
        local a = spin + (i - 1) * step
        local wp = baseCenter + v3(cos(a) * ch.Size, 0, sin(a) * ch.Size)
        local sp = cam:WorldToViewportPoint(wp)
        hatOk[i] = sp.Z > 0.1
        hatZ[i] = sp.Z
        hatPts[i] = hatOk[i] and v2(sp.X, sp.Y) or nil
    end

    for idx = 1, segs do
        local seg = hatSegOrder[idx]
        local i, j = seg.i, seg.j
        seg.z = (hatOk[i] and hatOk[j]) and ((hatZ[i] + hatZ[j]) * 0.5) or -9999
    end
    table.sort(hatSegOrder, sortHatSegDesc)

    for rank = 1, segs do
        local seg = hatSegOrder[rank]
        local i, j = seg.i, seg.j
        local p1, p2 = hatPts[i], hatPts[j]
        local ok = hatOk[i] and hatOk[j]
        local segCol, segRim = col, rimCol
        if not isCustom then segCol, segRim = styleColors(ch.Style, ch.Color, 1, (i - 1) / segs * 1.8) end

        if hasTriangle then
            local tri = hatTris[rank]
            if not tri then
                tri = poolGet("Triangle")
                pcall(function() tri.ZIndex = 1 + rank end)
                hatTris[rank] = tri
            elseif shapeChanged then
                pcall(function() tri.ZIndex = 1 + rank end)
            end
            if ok then
                tri.PointA, tri.PointB, tri.PointC = apex2, p1, p2
                tri.Filled, tri.Color, tri.Transparency, tri.Visible = true, segCol, fillAlpha, true
            else
                tri.Visible = false
            end
        end

        setHatEdge(i, ok and p1 or nil, ok and p2 or nil, segRim, segCol, rimAlpha)
    end
    local ribIdx = segs
    for rib = 0, 3 do
        local r = 1 + floor(rib * segs / 4)
        ribIdx += 1
        setHatEdge(ribIdx, hatOk[r] and apex2 or nil, hatPts[r], rimCol, col, rimAlpha * 0.36)
    end
    for k = ribIdx + 1, #hatGlow do hatGlow[k].Visible = false end
    for k = ribIdx + 1, #hatLines do hatLines[k].Visible = false end
    local apNd = hatNodes[1]
    if not apNd then apNd = poolGet("Circle") pcall(function() apNd.ZIndex = 20 end) hatNodes[1] = apNd end
    apNd.Position, apNd.Radius, apNd.NumSides, apNd.Filled = apex2, 2.3, 10, true
    apNd.Color, apNd.Transparency, apNd.Visible = WHITE:Lerp(rimCol, 0.35), rimAlpha, true
    for n = 2, #hatNodes do hatNodes[n].Visible = false end
end

local function updateAuraShape(cam, char, root, dt, aura)
    local t = clock()
    auraAngle = (auraAngle + (dt or 0.016) * 1.45) % (math.pi * 2)
    local c1, c2 = styleColors(aura.Style, aura.Color, 1)
    local pulse = 1 + sin(t * 2.8) * 0.05
    local alpha = clamp(1 - aura.Transparency + 0.55, 0.25, 0.95)
    local bodyCenter = partPos(root) + v3(0, 0.15, 0)
    local shape = aura.Shape or "Orbitals"
    local usedSegs, usedInner, usedNodes = 0, 0, 0

    if shape == "Orbitals" then
        local r = aura.Size * pulse
        local cf1 = cfNew(bodyCenter) * cfAng(0.66, auraAngle, 0.24)
        local cf2 = cfNew(bodyCenter) * cfAng(-0.66, -auraAngle * 1.18, -0.24)
        local cf3 = cfNew(bodyCenter) * cfAng(sin(t * 1.4) * 0.28, auraAngle * 0.7, cos(t * 1.1) * 0.22)
        drawRing(cam, cf1, true, r, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, 0, c1, c2, alpha, 1.6)
        drawRing(cam, cf2, true, r * 0.92, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, C.RING_SEGMENTS, c2, c1, alpha * 0.88, 1.4)
        drawRing(cam, cf3, true, r * 1.06, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, C.RING_SEGMENTS * 2, c1:Lerp(c2, 0.5), c2, alpha * 0.75, 1.1)
        usedSegs = C.RING_SEGMENTS * 3
        for n = 1, 4 do
            local nd = auraDrawNodes[n]
            if not nd then nd = poolGet("Circle") pcall(function() nd.ZIndex = 4 end) auraDrawNodes[n] = nd end
            local ringCF = (n <= 2) and cf1 or cf2
            local rad = (n <= 2) and r or (r * 0.92)
            local na = (n % 2 == 0) and 0 or math.pi
            local sp = cam:WorldToViewportPoint(ringCF:PointToWorldSpace(v3(cos(na) * rad, 0, sin(na) * rad)))
            if sp.Z > 0.1 then
                local nodePulse = (sin(t * 3.8 + n * 1.4) + 1) * 0.5
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = v2(sp.X, sp.Y), 2.3 + nodePulse * 0.85, 10, true
                nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(c2, 0.35), alpha, true
            else
                nd.Visible = false
            end
        end
        usedNodes = 4
    elseif shape == "Helix" then
        local steps = 26
        local radBase = aura.Size * 0.68 * pulse
        local isCustom = (aura.Style == "Custom")
        for strand = 0, 1 do
            local prevPt, prevOk = nil, false
            for s = 0, steps do
                local f = s / steps
                local y = -2.6 + f * 4.8
                local taper = 0.65 + 0.35 * sin(f * math.pi)
                local ang = auraAngle * 2.2 + f * (math.pi * 3.6) + strand * math.pi
                local wp = bodyCenter + v3(cos(ang) * radBase * taper, y, sin(ang) * radBase * taper)
                local sp = cam:WorldToViewportPoint(wp)
                local ok = sp.Z > 0.1
                local pt = ok and v2(sp.X, sp.Y) or nil
                if s > 0 then
                    usedSegs += 1
                    local gl = auraDrawGlow[usedSegs]
                    if not gl then gl = poolGet("Line") pcall(function() gl.ZIndex = 2 end) auraDrawGlow[usedSegs] = gl end
                    local ln = auraDrawOuter[usedSegs]
                    if not ln then ln = poolGet("Line") pcall(function() ln.ZIndex = 3 end) auraDrawOuter[usedSegs] = ln end
                    if ok and prevOk then
                        local sc, sr = c1, c2
                        if not isCustom then sc, sr = styleColors(aura.Style, aura.Color, 1, f * 2.4 + strand * 0.8) end
                        local edgeAlpha = alpha * (0.35 + 0.65 * sin(f * math.pi))
                        gl.From, gl.To, gl.Color, gl.Thickness, gl.Transparency, gl.Visible = prevPt, pt, sr, 4.5, edgeAlpha * 0.25, true
                        ln.From, ln.To, ln.Color, ln.Thickness, ln.Transparency, ln.Visible = prevPt, pt, sc, 1.8, edgeAlpha, true
                    else
                        gl.Visible, ln.Visible = false, false
                    end
                end
                prevPt, prevOk = pt, ok
            end
        end
        for r = 1, 6 do
            local ln = auraDrawInner[r]
            if not ln then ln = poolGet("Line") pcall(function() ln.ZIndex = 3 end) auraDrawInner[r] = ln end
            local f = r / 7
            local y = -2.6 + f * 4.8
            local rad = radBase * (0.65 + 0.35 * sin(f * math.pi))
            local ang = auraAngle * 2.2 + f * (math.pi * 3.6)
            local s1 = cam:WorldToViewportPoint(bodyCenter + v3(cos(ang) * rad, y, sin(ang) * rad))
            local s2 = cam:WorldToViewportPoint(bodyCenter - v3(cos(ang) * rad, -y, sin(ang) * rad))
            if s1.Z > 0.1 and s2.Z > 0.1 then
                ln.From, ln.To, ln.Color, ln.Thickness, ln.Transparency, ln.Visible = v2(s1.X, s1.Y), v2(s2.X, s2.Y), c1:Lerp(c2, f), 1.1, alpha * 0.42 * sin(f * math.pi), true
            else
                ln.Visible = false
            end
        end
        usedInner = 6
        for n = 1, 4 do
            local nd = auraDrawNodes[n]
            if not nd then nd = poolGet("Circle") pcall(function() nd.ZIndex = 4 end) auraDrawNodes[n] = nd end
            local strand = (n <= 2) and 0 or 1
            local f = (n % 2 == 1) and 0.2 or 0.8
            local y = -2.6 + f * 4.8
            local rad = radBase * (0.65 + 0.35 * sin(f * math.pi))
            local ang = auraAngle * 2.2 + f * (math.pi * 3.6) + strand * math.pi
            local sp = cam:WorldToViewportPoint(bodyCenter + v3(cos(ang) * rad, y, sin(ang) * rad))
            if sp.Z > 0.1 then
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = v2(sp.X, sp.Y), 2.5, 10, true
                nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(strand == 0 and c1 or c2, 0.45), alpha * 0.9, true
            else
                nd.Visible = false
            end
        end
        usedNodes = 4
    elseif shape == "Crown" then
        local r = aura.Size * 0.94 * pulse
        for k = 0, 2 do
            local yaw = auraAngle * 0.85 + k * (math.pi / 3)
            local cf = cfNew(bodyCenter) * cfAng(0, yaw, math.pi * 0.5)
            drawRing(cam, cf, true, r, k * 0.5, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, k * C.RING_SEGMENTS, k % 2 == 0 and c1 or c2, c2, alpha * 0.86, 1.35)
            for m = 1, 2 do
                local nIdx = k * 2 + m
                local nd = auraDrawNodes[nIdx]
                if not nd then nd = poolGet("Circle") pcall(function() nd.ZIndex = 4 end) auraDrawNodes[nIdx] = nd end
                local na = auraAngle * 1.4 + (m == 1 and 0 or math.pi) + k * 0.7
                local sp = cam:WorldToViewportPoint(cf:PointToWorldSpace(v3(cos(na) * r, 0, sin(na) * r)))
                if sp.Z > 0.1 then
                    nd.Position, nd.Radius, nd.NumSides, nd.Filled = v2(sp.X, sp.Y), 2.5, 10, true
                    nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(k % 2 == 0 and c1 or c2, 0.4), alpha, true
                else
                    nd.Visible = false
                end
            end
        end
        usedSegs = C.RING_SEGMENTS * 3
        usedNodes = 6
        local step = (math.pi * 2) / C.RING_SEGMENTS
        local bandR = r * 0.84
        for i = 1, C.RING_SEGMENTS do
            local ln = auraDrawInner[i]
            if not ln then ln = poolGet("Line") pcall(function() ln.ZIndex = 3 end) auraDrawInner[i] = ln end
            if i % 3 ~= 0 then
                local a1 = -auraAngle * 1.1 + (i - 1) * step
                local a2 = a1 + step * 0.78
                local s1 = cam:WorldToViewportPoint(bodyCenter + v3(cos(a1) * bandR, -0.15, sin(a1) * bandR))
                local s2 = cam:WorldToViewportPoint(bodyCenter + v3(cos(a2) * bandR, -0.15, sin(a2) * bandR))
                if s1.Z > 0.1 and s2.Z > 0.1 then
                    ln.From, ln.To, ln.Color, ln.Thickness, ln.Transparency, ln.Visible = v2(s1.X, s1.Y), v2(s2.X, s2.Y), c2, 1.25, alpha * 0.65, true
                else
                    ln.Visible = false
                end
            else
                ln.Visible = false
            end
        end
        usedInner = C.RING_SEGMENTS
    elseif shape == "Sigil" then
        local gPos = rayGroundPos(char, root)
        local rOut = aura.Size * pulse
        local rIn = rOut * 0.78
        drawRing(cam, gPos, false, rOut, auraAngle * 0.5, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, 0, c1, c2, alpha, 1.6)
        drawRing(cam, gPos + v3(0, 0.04, 0), false, rIn, -auraAngle * 0.7, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, C.RING_SEGMENTS, c2, c1, alpha * 0.82, 1.2)
        usedSegs = C.RING_SEGMENTS * 2
        local starStep = (math.pi * 2) / 6
        local starR = rOut * 0.96
        for k = 1, 6 do
            local a1 = auraAngle * 0.55 + (k - 1) * starStep
            local a2 = a1 + starStep * 2
            local cx1, cz1 = cos(a1), sin(a1)
            local p1 = cam:WorldToViewportPoint(gPos + v3(cx1 * starR, 0.02, cz1 * starR))
            local p2 = cam:WorldToViewportPoint(gPos + v3(cos(a2) * starR, 0.02, sin(a2) * starR))
            usedSegs += 1
            local gl = auraDrawGlow[usedSegs]
            if not gl then gl = poolGet("Line") pcall(function() gl.ZIndex = 2 end) auraDrawGlow[usedSegs] = gl end
            local ln = auraDrawOuter[usedSegs]
            if not ln then ln = poolGet("Line") pcall(function() ln.ZIndex = 3 end) auraDrawOuter[usedSegs] = ln end
            if p1.Z > 0.1 and p2.Z > 0.1 then
                local vA, vB = v2(p1.X, p1.Y), v2(p2.X, p2.Y)
                gl.From, gl.To, gl.Color, gl.Thickness, gl.Transparency, gl.Visible = vA, vB, c2, 3.8, alpha * 0.25, true
                ln.From, ln.To, ln.Color, ln.Thickness, ln.Transparency, ln.Visible = vA, vB, c1:Lerp(c2, 0.45), 1.4, alpha * 0.88, true
            else
                gl.Visible, ln.Visible = false, false
            end
            local spOut = cam:WorldToViewportPoint(gPos + v3(cx1 * (rOut * 1.15), 0.02, cz1 * (rOut * 1.15)))
            local rLn = auraDrawInner[k]
            if not rLn then rLn = poolGet("Line") pcall(function() rLn.ZIndex = 3 end) auraDrawInner[k] = rLn end
            if p1.Z > 0.1 and spOut.Z > 0.1 then
                rLn.From, rLn.To, rLn.Color, rLn.Thickness, rLn.Transparency, rLn.Visible = v2(p1.X, p1.Y), v2(spOut.X, spOut.Y), c2, 1.25, alpha * 0.72, true
            else
                rLn.Visible = false
            end
            local nd = auraDrawNodes[k]
            if not nd then nd = poolGet("Circle") pcall(function() nd.ZIndex = 4 end) auraDrawNodes[k] = nd end
            if p1.Z > 0.1 then
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = v2(p1.X, p1.Y), 2.5, 10, true
                nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(c2, 0.4), alpha, true
            else
                nd.Visible = false
            end
        end
        usedInner = 6
        usedNodes = 6
    elseif shape == "Galaxy" then
        local r = aura.Size * pulse
        local cf1 = cfNew(bodyCenter) * cfAng(0.38, auraAngle * 0.65, 0.22)
        local cf2 = cfNew(bodyCenter) * cfAng(-0.32, -auraAngle * 1.1, -0.18)
        local cf3 = cfNew(bodyCenter) * cfAng(0.08, auraAngle * 1.4, -0.1)
        drawRing(cam, cf1, true, r * 1.18, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, 0, c1, c2, alpha * 0.92, 1.7)
        drawRing(cam, cf2, true, r * 0.78, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, C.RING_SEGMENTS, c2, c1, alpha * 0.85, 1.3)
        drawRing(cam, cf3, true, r * 0.96, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, C.RING_SEGMENTS * 2, c1:Lerp(c2, 0.5), c2, alpha * 0.65, 1.0)
        usedSegs = C.RING_SEGMENTS * 3
        for n = 1, 6 do
            local nd = auraDrawNodes[n]
            if not nd then nd = poolGet("Circle") pcall(function() nd.ZIndex = 4 end) auraDrawNodes[n] = nd end
            local ringCF = (n <= 3) and cf1 or cf2
            local rad = (n <= 3) and (r * 1.18) or (r * 0.78)
            local na = ((n - 1) % 3) * ((math.pi * 2) / 3)
            local sp = cam:WorldToViewportPoint(ringCF:PointToWorldSpace(v3(cos(na) * rad, 0, sin(na) * rad)))
            if sp.Z > 0.1 then
                local nodePulse = (sin(t * 3.4 + n * 0.9) + 1) * 0.5
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = v2(sp.X, sp.Y), ((n <= 3) and 2.5 or 2.0) + nodePulse * 0.75, 10, true
                nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(c2, 0.35), alpha, true
            else
                nd.Visible = false
            end
        end
        usedNodes = 6
    elseif shape == "Vortex" then
        local rBase = aura.Size * pulse
        for k = 0, 3 do
            local prog = ((t * 0.72 + k * 0.25) % 1)
            local yOff = -2.2 + prog * 4.2
            local rad = rBase * (0.38 + prog * 0.84)
            local fade = sin(prog * math.pi)
            local cf = cfNew(bodyCenter + v3(0, yOff, 0)) * cfAng(sin(t * 1.35 + k) * 0.15, auraAngle * (1.25 + k * 0.28), cos(t * 1.1 + k) * 0.08)
            drawRing(cam, cf, true, rad, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, k * C.RING_SEGMENTS, k % 2 == 0 and c1 or c2, c2, alpha * clamp(fade * 1.18, 0.12, 1), 1.45)
        end
        usedSegs = C.RING_SEGMENTS * 4
        for n = 1, 8 do
            local nd = auraDrawNodes[n]
            if not nd then nd = poolGet("Circle") pcall(function() nd.ZIndex = 4 end) auraDrawNodes[n] = nd end
            local prog = ((t * 0.72 + (n - 1) / 8) % 1)
            local yOff = -2.1 + prog * 4.0
            local rad = rBase * (0.42 + prog * 0.78)
            local na = auraAngle * 2.25 + n * 0.85
            local sp = cam:WorldToViewportPoint(bodyCenter + v3(cos(na) * rad, yOff, sin(na) * rad))
            if sp.Z > 0.1 then
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = v2(sp.X, sp.Y), 2.3 + sin(prog * math.pi) * 0.6, 10, true
                nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(n % 2 == 0 and c1 or c2, 0.35), alpha * sin(prog * math.pi), true
            else
                nd.Visible = false
            end
        end
        usedNodes = 8
    elseif shape == "Atom" then
        local r = aura.Size * 0.98 * pulse
        local tilt1 = cfNew(bodyCenter) * cfAng(0.68, auraAngle * 0.4, 0.25)
        local tilt2 = cfNew(bodyCenter) * cfAng(-0.68, -auraAngle * 0.4, 0.85)
        local tilt3 = cfNew(bodyCenter) * cfAng(0.18, auraAngle * 0.5, -0.95)
        drawRing(cam, tilt1, true, r, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, 0, c1, c2, alpha * 0.9, 1.45)
        drawRing(cam, tilt2, true, r, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, C.RING_SEGMENTS, c2, c1, alpha * 0.9, 1.45)
        drawRing(cam, tilt3, true, r, 0, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, C.RING_SEGMENTS * 2, c1:Lerp(c2, 0.5), c2, alpha * 0.85, 1.35)
        usedSegs = C.RING_SEGMENTS * 3
        for n = 1, 6 do
            local nd = auraDrawNodes[n]
            if not nd then nd = poolGet("Circle") pcall(function() nd.ZIndex = 4 end) auraDrawNodes[n] = nd end
            local orbitIdx = ((n - 1) % 3) + 1
            local ringCF = (orbitIdx == 1) and tilt1 or ((orbitIdx == 2) and tilt2 or tilt3)
            local na = auraAngle * 2.4 + (n > 3 and math.pi or 0) + orbitIdx * 1.1
            local sp = cam:WorldToViewportPoint(ringCF:PointToWorldSpace(v3(cos(na) * r, 0, sin(na) * r)))
            if sp.Z > 0.1 then
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = v2(sp.X, sp.Y), 3.0, 10, true
                nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(orbitIdx == 2 and c1 or c2, 0.35), alpha, true
            else
                nd.Visible = false
            end
        end
        usedNodes = 6
    else
        local gPos = rayGroundPos(char, root)
        local outerR = aura.Size * pulse
        drawRing(cam, gPos, false, outerR, auraAngle, C.RING_SEGMENTS, auraDrawGlow, auraDrawOuter, 0, c1, c2, alpha, 1.6)
        usedSegs = C.RING_SEGMENTS
        local step = (math.pi * 2) / C.RING_SEGMENTS
        local innerR = aura.Size * 0.62 * pulse
        for i = 1, C.RING_SEGMENTS do
            local ln = auraDrawInner[i]
            if not ln then ln = poolGet("Line") pcall(function() ln.ZIndex = 3 end) auraDrawInner[i] = ln end
            if i % 3 ~= 0 then
                local a1 = -auraAngle * 1.4 + (i - 1) * step
                local a2 = a1 + step * 0.78
                local s1 = cam:WorldToViewportPoint(gPos + v3(cos(a1) * innerR, 0, sin(a1) * innerR))
                local s2 = cam:WorldToViewportPoint(gPos + v3(cos(a2) * innerR, 0, sin(a2) * innerR))
                if s1.Z > 0.1 and s2.Z > 0.1 then
                    ln.From, ln.To, ln.Color, ln.Thickness, ln.Transparency, ln.Visible = v2(s1.X, s1.Y), v2(s2.X, s2.Y), c2, 1.2, alpha * 0.7, true
                else
                    ln.Visible = false
                end
            else
                local ta = auraAngle + (i - 1) * step
                local cx, cz = cos(ta), sin(ta)
                local s1 = cam:WorldToViewportPoint(gPos + v3(cx * (innerR * 0.94), 0, cz * (innerR * 0.94)))
                local s2 = cam:WorldToViewportPoint(gPos + v3(cx * (outerR * 0.98), 0, cz * (outerR * 0.98)))
                if s1.Z > 0.1 and s2.Z > 0.1 then
                    ln.From, ln.To, ln.Color, ln.Thickness, ln.Transparency, ln.Visible = v2(s1.X, s1.Y), v2(s2.X, s2.Y), c1:Lerp(c2, 0.5), 1.15, alpha * 0.55, true
                else
                    ln.Visible = false
                end
            end
        end
        usedInner = C.RING_SEGMENTS
        for n = 1, 4 do
            local nd = auraDrawNodes[n]
            if not nd then nd = poolGet("Circle") pcall(function() nd.ZIndex = 4 end) auraDrawNodes[n] = nd end
            local na = auraAngle + (n - 1) * (math.pi * 0.5)
            local sp = cam:WorldToViewportPoint(gPos + v3(cos(na) * outerR, 0, sin(na) * outerR))
            if sp.Z > 0.1 then
                nd.Position, nd.Radius, nd.NumSides, nd.Filled = v2(sp.X, sp.Y), 2.5, 10, true
                nd.Color, nd.Transparency, nd.Visible = WHITE:Lerp(c2, 0.4), alpha, true
            else
                nd.Visible = false
            end
        end
        usedNodes = 4
    end

    for k = usedSegs + 1, #auraDrawGlow do auraDrawGlow[k].Visible = false end
    for k = usedSegs + 1, #auraDrawOuter do auraDrawOuter[k].Visible = false end
    for k = usedInner + 1, #auraDrawInner do auraDrawInner[k].Visible = false end
    for k = usedNodes + 1, #auraDrawNodes do auraDrawNodes[k].Visible = false end

    if aura.Particles then
        ensureAuraParticles(root)
        auraEmitter.Enabled = true
        if not auraSeq or colorDelta(c1, auraSeqC1) > 0.015 or colorDelta(c2, auraSeqC2) > 0.015 then
            auraSeqC1, auraSeqC2 = c1, c2
            auraSeq = ColorSequence.new(c1, c2)
            auraEmitter.Color = auraSeq
        end
    elseif auraEmitter then
        auraEmitter.Enabled = false
    end

    if aura.GlowLight then
        ensureAuraLight(root)
        auraLight.Enabled = true
        auraLight.Color = c1
        auraLight.Range = clamp(aura.Size * 3.8, 6, 26)
        auraLight.Brightness = 1.6
    elseif auraLight then
        auraLight.Enabled = false
    end
end

local function updateLocalEffects(dt)
    local cam = workspace.CurrentCamera
    local char = LP and LP.Character
    local root = getRootPart(char)
    if not cam or not char or not char.Parent or not isPartValid(root) then
        if lastEffectCharacter then clearLocalEffects() end
        return
    end
    if lastEffectCharacter ~= char then
        clearLocalEffects()
        lastEffectCharacter = char
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")

    local aura = cfg().PlayerAura
    if aura.Enabled then
        updateAuraShape(cam, char, root, dt, aura)
    else
        hideRingDrawings()
        if auraEmitter then auraEmitter.Enabled = false end
        if auraLight then auraLight.Enabled = false end
    end

    local after = cfg().Afterimage
    local trail = cfg().ParticleTrail
    if trail.Enabled then
        local life = clamp(trail.Lifetime, 0.1, 2)
        local mode = trail.Mode or "Orbit"
        local pattern = trail.Pattern or "Smooth"
        local width = trail.Width or 0.14
        local withSparks = trail.Sparks == true
        ensureTrail(char, root, mode, pattern, width, life, withSparks)
        local spd = clamp(trail.Speed or 1.0, 0.25, 3.0)
        local c1, c2 = styleColors(trail.Style, trail.Color, spd)
        local seqChanged = not trailSeq or colorDelta(c1, trailSeqC1) > 0.015 or colorDelta(c2, trailSeqC2) > 0.015
        if seqChanged then
            trailSeqC1, trailSeqC2 = c1, c2
            trailSeq = ColorSequence.new(c1, c2)
        end
        if #trailOrbitPairs > 0 then
            local tNow = clock() * 3.4 * spd
            for k, pair in ipairs(trailOrbitPairs) do
                if pair.a0 and pair.a0.Parent and pair.a1 and pair.a1.Parent then
                    local ang, pos
                    if pair.kind == "Helix" then
                        ang = tNow * 1.35 + pair.phase
                        local rad = 1.45
                        local y = sin(tNow * 0.75 + pair.phase) * 2.2
                        pos = v3(cos(ang) * rad, y, sin(ang) * rad)
                    elseif pair.kind == "Halo" then
                        ang = tNow * 1.6 + pair.phase
                        local rad = 1.18
                        local y = 2.25 + sin(tNow * 1.2 + k) * 0.22
                        pos = v3(cos(ang) * rad, y, sin(ang) * rad)
                    else
                        ang = tNow + pair.phase
                        local rad = 2.15 + sin(tNow * 0.7 + k) * 0.3
                        local tilt = (k == 1) and 0.45 or ((k == 2) and -0.45 or 0.15)
                        local y = sin(ang) * sin(tilt) * rad + cos(tNow * 0.8 + k) * 0.55
                        pos = v3(cos(ang) * rad, y, sin(ang) * rad)
                    end
                    local wOff = v3(-cos(ang) * pair.hw * 0.4, pair.hw, -sin(ang) * pair.hw * 0.4)
                    pair.a0.Position = pos + wOff
                    pair.a1.Position = pos - wOff
                end
            end
        end
        for _, tr in ipairs(trailObjects) do
            if tr.Lifetime ~= life then tr.Lifetime = life end
            if seqChanged or not tr.Enabled then tr.Color = trailSeq end
            if not tr.Enabled then tr.Enabled = true end
        end
        for _, em in ipairs(trailEmitters) do
            if seqChanged or not em.Enabled then em.Color = trailSeq end
            if not em.Enabled then em.Enabled = true end
        end
    elseif #trailObjects > 0 then
        clearTrail()
    end

    if after.Enabled then
        local alive = not humanoid or humanoid.Health > 0
        if alive then
            local vel = root.AssemblyLinearVelocity or root.Velocity
            local spd = vel.Magnitude
            local minSpd = clamp(after.MinSpeed or 4, 0, 50)
            local mode = after.TriggerMode or "Moving"
            local shouldSpawn = false
            if mode == "Always" then
                shouldSpawn = true
            elseif mode == "Dash/Air" then
                local airborne = humanoid and humanoid.FloorMaterial == Enum.Material.Air
                shouldSpawn = airborne or (spd >= math.max(minSpd, 20))
            else
                shouldSpawn = (minSpd > 0 and spd >= minSpd)
                    or (minSpd == 0 and (spd > 0.6 or (humanoid and humanoid.MoveDirection.Magnitude > 0.05)))
            end
            local nowAfter = clock()
            if shouldSpawn and nowAfter - lastAfterimage >= clamp(after.Interval, 0.03, 0.8) then
                lastAfterimage = nowAfter
                makeAfterimage(char)
            end
        end
        updateAfterimages(cam, root)
    elseif #afterimages > 0 or #afterArcLines > 0 then
        clearAfterimages()
    end

    updateChinaHat(cam, char)
    updateJumpRings(cam, char, root, humanoid)

    local sat = cfg().Satellites
    if sat.Enabled and (not humanoid or humanoid.Health > 0) then
        local cnt = clamp(floor(sat.Count or 3), 1, 6)
        local shape = sat.Shape or "Crystal"
        local sz = clamp(sat.Size or 0.45, 0.2, 1.2)
        local withTrails = sat.Trails ~= false
        local needBuild = (#satItems ~= cnt or satShapeCur ~= shape or satTrailsCur ~= withTrails or abs(satSizeCur - sz) > 0.005)
        if not needBuild then
            for _, item in ipairs(satItems) do
                if not item.part or not item.part.Parent then needBuild = true break end
            end
        end
        local rootPos = partPos(root)
        if needBuild then
            clearSatellites()
            satShapeCur, satCountCur, satTrailsCur, satSizeCur = shape, cnt, withTrails, sz
            local par = workspace.CurrentCamera or workspace
            for i = 1, cnt do
                local p = Instance.new("Part")
                p.Name, p.Anchored, p.CastShadow, p.Massless = "GlupostSatellite", true, false, true
                p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
                p.Material, p.Transparency = Enum.Material.Neon, 0.14
                if shape == "Orb" then
                    p.Shape, p.Size = Enum.PartType.Ball, v3(sz, sz, sz)
                elseif shape == "Blade" then
                    p.Shape, p.Size = Enum.PartType.Block, v3(sz * 0.28, sz * 0.2, sz * 1.85)
                elseif shape == "Shard" then
                    p.Shape, p.Size = Enum.PartType.Block, v3(sz * 0.34, sz * 1.65, sz * 0.34)
                elseif shape == "Disc" then
                    p.Shape, p.Size = Enum.PartType.Block, v3(sz * 1.45, sz * 0.16, sz * 1.45)
                else
                    p.Shape, p.Size = Enum.PartType.Block, v3(sz * 0.62, sz * 1.12, sz * 0.62)
                end
                local sb = nil
                if shape == "Crystal" or shape == "Shard" or shape == "Disc" or shape == "Blade" then
                    sb = Instance.new("SelectionBox")
                    sb.Name, sb.Adornee = "GlupostSatBox", p
                    sb.LineThickness = (shape == "Blade") and 0.014 or clamp(sz * 0.04, 0.015, 0.032)
                    sb.Transparency = (shape == "Blade") and 0.32 or 0.14
                    sb.SurfaceTransparency = (shape == "Blade") and 0.93 or 0.84
                    sb.Parent = p
                end
                local tr = nil
                if withTrails then
                    local a0 = Instance.new("Attachment")
                    a0.Name, a0.Position, a0.Parent = "GlupostSatA", v3(0, sz * 0.24, 0), p
                    local a1 = Instance.new("Attachment")
                    a1.Name, a1.Position, a1.Parent = "GlupostSatB", v3(0, -sz * 0.24, 0), p
                    tr = Instance.new("Trail")
                    tr.Name, tr.Attachment0, tr.Attachment1 = "GlupostSatTrail", a0, a1
                    tr.FaceCamera, tr.LightEmission, tr.MinLength, tr.Lifetime = true, 1, 0.02, 0.40
                    tr.WidthScale = numSeq({ { 0, 1.1 }, { 0.45, 0.65 }, { 1, 0 } })
                    tr.Transparency = numSeq({ { 0, 0.14 }, { 0.7, 0.55 }, { 1, 1 } })
                    tr.Parent = p
                end
                p.CFrame = cfNew(rootPos)
                p.Parent = par
                satItems[i] = {
                    part = p, box = sb, trail = tr,
                    phase = (i - 1) * ((math.pi * 2) / cnt),
                    tilt = ((i % 2 == 0) and 1 or -1) * (0.28 + (i % 3) * 0.12),
                }
            end
        end
        local spd = clamp(sat.Speed or 1.4, 0.2, 4.0)
        local radBase = clamp(sat.Radius or 3.2, 1.2, 8.0)
        local hOff = clamp(sat.Height or 0.8, -3.0, 5.0)
        local tNow = clock()
        for _, item in ipairs(satItems) do
            local ang = tNow * spd * 1.85 + item.phase
            local r = radBase + sin(tNow * 2.1 + item.phase) * 0.22
            local oy = hOff + sin(ang + item.phase) * r * sin(item.tilt) + cos(tNow * 2.6 + item.phase) * 0.2
            local pos = rootPos + v3(cos(ang) * r, oy, sin(ang) * r)
            local c1, c2 = styleColors(sat.Style, sat.Color, spd, item.phase * 0.6)
            local shimmer = (sin(tNow * 3.4 + item.phase) + 1) * 0.5
            item.part.Color = (shape == "Orb") and c1:Lerp(c2, shimmer * 0.45) or c1
            item.part.Transparency = 0.08 + shimmer * 0.12
            if shape == "Blade" then
                local tx, tz = -sin(ang), cos(ang)
                item.part.CFrame = cfNew(pos, pos + v3(tx, cos(ang + item.phase) * sin(item.tilt) * 0.6, tz)) * cfAng(0, 0, item.tilt * 0.75)
            elseif shape == "Crystal" then
                item.part.CFrame = cfNew(pos) * cfAng(0.65 + tNow * 0.85, ang * 1.35, 0.78)
            elseif shape == "Shard" then
                item.part.CFrame = cfNew(pos) * cfAng(0.35, ang * 2.2, tNow * 2.1)
            elseif shape == "Disc" then
                item.part.CFrame = cfNew(pos) * cfAng(0.24, ang * 2.8, item.tilt)
            else
                item.part.CFrame = cfNew(pos)
            end
            if item.box then
                item.box.Color3, item.box.SurfaceColor3 = c2, c1
            end
            if item.trail and (not item.cs or colorDelta(c1, item.c1) > 0.015 or colorDelta(c2, item.c2) > 0.015) then
                item.c1, item.c2 = c1, c2
                item.cs = ColorSequence.new(c1, c2)
                item.trail.Color = item.cs
            end
        end
    elseif #satItems > 0 then
        clearSatellites()
    end
end

local function syncVMHighlights(cam, e, fill, outline, ft, ot)
    if not e.IncludeViewmodel and next(selfVmHighlights) == nil then return end
    table.clear(vmActiveMap)
    if e.IncludeViewmodel and cam then
        for _, vm in ipairs(cam:GetChildren()) do
            if vm:IsA("Model") and vm.Name ~= "GlupostSandevistanGhost" then
                vmActiveMap[vm] = true
                local hl = selfVmHighlights[vm]
                if not hl or hl.Parent ~= vm then
                    if hl then safeDestroy(hl) end
                    hl = Instance.new("Highlight")
                    hl.Name = "GlupostSelfVMVisual"
                    hl.Adornee = vm
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = vm
                    selfVmHighlights[vm] = hl
                end
                if not hl.Enabled then hl.Enabled = true end
                if hl.FillColor ~= fill then hl.FillColor = fill end
                if hl.OutlineColor ~= outline then hl.OutlineColor = outline end
                if hl.FillTransparency ~= ft then hl.FillTransparency = ft end
                if hl.OutlineTransparency ~= ot then hl.OutlineTransparency = ot end
            end
        end
    end
    for vm, hl in pairs(selfVmHighlights) do
        if not vmActiveMap[vm] or not vm.Parent then
            safeDestroy(hl)
            selfVmHighlights[vm] = nil
        end
    end
end

local function applySelfPartMaterial(p, mat, col, tr, refl)
    if not isPartValid(p) or p.Name == "HumanoidRootPart" then return end
    if scSavedParts[p] == nil then
        if p.Transparency >= 0.98 then return end
        local tex = nil
        if p:IsA("MeshPart") then
            pcall(function() tex = p.TextureID end)
        end
        scSavedParts[p] = {
            mat = p.Material, col = p.Color, tr = p.Transparency,
            refl = p.Reflectance, cast = p.CastShadow, tex = tex,
        }
        scHasSaved = true
    end
    scSeenParts[p] = true
    if p.Material ~= mat then p.Material = mat end
    if p.Color ~= col then p.Color = col end
    if math.abs(p.Transparency - tr) > 0.005 then p.Transparency = tr end
    if math.abs(p.Reflectance - refl) > 0.005 then p.Reflectance = refl end
    if p.CastShadow ~= false then p.CastShadow = false end
    if p:IsA("MeshPart") and p.TextureID ~= "" then
        pcall(function() p.TextureID = "" end)
    end
    for _, child in ipairs(p:GetChildren()) do
        if child:IsA("Decal") or child:IsA("Texture") then
            if scSavedDecals[child] == nil then
                scSavedDecals[child] = child.Transparency
                scHasSaved = true
            end
            scSeenDecals[child] = true
            if child.Transparency ~= 1 then child.Transparency = 1 end
        elseif child:IsA("SpecialMesh") then
            if scSavedMeshes[child] == nil then
                scSavedMeshes[child] = { tex = child.TextureId, vc = child.VertexColor }
                scHasSaved = true
            end
            scSeenMeshes[child] = true
            if child.TextureId ~= "" or child.VertexColor ~= VEC3_ONE then
                pcall(function()
                    child.TextureId = ""
                    child.VertexColor = VEC3_ONE
                end)
            end
        elseif child:IsA("SurfaceAppearance") then
            scSavedSurf[child] = p
            scSeenSurf[child] = true
            scHasSaved = true
            pcall(function() child.Parent = nil end)
        end
    end
end

local function applySelfMaterials(char, cam, e, isGlass, fill)
    local now = clock()
    local phase = now * math.max(e.AnimationSpeed, 0.05)
    local mat = isGlass and Enum.Material.Glass or Enum.Material.ForceField
    local tr = isGlass and clamp(e.FillTransparency, 0.25, 0.92) or clamp(e.FillTransparency, 0.05, 0.85)
    local refl = isGlass and (0.26 + 0.1 * math.sin(phase * 1.25)) or 0

    if scLastChar ~= char then
        clearScCharConns()
        scLastChar = char
        scForceScan = true
        scChildConn = char.ChildAdded:Connect(function() scForceScan = true end)
        scChildRemConn = char.ChildRemoved:Connect(function() scForceScan = true end)
    end

    local scanInterval = e.IncludeViewmodel and 0.14 or 0.25
    local needScan = scForceScan
        or (now - scLastScan >= scanInterval)
        or scLastStyle ~= e.Style
        or scLastTools ~= e.IncludeTools
        or scLastVM ~= e.IncludeViewmodel

    if not needScan then
        for p in pairs(scSavedParts) do
            if not p or not p.Parent then
                scSavedParts[p] = nil
                scForceScan = true
            else
                if p.Material ~= mat then p.Material = mat end
                if p.Color ~= fill then p.Color = fill end
                if math.abs(p.Transparency - tr) > 0.005 then p.Transparency = tr end
                if math.abs(p.Reflectance - refl) > 0.005 then p.Reflectance = refl end
                if p.CastShadow ~= false then p.CastShadow = false end
            end
        end
        return
    end

    scForceScan = false
    scLastScan = now
    scLastStyle, scLastTools, scLastVM = e.Style, e.IncludeTools, e.IncludeViewmodel

    table.clear(scSeenParts)
    table.clear(scSeenDecals)
    table.clear(scSeenClothes)
    table.clear(scSeenMeshes)
    table.clear(scSeenSurf)

    local CLOTH_PROPS = { Shirt = "ShirtTemplate", Pants = "PantsTemplate", ShirtGraphic = "Graphic" }
    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("BasePart") then
            applySelfPartMaterial(inst, mat, fill, tr, refl)
        elseif inst:IsA("Accessory") or (e.IncludeTools and inst:IsA("Tool")) then
            for _, sub in ipairs(inst:GetDescendants()) do
                if sub:IsA("BasePart") then applySelfPartMaterial(sub, mat, fill, tr, refl) end
            end
        else
            local cProp = CLOTH_PROPS[inst.ClassName]
            if cProp then
                if scSavedClothes[inst] == nil then
                    scSavedClothes[inst] = { prop = cProp, val = inst[cProp] }
                    scHasSaved = true
                end
                scSeenClothes[inst] = true
                if inst[cProp] ~= "" then pcall(function() inst[cProp] = "" end) end
            end
        end
    end

    if e.IncludeViewmodel and cam then
        for _, ch in ipairs(cam:GetChildren()) do
            if ch:IsA("Model") and ch.Name ~= "GlupostSandevistanGhost" then
                for _, sub in ipairs(ch:GetDescendants()) do
                    if sub:IsA("BasePart") then applySelfPartMaterial(sub, mat, fill, tr, refl) end
                end
            elseif ch:IsA("BasePart") and ch.Name ~= "GlupostWeatherPart" then
                applySelfPartMaterial(ch, mat, fill, tr, refl)
            end
        end
    end

    for p, orig in pairs(scSavedParts) do
        if not scSeenParts[p] then
            restoreSinglePart(p, orig)
            scSavedParts[p] = nil
        end
    end
    for d, origTr in pairs(scSavedDecals) do
        if not scSeenDecals[d] then
            if d and d.Parent then pcall(function() d.Transparency = origTr end) end
            scSavedDecals[d] = nil
        end
    end
    for obj, orig in pairs(scSavedClothes) do
        if not scSeenClothes[obj] then
            if obj and obj.Parent then pcall(function() obj[orig.prop] = orig.val end) end
            scSavedClothes[obj] = nil
        end
    end
    for m, orig in pairs(scSavedMeshes) do
        if not scSeenMeshes[m] then
            if m and m.Parent then
                pcall(function()
                    m.TextureId = orig.tex
                    m.VertexColor = orig.vc
                end)
            end
            scSavedMeshes[m] = nil
        end
    end
    for sa, origParent in pairs(scSavedSurf) do
        if not scSeenSurf[sa] and not scSeenParts[origParent] then
            if origParent and origParent.Parent then
                pcall(function() sa.Parent = origParent end)
            else
                safeDestroy(sa)
            end
            scSavedSurf[sa] = nil
        end
    end
    scHasSaved = next(scSavedParts) ~= nil
        or next(scSavedDecals) ~= nil
        or next(scSavedClothes) ~= nil
        or next(scSavedMeshes) ~= nil
        or next(scSavedSurf) ~= nil
end

local function updateSelfChams()
    local e = cfg().SelfChams
    local char = LP and LP.Character
    if not e.Enabled or not char or not char.Parent then
        if selfChamsHighlight or scHasSaved or next(selfVmHighlights) ~= nil then
            destroySelfChams()
        end
        return
    end

    local cam = workspace.CurrentCamera
    local isGlass = (e.Style == "Liquid Glass" or e.Style == "Glass")
    local isForceField = (e.Style == "ForceField")
    local useMat = isGlass or isForceField

    if selfChamsCharacter ~= char then
        destroySelfChams()
    end

    if not selfChamsHighlight or selfChamsCharacter ~= char or selfChamsHighlight.Parent ~= char then
        if selfChamsHighlight then safeDestroy(selfChamsHighlight) end
        local hl = Instance.new("Highlight")
        hl.Name = "GlupostSelfVisual"
        hl.Adornee = char
        hl.DepthMode = Enum.HighlightDepthMode.Occluded
        hl.Parent = char
        selfChamsHighlight, selfChamsCharacter = hl, char
    end

    local now = clock()
    local fill, outline = selfChamsColor(now)
    if useMat then
        applySelfMaterials(char, cam, e, isGlass, fill)
    elseif scHasSaved then
        clearScCharConns()
        scForceScan = true
        restoreSelfMaterials()
    end

    local phase = now * math.max(e.AnimationSpeed, 0.05)
    local ft = useMat and (isGlass and 0.90 or 0.93)
        or (e.Style == "Energy Rim" and clamp(0.72 + e.FillTransparency * 0.28, 0.72, 1)
        or (e.Style == "Scanline" and clamp(e.FillTransparency + sin(phase * 4.2) * 0.14, 0.05, 0.95)
        or (e.Style == "Pulse" and clamp(e.FillTransparency + sin(phase * 2.2) * 0.10, 0.05, 0.95)
        or clamp(e.FillTransparency, 0, 1))))
    local ot = (e.Style == "Energy Rim")
        and clamp(e.OutlineTransparency - (sin(phase * 2.6) + 1) * 0.08, 0, 1)
        or clamp(e.OutlineTransparency, 0, 1)
    if not selfChamsHighlight.Enabled then selfChamsHighlight.Enabled = true end
    if selfChamsHighlight.FillColor ~= fill then selfChamsHighlight.FillColor = fill end
    if selfChamsHighlight.OutlineColor ~= outline then selfChamsHighlight.OutlineColor = outline end
    if selfChamsHighlight.FillTransparency ~= ft then selfChamsHighlight.FillTransparency = ft end
    if selfChamsHighlight.OutlineTransparency ~= ot then selfChamsHighlight.OutlineTransparency = ot end

    syncVMHighlights(cam, e, fill, outline, ft, ot)
end

return {
    updateSelfChams = updateSelfChams, destroySelfChams = destroySelfChams,
    updateLocalEffects = updateLocalEffects, clearLocalEffects = clearLocalEffects,
    drawWorldRing = drawWorldRing,
}
end)()

local function getChar(plr)
    if Module.CustomCharacter then
        local ok, ch = pcall(Module.CustomCharacter, plr)
        if ok and ch then return ch end
    end
    return plr.Character
end

local function isTeammate(plr)
    if plr == LP then return false end
    if LP.Team and plr.Team and LP.Team == plr.Team then return true end
    if not LP.Neutral and not plr.Neutral and LP.TeamColor == plr.TeamColor then return true end
    local a, b = LP:GetAttribute("Team"), plr:GetAttribute("Team")
    if a and b and a == b then return true end
    local la, lb = LP:FindFirstChild("leaderstats"), plr:FindFirstChild("leaderstats")
    if la and lb then
        local ta, tb = la:FindFirstChild("Team"), lb:FindFirstChild("Team")
        if ta and tb and ta:IsA("ValueBase") and tb:IsA("ValueBase") and ta.Value == tb.Value then return true end
    end
    return false
end

local function newPlayerData()
    return { parts = {}, visible = false, lastVis = 0, drawings = {}, highlight = nil, _lastHP = nil }
end

local function hideAll(pd)
    if not pd then return end
    local dr = pd.drawings
    if dr then
        for k in pairs(KEYCLS) do
            local t = dr[k]
            if t then for _, o in pairs(t) do o.Visible = false end end
        end
    end
    if pd.highlight and pd.highlight.Enabled then pd.highlight.Enabled = false end
end

local function hideESP(pd)
    if not pd then return end
    local dr = pd.drawings
    if dr then
        for k in pairs(KEYCLS) do
            if k ~= "radar" and k ~= "radarbg" and k ~= "radarlook" and k ~= "radarprio" then
                local t = dr[k]
                if t then for _, o in pairs(t) do o.Visible = false end end
            end
        end
    end
    if pd.highlight and pd.highlight.Enabled then pd.highlight.Enabled = false end
end

local function destroyAll(pd)
    if not pd then return end
    local dr = pd.drawings
    if dr then
        for k, cls in pairs(KEYCLS) do
            local t = dr[k]
            if t then
                for _, o in pairs(t) do poolPut(cls, o) end
                dr[k] = nil
            end
        end
    end
    if pd.highlight then safeDestroy(pd.highlight) pd.highlight = nil end
end

local function pick(char, ...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        local p = char:FindFirstChild(name)
        if p then return p end
    end
    return nil
end

local function cacheParts(plr, char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local parts = {
        _player = plr, Character = char,
        humanoid = hum,
        Head = char:FindFirstChild("Head"),
        HumanoidRootPart = getRootPart(char),
        Torso = pick(char, "Torso", "UpperTorso"),
        LowerTorso = char:FindFirstChild("LowerTorso"),
        LeftArm = pick(char, "LeftArm", "LeftUpperArm"),
        LeftLowerArm = char:FindFirstChild("LeftLowerArm"),
        LeftHand = char:FindFirstChild("LeftHand"),
        RightArm = pick(char, "RightArm", "RightUpperArm"),
        RightLowerArm = char:FindFirstChild("RightLowerArm"),
        RightHand = char:FindFirstChild("RightHand"),
        LeftLeg = pick(char, "LeftLeg", "LeftUpperLeg"),
        LeftLowerLeg = char:FindFirstChild("LeftLowerLeg"),
        LeftFoot = char:FindFirstChild("LeftFoot"),
        RightLeg = pick(char, "RightLeg", "RightUpperLeg"),
        RightLowerLeg = char:FindFirstChild("RightLowerLeg"),
        RightFoot = char:FindFirstChild("RightFoot"),
    }
    local d = playersData[plr]
    if d then
        d.parts = parts
        d._lastHP = hum and hum.Health or nil
    else
        playersData[plr] = newPlayerData()
        playersData[plr].parts = parts
        playersData[plr]._lastHP = hum and hum.Health or nil
    end
end

local function syncChams(plr, d, rd, allowCham)
    local char = d.parts and d.parts.Character
    if not char or not char.Parent then
        if d.highlight and d.highlight.Enabled then d.highlight.Enabled = false end
        return
    end
    local e = cfg().ESP
    if e.Enabled and e.Chams and allowCham ~= false then
        local isVis = (rd and rd.visible) or d.visible or false
        local fill = isVis and e.Colors.ChamsVis or e.Colors.ChamsOcc
        local outline = fill:Lerp(BLACK, 0.45)
        local tr = e.ChamsTransparency
        local otr = e.ChamsOutlineTransparency or 0
        if not d.highlight or d.highlight.Parent ~= char then
            if d.highlight then safeDestroy(d.highlight) end
            local hl = Instance.new("Highlight")
            hl.Name = HttpSvc:GenerateGUID(false)
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = char
            hl.FillColor, hl.OutlineColor = fill, outline
            hl.FillTransparency = tr
            hl.OutlineTransparency = otr
            hl.Parent = char
            d.highlight = hl
        else
            if not d.highlight.Enabled then d.highlight.Enabled = true end
            if d.highlight.FillColor ~= fill then d.highlight.FillColor = fill end
            if d.highlight.OutlineColor ~= outline then d.highlight.OutlineColor = outline end
            if d.highlight.FillTransparency ~= tr then d.highlight.FillTransparency = tr end
            if d.highlight.OutlineTransparency ~= otr then d.highlight.OutlineTransparency = otr end
        end
    elseif d.highlight and d.highlight.Enabled then
        d.highlight.Enabled = false
    end
end

local function setupPlayer(plr)
    if plr == LP then return end
    if playersData[plr] then destroyAll(playersData[plr]) end
    if connections[plr] then for _, c in pairs(connections[plr]) do safeDestroy(c) end end

    playersData[plr] = newPlayerData()
    connections[plr] = {}
    renderData[plr] = nil

    connections[plr].added = plr.CharacterAdded:Connect(function(char)
        task.spawn(function()
            char:WaitForChild(Module.RootPartName or "HumanoidRootPart", 5)
            char:WaitForChild("Head", 5)
            if isUnloaded or not char.Parent then return end
            local d = playersData[plr]
            if not d then return end
            if d.highlight then safeDestroy(d.highlight) d.highlight = nil end
            cacheParts(plr, Module.CustomCharacter and getChar(plr) or char)
        end)
    end)

    connections[plr].removing = plr.CharacterRemoving:Connect(function()
        local d = playersData[plr]
        if d then
            if d.highlight then safeDestroy(d.highlight) d.highlight = nil end
            d._lastHP = nil
            hideAll(d)
        end
        renderData[plr] = nil
    end)

    local ch0 = getChar(plr)
    if ch0 then cacheParts(plr, ch0) end
end

local function refreshModuleChars()
    if not Module.CustomCharacter then return end
    local now = clock()
    if now - ticks.mod < 0.5 then return end
    ticks.mod = now
    for plr, d in pairs(playersData) do
        local ch = getChar(plr)
        if ch and (not d.parts or d.parts.Character ~= ch) then cacheParts(plr, ch) end
    end
end

local softIgnore, lastSoftClear, lastSoftPrune = {}, 0, 0

local function pruneSoftIgnore()
    for i = #softIgnore, 1, -1 do
        local inst = softIgnore[i]
        if not inst or not inst.Parent or (inst.Transparency < 0.3 and inst.CanCollide) then
            table.remove(softIgnore, i)
        end
    end
end

local function buildVisIgnore()
    table.clear(visIgnore)
    local cam = workspace.CurrentCamera
    if cam then visIgnore[#visIgnore + 1] = cam end
    if LP.Character then visIgnore[#visIgnore + 1] = LP.Character end
    for i = 1, #softIgnore do visIgnore[#visIgnore + 1] = softIgnore[i] end
    visParams.FilterDescendantsInstances = visIgnore
end

local function castVisible(origin, delta, part)
    local smart = cfg().ESP.SmartVisCheck
    local now = clock()
    if now - lastSoftClear > 5 then
        table.clear(softIgnore)
        lastSoftClear = now
        lastSoftPrune = now
    elseif #softIgnore > 0 and now - lastSoftPrune >= 0.2 then
        lastSoftPrune = now
        pruneSoftIgnore()
    end
    buildVisIgnore()
    for _ = 1, (smart and 6 or 1) do
        local res = rawRay(origin, delta, visParams)
        if not res then return true end
        local hit = res.Instance
        if hit:IsDescendantOf(part.Parent) then return true end
        if not smart or hit:IsA("Terrain") then return false end
        if hit.Transparency >= 0.3 or not hit.CanCollide then
            if #softIgnore < 64 then softIgnore[#softIgnore + 1] = hit end
            visIgnore[#visIgnore + 1] = hit
            visParams.FilterDescendantsInstances = visIgnore
        else
            return false
        end
    end
    local res = rawRay(origin, delta, visParams)
    return res == nil or res.Instance:IsDescendantOf(part.Parent)
end

local function isVisibleCached(d, part)
    if not d then return false end
    local now = clock()
    if now - d.lastVis < C.VIS_INTERVAL then return d.visible end
    d.lastVis = now
    if not isPartValid(part) then d.visible = false return false end

    local delta = part.Position - cameraPos
    local mag = delta.Magnitude
    if mag < 0.001 then d.visible = true return true end
    if mag > 14500 then d.visible = false return false end

    d.visible = castVisible(cameraPos, delta, part)
    return d.visible
end

local function threatScore(plr, parts, d)
    if not d or not parts then return -1000 end
    local hum = parts.humanoid
    if not hum or hum.Health <= 0 then return -1000 end
    local head = parts.Head
    if not isPartValid(head) then return -1000 end

    local myRoot = getRootPart(LP.Character)
    local myPos = myRoot and myRoot.Position or cameraPos
    local dist = (myPos - head.Position).Magnitude
    local vis = isVisibleCached(d, head) and 1 or 0
    local look = 0
    if myRoot then
        local toMe = myRoot.Position - head.Position
        if toMe.Magnitude > 0.001 then
            look = (head.CFrame.LookVector:Dot(toMe.Unit) + 1) / 2
        end
    end

    local e = cfg().ESP
    local normDist = e.UnlimitedDistance and 50000 or math.max(e.MaxDistance, 1)
    local w = cfg().ThreatWeights
    return vis * w.Visibility
        + look * w.LookAtMe
        + (1 - clamp(dist / normDist, 0, 1)) * w.Distance
        + (1 - hum.Health / math.max(hum.MaxHealth, 1)) * w.Health
end

local function boxColor(rd)
    local e = cfg().ESP
    if e.Enabled and rd.priority then return e.Colors.Priority end
    if e.Rainbow then return rainbow end
    if e.TeamColors and rd.teamColor then return rd.teamColor end
    if e.Enabled and e.VisibleCheck then return rd.visible and e.Colors.Visible or e.Colors.Occluded end
    return rd.team and e.Colors.Ally or e.Colors.Enemy
end

local DYN_NAMES = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
    "LeftHand", "RightHand", "LeftFoot", "RightFoot" }

local ESPDraw = (function()
local function ensure(d, key, n)
    local t = d[key]
    if not t then
        t = {}
        d[key] = t
    end
    for i = #t + 1, n do
        t[i] = newObj(key)
    end
    return t
end

local function hideKey(d, key)
    local t = d[key]
    if t then for _, o in pairs(t) do o.Visible = false end end
end

local BOX_KEYS = { "lines", "corners", "lines3dbg", "lines3d", "outline", "fill" }
local ARROW_KEYS = { "arrows", "arrowbg", "arrowtri", "arrowglow" }
local RADAR_KEYS = { "radarbg", "radar", "radarlook", "radarprio" }

local function hideList(d, list)
    for i = 1, #list do hideKey(d, list[i]) end
end

local function hideRadar(d) hideList(d, RADAR_KEYS) end

local function hideBox(d, rd)
    hideList(d, BOX_KEYS)
    rd.bL, rd.bR, rd.bT, rd.bB, rd.bH = nil, nil, nil, nil, nil
end

local EDGES_3D = { {1,2},{3,4},{1,3},{2,4},{5,6},{7,8},{5,7},{6,8},{1,5},{2,6},{3,7},{4,8} }
local screen3D = {}

local function segment(bt, i, l, t, r, b, len, pad)
    pad = pad or 0
    if bt == "2D" then
        if i == 1 then return l - pad, t, r + pad, t
        elseif i == 2 then return r, t - pad, r, b + pad
        elseif i == 3 then return r + pad, b, l - pad, b
        else return l, b + pad, l, t - pad end
    elseif bt == "Bracket" then
        if i == 1 then return l, t - pad, l, b + pad
        elseif i == 2 then return r, t - pad, r, b + pad
        elseif i == 3 then return l - pad, t, l + len, t
        elseif i == 4 then return r + pad, t, r - len, t
        elseif i == 5 then return l - pad, b, l + len, b
        else return r + pad, b, r - len, b end
    end
    if i == 1 then return l - pad, t, l + len, t
    elseif i == 2 then return l, t - pad, l, t + len
    elseif i == 3 then return r + pad, t, r - len, t
    elseif i == 4 then return r, t - pad, r, t + len
    elseif i == 5 then return l - pad, b, l + len, b
    elseif i == 6 then return l, b + pad, l, b - len
    elseif i == 7 then return r + pad, b, r - len, b
    else return r, b + pad, r, b - len end
end

local function drawBox(d, parts, rd)
    local e = cfg().ESP
    if not rd.onScreen or not rd.headScreen or not rd.legScreen or not rd.hrpScreen then
        hideBox(d, rd)
        return
    end

    local top, bottom, left, right
    if rd.dynL then
        top, bottom, left, right = rd.dynT, rd.dynB, rd.dynL, rd.dynR
    else
        top, bottom = rd.headScreen.Y, rd.legScreen.Y
    end
    local h = math.abs(bottom - top)
    if h < 0.1 then hideBox(d, rd) return end

    local w
    if rd.dynL then
        w = right - left
    else
        w = h * 0.58
        left, right = rd.hrpScreen.X - w / 2, rd.hrpScreen.X + w / 2
    end

    local lod = e.AdaptiveLOD
    if h < 4 then
        local cx, cy = rd.hrpScreen.X, rd.hrpScreen.Y
        h, w = 4, 4
        left, right, top, bottom = cx - 2, cx + 2, cy - 2, cy + 2
    end
    rd.bL, rd.bR, rd.bT, rd.bB, rd.bH = left, right, top, bottom, h

    local thick = e.BoxThickness + ((rd.priority and (not lod or h >= 26)) and 1 or 0)
    if lod then
        if h < 20 then thick = 1
        elseif h < 36 then thick = min(thick, 2) end
    end

    local col = boxColor(rd)
    local alpha = rd.alpha
    local bt = e.BoxType
    if lod then
        if (bt == "Corner" or bt == "Bracket") and h < 16 then bt = "2D"
        elseif bt == "3D" and h < 22 then bt = "2D" end
    end

    if e.BoxFill and bt ~= "3D" and (not lod or h >= 6) then
        local F = ensure(d, "fill", 1)[1]
        F.Position, F.Size = v2(left, top), v2(w, h)
        F.Filled, F.Color = true, col
        F.Transparency, F.Visible = e.FillOpacity * alpha, true
    else
        hideKey(d, "fill")
    end

    if bt == "2D" or bt == "Corner" or bt == "Bracket" then
        hideKey(d, "lines3d")
        hideKey(d, "lines3dbg")
        local main, other, n = "lines", "corners", 4
        if bt == "Corner" then main, other, n = "corners", "lines", 8
        elseif bt == "Bracket" then main, other, n = "corners", "lines", 6 end
        hideKey(d, other)
        local len = bt == "Bracket" and clamp(w * 0.28, 3, 12) or min(14, h * 0.24)

        if e.Outline and (not lod or h >= 18) then
            local O = ensure(d, "outline", n)
            for i = n + 1, #O do O[i].Visible = false end
            for i = 1, n do
                local x1, y1, x2, y2 = segment(bt, i, left, top, right, bottom, len, 1)
                local o = O[i]
                o.From, o.To = v2(x1, y1), v2(x2, y2)
                o.Color, o.Thickness, o.Transparency, o.Visible = BLACK, thick + 2, alpha, true
            end
        else
            hideKey(d, "outline")
        end

        local L = ensure(d, main, n)
        for i = n + 1, #L do L[i].Visible = false end
        for i = 1, n do
            local x1, y1, x2, y2 = segment(bt, i, left, top, right, bottom, len, 0)
            local o = L[i]
            o.From, o.To = v2(x1, y1), v2(x2, y2)
            o.Color, o.Thickness, o.Transparency, o.Visible = col, thick, alpha, true
        end
    else
        hideKey(d, "lines") hideKey(d, "corners") hideKey(d, "outline")
        local hrp, head = parts.HumanoidRootPart, parts.Head
        if not (isPartValid(hrp) and isPartValid(head)) then
            hideKey(d, "lines3d") hideKey(d, "lines3dbg") return
        end
        local size, cf = hrp.Size, partCF(hrp)
        local minX, maxX, minY, maxY, minZ, maxZ

        if e.BoxFit == "Dynamic" then
            minX, minY, minZ = math.huge, math.huge, math.huge
            maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
            for i = 1, #DYN_NAMES do
                local p = parts[DYN_NAMES[i]]
                if isPartValid(p) then
                    local rel = cf:ToObjectSpace(partCF(p))
                    local ps = p.Size
                    local px, py, pz = ps.X / 2, ps.Y / 2, ps.Z / 2
                    for sx = -1, 1, 2 do
                        for sy = -1, 1, 2 do
                            for sz = -1, 1, 2 do
                                local lp = rel:PointToWorldSpace(v3(px * sx, py * sy, pz * sz))
                                if lp.X < minX then minX = lp.X end
                                if lp.X > maxX then maxX = lp.X end
                                if lp.Y < minY then minY = lp.Y end
                                if lp.Y > maxY then maxY = lp.Y end
                                if lp.Z < minZ then minZ = lp.Z end
                                if lp.Z > maxZ then maxZ = lp.Z end
                            end
                        end
                    end
                end
            end
        end

        if not minX or minX == math.huge then
            minX, maxX = -size.X * 0.9, size.X * 0.9
            minY, maxY = -size.Y * 1.45, size.Y * 0.5 + head.Size.Y
            minZ, maxZ = -size.Z * 0.85, size.Z * 0.85
        end

        local cam = workspace.CurrentCamera
        if not cam then hideKey(d, "lines3d") hideKey(d, "lines3dbg") return end
        local idx3 = 0
        for iy = 1, 2 do
            local cy = (iy == 1) and maxY or minY
            for ix = 1, 2 do
                local cx = (ix == 1) and minX or maxX
                for iz = 1, 2 do
                    idx3 += 1
                    local cz = (iz == 1) and minZ or maxZ
                    local sp = cam:WorldToViewportPoint(cf:PointToWorldSpace(v3(cx, cy, cz)))
                    screen3D[idx3] = (sp.Z > 0.1) and v2(sp.X, sp.Y) or nil
                end
            end
        end
        local useOut = e.Outline and (not lod or h >= 24)
        local BG = useOut and ensure(d, "lines3dbg", 12) or nil
        if not useOut then hideKey(d, "lines3dbg") end
        local L = ensure(d, "lines3d", 12)
        for i = 1, 12 do
            local ed = EDGES_3D[i]
            local a, b = screen3D[ed[1]], screen3D[ed[2]]
            if a and b then
                if BG then
                    BG[i].From, BG[i].To = a, b
                    BG[i].Color, BG[i].Thickness, BG[i].Transparency, BG[i].Visible = BLACK, thick + 2, alpha, true
                end
                L[i].From, L[i].To = a, b
                L[i].Color, L[i].Thickness, L[i].Transparency, L[i].Visible = col, thick, alpha, true
            else
                if BG then BG[i].Visible = false end
                L[i].Visible = false
            end
        end
    end
end

local function drawHealthBar(d, parts, rd, dt)
    local e = cfg().ESP
    local hum = parts.humanoid
    local h = rd.bH or 0
    if not e.HealthBar or not hum or not rd.bL or (e.AdaptiveLOD and h < 14) then
        hideKey(d, "hpbg") hideKey(d, "hptrail") hideKey(d, "hpfill") return
    end
    local targetP = clamp(hum.Health / max(hum.MaxHealth, 1), 0, 1)
    if rd._hpSmooth == nil then rd._hpSmooth = targetP end
    if rd._hpTrail == nil then rd._hpTrail = targetP end

    local step = clamp((dt or 0.016) * 14, 0, 1)
    rd._hpSmooth = rd._hpSmooth + (targetP - rd._hpSmooth) * step
    if abs(targetP - rd._hpSmooth) < 0.002 then rd._hpSmooth = targetP end

    if rd._hpTrail < rd._hpSmooth then
        rd._hpTrail = rd._hpSmooth
    else
        local trailStep = clamp((dt or 0.016) * 3.2, 0, 1)
        rd._hpTrail = rd._hpTrail + (rd._hpSmooth - rd._hpTrail) * trailStep
    end

    local thin = e.AdaptiveLOD and h < 28
    local barW = thin and 2 or 3
    local x = floor(rd.bL - barW - 4 + 0.5)
    local top = floor(rd.bT + 0.5)
    local bottom = floor(rd.bB + 0.5)
    local barH = max(2, bottom - top)

    local BG = ensure(d, "hpbg", 1)[1]
    BG.Position, BG.Size = v2(x - 1, top - 1), v2(barW + 2, barH + 2)
    BG.Filled, BG.Color, BG.Transparency, BG.Visible = true, BLACK, rd.alpha * 0.88, true

    if e.HealthTrail and rd._hpTrail > rd._hpSmooth + 0.005 then
        local trH = max(1, floor(barH * rd._hpTrail + 0.5))
        local TR = ensure(d, "hptrail", 1)[1]
        TR.Position, TR.Size = v2(x, bottom - trH), v2(barW, trH)
        TR.Filled, TR.Color, TR.Transparency, TR.Visible = true, WHITE, rd.alpha * 0.85, true
    else
        hideKey(d, "hptrail")
    end

    local fillH = max(1, floor(barH * rd._hpSmooth + 0.5))
    local F = ensure(d, "hpfill", 1)[1]
    F.Position, F.Size = v2(x, bottom - fillH), v2(barW, fillH)
    F.Filled, F.Color, F.Transparency, F.Visible = true, healthColor(rd._hpSmooth), rd.alpha, true
end

local function drawHeadDot(d, parts, rd)
    local e = cfg().ESP
    if not e.HeadDot or not rd.headDotScreen or not rd.headDotR or (e.AdaptiveLOD and (rd.bH or 0) < 16) then
        hideKey(d, "headdot") hideKey(d, "headdotring")
        return
    end
    local col = boxColor(rd)
    local c = ensure(d, "headdot", 1)[1]
    c.Position = rd.headDotScreen
    c.Radius, c.NumSides, c.Filled, c.Thickness = rd.headDotR, 20, e.HeadDotFilled, 1.5
    c.Color, c.Transparency, c.Visible = col, rd.alpha, true
    if rd.priority then
        local r = ensure(d, "headdotring", 1)[1]
        local pulse = 1 + sin(clock() * 6.5) * 0.22
        r.Position = rd.headDotScreen
        r.Radius, r.NumSides, r.Filled, r.Thickness = rd.headDotR * (1.85 * pulse), 20, false, 1.3
        r.Color, r.Transparency, r.Visible = WHITE:Lerp(col, 0.4), rd.alpha * 0.85, true
    else
        hideKey(d, "headdotring")
    end
end

local function drawLook(d, parts, rd)
    local e = cfg().ESP
    local head = parts.Head
    if not e.LookLine or not rd.onScreen or not isPartValid(head) or (e.AdaptiveLOD and (rd.bH or 0) < 16) then
        hideKey(d, "look") hideKey(d, "lookdot")
        return
    end
    local cam = workspace.CurrentCamera
    local p1 = partPos(head)
    local lookVec = partCF(head).LookVector
    local dir = lookVec * e.LookLength
    local p2 = p1 + dir

    if e.LookRaycast then
        tclear(visIgnore)
        visIgnore[1] = parts.Character
        visIgnore[2] = cam
        visParams.FilterDescendantsInstances = visIgnore
        local res = rawRay(p1, dir, visParams)
        if res then p2 = res.Position end
    end

    local a = cam:WorldToViewportPoint(p1)
    local b = cam:WorldToViewportPoint(p2)
    if a.Z <= 0.1 or b.Z <= 0.1 then hideKey(d, "look") hideKey(d, "lookdot") return end

    local toMe = cameraPos - p1
    local lookingAtMe = toMe.Magnitude > 0.5 and lookVec:Dot(toMe.Unit) >= 0.94
    local col = lookingAtMe and (e.Colors.LookAlert or HP_RED) or e.Colors.Look

    local L = ensure(d, "look", 1)[1]
    L.From, L.To = v2(a.X, a.Y), v2(b.X, b.Y)
    L.Color, L.Thickness, L.Transparency, L.Visible = col, lookingAtMe and 2 or 1.5, rd.alpha * 0.92, true

    local dot = ensure(d, "lookdot", 1)[1]
    dot.Position, dot.Radius, dot.NumSides, dot.Filled = v2(b.X, b.Y), lookingAtMe and 3.5 or 2.5, 10, true
    dot.Color, dot.Transparency, dot.Visible = col, rd.alpha, true
end

local SKEL = {
    R15 = {
        { "Head", "Torso" }, { "Torso", "HumanoidRootPart" },
        { "Torso", "LeftArm" }, { "Torso", "RightArm" },
        { "LeftArm", "LeftLowerArm" }, { "RightArm", "RightLowerArm" },
        { "LeftLowerArm", "LeftHand" }, { "RightLowerArm", "RightHand" },
        { "Torso", "LeftLeg" }, { "Torso", "RightLeg" },
        { "LeftLeg", "LeftLowerLeg" }, { "RightLeg", "RightLowerLeg" },
        { "LeftLowerLeg", "LeftFoot" }, { "RightLowerLeg", "RightFoot" },
    },
    R6 = {
        { "Head", "Torso" }, { "Torso", "HumanoidRootPart" },
        { "Torso", "LeftArm" }, { "Torso", "RightArm" },
        { "Torso", "LeftLeg" }, { "Torso", "RightLeg" },
    },
}

local function projSkel(cam, p)
    if not isPartValid(p) then return nil end
    local s = cam:WorldToViewportPoint(partPos(p))
    return s.Z > 0.1 and v2(s.X, s.Y) or nil
end

local function drawSkeleton(d, parts, rd)
    local e = cfg().ESP
    local h = rd.bH or 0
    if not e.Skeleton or not rd.onScreen or (e.AdaptiveLOD and h < 22) then
        hideKey(d, "skeleton") hideKey(d, "skeletonbg")
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then hideKey(d, "skeleton") hideKey(d, "skeletonbg") return end
    local set = parts.LowerTorso and SKEL.R15 or SKEL.R6
    local col = rd.priority and e.Colors.Priority or (e.Rainbow and rainbow or e.Colors.Skeleton)
    local skThick = (e.AdaptiveLOD and h < 45) and 1 or e.SkeletonThickness
    local useOut = e.SkeletonOutline and (not e.AdaptiveLOD or h >= 30)

    local S = ensure(d, "skeleton", #set)
    for i = #set + 1, #S do S[i].Visible = false end
    local SB = useOut and ensure(d, "skeletonbg", #set) or nil
    if SB then
        for i = #set + 1, #SB do SB[i].Visible = false end
    else
        hideKey(d, "skeletonbg")
    end

    for i = 1, #set do
        local pair = set[i]
        local a, b = projSkel(cam, parts[pair[1]]), projSkel(cam, parts[pair[2]])
        local line, bg = S[i], SB and SB[i] or nil
        if a and b then
            if bg then
                bg.From, bg.To = a, b
                bg.Color, bg.Thickness, bg.Transparency, bg.Visible = BLACK, skThick + 2, rd.alpha * 0.75, true
            end
            line.From, line.To = a, b
            line.Color, line.Thickness, line.Transparency, line.Visible = col, skThick, rd.alpha, true
        else
            if bg then bg.Visible = false end
            line.Visible = false
        end
    end
end

local function showEspText(T, key, sz, text, color, y, font, alpha, outline, cx)
    local t = T[key]
    if not t then
        t = newObj("texts")
        t.Center, t.OutlineColor = true, BLACK
        T[key] = t
    end
    t.Size, t.Font, t.Transparency, t.Outline = sz, font, alpha, outline
    t.Position = v2(cx, floor(y + 0.5))
    t.Text, t.Color, t.Visible = text, color, true
end

local function drawText(d, parts, rd, doText)
    local e = cfg().ESP
    local hum = parts.humanoid
    if not rd.onScreen or not hum or hum.Health <= 0 or not rd.bL then hideKey(d, "texts") return end

    d.texts = d.texts or {}
    local T = d.texts
    local col = boxColor(rd)
    local cx = floor((rd.bL + rd.bR) / 2 + 0.5)
    local h = rd.bH or 0
    local lod = e.AdaptiveLOD

    local size = e.TextSize
    if lod then
        if h < 16 then size = max(10, size - 2)
        elseif h < 28 then size = max(11, size - 1) end
    end
    local subSize = max(10, size - 1)
    local font = FONTS[e.FontName] or 2
    local alpha = rd.alpha

    if doText or not rd._txtReady then
        rd._txtReady = true
        if e.ShowName then
            local name = (rd.priority and "★ " or "") .. parts._player.DisplayName
            if Module.PlayerTag then
                local okT, tag = pcall(Module.PlayerTag, parts._player)
                if okT and tag then name = name .. " " .. tostring(tag) end
            end
            if e.ShowThreatScore then
                name = string.format("%s (%d%%)", name,
                    max(0, floor(threatScore(parts._player, parts, playersData[parts._player]) * 100)))
            end
            rd._nameStr = name
        else
            rd._nameStr = nil
        end

        if e.ShowHealth then
            local p = clamp(hum.Health / max(hum.MaxHealth, 1), 0, 1)
            rd._hpStr = healthText(e.HealthFormat, hum.Health, hum.MaxHealth)
            rd._hpCol = healthColor(p)
        else
            rd._hpStr = nil
        end

        rd._distStr = e.ShowDistance and string.format("%d st", floor(rd.distance)) or nil

        if e.ShowTool then
            local tool = parts.Character and parts.Character:FindFirstChildOfClass("Tool")
            rd._toolStr = tool and ("[" .. tool.Name .. "]") or nil
        else
            rd._toolStr = nil
        end

        if e.ShowState then
            if hum.Sit then
                rd._stateStr, rd._stateCol = "[СИДИТ]", rgb(255, 200, 100)
            elseif hum.FloorMaterial == Enum.Material.Air then
                rd._stateStr, rd._stateCol = "[ПРЫЖОК]", rgb(130, 225, 255)
            else
                local hrp = parts.HumanoidRootPart
                local vel = isPartValid(hrp) and (hrp.AssemblyLinearVelocity or hrp.Velocity)
                if vel and (vel.X * vel.X + vel.Z * vel.Z) > 324 then
                    rd._stateStr, rd._stateCol = "[БЕГ]", rgb(145, 255, 175)
                else
                    rd._stateStr = nil
                end
            end
        else
            rd._stateStr = nil
        end
    end

    local showHP = rd._hpStr and (not lod or h >= 18)
    local showDist = rd._distStr and (not lod or h >= 12 or not rd._nameStr)
    local showTool = rd._toolStr and (not lod or h >= 24)
    local showState = rd._stateStr and (not lod or h >= 26)
    local outline = e.TextOutline

    local yt = rd.bT - size - 5 - e.NameYOffset
    if rd._nameStr then
        showEspText(T, "name", size, rd._nameStr, col, yt, font, alpha, outline, cx)
    elseif T.name then T.name.Visible = false end

    local yb = rd.bB + 3
    if showHP then
        showEspText(T, "hp", subSize, rd._hpStr, rd._hpCol, yb, font, alpha, outline, cx)
        yb += subSize + 2
    elseif T.hp then T.hp.Visible = false end

    if showDist then
        showEspText(T, "dist", subSize, rd._distStr, GRAY, yb, font, alpha, outline, cx)
        yb += subSize + 2
    elseif T.dist then T.dist.Visible = false end

    if showTool then
        showEspText(T, "tool", subSize, rd._toolStr, TOOL_COLOR, yb, font, alpha, outline, cx)
        yb += subSize + 2
    elseif T.tool then T.tool.Visible = false end

    if showState then
        showEspText(T, "state", subSize, rd._stateStr, rd._stateCol, yb, font, alpha, outline, cx)
    elseif T.state then T.state.Visible = false end
end

local function drawTracer(d, rd)
    local e = cfg().ESP
    if not e.ShowTracer or not rd.onScreen or not rd.hrpScreen then
        hideKey(d, "tracer") hideKey(d, "tracerbg") return
    end
    local vp = workspace.CurrentCamera.ViewportSize
    local from
    if e.TracerOrigin == "Mouse" then from = UIS:GetMouseLocation()
    elseif e.TracerOrigin == "Center" then from = v2(vp.X / 2, vp.Y / 2)
    elseif e.TracerOrigin == "Top" then from = v2(vp.X / 2, 0)
    else from = v2(vp.X / 2, vp.Y) end
    local to = v2(rd.hrpScreen.X, rd.bB or (rd.legScreen and rd.legScreen.Y) or rd.hrpScreen.Y)
    local normDist = e.UnlimitedDistance and 50000 or max(e.MaxDistance, 1)
    local a = e.TracerFade and clamp(1 - rd.distance / max(normDist * 0.6, 1), 0.25, 0.9) or rd.alpha

    if e.TracerOutline then
        local B = ensure(d, "tracerbg", 1)[1]
        B.From, B.To = from, to
        B.Color, B.Thickness, B.Transparency, B.Visible = BLACK, e.TracerThickness + 2, a * 0.8, true
    else
        hideKey(d, "tracerbg")
    end

    local T = ensure(d, "tracer", 1)[1]
    T.From, T.To = from, to
    T.Color = rd.priority and e.Colors.Priority or (e.Rainbow and rainbow or e.Colors.Tracer)
    T.Thickness, T.Transparency, T.Visible = e.TracerThickness, a, true
end

local function drawArrow(d, rd)
    local e = cfg().ESP
    local hrp = rd.parts and rd.parts.HumanoidRootPart
    if not e.OffscreenArrows or rd.onScreen or not isPartValid(hrp) then
        hideList(d, ARROW_KEYS) return
    end
    local delta = partPos(hrp) - cameraPos
    if delta.Magnitude < 0.01 then hideList(d, ARROW_KEYS) return end
    local dir3 = delta.Unit
    local dir2 = v2(cameraCF.RightVector:Dot(dir3), -cameraCF.UpVector:Dot(dir3))
    if dir2.Magnitude < 0.001 then hideList(d, ARROW_KEYS) return end
    local dir = dir2.Unit

    local vp = workspace.CurrentCamera.ViewportSize
    local base = vp / 2 + dir * (min(vp.X, vp.Y) * 0.4)
    base = v2(clamp(base.X, e.ArrowSize + 6, vp.X - e.ArrowSize - 6),
              clamp(base.Y, e.ArrowSize + 6, vp.Y - e.ArrowSize - 6))

    local pulse = rd.priority and (1 + sin(clock() * 6.5) * 0.14) or 1
    local len = e.ArrowSize * pulse
    local tip, back = base + dir * (len * 0.65), base - dir * (len * 0.45)
    local perp = v2(-dir.Y, dir.X) * (len * 0.48)
    local col = rd.priority and e.Colors.Priority or (e.Rainbow and rainbow or e.Colors.Arrow)

    if hasTriangle then
        hideKey(d, "arrows")
        local bg = ensure(d, "arrowbg", 1)[1]
        local bPerp = v2(-dir.Y, dir.X) * (len * 0.48 + 2.5)
        bg.PointA, bg.PointB, bg.PointC = tip + dir * 2.5, (back - dir * 1.5) + bPerp, (back - dir * 1.5) - bPerp
        bg.Filled, bg.Color, bg.Transparency, bg.Visible = true, BLACK, rd.alpha * 0.85, true

        local tri = ensure(d, "arrowtri", 1)[1]
        tri.PointA, tri.PointB, tri.PointC = tip, back + perp, back - perp
        tri.Filled, tri.Color, tri.Transparency, tri.Visible = true, col, rd.alpha, true

        local gl = ensure(d, "arrowglow", 2)
        local glCol = WHITE:Lerp(col, 0.35)
        gl[1].From, gl[1].To = tip, back + perp
        gl[2].From, gl[2].To = tip, back - perp
        for _, g in ipairs(gl) do
            g.Color, g.Thickness, g.Transparency, g.Visible = glCol, 1.4, rd.alpha * 0.9, true
        end
    else
        hideKey(d, "arrowglow")
        local A = ensure(d, "arrows", 3)
        A[1].From, A[1].To = tip, back + perp
        A[2].From, A[2].To = tip, back - perp
        A[3].From, A[3].To = back + perp, back - perp
        for _, a in ipairs(A) do
            a.Thickness, a.Color, a.Transparency, a.Visible = 2, col, rd.alpha, true
        end
    end
end

local prioPtsIn, prioPtsOut = {}, {}
local function drawPriorityMarker(d, parts, rd)
    local e = cfg().ESP
    local hrp = parts and parts.HumanoidRootPart
    if not (e.PriorityTarget and e.PriorityMarker and rd.priority and rd.onScreen and isPartValid(hrp)) or (e.AdaptiveLOD and (rd.bH or 0) < 18) then
        hideKey(d, "priomark") hideKey(d, "priomarkbg")
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then hideKey(d, "priomark") hideKey(d, "priomarkbg") return end
    local t = clock()
    local ang, rad = t * 2.1, 2.35 + sin(t * 5.0) * 0.22
    local base = partPos(hrp) - v3(0, max(2.3, hrp.Size.Y * 1.3), 0)
    for k = 1, 4 do
        local a = ang + (k - 1) * (math.pi * 0.5)
        local ca, sa = cos(a), sin(a)
        local s1 = cam:WorldToViewportPoint(base + v3(ca * rad, 0, sa * rad))
        local s2 = cam:WorldToViewportPoint(base + v3(ca * (rad + 0.85), 0, sa * (rad + 0.85)))
        prioPtsIn[k] = (s1.Z > 0.1) and v2(s1.X, s1.Y) or nil
        prioPtsOut[k] = (s2.Z > 0.1) and v2(s2.X, s2.Y) or nil
    end
    local col = e.Colors.Priority
    local BG = ensure(d, "priomarkbg", 8)
    local LN = ensure(d, "priomark", 8)
    for k = 1, 4 do
        local j = (k % 4) + 1
        local p1, p2, po = prioPtsIn[k], prioPtsIn[j], prioPtsOut[k]
        if p1 and p2 then
            BG[k].From, BG[k].To, BG[k].Color, BG[k].Thickness, BG[k].Transparency, BG[k].Visible = p1, p2, BLACK, 3.5, rd.alpha * 0.7, true
            LN[k].From, LN[k].To, LN[k].Color, LN[k].Thickness, LN[k].Transparency, LN[k].Visible = p1, p2, col, 1.5, rd.alpha, true
        else
            BG[k].Visible, LN[k].Visible = false, false
        end
        local tk = 4 + k
        if p1 and po then
            BG[tk].From, BG[tk].To, BG[tk].Color, BG[tk].Thickness, BG[tk].Transparency, BG[tk].Visible = p1, po, BLACK, 3.5, rd.alpha * 0.7, true
            LN[tk].From, LN[tk].To, LN[tk].Color, LN[tk].Thickness, LN[tk].Transparency, LN[tk].Visible = p1, po, WHITE, 1.5, rd.alpha, true
        else
            BG[tk].Visible, LN[tk].Visible = false, false
        end
    end
end

return {
    ensure = ensure, hideKey = hideKey, hideRadar = hideRadar,
    drawBox = drawBox, drawHealthBar = drawHealthBar, drawHeadDot = drawHeadDot,
    drawLook = drawLook, drawSkeleton = drawSkeleton, drawText = drawText,
    drawTracer = drawTracer, drawArrow = drawArrow, drawPriorityMarker = drawPriorityMarker,
}
end)()

local damagePopups = {}
local killBursts = {}
local hitmarkerState = { born = -99, isKill = false, killFlashBorn = -99 }

local function spawnKillBurst(pos, col)
    while #killBursts >= 6 do
        local old = table.remove(killBursts, 1)
        for _, o in ipairs(old.lines) do poolPut("Line", o) end
    end
    local dirs, lines = {}, {}
    for s = 1, 10 do
        local phi = (s - 1) * 0.6283 + (math.random() - 0.5) * 0.35
        local vy = -0.35 + math.random() * 1.35
        local v = v3(math.cos(phi), vy, math.sin(phi)).Unit
        dirs[s] = v
        local ln = poolGet("Line")
        pcall(function() ln.ZIndex = 7 end)
        lines[s] = ln
    end
    for r = 1, 12 do
        local ln = poolGet("Line")
        pcall(function() ln.ZIndex = 6 end)
        lines[10 + r] = ln
    end
    table.insert(killBursts, {
        pos = pos,
        col = col,
        born = clock(),
        life = 0.58,
        dirs = dirs,
        lines = lines,
    })
end

local function trackDamagePopup(plr, d, parts)
    local hum = parts and parts.humanoid
    local head = parts and parts.Head
    if not hum or not isPartValid(head) then
        if d then d._lastHP = nil end
        return
    end
    local cur = hum.Health
    local wantDmg = cfg().ESP.DamageNumbers
    local wantHit = cfg().Hitmarker.Enabled or cfg().Hitmarker.KillEffect or cfg().Vignette.KillFlash
    if not wantDmg and not wantHit then
        d._lastHP = cur
        return
    end
    if d._lastHP and d._lastHP > 0 and (cur < d._lastHP - 0.5 or cur <= 0) then
        local dmg = math.floor(d._lastHP - cur + 0.5)
        if wantDmg and dmg > 0 then
            if #damagePopups >= C.MAX_DMG_POPUPS then
                local old = table.remove(damagePopups, 1)
                poolPut("Text", old.text)
            end
            local isCrit = dmg >= 35
            local t = poolGet("Text")
            pcall(function() t.ZIndex = 7 end)
            t.Center, t.Outline, t.OutlineColor = true, true, BLACK
            t.Font = FONTS[cfg().ESP.FontName] or 2
            local baseSz = cfg().ESP.TextSize + (isCrit and 5 or 2)
            t.Size = baseSz
            local jx = (math.random() - 0.5) * 1.4
            local jz = (math.random() - 0.5) * 1.4
            table.insert(damagePopups, {
                worldPos = partPos(head) + Vector3.new(jx, 1.3, jz),
                vx = (math.random() - 0.5) * 1.8,
                vz = (math.random() - 0.5) * 1.8,
                isCrit = isCrit,
                baseSize = baseSz,
                str = isCrit and ("-" .. tostring(dmg) .. "!") or ("-" .. tostring(dmg)),
                born = clock(),
                life = isCrit and 1.2 or 1.05,
                text = t,
            })
        end
        if wantHit then
            local delta = partPos(head) - cameraPos
            local dist = delta.Magnitude
            local rd = renderData[plr]
            local aimed = dist > 0.1 and dist <= 650 and cameraCF.LookVector:Dot(delta.Unit) >= 0.88
            if aimed or (rd and rd.priority) then
                local now = clock()
                if cfg().Hitmarker.Enabled then
                    hitmarkerState.born = now
                    hitmarkerState.isKill = (cur <= 0)
                end
                if cfg().Vignette.KillFlash and cur <= 0 then
                    hitmarkerState.killFlashBorn = now
                end
                if cfg().Hitmarker.KillEffect and cur <= 0 then
                    spawnKillBurst(partPos(head), cfg().Hitmarker.KillColor)
                end
            end
        end
    end
    d._lastHP = cur
end

local function destroyDamagePopups()
    for _, p in ipairs(damagePopups) do
        poolPut("Text", p.text)
    end
    table.clear(damagePopups)
    for _, kb in ipairs(killBursts) do
        for _, o in ipairs(kb.lines) do poolPut("Line", o) end
    end
    table.clear(killBursts)
end

local function updateKillBursts()
    if #killBursts == 0 then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local now, ringStep = clock(), (math.pi * 2) / 12
    for i = #killBursts, 1, -1 do
        local kb = killBursts[i]
        local elapsed = now - kb.born
        if elapsed >= kb.life then
            for _, o in ipairs(kb.lines) do poolPut("Line", o) end
            tremove(killBursts, i)
        else
            local prog = elapsed / kb.life
            local ease = 1 - (1 - prog) * (1 - prog)
            local alpha = 1 - prog
            local flashCol = WHITE:Lerp(kb.col, clamp(prog * 2.6, 0, 1))
            local rayTh = 2.8 - prog * 1.4
            local ringTh = 2.2 - prog * 0.9
            local r0 = 0.4 + ease * 3.2
            local r1 = r0 + 1.75 * (1 - prog * 0.45)
            for s = 1, 10 do
                local dir = kb.dirs[s]
                local a = cam:WorldToViewportPoint(kb.pos + dir * r0)
                local b = cam:WorldToViewportPoint(kb.pos + dir * r1)
                local ln = kb.lines[s]
                if a.Z > 0.1 and b.Z > 0.1 then
                    ln.From, ln.To = v2(a.X, a.Y), v2(b.X, b.Y)
                    ln.Color, ln.Thickness, ln.Transparency, ln.Visible = flashCol, rayTh, alpha, true
                else
                    ln.Visible = false
                end
            end
            local ringR, ringCol = 0.6 + ease * 4.5, WHITE:Lerp(kb.col, clamp(0.25 + prog * 0.75, 0, 1))
            local prevPt, prevOk, firstPt, firstOk = nil, false, nil, false
            for r = 0, 11 do
                local ang = prog * 1.65 + r * ringStep
                local sp = cam:WorldToViewportPoint(kb.pos + v3(cos(ang) * ringR, sin(ang) * ringR * 0.24, sin(ang) * ringR))
                local ok = sp.Z > 0.1
                local pt = ok and v2(sp.X, sp.Y) or nil
                if r == 0 then
                    firstPt, firstOk = pt, ok
                else
                    local ln = kb.lines[10 + r]
                    if ok and prevOk then
                        ln.From, ln.To, ln.Color, ln.Thickness, ln.Transparency, ln.Visible = prevPt, pt, ringCol, ringTh, alpha * 0.88, true
                    else
                        ln.Visible = false
                    end
                end
                prevPt, prevOk = pt, ok
            end
            local lastLn = kb.lines[22]
            if prevOk and firstOk then
                lastLn.From, lastLn.To, lastLn.Color, lastLn.Thickness, lastLn.Transparency, lastLn.Visible = prevPt, firstPt, ringCol, ringTh, alpha * 0.88, true
            else
                lastLn.Visible = false
            end
        end
    end
end

local function updateDamagePopups()
    updateKillBursts()
    if #damagePopups == 0 then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local now, col, showDmg = clock(), cfg().ESP.Colors.Damage, cfg().ESP.DamageNumbers
    for i = #damagePopups, 1, -1 do
        local p = damagePopups[i]
        local elapsed = now - p.born
        if elapsed >= p.life or not showDmg then
            poolPut("Text", p.text)
            tremove(damagePopups, i)
        else
            local prog = elapsed / p.life
            local sp = cam:WorldToViewportPoint(p.worldPos + v3(p.vx * elapsed, elapsed * 2.4 - elapsed * elapsed * 0.75, p.vz * elapsed))
            if sp.Z > 0.1 then
                local t = p.text
                t.Text = p.str
                t.Color = p.isCrit and rgb(255, 215, 70):Lerp(col, 0.35) or col
                t.Size = p.baseSize
                t.Position = v2(floor(sp.X + 0.5), floor(sp.Y + 0.5))
                t.Transparency, t.Visible = 1 - prog * prog, true
            else
                p.text.Visible = false
            end
        end
    end
end

local overlayObjs = {}
local ovState = { rd = false, xh = false, wm = false, la = false, th = false, kb = false, hm = false, sp = false, vg = false, sl = false }

local function ov(name, cls, z)
    local o = overlayObjs[name]
    if not o then
        o = Drawing.new(cls)
        overlayObjs[name] = o
        if z then pcall(function() o.ZIndex = z end) end
    end
    return o
end

local function hideGroup(prefix)
    for name, o in pairs(overlayObjs) do
        if name:sub(1, #prefix) == prefix then o.Visible = false end
    end
end

local radarCX, radarCY = 0, 0
local radarFwd, radarRight = Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
local radarReady = false

local function updateRadarFrame()
    local R = cfg().Radar
    local O = cfg().Overlay
    if not R.Enabled then
        if ovState.rd then hideGroup("rd") ovState.rd = false end
        radarReady = false
        hudState.rects.radar = nil
        return
    end
    ovState.rd = true

    local vp = workspace.CurrentCamera.ViewportSize
    local half = R.Size / 2
    local m = 18
    local cx, cy
    if R.PosX and R.PosX >= 0 and R.PosY and R.PosY >= 0 then
        cx = clamp(R.PosX, half + 6, vp.X - half - 6)
        cy = clamp(R.PosY, half + 6, vp.Y - half - 6)
    elseif R.Position == "TopLeft" then
        local topY = 14 + (O.Watermark and 34 or 0) + ((O.Keybinds and hudState.kbHeight > 0) and (hudState.kbHeight + 8) or 0)
        cx, cy = m + half, math.min(topY + half, vp.Y - half - 8)
    elseif R.Position == "TopRight" then cx, cy = vp.X - m - half, 60 + half
    elseif R.Position == "BottomRight" then cx, cy = vp.X - m - half, vp.Y - m - half
    else cx, cy = m + half, vp.Y - m - half end
    radarCX, radarCY = cx, cy
    setHudRect("radar", cx - half, cy - half, R.Size, R.Size)

    local look = cameraCF.LookVector
    local f = v3(look.X, 0, look.Z)
    if f.Magnitude < 0.01 then f = v3(0, 0, -1) end
    radarFwd = f.Unit
    radarRight = radarFwd:Cross(Vector3.yAxis)
    radarReady = true

    local center, acc = v2(cx, cy), O.Accent

    local bgOut = ov("rdBgOut", "Circle", 0)
    bgOut.Position, bgOut.Radius, bgOut.NumSides, bgOut.Filled, bgOut.Thickness = center, half + 1.5, 48, false, 2
    bgOut.Color, bgOut.Transparency, bgOut.Visible = BLACK, 0.75, true

    local bg = ov("rdBg", "Circle", 1)
    bg.Position, bg.Radius, bg.NumSides, bg.Filled = center, half, 48, true
    bg.Color, bg.Transparency, bg.Visible = rgb(12, 13, 18), R.Opacity, true

    local midRing = ov("rdMid", "Circle", 2)
    midRing.Position, midRing.Radius, midRing.NumSides, midRing.Filled, midRing.Thickness = center, half * 0.66, 40, false, 1
    midRing.Color, midRing.Transparency, midRing.Visible = GRAY, 0.14, true

    local innerRing = ov("rdIn", "Circle", 2)
    innerRing.Position, innerRing.Radius, innerRing.NumSides, innerRing.Filled, innerRing.Thickness = center, half * 0.33, 36, false, 1
    innerRing.Color, innerRing.Transparency, innerRing.Visible = GRAY, 0.12, true

    local bd = ov("rdBd", "Circle", 2)
    bd.Position, bd.Radius, bd.NumSides, bd.Filled, bd.Thickness = center, half, 48, false, O.DragHUD and 2 or 1.5
    bd.Color, bd.Transparency, bd.Visible = acc, O.DragHUD and 1 or 0.9, true

    local lh = ov("rdH", "Line", 2)
    lh.From, lh.To = center - v2(half - 2, 0), center + v2(half - 2, 0)
    lh.Color, lh.Thickness, lh.Transparency, lh.Visible = GRAY, 1, 0.16, true
    local lv = ov("rdV", "Line", 2)
    lv.From, lv.To = center - v2(0, half - 2), center + v2(0, half - 2)
    lv.Color, lv.Thickness, lv.Transparency, lv.Visible = GRAY, 1, 0.16, true

    local s, c = sin(math.rad(38)) * half, cos(math.rad(38)) * half
    local c1 = ov("rdC1", "Line", 3)
    c1.From, c1.To = center, center + v2(-s, -c)
    c1.Color, c1.Thickness, c1.Transparency, c1.Visible = acc, 1, 0.45, true
    local c2 = ov("rdC2", "Line", 3)
    c2.From, c2.To = center, center + v2(s, -c)
    c2.Color, c2.Thickness, c2.Transparency, c2.Visible = acc, 1, 0.45, true

    for k = 1, 4 do
        local ang = (k - 1) * (math.pi * 0.5)
        local ca, sa = cos(ang), sin(ang)
        local tk = ov("rdTk" .. k, "Line", 3)
        tk.From, tk.To = center + v2(ca * (half - 5), sa * (half - 5)), center + v2(ca * half, sa * half)
        tk.Color, tk.Thickness, tk.Transparency, tk.Visible = acc, 1.5, 0.75, true
    end

    if R.Sweep ~= false then
        local swAng = (clock() * 2.1) % (math.pi * 2)
        for sw = 1, 3 do
            local a = swAng - (sw - 1) * 0.14
            local swLn = ov("rdSw" .. sw, "Line", 3)
            swLn.From, swLn.To = center, center + v2(cos(a) * (half - 2), sin(a) * (half - 2))
            swLn.Color, swLn.Thickness, swLn.Transparency, swLn.Visible = acc, (sw == 1) and 1.6 or 1.2, 0.45 - (sw - 1) * 0.14, true
        end
    else
        for sw = 1, 3 do
            local swLn = overlayObjs["rdSw" .. sw]
            if swLn then swLn.Visible = false end
        end
    end

    local meOut = ov("rdMeOut", "Circle", 4)
    meOut.Position, meOut.Radius, meOut.NumSides, meOut.Filled = center, 4.2, 12, true
    meOut.Color, meOut.Transparency, meOut.Visible = BLACK, 0.85, true

    local me = ov("rdMe", "Circle", 5)
    me.Position, me.Radius, me.NumSides, me.Filled = center, 3, 12, true
    me.Color, me.Transparency, me.Visible = acc, 1, true
end

local function drawRadarDot(d, rd)
    local R = cfg().Radar
    local hrp = rd.parts and rd.parts.HumanoidRootPart
    if not R.Enabled or not radarReady or not isPartValid(hrp) then
        ESPDraw.hideRadar(d) return
    end

    local rel = partPos(hrp) - cameraPos
    local lim = R.Size / 2 - 5
    local scale = lim / max(R.Range, 1)
    local px, py = rel:Dot(radarRight) * scale, -rel:Dot(radarFwd) * scale
    local mag = sqrt(px * px + py * py)
    if mag > lim then px, py = px / mag * lim, py / mag * lim end

    local dotPos, col = v2(radarCX + px, radarCY + py), boxColor(rd)

    local bg = ESPDraw.ensure(d, "radarbg", 1)[1]
    bg.Position, bg.Radius, bg.NumSides, bg.Filled = dotPos, R.DotSize + 1.3, 12, true
    bg.Color, bg.Transparency, bg.Visible = BLACK, 0.85, true

    local dot = ESPDraw.ensure(d, "radar", 1)[1]
    dot.Position, dot.Radius, dot.NumSides, dot.Filled = dotPos, R.DotSize, 12, true
    dot.Color, dot.Transparency, dot.Visible = col, 1, true

    if rd.priority then
        local pr = ESPDraw.ensure(d, "radarprio", 1)[1]
        local pScale = 1 + sin(clock() * 6.5) * 0.25
        pr.Position, pr.Radius, pr.NumSides, pr.Filled, pr.Thickness = dotPos, (R.DotSize + 3.2) * pScale, 14, false, 1.3
        pr.Color, pr.Transparency, pr.Visible = cfg().ESP.Colors.Priority, 0.9, true
    else
        ESPDraw.hideKey(d, "radarprio")
    end

    if R.ShowLookDir then
        local lv = partCF(hrp).LookVector
        local lx, ly = lv:Dot(radarRight), -lv:Dot(radarFwd)
        local lmag = sqrt(lx * lx + ly * ly)
        if lmag > 0.01 then
            local rlook = ESPDraw.ensure(d, "radarlook", 1)[1]
            rlook.From, rlook.To = dotPos, dotPos + v2(lx / lmag, ly / lmag) * (R.DotSize + 4)
            rlook.Color, rlook.Thickness, rlook.Transparency, rlook.Visible = col, 1.5, 0.9, true
        else
            ESPDraw.hideKey(d, "radarlook")
        end
    else
        ESPDraw.hideKey(d, "radarlook")
    end
end

local Aware = (function()
local proximityState = {}
local proximityAudioObjects = {}
local proximityLastScan = 0

local function normalizeSoundId(value)
    local id = tostring(value or ""):match("%d+")
    if not id or id == "0" then return nil end
    return "rbxassetid://" .. id
end

local function playSoundWhenReady(sound, useLocal)
    local function trigger()
        if not sound.Parent then return end
        if useLocal then
            SoundService:PlayLocalSound(sound)
        else
            sound:Play()
        end
    end
    if sound.IsLoaded then
        trigger()
    else
        task.spawn(function()
            local t = clock()
            while not sound.IsLoaded and clock() - t < 2.5 do
                if not sound.Parent then return end
                task.wait(0.05)
            end
            if sound.IsLoaded and sound.Parent then
                trigger()
            end
        end)
    end
end

local function playProximitySound(targetRoot)
    local e = cfg().Proximity
    local raw = SOUND_PRESETS[e.SoundPreset] or e.SoundId
    local soundId = normalizeSoundId(raw)
    if not soundId then return end
    if e.SpatialSound and isPartValid(targetRoot) then
        local emitter = Instance.new("Part")
        emitter.Name = "GlupostLocalAudioEmitter"
        emitter.Size = Vector3.new(0.1, 0.1, 0.1)
        emitter.Transparency = 1
        emitter.Anchored, emitter.CanCollide, emitter.CanTouch, emitter.CanQuery = true, false, false, false
        emitter.CFrame = partCF(targetRoot)
        emitter.Parent = workspace
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = clamp(e.Volume, 0, 2)
        sound.RollOffMode = Enum.RollOffMode.InverseTapered
        sound.RollOffMinDistance = 4
        sound.RollOffMaxDistance = math.max(80, e.Distance * 2)
        sound.EmitterSize = 3
        sound.Parent = emitter
        proximityAudioObjects[emitter] = true
        emitter.Destroying:Connect(function() proximityAudioObjects[emitter] = nil end)
        playSoundWhenReady(sound, false)
        Debris:AddItem(emitter, 8)
    else
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = clamp(e.Volume, 0, 2)
        sound.Parent = SoundService
        proximityAudioObjects[sound] = true
        sound.Destroying:Connect(function() proximityAudioObjects[sound] = nil end)
        playSoundWhenReady(sound, true)
        Debris:AddItem(sound, 8)
    end
end

local function updateProximityAlert()
    local e = cfg().Proximity
    if not e.Enabled then
        table.clear(proximityState)
        return
    end
    local now = clock()
    if now - proximityLastScan < 0.12 then return end
    proximityLastScan = now
    local myChar = LP.Character
    local myRoot = getRootPart(myChar)
    local cam = workspace.CurrentCamera
    if not isPartValid(myRoot) or not cam then return end
    local esp = cfg().ESP
    local ignoreTeams = esp.SyncWithESP and esp.HideTeammates or e.IgnoreTeammates
    local maxDist = clamp(e.Distance, 5, 2000)
    local look = myRoot.CFrame.LookVector
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local char = getChar(plr)
            local root = getRootPart(char)
            local state = proximityState[plr] or { armed = true, last = 0 }
            proximityState[plr] = state
            if isPartValid(root) and (not ignoreTeams or not isTeammate(plr)) then
                local offset = root.Position - myRoot.Position
                local dist = offset.Magnitude
                if dist > maxDist + 12 then state.armed = true end
                local directional = true
                if dist > 0.01 then
                    local dot = look:Dot(offset.Unit)
                    if e.Direction == "Behind Only" then directional = dot <= -0.35
                    elseif e.Direction == "Front Only" then directional = dot >= 0.35 end
                end
                if dist <= maxDist and directional and state.armed and now - state.last >= e.Cooldown then
                    state.armed = false
                    state.last = now
                    playProximitySound(root)
                end
            else
                state.armed = true
            end
        end
    end
    for plr in pairs(proximityState) do
        if plr.Parent ~= Players then proximityState[plr] = nil end
    end
end

local lookAlertDirs = {}
local lookAlertCount = 0
local function sortLookDirs(a, b) return a.dist < b.dist end
local LA_BG_KEYS, LA_LN_KEYS, LA_TB_KEYS, LA_TL_KEYS = {}, {}, {}, {}
for idx = 1, 4 do
    LA_BG_KEYS[idx], LA_LN_KEYS[idx] = {}, {}
    LA_TB_KEYS[idx], LA_TL_KEYS[idx] = { "laTB_" .. idx .. "_1", "laTB_" .. idx .. "_2" }, { "laTL_" .. idx .. "_1", "laTL_" .. idx .. "_2" }
    for s = 1, 5 do
        LA_BG_KEYS[idx][s] = "laB_" .. idx .. "_" .. s
        LA_LN_KEYS[idx][s] = "laL_" .. idx .. "_" .. s
    end
end

local function updateLookingAlert()
    local L = cfg().LookingAlert
    if not L.Enabled then
        if ovState.la then hideGroup("la") ovState.la = false end
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then hideGroup("la") ovState.la = false return end
    ovState.la = true

    local esp = cfg().ESP
    local hideTeams = esp.SyncWithESP and esp.HideTeammates or L.HideTeammates
    local maxDist = clamp(L.MaxDistance, 20, 2000)
    local cosLimit = math.cos(math.rad(clamp(L.Angle, 3, 45)))

    lookAlertCount = 0
    for plr, rd in pairs(renderData) do
        if not (hideTeams and rd.team) and rd.distance and rd.distance <= maxDist then
            local d = playersData[plr]
            local head = rd.parts and rd.parts.Head
            if d and isPartValid(head) then
                local hpos = partPos(head)
                local toMe = cameraPos - hpos
                if toMe.Magnitude > 0.5 then
                    local dot = partCF(head).LookVector:Dot(toMe.Unit)
                    if dot >= cosLimit then
                        local visOk = (not L.RequireLoS) or isVisibleCached(d, head)
                        if visOk then
                            local toEnemy = -toMe.Unit
                            local dx = cameraCF.RightVector:Dot(toEnemy)
                            local dy = -cameraCF.UpVector:Dot(toEnemy)
                            lookAlertCount += 1
                            local slot = lookAlertDirs[lookAlertCount]
                            if not slot then
                                slot = { ang = 0, dist = 0, name = "" }
                                lookAlertDirs[lookAlertCount] = slot
                            end
                            slot.ang = math.atan2(dy, dx)
                            slot.dist = rd.distance
                            slot.name = plr.DisplayName
                        end
                    end
                end
            end
        end
    end
    for i = lookAlertCount + 1, #lookAlertDirs do
        lookAlertDirs[i].dist = math.huge
    end

    local count = lookAlertCount
    if count == 0 then
        hideGroup("la")
        return
    end
    if count > 1 then
        table.sort(lookAlertDirs, sortLookDirs)
    end

    local vp = cam.ViewportSize
    local center = Vector2.new(math.floor(vp.X * 0.5), math.floor(vp.Y * 0.5))
    local pulse = 0.72 + 0.28 * math.sin(clock() * 7)
    local radius = clamp(L.Radius or 76, 45, 180)
    local segs = 5
    local shown = math.min(count, 4)

    for idx = 1, shown do
        local baseA = lookAlertDirs[idx].ang
        local span = 0.52
        local startA = baseA - span * 0.5
        local step = span / segs
        for s = 1, segs do
            local a1 = startA + (s - 1) * step
            local a2 = a1 + step
            local p1 = center + Vector2.new(math.cos(a1) * radius, math.sin(a1) * radius)
            local p2 = center + Vector2.new(math.cos(a2) * radius, math.sin(a2) * radius)
            local bg = ov(LA_BG_KEYS[idx][s], "Line", 4)
            bg.From, bg.To = p1, p2
            bg.Color, bg.Thickness, bg.Transparency, bg.Visible = BLACK, 5, pulse * 0.65, true
            local ln = ov(LA_LN_KEYS[idx][s], "Line", 5)
            ln.From, ln.To = p1, p2
            ln.Color, ln.Thickness, ln.Transparency, ln.Visible = L.Color, 2.5, pulse, true
        end
        local tip = center + Vector2.new(math.cos(baseA) * (radius + 9), math.sin(baseA) * (radius + 9))
        local w1 = center + Vector2.new(math.cos(baseA - 0.14) * (radius + 1), math.sin(baseA - 0.14) * (radius + 1))
        local w2 = center + Vector2.new(math.cos(baseA + 0.14) * (radius + 1), math.sin(baseA + 0.14) * (radius + 1))
        for k = 1, 2 do
            local wp = k == 1 and w1 or w2
            local tbg = ov(LA_TB_KEYS[idx][k], "Line", 4)
            tbg.From, tbg.To = wp, tip
            tbg.Color, tbg.Thickness, tbg.Transparency, tbg.Visible = BLACK, 4.5, pulse * 0.65, true
            local tln = ov(LA_TL_KEYS[idx][k], "Line", 5)
            tln.From, tln.To = wp, tip
            tln.Color, tln.Thickness, tln.Transparency, tln.Visible = L.Color, 2, pulse, true
        end
    end
    for idx = shown + 1, 4 do
        for s = 1, segs do
            local bg = overlayObjs[LA_BG_KEYS[idx][s]]; if bg then bg.Visible = false end
            local ln = overlayObjs[LA_LN_KEYS[idx][s]]; if ln then ln.Visible = false end
        end
        for k = 1, 2 do
            local tbg = overlayObjs[LA_TB_KEYS[idx][k]]; if tbg then tbg.Visible = false end
            local tln = overlayObjs[LA_TL_KEYS[idx][k]]; if tln then tln.Visible = false end
        end
    end

    local nearest = lookAlertDirs[1]
    local badge = ov("laTxt", "Text", 6)
    if count == 1 then
        badge.Text = string.format("СМОТРИТ: %s (%d ст)", utf8Trunc(nearest.name or "", 14), math.floor(nearest.dist or 0))
    else
        badge.Text = string.format("НА ВАС СМОТРЯТ: %d (ближ. %s)", count, utf8Trunc(nearest.name or "", 12))
    end
    badge.Size, badge.Font, badge.Center, badge.Outline = 12, 2, true, true
    badge.Color, badge.OutlineColor = L.Color, BLACK
    badge.Position = Vector2.new(center.X, center.Y - radius - 22)
    badge.Transparency, badge.Visible = pulse, true
end

local stepState = {}
local stepRings = {}
local DOWN_10 = Vector3.new(0, -10, 0)
local UP_005 = Vector3.new(0, 0.05, 0)
local DEF_DROP = Vector3.new(0, 2.8, 0)

local function clearStepRings()
    for _, r in ipairs(stepRings) do freeRing(r) end
    tclear(stepRings)
end

local function spawnStepRing(pos, maxR, life, col, thick, maxCount)
    while #stepRings >= maxCount do freeRing(tremove(stepRings, 1)) end
    tinsert(stepRings, {
        pos = pos, born = clock(), life = life, maxR = maxR, col = col,
        glowCol = col:Lerp(WHITE, 0.35), thick = thick,
        glow = {}, lines = {}, glow2 = {}, lines2 = {},
    })
end

local stepVisParams = RaycastParams.new()
stepVisParams.FilterType = visParams.FilterType
local stepIgnore = {}

local function enemyGroundPos(char, root)
    local origin = partPos(root)
    tclear(stepIgnore)
    stepIgnore[1] = char
    if workspace.CurrentCamera then stepIgnore[2] = workspace.CurrentCamera end
    stepVisParams.FilterDescendantsInstances = stepIgnore
    local res = rawRay(origin, DOWN_10, stepVisParams)
    return res and (res.Position + UP_005) or (origin - DEF_DROP)
end

local function updateFootstepRings()
    local F = cfg().FootstepRings
    if not F.Enabled then
        if #stepRings > 0 then clearStepRings() end
        tclear(stepState)
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then clearStepRings() return end

    local esp = cfg().ESP
    local hideTeams = esp.SyncWithESP and esp.HideTeammates or F.HideTeammates
    local maxDist = clamp(F.MaxDistance, 20, 500)
    local maxCount = clamp(floor(F.MaxRings or 10), 4, 24)
    local baseR = clamp(F.MaxRadius or 3.8, 1.5, 10)
    local life = clamp(F.Lifetime or 0.65, 0.2, 1.8)
    local isPulse, now = (F.Style or "Pulse") ~= "Solid", clock()

    for plr, rd in pairs(renderData) do
        if not (hideTeams and rd.team) and rd.distance and rd.distance <= maxDist and rd.parts then
            local hum, root, char = rd.parts.humanoid, rd.parts.HumanoidRootPart, rd.parts.Character
            if hum and hum.Health > 0 and isPartValid(root) and char then
                local st, curFloor = stepState[plr], hum.FloorMaterial
                if not st then
                    stepState[plr] = { lastFloor = curFloor, lastStep = now }
                else
                    local vel = root.AssemblyLinearVelocity or root.Velocity
                    local horiz = v3(vel.X, 0, vel.Z).Magnitude
                    local landed = (st.lastFloor == Enum.Material.Air and curFloor ~= Enum.Material.Air)
                    if landed and now - st.lastStep >= 0.16 then
                        st.lastStep = now
                        spawnStepRing(enemyGroundPos(char, root), baseR * 1.32, life * 1.15, F.Color, 1.8, maxCount)
                    elseif curFloor ~= Enum.Material.Air and horiz > 6 then
                        local cadence = clamp(5.5 / horiz, 0.22, 0.52)
                        if now - st.lastStep >= cadence then
                            st.lastStep = now
                            spawnStepRing(enemyGroundPos(char, root), baseR * clamp(horiz / 20, 0.75, 1.2), life, F.Color, 1.4, maxCount)
                        end
                    end
                    st.lastFloor = curFloor
                end
            end
        end
    end

    for plr in pairs(stepState) do
        if not renderData[plr] then stepState[plr] = nil end
    end

    for i = #stepRings, 1, -1 do
        local r = stepRings[i]
        local elapsed = now - r.born
        if elapsed >= r.life then
            freeRing(r)
            tremove(stepRings, i)
        else
            local t = elapsed / r.life
            local ease = 1 - (1 - t) * (1 - t)
            local curR = 0.4 + (r.maxR - 0.4) * ease
            local distFade = clamp(1 - (r.pos - cameraPos).Magnitude / max(maxDist * 1.15, 1), 0.2, 0.9)
            local alpha = (1 - t) * distFade
            Fx.drawWorldRing(cam, r.pos, curR, t * 0.9, C.STEP_SEGMENTS, r.glow, r.lines, r.col, r.glowCol, alpha, r.thick)
            if isPulse and t > 0.10 then
                local t2 = clamp((t - 0.10) / 0.90, 0, 1)
                local ease2 = 1 - (1 - t2) * (1 - t2)
                local curR2 = 0.25 + (r.maxR * 0.72 - 0.25) * ease2
                local alpha2 = (1 - t2) * distFade * 0.62
                Fx.drawWorldRing(cam, r.pos, curR2, -t * 0.8, C.STEP_SEGMENTS, r.glow2, r.lines2, r.glowCol, r.col, alpha2, math.max(1, r.thick * 0.75))
            else
                if r.glow2 then for _, o in ipairs(r.glow2) do o.Visible = false end end
                if r.lines2 then for _, o in ipairs(r.lines2) do o.Visible = false end end
            end
        end
    end
end

return {
    updateProximityAlert = updateProximityAlert, updateLookingAlert = updateLookingAlert,
    updateFootstepRings = updateFootstepRings,
    playProximitySound = playProximitySound, normalizeSoundId = normalizeSoundId,
    cleanup = function()
        table.clear(proximityState)
        table.clear(lookAlertDirs)
        table.clear(stepState)
        clearStepRings()
        for obj in pairs(proximityAudioObjects) do safeDestroy(obj) end
        table.clear(proximityAudioObjects)
    end,
}
end)()

local Library, Options, Toggles = nil, nil, nil

local HUD = (function()
local XH_DIRS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
local HM_DIRS = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
local XH_O, XH_L, HM_O, HM_L = {}, {}, {}, {}
for i = 1, 8 do
    XH_O[i], XH_L[i] = "xhO" .. i, "xhL" .. i
    HM_O[i], HM_L[i] = "hmO" .. i, "hmL" .. i
end
local SP_B, SP_L = {}, {}
for i = 1, 18 do SP_B[i], SP_L[i] = "spB" .. i, "spL" .. i end
local KB_L, KB_R = {}, {}
for i = 1, 24 do KB_L[i], KB_R[i] = "kbL" .. i, "kbR" .. i end
local SL_COUNT = 20
local SL_KEYS = {}
for i = 1, SL_COUNT do SL_KEYS[i] = "sl" .. i end

local XH_VDIRS = { v2(-1, 0), v2(1, 0), v2(0, -1), v2(0, 1) }
local HM_UDIRS = { v2(-1, -1).Unit, v2(1, -1).Unit, v2(-1, 1).Unit, v2(1, 1).Unit }
local xhDynGap = 0
local xhSpinAng = 0

local function rotV(vx, vy, cosA, sinA)
    return v2(vx * cosA - vy * sinA, vx * sinA + vy * cosA)
end

local function drawXhSeg(idx, a, b, col, th, hasOutline)
    local d = b - a
    local dirV = d.Magnitude > 0.01 and d.Unit or v2(1, 0)
    local o = ov(XH_O[idx], "Line", 1)
    if hasOutline then
        o.From, o.To = a - dirV, b + dirV
        o.Color, o.Thickness, o.Transparency, o.Visible = BLACK, th + 2, 1, true
    else
        o.Visible = false
    end
    local l = ov(XH_L[idx], "Line", 2)
    l.From, l.To = a, b
    l.Color, l.Thickness, l.Transparency, l.Visible = col, th, 1, true
end

local function drawHmLine(idx, a, b, dirV, segTh, segCol, tr)
    local bg = ov(HM_O[idx], "Line", 4)
    bg.From, bg.To = a - dirV, b + dirV
    bg.Color, bg.Thickness, bg.Transparency, bg.Visible = BLACK, segTh + 2, tr * 0.85, true
    local ln = ov(HM_L[idx], "Line", 5)
    ln.From, ln.To = a, b
    ln.Color, ln.Thickness, ln.Transparency, ln.Visible = segCol, segTh, tr, true
end

local function updateCrosshair(dt)
    local X = cfg().Crosshair
    if not X.Enabled then
        if ovState.xh then hideGroup("xh") ovState.xh = false end
        return
    end
    ovState.xh = true

    local vp = workspace.CurrentCamera.ViewportSize
    local c = v2(floor(vp.X / 2), floor(vp.Y / 2))
    local col = X.Rainbow and rainbow or X.Color
    local s, th, hasOut = X.Size, X.Thickness, X.Outline

    local targetDyn = 0
    if X.Dynamic then
        local root = getRootPart(LP.Character)
        if isPartValid(root) then
            local vel = root.AssemblyLinearVelocity or root.Velocity
            targetDyn = clamp(vel.Magnitude * 0.35, 0, 18)
        end
    end
    xhDynGap = xhDynGap + (targetDyn - xhDynGap) * clamp((dt or 0.016) * 12, 0, 1)
    local hitAgo = clock() - hitmarkerState.born
    local hitPop = (hitAgo >= 0 and hitAgo < 0.12) and ((1 - hitAgo / 0.12) * 3.5) or 0
    local g = X.Gap + xhDynGap + hitPop

    if X.Spin then
        xhSpinAng = (xhSpinAng + (dt or 0.016) * 2.4) % (math.pi * 2)
    else
        xhSpinAng = 0
    end
    local cosA, sinA = cos(xhSpinAng), sin(xhSpinAng)

    local usedLines = 0
    if X.Style == "Circle" then
        local ro = ov("xhRO", "Circle", 1)
        if hasOut then
            ro.Position, ro.Radius, ro.NumSides, ro.Filled, ro.Thickness = c, g + s * 0.5, 32, false, th + 2
            ro.Color, ro.Transparency, ro.Visible = BLACK, 0.85, true
        else
            ro.Visible = false
        end
        local rl = ov("xhRL", "Circle", 2)
        rl.Position, rl.Radius, rl.NumSides, rl.Filled, rl.Thickness = c, g + s * 0.5, 32, false, th
        rl.Color, rl.Transparency, rl.Visible = col, 1, true
    else
        local ro = overlayObjs["xhRO"]; if ro then ro.Visible = false end
        local rl = overlayObjs["xhRL"]; if rl then rl.Visible = false end

        if X.Style == "Brackets" then
            local r = g + s * 0.55
            local arm = min(max(3, s * 0.55), max(1.5, r * 0.85))
            for _, cs in ipairs(HM_DIRS) do
                local vx, vy = cs[1] * r, cs[2] * r
                local corner = c + rotV(vx, vy, cosA, sinA)
                usedLines += 1; drawXhSeg(usedLines, corner, c + rotV(vx - cs[1] * arm, vy, cosA, sinA), col, th, hasOut)
                usedLines += 1; drawXhSeg(usedLines, corner, c + rotV(vx, vy - cs[2] * arm, cosA, sinA), col, th, hasOut)
            end
        elseif X.Style == "Chevron" then
            local apex = c + rotV(0, -g * 0.35, cosA, sinA)
            local w = max(4, s * 0.85)
            local h = g * 0.35 + s * 0.72
            usedLines += 1; drawXhSeg(usedLines, apex, c + rotV(-w, h, cosA, sinA), col, th, hasOut)
            usedLines += 1; drawXhSeg(usedLines, apex, c + rotV(w, h, cosA, sinA), col, th, hasOut)
            local wingIn, wingOut = g + s * 0.45, g + s * 0.95
            usedLines += 1; drawXhSeg(usedLines, c + rotV(-wingOut, 0, cosA, sinA), c + rotV(-wingIn, 0, cosA, sinA), col, th, hasOut)
            usedLines += 1; drawXhSeg(usedLines, c + rotV(wingIn, 0, cosA, sinA), c + rotV(wingOut, 0, cosA, sinA), col, th, hasOut)
        elseif X.Style == "Diamond" then
            local r = g + s * 0.65
            local top = c + rotV(0, -r, cosA, sinA)
            local right = c + rotV(r, 0, cosA, sinA)
            local bot = c + rotV(0, r, cosA, sinA)
            local left = c + rotV(-r, 0, cosA, sinA)
            usedLines += 1; drawXhSeg(usedLines, top, right, col, th, hasOut)
            usedLines += 1; drawXhSeg(usedLines, right, bot, col, th, hasOut)
            usedLines += 1; drawXhSeg(usedLines, bot, left, col, th, hasOut)
            usedLines += 1; drawXhSeg(usedLines, left, top, col, th, hasOut)
        elseif X.Style == "X-Cross" then
            for i = 1, 4 do
                local u = HM_UDIRS[i]
                local dirV = rotV(u.X, u.Y, cosA, sinA)
                usedLines += 1; drawXhSeg(usedLines, c + dirV * g, c + dirV * (g + s), col, th, hasOut)
            end
        elseif X.Style == "Sniper" then
            local outer = g + max(8, s * 1.45)
            local tickDist = g + s * 0.55
            local tickHalf = max(2, s * 0.28)
            for i = 1, 4 do
                local dv = XH_DIRS[i]
                local dirV = rotV(dv[1], dv[2], cosA, sinA)
                local perpV = rotV(-dv[2], dv[1], cosA, sinA)
                usedLines += 1; drawXhSeg(usedLines, c + dirV * g, c + dirV * outer, col, th, hasOut)
                local mid = c + dirV * tickDist
                usedLines += 1; drawXhSeg(usedLines, mid - perpV * tickHalf, mid + perpV * tickHalf, col, max(1, th - 0.3), hasOut)
            end
        else
            for i, dv in ipairs(XH_DIRS) do
                if not (X.Style == "T-Cross" and i == 3) then
                    local dirV = rotV(dv[1], dv[2], cosA, sinA)
                    usedLines += 1; drawXhSeg(usedLines, c + dirV * g, c + dirV * (g + s), col, th, hasOut)
                end
            end
        end
    end

    for i = usedLines + 1, 8 do
        local o = overlayObjs[XH_O[i]]; if o then o.Visible = false end
        local l = overlayObjs[XH_L[i]]; if l then l.Visible = false end
    end

    local dotOut = ov("xhDO", "Circle", 1)
    local dot = ov("xhD", "Circle", 2)
    if X.Dot then
        if hasOut then
            dotOut.Position, dotOut.Radius, dotOut.NumSides, dotOut.Filled = c, max(1, th) + 1.2, 12, true
            dotOut.Color, dotOut.Transparency, dotOut.Visible = BLACK, 0.9, true
        else
            dotOut.Visible = false
        end
        dot.Position, dot.Radius, dot.NumSides, dot.Filled = c, max(1, th), 12, true
        dot.Color, dot.Transparency, dot.Visible = col, 1, true
    else
        dotOut.Visible = false
        dot.Visible = false
    end
end

local function updateHitmarker()
    local H = cfg().Hitmarker
    local elapsed = clock() - hitmarkerState.born
    local dur = clamp(H.Duration, 0.1, 0.8)
    if not H.Enabled or elapsed < 0 or elapsed >= dur then
        if ovState.hm then hideGroup("hm") ovState.hm = false end
        return
    end
    ovState.hm = true
    local vp = workspace.CurrentCamera.ViewportSize
    local c = v2(floor(vp.X * 0.5), floor(vp.Y * 0.5))
    local prog = clamp(elapsed / dur, 0, 1)
    local alpha = 1 - prog * prog
    local spread = 4 + prog * 7
    local sz = H.Size + (hitmarkerState.isKill and 3 or 0)
    local col = hitmarkerState.isKill and H.KillColor or H.Color
    local th = H.Thickness
    local style = H.Style or "Cross"

    local used = 0
    if style == "Circle" then
        local r = 3 + prog * (sz + 4)
        local co = ov("hmCO", "Circle", 4)
        co.Position, co.Radius, co.NumSides, co.Filled, co.Thickness = c, r, 32, false, th + 2
        co.Color, co.Transparency, co.Visible = BLACK, alpha * 0.85, true
        local cl = ov("hmC", "Circle", 5)
        cl.Position, cl.Radius, cl.NumSides, cl.Filled, cl.Thickness = c, r, 32, false, th
        cl.Color, cl.Transparency, cl.Visible = col, alpha, true
        local tickLen = max(2.5, sz * 0.35)
        for i = 1, 4 do
            local u = HM_UDIRS[i]
            used += 1; drawHmLine(used, c + u * (r + 2), c + u * (r + 2 + tickLen), u, max(1, th * 0.85), col:Lerp(WHITE, 0.25), alpha * 0.9)
        end
    else
        local co = overlayObjs["hmCO"]; if co then co.Visible = false end
        local cl = overlayObjs["hmC"]; if cl then cl.Visible = false end
        if style == "Diamond" then
            local r = spread + sz * 0.85
            local pts = {
                c + v2(0, -r),
                c + v2(r, 0),
                c + v2(0, r),
                c + v2(-r, 0),
            }
            for i = 1, 4 do
                local j = (i % 4) + 1
                local d = pts[j] - pts[i]
                local u = d.Magnitude > 0.01 and d.Unit or v2(1, 0)
                used += 1; drawHmLine(used, pts[i], pts[j], u, th, col, alpha)
            end
            local inCol = col:Lerp(WHITE, 0.35)
            local inR = max(2, sz * 0.42)
            for i = 1, 4 do
                local u = HM_UDIRS[i]
                used += 1; drawHmLine(used, c + u * 2.5, c + u * (2.5 + inR), u, max(1, th * 0.8), inCol, alpha * 0.88)
            end
        else
            for i = 1, 4 do
                local u = HM_UDIRS[i]
                used += 1; drawHmLine(used, c + u * spread, c + u * (spread + sz), u, th, col, alpha)
            end
            if style == "Double" then
                local inCol = col:Lerp(WHITE, 0.35)
                local inSpread = 1.8 + prog * 3.2
                local inSz = max(2, sz * 0.48)
                for i = 1, 4 do
                    local u = HM_UDIRS[i]
                    used += 1; drawHmLine(used, c + u * inSpread, c + u * (inSpread + inSz), u, max(1, th * 0.85), inCol, alpha * 0.9)
                end
            elseif style == "Star" then
                local cardCol = col:Lerp(WHITE, 0.25)
                local cardSpread = spread * 0.85
                local cardSz = max(2, sz * 0.6)
                for i = 1, 4 do
                    local u = XH_VDIRS[i]
                    used += 1; drawHmLine(used, c + u * cardSpread, c + u * (cardSpread + cardSz), u, max(1, th * 0.8), cardCol, alpha * 0.9)
                end
            end
        end
    end
    for i = used + 1, 8 do
        local bg = overlayObjs[HM_O[i]]; if bg then bg.Visible = false end
        local ln = overlayObjs[HM_L[i]]; if ln then ln.Visible = false end
    end
end

local function setVigStrip(name, x, y, w, h, col, tr)
    local s = ov(name, "Square", 0)
    s.Position, s.Size = v2(x, y), v2(max(1, w), max(1, h))
    s.Filled, s.Color, s.Transparency, s.Visible = true, col, tr, true
end

local VIG_LAYERS = { { "0", 16, 0.28, 0.55 }, { "1", 22, 0.12, 0.28 }, { "2", 26, 0.055, 0.14 } }
local VIG_CORNERS = { { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } }
local lowHpSmooth = 0
local function updateVignette(dt)
    local V, cam = cfg().Vignette, workspace.CurrentCamera
    if not cam or (not V.LowHP and not V.KillFlash) then
        if ovState.vg then hideGroup("vg") ovState.vg = false end
        lowHpSmooth = 0
        return
    end

    local lowAlpha, now = 0, clock()
    if V.LowHP then
        local char = LP and LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local pct = (hum.Health / max(hum.MaxHealth, 1)) * 100
            local thr = clamp(V.LowHPThreshold or 35, 10, 80)
            if pct <= thr then
                local sev = clamp(1 - pct / thr, 0.12, 1)
                lowAlpha = sev * (0.65 + 0.35 * sin(now * (4.5 + sev * 4.5)))
            end
        end
    end
    lowHpSmooth += (lowAlpha - lowHpSmooth) * clamp((dt or 0.016) * 8, 0, 1)

    local killAlpha = 0
    if V.KillFlash then
        local elapsed = now - (hitmarkerState.killFlashBorn or -99)
        if elapsed >= 0 and elapsed < 0.45 then
            local p = elapsed / 0.45
            killAlpha = (1 - p) * (1 - p)
        end
    end

    local total = max(lowHpSmooth, killAlpha)
    if total <= 0.01 then
        if ovState.vg then hideGroup("vg") ovState.vg = false end
        return
    end
    ovState.vg = true

    local col = (killAlpha > lowHpSmooth * 0.85) and V.KillColor or V.LowHPColor
    local inten = clamp(V.Intensity or 0.85, 0.1, 1.5)
    local vp = cam.ViewportSize
    local W, H, off = floor(vp.X), floor(vp.Y), 0

    for i = 1, 3 do
        local L = VIG_LAYERS[i]
        local suf, d, mul, cap = L[1], L[2], L[3], L[4]
        local a = clamp(total * mul * inten, 0, cap)
        setVigStrip("vgT" .. suf, off, off, W - off * 2, d, col, a)
        setVigStrip("vgB" .. suf, off, H - off - d, W - off * 2, d, col, a)
        setVigStrip("vgL" .. suf, off, off + d, d, H - (off + d) * 2, col, a)
        setVigStrip("vgR" .. suf, W - off - d, off + d, d, H - (off + d) * 2, col, a)
        off += d
    end

    local cPad, cLen = 14, 28
    local cTr, cCol = clamp(total * 0.72 * inten, 0, 0.92), col:Lerp(WHITE, 0.25)
    for k = 1, 4 do
        local cr = VIG_CORNERS[k]
        local cx = cr[1] == 0 and cPad or (W - cPad)
        local cy = cr[2] == 0 and cPad or (H - cPad)
        local pt = v2(cx, cy)
        local l1 = ov("vgC" .. (k * 2 - 1), "Line", 2)
        l1.From, l1.To, l1.Color, l1.Thickness, l1.Transparency, l1.Visible = pt, v2(cx + cr[3] * cLen, cy), cCol, 2, cTr, true
        local l2 = ov("vgC" .. (k * 2), "Line", 2)
        l2.From, l2.To, l2.Color, l2.Thickness, l2.Transparency, l2.Visible = pt, v2(cx, cy + cr[4] * cLen), cCol, 2, cTr, true
    end
end

local function updateSpeedometer()
    local O = cfg().Overlay
    local cam, root = workspace.CurrentCamera, getRootPart(LP and LP.Character)
    if not O.Speedometer or not cam or not isPartValid(root) then
        if ovState.sp then hideGroup("sp") ovState.sp = false end
        return
    end
    ovState.sp = true

    local vp = cam.ViewportSize
    local c = v2(floor(vp.X * 0.5), floor(vp.Y * 0.5))
    local spd = (root.AssemblyLinearVelocity or root.Velocity).Magnitude
    local maxSpd = max(O.SpeedometerMax or 60, 10)
    local frac = clamp(spd / maxSpd, 0, 1)

    local sande = cfg().Afterimage
    local sandeActive = sande.Enabled and spd >= clamp(sande.MinSpeed or 4, 0, 50)
    local cyanCol = rgb(35, 255, 175)
    local tipCol = sandeActive and cyanCol or O.Accent:Lerp(cyanCol, frac * 0.85)

    local segs, radius = 18, 38
    local startA, endA = math.pi * 0.5 - 0.98, math.pi * 0.5 + 0.98
    local step = (endA - startA) / segs
    local filledSegs = floor(frac * segs + 0.5)

    for i = 1, segs do
        local a1 = startA + (i - 1) * step
        local a2 = a1 + step
        local p1, p2 = c + v2(cos(a1) * radius, sin(a1) * radius), c + v2(cos(a2) * radius, sin(a2) * radius)

        local bg = ov(SP_B[i], "Line", 2)
        bg.From, bg.To, bg.Color, bg.Thickness, bg.Transparency, bg.Visible = p1, p2, BLACK, 4.2, 0.55, true

        local ln = ov(SP_L[i], "Line", 3)
        ln.From, ln.To = p1, p2
        if i <= filledSegs then
            local segT = i / segs
            ln.Color = sandeActive and cyanCol:Lerp(WHITE, segT * 0.25) or O.Accent:Lerp(cyanCol, segT * 0.85)
            ln.Thickness, ln.Transparency, ln.Visible = 2.4, 0.96, true
        else
            ln.Color, ln.Thickness, ln.Transparency, ln.Visible = GRAY, 1.5, 0.22, true
        end
    end

    local dot = ov("spDot", "Circle", 4)
    if frac > 0.02 then
        local curA = startA + frac * (endA - startA)
        dot.Position, dot.Radius, dot.NumSides, dot.Filled = c + v2(cos(curA) * radius, sin(curA) * radius), 3.2, 12, true
        dot.Color, dot.Transparency, dot.Visible = tipCol:Lerp(WHITE, 0.45), 1, true
    else
        dot.Visible = false
    end

    local tick = ov("spTick", "Line", 4)
    if sande.Enabled then
        local ta = startA + clamp((sande.MinSpeed or 4) / maxSpd, 0, 1) * (endA - startA)
        local dx, dy = cos(ta), sin(ta)
        tick.From, tick.To = c + v2(dx * (radius - 4), dy * (radius - 4)), c + v2(dx * (radius + 4), dy * (radius + 4))
        tick.Color, tick.Thickness, tick.Transparency, tick.Visible = WHITE, 1.5, 0.9, true
    else
        tick.Visible = false
    end

    local lbl = ov("spTxt", "Text", 4)
    lbl.Text = string.format("%d st/s", floor(spd + 0.5))
    lbl.Size, lbl.Font, lbl.Center, lbl.Outline = 11, 2, true, true
    lbl.Color, lbl.OutlineColor = sandeActive and cyanCol or WHITE, BLACK
    lbl.Position, lbl.Transparency, lbl.Visible = v2(c.X, c.Y + radius + 6), 0.95, true
end

local slPhase = 0
local function updateSpeedLines(dt)
    local O = cfg().Overlay
    local cam, root = workspace.CurrentCamera, getRootPart(LP and LP.Character)
    if not O.SpeedLines or not cam or not isPartValid(root) then
        if ovState.sl then hideGroup("sl") ovState.sl = false end
        return
    end
    local spd = (root.AssemblyLinearVelocity or root.Velocity).Magnitude
    local minSpd = max(O.SpeedLinesMinSpeed or 20, 4)
    if spd < minSpd then
        if ovState.sl then hideGroup("sl") ovState.sl = false end
        return
    end
    ovState.sl = true
    slPhase = slPhase + (dt or 0.016) * 16
    local intensity = clamp((spd - minSpd) / max(minSpd * 0.85, 16), 0.12, 1)
    local vp = cam.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local maxR = sqrt(cx * cx + cy * cy)
    local innerBase = min(cx, cy) * (0.76 - intensity * 0.24)
    local col = O.SpeedLinesRainbow and rainbow or O.SpeedLinesColor
    local op = clamp(O.SpeedLinesOpacity or 0.65, 0.1, 1)
    local step = (math.pi * 2) / SL_COUNT
    for i = 1, SL_COUNT do
        local ln = ov(SL_KEYS[i], "Line", 1)
        if sin(slPhase * 1.45 + i * 2.3) > -0.45 then
            local ang = (i - 1) * step + sin(i * 4.1 + slPhase * 0.65) * 0.06
            local dx, dy = cos(ang), sin(ang)
            local pulse = 0.5 + 0.5 * sin(slPhase * 2.0 + i * 1.7)
            local rIn = innerBase + pulse * (min(cx, cy) * 0.16)
            local rOut = maxR * 1.05
            ln.From = v2(cx + dx * rOut, cy + dy * rOut)
            ln.To = v2(cx + dx * rIn, cy + dy * rIn)
            ln.Color = (i % 3 == 0) and col:Lerp(WHITE, 0.52) or col
            ln.Thickness = 1 + pulse * 1.55 * intensity
            ln.Transparency = clamp(op * intensity * (0.45 + 0.55 * pulse), 0.05, 0.95)
            ln.Visible = true
        else
            ln.Visible = false
        end
    end
end

local cachedPing, lastPingPoll = 0, 0
local function updateWatermark()
    local O = cfg().Overlay
    if not O.Watermark then
        if ovState.wm then hideGroup("wm") ovState.wm = false end
        return
    end
    local now = clock()
    if ovState.wm and now - ticks.wm < C.WATERMARK_TICK then return end
    ticks.wm, ovState.wm = now, true

    if now - ticks.pool > C.POOL_STAT then
        poolUsed, ticks.pool = poolCreated(), now
    end
    if now - lastPingPoll > 0.5 then
        lastPingPoll = now
        local okp, pval = pcall(function()
            return floor(StatsSvc.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
        end)
        if okp and type(pval) == "number" and pval > 0 then cachedPing = pval end
    end

    local pingPart = cachedPing > 0 and string.format("  |  %d ms", cachedPing) or ""
    local txt = string.format("glupost %s  |  %d fps%s  |  %d players  |  draw: %d  |  %s",
        VERSION, floor(fps + 0.5), pingPart, #Players:GetPlayers(), poolUsed, os.date("%H:%M:%S"))

    local bg, bd, line, t = ov("wmBg", "Square", 1), ov("wmBd", "Square", 2), ov("wmLine", "Line", 3), ov("wmT", "Text", 4)
    t.Text, t.Size, t.Font, t.Outline, t.OutlineColor = txt, 13, 2, true, BLACK
    t.Color, t.Position, t.Transparency, t.Visible = WHITE, v2(18, 15), 1, true

    local okb, bounds = pcall(function() return t.TextBounds end)
    local boxW, boxH = ((okb and bounds and bounds.X > 0) and bounds.X or (#txt * 7)) + 16, 26

    bg.Position, bg.Size, bg.Filled = v2(10, 8), v2(boxW, boxH), true
    bg.Color, bg.Transparency, bg.Visible = rgb(13, 14, 20), 0.82, true

    bd.Position, bd.Size, bd.Filled, bd.Thickness = v2(10, 8), v2(boxW, boxH), false, 1
    bd.Color, bd.Transparency, bd.Visible = BLACK, 0.8, true

    line.From, line.To = v2(10, 8), v2(10 + boxW, 8)
    line.Color, line.Thickness, line.Transparency, line.Visible = O.Accent, 2, 1, true
end

local targetHudSmoothHP, targetHudTrailHP, targetHudLastPlr = 1, 1, nil

local function updateTargetHUD(dt)
    local O, e = cfg().Overlay, cfg().ESP
    local rd, cam = currentPriorityRd, workspace.CurrentCamera
    local hasRealTarget, hum, plr = false, nil, nil
    if cam and O.TargetHUD and rd and rd.parts then
        hum, plr = rd.parts.humanoid, rd.parts._player
        if hum and hum.Health > 0 and plr and plr.Parent == Players then hasRealTarget = true end
    end
    local previewMode = (not hasRealTarget) and cam and O.TargetHUD and O.DragHUD
    if not cam or not O.TargetHUD or (not hasRealTarget and not previewMode) then
        if ovState.th then hideGroup("th") ovState.th = false end
        targetHudLastPlr = nil
        hudState.rects.th = nil
        return
    end
    ovState.th = true

    local vp = cam.ViewportSize
    local w, h, x, y = 236, 76
    if O.TargetHUDX and O.TargetHUDX >= 0 and O.TargetHUDY and O.TargetHUDY >= 0 then
        x, y = clamp(floor(O.TargetHUDX), 6, max(6, vp.X - w - 6)), clamp(floor(O.TargetHUDY), 6, max(6, vp.Y - h - 6))
    elseif O.TargetHUDPos == "TopCenter" then
        x, y = floor(vp.X * 0.5 - w * 0.5), 42
    elseif O.TargetHUDPos == "RightCenter" then
        x, y = floor(vp.X - w - 26), floor(vp.Y * 0.5 - h * 0.5)
    else
        x, y = floor(vp.X * 0.5 - w * 0.5), floor(vp.Y * 0.5 + 88)
    end
    setHudRect("th", x, y, w, h)

    local acc = O.Accent
    local pct, hpCur, hpMax, dispName, isVis, distVal, hTag, toolName
    if hasRealTarget then
        hpCur, hpMax = floor(hum.Health), floor(max(hum.MaxHealth, 1))
        pct = clamp(hum.Health / max(hum.MaxHealth, 1), 0, 1)
        if targetHudLastPlr ~= plr then
            targetHudLastPlr, targetHudSmoothHP, targetHudTrailHP = plr, pct, pct
        else
            targetHudSmoothHP += (pct - targetHudSmoothHP) * clamp((dt or 0.016) * 14, 0, 1)
            targetHudTrailHP = targetHudTrailHP < targetHudSmoothHP and targetHudSmoothHP
                or (targetHudTrailHP + (targetHudSmoothHP - targetHudTrailHP) * clamp((dt or 0.016) * 3.2, 0, 1))
        end
        dispName, isVis, distVal = utf8Trunc(plr.DisplayName, 13), rd.visible, floor(rd.distance or 0)
        local myRoot, tRoot = getRootPart(LP and LP.Character), rd.parts.HumanoidRootPart
        local dy = (isPartValid(myRoot) and isPartValid(tRoot)) and floor(partPos(tRoot).Y - partPos(myRoot).Y + 0.5) or 0
        hTag = dy > 3 and string.format("  +%dY", dy) or (dy < -3 and string.format("  %dY", dy) or "")
        local tool = rd.parts.Character and rd.parts.Character:FindFirstChildOfClass("Tool")
        toolName = tool and utf8Trunc(tool.Name, 20) or "Без предмета"
    else
        targetHudSmoothHP, targetHudTrailHP, hpCur, hpMax = 0.75, 0.75, 75, 100
        dispName, isVis, distVal, hTag, toolName = "Target HUD (перетащи)", true, 42, "", "Оружие"
    end

    local bg = ov("thBg", "Square", 1)
    bg.Position, bg.Size, bg.Filled = v2(x, y), v2(w, h), true
    bg.Color, bg.Transparency, bg.Visible = rgb(13, 14, 21), 0.84, true

    local lowTarget = hasRealTarget and targetHudSmoothHP < 0.30
    local bd = ov("thBd", "Square", 2)
    bd.Position, bd.Size, bd.Filled, bd.Thickness = v2(x, y), v2(w, h), false, O.DragHUD and 1.5 or 1
    bd.Color, bd.Transparency, bd.Visible = lowTarget and rgb(255, 75, 85) or acc, (O.DragHUD or lowTarget) and 0.95 or 0.45, true

    local sideCol = (hasRealTarget and rd and rd.priority) and e.Colors.Priority or (isVis and e.Colors.Visible or e.Colors.Occluded)
    local side = ov("thSide", "Square", 3)
    side.Position, side.Size, side.Filled = v2(x + 1, y + 2), v2(3, h - 4), true
    side.Color, side.Transparency, side.Visible = sideCol, 0.95, true

    local topLine = ov("thLine", "Line", 3)
    topLine.From, topLine.To = v2(x, y), v2(x + w, y)
    topLine.Color, topLine.Thickness, topLine.Transparency, topLine.Visible = acc, 2, 1, true

    local nameLbl = ov("thName", "Text", 4)
    nameLbl.Text, nameLbl.Size, nameLbl.Font, nameLbl.Center, nameLbl.Outline = dispName, 14, 2, false, true
    nameLbl.Color, nameLbl.Position, nameLbl.Transparency, nameLbl.Visible = WHITE, v2(x + 10, y + 8), 1, true

    local visTxt = isVis and "ВИДЕН" or "ЗА СТЕНОЙ"
    local visLbl = ov("thVis", "Text", 4)
    visLbl.Text, visLbl.Size, visLbl.Font, visLbl.Center, visLbl.Outline = visTxt, 11, 2, false, true
    visLbl.Color = isVis and e.Colors.Visible or e.Colors.Occluded
    local okVb, vBounds = pcall(function() return visLbl.TextBounds end)
    local visW = (okVb and vBounds and vBounds.X > 0) and vBounds.X or (isVis and 38 or 60)
    visLbl.Position, visLbl.Transparency, visLbl.Visible = v2(x + w - visW - 10, y + 10), 1, true

    local infoLbl = ov("thInfo", "Text", 4)
    infoLbl.Text, infoLbl.Size, infoLbl.Font, infoLbl.Center, infoLbl.Outline = string.format("%d ст%s  |  %s", distVal, hTag, toolName), 11, 2, false, true
    infoLbl.Color, infoLbl.Position, infoLbl.Transparency, infoLbl.Visible = GRAY, v2(x + 10, y + 26), 0.9, true

    local barX, barY, barW, barH = x + 10, y + 47, w - 20, 8
    local hpBg = ov("thHpBg", "Square", 2)
    hpBg.Position, hpBg.Size, hpBg.Filled = v2(barX - 1, barY - 1), v2(barW + 2, barH + 2), true
    hpBg.Color, hpBg.Transparency, hpBg.Visible = BLACK, 0.85, true

    local hpTrail = ov("thHpTrail", "Square", 3)
    if targetHudTrailHP > targetHudSmoothHP + 0.006 then
        hpTrail.Position, hpTrail.Size = v2(barX, barY), v2(max(2, floor(barW * targetHudTrailHP + 0.5)), barH)
        hpTrail.Filled, hpTrail.Color, hpTrail.Transparency, hpTrail.Visible = true, WHITE, 0.85, true
    else
        hpTrail.Visible = false
    end

    local hpFill = ov("thHpFill", "Square", 4)
    hpFill.Position, hpFill.Size, hpFill.Filled = v2(barX, barY), v2(max(2, floor(barW * targetHudSmoothHP + 0.5)), barH), true
    hpFill.Color, hpFill.Transparency, hpFill.Visible = healthColor(targetHudSmoothHP), 1, true

    local hpPctVal = hasRealTarget and floor(clamp(hum.Health / max(hum.MaxHealth, 1), 0, 1) * 100 + 0.5) or 75
    local hpTxt = ov("thHpTxt", "Text", 5)
    hpTxt.Text, hpTxt.Size, hpTxt.Font, hpTxt.Center, hpTxt.Outline = string.format("%d / %d HP  (%d%%)", hpCur, hpMax, hpPctVal), 11, 2, false, true
    hpTxt.Color, hpTxt.Position, hpTxt.Transparency, hpTxt.Visible = WHITE, v2(x + 10, y + 58), 0.95, true
end

local kbLastTick = 0
local kbLabels, kbTags, kbWidthCache = {}, {}, {}
local function kbTag(optIdx, fallback)
    local o = Library and Library.Options and Library.Options[optIdx]
    local v = o and o.Value
    if v == "None" then return "[ON]" end
    return "[" .. (type(v) == "string" and v ~= "" and v or fallback) .. "]"
end
local KB_DEFS = {
    { function() return cfg().ESP.Enabled end, "ВХ (ESP)", "KeyESP", "F1" },
    { function() return cfg().ESP.Skeleton end, "Скелет", "KeySkel", "F3" },
    { function() return cfg().ESP.Chams end, "Чамсы врагов" },
    { function() return cfg().Afterimage.Enabled end, "Sandevistan" },
    { function() return cfg().ThirdPerson.Enabled end, "3-е лицо", "KeyTP", "F5" },
    { function() return cfg().Crosshair.Enabled end, "Прицел" },
    { function() return cfg().Hitmarker.Enabled end, "Хитмаркер" },
    { function() return cfg().Overlay.TargetHUD end, "Target HUD" },
    { function() return cfg().Overlay.Speedometer end, "Спидометр" },
    { function() return cfg().Vignette.LowHP or cfg().Vignette.KillFlash end, "Виньетка" },
    { function() return cfg().World.SpeedFOV end, "Speed FOV" },
    { function() return cfg().Radar.Enabled end, "Мини-радар", "KeyRadar", "F4" },
    { function() return cfg().LookingAlert.Enabled end, "Тревога взгляда" },
    { function() return cfg().FootstepRings.Enabled end, "Кольца шагов" },
    { function() return cfg().SelfChams.Enabled end, "Чамсы на себя" },
    { function() return cfg().ChinaHat.Enabled end, "Шляпа / Нимб" },
    { function() return cfg().PlayerAura.Enabled end, "Аура" },
    { function() return cfg().Satellites.Enabled end, "Спутники" },
    { function() return cfg().ParticleTrail.Enabled end, "Ленты (Trail)" },
    { function() return cfg().Overlay.SpeedLines end, "Линии скорости" },
    { function() return cfg().Objects.Enabled end, "Object ESP" },
}
local function updateKeybindsHUD()
    local O = cfg().Overlay
    if not O.Keybinds then
        if ovState.kb then hideGroup("kb") ovState.kb = false end
        kbLastTick = 0
        hudState.kbHeight = 0
        hudState.rects.kb = nil
        return
    end
    local now = clock()
    if ovState.kb and (not O.DragHUD) and hudState.drag ~= "kb" and now - kbLastTick < 0.12 then return end
    kbLastTick, ovState.kb = now, true

    local n = 0
    for _, def in ipairs(KB_DEFS) do
        if def[1]() then
            n += 1
            kbLabels[n] = def[2]
            kbTags[n] = def[3] and kbTag(def[3], def[4]) or "[ON]"
        end
    end

    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or v2(1920, 1080)
    local w, h = 186, 24 + n * 16 + (n > 0 and 4 or 0)
    local x, y
    if O.KeybindsX and O.KeybindsX >= 0 and O.KeybindsY and O.KeybindsY >= 0 then
        x, y, hudState.kbHeight = clamp(floor(O.KeybindsX), 6, max(6, vp.X - w - 6)), clamp(floor(O.KeybindsY), 6, max(6, vp.Y - h - 6)), 0
    else
        x, y, hudState.kbHeight = 10, O.Watermark and 42 or 10, h
    end
    setHudRect("kb", x, y, w, h)
    local acc = O.Accent

    local bg = ov("kbBg", "Square", 1)
    bg.Position, bg.Size, bg.Filled = v2(x, y), v2(w, h), true
    bg.Color, bg.Transparency, bg.Visible = rgb(13, 14, 20), 0.8, true

    local bd = ov("kbBd", "Square", 2)
    bd.Position, bd.Size, bd.Filled, bd.Thickness = v2(x, y), v2(w, h), false, O.DragHUD and 1.5 or 1
    bd.Color, bd.Transparency, bd.Visible = O.DragHUD and acc or BLACK, O.DragHUD and 0.95 or 0.8, true

    local top = ov("kbTop", "Line", 3)
    top.From, top.To = v2(x, y), v2(x + w, y)
    top.Color, top.Thickness, top.Transparency, top.Visible = acc, 2, 1, true

    local hdr = ov("kbHdr", "Text", 4)
    hdr.Text, hdr.Size, hdr.Font, hdr.Center, hdr.Outline = "АКТИВНЫЕ МОДУЛИ", 12, 2, false, true
    hdr.Color, hdr.Position, hdr.Transparency, hdr.Visible = WHITE, v2(x + 8, y + 5), 1, true

    for i = 1, n do
        local ry = y + 23 + (i - 1) * 16
        local l = ov(KB_L[i], "Text", 4)
        l.Text, l.Size, l.Font, l.Center, l.Outline = kbLabels[i], 12, 2, false, true
        l.Color, l.Position, l.Transparency, l.Visible = GRAY, v2(x + 8, ry), 1, true

        local v, tag = ov(KB_R[i], "Text", 4), kbTags[i]
        v.Text, v.Size, v.Font, v.Center, v.Outline = tag, 11, 2, false, true
        local tw = kbWidthCache[tag]
        if not tw then
            local okb, bounds = pcall(function() return v.TextBounds end)
            tw = (okb and bounds and bounds.X > 0) and floor(bounds.X + 0.5) or floor(#tag * 6.2 + 0.5)
            if okb and bounds and bounds.X > 0 then kbWidthCache[tag] = tw end
        end
        v.Color, v.Position, v.Transparency, v.Visible = acc, v2(x + w - 8 - tw, ry + 1), 1, true
    end
    for i = n + 1, 24 do
        local l = overlayObjs[KB_L[i]]; if l then l.Visible = false end
        local v = overlayObjs[KB_R[i]]; if v then v.Visible = false end
    end
end

return {
    updateCrosshair = updateCrosshair,
    updateHitmarker = updateHitmarker,
    updateVignette = updateVignette,
    updateSpeedometer = updateSpeedometer,
    updateSpeedLines = updateSpeedLines,
    updateWatermark = updateWatermark,
    updateTargetHUD = updateTargetHUD,
    updateKeybindsHUD = updateKeybindsHUD,
}
end)()

local function validatePlayers()
    local e = cfg().ESP
    local espOn = e.Enabled
    local espMaxDist = e.UnlimitedDistance and math.huge or e.MaxDistance
    local espNormDist = e.UnlimitedDistance and 50000 or math.max(e.MaxDistance, 1)
    local radarOn = cfg().Radar.Enabled
    local radarRange = cfg().Radar.Range
    local lookOn = cfg().LookingAlert.Enabled
    local stepOn = cfg().FootstepRings.Enabled
    local needVis = (espOn and (e.VisibleCheck or e.Chams)) or cfg().Overlay.TargetHUD

    local maxTrackDist = 0
    if espOn or cfg().Overlay.TargetHUD or cfg().Hitmarker.Enabled or cfg().Hitmarker.KillEffect or cfg().Vignette.KillFlash then
        maxTrackDist = e.UnlimitedDistance and math.huge or math.max(maxTrackDist, espMaxDist)
    end
    if radarOn then maxTrackDist = math.max(maxTrackDist, radarRange) end
    if lookOn then maxTrackDist = math.max(maxTrackDist, cfg().LookingAlert.MaxDistance) end
    if stepOn then maxTrackDist = math.max(maxTrackDist, cfg().FootstepRings.MaxDistance) end

    local strictHideTeams = e.HideTeammates and (
        espOn or radarOn or e.SyncWithESP
        or ((not lookOn or cfg().LookingAlert.HideTeammates) and (not stepOn or cfg().FootstepRings.HideTeammates))
    )

    for plr, d in pairs(playersData) do
        local parts = d.parts
        local hrp = parts and parts.HumanoidRootPart
        local head = parts and parts.Head
        local hum = parts and parts.humanoid

        local team = isTeammate(plr)
        local trackable = plr.Parent == Players and isPartValid(hrp) and isPartValid(head) and hum
            and parts.Character and parts.Character.Parent
            and not (strictHideTeams and team)

        local dist = 0
        if trackable then
            dist = (cameraPos - hrp.Position).Magnitude
            if dist > maxTrackDist then trackable = false end
        end

        if trackable then
            trackDamagePopup(plr, d, parts)
        else
            d._lastHP = nil
        end

        local ok = trackable and hum.Health > 0

        if not ok then
            if not d._allHidden then
                hideAll(d)
                d._allHidden = true
                d._espHidden = true
                d._radarHidden = true
            end
            renderData[plr] = nil
        else
            d._allHidden = false
            local rd = renderData[plr] or {}
            if rd._lastChar ~= parts.Character then
                rd._lastChar = parts.Character
                rd._hpSmooth = nil
                rd._hpTrail = nil
                rd._txtReady = false
            end
            rd.parts = parts
            rd.distance = dist
            rd.team = team
            rd.teamColor = plr.Team and plr.TeamColor.Color or nil
            rd.inEsp = espOn and not (e.HideTeammates and team) and dist <= espMaxDist and dist >= e.MinDistance
            rd.inRadar = radarOn and not (e.HideTeammates and team) and dist <= radarRange
            rd.visible = needVis and isVisibleCached(d, head) or false
            rd.alpha = (espOn and e.DistanceFade) and (1 - 0.65 * clamp(dist / espNormDist, 0, 1)) or 1
            if not rd.inEsp then rd.priority = false end
            renderData[plr] = rd
        end
    end

    local wantPriority = (espOn and e.PriorityTarget) or cfg().Overlay.TargetHUD or cfg().Hitmarker.Enabled or cfg().Hitmarker.KillEffect or cfg().Vignette.KillFlash
    if not wantPriority then
        currentPriorityRd = nil
        for _, rd in pairs(renderData) do rd.priority = false end
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then currentPriorityRd = nil return end
    local vp = cam.ViewportSize
    local center = vp / 2
    local best, bestScore = nil, -math.huge
    for plr, rd in pairs(renderData) do
        local minOk = not espOn or rd.distance >= e.MinDistance
        if not (e.HideTeammates and rd.team) and rd.distance <= espMaxDist and minOk then
            local screenPt = rd.onScreen and rd.hrpScreen or nil
            if (not espOn or rd.onScreen == nil) and rd.parts and isPartValid(rd.parts.HumanoidRootPart) then
                local sp = cam:WorldToViewportPoint(partPos(rd.parts.HumanoidRootPart))
                if sp.Z > 0.1 then screenPt = Vector2.new(sp.X, sp.Y) end
            end
            if screenPt then
                local score = (rd.visible and 1 or 0)
                    - rd.distance / espNormDist
                    - (screenPt - center).Magnitude / (vp.X / 2) * 0.5
                if score > bestScore then best, bestScore = plr, score end
            end
        end
    end
    currentPriorityRd = best and renderData[best] or nil
    for plr, rd in pairs(renderData) do rd.priority = (espOn and e.PriorityTarget and plr == best and rd.inEsp) end
end

local function dynamicBounds(cam, parts)
    local xMin, yMin, xMax, yMax = math.huge, math.huge, -math.huge, -math.huge
    local validCorners = 0
    for i = 1, #DYN_NAMES do
        local p = parts[DYN_NAMES[i]]
        if isPartValid(p) then
            local cf, s = partCF(p), p.Size
            local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
            for sx = -1, 1, 2 do
                for sy = -1, 1, 2 do
                    for sz = -1, 1, 2 do
                        local v = cam:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(hx * sx, hy * sy, hz * sz)))
                        if v.Z > 0.1 then
                            validCorners += 1
                            if v.X < xMin then xMin = v.X end
                            if v.X > xMax then xMax = v.X end
                            if v.Y < yMin then yMin = v.Y end
                            if v.Y > yMax then yMax = v.Y end
                        end
                    end
                end
            end
        end
    end
    if validCorners < 4 or xMax <= xMin or yMax <= yMin then return nil end
    local vp = cam.ViewportSize
    xMin = clamp(xMin, -vp.X, vp.X * 2)
    xMax = clamp(xMax, -vp.X, vp.X * 2)
    yMin = clamp(yMin, -vp.Y, vp.Y * 2)
    yMax = clamp(yMax, -vp.Y, vp.Y * 2)
    if xMax <= xMin or yMax <= yMin then return nil end
    return xMin, xMax, yMin, yMax
end

local function projectPlayers()
    local cam = workspace.CurrentCamera
    local vp = cam.ViewportSize
    local m = 300
    local e = cfg().ESP
    local wantDot = e.HeadDot
    local dyn = e.BoxFit == "Dynamic"
    for _, rd in pairs(renderData) do
        rd.headDotScreen, rd.headDotR, rd.dynL = nil, nil, nil
        if not rd.inEsp then
            rd.onScreen, rd.headScreen, rd.legScreen, rd.hrpScreen = false, nil, nil, nil
        else
            local parts = rd.parts
            local hrp, head = parts.HumanoidRootPart, parts.Head
            if isPartValid(hrp) and isPartValid(head) then
                local hpos, rpos = partPos(head), partPos(hrp)
                local h3 = cam:WorldToViewportPoint(hpos + v3(0, 0.5, 0))
                local l3 = cam:WorldToViewportPoint(rpos - v3(0, 3, 0))
                local r3 = cam:WorldToViewportPoint(rpos)
                if h3.Z > 0.1 and l3.Z > 0.1 then
                    rd.headScreen = v2(h3.X, h3.Y)
                    rd.legScreen  = v2(l3.X, l3.Y)
                    rd.hrpScreen  = v2(r3.X, r3.Y)
                    local cx, cy = rd.hrpScreen.X, rd.hrpScreen.Y
                    rd.onScreen = cx > -m and cx < vp.X + m and cy > -m and cy < vp.Y + m
                    if wantDot then
                        local hd = cam:WorldToViewportPoint(hpos)
                        if hd.Z > 0.1 then
                            rd.headDotScreen = v2(hd.X, hd.Y)
                            local up = partCF(head).UpVector * (head.Size.Y / 2)
                            local a = cam:WorldToViewportPoint(hpos + up)
                            local b = cam:WorldToViewportPoint(hpos - up)
                            rd.headDotR = max(2, abs(a.Y - b.Y) / 2)
                        end
                    end
                    if dyn and rd.onScreen and rd.distance <= 400 then
                        rd.dynL, rd.dynR, rd.dynT, rd.dynB = dynamicBounds(cam, parts)
                    end
                else
                    rd.onScreen, rd.headScreen, rd.legScreen, rd.hrpScreen = false, nil, nil, nil
                end
            else
                rd.onScreen, rd.headScreen, rd.legScreen, rd.hrpScreen = false, nil, nil, nil
            end
        end
    end
end

local chamsCandidates = {}
local chamsAllowed = {}
local function sortChamsDist(a, b) return a.dist < b.dist end

local function updateChamsBudget()
    table.clear(chamsAllowed)
    local e = cfg().ESP
    if not (e.Enabled and e.Chams) then return end
    local n = 0
    for plr, rd in pairs(renderData) do
        if rd.inEsp then
            local d = playersData[plr]
            local char = d and d.parts and d.parts.Character
            if char and char.Parent then
                n += 1
                local slot = chamsCandidates[n]
                if not slot then
                    slot = { plr = plr, dist = math.huge }
                    chamsCandidates[n] = slot
                end
                slot.plr = plr
                slot.dist = rd.distance or math.huge
            end
        end
    end
    for i = n + 1, #chamsCandidates do
        chamsCandidates[i].dist = math.huge
    end
    if n > 1 then
        table.sort(chamsCandidates, sortChamsDist)
    end
    local lim = math.min(n, C.MAX_CHAMS)
    for i = 1, lim do
        chamsAllowed[chamsCandidates[i].plr] = true
    end
end

local function updateESP(dt)
    if isUnloaded then return end
    local espOn = cfg().ESP.Enabled
    local radarOn = cfg().Radar.Enabled
    local needPlayers = espOn or radarOn or cfg().Overlay.TargetHUD or cfg().Hitmarker.Enabled or cfg().Hitmarker.KillEffect or cfg().Vignette.KillFlash or cfg().LookingAlert.Enabled or cfg().FootstepRings.Enabled
    useRCF = HAS_RCF and cfg().ESP.SmoothCF

    if not needPlayers then
        ticks.esp, currentPriorityRd = false, nil
        for _, d in pairs(playersData) do
            if not d._allHidden then
                hideAll(d)
                d._allHidden, d._espHidden, d._radarHidden = true, true, true
            end
        end
        updateDamagePopups()
        return
    end

    refreshModuleChars()

    if espOn ~= ticks.esp then
        ticks.esp, ticks.val = espOn, 0
    end

    local now = clock()
    if now - ticks.val >= C.VALIDATE_INTERVAL then
        ticks.val = now
        validatePlayers()
    end

    if not espOn then
        for plr, d in pairs(playersData) do
            if not d._espHidden then
                hideESP(d)
                d._espHidden = true
            end
            local rd = renderData[plr]
            if radarOn and rd and rd.inRadar and d.drawings then
                d._allHidden = false
                drawRadarDot(d.drawings, rd)
            elseif d.drawings and not d._radarHidden then
                ESPDraw.hideRadar(d.drawings)
                d._radarHidden = true
            end
        end
        updateDamagePopups()
        return
    end

    projectPlayers()
    updateChamsBudget()

    local doText = (now - ticks.txt >= C.TEXT_INTERVAL)
    if doText then ticks.txt = now end

    for plr, rd in pairs(renderData) do
        local d = playersData[plr]
        if d and rd and d.drawings then
            local dr = d.drawings
            if rd.inEsp then
                d._espHidden, d._allHidden = false, false
                ESPDraw.drawBox(dr, rd.parts, rd)
                ESPDraw.drawHealthBar(dr, rd.parts, rd, dt)
                ESPDraw.drawHeadDot(dr, rd.parts, rd)
                ESPDraw.drawLook(dr, rd.parts, rd)
                ESPDraw.drawTracer(dr, rd)
                ESPDraw.drawSkeleton(dr, rd.parts, rd)
                ESPDraw.drawText(dr, rd.parts, rd, doText)
                ESPDraw.drawArrow(dr, rd)
                ESPDraw.drawPriorityMarker(dr, rd.parts, rd)
                syncChams(plr, d, rd, chamsAllowed[plr] == true)
            elseif not d._espHidden then
                hideESP(d)
                d._espHidden = true
            end
            if rd.inRadar then
                d._radarHidden, d._allHidden = false, false
                drawRadarDot(dr, rd)
            elseif not d._radarHidden then
                ESPDraw.hideRadar(dr)
                d._radarHidden = true
            end
        end
    end

    updateDamagePopups()
end

local Obj, updateObjects, destroyObjects = (function()
local state = { list = {}, custom = {}, draws = {}, last = 0, scanning = false }

local function resolvePart(inst)
    if typeof(inst) ~= "Instance" then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function isPlayerPart(inst)
    for plr, d in pairs(playersData) do
        local ch = (d.parts and d.parts.Character) or getChar(plr)
        if ch and (inst == ch or inst:IsDescendantOf(ch)) then return true end
    end
    local lc = getChar(LP) or LP.Character
    return lc ~= nil and (inst == lc or inst:IsDescendantOf(lc))
end

local function hasMatchedAncestor(inst, matched)
    local p = inst.Parent
    while p and p ~= workspace do
        if matched[p] then return true end
        p = p.Parent
    end
    return false
end

local function sortObjDist(a, b) return a.dist < b.dist end

local function parseObjFilter(raw)
    local inc, exc = {}, {}
    for token in string.gmatch(string.lower(raw or ""), "[^,;]+") do
        local t = token:match("^%s*(.-)%s*$")
        if t and t ~= "" then
            local first = t:sub(1, 1)
            if (first == "-" or first == "!") and #t > 1 then
                local ex = t:sub(2):match("^%s*(.-)%s*$")
                if ex and ex ~= "" then exc[#exc + 1] = ex end
            elseif first ~= "-" and first ~= "!" then
                inc[#inc + 1] = t
            end
        end
    end
    return inc, exc
end

local function matchesObjFilter(nameLower, inc, exc)
    local ok = false
    for k = 1, #inc do
        if string.find(nameLower, inc[k], 1, true) then ok = true break end
    end
    if not ok then return false end
    for k = 1, #exc do
        if string.find(nameLower, exc[k], 1, true) then return false end
    end
    return true
end

local function scanObjects()
    if state.scanning then return end
    state.scanning = true
    local inc, exc = parseObjFilter(cfg().Objects.Filter)
    local found, matched, n = {}, {}, 0
    local cam = workspace.CurrentCamera
    if #inc > 0 then
        pcall(function()
            for i, inst in ipairs(workspace:GetDescendants()) do
                if i % 4000 == 0 then
                    task.wait()
                    if isUnloaded then error("unloaded") end
                end
                if (inst:IsA("BasePart") or inst:IsA("Model"))
                    and inst ~= cam and (not cam or not inst:IsDescendantOf(cam))
                    and inst.Name:sub(1, 7) ~= "Glupost"
                    and not hasMatchedAncestor(inst, matched)
                    and matchesObjFilter(string.lower(inst.Name), inc, exc)
                    and not isPlayerPart(inst) then
                    matched[inst] = true
                    local part = resolvePart(inst)
                    if part then
                        n += 1
                        found[n] = { part = part, text = inst.Name, dist = (part.Position - cameraPos).Magnitude }
                        if n >= 3000 then break end
                    end
                end
            end
        end)
        table.sort(found, sortObjDist)
        for i = #found, 301, -1 do found[i] = nil end
    end
    if not isUnloaded then
        state.list = found
    end
    state.scanning = false
end

local function drawObject(idx, pos, text, color, dist)
    local cam = workspace.CurrentCamera
    local sp = cam:WorldToViewportPoint(pos)
    if sp.Z <= 0.1 then return false end
    local e, O = cfg().ESP, cfg().Objects

    local D = state.draws[idx]
    if not D then
        D = { text = poolGet("Text"), line = poolGet("Line") }
        pcall(function() D.text.ZIndex, D.line.ZIndex = 6, 4 end)
        D.text.Center, D.text.OutlineColor = true, BLACK
        state.draws[idx] = D
    end

    local t = D.text
    t.Text = O.ShowDistance and string.format("%s [%d]", text, math.floor(dist)) or text
    t.Size, t.Font, t.Outline = e.TextSize, FONTS[e.FontName] or 2, e.TextOutline
    t.Position = Vector2.new(math.floor(sp.X + 0.5), math.floor(sp.Y - e.TextSize - 2 + 0.5))
    t.Color, t.Transparency, t.Visible = color, 1, true

    local l = D.line
    if O.ShowTracer then
        local vp = cam.ViewportSize
        l.From, l.To = Vector2.new(vp.X / 2, vp.Y), Vector2.new(sp.X, sp.Y)
        l.Color, l.Thickness, l.Transparency, l.Visible = color, 1, 0.6, true
    else
        l.Visible = false
    end
    return true
end

local seenCustomParts = {}
local function updateObj()
    local O = cfg().Objects
    local count = 0
    if O.Enabled then
        local now = clock()
        if now - state.last >= O.Interval then
            state.last = now
            task.spawn(scanObjects)
        end
        local maxDist = O.UnlimitedDistance and math.huge or O.MaxDistance
        local hasCustom = next(state.custom) ~= nil
        if hasCustom then table.clear(seenCustomParts) end
        for inst, it in pairs(state.custom) do
            if count >= O.MaxCount then break end
            if it.part and it.part.Parent then
                if hasCustom then seenCustomParts[it.part] = true end
                local pos = partPos(it.part)
                local dist = (pos - cameraPos).Magnitude
                if dist <= maxDist and drawObject(count + 1, pos, it.text, it.color or O.Color, dist) then
                    count += 1
                end
            else
                state.custom[inst] = nil
            end
        end
        for i = 1, #state.list do
            if count >= O.MaxCount then break end
            local it = state.list[i]
            local part = it.part
            if part and part.Parent and (not hasCustom or not seenCustomParts[part]) then
                local pos = partPos(part)
                local dist = (pos - cameraPos).Magnitude
                if dist <= maxDist and drawObject(count + 1, pos, it.text, O.Color, dist) then
                    count += 1
                end
            end
        end
    end
    for i = count + 1, #state.draws do
        local D = state.draws[i]
        D.text.Visible, D.line.Visible = false, false
    end
end

local function destroyObj()
    for _, D in pairs(state.draws) do
        poolPut("Text", D.text)
        poolPut("Line", D.line)
    end
    table.clear(state.draws)
    table.clear(state.list)
    table.clear(state.custom)
end

getgenv_().GlupostObjects = {
    Add = function(inst, text, color)
        local part = resolvePart(inst)
        if part then state.custom[inst] = { part = part, text = text or inst.Name, color = color } end
    end,
    Remove = function(inst) state.custom[inst] = nil end,
    Clear = function() table.clear(state.custom) end,
}

return state, updateObj, destroyObj
end)()

local tagOrig = setmetatable({}, { __mode = "k" })

local function updateDefaultTags()
    local now = clock()
    if now - ticks.tags < 1 then return end
    ticks.tags = now
    local hide = cfg().ESP.Enabled and cfg().ESP.HideDefaultTags
    for _, d in pairs(playersData) do
        local hum = d.parts and d.parts.humanoid
        if hum and hum.Parent then
            if hide then
                if tagOrig[hum] == nil then tagOrig[hum] = hum.DisplayDistanceType end
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            elseif tagOrig[hum] ~= nil then
                hum.DisplayDistanceType = tagOrig[hum]
                tagOrig[hum] = nil
            end
        end
    end
end

local function restoreTags()
    for hum, orig in pairs(tagOrig) do
        pcall(function() hum.DisplayDistanceType = orig end)
    end
    table.clear(tagOrig)
end

local WorldMod = (function()
local worldOrig = { atm = {} }
local gradeFx, bloomFx = nil, nil
local customSky, weatherPart, weatherEmitter, weatherEmitter2, weatherModeCur = nil, nil, nil, nil, nil
local speedFovSmooth, appliedSpeedKick, lastWindTick = 0, 0, 0

local function clearWeather()
    if weatherPart then safeDestroy(weatherPart) end
    weatherPart, weatherEmitter, weatherEmitter2, weatherModeCur = nil, nil, nil, nil
end

local WEATHER_DEFS = {
    Rain = {
        Name = "GlupostWeatherEmitter", vol = false, volShape = true, initBurst = 0.25,
        yOff = 9, yVec = v3(0, 9, 0), boxSize = v3(48, 10, 48), rate = 240,
        LifeMin = 0.55, LifeMax = 0.85, SpdMin = 42, SpdMax = 56,
        Dir = Enum.NormalId.Bottom, Spread = v2(6, 6), Orient = Enum.ParticleOrientation.VelocityParallel,
        Squash = -1.8, Size = 0.28, Light = 0.45,
        Color = ColorSequence.new(rgb(165, 205, 255)),
        Tr = { { 0, 0.4 }, { 1, 0.85 } },
    },
    Snow = {
        Name = "GlupostWeatherEmitter", vol = false, volShape = true, initBurst = 0.35, windSway = true,
        windBase = { 1.2, -0.8, 0.7 }, windAmp = { 1.6, 1.3 },
        yOff = 8, yVec = v3(0, 8, 0), boxSize = v3(44, 12, 44), rate = 115,
        LifeMin = 2.0, LifeMax = 3.2, SpdMin = 5.5, SpdMax = 10.5,
        Dir = Enum.NormalId.Bottom, Spread = v2(28, 28), Accel = v3(1.2, -0.8, 0.7), Drag = 0.25,
        Rot = NumberRange.new(0, 360), RotSpd = NumberRange.new(-90, 90),
        Size = { { 0, 0.16 }, { 0.3, 0.26 }, { 1, 0.12 } }, Light = 0.55,
        Color = ColorSequence.new(rgb(240, 248, 255), rgb(210, 232, 255)),
        Tr = { { 0, 0.85 }, { 0.15, 0.12 }, { 0.85, 0.2 }, { 1, 0.95 } },
        layer2 = {
            Name = "GlupostWeatherEmitter2", volShape = true, rate = 45,
            LifeMin = 2.2, LifeMax = 3.4, SpdMin = 3.5, SpdMax = 7.0,
            Dir = Enum.NormalId.Bottom, Spread = v2(38, 38), Accel = v3(0.9, -0.6, 0.5), Drag = 0.3,
            Rot = NumberRange.new(0, 360), RotSpd = NumberRange.new(-140, 140),
            Size = { { 0, 0.08 }, { 0.4, 0.15 }, { 1, 0 } }, Light = 0.85,
            Color = ColorSequence.new(WHITE, rgb(215, 240, 255)),
            Tr = { { 0, 0.9 }, { 0.25, 0.22 }, { 1, 1 } },
        },
    },
    Embers = {
        Name = "GlupostWeatherEmitter", vol = true, volShape = true, initBurst = 0.35, windSway = true,
        windBase = { 0.9, 3.4, 0.5 }, windAmp = { 1.7, 1.4 },
        yOff = -4.5, rate = 90,
        LifeMin = 1.6, LifeMax = 2.8, SpdMin = 3.5, SpdMax = 8.0,
        Dir = Enum.NormalId.Top, Spread = v2(35, 35), Accel = v3(0.9, 3.4, 0.5),
        Rot = NumberRange.new(0, 360), RotSpd = NumberRange.new(-160, 160),
        Size = { { 0, 0.18 }, { 0.6, 0.14 }, { 1, 0 } }, Light = 1,
        Color = ColorSequence.new(rgb(255, 205, 70), rgb(255, 60, 40)),
        Tr = { { 0, 0.85 }, { 0.3, 0.1 }, { 1, 1 } },
    },
    Fireflies = {
        Name = "GlupostWeatherEmitter", vol = true, volShape = true, initBurst = 0.4,
        yOff = 1.5, rate = 48,
        LifeMin = 2.0, LifeMax = 3.4, SpdMin = 0.4, SpdMax = 1.5,
        Spread = v2(180, 180), Drag = 1.2,
        Size = { { 0, 0 }, { 0.5, 0.28 }, { 1, 0 } }, Light = 1,
        Color = ColorSequence.new(rgb(180, 255, 110), rgb(255, 225, 95)),
        Tr = { { 0, 1 }, { 0.4, 0.08 }, { 1, 1 } },
        layer2 = {
            Name = "GlupostWeatherEmitter2", volShape = true, rate = 24,
            LifeMin = 1.6, LifeMax = 2.8, SpdMin = 0.3, SpdMax = 1.1,
            Spread = v2(180, 180), Drag = 1.4,
            Size = { { 0, 0 }, { 0.5, 0.16 }, { 1, 0 } }, Light = 1,
            Color = ColorSequence.new(rgb(255, 245, 165), rgb(140, 255, 175)),
            Tr = { { 0, 1 }, { 0.35, 0.18 }, { 1, 1 } },
        },
    },
    CyberDust = {
        Name = "GlupostWeatherEmitter", vol = true, volShape = true, initBurst = 0.35,
        yOff = 1.5, rate = 70,
        LifeMin = 1.5, LifeMax = 2.6, SpdMin = 0.8, SpdMax = 2.2,
        Spread = v2(180, 180),
        Size = { { 0, 0.14 }, { 0.5, 0.2 }, { 1, 0 } }, Light = 1,
        Color = ColorSequence.new(rgb(0, 235, 255), rgb(220, 65, 255)),
        Tr = { { 0, 0.9 }, { 0.4, 0.2 }, { 1, 1 } },
    },
    Sakura = {
        Name = "GlupostWeatherEmitter", vol = false, yOff = 6, yVec = v3(0, 6, 0),
        boxSize = v3(38, 12, 38), lookDist = 14, windSway = true, volShape = true, initBurst = 0.45,
        windBase = { 2.8, -1.6, 1.5 }, windAmp = { 2.5, 2.1 }, rate = 140,
        LifeMin = 3.0, LifeMax = 4.6, SpdMin = 4.8, SpdMax = 8.4,
        Dir = Enum.NormalId.Bottom, Spread = v2(34, 34), Accel = v3(2.8, -1.6, 1.5), Drag = 0.25, VelInherit = 0.12,
        Rot = NumberRange.new(0, 360), RotSpd = NumberRange.new(-175, 175),
        Squash = { { 0, 0.55 }, { 0.5, -0.35 }, { 1, 0.48 } },
        Size = { { 0, 0.22 }, { 0.18, 0.44 }, { 0.75, 0.38 }, { 1, 0.16 } }, Light = 0.48,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, rgb(255, 228, 242)),
            ColorSequenceKeypoint.new(0.5, rgb(255, 165, 210)),
            ColorSequenceKeypoint.new(1, rgb(255, 115, 180)),
        }),
        Tr = { { 0, 0.9 }, { 0.15, 0.12 }, { 0.82, 0.18 }, { 1, 1 } },
        layer2 = {
            Name = "GlupostWeatherEmitter2", volShape = true, rate = 60,
            LifeMin = 2.4, LifeMax = 3.8, SpdMin = 2.8, SpdMax = 5.6,
            Dir = Enum.NormalId.Bottom, Spread = v2(52, 52), Accel = v3(2.0, -1.2, 1.2), Drag = 0.30, VelInherit = 0.10,
            Rot = NumberRange.new(0, 360), RotSpd = NumberRange.new(-230, 230),
            Squash = { { 0, -0.45 }, { 0.5, 0.45 }, { 1, -0.35 } },
            Size = { { 0, 0.16 }, { 0.25, 0.32 }, { 0.8, 0.24 }, { 1, 0 } }, Light = 0.85,
            Color = ColorSequence.new(rgb(255, 242, 248), rgb(255, 150, 205)),
            Tr = { { 0, 0.9 }, { 0.2, 0.2 }, { 0.8, 0.28 }, { 1, 1 } },
        },
    },
    MatrixRain = {
        Name = "GlupostWeatherEmitter", vol = false, volShape = true, initBurst = 0.25,
        yOff = 9, yVec = v3(0, 9, 0), boxSize = v3(48, 10, 48), rate = 180,
        LifeMin = 0.65, LifeMax = 1.05, SpdMin = 26, SpdMax = 38,
        Dir = Enum.NormalId.Bottom, Spread = v2(2, 2), Orient = Enum.ParticleOrientation.VelocityParallel,
        Squash = -1.6, Size = 0.26, Light = 1,
        Color = ColorSequence.new(rgb(130, 255, 175), rgb(25, 215, 95)),
        Tr = { { 0, 0.25 }, { 1, 0.9 } },
    },
    Starfall = {
        Name = "GlupostWeatherEmitter", vol = false, volShape = true, initBurst = 0.35,
        yOff = 10, yVec = v3(0, 10, 0), boxSize = v3(46, 10, 46), rate = 80,
        LifeMin = 0.75, LifeMax = 1.25, SpdMin = 30, SpdMax = 44,
        Dir = Enum.NormalId.Bottom, Spread = v2(16, 16), Accel = v3(-14, -4, -8),
        Orient = Enum.ParticleOrientation.VelocityParallel, Squash = -2.2, Size = 0.30, Light = 1,
        Color = ColorSequence.new(rgb(135, 235, 255), rgb(255, 225, 130)),
        Tr = { { 0, 0.15 }, { 0.75, 0.35 }, { 1, 1 } },
        layer2 = {
            Name = "GlupostWeatherEmitter2", volShape = true, rate = 50,
            LifeMin = 1.1, LifeMax = 1.9, SpdMin = 6, SpdMax = 12,
            Dir = Enum.NormalId.Bottom, Spread = v2(32, 32), Accel = v3(-5, -1, -3),
            Rot = NumberRange.new(0, 360), RotSpd = NumberRange.new(-160, 160),
            Size = { { 0, 0.1 }, { 0.35, 0.22 }, { 1, 0 } }, Light = 1,
            Color = ColorSequence.new(rgb(200, 245, 255), rgb(255, 225, 155)),
            Tr = { { 0, 0.8 }, { 0.3, 0.15 }, { 1, 1 } },
        },
    },
    BloodRain = {
        Name = "GlupostWeatherEmitter", vol = false, volShape = true, initBurst = 0.25,
        yOff = 9, yVec = v3(0, 9, 0), boxSize = v3(48, 10, 48), rate = 220,
        LifeMin = 0.50, LifeMax = 0.80, SpdMin = 44, SpdMax = 58,
        Dir = Enum.NormalId.Bottom, Spread = v2(6, 6), Orient = Enum.ParticleOrientation.VelocityParallel,
        Squash = -1.8, Size = 0.28, Light = 0.75,
        Color = ColorSequence.new(rgb(255, 70, 90), rgb(185, 20, 45)),
        Tr = { { 0, 0.25 }, { 1, 0.88 } },
    },
}

local function ensureWeather(mode, intensity, cam)
    local def = WEATHER_DEFS[mode] or WEATHER_DEFS.CyberDust
    local mult = clamp(intensity, 0.2, 1.5)
    local rate = floor(def.rate * mult)
    local yVec = def.yVec or v3(0, def.yOff, 0)
    if not def.yVec then def.yVec = yVec end
    local targetCF = cfNew(cam.CFrame.Position + cam.CFrame.LookVector * (def.lookDist or 12) + yVec)
    if weatherPart and weatherPart.Parent and weatherModeCur == mode then
        weatherPart.CFrame = targetCF
        if weatherEmitter and weatherEmitter.Rate ~= rate then weatherEmitter.Rate = rate end
        if weatherEmitter2 and def.layer2 then
            local rate2 = floor(def.layer2.rate * mult)
            if weatherEmitter2.Rate ~= rate2 then weatherEmitter2.Rate = rate2 end
        end
        if def.windSway and weatherEmitter then
            local now = clock()
            if now - lastWindTick >= 0.08 then
                lastWindTick = now
                local wb, wa = def.windBase, def.windAmp
                local bx, by, bz = wb and wb[1] or 2.8, wb and wb[2] or -1.6, wb and wb[3] or 1.5
                local ax, az = wa and wa[1] or 2.5, wa and wa[2] or 2.1
                local wx = bx + sin(now * 0.68) * ax
                local wz = bz + cos(now * 0.52) * az
                weatherEmitter.Acceleration = v3(wx, by, wz)
                if weatherEmitter2 then
                    weatherEmitter2.Acceleration = v3(wx * 0.75 + cos(now * 0.9) * 0.9, by * 0.75, wz * 0.75 + sin(now * 0.8) * 0.9)
                end
            end
        end
        return
    end
    clearWeather()
    weatherModeCur = mode
    local p = Instance.new("Part")
    p.Name, p.Anchored, p.CastShadow, p.Transparency = "GlupostWeatherPart", true, false, 1
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    p.Size = def.boxSize or (def.vol and v3(42, 18, 42) or v3(54, 4, 54))
    p.CFrame = targetCF
    local em = makeEmitter(p, def)
    em.Rate = rate
    local em2 = nil
    if def.layer2 then
        em2 = makeEmitter(p, def.layer2)
        em2.Rate = floor(def.layer2.rate * mult)
    end
    p.Parent = workspace.CurrentCamera or workspace
    if def.initBurst then
        pcall(function()
            em:Emit(floor(rate * def.initBurst))
            if em2 then em2:Emit(floor(em2.Rate * def.initBurst)) end
        end)
    end
    weatherPart, weatherEmitter, weatherEmitter2 = p, em, em2
end

local SKY_PROPS = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "StarCount", "CelestialBodiesShown", "MoonAngularSize", "SunAngularSize" }
local lastSkyRef, lastSkyMode = nil, nil
local lastAtmScan, wasFovEnabled = 0, false

local function restoreSky()
    if worldOrig.skyRef and worldOrig.skyProps then
        pcall(function()
            for k, v in pairs(worldOrig.skyProps) do worldOrig.skyRef[k] = v end
        end)
    end
    worldOrig.skyRef, worldOrig.skyProps = nil, nil
    lastSkyRef, lastSkyMode = nil, nil
    if customSky then safeDestroy(customSky) customSky = nil end
end

local function applySkyPreset(presetName)
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then
        if not customSky or not customSky.Parent then
            customSky = Instance.new("Sky")
            customSky.Name = HttpSvc:GenerateGUID(false)
            customSky.Parent = Lighting
        end
        sky = customSky
    elseif not worldOrig.skyProps then
        worldOrig.skyRef = sky
        worldOrig.skyProps = {}
        for _, k in ipairs(SKY_PROPS) do
            pcall(function() worldOrig.skyProps[k] = sky[k] end)
        end
    end

    if lastSkyRef == sky and lastSkyMode == presetName then return end
    lastSkyRef, lastSkyMode = sky, presetName

    if presetName == "Clean Night" or presetName == "Cyberpunk" or presetName == "Blood Moon" or presetName == "Emerald Matrix" or presetName == "Tokyo Neon" or presetName == "Crimson Void" or presetName == "Midnight Mist" then
        pcall(function()
            sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = "", "", ""
            sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = "", "", ""
            sky.StarCount = (presetName == "Cyberpunk" or presetName == "Emerald Matrix" or presetName == "Tokyo Neon") and 4200 or 5000
            sky.CelestialBodiesShown = true
            sky.MoonAngularSize = (presetName == "Blood Moon" or presetName == "Crimson Void") and 22 or 12
        end)
    elseif presetName == "Cold Frost" or presetName == "Warm Sunset" or presetName == "Solar Gold" or presetName == "Sakura Dusk" or presetName == "Golden Dawn" then
        if sky == customSky then
            safeDestroy(customSky)
            customSky = Instance.new("Sky")
            customSky.Name = HttpSvc:GenerateGUID(false)
            customSky.Parent = Lighting
            sky = customSky
            lastSkyRef = sky
        elseif worldOrig.skyRef == sky and worldOrig.skyProps then
            pcall(function()
                for _, k in ipairs({ "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "MoonAngularSize" }) do
                    if worldOrig.skyProps[k] ~= nil then sky[k] = worldOrig.skyProps[k] end
                end
            end)
        end
        pcall(function()
            sky.StarCount = 1800
            sky.CelestialBodiesShown = true
            sky.SunAngularSize = (presetName == "Solar Gold") and 26 or ((presetName == "Warm Sunset" or presetName == "Sakura Dusk" or presetName == "Golden Dawn") and 24 or 16)
        end)
    end
end

local function update(dt)
    local W = cfg().World
    local cam = workspace.CurrentCamera
    local preset = WORLD_PRESETS[W.Preset]

    if preset then
        if worldOrig.brightness == nil then
            worldOrig.brightness = Lighting.Brightness
            worldOrig.exposure = Lighting.ExposureCompensation
            worldOrig.shiftTop = Lighting.ColorShift_Top
        end
        if Lighting.Brightness ~= preset.Brightness then Lighting.Brightness = preset.Brightness end
        if Lighting.ExposureCompensation ~= preset.Exposure then Lighting.ExposureCompensation = preset.Exposure end
        if Lighting.ColorShift_Top ~= preset.ColorShiftTop then Lighting.ColorShift_Top = preset.ColorShiftTop end
    elseif worldOrig.brightness ~= nil then
        Lighting.Brightness = worldOrig.brightness
        Lighting.ExposureCompensation = worldOrig.exposure
        Lighting.ColorShift_Top = worldOrig.shiftTop
        worldOrig.brightness, worldOrig.exposure, worldOrig.shiftTop = nil, nil, nil
    end

    local skyMode = W.SkyPreset == "Auto" and W.Preset or W.SkyPreset
    if skyMode and skyMode ~= "None" then
        applySkyPreset(skyMode)
    elseif worldOrig.skyProps or customSky then
        restoreSky()
    end

    if W.Weather ~= "None" and cam then
        ensureWeather(W.Weather, W.WeatherIntensity or 0.6, cam)
    elseif weatherPart then
        clearWeather()
    end

    if W.TimeEnabled then
        if worldOrig.time == nil then worldOrig.time = Lighting.ClockTime end
        if abs(Lighting.ClockTime - W.Time) > 0.005 then Lighting.ClockTime = W.Time end
    elseif worldOrig.time ~= nil then
        Lighting.ClockTime = worldOrig.time
        worldOrig.time = nil
    end

    if cam then
        local kick = 0
        if W.SpeedFOV then
            local root = getRootPart(LP and LP.Character)
            local targetKick = 0
            if isPartValid(root) then
                local vel = root.AssemblyLinearVelocity or root.Velocity
                local spd = vel.Magnitude
                if spd > 14 then
                    targetKick = clamp((spd - 14) * 0.38 * (W.SpeedFOVSens or 1), 0, W.SpeedFOVMax or 15)
                end
            end
            speedFovSmooth = speedFovSmooth + (targetKick - speedFovSmooth) * clamp((dt or 0.016) * 8, 0, 1)
            kick = speedFovSmooth
        else
            speedFovSmooth = 0
        end

        if W.FOVEnabled then
            if worldOrig.fov == nil then worldOrig.fov = cam.FieldOfView - appliedSpeedKick end
            wasFovEnabled = true
            local curFov = cam.FieldOfView
            local applied = worldOrig.appliedFOV
            local gameZooming = applied ~= nil and (curFov < applied - 2) and (curFov < (worldOrig.fov or 70) - 2)
            if not gameZooming then
                local target = clamp(W.FOV + kick, 40, 120)
                if curFov ~= target then cam.FieldOfView = target end
                worldOrig.appliedFOV = target
                appliedSpeedKick = kick
            end
        elseif W.SpeedFOV and kick > 0.05 then
            local curFov = cam.FieldOfView
            local applied = worldOrig.appliedFOV
            local gameZooming = applied ~= nil and (curFov < applied - 2)
            if not gameZooming then
                local baseFov
                if wasFovEnabled and worldOrig.fov ~= nil then
                    baseFov = worldOrig.fov
                    wasFovEnabled = false
                elseif applied ~= nil and math.abs(curFov - applied) < 1.5 then
                    baseFov = curFov - appliedSpeedKick
                else
                    baseFov = curFov
                    worldOrig.fov = curFov
                end
                local target = clamp(baseFov + kick, 40, 120)
                if curFov ~= target then cam.FieldOfView = target end
                worldOrig.appliedFOV = target
                appliedSpeedKick = kick
            end
        elseif worldOrig.fov ~= nil or appliedSpeedKick > 0 then
            if wasFovEnabled and worldOrig.fov ~= nil then
                cam.FieldOfView = worldOrig.fov
            elseif appliedSpeedKick > 0 and worldOrig.appliedFOV ~= nil and math.abs(cam.FieldOfView - worldOrig.appliedFOV) < 1.5 then
                cam.FieldOfView = clamp(cam.FieldOfView - appliedSpeedKick, 40, 120)
            elseif worldOrig.fov ~= nil and not W.SpeedFOV then
                cam.FieldOfView = worldOrig.fov
            end
            wasFovEnabled = false
            worldOrig.fov = nil
            worldOrig.appliedFOV = nil
            appliedSpeedKick = 0
        else
            wasFovEnabled = false
        end
    end

    if W.NoFog then
        if worldOrig.fogEnd == nil then
            worldOrig.fogEnd = Lighting.FogEnd
            lastAtmScan = 0
        end
        if worldOrig.fogStart == nil then worldOrig.fogStart = Lighting.FogStart end
        if Lighting.FogStart ~= 1e5 then Lighting.FogStart = 1e5 end
        if Lighting.FogEnd ~= 1e6 then Lighting.FogEnd = 1e6 end
        local now = clock()
        if now - lastAtmScan >= 0.5 then
            lastAtmScan = now
            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("Atmosphere") and worldOrig.atm[child] == nil then
                    worldOrig.atm[child] = { d = child.Density, h = child.Haze, g = child.Glare }
                end
            end
        end
        for atm in pairs(worldOrig.atm) do
            if atm and atm.Parent then
                if atm.Density ~= 0 then atm.Density = 0 end
                if atm.Haze ~= 0 then atm.Haze = 0 end
                if atm.Glare ~= 0 then atm.Glare = 0 end
            else
                worldOrig.atm[atm] = nil
            end
        end
    elseif worldOrig.fogEnd ~= nil then
        Lighting.FogEnd = worldOrig.fogEnd
        Lighting.FogStart = worldOrig.fogStart
        worldOrig.fogEnd, worldOrig.fogStart = nil, nil
        for atm, orig in pairs(worldOrig.atm) do
            if atm and atm.Parent then
                atm.Density, atm.Haze, atm.Glare = orig.d, orig.h, orig.g
            end
        end
        table.clear(worldOrig.atm)
    end

    if W.AmbientEnabled then
        if worldOrig.ambient == nil then worldOrig.ambient = Lighting.Ambient end
        if worldOrig.outdoor == nil then worldOrig.outdoor = Lighting.OutdoorAmbient end
        if Lighting.Ambient ~= W.Ambient then Lighting.Ambient = W.Ambient end
        if Lighting.OutdoorAmbient ~= W.OutdoorAmbient then Lighting.OutdoorAmbient = W.OutdoorAmbient end
    elseif worldOrig.ambient ~= nil then
        Lighting.Ambient = worldOrig.ambient
        Lighting.OutdoorAmbient = worldOrig.outdoor
        worldOrig.ambient, worldOrig.outdoor = nil, nil
    end

    if W.Grading then
        if not gradeFx or not gradeFx.Parent then
            gradeFx = Instance.new("ColorCorrectionEffect")
            gradeFx.Name = HttpSvc:GenerateGUID(false)
            gradeFx.Parent = Lighting
        end
        if not gradeFx.Enabled then gradeFx.Enabled = true end
        if gradeFx.Saturation ~= W.Saturation then gradeFx.Saturation = W.Saturation end
        if gradeFx.Contrast ~= W.Contrast then gradeFx.Contrast = W.Contrast end
        if gradeFx.TintColor ~= W.Tint then gradeFx.TintColor = W.Tint end
    elseif gradeFx and gradeFx.Enabled then
        gradeFx.Enabled = false
    end

    if W.BloomEnabled then
        if not bloomFx or not bloomFx.Parent then
            bloomFx = Instance.new("BloomEffect")
            bloomFx.Name = HttpSvc:GenerateGUID(false)
            bloomFx.Parent = Lighting
        end
        if not bloomFx.Enabled then bloomFx.Enabled = true end
        if bloomFx.Intensity ~= W.BloomIntensity then bloomFx.Intensity = W.BloomIntensity end
        if bloomFx.Size ~= W.BloomSize then bloomFx.Size = W.BloomSize end
        if bloomFx.Threshold ~= W.BloomThreshold then bloomFx.Threshold = W.BloomThreshold end
    elseif bloomFx and bloomFx.Enabled then
        bloomFx.Enabled = false
    end
end

local function restore()
    pcall(function()
        if worldOrig.time ~= nil then Lighting.ClockTime = worldOrig.time end
        if worldOrig.brightness ~= nil then
            Lighting.Brightness = worldOrig.brightness
            Lighting.ExposureCompensation = worldOrig.exposure
            Lighting.ColorShift_Top = worldOrig.shiftTop
        end
        local cam = workspace.CurrentCamera
        if cam then
            if wasFovEnabled and worldOrig.fov ~= nil then
                cam.FieldOfView = worldOrig.fov
            elseif appliedSpeedKick > 0 and worldOrig.appliedFOV ~= nil and math.abs(cam.FieldOfView - worldOrig.appliedFOV) < 1.5 then
                cam.FieldOfView = clamp(cam.FieldOfView - appliedSpeedKick, 40, 120)
            elseif worldOrig.fov ~= nil then
                cam.FieldOfView = worldOrig.fov
            end
        end
        if worldOrig.fogEnd ~= nil then Lighting.FogEnd = worldOrig.fogEnd end
        if worldOrig.fogStart ~= nil then Lighting.FogStart = worldOrig.fogStart end
        if worldOrig.ambient ~= nil then Lighting.Ambient = worldOrig.ambient end
        if worldOrig.outdoor ~= nil then Lighting.OutdoorAmbient = worldOrig.outdoor end
        for atm, orig in pairs(worldOrig.atm) do
            if atm and atm.Parent then
                atm.Density, atm.Haze, atm.Glare = orig.d, orig.h, orig.g
            end
        end
    end)
    restoreSky()
    clearWeather()
    worldOrig = { atm = {} }
    wasFovEnabled, lastAtmScan = false, 0
    speedFovSmooth, appliedSpeedKick = 0, 0
    if gradeFx then safeDestroy(gradeFx) gradeFx = nil end
    if bloomFx then safeDestroy(bloomFx) bloomFx = nil end
end

return { update = update, restore = restore }
end)()

local ThirdPerson = (function()
local tpOrig = nil
local tpChar, tpBodyParts, tpBodyConn = nil, {}, nil
local tpLastOffX, tpLastOffY, tpLastOffVec = nil, nil, nil

local function clearTpBodyCache()
    if tpBodyConn then safeDestroy(tpBodyConn) tpBodyConn = nil end
    table.clear(tpBodyParts)
    tpChar = nil
end

local function rebuildTpBodyCache(char)
    clearTpBodyCache()
    if not char then return end
    tpChar = char
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            table.insert(tpBodyParts, p)
        end
    end
    tpBodyConn = char.DescendantAdded:Connect(function(inst)
        if inst:IsA("BasePart") and inst.Name ~= "HumanoidRootPart" then
            table.insert(tpBodyParts, inst)
        end
    end)
end

local function restore()
    clearTpBodyCache()
    if not tpOrig then return end
    pcall(function()
        LP.CameraMode = tpOrig.mode
        LP.CameraMinZoomDistance = tpOrig.minZ
        LP.CameraMaxZoomDistance = tpOrig.maxZ
        local char = LP and LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and tpOrig.camOff then hum.CameraOffset = tpOrig.camOff end
    end)
    tpOrig = nil
end

local function update()
    local T = cfg().ThirdPerson
    if not T.Enabled then
        if tpOrig or tpChar then restore() end
        return
    end
    local char = LP and LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not tpOrig then
        tpOrig = {
            mode = LP.CameraMode,
            minZ = LP.CameraMinZoomDistance,
            maxZ = LP.CameraMaxZoomDistance,
            camOff = hum and hum.CameraOffset or Vector3.new(),
        }
    end
    local dist = clamp(T.Distance or 10, 2, 28)
    if LP.CameraMode ~= Enum.CameraMode.Classic
        or math.abs(LP.CameraMinZoomDistance - dist) > 0.05
        or math.abs(LP.CameraMaxZoomDistance - math.max(dist, 2)) > 0.05 then
        pcall(function()
            LP.CameraMode = Enum.CameraMode.Classic
            LP.CameraMinZoomDistance = dist
            LP.CameraMaxZoomDistance = math.max(dist, 2)
        end)
    end
    if hum then
        local ox, oy = T.OffsetX or 0, T.OffsetY or 0
        if ox ~= tpLastOffX or oy ~= tpLastOffY or not tpLastOffVec then
            tpLastOffX, tpLastOffY = ox, oy
            tpLastOffVec = v3(ox, oy, 0)
        end
        if hum.CameraOffset ~= tpLastOffVec then hum.CameraOffset = tpLastOffVec end
    end
    if T.ShowBody and char then
        if tpChar ~= char then rebuildTpBodyCache(char) end
        for i = #tpBodyParts, 1, -1 do
            local p = tpBodyParts[i]
            if p and p.Parent then
                if p.LocalTransparencyModifier ~= 0 then
                    p.LocalTransparencyModifier = 0
                end
            else
                table.remove(tpBodyParts, i)
            end
        end
    elseif tpChar then
        clearTpBodyCache()
    end
    local cam = workspace.CurrentCamera
    local head = char and char:FindFirstChild("Head")
    if T.ForceCamera and cam and isPartValid(head) then
        local headPos = partPos(head)
        if (cam.CFrame.Position - headPos).Magnitude < 2.2 then
            local cf = cam.CFrame
            local wish = cf.Position - cf.LookVector * dist + cf.RightVector * (T.OffsetX or 0) + cf.UpVector * (T.OffsetY or 0)
            local delta = wish - headPos
            local mag = delta.Magnitude
            if mag > 0.05 then
                table.clear(visIgnore)
                visIgnore[1] = char
                visIgnore[2] = cam
                visParams.FilterDescendantsInstances = visIgnore
                local res = rawRay(headPos, delta, visParams)
                local finalPos = res and (res.Position - (delta / mag) * math.min(0.4, mag * 0.5)) or wish
                cam.CFrame = (cf - cf.Position) + finalPos
            end
        end
    end
end

return { update = update, restore = restore }
end)()

local trackFPS
do
    local fpsSum, fpsCount = 0, 0
    trackFPS = function(dt)
        if dt <= 0 then return end
        fpsSum += 1 / dt
        fpsCount += 1
        if fpsCount >= 30 then fps, fpsSum, fpsCount = fpsSum / fpsCount, 0, 0 end
    end
end

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local function loadModule(path)
    local ok, src = pcall(game.HttpGet, game, repo .. path)
    if not ok or not src then return nil end
    local fn = loadstring_(src)
    if not fn then return nil end
    local ok2, mod = pcall(fn)
    return ok2 and mod or nil
end

Library = loadModule("Library.lua")
if not Library then
    warn("[glupost] не удалось загрузить Obsidian")
    getgenv_().GlupostObjects = nil
    getgenv_()._GlupostHubActive = false
    return
end
local ThemeManager = loadModule("addons/ThemeManager.lua")
local SaveManager  = loadModule("addons/SaveManager.lua")

local Window = Library:CreateWindow({
    Title = "glupost hub", Footer = VERSION, Center = true, AutoShow = true, NotifySide = "Right",
})
Options = Library.Options
Toggles = Library.Toggles

local Tabs = {
    ESP       = Window:AddTab("ВХ (ESP)", "eye"),
    SelfFX    = Window:AddTab("Персонаж и FX", "sparkles"),
    Overlay   = Window:AddTab("Оверлей и HUD", "layers"),
    Awareness = Window:AddTab("Угрозы и звук", "radar"),
    World     = Window:AddTab("Мир и камера", "globe"),
    Objects   = Window:AddTab("Объекты", "box"),
    Help      = Window:AddTab("Справка", "info"),
    UI        = Window:AddTab("Настройки UI", "settings"),
}

local SYNC = {}
local isSyncingUI = false

local UiBg = {}
do
    local SCALE_MODES = {
        Crop = Enum.ScaleType.Crop,
        Stretch = Enum.ScaleType.Stretch,
        Fit = Enum.ScaleType.Fit,
        Tile = Enum.ScaleType.Tile,
    }
    local BG_ROOT = "glupost_hub"
    local BG_DIR = "glupost_hub/backgrounds"
    local CACHE_EXTS = { ".png", ".jpg", ".jpeg", ".webp", ".gif" }

    local screenGuiRef, mainFrameRef, bgLayer
    local origTransp = {}
    local urlAssetCache, urlPending, urlFailed = {}, {}, {}

    local function getCustomAssetFn()
        local g = getgenv_()
        return getcustomasset or getsynasset or g.getcustomasset or g.getsynasset
    end

    local function getRequestFn()
        local g = getgenv_()
        return request or http_request or g.request or g.http_request
            or (g.syn and g.syn.request) or (g.http and g.http.request)
    end

    local function ensureBgDir()
        if not (isfolder and makefolder) then return false end
        if not isfolder(BG_ROOT) then pcall(makefolder, BG_ROOT) end
        if not isfolder(BG_DIR) then pcall(makefolder, BG_DIR) end
        return isfolder(BG_DIR)
    end

    local function hashUrl(u)
        local h = 5381
        for i = 1, #u do
            h = ((h * 131) + string.byte(u, i)) % 4294967296
        end
        return string.format("%08x", floor(h))
    end

    local function detectImageExt(bytes, url)
        if type(bytes) ~= "string" or #bytes < 64 then return nil end
        local b4 = bytes:sub(1, 4)
        if b4 == "\137PNG" then return ".png" end
        if bytes:sub(1, 3) == "\255\216\255" then return ".jpg" end
        if b4 == "RIFF" and bytes:sub(9, 12) == "WEBP" then return ".webp" end
        if b4 == "GIF8" then return ".gif" end
        local head = string.lower(bytes:sub(1, 96))
        if head:match("^%s*<!doctype") or head:match("^%s*<html") or head:match("^%s*<%?xml") or head:match("^%s*{") then
            return nil
        end
        local ext = url and url:match("^[^?#]+%.([%a]+)")
        if ext then
            ext = "." .. string.lower(ext)
            if ext == ".png" or ext == ".jpg" or ext == ".jpeg" or ext == ".webp" or ext == ".gif" then
                return ext
            end
        end
        return ".png"
    end

    local function findCachedAsset(url)
        if urlAssetCache[url] then return urlAssetCache[url] end
        local assetFn = getCustomAssetFn()
        if type(assetFn) ~= "function" or type(isfile) ~= "function" then return nil end
        local h = hashUrl(url)
        for _, ext in ipairs(CACHE_EXTS) do
            local path = BG_DIR .. "/" .. h .. ext
            if isfile(path) then
                local ok, id = pcall(assetFn, path)
                if ok and type(id) == "string" and id ~= "" then
                    urlAssetCache[url] = id
                    return id
                end
            end
        end
        return nil
    end

    local function fetchUrlBytes(url)
        local req = getRequestFn()
        if type(req) == "function" then
            local ok, res = pcall(req, {
                Url = url,
                Method = "GET",
                Headers = { ["User-Agent"] = "Mozilla/5.0" },
            })
            if ok and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
                if not res.StatusCode or (res.StatusCode >= 200 and res.StatusCode < 300) then
                    return res.Body
                end
            end
        end
        local ok2, body = pcall(game.HttpGet, game, url)
        if ok2 and type(body) == "string" and #body > 0 then return body end
        return nil
    end

    local function downloadUrlAsync(url)
        local failAt = urlFailed[url]
        if urlPending[url] or (failAt and clock() - failAt < 10) then return end
        local assetFn = getCustomAssetFn()
        if type(assetFn) ~= "function" or type(writefile) ~= "function" then
            urlFailed[url] = clock()
            pcall(function()
                Library:Notify({
                    Title = "Фон UI",
                    Description = "Экзекутор не поддерживает getcustomasset/writefile для URL — используйте Roblox ID",
                    Time = 4,
                })
            end)
            return
        end
        urlPending[url] = true
        task.spawn(function()
            local body = fetchUrlBytes(url)
            local ext = body and detectImageExt(body, url)
            if not ext then
                urlPending[url] = nil
                urlFailed[url] = clock()
                pcall(function()
                    Library:Notify({
                        Title = "Фон UI",
                        Description = "Не удалось загрузить картинку: нужна прямая ссылка на PNG/JPG/WEBP",
                        Time = 4,
                    })
                end)
                return
            end
            ensureBgDir()
            local path = BG_DIR .. "/" .. hashUrl(url) .. ext
            local okW = pcall(writefile, path, body)
            local okA, assetId = false, nil
            if okW then okA, assetId = pcall(assetFn, path) end
            urlPending[url] = nil
            if okA and type(assetId) == "string" and assetId ~= "" then
                urlAssetCache[url] = assetId
                urlFailed[url] = nil
                local cur = cfg().UI
                local curTrim = type(cur.BgId) == "string" and (cur.BgId:match("^%s*(.-)%s*$") or "") or ""
                if cur.BgEnabled and curTrim == url then
                    pcall(UiBg.apply)
                    pcall(function()
                        Library:Notify({ Title = "Фон UI", Description = "Картинка по ссылке загружена", Time = 3 })
                    end)
                end
            else
                urlFailed[url] = clock()
                pcall(function()
                    Library:Notify({ Title = "Фон UI", Description = "Ошибка создания custom asset из файла", Time = 4 })
                end)
            end
        end)
    end

    function UiBg.normalizeId(raw)
        if type(raw) ~= "string" then return nil, false end
        local s = raw:match("^%s*(.-)%s*$") or ""
        if s == "" then return nil, false end
        if s:match("^rbxthumb://") or s:match("^rbxasset://") then return s, false end
        local isRobloxHost = (not s:match("^https?://")) or (string.lower(s):match("^https?://[^/]*roblox%.com/") ~= nil)
        local asset = s:match("^rbxassetid://(%d+)$") or s:match("^(%d+)$")
        if not asset and isRobloxHost then
            asset = s:match("[?&]id=(%d+)")
                or s:match("/asset/(%d+)")
                or s:match("/library/(%d+)")
                or s:match("/catalog/(%d+)")
        end
        if asset then return "rbxassetid://" .. asset, false end
        if s:match("^rbxassetid://") then return s, false end
        if s:match("^https?://") then return s, true end
        return nil, false
    end

    local function findScreenGui()
        if screenGuiRef and screenGuiRef.Parent then return screenGuiRef end
        if Library and typeof(Library.ScreenGui) == "Instance" and Library.ScreenGui:IsA("ScreenGui") then
            screenGuiRef = Library.ScreenGui
            return screenGuiRef
        end
        for _, src in ipairs({ Tabs and Tabs.UI, Window }) do
            if type(src) == "table" then
                for _, v in pairs(src) do
                    if typeof(v) == "Instance" then
                        local sg = v:FindFirstAncestorWhichIsA("ScreenGui")
                        if sg then
                            screenGuiRef = sg
                            return sg
                        end
                    end
                end
            end
        end
        return nil
    end

    local function findMainFrame()
        if mainFrameRef and mainFrameRef.Parent then return mainFrameRef end
        local sg = findScreenGui()
        if not sg then return nil end
        if type(Window) == "table" then
            for _, key in ipairs({ "Holder", "MainFrame", "Container", "Frame", "Root", "Base", "WindowFrame" }) do
                local inst = Window[key]
                if typeof(inst) == "Instance" and inst:IsA("GuiObject") and inst:IsDescendantOf(sg) then
                    while inst.Parent and inst.Parent ~= sg do
                        if inst.Parent:IsA("GuiObject") then inst = inst.Parent else break end
                    end
                    mainFrameRef = inst
                    return inst
                end
            end
        end
        if Tabs and type(Tabs.UI) == "table" then
            for _, v in pairs(Tabs.UI) do
                if typeof(v) == "Instance" and v:IsDescendantOf(sg) then
                    local cur = v
                    while cur.Parent and cur.Parent ~= sg do
                        if cur.Parent:IsA("GuiObject") then cur = cur.Parent else break end
                    end
                    if cur:IsA("GuiObject") then
                        mainFrameRef = cur
                        return cur
                    end
                end
            end
        end
        local best, bestArea = nil, 0
        for _, ch in ipairs(sg:GetChildren()) do
            if ch:IsA("GuiObject") and (ch:IsA("Frame") or ch:IsA("CanvasGroup")) then
                local area = ch.AbsoluteSize.X * ch.AbsoluteSize.Y
                if area > bestArea and ch.AbsoluteSize.X >= 320 and ch.AbsoluteSize.Y >= 220 then
                    best, bestArea = ch, area
                end
            end
        end
        mainFrameRef = best
        return best
    end

    local function isPanelCandidate(inst)
        if not inst:IsA("Frame") and not inst:IsA("CanvasGroup") and not inst:IsA("ScrollingFrame") then
            return false
        end
        if inst == bgLayer then return false end
        local sz = inst.Size
        local abs = inst.AbsoluteSize
        local wideEnough = sz.X.Scale >= 0.35 or sz.X.Offset >= 140 or abs.X >= 140
        if not wideEnough then return false end
        if inst.AutomaticSize == Enum.AutomaticSize.Y or inst.AutomaticSize == Enum.AutomaticSize.XY then
            return true
        end
        return sz.Y.Scale >= 0.15 or sz.Y.Offset >= 44 or abs.Y >= 44
    end

    local function collectPanels(root)
        for _, ch in ipairs(root:GetDescendants()) do
            if isPanelCandidate(ch) and origTransp[ch] == nil then
                if ch.BackgroundTransparency < 0.95 then
                    origTransp[ch] = ch.BackgroundTransparency
                end
            end
        end
    end

    local function restorePanels()
        for inst, tr in pairs(origTransp) do
            if inst and inst.Parent then
                pcall(function() inst.BackgroundTransparency = tr end)
            end
        end
    end

    local function ensureBgLayer(mf, sg)
        if bgLayer and bgLayer.Parent then return bgLayer end
        if mf:FindFirstChildWhichIsA("UIListLayout") or mf:FindFirstChildWhichIsA("UIGridLayout") then
            return nil
        end
        local img = Instance.new("ImageLabel")
        img.Name = "GlupostCustomBg"
        img.Size = UDim2.fromScale(1, 1)
        img.Position = UDim2.fromScale(0, 0)
        img.BackgroundTransparency = 1
        img.BorderSizePixel = 0
        img.ClipsDescendants = true
        img.Visible = false
        local minZ = 1
        for _, ch in ipairs(mf:GetChildren()) do
            if ch:IsA("GuiObject") and ch.Size.X.Scale <= 1.01 and ch.Size.Y.Scale <= 1.01 then
                if ch.ZIndex < minZ then minZ = ch.ZIndex end
            end
        end
        if sg and sg.ZIndexBehavior == Enum.ZIndexBehavior.Sibling then
            img.ZIndex = math.min(0, minZ - 1)
        else
            img.ZIndex = mf.ZIndex
        end
        local srcCorner = mf:FindFirstChildWhichIsA("UICorner")
        if srcCorner then
            local c = Instance.new("UICorner")
            c.CornerRadius = srcCorner.CornerRadius
            c.Parent = img
        end
        img.Parent = mf
        bgLayer = img
        return img
    end

    function UiBg.clearFailures()
        table.clear(urlFailed)
    end

    function UiBg.apply()
        local U = cfg().UI
        local sg = findScreenGui()
        local mf = findMainFrame()
        if not mf then return end

        local source, isUrl = nil, false
        if U and U.BgEnabled then
            source, isUrl = UiBg.normalizeId(U.BgId)
        end

        local asset = nil
        if source then
            if isUrl then
                asset = findCachedAsset(source)
                if not asset then
                    downloadUrlAsync(source)
                end
            else
                asset = source
            end
        end

        if not asset then
            if bgLayer and bgLayer.Parent then bgLayer.Visible = false end
            restorePanels()
            return
        end

        local img = ensureBgLayer(mf, sg)
        if not img then return end
        collectPanels(mf)

        local panelTransp = 1 - clamp(U.BgPanelOpacity or 0.78, 0.05, 1)
        for inst, orig in pairs(origTransp) do
            if inst and inst.Parent then
                pcall(function()
                    inst.BackgroundTransparency = math.max(orig, panelTransp)
                end)
            end
        end

        local scale = SCALE_MODES[U.BgScale] or Enum.ScaleType.Crop
        img.Image = asset
        img.ImageColor3 = U.BgTint or Color3.new(1, 1, 1)
        img.ImageTransparency = 1 - clamp(U.BgOpacity or 0.65, 0.05, 1)
        img.ScaleType = scale
        if scale == Enum.ScaleType.Tile then
            img.TileSize = UDim2.fromOffset(256, 256)
        end
        img.Visible = true
    end

    function UiBg.destroy()
        restorePanels()
        table.clear(origTransp)
        table.clear(urlPending)
        table.clear(urlFailed)
        if bgLayer then pcall(function() bgLayer:Destroy() end) bgLayer = nil end
        mainFrameRef, screenGuiRef = nil, nil
    end
end

local function safeSet(idx, value)
    local o = (Toggles and Toggles[idx]) or (Options and Options[idx])
    if not o then return end
    pcall(function()
        if typeof(value) == "Color3" and o.SetValueRGB then o:SetValueRGB(value)
        elseif o.SetValue then o:SetValue(value) end
    end)
end

local function syncUI()
    if isSyncingUI then return end
    isSyncingUI = true
    for _, e in ipairs(SYNC) do
        local t = cfg()
        for _, k in ipairs(e.path) do t = t[k] end
        safeSet(e.idx, t)
    end
    isSyncingUI = false
    if UiBg and UiBg.apply then pcall(UiBg.apply) end
end

local function applyESPSync()
    local e = cfg().ESP
    if not e.SyncWithESP then return end
    cfg().Proximity.IgnoreTeammates = e.HideTeammates
    cfg().LookingAlert.HideTeammates = e.HideTeammates
    cfg().FootstepRings.HideTeammates = e.HideTeammates
    safeSet("ProxTeams", e.HideTeammates)
    safeSet("LookAlertTeams", e.HideTeammates)
    safeSet("StepRingsTeams", e.HideTeammates)
end

do
local SEARCH_INDEX = {}
local CUR_TAB, CUR_GROUP = "", ""

local function regSearch(text, tip)
    if CUR_TAB ~= "" and text and text ~= "" then
        SEARCH_INDEX[#SEARCH_INDEX + 1] = {
            tab = CUR_TAB,
            group = CUR_GROUP,
            text = text,
            tip = tip or "",
            lower = string.lower(text .. " " .. (tip or "") .. " " .. CUR_TAB .. " " .. CUR_GROUP),
        }
    end
end

local function getPath(path)
    local t = cfg()
    for _, k in ipairs(path) do t = t[k] end
    return t
end

local function setPath(path, v)
    local t = cfg()
    for i = 1, #path - 1 do t = t[path[i]] end
    t[path[#path]] = v
end

local function addToggle(gb, idx, text, path, tip, cb)
    gb:AddToggle(idx, { Text = text, Default = getPath(path), Tooltip = tip,
        Callback = function(v) setPath(path, v) if cb then cb(v) end end })
    table.insert(SYNC, { idx = idx, path = path })
    regSearch(text, tip)
end

local function addSlider(gb, idx, text, path, min, max, rounding, tip, cb)
    gb:AddSlider(idx, { Text = text, Default = getPath(path), Min = min, Max = max, Rounding = rounding, Tooltip = tip,
        Callback = function(v) setPath(path, v) if cb then cb(v) end end })
    table.insert(SYNC, { idx = idx, path = path })
    regSearch(text, tip)
end

local function addDropdown(gb, idx, text, path, values, tip, cb)
    gb:AddDropdown(idx, { Text = text, Values = values, Default = getPath(path), Tooltip = tip,
        Callback = function(v) setPath(path, v) if cb then cb(v) end end })
    table.insert(SYNC, { idx = idx, path = path })
    regSearch(text, tip)
end

local function addColorPicker(gb, idx, text, path, cb)
    gb:AddLabel(text):AddColorPicker(idx, { Default = getPath(path), Title = text,
        Callback = function(c) setPath(path, c) if cb then cb(c) end end })
    table.insert(SYNC, { idx = idx, path = path })
    regSearch(text, "Цвет: " .. text)
end

local function addInput(gb, idx, text, path, placeholder, tip, cb)
    gb:AddInput(idx, { Text = text, Default = getPath(path), Placeholder = placeholder, Finished = true, Tooltip = tip,
        Callback = function(v) setPath(path, v) if cb then cb(v) end end })
    table.insert(SYNC, { idx = idx, path = path })
    regSearch(text, tip)
end

local function withDep(parentGb, refIdx, expected, fn)
    local ref = (Toggles and Toggles[refIdx]) or (Options and Options[refIdx])
    if ref and type(parentGb.AddDependencyBox) == "function" then
        local ok, dep = pcall(function() return parentGb:AddDependencyBox() end)
        if ok and dep and type(dep.SetupDependencies) == "function" and type(dep.AddToggle) == "function" then
            fn(dep)
            pcall(function() dep:SetupDependencies({ { ref, expected } }) end)
            return dep
        end
    end
    fn(parentGb)
    return parentGb
end

local function resyncChams()
    updateChamsBudget()
    for plr, d in pairs(playersData) do
        syncChams(plr, d, renderData[plr], chamsAllowed[plr] == true)
    end
end

do
    CUR_TAB, CUR_GROUP = "ВХ (ESP)", "Основные настройки"
    local g = Tabs.ESP:AddLeftGroupbox("Основные настройки")
    addToggle(g, "EspOn", "Включить ВХ", { "ESP", "Enabled" },
        "Главный переключатель подсветки игроков. Горячая клавиша настраивается в «Настройки UI → Горячие клавиши» (по умолчанию F1).")
    addToggle(g, "EspUnlimDist", "Без лимита дистанции", { "ESP", "UnlimitedDistance" },
        "Убирает ограничение дальности прорисовки ВХ (учтите: на картах со StreamingEnabled сам сервер выгружает далёких игроков).")
    withDep(g, "EspUnlimDist", false, function(d)
        addSlider(d, "MaxDist", "Макс. дистанция", { "ESP", "MaxDistance" }, 50, 50000, 0,
            "Максимальное расстояние (в стадах), на котором отображаются игроки.",
            function(v)
                if cfg().ESP.MinDistance >= v then
                    cfg().ESP.MinDistance = math.max(0, v - 10)
                    safeSet("MinDist", cfg().ESP.MinDistance)
                end
                applyESPSync()
            end)
    end)
    addSlider(g, "MinDist", "Мин. дистанция", { "ESP", "MinDistance" }, 0, 2000, 0,
        "Минимальное расстояние: игроки ближе этого порога не рисуются, чтобы не загромождать экран.",
        function(v)
            if v >= cfg().ESP.MaxDistance then
                cfg().ESP.MaxDistance = math.min(50000, v + 50)
                safeSet("MaxDist", cfg().ESP.MaxDistance)
                applyESPSync()
            end
        end)
    addDropdown(g, "BoxType", "Тип рамки", { "ESP", "BoxType" }, { "2D", "Corner", "Bracket", "3D" },
        "Форма рамки вокруг игрока: 2D — прямоугольник, Corner — уголки, Bracket — тактические скобки с засечками, 3D — объёмный куб. По умолчанию переключается клавишей F2.")
    addDropdown(g, "BoxFit", "Подгонка рамки", { "ESP", "BoxFit" }, { "Fixed", "Dynamic" },
        "Fixed — быстрая рамка по фиксированным габаритам, Dynamic — точный обхват всех частей тела в каждом кадре.")
    addSlider(g, "BoxThick", "Толщина рамки", { "ESP", "BoxThickness" }, 1, 6, 0,
        "Толщина линий рамки в пикселях.")
    addToggle(g, "TeamHide", "Скрывать союзников", { "ESP", "HideTeammates" },
        "Скрывает игроков вашей команды с ВХ (работает только в играх, где есть команды).",
        applyESPSync)
    withDep(g, "TeamHide", true, function(d)
        addToggle(d, "SyncESP", "Синхр. команд с Угрозами", { "ESP", "SyncWithESP" },
            "Автоматически применяет настройку «Скрывать союзников» к звуку приближения, тревоге взгляда и кольцам шагов.",
            applyESPSync)
    end)
    addToggle(g, "VisCheck", "Проверка видимости", { "ESP", "VisibleCheck" },
        "Проверяет лучами, находится ли игрок в прямой видимости (цвет Visible) или за стеной (цвет Occluded).")
    withDep(g, "VisCheck", true, function(d)
        addToggle(d, "SmartVis", "Умная проверка (сквозь стекло)", { "ESP", "SmartVisCheck" },
            "Пробивает полупрозрачные и неколлизионные препятствия (стёкла, листву, невидимые барьеры) при проверке видимости.")
    end)
    addToggle(g, "Prio", "Выделять опасную цель", { "ESP", "PriorityTarget" },
        "Отдельно подсвечивает цветом Priority самого опасного врага по дистанции, направлению взгляда и урону.")
    withDep(g, "Prio", true, function(d)
        addToggle(d, "PrioMark", "3D-маркер под целью", { "ESP", "PriorityMarker" },
            "Рисует вращающийся тактический 3D-ромб под ногами самой опасной цели, чтобы она мгновенно выделялась в толпе.")
        addToggle(d, "ThreatTxt", "Показывать % угрозы", { "ESP", "ShowThreatScore" },
            "Отображает расчётный процент угрозы рядом с целью (учитывает близость, взгляд в вашу сторону и активность).")
    end)
    addToggle(g, "AdaptiveLOD", "Адаптивный LOD (вдали)", { "ESP", "AdaptiveLOD" },
        "На большой дистанции автоматически упрощает детализацию ВХ (отключает лишние линии/текст) для экономии FPS.")
    addToggle(g, "SmoothCF", "Плавная позиция (Render CFrame)", { "ESP", "SmoothCF" },
        "Использует сглаженные координаты рендера, чтобы рамка и скелет меньше дрожали при движении цели.")
    addToggle(g, "DistFade", "Затухание по дистанции", { "ESP", "DistanceFade" },
        "Плавно снижает прозрачность элементов ВХ по мере удаления игрока к максимальной дистанции.")

    local leftTabs = Tabs.ESP:AddLeftTabbox()
    CUR_GROUP = "Рамка и маркеры"
    local st = leftTabs:AddTab("Рамка и маркеры")
    addToggle(st, "BoxOutline", "Обводка рамки", { "ESP", "Outline" },
        "Добавляет чёрную обводку вокруг рамки — сильно повышает читаемость на светлом фоне.")
    addToggle(st, "BoxFill", "Заливка рамки", { "ESP", "BoxFill" },
        "Рисует полупрозрачный фон внутри рамки игрока.")
    withDep(st, "BoxFill", true, function(d)
        addSlider(d, "FillOp", "Прозрачность заливки", { "ESP", "FillOpacity" }, 0.05, 0.8, 2,
            "Насыщенность полупрозрачной заливки внутри рамки.")
    end)
    addToggle(st, "HpBar", "Полоса здоровья", { "ESP", "HealthBar" },
        "Рисует вертикальную полоску HP слева от рамки (цвет плавно меняется от зелёного к красному).")
    withDep(st, "HpBar", true, function(d)
        addToggle(d, "HpTrail", "Шлейф урона на полосе HP", { "ESP", "HealthTrail" },
            "После получения врагом урона на полосе здоровья остаётся плавно исчезающий белый/красный след.")
    end)
    addToggle(st, "HeadDot", "Точка на голове", { "ESP", "HeadDot" },
        "Рисует кружок на голове цели для точного наведения.")
    withDep(st, "HeadDot", true, function(d)
        addToggle(d, "HeadDotFill", "Заливка точки головы", { "ESP", "HeadDotFilled" },
            "Делает кружок на голове сплошным вместо пустого контура.")
    end)
    addToggle(st, "LookLine", "Линия взгляда", { "ESP", "LookLine" },
        "Показывает вектор, куда именно смотрит голова игрока в данный момент.")
    withDep(st, "LookLine", true, function(d)
        addToggle(d, "LookRay", "Упирать взгляд в стены", { "ESP", "LookRaycast" },
            "Обрезает линию взгляда о ближайшее препятствие, чтобы видеть точку, на которую смотрит враг.")
        addSlider(d, "LookLen", "Длина линии взгляда", { "ESP", "LookLength" }, 2, 20, 0,
            "Максимальная длина луча взгляда в стадах.")
    end)
    addToggle(st, "Rainbow", "Радужный режим", { "ESP", "Rainbow" },
        "Плавный перелив цветов ВХ по спектру радуги.")
    addToggle(st, "TeamColors", "Цвета команд из игры", { "ESP", "TeamColors" },
        "Окрашивает ВХ в цвет команды игрока (TeamColor), заданный самим режимом.")

    CUR_GROUP = "Текст и урон"
    local inf = leftTabs:AddTab("Текст и урон")
    addToggle(inf, "ShowName", "Имена игроков", { "ESP", "ShowName" },
        "Показывать никнейм над рамкой игрока.")
    withDep(inf, "ShowName", true, function(d)
        addSlider(d, "NameYOff", "Сдвиг имени по Y", { "ESP", "NameYOffset" }, -50, 50, 0,
            "Поднимает или опускает никнейм относительно верхнего края рамки.")
    end)
    addToggle(inf, "ShowHP", "Текст здоровья", { "ESP", "ShowHealth" },
        "Показывать числовое значение HP рядом с игроком.")
    withDep(inf, "ShowHP", true, function(d)
        addDropdown(d, "HpFormat", "Формат здоровья", { "ESP", "HealthFormat" }, { "HP", "Fraction", "Percent", "Both" },
            "Вид отображения: HP (число), Fraction (текущее/макс), Percent (%), Both (число и %).")
    end)
    addToggle(inf, "ShowDist", "Дистанция", { "ESP", "ShowDistance" },
        "Показывать расстояние до игрока в стадах.")
    addToggle(inf, "ShowTool", "Предмет в руках", { "ESP", "ShowTool" },
        "Показывать название оружия или инструмента, который сейчас держит игрок.")
    addToggle(inf, "ShowState", "Статус игрока ([ПРЫЖОК]/[БЕГ])", { "ESP", "ShowState" },
        "Показывает под целью её текущее состояние: бег, прыжок или сидение.")
    addToggle(inf, "DmgPopups", "Всплывающий урон", { "ESP", "DamageNumbers" },
        "При потере HP врагом над ним всплывают цифры полученного урона (крупный урон >= 35 выделяется золотым критом).")
    addSlider(inf, "TextSize", "Размер текста", { "ESP", "TextSize" }, 10, 20, 0,
        "Размер шрифта всех подписей ВХ в пикселях.")
    addDropdown(inf, "FontName", "Шрифт ВХ", { "ESP", "FontName" }, { "UI", "System", "Plex", "Monospace" },
        "Стиль шрифта Drawing для подписей. На части экзекьюторов чётче всего читается Plex или UI.")
    addToggle(inf, "TextOutline", "Обводка текста", { "ESP", "TextOutline" },
        "Добавляет тёмный контур вокруг букв, чтобы текст не сливался с фоном.")
    addToggle(inf, "HideTags", "Скрыть стандартные ники", { "ESP", "HideDefaultTags" },
        "Скрывает встроенные в игру таблички ников (Humanoid DisplayDistance), чтобы они не накладывались на ВХ.")

    local rightTabs = Tabs.ESP:AddRightTabbox()
    CUR_GROUP = "Скелет и трейсеры"
    local ln = rightTabs:AddTab("Скелет и трейсеры")
    addToggle(ln, "ShowSk", "Скелет", { "ESP", "Skeleton" },
        "Рисует кости персонажа (R6 и R15). Горячая клавиша настраивается в «Настройки UI» (по умолчанию F3).")
    withDep(ln, "ShowSk", true, function(d)
        addToggle(d, "SkOutline", "Обводка скелета", { "ESP", "SkeletonOutline" },
            "Чёрный контур вокруг линий скелета для контраста (немного нагружает Drawing).")
        addSlider(d, "SkThick", "Толщина скелета", { "ESP", "SkeletonThickness" }, 1, 5, 0,
            "Толщина линий костей в пикселях.")
    end)
    addToggle(ln, "ShowTr", "Трейсеры (линии к целям)", { "ESP", "ShowTracer" },
        "Рисует прямые линии от выбранной точки экрана к игрокам.")
    withDep(ln, "ShowTr", true, function(d)
        addDropdown(d, "TrOrigin", "Начало трейсеров", { "ESP", "TracerOrigin" }, { "Bottom", "Center", "Top", "Mouse" },
            "Откуда тянутся линии: Bottom — низ экрана, Center — центр, Top — верх, Mouse — от курсора.")
        addSlider(d, "TrThick", "Толщина трейсеров", { "ESP", "TracerThickness" }, 1, 4, 0,
            "Толщина линий трейсеров в пикселях.")
        addToggle(d, "TrOutline", "Обводка трейсеров", { "ESP", "TracerOutline" },
            "Добавляет чёрный контур линиям трейсеров.")
        addToggle(d, "TrFade", "Затухание трейсеров", { "ESP", "TracerFade" },
            "Делает линии к далёким игрокам более прозрачными.")
    end)
    addToggle(ln, "Arrows", "Стрелки вне экрана", { "ESP", "OffscreenArrows" },
        "Рисует треугольные стрелки по кругу от центра экрана, указывая на игроков за пределами обзора.")
    withDep(ln, "Arrows", true, function(d)
        addSlider(d, "ArrowSize", "Размер стрелок", { "ESP", "ArrowSize" }, 10, 40, 0,
            "Размер боковых индикаторных стрелок в пикселях.")
    end)

    CUR_GROUP = "Чамсы врагов"
    local ch = rightTabs:AddTab("Чамсы врагов")
    addToggle(ch, "Chams", "Включить чамсы врагов", { "ESP", "Chams" },
        "Подсвечивает 3D-модель игроков через стены (Roblox Highlight). Лимит бюджета — до 28 ближайших игроков.",
        resyncChams)
    withDep(ch, "Chams", true, function(d)
        addSlider(d, "ChamsTr", "Прозрачность заливки", { "ESP", "ChamsTransparency" }, 0, 1, 2,
            "Прозрачность заливки силуэта: 0 — плотный, 1 — прозрачный (поставь 1 при контуре 0 для режима только обводки).",
            function(x)
                for _, pd in pairs(playersData) do
                    if pd.highlight and pd.highlight.FillTransparency ~= x then
                        pd.highlight.FillTransparency = x
                    end
                end
            end)
        addSlider(d, "ChamsOutTr", "Прозрачность контура", { "ESP", "ChamsOutlineTransparency" }, 0, 1, 2,
            "Прозрачность обводки Highlight: 0 — чёткий контур, 1 — убрать контур.",
            function(x)
                for _, pd in pairs(playersData) do
                    if pd.highlight and pd.highlight.OutlineTransparency ~= x then
                        pd.highlight.OutlineTransparency = x
                    end
                end
            end)
        addColorPicker(d, "ChamsVis", "Чамсы (в прямой видимости)", { "ESP", "Colors", "ChamsVis" })
        addColorPicker(d, "ChamsOcc", "Чамсы (за стеной)", { "ESP", "Colors", "ChamsOcc" })
    end)

    CUR_GROUP = "Цвета ВХ"
    local gc = Tabs.ESP:AddRightGroupbox("Цвета ВХ")
    addColorPicker(gc, "ColEnemy", "Враг", { "ESP", "Colors", "Enemy" })
    addColorPicker(gc, "ColAlly", "Союзник", { "ESP", "Colors", "Ally" })
    addColorPicker(gc, "ColPrio", "Опасная цель (Priority)", { "ESP", "Colors", "Priority" })
    addColorPicker(gc, "ColVis", "Видимый (Visible)", { "ESP", "Colors", "Visible" })
    addColorPicker(gc, "ColOcc", "За стеной (Occluded)", { "ESP", "Colors", "Occluded" })
    addColorPicker(gc, "ColDamage", "Цифры урона", { "ESP", "Colors", "Damage" })
    addColorPicker(gc, "ColSkel", "Скелет", { "ESP", "Colors", "Skeleton" })
    addColorPicker(gc, "ColTracer", "Трейсер", { "ESP", "Colors", "Tracer" })
    addColorPicker(gc, "ColArrow", "Стрелка вне экрана", { "ESP", "Colors", "Arrow" })
    addColorPicker(gc, "ColLook", "Линия взгляда", { "ESP", "Colors", "Look" })
    addColorPicker(gc, "ColLookAlert", "Смотрит на вас", { "ESP", "Colors", "LookAlert" })

    CUR_GROUP = "Производительность"
    local pf = Tabs.ESP:AddRightGroupbox("Производительность")
    local optBtnTip = "Моментально отключает скелет, чамсы, трейсеры, проверку видимости, заливку и переключает рамку на лёгкий 2D-режим."
    pf:AddButton({
        Text = "Оптимизация: выключить тяжёлое",
        Tooltip = optBtnTip,
        Func = function()
            local e = cfg().ESP
            e.Skeleton, e.ShowTracer, e.Chams = false, false, false
            e.VisibleCheck, e.BoxType = false, "2D"
            e.BoxFill, e.HeadDot, e.LookLine, e.Outline = false, false, false, false
            e.DamageNumbers, e.HealthTrail, e.SkeletonOutline, e.ShowState = false, false, false, false
            e.BoxFit = "Fixed"
            syncUI()
            resyncChams()
        end,
    })
    regSearch("Оптимизация: выключить тяжёлое", optBtnTip)
end

do
    CUR_TAB, CUR_GROUP = "Персонаж и FX", "Чамсы на себя"
    local self = Tabs.SelfFX:AddLeftGroupbox("Чамсы на себя (Liquid Glass / FX)")
    addToggle(self, "SelfChamsOn", "Включить чамсы на себя", { "SelfChams", "Enabled" },
        "Красиво стилизует вашего персонажа (жидкое стекло, силовое поле, неон, голограмма и др.).",
        function(v)
            if not v then Fx.destroySelfChams() end
        end)
    withDep(self, "SelfChamsOn", true, function(d)
        addDropdown(d, "SelfChamsStyle", "Визуальный стиль", { "SelfChams", "Style" },
            { "Liquid Glass", "Energy Rim", "Scanline", "ForceField", "Holographic", "Aurora", "Rainbow", "Cyber", "Pulse", "Sakura", "Matrix", "Sunset", "Gold", "Custom" },
            "Liquid Glass — стекло; Energy Rim — неон-контур по скину; Scanline — сканирующая волна; Aurora/Cyber/Sakura/Matrix/Sunset/Gold — анимированные палитры.")
        addSlider(d, "SelfChamsFillTr", "Прозрачность стекла/заливки", { "SelfChams", "FillTransparency" }, 0, 0.95, 2,
            "Насколько прозрачным становится тело персонажа внутри обводки.")
        addSlider(d, "SelfChamsOutlineTr", "Прозрачность контура", { "SelfChams", "OutlineTransparency" }, 0, 1, 2,
            "Яркость светящейся окантовки по краям модели (меньше значение — ярче контур).")
        addSlider(d, "SelfChamsSpeed", "Скорость анимации", { "SelfChams", "AnimationSpeed" }, 0.1, 3, 1,
            "Скорость перелива и пульсации для анимированных стилей (Aurora, Rainbow, Pulse, Cyber, Scanline).")
        addToggle(d, "SelfChamsTools", "Применять к оружию в руках", { "SelfChams", "IncludeTools" },
            "Накладывает эффект стекла/подсветки также на предмет, который вы держите в руках.")
        addToggle(d, "SelfChamsVM", "Применять к рукам от 1-го лица", { "SelfChams", "IncludeViewmodel" },
            "Пытается подсветить Viewmodel-руки и оружие в камере в шутерах от первого лица.")
        addColorPicker(d, "SelfChamsFillColor", "Цвет заливки / стекла", { "SelfChams", "FillColor" })
        addColorPicker(d, "SelfChamsOutlineColor", "Цвет контура / блика", { "SelfChams", "OutlineColor" })
    end)

    local leftFxTabs = Tabs.SelfFX:AddLeftTabbox()
    CUR_GROUP = "Шлейф Sandevistan"
    local snd = leftFxTabs:AddTab("Шлейф Sandevistan")
    addToggle(snd, "AfterimageOn", "Включить Sandevistan", { "Afterimage", "Enabled" },
        "Оставляет за вашим персонажем светящиеся силуэты при движении или рывках. Можно комбинировать с лентами.")
    withDep(snd, "AfterimageOn", true, function(d)
        addDropdown(d, "AfterimageTrig", "Условие срабатывания", { "Afterimage", "TriggerMode" }, { "Moving", "Dash/Air", "Always" },
            "Moving — при ходьбе/беге выше мин. скорости; Dash/Air — только в прыжке, падении или быстром рывке; Always — постоянно.")
        addDropdown(d, "AfterimageStyle", "Стиль силуэтов", { "Afterimage", "Style" }, { "Sandevistan", "Phantom", "Inferno", "Void", "Cyber", "Rainbow", "Sakura", "Matrix", "Sunset", "Gold", "Custom" },
            "Цветовая палитра клонов: Sandevistan, Phantom, Inferno, Void, Cyber, Rainbow, Sakura, Matrix, Sunset, Gold или Custom.")
        addDropdown(d, "AfterimageFade", "Режим исчезновения", { "Afterimage", "FadeMode" }, { "Static", "Ascend", "Expand", "Implode", "Glitch", "Spiral" },
            "Static — на месте; Ascend — всплытие; Expand/Implode — разлёт или сжатие; Glitch — цифровое мерцание; Spiral — вихрь.")
        addDropdown(d, "AfterimageMat", "Материал / Вид силуэта", { "Afterimage", "Material" }, { "Neon", "ForceField", "Glass", "Wireframe", "SmoothPlastic" },
            "Neon — яркое свечение; ForceField — энерго-сетка; Glass — ледяной силуэт; Wireframe — неоновый каркас линий; SmoothPlastic — матовый.")
        addToggle(d, "AfterimageArc", "Векторная нить связи", { "Afterimage", "ConnectArc" },
            "Рисует светящуюся неоновую линию, соединяющую все активные копии эха от самой старой к вашему персонажу.")
        addToggle(d, "AfterimageSolid", "Сплошное свечение (убрать текстуры)", { "Afterimage", "SolidGlow" },
            "Скрывает текстуры одежды и наклейки на копиях, делая силуэт чистым монолитным.")
        addSlider(d, "AfterimageInterval", "Интервал спавна эха", { "Afterimage", "Interval" }, 0.03, 0.4, 2,
            "Как часто появляется новый силуэт (меньше значение — плотнее шлейф).")
        addSlider(d, "AfterimageLife", "Время жизни эха", { "Afterimage", "Lifetime" }, 0.15, 1.5, 2,
            "Сколько секунд каждый след остаётся видимым перед растворением.")
        addSlider(d, "AfterimageTransparency", "Начальная прозрачность", { "Afterimage", "Transparency" }, 0.1, 0.9, 2,
            "Прозрачность свежего силуэта сразу в момент появления.")
        addSlider(d, "AfterimageMinSpeed", "Мин. скорость срабатывания", { "Afterimage", "MinSpeed" }, 0, 30, 0,
            "Минимальная скорость персонажа (для режима Moving), при которой начинает тянуться шлейф.")
        addSlider(d, "AfterimageMax", "Макс. копий одновременно", { "Afterimage", "MaxCopies" }, 4, 24, 0,
            "Ограничение числа активных силуэтов в мире ради стабильного FPS.")
        addToggle(d, "AfterimageAcc", "Копировать аксессуары", { "Afterimage", "IncludeAccessories" },
            "Включает шапки, крылья и другие аксессуары в состав оставляемых силуэтов.")
        addColorPicker(d, "AfterimageColor", "Свой цвет (Custom)", { "Afterimage", "Color" })
    end)

    CUR_GROUP = "Энергетические ленты"
    local tr = leftFxTabs:AddTab("Ленты (Ribbons)")
    addToggle(tr, "TrailOn", "Включить ленты / шлейф", { "ParticleTrail", "Enabled" },
        "Рисует светящиеся ленты (Trail) и шлейфы с разными узорами вокруг тела, за головой, спиной или конечностями.")
    withDep(tr, "TrailOn", true, function(d)
        addDropdown(d, "TrailMode", "Форма / крепление лент", { "ParticleTrail", "Mode" }, { "Orbit", "Helix", "Void Slash", "Spiral Halo", "Hands", "Feet", "Wings", "Full" },
            "Orbit — 3 орбиты вокруг тела; Helix — двойная спираль; Void Slash — 4-ленточный плащ; Spiral Halo — витки над головой; Hands/Feet/Wings/Full.")
        addDropdown(d, "TrailPattern", "Узор / фактура ленты", { "ParticleTrail", "Pattern" }, { "Smooth", "Pulse", "Starlight", "Blade", "Neon Core" },
            "Smooth — классика; Pulse — прерывистый лазер; Starlight — звёздная дорожка; Blade — острый шлейф катаны; Neon Core — плотный неон.")
        addDropdown(d, "TrailStyle", "Цветовой стиль лент", { "ParticleTrail", "Style" }, { "Holographic", "Aurora", "Rainbow", "Cyber", "Flame", "Void", "Frost", "Sakura", "Matrix", "Sunset", "Gold", "Custom" },
            "Цветовая палитра свечения шлейфа и искр.")
        addSlider(d, "TrailLife", "Длительность шлейфа", { "ParticleTrail", "Lifetime" }, 0.1, 1.5, 2,
            "Как долго лента держится в воздухе за персонажем (в секундах).")
        addSlider(d, "TrailWidth", "Ширина ленты", { "ParticleTrail", "Width" }, 0.05, 0.6, 2,
            "Толщина светящейся полосы в стадах.")
        addSlider(d, "TrailSpeed", "Скорость вращения / перелива", { "ParticleTrail", "Speed" }, 0.3, 2.5, 2,
            "Управляет скоростью движения орбит (Orbit / Helix / Spiral Halo) и скоростью анимации цвета.")
        addToggle(d, "TrailSparks", "Искры вдоль шлейфа", { "ParticleTrail", "Sparks" },
            "Добавляет светящиеся микро-искры ParticleEmitter, осыпающиеся прямо с траектории движения лент.")
        addColorPicker(d, "TrailColor", "Свой цвет лент", { "ParticleTrail", "Color" })
    end)

    CUR_GROUP = "Камера от 3-го лица"
    local tp = Tabs.SelfFX:AddRightGroupbox("Камера от 3-го лица")
    addToggle(tp, "TpOn", "Включить 3-е лицо", { "ThirdPerson", "Enabled" },
        "Отдаляет камеру за спину персонажа даже в играх от 1-го лица. Горячая клавиша настраивается в «Настройки UI» (по умолчанию F5).")
    withDep(tp, "TpOn", true, function(d)
        addSlider(d, "TpDist", "Дистанция камеры", { "ThirdPerson", "Distance" }, 2, 26, 0,
            "На сколько стадов камера отодвигается от персонажа.")
        addToggle(d, "TpScroll", "Зум колесом мыши", { "ThirdPerson", "ScrollZoom" },
            "Позволяет приближать и отдалять камеру от 3-го лица колесом мыши прямо в игре.")
        addSlider(d, "TpOffX", "Смещение вбок (плечо X)", { "ThirdPerson", "OffsetX" }, -4, 4, 1,
            "Сдвиг камеры влево/вправо для удобного обзора из-за плеча.")
        addSlider(d, "TpOffY", "Смещение по высоте Y", { "ThirdPerson", "OffsetY" }, -3, 3, 1,
            "Поднимает или опускает точку обзора камеры.")
        addToggle(d, "TpBody", "Принудительно показывать тело", { "ThirdPerson", "ShowBody" },
            "Снимает невидимость (LocalTransparencyModifier) с вашего тела в шутерах, где игра прячет скин от 1-го лица.")
        addToggle(d, "TpForce", "Пробивать скрипты камеры игры", { "ThirdPerson", "ForceCamera" },
            "Включите, если сама игра жёстко фиксирует камеру на голове персонажа и обычное отдаление не срабатывает.")
    end)

    local rightFxTabs = Tabs.SelfFX:AddRightTabbox()
    CUR_GROUP = "Китайская шляпа / Нимб"
    local hat = rightFxTabs:AddTab("Шляпа / Нимб")
    addToggle(hat, "HatOn", "Включить шляпу / нимб / корону", { "ChinaHat", "Enabled" },
        "Рисует объёмный градиентный конус, двойной парящий нимб, кибер-корону, 3D-кристалл или двойной гекса-обруч CyberRing над головой.")
    withDep(hat, "HatOn", true, function(d)
        addDropdown(d, "HatShape", "Форма", { "ChinaHat", "Shape" }, { "Cone", "Halo", "Crown", "Crystal", "CyberRing" },
            "Cone — конус; Halo — двойной наклонный нимб; Crown — 8-лучевая корона; Crystal — 3D-кристалл; CyberRing — двойной гексагон.")
        addDropdown(d, "HatStyle", "Цветовой стиль", { "ChinaHat", "Style" }, { "Holographic", "Aurora", "Rainbow", "Cyber", "Flame", "Void", "Frost", "Sakura", "Matrix", "Sunset", "Gold", "Custom" },
            "Выбор градиента или своего цвета для шляпы/нимба/короны.")
        addSlider(d, "HatSize", "Радиус", { "ChinaHat", "Size" }, 1, 3.2, 2,
            "Ширина украшения в стадах.")
        addSlider(d, "HatHeight", "Высота конуса / короны", { "ChinaHat", "Height" }, 0.3, 1.4, 2,
            "Высота вершины конуса, кристалла или шипов короны.")
        addSlider(d, "HatOpacity", "Непрозрачность", { "ChinaHat", "Opacity" }, 0.1, 0.9, 2,
            "Плотность цвета заливки и линий.")
        addToggle(d, "HatHideFP", "Скрывать от 1-го лица", { "ChinaHat", "HideFirstPerson" },
            "Автоматически прячет объект, когда камера приближена вплотную к голове, чтобы не мешать обзору.")
        addColorPicker(d, "HatColor", "Свой цвет (Custom)", { "ChinaHat", "Color" })
    end)

    CUR_GROUP = "Аура персонажа"
    local au = rightFxTabs:AddTab("Аура")
    addToggle(au, "AuraOn", "Включить ауру", { "PlayerAura", "Enabled" },
        "Создаёт объёмную энергетическую ауру вокруг персонажа (Orbitals, Helix, Crown, Ground, Sigil, Galaxy, Vortex или Atom).")
    withDep(au, "AuraOn", true, function(d)
        addDropdown(d, "AuraShape", "Форма ауры", { "PlayerAura", "Shape" }, { "Orbitals", "Helix", "Crown", "Ground", "Sigil", "Galaxy", "Vortex", "Atom" },
            "Orbitals/Helix/Crown/Ground; Sigil — печать на земле; Galaxy — кольца Сатурна; Vortex — восходящий вихрь; Atom — электронные орбитали.")
        addDropdown(d, "AuraStyle", "Стиль ауры", { "PlayerAura", "Style" }, { "Aurora", "Holographic", "Rainbow", "Cyber", "Flame", "Void", "Frost", "Sakura", "Matrix", "Sunset", "Gold", "Custom" },
            "Цветовая схема свечения и частиц ауры.")
        addSlider(d, "AuraSize", "Размер ауры", { "PlayerAura", "Size" }, 1.8, 8, 1,
            "Радиус объёмной ауры вокруг персонажа.")
        addSlider(d, "AuraTransparency", "Прозрачность ауры", { "PlayerAura", "Transparency" }, 0.1, 0.95, 2,
            "Насколько мягко и полупрозрачно выглядят линии ауры.")
        addToggle(d, "AuraParticles", "Частицы вокруг тела", { "PlayerAura", "Particles" },
            "Добавляет искры, поднимающиеся вокруг всего силуэта персонажа.")
        addToggle(d, "AuraLight", "Подсветка окружения (Glow Light)", { "PlayerAura", "GlowLight" },
            "Добавляет мягкий клиентский свет (PointLight), подсвечивающий персонажа и землю в цвет ауры.")
        addColorPicker(d, "AuraColor", "Свой цвет ауры", { "PlayerAura", "Color" })
    end)

    CUR_GROUP = "Орбитальные спутники"
    local sat = rightFxTabs:AddTab("Спутники")
    addToggle(sat, "SatOn", "Включить спутников", { "Satellites", "Enabled" },
        "Запускает 3D-кристаллы, сферы, клинки, осколки (Shard) или диски (Disc), летающие по орбитам вокруг персонажа.")
    withDep(sat, "SatOn", true, function(d)
        addDropdown(d, "SatShape", "Форма спутников", { "Satellites", "Shape" }, { "Crystal", "Orb", "Blade", "Shard", "Disc" },
            "Crystal — граненые кристаллы; Orb — сферы; Blade — клинки; Shard — вращающиеся осколки; Disc — плоские чакрамы с контуром.")
        addDropdown(d, "SatStyle", "Цветовой стиль", { "Satellites", "Style" }, { "Aurora", "Holographic", "Rainbow", "Cyber", "Flame", "Void", "Frost", "Sakura", "Matrix", "Sunset", "Gold", "Custom" },
            "Цветовая палитра спутников и их шлейфов.")
        addSlider(d, "SatCount", "Количество спутников", { "Satellites", "Count" }, 1, 6, 0,
            "Сколько объектов одновременно вращается на орбите.")
        addSlider(d, "SatRadius", "Радиус орбиты", { "Satellites", "Radius" }, 1.5, 7, 1,
            "Дистанция орбиты от тела персонажа в стадах.")
        addSlider(d, "SatHeight", "Смещение по высоте", { "Satellites", "Height" }, -2, 4, 1,
            "Поднимает или опускает плоскость орбит относительно центра персонажа.")
        addSlider(d, "SatSpeed", "Скорость вращения", { "Satellites", "Speed" }, 0.3, 4, 1,
            "Как быстро спутники облетают вокруг вас.")
        addSlider(d, "SatSize", "Размер спутников", { "Satellites", "Size" }, 0.2, 1.2, 2,
            "Физический размер каждого спутника.")
        addToggle(d, "SatTrails", "Светящиеся шлейфы", { "Satellites", "Trails" },
            "Добавляет за каждым спутником плавную светящуюся ленту движения.")
        addColorPicker(d, "SatColor", "Свой цвет (Custom)", { "Satellites", "Color" })
    end)

    CUR_GROUP = "Кольца прыжка"
    local jr = rightFxTabs:AddTab("Кольца прыжка")
    addToggle(jr, "JumpRingsOn", "Включить ударную волну прыжка", { "JumpRings", "Enabled" },
        "При каждом вашем прыжке и приземлении под ногами расходится светящаяся двойная ударная волна с искрами.")
    withDep(jr, "JumpRingsOn", true, function(d)
        addDropdown(d, "JumpRingsStyle", "Стиль волн", { "JumpRings", "Style" }, { "Aurora", "Holographic", "Rainbow", "Cyber", "Flame", "Void", "Frost", "Sakura", "Matrix", "Sunset", "Gold", "Custom" },
            "Цветовой стиль расширяющихся волн.")
        addSlider(d, "JumpRingsRad", "Макс. радиус", { "JumpRings", "MaxRadius" }, 2, 12, 1,
            "До какого размера расширяется волна перед исчезновением.")
        addSlider(d, "JumpRingsLife", "Время жизни", { "JumpRings", "Lifetime" }, 0.2, 1.5, 2,
            "Длительность анимации расширения волны в секундах.")
        addToggle(d, "JumpRingsSparks", "Вторая волна и лучи вверх", { "JumpRings", "Sparks" },
            "Добавляет внутреннюю задержную волну и 8 вертикальных искр при отрыве/приземлении.")
        addColorPicker(d, "JumpRingsCol", "Свой цвет волн", { "JumpRings", "Color" })
    end)
end

do
    CUR_TAB, CUR_GROUP = "Оверлей и HUD", "HUD и индикаторы"
    local hud = Tabs.Overlay:AddLeftGroupbox("HUD и индикаторы")
    addToggle(hud, "Watermark", "Водяной знак (FPS / Пинг / Draw)", { "Overlay", "Watermark" },
        "Компактная плашка вверху экрана с версией хаба, текущим FPS, пингом и счётчиком активных Drawing-объектов.")
    addToggle(hud, "Keybinds", "Список активных модулей", { "Overlay", "Keybinds" },
        "Показывает аккуратную боковую панель со списком всех включённых в данный момент модулей и их биндами.")
    addToggle(hud, "TargetHUD", "Панель цели (Target HUD)", { "Overlay", "TargetHUD" },
        "Выводит карточку ближайшего/приоритетного врага: ник, здоровье, дистанция, оружие и статус видимости.")
    withDep(hud, "TargetHUD", true, function(d)
        addDropdown(d, "TargetHUDPos", "Позиция Target HUD", { "Overlay", "TargetHUDPos" },
            { "BottomCenter", "TopCenter", "RightCenter" },
            "Место на экране для карточки цели: снизу по центру, сверху по центру или справа.",
            function()
                if not isSyncingUI then cfg().Overlay.TargetHUDX = -1 cfg().Overlay.TargetHUDY = -1 end
            end)
    end)
    addToggle(hud, "SpeedArcOn", "Спидометр (дуга)", { "Overlay", "Speedometer" },
        "Рисует дуговой спидометр и текущую скорость вашего персонажа в стадах/сек.")
    withDep(hud, "SpeedArcOn", true, function(d)
        addSlider(d, "SpeedArcMax", "Макс. шкала спидометра", { "Overlay", "SpeedometerMax" }, 20, 150, 0,
            "Скорость, при которой дуга спидометра заполняется на 100%.")
    end)
    addToggle(hud, "SpeedLinesOn", "Аниме-линии скорости (Speed Lines)", { "Overlay", "SpeedLines" },
        "При быстром беге или падении по краям экрана вспыхивают динамические радиальные линии скорости.")
    withDep(hud, "SpeedLinesOn", true, function(d)
        addSlider(d, "SpeedLinesMin", "Мин. скорость появления", { "Overlay", "SpeedLinesMinSpeed" }, 8, 60, 0,
            "Порог скорости в стадах/сек, с которого появляются линии по краям экрана.")
        addSlider(d, "SpeedLinesOp", "Прозрачность линий", { "Overlay", "SpeedLinesOpacity" }, 0.1, 1, 2,
            "Яркость и насыщенность боковых линий скорости.")
        addToggle(d, "SpeedLinesRb", "Радужные линии", { "Overlay", "SpeedLinesRainbow" },
            "Переливает линии скорости цветами радуги.")
        addColorPicker(d, "SpeedLinesCol", "Цвет линий скорости", { "Overlay", "SpeedLinesColor" })
    end)
    addColorPicker(hud, "Accent", "Акцентный цвет HUD", { "Overlay", "Accent" })
    addToggle(hud, "DragHUD", "Перетаскивать HUD мышкой", { "Overlay", "DragHUD" },
        "Разрешает хватать мышкой и свободно двигать Target HUD, Мини-радар и Список модулей прямо по экрану.")
    withDep(hud, "DragHUD", true, function(d)
        d:AddButton({
            Text = "Сбросить позиции HUD",
            Tooltip = "Возвращает Target HUD, Мини-радар и Список модулей на стандартные места.",
            Func = function()
                cfg().Radar.PosX, cfg().Radar.PosY = -1, -1
                cfg().Overlay.TargetHUDX, cfg().Overlay.TargetHUDY = -1, -1
                cfg().Overlay.KeybindsX, cfg().Overlay.KeybindsY = -1, -1
                pcall(function() Library:Notify({ Title = "HUD", Description = "Позиции HUD сброшены", Time = 2 }) end)
            end,
        })
    end)

    CUR_GROUP = "Виньетка экрана"
    local vg = Tabs.Overlay:AddLeftGroupbox("Виньетка экрана")
    addToggle(vg, "VigLowHP", "Пульсация при низком HP", { "Vignette", "LowHP" },
        "Края экрана начинают тревожно пульсировать, когда ваше здоровье падает ниже заданного порога.")
    withDep(vg, "VigLowHP", true, function(d)
        addSlider(d, "VigLowHPThr", "Порог низкого HP (%)", { "Vignette", "LowHPThreshold" }, 10, 75, 0,
            "Процент здоровья, с которого включается пульсирующая виньетка.")
        addColorPicker(d, "VigLowHPCol", "Цвет низкого HP", { "Vignette", "LowHPColor" })
    end)
    addToggle(vg, "VigKill", "Вспышка при убийстве (Kill Flash)", { "Vignette", "KillFlash" },
        "При смерти ближайшей отслеживаемой цели по краям экрана проходит короткая цветная вспышка.")
    withDep(vg, "VigKill", true, function(d)
        addColorPicker(d, "VigKillCol", "Цвет вспышки убийства", { "Vignette", "KillColor" })
    end)
    addSlider(vg, "VigIntensity", "Яркость виньетки", { "Vignette", "Intensity" }, 0.2, 1.5, 2,
        "Общая интенсивность затемнения/подсветки краёв экрана.")

    CUR_GROUP = "Кастомный прицел"
    local xh = Tabs.Overlay:AddRightGroupbox("Кастомный прицел")
    addToggle(xh, "XhOn", "Включить прицел", { "Crosshair", "Enabled" },
        "Рисует собственный настраиваемый прицел поверх игры в центре экрана.")
    withDep(xh, "XhOn", true, function(d)
        addDropdown(d, "XhStyle", "Стиль прицела", { "Crosshair", "Style" }, { "Classic", "T-Cross", "X-Cross", "Sniper", "Circle", "Brackets", "Chevron", "Diamond" },
            "Classic — крест; T-Cross — без верха; X-Cross — диагональный крест; Sniper — дальномер с рисками; Circle/Brackets/Chevron/Diamond.")
        addSlider(d, "XhSize", "Длина штрихов / радиус", { "Crosshair", "Size" }, 2, 30, 0,
            "Размер линий прицела или радиус круга.")
        addSlider(d, "XhGap", "Зазор от центра", { "Crosshair", "Gap" }, 0, 20, 0,
            "Отступ штрихов от самой центральной точки.")
        addSlider(d, "XhThick", "Толщина линий", { "Crosshair", "Thickness" }, 1, 4, 0,
            "Толщина линий прицела в пикселях.")
        addToggle(d, "XhDot", "Точка в центре", { "Crosshair", "Dot" },
            "Добавляет маленькую точку ровно по центру прицела.")
        addToggle(d, "XhOutline", "Обводка прицела", { "Crosshair", "Outline" },
            "Чёрная подложка под прицелом, чтобы не терялся на ярком небе или снегу.")
        addToggle(d, "XhDyn", "Динамический разброс", { "Crosshair", "Dynamic" },
            "Расширяет штрихи прицела при быстром беге или прыжке.")
        addToggle(d, "XhSpin", "Вращение", { "Crosshair", "Spin" },
            "Плавно вращает прицел вокруг своей оси.")
        addToggle(d, "XhRainbow", "Радужный цвет", { "Crosshair", "Rainbow" },
            "Прицел плавно переливается цветами радуги.")
        addColorPicker(d, "XhColor", "Цвет прицела", { "Crosshair", "Color" })
    end)

    CUR_GROUP = "Хитмаркер"
    local hm = Tabs.Overlay:AddRightGroupbox("Хитмаркер (индикатор попадания)")
    addToggle(hm, "HmOn", "Включить хитмаркер", { "Hitmarker", "Enabled" },
        "Рисует хитмаркер по центру экрана при потере HP у отслеживаемой цели (визуальная реакция без модификации оружия).")
    withDep(hm, "HmOn", true, function(d)
        addDropdown(d, "HmStyle", "Стиль хитмаркера", { "Hitmarker", "Style" }, { "Cross", "Double", "Star", "Circle", "Diamond" },
            "Cross — X-крест; Double — двойной крест; Star — 8-лучевая звезда; Circle — расширяющееся кольцо; Diamond — ромб-вспышка.")
        addSlider(d, "HmSize", "Размер крестика", { "Hitmarker", "Size" }, 4, 20, 0,
            "Длина лучей хитмаркера в пикселях.")
        addSlider(d, "HmThick", "Толщина", { "Hitmarker", "Thickness" }, 1, 4, 0,
            "Толщина линий хитмаркера.")
        addSlider(d, "HmDur", "Длительность показа", { "Hitmarker", "Duration" }, 0.1, 0.7, 2,
            "Сколько секунд хитмаркер остаётся на экране после урона.")
        addColorPicker(d, "HmColor", "Цвет попадания", { "Hitmarker", "Color" })
        addColorPicker(d, "HmKillCol", "Цвет добивания", { "Hitmarker", "KillColor" })
    end)
    addToggle(hm, "KillFxOn", "3D-вспышка на месте убийства", { "Hitmarker", "KillEffect" },
        "При добивании цели на её месте в 3D-мире вспыхивают расходящиеся энергетические лучи и ударное кольцо.")

    CUR_GROUP = "Мини-радар"
    local rd = Tabs.Overlay:AddRightGroupbox("Мини-радар")
    addToggle(rd, "RadarOn", "Включить радар", { "Radar", "Enabled" },
        "Включает 2D мини-карту с позициями игроков вокруг вас. Горячая клавиша настраивается в «Настройки UI» (по умолчанию F4).")
    withDep(rd, "RadarOn", true, function(d)
        addDropdown(d, "RadarPos", "Угол экрана", { "Radar", "Position" },
            { "TopLeft", "TopRight", "BottomLeft", "BottomRight" },
            "Угол экрана, в котором закрепляется окно радара (автоматически смещается ниже HUD, чтобы не перекрывать их).",
            function()
                if not isSyncingUI then cfg().Radar.PosX = -1 cfg().Radar.PosY = -1 end
            end)
        addSlider(d, "RadarSize", "Размер радара", { "Radar", "Size" }, 80, 260, 0,
            "Ширина и высота квадратного радара в пикселях.")
        addSlider(d, "RadarRange", "Радиус радара (стады)", { "Radar", "Range" }, 50, 25000, 0,
            "На какой дистанции игроки попадают в границы радара.")
        addSlider(d, "RadarOpacity", "Непрозрачность фона", { "Radar", "Opacity" }, 0.1, 1, 2,
            "Насколько плотным будет тёмный фон мини-радара.")
        addSlider(d, "RadarDot", "Размер точек", { "Radar", "DotSize" }, 2, 6, 0,
            "Размер маркеров игроков на радаре.")
        addToggle(d, "RadarLook", "Показывать направление взгляда", { "Radar", "ShowLookDir" },
            "Рисует короткую чёрточку от каждой точки на радаре в сторону, куда смотрит игрок.")
        addToggle(d, "RadarSweep", "Вращающийся луч радара", { "Radar", "Sweep" },
            "Добавляет тактическую развёртку радара, кольца дистанции (33%/66%) и подсветку приоритетной цели.")
    end)
end

do
    CUR_TAB, CUR_GROUP = "Угрозы и звук", "Звук приближения"
    local prox = Tabs.Awareness:AddLeftGroupbox("Звук приближения (Proximity)")
    addToggle(prox, "ProxOn", "Включить звуковой радар", { "Proximity", "Enabled" },
        "Проигрывает звуковой сигнал, когда противник подходит ближе заданной дистанции.")
    withDep(prox, "ProxOn", true, function(d)
        addSlider(d, "ProxDistance", "Дистанция срабатывания (стады)", { "Proximity", "Distance" }, 5, 2000, 0,
            "Радиус вокруг вас, при входе в который сработает звуковое предупреждение.")
        addDropdown(d, "ProxPreset", "Пресет звука", { "Proximity", "SoundPreset" },
            { "Ping (Classic)", "Notification", "UI Beep", "Bass Thump", "Snap", "Hit", "Custom" },
            "Готовые встроенные звуки Roblox или выбор своего ID в режиме Custom.",
            function(v)
                local presetId = SOUND_PRESETS[v]
                if presetId then
                    cfg().Proximity.SoundId = presetId
                    safeSet("ProxSoundId", presetId)
                end
            end)
        addInput(d, "ProxSoundId", "Sound ID (свой звук)", { "Proximity", "SoundId" }, "rbxassetid://12221990",
            "Можно вставить числовой ID или rbxassetid://... любого звука из библиотеки Roblox.",
            function(v)
                local curPreset = cfg().Proximity.SoundPreset
                if curPreset ~= "Custom" and SOUND_PRESETS[curPreset] ~= v then
                    cfg().Proximity.SoundPreset = "Custom"
                    safeSet("ProxPreset", "Custom")
                end
            end)
        addSlider(d, "ProxVolume", "Громкость", { "Proximity", "Volume" }, 0, 2, 2,
            "Громкость сигнала предупреждения.")
        addSlider(d, "ProxCooldown", "Кулдаун на игрока (сек)", { "Proximity", "Cooldown" }, 0.5, 15, 1,
            "Пауза между повторными сигналами от одного и того же игрока, чтобы звук не спамил.")
        addDropdown(d, "ProxDirection", "Фильтр направления", { "Proximity", "Direction" }, { "Any Direction", "Behind Only", "Front Only" },
            "Any Direction — со всех сторон, Behind Only — только когда враг сзади, Front Only — только спереди.")
        addToggle(d, "ProxSpatial", "3D позиционный звук", { "Proximity", "SpatialSound" },
            "Привязывает звук к позиции врага в 3D-пространстве: в наушниках слышно, слева он или справа.")
        addToggle(d, "ProxTeams", "Игнорировать союзников", { "Proximity", "IgnoreTeammates" },
            "Не реагировать на приближение тиммейтов.")
        d:AddButton({
            Text = "Проверить звук",
            Tooltip = "Воспроизводит выбранный звук сейчас, чтобы проверить громкость и пресет.",
            Func = function()
                local raw = SOUND_PRESETS[cfg().Proximity.SoundPreset] or cfg().Proximity.SoundId
                if not Aware.normalizeSoundId(raw) then
                    pcall(function()
                        Library:Notify({ Title = "Proximity", Description = "Выбери Sound Preset или укажи Sound ID", Time = 3 })
                    end)
                    return
                end
                Aware.playProximitySound(getRootPart(LP.Character))
            end,
        })
        regSearch("Проверить звук", "Воспроизводит выбранный звук приближения")
    end)

    CUR_GROUP = "Уведомления сервера"
    local nt = Tabs.Awareness:AddLeftGroupbox("Уведомления сервера")
    addToggle(nt, "JoinLeave", "Вход / выход игроков", { "Misc", "JoinLeave" },
        "Показывает всплывающее уведомление, когда кто-то заходит на сервер или выходит с него.")

    CUR_GROUP = "Тревога «Смотрит на вас»"
    local la = Tabs.Awareness:AddRightGroupbox("Тревога «Смотрит на вас»")
    addToggle(la, "LookAlertOn", "Включить индикатор взгляда", { "LookingAlert", "Enabled" },
        "Выводит направленную дугу со стрелкой и именем ближайшего врага, который смотрит прямо в вашу сторону.")
    withDep(la, "LookAlertOn", true, function(d)
        addSlider(d, "LookAlertDist", "Макс. дистанция", { "LookingAlert", "MaxDistance" }, 30, 1500, 0,
            "Дальность, на которой отслеживается взгляд врагов в вашу сторону.")
        addSlider(d, "LookAlertAng", "Угол допуска (градусы)", { "LookingAlert", "Angle" }, 5, 40, 0,
            "Насколько точно враг должен смотреть на вас: 5° — почти точно в прицеле, 40° — широкий конус.")
        addSlider(d, "LookAlertRad", "Радиус дуги (px)", { "LookingAlert", "Radius" }, 45, 160, 0,
            "На каком расстоянии от центра экрана рисуются направленные дуги (удобно развести со спидометром и прицелом).")
        addToggle(d, "LookAlertLoS", "Только без стен (Line of Sight)", { "LookingAlert", "RequireLoS" },
            "Если включено, тревога сработает только если между вами и смотрящим врагом нет стены.")
        addToggle(d, "LookAlertTeams", "Игнорировать союзников", { "LookingAlert", "HideTeammates" },
            "Не показывать предупреждение, если на вас смотрит союзник.")
        addColorPicker(d, "LookAlertCol", "Цвет индикатора", { "LookingAlert", "Color" })
    end)

    CUR_GROUP = "Кольца шагов"
    local fr = Tabs.Awareness:AddRightGroupbox("Кольца шагов врагов")
    addToggle(fr, "StepRingsOn", "Включить кольца шагов и прыжков", { "FootstepRings", "Enabled" },
        "Рисует 3D-волны на земле под ногами бегущих или приземляющихся врагов — помогает слышать/видеть фланги через стены.")
    withDep(fr, "StepRingsOn", true, function(d)
        addDropdown(d, "StepRingsStyle", "Стиль колец", { "FootstepRings", "Style" }, { "Pulse", "Solid" },
            "Pulse — двойная расходящаяся эхо-волна на земле; Solid — одиночное чёткое кольцо.")
        addSlider(d, "StepRingsDist", "Макс. дистанция (стады)", { "FootstepRings", "MaxDistance" }, 20, 400, 0,
            "Дальность, на которой появляются волны от шагов противников.")
        addSlider(d, "StepRingsMax", "Макс. колец на экране", { "FootstepRings", "MaxRings" }, 4, 24, 0,
            "Лимит одновременно отображаемых колец шагов для защиты FPS.")
        addSlider(d, "StepRingsRad", "Радиус кольца", { "FootstepRings", "MaxRadius" }, 1.5, 8, 1,
            "Конечный размер волны от шага на земле.")
        addSlider(d, "StepRingsLife", "Длительность волны", { "FootstepRings", "Lifetime" }, 0.25, 1.5, 2,
            "Сколько секунд волна от шага затухает на поверхности.")
        addToggle(d, "StepRingsTeams", "Игнорировать союзников", { "FootstepRings", "HideTeammates" },
            "Не рисовать кольца шагов от тиммейтов.")
        addColorPicker(d, "StepRingsCol", "Цвет колец шагов", { "FootstepRings", "Color" })
    end)
end

do
    CUR_TAB, CUR_GROUP = "Объекты", "Object ESP"
    local o = Tabs.Objects:AddLeftGroupbox("Поиск объектов (Object ESP)")
    addToggle(o, "ObjOn", "Включить Object ESP", { "Objects", "Enabled" },
        "Ищет и подсвечивает на карте любые предметы, сундуки, монеты, двери или NPC по списку слов и исключений.")
    withDep(o, "ObjOn", true, function(d)
        addInput(d, "ObjFilter", "Фильтр (через запятую, -исключение)", { "Objects", "Filter" }, "chest, key, -plate",
            "Можно писать несколько слов через запятую и исключения через минус, например: chest, coin, -chestplate.",
            function() Obj.last = 0 end)
        addToggle(d, "ObjUnlimDist", "Без лимита дистанции", { "Objects", "UnlimitedDistance" },
            "Показывает найденные объекты на любом расстоянии без обрезки по дистанции.")
        withDep(d, "ObjUnlimDist", false, function(sd)
            addSlider(sd, "ObjDist", "Макс. дистанция", { "Objects", "MaxDistance" }, 50, 50000, 0,
                "Максимальное расстояние до подсвечиваемых объектов в стадах.")
        end)
        addSlider(d, "ObjMax", "Макс. объектов на экране", { "Objects", "MaxCount" }, 5, 150, 0,
            "Сколько ближайших найденных объектов отображать одновременно.")
        addSlider(d, "ObjInt", "Интервал перескана (сек)", { "Objects", "Interval" }, 1, 15, 0,
            "Как часто скрипт сканирует карту заново для поиска новых заспавнившихся предметов.")
        addToggle(d, "ObjDistTxt", "Показывать дистанцию", { "Objects", "ShowDistance" },
            "Добавляет расстояние в стадах рядом с названием найденного объекта.")
        addToggle(d, "ObjTracer", "Трейсеры к объектам", { "Objects", "ShowTracer" },
            "Рисует линии от нижней части экрана к найденным объектам.")
        addColorPicker(d, "ObjColor", "Цвет объектов", { "Objects", "Color" })
        d:AddButton({
            Text = "Сканировать сейчас",
            Tooltip = "Запускает немедленный поиск объектов по указанному фильтру без ожидания таймера.",
            Func = function() Obj.last = 0 end,
        })
        regSearch("Сканировать сейчас", "Немедленный поиск объектов по фильтру")
    end)

    CUR_GROUP = "Быстрые фильтры"
    local oq = Tabs.Objects:AddRightGroupbox("Быстрые фильтры")
    local function setObjFilterPreset(filterStr, enableOn)
        cfg().Objects.Filter = filterStr
        if enableOn then cfg().Objects.Enabled = true end
        Obj.last = 0
        syncUI()
    end
    oq:AddLabel("В 1 клик подставляют популярные шаблоны поиска и сразу запускают скан.", true)
    oq:AddButton({
        Text = "Сундуки и лут",
        Tooltip = "Ищет chest, crate, loot, box, drop (исключая chestplate).",
        Func = function() setObjFilterPreset("chest, crate, loot, box, drop, -chestplate", true) end,
    })
    oq:AddButton({
        Text = "Монеты и гемы",
        Tooltip = "Ищет coin, gem, crystal, orb, star, cash, money.",
        Func = function() setObjFilterPreset("coin, gem, crystal, orb, star, cash, money", true) end,
    })
    oq:AddButton({
        Text = "Ключи и карты доступа",
        Tooltip = "Ищет key, keycard, card, pass, code (исключая keyboard).",
        Func = function() setObjFilterPreset("key, keycard, card, pass, code, -keyboard", true) end,
    })
    oq:AddButton({
        Text = "Двери, порталы и выходы",
        Tooltip = "Ищет door, exit, portal, gate, hatch, vent.",
        Func = function() setObjFilterPreset("door, exit, portal, gate, hatch, vent", true) end,
    })
    oq:AddButton({
        Text = "Очистить фильтр",
        Tooltip = "Очищает строку фильтра поиска объектов.",
        Func = function() setObjFilterPreset("", false) end,
    })
    regSearch("Быстрые фильтры объектов (Сундуки / Монеты / Ключи / Двери)", "Готовые шаблоны поиска для Object ESP")
end

do
    CUR_TAB, CUR_GROUP = "Мир и камера", "Атмосфера и небо"
    local w = Tabs.World:AddLeftGroupbox("Атмосфера и небо")
    addDropdown(w, "WorldPreset", "Пресет атмосферы", { "World", "Preset" },
        { "None", "Clean Night", "Cyberpunk", "Cold Frost", "Warm Sunset", "Blood Moon", "Emerald Matrix", "Solar Gold", "Tokyo Neon", "Sakura Dusk", "Crimson Void", "Golden Dawn", "Midnight Mist" },
        "Готовая тема освещения: автоматически выставляет время суток, цветокоррекцию, туман и неон.",
        function(v)
            if isSyncingUI then return end
            local p = WORLD_PRESETS[v]
            if not p then
                if v == "None" then
                    cfg().World.TimeEnabled = false
                    cfg().World.Grading = false
                    cfg().World.AmbientEnabled = false
                    cfg().World.BloomEnabled = false
                    syncUI()
                end
                return
            end
            for k, val in pairs(p) do
                if cfg().World[k] ~= nil then cfg().World[k] = val end
            end
            syncUI()
        end)
    addDropdown(w, "WorldSky", "Замена неба (Sky)", { "World", "SkyPreset" },
        { "Auto", "None", "Clean Night", "Cyberpunk", "Cold Frost", "Warm Sunset", "Blood Moon", "Emerald Matrix", "Solar Gold", "Tokyo Neon", "Sakura Dusk", "Crimson Void", "Golden Dawn", "Midnight Mist" },
        "Auto — берёт небо из выбранного пресета атмосферы; None — оставляет родное небо игры.")
    addDropdown(w, "WorldWeather", "Погодные частицы", { "World", "Weather" },
        { "None", "Rain", "Snow", "CyberDust", "Embers", "Fireflies", "Sakura", "MatrixRain", "Starfall", "BloodRain" },
        "Клиентские частицы: дождь, снег, CyberDust, Embers, Fireflies, Sakura, MatrixRain, звездопад Starfall и BloodRain.")
    addSlider(w, "WorldWeatherInt", "Интенсивность погоды", { "World", "WeatherIntensity" }, 0.2, 1.5, 2,
        "Плотность и скорость появления частиц дождя, снега или пыли.")
    addToggle(w, "NoFog", "Убрать туман и дымку", { "World", "NoFog" },
        "Отключает стандартный Fog и Atmosphere-дымку на карте для максимально чистой видимости вдаль.")
    addToggle(w, "TimeOn", "Своё время суток", { "World", "TimeEnabled" },
        "Фиксирует выбранный час суток только у вас на клиенте (удобно сделать ночь или день для лучшей видимости).")
    withDep(w, "TimeOn", true, function(d)
        addSlider(d, "TimeVal", "Время (часы)", { "World", "Time" }, 0, 24, 1,
            "Время суток в Lighting.ClockTime: 0 — полночь, 12 — полдень, 18 — закат.")
    end)
    addToggle(w, "AmbientOn", "Свой цвет освещения", { "World", "AmbientEnabled" },
        "Переопределяет базовый цвет теней и уличного освещения на всей карте.")
    withDep(w, "AmbientOn", true, function(d)
        addColorPicker(d, "AmbientCol", "Внутреннее освещение (Ambient)", { "World", "Ambient" })
        addColorPicker(d, "OutdoorCol", "Уличное освещение (Outdoor)", { "World", "OutdoorAmbient" })
    end)

    CUR_GROUP = "Камера и FOV"
    local camGb = Tabs.World:AddRightGroupbox("Камера и угол обзора (FOV)")
    addToggle(camGb, "FovOn", "Свой FOV (угол обзора)", { "World", "FOVEnabled" },
        "Фиксирует желаемый угол обзора камеры (Field of View) даже если игра сбрасывает его при беге/прицеливании.")
    withDep(camGb, "FovOn", true, function(d)
        addSlider(d, "FovVal", "Базовый FOV", { "World", "FOV" }, 50, 120, 0,
            "Стандартное значение Roblox — 70. Чем больше число, тем шире обзор.")
    end)
    addToggle(camGb, "SpeedFovOn", "Динамический FOV от скорости", { "World", "SpeedFOV" },
        "Плавно расширяет угол обзора при быстром беге или рывках — добавляет ощущение высокой скорости.")
    withDep(camGb, "SpeedFovOn", true, function(d)
        addSlider(d, "SpeedFovMax", "Макс. бонус FOV", { "World", "SpeedFOVMax" }, 3, 35, 0,
            "Максимальная прибавка к базовому FOV на пиковой скорости.")
        addSlider(d, "SpeedFovSens", "Чувствительность ускорения", { "World", "SpeedFOVSens" }, 0.3, 2.5, 2,
            "Насколько резко FOV реагирует на разгон персонажа.")
    end)

    CUR_GROUP = "Цветокоррекция и Bloom"
    local gr = Tabs.World:AddRightGroupbox("Цветокоррекция и свечение (Bloom)")
    addToggle(gr, "GradeOn", "Включить цветокоррекцию", { "World", "Grading" },
        "Создаёт клиентский ColorCorrectionEffect для настройки насыщенности, контраста и оттенка картинки.")
    withDep(gr, "GradeOn", true, function(d)
        addSlider(d, "GradeSat", "Насыщенность (Saturation)", { "World", "Saturation" }, -1, 1, 2,
            "-1 — чёрно-белая картинка, 0 — стандарт, +1 — максимально сочные цвета.")
        addSlider(d, "GradeCon", "Контраст (Contrast)", { "World", "Contrast" }, -1, 1, 2,
            "Регулировка контрастности света и теней.")
        addColorPicker(d, "GradeTint", "Оттенок экрана (Tint)", { "World", "Tint" })
    end)
    addToggle(gr, "BloomOn", "Включить свечение (Bloom)", { "World", "BloomEnabled" },
        "Добавляет мягкое сияние вокруг ярких объектов, неона, чамсов и эффектов.")
    withDep(gr, "BloomOn", true, function(d)
        addSlider(d, "BloomInt", "Сила свечения", { "World", "BloomIntensity" }, 0, 2, 2,
            "Яркость ореола свечения.")
        addSlider(d, "BloomSize", "Радиус размытия Bloom", { "World", "BloomSize" }, 4, 48, 0,
            "Насколько широко расходится светящийся ореол.")
        addSlider(d, "BloomThr", "Порог срабатывания", { "World", "BloomThreshold" }, 0.5, 2, 2,
            "Чем ниже порог, тем больше светлых поверхностей начинают светиться.")
    end)
end

do
    local HELP_ORDER = {
        "Общее и быстрый старт",
        "ВХ (ESP) и проверка видимости",
        "Персонаж и FX (Sandevistan / Стекло)",
        "Оверлей, TargetHUD и Хитмаркер",
        "Угрозы и звук (Proximity / Взгляд / Шаги)",
        "Мир, Погода и Speed FOV",
        "Поиск объектов (Object ESP)",
        "Горячие клавиши и пресеты",
        "Советы по FPS",
    }

    local HELP_TOPICS = {
        ["Общее и быстрый старт"] = table.concat({
            "glupost hub — это клиентский визуальный хаб (ESP, FX, радар, HUD и атмосфера).",
            "",
            "• При запуске все функции выключены по умолчанию — включите только то, что нужно сейчас (или нажмите F1 для ВХ).",
            "• Дополнительные настройки каждого модуля скрыты и раскрываются автоматически при его включении.",
            "• Наведите курсор на любую настройку в соседних вкладках — появится всплывающая подсказка с описанием.",
            "• Скрыть или открыть меню: клавиша RightShift (меняется в «Настройки UI»).",
            "• Сбросить все включённые функции в 1 клик: кнопка «Выключить всё» в «Настройки UI».",
        }, "\n"),
        ["ВХ (ESP) и проверка видимости"] = table.concat({
            "• Включить ВХ (F1): рисует рамки, HP, имена, оружие и дистанцию.",
            "• Дальность прорисовки: до 50000 стадов либо переключатель «Без лимита дистанции».",
            "• Тип рамки (F2): 2D — быстрая; Corner — уголки; Bracket — тактические скобки; 3D — объёмный куб (тяжелее для FPS).",
            "• Проверка видимости: делит игроков на видимых (Visible) и за укрытиями (Occluded). «Умная проверка» пропускает стёкла и полупрозрачную листву.",
            "• Опасная цель (Priority): вычисляет % угрозы по расстоянию, взгляду врага на вас и полученному урону, выделяя цель отдельным цветом, пульсирующим кольцом на голове и стрелке.",
            "• Чамсы врагов: работают через Roblox Highlight (до 28 ближайших игроков); прозрачность заливки и контура настраиваются раздельно.",
        }, "\n"),
        ["Персонаж и FX (Sandevistan / Стекло)"] = table.concat({
            "• Чамсы на себя: Liquid Glass, Energy Rim (чистый скин + неон-контур), Scanline, ForceField и 14 цветовых палитр.",
            "• Sandevistan (клоны): Phantom/Inferno/Void/Cyber/Sakura/Matrix/Sunset/Gold, материалы ForceField/Glass/Wireframe, 6 режимов исчезновения + нить связи.",
            "• Ленты / Шлейф (Ribbons): 8 форм (Orbit, Helix, Void Slash, Spiral Halo, крылья и конечности) + 5 узоров + искры; работают даже вместе с Sandevistan!",
            "• Орбитальные спутники (Satellites): Crystal, Orb, Blade, Shard (осколки) и Disc (чакрамы) со шлейфами на наклонных орбитах.",
            "• Аура персонажа: Orbitals, Helix, Crown, Ground, Sigil, Galaxy, Vortex (восходящий вихрь) и Atom (орбитали электронов) + Glow Light.",
            "• Шляпа / Нимб / Корона / Crystal / CyberRing и ударные волны прыжка с искрами; зум колесом мыши в 3-м лице.",
        }, "\n"),
        ["Оверлей, TargetHUD и Хитмаркер"] = table.concat({
            "• Водяной знак: плашка с FPS, пингом и числом Drawing-объектов; дуговой 18-сегментный спидометр и аниме-линии скорости (Speed Lines).",
            "• Target HUD: отдельная карточка приоритетной цели (имя, статус-полоса видимости/угрозы, HP, дистанция, оружие).",
            "• Перетаскивание HUD: включите «Перетаскивать HUD мышкой», чтобы двигать Target HUD, Радар и Список модулей прямо по экрану.",
            "• Виньетка экрана: 3-слойный градиент с тактическими уголками при низком HP и вспышкой при убийстве.",
            "• Кастомный прицел (8 стилей: Classic, T-Cross, X-Cross, Sniper, Circle, Brackets, Chevron, Diamond) + Хитмаркер (Cross, Double, Star, Circle, Diamond).",
            "• Мини-радар: 2D-радар с кольцами дистанции, вращающимся лучом (Sweep), точками игроков и выделением Priority-цели.",
        }, "\n"),
        ["Угрозы и звук (Proximity / Взгляд / Шаги)"] = table.concat({
            "• Звук приближения: проигрывает звук, когда враг заходит в радиус; режим «3D позиционный звук» позволяет в наушниках слышать сторону.",
            "• Тревога «Смотрит на вас»: рисует дугу со стрелкой в сторону смотрящего врага, имя ближайшего и позволяет настроить радиус дуги.",
            "• Кольца шагов: рисует двойную пульсирующую (Pulse) или одиночную (Solid) волну под ногами бегущих и прыгающих врагов.",
        }, "\n"),
        ["Мир, Погода и Speed FOV"] = table.concat({
            "• Пресеты атмосферы: в 1 клик меняют небо, время суток, цветокоррекцию и Bloom (Cyberpunk, Tokyo Neon, Sakura Dusk, Crimson Void, Golden Dawn и др.).",
            "• Погодные частицы: дождь, снег, CyberDust, Embers, Fireflies, Sakura, MatrixRain, звездопад Starfall и BloodRain.",
            "• Убрать туман: очищает стандартную дымку карты для обзора вдаль.",
            "• Динамический FOV от скорости: расширяет угол обзора при быстром беге или рывках.",
        }, "\n"),
        ["Поиск объектов (Object ESP)"] = table.concat({
            "• Ищет на карте любые модели и детали по фильтру через запятую и с исключениями через «-» (например: chest, key, -chestplate).",
            "• Есть переключатель «Без лимита дистанции» и слайдер дальности до 50000 стадов.",
            "• Показывает до 150 ближайших совпадений с расстоянием и опциональными трейсерами.",
        }, "\n"),
        ["Горячие клавиши и пресеты"] = table.concat({
            "Быстрые клавиши по умолчанию (все переназначаются в «Настройки UI → Горячие клавиши»):",
            "• RightShift — скрыть / открыть меню",
            "• F1 — включить / выключить ВХ (ESP)",
            "• F2 — переключить тип рамки (2D -> Corner -> Bracket -> 3D)",
            "• F3 — включить / выключить скелет",
            "• F4 — включить / выключить мини-радар",
            "• F5 — включить / выключить вид от 3-го лица",
            "• Вверху этой вкладки есть «Поиск по меню», а в «Настройки UI» — кнопка сброса автозагрузки (Autoload).",
        }, "\n"),
        ["Советы по FPS"] = table.concat({
            "Если на слабом ПК или в тяжёлой игре падает FPS:",
            "1. Во вкладке «ВХ (ESP)» нажмите кнопку «Оптимизация: выключить тяжёлое».",
            "2. Включите «Адаптивный LOD (вдали)» и выберите подгонку рамки Fixed.",
            "3. Отключите обводку скелета/трейсеров и «Проверка видимости», если игроков на сервере 30+.",
            "4. В Sandevistan уменьшите «Макс. копий одновременно» и увеличьте интервал.",
        }, "\n"),
    }

    local hs = Tabs.Help:AddLeftGroupbox("Поиск по меню")
    hs:AddInput("HelpSearch", {
        Text = "Найти настройку",
        Default = "",
        Placeholder = "скелет, дальность, зум, чамсы...",
        Finished = false,
        Tooltip = "Мгновенный поиск по названиям и описаниям всех функций хаба.",
        Callback = function(v) end,
    })
    local searchOut = hs:AddLabel("Введите слово — покажет, в какой вкладке и разделе лежит нужная настройка.", true)
    if Options.HelpSearch and Options.HelpSearch.OnChanged then
        pcall(function()
            Options.HelpSearch:OnChanged(function(v)
                local q = string.lower((v or ""):match("^%s*(.-)%s*$") or "")
                local msg
                if q == "" then
                    msg = "Введите слово — покажет, в какой вкладке и разделе лежит нужная настройка."
                else
                    local hits = {}
                    for _, item in ipairs(SEARCH_INDEX) do
                        if string.find(item.lower, q, 1, true) then
                            hits[#hits + 1] = string.format("• [%s → %s]\n  %s", item.tab, item.group, item.text)
                            if #hits >= 7 then break end
                        end
                    end
                    msg = #hits > 0 and table.concat(hits, "\n") or ("Ничего не найдено по запросу «" .. tostring(v) .. "».")
                end
                if searchOut and searchOut.SetText then
                    pcall(function() searchOut:SetText(msg) end)
                end
            end)
        end)
    end

    local hl = Tabs.Help:AddLeftGroupbox("Система пояснений")
    hl:AddLabel("Наведите мышку на любой переключатель, слайдер, список или кнопку в меню — появится краткая подсказка о том, что делает настройка.", true)

    local hr = Tabs.Help:AddRightGroupbox("Подробный справочник")
    local helpBody = hr:AddLabel(HELP_TOPICS[HELP_ORDER[1]], true)
    hl:AddDropdown("HelpTopic", {
        Text = "Раздел справки",
        Values = HELP_ORDER,
        Default = HELP_ORDER[1],
        Tooltip = "Выберите тему, чтобы прочитать подробное описание всех механик раздела.",
        Callback = function(v)
            local txt = HELP_TOPICS[v]
            if txt and helpBody and helpBody.SetText then
                pcall(function() helpBody:SetText(txt) end)
            end
        end,
    })
end

do
    local DISABLE_SECTIONS = { "Radar", "Crosshair", "Objects", "SelfChams", "ThirdPerson", "ChinaHat", "JumpRings", "FootstepRings", "Proximity", "LookingAlert", "PlayerAura", "ParticleTrail", "Afterimage", "Satellites" }
    local function disableAll()
        local root = cfg()
        local E, H, O, W, V = root.ESP, root.Hitmarker, root.Overlay, root.World, root.Vignette
        E.Enabled, E.Skeleton, E.ShowTracer, E.OffscreenArrows, E.Chams, E.VisibleCheck = false, false, false, false, false, false
        E.PriorityTarget, E.BoxFill, E.HeadDot, E.LookLine, E.DamageNumbers, E.HideDefaultTags, E.ShowState = false, false, false, false, false, false, false
        H.Enabled, H.KillEffect = false, false
        O.Watermark, O.Keybinds, O.TargetHUD, O.Speedometer, O.SpeedLines, O.DragHUD = false, false, false, false, false, false
        W.Preset, W.SkyPreset, W.Weather = "None", "Auto", "None"
        W.TimeEnabled, W.FOVEnabled, W.SpeedFOV, W.NoFog, W.AmbientEnabled, W.Grading, W.BloomEnabled = false, false, false, false, false, false, false
        V.LowHP, V.KillFlash, root.Misc.JoinLeave = false, false, false
        for _, sec in ipairs(DISABLE_SECTIONS) do root[sec].Enabled = false end
        hudState.drag = nil
        destroyDamagePopups()
        Fx.destroySelfChams()
        Fx.clearLocalEffects()
        ThirdPerson.restore()
        WorldMod.restore()
        restoreTags()
        Aware.cleanup()
        syncUI()
        resyncChams()
    end

    CUR_TAB, CUR_GROUP = "Настройки UI", "Управление меню"
    local ui = Tabs.UI:AddLeftGroupbox("Управление меню")
    ui:AddLabel("Клавиша открытия меню"):AddKeyPicker("MenuKey", {
        Default = "RightShift", Mode = "Toggle", NoUI = true, Text = "Клавиша меню",
    })
    regSearch("Клавиша открытия меню", "RightShift — скрыть или открыть окно меню")
    ui:AddButton({
        Text = "Выключить всё",
        Tooltip = "Моментально выключает все активные модули (ВХ, эффекты, радар, HUD и мир) без выгрузки самого хаба.",
        Func = function()
            disableAll()
            pcall(function()
                Library:Notify({ Title = "glupost hub", Description = "Все модули выключены", Time = 3 })
            end)
        end,
    })
    regSearch("Выключить всё", "Отключает все активные модули без выгрузки")
    ui:AddButton({
        Text = "Сбросить автоконфиг (Autoload)",
        Tooltip = "Удаляет файл автозагрузки SaveManager и выключает все модули, чтобы при следующем запуске всё точно стартовало с нуля.",
        Func = function()
            pcall(function()
                if isfile and delfile and isfile("glupost_hub/configs/settings/autoload.txt") then
                    delfile("glupost_hub/configs/settings/autoload.txt")
                end
            end)
            disableAll()
            pcall(function()
                Library:Notify({ Title = "Autoload", Description = "Автозагрузка сброшена, всё выключено", Time = 3 })
            end)
        end,
    })
    regSearch("Сбросить автоконфиг (Autoload)", "Удаляет автозагрузку и сбрасывает модули")
    ui:AddButton({
        Text = "Выгрузить скрипт",
        Tooltip = "Полностью останавливает все циклы, удаляет эффекты, чистит Drawing и возвращает стандартную камеру/освещение.",
        Func = function()
            if getgenv_()._GlupostUnload then getgenv_()._GlupostUnload() end
        end,
    })
    regSearch("Выгрузить скрипт", "Полная остановка и выгрузка хаба")
    if Options.MenuKey then Library.ToggleKeybind = Options.MenuKey end

    CUR_GROUP = "Горячие клавиши"
    local kb = Tabs.UI:AddLeftGroupbox("Горячие клавиши")
    kb:AddLabel("Включить / выкл. ВХ"):AddKeyPicker("KeyESP", { Default = "F1", Mode = "Toggle", NoUI = true, Text = "ВХ (ESP)" })
    kb:AddLabel("Сменить тип рамки"):AddKeyPicker("KeyBox", { Default = "F2", Mode = "Toggle", NoUI = true, Text = "Тип рамки" })
    kb:AddLabel("Включить / выкл. скелет"):AddKeyPicker("KeySkel", { Default = "F3", Mode = "Toggle", NoUI = true, Text = "Скелет" })
    kb:AddLabel("Включить / выкл. радар"):AddKeyPicker("KeyRadar", { Default = "F4", Mode = "Toggle", NoUI = true, Text = "Мини-радар" })
    kb:AddLabel("Включить / выкл. 3-е лицо"):AddKeyPicker("KeyTP", { Default = "F5", Mode = "Toggle", NoUI = true, Text = "3-е лицо" })
    regSearch("Горячие клавиши (F1-F5)", "Бинды ВХ, рамки, скелета, радара и 3-го лица")

    local function applyStylePreset(name, patch)
        local root = cfg()
        for sec, tbl in pairs(patch) do
            if type(tbl) == "table" and type(root[sec]) == "table" then
                for k, v in pairs(tbl) do
                    if type(v) == "table" and type(root[sec][k]) == "table" then
                        for ck, cv in pairs(v) do root[sec][k][ck] = cv end
                    else
                        root[sec][k] = v
                    end
                end
            end
        end
        if not root.SelfChams.Enabled then Fx.destroySelfChams() end
        syncUI()
        applyESPSync()
        resyncChams()
        pcall(function()
            Library:Notify({ Title = "Пресет", Description = "Применён стиль: " .. name, Time = 3 })
        end)
    end

    CUR_GROUP = "Быстрые пресеты стиля"
    local pr = Tabs.UI:AddRightGroupbox("Быстрые пресеты стиля")
    pr:AddButton({
        Text = "Чистый минимум (Minimal)",
        Tooltip = "Аккуратный лёгкий ВХ с уголками, классический прицел, хитмаркер и минимум эффектов для максимального FPS.",
        Func = function()
            applyStylePreset("Clean Minimal", {
                ESP = { Enabled = true, BoxType = "Corner", BoxThickness = 1, BoxFill = true, FillOpacity = 0.06, Chams = false, Skeleton = false, ShowTracer = false, LookLine = false, DamageNumbers = false },
                Radar = { Enabled = false },
                LookingAlert = { Enabled = false },
                FootstepRings = { Enabled = false },
                Proximity = { Enabled = false },
                ThirdPerson = { Enabled = false },
                Overlay = { Watermark = true, Keybinds = true, TargetHUD = true, Speedometer = false, SpeedLines = false, Accent = Color3.fromRGB(100, 185, 255) },
                Crosshair = { Enabled = true, Style = "Classic", Size = 6, Gap = 3, Dot = true, Dynamic = false, Spin = false, Color = Color3.fromRGB(235, 245, 255) },
                Hitmarker = { Enabled = true },
                Vignette = { LowHP = true, KillFlash = true },
                SelfChams = { Enabled = false },
                Afterimage = { Enabled = false },
                Satellites = { Enabled = false },
                ChinaHat = { Enabled = false },
                PlayerAura = { Enabled = false },
                ParticleTrail = { Enabled = false },
                JumpRings = { Enabled = false },
                World = { Preset = "None", SkyPreset = "Auto", Weather = "None", NoFog = false, FOVEnabled = false, SpeedFOV = false, TimeEnabled = false, Grading = false, AmbientEnabled = false, BloomEnabled = false },
            })
        end,
    })
    regSearch("Пресет: Чистый минимум / Киберпанк / Ледяное стекло / Тактический / Токио Неон / Кровавая луна / Сакура", "Готовые стили оформления и пресеты")
    local function worldFromPreset(presetName, extra)
        local w = { Preset = presetName }
        local wp, target = WORLD_PRESETS[presetName], cfg().World
        if wp then
            for k, val in pairs(wp) do
                if target[k] ~= nil then w[k] = val end
            end
        end
        if extra then for k, val in pairs(extra) do w[k] = val end end
        return w
    end

    pr:AddButton({
        Text = "Киберпанк (Edgerunner)",
        Tooltip = "Включает Liquid Glass чамсы на себя, шлейф Sandevistan, кибер-корону, 3D-ауру Orbitals, спидометр и атмосферу Cyberpunk.",
        Func = function()
            applyStylePreset("Cyberpunk Edgerunner", {
                ESP = { Enabled = true, BoxType = "Corner", BoxThickness = 1, BoxFill = true, FillOpacity = 0.08, Chams = true, ChamsTransparency = 0.5 },
                SelfChams = { Enabled = true, Style = "Liquid Glass", FillTransparency = 0.58, OutlineTransparency = 0.2, IncludeTools = true, FillColor = rgb(120, 225, 255), OutlineColor = rgb(220, 140, 255) },
                Afterimage = { Enabled = true, Style = "Sandevistan", FadeMode = "Glitch", Material = "Neon", ConnectArc = true, SolidGlow = true, TriggerMode = "Moving", Interval = 0.04, Lifetime = 0.48, Transparency = 0.36 },
                ParticleTrail = { Enabled = false },
                ChinaHat = { Enabled = true, Shape = "Crown", Style = "Cyber", Size = 1.45, Opacity = 0.65 },
                PlayerAura = { Enabled = true, Shape = "Orbitals", Style = "Cyber", Size = 2.6, Transparency = 0.72, Particles = true, GlowLight = true },
                JumpRings = { Enabled = true, Style = "Cyber", MaxRadius = 5.0, Lifetime = 0.65, Sparks = true },
                Overlay = { Watermark = true, Keybinds = true, TargetHUD = true, Speedometer = true, Accent = rgb(0, 235, 200) },
                Hitmarker = { Enabled = true, KillEffect = true },
                Vignette = { LowHP = true, KillFlash = true, KillColor = rgb(0, 245, 205) },
                World = worldFromPreset("Cyberpunk", { SkyPreset = "Auto", Weather = "CyberDust", WeatherIntensity = 0.65, SpeedFOV = true, SpeedFOVMax = 16 }),
            })
        end,
    })
    pr:AddButton({
        Text = "Ледяное стекло (Liquid Frost)",
        Tooltip = "Холодная зимняя тема: ледяное стекло на персонаже, звёздная спираль шлейфа Frost, аура Helix, снег и Cold Frost.",
        Func = function()
            applyStylePreset("Liquid Frost", {
                ESP = { Enabled = true, BoxType = "Corner", BoxThickness = 1, BoxFill = true, FillOpacity = 0.08, Chams = false },
                SelfChams = { Enabled = true, Style = "Liquid Glass", FillTransparency = 0.55, OutlineTransparency = 0.16, IncludeTools = true, FillColor = rgb(150, 225, 255), OutlineColor = rgb(240, 252, 255) },
                Afterimage = { Enabled = false },
                ParticleTrail = { Enabled = true, Mode = "Helix", Pattern = "Starlight", Style = "Frost", Lifetime = 0.55, Width = 0.16, Speed = 1.15, Sparks = true },
                ChinaHat = { Enabled = true, Shape = "Halo", Style = "Aurora", Size = 1.45, Opacity = 0.65 },
                PlayerAura = { Enabled = true, Shape = "Helix", Style = "Aurora", Size = 2.6, Transparency = 0.72, Particles = true, GlowLight = false },
                JumpRings = { Enabled = true, Style = "Aurora", MaxRadius = 4.8, Lifetime = 0.68, Sparks = true },
                Overlay = { Watermark = true, Keybinds = false, TargetHUD = true, Speedometer = false, Accent = rgb(130, 210, 255) },
                World = worldFromPreset("Cold Frost", { SkyPreset = "Auto", Weather = "Snow", WeatherIntensity = 0.7, SpeedFOV = false }),
            })
        end,
    })
    pr:AddButton({
        Text = "Тактический (Awareness)",
        Tooltip = "Боевой набор для контроля карты: скелет, линии взгляда, радар, тревога взгляда, кольца шагов и звук приближения.",
        Func = function()
            applyStylePreset("Tactical Awareness", {
                ESP = { Enabled = true, BoxType = "Corner", BoxThickness = 1, BoxFill = true, FillOpacity = 0.07, Skeleton = true, LookLine = true, ShowTool = true, DamageNumbers = true },
                Radar = { Enabled = true, Size = 152, Range = 200, ShowLookDir = true },
                LookingAlert = { Enabled = true, MaxDistance = 320, Angle = 14, RequireLoS = true },
                FootstepRings = { Enabled = true, MaxDistance = 120, MaxRadius = 3.4, Lifetime = 0.58 },
                Proximity = { Enabled = true, Distance = 85, SpatialSound = true },
                Crosshair = { Enabled = true, Style = "Classic", Size = 6, Gap = 3, Dot = true, Dynamic = true },
                Hitmarker = { Enabled = true },
                Overlay = { Watermark = true, Keybinds = true, TargetHUD = true, Accent = Color3.fromRGB(100, 185, 255) },
                Vignette = { LowHP = true, KillFlash = true },
            })
        end,
    })
    pr:AddButton({
        Text = "Токио Неон (Anime FX)",
        Tooltip = "3D-кристалл над головой, аура Galaxy, спутники-кристаллы со шлейфами, Speed Lines, лепестки Sakura и Tokyo Neon.",
        Func = function()
            applyStylePreset("Tokyo Neon Anime FX", {
                ESP = { Enabled = true, BoxType = "Corner", BoxThickness = 1, BoxFill = true, FillOpacity = 0.08, ShowState = true, DamageNumbers = true },
                SelfChams = { Enabled = true, Style = "Energy Rim", FillTransparency = 0.55, OutlineTransparency = 0.12, IncludeTools = true, FillColor = rgb(110, 215, 255), OutlineColor = rgb(255, 115, 215) },
                ChinaHat = { Enabled = true, Shape = "Crystal", Style = "Cyber", Size = 1.45, Height = 0.65, Opacity = 0.65 },
                PlayerAura = { Enabled = true, Shape = "Galaxy", Style = "Cyber", Size = 2.7, Transparency = 0.7, Particles = true, GlowLight = true },
                Satellites = { Enabled = true, Count = 3, Shape = "Crystal", Style = "Cyber", Radius = 3.2, Height = 0.8, Speed = 1.5, Size = 0.45, Trails = true },
                JumpRings = { Enabled = true, Style = "Cyber", MaxRadius = 5.0, Lifetime = 0.65, Sparks = true },
                Overlay = { Watermark = true, Keybinds = true, TargetHUD = true, Speedometer = true, SpeedLines = true, SpeedLinesMinSpeed = 20, SpeedLinesOpacity = 0.65, SpeedLinesColor = rgb(0, 235, 255), Accent = rgb(0, 225, 255) },
                World = worldFromPreset("Tokyo Neon", { SkyPreset = "Auto", Weather = "Sakura", WeatherIntensity = 0.75, SpeedFOV = true, SpeedFOVMax = 15 }),
            })
        end,
    })
    pr:AddButton({
        Text = "Кровавая луна (Crimson)",
        Tooltip = "Агрессивная алая тема: Energy Rim на скине, огненный Sandevistan, аура Sigil, BloodRain, хитмаркер Diamond и Crimson Void.",
        Func = function()
            applyStylePreset("Crimson Moon", {
                ESP = { Enabled = true, BoxType = "Bracket", BoxThickness = 1, BoxFill = true, FillOpacity = 0.07, DamageNumbers = true },
                SelfChams = { Enabled = true, Style = "Energy Rim", FillTransparency = 0.6, OutlineTransparency = 0.1, IncludeTools = true, FillColor = rgb(255, 65, 85), OutlineColor = rgb(255, 110, 125) },
                Afterimage = { Enabled = true, Style = "Inferno", FadeMode = "Ascend", Material = "Neon", ConnectArc = true, SolidGlow = true, TriggerMode = "Moving", Interval = 0.04, Lifetime = 0.48, Transparency = 0.38 },
                ParticleTrail = { Enabled = false },
                ChinaHat = { Enabled = true, Shape = "Crown", Style = "Flame", Size = 1.45, Opacity = 0.65 },
                PlayerAura = { Enabled = true, Shape = "Sigil", Style = "Flame", Size = 2.8, Transparency = 0.72, Particles = true, GlowLight = true },
                Satellites = { Enabled = true, Count = 3, Shape = "Blade", Style = "Flame", Radius = 3.2, Height = 0.7, Speed = 1.8, Size = 0.45, Trails = true },
                JumpRings = { Enabled = true, Style = "Flame", MaxRadius = 5.2, Lifetime = 0.65, Sparks = true },
                Crosshair = { Enabled = true, Style = "X-Cross", Size = 6, Gap = 4, Dot = true, Color = rgb(255, 90, 110) },
                Hitmarker = { Enabled = true, Style = "Diamond", KillEffect = true, Color = rgb(255, 110, 125), KillColor = rgb(255, 45, 70) },
                Overlay = { Watermark = true, Keybinds = true, TargetHUD = true, Speedometer = true, Accent = rgb(255, 65, 88) },
                Vignette = { LowHP = true, KillFlash = true, KillColor = rgb(255, 55, 80) },
                World = worldFromPreset("Crimson Void", { SkyPreset = "Auto", Weather = "BloodRain", WeatherIntensity = 0.65, SpeedFOV = true, SpeedFOVMax = 15 }),
            })
        end,
    })
    pr:AddButton({
        Text = "Сакура Закат (Sakura)",
        Tooltip = "Аниме-эстетика: гекса-обруч CyberRing, атомная аура Atom, осколки Shard, ленты Spiral Halo, Starfall и Sakura Dusk.",
        Func = function()
            applyStylePreset("Sakura Dusk", {
                ESP = { Enabled = true, BoxType = "Corner", BoxThickness = 1, BoxFill = true, FillOpacity = 0.08, ShowState = true },
                SelfChams = { Enabled = true, Style = "Sakura", FillTransparency = 0.56, OutlineTransparency = 0.16, IncludeTools = true, FillColor = rgb(255, 175, 215), OutlineColor = rgb(255, 240, 248) },
                Afterimage = { Enabled = false },
                ParticleTrail = { Enabled = true, Mode = "Spiral Halo", Pattern = "Starlight", Style = "Sakura", Lifetime = 0.58, Width = 0.16, Speed = 1.1, Sparks = true },
                ChinaHat = { Enabled = true, Shape = "CyberRing", Style = "Sakura", Size = 1.45, Height = 0.55, Opacity = 0.65 },
                PlayerAura = { Enabled = true, Shape = "Atom", Style = "Sakura", Size = 2.7, Transparency = 0.72, Particles = true, GlowLight = true },
                Satellites = { Enabled = true, Count = 3, Shape = "Shard", Style = "Sakura", Radius = 3.2, Height = 0.8, Speed = 1.4, Size = 0.45, Trails = true },
                JumpRings = { Enabled = true, Style = "Sakura", MaxRadius = 5.0, Lifetime = 0.68, Sparks = true },
                Overlay = { Watermark = true, Keybinds = true, TargetHUD = true, Speedometer = true, SpeedLines = true, SpeedLinesMinSpeed = 22, SpeedLinesOpacity = 0.6, SpeedLinesColor = rgb(255, 170, 215), Accent = rgb(255, 130, 195) },
                World = worldFromPreset("Sakura Dusk", { SkyPreset = "Auto", Weather = "Sakura", WeatherIntensity = 0.78, SpeedFOV = true, SpeedFOVMax = 14 }),
            })
        end,
    })

    CUR_GROUP = "Кастомный фон UI"
    local bg = Tabs.UI:AddRightGroupbox("Кастомный фон UI")
    addToggle(bg, "UiBgOn", "Включить фон UI", { "UI", "BgEnabled" },
        "Ставит картинку по Roblox ID или ссылке из браузера на фон окна меню и делает панели полупрозрачными.",
        function(v)
            if v and not isSyncingUI then UiBg.clearFailures() end
            UiBg.apply()
        end)
    withDep(bg, "UiBgOn", true, function(d)
        addInput(d, "UiBgId", "ID или URL картинки", { "UI", "BgId" }, "ID, rbxassetid://... или https://...",
            "Вставьте цифры Roblox ID, rbxassetid://... или прямую ссылку из браузера на PNG/JPG/WEBP (нажмите Enter).",
            function(v)
                if not isSyncingUI then UiBg.clearFailures() end
                local norm = UiBg.normalizeId(v)
                if norm and norm ~= v then
                    cfg().UI.BgId = norm
                    safeSet("UiBgId", norm)
                end
                UiBg.apply()
            end)
        addSlider(d, "UiBgOpacity", "Яркость картинки", { "UI", "BgOpacity" }, 0.05, 1.0, 2,
            "Насколько ярко картинка видна на фоне окна меню.",
            function() UiBg.apply() end)
        addSlider(d, "UiBgPanelOp", "Плотность панелей", { "UI", "BgPanelOpacity" }, 0.15, 0.95, 2,
            "Прозрачность внутренних секций и карточек: чем ниже, тем лучше видно фон за текстом.",
            function() UiBg.apply() end)
        addDropdown(d, "UiBgScale", "Масштаб (ScaleType)", { "UI", "BgScale" }, { "Crop", "Stretch", "Fit", "Tile" },
            "Crop — заполняет без искажения; Stretch — растягивает; Fit — целиком в окне; Tile — плиткой.",
            function() UiBg.apply() end)
        addColorPicker(d, "UiBgTint", "Оттенок фона", { "UI", "BgTint" }, function() UiBg.apply() end)
        d:AddButton({
            Text = "Сбросить фон",
            Tooltip = "Выключает и очищает кастомную картинку фона.",
            Func = function()
                cfg().UI.BgEnabled = false
                cfg().UI.BgId = ""
                UiBg.clearFailures()
                safeSet("UiBgOn", false)
                safeSet("UiBgId", "")
                UiBg.apply()
            end,
        })
    end)
end

if ThemeManager then pcall(function()
    ThemeManager:SetLibrary(Library) ThemeManager:SetFolder("glupost_hub") ThemeManager:ApplyToTab(Tabs.UI)
end) end
if SaveManager then pcall(function()
    SaveManager:SetLibrary(Library) SaveManager:SetFolder("glupost_hub/configs")
    SaveManager:IgnoreThemeSettings() SaveManager:SetIgnoreIndexes({ "MenuKey", "HelpTopic", "HelpSearch" })
    SaveManager:BuildConfigSection(Tabs.UI) SaveManager:LoadAutoloadConfig()
end) end
end

local function cleanup()
    if cleaned then return end
    cleaned, isUnloaded = true, true

    for _, c in pairs(connections) do for _, conn in pairs(c) do safeDestroy(conn) end end
    table.clear(connections)

    for _, d in pairs(playersData) do destroyAll(d) end
    table.clear(playersData)
    table.clear(renderData)
    table.clear(chamsCandidates)
    table.clear(chamsAllowed)

    destroyObjects()
    destroyDamagePopups()
    restoreTags()
    getgenv_().GlupostObjects = nil

    Fx.destroySelfChams()
    Fx.clearLocalEffects()

    for _, p in pairs(POOLS) do
        for _, o in ipairs(p.free) do safeDestroy(o) end
        table.clear(p.free)
    end

    for _, o in pairs(overlayObjs) do safeDestroy(o) end
    table.clear(overlayObjs)

    Aware.cleanup()
    ThirdPerson.restore()
    WorldMod.restore()
    if UiBg and UiBg.destroy then UiBg.destroy() end

    for _, c in ipairs({ renderConn, inputBeginConn, inputChangedConn, inputEndedConn, playerAddedConn, playerRemovingConn }) do
        safeDestroy(c)
    end

    getgenv_()._GlupostHubActive = false
end

getgenv_()._GlupostUnload = function()
    cleanup()
    pcall(function() Library:Unload() end)
    getgenv_()._GlupostUnload = nil
end
Library:OnUnload(cleanup)

local function notify(title, text)
    pcall(function() Library:Notify({ Title = title, Description = text, Time = 3 }) end)
end

for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end

playerAddedConn = Players.PlayerAdded:Connect(function(plr)
    setupPlayer(plr)
    if cfg().Misc.JoinLeave then notify("Зашёл", plr.DisplayName .. " (@" .. plr.Name .. ")") end
end)

playerRemovingConn = Players.PlayerRemoving:Connect(function(plr)
    if cfg().Misc.JoinLeave then notify("Вышел", plr.DisplayName .. " (@" .. plr.Name .. ")") end
    if connections[plr] then for _, c in pairs(connections[plr]) do safeDestroy(c) end connections[plr] = nil end
    if playersData[plr] then destroyAll(playersData[plr]) playersData[plr] = nil end
    renderData[plr] = nil
end)

local function matchesBind(input, optIdx, fallback)
    local o = Library and Library.Options and Library.Options[optIdx]
    local key = o and o.Value
    if key == "None" then return false end
    if type(key) ~= "string" or key == "" then key = fallback end
    if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name == key then return true end
    if (key == "MB1" or key == "MouseButton1") and input.UserInputType == Enum.UserInputType.MouseButton1 then return true end
    if (key == "MB2" or key == "MouseButton2") and input.UserInputType == Enum.UserInputType.MouseButton2 then return true end
    if (key == "MB3" or key == "MouseButton3") and input.UserInputType == Enum.UserInputType.MouseButton3 then return true end
    return false
end

inputBeginConn = UIS.InputBegan:Connect(function(input, gp)
    if gp or isUnloaded then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and cfg().Overlay.DragHUD then
        local mp = UIS:GetMouseLocation()
        for _, id in ipairs({ "th", "radar", "kb" }) do
            local r = hudState.rects[id]
            if r and mp.X >= r.x and mp.X <= r.x + r.w and mp.Y >= r.y and mp.Y <= r.y + r.h then
                hudState.drag = id
                hudState.offX = mp.X - r.x
                hudState.offY = mp.Y - r.y
                return
            end
        end
    end
    if matchesBind(input, "KeyESP", "F1") then
        cfg().ESP.Enabled = not cfg().ESP.Enabled safeSet("EspOn", cfg().ESP.Enabled)
    elseif matchesBind(input, "KeyBox", "F2") then
        local t = { "2D", "Corner", "Bracket", "3D" }
        local i = (table.find(t, cfg().ESP.BoxType) or 1) % 4 + 1
        cfg().ESP.BoxType = t[i] safeSet("BoxType", t[i])
    elseif matchesBind(input, "KeySkel", "F3") then
        cfg().ESP.Skeleton = not cfg().ESP.Skeleton safeSet("ShowSk", cfg().ESP.Skeleton)
    elseif matchesBind(input, "KeyRadar", "F4") then
        cfg().Radar.Enabled = not cfg().Radar.Enabled safeSet("RadarOn", cfg().Radar.Enabled)
    elseif matchesBind(input, "KeyTP", "F5") then
        cfg().ThirdPerson.Enabled = not cfg().ThirdPerson.Enabled safeSet("TpOn", cfg().ThirdPerson.Enabled)
    end
end)

inputChangedConn = UIS.InputChanged:Connect(function(input, gp)
    if isUnloaded then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement and hudState.drag and cfg().Overlay.DragHUD then
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or v2(1920, 1080)
        local mp = UIS:GetMouseLocation()
        local nx, ny = mp.X - hudState.offX, mp.Y - hudState.offY
        if hudState.drag == "radar" then
            local half = (cfg().Radar.Size or 148) * 0.5
            cfg().Radar.PosX = clamp(nx + half, half + 6, vp.X - half - 6)
            cfg().Radar.PosY = clamp(ny + half, half + 6, vp.Y - half - 6)
        elseif hudState.drag == "th" then
            cfg().Overlay.TargetHUDX = clamp(nx, 6, max(6, vp.X - 242))
            cfg().Overlay.TargetHUDY = clamp(ny, 6, max(6, vp.Y - 82))
        elseif hudState.drag == "kb" then
            local r = hudState.rects.kb
            local kh = r and r.h or 60
            cfg().Overlay.KeybindsX = clamp(nx, 6, max(6, vp.X - 192))
            cfg().Overlay.KeybindsY = clamp(ny, 6, max(6, vp.Y - kh - 6))
        end
        return
    end
    if not gp and input.UserInputType == Enum.UserInputType.MouseWheel then
        local T = cfg().ThirdPerson
        if T.Enabled and T.ScrollZoom then
            local delta = input.Position.Z > 0 and -2 or 2
            T.Distance = clamp((T.Distance or 9) + delta, 2, 26)
            safeSet("TpDist", T.Distance)
        end
    end
end)

inputEndedConn = UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        hudState.drag = nil
    end
end)

local run
do
    local errCount = 0
    run = function(name, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok and errCount < 8 then
            errCount += 1
            warn("[glupost] " .. name .. ": " .. tostring(err))
        end
    end
end

renderConn = RunService.RenderStepped:Connect(function(dt)
    if isUnloaded then return end

    local cam = workspace.CurrentCamera
    if not cam then return end
    cameraCF, cameraPos = cam.CFrame, cam.CFrame.Position

    updateRainbow()
    trackFPS(dt)

    run("world", WorldMod.update, dt)
    run("third person", ThirdPerson.update)
    run("self chams", Fx.updateSelfChams)
    run("local effects", Fx.updateLocalEffects, dt)
    run("proximity alert", Aware.updateProximityAlert)
    run("keybinds hud", HUD.updateKeybindsHUD)
    run("radar", updateRadarFrame)
    run("esp", updateESP, dt)
    run("looking alert", Aware.updateLookingAlert)
    run("footstep rings", Aware.updateFootstepRings)
    run("objects", updateObjects)
    run("tags", updateDefaultTags)
    run("vignette", HUD.updateVignette, dt)
    run("speed lines", HUD.updateSpeedLines, dt)
    run("crosshair", HUD.updateCrosshair, dt)
    run("hitmarker", HUD.updateHitmarker)
    run("speedometer", HUD.updateSpeedometer)
    run("target hud", HUD.updateTargetHUD, dt)
    run("watermark", HUD.updateWatermark)
end)

syncUI()
applyESPSync()
local autoNotice = ""
pcall(function()
    if isfile and readfile and isfile("glupost_hub/configs/settings/autoload.txt") then
        local n = readfile("glupost_hub/configs/settings/autoload.txt"):match("^%s*(.-)%s*$")
        if n and n ~= "" and n ~= "none" then
            autoNotice = " (автоконфиг: " .. n .. ")"
        end
    end
end)
Library:Notify({ Title = "glupost hub", Description = VERSION .. " загружен" .. autoNotice, Time = 4 })
print("[glupost hub] " .. VERSION .. " загружен" .. autoNotice)
