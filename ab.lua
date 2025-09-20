local LaufDienst = game:GetService("RunService")
local EingabeDienst = game:GetService("UserInputService")
local KontextAktion = game:GetService("ContextActionService")
local TweenDienst = game:GetService("TweenService")
local SpielerDienst = game:GetService("Players")
local Arbeitsbereich = game:GetService("Workspace")
local LokalerSpieler = SpielerDienst.LocalPlayer
local Kamera = Arbeitsbereich.CurrentCamera
local MausBewegungRel = mousemoverel or (Input and Input.MouseMove)

local Zustand = {
	Aimbot = {
		Aktiv = false,
		TeamCheck = false,
		LebendCheck = true,
		WandCheck = false,
		Weichheit = 0.1,
		DrittePerson = false,
		DrittePersonEmpfindlichkeit = 3,
		AusloeseTaste = "MouseButton2",
		AktivierungsModus = "Hold",
		ZielTeil = "Head",
		ZielModus = "Naechste zum Fadenkreuz",
		FOVInDistanzModus = true,
		Prognose = false,
		PrognoseZeit = 0.12,
		SilentAim = false
	},
	FOV = {
		Aktiv = true,
		Sichtbar = true,
		Betrag = 90,
		Farbe = Color3.fromRGB(255,255,255),
		GesperrtFarbe = Color3.fromRGB(255,70,70),
		Transparenz = 0.5,
		Seiten = 60,
		Dicke = 1,
		Gefuellt = false
	},
	ESP = {
		Aktiv = false,
		Chams = true,
		Namensschilder = true,
		TeamFarben = true,
		FuellFarbe = Color3.fromRGB(0,170,255),
		UmrissFarbe = Color3.fromRGB(255,255,255),
		FuellTransparenz = 0.6,
		UmrissTransparenz = 0,
		NamenFarbe = Color3.fromRGB(255,255,255),
		NamenGroesse = 14
	},
	Einstellungen = {
		MenueTaste = Enum.KeyCode.F1
	}
}

local Gesperrt, Animation = nil, nil
local OriginalEmpfindlichkeit = EingabeDienst.MouseDeltaSensitivity
local Laeuft, Tippen = false, false
local HoereAusloeseKey = false
local Verbindungen, ESPObjekte = {}, {}
local FOVKreis = Drawing.new("Circle")
local Schiesst = false
local IstMobil = EingabeDienst.TouchEnabled and not EingabeDienst.KeyboardEnabled

local function V2(v) return typeof(v)=="Vector2" and v or Vector2.new(v.X,v.Y) end
local function Lebendig(c) local h=c and c:FindFirstChildOfClass("Humanoid") return h and h.Health>0 end
local function GleichesTeam(a,b) return a and b and a.Team and b.Team==a.Team end
local function StoppTween() if Animation then pcall(function()Animation:Cancel() end) Animation=nil end end
local function AbbrechenLock() Gesperrt=nil StoppTween() FOVKreis.Color=Zustand.FOV.Farbe EingabeDienst.MouseDeltaSensitivity=OriginalEmpfindlichkeit end
local function SichtbarVonKamera(pos,ign)
	local p=RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Exclude; p.FilterDescendantsInstances=ign; p.IgnoreWater=true
	local r=Arbeitsbereich:Raycast(Kamera.CFrame.Position,(pos-Kamera.CFrame.Position),p)
	if not r then return true end
	return (r.Position-pos).Magnitude<=1
end

local function NormiereTaste(s)
	s=tostring(s or "")
	if s=="MouseButton1" or s=="MouseButton2" or s=="MouseButton3" then return {typ="Maus",wert=s} end
	local kc=Enum.KeyCode[s] or Enum.KeyCode[string.upper(s)]
	if kc then return {typ="Taste",wert=kc} end
	return {typ="Maus",wert="MouseButton2"}
end

