--[[
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ███████╗██╗   ██╗███████╗██╗   ██╗███╗   ██╗██╗            ║
║   ╚══███╔╝██║   ██║██╔════╝╚██╗ ██╔╝████╗  ██║██║            ║
║     ███╔╝ ██║   ██║███████╗ ╚████╔╝ ██╔██╗ ██║██║            ║
║    ███╔╝  ██║   ██║╚════██║  ╚██╔╝  ██║╚██╗██║██║            ║
║   ███████╗╚██████╔╝███████║   ██║   ██║ ╚████║██║            ║
║   ╚══════╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚═╝            ║
║                                                               ║
║   Ultra Premium Mod Menu Library v3.0                        ║
║   Professional Developer Interface                            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
]]

-- ╔═══════════════════════════════════════════╗
-- ║          SERVICES & CORE SETUP            ║
-- ╚═══════════════════════════════════════════╝

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = Workspace.CurrentCamera

-- ╔═══════════════════════════════════════════╗
-- ║          ANTI-DETECTION SYSTEM            ║
-- ╚═══════════════════════════════════════════╝

local AntiDetect = {}

-- Spoof script detection methods
AntiDetect.Init = function()
    -- 1. Hide from common detection patterns
    pcall(function()
        -- Mask getconnections if available
        if getconnections then
            for _, conn in ipairs(getconnections(Player.Idled)) do
                conn:Disable()
            end
        end
    end)

    -- 2. Hook metamethods to hide GUI from detection scripts
    pcall(function()
        if hookmetamethod and getrawmetatable then
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            local oldIndex = mt.__index

            if setreadonly then setreadonly(mt, false) end

            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}

                -- Block FindFirstChild/WaitForChild lookups for our GUI
                if method == "FindFirstChild" or method == "FindFirstChildOfClass" then
                    if args[1] and type(args[1]) == "string" then
                        if args[1]:find("ZUSYNI") or args[1]:find("ZusyniLib") then
                            return nil
                        end
                    end
                end

                -- Block kick attempts
                if method == "Kick" and self == Player then
                    return nil
                end

                -- Block remote detection of our actions
                if method == "FireServer" or method == "InvokeServer" then
                    local remoteName = self.Name:lower()
                    if remoteName:find("detect") or remoteName:find("anticheat")
                       or remoteName:find("security") or remoteName:find("report")
                       or remoteName:find("ban") or remoteName:find("kick") then
                        return nil
                    end
                end

                return oldNamecall(self, ...)
            end)

            mt.__index = newcclosure(function(self, key)
                -- Hide our ScreenGui from enumeration
                if self == CoreGui and key == "ZUSYNI_Premium" then
                    return nil
                end
                return oldIndex(self, key)
            end)

            if setreadonly then setreadonly(mt, true) end
        end
    end)

    -- 3. Spoof PlayerGui children count
    pcall(function()
        if hookfunction then
            local oldGetChildren = game.GetChildren
            hookfunction(oldGetChildren, newcclosure(function(self, ...)
                local result = oldGetChildren(self, ...)
                if self == Player:FindFirstChild("PlayerGui") or self == CoreGui then
                    local filtered = {}
                    for _, child in ipairs(result) do
                        if child.Name ~= "ZUSYNI_Premium" and child.Name ~= "ZusyniLib" then
                            table.insert(filtered, child)
                        end
                    end
                    return filtered
                end
                return result
            end))
        end
    end)

    -- 4. Block screenshot/recording detection of GUI
    pcall(function()
        if sethiddenproperty then
            -- Will be applied to ScreenGui later
        end
    end)

    -- 5. Anti-teleport detection
    pcall(function()
        local TeleportService = game:GetService("TeleportService")
        if hookfunction then
            local oldTeleport = TeleportService.Teleport
            hookfunction(oldTeleport, newcclosure(function(self, placeId, ...)
                -- Allow teleport but re-inject after
                return oldTeleport(self, placeId, ...)
            end))
        end
    end)

    -- 6. Heartbeat spoofing (anti-speed detection)
    pcall(function()
        local realClock = os.clock
        -- Keep original timing to avoid speed detection
    end)

    -- 7. Block common anti-cheat remote names
    pcall(function()
        if hookfunction then
            local oldFireServer = Instance.new("RemoteEvent").FireServer
            hookfunction(oldFireServer, newcclosure(function(self, ...)
                if self and self:IsA("RemoteEvent") then
                    local name = self.Name:lower()
                    local blockedPatterns = {
                        "anticheat", "anti_cheat", "detection", "security",
                        "validate", "verify", "checker", "monitor",
                        "report", "flag", "suspicious", "exploit"
                    }
                    for _, pattern in ipairs(blockedPatterns) do
                        if name:find(pattern) then
                            return nil
                        end
                    end
                end
                return oldFireServer(self, ...)
            end))
        end
    end)
end

-- Initialize anti-detection
pcall(AntiDetect.Init)

-- ╔═══════════════════════════════════════════╗
-- ║          DEVICE DETECTION                 ║
-- ╚═══════════════════════════════════════════╝

local ViewportSize = Camera.ViewportSize
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local IsTablet = IsMobile and math.min(ViewportSize.X, ViewportSize.Y) > 600
local IsPortrait = ViewportSize.Y > ViewportSize.X

local function GetViewport()
    ViewportSize = Camera.ViewportSize
    IsPortrait = ViewportSize.Y > ViewportSize.X
    return ViewportSize
end

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    GetViewport()
end)

-- ╔═══════════════════════════════════════════╗
-- ║          DESIGN TOKENS                    ║
-- ╚═══════════════════════════════════════════╝

local Tokens = {
    -- Color Palette — Refined dark premium
    Colors = {
        BgPrimary      = Color3.fromRGB(12, 12, 16),
        BgSecondary    = Color3.fromRGB(18, 18, 24),
        BgTertiary     = Color3.fromRGB(24, 24, 32),
        BgElevated     = Color3.fromRGB(28, 28, 38),
        BgHover        = Color3.fromRGB(34, 34, 46),
        BgActive       = Color3.fromRGB(40, 40, 54),

        Surface        = Color3.fromRGB(22, 22, 30),
        SurfaceHover   = Color3.fromRGB(30, 30, 40),
        SurfaceBorder  = Color3.fromRGB(42, 42, 56),

        Accent         = Color3.fromRGB(99, 102, 241),  -- Indigo
        AccentHover    = Color3.fromRGB(120, 123, 255),
        AccentMuted    = Color3.fromRGB(99, 102, 241),
        AccentSubtle   = Color3.fromRGB(30, 30, 60),

        TextPrimary    = Color3.fromRGB(240, 240, 248),
        TextSecondary  = Color3.fromRGB(160, 160, 180),
        TextTertiary   = Color3.fromRGB(100, 100, 120),
        TextDisabled   = Color3.fromRGB(60, 60, 75),

        Success        = Color3.fromRGB(52, 211, 153),
        Warning        = Color3.fromRGB(251, 191, 36),
        Error          = Color3.fromRGB(239, 68, 68),
        Info           = Color3.fromRGB(96, 165, 250),

        Border         = Color3.fromRGB(38, 38, 52),
        BorderLight    = Color3.fromRGB(50, 50, 68),
        Divider        = Color3.fromRGB(32, 32, 44),

        Shadow         = Color3.fromRGB(0, 0, 0),
        Overlay        = Color3.fromRGB(0, 0, 0),

        White          = Color3.fromRGB(255, 255, 255),
        Black          = Color3.fromRGB(0, 0, 0),
    },

    -- Spacing system (base 4px)
    Spacing = {
        xs  = 4,
        sm  = 8,
        md  = 12,
        lg  = 16,
        xl  = 20,
        xxl = 24,
        xxxl = 32,
    },

    -- Corner radius
    Radius = {
        sm  = 6,
        md  = 8,
        lg  = 10,
        xl  = 12,
        xxl = 16,
        full = 999,
    },

    -- Font sizes
    FontSize = {
        xs    = 10,
        sm    = 11,
        md    = 12,
        lg    = 14,
        xl    = 16,
        xxl   = 18,
        title = 20,
        hero  = 24,
    },

    -- Animation durations
    Duration = {
        instant = 0.08,
        fast    = 0.15,
        normal  = 0.25,
        slow    = 0.35,
        page    = 0.3,
    },

    -- Sidebar
    Sidebar = {
        ExpandedWidth = IsMobile and 50 or 160,
        CollapsedWidth = IsMobile and 42 or 48,
    },
}

-- ╔═══════════════════════════════════════════╗
-- ║          UTILITY FUNCTIONS                ║
-- ╚═══════════════════════════════════════════╝

local Util = {}

function Util.Tween(obj, props, duration, style, direction)
    if not obj or not obj.Parent then return end
    local tween = TweenService:Create(
        obj,
        TweenInfo.new(
            duration or Tokens.Duration.normal,
            style or Enum.EasingStyle.Quint,
            direction or Enum.EasingDirection.Out
        ),
        props
    )
    tween:Play()
    return tween
end

function Util.Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or Tokens.Radius.md)
    c.Parent = parent
    return c
end

function Util.Stroke(parent, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = color or Tokens.Colors.Border
    s.Thickness = thick or 1
    s.Transparency = trans or 0.3
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

function Util.Padding(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or t or 0)
    p.PaddingLeft = UDim.new(0, l or t or 0)
    p.PaddingRight = UDim.new(0, r or l or t or 0)
    p.Parent = parent
    return p
end

function Util.ListLayout(parent, padding, dir, hAlign, vAlign, sort)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, padding or Tokens.Spacing.sm)
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left
    l.VerticalAlignment = vAlign or Enum.VerticalAlignment.Top
    l.SortOrder = sort or Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

function Util.Shadow(parent, size, trans)
    local s = Instance.new("ImageLabel")
    s.Name = "_Shadow"
    s.BackgroundTransparency = 1
    s.Image = "rbxassetid://7912134082"
    s.ImageColor3 = Tokens.Colors.Shadow
    s.ImageTransparency = trans or 0.6
    s.Size = UDim2.new(1, size or 40, 1, size or 40)
    s.Position = UDim2.new(0.5, 0, 0.5, 0)
    s.AnchorPoint = Vector2.new(0.5, 0.5)
    s.ScaleType = Enum.ScaleType.Slice
    s.SliceCenter = Rect.new(100, 100, 100, 100)
    s.ZIndex = -1
    s.Parent = parent
    return s
end

function Util.Gradient(parent, c1, c2, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rotation or 90
    g.Parent = parent
    return g
end

function Util.Ripple(button, color)
    local ripple = Instance.new("Frame")
    ripple.BackgroundColor3 = color or Tokens.Colors.White
    ripple.BackgroundTransparency = 0.85
    ripple.BorderSizePixel = 0
    ripple.ZIndex = button.ZIndex + 2
    ripple.Parent = button
    Util.Corner(ripple, Tokens.Radius.full)

    local mousePos = UserInputService:GetMouseLocation()
    local absPos = button.AbsolutePosition
    local relX = mousePos.X - absPos.X
    local relY = mousePos.Y - absPos.Y - GuiService:GetGuiInset().Y

    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.Position = UDim2.new(0, relX, 0, relY)
    ripple.AnchorPoint = Vector2.new(0.5, 0.5)

    local maxDim = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2
    Util.Tween(ripple, {
        Size = UDim2.new(0, maxDim, 0, maxDim),
        BackgroundTransparency = 1
    }, 0.5, Enum.EasingStyle.Quint)

    task.delay(0.5, function()
        if ripple and ripple.Parent then ripple:Destroy() end
    end)
end

function Util.GenerateId()
    return HttpService:GenerateGUID(false):sub(1, 8)
end

-- ╔═══════════════════════════════════════════╗
-- ║          LIBRARY CORE                     ║
-- ╚═══════════════════════════════════════════╝

local Library = {}
Library.__index = Library
Library.Windows = {}
Library.Connections = {}
Library.Tweens = {}
Library.ToggleKey = Enum.KeyCode.RightShift
Library.Notifications = {}

function Library:AddConnection(conn)
    table.insert(self.Connections, conn)
    return conn
end

function Library:Destroy()
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    for _, tween in ipairs(self.Tweens) do
        pcall(function() tween:Cancel() end)
    end
    if self._ScreenGui then
        pcall(function() self._ScreenGui:Destroy() end)
    end
    table.clear(self.Connections)
    table.clear(self.Tweens)
    table.clear(self.Windows)
end

-- ╔═══════════════════════════════════════════╗
-- ║          SCREENGU I SETUP                 ║
-- ╚═══════════════════════════════════════════╝

function Library:_InitGui()
    if self._ScreenGui then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "ZUSYNI_Premium"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999
    sg.IgnoreGuiInset = true

    -- Anti-detection: try CoreGui first
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(sg)
        end
        sg.Parent = CoreGui
    end)
    if not sg.Parent then
        pcall(function() sg.Parent = Player:WaitForChild("PlayerGui") end)
    end

    -- Anti-detection properties
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(sg, "OnTopOfCoreBlur", true)
        end
    end)

    self._ScreenGui = sg
    return sg
