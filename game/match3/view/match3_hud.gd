class_name Match3Hud
extends Control

## Match-3 gameplay HUD. The left sidebar mirrors the Unity MainHud: boss/level
## card, stacked round total + last-match score, points x multi, round/moves/cycles/money,
## home/settings/wiki/shuffle/restart/placeholder in a 2x3 grid at the bottom of the main sidebar.
## via refresh_from_service() (driven by the dispatcher on board reset/change).

const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const Match3DispatcherScript = preload("res://game/match3/view/match3_dispatcher.gd")
const Match3EventsScript = preload("res://game/match3/match3_events.gd")
const Match3BoonJuiceScript = preload("res://game/match3/boons/match3_boon_juice.gd")
const Match3GameSpeedScript = preload("res://game/match3/core/match3_game_speed.gd")
const Match3HudScoreEscalationScript = preload("res://game/match3/view/match3_hud_score_escalation.gd")
const Match3LuckMeterScript = preload("res://game/match3/view/match3_luck_meter.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const ConsumableDbgScript = preload("res://game/match3/debug/match3_consumable_debug.gd")
const UltraGameUiNav = preload("res://game/ui/ultra_game_ui_nav.gd")
const GameInputActions = preload("res://game/input/game_input_actions.gd")
## Boss letter token font — mirrors the collection view boss tokens.
const TOKEN_FONT_PATH := "res://assets/fonts/PolygonParty-3KXM.ttf"
const HUD_PURPLE_NORMAL := Color(0.345098, 0.345098, 0.572549, 1)
const HUD_PURPLE_DARK := Color(0.180392, 0.160784, 0.321569, 1)
## Same fill as MoneyBox / SB_dark — used for the letter token on normal rounds.
const HUD_BOSS_CARD_NORMAL := Color(0.156863, 0.196078, 0.290196, 1)
const TOKEN_DEFAULT_BG := HUD_BOSS_CARD_NORMAL
const SCORE_LANE_POP_PANEL_PEAK := 1.17
const SCORE_LANE_POP_LABEL_PEAK := 1.26
const SCORE_LANE_POP_FLASH := Color(1.28, 1.28, 1.28, 1.0)
## Total score label tints — zero blends into the dark inner panel; non-zero uses
## the outer score section purple (read from the section style / theme).
const SCORE_PANEL_BG_COLOR := UltraUiPalette.PILL_DARK
const SCORE_SECTION_COLOR_FALLBACK := HUD_PURPLE_NORMAL
const BOSS_SECTION_HEIGHT := 164.0
const LEVEL_DESC_FONT_MAX := 16
const LEVEL_DESC_FONT_MIN := 10

## Group used by subscreen overlays (shop / level select / reward) to find this
## HUD and query the shared content frame.
const HUD_GROUP := "match3_hud"
const LEFT_CARD_BRIDGE_TOLERANCE := 240.0
const HUD_TOOLTIP_CANVAS_LAYER := 8
## Uniform gap between the content frame and the sidebars (and between cards).
const FRAME_GAP := 32.0
## Main sidebar action chrome (home / settings / wiki / shuffle).
const ACTION_BUTTON_SIZE := 120
const ACTION_BUTTON_GAP := 12
const ACTION_ICON_MAX := 70
const SIDEBAR_PANEL_GAP := 12
const SIDEBAR_MARGIN_H := 48.0
const LEFT_RAIL_WIDTH := 64.0
const LEFT_RAIL_ICON_SIZE := LEFT_RAIL_WIDTH
const LEFT_RAIL_GAP := 6.0
const LEFT_RAIL_MIN_SLOT := 8.0
## ConsumablesBar tscn offsets: offset_left=-212, offset_right=-32 → 180px wide.
const CONSUMABLES_BAR_WIDTH := 180.0
const CONSUMABLES_BAR_OFFSET_LEFT := -212.0
const CONSUMABLES_BAR_OFFSET_RIGHT := -32.0


static func left_rail_slot_extent_for(control: Control) -> float:
	if control == null:
		return LEFT_RAIL_ICON_SIZE
	var node: Control = control
	while node != null:
		if node.size.x >= 8.0:
			return node.size.x
		node = node.get_parent() as Control
	return LEFT_RAIL_ICON_SIZE


## Fit N square icons into a fixed rail-section height the same way consumables
## fit an arbitrary bag: shrink icons first, then allow negative gap (overlap)
## so children never demand more height than the section already has.
static func left_rail_fit_slot_size_for_extent(width: float, height: float, count: int, gap: float = LEFT_RAIL_GAP) -> float:
	return left_rail_pack_metrics(width, height, count, gap).x


## Returns Vector2(slot_size, gap). Always satisfies:
##   count*slot + (count-1)*gap <= height  (when height >= min slot)
static func left_rail_pack_metrics(width: float, budget_h: float, count: int, preferred_gap: float = LEFT_RAIL_GAP) -> Vector2:
	var w := maxf(width, LEFT_RAIL_MIN_SLOT)
	var n := maxi(count, 1)
	if n == 1 or budget_h < LEFT_RAIL_MIN_SLOT:
		return Vector2(minf(w, maxf(budget_h, LEFT_RAIL_MIN_SLOT)), preferred_gap)
	# Prefer preferred gap + shrunk icons (consumables pattern).
	var by_height := (budget_h - preferred_gap * float(n - 1)) / float(n)
	if by_height >= LEFT_RAIL_MIN_SLOT:
		return Vector2(minf(w, by_height), preferred_gap)
	# Too many for min-size + preferred gap: keep min icons, overlap as needed.
	var slot := LEFT_RAIL_MIN_SLOT
	var gap := (budget_h - slot * float(n)) / float(n - 1)
	return Vector2(slot, gap)


static func left_rail_fit_slot_size(control: Control, count: int, gap: float = LEFT_RAIL_GAP) -> float:
	var width := left_rail_slot_extent_for(control)
	var available_h := 0.0
	if control != null:
		available_h = control.size.y
		if available_h < 8.0:
			var parent := control.get_parent() as Control
			if parent != null and parent.size.y >= 8.0:
				available_h = parent.size.y
	return left_rail_pack_metrics(width, available_h, count, gap).x

## Emitted whenever the content frame rect changes (sidebar relayout / resize) so
## overlays can re-align themselves to it.
signal content_frame_changed

@onready var _level_token_panel: PanelContainer = %LevelTokenPanel
@onready var _level_token: Label = %LevelToken
@onready var _level_name: Label = %LevelName
@onready var _level_desc: Label = %LevelDesc
@onready var _req_score_value: Label = %ReqScoreValue
@onready var _total_value: Label = %TotalValue
@onready var _last_match_value: Label = %LastMatchValue
@onready var _points_value: Label = %PointsValue
@onready var _multi_value: Label = %MultiValue
@onready var _round_value: Label = %RoundValue
@onready var _moves_value: Label = %MovesValue
@onready var _gameplay_busy_spinner: GameplayBusySpinner = %GameplayBusySpinner
@onready var _cycles_value: Label = %CyclesValue
@onready var _money_value: Label = %MoneyValue
@onready var _luck_meter: Match3LuckMeterScript = %LuckMeter
@onready var _shuffle_count: Label = %ShuffleCount
@onready var _status_label: Label = %StatusLabel
@onready var _home_button: Button = %HomeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _wiki_button: Button = %WikiButton
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _restart_hold_button: Button = %RestartHoldButton
@onready var _boss_section: PanelContainer = %BossSection
@onready var _boons_bar: PanelContainer = %BoonsBar
@onready var _boons_row: Match3HudBoonsRow = %BoonsRow
@onready var _boon_count: Label = %BoonCount
@onready var _consumables_bar: PanelContainer = %ConsumablesBar
@onready var _consumables_column: Match3HudConsumablesColumn = %ConsumablesColumn
@onready var _consumable_count: Label = %ConsumableCount
@onready var _left_rail: VBoxContainer = %LeftRail
@onready var _run_upgrades_column = %RunUpgradesColumn
@onready var _enhanced_tiles_column = %EnhancedTilesColumn
@onready var _item_upgrades_column = %ItemUpgradesColumn
@onready var _score_section: PanelContainer = %ScoreSection
@onready var _stats_section: PanelContainer = %StatsSection
@onready var _buttons_section: VBoxContainer = %ButtonsSection
@onready var _buttons_grid: GridContainer = %ButtonsGrid

var _frame_dirty_pending := false
@onready var _board_host: Control = %BoardHost

var _service = null
var _planning_focus_bridge_controls: Array[Control] = []
var _last_inventory_count_signature := ""
var _last_upgrade_rail_signature := ""
var _boon_juice_subscription: RefCounted = null
var _move_metrics_active := false
var _display_step_points := 0
var _display_step_multi := 0
var _display_total_score := 0
var _display_last_match_score := 0
var _score_display_tween: Tween = null
var _score_escalation = null
var _hud_tooltip_layer: CanvasLayer = null
var _planning_overlay_active := false
## Keep final move score + fire juice visible while the reward panel is open.
var _hold_score_celebration := false
var _level_desc_fit_pending := false
var _level_desc_fit_retries := 0


func _ready() -> void:
	add_to_group(HUD_GROUP)
	_hud_tooltip_layer = CanvasLayer.new()
	_hud_tooltip_layer.name = "HudTooltipLayer"
	_hud_tooltip_layer.layer = HUD_TOOLTIP_CANVAS_LAYER
	add_child(_hud_tooltip_layer)
	var token_font = load(TOKEN_FONT_PATH)
	if token_font and _level_token:
		_level_token.add_theme_font_override("font", token_font)
	if _home_button:
		_home_button.pressed.connect(_on_home_pressed)
	if _settings_button:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _wiki_button:
		_wiki_button.pressed.connect(_on_wiki_pressed)
	if _shuffle_button:
		_shuffle_button.pressed.connect(_on_shuffle_pressed)
	set_process_input(true)
	_score_escalation = Match3HudScoreEscalationScript.new()
	_score_escalation.name = "ScoreEscalation"
	add_child(_score_escalation)
	call_deferred("_setup_score_escalation")
	call_deferred("_wire_sidebar_grid_neighbors")
	if _boss_section:
		_boss_section.custom_minimum_size = Vector2(_boss_section.custom_minimum_size.x, BOSS_SECTION_HEIGHT)
		_boss_section.resized.connect(_schedule_frame_dirty)
	if _score_section:
		_score_section.resized.connect(_schedule_frame_dirty)
	if _stats_section:
		_stats_section.resized.connect(_schedule_frame_dirty)
	if _buttons_section:
		_buttons_section.resized.connect(_schedule_frame_dirty)
	if _boons_bar:
		_boons_bar.resized.connect(_schedule_frame_dirty)
	if _consumables_bar:
		_consumables_bar.resized.connect(_schedule_frame_dirty)
	if _boons_bar:
		_boons_bar.z_index = 4
	if _consumables_bar:
		_consumables_bar.z_index = 4
	if _left_rail:
		_left_rail.z_index = 4
	resized.connect(_schedule_frame_dirty)
	set_process(true)
	_schedule_frame_dirty()


func _setup_score_escalation() -> void:
	if _score_escalation == null or not is_instance_valid(_score_escalation):
		return
	if _points_value == null or _multi_value == null:
		push_warning("[Match3Hud] score escalation setup skipped: points/multi labels missing")
		return
	var points_box := _points_value.get_parent() as Control
	var multi_box := _multi_value.get_parent() as Control
	if points_box == null or multi_box == null:
		push_warning("[Match3Hud] score escalation setup skipped: points/multi box missing")
		return
	_score_escalation.setup(points_box, multi_box)


## Re-runs sidebar + content-frame layout (e.g. after a subscreen overlay opens).
func relayout_content_frame() -> void:
	_schedule_frame_dirty()


func _schedule_frame_dirty() -> void:
	if _frame_dirty_pending:
		return
	_frame_dirty_pending = true
	call_deferred("_flush_frame_dirty")


func _flush_frame_dirty() -> void:
	_frame_dirty_pending = false
	_on_frame_dirty()


func get_hud_tooltip_layer() -> CanvasLayer:
	return _hud_tooltip_layer


## While the planning overlay (shop + level cards) is open, the boons strip sits
## under the same screen region and must not steal hover / click from it.
func set_planning_overlay_active(active: bool) -> void:
	_planning_overlay_active = active
	var filter := Control.MOUSE_FILTER_IGNORE if active else Control.MOUSE_FILTER_STOP
	if _boons_bar:
		_boons_bar.mouse_filter = filter
	if _boons_row:
		_boons_row.mouse_filter = filter
	if _consumables_bar:
		_consumables_bar.mouse_filter = filter
	if _consumables_column:
		_consumables_column.mouse_filter = filter
	if not active:
		clear_planning_focus_neighbors()


func get_sidebar_shuffle_button() -> Button:
	return _shuffle_button


func get_sidebar_restart_button() -> Button:
	return _restart_hold_button


func _input(event: InputEvent) -> void:
	if not _planning_overlay_active:
		return
	if not _is_planning_nav_right(event):
		return
	var focus_owner := get_viewport().gui_get_focus_owner() as Control
	if focus_owner == null or not _is_sidebar_action_control(focus_owner):
		return
	var bridge := _find_planning_bridge_focus_target()
	if bridge:
		bridge.grab_focus()
		get_viewport().set_input_as_handled()


func _is_planning_nav_right(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_right") \
		or event.is_action_pressed(GameInputActions.axis_positive_action("UIHorizontal"))


func _is_sidebar_action_control(control: Control) -> bool:
	for btn in get_sidebar_action_buttons():
		if control == btn:
			return true
	return false


func _find_planning_bridge_focus_target() -> Control:
	for node in get_tree().get_nodes_in_group("gnosis_ui_view"):
		if node == self or not is_instance_valid(node):
			continue
		if not node.is_visible_in_tree():
			continue
		if node.has_method("get_sidebar_bridge_focus_target"):
			var target: Variant = node.call("get_sidebar_bridge_focus_target")
			if target is Control and _is_valid_bridge_target(target as Control):
				return target as Control
	return null


func _is_valid_bridge_target(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true


func get_sidebar_action_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	if _buttons_grid == null:
		return buttons
	for child in _buttons_grid.get_children():
		if child is Button:
			var btn := child as Button
			if btn.focus_mode != Control.FOCUS_NONE and btn.is_visible_in_tree():
				buttons.append(btn)
	return buttons


## Links planning-overlay controls (level cards, shop) to the left sidebar grid so
## gamepad left/right can reach shuffle / restart / home while level select is open.
func wire_planning_focus_neighbors(planning_controls: Array[Control]) -> void:
	clear_planning_focus_neighbors()
	_wire_sidebar_grid_neighbors()
	if planning_controls.is_empty() or _shuffle_button == null:
		return
	var bridge_controls := _leftmost_card_planning_controls(planning_controls)
	if bridge_controls.is_empty():
		return
	var bridge_target := _left_edge_bridge_control(bridge_controls)
	if bridge_target:
		_link_focus_neighbor(bridge_target, "left", _shuffle_button)
		_planning_focus_bridge_controls.append(bridge_target)
		_link_focus_neighbor(_shuffle_button, "right", bridge_target)
	if _restart_hold_button and bridge_target:
		var restart_target := _nearest_planning_by_y(_restart_hold_button, bridge_controls)
		if restart_target and restart_target != bridge_target:
			_link_focus_neighbor(_restart_hold_button, "right", restart_target)


func clear_planning_focus_neighbors() -> void:
	for plan in _planning_focus_bridge_controls:
		if is_instance_valid(plan):
			plan.focus_neighbor_left = NodePath()
	_planning_focus_bridge_controls.clear()
	for btn in get_sidebar_action_buttons():
		btn.focus_neighbor_right = NodePath()
	_wire_sidebar_grid_neighbors()


func _wire_sidebar_grid_neighbors() -> void:
	if _wiki_button == null or _shuffle_button == null or _home_button == null \
			or _settings_button == null or _restart_hold_button == null:
		return
	# 3x2 grid (middle-top cell is a non-focusable placeholder):
	#   Wiki | — | Shuffle
	#   Home | Settings | Restart
	_link_focus_neighbor(_wiki_button, "right", _shuffle_button)
	_link_focus_neighbor(_wiki_button, "bottom", _home_button)
	_trap_focus_neighbor(_wiki_button, "top")
	_link_focus_neighbor(_shuffle_button, "left", _wiki_button)
	_link_focus_neighbor(_shuffle_button, "bottom", _restart_hold_button)
	_trap_focus_neighbor(_shuffle_button, "top")
	_link_focus_neighbor(_home_button, "top", _wiki_button)
	_link_focus_neighbor(_home_button, "right", _settings_button)
	_trap_focus_neighbor(_home_button, "bottom")
	_trap_focus_neighbor(_home_button, "left")
	_trap_focus_neighbor(_wiki_button, "left")
	_link_focus_neighbor(_settings_button, "left", _home_button)
	_link_focus_neighbor(_settings_button, "right", _restart_hold_button)
	_link_focus_neighbor(_settings_button, "top", _wiki_button)
	_link_focus_neighbor(_restart_hold_button, "left", _settings_button)
	_link_focus_neighbor(_restart_hold_button, "top", _shuffle_button)
	_trap_focus_neighbor(_restart_hold_button, "bottom")


func _link_focus_neighbor(from: Control, side: String, to: Control) -> void:
	if from == null or to == null or not is_instance_valid(from) or not is_instance_valid(to):
		return
	if not from.is_visible_in_tree() or not to.is_visible_in_tree():
		return
	var path := from.get_path_to(to)
	if path.is_empty() or from.get_node_or_null(path) != to:
		return
	match side:
		"left":
			from.focus_neighbor_left = path
		"right":
			from.focus_neighbor_right = path
		"top":
			from.focus_neighbor_top = path
		"bottom":
			from.focus_neighbor_bottom = path


func _trap_focus_neighbor(control: Control, side: String) -> void:
	if control == null or not is_instance_valid(control):
		return
	_link_focus_neighbor(control, side, control)


func _leftmost_card_planning_controls(planning_controls: Array[Control]) -> Array[Control]:
	var min_x := INF
	for plan in planning_controls:
		if not _is_planning_focusable(plan):
			continue
		min_x = minf(min_x, plan.get_global_rect().position.x)
	if min_x == INF:
		return []
	var bridge: Array[Control] = []
	for plan in planning_controls:
		if not _is_planning_focusable(plan):
			continue
		if plan.get_global_rect().position.x <= min_x + LEFT_CARD_BRIDGE_TOLERANCE:
			bridge.append(plan)
	return bridge


func _left_edge_bridge_control(bridge_controls: Array[Control]) -> Control:
	if bridge_controls.is_empty():
		return null
	var min_x := INF
	for plan in bridge_controls:
		if not _is_planning_focusable(plan):
			continue
		min_x = minf(min_x, plan.get_global_rect().position.x)
	if min_x == INF:
		return null
	for plan in bridge_controls:
		if plan is Button and plan.name == "LevelPlayButton" and not (plan as Button).disabled:
			if plan.get_global_rect().position.x <= min_x + 12.0:
				return plan
	for plan in bridge_controls:
		if not _is_planning_focusable(plan):
			continue
		if plan.get_global_rect().position.x <= min_x + 12.0:
			return plan
	return null


func _primary_planning_bridge_target(bridge_controls: Array[Control]) -> Control:
	return _left_edge_bridge_control(bridge_controls)


func _nearest_planning_by_y(anchor: Control, planning_controls: Array[Control]) -> Control:
	var anchor_center := anchor.get_global_rect().get_center()
	var best: Control = null
	var best_score := INF
	for plan in planning_controls:
		if not _is_planning_focusable(plan):
			continue
		var score := anchor_center.distance_squared_to(plan.get_global_rect().get_center())
		if score < best_score:
			best_score = score
			best = plan
	return best


func _is_planning_focusable(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true


func bind_service(service) -> void:
	_service = service
	_subscribe_boon_juice(service)
	_bind_inventory_bar_services(service)
	_last_inventory_count_signature = ""
	_last_upgrade_rail_signature = ""
	refresh_from_service(service)


func _bind_inventory_bar_services(service) -> void:
	if _boons_row:
		_boons_row.bind_service(service)
	if _consumables_column:
		_consumables_column.bind_service(service)
	if _run_upgrades_column:
		_run_upgrades_column.bind_service(service)
	if _enhanced_tiles_column:
		_enhanced_tiles_column.bind_service(service)
	if _item_upgrades_column:
		_item_upgrades_column.bind_service(service)


## Icon bars keep their own _service copy; refresh_from_service used to update only
## the HUD, leaving bars on a stale transient Match3 instance after restart.
func _ensure_inventory_bars_bound() -> void:
	if _service == null:
		return
	for bar in [
		_boons_row,
		_consumables_column,
		_run_upgrades_column,
		_enhanced_tiles_column,
		_item_upgrades_column,
	]:
		if bar == null:
			continue
		if bar.get("_service") != _service:
			bar.bind_service(_service)


func refresh_from_service(service = null) -> void:
	if service:
		_service = service
	_ensure_inventory_bars_bound()
	if _service != null and _service.has_method("is_consumable_use_presentation_active"):
		if _service.is_consumable_use_presentation_active():
			ConsumableDbgScript.phase("Hud.refresh_from_service", "SKIPPED (presentation active)", _service)
			return
	if ConsumableDbgScript.is_enabled():
		ConsumableDbgScript.phase("Hud.refresh_from_service", "presentation=false", _service)
	if _service == null:
		return
	var gameplay = _service.get_gameplay()
	var playing: bool = gameplay.status == Match3ModelsScript.STATUS_PLAYING
	var celebrating := _should_hold_score_celebration(gameplay.status)
	if not playing and not celebrating:
		_clear_overlay_score_display()
	if _total_value:
		var total: int = 0
		if celebrating:
			total = _display_total_score
		elif playing:
			total = _display_total_score if _move_metrics_active else gameplay.current_score
		_set_total_value_display(total)
	if _last_match_value:
		if (_move_metrics_active and playing) or celebrating:
			_update_last_match_label()
		else:
			_last_match_value.text = _format_score(0)
	if _req_score_value:
		_req_score_value.text = _format_score(gameplay.target_score)
	if _moves_value:
		_moves_value.text = str(gameplay.current_moves)
	if _round_value:
		_round_value.text = str(_service.get_current_round())
	if _points_value:
		var points: int = 0
		if celebrating or _move_metrics_active:
			points = _display_step_points
		_points_value.text = str(points)
	if _multi_value:
		var multi: int = 0
		if celebrating or _move_metrics_active:
			multi = _display_step_multi
		_multi_value.text = str(multi)
	if _cycles_value:
		_cycles_value.text = "%d/%d" % [_service.get_round_in_floor(), _service.get_rounds_per_floor()]
	if _money_value:
		_money_value.text = "$%d" % _service.get_money()
	if _luck_meter:
		_refresh_luck_meter()
	if _shuffle_count:
		_shuffle_count.text = str(_service.get_shuffles_remaining())
	_apply_level_meta(_service.get_active_level_meta())
	if _status_label:
		_status_label.text = _status_text(gameplay.status)
	_refresh_inventory_counts()
	_sync_inventory_signatures()
	_refresh_upgrade_rail()
	# Re-assert the consumable sidebar alignment once data refreshes; by now the
	# sidebar panel has a valid layout, so this recovers if the initial deferred
	# pass ran before the panel was sized.
	_on_frame_dirty.call_deferred()


## Fills the boss/level card from the active level metadata, tinting the token
## with the profile accent colors (boss rounds) like the collection tokens.
func _apply_level_meta(meta: Dictionary) -> void:
	if meta.is_empty():
		return
	if _level_name:
		_level_name.text = _localized(str(meta.get("nameKey", "")), "")
	if _level_desc:
		_level_desc.text = _localized(str(meta.get("descriptionKey", "")), "")
	var letter := str(meta.get("startingLetter", "")).strip_edges()
	if letter.is_empty():
		letter = "?"
	var bg := _parse_color(str(meta.get("backgroundColor", "")), TOKEN_DEFAULT_BG)
	var fg := _parse_color(str(meta.get("textColor", "")), Color.WHITE)
	var is_boss := bool(meta.get("isBoss", false))
	# Normal rounds: token uses the dark money fill; boss rounds keep catalog accents.
	if not is_boss:
		bg = HUD_BOSS_CARD_NORMAL
	if _level_token:
		_level_token.visible = true
		_level_token.text = letter
		_level_token.add_theme_color_override("font_color", fg)
	if _level_token_panel:
		var box := _token_panel_style(bg)
		_level_token_panel.add_theme_stylebox_override("panel", box)
	_queue_fit_level_desc_font()


func _token_panel_style(bg: Color) -> StyleBoxFlat:
	var base := _level_token_panel.get_theme_stylebox("panel") if _level_token_panel else null
	var box: StyleBoxFlat
	if base is StyleBoxFlat:
		box = (base as StyleBoxFlat).duplicate()
	else:
		box = StyleBoxFlat.new()
		box.set_corner_radius_all(21)
	box.bg_color = bg
	return box


func _queue_fit_level_desc_font() -> void:
	if _level_desc_fit_pending:
		return
	_level_desc_fit_pending = true
	_level_desc_fit_retries = 0
	call_deferred("_fit_level_desc_font")


func _fit_level_desc_font() -> void:
	_level_desc_fit_pending = false
	if _level_desc == null or not is_instance_valid(_level_desc):
		return
	var host := _level_desc.get_parent() as Control
	if host == null or host.size.y < 8.0 or host.size.x < 8.0:
		if is_inside_tree() and _level_desc_fit_retries < 8:
			_level_desc_fit_retries += 1
			_level_desc_fit_pending = true
			call_deferred("_fit_level_desc_font")
		return
	_level_desc_fit_retries = 0
	var max_h := host.size.y
	var max_w := maxf(1.0, host.size.x)
	var font: Font = _level_desc.get_theme_font("font")
	if font == null and _level_name != null:
		font = _level_name.get_theme_font("font")
	if font == null:
		# No measurable font yet — keep a safe default size and clip.
		_level_desc.add_theme_font_size_override("font_size", LEVEL_DESC_FONT_MIN)
		return
	var chosen := LEVEL_DESC_FONT_MIN
	for font_size in range(LEVEL_DESC_FONT_MAX, LEVEL_DESC_FONT_MIN - 1, -1):
		var text_size := font.get_multiline_string_size(
			_level_desc.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			max_w,
			font_size
		)
		if text_size.y <= max_h + 0.5:
			chosen = font_size
			break
	_level_desc.add_theme_font_size_override("font_size", chosen)


## Compact score formatting (300000 -> "300K") matching the Unity HUD readout.
func _format_score(value: int) -> String:
	var v := absi(value)
	var sign_str := "-" if value < 0 else ""
	if v >= 1_000_000_000:
		return sign_str + _trim_suffix(float(v) / 1_000_000_000.0) + "B"
	if v >= 1_000_000:
		return sign_str + _trim_suffix(float(v) / 1_000_000.0) + "M"
	if v >= 1_000:
		return sign_str + _trim_suffix(float(v) / 1_000.0) + "K"
	return str(value)


func _trim_suffix(value: float) -> String:
	if value >= 100.0 or is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, 1)


func _refresh_luck_meter() -> void:
	if _luck_meter == null:
		return
	if _service == null or not _service.has_method("get_lucky_find"):
		_luck_meter.set_meter_active(false)
		return
	var lucky_find = _service.get_lucky_find()
	if lucky_find == null:
		_luck_meter.set_meter_active(false)
		return
	_luck_meter.configure_from_lucky_find(lucky_find)


func _status_text(status: int) -> String:
	match status:
		Match3ModelsScript.STATUS_WIN:
			return _localized("core__noun__victory", "You win!")
		Match3ModelsScript.STATUS_LOSS:
			return _localized("core__phrase__outOfMoves", "Out of moves")
		_:
			return ""


func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty():
		return fallback
	if _service == null or _service.context == null or _service.context.engine == null:
		return fallback
	var loc = _service.context.engine.get_service("Localization")
	if loc == null:
		return fallback
	return loc.get_string_value(key, fallback)


func _parse_color(value: String, fallback: Color) -> Color:
	var raw := value.strip_edges()
	if raw.is_empty() or not raw.begins_with("#") or not Color.html_is_valid(raw):
		return fallback
	return Color.html(raw)


func _game_ui():
	if _service == null or _service.context == null or _service.context.engine == null:
		return null
	return _service.context.engine.get_service("GameUI")


func _on_home_pressed() -> void:
	var ui = _game_ui()
	if ui == null or _service == null or _service.context == null:
		return
	UltraGameUiNav.return_to_title(ui, _service.context.engine)


func _on_settings_pressed() -> void:
	var ui = _game_ui()
	if ui == null or _service == null or _service.context == null:
		return
	UltraGameUiNav.push_from_gameplay(ui, _service.context.engine.store, "settings", "slide_left")


func _on_wiki_pressed() -> void:
	var ui = _game_ui()
	if ui == null or _service == null or _service.context == null:
		return
	UltraGameUiNav.push_from_gameplay(ui, _service.context.engine.store, "collection", "slide_right")


func _on_shuffle_pressed() -> void:
	if _service and _service.has_method("invoke_function"):
		_service.invoke_function("TryUseShuffle", null)


func _process(delta: float) -> void:
	_refresh_gameplay_busy_spinner()
	_refresh_upgrade_rail_if_changed()
	_refresh_inventory_counts_if_changed()


## True while cascades, score juice, or consumable presentation block board input (Unity inputLocked parity).
func is_gameplay_input_locked() -> bool:
	if _service == null or not _service.has_method("get_gameplay"):
		return false
	var gameplay = _service.get_gameplay()
	if gameplay == null or gameplay.status != Match3ModelsScript.STATUS_PLAYING:
		return false
	if _service.has_method("is_consumable_use_presentation_active") \
			and _service.is_consumable_use_presentation_active():
		return true
	var dispatcher := get_tree().get_first_node_in_group(Match3DispatcherScript.GROUP)
	if dispatcher != null and dispatcher.has_method("is_busy") and dispatcher.is_busy():
		return true
	return false


func _refresh_gameplay_busy_spinner() -> void:
	if _gameplay_busy_spinner == null:
		return
	_gameplay_busy_spinner.set_spinning(is_gameplay_input_locked())


func _refresh_upgrade_rail_if_changed() -> void:
	if _service == null:
		return
	if _service.has_method("is_consumable_use_presentation_active") \
			and _service.is_consumable_use_presentation_active():
		return
	var eph := _ephemeral()
	if not eph.is_valid():
		return
	var signature := _upgrade_rail_signature(eph)
	if signature == _last_upgrade_rail_signature:
		return
	_last_upgrade_rail_signature = signature
	_refresh_upgrade_rail()


func _refresh_inventory_counts_if_changed() -> void:
	if _service and _service.has_method("is_consumable_use_presentation_active"):
		if _service.is_consumable_use_presentation_active():
			return
	var signature := _inventory_count_signature()
	if signature == _last_inventory_count_signature:
		return
	_last_inventory_count_signature = signature
	_refresh_inventory_counts()


func _sync_inventory_signatures() -> void:
	if _service == null:
		_last_inventory_count_signature = ""
		_last_upgrade_rail_signature = ""
		return
	var eph := _ephemeral()
	if not eph.is_valid():
		_last_inventory_count_signature = ""
		_last_upgrade_rail_signature = ""
		return
	_last_inventory_count_signature = _inventory_count_signature()
	_last_upgrade_rail_signature = _upgrade_rail_signature(eph)


func _refresh_upgrade_rail() -> void:
	if _run_upgrades_column:
		_run_upgrades_column.force_refresh()
	if _item_upgrades_column:
		_item_upgrades_column.force_refresh()
	if _enhanced_tiles_column and _enhanced_tiles_column.has_method("force_refresh"):
		_enhanced_tiles_column.force_refresh()
	# force_refresh rebuilds slot mins; without re-equalize the thirds inflate and
	# faces spill (planning overlay keeps looking fine because it frame-dirties).
	_layout_left_rail()


func _refresh_inventory_counts() -> void:
	if _service == null:
		return
	var eph := _ephemeral()
	if not eph.is_valid():
		return
	if _boon_count:
		_boon_count.text = _format_bag_count(eph.get_node("boons").get_node("default"))
	if _consumable_count:
		_consumable_count.text = _format_bag_count(eph.get_node("consumables").get_node("default"))


func _inventory_count_signature() -> String:
	if _service == null:
		return ""
	var eph := _ephemeral()
	if not eph.is_valid():
		return ""
	return "%s|%s|%s" % [
		_bag_count_signature(eph.get_node("boons").get_node("default")),
		_bag_count_signature(eph.get_node("consumables").get_node("default")),
		_upgrade_rail_signature(eph),
	]


func _upgrade_rail_signature(eph: GnosisNode) -> String:
	var upgrades := eph.get_node("upgrades")
	if not upgrades.is_valid():
		return ""
	var run_sig := _upgrade_list_signature(upgrades.get_node("run").get_node("list"))
	var item_sig := _upgrade_list_signature(upgrades.get_node("itemUpgrades").get_node("list"))
	var pool_sig := ""
	var m3 := eph.get_node("match3")
	if m3.is_valid():
		var pool := m3.get_node("floorModifierPool")
		if pool.is_valid() and pool.get_type() == GnosisValueType.OBJECT:
			var parts: PackedStringArray = []
			for key in pool.get_keys():
				var id := str(key).strip_edges()
				if id.is_empty():
					continue
				parts.append("%s=%s" % [id, str(pool.get_node(id).value)])
			pool_sig = ",".join(parts)
	return "%s|%s|%s" % [run_sig, item_sig, pool_sig]


func _upgrade_list_signature(list: GnosisNode) -> String:
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return ""
	var parts: PackedStringArray = []
	for i in list.get_count():
		var entry := list.get_node(i)
		if not entry.is_valid():
			continue
		var id := ""
		for key in ["upgradeId", "id"]:
			var node := entry.get_node(key)
			if node.is_valid() and node.value != null:
				id = str(node.value).strip_edges()
				if not id.is_empty():
					break
		parts.append("%s:%d" % [id, _entry_int(entry, "currentCount", 1)])
	return "|".join(parts)


func _entry_int(entry: GnosisNode, key: String, default_value: int) -> int:
	if not entry.is_valid():
		return default_value
	var child := entry.get_node(key)
	if child.is_valid() and child.value != null:
		return int(child.value)
	return default_value


func _bag_count_signature(bag: GnosisNode) -> String:
	if not bag.is_valid():
		return "0/0"
	var list := bag.get_node("list")
	var list_count := list.get_count() if list.is_valid() and list.get_type() == GnosisValueType.LIST else 0
	var filled := _bag_int(bag, "filledSlotsCount", -1)
	if filled < 0 or filled != list_count:
		filled = list_count
	var max_size := _bag_int(bag, "maxSize", -1)
	if max_size < 0:
		max_size = maxi(filled, _bag_int(bag, "listCount", filled))
	return "%d/%d" % [filled, max_size]


func _format_bag_count(bag: GnosisNode) -> String:
	if not bag.is_valid():
		return "0 / 0"
	var sig := _bag_count_signature(bag)
	var parts := sig.split("/")
	if parts.size() != 2:
		return "0 / 0"
	return "%s / %s" % [parts[0], parts[1]]


func _bag_int(bag: GnosisNode, key: String, default_value: int) -> int:
	if not bag.is_valid():
		return default_value
	var child := bag.get_node(key)
	if child.is_valid() and child.value != null:
		return int(child.value)
	return default_value


func _ephemeral() -> GnosisNode:
	if _service == null or _service.context == null or _service.context.state == null:
		return GnosisNode.new(null)
	return _service.context.state.root.get_node("Ephemeral")


func get_sidebar_width() -> float:
	return SIDEBAR_MARGIN_H + ACTION_BUTTON_SIZE * 3.0 + ACTION_BUTTON_GAP * 2.0


func get_sidebar_offset_left() -> float:
	return FRAME_GAP + LEFT_RAIL_WIDTH


func get_sidebar_offset_right() -> float:
	return get_sidebar_offset_left() + get_sidebar_width()


## Combined global rect of the score + stats sidebar panels (excludes boss card).
func _get_sidebar_metrics_rect() -> Rect2:
	if _score_section == null:
		return Rect2()
	var top_rect := _score_section.get_global_rect()
	if _stats_section == null:
		return top_rect
	var bottom_rect := _stats_section.get_global_rect()
	if bottom_rect.size.y <= 0.0:
		return top_rect
	return Rect2(
		top_rect.position.x,
		top_rect.position.y,
		top_rect.size.x,
		bottom_rect.end.y - top_rect.position.y,
	)


func _global_rect_to_local(global_rect: Rect2) -> Rect2:
	if global_rect.size == Vector2.ZERO:
		return Rect2()
	var to_local := get_global_transform().affine_inverse()
	var pos: Vector2 = to_local * global_rect.position
	var end: Vector2 = to_local * global_rect.end
	return Rect2(pos, end - pos)


func _global_y_to_local(global_y: float) -> float:
	return (_global_point_to_local(Vector2(0.0, global_y))).y


func _global_point_to_local(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


## Positions the consumable sidebar to match the planning frame height (shop + cards).
func _layout_consumables_bar() -> void:
	if _consumables_bar == null or _score_section == null:
		return
	var planning := _get_planning_frame_local_rect()
	if planning.size.y <= 0.0:
		return
	var bar_local := Rect2(
		size.x - FRAME_GAP - CONSUMABLES_BAR_WIDTH,
		planning.position.y,
		CONSUMABLES_BAR_WIDTH,
		planning.size.y,
	)
	_consumables_bar.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_consumables_bar.anchor_right = 0.0
	_consumables_bar.anchor_bottom = 0.0
	if _consumables_column:
		_consumables_column.custom_minimum_size = Vector2.ZERO
	var layout := _consumables_column.get_parent() as Control if _consumables_column else null
	if layout:
		layout.custom_minimum_size = Vector2.ZERO
	if not _consumables_bar.position.is_equal_approx(bar_local.position):
		_consumables_bar.position = bar_local.position
	if not _consumables_bar.size.is_equal_approx(bar_local.size):
		_consumables_bar.size = bar_local.size


func _layout_boons_bar() -> void:
	if _boons_bar == null or _boss_section == null:
		return
	var frame := _get_content_frame_local_rect()
	var boss := _global_rect_to_local(_boss_section.get_global_rect())
	if frame.size.x <= 0.0 or boss.size.y <= 0.0:
		return
	var chrome := _boons_bar.get_node_or_null("BoonsChrome") as Control
	if chrome:
		chrome.custom_minimum_size = Vector2.ZERO
	_boons_bar.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_boons_bar.anchor_right = 0.0
	_boons_bar.anchor_bottom = 0.0
	var bar_pos := Vector2(frame.position.x, boss.position.y)
	var bar_size := Vector2(frame.size.x, boss.size.y)
	if not _boons_bar.position.is_equal_approx(bar_pos):
		_boons_bar.position = bar_pos
	if not _boons_bar.size.is_equal_approx(bar_size):
		_boons_bar.size = bar_size


func _get_content_frame_local_rect() -> Rect2:
	var panel := _global_rect_to_local(_get_sidebar_metrics_rect())
	if panel.size == Vector2.ZERO:
		return Rect2()
	var left := panel.position.x + panel.size.x + FRAME_GAP
	var top := panel.position.y
	var bottom := panel.end.y
	var right := size.x - FRAME_GAP - CONSUMABLES_BAR_WIDTH - FRAME_GAP
	return Rect2(left, top, maxf(0.0, right - left), maxf(0.0, bottom - top))


func _get_planning_frame_local_rect() -> Rect2:
	var frame := _get_content_frame_local_rect()
	if frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return frame
	return Rect2(
		frame.position.x,
		frame.position.y,
		frame.size.x,
		maxf(0.0, size.y - FRAME_GAP - frame.position.y),
	)


## Global rect of the shared subscreen content frame: spans the gap between the
## main sidebar panel and the consumable sidebar, with the height of the main
## sidebar panel. All subscreens (level select / reward) fill this.
func get_content_frame_rect() -> Rect2:
	var panel := _get_sidebar_metrics_rect()
	if panel.size == Vector2.ZERO:
		return Rect2()
	var left := panel.position.x + panel.size.x + FRAME_GAP
	var top := panel.position.y
	var bottom := panel.end.y
	var right := get_global_rect().end.x - FRAME_GAP - CONSUMABLES_BAR_WIDTH - FRAME_GAP
	return Rect2(left, top, maxf(0.0, right - left), maxf(0.0, bottom - top))


## Level-select / shop planning region: same top and width as the main sidebar
## stats panel, but extends to the bottom of the HUD so the shop can use the
## vertical strip above the sidebar button row.
func get_planning_frame_rect() -> Rect2:
	var frame := get_content_frame_rect()
	if frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return frame
	var bottom_global := get_global_rect().end.y - FRAME_GAP
	return Rect2(
		frame.position.x,
		frame.position.y,
		frame.size.x,
		maxf(0.0, bottom_global - frame.position.y),
	)


## Play-field rect for the match-3 board: same horizontal bounds as
## get_content_frame_rect() but extends to the bottom of the HUD.
func get_board_frame_rect() -> Rect2:
	var frame := get_content_frame_rect()
	if frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return frame
	var bottom_global := get_global_rect().end.y - FRAME_GAP
	return Rect2(
		frame.position.x,
		frame.position.y,
		frame.size.x,
		maxf(0.0, bottom_global - frame.position.y),
	)


## Keeps the boons strip and consumable sidebar aligned with the main sidebar
## panels, then notifies overlays the frame may have moved.
func _on_frame_dirty() -> void:
	_layout_left_rail()
	_layout_sidebar_width()
	_layout_action_buttons()
	if _consumables_bar and _score_section:
		_layout_consumables_bar()
	if _boss_section and _boons_bar:
		_layout_boons_bar()
	# Keep the board area on the exact same rect the subscreen overlays use, so
	# the board fills the level-select / reward region.
	if _board_host:
		var frame := get_board_frame_rect()
		if frame.size.x > 0.0 and frame.size.y > 0.0:
			_board_host.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_board_host.position = frame.position
			_board_host.size = frame.size
	_ensure_inventory_bar_insets()
	call_deferred("_sync_inventory_icon_bars")
	content_frame_changed.emit()


## PanelContainer children (BoonsChrome, ConsumablesColumn) collapse to 0x0 when the
## bar uses manual position/size from _on_frame_dirty — counts still paint via sibling
## labels, but icon TextureRects get zero layout and do not render in-game.
func _panel_content_size(panel: PanelContainer) -> Vector2:
	if panel == null:
		return Vector2.ZERO
	var style := panel.get_theme_stylebox(&"panel") as StyleBox
	var width := panel.size.x
	var height := panel.size.y
	if style:
		width -= style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
		height -= style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	return Vector2(maxf(0.0, width), maxf(0.0, height))


func _boons_bar_panel_vertical_inset() -> float:
	if _boons_bar == null:
		return 0.0
	var style := _boons_bar.get_theme_stylebox(&"panel") as StyleBox
	if style == null:
		return 0.0
	return style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)


func _boons_bar_panel_horizontal_inset() -> float:
	if _boons_bar == null:
		return 0.0
	var style := _boons_bar.get_theme_stylebox(&"panel") as StyleBox
	if style == null:
		return 0.0
	return style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)


func _ensure_inventory_bar_insets() -> void:
	if _boons_bar and _boss_section and _boons_bar.size.x >= 8.0:
		var chrome := _boons_bar.get_node_or_null("BoonsChrome") as Control
		if chrome:
			var frame := _get_content_frame_local_rect()
			var strip_h := maxf(8.0, _boss_section.size.y)
			var content_w := frame.size.x if frame.size.x > 8.0 else _panel_content_size(_boons_bar).x
			var content := Vector2(
				maxf(8.0, content_w - _boons_bar_panel_horizontal_inset()),
				maxf(8.0, strip_h - _boons_bar_panel_vertical_inset()),
			)
			if content.x >= 8.0 and content.y >= 8.0:
				chrome.custom_minimum_size = content
				chrome.size = content


## After manual bar/rail layout, rebuild or relayout icon slots so TextureRects
## get non-zero rects (c14d7af dropped boons force_refresh; consumables reorder
## can orphan slots under layout hosts until finalized).
func _sync_inventory_icon_bars() -> void:
	_ensure_inventory_bar_insets()
	_fit_rail_section_column(_run_upgrades_column)
	_fit_rail_section_column(_enhanced_tiles_column)
	_fit_rail_section_column(_item_upgrades_column)
	if _run_upgrades_column and _run_upgrades_column.has_method("_relayout_slot_sizes"):
		_run_upgrades_column._relayout_slot_sizes()
	if _item_upgrades_column and _item_upgrades_column.has_method("_relayout_slot_sizes"):
		_item_upgrades_column._relayout_slot_sizes()
	if _enhanced_tiles_column and _enhanced_tiles_column.has_method("_relayout_row_sizes"):
		_enhanced_tiles_column._relayout_row_sizes()
	var chrome := _boons_bar.get_node_or_null("BoonsChrome") as Control if _boons_bar else null
	if _boons_row and chrome and chrome.size.x >= 8.0 and chrome.size.y >= 8.0:
		# Layout-only — never force_refresh here (resized ↔ rebuild freeze loop).
		if _boons_row.has_method("_relayout_slot_sizes"):
			_boons_row._relayout_slot_sizes()
		elif _boons_row.has_method("_on_slot_layout_dirty"):
			_boons_row._on_slot_layout_dirty()
	if _consumables_column and _consumables_column.size.x >= 8.0 and _consumables_column.size.y >= 8.0:
		if _consumables_column.has_method("sync_after_hud_layout"):
			_consumables_column.sync_after_hud_layout()
		elif _consumables_column.has_method("_on_slot_layout_dirty"):
			_consumables_column._on_slot_layout_dirty()


func _layout_sidebar_width() -> void:
	var sidebar := get_node_or_null("Sidebar") as Control
	if sidebar:
		sidebar.offset_left = get_sidebar_offset_left()
		sidebar.offset_right = get_sidebar_offset_right()


func _layout_action_buttons() -> void:
	if _buttons_grid == null:
		return
	# 1) Size action buttons as true squares from the sidebar cell width.
	# 2) Score + stats share leftover height equally (centered content = even
	#    top/bottom padding inside each panel). No empty flex gap above buttons.
	var cols := maxi(_buttons_grid.columns, 1)
	var rows := ceili(float(_buttons_grid.get_child_count()) / float(cols))
	var h_sep := _buttons_grid.get_theme_constant("h_separation")
	var v_sep := _buttons_grid.get_theme_constant("v_separation")
	var grid_width := _buttons_grid.size.x
	if grid_width <= 8.0 and _buttons_section != null:
		grid_width = _buttons_section.size.x
	if grid_width <= 8.0:
		grid_width = get_sidebar_width() - SIDEBAR_MARGIN_H
	var side := float(ACTION_BUTTON_SIZE)
	if grid_width > 8.0:
		side = floorf((grid_width - h_sep * float(cols - 1)) / float(cols))
	var grid_height := _estimate_buttons_area_height()
	if grid_height > 8.0:
		var height_fit := floorf((grid_height - v_sep * float(rows - 1)) / float(rows))
		side = minf(side, height_fit)
	side = clampf(side, 40.0, float(ACTION_BUTTON_SIZE))
	var grid_min_h := side * float(rows) + v_sep * float(rows - 1)
	_buttons_grid.custom_minimum_size = Vector2(0.0, grid_min_h)
	if _buttons_section != null:
		_buttons_section.size_flags_vertical = Control.SIZE_SHRINK_END
		_buttons_section.custom_minimum_size = Vector2(0.0, grid_min_h)
	if _score_section:
		_score_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_score_section.size_flags_stretch_ratio = 1.0
	if _stats_section:
		_stats_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_stats_section.size_flags_stretch_ratio = 1.0
	var score_layout := _score_section.get_node_or_null("ScoreLayout") as VBoxContainer if _score_section else null
	if score_layout:
		score_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	var stats_layout := _stats_section.get_node_or_null("StatsLayout") as VBoxContainer if _stats_section else null
	if stats_layout:
		stats_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	var layout := get_node_or_null("Sidebar/Layout") as VBoxContainer
	if layout:
		layout.add_theme_constant_override("separation", SIDEBAR_PANEL_GAP)
		var spacer := layout.get_node_or_null("SidebarFlexSpacer") as Control
		if spacer:
			# Legacy spacer from earlier layout — reclaim that dead gap.
			spacer.visible = false
			spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			spacer.custom_minimum_size = Vector2.ZERO
	for child in _buttons_grid.get_children():
		if child is Control:
			var ctrl := child as Control
			var target_min := Vector2(side, side)
			if not ctrl.custom_minimum_size.is_equal_approx(target_min):
				ctrl.custom_minimum_size = target_min
			ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if ctrl is Button:
				var icon_max := int(minf(ACTION_ICON_MAX, side * 0.58))
				ctrl.add_theme_constant_override("icon_max_width", icon_max)
	call_deferred("_wire_sidebar_grid_neighbors")


func _estimate_buttons_area_height() -> float:
	var layout := get_node_or_null("Sidebar/Layout") as Control
	var sidebar := get_node_or_null("Sidebar") as Control
	if layout == null or sidebar == null:
		return 0.0
	var budget := sidebar.size.y
	if budget <= 0.0:
		budget = size.y
	budget -= sidebar.get_theme_constant("margin_top")
	budget -= sidebar.get_theme_constant("margin_bottom")
	if budget <= 0.0:
		return 0.0
	for section_name in ["BossSection", "ScoreSection", "StatsSection"]:
		var section := layout.get_node_or_null(section_name) as Control
		if section == null or not section.visible:
			continue
		var section_h := section.get_combined_minimum_size().y
		if section_h <= 0.0:
			section_h = section.size.y
		budget -= section_h
	if layout is VBoxContainer:
		var visible_children := 0
		for child in layout.get_children():
			if child is Control and (child as Control).visible:
				visible_children += 1
		if visible_children > 1:
			budget -= float(visible_children - 1) * float((layout as VBoxContainer).get_theme_constant("separation"))
	return maxf(0.0, budget)


func _layout_left_rail() -> void:
	if _left_rail == null:
		return
	# Drop any spacer left over from the short-lived content-sized rail experiment.
	var stale_spacer := _left_rail.get_node_or_null("RailSpacer")
	if stale_spacer:
		stale_spacer.queue_free()
	_left_rail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_left_rail.position = Vector2(FRAME_GAP, FRAME_GAP)
	var rail_h := maxf(0.0, size.y - FRAME_GAP * 2.0)
	# Lock height — PanelContainer children must not stretch the rail past the HUD.
	_left_rail.clip_contents = true
	_left_rail.custom_minimum_size = Vector2(LEFT_RAIL_WIDTH, rail_h)
	_left_rail.size = Vector2(LEFT_RAIL_WIDTH, rail_h)
	_equalize_left_rail_sections(rail_h)
	_fit_rail_section_column(_run_upgrades_column)
	_fit_rail_section_column(_enhanced_tiles_column)
	_fit_rail_section_column(_item_upgrades_column)
	if _run_upgrades_column and _run_upgrades_column.has_method("_relayout_slot_sizes"):
		_run_upgrades_column._relayout_slot_sizes()
	if _enhanced_tiles_column and _enhanced_tiles_column.has_method("_relayout_row_sizes"):
		_enhanced_tiles_column._relayout_row_sizes()
	if _item_upgrades_column and _item_upgrades_column.has_method("_relayout_slot_sizes"):
		_item_upgrades_column._relayout_slot_sizes()
	# Re-assert after fits — content mins can fight VBox for one layout pass.
	_left_rail.custom_minimum_size = Vector2(LEFT_RAIL_WIDTH, rail_h)
	_left_rail.size = Vector2(LEFT_RAIL_WIDTH, rail_h)


func _equalize_left_rail_sections(rail_h: float) -> void:
	if _left_rail == null:
		return
	var sections: Array[Control] = []
	for child in _left_rail.get_children():
		if child is Control and not str(child.name).begins_with("RailSpacer"):
			sections.append(child as Control)
	var n := sections.size()
	if n <= 0:
		return
	var sep := float(_left_rail.get_theme_constant(&"separation"))
	var section_h := maxf(8.0, (rail_h - sep * float(n - 1)) / float(n))
	for section in sections:
		section.visible = true
		section.clip_contents = true
		# Equal thirds of the locked rail. SHRINK_BEGIN collapsed empty panels and
		# crammed item icons into a content-sized capsule — use EXPAND_FILL + fixed min.
		section.size_flags_vertical = Control.SIZE_EXPAND_FILL
		section.size_flags_stretch_ratio = 1.0
		section.custom_minimum_size = Vector2(LEFT_RAIL_WIDTH, section_h)
		section.size = Vector2(LEFT_RAIL_WIDTH, section_h)
		section.set_meta(&"left_rail_equal_h", section_h)


func _fit_rail_section_column(column: Control) -> void:
	if column == null:
		return
	var section := column.get_parent() as Control
	if section == null:
		return
	section.visible = true
	section.clip_contents = true
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.size_flags_stretch_ratio = 1.0
	var section_h := section.size.y
	if section.has_meta(&"left_rail_equal_h"):
		section_h = float(section.get_meta(&"left_rail_equal_h"))
		section.custom_minimum_size = Vector2(LEFT_RAIL_WIDTH, section_h)
		section.size = Vector2(LEFT_RAIL_WIDTH, section_h)
	var style := section.get_theme_stylebox(&"panel") as StyleBox
	var inset := 0.0
	if style:
		inset = style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	var content := Vector2(LEFT_RAIL_WIDTH, maxf(8.0, section_h - inset))
	column.visible = true
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size = Vector2(LEFT_RAIL_WIDTH, 0.0)
	column.size = content
	column.clip_contents = true
	column.set_meta(&"left_rail_budget_h", content.y)
	var count := 0
	if column.has_method("_entries"):
		count = int(column.call("_entries").size())
	elif column.has_method("_enhanced_pool_rows"):
		count = int(column.call("_enhanced_pool_rows").size())
	var pack := left_rail_pack_metrics(content.x, content.y, maxi(count, 1), LEFT_RAIL_GAP)
	if column.has_method("apply_left_rail_pack"):
		column.apply_left_rail_pack(pack.x, pack.y)
	if column.has_method("_relayout_slot_sizes"):
		column.call("_relayout_slot_sizes")
	elif column.has_method("_relayout_row_sizes"):
		column.call("_relayout_row_sizes")


func _subscribe_boon_juice(service) -> void:
	if _boon_juice_subscription != null and _boon_juice_subscription.has_method("dispose"):
		_boon_juice_subscription.dispose()
	_boon_juice_subscription = null
	if service == null or service.context == null or service.context.event_bus == null:
		return
	_boon_juice_subscription = service.context.event_bus.subscribe(
		Match3EventsScript.FACT_MATCH3_BOON_SCALING_JUICE,
		_on_boon_scaling_juice,
		0
	)
	service.context.event_bus.subscribe(
		Match3EventsScript.FACT_MATCH3_BOON_SCORE_JUICE,
		_on_boon_score_juice,
		0
	)


func _on_boon_scaling_juice(event: GnosisEvent) -> void:
	if _boons_row == null or _service == null or event == null or not event.data.is_valid():
		return
	var slot_index := int(event.data.get_node("slotIndex").value if event.data.get_node("slotIndex").is_valid() else -1)
	if slot_index < 0:
		return
	var counter_key := str(event.data.get_node("counterKey").value if event.data.get_node("counterKey").is_valid() else "")
	var rows := SupportScript.get_active_boon_inventory_slot_rows(_service)
	if slot_index >= rows.size():
		return
	var kind: String = Match3BoonJuiceScript.resolve_score_kind_for_scaling(rows[slot_index], counter_key)
	_boons_row.play_scaling_up_juice(slot_index, kind)


func _on_boon_score_juice(event: GnosisEvent) -> void:
	if _boons_row == null or event == null or not event.data.is_valid():
		return
	var slot_index := int(event.data.get_node("slotIndex").value if event.data.get_node("slotIndex").is_valid() else -1)
	if slot_index < 0:
		return
	var kind := str(event.data.get_node("scoreKind").value if event.data.get_node("scoreKind").is_valid() else Match3BoonJuiceScript.KIND_POINTS)
	var display := str(event.data.get_node("displayText").value if event.data.get_node("displayText").is_valid() else "")
	_boons_row.play_score_juice(slot_index, kind, display)


func play_boon_score_juice_on_slot(slot_index: int, score_kind: String, display_text: String) -> void:
	if _boons_row == null:
		return
	_boons_row.play_score_juice(slot_index, score_kind, display_text)


func play_enhanced_tile_trigger_juice(type_id: String) -> void:
	if _enhanced_tiles_column and _enhanced_tiles_column.has_method("play_trigger_juice"):
		_enhanced_tiles_column.play_trigger_juice(type_id)


func begin_move_score_display(pre_move_total: int) -> void:
	_hold_score_celebration = false
	_kill_score_display_tweens()
	_move_metrics_active = true
	_display_step_points = 0
	_display_step_multi = 0
	_display_last_match_score = 0
	_display_total_score = pre_move_total
	if _score_escalation and _service:
		var gameplay = _service.get_gameplay()
		var target: int = gameplay.target_score if gameplay else 0
		_score_escalation.reset_move_ramp(pre_move_total, target)
	_apply_score_display_texts()


func apply_step_metrics_display(target_points: int, target_multi: int) -> void:
	if not _move_metrics_active:
		return
	var prev_points := _display_step_points
	var prev_multi := _display_step_multi
	_display_step_points = target_points
	_display_step_multi = maxi(1, target_multi)
	_apply_score_display_texts()
	_update_score_escalation_visual()
	if target_points != prev_points or target_multi != prev_multi:
		_pulse_score_lane_juice()


func _update_score_escalation_visual() -> void:
	if _score_escalation == null or _service == null:
		return
	var gameplay = _service.get_gameplay()
	if gameplay == null:
		return
	_score_escalation.update_from_step(
		_display_total_score,
		_display_step_points,
		_display_step_multi,
		gameplay.target_score,
	)


func finish_move_score_display(final_total: int) -> void:
	if _hold_score_celebration:
		_display_total_score = final_total
		_apply_score_display_texts()
		return
	_kill_score_display_tweens()
	_reset_last_match_label_transform()
	_display_step_points = 0
	_display_step_multi = 0
	_display_last_match_score = 0
	_display_total_score = final_total
	_move_metrics_active = false
	if _score_escalation:
		_score_escalation.hide_effects()
	_apply_score_display_texts()


## Keep the winning move's points/multi/total + fire juice while reward is open.
func hold_winning_score_celebration(final_total: int, move_gain: int = -1) -> void:
	_hold_score_celebration = true
	_kill_score_display_tweens()
	_reset_last_match_label_transform()
	_display_total_score = maxi(0, final_total)
	if move_gain > 0:
		_display_last_match_score = move_gain
	_move_metrics_active = true
	_apply_score_display_texts()
	_update_score_escalation_visual()


func clear_score_celebration() -> void:
	if not _hold_score_celebration and not _move_metrics_active:
		return
	_hold_score_celebration = false
	_clear_overlay_score_display()
	_apply_score_display_texts()


func _should_hold_score_celebration(status: int) -> bool:
	if not _hold_score_celebration:
		return false
	return status == Match3ModelsScript.STATUS_WIN \
		or status == Match3ModelsScript.STATUS_REWARD_PANEL \
		or status == Match3ModelsScript.STATUS_LOSE_PANEL


## Clears banked-score presentation when leaving gameplay (reward / shop / level select).
func _clear_overlay_score_display() -> void:
	_hold_score_celebration = false
	_kill_score_display_tweens()
	_reset_last_match_label_transform()
	_move_metrics_active = false
	_display_step_points = 0
	_display_step_multi = 0
	_display_last_match_score = 0
	_display_total_score = 0
	if _score_escalation:
		_score_escalation.hide_effects()


func cancel_move_score_display(final_total: int = -1) -> void:
	if _hold_score_celebration:
		return
	_kill_score_display_tweens()
	if final_total >= 0:
		finish_move_score_display(final_total)
	else:
		_move_metrics_active = false


func play_step_metrics_display(target_points: int, target_multi: int, duration_sec: float) -> void:
	if not _move_metrics_active:
		return
	var prev_points := _display_step_points
	var prev_multi := _display_step_multi
	_display_step_points = target_points
	_display_step_multi = maxi(1, target_multi)
	if _points_value:
		_points_value.text = str(_display_step_points)
	if _multi_value:
		_multi_value.text = str(_display_step_multi)
	if target_points != prev_points or target_multi != prev_multi:
		_pulse_score_lane_juice()
	_update_score_escalation_visual()
	if duration_sec > 0.0 and is_inside_tree():
		var tree := get_tree()
		if tree != null:
			await tree.create_timer(duration_sec, true, false, true).timeout


func play_score_transfer_to_total(
	target_total: int,
	move_gain: int,
	delay_sec: float,
	duration_sec: float,
) -> void:
	if not _move_metrics_active:
		return
	if move_gain > 0 and _display_last_match_score != move_gain:
		await _tween_last_match_score(
			_display_last_match_score,
			move_gain,
			_scale_presentation_seconds(0.14, 0.04),
		)
	if delay_sec > 0.0 and is_inside_tree():
		var tree := get_tree()
		if tree != null:
			await tree.create_timer(delay_sec, true, false, true).timeout
	_display_step_points = 0
	_display_step_multi = 0
	if _points_value:
		_points_value.text = "0"
	if _multi_value:
		_multi_value.text = "0"
	_pulse_score_lane_juice()
	var start_total := _display_total_score
	var last_start := _display_last_match_score
	if move_gain > 0 and duration_sec > 0.0:
		if _score_escalation:
			_score_escalation.fade_toward_off(0.0)
		await _play_score_bank_transfer(start_total, target_total, last_start, duration_sec)
		if _score_escalation:
			_score_escalation.fade_toward_off(1.0)
	else:
		_display_total_score = target_total
		_set_total_value_display(_display_total_score)
		_display_last_match_score = 0
		_update_last_match_label()
	finish_move_score_display(target_total)


func _scale_presentation_seconds(seconds: float, min_seconds: float = 0.0) -> float:
	if _service == null or _service.context == null or _service.context.engine == null:
		return maxf(min_seconds, seconds)
	return Match3GameSpeedScript.scale_duration(_service.context.engine, seconds, min_seconds)


func _play_score_bank_transfer(
	start_total: int,
	target_total: int,
	last_start: int,
	duration_sec: float,
) -> void:
	_kill_score_display_tweens()
	await _pop_last_match_centered()
	if not is_inside_tree() or duration_sec <= 0.0:
		_display_total_score = target_total
		_display_last_match_score = 0
		_set_total_value_display(_display_total_score)
		_update_last_match_label()
		_reset_last_match_label_transform()
		return
	_pulse_total_juice()
	_score_display_tween = create_tween()
	_score_display_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_score_display_tween.set_parallel(true)
	_score_display_tween.tween_method(
		func(value: float) -> void:
			_display_last_match_score = int(round(value))
			_update_last_match_label(),
		float(last_start),
		0.0,
		duration_sec,
	).set_trans(Tween.TRANS_LINEAR)
	_score_display_tween.parallel().tween_method(
		func(value: float) -> void:
			_display_total_score = int(round(value))
			_set_total_value_display(_display_total_score),
		float(start_total),
		float(target_total),
		duration_sec,
	).set_trans(Tween.TRANS_LINEAR)
	await _score_display_tween.finished
	_score_display_tween = null
	_display_total_score = target_total
	_display_last_match_score = 0
	_set_total_value_display(_display_total_score)
	_update_last_match_label()
	_reset_last_match_label_transform()


func _pop_last_match_centered() -> void:
	if _last_match_value == null or not is_inside_tree():
		return
	var label := _last_match_value
	_reset_last_match_label_transform()
	var tree := get_tree()
	if tree != null:
		await tree.process_frame
	label.pivot_offset = label.size * 0.5
	var pop_duration := _scale_presentation_seconds(0.14, 0.05)
	var peak_scale := 1.1
	var pop_tween := label.create_tween()
	pop_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pop_tween.tween_property(label, "scale", Vector2(peak_scale, peak_scale), pop_duration * 0.4).set_trans(Tween.TRANS_BACK)
	pop_tween.tween_property(label, "scale", Vector2.ONE, pop_duration * 0.6)
	await pop_tween.finished


func _reset_last_match_label_transform() -> void:
	if _last_match_value == null:
		return
	_last_match_value.top_level = false
	_last_match_value.scale = Vector2.ONE
	_last_match_value.modulate = Color.WHITE


func _apply_score_display_texts() -> void:
	if _points_value:
		_points_value.text = str(_display_step_points)
	if _multi_value:
		_multi_value.text = str(_display_step_multi)
	if _total_value:
		_set_total_value_display(_display_total_score)
	if _last_match_value:
		_update_last_match_label()


func _set_total_value_display(score: int) -> void:
	if _total_value == null:
		return
	_total_value.text = _format_score(score)
	var color := _score_total_visible_color() if score > 0 else SCORE_PANEL_BG_COLOR
	_total_value.add_theme_color_override("font_color", color)


func _score_total_visible_color() -> Color:
	if _score_section != null:
		var style := _score_section.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			return style.bg_color
	return _theme_primary_shade_color()


func _theme_primary_shade_color() -> Color:
	var theme_svc: GnosisThemeService = _theme_service()
	if theme_svc != null:
		var hex := theme_svc.get_theme_property("primary.shade", "")
		if not hex.is_empty():
			return Color.from_string(hex, SCORE_SECTION_COLOR_FALLBACK)
	return SCORE_SECTION_COLOR_FALLBACK


func _theme_service() -> GnosisThemeService:
	if _service != null and _service.context != null and _service.context.engine != null:
		return _service.context.engine.get_service("Theme") as GnosisThemeService
	return null


func _update_last_match_label() -> void:
	if _last_match_value:
		_last_match_value.text = _format_score(_display_last_match_score)


func _kill_score_display_tweens() -> void:
	if _score_display_tween != null and _score_display_tween.is_valid():
		_score_display_tween.kill()
	_score_display_tween = null


func _tween_last_match_score(from_value: int, to_value: int, duration_sec: float) -> void:
	_kill_score_display_tweens()
	if not is_inside_tree() or duration_sec <= 0.0 or from_value == to_value:
		_display_last_match_score = to_value
		_update_last_match_label()
		return
	_score_display_tween = create_tween()
	_score_display_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_score_display_tween.tween_method(
		func(value: float) -> void:
			_display_last_match_score = int(round(value))
			_update_last_match_label(),
		float(from_value),
		float(to_value),
		duration_sec,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _score_display_tween.finished
	_score_display_tween = null


func _tween_total_score(from_value: int, to_value: int, duration_sec: float) -> void:
	_kill_score_display_tweens()
	if not is_inside_tree() or duration_sec <= 0.0:
		_display_total_score = to_value
		_set_total_value_display(_display_total_score)
		return
	_score_display_tween = create_tween()
	_score_display_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_score_display_tween.tween_method(
		func(value: float) -> void:
			_display_total_score = int(round(value))
			_set_total_value_display(_display_total_score),
		float(from_value),
		float(to_value),
		duration_sec,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _score_display_tween.finished
	_score_display_tween = null


func _pulse_last_match_juice() -> void:
	if _last_match_value == null:
		return
	var tw: Tween = _last_match_value.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_last_match_value, "scale", Vector2(1.14, 1.14), 0.07).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_last_match_value, "scale", Vector2.ONE, 0.12)


func _pulse_total_juice() -> void:
	if _total_value == null:
		return
	var tw: Tween = _total_value.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_total_value, "scale", Vector2(1.1, 1.1), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_total_value, "scale", Vector2.ONE, 0.14)


func _pulse_score_lane_juice() -> void:
	var pop_out := _scale_presentation_seconds(0.1, 0.04)
	var pop_back := _scale_presentation_seconds(0.16, 0.05)
	_pulse_score_metric_lane(_points_value, SCORE_LANE_POP_PANEL_PEAK, SCORE_LANE_POP_LABEL_PEAK, pop_out, pop_back)
	_pulse_score_metric_lane(_multi_value, SCORE_LANE_POP_PANEL_PEAK, SCORE_LANE_POP_LABEL_PEAK, pop_out, pop_back)


func _pulse_score_metric_lane(
	value_label: Label,
	panel_peak: float,
	label_peak: float,
	out_sec: float,
	back_sec: float,
) -> void:
	if value_label == null:
		return
	var panel := value_label.get_parent() as Control
	if panel != null:
		_pulse_score_lane_control(panel, panel_peak, out_sec, back_sec, true)
	_pulse_score_lane_control(value_label, label_peak, out_sec, back_sec, true)


func _pulse_score_lane_control(
	control: Control,
	peak_scale: float,
	out_sec: float,
	back_sec: float,
	flash: bool,
) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var base_modulate := control.modulate
	var tw := control.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(control, "scale", Vector2(peak_scale, peak_scale), out_sec)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if flash:
		tw.tween_property(control, "modulate", SCORE_LANE_POP_FLASH, out_sec * 0.65)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().set_parallel(true)
	tw.tween_property(control, "scale", Vector2.ONE, back_sec)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if flash:
		tw.tween_property(control, "modulate", base_modulate, back_sec)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
