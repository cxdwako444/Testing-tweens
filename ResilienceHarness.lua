--[[
Resilience Harness — Overflow-Style UI (Visuals Only)
- Client-side only. No blur, tight gaps, left tabs fixed.
- UI toolkit inspired by your reference (Tabs/Sections/Toggles/Sliders/Notify).
- Wires to SAFE stress actions (no bypass logic): InputBurst, TweenLoad, MoveToStress, LatencySim.
- If you already have the v4.0 harness logic loaded, this script will just build UI around it.
  Otherwise, it includes a minimal safe harness fallback.

Place as LocalScript in StarterPlayerScripts.
]]

--== Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

--== Tiny Safe Harness (used if you didn’t inject your own already)
local Harness = rawget(_G, "RH_SafeHarness") or (function()
	local T = {buffer={},max=4096,flushInterval=2.0,lastFlush=time()}
	function T.push(x) if #T.buffer>=T.max then table.remove(T.buffer,1) end T.buffer[#T.buffer+1]=x end
	function T.snap(tag,extra)
		local v=hrp.Velocity
		T.push({t=time(),tag=tag,pos={x=hrp.Position.X,y=hrp.Position.Y,z=hrp.Position.Z},vel={x=v.X,y=v.Y,z=v.Z},speed=v.Magnitude,state=tostring(hum:GetState()),extra=extra or {}})
	end

	local Limits={MaxSpeed=28,MaxAccel=120,MaxJumpCadence=5,MaxPathDeviation=12}
	local C={lastV=Vector3.zero,jumpTimes={},pathAnchor=hrp.Position}
	hum.StateChanged:Connect(function(_,s) if s==Enum.HumanoidStateType.Jumping then table.insert(C.jumpTimes,time()) end end)
	local function pruneJumps()
		local now=time()
		for i=#C.jumpTimes,1,-1 do if now-C.jumpTimes[i]>10 then table.remove(C.jumpTimes,i) end end
		return #C.jumpTimes
	end

	local Perturb={}
	function Perturb.MoveToStress(duration,radius,step)
		local t0=time()
		local wp=Instance.new("Part"); wp.Anchored=true; wp.CanCollide=false; wp.Transparency=1; wp.Name="Harness_Waypoint"; wp.Parent=workspace
		while time()-t0<duration do
			local off=Vector3.new(math.random(-radius,radius),0,math.random(-radius,radius))
			wp.Position=hrp.Position+off; hum:MoveTo(wp.Position)
			T.snap("MoveToStress",{target={x=wp.Position.X,y=wp.Position.Y,z=wp.Position.Z}})
			task.wait(step)
		end
		wp:Destroy()
	end
	function Perturb.TweenLoad(duration)
		local t0=time(); local cam=workspace.CurrentCamera
		while time()-t0<duration do
			local tw=TweenService:Create(cam,TweenInfo.new(0.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{FieldOfView=70+math.random(-4,4)})
			tw:Play(); T.snap("TweenLoad"); tw.Completed:Wait()
		end
	end
	function Perturb.InputBurst(duration,freq)
		local t0=time(); local dt=1/math.max(1,freq)
		while time()-t0<duration do
			local d=Vector3.new(math.random(-100,100),0,math.random(-100,100)); if d.Magnitude<1 then d=Vector3.new(1,0,0) end
			d=d.Unit; hum:Move(d,true); T.snap("InputBurst",{dir={x=d.X,y=d.Y,z=d.Z}}); task.wait(dt)
		end
		hum:Move(Vector3.zero,true)
	end
	function Perturb.LatencySim(sendFn,payloadFn,duration,meanMs,jitterMs)
		local t0=time()
		while time()-t0<duration do
			local delay=math.max(0, meanMs+((math.random()*2-1)*jitterMs))
			task.wait(delay/1000); sendFn(payloadFn()); T.snap("LatencySim",{delayMs=delay})
		end
	end

	local Campaign={}
	Campaign["Sprint/Jump Jitter"]=function()
		Perturb.InputBurst(5.5,12); Perturb.TweenLoad(3.5); Perturb.MoveToStress(5.5,10,0.14)
	end
	Campaign["Latency Heavy"]=function()
		local r=RS:FindFirstChild("ClientTick"); if not r then T.push({t=time(),tag="ERROR_NoRemote"}); return end
		local function send(p) if r.FireServer then pcall(function() r:FireServer(p) end) end end
		local function payload() return {t=time(),pos=hrp.Position,vel=hrp.Velocity} end
		Perturb.LatencySim(send,payload,8.0,80,60)
	end

	-- telemetry loop
	RunService.Heartbeat:Connect(function(dt)
		local v=hrp.Velocity; local speed=v.Magnitude
		local accel=(v-C.lastV).Magnitude/math.max(dt,1/240); C.lastV=v
		if speed>Limits.MaxSpeed then T.push({t=time(),tag="VIOLATION_Speed",speed=speed}) end
		if accel>Limits.MaxAccel then T.push({t=time(),tag="VIOLATION_Accel",accel=accel}) end
		if pruneJumps()>Limits.MaxJumpCadence then T.push({t=time(),tag="VIOLATION_JumpCadence",count=#C.jumpTimes}) end
		local dev=(hrp.Position-C.pathAnchor).Magnitude
		if dev>Limits.MaxPathDeviation then T.push({t=time(),tag="DEVIATION",deviation=dev}) end
		if time()-T.lastFlush>=T.flushInterval then
			T.lastFlush=time()
			print("-- TELEMETRY FLUSH --", HttpService:JSONEncode({n=#T.buffer,last=T.buffer[#T.buffer]}))
		end
	end)

	return {
		T=T, Limits=Limits, C=C, Perturb=Perturb, Campaign=Campaign,
		resetAnchor=function() C.pathAnchor=hrp.Position end,
		runScenario=function(name) (Campaign[name] or function() end)() end,
		export=function() print("-- EXPORT BEGIN --"); print(HttpService:JSONEncode(_.buffer or T.buffer)); print("-- EXPORT END --") end,
		list={"Sprint/Jump Jitter","Latency Heavy"},
	}
end)()

--== UI Toolkit (overflow-style visuals)
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local SHADOW = "rbxassetid://13637412666"

local UI = {}
function UI.shadow(u,inflate)
	local p = inflate or 10
	local s = Instance.new("ImageLabel")
	s.BackgroundTransparency = 1
	s.Image = SHADOW
	s.ImageColor3 = Color3.new(0,0,0)
	s.ImageTransparency = 0.76
	s.ScaleType = Enum.ScaleType.Slice
	s.SliceCenter = Rect.new(64,64,64,64)
	s.ZIndex = (u.ZIndex or 1)-1
	s.Size = UDim2.new(1,p,1,p)
	s.Position = UDim2.fromOffset(-p/2,-p/2)
	s.Parent = u
	return s
end
function UI.ripple(btn, pos)
	local circle = Instance.new("Frame")
	circle.BackgroundColor3 = Color3.new(1,1,1)
	circle.BackgroundTransparency = 0.3
	circle.Size = UDim2.fromOffset(0,0)
	circle.ZIndex = btn.ZIndex + 2
	circle.Parent = btn
	local corner = Instance.new("UICorner", circle) corner.CornerRadius = UDim.new(1,0)
	local max = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.6
	circle.Position = UDim2.fromOffset(pos.X - max*0.5, pos.Y - max*0.5)
	TweenService:Create(circle, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(max,max), BackgroundTransparency = 1
	}):Play()
	game:GetService("Debris"):AddItem(circle, 0.24)
end
function UI.clickFX(btn)
	btn.ClipsDescendants = true
	local s = Instance.new("UIScale") s.Scale = 1 s.Parent = btn
	btn.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			TweenService:Create(s, TweenInfo.new(0.06, Enum.EasingStyle.Quad), {Scale=0.96}):Play()
			local rel = i.Position - btn.AbsolutePosition
			UI.ripple(btn, Vector2.new(rel.X,rel.Y))
		end
	end)
	btn.InputEnded:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			TweenService:Create(s, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=1}):Play()
		end
	end)
end

--== Window/Tab/Section components
local Screen = Instance.new("ScreenGui")
Screen.Name = "Resilience_OverflowUI"
Screen.IgnoreGuiInset = true
Screen.ResetOnSpawn = false
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Screen.Parent = player:WaitForChild("PlayerGui")

local GAP = 6; local R = 10
local Win = Instance.new("Frame")
Win.Name="Window"; Win.ClipsDescendants=true
Win.Size = UDim2.fromOffset(350, 230)
Win.Position = UDim2.fromOffset(28, 28)
Win.BackgroundColor3 = rgb(20,22,30)
Win.BackgroundTransparency = 0.08
Win.Parent = Screen
Instance.new("UICorner", Win).CornerRadius = UDim.new(0,R)
local wStroke = Instance.new("UIStroke", Win); wStroke.Color = rgb(60,64,84); wStroke.Transparency = 0.45
UI.shadow(Win, 12)

-- Topbar
local Top = Instance.new("Frame"); Top.Size = UDim2.new(1,0,0,28); Top.BackgroundTransparency=1; Top.Parent = Win
local Title = Instance.new("TextLabel")
Title.BackgroundTransparency=1; Title.Font=Enum.Font.GothamSemibold; Title.TextSize=13
Title.TextXAlignment=Enum.TextXAlignment.Left; Title.TextColor3=rgb(232,236,255)
Title.Text="Resilience Harness"; Title.Position=UDim2.fromOffset(10,5); Title.Size=UDim2.fromOffset(200,18); Title.Parent=Top

local Mini = Instance.new("TextButton")
Mini.Text="–"; Mini.Font=Enum.Font.GothamBold; Mini.TextSize=16; Mini.TextColor3=rgb(22,26,34)
Mini.AutoButtonColor=false; Mini.BackgroundColor3=rgb(140,230,190)
Mini.Size=UDim2.fromOffset(24,18); Mini.Position=UDim2.new(1,-28,0,5); Mini.ZIndex=2; Mini.Parent=Top
Instance.new("UICorner", Mini).CornerRadius=UDim.new(0,7); UI.shadow(Mini,8); UI.clickFX(Mini)

-- Drag
do
	local dragging=false; local dragStart; local startPos
	Top.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			dragging=true; dragStart=i.Position; startPos=Vector2.new(Win.Position.X.Offset, Win.Position.Y.Offset)
			i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
			local d=i.Position-dragStart; Win.Position=UDim2.fromOffset(startPos.X+d.X, startPos.Y+d.Y)
		end
	end)
end

-- Left Rail (tabs)
local RailH = Win.Size.Y.Offset - 28 - GAP
local Rail = Instance.new("Frame")
Rail.Size = UDim2.fromOffset(96, RailH)
Rail.Position = UDim2.fromOffset(GAP, 28+GAP)
Rail.BackgroundColor3 = rgb(28,30,42); Rail.ClipsDescendants = true; Rail.Parent = Win
Instance.new("UICorner", Rail).CornerRadius = UDim.new(0, R-2)
local railStroke = Instance.new("UIStroke", Rail); railStroke.Color=rgb(60,64,84); railStroke.Transparency=0.35
UI.shadow(Rail,10)
local RailPad = Instance.new("UIPadding", Rail); RailPad.PaddingTop=UDim.new(0,GAP); RailPad.PaddingBottom=UDim.new(0,GAP)
local RailList = Instance.new("UIListLayout", Rail); RailList.Padding=UDim.new(0,GAP)

local function RailButton(text)
	local b=Instance.new("TextButton")
	b.Text=text; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.TextColor3=rgb(230,236,255)
	b.AutoButtonColor=false; b.BackgroundColor3=rgb(38,42,58); b.Size=UDim2.fromOffset(80,24); b.Parent=Rail
	Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
	local s=Instance.new("UIStroke", b); s.Color=rgb(70,74,92); s.Transparency=0.35
	UI.shadow(b,8); UI.clickFX(b)
	return b
end

local Tabs = {
	Main = RailButton("Main"),
	Metrics = RailButton("Metrics"),
	Logs = RailButton("Logs"),
	Config = RailButton("Config"),
}

local Content = Instance.new("Frame")
Content.Size = UDim2.fromOffset(Win.Size.X.Offset - 96 - (GAP*3), RailH)
Content.Position = UDim2.fromOffset(96+GAP+GAP, 28+GAP)
Content.BackgroundColor3 = rgb(24,26,36); Content.ClipsDescendants = true; Content.Parent = Win
Instance.new("UICorner", Content).CornerRadius=UDim.new(0,R-2)
local cStroke=Instance.new("UIStroke", Content); cStroke.Color=rgb(60,64,84); cStroke.Transparency=0.35
UI.shadow(Content,10)

local function Page(name)
	local p=Instance.new("Frame")
	p.Name="Page_"..name; p.BackgroundTransparency=1; p.Size=UDim2.fromScale(1,1); p.Visible=false; p.Parent=Content
	return p
end
local P = {
	Main   = Page("Main"),
	Metrics= Page("Metrics"),
	Logs   = Page("Logs"),
	Config = Page("Config"),
}

-- Section/Card factory (compact)
local function Section(parent, title)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, - (GAP*2), 0, 60)
	frame.Position = UDim2.fromOffset(GAP,GAP)
	frame.BackgroundColor3=rgb(36,38,50)
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius=UDim.new(0,10)
	local s=Instance.new("UIStroke", frame); s.Color=rgb(70,74,92); s.Transparency=0.25
	UI.shadow(frame,8)
	-- layout stack
	local pad = Instance.new("UIPadding", frame); pad.PaddingTop=UDim.new(0,8); pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,8)
	local list = Instance.new("UIListLayout", frame); list.Padding=UDim.new(0,6)
	-- header
	local h = Instance.new("TextLabel"); h.Text=title; h.Font=Enum.Font.GothamSemibold; h.TextSize=14
	h.TextXAlignment=Enum.TextXAlignment.Left; h.TextColor3=rgb(240,244,255); h.BackgroundTransparency=1; h.Size=UDim2.fromOffset(200,18); h.Parent=frame
	return frame, list
