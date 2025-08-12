local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isGuiVisible = true

local initialLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ExposureCompensation = Lighting.ExposureCompensation,
}

local function restoreLighting()
    Lighting.Brightness = initialLighting.Brightness
    Lighting.ClockTime = initialLighting.ClockTime
    Lighting.FogStart = initialLighting.FogStart
    Lighting.FogEnd = initialLighting.FogEnd
    Lighting.GlobalShadows = initialLighting.GlobalShadows
    Lighting.OutdoorAmbient = initialLighting.OutdoorAmbient
    Lighting.ExposureCompensation = initialLighting.ExposureCompensation
end

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

local function createBillboard(text)
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

local function makeBoxAdornment(part, name, color, sizeInflate)
    local esp = Instance.new("BoxHandleAdornment")
    esp.Name = name
    esp.Adornee = part
    esp.AlwaysOnTop = true
    esp.ZIndex = 10
    esp.Size = part.Size + (sizeInflate or Vector3.new(0.2,0.2,0.2))
    esp.Transparency = 0.5
    esp.Color3 = color
    esp.Parent = part
    return esp
end

local function safePrimary(base)
    if base:IsA("Model") and base.PrimaryPart then return base.PrimaryPart end
    if base:IsA("BasePart") then return base end
    return base:FindFirstChildWhichIsA("BasePart", true)
end

local cakeEspActive, cakeLoop, cakeConnAdd, cakeConnRem = false, nil, nil, nil
local cakeEspColor = Color3.fromRGB(255, 255, 0)
local cakeTargets = {}

local coinEspActive, coinLoop, coinConnAdd, coinConnRem = false, nil, nil, nil
local coinEspColor = Color3.fromRGB(0, 255, 0)
local coinTargets = {}

local chamsActive, chamsLoop = false, nil
local enemyChamColor = Color3.fromRGB(255, 0, 0)
local teamChamColor = Color3.fromRGB(0, 255, 0)

local nametagActive, nametagLoop = false, nil

local valveEspActive, valveLoop, valveConnAdd, valveConnRem = false, nil, nil, nil
local valveEspColor = Color3.fromRGB(0, 255, 255)
local valveTargets = {}

local puzzleNumberEspActive, puzzleNumberLoop, puzzleNumConnAdd, puzzleNumConnRem = false, nil, nil, nil
local puzzleNumberEspColor = Color3.fromRGB(255, 255, 255)
local puzzleNumbers = {["23"]=true, ["34"]=true, ["31"]=true}
local puzzleNumberTargets = {}

local codePuzzleEspActive = false
local codePuzzleLabelAttached = false
local codePuzzleConnAdd = nil
local codePuzzleLabelColor = Color3.fromRGB(0, 255, 0)

local speedLoop = nil
local currentSpeed = 16

local flyActive = false
local flySpeed = 50
local flyBodyVelocity, flyBodyGyro, flyConnection = nil, nil, nil

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
    if antiAfkConnection then antiAfkConnection:Disconnect(); antiAfkConnection=nil end
end

local ccActive, ccEffect = false, nil
local ccBrightness, ccContrast, ccSaturation = 0, 0, 1
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
    if ccEffect then ccEffect:Destroy(); ccEffect=nil end
end
local sunRaysActive, sunRaysEffect = false, nil
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
    if sunRaysEffect then sunRaysEffect:Destroy(); sunRaysEffect=nil end
end

local function clearAdornment(part, name)
    if part and part:FindFirstChild(name) then part[name]:Destroy() end
end
local function clearBillboard(part, name)
    if part and part:FindFirstChild(name) then part[name]:Destroy() end
end

local function removeCakeEsp()
    for part in pairs(cakeTargets) do
        if part and part.Parent then
            clearAdornment(part,"CakeESP"); clearBillboard(part,"CakeLabel")
        end
    end
    cakeTargets = {}
end
local function removeCoinEsp()
    for part in pairs(coinTargets) do
        if part and part.Parent then
            clearAdornment(part,"CoinESP"); clearBillboard(part,"CoinLabel")
        end
    end
    coinTargets = {}
end
local function removeValveEsp()
    for part in pairs(valveTargets) do
        if part and part.Parent then
            clearAdornment(part,"ValveESP"); clearBillboard(part,"ValveLabel")
        end
    end
    valveTargets = {}
end
local function removePuzzleNumberEsp()
    for part in pairs(puzzleNumberTargets) do
        if part and part.Parent then
            clearAdornment(part,"PuzzleNumberESP"); clearBillboard(part,"PuzzleNumberLabel")
        end
    end
    puzzleNumberTargets = {}
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

local function isCakePart(obj)
    if not obj:IsA("BasePart") then return false end
    local p = obj.Parent
    if not p then return false end
    if p.Name=="Cake" and tonumber(obj.Name) then return true end
    if p.Name=="CakePlate" and obj.Name=="Plate" then return true end
    return false
