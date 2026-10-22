--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local MoveHit = require(script.Parent.Parent:WaitForChild("MoveHit"))

--// Variables \\--

local DropKick = {}

local effectsRemote = ReplicatedStorage.Remotes.Effects

local activeKicks = setmetatable({}, {__mode = "k"})

--// Functions \\--

local function broadcastToOthers(caster: Player, settings, effectData)
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= caster then
			effectsRemote:FireClient(otherPlayer, settings.EntryName, effectData)
		end
	end
end

local function getLookDirection(root: BasePart): Vector3
	local flatLook = root.CFrame.LookVector * Vector3.new(1, 0, 1)

	if flatLook.Magnitude > 0.1 then
		return flatLook.Unit
	end

	return root.CFrame.LookVector
end

local function hitTarget(character: Model, root: BasePart, settings)
	local boxCFrame = root.CFrame * CFrame.new(0, 0, -settings.HitboxOffset)
	local target = MoveHit.FindClosestTarget(character, root, boxCFrame, settings.HitboxSize)

	if not target then
		return
	end

	MoveHit.ApplyDamage(character, target, settings.Damage, settings.StunTime)
	MoveHit.Knockback(target, getLookDirection(root), settings.KnockbackForce, settings.KnockbackLift, settings.KnockbackDuration)
end

local function handleStartup(caster: Player, character: Model, root: BasePart, state, settings)
	if state.Startup then
		return
	end

	state.Startup = true

	broadcastToOthers(caster, settings, {phase = "Startup", char = character, root = root})
end

local function handleSwing(caster: Player, character: Model, humanoid: Humanoid, root: BasePart, state, settings, elapsed: number)
	if state.Swung or elapsed < settings.MinSwingTime then
		return
	end

	state.Swung = true

	if not MoveHit.CanAct(character, humanoid, root) then
		return
	end

	hitTarget(character, root, settings)

	broadcastToOthers(caster, settings, {phase = "Swing", char = character, root = root})
end

--// Move \\--

function DropKick.Activate(_player: Player, character: Model, settings, _aimPosition: Vector3?)
	local state = {
		StartTime = os.clock(),
		Startup = false,
		Swung = false,
	}

	activeKicks[character] = state

	task.delay(settings.PhaseWindow, function()
		if activeKicks[character] == state then
			activeKicks[character] = nil
		end
	end)
end

function DropKick.Phase(player: Player, character: Model, settings, phaseName: string)
	local state = activeKicks[character]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not state or not humanoid or not root then
		return
	end

	local elapsed = os.clock() - state.StartTime

	if elapsed > settings.PhaseWindow then
		activeKicks[character] = nil
		return
	end

	if phaseName == "Startup" then
		handleStartup(player, character, root, state, settings)
	elseif phaseName == "Swing" then
		handleSwing(player, character, humanoid, root, state, settings, elapsed)
	end
end

return DropKick
