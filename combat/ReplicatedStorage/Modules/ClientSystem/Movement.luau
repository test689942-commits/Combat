--// Services \\--

local Debris = game:GetService("Debris")

--// Setup \\--

local Movement = {}
local Client = require(script.Parent)
local MovementFX = require(script.Parent:WaitForChild("MovementFX"))

Movement.__index = Movement

local SLIDE_SPEED = 52
local SLIDE_DURATION = 0.55
local SLIDE_COOLDOWN = 1.2
local WALL_CLIMB_COOLDOWN = 0.8

local lastSlideTime = 0
local lastClimbTime = 0
local vaultToggle = false

local activeSlideVelocity: BodyVelocity? = nil
local activeSlideTrack: AnimationTrack? = nil
local activeSlideSound: Sound? = nil
local slideCancelThread: thread? = nil


local function hasBlockingState(character: Model?): boolean
	if not character then
		return true
	end

	if character:FindFirstChild("Stun")
		or character:FindFirstChild("Blocking")
		or character:FindFirstChild("DoingMove")
		or character:FindFirstChild("DoingCombat") then
		return true
	end

	if character:GetAttribute("Ragdolled") or character:GetAttribute("Stunned") then
		return true
	end

	return #Client.Actions > 0 or #Client.Stuns > 0 or Client.Dashing
end

local function createMapParams(character: Model): RaycastParams
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {
		character,
		workspace:FindFirstChild("Effects"),
		workspace:FindFirstChild("Debris"),
		workspace:FindFirstChild("NPCS"),
	}

	return rayParams
end

local function playMovementAnim(humanoid: Humanoid, animKey: string, priority: Enum.AnimationPriority, fadeTime: number?, speed: number?): AnimationTrack?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	if not Client.Animations.DetectSpecificAnimation("Movement", animKey) then
		return nil
	end

	local anim = Client.Animations.GetAnimation("Movement", animKey)
	if not anim then
		return nil
	end

	local track = animator:LoadAnimation(anim)
	track.Priority = priority
	track:Play(fadeTime or 0.1, 1, speed or 1)
	anim:Destroy()
	return track
end

local function cancelActiveSlide()
	if slideCancelThread then
		task.cancel(slideCancelThread)
		slideCancelThread = nil
	end

	if activeSlideVelocity then
		if activeSlideVelocity.Parent then
			activeSlideVelocity:Destroy()
		end
		activeSlideVelocity = nil
	end

	if activeSlideTrack then
		if activeSlideTrack.IsPlaying then
			activeSlideTrack:Stop(0.1)
		end
		activeSlideTrack:Destroy()
		activeSlideTrack = nil
	end

	if activeSlideSound then
		if activeSlideSound.Parent then
			activeSlideSound:Stop()
		end
		activeSlideSound = nil
	end

	Client.Sliding = false
	if Client.Character then
		Client.Character:SetAttribute("Sliding", false)
	end
end

--// Landed / Roll \\--

Movement.Landed = function()
	local Root: BasePart = Client.Root
	local Character: Model = Client.Character
	local Humanoid: Humanoid = Client.Humanoid

	if not Root or not Character or not Humanoid then
		return
	end

	if Humanoid:GetState() == Enum.HumanoidStateType.Freefall
		or Humanoid:GetState() == Enum.HumanoidStateType.Jumping
		or Client.Landed then
		return
	end

	if #Client.Actions > 0 then
		return
	end

	local Height = (Client.FallHeight - Root.Position.Y)
	if not Height or Height <= 15 then
		return
	end

	Client.Landed = true
	local rollanim: Animation = Client.Animations.GetAnimation("Movement", "Roll")
	local roll: AnimationTrack = Humanoid.Animator:LoadAnimation(rollanim)

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	roll.Priority = Enum.AnimationPriority.Action3
	roll:Play(0.1, 1, 1.25)
	table.insert(Client.Speeds, `LandedSpeed{(Height > 30 and -10) or -5}`)

	roll.Stopped:Once(function()
		Client.Landed = false
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		local speedIndex = table.find(Client.Speeds, `LandedSpeed{(Height > 30 and -10) or -5}`)
		if speedIndex then
			table.remove(Client.Speeds, speedIndex)
		end
	end)
