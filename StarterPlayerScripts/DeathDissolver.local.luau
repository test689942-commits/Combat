-- Dissolve characters a few seconds after they die, leaving time for their ragdoll to settle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DEATH_RAGDOLL_WAIT = 3
local DISSOLVE_TIME = 1.25
local DISSOLVE_RESOLUTION = 128

local playerModule = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Dissolver")
local cachedDissolver
local attemptedDissolverLoad = false
local warnedDissolverLoad = false
local watchedHumanoids = setmetatable({}, {__mode = "k"})
local scheduledDeaths = setmetatable({}, {__mode = "k"})

local function getDissolver()
	if attemptedDissolverLoad then
		return cachedDissolver
	end

	attemptedDissolverLoad = true
	if not playerModule:FindFirstChild("Actor") then
		if not warnedDissolverLoad then
			warn("Dissolver is missing its Actor worker child; using a normal fade until that child is included")
			warnedDissolverLoad = true
		end
		return nil
	end

	local success, result = pcall(require, playerModule)
	if success then
		cachedDissolver = result
	else
		if not warnedDissolverLoad then
			warn("Death dissolve module could not load; using a normal fade instead: " .. tostring(result))
			warnedDissolverLoad = true
		end
	end

	return cachedDissolver
end

local function fadeInstance(instance: Instance, duration: number)
	if instance:IsA("BasePart") then
		TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			LocalTransparencyModifier = 1,
		}):Play()
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			Transparency = 1,
		}):Play()
	end
end

local function sameTextureGroup(left, right): boolean
	return left.ColorMap == right.ColorMap
		and left.MetalnessMap == right.MetalnessMap
		and left.NormalMap == right.NormalMap
		and left.RoughnessMap == right.RoughnessMap
		and left.EmissiveMask == right.EmissiveMask
end

local function makeDissolverGroups(dissolverModule, character: Model)
	local groups = {}

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("MeshPart") and descendant.Name ~= "HumanoidRootPart" then
			local success, textureGroup = pcall(dissolverModule.NewTextureGroupFromMesh, descendant)
			if success and textureGroup then
				local group
				for _, existing in ipairs(groups) do
					if sameTextureGroup(existing.TextureGroup, textureGroup) then
						group = existing
						break
					end
				end

				if not group then
					group = {TextureGroup = textureGroup, MeshParts = {}}
					table.insert(groups, group)
				end
				table.insert(group.MeshParts, descendant)
			end
		end
	end

	return groups
end

local function playMeshDissolve(dissolverModule, group, setting)
	task.spawn(function()
		local success, dissolver = pcall(
			dissolverModule.NewDissolver,
			group.TextureGroup,
			setting,
			group.MeshParts
		)

		if not success or not dissolver then
			for _, meshPart in ipairs(group.MeshParts) do
				if meshPart.Parent then
					fadeInstance(meshPart, DISSOLVE_TIME)
				end
			end
			if not success then
				warn("Dissolver could not prepare a character mesh; using a normal fade: " .. tostring(dissolver))
			end
			return
		end

		local cleanedUp = false
		local function finishDissolve()
			if cleanedUp then
				return
			end
			cleanedUp = true

			for _, meshPart in ipairs(group.MeshParts) do
				if meshPart.Parent then
					meshPart.LocalTransparencyModifier = 1
				end
			end
			dissolver:Destroy()
		end

		dissolver.DissolveFinished:Once(function()
			-- The module fires this event just before its final texture update.
			task.delay(0.1, finishDissolve)
		end)

		local started, errorMessage = pcall(function()
			dissolver:Dissolve(1)
		end)
		if not started then
			warn("Dissolver animation failed; using a normal fade: " .. tostring(errorMessage))
			finishDissolve()
			for _, meshPart in ipairs(group.MeshParts) do
				if meshPart.Parent then
					meshPart.LocalTransparencyModifier = 0
					fadeInstance(meshPart, DISSOLVE_TIME)
				end
			end
			return
		end

		-- Ensure EditableImages and SurfaceAppearances are released if the event is missed.
		task.delay(DISSOLVE_TIME + 1, finishDissolve)
	end)
end

local function dissolveCharacter(character: Model)
	if not character.Parent then
		return
	end

	local dissolverModule = getDissolver()
	local groups = if dissolverModule then makeDissolverGroups(dissolverModule, character) else {}
	local meshPartSet = {}
	for _, group in ipairs(groups) do
		for _, meshPart in ipairs(group.MeshParts) do
			meshPartSet[meshPart] = true
		end
	end

	-- Standard R6 body parts are Parts rather than MeshParts, so fade those locally.
	for _, descendant in ipairs(character:GetDescendants()) do
		if not meshPartSet[descendant] then
			fadeInstance(descendant, DISSOLVE_TIME)
		end
	end

	if not dissolverModule then
		return
	end

	local settingSuccess, setting = pcall(dissolverModule.NewSetting, DISSOLVE_TIME, DISSOLVE_RESOLUTION)
	if not settingSuccess then
		for _, group in ipairs(groups) do
			for _, meshPart in ipairs(group.MeshParts) do
				if meshPart.Parent then
					fadeInstance(meshPart, DISSOLVE_TIME)
				end
			end
		end
		warn("Dissolver settings could not be created; using a normal fade: " .. tostring(setting))
		return
	end

	for _, group in ipairs(groups) do
		playMeshDissolve(dissolverModule, group, setting)
	end
end

local function scheduleDissolve(character: Model)
	if scheduledDeaths[character] then
		return
	end
	scheduledDeaths[character] = true

	task.delay(DEATH_RAGDOLL_WAIT, function()
		if character.Parent then
			dissolveCharacter(character)
		end
	end)
end

local function watchCharacter(character: Model)
	task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			local candidate = character:WaitForChild("Humanoid", 10)
			if candidate and candidate:IsA("Humanoid") then
				humanoid = candidate
			end
		end

		if not humanoid or watchedHumanoids[humanoid] then
			return
		end
		watchedHumanoids[humanoid] = true

		humanoid.Died:Once(function()
			scheduleDissolve(character)
		end)

		if humanoid.Health <= 0 then
			scheduleDissolve(character)
		end
	end)
end

local function watchPlayer(player: Player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

local function isNPCOrDummy(model: Model): boolean
	local npcFolder = Workspace:FindFirstChild("NPCS")
	return model:GetAttribute("Dummy") == true or (npcFolder ~= nil and model:IsDescendantOf(npcFolder))
end

local function watchNPCModel(instance: Instance)
	if not instance:IsA("Model") then
		return
	end

	if isNPCOrDummy(instance) then
		watchCharacter(instance)
		return
	end

	instance:GetAttributeChangedSignal("Dummy"):Connect(function()
		if instance:GetAttribute("Dummy") == true then
			watchCharacter(instance)
		end
	end)
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("Model") then
		watchNPCModel(descendant)
	end
end

Workspace.DescendantAdded:Connect(watchNPCModel)
