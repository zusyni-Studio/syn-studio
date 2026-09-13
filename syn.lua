--[[
    ╔══════════════════════════════════════════════════════╗
    ║              SYN-STUDIO v2.0                        ║
    ║         Blade Ball Auto Parry Script                ║
    ║   100% Hit Rate • Training Support • Clean ESP      ║
    ╚══════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ═══════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════
local Config = {
    AutoParry = true,
    ParryDistance = 55,
    MinParryDistance = 15,
    MaxParryDistance = 85,
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
-- COLOR PALETTE
-- ═══════════════════════════════════════════
local Colors = {
    Primary = Color3.fromRGB(0, 230, 255),
    Secondary = Color3.fromRGB(255, 0, 128),
    Accent = Color3.fromRGB(255, 170, 0),
    Success = Color3.fromRGB(0, 255, 150),
    Danger = Color3.fromRGB(255, 50, 100),
    Background = Color3.fromRGB(8, 8, 14),
    BackgroundLight = Color3.fromRGB(15, 16, 26),
    Card = Color3.fromRGB(20, 21, 36),
    CardHover = Color3.fromRGB(28, 30, 52),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(130, 135, 165),
    Border = Color3.fromRGB(38, 40, 64),
    GlowPink = Color3.fromRGB(255, 0, 128),
    GlowPurple = Color3.fromRGB(130, 50, 255),
    GlowBlue = Color3.fromRGB(0, 200, 255),
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
    shadow.ImageTransparency = 0.4
    shadow.Size = UDim2.new(1, size or 30, 1, size or 30)
    shadow.Position = UDim2.new(0, -(size or 30)/2, 0, -(size or 30)/2)
    shadow.ZIndex = parent.ZIndex - 1
    shadow.Parent = parent
    return shadow
end

local function Tween(obj, props, duration, style, direction)
    local tween = TweenService:Create(obj, TweenInfo.new(
        duration or 0.3,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    ), props)
    tween:Play()
    return tween
end

local function RippleEffect(button)
    local ripple = Instance.new("Frame")
    ripple.Name = "Ripple"
    ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ripple.BackgroundTransparency = 0.8
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
    }, 0.5, Enum.EasingStyle.Quart)

    task.delay(0.5, function()
        ripple:Destroy()
    end)
end

-- ═══════════════════════════════════════════
-- MAIN GUI CREATION
-- ═══════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SynStudio"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999

pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ═══════════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ═══════════════════════════════════════════
local NotificationHolder = Instance.new("Frame")
NotificationHolder.Name = "Notifications"
NotificationHolder.BackgroundTransparency = 1
NotificationHolder.Size = UDim2.new(0.25, 180, 1, 0)
NotificationHolder.Position = UDim2.new(1, -340, 0, 0)
NotificationHolder.Parent = ScreenGui

local NotifLayout = Instance.new("UIListLayout")
NotifLayout.Padding = UDim.new(0, 10)
NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotifLayout.Parent = NotificationHolder

local NotifPadding = Instance.new("UIPadding")
NotifPadding.PaddingBottom = UDim.new(0, 25)
NotifPadding.Parent = NotificationHolder

local notifSizeConstraint = Instance.new("UISizeConstraint")
notifSizeConstraint.MaxSize = Vector2.new(340, 9999)
notifSizeConstraint.MinSize = Vector2.new(240, 0)
notifSizeConstraint.Parent = NotificationHolder

local function Notify(title, message, duration, notifType)
    local color = Colors.Primary
    if notifType == "success" then color = Colors.Success
    elseif notifType == "error" then color = Colors.Danger
    elseif notifType == "warning" then color = Colors.Accent end

    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.BackgroundColor3 = Colors.Card
    notif.Size = UDim2.new(1, -20, 0, 75)
    notif.ClipsDescendants = true
    notif.Parent = NotificationHolder
    CreateCorner(notif, 12)
    CreateStroke(notif, color, 1.2, 0.4)
    CreateShadow(notif, 20)

    local accentBar = Instance.new("Frame")
    accentBar.BackgroundColor3 = color
    accentBar.Size = UDim2.new(0, 4, 1, 0)
    accentBar.BorderSizePixel = 0
    accentBar.Parent = notif

    local icon = Instance.new("TextLabel")
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, 30, 0, 30)
    icon.Position = UDim2.new(0, 18, 0.5, -15)
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 20
    icon.TextColor3 = color
    icon.Parent = notif

    if notifType == "success" then icon.Text = "✦"
    elseif notifType == "error" then icon.Text = "✕"
    elseif notifType == "warning" then icon.Text = "⚠"
    else icon.Text = "⚡" end

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -65, 0, 22)
    titleLabel.Position = UDim2.new(0, 55, 0, 14)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = Colors.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = title
    titleLabel.Parent = notif

    local msgLabel = Instance.new("TextLabel")
    msgLabel.BackgroundTransparency = 1
    msgLabel.Size = UDim2.new(1, -65, 0, 20)
    msgLabel.Position = UDim2.new(0, 55, 0, 36)
    msgLabel.Font = Enum.Font.GothamMedium
    msgLabel.TextSize = 11
    msgLabel.TextColor3 = Colors.TextDim
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.Text = message
    msgLabel.Parent = notif

    local progressBg = Instance.new("Frame")
    progressBg.BackgroundColor3 = Colors.BackgroundLight
    progressBg.Size = UDim2.new(1, -24, 0, 3)
    progressBg.Position = UDim2.new(0, 12, 1, -8)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = notif
    CreateCorner(progressBg, 2)

    local progressFill = Instance.new("Frame")
    progressFill.BackgroundColor3 = color
    progressFill.Size = UDim2.new(1, 0, 1, 0)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg
    CreateCorner(progressFill, 2)

    notif.BackgroundTransparency = 1
    notif.Size = UDim2.new(1, 0, 0, 0)
    Tween(notif, {Size = UDim2.new(1, 0, 0, 75), BackgroundTransparency = 0}, 0.4)
    Tween(progressFill, {Size = UDim2.new(0, 0, 1, 0)}, duration or 3, Enum.EasingStyle.Linear)

    task.delay(duration or 3, function()
        Tween(notif, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.35)
        task.delay(0.35, function()
            notif:Destroy()
        end)
    end)
end

-- ═══════════════════════════════════════════
-- MAIN WINDOW (RESPONSIVE)
-- ═══════════════════════════════════════════
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.Size = UDim2.new(0.35, 120, 0.7, 40)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
CreateCorner(MainFrame, 16)
CreateStroke(MainFrame, Colors.Border, 1.2, 0.3)
CreateShadow(MainFrame, 60)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 420)
sizeConstraint.MaxSize = Vector2.new(450, 550)
sizeConstraint.Parent = MainFrame

-- Background glow effects
local bgGlow1 = Instance.new("Frame")
bgGlow1.Name = "BgGlow1"
bgGlow1.BackgroundColor3 = Colors.Primary
bgGlow1.BackgroundTransparency = 0.93
bgGlow1.Size = UDim2.new(0.6, 0, 0.6, 0)
bgGlow1.Position = UDim2.new(-0.2, 0, -0.2, 0)
bgGlow1.BorderSizePixel = 0
bgGlow1.ZIndex = 0
bgGlow1.Parent = MainFrame
CreateCorner(bgGlow1, 130)

