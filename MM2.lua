local function fetchRayfield()
    local urls={"https://sirius.menu/rayfield","https://raw.githubusercontent.com/shlexware/Rayfield/main/source","https://github.com/shlexware/Rayfield/raw/main/source"}
    local function okBody(s) return type(s)=="string" and #s>4000 and s:find("CreateWindow") end
    local function try(u)
        local ok,b=pcall(function() return game:HttpGet(u) end)
        if ok and okBody(b) then return b end
        if syn and syn.request then local r=syn.request({Url=u,Method="GET"}); if r and r.StatusCode==200 and okBody(r.Body) then return r.Body end end
        if http_request then local r=http_request({Url=u,Method="GET"}); if r and r.StatusCode==200 and okBody(r.Body) then return r.Body end end
        if request then local r=request({Url=u,Method="GET"}); if r and r.StatusCode==200 and okBody(r.Body) then return r.Body end end
    end
    for _,u in ipairs(urls) do local b=try(u); if b then local ok,lib=pcall(function() return loadstring(b)() end); if ok and lib then return lib end end end
    error("Rayfield load failed")
end

local Rayfield=fetchRayfield()
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TextChatService=game:FindService("TextChatService")
local LocalPlayer=Players.LocalPlayer
local cam=workspace.CurrentCamera

local Window=Rayfield:CreateWindow({
    Name="MM2 Script | made by massivendurchfall",
    Icon=0,LoadingTitle="Initializing...",LoadingSubtitle="Rayfield UI",
    Theme="Default",ToggleUIKeybind="K",
    DisableRayfieldPrompts=true,DisableBuildWarnings=true,
    ConfigurationSaving={Enabled=true,FolderName="MM2Cfg",FileName="MM2_Main"},
    KeySystem=false
})

local STATE={
    PlayerChams=false,
    RoleESP=false,
    NameTags=false,
    CollectibleESP=false,
    BeachBallESP=false,
    AutoBeachBalls=false,
    AutoGun=false,
    WalkSpeed=16,
    Fly=false,FlySpeed=20,
    Noclip=false,
    AntiAFK=false,
    AutoChat=false,ChatMessage="gg",ChatInterval=30,
    BeachAutoSpeed=14,
    ExpandHitbox=false,
    HitboxOnlyMurder=true,
    HitboxSize=8,
    HitboxHeight=1.8
}

local UPDATE_STEP=0.16
local RECONCILE_STEP=1.0
local HARD_REFRESH_STEP=0.75
local COLLECT_UPDATE=0.25

local function hum(c) if not c then return end for _,v in ipairs(c:GetChildren()) do if v:IsA("Humanoid") then return v end end end
local function rig(char) if not char then return nil,nil end local head=char:FindFirstChild("Head") local root=char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChildWhichIsA("BasePart") if not head then head=root end return root,head end
local function hrp(c) local r,_=rig(c); return r end
local function backpack(p) for _,c in ipairs(p:GetChildren()) do if c:IsA("Backpack") then return c end end end
local function toolKnife(t) if not (t and t:IsA("Tool")) then return false end local n=(t.Name or ""):lower(); if n:find("knife") or n:find("blade") then return true end for _,d in ipairs(t:GetDescendants()) do if d:IsA("MeshPart") or d:IsA("SpecialMesh") then local mid=tostring(d.MeshId or ""):lower(); if mid:find("knife") or mid:find("blade") then return true end end end return false end
local function toolGun(t) if not (t and t:IsA("Tool")) then return false end local n=(t.Name or ""):lower(); return n:find("gun") or n:find("revolver") or n:find("pistol") end

local function roleFromAttrs(plr,char)
    local function norm(v) if type(v)~="string" then return end v=v:lower(); if v:find("murder") or v:find("killer") then return "murder" end if v:find("sheriff") or v:find("gun") then return "sheriff" end if v:find("innocent") then return "innocent" end end
    local ok1,r1=pcall(function() return plr:GetAttribute("Role") end); if ok1 then local r=norm(r1); if r then return r end end
    if char then local ok2,r2=pcall(function() return char:GetAttribute("Role") end); if ok2 then local r=norm(r2); if r then return r end end end
    local ls=plr:FindFirstChild("leaderstats"); if ls then local s=ls:FindFirstChild("Role"); if s and s:IsA("StringValue") then local r=norm(s.Value); if r then return r end end end
