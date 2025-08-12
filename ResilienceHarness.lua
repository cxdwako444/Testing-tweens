-- ResilienceHarness.lua (fixed full build)

-- ===== CONFIG =====
local PLOTS_FOLDER_NAME = "Plots"
local DELIVERY_NEEDLE   = "delivery"   -- e.g. "deliveryhitbox"
local TWEEN_SPEED       = 40           -- slider controls 5–1000
local AGENT_RADIUS      = 2.5
local AGENT_HEIGHT      = 5.0
local AGENT_CAN_JUMP    = true
local LOCK_Y_TO_ZERO    = false

-- Watchdog (gentle)
local SNAPBACK_JUMP_STUDS  = 12
local DIST_INCREASE_MARGIN = 20
local MAX_REROUTES         = 6

-- ===== SERVICES =====
local Players                = game:GetService("Players")
local TweenService           = game:GetService("TweenService")
local PathfindingService     = game:GetService("PathfindingService")
local RunService             = game:GetService("RunService")
local UserInputService       = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local plr = Players.LocalPlayer
local PG  = plr:WaitForChild("PlayerGui")
local WS  = workspace

-- ===== PET NAMES =====
local PET_NAMES = {
	"Noobini Pizzanini","Lirili Larila","Tim Cheese","FluriFlura","Talpa Di Fero","Svinina Bombardino",
	"Pipi Kiwi","Trippi Troppi","Tung Tung Tung Sahur","Gangster Footera","Bandito Bobritto","Boneca Ambalabu",
	"Cacto Hipopotamo","Ta Ta Ta Ta Sahur","Tric Trac Baraboom","Cappuccino Assassino","Brr Brr Patapim",
	"Trulimero Trulicina","Bambini Crostini","Bananita Dolphinita","Perochello Lemonchello",
	"Brri Brri Bicus Dicus Bombicus","Avocadini Guffo","Salamino Penguino","Burbaloni Loliloli",
	"Chimpazini Bananini","Ballerina Cappuccina","Chef Crabracadabra","Lionel Cactuseli","Glorbo Fruttodrillo",
	"Blueberrini Octopusin","Strawberelli Flamingelli","Pandaccini Bananini","Frigo Camelo",
	"Orangutini Ananassini","Rhino Toasterino","Bombardiro Crocodilo","Spioniro Golubiro",
	"Bombombini Gusini","Zibra Zubra Zibralini","Tigrilini Watermelini","Cavallo Virtuso",
	"Gorillo Watermelondrillo","Coco Elefanto","Girafa Celestre","Gattatino Nyanino","Matteo",
	"Tralalero Tralala","Trigoligre Frutonni","Espresso Signora","Odin Din Din Dun","Statutino Libertino",
	"Orcalero Orcala","Trenostruzzo Turbo 3000","Ballerino Lololo","Los Crocodillitos","Piccione Macchina",
	"La Vacca Staturno Saturnita","Chimpanzini Spiderini","Tortuginni Dragonfruitini","Los Tralaleritos",
	"Las Tralaleritas","Graipuss Medussi","Pot Hotspot","La Grande Combinasion","Nuclearo Dinossauro",
	"Garama and Madundung","Las Vaquitas Saturnitas","Chicleteira Bicicleteira"
}
local PET_SET = {} for _,n in ipairs(PET_NAMES) do PET_SET[n]=true end

-- ===== PET VALUES (later in list = higher; tweak if you want exact economy) =====
local PET_VALUES = {}
do
	for i, n in ipairs(PET_NAMES) do PET_VALUES[n] = i end
end

-- ===== “BEST PET” styling =====
local BEST_FILL     = Color3.fromRGB(60, 255, 120)
local BEST_TEXT     = Color3.fromRGB(60, 255, 120)
local BEST_TEXTSIZE = 16

-- ===== UTILS =====
local function ci(s) return string.lower(s or "") end
local function hrpNow()
	local c = plr.Character
	return c and c:FindFirstChild("HumanoidRootPart") or nil
end
local function firstPart(model)
	if model:IsA("Model") then
		if model.PrimaryPart then return model.PrimaryPart end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then return d end
		end
	elseif model:IsA("BasePart") then
		return model
	end
	return nil
