-- Steal a Brainrot – Auto Lock (präziser 2s-Wait + 2s-Cooldown, Edge-Trigger, stabile UI)
-- RemainingTime: Workspace.Plots.<GUID>.Purchases.PlotBlock.Main.BillboardGui.RemainingTime
-- Hitbox:        Workspace.Plots.<GUID>.Purchases.PlotBlock.Hitbox

-- ==== CONFIG ====
local WAIT_BEFORE_TOUCH  = 2.00   -- exakt warten nach 0
local TOUCH_COOLDOWN     = 2.00   -- Sperre nach Touch
local REDETECT_EVERY     = 2.0
local POLL_EVERY         = 0.08   -- etwas schneller, um Rücksprünge sofort zu sehen

-- ==== SERVICES ====
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local UserInput  = game:GetService("UserInputService")
local LP         = Players.LocalPlayer

-- ==== UTILS ====
local function now() return os.clock() end
local function HRP()
    local c = LP.Character or LP.CharacterAdded:Wait()
    return c:FindFirstChild("HumanoidRootPart")
end
local function Hum()
    local c = LP.Character or LP.CharacterAdded:Wait()
    return c:FindFirstChildOfClass("Humanoid")
end
local function safeFind(root, path)
    local n = root
    for _,k in ipairs(path) do if not n then return nil end n = n:FindFirstChild(k) end
    return n
end
local function v3dist(a,b) return (a-b).Magnitude end

-- robustes Parsen: "41s", "00:41", "0", "Ready", leere Strings → Sekundenzahl
local function parseSecs(txt)
    txt = tostring(txt or ""):lower():gsub("%s+", "")
    if txt == "" then return math.huge end
    if txt:find("ready") then return 0 end
    if txt:sub(-1) == "s" then txt = txt:sub(1, -2) end
    local m,s = txt:match("^(%d+):(%d+)$")
    if m and s then return tonumber(m)*60 + tonumber(s) end
    local n = tonumber(txt)
    if n then return n end
    return math.huge
end

-- ==== PLOT/Targets ====
local currentPlot, remainingLabel, hitboxPart
local function plotsFolder() return Workspace:FindFirstChild("Plots") end
local function getRemainingLabel(plot)
    return safeFind(plot, {"Purchases","PlotBlock","Main","BillboardGui","RemainingTime"})
        or safeFind(plot, {"Purchases","PlotBlock","Main","RemainingTime"})
end
local function hasCore(plot)
    local hb = safeFind(plot, {"Purchases","PlotBlock","Hitbox"})
    local rem= getRemainingLabel(plot)
    return hb and hb:IsA("BasePart") and rem and rem:IsA("TextLabel")
end
local function isMyPlot(plot)
    if not plot then return false end
    for _,d in ipairs(plot:GetDescendants()) do
        if d:IsA("ObjectValue") and d.Value==LP then return true end
        if (d:IsA("IntValue") or d:IsA("NumberValue")) and tonumber(d.Value)==LP.UserId then return true end
        if d:IsA("StringValue") then local v=tostring(d.Value); if v==LP.Name or v==LP.DisplayName then return true end end
    end
    return false
end
local function autoDetectPlot()
    local pf,my = plotsFolder(), HRP(); if not (pf and my) then return nil end
    local best,bestD
    for _,pl in ipairs(pf:GetChildren()) do
        if hasCore(pl) and (isMyPlot(pl) or true) then
            local hb = safeFind(pl, {"Purchases","PlotBlock","Hitbox"})
            local d = v3dist(my.Position, hb.Position)
            if not best or d < bestD then best,bestD = pl,d end
        end
    end
    return best
end
local function resolveTargets()
    if (not currentPlot) or (not currentPlot.Parent) or (not hasCore(currentPlot)) then
        currentPlot = autoDetectPlot()
    end
    remainingLabel = currentPlot and getRemainingLabel(currentPlot) or nil
    hitboxPart     = currentPlot and safeFind(currentPlot, {"Purchases","PlotBlock","Hitbox"}) or nil
end

-- ==== TOUCH CORE ====
local function charParts()
    local c = LP.Character; if not c then return {} end
    local out = {}
    for _,d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") then table.insert(out, d) end
    end
    return out
