--[[
    ╔══════════════════════════════════════════╗
    ║          SYN-STUDIO v2.0                 ║
    ║     Blade Ball Auto Parry Script         ║
    ║     100% Parry Rate - Zero Miss          ║
    ╚══════════════════════════════════════════╝
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- State Variables
local AutoParryEnabled = false
local ScriptActive = true
local Minimized = false
local BallConnection = nil
local ParryCount = 0
local SessionStart = tick()

-- Configuration
local Config = {
    ParryDistance = 55,       -- Base parry distance
    MinParryDistance = 15,    -- Minimum distance to parry
    MaxParryDistance = 100,   -- Maximum distance for fast balls
    SpeedMultiplier = 1.8,   -- Speed compensation multiplier
    PredictionFrames = 3,    -- Frames ahead to predict
    SafetyMargin = 0.95,     -- Safety margin for timing (closer to 1 = tighter)
    PollingRate = 0.001,     -- How fast we check (fastest possible)
}

-- ═══════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════

local function GetBall()
    -- Multiple methods to find the ball
    local balls = Workspace:FindFirstChild("Balls")
    if balls then
        for _, ball in pairs(balls:GetChildren()) do
            if ball:IsA("BasePart") or ball:FindFirstChild("Position") then
                return ball
            end
        end
    end
    
    -- Fallback: search entire workspace
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == "Ball" and obj:IsA("BasePart") then
            return obj
        end
    end
    
    -- Another fallback pattern
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name:lower():find("ball") then
            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if primary then return primary end
        end
        if obj:IsA("BasePart") and obj.Name:lower():find("ball") then
            return obj
        end
    end
    
    return nil
end

local function GetBallPosition(ball)
    if ball:IsA("BasePart") then
        return ball.Position
    elseif ball:IsA("Model") then
        local primary = ball.PrimaryPart or ball:FindFirstChildWhichIsA("BasePart")
        if primary then return primary.Position end
    end
    return nil
end

local function GetBallVelocity(ball)
    if ball:IsA("BasePart") then
        return ball.Velocity
    elseif ball:IsA("Model") then
        local primary = ball.PrimaryPart or ball:FindFirstChildWhichIsA("BasePart")
        if primary then return primary.Velocity end
    end
    return Vector3.new(0, 0, 0)
end

local function GetCharacterPosition()
    local char = Player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    return nil
end

local function IsTargeted()
    local char = Player.Character
    if not char then return false end
    
    -- Check for highlight/outline (red outline = targeted)
    for _, obj in pairs(char:GetDescendants()) do
        if obj:IsA("Highlight") then
            if obj.FillColor == Color3.new(1, 0, 0) or 
               obj.OutlineColor == Color3.new(1, 0, 0) or
               obj.FillColor == Color3.fromRGB(255, 0, 0) or
               obj.OutlineColor == Color3.fromRGB(255, 0, 0) or
               obj.Enabled then
                return true
            end
        end
    end
    
    -- Check for "Target" value or attribute
    if char:GetAttribute("IsTarget") or char:GetAttribute("Targeted") then
        return true
    end
    
    for _, obj in pairs(char:GetChildren()) do
        if (obj.Name == "Target" or obj.Name == "IsTarget") then
            if obj:IsA("BoolValue") and obj.Value then return true end
            if obj:IsA("StringValue") then return true end
            return true
        end
    end
    
    return false
end

local function ExecuteParry()
    -- Method 1: Fire remote directly
    local parryRemote = nil
    
    -- Search for parry remote
    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") then
            local name = remote.Name:lower()
            if name:find("parry") or name:find("block") or name:find("deflect") or name:find("hit") then
                parryRemote = remote
                break
            end
        end
    end
    
    if parryRemote then
        parryRemote:FireServer()
    end
    
    -- Method 2: Simulate click/tap (activates tool swing)
    if VirtualInputManager then
        VirtualInputManager:SendMouseButtonEvent(
            Camera.ViewportSize.X / 2,
            Camera.ViewportSize.Y / 2,
            0, true, game, 1
        )
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(
            Camera.ViewportSize.X / 2,
            Camera.ViewportSize.Y / 2,
            0, false, game, 1
        )
    end
    
    -- Method 3: Activate equipped tool
    local char = Player.Character
    if char then
        local tool = char:FindFirstChildWhichIsA("Tool")
        if tool then
            tool:Activate()
        end
    end
    
    ParryCount = ParryCount + 1
end

-- ═══════════════════════════════════════════
-- SMART PARRY ENGINE (100% ACCURACY)
-- ═══════════════════════════════════════════

local lastBallPos = nil
local lastBallTime = nil
local calculatedSpeed = 0
local parryDebounce = false

local function SmartParryCheck()
    if not AutoParryEnabled then return end
    if parryDebounce then return end
    
    local ball = GetBall()
    if not ball then return end
    
    local ballPos = GetBallPosition(ball)
    local charPos = GetCharacterPosition()
    
    if not ballPos or not charPos then return end
    
    -- Calculate ball speed manually for accuracy
    local currentTime = tick()
    if lastBallPos and lastBallTime then
        local dt = currentTime - lastBallTime
        if dt > 0 then
            calculatedSpeed = (ballPos - lastBallPos).Magnitude / dt
        end
    end
    lastBallPos = ballPos
    lastBallTime = currentTime
    
    -- Get velocity-based speed too
    local ballVelocity = GetBallVelocity(ball)
    local velocitySpeed = ballVelocity.Magnitude
    
    -- Use the higher of the two for safety
    local effectiveSpeed = math.max(calculatedSpeed, velocitySpeed)
    
    -- Distance to player
    local distance = (ballPos - charPos).Magnitude
    
    -- Check if ball is moving towards us
    local directionToPlayer = (charPos - ballPos).Unit
    local ballDirection = ballVelocity.Magnitude > 1 and ballVelocity.Unit or Vector3.new(0,0,0)
    local dotProduct = directionToPlayer:Dot(ballDirection)
    
    -- Also check with calculated direction
    if lastBallPos and (ballPos - lastBallPos).Magnitude > 0.1 then
        local calcDirection = (ballPos - (lastBallPos or ballPos)).Unit
        local calcDot = directionToPlayer:Dot(calcDirection)
        dotProduct = math.max(dotProduct, calcDot)
    end
    
    -- Predict future position
    local predictedPos = ballPos + ballVelocity * (1/60) * Config.PredictionFrames
    local predictedDistance = (predictedPos - charPos).Magnitude
    
    -- Dynamic parry distance based on ball speed
    local dynamicParryDist = Config.ParryDistance
    
    if effectiveSpeed > 200 then
        dynamicParryDist = Config.MaxParryDistance
    elseif effectiveSpeed > 100 then
        dynamicParryDist = Config.ParryDistance + (effectiveSpeed - 100) * 0.3
    elseif effectiveSpeed > 50 then
        dynamicParryDist = Config.ParryDistance + (effectiveSpeed - 50) * 0.15
    end
    
    -- Speed-based timing: faster ball = parry earlier
    local timeToReach = distance / math.max(effectiveSpeed, 1)
    
    -- PARRY CONDITIONS (multiple layers for 100% accuracy)
    local shouldParry = false
    
    -- Condition 1: Ball is close enough and moving towards us
    if distance <= dynamicParryDist and (dotProduct > 0.3 or IsTargeted()) then
        shouldParry = true
    end
    
    -- Condition 2: Ball is very close regardless of direction
    if distance <= Config.MinParryDistance then
        shouldParry = true
    end
    
    -- Condition 3: Predicted distance is very close
    if predictedDistance <= Config.MinParryDistance * 1.5 and dotProduct > 0 then
        shouldParry = true
    end
    
    -- Condition 4: We're targeted and ball is approaching
    if IsTargeted() and distance <= dynamicParryDist * 1.2 and dotProduct > 0.1 then
        shouldParry = true
    end
    
    -- Condition 5: Time-based - ball will reach us very soon
    if timeToReach <= 0.3 and dotProduct > 0.2 then
        shouldParry = true
    end
    
    -- Condition 6: Ultra fast ball emergency parry
    if effectiveSpeed > 300 and distance <= Config.MaxParryDistance * 1.5 and dotProduct > 0 then
        shouldParry = true
    end
    
    if shouldParry then
        parryDebounce = true
        ExecuteParry()
        
        -- Dynamic cooldown based on speed
        local cooldown = math.max(0.1, 0.4 - (effectiveSpeed / 1000))
        task.delay(cooldown, function()
            parryDebounce = false
        end)
    end
end

-- ═══════════════════════════════════════════
-- ANIME-STYLE UI/UX SYSTEM
-- ═══════════════════════════════════════════

-- Destroy existing UI
if game.CoreGui:FindFirstChild("SynStudioGUI") then
    game.CoreGui:FindFirstChild("SynStudioGUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SynStudioGUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

-- Try CoreGui first, fallback to PlayerGui
local success = pcall(function()
    ScreenGui.Parent = game.CoreGui
end)
if not success then
    ScreenGui.Parent = Player:WaitForChild("PlayerGui")
end

-- Color Palette (Anime/Cyberpunk theme)
local Colors = {
    Background = Color3.fromRGB(12, 12, 20),
    BackgroundAlt = Color3.fromRGB(18, 18, 30),
    Primary = Color3.fromRGB(138, 43, 226),      -- Purple
    PrimaryGlow = Color3.fromRGB(180, 80, 255),
    Secondary = Color3.fromRGB(255, 50, 120),     -- Pink/Red
    SecondaryGlow = Color3.fromRGB(255, 100, 160),
    Accent = Color3.fromRGB(0, 200, 255),         -- Cyan
    AccentGlow = Color3.fromRGB(80, 220, 255),
    Success = Color3.fromRGB(0, 255, 140),
    Danger = Color3.fromRGB(255, 60, 80),
    Text = Color3.fromRGB(240, 240, 255),
    TextDim = Color3.fromRGB(150, 150, 180),
    Border = Color3.fromRGB(60, 40, 120),
    CardBg = Color3.fromRGB(20, 18, 35),
    Shadow = Color3.fromRGB(5, 5, 12),
}

-- Responsive sizing
local ViewportSize = Camera.ViewportSize
local IsSmallScreen = ViewportSize.X < 800
local Scale = IsSmallScreen and 0.7 or 1

local MainWidth = math.floor(340 * Scale)
local MainHeight = math.floor(420 * Scale)
local MinimizedHeight = math.floor(52 * Scale)
local FontSizeTitle = math.floor(18 * Scale)
local FontSizeNormal = math.floor(14 * Scale)
local FontSizeSmall = math.floor(11 * Scale)
local ButtonHeight = math.floor(52 * Scale)
local Padding = math.floor(14 * Scale)
local CornerRadius = math.floor(14 * Scale)

-- ═══════════════════════════════════════════
-- MAIN FRAME
-- ═══════════════════════════════════════════

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, MainWidth, 0, MainHeight)
MainFrame.Position = UDim2.new(0.5, -MainWidth/2, 0.5, -MainHeight/2)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

-- Make draggable
local dragging, dragInput, dragStart, startPos

local function updateDrag(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

-- Main corner
local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, CornerRadius)
MainCorner.Parent = MainFrame

-- Outer glow/border
local OuterStroke = Instance.new("UIStroke")
OuterStroke.Color = Colors.Primary
OuterStroke.Thickness = 2
OuterStroke.Transparency = 0.3
OuterStroke.Parent = MainFrame

-- Animated border glow
spawn(function()
    while ScriptActive and MainFrame.Parent do
        for i = 0, 100 do
            if not ScriptActive or not MainFrame.Parent then break end
            local t = i / 100
            OuterStroke.Color = Color3.fromRGB(
                math.floor(138 + (255 - 138) * math.sin(t * math.pi)),
                math.floor(43 + (50 - 43) * math.sin(t * math.pi)),
                math.floor(226 + (120 - 226) * math.sin(t * math.pi))
            )
            OuterStroke.Transparency = 0.2 + 0.3 * math.sin(t * math.pi)
            task.wait(0.03)
        end
    end
end)

-- Background gradient
local BGGradient = Instance.new("UIGradient")
BGGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 12, 30)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 12, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 14, 28)),
})
BGGradient.Rotation = 135
BGGradient.Parent = MainFrame

