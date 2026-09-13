--[[
    ╔═══════════════════════════════════════════╗
    ║           SYN-STUDIO v2.0                 ║
    ║     Blade Ball Auto Parry System          ║
    ║     Premium UI/UX with Anime Style        ║
    ╚═══════════════════════════════════════════╝
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = Player:GetMouse()

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONFIGURATION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local Config = {
    AutoParry = true,
    ParryDistance = 35,
    PredictionEnabled = true,
    SmartTiming = true,
    SpamParry = false,
    SpamDelay = 0.05,
    VisualEffects = true,
    ShowBallESP = true,
    ShowParryRange = false,
    ParryMode = "Smart", -- "Smart", "Distance", "Spam"
    MinParryDist = 5,
    MaxParryDist = 65,
    TimingOffset = 0.02,
    AutoRetry = true,
    
    -- UI Config
    AccentColor = Color3.fromRGB(138, 92, 246),
    AccentColor2 = Color3.fromRGB(236, 72, 153),
    BGColor = Color3.fromRGB(15, 15, 25),
    SidebarColor = Color3.fromRGB(12, 12, 20),
    CardColor = Color3.fromRGB(22, 22, 35),
    TextColor = Color3.fromRGB(240, 240, 255),
    SubTextColor = Color3.fromRGB(140, 140, 170),
    BorderColor = Color3.fromRGB(45, 45, 70),
    SuccessColor = Color3.fromRGB(34, 197, 94),
    DangerColor = Color3.fromRGB(239, 68, 68),
    WarningColor = Color3.fromRGB(250, 204, 21),
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STATE MANAGEMENT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local State = {
    GuiOpen = false,
    CurrentTab = "AutoParry",
    Connections = {},
    Tweens = {},
    ParryCount = 0,
    MissCount = 0,
    LastParryTime = 0,
    BallSpeed = 0,
    BallDistance = 999,
    IsTargeted = false,
    SidebarExpanded = true,
    Dragging = false,
    DragStart = nil,
    DragOffset = nil,
    Notifications = {},
    IsMobile = false,
}

-- Detect mobile
State.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- UTILITY FUNCTIONS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local Util = {}

function Util.Tween(instance, props, duration, style, direction)
    local info = TweenInfo.new(
        duration or 0.25,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(instance, info, props)
    tween:Play()
    return tween
end

function Util.Create(className, properties, children)
    local inst = Instance.new(className)
    if properties then
        for k, v in pairs(properties) do
            if k ~= "Parent" then
                pcall(function() inst[k] = v end)
            end
        end
        if properties.Parent then
            inst.Parent = properties.Parent
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    return inst
end

function Util.GetViewportSize()
    return Camera.ViewportSize
end

function Util.Lerp(a, b, t)
    return a + (b - a) * t
end

function Util.GetWindowSize()
    local vp = Util.GetViewportSize()
    local isMobile = State.IsMobile
    
    local widthScale = isMobile and 0.88 or 0.58
    local heightScale = isMobile and 0.7 or 0.7
    
    local w = math.clamp(vp.X * widthScale, 320, 750)
    local h = math.clamp(vp.Y * heightScale, 300, 550)
    
    return w, h
end

function Util.RippleEffect(button, x, y)
    local ripple = Util.Create("Frame", {
        Parent = button,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.7,
        Position = UDim2.new(0, x - button.AbsolutePosition.X, 0, y - button.AbsolutePosition.Y),
        Size = UDim2.new(0, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = button.ZIndex + 1,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ripple })
    
    local maxSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.5
    Util.Tween(ripple, {
        Size = UDim2.new(0, maxSize, 0, maxSize),
        BackgroundTransparency = 1,
    }, 0.5, Enum.EasingStyle.Quad)
    
    task.delay(0.5, function()
        ripple:Destroy()
    end)
end

function Util.CleanConnections()
    for _, conn in pairs(State.Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    State.Connections = {}
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BLADE BALL AUTO PARRY ENGINE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local ParryEngine = {}

function ParryEngine:GetBall()
    -- Search for the ball in common Blade Ball locations
    local ballsFolder = Workspace:FindFirstChild("Balls") 
        or Workspace:FindFirstChild("Ball")
        or Workspace:FindFirstChild("GameBalls")
    
    if ballsFolder then
        for _, obj in pairs(ballsFolder:GetChildren()) do
            if obj:IsA("BasePart") or obj:FindFirstChildWhichIsA("BasePart") then
                return obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            end
        end
    end
    
    -- Fallback: search workspace
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (
            obj.Name:lower():find("ball") or 
            obj.Name:lower():find("orb") or
            obj.Name:lower():find("sphere")
        ) then
            if obj.Shape == Enum.PartType.Ball or obj.Size.X < 10 then
                return obj
            end
        end
    end
    
    return nil
end

function ParryEngine:GetCharacter()
    return Player.Character or Player.CharacterAdded:Wait()
end

function ParryEngine:GetHumanoidRootPart()
    local char = self:GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

function ParryEngine:IsTargeted()
    local char = self:GetCharacter()
    if not char then return false end
    
    -- Check for red outline/highlight (targeted indicator)
    for _, obj in pairs(char:GetDescendants()) do
        if obj:IsA("Highlight") then
            if obj.OutlineColor == Color3.fromRGB(255, 0, 0) or
               obj.FillColor == Color3.fromRGB(255, 0, 0) or
               obj.OutlineColor.R > 0.8 and obj.OutlineColor.G < 0.3 then
                return true
            end
        end
        if obj:IsA("SelectionBox") or obj:IsA("BillboardGui") then
            if obj.Name:lower():find("target") or obj.Name:lower():find("indicator") then
                return true
            end
        end
    end
    
    -- Check ball direction
    local ball = self:GetBall()
    local hrp = self:GetHumanoidRootPart()
    if ball and hrp then
        local ballVelocity = ball.AssemblyLinearVelocity or ball.Velocity
        if ballVelocity and ballVelocity.Magnitude > 5 then
            local dirToBall = (hrp.Position - ball.Position).Unit
            local ballDir = ballVelocity.Unit
            local dot = dirToBall:Dot(ballDir)
            if dot > 0.6 then
                return true
            end
        end
    end
    
    return false
end

function ParryEngine:GetBallSpeed(ball)
    if not ball then return 0 end
    local vel = ball.AssemblyLinearVelocity or ball.Velocity
    if vel then
        return vel.Magnitude
    end
    return 0
end

function ParryEngine:GetDistanceToBall(ball)
    local hrp = self:GetHumanoidRootPart()
    if not hrp or not ball then return 999 end
    return (hrp.Position - ball.Position).Magnitude
end

function ParryEngine:PredictArrivalTime(ball)
    local hrp = self:GetHumanoidRootPart()
    if not hrp or not ball then return 999 end
    
    local distance = (hrp.Position - ball.Position).Magnitude
    local speed = self:GetBallSpeed(ball)
    
    if speed < 1 then return 999 end
    
    return distance / speed
end

function ParryEngine:CalculateOptimalParryDistance(ball)
    local speed = self:GetBallSpeed(ball)
    
    -- Dynamic parry distance based on ball speed
    -- Faster ball = larger parry window needed
    if speed > 300 then
        return math.clamp(Config.ParryDistance * 1.8, Config.MinParryDist, Config.MaxParryDist)
    elseif speed > 200 then
        return math.clamp(Config.ParryDistance * 1.5, Config.MinParryDist, Config.MaxParryDist)
    elseif speed > 100 then
        return math.clamp(Config.ParryDistance * 1.2, Config.MinParryDist, Config.MaxParryDist)
    else
        return Config.ParryDistance
    end
end

function ParryEngine:ExecuteParry()
    -- Method 1: Fire remote
    local parryRemote = ReplicatedStorage:FindFirstChild("Remotes") 
        and ReplicatedStorage.Remotes:FindFirstChild("Parry")
    
    if not parryRemote then
        -- Search for parry remote
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") and (
                obj.Name:lower():find("parry") or
                obj.Name:lower():find("block") or
                obj.Name:lower():find("deflect") or
                obj.Name:lower():find("hit")
            ) then
                parryRemote = obj
                break
            end
        end
    end
    
    if parryRemote then
        parryRemote:FireServer()
    end
    
    -- Method 2: Virtual input (click) as backup
    local tool = self:GetCharacter() and self:GetCharacter():FindFirstChildWhichIsA("Tool")
    if tool then
        if tool:FindFirstChild("Handle") then
            -- Simulate tool activation
            tool:Activate()
        end
    end
    
    -- Method 3: Virtual click
    local VIM = game:GetService("VirtualInputManager")
    if VIM then
        pcall(function()
            VIM:SendMouseButtonEvent(
                Camera.ViewportSize.X / 2,
                Camera.ViewportSize.Y / 2,
                0, true, game, 0
            )
            task.wait(0.01)
            VIM:SendMouseButtonEvent(
                Camera.ViewportSize.X / 2,
                Camera.ViewportSize.Y / 2,
                0, false, game, 0
            )
        end)
    end
    
    State.ParryCount = State.ParryCount + 1
    State.LastParryTime = tick()
end

function ParryEngine:SmartParryCheck()
    if not Config.AutoParry then return end
    
    local ball = self:GetBall()
    if not ball then return end
    
    local distance = self:GetDistanceToBall(ball)
    local speed = self:GetBallSpeed(ball)
    local isTargeted = self:IsTargeted()
    local arrivalTime = self:PredictArrivalTime(ball)
    
    State.BallSpeed = speed
    State.BallDistance = distance
    State.IsTargeted = isTargeted
    
    if not isTargeted and Config.ParryMode ~= "Spam" then return end
    
    local optimalDist = self:CalculateOptimalParryDistance(ball)
    
    if Config.ParryMode == "Smart" then
        -- Smart mode: use prediction
        if Config.PredictionEnabled then
            -- Calculate frames until arrival
            local framesUntilArrival = arrivalTime * 60 -- assuming 60fps
            
            -- Dynamic timing based on speed
            local parryWindow
            if speed > 300 then
                parryWindow = 8 -- more frames for fast balls
            elseif speed > 200 then
                parryWindow = 6
            elseif speed > 100 then
                parryWindow = 4
            else
                parryWindow = 3
            end
            
            if framesUntilArrival <= parryWindow and distance <= optimalDist then
                if tick() - State.LastParryTime > 0.1 then
                    self:ExecuteParry()
                    return true
                end
            end
        else
            if distance <= optimalDist and isTargeted then
                if tick() - State.LastParryTime > 0.1 then
                    self:ExecuteParry()
                    return true
                end
            end
        end
        
    elseif Config.ParryMode == "Distance" then
        if distance <= Config.ParryDistance and isTargeted then
            if tick() - State.LastParryTime > 0.15 then
                self:ExecuteParry()
                return true
            end
        end
        
    elseif Config.ParryMode == "Spam" then
        if distance <= optimalDist * 1.5 and isTargeted then
            if tick() - State.LastParryTime > Config.SpamDelay then
                self:ExecuteParry()
                return true
            end
        end
    end
    
    return false
end

function ParryEngine:Start()
    -- Main parry loop
    State.Connections.ParryLoop = RunService.Heartbeat:Connect(function()
        self:SmartParryCheck()
    end)
    
    -- Additional RenderStepped for faster response
    State.Connections.RenderParry = RunService.RenderStepped:Connect(function()
        if Config.SmartTiming then
            self:SmartParryCheck()
        end
    end)
end

function ParryEngine:Stop()
    if State.Connections.ParryLoop then
        State.Connections.ParryLoop:Disconnect()
    end
    if State.Connections.RenderParry then
        State.Connections.RenderParry:Disconnect()
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- UI LIBRARY - SYN STUDIO
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local Library = {}

-- Remove existing GUI
if game:GetService("CoreGui"):FindFirstChild("SynStudio") then
    game:GetService("CoreGui"):FindFirstChild("SynStudio"):Destroy()
end

local ScreenGui = Util.Create("ScreenGui", {
    Name = "SynStudio",
    Parent = game:GetService("CoreGui"),
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TOGGLE BUTTON (Always visible)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local ToggleBtn = Util.Create("TextButton", {
    Parent = ScreenGui,
    Size = UDim2.new(0, 48, 0, 48),
    Position = UDim2.new(0, 16, 0.5, -24),
    BackgroundColor3 = Config.AccentColor,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 100,
})
Util.Create("UICorner", { CornerRadius = UDim.new(0, 14), Parent = ToggleBtn })
Util.Create("UIStroke", { Color = Color3.fromRGB(80, 50, 160), Thickness = 1.5, Parent = ToggleBtn })

-- Anime-style icon (sword/katana symbol)
local ToggleIcon = Util.Create("TextLabel", {
    Parent = ToggleBtn,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "⚔",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 22,
    Font = Enum.Font.GothamBold,
    ZIndex = 101,
})

-- Glow effect behind button
local ToggleGlow = Util.Create("ImageLabel", {
    Parent = ToggleBtn,
    Size = UDim2.new(2, 0, 2, 0),
    Position = UDim2.new(-0.5, 0, -0.5, 0),
    BackgroundTransparency = 1,
    Image = "rbxassetid://5028857084",
    ImageColor3 = Config.AccentColor,
    ImageTransparency = 0.6,
    ZIndex = 99,
})

-- Pulse animation for toggle button
task.spawn(function()
    while ScreenGui.Parent do
        Util.Tween(ToggleGlow, { ImageTransparency = 0.4 }, 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(1)
        Util.Tween(ToggleGlow, { ImageTransparency = 0.75 }, 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(1)
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MAIN WINDOW
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local WindowW, WindowH = Util.GetWindowSize()

local Overlay = Util.Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 9,
})

local MainWindow = Util.Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, WindowW, 0, WindowH),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Config.BGColor,
    BackgroundTransparency = 0.05,
    Visible = false,
    ClipsDescendants = true,
    ZIndex = 10,
})
Util.Create("UICorner", { CornerRadius = UDim.new(0, 16), Parent = MainWindow })
Util.Create("UIStroke", { 
    Color = Config.BorderColor, 
    Thickness = 1, 
    Transparency = 0.3,
    Parent = MainWindow 
})

-- Shadow
local Shadow = Util.Create("ImageLabel", {
    Parent = MainWindow,
    Size = UDim2.new(1, 50, 1, 50),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Image = "rbxassetid://5028857084",
    ImageColor3 = Color3.fromRGB(0, 0, 0),
    ImageTransparency = 0.4,
    ZIndex = 9,
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HEADER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local Header = Util.Create("Frame", {
    Parent = MainWindow,
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = Config.SidebarColor,
    BackgroundTransparency = 0.3,
    ZIndex = 15,
})
Util.Create("UICorner", { CornerRadius = UDim.new(0, 16), Parent = Header })
-- Fix bottom corners of header
Util.Create("Frame", {
    Parent = Header,
    Size = UDim2.new(1, 0, 0, 16),
    Position = UDim2.new(0, 0, 1, -16),
    BackgroundColor3 = Config.SidebarColor,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    ZIndex = 15,
})

-- Header gradient accent line
local AccentLine = Util.Create("Frame", {
    Parent = Header,
    Size = UDim2.new(1, 0, 0, 2),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = Config.AccentColor,
    BorderSizePixel = 0,
    ZIndex = 16,
})
Util.Create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Config.AccentColor),
        ColorSequenceKeypoint.new(0.5, Config.AccentColor2),
        ColorSequenceKeypoint.new(1, Config.AccentColor),
    }),
    Parent = AccentLine,
})

-- Title
local TitleLabel = Util.Create("TextLabel", {
    Parent = Header,
    Size = UDim2.new(0.6, 0, 1, 0),
    Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    Text = "SYN-STUDIO",
    TextColor3 = Config.TextColor,
    TextSize = 18,
    Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 17,
})

-- Subtitle
local SubLabel = Util.Create("TextLabel", {
    Parent = Header,
    Size = UDim2.new(0.4, 0, 0, 14),
    Position = UDim2.new(0, 120, 0.5, 3),
    BackgroundTransparency = 1,
    Text = "Blade Ball",
    TextColor3 = Config.SubTextColor,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 17,
})

-- Status indicator
local StatusDot = Util.Create("Frame", {
    Parent = Header,
    Size = UDim2.new(0, 8, 0, 8),
    Position = UDim2.new(1, -70, 0.5, -4),
    BackgroundColor3 = Config.SuccessColor,
    ZIndex = 17,
})
Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = StatusDot })

