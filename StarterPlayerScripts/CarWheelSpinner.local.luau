--// Services \\--

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

--// Variables \\--

local CAR_TAG = "EmoteCar"
local WHEEL_RADIUS = 0.5
local MOVING_SPEED_THRESHOLD = 1.5 -- studs/sec of forward speed before smoke kicks in

local spinAngles = {}
local smokeEmitters = {}

--// Functions \\--

local function getSmokeEmitters(car)
	local emitters = smokeEmitters[car]

	if not emitters then
		emitters = {}

		for _, descendant in ipairs(car:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") and descendant.Name == "MovementSmoke" then
				table.insert(emitters, descendant)
			end
		end

		smokeEmitters[car] = emitters
	end

	return emitters
end

local function updateMovementSmoke(car, isMoving)
	for _, emitter in ipairs(getSmokeEmitters(car)) do
		if emitter.Enabled ~= isMoving then
			emitter.Enabled = isMoving
		end
	end
end

local function spinWheels(car, deltaTime)
	local body = car.PrimaryPart
	local spinFolder = car:FindFirstChild("SpinWelds")

	if not body or not spinFolder then
		return
	end

	local scale = car:GetAttribute("Scale") or 1
	local forwardSpeed = body.AssemblyLinearVelocity:Dot(body.CFrame.LookVector)
	local angle = (spinAngles[car] or 0) - forwardSpeed * deltaTime / (WHEEL_RADIUS * scale)

	spinAngles[car] = angle

	for _, weld in ipairs(spinFolder:GetChildren()) do
		local baseOffset = weld:GetAttribute("BaseC0")

		if baseOffset then
			weld.C0 = baseOffset * CFrame.Angles(angle, 0, 0)
		end
	end

	updateMovementSmoke(car, math.abs(forwardSpeed) > MOVING_SPEED_THRESHOLD)
end

local function onHeartbeat(deltaTime)
	for _, car in ipairs(CollectionService:GetTagged(CAR_TAG)) do
		spinWheels(car, deltaTime)
	end
end

local function onCarRemoved(car)
	spinAngles[car] = nil
	smokeEmitters[car] = nil
end

--// Events \\--

RunService.Heartbeat:Connect(onHeartbeat)
CollectionService:GetInstanceRemovedSignal(CAR_TAG):Connect(onCarRemoved)