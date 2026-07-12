class_name UltravibePlayView
extends GnosisUIElementView

## Pre-run setup screen (viewId "play"). Setup tab starts a solo run; modifiers tab
## edits game flags.

const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")

@onready var _back_button: Button = %BackButton
@onready var _setup_tab: Button = %SetupTab
@onready var _flags_tab: Button = %FlagsTab
@onready var _setup_panel: Control = %SetupPanel
@onready var _flags_panel: Control = %FlagsPanel
@onready var _play_button: Button = %PlayButton
@onready var _flags_list: VBoxContainer = %FlagsList

var _host: GnosisGodotEngine = null
var _current_tab := "setup"
var _flag_toggles: Dictionary = {}

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_back_button.pressed.connect(_on_back_pressed)
	_setup_tab.pressed.connect(func(): _show_tab("setup"))
	_flags_tab.pressed.connect(func(): _show_tab("flags"))
	_play_button.pressed.connect(_on_play_pressed)
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		_sync_from_settings()
		call_deferred("_focus_default_control")

func get_preferred_focus_control() -> Control:
	if _current_tab == "setup" and _play_button and not _play_button.disabled:
		return _play_button
	if _back_button and not _back_button.disabled:
		return _back_button
	return null

func _focus_default_control() -> void:
	var target := get_preferred_focus_control()
	if target and is_visible_in_tree():
		target.grab_focus()

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			break
		node = node.get_parent()
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
	if which == "setup":
		call_deferred("_focus_default_control")

func _on_play_pressed() -> void:
	_start_run()

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
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	row.add_child(label)

	var toggle := preload("res://game/ui/widgets/juicy_toggle.tscn").instantiate() as JuicyToggle
	toggle.custom_minimum_size = Vector2(88, 44)
	toggle.toggled.connect(func(on: bool): _on_flag_toggled(settings_path, on))
	row.add_child(toggle)

	_flags_list.add_child(row)
	_flag_toggles[settings_path] = {"toggle": toggle, "default": default_value}

func _sync_from_settings() -> void:
	for settings_path in _flag_toggles.keys():
		var spec: Dictionary = _flag_toggles[settings_path]
		var toggle: JuicyToggle = spec.toggle
		var default_value: bool = spec.default
		var value := _read_bool_setting(settings_path, default_value)
		toggle.set_pressed_silent(value)

func _on_flag_toggled(settings_path: String, on: bool) -> void:
	var setting := _setting()
	if setting == null:
		return
	var store := setting.context.store
	var args := store.create_object()
	args.set_key("key", settings_path)
	args.set_key("value", on)
	setting.set_bool(args)

func _start_run() -> void:
	GnosisRunSave.clear_run_save()
	if _host:
		_host.restart_ephemeral_run()
	var eng := _engine()
	if eng == null:
		return
	var ephemeral := eng.state.root.get_node("Ephemeral")
	if ephemeral.is_valid():
		ephemeral.set_key("playerCount", 1)
		ephemeral.set_key("mode", "solo")
	var match3 = eng.get_service("Match3")
	if match3:
		match3.handle_run_started()
	if _host and _host.has_method("resync_match3_board_view"):
		_host.resync_match3_board_view()
	var ui := _game_ui()
	if ui and eng:
		UltraGameUiNav.transition_to_gameplay(ui, eng.store, "play", "slide_up", true)

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
	var eng := _engine()
	if ui == null or eng == null:
		return
	UltraGameUiNav.pop_menu_back(ui, eng.store, "slide_down")

func _meta_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	return str(n.value) if n.is_valid() and n.value != null else ""

func _prop_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	return str(n.value) if n.is_valid() and n.value != null else ""
