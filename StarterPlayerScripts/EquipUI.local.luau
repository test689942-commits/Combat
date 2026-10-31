--[[
	EquipUI.client.luau  —  wired to the hand-built StarterGui UI
	--------------------------------------------------------------------
	This version does NOT build any UI. It expects:

	PlayerGui.EquipUI (ScreenGui)
	  EquipPanel
	    Header (Close, Title)
	    Stats (Damage / "attack speed" / Crit / "Physical Damage" / "Magic Damage",
	           each with 2 TextLabels: [1]=label [2]=value)
	    Slots (Slot_hat, Slot_chest, Slot_trinket, Slot_wings, Slot_relic, Slot_ring, Slot_weapon)
	      each Slot_* has: SlotName, Count, ReturnBadge(.Return), boreder (ImageLabel),
	                        ReturnBar(.Return), UIStroke, HoverGlow (UIShadow)
	  ItemCard
	    ScrollingFrame > Frame (UIListLayout) — populated at runtime
	  Backpack
	    Header (Close, Title)
	    Tabs (Tab_weapon, Tab_armor, SortSlot.SortBtn)
	    Grid (UIGridLayout) — Cell9/Cell10/Cell15/Cell20/Cell22/Cell25 used as the
	                          clone template (first one found), then regenerated per item
	    Footer (EquipBest, SellBtn, Coins, Items)
	    SellBar (TextLabel, TextButton "Confirm Sale", TextButton "Cancel")

	INSTALL: StarterPlayer > StarterPlayerScripts > LocalScript named "EquipUI", paste this in.
--]]

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local InventoryClient  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Inventory"):WaitForChild("Client"))
local Weapons          = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Weapons"))
local weaponAssets     = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weapons")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui       = playerGui:WaitForChild("EquipUI")

----------------------------------------------------------------------
-- 1. THEME
----------------------------------------------------------------------
local C = {
	cellTop  = Color3.fromRGB(35, 37, 40),
	cellBot  = Color3.fromRGB(20, 21, 22),
	text     = Color3.fromRGB(233, 234, 235),
	textDim  = Color3.fromRGB(150, 152, 158),
}
-- the new hover color: applies to HoverGlow / UIStroke / boreder on EquipPanel
-- slots (and Backpack grid cells, same template), and to the Close button Glow
local HOVER_RED = Color3.fromRGB(255, 70, 70)

local RARITY = {
	common   = { color = Color3.fromRGB(111, 111, 124), name = "Common"    },
	uncommon = { color = Color3.fromRGB(78, 143, 92),   name = "Uncommon"  },
	rare     = { color = Color3.fromRGB(63, 120, 184),  name = "Rare"      },
	epic     = { color = Color3.fromRGB(138, 92, 192),  name = "Epic"      },
	legend   = { color = Color3.fromRGB(195, 154, 62),  name = "Legendary" },
	mythic   = { color = Color3.fromRGB(176, 71, 77),   name = "Mythic"    },
}
local RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legend", "mythic" }
local RARITY_INDEX = {}
for i, k in ipairs(RARITY_ORDER) do RARITY_INDEX[k] = i end

local SLOT_LABEL = {
	hat = "Hat", chest = "Chest", wings = "Cape", weapon = "Weapon",
	trinket = "Trinket", relic = "Relic", ring = "Ring",
}
local SLOT_ORDER = { "hat", "chest", "trinket", "wings", "relic", "ring", "weapon" }
local ARMOR_SLOTS = { hat = true, chest = true, wings = true, ring = true }

