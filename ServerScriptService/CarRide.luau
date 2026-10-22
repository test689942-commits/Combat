--// Services \\--

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Settings \\--

local CAR_TAG = "EmoteCar"

local WALK_SPEED_MULTIPLIER = 0.8
local SIT_HIP_DROP = 1.4
local LEG_HIDE_TIME = 0.35 -- how long the legs take to fade out/in

local MAX_WHEEL_ANGLE = math.rad(85)
local MAX_FRONT_WHEEL_YAW = math.rad(28)

local STEER_TIME = 0.2
local ENTER_TIME = 0.6
local ARM_TIME = 0.3
local EXIT_TIME = 0.45
local CAR_SPAWN_DROP = 1.6
local CAR_SCALE_MULTIPLIER = 0.65 -- shrinks the car relative to the player
local PLAYER_RIDE_SCALE = 0.6 -- shrinks the player while riding so they fit the car

local CAR_BODY_CENTER_Z = -0.6

local STEERING_WHEEL_RADIUS = 0.55
local GRIP_DEPTH = 0.12

local TEMPLATE_NAME = "EmoteCar"

local R6_SIT_HIP_DROP = 1.0

local R6_LEG_REFERENCE_SCALE = 0.6

local R6_LEG_POSES = {
	Left = {
		Position = Vector3.new(-0.3004, -0.4806, -0.5692),
		Rotation = CFrame.fromEulerAnglesXYZ(math.rad(51.144), math.rad(0.166), math.rad(-0.826)),
	},
	Right = {
		Position = Vector3.new(0.3000, -0.4958, -0.5909),
		Rotation = CFrame.fromEulerAnglesXYZ(math.rad(51.144), math.rad(0.166), math.rad(-2.524)),
	},
}

local R6_JOINT_LOCATIONS = {
	Root = { "HumanoidRootPart", "RootJoint" },
	LeftHip = { "Torso", "Left Hip" },
	RightHip = { "Torso", "Right Hip" },
	LeftShoulder = { "Torso", "Left Shoulder" },
	RightShoulder = { "Torso", "Right Shoulder" },
}

local R6_LEG_PART_NAMES = { "Left Leg", "Right Leg" }

