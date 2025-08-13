-- Blade Ball – Auto Parry (permanentes Tracking + Panic + Radius-Overlay)
-- Kein externes UI. Dragbares Mini-Panel. Toggle für Auto-Parry und "Show Radius".

-- ===== Konfig =====
local PARRY_KEY            = Enum.KeyCode.F
local TOGGLE_KEY           = Enum.KeyCode.G

local TRIGGER_DISTANCE     = 5.0       -- normaler Radius (Studs) – wird gezeichnet, wenn Overlay aktiv
local PANIC_RADIUS         = 2.2       -- „zu nah“ -> sofort parry
local PANIC_COOLDOWN       = 0.12

local MIN_APPROACH_SPEED   = 8         -- Studs/s – für Frühreaktion
local BASE_REACT_WINDOW    = 0.08
local EXTRA_PER_50S        = 0.06
local MAX_REACT_WINDOW     = 0.20
local NORMAL_COOLDOWN      = 0.25

local RESCAN_FALLBACK_EVERY= 0.5
-- ===================

local Players               = game:GetService("Players")
local RunService            = game:GetService("RunService")
local Workspace             = game:GetService("Workspace")
local UserInputService      = game:GetService("UserInputService")
local VirtualInputManager   = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local enabled, lastParry = true, 0
local showRadius = false

local BallsFolder = nil
local CandidateGroups = {}
local LastRescan = 0

local function HRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function dynWindow(vTo)
    local w = BASE_REACT_WINDOW + (vTo/50) * EXTRA_PER_50S
    if w < BASE_REACT_WINDOW then w = BASE_REACT_WINDOW end
    if w > MAX_REACT_WINDOW then w = MAX_REACT_WINDOW end
    return w
end

local function tapKey(k)
    VirtualInputManager:SendKeyEvent(true, k, false, game)
    VirtualInputManager:SendKeyEvent(false, k, false, game)
end

local function resolvePart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function vTowardsAndDist(part, myPos)
    local v = part.AssemblyLinearVelocity or Vector3.zero
    local toMe = (myPos - part.Position)
    local dist = toMe.Magnitude
    if dist <= 1e-6 then return 0, dist end
    local dir = toMe.Unit
    return v:Dot(dir), dist
end

local function clearGroups()
    for k in pairs(CandidateGroups) do CandidateGroups[k] = nil end
end

local function addToGroup(inst)
    if not inst or inst.Parent ~= BallsFolder then return end
    if not (inst:IsA("BasePart") or inst:IsA("Model")) then return end
    local key = inst.Name
    local list = CandidateGroups[key]
    if not list then list = {}; CandidateGroups[key] = list end
    table.insert(list, inst)
end

local function rebuildGroups()
    clearGroups()
    if not BallsFolder then return end
    for _,child in ipairs(BallsFolder:GetChildren()) do
        if child:IsA("BasePart") or child:IsA("Model") then
            addToGroup(child)
        end
    end
end

local function ensureBallsFolder()
    if BallsFolder and BallsFolder.Parent == Workspace then return end
    BallsFolder = Workspace:FindFirstChild("Balls") or Workspace:FindFirstChild("balls") or Workspace:FindFirstChild("BALLS")
    if BallsFolder then
        rebuildGroups()
        BallsFolder.ChildAdded:Connect(function(ch) addToGroup(ch) end)
        BallsFolder.ChildRemoved:Connect(function(_) rebuildGroups() end)
    end
end

local function pickRepresentative(list, myPos)
    local best, bestScore = nil, math.huge
    for _,obj in ipairs(list) do
        local p = resolvePart(obj)
        if p and p.Parent then
            local vTo, dist = vTowardsAndDist(p, myPos)
            local speed = (p.AssemblyLinearVelocity or Vector3.zero).Magnitude
            local score = (-vTo)*1e6 + (1/math.max(speed,1e-3))*1e3 + dist
            if score < bestScore then best = p; bestScore = score end
        end
    end
    return best
end

local function selectBestBallPart(myPos)
    local now = os.clock()
    if now - LastRescan >= RESCAN_FALLBACK_EVERY then
        LastRescan = now
        rebuildGroups()
    end
    local bestPart, bestScore = nil, math.huge
    for _,list in pairs(CandidateGroups) do
        if #list > 0 then
            local rep = pickRepresentative(list, myPos)
            if rep then
                local vTo, dist = vTowardsAndDist(rep, myPos)
                local tth = (vTo > 0) and (dist / vTo) or 9e9
                local score = tth*1000 + dist
                if score < bestScore then bestPart = rep; bestScore = score end
            end
        end
    end
    return bestPart
end

-- ===== Radius Overlay =====
local radiusAdornment = nil
local function setRadiusVisible(hrp, visible)
    if not visible then
        if radiusAdornment then radiusAdornment:Destroy(); radiusAdornment=nil end
        return
    end
    if not hrp then
        if radiusAdornment then radiusAdornment:Destroy(); radiusAdornment=nil end
        return
    end
    if not radiusAdornment then
        local s = Instance.new("SphereHandleAdornment")
        s.Name = "AutoParry_TriggerRadius"
        s.AlwaysOnTop = true
        s.ZIndex = 5
        s.Color3 = Color3.fromRGB(0, 255, 0)
        s.Transparency = 0.85
        s.Adornee = hrp
        s.Radius = TRIGGER_DISTANCE
        s.Parent = Workspace
        radiusAdornment = s
    else
        radiusAdornment.Adornee = hrp
        radiusAdornment.Radius  = TRIGGER_DISTANCE
    end
