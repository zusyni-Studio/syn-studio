--[[
    SYN-STUDIO v4.0
    Egg Stealer - Stealth Edition
    Clean UI / Fast Movement / Smart Targeting
]]

-- ============================================================
-- RANDOMIZE NAMES (Anti-Detect)
-- ============================================================
local function rid(n)
    local s = ""
    for i = 1, (n or 14) do
        local r = math.random(1, 52)
        local c = r <= 26 and string.char(64 + r) or string.char(70 + r)
        s = s .. c
    end
    return s
end

local _ID = rid(16)
local _GN = rid(20)

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    Rarity = {
        Ethernal  = { On = true,  Priority = 1,  Color = Color3.fromRGB(220, 50, 255) },
        Devine    = { On = true,  Priority = 2,  Color = Color3.fromRGB(255, 200, 30) },
        Cosmic    = { On = true,  Priority = 3,  Color = Color3.fromRGB(30, 220, 255) },
        Secret    = { On = true,  Priority = 4,  Color = Color3.fromRGB(230, 30, 30) },
        Legend    = { On = true,  Priority = 5,  Color = Color3.fromRGB(255, 150, 20) },
        Mistic    = { On = true,  Priority = 6,  Color = Color3.fromRGB(140, 20, 200) },
        Rare      = { On = false, Priority = 7,  Color = Color3.fromRGB(30, 100, 255) },
        Epic      = { On = false, Priority = 8,  Color = Color3.fromRGB(150, 50, 220) },
        Uncommon  = { On = false, Priority = 9,  Color = Color3.fromRGB(50, 200, 50) },
        Common    = { On = false, Priority = 10, Color = Color3.fromRGB(160, 160, 160) },
    },
    RarityOrder = {
        "Ethernal", "Devine", "Cosmic", "Secret",
        "Legend", "Mistic", "Rare", "Epic",
        "Uncommon", "Common"
    },

    -- Movement
    MoveSpeed       = 180,
    EscSpeed        = 240,
    BaseSpeed       = 16,
    Acceleration    = 8,

    -- Big Egg
    BigKG           = 1000,
    BigPriority     = true,

    -- Range
    ScanRange       = 5000,
    GrabDist        = 10,
    SafeDist        = 20,

    -- Timing
    GrabDelay       = 0.02,
    ScanRate        = 0.12,

    -- Toggles
    Active          = false,
    InstantSteal    = true,
    AutoEscape      = true,
    AntiDrop        = true,
    ESP             = true,
    Stealth         = true,

    SafePos         = nil,
}

-- ============================================================
-- STATE
-- ============================================================
local STATE = {
    Grabbing    = false,
    Escaping    = false,
    Carrying    = false,
    HasEgg      = false,
    Target      = nil,
    TargetRar   = nil,
    TargetKG    = 0,
    Conns       = {},
    EspList     = {},
    Mover       = nil,
}

-- ============================================================
-- CORE UTILS
-- ============================================================
local function GetChar()
    return LP.Character or LP.CharacterAdded:Wait()
end

local function GetRoot()
    local c = GetChar()
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

local function GetHum()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function GetPos()
    local r = GetRoot()
    return r and r.Position or Vector3.new(0, 0, 0)
end

local function Dist(p)
    return (GetPos() - p).Magnitude
end

local function Alive()
    local h = GetHum()
    return h and h.Health > 0
end

local function Notify(t, d)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "SYN-STUDIO",
            Text = t or "",
            Duration = d or 3,
        })
    end)
end

local function AddConn(c)
    table.insert(STATE.Conns, c)
end

local function ClearConns()
    for _, c in ipairs(STATE.Conns) do
        pcall(function()
            if c and typeof(c) == "RBXScriptConnection" then
                c:Disconnect()
            end
        end)
    end
    STATE.Conns = {}
end

-- ============================================================
-- SMART TARGET FILTER
-- Membedakan egg vs induk/mob/NPC
-- ============================================================
local Filter = {}

-- Keyword yang menandakan ini BUKAN egg (induk/mob/enemy)
Filter.ExcludeKeywords = {
    "mother", "parent", "guardian", "boss", "enemy", "mob",
    "monster", "creature", "npc", "dragon", "chicken", "hen",
    "rooster", "bird", "animal", "pet", "guard", "protector",
    "chaser", "attacker", "induk", "ibu", "mama", "predator",
    "wild", "hostile", "aggro", "minion", "sentinel"
}

-- Keyword yang menandakan ini ADALAH egg
Filter.EggKeywords = {
    "egg", "telur", "ovum", "hatch", "nest_egg", "spawn_egg",
    "rare_egg", "special_egg", "golden_egg", "mystic_egg"
}

function Filter.IsExcluded(obj)
    local name = obj.Name:lower()

    -- Cek exclude keywords
    for _, kw in ipairs(Filter.ExcludeKeywords) do
        if name:find(kw) then return true end
    end

    -- Exclude jika punya Humanoid (itu NPC/mob, bukan egg)
    if obj:IsA("Model") then
        if obj:FindFirstChildOfClass("Humanoid") then return true end
        if obj:FindFirstChild("Head") and obj:FindFirstChild("Torso") then return true end
        if obj:FindFirstChild("Head") and obj:FindFirstChild("UpperTorso") then return true end
        if obj:FindFirstChild("HumanoidRootPart") then return true end
    end

    -- Exclude jika ada health bar / attack script
    for _, child in ipairs(obj:GetChildren()) do
        local cn = child.Name:lower()
        if cn:find("attack") or cn:find("chase") or cn:find("ai") or
           cn:find("pathfind") or cn:find("aggro") or cn:find("health") then
            return true
        end
    end

    -- Exclude player characters
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character == obj then
            return true
        end
    end

    return false
end