local StatusLabel = Util.Create("TextLabel", {
    Parent = Header,
    Size = UDim2.new(0, 40, 0, 14),
    Position = UDim2.new(1, -58, 0.5, -7),
    BackgroundTransparency = 1,
    Text = "ON",
    TextColor3 = Config.SuccessColor,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 17,
})

-- Close button
local CloseBtn = Util.Create("TextButton", {
    Parent = Header,
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -38, 0.5, -15),
    BackgroundColor3 = Color3.fromRGB(60, 30, 30),
    BackgroundTransparency = 0.5,
    Text = "✕",
    TextColor3 = Config.DangerColor,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    ZIndex = 18,
})
Util.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = CloseBtn })

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SIDEBAR
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local sidebarWidth = State.IsMobile and 55 or 65

local Sidebar = Util.Create("Frame", {
    Parent = MainWindow,
    Size = UDim2.new(0, sidebarWidth, 1, -52),
    Position = UDim2.new(0, 0, 0, 51),
    BackgroundColor3 = Config.SidebarColor,
    BackgroundTransparency = 0.2,
    ClipsDescendants = true,
    ZIndex = 14,
})
Util.Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = Sidebar })

-- Sidebar right border
Util.Create("Frame", {
    Parent = Sidebar,
    Size = UDim2.new(0, 1, 1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = Config.BorderColor,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    ZIndex = 15,
})

local TabButtons = {}
local TabPages = {}

local Tabs = {
    { Name = "AutoParry", Icon = "⚔", Label = "Parry" },
    { Name = "Settings", Icon = "⚙", Label = "Settings" },
    { Name = "Visual", Icon = "◉", Label = "Visual" },
    { Name = "Stats", Icon = "📊", Label = "Stats" },
    { Name = "Info", Icon = "ℹ", Label = "Info" },
}

-- Active tab indicator
local TabIndicator = Util.Create("Frame", {
    Parent = Sidebar,
    Size = UDim2.new(0, 3, 0, 30),
    Position = UDim2.new(0, 0, 0, 15),
    BackgroundColor3 = Config.AccentColor,
    ZIndex = 16,
})
Util.Create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = TabIndicator })

