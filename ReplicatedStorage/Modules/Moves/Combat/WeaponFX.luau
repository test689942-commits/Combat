--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Weapons = require(Modules:WaitForChild("Weapons"))
local CombatInfo = require(Modules:WaitForChild("Moves")).Combat
local Sounds = require(Modules:WaitForChild("Sounds"))
local AnimationsModule = require(Modules:WaitForChild("Animations"))

--// Variables \\--

local WeaponFX = {}

local player = Players.LocalPlayer
local effectsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects")
local combatEffects = effectsFolder:WaitForChild("Combat")
local slashFolder = effectsFolder:WaitForChild("Slashes")

local EQUIPPED_NAME = "EquippedWeapon"
local SOUND_LIFETIME = 4
local SWING_FADE_TIME = 0.1

--// Slash Key Events \\--

local SLASH_MARKER_CRIT = "Crit Slash"
local CRIT_SLASH_EFFECT = "Crit_Slash"
local SLASH_MARKER_PATTERN = "^M(%d+)%s*Slash$"
local SLASH_LEAD = 0.1

local HIT_UP_LENGTH = 0.77
local HIT_UP_FADE_TIME = 0.1
local HIT_UP_SOUND_TIME = 0.35
local HIT_UP_TRAIL_START = 0.22
local HIT_UP_TRAIL_END = 0.72

local swingTracks = setmetatable({}, {__mode = "k"})
local slashMarkers = setmetatable({}, {__mode = "k"})
local baseSpeeds = setmetatable({}, {__mode = "k"})
local trailTokens = setmetatable({}, {__mode = "k"})

local shakeToken = 0
local fovToken = 0
local baseFieldOfView = nil
local walkSlowToken = 0
local savedWalkSpeed = nil

--// Helpers \\--

local function getCharacterParts(character: Model?)
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end

	return humanoid, root
end

local function playSounds(soundNames, category: string, parent: Instance)
	if not soundNames then
		return
	end

	for _, soundName in soundNames do
		local sound = Sounds.GetSound("SFX", soundName, "Weapons." .. category)

		if sound then
			sound.Parent = parent
			sound:Play()
			DebrisService:AddItem(sound, SOUND_LIFETIME)
		end
	end
end

local function hasWeaponSound(category: string, soundName: string): boolean
	local sfxTree = Sounds.GetSoundTree("SFX")
	local weaponSounds = sfxTree and sfxTree.Weapons and sfxTree.Weapons[category]

	return weaponSounds ~= nil and weaponSounds[soundName] ~= nil
end

local function resolveWeaponAnimationRoot(weapon, animationName: string): string?
	local weaponRoot = "Weapons." .. weapon.Name

	if AnimationsModule.DetectSpecificAnimation(weaponRoot, animationName) then
		return weaponRoot
	end

	return nil
end

local function loadTrack(humanoid: Humanoid, weapon, animationName: string): AnimationTrack?
	local root = resolveWeaponAnimationRoot(weapon, animationName)
	local animation = root and AnimationsModule.GetAnimation(root, animationName)

	if not animation then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
	local track = animator:LoadAnimation(animation)

	animation:Destroy()

	return track
end

--// Swing Effects (trail + air) \\--

local function setSwingEffects(character: Model, enabled: boolean)
	local weaponModel = character:FindFirstChild(EQUIPPED_NAME)

	if not weaponModel then
		return
	end

	for _, descendant in weaponModel:GetDescendants() do
		if descendant:IsA("Trail") or (descendant:IsA("ParticleEmitter") and descendant:GetAttribute("SwingEffect")) then
			descendant.Enabled = enabled
		end
	end
end

local function runSwingWindow(character: Model, startTime: number, endTime: number)
	local token = (trailTokens[character] or 0) + 1
	trailTokens[character] = token

	task.delay(startTime, function()
		if trailTokens[character] == token then
			setSwingEffects(character, true)
		end
	end)

	task.delay(endTime, function()
		if trailTokens[character] == token then
			setSwingEffects(character, false)
		end
	end)
end

--// Slash Effects \\--

