--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local Weapons = require(ReplicatedStorage.Modules:WaitForChild("Weapons"))
local Info = require(script.Parent).Spin
local MoveClient = require(script.Parent:WaitForChild("MoveClient"))
local Effects = require(script.Parent:WaitForChild("Effects"))

--// Variables \\--

local Spin = {
	Effect = Effects.Spin,
}

local MOVE_NAME = script.Name

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local activeRemote = remotes:WaitForChild("Active")
local phaseRemote = remotes:WaitForChild("MovePhase")

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

	local track = MoveClient.LoadTrack(humanoid, MOVE_NAME)
	local duration = Info.LockDuration

	local function reportPhase(eventName: string)
		if eventName ~= "End" and MoveClient.IsInterrupted(character, humanoid) then
			return
		end

		phaseRemote:FireServer(MOVE_NAME, eventName)
	end

	if track then
		if track.Length > 0 then
			duration = track.Length
		end

		Effects.Spin({
			char = character,
			root = root,
			track = track,
			onEvent = reportPhase,
		})

		activeRemote:FireServer(MOVE_NAME, aimPosition)
		MoveClient.StartTrack(track, duration)
	else
		activeRemote:FireServer(MOVE_NAME, aimPosition)
	end

	MoveClient.WaitForMove(character, humanoid, duration, track)

	Effects.Spin({char = character, root = root, phase = "End"})
	reportPhase("End")

	MoveClient.UnlockMovement(MOVE_NAME, humanoid, lock)
	active = false
end

--// Public \\--

function Spin.TryStart()
	if canStart() then
		task.spawn(run)
	end
end

function Spin.Release()
end

function Spin.Cancel()
end

return Spin