for i, tabInfo in ipairs(Tabs) do
    local tabY = (i - 1) * 52 + 10
    
    local tabBtn = Util.Create("TextButton", {
        Parent = Sidebar,
        Size = UDim2.new(1, -8, 0, 44),
        Position = UDim2.new(0, 4, 0, tabY),
        BackgroundColor3 = Config.AccentColor,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 15,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = tabBtn })
    
    -- Icon
    local icon = Util.Create("TextLabel", {
        Parent = tabBtn,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = tabInfo.Icon,
        TextColor3 = i == 1 and Config.AccentColor or Config.SubTextColor,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        ZIndex = 16,
    })
    
    TabButtons[tabInfo.Name] = { Button = tabBtn, Icon = icon, Index = i, YPos = tabY }
    
    -- Hover / Press
    tabBtn.MouseEnter:Connect(function()
        if State.CurrentTab ~= tabInfo.Name then
            Util.Tween(tabBtn, { BackgroundTransparency = 0.85 }, 0.2)
        end
    end)
    tabBtn.MouseLeave:Connect(function()
        if State.CurrentTab ~= tabInfo.Name then
            Util.Tween(tabBtn, { BackgroundTransparency = 1 }, 0.2)
        end
    end)
    
    tabBtn.MouseButton1Click:Connect(function()
        Library:SwitchTab(tabInfo.Name)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONTENT AREA
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local ContentArea = Util.Create("Frame", {
    Parent = MainWindow,
    Size = UDim2.new(1, -(sidebarWidth + 8), 1, -58),
    Position = UDim2.new(0, sidebarWidth + 4, 0, 54),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    ZIndex = 12,
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- UI COMPONENT BUILDERS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local Components = {}

function Components:CreatePage(name)
    local page = Util.Create("ScrollingFrame", {
        Parent = ContentArea,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Config.AccentColor,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = name == "AutoParry",
        BorderSizePixel = 0,
        ZIndex = 12,
    })
    Util.Create("UIListLayout", {
        Parent = page,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    })
    Util.Create("UIPadding", {
        Parent = page,
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 12),
    })
    
    TabPages[name] = page
    return page
end

function Components:CreateSection(parent, title, layoutOrder)
    local section = Util.Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Config.CardColor,
        BackgroundTransparency = 0.2,
        LayoutOrder = layoutOrder or 0,
        ZIndex = 13,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = section })
    Util.Create("UIStroke", { Color = Config.BorderColor, Thickness = 1, Transparency = 0.6, Parent = section })
    Util.Create("UIPadding", {
        Parent = section,
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
    })
    Util.Create("UIListLayout", {
        Parent = section,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    })
    
    -- Section title
    if title then
        local titleFrame = Util.Create("Frame", {
            Parent = section,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            LayoutOrder = -1,
            ZIndex = 13,
        })
        Util.Create("TextLabel", {
            Parent = titleFrame,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = title:upper(),
            TextColor3 = Config.AccentColor,
            TextSize = 11,
            Font = Enum.Font.GothamBlack,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 14,
        })
        -- Underline
        Util.Create("Frame", {
            Parent = titleFrame,
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, 2),
            BackgroundColor3 = Config.BorderColor,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 14,
        })
    end
    
    return section
