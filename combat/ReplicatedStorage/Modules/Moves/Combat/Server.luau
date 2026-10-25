local Combat = {}

local AirTargets = setmetatable({}, {__mode = "k"})

local CombatInfo = require(game.ReplicatedStorage.Modules:WaitForChild("Moves")).Combat

local MainHandler = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("MainHandler"))
local AnimationsModule = require(game.ReplicatedStorage.Modules:WaitForChild("Animations"))
local Weapons = require(game.ReplicatedStorage.Modules:WaitForChild("Weapons"))
local HitDetection = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("HitDetection"))


--// Remotes //--
local ClientRemote = game.ReplicatedStorage.Events:FindFirstChild("HandlerFireClient")


--// DESTROY BLOCK FUNCTION //--
function Combat.DestroyBlock(Char)
	if Char ~= nil and Char:FindFirstChild("Blocking") ~= nil then
		for i,v in pairs(Char:GetChildren()) do
			if v.Name == "Blocking" then
				v:Destroy()
			end
		end
		ClientRemote:FireAllClients(Char,"MainHandler","RemoveBlockClient",Char)
		if Char:FindFirstChild("Humanoid") ~= nil then
			ClientRemote:FireAllClients(Char,"MainHandler","StopAnimation","Blocking",Char.Humanoid)
		end
	end
end

--// BLOCK FUNCTION //--
function Combat.Block(Char)
	if Char ~= nil and Char:FindFirstChild("Humanoid") ~= nil and Char.Humanoid.Health > 0 and Char:FindFirstChild("HumanoidRootPart") ~= nil then
		--// Variables
		local Hum = Char:FindFirstChild("Humanoid")
		local Block = MainHandler.CreateTing("NumberValue",{Parent = Char, Name = "Blocking",Value = CombatInfo.Block.Health})
		MainHandler.CreateTing("BoolValue",{Parent = Block, Name = "PB"},CombatInfo.Block.ParryWindow)
		ClientRemote:FireAllClients(Char,"MainHandler","BlockClient",Char)
		ClientRemote:FireAllClients(Char,"Client_Framework","BlockAnimation",Char)
	end
end


--// Parry \--

local function parryAttacker(Attacker, Defender, Count, MaxCount)
	MainHandler.CreateTing("BoolValue", {Parent = Attacker, Name = "Stun"}, CombatInfo.Block.ParryStun)

	Defender:SetAttribute("LastParry", os.clock())

	ClientRemote:FireAllClients(Attacker, "Client_Framework", "Effect", Attacker, Count, "Parry", MaxCount, Defender)
end


--// In Combat \--

local COMBAT_TIMEOUT = 8

local function markInCombat(Character)
	local combatToken = (Character:GetAttribute("CombatToken") or 0) + 1

	Character:SetAttribute("CombatToken", combatToken)
	Character:SetAttribute("InCombat", true)

	task.delay(COMBAT_TIMEOUT, function()
		if Character.Parent ~= nil and Character:GetAttribute("CombatToken") == combatToken then
			Character:SetAttribute("InCombat", nil)
		end
	end)
end


--// MAIN COMBAT FUNCTION //--
local function buildHitIgnoreList(Character)
	return {workspace.Effects, workspace.Debris, Character, workspace.Baseplate}
end

local function applyHitKnockback(Humrp, EnemyHumrp, knockback)
	local hasLift = knockback.Lift > 0
	local direction = CFrame.new(Humrp.Position, Humrp.Position + (Humrp.CFrame.lookVector * 10) + (Humrp.CFrame.upVector * -10)).LookVector * knockback.Force

	local BodyVelocity = Instance.new("BodyVelocity")
	BodyVelocity.MaxForce = Vector3.new(4e4, if hasLift then 4e4 else 0, 4e4)
	BodyVelocity.Velocity = Vector3.new(direction.X, if hasLift then knockback.Lift else direction.Y, direction.Z)
	BodyVelocity.Parent = EnemyHumrp
	game.Debris:AddItem(BodyVelocity, knockback.Duration)
