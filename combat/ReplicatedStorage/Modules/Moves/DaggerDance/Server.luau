--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local AnimationsModule = require(ReplicatedStorage.Modules:WaitForChild("Animations"))
local HitDetection = require(ReplicatedStorage.Modules:WaitForChild("HitDetection"))
local MoveHit = require(script.Parent:WaitForChild("MoveHit"))

--// Variables \\--

local DaggerDance = {}

local MOVE_NAME = "DaggerDance"
local DAGGER_SLASH_NAME = "Dagger Slash"
local SLASH_MOVE_NAME = "Slash Move"
local END_NAME = "End"

local TRACK_WAIT_TIMEOUT = 1

local MARKER_ALIASES = {
	["Dagger Slash"] = DAGGER_SLASH_NAME,
	["Dagger slash"] = DAGGER_SLASH_NAME,
	["dagger slash"] = DAGGER_SLASH_NAME,
	["DaggerSlash"] = DAGGER_SLASH_NAME,
	["Dagger_Slash"] = DAGGER_SLASH_NAME,
	["Slash Move"] = SLASH_MOVE_NAME,
	["Slash move"] = SLASH_MOVE_NAME,
	["slash move"] = SLASH_MOVE_NAME,
	["SlashMove"] = SLASH_MOVE_NAME,
	["Slash_Move"] = SLASH_MOVE_NAME,
	["End"] = END_NAME,
	["end"] = END_NAME,
	["END"] = END_NAME,
}

local GENERIC_MARKER_NAMES = {"Event", "Marker", "KeyframeMarker", "KeyEvent"}

local effectsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effects")
local activeDances = {}

--// Helpers \\--

local function normalizeKey(text: string): string
	return string.lower((string.gsub(text, "[%s_]+", "")))
end

local function normalizeEventName(rawName: any): string?
	if type(rawName) ~= "string" or rawName == "" then
		return nil
	end

	if MARKER_ALIASES[rawName] then
		return MARKER_ALIASES[rawName]
	end

	local key = normalizeKey(rawName)

	if key == "daggerslash" then
		return DAGGER_SLASH_NAME
	elseif key == "slashmove" then
		return SLASH_MOVE_NAME
	elseif key == "end" then
		return END_NAME
	end

	return nil
end

local function firePhaseEffect(sourcePlayer: Player?, entryName: string, payload)
	for _, recipient in ipairs(Players:GetPlayers()) do
		if recipient ~= sourcePlayer then
			effectsRemote:FireClient(recipient, entryName, payload)
		end
	end
end

local function getTargets(character: Model, root: BasePart, settings)
	local size = settings.HitboxSize or Vector3.new(settings.Width or 8, settings.Height or 8, settings.Range or 12)
	local offset = settings.HitboxOffset or -(settings.Range or 12) * 0.5

	return HitDetection.GetCharactersInBox(
		root.CFrame * CFrame.new(0, 0, offset),
		size,
		{workspace.Effects, workspace.Debris, character},
		settings.EntryName
	)
end

local function applyDamagePass(character: Model, root: BasePart, damage: number, stunDuration: number, hitLabel: string, settings)
	local targets = getTargets(character, root, settings)

	for _, enemy in ipairs(targets) do
		local enemyHumanoid, enemyRoot = MoveHit.GetEnemyParts(enemy)

		if enemyHumanoid and enemyRoot then
			MoveHit.ApplyDamage(character, enemy, enemyHumanoid, damage, stunDuration, hitLabel)
		end
	end
end

