--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AnimationsModule = require(Modules:WaitForChild("Animations"))
local Weapons = require(Modules:WaitForChild("Weapons"))
local MainHandler = require(Modules.Shared:WaitForChild("MainHandler"))
local HitDetection = require(Modules.Shared:WaitForChild("HitDetection"))
local CombatServer = require(script.Parent:WaitForChild("Combat"):WaitForChild("Server"))
local MovesInfo = require(script.Parent)
local MoveHit = require(script.Parent:WaitForChild("MoveHit"))

--// Variables \\--

local CombatInfo = MovesInfo.Combat
local effectsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effects")
local handlerClient = ReplicatedStorage:WaitForChild("Events"):WaitForChild("HandlerFireClient")
local effectsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects")

local Server = {}

--// Shared Helpers \\--

local function broadcastToOthers(caster: Player?, entryName: string, effectData)
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= caster then
			effectsRemote:FireClient(otherPlayer, entryName, effectData)
		end
	end
end

local function findEffectAsset(categoryName: string, effectName: string): Instance?
	local categoryFolder = effectsFolder:FindFirstChild(categoryName)

	if categoryFolder then
		local found = categoryFolder:FindFirstChild(effectName) or categoryFolder:FindFirstChild(effectName, true)

		if found then
			return found
		end
	end

	return effectsFolder:FindFirstChild(effectName) or effectsFolder:FindFirstChild(effectName, true)
end

--// Leap Arc Helper \\--

local Arc = {}
do
	local GROUND_RAY_HEIGHT = 50
	local GROUND_RAY_DEPTH = 150
	local ROOT_HEIGHT = 3
	local MIN_AIM_DISTANCE = 0.1

	function Arc.CreateRayParams(ignoreList)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = ignoreList

		return rayParams
	end

	function Arc.GetTarget(rootCFrame: CFrame, aimPosition: Vector3?, maxRange: number, ignoreList): Vector3
		local origin = rootCFrame.Position
		local direction = Vector3.zero

		if aimPosition then
			direction = Vector3.new(aimPosition.X - origin.X, 0, aimPosition.Z - origin.Z)
		end

		if direction.Magnitude < MIN_AIM_DISTANCE then
			direction = Vector3.new(rootCFrame.LookVector.X, 0, rootCFrame.LookVector.Z)
		end

		local distance = math.min(direction.Magnitude, maxRange)
		local flatTarget = origin + direction.Unit * distance

		local rayOrigin = flatTarget + Vector3.new(0, GROUND_RAY_HEIGHT, 0)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -GROUND_RAY_DEPTH, 0), Arc.CreateRayParams(ignoreList))
		local height = origin.Y

		if result then
			height = result.Position.Y + ROOT_HEIGHT
		end

		return Vector3.new(flatTarget.X, height, flatTarget.Z)
	end

	function Arc.GetControl(origin: Vector3, target: Vector3, arcHeight: number): Vector3
		return (origin + target) / 2 + Vector3.new(0, arcHeight, 0)
	end

	function Arc.GetPoint(alpha: number, origin: Vector3, control: Vector3, target: Vector3): Vector3
		return (1 - alpha) ^ 2 * origin + 2 * (1 - alpha) * alpha * control + alpha ^ 2 * target
	end
end

Server.Arc = Arc

--// 1. GroundSlam \\--

