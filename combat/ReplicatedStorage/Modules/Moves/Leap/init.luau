--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local Weapons = require(ReplicatedStorage.Modules:WaitForChild("Weapons"))
local Info = require(script.Parent).Leap
local MoveClient = require(script.Parent:WaitForChild("MoveClient"))
local Arc = require(script:WaitForChild("Arc"))
local Effect = require(script:WaitForChild("Effect"))

--// Variables \\--

local Leap = {}

local MOVE_NAME = script.Name
local activeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Active")

local cooldownEnd = 0
local active = false

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

local function travel(root: BasePart, origin: Vector3, target: Vector3, rayParams: RaycastParams)
	local control = Arc.GetControl(origin, target, Info.ArcHeight)
	local elapsed = 0

	while elapsed < Info.LeapDuration do
		elapsed += RunService.Heartbeat:Wait()

		if not root.Parent then
			return
		end

		local alpha = math.clamp(elapsed / Info.LeapDuration, 0, 1)
		local nextPosition = Arc.GetPoint(alpha, origin, control, target)
		local blocked = workspace:Raycast(root.Position, nextPosition - root.Position, rayParams)

		if blocked then
			root.CFrame = CFrame.new(blocked.Position + blocked.Normal * 0.1) * root.CFrame.Rotation
			root.AssemblyLinearVelocity = Vector3.zero
			return
		end

		root.CFrame = CFrame.new(nextPosition) * root.CFrame.Rotation
		root.AssemblyLinearVelocity = Vector3.zero
	end

	root.CFrame = CFrame.new(target) * root.CFrame.Rotation
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
	local target = Arc.GetTarget(root.CFrame, aimPosition, Info.MaxRange, ignoreList)

	root.CFrame = CFrame.lookAt(origin, Vector3.new(target.X, origin.Y, target.Z))

	cooldownEnd = os.clock() + Info.Cooldown
	Client.Library.SetCooldown(character, MOVE_NAME, Info.Cooldown)
	activeRemote:FireServer(MOVE_NAME, aimPosition)

	local track = MoveClient.LoadTrack(humanoid, MOVE_NAME)

	if track then
		MoveClient.StartTrack(track, Info.LockDuration)
	end

	task.spawn(Effect, {
		root = root,
		char = character,
		target = target,
		duration = Info.LeapDuration,
	})

	travel(root, origin, target, Arc.CreateRayParams(ignoreList))

	task.wait(math.max(0, Info.LockDuration - Info.LeapDuration))

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
