--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules \\--

local Client = require(ReplicatedStorage.Modules:WaitForChild("ClientSystem"))
local EffectsBase = require(ReplicatedStorage.Modules:WaitForChild("EffectsBase"))
local AfterImages = require(ReplicatedStorage.Modules:WaitForChild("AfterImages"))
local Info = require(script.Parent).Dash

--// Variables \\--

local Dash = {}

local MOVE_NAME = script.Name
local LIMB_NAMES = {"Right Arm", "Left Arm", "Left Leg", "Right Leg"}
local SUPER_DASH_WINDOW = 0.35
local SUPER_DASH_DURATION = 0.65
local SUPER_DASH_SPEED = 85
local SUPER_DASH_COOLDOWN = 1.5

local directionsByName = {}
local superDashQueued = false
local superDashActive = false
local superDashWindowUntil = 0
local lastSuperDashTime = -math.huge

local obstructionParams = RaycastParams.new()
obstructionParams.FilterType = Enum.RaycastFilterType.Exclude

for _, directionInfo in Info.Directions do
	directionsByName[directionInfo.Direction] = directionInfo
end

--// Effects \\--

local function getDashEffectsFolder(): Instance?
	return Client.Assets.Effects:FindFirstChild("Movement")
		or Client.Assets.Effects:FindFirstChild("Dash")
		or Client.Assets.Effects:FindFirstChild("DashVFX")
end

local function spawnRing(ringCFrame: CFrame, size: Vector3)
	local Effects = getDashEffectsFolder()
	local ringTemplate = Effects and Effects:FindFirstChild("Ring")

	if not ringTemplate then
		return
	end

	local ring = ringTemplate:Clone()
	ring.Size = Vector3.new(3.749, 0.183, 3.948)
	ring.CFrame = ringCFrame
	ring.Transparency = 0.5
	ring.Color = Color3.new(1, 1, 1)
	ring.Parent = workspace.Effects

	Client.Utilities.Debris:AddItem(ring, 5)

	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local goals = {Transparency = 1, Size = size, CFrame = ringCFrame}

	Client.Service.TweenService:Create(ring, tweenInfo, goals):Play()
end

local function playBurst(character: Model, direction: string)
	if not character:IsA("Model") or typeof(direction) ~= "string" then
		return
	end

	local dashEffects = getDashEffectsFolder()
	local burstTemplate = dashEffects and dashEffects:FindFirstChild(direction)

	if not burstTemplate then
		return
	end

	local root: BasePart = character.PrimaryPart
	local burst: BasePart = burstTemplate:Clone()
	burst.Parent = workspace.Effects
	burst.CFrame = root.CFrame
	burst.WeldConstraint.Part0 = root

	task.delay(0.2, function()
		EffectsBase.Enable(burst, true, nil, false)
	end)

	EffectsBase.Emit(burst, true)
	Client.Utilities.Debris:AddItem(burst, 5)

	local vectorName = if direction == "Right" or direction == "Left" then "rightVector" else "lookVector"
	local ringCFrame = CFrame.lookAt(root.Position, root.Position - root.CFrame[vectorName]) * CFrame.Angles(math.pi / 2, 0, 0)

	spawnRing(ringCFrame, Vector3.new(7.222, 0.469, 7.605))
end

local function playSideDust(character: Model, direction: string)
	local root = character:FindFirstChild("HumanoidRootPart")
	local movementEffects = getDashEffectsFolder()
	local template = movementEffects and movementEffects:FindFirstChild("SideDust", true)
	if not root or not root:IsA("BasePart") or not template then
		return
	end

	local dust = template:Clone()
	local lateralOffset = if direction == "Left" then -1.25 elseif direction == "Right" then 1.25 else 0
	local effectCFrame = root.CFrame * CFrame.new(lateralOffset, -2, 0)

	if dust:IsA("Attachment") then
		dust.Position = Vector3.new(lateralOffset, -2, 0)
		dust.Parent = root
	elseif dust:IsA("BasePart") then
		dust.Anchored = true
		dust.CanCollide = false
		dust.CanQuery = false
		dust.CanTouch = false
		dust.CFrame = effectCFrame
		dust.Parent = workspace:FindFirstChild("Effects") or workspace
	elseif dust:IsA("Model") then
		dust:PivotTo(effectCFrame)
		dust.Parent = workspace:FindFirstChild("Effects") or workspace
	else
		dust.Parent = root
	end

	EffectsBase.Emit(dust, true)
	Client.Utilities.Debris:AddItem(dust, 2)
end

