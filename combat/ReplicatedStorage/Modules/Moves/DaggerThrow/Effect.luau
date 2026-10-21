--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")
local RunService = game:GetService("RunService")

--// Modules \\--

local Sounds = require(ReplicatedStorage.Modules:WaitForChild("Sounds"))

--// Variables \\--

local daggerTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weapons"):WaitForChild("Daggers"):WaitForChild("Steel Dagger")

local EQUIPPED_NAME = "EquippedWeapon"
local SOUND_LIFETIME = 4
local LANDING_LIFETIME = 0.6

--// Functions \\--

local function playSound(soundName: string, parent: Instance)
	local sound = Sounds.GetSound("SFX", soundName, "Moves.DaggerThrow")

	if sound then
		sound.Parent = parent
		sound:Play()
		DebrisService:AddItem(sound, SOUND_LIFETIME)
	end
end

local function hideHeldWeapon(character: Instance?, duration: number)
	if typeof(character) ~= "Instance" then
		return
	end

	local weapon = character:FindFirstChild(EQUIPPED_NAME)

	if not weapon then
		return
	end

	local saved = {}

	for _, descendant in weapon:GetDescendants() do
		if descendant:IsA("BasePart") then
			saved[descendant] = descendant.Transparency
			descendant.Transparency = 1
		end
	end

	task.delay(duration, function()
		for part, transparency in saved do
			if part.Parent then
				part.Transparency = transparency
			end
		end
	end)
end

local function createDagger(): Model
	local dagger = daggerTemplate:Clone()

	for _, descendant in dagger:GetDescendants() do
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
	dagger.Parent = workspace.Effects

	return dagger
end

return function(data)
	if typeof(data.origin) ~= "Vector3" or typeof(data.direction) ~= "Vector3" then
		return
	end

	local origin = data.origin
	local direction = data.direction
	local distance = data.distance or 0
	local speed = math.max(data.speed or 1, 1)

	hideHeldWeapon(data.char, data.hideTime or 0)

	local dagger = createDagger()

	if not dagger.PrimaryPart then
		dagger:Destroy()
		return
	end

	playSound("Throw", dagger.PrimaryPart)

	local travelled = 0

	while travelled < distance do
		travelled = math.min(travelled + RunService.Heartbeat:Wait() * speed, distance)

		local position = origin + direction * travelled

		dagger:PivotTo(CFrame.lookAt(position, position + direction))
	end

	if data.hit then
		playSound("Hit", dagger.PrimaryPart)
	end

	DebrisService:AddItem(dagger, LANDING_LIFETIME)
end
