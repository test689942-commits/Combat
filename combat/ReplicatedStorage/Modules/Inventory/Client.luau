-- Client API for the server-owned inventory. UI code should render only returned snapshots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes")
local getInventoryRemote = remotes:WaitForChild("GetInventory")
local actionRemote = remotes:WaitForChild("Action")
local updatedRemote = remotes:WaitForChild("InventoryUpdated")

local InventoryClient = {}

local function request(remote, ...)
	local arguments = table.pack(...)
	local ok, response = pcall(function()
		return remote:InvokeServer(table.unpack(arguments, 1, arguments.n))
	end)
	if not ok then
		return false, tostring(response)
	end
	if type(response) ~= "table" or response.success ~= true then
		return false, if type(response) == "table" then response.message or "Inventory request failed." else "Invalid server response."
	end
	return true, response.snapshot
end

function InventoryClient.Get()
	return request(getInventoryRemote)
end

function InventoryClient.Action(action: string, payload)
	return request(actionRemote, action, payload)
end

function InventoryClient.Equip(itemId: number)
	return InventoryClient.Action("Equip", {itemId = itemId})
end

function InventoryClient.Unequip(itemId: number)
	return InventoryClient.Action("Unequip", {itemId = itemId})
end

function InventoryClient.EquipBest()
	return InventoryClient.Action("EquipBest")
end

function InventoryClient.SellMany(itemIds: {number})
	return InventoryClient.Action("SellMany", {itemIds = itemIds})
end

function InventoryClient.OnUpdated(callback)
	return updatedRemote.OnClientEvent:Connect(callback)
end

return InventoryClient
