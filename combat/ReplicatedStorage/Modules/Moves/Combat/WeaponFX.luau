--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local DebrisService = game:GetService("Debris")

--// Modules \\--

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Weapons = require(Modules:WaitForChild("Weapons"))
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
local SLASH_LEAD = 0.1
local SLASH_FACING_YAW = 180

local HIT_UP_LENGTH = 0.77
local HIT_UP_FADE_TIME = 0.1
local HIT_UP_SOUND_TIME = 0.35
local HIT_UP_TRAIL_START = 0.22
local HIT_UP_TRAIL_END = 0.72

local swingTracks = setmetatable({}, {__mode = "k"})
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

local function loadTrack(humanoid: Humanoid, category: string, animationName: string): AnimationTrack?
	local animation = AnimationsModule.GetAnimation("Weapons." .. category, animationName)

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

local function getSlashTemplate(effectName: string, category: string?): BasePart?
	local categoryFolder = category and slashFolder:FindFirstChild(category)
	local template = categoryFolder and categoryFolder:FindFirstChild(effectName)

	if not template then
		template = slashFolder:FindFirstChild(effectName, true)
	end

	if template and template:IsA("BasePart") then
		return template
	end

	return nil
end

local function playSlashEffect(character: Model, effectName: string, category: string?)
	local humanoid, root = getCharacterParts(character)
	local template = getSlashTemplate(effectName, category)

	if not humanoid or not template or character:FindFirstChild("Stun") then
		return
	end

	local EmitModule = require(Modules:WaitForChild("EffectsBase")).EmitModule
	local facingYaw = math.rad(template:GetAttribute("FacingYaw") or SLASH_FACING_YAW)
	local templateRotation = template.CFrame - template.CFrame.Position
	local slashFrame = CFrame.Angles(0, facingYaw, 0) * templateRotation

	for _, attachment in template:GetChildren() do
		if attachment:IsA("Attachment") then
			local slashAttachment = attachment:Clone()
			slashAttachment.CFrame = slashFrame * attachment.CFrame
			slashAttachment.Parent = root

			EmitModule.EmitAndRemove(slashAttachment, nil, {dontClone = true, noAutoSmoke = true})
		end
	end
end

local function scheduleSlashEffect(character: Model, weapon, count: number, hit)
	local effectName = weapon.SlashEffects and weapon.SlashEffects[count]

	if not effectName then
		return
	end

	task.delay(math.max(0, hit.ImpactTime - SLASH_LEAD), function()
		playSlashEffect(character, effectName, weapon.Category)
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

	local track = loadTrack(humanoid, category, "Combat" .. count)

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

	scheduleSlashEffect(character, weapon, count, hit)

	return hit
end

--// Owner Swing Movement \\--

local function applyLunge(character: Model, lunge)
	local _, root = getCharacterParts(character)

	if not root or character:FindFirstChild("Stun") then
		return
	end

	local velocity = Instance.new("BodyVelocity")
	velocity.MaxForce = Vector3.new(4e4, 0, 4e4)
	velocity.Velocity = root.CFrame.LookVector * Vector3.new(1, 0, 1) * lunge.Force
	velocity.Parent = root

	DebrisService:AddItem(velocity, lunge.Duration)
end

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

	if hit.Lunge and not Weapons.GetForCharacter(character).NoLunge then
		task.delay(math.max(0, hit.ImpactTime - hit.Lunge.Lead), function()
			applyLunge(character, hit.Lunge)
		end)
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
	local dashFolder = effectsFolder:FindFirstChild("DashVFX")
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

	if hit.CritEffect then
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
	local category = Weapons.GetCategory(character)
	local humanoid, root = getCharacterParts(character)
	local equipTrack = nil

	if not humanoid then
		return nil
	end

	if playAnimation ~= false and AnimationsModule.DetectSpecificAnimation("Weapons." .. category, "Equip") then
		equipTrack = loadTrack(humanoid, category, "Equip")

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

	local track = loadTrack(humanoid, Weapons.GetCategory(character), "Blocking")

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

	local animation = AnimationsModule.GetAnimation("Combat.Weapon", "HitUp")

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
