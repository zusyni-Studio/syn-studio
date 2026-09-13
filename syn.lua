--[[
    ╔══════════════════════════════════════════════════════╗
    ║              SYN-STUDIO v2.1                        ║
    ║         Blade Ball Auto Parry Script                ║
    ║  Perfect Parry • Zero Miss • Anime UI • Responsive  ║
    ║              (STABLE & SAFE EDITION)                 ║
    ╚══════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════
-- SAFE SERVICES
-- ═══════════════════════════════════════════
local function SafeService(name)
    local ok, svc = pcall(function()
        if cloneref then return cloneref(game:GetService(name)) end
        return game:GetService(name)
    end)
    return ok and svc or game:GetService(name)
end

local Players = SafeService("Players")
local RunService = SafeService("RunService")
local ReplicatedStorage = SafeService("ReplicatedStorage")
local UserInputService = SafeService("UserInputService")
local TweenService = SafeService("TweenService")
local Workspace = SafeService("Workspace")
local GuiService = SafeService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ═══════════════════════════════════════════
-- DEVICE & RESPONSIVE
-- ═══════════════════════════════════════════
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local VP = Camera.ViewportSize

local function GetViewport()
    VP = Camera.ViewportSize
    return VP
end

local function CalcWindowSize()
    local v = GetViewport()
    local w, h
    if IsMobile then
        local portrait = v.Y > v.X
        w = math.clamp(v.X * (portrait and 0.92 or 0.7), 300, 520)
        h = math.clamp(v.Y * (portrait and 0.55 or 0.7), 300, 560)
    else
        w = math.clamp(v.X * 0.35, 360, 500)
        h = math.clamp(v.Y * 0.7, 350, 580)
    end
    return math.floor(w), math.floor(h)
end

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
    Mode = "Normal", -- "Brutal", "Normal", "Santai"
}

-- Mode presets
local ModePresets = {
    Brutal = {
        ParryDistance = 85,
        MinParryDistance = 25,
        MaxParryDistance = 130,
        SpeedMultiplier = 1.8,
        PredictionEnabled = true,
        SmartTiming = true,
    },
    Normal = {
        ParryDistance = 55,
        MinParryDistance = 15,
        MaxParryDistance = 85,
        SpeedMultiplier = 1.0,
        PredictionEnabled = true,
        SmartTiming = true,
    },
    Santai = {
        ParryDistance = 30,
        MinParryDistance = 8,
        MaxParryDistance = 50,
        SpeedMultiplier = 0.6,
        PredictionEnabled = false,
        SmartTiming = true,
    },
}

local function ApplyMode(modeName)
    local preset = ModePresets[modeName]
    if not preset then return end
    Config.Mode = modeName
    for k, v in pairs(preset) do
        Config[k] = v
    end
end

-- ═══════════════════════════════════════════
-- COLOR PALETTE
-- ═══════════════════════════════════════════
local Colors = {
    Primary = Color3.fromRGB(255, 85, 125),
    Secondary = Color3.fromRGB(120, 80, 255),
    Accent = Color3.fromRGB(255, 170, 50),
    Success = Color3.fromRGB(80, 255, 120),
    Danger = Color3.fromRGB(255, 60, 60),
    Background = Color3.fromRGB(15, 15, 25),
    BackgroundLight = Color3.fromRGB(25, 25, 45),
    Card = Color3.fromRGB(30, 30, 55),
    CardHover = Color3.fromRGB(40, 40, 70),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(180, 180, 200),
    Border = Color3.fromRGB(60, 60, 100),
    GlowPink = Color3.fromRGB(255, 100, 150),
    GlowPurple = Color3.fromRGB(150, 100, 255),
    GlowBlue = Color3.fromRGB(80, 150, 255),
    Brutal = Color3.fromRGB(255, 40, 40),
    Santai = Color3.fromRGB(80, 200, 255),
}

-- ═══════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════
local function CreateCorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c
end

local function CreateStroke(p, col, th, tr)
    local s = Instance.new("UIStroke"); s.Color = col or Colors.Border; s.Thickness = th or 1
    s.Transparency = tr or 0.5; s.Parent = p; return s
end

local function CreateGradient(p, c1, c2, rot)
    local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(c1 or Colors.Primary, c2 or Colors.Secondary)
    g.Rotation = rot or 45; g.Parent = p; return g
end

local function CreateShadow(p, sz)
    local s = Instance.new("ImageLabel"); s.Name = "_Sh"; s.BackgroundTransparency = 1
    s.Image = "rbxassetid://7912134082"; s.ImageColor3 = Color3.new(0,0,0); s.ImageTransparency = 0.5
    s.Size = UDim2.new(1, sz or 30, 1, sz or 30)
    s.Position = UDim2.new(0, -(sz or 30)/2, 0, -(sz or 30)/2)
    s.ZIndex = p.ZIndex - 1
    pcall(function() s.Parent = p end)
    return s
end

local function Tween(obj, props, dur, style, dir)
    if not obj or not obj.Parent then return end
    local t = TweenService:Create(obj, TweenInfo.new(dur or 0.3, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    t:Play(); return t
end

local function Ripple(btn, col)
    local r = Instance.new("Frame"); r.BackgroundColor3 = col or Colors.Text
    r.BackgroundTransparency = 0.7; r.BorderSizePixel = 0; r.ZIndex = btn.ZIndex + 5; r.Parent = btn
    CreateCorner(r, 999)
    local m = UserInputService:GetMouseLocation(); local a = btn.AbsolutePosition
    r.Size = UDim2.new(0,0,0,0); r.Position = UDim2.new(0, m.X-a.X, 0, m.Y-a.Y)
    r.AnchorPoint = Vector2.new(0.5,0.5)
    local mx = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2.5
    Tween(r, {Size = UDim2.new(0,mx,0,mx), BackgroundTransparency = 1}, 0.6)
    task.delay(0.6, function() r:Destroy() end)
end

-- ═══════════════════════════════════════════
-- SAFE GUI CREATION
-- ═══════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SynStudio_" .. math.random(100,999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999

local parented = false
if gethui then pcall(function() ScreenGui.Parent = gethui(); parented = true end) end
if not parented then pcall(function() ScreenGui.Parent = game:GetService("CoreGui"); parented = true end) end
if not parented then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ═══════════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ═══════════════════════════════════════════
local NotifHolder = Instance.new("Frame")
NotifHolder.Name = "Notifs"; NotifHolder.BackgroundTransparency = 1
NotifHolder.Size = UDim2.new(0, IsMobile and 220 or 300, 1, 0)
NotifHolder.Position = UDim2.new(1, -(IsMobile and 230 or 320), 0, 0)
NotifHolder.ZIndex = 50; NotifHolder.Parent = ScreenGui

local nLayout = Instance.new("UIListLayout"); nLayout.Padding = UDim.new(0, 8)
nLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
nLayout.SortOrder = Enum.SortOrder.LayoutOrder; nLayout.Parent = NotifHolder
local nPad = Instance.new("UIPadding"); nPad.PaddingBottom = UDim.new(0, 20); nPad.Parent = NotifHolder

local function Notify(title, message, duration, notifType)
    local color = Colors.Primary
    if notifType == "success" then color = Colors.Success
    elseif notifType == "error" then color = Colors.Danger
    elseif notifType == "warning" then color = Colors.Accent end

    local notif = Instance.new("Frame"); notif.BackgroundColor3 = Colors.Card
    notif.Size = UDim2.new(1,0,0,65); notif.ClipsDescendants = true; notif.ZIndex = 51; notif.Parent = NotifHolder
    CreateCorner(notif, 10); CreateStroke(notif, color, 1.5, 0.3)

    local bar = Instance.new("Frame"); bar.BackgroundColor3 = color; bar.Size = UDim2.new(0,3,1,0)
    bar.BorderSizePixel = 0; bar.ZIndex = 52; bar.Parent = notif

    local ico = Instance.new("TextLabel"); ico.BackgroundTransparency = 1
    ico.Size = UDim2.new(0,25,0,25); ico.Position = UDim2.new(0,12,0,8)
    ico.Font = Enum.Font.GothamBold; ico.TextSize = 16; ico.TextColor3 = color; ico.ZIndex = 52; ico.Parent = notif
    if notifType == "success" then ico.Text = "✓"
    elseif notifType == "error" then ico.Text = "✕"
    elseif notifType == "warning" then ico.Text = "⚠"
    else ico.Text = "★" end

    local tLbl = Instance.new("TextLabel"); tLbl.BackgroundTransparency = 1
    tLbl.Size = UDim2.new(1,-50,0,18); tLbl.Position = UDim2.new(0,42,0,8)
    tLbl.Font = Enum.Font.GothamBold; tLbl.TextSize = IsMobile and 11 or 13; tLbl.TextColor3 = Colors.Text
    tLbl.TextXAlignment = Enum.TextXAlignment.Left; tLbl.Text = title; tLbl.ZIndex = 52; tLbl.Parent = notif

    local mLbl = Instance.new("TextLabel"); mLbl.BackgroundTransparency = 1
    mLbl.Size = UDim2.new(1,-50,0,16); mLbl.Position = UDim2.new(0,42,0,28)
    mLbl.Font = Enum.Font.Gotham; mLbl.TextSize = IsMobile and 9 or 11; mLbl.TextColor3 = Colors.TextDim
    mLbl.TextXAlignment = Enum.TextXAlignment.Left; mLbl.Text = message; mLbl.ZIndex = 52; mLbl.Parent = notif

    local pBg = Instance.new("Frame"); pBg.BackgroundColor3 = Colors.BackgroundLight
    pBg.Size = UDim2.new(1,-16,0,2); pBg.Position = UDim2.new(0,8,1,-6); pBg.BorderSizePixel = 0
    pBg.ZIndex = 52; pBg.Parent = notif; CreateCorner(pBg, 1)
    local pFill = Instance.new("Frame"); pFill.BackgroundColor3 = color
    pFill.Size = UDim2.new(1,0,1,0); pFill.BorderSizePixel = 0; pFill.ZIndex = 53; pFill.Parent = pBg
    CreateCorner(pFill, 1)

    notif.BackgroundTransparency = 1; notif.Size = UDim2.new(1,0,0,0)
    Tween(notif, {Size = UDim2.new(1,0,0,65), BackgroundTransparency = 0}, 0.4)
    Tween(pFill, {Size = UDim2.new(0,0,1,0)}, duration or 3, Enum.EasingStyle.Linear)

    task.delay(duration or 3, function()
        Tween(notif, {Size = UDim2.new(1,0,0,0), BackgroundTransparency = 1}, 0.3)
        task.delay(0.35, function() notif:Destroy() end)
    end)
end

-- ═══════════════════════════════════════════
-- FLOAT ICON (Minimize State)
-- ═══════════════════════════════════════════
local FloatIcon = Instance.new("TextButton")
FloatIcon.Name = "FloatIcon"
FloatIcon.BackgroundColor3 = Colors.Primary
FloatIcon.Size = UDim2.new(0, IsMobile and 50 or 48, 0, IsMobile and 50 or 48)
FloatIcon.Position = UDim2.new(0, 15, 0.5, -(IsMobile and 25 or 24))
FloatIcon.Font = Enum.Font.GothamBold
FloatIcon.TextSize = IsMobile and 22 or 20
FloatIcon.TextColor3 = Colors.Text
FloatIcon.Text = "⚔"
FloatIcon.ZIndex = 30
FloatIcon.Visible = false
FloatIcon.Parent = ScreenGui
CreateCorner(FloatIcon, 999)
CreateStroke(FloatIcon, Colors.GlowPurple, 2, 0.3)
CreateShadow(FloatIcon, 20)

-- Float icon gradient background
local floatGrad = Instance.new("UIGradient")
floatGrad.Color = ColorSequence.new(Colors.Primary, Colors.Secondary)
floatGrad.Rotation = 135
floatGrad.Parent = FloatIcon

-- Float icon pulse animation
task.spawn(function()
    while ScreenGui.Parent do
        if FloatIcon.Visible then
            Tween(FloatIcon, {Size = UDim2.new(0, (IsMobile and 54 or 52), 0, (IsMobile and 54 or 52))}, 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1)
            Tween(FloatIcon, {Size = UDim2.new(0, (IsMobile and 50 or 48), 0, (IsMobile and 50 or 48))}, 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1)
        else
            task.wait(0.5)
        end
    end
end)

-- Float icon dragging
local floatDrag, floatDragInput, floatDragStart, floatStartPos
FloatIcon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        floatDrag = true; floatDragStart = input.Position; floatStartPos = FloatIcon.Position
    end
end)
FloatIcon.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        floatDragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == floatDragInput and floatDrag then
        local delta = input.Position - floatDragStart
        local vp = GetViewport()
        local newX = math.clamp(floatStartPos.X.Offset + delta.X, 0, vp.X - 60)
        local newY = math.clamp(floatStartPos.Y.Offset + delta.Y, -vp.Y/2 + 30, vp.Y/2 - 30)
        FloatIcon.Position = UDim2.new(0, newX, 0.5, newY)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        floatDrag = false
    end
end)

-- ═══════════════════════════════════════════
-- MAIN WINDOW
-- ═══════════════════════════════════════════
local winW, winH = CalcWindowSize()

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.Size = UDim2.new(0, winW, 0, winH)
MainFrame.Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2)
MainFrame.ClipsDescendants = true
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui
CreateCorner(MainFrame, IsMobile and 12 or 14)
CreateStroke(MainFrame, Colors.Border, 1, 0.4)
CreateShadow(MainFrame, 50)

