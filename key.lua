--[[
    ZUSYNI Studio / Key System Loader
    File: key.lua
    Repository: zusyni-studio/syn-studio

    Setiap script ZUSYNI harus memanggil file ini terlebih dahulu.
    Script ini memverifikasi akses user sebelum melanjutkan ke main script.

    USAGE:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/zusyni-studio/syn-studio/main/key.lua"))()
]]

if _G.ZUSYNI_LOADED then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "ZUSYNI Studio",
        Text = "Already running.",
        Duration = 3
    })
    return
end
_G.ZUSYNI_LOADED = true
_G.ZUSYNI_ACCESS = false

-- ═══════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════

local CONFIG = {
    -- ⚠️ GANTI dengan domain Netlify kamu yang asli!
    Domain = "https://zusyni-studio.netlify.app",  
    
    KeyFile = "ZUSYNI/keys.json",
    KeyFolder = "ZUSYNI",
    SessionTimeout = 600,
    VerifyRetries = 2,
}

-- ═══════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- HTTP DETECTION
-- ═══════════════════════════════════════════

local httpRequest = (function()
    if syn and syn.request then return syn.request end
    if http and http.request then return http.request end
    if http_request then return http_request end
    if fluxus and fluxus.request then return fluxus.request end
    if request then return request end
    if KRNL_LOADED and request then return request end
    return nil
end)()

local canWriteFile = (function()
    local ok = pcall(function() return writefile and readfile and isfile and makefolder end)
    return ok
end)()

-- ═══════════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════════

local function safeRequest(options)
    if not httpRequest then
        return nil, "No HTTP support"
    end

    local ok, result = pcall(function()
        return httpRequest(options)
    end)

    if not ok then
        return nil, tostring(result)
    end

    if result and result.StatusCode and result.Body then
        local parseOk, parsed = pcall(function()
            return HttpService:JSONDecode(result.Body)
        end)
        if parseOk then
            return parsed, nil
        else
            return nil, "Invalid response"
        end
    end

    return nil, "Request failed"
end