end

local function isCoinPart(obj)
    if not obj:IsA("BasePart") then return false end
    local p = obj.Parent
    return p and p.Name=="Tokens" and obj.Name=="Token"
end

local function isValveBase(obj)
    if not obj:IsA("BasePart") then return false end
    local parent = obj.Parent
    if not parent then return false end
    if parent.Name=="Valve" or parent.Name=="ValvePuzzle" then return true end
    if parent.Name=="Buttons" and obj.Name=="ValveButton" then return true end
    return false
end

local function isPuzzleNumber(obj)
    if not obj:IsA("BasePart") then return false end
    local parent = obj.Parent
    return parent and parent.Name=="Buttons" and puzzleNumbers[obj.Name]==true
end

local function initialScanAndCache(predicate, cacheTable)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if predicate(obj) then
            cacheTable[obj] = true
        end
    end
end

local function hookWorkspace(predicate, cacheTable, onAddRef, onRemRef)
    if onAddRef then onAddRef:Disconnect() end
    if onRemRef then onRemRef:Disconnect() end
    local addConn = workspace.DescendantAdded:Connect(function(obj)
        if predicate(obj) then cacheTable[obj] = true end
    end)
    local remConn = workspace.DescendantRemoving:Connect(function(obj)
        if cacheTable[obj] then cacheTable[obj] = nil end
    end)
    return addConn, remConn
end

local function cakeEspLoopFunction()
    local waitTime = isMobile and 0.5 or 0.25
    while cakeEspActive do
        for part in pairs(cakeTargets) do
            if part and part.Parent then
                if not part:FindFirstChild("CakeESP") then
                    makeBoxAdornment(part,"CakeESP",cakeEspColor)
                else
                    part.CakeESP.Color3 = cakeEspColor
                end
                if not part:FindFirstChild("CakeLabel") then
                    local b = createBillboard("Cake Plate"); b.Name="CakeLabel"; b.Parent = part
                end
            else
                cakeTargets[part] = nil
            end
        end
        task.wait(waitTime)
    end
end

local function coinEspLoopFunction()
    local waitTime = isMobile and 0.5 or 0.25
    while coinEspActive do
        for part in pairs(coinTargets) do
            if part and part.Parent then
                if not part:FindFirstChild("CoinESP") then
                    makeBoxAdornment(part,"CoinESP",coinEspColor)
                else
                    part.CoinESP.Color3 = coinEspColor
                end
                if not part:FindFirstChild("CoinLabel") then
                    local b = createBillboard("Coin"); b.Name="CoinLabel"; b.Parent = part
                end
            else
                coinTargets[part] = nil
            end
        end
        task.wait(waitTime)
    end
end

local function valveEspLoopFunction()
    local waitTime = isMobile and 0.6 or 0.3
    while valveEspActive do
        for base in pairs(valveTargets) do
            if base and base.Parent then
                local part = safePrimary(base) or base
                if part then
                    if not part:FindFirstChild("ValveESP") then
                        makeBoxAdornment(part,"ValveESP",valveEspColor)
                    else
                        part.ValveESP.Color3 = valveEspColor
                    end
                    if not part:FindFirstChild("ValveLabel") then
                        local b = createBillboard("Valve"); b.Name="ValveLabel"; b.Parent = part
                    end
                end
            else
                valveTargets[base] = nil
            end
        end
        task.wait(waitTime)
    end
end

local function puzzleNumberEspLoopFunction()
    local waitTime = isMobile and 0.6 or 0.3
    while puzzleNumberEspActive do
        for part in pairs(puzzleNumberTargets) do
            if part and part.Parent then
                if not part:FindFirstChild("PuzzleNumberESP") then
                    makeBoxAdornment(part,"PuzzleNumberESP",puzzleNumberEspColor)
                else
                    part.PuzzleNumberESP.Color3 = puzzleNumberEspColor
                end
                if not part:FindFirstChild("PuzzleNumberLabel") then
                    local b = createBillboard("Cube Puzzle"); b.Name="PuzzleNumberLabel"; b.Parent = part
                end
            else
                puzzleNumberTargets[part] = nil
            end
        end
        task.wait(waitTime)
    end
end

local function findCombinationPuzzlePart()
    local gk = workspace:FindFirstChild("GameKeeper")
    if not gk then return nil end
    local puzzles = gk:FindFirstChild("Puzzles")
    if not puzzles then return nil end
    local cp = puzzles:FindFirstChild("CombinationPuzzle")
    if not cp then return nil end
    local target = cp.PrimaryPart or cp:FindFirstChildWhichIsA("BasePart", true)
    return target
end

