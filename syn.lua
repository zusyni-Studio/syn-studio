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
║   ZUSYNI Ultra Premium v3.0                                  ║
║   + SYN-STUDIO Auto Parry Engine (Integrated)                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════
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
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = Workspace.CurrentCamera

-- ══════════════════════════════════════════════
-- ANTI-DETECTION SYSTEM
-- ══════════════════════════════════════════════
local AntiDetect = {}

AntiDetect.Init = function()
    pcall(function()
        if getconnections then
            for _, conn in ipairs(getconnections(Player.Idled)) do
                conn:Disable()
            end
        end
    end)

    pcall(function()
        if hookmetamethod and getrawmetatable then
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            local oldIndex = mt.__index

            if setreadonly then setreadonly(mt, false) end

            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}

                if method == "FindFirstChild" or method == "FindFirstChildOfClass" then
                    if args[1] and type(args[1]) == "string" then
                        if args[1]:find("ZUSYNI") or args[1]:find("ZusyniLib") then
                            return nil
                        end
                    end
                end

                if method == "Kick" and self == Player then
                    return nil
                end

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
                if self == CoreGui and key == "ZUSYNI_Premium" then
                    return nil
                end
                return oldIndex(self, key)
            end)

            if setreadonly then setreadonly(mt, true) end
        end
    end)

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

    pcall(function()
        if hookfunction then
            local oldFireServer = Instance.new("RemoteEvent").FireServer
            hookfunction(oldFireServer, newcclosure(function(self, ...)
                if self and self:IsA("RemoteEvent") then
                    local name = self.Name:lower()
                    local blocked = {
                        "anticheat","anti_cheat","detection","security",
                        "validate","verify","checker","monitor",
                        "report","flag","suspicious","exploit"
                    }
                    for _, pattern in ipairs(blocked) do
                        if name:find(pattern) then return nil end
                    end
                end
                return oldFireServer(self, ...)
            end))
        end
    end)
end

pcall(AntiDetect.Init)

-- ══════════════════════════════════════════════
-- DEVICE DETECTION
-- ══════════════════════════════════════════════
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

-- ══════════════════════════════════════════════
-- DESIGN TOKENS
-- ══════════════════════════════════════════════
local Tokens = {
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

        Accent         = Color3.fromRGB(99, 102, 241),
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

    Spacing = {xs=4, sm=8, md=12, lg=16, xl=20, xxl=24, xxxl=32},
    Radius = {sm=6, md=8, lg=10, xl=12, xxl=16, full=999},
    FontSize = {xs=10, sm=11, md=12, lg=14, xl=16, xxl=18, title=20, hero=24},
    Duration = {instant=0.08, fast=0.15, normal=0.25, slow=0.35, page=0.3},

    Sidebar = {
        ExpandedWidth = IsMobile and 50 or 160,
        CollapsedWidth = IsMobile and 42 or 48,
    },
}

-- ══════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ══════════════════════════════════════════════
local Util = {}

function Util.Tween(obj, props, duration, style, direction)
    if not obj or not obj.Parent then return end
    local tween = TweenService:Create(obj,
        TweenInfo.new(duration or Tokens.Duration.normal, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
        props)
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
    Util.Tween(ripple, {Size = UDim2.new(0, maxDim, 0, maxDim), BackgroundTransparency = 1}, 0.5)
    task.delay(0.5, function() if ripple and ripple.Parent then ripple:Destroy() end end)
end

function Util.GenerateId()
    return HttpService:GenerateGUID(false):sub(1, 8)
end

-- ══════════════════════════════════════════════
-- LIBRARY CORE
-- ══════════════════════════════════════════════
local Library = {}
Library.__index = Library
Library.Windows = {}
Library.Connections = {}
Library.Tweens = {}
Library.ToggleKey = Enum.KeyCode.RightShift

function Library:AddConnection(conn)
    table.insert(self.Connections, conn)
    return conn
end

function Library:Destroy()
    for _, conn in ipairs(self.Connections) do pcall(function() conn:Disconnect() end) end
    for _, tween in ipairs(self.Tweens) do pcall(function() tween:Cancel() end) end
    if self._ScreenGui then pcall(function() self._ScreenGui:Destroy() end) end
    table.clear(self.Connections)
    table.clear(self.Tweens)
    table.clear(self.Windows)
end

function Library:_InitGui()
    if self._ScreenGui then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "ZUSYNI_Premium"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999
    sg.IgnoreGuiInset = true
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(sg) end
        sg.Parent = CoreGui
    end)
    if not sg.Parent then
        pcall(function() sg.Parent = Player:WaitForChild("PlayerGui") end)
    end
    self._ScreenGui = sg
    return sg
end

-- ══════════════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ══════════════════════════════════════════════
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
    local nType = config.Type or "info"

    local accentColor = Tokens.Colors.Info
    local icon = "i"
    if nType == "success" then accentColor = Tokens.Colors.Success; icon = "✓"
    elseif nType == "warning" then accentColor = Tokens.Colors.Warning; icon = "!"
    elseif nType == "error" then accentColor = Tokens.Colors.Error; icon = "✕" end

    local notifW = IsMobile and 260 or 320

    local container = Instance.new("Frame")
    container.Name = "Notif_"..Util.GenerateId()
    container.BackgroundColor3 = Tokens.Colors.BgElevated
    container.Size = UDim2.new(0, notifW, 0, 0)
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.ClipsDescendants = true
    container.ZIndex = 101
    container.Parent = self._NotifHolder
    Util.Corner(container, Tokens.Radius.lg)
    Util.Stroke(container, Tokens.Colors.Border, 1, 0.5)
    Util.Shadow(container, 30, 0.7)

    local accent = Instance.new("Frame")
    accent.BackgroundColor3 = accentColor
    accent.Size = UDim2.new(0, 3, 1, 0)
    accent.BorderSizePixel = 0
    accent.ZIndex = 102
    accent.Parent = container

    local inner = Instance.new("Frame")
    inner.BackgroundTransparency = 1
    inner.Size = UDim2.new(1, -12, 0, 0)
    inner.Position = UDim2.new(0, 12, 0, 0)
    inner.AutomaticSize = Enum.AutomaticSize.Y
    inner.ZIndex = 102
    inner.Parent = container
    Util.Padding(inner, Tokens.Spacing.md, Tokens.Spacing.md, Tokens.Spacing.sm, Tokens.Spacing.md)
    Util.ListLayout(inner, Tokens.Spacing.xs)

    local headerRow = Instance.new("Frame")
    headerRow.BackgroundTransparency = 1
    headerRow.Size = UDim2.new(1, 0, 0, 18)
    headerRow.LayoutOrder = 1
    headerRow.ZIndex = 103
    headerRow.Parent = inner

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

    container.Position = UDim2.new(1, 50, 0, 0)
    container.BackgroundTransparency = 0.5
    Util.Tween(container, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0}, Tokens.Duration.normal)
    Util.Tween(progressFill, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)

    local function closeNotif()
        Util.Tween(container, {Position = UDim2.new(1, 50, 0, 0), BackgroundTransparency = 1}, Tokens.Duration.fast)
        task.delay(Tokens.Duration.fast + 0.05, function()
            if container and container.Parent then container:Destroy() end
        end)
    end
    closeBtn.MouseButton1Click:Connect(closeNotif)
    task.delay(duration, closeNotif)
end

-- ══════════════════════════════════════════════
-- MODAL SYSTEM
-- ══════════════════════════════════════════════
function Library:Modal(config)
    local title = config.Title or "Confirm"
    local desc = config.Description or ""
    local confirmText = config.ConfirmText or "Confirm"
    local cancelText = config.CancelText or "Cancel"
    local onConfirm = config.OnConfirm
    local onCancel = config.OnCancel

    local overlay = Instance.new("TextButton")
    overlay.Name = "ModalOverlay"
    overlay.BackgroundColor3 = Tokens.Colors.Overlay
    overlay.BackgroundTransparency = 1
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Text = ""
    overlay.ZIndex = 150
    overlay.Parent = self._ScreenGui
    Util.Tween(overlay, {BackgroundTransparency = 0.5}, Tokens.Duration.normal)

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

    local cancelBtnM = Instance.new("TextButton")
    cancelBtnM.BackgroundColor3 = Tokens.Colors.BgTertiary
    cancelBtnM.Size = UDim2.new(0.48, 0, 1, 0)
    cancelBtnM.Font = Enum.Font.GothamMedium
    cancelBtnM.TextSize = Tokens.FontSize.sm
    cancelBtnM.TextColor3 = Tokens.Colors.TextSecondary
    cancelBtnM.Text = cancelText
    cancelBtnM.LayoutOrder = 1
    cancelBtnM.ZIndex = 153
    cancelBtnM.Parent = btnRow
    Util.Corner(cancelBtnM, Tokens.Radius.md)

    local confirmBtnM = Instance.new("TextButton")
    confirmBtnM.BackgroundColor3 = Tokens.Colors.Accent
    confirmBtnM.Size = UDim2.new(0.48, 0, 1, 0)
    confirmBtnM.Font = Enum.Font.GothamBold
    confirmBtnM.TextSize = Tokens.FontSize.sm
    confirmBtnM.TextColor3 = Tokens.Colors.White
    confirmBtnM.Text = confirmText
    confirmBtnM.LayoutOrder = 2
    confirmBtnM.ZIndex = 153
    confirmBtnM.Parent = btnRow
    Util.Corner(confirmBtnM, Tokens.Radius.md)

    card.BackgroundTransparency = 0.5
    Util.Tween(card, {BackgroundTransparency = 0}, Tokens.Duration.normal, Enum.EasingStyle.Back)

    cancelBtnM.MouseButton1Click:Connect(function() Util.Ripple(cancelBtnM); closeModal(); if onCancel then onCancel() end end)
    confirmBtnM.MouseButton1Click:Connect(function() Util.Ripple(confirmBtnM, Tokens.Colors.Accent); closeModal(); if onConfirm then onConfirm() end end)
    overlay.MouseButton1Click:Connect(function() closeModal(); if onCancel then onCancel() end end)
