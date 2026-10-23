--// WALLRUN CONTROLLER \\--

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Client = require(script.Parent)
local MovementFX = require(script.Parent:WaitForChild("MovementFX"))

local WallRun = {}

local WALL_RUN_ANIM_SPEED = 1.25

local JumpKeys = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.ButtonA] = true,
}

local FallbackDir = {
	RightVector = function(Root: BasePart) return Root.CFrame.RightVector end,
	LeftVector = function(Root: BasePart) return -Root.CFrame.RightVector end,
}

local function createMapRayParams(character: Model): RaycastParams
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

local function HasForwardInput(Humanoid: Humanoid, Root: BasePart): boolean
	local MoveDirection = Humanoid.MoveDirection
	return MoveDirection.Magnitude > 0.05
		and MoveDirection:Dot(Root.CFrame.LookVector) > 0.1
end

local function IsValidWall(Hit: RaycastResult?, Origin: Vector3): boolean
	return Hit ~= nil
		and Hit.Instance ~= nil
		and Hit.Instance.CanCollide
		and Hit.Distance > 0.5
		and Hit.Distance < (4 + 0.5)
		and math.abs(Hit.Normal.Y) < 0.7
		and Hit.Normal:Dot((Origin - Hit.Position).Unit) > 0.1
end

local function IsBlockingFront(Hit: RaycastResult?): boolean
	return Hit ~= nil
		and Hit.Instance ~= nil
		and Hit.Instance.CanCollide
		and Hit.Distance > 0.1
		and Hit.Distance < (2 + 0.5)
		and math.abs(Hit.Normal.Y) < 0.7
end

local function DetectWall(Humanoid: Humanoid, Root: BasePart, RayParams: RaycastParams)
	if not HasForwardInput(Humanoid, Root) then
		return nil, nil, nil
	end

	local Origin = Root.Position
	local Ground = workspace:Raycast(Origin, Vector3.new(0, -3, 0), RayParams)
	if Ground and Ground.Instance and Ground.Instance.CanCollide and Ground.Distance < 2 then
		return nil, nil, "Ground"
	end

	local Front = workspace:Raycast(Origin, Root.CFrame.LookVector * 2, RayParams)
	if IsBlockingFront(Front) then
		return nil, nil, "Front"
	end

	local Right = workspace:Raycast(Origin, Root.CFrame.RightVector * 4, RayParams)
	local Left = workspace:Raycast(Origin, -Root.CFrame.RightVector * 4, RayParams)

	local RightValid = IsValidWall(Right, Origin)
	local LeftValid = IsValidWall(Left, Origin)

	if not RightValid and not LeftValid then
		return nil, nil, nil
	end

	if RightValid and LeftValid then
		if Right.Distance <= Left.Distance then
			return "RightVector", Right, nil
		end

		return "LeftVector", Left, nil
	end

	if RightValid then
		return "RightVector", Right, nil
	end

	return "LeftVector", Left, nil
end

local function ApplyPhysics(Root: BasePart, Humanoid: Humanoid, Hit: RaycastResult, BV: BodyVelocity, BG: BodyGyro, Side: string)
	local Look = Root.CFrame.LookVector
	local MoveDirection = Humanoid.MoveDirection
	local Travel = MoveDirection.Magnitude > 0.05 and MoveDirection.Unit or Look
	local N = Hit.Normal
	local WallToChar = (Root.Position - Hit.Position).Unit
	N = N:Dot(WallToChar) < 0 and -N or N

	local Tangent = Vector3.yAxis:Cross(N)
	Tangent = Tangent.Magnitude <= 1e-3 and (Travel - N * Travel:Dot(N)) or Tangent

	local HasTangent = Tangent.Magnitude > 1e-3
	local Dir = HasTangent and Tangent.Unit or (FallbackDir[Side] and FallbackDir[Side](Root) or Vector3.zAxis)
	Dir = HasTangent and (Dir:Dot(Travel) < 0 and -Dir or Dir) or Dir

	local Mass = Root.AssemblyMass
	BG.MaxTorque = Vector3.one * (Mass * 5e4)
	BG.CFrame = CFrame.lookAt(Root.Position, Root.Position + Dir)

	local Correction = math.clamp((Hit.Distance - 0.45) * 25, -12, 12)
	BV.Velocity = HasTangent and (Dir * 45 - N * Correction) or (Dir * 45)
