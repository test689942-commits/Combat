--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local Weapons = require(ReplicatedStorage.Modules:WaitForChild("Weapons"))
local Info = require(script.Parent).DaggerDance
local MoveClient = require(script.Parent:WaitForChild("MoveClient"))
local Effect = require(script:WaitForChild("Effect"))

--// Variables \\--

local DaggerDance = {}

local MOVE_NAME = script.Name
local KEY_EVENTS = {"Dagger Slash", "Slash Move", "End"}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local activeRemote = remotes:WaitForChild("Active")
local phaseRemote = remotes:FindFirstChild("MovePhase")

local cooldownEnd = 0
local active = false

--// Key Events \\--

local function createEventReporter(character: Model, root: BasePart)
	local ended = false

	return function(eventName: string)
		if eventName == "End" then
			if ended then
				return
			end

			ended = true
		end

		Effect({char = character, root = root, phase = eventName})

		if phaseRemote then
			phaseRemote:FireServer(MOVE_NAME, eventName)
		end
	end
end

local function connectKeyEvents(track: AnimationTrack, reportEvent)
	local connections = {}

	table.insert(connections, track.KeyframeReached:Connect(function(keyframeName: string)
		if table.find(KEY_EVENTS, keyframeName) then
			reportEvent(keyframeName)
		end
	end))

	for _, eventName in ipairs(KEY_EVENTS) do
		table.insert(connections, track:GetMarkerReachedSignal(eventName):Connect(function()
			reportEvent(eventName)
		end))
	end

	return function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
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
	local reportEvent = createEventReporter(character, root)

	faceAim(root, aimPosition)

	cooldownEnd = os.clock() + Info.Cooldown
	Client.Library.SetCooldown(character, MOVE_NAME, Info.Cooldown)
	activeRemote:FireServer(MOVE_NAME, aimPosition)

	local track = MoveClient.LoadTrack(humanoid, MOVE_NAME)
	local duration = Info.LockDuration
	local disconnectEvents = nil

	if track then
		if track.Length > 0 then
			duration = track.Length
		end

		disconnectEvents = connectKeyEvents(track, reportEvent)
		MoveClient.StartTrack(track, duration)
	end

	task.wait(duration)

	if disconnectEvents then
		disconnectEvents()
	end

	reportEvent("End")
	MoveClient.UnlockMovement(MOVE_NAME, humanoid, lock)
	active = false
end

--// Public \\--

function DaggerDance.TryStart()
	if canStart() then
		task.spawn(run)
	end
end

function DaggerDance.Release()
end

function DaggerDance.Cancel()
end

return DaggerDance