end

-- ══════════════════════════════════════════════
-- TOOLTIP SYSTEM
-- ══════════════════════════════════════════════
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
    local absPos = refObj.AbsolutePosition
    local absSize = refObj.AbsoluteSize
    local x = absPos.X + absSize.X + 8
    local y = absPos.Y + absSize.Y / 2
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

-- ══════════════════════════════════════════════════════════════════
-- ██████╗  █████╗ ██████╗ ██████╗ ██╗   ██╗
-- ██╔══██╗██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝
-- ██████╔╝███████║██████╔╝██████╔╝ ╚████╔╝
-- ██╔═══╝ ██╔══██║██╔══██╗██╔══██╗  ╚██╔╝
-- ██║     ██║  ██║██║  ██║██║  ██║   ██║
-- ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
--
-- AUTO PARRY ENGINE — COMPLETE BLADE BALL SYSTEM
-- ══════════════════════════════════════════════════════════════════

local ParryEngine = {
    Enabled = false,
    SmartTiming = true,
    PredictionEnabled = true,
    VisualEffects = true,
    BallESP = true,
    SoundEffects = true,

    BaseParryDistance = 55,
    MinParryDistance = 15,
    MaxParryDistance = 85,
    SpeedMultiplier = 1.0,

    -- Stats
    ParryCount = 0,
    TotalAttempts = 0,
    CurrentBallSpeed = 0,
    LastParryTick = 0,
    ParryDebounce = false,

    -- Ball tracking
    BallTracker = {
        lastPosition = nil,
        lastTime = nil,
        calculatedSpeed = 0,
        positions = {}, -- Rolling buffer for prediction
    },

    -- Connections
    _Connections = {},
    _ESP = nil,
    _HeartbeatConn = nil,
    _BackupConn = nil,
    _ParryRemote = nil,  -- Cached remote
}

-- ═══════════════════════════════════════
-- FIND THE BALL
-- ═══════════════════════════════════════
function ParryEngine:FindBall()
    -- Method 1: Direct name search in Workspace children
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name == "ball" or name == "bladeball" or name == "blade_ball" then
                return obj
            end
        end
        if obj:IsA("Model") then
            local name = obj.Name:lower()
            if name == "ball" or name == "bladeball" or name == "blade_ball" then
                local part = obj:FindFirstChildWhichIsA("BasePart")
                if part then return part end
            end
        end
    end

    -- Method 2: Common folder structures
    local searchFolders = {
        Workspace:FindFirstChild("Balls"),
        Workspace:FindFirstChild("GameObjects"),
        Workspace:FindFirstChild("Assets"),
        Workspace:FindFirstChild("Game"),
        Workspace:FindFirstChild("BladeBall"),
    }
    for _, folder in ipairs(searchFolders) do
        if folder then
            for _, child in ipairs(folder:GetDescendants()) do
                if child:IsA("BasePart") then
                    local name = child.Name:lower()
                    if name == "ball" or name:find("blade") or name:find("ball") then
                        return child
                    end
                end
            end
        end
    end

    -- Method 3: Deep descendant search (fallback, heavier)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:IsDescendantOf(Player.Character or Instance.new("Folder")) then
            local name = obj.Name:lower()
            if name == "ball" or name == "bladeball" then
                return obj
            end
        end
    end

    return nil
end