end
local function addHighlightOn(adoree, fill, outline, ft)
	local h = Instance.new("Highlight")
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.FillColor = fill or Color3.fromRGB(255,230,0)
	h.OutlineColor = outline or Color3.fromRGB(30,30,30)
	h.FillTransparency = ft or 0.6
	h.OutlineTransparency = 0
	h.Adornee = adoree
	h.Parent = PG
	return h
end

-- Billboard text (no background)
local function addBillboard(part, name, yOffset, textSizePx, color)
	local bb = Instance.new("BillboardGui")
	bb.Name = name or "Label"
	bb.AlwaysOnTop = true
	bb.MaxDistance = 5000
	bb.Size = UDim2.fromOffset(180, 28)
	bb.StudsOffset = Vector3.new(0, yOffset or 0, 0)
	bb.Adornee = part
	bb.Parent = PG

	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.AnchorPoint = Vector2.new(0.5, 0.5)
	tl.Position = UDim2.fromScale(0.5, 0.5)
	tl.TextScaled = false
	tl.TextSize = textSizePx or 12
	tl.Font = Enum.Font.Gotham
	tl.TextColor3 = color or Color3.new(1,1,1)
	tl.TextStrokeTransparency = 0.1
	tl.TextStrokeColor3 = Color3.new(0,0,0)
	tl.Text = ""
	tl.Parent = bb

	return bb, tl
end

local function plotsFolder()
	local pf = WS:FindFirstChild(PLOTS_FOLDER_NAME)
	if pf then return pf end
	for _, c in ipairs(WS:GetChildren()) do
		if ci(c.Name) == ci(PLOTS_FOLDER_NAME) then return c end
	end
	return nil
end

-- ===== Best pet finder (current server) =====
local function findBestPetInServer()
	local bestModel, bestScore = nil, -math.huge
	for _, ch in ipairs(WS:GetChildren()) do
		if ch:IsA("Model") and PET_SET[ch.Name] then
			local score = PET_VALUES[ch.Name] or 0
			if score > bestScore then
				bestScore = score
				bestModel = ch
			end
		end
	end
	return bestModel
end

-- ===== ESP: Pets =====
local espOn = false
local petHandles = {} -- [Model] = {highlight=<Highlight>}

local function clearPetESP()
	for mdl, pack in pairs(petHandles) do
		if pack and pack.highlight then pack.highlight:Destroy() end
	end
	petHandles = {}
	for _, gui in ipairs(PG:GetChildren()) do
		if gui:IsA("BillboardGui") and gui.Name == "__PetName" then gui:Destroy() end
	end
end

local function highlightAllPets()
	local bestModel = findBestPetInServer()
	for _, ch in ipairs(WS:GetChildren()) do
		if ch:IsA("Model") and PET_SET[ch.Name] and not petHandles[ch] then
			local isBest = (bestModel ~= nil and ch == bestModel)
			local fillColor   = isBest and BEST_FILL or Color3.fromRGB(255,230,0)
			local outlineColor= Color3.fromRGB(0,0,0)
			local fillTransp  = isBest and 0.25 or 0.35

			local h = addHighlightOn(ch, fillColor, outlineColor, fillTransp)

			local p = firstPart(ch)
			if p then
				local textSize = isBest and BEST_TEXTSIZE or 10
				local bb, tl = addBillboard(p, "__PetName", 4, textSize, isBest and BEST_TEXT or nil)
				tl.Text = ch.Name
				if isBest then tl.TextStrokeTransparency = 0.05 end
			end
			petHandles[ch] = {highlight = h}
		end
	end
end

-- keep best-pet styling fresh
task.spawn(function()
	while true do
		if espOn then
			clearPetESP()
			highlightAllPets()
		end
		task.wait(2)
	end
end)

-- ===== Base timer ESP ('RemainingTime' anywhere under each plot) =====
local baseOverlays = {} -- plotRoot -> {highlight, billboard, label, anchor, sources}

local function findPlotRoot(inst)
	local plots = plotsFolder(); if not plots then return nil end
	local cur = inst
	while cur and cur ~= WS do
		if cur.Parent == plots then return cur end
		cur = cur.Parent
	end
	return nil
