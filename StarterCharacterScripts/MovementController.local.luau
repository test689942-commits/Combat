--// Services \\--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local ClientSystemModule = ReplicatedStorage.Modules.ClientSystem
local Client = require(ClientSystemModule)

Client.Modules.Movement = require(ClientSystemModule.Movement)
Client.Modules.Inputs = require(ClientSystemModule.Inputs)

--// Variables \\--

local player = Players.LocalPlayer
local characterConnections = {}

local AIRBORNE_STATES = {
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Jumping] = true,
}

--// Functions \\--

local function disconnectCharacterConnections()
	for _, connection in characterConnections do
		connection:Disconnect()
	end

	table.clear(characterConnections)
end

local function resetMovementState(root: BasePart)
	Client.InAir = false
	Client.FallHeight = root.Position.Y
	Client.Dashing = false
end

local function onStateChanged(_, newState: Enum.HumanoidStateType)
	local wasInAir = Client.InAir
	Client.InAir = AIRBORNE_STATES[newState] == true

	if newState == Enum.HumanoidStateType.Landed and wasInAir then
		Client.Modules.Movement.Landed()
	end
end

local function onHeartbeat()
	if not Client.Character or not Client.Root then
		return
	end

	if Client.InAir then
		Client.FallHeight = math.max(Client.FallHeight, Client.Root.Position.Y)
	else
		Client.FallHeight = Client.Root.Position.Y
	end
end

local function onCharacterAdded(character: Model)
	disconnectCharacterConnections()

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = humanoid:WaitForChild("Animator") :: Animator

	Client.Character = character
	Client.Humanoid = humanoid
	Client.Root = root
	Client.Animator = animator

	resetMovementState(root)

	table.insert(characterConnections, humanoid.StateChanged:Connect(onStateChanged))

	table.insert(characterConnections, humanoid.Died:Connect(function()
		resetMovementState(root)
	end))

	table.insert(characterConnections, RunService.Heartbeat:Connect(onHeartbeat))
end

--// Setup \\--

if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)