end

function Components:CreateToggle(parent, text, default, callback, layoutOrder)
    local toggled = default or false
    
    local toggleFrame = Util.Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        LayoutOrder = layoutOrder or 0,
        ZIndex = 13,
    })
    
    local label = Util.Create("TextLabel", {
        Parent = toggleFrame,
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Config.TextColor,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })
    
    -- Toggle track
    local track = Util.Create("TextButton", {
        Parent = toggleFrame,
        Size = UDim2.new(0, 44, 0, 24),
        Position = UDim2.new(1, -44, 0.5, -12),
        BackgroundColor3 = toggled and Config.AccentColor or Color3.fromRGB(50, 50, 65),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 15,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    
    -- Toggle knob
    local knob = Util.Create("Frame", {
        Parent = track,
        Size = UDim2.new(0, 18, 0, 18),
        Position = toggled and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 16,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
    
    -- Knob glow
    local knobGlow = Util.Create("Frame", {
        Parent = knob,
        Size = UDim2.new(1, 6, 1, 6),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Config.AccentColor,
        BackgroundTransparency = toggled and 0.6 or 1,
        ZIndex = 15,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knobGlow })
    
    local function updateToggle()
        if toggled then
            Util.Tween(knob, { Position = UDim2.new(1, -21, 0.5, -9) }, 0.25)
            Util.Tween(track, { BackgroundColor3 = Config.AccentColor }, 0.25)
            Util.Tween(knobGlow, { BackgroundTransparency = 0.6 }, 0.25)
        else
            Util.Tween(knob, { Position = UDim2.new(0, 3, 0.5, -9) }, 0.25)
            Util.Tween(track, { BackgroundColor3 = Color3.fromRGB(50, 50, 65) }, 0.25)
            Util.Tween(knobGlow, { BackgroundTransparency = 1 }, 0.25)
        end
        if callback then callback(toggled) end
    end
    
    track.MouseButton1Click:Connect(function()
        toggled = not toggled
        updateToggle()
    end)
    
    return {
        SetValue = function(_, val)
            toggled = val
            updateToggle()
        end,
        GetValue = function() return toggled end,
    }
end

function Components:CreateSlider(parent, text, min, max, default, callback, layoutOrder)
    local value = default or min
    
    local sliderFrame = Util.Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        LayoutOrder = layoutOrder or 0,
        ZIndex = 13,
    })
    
    -- Label row
    local labelRow = Util.Create("Frame", {
        Parent = sliderFrame,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        ZIndex = 13,
    })
    
    Util.Create("TextLabel", {
        Parent = labelRow,
        Size = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Config.TextColor,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    })
    
    local valueLabel = Util.Create("TextLabel", {
        Parent = labelRow,
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0.7, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(math.floor(value)),
        TextColor3 = Config.AccentColor,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 14,
    })
    
    -- Slider track
    local sliderTrack = Util.Create("TextButton", {
        Parent = sliderFrame,
        Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(40, 40, 55),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 14,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sliderTrack })
    
    -- Fill
    local fill = Util.Create("Frame", {
        Parent = sliderTrack,
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Config.AccentColor,
        BorderSizePixel = 0,
        ZIndex = 15,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
    Util.Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Config.AccentColor),
            ColorSequenceKeypoint.new(1, Config.AccentColor2),
        }),
        Parent = fill,
    })
    
    -- Slider knob
    local sliderKnob = Util.Create("Frame", {
        Parent = sliderTrack,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new((value - min) / (max - min), -8, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 16,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sliderKnob })
    Util.Create("UIStroke", { Color = Config.AccentColor, Thickness = 2, Parent = sliderKnob })
    
    local dragging = false
    
    local function updateSlider(input)
        local trackPos = sliderTrack.AbsolutePosition.X
        local trackSize = sliderTrack.AbsoluteSize.X
        local mouseX = input.Position.X
        
        local pct = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
        value = math.floor(min + (max - min) * pct)
        
        Util.Tween(fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.08)
        Util.Tween(sliderKnob, { Position = UDim2.new(pct, -8, 0.5, -8) }, 0.08)
        valueLabel.Text = tostring(value)
        
        if callback then callback(value) end
    end
    
    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            Util.Tween(sliderKnob, { Size = UDim2.new(0, 20, 0, 20) }, 0.15)
            updateSlider(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            Util.Tween(sliderKnob, { Size = UDim2.new(0, 16, 0, 16) }, 0.15)
        end
    end)
    
    return {
        SetValue = function(_, val)
            value = math.clamp(val, min, max)
            local pct = (value - min) / (max - min)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            sliderKnob.Position = UDim2.new(pct, -8, 0.5, -8)
            valueLabel.Text = tostring(math.floor(value))
            if callback then callback(value) end
        end,
        GetValue = function() return value end,
    }
end

function Components:CreateDropdown(parent, text, options, default, callback, layoutOrder)
    local selected = default or options[1]
    local isOpen = false
    
    local dropFrame = Util.Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        LayoutOrder = layoutOrder or 0,
        ClipsDescendants = false,
        ZIndex = 20,
    })
    
    local label = Util.Create("TextLabel", {
        Parent = dropFrame,
        Size = UDim2.new(0.45, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Config.TextColor,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 21,
    })
    
    local dropBtn = Util.Create("TextButton", {
        Parent = dropFrame,
        Size = UDim2.new(0.52, 0, 0, 32),
        Position = UDim2.new(0.48, 0, 0, 2),
        BackgroundColor3 = Color3.fromRGB(35, 35, 50),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 21,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = dropBtn })
    Util.Create("UIStroke", { Color = Config.BorderColor, Thickness = 1, Transparency = 0.5, Parent = dropBtn })
    
    local selectedLabel = Util.Create("TextLabel", {
        Parent = dropBtn,
        Size = UDim2.new(1, -28, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = selected,
        TextColor3 = Config.TextColor,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 22,
    })
    
    local arrow = Util.Create("TextLabel", {
        Parent = dropBtn,
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -24, 0, 0),
        BackgroundTransparency = 1,
        Text = "▼",
        TextColor3 = Config.SubTextColor,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        ZIndex = 22,
    })
    
    -- Dropdown list
    local dropList = Util.Create("Frame", {
        Parent = dropBtn,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 4),
        BackgroundColor3 = Color3.fromRGB(30, 30, 45),
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 50,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = dropList })
    Util.Create("UIStroke", { Color = Config.BorderColor, Thickness = 1, Parent = dropList })
    Util.Create("UIListLayout", {
        Parent = dropList,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })
    Util.Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = dropList })
    
    for idx, option in ipairs(options) do
        local optBtn = Util.Create("TextButton", {
            Parent = dropList,
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = Config.AccentColor,
            BackgroundTransparency = option == selected and 0.7 or 1,
            Text = option,
            TextColor3 = option == selected and Config.AccentColor or Config.TextColor,
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            AutoButtonColor = false,
            LayoutOrder = idx,
            ZIndex = 51,
        })
        Util.Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = optBtn })
        
        optBtn.MouseEnter:Connect(function()
            Util.Tween(optBtn, { BackgroundTransparency = 0.75 }, 0.15)
        end)
        optBtn.MouseLeave:Connect(function()
            if optBtn.Text ~= selected then
                Util.Tween(optBtn, { BackgroundTransparency = 1 }, 0.15)
            end
        end)
        
        optBtn.MouseButton1Click:Connect(function()
            selected = option
            selectedLabel.Text = option
            
            -- Update all option visuals
            for _, child in pairs(dropList:GetChildren()) do
                if child:IsA("TextButton") then
                    local isSel = child.Text == selected
                    Util.Tween(child, { 
                        BackgroundTransparency = isSel and 0.7 or 1,
                        TextColor3 = isSel and Config.AccentColor or Config.TextColor
                    }, 0.2)
                end
            end
            
            -- Close dropdown
            isOpen = false
            Util.Tween(dropList, { Size = UDim2.new(1, 0, 0, 0) }, 0.2)
            Util.Tween(arrow, { Rotation = 0 }, 0.2)
            task.delay(0.2, function()
                dropList.Visible = false
            end)
            
            if callback then callback(option) end
        end)
    end
    
    local totalHeight = #options * 30 + 8
    
    dropBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            dropList.Visible = true
            Util.Tween(dropList, { Size = UDim2.new(1, 0, 0, totalHeight) }, 0.25, Enum.EasingStyle.Back)
            Util.Tween(arrow, { Rotation = 180 }, 0.25)
        else
            Util.Tween(dropList, { Size = UDim2.new(1, 0, 0, 0) }, 0.2)
            Util.Tween(arrow, { Rotation = 0 }, 0.2)
            task.delay(0.2, function()
                dropList.Visible = false
            end)
        end
    end)
    
    return {
        SetValue = function(_, val)
            selected = val
            selectedLabel.Text = val
            if callback then callback(val) end
        end,
        GetValue = function() return selected end,
    }
