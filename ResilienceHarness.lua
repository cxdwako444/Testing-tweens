--[[
Resilience Harness v4.0 — Compact Rail UI (Safe, Measurement-Only)
- REMOVED gameplay blur completely
- Left-side tabs fixed inside window (no spill), tight 6px gaps
- Buttons: shadow + squish/pop + white ripple
- Compact window, minimize/restore pill
- Safe stress scenarios (no bypass logic): InputBurst, TweenLoad, MoveToStress, LatencySim
]]

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

--// Player rig
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

--// Helpers
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local function new(class,props,parent) local o=Instance.new(class) for k,v in pairs(props or {}) do o[k]=v end o.Parent=parent return o end

--============= SAFE MEASUREMENT CORE =============
local Telemetry = {buffer={},max=4096,flushInterval=2.0,lastFlush=time()}
function Telemetry.push(x) if #Telemetry.buffer>=Telemetry.max then table.remove(Telemetry.buffer,1) end Telemetry.buffer[#Telemetry.buffer+1]=x end
function Telemetry.snap(tag,extra)
	local v=hrp.Velocity
	Telemetry.push({t=time(),tag=tag,pos={x=hrp.Position.X,y=hrp.Position.Y,z=hrp.Position.Z},vel={x=v.X,y=v.Y,z=v.Z},speed=v.Magnitude,state=tostring(hum:GetState()),extra=extra or {}})
end

local Limits={MaxSpeed=28,MaxAccel=120,MaxJumpCadence=5,MaxPathDeviation=12}
local Constraint={lastV=Vector3.zero,jumpTimes={},pathAnchor=hrp.Position}
hum.StateChanged:Connect(function(_,s) if s==Enum.HumanoidStateType.Jumping then table.insert(Constraint.jumpTimes,time()) end end)
local function pruneJumps()
	local now=time()
	for i=#Constraint.jumpTimes,1,-1 do if now-Constraint.jumpTimes[i]>10 then table.remove(Constraint.jumpTimes,i) end end
	return #Constraint.jumpTimes
end

local Perturb={}
function Perturb.MoveToStress(duration,radius,step)
	local t0=time()
	local wp=new("Part",{Anchored=true,CanCollide=false,Transparency=1,Name="Harness_Waypoint"},workspace)
	while time()-t0<duration do
		local off=Vector3.new(math.random(-radius,radius),0,math.random(-radius,radius))
		wp.Position=hrp.Position+off; hum:MoveTo(wp.Position)
		Telemetry.snap("MoveToStress",{target={x=wp.Position.X,y=wp.Position.Y,z=wp.Position.Z}})
		task.wait(step)
	end
	wp:Destroy()
