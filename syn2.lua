--[[
    SYN-STUDIO v5.0
    Complete Rewrite - Optimized & Working
]]

-- Anti-detect naming
local function rn(l)
    local s,c = "","qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM"
    for i=1,(l or 12) do local r=math.random(1,#c) s=s..c:sub(r,r) end
    return s
end
local _ID,_UI = rn(14),rn(18)

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local RepS = game:GetService("ReplicatedStorage")
local CG = game:GetService("CoreGui")
local SG = game:GetService("StarterGui")
local LP = Players.LocalPlayer

-- =============================================
-- CONFIG
-- =============================================
local Config = {
    RarityList = {"Ethernal","Devine","Cosmic","Secret","Legend","Mistic","Rare","Epic","Uncommon","Common"},
    RarityEnabled = {
        Ethernal=true, Devine=true, Cosmic=true, Secret=true, Legend=true,
        Mistic=true, Rare=false, Epic=false, Uncommon=false, Common=false,
    },
    RarityPri = {
        Ethernal=1,Devine=2,Cosmic=3,Secret=4,Legend=5,
        Mistic=6,Rare=7,Epic=8,Uncommon=9,Common=10,
    },
    RarityCol = {
        Ethernal=Color3.fromRGB(255,60,255), Devine=Color3.fromRGB(255,210,40),
        Cosmic=Color3.fromRGB(40,230,255), Secret=Color3.fromRGB(240,40,40),
        Legend=Color3.fromRGB(255,160,30), Mistic=Color3.fromRGB(150,30,210),
        Rare=Color3.fromRGB(40,110,255), Epic=Color3.fromRGB(160,60,230),
        Uncommon=Color3.fromRGB(60,210,60), Common=Color3.fromRGB(170,170,170),
    },
    Speed = 160,
    EscSpeed = 220,
    BigKG = 1000,
    BigMode = true,
    GrabDist = 15,
    SafeDist = 25,
    Active = false,
    AutoEsc = true,
    AntiDrop = true,
    ShowESP = true,
    SafePos = nil,
}

-- =============================================
-- STATE
-- =============================================
local State = {
    Moving = false,
    Escaping = false,
    HasEgg = false,
    Target = nil,
    TargetRar = nil,
    TargetKG = 0,
    Conns = {},
    Esps = {},
    MainConn = nil,
    EspConn = nil,
    MoveConn = nil,
}

-- =============================================
-- UTILS (lightweight)
-- =============================================
local function GetChar() return LP.Character end
local function GetRoot()
    local c = GetChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function MyPos()
    local r = GetRoot()
    return r and r.Position or Vector3.zero
end
local function Dist(p) return (MyPos()-p).Magnitude end
local function Alive()
    local h = GetHum()
    return h and h.Health > 0
end

local function Notify(t,d)
    pcall(function()
        SG:SetCore("SendNotification",{Title="SYN",Text=t or"",Duration=d or 2})
    end)
end

local function DisconnectAll()
    if State.MainConn then pcall(function() State.MainConn:Disconnect() end) State.MainConn=nil end
    if State.EspConn then pcall(function() State.EspConn:Disconnect() end) State.EspConn=nil end
    if State.MoveConn then pcall(function() State.MoveConn:Disconnect() end) State.MoveConn=nil end
    for _,c in ipairs(State.Conns) do pcall(function() c:Disconnect() end) end
    State.Conns = {}
end

-- =============================================
-- EGG DETECTION (Optimized - no lag)
-- Scan hanya per interval, cache results
-- =============================================
local EggCache = {}
local LastScan = 0

local function IsNPC(obj)
    if not obj:IsA("Model") then return false end
    if obj:FindFirstChildOfClass("Humanoid") then return true end
    if obj:FindFirstChild("HumanoidRootPart") then return true end
    if obj:FindFirstChild("Head") and (obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")) then return true end
    return false
end

local function IsPlayer(obj)
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character == obj then return true end
    end
    return false
end

local BAD_WORDS = {"mother","parent","guardian","boss","enemy","mob","monster",
    "creature","npc","dragon","chicken","hen","animal","pet","guard",
    "chaser","attacker","hostile","wild","predator","minion","zombie",
    "wolf","bear","spider","snake","induk","musuh"}

local function IsBadName(name)
    local low = name:lower()
    for _,w in ipairs(BAD_WORDS) do
        if low:find(w) then return true end
    end
    return false
end

local EGG_WORDS = {"egg","telur","ovum","hatch"}

local function LooksLikeEgg(obj)
    local low = obj.Name:lower()
    for _,w in ipairs(EGG_WORDS) do
        if low:find(w) then return true end
    end
    -- check attributes
    for _,a in ipairs({"IsEgg","Egg","EggType","EggRarity","Rarity"}) do
        if obj:GetAttribute(a) ~= nil then return true end
    end
    -- check parent folder
    if obj.Parent then
        local plow = obj.Parent.Name:lower()
        for _,w in ipairs(EGG_WORDS) do
            if plow:find(w) then return true end
        end
    end
    return false
end

local function GetRarity(obj)
    -- check name
    local low = obj.Name:lower()
    for _,r in ipairs(Config.RarityList) do
        if low:find(r:lower()) then return r end
    end
    -- check attributes
    for _,aName in ipairs({"Rarity","Tier","Grade","Type","EggRarity","EggTier"}) do
        local a = obj:GetAttribute(aName)
        if a then
            local al = tostring(a):lower()
            for _,r in ipairs(Config.RarityList) do
                if al:find(r:lower()) then return r end
            end
        end
    end
    -- check string values
    for _,ch in ipairs(obj:GetChildren()) do
        if ch:IsA("StringValue") then
            local cl = ch.Value:lower()
            for _,r in ipairs(Config.RarityList) do
                if cl:find(r:lower()) then return r end
            end
        end
    end
    -- check parent name
    if obj.Parent then
        local pl = obj.Parent.Name:lower()
        for _,r in ipairs(Config.RarityList) do
            if pl:find(r:lower()) then return r end
        end
    end
    -- check text labels inside
    for _,d in ipairs(obj:GetDescendants()) do
        if d:IsA("TextLabel") then
            local tl = d.Text:lower()
            for _,r in ipairs(Config.RarityList) do
                if tl:find(r:lower()) then return r end
            end
        end
    end
    return nil
end

local function GetWeight(obj)
    for _,a in ipairs({"Weight","Kilogram","Mass","KG","Kg","weight","kg","mass"}) do
        local v = obj:GetAttribute(a)
        if v then local n=tonumber(v) if n and n>0 then return n end end
    end
    for _,ch in ipairs(obj:GetChildren()) do
        if (ch:IsA("NumberValue") or ch:IsA("IntValue")) then
            local cn = ch.Name:lower()
            if cn:find("weight") or cn:find("kg") or cn:find("mass") then
                return ch.Value
            end
        end
    end
    local nw = obj.Name:match("(%d+)%s*[kK][gG]")
    if nw then return tonumber(nw) or 0 end
    return 0
end

local function GetObjPos(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        local p = obj:FindFirstChildWhichIsA("BasePart")
        if p then return p.Position end
    end
    return nil
end

local function ScanEggs()
    local results = {}
    for _,obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            if LooksLikeEgg(obj) and not IsBadName(obj.Name) then
                if obj:IsA("Model") and IsNPC(obj) then continue end
                if IsPlayer(obj) then continue end

                local rar = GetRarity(obj)
                local pos = GetObjPos(obj)

                if pos and rar and Config.RarityEnabled[rar] then
                    local wt = GetWeight(obj)
                    table.insert(results,{
                        Obj=obj, Rar=rar, Wt=wt, Pos=pos,
                        Pri=Config.RarityPri[rar] or 99,
                        Big=wt>=Config.BigKG,
                        Dist=Dist(pos),
                    })
                end
            end
        end
    end
    return results
end

local function BestEgg(list)
    if #list==0 then return nil end
    table.sort(list, function(a,b)
        if Config.BigMode then
            if a.Big and not b.Big then return true end
            if not a.Big and b.Big then return false end
            if a.Big and b.Big and a.Wt~=b.Wt then return a.Wt>b.Wt end
        end
        if a.Pri~=b.Pri then return a.Pri<b.Pri end
        return a.Dist<b.Dist
    end)
    return list[1]
end

-- =============================================
-- MOVEMENT (Simple & Working)
-- Direct CFrame lerp per frame, NO BodyVelocity
-- =============================================
local function MoveToTarget(targetObj, speed, onArrive)
    -- Stop previous movement
    if State.MoveConn then
        pcall(function() State.MoveConn:Disconnect() end)
        State.MoveConn = nil
    end

    State.MoveConn = RS.RenderStepped:Connect(function(dt)
        local root = GetRoot()
        local hum = GetHum()
        if not root or not hum or not Alive() or not Config.Active then
            if State.MoveConn then State.MoveConn:Disconnect() State.MoveConn=nil end
            return
        end

        -- Get current target position (bisa bergerak)
        local tPos
        if targetObj and targetObj.Parent then
            tPos = GetObjPos(targetObj)
        end
        -- Jika target hilang, pakai SafePos untuk escape
        if not tPos then
            if State.Escaping and Config.SafePos then
                tPos = Config.SafePos
            else
                if State.MoveConn then State.MoveConn:Disconnect() State.MoveConn=nil end
                State.Moving = false
                return
            end
        end

        local myP = root.Position
        local delta = tPos - myP
        local dist = delta.Magnitude

        -- Arrived
        if dist <= Config.GrabDist then
            if State.MoveConn then State.MoveConn:Disconnect() State.MoveConn=nil end
            hum.WalkSpeed = 16
            if onArrive then onArrive() end
            return
        end

        -- Calculate step
        local dir = delta.Unit
        local step = math.min(speed * dt, dist)
        local newPos = myP + dir * step

        -- Keep Y stable (don't fly underground)
        -- Raycast down to find ground
        local rayResult = WS:Raycast(
            Vector3.new(newPos.X, newPos.Y + 10, newPos.Z),
            Vector3.new(0, -50, 0),
            RaycastParams.new()
        )
        local groundY = rayResult and (rayResult.Position.Y + 3) or newPos.Y
        newPos = Vector3.new(newPos.X, math.max(newPos.Y, groundY), newPos.Z)

        -- Apply movement
        local lookDir = Vector3.new(dir.X, 0, dir.Z)
        if lookDir.Magnitude > 0.01 then
            root.CFrame = CFrame.new(newPos, newPos + lookDir)
        else
            root.CFrame = CFrame.new(newPos)
        end

        -- Kill velocity so physics doesn't fight us
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function MoveToPos(pos, speed, onArrive)
    if State.MoveConn then
        pcall(function() State.MoveConn:Disconnect() end)
        State.MoveConn = nil
    end

    local targetProxy = Instance.new("Part")
    targetProxy.Anchored = true
    targetProxy.Position = pos
    targetProxy.Parent = nil -- don't parent, just use for position

    State.MoveConn = RS.RenderStepped:Connect(function(dt)
        local root = GetRoot()
        local hum = GetHum()
        if not root or not hum or not Alive() or not Config.Active then
            if State.MoveConn then State.MoveConn:Disconnect() State.MoveConn=nil end
            return
        end

        local myP = root.Position
        local delta = pos - myP
        local dist = delta.Magnitude

        if dist <= Config.SafeDist then
            if State.MoveConn then State.MoveConn:Disconnect() State.MoveConn=nil end
            hum.WalkSpeed = 16
            if onArrive then onArrive() end
            return
        end

        local dir = delta.Unit
        local step = math.min(speed * dt, dist)
        local newPos = myP + dir * step

        local rayResult = WS:Raycast(
            Vector3.new(newPos.X, newPos.Y + 10, newPos.Z),
            Vector3.new(0, -50, 0),
            RaycastParams.new()
        )
        local groundY = rayResult and (rayResult.Position.Y + 3) or newPos.Y
        newPos = Vector3.new(newPos.X, math.max(newPos.Y, groundY), newPos.Z)

        local lookDir = Vector3.new(dir.X, 0, dir.Z)
        if lookDir.Magnitude > 0.01 then
            root.CFrame = CFrame.new(newPos, newPos + lookDir)
        else
            root.CFrame = CFrame.new(newPos)
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function StopMove()
    if State.MoveConn then
        pcall(function() State.MoveConn:Disconnect() end)
        State.MoveConn = nil
    end
    local hum = GetHum()
    if hum then hum.WalkSpeed = 16 end
end

-- =============================================
-- PICKUP
-- =============================================
local function DoPickup(egg)
    -- ProximityPrompt
    local function findPrompt(obj)
        local p = obj:FindFirstChildOfClass("ProximityPrompt")
        if p then return p end
        for _,d in ipairs(obj:GetDescendants()) do
            if d:IsA("ProximityPrompt") then return d end
        end
        if obj.Parent then
            for _,d in ipairs(obj.Parent:GetDescendants()) do
                if d:IsA("ProximityPrompt") then return d end
            end
        end
        return nil
    end

    local prompt = findPrompt(egg)
    if prompt then
        local oh,od,ol = prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 9999
        prompt.RequiresLineOfSight = false
        prompt.Enabled = true
        pcall(function() fireproximityprompt(prompt,1) end)
        task.delay(0.3, function()
            pcall(function() prompt.HoldDuration=oh prompt.MaxActivationDistance=od prompt.RequiresLineOfSight=ol end)
        end)
        return true
    end

    -- ClickDetector
    local function findClick(obj)
        for _,d in ipairs(obj:GetDescendants()) do
            if d:IsA("ClickDetector") then return d end
        end
        if obj:IsA("BasePart") then
            local cd = obj:FindFirstChildOfClass("ClickDetector")
            if cd then return cd end
        end
        return nil
    end

    local cd = findClick(egg)
    if cd then
        pcall(function() fireclickdetector(cd) end)
        return true
    end

    -- GUI Button
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local kws = {"pickup","grab","take","lift","collect","steal","carry","interact","claim","ambil","angkat"}
        for _,g in ipairs(pg:GetDescendants()) do
            if (g:IsA("TextButton") or g:IsA("ImageButton")) and g.Visible then
                local nl = g.Name:lower()
                local tl = g:IsA("TextButton") and g.Text:lower() or ""
                for _,kw in ipairs(kws) do
                    if nl:find(kw) or tl:find(kw) then
                        pcall(function()
                            if firesignal then
                                firesignal(g.Activated)
                                firesignal(g.MouseButton1Click)
                            end
                        end)
                        return true
                    end
                end
            end
        end
    end

    -- Touch
    pcall(function()
        local root = GetRoot()
        local part = egg:IsA("BasePart") and egg or egg:FindFirstChildWhichIsA("BasePart")
        if root and part and firetouchinterest then
            firetouchinterest(root,part,0)
            task.wait(0.05)
            firetouchinterest(root,part,1)
        end
    end)

    -- Remotes
    pcall(function()
        for _,rem in ipairs(RepS:GetDescendants()) do
            if rem:IsA("RemoteEvent") then
                local rl = rem.Name:lower()
                if rl:find("pick") or rl:find("grab") or rl:find("steal") or rl:find("collect") or rl:find("interact") then
                    rem:FireServer(egg)
                end
            end
        end
    end)

    return true
end

-- =============================================
-- SAFE ZONE
-- =============================================
local function FindSafe()
    local kws = {"safe","spawn","base","home","lobby","hub","camp","start","safezone","nest_base"}
    for _,obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            Config.SafePos = obj.Position
            return
        end
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local nl = obj.Name:lower()
            for _,kw in ipairs(kws) do
                if nl:find(kw) then
                    local p = obj:IsA("BasePart") and obj.Position or GetObjPos(obj)
                    if p then Config.SafePos = p return end
                end
            end
        end
    end
    Config.SafePos = MyPos()
end

-- =============================================
-- ESP (lightweight)
-- =============================================
local function ClearESP()
    for obj,data in pairs(State.Esps) do
        pcall(function() data.BB:Destroy() end)
    end
    State.Esps = {}
end

local function CreateESP(obj, rar, wt)
    if State.Esps[obj] then return end
    local pos = GetObjPos(obj)
    if not pos then return end

    local col = Config.RarityCol[rar] or Color3.fromRGB(255,255,255)
    local big = wt >= Config.BigKG

    local bb = Instance.new("BillboardGui")
    bb.Name = rn(6)
    bb.Size = UDim2.new(0,140,0,40)
    bb.StudsOffset = Vector3.new(0,4,0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 1500

    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(1,0,1,0)
    fr.BackgroundColor3 = Color3.fromRGB(10,10,18)
    fr.BackgroundTransparency = 0.15
    fr.BorderSizePixel = 0
    fr.Parent = bb
    Instance.new("UICorner",fr).CornerRadius = UDim.new(0,5)
    local s = Instance.new("UIStroke")
    s.Color = col s.Thickness = big and 2 or 1 s.Parent = fr

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1,0,0.55,0)
    tl.BackgroundTransparency = 1
    tl.Text = (big and "BIG " or "")..rar:upper()
    tl.TextColor3 = col
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.Parent = fr

    local dl = Instance.new("TextLabel")
    dl.Name = "D"
    dl.Size = UDim2.new(1,0,0.45,0)
    dl.Position = UDim2.new(0,0,0.55,0)
    dl.BackgroundTransparency = 1
    dl.Text = ""
    dl.TextColor3 = Color3.fromRGB(160,160,180)
    dl.TextScaled = true
    dl.Font = Enum.Font.Gotham
    dl.Parent = fr

    local adornee = obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")))
    if adornee then bb.Adornee = adornee end
    bb.Parent = CG

    State.Esps[obj] = {BB=bb, DL=dl, Wt=wt}
end

local function UpdateESP()
    for obj,data in pairs(State.Esps) do
        if obj and obj.Parent then
            local p = GetObjPos(obj)
            if p then
                local d = math.floor(Dist(p))
                data.DL.Text = (data.Wt>0 and (data.Wt.."kg  ") or "")..d.."m"
            end
        else
            pcall(function() data.BB:Destroy() end)
            State.Esps[obj] = nil
        end
    end
end

-- =============================================
-- CONTROLLER
-- =============================================
local function GrabEgg(data)
    if State.Moving or State.HasEgg then return end
    State.Moving = true
    State.Target = data.Obj
    State.TargetRar = data.Rar
    State.TargetKG = data.Wt

    Notify(data.Rar:upper()..(data.Big and " BIG "..data.Wt.."kg" or "").." | Moving",2)

    MoveToTarget(data.Obj, Config.Speed, function()
        -- Arrived at egg
        State.Moving = false
        task.wait(0.02)

        -- Try pickup multiple times
        for i=1,5 do
            DoPickup(data.Obj)
            task.wait(0.06)
        end

        State.HasEgg = true
        Notify(data.Rar:upper().." grabbed | Escaping",2)

        if Config.AutoEsc then
            Escape()
        end
    end)
end

function Escape()
    local sp = Config.SafePos
    if not sp then FindSafe() sp = Config.SafePos end
    if not sp then Notify("No safe zone",2) return end

    State.Escaping = true

    MoveToPos(sp, Config.EscSpeed, function()
        State.Escaping = false
        State.HasEgg = false
        State.Target = nil
        State.TargetRar = nil
        State.TargetKG = 0
        StopMove()
        Notify("Egg delivered. Ready for next.",3)
    end)
end

local function FullStop()
    Config.Active = false
    StopMove()
    State.Moving = false
    State.Escaping = false
    State.HasEgg = false
    State.Target = nil
    State.TargetRar = nil
    State.TargetKG = 0
    DisconnectAll()
    ClearESP()
end

-- =============================================
-- ANTI DROP
-- =============================================
local function SetupAntiDrop()
    local hum = GetHum()
    if not hum then return end
    local c = hum.HealthChanged:Connect(function()
        if State.HasEgg and State.Escaping then
            -- nothing complex, the CFrame movement already ignores knockback
        end
    end)
    table.insert(State.Conns, c)
end

-- =============================================
-- MAIN LOOP (Optimized - scan every 0.5s NOT every frame)
-- =============================================
local function StartLoop()
    Config.Active = true
    FindSafe()
    SetupAntiDrop()
    Notify("Activated. Scanning...",2)

    -- SCAN LOOP - runs every 0.5 seconds, NOT every frame
    State.MainConn = task.spawn(function()
        while Config.Active do
            if Alive() and not State.Moving and not State.Escaping and not State.HasEgg then
                local eggs = ScanEggs()

                -- Update ESP
                if Config.ShowESP then
                    ClearESP()
                    for _,ed in ipairs(eggs) do
                        CreateESP(ed.Obj, ed.Rar, ed.Wt)
                    end
                end

                local best = BestEgg(eggs)
                if best then
                    GrabEgg(best)
                end
            end
            task.wait(0.5)
        end
    end)

    -- ESP distance update - every 1 second
    State.EspConn = task.spawn(function()
        while Config.Active do
            if Config.ShowESP then UpdateESP() end
            task.wait(1)
        end
    end)
end

-- =============================================
-- UI - ANIME/MANGA AESTHETIC
-- Dark theme with sharp accents, manga-style typography
-- =============================================

-- Color Palette (Manga/Anime inspired)
local P = {
    -- Base
    bg       = Color3.fromRGB(10, 10, 16),
    panel    = Color3.fromRGB(16, 16, 26),
    card     = Color3.fromRGB(22, 22, 34),
    cardHi   = Color3.fromRGB(28, 28, 42),

    -- Accents
    accent   = Color3.fromRGB(220, 50, 80),   -- manga red
    accent2  = Color3.fromRGB(180, 40, 65),
    blue     = Color3.fromRGB(60, 130, 255),
    cyan     = Color3.fromRGB(40, 200, 220),
    gold     = Color3.fromRGB(240, 190, 50),

    -- Text
    white    = Color3.fromRGB(235, 235, 245),
    text     = Color3.fromRGB(195, 195, 210),
    dim      = Color3.fromRGB(100, 100, 125),
    dimmer   = Color3.fromRGB(60, 60, 80),

    -- Status
    green    = Color3.fromRGB(50, 185, 80),
    red      = Color3.fromRGB(200, 50, 50),
    orange   = Color3.fromRGB(230, 140, 30),

    -- Lines
    line     = Color3.fromRGB(35, 35, 50),
    lineAcc  = Color3.fromRGB(220, 50, 80),
}

local function BuildUI()
    -- Cleanup
    local old = CG:FindFirstChild(_UI)
    if old then old:Destroy() end

    local vx = workspace.CurrentCamera.ViewportSize.X
    local vy = workspace.CurrentCamera.ViewportSize.Y
    local mobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
    local W = mobile and math.clamp(vx*0.9, 280, 420) or math.clamp(vx*0.22, 310, 400)
    local H = mobile and math.clamp(vy*0.75, 380, 620) or math.clamp(vy*0.72, 420, 650)
    local fs = mobile and 1.15 or 1

    local Screen = Instance.new("ScreenGui")
    Screen.Name = _UI
    Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Screen.ResetOnSpawn = false
    Screen.Parent = CG

    -- Scale
    local uisc = Instance.new("UIScale")
    uisc.Parent = Screen
    local function rescale()
        local x = workspace.CurrentCamera.ViewportSize.X
        uisc.Scale = mobile and math.clamp(x/1080,0.6,1.2) or math.clamp(x/1920,0.55,1.3)
    end
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
    rescale()

    -- Main Frame
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0,W,0,H)
    Main.Position = UDim2.new(0.5,-W/2,0.5,-H/2)
    Main.BackgroundColor3 = P.bg
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.ClipsDescendants = true
    Main.Parent = Screen
    Instance.new("UICorner",Main).CornerRadius = UDim.new(0,8)

    -- Border stroke
    local mStroke = Instance.new("UIStroke")
    mStroke.Color = P.accent
    mStroke.Thickness = 1.5
    mStroke.Transparency = 0.4
    mStroke.Parent = Main

    -- Top accent bar (manga style - sharp red line)
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1,0,0,3)
    topBar.BackgroundColor3 = P.accent
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 10
    topBar.Parent = Main

    -- Title section
    local titleH = 44
    local titleBg = Instance.new("Frame")
    titleBg.Size = UDim2.new(1,0,0,titleH)
    titleBg.Position = UDim2.new(0,0,0,3)
    titleBg.BackgroundColor3 = P.panel
    titleBg.BorderSizePixel = 0
    titleBg.Parent = Main

    -- Title text - manga style
    local titleMain = Instance.new("TextLabel")
    titleMain.Size = UDim2.new(0,120,0,20)
    titleMain.Position = UDim2.new(0,14,0,6)
    titleMain.BackgroundTransparency = 1
    titleMain.Text = "SYN-STUDIO"
    titleMain.TextColor3 = P.accent
    titleMain.TextSize = 16*fs
    titleMain.Font = Enum.Font.GothamBlack
    titleMain.TextXAlignment = Enum.TextXAlignment.Left
    titleMain.Parent = titleBg

    local titleSub = Instance.new("TextLabel")
    titleSub.Size = UDim2.new(0,100,0,12)
    titleSub.Position = UDim2.new(0,14,0,27)
    titleSub.BackgroundTransparency = 1
    titleSub.Text = "EGG STEALER v5"
    titleSub.TextColor3 = P.dim
    titleSub.TextSize = 8*fs
    titleSub.Font = Enum.Font.GothamBold
    titleSub.TextXAlignment = Enum.TextXAlignment.Left
    titleSub.Parent = titleBg

    -- Red kanji-style decoration
    local deco = Instance.new("TextLabel")
    deco.Size = UDim2.new(0,20,0,20)
    deco.Position = UDim2.new(0,138,0,7)
    deco.BackgroundTransparency = 1
    deco.Text = "/"
    deco.TextColor3 = P.accent
    deco.TextSize = 14
    deco.Font = Enum.Font.GothamBlack
    deco.Rotation = 15
    deco.Parent = titleBg

    -- Buttons
    local bsz = 28
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0,bsz,0,bsz)
    closeBtn.Position = UDim2.new(1,-(bsz+8),0.5,-bsz/2)
    closeBtn.BackgroundColor3 = P.red
    closeBtn.Text = "x"
    closeBtn.TextColor3 = P.white
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBg
    Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,6)
    closeBtn.MouseButton1Click:Connect(function() FullStop() Screen:Destroy() end)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0,bsz,0,bsz)
    minBtn.Position = UDim2.new(1,-(bsz*2+16),0.5,-bsz/2)
    minBtn.BackgroundColor3 = P.card
    minBtn.Text = "--"
    minBtn.TextColor3 = P.dim
    minBtn.TextSize = 10
    minBtn.Font = Enum.Font.GothamBold
    minBtn.BorderSizePixel = 0
    minBtn.Parent = titleBg
    Instance.new("UICorner",minBtn).CornerRadius = UDim.new(0,6)

    -- Separator
    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1,-20,0,1)
    sep1.Position = UDim2.new(0,10,0,titleH+3)
    sep1.BackgroundColor3 = P.line
    sep1.BorderSizePixel = 0
    sep1.Parent = Main

    -- Content
    local contentTop = titleH + 8
    local Content = Instance.new("ScrollingFrame")
    Content.Size = UDim2.new(1,-12,1,-(contentTop+6))
    Content.Position = UDim2.new(0,6,0,contentTop)
    Content.BackgroundTransparency = 1
    Content.BorderSizePixel = 0
    Content.ScrollBarThickness = 2
    Content.ScrollBarImageColor3 = P.accent
    Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Content.CanvasSize = UDim2.new(0,0,0,0)
    Content.Parent = Main

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0,3)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = Content

    Instance.new("UIPadding",Content).PaddingBottom = UDim.new(0,16)

    -- Minimize
    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Content.Visible = not minimized
        sep1.Visible = not minimized
        Main.Size = minimized and UDim2.new(0,W,0,titleH+6) or UDim2.new(0,W,0,H)
        minBtn.Text = minimized and "+" or "--"
    end)

    -- ORDER
    local _o = 0
    local function no() _o=_o+1 return _o end

    -- ====== COMPONENTS ======

    local function MkSep(text)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1,0,0,22)
        f.BackgroundTransparency = 1
        f.LayoutOrder = no()
        f.Parent = Content

        -- Left red bar
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0,3,0,12)
        bar.Position = UDim2.new(0,2,0.5,-6)
        bar.BackgroundColor3 = P.accent
        bar.BorderSizePixel = 0
        bar.Parent = f

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,-12,1,0)
        l.Position = UDim2.new(0,10,0,0)
        l.BackgroundTransparency = 1
        l.Text = text:upper()
        l.TextColor3 = P.dim
        l.TextSize = 9*fs
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = f
    end

    local function MkToggle(text, default, cb, dotCol)
        local h = 30
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1,0,0,h)
        f.BackgroundColor3 = P.card
        f.BorderSizePixel = 0
        f.LayoutOrder = no()
        f.Parent = Content
        Instance.new("UICorner",f).CornerRadius = UDim.new(0,5)

        local lx = 8
        if dotCol then
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0,6,0,6)
            dot.Position = UDim2.new(0,8,0.5,-3)
            dot.BackgroundColor3 = dotCol
            dot.BorderSizePixel = 0
            dot.Parent = f
            Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)
            lx = 20
        end

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,-60,1,0)
        l.Position = UDim2.new(0,lx,0,0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = dotCol or P.text
        l.TextSize = 10*fs
        l.Font = dotCol and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Parent = f

        -- Switch track
        local tw,th = 34,16
        local track = Instance.new("TextButton")
        track.Size = UDim2.new(0,tw,0,th)
        track.Position = UDim2.new(1,-(tw+6),0.5,-th/2)
        track.BorderSizePixel = 0
        track.Text = ""
        track.AutoButtonColor = false
        track.Parent = f
        Instance.new("UICorner",track).CornerRadius = UDim.new(1,0)

        local ksz = th-4
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0,ksz,0,ksz)
        knob.BackgroundColor3 = P.white
        knob.BorderSizePixel = 0
        knob.Parent = track
        Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

        local on = default
        local function upd(anim)
            local d = anim and 0.12 or 0
            if on then
                TS:Create(track,TweenInfo.new(d),{BackgroundColor3=P.green}):Play()
                TS:Create(knob,TweenInfo.new(d),{Position=UDim2.new(1,-(ksz+2),0.5,-ksz/2)}):Play()
            else
                TS:Create(track,TweenInfo.new(d),{BackgroundColor3=P.dimmer}):Play()
                TS:Create(knob,TweenInfo.new(d),{Position=UDim2.new(0,2,0.5,-ksz/2)}):Play()
            end
        end
        upd(false)

        track.MouseButton1Click:Connect(function()
            on = not on
            upd(true)
            if cb then cb(on) end
        end)

        -- Hover
        f.MouseEnter:Connect(function()
            TS:Create(f,TweenInfo.new(0.1),{BackgroundColor3=P.cardHi}):Play()
        end)
        f.MouseLeave:Connect(function()
            TS:Create(f,TweenInfo.new(0.1),{BackgroundColor3=P.card}):Play()
        end)

        return f
    end

    local function MkSlider(text, mn, mx, def, cb)
        local h = 40
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1,0,0,h)
        f.BackgroundColor3 = P.card
        f.BorderSizePixel = 0
        f.LayoutOrder = no()
        f.Parent = Content
        Instance.new("UICorner",f).CornerRadius = UDim.new(0,5)

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.55,0,0,18)
        l.Position = UDim2.new(0,8,0,2)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = P.text
        l.TextSize = 9*fs
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = f

        local vl = Instance.new("TextLabel")
        vl.Size = UDim2.new(0.4,0,0,18)
        vl.Position = UDim2.new(0.58,0,0,2)
        vl.BackgroundTransparency = 1
        vl.Text = tostring(def)
        vl.TextColor3 = P.accent
        vl.TextSize = 10*fs
        vl.Font = Enum.Font.GothamBold
        vl.TextXAlignment = Enum.TextXAlignment.Right
        vl.Parent = f

        local bH = 4
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1,-16,0,bH)
        bg.Position = UDim2.new(0,8,0,28)
        bg.BackgroundColor3 = P.dimmer
        bg.BorderSizePixel = 0
        bg.Parent = f
        Instance.new("UICorner",bg).CornerRadius = UDim.new(1,0)

        local ia = math.clamp((def-mn)/(mx-mn),0,1)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(ia,0,1,0)
        fill.BackgroundColor3 = P.accent
        fill.BorderSizePixel = 0
        fill.Parent = bg
        Instance.new("UICorner",fill).CornerRadius = UDim.new(1,0)

        local ksz = 12
        local knob = Instance.new("TextButton")
        knob.Size = UDim2.new(0,ksz,0,ksz)
        knob.Position = UDim2.new(ia,-ksz/2,0.5,-ksz/2)
        knob.BackgroundColor3 = P.white
        knob.Text = ""
        knob.BorderSizePixel = 0
        knob.ZIndex = 3
        knob.AutoButtonColor = false
        knob.Parent = bg
        Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

        local drag = false

        local function setA(a)
            a = math.clamp(a,0,1)
            fill.Size = UDim2.new(a,0,1,0)
            knob.Position = UDim2.new(a,-ksz/2,0.5,-ksz/2)
            local val = math.floor(mn + (mx-mn)*a)
            vl.Text = tostring(val)
            if cb then cb(val) end
        end

        local function handle(pos)
            local ap = bg.AbsolutePosition
            local as = bg.AbsoluteSize
            setA((pos.X - ap.X) / as.X)
        end

        knob.MouseButton1Down:Connect(function() drag=true end)
        bg.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
                handle(i.Position) drag=true
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
                handle(i.Position)
            end
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
                drag=false
            end
        end)

        return f
    end

    local function MkBtn(text, col, cb)
        local h = 32
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1,0,0,h)
        b.BackgroundColor3 = col
        b.Text = text
        b.TextColor3 = P.white
        b.TextSize = 11*fs
        b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.LayoutOrder = no()
        b.Parent = Content
        Instance.new("UICorner",b).CornerRadius = UDim.new(0,5)

        local oc = col
        b.MouseEnter:Connect(function()
            TS:Create(b,TweenInfo.new(0.1),{BackgroundColor3=Color3.new(math.min(col.R*1.25,1),math.min(col.G*1.25,1),math.min(col.B*1.25,1))}):Play()
        end)
        b.MouseLeave:Connect(function()
            TS:Create(b,TweenInfo.new(0.1),{BackgroundColor3=oc}):Play()
        end)
        b.MouseButton1Click:Connect(function()
            TS:Create(b,TweenInfo.new(0.04),{BackgroundColor3=P.white}):Play()
            task.wait(0.04)
            TS:Create(b,TweenInfo.new(0.08),{BackgroundColor3=oc}):Play()
            if cb then cb(b) end
        end)

        return b
    end

    -- ====== STATUS ======
    local stH = 40
    local stF = Instance.new("Frame")
    stF.Size = UDim2.new(1,0,0,stH)
    stF.BackgroundColor3 = Color3.fromRGB(14,18,14)
    stF.BorderSizePixel = 0
    stF.LayoutOrder = no()
    stF.Parent = Content
    Instance.new("UICorner",stF).CornerRadius = UDim.new(0,5)

    -- Left accent bar on status
    local stBar = Instance.new("Frame")
    stBar.Size = UDim2.new(0,2,0.7,0)
    stBar.Position = UDim2.new(0,4,0.15,0)
    stBar.BackgroundColor3 = P.green
    stBar.BorderSizePixel = 0
    stBar.Parent = stF

    local stLbl = Instance.new("TextLabel")
    stLbl.Size = UDim2.new(1,-16,1,0)
    stLbl.Position = UDim2.new(0,12,0,0)
    stLbl.BackgroundTransparency = 1
    stLbl.Text = "IDLE"
    stLbl.TextColor3 = Color3.fromRGB(130,210,130)
    stLbl.TextSize = 9*fs
    stLbl.Font = Enum.Font.Gotham
    stLbl.TextXAlignment = Enum.TextXAlignment.Left
    stLbl.TextWrapped = true
    stLbl.Parent = stF

    -- ====== BUILD SECTIONS ======
    MkSep("Controls")

    local running = false
    MkBtn("START", P.green, function(btn)
        running = not running
        if running then
            btn.BackgroundColor3 = P.red
            btn.Text = "STOP"
            StartLoop()
        else
            btn.BackgroundColor3 = P.green
            btn.Text = "START"
            FullStop()
        end
    end)

    MkBtn("Set Safe Zone Here", P.accent2, function()
        Config.SafePos = MyPos()
        Notify("Safe zone saved",2)
    end)

    MkSep("Features")
    MkToggle("Instant Steal", true, function(v) Config.InstantSteal=v end)
    MkToggle("Auto Escape", Config.AutoEsc, function(v) Config.AutoEsc=v end)
    MkToggle("Big Egg Priority", Config.BigMode, function(v) Config.BigMode=v end)
    MkToggle("Anti-Drop", Config.AntiDrop, function(v) Config.AntiDrop=v end)
    MkToggle("Show ESP", Config.ShowESP, function(v)
        Config.ShowESP=v
        if not v then ClearESP() end
    end)

    MkSep("Speed")
    MkSlider("Move Speed", 60, 400, Config.Speed, function(v) Config.Speed=v end)
    MkSlider("Escape Speed", 60, 500, Config.EscSpeed, function(v) Config.EscSpeed=v end)
    MkSlider("Big Egg KG", 100, 5000, Config.BigKG, function(v) Config.BigKG=v end)
    MkSlider("Grab Distance", 5, 30, Config.GrabDist, function(v) Config.GrabDist=v end)

    MkSep("Rarity Filter")

    for _,r in ipairs(Config.RarityList) do
        MkToggle(r, Config.RarityEnabled[r], function(v)
            Config.RarityEnabled[r] = v
        end, Config.RarityCol[r])
    end

    -- All on / All off
    local selF = Instance.new("Frame")
    selF.Size = UDim2.new(1,0,0,26)
    selF.BackgroundTransparency = 1
    selF.LayoutOrder = no()
    selF.Parent = Content

    local function mkSmallBtn(txt, col, pos, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.48,0,1,0)
        b.Position = pos
        b.BackgroundColor3 = col
        b.Text = txt
        b.TextColor3 = P.text
        b.TextSize = 9*fs
        b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        b.Parent = selF
        Instance.new("UICorner",b).CornerRadius = UDim.new(0,4)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    mkSmallBtn("All On", Color3.fromRGB(30,70,35), UDim2.new(0,0,0,0), function()
        for _,r in ipairs(Config.RarityList) do Config.RarityEnabled[r]=true end
        Screen:Destroy() BuildUI()
    end)
    mkSmallBtn("All Off", Color3.fromRGB(70,30,30), UDim2.new(0.52,0,0,0), function()
        for _,r in ipairs(Config.RarityList) do Config.RarityEnabled[r]=false end
        Screen:Destroy() BuildUI()
    end)

    MkSep("Hotkeys")

    local infoF = Instance.new("Frame")
    infoF.Size = UDim2.new(1,0,0,48)
    infoF.BackgroundColor3 = P.card
    infoF.BorderSizePixel = 0
    infoF.LayoutOrder = no()
    infoF.Parent = Content
    Instance.new("UICorner",infoF).CornerRadius = UDim.new(0,5)

    local infoL = Instance.new("TextLabel")
    infoL.Size = UDim2.new(1,-12,1,0)
    infoL.Position = UDim2.new(0,6,0,0)
    infoL.BackgroundTransparency = 1
    infoL.RichText = true
    infoL.Text = '<font color="#DC3250">RightShift</font>  Toggle UI\n<font color="#DC3250">F5</font>  Start / Stop\n<font color="#DC3250">F6</font>  Toggle ESP     <font color="#DC3250">F7</font>  Set Safe Zone'
    infoL.TextColor3 = P.dim
    infoL.TextSize = 8*fs
    infoL.Font = Enum.Font.Gotham
    infoL.TextXAlignment = Enum.TextXAlignment.Left
    infoL.TextYAlignment = Enum.TextYAlignment.Center
    infoL.Parent = infoF

    -- MOBILE TOGGLE
    if mobile then
        local mb = Instance.new("TextButton")
        mb.Size = UDim2.new(0,42,0,42)
        mb.Position = UDim2.new(0,6,0.5,-21)
        mb.BackgroundColor3 = P.accent
        mb.BackgroundTransparency = 0.15
        mb.Text = "S"
        mb.TextSize = 16
        mb.Font = Enum.Font.GothamBlack
        mb.TextColor3 = P.white
        mb.BorderSizePixel = 0
        mb.Draggable = true
        mb.Parent = Screen
        Instance.new("UICorner",mb).CornerRadius = UDim.new(1,0)
        mb.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)
    end

    -- STATUS UPDATE
    task.spawn(function()
        while Screen and Screen.Parent do
            local txt = ""
            local barCol = P.dim

            if Config.Active then
                if State.Moving then
                    txt = "MOVING TO TARGET"
                    barCol = P.orange
                elseif State.Escaping then
                    txt = "ESCAPING"
                    barCol = P.cyan
                elseif State.HasEgg then
                    txt = "CARRYING"
                    barCol = P.blue
                else
                    txt = "SCANNING"
                    barCol = P.green
                end
            else
                txt = "IDLE"
                barCol = P.dim
            end

            if State.Target and State.TargetRar then
                local bt = State.TargetKG >= Config.BigKG and ("  BIG "..State.TargetKG.."kg") or ""
                txt = txt .. "  //  " .. State.TargetRar:upper() .. bt
            end

            pcall(function()
                stLbl.Text = txt
                stBar.BackgroundColor3 = barCol
            end)

            task.wait(0.25)
        end
    end)

    -- UI TOGGLE KEY
    UIS.InputBegan:Connect(function(i,g)
        if g then return end
        if i.KeyCode == Enum.KeyCode.RightShift then
            Main.Visible = not Main.Visible
        end
    end)

    return Screen
end

-- =============================================
-- HOTKEYS
-- =============================================
UIS.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.F5 then
        Config.Active = not Config.Active
        if Config.Active then StartLoop() Notify("Started",1)
        else FullStop() Notify("Stopped",1) end
    end
    if i.KeyCode == Enum.KeyCode.F6 then
        Config.ShowESP = not Config.ShowESP
        if not Config.ShowESP then ClearESP() end
        Notify("ESP "..(Config.ShowESP and "on" or "off"),1)
    end
    if i.KeyCode == Enum.KeyCode.F7 then
        Config.SafePos = MyPos()
        Notify("Safe zone set",1)
    end
end)

-- =============================================
-- RESPAWN
-- =============================================
LP.CharacterAdded:Connect(function()
    task.wait(1)
    State.Moving=false State.Escaping=false State.HasEgg=false State.Target=nil
    StopMove()
end)

-- =============================================
-- INIT
-- =============================================
BuildUI()
Notify("SYN-STUDIO v5 loaded",3)
