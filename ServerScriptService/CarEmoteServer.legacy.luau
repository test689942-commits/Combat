--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--// Variables \\--

local CarRide = require(ServerScriptService:WaitForChild("CarRide"))

local remotes = ReplicatedStorage:WaitForChild("CarEmote")
local toggleRemote = remotes:WaitForChild("ToggleCar")
local steerRemote = remotes:WaitForChild("Steer")
local rideStateRemote = remotes:WaitForChild("RideState")

local activeRides = {}

--// Functions \\--

local function destroyRide(player)
	local ride = activeRides[player]

	if not ride then
		return
	end

	activeRides[player] = nil
	ride:Destroy()
end

local function startRide(player)
	local character = player.Character

	if not character then
		return
	end

	local ride = CarRide.new(character)

	if not ride then
		return
	end

	activeRides[player] = ride
	rideStateRemote:FireClient(player, true)

	ride:Start()
end

local function stopRide(player, ride)
	ride:Stop()

	if activeRides[player] ~= ride then
		return
	end

	destroyRide(player)
	rideStateRemote:FireClient(player, false)
end

local function onToggle(player)
	local ride = activeRides[player]

	if not ride then
		startRide(player)
		return
	end

	if ride:IsRiding() then
		stopRide(player, ride)
	end
end

local function onSteer(player, direction)
	local ride = activeRides[player]

	if not ride then
		return
	end

	if typeof(direction) ~= "number" or direction ~= direction then
		return
	end

	ride:SetSteer(math.sign(direction))
end

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)

	if not humanoid then
		return
	end

	humanoid.Died:Connect(function()
		destroyRide(player)
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	player.CharacterRemoving:Connect(function()
		destroyRide(player)
	end)
end

--// Events \\--

toggleRemote.OnServerEvent:Connect(onToggle)
steerRemote.OnServerEvent:Connect(onSteer)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(destroyRide)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end