local GroundSlam = {}
do
	local function isInsideSlam(root: BasePart, targetRoot: BasePart, settings): boolean
		local offset = targetRoot.Position - root.Position
		local flatDistance = (offset * Vector3.new(1, 0, 1)).Magnitude

		return flatDistance <= settings.Radius and math.abs(offset.Y) <= settings.VerticalReach
	end

	local function getTargets(character: Model, root: BasePart, settings)
		local nearbyCharacters = HitDetection.GetCharactersInSphere(
			root.Position,
			settings.Radius + settings.VerticalReach,
			{workspace.Effects, workspace.Debris, character},
			"GroundSlam"
		)
		local targets = {}

		for _, model in ipairs(nearbyCharacters) do
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
		if target.Model:FindFirstChild("Blocking") then
			CombatServer.DestroyBlock(target.Model)
		end

		target.Humanoid:TakeDamage(settings.Damage)
		handlerClient:FireAllClients(character, "MainHandler", "DamageInd", target.Model, settings.Damage)
		MainHandler.CreateTing("BoolValue", {Parent = target.Model, Name = "Stun"}, settings.StunTime)
		applyKnockback(root, target, settings)
	end

	local function getAirborneTargets(character: Model, root: BasePart, settings)
		local airborneTargets = {}
		local liftHeight = CombatInfo.UpperCut and CombatInfo.UpperCut.LiftHeight or 0
		local searchRadius = settings.Radius + settings.VerticalReach + liftHeight
		local nearbyCharacters = HitDetection.GetCharactersInSphere(
			root.Position,
			searchRadius,
			{workspace.Effects, workspace.Debris, character},
			"GroundSlamAirTargets"
		)

		for _, model in ipairs(nearbyCharacters) do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")

			if humanoid and targetRoot and humanoid.Health > 0 and targetRoot:FindFirstChild("AirPos") then
				local offset = targetRoot.Position - root.Position
				local horizontalDistance = (offset * Vector3.new(1, 0, 1)).Magnitude

				if horizontalDistance <= settings.Radius then
					table.insert(airborneTargets, {
						Model = model,
						Humanoid = humanoid,
						Root = targetRoot,
					})
				end
			end
		end

		return airborneTargets
	end

	local function releaseAirHold(targetRoot: BasePart)
		local airHold = targetRoot:FindFirstChild("AirPos")

		if airHold then
			local attachment = airHold.Attachment0
			airHold:Destroy()

			if attachment and attachment.Parent then
				attachment:Destroy()
			end
		end
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

		for _, child in ipairs(character:GetChildren()) do
			if child.Name == "AirCombat" then
				child:Destroy()
			end
		end
	end

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
			if MoveHit.TryParryGroup(character, airborneTargets, settings.EntryName) then
				for _, target in ipairs(airborneTargets) do
					releaseAirHold(target.Root)
				end
				dropFromAirCombat(character, root)
				return
			end

			CombatServer.UpDown(character, CombatInfo.MaxCombo, CombatInfo.MaxCombo, true, airborneTargets)

			for _, target in ipairs(airborneTargets) do
				if target.Model.Parent and target.Humanoid.Health > 0 then
					-- If the normal down-slam path skipped a target (for example, a
					-- guarded dummy), release its hold so it cannot remain suspended.
					releaseAirHold(target.Root)
					effectsRemote:FireAllClients(settings.EntryName, {root = target.Root, char = character})
				end
			end

			return
		end

		task.wait(settings.ImpactDelay)

		if not canLand(character, humanoid, root) then
			return
		end

		local targets = getTargets(character, root, settings)

		if MoveHit.TryParryGroup(character, targets, settings.EntryName) then
			return
		end

		for _, target in ipairs(targets) do
			applyHit(character, root, target, settings)
		end

		effectsRemote:FireAllClients(settings.EntryName, {root = root, char = character})
	end
end
Server.GroundSlam = GroundSlam

--// 2. FistBarrage \\--

local FistBarrage = {}
do
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
				if not MoveHit.ApplyDamage(character, target, settings.Damage, settings.StunTime, settings.EntryName) then
					break
				end
			end

			if hitIndex < settings.HitCount then
				task.wait(settings.HitInterval)
			end
		end
	end
end
Server.FistBarrage = FistBarrage

--// 3. Rage \\--

