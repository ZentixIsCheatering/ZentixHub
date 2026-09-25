-- ============================================================
-- ZentixWare v1.0 — Combat Hub for RIVALS / Arsenal
-- Pure black GUI, Drawing API ESP, adaptive executor support
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================================
-- EXECUTOR DETECTION
-- ============================================================
local Env = {
    Executor = identifyexecutor and identifyexecutor() or "Unknown",
    HasDrawing = pcall(function() return Drawing.new("Line") end),
    HasHook = type(hookmetamethod) == "function" and type(newcclosure) == "function",
    HasGetGC = type(getgc) == "function",
    HasConnections = type(getconnections) == "function",
}

print(string.format("[ZentixWare] Loaded on %s | Drawing:%s Hook:%s", 
    Env.Executor, tostring(Env.HasDrawing), tostring(Env.HasHook)))

-- ============================================================
-- ANTI-DETECTION LAYER (universal, non-invasive)
-- ============================================================
local function InitAntiDetection()
    if not Env.HasHook then return end

    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        -- Block anti-cheat kick patterns
        if method == "Kick" and not checkcaller() then
            return nil
        end

        -- Block common anti-cheat remotes
        if method == "FireServer" then
            local name = tostring(self)
            if name:lower():find("ac") or name:lower():find("detect") 
               or name:lower():find("ban") or name:lower():find("report") then
                return
            end
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
    print("[ZentixWare] Anti-detection hooks installed")
end

InitAntiDetection()

-- ============================================================
-- GLOBAL SETTINGS
-- ============================================================
local Settings = {
    -- ESP
    ESPEnabled = false,
    ShowBox = true,
    ShowSkeleton = false,
    ShowName = true,
    ShowHeadCircle = true,
    ShowHealthBar = true,
    ShowDistance = false,
    ESPColor = Color3.fromRGB(255, 50, 50),
    TeamCheck = true,
    MaxDistance = 500,

    -- Aimbot
    AimbotEnabled = false,
    SilentAim = false,
    AimSmoothness = 0.15,
    AimFOV = 120,
    AimPart = "Head",
}

-- ============================================================
-- DRAWING MANAGER
-- ============================================================
local Drawings = {}

local function NewDrawing(type, props)
    if not Env.HasDrawing then return nil end
    local d = Drawing.new(type)
    if props then
        for k, v in pairs(props) do
            pcall(function() d[k] = v end)
        end
    end
    return d
end

local function CleanupPlayer(player)
    if Drawings[player] then
        for _, obj in pairs(Drawings[player]) do
            if obj and obj.Remove then obj:Remove() end
        end
        Drawings[player] = nil
    end
end

local function CreatePlayerDrawings(player)
    if Drawings[player] then return end
    
    Drawings[player] = {
        Box = NewDrawing("Square", {
            Thickness = 1,
            Filled = false,
            Color = Settings.ESPColor,
            Visible = false
        }),
        Name = NewDrawing("Text", {
            Size = 14,
            Center = true,
            Outline = true,
            Font = 2,
            Color = Color3.fromRGB(255, 255, 255),
            Visible = false
        }),
        HeadCircle = NewDrawing("Circle", {
            Thickness = 1,
            NumSides = 32,
            Filled = false,
            Color = Settings.ESPColor,
            Visible = false
        }),
        HealthBar = NewDrawing("Line", {
            Thickness = 2,
            Color = Color3.fromRGB(0, 255, 0),
            Visible = false
        }),
        Skeleton = {},
        Distance = NewDrawing("Text", {
            Size = 12,
            Center = true,
            Outline = true,
            Font = 2,
            Color = Color3.fromRGB(200, 200, 200),
            Visible = false
        })
    }
end

-- ============================================================
-- SKELETON BONES
-- ============================================================
local SKELETON_BONES = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}

local function CreateSkeletonLines(player)
    if not Drawings[player] or Drawings[player].Skeleton[1] then return end
    for i = 1, #SKELETON_BONES do
        Drawings[player].Skeleton[i] = NewDrawing("Line", {
            Thickness = 1,
            Color = Settings.ESPColor,
            Visible = false
        })
    end
end

-- ============================================================
-- ESP UPDATE LOOP
-- ============================================================
local function IsValidTarget(player)
    if player == LocalPlayer then return false end
    if not player.Character then return false end
    local char = player.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if Settings.TeamCheck and player.Team == LocalPlayer.Team then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    if (Camera.CFrame.Position - root.Position).Magnitude > Settings.MaxDistance then return false end
    return true
end

local function GetPartPosition(char, name)
    local p = char:FindFirstChild(name)
    if p and p:IsA("BasePart") then
        local sp, onScreen = Camera:WorldToViewportPoint(p.Position)
        if onScreen then return Vector2.new(sp.X, sp.Y) end
    end
    return nil
