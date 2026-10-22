--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")

--// Modules \\--

local MainHandler = require(ReplicatedStorage.Modules.Shared:WaitForChild("MainHandler"))
local HitDetection = require(ReplicatedStorage.Modules.Shared:WaitForChild("HitDetection"))
local CombatServer = require(ReplicatedStorage.Modules.Moves:WaitForChild("Combat"):WaitForChild("Server"))
local CombatInfo = require(ReplicatedStorage.Modules:WaitForChild("Moves")).Combat

--// Variables \\--

local GroundSlam = {}

local effectsRemote = ReplicatedStorage.Remotes.Effects
local handlerClient = ReplicatedStorage.Events.HandlerFireClient

--// Functions \\--

local function isInsideSlam(root: BasePart, targetRoot: BasePart, settings): boolean
	local offset = targetRoot.Position - root.Position
	local flatDistance = (offset * Vector3.new(1, 0, 1)).Magnitude

	return flatDistance <= settings.Radius and math.abs(offset.Y) <= settings.VerticalReach
end

local function getTargets(character: Model, root: BasePart, settings)
	local nearbyCharacters = HitDetection.GetCharactersInSphere(root.Position, settings.Radius + settings.VerticalReach, { workspace.Effects, workspace.Debris, character }, "GroundSlam")
	local targets = {}

	for _, model in nearbyCharacters do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local targetRoot = model:FindFirstChild("HumanoidRootPart")

		if humanoid and targetRoot and humanoid.Health > 0 and isInsideSlam(root, targetRoot, settings) then
			table.insert(targets, {
				Model = model,
				Humanoid = humanoid,
				Root = targetRoot,
			})
		end
	end

	return targets
end

local function applyKnockback(root: BasePart, target, settings)
	local away = (target.Root.Position - root.Position) * Vector3.new(1, 0, 1)
	local direction = if away.Magnitude > 0.1 then away.Unit else root.CFrame.LookVector

	local velocity = Instance.new("BodyVelocity")
	velocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
	velocity.Velocity = direction * settings.KnockbackForce + Vector3.new(0, settings.KnockbackLift, 0)
	velocity.Parent = target.Root

	DebrisService:AddItem(velocity, 0.25)
end

local function applyHit(character: Model, root: BasePart, target, settings)
	target.Humanoid:TakeDamage(settings.Damage)

	handlerClient:FireAllClients(character, "MainHandler", "DamageInd", target.Model, settings.Damage)

	MainHandler.CreateTing("BoolValue", { Parent = target.Model, Name = "Stun" }, settings.StunTime)

	applyKnockback(root, target, settings)
end

local function getAirborneTargets(character: Model, root: BasePart, settings)
	local airborneTargets = {}

	for _, target in getTargets(character, root, settings) do
		if target.Root:FindFirstChild("AirPos") then
			table.insert(airborneTargets, target)
		end
	end

	return airborneTargets
end

local function canLand(character: Model, humanoid: Humanoid, root: BasePart): boolean
	return root.Parent == character and humanoid.Health > 0 and not character:FindFirstChild("Stun")
end

local function dropFromAirCombat(character: Model, root: BasePart)
	if root.Parent ~= character then
		return
	end

	local airHold = root:FindFirstChild("AirPosAttacker")

	if airHold then
		if airHold.Attachment0 then
			airHold.Attachment0:Destroy()
		end

		airHold:Destroy()
	end

	for _, child in character:GetChildren() do
		if child.Name == "AirCombat" then
			child:Destroy()
		end
	end
end

--// Move \\--

function GroundSlam.Activate(_player: Player, character: Model, settings, _aimPosition: Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return
	end

	local inAirCombat = character:FindFirstChild("AirCombat") ~= nil
	local airborneTargets = if inAirCombat then getAirborneTargets(character, root, settings) else {}

	if inAirCombat and settings.DropFromAirCombat then
		task.delay(settings.AirDropDelay or 0, dropFromAirCombat, character, root)
	end

	if #airborneTargets > 0 then
		CombatServer.UpDown(character, CombatInfo.MaxCombo, CombatInfo.MaxCombo, true)

		for _, target in airborneTargets do
			if not target.Root:FindFirstChild("AirPos") then
				effectsRemote:FireAllClients(settings.EntryName, { root = target.Root, char = character })
			end
		end

		return
	end

	task.wait(settings.ImpactDelay)

	if not canLand(character, humanoid, root) then
		return
	end

	for _, target in getTargets(character, root, settings) do
		applyHit(character, root, target, settings)
	end

	effectsRemote:FireAllClients(settings.EntryName, { root = root, char = character })
end

return GroundSlam