end

function Combat.Punch(Character,Count,Type,MaxCount)
	if Character ~= nil and typeof(Count) == "number" and Character:FindFirstChild("Humanoid") ~= nil and Character.Humanoid.Health > 0 and Character:FindFirstChild("HumanoidRootPart") ~= nil and Type ~= nil then
		local Humrp = Character:FindFirstChild("HumanoidRootPart")
		local weapon = Weapons.GetForCharacter(Character)

		MaxCount = weapon.MaxCombo
		Count = math.clamp(math.floor(Count), 1, MaxCount)

		local hit = Weapons.GetHit(weapon, Count, Character)

		ClientRemote:FireAllClients(Character,"Client_Framework","Swing",Character,Count,Type)

		task.wait(hit.HitboxDelay)

		if Humrp.Parent == nil or Character.Humanoid.Health <= 0 then
			return
		end

		if weapon.Interruptible and Character:FindFirstChild("Stun") ~= nil then
			return
		end

		if Type == "Punch" then
			local Targets = HitDetection.GetCharactersInBox(HitDetection.GetAttackCFrame(Character, weapon.Hitbox.Offset), weapon.Hitbox.Size, buildHitIgnoreList(Character), "Punch")
			for _, Enemy in ipairs(Targets) do
				if Enemy:FindFirstChild("Humanoid") ~= nil and Enemy:FindFirstChild("HumanoidRootPart") ~= nil and Enemy.Humanoid.Health > 0 then
					local EnemyHum = Enemy:FindFirstChild("Humanoid")
					local EnemyHumrp = Enemy:FindFirstChild("HumanoidRootPart")
					markInCombat(Character)
					markInCombat(Enemy)
					local cos = Enemy.HumanoidRootPart.CFrame.lookVector:Dot(CFrame.new(Humrp.Position,Enemy.HumanoidRootPart.Position).lookVector)

					if cos > 0.7 or
						(cos <= 0.7 and Enemy:FindFirstChild("Blocking") == nil) then

						MainHandler.CreateTing("BoolValue", {Parent = Enemy, Name = "Stun"}, hit.Stun)

						EnemyHum:TakeDamage(hit.Damage)
						ClientRemote:FireAllClients(Character,"MainHandler","DamageInd",Enemy,hit.Damage)

						ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Enemy, Count, Type, MaxCount, Character)

						if hit.Knockback then
							applyHitKnockback(Humrp, EnemyHumrp, hit.Knockback)
						end

					elseif Enemy:FindFirstChild("Blocking") ~= nil and Enemy.Blocking:FindFirstChild("PB") ~= nil then

						parryAttacker(Character, Enemy, Count, MaxCount)

					elseif Enemy:FindFirstChild("Blocking") ~= nil and Enemy.Blocking:FindFirstChild("PB") == nil then

						local Blocking = Enemy:FindFirstChild("Blocking")

						if Blocking:IsA("NumberValue") and Blocking.Value <= CombatInfo.Block.Health and Blocking.Value ~= 1 then
							Blocking.Value = Blocking.Value - 1
							ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Enemy, Count, "BlockHit", MaxCount)
						elseif Blocking:IsA("NumberValue") and Blocking.Value == 1 then
							ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Enemy, Count, "Block Break", MaxCount)
							MainHandler.CreateTing("BoolValue", {Parent = Enemy, Name = "Stun"}, CombatInfo.Block.BreakStun)
							Combat.DestroyBlock(Enemy)
						end
					end

				end
			end
		end
	end
end

local HeavyCooldowns = setmetatable({}, {__mode = "k"})

