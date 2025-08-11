--[[ 
Resilience UI — CLEAN REMAKE (client-side only)
- Left rail tabs (always visible), compact spacing, subtle shadows
- Ripple/squish button feedback
- Per-tab simple tween demo (UI box + optional Workspace.TweenTarget)
- No game/exploit logic. No blur.

Place as: StarterPlayerScripts/ResilienceUI.client.lua
]]--

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ===== THEME =====
local GAP, R, RAIL_W = 4, 10, 94
local WIN_W, WIN_H = 360, 236
local C_BG     = Color3.fromRGB(20,22,30)
local C_PANEL  = Color3.fromRGB(24,26,36)
local C_RAIL   = Color3.fromRGB(28,30,42)
local C_BTN    = Color3.fromRGB(38,42,58)
local C_BTN_ON = Color3.fromRGB(60,64,84)
local C_TEXT   = Color3.fromRGB(232,236,255)
local C_MUTED  = Color3.fromRGB(200,205,220)
local C_ACCENT = Color3.fromRGB(140,230,190)
local SHADOW   = "rbxassetid://13637412666"

-- ===== UTIL =====
local function shadow(u, pad)
	local s = Instance.new("ImageLabel")
	s.BackgroundTransparency = 1
	s.Image = SHADOW
	s.ImageColor3 = Color3.new(0,0,0)
	s.ImageTransparency = 0.78
	s.ScaleType = Enum.ScaleType.Slice
	s.SliceCenter = Rect.new(64,64,64,64)
	s.Size = UDim2.new(1,pad or 10,1,pad or 10)
	s.Position = UDim2.fromOffset(-((pad or 10)/2),-((pad or 10)/2))
	s.ZIndex = (u.ZIndex or 1)-1
	s.Parent = u
end

local function ripple(btn, inputPos)
	local rel = inputPos - btn.AbsolutePosition
	local c = Instance.new("Frame")
	c.BackgroundColor3 = Color3.new(1,1,1)
	c.BackgroundTransparency = 0.3
	c.Size = UDim2.fromOffset(0,0)
	c.ClipsDescendants = true
	c.ZIndex = btn.ZIndex + 3
	c.Parent = btn
	Instance.new("UICorner", c).CornerRadius = UDim.new(1,0)
	local max = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.6
	c.Position = UDim2.fromOffset(rel.X - max*0.5, rel.Y - max*0.5)
	TweenService:Create(c, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(max,max), BackgroundTransparency = 1
	}):Play()
	game:GetService("Debris"):AddItem(c, 0.24)
end

local function clickFX(btn)
	local scale = Instance.new("UIScale", btn); scale.Scale = 1
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.965}):Play()
			ripple(btn, i.Position)
		end
	end)
	btn.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(scale, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end)
end

-- ===== CLEAN SLATE =====
local old = PG:FindFirstChild("ResilienceUI")
if old then old:Destroy() end

-- ===== GUI ROOT =====
local SG = Instance.new("ScreenGui")
SG.Name = "ResilienceUI"
SG.IgnoreGuiInset = true
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = PG

local Root = Instance.new("Frame")
Root.Name = "Window"
Root.Size = UDim2.fromOffset(WIN_W, WIN_H)
Root.Position = UDim2.fromOffset(26, 26)
Root.BackgroundColor3 = C_BG
Root.BackgroundTransparency = 0.06
Root.ClipsDescendants = true
Root.Parent = SG
Instance.new("UICorner", Root).CornerRadius = UDim.new(0, R)
local st = Instance.new("UIStroke", Root); st.Color = Color3.fromRGB(60,64,84); st.Transparency = 0.45
shadow(Root, 12)

-- Topbar + drag + minimize
local Top = Instance.new("Frame", Root)
Top.Size = UDim2.new(1,0,0,26)
Top.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", Top)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamSemibold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextColor3 = C_TEXT
Title.Text = "Resilience UI"
Title.Position = UDim2.fromOffset(10,4)
Title.Size = UDim2.fromOffset(180,18)

local Mini = Instance.new("TextButton", Top)
Mini.Text = "–"
Mini.AutoButtonColor = false
Mini.Font = Enum.Font.GothamBold
Mini.TextSize = 16
Mini.TextColor3 = Color3.fromRGB(22,26,34)
Mini.BackgroundColor3 = C_ACCENT
Mini.Size = UDim2.fromOffset(24,18)
Mini.Position = UDim2.new(1,-28,0,4)
Instance.new("UICorner", Mini).CornerRadius = UDim.new(0,7)
shadow(Mini, 8)
clickFX(Mini)

