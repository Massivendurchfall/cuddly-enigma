
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local TextChatService = game:GetService("TextChatService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isGuiVisible = true

local Window = Fluent:CreateWindow({
    Title = "Banana Eats Script",
    SubTitle = "by Massivendurchfall",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = isMobile and nil or Enum.KeyCode.LeftControl
})

local Tabs = {
    ESP = Window:AddTab({ Title = "ESP", Icon = "eye" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Auto = Window:AddTab({ Title = "Auto", Icon = "zap" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "sun" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local cakeEspActive, cakeEspLoop = false, nil
local cakeEspColor = Color3.fromRGB(255, 255, 0)

local coinEspActive, coinEspLoop = false, nil
local coinEspColor = Color3.fromRGB(0, 255, 0)

local chamsActive, chamsLoop = false, nil
local enemyChamColor = Color3.fromRGB(255, 0, 0)
local teamChamColor = Color3.fromRGB(0, 255, 0)

local nametagActive, nametagLoop = false, nil

local valveEspActive, valveEspLoop = false, nil
local valveEspColor = Color3.fromRGB(0, 255, 255)

local puzzleNumberEspActive, puzzleNumberEspLoop = false, nil
local puzzleNumberEspColor = Color3.fromRGB(255, 255, 255)
local puzzleNumbers = {["23"] = true, ["34"] = true, ["31"] = true}

local puzzleEspActive, puzzleEspLoop = false, nil
local puzzleEspColor = Color3.fromRGB(0, 255, 0)

local speedLoop = nil
local currentSpeed = 16

local flyActive = false
local flySpeed = 50
local flyBodyVelocity, flyBodyGyro, flyConnection = nil, nil, nil

-- Noclip variables
local noclipActive = false
local noclipConnection = nil
local noclipParts = {}

local fullbrightActive = false
local noFogActive, noFogLoop = false, nil

local autoDeletePeelsActive, autoDeletePeelsThread = false, nil
local autoCollectCoinsActive, autoCollectCoinsThread = false, nil
local autoDeleteLockersActive, autoDeleteLockersThread = false, nil
local autoKillActive, autoKillThread = false, nil
local antiKickConnection = nil

local antiAfkConnection = nil
local function enableAntiAfk()
    if antiAfkConnection then return end
    antiAfkConnection = Players.LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end

local function disableAntiAfk()
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end
end

local ccActive = false
local ccEffect = nil
local ccBrightness = 0
local ccContrast = 0
local ccSaturation = 1

local function enableColorCorrection()
    if not Lighting:FindFirstChild("ColorCorrectionEffect") then
        ccEffect = Instance.new("ColorCorrectionEffect")
        ccEffect.Parent = Lighting
    else
        ccEffect = Lighting:FindFirstChild("ColorCorrectionEffect")
    end
    ccEffect.Brightness = ccBrightness
    ccEffect.Contrast = ccContrast
    ccEffect.Saturation = ccSaturation
end

local function disableColorCorrection()
    if ccEffect then
        ccEffect:Destroy()
        ccEffect = nil
    end
end

local sunRaysActive = false
local sunRaysEffect = nil
local sunRaysIntensity = 0.3

local function enableSunRays()
    if not Lighting:FindFirstChild("SunRaysEffect") then
        sunRaysEffect = Instance.new("SunRaysEffect")
        sunRaysEffect.Parent = Lighting
    else
        sunRaysEffect = Lighting:FindFirstChild("SunRaysEffect")
    end
    sunRaysEffect.Intensity = sunRaysIntensity
end

local function disableSunRays()
    if sunRaysEffect then
        sunRaysEffect:Destroy()
        sunRaysEffect = nil
    end
end

-- Noclip functions
local function enableNoclip()
    if noclipActive then return end
    noclipActive = true
    
    local function noclipLoop()
        local character = Players.LocalPlayer.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    noclipParts[part] = true
                    part.CanCollide = false
                end
            end
        end
    end
    
    noclipConnection = RunService.Stepped:Connect(noclipLoop)
    
    Fluent:Notify({
        Title = "Noclip",
        Content = "Noclip enabled",
        Duration = 3
    })
end

local function disableNoclip()
    if not noclipActive then return end
    noclipActive = false
    
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    
    -- Restore collision for all parts that were modified
    for part, _ in pairs(noclipParts) do
        if part and part.Parent then
            part.CanCollide = true
        end
    end
    noclipParts = {}
    
    Fluent:Notify({
        Title = "Noclip",
        Content = "Noclip disabled",
        Duration = 3
    })
end

local function createBillboard(text, isNametag)
    local billboard = Instance.new("BillboardGui")
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Parent = billboard

    return billboard
end

local function removeCakeEsp()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            if obj:FindFirstChild("CakeESP") then obj.CakeESP:Destroy() end
            if obj:FindFirstChild("CakeLabel") then obj.CakeLabel:Destroy() end
        end
    end
end

local function removeCoinEsp()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            if obj:FindFirstChild("CoinESP") then obj.CoinESP:Destroy() end
            if obj:FindFirstChild("CoinLabel") then obj.CoinLabel:Destroy() end
        end
    end
end

local function removeChams()
    for _, plyr in pairs(Players:GetPlayers()) do
        if plyr.Character then
            for _, part in pairs(plyr.Character:GetDescendants()) do
                if part:IsA("BasePart") and part:FindFirstChild("Cham") then
                    part.Cham:Destroy()
                end
            end
        end
    end
end

local function removeNametags()
    for _, plyr in pairs(Players:GetPlayers()) do
        if plyr.Character and plyr.Character:FindFirstChild("Head") then
            local tag = plyr.Character.Head:FindFirstChild("Nametag")
            if tag then tag:Destroy() end
        end
    end
end

local function removeValveEsp()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            if obj:FindFirstChild("ValveESP") then obj.ValveESP:Destroy() end
            if obj:FindFirstChild("ValveLabel") then obj.ValveLabel:Destroy() end
        end
    end
end

local function removePuzzleNumberEsp()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent and obj.Parent.Name == "Buttons" and puzzleNumbers[obj.Name] then
            if obj:FindFirstChild("PuzzleNumberESP") then obj.PuzzleNumberESP:Destroy() end
            if obj:FindFirstChild("PuzzleNumberLabel") then obj.PuzzleNumberLabel:Destroy() end
        end
    end
end

local function removePuzzleEsp()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            if obj:FindFirstChild("PuzzleLabel") then obj.PuzzleLabel:Destroy() end
        end
    end
end

local function cakeEspLoopFunction()
    while cakeEspActive do
        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and ((obj.Parent and obj.Parent.Name == "Cake" and tonumber(obj.Name)) or (obj.Parent and obj.Parent.Name == "CakePlate" and obj.Name == "Plate")) then
                    if not obj:FindFirstChild("CakeESP") then
                        local esp = Instance.new("BoxHandleAdornment")
                        esp.Name = "CakeESP"
                        esp.Adornee = obj
                        esp.AlwaysOnTop = true
                        esp.ZIndex = 10
                        esp.Size = obj.Size + Vector3.new(0.2, 0.2, 0.2)
                        esp.Transparency = 0.5
                        esp.Color3 = cakeEspColor
                        esp.Parent = obj
                    end
                    if not obj:FindFirstChild("CakeLabel") then
                        local billboard = createBillboard("Cake Plate")
                        billboard.Name = "CakeLabel"
                        billboard.Parent = obj
                    end
                end
            end
        end)
        task.wait(3)
    end
end

local function coinEspLoopFunction()
    while coinEspActive do
        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Parent and obj.Parent.Name == "Tokens" and obj.Name == "Token" then
                    if not obj:FindFirstChild("CoinESP") then
                        local esp = Instance.new("BoxHandleAdornment")
                        esp.Name = "CoinESP"
                        esp.Adornee = obj
                        esp.AlwaysOnTop = true
                        esp.ZIndex = 10
                        esp.Size = obj.Size + Vector3.new(0.2, 0.2, 0.2)
                        esp.Transparency = 0.5
                        esp.Color3 = coinEspColor
                        esp.Parent = obj
                    end
                    if not obj:FindFirstChild("CoinLabel") then
                        local billboard = createBillboard("Coin")
                        billboard.Name = "CoinLabel"
                        billboard.Parent = obj
                    end
                end
            end
        end)
        task.wait(3)
    end
end

local function chamsLoopFunction()
    while chamsActive do
        pcall(function()
            for _, plyr in pairs(Players:GetPlayers()) do
                if plyr ~= Players.LocalPlayer and plyr.Character then
                    local sameTeam = (plyr.TeamColor == Players.LocalPlayer.TeamColor)
                    local color = sameTeam and teamChamColor or enemyChamColor
                    for _, part in pairs(plyr.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            local cham = part:FindFirstChild("Cham")
                            if not cham then
                                cham = Instance.new("BoxHandleAdornment")
                                cham.Name = "Cham"
                                cham.Adornee = part
                                cham.AlwaysOnTop = true
                                cham.ZIndex = 10
                                cham.Size = part.Size + Vector3.new(0.1, 0.1, 0.1)
                                cham.Transparency = 0.5
                                cham.Color3 = color
                                cham.Parent = part
                            else
                                cham.Color3 = color
                            end
                        end
                    end
                end
            end
        end)
        task.wait(4)
    end
end

local function nametagLoopFunction()
    while nametagActive do
        pcall(function()
            for _, plyr in pairs(Players:GetPlayers()) do
                if plyr ~= Players.LocalPlayer and plyr.Character and plyr.Character:FindFirstChild("Head") then
                    local sameTeam = (plyr.TeamColor == Players.LocalPlayer.TeamColor)
                    local color = sameTeam and teamChamColor or enemyChamColor
                    local head = plyr.Character.Head
                    local existingTag = head:FindFirstChild("Nametag")
                    if not existingTag then
                        local billboard = createBillboard(plyr.Name)
                        billboard.Name = "Nametag"
                        billboard.Parent = head
                    end
                end
            end
        end)
        task.wait(4)
    end
end

local function valveEspLoopFunction()
    while valveEspActive do
        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local parent = obj.Parent
                    if parent and ((parent.Name == "Valve" or parent.Name == "ValvePuzzle") or (parent.Name == "Buttons" and obj.Name == "ValveButton")) then
                        local basePart = obj
                        if parent:IsA("Model") and parent.PrimaryPart then
                            basePart = parent.PrimaryPart
                        end
                        if not basePart:FindFirstChild("ValveESP") then
                            local esp = Instance.new("BoxHandleAdornment")
                            esp.Name = "ValveESP"
                            esp.Adornee = basePart
                            esp.AlwaysOnTop = true
                            esp.ZIndex = 10
                            esp.Size = basePart.Size + Vector3.new(0.2, 0.2, 0.2)
                            esp.Transparency = 0.5
                            esp.Color3 = valveEspColor
                            esp.Parent = basePart
                        end
                        if not basePart:FindFirstChild("ValveLabel") then
                            local billboard = createBillboard("Valve")
                            billboard.Name = "ValveLabel"
                            billboard.Parent = basePart
                        end
                    end
                end
            end
        end)
        task.wait(4)
    end
end

local function puzzleNumberEspLoopFunction()
    while puzzleNumberEspActive do
        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Parent and obj.Parent.Name == "Buttons" and puzzleNumbers[obj.Name] then
                    if not obj:FindFirstChild("PuzzleNumberESP") then
                        local esp = Instance.new("BoxHandleAdornment")
                        esp.Name = "PuzzleNumberESP"
                        esp.Adornee = obj
                        esp.AlwaysOnTop = true
                        esp.ZIndex = 10
                        esp.Size = obj.Size + Vector3.new(0.2, 0.2, 0.2)
                        esp.Transparency = 0.5
                        esp.Color3 = puzzleNumberEspColor
                        esp.Parent = obj
                    end
                    if not obj:FindFirstChild("PuzzleNumberLabel") then
                        local billboard = createBillboard("Cube Puzzle")
                        billboard.Name = "PuzzleNumberLabel"
                        billboard.Parent = obj
                    end
                end
            end
        end)
        task.wait(4)
    end
end

local function codePuzzleEspLoopFunction()
    while puzzleEspActive do
        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local fullname = obj:GetFullName():lower()
                    if fullname:find("combinationpuzzle") then
                        if not obj:FindFirstChild("PuzzleLabel") then
                            local billboard = createBillboard("Code Puzzle")
                            billboard.Name = "PuzzleLabel"
                            billboard.Parent = obj
                        end
                    end
                end
            end
        end)
        task.wait(5)
    end
end

local function noFogLoopFunction()
    while noFogActive do
        Lighting.FogStart = 0
        Lighting.FogEnd = 1e9
        task.wait(1)
    end
end

local function enableFly()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local root = character.HumanoidRootPart
        flyBodyVelocity = Instance.new("BodyVelocity", root)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBodyGyro = Instance.new("BodyGyro", root)
        flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        flyBodyGyro.CFrame = root.CFrame
        flyActive = true

        if isMobile then
            local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
            local flyGui = Instance.new("ScreenGui")
            flyGui.Name = "FlyControlsGUI"
            flyGui.ResetOnSpawn = false
            flyGui.Parent = playerGui

            local function createFlyButton(text, position, size)
                local button = Instance.new("TextButton")
                button.Text = text
                button.Size = size
                button.Position = position
                button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                button.TextColor3 = Color3.fromRGB(255, 255, 255)
                button.TextScaled = true
                button.Font = Enum.Font.GothamBold
                button.Parent = flyGui
                
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 8)
                corner.Parent = button
                
                return button
            end

            local upButton = createFlyButton("↑", UDim2.new(0.5, -40, 0.3, 0), UDim2.new(0, 80, 0, 60))
            local downButton = createFlyButton("↓", UDim2.new(0.5, -40, 0.7, 0), UDim2.new(0, 80, 0, 60))
            local forwardButton = createFlyButton("▲", UDim2.new(0.5, -40, 0.4, 0), UDim2.new(0, 80, 0, 60))
            local backwardButton = createFlyButton("▼", UDim2.new(0.5, -40, 0.6, 0), UDim2.new(0, 80, 0, 60))
            local leftButton = createFlyButton("◄", UDim2.new(0.3, -40, 0.5, 0), UDim2.new(0, 80, 0, 60))
            local rightButton = createFlyButton("►", UDim2.new(0.7, -40, 0.5, 0), UDim2.new(0, 80, 0, 60))

            flyConnection = RunService.RenderStepped:Connect(function()
                local direction = Vector3.new(0, 0, 0)
                
                if upButton.Parent and GuiService:IsTenFootInterface() then
                    return
                end
                
                flyBodyVelocity.Velocity = direction.Unit * flySpeed
                flyBodyGyro.CFrame = workspace.CurrentCamera.CFrame
            end)

            local function handleMobileInput(button, directionVector)
                local inputBegan, inputEnded
                
                inputBegan = button.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        flyConnection:Disconnect()
                        flyConnection = RunService.RenderStepped:Connect(function()
                            flyBodyVelocity.Velocity = directionVector.Unit * flySpeed
                            flyBodyGyro.CFrame = workspace.CurrentCamera.CFrame
                        end)
                    end
                end)
                
                inputEnded = button.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        flyConnection:Disconnect()
                        flyConnection = RunService.RenderStepped:Connect(function()
                            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                            flyBodyGyro.CFrame = workspace.CurrentCamera.CFrame
                        end)
                    end
                end)
            end

            handleMobileInput(forwardButton, workspace.CurrentCamera.CFrame.LookVector)
            handleMobileInput(backwardButton, -workspace.CurrentCamera.CFrame.LookVector)
            handleMobileInput(leftButton, -workspace.CurrentCamera.CFrame.RightVector)
            handleMobileInput(rightButton, workspace.CurrentCamera.CFrame.RightVector)
            handleMobileInput(upButton, Vector3.new(0, 1, 0))
            handleMobileInput(downButton, Vector3.new(0, -1, 0))
        else
            flyConnection = RunService.RenderStepped:Connect(function()
                local direction = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    direction = direction + workspace.CurrentCamera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    direction = direction - workspace.CurrentCamera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    direction = direction - workspace.CurrentCamera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    direction = direction + workspace.CurrentCamera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    direction = direction + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    direction = direction - Vector3.new(0, 1, 0)
                end

                if direction.Magnitude > 0 then
                    flyBodyVelocity.Velocity = direction.Unit * flySpeed
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
                flyBodyGyro.CFrame = workspace.CurrentCamera.CFrame
            end)
        end
    end