end
function Perturb.TweenLoad(duration)
	local t0=time(); local cam=workspace.CurrentCamera
	while time()-t0<duration do
		local tw=TweenService:Create(cam,TweenInfo.new(0.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{FieldOfView=70+math.random(-4,4)})
		tw:Play(); Telemetry.snap("TweenLoad"); tw.Completed:Wait()
	end
end
function Perturb.InputBurst(duration,freq)
	local t0=time(); local dt=1/math.max(1,freq)
	while time()-t0<duration do
		local d=Vector3.new(math.random(-100,100),0,math.random(-100,100)); if d.Magnitude<1 then d=Vector3.new(1,0,0) end
		d=d.Unit; hum:Move(d,true); Telemetry.snap("InputBurst",{dir={x=d.X,y=d.Y,z=d.Z}}); task.wait(dt)
	end
	hum:Move(Vector3.zero,true)
end
function Perturb.LatencySim(sendFn,payloadFn,duration,meanMs,jitterMs)
	local t0=time()
	while time()-t0<duration do
		local delay=math.max(0, meanMs+((math.random()*2-1)*jitterMs))
		task.wait(delay/1000); sendFn(payloadFn()); Telemetry.snap("LatencySim",{delayMs=delay})
	end
end

local Campaign={}
Campaign["Sprint/Jump Jitter"]=function()
	Perturb.InputBurst(5.5,12); Perturb.TweenLoad(3.5); Perturb.MoveToStress(5.5,10,0.14)
end
Campaign["Latency Heavy"]=function()
	local r=RS:FindFirstChild("ClientTick"); if not r then Telemetry.push({t=time(),tag="ERROR_NoRemote"}); return end
	local function send(p) if r.FireServer then pcall(function() r:FireServer(p) end) end end
	local function payload() return {t=time(),pos=hrp.Position,vel=hrp.Velocity} end
	Perturb.LatencySim(send,payload,8.0,80,60)
end
local SCENARIOS={"Sprint/Jump Jitter","Latency Heavy"}

--============= STYLE (compact) =============
local GAP=6                 -- tiny spacing
local R=10                  -- radius
local SHADOW_IMG="rbxassetid://13637412666" -- soft shadow sprite
local function shadowUnder(ui,inflate)
	local pad=inflate or 10
	local img=new("ImageLabel",{BackgroundTransparency=1,Image=SHADOW_IMG,ImageColor3=rgb(0,0,0),ImageTransparency=0.76,
		ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(64,64,64,64),ZIndex=(ui.ZIndex or 1)-1},ui)
	img.Size=UDim2.new(1,pad,1,pad); img.Position=UDim2.fromOffset(-pad/2,-pad/2)
	return img
end
local function ripple(btn, at)
	local circle=new("Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0.3,Size=UDim2.fromOffset(0,0),ZIndex=btn.ZIndex+2},btn)
	new("UICorner",{CornerRadius=UDim.new(1,0)},circle)
	local max=math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y)*1.6
	circle.Position=UDim2.fromOffset(at.X-max*0.5, at.Y-max*0.5)
	TweenService:Create(circle,TweenInfo.new(0.18,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(max,max),BackgroundTransparency=1}):Play()
	game:GetService("Debris"):AddItem(circle,0.24)
end
local function clickFX(btn)
	btn.ClipsDescendants=true
	local s=new("UIScale",{Scale=1},btn)
	btn.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			TweenService:Create(s,TweenInfo.new(0.06,Enum.EasingStyle.Quad),{Scale=0.96}):Play()
			local rel=i.Position-btn.AbsolutePosition; ripple(btn, Vector2.new(rel.X,rel.Y))
		end
	end)
	btn.InputEnded:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			TweenService:Create(s,TweenInfo.new(0.10,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
		end
	end)
end

--============= UI =============
local gui=new("ScreenGui",{Name="ResilienceHarnessUI",IgnoreGuiInset=true,ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))

-- Window (clipped so nothing spills outside)
local root=new("Frame",{Size=UDim2.fromOffset(360,240),Position=UDim2.fromOffset(26,26),
	BackgroundColor3=rgb(20,22,30),BackgroundTransparency=0.08,ClipsDescendants=true},gui)
new("UICorner",{CornerRadius=UDim.new(0,R)},root)
new("UIStroke",{Color=rgb(60,64,84),Transparency=0.45,Thickness=1},root)
shadowUnder(root,12)

-- Topbar (drag + minimize)
local top=new("Frame",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1},root)
local title=new("TextLabel",{Text="Resilience Harness",Font=Enum.Font.GothamSemibold,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,
	TextColor3=rgb(232,236,255),BackgroundTransparency=1,Position=UDim2.fromOffset(10,5),Size=UDim2.fromOffset(200,18)},top)
local mini=new("TextButton",{Text="–",Font=Enum.Font.GothamBold,TextSize=16,TextColor3=rgb(22,26,34),
	AutoButtonColor=false,BackgroundColor3=rgb(140,230,190),Size=UDim2.fromOffset(24,18),Position=UDim2.new(1,-28,0,5),ZIndex=2},top)
new("UICorner",{CornerRadius=UDim.new(0,7)},mini) shadowUnder(mini,8) clickFX(mini)

-- Dragging
do
	local dragging=false local dragStart local startPos
	top.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			dragging=true dragStart=i.Position startPos=Vector2.new(root.Position.X.Offset, root.Position.Y.Offset)
			i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
			local d=i.Position-dragStart root.Position=UDim2.fromOffset(startPos.X+d.X, startPos.Y+d.Y)
		end
	end)
end

-- Left rail (fixed, inside)
local railHeight = root.Size.Y.Offset-28-GAP
local rail=new("Frame",{Size=UDim2.fromOffset(100, railHeight),Position=UDim2.fromOffset(GAP,28+GAP),
	BackgroundColor3=rgb(28,30,42),ClipsDescendants=true},root)
new("UICorner",{CornerRadius=UDim.new(0,R-2)},rail)
new("UIStroke",{Color=rgb(60,64,84),Transparency=0.35},rail)
shadowUnder(rail,10)
new("UIPadding",{PaddingTop=UDim.new(0,GAP),PaddingBottom=UDim.new(0,GAP)},rail)
local railList=new("UIListLayout",{Padding=UDim.new(0,GAP),HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Top},rail)

local function railBtn(text)
	local b=new("TextButton",{Text=text,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=rgb(230,236,255),AutoButtonColor=false,
		BackgroundColor3=rgb(38,42,58),Size=UDim2.fromOffset(84,24)},rail)
	new("UICorner",{CornerRadius=UDim.new(0,8)},b)
	new("UIStroke",{Color=rgb(70,74,92),Transparency=0.35},b)
	shadowUnder(b,8) clickFX(b)
	return b