-- ═══════════════════════════════════════
-- FIND PARRY REMOTE (CACHED)
-- ═══════════════════════════════════════
function ParryEngine:FindParryRemote()
    if self._ParryRemote and self._ParryRemote.Parent then
        return self._ParryRemote
    end

    -- Search patterns (priority order)
    local searchPatterns = {"parry", "deflect", "block", "hit", "swing", "click", "attack"}

    -- Search in Remotes folder first
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
        or ReplicatedStorage:FindFirstChild("RemoteEvents")
        or ReplicatedStorage:FindFirstChild("Events")
        or ReplicatedStorage:FindFirstChild("Network")

    local function searchIn(parent)
        if not parent then return nil end
        for _, remote in ipairs(parent:GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                local name = remote.Name:lower()
                for _, pattern in ipairs(searchPatterns) do
                    if name:find(pattern) then
                        self._ParryRemote = remote
                        return remote
                    end
                end
            end
        end
        return nil
    end

    -- Priority search
    local found = searchIn(remotesFolder) or searchIn(ReplicatedStorage)
    return found
end

-- ═══════════════════════════════════════
-- CHECK IF PLAYER IS TARGETED (RED OUTLINE)
-- ═══════════════════════════════════════
function ParryEngine:IsTargeted()
    local char = Player.Character
    if not char then return false end

    -- Check Highlights (red outline/fill)
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("Highlight") then
            local fillR, fillG, fillB = v.FillColor.R, v.FillColor.G, v.FillColor.B
            local outR, outG, outB = v.OutlineColor.R, v.OutlineColor.G, v.OutlineColor.B
            -- Red detection (R > 0.7, G < 0.3, B < 0.3)
            if (fillR > 0.7 and fillG < 0.3 and fillB < 0.3) or
               (outR > 0.7 and outG < 0.3 and outB < 0.3) then
                return true
            end
        end
        if v:IsA("SelectionBox") or v:IsA("SelectionSphere") then
            local r, g, b = v.Color3.R, v.Color3.G, v.Color3.B
            if r > 0.7 and g < 0.3 and b < 0.3 then
                return true
            end
        end
    end

    -- Check ball attributes for target
    local ball = self:FindBall()
    if ball then
        local target = ball:GetAttribute("Target")
            or ball:GetAttribute("target")
            or ball:GetAttribute("CurrentTarget")
            or ball:GetAttribute("TargetPlayer")

        if target then
            if target == Player.Name or target == Player.UserId or target == tostring(Player.UserId) then
                return true
            end
        end

        -- Check ObjectValue children
        for _, child in ipairs(ball:GetChildren()) do
            if child:IsA("ObjectValue") then
                local name = child.Name:lower()
                if name:find("target") or name:find("player") then
                    if child.Value == char or child.Value == Player then
                        return true
                    end
                end
            end
            if child:IsA("StringValue") then
                if child.Value == Player.Name then
                    return true
                end
            end
        end
    end

    return false
end

-- ═══════════════════════════════════════
-- CALCULATE BALL SPEED (MULTI-METHOD)
-- ═══════════════════════════════════════
function ParryEngine:CalculateBallSpeed(ball)
    local now = tick()
    local ballPos = ball.Position

    -- Method 1: Use Velocity property
    local velocitySpeed = 0
    pcall(function()
        if ball.Velocity then
            velocitySpeed = ball.Velocity.Magnitude
        end
    end)

    -- Method 2: Calculate from position delta
    local deltaSpeed = 0
    if self.BallTracker.lastPosition and self.BallTracker.lastTime then
        local dt = now - self.BallTracker.lastTime
        if dt > 0 and dt < 1 then  -- Sanity check
            local dist = (ballPos - self.BallTracker.lastPosition).Magnitude
            deltaSpeed = dist / dt
        end
    end

    -- Method 3: Rolling average from position buffer
    table.insert(self.BallTracker.positions, {pos = ballPos, time = now})
    if #self.BallTracker.positions > 10 then
        table.remove(self.BallTracker.positions, 1)
    end

    local avgSpeed = 0
    if #self.BallTracker.positions >= 3 then
        local first = self.BallTracker.positions[1]
        local last = self.BallTracker.positions[#self.BallTracker.positions]
        local timeDiff = last.time - first.time
        if timeDiff > 0 then
            avgSpeed = (last.pos - first.pos).Magnitude / timeDiff
        end
    end

    -- Update tracker
    self.BallTracker.lastPosition = ballPos
    self.BallTracker.lastTime = now

    -- Use the most reliable speed measurement
    local speed = math.max(velocitySpeed, deltaSpeed)
    if speed < 1 then speed = avgSpeed end

    self.BallTracker.calculatedSpeed = speed
    self.CurrentBallSpeed = speed

    return speed
end

-- ═══════════════════════════════════════
-- CALCULATE OPTIMAL PARRY DISTANCE
-- ═══════════════════════════════════════
function ParryEngine:CalculateOptimalDistance(speed)
    local base = self.BaseParryDistance

    -- Speed-adaptive factor
    -- Fast ball (>200) → parry at 1.5x+ distance
    -- Slow ball (<50)  → parry at 0.6x distance
    local speedFactor
    if speed > 300 then
        speedFactor = 2.0
    elseif speed > 200 then
        speedFactor = 1.5
    elseif speed > 100 then
        speedFactor = 1.2
    elseif speed > 50 then
        speedFactor = 1.0
    else
        speedFactor = 0.6
    end

    local optimal = base * speedFactor * self.SpeedMultiplier
    return math.clamp(optimal, self.MinParryDistance, self.MaxParryDistance)
end

-- ═══════════════════════════════════════
-- PREDICT BALL TRAJECTORY
-- ═══════════════════════════════════════
function ParryEngine:PredictTimeToReach(ball, hrp)
    local distance = (ball.Position - hrp.Position).Magnitude
    local speed = self.CurrentBallSpeed

    if speed < 0.1 then return 999 end

    -- Simple time = distance / speed
    local baseTime = distance / speed

    -- Account for ball acceleration (balls often speed up)
    if #self.BallTracker.positions >= 5 then
        local earlyIdx = math.max(1, #self.BallTracker.positions - 4)
        local lateIdx = #self.BallTracker.positions

        local early = self.BallTracker.positions[earlyIdx]
        local late = self.BallTracker.positions[lateIdx]

        local earlySpeed, lateSpeed = 0, 0
        if earlyIdx + 1 <= #self.BallTracker.positions then
            local next = self.BallTracker.positions[earlyIdx + 1]
            local dt = next.time - early.time
            if dt > 0 then earlySpeed = (next.pos - early.pos).Magnitude / dt end
        end
        if lateIdx - 1 >= 1 then
            local prev = self.BallTracker.positions[lateIdx - 1]
            local dt = late.time - prev.time
            if dt > 0 then lateSpeed = (late.pos - prev.pos).Magnitude / dt end
        end

        -- If ball is accelerating, reduce predicted time
        if lateSpeed > earlySpeed * 1.2 then
            baseTime = baseTime * 0.75  -- Ball is speeding up
        end
    end

    return baseTime
end

-- ═══════════════════════════════════════
-- CHECK IF BALL IS APPROACHING PLAYER
-- ═══════════════════════════════════════
function ParryEngine:IsBallApproaching(ball, hrp)
    local direction = (hrp.Position - ball.Position)
    if direction.Magnitude < 0.1 then return true end -- Basically on top of us

    local dirNorm = direction.Unit

    -- Get ball velocity direction
    local ballVel = Vector3.new(0, 0, 0)
    pcall(function()
        ballVel = ball.Velocity or Vector3.new(0, 0, 0)
    end)

    -- If velocity is low, use position delta
    if ballVel.Magnitude < 1 and self.BallTracker.lastPosition then
        local dt = (tick() - (self.BallTracker.lastTime or tick()))
        if dt > 0 and dt < 1 then
            ballVel = (ball.Position - self.BallTracker.lastPosition) / dt
        end
    end

    if ballVel.Magnitude < 0.1 then return false end

    local ballDirNorm = ballVel.Unit
    local dot = dirNorm:Dot(ballDirNorm)

    -- dot > 0.2 means ball is generally moving toward player
    -- Lower threshold at close range
    local distance = direction.Magnitude
    if distance < 30 then
        return dot > -0.2  -- Almost any direction at close range
    elseif distance < 60 then
        return dot > 0.1
    else
        return dot > 0.3
    end
end

-- ═══════════════════════════════════════
-- EXECUTE PARRY (MULTI-METHOD)
-- ═══════════════════════════════════════
function ParryEngine:ExecuteParry()
    if self.ParryDebounce then return false end
    self.ParryDebounce = true

    local success = false

    -- Method 1: Cached remote
    local remote = self:FindParryRemote()
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

    -- Method 2: Fire all parry-related remotes (if Method 1 didn't find specific one)
    if not success then
        for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
            if r:IsA("RemoteEvent") then
                local name = r.Name:lower()
                if name:find("parry") or name:find("block") or name:find("deflect") or name:find("swing") then
                    pcall(function() r:FireServer() end)
                    success = true
                end
            end
        end
    end

    -- Method 3: Activate held tool (sword)
    pcall(function()
        local char = Player.Character
        if char then
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool then
                tool:Activate()
                success = true
            end
        end
    end)

    -- Method 4: VirtualInputManager click
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        success = true
    end)

    -- Method 5: Simulate mouse click via UserInputService
    pcall(function()
        if not success then
            -- Trigger mouse click event through the character
            local char = Player.Character
            if char then
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid then
                    -- Some games use Humanoid events
                end
            end
        end
    end)

    if success then
        self.ParryCount = self.ParryCount + 1
        self.TotalAttempts = self.TotalAttempts + 1
        self.LastParryTick = tick()

        -- Visual effect
        if self.VisualEffects then
            self:DoParryEffect()
        end

        -- Sound
        if self.SoundEffects then
            pcall(function()
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxassetid://12221984"
                sound.Volume = 0.25
                sound.PlayOnRemove = true
                sound.Parent = Workspace
                sound:Destroy()
            end)
        end
    end

    task.delay(0.12, function()
        self.ParryDebounce = false
    end)

    return success
end

-- ═══════════════════════════════════════
-- PARRY VISUAL EFFECT
-- ═══════════════════════════════════════
function ParryEngine:DoParryEffect()
    if not Library._ScreenGui then return end

    -- Screen flash
    local flash = Instance.new("Frame")
    flash.BackgroundColor3 = Tokens.Colors.Accent
    flash.BackgroundTransparency = 0.75
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.ZIndex = 50
    flash.BorderSizePixel = 0
    flash.Parent = Library._ScreenGui
    Util.Tween(flash, {BackgroundTransparency = 1}, 0.35)
    task.delay(0.35, function() if flash.Parent then flash:Destroy() end end)

    -- 3D sphere effect
    pcall(function()
        local char = Player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local sphere = Instance.new("Part")
                sphere.Shape = Enum.PartType.Ball
                sphere.Material = Enum.Material.Neon
                sphere.Color = Tokens.Colors.Accent
                sphere.Size = Vector3.new(2, 2, 2)
                sphere.Position = hrp.Position
                sphere.Anchored = true
                sphere.CanCollide = false
                sphere.Transparency = 0.4
                sphere.Parent = Workspace
                Util.Tween(sphere, {Size = Vector3.new(18, 18, 18), Transparency = 1}, 0.45)
                task.delay(0.5, function() if sphere.Parent then sphere:Destroy() end end)
            end
        end
    end)
end

-- ═══════════════════════════════════════
-- BALL ESP
-- ═══════════════════════════════════════
function ParryEngine:UpdateESP(ball, distance, speed, isApproaching)
    if not self.BallESP then
        if self._ESP and self._ESP.Parent then self._ESP:Destroy() end
        self._ESP = nil
        return
    end

    if not self._ESP or self._ESP.Parent ~= ball then
        if self._ESP then self._ESP:Destroy() end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ZusyniESP"
        billboard.Size = UDim2.new(0, 110, 0, 44)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Adornee = ball
        billboard.Parent = ball

        local bg = Instance.new("Frame")
        bg.Name = "BG"
        bg.BackgroundColor3 = Tokens.Colors.BgPrimary
        bg.BackgroundTransparency = 0.15
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.Parent = billboard
        Util.Corner(bg, 8)
        Util.Stroke(bg, Tokens.Colors.Error, 1.5, 0.3)

        local statusLabel = Instance.new("TextLabel")
        statusLabel.Name = "Status"
        statusLabel.BackgroundTransparency = 1
        statusLabel.Size = UDim2.new(1, 0, 0.5, 0)
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.TextSize = 11
        statusLabel.TextColor3 = Tokens.Colors.Error
        statusLabel.Text = "BALL"
        statusLabel.Parent = bg

        local infoLabel = Instance.new("TextLabel")
        infoLabel.Name = "Info"
        infoLabel.BackgroundTransparency = 1
        infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
        infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
        infoLabel.Font = Enum.Font.Gotham
        infoLabel.TextSize = 9
        infoLabel.TextColor3 = Tokens.Colors.TextPrimary
        infoLabel.Text = "0 studs"
        infoLabel.Parent = bg

        self._ESP = billboard
    end

    -- Update ESP text
    pcall(function()
        local bg = self._ESP:FindFirstChild("BG")
        if bg then
            local status = bg:FindFirstChild("Status")
            local info = bg:FindFirstChild("Info")
            if status then
                if isApproaching and distance < 100 then
                    status.Text = "⚠ INCOMING"
                    status.TextColor3 = Tokens.Colors.Error
                else
                    status.Text = "● BALL"
                    status.TextColor3 = Tokens.Colors.Warning
                end
            end
            if info then
                info.Text = string.format("%.0f studs | %.0f spd", distance, speed)
            end
            local stroke = bg:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Color = (isApproaching and distance < 80) and Tokens.Colors.Error or Tokens.Colors.Warning
            end
        end
    end)
end

-- ═══════════════════════════════════════
-- MAIN PARRY LOOP (Heartbeat)
-- ═══════════════════════════════════════
function ParryEngine:Start()
    self:Stop() -- Clean up any existing connections

    -- Main heartbeat loop
    self._HeartbeatConn = RunService.Heartbeat:Connect(function()
        if not self.Enabled then return end

        local char = Player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end

        -- Find ball
        local ball = self:FindBall()
        if not ball then return end

        -- Calculate speed
        local speed = self:CalculateBallSpeed(ball)

        -- Distance
        local distance = (ball.Position - hrp.Position).Magnitude

        -- Is approaching?
        local isApproaching = self:IsBallApproaching(ball, hrp)

        -- Is targeted? (red outline)
        local isTargeted = self:IsTargeted()

        -- Update ESP
        self:UpdateESP(ball, distance, speed, isApproaching)

        -- Update GUI stats (will be connected later)
        if self._OnStatsUpdate then
            self._OnStatsUpdate(self.ParryCount, self.TotalAttempts, speed)
        end

        -- ═══════════════════════════════════
        -- PARRY DECISION ENGINE
        -- ═══════════════════════════════════

        -- Skip if ball not approaching and not targeted
        if not isApproaching and not isTargeted then return end

        -- Skip if on cooldown
        if tick() - self.LastParryTick < 0.12 then return end

        -- Calculate optimal parry distance
        local optimalDist = self:CalculateOptimalDistance(speed)

        -- Predict time to reach
        local timeToReach = self:PredictTimeToReach(ball, hrp)

        local shouldParry = false

        if self.SmartTiming then
            -- Ultra-fast balls (>300 speed) — parry very early
            if speed > 300 and distance < optimalDist * 1.8 and isApproaching then
                shouldParry = true

            -- Very fast balls (>200) — parry early
            elseif speed > 200 and distance < optimalDist * 1.5 and isApproaching then
                shouldParry = true

            -- Fast balls (>100) — parry with margin
            elseif speed > 100 and distance < optimalDist * 1.2 and isApproaching then
                shouldParry = true

            -- Normal speed — standard parry
            elseif distance < optimalDist and isApproaching then
                shouldParry = true

            -- Emergency close range — always parry
            elseif distance < self.MinParryDistance then
                shouldParry = true

            -- Targeted and in range — parry with extra margin
            elseif isTargeted and distance < optimalDist * 1.4 then
                shouldParry = true

            -- Targeted emergency — very close
            elseif isTargeted and distance < 30 then
                shouldParry = true
            end

            -- Time-based prediction parry
            if self.PredictionEnabled then
                if timeToReach < 0.2 and timeToReach > 0.01 then
                    shouldParry = true
                end
                -- For fast balls, also check slightly further out
                if speed > 150 and timeToReach < 0.3 and timeToReach > 0.01 then
                    shouldParry = true
                end
            end
        else
            -- Simple mode: distance only
            if distance < self.BaseParryDistance and (isApproaching or isTargeted) then
                shouldParry = true
            end
        end

        -- EXECUTE
        if shouldParry then
            if speed > 150 then
                -- Immediate parry for fast balls
                self:ExecuteParry()
            else
                -- Slight delay for slower balls to maximize timing accuracy
                local delay = math.clamp(timeToReach * 0.25, 0, 0.08)
                task.delay(delay, function()
                    if self.Enabled then
                        self:ExecuteParry()
                    end
                end)
            end
        end
    end)

    table.insert(self._Connections, self._HeartbeatConn)

    -- Backup target detection loop (runs less frequently)
    self._BackupConn = task.spawn(function()
        while self.Enabled and Library._ScreenGui and Library._ScreenGui.Parent do
            pcall(function()
                if not self.Enabled then return end

                local ball = self:FindBall()
                if not ball then return end

                local char = Player.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                -- Check attribute-based targeting
                local target = ball:GetAttribute("Target")
                    or ball:GetAttribute("target")
                    or ball:GetAttribute("CurrentTarget")
                    or ball:GetAttribute("TargetPlayer")

                local isTarget = false
                if target then
                    if target == Player.Name or target == Player.UserId
                       or target == tostring(Player.UserId) then
                        isTarget = true
                    end
                end

                -- Check ObjectValue targeting
                for _, child in ipairs(ball:GetChildren()) do
                    if child:IsA("ObjectValue") and child.Value then
                        if child.Value == char or child.Value == Player then
                            isTarget = true
                            break
                        end
                    end
                end

                if isTarget then
                    local dist = (ball.Position - hrp.Position).Magnitude
                    if dist < self.BaseParryDistance * 1.5 and tick() - self.LastParryTick > 0.15 then
                        self:ExecuteParry()
                    end
                end
            end)
            task.wait(0.05) -- 20 checks per second
        end
    end)
end

function ParryEngine:Stop()
    for _, conn in ipairs(self._Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self._Connections = {}

    if self._ESP and self._ESP.Parent then
        self._ESP:Destroy()
        self._ESP = nil
    end
end

function ParryEngine:SetEnabled(enabled)
    self.Enabled = enabled
    if enabled then
        self:Start()
    else
        self:Stop()
    end
end

-- ══════════════════════════════════════════════════════════════════
-- WINDOW CREATION — FULL GUI WITH INTEGRATED PARRY
-- ══════════════════════════════════════════════════════════════════

Library:_InitGui()

local vp = GetViewport()

local function CalcWindowSize()
    vp = GetViewport()
    local wScale = IsMobile and (IsPortrait and 0.88 or 0.82) or 0.58
    local hScale = IsMobile and (IsPortrait and 0.68 or 0.72) or 0.70
    local w = math.clamp(vp.X * wScale, 320, 900)
    local h = math.clamp(vp.Y * hScale, 280, 650)
    return w, h
end

local winW, winH = CalcWindowSize()

-- ═══ Main Window ═══
local WindowFrame = Instance.new("Frame")
WindowFrame.Name = "ZusyniWindow"
WindowFrame.BackgroundColor3 = Tokens.Colors.BgPrimary
WindowFrame.Size = UDim2.new(0, winW, 0, winH)
WindowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
WindowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
WindowFrame.ClipsDescendants = true
WindowFrame.Visible = false
WindowFrame.ZIndex = 10
WindowFrame.Parent = Library._ScreenGui
Util.Corner(WindowFrame, Tokens.Radius.xxl)
Util.Stroke(WindowFrame, Tokens.Colors.Border, 1, 0.3)
Util.Shadow(WindowFrame, 60, 0.55)

-- Resize handler
Library:AddConnection(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local nw, nh = CalcWindowSize()
    Util.Tween(WindowFrame, {Size = UDim2.new(0, nw, 0, nh)}, Tokens.Duration.slow)
end))

-- ═══ Header ═══
local headerH = IsMobile and 44 or 48

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.BackgroundColor3 = Tokens.Colors.BgSecondary
Header.Size = UDim2.new(1, 0, 0, headerH)
Header.BorderSizePixel = 0
Header.ZIndex = 20
Header.Parent = WindowFrame
Util.Corner(Header, Tokens.Radius.xxl)

local headerFix = Instance.new("Frame")
headerFix.BackgroundColor3 = Tokens.Colors.BgSecondary
headerFix.Size = UDim2.new(1, 0, 0, 10)
headerFix.Position = UDim2.new(0, 0, 1, -10)
headerFix.BorderSizePixel = 0
headerFix.ZIndex = 20
headerFix.Parent = Header

local headerLine = Instance.new("Frame")
headerLine.BackgroundColor3 = Tokens.Colors.Accent
headerLine.Size = UDim2.new(1, 0, 0, 1)
headerLine.Position = UDim2.new(0, 0, 1, 0)
headerLine.BorderSizePixel = 0
headerLine.BackgroundTransparency = 0.7
headerLine.ZIndex = 21
headerLine.Parent = Header

-- Logo
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

local headerTitle = Instance.new("TextLabel")
headerTitle.BackgroundTransparency = 1
headerTitle.Size = UDim2.new(0, 150, 0, 16)
headerTitle.Position = UDim2.new(0, Tokens.Spacing.lg + 36, 0, IsMobile and 8 or 10)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = IsMobile and Tokens.FontSize.md or Tokens.FontSize.lg
headerTitle.TextColor3 = Tokens.Colors.TextPrimary
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Text = "ZUSYNI"
headerTitle.ZIndex = 22
headerTitle.Parent = Header

local headerSub = Instance.new("TextLabel")
headerSub.BackgroundTransparency = 1
headerSub.Size = UDim2.new(0, 250, 0, 12)
headerSub.Position = UDim2.new(0, Tokens.Spacing.lg + 36, 0, (IsMobile and 8 or 10) + 17)
headerSub.Font = Enum.Font.Gotham
headerSub.TextSize = Tokens.FontSize.xs
headerSub.TextColor3 = Tokens.Colors.TextTertiary
headerSub.TextXAlignment = Enum.TextXAlignment.Left
headerSub.Text = "Premium Interface + Auto Parry Engine"
headerSub.ZIndex = 22
headerSub.Parent = Header

-- Header buttons
local headerBtns = Instance.new("Frame")
headerBtns.BackgroundTransparency = 1
headerBtns.Size = UDim2.new(0, 70, 0, headerH)
headerBtns.Position = UDim2.new(1, -78, 0, 0)
headerBtns.ZIndex = 22
headerBtns.Parent = Header

local hBtnLayout = Util.ListLayout(headerBtns, Tokens.Spacing.xs, Enum.FillDirection.Horizontal)
hBtnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
hBtnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

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
sidebarToggleBtn.Parent = headerBtns
Util.Corner(sidebarToggleBtn, Tokens.Radius.sm)

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
closeBtn.Parent = headerBtns
Util.Corner(closeBtn, Tokens.Radius.sm)

closeBtn.MouseEnter:Connect(function() Util.Tween(closeBtn, {BackgroundTransparency = 0.5}, Tokens.Duration.fast) end)
closeBtn.MouseLeave:Connect(function() Util.Tween(closeBtn, {BackgroundTransparency = 0.8}, Tokens.Duration.fast) end)

-- ═══ Body ═══
local Body = Instance.new("Frame")
Body.Name = "Body"
Body.BackgroundTransparency = 1
Body.Size = UDim2.new(1, 0, 1, -headerH)
Body.Position = UDim2.new(0, 0, 0, headerH)
Body.ZIndex = 11
Body.Parent = WindowFrame

-- ═══ Sidebar ═══
local sidebarExpanded = not IsMobile
local sidebarW = sidebarExpanded and Tokens.Sidebar.ExpandedWidth or Tokens.Sidebar.CollapsedWidth

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.BackgroundColor3 = Tokens.Colors.BgSecondary
Sidebar.Size = UDim2.new(0, sidebarW, 1, 0)
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 15
Sidebar.ClipsDescendants = true
Sidebar.Parent = Body

local sidebarDivider = Instance.new("Frame")
sidebarDivider.BackgroundColor3 = Tokens.Colors.Divider
sidebarDivider.Size = UDim2.new(0, 1, 1, 0)
sidebarDivider.Position = UDim2.new(1, 0, 0, 0)
sidebarDivider.BorderSizePixel = 0
sidebarDivider.ZIndex = 16
sidebarDivider.Parent = Sidebar

local SidebarScroll = Instance.new("ScrollingFrame")
SidebarScroll.BackgroundTransparency = 1
SidebarScroll.Size = UDim2.new(1, 0, 1, -Tokens.Spacing.sm)
SidebarScroll.Position = UDim2.new(0, 0, 0, Tokens.Spacing.xs)
SidebarScroll.ScrollBarThickness = 0
SidebarScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
SidebarScroll.ZIndex = 16
SidebarScroll.Parent = Sidebar
Util.ListLayout(SidebarScroll, Tokens.Spacing.xs)
Util.Padding(SidebarScroll, Tokens.Spacing.xs, Tokens.Spacing.xs, Tokens.Spacing.xs, Tokens.Spacing.xs)

-- ═══ Content Area ═══
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.BackgroundColor3 = Tokens.Colors.BgPrimary
ContentArea.Size = UDim2.new(1, -sidebarW, 1, 0)
ContentArea.Position = UDim2.new(0, sidebarW, 0, 0)
ContentArea.BorderSizePixel = 0
ContentArea.ClipsDescendants = true
ContentArea.ZIndex = 12
ContentArea.Parent = Body

-- Page container
local PageContainer = Instance.new("Frame")
PageContainer.Name = "Pages"
PageContainer.BackgroundTransparency = 1
PageContainer.Size = UDim2.new(1, 0, 1, 0)
PageContainer.ClipsDescendants = true
PageContainer.ZIndex = 13
PageContainer.Parent = ContentArea

-- ═══ Sidebar toggle ═══
sidebarToggleBtn.MouseButton1Click:Connect(function()
    Util.Ripple(sidebarToggleBtn)
    sidebarExpanded = not sidebarExpanded
    local targetW = sidebarExpanded and Tokens.Sidebar.ExpandedWidth or Tokens.Sidebar.CollapsedWidth
    Util.Tween(Sidebar, {Size = UDim2.new(0, targetW, 1, 0)}, Tokens.Duration.normal)
    Util.Tween(ContentArea, {
        Size = UDim2.new(1, -targetW, 1, 0),
        Position = UDim2.new(0, targetW, 0, 0)
    }, Tokens.Duration.normal)
end)

-- ═══ Dragging ═══
local isDragging = false
local dragStartPos, frameStartPos

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStartPos = input.Position
        frameStartPos = WindowFrame.Position
    end
end)

Library:AddConnection(UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartPos
        local vps = GetViewport()
        local newX = frameStartPos.X.Offset + delta.X
        local newY = frameStartPos.Y.Offset + delta.Y
        local halfW = WindowFrame.AbsoluteSize.X / 2
        local halfH = WindowFrame.AbsoluteSize.Y / 2
        newX = math.clamp(newX, -vps.X*0.5 + halfW + 10, vps.X*0.5 - halfW - 10)
        newY = math.clamp(newY, -vps.Y*0.5 + halfH + 10, vps.Y*0.5 - halfH - 10)
        Util.Tween(WindowFrame, {Position = UDim2.new(0.5, newX, 0.5, newY)}, 0.06, Enum.EasingStyle.Quad)
    end
end))

Library:AddConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end))