end

local function disableFly()
    flyActive = false
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    
    if isMobile then
        local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local flyGui = playerGui:FindFirstChild("FlyControlsGUI")
            if flyGui then
                flyGui:Destroy()
            end
        end
    end
end

local function startAntiKick()
    if not antiKickConnection then
        antiKickConnection = Players.LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end

local function stopAntiKick()
    if antiKickConnection then
        antiKickConnection:Disconnect()
        antiKickConnection = nil
    end
end

local function autoDeletePeelsFunc()
    while autoDeletePeelsActive do
        pcall(function()
            local peelsFolder = (workspace:FindFirstChild("GameKeeper") and workspace.GameKeeper:FindFirstChild("Map") and workspace.GameKeeper.Map:FindFirstChild("Peels")) or workspace:FindFirstChild("Peels")
            if peelsFolder then
                for _, peel in ipairs(peelsFolder:GetChildren()) do
                    if peel and peel.Name:lower():find("peel") then
                        peel:Destroy()
                    end
                end
            end
        end)
        task.wait(4)
    end
end

local function autoCollectCoinsFunc()
    while autoCollectCoinsActive do
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj and obj.Name:lower():find("token") and obj:IsA("BasePart") then
                    local char = Players.LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and obj.Parent then
                        hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 2, 0))
                        task.wait(0.3)
                    end
                end
            end
        end)
        task.wait(3)
    end
