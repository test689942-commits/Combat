--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--// Modules \\--

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AnimationsModule = require(Modules:WaitForChild("Animations"))
local EffectsBase = require(Modules:WaitForChild("EffectsBase"))
local Sounds = require(Modules:WaitForChild("Sounds"))
local MovesInfo = require(script.Parent)

--// Variables \\--

local EmitModule = EffectsBase.EmitModule

local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
local effectsFolder = assetsFolder:WaitForChild("Effects")

local Effects = {}

--// Effects Folder Organization \\--

local FOLDER_LAYOUT = {
	Combat = {
		"GoUp",
		"Wave",
	},
	Slashes = {
		"M1Swing",
		"M1Floor",
		"M2Swing",
		"M2Floor",
		"M3Swing",
		"M3Slam",
		"M3Floor",
		"M4Swing",
	},
	Fists = {
		"Stab2",
		"Wind1",
		"Wind2",
		"groundslam",
		"Impact",
		"inversRing",
		"Barrage",
	},
	Greatsword = {
		"Scream",
		"RageAura",
		"Jump",
		"SlamFX",
		"Slam",
		"TrailPart",
	},
	Axe = {
		"Thrust",
		"Slashup",
		"SlashUp",
		"SlashLast",
		"Startup",
		"Spin",
		"End",
	},
	Dagger = {
		"Cut",
		"Dagger Slash",
		"Slash Move",
		"Slash Floor",
		"Idk",
	},
	Movement = {
		"Ring",
		"Arm Trail",
		"Back",
		"Forward",
		"Left",
		"Right",
		"SideDust",
		"Trail",
		"TransparentArmTrail",
	},

}

local function normalizeKey(text: string): string
	return string.lower((string.gsub(text, "[%s_]+", "")))
end

local function ensureCategoryFolder(categoryName: string): Folder
	local folder = effectsFolder:FindFirstChild(categoryName)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = categoryName
		folder.Parent = effectsFolder
	end

	return folder
end

function Effects.OrganizeFolder()
	local dashVfx = effectsFolder:FindFirstChild("DashVFX")
	local dashFolder = effectsFolder:FindFirstChild("Dash")

	if dashVfx and not dashFolder then
		dashVfx.Name = "Dash"
	end

	for categoryName, effectNames in pairs(FOLDER_LAYOUT) do
		local categoryFolder = ensureCategoryFolder(categoryName)
		local targetKeys = {}

		for _, effectName in ipairs(effectNames) do
			targetKeys[normalizeKey(effectName)] = true
		end

		for _, child in ipairs(effectsFolder:GetChildren()) do
			if not child:IsA("Folder") and targetKeys[normalizeKey(child.Name)] then
				child.Parent = categoryFolder
			end
		end
	end
end

function Effects.GetCategoryFolder(categoryName: string): Instance?
	if categoryName == "Dash" then
		return effectsFolder:FindFirstChild("Movement") or effectsFolder:FindFirstChild("Dash") or effectsFolder:FindFirstChild("DashVFX")
	end

	return effectsFolder:FindFirstChild(categoryName)
end

function Effects.GetTemplate(categoryName: string?, effectName: string): Instance?
	if categoryName then
		local categoryFolder = Effects.GetCategoryFolder(categoryName)

		if categoryFolder then
			local inCategory = categoryFolder:FindFirstChild(effectName) or categoryFolder:FindFirstChild(effectName, true)

			if inCategory then
				return inCategory
			end
		end
	end

	local direct = effectsFolder:FindFirstChild(effectName) or effectsFolder:FindFirstChild(effectName, true)

	if direct then
		return direct
	end

	local targetKey = normalizeKey(effectName)

	if categoryName then
		local categoryFolder = Effects.GetCategoryFolder(categoryName)

		if categoryFolder then
			for _, descendant in ipairs(categoryFolder:GetDescendants()) do
				if normalizeKey(descendant.Name) == targetKey then
					return descendant
				end
			end
		end
	end

	for _, descendant in ipairs(effectsFolder:GetDescendants()) do
		if normalizeKey(descendant.Name) == targetKey then
			return descendant
		end
	end

	for _, descendant in ipairs(assetsFolder:GetDescendants()) do
		if normalizeKey(descendant.Name) == targetKey then
			return descendant
		end
	end

	warn("[Moves.Effects] Could not find effect template:", categoryName or "Any", effectName)
	return nil
end

Effects.OrganizeFolder()

--// Shared Helpers \\--

local SOUND_LIFETIME = 4

local function playMoveSound(soundName: string, soundPath: string, parent: Instance?, lifetime: number?)
	if not parent then
		return
	end

	local sound = Sounds.GetSound("SFX", soundName, soundPath)

	if sound then
		sound.Parent = parent
		sound:Play()
		DebrisService:AddItem(sound, lifetime or SOUND_LIFETIME)
	end
end

local function canCharacterEmit(character: Instance?, root: Instance): boolean
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

local cappedTemplateCache = {}

