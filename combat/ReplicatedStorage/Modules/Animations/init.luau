--// Services \\--

local RunService = game:GetService("RunService")
local ContentPA = game:GetService("ContentProvider")

--// Modules \\--

local AnimData = require(script:WaitForChild("Anims"))

--// Variables \\--

local Animations = {}
Animations.__index = Animations

local self = setmetatable({}, Animations)

Animations.Cache = {}
Animations.Temp = {}

local RIG_BATCH_SIZE = 60

--// Functions \\--

local function createAnimation(name: string, id: string): Animation
	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = id

	return animation
end

local function buildCache(node, path: string?)
	for key, value in next, node do
		local keyName = tostring(key)

		if type(value) == "table" then
			local childPath = if path then path .. "." .. keyName else keyName

			buildCache(value, childPath)
		elseif path and type(value) == "string" and value ~= "" then
			if not self.Cache[path] then
				self.Cache[path] = {}
			end

			local animation = createAnimation(keyName, value)

			self.Cache[path][keyName] = animation
			self.Temp[#self.Temp + 1] = animation
		end
	end
end

local function normalizePath(root: string?, sub: string?): (string?, string?)
	if type(root) ~= "string" then
		return root, sub
	end

	local normalizedRoot = root
	if normalizedRoot == "Combat" then
		normalizedRoot = "Shared"
	elseif string.sub(normalizedRoot, 1, 7) == "Combat." then
		normalizedRoot = "Shared." .. string.sub(normalizedRoot, 8)
	end

	local normalizedSub = sub
	if type(normalizedSub) == "string" then
		if normalizedRoot == "Shared.Punch" then
			local index = string.match(normalizedSub, "^Combat(%d+)$")
			if index then
				normalizedSub = "Punch" .. index
			end
		elseif normalizedRoot == "Shared.Idle" and normalizedSub == "Combat" then
			normalizedSub = "Default"
		end
	end

	return normalizedRoot, normalizedSub
end

local function resolveNode(root: string)
	local normalizedRoot = normalizePath(root, nil)
	local node = AnimData

	for _, key in ipairs(string.split(normalizedRoot :: string, ".")) do
		if type(node) ~= "table" then
			return nil
		end

		node = node[key]
	end

	return node
end

local function createRig()
	local preloadRig = script.PreloadRig:Clone()
	preloadRig.Parent = workspace

	return preloadRig
end

local function warmUpAnimation(rig: Model, animation: Animation)
	local track = rig.Humanoid.Animator:LoadAnimation(animation)
	track:Play()
	track:AdjustSpeed(math.huge)

	task.wait()

	track:Stop()
	track:Destroy()
end

local function preloadAnimations()
	local startTime = os.clock()

	ContentPA:PreloadAsync(self.Temp)
	warn(("Animation Preloader Complete; %.2f seconds"):format(os.clock() - startTime))

	local rigs = {}
	local rigCount = 1
	local pendingWarmUps = 0

	for i, animation in ipairs(self.Temp) do
		if i > (RIG_BATCH_SIZE * rigCount) then
			rigCount += 1
		end

		if not rigs[rigCount] then
			rigs[rigCount] = createRig()
		end

		pendingWarmUps += 1

		task.spawn(function()
			warmUpAnimation(rigs[rigCount], animation)

			pendingWarmUps -= 1
		end)
	end

	while pendingWarmUps > 0 do
		task.wait()
	end

	for count, rig in rigs do
		rig:Destroy()
		warn(rig.Name .. count .. " Destroyed")
	end
end

--// Setup \\--

buildCache(AnimData, nil)

if RunService:IsClient() then
	task.spawn(preloadAnimations)
end

--// API \\--

Animations.GetAnimation = function(Root: string, Sub: string): (Animation | nil)
	if not Root or not Sub then
		return nil
	end

	local normalizedRoot, normalizedSub = normalizePath(Root, Sub)

	if self.Cache[normalizedRoot] and self.Cache[normalizedRoot][normalizedSub] then
		return self.Cache[normalizedRoot][normalizedSub]:Clone()
	else
		warn(("Tried To Index Nil Root And Sub : %s | %s"):format(Root, Sub))
		return nil
	end
end

Animations.GetAnimationId = function(Root: string, Sub: string): (string | nil)
	if not Root or not Sub then
		return nil
	end

	local normalizedRoot, normalizedSub = normalizePath(Root, Sub)

	if self.Cache[normalizedRoot] and self.Cache[normalizedRoot][normalizedSub] then
		return self.Cache[normalizedRoot][normalizedSub].AnimationId
	else
		warn(("Tried To Index Nil Root And Sub : %s | %s"):format(Root, Sub))
		return nil
	end
end

Animations.GetAnimationTree = function(Root: string): ({[string]: Animation} | nil)
	if not Root then
		return nil
	end

	local normalizedRoot = normalizePath(Root, nil)

	if self.Cache[normalizedRoot] then
		return self.Cache[normalizedRoot]
	else
		warn(("Tried To Index Nil Root : %s"):format(Root))
		return nil
	end
end

Animations.GetIndexedAnimation = function(Root: string, Index: number?): (Animation | nil)
	local node = resolveNode(Root)

	if type(node) ~= "table" or #node == 0 then
		warn(("Tried To Index Nil Indexed Root : %s"):format(Root))
		return nil
	end

	local safeIndex = Index

	if typeof(safeIndex) ~= "number" or node[safeIndex] == nil then
		safeIndex = 1
	end

	return Animations.GetAnimation(Root, tostring(safeIndex))
end

Animations.PickRandomIndex = function(Root: string): number
	local node = resolveNode(Root)

	if type(node) ~= "table" or #node == 0 then
		return 1
	end

	return math.random(1, #node)
end

Animations.DetectAnimation = function(Sub: string)
	if not Sub then
		return false
	end

	for _, Module in pairs(self.Cache) do
		if Module[Sub] then
			return true
		end
	end

	return false
end

Animations.DetectSpecificAnimation = function(Root: string, Sub: string)
	local normalizedRoot, normalizedSub = normalizePath(Root, Sub)

	if not normalizedRoot or not self.Cache[normalizedRoot] then
		return
	end

	if self.Cache[normalizedRoot][normalizedSub] then
		return true
	end

	return false
end

return Animations