end
local function roleFromEquip(plr,char)
    local k,g=false,false
    if char then for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") then if toolKnife(t) then k=true end if toolGun(t) then g=true end end end end
    local bp=backpack(plr); if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then if toolKnife(t) then k=true end if toolGun(t) then g=true end end end end
    if g then return "sheriff" end
    if k then return "murder" end
    return "innocent"
end
local function resolveRole(plr) local c=plr.Character; return roleFromAttrs(plr,c) or roleFromEquip(plr,c) end
local function colorForRole(r) if r=="murder" then return Color3.fromRGB(255,70,70) elseif r=="sheriff" then return Color3.fromRGB(255,230,0) else return Color3.fromRGB(55,200,255) end end

local function ensureTextLabel(parent, size, bold)
    local lbl=parent:FindFirstChild("Text")
    if not lbl then lbl=Instance.new("TextLabel"); lbl.Name="Text"; lbl.BackgroundTransparency=1; lbl.TextScaled=false; lbl.TextSize=size; lbl.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham; lbl.TextStrokeTransparency=0.5; lbl.Size=UDim2.new(1,0,1,0); lbl.Parent=parent end
    return lbl
end

local function ensureESP(char)
    local f=char:FindFirstChild("__ESP"); if not f then f=Instance.new("Folder"); f.Name="__ESP"; f.Parent=char end
    local hl=f:FindFirstChildOfClass("Highlight"); if not hl then hl=Instance.new("Highlight"); hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.FillTransparency=0.72; hl.OutlineTransparency=0; hl.Adornee=char; hl.Parent=f end
    local nameGui=f:FindFirstChild("NameGui"); if not nameGui then nameGui=Instance.new("BillboardGui"); nameGui.Name="NameGui"; nameGui.AlwaysOnTop=true; nameGui.Size=UDim2.new(0,200,0,18); nameGui.MaxDistance=10000; nameGui.Parent=f end
    local roleGui=f:FindFirstChild("RoleGui"); if not roleGui then roleGui=Instance.new("BillboardGui"); roleGui.Name="RoleGui"; roleGui.AlwaysOnTop=true; roleGui.Size=UDim2.new(0,160,0,18); roleGui.MaxDistance=10000; roleGui.Parent=f end
    local root,head=rig(char)
    nameGui.Adornee=head or char
    roleGui.Adornee=root or head or char
    nameGui.StudsOffset=Vector3.new(0,(head and 3.6 or 4.0),0)
    roleGui.StudsOffset=Vector3.new(0,1.8,0)
    local nameLabel=ensureTextLabel(nameGui,14,false)
    local roleLabel=ensureTextLabel(roleGui,16,true)
    return f,hl,nameGui,nameLabel,roleGui,roleLabel
end

local function ensureHitbox(char,size,height,color)
    local f=char:FindFirstChild("__HBX"); if not f then f=Instance.new("Folder"); f.Name="__HBX"; f.Parent=char end
    local box=f:FindFirstChild("HBXBox"); if not box then box=Instance.new("BoxHandleAdornment"); box.Name="HBXBox"; box.AlwaysOnTop=true; box.ZIndex=20; box.Transparency=0.55; box.Parent=f end
    local r=hrp(char) or char:FindFirstChildWhichIsA("BasePart"); if r then box.Adornee=r end
    box.Color3=color
    box.Size=Vector3.new(size, size*height, size)
    box.Visible=true
end
local function clearHitbox(char) local f=char and char:FindFirstChild("__HBX"); if f then f:Destroy() end end

local function applyFor(plr)
    if plr==LocalPlayer then return end
    local c=plr.Character; if not (c and c.Parent) then return end
    local folder,hl,nameGui,nameLabel,roleGui,roleLabel=ensureESP(c)
    if nameLabel then nameLabel.Text=plr.Name end
    nameGui.Enabled=STATE.NameTags
    if nameLabel then nameLabel.Visible=STATE.NameTags end
    local r=resolveRole(plr)
    local col=colorForRole(r)
    if STATE.PlayerChams then hl.FillColor=col hl.OutlineColor=Color3.new(1,1,1) hl.Enabled=true else hl.Enabled=false end
    if STATE.RoleESP then roleGui.Enabled=true if roleLabel then roleLabel.Text=string.upper(r) roleLabel.TextColor3=col end else roleGui.Enabled=false end
    local wantHB=STATE.ExpandHitbox and ((STATE.HitboxOnlyMurder and r=="murder") or (not STATE.HitboxOnlyMurder))
    if wantHB then ensureHitbox(c,STATE.HitboxSize,STATE.HitboxHeight,col) else clearHitbox(c) end