end

local function autoDeleteLockersFunc()
    while autoDeleteLockersActive do
        pcall(function()
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc and desc.Name:lower():find("locker") then
                    desc:Destroy()
                end
            end
        end)
        task.wait(5)
    end
end

local function autoKillFunc()
    while autoKillActive do
        pcall(function()
            local localPlayer = Players.LocalPlayer
            local localChar = localPlayer.Character
            local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
            
            if localHrp and localPlayer.Team and localPlayer.Team.Name == "Banana" then
                local targetPlayer = nil
                local shortestDistance = math.huge
                
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= localPlayer and player.Team and player.Team.Name == "Runners" then
                        local char = player.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local distance = (localHrp.Position - hrp.Position).Magnitude
                            if distance < shortestDistance then
                                shortestDistance = distance
                                targetPlayer = player
                            end
                        end
                    end
                end
                
                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local targetPos = targetPlayer.Character.HumanoidRootPart.Position
                    localHrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
                end
            end
        end)
        task.wait(1)
    end
end

local ESPSection = Tabs.ESP:AddSection("ESP Toggles")
local ESPColorsSection = Tabs.ESP:AddSection("ESP Colors")

ESPSection:AddToggle("CakeEspToggle", {
    Title = "Cake ESP",
    Default = false,
    Callback = function(state)
        cakeEspActive = state
        if state then
            if cakeEspLoop then task.cancel(cakeEspLoop) end
            cakeEspLoop = task.spawn(cakeEspLoopFunction)
        else
            if cakeEspLoop then task.cancel(cakeEspLoop) end
            cakeEspLoop = nil
            removeCakeEsp()
        end
    end
})

