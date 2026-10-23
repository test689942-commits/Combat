--// SHIFTLOCK OFFSET & COMBAT JUMP TUNING \\--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local CameraShiftlock = {}

local SHIFTLOCK_OFFSET = Vector3.new(1.3, 0.35, 0)
local SHIFTLOCK_ICON = "http://www.roblox.com/asset/?id=109916623354797"

local initialized = false
local cameraController = nil
local lastMouseLocked = false

local function getCameraController()
	if cameraController then
		return cameraController
	end

	local playerScripts = Player:FindFirstChild("PlayerScripts")
	local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")

	if not playerModule then
		return nil
	end

	local ok, module = pcall(require, playerModule)

	if not ok or not module.GetCameras then
		return nil
	end

	local camerasOk, cameras = pcall(function()
		return module:GetCameras()
	end)

	if camerasOk and cameras then
		cameraController = cameras.activeCameraController
	end

	return cameraController
end

local function setMouseLockOffset(offset: Vector3)
	local controller = getCameraController()

	if controller and controller.SetMouseLockOffset then
		pcall(function()
			controller:SetMouseLockOffset(offset)
		end)
	end
end

function CameraShiftlock.InstallCombatJumpTuning(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?

	if not humanoid then
		return
	end

	local baseJumpHeight = humanoid.JumpHeight
	local baseJumpPower = humanoid.JumpPower
	local resetThread: thread? = nil

	humanoid.StateChanged:Connect(function(_, newState)
		local inCombat = character:GetAttribute("InCombat") == true or character:GetAttribute("CombatTag") == true

		if newState ~= Enum.HumanoidStateType.Jumping or not inCombat then
			return
		end

		baseJumpHeight = math.max(baseJumpHeight, humanoid.JumpHeight)
		baseJumpPower = math.max(baseJumpPower, humanoid.JumpPower)

		if humanoid.JumpHeight > 3.5 then
			humanoid.JumpHeight = math.max(humanoid.JumpHeight - 1, 3.5)
		end

		if humanoid.JumpPower > 25 then
			humanoid.JumpPower = math.max(humanoid.JumpPower - 7, 25)
		end

		if resetThread then
			task.cancel(resetThread)
		end

		resetThread = task.delay(1.5, function()
			resetThread = nil
			if humanoid.Parent then
				humanoid.JumpHeight = baseJumpHeight
				humanoid.JumpPower = baseJumpPower
			end
		end)
	end)
end

function CameraShiftlock.Init()
	if initialized then
		return
	end

	initialized = true

	Player.CameraMaxZoomDistance = 20
	Player.CameraMinZoomDistance = 0

	RunService.RenderStepped:Connect(function()
		Player.CameraMaxZoomDistance = 20
		Player.CameraMinZoomDistance = 0

		local mouseLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

		if mouseLocked then
			setMouseLockOffset(SHIFTLOCK_OFFSET)
			Player:GetMouse().Icon = SHIFTLOCK_ICON
		elseif lastMouseLocked then
			setMouseLockOffset(Vector3.zero)
			Player:GetMouse().Icon = ""
		end

		lastMouseLocked = mouseLocked
	end)
end

return CameraShiftlock
