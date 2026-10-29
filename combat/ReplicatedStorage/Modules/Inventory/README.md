# Inventory folder

The inventory data and client API live here. The server-owned implementation and bootstrap are in `ServerScriptService/Inventory`.

## Snapshot and actions

```lua
local Inventory = require(game.ReplicatedStorage.Modules.Inventory.Client)
local ok, snapshotOrError = Inventory.Get()

-- The UI should replace its local item data and gold with a successful snapshot.
local success, updatedSnapshotOrError = Inventory.Equip(itemId)
Inventory.Unequip(itemId)
Inventory.EquipBest()
Inventory.SellMany({itemId1, itemId2})

Inventory.OnUpdated(function(snapshot)
    -- Refresh the UI after server-side loot is awarded.
end)
```

Each method returns `(success, snapshotOrError)`. A snapshot contains `gold` and `items`; each item has `id`, `n`, `r`, `slot`, `tag`, `qty`, `lvl`, `loc`, `eqSlot`, and server-generated `stats`.

In the existing EquipUI script, use `Inventory.Get()` to initialize `ITEMS` and `State.gold`; call `Equip`, `Unequip`, `EquipBest`, and `SellMany` from the matching UI buttons, then redraw from the returned snapshot. The UI script is not currently a file in this checkout, so its local demo state still needs those API calls to become server-backed.

## Starter data and future drops

New profiles start with the sample equipment/items from the pasted UI script. This checkout had no loot/drop or existing inventory persistence system. Server loot code can award items with:

```lua
InventoryService.AddItem(player, {
    n = "Glacier Blade", r = "rare", slot = "weapon", tag = "Weapon",
}, 1)
```

`DataStoreService` must be enabled for persistence in Studio. If loading fails, the service uses a session-only starter profile and intentionally won't save over data it couldn't read.