-- Responsive resize
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local nw, nh = CalcWindowSize()
    Tween(MainFrame, {Size = UDim2.new(0, nw, 0, nh), Position = UDim2.new(0.5, -nw/2, 0.5, -nh/2)}, 0.4)
end)

-- BG Glows
local bgG1 = Instance.new("Frame"); bgG1.BackgroundColor3 = Colors.Primary
bgG1.BackgroundTransparency = 0.92; bgG1.Size = UDim2.new(0,200,0,200)
bgG1.Position = UDim2.new(0,-50,0,-50); bgG1.BorderSizePixel = 0; bgG1.ZIndex = 0
bgG1.Parent = MainFrame; CreateCorner(bgG1, 100)

local bgG2 = Instance.new("Frame"); bgG2.BackgroundColor3 = Colors.Secondary
bgG2.BackgroundTransparency = 0.92; bgG2.Size = UDim2.new(0,250,0,250)
bgG2.Position = UDim2.new(1,-150,1,-150); bgG2.BorderSizePixel = 0; bgG2.ZIndex = 0
bgG2.Parent = MainFrame; CreateCorner(bgG2, 125)

task.spawn(function()
    while ScreenGui.Parent do
        Tween(bgG1, {Position = UDim2.new(0,-30,0,-30)}, 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(3)
        Tween(bgG1, {Position = UDim2.new(0,-70,0,-70)}, 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(3)
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        Tween(bgG2, {Position = UDim2.new(1,-130,1,-130)}, 4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(4)
        Tween(bgG2, {Position = UDim2.new(1,-170,1,-170)}, 4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(4)
    end
end)

-- ═══════════════════════════════════════════
-- TITLE BAR
-- ═══════════════════════════════════════════
local hH = IsMobile and 48 or 55
local TitleBar = Instance.new("Frame"); TitleBar.Name = "TitleBar"
TitleBar.BackgroundColor3 = Colors.BackgroundLight; TitleBar.Size = UDim2.new(1,0,0,hH)
TitleBar.BorderSizePixel = 0; TitleBar.ZIndex = 15; TitleBar.Parent = MainFrame
CreateCorner(TitleBar, IsMobile and 12 or 14)

local tbFix = Instance.new("Frame"); tbFix.BackgroundColor3 = Colors.BackgroundLight
tbFix.Size = UDim2.new(1,0,0,15); tbFix.Position = UDim2.new(0,0,1,-15)
tbFix.BorderSizePixel = 0; tbFix.ZIndex = 15; tbFix.Parent = TitleBar

local tbLine = Instance.new("Frame"); tbLine.BackgroundColor3 = Colors.Primary
tbLine.Size = UDim2.new(1,0,0,2); tbLine.Position = UDim2.new(0,0,1,-2)
tbLine.BorderSizePixel = 0; tbLine.ZIndex = 16; tbLine.Parent = TitleBar
CreateGradient(tbLine, Colors.Primary, Colors.Secondary, 0)

-- Logo
local logoFrame = Instance.new("Frame"); logoFrame.BackgroundColor3 = Colors.Primary
logoFrame.Size = UDim2.new(0, IsMobile and 30 or 35, 0, IsMobile and 30 or 35)
logoFrame.Position = UDim2.new(0, IsMobile and 8 or 12, 0.5, -(IsMobile and 15 or 17))
logoFrame.ZIndex = 17; logoFrame.Parent = TitleBar
CreateCorner(logoFrame, IsMobile and 8 or 10)
CreateGradient(logoFrame, Colors.Primary, Colors.GlowPurple, 135)

local logoText = Instance.new("TextLabel"); logoText.BackgroundTransparency = 1
logoText.Size = UDim2.new(1,0,1,0); logoText.Font = Enum.Font.GothamBold
logoText.TextSize = IsMobile and 15 or 18; logoText.TextColor3 = Colors.Text
logoText.Text = "⚔"; logoText.ZIndex = 18; logoText.Parent = logoFrame

task.spawn(function()
    while ScreenGui.Parent do
        Tween(logoFrame, {Rotation = 10}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(1.5)
        Tween(logoFrame, {Rotation = -10}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(1.5)
    end
end)

local titleOff = IsMobile and 44 or 55
local titleText = Instance.new("TextLabel"); titleText.BackgroundTransparency = 1
titleText.Size = UDim2.new(0, 160, 0, 20)
titleText.Position = UDim2.new(0, titleOff, 0, IsMobile and 6 or 8)
titleText.Font = Enum.Font.GothamBold; titleText.TextSize = IsMobile and 14 or 17
titleText.TextColor3 = Colors.Text; titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Text = "SYN-STUDIO"; titleText.ZIndex = 17; titleText.Parent = TitleBar

local subText = Instance.new("TextLabel"); subText.BackgroundTransparency = 1
subText.Size = UDim2.new(0, 200, 0, 12)
subText.Position = UDim2.new(0, titleOff, 0, IsMobile and 25 or 30)
subText.Font = Enum.Font.Gotham; subText.TextSize = IsMobile and 8 or 10
subText.TextColor3 = Colors.TextDim; subText.TextXAlignment = Enum.TextXAlignment.Left
subText.Text = "⚡ Blade Ball Auto Parry • v2.1"; subText.ZIndex = 17; subText.Parent = TitleBar

-- Status dot
local statusDot = Instance.new("Frame"); statusDot.BackgroundColor3 = Colors.Success
statusDot.Size = UDim2.new(0,8,0,8); statusDot.Position = UDim2.new(1, IsMobile and -62 or -70, 0.5, -4)
statusDot.ZIndex = 17; statusDot.Parent = TitleBar; CreateCorner(statusDot, 4)

task.spawn(function()
    while ScreenGui.Parent do
        Tween(statusDot, {BackgroundTransparency = 0.5}, 0.8, Enum.EasingStyle.Sine)
        task.wait(0.8)
        Tween(statusDot, {BackgroundTransparency = 0}, 0.8, Enum.EasingStyle.Sine)
        task.wait(0.8)
    end
end)

local statusLabel = Instance.new("TextLabel"); statusLabel.BackgroundTransparency = 1
statusLabel.Size = UDim2.new(0,42,0,16)
statusLabel.Position = UDim2.new(1, IsMobile and -50 or -55, 0.5, -8)
statusLabel.Font = Enum.Font.GothamBold; statusLabel.TextSize = IsMobile and 8 or 10
statusLabel.TextColor3 = Colors.Success; statusLabel.Text = "ACTIVE"
statusLabel.ZIndex = 17; statusLabel.Parent = TitleBar

-- Minimize Button
local minBtn = Instance.new("TextButton"); minBtn.BackgroundColor3 = Colors.Card
minBtn.Size = UDim2.new(0, IsMobile and 28 or 30, 0, IsMobile and 28 or 30)
minBtn.Position = UDim2.new(1, -(IsMobile and 32 or 35), 0.5, -(IsMobile and 14 or 15))
minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = IsMobile and 14 or 16
minBtn.TextColor3 = Colors.TextDim; minBtn.Text = "−"; minBtn.ZIndex = 18
minBtn.Parent = TitleBar; CreateCorner(minBtn, 8)

-- ═══════════════════════════════════════════
-- DRAGGING (Main Window)
-- ═══════════════════════════════════════════
local dragging, dragInput, dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
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
        local vp = GetViewport()
        local nx = math.clamp(startPos.X.Offset + delta.X, -vp.X/2 + 50, vp.X/2 - 50)
        local ny = math.clamp(startPos.Y.Offset + delta.Y, -vp.Y/2 + 30, vp.Y/2 - 30)
        Tween(MainFrame, {Position = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)}, 0.08, Enum.EasingStyle.Quad)
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
local ContentFrame = Instance.new("ScrollingFrame"); ContentFrame.Name = "Content"
ContentFrame.BackgroundTransparency = 1
ContentFrame.Size = UDim2.new(1, -16, 1, -(hH + 8))
ContentFrame.Position = UDim2.new(0, 8, 0, hH + 4)
ContentFrame.ScrollBarThickness = 3; ContentFrame.ScrollBarImageColor3 = Colors.Primary
ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentFrame.CanvasSize = UDim2.new(0,0,0,0)
ContentFrame.ZIndex = 11; ContentFrame.Parent = MainFrame

local cLayout = Instance.new("UIListLayout"); cLayout.Padding = UDim.new(0, IsMobile and 8 or 10)
cLayout.SortOrder = Enum.SortOrder.LayoutOrder; cLayout.Parent = ContentFrame

-- ═══════════════════════════════════════════
-- STATS DASHBOARD
-- ═══════════════════════════════════════════
local StatsCard = Instance.new("Frame"); StatsCard.BackgroundColor3 = Colors.Card
StatsCard.Size = UDim2.new(1,0,0, IsMobile and 80 or 90); StatsCard.LayoutOrder = 1
StatsCard.ZIndex = 12; StatsCard.Parent = ContentFrame
CreateCorner(StatsCard, 12); CreateStroke(StatsCard, Colors.Border, 1, 0.6)

local statsHdr = Instance.new("TextLabel"); statsHdr.BackgroundTransparency = 1
statsHdr.Size = UDim2.new(1,0,0,20); statsHdr.Position = UDim2.new(0,12,0,6)
statsHdr.Font = Enum.Font.GothamBold; statsHdr.TextSize = IsMobile and 10 or 12
statsHdr.TextColor3 = Colors.TextDim; statsHdr.TextXAlignment = Enum.TextXAlignment.Left
statsHdr.Text = "📊 LIVE STATISTICS"; statsHdr.ZIndex = 13; statsHdr.Parent = StatsCard

local function CreateStatBox(parent, posScale, icon, label, value, color)
    local boxW = IsMobile and 95 or 130
    local box = Instance.new("Frame"); box.BackgroundColor3 = Colors.BackgroundLight
    box.Size = UDim2.new(0.31, -4, 0, IsMobile and 42 or 48)
    box.LayoutOrder = posScale
    box.ZIndex = 13; box.Parent = parent
    CreateCorner(box, 8)

    local iLbl = Instance.new("TextLabel"); iLbl.BackgroundTransparency = 1
    iLbl.Size = UDim2.new(0,20,1,0); iLbl.Position = UDim2.new(0,6,0,0)
    iLbl.Font = Enum.Font.GothamBold; iLbl.TextSize = IsMobile and 13 or 16
    iLbl.TextColor3 = color; iLbl.Text = icon; iLbl.ZIndex = 14; iLbl.Parent = box

    local lLbl = Instance.new("TextLabel"); lLbl.BackgroundTransparency = 1
    lLbl.Size = UDim2.new(1,-30,0,12); lLbl.Position = UDim2.new(0,28,0,IsMobile and 4 or 6)
    lLbl.Font = Enum.Font.Gotham; lLbl.TextSize = IsMobile and 7 or 9
    lLbl.TextColor3 = Colors.TextDim; lLbl.TextXAlignment = Enum.TextXAlignment.Left
    lLbl.Text = label; lLbl.ZIndex = 14; lLbl.Parent = box

    local vLbl = Instance.new("TextLabel"); vLbl.Name = "Value"; vLbl.BackgroundTransparency = 1
    vLbl.Size = UDim2.new(1,-30,0,16); vLbl.Position = UDim2.new(0,28,0, IsMobile and 17 or 22)
    vLbl.Font = Enum.Font.GothamBold; vLbl.TextSize = IsMobile and 12 or 15
    vLbl.TextColor3 = color; vLbl.TextXAlignment = Enum.TextXAlignment.Left
    vLbl.Text = value; vLbl.ZIndex = 14; vLbl.Parent = box
    return vLbl
end

-- Stats row
local statsRow = Instance.new("Frame"); statsRow.BackgroundTransparency = 1
statsRow.Size = UDim2.new(1,-16,0, IsMobile and 42 or 48)
statsRow.Position = UDim2.new(0,8,0, IsMobile and 28 or 35)
statsRow.ZIndex = 13; statsRow.Parent = StatsCard
local sRowLayout = Instance.new("UIListLayout"); sRowLayout.FillDirection = Enum.FillDirection.Horizontal
sRowLayout.Padding = UDim.new(0,6); sRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
sRowLayout.Parent = statsRow

local parryCountLabel = CreateStatBox(statsRow, 1, "⚔", "PARRIES", "0", Colors.Primary)
local successRateLabel = CreateStatBox(statsRow, 2, "✦", "SUCCESS", "100%", Colors.Success)
local ballSpeedLabel = CreateStatBox(statsRow, 3, "⚡", "SPEED", "0", Colors.Accent)

-- ═══════════════════════════════════════════
-- COMPONENT BUILDERS
-- ═══════════════════════════════════════════
local function CreateSection(title, icon, layoutOrder)
    local sec = Instance.new("Frame"); sec.Name = title; sec.BackgroundColor3 = Colors.Card
    sec.Size = UDim2.new(1,0,0,0); sec.AutomaticSize = Enum.AutomaticSize.Y
    sec.LayoutOrder = layoutOrder; sec.ZIndex = 12; sec.Parent = ContentFrame
    CreateCorner(sec, 12); CreateStroke(sec, Colors.Border, 1, 0.6)

    local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0,10)
    pad.PaddingBottom = UDim.new(0,10); pad.PaddingLeft = UDim.new(0,12)
    pad.PaddingRight = UDim.new(0,12); pad.Parent = sec

    local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, IsMobile and 7 or 10)
    lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = sec

    local hdr = Instance.new("TextLabel"); hdr.BackgroundTransparency = 1
    hdr.Size = UDim2.new(1,0,0,20); hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = IsMobile and 11 or 13; hdr.TextColor3 = Colors.Text
    hdr.TextXAlignment = Enum.TextXAlignment.Left; hdr.Text = icon.."  "..title
    hdr.LayoutOrder = 0; hdr.ZIndex = 13; hdr.Parent = sec

    local div = Instance.new("Frame"); div.BackgroundColor3 = Colors.Border
    div.BackgroundTransparency = 0.5; div.Size = UDim2.new(1,0,0,1)
    div.BorderSizePixel = 0; div.LayoutOrder = 1; div.ZIndex = 13; div.Parent = sec
    return sec
end

local function CreateToggle(parent, label, default, layoutOrder, callback)
    local cH = IsMobile and 36 or 40
    local f = Instance.new("Frame"); f.BackgroundColor3 = Colors.BackgroundLight
    f.Size = UDim2.new(1,0,0,cH); f.LayoutOrder = layoutOrder; f.ZIndex = 13; f.Parent = parent
    CreateCorner(f, 8)

    local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1
    l.Size = UDim2.new(1,-60,1,0); l.Position = UDim2.new(0,10,0,0)
    l.Font = Enum.Font.Gotham; l.TextSize = IsMobile and 10 or 12; l.TextColor3 = Colors.Text
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Text = label; l.ZIndex = 14; l.Parent = f

    local tW, tH = IsMobile and 38 or 44, IsMobile and 18 or 22
    local kS = tH - 4

    local tBg = Instance.new("Frame"); tBg.BackgroundColor3 = default and Colors.Primary or Color3.fromRGB(60,60,80)
    tBg.Size = UDim2.new(0,tW,0,tH); tBg.Position = UDim2.new(1,-(tW+8),0.5,-tH/2)
    tBg.ZIndex = 14; tBg.Parent = f; CreateCorner(tBg, tH/2)

    local tC = Instance.new("Frame"); tC.BackgroundColor3 = Colors.Text
    tC.Size = UDim2.new(0,kS,0,kS)
    tC.Position = default and UDim2.new(1,-(kS+2),0.5,-kS/2) or UDim2.new(0,2,0.5,-kS/2)
    tC.ZIndex = 15; tC.Parent = tBg; CreateCorner(tC, kS/2)

    local enabled = default
    local btn = Instance.new("TextButton"); btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1,0,1,0); btn.Text = ""; btn.ZIndex = 16; btn.Parent = f

    btn.MouseButton1Click:Connect(function()
        enabled = not enabled; Ripple(f, Colors.Primary)
        if enabled then
            Tween(tBg, {BackgroundColor3 = Colors.Primary}, 0.3)
            Tween(tC, {Position = UDim2.new(1,-(kS+2),0.5,-kS/2)}, 0.3, Enum.EasingStyle.Back)
        else
            Tween(tBg, {BackgroundColor3 = Color3.fromRGB(60,60,80)}, 0.3)
            Tween(tC, {Position = UDim2.new(0,2,0.5,-kS/2)}, 0.3, Enum.EasingStyle.Back)
        end
        if callback then callback(enabled) end
    end)

    btn.MouseEnter:Connect(function() Tween(f, {BackgroundColor3 = Colors.CardHover}, 0.2) end)
    btn.MouseLeave:Connect(function() Tween(f, {BackgroundColor3 = Colors.BackgroundLight}, 0.2) end)
    return f
end

local function CreateSlider(parent, label, min, max, default, layoutOrder, callback)
    local cH = IsMobile and 48 or 55
    local f = Instance.new("Frame"); f.BackgroundColor3 = Colors.BackgroundLight
    f.Size = UDim2.new(1,0,0,cH); f.LayoutOrder = layoutOrder; f.ZIndex = 13; f.Parent = parent
    CreateCorner(f, 8)

    local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1
    l.Size = UDim2.new(1,-55,0,18); l.Position = UDim2.new(0,10,0,4)
    l.Font = Enum.Font.Gotham; l.TextSize = IsMobile and 9 or 11; l.TextColor3 = Colors.Text
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Text = label; l.ZIndex = 14; l.Parent = f

    local vl = Instance.new("TextLabel"); vl.BackgroundTransparency = 1
    vl.Size = UDim2.new(0,45,0,18); vl.Position = UDim2.new(1,-50,0,4)
    vl.Font = Enum.Font.GothamBold; vl.TextSize = IsMobile and 10 or 12
    vl.TextColor3 = Colors.Primary; vl.Text = tostring(default); vl.ZIndex = 14; vl.Parent = f

    local sBg = Instance.new("Frame"); sBg.BackgroundColor3 = Color3.fromRGB(40,40,65)
    sBg.Size = UDim2.new(1,-20,0,6); sBg.Position = UDim2.new(0,10,0, IsMobile and 28 or 33)
    sBg.ZIndex = 14; sBg.Parent = f; CreateCorner(sBg, 3)

    local sFill = Instance.new("Frame"); sFill.BackgroundColor3 = Colors.Primary
    sFill.Size = UDim2.new((default-min)/(max-min),0,1,0); sFill.BorderSizePixel = 0
    sFill.ZIndex = 15; sFill.Parent = sBg; CreateCorner(sFill, 3)
    CreateGradient(sFill, Colors.Primary, Colors.GlowPurple, 0)

    local kS = IsMobile and 14 or 16
    local sKnob = Instance.new("Frame"); sKnob.BackgroundColor3 = Colors.Text
    sKnob.Size = UDim2.new(0,kS,0,kS)
    sKnob.Position = UDim2.new((default-min)/(max-min),-kS/2,0.5,-kS/2)
    sKnob.ZIndex = 16; sKnob.Parent = sBg; CreateCorner(sKnob, kS/2)
    CreateStroke(sKnob, Colors.Primary, 2, 0)

    local sliding = false
    local sBtn = Instance.new("TextButton"); sBtn.BackgroundTransparency = 1
    sBtn.Size = UDim2.new(1,0,0,20); sBtn.Position = UDim2.new(0,0,0,IsMobile and 22 or 26)
    sBtn.Text = ""; sBtn.ZIndex = 17; sBtn.Parent = f

    sBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then sliding = true end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((inp.Position.X - sBg.AbsolutePosition.X) / sBg.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max-min)*rel)
            Tween(sFill, {Size = UDim2.new(rel,0,1,0)}, 0.05)
            Tween(sKnob, {Position = UDim2.new(rel,-kS/2,0.5,-kS/2)}, 0.05)
            vl.Text = tostring(val)
            if callback then callback(val) end
        end
    end)
    return f