function Filter.IsEgg(obj)
    -- Pertama, pastikan BUKAN mob/NPC
    if Filter.IsExcluded(obj) then return false end

    local name = obj.Name:lower()

    -- Cek egg keywords
    for _, kw in ipairs(Filter.EggKeywords) do
        if name:find(kw) then return true end
    end

    -- Cek attribute
    if obj:GetAttribute("IsEgg") or obj:GetAttribute("Egg") or
       obj:GetAttribute("EggType") or obj:GetAttribute("EggRarity") then
        return true
    end

    -- Cek children yang mengindikasikan egg
    for _, child in ipairs(obj:GetChildren()) do
        local cn = child.Name:lower()
        if cn:find("egg") and not cn:find("mother") and not cn:find("parent") then
            -- Pastikan child ini bukan mob reference
            if not Filter.IsExcluded(child) then
                return true
            end
        end
    end

    -- Cek apakah parent foldernya terkait egg
    if obj.Parent then
        local pn = obj.Parent.Name:lower()
        if (pn:find("egg") or pn:find("nest") or pn:find("spawn")) and
           not pn:find("mother") and not pn:find("mob") then
            -- Tapi obj sendiri harus bukan humanoid
            if not obj:FindFirstChildOfClass("Humanoid") then
                return true
            end
        end
    end

    return false
end

-- ============================================================
-- EGG SCANNER
-- ============================================================
local Scanner = {}

function Scanner.GetRarity(obj)
    local name = obj.Name:lower()

    for _, r in ipairs(CFG.RarityOrder) do
        if name:find(r:lower()) then return r end
    end

    -- Attribute check
    for _, attrName in ipairs({"Rarity", "Tier", "Grade", "Type", "EggRarity"}) do
        local attr = obj:GetAttribute(attrName)
        if attr then
            local a = tostring(attr):lower()
            for _, r in ipairs(CFG.RarityOrder) do
                if a:find(r:lower()) then return r end
            end
        end
    end

    -- Value objects
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("StringValue") then
            local cn = child.Name:lower()
            if cn == "rarity" or cn == "tier" or cn == "type" or cn == "grade" then
                local v = child.Value:lower()
                for _, r in ipairs(CFG.RarityOrder) do
                    if v:find(r:lower()) then return r end
                end
            end
        end
    end

    -- Billboard text
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("TextLabel") then
            local t = d.Text:lower()
            for _, r in ipairs(CFG.RarityOrder) do
                if t:find(r:lower()) then return r end
            end
        end
    end

    -- Parent name
    if obj.Parent then
        local pn = obj.Parent.Name:lower()
        for _, r in ipairs(CFG.RarityOrder) do
            if pn:find(r:lower()) then return r end
        end
    end

    return nil
end

function Scanner.GetWeight(obj)
    -- Attributes
    for _, a in ipairs({"Weight","Kilogram","Mass","KG","Kg","weight","kg","mass"}) do
        local v = obj:GetAttribute(a)
        if v then
            local n = tonumber(v)
            if n and n > 0 then return n end
        end
    end

    -- Value objects
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("NumberValue") or child:IsA("IntValue") then
            local cn = child.Name:lower()
            if cn:find("weight") or cn:find("kg") or cn:find("mass") then
                return child.Value
            end
        end
        if child:IsA("StringValue") then
            local cn = child.Name:lower()
            if cn:find("weight") or cn:find("kg") then
                local n = tonumber(child.Value)
                if n then return n end
            end
        end
    end

    -- Name pattern
    local nw = obj.Name:match("(%d+)%s*[kK][gG]")
    if nw then return tonumber(nw) or 0 end

    -- Text labels
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("TextLabel") then
            local tw = d.Text:match("(%d+)%s*[kK][gG]")
            if tw then return tonumber(tw) or 0 end
        end
    end

    return 0
end

function Scanner.GetEggPos(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if p then return p.Position end
    end
    return nil
end

function Scanner.Scan()
    local results = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and Filter.IsEgg(obj) then
            local rar = Scanner.GetRarity(obj)
            local wt = Scanner.GetWeight(obj)
            local pos = Scanner.GetEggPos(obj)

            if pos and rar and CFG.Rarity[rar] and CFG.Rarity[rar].On then
                local d = Dist(pos)
                if d <= CFG.ScanRange then
                    table.insert(results, {
                        Obj   = obj,
                        Rar   = rar,
                        Wt    = wt,
                        Pos   = pos,
                        Pri   = CFG.Rarity[rar].Priority,
                        Big   = wt >= CFG.BigKG,
                        Dist  = d,
                    })
                end
            end
        end
    end

    return results
end

function Scanner.Best(list)
    if #list == 0 then return nil end

    table.sort(list, function(a, b)
        -- Big egg priority
        if CFG.BigPriority then
            if a.Big and not b.Big then return true end
            if not a.Big and b.Big then return false end
            if a.Big and b.Big and a.Wt ~= b.Wt then
                return a.Wt > b.Wt
            end
        end
        -- Rarity priority
        if a.Pri ~= b.Pri then return a.Pri < b.Pri end
        -- Distance
        return a.Dist < b.Dist
    end)

    return list[1]
end

-- ============================================================
-- MOVEMENT ENGINE
-- Cepat tapi smooth, bukan teleport
-- Menggunakan BodyVelocity + CFrame facing
-- ============================================================
local Mover = {}

function Mover.CreateBV(root)
    local old = root:FindFirstChild("_mv_" .. _ID)
    if old then old:Destroy() end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "_mv_" .. _ID
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.P = 1e5
    bv.Parent = root

    -- Anti gravity
    local bg = root:FindFirstChild("_bg_" .. _ID)
    if bg then bg:Destroy() end

    local bodyG = Instance.new("BodyForce")
    bodyG.Name = "_bg_" .. _ID
    bodyG.Force = Vector3.new(0, Workspace.Gravity * root:GetMass(), 0)
    bodyG.Parent = root

    return bv
end

function Mover.RemoveBV(root)
    local bv = root:FindFirstChild("_mv_" .. _ID)
    if bv then bv:Destroy() end
    local bg = root:FindFirstChild("_bg_" .. _ID)
    if bg then bg:Destroy() end
end

function Mover.GoTo(targetPos, speed, onArrive)
    local root = GetRoot()
    local hum = GetHum()
    if not root or not hum then return end

    local bv = Mover.CreateBV(root)
    local currentSpeed = 0

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not CFG.Active or not Alive() then
            bv.Velocity = Vector3.zero
            Mover.RemoveBV(root)
            if conn then conn:Disconnect() end
            return
        end

        -- Update target jika target masih ada
        local tPos = targetPos
        if STATE.Target and STATE.Target.Parent then
            local newPos = Scanner.GetEggPos(STATE.Target)
            if newPos then tPos = newPos end
        end

        local myPos = root.Position
        local delta = tPos - myPos
        local dist = delta.Magnitude

        -- Arrival check
        if dist <= CFG.GrabDist then
            bv.Velocity = Vector3.zero
            Mover.RemoveBV(root)
            if conn then conn:Disconnect() end
            if onArrive then onArrive() end
            return
        end

        local dir = delta.Unit

        -- Smooth acceleration
        local targetSpeed = math.min(speed or CFG.MoveSpeed, dist * 3)
        currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * math.min(dt * CFG.Acceleration, 1)

        -- Horizontal movement only via BV, maintain Y
        local vel = Vector3.new(dir.X, 0, dir.Z).Unit * currentSpeed

        -- Jika target lebih tinggi/rendah, tambah sedikit Y velocity
        local yDiff = tPos.Y - myPos.Y
        if math.abs(yDiff) > 3 then
            vel = vel + Vector3.new(0, math.clamp(yDiff * 2, -50, 50), 0)
        end

        bv.Velocity = vel

        -- Face direction
        pcall(function()
            local lookDir = Vector3.new(dir.X, 0, dir.Z)
            if lookDir.Magnitude > 0.01 then
                root.CFrame = CFrame.new(root.Position, root.Position + lookDir)
            end
        end)

        -- Spoof walkspeed
        if CFG.Stealth then
            hum.WalkSpeed = math.min(currentSpeed * 0.3, 50)
        end
    end)

    AddConn(conn)
    return conn