local function attachCodePuzzleLabelOnce()
    if codePuzzleLabelAttached then return end
    local target = findCombinationPuzzlePart()
    if target then
        if not target:FindFirstChild("PuzzleLabel") then
            local b = createBillboard("Combination Puzzle")
            b.Name = "PuzzleLabel"
            b.Parent = target
        end
        codePuzzleLabelAttached = true
    end
end

local function getComboButtonsFolder()
    local gk = workspace:FindFirstChild("GameKeeper")
    if not gk then return nil end
    local puzzles = gk:FindFirstChild("Puzzles")
    if not puzzles then return nil end
    local cp = puzzles:FindFirstChild("CombinationPuzzle")
    if not cp then return nil end
    local key = cp:FindFirstChild("CombinationKey")
    if not key then return nil end
    local buttonsRoot = key:FindFirstChild("Buttons")
    if not buttonsRoot then return nil end
    return buttonsRoot
end

local function readCombinationCode()
    local root = getComboButtonsFolder()
    if not root then return nil end
    local out = {}
    for i = 1, 3 do
        local btn = root:FindFirstChild("Button"..i)
        if not btn then return nil end
        local bl = btn:FindFirstChild("ButtonLabel")
        if not bl then return nil end
        local label = bl:FindFirstChild("Label")
        if not (label and label:IsA("TextLabel")) then return nil end
        local txt = tostring(label.Text or "")
        local digit = txt:match("(%d)%s*$") or txt:match("(%d)") or ""
        if digit == "" then return nil end
        table.insert(out, digit)
    end
    return table.concat(out, "")
end

local comboParagraph
local comboLoop = nil
local comboCurrentCode = nil

local function startComboWatcher()
    if comboLoop then task.cancel(comboLoop) end
    comboLoop = task.spawn(function()
        while true do
            local code = nil
            pcall(function() code = readCombinationCode() end)
            comboCurrentCode = code
            if comboParagraph then
                comboParagraph:SetDesc(code and code or "—")
            end
            task.wait(0.4)
        end
    end)
end

local function applyChamsToCharacter(plyr)
    if not plyr or not plyr.Character then return end
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

local function applyNametagToCharacter(plyr)
    if not plyr or not plyr.Character then return end
    local head = plyr.Character:FindFirstChild("Head")
    if not head then return end
    if not head:FindFirstChild("Nametag") then
        local b = createBillboard(plyr.Name)
        b.Name = "Nametag"
        b.Parent = head
    end
end

local function hookPlayer(plyr)
    plyr.CharacterAdded:Connect(function()
        task.wait(0.2)
        if chamsActive then applyChamsToCharacter(plyr) end
        if nametagActive then applyNametagToCharacter(plyr) end
    end)
    if plyr.Character then
        if chamsActive then applyChamsToCharacter(plyr) end
        if nametagActive then applyNametagToCharacter(plyr) end
    end
    if chamsActive then
        task.spawn(function()
            while chamsActive and plyr.Parent do
                if plyr.Character then applyChamsToCharacter(plyr) end
                task.wait(1.0)
            end
        end)
    end
end

local function enableNoclip()
    if noclipActive then return end
    noclipActive = true
    noclipConnection = RunService.Stepped:Connect(function()
        local character = Players.LocalPlayer.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    noclipParts[part] = true
                    part.CanCollide = false
                end
            end
        end
    end)
end
local function disableNoclip()
    if not noclipActive then return end
    noclipActive = false
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection=nil end
    for part in pairs(noclipParts) do
        if part and part.Parent then part.CanCollide = true end
    end
    noclipParts = {}
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
            local function setDir(vec)
                if flyConnection then flyConnection:Disconnect() end
                flyConnection = RunService.RenderStepped:Connect(function()
                    flyBodyVelocity.Velocity = vec.Unit * flySpeed
                    flyBodyGyro.CFrame = workspace.CurrentCamera.CFrame
                end)
            end
            local function clearDir()
                if flyConnection then flyConnection:Disconnect() end
                flyConnection = RunService.RenderStepped:Connect(function()
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    flyBodyGyro.CFrame = workspace.CurrentCamera.CFrame
                end)
            end
            local function bind(button, vec)
                button.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then setDir(vec) end
                end)
                button.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then clearDir() end
                end)
            end
            bind(forwardButton, workspace.CurrentCamera.CFrame.LookVector)
            bind(backwardButton, -workspace.CurrentCamera.CFrame.LookVector)
            bind(leftButton, -workspace.CurrentCamera.CFrame.RightVector)
            bind(rightButton, workspace.CurrentCamera.CFrame.RightVector)
            bind(upButton, Vector3.new(0,1,0))
            bind(downButton, Vector3.new(0,-1,0))
        else
            flyConnection = RunService.RenderStepped:Connect(function()
                local dir = Vector3.new(0,0,0)
                local cam = workspace.CurrentCamera
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
                flyBodyVelocity.Velocity = (dir.Magnitude > 0) and dir.Unit * flySpeed or Vector3.new(0,0,0)
                flyBodyGyro.CFrame = cam.CFrame
            end)
        end
    end
