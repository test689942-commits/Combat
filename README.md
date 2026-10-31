# Combat

Roblox combat, weapon, movement, VFX, and inventory code, organized by the Roblox services where each script belongs.

## Project layout

```text
ReplicatedStorage/Modules/
├── Animations/       # Animation definitions and loader
├── ClientSystem/     # Movement, dash, sprint, slide, wall-run, and camera controllers
├── Hitbox/           # Hitbox signals and helpers
├── Inventory/        # Shared weapon catalog and client inventory API
├── Moves/            # Combat input/effects/server handlers and individual skill modules
├── Shared/           # MainHandler, hit detection, effects, library, and utilities
├── Sounds/           # Sound registry and playback helpers
└── Weapons/          # Weapon registry, combat categories, and combo definitions

ServerScriptService/
├── Inventory/        # Persistent inventory service and remote bootstrap
├── MoveServer.legacy.luau
├── Players Data/Remotes.legacy.luau
└── WeaponServer.legacy.luau

StarterCharacterScripts/
├── Animate.local.luau
└── MovementController.local.luau

StarterPlayerScripts/
├── CombatInput.local.luau
├── Effects.local.luau
├── EquipUI.local.luau
└── MoveEffects.local.luau
```

Roblox assets and GUI instances (such as `ReplicatedStorage.Assets` and `PlayerGui.EquipUI`) are referenced by the scripts but are not represented as source files in this repository. Keep those Studio hierarchies and names in sync with the lookups in the code.

## Combat and weapon flow

- `StarterPlayerScripts/CombatInput.local.luau` binds combat input and skill keys. M1 starts the combo, Mouse 2 starts Heavy, and F blocks. Skill keys and requirements are declared in `ReplicatedStorage/Modules/Moves/init.luau`.
- `ReplicatedStorage/Modules/Moves/Combat/` contains the client input handler, combat server logic, weapon animations/VFX, and shared combat effects.
- Skill moves are registered in `Moves/init.luau`. Their client modules live in `Moves/` (for example `Rage.luau`, `Leap.luau`, `DaggerDance.luau`, `Thrust.luau`, and `Spin.luau`); `Moves/Server.luau` handles server-side move phases and hit validation, and `Moves/Effects.luau` dispatches move effects.
- `ReplicatedStorage/Modules/Weapons/Registry.luau` is the source of weapon keys, names, categories, and weapon-specific move configuration. `Weapons/init.luau` combines those entries with the shared `Weapons/Categories/` and `Weapons/Combo.luau` definitions.
- The server equips a weapon by setting the character's `EquippedWeaponId` attribute. Combat reads that key from the registry; `ServerScriptService/WeaponServer.legacy.luau` attaches the matching visual model. This equip path does not require a Roblox Tool.

### Registered weapons

`GreatSword`, `DragonSlayer`, `Fists`, `Staff`, `LongSword`, `Axe`, `Mortal Blade`, `Dual KT`, `Steel Dagger`, `Steel Spear`, and `Steel Scythe` are defined in the weapon registry. Use the registry key (not the display name) when referring to an equipped weapon or awarding a weapon.

### Skill keys

The current move registry assigns: Z — Ground Slam; X — Fist Barrage; R — Rage; E — Leap; V — Cut; G — Throw; B — Dagger Dance; C — Thrust; T — Spin. Q is the directional dash key. Move availability and cooldowns are defined in the registries rather than duplicated in the input script.

## Movement

`ReplicatedStorage/Modules/ClientSystem/` contains the movement controller modules. `MovementController.local.luau` starts the client system, with additional modules for directional movement, sprint visuals, footsteps, shiftlock, and wall-running. The default binds are initialized in `ClientSystem/init.luau`; the input modules implement dash, Heavy, jump, and slide controls. Movement animation and character animation logic are in `Animations/` and `StarterCharacterScripts/Animate.local.luau`.

## Persistent weapon inventory

The current inventory is weapon-only; the catalog and combat registry are the source of truth for owned weapons.

- `ReplicatedStorage/Modules/Inventory/Catalog.luau` seeds the starter profile with Great Sword equipped and the other registry weapons in the bag. It derives weapon combat details from the same registry/combo data used by combat.
- `ReplicatedStorage/Modules/Inventory/Client.luau` exposes `Get`, `Equip`, `Unequip`, `EquipBest`, `SellMany`, and `OnUpdated` for UI code.
- `StarterPlayerScripts/EquipUI.local.luau` keeps the existing GUI and animations while using the server inventory API for item state and actions. It expects the `PlayerGui.EquipUI` ScreenGui hierarchy described at the top of the script; it does not create the GUI itself.
- `ServerScriptService/Inventory/InventoryService.luau` owns profile validation, item actions, weapon equip state, and persistence. `InventoryServer.server.luau` creates the remotes and handles saves.
- Future server-side loot code should award weapons with `InventoryService.AddItem(player, definition)`, providing a valid `weaponId` from `Weapons/Registry.luau`.

Inventory data is stored in the `CombatInventory_v1` DataStore. Enable Studio API access when testing persistence in Studio. The service uses a session-only starter profile when DataStore loading fails and avoids saving that fallback over data it could not load.

## Assets and testing notes

The scripts expect weapon models under `ReplicatedStorage.Assets.Weapons`, plus the combat, movement, and move effects referenced by `Moves/Effects.luau`, `Moves/Combat/WeaponFX.luau`, and the client-system modules. GUI and asset instances need to be present in the place file for those references to resolve. Validate remote calls, asset names, DataStore access, and combat in Roblox Studio; Luau syntax checks alone do not verify the Studio hierarchy or runtime behavior.
