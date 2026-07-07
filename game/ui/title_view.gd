class_name UltravibeTitleView
extends GnosisUIElementView

## Main menu / title screen. Ported from the Unity TitleView prefab (viewId "title"):
## logo + menu buttons that drive the GameUI navigation state.

@onready var _play_button: Button = %PlayButton
@onready var _continue_button: Button = %ContinueButton
@onready var _collection_button: Button = %CollectionButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _btn_container: Container = $Center/Menu/BtnContainers
@onready var _mods_button: Button = %ModsButton
@onready var _web_button: Button = %WebButton
@onready var _discord_button: Button = %DiscordButton
@onready var _credits_button: Button = %CreditsButton

var _host: GnosisGodotEngine = null

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		_ensure_menu_buttons_visible()
		_refresh_continue_button()

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
			return
		node = node.get_parent()

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