end
local function tryFireTouchAll()
    if typeof(firetouchinterest) ~= "function" then return false end
    if not (hitboxPart and hitboxPart.Parent) then return false end
    local ok = false
    for _,bp in ipairs(charParts()) do
        pcall(function()
            firetouchinterest(bp, hitboxPart, 0)
            task.wait(0.02)
            firetouchinterest(bp, hitboxPart, 1)
            ok = true
        end)
    end
    return ok
end
local function tpInsideJitter(duration)
    duration = duration or 0.26
    local hrp = HRP(); if not (hrp and hitboxPart) then return end
    local orig = hrp.CFrame
    pcall(function()
        local h = Hum(); if h then h:ChangeState(Enum.HumanoidStateType.Physics) end
        local t0 = now()
        while now() - t0 < duration do
            hrp.CFrame = hitboxPart.CFrame + Vector3.new(0, 1.05, 0)
            RunService.RenderStepped:Wait()
            hrp.CFrame = hrp.CFrame * CFrame.new(0, 0.05, 0)
            RunService.RenderStepped:Wait()
        end
        hrp.CFrame = orig
    end)
end
local function doTouch()
    local fired = tryFireTouchAll()
    if not fired then tpInsideJitter(0.30) end
end

-- ==== STATE MACHINE ====
-- States: "IDLE" | "COUNTING" | "ARMED" | "COOLDOWN"
local state = "IDLE"
local lastSeconds = math.huge
local armAt, coolUntil = nil, nil
local lastDetect, lastPoll = 0, 0

local function onSeconds(secs)
    -- Sofort-Guards
    if secs == math.huge then return end
    local t = now()

    if state == "COOLDOWN" then
        if t >= (coolUntil or 0) then
            -- Cooldown vorbei → zurück in IDLE/COUNTING abhängig von Anzeige
            state = (secs > 0) and "COUNTING" or "IDLE"
            armAt, coolUntil = nil, nil
        end
        lastSeconds = secs
        return
    end

    if state == "ARMED" then
        -- Wenn die Anzeige wieder >0 springt (du hast schon manuell gelockt), ARMED abbrechen
        if secs > 0 then
            state = "COUNTING"
            armAt = nil
            lastSeconds = secs
            return
        end
        -- Warten bis armAt, dann touchen
        if t >= (armAt or 0) then
            doTouch()
            state = "COOLDOWN"
            coolUntil = t + TOUCH_COOLDOWN
            armAt = nil
        end
        lastSeconds = secs
        return
    end

    -- IDLE/COUNTING Logik mit echter Falling-Edge
    if secs > 0 then
        state = "COUNTING"
    elseif secs == 0 then
        -- Nur triggern, wenn wir zuvor >0 gesehen haben (echte Flanke)
        if lastSeconds > 0 then
            state = "ARMED"
            armAt = t + WAIT_BEFORE_TOUCH
        else
            -- wiederholtes 0, ignoriere (kein Re-Arm)
        end
    end

    lastSeconds = secs
end

