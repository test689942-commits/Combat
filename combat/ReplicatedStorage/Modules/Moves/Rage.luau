--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local Weapons = require(ReplicatedStorage.Modules:WaitForChild("Weapons"))
local Info = require(script.Parent).Rage
local MoveClient = require(script.Parent:WaitForChild("MoveClient"))
local Effects = require(script.Parent:WaitForChild("Effects"))

--// Variables \\--

local Rage = {
	Effect = Effects.Rage,
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

local function run()
	local character, humanoid = MoveClient.GetCharacterParts()

	if not character then
		return
	end

	active = true

	local lock = MoveClient.LockMovement(MOVE_NAME, character, humanoid)

	cooldownEnd = os.clock() + Info.Cooldown
	Client.Library.SetCooldown(character, MOVE_NAME, Info.Cooldown)
	activeRemote:FireServer(MOVE_NAME)

	local track = MoveClient.LoadTrack(humanoid, MOVE_NAME)

	if track then
		MoveClient.StartTrack(track, Info.LockDuration)
	end

	task.wait(Info.LockDuration)

	MoveClient.UnlockMovement(MOVE_NAME, humanoid, lock)
	active = false
end

--// Public \\--

function Rage.TryStart()
	if canStart() then
		task.spawn(run)
	end
end

function Rage.Release()
end

function Rage.Cancel()
end

return Rage
