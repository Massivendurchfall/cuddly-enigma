-- Arsenal Script – Full GUI, Aimbot + ESP, Target Modes, Mobile Support, Hold/Toggle Auswahl

--// Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local mousemoverel = mousemoverel or (Input and Input.MouseMove)

--// State
local State = {
	Aimbot = {
		Enabled = false,
		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,
		Smoothness = 0.1,
		ThirdPerson = false,
		ThirdPersonSensitivity = 3,
		TriggerKey = "MouseButton2",
		ActivationMode = "Hold",            -- "Hold" oder "Toggle"
		LockPart = "Head",
		TargetMode = "Closest to Crosshair",-- oder "Closest Distance"
		UseFOVInDistanceMode = true,
		Predict = false,
		PredictionTime = 0.12,
		SilentAim = false
	},
	FOV = {
		Enabled = true,
		Visible = true,
		Amount = 90,
		Color = Color3.fromRGB(255,255,255),
		LockedColor = Color3.fromRGB(255,70,70),
		Transparency = 0.5,
		Sides = 60,
		Thickness = 1,
		Filled = false
	},
	ESP = {
		Enabled = false,
		Chams = true,
		NameTags = true,
		TeamColors = true,
		FillColor = Color3.fromRGB(0,170,255),
		OutlineColor = Color3.fromRGB(255,255,255),
		FillTransparency = 0.6,
		OutlineTransparency = 0,
		NameTextColor = Color3.fromRGB(255,255,255),
		NameTextSize = 14,
		ToggleKey = Enum.KeyCode.K
	},
	Settings = {
		MenuKey = Enum.KeyCode.RightShift
	}
}

--// Internal
local Locked, Animation = nil, nil
local OriginalSensitivity = UserInputService.MouseDeltaSensitivity
local Running, Typing = false, false
local ListeningHoldKey, ListeningMenuKey = false, false
local Connections, ESPObjects = {}, {}
local FOVCircle = Drawing.new("Circle")
local IsShooting = false
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

--// Utils
local function toVec2(v) return typeof(v)=="Vector2" and v or Vector2.new(v.X,v.Y) end
local function isAlive(c) local h=c and c:FindFirstChildOfClass("Humanoid") return h and h.Health>0 end
local function sameTeam(a,b) return a and b and a.Team and b.Team==a.Team end
local function cancelTween() if Animation then pcall(function()Animation:Cancel() end) Animation=nil end end
local function CancelLock() Locked=nil cancelTween() FOVCircle.Color=State.FOV.Color UserInputService.MouseDeltaSensitivity=OriginalSensitivity end
local function visibleFromCamera(pos,ignore)
	local p=RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Exclude; p.FilterDescendantsInstances=ignore; p.IgnoreWater=true
	local r=Workspace:Raycast(Camera.CFrame.Position,(pos-Camera.CFrame.Position),p)
	if not r then return true end
	return (r.Position-pos).Magnitude<=1
end

local function normalizeKey(s)
	s=tostring(s or "")
	if s=="MouseButton1" or s=="MouseButton2" or s=="MouseButton3" then return {type="MouseButton",value=s} end
	local kc=Enum.KeyCode[s] or Enum.KeyCode[string.upper(s)]
	if kc then return {type="KeyCode",value=kc} end
	return {type="MouseButton",value="MouseButton2"}
end

local HoldKey = normalizeKey(State.Aimbot.TriggerKey)
local function isHoldKey(input)
	if HoldKey.type=="KeyCode" then
		return input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==HoldKey.value
	else
		return (input.UserInputType==Enum.UserInputType.MouseButton1 and HoldKey.value=="MouseButton1")
			or (input.UserInputType==Enum.UserInputType.MouseButton2 and HoldKey.value=="MouseButton2")
			or (input.UserInputType==Enum.UserInputType.MouseButton3 and HoldKey.value=="MouseButton3")
	end
end

local function predictedPoint(char, part)
	if not State.Aimbot.Predict then return part.Position end
	local hrp=char:FindFirstChild("HumanoidRootPart")
	local v=(hrp and hrp.Velocity) or Vector3.zero
	return part.Position + v * State.Aimbot.PredictionTime
end

--// ESP
local function DestroyESP(plr)
	local o=ESPObjects[plr]
	if not o then return end
	if o.CharAdded then pcall(function()o.CharAdded:Disconnect() end) end
	if o.CharRemoving then pcall(function()o.CharRemoving:Disconnect() end) end
	if o.Highlight then pcall(function()o.Highlight:Destroy() end) end
	if o.Tag then pcall(function()o.Tag:Destroy() end) end
	ESPObjects[plr]=nil