end

local function Toggle(parent, text, color, cb)
	local row = Instance.new("Frame"); row.Size=UDim2.new(1,0,0,26); row.BackgroundTransparency=1; row.Parent=parent
	local label=Instance.new("TextLabel"); label.BackgroundTransparency=1; label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=12
	label.TextXAlignment=Enum.TextXAlignment.Left; label.TextColor3=rgb(210,214,230); label.Size=UDim2.new(1,-70,1,0); label.Parent=row
	local sw = Instance.new("Frame"); sw.Size=UDim2.fromOffset(52,22); sw.Position=UDim2.new(1,-58,0.5,-11); sw.BackgroundColor3=rgb(52,56,70); sw.Parent=row
	Instance.new("UICorner", sw).CornerRadius=UDim.new(1,0)
	local k = Instance.new("Frame"); k.Size=UDim2.fromOffset(18,18); k.Position=UDim2.fromOffset(2,2); k.BackgroundColor3=Color3.fromRGB(240,240,245); k.Parent=sw
	Instance.new("UICorner", k).CornerRadius=UDim.new(1,0)
	local btn=Instance.new("TextButton"); btn.Text=""; btn.BackgroundTransparency=1; btn.Size=UDim2.fromScale(1,1); btn.Parent=sw
	UI.clickFX(btn)
	local state=false
	local api={}
	function api.Set(v)
		state=v
		TweenService:Create(sw,TweenInfo.new(0.12),{BackgroundColor3 = v and (color or rgb(120,230,170)) or rgb(52,56,70)}):Play()
		TweenService:Create(k, TweenInfo.new(0.12), {Position = v and UDim2.fromOffset(32,2) or UDim2.fromOffset(2,2)}):Play()
		if cb then cb(v) end
	end
	btn.MouseButton1Click:Connect(function() api.Set(not state) end)
	return api