function Combat.Heavy(Character)
	if Character == nil
		or Character:FindFirstChildOfClass("Humanoid") == nil
		or Character:FindFirstChild("HumanoidRootPart") == nil
		or Character.Humanoid.Health <= 0
		or Character:FindFirstChild("Stun") ~= nil
		or Character:FindFirstChild("Blocking") ~= nil
		or Character:FindFirstChild("DoingMove") ~= nil
		or Weapons.GetEquippedTool(Character) == nil then
		return
	end

	local equippedTool = Weapons.GetEquippedTool(Character)
	local now = os.clock()
	if HeavyCooldowns[Character] ~= nil and HeavyCooldowns[Character] > now then
		return
	end

	local Humrp = Character.HumanoidRootPart
	local weapon = Weapons.GetForCharacter(Character)
	local Count = weapon.MaxCombo
	local hit = Weapons.GetHit(weapon, Count, Character)
	local cooldown = math.max(hit.Cooldown, CombatInfo.CriticalCooldown)
	HeavyCooldowns[Character] = now + cooldown

	ClientRemote:FireAllClients(Character, "Client_Framework", "HeavySwing", Character)
	task.wait(CombatInfo.CriticalWindup + hit.HitboxDelay)

	if Character.Parent == nil
		or Humrp.Parent ~= Character
		or Character.Humanoid.Health <= 0
		or equippedTool.Parent ~= Character
		or Weapons.GetEquippedTool(Character) ~= equippedTool then
		return
	end

	if weapon.Interruptible and Character:FindFirstChild("Stun") ~= nil then
		return
	end

	local Targets = HitDetection.GetCharactersInBox(HitDetection.GetAttackCFrame(Character, weapon.Hitbox.Offset), weapon.Hitbox.Size, buildHitIgnoreList(Character), "Punch")
	for _, Enemy in ipairs(Targets) do
		local EnemyHum = Enemy:FindFirstChildOfClass("Humanoid")
		local EnemyHumrp = Enemy:FindFirstChild("HumanoidRootPart")

		if EnemyHum ~= nil and EnemyHumrp ~= nil and EnemyHum.Health > 0 then
			markInCombat(Character)
			markInCombat(Enemy)

			local cos = EnemyHumrp.CFrame.LookVector:Dot(CFrame.new(Humrp.Position, EnemyHumrp.Position).LookVector)
			local Blocking = Enemy:FindFirstChild("Blocking")

			if cos > 0.7 or Blocking == nil then
				MainHandler.CreateTing("BoolValue", {Parent = Enemy, Name = "Stun"}, hit.Stun)
				EnemyHum:TakeDamage(hit.Damage)
				ClientRemote:FireAllClients(Character, "MainHandler", "DamageInd", Enemy, hit.Damage)
				ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Enemy, Count, "Punch", weapon.MaxCombo, Character)

				if hit.Knockback then
					applyHitKnockback(Humrp, EnemyHumrp, hit.Knockback)
				end
			elseif Blocking:FindFirstChild("PB") ~= nil then
				parryAttacker(Character, Enemy, Count, weapon.MaxCombo)
			else
				ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Enemy, Count, "Block Break", weapon.MaxCombo)
				MainHandler.CreateTing("BoolValue", {Parent = Enemy, Name = "Stun"}, CombatInfo.Block.BreakStun)
				Combat.DestroyBlock(Enemy)
			end
		end
	end
end

