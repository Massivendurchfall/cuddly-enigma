-- Blade Ball – Auto Parry (tracking + sticky + smart timing + clash + overlay + inputs + auto/anti-curve)
-- Toggle: Enable, Show Radius, Show Debug, AutoCurve, AntiCurve
-- Inputs: Trigger Radius, Clash Radius, Curve Degrees, Curve Duration ms

----------------------- CONFIG DEFAULTS -----------------------
local PARRY_KEY              = Enum.KeyCode.F
local TOGGLE_KEY             = Enum.KeyCode.G

local TRIGGER_DISTANCE       = 5.0      -- per TextBox änderbar
local PANIC_RADIUS           = 2.2
local PANIC_COOLDOWN         = 0.12     -- s

-- Frühreaktion (außerhalb Trigger)
local MIN_APPROACH_SPEED     = 8        -- Studs/s
local BASE_REACT_WINDOW      = 0.08     -- s
local EXTRA_PER_50S          = 0.06     -- s / 50 Studs/s
local MAX_REACT_WINDOW       = 0.20     -- s

-- Im-Radius Timingfenster (Serverfenster kurz vor Impact)
local IN_RADIUS_MAX_TTH      = 0.21     -- s (spätestens)
local IN_RADIUS_MIN_TTH      = 0.03     -- s (frühestens; 0 = aus)

-- Fix für sehr langsame Bälle (Dwell)
local IN_RADIUS_DWELL        = 0.12     -- s im Radius => Parry

local NORMAL_COOLDOWN        = 0.25     -- s
local RESCAN_FALLBACK_EVERY  = 0.5      -- s

-- Clash (nahes 1v1 „spammen“)
local CLASH_AUTO             = true
local CLASH_NEAR_RADIUS      = 6.0      -- per TextBox änderbar
local CLASH_MIN_PERIOD       = 0.05     -- s
local CLASH_MAX_PERIOD       = 0.14     -- s
local CLASH_HARD_TIMEOUT     = 1.2      -- s

-- Curve / Anti-Curve (per TextBox änderbar)
local AUTOCURVE_ENABLED      = true     -- beim Parry in Richtung Gegner flicken
local ANTICURVE_ENABLED      = true     -- seitliche Anströmung erkennen & kontern
local CURVE_DEGREES          = 8        -- horizontale Gradzahl (klein halten, z.B. 6–12)
local CURVE_DURATION_MS      = 60       -- Dauer des Flicks in Millisekunden

----------------------------------------------------------------

local Players               = game:GetService("Players")
local RunService            = game:GetService("RunService")
local Workspace             = game:GetService("Workspace")
local UserInputService      = game:GetService("UserInputService")
local VirtualInputManager   = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local enabled, showRadius, showDebug = true, false, false
local lastParry = 0

-- tracking / caches
local BallsFolder, CandidateGroups = nil, {}
local LastRescan = 0
local trackedPart, insideStart = nil, nil

-- clash state
local clashActive, lastClashPress, clashStart = false, 0, 0

----------------------- HELPERS -----------------------
local function HRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tapKey(k)
    VirtualInputManager:SendKeyEvent(true, k, false, game)
    VirtualInputManager:SendKeyEvent(false, k, false, game)
end

-- kurzer Maus-Flick (horizontales Delta in Pixeln über Zeit)
local function mouseFlick(px, ms)
    -- Roblox VirtualInput: SendMouseMoveEvent(dx, dy)
    local steps = math.max(1, math.floor(ms / 16))
    local step = px / steps
    for i = 1, steps do
        VirtualInputManager:SendMouseMoveEvent(step, 0, false)
        RunService.RenderStepped:Wait()
    end
end

-- Grad -> Pixel grob schätzen (abhängig von FOV & Sensitivity; heuristisch)
-- wir halten die Werte klein, daher reicht ein fester Faktor
local function degreesToPixels(deg)
    return deg * 3.0  -- tweakbar; 3 px pro Grad ist konservativ
end

local function dynWindow(vTo)
    local w = BASE_REACT_WINDOW + (vTo/50)*EXTRA_PER_50S
    if w < BASE_REACT_WINDOW then w = BASE_REACT_WINDOW end
    if w > MAX_REACT_WINDOW then w = MAX_REACT_WINDOW end
    return w
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
    return v:Dot(dir), dist -- >0: nähert sich
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