end

local function fullRefresh() for _,pl in ipairs(Players:GetPlayers()) do if pl~=LocalPlayer then applyFor(pl) end end end
local function disableAllVisuals()
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer and pl.Character then
            local f=pl.Character:FindFirstChild("__ESP")
            if f then
                local hl=f:FindFirstChildOfClass("Highlight"); if hl then hl.Enabled=false end
                local ng=f:FindFirstChild("NameGui"); if ng then ng.Enabled=false end
                local rg=f:FindFirstChild("RoleGui"); if rg then rg.Enabled=false end
            end
            clearHitbox(pl.Character)
        end
    end
end

local function backpackHook(plr,bp) if not bp then return end bp.ChildAdded:Connect(function() applyFor(plr) end) bp.ChildRemoved:Connect(function() applyFor(plr) end) end

local conns={}
local function isOur(inst) local n=inst and inst.Name or "" return string.sub(n,1,2)=="__" end
local function bindCharacter(plr,char)
    if not conns[plr] then conns[plr]={} end
    for _,c in ipairs(conns[plr]) do pcall(function() c:Disconnect() end) end
    conns[plr]={}
    table.insert(conns[plr], char.DescendantAdded:Connect(function(inst) if isOur(inst) then return end task.defer(function() if plr.Character==char then applyFor(plr) end end) end))
    table.insert(conns[plr], char.DescendantRemoving:Connect(function(inst) if isOur(inst) then return end task.defer(function() if plr.Character==char then applyFor(plr) end end) end))
    local h=hum(char)
    if h then table.insert(conns[plr], h.Changed:Connect(function(p) if p=="RigType" or p=="Health" then task.defer(function() if plr.Character==char then applyFor(plr) end end) end end)) end
    applyFor(plr)
end
local function unbind(plr) local arr=conns[plr]; if arr then for _,c in ipairs(arr) do pcall(function() c:Disconnect() end) end end conns[plr]=nil end

local function wire(plr)
    local bp=backpack(plr); if bp then backpackHook(plr,bp) end
    plr.ChildAdded:Connect(function(ch) if ch:IsA("Backpack") then backpackHook(plr,ch) end end)
    if plr.Character then bindCharacter(plr,plr.Character) end
    plr.CharacterAdded:Connect(function(c) task.wait(0.2); bindCharacter(plr,c) end)
    plr.CharacterRemoving:Connect(function() unbind(plr) end)
end
for _,p in ipairs(Players:GetPlayers()) do wire(p) end
Players.PlayerAdded:Connect(wire)
Players.PlayerRemoving:Connect(function(plr) unbind(plr) end)

local function restoreCollision()
    local c=LocalPlayer.Character; if not c then return end
    for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end
end

local rr,lastStep=1,0
local lastRecon=0
local lastHard=0
RunService.Heartbeat:Connect(function()
    local c=LocalPlayer.Character; local h=hum(c)
    if h and h.WalkSpeed~=STATE.WalkSpeed then h.WalkSpeed=STATE.WalkSpeed end
    if time()-lastStep>=UPDATE_STEP and (STATE.PlayerChams or STATE.RoleESP or STATE.NameTags or STATE.ExpandHitbox) then
        local list=Players:GetPlayers()
        if #list>0 then rr=rr+1; if rr>#list then rr=1 end local pl=list[rr]; if pl and pl~=LocalPlayer then applyFor(pl) end end
        lastStep=time()
    end
    if time()-lastRecon>=RECONCILE_STEP then
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl~=LocalPlayer and pl.Character then
                local f=pl.Character:FindFirstChild("__ESP")
                if not f then applyFor(pl) else
                    local ng=f:FindFirstChild("NameGui")
                    local rg=f:FindFirstChild("RoleGui")
                    if not ng or not rg then applyFor(pl) else
                        local root,head=rig(pl.Character)
                        if ng.Adornee~=head then ng.Adornee=head or pl.Character end
                        if rg.Adornee~=root then rg.Adornee=root or head or pl.Character end
                        ensureTextLabel(ng,14,false)
                        ensureTextLabel(rg,16,true)
                    end
                end
            end
        end
        lastRecon=time()
    end
    if time()-lastHard>=HARD_REFRESH_STEP and (STATE.PlayerChams or STATE.RoleESP or STATE.NameTags or STATE.ExpandHitbox) then
        fullRefresh()
        lastHard=time()
    end
end)

