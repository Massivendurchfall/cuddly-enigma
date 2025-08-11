local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VoiceChatService = game:GetService("VoiceChatService")

local LocalPlayer = Players.LocalPlayer

-- Movement wieder aktivieren
local function reEnableMovement()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChild("Humanoid")
        if root then root.Anchored = false end
        if hum then
            hum.PlatformStand = false
            hum.Sit = false
        end
    end
end

-- Ring-Koordinaten
local collectCoords = {
    Vector3.new(3510.47, 177.41, 1198.01),
    Vector3.new(3432.29, 155.51, 1137.61),
    Vector3.new(3476.75, -126.64, 968.31),
    Vector3.new(3346.27, -106.83, 1133.09)
}

-- Status-Variablen
local autoCollectActive     = false
local autoCollectTask
local undergroundActive     = false
local undergroundTask

-- Auto-Collect Ringe
local function autoCollectMoney()
    enableFly()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return end
    for _, coord in ipairs(collectCoords) do
        root.CFrame = CFrame.new(coord)
        reEnableMovement()
        task.wait(0.05)
        root.CFrame = root.CFrame + Vector3.new(0, -3, 0)
        task.wait(0.1)
        root.CFrame = root.CFrame + Vector3.new(0, 6, 0)
        task.wait(0.5)
    end
end

-- Auto-Collect unterirdische Ringe
local function collectUnderground()
    enableFly()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return end
    for i = 3, 4 do
        root.CFrame = CFrame.new(collectCoords[i])
        reEnableMovement()
        task.wait(0.05)
        root.CFrame = root.CFrame + Vector3.new(0, -3, 0)
        task.wait(0.1)
        root.CFrame = root.CFrame + Vector3.new(0, 6, 0)
        task.wait(0.5)
    end
end

-- Kamera zurücksetzen beim Respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        Workspace.CurrentCamera.CameraSubject = hum
        Workspace.CurrentCamera.CameraType   = Enum.CameraType.Custom
    end
end)

-- Fenster & Tabs
local Window = Fluent:CreateWindow({
    Title       = "Voice Ban Bypasser",
    TabWidth    = 160,
    Size        = UDim2.fromOffset(580,460),
    Acrylic     = false,
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Player   = Window:AddTab({Title="Player",   Icon="user"}),
    Chams    = Window:AddTab({Title="ESP",      Icon="eye"}),
    Voice    = Window:AddTab({Title="Voice",    Icon="mic"}),
    Teleport = Window:AddTab({Title="Teleport", Icon="map"}),
    Spectate = Window:AddTab({Title="Spectate", Icon="camera"}),
    Info     = Window:AddTab({Title="Info",     Icon="heart"}),
    Settings = Window:AddTab({Title="Settings", Icon="settings"})
}

-- Grundwerte für Speed & Fly
local currentSpeed = 16
local flySpeed     = 50
local flyBodyVelocity, flyBodyGyro, flyConnection

-- Hilfsfunktionen
local function getRootPart(char)
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then pcall(function() root = char:WaitForChild("HumanoidRootPart",5) end) end
    return root
end

local function setWalkSpeed(speed)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = speed
    end
end

-- Fly aktivieren / deaktivieren
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
                flyBodyVelocity.Velocity = (dir.Magnitude>0 and dir.Unit*flySpeed) or Vector3.new()
                flyBodyGyro.CFrame      = Workspace.CurrentCamera.CFrame
            end)
        end
    end
end

local function disableFly()
    if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity=nil end
    if flyBodyGyro    then flyBodyGyro:Destroy()    flyBodyGyro=nil    end
    if flyConnection  then flyConnection:Disconnect() flyConnection=nil end
end

-- Noclip aktivieren / deaktivieren
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
    if noclipConn then noclipConn:Disconnect() noclipConn=nil end
end

-- Teleport & Spectate
local function TeleportToPlayer(plr)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = getRootPart(char)
    local tgt  = getRootPart(plr.Character or plr.CharacterAdded:Wait())
    if root and tgt then
        root.CFrame = tgt.CFrame
        reEnableMovement()
    end
end

local function SpectatePlayer(plr)
    local char = plr.Character or plr.CharacterAdded:Wait()
    local hum  = char:FindFirstChild("Humanoid")
    if hum then
        Workspace.CurrentCamera.CameraSubject = hum
        Workspace.CurrentCamera.CameraType   = Enum.CameraType.Custom
    end
end

local function StopSpectating()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum  = char:FindFirstChild("Humanoid")
    if hum then
        Workspace.CurrentCamera.CameraSubject = hum
        Workspace.CurrentCamera.CameraType   = Enum.CameraType.Custom
        reEnableMovement()
    end
end

