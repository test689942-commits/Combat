local plr = game.Players.LocalPlayer

local CombatInfo = require(game.ReplicatedStorage.Modules:WaitForChild("Moves")).Combat

local Handler = {}

Handler.Variables = {
	debounce = false;
	BlockDebounce = false;
	currTime = 0;
	prevTime = 0;
	count = 0;
	comboToken = 0;
}
--// Modules \--

local AnimationsModule = require(game.ReplicatedStorage.Modules:WaitForChild("Animations"))
local Weapons = require(game.ReplicatedStorage.Modules:WaitForChild("Weapons"))
local WeaponFX = require(script.Parent:WaitForChild("WeaponFX"))

--// Idle Variables \\--

local RunService = game:GetService("RunService")

local IdleFadeTime = 0.2
local MoveFadeTime = 0.15
local MoveSpeedThreshold = 0.5

local GroundedStates = {
	[Enum.HumanoidStateType.Running] = true;
	[Enum.HumanoidStateType.RunningNoPhysics] = true;
	[Enum.HumanoidStateType.Landed] = true;
}

local IdleTrack = nil
local IdleConnection = nil
local IdleHumanoid = nil
local IdleRoot = nil
local IdlePlaying = false
local EquipTrack = nil
local RageConnection = nil

--// Remotes //--
local ServerRemote = game.ReplicatedStorage.Events:FindFirstChild("HandlerFireServer")

local UI = plr:WaitForChild("PlayerGui")
local Tween = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")


--// Can Punch?
function Handler.CanDoCombat(Character)
	if Character:FindFirstChild("Stun") ~= nil or Character:FindFirstChild("Blocking") ~= nil or Character:FindFirstChild("DoingMove") ~= nil then
		return false
	else
		return true
	end
end

--// Can Block?
function Handler.Can_Do_Block(Character)
	if Character:FindFirstChild("Stun") or Character:FindFirstChild("DoingCombat") and Character:FindFirstChild("DoingMove") ~= nil then
		return false
	else
		return true
	end
end

--// Control UI \--

local ControlTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PressedColor = Color3.fromRGB(150, 150, 150)
local ReleasedColor = Color3.fromRGB(255, 255, 255)

local function setControlPressed(ControlName, Pressed)
	local ControlsGui = UI:WaitForChild("Controls")
	local Control = ControlsGui.ControlFrame:FindFirstChild(ControlName)
	if Control == nil then
		return
	end

	local KeyCap = Control.ImageLabel
	local ControlColor = Pressed and PressedColor or ReleasedColor

	Tween:Create(KeyCap, ControlTweenInfo, {ImageColor3 = ControlColor}):Play()
	Tween:Create(KeyCap.Key, ControlTweenInfo, {TextColor3 = ControlColor}):Play()
end

local function UIFX(ControlName)
	task.spawn(function()
		setControlPressed(ControlName, true)
		task.wait(0.16)
		setControlPressed(ControlName, false)
	end)
end

--// Jump Lock \--

local JumpLockTime = CombatInfo.JumpLockTime
local JumpLockToken = 0
local JumpLockHumanoid = nil
local JumpReleaseConnection = nil

local function enableJump()
	if JumpReleaseConnection ~= nil then
		JumpReleaseConnection:Disconnect()
		JumpReleaseConnection = nil
	end

	if JumpLockHumanoid ~= nil and JumpLockHumanoid.Parent ~= nil then
		JumpLockHumanoid.Jump = false
		JumpLockHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end

	JumpLockHumanoid = nil
end

local function releaseJumpLock()
	if UIS:IsKeyDown(Enum.KeyCode.Space) == false then
		enableJump()
		return
	end

	if JumpReleaseConnection ~= nil then
		JumpReleaseConnection:Disconnect()
	end

	JumpReleaseConnection = UIS.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then
			enableJump()
		end
	end)
end

