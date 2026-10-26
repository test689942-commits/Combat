--// DIRECTIONAL MOVEMENT (body-tilt during walk/sprint/strafe) \\--

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = require(script.Parent)

local DirectionalMovement = {}

local TILT_SIZE = 150
local TWEEN_TIME = 0.28
local IDLE_TIMEOUT = 2
local WALL_RAY_DISTANCE = 2

local DEFAULT_R6_JOINTS = {
	rootJointC0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	rightHipC0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	leftHipC0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	neckC0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
}

local function resolveReferenceData(character: Model)
	local container = ReplicatedStorage:FindFirstChild("DirectionalMovement")
	local referenceRig = container and container:FindFirstChild("ReferenceRig")

	if referenceRig then
		local refTorso = referenceRig:FindFirstChild("Torso")
		local refHRP = referenceRig:FindFirstChild("HumanoidRootPart")
		local refRoot = refHRP and refHRP:FindFirstChild("RootJoint")
		local refRightHip = refTorso and refTorso:FindFirstChild("Right Hip")
		local refLeftHip = refTorso and refTorso:FindFirstChild("Left Hip")
		local refNeck = refTorso and refTorso:FindFirstChild("Neck")

		if refRoot and refRightHip and refLeftHip and refNeck then
			return {
				rootJointC0 = refRoot.C0,
				rightHipC0 = refRightHip.C0,
				leftHipC0 = refLeftHip.C0,
				neckC0 = refNeck.C0,
			}
		end
	end

	local torso = character:FindFirstChild("Torso")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local root = hrp and hrp:FindFirstChild("RootJoint")
	local rightHip = torso and torso:FindFirstChild("Right Hip")
	local leftHip = torso and torso:FindFirstChild("Left Hip")
	local neck = torso and torso:FindFirstChild("Neck")

	return {
		rootJointC0 = (root and root.C0) or DEFAULT_R6_JOINTS.rootJointC0,
		rightHipC0 = (rightHip and rightHip.C0) or DEFAULT_R6_JOINTS.rightHipC0,
		leftHipC0 = (leftHip and leftHip.C0) or DEFAULT_R6_JOINTS.leftHipC0,
		neckC0 = (neck and neck.C0) or DEFAULT_R6_JOINTS.neckC0,
	}
end

function DirectionalMovement.Start(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?

	if not humanoid or not humanoidRootPart then
		return function() end
	end

	local referenceData = resolveReferenceData(character)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}

	local activeTweens = {}

	local function TweenC0(motor: Motor6D?, target: CFrame)
		if not motor or not motor.Parent then
			return
		end

		if activeTweens[motor] then
			pcall(function()
				activeTweens[motor]:Cancel()
			end)
		end

		local tween = TweenService:Create(motor, TweenInfo.new(TWEEN_TIME), {C0 = target})
		activeTweens[motor] = tween
		tween:Play()
	end

	local function IsInCombatState(): boolean
		if character:FindFirstChild("Stun")
			or character:FindFirstChild("DoingCombat")
			or character:FindFirstChild("DoingMove")
			or character:FindFirstChild("Blocking") then
			return true
		end

		if character:GetAttribute("Attacking")
			or character:GetAttribute("Stunned") then
			return true
		end

		if #Client.Actions > 0 or #Client.Stuns > 0 or Client.Dashing then
			return true
		end

		return false
	end

	local function GetMotors()
		local torso = character:FindFirstChild("Torso")
		local hrp = character:FindFirstChild("HumanoidRootPart")

		if not torso or not hrp then
			return nil
		end

		return {
			root = hrp:FindFirstChild("RootJoint") :: Motor6D?,
			rightHip = torso:FindFirstChild("Right Hip") :: Motor6D?,
			leftHip = torso:FindFirstChild("Left Hip") :: Motor6D?,
			neck = torso:FindFirstChild("Neck") :: Motor6D?,
		}
	end

	local function ResetToNeutral()
		local m = GetMotors()

		if not m then
			return
		end

		if m.root then TweenC0(m.root, referenceData.rootJointC0) end
		if m.rightHip then TweenC0(m.rightHip, referenceData.rightHipC0) end
		if m.leftHip then TweenC0(m.leftHip, referenceData.leftHipC0) end
		if m.neck then TweenC0(m.neck, referenceData.neckC0) end
	end

	local lastMovementTime = tick()

	local stepConn = RunService.Stepped:Connect(function()
		if not character.Parent then
			return
		end

		if not humanoid or humanoid.Health <= 0 then
			return
		end

		if not humanoidRootPart or not humanoidRootPart.Parent then
			return
		end

		if humanoid.MoveDirection == Vector3.zero and (tick() - lastMovementTime) > IDLE_TIMEOUT then
			return
		end

		if IsInCombatState() then
			ResetToNeutral()
			return
		end

		local motors = GetMotors()
		if not motors or not motors.root or not motors.rightHip or not motors.leftHip or not motors.neck then
			return
		end

		local wallHit = workspace:Raycast(
			humanoidRootPart.Position,
			humanoidRootPart.CFrame.LookVector * WALL_RAY_DISTANCE,
			rayParams
		)

		if wallHit then
			ResetToNeutral()
			return
		end

		lastMovementTime = tick()

		local velocity = humanoidRootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local angle1 = 0
		local angle2 = 0

		if velocity.Magnitude > 2 then
			local velUnit = velocity.Unit
			angle1 = humanoidRootPart.CFrame.LookVector:Dot(velUnit) / (1000 / TILT_SIZE)
			angle2 = humanoidRootPart.CFrame.RightVector:Dot(velUnit) / (1000 / TILT_SIZE)
		end

		TweenC0(
			motors.root,
			referenceData.rootJointC0 * CFrame.Angles(angle1 * 0.015, -angle2 * 0.5, -angle2 * 2)
		)
		TweenC0(
			motors.rightHip,
			referenceData.rightHipC0 * CFrame.Angles(0, -angle2 * 2, 0)
		)
		TweenC0(
			motors.leftHip,
			referenceData.leftHipC0 * CFrame.Angles(0, -angle2 * 2, 0)
		)
		TweenC0(
			motors.neck,
			referenceData.neckC0 * CFrame.Angles(0, 0, angle2)
		)
	end)

	local function cleanup()
		if stepConn then
			stepConn:Disconnect()
			stepConn = nil
		end
	end

	humanoid.Died:Once(cleanup)

	return cleanup
end

return DirectionalMovement
