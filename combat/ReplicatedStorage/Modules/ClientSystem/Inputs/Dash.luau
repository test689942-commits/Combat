--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--// Modules \\--

local MovesModule = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Moves")
local DashInfo = require(MovesModule).Dash
local DashMove = require(MovesModule:WaitForChild("Dash"))

--// Functions \\--

local function getDirection(): string
	for _, directionInfo in DashInfo.Directions do
		if UserInputService:IsKeyDown(directionInfo.ModifierKey) then
			return directionInfo.Direction
		end
	end

	return DashInfo.DefaultDirection
end

--// Input \\--

local InputModule = {}

InputModule.InputBegan = function(_, Client)
	if not Client.Character then
		return
	end

	DashMove.Activate(getDirection())
end

InputModule.InputEnded = function()
end

InputModule.InputChanged = function()
end

return InputModule
