class_name UltravibeSettingsView
extends GnosisUIElementView

## Tabbed settings screen (viewId "settings"), styled after the Unity SettingsView:
## an icon/text tab bar (Audio / Language / Theme) over a swappable content area.
## All state is driven through Gnosis services.

const AudioService = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_audio_service.gd")
const SettingService = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_setting_service.gd")
const RoundedSquareBtnScene = preload("res://game/ui/widgets/rounded_square_btn.tscn")
## Shared UI font (matches the buttons/titles) so rebind row labels read in the
## same typeface as the rest of the HUD rather than the default pixel font.
const UI_FONT = preload("res://assets/fonts/Comic Lemon.otf")
## Order the rebind rows are grouped into, with their section-header i18n keys.
## Actions whose category isn't listed here are appended under their raw name.
const CATEGORY_ORDER := ["gameplay", "ui", "console"]
const CATEGORY_LABELS := {
	"gameplay": "ultravibe__settings__category__gameplay",
	"ui": "ultravibe__settings__category__ui",
	"console": "ultravibe__settings__category__console",
}
const HAPTICS_ENABLED_KEY := "haptic.hapticsEnabled"
const GAME_SPEED_KEY := "settings.gameSpeed"
const LOG_LEVEL_KEY := "settings.logLevel"
const SHOW_FPS_KEY := "settings.showFps"
const SHOW_VERSION_KEY := "settings.showVersion"
const SHOW_DEVICE_INFO_KEY := "settings.showDeviceInfo"
const ENABLE_CONSOLE_KEY := "settings.enableConsole"
const LOG_LEVEL_VALUES := ["none", "error", "warning", "info", "debug", "trace"]
const LOG_LEVEL_LABELS := [
	"core__adjective__none",
	"core__logLevel__error",
	"core__logLevel__warning",
	"core__logLevel__info",
	"core__logLevel__debug",
	"core__logLevel__trace",
]
const DEFAULT_LOG_LEVEL_INDEX := 3
const SCANLINES_KEY := "settings.crtScanlinesStrength"
const VIGNETTE_INTENSITY_KEY := "settings.vignetteIntensity"
const CRT_FILTER_ENABLED_KEY := "settings.crtFilterEnabled"
const VSYNC_KEY := "settings.vsyncEnabled"
const WINDOW_MODE_KEY := "settings.windowMode"
const FRAMERATE_CAP_KEY := "settings.framerateCap"
const RESOLUTION_INDEX_KEY := "settings.resolutionIndex"
const DISPLAY_INDEX_KEY := "settings.displayIndex"
const REFRESH_RATE_INDEX_KEY := "settings.refreshRateIndex"
const WINDOW_MODE_LABELS := {
	"WindowModeWindowed": "WindowModeWindowed",
	"WindowModeExclusiveFullScreen": "WindowModeExclusiveFullScreen",
	"WindowModeFullScreenWindow": "WindowModeFullScreenWindow",
}
const FLAG_DIR := "res://assets/ui/flags/"
const FLAG_BY_CODE := {
	"en": "englishFlag", "es": "spanishFlag", "fr": "frenchFlag", "de": "germanFlag",
	"it": "italianFlag", "pt": "portugueseFlag", "pl": "polishFlag", "ro": "romanianFlag",
	"sv": "swedishFlag", "el": "greekFlag", "zh": "china", "ko": "korea", "ja": "japan"
}
var _input_bindings_cache: Dictionary = {}

func _input_bindings() -> Dictionary:
	if _input_bindings_cache.is_empty():
		_input_bindings_cache = GnosisConsoleInputActions.merge_with_game_bindings(GameInputActions.BINDINGS)
	return _input_bindings_cache