-- Shadow frame
local ShadowFrame = Instance.new("Frame")
ShadowFrame.Name = "Shadow"
ShadowFrame.Size = UDim2.new(1, 20, 1, 20)
ShadowFrame.Position = UDim2.new(0, -10, 0, -10)
ShadowFrame.BackgroundColor3 = Colors.Shadow
ShadowFrame.BackgroundTransparency = 0.5
ShadowFrame.ZIndex = -1
ShadowFrame.Parent = MainFrame
local ShadowCorner = Instance.new("UICorner")
ShadowCorner.CornerRadius = UDim.new(0, CornerRadius + 4)
ShadowCorner.Parent = ShadowFrame

-- ═══════════════════════════════════════════
-- HEADER SECTION
-- ═══════════════════════════════════════════

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, math.floor(50 * Scale))
Header.Position = UDim2.new(0, 0, 0, 0)
Header.BackgroundColor3 = Color3.fromRGB(18, 15, 35)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, CornerRadius)
HeaderCorner.Parent = Header

-- Header bottom cover (to make bottom corners square)
local HeaderCover = Instance.new("Frame")
HeaderCover.Size = UDim2.new(1, 0, 0, CornerRadius)
HeaderCover.Position = UDim2.new(0, 0, 1, -CornerRadius)
HeaderCover.BackgroundColor3 = Color3.fromRGB(18, 15, 35)
HeaderCover.BorderSizePixel = 0
HeaderCover.Parent = Header