local function emitSlashInstance(container: Instance): number
	local maxLifetime = 1
	local objects = container:GetDescendants()
	table.insert(objects, 1, container)

	for _, particle in ipairs(objects) do
		if particle:IsA("ParticleEmitter") then
			local emitDelay = particle:GetAttribute("EmitDelay")
			local emitDuration = particle:GetAttribute("EmitDuration")
			local emitCount = particle:GetAttribute("EmitCount") or particle:GetAttribute("Amount")

			local delayTime = if type(emitDelay) == "number" and emitDelay > 0 then emitDelay else 0
			local durationTime = if type(emitDuration) == "number" and emitDuration > 0 then emitDuration else 0

			local totalTime = delayTime + durationTime + particle.Lifetime.Max
			if totalTime > maxLifetime then
				maxLifetime = totalTime
			end

			if emitCount and emitCount > 0 then
				if delayTime > 0 then
					task.delay(delayTime, function()
						if particle.Parent then
							particle:Emit(emitCount)
						end
					end)
				else
					particle:Emit(emitCount)
				end
			elseif durationTime <= 0 then
				task.delay(delayTime, function()
					if particle.Parent then
						particle:Emit(1)
					end
				end)
			end

			if durationTime > 0 then
				if delayTime > 0 then
					task.delay(delayTime, function()
						if particle.Parent then
							particle.Enabled = true
							task.delay(durationTime, function()
								if particle.Parent then
									particle.Enabled = false
								end
							end)
						end
					end)
				else
					particle.Enabled = true
					task.delay(durationTime, function()
						if particle.Parent then
							particle.Enabled = false
						end
					end)
				end
			end
		end
	end

	return maxLifetime
end

local function getSlashTemplate(effectName: string, category: string?, weaponName: string?): Instance?
	if weaponName == "Fists" or category == "Fists" then
		local combatSlashFolder = slashFolder:FindFirstChild("Combat")
		local fistEffect = combatSlashFolder and combatSlashFolder:FindFirstChild(effectName)

		if fistEffect then
			return fistEffect
		end
	end

	local weaponSubfolder = weaponName and (slashFolder:FindFirstChild(weaponName) or effectsFolder:FindFirstChild(weaponName))
	local template = weaponSubfolder and weaponSubfolder:FindFirstChild(effectName)

	if not template then
		local categoryFolder = category and (slashFolder:FindFirstChild(category) or effectsFolder:FindFirstChild(category))
		template = categoryFolder and categoryFolder:FindFirstChild(effectName)
	end

	if not template then
		template = slashFolder:FindFirstChild(effectName, true)
	end

	if not template then
		template = effectsFolder:FindFirstChild(effectName, true)
	end

	return template
end