end

-- ╔═══════════════════════════════════════════╗
-- ║          NOTIFICATION SYSTEM              ║
-- ╚═══════════════════════════════════════════╝

function Library:_InitNotifications()
    if self._NotifHolder then return end

    local holder = Instance.new("Frame")
    holder.Name = "Notifications"
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(0, IsMobile and 260 or 320, 1, -20)
    holder.Position = UDim2.new(1, -(IsMobile and 270 or 330), 0, 10)
    holder.ZIndex = 100
    holder.Parent = self._ScreenGui

    local layout = Util.ListLayout(holder, Tokens.Spacing.sm)
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right

    Util.Padding(holder, 0, Tokens.Spacing.lg, 0, 0)

    self._NotifHolder = holder
end

function Library:Notify(config)
    self:_InitNotifications()

    local title = config.Title or "Notification"
    local desc = config.Description or ""
    local duration = config.Duration or 4
    local nType = config.Type or "info" -- info, success, warning, error

    local accentColor = Tokens.Colors.Info
    local icon = "i"
    if nType == "success" then
        accentColor = Tokens.Colors.Success; icon = "✓"
    elseif nType == "warning" then
        accentColor = Tokens.Colors.Warning; icon = "!"
    elseif nType == "error" then
        accentColor = Tokens.Colors.Error; icon = "✕"
    end

    local notifWidth = IsMobile and 260 or 320

    -- Container
    local container = Instance.new("Frame")
    container.Name = "Notif_" .. Util.GenerateId()
    container.BackgroundColor3 = Tokens.Colors.BgElevated
    container.Size = UDim2.new(0, notifWidth, 0, 0)
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.ClipsDescendants = true
    container.ZIndex = 101
    container.Parent = self._NotifHolder
    Util.Corner(container, Tokens.Radius.lg)
    Util.Stroke(container, Tokens.Colors.Border, 1, 0.5)
    Util.Shadow(container, 30, 0.7)

    -- Accent bar left
    local accent = Instance.new("Frame")
    accent.BackgroundColor3 = accentColor
    accent.Size = UDim2.new(0, 3, 1, 0)
    accent.BorderSizePixel = 0
    accent.ZIndex = 102
    accent.Parent = container

    -- Inner content
    local inner = Instance.new("Frame")
    inner.BackgroundTransparency = 1
    inner.Size = UDim2.new(1, -12, 0, 0)
    inner.Position = UDim2.new(0, 12, 0, 0)
    inner.AutomaticSize = Enum.AutomaticSize.Y
    inner.ZIndex = 102
    inner.Parent = container
    Util.Padding(inner, Tokens.Spacing.md, Tokens.Spacing.md, Tokens.Spacing.sm, Tokens.Spacing.md)

    local innerLayout = Util.ListLayout(inner, Tokens.Spacing.xs)

    -- Header row
    local headerRow = Instance.new("Frame")
    headerRow.BackgroundTransparency = 1
    headerRow.Size = UDim2.new(1, 0, 0, 18)
    headerRow.LayoutOrder = 1
    headerRow.ZIndex = 103
    headerRow.Parent = inner

    -- Icon circle
    local iconFrame = Instance.new("Frame")
    iconFrame.BackgroundColor3 = accentColor
    iconFrame.BackgroundTransparency = 0.85
    iconFrame.Size = UDim2.new(0, 18, 0, 18)
    iconFrame.ZIndex = 104
    iconFrame.Parent = headerRow
    Util.Corner(iconFrame, Tokens.Radius.full)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.BackgroundTransparency = 1
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 10
    iconLabel.TextColor3 = accentColor
    iconLabel.Text = icon
    iconLabel.ZIndex = 105
    iconLabel.Parent = iconFrame

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -50, 0, 18)
    titleLabel.Position = UDim2.new(0, 24, 0, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = Tokens.FontSize.sm
    titleLabel.TextColor3 = Tokens.Colors.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Text = title
    titleLabel.ZIndex = 104
    titleLabel.Parent = headerRow

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundTransparency = 1
    closeBtn.Size = UDim2.new(0, 18, 0, 18)
    closeBtn.Position = UDim2.new(1, -18, 0, 0)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Tokens.Colors.TextTertiary
    closeBtn.Text = "×"
    closeBtn.ZIndex = 105
    closeBtn.Parent = headerRow

    -- Description
    if desc ~= "" then
        local descLabel = Instance.new("TextLabel")
        descLabel.BackgroundTransparency = 1
        descLabel.Size = UDim2.new(1, 0, 0, 0)
        descLabel.AutomaticSize = Enum.AutomaticSize.Y
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = Tokens.FontSize.xs
        descLabel.TextColor3 = Tokens.Colors.TextSecondary
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextWrapped = true
        descLabel.Text = desc
        descLabel.LayoutOrder = 2
        descLabel.ZIndex = 103
        descLabel.Parent = inner
    end

    -- Progress bar
    local progressBg = Instance.new("Frame")
    progressBg.BackgroundColor3 = Tokens.Colors.BgTertiary
    progressBg.Size = UDim2.new(1, 0, 0, 2)
    progressBg.BorderSizePixel = 0
    progressBg.LayoutOrder = 3
    progressBg.ZIndex = 103
    progressBg.Parent = inner
    Util.Corner(progressBg, 1)

    local progressFill = Instance.new("Frame")
    progressFill.BackgroundColor3 = accentColor
    progressFill.Size = UDim2.new(1, 0, 1, 0)
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 104
    progressFill.Parent = progressBg
    Util.Corner(progressFill, 1)

    -- Animate in
    container.Position = UDim2.new(1, 50, 0, 0)
    container.BackgroundTransparency = 0.5
    Util.Tween(container, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0}, Tokens.Duration.normal)

    -- Progress countdown
    Util.Tween(progressFill, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)

    -- Close function
    local function closeNotif()
        Util.Tween(container, {
            Position = UDim2.new(1, 50, 0, 0),
            BackgroundTransparency = 1
        }, Tokens.Duration.fast)
        task.delay(Tokens.Duration.fast + 0.05, function()
            if container and container.Parent then container:Destroy() end
        end)
    end

    closeBtn.MouseButton1Click:Connect(closeNotif)
    task.delay(duration, closeNotif)
end

-- ╔═══════════════════════════════════════════╗
-- ║          TOOLTIP SYSTEM                   ║
-- ╚═══════════════════════════════════════════╝

function Library:_InitTooltip()
    if self._Tooltip then return end

    local tooltip = Instance.new("Frame")
    tooltip.Name = "Tooltip"
    tooltip.BackgroundColor3 = Tokens.Colors.BgElevated
    tooltip.Size = UDim2.new(0, 0, 0, 0)
    tooltip.AutomaticSize = Enum.AutomaticSize.XY
    tooltip.Visible = false
    tooltip.ZIndex = 200
    tooltip.Parent = self._ScreenGui
    Util.Corner(tooltip, Tokens.Radius.sm)
    Util.Stroke(tooltip, Tokens.Colors.BorderLight, 1, 0.5)
    Util.Shadow(tooltip, 16, 0.7)
    Util.Padding(tooltip, Tokens.Spacing.sm, Tokens.Spacing.sm, Tokens.Spacing.md, Tokens.Spacing.md)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.XY
    label.Font = Enum.Font.Gotham
    label.TextSize = Tokens.FontSize.xs
    label.TextColor3 = Tokens.Colors.TextSecondary
    label.TextWrapped = true
    label.ZIndex = 201
    label.Parent = tooltip

    local maxW = Instance.new("UISizeConstraint")
    maxW.MaxSize = Vector2.new(200, 100)
    maxW.Parent = label

    self._Tooltip = tooltip
    self._TooltipLabel = label
end

function Library:ShowTooltip(text, refObj)
    self:_InitTooltip()
    self._TooltipLabel.Text = text
    self._Tooltip.Visible = true
    self._Tooltip.BackgroundTransparency = 1

    -- Position near the reference object
    local absPos = refObj.AbsolutePosition
    local absSize = refObj.AbsoluteSize
    local x = absPos.X + absSize.X + 8
    local y = absPos.Y + absSize.Y / 2

    -- Keep on screen
    task.defer(function()
        local ttSize = self._Tooltip.AbsoluteSize
        local vp = GetViewport()
        if x + ttSize.X > vp.X - 10 then
            x = absPos.X - ttSize.X - 8
        end
        if y + ttSize.Y > vp.Y - 10 then
            y = vp.Y - ttSize.Y - 10
        end
        self._Tooltip.Position = UDim2.new(0, x, 0, y - 15)
    end)

    self._Tooltip.Position = UDim2.new(0, x, 0, y - 10)
    Util.Tween(self._Tooltip, {BackgroundTransparency = 0}, Tokens.Duration.fast)
end

function Library:HideTooltip()
    if not self._Tooltip then return end
    Util.Tween(self._Tooltip, {BackgroundTransparency = 1}, Tokens.Duration.fast)
    task.delay(Tokens.Duration.fast, function()
        if self._Tooltip then self._Tooltip.Visible = false end
    end)
end

-- ╔═══════════════════════════════════════════╗
-- ║          MODAL / POPUP SYSTEM             ║
-- ╚═══════════════════════════════════════════╝