end

local function Button(parent, text, cb)
	local b = Instance.new("TextButton")
	b.Text = text; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.TextColor3=rgb(235,240,255)
	b.AutoButtonColor=false; b.BackgroundColor3=rgb(48,52,66); b.Size=UDim2.new(1,0,0,24); b.Parent=parent
	Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
	local s=Instance.new("UIStroke", b); s.Color=rgb(70,74,92); s.Transparency=0.35
	UI.shadow(b,8); UI.clickFX(b)
	if cb then b.MouseButton1Click:Connect(cb) end
	return b
end

local function Label(parent, text)
	local l=Instance.new("TextLabel")
	l.BackgroundTransparency=1; l.Font=Enum.Font.Gotham; l.TextSize=12; l.TextXAlignment=Enum.TextXAlignment.Left
	l.TextColor3=rgb(200,205,220); l.TextWrapped=true; l.Size=UDim2.new(1,0,0,14); l.Text = text; l.Parent = parent
	return l
end

local function Slider(parent, text, min, max, default, cb)
	local group = Instance.new("Frame"); group.Size=UDim2.new(1,0,0,36); group.BackgroundTransparency=1; group.Parent=parent
	local t=Label(group, ("%s (%d–%d)"):format(text,min,max))
	t.Position=UDim2.fromOffset(0,0)
	local track = Instance.new("Frame"); track.Size=UDim2.new(1,0,0,6); track.Position=UDim2.fromOffset(0,20); track.BackgroundColor3=rgb(40,44,58); track.Parent=group
	Instance.new("UICorner", track).CornerRadius=UDim.new(0,3); UI.shadow(track,6)
	local fill = Instance.new("Frame"); fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=rgb(120,230,170); fill.Parent=track
	Instance.new("UICorner", fill).CornerRadius=UDim.new(0,3)
	local knob = Instance.new("Frame"); knob.Size=UDim2.fromOffset(12,12); knob.Position=UDim2.fromOffset(0,-3); knob.BackgroundColor3=Color3.fromRGB(245,247,255); knob.Parent=fill
	Instance.new("UICorner", knob).CornerRadius=UDim.new(1,0); UI.shadow(knob,8)
	local value = default or min
	local function setVal(v)
		v = math.clamp(v, min, max); value = v
		local alpha = (v - min) / (max - min)
		fill.Size = UDim2.new(alpha,0,1,0)
		if cb then cb(v) end
	end
	setVal(default or min)
	local dragging=false
	track.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			dragging=true
			local x = math.clamp((i.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0,1)
			setVal(math.floor(min + x*(max-min)))
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
			local x = math.clamp((i.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0,1)
			setVal(math.floor(min + x*(max-min)))
		end
	end)
	UIS.InputEnded:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then dragging=false end end)
	return {Set=setVal, Get=function() return value end}