----------------------------------------------------------------------
-- 2. TINY UTILITIES
----------------------------------------------------------------------
local EASE = {
	juice = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	out   = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	pop   = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	soft  = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
}
local function tween(inst, info, props)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function commafy(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return out
end

----------------------------------------------------------------------
-- 3. SERVER INVENTORY STATE
----------------------------------------------------------------------
-- IDs and item data are supplied by the server. This UI owns presentation,
-- selection, and animations only; inventory mutations are always remote actions.
local ITEMS = {}
local applySnapshot
local actionInFlight = false

local State = {
	gold = 0, tab = "weapon", sellMode = false, sellSet = {},
	sorting = false, sortAsc = false, equipped = {}, bag = {},
}

local function rebuildState()
	State.equipped = {}
	State.bag = {}
	for _, item in ipairs(ITEMS) do
		if item.loc == "eq" then
			State.equipped[item.eqSlot] = item
		else
			table.insert(State.bag, item)
		end
	end
end

local function totals()
	local weapon = State.equipped.weapon
	local stats = weapon and weapon.stats or {}
	return {
		damage = stats.averageDamage or 0,
		speed = stats.averageCooldown or 0,
		crit = stats.comboCount or 0,
		phys = stats.maxDamage or 0,
		magic = stats.moves and #stats.moves or 0,
	}
end

local function requestInventoryAction(request)
	if actionInFlight then return false end
	actionInFlight = true
	local success, result = request()
	actionInFlight = false
	if success then
		if applySnapshot then applySnapshot(result) end
	else
		warn("Inventory request failed: " .. tostring(result))
	end
	return success
end

----------------------------------------------------------------------
-- 5. BIND TO EXISTING GUI
----------------------------------------------------------------------
local stage      = gui:WaitForChild("Stage")
local equipPanel = stage:WaitForChild("EquipPanel")
local packPanel  = stage:WaitForChild("Backpack")
local card       = stage:WaitForChild("ItemCard")
local cardScroll = card:WaitForChild("ScrollingFrame")
local cardList   = cardScroll:WaitForChild("Frame")

--// Panel Layout \\--

local PANEL_WIDTH_FILL = 0.94
local PANEL_HEIGHT_FILL = 0.96
local MIN_PANEL_SCALE = 0.15
local FALLBACK_AREA = Vector2.new(1280, 720)

local function getFitScale(panel: GuiObject): UIScale
	local scale = panel:FindFirstChild("FitScale")

	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "FitScale"
		scale.Parent = panel
	end

	return scale
end

local panelScales = {getFitScale(equipPanel), getFitScale(packPanel), getFitScale(card)}

local function fitViewport()
	local area = stage.AbsoluteSize

	if area.X <= 0 or area.Y <= 0 then
		area = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or FALLBACK_AREA
	end

	local panelsWidth = equipPanel.Size.X.Offset + packPanel.Size.X.Offset
	local panelsHeight = math.max(equipPanel.Size.Y.Offset, packPanel.Size.Y.Offset)
	local fitScale = math.min(area.X * PANEL_WIDTH_FILL / panelsWidth, area.Y * PANEL_HEIGHT_FILL / panelsHeight)
	fitScale = math.clamp(fitScale, MIN_PANEL_SCALE, 1)

	for _, scale in panelScales do
		scale.Scale = fitScale
	end
end

fitViewport()
stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitViewport)
player.CharacterAdded:Connect(function()
	task.wait(0.1)
	fitViewport()
end)

local function showPanel(panel) panel.Visible = true end
local function hidePanel(panel) panel.Visible = false end

----------------------------------------------------------------------
-- Close buttons — hover glow now uses HOVER_RED
----------------------------------------------------------------------
local function wireClose(panel)
	local head  = panel:WaitForChild("Header")
	local btn   = head:WaitForChild("Close")
	local st    = btn:WaitForChild("UIStroke")
	local glow  = btn:WaitForChild("Glow") -- UIShadow
	local sc    = btn:WaitForChild("UIScale")
	local baseStroke = st.Color
	local baseGlowColor = glow.Color
	local baseGlowTransparency = glow.Transparency

	local glowTween
	local function setGlow(color, transparency, info)
		if glowTween then glowTween:Cancel() end
		glowTween = tween(glow, info or EASE.out, { Color = color, Transparency = transparency })
	end

	btn.MouseEnter:Connect(function()
		tween(btn, EASE.juice, { Rotation = 180 })
		tween(st, EASE.soft, { Color = HOVER_RED })
		tween(sc, EASE.juice, { Scale = 1.12 })
		setGlow(HOVER_RED, 0.25, EASE.out)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, EASE.out, { Rotation = 0 })
		tween(st, EASE.soft, { Color = baseStroke })
		tween(sc, EASE.soft, { Scale = 1 })
		setGlow(baseGlowColor, baseGlowTransparency, EASE.out)
	end)
	btn.MouseButton1Down:Connect(function()
		tween(sc, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.84 })
	end)
	btn.MouseButton1Up:Connect(function()
		tween(sc, EASE.juice, { Scale = 1.12 })
	end)
	btn.MouseButton1Click:Connect(function()
		hidePanel(panel)
	end)
end
wireClose(equipPanel)
wireClose(packPanel)

----------------------------------------------------------------------
-- 6. EQUIP SLOTS
----------------------------------------------------------------------
local slotsFrame = equipPanel:WaitForChild("Slots")
local slotViews = {}
local SLOT_LINE_EMPTY = Color3.fromRGB(62, 64, 69)
local SLOT_NAME       = Color3.fromRGB(135, 139, 148)
local SLOT_NAME_HOVER = Color3.fromRGB(218, 219, 222)

