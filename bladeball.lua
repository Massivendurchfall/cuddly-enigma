
----------------------- CONFIG -----------------------
local PARRY_KEY               = Enum.KeyCode.F
local TOGGLE_KEY              = Enum.KeyCode.G

-- Geometrie
local TRIGGER_DISTANCE        = 5.0       -- per UI änderbar
local INNER_DWELL_FRACTION    = 0.85      -- Dwell erst, wenn dist <= 85% von TRIGGER_DISTANCE
local PANIC_RADIUS            = 2.6       -- ↑ breiter für ultra-slow
local PANIC_COOLDOWN          = 0.12

-- „Außerhalb“-Frühreaktion
local MIN_APPROACH_SPEED      = 8         -- Studs/s
local BASE_REACT_WINDOW       = 0.08
local EXTRA_PER_50S           = 0.06
local MAX_REACT_WINDOW        = 0.20

-- „Im-Radius“: dynamisches TTH-Zeitfenster
local IN_TTH_MIN              = 0.03
local IN_TTH_BASE             = 0.18
local IN_TTH_EXTRA_SLOW       = 0.16
local IN_TTH_MIN_CAP          = 0.16
local IN_TTH_MAX_CAP          = 0.34

-- Dwell
local IN_RADIUS_DWELL         = 0.12      -- normaler Dwell
local MAX_DWELL_TIMEOUT       = 0.38      -- HARTE Obergrenze: so lange im Kreis? -> parry

-- Cooldowns / Korrektur
local NORMAL_COOLDOWN         = 0.25
local CORRECTIVE_TTH          = 0.08      -- tth <= 80ms -> Korrektur-Press erlaubt
local CORRECTIVE_COOLDOWN_FR  = 0.60      -- 60% Cooldown reichen für Korrektur

-- Clash
local CLASH_AUTO              = true
local CLASH_NEAR_RADIUS       = 6.0
local CLASH_MIN_PERIOD        = 0.05
local CLASH_MAX_PERIOD        = 0.14
local CLASH_HARD_TIMEOUT      = 1.2

-- Curve / Anti-Curve
local AUTOCURVE_ENABLED       = true
local ANTICURVE_ENABLED       = true
local CURVE_DEGREES           = 8
local CURVE_DURATION_MS       = 60

-- Ping-Kompensation
local PING_COMP_MIN           = 0.010
local PING_COMP_MAX           = 0.090
local PING_SAMPLE_EVERY       = 0.50

-- Filter (EMA) für v→
local VTO_EMA_ALPHA           = 0.35

-- Rescan
local RESCAN_FALLBACK_EVERY   = 0.5

-- Slow-Guards
local EDGE_FACTOR             = 1.15      -- Edge-Crossing: 1.15 * PANIC_RADIUS
local MIN_VTO_FOR_EDGE        = 0.15      -- minimaler v→ damit „annähern“ zählt

----------------------- SERVICES & STATE -----------------------
local Players               = game:GetService("Players")
local RunService            = game:GetService("RunService")
local Workspace             = game:GetService("Workspace")
local UserInputService      = game:GetService("UserInputService")
local VirtualInputManager   = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local enabled, showRadius, showDebug = true, false, false

local lastParry       = 0
local lastPingRead    = 0
local pingHalf        = 0.04

local BallsFolder, CandidateGroups = nil, {}
local LastRescan     = 0
local trackedPart    = nil
local insideStart    = nil

-- clash
local clashActive, lastClashPress, clashStart = false, 0, 0

-- speed filter
local vToFiltered    = nil

-- edge-crossing
local lastDist       = nil

----------------------- UTILS -----------------------
local function HRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- VirtualInput wrappers
local function sendKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function sendMouseMove(dx, dy)
    local ok = pcall(function()
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        VirtualInputManager:SendMouseMoveEvent(dx, dy, pg or game:GetService("CoreGui"))
    end)
    if not ok then
        pcall(function() VirtualInputManager:SendMouseMoveEvent(dx, dy, false) end)
    end
end

local function mouseFlick(px, ms)
    local steps = math.max(1, math.floor(ms / 16))
    local step = px / steps
    for _ = 1, steps do
        sendMouseMove(step, 0)
        RunService.RenderStepped:Wait()
    end
end

