-- Resilience UI v4.1 — compact, polished, left-rail tabs (client-side only)
-- minimal layers · tiny gaps · soft shadows · ripple/squish · no background blur

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

-- ========= THEME / TWEAKS =========
local GAP = 6                 -- tiny spacing
local R   = 10                -- corner radius
local RAIL_W = 96             -- left rail width
local WIN_W, WIN_H = 360, 240 -- window size
local C_BG     = Color3.fromRGB(20,22,30)
local C_RAIL   = Color3.fromRGB(28,30,42)
local C_BTN    = Color3.fromRGB(38,42,58)
local C_BTN_ON = Color3.fromRGB(60,64,84)
local C_PANEL  = Color3.fromRGB(24,26,36)
local C_TEXT   = Color3.fromRGB(232,236,255)
local C_MUTED  = Color3.fromRGB(210,214,230)
local C_ACCENT = Color3.fromRGB(140,230,190)
local SHADOW   = "rbxassetid://13637412666"

-- ========= tiny helpers =========
local function shadowUnder(ui, pad)
	local p = pad or 10
	local s = Instance.new("ImageLabel")
	s.BackgroundTransparency = 1
	s.Image = SHADOW
	s.ImageColor3 = Color3.new(0,0,0)
	s.ImageTransparency = 0.76
	s.ScaleType = Enum.ScaleType.Slice
	s.SliceCenter = Rect.new(64,64,64,64)
	s.ZIndex = (ui.ZIndex or 1) - 1
	s.Size = UDim2.new(1,p,1,p)
	s.Position = UDim2.fromOffset(-p/2, -p/2)
	s.Parent = ui
	return s
end

local function clickFX(btn)
	btn.ClipsDescendants = true
	local s = Instance.new("UIScale"); s.Scale = 1; s.Parent = btn
	btn.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			TweenService:Create(s, TweenInfo.new(0.06, Enum.EasingStyle.Quad), {Scale=0.96}):Play()
			local rel = i.Position - btn.AbsolutePosition
			local ripple = Instance.new("Frame"); ripple.Size = UDim2.fromOffset(0,0); ripple.BackgroundColor3 = Color3.new(1,1,1)
			ripple.BackgroundTransparency = 0.3; ripple.ZIndex = btn.ZIndex + 2; ripple.Parent = btn
			Instance.new("UICorner", ripple).CornerRadius = UDim.new(1,0)
			local max = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.6
			ripple.Position = UDim2.fromOffset(rel.X - max*0.5, rel.Y - max*0.5)
			TweenService:Create(ripple, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(max,max), BackgroundTransparency = 1
			}):Play()
			game:GetService("Debris"):AddItem(ripple, 0.24)
		end
	end)
	btn.InputEnded:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			TweenService:Create(s, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=1}):Play()
		end
	end)
end

-- ========= fresh UI (remove any old) =========
do local old = pg:FindFirstChild("ResilienceHarnessUI"); if old then old:Destroy() end end

local gui = Instance.new("ScreenGui")
gui.Name = "ResilienceHarnessUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

-- ========= window =========
local root = Instance.new("Frame")
root.Name = "RH_Root"
root.Size = UDim2.fromOffset(WIN_W, WIN_H)
root.Position = UDim2.fromOffset(26, 26)
root.BackgroundColor3 = C_BG
root.BackgroundTransparency = 0.08
root.BorderSizePixel = 0
root.ClipsDescendants = true
root.Parent = gui
Instance.new("UICorner", root).CornerRadius = UDim.new(0, R)
local wStroke = Instance.new("UIStroke", root); wStroke.Color = Color3.fromRGB(60,64,84); wStroke.Transparency = 0.45
shadowUnder(root, 12)

-- topbar + drag
local top = Instance.new("Frame"); top.Size = UDim2.new(1,0,0,28); top.BackgroundTransparency=1; top.Parent = root
local title = Instance.new("TextLabel")
title.BackgroundTransparency=1; title.Font=Enum.Font.GothamSemibold; title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left
title.TextColor3=C_TEXT; title.Text="Resilience Harness"; title.Position=UDim2.fromOffset(10,5); title.Size=UDim2.fromOffset(200,18); title.Parent=top
local mini = Instance.new("TextButton")
mini.Text="–"; mini.Font=Enum.Font.GothamBold; mini.TextSize=16; mini.TextColor3=Color3.fromRGB(22,26,34)
mini.AutoButtonColor=false; mini.BackgroundColor3=C_ACCENT; mini.Size=UDim2.fromOffset(24,18); mini.Position=UDim2.new(1,-28,0,5); mini.ZIndex=2; mini.Parent=top
Instance.new("UICorner", mini).CornerRadius = UDim.new(0,7); shadowUnder(mini,8); clickFX(mini)

do -- drag
	local dragging=false; local dragStart; local startPos
	top.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			dragging=true; dragStart=i.Position; startPos=Vector2.new(root.Position.X.Offset, root.Position.Y.Offset)
			i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
			local d=i.Position-dragStart; root.Position=UDim2.fromOffset(startPos.X+d.X, startPos.Y+d.Y)
		end
	end)