end

local function disableFly()
    flyActive = false
    if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity=nil end
    if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro=nil end
    if flyConnection then flyConnection:Disconnect(); flyConnection=nil end
    if isMobile then
        local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local flyGui = playerGui:FindFirstChild("FlyControlsGUI")
            if flyGui then flyGui:Destroy() end
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
    if antiKickConnection then antiKickConnection:Disconnect(); antiKickConnection=nil end
end

local function autoDeletePeelsFunc()
    while autoDeletePeelsActive do
        pcall(function()
            local peelsFolder = (workspace:FindFirstChild("GameKeeper") and workspace.GameKeeper:FindFirstChild("Map") and workspace.GameKeeper.Map:FindFirstChild("Peels")) or workspace:FindFirstChild("Peels")
            if peelsFolder then
                for _, peel in ipairs(peelsFolder:GetChildren()) do
                    if peel and peel.Name:lower():find("peel") then peel:Destroy() end
                end
            end
        end)
        task.wait(4)
    end
end

local function autoCollectCoinsFunc()
    while autoCollectCoinsActive do
        pcall(function()
            for part in pairs(coinTargets) do
                if part and part.Parent then
                    local char = Players.LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))
                        task.wait(0.25)
                    end
                end
            end
        end)
        task.wait(0.8)
    end
end

local function autoDeleteLockersFunc()
    while autoDeleteLockersActive do
        pcall(function()
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc and desc.Name:lower():find("locker") then desc:Destroy() end
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
                local targetPlayer, shortest = nil, math.huge
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= localPlayer and p.Team and p.Team.Name == "Runners" then
                        local c = p.Character; local hrp = c and c:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local d = (localHrp.Position - hrp.Position).Magnitude
                            if d < shortest then shortest = d; targetPlayer = p end
                        end
                    end
                end
                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local targetPos = targetPlayer.Character.HumanoidRootPart.Position
                    local localPlayerHRP = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if localPlayerHRP then
                        localPlayerHRP.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
                    end
                end
            end
        end)
        task.wait(0.6)
    end
end

local function sendChatMessage(msg)
    local ok = false
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channels = TextChatService:FindFirstChild("TextChannels")
            local general = channels and channels:FindFirstChild("RBXGeneral")
            if general then general:SendAsync(msg); ok = true end
        end
    end)
    if not ok then
        pcall(function()
            local say = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
            if say then say:FireServer(msg, "All"); ok = true end
        end)
    end
    return ok
end

local function collectValveActivators()
    local out = {}
    local puzzles = workspace:FindFirstChild("GameKeeper") and workspace.GameKeeper:FindFirstChild("Puzzles")
    if not puzzles then return out end
    for _, d in ipairs(puzzles:GetDescendants()) do
        if d:IsA("ClickDetector") and d.Parent and d.Parent.Name == "ValveButton" then
            table.insert(out, d)
        elseif d:IsA("ProximityPrompt") and d.Parent and d.Parent.Name == "ValveButton" then
            table.insert(out, d)
        end
    end
    return out
end

local function spamClickDetector(cd, duration)
    local t0 = tick()
    while cd and cd.Parent and tick() - t0 < duration do
        pcall(function()
            if cd.MaxActivationDistance then cd.MaxActivationDistance = math.huge end
            fireclickdetector(cd)
        end)
        task.wait(0.05)
    end
end

local function spamPrompt(pp, duration)
    local t0 = tick()
    while pp and pp.Parent and tick() - t0 < duration do
        pcall(function()
            fireproximityprompt(pp, 1)
        end)
        task.wait(0.05)
    end
end

local function instantFinishValve(duration)
    duration = duration or 4
    local targets = collectValveActivators()
    if #targets == 0 then return end
    for _, obj in ipairs(targets) do
        if obj:IsA("ClickDetector") then
            task.spawn(spamClickDetector, obj, duration)
        else
            task.spawn(spamPrompt, obj, duration)
        end
    end
end

local ESPSection = Tabs.ESP:AddSection("ESP Toggles")

local ComboCodeSection = Tabs.ESP:AddSection("Combination Puzzle")
local comboUI = ComboCodeSection:AddParagraph({ Title = "Combination Code", Content = "—" })
comboParagraph = comboUI

local autoChatComboActive = false
local autoChatWatcher = nil
local lastSentCombo = nil
local lastObservedCombo = nil
local scheduleToken = 0
local chatDelaySeconds = 20

