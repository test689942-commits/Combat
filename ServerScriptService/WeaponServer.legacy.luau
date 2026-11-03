--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local Weapons = require(ReplicatedStorage.Modules.Weapons)

--// Variables \\--

local weaponAssets = ReplicatedStorage.Assets:WaitForChild("Weapons")

local EQUIPPED_NAME = "EquippedWeapon"
local JOINT_ATTRIBUTE = "WeaponJoint"
local EXCLUDED_PREFIXES = table.freeze({"WTB", "Holster"})
local ANCHOR_SIZE = Vector3.new(0.2, 0.2, 0.2)

--// Weapon Model \\--

local function detachWeapon(character: Model)
	local equippedModel = character:FindFirstChild(EQUIPPED_NAME)

	if equippedModel then
		equippedModel:Destroy()
	end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant:GetAttribute(JOINT_ATTRIBUTE) then
			descendant:Destroy()
		end
	end
end

local function findTemplate(modelName: string): Instance?
	local direct = weaponAssets:FindFirstChild(modelName)

	if direct then
		return direct
	end

	for _, folder in weaponAssets:GetChildren() do
		if folder:IsA("Folder") then
			local nested = folder:FindFirstChild(modelName)

			if nested then
				return nested
			end
		end
	end

	return nil
end

