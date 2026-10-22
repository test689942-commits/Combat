--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local HitDetection = require(ReplicatedStorage.Modules.Shared:WaitForChild("HitDetection"))
local Info = require(script.Parent).GroundSlam
local Effects = require(script.Parent:WaitForChild("Effects"))

--// Variables \\--

local GroundSlam = {
	Effect = Effects.GroundSlam,
}

local MOVE_NAME = script.Name
local BLOCKING_STATES = {"Stun", "Blocking", "DoingMove", "DoingCombat"}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local activeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Active")

local cooldownEnd = 0
local active = false
local moveMarker = nil
local holding = false
local cancelled = false
local savedWalkSpeed = 16

mouse.TargetFilter = workspace:WaitForChild("Debris")

--// Character \\--

local function getCharacterParts()
	local character = player.Character

	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end

	return character, humanoid, root
end

local function canStart(): boolean
	if active or os.clock() < cooldownEnd then
		return false
	end

	local character = getCharacterParts()

	if not character then
		return false
	end

	for _, stateName in BLOCKING_STATES do
		if character:FindFirstChild(stateName) then
			return false
		end
	end

	return #Client.Actions == 0 and #Client.Stuns == 0 and not Client.Dashing
end

local function lockMovement(character: Model, humanoid: Humanoid)
	savedWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	table.insert(Client.Actions, MOVE_NAME)

	moveMarker = Instance.new("BoolValue")
	moveMarker.Name = "DoingMove"
	moveMarker.Parent = character
end

local function unlockMovement(humanoid: Humanoid)
	humanoid.WalkSpeed = savedWalkSpeed
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

	local actionIndex = table.find(Client.Actions, MOVE_NAME)

	if actionIndex then
		table.remove(Client.Actions, actionIndex)
	end

	if moveMarker then
		moveMarker:Destroy()
		moveMarker = nil
	end
end

local function faceMouse(root: BasePart)
	local aimPosition = mouse.Hit.Position
	local flatTarget = Vector3.new(aimPosition.X, root.Position.Y, aimPosition.Z)

	if (flatTarget - root.Position).Magnitude < 0.1 then
		return
	end

	root.CFrame = CFrame.lookAt(root.Position, flatTarget)
end

local function findAirborneEnemyRoot(root: BasePart): BasePart?
	local nearbyCharacters = HitDetection.GetCharactersInSphere(root.Position, Info.Radius + Info.VerticalReach, {workspace.Effects, workspace.Debris, player.Character}, "GroundSlamAim")
	local closestRoot = nil
	local closestDistance = math.huge

	for _, model in nearbyCharacters do
		local enemyRoot = model:FindFirstChild("HumanoidRootPart")

		if enemyRoot and enemyRoot:FindFirstChild("AirPos") then
			local distance = (enemyRoot.Position - root.Position).Magnitude

			if distance < closestDistance then
				closestDistance = distance
				closestRoot = enemyRoot
			end
		end
	end

	return closestRoot
end

local function faceAim(character: Model, root: BasePart)
	local airborneRoot = if character:FindFirstChild("AirCombat") then findAirborneEnemyRoot(root) else nil

	if not airborneRoot then
		faceMouse(root)
		return
	end

	local flatTarget = Vector3.new(airborneRoot.Position.X, root.Position.Y, airborneRoot.Position.Z)

	if (flatTarget - root.Position).Magnitude < 0.1 then
		return
	end

	root.CFrame = CFrame.lookAt(root.Position, flatTarget)
end

local function playAnimation(humanoid: Humanoid)
	if not Client.Animations.DetectSpecificAnimation("Moves", MOVE_NAME) then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		return
	end

	local animation = Client.Animations.GetAnimation("Moves", MOVE_NAME)

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action2
	track.Looped = false
	track:Play(0.1)

	task.delay(Info.LockDuration, function()
		track:Stop(0.2)
	end)

	animation:Destroy()
end

--// Move Flow \\--

local function holdAim(character: Model, humanoid: Humanoid, root: BasePart)
	local startTime = os.clock()

	while holding and os.clock() - startTime <= Info.MaxHoldTime do
		if humanoid.Health <= 0 or character:FindFirstChild("Stun") then
			cancelled = true
			break
		end

		faceAim(character, root)
		RunService.RenderStepped:Wait()
	end

	holding = false
end

local function run()
	local character, humanoid, root = getCharacterParts()

	if not character then
		return
	end

	active = true
	holding = true
	cancelled = false
	lockMovement(character, humanoid)

	holdAim(character, humanoid, root)

	if cancelled then
		unlockMovement(humanoid)
		active = false
		return
	end

	cooldownEnd = os.clock() + Info.Cooldown
	Client.Library.SetCooldown(character, MOVE_NAME, Info.Cooldown)
	activeRemote:FireServer(MOVE_NAME, mouse.Hit.Position)
	playAnimation(humanoid)

	task.wait(Info.LockDuration)

	unlockMovement(humanoid)
	active = false
end

--// Public \\--

function GroundSlam.TryStart()
	if canStart() then
		task.spawn(run)
	end
end

function GroundSlam.Release()
	if holding then
		holding = false
	end
end

function GroundSlam.Cancel()
	if holding then
		cancelled = true
		holding = false
	end
end

return GroundSlam