-- ═══ Open / Close Animation ═══
local isOpen = false

local function OpenWindow()
    if isOpen then return end
    isOpen = true
    WindowFrame.Visible = true
    WindowFrame.BackgroundTransparency = 0.3
    WindowFrame.Size = UDim2.new(0, winW * 0.95, 0, winH * 0.95)
    Util.Tween(WindowFrame, {Size = UDim2.new(0, winW, 0, winH), BackgroundTransparency = 0}, Tokens.Duration.normal, Enum.EasingStyle.Back)
    Header.BackgroundTransparency = 0.5
    Util.Tween(Header, {BackgroundTransparency = 0}, Tokens.Duration.normal)
    Sidebar.Position = UDim2.new(0, -20, 0, 0)
    task.delay(0.05, function()
        Util.Tween(Sidebar, {Position = UDim2.new(0, 0, 0, 0)}, Tokens.Duration.slow)
    end)
end

local function CloseWindow()
    if not isOpen then return end
    isOpen = false
    Util.Tween(ContentArea, {BackgroundTransparency = 0.3}, Tokens.Duration.fast)
    Util.Tween(Sidebar, {Position = UDim2.new(0, -15, 0, 0)}, Tokens.Duration.fast)
    task.delay(0.05, function()
        Util.Tween(WindowFrame, {
            Size = UDim2.new(0, winW * 0.95, 0, winH * 0.95),
            BackgroundTransparency = 0.3
        }, Tokens.Duration.normal, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    end)
    task.delay(Tokens.Duration.normal + 0.1, function()
        WindowFrame.Visible = false
        ContentArea.BackgroundTransparency = 0
    end)
end

closeBtn.MouseButton1Click:Connect(function()
    Util.Ripple(closeBtn, Tokens.Colors.Error)
    CloseWindow()
end)

Library:AddConnection(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Library.ToggleKey then
        if isOpen then CloseWindow() else OpenWindow() end
    end
end))

