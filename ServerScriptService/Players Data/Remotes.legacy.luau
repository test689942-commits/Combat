local Modules = {
	["MainHandler"] = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("MainHandler")),
	["Client_Framework"] = require(game.ReplicatedStorage.Modules:WaitForChild("Moves"):WaitForChild("Combat")),
	["Combat_Server"] = require(game.ReplicatedStorage.Modules:WaitForChild("Moves"):WaitForChild("Combat"):WaitForChild("Server")),
}

--// CLient //--
game.ReplicatedStorage.Events.HandlerFireClient.OnServerEvent:Connect(function(plr,Module,Action,...)
	local Sender = plr.Character
	game.ReplicatedStorage.Events.HandlerFireClient:FireAllClients(Sender,Module,Action,...)
end)

--// Server //--
game.ReplicatedStorage.Events.HandlerFireServer.OnServerEvent:Connect(function(plr,Module,Action,...)
	if Module ~= nil and Action ~= nil and Modules[Module] ~= nil and Modules[Module][Action] ~= nil then
		Modules[Module][Action](...)
	end
end)