end
local function findLowestPart(plot)
	local lowest, ly = nil, math.huge
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("BasePart") and d.Position.Y < ly then
			ly = d.Position.Y; lowest = d
		end
	end
	return lowest
end
local function parseSecsFromString(s)
	if not s or s == "" then return nil end
	local m, sec = s:match("^(%d+):(%d+)$")
	if m and sec then return tonumber(m)*60 + tonumber(sec) end
	local d = s:match("(%d+)")
	if d then return tonumber(d) end
	return nil
end
local function readTimerValue(obj)
	if obj:IsA("StringValue") then return parseSecsFromString(obj.Value) or 0 end
	if obj:IsA("NumberValue") or obj:IsA("IntValue") then return tonumber(obj.Value) or 0 end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then return parseSecsFromString(obj.Text) or 0 end
	return 0
end

local function startBaseTimersESP()
	local plots = plotsFolder()
	if not plots then warn("[TimerESP] Plots folder not found"); return end

	local candidates = {}
	for _, d in ipairs(WS:GetDescendants()) do
		if ci(d.Name) == "remainingtime" then
			local plot = findPlotRoot(d)
			if plot then
				candidates[plot] = candidates[plot] or {}
				table.insert(candidates[plot], d)
			end
		end
	end

	for plot, list in pairs(candidates) do
		if not baseOverlays[plot] then
			local anchor = findLowestPart(plot) or firstPart(plot)
			if anchor then
				local bottomOffsetY = -(anchor.Size.Y / 2) + 1
				local bb, tl = addBillboard(anchor, "__BaseTimer", bottomOffsetY, 12)
				local hl = addHighlightOn(plot, Color3.fromRGB(80,255,120), Color3.fromRGB(20,60,25), 0.7)
				baseOverlays[plot] = {highlight=hl, billboard=bb, label=tl, anchor=anchor, sources=list}
			end
		else
			for _, s in ipairs(list) do table.insert(baseOverlays[plot].sources, s) end
		end
	end

	task.spawn(function()
		while espOn do
			for plot, pack in pairs(baseOverlays) do
				if not plot.Parent then continue end
				local maxSecs = 0
				for _, src in ipairs(pack.sources) do
					if src.Parent then
						local v = readTimerValue(src)
						if v > maxSecs then maxSecs = v end
					end
				end
				if maxSecs > 0 then
					local txt = (maxSecs >= 60)
						and string.format("%d:%02d", math.floor(maxSecs/60), math.floor(maxSecs%60))
						or (tostring(math.floor(maxSecs)).."s")
					pack.label.Text = txt
					pack.highlight.FillColor = Color3.fromRGB(255,80,80)
				else
					pack.label.Text = "Open"
					pack.highlight.FillColor = Color3.fromRGB(80,255,120)
				end
			end
			task.wait(0.25)
		end
	end)
end

local function stopBaseTimersESP()
	for _, pack in pairs(baseOverlays) do
		if pack.highlight then pack.highlight:Destroy() end
		if pack.billboard then pack.billboard:Destroy() end
	end
	baseOverlays = {}
end

-- ===== Delivery bind =====
local myBaseModel, myDeliveryPart
local function allDeliveriesUnder(plotModel)
	local out = {}
	for _, d in ipairs(plotModel:GetDescendants()) do
		if d:IsA("BasePart") and string.find(ci(d.Name), ci(DELIVERY_NEEDLE), 1, true) then
			table.insert(out, d)
		end
	end
	return out
end
local function plotsFolderChildren()
	local pf = plotsFolder()
	return pf and pf:GetChildren() or {}
end
local function autoBindMyBase()
	if myDeliveryPart and myBaseModel then return true end
	local hrp = hrpNow() if not hrp then return false end
	local bestPlot, bestDelivery, bestDist = nil, nil, math.huge
	for _, plot in ipairs(plotsFolderChildren()) do
		for _, part in ipairs(allDeliveriesUnder(plot)) do
			local d = (part.Position - hrp.Position).Magnitude
			if d < bestDist then bestPlot, bestDelivery, bestDist = plot, part, d end
		end
	end
	if bestPlot and bestDelivery then
		myBaseModel, myDeliveryPart = bestPlot, bestDelivery
		return true
	end
	return false
