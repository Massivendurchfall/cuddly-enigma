local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VoiceChatService = game:GetService("VoiceChatService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Voice Ban Bypasser",
    LoadingTitle = "Voice Ban Bypasser",
    LoadingSubtitle = "by jlcfg",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RayfieldScript_MicUp",
        FileName = "Config"
    },
    Discord = { Enabled = false, Invite = "", RememberJoins = true },
    KeySystem = false
})

local Tabs = {
    Player = Window:CreateTab("Player"),
    ESP = Window:CreateTab("ESP"),
    Voice = Window:CreateTab("Voice"),
    Info = Window:CreateTab("Info")
}

local function reEnableMovement()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if root then root.Anchored = false end
        if hum then hum.PlatformStand = false hum.Sit = false end
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        Workspace.CurrentCamera.CameraSubject = hum
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
end)

local flySpeed = 50
local flyBodyVelocity
local flyBodyGyro
local flyConnection

local function setWalkSpeed(speed)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = speed
    end
end

function enableFly()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local root = char.HumanoidRootPart
        if not flyBodyVelocity then
            flyBodyVelocity = Instance.new("BodyVelocity", root)
            flyBodyVelocity.MaxForce = Vector3.new(1e5,1e5,1e5)
        end
        if not flyBodyGyro then
            flyBodyGyro = Instance.new("BodyGyro", root)
            flyBodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
        end
        flyBodyGyro.CFrame = root.CFrame
        if not flyConnection then
            flyConnection = RunService.RenderStepped:Connect(function()
                local dir = Vector3.new()
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Workspace.CurrentCamera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Workspace.CurrentCamera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Workspace.CurrentCamera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Workspace.CurrentCamera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0,1,0) end
                flyBodyVelocity.Velocity = (dir.Magnitude > 0 and dir.Unit * flySpeed) or Vector3.new()
                flyBodyGyro.CFrame = Workspace.CurrentCamera.CFrame
            end)
        end
    end
end

local function disableFly()
    if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
end

local noclipConn
local function enableNoclip()
    noclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            for _,p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
end

local function disableNoclip()
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
end

Tabs.Player:CreateParagraph({Title="Player Controls", Content=" "})

Tabs.Player:CreateSlider({
    Name = "Walk Speed",
    Range = {0,150},
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(v) setWalkSpeed(v) end
})

Tabs.Player:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "Fly",
    Callback = function(s) if s then enableFly() else disableFly() end end
})

Tabs.Player:CreateSlider({
    Name = "Fly Speed",
    Range = {0,300},
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = 50,
    Flag = "FlySpeed",
    Callback = function(v) flySpeed = v end
})

Tabs.Player:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(s) if s then enableNoclip() else disableNoclip() end end
})

local antiAfkConn
Tabs.Player:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = false,
    Flag = "AntiAFK",
    Callback = function(s)
        if s and not antiAfkConn then
            antiAfkConn = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        elseif not s and antiAfkConn then
            antiAfkConn:Disconnect()
            antiAfkConn = nil
        end
    end
})

local chamsActive = false
local chamsThroughWalls = true
local useTeamColors = false
local teamFilter = "All"
local chamsColor = Color3.new(1,1,1)
local teamFriendColor = Color3.fromRGB(0,255,0)
local teamEnemyColor = Color3.fromRGB(255,0,0)
local chamsTask
local ChamsPerPlayer = {}
local CharAddedConns = {}
local PlayerAddedConn
local PlayerRemovingConn

local function getTeamRelation(p)
    local lt = LocalPlayer.Team
    local pt = p.Team
    if not lt or not pt then return "All" end
    if lt == pt then return "Friend" else return "Enemy" end
end

local function resolveChamColorFor(p)
    if useTeamColors then
        local rel = getTeamRelation(p)
        if rel == "Friend" then return teamFriendColor else return teamEnemyColor end
    end
    return chamsColor
end

local function filterPass(p)
    if p == LocalPlayer then return false end
    if teamFilter == "All" then return true end
    local rel = getTeamRelation(p)
    if teamFilter == "Enemies" then return rel ~= "Friend" end
    if teamFilter == "Teammates" then return rel == "Friend" end
    return true
end

local function removeChamsFor(player)
    if ChamsPerPlayer[player] and ChamsPerPlayer[player].hl then
        ChamsPerPlayer[player].hl:Destroy()
    end
    ChamsPerPlayer[player] = nil
    if CharAddedConns[player] then
        for _,c in ipairs(CharAddedConns[player]) do c:Disconnect() end
        CharAddedConns[player] = nil
    end
end