----------------------- CANDIDATE MGMT -----------------------
local function clearGroups() for k in pairs(CandidateGroups) do CandidateGroups[k]=nil end end
local function addToGroup(inst)
    if not inst or inst.Parent ~= BallsFolder then return end
    if not (inst:IsA("BasePart") or inst:IsA("Model")) then return end
    local key = inst.Name
    local list = CandidateGroups[key] or {}
    CandidateGroups[key] = list
    table.insert(list, inst)
end
local function rebuildGroups()
    clearGroups()
    if not BallsFolder then return end
    for _,child in ipairs(BallsFolder:GetChildren()) do
        if child:IsA("BasePart") or child:IsA("Model") then addToGroup(child) end
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
    debugLabel = Instance.new("TextLabel"); debugLabel.Size=UDim2.new(0,500,0,22); debugLabel.Position=UDim2.new(0,20,0,4)
    debugLabel.BackgroundTransparency=0.4; debugLabel.BackgroundColor3=Color3.fromRGB(20,20,24)
    debugLabel.Font=Enum.Font.Code; debugLabel.TextSize=14; debugLabel.TextXAlignment=Enum.TextXAlignment.Left
    debugLabel.TextColor3=Color3.fromRGB(235,235,245); debugLabel.Parent=debugGui
end
local function setDebugText(text) if debugLabel then debugLabel.Text = text end end

----------------------- UI (Inputs statt Slider) -----------------------
local function mk(inst,props,parent) local o=Instance.new(inst) for k,v in pairs(props)do o[k]=v end o.Parent=parent return o end
local SG = mk("ScreenGui",{Name="BB_AutoParry_UI",IgnoreGuiInset=true,ResetOnSpawn=false},game:GetService("CoreGui"))
local Frame = mk("Frame",{Size=UDim2.new(0,420,0,260),Position=UDim2.new(0,20,0.18,0),BackgroundColor3=Color3.fromRGB(22,22,26),BorderSizePixel=0,Active=true,Draggable=true},SG)
mk("UICorner",{CornerRadius=UDim.new(0,10)},Frame)
mk("UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Color3.fromRGB(60,60,70),Thickness=1},Frame)
mk("TextLabel",{Size=UDim2.new(1,0,0,30),BackgroundColor3=Color3.fromRGB(30,30,36),BorderSizePixel=0,Text="Blade Ball – Auto Parry",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1)},Frame)

local Status = mk("TextLabel",{Position=UDim2.new(0,12,0,40),Size=UDim2.new(1,-160,0,22),BackgroundTransparency=1,Text="Status: ON (Toggle: "..TOGGLE_KEY.Name..")",Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=Color3.fromRGB(120,255,140),TextXAlignment=Enum.TextXAlignment.Left},Frame)

local ToggleBtn  = mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,38),Size=UDim2.new(0,84,0,26),BackgroundColor3=Color3.fromRGB(30,150,85),Text="ON",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,8)},ToggleBtn)
local RadiusBtn  = mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,68),Size=UDim2.new(0,84,0,24),BackgroundColor3=Color3.fromRGB(90,90,95),Text="Radius OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,8)},RadiusBtn)
local DebugBtn   = mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,98),Size=UDim2.new(0,84,0,24),BackgroundColor3=Color3.fromRGB(90,90,95),Text="Debug OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,8)},DebugBtn)