end

local function CreateESP(plr)
	if ESPObjects[plr] then return end
	local t={}
	local function attach(char)
		if not State.ESP.Enabled then return end
		if State.ESP.Chams then
			local h=Instance.new("Highlight")
			h.FillColor = State.ESP.TeamColors and (plr.Team and plr.Team.TeamColor and plr.Team.TeamColor.Color) or State.ESP.FillColor
			h.OutlineColor = State.ESP.OutlineColor
			h.FillTransparency = State.ESP.FillTransparency
			h.OutlineTransparency = State.ESP.OutlineTransparency
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Adornee = char
			h.Parent = char
			t.Highlight=h
		end
		if State.ESP.NameTags then
			local hrp=char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local bg=Instance.new("BillboardGui")
				bg.AlwaysOnTop=true
				bg.Size=UDim2.new(0,200,0,22)
				bg.StudsOffset=Vector3.new(0,3,0)
				bg.Adornee=hrp
				local tl=Instance.new("TextLabel")
				tl.Size=UDim2.new(1,0,1,0)
				tl.BackgroundTransparency=1
				tl.Text=plr.Name
				tl.TextColor3=State.ESP.NameTextColor
				tl.TextSize=State.ESP.NameTextSize
				tl.Font=Enum.Font.GothamBold
				tl.Parent=bg
				bg.Parent=char
				t.Tag=bg
			end
		end
		ESPObjects[plr]=t
	end
	local function cleanup()
		if t.Highlight then pcall(function()t.Highlight:Destroy()end) t.Highlight=nil end
		if t.Tag then pcall(function()t.Tag:Destroy()end) t.Tag=nil end
		ESPObjects[plr]=nil
	end
	t.Cleanup=cleanup
	if plr.Character then attach(plr.Character) end
	t.CharAdded=plr.CharacterAdded:Connect(function(c) task.wait(0.1) attach(c) end)
	t.CharRemoving=plr.CharacterRemoving:Connect(function() cleanup() end)
end

local function RebuildAllESP()
	for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then DestroyESP(p) CreateESP(p) end end
end

for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then CreateESP(p) end end
Players.PlayerAdded:Connect(function(p) if p~=LocalPlayer then CreateESP(p) end end)
Players.PlayerRemoving:Connect(function(p) DestroyESP(p) end)

--// Targeting + Aim
local function GetClosestPlayer()
	local best, bestMetric = nil, math.huge
	local mousePos = UserInputService:GetMouseLocation()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr~=LocalPlayer then
			local char=plr.Character
			if char then
				local part=char:FindFirstChild(State.Aimbot.LockPart)
				if part then
					if not(State.Aimbot.TeamCheck and sameTeam(plr,LocalPlayer))
					and not(State.Aimbot.AliveCheck and not isAlive(char))
					and (not State.Aimbot.WallCheck or visibleFromCamera(part.Position,{LocalPlayer.Character,char,Camera})) then

						if State.Aimbot.TargetMode=="Closest to Crosshair" then
							local v,on = Camera:WorldToViewportPoint(predictedPoint(char,part))
							if on then
								local d=(mousePos-toVec2(v)).Magnitude
								if d<=State.FOV.Amount and d<bestMetric then bestMetric=d best=plr end
							end
						else
							local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
							local dist3 = root and (root.Position - part.Position).Magnitude or math.huge
							if State.Aimbot.UseFOVInDistanceMode then
								local v,on=Camera:WorldToViewportPoint(part.Position)
								if on then
									local scr=(mousePos-toVec2(v)).Magnitude
									if scr<=State.FOV.Amount and dist3<bestMetric then bestMetric=dist3 best=plr end
								end
							else
								if dist3<bestMetric then bestMetric=dist3 best=plr end
							end
						end
					end
				end
			end
		end
	end
	if best then Locked=best else if Locked then CancelLock() end end
end

