--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

--// Modules \\--

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EffectsBase = require(Modules:WaitForChild("EffectsBase"))
local EmitModule = EffectsBase.EmitModule

--// MovementFX \\--

local MovementFX = {}

local function normalizeKey(text: string): string
	return string.lower((string.gsub(text, "[%s_]+", "")))
end

local function getEffectsRoot(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Effects")
end

function MovementFX.FindTemplate(candidateNames: {string}): Instance?
	local effectsFolder = getEffectsRoot()
	local movementFolder = effectsFolder and effectsFolder:FindFirstChild("Movement")
	if not movementFolder then
		return nil
	end

	-- Restrict movement VFX lookup to Assets.Effects.Movement. Searching all
	-- Effects descendants can accidentally select similarly named combat VFX
	-- (for example, a Greatsword effect named "Jump").
	for _, name in ipairs(candidateNames) do
		local exact = movementFolder:FindFirstChild(name) or movementFolder:FindFirstChild(name, true)
		if exact then
			return exact
		end
	end

	local targetKeys = {}
	for _, name in ipairs(candidateNames) do
		targetKeys[normalizeKey(name)] = true
	end

	for _, descendant in ipairs(movementFolder:GetDescendants()) do
		if targetKeys[normalizeKey(descendant.Name)] then
			return descendant
		end
	end

	return nil
end

local function mountEffectClone(clone: Instance, targetPart: BasePart): {Instance}
	local cleanupList = {clone}

	if clone:IsA("Attachment") then
		clone.Parent = targetPart
	elseif clone:IsA("BasePart") then
		clone.Anchored = false
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Massless = true
		clone.CFrame = targetPart.CFrame
		clone.Parent = targetPart

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = targetPart
		weld.Part1 = clone
		weld.Parent = clone
		table.insert(cleanupList, weld)
	elseif clone:IsA("Model") then
		clone:PivotTo(targetPart.CFrame)
		clone.Parent = targetPart

		local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = false
				desc.CanCollide = false
				desc.CanQuery = false
				desc.CanTouch = false
				desc.Massless = true
			end
		end
		if primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = targetPart
			weld.Part1 = primary
			weld.Parent = primary
			table.insert(cleanupList, weld)
		end
	else
		clone.Parent = targetPart
	end

	return cleanupList
end

local function emitWithAttributes(container: Instance)
	pcall(function()
		EmitModule.Emit(container)
	end)

	local list = container:GetDescendants()
	table.insert(list, 1, container)

	for _, inst in ipairs(list) do
		if inst:IsA("ParticleEmitter") then
			local emitDelay = tonumber(inst:GetAttribute("EmitDelay")) or 0
			local emitDuration = tonumber(inst:GetAttribute("EmitDuration")) or 0
			local rawCount = inst:GetAttribute("EmitCount")
			local emitCount = tonumber(rawCount)

			local function trigger()
				if not inst.Parent then
					return
				end

				if emitDuration > 0 then
					inst.Enabled = true
					task.delay(emitDuration, function()
						if inst.Parent then
							inst.Enabled = false
						end
					end)
				end

				if emitCount and emitCount > 0 then
					inst:Emit(emitCount)
				elseif emitDuration <= 0 and rawCount == nil then
					local fallback = math.clamp(math.ceil(inst.Rate * 0.15), 1, 20)
					inst:Emit(fallback)
				end
			end

			if emitDelay > 0 then
				task.delay(emitDelay, trigger)
			else
				trigger()
			end
		end
	end
end

function MovementFX.PlayAt(candidateNames: {string}, effectCFrame: CFrame, cleanupAfter: number?)
	local template = MovementFX.FindTemplate(candidateNames)
	if not template then
		return
	end

	local clone = template:Clone()
	local worldEffects = workspace:FindFirstChild("Effects") or workspace
	local cleanupRoot: Instance = clone

	if clone:IsA("Attachment") or clone:IsA("Folder") then
		local holder = Instance.new("Part")
		holder.Name = "MovementVFXAnchor"
		holder.Size = Vector3.new(0.1, 0.1, 0.1)
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CFrame = effectCFrame
		holder.Parent = worldEffects
		clone.Parent = holder
		cleanupRoot = holder
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CFrame = effectCFrame
		clone.Parent = worldEffects
	elseif clone:IsA("Model") then
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		clone:PivotTo(effectCFrame)
		clone.Parent = worldEffects
	else
		clone.Parent = worldEffects
	end

	emitWithAttributes(clone)
	Debris:AddItem(cleanupRoot, cleanupAfter or 2)
end

function MovementFX.PlayOnce(character: Model?, candidateNames: {string}, targetPartName: string?, cleanupAfter: number?, attachmentPosition: Vector3?)
	if not character then
		return
	end

	local targetPart = (targetPartName and character:FindFirstChild(targetPartName))
		or character:FindFirstChild("HumanoidRootPart")
	if not targetPart or not targetPart:IsA("BasePart") then
		return
	end

	local template = MovementFX.FindTemplate(candidateNames)
	if not template then
		return
	end

	local clone = template:Clone()
	if clone:IsA("Attachment") and attachmentPosition then
		clone.Position = attachmentPosition
	end
	local mounted = mountEffectClone(clone, targetPart)

	emitWithAttributes(clone)

	local lifetime = cleanupAfter or 2.5
	for _, item in ipairs(mounted) do
		Debris:AddItem(item, lifetime)
	end
end

function MovementFX.StartLoop(character: Model?, candidateNames: {string}, targetPartName: string?): () -> ()
	if not character then
		return function() end
	end

	local targetPart = (targetPartName and character:FindFirstChild(targetPartName))
		or character:FindFirstChild("HumanoidRootPart")
	if not targetPart or not targetPart:IsA("BasePart") then
		return function() end
	end

	local template = MovementFX.FindTemplate(candidateNames)
	if not template then
		return function() end
	end

	local clone = template:Clone()
	local mounted = mountEffectClone(clone, targetPart)

	local emitters = {}
	local list = clone:GetDescendants()
	table.insert(list, 1, clone)

	for _, inst in ipairs(list) do
		if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
			inst.Enabled = true
			table.insert(emitters, inst)
		end
	end

	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true

		for _, emitter in ipairs(emitters) do
			if emitter.Parent then
				emitter.Enabled = false
			end
		end

		for _, item in ipairs(mounted) do
			if item.Parent then
				Debris:AddItem(item, 1.5)
			end
		end
	end
end

return MovementFX