local function wireSlot(kind)
	local box = slotsFrame:WaitForChild("Slot_" .. kind)
	local st       = box:WaitForChild("UIStroke")
	local hoverGlow= box:WaitForChild("HoverGlow")
	local boreder  = box:WaitForChild("boreder")
	local name     = box:WaitForChild("SlotName")
	local count    = box:WaitForChild("Count")
	local retWrap  = box:WaitForChild("ReturnBar")
	local retLabel = retWrap:WaitForChild("Return")
	local badge    = box:WaitForChild("ReturnBadge")
	local badgeScale  = badge:WaitForChild("UIScale")
	local badgeStroke = badge:WaitForChild("UIStroke")
	local badgeText   = badge:WaitForChild("Return")
	local sc       = box:WaitForChild("UIScale")

	-- rest state for the badge pop
	badge.Visible = true
	badge.ZIndex = math.max(badge.ZIndex, box.boreder.ZIndex + 1)
	badgeScale.Scale = 0.5
	badgeStroke.Transparency = 1
	badgeText.TextTransparency = 1

	local view = {
		box = box, stroke = st, glow = hoverGlow, boreder = boreder,
		name = name, count = count, retWrap = retWrap, retLabel = retLabel,
		badge = badge, badgeScale = badgeScale, badgeStroke = badgeStroke,
		badgeText = badgeText, scale = sc,
	}
	slotViews[kind] = view

	box.MouseEnter:Connect(function()
		-- new hover color applies here regardless of filled/empty
		tween(st, EASE.soft, { Color = HOVER_RED, Thickness = 2 })
		tween(hoverGlow, EASE.out, { Color = HOVER_RED, Transparency = 0.4 })
		tween(boreder, EASE.soft, { ImageColor3 = HOVER_RED })
		tween(sc, EASE.juice, { Scale = 1.035 })

		if State.equipped[kind] then
			tween(count, EASE.soft, { TextTransparency = 1 })
			retWrap.Visible = true
			tween(retWrap, EASE.out, { BackgroundTransparency = 0 })
			tween(retLabel, EASE.soft, { TextTransparency = 0 })
			badge.BackgroundTransparency = 0
			badgeScale.Scale = 0.5
			tween(badgeScale, EASE.pop, { Scale = 1 })
			tween(badgeStroke, EASE.soft, { Transparency = 0 })
			tween(badgeText, EASE.soft, { TextTransparency = 0 })
		else
			tween(name, EASE.soft, { TextColor3 = SLOT_NAME_HOVER })
		end
	end)

	box.MouseLeave:Connect(function()
		local it = State.equipped[kind]
		local restColor = it and RARITY[it.r].color or SLOT_LINE_EMPTY
		tween(st, EASE.soft, { Color = restColor, Thickness = 2 })
		tween(hoverGlow, EASE.soft, { Transparency = 1 })
		tween(boreder, EASE.soft, { ImageColor3 = it and RARITY[it.r].color or SLOT_LINE_EMPTY })
		tween(sc, EASE.soft, { Scale = 1 })

		if it then
			tween(count, EASE.soft, { TextTransparency = 0 })
			tween(retWrap, EASE.soft, { BackgroundTransparency = 1 })
			tween(retLabel, EASE.soft, { TextTransparency = 1 })
			tween(badgeScale, EASE.soft, { Scale = 0.5 })
			tween(badgeStroke, EASE.soft, { Transparency = 1 })
			tween(badgeText, EASE.soft, { TextTransparency = 1 })
			task.delay(0.2, function()
				if not State.equipped[kind] then return end
				retWrap.Visible = false
				badge.BackgroundTransparency = 1
			end)
		else
			tween(name, EASE.soft, { TextColor3 = SLOT_NAME })
		end
	end)

	box.MouseButton1Click:Connect(function()
		local it = State.equipped[kind]
		if not it then return end
		if currentCardItem == it and card.Visible then
			closeCard()
		else
			openCard(it, "eq")
		end
	end)

	return view
end
for _, kind in ipairs(SLOT_ORDER) do wireSlot(kind) end

--// Weapon Previews \\--

local PREVIEW_FOV = 30
local PREVIEW_MARGIN = 1.2
local PREVIEW_YAW = math.rad(-12)
local PREVIEW_DIAGONAL = Vector3.new(1, 1, 0).Unit
local PREVIEW_ANCHOR = Vector2.new(0.5, 0)
local PREVIEW_POSITION = UDim2.fromScale(0.5, 0.19)
local PREVIEW_SIZE = UDim2.fromScale(0.84, 0.56)
local PREVIEW_HANDLE_THRESHOLD = 0.1
local PREVIEW_PARALLEL_LIMIT = 0.001
local CELL_PREVIEW_ASPECT = 1.5
local SLOT_PREVIEW_ASPECT = 1.7
local WORLD_AXES = {Vector3.xAxis, Vector3.yAxis, Vector3.zAxis}

local previewModels = {}

local function getWorldBounds(model: Model): (Vector3, Vector3)
	local minimum = Vector3.one * math.huge
	local maximum = -Vector3.one * math.huge

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2

			for _, x in {-1, 1} do
				for _, y in {-1, 1} do
					for _, z in {-1, 1} do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						minimum = minimum:Min(corner)
						maximum = maximum:Max(corner)
					end
				end
			end
		end
	end

	return minimum, maximum
end