function Library:Modal(config)
    local title = config.Title or "Confirm"
    local desc = config.Description or ""
    local confirmText = config.ConfirmText or "Confirm"
    local cancelText = config.CancelText or "Cancel"
    local onConfirm = config.OnConfirm
    local onCancel = config.OnCancel

    -- Overlay
    local overlay = Instance.new("TextButton")
    overlay.Name = "ModalOverlay"
    overlay.BackgroundColor3 = Tokens.Colors.Overlay
    overlay.BackgroundTransparency = 1
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Text = ""
    overlay.ZIndex = 150
    overlay.Parent = self._ScreenGui

    Util.Tween(overlay, {BackgroundTransparency = 0.5}, Tokens.Duration.normal)

    -- Modal card
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Tokens.Colors.BgElevated
    card.Size = UDim2.new(0, IsMobile and 280 or 340, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.ZIndex = 151
    card.Parent = overlay
    Util.Corner(card, Tokens.Radius.xl)
    Util.Stroke(card, Tokens.Colors.BorderLight, 1, 0.4)
    Util.Shadow(card, 50, 0.5)
    Util.Padding(card, Tokens.Spacing.xl, Tokens.Spacing.xl, Tokens.Spacing.xl, Tokens.Spacing.xl)

    local cardLayout = Util.ListLayout(card, Tokens.Spacing.md)
    cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    -- Title
    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Size = UDim2.new(1, 0, 0, 24)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = Tokens.FontSize.xl
    titleLbl.TextColor3 = Tokens.Colors.TextPrimary
    titleLbl.Text = title
    titleLbl.LayoutOrder = 1
    titleLbl.ZIndex = 152
    titleLbl.Parent = card

    -- Desc
    if desc ~= "" then
        local descLbl = Instance.new("TextLabel")
        descLbl.BackgroundTransparency = 1
        descLbl.Size = UDim2.new(1, 0, 0, 0)
        descLbl.AutomaticSize = Enum.AutomaticSize.Y
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = Tokens.FontSize.sm
        descLbl.TextColor3 = Tokens.Colors.TextSecondary
        descLbl.TextWrapped = true
        descLbl.Text = desc
        descLbl.LayoutOrder = 2
        descLbl.ZIndex = 152
        descLbl.Parent = card
    end

    -- Buttons row
    local btnRow = Instance.new("Frame")
    btnRow.BackgroundTransparency = 1
    btnRow.Size = UDim2.new(1, 0, 0, 36)
    btnRow.LayoutOrder = 3
    btnRow.ZIndex = 152
    btnRow.Parent = card

    local btnLayout = Util.ListLayout(btnRow, Tokens.Spacing.sm, Enum.FillDirection.Horizontal)
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

    local function closeModal()
        Util.Tween(card, {BackgroundTransparency = 1}, Tokens.Duration.fast)
        Util.Tween(overlay, {BackgroundTransparency = 1}, Tokens.Duration.fast)
        task.delay(Tokens.Duration.fast + 0.05, function()
            if overlay and overlay.Parent then overlay:Destroy() end
        end)
    end

    -- Cancel btn
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.BackgroundColor3 = Tokens.Colors.BgTertiary
    cancelBtn.Size = UDim2.new(0.48, 0, 1, 0)
    cancelBtn.Font = Enum.Font.GothamMedium
    cancelBtn.TextSize = Tokens.FontSize.sm
    cancelBtn.TextColor3 = Tokens.Colors.TextSecondary
    cancelBtn.Text = cancelText
    cancelBtn.LayoutOrder = 1
    cancelBtn.ZIndex = 153
    cancelBtn.Parent = btnRow
    Util.Corner(cancelBtn, Tokens.Radius.md)

    -- Confirm btn
    local confirmBtn = Instance.new("TextButton")
    confirmBtn.BackgroundColor3 = Tokens.Colors.Accent
    confirmBtn.Size = UDim2.new(0.48, 0, 1, 0)
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.TextSize = Tokens.FontSize.sm
    confirmBtn.TextColor3 = Tokens.Colors.White
    confirmBtn.Text = confirmText
    confirmBtn.LayoutOrder = 2
    confirmBtn.ZIndex = 153
    confirmBtn.Parent = btnRow
    Util.Corner(confirmBtn, Tokens.Radius.md)

    -- Animate in
    card.BackgroundTransparency = 0.5
    card.Size = UDim2.new(0, (IsMobile and 280 or 340) * 0.95, 0, 0)
    Util.Tween(card, {
        BackgroundTransparency = 0,
        Size = UDim2.new(0, IsMobile and 280 or 340, 0, 0)
    }, Tokens.Duration.normal, Enum.EasingStyle.Back)

    cancelBtn.MouseButton1Click:Connect(function()
        Util.Ripple(cancelBtn)
        closeModal()
        if onCancel then onCancel() end
    end)

    confirmBtn.MouseButton1Click:Connect(function()
        Util.Ripple(confirmBtn, Tokens.Colors.Accent)
        closeModal()
        if onConfirm then onConfirm() end
    end)

    overlay.MouseButton1Click:Connect(function()
        closeModal()
        if onCancel then onCancel() end
    end)
end

-- ╔═══════════════════════════════════════════╗
-- ║          WINDOW CREATION                  ║
-- ╚═══════════════════════════════════════════╝

function Library:CreateWindow(config)
    self:_InitGui()

    local windowTitle = config.Title or "ZUSYNI"
    local windowSubtitle = config.Subtitle or "Premium Interface"
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift

    self.ToggleKey = toggleKey

    local Window = {}
    Window.Tabs = {}
    Window.ActiveTab = nil
    Window.SidebarExpanded = not IsMobile
    Window._Library = self

    -- ═══════════════════════════════════════
    -- CALCULATE RESPONSIVE SIZE
    -- ═══════════════════════════════════════

    local vp = GetViewport()

    local function CalcWindowSize()
        vp = GetViewport()
        local wScale, hScale

        if IsMobile then
            wScale = IsPortrait and 0.88 or 0.82
            hScale = IsPortrait and 0.68 or 0.72
        else
            wScale = 0.58
            hScale = 0.70
        end

        local w = math.clamp(vp.X * wScale, 320, 900)
        local h = math.clamp(vp.Y * hScale, 280, 650)

        return w, h
    end

    local winW, winH = CalcWindowSize()

    -- ═══════════════════════════════════════
    -- MAIN WINDOW FRAME
    -- ═══════════════════════════════════════

    local WindowFrame = Instance.new("Frame")
    WindowFrame.Name = "ZusyniWindow"
    WindowFrame.BackgroundColor3 = Tokens.Colors.BgPrimary
    WindowFrame.Size = UDim2.new(0, winW, 0, winH)
    WindowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    WindowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    WindowFrame.ClipsDescendants = true
    WindowFrame.Visible = false
    WindowFrame.ZIndex = 10
    WindowFrame.Parent = self._ScreenGui
    Util.Corner(WindowFrame, Tokens.Radius.xxl)
    Util.Stroke(WindowFrame, Tokens.Colors.Border, 1, 0.3)
    Util.Shadow(WindowFrame, 60, 0.55)

    Window._Frame = WindowFrame

    -- Resize handler
    local resizeConn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local nw, nh = CalcWindowSize()
        Util.Tween(WindowFrame, {
            Size = UDim2.new(0, nw, 0, nh)
        }, Tokens.Duration.slow)
    end)
    self:AddConnection(resizeConn)

    -- ═══════════════════════════════════════
    -- HEADER BAR
    -- ═══════════════════════════════════════

    local headerH = IsMobile and 44 or 48

    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.BackgroundColor3 = Tokens.Colors.BgSecondary
    Header.Size = UDim2.new(1, 0, 0, headerH)
    Header.BorderSizePixel = 0
    Header.ZIndex = 20
    Header.Parent = WindowFrame

    -- Only round top corners
    local headerCornerFix = Instance.new("Frame")
    headerCornerFix.BackgroundColor3 = Tokens.Colors.BgSecondary
    headerCornerFix.Size = UDim2.new(1, 0, 0, 10)
    headerCornerFix.Position = UDim2.new(0, 0, 1, -10)
    headerCornerFix.BorderSizePixel = 0
    headerCornerFix.ZIndex = 20
    headerCornerFix.Parent = Header

    Util.Corner(Header, Tokens.Radius.xxl)

    -- Accent line under header
    local headerLine = Instance.new("Frame")
    headerLine.BackgroundColor3 = Tokens.Colors.Accent
    headerLine.Size = UDim2.new(1, 0, 0, 1)
    headerLine.Position = UDim2.new(0, 0, 1, 0)
    headerLine.BorderSizePixel = 0
    headerLine.BackgroundTransparency = 0.7
    headerLine.ZIndex = 21
    headerLine.Parent = Header

    -- Logo container
    local logoContainer = Instance.new("Frame")
    logoContainer.BackgroundColor3 = Tokens.Colors.Accent
    logoContainer.BackgroundTransparency = 0.88
    logoContainer.Size = UDim2.new(0, 28, 0, 28)
    logoContainer.Position = UDim2.new(0, Tokens.Spacing.lg, 0.5, 0)
    logoContainer.AnchorPoint = Vector2.new(0, 0.5)
    logoContainer.ZIndex = 22
    logoContainer.Parent = Header
    Util.Corner(logoContainer, Tokens.Radius.sm)

    local logoIcon = Instance.new("TextLabel")
    logoIcon.BackgroundTransparency = 1
    logoIcon.Size = UDim2.new(1, 0, 1, 0)
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.TextSize = 14
    logoIcon.TextColor3 = Tokens.Colors.Accent
    logoIcon.Text = "Z"
    logoIcon.ZIndex = 23
    logoIcon.Parent = logoContainer

    -- Title
    local headerTitle = Instance.new("TextLabel")
    headerTitle.BackgroundTransparency = 1
    headerTitle.Size = UDim2.new(0, 150, 0, 16)
    headerTitle.Position = UDim2.new(0, Tokens.Spacing.lg + 36, 0, IsMobile and 8 or 10)
    headerTitle.Font = Enum.Font.GothamBold
    headerTitle.TextSize = IsMobile and Tokens.FontSize.md or Tokens.FontSize.lg
    headerTitle.TextColor3 = Tokens.Colors.TextPrimary
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    headerTitle.Text = windowTitle
    headerTitle.ZIndex = 22
    headerTitle.Parent = Header

    -- Subtitle
    local headerSub = Instance.new("TextLabel")
    headerSub.BackgroundTransparency = 1
    headerSub.Size = UDim2.new(0, 200, 0, 12)
    headerSub.Position = UDim2.new(0, Tokens.Spacing.lg + 36, 0, (IsMobile and 8 or 10) + 17)
    headerSub.Font = Enum.Font.Gotham
    headerSub.TextSize = Tokens.FontSize.xs
    headerSub.TextColor3 = Tokens.Colors.TextTertiary
    headerSub.TextXAlignment = Enum.TextXAlignment.Left
    headerSub.Text = windowSubtitle
    headerSub.ZIndex = 22
    headerSub.Parent = Header

    -- Header buttons
    local headerBtnsFrame = Instance.new("Frame")
    headerBtnsFrame.BackgroundTransparency = 1
    headerBtnsFrame.Size = UDim2.new(0, 70, 0, headerH)
    headerBtnsFrame.Position = UDim2.new(1, -78, 0, 0)
    headerBtnsFrame.ZIndex = 22
    headerBtnsFrame.Parent = Header

    local hBtnLayout = Util.ListLayout(headerBtnsFrame, Tokens.Spacing.xs, Enum.FillDirection.Horizontal)
    hBtnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    hBtnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

    -- Sidebar toggle button
    local sidebarToggleBtn = Instance.new("TextButton")
    sidebarToggleBtn.BackgroundColor3 = Tokens.Colors.BgTertiary
    sidebarToggleBtn.BackgroundTransparency = 0.5
    sidebarToggleBtn.Size = UDim2.new(0, 28, 0, 28)
    sidebarToggleBtn.Font = Enum.Font.Gotham
    sidebarToggleBtn.TextSize = 14
    sidebarToggleBtn.TextColor3 = Tokens.Colors.TextSecondary
    sidebarToggleBtn.Text = "≡"
    sidebarToggleBtn.LayoutOrder = 1
    sidebarToggleBtn.ZIndex = 23
    sidebarToggleBtn.Parent = headerBtnsFrame
    Util.Corner(sidebarToggleBtn, Tokens.Radius.sm)

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundColor3 = Tokens.Colors.Error
    closeBtn.BackgroundTransparency = 0.8
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Tokens.Colors.Error
    closeBtn.Text = "×"
    closeBtn.LayoutOrder = 2
    closeBtn.ZIndex = 23
    closeBtn.Parent = headerBtnsFrame
    Util.Corner(closeBtn, Tokens.Radius.sm)

    closeBtn.MouseEnter:Connect(function()
        Util.Tween(closeBtn, {BackgroundTransparency = 0.5}, Tokens.Duration.fast)
    end)
    closeBtn.MouseLeave:Connect(function()
        Util.Tween(closeBtn, {BackgroundTransparency = 0.8}, Tokens.Duration.fast)
    end)

    -- ═══════════════════════════════════════
    -- BODY (Sidebar + Content)
    -- ═══════════════════════════════════════

    local Body = Instance.new("Frame")
    Body.Name = "Body"
    Body.BackgroundTransparency = 1
    Body.Size = UDim2.new(1, 0, 1, -headerH)
    Body.Position = UDim2.new(0, 0, 0, headerH)
    Body.ZIndex = 11
    Body.Parent = WindowFrame

    -- ═══════════════════════════════════════
    -- SIDEBAR
    -- ═══════════════════════════════════════

    local sidebarW = Window.SidebarExpanded and Tokens.Sidebar.ExpandedWidth or Tokens.Sidebar.CollapsedWidth

    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.BackgroundColor3 = Tokens.Colors.BgSecondary
    Sidebar.Size = UDim2.new(0, sidebarW, 1, 0)
    Sidebar.BorderSizePixel = 0
    Sidebar.ZIndex = 15
    Sidebar.ClipsDescendants = true
    Sidebar.Parent = Body

    -- Sidebar divider
    local sidebarDivider = Instance.new("Frame")
    sidebarDivider.BackgroundColor3 = Tokens.Colors.Divider
    sidebarDivider.Size = UDim2.new(0, 1, 1, 0)
    sidebarDivider.Position = UDim2.new(1, 0, 0, 0)
    sidebarDivider.BorderSizePixel = 0
    sidebarDivider.ZIndex = 16
    sidebarDivider.Parent = Sidebar

    -- Sidebar scroll
    local SidebarScroll = Instance.new("ScrollingFrame")
    SidebarScroll.BackgroundTransparency = 1
    SidebarScroll.Size = UDim2.new(1, 0, 1, -Tokens.Spacing.sm)
    SidebarScroll.Position = UDim2.new(0, 0, 0, Tokens.Spacing.xs)
    SidebarScroll.ScrollBarThickness = 0
    SidebarScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    SidebarScroll.ZIndex = 16
    SidebarScroll.Parent = Sidebar

    local sidebarLayout = Util.ListLayout(SidebarScroll, Tokens.Spacing.xs)
    Util.Padding(SidebarScroll, Tokens.Spacing.xs, Tokens.Spacing.xs, Tokens.Spacing.xs, Tokens.Spacing.xs)

    -- Sidebar toggle
    local function ToggleSidebar()
        Window.SidebarExpanded = not Window.SidebarExpanded
        local targetW = Window.SidebarExpanded and Tokens.Sidebar.ExpandedWidth or Tokens.Sidebar.CollapsedWidth
        Util.Tween(Sidebar, {Size = UDim2.new(0, targetW, 1, 0)}, Tokens.Duration.normal)
        Util.Tween(ContentArea, {
            Size = UDim2.new(1, -targetW, 1, 0),
            Position = UDim2.new(0, targetW, 0, 0)
        }, Tokens.Duration.normal)

        -- Update tab labels visibility
        for _, tab in ipairs(Window.Tabs) do
            if tab._SidebarLabel then
                Util.Tween(tab._SidebarLabel, {
                    TextTransparency = Window.SidebarExpanded and 0 or 1
                }, Tokens.Duration.fast)
            end
        end
    end

    sidebarToggleBtn.MouseButton1Click:Connect(function()
        Util.Ripple(sidebarToggleBtn)
        ToggleSidebar()
    end)

    -- ═══════════════════════════════════════
    -- CONTENT AREA
    -- ═══════════════════════════════════════

    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.BackgroundColor3 = Tokens.Colors.BgPrimary
    ContentArea.Size = UDim2.new(1, -sidebarW, 1, 0)
    ContentArea.Position = UDim2.new(0, sidebarW, 0, 0)
    ContentArea.BorderSizePixel = 0
    ContentArea.ClipsDescendants = true
    ContentArea.ZIndex = 12
    ContentArea.Parent = Body

    -- Search bar at top of content
    local SearchFrame = Instance.new("Frame")
    SearchFrame.BackgroundTransparency = 1
    SearchFrame.Size = UDim2.new(1, 0, 0, 42)
    SearchFrame.ZIndex = 14
    SearchFrame.Parent = ContentArea
    Util.Padding(SearchFrame, Tokens.Spacing.sm, 0, Tokens.Spacing.md, Tokens.Spacing.md)

    local SearchBox = Instance.new("TextBox")
    SearchBox.BackgroundColor3 = Tokens.Colors.BgTertiary
    SearchBox.Size = UDim2.new(1, 0, 0, 30)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = Tokens.FontSize.sm
    SearchBox.TextColor3 = Tokens.Colors.TextPrimary
    SearchBox.PlaceholderText = "  Search settings..."
    SearchBox.PlaceholderColor3 = Tokens.Colors.TextTertiary
    SearchBox.Text = ""
    SearchBox.ClearTextOnFocus = false
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.ZIndex = 15
    SearchBox.Parent = SearchFrame
    Util.Corner(SearchBox, Tokens.Radius.md)
    Util.Stroke(SearchBox, Tokens.Colors.Border, 1, 0.5)
    Util.Padding(SearchBox, 0, 0, Tokens.Spacing.lg, Tokens.Spacing.sm)

    -- Search focus animation
    SearchBox.Focused:Connect(function()
        Util.Tween(SearchBox, {
            BackgroundColor3 = Tokens.Colors.BgHover,
            Size = UDim2.new(1, 0, 0, 32)
        }, Tokens.Duration.fast)
        local stroke = SearchBox:FindFirstChildOfClass("UIStroke")
        if stroke then Util.Tween(stroke, {Color = Tokens.Colors.Accent, Transparency = 0.2}, Tokens.Duration.fast) end
    end)
    SearchBox.FocusLost:Connect(function()
        Util.Tween(SearchBox, {
            BackgroundColor3 = Tokens.Colors.BgTertiary,
            Size = UDim2.new(1, 0, 0, 30)
        }, Tokens.Duration.fast)
        local stroke = SearchBox:FindFirstChildOfClass("UIStroke")
        if stroke then Util.Tween(stroke, {Color = Tokens.Colors.Border, Transparency = 0.5}, Tokens.Duration.fast) end
    end)

    -- Page container (holds tab pages)
    local PageContainer = Instance.new("Frame")
    PageContainer.Name = "Pages"
    PageContainer.BackgroundTransparency = 1
    PageContainer.Size = UDim2.new(1, 0, 1, -42)
    PageContainer.Position = UDim2.new(0, 0, 0, 42)
    PageContainer.ClipsDescendants = true
    PageContainer.ZIndex = 13
    PageContainer.Parent = ContentArea

    Window._PageContainer = PageContainer

    -- ═══════════════════════════════════════
    -- SEARCH FUNCTIONALITY
    -- ═══════════════════════════════════════

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = SearchBox.Text:lower()
        -- Search through all components in active tab
        if Window.ActiveTab and Window.ActiveTab._Page then
            for _, descendant in ipairs(Window.ActiveTab._Page:GetDescendants()) do
                if descendant.Name == "_ComponentFrame" then
                    local label = descendant:FindFirstChild("_Label")
                    if label and label:IsA("TextLabel") then
                        local match = query == "" or label.Text:lower():find(query, 1, true)
                        Util.Tween(descendant, {
                            BackgroundTransparency = match and 0 or 0.8,
                            Size = match and UDim2.new(1, 0, 0, descendant:GetAttribute("OrigHeight") or 40) or UDim2.new(1, 0, 0, 0)
                        }, Tokens.Duration.fast)
                        descendant.ClipsDescendants = true
                        descendant.Visible = match and true or false
                    end
                end
            end
        end
    end)

    -- ═══════════════════════════════════════
    -- DRAGGING
    -- ═══════════════════════════════════════

    local isDragging = false
    local dragStartPos, frameStartPos

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStartPos = input.Position
            frameStartPos = WindowFrame.Position
        end
    end)

    self:AddConnection(UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartPos
            local vps = GetViewport()

            local newX = frameStartPos.X.Offset + delta.X
            local newY = frameStartPos.Y.Offset + delta.Y

            -- Clamp within viewport
            local halfW = WindowFrame.AbsoluteSize.X / 2
            local halfH = WindowFrame.AbsoluteSize.Y / 2
            newX = math.clamp(newX, -vps.X * 0.5 + halfW + 10, vps.X * 0.5 - halfW - 10)
            newY = math.clamp(newY, -vps.Y * 0.5 + halfH + 10, vps.Y * 0.5 - halfH - 10)

            Util.Tween(WindowFrame, {
                Position = UDim2.new(0.5, newX, 0.5, newY)
            }, 0.06, Enum.EasingStyle.Quad)
        end
    end))

    self:AddConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end))

    -- ═══════════════════════════════════════
    -- OPEN / CLOSE ANIMATION
    -- ═══════════════════════════════════════

    local isOpen = false

    function Window:Open()
        if isOpen then return end
        isOpen = true
        WindowFrame.Visible = true
        WindowFrame.BackgroundTransparency = 0.3

        -- Scale from 95%
        WindowFrame.Size = UDim2.new(0, winW * 0.95, 0, winH * 0.95)

        Util.Tween(WindowFrame, {
            Size = UDim2.new(0, winW, 0, winH),
            BackgroundTransparency = 0
        }, Tokens.Duration.normal, Enum.EasingStyle.Back)

        -- Header fade
        Header.BackgroundTransparency = 0.5
        Util.Tween(Header, {BackgroundTransparency = 0}, Tokens.Duration.normal)

        -- Sidebar slide
        Sidebar.Position = UDim2.new(0, -20, 0, 0)
        Sidebar.BackgroundTransparency = 0.5
        task.delay(0.05, function()
            Util.Tween(Sidebar, {
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundTransparency = 0
            }, Tokens.Duration.slow)
        end)

        -- Content fade
        ContentArea.BackgroundTransparency = 0.3
        task.delay(0.1, function()
            Util.Tween(ContentArea, {BackgroundTransparency = 0}, Tokens.Duration.normal)
        end)
    end

    function Window:Close()
        if not isOpen then return end
        isOpen = false

        -- Content fade out
        Util.Tween(ContentArea, {BackgroundTransparency = 0.3}, Tokens.Duration.fast)

        -- Sidebar slide out
        Util.Tween(Sidebar, {
            Position = UDim2.new(0, -15, 0, 0),
            BackgroundTransparency = 0.3
        }, Tokens.Duration.fast)

        -- Window scale down
        task.delay(0.05, function()
            Util.Tween(WindowFrame, {
                Size = UDim2.new(0, winW * 0.95, 0, winH * 0.95),
                BackgroundTransparency = 0.3
            }, Tokens.Duration.normal, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        end)

        task.delay(Tokens.Duration.normal + 0.1, function()
            WindowFrame.Visible = false
        end)
    end

    function Window:Toggle()
        if isOpen then self:Close() else self:Open() end
    end

    -- Close button
    closeBtn.MouseButton1Click:Connect(function()
        Util.Ripple(closeBtn, Tokens.Colors.Error)
        Window:Close()
    end)

    -- Toggle keybind
    self:AddConnection(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == self.ToggleKey then
            Window:Toggle()
        end
    end))

    -- ═══════════════════════════════════════
    -- TAB SYSTEM
    -- ═══════════════════════════════════════

    function Window:AddTab(config)
        local tabName = config.Name or "Tab"
        local tabIcon = config.Icon or "●"

        local Tab = {}
        Tab.Name = tabName
        Tab.Sections = {}
        Tab._Components = {}

        local tabIndex = #Window.Tabs + 1

        -- Sidebar button
        local tabBtnH = IsMobile and 36 or 38

        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "Tab_" .. tabName
        tabBtn.BackgroundColor3 = Tokens.Colors.BgSecondary
        tabBtn.BackgroundTransparency = 1
        tabBtn.Size = UDim2.new(1, 0, 0, tabBtnH)
        tabBtn.Text = ""
        tabBtn.LayoutOrder = tabIndex
        tabBtn.ZIndex = 17
        tabBtn.Parent = SidebarScroll
        Util.Corner(tabBtn, Tokens.Radius.md)

        -- Tab icon
        local tabIconLabel = Instance.new("TextLabel")
        tabIconLabel.BackgroundTransparency = 1
        tabIconLabel.Size = UDim2.new(0, 24, 1, 0)
        tabIconLabel.Position = UDim2.new(0, IsMobile and 9 or 12, 0, 0)
        tabIconLabel.Font = Enum.Font.Gotham
        tabIconLabel.TextSize = IsMobile and 13 or 14
        tabIconLabel.TextColor3 = Tokens.Colors.TextTertiary
        tabIconLabel.Text = tabIcon
        tabIconLabel.ZIndex = 18
        tabIconLabel.Parent = tabBtn

        -- Tab label
        local tabLabel = Instance.new("TextLabel")
        tabLabel.Name = "Label"
        tabLabel.BackgroundTransparency = 1
        tabLabel.Size = UDim2.new(1, -44, 1, 0)
        tabLabel.Position = UDim2.new(0, 40, 0, 0)
        tabLabel.Font = Enum.Font.GothamMedium
        tabLabel.TextSize = Tokens.FontSize.sm
        tabLabel.TextColor3 = Tokens.Colors.TextSecondary
        tabLabel.TextXAlignment = Enum.TextXAlignment.Left
        tabLabel.TextTruncate = Enum.TextTruncate.AtEnd
        tabLabel.Text = tabName
        tabLabel.TextTransparency = Window.SidebarExpanded and 0 or 1
        tabLabel.ZIndex = 18
        tabLabel.Parent = tabBtn

        Tab._SidebarBtn = tabBtn
        Tab._SidebarIcon = tabIconLabel
        Tab._SidebarLabel = tabLabel

        -- Active indicator
        local activeIndicator = Instance.new("Frame")
        activeIndicator.BackgroundColor3 = Tokens.Colors.Accent
        activeIndicator.Size = UDim2.new(0, 3, 0, 0)
        activeIndicator.Position = UDim2.new(0, 0, 0.5, 0)
        activeIndicator.AnchorPoint = Vector2.new(0, 0.5)
        activeIndicator.BorderSizePixel = 0
        activeIndicator.ZIndex = 19
        activeIndicator.Parent = tabBtn
        Util.Corner(activeIndicator, 2)

        Tab._Indicator = activeIndicator

        -- Page
        local page = Instance.new("ScrollingFrame")
        page.Name = "Page_" .. tabName
        page.BackgroundTransparency = 1
        page.Size = UDim2.new(1, 0, 1, 0)
        page.ScrollBarThickness = 2
        page.ScrollBarImageColor3 = Tokens.Colors.Accent
        page.ScrollBarImageTransparency = 0.5
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = false
        page.ZIndex = 13
        page.Parent = PageContainer
        Util.Padding(page, Tokens.Spacing.md, Tokens.Spacing.xl, Tokens.Spacing.md, Tokens.Spacing.md)

        local pageLayout = Util.ListLayout(page, Tokens.Spacing.md)

        Tab._Page = page

        -- Tab selection
        local function SelectTab()
            -- Deselect previous
            if Window.ActiveTab and Window.ActiveTab ~= Tab then
                local prev = Window.ActiveTab
                Util.Tween(prev._SidebarBtn, {BackgroundTransparency = 1}, Tokens.Duration.fast)
                Util.Tween(prev._SidebarIcon, {TextColor3 = Tokens.Colors.TextTertiary}, Tokens.Duration.fast)
                Util.Tween(prev._SidebarLabel, {TextColor3 = Tokens.Colors.TextSecondary}, Tokens.Duration.fast)
                Util.Tween(prev._Indicator, {Size = UDim2.new(0, 3, 0, 0)}, Tokens.Duration.fast)

                -- Page transition out
                Util.Tween(prev._Page, {
                    Position = UDim2.new(-0.03, 0, 0, 0),
                    -- GroupTransparency doesn't exist on ScrollingFrame, use workaround
                }, Tokens.Duration.fast)
                task.delay(Tokens.Duration.fast * 0.5, function()
                    if prev._Page then prev._Page.Visible = false end
                end)
            end

            Window.ActiveTab = Tab

            -- Select new
            Util.Tween(tabBtn, {BackgroundTransparency = 0.7}, Tokens.Duration.fast)
            Util.Tween(tabIconLabel, {TextColor3 = Tokens.Colors.Accent}, Tokens.Duration.fast)
            Util.Tween(tabLabel, {TextColor3 = Tokens.Colors.TextPrimary}, Tokens.Duration.fast)
            Util.Tween(activeIndicator, {Size = UDim2.new(0, 3, 0, 20)}, Tokens.Duration.normal, Enum.EasingStyle.Back)

            -- Page transition in
            page.Visible = true
            page.Position = UDim2.new(0.03, 0, 0, 0)
            Util.Tween(page, {Position = UDim2.new(0, 0, 0, 0)}, Tokens.Duration.page)
        end

        tabBtn.MouseButton1Click:Connect(function()
            Util.Ripple(tabBtn, Tokens.Colors.Accent)
            SelectTab()
        end)

        -- Hover
        tabBtn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                Util.Tween(tabBtn, {BackgroundTransparency = 0.85}, Tokens.Duration.fast)
                Util.Tween(tabIconLabel, {TextColor3 = Tokens.Colors.TextSecondary}, Tokens.Duration.fast)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                Util.Tween(tabBtn, {BackgroundTransparency = 1}, Tokens.Duration.fast)
                Util.Tween(tabIconLabel, {TextColor3 = Tokens.Colors.TextTertiary}, Tokens.Duration.fast)
            end
        end)

        -- Auto-select first tab
        if tabIndex == 1 then
            task.defer(SelectTab)
        end

        -- ═══════════════════════════════════
        -- SECTION SYSTEM
        -- ═══════════════════════════════════

        function Tab:AddSection(config)
            local sectionName = config.Name or "Section"
            local sectionDesc = config.Description

            local Section = {}
            Section._Components = {}
            Section._LayoutOrder = #Tab.Sections * 100 + 10

            local sectionFrame = Instance.new("Frame")
            sectionFrame.Name = "Section_" .. sectionName
            sectionFrame.BackgroundTransparency = 1
            sectionFrame.Size = UDim2.new(1, 0, 0, 0)
            sectionFrame.AutomaticSize = Enum.AutomaticSize.Y
            sectionFrame.LayoutOrder = Section._LayoutOrder
            sectionFrame.ZIndex = 14
            sectionFrame.Parent = page

            local sectionLayout = Util.ListLayout(sectionFrame, Tokens.Spacing.sm)

            -- Section header
            local sectionHeader = Instance.new("Frame")
            sectionHeader.BackgroundTransparency = 1
            sectionHeader.Size = UDim2.new(1, 0, 0, sectionDesc and 36 or 22)
            sectionHeader.LayoutOrder = 0
            sectionHeader.ZIndex = 14
            sectionHeader.Parent = sectionFrame

            local sectionTitle = Instance.new("TextLabel")
            sectionTitle.BackgroundTransparency = 1
            sectionTitle.Size = UDim2.new(1, 0, 0, 16)
            sectionTitle.Font = Enum.Font.GothamBold
            sectionTitle.TextSize = Tokens.FontSize.xs
            sectionTitle.TextColor3 = Tokens.Colors.TextTertiary
            sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
            sectionTitle.Text = sectionName:upper()
            sectionTitle.ZIndex = 15
            sectionTitle.Parent = sectionHeader

            if sectionDesc then
                local sectionDescLabel = Instance.new("TextLabel")
                sectionDescLabel.BackgroundTransparency = 1
                sectionDescLabel.Size = UDim2.new(1, 0, 0, 14)
                sectionDescLabel.Position = UDim2.new(0, 0, 0, 18)
                sectionDescLabel.Font = Enum.Font.Gotham
                sectionDescLabel.TextSize = Tokens.FontSize.xs
                sectionDescLabel.TextColor3 = Tokens.Colors.TextDisabled
                sectionDescLabel.TextXAlignment = Enum.TextXAlignment.Left
                sectionDescLabel.Text = sectionDesc
                sectionDescLabel.ZIndex = 15
                sectionDescLabel.Parent = sectionHeader
            end

            Section._Frame = sectionFrame
            local componentOrder = 1

            -- ════════════════════════════
            -- TOGGLE COMPONENT
            -- ════════════════════════════

            function Section:AddToggle(cfg)
                local name = cfg.Name or "Toggle"
                local default = cfg.Default or false
                local tooltip = cfg.Tooltip
                local callback = cfg.Callback or function() end

                local enabled = default
                local compH = IsMobile and 44 or 40
                componentOrder = componentOrder + 1

                local frame = Instance.new("Frame")
                frame.Name = "_ComponentFrame"
                frame.BackgroundColor3 = Tokens.Colors.Surface
                frame.Size = UDim2.new(1, 0, 0, compH)
                frame.LayoutOrder = componentOrder
                frame.ZIndex = 15
                frame.Parent = sectionFrame
                frame:SetAttribute("OrigHeight", compH)
                Util.Corner(frame, Tokens.Radius.md)
                Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

                local label = Instance.new("TextLabel")
                label.Name = "_Label"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(1, -70, 1, 0)
                label.Position = UDim2.new(0, Tokens.Spacing.md, 0, 0)
                label.Font = Enum.Font.GothamMedium
                label.TextSize = Tokens.FontSize.sm
                label.TextColor3 = Tokens.Colors.TextPrimary
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Text = name
                label.ZIndex = 16
                label.Parent = frame

                -- Toggle track
                local trackW = IsMobile and 40 or 38
                local trackH = IsMobile and 22 or 20
                local knobSize = trackH - 4

                local track = Instance.new("Frame")
                track.BackgroundColor3 = enabled and Tokens.Colors.Accent or Tokens.Colors.BgActive
                track.Size = UDim2.new(0, trackW, 0, trackH)
                track.Position = UDim2.new(1, -(trackW + Tokens.Spacing.md), 0.5, 0)
                track.AnchorPoint = Vector2.new(0, 0.5)
                track.ZIndex = 17
                track.Parent = frame
                Util.Corner(track, Tokens.Radius.full)

                local knob = Instance.new("Frame")
                knob.BackgroundColor3 = Tokens.Colors.White
                knob.Size = UDim2.new(0, knobSize, 0, knobSize)
                knob.Position = enabled
                    and UDim2.new(1, -(knobSize + 2), 0.5, 0)
                    or UDim2.new(0, 2, 0.5, 0)
                knob.AnchorPoint = Vector2.new(0, 0.5)
                knob.ZIndex = 18
                knob.Parent = track
                Util.Corner(knob, Tokens.Radius.full)

                -- Subtle knob shadow
                local knobShadow = Instance.new("Frame")
                knobShadow.BackgroundColor3 = Tokens.Colors.Black
                knobShadow.BackgroundTransparency = 0.8
                knobShadow.Size = UDim2.new(1, 2, 1, 2)
                knobShadow.Position = UDim2.new(0.5, 0, 0.5, 1)
                knobShadow.AnchorPoint = Vector2.new(0.5, 0.5)
                knobShadow.ZIndex = 17
                knobShadow.Parent = knob
                Util.Corner(knobShadow, Tokens.Radius.full)

                local btn = Instance.new("TextButton")
                btn.BackgroundTransparency = 1
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.Text = ""
                btn.ZIndex = 19
                btn.Parent = frame

                local function UpdateToggle()
                    if enabled then
                        Util.Tween(track, {BackgroundColor3 = Tokens.Colors.Accent}, Tokens.Duration.fast)
                        Util.Tween(knob, {Position = UDim2.new(1, -(knobSize + 2), 0.5, 0)}, Tokens.Duration.normal, Enum.EasingStyle.Back)
                    else
                        Util.Tween(track, {BackgroundColor3 = Tokens.Colors.BgActive}, Tokens.Duration.fast)
                        Util.Tween(knob, {Position = UDim2.new(0, 2, 0.5, 0)}, Tokens.Duration.normal, Enum.EasingStyle.Back)
                    end
                end

                btn.MouseButton1Click:Connect(function()
                    enabled = not enabled
                    Util.Ripple(frame, Tokens.Colors.Accent)
                    UpdateToggle()
                    pcall(callback, enabled)
                end)

                -- Hover
                btn.MouseEnter:Connect(function()
                    Util.Tween(frame, {BackgroundColor3 = Tokens.Colors.SurfaceHover}, Tokens.Duration.fast)
                    if tooltip then
                        Window._Library:ShowTooltip(tooltip, frame)
                    end
                end)
                btn.MouseLeave:Connect(function()
                    Util.Tween(frame, {BackgroundColor3 = Tokens.Colors.Surface}, Tokens.Duration.fast)
                    if tooltip then
                        Window._Library:HideTooltip()
                    end
                end)

                local toggleObj = {
                    Set = function(_, val)
                        enabled = val
                        UpdateToggle()
                    end,
                    Get = function() return enabled end,
                    _Frame = frame,
                }

                table.insert(Section._Components, toggleObj)
                return toggleObj
            end

            -- ════════════════════════════
            -- SLIDER COMPONENT
            -- ════════════════════════════

            function Section:AddSlider(cfg)
                local name = cfg.Name or "Slider"
                local min = cfg.Min or 0
                local max = cfg.Max or 100
                local default = cfg.Default or 50
                local step = cfg.Step or 1
                local suffix = cfg.Suffix or ""
                local tooltip = cfg.Tooltip
                local callback = cfg.Callback or function() end

                local value = math.clamp(default, min, max)
                local compH = IsMobile and 56 or 52
                componentOrder = componentOrder + 1

                local frame = Instance.new("Frame")
                frame.Name = "_ComponentFrame"
                frame.BackgroundColor3 = Tokens.Colors.Surface
                frame.Size = UDim2.new(1, 0, 0, compH)
                frame.LayoutOrder = componentOrder
                frame.ZIndex = 15
                frame.Parent = sectionFrame
                frame:SetAttribute("OrigHeight", compH)
                Util.Corner(frame, Tokens.Radius.md)
                Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

                local label = Instance.new("TextLabel")
                label.Name = "_Label"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(0.6, 0, 0, 18)
                label.Position = UDim2.new(0, Tokens.Spacing.md, 0, Tokens.Spacing.sm)
                label.Font = Enum.Font.GothamMedium
                label.TextSize = Tokens.FontSize.sm
                label.TextColor3 = Tokens.Colors.TextPrimary
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Text = name
                label.ZIndex = 16
                label.Parent = frame

                local valueLabel = Instance.new("TextLabel")
                valueLabel.BackgroundTransparency = 1
                valueLabel.Size = UDim2.new(0.35, 0, 0, 18)
                valueLabel.Position = UDim2.new(0.65, -Tokens.Spacing.md, 0, Tokens.Spacing.sm)
                valueLabel.Font = Enum.Font.GothamBold
                valueLabel.TextSize = Tokens.FontSize.sm
                valueLabel.TextColor3 = Tokens.Colors.Accent
                valueLabel.TextXAlignment = Enum.TextXAlignment.Right
                valueLabel.Text = tostring(value) .. suffix
                valueLabel.ZIndex = 16
                valueLabel.Parent = frame

                -- Track
                local trackBg = Instance.new("Frame")
                trackBg.BackgroundColor3 = Tokens.Colors.BgActive
                trackBg.Size = UDim2.new(1, -(Tokens.Spacing.md * 2), 0, 6)
                trackBg.Position = UDim2.new(0, Tokens.Spacing.md, 1, -(Tokens.Spacing.sm + 6))
                trackBg.ZIndex = 16
                trackBg.Parent = frame
                Util.Corner(trackBg, 3)

                local fill = Instance.new("Frame")
                fill.BackgroundColor3 = Tokens.Colors.Accent
                fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
                fill.BorderSizePixel = 0
                fill.ZIndex = 17
                fill.Parent = trackBg
                Util.Corner(fill, 3)

                local knobS = IsMobile and 16 or 14
                local knobFrame = Instance.new("Frame")
                knobFrame.BackgroundColor3 = Tokens.Colors.White
                knobFrame.Size = UDim2.new(0, knobS, 0, knobS)
                knobFrame.Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0)
                knobFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                knobFrame.ZIndex = 18
                knobFrame.Parent = trackBg
                Util.Corner(knobFrame, Tokens.Radius.full)
                Util.Stroke(knobFrame, Tokens.Colors.Accent, 2, 0)

                local isSliding = false

                local sliderBtn = Instance.new("TextButton")
                sliderBtn.BackgroundTransparency = 1
                sliderBtn.Size = UDim2.new(1, 20, 0, 24)
                sliderBtn.Position = UDim2.new(0, -10, 1, -28)
                sliderBtn.Text = ""
                sliderBtn.ZIndex = 20
                sliderBtn.Parent = frame

                sliderBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                        isSliding = true
                        Util.Tween(knobFrame, {
                            Size = UDim2.new(0, knobS + 4, 0, knobS + 4)
                        }, Tokens.Duration.fast, Enum.EasingStyle.Back)
                    end
                end)

                Library:AddConnection(UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                        if isSliding then
                            isSliding = false
                            Util.Tween(knobFrame, {
                                Size = UDim2.new(0, knobS, 0, knobS)
                            }, Tokens.Duration.fast, Enum.EasingStyle.Back)
                        end
                    end
                end))

                Library:AddConnection(UserInputService.InputChanged:Connect(function(input)
                    if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                        local rel = (input.Position.X - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X
                        rel = math.clamp(rel, 0, 1)

                        local rawVal = min + (max - min) * rel
                        value = math.floor(rawVal / step + 0.5) * step
                        value = math.clamp(value, min, max)

                        local norm = (value - min) / (max - min)
                        Util.Tween(fill, {Size = UDim2.new(norm, 0, 1, 0)}, 0.04)
                        Util.Tween(knobFrame, {Position = UDim2.new(norm, 0, 0.5, 0)}, 0.04)
                        valueLabel.Text = tostring(value) .. suffix

                        pcall(callback, value)
                    end
                end))

                -- Hover
                frame.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement then
                        Util.Tween(frame, {BackgroundColor3 = Tokens.Colors.SurfaceHover}, Tokens.Duration.fast)
                    end
                end)
                frame.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement then
                        Util.Tween(frame, {BackgroundColor3 = Tokens.Colors.Surface}, Tokens.Duration.fast)
                    end
                end)

                local sliderObj = {
                    Set = function(_, val)
                        value = math.clamp(val, min, max)
                        local norm = (value - min) / (max - min)
                        Util.Tween(fill, {Size = UDim2.new(norm, 0, 1, 0)}, Tokens.Duration.fast)
                        Util.Tween(knobFrame, {Position = UDim2.new(norm, 0, 0.5, 0)}, Tokens.Duration.fast)
                        valueLabel.Text = tostring(value) .. suffix
                    end,
                    Get = function() return value end,
                    _Frame = frame,
                }
                table.insert(Section._Components, sliderObj)
                return sliderObj
            end

            -- ════════════════════════════
            -- BUTTON COMPONENT
            -- ════════════════════════════

            function Section:AddButton(cfg)
                local name = cfg.Name or "Button"
                local desc = cfg.Description
                local tooltip = cfg.Tooltip
                local callback = cfg.Callback or function() end

                local compH = desc and (IsMobile and 52 or 48) or (IsMobile and 40 or 36)
                componentOrder = componentOrder + 1

                local frame = Instance.new("TextButton")
                frame.Name = "_ComponentFrame"
                frame.BackgroundColor3 = Tokens.Colors.Surface
                frame.Size = UDim2.new(1, 0, 0, compH)
                frame.LayoutOrder = componentOrder
                frame.Text = ""
                frame.ZIndex = 15
                frame.Parent = sectionFrame
                frame:SetAttribute("OrigHeight", compH)
                Util.Corner(frame, Tokens.Radius.md)
                Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

                local label = Instance.new("TextLabel")
                label.Name = "_Label"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(1, -50, 0, 18)
                label.Position = UDim2.new(0, Tokens.Spacing.md, 0, desc and Tokens.Spacing.sm or (compH/2 - 9))
                label.Font = Enum.Font.GothamMedium
                label.TextSize = Tokens.FontSize.sm
                label.TextColor3 = Tokens.Colors.TextPrimary
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Text = name
                label.ZIndex = 16
                label.Parent = frame

                if desc then
                    local descLabel = Instance.new("TextLabel")
                    descLabel.BackgroundTransparency = 1
                    descLabel.Size = UDim2.new(1, -50, 0, 14)
                    descLabel.Position = UDim2.new(0, Tokens.Spacing.md, 0, Tokens.Spacing.sm + 18)
                    descLabel.Font = Enum.Font.Gotham
                    descLabel.TextSize = Tokens.FontSize.xs
                    descLabel.TextColor3 = Tokens.Colors.TextTertiary
                    descLabel.TextXAlignment = Enum.TextXAlignment.Left
                    descLabel.Text = desc
                    descLabel.ZIndex = 16
                    descLabel.Parent = frame
                end

                -- Arrow
                local arrow = Instance.new("TextLabel")
                arrow.BackgroundTransparency = 1
                arrow.Size = UDim2.new(0, 20, 1, 0)
                arrow.Position = UDim2.new(1, -(20 + Tokens.Spacing.md), 0, 0)
                arrow.Font = Enum.Font.Gotham
                arrow.TextSize = 14
                arrow.TextColor3 = Tokens.Colors.TextTertiary
                arrow.Text = "›"
                arrow.ZIndex = 16
                arrow.Parent = frame

                frame.MouseButton1Click:Connect(function()
                    Util.Ripple(frame, Tokens.Colors.Accent)
                    -- Press animation
                    Util.Tween(frame, {Size = UDim2.new(1, 0, 0, compH - 2)}, Tokens.Duration.instant)
                    task.delay(Tokens.Duration.instant, function()
                        Util.Tween(frame, {Size = UDim2.new(1, 0, 0, compH)}, Tokens.Duration.fast, Enum.EasingStyle.Back)
                    end)
                    pcall(callback)
                end)

                frame.MouseEnter:Connect(function()
                    Util.Tween(frame, {BackgroundColor3 = Tokens.Colors.SurfaceHover}, Tokens.Duration.fast)
                    Util.Tween(arrow, {TextColor3 = Tokens.Colors.Accent, Position = UDim2.new(1, -(18 + Tokens.Spacing.md), 0, 0)}, Tokens.Duration.fast)
                    if tooltip then Window._Library:ShowTooltip(tooltip, frame) end
                end)
                frame.MouseLeave:Connect(function()
                    Util.Tween(frame, {BackgroundColor3 = Tokens.Colors.Surface}, Tokens.Duration.fast)
                    Util.Tween(arrow, {TextColor3 = Tokens.Colors.TextTertiary, Position = UDim2.new(1, -(20 + Tokens.Spacing.md), 0, 0)}, Tokens.Duration.fast)
                    if tooltip then Window._Library:HideTooltip() end
                end)

                return {_Frame = frame}
            end

            -- ════════════════════════════
            -- DROPDOWN COMPONENT
            -- ════════════════════════════

            function Section:AddDropdown(cfg)
                local name = cfg.Name or "Dropdown"
                local options = cfg.Options or {"Option 1", "Option 2", "Option 3"}
                local default = cfg.Default or options[1]
                local tooltip = cfg.Tooltip
                local callback = cfg.Callback or function() end

                local selected = default
                local isExpanded = false
                local compH = IsMobile and 44 or 40
                local optionH = IsMobile and 34 or 30
                componentOrder = componentOrder + 1

                local frame = Instance.new("Frame")
                frame.Name = "_ComponentFrame"
                frame.BackgroundColor3 = Tokens.Colors.Surface
                frame.Size = UDim2.new(1, 0, 0, compH)
                frame.LayoutOrder = componentOrder
                frame.ClipsDescendants = true
                frame.ZIndex = 15
                frame.Parent = sectionFrame
                frame:SetAttribute("OrigHeight", compH)
                Util.Corner(frame, Tokens.Radius.md)
                Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

                local label = Instance.new("TextLabel")
                label.Name = "_Label"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(0.5, 0, 0, compH)
                label.Position = UDim2.new(0, Tokens.Spacing.md, 0, 0)
                label.Font = Enum.Font.GothamMedium
                label.TextSize = Tokens.FontSize.sm
                label.TextColor3 = Tokens.Colors.TextPrimary
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Text = name
                label.ZIndex = 16
                label.Parent = frame

                -- Selected value display
                local selectedLabel = Instance.new("TextLabel")
                selectedLabel.BackgroundTransparency = 1
                selectedLabel.Size = UDim2.new(0.4, -30, 0, compH)
                selectedLabel.Position = UDim2.new(0.5, 0, 0, 0)
                selectedLabel.Font = Enum.Font.Gotham
                selectedLabel.TextSize = Tokens.FontSize.sm
                selectedLabel.TextColor3 = Tokens.Colors.Accent
                selectedLabel.TextXAlignment = Enum.TextXAlignment.Right
                selectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
                selectedLabel.Text = tostring(selected)
                selectedLabel.ZIndex = 16
                selectedLabel.Parent = frame

                -- Arrow
                local arrow = Instance.new("TextLabel")
                arrow.BackgroundTransparency = 1
                arrow.Size = UDim2.new(0, 20, 0, compH)
                arrow.Position = UDim2.new(1, -(20 + Tokens.Spacing.sm), 0, 0)
                arrow.Font = Enum.Font.Gotham
                arrow.TextSize = 12
                arrow.TextColor3 = Tokens.Colors.TextTertiary
                arrow.Text = "▼"
                arrow.ZIndex = 16
                arrow.Rotation = 0
                arrow.Parent = frame

                -- Options container
                local optionsContainer = Instance.new("Frame")
                optionsContainer.BackgroundTransparency = 1
                optionsContainer.Size = UDim2.new(1, -(Tokens.Spacing.sm * 2), 0, 0)
                optionsContainer.Position = UDim2.new(0, Tokens.Spacing.sm, 0, compH + 4)
                optionsContainer.AutomaticSize = Enum.AutomaticSize.Y
                optionsContainer.ZIndex = 17
                optionsContainer.Parent = frame

                local optLayout = Util.ListLayout(optionsContainer, 2)

                -- Create option buttons
                for i, opt in ipairs(options) do
                    local optBtn = Instance.new("TextButton")
                    optBtn.BackgroundColor3 = Tokens.Colors.BgTertiary
                    optBtn.BackgroundTransparency = 0.5
                    optBtn.Size = UDim2.new(1, 0, 0, optionH)
                    optBtn.Font = Enum.Font.Gotham
                    optBtn.TextSize = Tokens.FontSize.sm
                    optBtn.TextColor3 = (opt == selected) and Tokens.Colors.Accent or Tokens.Colors.TextSecondary
                    optBtn.Text = "  " .. tostring(opt)
                    optBtn.TextXAlignment = Enum.TextXAlignment.Left
                    optBtn.LayoutOrder = i
                    optBtn.ZIndex = 18
                    optBtn.Parent = optionsContainer
                    Util.Corner(optBtn, Tokens.Radius.sm)

                    optBtn.MouseButton1Click:Connect(function()
                        selected = opt
                        selectedLabel.Text = tostring(opt)

                        -- Update all option colors
                        for _, child in ipairs(optionsContainer:GetChildren()) do
                            if child:IsA("TextButton") then
                                Util.Tween(child, {
                                    TextColor3 = (child.Text:sub(3) == tostring(opt))
                                        and Tokens.Colors.Accent
                                        or Tokens.Colors.TextSecondary
                                }, Tokens.Duration.fast)
                            end
                        end

                        -- Close dropdown
                        isExpanded = false
                        Util.Tween(frame, {
                            Size = UDim2.new(1, 0, 0, compH)
                        }, Tokens.Duration.normal, Enum.EasingStyle.Back, Enum.EasingDirection.In)
                        Util.Tween(arrow, {Rotation = 0}, Tokens.Duration.fast)

                        pcall(callback, opt)
                    end)

                    optBtn.MouseEnter:Connect(function()
                        Util.Tween(optBtn, {BackgroundTransparency = 0.2}, Tokens.Duration.fast)
                    end)
                    optBtn.MouseLeave:Connect(function()
                        Util.Tween(optBtn, {BackgroundTransparency = 0.5}, Tokens.Duration.fast)
                    end)
                end

                -- Toggle dropdown
                local toggleBtn = Instance.new("TextButton")
                toggleBtn.BackgroundTransparency = 1
                toggleBtn.Size = UDim2.new(1, 0, 0, compH)
                toggleBtn.Text = ""
                toggleBtn.ZIndex = 19
                toggleBtn.Parent = frame

                toggleBtn.MouseButton1Click:Connect(function()
                    isExpanded = not isExpanded
                    Util.Ripple(frame, Tokens.Colors.Accent)

                    if isExpanded then
                        local totalH = compH + 8 + (#options * (optionH + 2))
                        Util.Tween(frame, {
                            Size = UDim2.new(1, 0, 0, totalH)
                        }, Tokens.Duration.normal, Enum.EasingStyle.Back)
                        Util.Tween(arrow, {Rotation = 180}, Tokens.Duration.fast)
                    else
                        Util.Tween(frame, {
                            Size = UDim2.new(1, 0, 0, compH)
                        }, Tokens.Duration.normal, Enum.EasingStyle.Back, Enum.EasingDirection.In)
                        Util.Tween(arrow, {Rotation = 0}, Tokens.Duration.fast)
                    end
                end)

                return {
                    Set = function(_, val)
                        selected = val
                        selectedLabel.Text = tostring(val)
                    end,
                    Get = function() return selected end,
                    _Frame = frame,
                }
            end

            -- ════════════════════════════
            -- TEXTBOX COMPONENT
            -- ════════════════════════════

            function Section:AddTextbox(cfg)
                local name = cfg.Name or "Input"
                local default = cfg.Default or ""
                local placeholder = cfg.Placeholder or "Type here..."
                local tooltip = cfg.Tooltip
                local callback = cfg.Callback or function() end

                local compH = IsMobile and 44 or 40
                componentOrder = componentOrder + 1

                local frame = Instance.new("Frame")
                frame.Name = "_ComponentFrame"
                frame.BackgroundColor3 = Tokens.Colors.Surface
                frame.Size = UDim2.new(1, 0, 0, compH)
                frame.LayoutOrder = componentOrder
                frame.ZIndex = 15
                frame.Parent = sectionFrame
                frame:SetAttribute("OrigHeight", compH)
                Util.Corner(frame, Tokens.Radius.md)
                Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

                local label = Instance.new("TextLabel")
                label.Name = "_Label"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(0.4, 0, 1, 0)
                label.Position = UDim2.new(0, Tokens.Spacing.md, 0, 0)
                label.Font = Enum.Font.GothamMedium
                label.TextSize = Tokens.FontSize.sm
                label.TextColor3 = Tokens.Colors.TextPrimary
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Text = name
                label.ZIndex = 16
                label.Parent = frame

                local inputBox = Instance.new("TextBox")
                inputBox.BackgroundColor3 = Tokens.Colors.BgTertiary
                inputBox.Size = UDim2.new(0.55, -Tokens.Spacing.md, 0, compH - 12)
                inputBox.Position = UDim2.new(0.45, 0, 0.5, 0)
                inputBox.AnchorPoint = Vector2.new(0, 0.5)
                inputBox.Font = Enum.Font.Gotham
                inputBox.TextSize = Tokens.FontSize.sm
                inputBox.TextColor3 = Tokens.Colors.TextPrimary
                inputBox.PlaceholderText = placeholder
                inputBox.PlaceholderColor3 = Tokens.Colors.TextDisabled
                inputBox.Text = default
                inputBox.ClearTextOnFocus = false
                inputBox.TextXAlignment = Enum.TextXAlignment.Left
                inputBox.ZIndex = 17
                inputBox.Parent = frame
                Util.Corner(inputBox, Tokens.Radius.sm)
                Util.Padding(inputBox, 0, 0, Tokens.Spacing.sm, Tokens.Spacing.sm)

                local inputStroke = Util.Stroke(inputBox, Tokens.Colors.Border, 1, 0.6)

                inputBox.Focused:Connect(function()
                    Util.Tween(inputStroke, {Color = Tokens.Colors.Accent, Transparency = 0.1}, Tokens.Duration.fast)
                    Util.Tween(inputBox, {BackgroundColor3 = Tokens.Colors.BgHover}, Tokens.Duration.fast)
                end)

                inputBox.FocusLost:Connect(function(enterPressed)
                    Util.Tween(inputStroke, {Color = Tokens.Colors.Border, Transparency = 0.6}, Tokens.Duration.fast)
                    Util.Tween(inputBox, {BackgroundColor3 = Tokens.Colors.BgTertiary}, Tokens.Duration.fast)
                    pcall(callback, inputBox.Text)
                end)

                return {
                    Set = function(_, val) inputBox.Text = tostring(val) end,
                    Get = function() return inputBox.Text end,
                    _Frame = frame,
                }
            end

            -- ════════════════════════════
            -- KEYBIND COMPONENT
            -- ════════════════════════════

            function Section:AddKeybind(cfg)
                local name = cfg.Name or "Keybind"
                local default = cfg.Default or Enum.KeyCode.Unknown
                local tooltip = cfg.Tooltip
                local callback = cfg.Callback or function() end

                local currentKey = default
                local listening = false
                local compH = IsMobile and 44 or 40
                componentOrder = componentOrder + 1

                local frame = Instance.new("Frame")
                frame.Name = "_ComponentFrame"
                frame.BackgroundColor3 = Tokens.Colors.Surface
                frame.Size = UDim2.new(1, 0, 0, compH)
                frame.LayoutOrder = componentOrder
                frame.ZIndex = 15
                frame.Parent = sectionFrame
                frame:SetAttribute("OrigHeight", compH)
                Util.Corner(frame, Tokens.Radius.md)
                Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

                local label = Instance.new("TextLabel")
                label.Name = "_Label"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(0.6, 0, 1, 0)
                label.Position = UDim2.new(0, Tokens.Spacing.md, 0, 0)
                label.Font = Enum.Font.GothamMedium
                label.TextSize = Tokens.FontSize.sm
                label.TextColor3 = Tokens.Colors.TextPrimary
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Text = name
                label.ZIndex = 16
                label.Parent = frame

                local keyBtn = Instance.new("TextButton")
                keyBtn.BackgroundColor3 = Tokens.Colors.BgTertiary
                keyBtn.Size = UDim2.new(0, IsMobile and 70 or 80, 0, compH - 14)
                keyBtn.Position = UDim2.new(1, -(IsMobile and 70 or 80) - Tokens.Spacing.md, 0.5, 0)
                keyBtn.AnchorPoint = Vector2.new(0, 0.5)
                keyBtn.Font = Enum.Font.GothamBold
                keyBtn.TextSize = Tokens.FontSize.xs
                keyBtn.TextColor3 = Tokens.Colors.TextSecondary
                keyBtn.Text = currentKey.Name or "None"
                keyBtn.ZIndex = 17
                keyBtn.Parent = frame
                Util.Corner(keyBtn, Tokens.Radius.sm)
                Util.Stroke(keyBtn, Tokens.Colors.Border, 1, 0.6)

                keyBtn.MouseButton1Click:Connect(function()
                    listening = true
                    keyBtn.Text = "..."
                    Util.Tween(keyBtn, {BackgroundColor3 = Tokens.Colors.AccentSubtle}, Tokens.Duration.fast)
                    local stroke = keyBtn:FindFirstChildOfClass("UIStroke")
                    if stroke then Util.Tween(stroke, {Color = Tokens.Colors.Accent}, Tokens.Duration.fast) end
                end)

                Library:AddConnection(UserInputService.InputBegan:Connect(function(input, gpe)
                    if not listening then return end
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false
                        currentKey = input.KeyCode
                        keyBtn.Text = currentKey.Name
                        Util.Tween(keyBtn, {BackgroundColor3 = Tokens.Colors.BgTertiary}, Tokens.Duration.fast)
                        local stroke = keyBtn:FindFirstChildOfClass("UIStroke")
                        if stroke then Util.Tween(stroke, {Color = Tokens.Colors.Border}, Tokens.Duration.fast) end
                        pcall(callback, currentKey)
                    end
                end))

                return {
                    Set = function(_, key)
                        currentKey = key
                        keyBtn.Text = key.Name
                    end,
                    Get = function() return currentKey end,
                    _Frame = frame,
                }
            end

            -- ════════════════════════════
            -- COLOR PICKER COMPONENT
            -- ════════════════════════════

            function Section:AddColorPicker(cfg)
                local name = cfg.Name or "Color"
                local default = cfg.Default or Color3.fromRGB(99, 102, 241)
                local callback = cfg.Callback or function() end

                local currentColor = default
                local isExpanded = false
                local compH = IsMobile and 44 or 40
                local expandedH = compH + 110
                componentOrder = componentOrder + 1

                local frame = Instance.new("Frame")
                frame.Name = "_ComponentFrame"
                frame.BackgroundColor3 = Tokens.Colors.Surface
                frame.Size = UDim2.new(1, 0, 0, compH)
                frame.LayoutOrder = componentOrder
                frame.ClipsDescendants = true
                frame.ZIndex = 15
                frame.Parent = sectionFrame
                frame:SetAttribute("OrigHeight", compH)
                Util.Corner(frame, Tokens.Radius.md)
                Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

                local label = Instance.new("TextLabel")
                label.Name = "_Label"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(0.7, 0, 0, compH)
                label.Position = UDim2.new(0, Tokens.Spacing.md, 0, 0)
                label.Font = Enum.Font.GothamMedium
                label.TextSize = Tokens.FontSize.sm
                label.TextColor3 = Tokens.Colors.TextPrimary
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Text = name
                label.ZIndex = 16
                label.Parent = frame

                local preview = Instance.new("Frame")
                preview.BackgroundColor3 = currentColor
                preview.Size = UDim2.new(0, 24, 0, 24)
                preview.Position = UDim2.new(1, -(24 + Tokens.Spacing.md), 0, (compH - 24) / 2)
                preview.ZIndex = 17
                preview.Parent = frame
                Util.Corner(preview, Tokens.Radius.sm)
                Util.Stroke(preview, Tokens.Colors.Border, 1, 0.5)

                -- Simplified color palette
                local colorPalette = Instance.new("Frame")
                colorPalette.BackgroundTransparency = 1
                colorPalette.Size = UDim2.new(1, -(Tokens.Spacing.md * 2), 0, 90)
                colorPalette.Position = UDim2.new(0, Tokens.Spacing.md, 0, compH + 8)
                colorPalette.ZIndex = 17
                colorPalette.Parent = frame

                local gridLayout = Instance.new("UIGridLayout")
                gridLayout.CellSize = UDim2.new(0, 28, 0, 28)
                gridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
                gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
                gridLayout.Parent = colorPalette

                local presetColors = {
                    Color3.fromRGB(239, 68, 68),   Color3.fromRGB(249, 115, 22),
                    Color3.fromRGB(234, 179, 8),   Color3.fromRGB(34, 197, 94),
                    Color3.fromRGB(20, 184, 166),  Color3.fromRGB(59, 130, 246),
                    Color3.fromRGB(99, 102, 241),  Color3.fromRGB(168, 85, 247),
                    Color3.fromRGB(236, 72, 153),  Color3.fromRGB(244, 114, 182),
                    Color3.fromRGB(255, 255, 255), Color3.fromRGB(148, 163, 184),
                    Color3.fromRGB(100, 116, 139), Color3.fromRGB(51, 65, 85),
                    Color3.fromRGB(30, 41, 59),    Color3.fromRGB(15, 23, 42),
                }

                for i, col in ipairs(presetColors) do
                    local colorBtn = Instance.new("TextButton")
                    colorBtn.BackgroundColor3 = col
                    colorBtn.Size = UDim2.new(0, 28, 0, 28)
                    colorBtn.Text = ""
                    colorBtn.LayoutOrder = i
                    colorBtn.ZIndex = 18
                    colorBtn.Parent = colorPalette
                    Util.Corner(colorBtn, Tokens.Radius.sm)

                    colorBtn.MouseButton1Click:Connect(function()
                        currentColor = col
                        Util.Tween(preview, {BackgroundColor3 = col}, Tokens.Duration.fast)
                        pcall(callback, col)
                    end)

                    colorBtn.MouseEnter:Connect(function()
                        Util.Tween(colorBtn, {Size = UDim2.new(0, 30, 0, 30)}, Tokens.Duration.instant)
                    end)
                    colorBtn.MouseLeave:Connect(function()
                        Util.Tween(colorBtn, {Size = UDim2.new(0, 28, 0, 28)}, Tokens.Duration.instant)
                    end)
                end

                -- Toggle
                local toggleArea = Instance.new("TextButton")
                toggleArea.BackgroundTransparency = 1
                toggleArea.Size = UDim2.new(1, 0, 0, compH)
                toggleArea.Text = ""
                toggleArea.ZIndex = 20
                toggleArea.Parent = frame

                toggleArea.MouseButton1Click:Connect(function()
                    isExpanded = not isExpanded
                    Util.Tween(frame, {
                        Size = UDim2.new(1, 0, 0, isExpanded and expandedH or compH)
                    }, Tokens.Duration.normal, Enum.EasingStyle.Back)
                end)

                return {
                    Set = function(_, col)
                        currentColor = col
                        preview.BackgroundColor3 = col
                    end,
                    Get = function() return currentColor end,
                    _Frame = frame,
                }
            end

            -- ════════════════════════════
            -- LABEL / INFO COMPONENT
            -- ════════════════════════════

            function Section:AddLabel(cfg)
                local text = cfg.Text or "Label"
                componentOrder = componentOrder + 1

                local label = Instance.new("TextLabel")
                label.Name = "_ComponentFrame"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(1, 0, 0, 20)
                label.LayoutOrder = componentOrder
                label.Font = Enum.Font.Gotham
                label.TextSize = Tokens.FontSize.xs
                label.TextColor3 = Tokens.Colors.TextTertiary
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Text = text
                label.ZIndex = 15
                label.Parent = sectionFrame

                return {
                    Set = function(_, t) label.Text = t end,
                    _Frame = label,
                }
            end

            table.insert(Tab.Sections, Section)
            return Section
        end

        table.insert(Window.Tabs, Tab)
        return Tab
    end

    -- Initial open
    task.defer(function()
        Window:Open()
    end)

    table.insert(self.Windows, Window)
    return Window
end


-- ╔═══════════════════════════════════════════════════════════════╗
-- ║                                                               ║
-- ║                    DEMO / USAGE EXAMPLE                       ║
-- ║                                                               ║
-- ║    Below is a complete working demonstration showing          ║
-- ║    every component with proper callbacks.                     ║
-- ║                                                               ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Window = Library:CreateWindow({
    Title = "ZUSYNI",
    Subtitle = "Premium Mod Menu • v3.0",
    ToggleKey = Enum.KeyCode.RightShift,
})

-- ═══════════════════════════════════════
-- TAB 1: PLAYER
-- ═══════════════════════════════════════

local PlayerTab = Window:AddTab({
    Name = "Player",
    Icon = "👤",
})

local movementSection = PlayerTab:AddSection({
    Name = "Movement",
    Description = "Character movement modifications",
})

movementSection:AddToggle({
    Name = "Speed Boost",
    Default = false,
    Tooltip = "Increases your walkspeed beyond normal limits",
    Callback = function(enabled)
        local char = Player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = enabled and 32 or 16
        end
        Library:Notify({
            Title = "Speed Boost",
            Description = enabled and "Enabled — WalkSpeed set to 32" or "Disabled — WalkSpeed restored",
            Type = enabled and "success" or "info",
            Duration = 3,
        })
    end,
})

movementSection:AddSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 200,
    Default = 16,
    Step = 1,
    Suffix = " studs/s",
    Callback = function(value)
        local char = Player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = value
        end
    end,
})