local function resolveSlashEffect(weapon, markerName: string, count: number?): string?
	local customMarkers = weapon.SlashMarkers
	local customIndex = customMarkers and table.find(customMarkers, markerName)

	if customIndex then
		local customEffects = weapon.SlashEffects

		return customEffects and customEffects[customIndex]
	end

	if count and weapon.SlashEffects then
		local mappedName = nil

		if markerName == "Slash" then
			mappedName = "M" .. count .. "Swing"
		elseif markerName == "Floor" then
			mappedName = "M" .. count .. "Floor"
		elseif markerName == "Slam" then
			mappedName = "M" .. count .. "Slam"
		end

		if mappedName and table.find(weapon.SlashEffects, mappedName) then
			return mappedName
		end
	end

	local index = markerName:match(SLASH_MARKER_PATTERN)

	if index then
		local effects = weapon.SlashEffects
		local effectName = effects and effects[tonumber(index)]

		return effectName or ("M" .. index)
	end

	if markerName == SLASH_MARKER_CRIT and not weapon.NoCritical then
		if weapon.CritSlashEffect then
			return weapon.CritSlashEffect
		end

		local effects = weapon.SlashEffects

		if effects and #effects > 0 then
			return effects[#effects]
		end

		return CRIT_SLASH_EFFECT
	end

	return nil
end

local function playSlashEffect(character: Model, effectName: string, category: string?, weaponName: string?)
	local humanoid, root = getCharacterParts(character)

	if not humanoid or not root or character:FindFirstChild("Stun") then
		return
	end

	local existingOnRoot = root:FindFirstChild(effectName)
	if existingOnRoot then
		emitSlashInstance(existingOnRoot)
		return
	end

	local template = getSlashTemplate(effectName, category, weaponName)

	if not template then
		return
	end

	if template:IsA("Attachment") then
		local slashAttachment = template:Clone()
		slashAttachment.Parent = root

		local lifetime = emitSlashInstance(slashAttachment)
		DebrisService:AddItem(slashAttachment, lifetime + 0.5)
		return
	end

	if template:IsA("BasePart") then
		local templateRotation = template.CFrame - template.CFrame.Position
		local spawnedAttachments = false

		for _, child in ipairs(template:GetChildren()) do
			if child:IsA("Attachment") then
				spawnedAttachments = true
				local slashAttachment = child:Clone()
				slashAttachment.CFrame = templateRotation * child.CFrame
				slashAttachment.Parent = root

				local lifetime = emitSlashInstance(slashAttachment)
				DebrisService:AddItem(slashAttachment, lifetime + 0.5)
			end
		end

		if spawnedAttachments then
			return
		end

		local clone = template:Clone()
		clone.CFrame = root.CFrame * templateRotation
		clone.Anchored = false
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Massless = true
		clone.Parent = workspace:FindFirstChild("Effects") or workspace

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = clone
		weld.Parent = clone

		local lifetime = emitSlashInstance(clone)
		DebrisService:AddItem(clone, lifetime + 0.5)
		return
	end

	local clone = template:Clone()
	clone.Parent = root
	local lifetime = emitSlashInstance(clone)
	DebrisService:AddItem(clone, lifetime + 0.5)
end

local function getSlashMarkerName(weapon, index: number): string
	local customMarkers = weapon.SlashMarkers
	local customName = customMarkers and customMarkers[index]

	return customName or ("M" .. index .. " Slash")
end

local function getSlashMarkerNames(weapon): {string}
	local names = {}
	local effects = weapon.SlashEffects

	if effects then
		for index = 1, #effects do
			table.insert(names, getSlashMarkerName(weapon, index))
		end
	end

	if not weapon.NoCritical then
		table.insert(names, SLASH_MARKER_CRIT)
	end

	return names
end

local function clearSlashMarkers(character: Model)
	local entry = slashMarkers[character]

	if not entry then
		return
	end

	for _, connection in ipairs(entry.connections) do
		connection:Disconnect()
	end

	entry.stopped:Disconnect()

	slashMarkers[character] = nil
end

local function bindSlashMarkers(character: Model, track: AnimationTrack?, weapon, count: number?)
	clearSlashMarkers(character)

	if not track or not weapon.SlashEffects then
		return
	end

	local entry = {
		connections = {},
		stopped = nil,
		triggered = {},
	}

	function entry.triggerEffect(effectName: string)
		if entry.triggered[effectName] then
			return
		end

		entry.triggered[effectName] = true
		playSlashEffect(character, effectName, weapon.Category, weapon.Name)
	end

	local function triggerMarker(markerName: string)
		local effectName = resolveSlashEffect(weapon, markerName, count)

		if effectName ~= nil then
			entry.triggerEffect(effectName)
		end
	end

	for _, markerName in ipairs(getSlashMarkerNames(weapon)) do
		local connection = track:GetMarkerReachedSignal(markerName):Connect(function()
			triggerMarker(markerName)
		end)

		table.insert(entry.connections, connection)
	end

	for _, shortMarker in ipairs({"Slash", "Floor", "Slam"}) do
		local connection = track:GetMarkerReachedSignal(shortMarker):Connect(function()
			triggerMarker(shortMarker)
		end)

		table.insert(entry.connections, connection)
	end

	table.insert(entry.connections, track.KeyframeReached:Connect(function(keyframeName: string)
		triggerMarker(keyframeName)
	end))

	entry.stopped = track.Stopped:Connect(function()
		if slashMarkers[character] == entry then
			clearSlashMarkers(character)
		end
	end)

	slashMarkers[character] = entry

	return entry
end

local function scheduleSlashEffect(character: Model, weapon, count: number, hit, triggerEffect)
	local effectName = weapon.SlashEffects and weapon.SlashEffects[count]

	if not effectName then
		return
	end

	task.delay(math.max(0, hit.ImpactTime - SLASH_LEAD), function()
		if triggerEffect then
			triggerEffect(effectName)
		else
			playSlashEffect(character, effectName, weapon.Category, weapon.Name)
		end
	end)
end

--// Swing \\--

function WeaponFX.Swing(character: Model, count: number)
	local weapon = Weapons.GetForCharacter(character)
	local category = weapon.Category
	local hit = Weapons.GetHit(weapon, count, character)
	local humanoid, root = getCharacterParts(character)

	if not humanoid then
		return hit
	end

	local track = loadTrack(humanoid, weapon, "Combat" .. count)
	local markerEntry = nil

	if track then
		track.Looped = false

		if weapon.SwingPriority then
			track.Priority = weapon.SwingPriority
		end

		local previousTrack = swingTracks[character]

		if previousTrack and previousTrack ~= track and previousTrack.IsPlaying then
			previousTrack:Stop(SWING_FADE_TIME)
		end

		swingTracks[character] = track
		baseSpeeds[track] = hit.Speed

		-- Subscribe before playback so an early keyframe/marker cannot be missed.
		if weapon.SlashEvents then
			markerEntry = bindSlashMarkers(character, track, weapon, count)
		end

		track:Play(SWING_FADE_TIME, 1, hit.Speed)
	elseif weapon.SlashEvents then
		bindSlashMarkers(character, nil, weapon, count)
	end

	if hit.SwingSoundTime <= 0 then
		playSounds(hit.SwingSounds, category, root)
	else
		task.delay(hit.SwingSoundTime, function()
			if root.Parent then
				playSounds(hit.SwingSounds, category, root)
			end
		end)
	end

	if hit.TrailStart then
		runSwingWindow(character, hit.TrailStart, hit.TrailEnd)
	end

	if weapon.Name == "Fists" then
		-- Fist animation assets can lack named markers; use the combo impact time
		-- as a deduplicated fallback while still honoring FistM1-FistM4 markers.
		scheduleSlashEffect(character, weapon, count, hit, markerEntry and markerEntry.triggerEffect)
	elseif not weapon.SlashEvents then
		scheduleSlashEffect(character, weapon, count, hit)
	end

	return hit
end

local function playCriticalTell(character: Model)
	local head = character:FindFirstChild("Head")
	local combatSlashFolder = slashFolder:FindFirstChild("Combat")
	local criticalTemplate = combatSlashFolder and combatSlashFolder:FindFirstChild("Critical")

	if not criticalTemplate or not (criticalTemplate:IsA("Attachment") or criticalTemplate:IsA("ParticleEmitter")) then
		criticalTemplate = nil
		for _, candidate in ipairs(effectsFolder:GetDescendants()) do
			if candidate.Name == "Critical" and (candidate:IsA("Attachment") or candidate:IsA("ParticleEmitter")) then
				criticalTemplate = candidate
				break
			end
		end
	end

	local hitFlashTemplate = combatEffects:FindFirstChild("HitFlash")
	if hitFlashTemplate and hitFlashTemplate:IsA("Highlight") then
		local criticalHighlight = hitFlashTemplate:Clone()
		criticalHighlight.Parent = character
		DebrisService:AddItem(criticalHighlight, 0.65)
	end

	if not criticalTemplate or not head or not head:IsA("BasePart") then
		return
	end

	local criticalEffect: Attachment
	if criticalTemplate:IsA("Attachment") then
		criticalEffect = criticalTemplate:Clone()
	else
		criticalEffect = Instance.new("Attachment")
		criticalEffect.Name = "CriticalTell"
		local emitter = criticalTemplate:Clone()
		emitter.Parent = criticalEffect
	end

	criticalEffect.Position = Vector3.new(0, head.Size.Y * 0.5 + 0.9, 0)
	criticalEffect.Parent = head

	local lifetime = emitSlashInstance(criticalEffect)
	DebrisService:AddItem(criticalEffect, lifetime + 0.5)
end

function WeaponFX.HeavySwing(character: Model)
	local weapon = Weapons.GetForCharacter(character)
	local count = weapon.MaxCombo
	local category = weapon.Category
	local hit = Weapons.GetHit(weapon, count, character)
	local humanoid, root = getCharacterParts(character)
	local equippedWeaponName = Weapons.GetEquippedWeaponName(character)

	if not humanoid or not equippedWeaponName then
		return hit
	end

	clearSlashMarkers(character)
	playCriticalTell(character)

	task.delay(CombatInfo.CriticalWindup, function()
		if character.Parent == nil
			or humanoid.Parent ~= character
			or humanoid.Health <= 0
			or Weapons.GetEquippedWeaponName(character) ~= equippedWeaponName then
			return
		end

		-- The dedicated Critical slot is the Heavy animation. Existing zero-ID
		-- slots fall back to that weapon's final combo animation until populated.
		local track = loadTrack(humanoid, weapon, "Critical") or loadTrack(humanoid, weapon, "Combat" .. count)

		if track then
			track.Looped = false

			if weapon.SwingPriority then
				track.Priority = weapon.SwingPriority
			end

			local previousTrack = swingTracks[character]

			if previousTrack and previousTrack ~= track and previousTrack.IsPlaying then
				previousTrack:Stop(SWING_FADE_TIME)
			end

			track:Play(SWING_FADE_TIME, 1, hit.Speed)
			swingTracks[character] = track
			baseSpeeds[track] = hit.Speed
		end

		if hit.SwingSoundTime <= 0 then
			playSounds(hit.SwingSounds, category, root)
		else
			task.delay(hit.SwingSoundTime, function()
				if root.Parent then
					playSounds(hit.SwingSounds, category, root)
				end
			end)
		end

		if hit.TrailStart then
			runSwingWindow(character, hit.TrailStart, hit.TrailEnd)
		end

		if weapon.SlashEvents and weapon.HeavySlashEvents ~= false then
			bindSlashMarkers(character, track, weapon, count)
		elseif not weapon.SlashEvents then
			scheduleSlashEffect(character, weapon, count, hit)
		end
	end)

	return hit
end

--// Owner Swing Movement \\--

function WeaponFX.ClearSwing(humanoid: Humanoid?)
	walkSlowToken += 1

	if savedWalkSpeed and humanoid and humanoid.Parent then
		humanoid.WalkSpeed = savedWalkSpeed
	end

	savedWalkSpeed = nil
end

local function slowWalk(humanoid: Humanoid, speed: number, duration: number)
	if savedWalkSpeed == nil then
		savedWalkSpeed = humanoid.WalkSpeed
	end

	walkSlowToken += 1

	local token = walkSlowToken
	humanoid.WalkSpeed = math.min(savedWalkSpeed, speed)

	task.delay(duration, function()
		if token == walkSlowToken then
			WeaponFX.ClearSwing(humanoid)
		end
	end)
end

function WeaponFX.ClientSwing(character: Model, hit)
	local humanoid = getCharacterParts(character)

	if not humanoid then
		return
	end

	if hit.WalkSpeed then
		slowWalk(humanoid, hit.WalkSpeed, hit.ActionTime)
	end
end

--// Impact Feel \\--

function WeaponFX.HitStop(attacker: Model?, duration: number)
	local track = attacker and swingTracks[attacker]

	if not track or not track.IsPlaying or duration <= 0 then
		return
	end

	local normalSpeed = baseSpeeds[track] or 1

	track:AdjustSpeed(0.03)

	task.delay(duration, function()
		if track.IsPlaying then
			track:AdjustSpeed(normalSpeed)
		end
	end)
end

function WeaponFX.Shake(strength: number, duration: number)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	shakeToken += 1

	local token = shakeToken
	local startTime = os.clock()
	local connection

	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime

		if token ~= shakeToken or elapsed >= duration or not humanoid.Parent then
			if token == shakeToken and humanoid.Parent then
				humanoid.CameraOffset = Vector3.zero
			end

			connection:Disconnect()
			return
		end

		local falloff = 1 - elapsed / duration

		humanoid.CameraOffset = Vector3.new(math.random(-100, 100) / 100, math.random(-100, 100) / 100, 0) * strength * falloff
	end)
