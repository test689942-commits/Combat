--// Setup \\--

local Client = require(script.Parent.Parent)
local Movement = require(script.Parent.Parent.Movement)

--// Slide Input \\--

local SlideInput = {}

SlideInput.InputBegan = function(_Input: InputObject?, _Client: any)
	local Character: Model? = Client.Character
	if not Character then
		return
	end

	if #Client.Actions > 0 or #Client.Stuns > 0 or Client.InAir or Client.Dashing then
		return
	end

	Movement.Slide()
end

SlideInput.InputEnded = function(_Input: InputObject?, _Client: any)
end

SlideInput.InputChanged = function(_Input: InputObject?, _Client: any)
end

return SlideInput