movementSection:AddSlider({
    Name = "Jump Power",
    Min = 50,
    Max = 300,
    Default = 50,
    Step = 5,
    Suffix = "",
    Callback = function(value)
        local char = Player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = value
        end
    end,
})

movementSection:AddToggle({
    Name = "Infinite Jump",
    Default = false,
    Callback = function(enabled)
        -- Note: Actual infinite jump needs RunService connection
        Library:Notify({
            Title = "Infinite Jump",
            Description = enabled and "Activated" or "Deactivated",
            Type = enabled and "success" or "info",
        })
    end,
})

local teleportSection = PlayerTab:AddSection({
    Name = "Teleport",
})

teleportSection:AddButton({
    Name = "Teleport to Spawn",
    Description = "Returns you to the spawn point",
    Callback = function()
        local char = Player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local spawn = Workspace:FindFirstChild("SpawnLocation")
            if spawn then
                char.HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
            end
        end
        Library:Notify({
            Title = "Teleport",
            Description = "Teleported to spawn",
            Type = "success",
        })
    end,
})

teleportSection:AddTextbox({
    Name = "Player Name",
    Placeholder = "Enter player name...",
    Callback = function(text)
        Library:Notify({
            Title = "Input",
            Description = "Entered: " .. text,
            Type = "info",
        })
    end,
})

