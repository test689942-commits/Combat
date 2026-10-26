-- R6-only ragdoll constraints for NPCs and dummies.
local Ragdoll = {}

local PHYSICS_STATE = Enum.HumanoidStateType.Physics
local GETTING_UP_STATE = Enum.HumanoidStateType.GettingUp
local RAGDOLLED_ATTRIBUTE = "Ragdolled"
local CONSTRAINT_NAME = "RagdollConstraint"
local ATTACHMENT_NAME = "RagdollAttachment"
local NO_COLLISION_NAME = "RagdollNoCollision"
local EXPECTED_R6_JOINTS = 6

local R6_PART_NAMES = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

local R6_JOINT_LIMITS = {
	RootJoint = {UpperAngle = 20, TwistLowerAngle = -20, TwistUpperAngle = 20},
	Neck = {UpperAngle = 35, TwistLowerAngle = -40, TwistUpperAngle = 40},
	["Left Shoulder"] = {UpperAngle = 100, TwistLowerAngle = -80, TwistUpperAngle = 80},
	["Right Shoulder"] = {UpperAngle = 100, TwistLowerAngle = -80, TwistUpperAngle = 80},
	["Left Hip"] = {UpperAngle = 55, TwistLowerAngle = -35, TwistUpperAngle = 35},
	["Right Hip"] = {UpperAngle = 55, TwistLowerAngle = -35, TwistUpperAngle = 35},
}

local NO_COLLISION_PAIRS = {
	{"Head", "Torso"},
	{"Head", "Left Arm"},
	{"Head", "Right Arm"},
	{"Head", "Left Leg"},
	{"Head", "Right Leg"},
	{"Torso", "Left Arm"},
	{"Torso", "Right Arm"},
	{"Left Arm", "Right Arm"},
	{"Torso", "Left Leg"},
	{"Torso", "Right Leg"},
	{"Left Arm", "Left Leg"},
	{"Left Arm", "Right Leg"},
	{"Right Arm", "Left Leg"},
	{"Right Arm", "Right Leg"},
	{"Left Leg", "Right Leg"},
}

local states = setmetatable({}, {__mode = "k"})
local durationTokens = setmetatable({}, {__mode = "k"})

local function getR6Parts(character: Model)
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")

	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6
		or not root or not root:IsA("BasePart")
		or not torso or not torso:IsA("BasePart")
		or not head or not head:IsA("BasePart") then
		return nil
	end

	for _, partName in ipairs(R6_PART_NAMES) do
		local part = character:FindFirstChild(partName)
		if not part or not part:IsA("BasePart") then
			return nil
		end
	end

	return humanoid, root, head
end

local function createConstraint(character: Model, motor: Motor6D, limits)
	if not motor.Part0 or not motor.Part1 then
		return nil
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = ATTACHMENT_NAME
	attachment0.CFrame = motor.C0
	attachment0.Parent = motor.Part0

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = ATTACHMENT_NAME
	attachment1.CFrame = motor.C1
	attachment1.Parent = motor.Part1

	local constraint = Instance.new("BallSocketConstraint")
	constraint.Name = CONSTRAINT_NAME
	constraint.Attachment0 = attachment0
	constraint.Attachment1 = attachment1
	constraint.LimitsEnabled = true
	constraint.UpperAngle = limits.UpperAngle
	constraint.TwistLimitsEnabled = true
	constraint.TwistLowerAngle = limits.TwistLowerAngle
	constraint.TwistUpperAngle = limits.TwistUpperAngle
	constraint.Parent = character

	return constraint, attachment0, attachment1
end

local function createNoCollisionConstraints(character: Model)
	local constraints = {}

	for _, pair in ipairs(NO_COLLISION_PAIRS) do
		local part0 = character:FindFirstChild(pair[1])
		local part1 = character:FindFirstChild(pair[2])

		if part0 and part0:IsA("BasePart") and part1 and part1:IsA("BasePart") then
			local constraint = Instance.new("NoCollisionConstraint")
			constraint.Name = NO_COLLISION_NAME
			constraint.Part0 = part0
			constraint.Part1 = part1
			constraint.Parent = character
			table.insert(constraints, constraint)
		end
	end

	return constraints
end

function Ragdoll.IsR6(character: Model): boolean
	return getR6Parts(character) ~= nil
end

function Ragdoll.CreateJoints(character: Model)
	if not Ragdoll.IsR6(character) then
		return nil
	end

	local state = states[character]
	if state then
		return state.motors
	end

	state = {
		motors = {},
		motorEnabled = {},
		constraints = {},
		attachments = {},
		noCollisionConstraints = {},
	}

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local limits = R6_JOINT_LIMITS[descendant.Name]
			if limits then
				local constraint, attachment0, attachment1 = createConstraint(character, descendant, limits)
				if constraint then
					table.insert(state.motors, descendant)
					state.motorEnabled[descendant] = descendant.Enabled
					table.insert(state.constraints, constraint)
					table.insert(state.attachments, attachment0)
					table.insert(state.attachments, attachment1)
				end
			end
		end
	end

	if #state.motors ~= EXPECTED_R6_JOINTS then
		for _, instance in ipairs(state.constraints) do
			instance:Destroy()
		end
		for _, instance in ipairs(state.attachments) do
			instance:Destroy()
		end
		return nil
	end

	state.noCollisionConstraints = createNoCollisionConstraints(character)
	states[character] = state
	return state.motors
