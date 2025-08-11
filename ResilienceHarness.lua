--[[
  Overflow-Style Harness UI (Visuals Only) — Full Client Script
  Tabs: Dig, Jetpack, Farming, Spin Wheel, Treasure, Info, Misc
  Each main tab includes simple, customizable tween demos that animate:
    - A local UI box (safe visual)
    - (Optional) a Workspace part named "TweenTarget" if present (position/size/color wiggles)

  100% client-side, no remotes, no hooks, no blur. Left-rail tabs, compact spacing, subtle shadows,
  button ripple/squish, dropdowns + sliders for tween settings.

  Place as: StarterPlayerScripts/OverflowHarnessUI.client.lua
]]

--// Services
local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local UIS           = game:GetService("UserInputService")
local RunService    = game:GetService("RunService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

-- =========================================
-- THEME / LAYOUT
-- =========================================
local GAP    = 4                 -- tight spacing (matches compact refs)
local R      = 10                -- corner radius
local RAIL_W = 96                -- left rail width
local WIN_W, WIN_H = 360, 240    -- compact window

local C_BG     = Color3.fromRGB(20,22,30)
local C_RAIL   = Color3.fromRGB(28,30,42)
local C_BTN    = Color3.fromRGB(38,42,58)
local C_BTN_ON = Color3.fromRGB(60,64,84)
local C_PANEL  = Color3.fromRGB(24,26,36)
local C_TEXT   = Color3.fromRGB(232,236,255)
local C_MUTED  = Color3.fromRGB(210,214,230)
local C_ACCENT = Color3.fromRGB(140,230,190)
local SHADOW   = "rbxassetid://13637412666"

-- Easing presets
local EASE_STYLES = {
	"Linear","Sine","Quad","Quart","Quint","Expo","Cubic","Back","Bounce","Elastic","Circular"
}
local EASE_DIRECTIONS = {"In","Out","InOut"}

local function getEase(styleName, dirName)
	local style = Enum.EasingStyle[styleName] or Enum.EasingStyle.Sine
	local dir   = Enum.EasingDirection[dirName] or Enum.EasingDirection.Out
	return style, dir
end

-- =========================================
-- UTILS
-- =========================================
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
			-- ripple
			local rel = i.Position - btn.AbsolutePosition
			local ripple = Instance.new("Frame")
			ripple.Size = UDim2.fromOffset(0,0)
			ripple.BackgroundColor3 = Color3.new(1,1,1)
			ripple.BackgroundTransparency = 0.3
			ripple.ZIndex = btn.ZIndex + 2
			ripple.Parent = btn
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

local function tinyButton(parent, text, height)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(235,240,255)
	b.AutoButtonColor = false
	b.BackgroundColor3 = C_BTN
	b.Size = UDim2.new(1,0,0,height or 24)
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
	local s=Instance.new("UIStroke", b); s.Color=Color3.fromRGB(70,74,92); s.Transparency=0.35
	shadowUnder(b,8); clickFX(b)
	return b
end

local function labeled(parent, txt)
	local l=Instance.new("TextLabel")
	l.BackgroundTransparency=1
	l.TextXAlignment=Enum.TextXAlignment.Left
	l.TextWrapped=true
	l.Font=Enum.Font.Gotham
	l.TextSize=12
	l.TextColor3=C_MUTED
	l.Text=txt
	l.Size=UDim2.new(1,0,0,14)
	l.Parent=parent
	return l
end

local function section(parent, titleText)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1,-(GAP*2),0,60)
	card.Position = UDim2.fromOffset(GAP,GAP)
	card.BackgroundColor3 = Color3.fromRGB(36,38,50)
	card.BorderSizePixel=0
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0,10)
	local s=Instance.new("UIStroke", card); s.Color=Color3.fromRGB(70,74,92); s.Transparency=0.25
	shadowUnder(card,8)
	local pad = Instance.new("UIPadding", card); pad.PaddingTop=UDim.new(0,8); pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,8)
	local list=Instance.new("UIListLayout", card); list.Padding=UDim.new(0,6)
	local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Font=Enum.Font.GothamSemibold; title.TextSize=14
	title.TextXAlignment=Enum.TextXAlignment.Left; title.TextColor3=C_TEXT; title.Text=titleText; title.Size=UDim2.fromOffset(220,18); title.Parent=card
	return card