local function scheduleDelayedSend(code)
    scheduleToken = scheduleToken + 1
    local myToken = scheduleToken
    task.delay(chatDelaySeconds, function()
        if autoChatComboActive and myToken == scheduleToken and comboCurrentCode == code and lastSentCombo ~= code then
            sendChatMessage("code: " .. tostring(code))
            lastSentCombo = code
        end
    end)
end

local function startAutoChatCombo()
    if autoChatWatcher then task.cancel(autoChatWatcher) end
    lastObservedCombo = nil
    autoChatWatcher = task.spawn(function()
        while autoChatComboActive do
            local code = comboCurrentCode
            if code and code ~= "" and code ~= lastObservedCombo then
                lastObservedCombo = code
                scheduleDelayedSend(code)
            end
            task.wait(0.3)
        end
    end)
    if comboCurrentCode and comboCurrentCode ~= "" and comboCurrentCode ~= lastSentCombo then
        lastObservedCombo = comboCurrentCode
        scheduleDelayedSend(comboCurrentCode)
    end
end

ComboCodeSection:AddToggle("Auto Chat Combination Code", {
    Title = "Auto Chat Combination Code",
    Default = false,
    Callback = function(state)
        autoChatComboActive = state
        if state then
            startAutoChatCombo()
        else
            if autoChatWatcher then task.cancel(autoChatWatcher); autoChatWatcher=nil end
            scheduleToken = scheduleToken + 1
        end
    end
})

local ESPColorsSection = Tabs.ESP:AddSection("ESP Colors")

ESPSection:AddToggle("Cake ESP", {
    Title = "Cake ESP",
    Default = false,
    Callback = function(state)
        cakeEspActive = state
        if state then
            removeCakeEsp()
            initialScanAndCache(isCakePart, cakeTargets)
            cakeConnAdd, cakeConnRem = hookWorkspace(isCakePart, cakeTargets, cakeConnAdd, cakeConnRem)
            if cakeLoop then task.cancel(cakeLoop) end
            cakeLoop = task.spawn(cakeEspLoopFunction)
        else
            if cakeLoop then task.cancel(cakeLoop); cakeLoop=nil end
            if cakeConnAdd then cakeConnAdd:Disconnect(); cakeConnAdd=nil end
            if cakeConnRem then cakeConnRem:Disconnect(); cakeConnRem=nil end
            removeCakeEsp()
        end
    end
})

ESPSection:AddToggle("Coin ESP", {
    Title = "Coin ESP",
    Default = false,
    Callback = function(state)
        coinEspActive = state
        if state then
            removeCoinEsp()
            initialScanAndCache(isCoinPart, coinTargets)
            coinConnAdd, coinConnRem = hookWorkspace(isCoinPart, coinTargets, coinConnAdd, coinConnRem)
            if coinLoop then task.cancel(coinLoop) end
            coinLoop = task.spawn(coinEspLoopFunction)
        else
            if coinLoop then task.cancel(coinLoop); coinLoop=nil end
            if coinConnAdd then coinConnAdd:Disconnect(); coinConnAdd=nil end
            if coinConnRem then coinConnRem:Disconnect(); coinConnRem=nil end
            removeCoinEsp()
        end
    end
})

ESPSection:AddToggle("Player Chams", {
    Title = "Player Chams",
    Default = false,
    Callback = function(state)
        chamsActive = state
        if state then
            for _, p in ipairs(Players:GetPlayers()) do if p ~= Players.LocalPlayer then hookPlayer(p) end end
            if chamsLoop then task.cancel(chamsLoop) end
            chamsLoop = task.spawn(function()
                while chamsActive do task.wait(1.5) end
            end)
        else
            if chamsLoop then task.cancel(chamsLoop); chamsLoop=nil end
            removeChams()
        end
    end
})

ESPSection:AddToggle("Nametags", {
    Title = "Nametags",
    Default = false,
    Callback = function(state)
        nametagActive = state
        if state then
            for _, p in ipairs(Players:GetPlayers()) do if p ~= Players.LocalPlayer then hookPlayer(p) end end
            if nametagLoop then task.cancel(nametagLoop) end
            nametagLoop = task.spawn(function()
                while nametagActive do task.wait(2.0) end
            end)
        else
            if nametagLoop then task.cancel(nametagLoop); nametagLoop=nil end
            removeNametags()
        end
    end
})

ESPSection:AddToggle("Valve ESP", {
    Title = "Valve ESP",
    Default = false,
    Callback = function(state)
        valveEspActive = state
        if state then
            removeValveEsp()
            initialScanAndCache(isValveBase, valveTargets)
            valveConnAdd, valveConnRem = hookWorkspace(isValveBase, valveTargets, valveConnAdd, valveConnRem)
            if valveLoop then task.cancel(valveLoop) end
            valveLoop = task.spawn(valveEspLoopFunction)
        else
            if valveLoop then task.cancel(valveLoop); valveLoop=nil end
            if valveConnAdd then valveConnAdd:Disconnect(); valveConnAdd=nil end
            if valveConnRem then valveConnRem:Disconnect(); valveConnRem=nil end
            removeValveEsp()
        end
    end
})

