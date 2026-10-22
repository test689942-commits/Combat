--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local Info = require(script.Parent).DropKick
local MoveClient = require(script.Parent:WaitForChild("MoveClient"))
local Effects = require(script.Parent:WaitForChild("Effects"))

--// Variables \\--

local DropKick = {
	Effect = Effects.DropKick,
}

local MOVE_NAME = script.Name
local PHASES = {"Startup", "Swing"}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local activeRemote = remotes:WaitForChild("Active")
local phaseRemote = remotes:WaitForChild("MovePhase")

local cooldownEnd = 0
local active = false

--// Phases \\--

local function createPhaseReporter(character: Model, root: BasePart)
	local reported = {}

	return function(phase: string)
		if reported[phase] then
			return
		end

		reported[phase] = true

		Effects.DropKick({char = character, root = root, phase = phase})
		phaseRemote:FireServer(MOVE_NAME, phase)
	end
end

local function connectEvents(track: AnimationTrack, reportPhase)
	track.KeyframeReached:Connect(function(keyframeName: string)
		if table.find(PHASES, keyframeName) then
			reportPhase(keyframeName)
		end
	end)

	for _, phase in PHASES do
		track:GetMarkerReachedSignal(phase):Connect(function()
			reportPhase(phase)
		end)
	end

	task.delay(Info.SwingTimeout, reportPhase, "Swing")
end

local function scheduleFallbackPhases(reportPhase)
	task.delay(Info.StartupFallback, reportPhase, "Startup")
	task.delay(Info.SwingFallback, reportPhase, "Swing")
end

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
	local reportPhase = createPhaseReporter(character, root)

	MoveClient.FaceMouse(root)

	cooldownEnd = os.clock() + Info.Cooldown
	Client.Library.SetCooldown(character, MOVE_NAME, Info.Cooldown)
	activeRemote:FireServer(MOVE_NAME, MoveClient.GetAimPosition())

	local track = MoveClient.LoadTrack(humanoid, MOVE_NAME)

	if track then
		connectEvents(track, reportPhase)
		MoveClient.StartTrack(track, Info.LockDuration)
	else
		scheduleFallbackPhases(reportPhase)
	end

	task.wait(Info.LockDuration)

	MoveClient.UnlockMovement(MOVE_NAME, humanoid, lock)
	active = false
end

--// Public \\--

function DropKick.TryStart()
	if canStart() then
		task.spawn(run)
	end
end

function DropKick.Release()
end

function DropKick.Cancel()
end

return DropKick