end

function Mover.Stop()
    local root = GetRoot()
    if root then Mover.RemoveBV(root) end
    local hum = GetHum()
    if hum then hum.WalkSpeed = CFG.BaseSpeed end
end

-- ============================================================
-- SAFE ZONE
-- ============================================================
local SafeZone = {}

function SafeZone.Find()
    local keywords = {
        "safe", "spawn", "base", "home", "lobby",
        "hub", "camp", "start", "nest_base", "safezone"
    }

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("SpawnLocation") then
            local nl = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if nl:find(kw) then
                    CFG.SafePos = obj.Position
                    return obj.Position
                end
            end
        elseif obj:IsA("Model") then
            local nl = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if nl:find(kw) then
                    local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if p then
                        CFG.SafePos = p.Position
                        return p.Position
                    end
                end
            end
        end
    end

    -- Fallback: SpawnLocation
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            CFG.SafePos = obj.Position
            return obj.Position
        end
    end

    CFG.SafePos = GetPos()
    return CFG.SafePos
end

function SafeZone.Get()
    if not CFG.SafePos then SafeZone.Find() end
    return CFG.SafePos
end

function SafeZone.IsInside()
    local p = SafeZone.Get()
    return p and Dist(p) <= CFG.SafeDist
end

-- ============================================================
-- PICKUP SYSTEM
-- ============================================================
local Pickup = {}

function Pickup.FindPrompt(obj)
    if not obj then return nil end

    -- Direct child
    local p = obj:FindFirstChildOfClass("ProximityPrompt")
    if p then return p end

    -- Descendants
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end

    -- Parent & siblings
    if obj.Parent then
        p = obj.Parent:FindFirstChildOfClass("ProximityPrompt")
        if p then return p end
        for _, d in ipairs(obj.Parent:GetDescendants()) do
            if d:IsA("ProximityPrompt") then return d end
        end
    end

    return nil
end

function Pickup.FindClick(obj)
    if obj:IsA("BasePart") then
        local cd = obj:FindFirstChildOfClass("ClickDetector")
        if cd then return cd end
    end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("ClickDetector") then return d end
    end
    return nil
end

function Pickup.FindButton()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local keywords = {
        "pickup", "pick", "grab", "take", "lift",
        "collect", "steal", "carry", "interact", "claim",
        "ambil", "angkat"
    }

    for _, g in ipairs(pg:GetDescendants()) do
        if (g:IsA("TextButton") or g:IsA("ImageButton")) and g.Visible then
            local nl = g.Name:lower()
            local tl = g:IsA("TextButton") and g.Text:lower() or ""
            for _, kw in ipairs(keywords) do
                if nl:find(kw) or tl:find(kw) then
                    if g.AbsoluteSize.X > 0 and g.AbsoluteSize.Y > 0 then
                        return g
                    end
                end
            end
        end
    end

    return nil
end

function Pickup.Execute(egg)
    -- 1) ProximityPrompt
    local prompt = Pickup.FindPrompt(egg)
    if prompt then
        local origHold = prompt.HoldDuration
        local origDist = prompt.MaxActivationDistance
        local origLOS = prompt.RequiresLineOfSight

        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 9999
        prompt.RequiresLineOfSight = false
        prompt.Enabled = true

        pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt, 1)
            end
        end)

        task.delay(0.3, function()
            pcall(function()
                prompt.HoldDuration = origHold
                prompt.MaxActivationDistance = origDist
                prompt.RequiresLineOfSight = origLOS
            end)
        end)
        return true
    end

    -- 2) ClickDetector
    local cd = Pickup.FindClick(egg)
    if cd then
        pcall(function()
            if fireclickdetector then
                fireclickdetector(cd)
            end
        end)
        return true
    end

    -- 3) GUI Button
    local btn = Pickup.FindButton()
    if btn then
        pcall(function()
            if firesignal then
                firesignal(btn.Activated)
                firesignal(btn.MouseButton1Click)
            end
        end)
        return true
    end

    -- 4) Touch
    pcall(function()
        local root = GetRoot()
        local part = egg:IsA("BasePart") and egg or egg:FindFirstChildWhichIsA("BasePart")
        if root and part and firetouchinterest then
            firetouchinterest(root, part, 0)
            task.wait(0.03)
            firetouchinterest(root, part, 1)
        end
    end)

    -- 5) Remote search
    pcall(function()
        for _, rem in ipairs(ReplicatedStorage:GetDescendants()) do
            if rem:IsA("RemoteEvent") then
                local rn = rem.Name:lower()
                if rn:find("pick") or rn:find("grab") or rn:find("steal") or
                   rn:find("collect") or rn:find("take") then
                    rem:FireServer(egg)
                end
            end
        end
    end)

    return false