-- ══════════════════════════════════════════════════════════════════
-- TAB & PAGE SYSTEM — HELPER FUNCTIONS
-- ══════════════════════════════════════════════════════════════════

local AllTabs = {}
local ActiveTab = nil
local tabLabels = {}

local function CreateTab(tabName, tabIcon, tabIndex)
    local tabBtnH = IsMobile and 36 or 38

    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = "Tab_"..tabName
    tabBtn.BackgroundColor3 = Tokens.Colors.BgSecondary
    tabBtn.BackgroundTransparency = 1
    tabBtn.Size = UDim2.new(1, 0, 0, tabBtnH)
    tabBtn.Text = ""
    tabBtn.LayoutOrder = tabIndex
    tabBtn.ZIndex = 17
    tabBtn.Parent = SidebarScroll
    Util.Corner(tabBtn, Tokens.Radius.md)

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

    local tabLabel = Instance.new("TextLabel")
    tabLabel.BackgroundTransparency = 1
    tabLabel.Size = UDim2.new(1, -44, 1, 0)
    tabLabel.Position = UDim2.new(0, 40, 0, 0)
    tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = Tokens.FontSize.sm
    tabLabel.TextColor3 = Tokens.Colors.TextSecondary
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Text = tabName
    tabLabel.TextTransparency = sidebarExpanded and 0 or 1
    tabLabel.ZIndex = 18
    tabLabel.Parent = tabBtn
    table.insert(tabLabels, tabLabel)

    local indicator = Instance.new("Frame")
    indicator.BackgroundColor3 = Tokens.Colors.Accent
    indicator.Size = UDim2.new(0, 3, 0, 0)
    indicator.Position = UDim2.new(0, 0, 0.5, 0)
    indicator.AnchorPoint = Vector2.new(0, 0.5)
    indicator.BorderSizePixel = 0
    indicator.ZIndex = 19
    indicator.Parent = tabBtn
    Util.Corner(indicator, 2)

    -- Page
    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_"..tabName
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
    Util.ListLayout(page, Tokens.Spacing.md)

    local tab = {
        Name = tabName,
        Btn = tabBtn,
        Icon = tabIconLabel,
        Label = tabLabel,
        Indicator = indicator,
        Page = page,
    }

    local function Select()
        if ActiveTab and ActiveTab ~= tab then
            Util.Tween(ActiveTab.Btn, {BackgroundTransparency = 1}, Tokens.Duration.fast)
            Util.Tween(ActiveTab.Icon, {TextColor3 = Tokens.Colors.TextTertiary}, Tokens.Duration.fast)
            Util.Tween(ActiveTab.Label, {TextColor3 = Tokens.Colors.TextSecondary}, Tokens.Duration.fast)
            Util.Tween(ActiveTab.Indicator, {Size = UDim2.new(0, 3, 0, 0)}, Tokens.Duration.fast)
            task.delay(Tokens.Duration.fast * 0.5, function() ActiveTab.Page.Visible = false end)
        end
        ActiveTab = tab
        Util.Tween(tabBtn, {BackgroundTransparency = 0.7}, Tokens.Duration.fast)
        Util.Tween(tabIconLabel, {TextColor3 = Tokens.Colors.Accent}, Tokens.Duration.fast)
        Util.Tween(tabLabel, {TextColor3 = Tokens.Colors.TextPrimary}, Tokens.Duration.fast)
        Util.Tween(indicator, {Size = UDim2.new(0, 3, 0, 20)}, Tokens.Duration.normal, Enum.EasingStyle.Back)

        page.Visible = true
        page.Position = UDim2.new(0.03, 0, 0, 0)
        Util.Tween(page, {Position = UDim2.new(0, 0, 0, 0)}, Tokens.Duration.page)
    end

    tabBtn.MouseButton1Click:Connect(function()
        Util.Ripple(tabBtn, Tokens.Colors.Accent)
        Select()
    end)
    tabBtn.MouseEnter:Connect(function()
        if ActiveTab ~= tab then
            Util.Tween(tabBtn, {BackgroundTransparency = 0.85}, Tokens.Duration.fast)
        end
    end)
    tabBtn.MouseLeave:Connect(function()
        if ActiveTab ~= tab then
            Util.Tween(tabBtn, {BackgroundTransparency = 1}, Tokens.Duration.fast)
        end
    end)

    tab.Select = Select
    table.insert(AllTabs, tab)
    return tab
