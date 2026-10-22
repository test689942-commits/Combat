--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local MoveHit = require(script.Parent.Parent:WaitForChild("MoveHit"))

--// Variables \\--

local FistBarrage = {}

local effectsRemote = ReplicatedStorage.Remotes.Effects

--// Functions \\--

local function findTarget(character: Model, root: BasePart, settings)
	local boxCFrame = root.CFrame * CFrame.new(0, 0, -settings.HitboxOffset)

	return MoveHit.FindClosestTarget(character, root, boxCFrame, settings.HitboxSize)
end

local function playEffect(character: Model, root: BasePart, settings)
	effectsRemote:FireAllClients(settings.EntryName, {
		root = root,
		char = character,
		pulses = settings.HitCount,
		interval = settings.HitInterval,
		delay = settings.StartDelay,
	})
end

--// Move \\--

function FistBarrage.Activate(_player: Player, character: Model, settings, _aimPosition: Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return
	end

	playEffect(character, root, settings)

	task.wait(settings.StartDelay)

	local target = nil

	for hitIndex = 1, settings.HitCount do
		if not MoveHit.CanAct(character, humanoid, root) then
			break
		end

		if not MoveHit.IsTargetValid(target, root, settings.MaxTargetDistance) then
			target = findTarget(character, root, settings)
		end

		if target then
			MoveHit.ApplyDamage(character, target, settings.Damage, settings.StunTime)
		end

		if hitIndex < settings.HitCount then
			task.wait(settings.HitInterval)
		end
	end
end

return FistBarrage
