--// Modules \\--

local Registry = require(script:WaitForChild("Registry"))
local CategoryModules = script:WaitForChild("Categories")

--// Setup \\--

local Weapons = {}

Weapons.Default = "GreatSword"
Weapons.FistsName = "Fists"
Weapons.FistsCategory = "Fists"
Weapons.AttributeName = "Weapon"
Weapons.EquippedAttributeName = "EquippedWeaponId"
Weapons.Categories = {}
Weapons.Data = {}
Weapons.Order = {}

local DEFAULT_GRIP_PART = "Right Arm"
local DEFAULT_JOINT_NAME = "Handle"
local DEFAULT_GRIP_C0 = CFrame.new(-0.230697632, -1.13454056, 0.00231933594)
local DEFAULT_GRIP_C1 = CFrame.new()
local HITBOX_HEIGHT = 6

--// Build \\--

for _, categoryModule in CategoryModules:GetChildren() do
	if categoryModule:IsA("ModuleScript") then
		Weapons.Categories[categoryModule.Name] = require(categoryModule)
	end
end

local function buildWeapon(name: string, entry)
	local category = Weapons.Categories[entry.Category]

	assert(category, "Unknown weapon category '" .. tostring(entry.Category) .. "' for " .. name)

	local data = {}

	for key, value in category do
		data[key] = value
	end

	for key, value in entry do
		data[key] = value
	end

	data.Name = name

	if entry.Range and not entry.Hitbox then
		data.Hitbox = table.freeze({
			Offset = entry.Range / 2;
			Size = Vector3.new(entry.Range, HITBOX_HEIGHT, entry.Range);
		})
	end

	if data.Model and not data.Grips and not data.GripPart then
		data.GripPart = DEFAULT_GRIP_PART
		data.JointName = DEFAULT_JOINT_NAME
		data.GripC0 = DEFAULT_GRIP_C0
		data.GripC1 = DEFAULT_GRIP_C1
	end

	return table.freeze(data)
end

for name, entry in Registry do
	Weapons.Data[name] = buildWeapon(name, entry)
	table.insert(Weapons.Order, name)
end

table.sort(Weapons.Order, function(first: string, second: string): boolean
	return (Weapons.Data[first].Order or 99) < (Weapons.Data[second].Order or 99)
end)

--// Lookup \\--

function Weapons.Get(weaponName: string?)
	return Weapons.Data[weaponName or Weapons.Default] or Weapons.Data[Weapons.Default]
end

function Weapons.GetEquippedTool(character: Model?): Tool?
	if not character then
		return nil
	end

	for _, child in character:GetChildren() do
		if child:IsA("Tool") and Weapons.Data[child:GetAttribute(Weapons.AttributeName)] then
			return child
		end
	end

	return nil
end

function Weapons.GetEquippedWeaponName(character: Model?): string?
	if not character then
		return nil
	end

	local weaponName = character:GetAttribute(Weapons.EquippedAttributeName)
	if Weapons.Data[weaponName] then
		return weaponName
	end

	-- Keep compatibility with legacy tools while inventory equips are attribute-based.
	local tool = Weapons.GetEquippedTool(character)
	local toolWeaponName = tool and tool:GetAttribute(Weapons.AttributeName)
	if Weapons.Data[toolWeaponName] then
		return toolWeaponName
	end

	return nil
end

function Weapons.HasEquippedWeapon(character: Model?): boolean
	return Weapons.GetEquippedWeaponName(character) ~= nil
end

function Weapons.GetName(character: Model?): string?
	-- Nothing equipped must resolve to nil, full stop -- Fists is now a normal
	-- catalog weapon you equip like any other, not an automatic fallback.
	return Weapons.GetEquippedWeaponName(character)
end

function Weapons.GetForCharacter(character: Model?)
	local name = Weapons.GetName(character)
	if name == nil then
		return nil
	end
	return Weapons.Data[name]
end

function Weapons.GetCategory(character: Model?): string?
	local weapon = Weapons.GetForCharacter(character)
	return weapon and weapon.Category
end

function Weapons.IsFists(character: Model?): boolean
	return Weapons.GetCategory(character) == Weapons.FistsCategory
end

function Weapons.DataHasMove(weapon, moveName: string): boolean
	if not weapon or not weapon.Moves then
		return false
	end

	return table.find(weapon.Moves, moveName) ~= nil
end

function Weapons.HasMove(character: Model?, moveName: string): boolean
	if not Weapons.HasEquippedWeapon(character) then
		return false
	end

	return Weapons.DataHasMove(Weapons.GetForCharacter(character), moveName)
end

local rageHits = setmetatable({}, {__mode = "k"})

local function buildRageHit(hit, rage)
	local cached = rageHits[hit]

	if cached then
		return cached
	end

	local speed = rage.SpeedMultiplier
	local scaled = table.clone(hit)

	scaled.Damage = hit.Damage * rage.DamageMultiplier
	scaled.Speed = hit.Speed * speed
	scaled.HitboxDelay = math.max(0.05, hit.HitboxDelay / speed)
	scaled.ImpactTime = hit.ImpactTime / speed
	scaled.ActionTime = hit.ActionTime / speed
	scaled.Cooldown = hit.Cooldown / speed
	scaled.SwingSoundTime = hit.SwingSoundTime / speed

	if hit.TrailStart then
		scaled.TrailStart = hit.TrailStart / speed
		scaled.TrailEnd = hit.TrailEnd / speed
	end

	rageHits[hit] = table.freeze(scaled)

	return rageHits[hit]
end

function Weapons.GetHit(info, count: number, character: Model?)
	local hit = info.Combo[math.clamp(count, 1, #info.Combo)]
	local rage = info.RageStats

	if character and rage and character:GetAttribute(rage.Attribute) == true then
		return buildRageHit(hit, rage)
	end

	return hit
end

return Weapons
