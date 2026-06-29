class_name FallingBlockAdapter
extends GnosisAdapter

const FallingBlockServiceScript = preload("res://game/services/falling_block_service.gd")
const PlayerRuntime = preload("res://game/services/falling_block_player_runtime.gd")
const FallingBlockTraitOverlay = preload("res://game/adapters/falling_block_trait_overlay.gd")
const UltraAccessibilitySettings = preload("res://game/ultra_accessibility_settings.gd")

@export var player_id: String = "P0"
@export var redraw_each_frame: bool = true

var _falling_block_service: FallingBlockService = null
var _run_state := FallingBlockModels.RunState.new()
var _grid_state := FallingBlockModels.GridState.new()
var _player_states: Array = []
var _board_renderer: FallingBlockBoardRenderer = null
var _trait_overlay: FallingBlockTraitOverlay = null
var _ultravibe_registry := UltravibeRegistry.new()
var _game_over_subscription: RefCounted = null
var _line_clear_subscription: RefCounted = null
var _piece_locked_subscription: RefCounted = null

func _ready() -> void:
	_board_renderer = get_tree().get_first_node_in_group(
		FallingBlockBoardRenderer.BOARD_RENDERER_GROUP
	) as FallingBlockBoardRenderer
	if _board_renderer == null:
		var parent := get_parent()
		if parent:
			_board_renderer = parent.get_node_or_null("BoardRenderer") as FallingBlockBoardRenderer
	_player_states = _build_player_states()

func _exit_tree() -> void:
	_dispose(_game_over_subscription)
	_game_over_subscription = null
	_dispose(_line_clear_subscription)
	_line_clear_subscription = null
	_dispose(_piece_locked_subscription)
	_piece_locked_subscription = null

func _dispose(sub: RefCounted) -> void:
	if sub and sub.has_method("dispose"):
		sub.dispose()

func _on_game_over_event(_event) -> void:
	GnosisRunSave.clear_run_save()
	var game_ui := engine.get_service("GameUI") as GnosisGameUIService if engine else null
	if game_ui == null or engine == null:
		return
	# Show game over as an additive overlay above the (now-lost) board, like the
	# pause menu, so the final grid stays visible behind a dimmed summary panel.
	if game_ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return
	if not game_ui.get_active_overlay_state_for_view("game_over").is_empty():
		return
	var params := engine.store.create_object()
	params.set_key("viewId", "game_over")
	params.set_key("overlayStateId", "open")
	game_ui.invoke_function("PushViewAdditive", params)

func rebuild_player_states_from_ephemeral() -> void:
	_player_states = _build_player_states()
	if _falling_block_service:
		_falling_block_service.set_runtime_references(
			_run_state,
			_grid_state,
			_player_states,
			_ultravibe_registry
		)
	if _board_renderer:
		_board_renderer.bind_grid_state(_grid_state)

func _on_service_bound() -> void:
	_falling_block_service = service as FallingBlockService
	_ultravibe_registry.load_shapes()
	_falling_block_service.set_runtime_references(
		_run_state,
		_grid_state,
		_player_states,
		_ultravibe_registry
	)
	# Fresh runs call handle_run_started() from the play/pause UI after Ephemeral
	# settings are written; Continue restores a saved runtime snapshot instead.
	if _board_renderer:
		_board_renderer.bind_grid_state(_grid_state)
	if engine and engine.event_bus:
		_game_over_subscription = engine.event_bus.subscribe(
			FallingBlockEvents.FACT_FALLING_BLOCK_GAME_OVER,
			_on_game_over_event,
			0
		)
		_line_clear_subscription = engine.event_bus.subscribe(
			FallingBlockEvents.FACT_FALLING_BLOCK_LINE_CLEAR_CALLOUT,
			_on_line_clear_callout,
			0
		)
		_piece_locked_subscription = engine.event_bus.subscribe(
			FallingBlockEvents.FACT_FALLING_BLOCK_PIECE_LOCKED,
			_on_piece_locked,
			0
		)