local function getCappedTemplate(categoryName: string, effectName: string, maxLifetime: number): Instance?
	local cacheKey = categoryName .. "/" .. effectName .. "/" .. tostring(maxLifetime)

	if cappedTemplateCache[cacheKey] then
		return cappedTemplateCache[cacheKey]
	end

	local template = Effects.GetTemplate(categoryName, effectName)

	if not template then
		return nil
	end

	local copy = template:Clone()

	for _, descendant in ipairs(copy:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") and descendant.Lifetime.Max > maxLifetime then
			local scale = maxLifetime / descendant.Lifetime.Max

			descendant.Lifetime = NumberRange.new(descendant.Lifetime.Min * scale, maxLifetime)
		end
	end

	cappedTemplateCache[cacheKey] = copy
	return copy
end

--// 1. GroundSlam (Fists) \\--

function Effects.GroundSlam(data)
	local root: BasePart = data.root

	if typeof(root) ~= "Instance" or not root:IsA("BasePart") then
		return
	end

	local debrisFolder = workspace:FindFirstChild("Debris") or workspace

	playMoveSound("GroundSlam", "Moves", root, 5)

	local stabTemplate = Effects.GetTemplate("Fists", "Stab2")
	local wind2Template = Effects.GetTemplate("Fists", "Wind2")
	local wind1Template = Effects.GetTemplate("Fists", "Wind1")
	local groundSlamTemplate = Effects.GetTemplate("Fists", "groundslam")
	local impactTemplate = Effects.GetTemplate("Fists", "Impact")
	local ringTemplate = Effects.GetTemplate("Fists", "inversRing")

	local w1 = stabTemplate and stabTemplate:Clone()
	if w1 then
		w1.Parent = debrisFolder
		w1.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
		w1.Mesh.Scale = Vector3.new(1, 0.01, 0.01)

		TweenService:Create(
			w1.Mesh,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{Scale = Vector3.new(0.3, 1, 1)}
		):Play()
	end

	local wind = wind2Template and wind2Template:Clone()
	if wind then
		wind.Parent = debrisFolder
		wind.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
		wind.Mesh.Scale = Vector3.new(2, 0.01, 0.01)

		TweenService:Create(
			wind.Mesh,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{Scale = Vector3.new(0.5, 1, 1)}
		):Play()
		TweenService:Create(
			wind,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{CFrame = wind.CFrame * CFrame.Angles(math.rad(math.random(-90, 90)), 0, 0)}
		):Play()
		TweenService:Create(
			wind.Decal,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{Transparency = 1}
		):Play()
	end

	local wind1 = wind1Template and wind1Template:Clone()
	if wind1 then
		wind1.Parent = debrisFolder
		wind1.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
		wind1.Mesh.Scale = Vector3.new(2, 0.01, 0.01)

		TweenService:Create(
			wind1.Mesh,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{Scale = Vector3.new(0.5, 1.7, 1.7)}
		):Play()
		TweenService:Create(
			wind1.Decal,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{Transparency = 1}
		):Play()
	end

	task.wait(0.1)

	if w1 then
		TweenService:Create(
			w1.Decal,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{Transparency = 1}
		):Play()
		DebrisService:AddItem(w1, 0.5)
	end

	local floorResult = nil
	if groundSlamTemplate then
		_, floorResult = EmitModule.EmitAndRemove(groundSlamTemplate, root.CFrame, {maxFloorDist = 20})
	end

	if impactTemplate then
		local impactPosition = if floorResult then floorResult.Position + Vector3.new(0, 1.5, 0) else root.Position
		EmitModule.EmitAndRemove(impactTemplate, CFrame.new(impactPosition), {noAutoSmoke = true})
	end

	if ringTemplate then
		local ring = ringTemplate:Clone()
		ring.Parent = debrisFolder
		ring.CFrame = root.CFrame * CFrame.new(0, -2, 0)
		EffectsBase.TM.Clasic_tween(ring, {
			size = Vector3.new(35, 0, 35),
			startSize = Vector3.new(5, 50, 5),
			sizeTim = 0.5 / 1.5,
			tim = 0.5,
			EasingStyle = Enum.EasingStyle.Exponential,
			EasingDirection = Enum.EasingDirection.Out,
			trans = 1,
			transTim = 0.5,
			startTrans = 0.5,
		})
		ring.Material = Enum.Material.Neon
		DebrisService:AddItem(ring, 0.5 * 1.5)
	end

	if wind then
		TweenService:Create(
			wind.Mesh,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{Scale = Vector3.new(0, 1.3, 1.3)}
		):Play()
		DebrisService:AddItem(wind, 1)
	end

	if wind1 then
		TweenService:Create(
			wind1.Mesh,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{Scale = Vector3.new(0, 1.7, 1.7)}
		):Play()
		DebrisService:AddItem(wind1, 1)
	end
end

--// 2. FistBarrage (Fists) \\--

function Effects.FistBarrage(data)
	local root = data.root

	if typeof(root) ~= "Instance" or not root:IsA("BasePart") then
		return
	end

	local barrageTemplate = Effects.GetTemplate("Fists", "Barrage")

	if not barrageTemplate or not barrageTemplate:IsA("BasePart") then
		return
	end

	local info = MovesInfo.FistBarrage
	local pulses = data.pulses or 1
	local interval = data.interval or 0.1

	task.wait(data.delay or 0)

	for pulse = 1, pulses do
		if not canCharacterEmit(data.char, root) then
			break
		end

		local halfLength = barrageTemplate.Size.Z / 2
		local pulseCFrame = root.CFrame * CFrame.new(0, 0, -(halfLength + info.EffectOffset))

		EmitModule.EmitAndRemove(barrageTemplate, pulseCFrame, {noAutoSmoke = true})

		if pulse < pulses then
			task.wait(interval)
		end
	end
end

--// 3. Rage (Greatsword) \\--

local RAGE_SOUND_LIFETIME = 6

function Effects.Rage(data)
	local root = data.root

	if typeof(root) ~= "Instance" or not root:IsA("BasePart") then
		return
	end

	local info = MovesInfo.Rage
	local screamTemplate = Effects.GetTemplate("Greatsword", info.EffectName)

	playMoveSound("Windup", "Moves.Rage", root, RAGE_SOUND_LIFETIME)

	task.wait(data.delay or 0)

	for pulse = 1, info.EffectPulses do
		if not canCharacterEmit(data.char, root) then
			break
		end

		if screamTemplate then
			local screamAttachment = screamTemplate:Clone()
			screamAttachment.CFrame = CFrame.new()
			screamAttachment.Parent = root

			EmitModule.EmitAndRemove(screamAttachment, nil, {dontClone = true, noAutoSmoke = true})
		end

		if pulse == 1 then
			playMoveSound("Scream", "Moves.Rage", root, RAGE_SOUND_LIFETIME)
		end

		if pulse < info.EffectPulses then
			task.wait(info.EffectInterval)
		end
	end
end

--// 5. Leap (Greatsword) \\--

local LEAP_FLOOR_DISTANCE = 30
local LEAP_MAX_PARTICLE_LIFETIME = 1.5
local LEAP_SLAM_LIFETIME = 2
local LEAP_DECAL_FADE_TIME = 0.8

local function fadeDecals(slam: Instance)
	for _, descendant in ipairs(slam:GetDescendants()) do
		if descendant:IsA("Decal") and descendant.Transparency < 1 then
			TweenService:Create(descendant, TweenInfo.new(LEAP_DECAL_FADE_TIME), {Transparency = 1}):Play()
		end
	end
end

function Effects.Leap(data)
	local root = data.root

	if typeof(root) ~= "Instance" or not root:IsA("BasePart") or typeof(data.target) ~= "Vector3" then
		return
	end

	local jumpTemplate = getCappedTemplate("Greatsword", "Jump", LEAP_MAX_PARTICLE_LIFETIME)
	local slamFxTemplate = getCappedTemplate("Greatsword", "SlamFX", LEAP_MAX_PARTICLE_LIFETIME)
	local slamTemplate = getCappedTemplate("Greatsword", "Slam", LEAP_MAX_PARTICLE_LIFETIME)
	local trailTemplate = Effects.GetTemplate("Greatsword", "TrailPart")

	playMoveSound("Takeoff", "Moves.Leap", root)

	if jumpTemplate then
		EmitModule.EmitAndRemove(jumpTemplate, root.CFrame, {maxFloorDist = LEAP_FLOOR_DISTANCE, noAutoSmoke = true})
	end

	local trail = nil
	if trailTemplate and trailTemplate:IsA("BasePart") then
		trail = trailTemplate:Clone()
		trail.CFrame = root.CFrame
		trail.Massless = true
		trail.CanCollide = false
		trail.Parent = workspace:FindFirstChild("Effects") or workspace

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = trail
		weld.Parent = trail

		EmitModule.EnableVFX(trail)
	end

	local duration = data.duration or 0
	local elapsed = 0

	while elapsed < duration and canCharacterEmit(data.char, root) do
		elapsed += RunService.Heartbeat:Wait()
	end

	if trail then
		EmitModule.RemoveVFX(trail)
	end

	if not canCharacterEmit(data.char, root) then
		return
	end

	playMoveSound("Land", "Moves.Leap", root)

	if not slamFxTemplate then
		return
	end

	local slamFx = EmitModule.EmitAndRemove(slamFxTemplate, CFrame.new(data.target), {maxFloorDist = LEAP_FLOOR_DISTANCE, noAutoSmoke = true})

	if not slamFx or not slamTemplate then
		return
	end

	local slam = slamTemplate:Clone()
	slam:PivotTo(CFrame.new(slamFx.Position))
	slam.Parent = workspace:FindFirstChild("Effects") or workspace

	EmitModule.EmitFromModel(slam, true)
	fadeDecals(slam)
	DebrisService:AddItem(slam, LEAP_SLAM_LIFETIME)
end

--// 6. Cut (Dagger) \\--

local CUT_FLOOR_DISTANCE = 30
local CUT_MAX_PARTICLE_LIFETIME = 1
local CUT_CHECK_INTERVAL = 0.1

local function getCutFrame(root: BasePart, character: Instance?, distance: number): CFrame
	local rotation = root.CFrame.Rotation
	local frame = CFrame.new(root.Position) * rotation * CFrame.new(0, 0, -distance)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character, workspace:FindFirstChild("Effects"), workspace:FindFirstChild("Debris")}

	local result = workspace:Raycast(frame.Position, Vector3.new(0, -CUT_FLOOR_DISTANCE, 0), rayParams)

	if result then
		return CFrame.new(result.Position) * rotation
	end

	return frame