end

local function dropdown(parent, labelText, options, onPick)
	local wrapper = Instance.new("Frame"); wrapper.Size=UDim2.new(1,0,0,26); wrapper.BackgroundTransparency=1; wrapper.Parent=parent
	local lab = Instance.new("TextLabel"); lab.BackgroundTransparency=1; lab.Font=Enum.Font.Gotham; lab.TextSize=12; lab.TextXAlignment=Enum.TextXAlignment.Left
	lab.TextColor3=C_MUTED; lab.Text=labelText; lab.Size=UDim2.new(0.5, -4, 1, 0); lab.Parent=wrapper
	local btn = Instance.new("TextButton"); btn.Text=""; btn.AutoButtonColor=false; btn.BackgroundColor3=C_BTN; btn.Size=UDim2.new(0.5, 0, 1, 0); btn.Position=UDim2.new(0.5,0,0,0); btn.Parent=wrapper
	Instance.new("UICorner", btn).CornerRadius=UDim.new(0,8); clickFX(btn)
	local btnText=Instance.new("TextLabel", btn); btnText.BackgroundTransparency=1; btnText.Font=Enum.Font.Gotham; btnText.TextSize=12; btnText.Text=options[1]; btnText.TextColor3=C_TEXT; btnText.Size=UDim2.fromScale(1,1)

	local menu = Instance.new("Frame"); menu.Visible=false; menu.BackgroundColor3=C_PANEL; menu.Size=UDim2.new(0, 140, 0, (#options*22)+8); menu.Parent=parent
	Instance.new("UICorner", menu).CornerRadius=UDim.new(0,8)
	local ml=Instance.new("UIListLayout", menu); ml.Padding=UDim.new(0,4)
	menu.ZIndex = (parent.ZIndex or 1) + 5

	btn.MouseButton1Click:Connect(function()
		menu.Position = UDim2.fromOffset(btn.AbsolutePosition.X - parent.AbsolutePosition.X, wrapper.AbsolutePosition.Y - parent.AbsolutePosition.Y + wrapper.AbsoluteSize.Y + 4)
		menu.Visible = not menu.Visible
	end)
	for _,opt in ipairs(options) do
		local o = tinyButton(menu, opt, 22)
		o.Size = UDim2.new(1, -8, 0, 22)
		o.MouseButton1Click:Connect(function()
			btnText.Text = opt
			menu.Visible=false
			if onPick then onPick(opt) end
		end)
	end
	return {
		Set=function(t) btnText.Text=t end,
		Get=function() return btnText.Text end,
		Menu=menu
	}
end

local function slider(parent, labelText, min, max, default, onChange)
	local pack = Instance.new("Frame"); pack.Size=UDim2.new(1,0,0,36); pack.BackgroundTransparency=1; pack.Parent=parent
	local lab = labeled(pack, ("%s (%d–%d)"):format(labelText,min,max)); lab.Position=UDim2.fromOffset(0,0)
	local track = Instance.new("Frame"); track.Size=UDim2.new(1,0,0,6); track.Position=UDim2.fromOffset(0,20); track.BackgroundColor3=Color3.fromRGB(40,44,58); track.Parent=pack
	Instance.new("UICorner", track).CornerRadius=UDim.new(0,3)
	local fill = Instance.new("Frame"); fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=C_ACCENT; fill.Parent=track
	Instance.new("UICorner", fill).CornerRadius=UDim.new(0,3)
	local knob = Instance.new("Frame"); knob.Size=UDim2.fromOffset(12,12); knob.Position=UDim2.fromOffset(0,-3); knob.BackgroundColor3=Color3.fromRGB(245,247,255); knob.Parent=fill
	Instance.new("UICorner", knob).CornerRadius=UDim.new(1,0)

	local value = default or min
	local function setVal(v)
		v = math.clamp(v, min, max); value=v
		local a = (v - min) / (max - min)
		fill.Size = UDim2.new(a,0,1,0)
		if onChange then onChange(v) end
	end
	setVal(value)

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
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then dragging=false end
	end)

	return { Set=setVal, Get=function() return value end }
end

-- Simple toggle control
local function toggle(parent, text, onChange)
	local row = Instance.new("Frame"); row.Size=UDim2.new(1,0,0,26); row.BackgroundTransparency=1; row.Parent=parent
	local label=Instance.new("TextLabel"); label.BackgroundTransparency=1; label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=12
	label.TextXAlignment=Enum.TextXAlignment.Left; label.TextColor3=C_MUTED; label.Size=UDim2.new(1,-70,1,0); label.Parent=row
	local sw = Instance.new("Frame"); sw.Size=UDim2.fromOffset(52,22); sw.Position=UDim2.new(1,-58,0.5,-11); sw.BackgroundColor3=Color3.fromRGB(52,56,70); sw.Parent=row
	Instance.new("UICorner", sw).CornerRadius=UDim.new(1,0)
	local knob = Instance.new("Frame"); knob.Size=UDim2.fromOffset(18,18); knob.Position=UDim2.fromOffset(2,2); knob.BackgroundColor3=Color3.fromRGB(240,240,245); knob.Parent=sw
	Instance.new("UICorner", knob).CornerRadius=UDim.new(1,0)
	local hit=Instance.new("TextButton"); hit.Text=""; hit.BackgroundTransparency=1; hit.Size=UDim2.fromScale(1,1); hit.Parent=sw
	clickFX(hit)
	local state=false
	local function set(v)
		state=v
		TweenService:Create(sw, TweenInfo.new(0.12), {BackgroundColor3 = v and C_ACCENT or Color3.fromRGB(52,56,70)}):Play()
		TweenService:Create(knob, TweenInfo.new(0.12), {Position = v and UDim2.fromOffset(32,2) or UDim2.fromOffset(2,2)}):Play()
		if onChange then onChange(v) end
	end
	hit.MouseButton1Click:Connect(function() set(not state) end)
	return {Set=set, Get=function() return state end}
end

-- Toast (minimal)
local ToastHolder
local function notifyInit(gui)
	ToastHolder = Instance.new("Frame")
	ToastHolder.Size=UDim2.fromOffset(260,200); ToastHolder.BackgroundTransparency=1
	ToastHolder.Position=UDim2.new(1,-270,1,-210); ToastHolder.Parent=gui
	local TList = Instance.new("UIListLayout", ToastHolder); TList.Padding=UDim.new(0,6); TList.VerticalAlignment=Enum.VerticalAlignment.Bottom
end
local function notify(msg, dur)
	if not ToastHolder then return end
	local card = Instance.new("Frame"); card.Size=UDim2.new(1,0,0,34); card.BackgroundColor3=Color3.fromRGB(36,38,50); card.Parent=ToastHolder
	Instance.new("UICorner", card).CornerRadius=UDim.new(0,10); shadowUnder(card,8)
	local txt=Instance.new("TextLabel", card); txt.BackgroundTransparency=1; txt.TextWrapped=true; txt.TextXAlignment=Enum.TextXAlignment.Left
	txt.Font=Enum.Font.Gotham; txt.TextSize=12; txt.TextColor3=C_TEXT; txt.Size=UDim2.new(1,-16,1,-8); txt.Position=UDim2.fromOffset(8,4); txt.Text=tostring(msg)
	task.delay(dur or 2, function() if card then card:Destroy() end end)
end

-- =========================================
-- CLEAN SLATE + WINDOW
-- =========================================
local old = pg:FindFirstChild("ResilienceHarnessUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "ResilienceHarnessUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg
notifyInit(gui)

local root = Instance.new("Frame")
root.Name = "RH_Root"
root.Size = UDim2.fromOffset(WIN_W, WIN_H)
root.Position = UDim2.fromOffset(26,26)
root.BackgroundColor3 = C_BG
root.BackgroundTransparency = 0.08
root.BorderSizePixel=0
root.ClipsDescendants=true
root.Parent = gui
Instance.new("UICorner", root).CornerRadius = UDim.new(0,R)
local wStroke = Instance.new("UIStroke", root); wStroke.Color = Color3.fromRGB(60,64,84); wStroke.Transparency = 0.45
shadowUnder(root,12)

-- Topbar + drag + minimize
local top = Instance.new("Frame"); top.Size=UDim2.new(1,0,0,28); top.BackgroundTransparency=1; top.Parent=root
local title = Instance.new("TextLabel")
title.BackgroundTransparency=1; title.Font=Enum.Font.GothamSemibold; title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left
title.TextColor3=C_TEXT; title.Text="Overflow Harness (Visuals Only)"; title.Position=UDim2.fromOffset(10,5); title.Size=UDim2.fromOffset(220,18); title.Parent=top
local mini = Instance.new("TextButton")
mini.Text="–"; mini.Font=Enum.Font.GothamBold; mini.TextSize=16; mini.TextColor3=Color3.fromRGB(22,26,34)
mini.AutoButtonColor=false; mini.BackgroundColor3=C_ACCENT; mini.Size=UDim2.fromOffset(24,18); mini.Position=UDim2.new(1,-28,0,5); mini.ZIndex=2; mini.Parent=top
Instance.new("UICorner", mini).CornerRadius=UDim.new(0,7); shadowUnder(mini,8); clickFX(mini)

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

-- Minimize
local minimized=false local pill
local function restore() if pill then pill:Destroy() pill=nil end root.Visible=true minimized=false end
local function minimize()
	root.Visible=false minimized=true
	pill = Instance.new("TextButton")
	pill.Text="OH"; pill.Font=Enum.Font.GothamSemibold; pill.TextSize=12; pill.TextColor3=Color3.fromRGB(22,26,34)
	pill.AutoButtonColor=false; pill.BackgroundColor3=C_ACCENT
	pill.Size=UDim2.fromOffset(36,20); pill.Position=UDim2.fromOffset(24,24); pill.Parent=gui
	Instance.new("UICorner", pill).CornerRadius=UDim.new(1,0); clickFX(pill)
	pill.MouseButton1Click:Connect(restore)
end
mini.MouseButton1Click:Connect(function() if minimized then restore() else minimize() end end)

-- Left rail
local railH = WIN_H - 28 - GAP
local rail = Instance.new("Frame")
rail.Name = "LeftRail"
rail.Size = UDim2.fromOffset(RAIL_W, railH)
rail.Position = UDim2.fromOffset(GAP, 28+GAP)
rail.BackgroundColor3 = C_RAIL
rail.BorderSizePixel=0
rail.ClipsDescendants=true
rail.Parent=root
Instance.new("UICorner", rail).CornerRadius=UDim.new(0,R-2)
local rs=Instance.new("UIStroke", rail); rs.Color=Color3.fromRGB(60,64,84); rs.Transparency=0.35
shadowUnder(rail,10)
local rpad=Instance.new("UIPadding", rail); rpad.PaddingTop=UDim.new(0,GAP); rpad.PaddingBottom=UDim.new(0,GAP)
local rlist=Instance.new("UIListLayout", rail); rlist.Padding=UDim.new(0,GAP); rlist.HorizontalAlignment=Enum.HorizontalAlignment.Center

local function railBtn(text)
	local b=Instance.new("TextButton")
	b.Text=text; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.TextColor3=C_TEXT
	b.AutoButtonColor=false; b.BackgroundColor3=C_BTN
	b.Size=UDim2.fromOffset(RAIL_W-16, 24)
	b.Parent=rail
	Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
	local s=Instance.new("UIStroke", b); s.Color=Color3.fromRGB(70,74,92); s.Transparency=0.35
	shadowUnder(b,8); clickFX(b)
	return b
end

local Tabs = {
	Dig     = railBtn("Dig"),
	Jetpack = railBtn("Jetpack"),
	Farming = railBtn("Farming"),
	Spin    = railBtn("Spin Wheel"),
	Treasure= railBtn("Treasure"),
	Info    = railBtn("Info"),
	Misc    = railBtn("Misc"),
}

-- Content
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.fromOffset(WIN_W - RAIL_W - (GAP*3), railH)
content.Position = UDim2.fromOffset(RAIL_W + GAP + GAP, 28 + GAP)
content.BackgroundColor3 = C_PANEL
content.BorderSizePixel=0
content.ClipsDescendants=true
content.Parent = root
Instance.new("UICorner", content).CornerRadius = UDim.new(0, R-2)
local cs=Instance.new("UIStroke", content); cs.Color=Color3.fromRGB(60,64,84); cs.Transparency=0.35
shadowUnder(content,10)

local function Page(name)
	local p = Instance.new("Frame")
	p.Name = "Page_"..name
	p.Size = UDim2.fromScale(1,1)
	p.BackgroundTransparency=1
	p.Visible=false
	p.Parent=content
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

-- =========================================
-- DEMO TARGETS (UI box + optional world part)
-- =========================================
local function makeDemoBox(parent)
	local box = Instance.new("Frame")
	box.Name="Demo"
	box.Size = UDim2.fromOffset(28, 28)
	box.Position = UDim2.fromOffset(12, 40)
	box.BackgroundColor3 = Color3.fromRGB(120, 230, 190)
	box.BorderSizePixel = 0
	box.Parent = parent
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
	shadowUnder(box, 8)
	return box
end

local function findWorldTarget()
	local ok, part = pcall(function() return workspace:FindFirstChild("TweenTarget") end)
	if ok and part and part:IsA("BasePart") then return part end
	return nil
end

-- Tween helpers
local function tweenUIBox(box, duration, styleName, dirName, sizePx, movePx, color)
	if not box then return end
	local style, dir = getEase(styleName, dirName)
	local tw1 = TweenService:Create(box, TweenInfo.new(duration, style, dir), {
		Size     = UDim2.fromOffset(sizePx, sizePx),
		Position = UDim2.fromOffset(12 + movePx, 40 + movePx),
		BackgroundColor3 = color
	})
	tw1:Play()
	return tw1
end

local function tweenWorldPart(part, duration, styleName, dirName, deltaPos, scaleMult, color)
	if not part then return end
	local style, dir = getEase(styleName, dirName)
	local goal = { Color = color }
	if part.Anchored then goal.Position = part.Position + deltaPos end
	goal.Size = part.Size * scaleMult
	local tw = TweenService:Create(part, TweenInfo.new(duration, style, dir), goal)
	tw:Play()
	return tw
end

-- Reusable tween controls block
local function buildTweenControls(parent, labelPrefix)
	local card = section(parent, labelPrefix .. " Tween Controls")
	-- Dropdowns
	local ddStyle = dropdown(card, "Easing Style", EASE_STYLES, nil)
	local ddDir   = dropdown(card, "Easing Direction", EASE_DIRECTIONS, nil)
	ddStyle.Set("Sine"); ddDir.Set("Out")

	-- Sliders
	local durS   = slider(card, "Duration (s*10)", 5, 60, 18, nil)  -- internally /10
	local sizeS  = slider(card, "Box Size (px)", 16, 96, 36, nil)
	local moveS  = slider(card, "Move Offset (px)", 0, 64, 12, nil)
	local wPosS  = slider(card, "World ΔPos (studs)", 0, 50, 10, nil)
	local wScale = slider(card, "World Scale (%)", 50, 200, 120, nil)

	-- Color presets
	local colorCard = section(parent, "Color Preset")
	local ddColor = dropdown(colorCard, "Preset", {"Mint","Sky","Peach","Violet","Lemon"}, nil)
	local function colorFromPreset(name)
		if name=="Mint"  then return Color3.fromRGB(120,230,190)
		elseif name=="Sky"   then return Color3.fromRGB(110,170,255)
		elseif name=="Peach" then return Color3.fromRGB(255,170,130)
		elseif name=="Violet"then return Color3.fromRGB(185,155,255)
		elseif name=="Lemon" then return Color3.fromRGB(245,230,120)
		end
		return C_ACCENT
	end
	ddColor.Set("Mint")

	-- Buttons row
	local actions = section(parent, "Actions")
	local bUI     = tinyButton(actions, "Tween UI Box")
	local bWorld  = tinyButton(actions, "Tween World Part (TweenTarget)")
	local bBoth   = tinyButton(actions, "Tween Both")

	-- Attach demo box
	local demo = parent:FindFirstChild("Demo") or makeDemoBox(parent)

	local function runUI()
		local dur = durS.Get()/10
		local style = ddStyle.Get()
		local dir   = ddDir.Get()
		local size  = sizeS.Get()
		local move  = moveS.Get()
		local col   = colorFromPreset(ddColor.Get())
		tweenUIBox(demo, dur, style, dir, size, move, col)
	end
	local function runWorld()
		local tgt = findWorldTarget()
		if not tgt then notify("No Workspace.TweenTarget part found (optional).", 2); return end
		local dur = durS.Get()/10
		local style = ddStyle.Get()
		local dir   = ddDir.Get()
		local dpos  = Vector3.new(wPosS.Get(), 0, wPosS.Get())
		local scale = wScale.Get()/100
		local col   = colorFromPreset(ddColor.Get())
		tweenWorldPart(tgt, dur, style, dir, dpos, scale, col)
	end
	local function runBoth() runUI(); runWorld() end

	bUI.MouseButton1Click:Connect(runUI)
	bWorld.MouseButton1Click:Connect(runWorld)
	bBoth.MouseButton1Click:Connect(runBoth)

	return {
		runUI = runUI, runWorld = runWorld, runBoth = runBoth,
		setDemo = function(newDemo) demo = newDemo end,
	}
end

-- =========================================
-- POPULATE PAGES
-- =========================================
local function padAndList(frame)
	local pad = Instance.new("UIPadding", frame); pad.PaddingTop=UDim.new(0,GAP); pad.PaddingLeft=UDim.new(0,GAP); pad.PaddingRight=UDim.new(0,GAP)
	local list = Instance.new("UIListLayout", frame); list.Padding=UDim.new(0,GAP)
	return pad, list
end

-- Dig
do
	padAndList(Pages.Dig)
	buildTweenControls(Pages.Dig, "Dig")
end

-- Jetpack
do
	padAndList(Pages.Jetpack)
	buildTweenControls(Pages.Jetpack, "Jetpack")
end

-- Farming
do
	padAndList(Pages.Farming)
	buildTweenControls(Pages.Farming, "Farming")
end

-- Spin
do
	padAndList(Pages.Spin)
	buildTweenControls(Pages.Spin, "Spin")
end

-- Treasure
do
	padAndList(Pages.Treasure)
	buildTweenControls(Pages.Treasure, "Treasure")
end

-- Info
do
	padAndList(Pages.Info)
	local card = section(Pages.Info, "Script Info")
	labeled(card, "Overflow Harness (Visuals Only)")
	labeled(card, "Tabs with tween controls; safe demo only.")
	labeled(card, "Drop a BasePart named \"TweenTarget\" into Workspace for world tweens.")
	local stats = section(Pages.Info, "Stats")
	local fpsLbl = labeled(stats, "FPS: --")
	local t = 0; local frames = 0; local last = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		frames += 1; t += dt
		if t >= 0.5 then
			local now = os.clock()
			local fps = math.floor(frames / (now - last))
			last = now; frames = 0; t = 0
			fpsLbl.Text = "FPS: "..fps
		end
	end)
end

-- Misc
do
	padAndList(Pages.Misc)
	local demo = makeDemoBox(Pages.Misc)
	local miscCard = section(Pages.Misc, "Misc Effects")

	-- Color cycle toggle
	local cycling = false
	local tgCycle = toggle(miscCard, "Cycle Demo Color", function(on)
		cycling = on
	end)

	-- Spin TweenTarget toggle
	local spinning = false
	local tgSpin = toggle(miscCard, "Spin Workspace.TweenTarget", function(on)
		spinning = on
	end)

	-- Reset window position
	local btnRow = section
		-- Reset window position
	local btnRow = section(Pages.Misc, "Window / Target")
	local bReset = tinyButton(btnRow, "Reset Window Position")
	local bMakeTarget = tinyButton(btnRow, "Create Workspace.TweenTarget (demo)")

	bReset.MouseButton1Click:Connect(function()
		root.Position = UDim2.fromOffset(26,26)
		notify("Window reset.", 1.5)
	end)

	bMakeTarget.MouseButton1Click:Connect(function()
		if workspace:FindFirstChild("TweenTarget") then
			notify("TweenTarget already exists.", 1.5)
			return
		end
		local p = Instance.new("Part")
		p.Name = "TweenTarget"
		p.Anchored = true
		p.Size = Vector3.new(4,4,4)
		p.Color = Color3.fromRGB(120,230,190)
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector * 12)
		p.Parent = workspace
		notify("Created TweenTarget in front of camera.", 2)
	end)

	-- live effects
	local cycleConn, spinConn
	local hue = 0

	local function stopCycle()
		if cycleConn then cycleConn:Disconnect() cycleConn = nil end
	end
	local function stopSpin()
		if spinConn then spinConn:Disconnect() spinConn = nil end
	end

	tgCycle.Set(false)
	tgSpin.Set(false)

	tgCycle = toggle(miscCard, "Cycle Demo Color", function(on)
		stopCycle()
		if on then
			cycleConn = RunService.Heartbeat:Connect(function(dt)
				hue = (hue + dt*0.15) % 1
				demo.BackgroundColor3 = Color3.fromHSV(hue, 0.6, 1)
			end)
		end
	end)

	tgSpin = toggle(miscCard, "Spin Workspace.TweenTarget", function(on)
		stopSpin()
		if on then
			spinConn = RunService.Heartbeat:Connect(function(dt)
				local tgt = findWorldTarget()
				if tgt and tgt:IsA("BasePart") then
					local ang = math.rad(90) * dt
					-- Keep position stable, spin around Y
					tgt.CFrame = tgt.CFrame * CFrame.Angles(0, ang, 0)
				end
			end)
		end
	end)

	-- cleanup when page hidden (optional)
	local page = Pages.Misc
	page:GetPropertyChangedSignal("Visible"):Connect(function()
		if not page.Visible then
			stopCycle(); stopSpin()
		end
	end)
end

-- =========================================
-- TAB ROUTING + STARTUP
-- =========================================
local function selectTab(name)
	for id,btn in pairs(Tabs) do
		local on = (id == name)
		TweenService:Create(btn, TweenInfo.new(0.10), {
			BackgroundColor3 = on and C_BTN_ON or C_BTN,
			TextColor3       = on and Color3.new(1,1,1) or C_TEXT
		}):Play()
		Pages[id].Visible = on
	end
end
for id,btn in pairs(Tabs) do
	btn.MouseButton1Click:Connect(function() selectTab(id) end)
end

selectTab("Dig")
notify("UI loaded. Use tabs on the left.", 2)