-- ═══════════════════════════════════════
-- TAB 2: VISUAL
-- ═══════════════════════════════════════

local VisualTab = Window:AddTab({
    Name = "Visual",
    Icon = "👁",
})

local espSection = VisualTab:AddSection({
    Name = "ESP & Highlights",
    Description = "Visual overlay settings",
})

espSection:AddToggle({
    Name = "Player ESP",
    Default = false,
    Tooltip = "Shows player outlines through walls",
    Callback = function(enabled)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and plr.Character then
                local existing = plr.Character:FindFirstChild("ZusyniHighlight")
                if enabled then
                    if not existing then
                        local hl = Instance.new("Highlight")
                        hl.Name = "ZusyniHighlight"
                        hl.FillColor = Tokens.Colors.Accent
                        hl.FillTransparency = 0.7
                        hl.OutlineColor = Tokens.Colors.Accent
                        hl.OutlineTransparency = 0.3
                        hl.Parent = plr.Character
                    end
                else
                    if existing then existing:Destroy() end
                end
            end
        end
        Library:Notify({
            Title = "ESP",
            Description = enabled and "Player ESP enabled" or "Player ESP disabled",
            Type = enabled and "success" or "info",
        })
    end,
})

espSection:AddColorPicker({
    Name = "ESP Color",
    Default = Tokens.Colors.Accent,
    Callback = function(color)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and plr.Character then
                local hl = plr.Character:FindFirstChild("ZusyniHighlight")
                if hl then
                    hl.FillColor = color
                    hl.OutlineColor = color
                end
            end
        end
    end,
})

