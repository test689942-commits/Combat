--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local MainHandler = require(ReplicatedStorage.Modules.Shared:WaitForChild("MainHandler"))
local HitDetection = require(ReplicatedStorage.Modules.Shared:WaitForChild("HitDetection"))
local MovesInfo = require(script.Parent)
local CombatServer = require(script.Parent:WaitForChild("Combat"):WaitForChild("Server"))

--// Variables \\--

local MoveHit = {}

local CombatInfo = MovesInfo.Combat
local handlerClient = ReplicatedStorage.Events.HandlerFireClient
local effectsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effects")

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

--// Parry & Skill Cancel \\--

local function resolveTargetModel(targetOrModel: any): Model?
	if typeof(targetOrModel) == "Instance" and targetOrModel:IsA("Model") then
		return targetOrModel
	end

	if type(targetOrModel) == "table" and typeof(targetOrModel.Model) == "Instance" then
		return targetOrModel.Model
	end

	return nil
end

function MoveHit.CanParryMove(moveOrSettings: any): boolean
	if moveOrSettings == nil then
		return true
	end

	local settings = if type(moveOrSettings) == "table"
		then moveOrSettings
		elseif type(moveOrSettings) == "string" then MovesInfo[moveOrSettings]
		else nil

	if not settings then
		return true
	end

	if settings.Parryable == false or settings.Unparryable == true or settings.CanParry == false then
		return false
	end

	return true
end

function MoveHit.IsParrying(targetOrModel: any): boolean
	local targetModel = resolveTargetModel(targetOrModel)

	if not targetModel then
		return false
	end

	local blocking = targetModel:FindFirstChild("Blocking")

	return blocking ~= nil and blocking:FindFirstChild("PB") ~= nil
end

function MoveHit.ClearMoveState(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		if child.Name == "DoingMove" or child.Name == "AirCombat" then
			child:Destroy()
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if root then
		local airHold = root:FindFirstChild("AirPosAttacker")

		if airHold then
			if airHold.Attachment0 then
				airHold.Attachment0:Destroy()
			end

			airHold:Destroy()
		end
	end
end

function MoveHit.ParrySkill(attacker: Model, defender: Model, moveName: string?)
	MoveHit.ClearMoveState(attacker)

	MainHandler.CreateTing("BoolValue", {Parent = attacker, Name = "Stun"}, CombatInfo.Block.ParryStun)
	defender:SetAttribute("LastParry", os.clock())

	handlerClient:FireAllClients(attacker, "Client_Framework", "Effect", attacker, moveName or 1, "Parry", 1, defender)
	effectsRemote:FireAllClients("CancelMove", {
		char = attacker,
		move = moveName,
	})
end

function MoveHit.TryParry(attacker: Model, targetOrModel: any, moveName: string?): boolean
	if not MoveHit.CanParryMove(moveName) then
		return false
	end

	local targetModel = resolveTargetModel(targetOrModel)

	if not targetModel or not MoveHit.IsParrying(targetModel) then
		return false
	end

	MoveHit.ParrySkill(attacker, targetModel, moveName)
	return true
end

function MoveHit.TryParryGroup(attacker: Model, targets: {any}, moveName: string?): boolean
	if not MoveHit.CanParryMove(moveName) then
		return false
	end

	for _, target in ipairs(targets) do
		if MoveHit.TryParry(attacker, target, moveName) then
			return true
		end
	end

	return false
end

--// Hits \\--

function MoveHit.ApplyDamage(character: Model, target, damage: number, stunTime: number, moveName: string?): boolean
	if MoveHit.TryParry(character, target, moveName) then
		return false
	end

	if target.Model:FindFirstChild("Blocking") then
		CombatServer.DestroyBlock(target.Model)
	end

	target.Humanoid:TakeDamage(damage)

	handlerClient:FireAllClients(character, "MainHandler", "DamageInd", target.Model, damage)

	MainHandler.CreateTing("BoolValue", {Parent = target.Model, Name = "Stun"}, stunTime)

	return true
end

function MoveHit.Knockback(target, direction: Vector3, force: number, lift: number, duration: number)
	local velocity = Instance.new("BodyVelocity")
	velocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
	velocity.Velocity = direction * force + Vector3.new(0, lift, 0)
	velocity.Parent = target.Root

	DebrisService:AddItem(velocity, duration)
end

return MoveHit