end

-- ═══════════════════════════════════════════
-- MODE SELECTOR (Brutal / Normal / Santai)
-- ═══════════════════════════════════════════
local function CreateModeSelector(parent, layoutOrder)
    local cH = IsMobile and 44 or 50
    local f = Instance.new("Frame"); f.BackgroundColor3 = Colors.BackgroundLight
    f.Size = UDim2.new(1,0,0,cH); f.LayoutOrder = layoutOrder; f.ZIndex = 13; f.Parent = parent
    CreateCorner(f, 8)

    local modes = {
        {name = "Brutal", icon = "🔥", color = Colors.Brutal, desc = "Jarak jauh, sangat agresif"},
        {name = "Normal", icon = "⚡", color = Colors.Primary, desc = "Seimbang & konsisten"},
        {name = "Santai", icon = "🛡", color = Colors.Santai, desc = "Hanya jarak dekat, aman"},
    }

    local modeLabel = Instance.new("TextLabel"); modeLabel.BackgroundTransparency = 1
    modeLabel.Size = UDim2.new(1,0,0,14); modeLabel.Position = UDim2.new(0,10,0,3)
    modeLabel.Font = Enum.Font.Gotham; modeLabel.TextSize = IsMobile and 8 or 10
    modeLabel.TextColor3 = Colors.TextDim; modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.Text = "MODE PRESET"; modeLabel.ZIndex = 14; modeLabel.Parent = f

    local btnContainer = Instance.new("Frame"); btnContainer.BackgroundTransparency = 1
    btnContainer.Size = UDim2.new(1,-16,0, IsMobile and 24 or 28)
    btnContainer.Position = UDim2.new(0,8,0, IsMobile and 18 or 20)
    btnContainer.ZIndex = 14; btnContainer.Parent = f
    local bcLayout = Instance.new("UIListLayout"); bcLayout.FillDirection = Enum.FillDirection.Horizontal
    bcLayout.Padding = UDim.new(0,6); bcLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bcLayout.Parent = btnContainer

    local modeButtons = {}
    local selectedIndicator = nil

    for i, mode in ipairs(modes) do
        local mBtn = Instance.new("TextButton"); mBtn.BackgroundColor3 = Config.Mode == mode.name and mode.color or Colors.Card
        mBtn.BackgroundTransparency = Config.Mode == mode.name and 0.2 or 0
        mBtn.Size = UDim2.new(0.32,-2,1,0); mBtn.Font = Enum.Font.GothamBold
        mBtn.TextSize = IsMobile and 9 or 11
        mBtn.TextColor3 = Config.Mode == mode.name and mode.color or Colors.TextDim
        mBtn.Text = mode.icon.." "..mode.name; mBtn.LayoutOrder = i
        mBtn.ZIndex = 15; mBtn.Parent = btnContainer
        CreateCorner(mBtn, 6)

        local mStroke = CreateStroke(mBtn, Config.Mode == mode.name and mode.color or Colors.Border, 1, Config.Mode == mode.name and 0.3 or 0.7)

        modeButtons[mode.name] = {btn = mBtn, stroke = mStroke, color = mode.color}

        mBtn.MouseButton1Click:Connect(function()
            Ripple(mBtn, mode.color)
            ApplyMode(mode.name)

            -- Update all buttons
            for mName, mData in pairs(modeButtons) do
                local isSelected = mName == mode.name
                Tween(mData.btn, {
                    BackgroundColor3 = isSelected and mData.color or Colors.Card,
                    BackgroundTransparency = isSelected and 0.2 or 0,
                    TextColor3 = isSelected and mData.color or Colors.TextDim
                }, 0.25)
                Tween(mData.stroke, {
                    Color = isSelected and mData.color or Colors.Border,
                    Transparency = isSelected and 0.3 or 0.7
                }, 0.25)
            end

            Notify("Mode: "..mode.name, mode.desc, 2, mode.name == "Brutal" and "error" or (mode.name == "Santai" and "success" or "warning"))
        end)

        mBtn.MouseEnter:Connect(function()
            if Config.Mode ~= mode.name then
                Tween(mBtn, {BackgroundColor3 = Colors.CardHover}, 0.15)
            end
        end)
        mBtn.MouseLeave:Connect(function()
            if Config.Mode ~= mode.name then
                Tween(mBtn, {BackgroundColor3 = Colors.Card}, 0.15)
            end
        end)
    end

    return f
