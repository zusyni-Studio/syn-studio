--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║                      SYN-STUDIO v2.0                        ║
    ║            Advanced Egg Stealer & Auto Collector             ║
    ║                                                              ║
    ║  Features:                                                   ║
    ║  - Ultra Fast Egg Grab (Non-Teleport Dash)                  ║
    ║  - Rarity Selection Filter                                   ║
    ║  - Instant Steal (Auto Press Pickup Button)                  ║
    ║  - Big Egg Priority (>1000kg)                                ║
    ║  - Auto Escape to Safe Zone                                  ║
    ║  - Anti-Drop Protection                                      ║
    ║  - One Egg Per Trip System                                   ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- CONFIGURATION
-- ============================================================
local Config = {
    -- Rarity Settings (true = akan diambil, false = diabaikan)
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

    -- Rarity Priority (semakin kecil angka = semakin prioritas)
    RarityPriority = {
        Ethernal = 1,
        Devine = 2,
        Cosmic = 3,
        Secret = 4,
        Legend = 5,
        Mistic = 6,
        Rare = 7,
        Epic = 8,
        Uncommon = 9,
        Common = 10,
    },

    -- Rarity Colors untuk UI
    RarityColors = {
        Ethernal = Color3.fromRGB(255, 0, 255),
        Devine = Color3.fromRGB(255, 215, 0),
        Cosmic = Color3.fromRGB(0, 255, 255),
        Secret = Color3.fromRGB(255, 0, 0),
        Legend = Color3.fromRGB(255, 165, 0),
        Mistic = Color3.fromRGB(148, 0, 211),
        Rare = Color3.fromRGB(0, 100, 255),
        Epic = Color3.fromRGB(163, 53, 238),
        Uncommon = Color3.fromRGB(0, 255, 0),
        Common = Color3.fromRGB(200, 200, 200),
    },

    -- Movement Settings
    DashSpeed = 250,              -- Kecepatan dash menuju egg
    EscapeSpeed = 300,            -- Kecepatan kabur ke safe zone
    NormalSpeed = 16,             -- Kecepatan normal
    DashStepSize = 3,             -- Ukuran step per frame (smooth movement)

    -- Big Egg Settings
    BigEggThreshold = 1000,       -- Berat minimum untuk "Big Egg" (kg)
    BigEggPriority = true,        -- Prioritaskan Big Egg

    -- System Settings
    ScanRadius = 5000,            -- Radius scan untuk egg
    PickupRange = 10,             -- Jarak untuk pickup egg
    SafeZoneRange = 15,           -- Jarak dianggap sudah di safe zone
    AutoPickupDelay = 0.05,       -- Delay sebelum auto pickup (detik)
    ScanInterval = 0.1,           -- Interval scan egg (detik)

    -- Safe Zone Position (sesuaikan dengan game)
    SafeZonePosition = nil,       -- Akan di-detect otomatis atau set manual

    -- Toggle
    Enabled = false,
    InstantSteal = true,
    AutoEscape = true,
    BigEggMode = true,
    AntiDrop = true,
    ShowESP = true,
}

-- ============================================================
-- STATE MANAGEMENT
-- ============================================================
local State = {
    IsGrabbing = false,
    IsEscaping = false,
    IsCarrying = false,
    CurrentTarget = nil,
    CurrentTargetRarity = nil,
    CurrentTargetWeight = 0,
    HasEgg = false,
    TripComplete = false,
    Connection = {},
    ESPObjects = {},
    DashTween = nil,
}

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
local Utility = {}

function Utility:GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

function Utility:GetHumanoid()
    local char = self:GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

function Utility:GetRootPart()
    local char = self:GetCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

function Utility:GetPosition()
    local root = self:GetRootPart()
    return root and root.Position or Vector3.new(0, 0, 0)
end

function Utility:DistanceTo(position)
    return (self:GetPosition() - position).Magnitude
end

function Utility:Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "SYN-STUDIO",
            Text = text or "",
            Duration = duration or 3,
        })
    end)
    print("[SYN-STUDIO] " .. (text or ""))
end

function Utility:IsAlive()
    local humanoid = self:GetHumanoid()
    return humanoid and humanoid.Health > 0
end

-- ============================================================
-- SAFE ZONE DETECTOR
-- ============================================================
local SafeZone = {}

function SafeZone:FindSafeZone()
    -- Coba cari safe zone di workspace
    local possibleNames = {
        "SafeZone", "Safe Zone", "SafeArea", "Safe_Zone",
        "Safezone", "Base", "Spawn", "SpawnArea",
        "Home", "HomeBase", "safe_zone", "safezone",
        "Lobby", "Hub", "StartArea", "NestBase",
        "PlayerBase", "BaseZone", "SafeRegion"
    }

    -- Search in Workspace
    for _, name in ipairs(possibleNames) do
        local found = Workspace:FindFirstChild(name, true)
        if found then
            if found:IsA("BasePart") then
                Config.SafeZonePosition = found.Position
                Utility:Notify("Safe Zone", "Found: " .. name, 3)
                return found.Position
            elseif found:IsA("Model") then
                local primary = found.PrimaryPart or found:FindFirstChildWhichIsA("BasePart")
                if primary then
                    Config.SafeZonePosition = primary.Position
                    Utility:Notify("Safe Zone", "Found: " .. name, 3)
                    return primary.Position
                end
            end
        end
    end

    -- Cari berdasarkan Zone/Region folder
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local nameLower = obj.Name:lower()
            if nameLower:find("safe") or nameLower:find("spawn") or nameLower:find("base") then
                Config.SafeZonePosition = obj.Position
                Utility:Notify("Safe Zone", "Auto-detected: " .. obj.Name, 3)
                return obj.Position
            end
        end
    end

    -- Fallback: gunakan spawn point
    local spawnPoints = Workspace:FindFirstChildOfClass("SpawnLocation")
    if spawnPoints then
        Config.SafeZonePosition = spawnPoints.Position
        Utility:Notify("Safe Zone", "Using SpawnLocation", 3)
        return spawnPoints.Position
    end

    -- Ultimate fallback: posisi awal player
    Config.SafeZonePosition = Utility:GetPosition()
    Utility:Notify("Safe Zone", "Using current position as safe zone", 3)
    return Config.SafeZonePosition
end

function SafeZone:GetPosition()
    if not Config.SafeZonePosition then
        self:FindSafeZone()
    end
    return Config.SafeZonePosition
end

function SafeZone:IsInSafeZone()
    local safePos = self:GetPosition()
    if not safePos then return false end
    return Utility:DistanceTo(safePos) <= Config.SafeZoneRange
end

-- ============================================================
-- EGG SCANNER
-- ============================================================
local EggScanner = {}

