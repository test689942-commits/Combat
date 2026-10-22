--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local AnimationsModule = require(ReplicatedStorage.Modules:WaitForChild("Animations"))
local Sounds = require(ReplicatedStorage.Modules:WaitForChild("Sounds"))

--// Variables \\--

local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
local effectsFolder = assetsFolder:WaitForChild("Effects")

local MOVE_NAME = "DaggerDance"
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

local SOUND_LIFETIME = 4
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

local activeEffects = setmetatable({}, {__mode = "k"})
local boundTracks = setmetatable({}, {__mode = "k"})

--// Helpers \\--

local function normalizeKey(text: string): string
	return string.lower((string.gsub(text, "[%s_]+", "")))
end

local function normalizeEventName(rawName: any): string?
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
	local direct = effectsFolder:FindFirstChild(name) or effectsFolder:FindFirstChild(name, true)

	if direct then
		return direct
	end

	local targetKey = normalizeKey(name)

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

	warn("[DaggerDance] Could not find effect template:", name)
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

			slashMoveEffect = attachEffectToPart(slashMoveTemplate, root, effectsParent, getSlashMoveOffset())
			state.slashMoveEffect = slashMoveEffect
		end
	end

	if slashMoveEffect then
		table.insert(pathsToEnable, slashMoveEffect)
	end

	local slashFloorEffect = state.slashFloorEffect

	if not slashFloorEffect or not slashFloorEffect.Parent then
		local slashFloorTemplate = findEffectTemplate(SLASH_FLOOR_NAME)

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

	playSound("Slash", root)
end

local function disableSlashMove(character: Model)
	local state = activeEffects[character]
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

		activeEffects[character] = nil
	end
end

local function handlePhase(character: Model, root: BasePart?, phase: string)
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
	if track.Name == MOVE_NAME then
		return true
	end

	local anim = track.Animation
	if anim then
		if anim.Name == MOVE_NAME then
			return true
		end

		if targetAnimId and anim.AnimationId == targetAnimId then
			return true
		end

		if string.find(anim.AnimationId, "115648844139917", 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function findPlayingTrack(animator: Animator, targetAnimId: string?): AnimationTrack?
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if isDaggerDanceTrack(track, targetAnimId) then
			return track
		end
	end

	return nil
end

local function bindTrackEvents(character: Model, root: BasePart?, track: AnimationTrack, onEvent: ((string) -> ())?)
	if boundTracks[character] == track then
		return
	end

	boundTracks[character] = track

	local connections = {}
	local ended = false

	local function dispatch(rawName: any)
		local eventName = normalizeEventName(rawName)

		if not eventName then
			return
		end

		if eventName == END_NAME then
			if ended then
				return
			end

			ended = true
		end

		handlePhase(character, root, eventName)

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

		if boundTracks[character] == track then
			boundTracks[character] = nil
		end
	end))
end

local function attachToCharacterTrack(character: Model, root: BasePart?, providedTrack: AnimationTrack?, onEvent: ((string) -> ())?)
	if providedTrack then
		bindTrackEvents(character, root, providedTrack, onEvent)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		return
	end

	local targetAnimId = AnimationsModule.GetAnimationId("Moves", MOVE_NAME)
	local existingTrack = findPlayingTrack(animator, targetAnimId)

	if existingTrack then
		bindTrackEvents(character, root, existingTrack, onEvent)
		return
	end

	local connection
	connection = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		if isDaggerDanceTrack(track, targetAnimId) then
			if connection then
				connection:Disconnect()
				connection = nil
			end

			bindTrackEvents(character, root, track, onEvent)
		end
	end)

	task.delay(TRACK_WAIT_TIMEOUT, function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

--// Public \\--

return function(data)
	if type(data) ~= "table" then
		return
	end

	local character = data.char
	local root = data.root
	local phase = normalizeEventName(data.phase)

	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	if not root then
		root = character:FindFirstChild("HumanoidRootPart")
	end

	if phase then
		handlePhase(character, root, phase)
		return
	end

	attachToCharacterTrack(character, root, data.track, data.onEvent)
end
