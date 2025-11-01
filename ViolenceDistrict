local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer

local function alive(i)
    if not i then return false end
    local ok = pcall(function() return i.Parent end)
    return ok and i.Parent ~= nil
end
local function validPart(p) return p and alive(p) and p:IsA("BasePart") end
local function clamp(n,lo,hi) if n<lo then return lo elseif n>hi then return hi else return n end end
local function now() return os.clock() end
local function dist(a,b) return (a-b).Magnitude end

local function firstBasePart(inst)
    if not alive(inst) then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst.PrimaryPart and inst.PrimaryPart:IsA("BasePart") and alive(inst.PrimaryPart) then return inst.PrimaryPart end
        local p = inst:FindFirstChildWhichIsA("BasePart", true)
        if validPart(p) then return p end
    end
    if inst:IsA("Tool") then
        local h = inst:FindFirstChild("Handle") or inst:FindFirstChildWhichIsA("BasePart")
        if validPart(h) then return h end
    end
    return nil
end

local function makeBillboard(text, color3)
    local g = Instance.new("BillboardGui")
    g.Name = "VD_Tag"
    g.AlwaysOnTop = true
    g.Size = UDim2.new(0, 200, 0, 36)
    g.StudsOffset = Vector3.new(0, 3, 0)
    local l = Instance.new("TextLabel")
    l.Name = "Label"
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 1, 0)
    l.Font = Enum.Font.GothamBold
    l.Text = text
    l.TextSize = 14
    l.TextColor3 = color3 or Color3.new(1,1,1)
    l.TextStrokeTransparency = 0
    l.TextStrokeColor3 = Color3.new(0,0,0)
    l.Parent = g
    return g
end

local function ensureBoxESP(part, name, color)
    if not validPart(part) then return end
    local a = part:FindFirstChild(name)
    if not a then
        local ok, obj = pcall(function()
            local b = Instance.new("BoxHandleAdornment")
            b.Name = name
            b.Adornee = part
            b.ZIndex = 10
            b.AlwaysOnTop = true
            b.Transparency = 0.5
            b.Size = part.Size + Vector3.new(0.2,0.2,0.2)
            b.Color3 = color
            b.Parent = part
            return b
        end)
        if ok then a = obj end
    else
        a.Color3 = color
        a.Size = part.Size + Vector3.new(0.2,0.2,0.2)
    end
end

local function clearChild(o, n)
    if o and alive(o) then
        local c = o:FindFirstChild(n)
        if c then pcall(function() c:Destroy() end) end
    end
end

local function ensureHighlight(model, fill)
    if not (model and model:IsA("Model") and alive(model)) then return end
    local hl = model:FindFirstChild("VD_HL")
    if not hl then
        local ok, obj = pcall(function()
            local h = Instance.new("Highlight")
            h.Name = "VD_HL"
            h.Adornee = model
            h.FillTransparency = 0.5
            h.OutlineTransparency = 0
            h.Parent = model
            return h
        end)
        if ok then hl = obj else return end
    end
    hl.FillColor = fill
    hl.OutlineColor = fill
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

local function clearHighlight(model)
    if model and model:FindFirstChild("VD_HL") then
        pcall(function() model.VD_HL:Destroy() end)
    end
end

local Window   = Rayfield:CreateWindow({Name="Violence District",LoadingTitle="Violence District",LoadingSubtitle="by jlcfg",ConfigurationSaving={Enabled=true,FolderName="VD_Suite",FileName="vd_config"},KeySystem=false})
local TabPlayer= Window:CreateTab("Player")
local TabESP   = Window:CreateTab("ESP")
local TabWorld = Window:CreateTab("World")
local TabVisual= Window:CreateTab("Visual")
local TabMisc  = Window:CreateTab("Misc")

local function getRole(p)
    local tn = p.Team and p.Team.Name and p.Team.Name:lower() or ""
    if tn:find("killer") then return "Killer" end
    if tn:find("survivor") then return "Survivor" end
    return "Survivor"
end

local killerTypeName = "Killer"
local killerColors = {
    Jason = Color3.fromRGB(255, 60, 60),
    Stalker = Color3.fromRGB(255, 120, 60),
    Masked = Color3.fromRGB(255, 160, 60),
    Hidden = Color3.fromRGB(255, 60, 160),
    Abysswalker = Color3.fromRGB(120, 60, 255),
    Killer = Color3.fromRGB(255, 0, 0),
}
local function currentKillerColor()
    return killerColors[killerTypeName] or killerColors.Killer
end

local knownKillers = {Jason=true, Stalker=true, Masked=true, Hidden=true, Abysswalker=true}
do
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    if r then
        local k = r:FindFirstChild("Killers")
        if k then
            for _,ch in ipairs(k:GetChildren()) do
                if ch:IsA("Folder") then knownKillers[ch.Name] = true end
            end
        end
    end
end

local function refreshKillerESPLabels()
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP and getRole(pl)=="Killer" then
            if pl.Character then
                local head = pl.Character:FindFirstChild("Head")
                if head then
                    local tag = head:FindFirstChild("VD_Tag")
                    if tag then
                        local l = tag:FindFirstChild("Label")
                        if l then l.Text = pl.Name.." ["..tostring(killerTypeName).."]" end
                    end
                end
            end
        end
    end
end

local function setKillerType(name)
    if name and knownKillers[name] and killerTypeName ~= name then
        killerTypeName = name
        refreshKillerESPLabels()
    end
end

local survivorColor = Color3.fromRGB(0,255,0)
local killerBaseColor = killerColors.Killer
local nametagsEnabled, playerESPEnabled = false, false
local playerConns = {}

local function applyPlayerESP(p)
    if p == LP then return end
    local c = p.Character
    if not (c and alive(c)) then return end
    local col = (getRole(p)=="Killer") and currentKillerColor() or survivorColor

    if playerESPEnabled then
        if c:IsDescendantOf(Workspace) then ensureHighlight(c, col) end
        local head = c:FindFirstChild("Head")
        if nametagsEnabled and validPart(head) then
            local tag = head:FindFirstChild("VD_Tag") or makeBillboard(p.Name, col)
            tag.Name = "VD_Tag"
            tag.Parent = head
            local l = tag:FindFirstChild("Label")
            if l then
                if getRole(p)=="Killer" then l.Text = p.Name.." ["..tostring(killerTypeName).."]" else l.Text = p.Name end
                l.TextColor3 = col
            end
        else
            local t = head and head:FindFirstChild("VD_Tag")
            if t then pcall(function() t:Destroy() end) end
        end
    else
        clearHighlight(c)
        local head = c:FindFirstChild("Head")
        local t = head and head:FindFirstChild("VD_Tag")
        if t then pcall(function() t:Destroy() end) end
    end
end

local function watchPlayer(p)
    if playerConns[p] then for _,cn in ipairs(playerConns[p]) do cn:Disconnect() end end
    playerConns[p] = {}
    table.insert(playerConns[p], p.CharacterAdded:Connect(function()
        task.delay(0.15, function() applyPlayerESP(p) end)
    end))
    table.insert(playerConns[p], p:GetPropertyChangedSignal("Team"):Connect(function() applyPlayerESP(p) end))
    if p.Character then applyPlayerESP(p) end
end
local function unwatchPlayer(p)
    if p.Character then
        clearHighlight(p.Character)
        local head = p.Character:FindFirstChild("Head")
        if head and head:FindFirstChild("VD_Tag") then pcall(function() head.VD_Tag:Destroy() end) end
    end
    if playerConns[p] then for _,cn in ipairs(playerConns[p]) do cn:Disconnect() end end
    playerConns[p] = nil