-- ==== UI (kompakt) ====
local function gui()
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
    local SG = Instance.new("ScreenGui")
    SG.Name = "SAB_AutoLock_UI"; SG.ResetOnSpawn=false; SG.IgnoreGuiInset=true; SG.Parent=guiParent

    local Card = Instance.new("Frame")
    Card.Name="Card"; Card.Size=UDim2.new(0,320,0,120); Card.Position=UDim2.new(0,20,0.18,0)
    Card.BackgroundColor3=Color3.fromRGB(22,22,26); Card.BorderSizePixel=0; Card.Active=true; Card.Draggable=true; Card.Parent=SG
    Instance.new("UICorner", Card).CornerRadius=UDim.new(0,12)
    local stroke=Instance.new("UIStroke", Card); stroke.Color=Color3.fromRGB(70,70,80); stroke.Thickness=1

    local Title = Instance.new("TextLabel", Card)
    Title.Size=UDim2.new(1,-36,0,28); Title.Position=UDim2.new(0,12,0,8)
    Title.BackgroundTransparency=1; Title.Text="Steal a Brainrot – Auto Lock"; Title.Font=Enum.Font.GothamBold; Title.TextSize=14
    Title.TextXAlignment=Enum.TextXAlignment.Left; Title.TextColor3=Color3.fromRGB(230,230,240)

    local Close = Instance.new("TextButton", Card)
    Close.Size=UDim2.new(0,24,0,24); Close.Position=UDim2.new(1,-28,0,8)
    Close.Text="—"; Close.Font=Enum.Font.GothamBold; Close.TextSize=18
    Close.BackgroundColor3=Color3.fromRGB(38,38,44); Close.TextColor3=Color3.fromRGB(220,220,230); Close.BorderSizePixel=0
    Instance.new("UICorner", Close).CornerRadius=UDim.new(0,8)
    Close.MouseButton1Click:Connect(function() Card.Visible = not Card.Visible end)
    UserInput.InputBegan:Connect(function(i,gp) if gp then return end if i.KeyCode==Enum.KeyCode.RightControl then Card.Visible = not Card.Visible end end)

    local Status = Instance.new("TextLabel", Card)
    Status.Size=UDim2.new(1,-24,0,20); Status.Position=UDim2.new(0,12,0,40)
    Status.BackgroundTransparency=1; Status.Font=Enum.Font.Code; Status.TextSize=13
    Status.TextXAlignment=Enum.TextXAlignment.Left; Status.TextColor3=Color3.fromRGB(180,255,120)

    local Line2 = Instance.new("TextLabel", Card)
    Line2.Size=UDim2.new(1,-24,0,20); Line2.Position=UDim2.new(0,12,0,62)
    Line2.BackgroundTransparency=1; Line2.Font=Enum.Font.Code; Line2.TextSize=13
    Line2.TextXAlignment=Enum.TextXAlignment.Left; Line2.TextColor3=Color3.fromRGB(210,210,220)

    local Line3 = Instance.new("TextLabel", Card)
    Line3.Size=UDim2.new(1,-24,0,20); Line3.Position=UDim2.new(0,12,0,84)
    Line3.BackgroundTransparency=1; Line3.Font=Enum.Font.Code; Line3.TextSize=13
    Line3.TextXAlignment=Enum.TextXAlignment.Left; Line3.TextColor3=Color3.fromRGB(200,200,210)

    -- UI Updater
    RunService.RenderStepped:Connect(function()
        local plotName = currentPlot and currentPlot.Name or "(kein Plot)"
        local hbOk = (hitboxPart and hitboxPart.Parent) and "OK" or "FEHLT"
        Line2.Text = ("Plot: %s  |  Hitbox: %s"):format(plotName, hbOk)

        local rt = remainingLabel and remainingLabel.Text or "n/a"
        local t = now()
        local nextTxt = "—"
        if state == "ARMED"   then nextTxt = string.format("%.2fs", math.max(0, (armAt or t) - t)) end
        if state == "COOLDOWN"then nextTxt = string.format("%.2fs", math.max(0, (coolUntil or t) - t)) end
        Line3.Text = ("Remaining: %s  |  Next: %s"):format(rt or "n/a", nextTxt)

        if state == "ARMED" then
            Status.Text = "Auto: ON  |  ARMED (warte…)"
            Status.TextColor3 = Color3.fromRGB(255,220,120)
        elseif state == "COOLDOWN" then
            Status.Text = "Auto: ON  |  COOLDOWN"
            Status.TextColor3 = Color3.fromRGB(255,180,120)
        elseif state == "COUNTING" then
            Status.Text = "Auto: ON  |  Counting"
            Status.TextColor3 = Color3.fromRGB(180,255,120)
        else
            Status.Text = "Auto: ON  |  Ready"
            Status.TextColor3 = Color3.fromRGB(180,255,120)
        end
    end)
end

-- ==== BOOT ====
resolveTargets()
gui()

-- Event + Poll: beides, damit kein Frame verpasst wird
if remainingLabel then
    remainingLabel:GetPropertyChangedSignal("Text"):Connect(function()
        local secs = parseSecs(remainingLabel.Text)
        onSeconds(secs)
    end)
end

local lastDetectT, lastPollT = 0, 0
RunService.Heartbeat:Connect(function()
    local t = now()
    if t - lastDetectT >= REDETECT_EVERY then
        lastDetectT = t
        local oldPlot = currentPlot
        resolveTargets()
        if currentPlot ~= oldPlot and remainingLabel then
            remainingLabel:GetPropertyChangedSignal("Text"):Connect(function()
                local secs = parseSecs(remainingLabel.Text)
                onSeconds(secs)
            end)
        end
    end
    if t - lastPollT >= POLL_EVERY then
        lastPollT = t
        if remainingLabel and remainingLabel.Parent then
            onSeconds(parseSecs(remainingLabel.Text))
        end
    end
end)