local HalteTaste = NormiereTaste(Zustand.Aimbot.AusloeseTaste)
local function IstHalteTaste(input)
	if HalteTaste.typ=="Taste" then
		return input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==HalteTaste.wert
	else
		return (input.UserInputType==Enum.UserInputType.MouseButton1 and HalteTaste.wert=="MouseButton1")
			or (input.UserInputType==Enum.UserInputType.MouseButton2 and HalteTaste.wert=="MouseButton2")
			or (input.UserInputType==Enum.UserInputType.MouseButton3 and HalteTaste.wert=="MouseButton3")
	end
end

local function PrognosePunkt(char, teil)
	if not Zustand.Aimbot.Prognose then return teil.Position end
	local hrp=char:FindFirstChild("HumanoidRootPart")
	local v=(hrp and hrp.Velocity) or Vector3.zero
	return teil.Position + v * Zustand.Aimbot.PrognoseZeit
end

local function ZerstoereESP(plr)
	local o=ESPObjekte[plr]
	if not o then return end
	if o.CharHinzu then pcall(function()o.CharHinzu:Disconnect() end) end
	if o.CharRaus then pcall(function()o.CharRaus:Disconnect() end) end
	if o.Hervorheben then pcall(function()o.Hervorheben:Destroy() end) end
	if o.Schild then pcall(function()o.Schild:Destroy() end) end
	ESPObjekte[plr]=nil
end

local function ErzeugeESP(plr)
	if ESPObjekte[plr] then return end
	local t={}
	local function anheften(char)
		if not Zustand.ESP.Aktiv then return end
		if Zustand.ESP.Chams then
			local h=Instance.new("Highlight")
			h.FillColor = Zustand.ESP.TeamFarben and (plr.Team and plr.Team.TeamColor and plr.Team.TeamColor.Color) or Zustand.ESP.FuellFarbe
			h.OutlineColor = Zustand.ESP.UmrissFarbe
			h.FillTransparency = Zustand.ESP.FuellTransparenz
			h.OutlineTransparency = Zustand.ESP.UmrissTransparenz
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Adornee = char
			h.Parent = char
			t.Hervorheben=h
		end
		if Zustand.ESP.Namensschilder then
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
				tl.TextColor3=Zustand.ESP.NamenFarbe
				tl.TextSize=Zustand.ESP.NamenGroesse
				tl.Font=Enum.Font.GothamBold
				tl.Parent=bg
				bg.Parent=char
				t.Schild=bg
			end
		end
		ESPObjekte[plr]=t
	end
	local function aufraeumen()
		if t.Hervorheben then pcall(function()t.Hervorheben:Destroy()end) t.Hervorheben=nil end
		if t.Schild then pcall(function()t.Schild:Destroy()end) t.Schild=nil end
		ESPObjekte[plr]=nil
	end
	t.Aufraeumen=aufraeumen
	if plr.Character then anheften(plr.Character) end
	t.CharHinzu=plr.CharacterAdded:Connect(function(c) task.wait(0.1) anheften(c) end)
	t.CharRaus=plr.CharacterRemoving:Connect(function() aufraeumen() end)
end

local function BaueAlleESPNeu()
	for _,p in ipairs(SpielerDienst:GetPlayers()) do if p~=LokalerSpieler then ZerstoereESP(p) ErzeugeESP(p) end end
end

for _,p in ipairs(SpielerDienst:GetPlayers()) do if p~=LokalerSpieler then ErzeugeESP(p) end end
SpielerDienst.PlayerAdded:Connect(function(p) if p~=LokalerSpieler then ErzeugeESP(p) end end)
SpielerDienst.PlayerRemoving:Connect(function(p) ZerstoereESP(p) end)