end
local tabs={Main=railBtn("Main"), Metrics=railBtn("Metrics"), Logs=railBtn("Logs"), Config=railBtn("Config")}

-- Content (fixed, inside)
local content=new("Frame",{Size=UDim2.fromOffset(root.Size.X.Offset-100-(GAP*3), railHeight),
	Position=UDim2.fromOffset(100+GAP+GAP, 28+GAP),BackgroundColor3=rgb(24,26,36),ClipsDescendants=true},root)
new("UICorner",{CornerRadius=UDim.new(0,R-2)},content)
new("UIStroke",{Color=rgb(60,64,84),Transparency=0.35},content)
shadowUnder(content,10)

local function page(name) return new("Frame",{Name="Page_"..name,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=false},content) end
local pageMain, pageMetrics, pageLogs, pageConfig = page("Main"), page("Metrics"), page("Logs"), page("Config")

-- Cards stack (tight)
new("UIPadding",{PaddingTop=UDim.new(0,GAP),PaddingLeft=UDim.new(0,GAP),PaddingRight=UDim.new(0,GAP)},pageMain)
local stack=new("UIListLayout",{Padding=UDim.new(0,GAP)},pageMain)

local function card(parent, titleTxt, descTxt)
	local c=new("Frame",{Size=UDim2.new(1,0,0,60),BackgroundColor3=rgb(36,38,50)},parent)
	new("UICorner",{CornerRadius=UDim.new(0,12)},c)
	new("UIStroke",{Color=rgb(70,74,92),Transparency=0.25},c)
	shadowUnder(c,8)
	local t=new("TextLabel",{Text=titleTxt,Font=Enum.Font.GothamSemibold,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,
		TextColor3=rgb(240,244,255),BackgroundTransparency=1,Position=UDim2.fromOffset(12,8),Size=UDim2.fromOffset(190,18)},c)
	local d=new("TextLabel",{Text=descTxt,Font=Enum.Font.Gotham,TextSize=12,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
		TextColor3=rgb(200,205,220),BackgroundTransparency=1,Position=UDim2.fromOffset(12,28),Size=UDim2.new(1,-90,0,24)},c)
	-- switch
	local sw=new("Frame",{Size=UDim2.fromOffset(54,28),Position=UDim2.new(1,-66,0.5,-14),BackgroundColor3=rgb(52,56,70)},c)
	new("UICorner",{CornerRadius=UDim.new(1,0)},sw) new("UIStroke",{Color=rgb(80,84,100),Transparency=0.4},sw) shadowUnder(sw,6)
	local knob=new("Frame",{Size=UDim2.fromOffset(24,24),Position=UDim2.fromOffset(2,2),BackgroundColor3=rgb(235,238,245)},sw) new("UICorner",{CornerRadius=UDim.new(1,0)},knob)
	local hit=new("TextButton",{Text="",AutoButtonColor=false,BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},sw) clickFX(hit)
	local state=false
	local function set(on)
		state=on
		TweenService:Create(sw,TweenInfo.new(0.12),{BackgroundColor3= on and rgb(120,230,170) or rgb(52,56,70)}):Play()
		TweenService:Create(knob,TweenInfo.new(0.12),{Position= on and UDim2.fromOffset(28,2) or UDim2.fromOffset(2,2)}):Play()
	end
	return c,set,function() return state end,hit
end

-- Main cards -> safe stress ops
local c1,set1,get1,hit1=card(pageMain,"Input Burst","Rapid direction changes to stress movement checks.")
hit1.MouseButton1Click:Connect(function()
	set1(not get1()); if get1() then task.spawn(function() Telemetry.push({t=time(),tag="Start_InputBurst"}); Perturb.InputBurst(5.0,12); Telemetry.push({t=time(),tag="End_InputBurst"}); set1(false) end) end
end)
local c2,set2,get2,hit2=card(pageMain,"Tween Load","Camera FOV oscillations to simulate client load.")
hit2.MouseButton1Click:Connect(function()
	set2(not get2()); if get2() then task.spawn(function() Telemetry.push({t=time(),tag="Start_TweenLoad"}); Perturb.TweenLoad(4.0); Telemetry.push({t=time(),tag="End_TweenLoad"}); set2(false) end) end
end)
local c3,set3,get3,hit3=card(pageMain,"MoveTo Stress","Short waypoint hops via Humanoid:MoveTo.")
hit3.MouseButton1Click:Connect(function()
	set3(not get3()); if get3() then task.spawn(function() Telemetry.push({t=time(),tag="Start_MoveTo"}); Perturb.MoveToStress(6.0,10,0.14); Telemetry.push({t=time(),tag="End_MoveTo"}); set3(false) end) end
end)
local c4,set4,get4,hit4=card(pageMain,"Latency Heavy","Client-side send jitter (no packet tamper).")
hit4.MouseButton1Click:Connect(function()
	set4(not get4()); if get4() then
		local r=RS:FindFirstChild("ClientTick"); if not r then set4(false); Telemetry.push({t=time(),tag="ERROR_NoRemote"}); return end
		task.spawn(function()
			local function send(p) if r.FireServer then pcall(function() r:FireServer(p) end) end end
			local function payload() return {t=time(),pos=hrp.Position,vel=hrp.Velocity} end
			Telemetry.push({t=time(),tag="Start_Latency"}); Perturb.LatencySim(send,payload,8.0,80,60); Telemetry.push({t=time(),tag="End_Latency"}); set4(false)
		end)
	end
end)

