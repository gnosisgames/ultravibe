class_name UltravibePauseView
extends GnosisUIElementView

## Pause overlay shown additively over gameplay. Styled after the settings
## screen: a "PAUSED" title, a row of action buttons (resume / restart / home /
## settings / wiki), and a scrollable panel previewing the current run deck.

## Slot background behind each deck piece; built once and shared by every cell.
const SLOT_BG_COLOR := Color(0.164706, 0.207843, 0.313725, 1)
const SLOT_SIZE := Vector2(118, 118)

## Matches the variant palette used by the board renderer / next-piece preview so
## the deck thumbnails read with the same colours as the pieces in play.
const VARIANT_COLORS := {
	"blue": Color(0.2, 0.5, 1.0),
	"red": Color(1.0, 0.25, 0.25),
	"green": Color(0.2, 0.85, 0.35),
	"orange": Color(1.0, 0.55, 0.1),
	"disabled": Color(0.45, 0.45, 0.45),
}
const FALLBACK_COLOR := Color(0.75, 0.75, 0.85)

@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _home_button: Button = %HomeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _wiki_button: Button = %WikiButton
@onready var _deck_grid: GridContainer = %DeckGrid
@onready var _card: PanelContainer = $Center/Layout/Card

var _host: GnosisGodotEngine = null
var _registry := UltravibeRegistry.new()
var _slot_style: StyleBoxFlat = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_registry.load_shapes()
	_slot_style = _build_slot_style()
	_resume_button.pressed.connect(_on_resume_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_home_button.pressed.connect(_on_home_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_wiki_button.pressed.connect(_on_wiki_pressed)
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		if _card:
			_card.scale = Vector2.ONE
			_card.modulate.a = 1.0
		_play_card_intro()
		_populate_deck()

func _play_card_intro() -> void:
	if _card == null:
		return
	var tween_node := _card.get_node_or_null("AutoTween")
	if tween_node and tween_node.has_method("show"):
		tween_node.show()

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			return
		node = node.get_parent()

func _engine() -> GnosisEngine:
	return _host.engine if _host else null

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

func _falling_block() -> FallingBlockService:
	var eng := _engine()
	return eng.get_service("FallingBlock") as FallingBlockService if eng else null

# --- deck preview -----------------------------------------------------------

func _build_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_BG_COLOR
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 6.0
	style.content_margin_top = 6.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 6.0
	return style

func _populate_deck() -> void:
	if _deck_grid == null:
		return
	for child in _deck_grid.get_children():
		child.queue_free()
	var fb := _falling_block()
	if fb == null or fb.context == null:
		return
	var deck := FallingBlockEphemeral.get_fb_node(fb.context, "deckEntries")
	if not deck.is_valid() or deck.get_type() != GnosisValueType.LIST:
		return
	for i in range(deck.get_count()):
		var entry := deck.get_node(i)
		if not entry.is_valid():
			continue
		var poly_id := _node_str(entry, "ultravibeId")
		var variant_id := _node_str(entry, "variantId")
		var info := _registry.get_shape(poly_id)
		if info == null:
			continue
		var color: Color = VARIANT_COLORS.get(variant_id.to_lower(), FALLBACK_COLOR)
		_deck_grid.add_child(_make_slot(info.block_offsets, variant_id, color))

func _make_slot(offsets: Array, variant_id: String, color: Color) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.add_theme_stylebox_override("panel", _slot_style)
	var thumb := DeckPieceThumb.new()
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_child(thumb)
	thumb.setup(offsets, variant_id, color)
	return slot

func _node_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	if n.is_valid() and n.value != null:
		return str(n.value)
	return ""

# --- button actions ---------------------------------------------------------

func _on_resume_pressed() -> void:
	var ui := _game_ui()
	if ui:
		ui.invoke_function("PopView", _engine().store.create_object())

func _on_restart_pressed() -> void:
	GnosisRunSave.clear_run_save()
	var ui := _game_ui()
	if ui:
		ui.invoke_function("PopView", _engine().store.create_object())
	if _host:
		_host.restart_ephemeral_run()
	var fb := _falling_block()
	if fb:
		fb.handle_run_started()

func _on_home_pressed() -> void:
	var ui := _game_ui()
	var eng := _engine()
	if ui == null or eng == null:
		return
	if _host and _host.has_method("try_save_in_progress_run"):
		_host.try_save_in_progress_run()
	# Leave the paused context entirely before returning to the title so the
	# pause overlay state doesn't linger (and freeze) into the next run.
	UltraGameUiNav.reset_theme_to_default(eng)
	ui.invoke_function("PopView", eng.store.create_object())
	ui.set_base_view("title")

func _on_settings_pressed() -> void:
	_open_view_from_pause("settings", "slide_left")

func _on_wiki_pressed() -> void:
	_open_view_from_pause("collection", "slide_right")

## Opens a full-screen view (settings / collection) from the pause overlay using
## the same slide transitions as the title menu. The pause overlay is left OPEN
## (not dismissed) so the run stays paused and "Back" from the opened view pops
## to gameplay where the adapter restores the pause menu rather than resuming.
func _open_view_from_pause(view_id: String, transition_id: String) -> void:
	var eng := _engine()
	var ui := _game_ui()
	if eng == null or ui == null:
		return
	var params := eng.store.create_object()
	params.set_key("viewId", view_id)
	params.set_key("transitionId", transition_id)
	params.set_key("inDuration", 0.35)
	params.set_key("outDuration", 0.35)
	ui.invoke_function("PushView", params)