local function notify(text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "ZUSYNI Studio",
            Text = text,
            Duration = duration or 4
        })
    end)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function hexColor(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return Color3.new(r, g, b)
end

-- ═══════════════════════════════════════════
-- COLOR PALETTE
-- ═══════════════════════════════════════════

local C = {
    bg         = hexColor("08080d"),
    bgCard     = hexColor("0c0c13"),
    bgElevated = hexColor("101018"),
    bgHover    = hexColor("14141e"),
    bgInput    = hexColor("0a0a12"),
    border     = hexColor("1a1a26"),
    borderLt   = hexColor("222233"),
    borderFocus= hexColor("2d2d44"),
    text       = hexColor("e0e0e8"),
    text2      = hexColor("9898aa"),
    text3      = hexColor("5c5c72"),
    text4      = hexColor("363650"),
    text5      = hexColor("24243a"),
    accent     = hexColor("7ba4e8"),
    accent2    = hexColor("5b8cd6"),
    accentDim  = hexColor("162040"),
    green      = hexColor("5ee8a0"),
    greenDim   = hexColor("0d2818"),
    red        = hexColor("f07070"),
    redDim     = hexColor("281010"),
    yellow     = hexColor("f0c060"),
    white      = hexColor("f0f0f4"),
}

-- ═══════════════════════════════════════════
-- KEY FILE OPERATIONS
-- ═══════════════════════════════════════════

local function ensureFolder()
    if not canWriteFile then return end
    pcall(function()
        if not isfolder(CONFIG.KeyFolder) then
            makefolder(CONFIG.KeyFolder)
        end
    end)
end

local function loadSavedKey()
    if not canWriteFile then return nil end

    local ok, result = pcall(function()
        if isfile(CONFIG.KeyFile) then
            local raw = readfile(CONFIG.KeyFile)
            return HttpService:JSONDecode(raw)
        end
        return nil
    end)

    if ok and result and result.key then
        return result.key
    end
    return nil
end

local function saveKey(key, expiresAt)
    if not canWriteFile then return end

    ensureFolder()
    pcall(function()
        local data = HttpService:JSONEncode({
            key = key,
            savedAt = os.time(),
            expiresAt = expiresAt or "",
        })
        writefile(CONFIG.KeyFile, data)
    end)
end

local function deleteSavedKey()
    if not canWriteFile then return end
    pcall(function()
        if isfile(CONFIG.KeyFile) then
            delfile(CONFIG.KeyFile)
        end
    end)
end

-- ═══════════════════════════════════════════
-- API
-- ═══════════════════════════════════════════

local function apiCreateSession()
    return safeRequest({
        Url = CONFIG.Domain .. "/api/key/session",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({})
    })
end

local function apiVerifyKey(key)
    return safeRequest({
        Url = CONFIG.Domain .. "/api/key/verify",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({key = key})
    })
end

-- ═══════════════════════════════════════════
-- TWEEN HELPERS
-- ═══════════════════════════════════════════

local function tweenProperty(obj, props, duration, style, direction)
    local ti = TweenInfo.new(
        duration or 0.35,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(obj, ti, props)
    tween:Play()
    return tween
end

local function fadeIn(obj, duration)
    obj.BackgroundTransparency = 1
    return tweenProperty(obj, {BackgroundTransparency = 0}, duration or 0.4)
end

local function slideIn(obj, fromOffset, duration)
    local target = obj.Position
    obj.Position = target + fromOffset
    return tweenProperty(obj, {Position = target}, duration or 0.5, Enum.EasingStyle.Quint)
end

-- ═══════════════════════════════════════════
-- UI BUILDER
-- ═══════════════════════════════════════════

local ScreenGui, MainFrame, Overlay
local StatusLabel, StatusSub, KeyInput
local BtnGetKey, BtnVerify, BtnClose
local ProgressBar, ProgressFill
local LogoGroup, TitleLabel, SubtitleLabel
local ContentFrame, FooterLabel
local GlowFrame

local WINDOW_W = 400
local WINDOW_H = 480
local CORNER_R = 10

local function createCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or CORNER_R)
    c.Parent = parent
    return c
end

local function createStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function createPadding(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingRight = UDim.new(0, r or 0)
    p.Parent = parent
    return p
end

local function buildUI()
    -- Cleanup existing
    pcall(function()
        local existing = CoreGui:FindFirstChild("ZUSYNIKeySystem")
        if existing then existing:Destroy() end
    end)

    -- ScreenGui
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ZUSYNIKeySystem"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999

    pcall(function()
        ScreenGui.Parent = CoreGui
    end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = Player:WaitForChild("PlayerGui")
    end

    -- Overlay
    Overlay = Instance.new("Frame")
    Overlay.Name = "Overlay"
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    Overlay.BackgroundTransparency = 1
    Overlay.BorderSizePixel = 0
    Overlay.Parent = ScreenGui

    -- Main Window
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "Main"
    MainFrame.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
    MainFrame.Position = UDim2.new(0.5, -WINDOW_W/2, 0.5, -WINDOW_H/2)
    MainFrame.BackgroundColor3 = C.bg
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    createCorner(MainFrame, 12)
    createStroke(MainFrame, C.border, 1)

    -- Drop Shadow (outer glow)
    GlowFrame = Instance.new("ImageLabel")
    GlowFrame.Name = "Shadow"
    GlowFrame.Size = UDim2.new(1, 48, 1, 48)
    GlowFrame.Position = UDim2.new(0, -24, 0, -24)
    GlowFrame.BackgroundTransparency = 1
    GlowFrame.Image = "rbxassetid://5554236805"
    GlowFrame.ImageColor3 = Color3.new(0, 0, 0)
    GlowFrame.ImageTransparency = 0.6
    GlowFrame.ScaleType = Enum.ScaleType.Slice
    GlowFrame.SliceCenter = Rect.new(23, 23, 277, 277)
    GlowFrame.ZIndex = -1
    GlowFrame.Parent = MainFrame

    -- ═══ HEADER ═══

    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 56)
    Header.BackgroundColor3 = C.bgCard
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame

    local HeaderBorder = Instance.new("Frame")
    HeaderBorder.Name = "Border"
    HeaderBorder.Size = UDim2.new(1, 0, 0, 1)
    HeaderBorder.Position = UDim2.new(0, 0, 1, -1)
    HeaderBorder.BackgroundColor3 = C.border
    HeaderBorder.BorderSizePixel = 0
    HeaderBorder.Parent = Header

    -- Logo Icon (bracket symbol via text)
    local LogoIcon = Instance.new("TextLabel")
    LogoIcon.Name = "LogoIcon"
    LogoIcon.Size = UDim2.new(0, 28, 0, 28)
    LogoIcon.Position = UDim2.new(0, 18, 0.5, -14)
    LogoIcon.BackgroundColor3 = C.accentDim
    LogoIcon.BorderSizePixel = 0
    LogoIcon.Text = ">"
    LogoIcon.TextColor3 = C.accent
    LogoIcon.Font = Enum.Font.RobotoMono
    LogoIcon.TextSize = 16
    LogoIcon.Parent = Header
    createCorner(LogoIcon, 6)

    -- Brand Name
    local BrandLabel = Instance.new("TextLabel")
    BrandLabel.Name = "Brand"
    BrandLabel.Size = UDim2.new(0, 160, 0, 20)
    BrandLabel.Position = UDim2.new(0, 54, 0.5, -10)
    BrandLabel.BackgroundTransparency = 1
    BrandLabel.Text = "ZUSYNI Studio"
    BrandLabel.TextColor3 = C.text
    BrandLabel.Font = Enum.Font.GothamBold
    BrandLabel.TextSize = 14
    BrandLabel.TextXAlignment = Enum.TextXAlignment.Left
    BrandLabel.Parent = Header

    -- Close Button
    BtnClose = Instance.new("TextButton")
    BtnClose.Name = "Close"
    BtnClose.Size = UDim2.new(0, 32, 0, 32)
    BtnClose.Position = UDim2.new(1, -44, 0.5, -16)
    BtnClose.BackgroundColor3 = C.bgElevated
    BtnClose.BorderSizePixel = 0
    BtnClose.Text = "x"
    BtnClose.TextColor3 = C.text3
    BtnClose.Font = Enum.Font.RobotoMono
    BtnClose.TextSize = 16
    BtnClose.AutoButtonColor = false
    BtnClose.Parent = Header
    createCorner(BtnClose, 6)

    -- ═══ TOP ACCENT LINE ═══

    local AccentLine = Instance.new("Frame")
    AccentLine.Name = "AccentLine"
    AccentLine.Size = UDim2.new(0, 0, 0, 2)
    AccentLine.Position = UDim2.new(0, 0, 0, 0)
    AccentLine.BackgroundColor3 = C.accent
    AccentLine.BorderSizePixel = 0
    AccentLine.Parent = MainFrame

    -- Animate accent line
    task.delay(0.3, function()
        if AccentLine then
            tweenProperty(AccentLine, {Size = UDim2.new(1, 0, 0, 2)}, 0.8, Enum.EasingStyle.Quint)
        end
    end)

    -- ═══ CONTENT ═══

    ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "Content"
    ContentFrame.Size = UDim2.new(1, 0, 1, -56)
    ContentFrame.Position = UDim2.new(0, 0, 0, 56)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame
    createPadding(ContentFrame, 32, 24, 32, 32)

    -- Section Label
    local SectionLabel = Instance.new("TextLabel")
    SectionLabel.Name = "SectionLabel"
    SectionLabel.Size = UDim2.new(1, 0, 0, 14)
    SectionLabel.BackgroundTransparency = 1
    SectionLabel.Text = "ACCESS GATE"
    SectionLabel.TextColor3 = C.text4
    SectionLabel.Font = Enum.Font.RobotoMono
    SectionLabel.TextSize = 10
    SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
    SectionLabel.LayoutOrder = 1
    SectionLabel.Parent = ContentFrame

    -- Title
    TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Size = UDim2.new(1, 0, 0, 28)
    TitleLabel.Position = UDim2.new(0, 0, 0, 22)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Key Required"
    TitleLabel.TextColor3 = C.text
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 20
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = ContentFrame

    -- Subtitle
    SubtitleLabel = Instance.new("TextLabel")
    SubtitleLabel.Name = "Subtitle"
    SubtitleLabel.Size = UDim2.new(1, 0, 0, 36)
    SubtitleLabel.Position = UDim2.new(0, 0, 0, 56)
    SubtitleLabel.BackgroundTransparency = 1
    SubtitleLabel.Text = "Enter your ZUSYNI access key to continue.\nGet a key from the website if you don't have one."
    SubtitleLabel.TextColor3 = C.text3
    SubtitleLabel.Font = Enum.Font.Gotham
    SubtitleLabel.TextSize = 12
    SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubtitleLabel.TextWrapped = true
    SubtitleLabel.LineHeight = 1.4
    SubtitleLabel.Parent = ContentFrame

    -- ═══ INPUT SECTION ═══

    local InputLabel = Instance.new("TextLabel")
    InputLabel.Name = "InputLabel"
    InputLabel.Size = UDim2.new(1, 0, 0, 14)
    InputLabel.Position = UDim2.new(0, 0, 0, 112)
    InputLabel.BackgroundTransparency = 1
    InputLabel.Text = "ACCESS KEY"
    InputLabel.TextColor3 = C.text4
    InputLabel.Font = Enum.Font.RobotoMono
    InputLabel.TextSize = 10
    InputLabel.TextXAlignment = Enum.TextXAlignment.Left
    InputLabel.Parent = ContentFrame

    -- Input Container
    local InputContainer = Instance.new("Frame")
    InputContainer.Name = "InputContainer"
    InputContainer.Size = UDim2.new(1, 0, 0, 44)
    InputContainer.Position = UDim2.new(0, 0, 0, 130)
    InputContainer.BackgroundColor3 = C.bgInput
    InputContainer.BorderSizePixel = 0
    InputContainer.Parent = ContentFrame
    createCorner(InputContainer, 8)
    local inputStroke = createStroke(InputContainer, C.border, 1)

    KeyInput = Instance.new("TextBox")
    KeyInput.Name = "KeyInput"
    KeyInput.Size = UDim2.new(1, -24, 1, 0)
    KeyInput.Position = UDim2.new(0, 12, 0, 0)
    KeyInput.BackgroundTransparency = 1
    KeyInput.Text = ""
    KeyInput.PlaceholderText = "ZUSYNI-XXXX-XXXX"
    KeyInput.PlaceholderColor3 = C.text4
    KeyInput.TextColor3 = C.accent
    KeyInput.Font = Enum.Font.RobotoMono
    KeyInput.TextSize = 14
    KeyInput.TextXAlignment = Enum.TextXAlignment.Left
    KeyInput.ClearTextOnFocus = false
    KeyInput.Parent = InputContainer

    -- Input focus glow
    KeyInput.Focused:Connect(function()
        tweenProperty(inputStroke, {Color = C.accent}, 0.2)
    end)
    KeyInput.FocusLost:Connect(function()
        tweenProperty(inputStroke, {Color = C.border}, 0.2)
    end)

    -- ═══ BUTTONS ═══

    -- Verify Button (primary)
    BtnVerify = Instance.new("TextButton")
    BtnVerify.Name = "BtnVerify"
    BtnVerify.Size = UDim2.new(1, 0, 0, 44)
    BtnVerify.Position = UDim2.new(0, 0, 0, 192)
    BtnVerify.BackgroundColor3 = C.accent
    BtnVerify.BorderSizePixel = 0
    BtnVerify.Text = "Verify Key"
    BtnVerify.TextColor3 = C.bg
    BtnVerify.Font = Enum.Font.GothamBold
    BtnVerify.TextSize = 13
    BtnVerify.AutoButtonColor = false
    BtnVerify.Parent = ContentFrame
    createCorner(BtnVerify, 8)

    -- Get Key Button (secondary)
    BtnGetKey = Instance.new("TextButton")
    BtnGetKey.Name = "BtnGetKey"
    BtnGetKey.Size = UDim2.new(1, 0, 0, 44)
    BtnGetKey.Position = UDim2.new(0, 0, 0, 244)
    BtnGetKey.BackgroundColor3 = C.bgElevated
    BtnGetKey.BorderSizePixel = 0
    BtnGetKey.Text = "Get Key"
    BtnGetKey.TextColor3 = C.text2
    BtnGetKey.Font = Enum.Font.GothamBold
    BtnGetKey.TextSize = 13
    BtnGetKey.AutoButtonColor = false
    BtnGetKey.Parent = ContentFrame
    createCorner(BtnGetKey, 8)
    createStroke(BtnGetKey, C.border, 1)

    -- ═══ STATUS ═══

    -- Progress Bar
    local ProgressContainer = Instance.new("Frame")
    ProgressContainer.Name = "ProgressContainer"
    ProgressContainer.Size = UDim2.new(1, 0, 0, 3)
    ProgressContainer.Position = UDim2.new(0, 0, 0, 306)
    ProgressContainer.BackgroundColor3 = C.border
    ProgressContainer.BorderSizePixel = 0
    ProgressContainer.Visible = false
    ProgressContainer.Parent = ContentFrame
    createCorner(ProgressContainer, 2)

    ProgressFill = Instance.new("Frame")
    ProgressFill.Name = "Fill"
    ProgressFill.Size = UDim2.new(0, 0, 1, 0)
    ProgressFill.BackgroundColor3 = C.accent
    ProgressFill.BorderSizePixel = 0
    ProgressFill.Parent = ProgressContainer
    createCorner(ProgressFill, 2)

    ProgressBar = ProgressContainer

    -- Status Text
    StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "Status"
    StatusLabel.Size = UDim2.new(1, 0, 0, 18)
    StatusLabel.Position = UDim2.new(0, 0, 0, 318)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = ""
    StatusLabel.TextColor3 = C.text3
    StatusLabel.Font = Enum.Font.RobotoMono
    StatusLabel.TextSize = 11
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.TextWrapped = true
    StatusLabel.Parent = ContentFrame

    StatusSub = Instance.new("TextLabel")
    StatusSub.Name = "StatusSub"
    StatusSub.Size = UDim2.new(1, 0, 0, 14)
    StatusSub.Position = UDim2.new(0, 0, 0, 338)
    StatusSub.BackgroundTransparency = 1
    StatusSub.Text = ""
    StatusSub.TextColor3 = C.text4
    StatusSub.Font = Enum.Font.RobotoMono
    StatusSub.TextSize = 10
    StatusSub.TextXAlignment = Enum.TextXAlignment.Left
    StatusSub.TextWrapped = true
    StatusSub.Parent = ContentFrame

    -- ═══ FOOTER ═══

    FooterLabel = Instance.new("TextLabel")
    FooterLabel.Name = "Footer"
    FooterLabel.Size = UDim2.new(1, 0, 0, 14)
    FooterLabel.Position = UDim2.new(0, 0, 1, -46)
    FooterLabel.BackgroundTransparency = 1
    FooterLabel.Text = "ZUSYNI Studio / Access Gate"
    FooterLabel.TextColor3 = C.text4
    FooterLabel.Font = Enum.Font.RobotoMono
    FooterLabel.TextSize = 9
    FooterLabel.TextXAlignment = Enum.TextXAlignment.Center
    FooterLabel.Parent = ContentFrame

    -- ═══ RESPONSIVE ═══

    if UserInputService.TouchEnabled then
        WINDOW_W = math.min(WINDOW_W, workspace.CurrentCamera.ViewportSize.X - 32)
        WINDOW_H = math.min(WINDOW_H, workspace.CurrentCamera.ViewportSize.Y - 80)
        MainFrame.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
        MainFrame.Position = UDim2.new(0.5, -WINDOW_W/2, 0.5, -WINDOW_H/2)
    end
end

-- ═══════════════════════════════════════════
-- DRAG SYSTEM
-- ═══════════════════════════════════════════

local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart, startPos

    handle = handle or frame

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ═══════════════════════════════════════════
-- BUTTON HOVER EFFECTS
-- ═══════════════════════════════════════════

local function setupBtnHover(btn, normalColor, hoverColor)
    btn.MouseEnter:Connect(function()
        tweenProperty(btn, {BackgroundColor3 = hoverColor}, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tweenProperty(btn, {BackgroundColor3 = normalColor}, 0.15)
    end)
end

-- ═══════════════════════════════════════════
-- STATUS MANAGEMENT
-- ═══════════════════════════════════════════

local function setStatus(text, color, sub)
    if StatusLabel then
        StatusLabel.Text = text or ""
        StatusLabel.TextColor3 = color or C.text3
    end
    if StatusSub then
        StatusSub.Text = sub or ""
    end
end

local function showProgress(visible)
    if ProgressBar then
        ProgressBar.Visible = visible
        if visible then
            ProgressFill.Size = UDim2.new(0, 0, 1, 0)
        end
    end
end

local function animateProgress(targetScale, duration)
    if ProgressFill then
        tweenProperty(ProgressFill, {Size = UDim2.new(targetScale, 0, 1, 0)}, duration or 0.5)
    end
end

local function setButtonsEnabled(enabled)
    if BtnVerify then
        BtnVerify.Active = enabled
        BtnVerify.BackgroundColor3 = enabled and C.accent or C.text4
    end
    if BtnGetKey then
        BtnGetKey.Active = enabled
    end
end

-- ═══════════════════════════════════════════
-- ENTRY ANIMATION
-- ═══════════════════════════════════════════

local function animateOpen()
    -- Overlay fade in
    tweenProperty(Overlay, {BackgroundTransparency = 0.5}, 0.4)

    -- Window entrance
    MainFrame.BackgroundTransparency = 1
    MainFrame.Size = UDim2.new(0, WINDOW_W * 0.92, 0, WINDOW_H * 0.92)
    MainFrame.Position = UDim2.new(0.5, -(WINDOW_W*0.92)/2, 0.5, -(WINDOW_H*0.92)/2 + 20)

    -- Set all children invisible initially
    for _, child in ipairs(MainFrame:GetDescendants()) do
        if child:IsA("Frame") and child.Name ~= "Shadow" then
            child.BackgroundTransparency = 1
        elseif child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
            child.TextTransparency = 1
            if child:IsA("Frame") or child.BackgroundTransparency ~= 1 then
                child.BackgroundTransparency = 1
            end
        end
    end

    task.wait(0.05)

    -- Animate main frame
    tweenProperty(MainFrame, {
        BackgroundTransparency = 0,
        Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
        Position = UDim2.new(0.5, -WINDOW_W/2, 0.5, -WINDOW_H/2),
    }, 0.5, Enum.EasingStyle.Quint)

    task.wait(0.15)

    -- Fade in all children sequentially
    local delay = 0
    for _, child in ipairs(MainFrame:GetDescendants()) do
        if child:IsA("Frame") and child.Name ~= "Shadow" and child.Name ~= "Fill" then
            task.delay(delay, function()
                tweenProperty(child, {BackgroundTransparency = 0}, 0.3)
            end)
            delay = delay + 0.02
        elseif child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
            task.delay(delay, function()
                tweenProperty(child, {TextTransparency = 0}, 0.3)
                if child:IsA("TextButton") or child:IsA("Frame") then
                    tweenProperty(child, {BackgroundTransparency = 0}, 0.3)
                end
            end)
            delay = delay + 0.025
        end
    end

    -- Fix backgrounds that should be transparent
    task.delay(delay + 0.1, function()
        for _, child in ipairs(MainFrame:GetDescendants()) do
            if child:IsA("TextLabel") then
                child.BackgroundTransparency = 1
            end
        end
        ContentFrame.BackgroundTransparency = 1
        Overlay.BackgroundTransparency = 0.5
        GlowFrame.ImageTransparency = 0.6

        -- Restore button states
        BtnVerify.BackgroundTransparency = 0
        BtnGetKey.BackgroundTransparency = 0
    end)
end

-- ═══════════════════════════════════════════
-- EXIT ANIMATION
-- ═══════════════════════════════════════════

local function animateClose(callback)
    tweenProperty(Overlay, {BackgroundTransparency = 1}, 0.3)
    tweenProperty(MainFrame, {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, WINDOW_W * 0.95, 0, WINDOW_H * 0.95),
        Position = UDim2.new(0.5, -(WINDOW_W*0.95)/2, 0.5, -(WINDOW_H*0.95)/2 + 10),
    }, 0.35, Enum.EasingStyle.Quint)

    for _, child in ipairs(MainFrame:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
            tweenProperty(child, {TextTransparency = 1}, 0.2)
        end
        if child:IsA("Frame") then
            tweenProperty(child, {BackgroundTransparency = 1}, 0.2)
        end
    end

    task.delay(0.4, function()
        if ScreenGui then
            ScreenGui:Destroy()
        end
        if callback then callback() end
    end)
end

-- ═══════════════════════════════════════════
-- SUCCESS ANIMATION
-- ═══════════════════════════════════════════

local function animateSuccess()
    local accentLine = MainFrame:FindFirstChild("AccentLine")
    if accentLine then
        tweenProperty(accentLine, {BackgroundColor3 = C.green}, 0.3)
    end

    setStatus("Access verified", C.green, "Loading script...")
    showProgress(true)
    animateProgress(1, 0.8)

    local mainStroke = MainFrame:FindFirstChildWhichIsA("UIStroke")
    if mainStroke then
        tweenProperty(mainStroke, {Color = C.green}, 0.3)
        task.delay(1.2, function()
            tweenProperty(mainStroke, {Color = C.border}, 0.3)
        end)
    end

    pcall(function()
        if UserInputService.TouchEnabled then
            game:GetService("HapticService"):SetMotor(
                Enum.UserInputType.Gamepad1,
                Enum.VibrationMotor.Large, 0.5
            )
        end
    end)
end

-- ═══════════════════════════════════════════
-- CORE LOGIC
-- ═══════════════════════════════════════════

local function verifyAndLoad(key, silent)
    if not silent then
        setStatus("Verifying key...", C.text2)
        showProgress(true)
        animateProgress(0.5, 0.6)
        setButtonsEnabled(false)
    end

    local data, err = apiVerifyKey(key)

    if data and data.success and data.valid then
        saveKey(key, data.expiresAt)

        if not silent then
            animateProgress(1, 0.3)
            animateSuccess()
            task.wait(1.5)
        end

        _G.ZUSYNI_ACCESS = true

        if not silent then
            animateClose(function()
                notify("Access granted. Script loading.", 3)
            end)
        else
            if ScreenGui then ScreenGui:Destroy() end
            notify("Access verified. Loading...", 3)
        end

        return true
    else
        if not silent then
            showProgress(false)
            local reason = (data and data.reason) or "unknown"
            local messages = {
                invalid_or_expired = "Invalid or expired key.",
                revoked = "This key has been revoked.",
                expired = "This key has expired.",
                missing_key = "Please enter a key.",
            }
            setStatus(messages[reason] or "Invalid key.", C.red, "Check your key and try again.")
            setButtonsEnabled(true)

            local inputCont = ContentFrame:FindFirstChild("InputContainer")
            if inputCont then
                local origPos = inputCont.Position
                for i = 1, 3 do
                    tweenProperty(inputCont, {Position = origPos + UDim2.new(0, 6, 0, 0)}, 0.04)
                    task.wait(0.04)
                    tweenProperty(inputCont, {Position = origPos + UDim2.new(0, -6, 0, 0)}, 0.04)
                    task.wait(0.04)
                end
                tweenProperty(inputCont, {Position = origPos}, 0.04)
            end
        else
            deleteSavedKey()
        end

        return false
    end
end

local function handleGetKey()
    setStatus("Creating session...", C.text2)
    setButtonsEnabled(false)
    showProgress(true)
    animateProgress(0.4, 0.5)

    local data, err = apiCreateSession()

    if data and data.success and data.getKeyUrl then
        animateProgress(1, 0.3)
        showProgress(false)

        pcall(function()
            setclipboard(data.getKeyUrl)
        end)

        setStatus("Session URL copied to clipboard", C.green, "Open the URL in your browser to get your key.")
        BtnGetKey.Text = "URL Copied"
        task.delay(3, function()
            if BtnGetKey then
                BtnGetKey.Text = "Get Key"
            end
        end)

        setButtonsEnabled(true)
        notify("Get Key URL copied. Open it in browser.", 5)
    else
        showProgress(false)
        setStatus("Failed to create session.", C.red, err or "Check connection and try again.")
        setButtonsEnabled(true)
    end
end

-- ═══════════════════════════════════════════
-- MAIN
-- ═══════════════════════════════════════════

local function main()
    if not httpRequest then
        notify("No HTTP support. Key system unavailable.", 5)
        _G.ZUSYNI_LOADED = false
        return
    end

    local savedKey = loadSavedKey()
    if savedKey then
        notify("Checking saved key...", 2)
        local valid = verifyAndLoad(savedKey, true)
        if valid then
            return
        end
    end

    buildUI()
    makeDraggable(MainFrame, MainFrame:FindFirstChild("Header"))

    setupBtnHover(BtnVerify, C.accent, C.accent2)
    setupBtnHover(BtnGetKey, C.bgElevated, C.bgHover)
    setupBtnHover(BtnClose, C.bgElevated, C.redDim)

    animateOpen()

    BtnVerify.MouseButton1Click:Connect(function()
        if not BtnVerify.Active then return end

        local key = KeyInput.Text
        key = key:match("^%s*(.-)%s*$") -- trim

        if key == "" then
            setStatus("Please enter a key.", C.yellow)
            return
        end

        if not key:match("^ZUSYNI%-") then
            setStatus("Invalid key format.", C.red, "Key should start with ZUSYNI-")
            return
        end

        verifyAndLoad(key, false)
    end)

    BtnGetKey.MouseButton1Click:Connect(function()
        if not BtnGetKey.Active then return end
        handleGetKey()
    end)

    BtnClose.MouseButton1Click:Connect(function()
        animateClose(function()
            _G.ZUSYNI_LOADED = false
            _G.ZUSYNI_ACCESS = false
        end)
    end)

    KeyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            BtnVerify.MouseButton1Click:Fire()
        end
    end)
end

local ok, err = pcall(main)
if not ok then
    warn("[ZUSYNI] Error: " .. tostring(err))
    _G.ZUSYNI_LOADED = false
    notify("ZUSYNI Loader error. Check console.", 4)
end