local function NaechsterSpieler()
	local bester, metr = nil, math.huge
	local maus = EingabeDienst:GetMouseLocation()
	for _, plr in ipairs(SpielerDienst:GetPlayers()) do
		if plr~=LokalerSpieler then
			local char=plr.Character
			if char then
				local teil=char:FindFirstChild(Zustand.Aimbot.ZielTeil)
				if teil then
					if not(Zustand.Aimbot.TeamCheck and GleichesTeam(plr,LokalerSpieler))
					and not(Zustand.Aimbot.LebendCheck and not Lebendig(char))
					and (not Zustand.Aimbot.WandCheck or SichtbarVonKamera(teil.Position,{LokalerSpieler.Character,char,Kamera})) then
						if Zustand.Aimbot.ZielModus=="Naechste zum Fadenkreuz" then
							local v,on = Kamera:WorldToViewportPoint(PrognosePunkt(char,teil))
							if on then
								local d=(maus-V2(v)).Magnitude
								if d<=Zustand.FOV.Betrag and d<metr then metr=d bester=plr end
							end
						else
							local wurzel = LokalerSpieler.Character and LokalerSpieler.Character:FindFirstChild("HumanoidRootPart")
							local dist3 = wurzel and (wurzel.Position - teil.Position).Magnitude or math.huge
							if Zustand.Aimbot.FOVInDistanzModus then
								local v,on=Kamera:WorldToViewportPoint(teil.Position)
								if on then
									local scr=(maus-V2(v)).Magnitude
									if scr<=Zustand.FOV.Betrag and dist3<metr then metr=dist3 bester=plr end
								end
							else
								if dist3<metr then metr=dist3 bester=plr end
							end
						end
					end
				end
			end
		end
	end
	if bester then Gesperrt=bester else if Gesperrt then AbbrechenLock() end end
end