@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _ui_slider: HSlider = %UiSlider
@onready var _scanlines_slider: HSlider = %ScanlinesSlider
@onready var _vignette_slider: HSlider = %VignetteSlider
@onready var _crt_filter_toggle: JuicyToggle = %CrtFilterToggle
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _refresh_option: OptionButton = %RefreshRateOption
@onready var _monitor_option: OptionButton = %MonitorOption
@onready var _window_mode_option: OptionButton = %WindowModeOption
@onready var _framerate_option: OptionButton = %FramerateOption
@onready var _framerate_row: HBoxContainer = %FramerateRow
@onready var _vsync_toggle: JuicyToggle = %VsyncToggle
@onready var _back_button: Button = %BackButton
@onready var _audio_tab: Button = %AudioTab
@onready var _language_tab: Button = %LanguageTab
@onready var _theme_tab: Button = %ThemeTab
@onready var _filter_tab: Button = %FilterTab
@onready var _input_tab: Button = %InputTab
@onready var _gamepad_tab: Button = %GamepadTab
@onready var _accessibility_tab: Button = %AccessibilityTab
@onready var _advanced_tab: Button = %AdvancedTab
@onready var _audio_panel: VBoxContainer = %AudioPanel
@onready var _language_panel: VBoxContainer = %LanguagePanel
@onready var _video_panel: VBoxContainer = %VideoPanel
@onready var _filter_panel: VBoxContainer = %FilterPanel
@onready var _input_panel: ScrollContainer = %InputPanel
@onready var _gamepad_panel: ScrollContainer = %GamepadPanel
@onready var _accessibility_panel: VBoxContainer = %AccessibilityPanel
@onready var _advanced_panel: ScrollContainer = %AdvancedPanel
@onready var _log_level_option: OptionButton = %LogLevelOption
@onready var _show_fps_toggle: JuicyToggle = %ShowFpsToggle
@onready var _show_version_toggle: JuicyToggle = %ShowVersionToggle
@onready var _show_device_info_toggle: JuicyToggle = %ShowDeviceInfoToggle
@onready var _enable_console_toggle: JuicyToggle = %EnableConsoleToggle
@onready var _vibration_toggle: JuicyToggle = %VibrationToggle
@onready var _game_speed_option: OptionButton = %GameSpeedOption
@onready var _flag_grid: GridContainer = %FlagGrid
@onready var _keyboard_grid: GridContainer = %KeyboardGrid
@onready var _gamepad_grid: GridContainer = %GamepadGrid
@onready var _capture_status: Label = %CaptureStatus
@onready var _gamepad_capture_status: Label = %GamepadCaptureStatus
@onready var _reset_keyboard_button: Button = %ResetKeyboardButton
@onready var _reset_gamepad_button: Button = %ResetGamepadButton
@onready var _keyboard_bindings_panel: VBoxContainer = %KeyboardBindingsPanel
@onready var _gamepad_bindings_panel: VBoxContainer = %GamepadBindingsPanel
@onready var _no_input_devices_label: Label = %NoInputDevicesLabel

var _host: GnosisGodotEngine = null
var _language_codes: Array[String] = []
var _flag_buttons: Array[LanguageFlagButton] = []
var _keyboard_buttons: Dictionary = {}
var _gamepad_buttons: Dictionary = {}
var _capturing_action := ""
var _capturing_scheme := ""
var _current_tab := "audio"
var _syncing := false

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	set_process_unhandled_input(true)
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_ui_slider.value_changed.connect(_on_ui_changed)
	_back_button.pressed.connect(_on_back_pressed)
	_audio_tab.pressed.connect(func(): _show_tab("audio"))
	_input_tab.pressed.connect(func(): _show_tab("controls"))
	_gamepad_tab.pressed.connect(func(): _show_tab("gamepad"))
	_theme_tab.pressed.connect(func(): _show_tab("video"))
	_filter_tab.pressed.connect(func(): _show_tab("filter"))
	_accessibility_tab.pressed.connect(func(): _show_tab("accessibility"))
	_language_tab.pressed.connect(func(): _show_tab("language"))
	_advanced_tab.pressed.connect(func(): _show_tab("advanced"))
	_reset_keyboard_button.pressed.connect(_reset_keyboard_defaults)
	_reset_gamepad_button.pressed.connect(_reset_gamepad_defaults)
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_vibration_toggle.toggled.connect(_on_vibration_toggled)
	_game_speed_option.item_selected.connect(_on_game_speed_selected)
	_log_level_option.item_selected.connect(_on_log_level_selected)
	_scanlines_slider.value_changed.connect(func(v): _set_setting_slider(SCANLINES_KEY, v))
	_vignette_slider.value_changed.connect(func(v): _set_setting_slider(VIGNETTE_INTENSITY_KEY, v))
	_crt_filter_toggle.toggled.connect(_on_crt_filter_toggled)
	_resolution_option.item_selected.connect(func(i): _set_setting_dropdown(RESOLUTION_INDEX_KEY, i))
	_refresh_option.item_selected.connect(func(i): _set_setting_dropdown(REFRESH_RATE_INDEX_KEY, i))
	_monitor_option.item_selected.connect(func(i): _set_setting_dropdown(DISPLAY_INDEX_KEY, i))
	_window_mode_option.item_selected.connect(func(i): _set_setting_dropdown(WINDOW_MODE_KEY, i))
	_framerate_option.item_selected.connect(func(i): _set_setting_dropdown(FRAMERATE_CAP_KEY, i))
	_vsync_toggle.toggled.connect(_on_vsync_toggled)
	_show_fps_toggle.toggled.connect(func(on): _set_setting_bool(SHOW_FPS_KEY, on))
	_show_version_toggle.toggled.connect(func(on): _set_setting_bool(SHOW_VERSION_KEY, on))
	_show_device_info_toggle.toggled.connect(func(on): _set_setting_bool(SHOW_DEVICE_INFO_KEY, on))
	_enable_console_toggle.toggled.connect(func(on): _set_setting_bool(ENABLE_CONSOLE_KEY, on))
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		_refresh_input_device_tabs()
		_sync_from_services()

