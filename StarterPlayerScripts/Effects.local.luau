--// Variables \--

local localPlayer = game.Players.LocalPlayer

local MaxEffectDistance = 100

--// Setup \--

repeat
	task.wait()
until localPlayer.Character ~= nil

local Modules = {
	["MainHandler"] = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("MainHandler")),
	["Client_Framework"] = require(game.ReplicatedStorage.Modules:WaitForChild("Moves"):WaitForChild("Combat")),
}

--// Events \--

game.ReplicatedStorage.Events.HandlerFireClient.OnClientEvent:Connect(function(Sender, ModuleName, ActionName, ...)
	if ModuleName == nil or ActionName == nil then
		return
	end

	local Module = Modules[ModuleName]
	if Module == nil or Module[ActionName] == nil then
		return
	end

	if Sender == nil or localPlayer.Character == nil then
		return
	end

	local senderRoot = Sender:FindFirstChild("HumanoidRootPart")
	local localRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if senderRoot == nil or localRoot == nil then
		return
	end

	if (senderRoot.Position - localRoot.Position).Magnitude <= MaxEffectDistance then
		Module[ActionName](...)
	end
end)