local function ZieleAufGesperrt()
	local l=Gesperrt; if not l then return end
	local char=l.Character; if not char then AbbrechenLock() return end
	local teil=char:FindFirstChild(Zustand.Aimbot.ZielTeil); if not teil then AbbrechenLock() return end
	local ziel = PrognosePunkt(char,teil)
	local v,on=Kamera:WorldToViewportPoint(ziel); if not on then AbbrechenLock() return end
	if Zustand.Aimbot.SilentAim then
		if Schiesst and MausBewegungRel then
			local m=EingabeDienst:GetMouseLocation()
			local dx=(v.X-m.X); local dy=(v.Y-m.Y)
			MausBewegungRel(dx*0.6,dy*0.6)
		end
		return
	end
	if Zustand.Aimbot.DrittePerson then
		if MausBewegungRel then
			local m=EingabeDienst:GetMouseLocation()
			local dx=(v.X-m.X)*Zustand.Aimbot.DrittePersonEmpfindlichkeit
			local dy=(v.Y-m.Y)*Zustand.Aimbot.DrittePersonEmpfindlichkeit
			MausBewegungRel(dx,dy)
		end
	else
		local dauer=tonumber(Zustand.Aimbot.Weichheit) or 0
		StoppTween()
		if dauer>0 then
			Animation=TweenDienst:Create(Kamera,TweenInfo.new(dauer,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{CFrame=CFrame.new(Kamera.CFrame.Position,ziel)})
			Animation:Play()
		else
			Kamera.CFrame=CFrame.new(Kamera.CFrame.Position,ziel)
		end
		EingabeDienst.MouseDeltaSensitivity=0
	end
	FOVKreis.Color=Zustand.FOV.GesperrtFarbe
end

local function AktualisiereFOV()
	local f=Zustand.FOV
	if f.Aktiv then
		FOVKreis.Visible=f.Sichtbar
		FOVKreis.Radius=f.Betrag
		FOVKreis.Thickness=f.Dicke
		FOVKreis.Filled=f.Gefuellt
		FOVKreis.NumSides=f.Seiten
		FOVKreis.Color=Gesperrt and f.GesperrtFarbe or f.Farbe
		FOVKreis.Transparency=f.Transparenz
		FOVKreis.Position=EingabeDienst:GetMouseLocation()
	else
		FOVKreis.Visible=false
	end
end

LaufDienst.RenderStepped:Connect(function()
	pcall(AktualisiereFOV)
	if Laeuft and Zustand.Aimbot.Aktiv then
		pcall(NaechsterSpieler)
		if Gesperrt then
			if Zustand.Aimbot.LebendCheck and not Lebendig(Gesperrt.Character) then
				AbbrechenLock()
			else
				pcall(ZieleAufGesperrt)
			end
		end
	end
end)

EingabeDienst.InputBegan:Connect(function(i,g)
	if HoereAusloeseKey and i.UserInputType==Enum.UserInputType.Keyboard then
		Zustand.Aimbot.AusloeseTaste=i.KeyCode.Name
		HalteTaste=NormiereTaste(Zustand.Aimbot.AusloeseTaste)
		HoereAusloeseKey=false
		return
	end
	if g or Tippen then return end
	if i.UserInputType==Enum.UserInputType.MouseButton1 then Schiesst=true end
	if IstHalteTaste(i) then
		if Zustand.Aimbot.AktivierungsModus=="Hold" then
			Laeuft=true
		else
			Laeuft=not Laeuft
			if not Laeuft then AbbrechenLock() end
		end
	end
end)

EingabeDienst.InputEnded:Connect(function(i,g)
	if g or Tippen then return end
	if i.UserInputType==Enum.UserInputType.MouseButton1 then Schiesst=false end
	if IstHalteTaste(i) and Zustand.Aimbot.AktivierungsModus=="Hold" then
		Laeuft=false
		AbbrechenLock()
	end
end)

EingabeDienst.TextBoxFocused:Connect(function() Tippen=true end)
EingabeDienst.TextBoxFocusReleased:Connect(function() Tippen=false end)

local function Neu(inst,props,parent) local o=Instance.new(inst) for k,v in pairs(props)do o[k]=v end o.Parent=parent return o end

local BildschirmGui = Neu("ScreenGui",{Name="ArsenalSkriptUI",IgnoreGuiInset=true,ResetOnSpawn=false},game:GetService("CoreGui"))
local HauptFrame = Neu("Frame",{Size=UDim2.new(0,720,0,500),Position=UDim2.new(0,0,0.2,0),AnchorPoint=Vector2.new(0,0),BackgroundColor3=Color3.fromRGB(20,20,25),BorderSizePixel=0},BildschirmGui)
Neu("UICorner",{CornerRadius=UDim.new(0,12)},HauptFrame)
local TitelLeiste = Neu("TextLabel",{Size=UDim2.new(1,0,0,40),BackgroundColor3=Color3.fromRGB(28,28,34),Text="Arsenal Skript",TextColor3=Color3.new(1,1,1),TextSize=18,Font=Enum.Font.GothamBold},HauptFrame)
local Reiter = Neu("Frame",{Size=UDim2.new(0,170,1,-40),Position=UDim2.new(0,0,0,40),BackgroundColor3=Color3.fromRGB(28,28,34),BorderSizePixel=0},HauptFrame)
local Inhalt = Neu("Frame",{Size=UDim2.new(1,-180,1,-55),Position=UDim2.new(0,180,0,50),BackgroundColor3=Color3.fromRGB(24,24,30),BorderSizePixel=0},HauptFrame)
Neu("UICorner",{CornerRadius=UDim.new(0,10)},Inhalt)
local Fuss = Neu("TextLabel",{Size=UDim2.new(1,0,0,15),Position=UDim2.new(0,0,1,-15),BackgroundTransparency=1,Text="F1: Menü",TextColor3=Color3.fromRGB(180,180,190),TextSize=12,Font=Enum.Font.Gotham},HauptFrame)
local Skala = Instance.new("UIScale",HauptFrame); Skala.Scale = IstMobil and 0.92 or 1

do
	local ziehen=false; local start; local posStart
	TitelLeiste.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			ziehen=true; start=i.Position; posStart=HauptFrame.Position
		end
	end)
	TitelLeiste.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then ziehen=false end end)
	EingabeDienst.InputChanged:Connect(function(i)
		if ziehen and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
			local delta=i.Position-start
			HauptFrame.Position=UDim2.new(posStart.X.Scale,posStart.X.Offset+delta.X,posStart.Y.Scale,posStart.Y.Offset+delta.Y)
		end
	end)
end

local function ReiterTaste(text,ordnung)
	return Neu("TextButton",{Size=UDim2.new(1,0,0,44),Position=UDim2.new(0,0,0,(ordnung-1)*46),Text=text,TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(36,36,44),BorderSizePixel=0},Reiter)
