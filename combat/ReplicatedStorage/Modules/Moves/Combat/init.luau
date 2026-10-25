local Main = {}

local Tween = game:GetService("TweenService")

local MainHandler = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("MainHandler"))
local CombatInfo = require(game.ReplicatedStorage.Modules:WaitForChild("Moves")).Combat
local RockModule = require(script:WaitForChild("RockModule"))

local AnimationsModule = require(game.ReplicatedStorage.Modules:WaitForChild("Animations"))

local EffFold = game.ReplicatedStorage.Assets.Effects:WaitForChild("Combat")

local Sounds = require(game.ReplicatedStorage.Modules:WaitForChild("Sounds"))
local WeaponFX = require(script:WaitForChild("WeaponFX"))
local Weapons = require(game.ReplicatedStorage.Modules:WaitForChild("Weapons"))

--// Sounds \\--

local function PlayCombatSound(Category, Name, Parent, DebrisTime)
	local SoundObject = Sounds.GetSound("SFX", Name, Category)

	if not SoundObject then
		return
	end

	MainHandler.Sound(SoundObject, {Parent = Parent}, DebrisTime)
	SoundObject:Destroy()
end

function Beams(MainCFrame,Properties,width)
	if MainCFrame ~= nil and Properties ~= nil then
		for i=1,Properties.Count do
			local Sphere = EffFold:WaitForChild("Sphere"):Clone()
			Sphere.Parent = workspace.Effects
			Sphere.CFrame = MainCFrame * CFrame.Angles(math.random(360),math.random(360),math.random(360))
			Sphere.Size = Vector3.new(width or 0.3, math.random(Properties.Size[1],Properties.Size[2]), width or 0.3)
			Sphere.Color = Properties.Color

			Tween:Create(Sphere, TweenInfo.new(Properties.Debris - 0.02,Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {CFrame = Sphere.CFrame*CFrame.new(0,Properties.GoalPos,0),Size = Vector3.new(0,Sphere.Size.Y,0),Transparency = 0}):Play()

			game.Debris:AddItem(Sphere,Properties.Debris)
		end
	end
end

function CharEff(Char,Colorr)
	if Char ~= nil then
		local Highlight = Instance.new("Highlight")
		Highlight.Parent = Char
		Highlight.Enabled = true
		Highlight.OutlineTransparency = 0
		Highlight.FillTransparency = 0
		if Colorr == nil then
			Highlight.FillColor = Color3.fromRGB(255, 255, 255)
			Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		else
			Highlight.FillColor = Colorr
			Highlight.OutlineColor = Colorr
		end
		Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		Tween:Create(Highlight, TweenInfo.new(.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {OutlineTransparency = 1, FillTransparency = 1}):Play()
		game.Debris:AddItem(Highlight,1.5)
	end
end

function Main.Effect(Character,Count,Type,MaxCount,Char2,SlamProps)
	if Character ~= nil and Count ~= nil and Character:FindFirstChild("Humanoid") ~= nil and Character.Humanoid.Health > 0 and Character:FindFirstChild("HumanoidRootPart") ~= nil and Type ~= nil and MaxCount ~= nil then
		--// Variables
		local Humrp = Character:FindFirstChild("HumanoidRootPart")
		local Hum = Character:FindFirstChild("Humanoid")
		if Type == "Punch" then
			CharEff(Character,nil)
			local hit = WeaponFX.HitEffects(Character, Char2, Count)
			MainHandler.Animation(AnimationsModule.GetAnimation("Shared.Stun","Hit"..Count),Hum)
			WeaponFX.OnImpact(Char2, Character, hit)

		elseif Type == "Block Break" then
			
			MainHandler.Animation(AnimationsModule.GetAnimation("Shared.Block","BlockBreak"),Hum)
			_G.EffectEmitter(EffFold["Block Break"]:WaitForChild("Break"),{Parent = Humrp,Debris = 1.5})
			PlayCombatSound("Combat.Punch", "Block Break", Humrp, 2.5)
			
		elseif Type == "BlockHit" then
			
			MainHandler.Animation(AnimationsModule.GetAnimation("Shared.Block","BlockHit"),Hum)
			_G.EffectEmitter(EffFold.Block:WaitForChild("Blocking"),{Parent = Humrp,Debris = 1.5})
			PlayCombatSound("Combat.Punch", "Block", Humrp, 1.5)
			
		elseif Type == "PB" then
			
			if Character ~= nil and Character:FindFirstChild("Humanoid") ~= nil and Character.Humanoid.Health > 1 then
				MainHandler.StopAnimation("Combat"..Count,Character.Humanoid)
				MainHandler.Animation(AnimationsModule.GetAnimation("Shared.Block","BlockBreak"),Character.Humanoid)
			end
			_G.EffectEmitter(EffFold.Parry:WaitForChild("ATM"),{Parent = Humrp,Debris = 1.5})
			PlayCombatSound("Combat.Punch", "Parry", Humrp, 1.5)
			
		elseif Type == "Parry" then

			if Character.Humanoid.Health > 1 then
				WeaponFX.ClearSwing(Hum)
				MainHandler.StopAnimation("Combat"..tostring(Count),Hum)
				if typeof(Count) == "string" then
					MainHandler.StopAnimation(Count,Hum)
				end
				local movesTree = AnimationsModule.GetAnimationTree("Moves")
				if movesTree ~= nil then
					for moveAnimName in pairs(movesTree) do
						MainHandler.StopAnimation(moveAnimName,Hum)
					end
				end
				MainHandler.Animation(AnimationsModule.GetAnimation("Shared.Parry","Parried"),Hum,nil,Enum.AnimationPriority.Action4)
			end

			if Char2 ~= nil and Char2:FindFirstChild("Humanoid") ~= nil and Char2:FindFirstChild("HumanoidRootPart") ~= nil then
				MainHandler.StopAnimation("Blocking",Char2.Humanoid)
				MainHandler.Animation(AnimationsModule.GetAnimation("Shared.Parry","Parry"),Char2.Humanoid,nil,Enum.AnimationPriority.Action4)
				_G.EffectEmitter(EffFold.Parry:WaitForChild("ATM"),{Parent = Char2.HumanoidRootPart,Debris = 1.5})
			end

			PlayCombatSound("Combat.Punch", "Parry", Humrp, 1.5)

		elseif Type == "Up" then
			
			--// Effect //--
			CharEff(Character,nil)
			_G.EffectEmitter(EffFold.Fists:WaitForChild("Hit"),{Parent = Humrp,Debris = 1.5})
			--// Sound //--
			PlayCombatSound("Combat.Punch", "Punch" .. Count, Humrp, 1.5)
			--// ANIMATION //--
			MainHandler.Animation(AnimationsModule.GetAnimation("Shared.Stun","Hit3"),Hum)
			
		elseif Type == "UpFX" then
			
			--// Levitating Rocks //--
			for i=1,5 do
				local rock = Instance.new("Part")
				rock.Size = Vector3.new(
					math.random(100, 200) / 100,  -- Generates a random number between 1.00 and 2.00
					math.random(100, 200) / 100,  -- Generates a random number between 1.00 and 2.00
					math.random(100, 200) / 100   -- Generates a random number between 1.00 and 2.00
				)
				
				local direction = Humrp.CFrame.UpVector * -10

				-- Set up RaycastParams
				local raycastParams = RaycastParams.new()
				raycastParams.FilterDescendantsInstances = {Character,workspace.Effects,workspace.NPCS} 
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude

				-- Perform the raycast
				local result = workspace:Raycast(Humrp.Position, direction, raycastParams)

				rock.Anchored = false
				rock.Parent = workspace.Effects
				rock.CanCollide = true
				
				if result then
					rock.Material = result.Instance.Material
					rock.Color = result.Instance.Color
				else
					rock.Material = Enum.Material.Plastic
					rock.Color = Color3.fromRGB(31, 31, 31)
				end

				rock.CFrame = Humrp.CFrame * CFrame.new(math.random(-10,10),math.random(3,6),math.random(-10,10))
				rock.CFrame *= CFrame.Angles(math.rad(math.random(0,360)),math.rad(math.random(0,360)),math.rad(math.random(0,360)))

				game.Debris:AddItem(rock,3)

				coroutine.resume(coroutine.create(function()
					task.wait(2)
					Tween:Create(rock, TweenInfo.new(1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Size = Vector3.new(0,0,0)}):Play()
				end))

			end
			
			PlayCombatSound("Combat", "Jump2", Humrp, 1.5)
			
			local goUpTemplate = EffFold:FindFirstChild("GoUp") or game.ReplicatedStorage.Assets.Effects:FindFirstChild("GoUp")
			local Particles = goUpTemplate:Clone()
			Particles.Parent = workspace.Effects
			Particles.CFrame = Humrp.CFrame
			Particles.Anchored = true
			Particles.CanCollide = false
			game.Debris:AddItem(Particles,3)
			
			for i,v in pairs(Particles:GetDescendants()) do
				if v:IsA("ParticleEmitter") then
					v:Emit(v:GetAttribute("EmitCount" or 1))
				end
			end
			
			--// Shockwave
			local dashFolder = game.ReplicatedStorage.Assets.Effects:FindFirstChild("Movement") or game.ReplicatedStorage.Assets.Effects:FindFirstChild("Dash") or game.ReplicatedStorage.Assets.Effects:FindFirstChild("DashVFX")
			local Ring = dashFolder:FindFirstChild("Ring"):Clone()
			Ring.CFrame = Humrp.CFrame * CFrame.new(0,-2.3,0)
			Ring.Parent = workspace.Effects
			Ring.Size *= 2
			game.Debris:AddItem(Ring,3)
			Tween:Create(Ring, TweenInfo.new(.25,Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Size = Ring.Size * 2,Transparency = 1}):Play()
			--// Center Thing
			local waveTemplate = EffFold:FindFirstChild("Wave") or game.ReplicatedStorage.Assets.Effects:FindFirstChild("Wave")
			local Center = waveTemplate:Clone()
			Center.CFrame = Humrp.CFrame * CFrame.new(0,-2,0)
			Center.Parent = workspace.Effects
			Center.Orientation += Vector3.new(0,0,180)
			Center.Size = Vector3.new(0.684, 14.553, 0.456)
			game.Debris:AddItem(Center,.45)
			Tween:Create(Center, TweenInfo.new(.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Size = Vector3.new(0.001, 14.553, 0.001),Transparency = 0,CFrame = Center.CFrame * CFrame.new(0,-6,0)}):Play()
			
			
		elseif Type == "Down" then

			--// Effect //--
			CharEff(Character,nil)
			Beams(Humrp.CFrame,{Count = math.random(6,8),Size = {8,10},Color = Color3.fromRGB(255, 255, 255),GoalPos = 20,Debris = .4},1.5)
			_G.EffectEmitter(EffFold.Fists:WaitForChild("Hit"),{Parent = Humrp,Debris = 1.5})
			--// Sound //--
			PlayCombatSound("Combat", "Slam", Humrp, 3)
			--// ANIMATION //--
			MainHandler.Animation(AnimationsModule.GetAnimation("Shared.Stun","SlamStun"),Hum)
			
			local Slam = game.ReplicatedStorage.Assets.Effects.Combat:FindFirstChild("Slam"):Clone()
			Slam.Parent = workspace.Effects
			Slam.CFrame = CFrame.new(SlamProps[2]) * CFrame.new(0,0.5,0)
			Slam.Anchored = true
			Slam.CanCollide = false
			game.Debris:AddItem(Slam,3)
			
			for i,v in pairs(Slam:GetDescendants()) do
				if v:IsA("ParticleEmitter") then
					v:Emit(v:GetAttribute("EmitCount") or 1)
				end
				if v.Name == "Debris" then
					v.Color = ColorSequence.new(SlamProps[3].Color)
				end
			end
			
			task.wait(.15)
			
			--// All Rock Effects //--
			
			--// Levitating Rocks //--
			local slamRadius = 9

			for i=1,8 do
				local rock = Instance.new("Part")
				rock.Size = Vector3.new(
					math.random(100, 200) / 100,  -- Generates a random number between 1.00 and 2.00
					math.random(100, 200) / 100,  -- Generates a random number between 1.00 and 2.00
					math.random(100, 200) / 100   -- Generates a random number between 1.00 and 2.00
				)

				rock.Anchored = false
				rock.Parent = workspace.Effects
				rock.CanCollide = true
				rock.Material = SlamProps[3].Material

				for _, surfaceName in {"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"} do
					rock[surfaceName] = Enum.SurfaceType.Smooth
				end

				rock.Color = SlamProps[3].Color
				
				rock.CFrame = Slam.CFrame * CFrame.new(math.random(-slamRadius,slamRadius),math.random(4,6),math.random(-slamRadius,slamRadius))
				rock.CFrame *= CFrame.Angles(math.rad(math.random(0,360)),math.rad(math.random(0,360)),math.rad(math.random(0,360)))
				
				game.Debris:AddItem(rock,4)
				
				coroutine.resume(coroutine.create(function()
					task.wait(2.5)
					Tween:Create(rock, TweenInfo.new(1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Size = Vector3.new(0,0,0)}):Play()
				end))
				
			end
			
			if RockModule then
				RockModule.new(
					'Crater', -- This is the type of effect you want
					Slam.CFrame, -- This is the start/center point (depending on the effect)
					{
						["HoldTime"] = 1.5;
						['AnimationSpeed'] = .05;
						['PartCount'] = 6;
						['Radius'] = slamRadius
					}
				)
			end
			
		end
	end
end

function Main.Swing(Character,Count,Type)
	if Character ~= nil and Count ~= nil and Character:FindFirstChild("Humanoid") ~= nil and Character.Humanoid.Health > 0 and Character:FindFirstChild("HumanoidRootPart") ~= nil and Type ~= nil then
		local hit = WeaponFX.Swing(Character, Count)
		MainHandler.CreateTing("BoolValue",{Parent = Character, Name = "DoingCombat"},hit.ActionTime)
	end
end

function Main.HeavySwing(Character)
	if Character ~= nil and Character:FindFirstChild("Humanoid") ~= nil and Character.Humanoid.Health > 0 and Character:FindFirstChild("HumanoidRootPart") ~= nil and Weapons.GetEquippedTool(Character) ~= nil then
		local hit = WeaponFX.HeavySwing(Character)
		MainHandler.CreateTing("BoolValue", {Parent = Character, Name = "DoingCombat"}, hit.ActionTime + CombatInfo.CriticalWindup)
	end
end

function Main.BlockAnimation(Character)
	WeaponFX.PlayBlockAnimation(Character)
end

function Main.UpSwing(Character)
	if Character ~= nil and Character:FindFirstChild("Humanoid") ~= nil and Character.Humanoid.Health > 0 and Character:FindFirstChild("HumanoidRootPart") ~= nil then
		--// Variables
		local Humrp = Character:FindFirstChild("HumanoidRootPart")
		local Hum = Character:FindFirstChild("Humanoid")
		if not Weapons.IsFists(Character) then
			local actionTime = WeaponFX.PlayHitUp(Character)

			MainHandler.CreateTing("BoolValue",{Parent = Character, Name = "DoingCombat"},actionTime)

			return
		end

		MainHandler.CreateTing("BoolValue",{Parent = Character, Name = "DoingCombat"},.6)
		PlayCombatSound("Combat.Punch", "Swing", Humrp)
		MainHandler.Animation(AnimationsModule.GetAnimation("Shared.Punch","Punch3"),Hum,nil,Enum.AnimationPriority.Action4)
	
	end
end

function Main.DownSwing(Character,DownSlamIndex)
	if Character ~= nil and Character:FindFirstChild("Humanoid") ~= nil and Character.Humanoid.Health > 0 and Character:FindFirstChild("HumanoidRootPart") ~= nil then
		--// Variables
		local Humrp = Character:FindFirstChild("HumanoidRootPart")
		local Hum = Character:FindFirstChild("Humanoid")
		MainHandler.CreateTing("BoolValue",{Parent = Character, Name = "DoingCombat"},.6)
		PlayCombatSound("Combat.Punch", "Swing", Humrp)
		MainHandler.Animation(AnimationsModule.GetIndexedAnimation("Shared.DownSlam",DownSlamIndex),Hum,nil,Enum.AnimationPriority.Action4)

	end
end

return Main