local function degreesToPixels(deg) return deg * 3.0 end

local function dynReactWindow(vTo)
    local w = BASE_REACT_WINDOW + (vTo/50)*EXTRA_PER_50S
    if w < BASE_REACT_WINDOW then w = BASE_REACT_WINDOW end
    if w > MAX_REACT_WINDOW  then w = MAX_REACT_WINDOW  end
    return w
end

local function dynInRadiusMaxTTH(vTo)
    local spd = math.max(0, vTo)
    local slowFactor = 1 - math.clamp(spd/50, 0, 1)
    local t = IN_TTH_BASE + IN_TTH_EXTRA_SLOW * slowFactor
    return math.clamp(t, IN_TTH_MIN_CAP, IN_TTH_MAX_CAP)
end

local function resolvePart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then return obj:FindFirstChildWhichIsA("BasePart", true) end
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

local function nearestEnemy(myPos)
    local best, who = math.huge, nil
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local d = (plr.Character.HumanoidRootPart.Position - myPos).Magnitude
            if d < best then best = d; who = plr end
        end
    end
    return who, best
end

----------------------- CANDIDATES -----------------------
local function clearGroups() for k in pairs(CandidateGroups) do CandidateGroups[k] = nil end end

local function addToGroup(inst)
    if not inst or not inst.Parent then return end
    if not (inst:IsA("BasePart") or inst:IsA("Model")) then return end
    local key = inst.Name
    CandidateGroups[key] = CandidateGroups[key] or {}
    table.insert(CandidateGroups[key], inst)
end

local function rebuildGroups()
    clearGroups()
    if BallsFolder then
        for _,child in ipairs(BallsFolder:GetChildren()) do
            if child:IsA("BasePart") or child:IsA("Model") then addToGroup(child) end
        end
        return
    end
    for _,desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("BasePart") then
            local n = string.lower(desc.Name or "")
            local isBallName = string.find(n, "ball") ~= nil
            local vmag = (desc.AssemblyLinearVelocity or Vector3.zero).Magnitude
            local size = (desc.Size and desc.Size.Magnitude) or 0
            if (isBallName and vmag > 0.5 and size <= 25) then addToGroup(desc) end
        elseif desc:IsA("Model") then
            local n = string.lower(desc.Name or "")
            if string.find(n, "ball") ~= nil then addToGroup(desc) end
        end
    end
end

local function ensureBallsFolder()
    if BallsFolder and BallsFolder.Parent == Workspace then return end
    BallsFolder = Workspace:FindFirstChild("Balls")
              or Workspace:FindFirstChild("balls")
              or Workspace:FindFirstChild("BALLS")
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
            local spd = (p.AssemblyLinearVelocity or Vector3.zero).Magnitude
            local score = (vTo > 0 and (dist / vTo) or 9e9)*1000 + dist + (1/math.max(spd,1e-3))*500
            if score < bestScore then best = p; bestScore = score end
        end
    end
    return best
end

local function selectBestBallPart(myPos)
    local now = os.clock()
    if now - LastRescan >= RESCAN_FALLBACK_EVERY then LastRescan = now; rebuildGroups() end
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

----------------------- OVERLAYS -----------------------
local radiusAdornment = nil
local function setRadiusVisible(hrp, visible)
    if not visible then if radiusAdornment then radiusAdornment:Destroy() radiusAdornment=nil end return end
    if not hrp then if radiusAdornment then radiusAdornment:Destroy() radiusAdornment=nil end return end
    if not radiusAdornment then
        local s = Instance.new("SphereHandleAdornment")
        s.Name = "AutoParry_TriggerRadius"; s.AlwaysOnTop=true; s.ZIndex=5
        s.Color3 = Color3.fromRGB(0,255,0); s.Transparency=0.85
        s.Adornee = hrp; s.Radius = TRIGGER_DISTANCE; s.Parent = Workspace
        radiusAdornment = s
    else
        radiusAdornment.Adornee = hrp; radiusAdornment.Radius = TRIGGER_DISTANCE
    end
end