local function isExcluded(child: Instance): boolean
	for _, prefix in EXCLUDED_PREFIXES do
		if string.sub(child.Name, 1, #prefix) == prefix then
			return true
		end
	end

	return false
end

local function buildWeaponModel(template: Instance): Model
	local templateClone = template:Clone()
	local weaponModel = Instance.new("Model")
	weaponModel.Name = EQUIPPED_NAME

	for _, child in templateClone:GetChildren() do
		if not isExcluded(child) then
			child.Parent = weaponModel
		end
	end

	templateClone:Destroy()

	return weaponModel
end

local function getGrips(info)
	if info.Grips then
		return info.Grips
	end

	return {
		{
			GripPart = info.GripPart;
			JointName = info.JointName;
			GripC0 = info.GripC0;
			GripC1 = info.GripC1;
			AnchorName = info.AnchorName;
		};
	}
end

local function getHandle(container: Instance, grip): BasePart?
	return container:FindFirstChild(grip.HandleName or "Handle")
end

local function createAnchor(weaponModel: Model, anchorName: string): BasePart
	local anchor = Instance.new("Part")
	anchor.Name = anchorName
	anchor.Size = ANCHOR_SIZE
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Massless = true
	anchor.Anchored = false
	anchor:SetAttribute("NormalTransparency", 1)
	anchor.Parent = weaponModel

	return anchor
end

local function createJoint(character: Model, weaponModel: Model, handle: BasePart, grip)
	local gripPart = character:FindFirstChild(grip.GripPart)

	if grip.AnchorName then
		local anchor = createAnchor(weaponModel, grip.AnchorName)

		local anchorJoint = Instance.new("Motor6D")
		anchorJoint.Name = grip.AnchorName
		anchorJoint.Part0 = gripPart
		anchorJoint.Part1 = anchor
		anchorJoint.C0 = grip.GripC0
		anchorJoint:SetAttribute(JOINT_ATTRIBUTE, true)
		anchorJoint.Parent = gripPart

		local handleJoint = Instance.new("Motor6D")
		handleJoint.Name = grip.JointName
		handleJoint.Part0 = anchor
		handleJoint.Part1 = handle
		handleJoint.C1 = grip.GripC1
		handleJoint:SetAttribute(JOINT_ATTRIBUTE, true)
		handleJoint.Parent = anchor
	else
		local joint = Instance.new("Motor6D")
		joint.Name = grip.JointName
		joint.Part0 = gripPart
		joint.Part1 = handle
		joint.C0 = grip.GripC0
		joint.C1 = grip.GripC1
		joint:SetAttribute(JOINT_ATTRIBUTE, true)
		joint.Parent = gripPart
	end

	if grip.PartName then
		handle.Name = grip.PartName
	end
end

local function canAttach(character: Model, template: Instance, grips): boolean
	for _, grip in grips do
		if not character:FindFirstChild(grip.GripPart) or not getHandle(template, grip) then
			return false
		end
	end

	return true
end

-- CFrame.Angles are XYZ Euler rotations in radians, converted from the requested degree orientations.
local HOLSTER_OFFSETS = table.freeze({
	Back = CFrame.new(0.45, 0.1, 0.55) * CFrame.Angles(math.rad(55), math.rad(90), math.rad(180));
	LeftLeg = CFrame.new(-0.08, 0.05, 0.03) * CFrame.Angles(0, math.rad(-90), math.rad(-105));
	RightLeg = CFrame.new(0.08, 0.05, 0.03) * CFrame.Angles(0, math.rad(-90), math.rad(-105));
})

local HOLSTER_BODY_PARTS = table.freeze({
	Back = {"UpperTorso", "Torso"};
	LeftLeg = {"LeftUpperLeg", "Left Leg", "LeftLowerLeg"};
	RightLeg = {"RightUpperLeg", "Right Leg", "RightLowerLeg"};
})

local function findHolsterBodyPart(character: Model, slot: string): BasePart?
	for _, partName in HOLSTER_BODY_PARTS[slot] or {} do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function attachHolsteredWeapon(character: Model, weaponName: string)
	detachWeapon(character)

	local info = Weapons.Get(weaponName)
	if not info.Model then
		return
	end

	local template = findTemplate(info.Model)
	local grips = getGrips(info)
	if not template then
		warn("Holstered weapon model could not be found: " .. weaponName)
		return
	end

	local mounts = {}
	for index, grip in grips do
		local slot = if info.HolsterSlots then info.HolsterSlots[index] else info.HolsterSlot
		local offset = HOLSTER_OFFSETS[slot]
		local bodyPart = if offset then findHolsterBodyPart(character, slot) else nil
		local handle = getHandle(template, grip)
		if not offset or not bodyPart or not handle then
			warn("Weapon has no valid holster placement or handle: " .. weaponName)
			return
		end
		table.insert(mounts, {Slot = slot; Offset = offset; BodyPart = bodyPart; Grip = grip})
	end

	local weaponModel = buildWeaponModel(template)
	local mountedSlots = {}
	for _, mount in mounts do
		mount.Handle = getHandle(weaponModel, mount.Grip)
		if not mount.Handle then
			weaponModel:Destroy()
			warn("Holstered weapon handle was excluded from model: " .. weaponName)
			return
		end
		table.insert(mountedSlots, mount.Slot)
	end

	weaponModel:SetAttribute("HolsterSlot", table.concat(mountedSlots, ","))
	weaponModel.Parent = character
	for index, mount in mounts do
		local joint = Instance.new("Motor6D")
		joint.Name = "HolsterWeaponJoint" .. tostring(index)
		joint.Part0 = mount.BodyPart
		joint.Part1 = mount.Handle
		joint.C0 = info.HolsterC0 or mount.Offset
		joint:SetAttribute(JOINT_ATTRIBUTE, true)
		joint.Parent = mount.BodyPart
	end
end

local function attachWeapon(character: Model, weaponName: string)
	detachWeapon(character)

	local info = Weapons.Get(weaponName)

	if not info.Model then
		return
	end

	local template = findTemplate(info.Model)
	local grips = getGrips(info)

	if not template or not canAttach(character, template, grips) then
		warn("Weapon could not be attached: " .. weaponName)
		return
	end

	local weaponModel = buildWeaponModel(template)
	weaponModel.Parent = character

	for _, grip in grips do
		createJoint(character, weaponModel, getHandle(weaponModel, grip), grip)
	end
end

local function refreshWeapon(character: Model)
	local drawnWeaponName = Weapons.GetEquippedWeaponName(character)
	if drawnWeaponName then
		attachWeapon(character, drawnWeaponName)
		return
	end

	local selectedWeaponName = Weapons.GetSelectedWeaponName(character)
	if selectedWeaponName then
		attachHolsteredWeapon(character, selectedWeaponName)
	else
		detachWeapon(character)
	end
end

--// Characters \\--

local function setupCharacter(character: Model)
	character:GetAttributeChangedSignal(Weapons.EquippedAttributeName):Connect(function()
		refreshWeapon(character)
	end)
	character:GetAttributeChangedSignal(Weapons.SelectedAttributeName):Connect(function()
		refreshWeapon(character)
	end)

	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") then
			refreshWeapon(character)
		end
	end)

	character.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") then
			refreshWeapon(character)
		end
	end)

	refreshWeapon(character)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(setupCharacter)

	if player.Character then
		setupCharacter(player.Character)
	end
end

--// Events \\--

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
