--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local MainHandler = require(ReplicatedStorage.Modules.Shared:WaitForChild("MainHandler"))
local HitDetection = require(ReplicatedStorage.Modules.Shared:WaitForChild("HitDetection"))

--// Variables \\--

local MoveHit = {}

local handlerClient = ReplicatedStorage.Events.HandlerFireClient

--// Targets \\--

function MoveHit.FindClosestTarget(character: Model, root: BasePart, boxCFrame: CFrame, boxSize: Vector3)
	local characters = HitDetection.GetCharactersInBox(boxCFrame, boxSize, {workspace.Effects, workspace.Debris, character}, "MoveHit")
	local closestTarget = nil
	local closestDistance = math.huge

	for _, model in characters do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local targetRoot = model:FindFirstChild("HumanoidRootPart")

		if humanoid and targetRoot and humanoid.Health > 0 then
			local distance = (targetRoot.Position - root.Position).Magnitude

			if distance < closestDistance then
				closestDistance = distance
				closestTarget = {
					Model = model,
					Humanoid = humanoid,
					Root = targetRoot,
				}
			end
		end
	end

	return closestTarget
end

function MoveHit.IsTargetValid(target, root: BasePart, maxDistance: number): boolean
	if not target or not target.Model.Parent or target.Humanoid.Health <= 0 then
		return false
	end

	return (target.Root.Position - root.Position).Magnitude <= maxDistance
end

function MoveHit.CanAct(character: Model, humanoid: Humanoid, root: BasePart): boolean
	return root.Parent == character and humanoid.Health > 0 and not character:FindFirstChild("Stun")
end

--// Hits \\--

function MoveHit.ApplyDamage(character: Model, target, damage: number, stunTime: number)
	target.Humanoid:TakeDamage(damage)

	handlerClient:FireAllClients(character, "MainHandler", "DamageInd", target.Model, damage)

	MainHandler.CreateTing("BoolValue", {Parent = target.Model, Name = "Stun"}, stunTime)
end

function MoveHit.Knockback(target, direction: Vector3, force: number, lift: number, duration: number)
	local velocity = Instance.new("BodyVelocity")
	velocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
	velocity.Velocity = direction * force + Vector3.new(0, lift, 0)
	velocity.Parent = target.Root

	DebrisService:AddItem(velocity, duration)
end

return MoveHit
