local Main = {}

local Tween = game:GetService("TweenService")

local AnimationsModule = require(game.ReplicatedStorage.Modules:WaitForChild("Animations"))

_G.Debris = function(Item,Time)
	if Item ~= nil and Time ~= nil then
		game.Debris:AddItem(Item,Time)
	end
end

_G.EffectEmitter = function(Attachment,Properties)
	if Attachment ~= nil and Properties ~= nil then
		local NewAttachment = Attachment:Clone()
		for i,v in pairs(Properties) do
			if v ~= Properties.Debris then
				NewAttachment[i] = v
			end
		end
		--// Emit
		for i,v in pairs(NewAttachment:GetChildren()) do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		if Properties.Debris ~= nil then
			game.Debris:AddItem(NewAttachment,Properties.Debris)
		end
	end
end

--// Being Called from where? //--
function get()
	local RunService = game:GetService("RunService")
	if RunService:IsServer() then
		return "Server"
	elseif RunService:IsClient() then
		return "Client"
	end
end

function Main.CreateTing(Type,Properties,DebrisTime)
	if Type ~= nil and Properties ~= nil then
		local Thing = Instance.new(Type)
		--// Properties //--
		for i,v in pairs(Properties) do
			Thing[i] = v
		end
		if DebrisTime then
			_G.Debris(Thing,DebrisTime)
		end

		return Thing
	end
end

function Main.Notification(plr,TextToNotif,Properties,Type)
	if plr ~= nil and TextToNotif ~= nil and plr:FindFirstChild("PlayerGui") then
		if Type == nil then
			local plrUI = plr:FindFirstChild("PlayerGui")
			local MainHUD = plrUI:WaitForChild("Main_HUD")
			local NotificationsFrame = MainHUD:WaitForChild("Notifications")
			--// Label //--
			
			local NotifText = game.ReplicatedStorage.Assets.Notifs:WaitForChild("Notif"):Clone()
			--// Properties 
			NotifText.Parent = NotificationsFrame
			NotifText.Text = TextToNotif
			if Properties ~= nil then
				for i,v in pairs(Properties) do
					NotifText[i] = v
				end
			end
			NotifText.TextTransparency = 1
			NotifText.TextStrokeTransparency = 1
			game.ReplicatedStorage.Sounds.Misc.Notification:Play()
		
			game.Debris:AddItem(NotifText,3.5)
			--// Effect
			coroutine.resume(coroutine.create(function()
				game.TweenService:Create(NotifText,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency = 0.14,TextStrokeTransparency = 0.89}):Play()
				wait(2.7)
				game.TweenService:Create(NotifText,TweenInfo.new(.45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency = 1,TextStrokeTransparency = 1}):Play()
			end))
		elseif Type == "TypeWriter" then
			-- Type Writer Effect --
		end
	end
end

function Main.Deletus(ThingName,Parent)
	if ThingName ~= nil and Parent ~= nil and Parent:FindFirstChild(ThingName) ~= nil then
		Parent:FindFirstChild(ThingName):Destroy()
	end
end

function Main.HitCounterUp(plr)
	if plr ~= nil and game.ReplicatedStorage.PlayersData:FindFirstChild(plr.Name.."Data") ~= nil then
		local plr_Data = game.ReplicatedStorage.PlayersData:FindFirstChild(plr.Name.."Data")
		plr_Data.Hit.Value +=1
	end
end

function Main.Alert(Char)
	if Char ~= nil and Char:FindFirstChild('Head') ~= nil then
		local Alert = game.ReplicatedStorage.Effects.Alerted:WaitForChild("Alert"):Clone()
		Alert.Parent = Char:FindFirstChild('Head') 
		for i,v in pairs(Alert:GetChildren()) do
			if v:IsA("ParticleEmitter") then
				v:Emit(1)
			end
		end
		game.Debris:AddItem(Alert,1.5)
		Main.Sound(game.ReplicatedStorage.Sounds.Misc:WaitForChild("Alert"),{Parent = Char.HumanoidRootPart},3)
	end
end

function Main.AfterImage(Char,Color)
	if Char ~= nil then
		for i,v in pairs(Char:GetDescendants()) do
			if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
				local Part = Instance.new("Part")
				Part.Name = "AI"
				Part.Parent = workspace.Effects
				Part.Size = v.Size
				Part.CFrame = v.CFrame
				Part.Anchored = true
				Part.CanCollide = false
				Part.Material = Enum.Material.Neon
				if Color == nil then
					Part.Color = Color3.fromRGB(255, 255, 255)
				else
					Part.Color = Color
				end
				Part.Transparency = 0.15
				if v.Name == "Head" then
					local Mesh = Instance.new("SpecialMesh")
					Mesh.Parent = Part
					Mesh.MeshType = Enum.MeshType.Head
				end
				Tween:Create(Part,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency = 1,Size = Part.Size / 2}):Play()
				game.Debris:AddItem(Part,.5)
			end
		end
	end