local Rage = {}
do
	local activeAuras = setmetatable({}, {__mode = "k"})

	local function clearAura(character: Model)
		local pieces = activeAuras[character]

		if not pieces then
			return
		end

		for _, piece in ipairs(pieces) do
			piece:Destroy()
		end

		activeAuras[character] = nil
	end

	local function applyAura(character: Model)
		clearAura(character)

		local auraTemplate = findEffectAsset("Greatsword", "RageAura")

		if not auraTemplate then
			return
		end

		local pieces = {}

		for _, partFolder in ipairs(auraTemplate:GetChildren()) do
			local part = character:FindFirstChild(partFolder.Name)

			if part and part:IsA("BasePart") then
				local copy = partFolder:Clone()

				for _, child in ipairs(copy:GetChildren()) do
					child.Parent = part
					table.insert(pieces, child)
				end

				copy:Destroy()
			end
		end

		activeAuras[character] = pieces
	end

	local function stunNearby(character: Model, root: BasePart, settings): boolean
		local boxSize = Vector3.new(settings.Radius * 2, settings.VerticalReach * 2, settings.Radius * 2)
		local ignoreList = {workspace.Effects, workspace.Debris, character}
		local targets = HitDetection.GetCharactersInBox(root.CFrame, boxSize, ignoreList, "MoveHit")
		local validTargets = {}

		for _, target in ipairs(targets) do
			local humanoid = target:FindFirstChildOfClass("Humanoid")
			local targetRoot = target:FindFirstChild("HumanoidRootPart")

			if humanoid and targetRoot and humanoid.Health > 0 and (targetRoot.Position - root.Position).Magnitude <= settings.Radius then
				table.insert(validTargets, target)
			end
		end

		if MoveHit.TryParryGroup(character, validTargets, settings.EntryName) then
			return false
		end

		for _, target in ipairs(validTargets) do
			if target:FindFirstChild("Blocking") then
				CombatServer.DestroyBlock(target)
			end

			MainHandler.CreateTing("BoolValue", {Parent = target, Name = "Stun"}, settings.StunTime)
		end

		return true
	end

	function Rage.Activate(_player: Player, character: Model, settings, _aimPosition: Vector3?)
		local root = character:FindFirstChild("HumanoidRootPart")

		if not root then
			return
		end

		effectsRemote:FireAllClients(settings.EntryName, {
			root = root,
			char = character,
			delay = settings.EffectDelay,
		})

		task.wait(settings.EffectDelay)

		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if not humanoid or not MoveHit.CanAct(character, humanoid, root) then
			return
		end

		if not stunNearby(character, root, settings) then
			return
		end

		local token = (character:GetAttribute(settings.AttributeName .. "Token") or 0) + 1

		character:SetAttribute(settings.AttributeName .. "Token", token)
		character:SetAttribute(settings.AttributeName, true)
		applyAura(character)

		task.delay(settings.Duration, function()
			if character.Parent and character:GetAttribute(settings.AttributeName .. "Token") == token then
				character:SetAttribute(settings.AttributeName, nil)
				clearAura(character)
			end
		end)
	end
end
Server.Rage = Rage

--// 5. Leap \\--

local Leap = {}
do
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

		for _, model in ipairs(nearby) do
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
		local targets = getTargets(character, root, settings)

		if MoveHit.TryParryGroup(character, targets, settings.EntryName) then
			return
		end

		local damage = getDamage(character, settings)

		for _, target in ipairs(targets) do
			local away = (target.Root.Position - root.Position) * Vector3.new(1, 0, 1)
			local direction = if away.Magnitude > 0.1 then away.Unit else root.CFrame.LookVector

			if not MoveHit.ApplyDamage(character, target, damage, settings.StunTime, settings.EntryName) then
				return
			end

			MoveHit.Knockback(target, direction, settings.KnockbackForce, settings.KnockbackLift, 0.25)
		end
	end

	function Leap.Activate(player: Player, character: Model, settings, aimPosition: Vector3?)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root then
			return
		end

		local ignoreList = {character, workspace.Effects, workspace.Debris, workspace.NPCS}
		local target = Arc.GetTarget(root.CFrame, aimPosition, settings.MaxRange, ignoreList)

		broadcastToOthers(player, settings.EntryName, {
			root = root,
			char = character,
			target = target,
			duration = settings.LeapDuration,
		})

		task.wait(settings.LeapDuration)

		if MoveHit.CanAct(character, humanoid, root) then
			landingHit(character, root, settings)
		end
	end
end
Server.Leap = Leap

--// 6. Cut \\--