end

-- ============================================================
-- ESP
-- ============================================================
local ESP = {}

function ESP.Create(egg, rar, wt)
    if not CFG.ESP then return end
    ESP.Remove(egg)

    local pos = Scanner.GetEggPos(egg)
    if not pos then return end

    local col = CFG.Rarity[rar] and CFG.Rarity[rar].Color or Color3.fromRGB(255,255,255)
    local big = wt >= CFG.BigKG

    local bb = Instance.new("BillboardGui")
    bb.Name = rid(8)
    bb.Size = UDim2.new(0, 160, 0, 50)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 2000
    bb.LightInfluence = 0

    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(1, 0, 1, 0)
    fr.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
    fr.BackgroundTransparency = 0.15
    fr.BorderSizePixel = 0
    fr.Parent = bb
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 6)

    local stk = Instance.new("UIStroke")
    stk.Color = col
    stk.Thickness = big and 2.5 or 1.2
    stk.Parent = fr

    local rl = Instance.new("TextLabel")
    rl.Size = UDim2.new(1, -6, 0.5, 0)
    rl.Position = UDim2.new(0, 3, 0, 0)
    rl.BackgroundTransparency = 1
    rl.Text = (big and "[BIG] " or "") .. rar:upper()
    rl.TextColor3 = col
    rl.TextScaled = true
    rl.Font = Enum.Font.GothamBold
    rl.Parent = fr

    local dl = Instance.new("TextLabel")
    dl.Name = "D"
    dl.Size = UDim2.new(1, -6, 0.45, 0)
    dl.Position = UDim2.new(0, 3, 0.52, 0)
    dl.BackgroundTransparency = 1
    dl.Text = wt > 0 and (wt .. "kg | --m") or "--m"
    dl.TextColor3 = Color3.fromRGB(170, 170, 190)
    dl.TextScaled = true
    dl.Font = Enum.Font.Gotham
    dl.Parent = fr

    if egg:IsA("BasePart") then
        bb.Adornee = egg
    elseif egg:IsA("Model") then
        bb.Adornee = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
    end

    bb.Parent = CoreGui
    STATE.EspList[egg] = { BB = bb, DL = dl, Wt = wt }
end

function ESP.Update()
    for egg, data in pairs(STATE.EspList) do
        if egg and egg.Parent then
            local p = Scanner.GetEggPos(egg)
            if p and data.DL then
                local d = math.floor(Dist(p))
                data.DL.Text = (data.Wt > 0 and (data.Wt .. "kg | ") or "") .. d .. "m"
            end
        else
            ESP.Remove(egg)
        end
    end
end

function ESP.Remove(egg)
    if STATE.EspList[egg] then
        pcall(function() STATE.EspList[egg].BB:Destroy() end)
        STATE.EspList[egg] = nil
    end
end

function ESP.Clear()
    for egg in pairs(STATE.EspList) do
        ESP.Remove(egg)
    end
    STATE.EspList = {}
end

-- ============================================================
-- CONTROLLER
-- ============================================================
local Ctrl = {}

function Ctrl.Grab(data)
    if STATE.Grabbing or STATE.HasEgg then return end

    STATE.Grabbing = true
    STATE.Target = data.Obj
    STATE.TargetRar = data.Rar
    STATE.TargetKG = data.Wt

    local bigText = data.Big and (" / " .. data.Wt .. "kg BIG") or ""
    Notify(data.Rar:upper() .. bigText .. " detected. Moving...", 2)

    if CFG.Stealth then
        task.wait(0.03 + math.random() * 0.07)
    end

    Mover.GoTo(data.Pos, CFG.MoveSpeed, function()
        Ctrl.DoPickup(data)
    end)
end

function Ctrl.DoPickup(data)
    task.wait(CFG.GrabDelay)

    local ok = false
    for i = 1, 6 do
        ok = Pickup.Execute(data.Obj)
        if ok then break end
        task.wait(0.04)

        local btn = Pickup.FindButton()
        if btn then
            pcall(function()
                if firesignal then
                    firesignal(btn.Activated)
                    firesignal(btn.MouseButton1Click)
                end
            end)
            ok = true
            break
        end
    end

    if ok then
        STATE.HasEgg = true
        STATE.Carrying = true
        STATE.Grabbing = false

        Notify(data.Rar:upper() .. " secured. Heading to safe zone.", 2)

        if CFG.AutoEscape then
            Ctrl.Escape()
        else
            STATE.Grabbing = false
        end
    else
        STATE.Grabbing = false
        Notify("Pickup failed. Retrying next scan.", 2)
    end
end

function Ctrl.Escape()
    STATE.Escaping = true
    STATE.Grabbing = false

    local sp = SafeZone.Get()
    if not sp then
        Notify("No safe zone found.", 2)
        STATE.Escaping = false
        return
    end

    Mover.GoTo(sp, CFG.EscSpeed, function()
        Mover.Stop()
        STATE.Escaping = false
        STATE.Carrying = false

        Notify(STATE.TargetRar:upper() .. " egg delivered.", 3)

        task.wait(0.4)
        STATE.HasEgg = false
        STATE.Target = nil
        STATE.TargetRar = nil
        STATE.TargetKG = 0
    end)
end

function Ctrl.FullStop()
    CFG.Active = false
    STATE.Grabbing = false
    STATE.Escaping = false
    STATE.Carrying = false
    STATE.HasEgg = false
    STATE.Target = nil
    STATE.TargetRar = nil
    STATE.TargetKG = 0

    Mover.Stop()
    ClearConns()
    ESP.Clear()
end

-- ============================================================
-- ANTI DROP
-- ============================================================
local function EnableAntiDrop()
    if not CFG.AntiDrop then return end
    local hum = GetHum()
    if not hum then return end

    local c = hum.HealthChanged:Connect(function()
        if STATE.Carrying and STATE.HasEgg then
            local root = GetRoot()
            if root then
                local bv = root:FindFirstChild("_mv_" .. _ID)
                if bv then
                    bv.Velocity = bv.Velocity * 1.6
                end
            end
        end
    end)
    AddConn(c)
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local MainLoop = {}