end

function WeaponFX.FovKick(amount: number)
	local camera = workspace.CurrentCamera

	if not camera then
		return
	end

	fovToken += 1

	local token = fovToken

	if baseFieldOfView == nil then
		baseFieldOfView = camera.FieldOfView
	end

	local kickTween = TweenService:Create(camera, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = baseFieldOfView + amount})
	kickTween:Play()

	task.delay(0.1, function()
		local returnTween = TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = baseFieldOfView})
		returnTween:Play()

		returnTween.Completed:Connect(function()
			if token == fovToken then
				baseFieldOfView = nil
			end
		end)
	end)
end

function WeaponFX.OnImpact(attacker: Model?, victim: Model, hit)
	if hit.HitStop then
		WeaponFX.HitStop(attacker, hit.HitStop)
	end

	local localCharacter = player and player.Character

	if hit.Shake and localCharacter then
		if localCharacter == attacker then
			WeaponFX.Shake(hit.Shake.Attacker, hit.Shake.Duration)
		elseif localCharacter == victim then
			WeaponFX.Shake(hit.Shake.Victim, hit.Shake.Duration)
		end
	end

	if hit.FovKick and localCharacter and localCharacter == attacker then
		WeaponFX.FovKick(hit.FovKick)
	end
end

--// Hit Visuals \\--