end

-- ═══════════════════════════════════════════
-- BUILD SECTIONS
-- ═══════════════════════════════════════════
local parrySec = CreateSection("AUTO PARRY", "⚔", 2)

CreateModeSelector(parrySec, 2)

CreateToggle(parrySec, "Enable Auto Parry", true, 3, function(on)
    Config.AutoParry = on
    statusLabel.Text = on and "ACTIVE" or "IDLE"
    statusLabel.TextColor3 = on and Colors.Success or Colors.Danger
    statusDot.BackgroundColor3 = on and Colors.Success or Colors.Danger
    Notify("Auto Parry", on and "Enabled ⚔" or "Disabled", 2, on and "success" or "warning")
end)

CreateToggle(parrySec, "Smart Timing", true, 4, function(on) Config.SmartTiming = on end)
CreateToggle(parrySec, "Prediction System", true, 5, function(on) Config.PredictionEnabled = on end)
CreateSlider(parrySec, "Base Parry Distance", 10, 100, 55, 6, function(v) Config.ParryDistance = v end)
CreateSlider(parrySec, "Speed Multiplier (×10)", 5, 20, 10, 7, function(v) Config.SpeedMultiplier = v/10 end)

local visualSec = CreateSection("VISUALS & ESP", "👁", 3)
CreateToggle(visualSec, "Visual Effects", true, 2, function(on) Config.VisualEffects = on end)
CreateToggle(visualSec, "Ball ESP", true, 3, function(on) Config.ShowBallESP = on end)
CreateToggle(visualSec, "Distance Indicator", true, 4, function(on) Config.ShowDistanceIndicator = on end)