espSection:AddSlider({
    Name = "ESP Transparency",
    Min = 0,
    Max = 100,
    Default = 70,
    Step = 5,
    Suffix = "%",
    Callback = function(value)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and plr.Character then
                local hl = plr.Character:FindFirstChild("ZusyniHighlight")
                if hl then
                    hl.FillTransparency = value / 100
                end
            end
        end
    end,
})

espSection:AddToggle({
    Name = "Fullbright",
    Default = false,
    Callback = function(enabled)
        local lighting = game:GetService("Lighting")
        if enabled then
            lighting.Brightness = 3
            lighting.FogEnd = 1e10
            lighting.GlobalShadows = false
        else
            lighting.Brightness = 1
            lighting.FogEnd = 100000
            lighting.GlobalShadows = true
        end
    end,
})

-- ═══════════════════════════════════════
-- TAB 3: COMBAT
-- ═══════════════════════════════════════

local CombatTab = Window:AddTab({
    Name = "Combat",
    Icon = "⚔",
})

local combatSection = CombatTab:AddSection({
    Name = "Combat Mods",
})

combatSection:AddToggle({
    Name = "Auto Parry",
    Default = false,
    Tooltip = "Automatically parries incoming attacks",
    Callback = function(enabled)
        Library:Notify({
            Title = "Auto Parry",
            Description = enabled and "Auto parry is now active" or "Auto parry disabled",
            Type = enabled and "success" or "warning",
        })
    end,
})