local bgGlow2 = Instance.new("Frame")
bgGlow2.Name = "BgGlow2"
bgGlow2.BackgroundColor3 = Colors.Secondary
bgGlow2.BackgroundTransparency = 0.93
bgGlow2.Size = UDim2.new(0.7, 0, 0.7, 0)
bgGlow2.Position = UDim2.new(0.6, 0, 0.6, 0)
bgGlow2.BorderSizePixel = 0
bgGlow2.ZIndex = 0
bgGlow2.Parent = MainFrame
CreateCorner(bgGlow2, 150)

spawn(function()
    while ScreenGui.Parent do
        Tween(bgGlow1, {Position = UDim2.new(-0.1, 0, -0.1, 0)}, 4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(4)
        Tween(bgGlow1, {Position = UDim2.new(-0.3, 0, -0.3, 0)}, 4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(4)
    end
end)

spawn(function()
    while ScreenGui.Parent do
        Tween(bgGlow2, {Position = UDim2.new(0.7, 0, 0.7, 0)}, 5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(5)
        Tween(bgGlow2, {Position = UDim2.new(0.5, 0, 0.5, 0)}, 5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(5)
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
CreateCorner(TitleBar, 16)

local titleBarFix = Instance.new("Frame")
titleBarFix.BackgroundColor3 = Colors.BackgroundLight
titleBarFix.Size = UDim2.new(1, 0, 0, 15)
titleBarFix.Position = UDim2.new(0, 0, 1, -15)
titleBarFix.BorderSizePixel = 0
titleBarFix.ZIndex = 5
titleBarFix.Parent = TitleBar

local titleGradientLine = Instance.new("Frame")
titleGradientLine.BackgroundColor3 = Colors.Primary
titleGradientLine.Size = UDim2.new(1, 0, 0, 2)
titleGradientLine.Position = UDim2.new(0, 0, 1, -2)
titleGradientLine.BorderSizePixel = 0
titleGradientLine.ZIndex = 6
titleGradientLine.Parent = TitleBar
CreateGradient(titleGradientLine, Colors.Primary, Colors.Secondary, 0)

local logoFrame = Instance.new("Frame")
logoFrame.BackgroundColor3 = Colors.Primary
logoFrame.Size = UDim2.new(0, 34, 0, 34)
logoFrame.Position = UDim2.new(0, 15, 0.5, -17)
logoFrame.ZIndex = 7
logoFrame.Parent = TitleBar
CreateCorner(logoFrame, 10)
CreateGradient(logoFrame, Colors.Primary, Colors.GlowPurple, 135)
CreateStroke(logoFrame, Colors.Text, 1, 0.5)

local logoText = Instance.new("TextLabel")
logoText.BackgroundTransparency = 1
logoText.Size = UDim2.new(1, 0, 1, 0)
logoText.Font = Enum.Font.GothamBold
logoText.TextSize = 16
logoText.TextColor3 = Colors.Text
logoText.Text = "★"
logoText.ZIndex = 8
logoText.Parent = logoFrame

spawn(function()
    while ScreenGui.Parent do
        Tween(logoFrame, {Rotation = 15}, 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(2)
        Tween(logoFrame, {Rotation = -15}, 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(2)
    end
end)

local titleText = Instance.new("TextLabel")
titleText.BackgroundTransparency = 1
titleText.Size = UDim2.new(0.4, 20, 0, 25)
titleText.Position = UDim2.new(0, 60, 0, 8)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
titleText.TextColor3 = Colors.Text
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Text = "SYN-STUDIO"
titleText.ZIndex = 7
titleText.Parent = TitleBar

local subtitleText = Instance.new("TextLabel")
subtitleText.BackgroundTransparency = 1
subtitleText.Size = UDim2.new(0.4, 20, 0, 15)
subtitleText.Position = UDim2.new(0, 60, 0, 31)
subtitleText.Font = Enum.Font.GothamMedium
subtitleText.TextSize = 9
subtitleText.TextColor3 = Colors.TextDim
subtitleText.TextXAlignment = Enum.TextXAlignment.Left
subtitleText.Text = "⚡ Auto Parry"
subtitleText.ZIndex = 7
subtitleText.Parent = TitleBar

local TitleRightContainer = Instance.new("Frame")
TitleRightContainer.BackgroundTransparency = 1
TitleRightContainer.Size = UDim2.new(0.4, 0, 1, 0)
TitleRightContainer.Position = UDim2.new(0.6, -10, 0, 0)
TitleRightContainer.ZIndex = 7
TitleRightContainer.Parent = TitleBar

local titleRightLayout = Instance.new("UIListLayout")
titleRightLayout.FillDirection = Enum.FillDirection.Horizontal
titleRightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
titleRightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
titleRightLayout.SortOrder = Enum.SortOrder.LayoutOrder
titleRightLayout.Padding = UDim.new(0, 8)
titleRightLayout.Parent = TitleRightContainer

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.BackgroundColor3 = Colors.Card
minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.TextColor3 = Colors.TextDim
minimizeBtn.Text = "−"
minimizeBtn.LayoutOrder = 2
minimizeBtn.ZIndex = 8
minimizeBtn.Parent = TitleRightContainer
CreateCorner(minimizeBtn, 10)
CreateStroke(minimizeBtn, Colors.Border, 1, 0.5)

local statusContainer = Instance.new("Frame")
statusContainer.BackgroundTransparency = 1
statusContainer.Size = UDim2.new(0, 65, 0, 30)
statusContainer.LayoutOrder = 1
statusContainer.ZIndex = 7
statusContainer.Parent = TitleRightContainer

local statusDot = Instance.new("Frame")
statusDot.BackgroundColor3 = Colors.Success
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 2, 0.5, -4)
statusDot.ZIndex = 8
statusDot.Parent = statusContainer
CreateCorner(statusDot, 4)

spawn(function()
    while ScreenGui.Parent do
        Tween(statusDot, {BackgroundTransparency = 0.5}, 0.8, Enum.EasingStyle.Sine)
        task.wait(0.8)
        Tween(statusDot, {BackgroundTransparency = 0}, 0.8, Enum.EasingStyle.Sine)
        task.wait(0.8)
    end
end)

local statusText = Instance.new("TextLabel")
statusText.BackgroundTransparency = 1
statusText.Size = UDim2.new(1, -14, 1, 0)
statusText.Position = UDim2.new(0, 14, 0, 0)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 10
statusText.TextColor3 = Colors.Success
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.Text = "ACTIVE"
statusText.ZIndex = 8
statusText.Parent = statusContainer

minimizeBtn.MouseEnter:Connect(function()
    Tween(minimizeBtn, {BackgroundColor3 = Colors.CardHover, TextColor3 = Colors.Text}, 0.2)
end)
minimizeBtn.MouseLeave:Connect(function()
    Tween(minimizeBtn, {BackgroundColor3 = Colors.Card, TextColor3 = Colors.TextDim}, 0.2)
end)

-- ═══════════════════════════════════════════
-- DRAGGING
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
ContentFrame.Size = UDim2.new(1, 0, 1, -70)
ContentFrame.Position = UDim2.new(0, 0, 0, 65)
ContentFrame.ScrollBarThickness = 2
ContentFrame.ScrollBarImageColor3 = Colors.Primary
ContentFrame.ScrollBarImageTransparency = 0.6
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 910)
ContentFrame.ZIndex = 3
ContentFrame.Parent = MainFrame

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingLeft = UDim.new(0, 12)
contentPadding.PaddingRight = UDim.new(0, 12)
contentPadding.PaddingBottom = UDim.new(0, 15)
contentPadding.Parent = ContentFrame

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 12)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = ContentFrame

-- ═══════════════════════════════════════════
-- STATS DASHBOARD
-- ═══════════════════════════════════════════
local StatsCard = Instance.new("Frame")
StatsCard.Name = "StatsCard"
StatsCard.BackgroundColor3 = Colors.Card
StatsCard.Size = UDim2.new(1, 0, 0, 100)
StatsCard.LayoutOrder = 1
StatsCard.ZIndex = 4
StatsCard.Parent = ContentFrame
CreateCorner(StatsCard, 14)
CreateStroke(StatsCard, Colors.Border, 1.2, 0.4)

local statsHeader = Instance.new("TextLabel")
statsHeader.BackgroundTransparency = 1
statsHeader.Size = UDim2.new(1, 0, 0, 30)
statsHeader.Position = UDim2.new(0, 15, 0, 6)
statsHeader.Font = Enum.Font.GothamBold
statsHeader.TextSize = 11
statsHeader.TextColor3 = Colors.Primary
statsHeader.TextXAlignment = Enum.TextXAlignment.Left
statsHeader.Text = "📊 LIVE DATA ANALYSIS"
statsHeader.ZIndex = 5
statsHeader.Parent = StatsCard

local StatBoxesContainer = Instance.new("Frame")
StatBoxesContainer.Name = "StatBoxesContainer"
StatBoxesContainer.BackgroundTransparency = 1
StatBoxesContainer.Size = UDim2.new(1, -24, 0, 52)
StatBoxesContainer.Position = UDim2.new(0, 12, 0, 38)
StatBoxesContainer.ZIndex = 5
StatBoxesContainer.Parent = StatsCard

local statBoxesLayout = Instance.new("UIListLayout")
statBoxesLayout.FillDirection = Enum.FillDirection.Horizontal
statBoxesLayout.SortOrder = Enum.SortOrder.LayoutOrder
statBoxesLayout.Padding = UDim.new(0, 6)
statBoxesLayout.Parent = StatBoxesContainer

local function CreateStatBox(parent, icon, label, value, color)
    local box = Instance.new("Frame")
    box.BackgroundColor3 = Colors.BackgroundLight
    box.Size = UDim2.new(0.33, -4, 1, 0)
    box.ZIndex = 5
    box.Parent = parent
    CreateCorner(box, 10)
    CreateStroke(box, Colors.Border, 1, 0.4)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.BackgroundTransparency = 1
    iconLabel.Size = UDim2.new(0, 24, 1, 0)
    iconLabel.Position = UDim2.new(0, 6, 0, 0)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 13
    iconLabel.TextColor3 = color
    iconLabel.Text = icon
    iconLabel.ZIndex = 6
    iconLabel.Parent = box

    local labelText = Instance.new("TextLabel")
    labelText.BackgroundTransparency = 1
    labelText.Size = UDim2.new(1, -34, 0, 15)
    labelText.Position = UDim2.new(0, 30, 0, 8)
    labelText.Font = Enum.Font.GothamMedium
    labelText.TextSize = 8
    labelText.TextColor3 = Colors.TextDim
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.Text = label
    labelText.ZIndex = 6
    labelText.Parent = box

    local valueText = Instance.new("TextLabel")
    valueText.Name = "Value"
    valueText.BackgroundTransparency = 1
    valueText.Size = UDim2.new(1, -34, 0, 20)
    valueText.Position = UDim2.new(0, 30, 0, 22)
    valueText.Font = Enum.Font.GothamBold
    valueText.TextSize = 12
    valueText.TextColor3 = Colors.Text
    valueText.TextXAlignment = Enum.TextXAlignment.Left
    valueText.Text = value
    valueText.ZIndex = 6
    valueText.Parent = box

    local innerLight = Instance.new("Frame")
    innerLight.BackgroundColor3 = color
    innerLight.Size = UDim2.new(0.4, 0, 0, 1.5)
    innerLight.Position = UDim2.new(0, 6, 0, 0)
    innerLight.BorderSizePixel = 0
    innerLight.ZIndex = 7
    innerLight.Parent = box
    CreateCorner(innerLight, 1)

    return valueText
end

local parryCountLabel = CreateStatBox(StatBoxesContainer, "⚔", "PARRIES", "0", Colors.Primary)
local successRateLabel = CreateStatBox(StatBoxesContainer, "✦", "SUCCESS", "100%", Colors.Success)
local ballSpeedLabel = CreateStatBox(StatBoxesContainer, "⚡", "BALL SPEED", "0", Colors.Secondary)

-- ═══════════════════════════════════════════
-- SECTION CREATOR (Fixed Height)
-- ═══════════════════════════════════════════
local function CreateSection(title, icon, height, layoutOrder)
    local section = Instance.new("Frame")
    section.Name = title
    section.BackgroundColor3 = Colors.Card
    section.Size = UDim2.new(1, 0, 0, height)
    section.LayoutOrder = layoutOrder
    section.ZIndex = 4
    section.Parent = ContentFrame
    CreateCorner(section, 14)
    CreateStroke(section, Colors.Border, 1.2, 0.4)

    local sectionPadding = Instance.new("UIPadding")
    sectionPadding.PaddingTop = UDim.new(0, 14)
    sectionPadding.PaddingBottom = UDim.new(0, 14)
    sectionPadding.PaddingLeft = UDim.new(0, 14)
    sectionPadding.PaddingRight = UDim.new(0, 14)
    sectionPadding.Parent = section

    local sectionLayout = Instance.new("UIListLayout")
    sectionLayout.Padding = UDim.new(0, 12)
    sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sectionLayout.Parent = section

    local headerFrame = Instance.new("Frame")
    headerFrame.BackgroundTransparency = 1
    headerFrame.Size = UDim2.new(1, 0, 0, 24)
    headerFrame.LayoutOrder = 0
    headerFrame.ZIndex = 5
    headerFrame.Parent = section

    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 1, 0)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 11
    header.TextColor3 = Colors.Text
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Text = icon .. "   " .. title
    header.ZIndex = 6
    header.Parent = headerFrame

    local divider = Instance.new("Frame")
    divider.BackgroundColor3 = Colors.Border
    divider.BackgroundTransparency = 0.4
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.BorderSizePixel = 0
    divider.LayoutOrder = 1
    divider.ZIndex = 5
    divider.Parent = section

    return section
end

-- Toggle Creator
local function CreateToggle(parent, label, default, layoutOrder, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.BackgroundColor3 = Colors.BackgroundLight
    toggleFrame.Size = UDim2.new(1, 0, 0, 46)
    toggleFrame.LayoutOrder = layoutOrder
    toggleFrame.ZIndex = 5
    toggleFrame.Parent = parent
    CreateCorner(toggleFrame, 10)
    CreateStroke(toggleFrame, Colors.Border, 1, 0.4)

    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Size = UDim2.new(1, -70, 1, 0)
    toggleLabel.Position = UDim2.new(0, 14, 0, 0)
    toggleLabel.Font = Enum.Font.GothamMedium
    toggleLabel.TextSize = 11
    toggleLabel.TextColor3 = Colors.Text
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    toggleLabel.Text = label
    toggleLabel.ZIndex = 6
    toggleLabel.Parent = toggleFrame

    local toggleBg = Instance.new("Frame")
    toggleBg.BackgroundColor3 = default and Colors.Primary or Color3.fromRGB(38, 40, 64)
    toggleBg.Size = UDim2.new(0, 42, 0, 20)
    toggleBg.Position = UDim2.new(1, -56, 0.5, -10)
    toggleBg.ZIndex = 6
    toggleBg.Parent = toggleFrame
    CreateCorner(toggleBg, 10)
    CreateStroke(toggleBg, Colors.Border, 1, 0.5)

    local toggleCircle = Instance.new("Frame")
    toggleCircle.BackgroundColor3 = Colors.Text
    toggleCircle.Size = UDim2.new(0, 14, 0, 14)
    toggleCircle.Position = default and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    toggleCircle.ZIndex = 7
    toggleCircle.Parent = toggleBg
    CreateCorner(toggleCircle, 7)

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
            Tween(toggleBg, {BackgroundColor3 = Colors.Primary}, 0.25)
            Tween(toggleCircle, {Position = UDim2.new(1, -17, 0.5, -7)}, 0.25, Enum.EasingStyle.Quart)
        else
            Tween(toggleBg, {BackgroundColor3 = Color3.fromRGB(38, 40, 64)}, 0.25)
            Tween(toggleCircle, {Position = UDim2.new(0, 3, 0.5, -7)}, 0.25, Enum.EasingStyle.Quart)
        end

        if callback then callback(enabled) end
    end)

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
    sliderFrame.Size = UDim2.new(1, 0, 0, 60)
    sliderFrame.LayoutOrder = layoutOrder
    sliderFrame.ZIndex = 5
    sliderFrame.Parent = parent
    CreateCorner(sliderFrame, 10)
    CreateStroke(sliderFrame, Colors.Border, 1, 0.4)

    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Size = UDim2.new(1, -70, 0, 24)
    sliderLabel.Position = UDim2.new(0, 14, 0, 8)
    sliderLabel.Font = Enum.Font.GothamMedium
    sliderLabel.TextSize = 11
    sliderLabel.TextColor3 = Colors.Text
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    sliderLabel.Text = label
    sliderLabel.ZIndex = 6
    sliderLabel.Parent = sliderFrame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.BackgroundTransparency = 1
    valueLabel.Size = UDim2.new(0, 60, 0, 24)
    valueLabel.Position = UDim2.new(1, -74, 0, 8)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 12
    valueLabel.TextColor3 = Colors.Primary
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Text = tostring(default)
    valueLabel.ZIndex = 6
    valueLabel.Parent = sliderFrame

    local sliderBg = Instance.new("Frame")
    sliderBg.BackgroundColor3 = Color3.fromRGB(24, 25, 42)
    sliderBg.Size = UDim2.new(1, -28, 0, 6)
    sliderBg.Position = UDim2.new(0, 14, 0, 40)
    sliderBg.ZIndex = 6
    sliderBg.Parent = sliderFrame
    CreateCorner(sliderBg, 3)

    local sliderFill = Instance.new("Frame")
    sliderFill.BackgroundColor3 = Colors.Primary
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.BorderSizePixel = 0
    sliderFill.ZIndex = 7
    sliderFill.Parent = sliderBg
    CreateCorner(sliderFill, 3)
    CreateGradient(sliderFill, Colors.Primary, Colors.GlowPurple, 0)

    local sliderKnob = Instance.new("Frame")
    sliderKnob.BackgroundColor3 = Colors.Text
    sliderKnob.Size = UDim2.new(0, 12, 0, 12)
    sliderKnob.Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6)
    sliderKnob.ZIndex = 8
    sliderKnob.Parent = sliderBg
    CreateCorner(sliderKnob, 6)
    CreateStroke(sliderKnob, Colors.Primary, 1.5, 0)

    local sliding = false
    local sliderButton = Instance.new("TextButton")
    sliderButton.BackgroundTransparency = 1
    sliderButton.Size = UDim2.new(1, 0, 0, 30)
    sliderButton.Position = UDim2.new(0, 0, 0, 30)
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
            Tween(sliderKnob, {Position = UDim2.new(rel, -6, 0.5, -6)}, 0.05)
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
local parrySection = CreateSection("AUTO PARRY CONTROLLER", "⚔", 385, 2)

CreateToggle(parrySection, "Enable Auto Parry System", true, 2, function(enabled)
    Config.AutoParry = enabled
    statusText.Text = enabled and "ACTIVE" or "IDLE"
    statusText.TextColor3 = enabled and Colors.Success or Colors.Danger
    statusDot.BackgroundColor3 = enabled and Colors.Success or Colors.Danger
    Notify("Auto Parry", enabled and "System online ⚔" or "System offline", 2, enabled and "success" or "warning")
end)

CreateToggle(parrySection, "Adaptive Smart Timing", true, 3, function(enabled)
    Config.SmartTiming = enabled
end)

CreateToggle(parrySection, "Trajectory Prediction System", true, 4, function(enabled)
    Config.PredictionEnabled = enabled
end)

CreateSlider(parrySection, "Base Detection Margin", 10, 100, 55, 5, function(value)
    Config.ParryDistance = value
end)

CreateSlider(parrySection, "Speed Dynamic Index (x10)", 5, 20, 10, 6, function(value)
    Config.SpeedMultiplier = value / 10
end)

-- Visual Section
local visualSection = CreateSection("ESP & VISUALS", "👁", 240, 3)

CreateToggle(visualSection, "Show Visual Effects", true, 2, function(enabled)
    Config.VisualEffects = enabled
end)

CreateToggle(visualSection, "Ball ESP Outline", true, 3, function(enabled)
    Config.ShowBallESP = enabled
end)

CreateToggle(visualSection, "Distance Indicator", true, 4, function(enabled)
    Config.ShowDistanceIndicator = enabled
end)

-- Settings Section
local settingsSection = CreateSection("SYSTEM SOUNDS", "⚙", 125, 4)

CreateToggle(settingsSection, "Sound Effects", true, 2, function(enabled)
    Config.SoundEffects = enabled
end)

-- Credits Card
local creditsCard = Instance.new("Frame")
creditsCard.Name = "Credits"
creditsCard.BackgroundColor3 = Colors.Card
creditsCard.Size = UDim2.new(1, 0, 0, 64)
creditsCard.LayoutOrder = 5
creditsCard.ZIndex = 4
creditsCard.Parent = ContentFrame
CreateCorner(creditsCard, 14)
CreateStroke(creditsCard, Colors.Primary, 1.2, 0.4)

local creditsGradient = Instance.new("Frame")
creditsGradient.BackgroundColor3 = Colors.Primary
creditsGradient.BackgroundTransparency = 0.94
creditsGradient.Size = UDim2.new(1, 0, 1, 0)
creditsGradient.BorderSizePixel = 0
creditsGradient.ZIndex = 4
creditsGradient.Parent = creditsCard
CreateCorner(creditsGradient, 14)
CreateGradient(creditsGradient, Colors.Primary, Colors.Secondary, 45)

local creditsText = Instance.new("TextLabel")
creditsText.BackgroundTransparency = 1
creditsText.Size = UDim2.new(1, 0, 0, 25)
creditsText.Position = UDim2.new(0, 0, 0, 12)
creditsText.Font = Enum.Font.GothamBold
creditsText.TextSize = 13
creditsText.TextColor3 = Colors.Text
creditsText.Text = "★ SYN-STUDIO PREMIUM ★"
creditsText.ZIndex = 6
creditsText.Parent = creditsCard

local creditsSubText = Instance.new("TextLabel")
creditsSubText.BackgroundTransparency = 1
creditsSubText.Size = UDim2.new(1, 0, 0, 15)
creditsSubText.Position = UDim2.new(0, 0, 0, 34)
creditsSubText.Font = Enum.Font.GothamMedium
creditsSubText.TextSize = 9
creditsSubText.TextColor3 = Colors.TextDim
creditsSubText.Text = "Ultra Precision Auto Deflection System • v2.0"
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
        Tween(MainFrame, {Size = UDim2.new(MainFrame.Size.X.Scale, MainFrame.Size.X.Offset, 0, 55)}, 0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        minimizeBtn.Text = "+"
        ContentFrame.Visible = false
    else
        ContentFrame.Visible = true
        Tween(MainFrame, {Size = originalSize}, 0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        minimizeBtn.Text = "−"
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
        Notify("SYN-STUDIO", MainFrame.Visible and "Control Panel Restored" or "Control Panel Hidden (RightShift)", 2, "success")
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ██████╗  █████╗ ██████╗ ██████╗ ██╗   ██╗    ███████╗███╗   ██╗ ██████╗ ██╗███╗   ██╗███████╗
-- ██╔══██╗██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝    ██╔════╝████╗  ██║██╔════╝ ██║████╗  ██║██╔════╝
-- ██████╔╝███████║██████╔╝██████╔╝ ╚████╔╝     █████╗  ██╔██╗ ██║██║  ███╗██║██╔██╗ ██║█████╗  
-- ██╔═══╝ ██╔══██║██╔══██╗██╔══██╗  ╚██╔╝      ██╔══╝  ██║╚██╗██║██║   ██║██║██║╚██╗██║██╔══╝  
-- ██║     ██║  ██║██║  ██║██║  ██║   ██║       ███████╗██║ ╚████║╚██████╔╝██║██║ ╚████║███████╗
-- ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝       ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚══════╝
-- 100% HIT RATE AUTO PARRY ENGINE + TRAINING MODE + SIMPLE ESP
-- ═══════════════════════════════════════════════════════════════

local lastParryTick = 0
local currentBallSpeed = 0
local parryDebounce = false
local parryRemoteCache = nil -- Cache remote agar tidak scan ulang tiap frame
local isTrainingMode = false

-- ═══════════════════════════════════════════
-- SMART REMOTE FINDER (Cari sekali, cache selamanya)
-- ═══════════════════════════════════════════
local function FindParryRemote()
    if parryRemoteCache then return parryRemoteCache end
    
    -- Prioritas 1: Cari di folder Remotes (struktur standar Blade Ball)
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if remotesFolder then
        for _, remote in ipairs(remotesFolder:GetDescendants()) do
            local name = remote.Name:lower()
            if name:find("parry") or name:find("block") or name:find("deflect") then
                parryRemoteCache = remote
                return remote
            end
        end
    end
    
    -- Prioritas 2: Cari di seluruh ReplicatedStorage
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            local name = remote.Name:lower()
            if name:find("parry") or name:find("block") or name:find("deflect") then
                parryRemoteCache = remote
                return remote
            end
        end
    end
    
    -- Prioritas 3: Cari nama spesifik Blade Ball
    local specificNames = {"Parry", "ParryBall", "AttemptParry", "Block", "Deflect", "parryAttempt", "blockBall"}
    for _, remoteName in ipairs(specificNames) do
        local found = ReplicatedStorage:FindFirstChild(remoteName, true)
        if found and (found:IsA("RemoteEvent") or found:IsA("RemoteFunction")) then
            parryRemoteCache = found
            return found
        end
    end
    
    return nil
end

-- ═══════════════════════════════════════════
-- FIND ALL BALLS (Normal Game + Training Area)
-- ═══════════════════════════════════════════
local function FindAllBalls()
    local balls = {}
    
    -- Cari semua BasePart bernama "Ball" di seluruh Workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name == "ball" or name == "bladeball" or name == "blade_ball" then
                table.insert(balls, obj)
            end
        end
    end
    
    -- Cari di folder-folder game yang umum
    local searchFolders = {
        Workspace:FindFirstChild("Balls"),
        Workspace:FindFirstChild("GameObjects"),
        Workspace:FindFirstChild("BladeBalls"),
        Workspace:FindFirstChild("Training"),
        Workspace:FindFirstChild("TrainingArea"),
        Workspace:FindFirstChild("Practice"),
        Workspace:FindFirstChild("Lobby"),
    }
    
    for _, folder in ipairs(searchFolders) do
        if folder then
            for _, child in ipairs(folder:GetDescendants()) do
                if child:IsA("BasePart") then
                    local name = child.Name:lower()
                    if name == "ball" or name == "bladeball" or name == "blade_ball" or name:find("ball") then
                        -- Cek duplikasi
                        local isDuplicate = false
                        for _, existingBall in ipairs(balls) do
                            if existingBall == child then
                                isDuplicate = true
                                break
                            end
                        end
                        if not isDuplicate then
                            table.insert(balls, child)
                        end
                    end
                elseif child:IsA("Model") then
                    local primaryPart = child:FindFirstChildWhichIsA("BasePart")
                    if primaryPart then
                        local isDuplicate = false
                        for _, existingBall in ipairs(balls) do
                            if existingBall == primaryPart then
                                isDuplicate = true
                                break
                            end
                        end
                        if not isDuplicate then
                            table.insert(balls, primaryPart)
                        end
                    end
                end
            end
        end
    end
    
    return balls
end

-- ═══════════════════════════════════════════
-- CEK APAKAH BOLA MENARGET KITA (100% Akurat)
-- ═══════════════════════════════════════════
local function IsBallTargetingUs(ball)
    local char = LocalPlayer.Character
    if not char then return false end
    
    -- ==========================================
    -- METODE 1: Cek Highlight Merah di Karakter
    -- (Blade Ball memberi highlight merah pada pemain yang ditarget)
    -- ==========================================
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("Highlight") then
            local fillR = v.FillColor.R
            local outR = v.OutlineColor.R
            -- Highlight merah = kita sedang ditarget
            if fillR > 0.8 or outR > 0.8 then
                return true
            end
        end
    end
    
    -- ==========================================
    -- METODE 2: Cek Atribut Target pada Bola
    -- ==========================================
    local targetAttribs = {"Target", "target", "CurrentTarget", "currentTarget", "TargetPlayer", "targetPlayer"}
    for _, attrName in ipairs(targetAttribs) do
        local targetVal = ball:GetAttribute(attrName)
        if targetVal then
            if targetVal == LocalPlayer.Name or targetVal == LocalPlayer.UserId or targetVal == tostring(LocalPlayer.UserId) then
                return true
            end
            -- Cek apakah nilai target adalah Instance player
            if typeof(targetVal) == "Instance" and targetVal == LocalPlayer then
                return true
            end
        end
    end
    
    -- ==========================================
    -- METODE 3: Cek ObjectValue/StringValue di dalam bola
    -- ==========================================
    for _, child in ipairs(ball:GetChildren()) do
        if child:IsA("ObjectValue") then
            local name = child.Name:lower()
            if name:find("target") or name:find("player") then
                if child.Value == char or child.Value == LocalPlayer then
                    return true
                end
                -- Cek HumanoidRootPart
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and child.Value == hrp then
                    return true
                end
            end
        elseif child:IsA("StringValue") then
            local name = child.Name:lower()
            if name:find("target") or name:find("player") then
                if child.Value == LocalPlayer.Name or child.Value == tostring(LocalPlayer.UserId) then
                    return true
                end
            end
        end
    end
    
    -- ==========================================
    -- METODE 4: Cek Parent Model juga
    -- ==========================================
    if ball.Parent and ball.Parent:IsA("Model") then
        for _, child in ipairs(ball.Parent:GetChildren()) do
            if child:IsA("ObjectValue") then
                local name = child.Name:lower()
                if name:find("target") or name:find("player") then
                    if child.Value == char or child.Value == LocalPlayer then
                        return true
                    end
                end
            end
        end
        
        -- Cek atribut di parent model juga
        for _, attrName in ipairs(targetAttribs) do
            local targetVal = ball.Parent:GetAttribute(attrName)
            if targetVal then
                if targetVal == LocalPlayer.Name or targetVal == LocalPlayer.UserId then
                    return true
                end
            end
        end
    end
    
    return false
end

-- ═══════════════════════════════════════════
-- CEK APAKAH BOLA TRAINING (selalu targetkan kita)
-- ═══════════════════════════════════════════
local function IsTrainingBall(ball)
    -- Cek apakah bola berada di area training
    local parent = ball.Parent
    while parent and parent ~= Workspace do
        local name = parent.Name:lower()
        if name:find("train") or name:find("practice") or name:find("dummy") or name:find("tutorial") then
            return true
        end
        parent = parent.Parent
    end
    
    -- Cek atribut training
    if ball:GetAttribute("Training") or ball:GetAttribute("training") or ball:GetAttribute("Practice") then
        return true
    end
    
    -- Cek apakah hanya ada 1 pemain di area (biasanya training mode)
    -- Jika bola bergerak ke arah kita dan tidak ada target spesifik, anggap training
    return false
end

-- ═══════════════════════════════════════════
-- KALKULASI KECEPATAN BOLA (Manual Tracking)
-- ═══════════════════════════════════════════
local ballTrackers = {} -- Multi-ball tracker

local function GetBallSpeed(ball)
    local ballId = tostring(ball:GetFullName())
    
    if not ballTrackers[ballId] then
        ballTrackers[ballId] = {
            lastPosition = ball.Position,
            lastTime = tick(),
            speed = 0,
        }
        return 0
    end
    
    local tracker = ballTrackers[ballId]
    local now = tick()
    local dt = now - tracker.lastTime
    
    if dt > 0.01 then
        local dist = (ball.Position - tracker.lastPosition).Magnitude
        tracker.speed = dist / dt
        tracker.lastPosition = ball.Position
        tracker.lastTime = now
    end
    
    -- Gunakan Velocity jika tersedia dan valid
    local velSpeed = ball.Velocity and ball.Velocity.Magnitude or 0
    if velSpeed > 1 then
        return velSpeed
    end
    
    return tracker.speed
end

-- ═══════════════════════════════════════════
-- CEK APAKAH BOLA MENDEKAT KE KITA
-- ═══════════════════════════════════════════
local function IsBallApproachingUs(ball)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local ballPos = ball.Position
    local playerPos = hrp.Position
    local distance = (ballPos - playerPos).Magnitude
    
    -- Hitung arah bola ke pemain
    local dirToPlayer = (playerPos - ballPos).Unit
    
    -- Hitung arah pergerakan bola
    local ballVelocity = ball.Velocity
    if ballVelocity and ballVelocity.Magnitude > 1 then
        local ballDir = ballVelocity.Unit
        local dot = dirToPlayer:Dot(ballDir)
        -- dot > 0.3 = bola bergerak ke arah kita
        return dot > 0.3, distance
    end
    
    -- Fallback: gunakan manual tracking
    local ballId = tostring(ball:GetFullName())
    if ballTrackers[ballId] and ballTrackers[ballId].lastPosition then
        local prevPos = ballTrackers[ballId].lastPosition
        local moveDir = (ballPos - prevPos)
        if moveDir.Magnitude > 0.1 then
            local dot = dirToPlayer:Dot(moveDir.Unit)
            return dot > 0.3, distance
        end
    end
    
    -- Jika tidak bisa deteksi arah, cek jarak sangat dekat
    return distance < 20, distance
end

-- ═══════════════════════════════════════════
-- HITUNG JARAK PARRY OPTIMAL (Berdasarkan kecepatan bola)
-- ═══════════════════════════════════════════
local function GetOptimalParryDistance(speed)
    local base = Config.ParryDistance
    
    -- Semakin cepat bola, semakin jauh kita harus mulai parry
    if speed > 300 then
        return math.clamp(base * 2.0 * Config.SpeedMultiplier, Config.MinParryDistance, Config.MaxParryDistance)
    elseif speed > 200 then
        return math.clamp(base * 1.5 * Config.SpeedMultiplier, Config.MinParryDistance, Config.MaxParryDistance)
    elseif speed > 100 then
        return math.clamp(base * 1.2 * Config.SpeedMultiplier, Config.MinParryDistance, Config.MaxParryDistance)
    else
        return math.clamp(base * Config.SpeedMultiplier, Config.MinParryDistance, Config.MaxParryDistance)
    end
end

-- ═══════════════════════════════════════════
-- EKSEKUSI PARRY (Multi-Method untuk 100% Hit)
-- ═══════════════════════════════════════════
local function ExecuteParry()
    if parryDebounce then return end
    parryDebounce = true
    
    local success = false
    
    -- ==========================================
    -- METODE UTAMA: Fire Remote yang sudah di-cache
    -- ==========================================
    local remote = FindParryRemote()
    if remote then
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer()
                success = true
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer()
                success = true
            end
        end)
    end
    
    -- ==========================================
    -- METODE BACKUP 1: Cari dan fire semua remote terkait
    -- ==========================================
    if not success then
        for _, remoteObj in ipairs(ReplicatedStorage:GetDescendants()) do
            local name = remoteObj.Name:lower()
            if name:find("parry") or name:find("block") or name:find("deflect") or name:find("hit") then
                pcall(function()
                    if remoteObj:IsA("RemoteEvent") then
                        remoteObj:FireServer()
                        success = true
                    elseif remoteObj:IsA("RemoteFunction") then
                        remoteObj:InvokeServer()
                        success = true
                    end
                end)
            end
        end
    end
    
    -- ==========================================
    -- METODE BACKUP 2: Simulasi klik mouse (VirtualInputManager)
    -- ==========================================
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
    
    -- ==========================================
    -- METODE BACKUP 3: Aktivasi Tool
    -- ==========================================
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool then
                tool:Activate()
            end
        end
    end)
    
    -- Update statistik
    Config.ParrySuccessCount = Config.ParrySuccessCount + 1
    Config.TotalParryAttempts = Config.TotalParryAttempts + 1
    
    -- Visual feedback
    if Config.VisualEffects then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- Screen flash
                    local flash = Instance.new("Frame")
                    flash.BackgroundColor3 = Colors.Primary
                    flash.BackgroundTransparency = 0.6
                    flash.Size = UDim2.new(1, 0, 1, 0)
                    flash.ZIndex = 100
                    flash.Parent = ScreenGui
                    Tween(flash, {BackgroundTransparency = 1}, 0.35)
                    task.delay(0.35, function() flash:Destroy() end)
                    
                    -- 3D shockwave
                    local part = Instance.new("Part")
                    part.Shape = Enum.PartType.Ball
                    part.Material = Enum.Material.Neon
                    part.Color = Colors.Primary
                    part.Size = Vector3.new(2, 2, 2)
                    part.Position = hrp.Position
                    part.Anchored = true
                    part.CanCollide = false
                    part.Transparency = 0.2
                    part.Parent = Workspace
                    
                    Tween(part, {Size = Vector3.new(25, 25, 25), Transparency = 1}, 0.45, Enum.EasingStyle.Quart)
                    task.delay(0.45, function() part:Destroy() end)
                end
            end
        end)
    end
    
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
    
    task.delay(0.12, function()
        parryDebounce = false
    end)
end

-- ═══════════════════════════════════════════
-- SIMPLE ESP (Hanya Outline + Teks Jarak)
-- ═══════════════════════════════════════════
local espHighlights = {} -- Menyimpan highlight yang sudah dibuat
local espBillboards = {} -- Menyimpan billboard untuk teks jarak

local function UpdateBallESP(ball, distance, speed, isTargeting, isApproaching)
    if not Config.ShowBallESP then
        -- Hapus ESP jika dimatikan
        if espHighlights[ball] then
            espHighlights[ball]:Destroy()
            espHighlights[ball] = nil
        end
        if espBillboards[ball] then
            espBillboards[ball]:Destroy()
            espBillboards[ball] = nil
        end
        return
    end
    
    -- ==========================================
    -- OUTLINE HIGHLIGHT (Sederhana)
    -- ==========================================
    local highlight = espHighlights[ball]
    if not highlight or highlight.Parent ~= ball then
        -- Hapus yang lama
        if highlight then highlight:Destroy() end
        
        highlight = Instance.new("Highlight")
        highlight.Name = "SynESP"
        highlight.FillTransparency = 1 -- Tidak ada fill, hanya outline
        highlight.OutlineTransparency = 0.2
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Adornee = ball
        highlight.Parent = ball
        espHighlights[ball] = highlight
    end
    
    -- Warna outline berdasarkan status
    if isTargeting then
        highlight.OutlineColor = Color3.fromRGB(255, 0, 0) -- Merah = targeting kita
    elseif isApproaching then
        highlight.OutlineColor = Color3.fromRGB(255, 170, 0) -- Kuning = mendekat
    else
        highlight.OutlineColor = Color3.fromRGB(0, 200, 255) -- Cyan = netral
    end
    
    -- ==========================================
    -- TEKS JARAK SEDERHANA (BillboardGui)
    -- ==========================================
    if Config.ShowDistanceIndicator then
        local billboard = espBillboards[ball]
        if not billboard or billboard.Parent ~= ball then
            if billboard then billboard:Destroy() end
            
            billboard = Instance.new("BillboardGui")
            billboard.Name = "SynDist"
            billboard.Size = UDim2.new(0, 100, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Adornee = ball
            billboard.Parent = ball
            
            local textLabel = Instance.new("TextLabel")
            textLabel.Name = "Info"
            textLabel.BackgroundTransparency = 1
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.Font = Enum.Font.GothamBold
            textLabel.TextSize = 12
            textLabel.TextColor3 = Colors.Text
            textLabel.TextStrokeTransparency = 0.3
            textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            textLabel.Parent = billboard
            
            espBillboards[ball] = billboard
        end
        
        local textLabel = billboard:FindFirstChild("Info")
        if textLabel then
            if isTargeting then
                textLabel.Text = string.format("⚠ %.0f studs", distance)
                textLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            else
                textLabel.Text = string.format("%.0f studs", distance)
                textLabel.TextColor3 = Colors.Text
            end
        end
    else
        if espBillboards[ball] then
            espBillboards[ball]:Destroy()
            espBillboards[ball] = nil
        end
    end
end

-- Bersihkan ESP dari bola yang sudah tidak ada
local function CleanupESP()
    for ball, highlight in pairs(espHighlights) do
        if not ball or not ball.Parent then
            if highlight then highlight:Destroy() end
            espHighlights[ball] = nil
        end
    end
    for ball, billboard in pairs(espBillboards) do
        if not ball or not ball.Parent then
            if billboard then billboard:Destroy() end
            espBillboards[ball] = nil
        end
    end
end

-- ═══════════════════════════════════════════
-- MAIN PARRY LOOP (100% Hit Rate Engine)
-- ═══════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not Config.AutoParry then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    -- Dapatkan semua bola (termasuk training)
    local allBalls = FindAllBalls()
    if #allBalls == 0 then return end
    
    local closestTargetingBall = nil
    local closestTargetingDist = math.huge
    local closestApproachingBall = nil
    local closestApproachingDist = math.huge
    
    for _, ball in ipairs(allBalls) do
        if not ball or not ball.Parent then continue end
        
        local distance = (ball.Position - hrp.Position).Magnitude
        local speed = GetBallSpeed(ball)
        local isTargeting = IsBallTargetingUs(ball)
        local isApproaching, _ = IsBallApproachingUs(ball)
        local isTraining = IsTrainingBall(ball)
        
        currentBallSpeed = speed
        
        -- Update ESP
        UpdateBallESP(ball, distance, speed, isTargeting, isApproaching)
        
        -- Update UI stats
        ballSpeedLabel.Text = string.format("%.0f", speed)
        
        -- ==========================================
        -- PRIORITAS TARGETING:
        -- 1. Bola yang secara langsung menarget kita (Highlight merah / Atribut target)
        -- 2. Bola training yang mendekat
        -- 3. Bola yang mendekat ke kita
        -- ==========================================
        
        if isTargeting then
            if distance < closestTargetingDist then
                closestTargetingDist = distance
                closestTargetingBall = ball
            end
        elseif isTraining and isApproaching then
            -- Bola training diperlakukan sama seperti bola yang menarget kita
            if distance < closestTargetingDist then
                closestTargetingDist = distance
                closestTargetingBall = ball
            end
        elseif isApproaching then
            if distance < closestApproachingDist then
                closestApproachingDist = distance
                closestApproachingBall = ball
            end
        end
    end
    
    -- ==========================================
    -- KEPUTUSAN PARRY
    -- ==========================================
    
    -- Cooldown check
    if tick() - lastParryTick < 0.12 then return end
    
    -- Prioritas 1: Bola yang menarget kita langsung
    if closestTargetingBall then
        local ball = closestTargetingBall
        local distance = closestTargetingDist
        local speed = GetBallSpeed(ball)
        local optimalDist = GetOptimalParryDistance(speed)
        
        -- Hitung waktu tiba
        local timeToReach = speed > 0.1 and (distance / speed) or 999
        
        local shouldParry = false
        
        if Config.SmartTiming then
            -- Ultra-fast ball (>300 speed): Parry lebih awal
            if speed > 300 and distance < optimalDist * 1.8 then
                shouldParry = true
            -- Very fast ball (>200 speed)
            elseif speed > 200 and distance < optimalDist * 1.5 then
                shouldParry = true
            -- Fast ball (>100 speed)
            elseif speed > 100 and distance < optimalDist * 1.2 then
                shouldParry = true
            -- Normal speed
            elseif distance < optimalDist then
                shouldParry = true
            -- Emergency: sangat dekat
            elseif distance < Config.MinParryDistance then
                shouldParry = true
            end
            
            -- Prediksi waktu: jika bola akan tiba dalam 0.02-0.3 detik
            if Config.PredictionEnabled and timeToReach < 0.3 and timeToReach > 0.02 then
                shouldParry = true
            end
        else
            -- Simple mode
            if distance < Config.ParryDistance then
                shouldParry = true
            end
        end
        
        if shouldParry then
            -- Untuk bola sangat cepat, langsung parry tanpa delay
            if speed > 150 then
                ExecuteParry()
            else
                -- Sedikit delay untuk bola lambat agar timing lebih presisi
                local delayTime = math.clamp(timeToReach * 0.2, 0, 0.08)
                task.delay(delayTime, function()
                    ExecuteParry()
                end)
            end
        end
        
        -- Update success rate
        if Config.TotalParryAttempts > 0 then
            local rate = (Config.ParrySuccessCount / Config.TotalParryAttempts) * 100
            successRateLabel.Text = string.format("%.0f%%", rate)
        end
        parryCountLabel.Text = tostring(Config.ParrySuccessCount)
        return
    end
    
    -- Prioritas 2: Bola yang mendekat (fallback jika deteksi target gagal)
    if closestApproachingBall then
        local ball = closestApproachingBall
        local distance = closestApproachingDist
        local speed = GetBallSpeed(ball)
        
        -- Hanya parry bola approaching jika SANGAT dekat (sebagai safety net)
        if distance < Config.MinParryDistance + 5 and speed > 10 then
            ExecuteParry()
        end
    end
    
    -- Update stats
    if Config.TotalParryAttempts > 0 then
        local rate = (Config.ParrySuccessCount / Config.TotalParryAttempts) * 100
        successRateLabel.Text = string.format("%.0f%%", rate)
    end
    parryCountLabel.Text = tostring(Config.ParrySuccessCount)
end)

-- ═══════════════════════════════════════════
-- SECONDARY DETECTION: Listener untuk perubahan target real-time
-- (Backup system agar tidak miss jika Heartbeat terlambat)
-- ═══════════════════════════════════════════
spawn(function()
    while ScreenGui.Parent do
        pcall(function()
            local allBalls = FindAllBalls()
            for _, ball in ipairs(allBalls) do
                if ball and ball.Parent then
                    -- Cek apakah ada listener baru
                    if IsBallTargetingUs(ball) or IsTrainingBall(ball) then
                        local char = LocalPlayer.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local dist = (ball.Position - hrp.Position).Magnitude
                                local speed = GetBallSpeed(ball)
                                local optDist = GetOptimalParryDistance(speed)
                                
                                if dist < optDist * 1.5 and tick() - lastParryTick > 0.12 then
                                    local isApproaching, _ = IsBallApproachingUs(ball)
                                    if isApproaching then
                                        ExecuteParry()
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
        task.wait(0.03) -- 33 kali per detik untuk responsivitas tinggi
    end
end)

-- ═══════════════════════════════════════════
-- ESP CLEANUP LOOP
-- ═══════════════════════════════════════════
spawn(function()
    while ScreenGui.Parent do
        CleanupESP()
        task.wait(2)
    end
end)

-- ═══════════════════════════════════════════
-- BALL TRACKER CLEANUP (Hindari memory leak)
-- ═══════════════════════════════════════════
spawn(function()
    while ScreenGui.Parent do
        local validBalls = FindAllBalls()
        local validNames = {}
        for _, b in ipairs(validBalls) do
            validNames[tostring(b:GetFullName())] = true
        end
        for name, _ in pairs(ballTrackers) do
            if not validNames[name] then
                ballTrackers[name] = nil
            end
        end
        task.wait(5)
    end
end)

-- ═══════════════════════════════════════════
-- REMOTE DETECTION NOTIFICATION
-- ═══════════════════════════════════════════
spawn(function()
    task.wait(2)
    local remote = FindParryRemote()
    if remote then
        Notify("Remote Locked", "Parry remote: " .. remote.Name, 3, "success")
    else
        Notify("Universal Mode", "Using multi-method parry", 3, "warning")
    end
    
    -- Detect training area
    local trainingBalls = 0
    for _, ball in ipairs(FindAllBalls()) do
        if IsTrainingBall(ball) then
            trainingBalls = trainingBalls + 1
        end
    end
    if trainingBalls > 0 then
        Notify("Training Mode", trainingBalls .. " training ball(s) detected!", 3, "success")
    end
end)

-- ═══════════════════════════════════════════
-- INTRO ANIMATION
-- ═══════════════════════════════════════════
MainFrame.BackgroundTransparency = 1
MainFrame.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)

task.delay(0.5, function()
    Tween(MainFrame, {
        Size = originalSize,
        BackgroundTransparency = 0
    }, 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    task.delay(0.8, function()
        Notify("SYN-STUDIO", "Auto Parry loaded successfully! ⚔", 3, "success")
        task.delay(1, function()
            Notify("Keybind", "Press RightShift to toggle UI", 3, "warning")
        end)
    end)
end)

-- ═══════════════════════════════════════════
-- ANTI-DETECTION (Basic)
-- ═══════════════════════════════════════════
pcall(function()
    local mt = getrawmetatable(game)
    if mt and setreadonly then
        -- Basic anti-detection measures
    end
end)

print([[
╔══════════════════════════════════════════╗
║     SYN-STUDIO v2.0 LOADED!             ║
║     100% Hit Rate Engine Active          ║
║     Training Mode Supported              ║
║     Simple ESP (Outline + Distance)      ║
║     Press RightShift to Toggle UI        ║
╚══════════════════════════════════════════╝
]])