end

--// Sprint \\--

Movement.SetSprint = function(active: boolean)
	local Character: Model = Client.Character
	local Humanoid: Humanoid = Client.Humanoid

	if not Character or not Humanoid or Humanoid.Health <= 0 then
		return
	end

	if active and hasBlockingState(Character) then
		active = false
	end

	Client.Running = active
	Humanoid:SetAttribute("Sprint", active)
	Character:SetAttribute("Sprint", active)

	if not hasBlockingState(Character) then
		Humanoid.WalkSpeed = if active then Client.SprintSpeed else Client.BaseSpeed
	end
end

--// Slide (Audio is registered as Sounds/SFX.Slide) \\--

Movement.Slide = function()
	local Character: Model = Client.Character
	local Humanoid: Humanoid = Client.Humanoid
	local Root: BasePart = Client.Root

	if not Character or not Humanoid or not Root or Humanoid.Health <= 0 then
		return
	end

	if Client.InAir or Client.Sliding or hasBlockingState(Character) then
		return
	end

	if tick() - lastSlideTime < SLIDE_COOLDOWN then
		return
	end

	lastSlideTime = tick()

	local direction = Humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end

	if direction.Magnitude < 0.1 then
		return
	end

	direction = direction.Unit

	cancelActiveSlide()
	Client.Sliding = true
	Character:SetAttribute("Sliding", true)

	local slideVelocity = Instance.new("BodyVelocity")
	slideVelocity.Name = "SlideVelocity"
	slideVelocity.MaxForce = Vector3.new(4e4, 0, 4e4)
	slideVelocity.Velocity = direction * SLIDE_SPEED
	slideVelocity.Parent = Root
	activeSlideVelocity = slideVelocity

	local slideSound = Client.Sounds.GetSound("SFX", "Slide")
	if slideSound then
		slideSound.Volume = 0.65
		slideSound.Parent = Root
		slideSound:Play()
		Debris:AddItem(slideSound, 2)
		activeSlideSound = slideSound
	end

	local animName = if Client.Animations.DetectSpecificAnimation("Movement", "Sliding") then "Sliding" else "Roll"
	activeSlideTrack = playMovementAnim(Humanoid, animName, Enum.AnimationPriority.Action3, 0.08, 1)

	slideCancelThread = task.delay(SLIDE_DURATION, function()
		slideCancelThread = nil
		cancelActiveSlide()
	end)
end

--// WallClimb, Vault (Vault1 / Vault2) & Slide LongJump \\--

Movement.ShouldWallClimb = function(Character: Model, Humanoid: Humanoid): (boolean, boolean)
	local RootPart = Humanoid.RootPart
	if not RootPart then
		return false, false
	end

	local MapParams = createMapParams(Character)

	local Ground = workspace:Raycast(RootPart.Position, Vector3.new(0, -6, 0), MapParams)
	local TopCheck = workspace:Raycast(RootPart.Position, Vector3.new(0, 10, 0), MapParams)
	if TopCheck then
		return false, false
	end

	local WallCheck = workspace:Raycast(RootPart.Position, RootPart.CFrame.LookVector * 2.5, MapParams)
	local HeadCheck = workspace:Raycast(RootPart.Position + Vector3.new(0, 4.5, 0), RootPart.CFrame.LookVector * 3, MapParams)

	if not WallCheck then
		return false, false
	end

	if not HeadCheck and WallCheck then
		return false, true
	end

	if Ground then
		return false, false
	end

	local VerticalWall = WallCheck.Normal.Y >= -0.05 and WallCheck.Normal.Y <= 0.05
	return VerticalWall, false
end