end

local function UpdateESP()
    if not Env.HasDrawing then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if not IsValidTarget(player) then
            if Drawings[player] then
                for _, d in pairs(Drawings[player]) do
                    if type(d) == "table" then
                        for _, sub in pairs(d) do sub.Visible = false end
                    else d.Visible = false end
                end
            end
            continue
        end

        CreatePlayerDrawings(player)
        CreateSkeletonLines(player)
        local d = Drawings[player]
        local char = player.Character
        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not root or not head then continue end

        local rootSP, rootOnScreen = Camera:WorldToViewportPoint(root.Position)
        local headSP, headOnScreen = Camera:WorldToViewportPoint(head.Position)

        -- Box
        if Settings.ShowBox and d.Box then
            local dist = (Camera.CFrame.Position - root.Position).Magnitude
            local height = math.clamp(2000 / dist, 30, 300)
            local width = height * 0.55
            d.Box.Size = Vector2.new(width, height)
            d.Box.Position = Vector2.new(rootSP.X - width/2, rootSP.Y - height/2)
            d.Box.Color = Settings.ESPColor
            d.Box.Visible = rootOnScreen
        end

        -- Name
        if Settings.ShowName and d.Name then
            d.Name.Text = player.Name
            d.Name.Position = Vector2.new(headSP.X, headSP.Y - 20)
            d.Name.Color = Color3.fromRGB(255, 255, 255)
            d.Name.Visible = headOnScreen
        end

        -- Head circle
        if Settings.ShowHeadCircle and d.HeadCircle then
            local headPos = GetPartPosition(char, "Head")
            if headPos then
                d.HeadCircle.Position = headPos
                d.HeadCircle.Radius = 18
                d.HeadCircle.Color = Settings.ESPColor
                d.HeadCircle.Visible = true
            else
                d.HeadCircle.Visible = false
            end
        end

        -- Health bar
        if Settings.ShowHealthBar and d.HealthBar then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and rootOnScreen then
                local healthPct = hum.Health / hum.MaxHealth
                local barHeight = 60
                local barY = rootSP.Y - barHeight/2
                d.HealthBar.From = Vector2.new(rootSP.X - 35, barY + barHeight)
                d.HealthBar.To = Vector2.new(rootSP.X - 35, barY + barHeight * (1 - healthPct))
                d.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPct), 255 * healthPct, 0)
                d.HealthBar.Visible = true
            else
                d.HealthBar.Visible = false
            end
        end

        -- Skeleton
        if Settings.ShowSkeleton then
            for i, bones in ipairs(SKELETON_BONES) do
                local line = d.Skeleton[i]
                if not line then continue end
                local p1 = GetPartPosition(char, bones[1])
                local p2 = GetPartPosition(char, bones[2])
                if p1 and p2 then
                    line.From = p1
                    line.To = p2
                    line.Color = Settings.ESPColor
                    line.Visible = true
                else
                    line.Visible = false
                end
            end
        else
            for _, line in pairs(d.Skeleton) do line.Visible = false end
        end

        -- Distance
        if Settings.ShowDistance and d.Distance then
            local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
            d.Distance.Text = dist .. "m"
            d.Distance.Position = Vector2.new(rootSP.X, rootSP.Y + 30)
            d.Distance.Visible = rootOnScreen
        end
    end
end

-- ============================================================
-- AIMBOT
-- ============================================================
local function GetClosestEnemy()
    local closest, shortest = nil, Settings.AimFOV
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, player in ipairs(Players:GetPlayers()) do
        if not IsValidTarget(player) then continue end
        local char = player.Character
        local part = char:FindFirstChild(Settings.AimPart)
        if not part then continue end

        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if dist < shortest then
            shortest = dist
            closest = player
        end
    end
    return closest
end

local function UpdateAimbot()
    if not Settings.AimbotEnabled then return end
    local target = GetClosestEnemy()
    if not target then return end
    local char = target.Character
    local part = char and char:FindFirstChild(Settings.AimPart)
    if not part then return end

    if Settings.SilentAim and Env.HasHook then
        -- Silent aim would go here (requires hooking __namecall for Fire)
        -- RIVALS/Arsenal silent aim is game-specific; skip for universal base
    else
        local desired = CFrame.new(Camera.CFrame.Position, part.Position)
        Camera.CFrame = Camera.CFrame:Lerp(desired, Settings.AimSmoothness)
    end
end