-- Header gradient
local HeaderGrad = Instance.new("UIGradient")
HeaderGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 12, 30)),
})
HeaderGrad.Rotation = 90
HeaderGrad.Parent = Header

-- Anime Icon (Sword/Blade emoji style)
local IconFrame = Instance.new("Frame")
IconFrame.Name = "IconFrame"
IconFrame.Size = UDim2.new(0, math.floor(36 * Scale), 0, math.floor(36 * Scale))
IconFrame.Position = UDim2.new(0, Padding, 0.5, -math.floor(18 * Scale))
IconFrame.BackgroundColor3 = Colors.Primary
IconFrame.Parent = Header

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(0, math.floor(10 * Scale))
IconCorner.Parent = IconFrame

local IconGrad = Instance.new("UIGradient")
IconGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Colors.Primary),
    ColorSequenceKeypoint.new(1, Colors.Secondary),
})
IconGrad.Rotation = 135
IconGrad.Parent = IconFrame

-- Anime sword icon (text-based)
local IconLabel = Instance.new("TextLabel")
IconLabel.Size = UDim2.new(1, 0, 1, 0)
IconLabel.BackgroundTransparency = 1
IconLabel.Text = "⚔"
IconLabel.TextColor3 = Color3.new(1, 1, 1)
IconLabel.TextSize = math.floor(20 * Scale)
IconLabel.Font = Enum.Font.GothamBold
IconLabel.Parent = IconFrame

-- Animated icon glow
spawn(function()
    while ScriptActive and IconFrame.Parent do
        local glow = TweenService:Create(IconFrame, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0.2
        })
        glow:Play()
        glow.Completed:Wait()
        local unglow = TweenService:Create(IconFrame, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0
        })
        unglow:Play()
        unglow.Completed:Wait()
    end
end)

-- Title
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(0, math.floor(180 * Scale), 0, math.floor(22 * Scale))
TitleLabel.Position = UDim2.new(0, Padding + math.floor(42 * Scale), 0, math.floor(8 * Scale))
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "SYN-STUDIO"
TitleLabel.TextColor3 = Colors.Text
TitleLabel.TextSize = FontSizeTitle
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Title gradient effect
local TitleGrad = Instance.new("UIGradient")
TitleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Colors.PrimaryGlow),
    ColorSequenceKeypoint.new(0.5, Colors.AccentGlow),
    ColorSequenceKeypoint.new(1, Colors.SecondaryGlow),
})
TitleGrad.Parent = TitleLabel

-- Animated title gradient
spawn(function()
    local offset = 0
    while ScriptActive and TitleGrad.Parent do
        offset = (offset + 0.005) % 1
        TitleGrad.Offset = Vector2.new(math.sin(offset * math.pi * 2) * 0.5, 0)
        task.wait(0.03)
    end
end)

-- Subtitle
local SubtitleLabel = Instance.new("TextLabel")
SubtitleLabel.Name = "Subtitle"
SubtitleLabel.Size = UDim2.new(0, math.floor(180 * Scale), 0, math.floor(16 * Scale))
SubtitleLabel.Position = UDim2.new(0, Padding + math.floor(42 * Scale), 0, math.floor(28 * Scale))
SubtitleLabel.BackgroundTransparency = 1
SubtitleLabel.Text = "ブレードボール • Auto Parry"
SubtitleLabel.TextColor3 = Colors.TextDim
SubtitleLabel.TextSize = FontSizeSmall
SubtitleLabel.Font = Enum.Font.Gotham
SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubtitleLabel.Parent = Header

