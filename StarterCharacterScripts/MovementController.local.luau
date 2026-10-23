--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Modules \\--

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Client = require(Modules:WaitForChild("ClientSystem"))
local Movement = require(Modules.ClientSystem:WaitForChild("Movement"))
local DirectionalMovement = require(Modules.ClientSystem:WaitForChild("DirectionalMovement"))
local SprintVisuals = require(Modules.ClientSystem:WaitForChild("SprintVisuals"))
local WallRun = require(Modules.ClientSystem:WaitForChild("WallRun"))
local CameraShiftlock = require(Modules.ClientSystem:WaitForChild("CameraShiftlock"))
local FootSteps = require(Modules.ClientSystem:WaitForChild("FootSteps"))
local MovementFX = require(Modules.ClientSystem:WaitForChild("MovementFX"))

--// Character Setup \\--

local Character: Model = script.Parent
local Humanoid: Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
local Root: BasePart = Character:WaitForChild("HumanoidRootPart") :: BasePart

Client.Character = Character
Client.Humanoid = Humanoid
Client.Root = Root

--// Sub-Controllers \\--

CameraShiftlock.Init()
CameraShiftlock.InstallCombatJumpTuning(Character)

local cleanupDirectional = DirectionalMovement.Start(Character)
local cleanupSprintVisuals = SprintVisuals.Start(Character)
local cleanupWallRun = WallRun.Start(Character)

--// Fall / Landed & Jump FootStep \\--

Humanoid.StateChanged:Connect(function(_Old: Enum.HumanoidStateType, New: Enum.HumanoidStateType)
	if New == Enum.HumanoidStateType.Freefall then
		Client.InAir = true
		Client.FallHeight = Root.Position.Y
	elseif New == Enum.HumanoidStateType.Jumping then
		Client.InAir = true
		FootSteps.PlayStep(Root, Enum.HumanoidStateType.Jumping, 0.4, 1)
		MovementFX.PlayOnce(Character, {"JumpFX", "Jump"})
	elseif New == Enum.HumanoidStateType.Landed or New == Enum.HumanoidStateType.Running then
		if Client.InAir then
			Client.InAir = false
			Movement.Landed()
			if Humanoid.FloorMaterial ~= Enum.Material.Air then
				FootSteps.PlayStep(Root, Humanoid.FloorMaterial, 0.45, 0.92)
			end
		end
	end
end)

--// Footstep Loop & Sprint State Guard \\--

local stepAccumulator = 0

local heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
	if not Character.Parent or Humanoid.Health <= 0 then
		return
	end

	-- Automatically drop sprint if stunned or blocking
	if Client.Running then
		if Character:FindFirstChild("Stun")
			or Character:FindFirstChild("Blocking")
			or Character:FindFirstChild("DoingMove")
			or Character:FindFirstChild("DoingCombat")
			or Humanoid.MoveDirection.Magnitude < 0.05 then
			Movement.SetSprint(false)
		end
	end

	-- Material-mapped footsteps while moving on ground
	local horizontalSpeed = (Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local onGround = Humanoid.FloorMaterial ~= Enum.Material.Air and not Client.InAir

	if onGround and horizontalSpeed > 2 and Humanoid.MoveDirection.Magnitude > 0.05 then
		local strideInterval = math.clamp(7 / math.max(horizontalSpeed, 6), 0.24, 0.52)
		stepAccumulator += dt
		if stepAccumulator >= strideInterval then
			stepAccumulator = 0
			local sprinting = Humanoid:GetAttribute("Sprint") == true or Character:GetAttribute("Sprint") == true
			local volume = if sprinting then 0.42 else 0.28
			local pitch = if sprinting then (1.02 + math.random() * 0.08) else (0.94 + math.random() * 0.08)
			FootSteps.PlayStep(Root, Humanoid.FloorMaterial, volume, pitch)
		end
	else
		stepAccumulator = 0
	end
end)

Humanoid.Died:Once(function()
	if heartbeatConn then
		heartbeatConn:Disconnect()
	end
	cleanupDirectional()
	cleanupSprintVisuals()
	cleanupWallRun()
end)