-- Player Tab
do
    local sec = Tabs.Player:AddSection("Player Controls")
    sec:AddSlider("SpeedSlider", {Title="Walk Speed",Default=16,Min=0,Max=150,Rounding=0})
       :OnChanged(function(v) setWalkSpeed(v) end)
    sec:AddToggle("FlyToggle", {Title="Fly",Default=false})
       :OnChanged(function(s) if s then enableFly() else disableFly() end end)
    sec:AddSlider("FlySpeedSlider", {Title="Fly Speed",Default=50,Min=0,Max=300,Rounding=0})
       :OnChanged(function(v) flySpeed=v end)
    sec:AddToggle("NoclipToggle", {Title="Noclip",Default=false})
       :OnChanged(function(s) if s then enableNoclip() else disableNoclip() end end)

    sec:AddToggle("AutoCollectToggle", {Title="Auto Collect Rings",Default=false})
       :OnChanged(function(s)
           autoCollectActive = s
           if s then
               autoCollectTask = task.spawn(function()
                   while autoCollectActive do
                       autoCollectMoney()
                       task.wait(1)
                   end
               end)
           else
               if autoCollectTask then task.cancel(autoCollectTask) end
               if not undergroundActive then disableFly() end
           end
       end)

    sec:AddToggle("AutoCollectUndergroundToggle", {Title="Collect Underground Only",Default=false})
       :OnChanged(function(s)
           undergroundActive = s
           if s then
               undergroundTask = task.spawn(function()
                   while undergroundActive do
                       collectUnderground()
                       task.wait(1)
                   end
               end)
           else
               if undergroundTask then task.cancel(undergroundTask) end
               if not autoCollectActive then disableFly() end
           end
       end)

    local afk = Tabs.Player:AddSection("Anti AFK")
    afk:AddToggle("AntiAFKToggle", {Title="Anti AFK",Default=false})
       :OnChanged(function(s)
           if s then
               LocalPlayer.Idled:Connect(function()
                   game:GetService("VirtualUser"):CaptureController()
                   game:GetService("VirtualUser"):ClickButton2(Vector2.new())
               end)
           end
       end)
end