local function setNoclip(on)
    STATE.Noclip=on
    if not on then restoreCollision() end
end

RunService.Stepped:Connect(function()
    if not (STATE.Noclip or STATE.AutoBeachBalls or STATE.Fly) then return end
    local c=LocalPlayer.Character; if not c then return end
    for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
end)

local vu=game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function() if STATE.AntiAFK then vu:Button2Down(Vector2.new(0,0), cam.CFrame); task.wait(0.8); vu:Button2Up(Vector2.new(0,0), cam.CFrame) end end)

local function isCollectible(part)
    if not (part and part:IsA("BasePart")) then return false end
    if part:GetAttribute("Collected")==true then return false end
    if part:GetAttribute("CoinID") then return true end
    if part.Name=="Coin_Server" then return true end
    if part:FindFirstChildWhichIsA("TouchTransmitter") or part:FindFirstChildOfClass("TouchInterest") then return true end
    local n=(part.Name or ""):lower()
    if n:find("coin") or n:find("beach") then return true end
    return false
end

local collectMap,collectList={},{}
local beachMap,beachList={},{}

local function ensureCollectESP(part,color,labelText)
    local f=part:FindFirstChild("__CESP"); if not f then f=Instance.new("Folder"); f.Name="__CESP"; f.Parent=part end
    local hl=f:FindFirstChildOfClass("Highlight"); if not hl then hl=Instance.new("Highlight"); hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.FillTransparency=0.7; hl.OutlineTransparency=0; hl.Adornee=part; hl.Parent=f end
    hl.FillColor=color
    local bg=f:FindFirstChild("Bill"); if not bg then bg=Instance.new("BillboardGui"); bg.Name="Bill"; bg.AlwaysOnTop=true; bg.Size=UDim2.new(0,160,0,18); bg.StudsOffset=Vector3.new(0,2.2,0); bg.Adornee=part; bg.MaxDistance=10000; bg.Parent=f end
    local lbl=ensureTextLabel(bg,14,true); lbl.Text=labelText
    return f,hl,bg,lbl
end

local function setCollectVisible(part,on)
    local f=part and part:FindFirstChild("__CESP"); if not f then return end
    local hl=f:FindFirstChildOfClass("Highlight"); if hl then hl.Enabled=on end
    local bg=f:FindFirstChild("Bill"); if bg then bg.Enabled=on end
end

local function addCollectible(part)
    if collectMap[part] then return end
    collectMap[part]=true
    table.insert(collectList,part)
    local id=tostring(part:GetAttribute("CoinID") or "Collectible")
    ensureCollectESP(part,Color3.fromRGB(0,220,140),id)
    setCollectVisible(part,STATE.CollectibleESP)
    part.Destroying:Connect(function() collectMap[part]=nil end)
    part:GetAttributeChangedSignal("Collected"):Connect(function() if part:GetAttribute("Collected")==true then setCollectVisible(part,false) end end)
end

local function addBeachBall(part)
    if beachMap[part] then return end
    beachMap[part]=true
    table.insert(beachList,part)
    ensureCollectESP(part,Color3.fromRGB(20,160,255),"BeachBall")
    setCollectVisible(part,STATE.BeachBallESP)
    part.Destroying:Connect(function() beachMap[part]=nil end)
    part:GetAttributeChangedSignal("Collected"):Connect(function() if part:GetAttribute("Collected")==true then setCollectVisible(part,false) end end)
end

local function scanInitialCollectibles()
    for _,d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and isCollectible(d) then
            local id=d:GetAttribute("CoinID")
            if id=="BeachBall" then addBeachBall(d) else addCollectible(d) end
        end
    end
end

