local Rayfield=loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local VirtualUser=game:GetService("VirtualUser")

local LocalPlayer=Players.LocalPlayer

local Window=Rayfield:CreateWindow({
    Name="VoiceChat Script",
    LoadingTitle="VoiceChat Script",
    LoadingSubtitle="by jlcfg",
    ConfigurationSaving={Enabled=true,FolderName="RayfieldScript_MicUp",FileName="Config"},
    Discord={Enabled=false,Invite="",RememberJoins=true},
    KeySystem=false
})

local Tabs={
    Player=Window:CreateTab("Player"),
    ESP=Window:CreateTab("ESP"),
    Anim=Window:CreateTab("Animations"),
    Info=Window:CreateTab("Info")
}

local function reEnableMovement()
    local char=LocalPlayer.Character
    if char then
        local root=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChild("Humanoid")
        if root then root.Anchored=false end
        if hum then hum.PlatformStand=false hum.Sit=false end
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum=char:WaitForChild("Humanoid",5)
    if hum then
        Workspace.CurrentCamera.CameraSubject=hum
        Workspace.CurrentCamera.CameraType=Enum.CameraType.Custom
    end
end)

local flySpeed=50
local flyBodyVelocity
local flyBodyGyro
local flyConnection

local function setWalkSpeed(speed)
    local char=LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed=speed
    end
end

function enableFly()
    local char=LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local root=char.HumanoidRootPart
        if not flyBodyVelocity then
            flyBodyVelocity=Instance.new("BodyVelocity",root)
            flyBodyVelocity.MaxForce=Vector3.new(1e5,1e5,1e5)
        end
        if not flyBodyGyro then
            flyBodyGyro=Instance.new("BodyGyro",root)
            flyBodyGyro.MaxTorque=Vector3.new(1e5,1e5,1e5)
        end
        flyBodyGyro.CFrame=root.CFrame
        if not flyConnection then
            flyConnection=RunService.RenderStepped:Connect(function()
                local dir=Vector3.new()
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir+=Workspace.CurrentCamera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir-=Workspace.CurrentCamera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir-=Workspace.CurrentCamera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir+=Workspace.CurrentCamera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir-=Vector3.new(0,1,0) end
                flyBodyVelocity.Velocity=(dir.Magnitude>0 and dir.Unit*flySpeed) or Vector3.new()
                flyBodyGyro.CFrame=Workspace.CurrentCamera.CFrame
            end)
        end
    end
end

local function disableFly()
    if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity=nil end
    if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro=nil end
    if flyConnection then flyConnection:Disconnect() flyConnection=nil end
end

local noclipConn
local function enableNoclip()
    noclipConn=RunService.Stepped:Connect(function()
        local char=LocalPlayer.Character
        if char then
            for _,p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=false end
            end
        end
    end)
end

local function disableNoclip()
    if noclipConn then noclipConn:Disconnect() noclipConn=nil end
end

local function tpVipSeat()
    local map=Workspace:FindFirstChild("Map")
    local poi=map and map:FindFirstChild("POI")
    local vip=poi and poi:FindFirstChild("VipRoom")
    local room=vip and vip:FindFirstChild("Room")
    local deco=room and room:FindFirstChild("Decoration")
    local seatFound=nil
    if deco then
        for _,c in ipairs(deco:GetChildren()) do
            if string.find(c.Name,"Couch") then
                for _,d in ipairs(c:GetDescendants()) do
                    if d:IsA("Seat") then seatFound=d break end
                end
                if seatFound then break end
            end
        end
    end
    local char=LocalPlayer.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if seatFound and hrp and hum then
        hrp.CFrame=seatFound.CFrame+Vector3.new(0,2,0)
        pcall(function() seatFound:Sit(hum) end)
        Rayfield:Notify({Title="Teleport",Content="Teleported to VIP seat.",Duration=5})
    else
        Rayfield:Notify({Title="Teleport",Content="VIP seat not found.",Duration=6})
    end
end

