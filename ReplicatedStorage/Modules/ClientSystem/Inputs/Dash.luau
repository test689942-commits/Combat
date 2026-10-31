--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--// Modules \\--

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MovesModule = Modules:WaitForChild("Moves")
local DashInfo = require(MovesModule).Dash
local DashMove = require(MovesModule:WaitForChild("Dash"))

--// Functions \\--

local function keyDown(primary: Enum.KeyCode, alternate: Enum.KeyCode): boolean
	return UserInputService:IsKeyDown(primary) or UserInputService:IsKeyDown(alternate)
end

local function getDirection(Client): string
	local forward = keyDown(Enum.KeyCode.W, Enum.KeyCode.Up)
	local backward = keyDown(Enum.KeyCode.S, Enum.KeyCode.Down)
	local left = keyDown(Enum.KeyCode.A, Enum.KeyCode.Left)
	local right = keyDown(Enum.KeyCode.D, Enum.KeyCode.Right)

	-- On diagonals, choose the lateral dash direction before a forward/back dash.
	if left then
		return "Left"
	elseif right then
		return "Right"
	elseif forward and not backward then
		return "Forward"
	elseif backward and not forward then
		return "Back"
	elseif forward or backward then
		return if forward then "Forward" else "Back"
	end

	local humanoid: Humanoid? = Client.Humanoid
	local root: BasePart? = Client.Root
	if not humanoid or not root then
		return DashInfo.DefaultDirection
	end

	local moveDirection = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if moveDirection.Magnitude < 0.05 then
		return DashInfo.DefaultDirection
	end

	local localDirection = root.CFrame:VectorToObjectSpace(moveDirection.Unit)
	if math.abs(localDirection.X) >= math.abs(localDirection.Z) then
		return if localDirection.X < 0 then "Left" else "Right"
	end

	return if localDirection.Z < 0 then "Forward" else "Back"
end

--// Input \\--

local InputModule = {}

InputModule.InputBegan = function(_, Client)
	if not Client.Character then
		return
	end

	DashMove.Activate(getDirection(Client))
end

InputModule.InputEnded = function()
end

InputModule.InputChanged = function()
end

return InputModule
