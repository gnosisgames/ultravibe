# Mechanics parity ledger (Match-3)

Unity source: `old_unity/ultravibe_unity/Assets/Game/Scripts/GnosisMatch3/`  
Godot target: `ultravibe/game/match3/`

**Sprint backlog:** [ULTRAVIBE_MATCH3_PARITY_SPRINTS.md](ULTRAVIBE_MATCH3_PARITY_SPRINTS.md)

## Status keys

| Status | Meaning |
|---|---|
| **done** | Unity behavior identified, Godot executes it, focused test exists |
| **partial** | Core path works; edge cases or polish remain |
| **missing** | Not implemented in Godot |
| **godot+** | Godot exceeds Unity (intentional) |

## Core loop

| Mechanic | Status | Tests |
|---|---|---|
| Swap, cascade, gravity, spawn | done | `test_match3_core` |
| Irregular boards (134) | done | `test_match3_core` |
| 8 floors × 3 rounds | done | `test_match3_core` |
| Level select + shop | done | `test_match3_core`, `test_shop_polish` |
| Skip / double-down | done | `test_match3_core`, `test_skip_then_floor_consumable` |
| Round-action consumables | done | `test_skip_then_floor_consumable` |
| Boss rounds + reroll boss | partial | `test_boss_match3_effects` |
| Match3 effects (20) | partial | `test_disable_color_block`, `test_boss_match3_effects` |
| Cell floors + modifier pool | partial | `test_cell_floor_effects`, `test_floor_modifier_pool` |

## Economy & inventory

| Mechanic | Status | Tests |
|---|---|---|
| Shop buy / reroll / pricing | done | `test_shop_polish` |
| Boon sell (inventory) | done | `test_boon_sell` |
| Consumable sell (inventory) | done | `test_consumable_sell` |
| Run upgrades (9 Golden*) | done | `test_run_upgrade_invokes`, `test_lucky_find_upgrade` |
| Item upgrades (6 colors) | done | `test_item_level_upgrades`, `test_item_upgrade_grant` |
| Lucky Find | godot+ | `test_lucky_find`, `test_lucky_find_upgrade` |

## Boons & consumables

| Mechanic | Status | Tests |
|---|---|---|
| Boon flavors (7) | partial | `test_boon_flavors` |
| Boon grants / echoes | partial | `test_boon_grants`, `test_iconic_uncommon_echo` |
| Move hooks / finalize | partial | `test_boon_move_hooks`, `test_ephemeral_finalize_boons` |
| Scaling counters | partial | `test_brainrot_scaling_increment` |
| Topology / match component | partial | `test_match_component_axis_boons`, `test_topology_intersection_shapes` |

## Meta & platform

| Mechanic | Status | Tests |
|---|---|---|
| Save & continue | done | `test_continue_run` |
| Endless mode (post–round 24) | done | `test_endless_mode` |
| Collection compendium | godot+ | manual |
| i18n (13 langs) | done | `test_catalog_localization` |
| Persistence boundaries | done | `test_persistence_boundaries` |

## Legacy (not active)

Falling-block / Polyomino mechanics ledgers and tests live under:

- `game/_legacy_polyomino/`
- `tests/_legacy_polyomino/`
- `data/Upgrades/` (not in `configuration.json`)

## Working rule

A mechanic is **not done** until a focused Godot test or golden scenario proves it.  
**Smoke CI:** `./tests/run_tests.sh` · **Extended:** `./tests/run_tests_extended.sh`