-- Debug HUD
local debugGui, debugLabel
local function setDebugVisible(visible)
    if not visible then if debugGui then debugGui:Destroy() debugGui=nil debugLabel=nil end return end
    if debugGui then return end
    debugGui = Instance.new("ScreenGui"); debugGui.Name="BB_AutoParry_Debug"; debugGui.ResetOnSpawn=false; debugGui.Parent=game:GetService("CoreGui")
    debugLabel = Instance.new("TextLabel"); debugLabel.Size=UDim2.new(0,880,0,22); debugLabel.Position=UDim2.new(0,20,0,4)
    debugLabel.BackgroundTransparency=0.4; debugLabel.BackgroundColor3=Color3.fromRGB(20,20,24)
    debugLabel.Font=Enum.Font.Code; debugLabel.TextSize=14; debugLabel.TextXAlignment=Enum.TextXAlignment.Left
    debugLabel.TextColor3=Color3.fromRGB(235,235,245); debugLabel.Parent=debugGui
end
local function setDebugText(text) if debugLabel then debugLabel.Text = text end end

----------------------- UI -----------------------
local function mk(inst,props,parent) local o=Instance.new(inst) for k,v in pairs(props)do o[k]=v end o.Parent=parent return o end
local SG = mk("ScreenGui",{Name="BB_AutoParry_UI",IgnoreGuiInset=true,ResetOnSpawn=false},game:GetService("CoreGui"))
local Frame = mk("Frame",{Size=UDim2.new(0,420,0,260),Position=UDim2.new(0,20,0.18,0),BackgroundColor3=Color3.fromRGB(22,22,26),BorderSizePixel=0,Active=true,Draggable=true},SG)
mk("UICorner",{CornerRadius=UDim.new(0,10)},Frame)
mk("UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Color3.fromRGB(60,60,70),Thickness=1},Frame)
mk("TextLabel",{Size=UDim2.new(1,0,0,30),BackgroundColor3=Color3.fromRGB(30,30,36),BorderSizePixel=0,Text="Blade Ball – Auto Parry v2.1",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1)},Frame)

local Status = mk("TextLabel",{Position=UDim2.new(0,12,0,40),Size=UDim2.new(1,-160,0,22),BackgroundTransparency=1,Text="Status: ON (Toggle: "..TOGGLE_KEY.Name..")",Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=Color3.fromRGB(120,255,140),TextXAlignment=Enum.TextXAlignment.Left},Frame)

local ToggleBtn  = mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,38),Size=UDim2.new(0,84,0,26),BackgroundColor3=Color3.fromRGB(30,150,85),Text="ON",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,8)},ToggleBtn)
local RadiusBtn  = mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,68),Size=UDim2.new(0,84,0,24),BackgroundColor3=Color3.fromRGB(90,90,95),Text="Radius OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,8)},RadiusBtn)
local DebugBtn   = mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,98),Size=UDim2.new(0,84,0,24),BackgroundColor3=Color3.fromRGB(90,90,95),Text="Debug OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,8)},DebugBtn)