local function buildPreviewModel(weaponId: string): Model?
	local weapon = Weapons.Data[weaponId]
	local source = weapon and weapon.Model and weaponAssets:FindFirstChild(weapon.Model, true)

	if not source or not source:IsA("Model") then
		return nil
	end

	local model = source:Clone()

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	local minimum, maximum = getWorldBounds(model)
	local size = maximum - minimum
	model:PivotTo(model:GetPivot() - (minimum + maximum) / 2)

	local dimensions = {size.X, size.Y, size.Z}
	local longIndex = 1
	local thinIndex = 1

	for index = 2, 3 do
		if dimensions[index] > dimensions[longIndex] then
			longIndex = index
		end

		if dimensions[index] < dimensions[thinIndex] then
			thinIndex = index
		end
	end

	if thinIndex == longIndex then
		thinIndex = if longIndex == 1 then 2 else 1
	end

	local longAxis = WORLD_AXES[longIndex]
	local thinAxis = WORLD_AXES[thinIndex]
	local handle = model:FindFirstChild("Handle")

	if handle and handle:IsA("BasePart") and handle.Position:Dot(longAxis) > dimensions[longIndex] * PREVIEW_HANDLE_THRESHOLD then
		longAxis = -longAxis
	end

	local alignAxis = longAxis:Cross(PREVIEW_DIAGONAL)
	local alignAngle = math.acos(math.clamp(longAxis:Dot(PREVIEW_DIAGONAL), -1, 1))
	local align = CFrame.fromAxisAngle(alignAxis.Unit, alignAngle)

	local thinDirection = align:VectorToWorldSpace(thinAxis)
	local thinFlat = thinDirection - PREVIEW_DIAGONAL * thinDirection:Dot(PREVIEW_DIAGONAL)
	local faceCamera = CFrame.identity

	if thinFlat.Magnitude > PREVIEW_PARALLEL_LIMIT then
		local faceAngle = math.atan2(PREVIEW_DIAGONAL:Dot(thinFlat:Cross(Vector3.zAxis)), thinFlat:Dot(Vector3.zAxis))
		faceCamera = CFrame.fromAxisAngle(PREVIEW_DIAGONAL, faceAngle)
	end

	model:PivotTo(CFrame.Angles(0, PREVIEW_YAW, 0) * faceCamera * align * model:GetPivot())

	local finalMinimum, finalMaximum = getWorldBounds(model)
	model:PivotTo(model:GetPivot() - (finalMinimum + finalMaximum) / 2)
	model:SetAttribute("PreviewExtents", finalMaximum - finalMinimum)

	return model
end

local function getPreviewModel(weaponId: string): Model?
	local cached = previewModels[weaponId]

	if cached == nil then
		cached = buildPreviewModel(weaponId) or false
		previewModels[weaponId] = cached
	end

	return cached or nil
end

local function createPreview(weaponId: string?, aspect: number?): ViewportFrame?
	local template = weaponId and getPreviewModel(weaponId)

	if not template then
		return nil
	end

	local extents = template:GetAttribute("PreviewExtents")
	local halfTan = math.tan(math.rad(PREVIEW_FOV / 2))
	local viewAspect = aspect or CELL_PREVIEW_ASPECT
	local distance = math.max(extents.Y / (2 * halfTan), extents.X / (2 * halfTan * viewAspect)) * PREVIEW_MARGIN + extents.Z / 2

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ItemIcon"
	viewport.AnchorPoint = PREVIEW_ANCHOR
	viewport.Position = PREVIEW_POSITION
	viewport.Size = PREVIEW_SIZE
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Active = false
	viewport.ZIndex = 0
	viewport.Ambient = Color3.fromRGB(170, 170, 178)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-0.5, -0.8, -1)

	template:Clone().Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = PREVIEW_FOV
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	return viewport
end

local function renderSlot(kind)
	local v = slotViews[kind]
	local it = State.equipped[kind]
	local oldPreview = v.box:FindFirstChild("ItemIcon")

	if oldPreview then
		oldPreview:Destroy()
	end

	v.retWrap.Visible = false
	v.retWrap.BackgroundTransparency = 1
	v.retLabel.TextTransparency = 1
	v.badge.BackgroundTransparency = 1
	v.badgeScale.Scale = 0.5
	v.badgeStroke.Transparency = 1
	v.badgeText.TextTransparency = 1
	v.name.TextColor3 = SLOT_NAME
	if not it then
		v.name.Text = SLOT_LABEL[kind] or kind
		v.stroke.Color = SLOT_LINE_EMPTY
		v.boreder.ImageColor3 = SLOT_LINE_EMPTY
		v.count.Text = ""
		return
	end
	v.name.Text = it.n
	v.stroke.Color = RARITY[it.r].color
	v.boreder.ImageColor3 = RARITY[it.r].color
	v.count.Text = ""

	local preview = createPreview(it.weaponId, SLOT_PREVIEW_ASPECT)

	if preview then
		preview.Parent = v.box
	end
end

----------------------------------------------------------------------
-- 7. STATS
----------------------------------------------------------------------
local STAT_DEFS = {
	{ k = "damage", row = "Damage",          label = "Average Hit",  dec = 1, suf = ""  },
	{ k = "speed",  row = "attack speed",    label = "Avg Cooldown", dec = 2, suf = "s" },
	{ k = "crit",   row = "Crit",            label = "Combo Hits",   dec = 0, suf = ""  },
	{ k = "phys",   row = "Physical Damage", label = "Max Hit",      dec = 1, suf = ""  },
	{ k = "magic",  row = "Magic Damage",    label = "Special Moves",dec = 0, suf = ""  },
}
local statsHolder = equipPanel:WaitForChild("Stats")
local statLabels = {}
for _, def in ipairs(STAT_DEFS) do
	local row = statsHolder:WaitForChild(def.row)
	local labels = {}
	for _, c in ipairs(row:GetChildren()) do
		if c:IsA("TextLabel") then table.insert(labels, c) end
	end
	table.sort(labels, function(a, b)
		local aX = a.Position.X.Scale * 100000 + a.Position.X.Offset
		local bX = b.Position.X.Scale * 100000 + b.Position.X.Offset
		return aX < bX
	end)
	if labels[1] then labels[1].Text = def.label end
	statLabels[def.k] = labels[2] -- [1]=label, [2]=value
