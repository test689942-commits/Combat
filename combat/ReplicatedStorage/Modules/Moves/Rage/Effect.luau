--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local EffectsBase = require(ReplicatedStorage.Modules:WaitForChild("EffectsBase"))
local Sounds = require(ReplicatedStorage.Modules:WaitForChild("Sounds"))
local Info = require(script.Parent.Parent).Rage

--// Variables \\--

local EmitModule = EffectsBase.EmitModule
local screamTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild(Info.EffectName)

local SOUND_LIFETIME = 6

--// Functions \\--

local function playSound(soundName: string, parent: Instance)
	local sound = Sounds.GetSound("SFX", soundName, "Moves.Rage")

	if sound then
		sound.Parent = parent
		sound:Play()
		DebrisService:AddItem(sound, SOUND_LIFETIME)
	end
end

local function canEmit(character: Instance?, root: Instance): boolean
	if not root.Parent then
		return false
	end

	if typeof(character) ~= "Instance" then
		return true
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return character:FindFirstChild("Stun") == nil
end

local function emitScream(root: BasePart)
	local screamAttachment = screamTemplate:Clone()
	screamAttachment.CFrame = CFrame.new()
	screamAttachment.Parent = root

	EmitModule.EmitAndRemove(screamAttachment, nil, {dontClone = true, noAutoSmoke = true})
end

return function(data)
	local root = data.root

	if typeof(root) ~= "Instance" or not root:IsA("BasePart") then
		return
	end

	playSound("Windup", root)

	task.wait(data.delay or 0)

	for pulse = 1, Info.EffectPulses do
		if not canEmit(data.char, root) then
			break
		end

		emitScream(root)

		if pulse == 1 then
			playSound("Scream", root)
		end

		if pulse < Info.EffectPulses then
			task.wait(Info.EffectInterval)
		end
	end
end
