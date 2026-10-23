--// Services \\--

local Debris = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SFX = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Sounds"):WaitForChild("SFX"))

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

function FootSteps.PlayStep(rootPart: BasePart?, materialOrState: any, volume: number?, playbackSpeed: number?)
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

	Debris:AddItem(sound, 2)
end

return FootSteps