-- Metrics page (compact labels)
local function metric(y,text) return new("TextLabel",{Text=text..": --",Font=Enum.Font.GothamSemibold,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=rgb(235,240,255),BackgroundTransparency=1,Position=UDim2.fromOffset(4,y),Size=UDim2.fromOffset(210,18)},pageMetrics) end
local mSpeed=metric(0,"Speed"); local mAccel=metric(20,"Accel"); local mState=metric(40,"State"); local mDev=metric(60,"Deviation"); local mJump=metric(80,"Jump/10s")

-- Logs page (tight scroll)
local log=new("ScrollingFrame",{Active=true,ScrollBarThickness=6,BackgroundColor3=rgb(28,30,40),BorderSizePixel=0,Size=UDim2.new(1,-(GAP*2),1,-(GAP*2)),Position=UDim2.fromOffset(GAP,GAP),CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},pageLogs)
new("UICorner",{CornerRadius=UDim.new(0,8)},log) new("UIStroke",{Color=rgb(60,64,84),Transparency=0.35},log) shadowUnder(log,8)
local ll=new("UIListLayout",{Padding=UDim.new(0,4)},log)
local function appendLog(t) new("TextLabel",{BackgroundTransparency=1,Font=Enum.Font.Code,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,TextColor3=rgb(210,214,230),Text=t,Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y},log) end

-- Config page: scenario dropdown + anchor + run + export
new("UIPadding",{PaddingTop=UDim.new(0,GAP),PaddingLeft=UDim.new(0,GAP),PaddingRight=UDim.new(0,GAP)},pageConfig)
local function tinyBtn(txt,w,parent)
	local b=new("TextButton",{Text=txt,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=rgb(235,240,255),AutoButtonColor=false,
		BackgroundColor3=rgb(48,52,66),Size=UDim2.fromOffset(w, 24)},parent or pageConfig)
	new("UICorner",{CornerRadius=UDim.new(0,8)},b) new("UIStroke",{Color=rgb(70,74,92),Transparency=0.35},b) shadowUnder(b,8) clickFX(b)
	return b