local function spawnShockwave(root: BasePart)
	local dashFolder = effectsFolder:FindFirstChild("Movement") or effectsFolder:FindFirstChild("Dash") or effectsFolder:FindFirstChild("DashVFX")
	local template = dashFolder and dashFolder:FindFirstChild("Ring")

	if not template then
		return
	end

	local ring = template:Clone()
	ring.CFrame = root.CFrame * CFrame.new(0, -2.3, 0)
	ring.Size = ring.Size * 2
	ring.Parent = workspace.Effects

	DebrisService:AddItem(ring, 1)

	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = ring.Size * 2, Transparency = 1}):Play()
end

local function playCritEffect(attacker: Model?, effectName: string)
	local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart")
	local critPart = combatEffects:FindFirstChild(effectName)

	if not attackerRoot or not critPart then
		return
	end

	for _, attachment in critPart:GetChildren() do
		if attachment:IsA("Attachment") then
			_G.EffectEmitter(attachment, {Parent = attackerRoot, Debris = 1.5})
		end
	end
end

function WeaponFX.HitEffects(victim: Model, attacker: Model?, count: number)
	local weapon = Weapons.GetForCharacter(attacker)
	local category = weapon.Category
	local hit = Weapons.GetHit(weapon, count, attacker)
	local root = victim:FindFirstChild("HumanoidRootPart")

	if not root then
		return hit
	end

	local folder = combatEffects:FindFirstChild(weapon.EffectFolder)
	local attachment = folder and folder:FindFirstChild(hit.HitEffect)

	if attachment then
		_G.EffectEmitter(attachment, {Parent = root, Debris = 1.5})
	end

	if hit.CritEffect and not weapon.NoCritical then
		playCritEffect(attacker, hit.CritEffect)
	end

	playSounds(hit.HitSounds, category, root)

	if hit.Shockwave then
		spawnShockwave(root)
	end

	return hit