ESPSection:AddToggle("CoinEspToggle", {
    Title = "Coin ESP",
    Default = false,
    Callback = function(state)
        coinEspActive = state
        if state then
            if coinEspLoop then task.cancel(coinEspLoop) end
            coinEspLoop = task.spawn(coinEspLoopFunction)
        else
            if coinEspLoop then task.cancel(coinEspLoop) end
            coinEspLoop = nil
            removeCoinEsp()
        end
    end
})

ESPSection:AddToggle("ChamsToggle", {
    Title = "Player Chams",
    Default = false,
    Callback = function(state)
        chamsActive = state
        if state then
            if chamsLoop then task.cancel(chamsLoop) end
            chamsLoop = task.spawn(chamsLoopFunction)
        else
            if chamsLoop then task.cancel(chamsLoop) end
            chamsLoop = nil
            removeChams()
        end
    end
})

ESPSection:AddToggle("NametagToggle", {
    Title = "Nametags",
    Default = false,
    Callback = function(state)
        nametagActive = state
        if state then
            if nametagLoop then task.cancel(nametagLoop) end
            nametagLoop = task.spawn(nametagLoopFunction)
        else
            if nametagLoop then task.cancel(nametagLoop) end
            nametagLoop = nil
            removeNametags()
        end
    end
})

