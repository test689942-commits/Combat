-- Server-authoritative inventory state with DataStore persistence.
-- Future loot code should award items through AddItem rather than changing client data.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Catalog = require(Modules:WaitForChild("Inventory"):WaitForChild("Catalog"))
local Weapons = require(Modules:WaitForChild("Weapons"))
local Store = DataStoreService:GetDataStore("CombatInventory_v1")

local InventoryService = {}
InventoryService.Changed = Instance.new("BindableEvent")

local profiles = {}
local loading = {}
local MAX_ITEMS = 150
local MAX_STACK = 100000
local MAX_GOLD = 2000000000

local function makeDefaultProfile()
	local profile = {gold = 0, nextId = 1, items = {}, dirty = true, sessionOnly = false, revision = 0}

	for _, definition in ipairs(Catalog.StarterEquipped) do
		local item = Catalog.MakeItemRecord(definition, profile.nextId, "eq")
		profile.nextId += 1
		table.insert(profile.items, item)
	end
	for _, definition in ipairs(Catalog.StarterBag) do
		local item = Catalog.MakeItemRecord(definition, profile.nextId, "bag")
		profile.nextId += 1
		table.insert(profile.items, item)
	end

	return profile
end

local function sanitizeProfile(saved)
	local profile = makeDefaultProfile()
	profile.gold = 0
	profile.nextId = 1
	profile.items = {}
	profile.dirty = false

	if type(saved) ~= "table" or (saved.version ~= 1 and saved.version ~= 2) or type(saved.items) ~= "table" then
		return makeDefaultProfile()
	end

	if type(saved.gold) == "number" then
		profile.gold = math.clamp(math.floor(saved.gold), 0, MAX_GOLD)
	end

	local needsRewrite = saved.version ~= 2
	local seenIds = {}
	local occupiedSlots = {}
	for _, item in ipairs(saved.items) do
		if #profile.items >= MAX_ITEMS then break end
		if type(item) == "table"
			and type(item.id) == "number" and item.id >= 1 and item.id % 1 == 0
			and not seenIds[item.id]
			and type(item.n) == "string" and #item.n > 0 and #item.n <= 80
			and type(item.r) == "string"
			and type(item.slot) == "string" and Catalog.IsValidSlot(item.slot)
			and (item.loc == "eq" or item.loc == "bag") then

			local weaponId = item.weaponId
			if not Catalog.IsValidWeapon(weaponId) then
				weaponId = Catalog.GetWeaponIdByDisplayName(item.n)
				if item.n == "Void Blade" then weaponId = Weapons.Default end
			end
			local weaponValid = item.slot == "weapon" and Catalog.IsValidWeapon(weaponId)
			if weaponValid then
				local location = item.loc
				local equipSlot = nil
				if location == "eq" then
					equipSlot = item.eqSlot
					if equipSlot ~= item.slot or not Catalog.IsValidSlot(equipSlot) or occupiedSlots[equipSlot] then
						location = "bag"
						equipSlot = nil
					else
						occupiedSlots[equipSlot] = true
					end
				end

				local weaponData = Weapons.Data[weaponId]
				local safe = {
					id = item.id,
					n = weaponData.DisplayName or weaponId,
					r = "common",
					slot = "weapon",
					tag = "Weapon",
					weaponId = weaponId,
					qty = 1,
					lvl = 1,
					loc = location,
					eqSlot = location == "eq" and "weapon" or nil,
				}
				if item.weaponId ~= safe.weaponId or item.n ~= safe.n or item.r ~= safe.r
					or item.slot ~= safe.slot or item.tag ~= safe.tag or item.qty ~= safe.qty or item.lvl ~= safe.lvl
					or item.loc ~= safe.loc or item.eqSlot ~= safe.eqSlot then
					needsRewrite = true
				end
				table.insert(profile.items, safe)
				seenIds[safe.id] = true
				profile.nextId = math.max(profile.nextId, safe.id + 1)
			end
		end
	end

	if type(saved.nextId) == "number" then
		profile.nextId = math.max(profile.nextId, math.floor(saved.nextId))
	end
	profile.dirty = needsRewrite or #profile.items ~= #saved.items
	return profile
