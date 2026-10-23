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

local function getDirection(Client): (string, boolean)
	local forward = keyDown(Enum.KeyCode.W, Enum.KeyCode.Up)
	local backward = keyDown(Enum.KeyCode.S, Enum.KeyCode.Down)
	local left = keyDown(Enum.KeyCode.A, Enum.KeyCode.Left)
	local right = keyDown(Enum.KeyCode.D, Enum.KeyCode.Right)

	-- Any side input takes precedence on a diagonal and never counts as straight forward.
	if left then
		return "Left", false
	elseif right then
		return "Right", false
	elseif forward and not backward then
		return "Forward", true
	elseif backward and not forward then
		return "Back", false
	elseif forward or backward then
		return if forward then "Forward" else "Back", false
	end

	local humanoid: Humanoid? = Client.Humanoid
	local root: BasePart? = Client.Root
	if not humanoid or not root then
		return DashInfo.DefaultDirection, false
	end

	local moveDirection = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if moveDirection.Magnitude < 0.05 then
		return DashInfo.DefaultDirection, false
	end

	local localDirection = root.CFrame:VectorToObjectSpace(moveDirection.Unit)
	if math.abs(localDirection.X) >= math.abs(localDirection.Z) then
		return if localDirection.X < 0 then "Left" else "Right", false
	end

	if localDirection.Z < 0 then
		local straightForward = math.abs(localDirection.X) < 0.1 and localDirection.Z <= -0.985
		return "Forward", straightForward
	end

	return "Back", false
end

--// Input \\--

local InputModule = {}

InputModule.InputBegan = function(_, Client)
	if not Client.Character then
		return
	end

	local direction, straightForward = getDirection(Client)
	DashMove.Activate(direction, straightForward)
end

InputModule.InputEnded = function()
end

InputModule.InputChanged = function()
end

return InputModule