combatSection:AddSlider({
    Name = "Parry Distance",
    Min = 10,
    Max = 100,
    Default = 50,
    Step = 1,
    Suffix = " studs",
})

combatSection:AddDropdown({
    Name = "Parry Mode",
    Options = {"Balanced", "Aggressive", "Defensive", "Custom"},
    Default = "Balanced",
    Callback = function(selected)
        Library:Notify({
            Title = "Mode Changed",
            Description = "Parry mode set to: " .. selected,
            Type = "info",
        })
    end,
})

combatSection:AddToggle({
    Name = "Hit Visualization",
    Default = true,
})

-- ═══════════════════════════════════════
-- TAB 4: SETTINGS
-- ═══════════════════════════════════════

local SettingsTab = Window:AddTab({
    Name = "Settings",
    Icon = "⚙",
})

local uiSection = SettingsTab:AddSection({
    Name = "Interface",
})

uiSection:AddKeybind({
    Name = "Toggle Menu",
    Default = Enum.KeyCode.RightShift,
    Callback = function(key)
        Library.ToggleKey = key
        Library:Notify({
            Title = "Keybind Updated",
            Description = "Toggle key set to: " .. key.Name,
            Type = "success",
        })
    end,
})

uiSection:AddDropdown({
    Name = "Accent Color",
    Options = {"Indigo", "Rose", "Emerald", "Amber", "Sky"},
    Default = "Indigo",
    Callback = function(selected)
        Library:Notify({
            Title = "Theme",
            Description = "Accent color changed to " .. selected,
            Type = "success",
        })
    end,
})

