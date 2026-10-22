--// Services \\--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Variables \\--

local HitDetection = {}

local STORAGE_NAME = "Debris"
local SHOW_ATTRIBUTE = "ShowHitboxes"
local DEBUG_LIFETIME = 0.4
local DEBUG_TRANSPARENCY = 0.55
local DEBUG_MISS_COLOR = Color3.fromRGB(255, 70, 70)
local DEBUG_HIT_COLOR = Color3.fromRGB(70, 255, 110)

local HitboxModule = nil

--// Hitbox module \\--

local function getHitboxModule()
	if not HitboxModule then
		HitboxModule = require(ReplicatedStorage.Modules:WaitForChild("Hitbox"))
	end

	return HitboxModule
end

if RunService:IsServer() then
	getHitboxModule()
end

--// Debug \\--

local function shouldShowHitboxes(): boolean
	local setting = ReplicatedStorage:GetAttribute(SHOW_ATTRIBUTE)

	if setting ~= nil then
		return setting == true
	end

	return false
end

local function styleDebugPart(hitPart: BasePart)
	hitPart.Transparency = DEBUG_TRANSPARENCY
	hitPart.Color = DEBUG_MISS_COLOR
	hitPart.Material = Enum.Material.SmoothPlastic
	hitPart.CastShadow = false
	hitPart.CanQuery = false
	hitPart.CanTouch = false
end

--// Helpers \\--

local function buildParams(ignoreList: {Instance}): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList

	return params
end

local function getStorage(): Instance
	return workspace:FindFirstChild(STORAGE_NAME) or workspace
end

local function queryCharacters(cframe: CFrame, size: Vector3 | number, ignoreList: {Instance}, label: string?): {Model}
	local hitboxModule = getHitboxModule()
	local showHitboxes = shouldShowHitboxes()
	local hitPart = hitboxModule.Part(size)
	local container = hitPart.Parent

	container.Name = "Hitbox_" .. (label or "Query")
	container.Parent = getStorage()
	hitPart.CFrame = cframe

	if showHitboxes then
		styleDebugPart(hitPart)
	end

	local hitbox = hitboxModule.New(hitPart, buildParams(ignoreList))

	local success, result = pcall(function()
		return hitbox:Once()
	end)

	hitbox:Destroy()

	if not success then
		warn("HitDetection query failed: " .. tostring(result))
		result = {}
	end

	if showHitboxes then
		hitPart.Color = if #result > 0 then DEBUG_HIT_COLOR else DEBUG_MISS_COLOR

		task.delay(DEBUG_LIFETIME, function()
			container:Destroy()
		end)
	else
		container:Destroy()
	end

	return result
end

--// Lag Compensation \\--

local BASE_COMPENSATION = 0.04
local MAX_COMPENSATION = 0.25
local MAX_LEAD_DISTANCE = 8

local function getCompensationTime(character: Model): number
	local player = Players:GetPlayerFromCharacter(character)

	if not player then
		return 0
	end

	return math.min(player:GetNetworkPing() + BASE_COMPENSATION, MAX_COMPENSATION)
end

function HitDetection.GetAttackCFrame(character: Model, forwardOffset: number): CFrame
	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		return CFrame.new()
	end

	local velocity = root.AssemblyLinearVelocity
	local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local lead = planarVelocity * getCompensationTime(character)

	if lead.Magnitude > MAX_LEAD_DISTANCE then
		lead = lead.Unit * MAX_LEAD_DISTANCE
	end

	local rootCFrame = CFrame.new(root.Position + lead) * root.CFrame.Rotation

	return rootCFrame * CFrame.new(0, 0, -forwardOffset)
end

--// Queries \\--

function HitDetection.GetCharactersInBox(cframe: CFrame, size: Vector3, ignoreList: {Instance}, label: string?): {Model}
	return queryCharacters(cframe, size, ignoreList, label)
end

function HitDetection.GetCharactersInSphere(position: Vector3, radius: number, ignoreList: {Instance}, label: string?): {Model}
	return queryCharacters(CFrame.new(position), radius * 2, ignoreList, label)
end

return HitDetection
