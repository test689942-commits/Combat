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

`StarterPlayerScripts/EquipUI.local.luau` keeps the existing GUI, rendering, and animations, but loads item state from `Inventory.Client`. Equip, unequip, Equip Best, and sale actions send server item IDs and redraw from the returned snapshot; the UI also refreshes from `OnUpdated`. The client does not locally mutate authoritative inventory.

## Weapon items and combat equip

Weapon definitions are sourced from `ReplicatedStorage.Modules.Weapons` and use registry keys such as `GreatSword`, `DragonSlayer`, `Staff`, `LongSword`, `Axe`, `Mortal Blade`, `Dual KT`, `Steel Dagger`, `Steel Spear`, and `Steel Scythe`. `Fists` is an unarmed combat style and is not seeded as a physical weapon item.

A weapon item stores the registry key in `weaponId`. When one is equipped, the server sets the character's `EquippedWeaponId` attribute; combat reads that registry key directly, so no Roblox `Tool` or hotbar tool is created. The weapon model is still attached visually by `WeaponServer`. Unequipping clears the attribute, and the server reapplies the selected weapon on character respawn.

New profiles contain weapons only: the registry's Great Sword starts equipped and the other physical registry weapons are in the bag. Fists is omitted because it is an unarmed style, not a weapon model. Older saved armor, materials, fictional demo weapons, and non-registry move/stat rolls are filtered during migration. The UI shows only combo damage/cooldown and move names from the combat weapon data. Future weapon drops must reference a registry key:

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