local function lockJump(Character)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid == nil then
		return
	end

	if JumpReleaseConnection ~= nil then
		JumpReleaseConnection:Disconnect()
		JumpReleaseConnection = nil
	end

	JumpLockToken += 1
	local lockToken = JumpLockToken

	JumpLockHumanoid = Humanoid
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	task.delay(JumpLockTime, function()
		if lockToken == JumpLockToken then
			releaseJumpLock()
		end
	end)
end

function Handler.UnlockJump()
	JumpLockToken += 1
	enableJump()
end

function Handler.Punch(Character)
	if Character ~= nil then
		local weapon = Weapons.GetForCharacter(Character)
		local MaxCount = weapon.MaxCombo
		local hit = Weapons.GetHit(weapon, Handler.Variables.count, Character)

		lockJump(Character)
		UIFX("Punch")
		WeaponFX.ClientSwing(Character, hit)

		if weapon.AllowUpperCut and Handler.Variables.count == MaxCount and UIS:IsKeyDown(CombatInfo.UpperCut.Key) == true and Character:FindFirstChild("AirCombat") == nil then
			ServerRemote:FireServer("Combat_Server","Up",Character,Handler.Variables.count,MaxCount,"Punch")

			UIFX("UpperCut")

		elseif weapon.AllowUpperCut and Handler.Variables.count == MaxCount and Character:FindFirstChild("AirCombat") ~= nil then
			ServerRemote:FireServer("Combat_Server","UpDown",Character,Handler.Variables.count,MaxCount,"Punch")
		else
			ServerRemote:FireServer("Combat_Server","Punch",Character,Handler.Variables.count,"Punch",MaxCount)
		end
	end
end

--// Run Checks For Comnbat //--
function Handler.TryCombat(Char)
	if Char ~= nil and Handler.Variables.debounce == false and Char:FindFirstChild("Stun") == nil then
		local weapon = Weapons.GetForCharacter(Char)
		local MaxCount = weapon.MaxCombo

		Handler.Variables.debounce = true
		Handler.Variables.comboToken += 1
		Handler.Variables.currTime = os.clock()

		local cooldownToken = Handler.Variables.comboToken

		local passedTime = Handler.Variables.currTime - Handler.Variables.prevTime

		if passedTime < weapon.ComboWindow then
			Handler.Variables.count += 1

			if Handler.Variables.count > MaxCount then
				Handler.Variables.count = 1
			end
		else
			Handler.Variables.count = 1
		end

		if Handler.CanDoCombat(Char) == true then
			Handler.Punch(Char)
		end

		local hit = Weapons.GetHit(weapon, Handler.Variables.count, Char)

		task.wait(hit.Cooldown)

		if cooldownToken ~= Handler.Variables.comboToken then
			return
		end

		Handler.Variables.debounce = false
		Handler.Variables.prevTime = Handler.Variables.currTime
	end
end

--// Try To Do Block //--
function Handler.TryBlock(Char,Type)
	if Char ~= nil and Handler.Variables.BlockDebounce == false and Handler.Can_Do_Block(Char) == true and Char:FindFirstChild("Humanoid") ~= nil and Char.Humanoid.Health > 0 and Char:FindFirstChild("HumanoidRootPart") ~= nil then
		if Type ~= nil then
			ServerRemote:FireServer("Combat_Server","Block",Char,Type)
		else
			ServerRemote:FireServer("Combat_Server","Block",Char,"Fists")
			
			setControlPressed("Block", true)
			
		end
	end
end

--// Remove Block //--
function Handler.RemoveBlock(Char)
	if Char ~= nil and Handler.Variables.BlockDebounce == false and Char:FindFirstChild("Blocking") ~= nil then
		Handler.Variables.BlockDebounce = true
		ServerRemote:FireServer("Combat_Server","DestroyBlock",Char)
		wait(Handler.Variables.BlockCooldown)
		Handler.Variables.BlockDebounce = false
		
		setControlPressed("Block", false)
		
	end
end

--// Idle \\--