Tabs.Player:CreateParagraph({Title="Player Controls",Content=" "})
Tabs.Player:CreateSlider({Name="Walk Speed",Range={0,150},Increment=1,Suffix="Speed",CurrentValue=16,Flag="WalkSpeed",Callback=function(v) setWalkSpeed(v) end})
Tabs.Player:CreateToggle({Name="Fly",CurrentValue=false,Flag="Fly",Callback=function(s) if s then enableFly() else disableFly() end end})
Tabs.Player:CreateSlider({Name="Fly Speed",Range={0,300},Increment=1,Suffix="Speed",CurrentValue=50,Flag="FlySpeed",Callback=function(v) flySpeed=v end})
Tabs.Player:CreateToggle({Name="Noclip",CurrentValue=false,Flag="Noclip",Callback=function(s) if s then enableNoclip() else disableNoclip() end end})
Tabs.Player:CreateButton({Name="Teleport VIP-Sitz",Callback=function() tpVipSeat() end})

local antiAfkConn
Tabs.Player:CreateToggle({
    Name="Anti AFK",
    CurrentValue=false,
    Flag="AntiAFK",
    Callback=function(s)
        if s and not antiAfkConn then
            antiAfkConn=LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        elseif not s and antiAfkConn then
            antiAfkConn:Disconnect()
            antiAfkConn=nil
        end
    end
})

local chamsActive=false
local chamsColor=Color3.new(1,1,1)
local chamsTask
local ChamsPerPlayer={}
local CharAddedConns={}
local PlayerAddedConn
local PlayerRemovingConn

local function removeChamsFor(player)
    if ChamsPerPlayer[player] and ChamsPerPlayer[player].hl then
        ChamsPerPlayer[player].hl:Destroy()
    end
    ChamsPerPlayer[player]=nil
    if CharAddedConns[player] then
        for _,c in ipairs(CharAddedConns[player]) do c:Disconnect() end
        CharAddedConns[player]=nil
    end
end

local function attachHighlightToCharacter(player,character)
    if not character or not character:IsDescendantOf(game) then return end
    if player==LocalPlayer then return end
    local hl=character:FindFirstChild("ChamHighlight")
    if not hl then
        hl=Instance.new("Highlight")
        hl.Name="ChamHighlight"
        hl.Adornee=character
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency=0.5
        hl.OutlineTransparency=0
        hl.Parent=character
    end
    hl.FillColor=chamsColor
    hl.OutlineColor=chamsColor
    ChamsPerPlayer[player]=ChamsPerPlayer[player] or {}
    ChamsPerPlayer[player].hl=hl
end

local function trackPlayer(player)
    if player==LocalPlayer then return end
    local a=player.Character or player.CharacterAdded:Wait()
    attachHighlightToCharacter(player,a)
    CharAddedConns[player]=CharAddedConns[player] or {}
    table.insert(CharAddedConns[player],player.CharacterAdded:Connect(function(nc)
        task.wait(0.15)
        attachHighlightToCharacter(player,nc)
    end))
    table.insert(CharAddedConns[player],player.CharacterRemoving:Connect(function()
        removeChamsFor(player)
    end))
end

local function enableChams()
    if chamsTask then return end
    for _,p in ipairs(Players:GetPlayers()) do task.spawn(trackPlayer,p) end
    PlayerAddedConn=Players.PlayerAdded:Connect(function(p) task.spawn(trackPlayer,p) end)
    PlayerRemovingConn=Players.PlayerRemoving:Connect(function(p) removeChamsFor(p) end)
    chamsTask=task.spawn(function()
        while chamsActive do
            for p,info in pairs(ChamsPerPlayer) do
                if p and p.Character and info.hl and info.hl.Parent then
                    info.hl.FillColor=chamsColor
                    info.hl.OutlineColor=chamsColor
                    info.hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                end
            end
            task.wait(0.25)
        end
    end)
end

local function disableChams()
    if chamsTask then task.cancel(chamsTask) chamsTask=nil end
    if PlayerAddedConn then PlayerAddedConn:Disconnect() PlayerAddedConn=nil end
    if PlayerRemovingConn then PlayerRemovingConn:Disconnect() PlayerRemovingConn=nil end
    for p,_ in pairs(ChamsPerPlayer) do removeChamsFor(p) end
end

Tabs.ESP:CreateParagraph({Title="ESP",Content=" "})
Tabs.ESP:CreateToggle({Name="Chams",CurrentValue=false,Flag="Chams",Callback=function(s) chamsActive=s if s then enableChams() else disableChams() end end})
Tabs.ESP:CreateColorPicker({Name="Chams Color",Color=chamsColor,Flag="ChamsColor",Callback=function(c) chamsColor=c end})