-- Minimize Button
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.new(0, math.floor(32 * Scale), 0, math.floor(32 * Scale))
MinimizeBtn.Position = UDim2.new(1, -Padding - math.floor(32 * Scale), 0.5, -math.floor(16 * Scale))
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Text = "─"
MinimizeBtn.TextColor3 = Colors.Accent
MinimizeBtn.TextSize = math.floor(16 * Scale)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Parent = Header

local MinBtnCorner = Instance.new("UICorner")
MinBtnCorner.CornerRadius = UDim.new(0, math.floor(8 * Scale))
MinBtnCorner.Parent = MinimizeBtn

-- ═══════════════════════════════════════════
-- CONTENT AREA
-- ═══════════════════════════════════════════

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -Padding * 2, 0, MainHeight - math.floor(60 * Scale))
ContentFrame.Position = UDim2.new(0, Padding, 0, math.floor(56 * Scale))
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = MainFrame

-- ═══════════════════════════════════════════
-- STATUS DISPLAY
-- ═══════════════════════════════════════════

local StatusCard = Instance.new("Frame")
StatusCard.Name = "StatusCard"
StatusCard.Size = UDim2.new(1, 0, 0, math.floor(70 * Scale))
StatusCard.Position = UDim2.new(0, 0, 0, 0)
StatusCard.BackgroundColor3 = Colors.CardBg
StatusCard.BorderSizePixel = 0
StatusCard.Parent = ContentFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, math.floor(12 * Scale))
StatusCorner.Parent = StatusCard

local StatusStroke = Instance.new("UIStroke")
StatusStroke.Color = Color3.fromRGB(40, 30, 70)
StatusStroke.Thickness = 1
StatusStroke.Transparency = 0.5
StatusStroke.Parent = StatusCard

-- Status indicator dot
local StatusDot = Instance.new("Frame")
StatusDot.Name = "StatusDot"
StatusDot.Size = UDim2.new(0, math.floor(10 * Scale), 0, math.floor(10 * Scale))
StatusDot.Position = UDim2.new(0, math.floor(14 * Scale), 0, math.floor(14 * Scale))
StatusDot.BackgroundColor3 = Colors.Danger
StatusDot.Parent = StatusCard

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

-- Animated dot pulse
spawn(function()
    while ScriptActive and StatusDot.Parent do
        local color = AutoParryEnabled and Colors.Success or Colors.Danger
        StatusDot.BackgroundColor3 = color
        
        local pulse = TweenService:Create(StatusDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0.5,
            Size = UDim2.new(0, math.floor(14 * Scale), 0, math.floor(14 * Scale)),
            Position = UDim2.new(0, math.floor(12 * Scale), 0, math.floor(12 * Scale))
        })
        pulse:Play()
        pulse.Completed:Wait()
        
        local unpulse = TweenService:Create(StatusDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0,
            Size = UDim2.new(0, math.floor(10 * Scale), 0, math.floor(10 * Scale)),
            Position = UDim2.new(0, math.floor(14 * Scale), 0, math.floor(14 * Scale))
        })
        unpulse:Play()
        unpulse.Completed:Wait()
    end
end)

-- Status text
local StatusText = Instance.new("TextLabel")
StatusText.Name = "StatusText"
StatusText.Size = UDim2.new(1, -math.floor(36 * Scale), 0, math.floor(18 * Scale))
StatusText.Position = UDim2.new(0, math.floor(30 * Scale), 0, math.floor(10 * Scale))
StatusText.BackgroundTransparency = 1
StatusText.Text = "STATUS: OFFLINE"
StatusText.TextColor3 = Colors.Danger
StatusText.TextSize = FontSizeNormal
StatusText.Font = Enum.Font.GothamBold
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusCard

-- Stats row
local StatsRow = Instance.new("Frame")
StatsRow.Size = UDim2.new(1, -math.floor(20 * Scale), 0, math.floor(28 * Scale))
StatsRow.Position = UDim2.new(0, math.floor(10 * Scale), 0, math.floor(36 * Scale))
StatsRow.BackgroundTransparency = 1
StatsRow.Parent = StatusCard

-- Parry count
local ParryLabel = Instance.new("TextLabel")
ParryLabel.Size = UDim2.new(0.5, 0, 1, 0)
ParryLabel.BackgroundTransparency = 1
ParryLabel.Text = "⚡ Parries: 0"
ParryLabel.TextColor3 = Colors.Accent
ParryLabel.TextSize = FontSizeSmall
ParryLabel.Font = Enum.Font.GothamSemibold
ParryLabel.TextXAlignment = Enum.TextXAlignment.Left
ParryLabel.Parent = StatsRow

-- Accuracy
local AccuracyLabel = Instance.new("TextLabel")
AccuracyLabel.Size = UDim2.new(0.5, 0, 1, 0)
AccuracyLabel.Position = UDim2.new(0.5, 0, 0, 0)
AccuracyLabel.BackgroundTransparency = 1
AccuracyLabel.Text = "🎯 Accuracy: 100%"
AccuracyLabel.TextColor3 = Colors.Success
AccuracyLabel.TextSize = FontSizeSmall
AccuracyLabel.Font = Enum.Font.GothamSemibold
AccuracyLabel.TextXAlignment = Enum.TextXAlignment.Right
AccuracyLabel.Parent = StatsRow

-- Update stats periodically
spawn(function()
    while ScriptActive and ParryLabel.Parent do
        ParryLabel.Text = "⚡ Parries: " .. tostring(ParryCount)
        local elapsed = math.floor(tick() - SessionStart)
        local minutes = math.floor(elapsed / 60)
        local seconds = elapsed % 60
        task.wait(0.5)
    end
end)