end

local function LeereInhalt() for _,c in ipairs(Inhalt:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end

local function Scroll()
	local s=Neu("ScrollingFrame",{Size=UDim2.new(1,-20,1,-20),Position=UDim2.new(0,10,0,10),CanvasSize=UDim2.new(0,0,0,0),ScrollBarThickness=6,BackgroundTransparency=1},Inhalt)
	local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.Parent=s
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() s.CanvasSize=UDim2.new(0,0,0,list.AbsoluteContentSize.Y+10) end)
	return s
end

local function Abschnitt(parent,text)
	local f=Neu("Frame",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1},parent)
	Neu("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=16,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1)},f)
	return f
end

local function Umschalter(parent,text,standard,cb)
	local f=Neu("Frame",{Size=UDim2.new(1,0,0,36),BackgroundTransparency=1},parent)
	Neu("TextLabel",{Size=UDim2.new(1,-100,1,0),BackgroundTransparency=1,Text=text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1)},f)
	local b=Neu("TextButton",{Size=UDim2.new(0,90,1,0),Position=UDim2.new(1,-90,0,0),Text=standard and "AN" or "AUS",TextSize=14,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=standard and Color3.fromRGB(30,150,85) or Color3.fromRGB(90,90,95),BorderSizePixel=0},f)
	Neu("UICorner",{CornerRadius=UDim.new(0,8)},b)
	local state=standard
	b.MouseButton1Click:Connect(function() state=not state b.Text=state and "AN" or "AUS" b.BackgroundColor3=state and Color3.fromRGB(30,150,85) or Color3.fromRGB(90,90,95) pcall(cb,state) end)
	return f
end

local function Schieber(parent,text,min,max,standard,stellen,cb)
	local f=Neu("Frame",{Size=UDim2.new(1,0,0,44),BackgroundTransparency=1},parent)
	Neu("TextLabel",{Size=UDim2.new(1,0,0,18),Text=text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1)},f)
	local balken=Neu("Frame",{Size=UDim2.new(1,-10,0,6),Position=UDim2.new(0,5,0,26),BackgroundColor3=Color3.fromRGB(45,45,55),BorderSizePixel=0},f)
	local fuell=Neu("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=Color3.fromRGB(85,150,255),BorderSizePixel=0},balken)
	local knopf=Neu("Frame",{Size=UDim2.new(0,12,0,12),Position=UDim2.new(0,0,0.5,-6),BackgroundColor3=Color3.fromRGB(200,200,255),BorderSizePixel=0},balken)
	Neu("UICorner",{CornerRadius=UDim.new(0,6)},knopf)
	local wertLabel=Neu("TextLabel",{Size=UDim2.new(0,90,0,18),Position=UDim2.new(1,-90,0,0),BackgroundTransparency=1,Text="",TextSize=13,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1)},f)
	local function clamp(v) if v<min then v=min end if v>max then v=max end return v end
	local function round(v) if not stellen or stellen<=0 then return math.floor(v+0.5) end local m=10^stellen return math.floor(v*m+0.5)/m end
	local function setFromRatio(r) local v=round(clamp(min+(max-min)*r)); fuell.Size=UDim2.new(r,0,1,0); knopf.Position=UDim2.new(r,-6,0.5,-6); wertLabel.Text=tostring(v); pcall(cb,v) end
	local start=(standard-min)/(max-min); setFromRatio(start)
	local ziehen=false
	local function update(x) local abs=balken.AbsoluteSize.X; local off=x-balken.AbsolutePosition.X; local r=math.clamp(off/abs,0,1); setFromRatio(r) end
	balken.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then ziehen=true update(i.Position.X) end end)
	balken.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then ziehen=false end end)
	EingabeDienst.InputChanged:Connect(function(i) if ziehen and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then update(i.Position.X) end end)
	return f
end