workspace.DescendantAdded:Connect(function(d)
    if not d:IsA("BasePart") then return end
    if d.Name and string.sub(d.Name,1,2)=="__" then return end
    if not isCollectible(d) then return end
    task.defer(function()
        local id=d:GetAttribute("CoinID")
        if id=="BeachBall" then addBeachBall(d) else addCollectible(d) end
    end)
end)
scanInitialCollectibles()

local function updateCollectLabel(part)
    if not (part and part.Parent) then return end
    local f=part:FindFirstChild("__CESP"); if not f then return end
    local bg=f:FindFirstChild("Bill"); if not bg then return end
    local lbl=ensureTextLabel(bg,14,true)
    local r=hrp(LocalPlayer.Character); if not (r and r.Parent) then return end
    local id=tostring(part:GetAttribute("CoinID") or "Collectible")
    local ok,dist=pcall(function() return (part.Position-r.Position).Magnitude end)
    if not ok or type(dist)~="number" then return end
    lbl.Text=id.."  ["..math.floor(dist).."m]"
end

local collectRR,collectLast=1,0
task.spawn(function()
    while true do
        if (STATE.CollectibleESP or STATE.BeachBallESP) and time()-collectLast>=COLLECT_UPDATE then
            local pool={}
            if STATE.CollectibleESP then for _,p in ipairs(collectList) do if p and p.Parent and p:GetAttribute("Collected")~=true then table.insert(pool,p) end end end
            if STATE.BeachBallESP then for _,p in ipairs(beachList) do if p and p.Parent and p:GetAttribute("Collected")~=true then table.insert(pool,p) end end end
            if #pool>0 then collectRR=collectRR+1; if collectRR>#pool then collectRR=1 end; updateCollectLabel(pool[collectRR]) end
            collectLast=time()
        end
        task.wait(0.05)
    end
end)

local gunQueue={}
local lastGunSweep=0
workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Tool") then
        local n=(d.Name or ""):lower()
        if n:find("gun") or n:find("revolver") or n:find("pistol") then table.insert(gunQueue,d) end
    elseif d:IsA("BasePart") then
        local n=(d.Name or ""):lower()
        if n:find("gun") and d.Parent==workspace then table.insert(gunQueue,d) end
    end
end)

local function findDroppedGunFast()
    for i=#gunQueue,1,-1 do
        local g=gunQueue[i]
        if not g or not g.Parent then table.remove(gunQueue,i) else return g end
    end
    if time()-lastGunSweep<3 then return nil end
    lastGunSweep=time()
    for _,d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Tool") then
            local n=(d.Name or ""):lower()
            if (n:find("gun") or n:find("revolver") or n:find("pistol")) and not d:FindFirstChildWhichIsA("Humanoid") then return d end
        elseif d:IsA("BasePart") then
            local n=(d.Name or ""):lower()
            if n:find("gun") and d.Parent==workspace then return d end
        end
    end
end

local function partFrom(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Tool") then return obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart",true) end
    return obj:FindFirstChildWhichIsA("BasePart",true)
end

local function equipGunNow()
    if not STATE.AutoGun then return end
    local c=LocalPlayer.Character; if not c then return end
    local h=hum(c); if not h then return end
    for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and toolGun(t) then h:EquipTool(t) return end end
    local bp=backpack(LocalPlayer)
    if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and toolGun(t) then h:EquipTool(t) return end end end
end

local function touchSmart(obj)
    local root=hrp(LocalPlayer.Character); if not root or not obj then return end
    local target=partFrom(obj); if not target then return end
    if typeof(firetouchinterest)=="function" then firetouchinterest(root,target,0); task.wait(0.05); firetouchinterest(root,target,1) end
    local old=root.CFrame; root.CFrame=target.CFrame*CFrame.new(0,3,0); task.wait(0.06); root.CFrame=old
    task.delay(0.05,equipGunNow)
end

local function wireAutoGun()
    local function onAdded(x) if not STATE.AutoGun then return end if x:IsA("Tool") and toolGun(x) then task.defer(equipGunNow) end end
    if LocalPlayer.Character then LocalPlayer.Character.ChildAdded:Connect(onAdded) end
    LocalPlayer.CharacterAdded:Connect(function(ch) ch.ChildAdded:Connect(onAdded) end)
    local bp=backpack(LocalPlayer); if bp then bp.ChildAdded:Connect(onAdded) end
    LocalPlayer.ChildAdded:Connect(function(o) if o:IsA("Backpack") then o.ChildAdded:Connect(onAdded) end end)