ESPSection:AddToggle("ValveEspToggle", {
    Title = "Valve ESP",
    Default = false,
    Callback = function(state)
        valveEspActive = state
        if state then
            if valveEspLoop then task.cancel(valveEspLoop) end
            valveEspLoop = task.spawn(valveEspLoopFunction)
        else
            if valveEspLoop then task.cancel(valveEspLoop) end
            valveEspLoop = nil
            removeValveEsp()
        end
    end
})

ESPSection:AddToggle("CubePuzzleEspToggle", {
    Title = "Cube Puzzle ESP",
    Default = false,
    Callback = function(state)
        puzzleNumberEspActive = state
        if state then
            if puzzleNumberEspLoop then task.cancel(puzzleNumberEspLoop) end
            puzzleNumberEspLoop = task.spawn(puzzleNumberEspLoopFunction)
        else
            if puzzleNumberEspLoop then task.cancel(puzzleNumberEspLoop) end
            puzzleNumberEspLoop = nil
            removePuzzleNumberEsp()
        end
    end
})

ESPSection:AddToggle("CodePuzzleEspToggle", {
    Title = "Code Puzzle ESP",
    Default = false,
    Callback = function(state)
        puzzleEspActive = state
        if state then
            if puzzleEspLoop then task.cancel(puzzleEspLoop) end
            puzzleEspLoop = task.spawn(codePuzzleEspLoopFunction)
        else
            if puzzleEspLoop then task.cancel(puzzleEspLoop) end
            puzzleEspLoop = nil
            removePuzzleEsp()
        end
    end
})

