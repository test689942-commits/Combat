--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local Moves = require(ReplicatedStorage.Modules.Moves)
local Weapons = require(ReplicatedStorage.Modules.Weapons)

--// Variables \\--

local activeRemote = ReplicatedStorage.Remotes.Active
local phaseRemote = ReplicatedStorage.Remotes:WaitForChild("MovePhase")
local movesModule = ReplicatedStorage.Modules.Moves

local COOLDOWN_TOLERANCE = 0.3

local cooldowns = {}
local loadedMoves = {}

--// Functions \\--

local function getMove(moveName: string)
	if loadedMoves[moveName] then
		return loadedMoves[moveName]
	end

	local moveModule = movesModule:FindFirstChild(moveName)
	local serverModule = moveModule and moveModule:FindFirstChild("Server")

	if not serverModule or not serverModule:IsA("ModuleScript") then
		return nil
	end

	loadedMoves[moveName] = require(serverModule)

	return loadedMoves[moveName]
end

local function isOnCooldown(player: Player, moveName: string): boolean
	local playerCooldowns = cooldowns[player]

	if not playerCooldowns or not playerCooldowns[moveName] then
		return false
	end

	return os.clock() < playerCooldowns[moveName]
end

local function startCooldown(player: Player, moveName: string, duration: number)
	if not cooldowns[player] then
		cooldowns[player] = {}
	end

	cooldowns[player][moveName] = os.clock() + math.max(0, duration - COOLDOWN_TOLERANCE)
end

local function getCaster(player: Player, moveName: string, settings): Model?
	local character = player.Character

	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end

	if character:FindFirstChild("Stun") or character:FindFirstChild("Blocking") or character:FindFirstChild("DoingMove") then
		return nil
	end

	if not Weapons.HasMove(character, moveName) then
		return nil
	end

	if settings.RequiresFist and not Weapons.IsFists(character) then
		return nil
	end

	return character
end

local function markDoingMove(character: Model, duration: number)
	local marker = Instance.new("BoolValue")
	marker.Name = "DoingMove"
	marker.Parent = character

	DebrisService:AddItem(marker, duration)
end

local function onActivate(player: Player, moveName: any, aimPosition: any)
	if typeof(moveName) ~= "string" then
		return
	end

	local settings = Moves[moveName]
	local move = getMove(moveName)

	if not settings or not move then
		return
	end

	if isOnCooldown(player, moveName) then
		return
	end

	local character = getCaster(player, moveName, settings)

	if not character then
		return
	end

	if typeof(aimPosition) ~= "Vector3" then
		aimPosition = nil
	end

	startCooldown(player, moveName, settings.Cooldown)
	markDoingMove(character, settings.LockDuration)

	local success, errorMessage = pcall(move.Activate, player, character, settings, aimPosition)

	if not success then
		warn("Move failed (" .. moveName .. "): " .. tostring(errorMessage))
	end
end

local function onPhase(player: Player, moveName: any, phaseName: any)
	if typeof(moveName) ~= "string" or typeof(phaseName) ~= "string" then
		return
	end

	local settings = Moves[moveName]
	local move = getMove(moveName)
	local character = player.Character

	if not settings or not move or not character or typeof(move.Phase) ~= "function" then
		return
	end

	local success, errorMessage = pcall(move.Phase, player, character, settings, phaseName)

	if not success then
		warn("Move phase failed (" .. moveName .. "): " .. tostring(errorMessage))
	end
end

--// Events \\--

activeRemote.OnServerEvent:Connect(onActivate)
phaseRemote.OnServerEvent:Connect(onPhase)

Players.PlayerRemoving:Connect(function(player: Player)
	cooldowns[player] = nil
end)
