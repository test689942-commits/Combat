--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local Sounds = require(ReplicatedStorage.Modules:WaitForChild("Sounds"))

--// Variables \\--

local effectsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects")

local DAGGER_SLASH_NAME = "Dagger Slash"
local SLASH_MOVE_NAME = "Slash Move"
local ARM_EFFECT_NAME = "Idk"
local RIGHT_ARM_NAME = "Right Arm"

local SOUND_LIFETIME = 4
local DEFAULT_CLEANUP_DELAY = 2

local activeEffects = setmetatable({}, {__mode = "k"})

--// Helpers \\--

local function playSound(soundName: string, parent: Instance?)
	if not parent then
		return
	end

	local sound = Sounds.GetSound("SFX", soundName, "Moves.DaggerDance")

	if sound then
		sound.Parent = parent
		sound:Play()
		DebrisService:AddItem(sound, SOUND_LIFETIME)
	end
end

local function findEffectTemplate(name: string): Instance?
	return effectsFolder:FindFirstChild(name) or effectsFolder:FindFirstChild(name, true)
end

local function setEffectsEnabled(container: Instance?, enabled: boolean)
	if not container then
		return
	end

	for _, effect in ipairs(container:GetDescendants()) do
		if effect:IsA("ParticleEmitter") or effect:IsA("Trail") or effect:IsA("Beam") then
			effect.Enabled = enabled
		end
	end
end

local function emitParticles(container: Instance): number
	local maxLifetime = 1

	for _, particles in pairs(container:GetDescendants()) do
		if particles:IsA("ParticleEmitter") then
			particles:Emit(particles:GetAttribute("EmitCount") or 1)

			if particles.Lifetime.Max > maxLifetime then
				maxLifetime = particles.Lifetime.Max
			end
		end
	end

	return maxLifetime
end

local function attachEffectToPart(template: Instance, targetPart: BasePart, parent: Instance): Instance
	local clone = template:Clone()

	if clone:IsA("BasePart") then
		local templateRotation = template.CFrame - template.CFrame.Position

		clone.CFrame = targetPart.CFrame * templateRotation
		clone.Anchored = false
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Massless = true
		clone.Parent = parent

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = targetPart
		weld.Part1 = clone
		weld.Parent = clone
	elseif clone:IsA("Model") then
		local pivot = template:GetPivot()
		local templateRotation = pivot - pivot.Position

		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
			end
		end

		clone:PivotTo(targetPart.CFrame * templateRotation)
		clone.Parent = parent

		local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)

		if primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = targetPart
			weld.Part1 = primary
			weld.Parent = primary
		end
	else
		clone.Parent = targetPart
	end

	return clone
end

local function emitDaggerSlash(character: Model, root: BasePart)
	local template = findEffectTemplate(DAGGER_SLASH_NAME)

	playSound("Slash", root)

	if not template then
		return
	end

	local effectsParent = workspace:FindFirstChild("Effects") or workspace
	local slashEffect = attachEffectToPart(template, root, effectsParent)
	local lifetime = emitParticles(slashEffect)

	DebrisService:AddItem(slashEffect, lifetime + 0.5)
end

local function enableSlashMove(character: Model, root: BasePart)
	local state = activeEffects[character]

	if not state then
		state = {}
		activeEffects[character] = state
	end

	local rightArm = character:FindFirstChild(RIGHT_ARM_NAME)
	local pathsToEnable = {}

	if rightArm and rightArm:IsA("BasePart") then
		local armEffect = state.armEffect

		if not armEffect or not armEffect.Parent then
			local existing = rightArm:FindFirstChild(ARM_EFFECT_NAME)

			if existing then
				armEffect = existing
				state.armOwned = false
			else
				local armTemplate = findEffectTemplate(ARM_EFFECT_NAME)

				if armTemplate then
					armEffect = attachEffectToPart(armTemplate, rightArm, rightArm)
					state.armOwned = true
				end
			end

			state.armEffect = armEffect
		end

		if armEffect then
			table.insert(pathsToEnable, armEffect)
		end
	end

	local slashMoveEffect = state.slashMoveEffect

	if not slashMoveEffect or not slashMoveEffect.Parent then
		local slashMoveTemplate = findEffectTemplate(SLASH_MOVE_NAME)

		if slashMoveTemplate then
			local effectsParent = workspace:FindFirstChild("Effects") or workspace

			slashMoveEffect = attachEffectToPart(slashMoveTemplate, root, effectsParent)
			state.slashMoveEffect = slashMoveEffect
		end
	end

	if slashMoveEffect then
		table.insert(pathsToEnable, slashMoveEffect)
	end

	for _, path in ipairs(pathsToEnable) do
		setEffectsEnabled(path, true)
	end

	playSound("Slash", root)
end

local function disableSlashMove(character: Model)
	local state = activeEffects[character]
	local rightArm = character:FindFirstChild(RIGHT_ARM_NAME)

	local armEffect = (state and state.armEffect) or (rightArm and rightArm:FindFirstChild(ARM_EFFECT_NAME))
	local slashMoveEffect = state and state.slashMoveEffect

	local pathsToDisable = {}

	if armEffect then
		table.insert(pathsToDisable, armEffect)
	end

	if slashMoveEffect then
		table.insert(pathsToDisable, slashMoveEffect)
	end

	for _, path in ipairs(pathsToDisable) do
		setEffectsEnabled(path, false)
	end

	if state then
		if state.armOwned and armEffect and armEffect.Parent then
			DebrisService:AddItem(armEffect, DEFAULT_CLEANUP_DELAY)
		end

		if slashMoveEffect and slashMoveEffect.Parent then
			DebrisService:AddItem(slashMoveEffect, DEFAULT_CLEANUP_DELAY)
		end

		activeEffects[character] = nil
	end
end

--// Public \\--

return function(data)
	local character = data.char
	local root = data.root
	local phase = data.phase

	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	if not root then
		root = character:FindFirstChild("HumanoidRootPart")
	end

	if phase == DAGGER_SLASH_NAME then
		if root and root:IsA("BasePart") then
			emitDaggerSlash(character, root)
		end
	elseif phase == SLASH_MOVE_NAME then
		if root and root:IsA("BasePart") then
			enableSlashMove(character, root)
		end
	elseif phase == "End" then
		disableSlashMove(character)
	end
end