end

function Main.DoubleJump(Char)
	Main.Sound(game.ReplicatedStorage.Assets.Sounds.Movement.Jump2,{Parent = Char.HumanoidRootPart},1.5)
	Main.AfterImage(Char)
end

function Main.GroundRay(StartPos,Direction,Object)
	if StartPos ~= nil and Direction ~= nil and Object ~= nil then
		local rayOrigin = StartPos
		local rayDirection = Direction
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {Object,workspace.Effects,workspace.NPCS,workspace.P_Characters}
		params.FilterType = Enum.RaycastFilterType.Exclude
		local Hit = workspace:Raycast(rayOrigin,rayDirection,params)
		if Hit then
			local HitResult = Hit.Instance
			local Color = HitResult.Color
			local Material = HitResult.Material
			local HitPos = Hit.Position
			return {HitPos,Color,Material}
		else
			return false
		end 
	end
end

function Main.DashEffect(Char,Humrp)
	if Humrp ~= nil and Char ~= nil then
	end
end

function Main.Slide(Char)
	if Char ~= nil and Char:FindFirstChild("HumanoidRootPart") ~= nil and Char:FindFirstChild("Torso") ~= nil then
		Main.Sound(game.ReplicatedStorage.Assets.Sounds.Movement.Slide,{Parent = Char:WaitForChild("HumanoidRootPart")},1.2)
	end
end

local DamageIndMod = require(script:WaitForChild("DamageIndicator"))

function Main.DamageInd(Character,Damage)
	DamageIndMod(Character,Damage,Color3.fromRGB(255, 255, 255),UDim2.new(1.2, 0, 1.2, 0),Enum.Font.ArialBold)
end

function Main.StopAnimation(AnimationName,Hum)
	if AnimationName ~= nil and Hum ~= nil and Hum:IsA("Humanoid") then
		local AnimationTracks = Hum:GetPlayingAnimationTracks()
		for i, track in pairs(AnimationTracks) do
			if track.Name == AnimationName then
				track:Stop()
			end
		end
	end
end

function Main.Animation(Animation,Hum,PlaybackSpeed,AnimPriority)
	if Hum ~= nil and Animation ~= nil and Hum.Health ~= nil and Hum.Health > 0 then
		local Anim
		if Hum:FindFirstChild("Animator") ~= nil then
			Anim = Hum.Animator:LoadAnimation(Animation)
		else
			Anim = Hum:LoadAnimation(Animation)
		end
		if PlaybackSpeed ~= nil then
			Anim:AdjustSpeed(PlaybackSpeed)
		end
		if AnimPriority ~= nil then
			Anim.Priority = AnimPriority
		end
		Anim:Play()
	end
end

function Main.CombatAnimation(GroupName,AnimationName,Hum,PlaybackSpeed,AnimPriority)
	Main.Animation(AnimationsModule.GetAnimation("Shared." .. GroupName,AnimationName),Hum,PlaybackSpeed,AnimPriority)
end

function Main.Sound(SoundObject,Properties,DebrisTime)
	if SoundObject ~= nil and Properties ~= nil then
		local Sound = SoundObject:Clone()
		for i,v in pairs(Properties) do
			Sound[i] = v
		end
		Sound:Play()
		if DebrisTime then
			_G.Debris(Sound,DebrisTime)
		end
	end
end

function Main.PlaySound(Id, Volume, TimePosition, Parent, Duration)
	local s = Instance.new('Sound')
	s.SoundId = Id
	s.Volume = Volume
	s.TimePosition = TimePosition
	s.Parent = Parent
	s:Play()
	_G.Debris(s, Duration or 1)
end

--// Blocking Stuff //--
function Main.CanDo(Char)
	if Char ~= nil and Char:FindFirstChild("Blocking") == nil and Char:FindFirstChild("Stun") == nil and Char:FindFirstChild("DoingCombat") == nil and Char:FindFirstChild("DoingMove") == nil then
		return true
	else 
		return false
	end
end

function Main.DestroyBlock(Char)
	if Char ~= nil and Char:FindFirstChild("Blocking") ~= nil and Char:FindFirstChild("Humanoid") ~= nil then
		for i,v in pairs(Char:GetChildren()) do
			if v.Name == "Blocking" then
				v:Destroy()
			end
		end
		game.ReplicatedStorage.Events.HandlerFireClient:FireAllClients("MainHandler","StopAnimation","Block",Char.Humanoid)
	end
end