end

-- Notify (toast)
local ToastHolder = Instance.new("Frame")
ToastHolder.Size=UDim2.fromOffset(260,200); ToastHolder.BackgroundTransparency=1
ToastHolder.Position=UDim2.new(1,-270,1,-210); ToastHolder.Parent=Screen
local TList = Instance.new("UIListLayout", ToastHolder); TList.Padding=UDim.new(0,6); TList.VerticalAlignment=Enum.VerticalAlignment.Bottom

local function Notify(msg, dur)
	local card = Instance.new("Frame"); card.Size=UDim2.new(1,0,0,34); card.BackgroundColor3=rgb(36,38,50); card.Parent=ToastHolder
	Instance.new("UICorner", card).CornerRadius=UDim.new(0,10); UI.shadow(card,8)
	local txt=Instance.new("TextLabel", card); txt.BackgroundTransparency=1; txt.TextWrapped=true; txt.TextXAlignment=Enum.TextXAlignment.Left
	txt.Font=Enum.Font.Gotham; txt.TextSize=12; txt.TextColor3=rgb(235,240,255); txt.Size=UDim2.new(1,-16,1,-8); txt.Position=UDim2.fromOffset(8,4); txt.Text=tostring(msg)
	TweenService:Create(card, TweenInfo.new(0.18), {BackgroundTransparency=0.02}):Play()
	task.delay(dur or 2, function()
		local tw = TweenService:Create(card, TweenInfo.new(0.2), {BackgroundTransparency=1})
		tw:Play(); tw.Completed:Wait(); card:Destroy()
	end)