local function playLimbTrails(character: Model)
	if not character or not character.PrimaryPart then
		return
	end

	local dashEffects = getDashEffectsFolder()
	local trailAsset = dashEffects and dashEffects:FindFirstChild("Trail")
	local limbTrailTemplate = trailAsset

	if trailAsset and not trailAsset:IsA("Attachment") then
		limbTrailTemplate = trailAsset:FindFirstChild("LimbAtt", true)
			or trailAsset:FindFirstChildWhichIsA("Attachment", true)
	end

	if not limbTrailTemplate or not limbTrailTemplate:IsA("Attachment") then
		return
	end

	local trails = {}

	for _, limbName in LIMB_NAMES do
		local limb = character:FindFirstChild(limbName)

		if limb then
			local attachment = limbTrailTemplate:Clone()
			attachment.Parent = limb

			Client.Utilities.Debris:AddItem(attachment, 0.5)

			for _, child in attachment:GetChildren() do
				if child:IsA("Trail") then
					table.insert(trails, child)
				end
			end
		end
	end

	task.wait(0.35)

	for _, trail in trails do
		if trail.Enabled then
			trail.Enabled = false
		end
	end
end

local function playSound(root: BasePart)
	local soundName = Info.Sounds[math.random(1, #Info.Sounds)]
	local sound = Client.Sounds.GetSound("SFX", soundName)

	if not sound then
		return
	end

	sound.Parent = root
	sound:Play()

	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function startAfterImages(character: Model)
	AfterImages.Play({
		Model = character,
		GhostColor = Color3.fromRGB(170, 0, 255),
		FadeTime = 0.18,
		Interval = 0.05,
		FillTransparency = 0.8,
		StartTransparency = 0.4,
	})
end

local function playEffects(character: Model, root: BasePart, direction: string)
	task.spawn(playLimbTrails, character)
	task.spawn(playBurst, character, direction)
	task.spawn(playSideDust, character, direction)

	startAfterImages(character)
	playSound(root)
end

--// Movement \\--

local function canDash(character: Model): boolean
	if #Client.Actions > 0 or #Client.Stuns > 0 then
		return false
	end

	if Client.Dashing then
		return false
	end

	return not Client.Library.CheckCooldown(character, MOVE_NAME)
end

local function clearVelocities(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BodyVelocity") or descendant:IsA("LinearVelocity") then
			descendant:Destroy()
		end
	end
end

local function endAirCombat(character: Model)
	if not character:FindFirstChild("AirCombat") then
		return
	end

	local remote = Client.Service.ReplicatedStorage.Events.HandlerFireServer
	remote:FireServer("Combat_Server", "EndAirCombat", character)
end

local function getSpeedAndDuration(character: Model, direction: string): (number, number)
	if character:GetAttribute("AirDuration") then
		return Info.ComboSpeed, Info.ComboDuration
	end

	return Info.Speed, directionsByName[direction].Duration or Info.Duration
end

local function createVelocity(root: BasePart, duration: number): BodyVelocity
	local mass = root.AssemblyCenterOfMass.Magnitude
	local velocity = Instance.new("BodyVelocity")

	if Client.InAir then
		velocity.MaxForce = vector.one * 8e5 * mass
	else
		velocity.MaxForce = Vector3.new(1, 1, 1) * 2500 * mass
	end

	velocity.Parent = root

	Client.Utilities.Debris:AddItem(velocity, duration)

	return velocity
end

local function isObstructed(root: BasePart): RaycastResult?
	local hit = workspace:Raycast(root.Position, root.AssemblyLinearVelocity * 0.0915, obstructionParams)

	if not hit or not hit.Instance then
		return nil
	end

	if hit.Instance.CanCollide and hit.Instance.Transparency ~= 1 and hit.Instance.Anchored then
		return hit
	end

	return nil
end

local function markDashWallContact(character: Model, hit: RaycastResult)
	if math.abs(hit.Normal.Y) >= 0.7 then
		return
	end

	local contactTime = os.clock()
	character:SetAttribute("DashWallContactAt", contactTime)
	character:SetAttribute("DashWallNormal", hit.Normal)

	task.delay(0.8, function()
		if character.Parent and character:GetAttribute("DashWallContactAt") == contactTime then
			character:SetAttribute("DashWallContactAt", nil)
			character:SetAttribute("DashWallNormal", nil)
		end
	end)
end

local function updateVelocity(velocity: BodyVelocity, root: BasePart, character: Model, direction: string, speed: number)
	local directionInfo = directionsByName[direction]

	if Client.InAir and not character:GetAttribute("AirDuration") then
		local camera = workspace.CurrentCamera
		local position = Vector3.new(camera.CFrame.X, root.CFrame.Y, camera.CFrame.Z)
		local cameraOffset = camera.CFrame * CFrame.new(0, 0, 2)
		local offsetPosition = Vector3.new(cameraOffset.X, root.CFrame.Y, cameraOffset.Z)

		local airDirection = CFrame.new(position, offsetPosition)
			* CFrame.Angles(0, math.rad(directionInfo.AirAngle), 0)
			* CFrame.Angles(camera.CFrame.LookVector.Y, 0, 0)

		velocity.Velocity = airDirection.LookVector * Info.AirSpeed
	else
		local axis = if directionInfo.Axis == "Right" then root.CFrame.RightVector else root.CFrame.LookVector

		velocity.Velocity = axis * (directionInfo.Sign * speed) + Vector3.zero
	end
end

local function stopAnimation(animation: AnimationTrack?)
	if animation then
		animation:Stop()
	end
end

local function runDash(character: Model, root: BasePart, animation: AnimationTrack?, velocity: BodyVelocity, direction: string, speed: number)
	repeat
		if #Client.Actions > 0 or #Client.Stuns > 0 then
			stopAnimation(animation)
			break
		end

		local obstruction = isObstructed(root)
		if obstruction then
			stopAnimation(animation)
			velocity:Destroy()
			markDashWallContact(character, obstruction)
			break
		end

		updateVelocity(velocity, root, character, direction, speed)

		Client.Service.RunService.RenderStepped:Wait()
	until not velocity.Parent
end

local function runSuperDash(character: Model, humanoid: Humanoid, root: BasePart)
	local now = os.clock()
	if superDashActive or now - lastSuperDashTime < SUPER_DASH_COOLDOWN
		or #Client.Actions > 0 or #Client.Stuns > 0 or humanoid.Health <= 0 then
		return
	end

	local movementDirection = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if movementDirection.Magnitude < 0.05 then
		return
	end
	movementDirection = movementDirection.Unit

	local localDirection = root.CFrame:VectorToObjectSpace(movementDirection)
	local direction = if math.abs(localDirection.X) > math.abs(localDirection.Z)
		then (if localDirection.X > 0 then "Right" else "Left")
		else (if localDirection.Z < 0 then "Forward" else "Back")

	superDashActive = true
	superDashQueued = false
	superDashWindowUntil = 0
	lastSuperDashTime = now
	Client.Dashing = true

	local transparencyByInstance = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			transparencyByInstance[descendant] = descendant.Transparency
		end
	end

	local function setInvisible(invisible: boolean)
		for instance, originalTransparency in pairs(transparencyByInstance) do
			if instance.Parent then
				instance.Transparency = if invisible then 1 else originalTransparency
			end
		end
	end

	local velocity = Instance.new("BodyVelocity")
	velocity.Name = "SuperDashVelocity"
	velocity.MaxForce = Vector3.new(1e5, 0, 1e5) * root.AssemblyMass
	velocity.P = 10000
	velocity.Parent = root

	playEffects(character, root, direction)
	startAfterImages(character)

	local startedAt = os.clock()
	local nextBlinkAt = startedAt
	local visibleAgainAt = 0
	while os.clock() - startedAt < SUPER_DASH_DURATION and character.Parent and humanoid.Health > 0 do
		if #Client.Actions > 0 or #Client.Stuns > 0 then
			break
		end

		local currentTime = os.clock()
		if currentTime >= nextBlinkAt then
			setInvisible(true)
			visibleAgainAt = currentTime + 0.08
			nextBlinkAt = currentTime + 0.23
		elseif currentTime >= visibleAgainAt then
			setInvisible(false)
		end

		local obstruction = isObstructed(root)
		if obstruction then
			markDashWallContact(character, obstruction)
			break
		end

		velocity.Velocity = movementDirection * SUPER_DASH_SPEED
		Client.Service.RunService.Heartbeat:Wait()
	end

	setInvisible(false)
	if velocity.Parent then
		velocity:Destroy()
	end
	AfterImages.Play({Model = character, Stop = true})
	Client.Dashing = false
	superDashActive = false
end

--// Move \\--

function Dash.Activate(direction: string)
	local humanoid = Client.Humanoid :: Humanoid
	local root = Client.Root :: BasePart
	local character = Client.Character :: Model

	if not humanoid or not root or not character then
		return
	end

	if not directionsByName[direction] then
		return
	end

	obstructionParams.FilterDescendantsInstances = {character}

	if Client.Dashing then
		if not superDashActive then
			superDashQueued = true
		end
		return
	end

	if superDashWindowUntil > os.clock() then
		superDashWindowUntil = 0
		runSuperDash(character, humanoid, root)
		return
	end

	if not canDash(character) then
		return
	end

	clearVelocities(character)
	superDashQueued = false

	Client.Library.SetCooldown(character, MOVE_NAME, Info.Cooldown)
	Client.Dashing = true

	endAirCombat(character)

	local animation = Client.Library.PlayAnimation(character, "Movement", direction, 0.1)
	local speed, duration = getSpeedAndDuration(character, direction)
	local velocity = createVelocity(root, duration)

	playEffects(character, root, direction)
	runDash(character, root, animation, velocity, direction, speed)

	AfterImages.Play({Model = character, Stop = true})

	Client.Dashing = false
	if superDashQueued then
		superDashQueued = false
		runSuperDash(character, humanoid, root)
	else
		superDashWindowUntil = os.clock() + SUPER_DASH_WINDOW
	end
end

return Dash
