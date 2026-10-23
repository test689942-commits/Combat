--// Services \\--

local Debris = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local SFX = require(Modules:WaitForChild("Sounds"):WaitForChild("SFX"))
local MovementFX = require(Modules:WaitForChild("ClientSystem"):WaitForChild("MovementFX"))

--// FootSteps \\--

local FootSteps = {}

FootSteps.SoundIds = SFX.Footsteps

FootSteps.MaterialMap = {
	[Enum.Material.Slate] =         FootSteps.SoundIds.Concrete;
	[Enum.Material.Concrete] =      FootSteps.SoundIds.Concrete;
	[Enum.Material.Brick] =         FootSteps.SoundIds.Concrete;
	[Enum.Material.Cobblestone] =   FootSteps.SoundIds.Concrete;
	[Enum.Material.Sandstone] =     FootSteps.SoundIds.Concrete;
	[Enum.Material.Rock] =          FootSteps.SoundIds.Concrete;
	[Enum.Material.Basalt] =        FootSteps.SoundIds.Concrete;
	[Enum.Material.CrackedLava] =   FootSteps.SoundIds.Concrete;
	[Enum.Material.Asphalt] =       FootSteps.SoundIds.Concrete;
	[Enum.Material.Limestone] =     FootSteps.SoundIds.Concrete;
	[Enum.Material.Pavement] =      FootSteps.SoundIds.Concrete;
	[Enum.Material.Plastic] =       FootSteps.SoundIds.Tile;
	[Enum.Material.Marble] =        FootSteps.SoundIds.Tile;
	[Enum.Material.Neon] =          FootSteps.SoundIds.Tile;
	[Enum.Material.Granite] =       FootSteps.SoundIds.Tile;
	[Enum.Material.Wood] =          FootSteps.SoundIds.Wood;
	[Enum.Material.WoodPlanks] =    FootSteps.SoundIds.Wood;
	[Enum.Material.Water] =         FootSteps.SoundIds.Glass;
	[Enum.Material.CorrodedMetal] = FootSteps.SoundIds.Metal_Solid;
	[Enum.Material.DiamondPlate] =  FootSteps.SoundIds.Metal_Solid;
	[Enum.Material.Metal] =         FootSteps.SoundIds.Metal_Solid;
	[Enum.Material.Foil] =          FootSteps.SoundIds.Metal_Grate;
	[Enum.Material.Ground] =        FootSteps.SoundIds.Dirt;
	[Enum.Material.Grass] =         FootSteps.SoundIds.Grass;
	[Enum.Material.LeafyGrass] =    FootSteps.SoundIds.Grass;
	[Enum.Material.Fabric] =        FootSteps.SoundIds.Carpet;
	[Enum.Material.Pebble] =        FootSteps.SoundIds.Gravel;
	[Enum.Material.Snow] =          FootSteps.SoundIds.Snow;
	[Enum.Material.Sand] =          FootSteps.SoundIds.Sand;
	[Enum.Material.Salt] =          FootSteps.SoundIds.Sand;
	[Enum.Material.Ice] =           FootSteps.SoundIds.Glass;
	[Enum.Material.Glacier] =       FootSteps.SoundIds.Glass;
	[Enum.Material.Glass] =         FootSteps.SoundIds.Glass;
	[Enum.Material.SmoothPlastic] = FootSteps.SoundIds.Rubber;
	[Enum.Material.ForceField] =    FootSteps.SoundIds.Rubber;
	[Enum.Material.Mud] =           FootSteps.SoundIds.Mud;
	[Enum.HumanoidStateType.Jumping] = FootSteps.SoundIds.Jump;
}

local function playFootstepVFX(rootPart: BasePart)
	local character = rootPart.Parent
	if not character then
		return
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	local hit = workspace:Raycast(rootPart.Position + Vector3.new(0, 1, 0), Vector3.new(0, -7, 0), rayParams)
	if not hit then
		return
	end

	local up = hit.Normal
	local forward = rootPart.CFrame.LookVector
	local right = forward:Cross(up)
	if right.Magnitude < 0.01 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end
	forward = up:Cross(right).Unit
	local footstepCFrame = CFrame.fromMatrix(hit.Position + up * 0.025, right, up, -forward)
	MovementFX.PlayAt({"FootStep"}, footstepCFrame, 8)
end

function FootSteps.PlayStep(rootPart: BasePart?, materialOrState: any, volume: number?, playbackSpeed: number?, emitVFX: boolean?)
	if not rootPart or not rootPart.Parent then
		return
	end

	local pool = FootSteps.MaterialMap[materialOrState]
	if not pool or #pool == 0 then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = pool[math.random(1, #pool)]
	sound.Volume = volume or 0.35
	sound.PlaybackSpeed = playbackSpeed or (0.95 + math.random() * 0.1)
	sound.RollOffMaxDistance = 65
	sound.Parent = rootPart
	sound:Play()

	-- The ground-step VFX is opt-in so jumping and landing sounds stay particle-free.
	if emitVFX and typeof(materialOrState) == "EnumItem" and materialOrState.EnumType == Enum.Material then
		playFootstepVFX(rootPart)
	end

	Debris:AddItem(sound, 2)
end

return FootSteps
