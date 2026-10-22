--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local EffectsBase = require(ReplicatedStorage.Modules:WaitForChild("EffectsBase"))
local Sounds = require(ReplicatedStorage.Modules:WaitForChild("Sounds"))

--// Variables \\--

local EmitModule = EffectsBase.EmitModule
local FLOOR_DISTANCE = 30
local MAX_PARTICLE_LIFETIME = 1
local SOUND_LIFETIME = 4
local CHECK_INTERVAL = 0.1

local function createCappedTemplate(template: Instance): Instance
	local copy = template:Clone()

	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant.Lifetime.Max > MAX_PARTICLE_LIFETIME then
			local scale = MAX_PARTICLE_LIFETIME / descendant.Lifetime.Max

			descendant.Lifetime = NumberRange.new(descendant.Lifetime.Min * scale, MAX_PARTICLE_LIFETIME)
		end
	end

	return copy
end

local cutTemplate = createCappedTemplate(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("Cut"))


--// Functions \\--

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

local function playSound(soundName: string, parent: Instance)
	local sound = Sounds.GetSound("SFX", soundName, "Moves.Cut")

	if sound then
		sound.Parent = parent
		sound:Play()
		DebrisService:AddItem(sound, SOUND_LIFETIME)
	end
end

local function getCutFrame(root: BasePart, character: Instance?, distance: number): CFrame
	local rotation = root.CFrame.Rotation
	local frame = CFrame.new(root.Position) * rotation * CFrame.new(0, 0, -distance)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character, workspace.Effects, workspace.Debris}

	local result = workspace:Raycast(frame.Position, Vector3.new(0, -FLOOR_DISTANCE, 0), rayParams)

	if result then
		return CFrame.new(result.Position) * rotation
	end

	return frame
end

local function playCut(root: BasePart, character: Instance?, distance: number, duration: number)
	local cut = cutTemplate:Clone()
	cut.CFrame = getCutFrame(root, character, distance)
	cut.Anchored = false
	cut.Massless = true
	cut.CanCollide = false
	cut.Parent = workspace.Effects

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = cut
	weld.Parent = cut

	EmitModule.EmitFromModel(cut, true)
	EmitModule.EnableVFX(cut)

	local elapsed = 0

	while elapsed < duration and canEmit(character, root) do
		task.wait(CHECK_INTERVAL)
		elapsed += CHECK_INTERVAL
	end

	EmitModule.RemoveVFX(cut)
end

return function(data)
	local root = data.root

	if typeof(root) ~= "Instance" or not root:IsA("BasePart") then
		return
	end

	task.delay(data.delay or 0, function()
		if canEmit(data.char, root) then
			playSound("Slash", root)
			playSound("Impact", root)
		end
	end)

	task.wait(data.start or 0)

	if canEmit(data.char, root) then
		playCut(root, data.char, data.distance or 0, data.duration or 0)
	end
end