end

-- ===== TWEEN + PATH =====
local activeTween, hbConn, GO_RUNNING = nil, nil, false

local function tweenToPoint(toPos, finalTarget)
	local hrp = hrpNow() if not hrp then return false end
	local from = hrp.Position
	local to   = LOCK_Y_TO_ZERO and Vector3.new(toPos.X,0,toPos.Z) or toPos

	local horizFrom = Vector3.new(from.X,0,from.Z)
	local horizTo   = Vector3.new(to.X,0,to.Z)
	local dist = (horizTo - horizFrom).Magnitude
	local dur  = math.max(0.05, dist / TWEEN_SPEED)

	local info = TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local look = to + Vector3.new(0,0,1)

	local lastPos = hrp.Position
	local interrupted = false
	local minDistToFinal = (finalTarget - hrp.Position).Magnitude
	local framesStable = 0

	if hbConn then hbConn:Disconnect() hbConn = nil end
	hbConn = RunService.Heartbeat:Connect(function()
		if not hrp.Parent then return end
		local p = hrp.Position
		local jump = (p - lastPos).Magnitude
		lastPos = p

		if jump >= SNAPBACK_JUMP_STUDS then
			interrupted = true
			if activeTween then activeTween:Cancel() end
			if hbConn then hbConn:Disconnect() hbConn = nil end
			return
		end

		framesStable += 1
		if framesStable > 6 then
			local curDist = (finalTarget - p).Magnitude
			if curDist < minDistToFinal then
				minDistToFinal = curDist
			elseif (curDist - minDistToFinal) > DIST_INCREASE_MARGIN then
				interrupted = true
				if activeTween then activeTween:Cancel() end
				if hbConn then hbConn:Disconnect() hbConn = nil end
				return
			end
		end
	end)

	activeTween = TweenService:Create(hrp, info, { CFrame = CFrame.new(to, look) })
	activeTween:Play()
	activeTween.Completed:Wait()
	if hbConn then hbConn:Disconnect() hbConn = nil end
	activeTween = nil

	return not interrupted
end

local function computePathPoints(targetPos)
	local hrp = hrpNow() if not hrp then return nil end
	local start = hrp.Position
	local goal  = LOCK_Y_TO_ZERO and Vector3.new(targetPos.X, start.Y, targetPos.Z) or targetPos

	local path = PathfindingService:CreatePath({
		AgentRadius = AGENT_RADIUS,
		AgentHeight = AGENT_HEIGHT,
		AgentCanJump = AGENT_CAN_JUMP
	})
	path:ComputeAsync(start, goal)
	if path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local pts, last = {}, nil
	for _, wp in ipairs(path:GetWaypoints()) do
		local p = wp.Position
		if LOCK_Y_TO_ZERO then p = Vector3.new(p.X,0,p.Z) end
		if (not last) or (p - last).Magnitude > 0.5 then
			table.insert(pts, p) last = p
		end
	end
	return pts
end