local settingSec = CreateSection("SETTINGS", "⚙", 4)
CreateToggle(settingSec, "Sound Effects", true, 2, function(on) Config.SoundEffects = on end)

-- Credits
local creditsCard = Instance.new("Frame"); creditsCard.BackgroundColor3 = Colors.Card
creditsCard.Size = UDim2.new(1,0,0, IsMobile and 50 or 60); creditsCard.LayoutOrder = 5
creditsCard.ZIndex = 12; creditsCard.Parent = ContentFrame
CreateCorner(creditsCard, 12); CreateStroke(creditsCard, Colors.Primary, 1, 0.5)

local creditsGrad = Instance.new("Frame"); creditsGrad.BackgroundColor3 = Colors.Primary
creditsGrad.BackgroundTransparency = 0.9; creditsGrad.Size = UDim2.new(1,0,1,0)
creditsGrad.BorderSizePixel = 0; creditsGrad.ZIndex = 12; creditsGrad.Parent = creditsCard
CreateCorner(creditsGrad, 12); CreateGradient(creditsGrad, Colors.Primary, Colors.Secondary, 45)

local creditsT = Instance.new("TextLabel"); creditsT.BackgroundTransparency = 1
creditsT.Size = UDim2.new(1,0,0,20); creditsT.Position = UDim2.new(0,0,0,IsMobile and 6 or 10)
creditsT.Font = Enum.Font.GothamBold; creditsT.TextSize = IsMobile and 12 or 14
creditsT.TextColor3 = Colors.Text; creditsT.Text = "★ SYN-STUDIO ★"
creditsT.ZIndex = 14; creditsT.Parent = creditsCard