end

function Components:CreateButton(parent, text, callback, layoutOrder)
    local btn = Util.Create("TextButton", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Config.AccentColor,
        BackgroundTransparency = 0.3,
        Text = text,
        TextColor3 = Config.TextColor,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        LayoutOrder = layoutOrder or 0,
        ZIndex = 14,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = btn })
    
    btn.MouseEnter:Connect(function()
        Util.Tween(btn, { BackgroundTransparency = 0.15 }, 0.2)
    end)
    btn.MouseLeave:Connect(function()
        Util.Tween(btn, { BackgroundTransparency = 0.3 }, 0.2)
    end)
    btn.MouseButton1Down:Connect(function()
        Util.Tween(btn, { Size = UDim2.new(1, -4, 0, 34) }, 0.1)
    end)
    btn.MouseButton1Up:Connect(function()
        Util.Tween(btn, { Size = UDim2.new(1, 0, 0, 36) }, 0.15)
    end)
    
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    
    return btn
end

function Components:CreateInfoLabel(parent, label, getValue, layoutOrder)
    local frame = Util.Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = layoutOrder or 0,
        ZIndex = 13,
    })
    
    Util.Create("TextLabel", {
        Parent = frame,
        Size = UDim2.new(0.55, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Config.SubTextColor,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    })
    
    local valueText = Util.Create("TextLabel", {
        Parent = frame,
        Size = UDim2.new(0.45, 0, 1, 0),
        Position = UDim2.new(0.55, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = getValue and tostring(getValue()) or "--",
        TextColor3 = Config.TextColor,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 14,
    })
    
    return valueText
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BUILD PAGES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- === AUTO PARRY PAGE ===
local parryPage = Components:CreatePage("AutoParry")

local mainSection = Components:CreateSection(parryPage, "⚔ Main Controls", 1)

Components:CreateToggle(mainSection, "Auto Parry", Config.AutoParry, function(val)
    Config.AutoParry = val
    StatusLabel.Text = val and "ON" or "OFF"
    StatusDot.BackgroundColor3 = val and Config.SuccessColor or Config.DangerColor
    StatusLabel.TextColor3 = val and Config.SuccessColor or Config.DangerColor
    
    if val then
        ParryEngine:Start()
        Library:Notify("Auto Parry", "Enabled - You're protected!", Config.SuccessColor)
    else
        ParryEngine:Stop()
        Library:Notify("Auto Parry", "Disabled", Config.DangerColor)
    end
end, 1)

Components:CreateToggle(mainSection, "Smart Timing", Config.SmartTiming, function(val)
    Config.SmartTiming = val
end, 2)

Components:CreateToggle(mainSection, "Prediction Mode", Config.PredictionEnabled, function(val)
    Config.PredictionEnabled = val
end, 3)

local parrySection = Components:CreateSection(parryPage, "⚙ Parry Settings", 2)

Components:CreateDropdown(parrySection, "Parry Mode", {"Smart", "Distance", "Spam"}, Config.ParryMode, function(val)
    Config.ParryMode = val
    Library:Notify("Mode Changed", "Parry mode: " .. val, Config.AccentColor)
end, 1)

Components:CreateSlider(parrySection, "Parry Distance", 5, 65, Config.ParryDistance, function(val)
    Config.ParryDistance = val
end, 2)

Components:CreateSlider(parrySection, "Timing Offset (ms)", 0, 100, Config.TimingOffset * 1000, function(val)
    Config.TimingOffset = val / 1000
end, 3)

-- Live status section
local statusSection = Components:CreateSection(parryPage, "📡 Live Status", 3)

local ballDistLabel = Components:CreateInfoLabel(statusSection, "Ball Distance", function() return "---" end, 1)
local ballSpeedLabel = Components:CreateInfoLabel(statusSection, "Ball Speed", function() return "---" end, 2)
local targetedLabel = Components:CreateInfoLabel(statusSection, "Targeted", function() return "No" end, 3)
local parryCountLabel = Components:CreateInfoLabel(statusSection, "Parries", function() return "0" end, 4)

-- === SETTINGS PAGE ===
local settingsPage = Components:CreatePage("Settings")

local gameSection = Components:CreateSection(settingsPage, "🎮 Game Settings", 1)

Components:CreateToggle(gameSection, "Auto Retry on Death", Config.AutoRetry, function(val)
    Config.AutoRetry = val
end, 1)

Components:CreateToggle(gameSection, "Spam Parry Fallback", Config.SpamParry, function(val)
    Config.SpamParry = val
end, 2)

Components:CreateSlider(gameSection, "Spam Delay (ms)", 10, 200, Config.SpamDelay * 1000, function(val)
    Config.SpamDelay = val / 1000
end, 3)

local uiSection = Components:CreateSection(settingsPage, "🎨 UI Settings", 2)

Components:CreateSlider(uiSection, "UI Transparency", 0, 50, 5, function(val)
    MainWindow.BackgroundTransparency = val / 100
end, 1)

Components:CreateButton(uiSection, "Reset Stats", function()
    State.ParryCount = 0
    State.MissCount = 0
    Library:Notify("Stats Reset", "All stats cleared!", Config.WarningColor)
end, 2)

Components:CreateButton(uiSection, "Destroy GUI", function()
    Library:Close(function()
        Util.CleanConnections()
        ParryEngine:Stop()
        ScreenGui:Destroy()
    end)
end, 3)

-- === VISUAL PAGE ===
local visualPage = Components:CreatePage("Visual")

local espSection = Components:CreateSection(visualPage, "👁 ESP Options", 1)

Components:CreateToggle(espSection, "Ball ESP", Config.ShowBallESP, function(val)
    Config.ShowBallESP = val
end, 1)

Components:CreateToggle(espSection, "Parry Range Circle", Config.ShowParryRange, function(val)
    Config.ShowParryRange = val
end, 2)

Components:CreateToggle(espSection, "Visual Effects", Config.VisualEffects, function(val)
    Config.VisualEffects = val
end, 3)

-- === STATS PAGE ===
local statsPage = Components:CreatePage("Stats")

local statsSection = Components:CreateSection(statsPage, "📊 Session Statistics", 1)

local sParryLabel = Components:CreateInfoLabel(statsSection, "Total Parries", function() return State.ParryCount end, 1)
local sMissLabel = Components:CreateInfoLabel(statsSection, "Total Misses", function() return State.MissCount end, 2)
local sRateLabel = Components:CreateInfoLabel(statsSection, "Success Rate", function() 
    if State.ParryCount + State.MissCount == 0 then return "N/A" end
    return math.floor(State.ParryCount / (State.ParryCount + State.MissCount) * 100) .. "%" 
end, 3)
local sUptimeLabel = Components:CreateInfoLabel(statsSection, "Uptime", function() return "0m" end, 4)

local startTime = tick()

-- === INFO PAGE ===
local infoPage = Components:CreatePage("Info")

local aboutSection = Components:CreateSection(infoPage, "ℹ About", 1)

Components:CreateInfoLabel(aboutSection, "Script", function() return "SYN-STUDIO" end, 1)
Components:CreateInfoLabel(aboutSection, "Version", function() return "2.0.0" end, 2)
Components:CreateInfoLabel(aboutSection, "Game", function() return "Blade Ball" end, 3)
Components:CreateInfoLabel(aboutSection, "Engine", function() return "Smart Parry" end, 4)

local hotkeySection = Components:CreateSection(infoPage, "⌨ Hotkeys", 2)

Components:CreateInfoLabel(hotkeySection, "Toggle GUI", function() return "Right Shift" end, 1)
Components:CreateInfoLabel(hotkeySection, "Toggle Parry", function() return "P" end, 2)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TAB SWITCHING
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Library:SwitchTab(tabName)
    if State.CurrentTab == tabName then return end
    
    local oldTab = State.CurrentTab
    State.CurrentTab = tabName
    
    -- Update tab button visuals
    for name, data in pairs(TabButtons) do
        local isSelected = name == tabName
        Util.Tween(data.Icon, { 
            TextColor3 = isSelected and Config.AccentColor or Config.SubTextColor 
        }, 0.25)
        Util.Tween(data.Button, { 
            BackgroundTransparency = isSelected and 0.8 or 1 
        }, 0.25)
    end
    
    -- Move indicator
    local newData = TabButtons[tabName]
    if newData then
        Util.Tween(TabIndicator, { 
            Position = UDim2.new(0, 0, 0, newData.YPos + 7) 
        }, 0.3, Enum.EasingStyle.Back)
    end
    
    -- Animate pages
    local oldPage = TabPages[oldTab]
    local newPage = TabPages[tabName]
    
    if oldPage then
        -- Fade out old page
        for _, child in pairs(oldPage:GetChildren()) do
            if child:IsA("Frame") then
                Util.Tween(child, { BackgroundTransparency = 1 }, 0.12)
            end
        end
        Util.Tween(oldPage, { Position = UDim2.new(-0.03, 0, 0, 0) }, 0.15)
        task.delay(0.15, function()
            if oldPage then oldPage.Visible = false end
            oldPage.Position = UDim2.new(0, 0, 0, 0)
        end)
    end
    
    if newPage then
        task.delay(0.1, function()
            newPage.Position = UDim2.new(0.03, 0, 0, 0)
            newPage.Visible = true
            Util.Tween(newPage, { Position = UDim2.new(0, 0, 0, 0) }, 0.2, Enum.EasingStyle.Back)
            
            for _, child in pairs(newPage:GetChildren()) do
                if child:IsA("Frame") then
                    child.BackgroundTransparency = 1
                    Util.Tween(child, { BackgroundTransparency = 0.2 }, 0.3)
                end
            end
        end)
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NOTIFICATION SYSTEM
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local NotifContainer = Util.Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, 260, 1, 0),
    Position = UDim2.new(1, -270, 0, 0),
    BackgroundTransparency = 1,
    ZIndex = 200,
})
Util.Create("UIListLayout", {
    Parent = NotifContainer,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 8),
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
})
Util.Create("UIPadding", { PaddingBottom = UDim.new(0, 20), PaddingRight = UDim.new(0, 10), Parent = NotifContainer })

