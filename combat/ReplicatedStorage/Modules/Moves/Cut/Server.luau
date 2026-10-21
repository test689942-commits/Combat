--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local HitDetection = require(ReplicatedStorage.Modules.Shared:WaitForChild("HitDetection"))
local MoveHit = require(script.Parent.Parent:WaitForChild("MoveHit"))

--// Variables \\--

local Cut = {}

local effectsRemote = ReplicatedStorage.Remotes.Effects

--// Cut Hit \\--

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

local function tickHit(character: Model, root: BasePart, settings)
	for _, target in getTargets(character, root, settings) do
		MoveHit.ApplyDamage(character, target, settings.TickDamage, settings.TickStun)
	end
end

local function finisherHit(character: Model, root: BasePart, settings)
	local direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)

	for _, target in getTargets(character, root, settings) do
		MoveHit.ApplyDamage(character, target, settings.Damage, settings.StunTime)
		MoveHit.Knockback(target, direction.Unit, settings.KnockbackForce, settings.KnockbackLift, 0.25)
	end
end

local function runTicks(character: Model, humanoid: Humanoid, root: BasePart, settings): boolean
	local elapsed = 0

	while elapsed < settings.EffectDuration do
		if not MoveHit.CanAct(character, humanoid, root) then
			return false
		end

		tickHit(character, root, settings)

		task.wait(settings.TickInterval)
		elapsed += settings.TickInterval
	end

	return true
end

--// Move \\--

function Cut.Activate(player: Player, character: Model, settings, _aimPosition: Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return
	end

	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			effectsRemote:FireClient(otherPlayer, settings.EntryName, {
				root = root,
				char = character,
				delay = settings.HitDelay,
				start = settings.EffectStart,
				duration = settings.EffectDuration,
				distance = settings.EffectDistance,
			})
		end
	end

	task.wait(settings.EffectStart)

	if not runTicks(character, humanoid, root, settings) then
		return
	end

	task.wait(math.max(0, settings.HitDelay - settings.EffectStart - settings.EffectDuration))

	if MoveHit.CanAct(character, humanoid, root) then
		finisherHit(character, root, settings)
	end
end

return Cut