local nametagsActive=false
local nametagTask

local function createNametag(p)
    local bill=Instance.new("BillboardGui")
    bill.Name="Nametag"
    bill.Size=UDim2.new(0,50,0,50)
    bill.StudsOffset=Vector3.new(0,2.2,0)
    bill.AlwaysOnTop=true
    local frame=Instance.new("Frame",bill)
    frame.Size=UDim2.new(1,0,1,0)
    frame.BackgroundTransparency=1
    local lbl=Instance.new("TextLabel",frame)
    lbl.Size=UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency=1
    lbl.Text=p.Name
    lbl.TextScaled=false
    lbl.TextSize=14
    lbl.Font=Enum.Font.GothamBold
    lbl.TextColor3=chamsColor
    lbl.TextStrokeTransparency=0.3
    return bill
end

local function updateNametagsOnce()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
            local head=p.Character.Head
            local tag=head:FindFirstChild("Nametag")
            if not tag then
                tag=createNametag(p)
                tag.Parent=head
            else
                local lbl=tag:FindFirstChildWhichIsA("TextLabel",true)
                if lbl then lbl.TextColor3=chamsColor end
            end
        end
    end
end

Tabs.ESP:CreateToggle({
    Name="Nametags",
    CurrentValue=false,
    Flag="Nametags",
    Callback=function(s)
        nametagsActive=s
        if s then
            if nametagTask then task.cancel(nametagTask) end
            nametagTask=task.spawn(function()
                while nametagsActive do
                    updateNametagsOnce()
                    task.wait(0.3)
                end
            end)
        else
            if nametagTask then task.cancel(nametagTask) nametagTask=nil end
            for _,p in ipairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("Head") then
                    local tag=p.Character.Head:FindFirstChild("Nametag")
                    if tag then tag:Destroy() end
                end
            end
        end
    end
})