-- ============================================================
-- BLACK GUI
-- ============================================================
local function CreateGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FOX_Hub"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("CoreGui")

    -- Main frame
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 420, 0, 320)
    main.Position = UDim2.new(0.5, -210, 0.5, -160)
    main.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(40, 40, 40)
    mainStroke.Thickness = 1
    mainStroke.Parent = main

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "FOX // COMBAT"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Tab bar
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 30)
    tabBar.Position = UDim2.new(0, 10, 0, 42)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = main

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.Parent = tabBar

    -- Content area
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -80)
    content.Position = UDim2.new(0, 10, 0, 78)
    content.BackgroundTransparency = 1
    content.Parent = main

    local pages = {}

    -- Create page function
    local function CreatePage(name)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 2
        scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Visible = false
        scroll.Parent = content

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.Parent = scroll

        local page = { Frame = scroll, Layout = layout }
        pages[name] = page
        return page
    end

    -- Tab button function
    local activeTab = nil
    local function CreateTabButton(name)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 80, 0, 26)
        btn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(150, 150, 150)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamMedium
        btn.Parent = tabBar

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            if activeTab == name then return end
            for n, page in pairs(pages) do page.Frame.Visible = (n == name) end
            for _, child in ipairs(tabBar:GetChildren()) do
                if child:IsA("TextButton") then
                    child.TextColor3 = child.Text == name and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
                    child.BackgroundColor3 = child.Text == name and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(15, 15, 15)
                end
            end
            activeTab = name
        end)
        return btn
    end

    -- Toggle button factory
    local function CreateToggle(parent, text, getter, setter)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        btn.Text = text .. "  [" .. (getter() and "ON" or "OFF") .. "]"
        btn.TextColor3 = getter() and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(180, 180, 180)
        btn.TextSize = 13
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.Parent = btn

        btn.MouseButton1Click:Connect(function()
            setter(not getter())
            btn.Text = text .. "  [" .. (getter() and "ON" or "OFF") .. "]"
            btn.TextColor3 = getter() and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(180, 180, 180)
        end)
        return btn
    end

    -- Create tabs
    CreatePage("ESP")
    CreatePage("Aimbot")
    CreatePage("Misc")

    CreateTabButton("ESP")
    CreateTabButton("Aimbot")
    CreateTabButton("Misc")

    -- ESP page
    local espPage = pages["ESP"]
    CreateToggle(espPage.Frame, "Enable ESP", function() return Settings.ESPEnabled end, function(v) Settings.ESPEnabled = v end)
    CreateToggle(espPage.Frame, "Box", function() return Settings.ShowBox end, function(v) Settings.ShowBox = v end)
    CreateToggle(espPage.Frame, "Skeleton", function() return Settings.ShowSkeleton end, function(v) Settings.ShowSkeleton = v end)
    CreateToggle(espPage.Frame, "Name Tags", function() return Settings.ShowName end, function(v) Settings.ShowName = v end)
    CreateToggle(espPage.Frame, "Head Circle", function() return Settings.ShowHeadCircle end, function(v) Settings.ShowHeadCircle = v end)
    CreateToggle(espPage.Frame, "Health Bar", function() return Settings.ShowHealthBar end, function(v) Settings.ShowHealthBar = v end)
    CreateToggle(espPage.Frame, "Distance", function() return Settings.ShowDistance end, function(v) Settings.ShowDistance = v end)
    CreateToggle(espPage.Frame, "Team Check", function() return Settings.TeamCheck end, function(v) Settings.TeamCheck = v end)

    -- Aimbot page
    local aimPage = pages["Aimbot"]
    CreateToggle(aimPage.Frame, "Enable Aimbot", function() return Settings.AimbotEnabled end, function(v) Settings.AimbotEnabled = v end)
    CreateToggle(aimPage.Frame, "Silent Aim", function() return Settings.SilentAim end, function(v) Settings.SilentAim = v end)

    -- Misc page
    local miscPage = pages["Misc"]
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0, 60)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Executor: " .. Env.Executor .. "\nDrawing: " .. tostring(Env.HasDrawing) .. "\nHook: " .. tostring(Env.HasHook)
    infoLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    infoLabel.TextSize = 12
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.Parent = miscPage.Frame

    -- Show first tab
    pages["ESP"].Frame.Visible = true
    activeTab = "ESP"
    for _, child in ipairs(tabBar:GetChildren()) do
        if child:IsA("TextButton") and child.Text == "ESP" then
            child.TextColor3 = Color3.fromRGB(255, 255, 255)
            child.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        end
    end

    return screenGui
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local gui = CreateGUI()

local espConnection = RunService.RenderStepped:Connect(function()
    if Settings.ESPEnabled then
        UpdateESP()
    else
        -- Hide all drawings when disabled
        for _, d in pairs(Drawings) do
            for _, obj in pairs(d) do
                if type(obj) == "table" then
                    for _, sub in pairs(obj) do sub.Visible = false end
                else obj.Visible = false end
            end
        end
    end
    UpdateAimbot()
end)

-- Player cleanup
Players.PlayerRemoving:Connect(CleanupPlayer)

print("[ZentixWare] Ready.")
