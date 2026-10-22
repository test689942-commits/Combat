--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))

--// Variables \\--

local MoveClient = {}

local BLOCKING_STATES = {"Stun", "Blocking", "DoingMove", "DoingCombat"}
local ANIMATION_LOAD_TIMEOUT = 1

local player = Players.LocalPlayer
local mouse = player:GetMouse()

mouse.TargetFilter = workspace:WaitForChild("Debris")

--// Character \\--

function MoveClient.GetCharacterParts()
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

function MoveClient.CanStart(): boolean
	local character = MoveClient.GetCharacterParts()

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

--// Movement Lock \\--

function MoveClient.LockMovement(moveName: string, character: Model, humanoid: Humanoid)
	local lock = {
		WalkSpeed = humanoid.WalkSpeed,
		Marker = nil,
	}

	humanoid.WalkSpeed = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	table.insert(Client.Actions, moveName)

	local marker = Instance.new("BoolValue")
	marker.Name = "DoingMove"
	marker.Parent = character

	lock.Marker = marker

	return lock
end

function MoveClient.UnlockMovement(moveName: string, humanoid: Humanoid, lock)
	humanoid.WalkSpeed = lock.WalkSpeed
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

	local actionIndex = table.find(Client.Actions, moveName)

	if actionIndex then
		table.remove(Client.Actions, actionIndex)
	end

	if lock.Marker then
		lock.Marker:Destroy()
		lock.Marker = nil
	end
end

--// Aim \\--

function MoveClient.FaceMouse(root: BasePart)
	local aimPosition = mouse.Hit.Position
	local flatTarget = Vector3.new(aimPosition.X, root.Position.Y, aimPosition.Z)

	if (flatTarget - root.Position).Magnitude < 0.1 then
		return
	end

	root.CFrame = CFrame.lookAt(root.Position, flatTarget)
end

function MoveClient.GetAimPosition(): Vector3
	return mouse.Hit.Position
end

--// Animation \\--

function MoveClient.LoadTrack(humanoid: Humanoid, moveName: string): AnimationTrack?
	if not Client.Animations.DetectSpecificAnimation("Moves", moveName) then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		return nil
	end

	local animation = Client.Animations.GetAnimation("Moves", moveName)
	local track = animator:LoadAnimation(animation)
	local loadDeadline = os.clock() + ANIMATION_LOAD_TIMEOUT

	while track.Length == 0 and os.clock() < loadDeadline do
		task.wait()
	end
	track.Priority = Enum.AnimationPriority.Action2
	track.Looped = false

	animation:Destroy()

	return track
end

function MoveClient.StartTrack(track: AnimationTrack, duration: number)
	track:Play(0.1)

	task.delay(duration, function()
		if track.IsPlaying then
			track:Stop(0.2)
		end
	end)
end

return MoveClient