end

-- ========= left rail (tabs) =========
local railH = WIN_H - 28 - GAP
local rail = Instance.new("Frame")
rail.Name = "LeftRail"
rail.Size = UDim2.fromOffset(RAIL_W, railH)
rail.Position = UDim2.fromOffset(GAP, 28+GAP)
rail.BackgroundColor3 = C_RAIL
rail.BorderSizePixel = 0
rail.ClipsDescendants = true
rail.Parent = root
Instance.new("UICorner", rail).CornerRadius = UDim.new(0, R-2)
local rStroke = Instance.new("UIStroke", rail); rStroke.Color = Color3.fromRGB(60,64,84); rStroke.Transparency = 0.35
shadowUnder(rail,10)
local pad = Instance.new("UIPadding", rail); pad.PaddingTop=UDim.new(0,GAP); pad.PaddingBottom=UDim.new(0,GAP)
local rList = Instance.new("UIListLayout", rail); rList.Padding=UDim.new(0,GAP); rList.HorizontalAlignment=Enum.HorizontalAlignment.Center

local function railBtn(text)
	local b = Instance.new("TextButton")
	b.Text = text; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.TextColor3=C_TEXT
	b.AutoButtonColor=false; b.BackgroundColor3=C_BTN
	b.Size = UDim2.fromOffset(RAIL_W-16, 24)
	b.Parent = rail
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", b); s.Color = Color3.fromRGB(70,74,92); s.Transparency = 0.35
	shadowUnder(b,8); clickFX(b)
	return b
end

local Tabs = {
	Main    = railBtn("Main"),
	Metrics = railBtn("Metrics"),
	Logs    = railBtn("Logs"),
	Config  = railBtn("Config"),
}

-- ========= content panel =========
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.fromOffset(WIN_W - RAIL_W - (GAP*3), railH)
content.Position = UDim2.fromOffset(RAIL_W + GAP + GAP, 28 + GAP)
content.BackgroundColor3 = C_PANEL
content.BorderSizePixel = 0
content.ClipsDescendants = true
content.Parent = root
Instance.new("UICorner", content).CornerRadius = UDim.new(0, R-2)
local cStroke = Instance.new("UIStroke", content); cStroke.Color=Color3.fromRGB(60,64,84); cStroke.Transparency=0.35
shadowUnder(content,10)

local function page(name)
	local p = Instance.new("Frame")
	p.Name="Page_"..name
	p.Size = UDim2.fromScale(1,1)
	p.BackgroundTransparency = 1
	p.Visible = false
	p.Parent = content
	return p
end
local Pages = {
	Main    = page("Main"),
	Metrics = page("Metrics"),
	Logs    = page("Logs"),
	Config  = page("Config"),
}

-- ========= simple section/card helpers =========
local function section(parent, titleText)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, - (GAP*2), 0, 60)
	card.Position = UDim2.fromOffset(GAP,GAP)
	card.BackgroundColor3 = Color3.fromRGB(36,38,50)
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", card); s.Color = Color3.fromRGB(70,74,92); s.Transparency = 0.25
	shadowUnder(card,8)
	local pad = Instance.new("UIPadding", card); pad.PaddingTop=UDim.new(0,8); pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,8)
	local lst = Instance.new("UIListLayout", card); lst.Padding=UDim.new(0,6)
	local title = Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Font=Enum.Font.GothamSemibold; title.TextSize=14
	title.TextXAlignment=Enum.TextXAlignment.Left; title.TextColor3=C_TEXT; title.Text=titleText; title.Size=UDim2.fromOffset(220,18); title.Parent=card
	return card
end

local function button(parent, text, onClick)
	local b = Instance.new("TextButton")
	b.Text = text; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.TextColor3=Color3.fromRGB(235,240,255)
	b.AutoButtonColor=false; b.BackgroundColor3=C_BTN; b.Size=UDim2.new(1,0,0,24); b.Parent=parent
	Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
	local s=Instance.new("UIStroke", b); s.Color=Color3.fromRGB(70,74,92); s.Transparency=0.35
	shadowUnder(b,8); clickFX(b)
	if onClick then b.MouseButton1Click:Connect(onClick) end
	return b
end

local function label(parent, text)
	local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Font=Enum.Font.Gotham; l.TextSize=12; l.TextXAlignment=Enum.TextXAlignment.Left
	l.TextWrapped=true; l.TextColor3=C_MUTED; l.Size=UDim2.new(1,0,0,14); l.Text=text; l.Parent=parent; return l
end

