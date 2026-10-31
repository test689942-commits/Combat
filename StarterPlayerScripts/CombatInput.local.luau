-- Binds player input to the combat Handler (ReplicatedStorage.Modules.Moves.Combat.Input).
-- Nothing else in the game currently calls Handler.TryCombat / TryHeavy / TryBlock,
-- so without this script equipping a weapon does nothing when you click to attack.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Handler = require(ReplicatedStorage.Modules.Moves.Combat.Input)
local MovesInfo = require(ReplicatedStorage.Modules.Moves)
local CombatInfo = MovesInfo.Combat
local Weapons = require(ReplicatedStorage.Modules:WaitForChild("Weapons"))

local player = Players.LocalPlayer

local function getCharacter()
	return player.Character
end

-- Attack (M1)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local character = getCharacter()
		if character then
			task.spawn(Handler.TryCombat, character)
		end
	end
end)

-- Block (hold F)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == CombatInfo.Block.Key then
		local character = getCharacter()
		if character then
			Handler.TryBlock(character)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == CombatInfo.Block.Key then
		local character = getCharacter()
		if character then
			Handler.RemoveBlock(character)
		end
	end
end)

-- Heavy attack (hold/right-click M2)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		local character = getCharacter()
		if character then
			Handler.TryHeavy(character)
		end
	end
end)

--// Skills \\--

local movesFolder = ReplicatedStorage.Modules.Moves
local skillKeys = {}
local skillModules = {}

for moveName, info in MovesInfo do
	if info.Skill and info.Key then
		local moveModule = movesFolder:FindFirstChild(moveName)

		if moveModule and moveModule:IsA("ModuleScript") then
			skillKeys[info.Key] = moveName

			task.spawn(function()
				local success, move = pcall(require, moveModule)

				if success then
					skillModules[moveName] = move
				else
					warn("Skill failed to load (" .. moveName .. "): " .. tostring(move))
				end
			end)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	local moveName = skillKeys[input.KeyCode]
	local move = moveName and skillModules[moveName]
	local character = getCharacter()

	if not move or not character or not Weapons.HasMove(character, moveName) then
		return
	end

	task.spawn(move.TryStart)
end)

UserInputService.InputEnded:Connect(function(input)
	local moveName = skillKeys[input.KeyCode]
	local move = moveName and skillModules[moveName]

	if move then
		task.spawn(move.Release)
	end
end)

--// Weapon Changes \\--

local function cancelSkills()
	for _, move in skillModules do
		task.spawn(move.Cancel)
	end
end

local function onWeaponChanged(character)
	Handler.ResetCombo()
	Handler.ClearSwing(character)
	Handler.UnlockJump()
	cancelSkills()
	Handler.StartIdle(character)

	if Weapons.HasEquippedWeapon(character) then
		Handler.PlayEquip(character)
	end
end

-- Idle/locomotion animations need to be (re)started per character
local function onCharacterAdded(character)
	Handler.StartIdle(character)

	character:GetAttributeChangedSignal(Weapons.EquippedAttributeName):Connect(function()
		onWeaponChanged(character)
	end)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(function()
	Handler.StopIdle()
end)