function MainLoop.Start()
    CFG.Active = true
    SafeZone.Find()
    EnableAntiDrop()

    Notify("Activated. Scanning for eggs...", 3)

    local scanConn = RunService.Heartbeat:Connect(function()
        if not CFG.Active then return end
        if not Alive() then return end
        if STATE.Grabbing or STATE.Escaping or STATE.HasEgg then return end

        local eggs = Scanner.Scan()

        if CFG.ESP then
            ESP.Clear()
            for _, ed in ipairs(eggs) do
                ESP.Create(ed.Obj, ed.Rar, ed.Wt)
            end
        end

        local best = Scanner.Best(eggs)
        if best then
            Ctrl.Grab(best)
        end
    end)
    AddConn(scanConn)

    task.spawn(function()
        while CFG.Active do
            ESP.Update()
            task.wait(0.5)
        end
    end)
end

-- ============================================================
-- UI - CLEAN MINIMALIST (NO EMOJI)
-- ============================================================
local UI = {}

function UI.GetScale()
    local vx = Camera.ViewportSize.X
    local vy = Camera.ViewportSize.Y
    local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    local w, h
    if mobile then
        w = math.clamp(vx * 0.88, 280, 400)
        h = math.clamp(vy * 0.72, 380, 600)
    else
        w = math.clamp(vx * 0.2, 300, 400)
        h = math.clamp(vy * 0.7, 400, 640)
    end

    return w, h, mobile
end

