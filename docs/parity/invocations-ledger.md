# FallingBlock invocation ledger

Functions referenced by Godot JSON catalogs (`data/`) via `"service": "FallingBlock"`.

| Function | Used by | Godot status |
|---|---|---|
| AddBaseDiscardsDelta | Upgrades (discardUpgrade, …) | done — `falling_block_invocations.gd` |
| AddDiscards | Rules (boon_trigger_discard) | done |
| AddVariantLevelDelta | Consumables (color cubes), ItemUpgrades | done |
| ApplyEffect | Bosses (24) | done — stores + native runtime |
| ApplyStackGravityAndClear | Consumables (feather) | done |
| ChangeFallSpeed | Consumables (balloon) | done |
| ClearEntireGridAndRespawn | Consumables (bomba) | done |
| ClearRandomNonEmptyLockedRows | Abilities (axe) | done |
| ClearRowsAboveLowestNonEmptyColumnHeight | Abilities (hammer) | done |
| DestroyCurrentPiece | Consumables (rip) | done |
| DuplicateCurrentDeckEntry | Consumables (mirror) | done |
| ExecuteGridShiftAbility | Abilities (gridShift, co-op) | done |
| FillSingleGapsInNonEmptyRowsAndClear | Abilities (gum) | done |
| GrantRandomEligibleUpgrade | Rewards | done — delegates to Upgrade service |
| MirrorRightHalfToLeftAndClear | Consumables (butterfly) | done |
| PlayFallingPieceFeedback | Consumables (VFX-only) | done — no-op ok |
| RemoveEffect | Bosses (24) | done |
| SetFallingPieceVariant | Consumables (color cubes) | done |
| SpawnTrashLines | Rules (boss_effects), boss native effects | done |

Rule interceptor targets (not direct service functions):

| Target | Rule file | Godot status |
|---|---|---|
| FallingBlock.AddDiscards | boon_trigger_discard.json | done |
| FallingBlock.SpawnTrashLines | boss_effects.json | done |

Unity source: `FallingBlockGnosisService.Consumables.partial.cs`, `Discard.Statistics.partial.cs`, `VariantLevels.partial.cs`, `TrashLines.partial.cs`, `Abilities.partial.cs`, `Reward.partial.cs`.