end

-- Component helper: Section
local function CreateSection(page, sectionName, layoutOrder)
    local sectionFrame = Instance.new("Frame")
    sectionFrame.BackgroundTransparency = 1
    sectionFrame.Size = UDim2.new(1, 0, 0, 0)
    sectionFrame.AutomaticSize = Enum.AutomaticSize.Y
    sectionFrame.LayoutOrder = layoutOrder or 1
    sectionFrame.ZIndex = 14
    sectionFrame.Parent = page
    Util.ListLayout(sectionFrame, Tokens.Spacing.sm)

    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 16)
    header.Font = Enum.Font.GothamBold
    header.TextSize = Tokens.FontSize.xs
    header.TextColor3 = Tokens.Colors.TextTertiary
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Text = sectionName:upper()
    header.LayoutOrder = 0
    header.ZIndex = 15
    header.Parent = sectionFrame

    return sectionFrame
end

-- Component helper: Toggle
local function CreateToggle(parent, name, default, layoutOrder, callback)
    local enabled = default or false
    local compH = IsMobile and 44 or 40

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Tokens.Colors.Surface
    frame.Size = UDim2.new(1, 0, 0, compH)
    frame.LayoutOrder = layoutOrder
    frame.ZIndex = 15
    frame.Parent = parent
    Util.Corner(frame, Tokens.Radius.md)
    Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

    local label = Instance.new("TextLabel")
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
    knob.Position = enabled and UDim2.new(1, -(knobSize+2), 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.ZIndex = 18
    knob.Parent = track
    Util.Corner(knob, Tokens.Radius.full)

    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Text = ""
    btn.ZIndex = 19
    btn.Parent = frame

    local function Update()
        if enabled then
            Util.Tween(track, {BackgroundColor3 = Tokens.Colors.Accent}, Tokens.Duration.fast)
            Util.Tween(knob, {Position = UDim2.new(1, -(knobSize+2), 0.5, 0)}, Tokens.Duration.normal, Enum.EasingStyle.Back)
        else
            Util.Tween(track, {BackgroundColor3 = Tokens.Colors.BgActive}, Tokens.Duration.fast)
            Util.Tween(knob, {Position = UDim2.new(0, 2, 0.5, 0)}, Tokens.Duration.normal, Enum.EasingStyle.Back)
        end
    end

    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        Util.Ripple(frame, Tokens.Colors.Accent)
        Update()
        if callback then pcall(callback, enabled) end
    end)
    btn.MouseEnter:Connect(function() Util.Tween(frame, {BackgroundColor3 = Tokens.Colors.SurfaceHover}, Tokens.Duration.fast) end)
    btn.MouseLeave:Connect(function() Util.Tween(frame, {BackgroundColor3 = Tokens.Colors.Surface}, Tokens.Duration.fast) end)

    return {Set = function(_, v) enabled = v; Update() end, Get = function() return enabled end}
end