end

local function isActionLocked(character: Model): boolean
	if character:FindFirstChild("Stun")
		or character:FindFirstChild("Blocking")
		or character:FindFirstChild("DoingMove")
		or character:FindFirstChild("DoingCombat") then
		return true
	end

	return #Client.Actions > 0 or #Client.Stuns > 0 or Client.Dashing
end

local function loadMovementTrack(humanoid: Humanoid, animKey: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
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
	track.Looped = looped
	anim:Destroy()
	return track
end

function WallRun.Start(Character: Model)
	local Humanoid = Character:WaitForChild("Humanoid", 5) :: Humanoid?
	local Root = Character:WaitForChild("HumanoidRootPart", 5) :: BasePart?

	if not Humanoid or not Root then
		return function() end
	end

	local RayParams = createMapRayParams(Character)
	local Mass = Root.AssemblyMass
	local Active = false
	local Side: string? = nil
	local BV: BodyVelocity? = nil
	local BG: BodyGyro? = nil
	local LastNormal: Vector3? = nil
	local ActiveRunTrack: AnimationTrack? = nil
	local ActiveGrabAttachment: Attachment? = nil
	local JumpOffActive = false
	local Grace = 0.15
	local SwitchCd = 0
	local StabilityTmr = 0
	local RetryCd = 0

	local function StopRunVisuals()
		if ActiveRunTrack then
			if ActiveRunTrack.IsPlaying then
				ActiveRunTrack:Stop(0.12)
			end
			ActiveRunTrack:Destroy()
			ActiveRunTrack = nil
		end

		if ActiveGrabAttachment then
			for _, descendant in ActiveGrabAttachment:GetDescendants() do
				if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
					descendant.Enabled = false
				end
			end
			Debris:AddItem(ActiveGrabAttachment, 1)
			ActiveGrabAttachment = nil
		end
	end

	local function ClearMovers()
		if BV then BV:Destroy(); BV = nil end
		if BG then BG:Destroy(); BG = nil end
	end

	local function getWallRunArm(side: string): (BasePart?, string, string)
		local isLeft = side == "LeftVector"
		local armNames = if isLeft then {"Left Arm", "LeftHand", "LeftLowerArm"} else {"Right Arm", "RightHand", "RightLowerArm"}
		local arm: BasePart? = nil
		for _, armName in ipairs(armNames) do
			local candidate = Character:FindFirstChild(armName)
			if candidate and candidate:IsA("BasePart") then
				arm = candidate
				break
			end
		end

		return arm, if isLeft then "LeftWallGrab" else "RightWallGrab", if isLeft then "LeftKick" else "RightKick"
	end

	local function attachWallRunVisual(side: string)
		local arm, grabName = getWallRunArm(side)
		if not arm then
			return
		end

		local template = MovementFX.FindTemplate({grabName})
		if not template or not template:IsA("Attachment") then
			return
		end

		local attachment = template:Clone()
		-- These templates were authored under a different parent; reset their local
		-- position so they sit on the arm instead of inheriting a shoulder offset.
		attachment.Position = Vector3.zero
		attachment.Parent = arm
		ActiveGrabAttachment = attachment

		for _, descendant in attachment:GetDescendants() do
			if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
				descendant.Enabled = true
			end
		end
	end

	local function playWallKick(side: string?)
		if not side then
			return
		end

		local arm, _, kickName = getWallRunArm(side)
		if arm then
			MovementFX.PlayOnce(Character, {kickName}, arm.Name, 2.5, Vector3.zero)
		end
	end

	local function Detach(Cooldown: number?)
		Active = false
		Side = nil
		Grace = 0.15
		Character:SetAttribute("WallRunning", nil)
		StopRunVisuals()
		ClearMovers()

		if Cooldown then
			RetryCd = math.max(RetryCd, Cooldown)
			StabilityTmr = math.max(StabilityTmr, Cooldown)
		end
	end

	local function Activate(S: string)
		StopRunVisuals()

		for _, Obj in Root:GetChildren() do
			local IsMover = Obj:IsA("BodyVelocity") or Obj:IsA("BodyGyro")
			if IsMover then
				Obj:Destroy()
			end
		end

		BV = Instance.new("BodyVelocity")
		BV.MaxForce = Vector3.one * (Mass * 2000)
		BV.Velocity = Vector3.zero
		BV.Parent = Root

		BG = Instance.new("BodyGyro")
		BG.P = Mass * 10000
		BG.MaxTorque = Vector3.one * (Mass * 10000)
		BG.CFrame = Root.CFrame
		BG.Parent = Root

		Active = true
		Side = S
		Grace = 0.15
		RetryCd = 0
		Character:SetAttribute("WallRunning", S)

		local runAnimKey = if S == "LeftVector" then "LeftRun" else "RightRun"
		ActiveRunTrack = loadMovementTrack(Humanoid, runAnimKey, Enum.AnimationPriority.Action2, true)
		if ActiveRunTrack then
			ActiveRunTrack:Play(0.1, 1, WALL_RUN_ANIM_SPEED)
		end

		attachWallRunVisual(S)
	end

	local function Release()
		Detach()
	end

	local InputConn = UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed or not Active then
			return
		end

		if not JumpKeys[Input.KeyCode] then
			return
		end

		local currentSide = Side
		local jumpAway = LastNormal or Vector3.zero
		local horizontalAway = Vector3.new(jumpAway.X, 0, jumpAway.Z)
		if horizontalAway.Magnitude > 0.01 then
			horizontalAway = horizontalAway.Unit
		else
			horizontalAway = if currentSide == "LeftVector" then Root.CFrame.RightVector else -Root.CFrame.RightVector
		end

		-- Do not auto-start another wall run while the jump-off remains airborne.
		JumpOffActive = true
		Character:SetAttribute("WallJumpLock", true)
		Detach(0.25)

		if Root.Parent then
			playWallKick(currentSide)
			-- Enter the normal jump state so Animate plays the regular Jump track;
			-- wall-jump-specific left/right tracks are intentionally not used.
			Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			-- Stronger launch along the run direction and away from the wall.
			Root.AssemblyLinearVelocity = Root.CFrame.LookVector * 52 + horizontalAway * 48 + Vector3.new(0, 48, 0)
		end
	end)

	local SteppedConn = RunService.RenderStepped:Connect(function(DT)
		if not Character.Parent or Humanoid.Health <= 0 then
			return
		end

		if isActionLocked(Character) then
			if Active then
				Release()
			end
			return
		end

		SwitchCd = math.max(0, SwitchCd - DT)
		StabilityTmr = math.max(0, StabilityTmr - DT)
		RetryCd = math.max(0, RetryCd - DT)

		local NewSide, Hit, DetectState = DetectWall(Humanoid, Root, RayParams)

		if JumpOffActive or Character:GetAttribute("WallJumpLock") == true then
			if Humanoid.FloorMaterial ~= Enum.Material.Air or DetectState == "Ground" then
				JumpOffActive = false
				Character:SetAttribute("WallJumpLock", nil)
			else
				return
			end
		end

		if not Active then
			if NewSide and StabilityTmr == 0 and RetryCd == 0 then
				Activate(NewSide)
				StabilityTmr = 0.05
			end
			return
		end

		if NewSide and NewSide ~= Side and SwitchCd == 0 and StabilityTmr == 0 then
			Release()
			Activate(NewSide)
			SwitchCd = 0.2
			StabilityTmr = 0.05
			return
		end

		if not NewSide then
			Grace -= DT
			if Grace <= 0 then
				Release()
				if DetectState == "Ground" then
					RetryCd = math.max(RetryCd, 0.2)
				end
				StabilityTmr = 0.05
			end
			return
		end

		Grace = 0.15

		if Hit and BV and BG and Side then
			LastNormal = Hit.Normal
			ApplyPhysics(Root, Humanoid, Hit, BV, BG, Side)
		end
	end)

	return function()
		InputConn:Disconnect()
		SteppedConn:Disconnect()
		StopRunVisuals()
		JumpOffActive = false
		Character:SetAttribute("WallJumpLock", nil)
		ClearMovers()
		Character:SetAttribute("WallRunning", nil)
	end
end

return WallRun