function Combat.Up(Character,Count,MaxCount)
	if Character == nil or not Weapons.GetForCharacter(Character).AllowUpperCut then
		return
	end

	if Character and Count and MaxCount and Character:FindFirstChild("Humanoid") ~= nil and Character.Humanoid.Health > 0 and Character:FindFirstChild("HumanoidRootPart") ~= nil and Count == MaxCount then
		
		--// Variables
		local Humrp = Character:FindFirstChild("HumanoidRootPart")
		local Hum = Character:FindFirstChild("Humanoid")
		ClientRemote:FireAllClients(Character,"Client_Framework","UpSwing",Character)
		AirTargets[Character] = {}
		
		local hitDelay = CombatInfo.HitboxDelay
		local liftDelay = CombatInfo.UpperCut.LiftDelay
		local usesFists = Weapons.IsFists(Character)

		if not usesFists then
			hitDelay = CombatInfo.UpperCut.WeaponHitDelay
			liftDelay = CombatInfo.UpperCut.WeaponLiftDelay
		end

		wait(hitDelay)
		
		--// HITBOX //--
		
		local Targets = HitDetection.GetCharactersInBox(HitDetection.GetAttackCFrame(Character, CombatInfo.HitboxOffset), Vector3.new(CombatInfo.HitboxSize,CombatInfo.HitboxSize,CombatInfo.HitboxSize), {workspace.Effects, Character, workspace.Baseplate}, "UpperCut")
		for _, Enemy in ipairs(Targets) do
			if Enemy:FindFirstChild("Humanoid") ~= nil and Enemy:FindFirstChild("HumanoidRootPart") ~= nil and Enemy.Humanoid.Health > 0 then
				local EnemyHum = Enemy:FindFirstChild("Humanoid")
				local EnemyHumrp = Enemy:FindFirstChild("HumanoidRootPart")
				markInCombat(Character)
				markInCombat(Enemy)
				local cos = Enemy.HumanoidRootPart.CFrame.lookVector:Dot(CFrame.new(Humrp.Position,Enemy.HumanoidRootPart.Position).lookVector)
				--// Hit Type Distinction

				--// BEHIND OR NORMAL HIT //--
				if cos > 0.7 or 
					(cos <= 0.7 and Enemy:FindFirstChild("Blocking") == nil) then 
					
					local Length = CombatInfo.UpperCut.AirTime
					
					MainHandler.CreateTing("BoolValue", {Parent = Enemy, Name = "Stun"}, Length)
					
					MainHandler.CreateTing("BoolValue", {Parent = Character, Name = "Stun"}, CombatInfo.UpperCut.AttackerStun)
					
					MainHandler.CreateTing("BoolValue", {Parent = Character, Name = "AirCombat", Value = false}, Length)

					EnemyHum:TakeDamage(CombatInfo.UpperCut.Damage)
					ClientRemote:FireAllClients(Character,"MainHandler","DamageInd",Enemy,CombatInfo.UpperCut.Damage)
					
					ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Enemy, Count, "Up", MaxCount, Character)
					
					
					
					--// Enemy //--
					if EnemyHumrp and EnemyHum.Health > 0 then
						local alignPosition = Instance.new("AlignPosition")
						alignPosition.Name = "AirPos"
						alignPosition.MaxForce = 4e4
						alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
						alignPosition.Responsiveness = 70 
						alignPosition.Attachment0 = Instance.new("Attachment", EnemyHumrp)

						alignPosition.Position = EnemyHumrp.Position + Vector3.new(0, CombatInfo.UpperCut.LiftHeight, 0)
						alignPosition.Parent = EnemyHumrp

						if AirTargets[Character] ~= nil then
							table.insert(AirTargets[Character], Enemy)
						end

						game:GetService("Debris"):AddItem(alignPosition, Length)
					end
					
					if usesFists then
						ClientRemote:FireAllClients(Character,"MainHandler","CombatAnimation","Punch","JumpUp",Hum)
					end
					
					task.wait(liftDelay)
					
					--// Player //--
					if Humrp and Hum.Health > 0 and Character:FindFirstChild("AirCombat") ~= nil then
						local alignPosition = Instance.new("AlignPosition")
						alignPosition.Name = "AirPosAttacker"
						alignPosition.MaxForce = 4e4
						alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
						alignPosition.Responsiveness = 70 
						alignPosition.Attachment0 = Instance.new("Attachment", Humrp)

						alignPosition.Position = Humrp.Position + Vector3.new(0, CombatInfo.UpperCut.LiftHeight, 0)
						alignPosition.Parent = Humrp

						game:GetService("Debris"):AddItem(alignPosition, Length)
						
						ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Character, Count, "UpFX", MaxCount, Character)
						
					end
					
					game.ReplicatedStorage.Events.AC:FireClient(game.Players:GetPlayerFromCharacter(Character),Character)

					--// Parry \--
				elseif Enemy:FindFirstChild("Blocking") ~= nil and Enemy.Blocking:FindFirstChild("PB") ~= nil then

					parryAttacker(Character, Enemy, Count, MaxCount)

					--// BLOCKING //--	
				elseif Enemy:FindFirstChild("Blocking") ~= nil and Enemy.Blocking:FindFirstChild("PB") == nil then 

					local Blocking = Enemy:FindFirstChild("Blocking")

					if Blocking:IsA("NumberValue") and Blocking.Value <= CombatInfo.Block.Health and Blocking.Value ~= 1 then
						Blocking.Value = Blocking.Value - 1
						ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Enemy, Count, "BlockHit", MaxCount)
					elseif Blocking:IsA("NumberValue") and Blocking.Value == 1 then
						ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Enemy, Count, "Block Break", MaxCount)
						MainHandler.CreateTing("BoolValue", {Parent = Enemy, Name = "Stun"}, CombatInfo.Block.BreakStun)
						Combat.DestroyBlock(Enemy)
					end
				end
				
			end
		end
		
	end