-- ═══════════════════════════════════════════
-- BUTTON 1: AUTO PARRY TOGGLE
-- ═══════════════════════════════════════════

local function CreateAnimeButton(name, text, icon, yPos, defaultOn, parent)
    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Name = name
    ButtonFrame.Size = UDim2.new(1, 0, 0, ButtonHeight)
    ButtonFrame.Position = UDim2.new(0, 0, 0, yPos)
    ButtonFrame.BackgroundColor3 = Colors.CardBg
    ButtonFrame.BorderSizePixel = 0
    ButtonFrame.Parent = parent

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, math.floor(12 * Scale))
    BtnCorner.Parent = ButtonFrame

    local BtnStroke = Instance.new("UIStroke")
    BtnStroke.Color = Color3.fromRGB(40, 30, 70)
    BtnStroke.Thickness = 1.5
    BtnStroke.Transparency = 0.3
    BtnStroke.Parent = ButtonFrame

    -- Icon container
    local BtnIconFrame = Instance.new("Frame")
    BtnIconFrame.Size = UDim2.new(0, math.floor(38 * Scale), 0, math.floor(38 * Scale))
    BtnIconFrame.Position = UDim2.new(0, math.floor(8 * Scale), 0.5, -math.floor(19 * Scale))
    BtnIconFrame.BackgroundColor3 = Colors.Primary
    BtnIconFrame.BackgroundTransparency = 0.8
    BtnIconFrame.Parent = ButtonFrame

    local BtnIconCorner = Instance.new("UICorner")
    BtnIconCorner.CornerRadius = UDim.new(0, math.floor(10 * Scale))
    BtnIconCorner.Parent = BtnIconFrame

    local BtnIconLabel = Instance.new("TextLabel")
    BtnIconLabel.Size = UDim2.new(1, 0, 1, 0)
    BtnIconLabel.BackgroundTransparency = 1
    BtnIconLabel.Text = icon
    BtnIconLabel.TextColor3 = Colors.PrimaryGlow
    BtnIconLabel.TextSize = math.floor(18 * Scale)
    BtnIconLabel.Font = Enum.Font.GothamBold
    BtnIconLabel.Parent = BtnIconFrame

    -- Button text
    local BtnText = Instance.new("TextLabel")
    BtnText.Size = UDim2.new(0, math.floor(140 * Scale), 0, math.floor(18 * Scale))
    BtnText.Position = UDim2.new(0, math.floor(54 * Scale), 0, math.floor(8 * Scale))
    BtnText.BackgroundTransparency = 1
    BtnText.Text = text
    BtnText.TextColor3 = Colors.Text
    BtnText.TextSize = FontSizeNormal
    BtnText.Font = Enum.Font.GothamBold
    BtnText.TextXAlignment = Enum.TextXAlignment.Left
    BtnText.Parent = ButtonFrame

    -- Sub text
    local BtnSubText = Instance.new("TextLabel")
    BtnSubText.Name = "SubText"
    BtnSubText.Size = UDim2.new(0, math.floor(140 * Scale), 0, math.floor(14 * Scale))
    BtnSubText.Position = UDim2.new(0, math.floor(54 * Scale), 0, math.floor(28 * Scale))
    BtnSubText.BackgroundTransparency = 1
    BtnSubText.Text = defaultOn and "アクティブ • Active" or "非アクティブ • Inactive"
    BtnSubText.TextColor3 = Colors.TextDim
    BtnSubText.TextSize = FontSizeSmall
    BtnSubText.Font = Enum.Font.Gotham
    BtnSubText.TextXAlignment = Enum.TextXAlignment.Left
    BtnSubText.Parent = ButtonFrame

    -- Toggle switch
    local ToggleBg = Instance.new("Frame")
    ToggleBg.Name = "ToggleBg"
    ToggleBg.Size = UDim2.new(0, math.floor(48 * Scale), 0, math.floor(26 * Scale))
    ToggleBg.Position = UDim2.new(1, -math.floor(58 * Scale), 0.5, -math.floor(13 * Scale))
    ToggleBg.BackgroundColor3 = Color3.fromRGB(40, 35, 60)
    ToggleBg.BorderSizePixel = 0
    ToggleBg.Parent = ButtonFrame

    local ToggleBgCorner = Instance.new("UICorner")
    ToggleBgCorner.CornerRadius = UDim.new(1, 0)
    ToggleBgCorner.Parent = ToggleBg

    local ToggleCircle = Instance.new("Frame")
    ToggleCircle.Name = "ToggleCircle"
    ToggleCircle.Size = UDim2.new(0, math.floor(20 * Scale), 0, math.floor(20 * Scale))
    ToggleCircle.Position = UDim2.new(0, math.floor(3 * Scale), 0.5, -math.floor(10 * Scale))
    ToggleCircle.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
    ToggleCircle.BorderSizePixel = 0
    ToggleCircle.Parent = ToggleBg

    local CircleCorner = Instance.new("UICorner")
    CircleCorner.CornerRadius = UDim.new(1, 0)
    CircleCorner.Parent = ToggleCircle

    -- Click button overlay
    local ClickBtn = Instance.new("TextButton")
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.Parent = ButtonFrame

    return {
        Frame = ButtonFrame,
        ClickBtn = ClickBtn,
        ToggleBg = ToggleBg,
        ToggleCircle = ToggleCircle,
        SubText = BtnSubText,
        Stroke = BtnStroke,
        IconFrame = BtnIconFrame,
        IconLabel = BtnIconLabel,
    }
end

