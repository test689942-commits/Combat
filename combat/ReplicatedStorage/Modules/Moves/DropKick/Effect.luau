--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local EffectsBase = require(ReplicatedStorage.Modules:WaitForChild("EffectsBase"))

--// Variables \\--

local EmitModule = EffectsBase.EmitModule
local effectsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects")

local PHASE_EFFECTS = {
	Startup = {
		Template = "Startup",
		AttachParts = {"Right Leg"},
	},
	Swing = {
		Template = "Swing",
		AttachParts = {"Torso"},
	},
}

--// Functions \\--

local function findAttachPart(character: Model, partNames): BasePart?
	for _, partName in partNames do
		local part = character:FindFirstChild(partName)

		if part and part:IsA("BasePart") then
			return part
		end
	end

	return nil
end

return function(data)
	local character = data.char
	local phaseEffect = PHASE_EFFECTS[data.phase]

	if typeof(character) ~= "Instance" or not phaseEffect then
		return
	end

	local attachPart = findAttachPart(character, phaseEffect.AttachParts)
	local template = effectsFolder:FindFirstChild(phaseEffect.Template)

	if not attachPart or not template then
		return
	end

	local effect = template:Clone()
	effect.Parent = attachPart

	EmitModule.EmitAndRemove(effect, nil, {dontClone = true, noAutoSmoke = true})
end