local SkeletonConnections={
    {"Head","UpperTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"UpperTorso","LowerTorso"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
}
local skeletonESPEnabled=false
local skeletonESPColor=Color3.new(1,0,0)
local SkeletonESPs={}
local skeletonTask

local function createSkeletonForPlayer(player)
    local drawings={}
    for i=1,#SkeletonConnections do
        local line=Drawing.new("Line")
        line.Visible=true
        line.Transparency=1
        line.Color=skeletonESPColor
        line.Thickness=2
        drawings[i]=line
    end
    SkeletonESPs[player]=drawings
end

local function updateSkeletonESP(player)
    if not SkeletonESPs[player] then createSkeletonForPlayer(player) end
    local drawings=SkeletonESPs[player]
    local char=player.Character
    if char then
        for i,conn in ipairs(SkeletonConnections) do
            local partA=char:FindFirstChild(conn[1])
            local partB=char:FindFirstChild(conn[2])
            if partA and partB then
                local a,onA=Workspace.CurrentCamera:WorldToViewportPoint(partA.Position)
                local b,onB=Workspace.CurrentCamera:WorldToViewportPoint(partB.Position)
                if onA and onB then
                    local line=drawings[i]
                    line.Visible=true
                    line.From=Vector2.new(a.X,a.Y)
                    line.To=Vector2.new(b.X,b.Y)
                    line.Color=skeletonESPColor
                else
                    drawings[i].Visible=false
                end
            else
                drawings[i].Visible=false
            end
        end
    end
end

local function enableSkeletonESP()
    if skeletonTask then return end
    skeletonTask=task.spawn(function()
        while skeletonESPEnabled do
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character then
                    updateSkeletonESP(p)
                end
            end
            task.wait(0.05)
        end
        for _,lines in pairs(SkeletonESPs) do for _,l in ipairs(lines) do l:Remove() end end
        SkeletonESPs={}
    end)
end

local function disableSkeletonESP()
    skeletonESPEnabled=false
    if skeletonTask then task.cancel(skeletonTask) skeletonTask=nil end
    for _,lines in pairs(SkeletonESPs) do for _,l in ipairs(lines) do l:Remove() end end
    SkeletonESPs={}
end

Tabs.ESP:CreateToggle({
    Name="Skeleton ESP (fast)",
    CurrentValue=false,
    Flag="SkeletonESP",
    Callback=function(s)
        if s then
            skeletonESPEnabled=true
            enableSkeletonESP()
        else
            disableSkeletonESP()
        end
    end
})
Tabs.ESP:CreateColorPicker({Name="Skeleton Color",Color=skeletonESPColor,Flag="SkeletonColor",Callback=function(c) skeletonESPColor=c end})

Tabs.Info:CreateParagraph({Title="Info",Content="★ Made by jlcfg ★\nDiscord: jlcfg\nhttps://discord.gg/2xDHnGg6J"})

Rayfield:Notify({Title="VoiceChat Script",Content="Script loaded! jlcfg on discord",Duration=12})
Rayfield:LoadConfiguration()

local Packs={
    Astronaut={run={891636393},walk={891636393},jump={891627522},idle={891621366,891633237,1047759695},fall={891617961},swim={891639666},swimidle={891663592},climb={891609353}},
    Bubbly={run={910025107},walk={910034870},jump={910016857},idle={910004836,910009958,1018536639},fall={910001910},swim={910028158},swimidle={910030921},climb={909997997}},
    Cartoony={run={742638842},walk={742640026},jump={742637942},idle={742637544,742638445,885477856},fall={742637151},swim={742639220},swimidle={742639812},climb={742636889}},
    Elder={run={845386501},walk={845403856},jump={845398858},idle={845397899,845400520,901160519},fall={845396048},swim={845401742},swimidle={845403127},climb={845392038}},
    Knight={run={657564596},walk={657552124},jump={658409194},idle={657595757,657568135,885499184},fall={657600338},swim={657560551},swimidle={657557095},climb={658360781}},
    Levitation={run={616010382},walk={616013216},jump={616008936},idle={616006778,616008087,886862142},fall={616005863},swim={616011509},swimidle={616012453},climb={616003713}},
    Mage={run={707861613},walk={707897309},jump={707853694},idle={707742142,707855907,885508740},fall={707829716},swim={707876443},swimidle={707894699},climb={707826056}},
    Ninja={run={656118852},walk={656121766},jump={656117878},idle={656117400,656118341,886742569},fall={656115606},swim={656119721},swimidle={656121397},climb={656114359}},
    Pirate={run={750783738},walk={750785693},jump={750782230},idle={750781874,750782770,885515365},fall={750780242},swim={750784579},swimidle={750785176},climb={750779899}},
    Robot={run={616091570},walk={616095330},jump={616090535},idle={616088211,616089559,885531463},fall={616087089},swim={616092998},swimidle={616094091},climb={616086039}},
    Rthro={run={2510198475},walk={2510202577},jump={2510197830},idle={2510197257,2510196951,3711062489},fall={2510195892},swim={2510199791},swimidle={2510201162},climb={2510192778}},
    Stylish={run={616140816},walk={616146177},jump={616139451},idle={616136790,616138447,886888594},fall={616134815},swim={616143378},swimidle={616144772},climb={616133594}},
    Superhero={run={616117076},walk={616122287},jump={616115533},idle={616111295,616113536,885535855},fall={616108001},swim={616119360},swimidle={616120861},climb={616104706}},
    Toy={run={782842708},walk={782843345},jump={782847020},idle={782841498,782845736,980952228},fall={782846423},swim={782844582},swimidle={782845186},climb={782843869}},
    Vampire={run={1083462077},walk={1083473930},jump={1083455352},idle={1083445855,1083450166,1088037547},fall={1083443587},swim={1083464683},swimidle={1083467779},climb={1083439238}},
    Werewolf={run={1083216690},walk={1083178339},jump={1083218792},idle={1083195517,1083214717,1099492820},fall={1083189019},swim={1083222527},swimidle={1083225406},climb={1083182000}},
    Zombie={run={616163682},walk={616168032},jump={616161997},idle={616158929,616160636,885545458},fall={616157476},swim={616165109},swimidle={616166655},climb={616156119}},
    ["Confident Animation Pack"]={
        run={1070001516},walk={1070017263},jump={1069984524},
        idle={1069977950,1069987858},fall={1069973677},
        swim={1070009914},swimidle={1070012133},climb={1069946257}
    },
    ["Popstar Animation Pack"]={
        run={1212980348},walk={1212980338},jump={1212954642},
        idle={1212900985,1212954651},fall={1212900995},
        swim={1212852603},swimidle={1212998578},climb={1213044953,1213044939}
    },
    ["Patrol Animation Pack"]={
        run={1150967949},walk={1151231493},jump={1150944216},
        idle={1149612882,1150842221},fall={1148863382},
        swim={1151204998},swimidle={1151221899},climb={1148811837}
    },
    ["Sneaky Animation Pack"]={
        run={1132494274},walk={1132510133},jump={1132489853},
        idle={1132473842,1132477671},fall={1132469004},
        swim={1132500520},swimidle={1132506407},climb={1132461372}
    },
    ["Princess Animation Pack"]={
        run={941015281},walk={941028902},jump={941008832},
        idle={941003647,941013098},fall={941000007},
        swim={941018893},swimidle={941025398},climb={940996062}
    },
    ["Cowboy Animation Pack"]={
        run={1014401683},walk={1014421541},jump={1014394726},
        idle={1014390418,1014398616},fall={1014384571},
        swim={1014406523},swimidle={1014411816},climb={1014380606}
    },
    ["Stylized Female"]={
        run={4708192705},walk={4708193840},jump={4708188025},
        idle={4708191566,4708192150},fall={4708186162},
        swim={4708189360},swimidle={4708190607},climb={4708184253}
    }
}

local AnimSelection={pack="Zombie",idle=nil,walk=nil,run=nil,jump=nil,fall=nil,climb=nil,swim=nil,swimidle=nil}
local AppliedIds={idle="",walk="",run="",jump="",fall="",climb="",swim="",swimidle=""}
local OriginalIds={idle="",walk="",run="",jump="",fall="",climb="",swim="",swimidle=""}
local OriginalIdsCaptured=false
local EmoteTrack=nil
local EmoteLoop=false
local EmoteSpeed=1
local ReapplyOnRespawn=true

local function getAnimateScript()
    local c=LocalPlayer.Character
    if not c then return nil end
    return c:FindFirstChild("Animate")
end

local function setAnimIdOnContainer(container,assetId)
    for _,a in ipairs(container:GetChildren()) do
        if a:IsA("Animation") then
            a.AnimationId="rbxassetid://"..tostring(assetId)
        end
    end
end

local function applyToAnimate(anim,ids)
    if not anim then return end
    if ids.idle~="" and anim:FindFirstChild("idle") then setAnimIdOnContainer(anim.idle,ids.idle) end
    if ids.walk~="" and anim:FindFirstChild("walk") then setAnimIdOnContainer(anim.walk,ids.walk) end
    if ids.run~="" and anim:FindFirstChild("run") then setAnimIdOnContainer(anim.run,ids.run) end
    if ids.jump~="" and anim:FindFirstChild("jump") then setAnimIdOnContainer(anim.jump,ids.jump) end
    if ids.fall~="" and anim:FindFirstChild("fall") then setAnimIdOnContainer(anim.fall,ids.fall) end
    if ids.climb~="" and anim:FindFirstChild("climb") then setAnimIdOnContainer(anim.climb,ids.climb) end
    if ids.swim~="" and anim:FindFirstChild("swim") then setAnimIdOnContainer(anim.swim,ids.swim) end
    if ids.swimidle~="" and anim:FindFirstChild("swimidle") then setAnimIdOnContainer(anim.swimidle,ids.swimidle) end
end

local function refreshHumanoidState()
    local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _,t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end
    hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
    task.wait()
    hum:ChangeState(Enum.HumanoidStateType.Running)
end

local function captureOriginalIds()
    if OriginalIdsCaptured then return end
    local char=LocalPlayer.Character
    if not char then return end
    local anim=char:FindFirstChild("Animate")
    if not anim then return end
    local function extract(container)
        if not container then return "" end
        for _,a in ipairs(container:GetChildren()) do
            if a:IsA("Animation") and a.AnimationId~="" then
                local num=a.AnimationId:match("(%d+)")
                if num then return num end
            end
        end
        return ""
    end
    OriginalIds.idle=extract(anim:FindFirstChild("idle"))
    OriginalIds.walk=extract(anim:FindFirstChild("walk"))
    OriginalIds.run=extract(anim:FindFirstChild("run"))
    OriginalIds.jump=extract(anim:FindFirstChild("jump"))
    OriginalIds.fall=extract(anim:FindFirstChild("fall"))
    OriginalIds.climb=extract(anim:FindFirstChild("climb"))
    OriginalIds.swim=extract(anim:FindFirstChild("swim"))
    OriginalIds.swimidle=extract(anim:FindFirstChild("swimidle"))
    OriginalIdsCaptured=true
end

local function applyAnimOverridesReliable()
    local char=LocalPlayer.Character
    if not char then return end
    captureOriginalIds()
    local anim=char:FindFirstChild("Animate") or char:WaitForChild("Animate",10)
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not anim or not hum then return end
    local animator=hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator",3)
    if not animator then return end
    applyToAnimate(anim,AppliedIds)
    task.wait(0.05)
    refreshHumanoidState()
end

local function resetToOriginal()
    local char=LocalPlayer.Character
    if not char then return end
    if not OriginalIdsCaptured then
        captureOriginalIds()
    end
    local anim=char:FindFirstChild("Animate") or char:WaitForChild("Animate",10)
    if not anim then return end
    applyToAnimate(anim,OriginalIds)
    task.wait(0.05)
    refreshHumanoidState()
end

LocalPlayer.CharacterAdded:Connect(function(char)
    if ReapplyOnRespawn then
        task.spawn(function()
            local anim=char:WaitForChild("Animate",10)
            local hum=char:WaitForChild("Humanoid",10)
            if anim and hum then
                task.wait(0.15)
                applyAnimOverridesReliable()
            end
        end)
    end
end)

local function populateFromPack(pack)
    local p=Packs[pack]; if not p then return end
    AnimSelection.pack=pack
    AnimSelection.idle=p.idle[1] or nil
    AnimSelection.walk=p.walk[1] or nil
    AnimSelection.run=p.run[1] or nil
    AnimSelection.jump=p.jump[1] or nil
    AnimSelection.fall=p.fall[1] or nil
    AnimSelection.climb=p.climb[1] or nil
    AnimSelection.swim=p.swim[1] or nil
    AnimSelection.swimidle=p.swimidle[1] or nil
end

local function rebuildAppliedIds()
    AppliedIds.idle=AnimSelection.idle and tostring(AnimSelection.idle) or ""
    AppliedIds.walk=AnimSelection.walk and tostring(AnimSelection.walk) or ""
    AppliedIds.run=AnimSelection.run and tostring(AnimSelection.run) or ""
    AppliedIds.jump=AnimSelection.jump and tostring(AnimSelection.jump) or ""
    AppliedIds.fall=AnimSelection.fall and tostring(AnimSelection.fall) or ""
    AppliedIds.climb=AnimSelection.climb and tostring(AnimSelection.climb) or ""
    AppliedIds.swim=AnimSelection.swim and tostring(AnimSelection.swim) or ""
    AppliedIds.swimidle=AnimSelection.swimidle and tostring(AnimSelection.swimidle) or ""
end

populateFromPack(AnimSelection.pack)
rebuildAppliedIds()

local function buildGlobalStateMaps()
    local maps={idle={},walk={},run={},jump={},fall={},climb={},swim={},swimidle={}}
    local lists={idle={},walk={},run={},jump={},fall={},climb={},swim={},swimidle={}}
    for packName,pack in pairs(Packs) do
        for _,id in ipairs(pack.idle or {}) do local key=tostring(id).." ("..packName..")"; maps.idle[key]=id table.insert(lists.idle,key) end
        for _,id in ipairs(pack.walk or {}) do local key=tostring(id).." ("..packName..")"; maps.walk[key]=id table.insert(lists.walk,key) end
        for _,id in ipairs(pack.run or {}) do local key=tostring(id).." ("..packName..")"; maps.run[key]=id table.insert(lists.run,key) end
        for _,id in ipairs(pack.jump or {}) do local key=tostring(id).." ("..packName..")"; maps.jump[key]=id table.insert(lists.jump,key) end
        for _,id in ipairs(pack.fall or {}) do local key=tostring(id).." ("..packName..")"; maps.fall[key]=id table.insert(lists.fall,key) end
        for _,id in ipairs(pack.climb or {}) do local key=tostring(id).." ("..packName..")"; maps.climb[key]=id table.insert(lists.climb,key) end
        for _,id in ipairs(pack.swim or {}) do local key=tostring(id).." ("..packName..")"; maps.swim[key]=id table.insert(lists.swim,key) end
        for _,id in ipairs(pack.swimidle or {}) do local key=tostring(id).." ("..packName..")"; maps.swimidle[key]=id table.insert(lists.swimidle,key) end
    end
    local function sortList(t)
        table.sort(t,function(a,b)
            local na=tonumber(a:match("^(%d+)")) or 0
            local nb=tonumber(b:match("^(%d+)")) or 0
            if na==nb then return a<b else return na<nb end
        end)
    end
    for _,v in pairs(lists) do sortList(v) end
    return maps,lists
end

local StateMap,StateList=buildGlobalStateMaps()

local function labelFor(state,id)
    local target=tostring(id or "")
    for _,label in ipairs(StateList[state]) do
        if label:match("^"..target.." ") then return label end
    end
    return StateList[state][1]
end

Tabs.Anim:CreateButton({
    Name="here you find all IDs",
    Callback=function()
        local ok=false
        if typeof(setclipboard)=="function" then
            pcall(function()
                setclipboard("https://create.roblox.com/docs/animation/using#catalog-animations")
                ok=true
            end)
        end
        Rayfield:Notify({Title="Animations",Content=ok and "Link copied." or "Clipboard not available.",Duration=5})
    end
})

Tabs.Anim:CreateButton({
    Name="emote marketplace",
    Callback=function()
        local ok=false
        if typeof(setclipboard)=="function" then
            pcall(function()
                setclipboard("https://www.roblox.com/catalog?Category=12")
                ok=true
            end)
        end
        Rayfield:Notify({Title="Emotes",Content=ok and "Marketplace link copied. Copy IDs from there and paste below." or "Clipboard not available.",Duration=6})
    end
})

Tabs.Anim:CreateParagraph({Title="Tip",Content="Open the Emote marketplace, copy the numeric ID from the URL, and paste below to play."})

local packNames=(function() local t={} for k,_ in pairs(Packs) do table.insert(t,k) end table.sort(t) return t end)()

Tabs.Anim:CreateDropdown({
    Name="Pack",
    Options=packNames,
    CurrentOption=AnimSelection.pack,
    Flag="PackPick",
    Callback=function(v)
        local name=typeof(v)=="table" and v[1] or v
        populateFromPack(name)
        rebuildAppliedIds()
    end
})

local function onPick(state,label)
    local id=StateMap[state][typeof(label)=="table" and label[1] or label]
    if id then
        AnimSelection[state]=tonumber(id)
        rebuildAppliedIds()
    end
end

ddIdle=Tabs.Anim:CreateDropdown({Name="Idle",Options=StateList.idle,CurrentOption=labelFor("idle",Packs[AnimSelection.pack].idle[1]),Flag="IdlePick",Callback=function(v) onPick("idle",v) end})
ddWalk=Tabs.Anim:CreateDropdown({Name="Walk",Options=StateList.walk,CurrentOption=labelFor("walk",Packs[AnimSelection.pack].walk[1]),Flag="WalkPick",Callback=function(v) onPick("walk",v) end})
ddRun=Tabs.Anim:CreateDropdown({Name="Run",Options=StateList.run,CurrentOption=labelFor("run",Packs[AnimSelection.pack].run[1]),Flag="RunPick",Callback=function(v) onPick("run",v) end})
ddJump=Tabs.Anim:CreateDropdown({Name="Jump",Options=StateList.jump,CurrentOption=labelFor("jump",Packs[AnimSelection.pack].jump[1]),Flag="JumpPick",Callback=function(v) onPick("jump",v) end})
ddFall=Tabs.Anim:CreateDropdown({Name="Fall",Options=StateList.fall,CurrentOption=labelFor("fall",Packs[AnimSelection.pack].fall[1]),Flag="FallPick",Callback=function(v) onPick("fall",v) end})
ddClimb=Tabs.Anim:CreateDropdown({Name="Climb",Options=StateList.climb,CurrentOption=labelFor("climb",Packs[AnimSelection.pack].climb[1]),Flag="ClimbPick",Callback=function(v) onPick("climb",v) end})
ddSwim=Tabs.Anim:CreateDropdown({Name="Swim",Options=StateList.swim,CurrentOption=labelFor("swim",Packs[AnimSelection.pack].swim[1]),Flag="SwimPick",Callback=function(v) onPick("swim",v) end})
ddSwimIdle=Tabs.Anim:CreateDropdown({Name="Swim Idle",Options=StateList.swimidle,CurrentOption=labelFor("swimidle",Packs[AnimSelection.pack].swimidle[1]),Flag="SwimIdlePick",Callback=function(v) onPick("swimidle",v) end})

Tabs.Anim:CreateButton({Name="Apply Overrides",Callback=function() applyAnimOverridesReliable() Rayfield:Notify({Title="Animations",Content="Applied.",Duration=5}) end})
Tabs.Anim:CreateButton({Name="Reset default animations",Callback=function() resetToOriginal() Rayfield:Notify({Title="Animations",Content="Reset to default.",Duration=5}) end})
Tabs.Anim:CreateToggle({Name="Reapply on respawn",CurrentValue=true,Flag="ReapplyRespawn",Callback=function(v) ReapplyOnRespawn=v end})

local EmoteIdInput=""
local EmoteSpeedValue=1
EmoteTrack=nil
EmoteLoop=false

local function getAnimator()
    local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local an=hum:FindFirstChildOfClass("Animator")
    if not an then an=Instance.new("Animator") an.Parent=hum end
    return an
end

local function resolveAnimationFromAsset(assetId)
    local ok,obj=pcall(function() return game:GetObjects("rbxassetid://"..tostring(assetId))[1] end)
    if not ok or not obj then return nil end
    if obj:IsA("Animation") then return obj end
    local anim=obj:FindFirstChildWhichIsA("Animation",true)
    if anim then return anim end
    if obj:IsA("KeyframeSequence") then
        local a=Instance.new("Animation"); a.AnimationId="rbxassetid://"..tostring(assetId); return a
    end
    return nil
end

local function playEmoteAsset(assetId,loop,speed)
    local an=getAnimator(); if not an then return end
    if EmoteTrack then pcall(function() EmoteTrack:Stop() EmoteTrack:Destroy() end) EmoteTrack=nil end
    local anim=resolveAnimationFromAsset(assetId)
    if not anim then Rayfield:Notify({Title="Emote",Content="Could not load asset.",Duration=5}); return end
    local track=an:LoadAnimation(anim)
    track:Play(0.1,1,1)
    track:AdjustSpeed(speed or 1)
    EmoteTrack=track
    if loop then
        EmoteLoop=true
        task.spawn(function()
            while EmoteLoop and EmoteTrack do
                if not EmoteTrack.IsPlaying then pcall(function() EmoteTrack:Play(0.1,1,1) EmoteTrack:AdjustSpeed(speed or 1) end) end
                task.wait(0.25)
            end
        end)
    else
        EmoteLoop=false
    end
end

local function stopEmote()
    EmoteLoop=false
    if EmoteTrack then pcall(function() EmoteTrack:Stop() EmoteTrack:Destroy() end) EmoteTrack=nil end
end

Tabs.Anim:CreateParagraph({Title="Play Emote by Catalog ID",Content="Copy the numeric ID from an emote URL and paste below."})
Tabs.Anim:CreateInput({Name="Catalog ID",PlaceholderText="e.g. 74308052301228",RemoveTextAfterFocusLost=false,Callback=function(v) EmoteIdInput=tostring(v or "") end})
Tabs.Anim:CreateSlider({Name="Emote Speed",Range={0.1,3},Increment=0.1,Suffix="x",CurrentValue=1,Flag="EmoteSpeed",Callback=function(v) EmoteSpeedValue=v end})
Tabs.Anim:CreateToggle({Name="Loop",CurrentValue=false,Flag="EmoteLoop",Callback=function(v) EmoteLoop=v end})
Tabs.Anim:CreateButton({
    Name="Play Emote",
    Callback=function()
        if EmoteIdInput~="" then
            playEmoteAsset(EmoteIdInput,EmoteLoop,EmoteSpeedValue)
        else
            Rayfield:Notify({Title="Emote",Content="Please enter a valid ID first.",Duration=5})
        end
    end
})
Tabs.Anim:CreateButton({
    Name="Stop Emote",
    Callback=function()
        stopEmote()
        Rayfield:Notify({Title="Emote",Content="Emote stopped.",Duration=4})
    end
})
