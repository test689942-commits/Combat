--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local MoveHit = require(script.Parent.Parent:WaitForChild("MoveHit"))

--// Variables \\--

local DaggerThrow = {}

local effectsRemote = ReplicatedStorage.Remotes.Effects

--// Flight \\--

local function getDirection(origin: Vector3, aimPosition: Vector3?, root: BasePart): Vector3
	local flatMask = Vector3.new(1, 0, 1)

	if aimPosition then
		local flatOffset = (aimPosition - origin) * flatMask

		if flatOffset.Magnitude > 1 then
			return flatOffset.Unit
		end
	end

	local flatLook = root.CFrame.LookVector * flatMask

	if flatLook.Magnitude > 0.1 then
		return flatLook.Unit
	end

	return root.CFrame.LookVector
end

local function castFlight(character: Model, origin: Vector3, direction: Vector3, settings)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character, workspace.Effects, workspace.Debris}

	local result = workspace:Spherecast(origin, settings.HitRadius, direction * settings.MaxDistance, rayParams)

	if not result then
		return settings.MaxDistance, nil
	end

	local distance = (result.Position - origin).Magnitude
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local targetRoot = model and model:FindFirstChild("HumanoidRootPart")

	if humanoid and targetRoot and humanoid.Health > 0 then
		return distance, {Model = model, Humanoid = humanoid, Root = targetRoot}
	end

	return distance, nil
end

--// Move \\--

function DaggerThrow.Activate(_player: Player, character: Model, settings, aimPosition: Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return
	end

	task.wait(settings.ThrowDelay)

	if not MoveHit.CanAct(character, humanoid, root) then
		return
	end

	local hand = character:FindFirstChild("Right Arm") or root
	local origin = hand.Position + root.CFrame.LookVector
	local direction = getDirection(origin, aimPosition, root)
	local distance, target = castFlight(character, origin, direction, settings)

	effectsRemote:FireAllClients(settings.EntryName, {
		char = character,
		origin = origin,
		direction = direction,
		distance = distance,
		speed = settings.Speed,
		hit = target ~= nil,
		hideTime = settings.LockDuration - settings.ThrowDelay,
	})

	if not target then
		return
	end

	task.wait(distance / settings.Speed)

	if target.Humanoid.Health > 0 then
		MoveHit.ApplyDamage(character, target, settings.Damage, settings.StunTime)
		MoveHit.Knockback(target, direction * Vector3.new(1, 0, 1), settings.KnockbackForce, settings.KnockbackLift, 0.25)
	end
end

return DaggerThrow
