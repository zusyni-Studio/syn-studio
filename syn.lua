--[[
    ╔══════════════════════════════════════════════════════╗
    ║              SYN-STUDIO v2.0                        ║
    ║         Blade Ball Auto Parry Script                ║
    ║     Perfect Parry • Zero Miss • Anime UI            ║
    ║             (STABLE & SAFE EDITION)                  ║
    ╚══════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════
-- SAFE SERVICES (cloneref to prevent detection)
-- ═══════════════════════════════════════════
local function GetSafeService(serviceName)
    local success, service = pcall(function()
        if cloneref then
            return cloneref(game:GetService(serviceName))
        end
        return game:GetService(serviceName)
    end)
    return success and service or game:GetService(serviceName)
end

local Players = GetSafeService("Players")
local RunService = GetSafeService("RunService")
local ReplicatedStorage = GetSafeService("ReplicatedStorage")
local UserInputService = GetSafeService("UserInputService")
local TweenService = GetSafeService("TweenService")
local Workspace = GetSafeService("Workspace")
local StarterGui = GetSafeService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ═══════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════
local Config = {
    AutoParry = true,
    ParryDistance = 55, -- Base parry distance
    MinParryDistance = 15, -- Minimum distance for fast balls
    MaxParryDistance = 85, -- Maximum distance for slow balls
    SpeedMultiplier = 1.0,
    PredictionEnabled = true,
    SmartTiming = true,
    VisualEffects = true,
    SoundEffects = true,
    ShowBallESP = true,
    ShowDistanceIndicator = true,
    ParrySuccessCount = 0,
    TotalParryAttempts = 0,
    Theme = "Anime",
}

-- ═══════════════════════════════════════════
-- COLOR PALETTE (Anime Theme)
-- ═══════════════════════════════════════════
local Colors = {
    Primary = Color3.fromRGB(255, 85, 125),       -- Sakura Pink
    Secondary = Color3.fromRGB(120, 80, 255),      -- Purple
    Accent = Color3.fromRGB(255, 170, 50),         -- Orange Gold
    Success = Color3.fromRGB(80, 255, 120),        -- Green
    Danger = Color3.fromRGB(255, 60, 60),          -- Red
    Background = Color3.fromRGB(15, 15, 25),       -- Dark BG
    BackgroundLight = Color3.fromRGB(25, 25, 45),  -- Lighter BG
    Card = Color3.fromRGB(30, 30, 55),             -- Card BG
    CardHover = Color3.fromRGB(40, 40, 70),        -- Card Hover
    Text = Color3.fromRGB(255, 255, 255),           -- White
    TextDim = Color3.fromRGB(180, 180, 200),       -- Dim text
    Border = Color3.fromRGB(60, 60, 100),          -- Border
    GlowPink = Color3.fromRGB(255, 100, 150),     -- Glow
    GlowPurple = Color3.fromRGB(150, 100, 255),   -- Glow Purple
    GlowBlue = Color3.fromRGB(80, 150, 255),      -- Glow Blue
}

-- ═══════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════
local function CreateCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function CreateStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Colors.Border
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.5
    stroke.Parent = parent
    return stroke
end

local function CreateGradient(parent, color1, color2, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(color1 or Colors.Primary, color2 or Colors.Secondary)
    gradient.Rotation = rotation or 45
    gradient.Parent = parent
    return gradient
end

local function CreateShadow(parent, size)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://7912134082"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.Size = UDim2.new(1, size or 30, 1, size or 30)
    shadow.Position = UDim2.new(0, -(size or 30)/2, 0, -(size or 30)/2)
    shadow.ZIndex = parent.ZIndex - 1
    shadow.Parent = shadow.Parent -- Safe hierarchy parenting
    pcall(function() shadow.Parent = parent end)
    return shadow
end

local function Tween(obj, props, duration, style, direction)
    local tween = TweenService:Create(obj, TweenInfo.new(
        duration or 0.3,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    ), props)
    tween:Play()
    return tween
end

local function RippleEffect(button)
    local ripple = Instance.new("Frame")
    ripple.Name = "Ripple"
    ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ripple.BackgroundTransparency = 0.7
    ripple.BorderSizePixel = 0
    ripple.ZIndex = button.ZIndex + 5
    ripple.Parent = button
    CreateCorner(ripple, 999)

    local mouse = UserInputService:GetMouseLocation()
    local absPos = button.AbsolutePosition
    local relX = mouse.X - absPos.X
    local relY = mouse.Y - absPos.Y

    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.Position = UDim2.new(0, relX, 0, relY)
    ripple.AnchorPoint = Vector2.new(0.5, 0.5)

    local maxSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.5
    Tween(ripple, {
        Size = UDim2.new(0, maxSize, 0, maxSize),
        BackgroundTransparency = 1
    }, 0.6, Enum.EasingStyle.Quint)

    task.delay(0.6, function()
        ripple:Destroy()
    end)
end

-- ═══════════════════════════════════════════
-- SAFE MAIN GUI CREATION (Anti-Crash)
-- ═══════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SynStudio_" .. tostring(math.random(100, 999))
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999

-- Metode teraman menaruh GUI agar tidak terdeteksi game & tidak crash
local parented = false
if gethui then
    pcall(function()
        ScreenGui.Parent = gethui()
        parented = true
    end)
end
if not parented then
    pcall(function()
        ScreenGui.Parent = game:GetService("CoreGui")
        parented = true
    end)
end
if not parented then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ═══════════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ═══════════════════════════════════════════
local NotificationHolder = Instance.new("Frame")
NotificationHolder.Name = "Notifications"
NotificationHolder.BackgroundTransparency = 1
NotificationHolder.Size = UDim2.new(0, 300, 1, 0)
NotificationHolder.Position = UDim2.new(1, -320, 0, 0)
NotificationHolder.Parent = ScreenGui

local NotifLayout = Instance.new("UIListLayout")
NotifLayout.Padding = UDim.new(0, 8)
NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotifLayout.Parent = NotificationHolder

local NotifPadding = Instance.new("UIPadding")
NotifPadding.PaddingBottom = UDim.new(0, 20)
NotifPadding.Parent = NotificationHolder

local function Notify(title, message, duration, notifType)
    local color = Colors.Primary
    if notifType == "success" then color = Colors.Success
    elseif notifType == "error" then color = Colors.Danger
    elseif notifType == "warning" then color = Colors.Accent end

    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.BackgroundColor3 = Colors.Card
    notif.Size = UDim2.new(1, 0, 0, 70)
    notif.ClipsDescendants = true
    notif.Parent = NotificationHolder
    CreateCorner(notif, 10)
    CreateStroke(notif, color, 1.5, 0.3)

    -- Accent bar
    local accentBar = Instance.new("Frame")
    accentBar.BackgroundColor3 = color
    accentBar.Size = UDim2.new(0, 4, 1, 0)
    accentBar.BorderSizePixel = 0
    accentBar.Parent = notif

    -- Icon
    local icon = Instance.new("TextLabel")
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, 30, 0, 30)
    icon.Position = UDim2.new(0, 15, 0, 10)
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 20
    icon.TextColor3 = color
    icon.Parent = notif

    if notifType == "success" then icon.Text = "✓"
    elseif notifType == "error" then icon.Text = "✕"
    elseif notifType == "warning" then icon.Text = "⚠"
    else icon.Text = "★" end

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -60, 0, 22)
    titleLabel.Position = UDim2.new(0, 50, 0, 10)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = Colors.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = title
    titleLabel.Parent = notif

    -- Message
    local msgLabel = Instance.new("TextLabel")
    msgLabel.BackgroundTransparency = 1
    msgLabel.Size = UDim2.new(1, -60, 0, 20)
    msgLabel.Position = UDim2.new(0, 50, 0, 34)
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextSize = 11
    msgLabel.TextColor3 = Colors.TextDim
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.Text = message
    msgLabel.Parent = notif

    -- Progress bar
    local progressBg = Instance.new("Frame")
    progressBg.BackgroundColor3 = Colors.BackgroundLight
    progressBg.Size = UDim2.new(1, -20, 0, 3)
    progressBg.Position = UDim2.new(0, 10, 1, -8)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = notif
    CreateCorner(progressBg, 2)

    local progressFill = Instance.new("Frame")
    progressFill.BackgroundColor3 = color
    progressFill.Size = UDim2.new(1, 0, 1, 0)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg
    CreateCorner(progressFill, 2)

    -- Animate in
    notif.BackgroundTransparency = 1
    notif.Size = UDim2.new(1, 0, 0, 0)
    Tween(notif, {Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 0}, 0.4)
    Tween(progressFill, {Size = UDim2.new(0, 0, 1, 0)}, duration or 3, Enum.EasingStyle.Linear)

    task.delay(duration or 3, function()
        Tween(notif, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.3)
        task.delay(0.35, function()
            notif:Destroy()
        end)
    end)
end

-- ═══════════════════════════════════════════
-- MAIN WINDOW
-- ═══════════════════════════════════════════
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.Size = UDim2.new(0, 480, 0, 560)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -280)
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
CreateCorner(MainFrame, 14)
CreateStroke(MainFrame, Colors.Border, 1, 0.4)
CreateShadow(MainFrame, 50)

