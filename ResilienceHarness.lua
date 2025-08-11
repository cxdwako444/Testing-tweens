-- === LEFT-RAIL UI REBUILD (drop-in) ==================================
-- Creates/uses a root window, fixed left rail (always visible), content pages,
-- tab switching, shadows + click ripple/squish. No gameplay blur.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local SHADOW = "rbxassetid://13637412666"

-- soft shadow under any UI object
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
	s.Position = UDim2.fromOffset(-p/2,-p/2)
	s.Parent = ui
	return s
end

local function clickFX(btn)
	btn.ClipsDescendants = true
	local s = Instance.new("UIScale")
	s.Scale = 1
	s.Parent = btn
	btn.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			TweenService:Create(s, TweenInfo.new(0.06, Enum.EasingStyle.Quad), {Scale=0.96}):Play()
			local rel = i.Position - btn.AbsolutePosition
			-- ripple
			local circle = Instance.new("Frame")
			circle.BackgroundColor3 = Color3.new(1,1,1)
			circle.BackgroundTransparency = 0.3
			circle.Size = UDim2.fromOffset(0,0)
			circle.ZIndex = btn.ZIndex + 2
			circle.Parent = btn
			Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)
			local max = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.6
			circle.Position = UDim2.fromOffset(rel.X - max*0.5, rel.Y - max*0.5)
			TweenService:Create(circle, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(max,max), BackgroundTransparency = 1
			}):Play()
			game:GetService("Debris"):AddItem(circle, 0.24)
		end
	end)
	btn.InputEnded:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			TweenService:Create(s, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=1}):Play()
		end
	end)
end

-- reuse existing ScreenGui if you have one; else create
local gui = pg:FindFirstChild("ResilienceHarnessUI") or Instance.new("ScreenGui")
gui.Name = "ResilienceHarnessUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

-- reuse existing root if present; else create
local root = gui:FindFirstChild("RH_Root") or Instance.new("Frame")
root.Name = "RH_Root"
root.ClipsDescendants = true
root.Size = UDim2.fromOffset(360, 240)   -- compact window
root.Position = UDim2.fromOffset(26, 26)
root.BackgroundColor3 = rgb(20,22,30)
root.BackgroundTransparency = 0.08
root.Parent = gui
if not root:FindFirstChildOfClass("UICorner") then
	Instance.new("UICorner", root).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", root); s.Color = rgb(60,64,84); s.Transparency = 0.45
	shadowUnder(root, 12)
end

-- Topbar (drag + minimize) --------------------------------------------
local top = root:FindFirstChild("Topbar") or Instance.new("Frame")
top.Name="Topbar"; top.Size = UDim2.new(1,0,0,28); top.BackgroundTransparency = 1; top.Parent = root

local title = top:FindFirstChild("Title") or Instance.new("TextLabel")
title.Name="Title"; title.Text="Resilience Harness"
title.BackgroundTransparency=1; title.Font=Enum.Font.GothamSemibold; title.TextSize=13
title.TextXAlignment=Enum.TextXAlignment.Left; title.TextColor3=rgb(232,236,255)
title.Position=UDim2.fromOffset(10,5); title.Size=UDim2.fromOffset(200,18); title.Parent=top

local mini = top:FindFirstChild("Mini") or Instance.new("TextButton")
mini.Name="Mini"; mini.Text="–"; mini.Font=Enum.Font.GothamBold; mini.TextSize=16; mini.TextColor3=rgb(22,26,34)
mini.AutoButtonColor=false; mini.BackgroundColor3=rgb(140,230,190)
mini.Size=UDim2.fromOffset(24,18); mini.Position=UDim2.new(1,-28,0,5); mini.ZIndex=2; mini.Parent=top
if not mini:FindFirstChildOfClass("UICorner") then
	Instance.new("UICorner", mini).CornerRadius=UDim.new(0,7); shadowUnder(mini,8); clickFX(mini)
end

-- drag window
do
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

-- Minimize (no blur)
local minimized=false
local pill
local function restore()
	if pill then pill:Destroy() pill=nil end
	root.Visible=true
	minimized=false
end
local function minimize()
	root.Visible=false
	minimized=true
	pill = Instance.new("TextButton")
	pill.Text="RH"; pill.Font=Enum.Font.GothamSemibold; pill.TextSize=12; pill.TextColor3=rgb(22,26,34)
	pill.AutoButtonColor=false; pill.BackgroundColor3=rgb(140,230,190)
	pill.Size=UDim2.fromOffset(36,20); pill.Position=UDim2.fromOffset(24,24); pill.Parent=gui
	Instance.new("UICorner", pill).CornerRadius=UDim.new(1,0); shadowUnder(pill,10); clickFX(pill)
	pill.MouseButton1Click:Connect(restore)
end
mini.MouseButton1Click:Connect(function() if minimized then restore() else minimize() end end)

