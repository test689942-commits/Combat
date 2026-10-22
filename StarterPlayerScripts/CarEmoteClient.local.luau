--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--// Variables \\--

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("CarEmote")
local toggleRemote = remotes:WaitForChild("ToggleCar")
local steerRemote = remotes:WaitForChild("Steer")
local rideStateRemote = remotes:WaitForChild("RideState")

local TOGGLE_KEY = Enum.KeyCode.C

local isRiding = false
local steerDirection = 0
local leftHeld = false
local rightHeld = false

--// Animation Control \\--

local function getHumanoid()
	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function stopAllAnimations()
	local humanoid = getHumanoid()

	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		return
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0.1)
	end
end

local function setDefaultAnimationsEnabled(enabled)
	local character = player.Character

	if not character then
		return
	end

	local animateScript = character:FindFirstChild("Animate")

	if animateScript then
		animateScript.Enabled = enabled
	end

	if not enabled then
		stopAllAnimations()
	end
end

--// Steering \\--

local function sendSteer(newDirection)
	if newDirection == steerDirection then
		return
	end

	steerDirection = newDirection

	if isRiding then
		steerRemote:FireServer(steerDirection)
	end
end

local function refreshKeyboardSteer()
	local newDirection = 0

	if rightHeld then
		newDirection += 1
	end

	if leftHeld then
		newDirection -= 1
	end

	sendSteer(newDirection)
end

--// Ride State \\--

local function onRideStateChanged(riding)
	isRiding = riding
	steerDirection = 0

	if riding then
		setDefaultAnimationsEnabled(false)
		refreshKeyboardSteer()
		return
	end

	setDefaultAnimationsEnabled(true)
end

local function onCharacterAdded()
	isRiding = false
	steerDirection = 0
end

--// Input \\--

local function onInputBegan(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == TOGGLE_KEY then
		toggleRemote:FireServer()
		return
	end

	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		leftHeld = true
		refreshKeyboardSteer()
		return
	end

	if input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		rightHeld = true
		refreshKeyboardSteer()
	end
end

local function onInputEnded(input)
	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		leftHeld = false
		refreshKeyboardSteer()
		return
	end

	if input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		rightHeld = false
		refreshKeyboardSteer()
	end
end

--// Events \\--

rideStateRemote.OnClientEvent:Connect(onRideStateChanged)
player.CharacterAdded:Connect(onCharacterAdded)

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)