local function attachHighlightToCharacter(player, character)
    if not character or not character:IsDescendantOf(game) then return end
    if not filterPass(player) then return end
    local hl = character:FindFirstChild("ChamHighlight")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "ChamHighlight"
        hl.Adornee = character
        hl.DepthMode = chamsThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.Parent = character
    end
    local color = resolveChamColorFor(player)
    hl.FillColor = color
    hl.OutlineColor = color
    ChamsPerPlayer[player] = ChamsPerPlayer[player] or {}
    ChamsPerPlayer[player].hl = hl
end

local function trackPlayer(player)
    if player == LocalPlayer then return end
    local a = player.Character or player.CharacterAdded:Wait()
    attachHighlightToCharacter(player, a)
    CharAddedConns[player] = CharAddedConns[player] or {}
    table.insert(CharAddedConns[player], player.CharacterAdded:Connect(function(nc)
        task.wait(0.15)
        attachHighlightToCharacter(player, nc)
    end))
    table.insert(CharAddedConns[player], player.CharacterRemoving:Connect(function()
        removeChamsFor(player)
    end))
end

local function enableChams()
    if chamsTask then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if filterPass(p) then task.spawn(trackPlayer, p) end
    end
    PlayerAddedConn = Players.PlayerAdded:Connect(function(p)
        if filterPass(p) then task.spawn(trackPlayer, p) end
    end)
    PlayerRemovingConn = Players.PlayerRemoving:Connect(function(p)
        removeChamsFor(p)
    end)
    chamsTask = task.spawn(function()
        while chamsActive do
            for p, info in pairs(ChamsPerPlayer) do
                if p and p.Character and info.hl and info.hl.Parent then
                    local desired = resolveChamColorFor(p)
                    info.hl.FillColor = desired
                    info.hl.OutlineColor = desired
                    info.hl.DepthMode = chamsThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                end
            end
            task.wait(0.25)
        end
    end)
end

local function disableChams()
    if chamsTask then task.cancel(chamsTask) chamsTask = nil end
    if PlayerAddedConn then PlayerAddedConn:Disconnect() PlayerAddedConn = nil end
    if PlayerRemovingConn then PlayerRemovingConn:Disconnect() PlayerRemovingConn = nil end
    for p,_ in pairs(ChamsPerPlayer) do removeChamsFor(p) end
end