end

function Ragdoll.DestroyJoints(character: Model)
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	local state = states[character]
	if state then
		for _, instance in ipairs(state.constraints) do
			if instance.Parent then instance:Destroy() end
		end
		for _, instance in ipairs(state.attachments) do
			if instance.Parent then instance:Destroy() end
		end
		for _, instance in ipairs(state.noCollisionConstraints) do
			if instance.Parent then instance:Destroy() end
		end
		state.constraints = {}
		state.attachments = {}
		state.noCollisionConstraints = {}
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant.Name == CONSTRAINT_NAME or descendant.Name == ATTACHMENT_NAME or descendant.Name == NO_COLLISION_NAME then
			descendant:Destroy()
		end
	end
end

function Ragdoll.Ragdoll(character: Model): boolean
	local humanoid, root = getR6Parts(character)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local state = states[character]
	if not state then
		Ragdoll.CreateJoints(character)
		state = states[character]
	end
	if not state then
		return false
	end
	if state.ragdolled then
		return true
	end

	state.ragdolled = true
	state.humanoid = {
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
		PlatformStand = humanoid.PlatformStand,
		RequiresNeck = humanoid.RequiresNeck,
		GettingUpEnabled = humanoid:GetStateEnabled(GETTING_UP_STATE),
	}
	state.rootCanCollide = root.CanCollide
	state.ragdolledAttribute = character:GetAttribute(RAGDOLLED_ATTRIBUTE)

	humanoid.RequiresNeck = false
	Ragdoll.SetMotorsEnabled(state.motors, false)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(GETTING_UP_STATE, false)
	root.CanCollide = false
	state.partCanCollide = {}
	for _, partName in ipairs(R6_PART_NAMES) do
		local part = character:FindFirstChild(partName)
		state.partCanCollide[part] = part.CanCollide
		part.CanCollide = true
	end
	character:SetAttribute(RAGDOLLED_ATTRIBUTE, true)
	humanoid:ChangeState(PHYSICS_STATE)

	return true
end

function Ragdoll.UnRagdoll(character: Model): boolean
	local state = states[character]
	if not state or not state.ragdolled then
		return false
	end

	local humanoid, root = getR6Parts(character)
	if humanoid and humanoid.Health > 0 then
		for motor, wasEnabled in pairs(state.motorEnabled) do
			if motor.Parent then motor.Enabled = wasEnabled end
		end
		Ragdoll.DestroyJoints(character)

		local saved = state.humanoid
		humanoid.RequiresNeck = saved.RequiresNeck
		humanoid.WalkSpeed = saved.WalkSpeed
		humanoid.JumpPower = saved.JumpPower
		humanoid.JumpHeight = saved.JumpHeight
		humanoid.AutoRotate = saved.AutoRotate
		humanoid.PlatformStand = saved.PlatformStand
		humanoid:SetStateEnabled(GETTING_UP_STATE, saved.GettingUpEnabled)
		root.CanCollide = state.rootCanCollide
		for part, canCollide in pairs(state.partCanCollide) do
			if part.Parent then part.CanCollide = canCollide end
		end
		character:SetAttribute(RAGDOLLED_ATTRIBUTE, state.ragdolledAttribute)
		humanoid:ChangeState(GETTING_UP_STATE)
	end

	states[character] = nil
	return true
end

function Ragdoll.SetMotorsEnabled(motors: {Motor6D}, enabled: boolean)
	for _, motor in ipairs(motors) do
		if motor.Parent then motor.Enabled = enabled end
	end
end

function Ragdoll.IsRagdolled(characterOrHumanoid: Instance): boolean
	if typeof(characterOrHumanoid) ~= "Instance" then
		return false
	end

	local character = if characterOrHumanoid:IsA("Humanoid") then characterOrHumanoid.Parent else characterOrHumanoid
	if not character or not character:IsA("Model") then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character:GetAttribute(RAGDOLLED_ATTRIBUTE) == true or (humanoid ~= nil and humanoid:GetState() == PHYSICS_STATE)
end

function Ragdoll.ForDuration(character: Model, duration: number): boolean
	if not Ragdoll.Ragdoll(character) then
		return false
	end

	local token = (durationTokens[character] or 0) + 1
	durationTokens[character] = token

	task.delay(math.max(duration, 0), function()
		if character.Parent and durationTokens[character] == token then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				Ragdoll.UnRagdoll(character)
			else
				states[character] = nil
			end
		end
	end)

	return true
end

function Ragdoll.RagdollDummy(character: Model, duration: number): boolean
	if not character or not character:IsA("Model") then
		return false
	end

	local npcs = workspace:FindFirstChild("NPCS")
	local isDummy = character:GetAttribute("Dummy") == true
	local isNpc = npcs ~= nil and character:IsDescendantOf(npcs)
	if not isDummy and not isNpc then
		return false
	end

	return Ragdoll.ForDuration(character, duration)
end

return Ragdoll