ESPSection:AddToggle("Cube Puzzle ESP", {
    Title = "Cube Puzzle ESP",
    Default = false,
    Callback = function(state)
        puzzleNumberEspActive = state
        if state then
            removePuzzleNumberEsp()
            initialScanAndCache(isPuzzleNumber, puzzleNumberTargets)
            puzzleNumConnAdd, puzzleNumConnRem = hookWorkspace(isPuzzleNumber, puzzleNumberTargets, puzzleNumConnAdd, puzzleNumConnRem)
            if puzzleNumberLoop then task.cancel(puzzleNumberLoop) end
            puzzleNumberLoop = task.spawn(puzzleNumberEspLoopFunction)
        else
            if puzzleNumberLoop then task.cancel(puzzleNumberLoop); puzzleNumberLoop=nil end
            if puzzleNumConnAdd then puzzleNumConnAdd:Disconnect(); puzzleNumConnAdd=nil end
            if puzzleNumConnRem then puzzleNumConnRem:Disconnect(); puzzleNumConnRem=nil end
            removePuzzleNumberEsp()
        end
    end
})

ESPSection:AddToggle("Code Puzzle (Label)", {
    Title = "Code Puzzle (Label)",
    Default = false,
    Callback = function(state)
        codePuzzleEspActive = state
        if state then
            codePuzzleLabelAttached = false
            attachCodePuzzleLabelOnce()
            if not codePuzzleConnAdd then
                codePuzzleConnAdd = workspace.DescendantAdded:Connect(function(obj)
                    if not codePuzzleEspActive or codePuzzleLabelAttached then return end
                    if obj:IsA("Model") and obj.Name=="CombinationPuzzle" then
                        local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                        if part and not part:FindFirstChild("PuzzleLabel") then
                            local b = createBillboard("Combination Puzzle")
                            b.Name="PuzzleLabel"
                            b.Parent=part
                            codePuzzleLabelAttached = true
                        end
                    end
                end)
            end
        else
            if codePuzzleConnAdd then codePuzzleConnAdd:Disconnect(); codePuzzleConnAdd=nil end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj:FindFirstChild("PuzzleLabel") then
                    obj.PuzzleLabel:Destroy()
                end
            end
            codePuzzleLabelAttached = false
        end
    end
})

ESPColorsSection:AddColorpicker("Cake ESP", {
    Title = "Cake ESP",
    Default = cakeEspColor,
    Callback = function(color) cakeEspColor = color end
})
ESPColorsSection:AddColorpicker("Coin ESP", {
    Title = "Coin ESP",
    Default = coinEspColor,
    Callback = function(color) coinEspColor = color end
})
ESPColorsSection:AddColorpicker("Enemy Chams", {
    Title = "Enemy Chams",
    Default = enemyChamColor,
    Callback = function(color) enemyChamColor = color end
})
ESPColorsSection:AddColorpicker("Team Chams", {
    Title = "Team Chams",
    Default = teamChamColor,
    Callback = function(color) teamChamColor = color end
})
ESPColorsSection:AddColorpicker("Valve ESP", {
    Title = "Valve ESP",
    Default = valveEspColor,
    Callback = function(color) valveEspColor = color end
})
ESPColorsSection:AddColorpicker("Cube Puzzle ESP", {
    Title = "Cube Puzzle ESP",
    Default = puzzleNumberEspColor,
    Callback = function(color) puzzleNumberEspColor = color end
})
ESPColorsSection:AddColorpicker("Code Puzzle (Label)", {
    Title = "Code Puzzle (Label)",
    Default = codePuzzleLabelColor,
    Callback = function(color) codePuzzleLabelColor = color end
})

local PlayerMovementSection = Tabs.Player:AddSection("Movement")

