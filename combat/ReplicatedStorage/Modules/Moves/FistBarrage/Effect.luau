--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local EffectsBase = require(ReplicatedStorage.Modules:WaitForChild("EffectsBase"))
local Info = require(script.Parent.Parent).FistBarrage

--// Variables \\--

local EmitModule = EffectsBase.EmitModule
local barrageTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("Barrage")

--// Functions \\--

local function emitPulse(root: BasePart)
	local halfLength = barrageTemplate.Size.Z / 2
	local pulseCFrame = root.CFrame * CFrame.new(0, 0, -(halfLength + Info.EffectOffset))

	EmitModule.EmitAndRemove(barrageTemplate, pulseCFrame, {noAutoSmoke = true})
end

return function(data)
	local root = data.root

	if typeof(root) ~= "Instance" or not root:IsA("BasePart") then
		return
	end

	local pulses = data.pulses or 1
	local interval = data.interval or 0.1

	task.wait(data.delay or 0)

	for pulse = 1, pulses do
		if not root.Parent then
			break
		end

		emitPulse(root)

		if pulse < pulses then
			task.wait(interval)
		end
	end
end