ESPColorsSection:AddColorpicker("CakeEspColor", {
    Title = "Cake ESP",
    Default = cakeEspColor,
    Callback = function(color)
        cakeEspColor = color
    end
})

ESPColorsSection:AddColorpicker("CoinEspColor", {
    Title = "Coin ESP",
    Default = coinEspColor,
    Callback = function(color)
        coinEspColor = color
    end
})

ESPColorsSection:AddColorpicker("EnemyChamsColor", {
    Title = "Enemy Chams",
    Default = enemyChamColor,
    Callback = function(color)
        enemyChamColor = color
    end
})

ESPColorsSection:AddColorpicker("TeamChamsColor", {
    Title = "Team Chams",
    Default = teamChamColor,
    Callback = function(color)
        teamChamColor = color
    end
})

ESPColorsSection:AddColorpicker("ValveEspColor", {
    Title = "Valve ESP",
    Default = valveEspColor,
    Callback = function(color)
        valveEspColor = color
    end
})

ESPColorsSection:AddColorpicker("PuzzleNumberEspColor", {
    Title = "Cube Puzzle ESP",
    Default = puzzleNumberEspColor,
    Callback = function(color)
        puzzleNumberEspColor = color
    end
})

ESPColorsSection:AddColorpicker("PuzzleObjectEspColor", {
    Title = "Code Puzzle ESP",
    Default = puzzleEspColor,
    Callback = function(color)
        puzzleEspColor = color
    end
})

-- Player Tab with Noclip
local PlayerMovementSection = Tabs.Player:AddSection("Movement")

PlayerMovementSection:AddSlider("WalkSpeedSlider", {
    Title = "Walk Speed",
    Default = 16,
    Min = 16,
    Max = 45,
    Rounding = 0,
    Callback = function(value)
        currentSpeed = value
        local char = Players.LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = currentSpeed
        end
        
        if value ~= 16 then
            if speedLoop then task.cancel(speedLoop) end
            speedLoop = task.spawn(function()
                while currentSpeed ~= 16 do
                    local c = Players.LocalPlayer.Character
                    if c and c:FindFirstChild("Humanoid") then
                        c.Humanoid.WalkSpeed = currentSpeed
                    end
                    task.wait(0.1)
                end
            end)
        else
            if speedLoop then
                task.cancel(speedLoop)
                speedLoop = nil
            end
        end
    end
})

PlayerMovementSection:AddButton({
    Title = "Reset Speed",
    Callback = function()
        currentSpeed = 16
        local char = Players.LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = 16
        end
        if speedLoop then
            task.cancel(speedLoop)
            speedLoop = nil
        end
    end
})

PlayerMovementSection:AddToggle("FlyToggle", {
    Title = "Fly (Local)",
    Default = false,
    Callback = function(state)
        if state then
            enableFly()
        else
            disableFly()
        end
    end
})

PlayerMovementSection:AddSlider("FlySpeedSlider", {
    Title = "Fly Speed",
    Default = 50,
    Min = 1,
    Max = 200,
    Rounding = 0,
    Callback = function(value)
        flySpeed = value
    end
})

-- Noclip Toggle hinzugefügt
PlayerMovementSection:AddToggle("NoclipToggle", {
    Title = "Noclip",
    Default = false,
    Callback = function(state)
        if state then
            enableNoclip()
        else
            disableNoclip()
        end
    end
})

local PlayerUtilitySection = Tabs.Player:AddSection("Utility")

PlayerUtilitySection:AddToggle("AntiAFKToggle", {
    Title = "Anti-AFK",
    Default = false,
    Callback = function(state)
        if state then
            enableAntiAfk()
        else
            disableAntiAfk()
        end
    end
})

local AutoSection = Tabs.Auto:AddSection("Auto Features")

AutoSection:AddToggle("AutoCollectCoins", {
    Title = "Auto Collect Coins",
    Default = false,
    Callback = function(state)
        autoCollectCoinsActive = state
        if state then
            if autoCollectCoinsThread then task.cancel(autoCollectCoinsThread) end
            autoCollectCoinsThread = task.spawn(autoCollectCoinsFunc)
        else
            if autoCollectCoinsThread then task.cancel(autoCollectCoinsThread) end
            autoCollectCoinsThread = nil
        end
    end
})