local R15_LEG_PART_NAMES = {
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local R15_JOINT_LOCATIONS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	LeftHip = { "LeftUpperLeg", "LeftHip" },
	RightHip = { "RightUpperLeg", "RightHip" },
	LeftKnee = { "LeftLowerLeg", "LeftKnee" },
	RightKnee = { "RightLowerLeg", "RightKnee" },
	LeftAnkle = { "LeftFoot", "LeftAnkle" },
	RightAnkle = { "RightFoot", "RightAnkle" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder" },
	RightShoulder = { "RightUpperArm", "RightShoulder" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	LeftWrist = { "LeftHand", "LeftWrist" },
	RightWrist = { "RightHand", "RightWrist" },
}

--// Math Helpers \\--

local function rotationBetween(fromVector, toVector)
	local fromDirection = fromVector.Unit
	local toDirection = toVector.Unit
	local dot = math.clamp(fromDirection:Dot(toDirection), -1, 1)

	if dot > 0.99999 then
		return CFrame.new()
	end

	local axis = fromDirection:Cross(toDirection)

	if axis.Magnitude < 0.0001 then
		axis = Vector3.xAxis
	end

	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

local function solveElbow(shoulderPosition, targetPosition, upperLength, lowerLength, poleVector)
	local toTarget = targetPosition - shoulderPosition
	local direction = toTarget.Unit
	local minimumReach = math.abs(upperLength - lowerLength) + 0.01
	local maximumReach = upperLength + lowerLength - 0.01
	local distance = math.clamp(toTarget.Magnitude, minimumReach, maximumReach)

	local along = (upperLength ^ 2 - lowerLength ^ 2 + distance ^ 2) / (2 * distance)
	local height = math.sqrt(math.max(upperLength ^ 2 - along ^ 2, 0))

	local sideways = poleVector - direction * poleVector:Dot(direction)

	if sideways.Magnitude < 0.0001 then
		sideways = Vector3.yAxis
	end

	local elbowPosition = shoulderPosition + direction * along + sideways.Unit * height
	local wristPosition = shoulderPosition + direction * distance

	return elbowPosition, wristPosition
end

local function composePose(baseOffset, rotation)
	return CFrame.new(baseOffset.Position) * rotation * baseOffset.Rotation
end

local function solveArm(arm, targetPosition)
	local shoulderPosition = arm.ShoulderBase.Position

	if arm.Single then
		local aimRotation = rotationBetween(arm.TipVector, targetPosition - shoulderPosition)

		return composePose(arm.ShoulderBase, aimRotation), nil
	end

	local elbowPosition, wristPosition = solveElbow(
		shoulderPosition,
		targetPosition,
		arm.UpperVector.Magnitude,
		arm.LowerVector.Magnitude,
		arm.Pole
	)

	local upperRotation = rotationBetween(arm.UpperVector, elbowPosition - shoulderPosition)
	local lowerDirection = upperRotation:VectorToObjectSpace(wristPosition - elbowPosition)
	local elbowRotation = rotationBetween(arm.LowerVector, lowerDirection)

	return composePose(arm.ShoulderBase, upperRotation), composePose(arm.ElbowBase, elbowRotation)
end

--// Rig Helpers \\--

local function findJointInstance(character, partName, jointName)
	local part = character:FindFirstChild(partName)

	if not part then
		return nil
	end

	return part:FindFirstChild(jointName)
end

local function wrapJoint(instance)
	if instance:IsA("Motor6D") then
		return {
			Target = instance,
			Property = "C0",
			C0 = instance.C0,
			C1 = instance.C1,
		}
	end

	if instance:IsA("AnimationConstraint") and instance.Attachment0 and instance.Attachment1 then
		return {
			Target = instance.Attachment0,
			Property = "CFrame",
			C0 = instance.Attachment0.CFrame,
			C1 = instance.Attachment1.CFrame,
		}
	end

	return nil
end

local function setJointOffset(joint, value)
	joint.Target[joint.Property] = value
end

local function collectJoints(character, locations)
	local joints = {}

	for jointName, location in pairs(locations) do
		local instance = findJointInstance(character, location[1], location[2])
		local joint = instance and wrapJoint(instance)

		if not joint then
			return nil
		end

		joints[jointName] = joint
	end

	return joints
end

local function buildArm(joints, prefix)
	local shoulder = joints[prefix .. "Shoulder"]
	local elbow = joints[prefix .. "Elbow"]
	local wrist = joints[prefix .. "Wrist"]

	local side = 1

	if shoulder.C0.Position.X < 0 then
		side = -1
	end

	return {
		Side = side,
		Shoulder = shoulder,
		Elbow = elbow,
		ShoulderBase = shoulder.C0,
		ElbowBase = elbow.C0,
		UpperVector = elbow.C0.Position - shoulder.C1.Position,
		LowerVector = wrist.C0.Position - elbow.C1.Position,
		Pole = Vector3.new(side * 0.6, -1, 0.1).Unit,
	}
end

local function buildSingleArm(character, joints, prefix)
	local shoulder = joints[prefix .. "Shoulder"]
	local armPart = character:FindFirstChild(prefix .. " Arm")

	local side = 1

	if shoulder.C0.Position.X < 0 then
		side = -1
	end

	local handPoint = Vector3.new(0, -armPart.Size.Y * 0.4, 0)
	local rotationDifference = shoulder.C0.Rotation * shoulder.C1.Rotation:Inverse()

	return {
		Single = true,
		Side = side,
		Shoulder = shoulder,
		ShoulderBase = shoulder.C0,
		HandPoint = handPoint,
		TipVector = rotationDifference:VectorToWorldSpace(handPoint - shoulder.C1.Position),
	}
end

local function buildPosedLeg(joint, pose, scale)
	local scaleRatio = scale / R6_LEG_REFERENCE_SCALE
	local scaledPose = CFrame.new(pose.Position * scaleRatio) * pose.Rotation

	return {
		Joint = joint,
		BaseC0 = joint.C0,
		TargetC0 = scaledPose * joint.C1,
	}
end

--// Car Model \\--

local function getTemplate()
	local template = ReplicatedStorage:FindFirstChild(TEMPLATE_NAME)

	if not template or not template:IsA("Model") then
		warn("CarRide: ReplicatedStorage." .. TEMPLATE_NAME .. " model not found")
		return nil
	end

	if not template.PrimaryPart then
		warn("CarRide: " .. TEMPLATE_NAME .. " needs its Body set as the PrimaryPart")
		return nil
	end

	local pivot = template:FindFirstChild("SteeringPivot", true)

	if not pivot or not pivot:FindFirstChild("PivotWeld") then
		warn("CarRide: " .. TEMPLATE_NAME .. " needs a SteeringPivot part with a PivotWeld")
		return nil
	end

	return template
end

local function sanitizeParts(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
end

local function collectAttachedParts(model)
	local attached = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("JointInstance") and descendant.Part1 then
			attached[descendant.Part1] = true
		elseif descendant:IsA("WeldConstraint") then
			if descendant.Part0 then
				attached[descendant.Part0] = true
			end

			if descendant.Part1 then
				attached[descendant.Part1] = true
			end
		end
	end

	return attached
end

local function weldLooseParts(model)
	local body = model.PrimaryPart
	local attached = collectAttachedParts(model)

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= body and not attached[part] then
			local weld = Instance.new("Weld")
			weld.Name = "StaticWeld"
			weld.Part0 = body
			weld.Part1 = part
			weld.C0 = body.CFrame:ToObjectSpace(part.CFrame)
			weld.Parent = part
		end
	end
end

local function storeBaseOffsets(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Weld") and descendant.Name ~= "StaticWeld" then
			descendant:SetAttribute("BaseC0", descendant.C0)
		end
	end
end

local function prepareCar(scale)
	local template = getTemplate()

	if not template then
		return nil
	end

	local model = template:Clone()

	sanitizeParts(model)
	weldLooseParts(model)

	local totalScale = scale * CAR_SCALE_MULTIPLIER
	model:ScaleTo(model:GetScale() * totalScale)

	storeBaseOffsets(model)
	model:SetAttribute("Scale", totalScale)
	model.PrimaryPart:SetAttribute("BaseSize", model.PrimaryPart.Size)

	return model
end

local function measureBodyHeight(model)
	local body = model.PrimaryPart
	local boxCFrame, boxSize = model:GetBoundingBox()
	local boxInBody = body.CFrame:ToObjectSpace(boxCFrame)

	return boxSize.Y / 2 - boxInBody.Position.Y
end

local function collectKnuckleWelds(model)
	local knuckleWelds = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Weld") and string.match(descendant.Name, "SteerWeld$") then
			table.insert(knuckleWelds, descendant)
		end
	end

	return knuckleWelds
end

local function createSmokeEmitter()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MovementSmoke"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Rate = 40
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1.8),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Enabled = false
	return emitter
end

local function addMovementSmoke(model)
	for _, name in ipairs({ "RearLeftWheel", "RearRightWheel" }) do
		local wheel = model:FindFirstChild(name, true)

		if wheel and wheel:IsA("BasePart") then
			createSmokeEmitter().Parent = wheel
		end
	end
end

local function assembleCar(model, rootPart, spawnOffset, pivotInBody)
	local body = model.PrimaryPart
	local pivot = model:FindFirstChild("SteeringPivot", true)

	local bodyWeld = Instance.new("Weld")
	bodyWeld.Name = "BodyWeld"
	bodyWeld.Part0 = rootPart
	bodyWeld.Part1 = body
	bodyWeld.C0 = spawnOffset
	bodyWeld.Parent = body

	addMovementSmoke(model)
	CollectionService:AddTag(model, CAR_TAG)

	return {
		Model = model,
		Body = body,
		BodyWeld = bodyWeld,
		PivotWeld = pivot:FindFirstChild("PivotWeld"),
		PivotBase = pivotInBody,
		KnuckleWelds = collectKnuckleWelds(model),
	}
end

--// Ride Class \\--

local CarRide = {}
CarRide.__index = CarRide

function CarRide.new(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		return nil
	end

	local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6

	if not isR6 and humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end

	if isR6 and not (character:FindFirstChild("Left Arm") and character:FindFirstChild("Right Arm") and character:FindFirstChild("Left Leg")) then
		return nil
	end

	local originalScale = character:GetScale()
	character:ScaleTo(originalScale * PLAYER_RIDE_SCALE)

	local locations = isR6 and R6_JOINT_LOCATIONS or R15_JOINT_LOCATIONS
	local joints = collectJoints(character, locations)

	if not joints then
		character:ScaleTo(originalScale)
		return nil
	end

	local scale = character:GetScale()
	local carModel = prepareCar(originalScale)

	if not carModel then
		character:ScaleTo(originalScale)
		return nil
	end

	local self = setmetatable({}, CarRide)
	self.Character = character
	self.CarModel = carModel
	self.IsR6 = isR6
	self.Humanoid = humanoid
	self.RootPart = rootPart
	self.Joints = joints
	self.Scale = scale
	self.OriginalCharacterScale = originalScale
	self.LegParts = {}
	self.Legs = {}

	for _, name in ipairs(isR6 and R6_LEG_PART_NAMES or R15_LEG_PART_NAMES) do
		local part = character:FindFirstChild(name)

		if part then
			table.insert(self.LegParts, { Part = part, OriginalTransparency = part.Transparency })
		end
	end

	self.State = "Idle"
	self.Destroyed = false
	self.DesiredSteer = 0
	self.Connections = {}
	self.Tweens = {}
	self.SteerValue = Instance.new("NumberValue")
	self.BlendValue = Instance.new("NumberValue")
	self.LegBlendValue = Instance.new("NumberValue")

	self:captureOriginals()
	self:computeGeometry()

	return self
end

function CarRide:captureOriginals()
	self.Original = {
		WalkSpeed = self.Humanoid.WalkSpeed,
		JumpPower = self.Humanoid.JumpPower,
		JumpHeight = self.Humanoid.JumpHeight,
		HipHeight = self.Humanoid.HipHeight,
	}

	self.BaseC0 = {}

	for _, motor in pairs(self.Joints) do
		self.BaseC0[motor] = motor.C0
	end
end

function CarRide:computeR15Geometry()
	local joints = self.Joints

	self.TorsoInRoot = joints.Root.C0 * joints.Root.C1:Inverse() * joints.Waist.C0 * joints.Waist.C1:Inverse()
	self.Arms = { buildArm(joints, "Left"), buildArm(joints, "Right") }

	self.StandHeight = self.Original.HipHeight
	self.SitHipHeight = math.max(self.Original.HipHeight - SIT_HIP_DROP * self.Scale, 0.1)
end

function CarRide:computeR6Geometry()
	local joints = self.Joints

	self.TorsoInRoot = joints.Root.C0 * joints.Root.C1:Inverse()
	self.Arms = {
		buildSingleArm(self.Character, joints, "Left"),
		buildSingleArm(self.Character, joints, "Right"),
	}

	self.Legs = {
		buildPosedLeg(joints.LeftHip, R6_LEG_POSES.Left, self.Scale),
		buildPosedLeg(joints.RightHip, R6_LEG_POSES.Right, self.Scale),
	}

	local legHeight = self.Character:FindFirstChild("Left Leg").Size.Y

	self.StandHeight = self.Original.HipHeight + legHeight
	self.SitHipHeight = self.Original.HipHeight - R6_SIT_HIP_DROP * self.Scale
end

function CarRide:computeGeometry()
	if self.IsR6 then
		self:computeR6Geometry()
	else
		self:computeR15Geometry()
	end

	local sitStandHeight = self.StandHeight + (self.SitHipHeight - self.Original.HipHeight)
	local groundHeight = -(sitStandHeight + self.RootPart.Size.Y / 2)
	local bodyHeight = measureBodyHeight(self.CarModel)

	local body = self.CarModel.PrimaryPart
	local seatPoint = self.CarModel:FindFirstChild("SeatPoint", true)
	local bodyCenterZ = CAR_BODY_CENTER_Z * self.Scale

	if seatPoint then
		bodyCenterZ = -body.CFrame:ToObjectSpace(seatPoint.CFrame).Position.Z
	end

	self.BodyOffset = CFrame.new(0, groundHeight + bodyHeight, bodyCenterZ)

	local pivot = self.CarModel:FindFirstChild("SteeringPivot", true)
	local topMarker = self.CarModel:FindFirstChild("TopMarker", true)

	self.PivotInBody = body.CFrame:ToObjectSpace(pivot.CFrame)
	self.PivotInRoot = self.BodyOffset * self.PivotInBody

	if topMarker then
		self.GripRadius = (topMarker.Position - pivot.Position).Magnitude
	else
		self.GripRadius = STEERING_WHEEL_RADIUS * self.Scale
	end
end

function CarRide:play(instance, duration, goal, easingStyle, easingDirection)
	local info = TweenInfo.new(
		duration,
		easingStyle or Enum.EasingStyle.Quad,
		easingDirection or Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(instance, info, goal)
	table.insert(self.Tweens, tween)
	tween:Play()

	return tween
end

function CarRide:getGripPosition(arm)
	local wheelAngle = -self.SteerValue.Value * MAX_WHEEL_ANGLE
	local scale = self.Scale

	local gripInPivot = Vector3.new(arm.Side * self.GripRadius, 0, GRIP_DEPTH * scale)
	local pivotInRoot = self.PivotInRoot * CFrame.Angles(0, 0, wheelAngle)
	local gripInRoot = pivotInRoot:PointToWorldSpace(gripInPivot)

	return self.TorsoInRoot:PointToObjectSpace(gripInRoot)
end

function CarRide:updateArms()
	local blend = self.BlendValue.Value

	for _, arm in ipairs(self.Arms) do
		local shoulderGoal, elbowGoal = solveArm(arm, self:getGripPosition(arm))
		setJointOffset(arm.Shoulder, arm.ShoulderBase:Lerp(shoulderGoal, blend))

		if arm.Elbow then
			setJointOffset(arm.Elbow, arm.ElbowBase:Lerp(elbowGoal, blend))
		end
	end
end

function CarRide:updateLegs()
	local blend = self.LegBlendValue.Value

	for _, leg in ipairs(self.Legs) do
		setJointOffset(leg.Joint, leg.BaseC0:Lerp(leg.TargetC0, blend))
	end
end

function CarRide:hideLegs()
	if #self.Legs > 0 then
		return
	end

	for _, entry in ipairs(self.LegParts) do
		self:play(entry.Part, LEG_HIDE_TIME, { Transparency = 1 })
	end
end

function CarRide:showLegs()
	if #self.Legs > 0 then
		return
	end

	for _, entry in ipairs(self.LegParts) do
		self:play(entry.Part, LEG_HIDE_TIME, { Transparency = entry.OriginalTransparency })
	end
end

function CarRide:applySteering()
	local car = self.Car

	if not car then
		return
	end

	local steer = self.SteerValue.Value

	car.PivotWeld.C0 = car.PivotBase * CFrame.Angles(0, 0, -steer * MAX_WHEEL_ANGLE)

	for _, knuckleWeld in ipairs(car.KnuckleWelds) do
		local baseOffset = knuckleWeld:GetAttribute("BaseC0")
		knuckleWeld.C0 = baseOffset * CFrame.Angles(0, -steer * MAX_FRONT_WHEEL_YAW, 0)
	end

	self:updateArms()
end

function CarRide:tweenSteer(direction)
	if self.SteerTween then
		self.SteerTween:Cancel()
	end

	self.SteerTween = self:play(self.SteerValue, STEER_TIME, { Value = direction })
end

function CarRide:SetSteer(direction)
	self.DesiredSteer = math.clamp(direction, -1, 1)

	if self.State == "Riding" then
		self:tweenSteer(self.DesiredSteer)
	end
end

function CarRide:IsRiding()
	return self.State == "Riding"
end

function CarRide:createCar()
	local spawnOffset = CFrame.new(0, -CAR_SPAWN_DROP * self.Scale, 0) * self.BodyOffset

	self.Car = assembleCar(self.CarModel, self.RootPart, spawnOffset, self.PivotInBody)
	self.Car.Model.Parent = self.Character

	table.insert(self.Connections, self.SteerValue.Changed:Connect(function()
		self:applySteering()
	end))

	table.insert(self.Connections, self.BlendValue.Changed:Connect(function()
		self:updateArms()
	end))

	table.insert(self.Connections, self.LegBlendValue.Changed:Connect(function()
		self:updateLegs()
	end))
end

function CarRide:applyRideStats()
	self.Humanoid.WalkSpeed = self.Original.WalkSpeed * WALK_SPEED_MULTIPLIER
	self.Humanoid.JumpPower = 0
	self.Humanoid.JumpHeight = 0
end

function CarRide:restoreStats()
	self.Humanoid.WalkSpeed = self.Original.WalkSpeed
	self.Humanoid.JumpPower = self.Original.JumpPower
	self.Humanoid.JumpHeight = self.Original.JumpHeight
	self.Humanoid.HipHeight = self.Original.HipHeight
end

function CarRide:Start()
	if self.State ~= "Idle" then
		return
	end

	self.State = "Entering"

	task.wait(0.15)

	if self.Destroyed then
		return
	end

	self:applyRideStats()
	self:createCar()
	self:hideLegs()
	self:play(self.LegBlendValue, ENTER_TIME, { Value = 1 })

	self:play(self.Car.BodyWeld, ENTER_TIME, { C0 = self.BodyOffset }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	self:play(self.Humanoid, ENTER_TIME, { HipHeight = self.SitHipHeight })

	task.wait(ENTER_TIME)

	if self.Destroyed then
		return
	end

	self:play(self.BlendValue, ARM_TIME, { Value = 1 })

	task.wait(ARM_TIME)

	if self.Destroyed then
		return
	end

	self.State = "Riding"
	self:tweenSteer(self.DesiredSteer)
end

function CarRide:Stop()
	if self.State ~= "Riding" then
		return
	end

	self.State = "Exiting"
	self.DesiredSteer = 0

	self:tweenSteer(0)
	self:showLegs()
	self:play(self.BlendValue, ARM_TIME, { Value = 0 })
	self:play(self.LegBlendValue, ARM_TIME, { Value = 0 })

	task.wait(ARM_TIME)

	if self.Destroyed then
		return
	end

	local sunkOffset = CFrame.new(0, -CAR_SPAWN_DROP * self.Scale, 0) * self.BodyOffset

	self:play(self.Car.BodyWeld, EXIT_TIME, { C0 = sunkOffset }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	self:play(self.Humanoid, EXIT_TIME, { HipHeight = self.Original.HipHeight })

	task.wait(EXIT_TIME)

	if self.Destroyed then
		return
	end

	self.State = "Done"
end

function CarRide:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end

	for _, tween in ipairs(self.Tweens) do
		tween:Cancel()
	end

	self.Car = nil
	self.CarModel:Destroy()

	self.SteerValue:Destroy()
	self.BlendValue:Destroy()
	self.LegBlendValue:Destroy()

	if self.Character.Parent then
		for joint, baseOffset in pairs(self.BaseC0) do
			setJointOffset(joint, baseOffset)
		end

		self:restoreStats()
		self.Character:ScaleTo(self.OriginalCharacterScale)

		for _, entry in ipairs(self.LegParts) do
			entry.Part.Transparency = entry.OriginalTransparency
		end
	end
end

return CarRide