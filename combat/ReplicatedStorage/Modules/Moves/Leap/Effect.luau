--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

--// Modules \\--

local EffectsBase = require(ReplicatedStorage.Modules:WaitForChild("EffectsBase"))
local Sounds = require(ReplicatedStorage.Modules:WaitForChild("Sounds"))

--// Variables \\--

local EmitModule = EffectsBase.EmitModule
local effects = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects")

local FLOOR_DISTANCE = 30
local MAX_PARTICLE_LIFETIME = 1.5
local SLAM_LIFETIME = 2
local DECAL_FADE_TIME = 0.8
local SOUND_LIFETIME = 4

--// Functions \\--

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

local jumpTemplate = createCappedTemplate(effects:WaitForChild("Jump"))
local slamFxTemplate = createCappedTemplate(effects:WaitForChild("SlamFX"))
local slamTemplate = createCappedTemplate(effects:WaitForChild("Slam"))
local trailTemplate = effects:WaitForChild("TrailPart")

local function playSound(soundName: string, parent: Instance)
	local sound = Sounds.GetSound("SFX", soundName, "Moves.Leap")

	if sound then
		sound.Parent = parent
		sound:Play()
		DebrisService:AddItem(sound, SOUND_LIFETIME)
	end
end

local function playTakeoff(root: BasePart)
	playSound("Takeoff", root)
	EmitModule.EmitAndRemove(jumpTemplate, root.CFrame, {maxFloorDist = FLOOR_DISTANCE, noAutoSmoke = true})
end

local function startTrail(root: BasePart): BasePart
	local trail = trailTemplate:Clone()
	trail.CFrame = root.CFrame
	trail.Massless = true
	trail.CanCollide = false
	trail.Parent = workspace.Effects

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = trail
	weld.Parent = trail

	EmitModule.EnableVFX(trail)

	return trail
end

local function fadeDecals(slam: Instance)
	for _, descendant in slam:GetDescendants() do
		if descendant:IsA("Decal") and descendant.Transparency < 1 then
			TweenService:Create(descendant, TweenInfo.new(DECAL_FADE_TIME), {Transparency = 1}):Play()
		end
	end
end

local function playLanding(root: BasePart, target: Vector3)
	playSound("Land", root)

	local slamFx = EmitModule.EmitAndRemove(slamFxTemplate, CFrame.new(target), {maxFloorDist = FLOOR_DISTANCE, noAutoSmoke = true})

	if not slamFx then
		return
	end

	local slam = slamTemplate:Clone()
	slam:PivotTo(CFrame.new(slamFx.Position))
	slam.Parent = workspace.Effects

	EmitModule.EmitFromModel(slam, true)
	fadeDecals(slam)
	DebrisService:AddItem(slam, SLAM_LIFETIME)
end

return function(data)
	local root = data.root

	if typeof(root) ~= "Instance" or not root:IsA("BasePart") or typeof(data.target) ~= "Vector3" then
		return
	end

	playTakeoff(root)

	local trail = startTrail(root)

	task.wait(data.duration or 0)

	EmitModule.RemoveVFX(trail)
	playLanding(root, data.target)
end
