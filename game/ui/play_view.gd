class_name UltravibePlayView
extends GnosisUIElementView

## Pre-run setup screen (viewId "play"). Two tabs mirror the old Unity PlayView:
## setup (difficulty + player count) and modifiers (game flags).

const DIFFICULTY_FALL_SPEED := ["easy", "normal", "hard"]
const PLAYER_SPECS := [
	{"count": 1, "mode": "solo", "label": "core__noun__solo", "count_label": ""},
	{"count": 2, "mode": "coop", "label": "core__noun__duo", "count_label": "2"},
	{"count": 3, "mode": "coop", "label": "core__noun__trio", "count_label": "3"},
	{"count": 4, "mode": "coop", "label": "core__noun__quad", "count_label": "4"},
]

const ICON_CONTROLLER := "res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Icons/White/controller.png"
const ICON_KEYBOARD := "res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Icons/White/keyboard.png"
const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")

@onready var _back_button: Button = %BackButton
@onready var _setup_tab: Button = %SetupTab
@onready var _flags_tab: Button = %FlagsTab
@onready var _setup_panel: Control = %SetupPanel
@onready var _flags_panel: Control = %FlagsPanel
@onready var _difficulty_dropdown: JuicyDropdown = %DifficultyDropdown
@onready var _players_list: VBoxContainer = %PlayersList
@onready var _flags_list: VBoxContainer = %FlagsList

var _host: GnosisGodotEngine = null
var _current_tab := "setup"
var _flag_toggles: Dictionary = {}

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_back_button.pressed.connect(_on_back_pressed)
	_setup_tab.pressed.connect(func(): _show_tab("setup"))
	_flags_tab.pressed.connect(func(): _show_tab("flags"))
	_difficulty_dropdown.item_selected.connect(_on_difficulty_selected)
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		_sync_from_settings()
		call_deferred("_focus_back_button")

func _focus_back_button() -> void:
	if is_visible_in_tree() and _back_button:
		_back_button.grab_focus()

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			break
		node = node.get_parent()
	_build_player_rows()
	_populate_difficulty_options()
	_populate_flags()
	_show_tab(_current_tab)
	_sync_from_settings()

func _engine() -> GnosisEngine:
	return _host.engine if _host else null

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

func _setting() -> GnosisSettingService:
	var eng := _engine()
	return eng.get_service("Setting") as GnosisSettingService if eng else null

func _localization() -> GnosisLocalizationService:
	var eng := _engine()
	return eng.get_service("Localization") as GnosisLocalizationService if eng else null

func _show_tab(which: String) -> void:
	_current_tab = which
	_setup_panel.visible = which == "setup"
	_flags_panel.visible = which == "flags"
	_setup_tab.button_pressed = which == "setup"
	_flags_tab.button_pressed = which == "flags"

func _build_player_rows() -> void:
	for child in _players_list.get_children():
		child.free()
	for spec in PLAYER_SPECS:
		var row := _make_player_button(spec)
		_players_list.add_child(row)

func _make_player_button(spec: Dictionary) -> Button:
	var btn := preload("res://game/ui/widgets/rounded_square_btn.tscn").instantiate() as Button
	btn.custom_minimum_size = Vector2(0, 72)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.focus_mode = Control.FOCUS_ALL

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22.0
	row.offset_right = -22.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var title := Label.new()
	title.text = tr(str(spec.label)).to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.992157, 0.894118, 0.72549))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)

	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 8)
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icons)

	if not str(spec.count_label).is_empty():
		var count_lbl := Label.new()
		count_lbl.text = str(spec.count_label)
		count_lbl.add_theme_font_override("font", UI_FONT)
		count_lbl.add_theme_font_size_override("font_size", 28)
		count_lbl.add_theme_color_override("font_color", Color(0.992157, 0.894118, 0.72549))
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(count_lbl)

	icons.add_child(_make_icon(ICON_CONTROLLER))
	if int(spec.count) == 1:
		icons.add_child(_make_icon(ICON_KEYBOARD))

	var player_count: int = int(spec.count)
	var mode: String = str(spec.mode)
	btn.pressed.connect(func(): _start_run(player_count, mode))
	return btn

func _make_icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(path)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _populate_difficulty_options() -> void:
	_difficulty_dropdown.clear()
	var options := _settings_list("difficultyOptions")
	if options.is_valid() and options.get_type() == GnosisValueType.LIST:
		for i in range(options.get_count()):
			var key := str(options.get_node(i).value)
			_difficulty_dropdown.add_item(tr(key))
	else:
		for key in ["core__adjective__easy", "core__adjective__medium", "core__adjective__hard"]:
			_difficulty_dropdown.add_item(tr(key))

func _populate_flags() -> void:
	for child in _flags_list.get_children():
		child.free()
	_flag_toggles.clear()
	var catalog := _config_node("gameFlags")
	if not catalog.is_valid() or catalog.get_type() != GnosisValueType.OBJECT:
		return
	for flag_id in catalog.get_keys():
		var entry := catalog.get_node(flag_id)
		if not entry.is_valid():
			continue
		_add_flag_row(str(flag_id), entry)

