--[[
    ╔═══════════════════════════════════════════╗
    ║          SYN-STUDIO v3.0 STEALTH          ║
    ║      Anti-Detect | Responsive UI          ║
    ╚═══════════════════════════════════════════╝
]]

-- ============================================================
-- ANTI-DETECTION: Randomize semua nama instance
-- ============================================================
local function rng_str(len)
    local c = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local s = ""
    for i = 1, (len or 12) do
        local r = math.random(1, #c)
        s = s .. c:sub(r, r)
    end
    return s
end

local SCRIPT_ID = rng_str(16)
local GUI_NAME = rng_str(20)
local FRAME_PREFIX = rng_str(8)

-- ============================================================
-- SERVICES (cached & obfuscated references)
-- ============================================================
local plrs = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local ws = game:GetService("Workspace")
local repstor = game:GetService("ReplicatedStorage")
local sg = game:GetService("StarterGui")
local cg = game:GetService("CoreGui")

local lp = plrs.LocalPlayer
local cam = ws.CurrentCamera

-- ============================================================
-- ANTI-DETECT: Wrap functions to avoid detection
-- ============================================================
local _wait = task.wait
local _spawn = task.spawn
local _defer = task.defer
local _delay = task.delay
local _tick = tick
local _pairs = pairs
local _ipairs = ipairs
local _type = type
local _typeof = typeof
local _pcall = pcall
local _tostring = tostring
local _tonumber = tonumber
local _math = math
local _table = table
local _string = string
local _coroutine = coroutine

-- Anti hookcheck / integrity
local function safe_call(fn, ...)
    local ok, result = _pcall(fn, ...)
    if ok then return result end
    return nil
end

-- ============================================================
-- STEALTH NOTIFICATION (tidak pakai SendNotification standar)
-- ============================================================
local function stealth_notify(title, text, dur)
    _pcall(function()
        sg:SetCore("SendNotification", {
            Title = title or "",
            Text = text or "",
            Duration = dur or 3,
        })
    end)
end

-- ============================================================
-- CONFIGURATION
-- ============================================================
local CFG = {
    Rarities = {
        Ethernal = true,
        Devine = true,
        Cosmic = true,
        Secret = true,
        Legend = true,
        Mistic = true,
        Rare = true,
        Epic = true,
        Uncommon = false,
        Common = false,
    },
    RarityWeight = {
        Ethernal = 1, Devine = 2, Cosmic = 3, Secret = 4,
        Legend = 5, Mistic = 6, Rare = 7, Epic = 8,
        Uncommon = 9, Common = 10,
    },
    RarityCol = {
        Ethernal = Color3.fromRGB(255, 0, 255),
        Devine = Color3.fromRGB(255, 215, 0),
        Cosmic = Color3.fromRGB(0, 255, 255),
        Secret = Color3.fromRGB(255, 30, 30),
        Legend = Color3.fromRGB(255, 165, 0),
        Mistic = Color3.fromRGB(148, 0, 211),
        Rare = Color3.fromRGB(0, 120, 255),
        Epic = Color3.fromRGB(163, 53, 238),
        Uncommon = Color3.fromRGB(0, 230, 0),
        Common = Color3.fromRGB(190, 190, 190),
    },

    DashSpeed = 200,
    EscapeSpeed = 280,
    NormalSpeed = 16,
    StepSize = 2.5,

    BigEggKG = 1000,
    BigEggOn = true,

    ScanRange = 5000,
    GrabRange = 12,
    SafeRange = 18,
    GrabDelay = 0.03,
    ScanTick = 0.15,

    SafePos = nil,

    On = false,
    InstSteal = true,
    AutoRun = true,
    AntiDrop = true,
    ShowESP = true,

    -- ANTI DETECT
    StealthMove = true,       -- Gunakan movement yang tidak terdeteksi
    HumanizeDelay = true,     -- Tambahkan delay kecil random agar terlihat natural
    SpoofSpeed = true,        -- Spoof walkspeed agar server tidak detect
    MaxSpeedServer = 50,      -- Speed yang dikirim ke server (batas aman)
}

-- ============================================================
-- STATE
-- ============================================================
local ST = {
    Grab = false,
    Esc = false,
    Carry = false,
    Target = nil,
    TRarity = nil,
    TWeight = 0,
    HasEgg = false,
    Done = false,
    Conns = {},
    Esps = {},
    Tw = nil,
}

-- ============================================================
-- UTILITY
-- ============================================================
local U = {}

function U.char()
    return lp.Character or lp.CharacterAdded:Wait()
end

function U.hum()
    local c = U.char()
    return c and c:FindFirstChildOfClass("Humanoid")
end

function U.root()
    local c = U.char()
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

function U.pos()
    local r = U.root()
    return r and r.Position or Vector3.new(0, 0, 0)
end

function U.dist(p)
    return (U.pos() - p).Magnitude
end

function U.alive()
    local h = U.hum()
    return h and h.Health > 0
end

function U.add_conn(c)
    _table.insert(ST.Conns, c)
end

function U.clear_conns()
    for _, c in _ipairs(ST.Conns) do
        if c and _typeof(c) == "RBXScriptConnection" then
            _pcall(function() c:Disconnect() end)
        end
    end
    ST.Conns = {}
end

function U.viewport()
    local vp = cam.ViewportSize
    return vp.X, vp.Y
end

-- ============================================================
-- ANTI-DETECT MOVEMENT SYSTEM
-- Menggunakan CFrame manipulation dengan interpolasi halus
-- Tidak mengubah WalkSpeed secara drastis
-- Menggunakan bodymovers sebagai alternatif
-- ============================================================
local MoveEngine = {}

function MoveEngine:create_mover(root)
    -- Gunakan BodyVelocity untuk movement yang lebih natural
    -- Server lebih sulit detect dibanding CFrame snap
    local existing = root:FindFirstChild("_bv_" .. SCRIPT_ID)
    if existing then existing:Destroy() end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "_bv_" .. SCRIPT_ID
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.P = 1e4
    bv.Parent = root
    return bv
end

function MoveEngine:remove_mover(root)
    local bv = root:FindFirstChild("_bv_" .. SCRIPT_ID)
    if bv then bv:Destroy() end
end

function MoveEngine:dash_to(target_pos, speed, on_arrive)
    local root = U.root()
    local hum = U.hum()
    if not root or not hum then return end

    -- Method hybrid: BodyVelocity + CFrame nudge
    -- Ini lebih sulit dideteksi daripada CFrame teleport murni

    local bv = self:create_mover(root)

    local conn
    conn = rs.Heartbeat:Connect(function(dt)
        if not CFG.On or not U.alive() then
            bv.Velocity = Vector3.new(0, 0, 0)
            self:remove_mover(root)
            if conn then conn:Disconnect() end
            return
        end

        local cur = root.Position
        local dir = (target_pos - cur)
        local dist = dir.Magnitude

        if dist <= CFG.GrabRange then
            bv.Velocity = Vector3.new(0, 0, 0)
            self:remove_mover(root)
            if conn then conn:Disconnect() end
            if on_arrive then on_arrive() end
            return
        end

        local unit = dir.Unit
        local actual_speed = speed or CFG.DashSpeed

        -- ANTI-DETECT: Jangan set velocity terlalu tinggi sekaligus
        -- Ramp up secara gradual
        if CFG.StealthMove then
            local cur_vel = bv.Velocity.Magnitude
            local target_vel = _math.min(actual_speed, dist * 2)
            local lerped = cur_vel + (target_vel - cur_vel) * _math.min(dt * 5, 1)
            bv.Velocity = unit * lerped
        else
            bv.Velocity = unit * actual_speed
        end

        -- Hadap ke arah gerak
        _pcall(function()
            root.CFrame = CFrame.new(root.Position, root.Position + unit)
        end)

        -- ANTI-DETECT: Humanize - tambah sedikit variasi
        if CFG.HumanizeDelay then
            if _math.random() < 0.02 then -- 2% chance per frame
                bv.Velocity = bv.Velocity * (0.85 + _math.random() * 0.3)
            end
        end

        -- ANTI-DETECT: Jaga WalkSpeed tetap normal di mata server
        if CFG.SpoofSpeed then
            hum.WalkSpeed = CFG.MaxSpeedServer
        end
    end)

    U.add_conn(conn)
    return conn
end

function MoveEngine:escape_to(target_pos, speed, on_arrive)
    return self:dash_to(target_pos, speed or CFG.EscapeSpeed, on_arrive)
end

function MoveEngine:stop()
    local root = U.root()
    if root then
        self:remove_mover(root)
    end
    local hum = U.hum()
    if hum then
        hum.WalkSpeed = CFG.NormalSpeed
    end
end

-- ============================================================
-- SAFE ZONE FINDER
-- ============================================================
local SZ = {}

function SZ.find()
    local names = {
        "SafeZone", "Safe Zone", "SafeArea", "Safe_Zone",
        "Safezone", "Base", "Spawn", "SpawnArea", "Home",
        "HomeBase", "safe_zone", "safezone", "Lobby",
        "Hub", "StartArea", "NestBase", "PlayerBase",
        "BaseZone", "SafeRegion", "StartZone", "Camp"
    }

    for _, n in _ipairs(names) do
        local f = ws:FindFirstChild(n, true)
        if f then
            if f:IsA("BasePart") then
                CFG.SafePos = f.Position
                return f.Position
            elseif f:IsA("Model") then
                local p = f.PrimaryPart or f:FindFirstChildWhichIsA("BasePart")
                if p then
                    CFG.SafePos = p.Position
                    return p.Position
                end
            end
        end
    end

    for _, obj in _ipairs(ws:GetDescendants()) do
        if obj:IsA("BasePart") then
            local nl = obj.Name:lower()
            if nl:find("safe") or nl:find("spawn") or nl:find("base") or nl:find("camp") then
                CFG.SafePos = obj.Position
                return obj.Position
            end
        end
    end

    local sp = ws:FindFirstChildOfClass("SpawnLocation")
    if sp then
        CFG.SafePos = sp.Position
        return sp.Position
    end

    CFG.SafePos = U.pos()
    return CFG.SafePos
end

function SZ.get()
    if not CFG.SafePos then SZ.find() end
    return CFG.SafePos
end

function SZ.inside()
    local p = SZ.get()
    return p and U.dist(p) <= CFG.SafeRange
end

-- ============================================================
-- EGG SCANNER
-- ============================================================
local Scanner = {}

local RARITY_LIST = {
    "Ethernal", "Devine", "Cosmic", "Secret",
    "Legend", "Mistic", "Rare", "Epic",
    "Uncommon", "Common"
}

function Scanner.get_rarity(obj)
    local nm = obj.Name:lower()
    for _, r in _ipairs(RARITY_LIST) do
        if nm:find(r:lower()) then return r end
    end

    local attr = obj:GetAttribute("Rarity")
    if attr then
        local a = _tostring(attr):lower()
        for _, r in _ipairs(RARITY_LIST) do
            if a:find(r:lower()) then return r end
        end
    end

    for _, ch in _ipairs(obj:GetChildren()) do
        if ch:IsA("StringValue") and (ch.Name == "Rarity" or ch.Name == "Type" or ch.Name == "Tier" or ch.Name == "Grade") then
            local v = ch.Value:lower()
            for _, r in _ipairs(RARITY_LIST) do
                if v:find(r:lower()) then return r end
            end
        end
    end

    for _, d in _ipairs(obj:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = d.Text:lower()
            for _, r in _ipairs(RARITY_LIST) do
                if t:find(r:lower()) then return r end
            end
        end
    end

    if obj.Parent then
        local pn = obj.Parent.Name:lower()
        for _, r in _ipairs(RARITY_LIST) do
            if pn:find(r:lower()) then return r end
        end
    end

    return nil
end

function Scanner.get_weight(obj)
    local w = 0

    for _, aname in _ipairs({"Weight", "Kilogram", "Mass", "KG", "Kg", "weight", "kg"}) do
        local a = obj:GetAttribute(aname)
        if a then
            w = _tonumber(a) or 0
            if w > 0 then return w end
        end
    end

    for _, ch in _ipairs(obj:GetChildren()) do
        if ch:IsA("NumberValue") or ch:IsA("IntValue") then
            local cnl = ch.Name:lower()
            if cnl:find("weight") or cnl:find("kg") or cnl:find("mass") or cnl:find("kilogram") then
                return ch.Value
            end
        end
        if ch:IsA("StringValue") then
            local cnl = ch.Name:lower()
            if cnl:find("weight") or cnl:find("kg") or cnl:find("mass") then
                local v = _tonumber(ch.Value)
                if v then return v end
            end
        end
    end

    local nw = obj.Name:match("(%d+)%s*[kK][gG]")
    if nw then return _tonumber(nw) or 0 end

    for _, d in _ipairs(obj:GetDescendants()) do
        if d:IsA("TextLabel") then
            local tw = d.Text:match("(%d+)%s*[kK][gG]")
            if tw then return _tonumber(tw) or 0 end
        end
    end

    return 0
end

function Scanner.is_egg(obj)
    local nl = obj.Name:lower()
    local kw = {"egg", "telur", "nest", "hatch", "ovum", "sarang"}
    for _, k in _ipairs(kw) do
        if nl:find(k) then return true end
    end
    if obj:GetAttribute("IsEgg") or obj:GetAttribute("Egg") or obj:GetAttribute("EggType") then
        return true
    end
    for _, ch in _ipairs(obj:GetChildren()) do
        if ch.Name:lower():find("egg") then return true end
    end
    return false
end

function Scanner.get_pos(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if p then return p.Position end
    end
    return nil
end

function Scanner.scan()
    local eggs = {}
    for _, obj in _ipairs(ws:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and Scanner.is_egg(obj) then
            local rar = Scanner.get_rarity(obj)
            local wt = Scanner.get_weight(obj)
            local pos = Scanner.get_pos(obj)
            if pos and rar and CFG.Rarities[rar] then
                _table.insert(eggs, {
                    Obj = obj,
                    Rar = rar,
                    Wt = wt,
                    Pos = pos,
                    Pri = CFG.RarityWeight[rar] or 99,
                    Big = wt >= CFG.BigEggKG,
                    Dist = U.dist(pos),
                })
            end
        end
    end
    return eggs
end

function Scanner.best(eggs)
    if #eggs == 0 then return nil end
    _table.sort(eggs, function(a, b)
        if CFG.BigEggOn then
            if a.Big and not b.Big then return true end
            if not a.Big and b.Big then return false end
            if a.Big and b.Big then
                if a.Wt ~= b.Wt then return a.Wt > b.Wt end
            end
        end
        if a.Pri ~= b.Pri then return a.Pri < b.Pri end
        return a.Dist < b.Dist
    end)
    return eggs[1]
end

-- ============================================================
-- INSTANT STEAL (ANTI-DETECT PICKUP)
-- ============================================================
local Steal = {}

function Steal.find_prompt(obj)
    if not obj then return nil end
    local p = obj:FindFirstChildOfClass("ProximityPrompt")
    if p then return p end
    for _, d in _ipairs(obj:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
    if obj.Parent then
        p = obj.Parent:FindFirstChildOfClass("ProximityPrompt")
        if p then return p end
        for _, d in _ipairs(obj.Parent:GetDescendants()) do
            if d:IsA("ProximityPrompt") then return d end
        end
    end
    return nil
end

function Steal.find_click(obj)
    if obj:IsA("BasePart") then
        local cd = obj:FindFirstChildOfClass("ClickDetector")
        if cd then return cd end
    end
    for _, d in _ipairs(obj:GetDescendants()) do
        if d:IsA("ClickDetector") then return d end
    end
    if obj.Parent then
        for _, d in _ipairs(obj.Parent:GetDescendants()) do
            if d:IsA("ClickDetector") then return d end
        end
    end
    return nil
end

function Steal.find_btn()
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local kw = {
        "pickup", "pick up", "grab", "take", "ambil",
        "angkat", "lift", "collect", "steal", "carry",
        "hold", "interact", "claim", "snatch", "press"
    }
    for _, g in _ipairs(pg:GetDescendants()) do
        if g:IsA("TextButton") or g:IsA("ImageButton") then
            local nl = g.Name:lower()
            local tl = ""
            if g:IsA("TextButton") then tl = g.Text:lower() end
            for _, k in _ipairs(kw) do
                if nl:find(k) or tl:find(k) then
                    if g.Visible and g.AbsoluteSize.X > 0 then
                        return g
                    end
                end
            end
        end
    end
    return nil
end

function Steal.try_pickup(egg)
    -- Method 1: ProximityPrompt (paling umum)
    local prompt = Steal.find_prompt(egg)
    if prompt then
        local hd = prompt.HoldDuration
        local md = prompt.MaxActivationDistance
        local re = prompt.RequiresLineOfSight

        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 9999
        prompt.RequiresLineOfSight = false
        prompt.Enabled = true

        if _typeof(fireproximityprompt) == "function" then
            fireproximityprompt(prompt, 1)
        elseif _typeof(fireproximityprompt) == "nil" then
            -- Fallback: simulate
            prompt:InputHoldBegin()
            _wait(0.05)
            prompt:InputHoldEnd()
        end

        _delay(0.5, function()
            _pcall(function()
                prompt.HoldDuration = hd
                prompt.MaxActivationDistance = md
                prompt.RequiresLineOfSight = re
            end)
        end)
        return true
    end

    -- Method 2: ClickDetector
    local cd = Steal.find_click(egg)
    if cd then
        if _typeof(fireclickdetector) == "function" then
            fireclickdetector(cd)
        end
        return true
    end

    -- Method 3: GUI Button
    local btn = Steal.find_btn()
    if btn then
        _pcall(function()
            if _typeof(firesignal) == "function" then
                firesignal(btn.Activated)
                firesignal(btn.MouseButton1Click)
            else
                -- Simulate natural click
                local vim = game:GetService("VirtualInputManager")
                local ap = btn.AbsolutePosition
                local as = btn.AbsoluteSize
                local cx, cy = ap.X + as.X / 2, ap.Y + as.Y / 2
                vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                _wait(0.02)
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end
        end)
        return true
    end

    -- Method 4: Touch simulation
    _pcall(function()
        local root = U.root()
        if not root then return end
        local part = egg
        if egg:IsA("Model") then
            part = egg:FindFirstChildWhichIsA("BasePart")
        end
        if part and part:IsA("BasePart") and _typeof(firetouchinterest) == "function" then
            firetouchinterest(root, part, 0)
            _wait(0.03)
            firetouchinterest(root, part, 1)
        end
    end)

    -- Method 5: Remote search
    _pcall(function()
        for _, rem in _ipairs(repstor:GetDescendants()) do
            if rem:IsA("RemoteEvent") then
                local rnl = rem.Name:lower()
                if rnl:find("pick") or rnl:find("grab") or rnl:find("steal") or
                   rnl:find("collect") or rnl:find("take") or rnl:find("interact") or
                   rnl:find("claim") then
                    rem:FireServer(egg)
                    rem:FireServer(egg, "pickup")
                    rem:FireServer("pickup", egg)
                end
            end
        end
    end)

    return false
end

-- ============================================================
-- ESP SYSTEM (lightweight)
-- ============================================================
local Esp = {}

function Esp.create(egg, rar, wt)
    if not CFG.ShowESP then return end
    local pos = Scanner.get_pos(egg)
    if not pos then return end

    Esp.remove(egg)

    local col = CFG.RarityCol[rar] or Color3.fromRGB(255, 255, 255)
    local big = wt >= CFG.BigEggKG

    local bb = Instance.new("BillboardGui")
    bb.Name = rng_str(10)
    bb.Size = UDim2.new(0, 180, 0, 65)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 2000
    bb.LightInfluence = 0

    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(1, 0, 1, 0)
    fr.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    fr.BackgroundTransparency = 0.25
    fr.BorderSizePixel = 0
    fr.Parent = bb

    Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)

    local stk = Instance.new("UIStroke")
    stk.Color = col
    stk.Thickness = big and 3 or 1.5
    stk.Transparency = 0.1
    stk.Parent = fr

    -- Glow effect for big eggs
    if big then
        local glow = Instance.new("UIStroke")
        glow.Color = Color3.fromRGB(255, 255, 0)
        glow.Thickness = 5
        glow.Transparency = 0.7
        glow.Parent = fr
    end

    local rl = Instance.new("TextLabel")
    rl.Size = UDim2.new(1, 0, 0.45, 0)
    rl.BackgroundTransparency = 1
    rl.Text = (big and "🔥 " or "⭐ ") .. rar:upper()
    rl.TextColor3 = col
    rl.TextScaled = true
    rl.Font = Enum.Font.GothamBold
    rl.Parent = fr

    local wl = Instance.new("TextLabel")
    wl.Size = UDim2.new(1, 0, 0.25, 0)
    wl.Position = UDim2.new(0, 0, 0.45, 0)
    wl.BackgroundTransparency = 1
    wl.Text = wt > 0 and ("⚖️ " .. wt .. "kg" .. (big and " 🔥BIG" or "")) or ""
    wl.TextColor3 = Color3.fromRGB(200, 200, 200)
    wl.TextScaled = true
    wl.Font = Enum.Font.Gotham
    wl.Parent = fr

    local dl = Instance.new("TextLabel")
    dl.Name = "DL"
    dl.Size = UDim2.new(1, 0, 0.3, 0)
    dl.Position = UDim2.new(0, 0, 0.7, 0)
    dl.BackgroundTransparency = 1
    dl.Text = "..."
    dl.TextColor3 = Color3.fromRGB(160, 160, 180)
    dl.TextScaled = true
    dl.Font = Enum.Font.Gotham
    dl.Parent = fr

    if egg:IsA("BasePart") then
        bb.Adornee = egg
    elseif egg:IsA("Model") then
        bb.Adornee = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
    end

    bb.Parent = cg

    ST.Esps[egg] = { BB = bb, DL = dl }
end

function Esp.update()
    for egg, data in _pairs(ST.Esps) do
        if egg and egg.Parent then
            local p = Scanner.get_pos(egg)
            if p and data.DL then
                data.DL.Text = "📏 " .. _math.floor(U.dist(p)) .. "m"
            end
        else
            Esp.remove(egg)
        end
    end
end

function Esp.remove(egg)
    if ST.Esps[egg] then
        _pcall(function()
            if ST.Esps[egg].BB then
                ST.Esps[egg].BB:Destroy()
            end
        end)
        ST.Esps[egg] = nil
    end
end

function Esp.clear()
    for egg in _pairs(ST.Esps) do
        Esp.remove(egg)
    end
    ST.Esps = {}
end

-- ============================================================
-- ANTI-DROP SYSTEM
-- ============================================================
local AntiDrop = {}

function AntiDrop.enable()
    if not CFG.AntiDrop then return end
    local hum = U.hum()
    if not hum then return end

    local c = hum.HealthChanged:Connect(function(hp)
        if ST.Carry and ST.HasEgg then
            -- Boost speed saat terkena hit
            local root = U.root()
            if root then
                local bv = root:FindFirstChild("_bv_" .. SCRIPT_ID)
                if bv then
                    bv.Velocity = bv.Velocity * 1.8
                end
            end
        end
    end)
    U.add_conn(c)
end

-- ============================================================
-- STEAL CONTROLLER
-- ============================================================
local Ctrl = {}

function Ctrl.grab(ed)
    if ST.Grab or ST.HasEgg then return end

    ST.Grab = true
    ST.Target = ed.Obj
    ST.TRarity = ed.Rar
    ST.TWeight = ed.Wt

    local bigTxt = ed.Big and (" [BIG " .. ed.Wt .. "kg]") or ""
    stealth_notify("🎯 TARGET", ed.Rar:upper() .. bigTxt .. " | " .. _math.floor(ed.Dist) .. "m", 2)

    -- ANTI-DETECT: Tambahkan delay random kecil sebelum mulai dash
    if CFG.HumanizeDelay then
        _wait(0.05 + _math.random() * 0.1)
    end

    -- Dash ke egg
    MoveEngine:dash_to(ed.Pos, CFG.DashSpeed, function()
        -- Sampai di egg -> pickup
        Ctrl.pickup(ed)
    end)
end

function Ctrl.pickup(ed)
    if CFG.HumanizeDelay then
        _wait(CFG.GrabDelay + _math.random() * 0.05)
    else
        _wait(CFG.GrabDelay)
    end

    -- Coba pickup berkali-kali
    local success = false
    for attempt = 1, 5 do
        success = Steal.try_pickup(ed.Obj)
        if success then break end
        _wait(0.05)

        -- Cek apakah button baru muncul
        local btn = Steal.find_btn()
        if btn then
            _pcall(function()
                if _typeof(firesignal) == "function" then
                    firesignal(btn.Activated)
                else
                    btn:FindFirstAncestorOfClass("ScreenGui").Enabled = true
                end
            end)
            success = true
            break
        end
    end

    if success then
        ST.HasEgg = true
        ST.Carry = true
        ST.Grab = false

        stealth_notify("✅ GRABBED!", ed.Rar:upper() .. " | Escaping...", 2)

        if CFG.AutoRun then
            Ctrl.escape()
        else
            ST.Grab = false
        end
    else
        ST.Grab = false
        stealth_notify("❌ FAILED", "Could not pickup", 2)
    end
end

function Ctrl.escape()
    ST.Esc = true
    ST.Grab = false

    local sp = SZ.get()
    if not sp then
        stealth_notify("❌", "No safe zone!", 2)
        ST.Esc = false
        return
    end

    stealth_notify("🏃 ESCAPING", "Dashing to safe zone!", 2)

    MoveEngine:escape_to(sp, CFG.EscapeSpeed, function()
        -- Arrived at safe zone
        MoveEngine:stop()

        ST.Esc = false
        ST.Carry = false
        ST.Done = true

        stealth_notify("🏠 SAFE!", ST.TRarity:upper() .. " egg claimed!", 4)

        _wait(0.5)
        ST.HasEgg = false
        ST.Done = false
        ST.Target = nil
        ST.TRarity = nil
        ST.TWeight = 0
    end)
end

function Ctrl.stop()
    CFG.On = false
    ST.Grab = false
    ST.Esc = false
    ST.Carry = false
    ST.HasEgg = false
    ST.Target = nil
    ST.TRarity = nil
    ST.TWeight = 0

    MoveEngine:stop()
    U.clear_conns()
    Esp.clear()

    stealth_notify("⏹️ STOPPED", "SYN-STUDIO stopped.", 2)
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local Loop = {}

function Loop.start()
    CFG.On = true
    stealth_notify("▶️ SYN-STUDIO", "Activated! Scanning...", 3)

    SZ.find()
    AntiDrop.enable()

    local mc = rs.Heartbeat:Connect(function()
        if not CFG.On then return end
        if not U.alive() then return end
        if ST.Grab or ST.Esc or ST.HasEgg then return end

        local eggs = Scanner.scan()

        -- Update ESP
        if CFG.ShowESP then
            Esp.clear()
            for _, ed in _ipairs(eggs) do
                Esp.create(ed.Obj, ed.Rar, ed.Wt)
            end
        end

        local best = Scanner.best(eggs)
        if best then
            Ctrl.grab(best)
        end
    end)
    U.add_conn(mc)

    -- ESP update loop
    _spawn(function()
        while CFG.On do
            Esp.update()
            _wait(0.4)
        end
    end)
end

-- ============================================================
-- RESPONSIVE UI SYSTEM
-- Scales properly on PC, Tablet, Phone
-- ============================================================
local GUI = {}

function GUI.scale()
    local vx, vy = U.viewport()
    local is_mobile = uis.TouchEnabled and not uis.KeyboardEnabled
    local base_w, base_h

    if is_mobile then
        if vx < 600 then
            -- Phone portrait
            base_w = vx * 0.92
            base_h = vy * 0.75
        else
            -- Phone landscape / tablet
            base_w = _math.min(vx * 0.55, 400)
            base_h = vy * 0.8
        end
    else
        -- PC
        base_w = _math.clamp(vx * 0.22, 320, 420)
        base_h = _math.clamp(vy * 0.72, 400, 650)
    end

    return base_w, base_h, is_mobile
end

function GUI.font_size(base, mobile)
    if mobile then
        return _math.clamp(base * 1.1, 10, 20)
    end
    return _math.clamp(base, 10, 18)
end

function GUI.create()
    -- Cleanup
    local old = cg:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end

    local base_w, base_h, is_mobile = GUI.scale()
    local fs = function(s) return GUI.font_size(s, is_mobile) end

    -- ScreenGui
    local sg_ui = Instance.new("ScreenGui")
    sg_ui.Name = GUI_NAME
    sg_ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg_ui.ResetOnSpawn = false
    sg_ui.Parent = cg

    -- Auto-scale constraint
    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = sg_ui

    -- Recalculate on viewport change
    local function recalc()
        local vx, vy = U.viewport()
        local s = _math.clamp(vx / 1920, 0.5, 1.5)
        if is_mobile then
            s = _math.clamp(vx / 1080, 0.65, 1.3)
        end
        scale.Scale = s
    end
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(recalc)
    recalc()

    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = FRAME_PREFIX .. "_m"
    main.Size = UDim2.new(0, base_w, 0, base_h)
    main.Position = UDim2.new(0.5, -base_w / 2, 0.5, -base_h / 2)
    main.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.ClipsDescendants = true
    main.Parent = sg_ui

    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

    local ms = Instance.new("UIStroke")
    ms.Color = Color3.fromRGB(90, 40, 220)
    ms.Thickness = 2
    ms.Transparency = 0.1
    ms.Parent = main

    -- Gradient accent on top
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 3)
    accent.Position = UDim2.new(0, 0, 0, 0)
    accent.BackgroundColor3 = Color3.fromRGB(120, 60, 255)
    accent.BorderSizePixel = 0
    accent.ZIndex = 5
    accent.Parent = main

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 150)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 60, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 200, 255)),
    }
    grad.Parent = accent

    -- Title Bar
    local title_h = _math.clamp(base_h * 0.08, 38, 52)
    local tbar = Instance.new("Frame")
    tbar.Size = UDim2.new(1, 0, 0, title_h)
    tbar.Position = UDim2.new(0, 0, 0, 3)
    tbar.BackgroundColor3 = Color3.fromRGB(18, 14, 35)
    tbar.BorderSizePixel = 0
    tbar.Parent = main

    local tlab = Instance.new("TextLabel")
    tlab.Size = UDim2.new(1, -90, 1, 0)
    tlab.Position = UDim2.new(0, 14, 0, 0)
    tlab.BackgroundTransparency = 1
    tlab.Text = "⚡ SYN-STUDIO"
    tlab.TextColor3 = Color3.fromRGB(170, 120, 255)
    tlab.TextSize = fs(17)
    tlab.Font = Enum.Font.GothamBold
    tlab.TextXAlignment = Enum.TextXAlignment.Left
    tlab.Parent = tbar

    local btn_sz = _math.clamp(title_h * 0.7, 26, 36)

    -- Close button
    local cbtn = Instance.new("TextButton")
    cbtn.Size = UDim2.new(0, btn_sz, 0, btn_sz)
    cbtn.Position = UDim2.new(1, -(btn_sz + 6), 0.5, -btn_sz / 2)
    cbtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    cbtn.Text = "✕"
    cbtn.TextColor3 = Color3.new(1, 1, 1)
    cbtn.TextSize = fs(13)
    cbtn.Font = Enum.Font.GothamBold
    cbtn.BorderSizePixel = 0
    cbtn.Parent = tbar
    Instance.new("UICorner", cbtn).CornerRadius = UDim.new(0, 8)

    cbtn.MouseButton1Click:Connect(function()
        Ctrl.stop()
        sg_ui:Destroy()
    end)

    -- Minimize button
    local mbtn = Instance.new("TextButton")
    mbtn.Size = UDim2.new(0, btn_sz, 0, btn_sz)
    mbtn.Position = UDim2.new(1, -(btn_sz * 2 + 14), 0.5, -btn_sz / 2)
    mbtn.BackgroundColor3 = Color3.fromRGB(45, 45, 75)
    mbtn.Text = "—"
    mbtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    mbtn.TextSize = fs(13)
    mbtn.Font = Enum.Font.GothamBold
    mbtn.BorderSizePixel = 0
    mbtn.Parent = tbar
    Instance.new("UICorner", mbtn).CornerRadius = UDim.new(0, 8)

    local minimized = false
    local content_frame -- defined below

    mbtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if content_frame then
            content_frame.Visible = not minimized
        end
        if minimized then
            main.Size = UDim2.new(0, base_w, 0, title_h + 6)
            mbtn.Text = "+"
        else
            main.Size = UDim2.new(0, base_w, 0, base_h)
            mbtn.Text = "—"
        end
    end)

    -- Content area
    local content_y = title_h + 6
    content_frame = Instance.new("ScrollingFrame")
    content_frame.Name = FRAME_PREFIX .. "_c"
    content_frame.Size = UDim2.new(1, -16, 1, -(content_y + 8))
    content_frame.Position = UDim2.new(0, 8, 0, content_y)
    content_frame.BackgroundTransparency = 1
    content_frame.BorderSizePixel = 0
    content_frame.ScrollBarThickness = 3
    content_frame.ScrollBarImageColor3 = Color3.fromRGB(100, 60, 255)
    content_frame.CanvasSize = UDim2.new(0, 0, 0, 0)
    content_frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content_frame.Parent = main

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content_frame

    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = content_frame

    -- ===== UI HELPERS =====

    local order_counter = 0
    local function next_order()
        order_counter = order_counter + 1
        return order_counter
    end

    local function mk_section(text)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, _math.clamp(base_h * 0.045, 24, 30))
        f.BackgroundColor3 = Color3.fromRGB(28, 18, 55)
        f.BorderSizePixel = 0
        f.LayoutOrder = next_order()
        f.Parent = content_frame
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -10, 1, 0)
        l.Position = UDim2.new(0, 10, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = "▸ " .. text
        l.TextColor3 = Color3.fromRGB(140, 100, 255)
        l.TextSize = fs(12)
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = f
    end

    local function mk_toggle(text, default, callback, color)
        local h = _math.clamp(base_h * 0.055, 28, 38)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, h)
        f.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
        f.BorderSizePixel = 0
        f.LayoutOrder = next_order()
        f.Parent = content_frame
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

        if color then
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 10, 0, 10)
            dot.Position = UDim2.new(0, 10, 0.5, -5)
            dot.BackgroundColor3 = color
            dot.BorderSizePixel = 0
            dot.Parent = f
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        end

        local lx = color and 28 or 10
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.62, 0, 1, 0)
        l.Position = UDim2.new(0, lx, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color or Color3.fromRGB(200, 200, 220)
        l.TextSize = fs(11)
        l.Font = color and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Parent = f

        local bw = _math.clamp(base_w * 0.15, 44, 58)
        local bh = _math.clamp(h * 0.65, 18, 26)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, bw, 0, bh)
        b.Position = UDim2.new(1, -(bw + 8), 0.5, -bh / 2)
        b.BorderSizePixel = 0
        b.TextSize = fs(10)
        b.Font = Enum.Font.GothamBold
        b.Parent = f
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

        local on = default
        local function upd()
            if on then
                b.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
                b.Text = "ON"
                b.TextColor3 = Color3.new(1, 1, 1)
            else
                b.BackgroundColor3 = Color3.fromRGB(70, 25, 25)
                b.Text = "OFF"
                b.TextColor3 = Color3.fromRGB(170, 170, 170)
            end
        end
        upd()

        b.MouseButton1Click:Connect(function()
            on = not on
            upd()
            if callback then callback(on) end
        end)

        return f
    end

    local function mk_slider(text, min_v, max_v, default, callback)
        local h = _math.clamp(base_h * 0.075, 40, 55)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, h)
        f.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
        f.BorderSizePixel = 0
        f.LayoutOrder = next_order()
        f.Parent = content_frame
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.58, 0, 0, h * 0.45)
        l.Position = UDim2.new(0, 10, 0, 2)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(200, 200, 220)
        l.TextSize = fs(10)
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Parent = f

        local vl = Instance.new("TextLabel")
        vl.Size = UDim2.new(0.35, 0, 0, h * 0.45)
        vl.Position = UDim2.new(0.63, 0, 0, 2)
        vl.BackgroundTransparency = 1
        vl.Text = _tostring(default)
        vl.TextColor3 = Color3.fromRGB(140, 190, 255)
        vl.TextSize = fs(10)
        vl.Font = Enum.Font.GothamBold
        vl.TextXAlignment = Enum.TextXAlignment.Right
        vl.Parent = f

        local bar_h = _math.clamp(h * 0.15, 5, 10)
        local bar_y = h * 0.6

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, -20, 0, bar_h)
        bg.Position = UDim2.new(0, 10, 0, bar_y)
        bg.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
        bg.BorderSizePixel = 0
        bg.Parent = f
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

        local init_a = (default - min_v) / (max_v - min_v)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(init_a, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(90, 50, 230)
        fill.BorderSizePixel = 0
        fill.Parent = bg
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local knob_sz = _math.clamp(bar_h * 2.2, 12, 20)
        local knob = Instance.new("TextButton")
        knob.Size = UDim2.new(0, knob_sz, 0, knob_sz)
        knob.Position = UDim2.new(init_a, -knob_sz / 2, 0.5, -knob_sz / 2)
        knob.BackgroundColor3 = Color3.fromRGB(160, 110, 255)
        knob.Text = ""
        knob.BorderSizePixel = 0
        knob.ZIndex = 3
        knob.Parent = bg
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local dragging = false

        local function set_val(alpha)
            alpha = _math.clamp(alpha, 0, 1)
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.new(alpha, -knob_sz / 2, 0.5, -knob_sz / 2)
            local val = _math.floor(min_v + (max_v - min_v) * alpha)
            vl.Text = _tostring(val)
            if callback then callback(val) end
        end

        knob.MouseButton1Down:Connect(function() dragging = true end)
        if uis.TouchEnabled then
            knob.TouchLongPress:Connect(function() dragging = true end)
            knob.TouchStarted:Connect(function() dragging = true end)
        end

        uis.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or
               inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        uis.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or
               inp.UserInputType == Enum.UserInputType.Touch) then
                local ap = bg.AbsolutePosition
                local as = bg.AbsoluteSize
                local rx = _math.clamp((inp.Position.X - ap.X) / as.X, 0, 1)
                set_val(rx)
            end
        end)

        bg.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or
               inp.UserInputType == Enum.UserInputType.Touch then
                local ap = bg.AbsolutePosition
                local as = bg.AbsoluteSize
                local rx = _math.clamp((inp.Position.X - ap.X) / as.X, 0, 1)
                set_val(rx)
                dragging = true
            end
        end)

        return f
    end

    local function mk_button(text, color, callback)
        local h = _math.clamp(base_h * 0.065, 32, 44)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, h)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextSize = fs(13)
        b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        b.LayoutOrder = next_order()
        b.Parent = content_frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

        -- Hover effect
        b.MouseEnter:Connect(function()
            ts:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.new(
                    _math.min(color.R + 0.1, 1),
                    _math.min(color.G + 0.1, 1),
                    _math.min(color.B + 0.1, 1)
                )
            }):Play()
        end)
        b.MouseLeave:Connect(function()
            ts:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play()
        end)

        b.MouseButton1Click:Connect(function()
            if callback then callback(b) end
        end)

        return b
    end

    -- ===== STATUS DISPLAY =====
    local status_h = _math.clamp(base_h * 0.1, 45, 65)
    local status_f = Instance.new("Frame")
    status_f.Size = UDim2.new(1, 0, 0, status_h)
    status_f.BackgroundColor3 = Color3.fromRGB(12, 22, 12)
    status_f.BorderSizePixel = 0
    status_f.LayoutOrder = next_order()
    status_f.Parent = content_frame
    Instance.new("UICorner", status_f).CornerRadius = UDim.new(0, 8)

    local sstk = Instance.new("UIStroke")
    sstk.Color = Color3.fromRGB(40, 130, 40)
    sstk.Thickness = 1
    sstk.Parent = status_f

    local slbl = Instance.new("TextLabel")
    slbl.Name = "SL"
    slbl.Size = UDim2.new(1, -14, 1, 0)
    slbl.Position = UDim2.new(0, 7, 0, 0)
    slbl.BackgroundTransparency = 1
    slbl.Text = "📊 IDLE | 🥚 No target"
    slbl.TextColor3 = Color3.fromRGB(140, 240, 140)
    slbl.TextSize = fs(10)
    slbl.Font = Enum.Font.Gotham
    slbl.TextXAlignment = Enum.TextXAlignment.Left
    slbl.TextWrapped = true
    slbl.Parent = status_f

    -- ===== MAIN CONTROLS =====
    mk_section("CONTROLS")

    local running = false
    mk_button("▶  START STEALING", Color3.fromRGB(35, 145, 35), function(btn)
        running = not running
        if running then
            btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            btn.Text = "⏹  STOP STEALING"
            Loop.start()
        else
            btn.BackgroundColor3 = Color3.fromRGB(35, 145, 35)
            btn.Text = "▶  START STEALING"
            Ctrl.stop()
        end
    end)

    mk_button("🏠 Set Safe Zone Here", Color3.fromRGB(40, 70, 150), function()
        CFG.SafePos = U.pos()
        stealth_notify("🏠", "Safe zone saved!", 2)
    end)

    -- ===== FEATURES =====
    mk_section("FEATURES")

    mk_toggle("Instant Steal", CFG.InstSteal, function(v)
        CFG.InstSteal = v
    end)

    mk_toggle("Auto Escape", CFG.AutoRun, function(v)
        CFG.AutoRun = v
    end)

    mk_toggle("Big Egg Priority (>1000kg)", CFG.BigEggOn, function(v)
        CFG.BigEggOn = v
    end)

    mk_toggle("Anti-Drop Protection", CFG.AntiDrop, function(v)
        CFG.AntiDrop = v
    end)

    mk_toggle("Show ESP", CFG.ShowESP, function(v)
        CFG.ShowESP = v
        if not v then Esp.clear() end
    end)

    mk_toggle("Stealth Movement", CFG.StealthMove, function(v)
        CFG.StealthMove = v
    end)

    mk_toggle("Humanize Delays", CFG.HumanizeDelay, function(v)
        CFG.HumanizeDelay = v
    end)

    -- ===== SPEED =====
    mk_section("SPEED")

    mk_slider("Dash Speed", 50, 500, CFG.DashSpeed, function(v)
        CFG.DashSpeed = v
    end)

    mk_slider("Escape Speed", 50, 600, CFG.EscapeSpeed, function(v)
        CFG.EscapeSpeed = v
    end)

    mk_slider("Server Safe Speed", 16, 100, CFG.MaxSpeedServer, function(v)
        CFG.MaxSpeedServer = v
    end)

    mk_slider("Big Egg KG Threshold", 100, 5000, CFG.BigEggKG, function(v)
        CFG.BigEggKG = v
    end)

    -- ===== RARITY FILTER =====
    mk_section("RARITY FILTER")

    local rarity_order = {
        "Ethernal", "Devine", "Cosmic", "Secret",
        "Legend", "Mistic", "Rare", "Epic",
        "Uncommon", "Common"
    }

    for _, r in _ipairs(rarity_order) do
        mk_toggle(r, CFG.Rarities[r], function(v)
            CFG.Rarities[r] = v
        end, CFG.RarityCol[r])
    end

    -- Select/Deselect All
    local sel_f = Instance.new("Frame")
    sel_f.Size = UDim2.new(1, 0, 0, _math.clamp(base_h * 0.05, 26, 34))
    sel_f.BackgroundTransparency = 1
    sel_f.LayoutOrder = next_order()
    sel_f.Parent = content_frame

    local sa = Instance.new("TextButton")
    sa.Size = UDim2.new(0.48, 0, 1, 0)
    sa.BackgroundColor3 = Color3.fromRGB(40, 110, 40)
    sa.Text = "Select All"
    sa.TextColor3 = Color3.new(1, 1, 1)
    sa.TextSize = fs(10)
    sa.Font = Enum.Font.GothamBold
    sa.BorderSizePixel = 0
    sa.Parent = sel_f
    Instance.new("UICorner", sa).CornerRadius = UDim.new(0, 6)

    local da = Instance.new("TextButton")
    da.Size = UDim2.new(0.48, 0, 1, 0)
    da.Position = UDim2.new(0.52, 0, 0, 0)
    da.BackgroundColor3 = Color3.fromRGB(110, 40, 40)
    da.Text = "Deselect All"
    da.TextColor3 = Color3.new(1, 1, 1)
    da.TextSize = fs(10)
    da.Font = Enum.Font.GothamBold
    da.BorderSizePixel = 0
    da.Parent = sel_f
    Instance.new("UICorner", da).CornerRadius = UDim.new(0, 6)

    sa.MouseButton1Click:Connect(function()
        for r in _pairs(CFG.Rarities) do CFG.Rarities[r] = true end
        stealth_notify("✅", "All ON", 1)
        sg_ui:Destroy()
        GUI.create()
    end)

    da.MouseButton1Click:Connect(function()
        for r in _pairs(CFG.Rarities) do CFG.Rarities[r] = false end
        stealth_notify("❌", "All OFF", 1)
        sg_ui:Destroy()
        GUI.create()
    end)

    -- ===== INFO =====
    mk_section("INFO")

    local info_h = _math.clamp(base_h * 0.12, 50, 80)
    local info_f = Instance.new("Frame")
    info_f.Size = UDim2.new(1, 0, 0, info_h)
    info_f.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
    info_f.BorderSizePixel = 0
    info_f.LayoutOrder = next_order()
    info_f.Parent = content_frame
    Instance.new("UICorner", info_f).CornerRadius = UDim.new(0, 6)

    local il = Instance.new("TextLabel")
    il.Size = UDim2.new(1, -14, 1, 0)
    il.Position = UDim2.new(0, 7, 0, 0)
    il.BackgroundTransparency = 1
    il.Text = "⚡ SYN-STUDIO v3.0 STEALTH\n🛡️ Anti-Detection Active\n📱 Responsive UI\n🎮 RightShift = Toggle | F5 = Start/Stop"
    il.TextColor3 = Color3.fromRGB(130, 130, 150)
    il.TextSize = fs(9)
    il.Font = Enum.Font.Gotham
    il.TextXAlignment = Enum.TextXAlignment.Left
    il.TextYAlignment = Enum.TextYAlignment.Top
    il.TextWrapped = true
    il.Parent = info_f

    -- ===== STATUS UPDATE LOOP =====
    _spawn(function()
        while sg_ui and sg_ui.Parent do
            local txt = ""
            if CFG.On then
                if ST.Grab then
                    txt = "📊 🏃 GRABBING"
                elseif ST.Esc then
                    txt = "📊 💨 ESCAPING"
                elseif ST.HasEgg then
                    txt = "📊 🥚 CARRYING"
                else
                    txt = "📊 👁️ SCANNING"
                end
            else
                txt = "📊 ⏸️ IDLE"
            end

            if ST.Target and ST.TRarity then
                local bt = (ST.TWeight >= CFG.BigEggKG) and
                    (" [BIG " .. ST.TWeight .. "kg]") or ""
                txt = txt .. "\n🥚 " .. ST.TRarity:upper() .. bt
            else
                txt = txt .. "\n🥚 No target"
            end

            if slbl and slbl.Parent then
                slbl.Text = txt
            end

            _wait(0.25)
        end
    end)

    -- ===== TOGGLE KEY =====
    local toggle_conn = uis.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Enum.KeyCode.RightShift then
            main.Visible = not main.Visible
        end
    end)
    U.add_conn(toggle_conn)

    -- Mobile toggle button (jika touch device)
    if is_mobile then
        local mob_btn = Instance.new("TextButton")
        mob_btn.Size = UDim2.new(0, 50, 0, 50)
        mob_btn.Position = UDim2.new(0, 10, 0.5, -25)
        mob_btn.BackgroundColor3 = Color3.fromRGB(90, 40, 220)
        mob_btn.BackgroundTransparency = 0.3
        mob_btn.Text = "⚡"
        mob_btn.TextSize = 22
        mob_btn.Font = Enum.Font.GothamBold
        mob_btn.TextColor3 = Color3.new(1, 1, 1)
        mob_btn.BorderSizePixel = 0
        mob_btn.Draggable = true
        mob_btn.Parent = sg_ui
        Instance.new("UICorner", mob_btn).CornerRadius = UDim.new(1, 0)

        mob_btn.MouseButton1Click:Connect(function()
            main.Visible = not main.Visible
        end)
    end

    stealth_notify("⚡ SYN-STUDIO v3.0",
        "Loaded!\n" .. (is_mobile and "Tap ⚡ to toggle" or "RightShift = Toggle UI"), 4)

    return sg_ui