end
local contentWidth = content.Size.X.Offset-(GAP*2)
local scenario = SCENARIOS[1]
local dd = tinyBtn("Scenario: "..scenario, contentWidth)
dd.Position=UDim2.fromOffset(0,0)
local ddMenu=new("Frame",{Visible=false,BackgroundColor3=rgb(26,28,40),Position=UDim2.fromOffset(0,24+GAP),Size=UDim2.fromOffset(contentWidth, (#SCENARIOS*24)+8),ZIndex=content.ZIndex+2},pageConfig)
new("UICorner",{CornerRadius=UDim.new(0,8)},ddMenu) new("UIStroke",{Color=rgb(70,74,92),Transparency=0.35},ddMenu)
new("UIPadding",{PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6)},ddMenu)
local ml=new("UIListLayout",{Padding=UDim.new(0,4)},ddMenu)
for _,name in ipairs(SCENARIOS) do
	local it=tinyBtn(name, contentWidth-12, ddMenu)
	it.MouseButton1Click:Connect(function() scenario=name dd.Text="Scenario: "..name ddMenu.Visible=false end)
end
dd.MouseButton1Click:Connect(function() ddMenu.Visible=not ddMenu.Visible end)

local anchorBtn=tinyBtn("Reset Path Anchor", contentWidth)
anchorBtn.Position=UDim2.fromOffset(0, 24+GAP)
anchorBtn.MouseButton1Click:Connect(function() Constraint.pathAnchor=hrp.Position appendLog(("Anchor(%.1f,%.1f,%.1f)"):format(hrp.Position.X,hrp.Position.Y,hrp.Position.Z)) end)

local runScenarioBtn=tinyBtn("Run Scenario", contentWidth)
runScenarioBtn.Position=UDim2.fromOffset(0, (24+GAP)*2)
runScenarioBtn.MouseButton1Click:Connect(function()
	appendLog("Run: "..scenario) Telemetry.push({t=time(),tag="SCENARIO_START",name=scenario})
	(Campaign[scenario] or function() end)()
	Telemetry.push({t=time(),tag="SCENARIO_END",name=scenario}) appendLog("Done: "..scenario)
end)

local exportBtn=tinyBtn("Export JSON", contentWidth)
exportBtn.Position=UDim2.fromOffset(0, (24+GAP)*3)
exportBtn.MouseButton1Click:Connect(function()
	local j=HttpService:JSONEncode(Telemetry.buffer)
	print("-- EXPORT BEGIN --") print(j) print("-- EXPORT END --")
	appendLog(("Exported %d events"):format(#Telemetry.buffer))
end)

-- Tab routing
local pages={Main=pageMain, Metrics=pageMetrics, Logs=pageLogs, Config=pageConfig}
local function selectTab(name)
	for id,btn in pairs(tabs) do
		local act=(id==name)
		TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=act and rgb(60,64,84) or rgb(38,42,58), TextColor3=act and Color3.new(1,1,1) or rgb(230,236,255)}):Play()
		pages[id].Visible=act
	end
end
for id,btn in pairs(tabs) do btn.MouseButton1Click:Connect(function() selectTab(id) end) end
selectTab("Main")

-- Minimize/restore (NO BLUR)
local minimized=false local pill
local function restore()
	if pill then pill:Destroy() pill=nil end
	root.Visible=true minimized=false
end
local function minimize()
	root.Visible=false minimized=true
	pill=new("TextButton",{Text="RH",Font=Enum.Font.GothamSemibold,TextSize=12,TextColor3=rgb(22,26,34),AutoButtonColor=false,BackgroundColor3=rgb(140,230,190),Size=UDim2.fromOffset(36,20),Position=UDim2.fromOffset(24,24)},gui)
	new("UICorner",{CornerRadius=UDim.new(1,0)},pill) shadowUnder(pill,10) clickFX(pill)
	pill.MouseButton1Click:Connect(restore)
end
mini.MouseButton1Click:Connect(function() if minimized then restore() else minimize() end end)

-- Live metrics + checks + periodic flush
RunService.Heartbeat:Connect(function(dt)
	local v=hrp.Velocity; local speed=v.Magnitude
	local accel=(v-Constraint.lastV).Magnitude/math.max(dt,1/240); Constraint.lastV=v
	if speed>Limits.MaxSpeed then Telemetry.push({t=time(),tag="VIOLATION_Speed",speed=speed}) end
	if accel>Limits.MaxAccel then Telemetry.push({t=time(),tag="VIOLATION_Accel",accel=accel}) end
	if accel>Limits.MaxAccel then Telemetry.push({t=time(),tag="VIOLATION_Accel",accel=accel}) end
	if pruneJumps()>Limits.MaxJumpCadence then Telemetry.push({t=time(),tag="VIOLATION_JumpCadence",count=#Constraint.jumpTimes}) end

	local dev=(hrp.Position-Constraint.pathAnchor).Magnitude
	if dev>Limits.MaxPathDeviation then Telemetry.push({t=time(),tag="DEVIATION",deviation=dev}) end

	-- metrics @ ~4Hz
	gui:SetAttribute("_acc",(gui:GetAttribute("_acc") or 0)+dt)
	if (gui:GetAttribute("_acc") or 0) > 0.25 then
		gui:SetAttribute("_acc",0)
		mSpeed.Text = ("Speed: %.1f"):format(speed)
		mAccel.Text = ("Accel: %.1f"):format(accel)
		mState.Text = ("State: %s"):format(tostring(hum:GetState()))
		mDev.Text   = ("Deviation: %.1f"):format(dev)
		mJump.Text  = ("Jump/10s: %d"):format(#Constraint.jumpTimes)
	end

	-- periodic flush
	if time() - Telemetry.lastFlush >= Telemetry.flushInterval then
		Telemetry.lastFlush = time()
		print("-- TELEMETRY FLUSH --", HttpService:JSONEncode({
			n = #Telemetry.buffer,
			last = Telemetry.buffer[#Telemetry.buffer]
		}))
	end
end)

-- show default tab
selectTab("Main")
appendLog("Resilience Harness v4.0 ready.")