func _show_tab(which: String) -> void:
	_current_tab = which
	_audio_panel.visible = which == "audio"
	_language_panel.visible = which == "language"
	_video_panel.visible = which == "video"
	_filter_panel.visible = which == "filter"
	_input_panel.visible = which == "controls"
	_gamepad_panel.visible = which == "gamepad"
	_accessibility_panel.visible = which == "accessibility"
	_advanced_panel.visible = which == "advanced"
	_audio_tab.button_pressed = which == "audio"
	_language_tab.button_pressed = which == "language"
	_theme_tab.button_pressed = which == "video"
	_filter_tab.button_pressed = which == "filter"
	_input_tab.button_pressed = which == "controls"
	_gamepad_tab.button_pressed = which == "gamepad"
	_accessibility_tab.button_pressed = which == "accessibility"
	_advanced_tab.button_pressed = which == "advanced"
	if which != "controls" and which != "gamepad":
		_cancel_capture()
	if which == "controls":
		_sync_keyboard_bindings()
		_set_capture_status_idle()
	elif which == "gamepad":
		_sync_gamepad_bindings()
		_set_capture_status_idle()
	elif _capturing_action.is_empty():
		_set_capture_status_idle()

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			break
		node = node.get_parent()
	_populate_options()
	_refresh_input_device_tabs()
	_sync_from_services()
	_show_tab("audio")

func _populate_game_speed_options() -> void:
	_game_speed_option.clear()
	var options := _settings_list("gameSpeedOptions")
	if options.is_valid() and options.get_type() == GnosisValueType.LIST and options.get_count() > 0:
		for i in range(options.get_count()):
			_game_speed_option.add_item(tr(str(options.get_node(i).value)))
	else:
		_game_speed_option.add_item(tr("ultravibe__settings__gameSpeed__1x"))
		_game_speed_option.add_item(tr("ultravibe__settings__gameSpeed__2x"))
		_game_speed_option.add_item(tr("ultravibe__settings__gameSpeed__3x"))
		_game_speed_option.add_item(tr("ultravibe__settings__gameSpeed__4x"))

func _engine() -> GnosisEngine:
	return _host.engine if _host else null

func _audio() -> GnosisAudioService:
	var eng := _engine()
	return eng.get_service("Audio") as GnosisAudioService if eng else null

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

func _config_node(key: String) -> GnosisNode:
	var eng := _engine()
	if not eng:
		return GnosisNode.new(null)
	var config := eng.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node(key)

func _setting() -> GnosisSettingService:
	var eng := _engine()
	return eng.get_service("Setting") as GnosisSettingService if eng else null

func _populate_options() -> void:
	_populate_languages()
	_populate_input_bindings()
	_populate_log_levels()
	_populate_game_speed_options()
	_populate_video_options()

## Video dropdown contents come from the settings option lists, which
## UltraDisplaySettings enumerates at startup. Repopulated on each open in case
## enumeration finished after the first pass.
func _populate_video_options() -> void:
	_window_mode_option.clear()
	var modes := _settings_list("windowModeOptions")
	if modes.is_valid() and modes.get_type() == GnosisValueType.LIST:
		for i in range(modes.get_count()):
			var raw := str(modes.get_node(i).value)
			_window_mode_option.add_item(tr(str(WINDOW_MODE_LABELS.get(raw, raw))))
	if _window_mode_option.item_count == 0:
		_window_mode_option.add_item(tr("WindowModeWindowed"))

	_framerate_option.clear()
	var caps := _settings_list("framerateOptionLabels")
	if caps.is_valid() and caps.get_type() == GnosisValueType.LIST:
		for i in range(caps.get_count()):
			var lbl := str(caps.get_node(i).value)
			_framerate_option.add_item(tr("ultravibe__settings__uncapped") if lbl == "-1" else "%s FPS" % lbl)
	if _framerate_option.item_count == 0:
		_framerate_option.add_item(tr("ultravibe__settings__uncapped"))

	_resolution_option.clear()
	var res := _settings_list("resolutionOptions")
	if res.is_valid() and res.get_type() == GnosisValueType.LIST:
		for i in range(res.get_count()):
			_resolution_option.add_item(_node_str(res.get_node(i), "text"))
	if _resolution_option.item_count == 0:
		_resolution_option.add_item(tr("core__state__default"))

	_refresh_option.clear()
	var rates := _settings_list("refreshRateOptions")
	if rates.is_valid() and rates.get_type() == GnosisValueType.LIST:
		for i in range(rates.get_count()):
			_refresh_option.add_item(_node_str(rates.get_node(i), "text"))
	if _refresh_option.item_count == 0:
		_refresh_option.add_item("60 Hz")

	_monitor_option.clear()
	var monitors := _settings_list("monitorOptionLabels")
	if monitors.is_valid() and monitors.get_type() == GnosisValueType.LIST:
		for i in range(monitors.get_count()):
			_monitor_option.add_item(str(monitors.get_node(i).value))
	if _monitor_option.item_count == 0:
		_monitor_option.add_item("Display 1")

func _populate_log_levels() -> void:
	_log_level_option.clear()
	for label in LOG_LEVEL_LABELS:
		_log_level_option.add_item(tr(label))

