--// Services \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Variables \\--

local MainHandler = require(ReplicatedStorage.Modules.Shared:WaitForChild("MainHandler"))
local HitDetection = require(ReplicatedStorage.Modules.Shared:WaitForChild("HitDetection"))

local Rage = {}

local effectsRemote = ReplicatedStorage.Remotes.Effects
local auraTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("RageAura")

local activeAuras = setmetatable({}, {__mode = "k"})

--// Aura \\--

local function clearAura(character: Model)
	local pieces = activeAuras[character]

	if not pieces then
		return
	end

	for _, piece in pieces do
		piece:Destroy()
	end

	activeAuras[character] = nil
end

local function applyAura(character: Model)
	clearAura(character)

	local pieces = {}

	for _, partFolder in auraTemplate:GetChildren() do
		local part = character:FindFirstChild(partFolder.Name)

		if part and part:IsA("BasePart") then
			local copy = partFolder:Clone()

			for _, child in copy:GetChildren() do
				child.Parent = part
				table.insert(pieces, child)
			end

			copy:Destroy()
		end
	end

	activeAuras[character] = pieces
end

--// Stun \\--

local function stunNearby(character: Model, root: BasePart, settings)
	local boxSize = Vector3.new(settings.Radius * 2, settings.VerticalReach * 2, settings.Radius * 2)
	local ignoreList = {workspace.Effects, workspace.Debris, character}
	local targets = HitDetection.GetCharactersInBox(root.CFrame, boxSize, ignoreList, "MoveHit")

	for _, target in targets do
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		local targetRoot = target:FindFirstChild("HumanoidRootPart")

		if humanoid and targetRoot and humanoid.Health > 0 and (targetRoot.Position - root.Position).Magnitude <= settings.Radius then
			MainHandler.CreateTing("BoolValue", {Parent = target, Name = "Stun"}, settings.StunTime)
		end
	end
end

--// Move \\--

function Rage.Activate(_player: Player, character: Model, settings, _aimPosition: Vector3?)
	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		return
	end

	effectsRemote:FireAllClients(settings.EntryName, {
		root = root,
		char = character,
		delay = settings.EffectDelay,
	})

	task.wait(settings.EffectDelay)

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then
		return
	end

	stunNearby(character, root, settings)

	local token = (character:GetAttribute(settings.AttributeName .. "Token") or 0) + 1

	character:SetAttribute(settings.AttributeName .. "Token", token)
	character:SetAttribute(settings.AttributeName, true)
	applyAura(character)

	task.delay(settings.Duration, function()
		if character.Parent and character:GetAttribute(settings.AttributeName .. "Token") == token then
			character:SetAttribute(settings.AttributeName, nil)
			clearAura(character)
		end
	end)
end

return Rage
