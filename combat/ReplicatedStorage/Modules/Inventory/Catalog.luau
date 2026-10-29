-- Shared item data and deterministic display stats for the inventory.
-- Add future loot definitions here, then call InventoryService.AddItem from server loot code.

local Catalog = {}

Catalog.RarityOrder = {"common", "uncommon", "rare", "epic", "legend", "mythic"}
Catalog.SlotOrder = {"hat", "chest", "trinket", "wings", "relic", "ring", "weapon"}
Catalog.ValidSlots = {
	hat = true, chest = true, trinket = true, wings = true,
	relic = true, ring = true, weapon = true,
}

Catalog.StarterEquipped = {
	{slot = "hat", n = "Worn Fedora", r = "legend", tag = "Armor", lvl = 16},
	{slot = "chest", n = "Violet Robe", r = "epic", tag = "Armor", lvl = 20},
	{slot = "trinket", n = "Thorn Amulet", r = "epic", tag = "Trinket", lvl = 32},
	{slot = "weapon", n = "Void Blade", r = "mythic", tag = "Weapon", lvl = 28},
	{slot = "wings", n = "Rune Wraps", r = "epic", tag = "Armor", lvl = 27},
	{slot = "relic", n = "Gilded Relic", r = "legend", tag = "Relic", lvl = 27},
	{slot = "ring", n = "Azure Crown", r = "rare", tag = "Ring", lvl = 19},
}

Catalog.StarterBag = {
	{n = "Crimson Shard", r = "mythic", slot = "trinket", tag = "Crafting", q = 1},
	{n = "Ember Rune", r = "mythic", slot = "weapon", tag = "Rune", q = 1},
	{n = "Glacier Blade", r = "rare", slot = "weapon", tag = "Weapon", q = 1},
	{n = "Blood Star", r = "mythic", slot = "ring", tag = "Gem", q = 1},
	{n = "Void Prism", r = "epic", slot = "trinket", tag = "Gem", q = 7},
	{n = "Trolls Pouch", r = "legend", slot = "relic", tag = "Gold", q = 3},
	{n = "Gilded Nugget", r = "legend", slot = "relic", tag = "Gold", q = 1},
	{n = "Rune of Warding", r = "epic", slot = "weapon", tag = "Rune", q = 2},
	{n = "Ember Leaf", r = "legend", slot = "trinket", tag = "Material", q = 1},
	{n = "Obsidian Chunk", r = "common", slot = "ring", tag = "Material", q = 4},
	{n = "Sigil of Ruin", r = "mythic", slot = "relic", tag = "Sigil", q = 4},
	{n = "Verdant Orb", r = "uncommon", slot = "trinket", tag = "Orb", q = 13},
	{n = "Tome of Ash", r = "legend", slot = "weapon", tag = "Tome", q = 12},
	{n = "Amber Splinter", r = "legend", slot = "trinket", tag = "Material", q = 13},
	{n = "Pale Rune", r = "rare", slot = "weapon", tag = "Rune", q = 5},
	{n = "Nebula Prism", r = "epic", slot = "ring", tag = "Gem", q = 12},
	{n = "Iron Chest", r = "common", slot = "relic", tag = "Container", q = 2},
	{n = "Frost Cluster", r = "rare", slot = "weapon", tag = "Material", q = 1},
	{n = "Shard of Winter", r = "rare", slot = "trinket", tag = "Material", q = 24},
	{n = "Umbral Ingot", r = "common", slot = "relic", tag = "Material", q = 104},
	{n = "Ashen Hood", r = "epic", slot = "hat", tag = "Armor", q = 1},
	{n = "Bone Helm", r = "rare", slot = "hat", tag = "Armor", q = 1},
	{n = "Iron Plate", r = "rare", slot = "chest", tag = "Armor", q = 1},
	{n = "Obsidian Cuirass", r = "legend", slot = "chest", tag = "Armor", q = 1},
	{n = "Ember Cape", r = "legend", slot = "wings", tag = "Armor", q = 1},
	{n = "Frost Mantle", r = "rare", slot = "wings", tag = "Armor", q = 1},
	{n = "Sigil Band", r = "epic", slot = "ring", tag = "Ring", q = 1},
	{n = "Amber Beads", r = "uncommon", slot = "trinket", tag = "Trinket", q = 1},
}