do -- drag
	local dragging, startPos, dragStart
	Top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startPos = Vector2.new(Root.Position.X.Offset, Root.Position.Y.Offset)
			dragStart = i.Position
			i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			Root.Position = UDim2.fromOffset(startPos.X + d.X, startPos.Y + d.Y)
		end
	end)
end

local minimized, Pill = false, nil
local function restore()
	if Pill then Pill:Destroy() Pill = nil end
	Root.Visible = true; minimized = false
end
local function minimize()
	Root.Visible = false; minimized = true
	Pill = Instance.new("TextButton")
	Pill.Text = "RH"
	Pill.AutoButtonColor = false
	Pill.Font = Enum.Font.GothamSemibold
	Pill.TextSize = 12
	Pill.TextColor3 = Color3.fromRGB(22,26,34)
	Pill.BackgroundColor3 = C_ACCENT
	Pill.Size = UDim2.fromOffset(36,20)
	Pill.Position = UDim2.fromOffset(24,24)
	Pill.Parent = SG
	Instance.new("UICorner", Pill).CornerRadius = UDim.new(1,0)
	shadow(Pill, 10)
	clickFX(Pill)
	Pill.MouseButton1Click:Connect(restore)
end
Mini.MouseButton1Click:Connect(function() if minimized then restore() else minimize() end end)

-- ===== LEFT RAIL =====
local railH = WIN_H - 26 - GAP
local Rail = Instance.new("Frame", Root)
Rail.Name = "LeftRail"
Rail.Size = UDim2.fromOffset(RAIL_W, railH)
Rail.Position = UDim2.fromOffset(GAP, 26 + GAP)
Rail.BackgroundColor3 = C_RAIL
Rail.ClipsDescendants = true
Instance.new("UICorner", Rail).CornerRadius = UDim.new(0, R-2)
local rs = Instance.new("UIStroke", Rail); rs.Color = Color3.fromRGB(60,64,84); rs.Transparency = 0.35
shadow(Rail, 10)
local rpad = Instance.new("UIPadding", Rail); rpad.PaddingTop = UDim.new(0,GAP); rpad.PaddingBottom = UDim.new(0,GAP)
local rlist = Instance.new("UIListLayout", Rail); rlist.Padding = UDim.new(0,GAP); rlist.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function RailBtn(text)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.TextColor3 = C_TEXT
	b.AutoButtonColor = false
	b.BackgroundColor3 = C_BTN
	b.Size = UDim2.fromOffset(RAIL_W-16, 24)
	b.Parent = Rail
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
	local s = Instance.new("UIStroke", b); s.Color = Color3.fromRGB(70,74,92); s.Transparency = 0.35
	shadow(b, 8)
	clickFX(b)
	return b
end

local Tabs = {
	Dig      = RailBtn("Dig"),
	Jetpack  = RailBtn("Jetpack"),
	Farming  = RailBtn("Farming"),
	Spin     = RailBtn("Spin"),
	Treasure = RailBtn("Treasure"),
	Info     = RailBtn("Info"),
	Misc     = RailBtn("Misc"),
}

-- ===== CONTENT PANEL =====
local Content = Instance.new("Frame", Root)
Content.Name = "Content"
Content.Size = UDim2.fromOffset(WIN_W - RAIL_W - (GAP*3), railH)
Content.Position = UDim2.fromOffset(RAIL_W + GAP + GAP, 26 + GAP)
Content.BackgroundColor3 = C_PANEL
Content.ClipsDescendants = true
Instance.new("UICorner", Content).CornerRadius = UDim.new(0, R-2)
local cs = Instance.new("UIStroke", Content); cs.Color = Color3.fromRGB(60,64,84); cs.Transparency = 0.35
shadow(Content, 10)

local function Page(name)
	local p = Instance.new("Frame")
	p.Name = "Page_"..name
	p.BackgroundTransparency = 1
	p.Size = UDim2.fromScale(1,1)
	p.Visible = false
	p.Parent = Content
	local pad = Instance.new("UIPadding", p); pad.PaddingTop = UDim.new(0,GAP); pad.PaddingLeft = UDim.new(0,GAP); pad.PaddingRight = UDim.new(0,GAP)
	local list = Instance.new("UIListLayout", p); list.Padding = UDim.new(0,GAP)
	return p
end