-- Zeile: Trigger Radius (TextBox)
local TRLbl = mk("TextLabel",{Position=UDim2.new(0,12,0,128),Size=UDim2.new(0,150,0,22),BackgroundTransparency=1,Text="Trigger Radius",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local TRBox = mk("TextBox",{Position=UDim2.new(0,160,0,128),Size=UDim2.new(0,80,0,22),Text=tostring(TRIGGER_DISTANCE),BackgroundColor3=Color3.fromRGB(32,32,38),BorderSizePixel=0,Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.fromRGB(235,235,245),ClearTextOnFocus=false},Frame)
mk("UICorner",{CornerRadius=UDim.new(0,6)},TRBox)

-- Zeile: Clash Radius (TextBox)
local CRLbl = mk("TextLabel",{Position=UDim2.new(0,12,0,156),Size=UDim2.new(0,150,0,22),BackgroundTransparency=1,Text="Clash Radius",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local CRBox = mk("TextBox",{Position=UDim2.new(0,160,0,156),Size=UDim2.new(0,80,0,22),Text=tostring(CLASH_NEAR_RADIUS),BackgroundColor3=Color3.fromRGB(32,32,38),BorderSizePixel=0,Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.fromRGB(235,235,245),ClearTextOnFocus=false},Frame)
mk("UICorner",{CornerRadius=UDim.new(0,6)},CRBox)
local ClashToggle = mk("TextButton",{Position=UDim2.new(0,250,0,156),Size=UDim2.new(0,90,0,22),BackgroundColor3=Color3.fromRGB(30,120,70),Text=CLASH_AUTO and "Clash ON" or "Clash OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},ClashToggle)

-- Zeile: AutoCurve / AntiCurve + Params
local ACLbl = mk("TextLabel",{Position=UDim2.new(0,12,0,184),Size=UDim2.new(0,150,0,22),BackgroundTransparency=1,Text="AutoCurve / AntiCurve",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local ACToggle = mk("TextButton",{Position=UDim2.new(0,160,0,184),Size=UDim2.new(0,76,0,22),BackgroundColor3=AUTOCURVE_ENABLED and Color3.fromRGB(30,120,70) or Color3.fromRGB(90,90,95),Text=AUTOCURVE_ENABLED and "Auto ON" or "Auto OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},ACToggle)
local ANTToggle = mk("TextButton",{Position=UDim2.new(0,240,0,184),Size=UDim2.new(0,76,0,22),BackgroundColor3=ANTICURVE_ENABLED and Color3.fromRGB(30,120,70) or Color3.fromRGB(90,90,95),Text=ANTICURVE_ENABLED and "Anti ON" or "Anti OFF",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},ANTToggle)

local CGLbl = mk("TextLabel",{Position=UDim2.new(0,12,0,212),Size=UDim2.new(0,80,0,22),BackgroundTransparency=1,Text="Curve°",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local CGBox = mk("TextBox",{Position=UDim2.new(0,92,0,212),Size=UDim2.new(0,60,0,22),Text=tostring(CURVE_DEGREES),BackgroundColor3=Color3.fromRGB(32,32,38),BorderSizePixel=0,Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.fromRGB(235,235,245),ClearTextOnFocus=false},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},CGBox)
local CDL = mk("TextLabel",{Position=UDim2.new(0,160,0,212),Size=UDim2.new(0,90,0,22),BackgroundTransparency=1,Text="Curve ms",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(200,200,210),TextXAlignment=Enum.TextXAlignment.Left},Frame)
local CDB = mk("TextBox",{Position=UDim2.new(0,246,0,212),Size=UDim2.new(0,60,0,22),Text=tostring(CURVE_DURATION_MS),BackgroundColor3=Color3.fromRGB(32,32,38),BorderSizePixel=0,Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.fromRGB(235,235,245),ClearTextOnFocus=false},Frame); mk("UICorner",{CornerRadius=UDim.new(0,6)},CDB)

-- Eingaben validieren/übernehmen
local function toNum(s, minv, maxv, def)
    local n = tonumber(s)
    if not n then return def end
    if minv then n = math.max(minv, n) end
    if maxv then n = math.min(maxv, n) end
    return n
end

local function applyTR()
    TRIGGER_DISTANCE = toNum(TRBox.Text, 0.5, 20, TRIGGER_DISTANCE)
    TRBox.Text = tostring(TRIGGER_DISTANCE)
    setRadiusVisible(HRP(), showRadius)
end
local function applyCR()
    CLASH_NEAR_RADIUS = toNum(CRBox.Text, 1.5, 20, CLASH_NEAR_RADIUS)
    CRBox.Text = tostring(CLASH_NEAR_RADIUS)
end
local function applyCurveParams()
    CURVE_DEGREES = toNum(CGBox.Text, 1, 30, CURVE_DEGREES)
    CURVE_DURATION_MS = math.floor(toNum(CDB.Text, 10, 200, CURVE_DURATION_MS))
    CGBox.Text = tostring(CURVE_DEGREES)
    CDB.Text   = tostring(CURVE_DURATION_MS)
end

TRBox.FocusLost:Connect(applyTR)
CRBox.FocusLost:Connect(applyCR)
CGBox.FocusLost:Connect(applyCurveParams)
CDB.FocusLost:Connect(applyCurveParams)

ToggleBtn.MouseButton1Click:Connect(function() enabled=not enabled; ToggleBtn.Text=enabled and "ON" or "OFF"; ToggleBtn.BackgroundColor3=enabled and Color3.fromRGB(30,150,85) or Color3.fromRGB(90,90,95); Status.Text = "Status: "..(enabled and "ON" or "OFF").." (Toggle: "..TOGGLE_KEY.Name..")"; Status.TextColor3 = enabled and Color3.fromRGB(120,255,140) or Color3.fromRGB(255,140,140) end)
RadiusBtn.MouseButton1Click:Connect(function() showRadius=not showRadius; RadiusBtn.Text=showRadius and "Radius ON" or "Radius OFF"; RadiusBtn.BackgroundColor3=showRadius and Color3.fromRGB(30,120,70) or Color3.fromRGB(90,90,95); setRadiusVisible(HRP(), showRadius) end)
DebugBtn.MouseButton1Click:Connect(function() showDebug=not showDebug; DebugBtn.Text=showDebug and "Debug ON" or "Debug OFF"; DebugBtn.BackgroundColor3=showDebug and Color3.fromRGB(120,90,30) or Color3.fromRGB(90,90,95); setDebugVisible(showDebug) end)
ClashToggle.MouseButton1Click:Connect(function() CLASH_AUTO=not CLASH_AUTO; ClashToggle.Text=CLASH_AUTO and "Clash ON" or "Clash OFF"; ClashToggle.BackgroundColor3=CLASH_AUTO and Color3.fromRGB(30,120,70) or Color3.fromRGB(90,90,95) end)
ACToggle.MouseButton1Click:Connect(function() AUTOCURVE_ENABLED=not AUTOCURVE_ENABLED; ACToggle.Text=AUTOCURVE_ENABLED and "Auto ON" or "Auto OFF"; ACToggle.BackgroundColor3=AUTOCURVE_ENABLED and Color3.fromRGB(30,120,70) or Color3.fromRGB(90,90,95) end)
ANTToggle.MouseButton1Click:Connect(function() ANTICURVE_ENABLED=not ANTICURVE_ENABLED; ANTToggle.Text=ANTICURVE_ENABLED and "Anti ON" or "Anti OFF"; ANTToggle.BackgroundColor3=ANTICURVE_ENABLED and Color3.fromRGB(30,120,70) or Color3.fromRGB(90,90,95) end)
UserInputService.InputBegan:Connect(function(i,gp) if gp then return end if i.UserInputType==Enum.UserInputType.Keyboard and i.KeyCode==TOGGLE_KEY then enabled=not enabled; ToggleBtn.Text=enabled and "ON" or "OFF"; ToggleBtn.BackgroundColor3=enabled and Color3.fromRGB(30,150,85) or Color3.fromRGB(90,90,95); Status.Text="Status: "..(enabled and "ON" or "OFF").." (Toggle: "..TOGGLE_KEY.Name..")"; Status.TextColor3=enabled and Color3.fromRGB(120,255,140) or Color3.fromRGB(255,140,140) end end)

----------------------- CLASH UTILS -----------------------
local function clashPeriod(dist, vTo)
    local tth = (vTo > 0) and (dist / vTo) or 0.25
    return math.clamp(tth * 0.5, CLASH_MIN_PERIOD, CLASH_MAX_PERIOD)
end

-- Richtung für Curve-Flick bestimmen:
-- AntiCurve hat Vorrang: seitliche Komponente der Ball-Relativbewegung kontern.
-- Sonst AutoCurve Richtung nächster Gegner (links/rechts relativ zu Blickrichtung).
local function curveDirectionSign(myCF, myPos, ballPart, vTo)
    -- AntiCurve?
    if ANTICURVE_ENABLED and ballPart then
        local v = ballPart.AssemblyLinearVelocity or Vector3.zero
        local toMe = (myPos - ballPart.Position)
        local dir = toMe.Magnitude > 1e-6 and toMe.Unit or myCF.LookVector
        local lateral = v - dir * v:Dot(dir)  -- seitliche Komponente
        local side = lateral:Dot(myCF.RightVector) -- >0 = kommt von rechts
        if math.abs(side) > 0.5 then
            return side > 0 and -1 or 1   -- entgegenwirken
        end
    end
    -- AutoCurve?
    if AUTOCURVE_ENABLED then
        local enemy = nearestEnemy(myPos)
        if enemy and enemy.Character and enemy.Character:FindFirstChild("HumanoidRootPart") then
            local rel = enemy.Character.HumanoidRootPart.Position - myPos
            local side = rel:Dot(myCF.RightVector)
            return side >= 0 and 1 or -1  -- Richtung Gegner
        end
    end
    return 0
end

local function doParryWithCurve(myCF, myPos, ballPart, vTo)
    tapKey(PARRY_KEY)
    local sign = curveDirectionSign(myCF, myPos, ballPart, vTo)
    if sign ~= 0 then
        local px = degreesToPixels(CURVE_DEGREES) * sign
        mouseFlick(px, CURVE_DURATION_MS)
    end
end

----------------------- MAIN -----------------------
ensureBallsFolder()
Workspace.ChildAdded:Connect(function(ch)
    if not BallsFolder and (ch.Name=="Balls" or ch.Name=="balls" or ch.Name=="BALLS") then ensureBallsFolder() end
end)

RunService.Heartbeat:Connect(function()
    if not enabled then return end
    ensureBallsFolder(); if not BallsFolder then return end

    local hrp = HRP(); if not hrp then return end
    if showRadius then setRadiusVisible(hrp, true) end

    local now  = os.clock()
    local myPos = hrp.Position
    local myCF  = hrp.CFrame

    -- sticky target
    if (not trackedPart) or (not trackedPart.Parent) then
        trackedPart = selectBestBallPart(myPos); insideStart=nil; clashActive=false
        if not trackedPart then return end
    else
        local candidate = selectBestBallPart(myPos)
        if candidate and candidate ~= trackedPart then
            local vToOld, distOld = vTowardsAndDist(trackedPart, myPos)
            local vToNew, distNew = vTowardsAndDist(candidate,   myPos)
            local tthOld = (vToOld > 0) and (distOld / vToOld) or 9e9
            local tthNew = (vToNew > 0) and (distNew / vToNew) or 9e9
            if (distNew + 0.25) < distOld or (tthNew + 0.03) < tthOld then
                trackedPart = candidate; insideStart=nil; clashActive=false
            end
        end
    end

    local vTo, dist = vTowardsAndDist(trackedPart, myPos)
    local _, enemyDist = nearestEnemy(myPos)
    local shouldClash = CLASH_AUTO and (enemyDist <= CLASH_NEAR_RADIUS) and (dist <= TRIGGER_DISTANCE + 1.5)

    -- Debug
    if showDebug then
        local tth = (vTo > 0) and dist/vTo or -1
        local dwell = insideStart and (now - insideStart) or 0
        local cd = math.max(0, NORMAL_COOLDOWN - (now - lastParry))
        setDebugText(string.format("dist %.2f | v→ %.2f | tth %.3f | dwell %.3f | cd %.2f | enemyDist %.2f",
            dist, vTo, tth, dwell, cd, enemyDist))
    end

    -- 1) PANIC
    if dist <= PANIC_RADIUS then
        if now - lastParry >= PANIC_COOLDOWN then
            lastParry = now
            doParryWithCurve(myCF, myPos, trackedPart, vTo)
            insideStart = nil
        end
        return
    end

    -- 2) IM TRIGGER-RADIUS: TTH-Fenster ODER Dwell
    if dist <= TRIGGER_DISTANCE then
        if not insideStart then insideStart = now end
        local okWindow = false
        if vTo > 0 then
            local tth = dist / vTo
            okWindow = (tth <= IN_RADIUS_MAX_TTH) and ((IN_RADIUS_MIN_TTH <= 0) or (tth >= IN_RADIUS_MIN_TTH))
        end
        local okDwell = (now - insideStart) >= IN_RADIUS_DWELL

        if (okWindow or okDwell) and (now - lastParry) >= NORMAL_COOLDOWN then
            lastParry = now
            doParryWithCurve(myCF, myPos, trackedPart, vTo)
            insideStart = nil
            -- Clash-Phase anschieben
            clashActive = shouldClash; clashStart = now; lastClashPress = now
        else
            if shouldClash then
                if not clashActive then clashActive=true; clashStart=now; lastClashPress=0 end
            else
                clashActive=false
            end
        end

        if clashActive and (now - clashStart) <= CLASH_HARD_TIMEOUT then
            local period = clashPeriod(dist, math.max(vTo, 0.01))
            if (now - lastClashPress) >= period then
                lastClashPress = now
                doParryWithCurve(myCF, myPos, trackedPart, vTo)
            end
        else
            clashActive = false
        end
        return
    else
        insideStart=nil; clashActive=false
    end

    -- 3) AUSSERHALB: Frühreaktion (sehr schnelle Bälle)
    if vTo > MIN_APPROACH_SPEED then
        local tth = dist / vTo
        if tth <= dynWindow(vTo) and (now - lastParry) >= NORMAL_COOLDOWN then
            lastParry = now
            doParryWithCurve(myCF, myPos, trackedPart, vTo)
            insideStart = nil
        end
    end
end)