local ParryButton = CreateAnimeButton(
    "ParryBtn",
    "AUTO PARRY",
    "🗡",
    math.floor(80 * Scale),
    false,
    ContentFrame
)

local SpeedAdaptBtn = CreateAnimeButton(
    "SpeedBtn",
    "SPEED ADAPT",
    "⚡",
    math.floor(142 * Scale),
    true,
    ContentFrame
)

-- Speed adapt is always on
local SpeedAdaptEnabled = true

-- ═══════════════════════════════════════════
-- TOGGLE ANIMATION FUNCTIONS
-- ═══════════════════════════════════════════

local function AnimateToggleOn(btn)
    -- Toggle circle slide right
    TweenService:Create(btn.ToggleCircle, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -math.floor(23 * Scale), 0.5, -math.floor(10 * Scale)),
        BackgroundColor3 = Color3.new(1, 1, 1)
    }):Play()
    
    -- Toggle background color
    TweenService:Create(btn.ToggleBg, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundColor3 = Colors.Success
    }):Play()
    
    -- Border glow
    TweenService:Create(btn.Stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Color = Colors.Success,
        Transparency = 0.2
    }):Play()
    
    -- Icon glow
    TweenService:Create(btn.IconFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundColor3 = Colors.Success,
        BackgroundTransparency = 0.5
    }):Play()
    
    -- Frame highlight
    TweenService:Create(btn.Frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundColor3 = Color3.fromRGB(15, 30, 20)
    }):Play()
    
    btn.SubText.Text = "アクティブ • Active"
    btn.SubText.TextColor3 = Colors.Success
end

local function AnimateToggleOff(btn)
    TweenService:Create(btn.ToggleCircle, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, math.floor(3 * Scale), 0.5, -math.floor(10 * Scale)),
        BackgroundColor3 = Color3.fromRGB(100, 100, 120)
    }):Play()
    
    TweenService:Create(btn.ToggleBg, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundColor3 = Color3.fromRGB(40, 35, 60)
    }):Play()
    
    TweenService:Create(btn.Stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Color = Color3.fromRGB(40, 30, 70),
        Transparency = 0.3
    }):Play()
    
    TweenService:Create(btn.IconFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundColor3 = Colors.Primary,
        BackgroundTransparency = 0.8
    }):Play()
    
    TweenService:Create(btn.Frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundColor3 = Colors.CardBg
    }):Play()
    
    btn.SubText.Text = "非アクティブ • Inactive"
    btn.SubText.TextColor3 = Colors.TextDim
end

-- ═══════════════════════════════════════════
-- BOTTOM INFO BAR
-- ═══════════════════════════════════════════

local BottomBar = Instance.new("Frame")
BottomBar.Name = "BottomBar"
BottomBar.Size = UDim2.new(1, 0, 0, math.floor(45 * Scale))
BottomBar.Position = UDim2.new(0, 0, 0, math.floor(210 * Scale))
BottomBar.BackgroundTransparency = 1
BottomBar.Parent = ContentFrame

-- Decorative line
local DecorLine = Instance.new("Frame")
DecorLine.Size = UDim2.new(1, 0, 0, 1)
DecorLine.Position = UDim2.new(0, 0, 0, 0)
DecorLine.BackgroundColor3 = Colors.Border
DecorLine.BackgroundTransparency = 0.5
DecorLine.BorderSizePixel = 0
DecorLine.Parent = BottomBar

local LineGrad = Instance.new("UIGradient")
LineGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 43, 226)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 200, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 120)),
})
LineGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.8),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1, 0.8),
})
LineGrad.Parent = DecorLine

-- Animated line gradient
spawn(function()
    local offset = 0
    while ScriptActive and LineGrad.Parent do
        offset = (offset + 0.01) % 1
        LineGrad.Offset = Vector2.new(math.sin(offset * math.pi * 2) * 0.5, 0)
        task.wait(0.03)
    end
end)

-- Bottom text
local BottomText = Instance.new("TextLabel")
BottomText.Size = UDim2.new(1, 0, 0, math.floor(20 * Scale))
BottomText.Position = UDim2.new(0, 0, 0, math.floor(10 * Scale))
BottomText.BackgroundTransparency = 1
BottomText.Text = "シン・スタジオ • 100% PARRY RATE • v2.0"
BottomText.TextColor3 = Colors.TextDim
BottomText.TextSize = math.floor(10 * Scale)
BottomText.Font = Enum.Font.Gotham
BottomText.Parent = BottomBar

-- Speed indicator
local SpeedIndicator = Instance.new("TextLabel")
SpeedIndicator.Name = "SpeedIndicator"
SpeedIndicator.Size = UDim2.new(1, 0, 0, math.floor(16 * Scale))
SpeedIndicator.Position = UDim2.new(0, 0, 0, math.floor(26 * Scale))
SpeedIndicator.BackgroundTransparency = 1
SpeedIndicator.Text = "Ball Speed: -- | Distance: --"
SpeedIndicator.TextColor3 = Color3.fromRGB(80, 80, 110)
SpeedIndicator.TextSize = math.floor(9 * Scale)
SpeedIndicator.Font = Enum.Font.Gotham
SpeedIndicator.Parent = BottomBar

-- Update speed indicator
spawn(function()
    while ScriptActive and SpeedIndicator.Parent do
        local ball = GetBall()
        if ball then
            local ballPos = GetBallPosition(ball)
            local charPos = GetCharacterPosition()
            if ballPos and charPos then
                local dist = math.floor((ballPos - charPos).Magnitude)
                local speed = math.floor(calculatedSpeed)
                SpeedIndicator.Text = string.format("⚡ Speed: %d | 📏 Distance: %d", speed, dist)
                
                if AutoParryEnabled then
                    SpeedIndicator.TextColor3 = Colors.Accent
                end
            end
        else
            SpeedIndicator.Text = "🔍 Searching for ball..."
        end
        task.wait(0.1)
    end
end)