end

local function playCutVFX(root: BasePart, character: Instance?, distance: number, duration: number)
	local cutTemplate = getCappedTemplate("Dagger", "Cut", CUT_MAX_PARTICLE_LIFETIME)

	if not cutTemplate or not cutTemplate:IsA("BasePart") then
		return
	end

	local cut = cutTemplate:Clone()
	cut.CFrame = getCutFrame(root, character, distance)
	cut.Anchored = false
	cut.Massless = true
	cut.CanCollide = false
	cut.Parent = workspace:FindFirstChild("Effects") or workspace

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = cut
	weld.Parent = cut

	EmitModule.EmitFromModel(cut, true)
	EmitModule.EnableVFX(cut)

	local elapsed = 0

	while elapsed < duration and canCharacterEmit(character, root) do
		task.wait(CUT_CHECK_INTERVAL)
		elapsed += CUT_CHECK_INTERVAL
	end

	EmitModule.RemoveVFX(cut)
end

function Effects.Cut(data)
	local root = data.root

	if typeof(root) ~= "Instance" or not root:IsA("BasePart") then
		return
	end

	task.delay(data.delay or 0, function()
		if canCharacterEmit(data.char, root) then
			playMoveSound("Slash", "Moves.Cut", root)
			playMoveSound("Impact", "Moves.Cut", root)
		end
	end)

	task.wait(data.start or 0)

	if canCharacterEmit(data.char, root) then
		playCutVFX(root, data.char, data.distance or 0, data.duration or 0)
	end
end

--// 7. DaggerThrow (Dagger) \\--

local EQUIPPED_NAME = "EquippedWeapon"
local THROW_LANDING_LIFETIME = 0.6

local function hideHeldWeapon(character: Instance?, duration: number)
	if typeof(character) ~= "Instance" then
		return
	end

	local weapon = character:FindFirstChild(EQUIPPED_NAME)

	if not weapon then
		return
	end

	local saved = {}

	for _, descendant in ipairs(weapon:GetDescendants()) do
		if descendant:IsA("BasePart") then
			saved[descendant] = descendant.Transparency
			descendant.Transparency = 1
		end
	end

	task.delay(duration, function()
		for part, transparency in pairs(saved) do
			if part.Parent then
				part.Transparency = transparency
			end
		end
	end)
end