func _add_flag_row(flag_id: String, entry: GnosisNode) -> void:
	var meta := entry.get_node("metadata")
	var props := entry.get_node("properties")
	var name_key := _meta_str(meta, "nameKey")
	var settings_path := _prop_str(props, "settingsPath")
	var default_value := true
	var default_node := props.get_node("defaultValue")
	if default_node.is_valid() and default_node.get_type() == GnosisValueType.BOOL:
		default_value = bool(default_node.value)
	if settings_path.is_empty():
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 56)

	var label := Label.new()
	label.text = _localized(name_key, flag_id.capitalize()).to_upper()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.992157, 0.894118, 0.72549))
	row.add_child(label)

	var toggle := preload("res://game/ui/widgets/juicy_toggle.tscn").instantiate() as JuicyToggle
	toggle.custom_minimum_size = Vector2(88, 44)
	toggle.toggled.connect(func(on: bool): _on_flag_toggled(settings_path, on))
	row.add_child(toggle)

	_flags_list.add_child(row)
	_flag_toggles[settings_path] = {"toggle": toggle, "default": default_value}

func _sync_from_settings() -> void:
	var difficulty_header := _setup_panel.get_node_or_null("DifficultyHeader") as Label
	if difficulty_header:
		difficulty_header.text = tr("core__noun__difficulty").to_upper()
	var index := _current_difficulty_index()
	if _difficulty_dropdown.item_count > 0:
		_difficulty_dropdown.select(clampi(index, 0, _difficulty_dropdown.item_count - 1))
	for settings_path in _flag_toggles.keys():
		var spec: Dictionary = _flag_toggles[settings_path]
		var toggle: JuicyToggle = spec.toggle
		var default_value: bool = spec.default
		var value := _read_bool_setting(settings_path, default_value)
		toggle.set_pressed_silent(value)

func _current_difficulty_index() -> int:
	var setting := _setting()
	if setting == null:
		return 1
	return setting.get_int("settings.difficultyIndex", true, 1)

func _difficulty_id_from_index(index: int) -> String:
	var clamped := clampi(index, 0, DIFFICULTY_FALL_SPEED.size() - 1)
	return DIFFICULTY_FALL_SPEED[clamped]

func _on_difficulty_selected(index: int) -> void:
	var setting := _setting()
	if setting == null:
		return
	var store := setting.context.store
	var args := store.create_object()
	args.set_key("key", "settings.difficultyIndex")
	args.set_key("index", index)
	setting.set_dropdown(args)
	var fall_speed := _difficulty_id_from_index(index)
	setting.set_state_value("settings.overrides.fallingBlock.fallSpeedDifficulty", fall_speed, true)

func _on_flag_toggled(settings_path: String, on: bool) -> void:
	var setting := _setting()
	if setting == null:
		return
	var store := setting.context.store
	var args := store.create_object()
	args.set_key("key", settings_path)
	args.set_key("value", on)
	setting.set_bool(args)

func _start_run(player_count: int, mode: String) -> void:
	GnosisRunSave.clear_run_save()
	if _host:
		_host.restart_ephemeral_run()
	var eng := _engine()
	if eng == null:
		return
	var ephemeral := eng.state.root.get_node("Ephemeral")
	if ephemeral.is_valid():
		ephemeral.set_key("playerCount", player_count)
		ephemeral.set_key("mode", mode)
		var difficulty_id := _difficulty_id_from_index(_current_difficulty_index())
		var fb := ephemeral.get_node("fallingBlock")
		if fb.is_valid():
			fb.set_key("fallSpeedDifficulty", difficulty_id)
			_copy_game_flags_to_ephemeral(fb)
	var falling_block := eng.get_service("FallingBlock") as FallingBlockService
	if falling_block:
		# restart_ephemeral_run() recreates services before adapters have runtime
		# refs, so seed the run after the selected Ephemeral settings are written.
		falling_block.handle_run_started()
	var ui := _game_ui()
	if ui and eng:
		UltraGameUiNav.transition_to_gameplay(ui, eng.store, "play", "slide_up")

func _copy_game_flags_to_ephemeral(fb_node: GnosisNode) -> void:
	var eng := _engine()
	if eng == null:
		return
	var overrides := eng.state.root.get_node("Persistent.settings.overrides.fallingBlock.gameFlags")
	var ephemeral_flags := fb_node.get_node("gameFlags")
	if not overrides.is_valid() or not ephemeral_flags.is_valid():
		return
	for key in overrides.get_keys():
		var value_node := overrides.get_node(key)
		if value_node.is_valid():
			ephemeral_flags.set_key(str(key), value_node.value)

func _read_bool_setting(path: String, default_value: bool) -> bool:
	var setting := _setting()
	if setting == null:
		return default_value
	return setting.get_bool(path, true, default_value)

func _settings_list(key: String) -> GnosisNode:
	var eng := _engine()
	if eng == null:
		return GnosisNode.new(null)
	var settings := eng.state.root.get_node("Persistent.settings")
	if not settings.is_valid():
		return GnosisNode.new(null)
	return settings.get_node(key)

func _config_node(key: String) -> GnosisNode:
	var eng := _engine()
	if eng == null:
		return GnosisNode.new(null)
	var config := eng.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node(key)

func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty():
		return fallback
	var loc := _localization()
	if loc == null:
		return fallback
	return loc.get_string_value(key, fallback)

func _on_back_pressed() -> void:
	var ui := _game_ui()
	if ui and _engine():
		if ui.get_navigation_history_count() > 0:
			var params := _engine().store.create_object()
			params.set_key("transitionId", "slide_down")
			params.set_key("inDuration", 0.35)
			params.set_key("outDuration", 0.35)
			ui.invoke_function("PopView", params)
		else:
			ui.set_base_view("title")

func _meta_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	return str(n.value) if n.is_valid() and n.value != null else ""

func _prop_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	return str(n.value) if n.is_valid() and n.value != null else ""
