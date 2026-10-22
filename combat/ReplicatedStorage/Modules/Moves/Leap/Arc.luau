--// Variables \\--

local Arc = {}

local GROUND_RAY_HEIGHT = 50
local GROUND_RAY_DEPTH = 150
local ROOT_HEIGHT = 3
local MIN_AIM_DISTANCE = 0.1

--// Functions \\--

function Arc.CreateRayParams(ignoreList)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreList

	return rayParams
end

function Arc.GetTarget(rootCFrame: CFrame, aimPosition: Vector3?, maxRange: number, ignoreList): Vector3
	local origin = rootCFrame.Position
	local direction = Vector3.zero

	if aimPosition then
		direction = Vector3.new(aimPosition.X - origin.X, 0, aimPosition.Z - origin.Z)
	end

	if direction.Magnitude < MIN_AIM_DISTANCE then
		direction = Vector3.new(rootCFrame.LookVector.X, 0, rootCFrame.LookVector.Z)
	end

	local distance = math.min(direction.Magnitude, maxRange)
	local flatTarget = origin + direction.Unit * distance

	local rayOrigin = flatTarget + Vector3.new(0, GROUND_RAY_HEIGHT, 0)
	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -GROUND_RAY_DEPTH, 0), Arc.CreateRayParams(ignoreList))
	local height = origin.Y

	if result then
		height = result.Position.Y + ROOT_HEIGHT
	end

	return Vector3.new(flatTarget.X, height, flatTarget.Z)
end

function Arc.GetControl(origin: Vector3, target: Vector3, arcHeight: number): Vector3
	return (origin + target) / 2 + Vector3.new(0, arcHeight, 0)
end

function Arc.GetPoint(alpha: number, origin: Vector3, control: Vector3, target: Vector3): Vector3
	return (1 - alpha) ^ 2 * origin + 2 * (1 - alpha) * alpha * control + alpha ^ 2 * target
end

return Arc