local Cut = {}
do
	local function getTargets(character: Model, root: BasePart, settings)
		local boxCFrame = root.CFrame * CFrame.new(0, 0, -settings.Range / 2)
		local boxSize = Vector3.new(settings.Width, settings.Height, settings.Range)
		local ignoreList = {workspace.Effects, workspace.Debris, character}
		local targets = {}

		for _, model in ipairs(HitDetection.GetCharactersInBox(boxCFrame, boxSize, ignoreList, "MoveHit")) do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")

			if humanoid and targetRoot and humanoid.Health > 0 then
				table.insert(targets, {Model = model, Humanoid = humanoid, Root = targetRoot})
			end
		end

		return targets
	end

	local function tickHit(character: Model, root: BasePart, settings): boolean
		local targets = getTargets(character, root, settings)

		if MoveHit.TryParryGroup(character, targets, settings.EntryName) then
			return false
		end

		for _, target in ipairs(targets) do
			if not MoveHit.ApplyDamage(character, target, settings.TickDamage, settings.TickStun, settings.EntryName) then
				return false
			end
		end

		return true
	end

	local function finisherHit(character: Model, root: BasePart, settings)
		local targets = getTargets(character, root, settings)

		if MoveHit.TryParryGroup(character, targets, settings.EntryName) then
			return
		end

		local direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)

		for _, target in ipairs(targets) do
			if not MoveHit.ApplyDamage(character, target, settings.Damage, settings.StunTime, settings.EntryName) then
				return
			end

			MoveHit.Knockback(target, direction.Unit, settings.KnockbackForce, settings.KnockbackLift, 0.25)
		end
	end

	local function runTicks(character: Model, humanoid: Humanoid, root: BasePart, settings): boolean
		local elapsed = 0

		while elapsed < settings.EffectDuration do
			if not MoveHit.CanAct(character, humanoid, root) then
				return false
			end

			if not tickHit(character, root, settings) then
				return false
			end

			task.wait(settings.TickInterval)
			elapsed += settings.TickInterval
		end

		return true
	end

	function Cut.Activate(player: Player, character: Model, settings, _aimPosition: Vector3?)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root then
			return
		end

		broadcastToOthers(player, settings.EntryName, {
			root = root,
			char = character,
			delay = settings.HitDelay,
			start = settings.EffectStart,
			duration = settings.EffectDuration,
			distance = settings.EffectDistance,
		})

		task.wait(settings.EffectStart)

		if not runTicks(character, humanoid, root, settings) then
			return
		end

		task.wait(math.max(0, settings.HitDelay - settings.EffectStart - settings.EffectDuration))

		if MoveHit.CanAct(character, humanoid, root) then
			finisherHit(character, root, settings)
		end
	end
end
Server.Cut = Cut

--// 7. DaggerThrow \\--

local DaggerThrow = {}
do
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
			if not MoveHit.ApplyDamage(character, target, settings.Damage, settings.StunTime, settings.EntryName) then
				return
			end

			MoveHit.Knockback(target, direction * Vector3.new(1, 0, 1), settings.KnockbackForce, settings.KnockbackLift, 0.25)
		end
	end
end
Server.DaggerThrow = DaggerThrow

--// 8. DaggerDance \\--