local function AimAtLocked()
	local l=Locked; if not l then return end
	local char=l.Character; if not char then CancelLock() return end
	local part=char:FindFirstChild(State.Aimbot.LockPart); if not part then CancelLock() return end
	local target = predictedPoint(char,part)
	local v,on=Camera:WorldToViewportPoint(target); if not on then CancelLock() return end

	if State.Aimbot.SilentAim then
		if IsShooting and mousemoverel then
			local m=UserInputService:GetMouseLocation()
			local dx=(v.X-m.X); local dy=(v.Y-m.Y)
			mousemoverel(dx*0.6,dy*0.6)
		end
		return
	end

	if State.Aimbot.ThirdPerson then
		if mousemoverel then
			local m=UserInputService:GetMouseLocation()
			local dx=(v.X-m.X)*State.Aimbot.ThirdPersonSensitivity
			local dy=(v.Y-m.Y)*State.Aimbot.ThirdPersonSensitivity
			mousemoverel(dx,dy)
		end
	else
		local dur=tonumber(State.Aimbot.Smoothness) or 0
		cancelTween()
		if dur>0 then
			Animation=TweenService:Create(Camera,TweenInfo.new(dur,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{CFrame=CFrame.new(Camera.CFrame.Position,target)})
			Animation:Play()
		else
			Camera.CFrame=CFrame.new(Camera.CFrame.Position,target)
		end
		UserInputService.MouseDeltaSensitivity=0
	end
	FOVCircle.Color=State.FOV.LockedColor
end

local function UpdateFOV()
	local f=State.FOV
	if f.Enabled then
		FOVCircle.Visible=f.Visible
		FOVCircle.Radius=f.Amount
		FOVCircle.Thickness=f.Thickness
		FOVCircle.Filled=f.Filled
		FOVCircle.NumSides=f.Sides
		FOVCircle.Color=Locked and f.LockedColor or f.Color
		FOVCircle.Transparency=f.Transparency
		FOVCircle.Position=UserInputService:GetMouseLocation()
	else
		FOVCircle.Visible=false
	end
end

RunService.RenderStepped:Connect(function()
	UpdateFOV()
	if Running and State.Aimbot.Enabled then
		GetClosestPlayer()
		if Locked then
			if State.Aimbot.AliveCheck and not isAlive(Locked.Character) then
				CancelLock()
			else
				AimAtLocked()
			end
		end
	end
end)

--// Input (Hold/Toggle berücksichtigt)
UserInputService.InputBegan:Connect(function(i,g)
	if g or Typing then return end

	if ListeningHoldKey and i.UserInputType==Enum.UserInputType.Keyboard then
		State.Aimbot.TriggerKey=i.KeyCode.Name
		HoldKey=normalizeKey(State.Aimbot.TriggerKey)
		ListeningHoldKey=false
		return
	end
	if ListeningMenuKey and i.UserInputType==Enum.UserInputType.Keyboard then
		State.Settings.MenuKey=i.KeyCode
		ListeningMenuKey=false
		return
	end

	if i.UserInputType==Enum.UserInputType.MouseButton1 then IsShooting=true end

	if isHoldKey(i) then
		if State.Aimbot.ActivationMode=="Hold" then
			Running=true
		else
			Running=not Running
			if not Running then CancelLock() end
		end
	end

	if i.UserInputType==Enum.UserInputType.Keyboard and i.KeyCode==State.ESP.ToggleKey then
		State.ESP.Enabled=not State.ESP.Enabled; RebuildAllESP()
	end
	if i.UserInputType==Enum.UserInputType.Keyboard and i.KeyCode==State.Settings.MenuKey then
		if MainFrame then MainFrame.Visible=not MainFrame.Visible end
	end
end)

UserInputService.InputEnded:Connect(function(i,g)
	if g or Typing then return end
	if i.UserInputType==Enum.UserInputType.MouseButton1 then IsShooting=false end

	if isHoldKey(i) and State.Aimbot.ActivationMode=="Hold" then
		Running=false
		CancelLock()
	end
end)

UserInputService.TextBoxFocused:Connect(function() Typing=true end)
UserInputService.TextBoxFocusReleased:Connect(function() Typing=false end)

--// GUI helpers
local function mk(inst,props,parent) local o=Instance.new(inst) for k,v in pairs(props)do o[k]=v end o.Parent=parent return o end

local ScreenGui = mk("ScreenGui",{Name="ArsenalScriptUI",IgnoreGuiInset=true,ResetOnSpawn=false},game:GetService("CoreGui"))
local MainFrame = mk("Frame",{Size=UDim2.new(0,680,0,460),Position=UDim2.new(0.2,0,0.2,0),BackgroundColor3=Color3.fromRGB(20,20,25),BorderSizePixel=0},ScreenGui)
mk("UICorner",{CornerRadius=UDim.new(0,12)},MainFrame)
local TitleBar = mk("TextLabel",{Size=UDim2.new(1,0,0,36),BackgroundColor3=Color3.fromRGB(28,28,34),Text="Arsenal Script",TextColor3=Color3.new(1,1,1),TextSize=18,Font=Enum.Font.GothamBold},MainFrame)
local Tabs = mk("Frame",{Size=UDim2.new(0,160,1,-36),Position=UDim2.new(0,0,0,36),BackgroundColor3=Color3.fromRGB(28,28,34),BorderSizePixel=0},MainFrame)
local Body = mk("Frame",{Size=UDim2.new(1,-170,1,-50),Position=UDim2.new(0,170,0,45),BackgroundColor3=Color3.fromRGB(24,24,30),BorderSizePixel=0},MainFrame)
mk("UICorner",{CornerRadius=UDim.new(0,10)},Body)
local UIScale = Instance.new("UIScale",MainFrame); UIScale.Scale = isMobile and 0.92 or 1

-- Drag
do
	local dragging=false; local dragStart; local startPos
	TitleBar.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			dragging=true; dragStart=i.Position; startPos=MainFrame.Position
		end
	end)
	TitleBar.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
			local delta=i.Position-dragStart
			MainFrame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
		end
	end)