function Main.BlockBar(Char)
	if Char ~= nil and Char:FindFirstChild("HumanoidRootPart") ~= nil and Char:FindFirstChild("Humanoid") ~= nil and Char.Humanoid.Health > 0 then
		local Humrp = Char:FindFirstChild("HumanoidRootPart")
		local BlockD = game.ReplicatedStorage.Effects:WaitForChild("BlockingDisplay"):Clone()
		BlockD.Parent = Humrp
		local Connection 
		Connection = game:GetService("RunService").Heartbeat:Connect(function()
			if Char:FindFirstChild("HumanoidRootPart") ~= nil and Humrp:FindFirstChild("BlockingDisplay") ~= nil and Char.Humanoid.Health > 0 and Char:FindFirstChild("Blocking") ~= nil then
				local Blocking = Char:FindFirstChild("Blocking")
				Humrp.BlockingDisplay.MainFrame.BlockBar.Size = UDim2.new(0.23, 0,(Blocking.Value/5)*1, 0)
			else
				if Humrp:FindFirstChild("BlockingDisplay") ~= nil then
					for i,v in pairs(Humrp:GetChildren()) do
						if v.Name == "BlockingDisplay" then
							v:Destroy()
						end
					end
				end
				Connection:Disconnect()
			end
		end)
	end
end

function Main.Block(Char)
	if Char ~= nil then
		local Bloc = Instance.new("NumberValue")
		Bloc.Parent = Char
		Bloc.Name = "Blocking"
		Bloc.Value = 5 
		local PB = Instance.new('BoolValue')
		PB.Parent = Bloc
		PB.Name = "PB"
		game.Debris:AddItem(PB,.25)
		game.ReplicatedStorage.Events.HandlerFireClient:FireAllClients("MainHandler","BlockBar",Char)
	end
end

function Main.BlockClient(Char)
	if Char:FindFirstChild("Humanoid") ~= nil and Char.Humanoid.Health > 0 and Char:FindFirstChild("HumanoidRootPart") ~= nil and Char:FindFirstChild("Blocking") ~= nil and get() == "Client" then
		local Humrp = Char:FindFirstChild("HumanoidRootPart")
		local Hum = Char:FindFirstChild("Humanoid")
		if Char:FindFirstChild("Blocking") ~= nil then
			local Block = Char:FindFirstChild("Blocking")
			local change
			change = Block.Changed:Connect(function(Val)
				BlockDisplay.MainFrame.BlockBar.Size = UDim2.new(0.13, 0,(Val/5)*1, 0)
			end)
		end
	end
end

function Main.RemoveBlockClient(Char)
	if Char:FindFirstChild("Humanoid") ~= nil and Char.Humanoid.Health > 0 and Char:FindFirstChild("HumanoidRootPart") ~= nil and get() == "Client" then
		local Humrp = Char:FindFirstChild("HumanoidRootPart")
		local Hum = Char:FindFirstChild("Humanoid")
		if Humrp:FindFirstChild("BlockingDisplay") ~= nil then
			Humrp.BlockingDisplay:Destroy()
		end
	end
end

--// Death Effects //--
function Main.PlayerDeath(Char)
	if Char ~= nil then
		
	end
end

function Main.EnemyNPCDeath(Pos,Char)
	if Pos ~= nil and Char ~= nil then
		--// Particles
		local DeathEff = game.ReplicatedStorage.Effects:WaitForChild("EnemyDeath"):Clone()
		DeathEff.Parent = workspace.Effects
		DeathEff.Position = Pos
		--// Sound //--
		Main.Sound(game.ReplicatedStorage.Sounds.Misc:WaitForChild("Defeated"),{Parent = DeathEff},3)
		_G.Debris(DeathEff,4)
		for i,v in pairs(DeathEff:GetChildren()) do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		--// Character
		for i,v in pairs(Char:GetDescendants()) do
			if v:IsA("BasePart") then
				Tween:Create(v,TweenInfo.new(1.2,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),{Transparency = 1,Color = Color3.fromRGB(118, 76, 47)}):Play()
			elseif v:IsA("Decal") then
				Tween:Create(v,TweenInfo.new(1.2,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),{Transparency = 1}):Play()
			end
		end
	end
end

function Main.NormalNPCDeath(Pos,Char)
	if Pos ~= nil and Char ~= nil then
		local MaxPower = 50
		local MinPower = 25
		--// Effect
		coroutine.resume(coroutine.create(function()
			for i=1,12 do
				local Exp = game.ReplicatedStorage.Effects:WaitForChild("Residue_Exp"):Clone()
				Exp.Parent = workspace.Effects
				Exp.Position = Pos
				Exp.Velocity = Vector3.new(math.random(-MaxPower,MaxPower),math.random(MinPower,MaxPower),math.random(-MaxPower,MaxPower))
				Exp.Color = Color3.fromRGB(math.random(100,255),math.random(100,255),math.random(100,255))
				Exp.Trail.Color = ColorSequence.new(Exp.Color)
				coroutine.resume(coroutine.create(function()
					task.wait(4)
					Exp.Trail.Enabled = false
					Tween:Create(Exp,TweenInfo.new(0.8,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Transparency = 1}):Play()
				end))
				game.Debris:AddItem(Exp,5)
				task.wait(.03)
			end
		end))
		--// Character
		for i,v in pairs(Char:GetDescendants()) do
			if v:IsA("BasePart") then
				v.Anchored = true
				Tween:Create(v,TweenInfo.new(1.2,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),{Transparency = 1,Color = Color3.fromRGB(118, 118, 118)}):Play()
			elseif v:IsA("Decal") then
				Tween:Create(v,TweenInfo.new(1.2,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),{Transparency = 1}):Play()
			end
		end
	end
