--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local HitDetection = require(ReplicatedStorage.Modules.Shared:WaitForChild("HitDetection"))
local Weapons = require(ReplicatedStorage.Modules:WaitForChild("Weapons"))
local MoveHit = require(script.Parent.Parent:WaitForChild("MoveHit"))
local Arc = require(script.Parent:WaitForChild("Arc"))

--// Variables \\--

local Leap = {}

local effectsRemote = ReplicatedStorage.Remotes.Effects

--// Landing Hit \\--

local function getDamage(character: Model, settings): number
	local rage = Weapons.GetForCharacter(character).RageStats

	if rage and character:GetAttribute(rage.Attribute) == true then
		return settings.Damage * rage.DamageMultiplier
	end

	return settings.Damage
end

local function getTargets(character: Model, root: BasePart, settings)
	local ignoreList = {workspace.Effects, workspace.Debris, character}
	local nearby = HitDetection.GetCharactersInSphere(root.Position, settings.Radius + settings.VerticalReach, ignoreList, "MoveHit")
	local targets = {}

	for _, model in nearby do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local targetRoot = model:FindFirstChild("HumanoidRootPart")

		if humanoid and targetRoot and humanoid.Health > 0 then
			local offset = targetRoot.Position - root.Position
			local flatDistance = (offset * Vector3.new(1, 0, 1)).Magnitude

			if flatDistance <= settings.Radius and math.abs(offset.Y) <= settings.VerticalReach then
				table.insert(targets, {Model = model, Humanoid = humanoid, Root = targetRoot})
			end
		end
	end

	return targets
end

local function landingHit(character: Model, root: BasePart, settings)
	local damage = getDamage(character, settings)

	for _, target in getTargets(character, root, settings) do
		local away = (target.Root.Position - root.Position) * Vector3.new(1, 0, 1)
		local direction = if away.Magnitude > 0.1 then away.Unit else root.CFrame.LookVector

		MoveHit.ApplyDamage(character, target, damage, settings.StunTime)
		MoveHit.Knockback(target, direction, settings.KnockbackForce, settings.KnockbackLift, 0.25)
	end
end

--// Move \\--

function Leap.Activate(player: Player, character: Model, settings, aimPosition: Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return
	end

	local ignoreList = {character, workspace.Effects, workspace.Debris, workspace.NPCS}
	local target = Arc.GetTarget(root.CFrame, aimPosition, settings.MaxRange, ignoreList)

	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			effectsRemote:FireClient(otherPlayer, settings.EntryName, {
				root = root,
				char = character,
				target = target,
				duration = settings.LeapDuration,
			})
		end
	end

	task.wait(settings.LeapDuration)

	if MoveHit.CanAct(character, humanoid, root) then
		landingHit(character, root, settings)
	end
end

return Leap