AutoSection:AddToggle("AutoDeletePeels", {
    Title = "Auto Delete Peels",
    Default = false,
    Callback = function(state)
        autoDeletePeelsActive = state
        if state then
            if autoDeletePeelsThread then task.cancel(autoDeletePeelsThread) end
            autoDeletePeelsThread = task.spawn(autoDeletePeelsFunc)
        else
            if autoDeletePeelsThread then task.cancel(autoDeletePeelsThread) end
            autoDeletePeelsThread = nil
        end
    end
})

AutoSection:AddToggle("AutoDeleteLockers", {
    Title = "Auto Delete Lockers",
    Default = false,
    Callback = function(state)
        autoDeleteLockersActive = state
        if state then
            if autoDeleteLockersThread then task.cancel(autoDeleteLockersThread) end
            autoDeleteLockersThread = task.spawn(autoDeleteLockersFunc)
        else
            if autoDeleteLockersThread then task.cancel(autoDeleteLockersThread) end
            autoDeleteLockersThread = nil
        end
    end
})

AutoSection:AddToggle("AutoKill", {
    Title = "Auto Kill",
    Default = false,
    Callback = function(state)
        autoKillActive = state
        if state then
            if autoKillThread then task.cancel(autoKillThread) end
            autoKillThread = task.spawn(autoKillFunc)
        else
            if autoKillThread then task.cancel(autoKillThread) end
            autoKillThread = nil
        end
    end
})

AutoSection:AddToggle("AntiKickBypass", {
    Title = "Anti Kick Bypass",
    Default = false,
    Callback = function(state)
        if state then
            startAntiKick()
        else
            stopAntiKick()
        end
    end
})

local VisualSection = Tabs.Visual

VisualSection:AddToggle("FullbrightToggle", {
    Title = "Fullbright",
    Default = false,
    Callback = function(state)
        fullbrightActive = state
        if state then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        else
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1000
            Lighting.GlobalShadows = true
            Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        end
    end
})

VisualSection:AddToggle("NoFogToggle", {
    Title = "No Fog",
    Default = false,
    Callback = function(state)
        noFogActive = state
        if state then
            if noFogLoop then task.cancel(noFogLoop) end
            noFogLoop = task.spawn(noFogLoopFunction)
        else
            if noFogLoop then task.cancel(noFogLoop) end
            noFogLoop = nil
            Lighting.FogStart = 0
            Lighting.FogEnd = 1000
        end
    end
})

VisualSection:AddToggle("ColorCorrectionToggle", {
    Title = "Color Correction",
    Default = false,
    Callback = function(state)
        ccActive = state
        if state then
            enableColorCorrection()
        else
            disableColorCorrection()
        end
    end
})

VisualSection:AddSlider("BrightnessSlider", {
    Title = "Brightness",
    Default = 0,
    Min = -1,
    Max = 1,
    Rounding = 2,
    Callback = function(value)
        ccBrightness = value
        if ccActive and ccEffect then
            ccEffect.Brightness = value
        end
    end
})

VisualSection:AddSlider("ContrastSlider", {
    Title = "Contrast",
    Default = 0,
    Min = -2,
    Max = 2,
    Rounding = 2,
    Callback = function(value)
        ccContrast = value
        if ccActive and ccEffect then
            ccEffect.Contrast = value
        end
    end
})

VisualSection:AddSlider("SaturationSlider", {
    Title = "Saturation",
    Default = 1,
    Min = 0,
    Max = 3,
    Rounding = 2,
    Callback = function(value)
        ccSaturation = value
        if ccActive and ccEffect then
            ccEffect.Saturation = value
        end
    end
})

VisualSection:AddToggle("SunRaysToggle", {
    Title = "Sun Rays",
    Default = false,
    Callback = function(state)
        sunRaysActive = state
        if state then
            enableSunRays()
        else
            disableSunRays()
        end
    end
})

VisualSection:AddSlider("SunRaysIntensitySlider", {
    Title = "Sun Rays Intensity",
    Default = 0.3,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(value)
        sunRaysIntensity = value
        if sunRaysActive and sunRaysEffect then
            sunRaysEffect.Intensity = value
        end
    end
})

local LightingSection = Tabs.Visual:AddSection("Lighting Controls")

