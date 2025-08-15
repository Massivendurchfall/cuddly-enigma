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
local LP = Players.LocalPlayer

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
    for k, v in pairs(initialLighting) do pcall(function() Lighting[k] = v end) end
end

local Window = Fluent:CreateWindow({
    Title = "Banana Eats Script",
    SubTitle = "by Massivendurchfall",
    TabWidth = 160,
    Size = UDim2.fromOffset(620, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = isMobile and nil or Enum.KeyCode.LeftControl
})

local Tabs = {
    ESP = Window:AddTab({ Title = "ESP", Icon = "eye" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Auto = Window:AddTab({ Title = "Auto", Icon = "settings-2" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "sun" }),
    Farm = Window:AddTab({ Title = "Farm", Icon = "sprout" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "sliders" })
}

local mobileToggleBtn
do
    if isMobile then
        local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
        local sg = Instance.new("ScreenGui")
        sg.Name = "BE_MobileToggle"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = guiParent
        local btn = Instance.new("TextButton")
        btn.Name = "Toggle"
        btn.AnchorPoint = Vector2.new(1,0)
        btn.Position = UDim2.new(1, -12, 0, 12)
        btn.Size = UDim2.new(0, 120, 0, 40)
        btn.Text = "GUI: ON"
        btn.BackgroundTransparency = 0.2
        btn.BackgroundColor3 = Color3.fromRGB(20,20,20)
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.AutoButtonColor = true
        btn.Parent = sg
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(80,80,80)
        btn.MouseButton1Click:Connect(function()
            isGuiVisible = not isGuiVisible
            if Window and Window.Root then Window.Root.Visible = isGuiVisible end
            btn.Text = "GUI: " .. (isGuiVisible and "ON" or "OFF")
        end)
        mobileToggleBtn = btn
    end
end

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
    textLabel.TextColor3 = Color3.new(1,1,1)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0,0,0)
    textLabel.Name = "Label"
    textLabel.Parent = billboard
    return billboard
end

local function makeBoxAdornment(part, name, color, extra)
    local esp = Instance.new("BoxHandleAdornment")
    esp.Name = name
    esp.Adornee = part
    esp.AlwaysOnTop = true
    esp.ZIndex = 10
    esp.Size = part.Size + (extra or Vector3.new(0.2,0.2,0.2))
    esp.Transparency = 0.5
    esp.Color3 = color
    esp.Parent = part
    return esp
end

local function safePrimary(model)
    if model and model:IsA("Model") then
        return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function getHRP()
    local c = LP.Character or LP.CharacterAdded:Wait()
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp end
    c:WaitForChild("HumanoidRootPart")
    return c:FindFirstChild("HumanoidRootPart")
end

local function forceTP(cf)
    local c = LP.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    local hrp = getHRP()
    if hum then
        hum.Sit = false
        hum.PlatformStand = false
    end
    for _=1,6 do
        pcall(function() hrp.CFrame = cf end)
        task.wait(0.05)
        if (hrp.CFrame.Position - cf.Position).Magnitude < 1.5 then return end
        pcall(function() c:PivotTo(cf) end)
        task.wait(0.05)
        if (hrp.CFrame.Position - cf.Position).Magnitude < 1.5 then return end
    end
end

local cakeEspActive, cakeLoop, cakeConnAdd, cakeConnRem = false, nil, nil, nil
local cakeEspColor = Color3.fromRGB(255,255,0)
local cakeTargets = {}

local coinEspActive, coinLoop, coinConnAdd, coinConnRem = false, nil, nil, nil
local coinEspColor = Color3.fromRGB(0,255,0)
local coinTargets = {}

local coinAutoParts = {}
local coinAutoConnAdd, coinAutoConnRem = nil, nil
local lastCoinTouch = setmetatable({}, {__mode="k"})
local COIN_TOUCHES_PER_STEP = isMobile and 2 or 12
local COIN_STEP_DELAY = isMobile and 0.35 or 0.10
local COIN_DEBOUNCE = isMobile and 1.00 or 0.45
local COIN_MAX_RADIUS = isMobile and 85 or 180

local chamsActive, chamsLoop = false, nil
local enemyChamColor = Color3.fromRGB(255,0,0)
local teamChamColor = Color3.fromRGB(0,255,0)

local nametagActive, nametagLoop = false, nil

local valveEspActive, valveLoop, valveConnAdd, valveConnRem = false, nil, nil, nil
local valveEspColor = Color3.fromRGB(0,255,255)
local valveTargets = {}

local puzzleNumberEspActive, puzzleNumberLoop, puzzleNumConnAdd, puzzleNumConnRem = false, nil, nil, nil
local puzzleNumberEspColor = Color3.fromRGB(255,255,255)
local puzzleNumbers = {["23"]=true,["34"]=true,["31"]=true}
local puzzleNumberTargets = {}

local comboLabelEspActive = false
local codePuzzleLabelAttached = false
local codePuzzleConnAdd = nil
local codePuzzleLabelColor = Color3.fromRGB(0,255,0)

local comboParagraph
local comboLoop = nil
local comboCurrentCode = nil

local speedLoop = nil
local currentSpeed = 16
local flyActive = false
local flySpeed = 50
local flyBodyVelocity, flyBodyGyro, flyConnection = nil,nil,nil
local noclipActive = false
local noclipConnection = nil
local noclipParts = {}

local fullbrightActive = false
local noFogActive, noFogLoop = false, nil
local ccActive, ccEffect = false, nil
local ccBrightness, ccContrast, ccSaturation = 0,0,1
local sunRaysActive, sunRaysEffect = false, nil
local sunRaysIntensity = 0.3

local autoDeletePeelsActive, autoDeletePeelsThread = false, nil
local autoCollectCoinsActive, autoCollectCoinsThread = false, nil
local autoDeleteLockersActive, autoDeleteLockersThread = false, nil
local autoKillActive, autoKillThread = false, nil

local autoBonusBarrelActive, autoBonusBarrelThread = false, nil
local lastBonusClaim, bonusBarrelCooldown = 0, 2

local autoChatComboActive = false
local autoChatWatcher = nil
local lastSentCombo = nil
local lastObservedCombo = nil
local scheduleToken = 0
local chatDelaySeconds = 30

local AC_CLICK_TIME_PER_PLATE = 2.5
local AC_SCAN_INTERVAL        = 0.20
local AC_EMPTY_SCANS_TO_EXIT  = 10
local AC_GRACE_AFTER_PICK     = 0.70

local autoEscapeMonitorEnabled, autoEscapeThread = false, nil
local autoEscapeCooldownSeconds = 120
local lastAutoEscapeTouch = 0
local antiKickConnection = nil
local antiAfkConnection = nil

local autoKillInterval = 1
local akIndex = 1

local function clearAdornment(part, name) if part and part:FindFirstChild(name) then part[name]:Destroy() end end
local function clearBillboard(part, name) if part and part:FindFirstChild(name) then part[name]:Destroy() end end
local function removeCakeEsp() for part in pairs(cakeTargets) do if part and part.Parent then clearAdornment(part,"CakeESP"); clearBillboard(part,"CakeLabel") end end; cakeTargets = {} end
local function removeCoinEsp() for part in pairs(coinTargets) do if part and part.Parent then clearAdornment(part,"CoinESP"); clearBillboard(part,"CoinLabel") end end; coinTargets = {} end
local function removeValveEsp() for part in pairs(valveTargets) do if part and part.Parent then clearAdornment(part,"ValveESP"); clearBillboard(part,"ValveLabel") end end; valveTargets = {} end
local function removePuzzleNumberEsp() for part in pairs(puzzleNumberTargets) do if part and part.Parent then clearAdornment(part,"PuzzleNumberESP"); clearBillboard(part,"PuzzleNumberLabel") end end; puzzleNumberTargets = {} end

local function removeChams()
    for _, plyr in pairs(Players:GetPlayers()) do
        if plyr.Character then
            for _, part in pairs(plyr.Character:GetDescendants()) do
                if part:IsA("BasePart") and part:FindFirstChild("Cham") then part.Cham:Destroy() end
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
    return (p and p.Name=="Token" and obj.Name=="Token") or (p and p.Name=="Tokens" and obj.Name=="Token")
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
        if predicate(obj) then cacheTable[obj] = true end
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
                if not part:FindFirstChild("CakeESP") then makeBoxAdornment(part,"CakeESP",cakeEspColor) else part.CakeESP.Color3 = cakeEspColor end
                if not part:FindFirstChild("CakeLabel") then local b = createBillboard("Cake Plate"); b.Name="CakeLabel"; b.Parent = part end
            else cakeTargets[part] = nil end
        end
        task.wait(waitTime)
    end
end

local function coinEspLoopFunction()
    local waitTime = isMobile and 0.5 or 0.25
    while coinEspActive do
        for part in pairs(coinTargets) do
            if part and part.Parent then
                if not part:FindFirstChild("CoinESP") then makeBoxAdornment(part,"CoinESP",coinEspColor) else part.CoinESP.Color3 = coinEspColor end
                if not part:FindFirstChild("CoinLabel") then local b = createBillboard("Coin"); b.Name="CoinLabel"; b.Parent = part end
            else coinTargets[part] = nil end
        end
        task.wait(waitTime)
    end
end

local function valveEspLoopFunction()
    local waitTime = isMobile and 0.6 or 0.3
    while valveEspActive do
        for base in pairs(valveTargets) do
            if base and base.Parent then
                local part = (base:IsA("BasePart") and base) or safePrimary(base)
                if part then
                    if not part:FindFirstChild("ValveESP") then makeBoxAdornment(part,"ValveESP",valveEspColor) else part.ValveESP.Color3 = valveEspColor end
                    if not part:FindFirstChild("ValveLabel") then local b = createBillboard("Valve"); b.Name="ValveLabel"; b.Parent = part end
                end
            else valveTargets[base] = nil end
        end
        task.wait(waitTime)
    end
end

local function puzzleNumberEspLoopFunction()
    local waitTime = isMobile and 0.6 or 0.3
    while puzzleNumberEspActive do
        for part in pairs(puzzleNumberTargets) do
            if part and part.Parent then
                if not part:FindFirstChild("PuzzleNumberESP") then makeBoxAdornment(part,"PuzzleNumberESP",puzzleNumberEspColor) else part.PuzzleNumberESP.Color3 = puzzleNumberEspColor end
                if not part:FindFirstChild("PuzzleNumberLabel") then local b = createBillboard("Cube Puzzle"); b.Name="PuzzleNumberLabel"; b.Parent = part end
            else puzzleNumberTargets[part] = nil end
        end
        task.wait(waitTime)
    end
end

local function findCombinationPuzzleModel()
    local gk = workspace:FindFirstChild("GameKeeper")
    if not gk then return nil end
    local puzzles = gk:FindFirstChild("Puzzles")
    if not puzzles then return nil end
    return puzzles:FindFirstChild("CombinationPuzzle")
end

local function findCombinationPuzzlePart()
    local cp = findCombinationPuzzleModel()
    if not cp then return nil end
    local target = cp.PrimaryPart or cp:FindFirstChildWhichIsA("BasePart", true)
    return target
end

local function getComboButtonsFolder()
    local cp = findCombinationPuzzleModel()
    if not cp then return nil end
    local key = cp:FindFirstChild("CombinationKey")
    if not key then return nil end
    return key:FindFirstChild("Buttons")
end

local function readCombinationCode()
    local root = getComboButtonsFolder()
    if not root then return nil end
    local out = {}
    for i = 1, 3 do
        local btn = root:FindFirstChild("Button"..i); if not btn then return nil end
        local bl = btn:FindFirstChild("ButtonLabel"); if not bl then return nil end
        local label = bl:FindFirstChild("Label"); if not (label and label:IsA("TextLabel")) then return nil end
        local txt = tostring(label.Text or "")
        local digit = txt:match("(%d)%s*$") or txt:match("(%d)") or ""
        if digit == "" then return nil end
        table.insert(out, digit)
    end
    return table.concat(out, "")
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

local function ensureComboLabel(state)
    if state then
        codePuzzleLabelAttached = false
        attachCodePuzzleLabelOnce()
        if not codePuzzleConnAdd then
            codePuzzleConnAdd = workspace.DescendantAdded:Connect(function(obj)
                if not comboLabelEspActive or codePuzzleLabelAttached then return end
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
            if obj:IsA("BasePart") and obj:FindFirstChild("PuzzleLabel") then obj.PuzzleLabel:Destroy() end
        end
        codePuzzleLabelAttached = false
    end
end

local function startComboWatcher()
    if comboLoop then task.cancel(comboLoop) end
    comboLoop = task.spawn(function()
        while true do
            local code = nil
            pcall(function() code = readCombinationCode() end)
            comboCurrentCode = code
            if comboParagraph then comboParagraph:SetDesc(code and code or "—") end
            task.wait(0.4)
        end
    end)
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
            local say = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
            if say then say:FireServer(msg, "All"); ok = true end
        end)
    end
    return ok
end

local function collectValveActivators()
    local out = {}
    local gk = workspace:FindFirstChild("GameKeeper")
    if not gk then return out end
    local puzzles = gk:FindFirstChild("Puzzles")
    if not puzzles then return out end
    for _, d in ipairs(puzzles:GetDescendants()) do
        if d:IsA("ClickDetector") and d.Parent and d.Parent.Name=="ValveButton" then
            table.insert(out, d)
        elseif d:IsA("ProximityPrompt") and d.Parent and d.Parent.Name=="ValveButton" then
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
        pcall(function() fireproximityprompt(pp, 1) end)
        task.wait(0.05)
    end
end

local function instantFinishValve(duration)
    duration = duration or 4
    local targets = collectValveActivators()
    if #targets == 0 then return end
    for _, obj in ipairs(targets) do
        if obj:IsA("ClickDetector") then task.spawn(spamClickDetector, obj, duration)
        else task.spawn(spamPrompt, obj, duration) end
    end
end

local function fireTouch(part)
    local hrp = getHRP(); if not hrp or not part or not part.Parent then return end
    pcall(function()
        firetouchinterest(hrp, part, 0)
        task.wait(0.05)
        firetouchinterest(hrp, part, 1)
    end)
end

local function startCoinTracker()
    if coinAutoConnAdd or coinAutoConnRem then return end
    initialScanAndCache(isCoinPart, coinAutoParts)
    coinAutoConnAdd, coinAutoConnRem = hookWorkspace(isCoinPart, coinAutoParts, coinAutoConnAdd, coinAutoConnRem)
end

local function stopCoinTracker()
    if coinAutoConnAdd then coinAutoConnAdd:Disconnect(); coinAutoConnAdd=nil end
    if coinAutoConnRem then coinAutoConnRem:Disconnect(); coinAutoConnRem=nil end
    coinAutoParts = {}
    lastCoinTouch = setmetatable({}, {__mode="k"})
end

local function autoCollectCoinsFunc()
    while autoCollectCoinsActive do
        local hrp = nil
        local ok = pcall(function() hrp = getHRP() end)
        if not ok or not hrp then
            task.wait(COIN_STEP_DELAY)
        else
            local snapshot = {}
            for token,_ in pairs(coinAutoParts) do
                if token and token.Parent and token:IsA("BasePart") then
                    local d = (token.Position - hrp.Position).Magnitude
                    if d <= COIN_MAX_RADIUS then
                        snapshot[#snapshot+1] = {part = token, dist = d}
                    end
                else
                    coinAutoParts[token] = nil
                    lastCoinTouch[token] = nil
                end
            end
            table.sort(snapshot, function(a,b) return a.dist < b.dist end)
            local count = 0
            for i = 1, #snapshot do
                if not autoCollectCoinsActive then break end
                local token = snapshot[i].part
                if token and token.Parent then
                    local lt = lastCoinTouch[token] or 0
                    if (tick() - lt) >= COIN_DEBOUNCE then
                        fireTouch(token)
                        lastCoinTouch[token] = tick()
                        count += 1
                        if count >= COIN_TOUCHES_PER_STEP then break end
                        task.wait(isMobile and 0.05 or 0.02)
                    end
                end
            end
            task.wait(COIN_STEP_DELAY)
        end
    end
end

local function findEscapeTouchParts()
    local out = {}
    local gk = workspace:FindFirstChild("GameKeeper"); if not gk then return out end
    local exits = gk:FindFirstChild("Exits"); if not exits then return out end
    for _, door in ipairs(exits:GetChildren()) do
        local root = door:FindFirstChild("Root", true) or door:FindFirstChild("Root")
        if root and root:IsA("BasePart") then
            if root:FindFirstChildOfClass("TouchTransmitter") or root:FindFirstChild("TouchInterest") then
                table.insert(out, root)
            end
        end
    end
    return out
end

local function tryAutoEscapeOnce()
    local parts = findEscapeTouchParts()
    if #parts == 0 then return false end
    local hrp = getHRP()
    local touched = false
    for _, part in ipairs(parts) do
        if hrp and (hrp.Position - part.Position).Magnitude > 8 then
            hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))
            task.wait(0.06)
        end
        fireTouch(part)
        touched = true
    end
    return touched
end

local function setAutoEscapeMonitor(state)
    if state and not autoEscapeMonitorEnabled then
        autoEscapeMonitorEnabled = true
        if autoEscapeThread then task.cancel(autoEscapeThread) end
        autoEscapeThread = task.spawn(function()
            while autoEscapeMonitorEnabled do
                if LP.Team and LP.Team.Name == "Runners" then
                    if (tick() - lastAutoEscapeTouch) >= autoEscapeCooldownSeconds then
                        local ok = false
                        pcall(function() ok = tryAutoEscapeOnce() end)
                        if ok then
                            lastAutoEscapeTouch = tick()
                            Fluent:Notify({ Title="Auto Escape", Content="Exit touched. Cooldown started (120s).", Duration=3 })
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end
    if not state and autoEscapeMonitorEnabled then
        autoEscapeMonitorEnabled = false
        if autoEscapeThread then task.cancel(autoEscapeThread); autoEscapeThread=nil end
    end
end

local function waitForPath(root, segments, timeout)
    local t0 = tick()
    local node = root
    for _, name in ipairs(segments) do
        local left = timeout and math.max(0, timeout - (tick()-t0)) or 5
        node = node:FindFirstChild(name) or node:WaitForChild(name, left)
        if not node then return nil end
    end
    return node
end

local function getActiveCakePlates()
    local items = waitForPath(workspace, {"GameKeeper","Map","Items"}, 5)
    local list = {}
    if not items then return list end
    for _, cp in ipairs(items:GetChildren()) do
        if cp.Name == "CakePlate" then
            local root = cp:FindFirstChild("Model")
            root = root and root:FindFirstChild("CakePlate")
            root = root and root:FindFirstChild("Root")
            local cd = root and (root:FindFirstChildOfClass("ClickDetector") or root:FindFirstChildWhichIsA("ClickDetector", true))
            if cd then
                table.insert(list, {inst = cp, cd = cd})
            end
        end
    end
    return list
end

local function clickUntilGone(entry, timeout)
    timeout = timeout or 3
    local t0 = tick()
    while entry.inst and entry.inst.Parent and tick() - t0 < timeout do
        if not entry.cd or not entry.cd.Parent then break end
        pcall(function()
            if entry.cd.MaxActivationDistance then entry.cd.MaxActivationDistance = math.huge end
            fireclickdetector(entry.cd)
        end)
        task.wait(0.05)
    end
end

local function getCakeDepositPart()
    local gk = workspace:FindFirstChild("GameKeeper")
    local puzzles = gk and gk:FindFirstChild("Puzzles")
    local cp = puzzles and puzzles:FindFirstChild("CakePuzzle")
    local root = cp and cp:FindFirstChild("Root")
    return root
end

local function depositCakeTouch(times)
    local part = getCakeDepositPart()
    if not part then return end
    for i=1,(times or 3) do
        fireTouch(part)
        task.wait(0.06)
    end
end

local function autoCakeOnce()
    local emptyScans = 0
    local lastPick = 0
    while true do
        if tick() - lastPick < AC_GRACE_AFTER_PICK then
            task.wait(AC_SCAN_INTERVAL)
        end
        local plates = getActiveCakePlates()
        if #plates == 0 then
            emptyScans += 1
            if emptyScans >= AC_EMPTY_SCANS_TO_EXIT then
                break
            end
            task.wait(AC_SCAN_INTERVAL)
        else
            emptyScans = 0
            for _, entry in ipairs(plates) do
                clickUntilGone(entry, AC_CLICK_TIME_PER_PLATE)
                depositCakeTouch(3)
                lastPick = tick()
                task.wait(AC_SCAN_INTERVAL)
            end
        end
    end
    Fluent:Notify({ Title="Auto Cake", Content="Done.", Duration=3 })
end

local function getDialFolder()
    local cp = findCombinationPuzzleModel()
    if not cp then return nil end
    return cp:FindFirstChild("Buttons")
end

local function readDialDigit(dial)
    local bl = dial and dial:FindFirstChild("ButtonLabel")
    local lbl = bl and bl:FindFirstChild("Label")
    local txt = lbl and (lbl.Text or "")
    local n = tonumber(tostring(txt):match("(%d)%s*$") or "")
    return n or 1
end

local function pressDialTo(dial, targetDigit)
    targetDigit = math.clamp(tonumber(targetDigit) or 1, 1, 9)
    local cd = dial and dial:FindFirstChildOfClass("ClickDetector") or dial:FindFirstChildWhichIsA("ClickDetector", true)
    if not cd then return end
    local cur = readDialDigit(dial)
    local delta = (targetDigit - cur) % 9
    for _ = 1, delta do
        pcall(function()
            if cd.MaxActivationDistance then cd.MaxActivationDistance = math.huge end
            fireclickdetector(cd)
        end)
        task.wait(0.12)
    end
end

local function enterCombinationOnce()
    local desired = readCombinationCode()
    if not desired or #desired ~= 3 then
        Fluent:Notify({ Title="Combination", Content="Code not visible.", Duration=3 })
        return
    end
    local buttons = getDialFolder()
    if not buttons then
        Fluent:Notify({ Title="Combination", Content="Dial folder not found.", Duration=3 })
        return
    end
    for i = 1, 3 do
        local dial = buttons:FindFirstChild("Button"..i)
        if dial then pressDialTo(dial, tonumber(desired:sub(i,i))) end
    end
    Fluent:Notify({ Title="Combination", Content="Entered: "..desired, Duration=3 })
end

local function getAllPictureButtonsFolders()
    local list = {}
    local gk = workspace:FindFirstChild("GameKeeper")
    local puzzles = gk and gk:FindFirstChild("Puzzles")
    if puzzles then
        for _, obj in ipairs(puzzles:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "PicturePuzzle" then
                local buttons = obj:FindFirstChild("Buttons")
                if buttons then table.insert(list, buttons) end
            end
        end
    end
    return list
end

local function isTileGreen(btn)
    local ui = btn:FindFirstChild("ButtonLabel")
    local img = ui and ui:FindFirstChild("ImageLabel")
    if img and img:IsA("ImageLabel") then
        local c = img.ImageColor3 or Color3.new(1,1,1)
        return (c.G > 0.75 and c.R < 0.5 and c.B < 0.5)
    end
    return false
end

local function rotateTileOnce(btn)
    local cd = btn:FindFirstChildOfClass("ClickDetector") or btn:FindFirstChildWhichIsA("ClickDetector", true)
    if not cd then return end
    pcall(function()
        if cd.MaxActivationDistance then cd.MaxActivationDistance = math.huge end
        fireclickdetector(cd)
    end)
end

local function solvePicturePuzzleOnce()
    local folders = getAllPictureButtonsFolders()
    if #folders == 0 then
        Fluent:Notify({ Title="Picture Puzzle", Content="No puzzles found.", Duration=3 })
        return
    end
    local solved = 0
    for _, folder in ipairs(folders) do
        for _, btn in ipairs(folder:GetChildren()) do
            if btn:IsA("BasePart") or btn:IsA("MeshPart") then
                local ri = btn:FindFirstChild("RotationIndex")
                local try = 0
                local ok = false
                while try < 3 do
                    if (ri and ri.Value % 4 == 0) or isTileGreen(btn) then
                        ok = true
                        break
                    end
                    rotateTileOnce(btn)
                    try += 1
                    task.wait(0.12)
                end
                if not ok and ri then
                    local need = (4 - (ri.Value % 4)) % 4
                    for i=1,need do rotateTileOnce(btn); task.wait(0.12) end
                end
                rotateTileOnce(btn)
                task.wait(0.12)
            end
        end
        solved += 1
    end
    Fluent:Notify({ Title="Picture Puzzle", Content="Attempted solve on "..tostring(solved).." puzzle(s).", Duration=3 })
end

local function autoBonusBarrelLoop()
    while autoBonusBarrelActive do
        pcall(function()
            local bb = workspace:FindFirstChild("BonusBarrel")
            if not bb then return end
            local hl = bb:FindFirstChild("ClaimHighlight")
            local ready = false
            if hl then
                local ok1, en = pcall(function() return hl.Enabled end)
                if ok1 and en == true then ready = true end
                if not ready then
                    local ok2, vis = pcall(function() return hl.Visible end)
                    if ok2 and vis == true then ready = true end
                end
            end
            if ready and (tick() - lastBonusClaim) > bonusBarrelCooldown then
                local root = bb:FindFirstChild("Root")
                if root and (root:FindFirstChild("TouchInterest") or root:FindFirstChildOfClass("TouchTransmitter")) then
                    for i=1,4 do fireTouch(root); task.wait(0.06) end
                    lastBonusClaim = tick()
                end
            end
        end)
        task.wait(0.2)
    end
end

local function enableAntiAfk()
    if antiAfkConnection then return end
    antiAfkConnection = LP.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end
local function disableAntiAfk() if antiAfkConnection then antiAfkConnection:Disconnect(); antiAfkConnection=nil end end
local function startAntiKick()
    if not antiKickConnection then
        antiKickConnection = LP.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end
local function stopAntiKick() if antiKickConnection then antiKickConnection:Disconnect(); antiKickConnection=nil end end

local setAutoKill
local function getRunnersList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Team and p.Team.Name == "Runners" then
            local c = p.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if h then table.insert(list, {p=p, hrp=h}) end
        end
    end
    table.sort(list, function(a,b) return a.p.UserId < b.p.UserId end)
    return list
end

setAutoKill = function(state)
    if state and not autoKillActive then
        autoKillActive = true
        if autoKillThread then task.cancel(autoKillThread) end
        akIndex = 1
        autoKillThread = task.spawn(function()
            while autoKillActive do
                if not (LP.Team and LP.Team.Name == "Banana") then
                    task.wait(0.5)
                else
                    local runners = getRunnersList()
                    if #runners == 0 then
                        task.wait(0.4)
                    else
                        if akIndex > #runners then akIndex = 1 end
                        local entry = runners[akIndex]
                        akIndex = akIndex + 1
                        local my = getHRP()
                        if my and entry and entry.hrp and entry.hrp.Parent then
                            my.CFrame = CFrame.new(entry.hrp.Position + Vector3.new(0, 2, 0))
                        end
                        task.wait(autoKillInterval)
                    end
                end
            end
        end)
    end
    if not state and autoKillActive then
        autoKillActive = false
        if autoKillThread then task.cancel(autoKillThread); autoKillThread=nil end
    end
end

local function setFly(state)
    if state and not flyActive then
        local character = LP.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local root = character.HumanoidRootPart
            flyBodyVelocity = Instance.new("BodyVelocity", root)
            flyBodyVelocity.Velocity = Vector3.new(0,0,0)
            flyBodyVelocity.MaxForce = Vector3.new(1e5,1e5,1e5)
            flyBodyGyro = Instance.new("BodyGyro", root)
            flyBodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
            flyBodyGyro.CFrame = root.CFrame
            flyActive = true
            flyConnection = RunService.RenderStepped:Connect(function()
                local dir = Vector3.new(0,0,0)
                local cam = workspace.CurrentCamera
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
                flyBodyVelocity.Velocity = (dir.Magnitude>0) and dir.Unit * flySpeed or Vector3.new(0,0,0)
                flyBodyGyro.CFrame = cam.CFrame
            end)
        end
    end
    if not state and flyActive then
        flyActive = false
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity=nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro=nil end
        if flyConnection then flyConnection:Disconnect(); flyConnection=nil end
    end
end

local function setNoclip(state)
    if state and not noclipActive then
        noclipActive = true
        noclipConnection = RunService.Stepped:Connect(function()
            local character = LP.Character
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
    if not state and noclipActive then
        noclipActive = false
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection=nil end
        for part in pairs(noclipParts) do if part and part.Parent then part.CanCollide = true end end
        noclipParts = {}
    end
end

local function setAutoCoins(state)
    if state and not autoCollectCoinsActive then
        autoCollectCoinsActive = true
        startCoinTracker()
        if autoCollectCoinsThread then task.cancel(autoCollectCoinsThread) end
        autoCollectCoinsThread = task.spawn(autoCollectCoinsFunc)
    end
    if not state and autoCollectCoinsActive then
        autoCollectCoinsActive = false
        if autoCollectCoinsThread then task.cancel(autoCollectCoinsThread); autoCollectCoinsThread=nil end
        stopCoinTracker()
    end
end

local function setAutoBarrel(state)
    if state and not autoBonusBarrelActive then
        autoBonusBarrelActive = true
        if autoBonusBarrelThread then task.cancel(autoBonusBarrelThread) end
        autoBonusBarrelThread = task.spawn(autoBonusBarrelLoop)
    end
    if not state and autoBonusBarrelActive then
        autoBonusBarrelActive = false
        if autoBonusBarrelThread then task.cancel(autoBonusBarrelThread); autoBonusBarrelThread=nil end
    end
end

local function setDeletePeels(state)
    if state and not autoDeletePeelsActive then
        autoDeletePeelsActive = true
        if autoDeletePeelsThread then task.cancel(autoDeletePeelsThread) end
        autoDeletePeelsThread = task.spawn(function()
            while autoDeletePeelsActive do
                pcall(function()
                    local peelsFolder = (workspace:FindFirstChild("GameKeeper")
                        and workspace.GameKeeper:FindFirstChild("Map")
                        and workspace.GameKeeper.Map:FindFirstChild("Peels")) or workspace:FindFirstChild("Peels")
                    if peelsFolder then
                        for _, peel in ipairs(peelsFolder:GetChildren()) do
                            if peel and peel.Name:lower():find("peel") then pcall(function() peel:Destroy() end) end
                        end
                    end
                end)
                task.wait(4)
            end
        end)
    end
    if not state and autoDeletePeelsActive then
        autoDeletePeelsActive = false
        if autoDeletePeelsThread then task.cancel(autoDeletePeelsThread); autoDeletePeelsThread=nil end
    end
end

local function setDeleteLockers(state)
    if state and not autoDeleteLockersActive then
        autoDeleteLockersActive = true
        if autoDeleteLockersThread then task.cancel(autoDeleteLockersThread) end
        autoDeleteLockersThread = task.spawn(function()
            while autoDeleteLockersActive do
                pcall(function()
                    for _, d in ipairs(workspace:GetDescendants()) do
                        if d and typeof(d.Name)=="string" and d.Name:lower():find("locker") then pcall(function() d:Destroy() end) end
                    end
                end)
                task.wait(5)
            end
        end)
    end
    if not state and autoDeleteLockersActive then
        autoDeleteLockersActive = false
        if autoDeleteLockersThread then task.cancel(autoDeleteLockersThread); autoDeleteLockersThread=nil end
    end
end

local function turnOffAllAutos()
    setAutoKill(false)
    setAutoCoins(false)
    setAutoBarrel(false)
    setDeletePeels(false)
    setDeleteLockers(false)
    setAutoEscapeMonitor(false)
    setFly(false)
    setNoclip(false)
end

local ESPSection = Tabs.ESP:AddSection("ESP Toggles")
local comboUI = ESPSection:AddParagraph({ Title = "Combination Code", Content = "—" })
comboParagraph = comboUI

ESPSection:AddToggle("ComboCodeLabelESP", {
    Title = "Combination Code Label",
    Default = false,
    Callback = function(state)
        comboLabelEspActive = state
        ensureComboLabel(state)
    end
})

ESPSection:AddToggle("CakeESP", {
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

ESPSection:AddToggle("CoinESP", {
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

ESPSection:AddToggle("PlayerChams", {
    Title = "Player Chams",
    Default = false,
    Callback = function(state)
        chamsActive = state
        local function applyChamsToCharacter(plyr)
            if not plyr or not plyr.Character then return end
            local sameTeam = (plyr.TeamColor == LP.TeamColor)
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
                    else cham.Color3 = color end
                end
            end
        end
        local function hookPlayer(plyr)
            plyr.CharacterAdded:Connect(function()
                task.wait(0.2)
                if chamsActive then applyChamsToCharacter(plyr) end
            end)
            if plyr.Character then if chamsActive then applyChamsToCharacter(plyr) end end
        end
        if state then
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then hookPlayer(p) end end
            if chamsLoop then task.cancel(chamsLoop) end
            chamsLoop = task.spawn(function()
                while chamsActive do
                    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then applyChamsToCharacter(p) end end
                    task.wait(2.0)
                end
            end)
        else
            if chamsLoop then task.cancel(chamsLoop); chamsLoop=nil end
            removeChams()
        end
    end
})

ESPSection:AddToggle("NametagsESP", {
    Title = "Nametags",
    Default = false,
    Callback = function(state)
        nametagActive = state
        local function applyNametagToCharacter(plyr)
            if not plyr or not plyr.Character then return end
            local head = plyr.Character:FindFirstChild("Head"); if not head then return end
            if not head:FindFirstChild("Nametag") then local b = createBillboard(plyr.Name); b.Name="Nametag"; b.Parent = head end
        end
        local function hookPlayer(plyr)
            plyr.CharacterAdded:Connect(function()
                task.wait(0.2)
                if nametagActive then applyNametagToCharacter(plyr) end
            end)
            if plyr.Character then if nametagActive then applyNametagToCharacter(plyr) end end
        end
        if state then
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then hookPlayer(p) end end
            if nametagLoop then task.cancel(nametagLoop) end
            nametagLoop = task.spawn(function()
                while nametagActive do
                    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then applyNametagToCharacter(p) end end
                    task.wait(3.0)
                end
            end)
        else
            if nametagLoop then task.cancel(nametagLoop); nametagLoop=nil end
            removeNametags()
        end
    end
})

ESPSection:AddToggle("ValveESP", {
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

ESPSection:AddToggle("CubePuzzleESP", {
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

local ESPColorsSection = Tabs.ESP:AddSection("ESP Colors")
ESPColorsSection:AddColorpicker("CakeESPColor", { Title="Cake ESP", Default=cakeEspColor, Callback=function(c) cakeEspColor=c end })
ESPColorsSection:AddColorpicker("CoinESPColor", { Title="Coin ESP", Default=coinEspColor, Callback=function(c) coinEspColor=c end })
ESPColorsSection:AddColorpicker("EnemyChamsColor", { Title="Enemy Chams", Default=enemyChamColor, Callback=function(c) enemyChamColor=c end })
ESPColorsSection:AddColorpicker("TeamChamsColor", { Title="Team Chams", Default=teamChamColor, Callback=function(c) teamChamColor=c end })
ESPColorsSection:AddColorpicker("ValveESPColor", { Title="Valve ESP", Default=valveEspColor, Callback=function(c) valveEspColor=c end })
ESPColorsSection:AddColorpicker("CubePuzzleESPColor", { Title="Cube Puzzle ESP", Default=puzzleNumberEspColor, Callback=function(c) puzzleNumberEspColor=c end })
ESPColorsSection:AddColorpicker("CodePuzzleLabelColor", { Title="Code Puzzle (Label)", Default=codePuzzleLabelColor, Callback=function(c) codePuzzleLabelColor=c end })

local PlayerMovementSection = Tabs.Player:AddSection("Movement")
PlayerMovementSection:AddSlider("WalkSpeedSlider", {
    Title="Walk Speed", Default=16, Min=16, Max=45, Rounding=0,
    Callback=function(value)
        currentSpeed = value
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = currentSpeed end
        if value ~= 16 then
            if speedLoop then task.cancel(speedLoop) end
            speedLoop = task.spawn(function()
                while currentSpeed ~= 16 do
                    local hh = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hh then hh.WalkSpeed = currentSpeed end
                    task.wait(0.15)
                end
            end)
        else
            if speedLoop then task.cancel(speedLoop); speedLoop=nil end
        end
    end
})
PlayerMovementSection:AddButton({ Title="Reset Speed", Callback=function()
    currentSpeed = 16
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = 16 end
    if speedLoop then task.cancel(speedLoop); speedLoop=nil end
end})
PlayerMovementSection:AddToggle("FlyToggle", { Title="Fly (Local)", Default=false, Callback=function(state)
    if state then
        local character = LP.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local root = character.HumanoidRootPart
            flyBodyVelocity = Instance.new("BodyVelocity", root)
            flyBodyVelocity.Velocity = Vector3.new(0,0,0)
            flyBodyVelocity.MaxForce = Vector3.new(1e5,1e5,1e5)
            flyBodyGyro = Instance.new("BodyGyro", root)
            flyBodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
            flyBodyGyro.CFrame = root.CFrame
            flyActive = true
            flyConnection = RunService.RenderStepped:Connect(function()
                local dir = Vector3.new(0,0,0)
                local cam = workspace.CurrentCamera
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
                flyBodyVelocity.Velocity = (dir.Magnitude>0) and dir.Unit * flySpeed or Vector3.new(0,0,0)
                flyBodyGyro.CFrame = cam.CFrame
            end)
        end
    else
        flyActive = false
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity=nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro=nil end
        if flyConnection then flyConnection:Disconnect(); flyConnection=nil end
    end
end})
PlayerMovementSection:AddSlider("FlySpeedSlider", { Title="Fly Speed", Default=50, Min=1, Max=200, Rounding=0, Callback=function(v) flySpeed=v end })
PlayerMovementSection:AddToggle("NoclipToggle", { Title="Noclip", Default=false, Callback=function(state)
    if state then
        if noclipActive then return end
        noclipActive = true
        noclipConnection = RunService.Stepped:Connect(function()
            local character = LP.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        noclipParts[part] = true
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if not noclipActive then return end
        noclipActive = false
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection=nil end
        for part in pairs(noclipParts) do if part and part.Parent then part.CanCollide = true end end
        noclipParts = {}
    end
end})

local PlayerUtilitySection = Tabs.Player:AddSection("Utility")
PlayerUtilitySection:AddToggle("AntiAFKToggle", { Title="Anti-AFK", Default=false, Callback=function(state) if state then enableAntiAfk() else disableAntiAfk() end end })

local killer = Tabs.Auto:AddSection("Killer")
killer:AddToggle("AutoKillToggle", {
    Title = "Auto Kill",
    Default = false,
    Callback = function(state)
        setAutoKill(state)
    end
})
killer:AddToggle("DeleteLockersToggle", {
    Title = "Delete Lockers",
    Default = false,
    Callback = function(state)
        setDeleteLockers(state)
    end
})

local runner = Tabs.Auto:AddSection("Runner")
runner:AddToggle("DeletePeelsToggle", {
    Title = "Delete Peels",
    Default = false,
    Callback = function(state)
        setDeletePeels(state)
    end
})
runner:AddToggle("AutoCoinsToggle", {
    Title = "Auto Collect Coins",
    Default = false,
    Callback = function(state)
        setAutoCoins(state)
    end
})
runner:AddToggle("AutoBonusBarrelToggle", {
    Title = "Auto Collect Bonus Barrel",
    Default = false,
    Callback = function(state)
        setAutoBarrel(state)
    end
})
runner:AddButton({
    Title = "Auto Escape (try)",
    Callback = function()
        if (tick() - lastAutoEscapeTouch) < autoEscapeCooldownSeconds then
            Fluent:Notify({ Title="Auto Escape", Content="On cooldown.", Duration=2 })
            return
        end
        local ok = tryAutoEscapeOnce()
        if ok then
            lastAutoEscapeTouch = tick()
            Fluent:Notify({ Title="Auto Escape", Content="Exit touched. Cooldown started (120s).", Duration=3 })
        else
            Fluent:Notify({ Title="Auto Escape", Content="No exit found.", Duration=2 })
        end
    end
})

local puzzles = Tabs.Auto:AddSection("Puzzles")
puzzles:AddButton({ Title="Auto Cake (run once)", Callback=autoCakeOnce })
puzzles:AddButton({ Title="Enter Combination Code (once)", Callback=enterCombinationOnce })
puzzles:AddButton({ Title="Solve Picture Puzzle (once)", Callback=solvePicturePuzzleOnce })
puzzles:AddButton({ Title="Instant Finish Valve", Callback=function() instantFinishValve(4) end })

puzzles:AddToggle("AutoChatComboToggle", {
    Title = "Auto Chat Combination (30s cooldown)",
    Default = false,
    Callback = function(state)
        autoChatComboActive = state
        if state then
            if autoChatWatcher then task.cancel(autoChatWatcher) end
            lastObservedCombo = nil
            autoChatWatcher = task.spawn(function()
                while autoChatComboActive do
                    local code = comboCurrentCode
                    if code and code ~= "" and code ~= lastObservedCombo then
                        lastObservedCombo = code
                        scheduleToken = scheduleToken + 1
                        local myToken = scheduleToken
                        task.delay(chatDelaySeconds, function()
                            if autoChatComboActive and myToken==scheduleToken and comboCurrentCode==code and lastSentCombo ~= code then
                                sendChatMessage("code: " .. tostring(code))
                                lastSentCombo = code
                            end
                        end)
                    end
                    task.wait(0.3)
                end
            end)
            if comboCurrentCode and comboCurrentCode ~= "" and comboCurrentCode ~= lastSentCombo then
                lastObservedCombo = comboCurrentCode
                scheduleToken = scheduleToken + 1
                local myToken = scheduleToken
                task.delay(chatDelaySeconds, function()
                    if autoChatComboActive and myToken==scheduleToken and comboCurrentCode==lastObservedCombo and lastSentCombo ~= lastObservedCombo then
                        sendChatMessage("code: " .. tostring(lastObservedCombo))
                        lastSentCombo = lastObservedCombo
                    end
                end)
            end
        else
            if autoChatWatcher then task.cancel(autoChatWatcher); autoChatWatcher=nil end
            scheduleToken = scheduleToken + 1
        end
    end
})

puzzles:AddToggle("AntiKickToggle", {
    Title = "Anti Kick Bypass",
    Default = false,
    Callback = function(state) if state then startAntiKick() else stopAntiKick() end end
})

local VisualSection = Tabs.Visual:AddSection("Lighting")
VisualSection:AddToggle("FullbrightToggle", { Title="Fullbright", Default=false, Callback=function(state)
    fullbrightActive = state
    if state then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1000000
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
    else restoreLighting() end
end})
VisualSection:AddToggle("NoFogToggle", { Title="No Fog", Default=false, Callback=function(state)
    noFogActive = state
    if state then
        if noFogLoop then task.cancel(noFogLoop) end
        noFogLoop = task.spawn(function() while noFogActive do Lighting.FogStart=0; Lighting.FogEnd=1e9; task.wait(1) end end)
    else
        if noFogLoop then task.cancel(noFogLoop); noFogLoop=nil end
        Lighting.FogStart = initialLighting.FogStart
        Lighting.FogEnd = initialLighting.FogEnd
    end
end})
VisualSection:AddToggle("CCToggle", { Title="Color Correction", Default=false, Callback=function(state)
    ccActive = state
    if state then
        if not Lighting:FindFirstChild("ColorCorrectionEffect") then
            ccEffect = Instance.new("ColorCorrectionEffect"); ccEffect.Parent = Lighting
        else ccEffect = Lighting:FindFirstChild("ColorCorrectionEffect") end
        ccEffect.Brightness = ccBrightness; ccEffect.Contrast=ccContrast; ccEffect.Saturation=ccSaturation
    else if ccEffect then ccEffect:Destroy(); ccEffect=nil end end
end})
VisualSection:AddSlider("CCBrightness", { Title="Brightness", Default=0, Min=-1, Max=1, Rounding=2, Callback=function(v) ccBrightness=v; if ccActive and ccEffect then ccEffect.Brightness=v end end })
VisualSection:AddSlider("CCContrast", { Title="Contrast", Default=0, Min=-2, Max=2, Rounding=2, Callback=function(v) ccContrast=v; if ccActive and ccEffect then ccEffect.Contrast=v end end })
VisualSection:AddSlider("CCSaturation", { Title="Saturation", Default=1, Min=0, Max=3, Rounding=2, Callback=function(v) ccSaturation=v; if ccActive and ccEffect then ccEffect.Saturation=v end end })
VisualSection:AddToggle("SunRaysToggle", { Title="Sun Rays", Default=false, Callback=function(state)
    sunRaysActive=state
    if state then
        if not Lighting:FindFirstChild("SunRaysEffect") then sunRaysEffect = Instance.new("SunRaysEffect"); sunRaysEffect.Parent = Lighting
        else sunRaysEffect = Lighting:FindFirstChild("SunRaysEffect") end
        sunRaysEffect.Intensity = sunRaysIntensity
    else if sunRaysEffect then sunRaysEffect:Destroy(); sunRaysEffect=nil end end
end})
VisualSection:AddSlider("SunRaysIntensity", { Title="Sun Rays Intensity", Default=0.3, Min=0, Max=1, Rounding=2, Callback=function(v) sunRaysIntensity=v; if sunRaysActive and sunRaysEffect then sunRaysEffect.Intensity=v end end })

local LightingSection = Tabs.Visual:AddSection("Lighting Controls")
LightingSection:AddSlider("TimeOfDaySlider", { Title="Time of Day", Default=initialLighting.ClockTime, Min=0, Max=24, Rounding=1, Callback=function(v) Lighting.ClockTime=v end })
LightingSection:AddSlider("ExposureSlider", { Title="Exposure", Default=initialLighting.ExposureCompensation, Min=-3, Max=3, Rounding=2, Callback=function(v) Lighting.ExposureCompensation=v end })
LightingSection:AddToggle("ShadowsToggle", { Title="Shadows", Default=initialLighting.GlobalShadows, Callback=function(state) Lighting.GlobalShadows=state end })

local UtilitySection = Tabs.Visual:AddSection("Utility")
UtilitySection:AddButton({ Title="Reset All Visual", Callback=function()
    if ccEffect then ccEffect:Destroy(); ccEffect=nil end
    if sunRaysEffect then sunRaysEffect:Destroy(); sunRaysEffect=nil end
    if noFogLoop then task.cancel(noFogLoop); noFogLoop=nil; noFogActive=false end
    ccActive=false; sunRaysActive=false; fullbrightActive=false
    restoreLighting()
    Fluent:Notify({ Title="Visual Reset", Content="Lighting restored.", Duration=3 })
end})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

local function setupChatCommands()
    local function onChatted(message)
        local msg = message:lower()
        if msg=="/gui" or msg=="/menu" or msg=="/toggle" then
            isGuiVisible = not isGuiVisible
            if Window and Window.Root then Window.Root.Visible = isGuiVisible end
            if mobileToggleBtn then mobileToggleBtn.Text = "GUI: " .. (isGuiVisible and "ON" or "OFF") end
            Fluent:Notify({ Title="GUI Toggle", Content="Menu "..(isGuiVisible and "opened" or "closed"), Duration=2 })
        elseif msg=="/help" then
            Fluent:Notify({ Title="Chat Commands", Content="/gui, /menu, /toggle\n/help", Duration=5 })
        end
    end
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        TextChatService.MessageReceived:Connect(function(m)
            if m.TextSource and m.TextSource.UserId == LP.UserId then onChatted(m.Text) end
        end)
    else
        LP.Chatted:Connect(onChatted)
    end
end
setupChatCommands()

LP.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart")
    task.wait(0.5)
    if speedLoop and currentSpeed ~= 16 then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then humanoid.WalkSpeed = currentSpeed end
    end
    if flyActive then task.wait(0.5); if flyConnection then flyConnection:Disconnect(); flyConnection=nil end end
    if noclipActive then task.wait(0.5); end
end)

local farmSection = Tabs.Farm:AddSection("Farm Mode")
local farmTeamParagraph = farmSection:AddParagraph({ Title = "Team", Content = "—" })
local farmStatusParagraph = farmSection:AddParagraph({ Title = "Status", Content = "Idle" })

farmSection:AddToggle("FarmCoinsToggle", {
    Title = "Enable Auto Collect Coins",
    Default = false,
    Callback = function(state)
        setAutoCoins(state)
        if state then
            farmStatusParagraph:SetDesc("Auto Coins: ON")
        else
            farmStatusParagraph:SetDesc("Auto Coins: OFF")
        end
    end
})

local farmActive = false
local farmToken = 0
local farmTeamConn = nil

local function updateFarmUI(team, status)
    if farmTeamParagraph then farmTeamParagraph:SetDesc(team or "—") end
    if farmStatusParagraph then farmStatusParagraph:SetDesc(status or "Idle") end
end

local function currentTeamName()
    return (LP.Team and LP.Team.Name) or "None"
end

local function applyFarmForTeam()
    local token = tick()
    farmToken = token
    local team = currentTeamName()
    if team == "Banana" or team == "Team Banana" then
        updateFarmUI(team, "Auto Kill ON")
        turnOffAllAutos()
        setAutoKill(true)
    elseif team == "Runners" or team == "Team Runners" then
        updateFarmUI(team, "Preparing sequence")
        turnOffAllAutos()
        setAutoEscapeMonitor(true)
        task.delay(3, function()
            if farmToken ~= token or currentTeamName() ~= team or not farmActive then return end
            local hrp = getHRP()
            if hrp then forceTP(CFrame.new(hrp.Position + Vector3.new(0,70,0))) end
            setNoclip(true)
            setFly(true)
            setAutoBarrel(true)
            updateFarmUI(team, "Fly+Noclip (+Barrel). Coins toggle separately.")
        end)
        task.delay(25, function()
            if farmToken ~= token or currentTeamName() ~= team or not farmActive then return end
            enterCombinationOnce()
            instantFinishValve(4)
            solvePicturePuzzleOnce()
            autoCakeOnce()
            updateFarmUI(team, "Puzzles+Cake executed")
        end)
    elseif team == "Lobby" or team == "Team Lobby" then
        turnOffAllAutos()
        updateFarmUI(team, "All autos OFF")
    else
        updateFarmUI(team, "Waiting")
    end
end

farmSection:AddToggle("FarmEnabled", {
    Title = "Enable Farm Mode",
    Default = false,
    Callback = function(state)
        farmActive = state
        if state then
            updateFarmUI(currentTeamName(), "Active")
            applyFarmForTeam()
            if farmTeamConn then farmTeamConn:Disconnect() end
            farmTeamConn = LP:GetPropertyChangedSignal("Team"):Connect(function()
                if farmActive then applyFarmForTeam() end
            end)
        else
            if farmTeamConn then farmTeamConn:Disconnect(); farmTeamConn=nil end
            farmToken = -1
            turnOffAllAutos()
            updateFarmUI(currentTeamName(), "Disabled")
        end
    end
})

Fluent:Notify({ Title="Banana Eats Script", Content="Loaded", Duration=4 })
Window:SelectTab(1)
startComboWatcher()