local skillPool = {
	{n = "Lightning Arrows", d = "Attack deals 72% Lightning damage that chains up to 5 targets for the duration."},
	{n = "Piercing Arrows", d = "Fires a piercing arrow forward, dealing 405% Physical damage."},
	{n = "Arrow Volley", d = "Unleash a volley into the air, dealing 10 hits of 440% Physical damage to the target area."},
	{n = "Ember Strike", d = "Ignites the target, burning for 88% Fire damage over 6 seconds."},
	{n = "Frost Bind", d = "Freezes the target in place for 1.4 seconds and slows nearby foes."},
	{n = "Void Rend", d = "Tears a rift, dealing 260% Magic damage and reducing armor by 12%."},
	{n = "Blood Pact", d = "Sacrifices 6% health to increase damage by 35% for 8 seconds."},
}

local flavors = {
	"Crafted from natural materials.", "Forged in the deep furnace.",
	"It hums with old magic.", "Pried from the hands of the fallen.",
	"Cold to the touch, even in fire.", "The runes refuse to fade.",
	"Older than the dungeon itself.",
}

local rarityTier = {}
for index, rarity in ipairs(Catalog.RarityOrder) do
	rarityTier[rarity] = index
end

local function makeRng(seed)
	local state = (seed * 9301 + 49297) % 233280
	return function()
		state = (state * 9301 + 49297) % 233280
		return state / 233280
	end
end

local function rollStats(item, seed)
	local random = makeRng(seed + 7)
	local tier = rarityTier[item.r] or 1
	local stats = {
		atk = math.floor(16 + tier * 8 + random() * 24 + 0.5),
		pct = math.floor(18 + random() * 63 + 0.5),
		atkSpeed = math.floor((0.9 + random() * 0.8) * 10 + 0.5) / 10,
		score = math.floor(300 + tier * 380 + random() * 1400 + 0.5),
		lines = {},
		skills = {},
	}

	local function addLine(chance, color, makeText)
		if random() > chance then
			table.insert(stats.lines, {k = color, t = makeText()})
		end
	end
	addLine(0.40, "blue", function()
		return string.format("Attack deals an additional %d points of magical damage", math.floor(4 + random() * 16 + 0.5))
	end)
	addLine(0.32, "gray", function()
		return string.format("Physical damage increased by %d%%", math.floor(6 + random() * 24 + 0.5))
	end)
	addLine(0.42, "gray", function()
		return string.format("Magical damage increased by %d%%", math.floor(3 + random() * 9 + 0.5))
	end)
	addLine(0.38, "gray", function()
		return string.format("Strength +%d", math.floor(2 + random() * 9 + 0.5))
	end)
	addLine(0.38, "green", function()
		return string.format("Attack speed increased by %d%%", math.floor(2 + random() * 9 + 0.5))
	end)
	addLine(0.54, "green", function()
		return string.format("Critical strike chance +%d%%", math.floor(1 + random() * 7 + 0.5))
	end)

	if item.slot == "weapon" then
		local pool = table.clone(skillPool)
		local skillCount = 1 + math.floor(random() * 2)
		for _ = 1, skillCount do
			if #pool == 0 then break end
			local skill = table.remove(pool, math.floor(random() * #pool) + 1)
			table.insert(stats.skills, {
				n = skill.n,
				d = skill.d,
				lvl = math.max(1, (item.lvl or 20) + math.floor((random() - 0.5) * 6)),
			})
		end
	end

	stats.flavor = flavors[math.floor(random() * #flavors) + 1]
	stats.price = math.floor((60 + tier * 95 + random() * 420) / 5 + 0.5) * 5
	return stats
end

local baseScore = 0
for index, item in ipairs(Catalog.StarterEquipped) do
	local level = item.lvl or (14 + (index * 7) % 19)
	baseScore += rollStats({slot = item.slot, r = item.r, lvl = level}, index).score
end
if baseScore <= 0 then baseScore = 1 end

local weights = {
	damage = 252.3 / baseScore,
	speed = 111.9 / baseScore,
	crit = 0.00035,
	phys = 193.2 / baseScore,
	magic = 59 / baseScore,
}

function Catalog.IsValidSlot(slot)
	return Catalog.ValidSlots[slot] == true
end

function Catalog.GetStats(item)
	local stats = rollStats(item, item.id)
	local score = stats.score
	stats.contrib = {
		damage = score * weights.damage,
		speed = score * weights.speed,
		crit = math.max(0, (score - baseScore / 7) * weights.crit),
		phys = score * weights.phys,
		magic = score * weights.magic,
	}
	return stats
end

function Catalog.MakeItemRecord(definition, id, location)
	return {
		id = id,
		n = definition.n,
		r = definition.r,
		slot = definition.slot,
		tag = definition.tag or "Equipment",
		qty = math.max(1, math.floor(definition.q or 1)),
		lvl = math.max(1, math.floor(definition.lvl or (14 + (id * 7) % 19))),
		loc = location or "bag",
		eqSlot = location == "eq" and definition.slot or nil,
	}
end

return Catalog