end

--== Main Page (safe actions)
do
	local pad = Instance.new("UIPadding", P.Main); pad.PaddingTop=UDim.new(0,GAP); pad.PaddingLeft=UDim.new(0,GAP); pad.PaddingRight=UDim.new(0,GAP)
	local list = Instance.new("UIListLayout", P.Main); list.Padding=UDim.new(0,GAP)

	local sec1,_ = Section(P.Main, "Stress Actions")
	local t1 = Toggle(sec1, "Input Burst", rgb(120,230,170), function(on)
		if on then
			Harness.T.snap("Start_InputBurst"); task.spawn(function() Harness.Perturb.InputBurst(5.0,12); Harness.T.snap("End_InputBurst") end)
		end
	end)
	local t2 = Toggle(sec1, "Tween Load",  rgb(100,200,255), function(on)
		if on then
			Harness.T.snap("Start_TweenLoad"); task.spawn(function() Harness.Perturb.TweenLoad(4.0); Harness.T.snap("End_TweenLoad") end)
		end
	end)
	local t3 = Toggle(sec1, "MoveTo Stress", rgb(255,175,120), function(on)
		if on then
			Harness.T.snap("Start_MoveTo"); task.spawn(function() Harness.Perturb.MoveToStress(6.0,10,0.14); Harness.T.snap("End_MoveTo") end)
		end
	end)
	-- Auto-off visuals
	for _,tg in ipairs({t1,t2,t3}) do task.delay(0.1, function() tg.Set(false) end) end

	local sec2,_ = Section(P.Main, "Scenarios")
	Button(sec2, "Run: Sprint/Jump Jitter", function()
		Notify("Running Sprint/Jump Jitter", 2)
		Harness.runScenario("Sprint/Jump Jitter")
	end)
	Button(sec2, "Run: Latency Heavy", function()
		Notify("Running Latency Heavy", 2)
		Harness.runScenario("Latency Heavy")
	end)
	Button(sec2, "Reset Path Anchor", function()
		Harness.resetAnchor(); Notify(("Anchor set (%.1f, %.1f, %.1f)"):format(hrp.Position.X,hrp.Position.Y,hrp.Position.Z), 2)
	end)
	Button(sec2, "Export JSON", function()
		print("-- EXPORT BEGIN --"); print(HttpService:JSONEncode(Harness.T.buffer)); print("-- EXPORT END --")
		Notify(("Exported %d events (Output)"):format(#Harness.T.buffer), 2)
	end)
end

--== Metrics Page
do
	local pad = Instance.new("UIPadding", P.Metrics); pad.PaddingTop=UDim.new(0,GAP); pad.PaddingLeft=UDim.new(0,GAP)
	local function metric(y,text)
		local l=Instance.new("TextLabel", P.Metrics)
		l.Text=text..": --"; l.Font=Enum.Font.GothamSemibold; l.TextSize=13; l.TextXAlignment=Enum.TextXAlignment.Left
		l.TextColor3=rgb(235,240,255); l.BackgroundTransparency=1; l.Position=UDim2.fromOffset(4,y); l.Size=UDim2.fromOffset(210,18)
		return l
	end
	local mSpeed=metric(0,"Speed"); local mAccel=metric(20,"Accel"); local mState=metric(40,"State"); local mDev=metric(60,"Deviation"); local mJump=metric(80,"Jump/10s")
	local acc=0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc > 0.25 then
			acc=0
			local v=hrp.Velocity
			local speed=v.Magnitude
			local accel=(v - Harness.C.lastV).Magnitude/math.max(dt,1/240)
			local dev=(hrp.Position - Harness.C.pathAnchor).Magnitude
			mSpeed.Text=("Speed: %.1f"):format(speed)
			mAccel.Text=("Accel: %.1f"):format(accel)
			mState.Text=("State: %s"):format(tostring(hum:GetState()))
			mDev.Text=("Deviation: %.1f"):format(dev)
			mJump.Text=("Jump/10s: %d"):format(#Harness.C.jumpTimes)
		end
	end)
end

--== Logs Page
do
	local log = Instance.new("ScrollingFrame")
	log.Active=true; log.ScrollBarThickness=6; log.BackgroundColor3=rgb(28,30,40); log.BorderSizePixel=0
	log.Size=UDim2.new(1,-(GAP*2),1,-(GAP*2)); log.Position=UDim2.fromOffset(GAP,GAP)
	log.CanvasSize=UDim2.new(0,0,0,0); log.AutomaticCanvasSize=Enum.AutomaticSize.Y; log.Parent=P.Logs
	Instance.new("UICorner", log).CornerRadius=UDim.new(0,8); local s=Instance.new("UIStroke", log); s.Color=rgb(60,64,84); s.Transparency=0.35
	UI.shadow(log,8)
	local list=Instance.new("UIListLayout", log); list.Padding=UDim.new(0,4)

	local function append(t)
		local L=Instance.new("TextLabel"); L.BackgroundTransparency=1; L.Font=Enum.Font.Code; L.TextSize=12
		L.TextXAlignment=Enum.TextXAlignment.Left; L.TextYAlignment=Enum.TextYAlignment.Top; L.TextWrapped=true; L.TextColor3=rgb(210,214,230)
		L.Text=t; L.Size=UDim2.new(1,-8,0,0); L.AutomaticSize=Enum.AutomaticSize.Y; L.Parent=log
	end

	-- sample startup logs
	append("Resilience UI loaded.")
	append(("Events in buffer: %d"):format(#Harness.T.buffer))
end

--== Config Page
do
	local pad = Instance.new("UIPadding", P.Config); pad.PaddingTop=UDim.new(0,GAP); pad.PaddingLeft=UDim.new(0,GAP); pad.PaddingRight=UDim.new(0,GAP)
	local sec, _ = Section(P.Config, "Limits")
	Label(sec, "Tune to your game movement.")
	Slider(sec, "Max Speed", 5, 200, Harness.Limits.MaxSpeed, function(v) Harness.Limits.MaxSpeed = v end)
	Slider(sec, "Max Accel", 20, 500, Harness.Limits.MaxAccel, function(v) Harness.Limits.MaxAccel = v end)
	Slider(sec, "Jump/10s", 1, 30, Harness.Limits.MaxJumpCadence, function(v) Harness.Limits.MaxJumpCadence = v end)
	Slider(sec, "Max Deviation", 2, 100, Harness.Limits.MaxPathDeviation, function(v) Harness.Limits.MaxPathDeviation = v end)

	local sec2,_ = Section(P.Config, "Telemetry")
	Slider(sec2, "Flush Interval (s)", 1, 10, math.floor(Harness.T.flushInterval), function(v) Harness.T.flushInterval = v end)
	Button(sec2, "Clear Buffer", function()
		table.clear(Harness.T.buffer); Notify("Telemetry cleared", 2)
	end)
end

--== Tab routing
local function selectTab(name)
	for id,btn in pairs(Tabs) do
		local act=(id==name)
		TweenService:Create(btn, TweenInfo.new(0.1), {
			BackgroundColor3 = act and rgb(60,64,84) or rgb(38,42,58),
			TextColor3       = act and Color3.new(1,1,1) or rgb(230,236,255)
		}):Play()
		P[id].Visible = act
	end
end
for id,btn in pairs(Tabs) do btn.MouseButton1Click:Connect(function() selectTab(id) end) end
selectTab("Main")

--== Minimize/Restore (no blur)
local minimized=false local pill
local function restore() if pill then pill:Destroy() pill=nil end Win.Visible=true minimized=false end
local function minimize()
	Win.Visible=false minimized=true
	pill=Instance.new("TextButton")
	pill.Text="RH"; pill.Font=Enum.Font.GothamSemibold; pill.TextSize=12; pill.TextColor3=rgb(22,26,34)
	pill.AutoButtonColor=false; pill.BackgroundColor3=rgb(140,230,190)
	pill.Size=UDim2.fromOffset(36,20); pill.Position=UDim2.fromOffset(24,24); pill.Parent=Screen
	Instance.new("UICorner", pill).CornerRadius=UDim.new(1,0); UI.shadow(pill,10); UI.clickFX(pill)
	pill.MouseButton1Click:Connect(restore)
end
Mini.MouseButton1Click:Connect(function() if minimized then restore() else minimize() end end)

--== Startup toast
Notify("UI loaded (client-side only).", 2)
