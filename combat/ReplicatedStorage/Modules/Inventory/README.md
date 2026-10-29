# Inventory

The server-owned inventory service and bootstrap are in `ServerScriptService/Inventory`. This shared folder contains the item catalog and the client API.

## Client API

```lua
local Inventory = require(game.ReplicatedStorage.Modules.Inventory.Client)

local ok, snapshotOrError = Inventory.Get()
if ok then
    renderInventory(snapshotOrError)
end

local success, updatedSnapshotOrError = Inventory.Equip(itemId)
if success then renderInventory(updatedSnapshotOrError) end

Inventory.Unequip(itemId)
Inventory.EquipBest()
Inventory.SellMany({itemId1, itemId2})

Inventory.OnUpdated(function(snapshot)
    -- Refresh after a server-side loot award.
    renderInventory(snapshot)
end)
```

Each request returns `(success, snapshotOrError)`. A snapshot contains `gold` and `items`; each item has `id`, `n`, `r`, `slot`, `tag`, `qty`, `lvl`, `loc`, `eqSlot`, `weaponId` (for weapons), and server-generated `stats`.

UI actions must use server item IDs, then redraw from the returned snapshot (and from `OnUpdated`) rather than mutating a local copy of inventory state. The EquipUI source supplied in chat is not present in this checkout, so its button handlers/rendering code still needs to be added here before the existing GUI can be directly wired and verified.

## Weapon items and combat equip

Weapon definitions are sourced from `ReplicatedStorage.Modules.Weapons` and use registry keys such as `GreatSword`, `DragonSlayer`, `Staff`, `LongSword`, `Axe`, `Mortal Blade`, `Dual KT`, `Steel Dagger`, `Steel Spear`, and `Steel Scythe`. `Fists` is an unarmed combat style and is not seeded as a physical weapon item.

A weapon item stores the registry key in `weaponId`. When one is equipped, the server creates a non-droppable character `Tool` with its `Weapon` attribute set to that registry key. The combat system recognizes this Tool; the existing weapon model attach script responds to the Tool being added. Unequipping removes the inventory-managed Tool. The server re-applies the selected weapon on character respawn.

New profiles start with the registry's Great Sword equipped and the other physical registry weapons in the bag, alongside the sample nonweapon items/equipment. Future weapon drops must reference a registry key:

```lua
local InventoryService = require(game.ServerScriptService.Inventory.InventoryService)

InventoryService.AddItem(player, {
    n = "Dragon Slayer",
    r = "mythic",
    slot = "weapon",
    weaponId = "DragonSlayer",
    tag = "Weapon",
}, 1)
```

`DataStoreService` must be enabled for persistence in Studio. If loading fails, the service uses a session-only starter profile and intentionally will not save over data it could not read. Legacy version-1 inventory saves are migrated by matching weapon display names to the current registry; the old starter `Void Blade` maps to `GreatSword`, and non-registry demo weapons are discarded.
