# Mechanics parity ledger

Unity source: `01_unity/ultravibe/Assets/Game/Scripts/GnosisFallingBlock/`
Godot target: `ultravibe/game/`

## Core falling-block loop

| Mechanic | Unity | Godot | Status |
|---|---|---|---|
| Grid 10×20 + 4 hidden | Core/GridDimensions | falling_block_service.gd | done |
| 32 ultravibe shapes | UltravibeRegistry | ultravibe_registry.gd | done |
| Gravity curve + difficulty | FallSpeed.partial | falling_block_gravity_curve.gd | done |
| Soft/hard drop + lock delay | GameplaySession | falling_block_service.gd | done |
| Rotation + 5-offset kicks | PieceLifecycleSystem | piece_lifecycle_system.gd | done |
| Line clear + collapse | GridSystem | grid_system.gd | done |
| heavy/rigid/eternal/soft/hard | PieceLifecycleSystem | piece_lifecycle_system.gd | done |
| Next queue (3) | DeckService | falling_block_deck_service.gd | done |
| Discards | Discard.partial | falling_block_service.gd | done |
| Hold piece | (vestigial) | — | n/a |

## Scoring / progression

| Mechanic | Status |
|---|---|
| points × multi + pending | done |
| Objective scaling | done |
| Round advancement | done |
| Boon scoreCalculations | done |
| Line-clear interceptor rules | done |
| Reward selection | done |

## Content systems (invocation-driven)

| System | Count | Status |
|---|---|---|
| Consumables | 23 | done — invocations wired |
| Abilities | 4 | done |
| Run upgrades | 8 | done |
| Item upgrades | 12 | done |
| Bosses | 24 | done — schedule + native effects |
| Game flags | 14 | done |

## Boss native effects (~20)

| Effect | Status |
|---|---|
| ReduceGravitySpeed | done |
| EnableRandomRotation (Chaos) | done |
| GhostOnly (Fates) | done |
| ForceBaseColorsOnly (Riza) | done |
| UnreliableInputs (Hypnos) | done |
| SpawnTrashLineIfNotPlacedWithin4Seconds (Icarus) | done |
| SpawnTrashLineEvery2LinesCleared (Themis) | done |
| RemoveDiscardsPerLineCleared (Persephone) | done |
| AutoDropAfterDelay (Titanos) | done |
| AutoDropAfterMoveCount (Zeus) | done |
| DisablePieceAfterDelay (Nemesis) | done |
| ConvertRandomBlockToNegativeOnPlacement (Xenon) | done |
| ReplaceBaseColorWithNegativeOnSpawn (Ares, …) | done |
| EnableWind (Boreas) | done |
| DisableGhost (Helios) | done |
| InvertControls (Dionysus) | done |
| Rule-backed (disable rotation/discard/consumables) | done — boss_effects.json |

## Variant tag simulation

| Tag | Status |
|---|---|
| placementDiscardChance (trash) | done |
| placementDiscardDrain (thief) | done |
| healing | done |
| poisoning | done |
| contagious | done |
| expansive (moss) | done |
| rising | done |
| sinking | done |
| linked (on clear) | done |
| slippery (stack gravity) | done |
| immutable (consumable respect) | done |

## Co-op (1–4 players)

| Mechanic | Status |
|---|---|
| Split-lane bounds | done — falling_block_player_runtime.gd |
| Per-lane row clear | done |
| Per-player runtime | done — falling_block_adapter.gd |
| gridShift ability | done |

## Meta (already ported)

Collection/wiki, settings, localization (13 langs), audio, themes, persistence — done.