end

local function dataStoreKey(player)
	return "Player_" .. tostring(player.UserId)
end

function InventoryService.Load(player: Player)
	if profiles[player] then
		return profiles[player]
	end
	if loading[player] then
		loading[player].Event:Wait()
		return profiles[player]
	end

	local completed = Instance.new("BindableEvent")
	loading[player] = completed
	local success, saved = pcall(function()
		return Store:GetAsync(dataStoreKey(player))
	end)

	local profile
	if success then
		if saved == nil then
			profile = makeDefaultProfile()
		else
			profile = sanitizeProfile(saved)
		end
	else
		-- Keep the UI usable during DataStore outages, but never save a fallback
		-- over data that could not be loaded.
		profile = makeDefaultProfile()
		profile.sessionOnly = true
		profile.dirty = false
		warn("Inventory DataStore load failed for " .. player.Name .. ": " .. tostring(saved))
	end

	profiles[player] = profile
	loading[player] = nil
	completed:Fire()
	task.defer(function()
		completed:Destroy()
	end)
	return profile
end

local function serialize(profile)
	local result = {version = 2, gold = profile.gold, nextId = profile.nextId, items = {}}
	for _, item in ipairs(profile.items) do
		table.insert(result.items, {
			id = item.id, n = item.n, r = item.r, slot = item.slot, tag = item.tag, weaponId = item.weaponId,
			qty = item.qty, lvl = item.lvl, loc = item.loc, eqSlot = item.eqSlot,
		})
	end
	return result
end

function InventoryService.Save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.dirty or profile.sessionOnly then
		return profile ~= nil
	end
	while profile.saving do
		task.wait()
	end
	if not profile.dirty or profile.sessionOnly then
		return true
	end

	profile.saving = true
	local revision = profile.revision
	local payload = serialize(profile)
	local success, message = pcall(function()
		Store:UpdateAsync(dataStoreKey(player), function()
			return payload
		end)
	end)
	profile.saving = false
	if success then
		profile.dirty = profile.revision ~= revision
	else
		warn("Inventory DataStore save failed for " .. player.Name .. ": " .. tostring(message))
	end
	return success
end

local function findItem(profile, itemId)
	if type(itemId) ~= "number" then return nil end
	for _, item in ipairs(profile.items) do
		if item.id == itemId then return item end
	end
	return nil
end

local function getSnapshot(profile)
	local snapshot = {gold = profile.gold, items = {}}
	for _, item in ipairs(profile.items) do
		local clientItem = table.clone(item)
		clientItem.stats = Catalog.GetStats(item)
		table.insert(snapshot.items, clientItem)
	end
	table.sort(snapshot.items, function(a, b) return a.id < b.id end)
	return snapshot
end

function InventoryService.GetSnapshot(player: Player)
	local profile = InventoryService.Load(player)
	return getSnapshot(profile)
end

local function equip(profile, item)
	if not item or item.loc ~= "bag" then
		return false, "That item is not in your bag."
	end

	for _, equipped in ipairs(profile.items) do
		if equipped.loc == "eq" and equipped.eqSlot == item.slot then
			equipped.loc = "bag"
			equipped.eqSlot = nil
		end
	end
	item.loc = "eq"
	item.eqSlot = item.slot
	return true
end

local function equipBest(profile)
	for _, slot in ipairs(Catalog.SlotOrder) do
		local bestItem
		local bestScore = -1
		for _, item in ipairs(profile.items) do
			if item.slot == slot then
				local score = Catalog.GetStats(item).score
				if score > bestScore then
					bestItem = item
					bestScore = score
				end
			end
		end
		if bestItem and bestItem.loc == "bag" then
			local current
			for _, item in ipairs(profile.items) do
				if item.loc == "eq" and item.eqSlot == slot then current = item; break end
			end
			if not current or bestScore > Catalog.GetStats(current).score then
				for _, item in ipairs(profile.items) do
					if item.loc == "eq" and item.eqSlot == slot then
						item.loc = "bag"
						item.eqSlot = nil
					end
				end
				bestItem.loc = "eq"
				bestItem.eqSlot = slot
			end
		end
	end