end
wireAutoGun()

task.spawn(function()
    while true do
        if STATE.AutoGun then local g=findDroppedGunFast(); if g and g.Parent then touchSmart(g) end end
        task.wait(0.25)
    end
end)

local flyBV,flyBG=nil,nil
local flyMove=Vector3.new()
local flyUp,flyDown=false,false
local autopilotVec=nil
local autopilotSpeed=nil
local beachTarget=nil
local beachLastDist=1e9
local beachStuck=0
local beachConn={}

local function ensureFlyBody()
    local r=hrp(LocalPlayer.Character); if not r then return end
    if not flyBV then flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(1e5,1e5,1e5); flyBV.Velocity=Vector3.new(); flyBV.Parent=r end
    if not flyBG then flyBG=Instance.new("BodyGyro"); flyBG.MaxTorque=Vector3.new(1e5,1e5,1e5); flyBG.P=6e3; flyBG.CFrame=r.CFrame; flyBG.Parent=r end
end
local function setFly(on) STATE.Fly=on if on then ensureFlyBody() else if flyBV then flyBV:Destroy(); flyBV=nil end if flyBG then flyBG:Destroy(); flyBG=nil end flyMove=Vector3.new() flyUp=false flyDown=false autopilotVec=nil autopilotSpeed=nil restoreCollision() end end

UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    local kc=i.KeyCode
    if kc==Enum.KeyCode.W then flyMove=Vector3.new(0,0,-1)
    elseif kc==Enum.KeyCode.S then flyMove=Vector3.new(0,0,1)
    elseif kc==Enum.KeyCode.A then flyMove=Vector3.new(-1,0,0)
    elseif kc==Enum.KeyCode.D then flyMove=Vector3.new(1,0,0)
    elseif kc==Enum.KeyCode.Space then flyUp=true
    elseif kc==Enum.KeyCode.LeftControl or kc==Enum.KeyCode.C then flyDown=true end
end)
UIS.InputEnded:Connect(function(i,gp)
    if gp then return end
    local kc=i.KeyCode
    if kc==Enum.KeyCode.W or kc==Enum.KeyCode.S or kc==Enum.KeyCode.A or kc==Enum.KeyCode.D then flyMove=Vector3.new()
    elseif kc==Enum.KeyCode.Space then flyUp=false
    elseif kc==Enum.KeyCode.LeftControl or kc==Enum.KeyCode.C then flyDown=false end
end)

local function flyStep(dt)
    if not STATE.Fly and not autopilotVec then return end
    local r=hrp(LocalPlayer.Character); if not r then return end
    ensureFlyBody()
    local look=cam.CFrame.LookVector
    local right=cam.CFrame.RightVector
    local dir=Vector3.new()
    if autopilotVec then dir=autopilotVec else
        dir=(right*flyMove.X + look*(-flyMove.Z))
        if flyUp then dir=dir+Vector3.new(0,1,0) end
        if flyDown then dir=dir+Vector3.new(0,-1,0) end
        if dir.Magnitude<0.01 then dir=Vector3.new() end
    end
    local spd=STATE.Fly and STATE.FlySpeed or (autopilotSpeed or STATE.BeachAutoSpeed)
    flyBV.Velocity=(dir.Magnitude>0 and dir.Unit or Vector3.new())*spd
    flyBG.CFrame=cam.CFrame
end
RunService.Heartbeat:Connect(function(dt) flyStep(dt) end)

local function clearBeachConn() for _,c in ipairs(beachConn) do pcall(function() c:Disconnect() end) end beachConn={} end
local function bindBeachTarget(ball)
    clearBeachConn()
    if not ball then return end
    table.insert(beachConn, ball.Destroying:Connect(function() beachTarget=nil end))
    table.insert(beachConn, ball:GetAttributeChangedSignal("Collected"):Connect(function() if ball:GetAttribute("Collected")==true then beachTarget=nil end end))
end

