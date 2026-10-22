--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local movesModule = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Moves")
local MoveEffects = require(movesModule:WaitForChild("Effects"))

--// Variables \\--

local player = Players.LocalPlayer
local effectsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effects")

local MAX_EFFECT_DISTANCE = 250

local loadedVisuals = {}

--// Functions \\--

local function getVisual(effectName: string)
	local handler = MoveEffects[effectName]

	if type(handler) == "function" then
		return handler
	end

	if loadedVisuals[effectName] then
		return loadedVisuals[effectName]
	end

	local moveModule = movesModule:FindFirstChild(effectName)
	local visualModule = moveModule and moveModule:FindFirstChild("Effect")

	if not visualModule or not visualModule:IsA("ModuleScript") then
		return nil
	end

	local success, visual = pcall(require, visualModule)

	if not success then
		warn("Effect failed to load (" .. effectName .. "): " .. tostring(visual))
		return nil
	end

	loadedVisuals[effectName] = visual

	return visual
end

local function isInRange(data): boolean
	local localRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	if not localRoot or typeof(data) ~= "table" or typeof(data.root) ~= "Instance" then
		return true
	end

	return (data.root.Position - localRoot.Position).Magnitude <= MAX_EFFECT_DISTANCE
end

local function onEffect(effectName: any, data: any)
	if typeof(effectName) ~= "string" or not isInRange(data) then
		return
	end

	local visual = getVisual(effectName)

	if not visual then
		return
	end

	task.spawn(function()
		local success, errorMessage = pcall(visual, data)

		if not success then
			warn("Effect errored (" .. effectName .. "): " .. tostring(errorMessage))
		end
	end)
end

--// Events \\--

effectsRemote.OnClientEvent:Connect(onEffect)