local function tryDashWallJump(Character: Model, Humanoid: Humanoid, Root: BasePart): boolean
	local contactTime = Character:GetAttribute("DashWallContactAt")
	local wallNormal = Character:GetAttribute("DashWallNormal")
	if typeof(contactTime) ~= "number" or os.clock() - contactTime > 0.8 or typeof(wallNormal) ~= "Vector3" then
		return false
	end

	local horizontalNormal = Vector3.new(wallNormal.X, 0, wallNormal.Z)
	if horizontalNormal.Magnitude < 0.5 then
		return false
	end
	horizontalNormal = horizontalNormal.Unit

	local mapParams = createMapParams(Character)
	local wallHit = workspace:Raycast(Root.Position, -horizontalNormal * 3.5, mapParams)
	if not wallHit or math.abs(wallHit.Normal.Y) >= 0.7 or wallHit.Normal:Dot(horizontalNormal) < 0.5 then
		return false
	end

	local alongWall = Humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if alongWall.Magnitude < 0.1 then
		alongWall = Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	alongWall -= horizontalNormal * alongWall:Dot(horizontalNormal)
	if alongWall.Magnitude < 0.1 then
		alongWall = Vector3.yAxis:Cross(horizontalNormal)
	end
	alongWall = alongWall.Unit

	local wallJumpVelocity = Instance.new("BodyVelocity")
	wallJumpVelocity.Name = "DashWallJumpVelocity"
	wallJumpVelocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
	wallJumpVelocity.Velocity = alongWall * 48 + horizontalNormal * 42 + Vector3.new(0, 46, 0)
	wallJumpVelocity.Parent = Root
	Debris:AddItem(wallJumpVelocity, 0.22)

	Character:SetAttribute("DashWallContactAt", nil)
	Character:SetAttribute("DashWallNormal", nil)
	Character:SetAttribute("WallJumpLock", true)
	MovementFX.PlayOnce(Character, {"WallJump"}, "HumanoidRootPart", 3)
	Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	return true
end

Movement.TryWallClimbOrVault = function()
	local Character: Model = Client.Character
	local Humanoid: Humanoid = Client.Humanoid
	local Root: BasePart = Client.Root

	if not Character or not Humanoid or not Root or Humanoid.Health <= 0 then
		return
	end

	if hasBlockingState(Character) or Character:GetAttribute("WallRunning") ~= nil then
		return
	end

	-- LongJump when jumping out of an active Slide (rbxassetid://71457670921368)
	if Client.Sliding then
		cancelActiveSlide()

		local direction = Humanoid.MoveDirection
		if direction.Magnitude < 0.1 then
			direction = Root.CFrame.LookVector * Vector3.new(1, 0, 1)
		end
		direction = if direction.Magnitude > 0.05 then direction.Unit else Root.CFrame.LookVector

		local longJumpVelocity = Instance.new("BodyVelocity")
		longJumpVelocity.Name = "LongJumpVelocity"
		longJumpVelocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
		longJumpVelocity.Velocity = direction * 54 + Vector3.new(0, 38, 0)
		longJumpVelocity.Parent = Root
		Debris:AddItem(longJumpVelocity, 0.24)

		playMovementAnim(Humanoid, "LongJump", Enum.AnimationPriority.Action3, 0.08, 1)
		return
	end

	if tryDashWallJump(Character, Humanoid, Root) then
		return
	end

	if tick() - lastClimbTime < WALL_CLIMB_COOLDOWN then
		return
	end

	local shouldClimb, shouldVault = Movement.ShouldWallClimb(Character, Humanoid)

	if shouldClimb then
		lastClimbTime = tick()
		local climbVelocity = Instance.new("BodyVelocity")
		climbVelocity.Name = "WallClimbVelocity"
		climbVelocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
		climbVelocity.Velocity = Root.CFrame.LookVector * 8 + Vector3.new(0, 46, 0)
		climbVelocity.Parent = Root
		Debris:AddItem(climbVelocity, 0.28)

		playMovementAnim(Humanoid, "Sprint", Enum.AnimationPriority.Action3, 0.08, 1.15)
	elseif shouldVault then
		lastClimbTime = tick()
		local vaultVelocity = Instance.new("BodyVelocity")
		vaultVelocity.Name = "VaultVelocity"
		vaultVelocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
		vaultVelocity.Velocity = Root.CFrame.LookVector * 28 + Vector3.new(0, 32, 0)
		vaultVelocity.Parent = Root
		Debris:AddItem(vaultVelocity, 0.22)

		vaultToggle = not vaultToggle
		local vaultAnimKey = if vaultToggle then "Vault1" else "Vault2"
		playMovementAnim(Humanoid, vaultAnimKey, Enum.AnimationPriority.Action3, 0.06, 1)
	end
end

return Movement
