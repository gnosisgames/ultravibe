class_name UltravibeTitleView
extends GnosisUIElementView

const UltraAchievementProgress = preload("res://game/ui/ultra_achievement_progress.gd")

## Main menu / title screen. Ported from the Unity TitleView prefab (viewId "title"):
## logo + menu buttons that drive the GameUI navigation state.

@onready var _play_button: Button = %PlayButton
@onready var _continue_button: Button = %ContinueButton
@onready var _collection_button: Button = %CollectionButton
@onready var _profiles_button: Button = %ProfilesButton
@onready var _achievements_button: Button = %AchievementsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _btn_container: Container = $Center/Menu/BtnContainers
@onready var _footer_tools: Container = $FooterTools
@onready var _footer_links: Container = $FooterLinks
@onready var _mods_button: Button = %ModsButton
@onready var _web_button: Button = %WebButton
@onready var _discord_button: Button = %DiscordButton
@onready var _credits_button: Button = %CreditsButton

var _host: GnosisGodotEngine = null
var _played_footer_entrance := false
var _achievements_counter: Label = null

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		_ensure_menu_buttons_visible()
		if not _played_footer_entrance:
			_play_footer_entrance()
			_played_footer_entrance = true
		else:
			_ensure_footer_buttons_visible()
		_refresh_continue_button()
		_refresh_achievement_counter()

func _ensure_footer_buttons_visible() -> void:
	_reset_footer_children_visible(_footer_tools)
	_reset_footer_children_visible(_footer_links)

func _reset_footer_children_visible(container: Container) -> void:
	if container == null:
		return
	for child in container.get_children():
		if child is Control:
			var c := child as Control
			c.scale = Vector2.ONE
			c.modulate.a = 1.0

func _play_footer_entrance() -> void:
	for container in [_footer_tools, _footer_links]:
		if container == null:
			continue
		var tween := container.get_meta("container_tween", null) as ContainerTween
		if tween:
			tween.appear()

func _ensure_menu_buttons_visible() -> void:
	if _btn_container == null:
		return
	for child in _btn_container.get_children():
		if child is Control:
			var c := child as Control
			c.scale = Vector2.ONE
			c.modulate.a = 1.0

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_play_button.pressed.connect(_on_play_pressed)
	if _continue_button:
		_continue_button.pressed.connect(_on_continue_pressed)
	_collection_button.pressed.connect(_on_collection_pressed)
	if _profiles_button:
		_profiles_button.pressed.connect(_on_profiles_pressed)
	if _achievements_button:
		_achievements_button.pressed.connect(_on_achievements_pressed)
		_achievements_counter = _create_achievement_counter_badge(_achievements_button)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_mods_button.pressed.connect(_on_mods_pressed)
	_web_button.pressed.connect(_on_web_pressed)
	_discord_button.pressed.connect(_on_discord_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	call_deferred("_resolve_host")

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			_refresh_achievement_counter()
			return
		node = node.get_parent()

func _achievement_service():
	if _host and _host.engine:
		return _host.engine.get_service("Achievement")
	return null

func _refresh_achievement_counter() -> void:
	if _achievements_counter == null:
		return
	_achievements_counter.text = UltraAchievementProgress.label(_achievement_service())

func _create_achievement_counter_badge(button: Button) -> Label:
	var button_size := button.custom_minimum_size
	if button_size == Vector2.ZERO:
		button_size = Vector2(96, 76)

	var label := Label.new()
	label.name = "AchievementCounter"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -button_size.x * 0.5
	label.offset_top = -26.0
	label.offset_right = button_size.x * 0.5
	label.offset_bottom = -4.0
	label.z_index = 1
	UltraAchievementProgress.apply_title_style(label)
	button.add_child(label)
	return label

func _game_ui() -> GnosisGameUIService:
	if _host and _host.engine:
		return _host.engine.get_service("GameUI") as GnosisGameUIService
	return null

func _navigate(view_id: String, transition_id: String) -> void:
	var ui := _game_ui()
	if ui and _host and _host.engine:
		var params := _host.engine.store.create_object()
		params.set_key("viewId", view_id)
		params.set_key("transitionId", transition_id)
		params.set_key("inDuration", 0.35)
		params.set_key("outDuration", 0.35)
		ui.invoke_function("PushView", params)

func _on_play_pressed() -> void:
	_navigate("play", "slide_up")

func _refresh_continue_button() -> void:
	if _continue_button == null:
		return
	var has_save := GnosisRunSave.has_continuable_save()
	_continue_button.visible = has_save
	if has_save:
		_continue_button.call_deferred("grab_focus")
	elif _play_button:
		_play_button.call_deferred("grab_focus")

func _on_continue_pressed() -> void:
	if _host == null or _host.engine == null:
		return
	var runtime := _host.engine.get_service("Gnosis") as GnosisRuntimeService
	if runtime == null:
		return
	var result := runtime.continue_last_run()
	if not result.is_ok:
		_refresh_continue_button()
		return
	var ui := _game_ui()
	if ui:
		UltraGameUiNav.transition_to_gameplay(ui, _host.engine.store, "title", "slide_up")

func _on_mods_pressed() -> void:
	_navigate("mods", "slide_left")

func _on_collection_pressed() -> void:
	_navigate("collection", "slide_right")

func _on_profiles_pressed() -> void:
	if _host == null:
		return
	var ui := _game_ui()
	if ui and _host.engine:
		UltraGameUiNav.go_to_play_profiles(ui, _host.engine.store, "title", "slide_left")

func _on_achievements_pressed() -> void:
	if _host == null:
		return
	var ui := _game_ui()
	if ui and _host.engine:
		UltraGameUiNav.go_to_achievements(ui, _host.engine.store, "title", "slide_left")

func _on_settings_pressed() -> void:
	_navigate("settings", "slide_left")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_web_pressed() -> void:
	OS.shell_open("https://gnosisgames.eu")

func _on_discord_pressed() -> void:
	OS.shell_open("https://discord.gg/Fz7PCuRHuc")

func _on_credits_pressed() -> void:
	_navigate("credits", "slide_down")
