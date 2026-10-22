--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local Weapons = require(ReplicatedStorage.Modules:WaitForChild("Weapons"))
local Info = require(script.Parent).Cut
local MoveClient = require(script.Parent:WaitForChild("MoveClient"))
local Effects = require(script.Parent:WaitForChild("Effects"))

--// Variables \\--

local Cut = {
	Effect = Effects.Cut,
}

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

local function faceAim(root: BasePart, aimPosition: Vector3?)
	if not aimPosition then
		return
	end

	local flatAim = Vector3.new(aimPosition.X, root.Position.Y, aimPosition.Z)

	if (flatAim - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flatAim)
	end
end

local function advance(root: BasePart)
	task.wait(Info.EffectStart)

	local direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)

	if direction.Magnitude < 0.1 then
		return
	end

	direction = direction.Unit

	local elapsed = 0

	while elapsed < Info.EffectDuration and root.Parent do
		elapsed += RunService.Heartbeat:Wait()

		local velocity = root.AssemblyLinearVelocity

		root.AssemblyLinearVelocity = Vector3.new(direction.X * Info.MoveSpeed, velocity.Y, direction.Z * Info.MoveSpeed)
	end

	if root.Parent then
		local velocity = root.AssemblyLinearVelocity

		root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
	end
end

local function run()
	local character, humanoid, root = MoveClient.GetCharacterParts()

	if not character then
		return
	end

	active = true

	local lock = MoveClient.LockMovement(MOVE_NAME, character, humanoid)
	local aimPosition = MoveClient.GetAimPosition()

	faceAim(root, aimPosition)

	cooldownEnd = os.clock() + Info.Cooldown
	Client.Library.SetCooldown(character, MOVE_NAME, Info.Cooldown)
	activeRemote:FireServer(MOVE_NAME, aimPosition)

	local track = MoveClient.LoadTrack(humanoid, MOVE_NAME)

	if track then
		track.Looped = false
		MoveClient.StartTrack(track, Info.LockDuration)
	end

	task.spawn(Effects.Cut, {
		root = root,
		char = character,
		delay = Info.HitDelay,
		start = Info.EffectStart,
		duration = Info.EffectDuration,
		distance = Info.EffectDistance,
	})

	task.spawn(advance, root)

	task.wait(Info.LockDuration)

	MoveClient.UnlockMovement(MOVE_NAME, humanoid, lock)
	active = false
end

--// Public \\--

function Cut.TryStart()
	if canStart() then
		task.spawn(run)
	end
end

function Cut.Release()
end

function Cut.Cancel()
end

return Cut
