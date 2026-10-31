--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local Weapons = require(ReplicatedStorage.Modules:WaitForChild("Weapons"))
local Info = require(script.Parent).Leap
local MoveClient = require(script.Parent:WaitForChild("MoveClient"))
local Effects = require(script.Parent:WaitForChild("Effects"))

--// Variables \\--

local Leap = {
	Effect = Effects.Leap,
}

local MOVE_NAME = script.Name
local activeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Active")

local GROUND_RAY_HEIGHT = 50
local GROUND_RAY_DEPTH = 150
local ROOT_HEIGHT = 3
local MIN_AIM_DISTANCE = 0.1

local cooldownEnd = 0
local active = false

--// Arc Helpers \\--

local function createRayParams(ignoreList)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreList

	return rayParams
end

local function getTarget(rootCFrame: CFrame, aimPosition: Vector3?, maxRange: number, ignoreList): Vector3
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
	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -GROUND_RAY_DEPTH, 0), createRayParams(ignoreList))
	local height = origin.Y

	if result then
		height = result.Position.Y + ROOT_HEIGHT
	end

	return Vector3.new(flatTarget.X, height, flatTarget.Z)
end

local function getControl(origin: Vector3, target: Vector3, arcHeight: number): Vector3
	return (origin + target) / 2 + Vector3.new(0, arcHeight, 0)
end

local function getPoint(alpha: number, origin: Vector3, control: Vector3, target: Vector3): Vector3
	return (1 - alpha) ^ 2 * origin + 2 * (1 - alpha) * alpha * control + alpha ^ 2 * target
end

--// Move Flow \\--

local function hasRequiredTool(character: Model): boolean
	return Weapons.HasMove(character, MOVE_NAME)
end

local function canStart(): boolean
	if active or os.clock() < cooldownEnd then
		return false
	end

	local character = MoveClient.GetCharacterParts()

	if not character or not hasRequiredTool(character) then
		return false
	end

	return MoveClient.CanStart()
end

local function getIgnoreList(character: Model)
	return {character, workspace.Effects, workspace.Debris, workspace.NPCS}
end

local function travel(character: Model, humanoid: Humanoid, root: BasePart, origin: Vector3, target: Vector3, rayParams: RaycastParams): boolean
	local control = getControl(origin, target, Info.ArcHeight)
	local elapsed = 0

	while elapsed < Info.LeapDuration do
		elapsed += RunService.Heartbeat:Wait()

		if not root.Parent or MoveClient.IsInterrupted(character, humanoid) then
			if root.Parent then
				root.AssemblyLinearVelocity = Vector3.zero
			end
			return false
		end

		local alpha = math.clamp(elapsed / Info.LeapDuration, 0, 1)
		local nextPosition = getPoint(alpha, origin, control, target)
		local blocked = workspace:Raycast(root.Position, nextPosition - root.Position, rayParams)

		if blocked then
			root.CFrame = CFrame.new(blocked.Position + blocked.Normal * 0.1) * root.CFrame.Rotation
			root.AssemblyLinearVelocity = Vector3.zero
			return true
		end

		root.CFrame = CFrame.new(nextPosition) * root.CFrame.Rotation
		root.AssemblyLinearVelocity = Vector3.zero
	end

	root.CFrame = CFrame.new(target) * root.CFrame.Rotation
	return true
end

local function run()
	local character, humanoid, root = MoveClient.GetCharacterParts()

	if not character then
		return
	end

	active = true

	local lock = MoveClient.LockMovement(MOVE_NAME, character, humanoid)
	local aimPosition = MoveClient.GetAimPosition()
	local ignoreList = getIgnoreList(character)
	local origin = root.Position
	local target = getTarget(root.CFrame, aimPosition, Info.MaxRange, ignoreList)

	root.CFrame = CFrame.lookAt(origin, Vector3.new(target.X, origin.Y, target.Z))

	cooldownEnd = os.clock() + Info.Cooldown
	Client.Library.SetCooldown(character, MOVE_NAME, Info.Cooldown)
	activeRemote:FireServer(MOVE_NAME, aimPosition)

	local track = MoveClient.LoadTrack(humanoid, MOVE_NAME)

	if track then
		MoveClient.StartTrack(track, Info.LockDuration)
	end

	task.spawn(Effects.Leap, {
		root = root,
		char = character,
		target = target,
		duration = Info.LeapDuration,
	})

	if travel(character, humanoid, root, origin, target, createRayParams(ignoreList)) then
		MoveClient.WaitForMove(character, humanoid, math.max(0, Info.LockDuration - Info.LeapDuration), track)
	elseif track and track.IsPlaying then
		track:Stop(0.1)
	end

	MoveClient.UnlockMovement(MOVE_NAME, humanoid, lock)
	active = false
end

--// Public \\--

function Leap.TryStart()
	if canStart() then
		task.spawn(run)
	end
end

function Leap.Release()
end

function Leap.Cancel()
end

return Leap