local function createThrownDagger(): Model?
	local weaponsFolder = assetsFolder:FindFirstChild("Weapons")
	local daggersFolder = weaponsFolder and weaponsFolder:FindFirstChild("Daggers")
	local daggerTemplate = daggersFolder and daggersFolder:FindFirstChild("Steel Dagger")

	if not daggerTemplate then
		return nil
	end

	local dagger = daggerTemplate:Clone()

	for _, descendant in ipairs(dagger:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	dagger.PrimaryPart = dagger:FindFirstChild("Handle")
	dagger.Parent = workspace:FindFirstChild("Effects") or workspace

	return dagger
end

function Effects.DaggerThrow(data)
	if typeof(data.origin) ~= "Vector3" or typeof(data.direction) ~= "Vector3" then
		return
	end

	local origin = data.origin
	local direction = data.direction
	local distance = data.distance or 0
	local speed = math.max(data.speed or 1, 1)

	hideHeldWeapon(data.char, data.hideTime or 0)

	local dagger = createThrownDagger()

	if not dagger then
		return
	end

	if not dagger.PrimaryPart then
		dagger:Destroy()
		return
	end

	playMoveSound("Throw", "Moves.DaggerThrow", dagger.PrimaryPart)

	local travelled = 0

	while travelled < distance do
		travelled = math.min(travelled + RunService.Heartbeat:Wait() * speed, distance)

		local position = origin + direction * travelled

		dagger:PivotTo(CFrame.lookAt(position, position + direction))
	end

	if data.hit then
		playMoveSound("Hit", "Moves.DaggerThrow", dagger.PrimaryPart)
	end

	DebrisService:AddItem(dagger, THROW_LANDING_LIFETIME)
end

--// 8. DaggerDance (Dagger) \\--

local DAGGER_DANCE_NAME = "DaggerDance"
local DAGGER_SLASH_NAME = "Dagger Slash"
local SLASH_MOVE_NAME = "Slash Move"
local SLASH_FLOOR_NAME = "Slash Floor"
local END_NAME = "End"
local ARM_EFFECT_NAME = "Idk"
local RIGHT_ARM_NAME = "Right Arm"

local SLASH_MOVE_FORWARD_OFFSET = 3
local FLOOR_RAY_DISTANCE = 20
local FLOOR_HEIGHT_OFFSET = 0.05
local FALLBACK_FLOOR_DROP = 3
local DEFAULT_CLEANUP_DELAY = 2
local TRACK_WAIT_TIMEOUT = 1

local MARKER_ALIASES = {
	["Dagger Slash"] = DAGGER_SLASH_NAME,
	["Dagger slash"] = DAGGER_SLASH_NAME,
	["dagger slash"] = DAGGER_SLASH_NAME,
	["DaggerSlash"] = DAGGER_SLASH_NAME,
	["Dagger_Slash"] = DAGGER_SLASH_NAME,
	["Slash Move"] = SLASH_MOVE_NAME,
	["Slash move"] = SLASH_MOVE_NAME,
	["slash move"] = SLASH_MOVE_NAME,
	["SlashMove"] = SLASH_MOVE_NAME,
	["Slash_Move"] = SLASH_MOVE_NAME,
	["End"] = END_NAME,
	["end"] = END_NAME,
	["END"] = END_NAME,
}

local GENERIC_MARKER_NAMES = {"Event", "Marker", "KeyframeMarker", "KeyEvent"}

local activeDanceEffects = setmetatable({}, {__mode = "k"})
local boundDanceTracks = setmetatable({}, {__mode = "k"})

local function normalizeDanceEventName(rawName: any): string?
	if type(rawName) ~= "string" or rawName == "" then
		return nil
	end

	if MARKER_ALIASES[rawName] then
		return MARKER_ALIASES[rawName]
	end

	local key = normalizeKey(rawName)

	if key == "daggerslash" then
		return DAGGER_SLASH_NAME
	elseif key == "slashmove" then
		return SLASH_MOVE_NAME
	elseif key == "end" then
		return END_NAME
	end

	return nil
end

local function getAllObjects(container: Instance): {Instance}
	local objects = container:GetDescendants()
	table.insert(objects, 1, container)
	return objects
end

local function setEffectsEnabled(container: Instance?, enabled: boolean)
	if not container then
		return
	end

	for _, effect in ipairs(getAllObjects(container)) do
		if effect:IsA("ParticleEmitter") or effect:IsA("Trail") or effect:IsA("Beam") then
			effect.Enabled = enabled
		end
	end
end

local function emitParticles(container: Instance): number
	local maxLifetime = 1

	for _, particles in ipairs(getAllObjects(container)) do
		if particles:IsA("ParticleEmitter") then
			local emitCount = particles:GetAttribute("EmitCount") or particles:GetAttribute("Amount") or 1
			local emitDelay = particles:GetAttribute("EmitDelay") or 0

			if particles.Lifetime.Max + emitDelay > maxLifetime then
				maxLifetime = particles.Lifetime.Max + emitDelay
			end

			task.delay(emitDelay, function()
				if particles.Parent then
					particles:Emit(emitCount)
				end
			end)
		end
	end

	return maxLifetime
end

local function collectBaseParts(container: Instance): {BasePart}
	local parts = {}

	if container:IsA("BasePart") then
		table.insert(parts, container)
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function cleanExternalJoints(container: Instance)
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			local part0 = descendant.Part0
			local part1 = descendant.Part1

			local part0Inside = part0 ~= nil and (part0 == container or part0:IsDescendantOf(container))
			local part1Inside = part1 ~= nil and (part1 == container or part1:IsDescendantOf(container))

			if not (part0Inside and part1Inside) then
				descendant:Destroy()
			end
		end
	end
end

local function attachEffectToPart(template: Instance, targetPart: BasePart, parent: Instance, offset: CFrame?): Instance
	local clone = template:Clone()
	local parts = collectBaseParts(clone)

	if #parts > 0 then
		cleanExternalJoints(clone)

		local originCFrame: CFrame
		if clone:IsA("BasePart") then
			originCFrame = clone.CFrame
		elseif clone:IsA("Model") then
			originCFrame = clone:GetPivot()
		else
			originCFrame = parts[1].CFrame
		end

		local originRotation = originCFrame - originCFrame.Position
		local goalOriginCFrame = targetPart.CFrame * (offset or CFrame.identity) * originRotation
		local relativeOffsets = {}

		for _, part in ipairs(parts) do
			relativeOffsets[part] = originCFrame:ToObjectSpace(part.CFrame)
		end

		clone.Parent = parent

		for _, part in ipairs(parts) do
			part.CFrame = goalOriginCFrame * relativeOffsets[part]
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = targetPart
			weld.Part1 = part
			weld.Parent = part
		end

		return clone
	end

	if clone:IsA("Folder") then
		local carrier = Instance.new("Part")
		carrier.Name = clone.Name
		carrier.Size = Vector3.new(0.1, 0.1, 0.1)
		carrier.Transparency = 1
		carrier.CFrame = targetPart.CFrame
		carrier.Anchored = false
		carrier.CanCollide = false
		carrier.CanQuery = false
		carrier.CanTouch = false
		carrier.Massless = true
		carrier.Parent = targetPart

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = targetPart
		weld.Part1 = carrier
		weld.Parent = carrier

		for _, child in ipairs(clone:GetChildren()) do
			child.Parent = carrier
		end

		clone:Destroy()
		return carrier
	end

	clone.Parent = targetPart
	return clone
end

local function emitDaggerSlash(character: Model, root: BasePart)
	local template = Effects.GetTemplate("Dagger", DAGGER_SLASH_NAME)

	playMoveSound("Slash", "Moves.DaggerDance", root)

	if not template then
		return
	end

	local effectsParent = workspace:FindFirstChild("Effects") or workspace
	local slashEffect = attachEffectToPart(template, root, effectsParent)
	local lifetime = emitParticles(slashEffect)

	DebrisService:AddItem(slashEffect, lifetime + 0.5)
end

local function getSlashMoveOffset(): CFrame
	return CFrame.new(0, 0, -SLASH_MOVE_FORWARD_OFFSET)
end

local function getSlashFloorOffset(character: Model, root: BasePart): CFrame
	local forwardPoint = (root.CFrame * getSlashMoveOffset()).Position

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}

	local result = workspace:Raycast(root.Position, Vector3.new(0, -FLOOR_RAY_DISTANCE, 0), rayParams)
	local floorY = root.Position.Y - FALLBACK_FLOOR_DROP

	if result then
		floorY = result.Position.Y + FLOOR_HEIGHT_OFFSET
	end

	local floorPoint = Vector3.new(forwardPoint.X, floorY, forwardPoint.Z)

	return CFrame.new(root.CFrame:PointToObjectSpace(floorPoint))
