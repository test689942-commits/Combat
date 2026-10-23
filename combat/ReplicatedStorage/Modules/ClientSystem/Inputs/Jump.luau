--// Setup \\--

local Client = require(script.Parent.Parent)
local Movement = require(script.Parent.Parent.Movement)

--// Jump / WallClimb & Vault Input \\--

return function(Input: InputObject, Key: string)
	if Input.UserInputState ~= Enum.UserInputState.Begin then
		return
	end

	local Character: Model = Client.Character
	local Humanoid: Humanoid = Client.Humanoid

	if not Character or not Humanoid then
		return
	end

	Movement.TryWallClimbOrVault()
end