end

local function fmtStat(v, def)
	v = math.max(0, v)
	if def.dec > 0 then return string.format("%." .. def.dec .. "f", v) .. def.suf end
	return tostring(math.floor(v + 0.5)) .. def.suf
end

local function refreshStats()
	local t = totals()
	for _, def in ipairs(STAT_DEFS) do
		statLabels[def.k].Text = fmtStat(t[def.k], def)
	end
end

----------------------------------------------------------------------
-- 8. ITEM CARD
----------------------------------------------------------------------
local currentCardItem, currentCardMode = nil, "bag"
local equipItem, unequipItem, discardItem -- forward decls

function closeCard()
	card.Visible = false
	currentCardItem = nil
end

function openCard(item, mode)
	currentCardItem, currentCardMode = item, mode or "bag"
	cardScroll.CanvasPosition = Vector2.new(0, 0)
	cardList:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cardList

	local rar = RARITY[item.r]
	card.UIStroke.Color = rar.color

	local function row(order, height, text, size, color, bg)
		local f = Instance.new("Frame")
		f.LayoutOrder = order
		f.Size = UDim2.new(1, 0, 0, height)
		f.BackgroundColor3 = bg or Color3.fromRGB(14, 15, 16)
		f.BorderSizePixel = 0
		f.Parent = cardList
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = size or 15
		lbl.TextColor3 = color or C.text
		lbl.Text = text
		lbl.Parent = f
		return f
	end

	local stats = item.stats
	row(1, 40, item.n, 19, Color3.fromRGB(242, 234, 214), Color3.fromRGB(28, 26, 20))
	row(2, 24, tostring(stats.category or "Weapon") .. " · Weapon", 15, C.text)
	row(3, 24, "Combo hits: " .. tostring(stats.comboCount or 0), 15, C.textDim)
	row(4, 24, string.format("Average hit damage: %.1f", stats.averageDamage or 0), 15, C.text)
	row(5, 24, string.format("Max hit damage: %.1f", stats.maxDamage or 0), 15, C.text)
	row(6, 24, string.format("Average cooldown: %.2f s", stats.averageCooldown or 0), 15, C.text)

	local order = 7
	if #stats.moves > 0 then
		row(order, 24, "Moves in combat registry", 14, Color3.fromRGB(236, 237, 240)); order += 1
		for _, moveName in ipairs(stats.moves) do
			row(order, 24, "• " .. moveName, 13, C.textDim)
			order += 1
		end
	else
		row(order, 24, "No special moves listed in the combat registry", 13, C.textDim)
		order += 1
	end
	row(order, 30, "Sell value: " .. commafy(stats.price or 0) .. " gold", 16, Color3.fromRGB(232, 223, 198)); order += 1

	local btnRow = Instance.new("Frame")
	btnRow.LayoutOrder = order
	btnRow.Size = UDim2.new(1, 0, 0, 50)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent = cardList
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -20, 0, 40)
	btn.Position = UDim2.fromOffset(10, 5)
	btn.BackgroundColor3 = Color3.fromRGB(81, 84, 91)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 18
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = (mode == "eq") and "Unequip" or "Equip"
	btn.Parent = btnRow
	btn.MouseButton1Click:Connect(function()
		closeCard()
		if mode == "eq" then unequipItem(item) else equipItem(item) end
	end)

	card.Visible = true
end

----------------------------------------------------------------------
-- 9. BACKPACK: TABS, SORT, GRID
----------------------------------------------------------------------
local tabs      = packPanel:WaitForChild("Tabs")
local tabWeapon = tabs:WaitForChild("Tab_weapon")
local tabArmor  = tabs:WaitForChild("Tab_armor")
local sortBtn   = tabs:WaitForChild("SortSlot"):WaitForChild("SortBtn")
local grid      = packPanel:WaitForChild("Grid")
local footer    = packPanel:WaitForChild("Footer")
local sellBar   = packPanel:WaitForChild("SellBar")

local renderGrid -- forward decl

local TAB_ON1, TAB_ON2   = Color3.fromRGB(81, 84, 91), Color3.fromRGB(40, 41, 44)
local TAB_OFF1, TAB_OFF2 = Color3.fromRGB(35, 37, 40), Color3.fromRGB(20, 21, 22)
local TAB_TEXT_ON, TAB_TEXT_OFF = Color3.new(1, 1, 1), Color3.fromRGB(182, 184, 189)
local activeStroke, idleStroke = Color3.fromRGB(174, 177, 182), Color3.fromRGB(52, 54, 57)