end

TabESP:CreateSection("Players")
TabESP:CreateToggle({Name="Player ESP (Chams)",CurrentValue=false,Flag="PlayerESP",Callback=function(s) playerESPEnabled=s for _,pl in ipairs(Players:GetPlayers()) do if pl~=LP then applyPlayerESP(pl) end end end})
TabESP:CreateToggle({Name="Nametags",CurrentValue=false,Flag="Nametags",Callback=function(s) nametagsEnabled=s for _,pl in ipairs(Players:GetPlayers()) do if pl~=LP then applyPlayerESP(pl) end end end})
TabESP:CreateColorPicker({Name="Survivor Color",Color=survivorColor,Flag="SurvivorCol",Callback=function(c) survivorColor=c for _,pl in ipairs(Players:GetPlayers()) do if pl~=LP then applyPlayerESP(pl) end end end})
TabESP:CreateColorPicker({Name="Killer Color",Color=killerBaseColor,Flag="KillerCol",Callback=function(c) killerBaseColor=c killerColors.Killer=c for _,pl in ipairs(Players:GetPlayers()) do if pl~=LP then applyPlayerESP(pl) end end end})

for _,p in ipairs(Players:GetPlayers()) do if p~=LP then watchPlayer(p) end end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(unwatchPlayer)

local worldColors = {
    Generator = Color3.fromRGB(0,170,255),
    Hook = Color3.fromRGB(255,0,0),
    Gate = Color3.fromRGB(255,225,0),
    Window = Color3.fromRGB(255,255,255),
    Palletwrong = Color3.fromRGB(255,140,0),
    Pumpkin = Color3.fromRGB(255,165,0)
}
local worldEnabled = {Generator=false,Hook=false,Gate=false,Window=false,Palletwrong=false,Pumpkin=false}
local validCats = {Generator=true,Hook=true,Gate=true,Window=true,Palletwrong=true,Pumpkin=true}
local worldReg = {Generator={},Hook={},Gate={},Window={},Palletwrong={},Pumpkin={}}
local mapAdd, mapRem = {}, {}

local palletState = setmetatable({}, {__mode="k"})
local windowState = setmetatable({}, {__mode="k"})
local function labelForPallet(model)
    local st=palletState[model] or "UP"
    if st=="DOWN" then return "Pallet (down)" end
    if st=="DEST" then return "Pallet (destroyed)" end
    if st=="SLIDE" then return "Pallet (slide)" end
    return "Pallet"
end
local function labelForWindow(model)
    local st=windowState[model] or "READY"
    return st=="BUSY" and "Window (busy)" or "Window"
end

local function pickRep(model, cat)
    if not (model and alive(model)) then return nil end
    if cat == "Generator" then
        local hb = model:FindFirstChild("HitBox", true)
        if validPart(hb) then return hb end
    elseif cat == "Palletwrong" then
        local a = model:FindFirstChild("HumanoidRootPart", true); if validPart(a) then return a end
        local b = model:FindFirstChild("PrimaryPartPallet", true); if validPart(b) then return b end
        local c = model:FindFirstChild("Primary1", true); if validPart(c) then return c end
        local d = model:FindFirstChild("Primary2", true); if validPart(d) then return d end
    elseif cat == "Pumpkin" then
        local p = model:FindFirstChildWhichIsA("BasePart", true)
        if validPart(p) then return p end
    end
    return firstBasePart(model)
end