end

function Combat.EndAirCombat(Character)
	if Character == nil then
		return
	end

	local Humrp = Character:FindFirstChild("HumanoidRootPart")
	if Humrp ~= nil then
		local airHold = Humrp:FindFirstChild("AirPosAttacker")
		if airHold ~= nil then
			airHold:Destroy()
		end
	end

	local launchedEnemies = AirTargets[Character]
	if launchedEnemies ~= nil then
		for _, Enemy in ipairs(launchedEnemies) do
			local enemyRoot = Enemy:FindFirstChild("HumanoidRootPart")
			local enemyHold = enemyRoot and enemyRoot:FindFirstChild("AirPos")
			if enemyHold ~= nil then
				enemyHold:Destroy()
			end
		end

		AirTargets[Character] = nil
	end

	for _, child in ipairs(Character:GetChildren()) do
		if child.Name == "AirCombat" then
			child:Destroy()
		end
	end
end

function Combat.UpDown(Character,Count,MaxCount,SkipSwing)
	if Character == nil or not Weapons.GetForCharacter(Character).AllowUpperCut then
		return
	end

	if Character and Count and MaxCount and Character:FindFirstChild("Humanoid") ~= nil and Character.Humanoid.Health > 0 and Character:FindFirstChild("HumanoidRootPart") ~= nil and Count == MaxCount then

		--// Variables
		local Humrp = Character:FindFirstChild("HumanoidRootPart")
		local Hum = Character:FindFirstChild("Humanoid")
		local DownSlamIndex = AnimationsModule.PickRandomIndex("Shared.DownSlam")
		if SkipSwing ~= true then
			ClientRemote:FireAllClients(Character,"Client_Framework","DownSwing",Character,DownSlamIndex)
		end

		local hitCFrame = Humrp.CFrame

		wait(CombatInfo.DownSlam.WindUp)

		--// HITBOX //--

		local Targets = HitDetection.GetCharactersInBox(hitCFrame * CFrame.new(0,0,-CombatInfo.HitboxOffset), Vector3.new(CombatInfo.HitboxSize,CombatInfo.HitboxSize,CombatInfo.HitboxSize), {workspace.Effects, Character, workspace.Baseplate}, "DownSlam")
		for _, Enemy in ipairs(Targets) do
			if Enemy:FindFirstChild("Humanoid") ~= nil and Enemy:FindFirstChild("HumanoidRootPart") ~= nil and Enemy.Humanoid.Health > 0 then
				local EnemyHum = Enemy:FindFirstChild("Humanoid")
				local EnemyHumrp = Enemy:FindFirstChild("HumanoidRootPart")
				markInCombat(Character)
				markInCombat(Enemy)
				local cos = Enemy.HumanoidRootPart.CFrame.lookVector:Dot(CFrame.new(hitCFrame.Position,Enemy.HumanoidRootPart.Position).lookVector)
				--// Hit Type Distinction

				--// BEHIND OR NORMAL HIT //--
				if cos > 0.7 or 
					(cos <= 0.7 and Enemy:FindFirstChild("Blocking") == nil) then 
					
					local airHold = EnemyHumrp:FindFirstChild("AirPos")

					if airHold then
						airHold:Destroy()
					end

					MainHandler.CreateTing("BoolValue", {Parent = Enemy, Name = "Stun"}, CombatInfo.DownSlam.Stun)
					
					ClientRemote:FireAllClients(Character,"MainHandler","DamageInd",Enemy,CombatInfo.DownSlam.Damage)
					EnemyHum:TakeDamage(CombatInfo.DownSlam.Damage)
					
					--// Direction Calculations //--
					local raycastparams = RaycastParams.new()
					local tableyes = {workspace.NPCS,workspace.Effects,Character,Enemy}
					raycastparams.FilterDescendantsInstances = tableyes
					raycastparams.FilterType = Enum.RaycastFilterType.Exclude
					
					local direction = CFrame.new(hitCFrame.Position,hitCFrame.Position+(hitCFrame.lookVector*12)+(hitCFrame.upVector*-10) ).lookVector*300
					local start= hitCFrame.Position
					local results = workspace:Raycast(start,direction,raycastparams)
					if results ~= nil and results.Instance ~= nil and (results.Position-start).Magnitude <= 300 then
						--// CFrames //--
						local cf = CFrame.new(results.Position,results.Position+results.Normal)
						local targetcf = cf*CFrame.new(0,0,-.5)
						local x,y,z = targetcf:ToOrientation()
						local rot = EnemyHumrp.CFrame -EnemyHumrp.Position
						local cframe = CFrame.new(targetcf.p)*rot
						local point = CFrame.new(results.Position)*CFrame.new(0,6,0)
						
						--// Move Enemy //--
						cf = cframe*CFrame.Angles(x,0,z)*CFrame.Angles(-math.pi/2,0,0)+Vector3.new(0,2.85,0) 
						if EnemyHumrp ~= nil and cf ~= nil then
							local rootv = Instance.new("Part")
							rootv.Anchored = true
							rootv.CanCollide = false
							rootv.Transparency = 1
							rootv.Massless = true
							rootv.Parent = workspace.Effects
							local w = Instance.new("Weld")
							w.Part0 = EnemyHumrp
							w.Part1 = rootv
							w.Parent = EnemyHumrp
							game.Debris:AddItem(rootv,1.5)
							rootv.CFrame = cf
							coroutine.resume(coroutine.create(function()
								wait(1.2)
								if rootv ~= nil and EnemyHumrp ~= nil then
									local victim = EnemyHumrp.Parent
									if victim:FindFirstChild("Humanoid") ~= nil and game.Players:GetPlayerFromCharacter(victim) == nil then
										victim.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
									end
								end
							end))
						end
						
						ClientRemote:FireAllClients(Character, "Client_Framework", "Effect", Enemy, Count, "Down", MaxCount, Character,{point,results.Position,results.Instance,results.Normal})
						
					else
						
						local BodyVelocity = Instance.new("BodyVelocity")
						BodyVelocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
						BodyVelocity.Velocity = direction
						BodyVelocity.Parent = EnemyHumrp
						game.Debris:AddItem(BodyVelocity, .25)
						
					end
					
				end
			end
		end
	end
end

return Combat