local function goToMyDelivery()
	if GO_RUNNING then return end
	if not myDeliveryPart or not myBaseModel then
		if not autoBindMyBase() then warn("Stand on/near your delivery once, then press Start Tween."); return end
	end

	GO_RUNNING = true
	local reroutes = 0
	local finalTarget = LOCK_Y_TO_ZERO and Vector3.new(myDeliveryPart.Position.X,0,myDeliveryPart.Position.Z)
	                                   or  myDeliveryPart.Position
	while reroutes <= MAX_REROUTES do
		local hrp = hrpNow() if not hrp then break end
		local points = computePathPoints(finalTarget)
		if not points or #points == 0 then
			if tweenToPoint(finalTarget, finalTarget) then break end
			reroutes += 1
			task.wait(0.05)
			continue
		end
		local start = LOCK_Y_TO_ZERO and Vector3.new(hrp.Position.X,0,hrp.Position.Z) or hrp.Position
		if (points[1] - start).Magnitude > 0.5 then table.insert(points, 1, start) end
		if (points[#points] - finalTarget).Magnitude > 0.5 then table.insert(points, finalTarget) end

		local interrupted = false
		for i = 2, #points do
			if not tweenToPoint(points[i], finalTarget) then interrupted = true break end
		end
		if not interrupted then break end
		reroutes += 1
		task.wait(0.05)
	end
	GO_RUNNING = false
end

-- ===== Timed Grab → Deliver =====
local function getRemainingTimeSecondsForPlot(plotModel)
	if not plotModel then return 0 end
	local maxSecs = 0
	for _, d in ipairs(plotModel:GetDescendants()) do
		if ci(d.Name) == "remainingtime" then
			maxSecs = math.max(maxSecs, readTimerValue(d))
		end
	end
	return maxSecs
end

local function findGrabPromptIn(model)
	if not model then return nil end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			local a = ci(d.ActionText or "")
			local o = ci(d.ObjectText or "")
			if a:find("grab",1,true) or o:find("grab",1,true) then
				return d
			end
		end
	end
	return nil
end

local function findBestPetModelNow()
	local hrp = hrpNow()
	local best, bestScore, bestDist = nil, -math.huge, math.huge
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and PET_VALUES[m.Name] then
			local score = PET_VALUES[m.Name]
			local p = firstPart(m)
			if p then
				local d = hrp and (p.Position - hrp.Position).Magnitude or math.huge
				if (score > bestScore) or (score == bestScore and d < bestDist) then
					best, bestScore, bestDist = m, score, d
				end
			end
		end
	end
	return best
end

local function goNearModel(model)
	local p = firstPart(model)
	if not p then return false end
	return tweenToPoint(p.Position, p.Position)
end

local function holdPrompt(prompt)
	if not prompt then return false end
	local dur = prompt.HoldDuration or 1.5
	ProximityPromptService:InputHoldBegin(prompt)
	task.wait(math.max(0, dur) + 0.10)
	ProximityPromptService:InputHoldEnd(prompt)
	return true
end

local function grabThenDeliverTimed()
	if not myDeliveryPart or not myBaseModel then
		if not autoBindMyBase() then
			warn("Go near your delivery once so I can bind your base, then try again.")
			return
		end
	end

	-- 1) best pet now
	local pet = findBestPetModelNow()
	if not pet then warn("No pets found right now."); return end

	-- 2) go to pet
	if not goNearModel(pet) then warn("Could not reach the pet."); return end

	-- 3) wait until base <= 2.5s (cap 20s to avoid hanging)
	local cutoff = 2.5
	local t0 = time()
	while true do
		local secs = getRemainingTimeSecondsForPlot(myBaseModel)
		if secs <= cutoff then break end
		if time() - t0 > 20 then break end
		task.wait(0.1)
	end

	-- 4) hold grab
	local prompt = findGrabPromptIn(pet)
	if not prompt then task.wait(0.15); prompt = findGrabPromptIn(pet) end
	if prompt then holdPrompt(prompt) else warn("Grab prompt not found on pet.") end

	-- 5) deliver
	goToMyDelivery()
end

-- ===== GUI =====
local GUI = PG:FindFirstChild("BrainrotMini") :: ScreenGui
if not GUI then
	GUI = Instance.new("ScreenGui")
	GUI.Name = "BrainrotMini"
	GUI.ResetOnSpawn = false
	GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	GUI.Parent = PG
end