function UI.Build()
    -- Cleanup old
    local old = CoreGui:FindFirstChild(_GN)
    if old then old:Destroy() end

    local W, H, MOBILE = UI.GetScale()

    -- Color Palette
    local C = {
        bg        = Color3.fromRGB(14, 14, 22),
        surface   = Color3.fromRGB(20, 20, 32),
        card      = Color3.fromRGB(24, 24, 38),
        border    = Color3.fromRGB(45, 35, 80),
        accent    = Color3.fromRGB(100, 60, 220),
        accent2   = Color3.fromRGB(75, 45, 180),
        text      = Color3.fromRGB(210, 210, 225),
        textDim   = Color3.fromRGB(130, 130, 155),
        textBright= Color3.fromRGB(240, 240, 255),
        green     = Color3.fromRGB(45, 160, 65),
        red       = Color3.fromRGB(170, 45, 45),
        redBright = Color3.fromRGB(210, 55, 55),
        greenDim  = Color3.fromRGB(30, 90, 40),
        redDim    = Color3.fromRGB(90, 25, 25),
        slider    = Color3.fromRGB(80, 50, 200),
        sliderBg  = Color3.fromRGB(35, 35, 55),
        line      = Color3.fromRGB(40, 35, 65),
    }

    local SG = Instance.new("ScreenGui")
    SG.Name = _GN
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.ResetOnSpawn = false
    SG.Parent = CoreGui

    -- Responsive scale
    local uiScale = Instance.new("UIScale")
    uiScale.Parent = SG

    local function rescale()
        local vx = Camera.ViewportSize.X
        local s = MOBILE and math.clamp(vx / 1080, 0.65, 1.25) or math.clamp(vx / 1920, 0.6, 1.4)
        uiScale.Scale = s
    end
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
    rescale()

    -- MAIN CONTAINER
    local Main = Instance.new("Frame")
    Main.Name = rid(6)
    Main.Size = UDim2.new(0, W, 0, H)
    Main.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    Main.BackgroundColor3 = C.bg
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.ClipsDescendants = true
    Main.Parent = SG

    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = C.border
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.2
    mainStroke.Parent = Main

    -- TOP ACCENT LINE
    local topLine = Instance.new("Frame")
    topLine.Size = UDim2.new(1, 0, 0, 2)
    topLine.BackgroundColor3 = C.accent
    topLine.BorderSizePixel = 0
    topLine.ZIndex = 5
    topLine.Parent = Main

    local lineGrad = Instance.new("UIGradient")
    lineGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 60, 220)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 80, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 40, 180)),
    }
    lineGrad.Parent = topLine

    -- TITLE BAR
    local TH = math.clamp(H * 0.07, 36, 48)

    local TBar = Instance.new("Frame")
    TBar.Size = UDim2.new(1, 0, 0, TH)
    TBar.Position = UDim2.new(0, 0, 0, 2)
    TBar.BackgroundColor3 = C.surface
    TBar.BorderSizePixel = 0
    TBar.Parent = Main

    local TTitle = Instance.new("TextLabel")
    TTitle.Size = UDim2.new(1, -80, 1, 0)
    TTitle.Position = UDim2.new(0, 16, 0, 0)
    TTitle.BackgroundTransparency = 1
    TTitle.Text = "SYN-STUDIO"
    TTitle.TextColor3 = C.accent
    TTitle.TextSize = MOBILE and 16 or 15
    TTitle.Font = Enum.Font.GothamBold
    TTitle.TextXAlignment = Enum.TextXAlignment.Left
    TTitle.Parent = TBar

    local TVersion = Instance.new("TextLabel")
    TVersion.Size = UDim2.new(0, 30, 0, 14)
    TVersion.Position = UDim2.new(0, 118, 0.5, -7)
    TVersion.BackgroundColor3 = C.accent2
    TVersion.BackgroundTransparency = 0.5
    TVersion.Text = "v4"
    TVersion.TextColor3 = C.textDim
    TVersion.TextSize = 9
    TVersion.Font = Enum.Font.GothamBold
    TVersion.TextXAlignment = Enum.TextXAlignment.Center
    TVersion.Parent = TBar
    Instance.new("UICorner", TVersion).CornerRadius = UDim.new(0, 4)

    -- Close
    local BS = math.clamp(TH * 0.6, 22, 32)

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, BS, 0, BS)
    CloseBtn.Position = UDim2.new(1, -(BS+8), 0.5, -BS/2)
    CloseBtn.BackgroundColor3 = C.red
    CloseBtn.Text = "x"
    CloseBtn.TextColor3 = C.textBright
    CloseBtn.TextSize = MOBILE and 14 or 12
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = TBar
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    CloseBtn.MouseButton1Click:Connect(function()
        Ctrl.FullStop()
        SG:Destroy()
    end)

    -- Minimize
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, BS, 0, BS)
    MinBtn.Position = UDim2.new(1, -(BS*2+16), 0.5, -BS/2)
    MinBtn.BackgroundColor3 = C.card
    MinBtn.Text = "-"
    MinBtn.TextColor3 = C.textDim
    MinBtn.TextSize = MOBILE and 16 or 14
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TBar
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

    local minimized = false
    local ContentArea

    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if ContentArea then ContentArea.Visible = not minimized end
        Main.Size = minimized and UDim2.new(0, W, 0, TH + 4) or UDim2.new(0, W, 0, H)
        MinBtn.Text = minimized and "+" or "-"
    end)

    -- SEPARATOR
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, -24, 0, 1)
    sep.Position = UDim2.new(0, 12, 0, TH + 2)
    sep.BackgroundColor3 = C.line
    sep.BorderSizePixel = 0
    sep.Parent = Main

    -- CONTENT SCROLL
    ContentArea = Instance.new("ScrollingFrame")
    ContentArea.Name = rid(5)
    ContentArea.Size = UDim2.new(1, -16, 1, -(TH + 12))
    ContentArea.Position = UDim2.new(0, 8, 0, TH + 6)
    ContentArea.BackgroundTransparency = 1
    ContentArea.BorderSizePixel = 0
    ContentArea.ScrollBarThickness = 2
    ContentArea.ScrollBarImageColor3 = C.accent
    ContentArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ContentArea.CanvasSize = UDim2.new(0, 0, 0, 0)
    ContentArea.Parent = Main

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = ContentArea

    Instance.new("UIPadding", ContentArea).PaddingBottom = UDim.new(0, 12)

    -- ORDER COUNTER
    local _ord = 0
    local function ord()
        _ord = _ord + 1
        return _ord
    end

    -- ===== UI COMPONENTS =====

    local function Section(text)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 26)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.LayoutOrder = ord()
        f.Parent = ContentArea

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 1, 0)
        l.Position = UDim2.new(0, 4, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = text:upper()
        l.TextColor3 = C.textDim
        l.TextSize = MOBILE and 10 or 9
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = f

        -- underline
        local ul = Instance.new("Frame")
        ul.Size = UDim2.new(1, -8, 0, 1)
        ul.Position = UDim2.new(0, 4, 1, -1)
        ul.BackgroundColor3 = C.line
        ul.BorderSizePixel = 0
        ul.Parent = f
    end

    local function Toggle(text, default, callback, dotColor)
        local h = MOBILE and 36 or 32
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, h)
        f.BackgroundColor3 = C.card
        f.BorderSizePixel = 0
        f.LayoutOrder = ord()
        f.Parent = ContentArea
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

        local lx = 10
        if dotColor then
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 8, 0, 8)
            dot.Position = UDim2.new(0, 10, 0.5, -4)
            dot.BackgroundColor3 = dotColor
            dot.BorderSizePixel = 0
            dot.Parent = f
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
            lx = 26
        end

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.65, -lx, 1, 0)
        l.Position = UDim2.new(0, lx, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = dotColor or C.text
        l.TextSize = MOBILE and 12 or 11
        l.Font = dotColor and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Parent = f

        -- Toggle switch style
        local sw_w = MOBILE and 42 or 38
        local sw_h = MOBILE and 20 or 18
        local sw = Instance.new("TextButton")
        sw.Size = UDim2.new(0, sw_w, 0, sw_h)
        sw.Position = UDim2.new(1, -(sw_w + 8), 0.5, -sw_h/2)
        sw.BorderSizePixel = 0
        sw.Text = ""
        sw.AutoButtonColor = false
        sw.Parent = f
        Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)

        -- Knob inside switch
        local knob_sz = sw_h - 4
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, knob_sz, 0, knob_sz)
        knob.BackgroundColor3 = C.textBright
        knob.BorderSizePixel = 0
        knob.Parent = sw
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local on = default
        local function upd(animate)
            local dur = animate and 0.15 or 0
            if on then
                TweenService:Create(sw, TweenInfo.new(dur), {BackgroundColor3 = C.green}):Play()
                TweenService:Create(knob, TweenInfo.new(dur), {Position = UDim2.new(1, -(knob_sz+2), 0.5, -knob_sz/2)}):Play()
            else
                TweenService:Create(sw, TweenInfo.new(dur), {BackgroundColor3 = C.sliderBg}):Play()
                TweenService:Create(knob, TweenInfo.new(dur), {Position = UDim2.new(0, 2, 0.5, -knob_sz/2)}):Play()
            end
        end
        upd(false)

        sw.MouseButton1Click:Connect(function()
            on = not on
            upd(true)
            if callback then callback(on) end
        end)

        return f, function() return on end
    end

    local function Slider(text, minV, maxV, default, callback)
        local h = MOBILE and 48 or 44
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, h)
        f.BackgroundColor3 = C.card
        f.BorderSizePixel = 0
        f.LayoutOrder = ord()
        f.Parent = ContentArea
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.6, 0, 0, h * 0.45)
        l.Position = UDim2.new(0, 10, 0, 2)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = C.text
        l.TextSize = MOBILE and 11 or 10
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Parent = f

        local vl = Instance.new("TextLabel")
        vl.Size = UDim2.new(0.35, 0, 0, h * 0.45)
        vl.Position = UDim2.new(0.63, 0, 0, 2)
        vl.BackgroundTransparency = 1
        vl.Text = tostring(default)
        vl.TextColor3 = C.accent
        vl.TextSize = MOBILE and 11 or 10
        vl.Font = Enum.Font.GothamBold
        vl.TextXAlignment = Enum.TextXAlignment.Right
        vl.Parent = f

        local barH = math.clamp(h * 0.12, 4, 8)
        local barY = h * 0.65

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, -20, 0, barH)
        bg.Position = UDim2.new(0, 10, 0, barY)
        bg.BackgroundColor3 = C.sliderBg
        bg.BorderSizePixel = 0
        bg.Parent = f
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

        local initA = math.clamp((default - minV) / (maxV - minV), 0, 1)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(initA, 0, 1, 0)
        fill.BackgroundColor3 = C.slider
        fill.BorderSizePixel = 0
        fill.Parent = bg
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local kSz = math.clamp(barH * 2.5, 12, 18)
        local knob = Instance.new("TextButton")
        knob.Size = UDim2.new(0, kSz, 0, kSz)
        knob.Position = UDim2.new(initA, -kSz/2, 0.5, -kSz/2)
        knob.BackgroundColor3 = C.accent
        knob.Text = ""
        knob.BorderSizePixel = 0
        knob.ZIndex = 3
        knob.AutoButtonColor = false
        knob.Parent = bg
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local dragging = false

        local function setAlpha(a)
            a = math.clamp(a, 0, 1)
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, -kSz/2, 0.5, -kSz/2)
            local val = math.floor(minV + (maxV - minV) * a)
            vl.Text = tostring(val)
            if callback then callback(val) end
        end

        local function inputHandler(inputPos)
            local ap = bg.AbsolutePosition
            local as = bg.AbsoluteSize
            local rx = math.clamp((inputPos.X - ap.X) / as.X, 0, 1)
            setAlpha(rx)
        end

        knob.MouseButton1Down:Connect(function() dragging = true end)

        bg.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or
               inp.UserInputType == Enum.UserInputType.Touch then
                inputHandler(inp.Position)
                dragging = true
            end
        end)

        UserInputService.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or
               inp.UserInputType == Enum.UserInputType.Touch) then
                inputHandler(inp.Position)
            end
        end)

        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or
               inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        return f
    end

    local function Button(text, color, callback)
        local h = MOBILE and 38 or 34
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, h)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = C.textBright
        b.TextSize = MOBILE and 13 or 12
        b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.LayoutOrder = ord()
        b.Parent = ContentArea
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)

        -- Hover
        local origColor = color
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {
                BackgroundColor3 = Color3.new(
                    math.min(color.R * 1.2, 1),
                    math.min(color.G * 1.2, 1),
                    math.min(color.B * 1.2, 1)
                )
            }):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = origColor}):Play()
        end)

        b.MouseButton1Click:Connect(function()
            -- Click feedback
            TweenService:Create(b, TweenInfo.new(0.05), {BackgroundColor3 = C.textBright}):Play()
            task.wait(0.05)
            TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = origColor}):Play()
            if callback then callback(b) end
        end)

        return b
    end

    -- ===== STATUS BAR =====
    local statusH = MOBILE and 50 or 44
    local statusF = Instance.new("Frame")
    statusF.Size = UDim2.new(1, 0, 0, statusH)
    statusF.BackgroundColor3 = Color3.fromRGB(14, 20, 14)
    statusF.BorderSizePixel = 0
    statusF.LayoutOrder = ord()
    statusF.Parent = ContentArea
    Instance.new("UICorner", statusF).CornerRadius = UDim.new(0, 6)

    local statusStroke = Instance.new("UIStroke")
    statusStroke.Color = Color3.fromRGB(35, 80, 35)
    statusStroke.Thickness = 1
    statusStroke.Transparency = 0.3
    statusStroke.Parent = statusF

    -- Status indicator dot
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 6, 0, 6)
    statusDot.Position = UDim2.new(0, 10, 0, 10)
    statusDot.BackgroundColor3 = C.textDim
    statusDot.BorderSizePixel = 0
    statusDot.Parent = statusF
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name = "SL"
    statusLbl.Size = UDim2.new(1, -24, 1, 0)
    statusLbl.Position = UDim2.new(0, 22, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "IDLE  |  No target"
    statusLbl.TextColor3 = Color3.fromRGB(120, 200, 120)
    statusLbl.TextSize = MOBILE and 11 or 10
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextWrapped = true
    statusLbl.Parent = statusF

    -- ===== CONTROLS =====
    Section("Controls")

    local isRunning = false
    Button("START", C.green, function(btn)
        isRunning = not isRunning
        if isRunning then
            btn.BackgroundColor3 = C.redBright
            btn.Text = "STOP"
            MainLoop.Start()
        else
            btn.BackgroundColor3 = C.green
            btn.Text = "START"
            Ctrl.FullStop()
        end
    end)

    Button("Set Safe Zone at Current Position", C.accent2, function()
        CFG.SafePos = GetPos()
        Notify("Safe zone position saved.", 2)
    end)

    -- ===== FEATURES =====
    Section("Features")

    Toggle("Instant Steal", CFG.InstantSteal, function(v) CFG.InstantSteal = v end)
    Toggle("Auto Escape", CFG.AutoEscape, function(v) CFG.AutoEscape = v end)
    Toggle("Big Egg Priority", CFG.BigPriority, function(v) CFG.BigPriority = v end)
    Toggle("Anti-Drop Boost", CFG.AntiDrop, function(v) CFG.AntiDrop = v end)
    Toggle("Show ESP", CFG.ESP, function(v)
        CFG.ESP = v
        if not v then ESP.Clear() end
    end)
    Toggle("Stealth Mode", CFG.Stealth, function(v) CFG.Stealth = v end)

    -- ===== SPEED =====
    Section("Speed")

    Slider("Move Speed", 80, 500, CFG.MoveSpeed, function(v) CFG.MoveSpeed = v end)
    Slider("Escape Speed", 80, 600, CFG.EscSpeed, function(v) CFG.EscSpeed = v end)
    Slider("Acceleration", 2, 20, CFG.Acceleration, function(v) CFG.Acceleration = v end)
    Slider("Big Egg Threshold (kg)", 100, 5000, CFG.BigKG, function(v) CFG.BigKG = v end)

    -- ===== RARITY FILTER =====
    Section("Rarity Filter")

    local rarityToggles = {}

    for _, r in ipairs(CFG.RarityOrder) do
        local data = CFG.Rarity[r]
        local _, getter = Toggle(r, data.On, function(v)
            CFG.Rarity[r].On = v
        end, data.Color)
        rarityToggles[r] = getter
    end

    -- Select All / Deselect All row
    local selFrame = Instance.new("Frame")
    selFrame.Size = UDim2.new(1, 0, 0, MOBILE and 32 or 28)
    selFrame.BackgroundTransparency = 1
    selFrame.LayoutOrder = ord()
    selFrame.Parent = ContentArea

    local selAll = Instance.new("TextButton")
    selAll.Size = UDim2.new(0.48, 0, 1, 0)
    selAll.BackgroundColor3 = C.greenDim
    selAll.Text = "All On"
    selAll.TextColor3 = C.text
    selAll.TextSize = MOBILE and 11 or 10
    selAll.Font = Enum.Font.GothamBold
    selAll.BorderSizePixel = 0
    selAll.Parent = selFrame
    Instance.new("UICorner", selAll).CornerRadius = UDim.new(0, 5)

    local deselAll = Instance.new("TextButton")
    deselAll.Size = UDim2.new(0.48, 0, 1, 0)
    deselAll.Position = UDim2.new(0.52, 0, 0, 0)
    deselAll.BackgroundColor3 = C.redDim
    deselAll.Text = "All Off"
    deselAll.TextColor3 = C.text
    deselAll.TextSize = MOBILE and 11 or 10
    deselAll.Font = Enum.Font.GothamBold
    deselAll.BorderSizePixel = 0
    deselAll.Parent = selFrame
    Instance.new("UICorner", deselAll).CornerRadius = UDim.new(0, 5)

    selAll.MouseButton1Click:Connect(function()
        for r in pairs(CFG.Rarity) do CFG.Rarity[r].On = true end
        SG:Destroy()
        UI.Build()
    end)

    deselAll.MouseButton1Click:Connect(function()
        for r in pairs(CFG.Rarity) do CFG.Rarity[r].On = false end
        SG:Destroy()
        UI.Build()
    end)

    -- ===== INFO =====
    Section("Info")

    local infoF = Instance.new("Frame")
    infoF.Size = UDim2.new(1, 0, 0, MOBILE and 60 or 52)
    infoF.BackgroundColor3 = C.card
    infoF.BorderSizePixel = 0
    infoF.LayoutOrder = ord()
    infoF.Parent = ContentArea
    Instance.new("UICorner", infoF).CornerRadius = UDim.new(0, 6)

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, -14, 1, 0)
    infoLbl.Position = UDim2.new(0, 7, 0, 0)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = "SYN-STUDIO v4.0\nRightShift  Toggle UI\nF5  Start/Stop  |  F6  ESP  |  F7  Safe Zone"
    infoLbl.TextColor3 = C.textDim
    infoLbl.TextSize = MOBILE and 9 or 8
    infoLbl.Font = Enum.Font.Gotham
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
    infoLbl.TextYAlignment = Enum.TextYAlignment.Center
    infoLbl.TextWrapped = true
    infoLbl.Parent = infoF

    -- ===== MOBILE TOGGLE BUTTON =====
    if MOBILE then
        local mobBtn = Instance.new("TextButton")
        mobBtn.Size = UDim2.new(0, 44, 0, 44)
        mobBtn.Position = UDim2.new(0, 8, 0.5, -22)
        mobBtn.BackgroundColor3 = C.accent
        mobBtn.BackgroundTransparency = 0.2
        mobBtn.Text = "S"
        mobBtn.TextSize = 18
        mobBtn.Font = Enum.Font.GothamBold
        mobBtn.TextColor3 = C.textBright
        mobBtn.BorderSizePixel = 0
        mobBtn.Draggable = true
        mobBtn.Parent = SG
        Instance.new("UICorner", mobBtn).CornerRadius = UDim.new(1, 0)

        mobBtn.MouseButton1Click:Connect(function()
            Main.Visible = not Main.Visible
        end)
    end

    -- ===== STATUS UPDATE =====
    task.spawn(function()
        while SG and SG.Parent do
            local txt = ""
            local dotCol = C.textDim

            if CFG.Active then
                if STATE.Grabbing then
                    txt = "MOVING TO TARGET"
                    dotCol = Color3.fromRGB(255, 200, 50)
                elseif STATE.Escaping then
                    txt = "ESCAPING TO SAFE ZONE"
                    dotCol = Color3.fromRGB(255, 130, 30)
                elseif STATE.HasEgg then
                    txt = "CARRYING EGG"
                    dotCol = Color3.fromRGB(100, 200, 255)
                else
                    txt = "SCANNING"
                    dotCol = C.green
                end
            else
                txt = "IDLE"
                dotCol = C.textDim
            end

            if STATE.Target and STATE.TargetRar then
                local bt = STATE.TargetKG >= CFG.BigKG and
                    ("  [BIG " .. STATE.TargetKG .. "kg]") or ""
                txt = txt .. "  |  " .. STATE.TargetRar:upper() .. bt
            else
                txt = txt .. "  |  No target"
            end

            if statusLbl and statusLbl.Parent then
                statusLbl.Text = txt
            end
            if statusDot and statusDot.Parent then
                statusDot.BackgroundColor3 = dotCol
            end

            task.wait(0.2)
        end
    end)

    -- Toggle visibility
    local togConn = UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Enum.KeyCode.RightShift then
            Main.Visible = not Main.Visible
        end
    end)
    AddConn(togConn)

    return SG
end

-- ============================================================
-- HOTKEYS
-- ============================================================
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end

    if inp.KeyCode == Enum.KeyCode.F5 then
        CFG.Active = not CFG.Active
        if CFG.Active then
            MainLoop.Start()
            Notify("Started.", 2)
        else
            Ctrl.FullStop()
            Notify("Stopped.", 2)
        end
    end

    if inp.KeyCode == Enum.KeyCode.F6 then
        CFG.ESP = not CFG.ESP
        if not CFG.ESP then ESP.Clear() end
        Notify("ESP " .. (CFG.ESP and "enabled" or "disabled"), 1)
    end

    if inp.KeyCode == Enum.KeyCode.F7 then
        CFG.SafePos = GetPos()
        Notify("Safe zone saved.", 1)
    end
end)

-- ============================================================
-- RESPAWN
-- ============================================================
LP.CharacterAdded:Connect(function()
    task.wait(1)
    STATE.Grabbing = false
    STATE.Escaping = false
    STATE.Carrying = false
    STATE.HasEgg = false
    STATE.Target = nil
    Mover.Stop()
end)

-- ============================================================
-- INIT
-- ============================================================
UI.Build()
Notify("SYN-STUDIO v4 loaded. Configure and press START.", 4)