end

-- ===== Mini UI =====
local function mk(inst,props,parent) local o=Instance.new(inst) for k,v in pairs(props)do o[k]=v end o.Parent=parent return o end
local SG = mk("ScreenGui",{Name="BB_AutoParry_UI",IgnoreGuiInset=true,ResetOnSpawn=false},game:GetService("CoreGui"))
local Frame = mk("Frame",{Size=UDim2.new(0,320,0,128),Position=UDim2.new(0,20,0.18,0),BackgroundColor3=Color3.fromRGB(22,22,26),BorderSizePixel=0,Active=true,Draggable=true},SG)
mk("UICorner",{CornerRadius=UDim.new(0,10)},Frame)
mk("UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Color3.fromRGB(60,60,70),Thickness=1},Frame)
mk("TextLabel",{Size=UDim2.new(1,0,0,30),BackgroundColor3=Color3.fromRGB(30,30,36),BorderSizePixel=0,Text="Blade Ball – Auto Parry",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1)},Frame)

local Status = mk("TextLabel",{Position=UDim2.new(0,12,0,40),Size=UDim2.new(1,-140,0,22),BackgroundTransparency=1,Text="Status: ON  (Toggle: "..TOGGLE_KEY.Name..")",Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=Color3.fromRGB(120,255,140),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local RadiusLbl = mk("TextLabel",{Position=UDim2.new(0,12,0,64),Size=UDim2.new(1,-24,0,18),BackgroundTransparency=1,Text=("Trigger Radius: %.1f studs"):format(TRIGGER_DISTANCE),Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(190,190,200),TextXAlignment=Enum.TextXAlignment.Left},Frame)

local ToggleBtn = mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,38),Size=UDim2.new(0,84,0,26),BackgroundColor3=Color3.fromRGB(30,150,85),Text="ON",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame)
mk("UICorner",{CornerRadius=UDim.new(0,8)},ToggleBtn)

local RadiusBtn = mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,68),Size=UDim2.new(0,84,0,24),BackgroundColor3=Color3.fromRGB(90,90,95),Text="Radius OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame)
mk("UICorner",{CornerRadius=UDim.new(0,8)},RadiusBtn)

local function refreshUI()
    if enabled then
        ToggleBtn.Text="ON";  ToggleBtn.BackgroundColor3=Color3.fromRGB(30,150,85)
        Status.Text="Status: ON  (Toggle: "..TOGGLE_KEY.Name..")"; Status.TextColor3=Color3.fromRGB(120,255,140)
    else
        ToggleBtn.Text="OFF"; ToggleBtn.BackgroundColor3=Color3.fromRGB(90,90,95)
        Status.Text="Status: OFF (Toggle: "..TOGGLE_KEY.Name..")"; Status.TextColor3=Color3.fromRGB(255,140,140)
    end
    setRadiusVisible(HRP(), showRadius)
    if showRadius then
        RadiusBtn.Text = "Radius ON"
        RadiusBtn.BackgroundColor3 = Color3.fromRGB(30,120,70)
    else
        RadiusBtn.Text = "Radius OFF"
        RadiusBtn.BackgroundColor3 = Color3.fromRGB(90,90,95)
    end
end

ToggleBtn.MouseButton1Click:Connect(function() enabled = not enabled; refreshUI() end)
RadiusBtn.MouseButton1Click:Connect(function() showRadius = not showRadius; refreshUI() end)
UserInputService.InputBegan:Connect(function(i,gp) if gp then return end if i.UserInputType==Enum.UserInputType.Keyboard and i.KeyCode==TOGGLE_KEY then enabled=not enabled; refreshUI() end end)

refreshUI()

-- ===== Main Loop =====
ensureBallsFolder()
Workspace.ChildAdded:Connect(function(ch)
    if not BallsFolder and (ch.Name=="Balls" or ch.Name=="balls" or ch.Name=="BALLS") then
        ensureBallsFolder()
    end
end)

RunService.Heartbeat:Connect(function()
    if not enabled then return end
    ensureBallsFolder()
    if not BallsFolder then return end

    local hrp = HRP(); if not hrp then return end
    if showRadius then setRadiusVisible(hrp, true) end

    local myPos = hrp.Position
    local part = selectBestBallPart(myPos)
    if not part then return end

    local vTo, dist = vTowardsAndDist(part, myPos)
    local now = os.clock()

    -- Panic-Zone
    if dist <= PANIC_RADIUS then
        if now - lastParry >= PANIC_COOLDOWN then
            lastParry = now
            tapKey(PARRY_KEY)
        end
        return
    end

    -- Normaler Trigger – jetzt OHNE Speedlimit
    if dist <= TRIGGER_DISTANCE then
        if now - lastParry >= NORMAL_COOLDOWN then
            lastParry = now
            tapKey(PARRY_KEY)
        end
        return
    end

    -- Frühreaktion – nur bei hoher Geschwindigkeit
    if vTo > MIN_APPROACH_SPEED then
        local tth = dist / vTo
        if tth <= dynWindow(vTo) and (now - lastParry) >= NORMAL_COOLDOWN then
            lastParry = now
            tapKey(PARRY_KEY)
        end
    end
end)
