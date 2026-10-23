--// Setup \\--

local Client = require(script.Parent.Parent)
local Movement = require(script.Parent.Parent.Movement)

--// Jump / WallClimb & Vault Input \\--

local JumpInput = {}

-- ContextActionService's dispatcher already selects InputBegan from the action
-- state. InputObject can be nil for some input sources, so do not inspect its
-- UserInputState here.
JumpInput.InputBegan = function(_Input: InputObject?, _Client: any)
	local Character: Model? = Client.Character
	local Humanoid: Humanoid? = Client.Humanoid

	if not Character or not Humanoid or Humanoid.Health <= 0 then
		return
	end

	Movement.TryWallClimbOrVault()
end

JumpInput.InputEnded = function(_Input: InputObject?, _Client: any)
end

JumpInput.InputChanged = function(_Input: InputObject?, _Client: any)
end

return JumpInput
