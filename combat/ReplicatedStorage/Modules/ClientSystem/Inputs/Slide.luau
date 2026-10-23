--// Setup \\--

local Client = require(script.Parent.Parent)
local Movement = require(script.Parent.Parent.Movement)

--// Slide Input \\--

return function(Input: InputObject, Key: string)
	if Input.UserInputState ~= Enum.UserInputState.Begin then
		return
	end

	local Character: Model = Client.Character
	if not Character then
		return
	end

	if #Client.Actions > 0 or #Client.Stuns > 0 or Client.InAir or Client.Dashing then
		return
	end

	Movement.Slide()
end
