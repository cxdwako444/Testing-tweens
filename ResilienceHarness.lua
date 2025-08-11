-- HARD RESET: guaranteed-visible left tabs (debug colors)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

-- 0) Nuke any previous UI with same name
local old = pg:FindFirstChild("ResilienceHarnessUI")
if old then old:Destroy() end

-- 1) Base gui
local gui = Instance.new("ScreenGui")
gui.Name = "ResilienceHarnessUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

-- 2) Root window
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromOffset(380, 250)      -- fixed size so math is predictable
root.Position = UDim2.fromOffset(32, 32)
root.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
root.BorderSizePixel = 0
root.ClipsDescendants = true
root.ZIndex = 10
root.Parent = gui
Instance.new("UICorner", root).CornerRadius = UDim.new(0, 10)

-- Topbar + drag
local top = Instance.new("Frame")
top.Name = "Topbar"
top.Size = UDim2.new(1, 0, 0, 28)
top.BackgroundTransparency = 1
top.ZIndex = 20
top.Parent = root

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamSemibold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(235, 240, 255)
title.Text = "Resilience Harness"
title.Position = UDim2.fromOffset(10, 5)
title.Size = UDim2.fromOffset(220, 18)
title.ZIndex = 21
title.Parent = top

local mini = Instance.new("TextButton")
mini.Text = "–"
mini.AutoButtonColor = false
mini.Font = Enum.Font.GothamBold
mini.TextSize = 16
mini.TextColor3 = Color3.fromRGB(22,26,34)
mini.BackgroundColor3 = Color3.fromRGB(140,230,190)
mini.Size = UDim2.fromOffset(24, 18)
mini.Position = UDim2.new(1, -28, 0, 5)
mini.ZIndex = 21
mini.Parent = top
Instance.new("UICorner", mini).CornerRadius = UDim.new(0, 7)

do -- drag
	local dragging=false; local dragStart; local startPos
	top.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging=true; dragStart=i.Position; startPos=Vector2.new(root.Position.X.Offset, root.Position.Y.Offset)
			i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
			local d=i.Position-dragStart; root.Position=UDim2.fromOffset(startPos.X+d.X,startPos.Y+d.Y)
		end
	end)
end

-- 3) LEFT RAIL — BRIGHT TEMP COLOR to prove visibility
local GAP = 6
local rail = Instance.new("Frame")
rail.Name = "LeftRail"
rail.Size = UDim2.fromOffset(96, root.Size.Y.Offset - 28 - GAP)
rail.Position = UDim2.fromOffset(GAP, 28 + GAP)
rail.BackgroundColor3 = Color3.fromRGB(60, 120, 255) -- DEBUG BLUE so you see it
rail.BorderSizePixel = 0
rail.ZIndex = 30 -- on top of content
rail.ClipsDescendants = false
rail.Parent = root
Instance.new("UICorner", rail).CornerRadius = UDim.new(0, 8)

local pad = Instance.new("UIPadding", rail)
pad.PaddingTop = UDim.new(0, GAP)
pad.PaddingBottom = UDim.new(0, GAP)

local list = Instance.new("UIListLayout", rail)
list.Padding = UDim.new(0, GAP)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Top
list.SortOrder = Enum.SortOrder.LayoutOrder

local function makeTab(name)
	local b = Instance.new("TextButton")
	b.Name = name .. "Tab"
	b.Size = UDim2.fromOffset(80, 24)
	b.BackgroundColor3 = Color3.fromRGB(38, 42, 58)
	b.Text = name
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.AutoButtonColor = false
	b.ZIndex = 31
	b.Parent = rail
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
	return b
end

local tabs = {
	Main    = makeTab("Main"),
	Metrics = makeTab("Metrics"),
	Logs    = makeTab("Logs"),
	Config  = makeTab("Config"),
}

-- 4) CONTENT PANEL — different bright color so layers are obvious
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.fromOffset(root.Size.X.Offset - 96 - (GAP*3), rail.Size.Y.Offset)
content.Position = UDim2.fromOffset(96 + GAP + GAP, 28 + GAP)
content.BackgroundColor3 = Color3.fromRGB(32, 36, 48) -- DEBUG DARK
content.BorderSizePixel = 0
content.ZIndex = 25        -- BELOW the rail to prove rail is on top
content.ClipsDescendants = true
content.Parent = root
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 8)

local function page(name)
	local p = Instance.new("Frame")
	p.Name = "Page_"..name
	p.Size = UDim2.fromScale(1,1)
	p.BackgroundTransparency = 1
	p.Visible = false
	p.ZIndex = 26
	p.Parent = content
	return p
end

local pages = {
	Main    = page("Main"),
	Metrics = page("Metrics"),
	Logs    = page("Logs"),
	Config  = page("Config"),
}

-- add obvious labels so you see switching
for id,frame in pairs(pages) do
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextSize = 16
	lbl.TextColor3 = Color3.fromRGB(255,255,255)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = "PAGE: "..id
	lbl.Position = UDim2.fromOffset(10,10)
	lbl.Size = UDim2.fromOffset(200,20)
	lbl.ZIndex = 27
	lbl.Parent = frame
end

-- 5) Tab switching (visually obvious)
local function selectTab(name)
	for id,btn in pairs(tabs) do
		local active = (id == name)
		btn.BackgroundColor3 = active and Color3.fromRGB(80, 180, 120) or Color3.fromRGB(38,42,58) -- green when active
		pages[id].Visible = active
	end
end
for id,btn in pairs(tabs) do
	btn.MouseButton1Click:Connect(function() selectTab(id) end)
end
selectTab("Main")

-- 6) Minimize (no blur)
local minimized=false local pill
local function restore()
	if pill then pill:Destroy() pill=nil end
	root.Visible=true
	minimized=false
end
local function minimize()
	root.Visible=false
	minimized=true
	pill = Instance.new("TextButton")
	pill.Text="RH"
	pill.Font=Enum.Font.GothamSemibold
	pill.TextSize=12
	pill.TextColor3=Color3.fromRGB(22,26,34)
	pill.AutoButtonColor=false
	pill.BackgroundColor3=Color3.fromRGB(140,230,190)
	pill.Size=UDim2.fromOffset(36,20)
	pill.Position=UDim2.fromOffset(24,24)
	pill.ZIndex = 50
	pill.Parent=gui
	Instance.new("UICorner", pill).CornerRadius=UDim.new(1,0)
	pill.MouseButton1Click:Connect(restore)
end
mini.MouseButton1Click:Connect(function() if minimized then restore() else minimize() end end)

-- 7) DEBUG: print positions/sizes so we know it's there
task.delay(0.2, function()
	print("[RH DEBUG] root", root.AbsolutePosition, root.AbsoluteSize)
	print("[RH DEBUG] rail", rail.AbsolutePosition, rail.AbsoluteSize)
	print("[RH DEBUG] first tab", tabs.Main.AbsolutePosition, tabs.Main.AbsoluteSize)
	print("[RH DEBUG] content", content.AbsolutePosition, content.AbsoluteSize)
end)