local function nearestBeachBall()
    local r=hrp(LocalPlayer.Character); if not r then return nil end
    local best,bd=nil,1e9
    for _,p in ipairs(beachList) do
        if p and p.Parent and p:GetAttribute("Collected")~=true then
            local d=(p.Position-r.Position).Magnitude
            if d<bd then bd, best=d, p end
        end
    end
    return best
end

RunService.Heartbeat:Connect(function(dt)
    local c=LocalPlayer.Character; local h=hum(c); if h and h.WalkSpeed~=STATE.WalkSpeed then h.WalkSpeed=STATE.WalkSpeed end
    if not STATE.AutoBeachBalls then
        autopilotVec=nil; autopilotSpeed=nil; beachTarget=nil; beachLastDist=1e9; beachStuck=0
        if STATE.Fly then setFly(false) end
        if STATE.Noclip then setNoclip(false) end
        return
    end
    if not STATE.Fly then setFly(true) end
    local root=hrp(LocalPlayer.Character); if not root then return end
    if (not beachTarget) or (not beachTarget.Parent) or (beachTarget:GetAttribute("Collected")==true) then
        beachTarget=nearestBeachBall()
        clearBeachConn()
        if beachTarget then bindBeachTarget(beachTarget) beachLastDist=1e9 beachStuck=0 else autopilotVec=nil autopilotSpeed=nil end
        return
    end
    local pos=beachTarget.Position
    local cur=root.Position
    local dir=(pos-cur)
    local dist=dir.Magnitude
    if not dist or dist~=dist then beachTarget=nil return end
    if dist<4 then
        if typeof(firetouchinterest)=="function" then firetouchinterest(root,beachTarget,0); task.wait(); firetouchinterest(root,beachTarget,1) end
        root.CFrame=CFrame.new(pos+Vector3.new(0,0.4,0))
        beachTarget=nil
        return
    end
    autopilotVec=dir
    autopilotSpeed=math.clamp(dist*0.6, 6, STATE.BeachAutoSpeed)
    if dist>beachLastDist-0.3 then
        beachStuck=beachStuck+dt
        if beachStuck>0.6 then root.CFrame=CFrame.new(root.Position.X,pos.Y+1.2,root.Position.Z); beachStuck=0 end
    else
        beachStuck=0
    end
    beachLastDist=dist
end)

local function sendChat(msg)
    msg=tostring(msg or ""); if msg=="" then return end
    local ok=false
    if TextChatService and TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
        local ch=TextChatService:FindFirstChild("TextChannels"); ch=ch and ch:FindFirstChild("RBXGeneral")
        if ch then ok=pcall(function() ch:SendAsync(msg) end) end
    end
    if not ok then
        local ev=ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents"); ev=ev and ev:FindFirstChild("SayMessageRequest")
        if ev then pcall(function() ev:FireServer(msg,"All") end) end
    end
end

task.spawn(function()
    while true do
        if STATE.AutoChat and STATE.ChatMessage and #STATE.ChatMessage>0 then sendChat(STATE.ChatMessage) end
        task.wait(math.max(5,tonumber(STATE.ChatInterval) or 30))
    end
end)

local TabESP=Window:CreateTab("ESP",4483362458)
local TabPlayer=Window:CreateTab("Player",4483362458)
local TabAuto=Window:CreateTab("Auto",4483362458)

TabESP:CreateSection("General")
TabESP:CreateToggle({Name="All Player Chams",CurrentValue=STATE.PlayerChams,Callback=function(v) STATE.PlayerChams=v; if v then fullRefresh() else disableAllVisuals() end end})
TabESP:CreateToggle({Name="Role ESP",CurrentValue=STATE.RoleESP,Callback=function(v) STATE.RoleESP=v; if v then fullRefresh() else disableAllVisuals() end end})
TabESP:CreateToggle({Name="Name Tags",CurrentValue=STATE.NameTags,Callback=function(v) STATE.NameTags=v; if v then fullRefresh() else if not (STATE.PlayerChams or STATE.RoleESP) then disableAllVisuals() end end end})
TabESP:CreateToggle({Name="Collectible ESP",CurrentValue=STATE.CollectibleESP,Callback=function(v) STATE.CollectibleESP=v; for _,p in ipairs(collectList) do if p and p.Parent then setCollectVisible(p,v) end end end})
TabESP:CreateToggle({Name="BeachBall ESP",CurrentValue=STATE.BeachBallESP,Callback=function(v) STATE.BeachBallESP=v; for _,p in ipairs(beachList) do if p and p.Parent then setCollectVisible(p,v) end end end})