local Pages = {
	Dig      = Page("Dig"),
	Jetpack  = Page("Jetpack"),
	Farming  = Page("Farming"),
	Spin     = Page("Spin"),
	Treasure = Page("Treasure"),
	Info     = Page("Info"),
	Misc     = Page("Misc"),
}

-- ===== CONTROLS (minimal, tidy) =====
local EASE_STYLES = {"Sine","Quad","Quart","Quint","Back","Bounce","Elastic","Cubic","Linear","Expo","Circular"}
local EASE_DIRS   = {"In","Out","InOut"}

local function Label(parent, txt)
	local l = Instance.new("TextLabel", parent)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = C_MUTED
	l.Text = txt
	l.Size = UDim2.new(1,0,0,14)
	return l
end

local function Section(parent, title)
	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(1,-(GAP*2),0,60)
	card.Position = UDim2.fromOffset(GAP,GAP)
	card.BackgroundColor3 = Color3.fromRGB(36,38,50)
	Instance.new("UICorner", card).CornerRadius = UDim.new(0,10)
	local s = Instance.new("UIStroke", card); s.Color = Color3.fromRGB(70,74,92); s.Transparency = 0.25
	shadow(card, 8)
	local pad = Instance.new("UIPadding", card); pad.PaddingTop = UDim.new(0,8); pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10); pad.PaddingBottom = UDim.new(0,8)
	local list = Instance.new("UIListLayout", card); list.Padding = UDim.new(0,6)
	local t = Instance.new("TextLabel", card); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamSemibold; t.TextSize = 14; t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = C_TEXT; t.Text = title; t.Size = UDim2.fromOffset(220,18)
	return card
end

local function Button(parent, txt, cb)
	local b = Instance.new("TextButton", parent)
	b.Text = txt
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(235,240,255)
	b.AutoButtonColor = false
	b.BackgroundColor3 = C_BTN
	b.Size = UDim2.new(1,0,0,24)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
	local s = Instance.new("UIStroke", b); s.Color = Color3.fromRGB(70,74,92); s.Transparency = 0.35
	shadow(b,8); clickFX(b)
	if cb then b.MouseButton1Click:Connect(cb) end
	return b
end

local function Slider(parent, labelText, min, max, default, onChange)
	local group = Instance.new("Frame", parent); group.Size = UDim2.new(1,0,0,36); group.BackgroundTransparency = 1
	local lab = Label(group, ("%s (%d–%d)"):format(labelText, min, max)); lab.Position = UDim2.fromOffset(0,0)
	local track = Instance.new("Frame", group); track.Size = UDim2.new(1,0,0,6); track.Position = UDim2.fromOffset(0,20); track.BackgroundColor3 = Color3.fromRGB(40,44,58)
	Instance.new("UICorner", track).CornerRadius = UDim.new(0,3)
	local fill = Instance.new("Frame", track); fill.Size = UDim2.new(0,0,1,0); fill.BackgroundColor3 = C_ACCENT
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0,3)
	local knob = Instance.new("Frame", fill); knob.Size = UDim2.fromOffset(12,12); knob.Position = UDim2.fromOffset(0,-3); knob.BackgroundColor3 = Color3.fromRGB(245,247,255)
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
	local value = default or min
	local function setVal(v)
		v = math.clamp(v, min, max); value = v
		local a = (v - min) / (max - min)
		fill.Size = UDim2.new(a,0,1,0)
		if onChange then onChange(v) end
	end
	setVal(value)
	local dragging = false
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
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
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then dragging=false end
	end)
	return {Set = setVal, Get = function() return value end}
end

