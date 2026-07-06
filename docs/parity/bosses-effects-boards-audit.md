# Bosses, effects & boards audit (Sprint 6)

Unity reference: `old_unity/ultravibe_unity/Assets/Game/Scripts/GnosisMatch3/`  
Godot: `game/match3/effects/`, `game/match3/services/match3_service.gd`, `data/Match3Effects/`, `data/Bosses/`

**Automated checks:** `tests/test_bosses_effects_boards.gd` (also `test_boss_match3_effects`, `test_disable_color_block`, `test_floor_modifier_pool`, `test_shop_polish` boss reroll)

## Match3 effects (20/20)

| Effect id | Handler | Verified property |
|-----------|---------|-------------------|
| `disable_*_block` (6 colors) | `spawn_disabled_item_type_for_blocks` | `spawn_disabled_block_ids` |
| `disable_all_cell_floor_modifiers` | `disable_all_cell_floor_modifiers` | flag true |
| `half_round_moves` | `multiply_round_moves_limit` | moves mult 0.5 |
| `halve_tile_points_multi_round` | `halve_accumulated_tile_points_and_multi_for_round` | pts/multi scale 0.5 |
| `lose_money_each_match` | `spend_currency_each_match_wave` | money spend per match |
| `party_animal_round_budget_bonus` | `add_shuffle_and_moves_budget_at_round_start` | +1 shuffle, +3 moves |
| `random_spawn_disabled_one_eighth` | `random_disabled_plain_spawn` | spawn disabled probability |
| `reduce_first_destroyed_item_level_each_move` | `reduce_first_destroyed_item_level_each_move` | gameplay + effect flags |
| `starts_with_zero_shuffles` | `override_manual_shuffles_at_round_start` | shuffle override 0 |
| `hardstuck_round_budget` | `add_shuffle_and_moves_budget_at_round_start` | +1 shuffle, −2 moves |
| `hippie_round_shuffle_bonus` | `add_shuffle_and_moves_budget_at_round_start` | +1 shuffle |
| `touch_grass_round_moves_bonus` | `add_shuffle_and_moves_budget_at_round_start` | +3 moves |
| `score_only_exact_three_match_lines` | `restrict_score_to_exact_three_line_matches` | restriction flags |
| `score_only_exact_four_or_five_match_lines` | `restrict_score_to_exact_four_or_five_line_matches` | restriction flags |
| `shuffle_board_after_each_move` | `shuffle_board_after_each_move` | post-move shuffle flag |

Each effect: `ApplyEffect` → derived state → `RemoveEffect` clears state (`test_bosses_effects_boards`).

## Boss invocations

| Boss | onRoundStart | onRoundEnd | Test |
|------|--------------|------------|------|
| Mister Beastus | `ApplyEffect lose_money_each_match` | `RemoveEffect` | `test_bosses_effects_boards` |
| Upcoming boss reroll | `RerollUpcomingBossRound` | — | `test_shop_polish` |
| Boss round skip guard | `SkipLevel` rejects | — | `test_match3_core` |

Additional boss profiles use the same `onRoundStartInvocations` / `onRoundEndInvocations` pattern in `data/Bosses/*.json`.

## Board difficulty pools

| Board tier (`data/Boards/index.json`) | Run stage pool | Example id |
|---------------------------------------|----------------|------------|
| `easy` | normal round (`_normal_board_pool_ids`) | `ball` |
| `normal` | advanced round (`_advanced_board_pool_ids`) | `ball_bm` |
| `hard` | boss round (`_boss_board_pool_ids`) | `ball_in_ball` |

Selection is deterministic per floor via `_pick_board_id_for_stage` (`test_bosses_effects_boards`).

## Floor modifier statistics

| Sync path | When | Test |
|-----------|------|------|
| `sync_floor_modifier_tile_statistics_from_pool` | Level select / pre-board | `test_bosses_effects_boards` |
| `sync_floor_modifier_tile_statistics_from_grid` | In-round grid | `test_bosses_effects_boards` |
| `get_enhanced_floor_tile_counts` | HUD enhanced column | `test_bosses_effects_boards`, `test_floor_modifier_pool` |

## Manual QA (Sprint 8)

- Playtest checklist: 8+ distinct boss rounds with theme + effect feel
- Side-by-side Unity comparison for shuffle-each-move and score-restriction bosses