-- Trigger Radius
local TRLbl = mk("TextLabel",{Position=UDim2.new(0,12,0,128),Size=UDim2.new(0,150,0,22),BackgroundTransparency=1,Text="Trigger Radius",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local TRBox = mk("TextBox",{Position=UDim2.new(0,160,0,128),Size=UDim2.new(0,80,0,22),Text=tostring(TRIGGER_DISTANCE),BackgroundColor3=Color3.fromRGB(32,32,38),BorderSizePixel=0,Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.fromRGB(235,235,245),ClearTextOnFocus=false},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},TRBox)

-- Clash Radius
local CRLbl = mk("TextLabel",{Position=UDim2.new(0,12,0,156),Size=UDim2.new(0,150,0,22),BackgroundTransparency=1,Text="Clash Radius",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local CRBox = mk("TextBox",{Position=UDim2.new(0,160,0,156),Size=UDim2.new(0,80,0,22),Text=tostring(CLASH_NEAR_RADIUS),BackgroundColor3=Color3.fromRGB(32,32,38),BorderSizePixel=0,Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.fromRGB(235,235,245),ClearTextOnFocus=false},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},CRBox)

-- AutoCurve/AntiCurve
local ACLbl = mk("TextLabel",{Position=UDim2.new(0,12,0,184),Size=UDim2.new(0,150,0,22),BackgroundTransparency=1,Text="AutoCurve / AntiCurve",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local ACToggle = mk("TextButton",{Position=UDim2.new(0,160,0,184),Size=UDim2.new(0,76,0,22),BackgroundColor3=AUTOCURVE_ENABLED and Color3.fromRGB(30,120,70) or Color3.fromRGB(90,90,95),Text=AUTOCURVE_ENABLED and "Auto ON" or "Auto OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},ACToggle)
local ANTToggle = mk("TextButton",{Position=UDim2.new(0,240,0,184),Size=UDim2.new(0,76,0,22),BackgroundColor3=ANTICURVE_ENABLED and Color3.fromRGB(30,120,70) or Color3.fromRGB(90,90,95),Text=ANTICURVE_ENABLED and "Anti ON" or "Anti OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},ANTToggle)

-- Curve params
local CGLbl = mk("TextLabel",{Position=UDim2.new(0,12,0,212),Size=UDim2.new(0,80,0,22),BackgroundTransparency=1,Text="Curve°",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local CGBox = mk("TextBox",{Position=UDim2.new(0,92,0,212),Size=UDim2.new(0,60,0,22),Text=tostring(CURVE_DEGREES),BackgroundColor3=Color3.fromRGB(32,32,38),BorderSizePixel=0,Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.fromRGB(235,235,245),ClearTextOnFocus=false},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},CGBox)
local CDL  = mk("TextLabel",{Position=UDim2.new(0,160,0,212),Size=UDim2.new(0,90,0,22),BackgroundTransparency=1,Text="Curve ms",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local CDB  = mk("TextBox",{Position=UDim2.new(0,246,0,212),Size=UDim2.new(0,60,0,22),Text=tostring(CURVE_DURATION_MS),BackgroundColor3=Color3.fromRGB(32,32,38),BorderSizePixel=0,Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.fromRGB(235,235,245),ClearTextOnFocus=false},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},CDB)

-- Eingaben übernehmen
local function toNum(s, minv, maxv, def)
    local n = tonumber(s); if not n then return def end
    if minv then n = math.max(minv, n) end
    if maxv then n = math.min(maxv, n) end
    return n
end
local function applyTR() TRIGGER_DISTANCE = toNum(TRBox.Text, 0.5, 20, TRIGGER_DISTANCE); TRBox.Text=tostring(TRIGGER_DISTANCE); setRadiusVisible(HRP(), showRadius) end
local function applyCR() CLASH_NEAR_RADIUS = toNum(CRBox.Text, 1.5, 20, CLASH_NEAR_RADIUS); CRBox.Text=tostring(CLASH_NEAR_RADIUS) end
local function applyCurve()
    CURVE_DEGREES = toNum(CGBox.Text, 1, 30, CURVE_DEGREES)
    CURVE_DURATION_MS = math.floor(toNum(CDB.Text, 10, 200, CURVE_DURATION_MS))
    CGBox.Text=tostring(CURVE_DEGREES); CDB.Text=tostring(CURVE_DURATION_MS)
end
TRBox.FocusLost:Connect(applyTR); CRBox.FocusLost:Connect(applyCR); CGBox.FocusLost:Connect(applyCurve); CDB.FocusLost:Connect(applyCurve)

ToggleBtn.MouseButton1Click:Connect(function() enabled=not enabled; ToggleBtn.Text=enabled and "ON" or "OFF"; ToggleBtn.BackgroundColor3=enabled and Color3.fromRGB(30,150,85) or Color3.fromRGB(90,90,95); Status.Text = "Status: "..(enabled and "ON" or "OFF").." (Toggle: "..TOGGLE_KEY.Name..")"; Status.TextColor3 = enabled and Color3.fromRGB(120,255,140) or Color3.fromRGB(255,140,140) end)
RadiusBtn.MouseButton1Click:Connect(function() showRadius=not showRadius; RadiusBtn.Text=showRadius and "Radius ON" or "Radius OFF"; RadiusBtn.BackgroundColor3=showRadius and Color3.fromRGB(30,120,70) or Color3.fromRGB(90,90,95); setRadiusVisible(HRP(), showRadius) end)
DebugBtn.MouseButton1Click:Connect(function() showDebug=not showDebug; DebugBtn.Text=showDebug and "Debug ON" or "Debug OFF"; DebugBtn.BackgroundColor3=showDebug and Color3.fromRGB(120,90,30) or Color3.fromRGB(90,90,95); setDebugVisible(showDebug) end)

UserInputService.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.UserInputType==Enum.UserInputType.Keyboard and i.KeyCode==TOGGLE_KEY then
        enabled=not enabled
        ToggleBtn.Text=enabled and "ON" or "OFF"
        ToggleBtn.BackgroundColor3=enabled and Color3.fromRGB(30,150,85) or Color3.fromRGB(90,90,95)
        Status.Text="Status: "..(enabled and "ON" or "OFF").." (Toggle: "..TOGGLE_KEY.Name..")"
        Status.TextColor3=enabled and Color3.fromRGB(120,255,140) or Color3.fromRGB(255,140,140)
    end
end)

----------------------- CLASH / CURVE -----------------------
local function clashPeriod(dist, vTo)
    local tth = (vTo > 0) and (dist / vTo) or 0.25
    return math.clamp(tth * 0.5, CLASH_MIN_PERIOD, CLASH_MAX_PERIOD)
end

local function curveDirectionSign(myCF, myPos, ballPart, vTo)
    if ANTICURVE_ENABLED and ballPart then
        local v = ballPart.AssemblyLinearVelocity or Vector3.zero
        local toMe = (myPos - ballPart.Position)
        local dir = toMe.Magnitude > 1e-6 and toMe.Unit or myCF.LookVector
        local lateral = v - dir * v:Dot(dir)
        local side = lateral:Dot(myCF.RightVector)
        if math.abs(side) > 0.5 then
            return side > 0 and -1 or 1
        end
    end
    if AUTOCURVE_ENABLED then
        local enemy = nearestEnemy(myPos)
        if enemy and enemy.Character and enemy.Character:FindFirstChild("HumanoidRootPart") then
            local rel = enemy.Character.HumanoidRootPart.Position - myPos
            local side = rel:Dot(myCF.RightVector)
            return side >= 0 and 1 or -1
        end
    end
    return 0
end

local function doParryWithCurve(myCF, myPos, ballPart, vTo)
    sendKey(PARRY_KEY)
    local sign = curveDirectionSign(myCF, myPos, ballPart, vTo)
    if sign ~= 0 then
        local px = degreesToPixels(CURVE_DEGREES) * sign
        mouseFlick(px, CURVE_DURATION_MS)
    end
end

----------------------- CORE HELPERS -----------------------
local function canPress(now, tth)
    if (now - lastParry) >= NORMAL_COOLDOWN then return true end
    if tth and tth >= 0 and tth <= CORRECTIVE_TTH then
        if (now - lastParry) >= (NORMAL_COOLDOWN * CORRECTIVE_COOLDOWN_FR) then return true end
    end
    return false
end

local function updatePing(now)
    if now - lastPingRead >= PING_SAMPLE_EVERY then
        lastPingRead = now
        local p = 0
        pcall(function() p = LP:GetNetworkPing() end)
        p = tonumber(p) or 0
        pingHalf = math.clamp(p * 0.5, PING_COMP_MIN, PING_COMP_MAX)
    end
end

local function ema(current, new, alpha)
    if not current then return new end
    return current*(1-alpha) + new*alpha
end

----------------------- MAIN -----------------------
local function debugLine(dist, vEff, tth, dwell, cd, enemyDist, dynMax)
    if not showDebug then return end
    setDebugText(string.format(
        "dist %.2f | v→ %.2f | tth %.3f | dwell %.3f | cd %.2f | enemyDist %.2f | maxTTH %.3f | ping½ %.0fms",
        dist, vEff or 0, (tth or -1), dwell or 0, cd or 0, enemyDist or -1, dynMax or 0, pingHalf*1000
    ))
end

local function tryParry(now, myCF, myPos, ballPart, vEff, tth)
    if canPress(now, tth) then
        lastParry = now
        doParryWithCurve(myCF, myPos, ballPart, vEff)
        insideStart = nil
        return true
    end
    return false
end

local function step()
    if not enabled then return end
    ensureBallsFolder(); if not BallsFolder and (os.clock() - LastRescan) > RESCAN_FALLBACK_EVERY then rebuildGroups() end

    local hrp = HRP(); if not hrp then return end
    if showRadius then setRadiusVisible(hrp, true) end

    local now   = os.clock()
    local myPos = hrp.Position
    local myCF  = hrp.CFrame

    updatePing(now)

    if (not trackedPart) or (not trackedPart.Parent) then
        trackedPart = selectBestBallPart(myPos); insideStart=nil; clashActive=false; vToFiltered=nil; lastDist=nil
        if not trackedPart then return end
    else
        local candidate = selectBestBallPart(myPos)
        if candidate and candidate ~= trackedPart then
            trackedPart = candidate; insideStart=nil; clashActive=false; vToFiltered=nil; lastDist=nil
        end
    end

    local vTo, dist = vTowardsAndDist(trackedPart, myPos)
    vToFiltered = ema(vToFiltered, vTo, VTO_EMA_ALPHA)
    local vEff = math.max(vToFiltered or vTo, 0)

    local _, enemyDist = nearestEnemy(myPos)
    local shouldClash = CLASH_AUTO and (enemyDist <= CLASH_NEAR_RADIUS) and (dist <= TRIGGER_DISTANCE + 1.5)

    local dwell  = insideStart and (now - insideStart) or 0
    local cd     = math.max(0, NORMAL_COOLDOWN - (now - lastParry))
    local dynMax = dynInRadiusMaxTTH(vEff)
    local tth    = (vEff > 0) and ((dist / vEff) - pingHalf) or nil

    -- Debug
    debugLine(dist, vEff, tth, dwell, cd, enemyDist, dynMax)

    -- 0) Edge-Crossing-Trigger (für ultra-slow)
    local edge = EDGE_FACTOR * PANIC_RADIUS
    if lastDist and dist <= edge and lastDist > edge and vEff >= MIN_VTO_FOR_EDGE then
        if tryParry(now, myCF, myPos, trackedPart, vEff, 0.05) then
            clashActive = shouldClash; clashStart = now; lastClashPress = now
            lastDist = dist
            return
        end
    end
    lastDist = dist

    -- 1) PANIC
    if dist <= PANIC_RADIUS then
        if now - lastParry >= PANIC_COOLDOWN then
            lastParry = now
            doParryWithCurve(myCF, myPos, trackedPart, vEff)
            insideStart = nil
        end
        return
    end

    -- 2) IM TRIGGER-RADIUS
    if dist <= TRIGGER_DISTANCE then
        if not insideStart then insideStart = now end

        local okWindow = false
        if tth and tth >= 0 then
            okWindow = (tth <= dynMax) and ((IN_TTH_MIN <= 0) or (tth >= IN_TTH_MIN))
        end
        local okDwellInner = (dwell >= IN_RADIUS_DWELL) and (dist <= (TRIGGER_DISTANCE * INNER_DWELL_FRACTION))
        local okDwellMax   = (dwell >= MAX_DWELL_TIMEOUT) -- Harter Fallback

        if (okWindow or okDwellInner or okDwellMax) and tryParry(now, myCF, myPos, trackedPart, vEff, tth or 0.05) then
            clashActive = shouldClash; clashStart = now; lastClashPress = now
        else
            if shouldClash then
                if not clashActive then clashActive=true; clashStart=now; lastClashPress=0 end
            else
                clashActive=false
            end
        end

        if clashActive and (now - clashStart) <= CLASH_HARD_TIMEOUT then
            local period = clashPeriod(dist, math.max(vEff, 0.01))
            if (now - lastClashPress) >= period then
                lastClashPress = now
                doParryWithCurve(myCF, myPos, trackedPart, vEff)
            end
        else
            clashActive = false
        end
        return
    else
        insideStart=nil; clashActive=false
    end

    -- 3) AUSSERHALB: Frühreaktion
    if vEff > MIN_APPROACH_SPEED then
        local tthOut = (dist / vEff) - pingHalf
        if tthOut <= dynReactWindow(vEff) and (now - lastParry) >= NORMAL_COOLDOWN then
            lastParry = now
            doParryWithCurve(myCF, myPos, trackedPart, vEff)
            insideStart = nil
        end
    end
end

ensureBallsFolder()
Workspace.ChildAdded:Connect(function(ch)
    if not BallsFolder and (ch.Name=="Balls" or ch.Name=="balls" or ch.Name=="BALLS") then ensureBallsFolder() end
end)

RunService.Heartbeat:Connect(step)
