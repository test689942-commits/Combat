--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local HitDetection = require(ReplicatedStorage.Modules.Shared:WaitForChild("HitDetection"))
local MoveHit = require(script.Parent.Parent:WaitForChild("MoveHit"))

--// Variables \\--

local DaggerDance = {}

local effectsRemote = ReplicatedStorage.Remotes.Effects

local activeDances = setmetatable({}, {__mode = "k"})

--// Functions \\--

local function broadcastToOthers(caster: Player, settings, effectData)
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= caster then
			effectsRemote:FireClient(otherPlayer, settings.EntryName, effectData)
		end
	end
end

local function getTargets(character: Model, root: BasePart, settings)
	local boxCFrame = root.CFrame * CFrame.new(0, 0, -settings.Range / 2)
	local boxSize = Vector3.new(settings.Width, settings.Height, settings.Range)
	local ignoreList = {workspace.Effects, workspace.Debris, character}
	local targets = {}

	for _, model in HitDetection.GetCharactersInBox(boxCFrame, boxSize, ignoreList, "MoveHit") do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local targetRoot = model:FindFirstChild("HumanoidRootPart")

		if humanoid and targetRoot and humanoid.Health > 0 then
			table.insert(targets, {Model = model, Humanoid = humanoid, Root = targetRoot})
		end
	end

	return targets
end

local function applySlashHit(character: Model, root: BasePart, settings)
	for _, target in getTargets(character, root, settings) do
		MoveHit.ApplyDamage(character, target, settings.SlashDamage, settings.SlashStun)
	end
end

local function applyFinisherHit(character: Model, root: BasePart, settings)
	local direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local unitDirection = if direction.Magnitude > 0.1 then direction.Unit else root.CFrame.LookVector

	for _, target in getTargets(character, root, settings) do
		MoveHit.ApplyDamage(character, target, settings.FinisherDamage, settings.FinisherStun)
		MoveHit.Knockback(target, unitDirection, settings.KnockbackForce, settings.KnockbackLift, 0.25)
	end
end

local function runSlashMoveTicks(character: Model, humanoid: Humanoid, root: BasePart, state, settings)
	while activeDances[character] == state and state.SlashMoveActive and not state.Ended do
		if not MoveHit.CanAct(character, humanoid, root) then
			break
		end

		for _, target in getTargets(character, root, settings) do
			MoveHit.ApplyDamage(character, target, settings.TickDamage, settings.TickStun)
		end

		task.wait(settings.TickInterval)
	end
end

--// Move \\--

function DaggerDance.Activate(_player: Player, character: Model, settings, _aimPosition: Vector3?)
	local state = {
		StartTime = os.clock(),
		SlashMoveActive = false,
		Ended = false,
	}

	activeDances[character] = state

	task.delay(settings.PhaseWindow, function()
		if activeDances[character] == state then
			state.Ended = true
			activeDances[character] = nil
		end
	end)
end

function DaggerDance.Phase(player: Player, character: Model, settings, phaseName: string)
	local state = activeDances[character]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not state or not humanoid or not root then
		return
	end

	if os.clock() - state.StartTime > settings.PhaseWindow then
		activeDances[character] = nil
		return
	end

	broadcastToOthers(player, settings, {
		phase = phaseName,
		char = character,
		root = root,
	})

	if phaseName == "Dagger Slash" then
		if MoveHit.CanAct(character, humanoid, root) then
			applySlashHit(character, root, settings)
		end
	elseif phaseName == "Slash Move" then
		if not state.SlashMoveActive then
			state.SlashMoveActive = true
			task.spawn(runSlashMoveTicks, character, humanoid, root, state, settings)
		end
	elseif phaseName == "End" then
		if not state.Ended then
			state.Ended = true
			state.SlashMoveActive = false

			if MoveHit.CanAct(character, humanoid, root) then
				applyFinisherHit(character, root, settings)
			end
		end

		activeDances[character] = nil
	end
end

return DaggerDance