local function paintTab(tab, active, animate)
	tab.Underline.Visible = true
	local targetSize = active and UDim2.new(1, -26, 0, 3) or UDim2.new(0, 0, 0, 3)
	if animate then
		tab.Underline.Size = UDim2.new(0, 0, 0, 3)
		tween(tab.Underline, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = targetSize })
	else
		tab.Underline.Size = targetSize
	end
	tab.UIStroke.Color = active and activeStroke or idleStroke
	tab.Caption.TextColor3 = active and TAB_TEXT_ON or TAB_TEXT_OFF
	local c1 = active and TAB_ON1 or TAB_OFF1
	local c2 = active and TAB_ON2 or TAB_OFF2
	tab.UIGradient.Color = ColorSequence.new(c1, c2)
end

local function setActiveTab(key, animate)
	State.tab = key
	paintTab(tabWeapon, key == "weapon", animate)
	paintTab(tabArmor, key == "armor", animate)
end
tabWeapon.MouseButton1Click:Connect(function()
	if State.tab == "weapon" then return end
	setActiveTab("weapon", true); renderGrid()
end)
tabArmor.MouseButton1Click:Connect(function()
	if State.tab == "armor" then return end
	setActiveTab("armor", true); renderGrid()
end)
setActiveTab("weapon")

sortBtn.MouseButton1Click:Connect(function()
	State.sorting = true
	State.sortAsc = not State.sortAsc
	tween(sortBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = sortBtn.Rotation + 360 })
	renderGrid()
end)

-- grab one existing Cell* as the clone template, then wipe the grid and
-- regenerate it from State.bag every render
local cellTemplate
for _, c in ipairs(grid:GetChildren()) do
	if c:IsA("TextButton") and c.Name:match("^Cell") then
		cellTemplate = c:Clone()
		break
	end
end

local cellViews = {}
local dragging, dragAdd = false, true

local function sellValue(it) return it.stats.price * it.qty end

local function paintSell()
	local total, count = 0, 0
	for id, cell in pairs(cellViews) do
		local on = State.sellSet[id] == true
		cell.stroke.Color = on and Color3.fromRGB(224, 119, 127) or RARITY[cell.item.r].color
		if on then count += 1; total += sellValue(cell.item) end
	end
	sellBar.TextLabel.Text = count .. " selected · " .. commafy(total)
end

local function onCellClick(cell)
	if State.sellMode then
		State.sellSet[cell.item.id] = not State.sellSet[cell.item.id]
		paintSell()
		return
	end
	if currentCardItem == cell.item and card.Visible then
		closeCard()
	else
		openCard(cell.item, "bag")
	end
end

local function buildList()
	local list = {}
	for _, it in ipairs(State.bag) do
		if State.sellMode then
			table.insert(list, it)
		elseif State.tab == "weapon" then
			if it.slot == "weapon" then table.insert(list, it) end
		else
			if ARMOR_SLOTS[it.slot] then table.insert(list, it) end
		end
	end
	if State.sorting then
		table.sort(list, function(a, b)
			local ai, bi = RARITY_INDEX[a.r] or 0, RARITY_INDEX[b.r] or 0
			if ai ~= bi then
				if State.sortAsc then return ai < bi end
				return ai > bi
			end
			return a.id < b.id
		end)
	end
	return list
end

-- Replace ONLY makeCell(item, index) in the hand-built-UI script you pasted
-- with this version. It assumes that script's existing locals/helpers remain
-- unchanged (State, RARITY, HOVER_RED, EASE, tween, paintSell, etc.).
--
-- Load/tab-change motion is a soft fade + tiny settle. There is no bounce or
-- initial rotation. Since renderGrid() calls makeCell() after each tab switch,
-- the new tab's cells automatically use this transition.