-- Left rail (ALWAYS VISIBLE, inside root) ------------------------------
local GAP = 6
local railHeight = root.Size.Y.Offset - 28 - GAP
local rail = root:FindFirstChild("LeftRail") or Instance.new("Frame")
rail.Name="LeftRail"
rail.Size = UDim2.fromOffset(96, railHeight)      -- fixed width rail
rail.Position = UDim2.fromOffset(GAP, 28+GAP)     -- flush-left inside root
rail.BackgroundColor3 = rgb(28,30,42)
rail.ClipsDescendants = true
rail.Parent = root
if not rail:FindFirstChildOfClass("UICorner") then
	Instance.new("UICorner", rail).CornerRadius=UDim.new(0,8)
	local s=Instance.new("UIStroke", rail); s.Color=rgb(60,64,84); s.Transparency=0.35
	shadowUnder(rail,10)
	local pad = Instance.new("UIPadding", rail); pad.PaddingTop=UDim.new(0,GAP); pad.PaddingBottom=UDim.new(0,GAP)
	local list = Instance.new("UIListLayout", rail); list.Padding=UDim.new(0,GAP)
end

local function railBtn(text)
	local b = Instance.new("TextButton")
	b.Text = text; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.TextColor3=rgb(230,236,255)
	b.AutoButtonColor=false; b.BackgroundColor3=rgb(38,42,58)
	b.Size = UDim2.fromOffset(80, 24)
	b.Parent = rail
	Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
	local s = Instance.new("UIStroke", b); s.Color=rgb(70,74,92); s.Transparency=0.35
	shadowUnder(b,8); clickFX(b)
	return b
end

-- create or reuse tab buttons
local Tabs = {}
Tabs.Main    = rail:FindFirstChild("MainTab")    or railBtn("Main");    Tabs.Main.Name="MainTab"
Tabs.Metrics = rail:FindFirstChild("MetricsTab") or railBtn("Metrics"); Tabs.Metrics.Name="MetricsTab"
Tabs.Logs    = rail:FindFirstChild("LogsTab")    or railBtn("Logs");    Tabs.Logs.Name="LogsTab"
Tabs.Config  = rail:FindFirstChild("ConfigTab")  or railBtn("Config");  Tabs.Config.Name="ConfigTab"

-- Content panel (aligned to rail) -------------------------------------
local content = root:FindFirstChild("Content") or Instance.new("Frame")
content.Name="Content"
content.Size = UDim2.fromOffset(root.Size.X.Offset - 96 - (GAP*3), railHeight)
content.Position = UDim2.fromOffset(96 + GAP + GAP, 28 + GAP)
content.BackgroundColor3 = rgb(24,26,36)
content.ClipsDescendants = true
content.Parent = root
if not content:FindChildWhichIsA("UICorner") then
	Instance.new("UICorner", content).CornerRadius=UDim.new(0,8)
	local s=Instance.new("UIStroke", content); s.Color=rgb(60,64,84); s.Transparency=0.35
	shadowUnder(content,10)
end

local function page(name)
	local p = content:FindFirstChild("Page_"..name) or Instance.new("Frame")
	p.Name="Page_"..name
	p.BackgroundTransparency=1
	p.Size=UDim2.fromScale(1,1)
	p.Visible=false
	p.Parent=content
	return p
end
local Pages = {
	Main    = page("Main"),
	Metrics = page("Metrics"),
	Logs    = page("Logs"),
	Config  = page("Config"),
}

-- simple content so you can see it's working
for _,p in pairs(Pages) do
	if not p:FindFirstChild("Pad") then
		local pad = Instance.new("UIPadding", p); pad.Name="Pad"; pad.PaddingTop=UDim.new(0,GAP); pad.PaddingLeft=UDim.new(0,GAP); pad.PaddingRight=UDim.new(0,GAP)
		local label = Instance.new("TextLabel", p)
		label.BackgroundTransparency=1; label.Font=Enum.Font.GothamSemibold; label.TextSize=14
		label.TextXAlignment=Enum.TextXAlignment.Left; label.TextColor3=rgb(235,240,255)
		label.Size=UDim2.fromOffset(220,20); label.Position=UDim2.fromOffset(6,6)
		label.Text = p.Name
	end
end

-- tab switching
local function selectTab(name)
	for id,btn in pairs(Tabs) do
		local active = (id == name)
		TweenService:Create(btn, TweenInfo.new(0.1), {
			BackgroundColor3 = active and rgb(60,64,84) or rgb(38,42,58),
			TextColor3       = active and Color3.new(1,1,1) or rgb(230,236,255)
		}):Play()
		Pages[id].Visible = active
	end
end
for id,btn in pairs(Tabs) do
	btn.MouseButton1Click:Connect(function() selectTab(id) end)
end
selectTab("Main") -- show something immediately

-- =====================================================================
-- Done. Left tabs are pinned inside root, visible, aligned, with ripple.
-- If your old UI still created extra overlays, remove the old frames that
-- duplicated the rail or content to avoid stacking.