local function genLabelData(model)
    local pct = tonumber(model:GetAttribute("RepairProgress")) or 0
    if pct>=0 and pct<=1.001 then pct = pct*100 end
    pct = clamp(pct,0,100)
    local repairers = tonumber(model:GetAttribute("PlayersRepairingCount")) or 0
    local paused = (model:GetAttribute("ProgressPaused")==true)
    local kickcount = tonumber(model:GetAttribute("kickcount")) or 0
    local abyss50 = (model:GetAttribute("Abyss50Triggered")==true)
    local parts = {"Gen "..tostring(math.floor(pct+0.5)).."%" }
    if repairers>0 then parts[#parts+1]="("..repairers.."p)" end
    if paused then parts[#parts+1]="⏸" end
    if abyss50 then parts[#parts+1]="⚠" end
    if kickcount and kickcount>0 then parts[#parts+1]="K:"..kickcount end
    local text = table.concat(parts," ")
    local hue = clamp((pct/100)*0.33,0,0.33)
    local labelColor = Color3.fromHSV(hue,1,1)
    return text, labelColor
end

local function hasAnyBasePart(m)
    if not (m and alive(m)) then return false end
    local bp = m:FindFirstChildWhichIsA("BasePart", true)
    return bp ~= nil
end

local function isPalletGone(m)
    if not alive(m) then return true end
    if not m:IsDescendantOf(Workspace) then return true end
    if palletState[m]=="DEST" then return true end
    local ok, val = pcall(function() return m:GetAttribute("Destroyed") end)
    if ok and val == true then return true end
    if not hasAnyBasePart(m) then return true end
    return false
end

local function ensureWorldEntry(cat, model)
    if not alive(model) or worldReg[cat][model] then return end
    if cat=="Palletwrong" and isPalletGone(model) then return end
    local rep = pickRep(model, cat)
    if not validPart(rep) then return end
    worldReg[cat][model] = {part = rep}
end
local function removeWorldEntry(cat, model)
    local e = worldReg[cat][model]
    if not e then return end
    clearChild(e.part, "VD_"..cat)
    clearChild(e.part, "VD_Text_"..cat)
    worldReg[cat][model] = nil
end

local function isPumpkinModelName(n)
    if not n then return false end
    return string.find(n, "^Pumpkin%d*$") ~= nil
end

local function registerFromDescendant(obj)
    if not alive(obj) then return end
    if obj:IsA("Model") then
        if validCats[obj.Name] then
            ensureWorldEntry(obj.Name, obj)
            return
        end
        if isPumpkinModelName(obj.Name) then
            ensureWorldEntry("Pumpkin", obj)
            return
        end
    end
    if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
        if validCats[obj.Parent.Name] then
            ensureWorldEntry(obj.Parent.Name, obj.Parent)
            return
        end
        if isPumpkinModelName(obj.Parent.Name) then
            ensureWorldEntry("Pumpkin", obj.Parent)
            return
        end
    end
end
local function unregisterFromDescendant(obj)
    if not obj then return end
    if obj:IsA("Model") then
        if validCats[obj.Name] then
            removeWorldEntry(obj.Name, obj)
            return
        end
        if isPumpkinModelName(obj.Name) then
            removeWorldEntry("Pumpkin", obj)
            return
        end
    end
    if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
        if validCats[obj.Parent.Name] then
            local e = worldReg[obj.Parent.Name][obj.Parent]
            if e and e.part == obj then removeWorldEntry(obj.Parent.Name, obj.Parent) end
            return
        end
        if isPumpkinModelName(obj.Parent.Name) then
            local e = worldReg.Pumpkin[obj.Parent]
            if e and e.part == obj then removeWorldEntry("Pumpkin", obj.Parent) end
            return
        end
    end
end
local function attachRoot(root)
    if not root or mapAdd[root] then return end
    mapAdd[root] = root.DescendantAdded:Connect(registerFromDescendant)
    mapRem[root] = root.DescendantRemoving:Connect(unregisterFromDescendant)
    for _,d in ipairs(root:GetDescendants()) do registerFromDescendant(d) end
end
local function refreshRoots()
    for _,cn in pairs(mapAdd) do if cn then cn:Disconnect() end end
    for _,cn in pairs(mapRem) do if cn then cn:Disconnect() end end
    mapAdd, mapRem = {}, {}
    local r1 = Workspace:FindFirstChild("Map")
    local r2 = Workspace:FindFirstChild("Map1")
    if r1 then attachRoot(r1) end
    if r2 then attachRoot(r2) end
end
refreshRoots()
Workspace.ChildAdded:Connect(function(ch) if ch.Name=="Map" or ch.Name=="Map1" then attachRoot(ch) end end)

local worldLoopThread=nil
local function anyWorldEnabled() for _,v in pairs(worldEnabled) do if v then return true end end return false end
local function startWorldLoop()
    if worldLoopThread then return end
    worldLoopThread = task.spawn(function()
        while anyWorldEnabled() do
            for cat,models in pairs(worldReg) do
                if worldEnabled[cat] then
                    local col, tagName, textName = worldColors[cat], "VD_"..cat, "VD_Text_"..cat
                    local n = 0
                    for model,entry in pairs(models) do
                        if cat=="Palletwrong" and isPalletGone(model) then
                            removeWorldEntry(cat, model)
                        else
                            local part = entry.part
                            if model and alive(model) then
                                if not validPart(part) or (model:IsA("Model") and not part:IsDescendantOf(model)) then
                                    entry.part = pickRep(model, cat); part = entry.part
                                end
                                if validPart(part) then
                                    ensureBoxESP(part, tagName, col)
                                    local bb = part:FindFirstChild(textName)
                                    if not bb then
                                        local newbb = makeBillboard((cat=="Palletwrong" and "Pallet") or cat, col)
                                        newbb.Name = textName
                                        newbb.Parent = part
                                        bb = newbb
                                    end
                                    local lbl = bb:FindFirstChild("Label")
                                    if lbl then
                                        if cat=="Generator" then local txt,lblCol=genLabelData(model) lbl.Text=txt lbl.TextColor3=lblCol
                                        elseif cat=="Palletwrong" then lbl.Text=labelForPallet(model) lbl.TextColor3=col
                                        elseif cat=="Window" then lbl.Text=labelForWindow(model) lbl.TextColor3=col
                                        elseif cat=="Pumpkin" then lbl.Text="Pumpkin" lbl.TextColor3=col
                                        else lbl.Text=cat lbl.TextColor3=col end
                                    end
                                end
                            else
                                removeWorldEntry(cat, model)
                            end
                        end
                        n = n + 1
                        if n % 60 == 0 then task.wait() end
                    end
                end
            end
            task.wait(0.25)
        end
        worldLoopThread=nil
    end)
end
local function setWorldToggle(cat, state)
    worldEnabled[cat] = state
    if state then
        if not worldLoopThread then startWorldLoop() end
    else
        for _,entry in pairs(worldReg[cat]) do
            if entry and entry.part then
                clearChild(entry.part,"VD_"..cat); clearChild(entry.part,"VD_Text_"..cat)
            end
        end
    end
end

TabWorld:CreateSection("Toggles")
TabWorld:CreateToggle({Name="Generators",CurrentValue=false,Flag="Gen",Callback=function(s) setWorldToggle("Generator", s) end})
TabWorld:CreateToggle({Name="Hooks",CurrentValue=false,Flag="Hook",Callback=function(s) setWorldToggle("Hook", s) end})
TabWorld:CreateToggle({Name="Gates",CurrentValue=false,Flag="Gate",Callback=function(s) setWorldToggle("Gate", s) end})
TabWorld:CreateToggle({Name="Windows (Usability)",CurrentValue=false,Flag="Window",Callback=function(s) setWorldToggle("Window", s) end})
TabWorld:CreateToggle({Name="Pallets (Usability)",CurrentValue=false,Flag="Pallet",Callback=function(s) setWorldToggle("Palletwrong", s) end})
TabWorld:CreateToggle({Name="Pumpkins",CurrentValue=false,Flag="Pumpkin",Callback=function(s) setWorldToggle("Pumpkin", s) end})
TabWorld:CreateSection("Colors")
TabWorld:CreateColorPicker({Name="Generators",Color=worldColors.Generator,Flag="GenCol",Callback=function(c) worldColors.Generator=c end})
TabWorld:CreateColorPicker({Name="Hooks",Color=worldColors.Hook,Flag="HookCol",Callback=function(c) worldColors.Hook=c end})
TabWorld:CreateColorPicker({Name="Gates",Color=worldColors.Gate,Flag="GateCol",Callback=function(c) worldColors.Gate=c end})
TabWorld:CreateColorPicker({Name="Windows",Color=worldColors.Window,Flag="WinCol",Callback=function(c) worldColors.Window=c end})
TabWorld:CreateColorPicker({Name="Pallets",Color=worldColors.Palletwrong,Flag="PalCol",Callback=function(c) worldColors.Palletwrong=c end})
TabWorld:CreateColorPicker({Name="Pumpkins",Color=worldColors.Pumpkin,Flag="PumpCol",Callback=function(c) worldColors.Pumpkin=c end})

local initLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ExposureCompensation = Lighting.ExposureCompensation,
    ShadowSoftness = Lighting:FindFirstChild("ShadowSoftness") and Lighting.ShadowSoftness or nil,
    EnvironmentDiffuseScale = Lighting:FindFirstChild("EnvironmentDiffuseScale") and Lighting.EnvironmentDiffuseScale or nil,
    EnvironmentSpecularScale = Lighting:FindFirstChild("EnvironmentSpecularScale") and Lighting.EnvironmentSpecularScale or nil,
    Technology = Lighting.Technology
}
local fullbrightEnabled = false
local fbLoop
local desiredClockTime = Lighting.ClockTime
local timeLockActive = false
local function bindTimeLock()
    if timeLockActive then return end
    timeLockActive = true
    RunService:BindToRenderStep("VD_TimeLock", 299, function()
        if Lighting.ClockTime ~= desiredClockTime then Lighting.ClockTime = desiredClockTime end
    end)
end

TabVisual:CreateSection("Lighting")
TabVisual:CreateToggle({
    Name="Fullbright", CurrentValue=false, Flag="Fullbright",
    Callback=function(s)
        fullbrightEnabled = s
        if fbLoop then task.cancel(fbLoop) fbLoop=nil end
        if s then
            fbLoop = task.spawn(function()
                while fullbrightEnabled do
                    Lighting.Brightness = 2
                    Lighting.ClockTime = 14
                    Lighting.FogStart = 0
                    Lighting.FogEnd = 1e9
                    Lighting.GlobalShadows = false
                    Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
                    Lighting.ExposureCompensation = 0
                    task.wait(0.5)
                end
            end)
        else
            for k,v in pairs(initLighting) do pcall(function() if v~=nil then Lighting[k]=v end end) end
            desiredClockTime = Lighting.ClockTime
        end
    end
})
TabVisual:CreateSlider({Name="Time Of Day",Range={0,24},Increment=1,CurrentValue=Lighting.ClockTime,Flag="TimeOfDay",Callback=function(v) desiredClockTime=v Lighting.ClockTime=v bindTimeLock() end})

local nfActive=false
local nfStore={lighting={},inst=setmetatable({},{__mode="k"}),conns={},tick=nil}
local nfNameTokens={"smoke","mist","fog","haze","smog","steam","cloud","lake"}
local nfStrictNames={["Smoke"]=true,["LakeMist"]=true,["Chromatic Water Fog"]=true,["Cursed Energy Smoke"]=true,["Firm Smoke"]=true,["Foggy Wind"]=true}
local nfQueue, nfQueued, nfProcessed = {}, setmetatable({}, {__mode="k"}), setmetatable({}, {__mode="k"})

local function nfSave(inst, props)
    if not inst then return end
    nfStore.inst[inst] = nfStore.inst[inst] or {}
    for _,p in ipairs(props) do
        if nfStore.inst[inst][p]==nil then
            local ok,v=pcall(function() return inst[p] end)
            if ok then nfStore.inst[inst][p]=v end
        end
    end
end
local function nfRestoreAll()
    for inst,props in pairs(nfStore.inst) do
        if inst and alive(inst) then
            for k,v in pairs(props) do pcall(function() inst[k]=v end) end
        end
    end
    nfStore.inst=setmetatable({},{__mode="k"})
    if nfStore.lighting then for k,v in pairs(nfStore.lighting) do pcall(function() Lighting[k]=v end) end end
    for _,c in ipairs(nfStore.conns) do pcall(function() c:Disconnect() end) end
    nfStore.conns={}
    if nfStore.tick then nfStore.tick:Disconnect() nfStore.tick=nil end
end
local function nfMatchesName(n)
    local s=string.lower(n or "")
    if nfStrictNames[n] then return true end
    for _,t in ipairs(nfNameTokens) do if string.find(s,t,1,true) then return true end end
    return false
end
local function nfIsCandidate(inst)
    if not inst or not inst.Parent then return false end
    if inst:IsA("Clouds") or inst:IsA("Atmosphere") then return true end
    if inst:IsA("ParticleEmitter") and nfMatchesName(inst.Name) then return true end
    if inst:IsA("SunRaysEffect") or inst:IsA("BloomEffect") or inst:IsA("DepthOfFieldEffect") then return true end
    if inst:IsA("Folder") and nfMatchesName(inst.Name) then return true end
    if inst:IsA("Part") and nfMatchesName(inst.Name) then return true end
    return false
end
local function nfDisableParticle(pe) nfSave(pe,{"Enabled","Rate"}) pcall(function() pe.Enabled=false pe.Rate=0 end) end
local function nfDisableClouds(c) nfSave(c,{"Enabled","Cover","Density","Color"}) pcall(function() c.Enabled=false end) end
local function nfFlattenAtmosphere(a) nfSave(a,{"Density","Haze","Glare","Offset","Color","Decay"}) pcall(function() a.Density=0 a.Haze=0 a.Glare=0 end) end
local function nfToneEffects(e)
    if e:IsA("SunRaysEffect") then nfSave(e,{"Enabled","Intensity","Spread"}) pcall(function() e.Enabled=false end)
    elseif e:IsA("BloomEffect") then nfSave(e,{"Enabled","Intensity","Threshold","Size"}) pcall(function() e.Enabled=false end)
    elseif e:IsA("DepthOfFieldEffect") then nfSave(e,{"Enabled","NearIntensity","FarIntensity","InFocusRadius","FocusDistance"}) pcall(function() e.Enabled=false end)
    end
end
local function nfHandle(inst)
    if nfProcessed[inst] then return end
    nfProcessed[inst]=true
    if inst:IsA("Clouds") then nfDisableClouds(inst) return end
    if inst:IsA("Atmosphere") then nfFlattenAtmosphere(inst) return end
    if inst:IsA("ParticleEmitter") then nfDisableParticle(inst) return end
    if inst:IsA("SunRaysEffect") or inst:IsA("BloomEffect") then nfToneEffects(inst) return end
    if inst:IsA("Folder") or inst:IsA("Part") then
        for _,d in ipairs(inst:GetDescendants()) do
            if d:IsA("ParticleEmitter") and nfMatchesName(d.Name) then nfDisableParticle(d) end
        end
    end
end
local function nfEnqueueOne(inst)
    if not nfActive or not nfIsCandidate(inst) or nfQueued[inst] then return end
    nfQueued[inst]=true
    table.insert(nfQueue,inst)
end
local function nfEnqueueTree(root)
    if not root then return end
    for _,d in ipairs(root:GetDescendants()) do nfEnqueueOne(d) end
end
local function nfApplyLighting()
    nfStore.lighting={FogStart=Lighting.FogStart,FogEnd=Lighting.FogEnd,FogColor=Lighting.FogColor}
    pcall(function() Lighting.FogStart=1e9 Lighting.FogEnd=1e9 end)
end
local function nfBindWatchers()
    local c1 = Workspace.DescendantAdded:Connect(function(d) nfEnqueueOne(d) end)
    local c2 = Lighting.DescendantAdded:Connect(function(d) nfEnqueueOne(d) end)
    local c3 = ReplicatedStorage.DescendantAdded:Connect(function(d) nfEnqueueOne(d) end)
    local c4 = Workspace.ChildAdded:Connect(function(ch)
        if ch.Name=="Map" or ch.Name=="Map1" or ch.Name=="Terrain" then
            task.delay(0.4, function() nfEnqueueTree(ch) end)
        end
    end)
    table.insert(nfStore.conns, c1)
    table.insert(nfStore.conns, c2)
    table.insert(nfStore.conns, c3)
    table.insert(nfStore.conns, c4)
end
local function nfStartQueue()
    if nfStore.tick then nfStore.tick:Disconnect() nfStore.tick=nil end
    nfStore.tick = RunService.Heartbeat:Connect(function()
        if not nfActive then return end
        local t0 = os.clock()
        while #nfQueue>0 and (os.clock()-t0) < 0.003 do
            local inst = table.remove(nfQueue,1)
            if inst and inst.Parent then nfHandle(inst) end
        end
    end)
end
local function nfEnable()
    if nfActive then return end
    nfActive = true
    nfApplyLighting()
    nfBindWatchers()
    nfStartQueue()
end
local function nfDisable()
    if not nfActive then return end
    nfActive=false
    nfRestoreAll()
end
TabVisual:CreateToggle({Name="No Fog",CurrentValue=false,Flag="NoFog",Callback=function(s) if s then nfEnable() else nfDisable() end end})

local nsActive=false
local nsStore={lighting={},parts=setmetatable({},{__mode="k"}),conns={}}
local nsQueue, nsQueued, nsProcessed = {}, setmetatable({}, {__mode="k"}), setmetatable({}, {__mode="k"})
local nsSignal=Instance.new("BindableEvent")
local nsBatchSize, nsTickDelay = 400, 0.02
local nsSoftRescanInterval, nsLastSoft = 6, 0
local function nsSaveLighting()
    nsStore.lighting={
        GlobalShadows=Lighting.GlobalShadows,
        ShadowSoftness=Lighting:FindFirstChild("ShadowSoftness") and Lighting.ShadowSoftness or nil,
        EnvironmentDiffuseScale=Lighting:FindFirstChild("EnvironmentDiffuseScale") and Lighting.EnvironmentDiffuseScale or nil,
        EnvironmentSpecularScale=Lighting:FindFirstChild("EnvironmentSpecularScale") and Lighting.EnvironmentSpecularScale or nil,
        Technology=Lighting.Technology
    }
end
local function nsApplyLighting()
    pcall(function()
        Lighting.GlobalShadows=false
        if Lighting:FindFirstChild("ShadowSoftness") then Lighting.ShadowSoftness=0 end
        if Lighting:FindFirstChild("EnvironmentDiffuseScale") then Lighting.EnvironmentDiffuseScale=0 end
        if Lighting:FindFirstChild("EnvironmentSpecularScale") then Lighting.EnvironmentSpecularScale=0 end
        Lighting.Technology=Enum.Technology.Compatibility
    end)
end
local function nsRestoreLighting()
    for k,v in pairs(nsStore.lighting or {}) do pcall(function() if v~=nil then Lighting[k]=v end end) end
end
local function nsIsCandidate(o) return o and o:IsA("BasePart") end
local function nsSavePart(p) if nsStore.parts[p]==nil then nsStore.parts[p]={CastShadow=p.CastShadow} end end
local function nsHandlePart(p) if nsProcessed[p] then return end nsProcessed[p]=true nsSavePart(p) pcall(function() p.CastShadow=false end) end
local function nsEnqueue(o) if nsActive and nsIsCandidate(o) and not nsQueued[o] then nsQueued[o]=true table.insert(nsQueue,o) nsSignal:Fire() end end
local function nsProcessQueue()
    while nsActive do
        if #nsQueue==0 then nsSignal.Event:Wait() end
        local c=0
        while nsActive and #nsQueue>0 and c<nsBatchSize do
            local o=table.remove(nsQueue,1)
            if o and o.Parent then nsHandlePart(o) end
            c=c+1
        end
        task.wait(nsTickDelay)
    end
end
local function nsSoftRescan()
    for _,root in ipairs({Workspace, Workspace:FindFirstChild("Map"), Workspace:FindFirstChild("Terrain")}) do
        if root then for _,d in ipairs(root:GetDescendants()) do if nsIsCandidate(d) then nsEnqueue(d) end end end
    end
end
local function nsBindWatchers()
    local a = Workspace.DescendantAdded:Connect(function(d) if nsIsCandidate(d) then nsEnqueue(d) end end)
    local b = Workspace.ChildAdded:Connect(function(ch) if ch.Name=="Map" or ch.Name=="Map1" then task.delay(0.2, nsSoftRescan) end end)
    local c = RunService.Heartbeat:Connect(function()
        local t=os.clock()
        if t-nsLastSoft>=nsSoftRescanInterval then nsLastSoft=t nsSoftRescan() end
    end)
    table.insert(nsStore.conns,a); table.insert(nsStore.conns,b); table.insert(nsStore.conns,c)
end
local nsThread=nil
local function nsEnable()
    if nsActive then return end
    nsActive=true
    nsQueue, nsQueued, nsProcessed = {}, setmetatable({}, {__mode="k"}), setmetatable({}, {__mode="k"})
    nsSaveLighting(); nsApplyLighting(); nsSoftRescan(); nsBindWatchers()
    if not nsThread then nsThread=task.spawn(nsProcessQueue) end
end
local function nsDisable()
    if not nsActive then return end
    nsActive=false
    for p,st in pairs(nsStore.parts) do if p and p.Parent and st and st.CastShadow~=nil then pcall(function() p.CastShadow=st.CastShadow end) end end
    nsStore.parts=setmetatable({}, {__mode="k"})
    for _,c in ipairs(nsStore.conns) do pcall(function() c:Disconnect() end) end
    nsStore.conns={}
    nsRestoreLighting()
    nsQueue, nsQueued, nsProcessed = {}, setmetatable({}, {__mode="k"}), setmetatable({}, {__mode="k"})
    nsSignal:Fire(); nsThread=nil
end
TabVisual:CreateToggle({Name="No Shadows",CurrentValue=false,Flag="NoShadows",Callback=function(s) if s then nsEnable() else nsDisable() end end})

local speedCurrent, speedHumanoid = 16, nil
local speedEnforced, speedPaused = false, false
local speedStunUntil, speedSlowUntil = 0, 0
local speedTickConn, wsConn, stConn, pfConn, anConn = nil, nil, nil, nil, nil
local speedLastTick, speedTickInterval = 0, 0.12
local serverBaseline = nil

local function canonicalDefault()
    local ok,val = pcall(function() return StarterPlayer.CharacterWalkSpeed end)
    if ok and typeof(val)=="number" and val>0 then return val end
    return 16
end
local function setWalkSpeed(h,v) if h and h.Parent then pcall(function() h.WalkSpeed=v end) end end

local function fixRunAnim()
    local h = speedHumanoid
    if not h or not h.Parent then return end
    local animator = h:FindFirstChildOfClass("Animator")
    if not animator then
        local ac = h:FindFirstChildOfClass("AnimationController")
        if ac then animator = ac:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end
    for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
        local name = (track.Name or ""):lower()
        if name:find("run") or name:find("walk") or name:find("sprint") then
            pcall(function() track:AdjustSpeed(1) end)
        end
    end
end

local function canEnforce()
    local h = speedHumanoid
    if not speedEnforced then return false end
    if not h or not h.Parent then return false end
    if speedPaused then return false end
    if now()<speedStunUntil or now()<speedSlowUntil then return false end
    if h.Health<=0 then return false end
    if h.PlatformStand or h.Sit then return false end
    local st = h:GetState()
    if st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown or st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.GettingUp or st==Enum.HumanoidStateType.Seated then return false end
    local hrp = h.Parent:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Anchored then return false end
    return true
end

local function heartbeat()
    if not speedHumanoid then return end
    local t = now()
    if t - speedLastTick < speedTickInterval then return end
    speedLastTick = t
    if not canEnforce() then return end
    if speedHumanoid.WalkSpeed ~= speedCurrent then setWalkSpeed(speedHumanoid, speedCurrent) end
end

local function disconnectAll()
    if speedTickConn then speedTickConn:Disconnect() speedTickConn=nil end
    if wsConn then wsConn:Disconnect() wsConn=nil end
    if stConn then stConn:Disconnect() stConn=nil end
    if pfConn then pfConn:Disconnect() pfConn=nil end
    if anConn then anConn:Disconnect() anConn=nil end
end

local function captureServerBaseline()
    task.spawn(function()
        local h = speedHumanoid
        if not h or not h.Parent then return end
        local start = now()
        local last = h.WalkSpeed
        while now() - start < 0.6 do
            last = h.WalkSpeed
            task.wait(0.1)
        end
        if typeof(last)=="number" and last > 0 then serverBaseline = last end
    end)
end

local function applyDisabledState()
    local h = speedHumanoid
    if not h or not h.Parent then return end
    local target = serverBaseline or canonicalDefault()
    setWalkSpeed(h, target)
    fixRunAnim()
    captureServerBaseline()
end

local function bindHumanoid(h)
    speedHumanoid = h

    if wsConn then wsConn:Disconnect() end
    wsConn = h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if speedEnforced and canEnforce() and h.WalkSpeed ~= speedCurrent then
            setWalkSpeed(h, speedCurrent)
        end
    end)

    if stConn then stConn:Disconnect() end
    stConn = h.StateChanged:Connect(function(_, new)
        if new==Enum.HumanoidStateType.Ragdoll
        or new==Enum.HumanoidStateType.FallingDown
        or new==Enum.HumanoidStateType.Physics
        or new==Enum.HumanoidStateType.GettingUp
        or new==Enum.HumanoidStateType.Seated then
            speedPaused=true
            speedStunUntil = math.max(speedStunUntil, now()+0.9)
            task.delay(1.0,function() speedPaused=false end)
        end
    end)

    if pfConn then pfConn:Disconnect() end
    pfConn = h:GetPropertyChangedSignal("PlatformStand"):Connect(function() speedPaused = h.PlatformStand end)

    if anConn then anConn:Disconnect() end
    anConn = h.AncestryChanged:Connect(function(_, parent)
        if not parent then disconnectAll() end
    end)

    if speedEnforced then
        if not speedTickConn then
            speedLastTick = 0
            speedTickConn = RunService.Heartbeat:Connect(heartbeat)
        end
        if canEnforce() then setWalkSpeed(h, speedCurrent) end
    else
        applyDisabledState()
    end
end

local abilityNotifyEnabled = true
TabMisc:CreateSection("Notifications")
TabMisc:CreateToggle({Name="Killer Ability Notify",CurrentValue=true,Flag="AbilityNotify",Callback=function(s) abilityNotifyEnabled=s end})

local remoteHooks=setmetatable({},{__mode="k"})
local abilityAllow = {
    ["Killer.ActivatePower"]      = "Ability Activated",
    ["Jason.Instinct"]            = "Instinct",
    ["Masked.Activatepower"]      = "Dash",
    ["Hidden.M2"]                 = "M2",
    ["Stalker.StartStalking"]     = "Stalk",
    ["Abysswalker.corrupt"]       = "Corrupt",
}

local function connectRemote(inst)
    if remoteHooks[inst] then return end
    local isRE,isBE=inst:IsA("RemoteEvent"),inst:IsA("BindableEvent")
    if not(isRE or isBE) then return end
    local full = inst:GetFullName()
    local underKillers    = full:find("ReplicatedStorage.Remotes.Killers",1,true)~=nil
    local underMechanics  = full:find("ReplicatedStorage.Remotes.Mechanics",1,true)~=nil
    local underPallet     = full:find("ReplicatedStorage.Remotes.Pallet",1,true)~=nil
    local underWindow     = full:find("ReplicatedStorage.Remotes.Window",1,true)~=nil

    local function hook(fn)
        local conn
        if isRE then conn=inst.OnClientEvent:Connect(fn) else conn=inst.Event:Connect(fn) end
        remoteHooks[inst]=conn
    end

    if underKillers then
        local seg = string.split(full,".")
        for i=#seg,1,-1 do
            if seg[i]=="Killers" then
                local kn = seg[i+1]
                if kn and knownKillers[kn] then
                    hook(function(...)
                        setKillerType(kn)
                        local key = kn.."."..inst.Name
                        local label = abilityAllow[key]
                        if label and abilityNotifyEnabled then
                            Rayfield:Notify({Title="Killer Ability",Content=kn..": "..label,Duration=4})
                        end
                    end)
                else
                    local key = (kn or "Killer").."."..inst.Name
                    if abilityAllow[key] then
                        hook(function(...)
                            if abilityNotifyEnabled then
                                local who = knownKillers[kn or ""] and kn or killerTypeName
                                Rayfield:Notify({Title="Killer Ability",Content=tostring(who)..": "..abilityAllow[key],Duration=4})
                            end
                        end)
                    end
                end
                break
            end
        end
    end

    if underMechanics then
        if inst.Name=="PalletStun" then hook(function() speedStunUntil = math.max(speedStunUntil, now()+3.5) end)
        elseif inst.Name=="Slow" then hook(function() speedSlowUntil = math.max(speedSlowUntil, now()+3.0) end)
        elseif inst.Name=="Slowserver" and isRE then
            hook(function(_,_,dur)
                local d = (typeof(dur)=="number") and math.clamp(dur,1,10) or 3.0
                speedSlowUntil = math.max(speedSlowUntil, now()+d)
            end)
        end
    end

    if underPallet then
        if inst.Name=="PalletDropEvent" then hook(function()
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local best,bd=nil,1e9
            for m,e in pairs(worldReg.Palletwrong) do if e and e.part then local d=dist(e.part.Position,hrp.Position) if d<bd then bd=d best=m end end end
            if best then palletState[best]="DOWN" end
        end)
        elseif inst.Name=="Destroy" or inst.Name=="Destroy-Global" then hook(function()
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local best,bd=nil,1e9
            for m,e in pairs(worldReg.Palletwrong) do if e and e.part then local d=dist(e.part.Position,hrp.Position) if d<bd then bd=d best=m end end end
            if best then palletState[best]="DEST" end
        end)
        elseif inst.Name=="PalletSlideEvent" then hook(function()
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local best,bd=nil,1e9
            for m,e in pairs(worldReg.Palletwrong) do if e and e.part then local d=dist(e.part.Position,hrp.Position) if d<bd then bd=d best=m end end end
            if best then palletState[best]="SLIDE" task.delay(1.4,function() if palletState[best]=="SLIDE" then palletState[best]="UP" end end) end
        end)
        elseif inst.Name=="PalletSlideCompleteEvent" then hook(function()
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local best,bd=nil,1e9
            for m,e in pairs(worldReg.Palletwrong) do if e and e.part then local d=dist(e.part.Position,hrp.Position) if d<bd then bd=d best=m end end end
            if best and palletState[best]~="DEST" then palletState[best]="UP" end
        end)
        end
    end
    if underWindow then
        if inst.Name=="VaultEvent" or inst.Name=="VaultAnim" or inst.Name=="fastvault" then hook(function()
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local best,bd=nil,1e9
            for m,e in pairs(worldReg.Window) do if e and e.part then local d=dist(e.part.Position,hrp.Position) if d<bd then bd=d best=m end end end
            if best then windowState[best]="BUSY" task.delay(1.2,function() if windowState[best]=="BUSY" then windowState[best]="READY" end end) end
        end)
        elseif inst.Name=="VaultCompleteEvent" then hook(function()
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local best,bd=nil,1e9
            for m,e in pairs(worldReg.Window) do if e and e.part then local d=dist(e.part.Position,hrp.Position) if d<bd then bd=d best=m end end end
            if best then windowState[best]="READY" end
        end)
        end
    end
end

for _,d in ipairs(ReplicatedStorage:GetDescendants()) do if d:IsA("RemoteEvent") or d:IsA("BindableEvent") then connectRemote(d) end end
ReplicatedStorage.DescendantAdded:Connect(function(d) if d:IsA("RemoteEvent") or d:IsA("BindableEvent") then connectRemote(d) end end)

local function onCharacterAdded(char)
    local h = char:WaitForChild("Humanoid", 10) or char:FindFirstChildOfClass("Humanoid")
    if h then bindHumanoid(h) end
    char.ChildAdded:Connect(function(ch) if ch:IsA("Humanoid") then bindHumanoid(ch) end end)
end
if LP.Character then onCharacterAdded(LP.Character) end
LP.CharacterAdded:Connect(onCharacterAdded)

TabPlayer:CreateSection("Movement")
TabPlayer:CreateToggle({
    Name="Speed Lock",
    CurrentValue=false,
    Flag="SpeedLock",
    Callback=function(state)
        speedEnforced = state
        local h = speedHumanoid
        if not h or not h.Parent then return end
        if state then
            if not speedTickConn then
                speedLastTick = 0
                speedTickConn = RunService.Heartbeat:Connect(heartbeat)
            end
            if canEnforce() then setWalkSpeed(h, speedCurrent) end
            Rayfield:Notify({Title="Speed",Content="Speed Lock enabled",Duration=3})
        else
            disconnectAll()
            applyDisabledState()
            Rayfield:Notify({Title="Speed",Content="Speed Lock disabled (baseline restored)",Duration=3})
        end
    end
})
TabPlayer:CreateSlider({Name="Walk Speed",Range={0,200},Increment=1,CurrentValue=16,Flag="WalkSpeed",Callback=function(v) speedCurrent=v if speedEnforced and canEnforce() then setWalkSpeed(speedHumanoid,speedCurrent) end end})
TabPlayer:CreateButton({Name="Reset Speed",Callback=function() speedCurrent=canonicalDefault() if speedHumanoid and speedHumanoid.Parent then if speedEnforced and canEnforce() then setWalkSpeed(speedHumanoid,speedCurrent) else applyDisabledState() end end end})

local noclipEnabled, noclipConn, noclipTouched = false, nil, {}
local function setNoclip(state)
    if state and not noclipConn then
        noclipEnabled = true
        noclipConn = RunService.Stepped:Connect(function()
            local c = LP.Character
            if not c then return end
            for _,part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then
                    if part.CanCollide and not noclipTouched[part] then noclipTouched[part] = true end
                    part.CanCollide = false
                end
            end
        end)
    elseif not state and noclipConn then
        noclipEnabled=false
        noclipConn:Disconnect(); noclipConn=nil
        for part,_ in pairs(noclipTouched) do if part and part.Parent then part.CanCollide=true end end
        noclipTouched={}
    end
end
TabPlayer:CreateToggle({Name="Noclip",CurrentValue=false,Flag="Noclip",Callback=function(s) setNoclip(s) end})
LP.CharacterAdded:Connect(function() if noclipEnabled then task.wait(0.2) setNoclip(true) end end)

TabPlayer:CreateSection("Teleports")
local function tpCFrame(cf)
    local char=LP.Character
    if not (char and char.Parent) then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local was=noclipEnabled
    setNoclip(true)
    hrp.CFrame = cf
    task.delay(0.7,function() if not was then setNoclip(false) end end)
end
local function teleportToNearest(role)
    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local best,bp,bd=nil,nil,1e9
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LP and getRole(pl)==role then
            local ch=pl.Character; local h=ch and ch:FindFirstChild("HumanoidRootPart")
            if h then local d=dist(h.Position,hrp.Position) if d<bd then bd=d best=pl bp=h end end
        end
    end
    if best and bp then
        local cf = bp.CFrame * CFrame.new(0,0,-3)
        cf = cf + Vector3.new(0,3,0)
        tpCFrame(cf)
        Rayfield:Notify({Title="Teleport",Content="To "..role..": "..best.Name,Duration=4})
    else
        Rayfield:Notify({Title="Teleport",Content="No "..role.." found.",Duration=4})
    end
end
TabPlayer:CreateButton({Name="Teleport to Killer (Nearest)",Callback=function() teleportToNearest("Killer") end})
TabPlayer:CreateButton({Name="Teleport to Teammate (Nearest)",Callback=function() teleportToNearest("Survivor") end})

TabPlayer:CreateSection("AFK")
local antiAFKConn=nil
local function setAntiAFK(state)
    if state and not antiAFKConn then
        antiAFKConn = LP.Idled:Connect(function()
            local cam = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or CFrame.new()
            VirtualUser:Button2Down(Vector2.new(0,0), cam); task.wait(1); VirtualUser:Button2Up(Vector2.new(0,0), cam)
        end)
    elseif not state and antiAFKConn then
        antiAFKConn:Disconnect(); antiAFKConn=nil
    end
end
TabPlayer:CreateToggle({Name="Anti AFK",CurrentValue=false,Flag="AntiAFK",Callback=function(s) setAntiAFK(s) end})

local function isKillerTeam() local tn=LP.Team and LP.Team.Name and LP.Team.Name:lower() or "" return tn:find("killer",1,true)~=nil end
local guiWhitelist = {Rayfield=true,DevConsoleMaster=true,RobloxGui=true,PlayerList=true,Chat=true,BubbleChat=true,Backpack=true}
local skillExactNames = {SkillCheckPromptGui=true,["SkillCheckPromptGui-con"]=true,SkillCheckEvent=true,SkillCheckFailEvent=true,SkillCheckResultEvent=true}
local function isExactSkill(inst) local n=inst and inst.Name if not n then return false end if skillExactNames[n] then return true end return n:lower():find("skillcheck",1,true)~=nil end
local function hardDelete(obj)
    pcall(function()
        if obj:IsA("ProximityPrompt") then obj.Enabled=false obj.HoldDuration=1e9 end
        if obj:IsA("ScreenGui") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            if obj:IsA("ScreenGui") and guiWhitelist[obj.Name] then return end
            obj.Enabled=false obj.Visible=false obj.ResetOnSpawn=false obj:Destroy()
        else
            obj:Destroy()
        end
    end)
end
local function nukeSkillExactOnce()
    local pg=LP:FindFirstChild("PlayerGui")
    if pg then
        for _,g in ipairs(pg:GetChildren()) do if isExactSkill(g) then hardDelete(g) end end
        for _,d in ipairs(pg:GetDescendants()) do if isExactSkill(d) then hardDelete(d) end end
    end
    for _,g in ipairs(StarterGui:GetChildren()) do if isExactSkill(g) then hardDelete(g) end end
    local rem=ReplicatedStorage:FindFirstChild("Remotes")
    if rem then for _,d in ipairs(rem:GetDescendants()) do if isExactSkill(d) then hardDelete(d) end end end
end
local noSkillEnabled=false
local noSkillToggleUser=false
local hookSkillInstalled=false
local rsAddConn, pgAddConn, pgDescConn, sgAddConn, remAddConn, wsAddConn
local charAddConns={}
local function installSkillBlock()
    if hookSkillInstalled then return end
    if typeof(hookmetamethod)=="function" and typeof(getnamecallmethod)=="function" then
        local old
        old = hookmetamethod(game,"__namecall",function(self,...)
            local m=getnamecallmethod()
            if noSkillEnabled and typeof(self)=="Instance" and isExactSkill(self) and (m=="FireServer" or m=="InvokeServer") then
                return nil
            end
            return old(self,...)
        end)
        hookSkillInstalled=true
    end
end
local function startNoSkill()
    installSkillBlock()
    nukeSkillExactOnce()
    local pg=LP:FindFirstChild("PlayerGui")
    if pg then
        if pgAddConn then pgAddConn:Disconnect() end
        pgAddConn = pg.ChildAdded:Connect(function(ch) if noSkillEnabled and isExactSkill(ch) then hardDelete(ch) end end)
        if pgDescConn then pgDescConn:Disconnect() end
        pgDescConn = pg.DescendantAdded:Connect(function(d) if noSkillEnabled and isExactSkill(d) then hardDelete(d) end end)
    end
    if sgAddConn then sgAddConn:Disconnect() end
    sgAddConn = StarterGui.ChildAdded:Connect(function(ch) if noSkillEnabled and isExactSkill(ch) then hardDelete(ch) end end)
    local rem=ReplicatedStorage:FindFirstChild("Remotes")
    if rem then
        if remAddConn then remAddConn:Disconnect() end
        remAddConn = rem.DescendantAdded:Connect(function(d) if noSkillEnabled and isExactSkill(d) then hardDelete(d) end end)
    end
    if rsAddConn then rsAddConn:Disconnect() end
    rsAddConn = ReplicatedStorage.DescendantAdded:Connect(function(d)
        if not noSkillEnabled then return end
        if d:IsA("ScreenGui") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") then
            if isExactSkill(d) then hardDelete(d) end
        end
    end)
    for _,pl in ipairs(Players:GetPlayers()) do
        if charAddConns[pl] then charAddConns[pl]:Disconnect() end
        charAddConns[pl] = pl.CharacterAdded:Connect(function(ch)
            if not noSkillEnabled then return end
            task.wait(0.1)
            for _,d in ipairs(ch:GetDescendants()) do if isExactSkill(d) then hardDelete(d) end end
        end)
        if pl.Character then for _,d in ipairs(pl.Character:GetDescendants()) do if isExactSkill(d) then hardDelete(d) end end end
    end
    if wsAddConn then wsAddConn:Disconnect() end
    wsAddConn = Workspace.DescendantAdded:Connect(function(d) if noSkillEnabled and isExactSkill(d) then hardDelete(d) end end)
end
local function stopNoSkill()
    if pgAddConn then pgAddConn:Disconnect() pgAddConn=nil end
    if pgDescConn then pgDescConn:Disconnect() pgDescConn=nil end
    if sgAddConn then sgAddConn:Disconnect() sgAddConn=nil end
    if remAddConn then remAddConn:Disconnect() remAddConn=nil end
    if rsAddConn then rsAddConn:Disconnect() rsAddConn=nil end
    if wsAddConn then wsAddConn:Disconnect() wsAddConn=nil end
    for pl,cn in pairs(charAddConns) do if cn then cn:Disconnect() end charAddConns[pl]=nil end
end
local function evalNoSkill()
    if noSkillToggleUser and not isKillerTeam() then
        if not noSkillEnabled then noSkillEnabled=true startNoSkill() end
    else
        if noSkillEnabled then noSkillEnabled=false stopNoSkill() end
    end
end
LP:GetPropertyChangedSignal("Team"):Connect(evalNoSkill)
TabMisc:CreateSection("Skillcheck")
TabMisc:CreateToggle({Name="No Skillchecks",CurrentValue=false,Flag="NoSkill",Callback=function(s) noSkillToggleUser=s evalNoSkill() end})

local function findExitLevers()
    local list={}
    local map=Workspace:FindFirstChild("Map")
    if not map then return list end
    for _,d in ipairs(map:GetDescendants()) do
        if d.Name=="ExitLever" then
            local p=firstBasePart(d)
            if validPart(p) then table.insert(list,p) end
        end
    end
    return list
end
local function teleportRightOfLever(leverPart)
    local right = leverPart.CFrame.RightVector * 50
    local targetPos = leverPart.Position + right
    tpCFrame(CFrame.new(targetPos))
end
TabWorld:CreateSection("Escape")
TabWorld:CreateButton({Name="Instant-Escape (Nearest Gate)",Callback=function()
    local levers = findExitLevers()
    if #levers==0 then Rayfield:Notify({Title="Instant-Escape",Content="No ExitLever found.",Duration=5}) return end
    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local pick = levers[1]
    if hrp then
        local bd=1e9
        for _,p in ipairs(levers) do local d=(p.Position-hrp.Position).Magnitude if d<bd then bd=d pick=p end end
    end
    teleportRightOfLever(pick)
    Rayfield:Notify({Title="Instant-Escape",Content="Teleported behind gate.",Duration=4})
end})

do
    local autoRepairEnabled = false
    local SCAN_INTERVAL = 1.0
    local REPAIR_TICK   = 0.25
    local AVOID_RADIUS  = 80
    local MOVE_DIST     = 35
    local UP_OFFSET     = Vector3.new(0, 3, 0)
    local gens = {}
    local current = nil
    local lastScan = 0

    local function findRemotes()
        local r = ReplicatedStorage:FindFirstChild("Remotes")
        if not r then return nil,nil end
        local g = r:FindFirstChild("Generator")
        if not g then return nil,nil end
        local repair = g:FindFirstChild("RepairEvent")
        local anim   = g:FindFirstChild("RepairAnim")
        return repair, anim
    end
    local RepairEvent, RepairAnim = findRemotes()

    local function ensureRemotes()
        if RepairEvent and RepairEvent.Parent then return end
        RepairEvent, RepairAnim = findRemotes()
    end

    local function getGenPartFromModel(m)
        if not (m and alive(m)) then return nil end
        local hb = m:FindFirstChild("HitBox", true)
        if validPart(hb) then return hb end
        return firstBasePart(m)
    end

    local function genProgress(m)
        local p = tonumber(m:GetAttribute("RepairProgress")) or 0
        if p <= 1.001 then p = p * 100 end
        return clamp(p,0,100)
    end

    local function genPaused(m)
        return (m:GetAttribute("ProgressPaused")==true)
    end

    local function rescanGenerators()
        gens = {}
        local function scanRoot(root)
            if not root then return end
            for _,d in ipairs(root:GetDescendants()) do
                if d:IsA("Model") and d.Name=="Generator" then
                    local part = getGenPartFromModel(d)
                    if validPart(part) then
                        table.insert(gens, {model=d, part=part})
                    end
                end
            end
        end
        scanRoot(Workspace:FindFirstChild("Map"))
        scanRoot(Workspace:FindFirstChild("Map1"))
    end

    local function nearestKillerDistanceTo(pos)
        local bd = 1e9
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and getRole(pl)=="Killer" then
                local ch = pl.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (hrp.Position - pos).Magnitude
                    if d < bd then bd = d end
                end
            end
        end
        return bd
    end

    local function lpHRP()
        return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    end

    local function chooseTarget()
        local best = nil
        local bestScore = -1
        for _,g in ipairs(gens) do
            local m = g.model
            if alive(m) then
                local prog = genProgress(m)
                if prog < 100 and not genPaused(m) then
                    local pos = g.part.Position
                    local kd = nearestKillerDistanceTo(pos)
                    local score = (kd >= AVOID_RADIUS and 1000 or 0) + prog
                    if score > bestScore then
                        bestScore = score
                        best = g
                    end
                end
            end
        end
        return best
    end

    local function safeFromKiller(target)
        if not target or not target.part then return false end
        local kd = nearestKillerDistanceTo(target.part.Position)
        return kd >= AVOID_RADIUS
    end

    local function closeEnough(target)
        local hrp = lpHRP(); if not hrp then return false end
        return (hrp.Position - target.part.Position).Magnitude <= MOVE_DIST
    end

    local function tpNear(part)
        local cf = part.CFrame * CFrame.new(0,0,-3)
        tpCFrame((cf + UP_OFFSET))
    end

    local function doRepair(target)
        ensureRemotes()
        if RepairAnim and RepairAnim.FireServer then pcall(function() RepairAnim:FireServer(target.model) end) end
        if RepairEvent and RepairEvent.FireServer then pcall(function() RepairEvent:FireServer(target.model) end) end
    end

    task.spawn(function()
        while true do
            local t = now()
            if t - lastScan >= SCAN_INTERVAL then
                lastScan = t
                rescanGenerators()
            end
            task.wait(0.2)
        end
    end)

    task.spawn(function()
        while true do
            if autoRepairEnabled then
                if (not current) or (not alive(current.model)) or genProgress(current.model) >= 100 or genPaused(current.model) or (not safeFromKiller(current)) then
                    current = chooseTarget()
                end

                if current and alive(current.model) and genProgress(current.model) < 100 then
                    local me = lpHRP()
                    if me and nearestKillerDistanceTo(me.Position) < AVOID_RADIUS then
                        local alt = chooseTarget()
                        if alt and alt ~= current then current = alt end
                    end

                    if not closeEnough(current) then
                        tpNear(current.part)
                    end

                    doRepair(current)
                end
            end
            task.wait(REPAIR_TICK)
        end
    end)

    TabWorld:CreateToggle({
        Name="Auto-Repair Gens",
        CurrentValue=false,
        Flag="AutoRepairGens",
        Callback=function(state)
            autoRepairEnabled = state
            Rayfield:Notify({
                Title="Auto-Repair",
                Content=state and "aktiviert" or "deaktiviert",
                Duration=4
            })
        end
    })

    ReplicatedStorage.DescendantAdded:Connect(function(d)
        if d:IsA("RemoteEvent") and d.Name=="RepairEvent" then RepairEvent=d end
        if d:IsA("RemoteEvent") and d.Name=="RepairAnim"  then RepairAnim=d end
    end)
end
Rayfield:LoadConfiguration()
Rayfield:Notify({Title="Violence District",Content="Loaded",Duration=6})
Rayfield:Notify({Title="Info",Content="Pallet ghost ESP fixed • Speed Lock stabilized • Pumpkin ESP added",Duration=6})