-- Component helper: Slider
local function CreateSlider(parent, name, min, max, default, suffix, layoutOrder, callback)
    local value = math.clamp(default, min, max)
    local compH = IsMobile and 56 or 52

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Tokens.Colors.Surface
    frame.Size = UDim2.new(1, 0, 0, compH)
    frame.LayoutOrder = layoutOrder
    frame.ZIndex = 15
    frame.Parent = parent
    Util.Corner(frame, Tokens.Radius.md)
    Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

    local label = Instance.new("TextLabel")
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
    valueLabel.Text = tostring(value)..(suffix or "")
    valueLabel.ZIndex = 16
    valueLabel.Parent = frame

    local trackBg = Instance.new("Frame")
    trackBg.BackgroundColor3 = Tokens.Colors.BgActive
    trackBg.Size = UDim2.new(1, -(Tokens.Spacing.md*2), 0, 6)
    trackBg.Position = UDim2.new(0, Tokens.Spacing.md, 1, -(Tokens.Spacing.sm+6))
    trackBg.ZIndex = 16
    trackBg.Parent = frame
    Util.Corner(trackBg, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Tokens.Colors.Accent
    fill.Size = UDim2.new((value-min)/(max-min), 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 17
    fill.Parent = trackBg
    Util.Corner(fill, 3)

    local knobS = IsMobile and 16 or 14
    local knobFrame = Instance.new("Frame")
    knobFrame.BackgroundColor3 = Tokens.Colors.White
    knobFrame.Size = UDim2.new(0, knobS, 0, knobS)
    knobFrame.Position = UDim2.new((value-min)/(max-min), 0, 0.5, 0)
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = true
            Util.Tween(knobFrame, {Size = UDim2.new(0, knobS+4, 0, knobS+4)}, Tokens.Duration.fast, Enum.EasingStyle.Back)
        end
    end)
    Library:AddConnection(UserInputService.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isSliding then
            isSliding = false
            Util.Tween(knobFrame, {Size = UDim2.new(0, knobS, 0, knobS)}, Tokens.Duration.fast, Enum.EasingStyle.Back)
        end
    end))
    Library:AddConnection(UserInputService.InputChanged:Connect(function(input)
        if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = (input.Position.X - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X
            rel = math.clamp(rel, 0, 1)
            value = math.floor(min + (max-min)*rel + 0.5)
            value = math.clamp(value, min, max)
            local norm = (value-min)/(max-min)
            Util.Tween(fill, {Size = UDim2.new(norm, 0, 1, 0)}, 0.04)
            Util.Tween(knobFrame, {Position = UDim2.new(norm, 0, 0.5, 0)}, 0.04)
            valueLabel.Text = tostring(value)..(suffix or "")
            if callback then pcall(callback, value) end
        end
    end))

    return {Set = function(_, v)
        value = math.clamp(v, min, max)
        local norm = (value-min)/(max-min)
        Util.Tween(fill, {Size = UDim2.new(norm, 0, 1, 0)}, Tokens.Duration.fast)
        Util.Tween(knobFrame, {Position = UDim2.new(norm, 0, 0.5, 0)}, Tokens.Duration.fast)
        valueLabel.Text = tostring(value)..(suffix or "")
    end, Get = function() return value end}
end

-- Component helper: Dropdown
local function CreateDropdown(parent, name, options, default, layoutOrder, callback)
    local selected = default or options[1]
    local isExpanded = false
    local compH = IsMobile and 44 or 40
    local optH = IsMobile and 34 or 30

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Tokens.Colors.Surface
    frame.Size = UDim2.new(1, 0, 0, compH)
    frame.LayoutOrder = layoutOrder
    frame.ClipsDescendants = true
    frame.ZIndex = 15
    frame.Parent = parent
    Util.Corner(frame, Tokens.Radius.md)
    Util.Stroke(frame, Tokens.Colors.SurfaceBorder, 1, 0.7)

    local label = Instance.new("TextLabel")
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

    local selLabel = Instance.new("TextLabel")
    selLabel.BackgroundTransparency = 1
    selLabel.Size = UDim2.new(0.35, -30, 0, compH)
    selLabel.Position = UDim2.new(0.5, 0, 0, 0)
    selLabel.Font = Enum.Font.Gotham
    selLabel.TextSize = Tokens.FontSize.sm
    selLabel.TextColor3 = Tokens.Colors.Accent
    selLabel.TextXAlignment = Enum.TextXAlignment.Right
    selLabel.TextTruncate = Enum.TextTruncate.AtEnd
    selLabel.Text = tostring(selected)
    selLabel.ZIndex = 16
    selLabel.Parent = frame

    local arrow = Instance.new("TextLabel")
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 20, 0, compH)
    arrow.Position = UDim2.new(1, -24, 0, 0)
    arrow.Font = Enum.Font.Gotham
    arrow.TextSize = 10
    arrow.TextColor3 = Tokens.Colors.TextTertiary
    arrow.Text = "▼"
    arrow.Rotation = 0
    arrow.ZIndex = 16
    arrow.Parent = frame

    local optContainer = Instance.new("Frame")
    optContainer.BackgroundTransparency = 1
    optContainer.Size = UDim2.new(1, -(Tokens.Spacing.sm*2), 0, 0)
    optContainer.Position = UDim2.new(0, Tokens.Spacing.sm, 0, compH + 4)
    optContainer.AutomaticSize = Enum.AutomaticSize.Y
    optContainer.ZIndex = 17
    optContainer.Parent = frame
    Util.ListLayout(optContainer, 2)

    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.BackgroundColor3 = Tokens.Colors.BgTertiary
        optBtn.BackgroundTransparency = 0.5
        optBtn.Size = UDim2.new(1, 0, 0, optH)
        optBtn.Font = Enum.Font.Gotham
        optBtn.TextSize = Tokens.FontSize.sm
        optBtn.TextColor3 = (opt == selected) and Tokens.Colors.Accent or Tokens.Colors.TextSecondary
        optBtn.Text = "  "..tostring(opt)
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.LayoutOrder = i
        optBtn.ZIndex = 18
        optBtn.Parent = optContainer
        Util.Corner(optBtn, Tokens.Radius.sm)

        optBtn.MouseButton1Click:Connect(function()
            selected = opt
            selLabel.Text = tostring(opt)
            for _, c in ipairs(optContainer:GetChildren()) do
                if c:IsA("TextButton") then
                    Util.Tween(c, {TextColor3 = (c.Text:sub(3) == tostring(opt)) and Tokens.Colors.Accent or Tokens.Colors.TextSecondary}, Tokens.Duration.fast)
                end
            end
            isExpanded = false
            Util.Tween(frame, {Size = UDim2.new(1, 0, 0, compH)}, Tokens.Duration.normal, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            Util.Tween(arrow, {Rotation = 0}, Tokens.Duration.fast)
            if callback then pcall(callback, opt) end
        end)
        optBtn.MouseEnter:Connect(function() Util.Tween(optBtn, {BackgroundTransparency = 0.2}, Tokens.Duration.fast) end)
        optBtn.MouseLeave:Connect(function() Util.Tween(optBtn, {BackgroundTransparency = 0.5}, Tokens.Duration.fast) end)
    end

    local toggleArea = Instance.new("TextButton")
    toggleArea.BackgroundTransparency = 1
    toggleArea.Size = UDim2.new(1, 0, 0, compH)
    toggleArea.Text = ""
    toggleArea.ZIndex = 19
    toggleArea.Parent = frame

    toggleArea.MouseButton1Click:Connect(function()
        isExpanded = not isExpanded
        Util.Ripple(frame, Tokens.Colors.Accent)
        if isExpanded then
            local totalH = compH + 8 + (#options * (optH + 2))
            Util.Tween(frame, {Size = UDim2.new(1, 0, 0, totalH)}, Tokens.Duration.normal, Enum.EasingStyle.Back)
            Util.Tween(arrow, {Rotation = 180}, Tokens.Duration.fast)
        else
            Util.Tween(frame, {Size = UDim2.new(1, 0, 0, compH)}, Tokens.Duration.normal, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            Util.Tween(arrow, {Rotation = 0}, Tokens.Duration.fast)
        end
    end)
end

-- Component helper: Info Label
local function CreateLabel(parent, text, layoutOrder)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.LayoutOrder = layoutOrder
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = Tokens.FontSize.xs
    lbl.TextColor3 = Tokens.Colors.TextTertiary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.ZIndex = 15
    lbl.Parent = parent
    return lbl
end

-- Component: Stat card
local function CreateStatCard(parent, layoutOrder)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Tokens.Colors.Surface
    card.Size = UDim2.new(1, 0, 0, 70)
    card.LayoutOrder = layoutOrder
    card.ZIndex = 15
    card.Parent = parent
    Util.Corner(card, Tokens.Radius.md)
    Util.Stroke(card, Tokens.Colors.SurfaceBorder, 1, 0.7)

    local function MiniStat(posX, icon, lbl, val, col)
        local box = Instance.new("Frame")
        box.BackgroundColor3 = Tokens.Colors.BgTertiary
        box.Size = UDim2.new(0, 120, 0, 42)
        box.Position = UDim2.new(0, posX, 0, 20)
        box.ZIndex = 16
        box.Parent = card
        Util.Corner(box, Tokens.Radius.sm)

        local icoLbl = Instance.new("TextLabel")
        icoLbl.BackgroundTransparency = 1
        icoLbl.Size = UDim2.new(0, 20, 1, 0)
        icoLbl.Position = UDim2.new(0, 6, 0, 0)
        icoLbl.Font = Enum.Font.GothamBold
        icoLbl.TextSize = 13
        icoLbl.TextColor3 = col
        icoLbl.Text = icon
        icoLbl.ZIndex = 17
        icoLbl.Parent = box

        local lblText = Instance.new("TextLabel")
        lblText.BackgroundTransparency = 1
        lblText.Size = UDim2.new(1, -30, 0, 12)
        lblText.Position = UDim2.new(0, 28, 0, 5)
        lblText.Font = Enum.Font.Gotham
        lblText.TextSize = 8
        lblText.TextColor3 = Tokens.Colors.TextTertiary
        lblText.TextXAlignment = Enum.TextXAlignment.Left
        lblText.Text = lbl
        lblText.ZIndex = 17
        lblText.Parent = box

        local valText = Instance.new("TextLabel")
        valText.Name = "Value"
        valText.BackgroundTransparency = 1
        valText.Size = UDim2.new(1, -30, 0, 16)
        valText.Position = UDim2.new(0, 28, 0, 19)
        valText.Font = Enum.Font.GothamBold
        valText.TextSize = 13
        valText.TextColor3 = col
        valText.TextXAlignment = Enum.TextXAlignment.Left
        valText.Text = val
        valText.ZIndex = 17
        valText.Parent = box
        return valText
    end

    local headerLbl = Instance.new("TextLabel")
    headerLbl.BackgroundTransparency = 1
    headerLbl.Size = UDim2.new(1, 0, 0, 16)
    headerLbl.Position = UDim2.new(0, 12, 0, 4)
    headerLbl.Font = Enum.Font.GothamBold
    headerLbl.TextSize = 9
    headerLbl.TextColor3 = Tokens.Colors.TextTertiary
    headerLbl.TextXAlignment = Enum.TextXAlignment.Left
    headerLbl.Text = "LIVE STATS"
    headerLbl.ZIndex = 16
    headerLbl.Parent = card

    local parryVal = MiniStat(12, "⚔", "PARRIES", "0", Tokens.Colors.Accent)
    local rateVal = MiniStat(142, "✓", "SUCCESS", "100%", Tokens.Colors.Success)
    local speedVal = MiniStat(272, "⚡", "SPEED", "0", Tokens.Colors.Warning)

    return parryVal, rateVal, speedVal
end

-- ══════════════════════════════════════════════════════════════════
-- BUILD ALL TABS & PAGES
-- ══════════════════════════════════════════════════════════════════

-- TAB 1: Auto Parry (Main)
local parryTab = CreateTab("Parry", "⚔", 1)
local parryPage = parryTab.Page

local statsSection = CreateSection(parryPage, "Live Statistics", 1)
local parryCountLabel, successRateLabel, ballSpeedLabel = CreateStatCard(statsSection, 1)

local parrySection = CreateSection(parryPage, "Auto Parry Engine", 2)

CreateToggle(parrySection, "Enable Auto Parry", false, 1, function(enabled)
    ParryEngine:SetEnabled(enabled)
    Library:Notify({
        Title = "Auto Parry",
        Description = enabled and "Engine started — zero miss active" or "Engine stopped",
        Type = enabled and "success" or "warning",
        Duration = 3,
    })
end)

CreateToggle(parrySection, "Smart Timing (Speed Adaptive)", true, 2, function(enabled)
    ParryEngine.SmartTiming = enabled
end)

CreateToggle(parrySection, "Prediction System", true, 3, function(enabled)
    ParryEngine.PredictionEnabled = enabled
end)

CreateSlider(parrySection, "Base Parry Distance", 10, 100, 55, " studs", 4, function(value)
    ParryEngine.BaseParryDistance = value
end)

CreateSlider(parrySection, "Min Parry Distance", 5, 50, 15, " studs", 5, function(value)
    ParryEngine.MinParryDistance = value
end)

CreateSlider(parrySection, "Max Parry Distance", 50, 150, 85, " studs", 6, function(value)
    ParryEngine.MaxParryDistance = value
end)

CreateSlider(parrySection, "Speed Multiplier (x10)", 5, 30, 10, "", 7, function(value)
    ParryEngine.SpeedMultiplier = value / 10
end)

local parryModeSection = CreateSection(parryPage, "Parry Mode", 3)
CreateDropdown(parryModeSection, "Mode Preset", {"Balanced", "Aggressive", "Defensive", "Ultra Fast"}, "Balanced", 1, function(mode)
    if mode == "Balanced" then
        ParryEngine.BaseParryDistance = 55
        ParryEngine.SpeedMultiplier = 1.0
    elseif mode == "Aggressive" then
        ParryEngine.BaseParryDistance = 70
        ParryEngine.SpeedMultiplier = 1.3
    elseif mode == "Defensive" then
        ParryEngine.BaseParryDistance = 40
        ParryEngine.SpeedMultiplier = 0.8
    elseif mode == "Ultra Fast" then
        ParryEngine.BaseParryDistance = 80
        ParryEngine.SpeedMultiplier = 1.6
    end
    Library:Notify({Title = "Mode", Description = "Parry mode set to: "..mode, Type = "info"})
end)

-- TAB 2: Visual
local visualTab = CreateTab("Visual", "👁", 2)
local visualPage = visualTab.Page

local espSection2 = CreateSection(visualPage, "ESP & Effects", 1)

CreateToggle(espSection2, "Ball ESP", true, 1, function(enabled)
    ParryEngine.BallESP = enabled
end)

CreateToggle(espSection2, "Parry Visual Effects", true, 2, function(enabled)
    ParryEngine.VisualEffects = enabled
end)

CreateToggle(espSection2, "Sound Effects", true, 3, function(enabled)
    ParryEngine.SoundEffects = enabled
end)

CreateToggle(espSection2, "Player ESP", false, 4, function(enabled)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character then
            local existing = plr.Character:FindFirstChild("ZusyniHL")
            if enabled then
                if not existing then
                    local hl = Instance.new("Highlight")
                    hl.Name = "ZusyniHL"
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
end)

CreateToggle(espSection2, "Fullbright", false, 5, function(enabled)
    if enabled then
        Lighting.Brightness = 3
        Lighting.FogEnd = 1e10
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = 1
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = true
    end
end)

-- TAB 3: Player
local playerTab = CreateTab("Player", "👤", 3)
local playerPage = playerTab.Page

local moveSection = CreateSection(playerPage, "Movement", 1)

CreateSlider(moveSection, "Walk Speed", 16, 200, 16, " studs/s", 1, function(value)
    local char = Player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = value
    end
end)

CreateSlider(moveSection, "Jump Power", 50, 300, 50, "", 2, function(value)
    local char = Player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.JumpPower = value
    end
end)

CreateToggle(moveSection, "Infinite Jump", false, 3, function(enabled)
    if enabled then
        Library._InfJumpConn = UserInputService.JumpRequest:Connect(function()
            local char = Player.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        Library:AddConnection(Library._InfJumpConn)
    else
        if Library._InfJumpConn then
            Library._InfJumpConn:Disconnect()
            Library._InfJumpConn = nil
        end
    end
end)

-- TAB 4: Settings
local settingsTab = CreateTab("Settings", "⚙", 4)
local settingsPage = settingsTab.Page

local uiSection = CreateSection(settingsPage, "Interface", 1)

CreateDropdown(uiSection, "Toggle Key", {"RightShift", "RightControl", "F6", "F9"}, "RightShift", 1, function(key)
    local keyMap = {
        RightShift = Enum.KeyCode.RightShift,
        RightControl = Enum.KeyCode.RightControl,
        F6 = Enum.KeyCode.F6,
        F9 = Enum.KeyCode.F9,
    }
    Library.ToggleKey = keyMap[key] or Enum.KeyCode.RightShift
    Library:Notify({Title = "Keybind", Description = "Toggle key: "..key, Type = "success"})
end)

local aboutSection = CreateSection(settingsPage, "About", 2)
CreateLabel(aboutSection, "ZUSYNI Premium v3.0 + Auto Parry Engine", 1)
CreateLabel(aboutSection, "Anti-Detection: Active", 2)
CreateLabel(aboutSection, "Press RightShift to toggle menu", 3)

-- ═══ Select first tab ═══
task.defer(function()
    AllTabs[1].Select()
end)

-- ══════════════════════════════════════════════════════════════════
-- CONNECT PARRY ENGINE STATS → GUI
-- ══════════════════════════════════════════════════════════════════

ParryEngine._OnStatsUpdate = function(parryCount, totalAttempts, speed)
    pcall(function()
        parryCountLabel.Text = tostring(parryCount)
        ballSpeedLabel.Text = string.format("%.0f", speed)
        if totalAttempts > 0 then
            successRateLabel.Text = string.format("%.0f%%", (parryCount / totalAttempts) * 100)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════
-- STARTUP
-- ══════════════════════════════════════════════════════════════════

-- Open window with animation
task.delay(0.5, function()
    OpenWindow()
end)

-- Startup notification
task.delay(1.2, function()
    Library:Notify({
        Title = "ZUSYNI Loaded",
        Description = "Auto Parry Engine ready. Press RightShift to toggle.",
        Type = "success",
        Duration = 5,
    })
end)

-- Remote detection
task.delay(2, function()
    local remote = ParryEngine:FindParryRemote()
    if remote then
        Library:Notify({
            Title = "Remote Detected",
            Description = "Parry remote found: "..remote.Name,
            Type = "success",
            Duration = 3,
        })
    else
        Library:Notify({
            Title = "Universal Mode",
            Description = "Using multi-method parry (Tool + VIM + Remote scan)",
            Type = "warning",
            Duration = 3,
        })
    end
end)

-- Console
print([[
╔═══════════════════════════════════════════════╗
║         ZUSYNI v3.0 + AUTO PARRY             ║
║                                               ║
║  Toggle:  RightShift                          ║
║  Device:  ]] .. (IsMobile and "Mobile " or "Desktop") .. [[
║                                               ║
║  AUTO PARRY ENGINE:                           ║
║  • Smart Speed-Adaptive Timing               ║
║  • Trajectory Prediction                      ║
║  • Red Outline (Target) Detection             ║
║  • Multi-Method Parry (5 methods)            ║
║  • Ball ESP with Distance/Speed              ║
║  • Zero Miss Technology                       ║
║                                               ║
║  Anti-Detection: Active                       ║
╚═══════════════════════════════════════════════╝
]])

return Library