func _populate_languages() -> void:
	for b in _flag_buttons:
		b.queue_free()
	_flag_buttons.clear()
	_language_codes.clear()
	var languages := _config_node("availableLanguages").get_node("languages")
	if languages.is_valid() and languages.get_type() == GnosisValueType.LIST:
		for i in range(languages.get_count()):
			var entry := languages.get_node(i)
			var code := _node_str(entry, "code")
			if code.is_empty():
				continue
			_language_codes.append(code)
			_add_flag_button(code, _node_str(entry, "id"))
	if _language_codes.is_empty():
		_language_codes.append("en")
		_add_flag_button("en", "english")

func _add_flag_button(code: String, id_name: String) -> void:
	var btn := LanguageFlagButton.new()
	btn.custom_minimum_size = Vector2(124, 128)
	btn.tooltip_text = id_name.capitalize()
	var path := "%s%s.png" % [FLAG_DIR, FLAG_BY_CODE.get(code, "")]
	if ResourceLoader.exists(path):
		btn.set_flag(load(path))
	else:
		btn.text = code.to_upper()
	btn.pressed.connect(_on_flag_pressed.bind(code))
	_flag_grid.add_child(btn)
	_flag_buttons.append(btn)

func _sync_from_services() -> void:
	var audio := _audio()
	if audio == null:
		return
	_syncing = true
	_master_slider.value = audio.get_track_volume(AudioService.SoundTrack.Master)
	_music_slider.value = audio.get_track_volume(AudioService.SoundTrack.Music)
	_sfx_slider.value = audio.get_track_volume(AudioService.SoundTrack.Sfx)
	_ui_slider.value = audio.get_track_volume(AudioService.SoundTrack.UI)

	var eng := _engine()
	if eng:
		var localization := eng.get_service("Localization") as GnosisLocalizationService
		if localization:
			_highlight_language(localization.get_current_language())
	_sync_input_bindings()
	_populate_video_options()
	_populate_game_speed_options()
	_scanlines_slider.value = _read_setting_float(SCANLINES_KEY, 0.0)
	_vignette_slider.value = _read_setting_float(VIGNETTE_INTENSITY_KEY, 0.0)
	_crt_filter_toggle.set_pressed_silent(_read_setting_bool(CRT_FILTER_ENABLED_KEY, false))
	_update_filter_interaction(_crt_filter_toggle.button_pressed)
	_vsync_toggle.set_pressed_silent(_read_setting_bool(VSYNC_KEY, true))
	_update_framerate_cap_interaction(_vsync_toggle.button_pressed)
	_window_mode_option.select(clampi(_read_setting_int(WINDOW_MODE_KEY, 2), 0, max(0, _window_mode_option.item_count - 1)))
	_framerate_option.select(_framerate_index_from_cap(_read_setting_int(FRAMERATE_CAP_KEY, 0)))
	_resolution_option.select(clampi(_read_setting_int(RESOLUTION_INDEX_KEY, 0), 0, max(0, _resolution_option.item_count - 1)))
	_refresh_option.select(clampi(_read_setting_int(REFRESH_RATE_INDEX_KEY, 0), 0, max(0, _refresh_option.item_count - 1)))
	_monitor_option.select(clampi(_read_setting_int(DISPLAY_INDEX_KEY, 0), 0, max(0, _monitor_option.item_count - 1)))
	_vibration_toggle.set_pressed_silent(_read_haptics_enabled())
	_game_speed_option.select(_read_game_speed_index())
	_log_level_option.select(_read_log_level_index())
	_show_fps_toggle.set_pressed_silent(_read_setting_bool(SHOW_FPS_KEY, false))
	_show_version_toggle.set_pressed_silent(_read_setting_bool(SHOW_VERSION_KEY, false))
	_show_device_info_toggle.set_pressed_silent(_read_setting_bool(SHOW_DEVICE_INFO_KEY, false))
	_enable_console_toggle.set_pressed_silent(_read_setting_bool(ENABLE_CONSOLE_KEY, false))
	_syncing = false

func _read_haptics_enabled() -> bool:
	var eng := _engine()
	if not eng:
		return true
	var node := eng.state.root.get_node("Persistent.haptic.hapticsEnabled")
	if node.is_valid() and node.value != null:
		return bool(node.value)
	return true

func _set_haptics_enabled(enabled: bool) -> void:
	if _syncing:
		return
	var setting := _setting()
	var eng := _engine()
	if setting == null or eng == null:
		return
	var args := eng.store.create_object()
	args.set_key("key", HAPTICS_ENABLED_KEY)
	args.set_key("value", enabled)
	setting.set_bool(args)

func _on_vsync_toggled(enabled: bool) -> void:
	_set_setting_bool(VSYNC_KEY, enabled)
	_update_framerate_cap_interaction(enabled)

func _on_crt_filter_toggled(enabled: bool) -> void:
	_set_setting_bool(CRT_FILTER_ENABLED_KEY, enabled)
	_update_filter_interaction(enabled)