TabPlayer:CreateSection("Movement")
TabPlayer:CreateSlider({Name="WalkSpeed",Range={16,32},Increment=1,Suffix=" stud/s",CurrentValue=STATE.WalkSpeed,Callback=function(v) STATE.WalkSpeed=v; local h=hum(LocalPlayer.Character); if h then h.WalkSpeed=v end end})
TabPlayer:CreateButton({Name="Reset Speed",Callback=function() STATE.WalkSpeed=16; local h=hum(LocalPlayer.Character); if h then h.WalkSpeed=16 end end})
TabPlayer:CreateToggle({Name="Fly",CurrentValue=STATE.Fly,Callback=function(v) setFly(v) end})
TabPlayer:CreateSlider({Name="Fly Speed",Range={10,50},Increment=1,Suffix=" stud/s",CurrentValue=STATE.FlySpeed,Callback=function(v) STATE.FlySpeed=v end})
TabPlayer:CreateToggle({Name="Noclip",CurrentValue=STATE.Noclip,Callback=function(v) setNoclip(v) end})
TabPlayer:CreateToggle({Name="Anti AFK",CurrentValue=STATE.AntiAFK,Callback=function(v) STATE.AntiAFK=v end})

TabAuto:CreateSection("Automation")
TabAuto:CreateToggle({Name="Auto Gun (pickup + equip)",CurrentValue=STATE.AutoGun,Callback=function(v) STATE.AutoGun=v; if v then equipGunNow() end end})
TabAuto:CreateToggle({Name="Auto Collect Beach Balls",CurrentValue=STATE.AutoBeachBalls,Callback=function(v) STATE.AutoBeachBalls=v; if not v then autopilotVec=nil autopilotSpeed=nil beachTarget=nil if STATE.Fly then setFly(false) end if STATE.Noclip then setNoclip(false) end end end})
TabAuto:CreateSlider({Name="BeachBall Auto Speed",Range={6,30},Increment=1,Suffix=" stud/s",CurrentValue=STATE.BeachAutoSpeed,Callback=function(v) STATE.BeachAutoSpeed=v end})

TabAuto:CreateSection("Combat")
TabAuto:CreateToggle({Name="Expand Hitbox",CurrentValue=STATE.ExpandHitbox,Callback=function(v) STATE.ExpandHitbox=v; if v then fullRefresh() else for _,pl in ipairs(Players:GetPlayers()) do if pl~=LocalPlayer and pl.Character then clearHitbox(pl.Character) end end end end})
TabAuto:CreateToggle({Name="Hitbox Only Murder",CurrentValue=STATE.HitboxOnlyMurder,Callback=function(v) STATE.HitboxOnlyMurder=v; if STATE.ExpandHitbox then fullRefresh() end end})
TabAuto:CreateSlider({Name="Hitbox Size",Range={2,30},Increment=0.5,Suffix=" studs",CurrentValue=STATE.HitboxSize,Callback=function(v) STATE.HitboxSize=v; if STATE.ExpandHitbox then fullRefresh() end end})
TabAuto:CreateSlider({Name="Hitbox Height",Range={1.0,3.0},Increment=0.1,Suffix="x",CurrentValue=STATE.HitboxHeight,Callback=function(v) STATE.HitboxHeight=v; if STATE.ExpandHitbox then fullRefresh() end end})

TabAuto:CreateSection("Auto Chat")
TabAuto:CreateToggle({Name="Auto Chat",CurrentValue=STATE.AutoChat,Callback=function(v) STATE.AutoChat=v end})
TabAuto:CreateInput({Name="Chat Message",PlaceholderText="enter message",RemoveTextAfterFocusLost=false,Callback=function(text) STATE.ChatMessage=tostring(text or "") end})
TabAuto:CreateSlider({Name="Interval (s)",Range={5,300},Increment=1,Suffix=" s",CurrentValue=STATE.ChatInterval,Callback=function(v) STATE.ChatInterval=v end})

Rayfield:Notify({Title="Ready",Content="Visible hitbox + no lag, Fly/Noclip turn off when Auto Beach Balls is off",Duration=5})
