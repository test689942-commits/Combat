--// Services \\--

local Debris = game:GetService("Debris")

--// Setup \\--

local Movement = {}
local Client = require(script.Parent)

Movement.__index = Movement

local SLIDE_SPEED = 52
local SLIDE_DURATION = 0.45
local SLIDE_COOLDOWN = 1.2
local WALL_CLIMB_COOLDOWN = 0.8

local lastSlideTime = 0
local lastClimbTime = 0

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

--// Slide (Audio: rbxassetid://6429226498) \\--

Movement.Slide = function()
	local Character: Model = Client.Character
	local Humanoid: Humanoid = Client.Humanoid
	local Root: BasePart = Client.Root

	if not Character or not Humanoid or not Root or Humanoid.Health <= 0 then
		return
	end

	if Client.InAir or hasBlockingState(Character) then
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

	local slideVelocity = Instance.new("BodyVelocity")
	slideVelocity.Name = "SlideVelocity"
	slideVelocity.MaxForce = Vector3.new(4e4, 0, 4e4)
	slideVelocity.Velocity = direction * SLIDE_SPEED
	slideVelocity.Parent = Root
	Debris:AddItem(slideVelocity, SLIDE_DURATION)

	local slideSound = Instance.new("Sound")
	slideSound.Name = "SlideSound"
	slideSound.SoundId = Client.SlideSoundId
	slideSound.Volume = 0.65
	slideSound.Parent = Root
	slideSound:Play()
	Debris:AddItem(slideSound, 2)

	local animName = if Client.Animations.DetectSpecificAnimation("Movement", "Slide") then "Slide" else "Roll"
	if Client.Animations.DetectSpecificAnimation("Movement", animName) then
		local slideAnim = Client.Animations.GetAnimation("Movement", animName)
		if slideAnim and Humanoid:FindFirstChildOfClass("Animator") then
			local track = Humanoid.Animator:LoadAnimation(slideAnim)
			track.Priority = Enum.AnimationPriority.Action3
			track:Play(0.1)
			slideAnim:Destroy()
		end
	end
end

--// WallClimb & Vault \\--

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
	elseif shouldVault then
		lastClimbTime = tick()
		local vaultVelocity = Instance.new("BodyVelocity")
		vaultVelocity.Name = "VaultVelocity"
		vaultVelocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
		vaultVelocity.Velocity = Root.CFrame.LookVector * 28 + Vector3.new(0, 32, 0)
		vaultVelocity.Parent = Root
		Debris:AddItem(vaultVelocity, 0.22)
	end
end

return Movement