local function runPhase(player: Player?, character: Model, settings, rawPhaseName: any)
	local phaseName = normalizeEventName(rawPhaseName)

	if not phaseName then
		return
	end

	local state = activeDances[character]

	if not state then
		return
	end

	if os.clock() - state.StartTime > settings.PhaseWindow then
		state.Ended = true
		state.SlashMoveActive = false
		activeDances[character] = nil
		return
	end

	local humanoid, root = MoveHit.GetAliveParts(character)

	if not humanoid then
		if phaseName == END_NAME then
			state.Ended = true
			state.SlashMoveActive = false
			activeDances[character] = nil
			firePhaseEffect(player, settings.EntryName, {
				char = character,
				phase = END_NAME,
			})
		end
		return
	end

	if phaseName == DAGGER_SLASH_NAME then
		if state.SlashDone or state.Ended then
			return
		end

		state.SlashDone = true

		firePhaseEffect(player, settings.EntryName, {
			char = character,
			root = root,
			phase = DAGGER_SLASH_NAME,
		})

		applyDamagePass(
			character,
			root,
			settings.SlashDamage,
			settings.SlashStun,
			settings.EntryName .. "Slash",
			settings
		)
	elseif phaseName == SLASH_MOVE_NAME then
		if state.SlashMoveActive or state.Ended then
			return
		end

		state.SlashMoveActive = true

		firePhaseEffect(player, settings.EntryName, {
			char = character,
			root = root,
			phase = SLASH_MOVE_NAME,
		})

		task.spawn(function()
			while state.SlashMoveActive and not state.Ended and activeDances[character] == state do
				local currentHumanoid, currentRoot = MoveHit.GetAliveParts(character)

				if not currentHumanoid or os.clock() - state.StartTime > settings.PhaseWindow then
					break
				end

				applyDamagePass(
					character,
					currentRoot,
					settings.TickDamage,
					settings.TickStun,
					settings.EntryName .. "Move",
					settings
				)

				task.wait(settings.TickInterval)
			end
		end)
	elseif phaseName == END_NAME then
		if state.Ended then
			return
		end

		state.Ended = true
		state.SlashMoveActive = false

		if activeDances[character] == state then
			activeDances[character] = nil
		end

		firePhaseEffect(player, settings.EntryName, {
			char = character,
			root = root,
			phase = END_NAME,
		})
	end
end

local function isDaggerDanceTrack(track: AnimationTrack, targetAnimId: string?): boolean
	if track.Name == MOVE_NAME then
		return true
	end

	local anim = track.Animation
	if anim then
		if anim.Name == MOVE_NAME then
			return true
		end

		if targetAnimId and anim.AnimationId == targetAnimId then
			return true
		end

		if string.find(anim.AnimationId, "115648844139917", 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function bindServerTrack(player: Player, character: Model, settings, state, track: AnimationTrack)
	if state.BoundTrack == track then
		return
	end

	state.BoundTrack = track

	local connections = {}

	local function dispatch(rawName: any)
		if activeDances[character] ~= state then
			return
		end

		runPhase(player, character, settings, rawName)
	end

	table.insert(connections, track.KeyframeReached:Connect(function(keyframeName: string)
		dispatch(keyframeName)
	end))

	for aliasName in pairs(MARKER_ALIASES) do
		table.insert(connections, track:GetMarkerReachedSignal(aliasName):Connect(function(param)
			dispatch(aliasName)
			if param and param ~= "" then
				dispatch(param)
			end
		end))
	end

	for _, genericName in ipairs(GENERIC_MARKER_NAMES) do
		table.insert(connections, track:GetMarkerReachedSignal(genericName):Connect(function(param)
			dispatch(param)
		end))
	end

	table.insert(connections, track.Stopped:Once(function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		dispatch(END_NAME)
	end))
end

local function watchServerAnimator(player: Player, character: Model, humanoid: Humanoid, settings, state)
	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		return
	end

	local targetAnimId = AnimationsModule.GetAnimationId("Moves", MOVE_NAME)

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if isDaggerDanceTrack(track, targetAnimId) then
			bindServerTrack(player, character, settings, state, track)
			return
		end
	end

	local connection
	connection = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		if isDaggerDanceTrack(track, targetAnimId) then
			if connection then
				connection:Disconnect()
				connection = nil
			end

			bindServerTrack(player, character, settings, state, track)
		end
	end)

	task.delay(TRACK_WAIT_TIMEOUT, function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

--// Public \\--

function DaggerDance.Activate(player: Player, character: Model, settings, aimOrPhase: any)
	if type(aimOrPhase) == "string" then
		runPhase(player, character, settings, aimOrPhase)
		return
	end

	local previous = activeDances[character]
	if previous then
		previous.Ended = true
		previous.SlashMoveActive = false
	end

	local humanoid, root = MoveHit.GetAliveParts(character)

	if not humanoid then
		return
	end

	local state = {
		StartTime = os.clock(),
		SlashDone = false,
		SlashMoveActive = false,
		Ended = false,
		BoundTrack = nil,
	}

	activeDances[character] = state

	effectsRemote:FireAllClients(settings.EntryName, {
		char = character,
		root = root,
	})

	watchServerAnimator(player, character, humanoid, settings, state)

	task.delay(settings.PhaseWindow, function()
		if activeDances[character] == state and not state.Ended then
			runPhase(player, character, settings, END_NAME)
		end
	end)
end

function DaggerDance.Phase(player: Player, character: Model, settings, phaseName: string)
	if not activeDances[character] then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		activeDances[character] = {
			StartTime = os.clock(),
			SlashDone = false,
			SlashMoveActive = false,
			Ended = false,
			BoundTrack = nil,
		}
	end

	runPhase(player, character, settings, phaseName)
end

return DaggerDance
