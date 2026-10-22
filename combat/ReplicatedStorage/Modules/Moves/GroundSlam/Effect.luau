-- Services
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ContextActionService = game:GetService("ContextActionService")
-- Instances
local modules = ReplicatedStorage.Modules
local skillAssets = ReplicatedStorage.Assets
local particles = skillAssets.Effects

local DebrisFolder = workspace.Debris
--
local EffectsBase = require(modules:WaitForChild("EffectsBase"))
local EmitModule = EffectsBase.EmitModule
local Sounds = require(modules:WaitForChild("Sounds"))

return function( Data )
	local Root:Part = Data.root
	local Character = Data.char

	local impactSound = Sounds.GetSound("SFX", "GroundSlam", "Moves")

	if impactSound then
		impactSound.Parent = Root
		impactSound:Play()
		Debris:AddItem(impactSound, 5)
	end
	
	local w1 = particles.Stab2:Clone()
	w1.Parent = DebrisFolder
	w1.CFrame = Root.CFrame * CFrame.Angles(0,0,math.rad(90))
	w1.Mesh.Scale = Vector3.new(1,0.01,0.01)

	TweenService:Create(w1.Mesh, 
		TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			Scale = Vector3.new(0.3,1,1),
		}
	):Play()

	local Wind = particles.Wind2:Clone()
	Wind.Parent = DebrisFolder
	Wind.CFrame = Root.CFrame * CFrame.Angles(0,0,math.rad(90))
	Wind.Mesh.Scale = Vector3.new(2,0.01,0.01)

	TweenService:Create(Wind.Mesh, 
		TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			Scale = Vector3.new(.5,1,1),
		}
	):Play()
	TweenService:Create(Wind, 
		TweenInfo.new(.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			CFrame = Wind.CFrame * CFrame.Angles(math.rad(math.random(-90,90)),0,0)
		}
	):Play()
	TweenService:Create(Wind.Decal, 
		TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{Transparency = 1}
	):Play()

	local Wind1 = particles.Wind1:Clone()
	Wind1.Parent = DebrisFolder
	Wind1.CFrame = Root.CFrame * CFrame.Angles(0,0,math.rad(90))
	Wind1.Mesh.Scale = Vector3.new(2,0.01,0.01)

	TweenService:Create(Wind1.Mesh, 
		TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			Scale = Vector3.new(.5,1.7,1.7),
		}
	):Play()
	TweenService:Create(Wind1.Decal, 
		TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{Transparency = 1}
	):Play()

	wait(.1)
	TweenService:Create(w1.Decal, 
		TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			Transparency = 1
		}
	):Play()

	Debris:AddItem(w1,0.5)

	local _, floorResult = EmitModule.EmitAndRemove(particles.groundslam,Root.CFrame,{maxFloorDist = 20})

	local impactPosition = if floorResult then floorResult.Position + Vector3.new(0,1.5,0) else Root.Position
	EmitModule.EmitAndRemove(particles.Impact,CFrame.new(impactPosition),{noAutoSmoke = true})
	
	local ring = particles.inversRing:Clone()
	ring.Parent = DebrisFolder
	ring.CFrame = Root.CFrame * CFrame.new(0,-2,0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0))
	EffectsBase.TM.Clasic_tween(ring , {size = Vector3.new(35 ,0,35),startSize = Vector3.new(5,50,5) , sizeTim = 0.5/1.5,tim = 0.5 ,EasingStyle = Enum.EasingStyle.Exponential,EasingDirection = Enum.EasingDirection.Out,trans = 1,transTim = .5  ,startTrans = .5,	})
	ring.Material = Enum.Material.Neon
	game.Debris:AddItem(ring, 0.5 * 1.5)

	TweenService:Create(Wind.Mesh, 
		TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			Scale = Vector3.new(0,1.3,1.3),
		}
	):Play()
	TweenService:Create(Wind1.Mesh, 
		TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			Scale = Vector3.new(0,1.7,1.7),
		}
	):Play()

	Debris:AddItem(Wind,1)
	Debris:AddItem(w1,1)
	Debris:AddItem(Wind1,1)
end