--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local Info = require(script.Parent).FistBarrage
local MoveClient = require(script.Parent:WaitForChild("MoveClient"))
local Effects = require(script.Parent:WaitForChild("Effects"))

--// Variables \\--

local FistBarrage = {
	Effect = Effects.FistBarrage,
}

local MOVE_NAME = script.Name
local activeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Active")

local cooldownEnd = 0
local active = false

--// Move Flow \\--

local function canStart(): boolean
	if active or os.clock() < cooldownEnd then
		return false
	end

	return MoveClient.CanStart()
end

local function run()
	local character, humanoid, root = MoveClient.GetCharacterParts()

	if not character then
		return
	end

	active = true

	local lock = MoveClient.LockMovement(MOVE_NAME, character, humanoid)

	MoveClient.FaceMouse(root)

	cooldownEnd = os.clock() + Info.Cooldown
	Client.Library.SetCooldown(character, MOVE_NAME, Info.Cooldown)
	activeRemote:FireServer(MOVE_NAME, MoveClient.GetAimPosition())

	local track = MoveClient.LoadTrack(humanoid, MOVE_NAME)

	if track then
		MoveClient.StartTrack(track, Info.LockDuration)
	end

	MoveClient.WaitForMove(character, humanoid, Info.LockDuration, track)

	MoveClient.UnlockMovement(MOVE_NAME, humanoid, lock)
	active = false
end

--// Public \\--

function FistBarrage.TryStart()
	if canStart() then
		task.spawn(run)
	end
end

function FistBarrage.Release()
end

function FistBarrage.Cancel()
end

return FistBarrage
