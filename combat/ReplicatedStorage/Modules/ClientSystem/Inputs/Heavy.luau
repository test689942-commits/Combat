local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatInput = require(ReplicatedStorage.Modules.Moves.Combat:WaitForChild("Input"))

local HeavyInput = {}

HeavyInput.InputBegan = function(_Input: InputObject?, Client: any)
	local Character: Model? = Client.Character

	if Character then
		CombatInput.TryHeavy(Character)
	end
end

HeavyInput.InputEnded = function(_Input: InputObject?, _Client: any)
end

HeavyInput.InputChanged = function(_Input: InputObject?, _Client: any)
end

return HeavyInput