function EggScanner:GetEggRarity(egg)
    -- Cek berbagai cara untuk menentukan rarity
    local rarityNames = {
        "Ethernal", "Devine", "Cosmic", "Secret",
        "Legend", "Mistic", "Rare", "Epic",
        "Uncommon", "Common"
    }

    -- Cek nama egg
    local eggName = egg.Name:lower()
    for _, rarity in ipairs(rarityNames) do
        if eggName:find(rarity:lower()) then
            return rarity
        end
    end

    -- Cek attributes
    for _, rarity in ipairs(rarityNames) do
        if egg:GetAttribute("Rarity") then
            local attr = tostring(egg:GetAttribute("Rarity")):lower()
            if attr:find(rarity:lower()) then
                return rarity
            end
        end
    end

    -- Cek children (StringValue, etc.)
    for _, child in ipairs(egg:GetChildren()) do
        if child:IsA("StringValue") and (child.Name == "Rarity" or child.Name == "Type" or child.Name == "Tier") then
            local val = child.Value:lower()
            for _, rarity in ipairs(rarityNames) do
                if val:find(rarity:lower()) then
                    return rarity
                end
            end
        end
    end

    -- Cek BillboardGui / TextLabel di dalam egg
    for _, desc in ipairs(egg:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local text = desc.Text:lower()
            for _, rarity in ipairs(rarityNames) do
                if text:find(rarity:lower()) then
                    return rarity
                end
            end
        end
    end

    -- Cek parent folder/model name
    if egg.Parent then
        local parentName = egg.Parent.Name:lower()
        for _, rarity in ipairs(rarityNames) do
            if parentName:find(rarity:lower()) then
                return rarity
            end
        end
    end

    return nil
end

function EggScanner:GetEggWeight(egg)
    -- Cek weight/kilogram dari egg
    local weight = 0

    -- Cek attribute
    if egg:GetAttribute("Weight") then
        weight = tonumber(egg:GetAttribute("Weight")) or 0
    elseif egg:GetAttribute("Kilogram") then
        weight = tonumber(egg:GetAttribute("Kilogram")) or 0
    elseif egg:GetAttribute("Mass") then
        weight = tonumber(egg:GetAttribute("Mass")) or 0
    elseif egg:GetAttribute("KG") then
        weight = tonumber(egg:GetAttribute("KG")) or 0
    end

    -- Cek children values
    for _, child in ipairs(egg:GetChildren()) do
        if child:IsA("NumberValue") or child:IsA("IntValue") then
            local nameLower = child.Name:lower()
            if nameLower:find("weight") or nameLower:find("kg") or nameLower:find("mass") or nameLower:find("kilogram") then
                weight = child.Value
                break
            end
        end
        if child:IsA("StringValue") then
            local nameLower = child.Name:lower()
            if nameLower:find("weight") or nameLower:find("kg") or nameLower:find("mass") then
                weight = tonumber(child.Value) or 0
                break
            end
        end
    end

    -- Cek dari nama egg
    local nameWeight = egg.Name:match("(%d+)%s*[kK][gG]")
    if nameWeight and weight == 0 then
        weight = tonumber(nameWeight) or 0
    end

    -- Cek dari descendants text
    if weight == 0 then
        for _, desc in ipairs(egg:GetDescendants()) do
            if desc:IsA("TextLabel") then
                local textWeight = desc.Text:match("(%d+)%s*[kK][gG]")
                if textWeight then
                    weight = tonumber(textWeight) or 0
                    break
                end
            end
        end
    end

    return weight
end

function EggScanner:IsEgg(obj)
    local nameLower = obj.Name:lower()
    local eggKeywords = {"egg", "telur", "nest", "hatch", "ovum"}

    for _, keyword in ipairs(eggKeywords) do
        if nameLower:find(keyword) then
            return true
        end
    end

    -- Cek attribute
    if obj:GetAttribute("IsEgg") or obj:GetAttribute("Egg") then
        return true
    end

    -- Cek tag
    if obj:IsA("BasePart") or obj:IsA("Model") then
        for _, child in ipairs(obj:GetChildren()) do
            if child.Name:lower():find("egg") then
                return true
            end
        end
    end

    return false
end

function EggScanner:GetEggPosition(egg)
    if egg:IsA("BasePart") then
        return egg.Position
    elseif egg:IsA("Model") then
        local primary = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
        if primary then
            return primary.Position
        end
    end
    return nil
end

function EggScanner:ScanAllEggs()
    local eggs = {}

    -- Scan semua descendants di workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and self:IsEgg(obj) then
            local rarity = self:GetEggRarity(obj)
            local weight = self:GetEggWeight(obj)
            local position = self:GetEggPosition(obj)

            if position and rarity then
                -- Cek apakah rarity ini di-enable
                if Config.Rarities[rarity] then
                    table.insert(eggs, {
                        Object = obj,
                        Rarity = rarity,
                        Weight = weight,
                        Position = position,
                        Priority = Config.RarityPriority[rarity] or 99,
                        IsBigEgg = weight >= Config.BigEggThreshold,
                        Distance = Utility:DistanceTo(position),
                    })
                end
            end
        end
    end

    return eggs
end

function EggScanner:GetBestTarget(eggs)
    if #eggs == 0 then return nil end

    -- Sort berdasarkan priority
    table.sort(eggs, function(a, b)
        -- Big Egg priority jika enabled
        if Config.BigEggMode and Config.BigEggPriority then
            if a.IsBigEgg and not b.IsBigEgg then return true end
            if not a.IsBigEgg and b.IsBigEgg then return false end
            -- Jika dua-duanya big egg, bandingkan weight (lebih berat lebih prioritas)
            if a.IsBigEgg and b.IsBigEgg then
                if a.Weight ~= b.Weight then
                    return a.Weight > b.Weight
                end
            end
        end

        -- Bandingkan rarity priority
        if a.Priority ~= b.Priority then
            return a.Priority < b.Priority
        end

        -- Jika sama, pilih yang lebih dekat
        return a.Distance < b.Distance
    end)

    return eggs[1]
end

-- ============================================================
-- MOVEMENT SYSTEM (Non-Teleport Dash)
-- ============================================================
local Movement = {}

function Movement:DashTo(targetPosition, speed, callback)
    local rootPart = Utility:GetRootPart()
    if not rootPart then return end

    local humanoid = Utility:GetHumanoid()
    if not humanoid then return end

    -- Cancel previous dash
    if State.DashTween then
        State.DashTween:Cancel()
        State.DashTween = nil
    end

    local startPos = rootPart.Position
    local direction = (targetPosition - startPos)
    local distance = direction.Magnitude

    if distance < 1 then
        if callback then callback() end
        return
    end

    -- Hitung durasi berdasarkan speed
    local duration = distance / (speed or Config.DashSpeed)
    duration = math.max(duration, 0.05) -- Minimum duration

    -- Set walkspeed sangat tinggi untuk smooth movement
    local originalSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 0 -- Disable manual movement during dash

    -- Gunakan CFrame lerp untuk movement yang smooth (bukan teleport)
    local startCFrame = rootPart.CFrame
    local targetCFrame = CFrame.new(targetPosition.X, targetPosition.Y, targetPosition.Z)

    -- Pastikan Y position reasonable
    local targetY = math.max(targetPosition.Y, startPos.Y - 5)
    targetCFrame = CFrame.new(targetPosition.X, targetY, targetPosition.Z)

    -- Create smooth dash menggunakan RenderStepped
    local elapsed = 0
    local dashConnection

    dashConnection = RunService.RenderStepped:Connect(function(dt)
        if not Utility:IsAlive() or not State.IsGrabbing and not State.IsEscaping then
            if dashConnection then dashConnection:Disconnect() end
            humanoid.WalkSpeed = originalSpeed
            return
        end

        elapsed = elapsed + dt
        local alpha = math.min(elapsed / duration, 1)

        -- Easing function untuk smooth movement (ease out quad)
        local easedAlpha = 1 - (1 - alpha) ^ 2

        -- Lerp position
        local currentPos = startPos:Lerp(targetCFrame.Position, easedAlpha)

        -- Buat karakter menghadap arah gerakan
        local lookDirection = (targetCFrame.Position - startPos).Unit
        local lookCFrame = CFrame.new(currentPos, currentPos + lookDirection)

        rootPart.CFrame = lookCFrame
        rootPart.Velocity = Vector3.new(0, 0, 0) -- Prevent physics interference
        rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

        if alpha >= 1 then
            if dashConnection then dashConnection:Disconnect() end
            humanoid.WalkSpeed = originalSpeed
            if callback then callback() end
        end
    end)

    -- Store connection for cleanup
    table.insert(State.Connection, dashConnection)
end

function Movement:SmoothDashTo(targetPosition, speed)
    return coroutine.wrap(function()
        local rootPart = Utility:GetRootPart()
        if not rootPart then return end

        local humanoid = Utility:GetHumanoid()
        if not humanoid then return end

        local originalSpeed = humanoid.WalkSpeed

        while Utility:DistanceTo(targetPosition) > Config.PickupRange do
            if not Utility:IsAlive() then break end
            if not State.IsGrabbing and not State.IsEscaping then break end

            local currentPos = rootPart.Position
            local direction = (targetPosition - currentPos).Unit
            local stepSize = Config.DashStepSize
            local newPos = currentPos + direction * stepSize

            -- Smooth CFrame movement (geser, bukan teleport)
            rootPart.CFrame = CFrame.new(newPos, newPos + direction)
            rootPart.Velocity = direction * (speed or Config.DashSpeed)
            rootPart.AssemblyLinearVelocity = direction * (speed or Config.DashSpeed)

            humanoid.WalkSpeed = speed or Config.DashSpeed

            RunService.RenderStepped:Wait()
        end

        humanoid.WalkSpeed = originalSpeed
    end)()
end

-- ============================================================
-- INSTANT STEAL SYSTEM
-- ============================================================
local InstantSteal = {}

function InstantSteal:FindPickupButton()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    -- Cari tombol pickup di semua ScreenGui
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local nameLower = gui.Name:lower()
            local textLower = ""
            if gui:IsA("TextButton") then
                textLower = gui.Text:lower()
            end

            local pickupKeywords = {
                "pickup", "pick up", "grab", "take", "ambil",
                "angkat", "lift", "collect", "steal", "carry",
                "hold", "snatch", "claim", "interact", "e"
            }

            for _, keyword in ipairs(pickupKeywords) do
                if nameLower:find(keyword) or textLower:find(keyword) then
                    return gui
                end
            end
        end
    end

    return nil
end

function InstantSteal:FindProximityPrompt(egg)
    -- Cari ProximityPrompt di egg atau sekitarnya
    if not egg then return nil end

    -- Cek di egg itu sendiri
    local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
    if prompt then return prompt end

    -- Cek di descendants
    for _, desc in ipairs(egg:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            return desc
        end
    end

    -- Cek di parent
    if egg.Parent then
        prompt = egg.Parent:FindFirstChildOfClass("ProximityPrompt")
        if prompt then return prompt end
    end

    return nil
end

function InstantSteal:TriggerPickup(egg)
    -- Method 1: ProximityPrompt
    local prompt = self:FindProximityPrompt(egg)
    if prompt then
        -- Force trigger prompt
        local holdDuration = prompt.HoldDuration
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 9999

        fireproximityprompt(prompt)

        task.delay(0.5, function()
            prompt.HoldDuration = holdDuration
        end)

        return true
    end

    -- Method 2: ClickDetector
    local clickDetector = nil
    if egg:IsA("BasePart") then
        clickDetector = egg:FindFirstChildOfClass("ClickDetector")
    elseif egg:IsA("Model") then
        for _, desc in ipairs(egg:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                clickDetector = desc
                break
            end
        end
    end

    if clickDetector then
        fireclickdetector(clickDetector)
        return true
    end

    -- Method 3: GUI Button
    local button = self:FindPickupButton()
    if button then
        -- Simulate click
        if typeof(firesignal) == "function" then
            firesignal(button.Activated)
            firesignal(button.MouseButton1Click)
        else
            -- Fallback
            pcall(function()
                button:FindFirstAncestorOfClass("ScreenGui").Enabled = true
                local absPos = button.AbsolutePosition
                local absSize = button.AbsoluteSize
                local center = absPos + absSize / 2

                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
            end)
        end
        return true
    end

    -- Method 4: Touch event
    if egg:IsA("BasePart") then
        local rootPart = Utility:GetRootPart()
        if rootPart then
            firetouchinterest(rootPart, egg, 0)
            task.wait(0.05)
            firetouchinterest(rootPart, egg, 1)
            return true
        end
    elseif egg:IsA("Model") then
        local part = egg:FindFirstChildWhichIsA("BasePart")
        local rootPart = Utility:GetRootPart()
        if part and rootPart then
            firetouchinterest(rootPart, part, 0)
            task.wait(0.05)
            firetouchinterest(rootPart, part, 1)
            return true
        end
    end

    -- Method 5: Remote Events
    pcall(function()
        for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
            if remote:IsA("RemoteEvent") then
                local remoteName = remote.Name:lower()
                if remoteName:find("pickup") or remoteName:find("grab") or
                   remoteName:find("steal") or remoteName:find("collect") or
                   remoteName:find("take") or remoteName:find("interact") then
                    remote:FireServer(egg)
                end
            end
        end
    end)

    return false
end

-- ============================================================
-- ANTI-DROP PROTECTION
-- ============================================================
local AntiDrop = {}

function AntiDrop:Enable()
    if not Config.AntiDrop then return end

    local humanoid = Utility:GetHumanoid()
    if not humanoid then return end

    -- Monitor health changes (detect hits)
    local healthConnection = humanoid.HealthChanged:Connect(function(newHealth)
        if State.IsCarrying and State.HasEgg then
            -- Jika terkena damage saat membawa egg, percepat escape
            Config.EscapeSpeed = Config.EscapeSpeed * 1.5
            Utility:Notify("⚠️ DANGER", "Taking damage! Speeding up escape!", 2)
        end
    end)

    table.insert(State.Connection, healthConnection)
end

-- ============================================================
-- ESP SYSTEM
-- ============================================================
local ESP = {}

function ESP:CreateESP(egg, rarity, weight)
    if not Config.ShowESP then return end

    local position = EggScanner:GetEggPosition(egg)
    if not position then return end

    -- Remove existing ESP for this egg
    self:RemoveESP(egg)

    local color = Config.RarityColors[rarity] or Color3.fromRGB(255, 255, 255)

    -- BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SynStudioESP_" .. egg.Name
    billboard.Size = UDim2.new(0, 200, 0, 80)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = Config.ScanRadius

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 2
    stroke.Parent = frame

    -- Rarity Label
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0.4, 0)
    rarityLabel.Position = UDim2.new(0, 0, 0, 0)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = "⭐ " .. rarity:upper()
    rarityLabel.TextColor3 = color
    rarityLabel.TextScaled = true
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.Parent = frame

    -- Weight Label
    local weightLabel = Instance.new("TextLabel")
    weightLabel.Size = UDim2.new(1, 0, 0.3, 0)
    weightLabel.Position = UDim2.new(0, 0, 0.4, 0)
    weightLabel.BackgroundTransparency = 1
    weightLabel.Text = weight > 0 and ("⚖️ " .. weight .. "kg") or ""
    weightLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    weightLabel.TextScaled = true
    weightLabel.Font = Enum.Font.Gotham
    weightLabel.Parent = frame

    -- Distance Label (updated dynamically)
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(1, 0, 0.3, 0)
    distLabel.Position = UDim2.new(0, 0, 0.7, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "📏 Calculating..."
    distLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    distLabel.TextScaled = true
    distLabel.Font = Enum.Font.Gotham
    distLabel.Parent = frame

    -- Big Egg indicator
    if weight >= Config.BigEggThreshold then
        local bigLabel = Instance.new("TextLabel")
        bigLabel.Size = UDim2.new(1, 0, 0.25, 0)
        bigLabel.Position = UDim2.new(0, 0, -0.3, 0)
        bigLabel.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        bigLabel.BackgroundTransparency = 0.2
        bigLabel.Text = "🔥 BIG EGG 🔥"
        bigLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        bigLabel.TextScaled = true
        bigLabel.Font = Enum.Font.GothamBold

        local bigCorner = Instance.new("UICorner")
        bigCorner.CornerRadius = UDim.new(0, 4)
        bigCorner.Parent = bigLabel

        bigLabel.Parent = frame
    end

    -- Adorn
    if egg:IsA("BasePart") then
        billboard.Adornee = egg
    elseif egg:IsA("Model") then
        billboard.Adornee = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
    end

    billboard.Parent = game:GetService("CoreGui")

    State.ESPObjects[egg] = {
        Billboard = billboard,
        DistLabel = distLabel,
    }
end

function ESP:UpdateESP()
    for egg, espData in pairs(State.ESPObjects) do
        if egg and egg.Parent then
            local dist = Utility:DistanceTo(EggScanner:GetEggPosition(egg) or Vector3.new(0,0,0))
            if espData.DistLabel then
                espData.DistLabel.Text = "📏 " .. math.floor(dist) .. " studs"
            end
        else
            -- Egg no longer exists, remove ESP
            self:RemoveESP(egg)
        end
    end
end

function ESP:RemoveESP(egg)
    if State.ESPObjects[egg] then
        if State.ESPObjects[egg].Billboard then
            State.ESPObjects[egg].Billboard:Destroy()
        end
        State.ESPObjects[egg] = nil
    end
end

function ESP:ClearAll()
    for egg, _ in pairs(State.ESPObjects) do
        self:RemoveESP(egg)
    end
    State.ESPObjects = {}
end

-- ============================================================
-- MAIN STEAL CONTROLLER
-- ============================================================
local StealController = {}

function StealController:GrabEgg(eggData)
    if State.IsGrabbing or State.HasEgg then return end

    State.IsGrabbing = true
    State.CurrentTarget = eggData.Object
    State.CurrentTargetRarity = eggData.Rarity
    State.CurrentTargetWeight = eggData.Weight

    local rarityColor = Config.RarityColors[eggData.Rarity] or "White"
    local bigEggText = eggData.IsBigEgg and " [BIG EGG " .. eggData.Weight .. "kg]" or ""

    Utility:Notify("🥚 TARGET LOCKED",
        eggData.Rarity:upper() .. bigEggText ..
        "\nDistance: " .. math.floor(eggData.Distance) .. " studs", 3)

    -- PHASE 1: Dash menuju egg
    local targetPos = eggData.Position
    local rootPart = Utility:GetRootPart()

    if rootPart then
        local humanoid = Utility:GetHumanoid()
        if humanoid then
            humanoid.WalkSpeed = Config.DashSpeed
        end

        -- Smooth dash (bukan teleport)
        local startTime = tick()
        local startPos = rootPart.Position
        local direction = (targetPos - startPos).Unit
        local distance = (targetPos - startPos).Magnitude
        local duration = distance / Config.DashSpeed

        local dashConn
        dashConn = RunService.Heartbeat:Connect(function(dt)
            if not Config.Enabled or not Utility:IsAlive() then
                if dashConn then dashConn:Disconnect() end
                State.IsGrabbing = false
                return
            end

            -- Update target position (egg mungkin bergerak)
            local currentTargetPos = EggScanner:GetEggPosition(State.CurrentTarget)
            if not currentTargetPos then
                if dashConn then dashConn:Disconnect() end
                State.IsGrabbing = false
                Utility:Notify("❌ TARGET LOST", "Egg disappeared!", 2)
                return
            end

            local currentPos = rootPart.Position
            local dist = (currentTargetPos - currentPos).Magnitude

            if dist <= Config.PickupRange then
                -- Sudah dekat, pickup!
                if dashConn then dashConn:Disconnect() end

                -- PHASE 2: Instant Steal
                self:PerformPickup(eggData)
                return
            end

            -- Smooth movement ke arah egg
            local moveDir = (currentTargetPos - currentPos).Unit
            local step = moveDir * math.min(Config.DashStepSize * (Config.DashSpeed / 50), dist)
            local newPos = currentPos + step

            rootPart.CFrame = CFrame.new(newPos, newPos + moveDir)

            -- Anti-gravity
            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 0, rootPart.Velocity.Z)
        end)

        table.insert(State.Connection, dashConn)
    end
end

function StealController:PerformPickup(eggData)
    Utility:Notify("🫳 GRABBING", "Attempting instant steal...", 1)

    task.wait(Config.AutoPickupDelay)

    -- Try instant steal
    local success = InstantSteal:TriggerPickup(eggData.Object)

    if success then
        State.HasEgg = true
        State.IsCarrying = true

        Utility:Notify("✅ EGG GRABBED!",
            eggData.Rarity:upper() .. " egg secured!\nEscaping to safe zone...", 3)

        -- PHASE 3: Escape ke safe zone
        if Config.AutoEscape then
            self:EscapeToSafeZone()
        else
            State.IsGrabbing = false
        end
    else
        Utility:Notify("⚠️ PICKUP FAILED", "Retrying...", 1)
        task.wait(0.1)

        -- Retry
        success = InstantSteal:TriggerPickup(eggData.Object)
        if success then
            State.HasEgg = true
            State.IsCarrying = true
            if Config.AutoEscape then
                self:EscapeToSafeZone()
            end
        else
            State.IsGrabbing = false
            Utility:Notify("❌ STEAL FAILED", "Could not pickup egg", 2)
        end
    end
end

function StealController:EscapeToSafeZone()
    State.IsEscaping = true
    State.IsGrabbing = false

    local safePos = SafeZone:GetPosition()
    if not safePos then
        Utility:Notify("❌ ERROR", "Safe zone not found!", 3)
        State.IsEscaping = false
        return
    end

    local rootPart = Utility:GetRootPart()
    local humanoid = Utility:GetHumanoid()

    if not rootPart or not humanoid then
        State.IsEscaping = false
        return
    end

    humanoid.WalkSpeed = Config.EscapeSpeed

    Utility:Notify("🏃 ESCAPING!", "Dashing to safe zone...", 2)

    -- Smooth escape dash
    local escapeConn
    escapeConn = RunService.Heartbeat:Connect(function(dt)
        if not Config.Enabled or not Utility:IsAlive() then
            if escapeConn then escapeConn:Disconnect() end
            State.IsEscaping = false
            humanoid.WalkSpeed = Config.NormalSpeed
            return
        end

        local currentPos = rootPart.Position
        local dist = (safePos - currentPos).Magnitude

        if dist <= Config.SafeZoneRange then
            -- Reached safe zone!
            if escapeConn then escapeConn:Disconnect() end
            humanoid.WalkSpeed = Config.NormalSpeed

            State.IsEscaping = false
            State.IsCarrying = false
            State.TripComplete = true

            Utility:Notify("🏠 SAFE!",
                State.CurrentTargetRarity:upper() .. " egg delivered!\n" ..
                "Ready for next trip.", 5)

            -- Reset untuk trip berikutnya
            task.wait(1)
            State.HasEgg = false
            State.TripComplete = false
            State.CurrentTarget = nil
            State.CurrentTargetRarity = nil
            State.CurrentTargetWeight = 0
            return
        end

        -- Smooth movement ke safe zone
        local moveDir = (safePos - currentPos).Unit
        local step = moveDir * math.min(Config.DashStepSize * (Config.EscapeSpeed / 50), dist)
        local newPos = currentPos + step

        rootPart.CFrame = CFrame.new(newPos, newPos + moveDir)
        rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 0, rootPart.Velocity.Z)
    end)

    table.insert(State.Connection, escapeConn)
end

function StealController:Stop()
    Config.Enabled = false
    State.IsGrabbing = false
    State.IsEscaping = false
    State.IsCarrying = false
    State.HasEgg = false
    State.CurrentTarget = nil

    -- Disconnect all connections
    for _, conn in ipairs(State.Connection) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    State.Connection = {}

    -- Reset speed
    local humanoid = Utility:GetHumanoid()
    if humanoid then
        humanoid.WalkSpeed = Config.NormalSpeed
    end

    -- Clear ESP
    ESP:ClearAll()

    Utility:Notify("⏹️ SYN-STUDIO", "Script stopped.", 3)
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local MainLoop = {}

function MainLoop:Start()
    Config.Enabled = true

    Utility:Notify("▶️ SYN-STUDIO", "Script activated!\nScanning for eggs...", 5)

    -- Find safe zone
    SafeZone:FindSafeZone()

    -- Enable anti-drop
    AntiDrop:Enable()

    -- Main scan loop
    local mainConn
    mainConn = RunService.Heartbeat:Connect(function()
        if not Config.Enabled then
            if mainConn then mainConn:Disconnect() end
            return
        end

        if not Utility:IsAlive() then return end

        -- Skip jika sedang grab/escape/carrying
        if State.IsGrabbing or State.IsEscaping or State.HasEgg then return end

        -- Scan untuk eggs
        local eggs = EggScanner:ScanAllEggs()

        -- Update ESP
        ESP:ClearAll()
        for _, eggData in ipairs(eggs) do
            ESP:CreateESP(eggData.Object, eggData.Rarity, eggData.Weight)
        end

        -- Cari target terbaik
        local bestTarget = EggScanner:GetBestTarget(eggs)

        if bestTarget then
            -- Auto grab
            StealController:GrabEgg(bestTarget)
        end
    end)

    table.insert(State.Connection, mainConn)

    -- ESP update loop
    spawn(function()
        while Config.Enabled do
            ESP:UpdateESP()
            task.wait(0.5)
        end
    end)
end

-- ============================================================
-- UI SYSTEM
-- ============================================================
local UI = {}

function UI:Create()
    -- Destroy existing UI
    local existing = game:GetService("CoreGui"):FindFirstChild("SynStudioUI")
    if existing then existing:Destroy() end

    -- Main ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SynStudioUI"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = game:GetService("CoreGui")

    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 380, 0, 620)
    MainFrame.Position = UDim2.new(0.5, -190, 0.5, -310)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = MainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(100, 50, 255)
    mainStroke.Thickness = 2
    mainStroke.Parent = MainFrame

    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 50)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 15, 50)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = TitleBar

    -- Fix bottom corners of title bar
    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0, 15)
    titleFix.Position = UDim2.new(0, 0, 1, -15)
    titleFix.BackgroundColor3 = Color3.fromRGB(25, 15, 50)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -60, 1, 0)
    TitleLabel.Position = UDim2.new(0, 15, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "⚡ SYN-STUDIO v2.0"
    TitleLabel.TextColor3 = Color3.fromRGB(180, 120, 255)
    TitleLabel.TextSize = 20
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    -- Close Button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 35, 0, 35)
    CloseBtn.Position = UDim2.new(1, -42, 0, 7)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 16
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = TitleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        StealController:Stop()
        ScreenGui:Destroy()
    end)

    -- Minimize Button
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 35, 0, 35)
    MinBtn.Position = UDim2.new(1, -82, 0, 7)
    MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    MinBtn.TextSize = 16
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TitleBar

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 8)
    minCorner.Parent = MinBtn

    local isMinimized = false
    MinBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        for _, child in ipairs(MainFrame:GetChildren()) do
            if child ~= TitleBar and child:IsA("GuiObject") then
                child.Visible = not isMinimized
            end
        end
        if isMinimized then
            MainFrame.Size = UDim2.new(0, 380, 0, 50)
            MinBtn.Text = "+"
        else
            MainFrame.Size = UDim2.new(0, 380, 0, 620)
            MinBtn.Text = "—"
        end
    end)

    -- Scroll Frame for Content
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -20, 1, -60)
    ScrollFrame.Position = UDim2.new(0, 10, 0, 55)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 4
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 50, 255)
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 900)
    ScrollFrame.Parent = MainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = ScrollFrame

    -- Helper: Create Section
    local function CreateSection(name, order)
        local section = Instance.new("Frame")
        section.Size = UDim2.new(1, 0, 0, 30)
        section.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
        section.BorderSizePixel = 0
        section.LayoutOrder = order
        section.Parent = ScrollFrame

        local sCorner = Instance.new("UICorner")
        sCorner.CornerRadius = UDim.new(0, 6)
        sCorner.Parent = section

        local sLabel = Instance.new("TextLabel")
        sLabel.Size = UDim2.new(1, -10, 1, 0)
        sLabel.Position = UDim2.new(0, 10, 0, 0)
        sLabel.BackgroundTransparency = 1
        sLabel.Text = "▸ " .. name
        sLabel.TextColor3 = Color3.fromRGB(150, 100, 255)
        sLabel.TextSize = 14
        sLabel.Font = Enum.Font.GothamBold
        sLabel.TextXAlignment = Enum.TextXAlignment.Left
        sLabel.Parent = section

        return section
    end

    -- Helper: Create Toggle
    local function CreateToggle(name, default, order, callback)
        local toggleFrame = Instance.new("Frame")
        toggleFrame.Size = UDim2.new(1, 0, 0, 35)
        toggleFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
        toggleFrame.BorderSizePixel = 0
        toggleFrame.LayoutOrder = order
        toggleFrame.Parent = ScrollFrame

        local tCorner = Instance.new("UICorner")
        tCorner.CornerRadius = UDim.new(0, 6)
        tCorner.Parent = toggleFrame

        local tLabel = Instance.new("TextLabel")
        tLabel.Size = UDim2.new(0.65, 0, 1, 0)
        tLabel.Position = UDim2.new(0, 12, 0, 0)
        tLabel.BackgroundTransparency = 1
        tLabel.Text = name
        tLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        tLabel.TextSize = 13
        tLabel.Font = Enum.Font.Gotham
        tLabel.TextXAlignment = Enum.TextXAlignment.Left
        tLabel.Parent = toggleFrame

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 55, 0, 25)
        toggleBtn.Position = UDim2.new(1, -65, 0.5, -12)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.TextSize = 12
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.Parent = toggleFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = toggleBtn

        local isOn = default

        local function UpdateVisual()
            if isOn then
                toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                toggleBtn.Text = "ON"
                toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
                toggleBtn.Text = "OFF"
                toggleBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end

        UpdateVisual()

        toggleBtn.MouseButton1Click:Connect(function()
            isOn = not isOn
            UpdateVisual()
            if callback then callback(isOn) end
        end)

        return toggleFrame
    end

    -- Helper: Create Rarity Toggle (with color)
    local function CreateRarityToggle(rarity, order)
        local color = Config.RarityColors[rarity] or Color3.fromRGB(255, 255, 255)

        local toggleFrame = Instance.new("Frame")
        toggleFrame.Size = UDim2.new(1, 0, 0, 32)
        toggleFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
        toggleFrame.BorderSizePixel = 0
        toggleFrame.LayoutOrder = order
        toggleFrame.Parent = ScrollFrame

        local tCorner = Instance.new("UICorner")
        tCorner.CornerRadius = UDim.new(0, 6)
        tCorner.Parent = toggleFrame

        -- Color indicator
        local colorDot = Instance.new("Frame")
        colorDot.Size = UDim2.new(0, 12, 0, 12)
        colorDot.Position = UDim2.new(0, 12, 0.5, -6)
        colorDot.BackgroundColor3 = color
        colorDot.BorderSizePixel = 0
        colorDot.Parent = toggleFrame

        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = colorDot

        local tLabel = Instance.new("TextLabel")
        tLabel.Size = UDim2.new(0.55, 0, 1, 0)
        tLabel.Position = UDim2.new(0, 32, 0, 0)
        tLabel.BackgroundTransparency = 1
        tLabel.Text = rarity
        tLabel.TextColor3 = color
        tLabel.TextSize = 13
        tLabel.Font = Enum.Font.GothamBold
        tLabel.TextXAlignment = Enum.TextXAlignment.Left
        tLabel.Parent = toggleFrame

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 55, 0, 22)
        toggleBtn.Position = UDim2.new(1, -65, 0.5, -11)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.TextSize = 11
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.Parent = toggleFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = toggleBtn

        local isOn = Config.Rarities[rarity]

        local function UpdateVisual()
            if isOn then
                toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                toggleBtn.Text = "ON"
                toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
                toggleBtn.Text = "OFF"
                toggleBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end

        UpdateVisual()

        toggleBtn.MouseButton1Click:Connect(function()
            isOn = not isOn
            Config.Rarities[rarity] = isOn
            UpdateVisual()
        end)

        return toggleFrame
    end

    -- ====== BUILD UI SECTIONS ======

    -- STATUS DISPLAY
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, 0, 0, 60)
    statusFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 15)
    statusFrame.BorderSizePixel = 0
    statusFrame.LayoutOrder = 0
    statusFrame.Parent = ScrollFrame

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = statusFrame

    local statusStroke = Instance.new("UIStroke")
    statusStroke.Color = Color3.fromRGB(50, 150, 50)
    statusStroke.Thickness = 1
    statusStroke.Parent = statusFrame

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, -20, 1, 0)
    StatusLabel.Position = UDim2.new(0, 10, 0, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "📊 Status: IDLE\n🥚 Target: None"
    StatusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    StatusLabel.TextSize = 12
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    StatusLabel.Parent = statusFrame

    -- MAIN CONTROLS
    CreateSection("MAIN CONTROLS", 1)

    -- Start/Stop Button
    local startBtnFrame = Instance.new("Frame")
    startBtnFrame.Size = UDim2.new(1, 0, 0, 45)
    startBtnFrame.BackgroundTransparency = 1
    startBtnFrame.LayoutOrder = 2
    startBtnFrame.Parent = ScrollFrame

    local StartBtn = Instance.new("TextButton")
    StartBtn.Size = UDim2.new(1, 0, 1, 0)
    StartBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
    StartBtn.Text = "▶ START STEALING"
    StartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartBtn.TextSize = 16
    StartBtn.Font = Enum.Font.GothamBold
    StartBtn.BorderSizePixel = 0
    StartBtn.Parent = startBtnFrame

    local startCorner = Instance.new("UICorner")
    startCorner.CornerRadius = UDim.new(0, 8)
    startCorner.Parent = StartBtn

    local scriptRunning = false
    StartBtn.MouseButton1Click:Connect(function()
        scriptRunning = not scriptRunning
        if scriptRunning then
            StartBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            StartBtn.Text = "⏹ STOP STEALING"
            MainLoop:Start()
        else
            StartBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
            StartBtn.Text = "▶ START STEALING"
            StealController:Stop()
        end
    end)

    -- Set Safe Zone Button
    local setSafeBtnFrame = Instance.new("Frame")
    setSafeBtnFrame.Size = UDim2.new(1, 0, 0, 35)
    setSafeBtnFrame.BackgroundTransparency = 1
    setSafeBtnFrame.LayoutOrder = 3
    setSafeBtnFrame.Parent = ScrollFrame

    local SetSafeBtn = Instance.new("TextButton")
    SetSafeBtn.Size = UDim2.new(1, 0, 1, 0)
    SetSafeBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 160)
    SetSafeBtn.Text = "🏠 Set Current Position as Safe Zone"
    SetSafeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SetSafeBtn.TextSize = 13
    SetSafeBtn.Font = Enum.Font.GothamBold
    SetSafeBtn.BorderSizePixel = 0
    SetSafeBtn.Parent = setSafeBtnFrame

    local setSafeCorner = Instance.new("UICorner")
    setSafeCorner.CornerRadius = UDim.new(0, 8)
    setSafeCorner.Parent = SetSafeBtn

    SetSafeBtn.MouseButton1Click:Connect(function()
        Config.SafeZonePosition = Utility:GetPosition()
        Utility:Notify("🏠 Safe Zone Set", "Current position saved as safe zone!", 3)
    end)

    -- FEATURE TOGGLES
    CreateSection("FEATURES", 10)

    CreateToggle("Instant Steal (Auto Pickup)", Config.InstantSteal, 11, function(v)
        Config.InstantSteal = v
    end)

    CreateToggle("Auto Escape to Safe Zone", Config.AutoEscape, 12, function(v)
        Config.AutoEscape = v
    end)

    CreateToggle("Big Egg Priority (>1000kg)", Config.BigEggMode, 13, function(v)
        Config.BigEggMode = v
        Config.BigEggPriority = v
    end)

    CreateToggle("Anti-Drop Protection", Config.AntiDrop, 14, function(v)
        Config.AntiDrop = v
    end)

    CreateToggle("Show ESP", Config.ShowESP, 15, function(v)
        Config.ShowESP = v
        if not v then ESP:ClearAll() end
    end)

    -- SPEED SETTINGS
    CreateSection("SPEED SETTINGS", 20)

    -- Dash Speed Slider
    local function CreateSlider(name, min, max, default, order, callback)
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, 0, 0, 50)
        sliderFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
        sliderFrame.BorderSizePixel = 0
        sliderFrame.LayoutOrder = order
        sliderFrame.Parent = ScrollFrame

        local sCorner = Instance.new("UICorner")
        sCorner.CornerRadius = UDim.new(0, 6)
        sCorner.Parent = sliderFrame

        local sLabel = Instance.new("TextLabel")
        sLabel.Size = UDim2.new(0.6, 0, 0, 20)
        sLabel.Position = UDim2.new(0, 12, 0, 3)
        sLabel.BackgroundTransparency = 1
        sLabel.Text = name
        sLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        sLabel.TextSize = 12
        sLabel.Font = Enum.Font.Gotham
        sLabel.TextXAlignment = Enum.TextXAlignment.Left
        sLabel.Parent = sliderFrame

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0.3, 0, 0, 20)
        valueLabel.Position = UDim2.new(0.7, 0, 0, 3)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(default)
        valueLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
        valueLabel.TextSize = 12
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = sliderFrame

        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(1, -24, 0, 8)
        sliderBg.Position = UDim2.new(0, 12, 0, 32)
        sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = sliderFrame

        local bgCorner = Instance.new("UICorner")
        bgCorner.CornerRadius = UDim.new(1, 0)
        bgCorner.Parent = sliderBg

        local sliderFill = Instance.new("Frame")
        local initAlpha = (default - min) / (max - min)
        sliderFill.Size = UDim2.new(initAlpha, 0, 1, 0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(100, 50, 255)
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBg

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = sliderFill

        local sliderKnob = Instance.new("TextButton")
        sliderKnob.Size = UDim2.new(0, 16, 0, 16)
        sliderKnob.Position = UDim2.new(initAlpha, -8, 0.5, -8)
        sliderKnob.BackgroundColor3 = Color3.fromRGB(180, 120, 255)
        sliderKnob.Text = ""
        sliderKnob.BorderSizePixel = 0
        sliderKnob.ZIndex = 2
        sliderKnob.Parent = sliderBg

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = sliderKnob

        local dragging = false

        sliderKnob.MouseButton1Down:Connect(function()
            dragging = true
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local absPos = sliderBg.AbsolutePosition
                local absSize = sliderBg.AbsoluteSize
                local relX = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)

                sliderFill.Size = UDim2.new(relX, 0, 1, 0)
                sliderKnob.Position = UDim2.new(relX, -8, 0.5, -8)

                local value = math.floor(min + (max - min) * relX)
                valueLabel.Text = tostring(value)

                if callback then callback(value) end
            end
        end)

        -- Click on bar to set
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local absPos = sliderBg.AbsolutePosition
                local absSize = sliderBg.AbsoluteSize
                local relX = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)

                sliderFill.Size = UDim2.new(relX, 0, 1, 0)
                sliderKnob.Position = UDim2.new(relX, -8, 0.5, -8)

                local value = math.floor(min + (max - min) * relX)
                valueLabel.Text = tostring(value)

                if callback then callback(value) end
                dragging = true
            end
        end)

        return sliderFrame
    end

    CreateSlider("Dash Speed", 50, 500, Config.DashSpeed, 21, function(v)
        Config.DashSpeed = v
    end)

    CreateSlider("Escape Speed", 50, 600, Config.EscapeSpeed, 22, function(v)
        Config.EscapeSpeed = v
    end)

    CreateSlider("Big Egg Threshold (kg)", 100, 5000, Config.BigEggThreshold, 23, function(v)
        Config.BigEggThreshold = v
    end)

    -- RARITY FILTER
    CreateSection("RARITY FILTER", 30)

    local rarityOrder = {
        "Ethernal", "Devine", "Cosmic", "Secret",
        "Legend", "Mistic", "Rare", "Epic",
        "Uncommon", "Common"
    }

    for i, rarity in ipairs(rarityOrder) do
        CreateRarityToggle(rarity, 30 + i)
    end

    -- Select All / Deselect All
    local selectFrame = Instance.new("Frame")
    selectFrame.Size = UDim2.new(1, 0, 0, 30)
    selectFrame.BackgroundTransparency = 1
    selectFrame.LayoutOrder = 45
    selectFrame.Parent = ScrollFrame

    local selectAllBtn = Instance.new("TextButton")
    selectAllBtn.Size = UDim2.new(0.48, 0, 1, 0)
    selectAllBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
    selectAllBtn.Text = "Select All"
    selectAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectAllBtn.TextSize = 12
    selectAllBtn.Font = Enum.Font.GothamBold
    selectAllBtn.BorderSizePixel = 0
    selectAllBtn.Parent = selectFrame

    local saCorner = Instance.new("UICorner")
    saCorner.CornerRadius = UDim.new(0, 6)
    saCorner.Parent = selectAllBtn

    local deselectAllBtn = Instance.new("TextButton")
    deselectAllBtn.Size = UDim2.new(0.48, 0, 1, 0)
    deselectAllBtn.Position = UDim2.new(0.52, 0, 0, 0)
    deselectAllBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
    deselectAllBtn.Text = "Deselect All"
    deselectAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    deselectAllBtn.TextSize = 12
    deselectAllBtn.Font = Enum.Font.GothamBold
    deselectAllBtn.BorderSizePixel = 0
    deselectAllBtn.Parent = selectFrame

    local daCorner = Instance.new("UICorner")
    daCorner.CornerRadius = UDim.new(0, 6)
    daCorner.Parent = deselectAllBtn

    selectAllBtn.MouseButton1Click:Connect(function()
        for rarity, _ in pairs(Config.Rarities) do
            Config.Rarities[rarity] = true
        end
        Utility:Notify("✅", "All rarities selected!", 2)
        -- Refresh UI (recreate)
        ScreenGui:Destroy()
        UI:Create()
    end)

    deselectAllBtn.MouseButton1Click:Connect(function()
        for rarity, _ in pairs(Config.Rarities) do
            Config.Rarities[rarity] = false
        end
        Utility:Notify("❌", "All rarities deselected!", 2)
        ScreenGui:Destroy()
        UI:Create()
    end)

    -- INFO SECTION
    CreateSection("INFO & CREDITS", 50)

    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, 0, 0, 80)
    infoFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    infoFrame.BorderSizePixel = 0
    infoFrame.LayoutOrder = 51
    infoFrame.Parent = ScrollFrame

    local iCorner = Instance.new("UICorner")
    iCorner.CornerRadius = UDim.new(0, 6)
    iCorner.Parent = infoFrame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -20, 1, 0)
    infoLabel.Position = UDim2.new(0, 10, 0, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = [[⚡ SYN-STUDIO v2.0
🥚 Auto Egg Stealer
📌 Press toggle to filter rarities
🏃 Non-teleport smooth dash
🛡️ Anti-drop protection enabled
⚠️ Use at your own risk!]]
    infoLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    infoLabel.TextSize = 11
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.TextWrapped = true
    infoLabel.Parent = infoFrame

    -- Update canvas size
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
    end)

    -- STATUS UPDATE LOOP
    spawn(function()
        while ScreenGui and ScreenGui.Parent do
            local statusText = ""

            if Config.Enabled then
                if State.IsGrabbing then
                    statusText = "📊 Status: 🏃 GRABBING EGG\n"
                elseif State.IsEscaping then
                    statusText = "📊 Status: 🏃 ESCAPING TO SAFE ZONE\n"
                elseif State.HasEgg then
                    statusText = "📊 Status: 🥚 CARRYING EGG\n"
                else
                    statusText = "📊 Status: 👁️ SCANNING...\n"
                end
            else
                statusText = "📊 Status: ⏸️ IDLE\n"
            end

            if State.CurrentTarget and State.CurrentTargetRarity then
                local bigText = State.CurrentTargetWeight >= Config.BigEggThreshold
                    and " [BIG " .. State.CurrentTargetWeight .. "kg]" or ""
                statusText = statusText .. "🥚 Target: " ..
                    State.CurrentTargetRarity:upper() .. bigText
            else
                statusText = statusText .. "🥚 Target: None"
            end

            if StatusLabel and StatusLabel.Parent then
                StatusLabel.Text = statusText
            end

            task.wait(0.2)
        end
    end)

    -- Toggle UI with key
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            MainFrame.Visible = not MainFrame.Visible
        end
    end)

    Utility:Notify("⚡ SYN-STUDIO",
        "UI Loaded!\nPress RightShift to toggle UI\nSet your rarity filters and press START!", 5)

    return ScreenGui
