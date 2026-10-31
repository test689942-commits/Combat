local module = {}
module.__index = module
local self = setmetatable({}, module)

local Utilities 	   = require(script.Parent.Utilities)
local AnimationsModule = require(script.Parent.Parent:WaitForChild("Animations"));

--// Character Function Library \\--

local Debris = Utilities.Debris

local Animations = {};
local Cooldowns  = {};

module.PlayAnimation = function(Char: Model, Class: string, Name: string, Transition: number, Priority: Enum.AnimationPriority?) : AnimationTrack
	if not Char then return end;
	if not Animations[Char.Name] then Animations[Char.Name] = {} end

	local Anim = AnimationsModule.GetAnimation(Class, Name);

	if Anim and Anim ~= nil then
		Animations[Char.Name][Name] = Char.Humanoid.Animator:LoadAnimation(Anim)
		if Priority then
			Animations[Char.Name][Name].Priority = Priority
		end
		Animations[Char.Name][Name]:Play(Transition)
		Anim:Destroy();
		return Animations[Char.Name][Name]
	end
end

module.StopAllAnims = function(Char: Model)
	if not Char or not Char:GetAttribute("Weapon") then return end 
	for _, v in next, Char.Humanoid.Animator:GetPlayingAnimationTracks() do
		if v then 
			if tonumber(v.Name) or AnimationsModule.DetectAnimation(v.Name) then
				if v.Name == "Counter" or v.Name == "Idle" or v.Name == "DSIdle" or v.Name == "walk" or v.Name == "Walk" or v.Name == "run" or v.Name == "Run" or v.Name == "Sprint" or v.Name == "GuardBreak" then continue end
				v:Stop(.2)
			end
		end
	end
end

module.SetCooldown = function(Char: Model, Identifier: string, Time: number)
	if Char:GetAttribute("CDModify") then return end
	if not Cooldowns[Char.Name] then Cooldowns[Char.Name] = {} end;
	Cooldowns[Char.Name][Identifier] = os.clock() + Time
end

module.CheckCooldown = function(Char: Model, Identifier: string)
	if Char:GetAttribute("CDModify") then return end
	if not Cooldowns[Char.Name] then Cooldowns[Char.Name] = {} end;
	if Cooldowns[Char.Name][Identifier] then 
		if Cooldowns[Char.Name][Identifier] > os.clock()  then
			return true;
		else
			Cooldowns[Char.Name][Identifier] = nil
			return false;
		end
	end;

	return false;
end

module.GetCooldownRemaining = function(Char: Model, Identifier: string)
	if Char:GetAttribute("CDModify") then return 0 end
	if not Cooldowns[Char.Name] or not Cooldowns[Char.Name][Identifier] then return 0 end

	return math.max(0, Cooldowns[Char.Name][Identifier] - os.clock())
end

module.ResetCooldown = function(Char: Model, Identifier: string)
	if not Cooldowns[Char.Name] then Cooldowns[Char.Name] = {} end;
	if Cooldowns[Char.Name][Identifier] ~= nil then Cooldowns[Char.Name][Identifier] = 0 end;
end

module.Remove = function(Char)
	if Animations[Char.Name] then Animations[Char.Name] = nil end;
	if Cooldowns[Char.Name] then Cooldowns[Char.Name] = nil end;
end

return module
