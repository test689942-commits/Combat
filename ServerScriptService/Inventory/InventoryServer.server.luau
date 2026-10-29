-- Creates the inventory remotes and owns inventory actions/saves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))

local remotes = ReplicatedStorage:FindFirstChild("InventoryRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "InventoryRemotes"
	remotes.Parent = ReplicatedStorage
end

local function getRemote(className: string, name: string)
	local remote = remotes:FindFirstChild(name)
	if remote and not remote:IsA(className) then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local getInventory = getRemote("RemoteFunction", "GetInventory") :: RemoteFunction
local action = getRemote("RemoteFunction", "Action") :: RemoteFunction
local updated = getRemote("RemoteEvent", "InventoryUpdated") :: RemoteEvent

getInventory.OnServerInvoke = function(player: Player)
	local success, result = pcall(InventoryService.GetSnapshot, player)
	if not success then
		warn("Inventory fetch failed for " .. player.Name .. ": " .. tostring(result))
		return {success = false, message = "Your inventory could not be loaded."}
	end
	return {success = true, snapshot = result}
end

action.OnServerInvoke = function(player: Player, actionName: string, payload)
	local success, result = pcall(InventoryService.HandleAction, player, actionName, payload)
	if not success then
		warn("Inventory action failed for " .. player.Name .. ": " .. tostring(result))
		return {success = false, message = "That inventory action failed."}
	end
	return result
end

InventoryService.Changed.Event:Connect(function(player: Player, snapshot)
	if player.Parent == Players then
		updated:FireClient(player, snapshot)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	InventoryService.Release(player)
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(InventoryService.Save, player)
		end
	end
end)

game:BindToClose(function()
	local players = Players:GetPlayers()
	if #players == 0 then return end

	local pending = #players
	local finished = Instance.new("BindableEvent")
	for _, player in ipairs(players) do
		task.spawn(function()
			InventoryService.Save(player)
			pending -= 1
			if pending == 0 then finished:Fire() end
		end)
	end
	finished.Event:Wait()
	finished:Destroy()
end)