-- Chams / ESP / Nametags
do
    -- Chams
    local chamsColor    = Color3.new(1,1,1)
    local chamsActive   = false
    local chamsTask

    local function applyChams(chr)
        task.wait(0.1)
        if not chr or not chr:IsDescendantOf(game) then return end
        pcall(function()
            local hl = chr:FindFirstChild("ChamHighlight")
            if not hl then
                hl = Instance.new("Highlight")
                hl.Name               = "ChamHighlight"
                hl.Adornee            = chr
                hl.FillTransparency   = 0.5
                hl.OutlineTransparency= 0
                hl.Parent             = chr
            end
            hl.FillColor    = chamsColor
            hl.OutlineColor = chamsColor
        end)
    end

    local function updateChams()
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                applyChams(p.Character)
            end
        end
    end

    local function removeChams()
        for _,p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("ChamHighlight")
                if hl then hl:Destroy() end
            end
        end
    end

    -- Skeleton ESP
    local SkeletonConnections = {
        {"Head","UpperTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},
        {"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},
        {"RightLowerArm","RightHand"},{"UpperTorso","LowerTorso"},{"LowerTorso","LeftUpperLeg"},
        {"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},
        {"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
    }
    local skeletonESPEnabled = false
    local skeletonESPColor   = Color3.new(1,0,0)
    local SkeletonESPs       = {}

    local function CreateSkeletonForPlayer(player)
        local drawings = {}
        for i, conn in ipairs(SkeletonConnections) do
            local line = Drawing.new("Line")
            line.Visible      = true
            line.Transparency = 1
            line.Color       = skeletonESPColor
            line.Thickness   = 2
            drawings[i]      = line
        end
        SkeletonESPs[player] = drawings
    end

    local function UpdateSkeletonESP(player)
        if not SkeletonESPs[player] then CreateSkeletonForPlayer(player) end
        local drawings = SkeletonESPs[player]
        local char     = player.Character
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
                        line.From    = Vector2.new(a.X,a.Y)
                        line.To      = Vector2.new(b.X,b.Y)
                        line.Color   = skeletonESPColor
                    else
                        drawings[i].Visible = false
                    end
                else
                    drawings[i].Visible = false
                end
            end
        end
    end

    -- Nametags
    local NametagsActive = false
    local nametagTask

    local function CreateNametag(p)
        local bill = Instance.new("BillboardGui")
        bill.Name        = "Nametag"
        bill.Size        = UDim2.new(0,50,0,50)
        bill.StudsOffset = Vector3.new(0,2,0)
        bill.AlwaysOnTop = true
        local frame      = Instance.new("Frame", bill)
        frame.Size       = UDim2.new(1,0,1,0)
        frame.BackgroundTransparency = 1
        local lbl        = Instance.new("TextLabel", frame)
        lbl.Size        = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text         = p.Name
        lbl.TextScaled   = false
        lbl.TextSize     = 14
        lbl.Font         = Enum.Font.GothamBold
        lbl.TextColor3   = chamsColor
        lbl.TextStrokeTransparency = 0.3
        return bill
    end

    local function UpdateNametags()
        for _, p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
                local head = p.Character.Head
                if not head:FindFirstChild("Nametag") then
                    local tag = CreateNametag(p)
                    tag.Parent = head
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

    -- ESP-Section
    local sec = Tabs.Chams:AddSection("ESP / Chams / Nametags")
    sec:AddToggle("ChamsToggle",{Title="Chams",Default=false})
       :OnChanged(function(s)
           chamsActive = s
           if s then
               chamsTask = task.spawn(function()
                   while chamsActive do
                       updateChams()
                       task.wait(0.5)
                   end
               end)
           else
               if chamsTask then task.cancel(chamsTask) end
               removeChams()
           end
       end)
    sec:AddColorpicker("ChamsColor",{Title="Chams Color",Default=Color3.new(1,1,1)})
       :OnChanged(function(c) chamsColor = c end)

    sec:AddToggle("SkeletonESPToggle",{Title="Skeleton ESP",Default=false})
       :OnChanged(function(s)
           skeletonESPEnabled = s
           if not s then
               for _, lines in pairs(SkeletonESPs) do
                   for _, l in ipairs(lines) do l:Remove() end
               end
               SkeletonESPs = {}
           end
       end)
    sec:AddColorpicker("SkeletonESPColor",{Title="Skeleton Color",Default=Color3.new(1,0,0)})
       :OnChanged(function(c) skeletonESPColor = c end)
    RunService.RenderStepped:Connect(function()
        if skeletonESPEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character then
                    UpdateSkeletonESP(p)
                end
            end
        end
    end)

    sec:AddToggle("NametagsToggle",{Title="Nametags",Default=false})
       :OnChanged(function(s)
           NametagsActive = s
           if s then
               nametagTask = task.spawn(function()
                   while NametagsActive do
                       UpdateNametags()
                       task.wait(2)
                   end
               end)
           else
               if nametagTask then task.cancel(nametagTask) end
               RemoveNametags()
           end
       end)
end

-- Voice Tab
do
    local sec = Tabs.Voice:AddSection("Voice Chat")
    sec:AddButton({Title="Bypass Voiceban",Callback=function()
        if VoiceChatService and VoiceChatService.joinVoice then
            local ok,err = pcall(function() VoiceChatService:joinVoice() end)
            if not ok then warn("Voice join failed: "..tostring(err)) end
            reEnableMovement()
        end
    end})
    local auto = false
    sec:AddToggle("AutoVoiceJoin",{Title="Auto Join",Default=false})
       :OnChanged(function(s)
           auto = s
           if s then
               task.spawn(function()
                   while auto do
                       if not pcall(function() return VoiceChatService.Running end) then
                           pcall(function() VoiceChatService:joinVoice() end)
                       end
                       reEnableMovement()
                       task.wait(5)
                   end
               end)
           end
       end)
end

-- Teleport Tab
do
    local sec = Tabs.Teleport:AddSection("Teleport Players")
    local buttons = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then
            buttons[p.UserId] = sec:AddButton({
                Title = p.Name,
                Callback = function() TeleportToPlayer(p) end
            })
        end
    end
    Players.PlayerAdded:Connect(function(p)
        if p~=LocalPlayer then
            buttons[p.UserId] = sec:AddButton({
                Title = p.Name,
                Callback = function() TeleportToPlayer(p) end
            })
        end
    end)
    Players.PlayerRemoving:Connect(function(p)
        if buttons[p.UserId] then buttons[p.UserId]:Remove(); buttons[p.UserId]=nil end
    end)
end

-- Spectate Tab
do
    local sec = Tabs.Spectate:AddSection("Spectate Players")
    sec:AddButton({Title="Stop Spectate",Callback=StopSpectating})
    local buttons = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then
            buttons[p.UserId] = sec:AddButton({
                Title=p.Name,
                Callback=function() SpectatePlayer(p) end
            })
        end
    end
    Players.PlayerAdded:Connect(function(p)
        if p~=LocalPlayer then
            buttons[p.UserId] = sec:AddButton({
                Title=p.Name,
                Callback=function() SpectatePlayer(p) end
            })
        end
    end)
    Players.PlayerRemoving:Connect(function(p)
        if buttons[p.UserId] then buttons[p.UserId]:Remove(); buttons[p.UserId]=nil end
    end)
end

-- Info Tab
Tabs.Info:AddSection("Info"):AddParagraph({
    Title="Info",
    Content="★ Made by massivendurchfall ★\nDiscord: massivendurchfall\nhttps://discord.gg/2xDHnGg6J"
})

-- Settings Tab
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub_MicUp")
SaveManager:SetFolder("FluentScriptHub_MicUp/configs")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Fluent:Notify({Title="Voice Ban Bypasser",Content="Script Loaded!",Duration=5})
Window:SelectTab(1)