## Forwards the just-locked piece footprint to the renderer for the hard-drop
## "slam" placement flash. No-op when the geometry payload is absent.
func _on_piece_locked(event: GnosisEvent) -> void:
	if _board_renderer == null or not event or not event.data.is_valid():
		return
	if not UltraAccessibilitySettings.light_flashes_enabled(engine):
		return
	var center_node := event.data.get_node(FallingBlockEvents.PAYLOAD_CENTER_GRID_X)
	if not center_node.is_valid():
		return
	var center_x := float(center_node.value) if center_node.value != null else 0.0
	var bottom_y := _node_int(event.data, FallingBlockEvents.PAYLOAD_BOTTOM_GRID_Y)
	var columns := maxi(1, _node_int(event.data, FallingBlockEvents.PAYLOAD_COLUMN_COUNT))
	var drop_node := event.data.get_node(FallingBlockEvents.PAYLOAD_DROP_DISTANCE)
	var drop := float(drop_node.value) if drop_node.is_valid() and drop_node.value != null else 0.0
	var variant := _event_string(event.data, FallingBlockEvents.PAYLOAD_VARIANT_ID)
	_board_renderer.play_placement_flash(center_x, bottom_y, columns, drop, variant)

## Forwards the cleared-cell snapshot to the renderer so it can play the legacy
## white flash (mirrors the Unity blockclear feedback handler).
func _on_line_clear_callout(event: GnosisEvent) -> void:
	if _board_renderer == null or not event or not event.data.is_valid():
		return
	if not UltraAccessibilitySettings.light_flashes_enabled(engine):
		return
	var cells_node := event.data.get_node(FallingBlockEvents.PAYLOAD_CLEAR_CELLS)
	if not cells_node.is_valid() or cells_node.get_type() != GnosisValueType.LIST:
		return
	var cells: Array = []
	for i in range(cells_node.get_count()):
		var cell_node := cells_node.get_node(i)
		if not cell_node.is_valid():
			continue
		cells.append({
			"x": _node_int(cell_node, FallingBlockEvents.PAYLOAD_CLEAR_CELL_GRID_X),
			"y": _node_int(cell_node, FallingBlockEvents.PAYLOAD_CLEAR_CELL_GRID_Y),
			"variant": _event_string(cell_node, FallingBlockEvents.PAYLOAD_CLEAR_CELL_VARIANT_ID),
		})
	if not cells.is_empty():
		_board_renderer.play_line_clear_flash(cells)

func _node_int(node: GnosisNode, key: String) -> int:
	var n := node.get_node(key)
	if n.is_valid() and n.value != null:
		return int(n.value)
	return 0

func _process(delta: float) -> void:
	if not _falling_block_service:
		return
	# Gameplay input is routed via GnosisInputService (UltravibeGameplayInputRouter);
	# the simulation only advances while the gameplay view is foremost so opening a
	# menu/pause overlay halts gravity without freezing the rest of the scene tree.
	if _gameplay_live():
		_falling_block_service.process_frame(delta)
	if redraw_each_frame and _board_renderer:
		_board_renderer.ghost_suppressed = _falling_block_service.is_ghost_suppressed()
		_board_renderer.trait_overlay_entries = _resolve_trait_overlay_entries()
		_board_renderer.bind_grid_state(_grid_state)

func _resolve_trait_overlay_entries() -> Array:
	if _trait_overlay == null:
		if engine == null:
			return []
		_trait_overlay = FallingBlockTraitOverlay.new(engine)
	return _trait_overlay.resolve_entries(_grid_state)

func _build_player_states() -> Array:
	var count := 1
	if engine and engine.state and engine.state.is_valid():
		var eph := engine.state.root.get_node("Ephemeral")
		if eph.is_valid():
			count = PlayerRuntime.clamp_player_count(FallingBlockEphemeral.read_int(eph.get_node("playerCount"), 1))
	var players: Array = []
	for i in range(count):
		var ps := FallingBlockModels.PlayerState.new()
		ps.player_id = PlayerRuntime.build_player_id(i)
		players.append(ps)
	if players.is_empty():
		var solo := FallingBlockModels.PlayerState.new()
		solo.player_id = player_id if not player_id.is_empty() else "P0"
		players.append(solo)
	return players

func send_input(input_type: int, target_player_id: String = "") -> void:
	if _falling_block_service:
		var pid := target_player_id if not target_player_id.is_empty() else player_id
		if pid.is_empty() and not _player_states.is_empty():
			pid = (_player_states[0] as FallingBlockModels.PlayerState).player_id
		_falling_block_service.publish_input_from_adapter(pid, input_type)

func _gameplay_live() -> bool:
	if not engine:
		return true
	var ui := engine.get_service("GameUI") as GnosisGameUIService
	if ui == null:
		return true
	if ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return false
	return ui.get_active_overlay_state_for_view("pause").is_empty() \
		and ui.get_active_overlay_state_for_view("game_over").is_empty()

func _event_string(data: GnosisNode, key: String) -> String:
	var node := data.get_node(key)
	return str(node.value) if node.is_valid() and node.value != null else ""