local DaggerDance = {}
do
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

	local activeDances = {}

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

	local function getTargets(character: Model, root: BasePart, settings)
		local size = settings.HitboxSize or Vector3.new(settings.Width or 8, settings.Height or 8, settings.Range or 12)
		local offset = settings.HitboxOffset or -(settings.Range or 12) * 0.5

		local models = HitDetection.GetCharactersInBox(
			root.CFrame * CFrame.new(0, 0, offset),
			size,
			{workspace.Effects, workspace.Debris, character},
			settings.EntryName
		)

		local targets = {}

		for _, model in ipairs(models) do
			local enemyHumanoid = model:FindFirstChildOfClass("Humanoid")
			local enemyRoot = model:FindFirstChild("HumanoidRootPart")

			if enemyHumanoid and enemyRoot and enemyHumanoid.Health > 0 then
				table.insert(targets, {Model = model, Humanoid = enemyHumanoid, Root = enemyRoot})
			end
		end

		return targets
	end

	local function applyDamagePass(character: Model, root: BasePart, damage: number, stunDuration: number, settings): boolean
		local targets = getTargets(character, root, settings)

		if MoveHit.TryParryGroup(character, targets, settings.EntryName) then
			return false
		end

		for _, target in ipairs(targets) do
			if not MoveHit.ApplyDamage(character, target, damage, stunDuration, settings.EntryName) then
				return false
			end
		end

		return true
	end

	local function getAliveParts(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root or humanoid.Health <= 0 then
			return nil, nil
		end

		return humanoid, root
	end

	local function cancelDance(player: Player?, character: Model, root: BasePart?, state, settings)
		state.Ended = true
		state.SlashMoveActive = false

		if activeDances[character] == state then
			activeDances[character] = nil
		end

		broadcastToOthers(player, settings.EntryName, {
			char = character,
			root = root,
			phase = END_NAME,
		})
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

		local humanoid, root = getAliveParts(character)

		if not humanoid or character:FindFirstChild("Stun") then
			if phaseName == END_NAME or character:FindFirstChild("Stun") then
				cancelDance(player, character, root, state, settings)
			end
			return
		end

		if phaseName == DAGGER_SLASH_NAME then
			if state.SlashDone or state.Ended then
				return
			end

			state.SlashDone = true

			if not applyDamagePass(
				character,
				root,
				settings.SlashDamage,
				settings.SlashStun,
				settings
			) then
				cancelDance(player, character, root, state, settings)
				return
			end

			broadcastToOthers(player, settings.EntryName, {
				char = character,
				root = root,
				phase = DAGGER_SLASH_NAME,
			})
		elseif phaseName == SLASH_MOVE_NAME then
			if state.SlashMoveActive or state.Ended then
				return
			end

			state.SlashMoveActive = true

			broadcastToOthers(player, settings.EntryName, {
				char = character,
				root = root,
				phase = SLASH_MOVE_NAME,
			})

			task.spawn(function()
				while state.SlashMoveActive and not state.Ended and activeDances[character] == state do
					local currentHumanoid, currentRoot = getAliveParts(character)

					if not currentHumanoid or character:FindFirstChild("Stun") or os.clock() - state.StartTime > settings.PhaseWindow then
						cancelDance(player, character, currentRoot, state, settings)
						break
					end

					if not applyDamagePass(
						character,
						currentRoot,
						settings.TickDamage,
						settings.TickStun,
						settings
					) then
						cancelDance(player, character, currentRoot, state, settings)
						break
					end

					task.wait(settings.TickInterval)
				end
			end)
		elseif phaseName == END_NAME then
			if state.Ended then
				return
			end

			cancelDance(player, character, root, state, settings)
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

			if string.find(anim.AnimationId, "115648844139917", 1, true) ~= nil
				or string.find(anim.AnimationId, "111287464837255", 1, true) ~= nil then
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

		local humanoid, root = getAliveParts(character)

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
end
Server.DaggerDance = DaggerDance

--// 8 & 9. Axe Moves: Thrust (yayy) & Spin (idk) \\--

do
	local TRACK_WAIT_TIMEOUT = 1
	local GENERIC_MARKER_NAMES = {"Event", "Marker", "KeyframeMarker", "KeyEvent"}

	local function normalizeKey(text: string): string
		return string.lower((string.gsub(text, "[%s_]+", "")))
	end

	local function getAliveParts(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root or humanoid.Health <= 0 then
			return nil, nil
		end

		return humanoid, root
	end

	local function getTargets(character: Model, root: BasePart, settings)
		local size = settings.HitboxSize or Vector3.new(settings.Width or 9, settings.Height or 8, settings.Range or 12)
		local offset = settings.HitboxOffset or -(settings.Range or 12) * 0.5

		local models = HitDetection.GetCharactersInBox(
			root.CFrame * CFrame.new(0, 0, offset),
			size,
			{workspace.Effects, workspace.Debris, character},
			settings.EntryName
		)

		local targets = {}

		for _, model in ipairs(models) do
			local enemyHumanoid = model:FindFirstChildOfClass("Humanoid")
			local enemyRoot = model:FindFirstChild("HumanoidRootPart")

			if enemyHumanoid and enemyRoot and enemyHumanoid.Health > 0 then
				table.insert(targets, {Model = model, Humanoid = enemyHumanoid, Root = enemyRoot})
			end
		end

		return targets
	end

	local function applyHitPass(character: Model, root: BasePart, damage: number, stunDuration: number, withKnockback: boolean, settings): boolean
		local targets = getTargets(character, root, settings)

		if MoveHit.TryParryGroup(character, targets, settings.EntryName) then
			return false
		end

		local lookDirection = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if lookDirection.Magnitude > 0.1 then
			lookDirection = lookDirection.Unit
		else
			lookDirection = root.CFrame.LookVector
		end

		for _, target in ipairs(targets) do
			if not MoveHit.ApplyDamage(character, target, damage, stunDuration, settings.EntryName) then
				return false
			end

			if withKnockback and settings.KnockbackForce then
				MoveHit.Knockback(target, lookDirection, settings.KnockbackForce, settings.KnockbackLift or 0, 0.25)
			end
		end

		return true
	end

	local function isMatchingTrack(track: AnimationTrack, moveName: string, targetAnimId: string?, fallbackDigits: string): boolean
		if track.Name == moveName then
			return true
		end

		local anim = track.Animation
		if anim then
			if anim.Name == moveName then
				return true
			end

			if targetAnimId and anim.AnimationId == targetAnimId then
				return true
			end

			if string.find(anim.AnimationId, fallbackDigits, 1, true) ~= nil then
				return true
			end
		end

		return false
	end

	local function watchAxeAnimator(
		activeTable,
		moveName: string,
		fallbackDigits: string,
		aliases: {[string]: string},
		hasEndPhase: boolean,
		runPhaseFn,
		player: Player,
		character: Model,
		humanoid: Humanoid,
		settings,
		state
	)
		local animator = humanoid:FindFirstChildOfClass("Animator")

		if not animator then
			return
		end

		local targetAnimId = AnimationsModule.GetAnimationId("Moves", moveName)

		local function bindTrack(track: AnimationTrack)
			if state.BoundTrack == track then
				return
			end

			state.BoundTrack = track

			local connections = {}

			local function dispatch(rawName: any)
				if activeTable[character] ~= state then
					return
				end

				runPhaseFn(player, character, settings, rawName)
			end

			table.insert(connections, track.KeyframeReached:Connect(function(keyframeName: string)
				dispatch(keyframeName)
			end))

			for aliasName in pairs(aliases) do
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

				if hasEndPhase then
					dispatch("End")
				end
			end))
		end

		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if isMatchingTrack(track, moveName, targetAnimId, fallbackDigits) then
				bindTrack(track)
				return
			end
		end

		local connection
		connection = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
			if isMatchingTrack(track, moveName, targetAnimId, fallbackDigits) then
				if connection then
					connection:Disconnect()
					connection = nil
				end

				bindTrack(track)
			end
		end)

		task.delay(TRACK_WAIT_TIMEOUT, function()
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end)
	end

	--// Move 1: Thrust (yayy) \\--

	local Thrust = {}
	do
		local MOVE_NAME = "Thrust"
		local FALLBACK_DIGITS = "86677978686885"

		local THRUST_ALIASES = {
			["Thrust"] = "Thrust",
			["thrust"] = "Thrust",
			["Slashup"] = "Slashup",
			["SlashUp"] = "Slashup",
			["slashup"] = "Slashup",
			["Slash_Up"] = "Slashup",
			["SlashLast"] = "SlashLast",
			["Slashlast"] = "SlashLast",
			["slashlast"] = "SlashLast",
			["Slash_Last"] = "SlashLast",
		}

		local activeThrusts = {}

		local function normalizeEvent(rawName: any): string?
			if type(rawName) ~= "string" or rawName == "" then
				return nil
			end

			if THRUST_ALIASES[rawName] then
				return THRUST_ALIASES[rawName]
			end

			local key = normalizeKey(rawName)

			if key == "thrust" then
				return "Thrust"
			elseif key == "slashup" then
				return "Slashup"
			elseif key == "slashlast" then
				return "SlashLast"
			end

			return nil
		end

		local function runPhase(player: Player?, character: Model, settings, rawPhaseName: any)
			local phaseName = normalizeEvent(rawPhaseName)

			if not phaseName then
				return
			end

			local state = activeThrusts[character]

			if not state or state.Ended then
				return
			end

			if os.clock() - state.StartTime > settings.PhaseWindow then
				state.Ended = true
				activeThrusts[character] = nil
				return
			end

			local humanoid, root = getAliveParts(character)

			if not humanoid or character:FindFirstChild("Stun") then
				state.Ended = true
				activeThrusts[character] = nil
				return
			end

			if state.DonePhases[phaseName] then
				return
			end

			state.DonePhases[phaseName] = true

			local damage = settings.ThrustDamage
			local stun = settings.ThrustStun
			local isFinisher = false

			if phaseName == "Slashup" then
				damage = settings.SlashupDamage
				stun = settings.SlashupStun
			elseif phaseName == "SlashLast" then
				damage = settings.SlashLastDamage
				stun = settings.SlashLastStun
				isFinisher = true
			end

			if not applyHitPass(character, root, damage, stun, isFinisher, settings) then
				state.Ended = true
				activeThrusts[character] = nil
				return
			end

			broadcastToOthers(player, settings.EntryName, {
				char = character,
				root = root,
				phase = phaseName,
			})

			if isFinisher then
				state.Ended = true
				if activeThrusts[character] == state then
					activeThrusts[character] = nil
				end
			end
		end

		function Thrust.Activate(player: Player, character: Model, settings, aimOrPhase: any)
			if type(aimOrPhase) == "string" then
				runPhase(player, character, settings, aimOrPhase)
				return
			end

			local previous = activeThrusts[character]
			if previous then
				previous.Ended = true
			end

			local humanoid, root = getAliveParts(character)

			if not humanoid then
				return
			end

			local state = {
				StartTime = os.clock(),
				DonePhases = {},
				Ended = false,
				BoundTrack = nil,
			}

			activeThrusts[character] = state

			effectsRemote:FireAllClients(settings.EntryName, {
				char = character,
				root = root,
			})

			watchAxeAnimator(
				activeThrusts,
				MOVE_NAME,
				FALLBACK_DIGITS,
				THRUST_ALIASES,
				false,
				runPhase,
				player,
				character,
				humanoid,
				settings,
				state
			)

			task.delay(settings.PhaseWindow, function()
				if activeThrusts[character] == state then
					state.Ended = true
					activeThrusts[character] = nil
				end
			end)
		end

		function Thrust.Phase(player: Player, character: Model, settings, phaseName: string)
			if not activeThrusts[character] then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then
					return
				end

				activeThrusts[character] = {
					StartTime = os.clock(),
					DonePhases = {},
					Ended = false,
					BoundTrack = nil,
				}
			end

			runPhase(player, character, settings, phaseName)
		end
	end
	Server.Thrust = Thrust

	--// Move 2: Spin (idk) \\--

	local Spin = {}
	do
		local MOVE_NAME = "Spin"
		local FALLBACK_DIGITS = "102759962289170"

		local SPIN_ALIASES = {
			["Startup"] = "Startup",
			["startup"] = "Startup",
			["StartUp"] = "Startup",
			["Thrust"] = "Thrust",
			["thrust"] = "Thrust",
			["Spin"] = "Spin",
			["spin"] = "Spin",
			["End"] = "End",
			["end"] = "End",
			["END"] = "End",
		}

		local activeSpins = {}

		local function normalizeEvent(rawName: any): string?
			if type(rawName) ~= "string" or rawName == "" then
				return nil
			end

			if SPIN_ALIASES[rawName] then
				return SPIN_ALIASES[rawName]
			end

			local key = normalizeKey(rawName)

			if key == "startup" then
				return "Startup"
			elseif key == "thrust" then
				return "Thrust"
			elseif key == "spin" then
				return "Spin"
			elseif key == "end" then
				return "End"
			end

			return nil
		end

		local function cancelSpin(_player: Player?, character: Model, _root: BasePart?, state, _settings)
			state.Ended = true

			if activeSpins[character] == state then
				activeSpins[character] = nil
			end
		end

		local function runPhase(player: Player?, character: Model, settings, rawPhaseName: any)
			local phaseName = normalizeEvent(rawPhaseName)

			if not phaseName then
				return
			end

			local state = activeSpins[character]

			if not state or state.Ended then
				return
			end

			if os.clock() - state.StartTime > settings.PhaseWindow then
				state.Ended = true
				activeSpins[character] = nil
				return
			end

			local humanoid, root = getAliveParts(character)

			if not humanoid or character:FindFirstChild("Stun") then
				cancelSpin(player, character, root, state, settings)
				return
			end

			if state.DonePhases[phaseName] then
				return
			end

			state.DonePhases[phaseName] = true

			if phaseName == "Startup" then
				broadcastToOthers(player, settings.EntryName, {
					char = character,
					root = root,
					phase = "Startup",
				})
			elseif phaseName == "Thrust" then
				if not applyHitPass(character, root, settings.ThrustDamage, settings.ThrustStun, false, settings) then
					cancelSpin(player, character, root, state, settings)
					return
				end

				broadcastToOthers(player, settings.EntryName, {
					char = character,
					root = root,
					phase = "Thrust",
				})
			elseif phaseName == "Spin" then
				if not applyHitPass(character, root, settings.SpinDamage, settings.SpinStun, false, settings) then
					cancelSpin(player, character, root, state, settings)
					return
				end

				broadcastToOthers(player, settings.EntryName, {
					char = character,
					root = root,
					phase = "Spin",
				})
			elseif phaseName == "End" then
				if not applyHitPass(character, root, settings.EndDamage or settings.SpinDamage, settings.EndStun or settings.SpinStun, true, settings) then
					cancelSpin(player, character, root, state, settings)
					return
				end

				broadcastToOthers(player, settings.EntryName, {
					char = character,
					root = root,
					phase = "End",
				})

				state.Ended = true
				if activeSpins[character] == state then
					activeSpins[character] = nil
				end
			end
		end

		function Spin.Activate(player: Player, character: Model, settings, aimOrPhase: any)
			if type(aimOrPhase) == "string" then
				runPhase(player, character, settings, aimOrPhase)
				return
			end

			local previous = activeSpins[character]
			if previous then
				previous.Ended = true
			end

			local humanoid, root = getAliveParts(character)

			if not humanoid then
				return
			end

			local state = {
				StartTime = os.clock(),
				DonePhases = {},
				Ended = false,
				BoundTrack = nil,
			}

			activeSpins[character] = state

			effectsRemote:FireAllClients(settings.EntryName, {
				char = character,
				root = root,
			})

			watchAxeAnimator(
				activeSpins,
				MOVE_NAME,
				FALLBACK_DIGITS,
				SPIN_ALIASES,
				false,
				runPhase,
				player,
				character,
				humanoid,
				settings,
				state
			)

			task.delay(settings.PhaseWindow, function()
				if activeSpins[character] == state then
					state.Ended = true
					activeSpins[character] = nil
				end
			end)
		end

		function Spin.Phase(player: Player, character: Model, settings, phaseName: string)
			if not activeSpins[character] then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then
					return
				end

				activeSpins[character] = {
					StartTime = os.clock(),
					DonePhases = {},
					Ended = false,
					BoundTrack = nil,
				}
			end

			runPhase(player, character, settings, phaseName)
		end
	end
	Server.Spin = Spin
end

--// Dispatcher \\--

function Server.Activate(moveName: string, player: Player, character: Model, settings, ...)
	local handler = Server[moveName]

	if handler and type(handler.Activate) == "function" then
		return handler.Activate(player, character, settings or MovesInfo[moveName], ...)
	end
end

function Server.Phase(moveName: string, player: Player, character: Model, settings, phaseName: string)
	local handler = Server[moveName]

	if handler and type(handler.Phase) == "function" then
		return handler.Phase(player, character, settings or MovesInfo[moveName], phaseName)
	end
end

return Server