local function Auswahl(parent,text,werte,standard,cb)
	local f=Neu("Frame",{Size=UDim2.new(1,0,0,36),BackgroundTransparency=1},parent)
	Neu("TextLabel",{Size=UDim2.new(1,-150,1,0),BackgroundTransparency=1,Text=text,TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1)},f)
	local idx=1 for i,v in ipairs(werte) do if v==standard then idx=i break end end
	local b=Neu("TextButton",{Size=UDim2.new(0,150,1,0),Position=UDim2.new(1,-150,0,0),Text=werte[idx],TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),BorderSizePixel=0},f)
	Neu("UICorner",{CornerRadius=UDim.new(0,8)},b)
	b.MouseButton1Click:Connect(function() idx=idx%#werte+1 b.Text=werte[idx] pcall(cb,werte[idx]) end)
	return f
end

local function Knopf(parent,text,cb)
	local b=Neu("TextButton",{Size=UDim2.new(0,240,0,34),Text=text,TextSize=14,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(60,60,70),BorderSizePixel=0},parent)
	Neu("UICorner",{CornerRadius=UDim.new(0,8)},b); b.MouseButton1Click:Connect(function() pcall(cb) end); return b
end

local FunktionAimbot, FunktionESP, FunktionFOV, FunktionEinstellungen

FunktionAimbot = function()
	LeereInhalt()
	local s=Scroll()
	Abschnitt(s,"Aimbot")
	Umschalter(s,"Aktiv",Zustand.Aimbot.Aktiv,function(v)Zustand.Aimbot.Aktiv=v end)
	Auswahl(s,"Aktivierungsmodus",{"Hold","Toggle"},Zustand.Aimbot.AktivierungsModus,function(v)Zustand.Aimbot.AktivierungsModus=v end)
	Auswahl(s,"Zielmodus",{"Naechste zum Fadenkreuz","Naechste Distanz"},Zustand.Aimbot.ZielModus,function(v)Zustand.Aimbot.ZielModus=v end)
	Umschalter(s,"FOV im Distanzmodus",Zustand.Aimbot.FOVInDistanzModus,function(v)Zustand.Aimbot.FOVInDistanzModus=v end)
	Auswahl(s,"Zielteile",{"Head","UpperTorso","HumanoidRootPart"},Zustand.Aimbot.ZielTeil,function(v)Zustand.Aimbot.ZielTeil=v end)
	Umschalter(s,"Team-Check",Zustand.Aimbot.TeamCheck,function(v)Zustand.Aimbot.TeamCheck=v end)
	Umschalter(s,"Lebend-Check",Zustand.Aimbot.LebendCheck,function(v)Zustand.Aimbot.LebendCheck=v end)
	Umschalter(s,"Wand-Check",Zustand.Aimbot.WandCheck,function(v)Zustand.Aimbot.WandCheck=v end)
	Schieber(s,"Weichheit (Sek.)",0,1,Zustand.Aimbot.Weichheit,2,function(v)Zustand.Aimbot.Weichheit=v end)
	Umschalter(s,"Dritte Person",Zustand.Aimbot.DrittePerson,function(v)Zustand.Aimbot.DrittePerson=v end)
	Schieber(s,"Dritte-Person-Empfindlichkeit",1,10,Zustand.Aimbot.DrittePersonEmpfindlichkeit,0,function(v)Zustand.Aimbot.DrittePersonEmpfindlichkeit=v end)
	Umschalter(s,"Silent Aim (beim Schuss)",Zustand.Aimbot.SilentAim,function(v)Zustand.Aimbot.SilentAim=v end)
	Umschalter(s,"Prognose",Zustand.Aimbot.Prognose,function(v)Zustand.Aimbot.Prognose=v end)
	Schieber(s,"Prognose-Zeit",0,0.5,Zustand.Aimbot.PrognoseZeit,3,function(v)Zustand.Aimbot.PrognoseZeit=v end)
	Abschnitt(s,"Auslöse-Taste")
	Knopf(s,"Taste setzen (Tastatur)",function()HoereAusloeseKey=true end)
	Knopf(s,"MouseButton1 verwenden",function()Zustand.Aimbot.AusloeseTaste="MouseButton1" HalteTaste=NormiereTaste("MouseButton1") end)
	Knopf(s,"MouseButton2 verwenden",function()Zustand.Aimbot.AusloeseTaste="MouseButton2" HalteTaste=NormiereTaste("MouseButton2") end)
	Knopf(s,"MouseButton3 verwenden",function()Zustand.Aimbot.AusloeseTaste="MouseButton3" HalteTaste=NormiereTaste("MouseButton3") end)
end

FunktionESP = function()
	LeereInhalt()
	local s=Scroll()
	Abschnitt(s,"ESP")
	Umschalter(s,"Aktiv",Zustand.ESP.Aktiv,function(v)Zustand.ESP.Aktiv=v BaueAlleESPNeu() end)
	Umschalter(s,"Chams",Zustand.ESP.Chams,function(v)Zustand.ESP.Chams=v BaueAlleESPNeu() end)
	Umschalter(s,"Namensschilder",Zustand.ESP.Namensschilder,function(v)Zustand.ESP.Namensschilder=v BaueAlleESPNeu() end)
	Umschalter(s,"Teamfarben",Zustand.ESP.TeamFarben,function(v)Zustand.ESP.TeamFarben=v BaueAlleESPNeu() end)
	Schieber(s,"Namen Schriftgröße",10,24,Zustand.ESP.NamenGroesse,0,function(v)Zustand.ESP.NamenGroesse=v BaueAlleESPNeu() end)
end

FunktionFOV = function()
	LeereInhalt()
	local s=Scroll()
	Abschnitt(s,"FOV")
	Umschalter(s,"Aktiv",Zustand.FOV.Aktiv,function(v)Zustand.FOV.Aktiv=v end)
	Umschalter(s,"Sichtbar",Zustand.FOV.Sichtbar,function(v)Zustand.FOV.Sichtbar=v end)
	Schieber(s,"Größe",10,300,Zustand.FOV.Betrag,0,function(v)Zustand.FOV.Betrag=v end)
	Schieber(s,"Dicke",1,4,Zustand.FOV.Dicke,0,function(v)Zustand.FOV.Dicke=v end)
	Schieber(s,"Seiten",10,120,Zustand.FOV.Seiten,0,function(v)Zustand.FOV.Seiten=v end)
	Umschalter(s,"Gefüllt",Zustand.FOV.Gefuellt,function(v)Zustand.FOV.Gefuellt=v end)
	Schieber(s,"Transparenz",0,1,Zustand.FOV.Transparenz,2,function(v)Zustand.FOV.Transparenz=v end)
end

FunktionEinstellungen = function()
	LeereInhalt()
	local s=Scroll()
	Abschnitt(s,"Allgemein")
	Knopf(s,"Position zurücksetzen",function()HauptFrame.Position=UDim2.new(0,0,0.2,0) end)
	Knopf(s,"Empfindlichkeit zurücksetzen",function()EingabeDienst.MouseDeltaSensitivity=OriginalEmpfindlichkeit end)
	Abschnitt(s,"Mobil")
	local mobilInfo=Neu("TextLabel",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Text=IstMobil and "Mobil erkannt: AN" or "Mobil erkannt: AUS",TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.Gotham,TextColor3=Color3.fromRGB(200,200,210)},s)
	Umschalter(s,"UI-Skalierung 90%",IstMobil,function(v)Skala.Scale=v and 0.92 or 1 end)
end

local rt1=ReiterTaste("Aimbot",1)
local rt2=ReiterTaste("ESP",2)
local rt3=ReiterTaste("FOV",3)
local rt4=ReiterTaste("Einstellungen",4)

rt1.MouseButton1Click:Connect(FunktionAimbot)
rt2.MouseButton1Click:Connect(FunktionESP)
rt3.MouseButton1Click:Connect(FunktionFOV)
rt4.MouseButton1Click:Connect(FunktionEinstellungen)

FunktionAimbot()

KontextAktion:BindAction("MenueUmschalten", function(_,zustand,_) 
	if zustand==Enum.UserInputState.Begin then
		if HauptFrame then HauptFrame.Visible=not HauptFrame.Visible end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F1)
