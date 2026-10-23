# Combat System — Updates & Architecture Guide

This repository contains the modular Roblox Luau combat, weapon, animation, and skill/move framework across `ReplicatedStorage`, `ServerScriptService`, `StarterPlayerScripts`, and `StarterCharacterScripts`.

---

## Table of Contents

1. [Repository Structure](#1-repository-structure)
2. [Summary of All Updates](#2-summary-of-all-updates)
   - [2.1 Consolidated Move Architecture (`Moves/Effects.luau` & `Moves/Server.luau`)](#21-consolidated-move-architecture-moveseffectsluau--movesserverluau)
   - [2.2 `ReplicatedStorage.Assets.Effects` Organized by Weapon Category](#22-replicatedstorageassetseffects-organized-by-weapon-category)
   - [2.3 Weapon Registry & Per-Weapon Animation Tables](#23-weapon-registry--per-weapon-animation-tables)
   - [2.4 `DragonSlayer` Greatsword (4-Swing Key-Event Weapon)](#24-dragonslayer-greatsword-4-swing-key-event-weapon)
   - [2.5 `DaggerDance` Skill Move](#25-daggerdance-skill-move)
   - [2.6 Locomotion (`Idle`, `walk`, `Sprint`) & Fallback to `Movement`](#26-locomotion-idle-walk-sprint--fallback-to-movement)
   - [2.7 Animation Key-Event Slash VFX & Lunge Removal](#27-animation-key-event-slash-vfx--lunge-removal)
   - [2.8 `Animations/Anims.luau` Naming Cleanup](#28-animationsanimsluau-naming-cleanup)
   - [2.9 Skill Parry & Cancel System](#29-skill-parry--cancel-system)
3. [Weapons Reference Table](#3-weapons-reference-table)
4. [Moves Reference Table](#4-moves-reference-table)
5. [Commit History Summary](#5-commit-history-summary)

---

## 1. Repository Structure

```text
├── ServerScriptService/
│   ├── CombatServer.legacy.luau        # Server M1/M2 combat & block remotes
│   ├── DashServer.legacy.luau          # Server dash validation & state
│   ├── MoveServer.legacy.luau          # Server skill activation & phase routing (uses Moves/Server.luau)
│   ├── StunHandler.legacy.luau         # Stun & walkspeed controller
│   └── WeaponServer/                   # Server weapon equip, unequip, switching & welding
├── StarterCharacterScripts/
│   └── BodyFlash.local.luau            # Character hit flash feedback
├── StarterPlayerScripts/
│   ├── CombatClient.local.luau         # Client M1/M2/Block & Z/X/C skill input handler
│   ├── DashClient.local.luau           # Client dash input & camera motion
│   ├── MoveEffects.local.luau          # Client VFX dispatcher (uses Moves/Effects.luau)
│   └── StunClient.local.luau           # Client stun UI/state feedback
└── combat/ReplicatedStorage/Modules/
    ├── Animations/
    │   ├── Anims.luau                  # Frozen animation ID dictionary (Weapons, Shared, Movement, Moves)
    │   └── init.luau                   # Animation loader, caching & priority playback API
    ├── Moves/
    │   ├── Effects.luau                # Centralized client VFX module for ALL moves
    │   ├── Server.luau                 # Centralized server hitboxes, damage & phase handlers for ALL moves
    │   ├── init.luau                   # Move registry & cooldown dispatcher
    │   ├── Combat/                     # M1/M2 combo system (Input, WeaponFX, Server)
    │   ├── Dash.luau                   # Directional dash & air dash
    │   ├── GroundSlam.luau             # Fists move (Z)
    │   ├── FistBarrage.luau            # Fists move (X)
    │   ├── Rage.luau                   # Greatsword move (R)
    │   ├── Leap.luau                   # Greatsword move (E)
    │   ├── Cut.luau                    # Dagger/Greatsword move (V)
    │   ├── DaggerThrow.luau            # Dagger move (G)
    │   ├── DaggerDance.luau            # Dagger move (B)
    │   ├── Thrust.luau                 # Axe move 1 (C) - yayy
    │   └── Spin.luau                   # Axe move 2 (T) - idk
    ├── Weapons/
    │   ├── init.luau                   # Weapon resolver (merges Category defaults + Registry overrides)
    │   ├── Registry.luau               # All weapon definitions (10 category primaries + DragonSlayer)
    │   ├── Combo.luau                  # Combo step builder & animation path resolver
    │   └── Categories/                 # Category defaults (Greatsword, Fists, Dagger, Katana, etc.)
    ├── Shared/                         # MainHandler, Knockback, Hitbox, Crator, Rocks, Raycast
    ├── Sounds/                         # SFX registry & playback manager
    └── Library.luau                    # Shared state, cooldown & velocity helper functions
```

---

## 2. Summary of All Updates

### 2.1 Consolidated Move Architecture (`Moves/Effects.luau` & `Moves/Server.luau`)
Replaced the separate per-move `Moves/<MoveName>/Effect.luau` and `Moves/<MoveName>/Server.luau` folders with two main modules:
- **`combat/ReplicatedStorage/Modules/Moves/Effects.luau`**:
  - Handles all client-side visual effects, rocks, craters, sound playback, and particle emitters for every skill move (`GroundSlam`, `FistBarrage`, `DropKick`, `Rage`, `Leap`, `Cut`, `DaggerThrow`, `DaggerDance`).
  - Wired directly into `StarterPlayerScripts/MoveEffects.local.luau` via `MoveEffects[effectName](data)`.
- **`combat/ReplicatedStorage/Modules/Moves/Server.luau`**:
  - Handles all server-side validation, state checks, cooldowns, hitboxes, knockback, and multi-phase damage (`Activate` and `Phase`) for every skill move.
  - Wired directly into `ServerScriptService/MoveServer.legacy.luau` via `MoveHandlers[moveName]`.
- **Flat Client Move Modules (`Moves/<MoveName>.luau`)**:
  - Each move (`GroundSlam.luau`, `FistBarrage.luau`, `DropKick.luau`, `Rage.luau`, `Leap.luau`, `Cut.luau`, `DaggerThrow.luau`, `DaggerDance.luau`) is now a clean single-file client module that plays the move animation, forwards animation key events (`GetMarkerReachedSignal`) to `Remotes.MovePhase`, and re-exports `.Effect = Effects.<MoveName>`.

---

### 2.2 `ReplicatedStorage.Assets.Effects` Organized by Weapon Category
`Moves/Effects.luau` resolves effect assets from a category-organized folder hierarchy under `ReplicatedStorage.Assets.Effects` (while automatically falling back to flat top-level names if an asset has not been moved yet in Studio):

```text
ReplicatedStorage.Assets.Effects
├── Fists/
│   ├── Stab2, Wind1, Wind2, groundslam, Impact, inversRing
│   └── Barrage
├── Greatsword/
│   ├── Scream, RageAura
│   └── Jump, SlamFX, Slam, TrailPart
├── Axe/
│   ├── Thrust, Slashup, SlashLast
│   └── Startup, Thrust, Spin
├── Dagger/
│   ├── Cut
│   ├── Dagger Slash
│   ├── Idk
│   ├── Slash Move
│   └── Slash Floor
├── Combat/
│   ├── Hit
│   └── Block
├── Dash/
│   └── Dash
└── Slashes/
    ├── GreatSword/
    │   ├── M1_Slash .. M4_Slash
    │   ├── Crit_Slash
    │   └── M1Swing, M1Floor, M2Swing, M2Floor, M3Swing, M3Slam, M3Floor, M4Swing
    ├── LongSword/
    ├── Axe/
    ├── Katana/
    ├── DualKatana/
    ├── Dagger/
    ├── Spear/
    └── Scythe/
```

---

### 2.3 Weapon Registry & Per-Weapon Animation Tables
- **Trimmed Weapon Registry (`Weapons/Registry.luau`)**:
  - Simplified down to **1 primary weapon per category** (10 base weapons: `GreatSword`, `Fists`, `Staff`, `LongSword`, `Axe`, `Mortal Blade`, `Dual KT`, `Steel Dagger`, `Steel Spear`, `Steel Scythe`) plus **`DragonSlayer`** as a second Greatsword (11 weapons total).
- **Standardized Per-Weapon Animation Tables (`Animations/Anims.luau`)**:
  - Every weapon has its own animation table under `Anims.Weapons.<WeaponName>` instead of sharing one animation table across an entire category.
  - Every weapon table uses a consistent key layout with `"rbxassetid://0"` for unused animation slots:
    ```luau
    Combat1 = "rbxassetid://...";
    Combat2 = "rbxassetid://...";
    Combat3 = "rbxassetid://...";
    Combat4 = "rbxassetid://...";
    Combat5 = "rbxassetid://...";
    Critical = "rbxassetid://...";
    Equip = "rbxassetid://...";
    Blocking = "rbxassetid://...";
    Idle = "rbxassetid://...";
    walk = "rbxassetid://...";
    run = "rbxassetid://...";
    ```

---

### 2.4 `DragonSlayer` Greatsword (4-Swing Key-Event Weapon)
Added **`DragonSlayer`** (`Category = "Greatsword"`) with custom combo, locomotion, and key-event particle behavior:
- **4 Swings Only (`MaxCombo = 4`)**:
  - `Combat1` (`M1`): `"rbxassetid://91138922124420"`
  - `Combat2` (`M2`): `"rbxassetid://110429591388952"`
  - `Combat3` (`M3`): `"rbxassetid://82396912225048"`
  - `Combat4` (`M4`): `"rbxassetid://129650220050908"`
  - `Combat5 = "rbxassetid://0"`
- **No `Idle`, `walk`, `run`, or `Critical`**:
  - `Idle`, `walk`, `run`, `Equip`, and `Critical` are set to `"rbxassetid://0"`.
  - Configured with `NoCritical = true` so the 4th swing finishes the combo without triggering a Critical animation or `Crit_Slash` effect.
- **8 Animation Key Events**:
  - Listens for `M1Swing`, `M1Floor`, `M2Swing`, `M2Floor`, `M3Swing`, `M3Slam`, `M3Floor`, and `M4Swing` (plus keyframe aliases `"Slash"`, `"Floor"`, `"Slam"` mapped to the current swing number).
  - Emits all descendant `ParticleEmitter`s honoring their **`EmitDelay`**, **`EmitDuration`** (`Particle.Enabled = true` for `EmitDuration` seconds, then `false`), and **`EmitCount`** attributes.

---

### 2.5 `DaggerDance` Skill Move
Added the **`DaggerDance`** skill (`X` move on `Steel Dagger`, animation `"rbxassetid://111287464837255"`):
- Driven by **3 animation key events** and **4 effect assets** (`"Dagger Slash"`, `"Idk"` on `"Right Arm"`, `"Slash Move"`, and `"Slash Floor"`):
  1. **`"Dagger Slash"`**:
     - Emits all `ParticleEmitter` descendants of `"Dagger Slash"` using `Particles:Emit(Particles:GetAttribute("EmitCount"))`.
     - Deals a single hit of damage on the server (`Phase = "Dagger Slash"`).
  2. **`"Slash Move"`**:
     - Sets `Enabled = true` on all `ParticleEmitter`, `Trail`, and `Beam` descendants of `Right Arm.Idk`, `"Slash Move"`, and `"Slash Floor"`.
     - Starts a server-side multi-hit damage loop dealing small rapid ticks of damage until `"End"` is reached.
  3. **`"End"`**:
     - Sets `Enabled = false` on all `ParticleEmitter`, `Trail`, and `Beam` descendants of `Right Arm.Idk`, `"Slash Move"`, and `"Slash Floor"`, stops the damage tick loop, and cleans up the cloned VFX attachments.

---

### 2.6 Locomotion (`Idle`, `walk`, `Sprint`) & Fallback to `Movement`
- Weapon animation tables retain their required `Idle`, `walk`, and `run` slots. When a weapon's locomotion slot is `"rbxassetid://0"`, the client uses the shared movement fallback rather than another weapon's animation.
- Shared locomotion has one `Sprint` animation (`rbxassetid://70903321662399`)—there is no separate shared `run` animation. Weapon `run` requests fall back to `Movement.Sprint`; `FastSprint` remains a distinct faster animation.

---

### 2.7 Animation Key-Event Slash VFX & Lunge Removal
- **Key-Event Driven Slash VFX (`Moves/Combat/WeaponFX.luau`)**:
  - Greatsword (`M1 Slash`..`M4 Slash`, `Crit Slash`) and `DragonSlayer` (`M1Swing`..`M4Swing`) emit their slash VFX on animation key events via `track:GetMarkerReachedSignal(markerName)` rather than fixed timer delays.
  - Renamed the Greatsword critical slash effect part from `Crit` to **`Crit_Slash`**.
  - Removed code-imposed slash rotation flipping so pre-oriented slash assets spawn at their authored orientation relative to `HumanoidRootPart`.
- **Removed Forward Swing Lunge**:
  - Removed the slight forward player velocity impulse (`Push`) when performing M1 weapon swings.

---

### 2.8 `Animations/Anims.luau` Naming Cleanup
- Renamed the top-level `Anims.Combat` table to **`Anims.Shared`**.
- Renamed `Anims.Shared.Punch.Combat1..5` to **`Punch1..5`**.
- Renamed `Anims.Shared.Idle.Combat` to **`Anims.Shared.Idle.Default`**.

---

### 2.9 Skill Parry & Cancel System
- **Regular Blocking vs. Parrying on Skills (`Moves/init.luau`, `Moves/MoveHit.luau` & `Moves/Server.luau`)**:
  - Regular blocking (`Blocking` without `PB`) does not block skills — skills break/bypass regular block (`CombatServer.DestroyBlock`).
  - **Per-Skill `Parryable` Flag (`Moves/init.luau`)**:
    - Each skill in `Moves/init.luau` defines `Parryable = true` or `Parryable = false` (checked via `MoveHit.CanParryMove`).
    - **`Rage` has `Parryable = false`** so it **cannot be parried** even if the defender is inside their `PB` parry window (it bypasses parry/block and stuns nearby targets).
    - Any other skill can be made unparryable at any time by setting `Parryable = false` on its entry in `Moves/init.luau`.
  - **Parrying a Parryable Skill at the Right Time (`Blocking` with `PB` active within the `ParryWindow`)** parries and **cancels** the skill (`GroundSlam`, `FistBarrage`, `DropKick`, `Leap`, `Cut`, `DaggerThrow`, `DaggerDance`):
    1. The defender takes **no damage, stun, or knockback**.
    2. The attacker's `DoingMove` state is cleared and replaced with `Stun` (`CombatInfo.Block.ParryStun`).
    3. All ongoing server skill loops/ticks/phases (`FistBarrage`, `Cut`, `DaggerDance`, `DropKick`, `Leap`, `GroundSlam`, `DaggerThrow`) immediately abort.
    4. The Parry VFX and `Parry` / `Parried` animations (`Enum.AnimationPriority.Action4`) play on the defender and attacker, stopping any active skill animation track.
    5. `Remotes.Effects` broadcasts `"CancelMove"` (`Effects.CancelMove`) and `MoveClient.WaitForMove` interrupts the caster's client-side movement/dash/VFX immediately.

---

### 2.10 Movement System (`ClientSystem`, `StarterCharacterScripts`)
- **Directional Movement Body-Tilt (`ClientSystem/DirectionalMovement.luau`)**:
  - Smoothly tilts `RootJoint`, `Right Hip`, `Left Hip`, and `Neck` `Motor6D.C0` based on horizontal velocity vs. character facing direction.
  - Automatically resets to neutral pose when idle (`> 2s`), facing a wall within `2` studs, or in any combat/stun/action state (`Stun`, `DoingCombat`, `DoingMove`, `Blocking`).
- **Double-Tap `W` Sprint, FastSprint & Sprint Visuals (`ClientSystem/Inputs/Sprint.luau`, `ClientSystem/SprintVisuals.luau`)**:
  - Double-tapping `W` starts with the `FastSprint` animation (`92394376692356`), then switches to `Sprint` (`70903321662399`) after 3 seconds of continuous sprinting.
  - Arm trails and camera visuals activate immediately. The `SpeedSprinting` effect from `ReplicatedStorage.Assets.Effects.Movement` starts only after that 3-second delay.
- **Movement VFX Location (`ReplicatedStorage.Assets.Effects.Movement`)**:
  - Movement and dash VFX are stored in the `Movement` folder: `Ring`, `Arm Trail`, `Back`, `Forward`, `Left`, `Right`, `SideDust`, `SpeedSprinting`, `Trail`, and `TransparentArmTrail`.
  - Dash now looks in `Effects.Movement` first for direction bursts, `Ring`, and arm-trail attachments (with legacy `Dash` / `DashVFX` fallback).
- **Slide, LongJump, WallClimb, Vault & WallRun (`ClientSystem/Movement.luau`, `ClientSystem/WallRun.luau`)**:
  - `LeftControl` performs the slide animation (`Sliding` = `134302481749326`) and plays slide audio (`rbxassetid://6429226498`). Pressing `Space` during slide triggers the forward-upward **LongJump** animation (`71457670921368`).
  - Jump input near a wall performs either a vertical **WallClimb** boost or a ledge **Vault** (alternating `Vault1` = `111806598954502` and `Vault2` = `87942706676175`). WallRun plays the corresponding left/right run and jump animations.
  - Ordinary jumping plays the jump animation and footstep jump sound only; no movement particle effect is emitted on jump. The movement controller does not treat combat effects (such as `Greatsword/Jump`) as movement VFX.
- **Movement Animations (`Animations/Anims.luau`, `StarterCharacterScripts/Animate.local.luau`)**:
  - `Idle`: `139783125255456`, `walk`: `81874417224388`, `Sprint`: `70903321662399`, `FastSprint`: `92394376692356`, `jump`: `135702083168555`, `Fall`: `120908359783163`.
  - `WallRun`: `Left Jump` (`119937163876536`), `Left Run` (`118914310248428`), `Right Jump` (`109550456840533`), `Right Run` (`92324260993876`).
  - `Vault`: `Vault1` (`111806598954502`), `Vault2` (`87942706676175`).
  - `Slide`: `LongJump` (`71457670921368`), `Sliding` (`134302481749326`).
- **Shiftlock Offset & Combat Jump Tuning (`ClientSystem/CameraShiftlock.luau`)**:
  - Applies custom Shiftlock camera offset (`Vector3.new(1.3, 0.35, 0)`), custom Shiftlock mouse icon (`http://www.roblox.com/asset/?id=109916623354797`), camera zoom bounds (`0..20`), and consecutive-jump height/power decay while in combat.
- **Material-Mapped Footsteps (`ClientSystem/FootSteps.luau`, `StarterCharacterScripts/MovementController.local.luau`)**:
  - Plays material-mapped footstep and jump sounds across `Concrete`, `Tile`, `Wood`, `Glass`, `Metal_Solid`, `Metal_Grate`, `Dirt`, `Grass`, `Carpet`, `Gravel`, `Snow`, `Sand`, `Rubber`, and `Mud`.

---

## 3. Weapons Reference Table

| Weapon Name | Category | Swings (`MaxCombo`) | Critical | Moves (`Z` / `X` / `C`) | Notes |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **`GreatSword`** | `Greatsword` | 5 | Yes (`Crit_Slash`) | `Rage`, `Leap`, `Cut` | Emits `M1_Slash`..`M4_Slash` & `Crit_Slash` on markers |
| **`DragonSlayer`** | `Greatsword` | 4 | No (`NoCritical`) | `Rage`, `Leap`, `Cut` | No Idle/walk/run; emits `M1Swing`..`M4Swing` & Floor/Slam markers |
| **`Fists`** | `Fists` | 5 | Yes | `GroundSlam`, `FistBarrage` | Unarmed combat style |
| **`Staff`** | `Staff` | 4 | Yes | `GroundSlam`, `Leap` | Blunt staff style |
| **`LongSword`** | `Longsword` | 4 | Yes | `Cut`, `Leap` | Balanced blade style |
| **`Axe`** | `Axe` | 4 | Yes | `Thrust`, `Spin` | Heavy axe style (`yayy` & `idk` moves) |
| **`Mortal Blade`** | `Katana` | 5 | Yes | `Cut`, `Leap` | Fast katana style |
| **`Dual KT`** | `DualKatana` | 5 | Yes | `Cut`, `FistBarrage`, `Leap` | Dual-wield katana style |
| **`Steel Dagger`** | `Dagger` | 4 | Yes | `DaggerThrow`, `DaggerDance` | Quick dagger style |
| **`Steel Spear`** | `Spear` | 4 | Yes | `Leap`, `Cut` | Long-reach polearm style |
| **`Steel Scythe`** | `Scythe` | 4 | Yes | `Cut`, `Leap`, `Rage` | Wide-arc reaper style |

---

## 4. Moves Reference Table

| Move Name | Category Folder | Parryable | Client Module | VFX Handler | Server Handler | Description |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- |
| **`GroundSlam`** | `Fists` | Yes | `Moves/GroundSlam.luau` | `Effects.GroundSlam` | `Server.GroundSlam` | AoE ground impact with crater, rocks & knockup |
| **`FistBarrage`** | `Fists` | Yes | `Moves/FistBarrage.luau` | `Effects.FistBarrage` | `Server.FistBarrage` | Rapid multi-hit flurry of punches |
| **`Rage`** | `Greatsword` | **No** | `Moves/Rage.luau` | `Effects.Rage` | `Server.Rage` | Unparryable warcry AoE shockwave + temporary damage buff |
| **`Leap`** | `Greatsword` | Yes | `Moves/Leap.luau` | `Effects.Leap` | `Server.Leap` | High-arcing jump slam with landing shockwave |
| **`Cut`** | `Greatsword` | Yes | `Moves/Cut.luau` | `Effects.Cut` | `Server.Cut` | Heavy forward cleaving slash |
| **`DaggerThrow`** | `Dagger` | Yes | `Moves/DaggerThrow.luau` | `Effects.DaggerThrow` | `Server.DaggerThrow` | Ranged dagger projectile triggered on `Throw` marker |
| **`DaggerDance`** | `Dagger` | Yes | `Moves/DaggerDance.luau` | `Effects.DaggerDance` | `Server.DaggerDance` | Key-event combo (`Dagger Slash` single hit + `Slash Move` multi-hit ticks until `End`) |
| **`Thrust`** | `Axe` | Yes | `Moves/Thrust.luau` | `Effects.Thrust` | `Server.Thrust` | Axe combo (`Thrust`, `Slashup`, `SlashLast` key events on `HumanoidRootPart`) |
| **`Spin`** | `Axe` | Yes | `Moves/Spin.luau` | `Effects.Spin` | `Server.Spin` | Axe spin combo (`Startup` on weapon `Handle`, `Thrust` & `Spin` on `HumanoidRootPart`, `End` cleanup) |

---

## 5. Commit History Summary

- **Latest** — Add Axe `Thrust` (`yayy`) and `Spin` (`idk`) moves and remove `DropKick`.
- **`68bdeaa`** — Add per-skill `Parryable` setting and make `Rage` unparryable.
- **`fa2cd9a`** — Add skill parry & cancel system across `Moves/MoveHit.luau`, `Moves/Server.luau`, `Moves/Effects.luau`, `Moves/MoveClient.luau`, `Moves/Combat/init.luau`, and all client move modules.
- **`b562d47`** — Update `DragonSlayer` `M1`–`M4` (`Combat1`–`Combat4`) animation IDs in `Animations/Anims.luau`.
- **`c6583f7`** — Add `DragonSlayer` Greatsword with 4 swings (`MaxCombo = 4`), no `Idle`/`walk`/`run`/`Critical`, and key-event VFX (`M1Swing`, `M1Floor`, `M2Swing`, `M2Floor`, `M3Swing`, `M3Slam`, `M3Floor`, `M4Swing`).
- **`6f9dc9d`** — Trim weapon registry and animation tables down to 1 primary weapon per category (10 base weapons).
- **`bdb8272`** — Update `Animations/Anims.luau` with latest weapon and move animation IDs (`DSIdle`, `Axe`, `Steel Dagger`, `DaggerDance`).
- **`188907e`** — Update `ServerScriptService/MoveServer.legacy.luau` and `StarterPlayerScripts/MoveEffects.local.luau` to use `Moves/Server.luau` and `Moves/Effects.luau`.
- **`ce5e493`** — Consolidate all move `Effect` and `Server` modules into `Moves/Effects.luau` and `Moves/Server.luau` and organize `Assets.Effects` by weapon category.
- **`5b5c6ed` / `5c4b1b9`** — Add `DaggerDance` move with animation key events (`"Dagger Slash"`, `"Slash Move"`, `"End"`), attachment VFX, and multi-hit tick damage.
- **`9b8e29b` / `1a82054`** — Standardize weapon tables in `Animations/Anims.luau` with `Idle`, `walk`, `run`, and `"rbxassetid://0"` placeholders + fallback to `Movement`.
- **`5269822`** — Give every weapon its own animation table and remove forward swing lunge.
- **`487ee21`** — Rename top-level `Combat` animations section to `Shared` and `Punch` entries to `Punch1..5`.
- **`960e977` / `d7f97a5`** — Drive Greatsword slash effects from animation key events via `GetMarkerReachedSignal`, rename crit effect to `Crit_Slash`, and remove code-imposed slash rotation.