PlayerMovementSection:AddSlider("Walk Speed", {
    Title = "Walk Speed",
    Default = 16, Min = 16, Max = 45, Rounding = 0,
    Callback = function(value)
        currentSpeed = value
        local c = Players.LocalPlayer.Character
        local h = c and c:FindFirstChild("Humanoid")
        if h then h.WalkSpeed = currentSpeed end
        if value ~= 16 then
            if speedLoop then task.cancel(speedLoop) end
            speedLoop = task.spawn(function()
                while currentSpeed ~= 16 do
                    local cc = Players.LocalPlayer.Character
                    local hh = cc and cc:FindFirstChild("Humanoid")
                    if hh then hh.WalkSpeed = currentSpeed end
                    task.wait(0.1)
                end
            end)
        else
            if speedLoop then task.cancel(speedLoop); speedLoop=nil end
        end
    end
})
PlayerMovementSection:AddButton({
    Title = "Reset Speed",
    Callback = function()
        currentSpeed = 16
        local c = Players.LocalPlayer.Character
        local h = c and c:FindFirstChild("Humanoid")
        if h then h.WalkSpeed = 16 end
        if speedLoop then task.cancel(speedLoop); speedLoop=nil end
    end
})
PlayerMovementSection:AddToggle("Fly (Local)", {
    Title = "Fly (Local)",
    Default = false,
    Callback = function(state) if state then enableFly() else disableFly() end end
})
PlayerMovementSection:AddSlider("Fly Speed", {
    Title = "Fly Speed",
    Default = 50, Min = 1, Max = 200, Rounding = 0,
    Callback = function(value) flySpeed = value end
})
PlayerMovementSection:AddToggle("Noclip", {
    Title = "Noclip",
    Default = false,
    Callback = function(state) if state then enableNoclip() else disableNoclip() end end
})

local PlayerUtilitySection = Tabs.Player:AddSection("Utility")
PlayerUtilitySection:AddToggle("Anti-AFK", {
    Title = "Anti-AFK",
    Default = false,
    Callback = function(state) if state then enableAntiAfk() else disableAntiAfk() end end
})

local AutoSection = Tabs.Auto:AddSection("Auto Features")
AutoSection:AddToggle("Auto Collect Coins", {
    Title = "Auto Collect Coins",
    Default = false,
    Callback = function(state)
        autoCollectCoinsActive = state
        if state then
            if autoCollectCoinsThread then task.cancel(autoCollectCoinsThread) end
            autoCollectCoinsThread = task.spawn(autoCollectCoinsFunc)
        else
            if autoCollectCoinsThread then task.cancel(autoCollectCoinsThread); autoCollectCoinsThread=nil end
        end
    end
})
AutoSection:AddToggle("Auto Delete Peels", {
    Title = "Auto Delete Peels",
    Default = false,
    Callback = function(state)
        autoDeletePeelsActive = state
        if state then
            if autoDeletePeelsThread then task.cancel(autoDeletePeelsThread) end
            autoDeletePeelsThread = task.spawn(autoDeletePeelsFunc)
        else
            if autoDeletePeelsThread then task.cancel(autoDeletePeelsThread); autoDeletePeelsThread=nil end
        end
    end
})
AutoSection:AddToggle("Auto Delete Lockers", {
    Title = "Auto Delete Lockers",
    Default = false,
    Callback = function(state)
        autoDeleteLockersActive = state
        if state then
            if autoDeleteLockersThread then task.cancel(autoDeleteLockersThread) end
            autoDeleteLockersThread = task.spawn(autoDeleteLockersFunc)
        else
            if autoDeleteLockersThread then task.cancel(autoDeleteLockersThread); autoDeleteLockersThread=nil end
        end
    end
})
AutoSection:AddToggle("Auto Kill", {
    Title = "Auto Kill",
    Default = false,
    Callback = function(state)
        autoKillActive = state
        if state then
            if autoKillThread then task.cancel(autoKillThread) end
            autoKillThread = task.spawn(autoKillFunc)
        else
            if autoKillThread then task.cancel(autoKillThread); autoKillThread=nil end
        end
    end
})
AutoSection:AddButton({
    Title = "Instant Finish Valve",
    Callback = function()
        instantFinishValve(4)
    end
})
AutoSection:AddToggle("Anti Kick Bypass", {
    Title = "Anti Kick Bypass",
    Default = false,
    Callback = function(state) if state then startAntiKick() else stopAntiKick() end end
})