end

-- ============================================================
-- HOTKEYS
-- ============================================================
uis.InputBegan:Connect(function(inp, gpe)
    if gpe then return end

    if inp.KeyCode == Enum.KeyCode.F5 then
        CFG.On = not CFG.On
        if CFG.On then
            Loop.start()
            stealth_notify("▶️", "Started (F5)", 2)
        else
            Ctrl.stop()
            stealth_notify("⏹️", "Stopped (F5)", 2)
        end
    end

    if inp.KeyCode == Enum.KeyCode.F6 then
        CFG.ShowESP = not CFG.ShowESP
        if not CFG.ShowESP then Esp.clear() end
        stealth_notify("👁️", CFG.ShowESP and "ESP ON" or "ESP OFF", 1)
    end

    if inp.KeyCode == Enum.KeyCode.F7 then
        CFG.SafePos = U.pos()
        stealth_notify("🏠", "Safe zone set!", 1)
    end
end)

-- ============================================================
-- RESPAWN HANDLER
-- ============================================================
lp.CharacterAdded:Connect(function()
    _wait(1)
    ST.Grab = false
    ST.Esc = false
    ST.Carry = false
    ST.HasEgg = false
    ST.Target = nil
    MoveEngine:stop()

    if CFG.On then
        stealth_notify("🔄", "Respawned. Resuming...", 2)
    end
end)

-- ============================================================
-- INIT
-- ============================================================
GUI.create()