local function Dropdown(parent, labelText, options, default, onPick)
	local row = Instance.new("Frame", parent); row.Size = UDim2.new(1,0,0,26); row.BackgroundTransparency = 1
	local lab = Instance.new("TextLabel", row); lab.BackgroundTransparency = 1; lab.Font = Enum.Font.Gotham; lab.TextSize = 12; lab.TextXAlignment = Enum.TextXAlignment.Left
	lab.TextColor3 = C_MUTED; lab.Size = UDim2.new(0.5,-4,1,0); lab.Text = labelText
	local btn = Instance.new("TextButton", row); btn.Text = ""; btn.AutoButtonColor = false; btn.BackgroundColor3 = C_BTN; btn.Size = UDim2.new(0.5,0,1,0); btn.Position = UDim2.new(0.5,0,0,0)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8); clickFX(btn)
	local txt = Instance.new("TextLabel", btn); txt.BackgroundTransparency=1; txt.Font=Enum.Font.Gotham; txt.TextSize=12; txt.TextColor3=C_TEXT; txt.Size=UDim2.fromScale(1,1); txt.Text = default or options[1]
	local menu = Instance.new("Frame", parent); menu.Visible=false; menu.BackgroundColor3 = C_PANEL; menu.Size = UDim2.new(0, 140, 0, (#options*22)+8)
	Instance.new("UICorner", menu).CornerRadius = UDim.new(0,8)
	local ml = Instance.new("UIListLayout", menu); ml.Padding = UDim.new(0,4)
	btn.MouseButton1Click:Connect(function()
		menu.Position = UDim2.fromOffset(btn.AbsolutePosition.X - parent.AbsolutePosition.X, row.AbsolutePosition.Y - parent.AbsolutePosition.Y + row.AbsoluteSize.Y + 4)
		menu.Visible = not menu.Visible
	end)
	for _,opt in ipairs(options) do
		local o = Button(menu, opt, function()
			txt.Text = opt
			menu.Visible = false
			if onPick then onPick(opt) end
		end)
		o.Size = UDim2.new(1,-8,0,22)
	end
	return {Get=function() return txt.Text end, Set=function(v) txt.Text=v end, Menu=menu}
end

-- ===== DEMO HELPERS =====
local function getEase(style, dir)
	return Enum.EasingStyle[style] or Enum.EasingStyle.Sine, Enum.EasingDirection[dir] or Enum.EasingDirection.Out
end

local function makeDemoBox(parent)
	local b = Instance.new("Frame", parent)
	b.Name = "Demo"
	b.Size = UDim2.fromOffset(28,28)
	b.Position = UDim2.fromOffset(10, 40)
	b.BackgroundColor3 = C_ACCENT
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	shadow(b, 8)
	return b
end

local function findWorldTarget()
	local ok, p = pcall(function() return workspace:FindFirstChild("TweenTarget") end)
	return (ok and p and p:IsA("BasePart")) and p or nil
end

local function tweenUIBox(box, t, es, ed, sizePx, movePx, col)
	if not box then return end
	local style, dir = getEase(es, ed)
	TweenService:Create(box, TweenInfo.new(t, style, dir), {
		Size = UDim2.fromOffset(sizePx, sizePx),
		Position = UDim2.fromOffset(10 + movePx, 40 + movePx),
		BackgroundColor3 = col
	}):Play()
end

local function tweenWorldPart(part, t, es, ed, dPos, scale, col)
	if not part then return end
	local style, dir = getEase(es, ed)
	local goal = {Color = col, Size = part.Size * scale}
	if part.Anchored then goal.Position = part.Position + dPos end
	TweenService:Create(part, TweenInfo.new(t, style, dir), goal):Play()
end

local function buildTweenControls(parent, tag)
	local sec = Section(parent, tag .. " Tweens")
	local ddStyle = Dropdown(sec, "Easing Style", EASE_STYLES, "Sine")
	local ddDir   = Dropdown(sec, "Easing Direction", EASE_DIRS, "Out")
	local durS    = Slider(sec, "Duration x10 (s)", 5, 60, 18)      -- /10
	local sizeS   = Slider(sec, "UI Size (px)", 16, 96, 36)
	local moveS   = Slider(sec, "UI Move (px)", 0, 64, 12)
	local wPosS   = Slider(sec, "World ΔPos (studs)", 0, 50, 10)
	local wScaleS = Slider(sec, "World Scale (%)", 50, 200, 120)

	local colSec  = Section(parent, "Color")
	local ddCol   = Dropdown(colSec, "Preset", {"Mint","Sky","Peach","Violet","Lemon"}, "Mint")
	local function col(p)
		if p=="Mint" then return Color3.fromRGB(120,230,190)
		elseif p=="Sky" then return Color3.fromRGB(110,170,255)
		elseif p=="Peach" then return Color3.fromRGB(255,170,130)
		elseif p=="Violet" then return Color3.fromRGB(185,155,255)
		elseif p=="Lemon" then return Color3.fromRGB(245,230,120)
		end
		return C_ACCENT
	end

	local act = Section(parent, "Actions")
	local bUI    = Button(act, "Tween UI Box")
	local bWorld = Button(act, "Tween Workspace.TweenTarget")
	local bBoth  = Button(act, "Tween Both")

	local demo = parent:FindFirstChild("Demo") or makeDemoBox(parent)

	local function runUI()
		tweenUIBox(demo, durS.Get()/10, ddStyle.Get(), ddDir.Get(), sizeS.Get(), moveS.Get(), col(ddCol.Get()))
	end
	local function runWorld()
		local tgt = findWorldTarget()
		if not tgt then print("No Workspace.TweenTarget (optional)"); return end
		tweenWorldPart(tgt, durS.Get()/10, ddStyle.Get(), ddDir.Get(), Vector3.new(wPosS.Get(),0,wPosS.Get()), wScaleS.Get()/100, col(ddCol.Get()))
	end

	bUI.MouseButton1Click:Connect(runUI)
	bWorld.MouseButton1Click:Connect(runWorld)
	bBoth.MouseButton1Click:Connect(function() runUI(); runWorld() end)
end

-- ===== PAGES =====
for name, frame in pairs(Pages) do
	if name ~= "Info" and name ~= "Misc" then
		buildTweenControls(frame, name)
	end
end

-- Info
do
	local f = Pages.Info
	local a = Section(f, "About")
	Label(a, "Resilience UI — clean client UI.")
	Label(a, "Left tabs, tight spacing, ripple, subtle shadows.")
	Label(a, "Drop a BasePart named 'TweenTarget' in Workspace to test world tweens.")
	local stats = Section(f, "Stats")
	local fps = Label(stats, "FPS: --")
	local acc, frames, last = 0, 0, os.clock()
	RunService.Heartbeat:Connect(function(dt)
		acc += dt; frames += 1
		if acc >= 0.5 then
			local now = os.clock()
			local fpsVal = math.floor(frames / (now - last))
			fps.Text = "FPS: " .. fpsVal
			acc, frames, last = 0, 0, now
		end
	end)
end

-- Misc
do
	local f = Pages.Misc
	local m = Section(f, "Misc")
	local demo = makeDemoBox(f)
	local cycling, spinConn, cycleConn = false, nil, nil

	local tCycle = Button(m, "Toggle UI Color Cycle", function()
		cycling = not cycling
		if cycling then
			local h = 0
			cycleConn = RunService.Heartbeat:Connect(function(dt)
				if not cycling then return end
				h = (h + dt*0.15) % 1
				demo.BackgroundColor3 = Color3.fromHSV(h, 0.6, 1)
			end)
		else
			if cycleConn then cycleConn:Disconnect() cycleConn=nil end
		end
	end)

	local tSpin = Button(m, "Toggle Spin TweenTarget", function()
		if spinConn then spinConn:Disconnect() spinConn = nil return end
		spinConn = RunService.Heartbeat:Connect(function(dt)
			local tgt = findWorldTarget()
			if tgt and tgt:IsA("BasePart") then
				local ang = math.rad(90)*dt
				tgt.CFrame = tgt.CFrame * CFrame.Angles(0, ang, 0)
			end
		end)
	end)

	local w = Section(f, "Window / Target")
	Button(w, "Reset Window Position", function() Root.Position = UDim2.fromOffset(26,26) end)
	Button(w, "Create Workspace.TweenTarget", function()
		if workspace:FindFirstChild("TweenTarget") then return end
		local p = Instance.new("Part")
		p.Name = "TweenTarget"; p.Anchored = true; p.Size = Vector3.new(4,4,4)
		p.Color = C_ACCENT; p.Material = Enum.Material.SmoothPlastic
		local cam = workspace.CurrentCamera
		p.CFrame = CFrame.new(cam.CFrame.Position + cam.CFrame.LookVector*12)
		p.Parent = workspace
	end)

	-- clean up when hiding page
	f:GetPropertyChangedSignal("Visible"):Connect(function()
		if not f.Visible then
			cycling = false
			if cycleConn then cycleConn:Disconnect() cycleConn=nil end
			if spinConn then spinConn:Disconnect() spinConn=nil end
		end
	end)
end

-- ===== TAB ROUTING =====
local function selectTab(name)
	for id, btn in pairs(Tabs) do
		local on = (id == name)
		TweenService:Create(btn, TweenInfo.new(0.10), {
			BackgroundColor3 = on and C_BTN_ON or C_BTN,
			TextColor3       = on and Color3.new(1,1,1) or C_TEXT
		}):Play()
		Pages[id].Visible = on
	end
end
for id, btn in pairs(Tabs) do
	btn.MouseButton1Click:Connect(function() selectTab(id) end)
end
selectTab("Dig")