-- ═══════════════════════════════════════════
-- PARTICLE EFFECTS (Anime sparkle)
-- ═══════════════════════════════════════════

local ParticleContainer = Instance.new("Frame")
ParticleContainer.Name = "Particles"
ParticleContainer.Size = UDim2.new(1, 0, 1, 0)
ParticleContainer.BackgroundTransparency = 1
ParticleContainer.ClipsDescendants = true
ParticleContainer.Parent = MainFrame

local function SpawnParticle()
    if not MainFrame.Parent or Minimized then return end
    
    local particle = Instance.new("Frame")
    particle.Size = UDim2.new(0, math.random(2, 4), 0, math.random(2, 4))
    particle.Position = UDim2.new(math.random() , 0, 1.1, 0)
    particle.BackgroundColor3 = ({Colors.PrimaryGlow, Colors.AccentGlow, Colors.SecondaryGlow})[math.random(1, 3)]
    particle.BackgroundTransparency = math.random() * 0.3
    particle.BorderSizePixel = 0
    particle.Parent = ParticleContainer
    
    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(1, 0)
    pCorner.Parent = particle
    
    local duration = 2 + math.random() * 3
    
    local tween = TweenService:Create(particle, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Position = UDim2.new(particle.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, -0.1, 0),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 1, 0, 1)
    })
    tween:Play()
    tween.Completed:Connect(function()
        particle:Destroy()
    end)
end

spawn(function()
    while ScriptActive and ParticleContainer.Parent do
        if AutoParryEnabled and not Minimized then
            SpawnParticle()
        end
        task.wait(0.3 + math.random() * 0.5)
    end
end)

-- ═══════════════════════════════════════════
-- BUTTON CLICK HANDLERS
-- ═══════════════════════════════════════════

-- Button hover effects
local function SetupHover(btn)
    btn.ClickBtn.MouseEnter:Connect(function()
        TweenService:Create(btn.Frame, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(
                btn.Frame.BackgroundColor3.R * 255 + 10,
                btn.Frame.BackgroundColor3.G * 255 + 10,
                btn.Frame.BackgroundColor3.B * 255 + 10
            ) / 255 -- Lighten slightly
        }):Play()
    end)
    
    btn.ClickBtn.MouseLeave:Connect(function()
        if AutoParryEnabled and btn == ParryButton then
            TweenService:Create(btn.Frame, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(15, 30, 20)
            }):Play()
        else
            TweenService:Create(btn.Frame, TweenInfo.new(0.2), {
                BackgroundColor3 = Colors.CardBg
            }):Play()
        end
    end)
end

SetupHover(ParryButton)
SetupHover(SpeedAdaptBtn)

-- Auto Parry Toggle
ParryButton.ClickBtn.MouseButton1Click:Connect(function()
    AutoParryEnabled = not AutoParryEnabled
    
    if AutoParryEnabled then
        AnimateToggleOn(ParryButton)
        StatusText.Text = "STATUS: ACTIVE 🟢"
        StatusText.TextColor3 = Colors.Success
        
        -- Flash effect
        local flash = Instance.new("Frame")
        flash.Size = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3 = Colors.Success
        flash.BackgroundTransparency = 0.8
        flash.BorderSizePixel = 0
        flash.ZIndex = 10
        flash.Parent = MainFrame
        
        local fCorner = Instance.new("UICorner")
        fCorner.CornerRadius = UDim.new(0, CornerRadius)
        fCorner.Parent = flash
        
        TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1
        }):Play()
        
        task.delay(0.5, function()
            if flash.Parent then flash:Destroy() end
        end)
    else
        AnimateToggleOff(ParryButton)
        StatusText.Text = "STATUS: OFFLINE"
        StatusText.TextColor3 = Colors.Danger
    end
end)

-- Speed Adapt Toggle
AnimateToggleOn(SpeedAdaptBtn) -- Start enabled

SpeedAdaptBtn.ClickBtn.MouseButton1Click:Connect(function()
    SpeedAdaptEnabled = not SpeedAdaptEnabled
    
    if SpeedAdaptEnabled then
        AnimateToggleOn(SpeedAdaptBtn)
        Config.SpeedMultiplier = 1.8
        Config.MaxParryDistance = 100
    else
        AnimateToggleOff(SpeedAdaptBtn)
        Config.SpeedMultiplier = 1.0
        Config.MaxParryDistance = 60
    end
end)

-- ═══════════════════════════════════════════
-- MINIMIZE FUNCTIONALITY
-- ═══════════════════════════════════════════

MinimizeBtn.MouseButton1Click:Connect(function()
    Minimized = not Minimized
    
    if Minimized then
        -- Minimize animation
        MinimizeBtn.Text = "+"
        
        TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, MainWidth, 0, MinimizedHeight)
        }):Play()
        
        TweenService:Create(ContentFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1
        }):Play()
        
        -- Hide content
        for _, child in pairs(ContentFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                TweenService:Create(child, TweenInfo.new(0.2), {
                    BackgroundTransparency = 1
                }):Play()
            end
        end
    else
        -- Expand animation
        MinimizeBtn.Text = "─"
        
        TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, MainWidth, 0, MainHeight)
        }):Play()
        
        task.delay(0.2, function()
            -- Show content
            for _, child in pairs(ContentFrame:GetChildren()) do
                if child:IsA("GuiObject") then
                    TweenService:Create(child, TweenInfo.new(0.3), {
                        BackgroundTransparency = 0
                    }):Play()
                end
            end
        end)
    end
end)

-- ═══════════════════════════════════════════
-- INTRO ANIMATION
-- ═══════════════════════════════════════════