local VisualSection = Tabs.Visual
VisualSection:AddToggle("Fullbright", {
    Title="Fullbright", Default=false,
    Callback=function(state)
        fullbrightActive = state
        if state then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
        else
            restoreLighting()
        end
    end
})
VisualSection:AddToggle("No Fog", {
    Title="No Fog", Default=false,
    Callback=function(state)
        noFogActive = state
        if state then
            if noFogLoop then task.cancel(noFogLoop) end
            noFogLoop = task.spawn(function()
                while noFogActive do
                    Lighting.FogStart = 0
                    Lighting.FogEnd = 1e9
                    task.wait(1)
                end
            end)
        else
            if noFogLoop then task.cancel(noFogLoop); noFogLoop=nil end
            Lighting.FogStart = initialLighting.FogStart
            Lighting.FogEnd = initialLighting.FogEnd
        end
    end
})
VisualSection:AddToggle("Color Correction", {
    Title="Color Correction", Default=false,
    Callback=function(state)
        ccActive = state
        if state then enableColorCorrection() else disableColorCorrection() end
    end
})
VisualSection:AddSlider("Brightness", {
    Title="Brightness", Default=0, Min=-1, Max=1, Rounding=2,
    Callback=function(value) ccBrightness=value; if ccActive and ccEffect then ccEffect.Brightness=value end end
})
VisualSection:AddSlider("Contrast", {
    Title="Contrast", Default=0, Min=-2, Max=2, Rounding=2,
    Callback=function(value) ccContrast=value; if ccActive and ccEffect then ccEffect.Contrast=value end end
})
VisualSection:AddSlider("Saturation", {
    Title="Saturation", Default=1, Min=0, Max=3, Rounding=2,
    Callback=function(value) ccSaturation=value; if ccActive and ccEffect then ccEffect.Saturation=value end end
})
VisualSection:AddToggle("Sun Rays", {
    Title="Sun Rays", Default=false,
    Callback=function(state) sunRaysActive=state; if state then enableSunRays() else disableSunRays() end end
})
VisualSection:AddSlider("Sun Rays Intensity", {
    Title="Sun Rays Intensity", Default=0.3, Min=0, Max=1, Rounding=2,
    Callback=function(value) sunRaysIntensity=value; if sunRaysActive and sunRaysEffect then sunRaysEffect.Intensity=value end end
})

local LightingSection = Tabs.Visual:AddSection("Lighting Controls")
LightingSection:AddSlider("Time of Day", {
    Title="Time of Day", Default=initialLighting.ClockTime, Min=0, Max=24, Rounding=1,
    Callback=function(value) Lighting.ClockTime = value end
})
LightingSection:AddSlider("Exposure", {
    Title="Exposure", Default=initialLighting.ExposureCompensation, Min=-3, Max=3, Rounding=2,
    Callback=function(value) Lighting.ExposureCompensation = value end
})
LightingSection:AddToggle("Shadows", {
    Title="Shadows", Default=initialLighting.GlobalShadows,
    Callback=function(state) Lighting.GlobalShadows = state end
})

local UtilitySection = Tabs.Visual:AddSection("Utility")
UtilitySection:AddButton({
    Title="Reset All Visual",
    Callback=function()
        if ccEffect then ccEffect:Destroy(); ccEffect=nil end
        if sunRaysEffect then sunRaysEffect:Destroy(); sunRaysEffect=nil end
        if noFogLoop then task.cancel(noFogLoop); noFogLoop=nil; noFogActive=false end
        ccActive=false; sunRaysActive=false; fullbrightActive=false
        restoreLighting()
        Fluent:Notify({ Title="Visual Reset", Content="Lighting restored to original", Duration=3 })
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
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,30); corner.Parent = toggleButton
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(100,100,100); stroke.Thickness = 2; stroke.Parent = toggleButton
    toggleButton.MouseButton1Click:Connect(function()
        isGuiVisible = not isGuiVisible
        if Window and Window.Root then Window.Root.Visible = isGuiVisible end
        toggleButton.Text = isGuiVisible and "🎮" or "📱"
        toggleButton.BackgroundColor3 = isGuiVisible and Color3.fromRGB(30,30,30) or Color3.fromRGB(60,60,60)
    end)
    local dragging, dragStart, startPos = false, nil, nil
    toggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = toggleButton.Position
        end
    end)
    toggleButton.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            toggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    toggleButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function setupChatCommands()
    local function onChatted(message)
        local msg = message:lower()
        if msg == "/gui" or msg == "/menu" or msg == "/toggle" then
            isGuiVisible = not isGuiVisible
            if Window and Window.Root then Window.Root.Visible = isGuiVisible end
            Fluent:Notify({ Title="GUI Toggle", Content="Menu "..(isGuiVisible and "opened" or "closed"), Duration=2 })
        elseif msg == "/help" then
            Fluent:Notify({ Title="Chat Commands", Content="/gui, /menu, /toggle\n/help", Duration=5 })
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

if isMobile then task.wait(2); createMobileGUIButton(); setupChatCommands() else setupChatCommands() end

Players.LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart")
    task.wait(0.5)
    if speedLoop and currentSpeed ~= 16 then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then humanoid.WalkSpeed = currentSpeed end
    end
    if flyActive then task.wait(0.5); disableFly(); task.wait(0.5); enableFly() end
    if noclipActive then task.wait(0.5); disableNoclip(); task.wait(0.5); enableNoclip() end
end)

Players.PlayerAdded:Connect(function(p) if p ~= Players.LocalPlayer then hookPlayer(p) end end)
for _, p in ipairs(Players:GetPlayers()) do if p ~= Players.LocalPlayer then hookPlayer(p) end end

Fluent:Notify({ Title="Banana Eats Script", Content="Loaded", Duration=4 })
Window:SelectTab(1)

startComboWatcher()