local function makeCell(item, index)
	local box = cellTemplate:Clone()
	box.Name = "Cell" .. tostring(item.id)
	box.LayoutOrder = index
	box.Parent = grid

	local st      = box:WaitForChild("UIStroke")
	local glow    = box:WaitForChild("HoverGlow")
	local boreder = box:WaitForChild("boreder")
	local count   = box:WaitForChild("Count")
	local badge   = box:WaitForChild("ReturnBadge")

	st.Color = RARITY[item.r].color
	boreder.ImageColor3 = RARITY[item.r].color
	count.Text = "x" .. tostring(item.qty)
	badge.BackgroundTransparency = 1
	box.ReturnBar.Visible = false

	local slotName = box:WaitForChild("SlotName")
	slotName.Text = item.n
	slotName.TextColor3 = C.text
	slotName.TextTruncate = Enum.TextTruncate.AtEnd

	local preview = createPreview(item.weaponId, CELL_PREVIEW_ASPECT)

	if preview then
		preview.Parent = box
	end

	-- Find the actual item art, not the border/count/selection overlays.
	-- Prefer a named art holder; otherwise choose the largest non-empty image.
	local artNames = { "CelIcon", "CellIcon", "ItemIcon", "Icon", "ItemImage" }
	local art
	for _, name in ipairs(artNames) do
		art = box:FindFirstChild(name, true)
		if art and art:IsA("GuiObject") then break end
		art = nil
	end
	if not art then
		local bestArea = -1
		for _, obj in ipairs(box:GetDescendants()) do
			if (obj:IsA("ImageLabel") or obj:IsA("ImageButton"))
				and obj.Name ~= "boreder" and obj.Name:lower() ~= "border"
				and obj.Image ~= "" then
				local area = obj.AbsoluteSize.X * obj.AbsoluteSize.Y
				if area > bestArea then
					bestArea = area
					art = obj
				end
			end
		end
	end

	local artScale
	if art then
		artScale = art:FindFirstChildOfClass("UIScale")
		if not artScale then
			artScale = Instance.new("UIScale")
			artScale.Scale = 1
			artScale.Parent = art
		end
	end

	local cellScale = box:FindFirstChildOfClass("UIScale")
	if not cellScale then
		cellScale = Instance.new("UIScale")
		cellScale.Scale = 1
		cellScale.Parent = box
	end

	local cell = { box = box, stroke = st, item = item, art = art,
		artScale = artScale, scale = cellScale, glow = glow,
		baseStroke = RARITY[item.r].color }
	cellViews[item.id] = cell

	local function onHover()
		if State.sellMode then
			-- Keep the existing sell-mode red hover cue and selection ring.
			tween(glow, EASE.out, { Color = HOVER_RED, Transparency = 0.35 })
			return
		end
		if State.sellSet[item.id] then return end

		-- HTML-matched hover: slight lift/scale, icon tilt + growth, rarity glow.
		tween(cellScale, EASE.juice, { Scale = 1.045 })
		tween(st, EASE.soft, { Color = Color3.fromRGB(214, 214, 224), Thickness = 2.5 })
		tween(boreder, EASE.soft, { ImageColor3 = Color3.fromRGB(214, 214, 224) })
		tween(glow, EASE.out, { Color = RARITY[item.r].color, Transparency = 0.35 })
		if art then tween(art, EASE.juice, { Rotation = -3 }) end
		if artScale then tween(artScale, EASE.juice, { Scale = 1.12 }) end
	end

	local function onLeave()
		tween(glow, EASE.soft, { Transparency = 1 })
		if State.sellSet[item.id] then return end
		if State.sellMode then return end
		tween(cellScale, EASE.soft, { Scale = 1 })
		tween(st, EASE.soft, { Color = RARITY[item.r].color, Thickness = 2 })
		tween(boreder, EASE.soft, { ImageColor3 = RARITY[item.r].color })
		if art then tween(art, EASE.out, { Rotation = 0 }) end
		if artScale then tween(artScale, EASE.out, { Scale = 1 }) end
	end

	box.MouseButton1Click:Connect(function()
		onCellClick(cell)
	end)

	box.MouseButton1Down:Connect(function()
		if not State.sellMode then
			tween(cellScale, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.99 })
			return
		end
		dragging = true
		dragAdd = not State.sellSet[item.id]
		State.sellSet[item.id] = dragAdd or nil
		paintSell()
	end)

	box.MouseButton1Up:Connect(function()
		if not State.sellMode then
			tween(cellScale, EASE.juice, { Scale = 1.045 })
		end
	end)

	box.MouseEnter:Connect(function()
		onHover()
		if State.sellMode and dragging then
			State.sellSet[item.id] = dragAdd or nil
			paintSell()
		end
	end)
	box.MouseLeave:Connect(onLeave)

	-- Fade the cell's existing visuals in, then make a very small smooth settle.
	-- Capture each original transparency first so text, images and strokes return
	-- to exactly their template opacity. No grid-owned Position/Rotation changes.
	local fades = {}
	local function hideToReveal(obj, property)
		local ok, original = pcall(function() return obj[property] end)
		if not ok or type(original) ~= "number" or original >= 1 then return end
		local setOk = pcall(function() obj[property] = 1 end)
		if setOk then
			table.insert(fades, { object = obj, property = property, value = original })
		end
	end
	local function captureVisual(obj)
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			hideToReveal(obj, "TextTransparency")
			hideToReveal(obj, "TextStrokeTransparency")
			hideToReveal(obj, "BackgroundTransparency")
		elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			hideToReveal(obj, "ImageTransparency")
			hideToReveal(obj, "BackgroundTransparency")
		elseif obj:IsA("ViewportFrame") then
			hideToReveal(obj, "ImageTransparency")
		elseif obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
			hideToReveal(obj, "BackgroundTransparency")
		elseif obj:IsA("UIStroke") or obj.Name == "HoverGlow" then
			hideToReveal(obj, "Transparency")
		end
	end
	captureVisual(box)
	for _, obj in ipairs(box:GetDescendants()) do captureVisual(obj) end

	cellScale.Scale = 0.96
	if artScale then artScale.Scale = 0.96 end
	task.delay((index - 1) * 0.03, function()
		if not box.Parent then return end
		local reveal = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		for _, fade in ipairs(fades) do
			tween(fade.object, reveal, { [fade.property] = fade.value })
		end
		tween(cellScale, reveal, { Scale = 1 })
		if artScale then tween(artScale, reveal, { Scale = 1 }) end
	end)

	return cell