local SkeletonConnections = {
    {"Head","UpperTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},
    {"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},
    {"RightLowerArm","RightHand"},{"UpperTorso","LowerTorso"},{"LowerTorso","LeftUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},
    {"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
}
local skeletonESPEnabled = false
local skeletonESPColor = Color3.new(1,0,0)
local SkeletonESPs = {}

local function CreateSkeletonForPlayer(player)
    local drawings = {}
    for i = 1, #SkeletonConnections do
        local line = Drawing.new("Line")
        line.Visible = true
        line.Transparency = 1
        line.Color = skeletonESPColor
        line.Thickness = 2
        drawings[i] = line
    end
    SkeletonESPs[player] = drawings
end

local function UpdateSkeletonESP(player)
    if not SkeletonESPs[player] then CreateSkeletonForPlayer(player) end
    local drawings = SkeletonESPs[player]
    local char = player.Character
    if char then
        for i, conn in ipairs(SkeletonConnections) do
            local partA = char:FindFirstChild(conn[1])
            local partB = char:FindFirstChild(conn[2])
            if partA and partB then
                local a,onA = Workspace.CurrentCamera:WorldToViewportPoint(partA.Position)
                local b,onB = Workspace.CurrentCamera:WorldToViewportPoint(partB.Position)
                if onA and onB then
                    local line = drawings[i]
                    line.Visible = true
                    line.From = Vector2.new(a.X,a.Y)
                    line.To = Vector2.new(b.X,b.Y)
                    line.Color = skeletonESPColor
                else
                    drawings[i].Visible = false
                end
            else
                drawings[i].Visible = false
            end
        end
    end
end

local NametagsActive = false
local nametagTask

local function CreateNametag(p)
    local bill = Instance.new("BillboardGui")
    bill.Name = "Nametag"
    bill.Size = UDim2.new(0,50,0,50)
    bill.StudsOffset = Vector3.new(0,2,0)
    bill.AlwaysOnTop = true
    local frame = Instance.new("Frame", bill)
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = p.Name
    lbl.TextScaled = false
    lbl.TextSize = 14
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = chamsColor
    lbl.TextStrokeTransparency = 0.3
    return bill
end

local function UpdateNametags()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and filterPass(p) and p.Character and p.Character:FindFirstChild("Head") then
            local head = p.Character.Head
            if not head:FindFirstChild("Nametag") then
                local tag = CreateNametag(p)
                tag.Parent = head
            else
                local tag = head:FindFirstChild("Nametag")
                local lbl = tag and tag:FindFirstChildWhichIsA("TextLabel", true)
                if lbl then
                    local color = resolveChamColorFor(p)
                    lbl.TextColor3 = color
                end
            end
        end
    end
end

local function RemoveNametags()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Head") then
            local tag = p.Character.Head:FindFirstChild("Nametag")
            if tag then tag:Destroy() end
        end
    end
end

Tabs.ESP:CreateParagraph({Title="ESP / Chams / Nametags", Content=" "})

local ChamsToggle = Tabs.ESP:CreateToggle({
    Name = "Chams",
    CurrentValue = false,
    Flag = "Chams",
    Callback = function(s) chamsActive = s if s then enableChams() else disableChams() end end
})

Tabs.ESP:CreateColorPicker({
    Name = "Chams Color",
    Color = Color3.new(1,1,1),
    Flag = "ChamsColor",
    Callback = function(c) chamsColor = c end
})

Tabs.ESP:CreateToggle({
    Name = "Through Walls",
    CurrentValue = true,
    Flag = "ThroughWalls",
    Callback = function(s) chamsThroughWalls = s end
})

Tabs.ESP:CreateDropdown({
    Name = "Team Filter",
    Options = {"All","Enemies","Teammates"},
    CurrentOption = "All",
    Flag = "TeamFilter",
    Callback = function(v)
        teamFilter = typeof(v) == "table" and v[1] or v
        if chamsActive then disableChams() enableChams() end
        if NametagsActive then RemoveNametags() UpdateNametags() end
    end
})

Tabs.ESP:CreateToggle({
    Name = "Use Team Colors",
    CurrentValue = false,
    Flag = "UseTeamColors",
    Callback = function(s) useTeamColors = s end
})

Tabs.ESP:CreateColorPicker({
    Name = "Friend Color",
    Color = teamFriendColor,
    Flag = "FriendColor",
    Callback = function(c) teamFriendColor = c end
})

Tabs.ESP:CreateColorPicker({
    Name = "Enemy Color",
    Color = teamEnemyColor,
    Flag = "EnemyColor",
    Callback = function(c) teamEnemyColor = c end
})

local SkeletonToggle = Tabs.ESP:CreateToggle({
    Name = "Skeleton ESP",
    CurrentValue = false,
    Flag = "SkeletonESP",
    Callback = function(s)
        local was = skeletonESPEnabled
        skeletonESPEnabled = s
        if not s and was then
            for _, lines in pairs(SkeletonESPs) do for _, l in ipairs(lines) do l:Remove() end end
            SkeletonESPs = {}
        end
    end
})

Tabs.ESP:CreateColorPicker({
    Name = "Skeleton Color",
    Color = Color3.new(1,0,0),
    Flag = "SkeletonColor",
    Callback = function(c) skeletonESPColor = c end
})

Tabs.ESP:CreateToggle({
    Name = "Nametags",
    CurrentValue = false,
    Flag = "Nametags",
    Callback = function(s)
        NametagsActive = s
        if s then
            nametagTask = task.spawn(function()
                while NametagsActive do
                    UpdateNametags()
                    task.wait(0.75)
                end
            end)
        else
            if nametagTask then task.cancel(nametagTask) end
            RemoveNametags()
        end
    end
})

RunService.RenderStepped:Connect(function()
    if skeletonESPEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and filterPass(p) and p.Character then
                UpdateSkeletonESP(p)
            end
        end
    end
end)

Tabs.Voice:CreateParagraph({Title="Voice Chat", Content=" "})

local function isVoiceEligible()
    local ok, enabled = pcall(function()
        return VoiceChatService:IsVoiceEnabledForUserIdAsync(LocalPlayer.UserId)
    end)
    return ok and enabled
end

local function refreshVoice()
    if not isVoiceEligible() then
        Rayfield:Notify({Title="Voice Chat", Content="Voice is not enabled for this account or experience.", Duration=4})
        return
    end
    local left = pcall(function()
        if VoiceChatService.Leave then VoiceChatService:Leave() end
    end)
    task.wait(0.35)
    local joined = pcall(function()
        if VoiceChatService.joinVoice then VoiceChatService:joinVoice() end
    end)
    if joined then
        reEnableMovement()
        Rayfield:Notify({Title="Voice Chat", Content="Voice rejoined.", Duration=3})
    else
        Rayfield:Notify({Title="Voice Chat", Content="Join failed.", Duration=3})
    end
end

Tabs.Voice:CreateButton({
    Name = "Refresh Voice",
    Callback = function() refreshVoice() end
})

Tabs.Info:CreateParagraph({
    Title = "Info",
    Content = "★ Made by jlcfg ★\nDiscord: jlcfg\nhttps://discord.gg/2xDHnGg6J"
})

Rayfield:Notify({ Title = "Voice Ban Bypasser", Content = "Script loaded!", Duration = 5 })
Rayfield:LoadConfiguration()