## Master switch for the CRT overlay; scanline/vignette sliders are dimmed while off.
func _update_filter_interaction(filter_on: bool) -> void:
	var dimmed := Color(1, 1, 1, 0.45) if not filter_on else Color.WHITE
	_scanlines_slider.modulate = dimmed
	_vignette_slider.modulate = dimmed
	_scanlines_slider.editable = filter_on
	_vignette_slider.editable = filter_on

## V-Sync caps the frame rate to the display refresh, so the framerate-cap
## dropdown is meaningless while it is on (same behaviour as the Unity build).
func _update_framerate_cap_interaction(vsync_on: bool) -> void:
	_framerate_row.modulate = Color(1, 1, 1, 0.45) if vsync_on else Color.WHITE
	_framerate_option.disabled = vsync_on

func _on_vibration_toggled(enabled: bool) -> void:
	_set_haptics_enabled(enabled)

func _read_game_speed_index() -> int:
	var speed := _read_setting_int(GAME_SPEED_KEY, 1)
	return clampi(speed - 1, 0, max(0, _game_speed_option.item_count - 1))

func _on_game_speed_selected(index: int) -> void:
	_set_setting_dropdown(GAME_SPEED_KEY, index)

func _read_setting_bool(key: String, default_value: bool) -> bool:
	var eng := _engine()
	if not eng:
		return default_value
	var node := eng.state.root.get_node("Persistent.%s" % key)
	if node.is_valid() and node.value != null:
		return bool(node.value)
	return default_value

func _set_setting_bool(key: String, enabled: bool) -> void:
	if _syncing:
		return
	var setting := _setting()
	var eng := _engine()
	if setting == null or eng == null:
		return
	var args := eng.store.create_object()
	args.set_key("key", key)
	args.set_key("value", enabled)
	setting.set_bool(args)

func _read_setting_int(key: String, default_value: int) -> int:
	var eng := _engine()
	if not eng:
		return default_value
	var node := eng.state.root.get_node("Persistent.%s" % key)
	if node.is_valid() and node.value != null and typeof(node.value) in [TYPE_INT, TYPE_FLOAT]:
		return int(node.value)
	return default_value

func _read_setting_float(key: String, default_value: float) -> float:
	var eng := _engine()
	if not eng:
		return default_value
	var node := eng.state.root.get_node("Persistent.%s" % key)
	if node.is_valid() and node.value != null and typeof(node.value) in [TYPE_INT, TYPE_FLOAT]:
		return float(node.value)
	return default_value

func _settings_list(leaf: String) -> GnosisNode:
	var eng := _engine()
	if not eng:
		return GnosisNode.new(null)
	return eng.state.root.get_node("Persistent.settings.%s" % leaf)

func _framerate_index_from_cap(cap: int) -> int:
	var caps := _settings_list("framerateOptionLabels")
	if caps.is_valid() and caps.get_type() == GnosisValueType.LIST:
		for i in range(caps.get_count()):
			if str(caps.get_node(i).value) == str(cap):
				return i
	return 0

func _set_setting_slider(key: String, value: float) -> void:
	if _syncing:
		return
	var setting := _setting()
	var eng := _engine()
	if setting == null or eng == null:
		return
	var args := eng.store.create_object()
	args.set_key("key", key)
	args.set_key("value", value)
	setting.set_slider(args)

func _set_setting_dropdown(key: String, index: int) -> void:
	if _syncing:
		return
	var setting := _setting()
	var eng := _engine()
	if setting == null or eng == null:
		return
	var args := eng.store.create_object()
	args.set_key("key", key)
	args.set_key("index", index)
	setting.set_dropdown(args)

func _read_log_level_index() -> int:
	var eng := _engine()
	if not eng:
		return DEFAULT_LOG_LEVEL_INDEX
	var node := eng.state.root.get_node("Persistent.%s" % LOG_LEVEL_KEY)
	if node.is_valid() and node.value != null:
		var stored := str(node.value)
		var idx := LOG_LEVEL_VALUES.find(stored.to_lower())
		if idx >= 0:
			return idx
	return DEFAULT_LOG_LEVEL_INDEX

func _on_log_level_selected(index: int) -> void:
	if _syncing:
		return
	var setting := _setting()
	var eng := _engine()
	if setting == null or eng == null:
		return
	var args := eng.store.create_object()
	args.set_key("key", LOG_LEVEL_KEY)
	args.set_key("index", index)
	setting.set_dropdown(args)

func _input_service() -> GnosisInputService:
	var eng := _engine()
	return eng.get_service("Input") as GnosisInputService if eng else null