local panel = GUI:FindFirstChild("Panel") :: Frame
if not panel then
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(260, 160)
	panel.Position = UDim2.new(0, 16, 1, -176)
	panel.BackgroundTransparency = 0.15
	panel.BackgroundColor3 = Color3.fromRGB(25,25,25)
	panel.Parent = GUI
	local c0 = Instance.new("UICorner") c0.CornerRadius = UDim.new(0,8) c0.Parent = panel

	-- Buttons
	local btnStart = Instance.new("TextButton")
	btnStart.Name = "BtnStart"
	btnStart.Size = UDim2.fromOffset(120, 34)
	btnStart.Position = UDim2.fromOffset(10, 10)
	btnStart.TextScaled = true
	btnStart.Text = "Start Tween"
	btnStart.Parent = panel
	local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0,8) c1.Parent = btnStart

	local btnESP = Instance.new("TextButton")
	btnESP.Name = "BtnESP"
	btnESP.Size = UDim2.fromOffset(120, 34)
	btnESP.Position = UDim2.fromOffset(130, 10)
	btnESP.TextScaled = true
	btnESP.Text = "ESP (toggle)"
	btnESP.Parent = panel
	local c2 = Instance.new("UICorner") c2.CornerRadius = UDim.new(0,8) c2.Parent = btnESP

	-- Slider (5–1000)
	local sliderLabel = Instance.new("TextLabel")
	sliderLabel.Name = "LblSpeed"
	sliderLabel.BackgroundTransparency = 1
	sliderLabel.TextScaled = true
	sliderLabel.Text = "Speed: "..tostring(TWEEN_SPEED)
	sliderLabel.Size = UDim2.fromOffset(240, 18)
	sliderLabel.Position = UDim2.fromOffset(10, 50)
	sliderLabel.TextColor3 = Color3.new(1,1,1)
	sliderLabel.Parent = panel

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromOffset(240, 6)
	bar.Position = UDim2.fromOffset(10, 78)
	bar.BackgroundColor3 = Color3.fromRGB(60,60,60)
	bar.Parent = panel
	local c3 = Instance.new("UICorner") c3.CornerRadius = UDim.new(0,3) c3.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromOffset(0, 6)
	fill.Position = UDim2.fromOffset(0, 0)
	fill.BackgroundColor3 = Color3.fromRGB(120,200,120)
	fill.Parent = bar
	local c4 = Instance.new("UICorner") c4.CornerRadius = UDim.new(0,3) c4.Parent = fill

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(10, 16)
	knob.Position = UDim2.fromOffset(0, -5)
	knob.BackgroundColor3 = Color3.fromRGB(230,230,230)
	knob.Parent = bar
	local c5 = Instance.new("UICorner") c5.CornerRadius = UDim.new(0,5) c5.Parent = knob

	local minSpeed, maxSpeed = 5, 1000
	local dragging = false
	local function updateSliderFromSpeed()
		local pct = (TWEEN_SPEED - minSpeed) / (maxSpeed - minSpeed)
		pct = math.clamp(pct, 0, 1)
		local px = math.floor(pct * bar.AbsoluteSize.X)
		fill.Size = UDim2.fromOffset(px, 6)
		knob.Position = UDim2.fromOffset(px - knob.AbsoluteSize.X/2, -5)
		sliderLabel.Text = "Speed: "..tostring(TWEEN_SPEED)
	end
	local function setSpeedFromX(x)
		local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
		local val = math.floor(minSpeed + rel * (maxSpeed - minSpeed))
		TWEEN_SPEED = math.clamp(val, minSpeed, maxSpeed)
		updateSliderFromSpeed()
	end
	bar.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setSpeedFromX(UserInputService:GetMouseLocation().X)
		end
	end)
	bar.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
			setSpeedFromX(UserInputService:GetMouseLocation().X)
		end
	end)
	updateSliderFromSpeed()

	-- Heist button
	local btnHeist = Instance.new("TextButton")
	btnHeist.Name = "BtnHeist"
	btnHeist.Size = UDim2.fromOffset(240, 34)
	btnHeist.Position = UDim2.fromOffset(10, 118)
	btnHeist.TextScaled = true
	btnHeist.Text = "Grab → Deliver (timed)"
	btnHeist.Parent = panel
	local cH = Instance.new("UICorner") cH.CornerRadius = UDim.new(0,8) cH.Parent = btnHeist

	-- Hooks
	btnStart.MouseButton1Click:Connect(function() task.spawn(goToMyDelivery) end)
	btnESP.MouseButton1Click:Connect(function()
		espOn = not espOn
		if espOn then
			highlightAllPets()
			startBaseTimersESP()
		else
			clearPetESP()
			stopBaseTimersESP()
		end
	end)
	btnHeist.MouseButton1Click:Connect(function() task.spawn(grabThenDeliverTimed) end)
end

print("[ResilienceHarness] Loaded: ESP + Timers + Tween + Heist button ready.")
