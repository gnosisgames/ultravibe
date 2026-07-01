class_name Match3EffectRebuildAccumulator
extends RefCounted

## Mutable aggregation while rebuilding runtime Match3 modifiers from active effects.

var spawn_disabled_block_ids: Dictionary = {}
var random_spawn_disabled_probability := 0.0
var tile_points_scale := 1.0
var tile_multi_scale := 1.0
var manual_shuffle_override_min := -1
var manual_shuffle_delta_sum := 0
var moves_limit_multiplier_product := 1.0
var moves_limit_delta_sum := 0
var currency_spend_per_match_by_id: Dictionary = {}
var restrict_score_to_exact_three_line_matches := false
var restrict_score_to_exact_four_or_five_line_matches := false
var shuffle_board_after_each_move := false
var reduce_first_destroyed_item_level_each_move := false
var disable_all_cell_floor_modifiers := false