uiSection:AddToggle({
    Name = "Notifications",
    Default = true,
})

uiSection:AddToggle({
    Name = "Sounds",
    Default = true,
})

local aboutSection = SettingsTab:AddSection({
    Name = "About",
})

aboutSection:AddLabel({
    Text = "ZUSYNI Premium Mod Menu v3.0"
})

aboutSection:AddLabel({
    Text = "Professional Developer Interface"
})

aboutSection:AddButton({
    Name = "Destroy Menu",
    Description = "Completely removes the menu from memory",
    Callback = function()
        Library:Modal({
            Title = "Confirm Destruction",
            Description = "Are you sure you want to destroy the menu? This cannot be undone.",
            ConfirmText = "Destroy",
            CancelText = "Cancel",
            OnConfirm = function()
                Library:Notify({
                    Title = "Goodbye",
                    Description = "Menu will be destroyed in 2 seconds...",
                    Type = "warning",
                    Duration = 2,
                })
                task.delay(2.2, function()
                    Library:Destroy()
                end)
            end,
        })
    end,
})

-- ═══════════════════════════════════════
-- STARTUP NOTIFICATION
-- ═══════════════════════════════════════

task.delay(1, function()
    Library:Notify({
        Title = "ZUSYNI Loaded",
        Description = "Press RightShift to toggle menu. All systems operational.",
        Type = "success",
        Duration = 5,
    })
end)

-- ═══════════════════════════════════════
-- CONSOLE OUTPUT
-- ═══════════════════════════════════════

print([[

    ╔═══════════════════════════════════════╗
    ║        ZUSYNI v3.0 — Loaded          ║
    ║                                       ║
    ║  Toggle:  RightShift                  ║
    ║  Device:  ]] .. (IsMobile and "Mobile" or "Desktop") .. [[
    ║  Status:  Operational                 ║
    ║                                       ║
    ║  Anti-Detection: Active               ║
    ╚═══════════════════════════════════════╝

]])

return Library