end

local function TabButton(text,order)
	return mk("TextButton",{Size=UDim2.new(1,0,0,42),Position=UDim2.new(0,0,0,(order-1)*44),Text=text,TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(36,36,44),BorderSizePixel=0},Tabs)
end

local function ClearBody() for _,c in ipairs(Body:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end

local function mkScroll()
	local s=mk("ScrollingFrame",{Size=UDim2.new(1,-20,1,-20),Position=UDim2.new(0,10,0,10),CanvasSize=UDim2.new(0,0,0,0),ScrollBarThickness=6,BackgroundTransparency=1},Body)
	local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.Parent=s
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() s.CanvasSize=UDim2.new(0,0,0,list.AbsoluteContentSize.Y+10) end)
	return s
end

local function Section(parent,text)
	local f=mk("Frame",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1},parent)
	mk("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=16,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1)},f)
	return f
end

local function Toggle(parent,text,default,cb)
	local f=mk("Frame",{Size=UDim2.new(1,0,0,36),BackgroundTransparency=1},parent)
	mk("TextLabel",{Size=UDim2.new(1,-90,1,0),BackgroundTransparency=1,Text=text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1)},f)
	local b=mk("TextButton",{Size=UDim2.new(0,80,1,0),Position=UDim2.new(1,-80,0,0),Text=default and "ON" or "OFF",TextSize=14,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=default and Color3.fromRGB(30,150,85) or Color3.fromRGB(90,90,95),BorderSizePixel=0},f)
	mk("UICorner",{CornerRadius=UDim.new(0,8)},b)
	local state=default
	b.MouseButton1Click:Connect(function() state=not state b.Text=state and "ON" or "OFF" b.BackgroundColor3=state and Color3.fromRGB(30,150,85) or Color3.fromRGB(90,90,95) cb(state) end)
	return f
end

local function Slider(parent,text,min,max,default,decimals,cb)
	local f=mk("Frame",{Size=UDim2.new(1,0,0,40),BackgroundTransparency=1},parent)
	mk("TextLabel",{Size=UDim2.new(1,0,0,18),Text=text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1)},f)
	local bar=mk("Frame",{Size=UDim2.new(1,-10,0,6),Position=UDim2.new(0,5,0,26),BackgroundColor3=Color3.fromRGB(45,45,55),BorderSizePixel=0},f)
	local fill=mk("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=Color3.fromRGB(85,150,255),BorderSizePixel=0},bar)
	local knob=mk("Frame",{Size=UDim2.new(0,12,0,12),Position=UDim2.new(0,0,0.5,-6),BackgroundColor3=Color3.fromRGB(200,200,255),BorderSizePixel=0},bar)
	mk("UICorner",{CornerRadius=UDim.new(0,6)},knob)
	local valLabel=mk("TextLabel",{Size=UDim2.new(0,80,0,18),Position=UDim2.new(1,-80,0,0),BackgroundTransparency=1,Text="",TextSize=13,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1)},f)
	local function clamp(v) if v<min then v=min end if v>max then v=max end return v end
	local function round(v) if not decimals or decimals<=0 then return math.floor(v+0.5) end local m=10^decimals return math.floor(v*m+0.5)/m end
	local function setFromRatio(r) local v=round(clamp(min+(max-min)*r)); fill.Size=UDim2.new(r,0,1,0); knob.Position=UDim2.new(r,-6,0.5,-6); valLabel.Text=tostring(v); cb(v) end
	local start=(default-min)/(max-min); setFromRatio(start)
	local dragging=false
	local function update(x) local abs=bar.AbsoluteSize.X; local off=x-bar.AbsolutePosition.X; local r=math.clamp(off/abs,0,1); setFromRatio(r) end
	bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true update(i.Position.X) end end)
	bar.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
	UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then update(i.Position.X) end end)
	return f