local function isStandingStill(Humanoid, Root)
	if Humanoid.Health <= 0 then
		return false
	end

	if GroundedStates[Humanoid:GetState()] ~= true then
		return false
	end

	local Velocity = Root.AssemblyLinearVelocity
	local HorizontalSpeed = Vector3.new(Velocity.X, 0, Velocity.Z).Magnitude

	return HorizontalSpeed <= MoveSpeedThreshold
end

local function stopEquipTrack()
	if EquipTrack ~= nil and EquipTrack.IsPlaying == true then
		EquipTrack:Stop(MoveFadeTime)
	end

	EquipTrack = nil
end

local function setIdlePlaying(Playing)
	if IdleTrack == nil or IdlePlaying == Playing then
		return
	end

	IdlePlaying = Playing

	if Playing == true then
		IdleTrack:Play(IdleFadeTime)
	else
		IdleTrack:Stop(MoveFadeTime)
	end
end

local function updateIdle()
	if IdleHumanoid == nil or IdleRoot == nil then
		return
	end

	local StandingStill = isStandingStill(IdleHumanoid, IdleRoot)

	setIdlePlaying(StandingStill)

	if StandingStill == false then
		stopEquipTrack()
	end
end

function Handler.StartIdle(Character)
	Handler.StopIdle()

	if Character == nil then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Root = Character:FindFirstChild("HumanoidRootPart")

	if Humanoid == nil or Root == nil then
		return
	end

	local IdlePath = "Weapons." .. Weapons.GetCategory(Character)
	local IdleName = "Idle"
	local RageIdleName = Weapons.GetForCharacter(Character).RageIdleAnimation

	if RageIdleName ~= nil and Character:GetAttribute("Rage") == true then
		IdleName = RageIdleName
	end
	local IdleAnimation = nil

	if AnimationsModule.DetectSpecificAnimation(IdlePath, IdleName) then
		IdleAnimation = AnimationsModule.GetAnimation(IdlePath, IdleName)
	end

	if IdleAnimation ~= nil then
		local Animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid

		IdleTrack = Animator:LoadAnimation(IdleAnimation)
		IdleTrack.Priority = Enum.AnimationPriority.Idle
		IdleTrack.Looped = true

		IdleAnimation:Destroy()
	end

	IdleHumanoid = Humanoid
	IdleRoot = Root
	IdlePlaying = false

	IdleConnection = RunService.Heartbeat:Connect(updateIdle)

	RageConnection = Character:GetAttributeChangedSignal("Rage"):Connect(function()
		Handler.StartIdle(Character)
	end)

	updateIdle()
end

function Handler.StopIdle()
	if IdleConnection ~= nil then
		IdleConnection:Disconnect()
		IdleConnection = nil
	end

	if RageConnection ~= nil then
		RageConnection:Disconnect()
		RageConnection = nil
	end

	stopEquipTrack()

	if IdleTrack ~= nil then
		IdleTrack:Stop(IdleFadeTime)
		IdleTrack:Destroy()
		IdleTrack = nil
	end

	IdleHumanoid = nil
	IdleRoot = nil
	IdlePlaying = false
end

function Handler.ResetCombo()
	Handler.Variables.comboToken += 1
	Handler.Variables.debounce = false
	Handler.Variables.currTime = 0
	Handler.Variables.prevTime = 0
	Handler.Variables.count = 0
end

function Handler.PlayEquip(Character)
	if Character == nil then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local CanPlayAnimation = Humanoid ~= nil and Root ~= nil and isStandingStill(Humanoid, Root)

	stopEquipTrack()

	EquipTrack = WeaponFX.PlayEquip(Character, CanPlayAnimation)
end

function Handler.ClearSwing(Character)
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

	WeaponFX.ClearSwing(Humanoid)
end

game.ReplicatedStorage.Events.AC.OnClientEvent:Connect(function(Char)
	--// Air Combat //--
	if Char ~= nil and Char:FindFirstChild("AirCombat") then
		Handler.ResetCombo()
	end
end)

return Handler