-- Background glow effects
local bgGlow1 = Instance.new("Frame")
bgGlow1.Name = "BgGlow1"
bgGlow1.BackgroundColor3 = Colors.Primary
bgGlow1.BackgroundTransparency = 0.92
bgGlow1.Size = UDim2.new(0, 200, 0, 200)
bgGlow1.Position = UDim2.new(0, -50, 0, -50)
bgGlow1.BorderSizePixel = 0
bgGlow1.ZIndex = 0
bgGlow1.Parent = MainFrame
CreateCorner(bgGlow1, 100)

local bgGlow2 = Instance.new("Frame")
bgGlow2.Name = "BgGlow2"
bgGlow2.BackgroundColor3 = Colors.Secondary
bgGlow2.BackgroundTransparency = 0.92
bgGlow2.Size = UDim2.new(0, 250, 0, 250)
bgGlow2.Position = UDim2.new(1, -150, 1, -150)
bgGlow2.BorderSizePixel = 0
bgGlow2.ZIndex = 0
bgGlow2.Parent = MainFrame
CreateCorner(bgGlow2, 125)

-- Animate background glows
task.spawn(function()
    while ScreenGui.Parent do
        Tween(bgGlow1, {Position = UDim2.new(0, -30, 0, -30)}, 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(3)
        Tween(bgGlow1, {Position = UDim2.new(0, -70, 0, -70)}, 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(3)
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        Tween(bgGlow2, {Position = UDim2.new(1, -130, 1, -130)}, 4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(4)
        Tween(bgGlow2, {Position = UDim2.new(1, -170, 1, -170)}, 4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(4)
    end
end)

-- ═══════════════════════════════════════════
-- TITLE BAR
-- ═══════════════════════════════════════════
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.BackgroundColor3 = Colors.BackgroundLight
TitleBar.Size = UDim2.new(1, 0, 0, 55)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 5
TitleBar.Parent = MainFrame
CreateCorner(TitleBar, 14)

-- Fix bottom corners of title bar
local titleBarFix = Instance.new("Frame")
titleBarFix.BackgroundColor3 = Colors.BackgroundLight
titleBarFix.Size = UDim2.new(1, 0, 0, 15)
titleBarFix.Position = UDim2.new(0, 0, 1, -15)
titleBarFix.BorderSizePixel = 0
titleBarFix.ZIndex = 5
titleBarFix.Parent = TitleBar

-- Title gradient line
local titleGradientLine = Instance.new("Frame")
titleGradientLine.BackgroundColor3 = Colors.Primary
titleGradientLine.Size = UDim2.new(1, 0, 0, 2)
titleGradientLine.Position = UDim2.new(0, 0, 1, -2)
titleGradientLine.BorderSizePixel = 0
titleGradientLine.ZIndex = 6
titleGradientLine.Parent = TitleBar
CreateGradient(titleGradientLine, Colors.Primary, Colors.Secondary, 0)

-- Logo icon (anime style star)
local logoFrame = Instance.new("Frame")
logoFrame.BackgroundColor3 = Colors.Primary
logoFrame.Size = UDim2.new(0, 35, 0, 35)
logoFrame.Position = UDim2.new(0, 12, 0.5, -17)
logoFrame.ZIndex = 7
logoFrame.Parent = TitleBar
CreateCorner(logoFrame, 10)
CreateGradient(logoFrame, Colors.Primary, Colors.GlowPurple, 135)

local logoText = Instance.new("TextLabel")
logoText.BackgroundTransparency = 1
logoText.Size = UDim2.new(1, 0, 1, 0)
logoText.Font = Enum.Font.GothamBold
logoText.TextSize = 18
logoText.TextColor3 = Colors.Text
logoText.Text = "⚔"
logoText.ZIndex = 8
logoText.Parent = logoFrame

-- Rotate logo animation
task.spawn(function()
    while ScreenGui.Parent do
        Tween(logoFrame, {Rotation = 10}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(1.5)
        Tween(logoFrame, {Rotation = -10}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(1.5)
    end
end)

-- Title text
local titleText = Instance.new("TextLabel")
titleText.BackgroundTransparency = 1
titleText.Size = UDim2.new(0, 200, 0, 25)
titleText.Position = UDim2.new(0, 55, 0, 8)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 17
titleText.TextColor3 = Colors.Text
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Text = "SYN-STUDIO"
titleText.ZIndex = 7
titleText.Parent = TitleBar

-- Subtitle
local subtitleText = Instance.new("TextLabel")
subtitleText.BackgroundTransparency = 1
subtitleText.Size = UDim2.new(0, 200, 0, 15)
subtitleText.Position = UDim2.new(0, 55, 0, 32)
subtitleText.Font = Enum.Font.Gotham
subtitleText.TextSize = 10
subtitleText.TextColor3 = Colors.TextDim
subtitleText.TextXAlignment = Enum.TextXAlignment.Left
subtitleText.Text = "⚡ Blade Ball Auto Parry • v2.0"
subtitleText.ZIndex = 7
subtitleText.Parent = TitleBar

-- Status indicator
local statusDot = Instance.new("Frame")
statusDot.BackgroundColor3 = Colors.Success
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(1, -70, 0.5, -4)
statusDot.ZIndex = 7
statusDot.Parent = TitleBar
CreateCorner(statusDot, 4)

-- Pulse animation for status dot
task.spawn(function()
    while ScreenGui.Parent do
        Tween(statusDot, {BackgroundTransparency = 0.5}, 0.8, Enum.EasingStyle.Sine)
        task.wait(0.8)
        Tween(statusDot, {BackgroundTransparency = 0}, 0.8, Enum.EasingStyle.Sine)
        task.wait(0.8)
    end
end)

local statusText = Instance.new("TextLabel")
statusText.BackgroundTransparency = 1
statusText.Size = UDim2.new(0, 45, 0, 20)
statusText.Position = UDim2.new(1, -55, 0.5, -10)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 10
statusText.TextColor3 = Colors.Success
statusText.Text = "ACTIVE"
statusText.ZIndex = 7
statusText.Parent = TitleBar

-- Minimize button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.BackgroundColor3 = Colors.Card
minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
minimizeBtn.Position = UDim2.new(1, -35, 0.5, -15)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.TextColor3 = Colors.TextDim
minimizeBtn.Text = "−"
minimizeBtn.ZIndex = 8
minimizeBtn.Parent = TitleBar
CreateCorner(minimizeBtn, 8)

-- ═══════════════════════════════════════════
-- DRAGGING FUNCTIONALITY
-- ═══════════════════════════════════════════
local dragging, dragInput, dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Tween(MainFrame, {
            Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        }, 0.08, Enum.EasingStyle.Quad)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ═══════════════════════════════════════════
-- CONTENT AREA
-- ═══════════════════════════════════════════
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Name = "Content"
ContentFrame.BackgroundTransparency = 1
ContentFrame.Size = UDim2.new(1, -20, 1, -65)
ContentFrame.Position = UDim2.new(0, 10, 0, 60)
ContentFrame.ScrollBarThickness = 3
ContentFrame.ScrollBarImageColor3 = Colors.Primary
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 850)
ContentFrame.ZIndex = 3
ContentFrame.Parent = MainFrame

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 10)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = ContentFrame

-- ═══════════════════════════════════════════
-- STATS DASHBOARD
-- ═══════════════════════════════════════════
local StatsCard = Instance.new("Frame")
StatsCard.Name = "StatsCard"
StatsCard.BackgroundColor3 = Colors.Card
StatsCard.Size = UDim2.new(1, 0, 0, 90)
StatsCard.LayoutOrder = 1
StatsCard.ZIndex = 4
StatsCard.Parent = ContentFrame
CreateCorner(StatsCard, 12)
CreateStroke(StatsCard, Colors.Border, 1, 0.6)

-- Stats header
local statsHeader = Instance.new("TextLabel")
statsHeader.BackgroundTransparency = 1
statsHeader.Size = UDim2.new(1, 0, 0, 25)
statsHeader.Position = UDim2.new(0, 15, 0, 8)
statsHeader.Font = Enum.Font.GothamBold
statsHeader.TextSize = 12
statsHeader.TextColor3 = Colors.TextDim
statsHeader.TextXAlignment = Enum.TextXAlignment.Left
statsHeader.Text = "📊 LIVE STATISTICS"
statsHeader.ZIndex = 5
statsHeader.Parent = StatsCard

-- Stat boxes
local function CreateStatBox(parent, posX, icon, label, value, color)
    local box = Instance.new("Frame")
    box.BackgroundColor3 = Colors.BackgroundLight
    box.Size = UDim2.new(0, 130, 0, 48)
    box.Position = UDim2.new(0, posX, 0, 35)
    box.ZIndex = 5
    box.Parent = parent
    CreateCorner(box, 8)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.BackgroundTransparency = 1
    iconLabel.Size = UDim2.new(0, 25, 1, 0)
    iconLabel.Position = UDim2.new(0, 8, 0, 0)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 16
    iconLabel.TextColor3 = color
    iconLabel.Text = icon
    iconLabel.ZIndex = 6
    iconLabel.Parent = box

    local labelText = Instance.new("TextLabel")
    labelText.BackgroundTransparency = 1
    labelText.Size = UDim2.new(1, -40, 0, 15)
    labelText.Position = UDim2.new(0, 35, 0, 6)
    labelText.Font = Enum.Font.Gotham
    labelText.TextSize = 9
    labelText.TextColor3 = Colors.TextDim
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.Text = label
    labelText.ZIndex = 6
    labelText.Parent = box

    local valueText = Instance.new("TextLabel")
    valueText.Name = "Value"
    valueText.BackgroundTransparency = 1
    valueText.Size = UDim2.new(1, -40, 0, 20)
    valueText.Position = UDim2.new(0, 35, 0, 22)
    valueText.Font = Enum.Font.GothamBold
    valueText.TextSize = 15
    valueText.TextColor3 = color
    valueText.TextXAlignment = Enum.TextXAlignment.Left
    valueText.Text = value
    valueText.ZIndex = 6
    valueText.Parent = box

    return valueText
end

local parryCountLabel = CreateStatBox(StatsCard, 15, "⚔", "PARRIES", "0", Colors.Primary)
local successRateLabel = CreateStatBox(StatsCard, 155, "✦", "SUCCESS", "100%", Colors.Success)
local ballSpeedLabel = CreateStatBox(StatsCard, 295, "⚡", "BALL SPEED", "0", Colors.Accent)

-- ═══════════════════════════════════════════
-- SECTION: AUTO PARRY
-- ═══════════════════════════════════════════
local function CreateSection(title, icon, layoutOrder)
    local section = Instance.new("Frame")
    section.Name = title
    section.BackgroundColor3 = Colors.Card
    section.Size = UDim2.new(1, 0, 0, 0) -- Will be auto-sized
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.LayoutOrder = layoutOrder
    section.ZIndex = 4
    section.Parent = ContentFrame
    CreateCorner(section, 12)
    CreateStroke(section, Colors.Border, 1, 0.6)

    local sectionPadding = Instance.new("UIPadding")
    sectionPadding.PaddingTop = UDim.new(0, 12)
    sectionPadding.PaddingBottom = UDim.new(0, 12)
    sectionPadding.PaddingLeft = UDim.new(0, 15)
    sectionPadding.PaddingRight = UDim.new(0, 15)
    sectionPadding.Parent = section

    local sectionLayout = Instance.new("UIListLayout")
    sectionLayout.Padding = UDim.new(0, 10)
    sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sectionLayout.Parent = section

    -- Header
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 22)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 13
    header.TextColor3 = Colors.Text
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Text = icon .. "  " .. title
    header.LayoutOrder = 0
    header.ZIndex = 5
    header.Parent = section

    -- Divider
    local divider = Instance.new("Frame")
    divider.BackgroundColor3 = Colors.Border
    divider.BackgroundTransparency = 0.5
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.BorderSizePixel = 0
    divider.LayoutOrder = 1
    divider.ZIndex = 5
    divider.Parent = section

    return section
end

-- Toggle Switch Creator
local function CreateToggle(parent, label, default, layoutOrder, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.BackgroundColor3 = Colors.BackgroundLight
    toggleFrame.Size = UDim2.new(1, 0, 0, 40)
    toggleFrame.LayoutOrder = layoutOrder
    toggleFrame.ZIndex = 5
    toggleFrame.Parent = parent
    CreateCorner(toggleFrame, 8)

    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Size = UDim2.new(1, -65, 1, 0)
    toggleLabel.Position = UDim2.new(0, 12, 0, 0)
    toggleLabel.Font = Enum.Font.Gotham
    toggleLabel.TextSize = 12
    toggleLabel.TextColor3 = Colors.Text
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    toggleLabel.Text = label
    toggleLabel.ZIndex = 6
    toggleLabel.Parent = toggleFrame

    local toggleBg = Instance.new("Frame")
    toggleBg.BackgroundColor3 = default and Colors.Primary or Color3.fromRGB(60, 60, 80)
    toggleBg.Size = UDim2.new(0, 44, 0, 22)
    toggleBg.Position = UDim2.new(1, -54, 0.5, -11)
    toggleBg.ZIndex = 6
    toggleBg.Parent = toggleFrame
    CreateCorner(toggleBg, 11)

    local toggleCircle = Instance.new("Frame")
    toggleCircle.BackgroundColor3 = Colors.Text
    toggleCircle.Size = UDim2.new(0, 18, 0, 18)
    toggleCircle.Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    toggleCircle.ZIndex = 7
    toggleCircle.Parent = toggleBg
    CreateCorner(toggleCircle, 9)

    local enabled = default
    local toggleButton = Instance.new("TextButton")
    toggleButton.BackgroundTransparency = 1
    toggleButton.Size = UDim2.new(1, 0, 1, 0)
    toggleButton.Text = ""
    toggleButton.ZIndex = 8
    toggleButton.Parent = toggleFrame

    toggleButton.MouseButton1Click:Connect(function()
        enabled = not enabled
        RippleEffect(toggleFrame)

        if enabled then
            Tween(toggleBg, {BackgroundColor3 = Colors.Primary}, 0.3)
            Tween(toggleCircle, {Position = UDim2.new(1, -20, 0.5, -9)}, 0.3, Enum.EasingStyle.Back)
        else
            Tween(toggleBg, {BackgroundColor3 = Color3.fromRGB(60, 60, 80)}, 0.3)
            Tween(toggleCircle, {Position = UDim2.new(0, 2, 0.5, -9)}, 0.3, Enum.EasingStyle.Back)
        end

        if callback then callback(enabled) end
    end)

    -- Hover effect
    toggleButton.MouseEnter:Connect(function()
        Tween(toggleFrame, {BackgroundColor3 = Colors.CardHover}, 0.2)
    end)
    toggleButton.MouseLeave:Connect(function()
        Tween(toggleFrame, {BackgroundColor3 = Colors.BackgroundLight}, 0.2)
    end)

    return toggleFrame
end

-- Slider Creator
local function CreateSlider(parent, label, min, max, default, layoutOrder, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.BackgroundColor3 = Colors.BackgroundLight
    sliderFrame.Size = UDim2.new(1, 0, 0, 55)
    sliderFrame.LayoutOrder = layoutOrder
    sliderFrame.ZIndex = 5
    sliderFrame.Parent = parent
    CreateCorner(sliderFrame, 8)

    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Size = UDim2.new(1, -60, 0, 20)
    sliderLabel.Position = UDim2.new(0, 12, 0, 6)
    sliderLabel.Font = Enum.Font.Gotham
    sliderLabel.TextSize = 11
    sliderLabel.TextColor3 = Colors.Text
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    sliderLabel.Text = label
    sliderLabel.ZIndex = 6
    sliderLabel.Parent = sliderFrame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.BackgroundTransparency = 1
    valueLabel.Size = UDim2.new(0, 50, 0, 20)
    valueLabel.Position = UDim2.new(1, -55, 0, 6)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 12
    valueLabel.TextColor3 = Colors.Primary
    valueLabel.Text = tostring(default)
    valueLabel.ZIndex = 6
    valueLabel.Parent = sliderFrame

    local sliderBg = Instance.new("Frame")
    sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
    sliderBg.Size = UDim2.new(1, -24, 0, 8)
    sliderBg.Position = UDim2.new(0, 12, 0, 35)
    sliderBg.ZIndex = 6
    sliderBg.Parent = sliderFrame
    CreateCorner(sliderBg, 4)

    local sliderFill = Instance.new("Frame")
    sliderFill.BackgroundColor3 = Colors.Primary
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.BorderSizePixel = 0
    sliderFill.ZIndex = 7
    sliderFill.Parent = sliderBg
    CreateCorner(sliderFill, 4)
    CreateGradient(sliderFill, Colors.Primary, Colors.GlowPurple, 0)

    local sliderKnob = Instance.new("Frame")
    sliderKnob.BackgroundColor3 = Colors.Text
    sliderKnob.Size = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position = UDim2.new((default - min) / (max - min), -8, 0.5, -8)
    sliderKnob.ZIndex = 8
    sliderKnob.Parent = sliderBg
    CreateCorner(sliderKnob, 8)
    CreateStroke(sliderKnob, Colors.Primary, 2, 0)

    -- Slider interaction
    local sliding = false
    local sliderButton = Instance.new("TextButton")
    sliderButton.BackgroundTransparency = 1
    sliderButton.Size = UDim2.new(1, 0, 0, 25)
    sliderButton.Position = UDim2.new(0, 0, 0, 28)
    sliderButton.Text = ""
    sliderButton.ZIndex = 9
    sliderButton.Parent = sliderFrame

    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
            rel = math.clamp(rel, 0, 1)
            local value = math.floor(min + (max - min) * rel)

            Tween(sliderFill, {Size = UDim2.new(rel, 0, 1, 0)}, 0.05)
            Tween(sliderKnob, {Position = UDim2.new(rel, -8, 0.5, -8)}, 0.05)
            valueLabel.Text = tostring(value)

            if callback then callback(value) end
        end
    end)

    return sliderFrame
end

-- ═══════════════════════════════════════════
-- CREATE SECTIONS
-- ═══════════════════════════════════════════

-- Auto Parry Section
local parrySection = CreateSection("AUTO PARRY", "⚔", 2)

CreateToggle(parrySection, "Enable Auto Parry", true, 2, function(enabled)
    Config.AutoParry = enabled
    statusText.Text = enabled and "ACTIVE" or "IDLE"
    statusText.TextColor3 = enabled and Colors.Success or Colors.Danger
    statusDot.BackgroundColor3 = enabled and Colors.Success or Colors.Danger
    Notify("Auto Parry", enabled and "Auto Parry Enabled ⚔" or "Auto Parry Disabled", 2, enabled and "success" or "warning")
end)

CreateToggle(parrySection, "Smart Timing (Speed Adaptive)", true, 3, function(enabled)
    Config.SmartTiming = enabled
end)

CreateToggle(parrySection, "Prediction System", true, 4, function(enabled)
    Config.PredictionEnabled = enabled
end)

CreateSlider(parrySection, "Base Parry Distance", 10, 100, 55, 5, function(value)
    Config.ParryDistance = value
end)

CreateSlider(parrySection, "Speed Multiplier (×10)", 5, 20, 10, 6, function(value)
    Config.SpeedMultiplier = value / 10
end)

-- Visual Section
local visualSection = CreateSection("VISUALS & ESP", "👁", 3)

CreateToggle(visualSection, "Visual Effects", true, 2, function(enabled)
    Config.VisualEffects = enabled
end)

CreateToggle(visualSection, "Ball ESP Highlight", true, 3, function(enabled)
    Config.ShowBallESP = enabled
end)

CreateToggle(visualSection, "Distance Indicator", true, 4, function(enabled)
    Config.ShowDistanceIndicator = enabled
end)

-- Settings Section
local settingsSection = CreateSection("SETTINGS", "⚙", 4)

CreateToggle(settingsSection, "Sound Effects", true, 2, function(enabled)
    Config.SoundEffects = enabled
end)

-- ═══════════════════════════════════════════
-- CREDITS SECTION
-- ═══════════════════════════════════════════
local creditsCard = Instance.new("Frame")
creditsCard.Name = "Credits"
creditsCard.BackgroundColor3 = Colors.Card
creditsCard.Size = UDim2.new(1, 0, 0, 60)
creditsCard.LayoutOrder = 5
creditsCard.ZIndex = 4
creditsCard.Parent = ContentFrame
CreateCorner(creditsCard, 12)
CreateStroke(creditsCard, Colors.Primary, 1, 0.5)

local creditsGradient = Instance.new("Frame")
creditsGradient.BackgroundColor3 = Colors.Primary
creditsGradient.BackgroundTransparency = 0.9
creditsGradient.Size = UDim2.new(1, 0, 1, 0)
creditsGradient.BorderSizePixel = 0
creditsGradient.ZIndex = 4
creditsGradient.Parent = creditsCard
CreateCorner(creditsGradient, 12)
CreateGradient(creditsGradient, Colors.Primary, Colors.Secondary, 45)

local creditsText = Instance.new("TextLabel")
creditsText.BackgroundTransparency = 1
creditsText.Size = UDim2.new(1, 0, 0, 25)
creditsText.Position = UDim2.new(0, 0, 0, 10)
creditsText.Font = Enum.Font.GothamBold
creditsText.TextSize = 14
creditsText.TextColor3 = Colors.Text
creditsText.Text = "★ SYN-STUDIO ★"
creditsText.ZIndex = 6
creditsText.Parent = creditsCard

local creditsSubText = Instance.new("TextLabel")
creditsSubText.BackgroundTransparency = 1
creditsSubText.Size = UDim2.new(1, 0, 0, 15)
creditsSubText.Position = UDim2.new(0, 0, 0, 35)
creditsSubText.Font = Enum.Font.Gotham
creditsSubText.TextSize = 10
creditsSubText.TextColor3 = Colors.TextDim
creditsSubText.Text = "Perfect Parry • Zero Miss • Made with ❤"
creditsSubText.ZIndex = 6
creditsSubText.Parent = creditsCard

-- ═══════════════════════════════════════════
-- MINIMIZE / TOGGLE UI
-- ═══════════════════════════════════════════
local isMinimized = false
local originalSize = MainFrame.Size

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        Tween(MainFrame, {Size = UDim2.new(0, 480, 0, 55)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        minimizeBtn.Text = "+"
        ContentFrame.Visible = false
    else
        ContentFrame.Visible = true
        Tween(MainFrame, {Size = originalSize}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        minimizeBtn.Text = "−"
    end
end)

-- Toggle with keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
        Notify("SYN-STUDIO", MainFrame.Visible and "UI Shown" or "UI Hidden (Press RShift)", 1.5, "success")
    end
end)

-- ═══════════════════════════════════════════
-- BALL ESP INDICATOR
-- ═══════════════════════════════════════════
local espBillboard = nil

local function CreateBallESP(ball)
    if espBillboard then espBillboard:Destroy() end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SynESP"
    billboard.Size = UDim2.new(0, 120, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = ball
    billboard.Parent = ball

    local espFrame = Instance.new("Frame")
    espFrame.Name = "Frame" -- FIX: Ditambahkan eksplisit agar heartbeat loop dapat menemukannya
    espFrame.BackgroundColor3 = Colors.Background
    espFrame.BackgroundTransparency = 0.2
    espFrame.Size = UDim2.new(1, 0, 1, 0)
    espFrame.Parent = billboard
    CreateCorner(espFrame, 8)
    CreateStroke(espFrame, Colors.Danger, 1.5, 0.3)

    local espText = Instance.new("TextLabel")
    espText.Name = "DistText"
    espText.BackgroundTransparency = 1
    espText.Size = UDim2.new(1, 0, 0.5, 0)
    espText.Font = Enum.Font.GothamBold
    espText.TextSize = 12
    espText.TextColor3 = Colors.Danger
    espText.Text = "⚠ BALL"
    espText.Parent = espFrame

    local distText = Instance.new("TextLabel")
    distText.Name = "Distance"
    distText.BackgroundTransparency = 1
    distText.Size = UDim2.new(1, 0, 0.5, 0)
    distText.Position = UDim2.new(0, 0, 0.5, 0)
    distText.Font = Enum.Font.Gotham
    distText.TextSize = 10
    distText.TextColor3 = Colors.Text
    distText.Text = "0 studs"
    distText.Parent = espFrame

    espBillboard = billboard
    return billboard
end

-- ═══════════════════════════════════════════
-- PARRY VISUAL EFFECT
-- ═══════════════════════════════════════════
local function ParryEffect()
    if not Config.VisualEffects then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Screen flash
    local flash = Instance.new("Frame")
    flash.BackgroundColor3 = Colors.Primary
    flash.BackgroundTransparency = 0.7
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.ZIndex = 100
    flash.Parent = ScreenGui
    Tween(flash, {BackgroundTransparency = 1}, 0.4)
    task.delay(0.4, function() flash:Destroy() end)

    -- 3D ring effect
    local part = Instance.new("Part")
    part.Shape = Enum.PartType.Ball
    part.Material = Enum.Material.Neon
    part.Color = Colors.Primary
    part.Size = Vector3.new(1, 1, 1)
    part.Position = hrp.Position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.3
    part.Parent = Workspace

    Tween(part, {Size = Vector3.new(20, 20, 20), Transparency = 1}, 0.5)
    task.delay(0.5, function() part:Destroy() end)
end

-- ═══════════════════════════════════════════
-- CORE AUTO PARRY ENGINE
-- ═══════════════════════════════════════════
local lastParryTick = 0
local currentBallSpeed = 0
local parryDebounce = false

local function FindBall()
    -- Search multiple possible ball locations
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name == "ball" or name == "bladeball" or name == "blade_ball" then
                return obj
            end
        end
    end

    -- Also check specific folders
    local ballsFolder = Workspace:FindFirstChild("Balls") or Workspace:FindFirstChild("GameObjects")
    if ballsFolder then
        for _, child in ipairs(ballsFolder:GetChildren()) do
            if child:IsA("BasePart") or child:IsA("Model") then
                if child:IsA("Model") then
                    return child:FindFirstChildWhichIsA("BasePart")
                end
                return child
            end
        end
    end

    return nil
end

local function IsTargeted()
    local char = LocalPlayer.Character
    if not char then return false end

    -- Check for red outline/highlight (targeted by color threshold to ensure maximum safety and consistency)
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("Highlight") then
            local color = v.OutlineColor
            if color.R > 0.8 and color.G < 0.2 and color.B < 0.2 then
                return true
            end
        end
        if v:IsA("SelectionBox") or v:IsA("SelectionSphere") then
            local color = v.Color3
            if color.R > 0.8 and color.G < 0.2 and color.B < 0.2 then
                return true
            end
        end
    end

    return false
end

local function IsBallApproaching(ball)
    local char = LocalPlayer.Character
    if not char then return false, 0, 0 end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, 0, 0 end

    local ballPos = ball.Position
    local playerPos = hrp.Position
    local distance = (ballPos - playerPos).Magnitude

    -- Calculate ball velocity/speed
    local velocity = ball.Velocity
    if velocity then
        currentBallSpeed = velocity.Magnitude
    end

    -- Check if ball is moving toward player
    local direction = (playerPos - ballPos).Unit
    local ballDir = velocity and velocity.Unit or Vector3.new(0,0,0)
    local dot = direction:Dot(ballDir)

    -- Ball is approaching if dot product > 0.3 (moving toward us)
    local isApproaching = dot > 0.3 or distance < 30

    return isApproaching, distance, currentBallSpeed
end

local function CalculateParryDistance(speed, distance)
    local baseDistance = Config.ParryDistance
    local speedFactor = math.clamp(speed / 100, 0.5, 3.0)

    -- Adaptive timing
    local adaptiveDistance = baseDistance * speedFactor * Config.SpeedMultiplier

    -- Clamp to reasonable range
    adaptiveDistance = math.clamp(adaptiveDistance, Config.MinParryDistance, Config.MaxParryDistance)

    return adaptiveDistance
end

local function TriggerParry()
    if parryDebounce then return end
    parryDebounce = true

    -- Method 1: Fire remote event for parry
    local parryRemote = ReplicatedStorage:FindFirstChild("Remotes")
    if parryRemote then
        local parryEvent = parryRemote:FindFirstChild("Parry")
            or parryRemote:FindFirstChild("ParryBall")
            or parryRemote:FindFirstChild("AttemptParry")
            or parryRemote:FindFirstChild("Block")

        if parryEvent then
            if parryEvent:IsA("RemoteEvent") then
                parryEvent:FireServer()
            elseif parryEvent:IsA("RemoteFunction") then
                pcall(function()
                    parryEvent:InvokeServer()
                end)
            end
        end
    end

    -- Method 2: Search all remotes for parry-related ones
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        local name = remote.Name:lower()
        if (name:find("parry") or name:find("block") or name:find("deflect") or name:find("hit")) then
            if remote:IsA("RemoteEvent") then
                pcall(function()
                    remote:FireServer()
                end)
            elseif remote:IsA("RemoteFunction") then
                pcall(function()
                    remote:InvokeServer()
                end)
            end
        end
    end

    -- Method 3: Simulate click/parry input
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)

    -- Method 4: Fire click detector if exists on tool (Sword parry support)
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool then
                tool:Activate()
            end
        end
    end)

    -- Update stats
    Config.ParrySuccessCount = Config.ParrySuccessCount + 1
    Config.TotalParryAttempts = Config.TotalParryAttempts + 1

    -- Visual feedback
    ParryEffect()

    -- Sound effect
    if Config.SoundEffects then
        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://12221984"
            sound.Volume = 0.3
            sound.PlayOnRemove = true
            sound.Parent = Workspace
            sound:Destroy()
        end)
    end

    lastParryTick = tick()

    task.delay(0.15, function()
        parryDebounce = false
    end)
end

-- ═══════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════
local ballTracker = {
    lastPosition = nil,
    lastTime = nil,
    calculatedSpeed = 0,
}

RunService.Heartbeat:Connect(function()
    if not Config.AutoParry then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Find the ball
    local ball = FindBall()
    if not ball then return end

    -- Calculate speed manually if Velocity is zero
    local ballPos = ball.Position
    local now = tick()

    if ballTracker.lastPosition and ballTracker.lastTime then
        local dt = now - ballTracker.lastTime
        if dt > 0 then
            local dist = (ballPos - ballTracker.lastPosition).Magnitude
            ballTracker.calculatedSpeed = dist / dt
        end
    end
    ballTracker.lastPosition = ballPos
    ballTracker.lastTime = now

    -- Use calculated speed or velocity
    local speed = ball.Velocity and ball.Velocity.Magnitude or 0
    if speed < 1 then
        speed = ballTracker.calculatedSpeed
    end
    currentBallSpeed = speed

    -- Distance to player
    local distance = (ballPos - hrp.Position).Magnitude

    -- Check if ball is approaching
    local direction = (hrp.Position - ballPos)
    local dirNorm = direction.Unit
    local ballVel = ball.Velocity or (ballTracker.lastPosition and (ballPos - ballTracker.lastPosition) * 60 or Vector3.new(0,0,0))
    local ballVelNorm = ballVel.Magnitude > 0.1 and ballVel.Unit or Vector3.new(0,0,0)
    local dotProduct = dirNorm:Dot(ballVelNorm)

    local isApproaching = dotProduct > 0.2 or (distance < 25 and speed > 5)
    local isTargeted = IsTargeted()

    -- Ball ESP
    if Config.ShowBallESP then
        if not espBillboard or espBillboard.Parent ~= ball then
            CreateBallESP(ball)
        end
        if espBillboard then
            local distLabel = espBillboard:FindFirstChild("Frame")
            if distLabel then
                local d = distLabel:FindFirstChild("Distance")
                if d then
                    d.Text = string.format("%.0f studs | %.0f spd", distance, speed)
                end
                local t = distLabel:FindFirstChild("DistText")
                if t then
                    if isApproaching and distance < 100 then
                        t.Text = "⚠ INCOMING!"
                        t.TextColor3 = Colors.Danger
                    else
                        t.Text = "● BALL"
                        t.TextColor3 = Colors.Primary
                    end
                end
            end
        end
    end

    -- Update UI stats
    pcall(function()
        ballSpeedLabel.Text = string.format("%.0f", speed)
        if Config.TotalParryAttempts > 0 then
            local rate = (Config.ParrySuccessCount / Config.TotalParryAttempts) * 100
            successRateLabel.Text = string.format("%.0f%%", rate)
        end
        parryCountLabel.Text = tostring(Config.ParrySuccessCount)
    end)

    -- ═══════════════════════════════════════
    -- PARRY DECISION ENGINE
    -- ═══════════════════════════════════════

    if not isApproaching and not isTargeted then return end
    if tick() - lastParryTick < 0.15 then return end -- Cooldown

    -- Calculate optimal parry distance
    local optimalDistance = CalculateParryDistance(speed, distance)

    -- Prediction: estimate time to reach player
    local timeToReach = speed > 0.1 and (distance / speed) or 999

    -- Smart timing based on speed
    local shouldParry = false

    if Config.SmartTiming then
        -- For very fast balls (speed > 200), parry at larger distance
        if speed > 200 and distance < optimalDistance * 1.5 and isApproaching then
            shouldParry = true
        -- For fast balls (speed > 100)
        elseif speed > 100 and distance < optimalDistance * 1.2 and isApproaching then
            shouldParry = true
        -- Normal speed
        elseif distance < optimalDistance and isApproaching then
            shouldParry = true
        -- Very close - emergency parry
        elseif distance < Config.MinParryDistance then
            shouldParry = true
        -- Targeted and close
        elseif isTargeted and distance < optimalDistance * 1.3 then
            shouldParry = true
        end

        -- Time-based prediction
        if Config.PredictionEnabled and timeToReach < 0.25 and timeToReach > 0.02 then
            shouldParry = true
        end
    else
        -- Simple mode: just use distance
        if distance < Config.ParryDistance and isApproaching then
            shouldParry = true
        end
    end

    -- EXECUTE PARRY
    if shouldParry then
        -- Add slight delay for very fast balls to be frame-perfect
        if speed > 150 then
            TriggerParry()
        else
            -- Small delay for slower balls to maximize timing
            local delayTime = math.clamp(timeToReach * 0.3, 0, 0.1)
            task.delay(delayTime, function()
                TriggerParry()
            end)
        end
    end
end)

-- ═══════════════════════════════════════════
-- SECONDARY PARRY DETECTION (Backup)
-- ═══════════════════════════════════════════

-- Listen for ball attribute changes or value objects
task.spawn(function()
    while ScreenGui.Parent do
        pcall(function()
            local ball = FindBall()
            if ball then
                -- Check for target attribute
                local target = ball:GetAttribute("Target")
                    or ball:GetAttribute("target")
                    or ball:GetAttribute("CurrentTarget")

                if target and (target == LocalPlayer.Name or target == LocalPlayer.UserId) then
                    -- We are targeted!
                    local char = LocalPlayer.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local dist = (ball.Position - hrp.Position).Magnitude
                            if dist < Config.ParryDistance * 1.5 then
                                TriggerParry()
                            end
                        end
                    end
                end

                -- Check value objects inside ball
                for _, child in ipairs(ball:GetChildren()) do
                    if child:IsA("ObjectValue") and child.Name:lower():find("target") then
                        if child.Value == LocalPlayer.Character or child.Value == LocalPlayer then
                            local hrpCheck = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if hrpCheck then
                                local d = (ball.Position - hrpCheck.Position).Magnitude
                                if d < Config.ParryDistance * 1.5 then
                                    TriggerParry()
                                end
                            end
                        end
                    end
                end
            end
        end)
        task.wait(0.05)
    end
end)

-- ═══════════════════════════════════════════
-- REMOTE SPY - Auto detect parry remote
-- ═══════════════════════════════════════════
task.spawn(function()
    task.wait(2)
    local parryFound = false
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        local name = remote.Name:lower()
        if name:find("parry") or name:find("deflect") or name:find("block") then
            parryFound = true
            break
        end
    end
    if parryFound then
        Notify("Remote Found", "Parry remote detected successfully!", 3, "success")
    else
        Notify("Info", "Using universal parry method", 3, "warning")
    end
end)

-- ═══════════════════════════════════════════
-- INTRO ANIMATION
-- ═══════════════════════════════════════════
MainFrame.BackgroundTransparency = 1
MainFrame.Size = UDim2.new(0, 480, 0, 0)

task.delay(0.5, function()
    Tween(MainFrame, {
        Size = UDim2.new(0, 480, 0, 560),
        BackgroundTransparency = 0
    }, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    task.delay(0.8, function()
        Notify("SYN-STUDIO", "Auto Parry loaded successfully! ⚔", 3, "success")
        task.delay(1, function()
            Notify("Keybind", "Press RightShift to toggle UI", 3, "warning")
        end)
    end)
end)

print([[
╔══════════════════════════════════════════╗
║         SYN-STUDIO v2.0 Loaded!         ║
║      Blade Ball Auto Parry Active       ║
║                                          ║
║  Keybind: RightShift = Toggle UI        ║
║  Features:                               ║
║  • Smart Speed-Adaptive Parry           ║
║  • Prediction System                     ║
║  • Ball ESP & Distance Tracker          ║
║  • Visual Effects                        ║
║  • Zero Miss Technology                  ║
╚══════════════════════════════════════════╝
]])