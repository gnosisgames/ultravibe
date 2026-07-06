# Boon & consumable depth audit (Sprint 5)

Unity reference: `old_unity/ultravibe_unity/Assets/Game/Scripts/GnosisMatch3/`  
Godot: `game/match3/boons/`, `data/Boons/`, `data/consumables/`

**Automated checks:** `tests/test_boon_consumable_depth.gd` plus extended suite boon tests below.

## Effect application (`perInstance` vs `catalogOnce`)

| Mode | Rule | Godot | Test |
|------|------|-------|------|
| `perInstance` | Each equipped copy runs round effects | `_for_each_equipped_boon_slot_with_effect_application` | `test_boon_consumable_depth` |
| `catalogOnce` | One contribution per catalog id | same helper, first slot only | `test_boon_consumable_depth` |

Examples: CookieTime / PassiveIncome / DoubleDown = perInstance; Backstabber / Simp / HypeTrain = catalogOnce.

## Contribution echoes (golden pairs)

| Pair | Trigger | Test |
|------|---------|------|
| Salty + Steel cell floor | finalize echo | `test_salty_steel_finalize` |
| Iconic + uncommon contributor | finalize multi echo | `test_iconic_uncommon_echo` |
| Echo Chamber | two straight match-3 points | `test_double_match3_finalize_boons` |
| Ephemeral + Steel | playback interleave | `test_ephemeral_finalize_boons` |
| Mewing | topology scaling finalize | `test_mewing_topology_scaling` |

## Flavor chips (7)

| Flavor | Rule | Test |
|--------|------|------|
| Clout (positive) | score-step trigger | `test_boon_flavors` |
| Perishable | rounds remaining → destroy | `test_boon_flavors` |
| Ghost | exempt from slot capacity | `test_boon_flavors` |
| Rental | round-start money cost | `test_boon_consumable_depth` |
| Eternal | `blockSell` | `test_boon_consumable_depth` |
| Steel | cell-floor type (not a flavor) | `test_salty_steel_finalize` |

## Self-destruct & scaling

| Boon pattern | Test |
|--------------|------|
| DoubleDown 1-in-3 round end | `test_boon_consumable_depth` |
| Brainrot scaling counter proc | `test_brainrot_scaling_increment` |
| Griefing floor conversion | `test_griefing_floor` |

## Consumables

| Rule | Test |
|------|------|
| `echoLastRuneOrItemUpgradeGrantConsumableId` tracking | `test_boon_consumable_depth`, `test_shop_polish` |
| Duplicate-last-grant invoke | `test_boon_consumable_depth` |
| Inventory sell refund | `test_consumable_sell` |

## Balance planning tool

```bash
cd ultravibe && ./tools/match3_round_balance_report.sh
```

Smoke-verified in `test_boon_consumable_depth` (header `Match3 round balance`).

## Coverage gaps (post-Sprint 5)

Per-boon golden matrix for all 80 boons is not automated — use playtest script (Sprint 8) and extend echo tests as bugs are found.