end

-- The combat system reads the selected registry key from the character attribute.
-- WeaponServer attaches the visual model separately; no Roblox Tool is created.
function InventoryService.ApplyEquippedWeapon(player: Player)
	local character = player.Character
	if not character then return end

	local weaponId
	local profile = profiles[player] or InventoryService.Load(player)
	for _, item in ipairs(profile.items) do
		if item.loc == "eq" and item.eqSlot == "weapon" and Catalog.IsValidWeapon(item.weaponId) then
			weaponId = item.weaponId
			break
		end
	end

	character:SetAttribute(Weapons.EquippedAttributeName, weaponId)

	-- Clean up a managed Tool left by an older inventory version during a live upgrade.
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("InventoryManagedWeapon") then
			child:Destroy()
		end
	end
end

function InventoryService.HandleAction(player: Player, action: string, payload)
	local profile = InventoryService.Load(player)
	if type(action) ~= "string" then
		return {success = false, message = "Invalid inventory action."}
	end
	payload = if type(payload) == "table" then payload else {}
	local changed = false
	local weaponChanged = false

	if action == "Equip" then
		local item = findItem(profile, payload.itemId)
		local success, message = equip(profile, item)
		if not success then return {success = false, message = message} end
		changed = true
		weaponChanged = item.slot == "weapon"
	elseif action == "Unequip" then
		local item = findItem(profile, payload.itemId)
		if not item or item.loc ~= "eq" then
			return {success = false, message = "That item is not equipped."}
		end
		item.loc = "bag"
		item.eqSlot = nil
		changed = true
		weaponChanged = item.slot == "weapon"
	elseif action == "EquipBest" then
		equipBest(profile)
		changed = true
		weaponChanged = true
	elseif action == "SellMany" then
		if type(payload.itemIds) ~= "table" or #payload.itemIds > MAX_ITEMS then
			return {success = false, message = "Invalid sale selection."}
		end
		local selected, total = {}, 0
		for _, itemId in ipairs(payload.itemIds) do
			local item = findItem(profile, itemId)
			if item and item.loc == "bag" and not selected[item.id] then
				selected[item.id] = true
				total += Catalog.GetStats(item).price * item.qty
			end
		end
		if total <= 0 then
			return {success = false, message = "Select items in your bag to sell."}
		end
		profile.gold = math.clamp(profile.gold + total, 0, MAX_GOLD)
		for index = #profile.items, 1, -1 do
			if selected[profile.items[index].id] then table.remove(profile.items, index) end
		end
		changed = true
	else
		return {success = false, message = "Unknown inventory action."}
	end

	if changed then
		if weaponChanged then
			InventoryService.ApplyEquippedWeapon(player)
		end
		profile.dirty = true
		profile.revision += 1
		task.spawn(InventoryService.Save, player)
	end
	return {success = true, snapshot = getSnapshot(profile)}
end

function InventoryService.Release(player: Player)
	InventoryService.Save(player)
	profiles[player] = nil
end

function InventoryService.AddItem(player: Player, definition, quantity: number?)
	local profile = InventoryService.Load(player)
	if #profile.items >= MAX_ITEMS then
		return false, "Your inventory is full."
	end
	if type(definition) ~= "table"
		or type(definition.n) ~= "string" or #definition.n == 0 or #definition.n > 80
		or type(definition.r) ~= "string" or not table.find(Catalog.RarityOrder, definition.r)
		or not Catalog.IsValidSlot(definition.slot)
		or (definition.slot == "weapon" and not Catalog.IsValidWeapon(definition.weaponId)) then
		return false, "Invalid item definition."
	end

	local item = Catalog.MakeItemRecord(definition, profile.nextId, "bag")
	item.qty = if item.slot == "weapon" then 1 else math.clamp(math.floor(tonumber(quantity) or item.qty), 1, MAX_STACK)
	profile.nextId += 1
	table.insert(profile.items, item)
	profile.dirty = true
	profile.revision += 1
	task.spawn(InventoryService.Save, player)
	InventoryService.Changed:Fire(player, getSnapshot(profile))
	return true, item.id
end

return InventoryService