LightingSection:AddSlider("ClockTimeSlider", {
    Title = "Time of Day",
    Default = 0,
    Min = 0,
    Max = 24,
    Rounding = 1,
    Callback = function(value)
        Lighting.ClockTime = value
    end
})

LightingSection:AddSlider("ExposureSlider", {
    Title = "Exposure",
    Default = 0,
    Min = -3,
    Max = 3,
    Rounding = 2,
    Callback = function(value)
        Lighting.ExposureCompensation = value
    end
})

LightingSection:AddToggle("ShadowsToggle", {
    Title = "Shadows",
    Default = true,
    Callback = function(state)
        Lighting.GlobalShadows = state
    end
})

local UtilitySection = Tabs.Visual:AddSection("Utility")

UtilitySection:AddButton({
    Title = "Reset All Visual",
    Callback = function()
        Lighting.Brightness = 1
        Lighting.ClockTime = 14
        Lighting.FogStart = 0
        Lighting.FogEnd = 1000
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        Lighting.ExposureCompensation = 0
        
        if ccEffect then ccEffect:Destroy(); ccEffect = nil end
        if sunRaysEffect then sunRaysEffect:Destroy(); sunRaysEffect = nil end
        
        ccActive = false
        sunRaysActive = false
        fullbrightActive = false
        
        if noFogLoop then
            task.cancel(noFogLoop)
            noFogLoop = nil
            noFogActive = false
        end
        
        Fluent:Notify({
            Title = "Visual Reset",
            Content = "All visual settings reset to default",
            Duration = 3
        })
    end
})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

local function createMobileGUIButton()
    if not isMobile then return end
    
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "MobileGUIToggle"
    mobileGui.ResetOnSpawn = false
    mobileGui.Parent = playerGui

    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Text = "🎮"
    toggleButton.Size = UDim2.new(0, 60, 0, 60)
    toggleButton.Position = UDim2.new(1, -70, 0, 10)
    toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextScaled = true
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = mobileGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 30)
    corner.Parent = toggleButton

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 100, 100)
    stroke.Thickness = 2
    stroke.Parent = toggleButton

    toggleButton.MouseButton1Click:Connect(function()
        isGuiVisible = not isGuiVisible
        if Window and Window.Root then
            Window.Root.Visible = isGuiVisible
        end
        toggleButton.Text = isGuiVisible and "🎮" or "📱"
        toggleButton.BackgroundColor3 = isGuiVisible and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(60, 60, 60)
    end)

    local dragging = false
    local dragStart = nil
    local startPos = nil

    toggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = toggleButton.Position
        end
    end)

    toggleButton.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            toggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    toggleButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function setupChatCommands()
    local function onChatted(message)
        local msg = message:lower()
        if msg == "/gui" or msg == "/menu" or msg == "/toggle" then
            isGuiVisible = not isGuiVisible
            if Window and Window.Root then
                Window.Root.Visible = isGuiVisible
            end
            
            local statusText = isGuiVisible and "opened" or "closed"
            Fluent:Notify({
                Title = "GUI Toggle",
                Content = "Menu " .. statusText .. " via chat command",
                Duration = 2
            })
        elseif msg == "/help" then
            Fluent:Notify({
                Title = "Chat Commands",
                Content = "/gui, /menu, /toggle - Toggle GUI\n/help - Show this help",
                Duration = 5
            })
        end
    end

    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        TextChatService.MessageReceived:Connect(function(textChatMessage)
            if textChatMessage.TextSource and textChatMessage.TextSource.UserId == Players.LocalPlayer.UserId then
                onChatted(textChatMessage.Text)
            end
        end)
    else
        Players.LocalPlayer.Chatted:Connect(onChatted)
    end
end

if isMobile then
    task.wait(2)
    createMobileGUIButton()
    setupChatCommands()
else
    setupChatCommands()
end

-- Character respawn handling including noclip
Players.LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart")
    task.wait(0.5)
    
    if speedLoop and currentSpeed ~= 16 then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = currentSpeed
        end
    end
    
    if flyActive then
        task.wait(0.5)
        disableFly()
        task.wait(0.5)
        enableFly()
    end
    
    -- Re-enable noclip after respawn
    if noclipActive then
        task.wait(0.5)
        disableNoclip()
        task.wait(0.5)
        enableNoclip()
    end
end)

Fluent:Notify({
    Title = "Banana Eats Script",
    Content = "Script loaded successfully!",
    Duration = 4
})

Window:SelectTab(1)