end


UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

function renderGrid()
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("TextButton") and c.Name:match("^Cell") then c:Destroy() end
	end
	cellViews = {}
	local list = buildList()
	for i, it in ipairs(list) do
		makeCell(it, i)
	end

	local count = #State.bag
	footer.Items.Text = count .. "/150"
	if State.sellMode then paintSell() end
end

----------------------------------------------------------------------
-- 10. EQUIP / UNEQUIP / DISCARD / EQUIP BEST / SELL
----------------------------------------------------------------------
function equipItem(item)
	if item.loc == "eq" then return end
	requestInventoryAction(function()
		return InventoryClient.Equip(item.id)
	end)
end

function unequipItem(item)
	if item.loc ~= "eq" then return end
	requestInventoryAction(function()
		return InventoryClient.Unequip(item.id)
	end)
end

function discardItem(item)
	if item.loc ~= "bag" then return end
	requestInventoryAction(function()
		return InventoryClient.SellMany({ item.id })
	end)
end

footer.EquipBest.MouseButton1Click:Connect(function()
	requestInventoryAction(function()
		return InventoryClient.EquipBest()
	end)
end)

local function setSellMode(on)
	State.sellMode = on
	State.sellSet = {}
	footer.Visible = not on
	sellBar.Visible = on
	renderGrid()
end
footer.SellBtn.MouseButton1Click:Connect(function() setSellMode(not State.sellMode) end)

-- SellBar's two TextButtons aren't uniquely named — find by position
local confirmBtn, cancelBtn
for _, c in ipairs(sellBar:GetChildren()) do
	if c:IsA("TextButton") then
		if c.Position.X.Offset == -96 then confirmBtn = c
		elseif c.Position.X.Offset == -8 then cancelBtn = c end
	end
end
cancelBtn.MouseButton1Click:Connect(function() setSellMode(false) end)
confirmBtn.MouseButton1Click:Connect(function()
	local itemIds = {}
	for id, selected in pairs(State.sellSet) do
		if selected then table.insert(itemIds, id) end
	end
	if #itemIds == 0 then return end
	local success = requestInventoryAction(function()
		return InventoryClient.SellMany(itemIds)
	end)
	if success then setSellMode(false) end
end)

----------------------------------------------------------------------
-- 11. KEYBINDS + RESET
----------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if State.sellMode then setSellMode(false) else closeCard() end
	end
end)

--// Toggle \\--

local TOGGLE_KEY = Enum.KeyCode.M

local function closeUi()
	if State.sellMode then
		setSellMode(false)
	end

	closeCard()
	stage.Visible = false
end

local function openUi()
	showPanel(equipPanel)
	showPanel(packPanel)
	stage.Visible = true
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or input.KeyCode ~= TOGGLE_KEY then
		return
	end

	if stage.Visible then
		closeUi()
	else
		openUi()
	end
end)

local function resetAll()
	State.tab = "weapon"
	State.sorting = false
	State.sortAsc = false
	State.sellMode = false
	State.sellSet = {}
	footer.Visible = true
	sellBar.Visible = false
	showPanel(equipPanel)
	showPanel(packPanel)
	setActiveTab("weapon")
	local success, snapshot = InventoryClient.Get()
	if success then
		applySnapshot(snapshot)
	else
		warn("Inventory refresh failed: " .. tostring(snapshot))
	end
end

local function applyInventorySnapshot(snapshot)
	if type(snapshot) ~= "table" or type(snapshot.items) ~= "table" then
		warn("Inventory returned an invalid snapshot.")
		return
	end

	ITEMS = {}
	for _, serverItem in ipairs(snapshot.items) do
		if type(serverItem) == "table" and type(serverItem.id) == "number" and type(serverItem.stats) == "table" then
			table.insert(ITEMS, table.clone(serverItem))
		end
	end
	State.gold = if type(snapshot.gold) == "number" then snapshot.gold else 0
	State.sellSet = {}
	if currentCardItem then closeCard() end
	rebuildState()
	for _, kind in ipairs(SLOT_ORDER) do renderSlot(kind) end
	renderGrid()
	refreshStats()
	footer.Coins.Text = commafy(State.gold)
end
applySnapshot = applyInventorySnapshot

----------------------------------------------------------------------
-- 12. BOOT FROM SERVER
----------------------------------------------------------------------
for _, kind in ipairs(SLOT_ORDER) do renderSlot(kind) end
renderGrid()
refreshStats()
footer.Coins.Text = commafy(State.gold)
showPanel(equipPanel)
showPanel(packPanel)

local updateRevision = 0
InventoryClient.OnUpdated(function(snapshot)
	updateRevision += 1
	applySnapshot(snapshot)
end)
local revisionBeforeFetch = updateRevision
local loaded, snapshotOrError = InventoryClient.Get()
if loaded then
	-- If a push arrived while Get() was yielding, prefer that newer snapshot.
	if updateRevision == revisionBeforeFetch then
		applySnapshot(snapshotOrError)
	end
else
	warn("Inventory load failed: " .. tostring(snapshotOrError))
end