-- ========= populate pages (visual placeholders—hook your logic where noted) =========
do -- Main
	local pad = Instance.new("UIPadding", Pages.Main); pad.PaddingTop=UDim.new(0,GAP); pad.PaddingLeft=UDim.new(0,GAP); pad.PaddingRight=UDim.new(0,GAP)
	local list = Instance.new("UIListLayout", Pages.Main); list.Padding=UDim.new(0,GAP)

	local s1 = section(Pages.Main, "Stress Actions")
	button(s1, "Input Burst", function() print("[UI] Input Burst clicked") end)   -- hook your action
	button(s1, "Tween Load",  function() print("[UI] Tween Load clicked") end)    -- hook your action
	button(s1, "MoveTo Stress", function() print("[UI] MoveTo clicked") end)      -- hook your action

	local s2 = section(Pages.Main, "Scenarios")
	button(s2, "Run: Sprint/Jump Jitter", function() print("[UI] Scenario Jitter") end)
	button(s2, "Run: Latency Heavy", function() print("[UI] Scenario Latency") end)
	button(s2, "Reset Path Anchor", function() print("[UI] Reset Anchor") end)
end

do -- Metrics (just labels you can set from your loop)
	local pad = Instance.new("UIPadding", Pages.Metrics); pad.PaddingTop=UDim.new(0,GAP); pad.PaddingLeft=UDim.new(0,GAP)
	local function metric(y, text)
		local l=Instance.new("TextLabel", Pages.Metrics)
		l.Text=text..": --"; l.Font=Enum.Font.GothamSemibold; l.TextSize=13; l.TextXAlignment=Enum.TextXAlignment.Left
		l.TextColor3=C_TEXT; l.BackgroundTransparency=1; l.Position=UDim2.fromOffset(4,y); l.Size=UDim2.fromOffset(220,18)
		return l
	end
	metric(0,"Speed"); metric(20,"Accel"); metric(40,"State"); metric(60,"Deviation"); metric(80,"Jump/10s")
end

do -- Logs
	local log = Instance.new("ScrollingFrame")
	log.Active=true; log.ScrollBarThickness=6; log.BackgroundColor3=Color3.fromRGB(28,30,40); log.BorderSizePixel=0
	log.Size=UDim2.new(1,-(GAP*2),1,-(GAP*2)); log.Position=UDim2.fromOffset(GAP,GAP)
	log.CanvasSize=UDim2.new(0,0,0,0); log.AutomaticCanvasSize=Enum.AutomaticSize.Y; log.Parent=Pages.Logs
	Instance.new("UICorner", log).CornerRadius=UDim.new(0,8)
	local s=Instance.new("UIStroke", log); s.Color=Color3.fromRGB(60,64,84); s.Transparency=0.35
	shadowUnder(log,8)
	local list=Instance.new("UIListLayout", log); list.Padding=UDim.new(0,4)
	local function add(t) local L=Instance.new("TextLabel", log); L.BackgroundTransparency=1; L.Font=Enum.Font.Code; L.TextSize=12; L.TextXAlignment=Enum.TextXAlignment.Left; L.TextYAlignment=Enum.TextYAlignment.Top; L.TextWrapped=true; L.TextColor3=C_MUTED; L.Text=t; L.Size=UDim2.new(1,-8,0,0); L.AutomaticSize=Enum.AutomaticSize.Y end
	add("UI ready."); add("Use Main tab actions to run scenarios.")
end

do -- Config
	local pad = Instance.new("UIPadding", Pages.Config); pad.PaddingTop=UDim.new(0,GAP); pad.PaddingLeft=UDim.new(0,GAP); pad.PaddingRight=UDim.new(0,GAP)
	local s = section(Pages.Config, "Settings")
	label(s, "Tune values in your logic loop; this is just the shell UI.")
	button(s, "Export JSON", function() print("[UI] Export click") end)
end

-- ========= tab routing =========
local function selectTab(name)
	for id,btn in pairs(Tabs) do
		local on = (id == name)
		TweenService:Create(btn, TweenInfo.new(0.10), {
			BackgroundColor3 = on and C_BTN_ON or C_BTN,
			TextColor3 = on and Color3.new(1,1,1) or C_TEXT
		}):Play()
		Pages[id].Visible = on
	end
end
for id,btn in pairs(Tabs) do btn.MouseButton1Click:Connect(function() selectTab(id) end) end
selectTab("Main")

-- ========= minimize (no blur) =========
local minimized=false local pill
local function restore() if pill then pill:Destroy() pill=nil end root.Visible=true minimized=false end
local function minimize()
	root.Visible=false minimized=true
	pill = Instance.new("TextButton")
	pill.Text="RH"; pill.Font=Enum.Font.GothamSemibold; pill.TextSize=12; pill.TextColor3=Color3.fromRGB(22,26,34)
	pill.AutoButtonColor=false; pill.BackgroundColor3=C_ACCENT
	pill.Size=UDim2.fromOffset(36,20); pill.Position=UDim2.fromOffset(24,24); pill.Parent=gui
	Instance.new("UICorner", pill).CornerRadius=UDim.new(1,0)
	clickFX(pill)
	pill.MouseButton1Click:Connect(restore)
end
clickFX(mini)
mini.MouseButton1Click:Connect(function() if minimized then restore() else minimize() end end)