end

-- ============================================================
-- INITIALIZATION
-- ============================================================
local function Initialize()
    print("===========================================")
    print("  ⚡ SYN-STUDIO v2.0 - Egg Stealer")
    print("  Loading...")
    print("===========================================")

    -- Bersihkan instance lama jika ada
    local existing = game:GetService("CoreGui"):FindFirstChild("SynStudioUI")
    if existing then existing:Destroy() end

    -- Buat UI
    UI:Create()

    print("[SYN-STUDIO] ✅ Script loaded successfully!")
    print("[SYN-STUDIO] 📌 Press RightShift to toggle UI")
    print("[SYN-STUDIO] 🥚 Configure rarities and press START")
end

-- Character respawn handler
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)

    -- Reset state on respawn
    State.IsGrabbing = false
    State.IsEscaping = false
    State.IsCarrying = false
    State.HasEgg = false
    State.CurrentTarget = nil

    if Config.Enabled then
        Utility:Notify("🔄 RESPAWNED", "Resuming egg stealing...", 3)
    end
end)

-- Run initialization
Initialize()

-- ============================================================
-- HOTKEYS
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- F5: Quick Start/Stop
    if input.KeyCode == Enum.KeyCode.F5 then
        Config.Enabled = not Config.Enabled
        if Config.Enabled then
            MainLoop:Start()
            Utility:Notify("▶️ HOTKEY", "Stealing STARTED (F5)", 2)
        else
            StealController:Stop()
            Utility:Notify("⏹️ HOTKEY", "Stealing STOPPED (F5)", 2)
        end
    end

    -- F6: Toggle ESP
    if input.KeyCode == Enum.KeyCode.F6 then
        Config.ShowESP = not Config.ShowESP
        if not Config.ShowESP then ESP:ClearAll() end
        Utility:Notify("👁️ ESP", Config.ShowESP and "ENABLED" or "DISABLED", 2)
    end

    -- F7: Set Safe Zone
    if input.KeyCode == Enum.KeyCode.F7 then
        Config.SafeZonePosition = Utility:GetPosition()
        Utility:Notify("🏠 SAFE ZONE", "Position saved!", 2)
    end
end)

return {
    Config = Config,
    State = State,
    Start = function() MainLoop:Start() end,
    Stop = function() StealController:Stop() end,
    SetSafeZone = function(pos) Config.SafeZonePosition = pos end,
}