func _unhandled_input(event: InputEvent) -> void:
	if _capturing_action.is_empty():
		return
	if _capturing_scheme == "keyboard":
		if not (event is InputEventKey):
			return
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE:
			_cancel_capture()
		else:
			_assign_keyboard(_capturing_action, key_event)
		get_viewport().set_input_as_handled()
	elif _capturing_scheme == "gamepad":
		if not (event is InputEventJoypadButton):
			return
		var button_event := event as InputEventJoypadButton
		if not button_event.pressed or button_event.echo:
			return
		if button_event.button_index == JOY_BUTTON_B:
			_cancel_capture()
		else:
			_assign_gamepad(_capturing_action, button_event.button_index)
		get_viewport().set_input_as_handled()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_input_device_tabs()

func _has_keyboard_mouse() -> bool:
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		return true
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return true
	return OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "Web"]

func _has_gamepad() -> bool:
	return Input.get_connected_joypads().size() > 0

## Keeps the top-level Keyboard/Gamepad tabs in sync with attached hardware:
## the keyboard tab shows whenever a keyboard/mouse is present, the gamepad tab
## only while a controller is connected. If the active tab disappears (e.g. the
## controller is unplugged), fall back to a sensible still-visible tab.
func _refresh_input_device_tabs() -> void:
	var has_keyboard := _has_keyboard_mouse()
	var has_gamepad := _has_gamepad()
	_input_tab.visible = has_keyboard
	_gamepad_tab.visible = has_gamepad
	_no_input_devices_label.visible = false

	if _current_tab == "controls" and not has_keyboard:
		_show_tab("gamepad" if has_gamepad else "audio")
	elif _current_tab == "gamepad" and not has_gamepad:
		_show_tab("controls" if has_keyboard else "audio")

func _set_capture_status_idle() -> void:
	if _capture_status:
		if _has_keyboard_mouse():
			_capture_status.text = tr("ultravibe__settings__inputPromptKeyboard")
		else:
			_capture_status.text = tr("ultravibe__settings__noInputDevices")
	if _gamepad_capture_status:
		_gamepad_capture_status.text = tr("ultravibe__settings__inputPromptGamepad")

func _populate_input_bindings() -> void:
	_populate_keyboard_bindings()
	_populate_gamepad_bindings()

func _populate_keyboard_bindings() -> void:
	_populate_binding_grid(_keyboard_grid, _keyboard_buttons, "keyboard", false)
	_sync_keyboard_bindings()

func _populate_gamepad_bindings() -> void:
	_populate_binding_grid(_gamepad_grid, _gamepad_buttons, "gamepad", true)
	_sync_gamepad_bindings()

## Rebuilds a 2-column rebind grid, inserting a section header above each
## category group (gameplay / interface / console) so the rows read as labelled,
## divided sections rather than one long undifferentiated list.
func _populate_binding_grid(grid: GridContainer, buttons: Dictionary, scheme: String, skip_keyboard_only: bool) -> void:
	for child in grid.get_children():
		child.queue_free()
	buttons.clear()
	for group in _actions_grouped_by_category(skip_keyboard_only):
		grid.add_child(_make_section_header(str(group["category"])))
		grid.add_child(_make_grid_filler())
		for action_name in group["actions"]:
			var label := _make_binding_label(str(_input_bindings()[action_name]["label"]))
			grid.add_child(label)
			var button := _make_binding_button()
			if scheme == "gamepad":
				button.pressed.connect(_begin_gamepad_capture.bind(action_name))
			else:
				button.pressed.connect(_begin_keyboard_capture.bind(action_name))
			grid.add_child(button)
			buttons[action_name] = button

## Groups bindings by category in [constant CATEGORY_ORDER], preserving each
## action's natural order within its group. Returns an Array of
## { "category": String, "actions": Array[String] }; empty groups are omitted.
func _actions_grouped_by_category(skip_keyboard_only: bool) -> Array:
	var by_cat := {}
	for action_name in _input_bindings().keys():
		if skip_keyboard_only and _is_keyboard_only_binding(action_name):
			continue
		var cat := str(_input_bindings()[action_name].get("category", "gameplay"))
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(action_name)
	var ordered: Array = []
	var seen := {}
	for cat in CATEGORY_ORDER:
		if by_cat.has(cat):
			ordered.append({"category": cat, "actions": by_cat[cat]})
			seen[cat] = true
	for cat in by_cat.keys():
		if not seen.has(cat):
			ordered.append({"category": cat, "actions": by_cat[cat]})
	return ordered

## Accent section header spanning the label column; the trailing top margin
## visually separates each category group from the rows above it.
func _make_section_header(category: String) -> Label:
	var key := str(CATEGORY_LABELS.get(category, ""))
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.345098, 0.345098, 0.572549))
	label.text = tr(key) if not key.is_empty() else category.capitalize()
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.custom_minimum_size = Vector2(280, 58)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

## Empty cell occupying the button column of a header row so the next binding
## row starts cleanly in column 1.
func _make_grid_filler() -> Control:
	var filler := Control.new()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return filler