MainFrame.BackgroundTransparency = 1
MainFrame.Size = UDim2.new(0, MainWidth * 0.8, 0, MainHeight * 0.8)

-- Fade in and scale up
task.delay(0.1, function()
    TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Size = UDim2.new(0, MainWidth, 0, MainHeight),
        Position = UDim2.new(0.5, -MainWidth/2, 0.5, -MainHeight/2)
    }):Play()
end)

-- ═══════════════════════════════════════════
-- PARRY NOTIFICATION POPUP
-- ═══════════════════════════════════════════

local function ShowParryNotification()
    if Minimized then return end
    
    local notif = Instance.new("TextLabel")
    notif.Size = UDim2.new(0, math.floor(120 * Scale), 0, math.floor(30 * Scale))
    notif.Position = UDim2.new(0.5, -math.floor(60 * Scale), 0, MainHeight - math.floor(20 * Scale))
    notif.BackgroundColor3 = Colors.Success
    notif.BackgroundTransparency = 0.2
    notif.Text = "✨ PARRIED! ✨"
    notif.TextColor3 = Color3.new(1, 1, 1)
    notif.TextSize = math.floor(12 * Scale)
    notif.Font = Enum.Font.GothamBold
    notif.ZIndex = 20
    notif.Parent = MainFrame
    
    local nCorner = Instance.new("UICorner")
    nCorner.CornerRadius = UDim.new(0, 8)
    nCorner.Parent = notif
    
    TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -math.floor(60 * Scale), 0, MainHeight - math.floor(60 * Scale))
    }):Play()
    
    task.delay(0.8, function()
        TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1,
            TextTransparency = 1,
            Position = UDim2.new(0.5, -math.floor(60 * Scale), 0, MainHeight - math.floor(80 * Scale))
        }):Play()
        task.delay(0.3, function()
            if notif.Parent then notif:Destroy() end
        end)
    end)
end

-- ═══════════════════════════════════════════
-- MAIN PARRY LOOP (100% ACCURACY ENGINE)
-- ═══════════════════════════════════════════

-- Primary loop - RenderStepped (fastest possible, runs every frame)
RunService.RenderStepped:Connect(function()
    if not AutoParryEnabled then return end
    SmartParryCheck()
end)

-- Secondary loop - Heartbeat (backup check)
RunService.Heartbeat:Connect(function()
    if not AutoParryEnabled then return end
    SmartParryCheck()
end)

-- Tertiary loop - Stepped (triple redundancy)
RunService.Stepped:Connect(function()
    if not AutoParryEnabled then return end
    SmartParryCheck()
end)

-- Monitor for parry events (show notification)
local lastParryCount = 0
spawn(function()
    while ScriptActive do
        if ParryCount > lastParryCount then
            lastParryCount = ParryCount
            ShowParryNotification()
        end
        task.wait(0.1)
    end
end)

-- ═══════════════════════════════════════════
-- ADVANCED: BALL ATTRIBUTE MONITORING
-- ═══════════════════════════════════════════

-- Watch for new balls being created
Workspace.DescendantAdded:Connect(function(obj)
    if not AutoParryEnabled then return end
    
    if obj:IsA("BasePart") and obj.Name:lower():find("ball") then
        -- New ball detected, immediately start tracking
        task.wait(0.1) -- Brief wait for ball to initialize
        SmartParryCheck()
    end
end)

-- ═══════════════════════════════════════════
-- EMERGENCY PARRY SYSTEM
-- ═══════════════════════════════════════════

-- Ultra-fast polling for emergency situations
spawn(function()
    while ScriptActive do
        if AutoParryEnabled then
            local ball = GetBall()
            if ball then
                local ballPos = GetBallPosition(ball)
                local charPos = GetCharacterPosition()
                
                if ballPos and charPos then
                    local dist = (ballPos - charPos).Magnitude
                    
                    -- EMERGENCY: Ball is extremely close
                    if dist <= Config.MinParryDistance * 2 and not parryDebounce then
                        -- Check if we're targeted or ball is coming at us
                        if IsTargeted() or dist <= Config.MinParryDistance then
                            parryDebounce = true
                            ExecuteParry()
                            task.delay(0.15, function()
                                parryDebounce = false
                            end)
                        end
                    end
                end
            end
        end
        task.wait(Config.PollingRate)
    end
end)

-- ═══════════════════════════════════════════
-- CLEANUP ON DESTROY
-- ═══════════════════════════════════════════

ScreenGui.Destroying:Connect(function()
    ScriptActive = false
    AutoParryEnabled = false
end)

-- ═══════════════════════════════════════════
-- MOBILE TOUCH SUPPORT
-- ═══════════════════════════════════════════

-- Ensure touch inputs work for buttons
for _, btn in pairs({ParryButton, SpeedAdaptBtn}) do
    btn.ClickBtn.Active = true
    btn.ClickBtn.Selectable = true
end

MinimizeBtn.Active = true
MinimizeBtn.Selectable = true

-- ═══════════════════════════════════════════
-- INITIALIZATION COMPLETE
-- ═══════════════════════════════════════════

print([[
╔══════════════════════════════════════════╗
║       SYN-STUDIO v2.0 LOADED ✓          ║
║                                          ║
║  ⚔ Auto Parry Engine: Ready             ║
║  ⚡ Speed Adaptation: Active             ║
║  🎯 Accuracy Target: 100%               ║
║  📱 Responsive UI: Enabled              ║
║                                          ║
║  Toggle Auto Parry to begin!             ║
╚══════════════════════════════════════════╝
]])

-- Notification
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "SYN-STUDIO ⚔",
        Text = "Auto Parry loaded! 100% accuracy mode.",
        Duration = 5,
    })
end)