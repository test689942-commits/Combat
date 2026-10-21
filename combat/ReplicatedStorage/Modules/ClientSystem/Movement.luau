--// Setup \\--

local Movement = {}
local Client = require(script.Parent)

Movement.__index = Movement

--// Actions \\--

Movement.Landed = function()	
	local Root: BasePart = Client.Root
	local Character: Model = Client.Character
	local Humanoid: Humanoid = Client.Humanoid

	if Humanoid:GetState() == Enum.HumanoidStateType.Freefall or Humanoid:GetState() == Enum.HumanoidStateType.Jumping or Client.Landed then
		return
	end	

	if #Client.Actions > 0 then 
		return
	end


	local Height = (Client.FallHeight - Root.Position.Y)
	if not Height or Height <= 15 then return end

	Client.Landed = true
	local rollanim: Animation = Client.Animations.GetAnimation("Movement", `Roll`)
	local roll: AnimationTrack = Humanoid.Animator:LoadAnimation(rollanim)

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	roll.Priority = Enum.AnimationPriority.Action3; roll:Play(0.1, 1, 1.25)
	table.insert(Client.Speeds, `LandedSpeed{(Height > 30 and -10) or -5}`); 

	roll.Stopped:Once(function() 
		Client.Landed = false; Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		table.remove(Client.Speeds, table.find(Client.Speeds, `LandedSpeed{(Height > 30 and -10) or -5}`))
	end); roll:Play(0.1, 1, 1.25)
end

return Movement