## Row label that expands to absorb the slack, pushing the rebind button to the
## right edge of the row (so it reads as "label .... button").
func _make_binding_label(text: String) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(280, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.text = tr(text)
	return label

## Builds an animated rebind button (same juice/focus visuals as the tabs),
## with its caption centered. A fixed medium width pinned to the right edge of
## the row, so the row reads as "label ........ button".
func _make_binding_button() -> RoundedSquareBtn:
	var button: RoundedSquareBtn = RoundedSquareBtnScene.instantiate()
	button.custom_minimum_size = Vector2(360, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.scale_w_width = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return button

func _sync_input_bindings() -> void:
	_sync_keyboard_bindings()
	_sync_gamepad_bindings()

func _sync_keyboard_bindings() -> void:
	for action_name in _input_bindings().keys():
		var button := _keyboard_buttons.get(action_name) as Button
		if button:
			button.text = _current_keyboard_display(action_name)

func _sync_gamepad_bindings() -> void:
	for action_name in _input_bindings().keys():
		var button := _gamepad_buttons.get(action_name) as Button
		if button:
			button.text = _current_gamepad_display(action_name)

func _begin_keyboard_capture(action_name: String) -> void:
	_capturing_action = action_name
	_capturing_scheme = "keyboard"
	var label := str(_input_bindings()[action_name]["label"])
	_capture_status.text = tr("ultravibe__settings__pressKeyForAction") % tr(label)

func _begin_gamepad_capture(action_name: String) -> void:
	_capturing_action = action_name
	_capturing_scheme = "gamepad"
	var label := str(_input_bindings()[action_name]["label"])
	_gamepad_capture_status.text = tr("ultravibe__settings__pressButtonForAction") % tr(label)

func _cancel_capture() -> void:
	_capturing_action = ""
	_capturing_scheme = ""
	_set_capture_status_idle()

func _assign_keyboard(action_name: String, event: InputEventKey) -> void:
	var input := _input_service()
	var eng := _engine()
	if input == null or eng == null:
		return
	var assignments := _copy_assignments(input.get_assignments_snapshot())
	var entry := _assignment_entry(assignments, action_name, eng)
	entry.set_key("keycode", int(event.keycode))
	entry.set_key("physicalKeycode", int(event.physical_keycode if event.physical_keycode != 0 else event.keycode))
	entry.set_key("ctrl", event.ctrl_pressed)
	entry.set_key("shift", event.shift_pressed)
	entry.set_key("alt", event.alt_pressed)
	entry.set_key("meta", event.meta_pressed)
	entry.set_key("displayName", _format_keyboard_display(event))
	assignments.set_key(action_name, entry)
	input.update_assignments(assignments)
	_capturing_action = ""
	_capturing_scheme = ""
	_capture_status.text = tr("ultravibe__settings__keyboardAssigned") % [
		tr(str(_input_bindings()[action_name]["label"])),
		_current_keyboard_display(action_name)
	]
	_sync_keyboard_bindings()
	_set_capture_status_idle()

func _assign_gamepad(action_name: String, button_index: int) -> void:
	var input := _input_service()
	var eng := _engine()
	if input == null or eng == null:
		return
	var assignments := _copy_assignments(input.get_assignments_snapshot())
	var entry := _assignment_entry(assignments, action_name, eng)
	entry.set_key("gamepadButton", button_index)
	entry.set_key("gamepadDisplayName", _joy_button_label(button_index))
	assignments.set_key(action_name, entry)
	input.update_assignments(assignments)
	_capturing_action = ""
	_capturing_scheme = ""
	_gamepad_capture_status.text = tr("ultravibe__settings__gamepadAssigned") % [
		tr(str(_input_bindings()[action_name]["label"])),
		_current_gamepad_display(action_name)
	]
	_sync_gamepad_bindings()
	_set_capture_status_idle()

func _reset_keyboard_defaults() -> void:
	var input := _input_service()
	var eng := _engine()
	if input == null or eng == null:
		return
	var assignments := _copy_assignments(input.get_assignments_snapshot())
	for action_name in _input_bindings().keys():
		var spec: Dictionary = _input_bindings()[action_name]
		var entry := _assignment_entry(assignments, action_name, eng)
		entry.set_key("keycode", int(spec.get("keycode", 0)))
		entry.set_key("physicalKeycode", int(spec.get("physicalKeycode", spec.get("keycode", 0))))
		entry.set_key("ctrl", bool(spec.get("ctrl", false)))
		entry.set_key("shift", bool(spec.get("shift", false)))
		entry.set_key("alt", bool(spec.get("alt", false)))
		entry.set_key("meta", bool(spec.get("meta", false)))
		var display := GnosisConsoleInputActions.default_keyboard_display(action_name) \
			if GnosisConsoleInputActions.BINDINGS.has(action_name) \
			else OS.get_keycode_string(int(spec.get("keycode", 0)))
		entry.set_key("displayName", display)
		assignments.set_key(action_name, entry)
	input.update_assignments(assignments)
	_cancel_capture()
	_capture_status.text = tr("ultravibe__settings__keyboardDefaultsRestored")
	_sync_keyboard_bindings()
	_set_capture_status_idle()

func _reset_gamepad_defaults() -> void:
	var input := _input_service()
	var eng := _engine()
	if input == null or eng == null:
		return
	var assignments := _copy_assignments(input.get_assignments_snapshot())
	for action_name in _input_bindings().keys():
		if _is_keyboard_only_binding(action_name):
			continue
		var spec: Dictionary = _input_bindings()[action_name]
		var button_index := int(spec["gamepadButton"])
		var entry := _assignment_entry(assignments, action_name, eng)
		entry.set_key("gamepadButton", button_index)
		entry.set_key("gamepadDisplayName", _joy_button_label(button_index))
		assignments.set_key(action_name, entry)
	input.update_assignments(assignments)
	_cancel_capture()
	_gamepad_capture_status.text = tr("ultravibe__settings__gamepadDefaultsRestored")
	_sync_gamepad_bindings()
	_set_capture_status_idle()

func _assignment_entry(assignments: GnosisNode, action_name: String, eng: GnosisEngine) -> GnosisNode:
	var entry := assignments.get_node(action_name)
	if entry.is_valid() and entry.get_type() == GnosisValueType.OBJECT:
		return entry
	return eng.store.create_object()

func _copy_assignments(source: GnosisNode) -> GnosisNode:
	var eng := _engine()
	var copy := eng.store.create_object()
	if source.is_valid() and source.get_type() == GnosisValueType.OBJECT:
		for key in source.get_keys():
			copy.set_key(str(key), source.get_node(key))
	return copy

func _current_keyboard_display(action_name: String) -> String:
	var assignments := _input_service().get_assignments_snapshot() if _input_service() else GnosisNode.new(null)
	var entry := assignments.get_node(action_name)
	if entry.is_valid() and entry.get_type() == GnosisValueType.OBJECT:
		var display := _node_str(entry, "displayName")
		if not display.is_empty():
			return display
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			return _format_keyboard_display(event as InputEventKey)
	return "UNBOUND"

func _is_keyboard_only_binding(action_name: String) -> bool:
	return bool(_input_bindings().get(action_name, {}).get("keyboardOnly", false))

func _format_keyboard_display(event: InputEventKey) -> String:
	var parts: PackedStringArray = []
	if event.ctrl_pressed:
		parts.append("Ctrl")
	if event.shift_pressed:
		parts.append("Shift")
	if event.alt_pressed:
		parts.append("Alt")
	if event.meta_pressed:
		parts.append("Meta")
	var code := event.keycode if event.keycode != 0 else event.physical_keycode
	parts.append(OS.get_keycode_string(code))
	return "+".join(parts)

func _current_gamepad_display(action_name: String) -> String:
	var assignments := _input_service().get_assignments_snapshot() if _input_service() else GnosisNode.new(null)
	var entry := assignments.get_node(action_name)
	if entry.is_valid() and entry.get_type() == GnosisValueType.OBJECT:
		var display := _node_str(entry, "gamepadDisplayName")
		if not display.is_empty():
			return display
		var button_index := _node_int(entry, "gamepadButton", -1)
		if button_index >= 0:
			return _joy_button_label(button_index)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			return _joy_button_label((event as InputEventJoypadButton).button_index)
	return "UNBOUND"

func _joy_button_label(button_index: int) -> String:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event.as_text()

func _node_str(node: GnosisNode, key: String) -> String:
	var child := node.get_node(key)
	if child.is_valid() and child.value != null:
		return str(child.value)
	return ""

func _node_int(node: GnosisNode, key: String, fallback: int) -> int:
	var child := node.get_node(key)
	if child.is_valid() and child.value != null and typeof(child.value) in [TYPE_INT, TYPE_FLOAT]:
		return int(child.value)
	return fallback

func _highlight_language(code: String) -> void:
	for i in range(_flag_buttons.size()):
		if i >= _language_codes.size():
			break
		var btn := _flag_buttons[i] as LanguageFlagButton
		if btn:
			btn.selected = _language_codes[i] == code

func _set_volume(track: int, value: float) -> void:
	if _syncing:
		return
	var audio := _audio()
	if audio:
		audio.set_track_volume(track, value)

func _on_master_changed(value: float) -> void:
	_set_volume(AudioService.SoundTrack.Master, value)

func _on_music_changed(value: float) -> void:
	_set_volume(AudioService.SoundTrack.Music, value)

func _on_sfx_changed(value: float) -> void:
	_set_volume(AudioService.SoundTrack.Sfx, value)

func _on_ui_changed(value: float) -> void:
	_set_volume(AudioService.SoundTrack.UI, value)

func _on_flag_pressed(code: String) -> void:
	if _syncing:
		return
	var eng := _engine()
	if not eng:
		return
	var localization := eng.get_service("Localization") as GnosisLocalizationService
	if localization:
		localization.set_language(code)
		_highlight_language(code)

func _on_back_pressed() -> void:
	var ui := _game_ui()
	var eng := _engine()
	if ui == null or eng == null:
		return
	UltraGameUiNav.pop_menu_back(ui, eng.store, "slide_right")