end

local function Dropdown(parent,text,values,default,cb)
	local f=mk("Frame",{Size=UDim2.new(1,0,0,36),BackgroundTransparency=1},parent)
	mk("TextLabel",{Size=UDim2.new(1,-140,1,0),BackgroundTransparency=1,Text=text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1)},f)
	local idx=1 for i,v in ipairs(values) do if v==default then idx=i break end end
	local b=mk("TextButton",{Size=UDim2.new(0,140,1,0),Position=UDim2.new(1,-140,0,0),Text=values[idx],TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),BorderSizePixel=0},f)
	mk("UICorner",{CornerRadius=UDim.new(0,8)},b)
	b.MouseButton1Click:Connect(function() idx=idx%#values+1 b.Text=values[idx] cb(values[idx]) end)
	return f
end

local function Button(parent,text,cb)
	local b=mk("TextButton",{Size=UDim2.new(0,220,0,34),Text=text,TextSize=14,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(60,60,70),BorderSizePixel=0},parent)
	mk("UICorner",{CornerRadius=UDim.new(0,8)},b); b.MouseButton1Click:Connect(cb); return b
end

-- Tabs
local function BuildAimbotTab()
	ClearBody()
	local s=mkScroll()
	Section(s,"Aimbot")
	Toggle(s,"Enabled",State.Aimbot.Enabled,function(v)State.Aimbot.Enabled=v end)
	Dropdown(s,"Activation Mode",{"Hold","Toggle"},State.Aimbot.ActivationMode,function(v)State.Aimbot.ActivationMode=v end)
	Dropdown(s,"Target Mode",{"Closest to Crosshair","Closest Distance"},State.Aimbot.TargetMode,function(v)State.Aimbot.TargetMode=v end)
	Toggle(s,"Use FOV in Distance Mode",State.Aimbot.UseFOVInDistanceMode,function(v)State.Aimbot.UseFOVInDistanceMode=v end)
	Dropdown(s,"Lock Part",{"Head","UpperTorso","HumanoidRootPart"},State.Aimbot.LockPart,function(v)State.Aimbot.LockPart=v end)
	Toggle(s,"Team Check",State.Aimbot.TeamCheck,function(v)State.Aimbot.TeamCheck=v end)
	Toggle(s,"Alive Check",State.Aimbot.AliveCheck,function(v)State.Aimbot.AliveCheck=v end)
	Toggle(s,"Wall Check",State.Aimbot.WallCheck,function(v)State.Aimbot.WallCheck=v end)
	Slider(s,"Smoothness (sec)",0,1,State.Aimbot.Smoothness,2,function(v)State.Aimbot.Smoothness=v end)
	Toggle(s,"Third Person",State.Aimbot.ThirdPerson,function(v)State.Aimbot.ThirdPerson=v end)
	Slider(s,"TP Sensitivity",1,10,State.Aimbot.ThirdPersonSensitivity,0,function(v)State.Aimbot.ThirdPersonSensitivity=v end)
	Toggle(s,"Silent Aim (on shoot)",State.Aimbot.SilentAim,function(v)State.Aimbot.SilentAim=v end)
	Toggle(s,"Predict",State.Aimbot.Predict,function(v)State.Aimbot.Predict=v end)
	Slider(s,"Prediction Time",0,0.5,State.Aimbot.PredictionTime,3,function(v)State.Aimbot.PredictionTime=v end)

	Section(s,"Hold/Toggle Key")
	Button(s,"Set Key (Keyboard)",function()ListeningHoldKey=true end)
	Button(s,"Use MouseButton1",function()State.Aimbot.TriggerKey="MouseButton1" HoldKey=normalizeKey("MouseButton1") end)
	Button(s,"Use MouseB