end

--// Equip / Block \\--

function WeaponFX.PlayEquip(character: Model, playAnimation: boolean?): AnimationTrack?
	local weapon = Weapons.GetForCharacter(character)
	local category = weapon.Category
	local humanoid, root = getCharacterParts(character)
	local equipTrack = nil

	if not humanoid then
		return nil
	end

	if playAnimation ~= false then
		equipTrack = loadTrack(humanoid, weapon, "Equip")

		if equipTrack then
			equipTrack.Looped = false
			equipTrack:Play()
		end
	end

	if hasWeaponSound(category, "Equip") then
		playSounds({"Equip"}, category, root)
	end

	return equipTrack
end

function WeaponFX.PlayBlockAnimation(character: Model)
	local humanoid = getCharacterParts(character)

	if not humanoid then
		return
	end

	local track = loadTrack(humanoid, Weapons.GetForCharacter(character), "Blocking")

	if track then
		track.Looped = true
		track:Play()
	end
end

--// Air Launch \\--

function WeaponFX.PlayHitUp(character: Model): number
	local weapon = Weapons.GetForCharacter(character)
	local category = weapon.Category
	local humanoid, root = getCharacterParts(character)

	if not humanoid then
		return HIT_UP_LENGTH
	end

	local animation = AnimationsModule.GetAnimation("Shared.Weapon", "HitUp")

	if animation then
		local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
		local track = animator:LoadAnimation(animation)

		animation:Destroy()

		track.Looped = false
		track.Priority = Enum.AnimationPriority.Action4
		track:Play(HIT_UP_FADE_TIME)
	end

	local finisher = Weapons.GetHit(weapon, weapon.MaxCombo)

	task.delay(HIT_UP_SOUND_TIME, function()
		if root.Parent then
			playSounds(finisher.SwingSounds, category, root)
		end
	end)

	runSwingWindow(character, HIT_UP_TRAIL_START, HIT_UP_TRAIL_END)

	return HIT_UP_LENGTH
end

return WeaponFX