function Library:Notify(title, message, color, duration)
    color = color or Config.AccentColor
    duration = duration or 3
    
    local notif = Util.Create("Frame", {
        Parent = NotifContainer,
        Size = UDim2.new(1, 0, 0, 65),
        BackgroundColor3 = Color3.fromRGB(20, 20, 32),
        BackgroundTransparency = 0.1,
        ClipsDescendants = true,
        ZIndex = 201,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = notif })
    Util.Create("UIStroke", { Color = color, Thickness = 1, Transparency = 0.5, Parent = notif })
    
    -- Accent left bar
    Util.Create("Frame", {
        Parent = notif,
        Size = UDim2.new(0, 3, 1, -8),
        Position = UDim2.new(0, 6, 0, 4),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        ZIndex = 202,
    })
    
    Util.Create("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.new(0, 16, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = color,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202,
    })
    
    Util.Create("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -24, 0, 18),
        Position = UDim2.new(0, 16, 0, 28),
        BackgroundTransparency = 1,
        Text = message,
        TextColor3 = Config.SubTextColor,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 202,
    })
    
    -- Progress bar
    local progress = Util.Create("Frame", {
        Parent = notif,
        Size = UDim2.new(1, -16, 0, 3),
        Position = UDim2.new(0, 8, 1, -8),
        BackgroundColor3 = Color3.fromRGB(40, 40, 55),
        BorderSizePixel = 0,
        ZIndex = 202,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = progress })
    
    local progressFill = Util.Create("Frame", {
        Parent = progress,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        ZIndex = 203,
    })
    Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = progressFill })
    
    -- Slide in
    notif.Position = UDim2.new(1, 0, 0, 0)
    Util.Tween(notif, { Position = UDim2.new(0, 0, 0, 0) }, 0.35, Enum.EasingStyle.Back)
    
    -- Progress countdown
    Util.Tween(progressFill, { Size = UDim2.new(0, 0, 1, 0) }, duration, Enum.EasingStyle.Linear)
    
    -- Slide out and destroy
    task.delay(duration, function()
        Util.Tween(notif, { 
            Position = UDim2.new(1, 0, 0, 0), 
            BackgroundTransparency = 1 
        }, 0.3)
        task.delay(0.3, function()
            notif:Destroy()
        end)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DRAG SYSTEM
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

do
    local dragging, dragStart, startPos

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainWindow.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local vp = Util.GetViewportSize()
            local winSize = MainWindow.AbsoluteSize
            
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y
            
            -- Clamp to viewport
            local halfW = winSize.X * MainWindow.AnchorPoint.X
            local halfH = winSize.Y * MainWindow.AnchorPoint.Y
            
            newX = math.clamp(newX, -vp.X/2 + halfW + 10, vp.X/2 - (winSize.X - halfW) - 10)
            newY = math.clamp(newY, -vp.Y/2 + halfH + 10, vp.Y/2 - (winSize.Y - halfH) - 10)
            
            MainWindow.Position = UDim2.new(0.5, newX, 0.5, newY)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- OPEN / CLOSE ANIMATIONS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Library:Open()
    if State.GuiOpen then return end
    State.GuiOpen = true
    
    -- Prepare
    MainWindow.Visible = true
    Overlay.Visible = true
    MainWindow.Size = UDim2.new(0, WindowW * 0.9, 0, WindowH * 0.9)
    MainWindow.BackgroundTransparency = 0.5
    
    -- Animate
    Util.Tween(Overlay, { BackgroundTransparency = 0.7 }, 0.3)
    Util.Tween(MainWindow, { 
        Size = UDim2.new(0, WindowW, 0, WindowH),
        BackgroundTransparency = 0.05
    }, 0.35, Enum.EasingStyle.Back)
    
    -- Staggered content appearance
    task.delay(0.15, function()
        -- Sidebar slide
        Sidebar.Position = UDim2.new(-0.2, 0, 0, 51)
        Util.Tween(Sidebar, { Position = UDim2.new(0, 0, 0, 51) }, 0.3, Enum.EasingStyle.Back)
    end)
    
    task.delay(0.2, function()
        -- Content fade
        ContentArea.Position = UDim2.new(0, sidebarWidth + 14, 0, 54)
        Util.Tween(ContentArea, { Position = UDim2.new(0, sidebarWidth + 4, 0, 54) }, 0.25)
    end)
    
    Util.Tween(ToggleBtn, { BackgroundTransparency = 0.5 }, 0.2)
end

function Library:Close(afterCallback)
    if not State.GuiOpen then return end
    State.GuiOpen = false
    
    -- Animate out
    Util.Tween(MainWindow, { 
        Size = UDim2.new(0, WindowW * 0.92, 0, WindowH * 0.92),
        BackgroundTransparency = 0.6
    }, 0.25)
    Util.Tween(Overlay, { BackgroundTransparency = 1 }, 0.25)
    
    Util.Tween(Sidebar, { Position = UDim2.new(-0.15, 0, 0, 51) }, 0.2)
    
    task.delay(0.25, function()
        MainWindow.Visible = false
        Overlay.Visible = false
        Util.Tween(ToggleBtn, { BackgroundTransparency = 0 }, 0.2)
        
        if afterCallback then afterCallback() end
    end)
end

function Library:Toggle()
    if State.GuiOpen then
        Library:Close()
    else
        Library:Open()
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENT CONNECTIONS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ToggleBtn.MouseButton1Click:Connect(function()
    Util.Tween(ToggleBtn, { Size = UDim2.new(0, 42, 0, 42) }, 0.1)
    task.delay(0.1, function()
        Util.Tween(ToggleBtn, { Size = UDim2.new(0, 48, 0, 48) }, 0.15, Enum.EasingStyle.Back)
    end)
    Library:Toggle()
end)

CloseBtn.MouseButton1Click:Connect(function()
    Library:Close()
end)

CloseBtn.MouseEnter:Connect(function()
    Util.Tween(CloseBtn, { BackgroundTransparency = 0.2, BackgroundColor3 = Config.DangerColor }, 0.2)
end)
CloseBtn.MouseLeave:Connect(function()
    Util.Tween(CloseBtn, { BackgroundTransparency = 0.5, BackgroundColor3 = Color3.fromRGB(60, 30, 30) }, 0.2)
end)

-- Keyboard shortcuts
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    if input.KeyCode == Enum.KeyCode.RightShift then
        Library:Toggle()
    elseif input.KeyCode == Enum.KeyCode.P then
        Config.AutoParry = not Config.AutoParry
        if Config.AutoParry then
            ParryEngine:Start()
        else
            ParryEngine:Stop()
        end
        StatusLabel.Text = Config.AutoParry and "ON" or "OFF"
        StatusDot.BackgroundColor3 = Config.AutoParry and Config.SuccessColor or Config.DangerColor
        StatusLabel.TextColor3 = Config.AutoParry and Config.SuccessColor or Config.DangerColor
        Library:Notify("Auto Parry", Config.AutoParry and "Enabled" or "Disabled", Config.AutoParry and Config.SuccessColor or Config.DangerColor)
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LIVE STATS UPDATE LOOP
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.1)
        
        -- Update live stats
        local ball = ParryEngine:GetBall()
        if ball then
            local dist = ParryEngine:GetDistanceToBall(ball)
            local speed = ParryEngine:GetBallSpeed(ball)
            local targeted = ParryEngine:IsTargeted()
            
            ballDistLabel.Text = string.format("%.1f studs", dist)
            ballSpeedLabel.Text = string.format("%.0f", speed)
            targetedLabel.Text = targeted and "⚠ YES" or "No"
            targetedLabel.TextColor3 = targeted and Config.DangerColor or Config.SuccessColor
        else
            ballDistLabel.Text = "No ball"
            ballSpeedLabel.Text = "---"
            targetedLabel.Text = "---"
            targetedLabel.TextColor3 = Config.TextColor
        end
        
        parryCountLabel.Text = tostring(State.ParryCount)
        
        -- Stats page update
        sParryLabel.Text = tostring(State.ParryCount)
        sMissLabel.Text = tostring(State.MissCount)
        
        if State.ParryCount + State.MissCount > 0 then
            sRateLabel.Text = math.floor(State.ParryCount / (State.ParryCount + State.MissCount) * 100) .. "%"
        else
            sRateLabel.Text = "N/A"
        end
        
        local uptime = tick() - startTime
        local mins = math.floor(uptime / 60)
        local secs = math.floor(uptime % 60)
        sUptimeLabel.Text = string.format("%dm %ds", mins, secs)
        
        -- Accent line animation
        local hue = (tick() * 15) % 360
        -- Subtle color shift (optional, very subtle)
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BALL ESP SYSTEM
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local espHighlight = nil

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.2)
        
        if Config.ShowBallESP then
            local ball = ParryEngine:GetBall()
            if ball then
                if not espHighlight or espHighlight.Parent ~= ball.Parent then
                    if espHighlight then espHighlight:Destroy() end
                    espHighlight = Instance.new("Highlight")
                    espHighlight.Name = "SynESP"
                    espHighlight.FillColor = Config.AccentColor
                    espHighlight.OutlineColor = Config.AccentColor2
                    espHighlight.FillTransparency = 0.5
                    espHighlight.OutlineTransparency = 0
                    espHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    
                    if ball:IsA("BasePart") then
                        espHighlight.Adornee = ball
                        espHighlight.Parent = ball
                    end
                end
                
                -- Color based on distance
                local dist = ParryEngine:GetDistanceToBall(ball)
                if dist < Config.ParryDistance then
                    espHighlight.FillColor = Config.DangerColor
                    espHighlight.OutlineColor = Config.DangerColor
                elseif dist < Config.ParryDistance * 2 then
                    espHighlight.FillColor = Config.WarningColor
                    espHighlight.OutlineColor = Config.WarningColor
                else
                    espHighlight.FillColor = Config.AccentColor
                    espHighlight.OutlineColor = Config.AccentColor2
                end
            end
        else
            if espHighlight then
                espHighlight:Destroy()
                espHighlight = nil
            end
        end
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VIEWPORT RESIZE HANDLER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    WindowW, WindowH = Util.GetWindowSize()
    if State.GuiOpen then
        Util.Tween(MainWindow, {
            Size = UDim2.new(0, WindowW, 0, WindowH)
        }, 0.3)
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STARTUP
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Start parry engine
ParryEngine:Start()

-- Initial notification
task.delay(1, function()
    Library:Notify("SYN-STUDIO", "Loaded successfully! Press ⚔ or Right Shift", Config.AccentColor, 4)
end)

task.delay(2, function()
    Library:Notify("Auto Parry", "Smart parry system is active", Config.SuccessColor, 3)
end)

-- Auto open on first load
task.delay(0.5, function()
    Library:Open()
end)

print([[
╔═══════════════════════════════════╗
║     SYN-STUDIO v2.0 Loaded!      ║
║     Blade Ball Auto Parry         ║
║                                   ║
║  Controls:                        ║
║  Right Shift - Toggle GUI         ║
║  P - Toggle Auto Parry            ║
║  ⚔ Button - Toggle GUI            ║
╚═══════════════════════════════════╝
]])