end

function Main.Dash(Char,Direction)
	--// Directions table //--
	local Directions = {
		["Front"] = Vector3.new(0,0,-1),
		["Left"] = Vector3.new(-1,0,0),
		["Back"] = Vector3.new(0,0,1),
		["Right"] = Vector3.new(1,0,0)
	}
	local Anims = {
		["Front"] = "W",
		["Left"] = "A",
		["Back"] = "S",
		["Right"] = "D"
	}
	if  Char ~= nil and Direction ~= nil and Char:FindFirstChild("Humanoid") ~= nil and Char.Humanoid.Health > 0  and Char:FindFirstChild("HumanoidRootPart") ~= nil and Char:FindFirstChild("Stun") == nil and Char:FindFirstChild("DoingCombat") == nil and Directions[Direction] ~= nil then
		--// Body Velocity //--
		Main.CreateTing("BodyVelocity",{Parent = Char.HumanoidRootPart,Name = "DodgeVoelocity",MaxForce = Vector3.new(4e4,0,4e4),Velocity = Char.HumanoidRootPart.CFrame:VectorToWorldSpace(Directions[Direction])*60},.4)
		--// Dash Effect //--
		Main.DashEffect(Char,Char.HumanoidRootPart)
		--// Animation //--
		Main.Animation(game.ReplicatedStorage.Animations.Dash:WaitForChild(Anims[Direction]),Char.Humanoid)
		--// Sound //--
		Main.Sound(game.ReplicatedStorage.Sounds.Movement:WaitForChild("Dash"),{Parent = Char.HumanoidRootPart},2.5)
	end
end

function Main.SetKey(plr,Key_ToChange,NewKey)
	if plr ~= nil and Key_ToChange ~= nil and NewKey ~= nil then
		local plr_Data = game.ReplicatedStorage.PlayersData:FindFirstChild(plr.Name.."Data")
		local KeysFold = plr_Data:WaitForChild("Keys")
		if KeysFold:FindFirstChild(Key_ToChange) ~= nil then
			KeysFold[Key_ToChange].Value = NewKey
		end
	end
end

function lerp(a, b, c)
	return a + (b - a) * c
end

function quadBezier(t, p0, p1, p2)
	local l1 = lerp(p0, p1, t)
	local l2 = lerp(p1, p2, t)
	local quad = lerp(l1, l2, t)
	return quad
end

function Main.ChargeBezier(Humrp,Amount,Color)
	if Humrp ~= nil and Amount ~= nil and Color ~= nil then
		--// BEZIERS //--
		coroutine.resume(coroutine.create(function()
			for i=1,Amount do
				local p1 = Humrp.Position + Vector3.new(math.random(-12,12),math.random(-5,14),math.random(-12,12))
				local First = CFrame.new(p1)
				local p2 = (First:Lerp(Humrp.CFrame, 0.45) * CFrame.new(math.random(-4, 4), math.random(-4, 4), math.random(-4, 4))).Position
				local p3 = Humrp.Position

				local Bit = game.ReplicatedStorage.Effects:WaitForChild("Bits"):Clone()
				Bit.Trail.Color = ColorSequence.new(Color)
				Bit.Position = p1
				Bit.Parent = workspace.Effects

				local Elapsed = 0
				local connection
				connection = game:GetService('RunService').Heartbeat:Connect(function(Delta)
					Elapsed += Delta
					Elapsed = Elapsed + .04
					local step = quadBezier(Elapsed, p1, p2, Humrp.Position)
					Bit.Position = step
					if Bit.Position == p3 then
						Bit.Trail.Enabled = false
						coroutine.wrap(function()
							wait(2)
							Bit:Destroy()
						end)()
						connection:Disconnect()
					end
					if Elapsed >= 1 then
						Bit.Trail.Enabled = false
						coroutine.wrap(function()
							wait(2)
							Bit:Destroy()
						end)()
						connection:Disconnect()
					end
				end)
			end
			task.wait()
		end))
	end
end

function _G.CopyTable(Table)
	if Table ~= nil then
		local NewTable = {}
		for i,v in pairs(Table) do
			NewTable[i] = v
		end
		return NewTable
	end
end

return Main