local creditsSub = Instance.new("TextLabel"); creditsSub.BackgroundTransparency = 1
creditsSub.Size = UDim2.new(1,0,0,12); creditsSub.Position = UDim2.new(0,0,0,IsMobile and 26 or 32)
creditsSub.Font = Enum.Font.Gotham; creditsSub.TextSize = IsMobile and 8 or 10
creditsSub.TextColor3 = Colors.TextDim; creditsSub.Text = "Perfect Parry • Zero Miss • Made with ❤"
creditsSub.ZIndex = 14; creditsSub.Parent = creditsCard

-- ═══════════════════════════════════════════
-- MINIMIZE ↔ FLOAT ICON
-- ═══════════════════════════════════════════
local isMinimized = false

minBtn.MouseButton1Click:Connect(function()
    isMinimized = true
    Tween(MainFrame, {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    task.delay(0.35, function()
        MainFrame.Visible = false
        FloatIcon.Visible = true
        FloatIcon.Size = UDim2.new(0,0,0,0); FloatIcon.BackgroundTransparency = 0.5
        Tween(FloatIcon, {
            Size = UDim2.new(0, IsMobile and 50 or 48, 0, IsMobile and 50 or 48),
            BackgroundTransparency = 0
        }, 0.4, Enum.EasingStyle.Back)
    end)
end)

FloatIcon.MouseButton1Click:Connect(function()
    if floatDrag then return end
    isMinimized = false
    Tween(FloatIcon, {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 0.5}, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    task.delay(0.25, function()
        FloatIcon.Visible = false
        MainFrame.Visible = true
        local nw, nh = CalcWindowSize()
        MainFrame.Size = UDim2.new(0,0,0,0); MainFrame.BackgroundTransparency = 0.5
        Tween(MainFrame, {
            Size = UDim2.new(0,nw,0,nh),
            BackgroundTransparency = 0
        }, 0.4, Enum.EasingStyle.Back)
    end)
end)

-- Keybind toggle
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if isMinimized then
            FloatIcon.Visible = not FloatIcon.Visible
        else
            MainFrame.Visible = not MainFrame.Visible
        end
        Notify("SYN-STUDIO", MainFrame.Visible and "UI Shown" or "UI Hidden (RShift)", 1.5, "success")
    end
end)

-- ═══════════════════════════════════════════
-- BALL ESP
-- ═══════════════════════════════════════════
local espBillboard = nil

local function CreateBallESP(ball)
    if espBillboard then espBillboard:Destroy() end
    local bb = Instance.new("BillboardGui"); bb.Name = "SynESP"
    bb.Size = UDim2.new(0,110,0,44); bb.StudsOffset = Vector3.new(0,3,0)
    bb.AlwaysOnTop = true; bb.Adornee = ball; bb.Parent = ball

    local ef = Instance.new("Frame"); ef.Name = "Frame"
    ef.BackgroundColor3 = Colors.Background; ef.BackgroundTransparency = 0.2
    ef.Size = UDim2.new(1,0,1,0); ef.Parent = bb
    CreateCorner(ef, 8); CreateStroke(ef, Colors.Danger, 1.5, 0.3)

    local et = Instance.new("TextLabel"); et.Name = "DistText"; et.BackgroundTransparency = 1
    et.Size = UDim2.new(1,0,0.5,0); et.Font = Enum.Font.GothamBold; et.TextSize = 11
    et.TextColor3 = Colors.Danger; et.Text = "⚠ BALL"; et.Parent = ef

    local dt = Instance.new("TextLabel"); dt.Name = "Distance"; dt.BackgroundTransparency = 1
    dt.Size = UDim2.new(1,0,0.5,0); dt.Position = UDim2.new(0,0,0.5,0)
    dt.Font = Enum.Font.Gotham; dt.TextSize = 9; dt.TextColor3 = Colors.Text
    dt.Text = "0 studs"; dt.Parent = ef

    espBillboard = bb; return bb
end

-- ═══════════════════════════════════════════
-- PARRY EFFECT
-- ═══════════════════════════════════════════
local function ParryEffect()
    if not Config.VisualEffects then return end
    local char = LocalPlayer.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

    local flash = Instance.new("Frame"); flash.BackgroundColor3 = Colors.Primary
    flash.BackgroundTransparency = 0.7; flash.Size = UDim2.new(1,0,1,0); flash.ZIndex = 100
    flash.Parent = ScreenGui
    Tween(flash, {BackgroundTransparency = 1}, 0.4)
    task.delay(0.4, function() flash:Destroy() end)

    local p = Instance.new("Part"); p.Shape = Enum.PartType.Ball; p.Material = Enum.Material.Neon
    p.Color = Colors.Primary; p.Size = Vector3.new(1,1,1); p.Position = hrp.Position
    p.Anchored = true; p.CanCollide = false; p.Transparency = 0.3; p.Parent = Workspace
    Tween(p, {Size = Vector3.new(20,20,20), Transparency = 1}, 0.5)
    task.delay(0.5, function() p:Destroy() end)
end

-- ═══════════════════════════════════════════
-- CORE AUTO PARRY ENGINE
-- ═══════════════════════════════════════════
local lastParryTick = 0
local currentBallSpeed = 0
local parryDebounce = false

local function FindBall()
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:IsA("BasePart") then
            local n = o.Name:lower()
            if n == "ball" or n == "bladeball" or n == "blade_ball" then return o end
        end
    end
    local bf = Workspace:FindFirstChild("Balls") or Workspace:FindFirstChild("GameObjects")
    if bf then
        for _, c in ipairs(bf:GetChildren()) do
            if c:IsA("BasePart") then return c end
            if c:IsA("Model") then return c:FindFirstChildWhichIsA("BasePart") end
        end
    end
    return nil
end

local function IsTargeted()
    local char = LocalPlayer.Character; if not char then return false end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("Highlight") then
            local c = v.OutlineColor
            if c.R > 0.8 and c.G < 0.2 and c.B < 0.2 then return true end
        end
        if v:IsA("SelectionBox") or v:IsA("SelectionSphere") then
            local c = v.Color3
            if c.R > 0.8 and c.G < 0.2 and c.B < 0.2 then return true end
        end
    end
    return false
end

local function CalculateParryDistance(speed)
    local base = Config.ParryDistance
    local factor = math.clamp(speed / 100, 0.5, 3.0)
    local dist = base * factor * Config.SpeedMultiplier
    return math.clamp(dist, Config.MinParryDistance, Config.MaxParryDistance)
end

local function TriggerParry()
    if parryDebounce then return end
    parryDebounce = true

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local pe = remotes:FindFirstChild("Parry") or remotes:FindFirstChild("ParryBall") or remotes:FindFirstChild("AttemptParry") or remotes:FindFirstChild("Block")
        if pe then
            if pe:IsA("RemoteEvent") then pe:FireServer()
            elseif pe:IsA("RemoteFunction") then pcall(function() pe:InvokeServer() end) end
        end
    end

    for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
        local n = r.Name:lower()
        if n:find("parry") or n:find("block") or n:find("deflect") or n:find("hit") then
            if r:IsA("RemoteEvent") then pcall(function() r:FireServer() end)
            elseif r:IsA("RemoteFunction") then pcall(function() r:InvokeServer() end) end
        end
    end

    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendMouseButtonEvent(0,0,0,true,game,0)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(0,0,0,false,game,0)
    end)

    pcall(function()
        local char = LocalPlayer.Character
        if char then local tool = char:FindFirstChildWhichIsA("Tool"); if tool then tool:Activate() end end
    end)

    Config.ParrySuccessCount += 1
    Config.TotalParryAttempts += 1
    ParryEffect()

    if Config.SoundEffects then
        pcall(function()
            local s = Instance.new("Sound"); s.SoundId = "rbxassetid://12221984"
            s.Volume = 0.3; s.PlayOnRemove = true; s.Parent = Workspace; s:Destroy()
        end)
    end

    lastParryTick = tick()
    task.delay(0.15, function() parryDebounce = false end)
end

-- ═══════════════════════════════════════════
-- MAIN HEARTBEAT LOOP
-- ═══════════════════════════════════════════
local ballTracker = {lastPosition = nil, lastTime = nil, calculatedSpeed = 0}

RunService.Heartbeat:Connect(function()
    if not Config.AutoParry then return end
    local char = LocalPlayer.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum or hum.Health <= 0 then return end

    local ball = FindBall(); if not ball then return end

    local ballPos = ball.Position; local now = tick()
    if ballTracker.lastPosition and ballTracker.lastTime then
        local dt = now - ballTracker.lastTime
        if dt > 0 then ballTracker.calculatedSpeed = (ballPos - ballTracker.lastPosition).Magnitude / dt end
    end
    ballTracker.lastPosition = ballPos; ballTracker.lastTime = now

    local speed = ball.Velocity and ball.Velocity.Magnitude or 0
    if speed < 1 then speed = ballTracker.calculatedSpeed end
    currentBallSpeed = speed

    local distance = (ballPos - hrp.Position).Magnitude

    local dir = (hrp.Position - ballPos)
    local dirN = dir.Magnitude > 0.1 and dir.Unit or Vector3.zero
    local ballVel = ball.Velocity or Vector3.zero
    if ballVel.Magnitude < 0.1 and ballTracker.lastPosition then
        ballVel = (ballPos - ballTracker.lastPosition) * 60
    end
    local bvN = ballVel.Magnitude > 0.1 and ballVel.Unit or Vector3.zero
    local dot = dirN:Dot(bvN)

    local isApproaching = dot > 0.2 or (distance < 25 and speed > 5)
    local isTargeted = IsTargeted()

    -- ESP
    if Config.ShowBallESP then
        if not espBillboard or espBillboard.Parent ~= ball then CreateBallESP(ball) end
        if espBillboard then
            local frm = espBillboard:FindFirstChild("Frame")
            if frm then
                local d = frm:FindFirstChild("Distance")
                if d then d.Text = string.format("%.0f studs | %.0f spd", distance, speed) end
                local t = frm:FindFirstChild("DistText")
                if t then
                    if isApproaching and distance < 100 then t.Text = "⚠ INCOMING!"; t.TextColor3 = Colors.Danger
                    else t.Text = "● BALL"; t.TextColor3 = Colors.Primary end
                end
            end
        end
    end

    -- Update stats
    pcall(function()
        ballSpeedLabel.Text = string.format("%.0f", speed)
        if Config.TotalParryAttempts > 0 then
            successRateLabel.Text = string.format("%.0f%%", (Config.ParrySuccessCount / Config.TotalParryAttempts) * 100)
        end
        parryCountLabel.Text = tostring(Config.ParrySuccessCount)
    end)

    -- Decision
    if not isApproaching and not isTargeted then return end
    if tick() - lastParryTick < 0.15 then return end

    local optDist = CalculateParryDistance(speed)
    local ttr = speed > 0.1 and (distance / speed) or 999
    local shouldParry = false

    if Config.SmartTiming then
        if speed > 200 and distance < optDist * 1.5 and isApproaching then shouldParry = true
        elseif speed > 100 and distance < optDist * 1.2 and isApproaching then shouldParry = true
        elseif distance < optDist and isApproaching then shouldParry = true
        elseif distance < Config.MinParryDistance then shouldParry = true
        elseif isTargeted and distance < optDist * 1.3 then shouldParry = true end

        if Config.PredictionEnabled and ttr < 0.25 and ttr > 0.02 then shouldParry = true end
    else
        if distance < Config.ParryDistance and isApproaching then shouldParry = true end
    end

    if shouldParry then
        if speed > 150 then TriggerParry()
        else
            local d = math.clamp(ttr * 0.3, 0, 0.1)
            task.delay(d, function() TriggerParry() end)
        end
    end
end)

-- ═══════════════════════════════════════════
-- BACKUP TARGET DETECTION
-- ═══════════════════════════════════════════
task.spawn(function()
    while ScreenGui.Parent do
        pcall(function()
            local ball = FindBall(); if not ball then return end
            local t = ball:GetAttribute("Target") or ball:GetAttribute("target") or ball:GetAttribute("CurrentTarget")
            if t and (t == LocalPlayer.Name or t == LocalPlayer.UserId) then
                local char = LocalPlayer.Character; if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
                local d = (ball.Position - hrp.Position).Magnitude
                if d < Config.ParryDistance * 1.5 then TriggerParry() end
            end
            for _, ch in ipairs(ball:GetChildren()) do
                if ch:IsA("ObjectValue") and ch.Name:lower():find("target") then
                    if ch.Value == LocalPlayer.Character or ch.Value == LocalPlayer then
                        local hrpC = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrpC then
                            local dd = (ball.Position - hrpC.Position).Magnitude
                            if dd < Config.ParryDistance * 1.5 then TriggerParry() end
                        end
                    end
                end
            end
        end)
        task.wait(0.05)
    end
end)

-- ═══════════════════════════════════════════
-- REMOTE DETECTION
-- ═══════════════════════════════════════════
task.spawn(function()
    task.wait(2)
    local found = false
    for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
        local n = r.Name:lower()
        if n:find("parry") or n:find("deflect") or n:find("block") then found = true; break end
    end
    Notify(found and "Remote Found" or "Info",
           found and "Parry remote detected!" or "Using universal parry method",
           3, found and "success" or "warning")
end)

-- ═══════════════════════════════════════════
-- INTRO ANIMATION
-- ═══════════════════════════════════════════
MainFrame.BackgroundTransparency = 1
MainFrame.Size = UDim2.new(0,0,0,0)

task.delay(0.5, function()
    local nw, nh = CalcWindowSize()
    Tween(MainFrame, {Size = UDim2.new(0,nw,0,nh), BackgroundTransparency = 0}, 0.6, Enum.EasingStyle.Back)
    task.delay(0.8, function()
        Notify("SYN-STUDIO", "Auto Parry loaded! ⚔", 3, "success")
        task.delay(1, function()
            Notify("Keybind", "RightShift = Toggle UI", 3, "warning")
            task.delay(1, function()
                Notify("Mode", "Current: "..Config.Mode, 2, "success")
            end)
        end)
    end)
end)

print([[
╔══════════════════════════════════════════╗
║       SYN-STUDIO v2.1 Loaded!           ║
║    Blade Ball Auto Parry Active         ║
║                                          ║
║  Toggle: RightShift                      ║
║  Modes: Brutal | Normal | Santai        ║
║  Responsive: Mobile + Desktop           ║
║  Float Icon: Minimize to icon           ║
╚══════════════════════════════════════════╝
]])