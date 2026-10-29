-- Weapon inventory catalog backed by the combat weapon registry.
-- Until nonweapon equipment is implemented, the inventory contains weapons only.

local Catalog = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Weapons"))

Catalog.RarityOrder = {"common", "uncommon", "rare", "epic", "legend", "mythic"}
Catalog.SlotOrder = {"weapon"}
Catalog.ValidSlots = {weapon = true}

Catalog.StarterEquipped = {
	{
		slot = "weapon",
		weaponId = Weapons.Default,
		n = Weapons.Data[Weapons.Default].DisplayName or Weapons.Default,
		r = "common",
		tag = "Weapon",
		lvl = 1,
	},
}

Catalog.StarterBag = {}
for _, weaponId in ipairs(Weapons.Order) do
	if weaponId ~= Weapons.FistsName and weaponId ~= Weapons.Default then
		local weapon = Weapons.Data[weaponId]
		table.insert(Catalog.StarterBag, {
			n = weapon.DisplayName or weaponId,
			weaponId = weaponId,
			r = "common",
			slot = "weapon",
			tag = "Weapon",
			q = 1,
			lvl = 1,
		})
	end
end

function Catalog.IsValidWeapon(weaponId)
	return type(weaponId) == "string"
		and weaponId ~= Weapons.FistsName
		and Weapons.Data[weaponId] ~= nil
end

function Catalog.GetWeaponIdByDisplayName(displayName)
	for weaponId, weapon in pairs(Weapons.Data) do
		if weaponId ~= Weapons.FistsName and weapon.DisplayName == displayName then
			return weaponId
		end
	end
	return nil
end

function Catalog.IsValidSlot(slot)
	return Catalog.ValidSlots[slot] == true
end

-- These facts come from the same combo/move data used by combat. No synthetic
-- affixes, random skills, rarity rolls, or stat rolls are generated for weapons.
function Catalog.GetStats(item)
	local weapon = Weapons.Data[item.weaponId]
	if not weapon then
		return {
			score = 0,
			maxDamage = 0,
			averageDamage = 0,
			averageCooldown = 0,
			comboCount = 0,
			moves = {},
			category = "Unknown",
			price = 0,
		}
	end

	local totalDamage = 0
	local maxDamage = 0
	local totalCooldown = 0
	local combo = weapon.Combo or {}
	for _, hit in ipairs(combo) do
		local damage = tonumber(hit.Damage) or 0
		totalDamage += damage
		maxDamage = math.max(maxDamage, damage)
		totalCooldown += tonumber(hit.Cooldown) or 0
	end

	local comboCount = if #combo > 0 then #combo else (weapon.MaxCombo or 0)
	local averageDamage = if #combo > 0 then totalDamage / #combo else 0
	local averageCooldown = if #combo > 0 then totalCooldown / #combo else 0
	local moves = {}
	for _, moveName in ipairs(weapon.Moves or {}) do
		table.insert(moves, moveName)
	end

	return {
		-- Equip Best compares the average damage defined by this weapon's combo.
		score = averageDamage,
		maxDamage = maxDamage,
		averageDamage = averageDamage,
		averageCooldown = averageCooldown,
		comboCount = comboCount,
		moves = moves,
		category = weapon.Category or "Weapon",
		-- Retain the existing sell UI with a stable value derived from actual
		-- maximum combo damage; this is not a randomized weapon stat.
		price = math.floor(maxDamage * 10 + 0.5),
		contrib = {damage = averageDamage},
	}
end

function Catalog.MakeItemRecord(definition, id, location)
	local weaponId = definition.weaponId
	local weapon = if Catalog.IsValidWeapon(weaponId) then Weapons.Data[weaponId] else nil
	return {
		id = id,
		n = if weapon then weapon.DisplayName or weaponId else definition.n,
		r = "common",
		slot = "weapon",
		tag = "Weapon",
		weaponId = weaponId,
		qty = 1,
		lvl = 1,
		loc = location or "bag",
		eqSlot = location == "eq" and "weapon" or nil,
	}
end

return Catalog