end

local function enableSlashMove(character: Model, root: BasePart)
	local state = activeDanceEffects[character]

	if not state then
		state = {}
		activeDanceEffects[character] = state
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
				local armTemplate = Effects.GetTemplate("Dagger", ARM_EFFECT_NAME)

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
		local slashMoveTemplate = Effects.GetTemplate("Dagger", SLASH_MOVE_NAME)

		if slashMoveTemplate then
			local effectsParent = workspace:FindFirstChild("Effects") or workspace

			slashMoveEffect = attachEffectToPart(slashMoveTemplate, root, effectsParent, getSlashMoveOffset())
			state.slashMoveEffect = slashMoveEffect
		end
	end

	if slashMoveEffect then
		table.insert(pathsToEnable, slashMoveEffect)
	end

	local slashFloorEffect = state.slashFloorEffect

	if not slashFloorEffect or not slashFloorEffect.Parent then
		local slashFloorTemplate = Effects.GetTemplate("Dagger", SLASH_FLOOR_NAME)

		if slashFloorTemplate then
			local effectsParent = workspace:FindFirstChild("Effects") or workspace

			slashFloorEffect = attachEffectToPart(slashFloorTemplate, root, effectsParent, getSlashFloorOffset(character, root))
			state.slashFloorEffect = slashFloorEffect
		end
	end

	if slashFloorEffect then
		table.insert(pathsToEnable, slashFloorEffect)
	end

	task.defer(function()
		for _, path in ipairs(pathsToEnable) do
			setEffectsEnabled(path, true)
		end
	end)

	playMoveSound("Slash", "Moves.DaggerDance", root)
end

local function disableSlashMove(character: Model)
	local state = activeDanceEffects[character]
	local rightArm = character:FindFirstChild(RIGHT_ARM_NAME)

	local armEffect = (state and state.armEffect) or (rightArm and rightArm:FindFirstChild(ARM_EFFECT_NAME))
	local slashMoveEffect = state and state.slashMoveEffect
	local slashFloorEffect = state and state.slashFloorEffect

	local pathsToDisable = {}

	if armEffect then
		table.insert(pathsToDisable, armEffect)
	end

	if slashMoveEffect then
		table.insert(pathsToDisable, slashMoveEffect)
	end

	if slashFloorEffect then
		table.insert(pathsToDisable, slashFloorEffect)
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

		if slashFloorEffect and slashFloorEffect.Parent then
			DebrisService:AddItem(slashFloorEffect, DEFAULT_CLEANUP_DELAY)
		end

		activeDanceEffects[character] = nil
	end
end

local function handleDaggerDancePhase(character: Model, root: BasePart?, phase: string)
	local resolvedRoot = root or character:FindFirstChild("HumanoidRootPart")

	if phase == DAGGER_SLASH_NAME then
		if resolvedRoot and resolvedRoot:IsA("BasePart") then
			emitDaggerSlash(character, resolvedRoot)
		end
	elseif phase == SLASH_MOVE_NAME then
		if resolvedRoot and resolvedRoot:IsA("BasePart") then
			enableSlashMove(character, resolvedRoot)
		end
	elseif phase == END_NAME then
		disableSlashMove(character)
	end
end

local function isDaggerDanceTrack(track: AnimationTrack, targetAnimId: string?): boolean
	if track.Name == DAGGER_DANCE_NAME then
		return true
	end

	local anim = track.Animation
	if anim then
		if anim.Name == DAGGER_DANCE_NAME then
			return true
		end

		if targetAnimId and anim.AnimationId == targetAnimId then
			return true
		end

		if string.find(anim.AnimationId, "115648844139917", 1, true) ~= nil
			or string.find(anim.AnimationId, "111287464837255", 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function findPlayingDanceTrack(animator: Animator, targetAnimId: string?): AnimationTrack?
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if isDaggerDanceTrack(track, targetAnimId) then
			return track
		end
	end

	return nil
end

local function bindDanceTrackEvents(character: Model, root: BasePart?, track: AnimationTrack, onEvent: ((string) -> ())?)
	if boundDanceTracks[character] == track then
		return
	end

	boundDanceTracks[character] = track

	local connections = {}
	local ended = false

	local function dispatch(rawName: any)
		local eventName = normalizeDanceEventName(rawName)

		if not eventName then
			return
		end

		if eventName == END_NAME then
			if ended then
				return
			end

			ended = true
		end

		handleDaggerDancePhase(character, root, eventName)

		if onEvent then
			onEvent(eventName)
		end
	end

	table.insert(connections, track.KeyframeReached:Connect(function(keyframeName: string)
		dispatch(keyframeName)
	end))

	for aliasName in pairs(MARKER_ALIASES) do
		table.insert(connections, track:GetMarkerReachedSignal(aliasName):Connect(function(param)
			dispatch(aliasName)
			if param and param ~= "" then
				dispatch(param)
			end
		end))
	end

	for _, genericName in ipairs(GENERIC_MARKER_NAMES) do
		table.insert(connections, track:GetMarkerReachedSignal(genericName):Connect(function(param)
			dispatch(param)
		end))
	end

	table.insert(connections, track.Stopped:Once(function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		dispatch(END_NAME)

		if boundDanceTracks[character] == track then
			boundDanceTracks[character] = nil
		end
	end))
end

local function attachToCharacterDanceTrack(character: Model, root: BasePart?, providedTrack: AnimationTrack?, onEvent: ((string) -> ())?)
	if providedTrack then
		bindDanceTrackEvents(character, root, providedTrack, onEvent)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		return
	end

	local targetAnimId = AnimationsModule.GetAnimationId("Moves", DAGGER_DANCE_NAME)
	local existingTrack = findPlayingDanceTrack(animator, targetAnimId)

	if existingTrack then
		bindDanceTrackEvents(character, root, existingTrack, onEvent)
		return
	end

	local connection
	connection = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		if isDaggerDanceTrack(track, targetAnimId) then
			if connection then
				connection:Disconnect()
				connection = nil
			end

			bindDanceTrackEvents(character, root, track, onEvent)
		end
	end)

	task.delay(TRACK_WAIT_TIMEOUT, function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

function Effects.DaggerDance(data)
	if type(data) ~= "table" then
		return
	end

	local character = data.char
	local root = data.root
	local phase = normalizeDanceEventName(data.phase)

	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	if not root then
		root = character:FindFirstChild("HumanoidRootPart")
	end

	if phase then
		handleDaggerDancePhase(character, root, phase)
		return
	end

	attachToCharacterDanceTrack(character, root, data.track, data.onEvent)
end

--// 8 & 9. Axe Moves: Thrust (yayy) & Spin (idk) \\--

local THRUST_MOVE_NAME = "Thrust"
local SPIN_MOVE_NAME = "Spin"

local THRUST_EVENT_ALIASES = {
	["Thrust"] = "Thrust",
	["thrust"] = "Thrust",
	["Slashup"] = "Slashup",
	["SlashUp"] = "Slashup",
	["slashup"] = "Slashup",
	["Slash_Up"] = "Slashup",
	["SlashLast"] = "SlashLast",
	["Slashlast"] = "SlashLast",
	["slashlast"] = "SlashLast",
	["Slash_Last"] = "SlashLast",
}

local SPIN_EVENT_ALIASES = {
	["Startup"] = "Startup",
	["startup"] = "Startup",
	["StartUp"] = "Startup",
	["Thrust"] = "Thrust",
	["thrust"] = "Thrust",
	["Spin"] = "Spin",
	["spin"] = "Spin",
	["End"] = "End",
	["end"] = "End",
	["END"] = "End",
}

local THRUST_SIBLING_HINTS = {"Slashup", "SlashLast"}
local SPIN_SIBLING_HINTS = {"Startup", "Spin", "End"}

local activeSpinEffects = setmetatable({}, {__mode = "k"})
local boundThrustTracks = setmetatable({}, {__mode = "k"})
local boundSpinTracks = setmetatable({}, {__mode = "k"})

local function normalizeThrustEvent(rawName: any): string?
	if type(rawName) ~= "string" or rawName == "" then
		return nil
	end

	if THRUST_EVENT_ALIASES[rawName] then
		return THRUST_EVENT_ALIASES[rawName]
	end

	local key = normalizeKey(rawName)

	if key == "thrust" then
		return "Thrust"
	elseif key == "slashup" then
		return "Slashup"
	elseif key == "slashlast" then
		return "SlashLast"
	end

	return nil
end

local function normalizeSpinEvent(rawName: any): string?
	if type(rawName) ~= "string" or rawName == "" then
		return nil
	end

	if SPIN_EVENT_ALIASES[rawName] then
		return SPIN_EVENT_ALIASES[rawName]
	end

	local key = normalizeKey(rawName)

	if key == "startup" then
		return "Startup"
	elseif key == "thrust" then
		return "Thrust"
	elseif key == "spin" then
		return "Spin"
	elseif key == "end" then
		return "End"
	end

	return nil
end

local function findWeaponHandle(character: Model): BasePart?
	local equipped = character:FindFirstChild(EQUIPPED_NAME)

	if equipped then
		local handle = equipped:FindFirstChild("Handle", true)

		if handle and handle:IsA("BasePart") then
			return handle
		end

		local firstPart = equipped:FindFirstChildWhichIsA("BasePart", true)

		if firstPart then
			return firstPart
		end
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") or (child:IsA("Model") and child.Name ~= "HumanoidRootPart") then
			local handle = child:FindFirstChild("Handle", true)

			if handle and handle:IsA("BasePart") then
				return handle
			end
		end
	end

	local rightArm = character:FindFirstChild(RIGHT_ARM_NAME)

	if rightArm and rightArm:IsA("BasePart") then
		return rightArm
	end

	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getAxeTemplate(effectName: string, siblingHints: {string}?): Instance?
	local targetKey = normalizeKey(effectName)
	local candidates = {}
	local searchContainers = {}

	local axeFolder = Effects.GetCategoryFolder("Axe")
	if axeFolder then
		table.insert(searchContainers, axeFolder)
	end
	table.insert(searchContainers, effectsFolder)

	for _, container in ipairs(searchContainers) do
		local children = container:GetChildren()

		for index, child in ipairs(children) do
			if not child:IsA("Folder") and normalizeKey(child.Name) == targetKey then
				table.insert(candidates, {
					instance = child,
					container = container,
					index = index,
				})
			end
		end
	end

	if #candidates == 1 then
		return candidates[1].instance
	elseif #candidates > 1 and siblingHints then
		local hintKeys = {}

		for _, hint in ipairs(siblingHints) do
			hintKeys[normalizeKey(hint)] = true
		end

		local bestCandidate = candidates[1].instance
		local bestDistance = math.huge

		for _, candidate in ipairs(candidates) do
			local siblings = candidate.container:GetChildren()

			for siblingIndex, sibling in ipairs(siblings) do
				if hintKeys[normalizeKey(sibling.Name)] then
					local distance = math.abs(candidate.index - siblingIndex)

					if distance < bestDistance then
						bestDistance = distance
						bestCandidate = candidate.instance
					end
				end
			end
		end

		return bestCandidate
	end

	return Effects.GetTemplate("Axe", effectName)
end

local function emitAxeAttributes(container: Instance): number
	local maxLifetime = 1

	for _, obj in ipairs(getAllObjects(container)) do
		if obj:IsA("ParticleEmitter") then
			local emitCount = obj:GetAttribute("EmitCount") or obj:GetAttribute("Amount")
			local emitDelay = obj:GetAttribute("EmitDelay") or 0
			local emitDuration = obj:GetAttribute("EmitDuration") or 0

			local totalTime = emitDelay + emitDuration + obj.Lifetime.Max

			if totalTime > maxLifetime then
				maxLifetime = totalTime
			end

			task.delay(emitDelay, function()
				if not obj.Parent then
					return
				end

				if emitDuration and emitDuration > 0 then
					obj.Enabled = true
					task.delay(emitDuration, function()
						if obj.Parent then
							obj.Enabled = false
						end
					end)
				end

				if emitCount and emitCount > 0 then
					obj:Emit(emitCount)
				elseif not emitDuration or emitDuration <= 0 then
					obj:Emit(1)
				end
			end)
		elseif obj:IsA("Trail") or obj:IsA("Beam") then
			local emitDelay = obj:GetAttribute("EmitDelay") or 0
			local emitDuration = obj:GetAttribute("EmitDuration") or 0

			if emitDuration and emitDuration > 0 then
				if emitDelay + emitDuration > maxLifetime then
					maxLifetime = emitDelay + emitDuration
				end

				task.delay(emitDelay, function()
					if obj.Parent then
						obj.Enabled = true
						task.delay(emitDuration, function()
							if obj.Parent then
								obj.Enabled = false
							end
						end)
					end
				end)
			end
		end
	end

	return maxLifetime
end

local function spawnAxeEffect(template: Instance, targetPart: BasePart): (Instance, number)
	local effectsParent = workspace:FindFirstChild("Effects") or workspace
	local parent = if template:IsA("Attachment") then targetPart else effectsParent
	local attached = attachEffectToPart(template, targetPart, parent)
	local lifetime = emitAxeAttributes(attached)

	DebrisService:AddItem(attached, lifetime + 0.75)

	return attached, lifetime
end

local function disableSpinEffects(character: Model)
	local instances = activeSpinEffects[character]

	if not instances then
		return
	end

	for _, inst in ipairs(instances) do
		if inst and inst.Parent then
			setEffectsEnabled(inst, false)
			DebrisService:AddItem(inst, DEFAULT_CLEANUP_DELAY)
		end
	end

	activeSpinEffects[character] = nil
end

local function handleThrustPhase(character: Model, root: BasePart?, phase: string)
	local resolvedRoot = root or character:FindFirstChild("HumanoidRootPart")

	if not resolvedRoot or not resolvedRoot:IsA("BasePart") then
		return
	end

	playMoveSound("Slash", "Moves.Thrust", resolvedRoot)

	local template = getAxeTemplate(phase, THRUST_SIBLING_HINTS)

	if template then
		spawnAxeEffect(template, resolvedRoot)
	end
end

local function shouldAttachToWeaponHandle(phase: string, template: Instance): boolean
	if phase == "Startup" and template:IsA("Attachment") then
		return true
	end

	if template:GetAttribute("AttachToHandle") == true or normalizeKey(template.Name) == "handle" then
		return true
	end

	return false
end

local function handleSpinPhase(character: Model, root: BasePart?, phase: string)
	local resolvedRoot = root or character:FindFirstChild("HumanoidRootPart")

	if not resolvedRoot or not resolvedRoot:IsA("BasePart") then
		return
	end

	playMoveSound("Slash", "Moves.Spin", resolvedRoot)

	local template = getAxeTemplate(phase, SPIN_SIBLING_HINTS)

	if not template then
		if phase == "End" then
			disableSpinEffects(character)
		end
		return
	end

	local targetPart: BasePart = resolvedRoot

	if shouldAttachToWeaponHandle(phase, template) then
		targetPart = findWeaponHandle(character) or resolvedRoot
	end

	local instance = spawnAxeEffect(template, targetPart)

	local list = activeSpinEffects[character]
	if not list then
		list = {}
		activeSpinEffects[character] = list
	end

	table.insert(list, instance)
end

local function isMoveAnimationTrack(track: AnimationTrack, moveName: string, targetAnimId: string?, fallbackDigits: string?): boolean
	if track.Name == moveName then
		return true
	end

	local anim = track.Animation
	if anim then
		if anim.Name == moveName then
			return true
		end

		if targetAnimId and anim.AnimationId == targetAnimId then
			return true
		end

		if fallbackDigits and string.find(anim.AnimationId, fallbackDigits, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function bindAxeTrackEvents(
	boundTable,
	character: Model,
	root: BasePart?,
	track: AnimationTrack,
	aliases: {[string]: string},
	normalizeFn: (any) -> string?,
	phaseHandler: (Model, BasePart?, string) -> (),
	hasEndPhase: boolean,
	onEvent: ((string) -> ())?
)
	if boundTable[character] == track then
		return
	end

	boundTable[character] = track

	local connections = {}
	local ended = false

	local function dispatch(rawName: any)
		local eventName = normalizeFn(rawName)

		if not eventName then
			return
		end

		if eventName == "End" then
			if ended then
				return
			end

			ended = true
		end

		phaseHandler(character, root, eventName)

		if onEvent then
			onEvent(eventName)
		end
	end

	table.insert(connections, track.KeyframeReached:Connect(function(keyframeName: string)
		dispatch(keyframeName)
	end))

	for aliasName in pairs(aliases) do
		table.insert(connections, track:GetMarkerReachedSignal(aliasName):Connect(function(param)
			dispatch(aliasName)
			if param and param ~= "" then
				dispatch(param)
			end
		end))
	end

	for _, genericName in ipairs(GENERIC_MARKER_NAMES) do
		table.insert(connections, track:GetMarkerReachedSignal(genericName):Connect(function(param)
			dispatch(param)
		end))
	end

	table.insert(connections, track.Stopped:Once(function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		if hasEndPhase then
			dispatch("End")
		end

		if boundTable[character] == track then
			boundTable[character] = nil
		end
	end))
end

local function attachToAxeTrack(
	boundTable,
	moveName: string,
	fallbackDigits: string,
	character: Model,
	root: BasePart?,
	providedTrack: AnimationTrack?,
	aliases: {[string]: string},
	normalizeFn: (any) -> string?,
	phaseHandler: (Model, BasePart?, string) -> (),
	hasEndPhase: boolean,
	onEvent: ((string) -> ())?
)
	if providedTrack then
		bindAxeTrackEvents(boundTable, character, root, providedTrack, aliases, normalizeFn, phaseHandler, hasEndPhase, onEvent)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		return
	end

	local targetAnimId = AnimationsModule.GetAnimationId("Moves", moveName)

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if isMoveAnimationTrack(track, moveName, targetAnimId, fallbackDigits) then
			bindAxeTrackEvents(boundTable, character, root, track, aliases, normalizeFn, phaseHandler, hasEndPhase, onEvent)
			return
		end
	end

	local connection
	connection = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		if isMoveAnimationTrack(track, moveName, targetAnimId, fallbackDigits) then
			if connection then
				connection:Disconnect()
				connection = nil
			end

			bindAxeTrackEvents(boundTable, character, root, track, aliases, normalizeFn, phaseHandler, hasEndPhase, onEvent)
		end
	end)

	task.delay(TRACK_WAIT_TIMEOUT, function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

function Effects.Thrust(data)
	if type(data) ~= "table" then
		return
	end

	local character = data.char
	local root = data.root
	local phase = normalizeThrustEvent(data.phase)

	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	if not root then
		root = character:FindFirstChild("HumanoidRootPart")
	end

	if phase then
		handleThrustPhase(character, root, phase)
		return
	end

	attachToAxeTrack(
		boundThrustTracks,
		THRUST_MOVE_NAME,
		"86677978686885",
		character,
		root,
		data.track,
		THRUST_EVENT_ALIASES,
		normalizeThrustEvent,
		handleThrustPhase,
		false,
		data.onEvent
	)
end

function Effects.Spin(data)
	if type(data) ~= "table" then
		return
	end

	local character = data.char
	local root = data.root
	local phase = normalizeSpinEvent(data.phase)

	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	if not root then
		root = character:FindFirstChild("HumanoidRootPart")
	end

	if phase then
		handleSpinPhase(character, root, phase)
		return
	end

	attachToAxeTrack(
		boundSpinTracks,
		SPIN_MOVE_NAME,
		"102759962289170",
		character,
		root,
		data.track,
		SPIN_EVENT_ALIASES,
		normalizeSpinEvent,
		handleSpinPhase,
		false,
		data.onEvent
	)
end

--// Cancel Move (On Parry / Interrupt) \\--

function Effects.CancelMove(data)
	if type(data) ~= "table" then
		return
	end

	local character = data.char

	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	disableSlashMove(character)
	disableSpinEffects(character)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if animator then
		local movesTree = AnimationsModule.GetAnimationTree("Moves")
		local targetMove = data.move

		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			local anim = track.Animation
			local trackName = track.Name
			local animName = anim and anim.Name

			if (targetMove and (trackName == targetMove or animName == targetMove))
				or (movesTree and (movesTree[trackName] ~= nil or (animName and movesTree[animName] ~= nil)))
				or isDaggerDanceTrack(track, AnimationsModule.GetAnimationId("Moves", DAGGER_DANCE_NAME))
				or isMoveAnimationTrack(track, THRUST_MOVE_NAME, AnimationsModule.GetAnimationId("Moves", THRUST_MOVE_NAME), "86677978686885")
				or isMoveAnimationTrack(track, SPIN_MOVE_NAME, AnimationsModule.GetAnimationId("Moves", SPIN_MOVE_NAME), "102759962289170") then
				track:Stop(0.1)
			end
		end
	end
end

--// Dispatcher \\--

function Effects.Play(moveName: string, data)
	local handler = Effects[moveName]

	if type(handler) == "function" then
		handler(data)
	end
end

setmetatable(Effects, {
	__call = function(_, moveName: string, data)
		Effects.Play(moveName, data)
	end,
})

return Effects
