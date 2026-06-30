class_name Match3Hud
extends Control

## Match-3 gameplay HUD. The left sidebar mirrors the Unity MainHud: boss/level
## card, total score, points x multi, round/moves/cycles/money, and the
## home/settings/wiki/shuffle action buttons. Values are pulled from Match3Service
## via refresh_from_service() (driven by the dispatcher on board reset/change).

const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
## Boss letter token font — mirrors the collection view boss tokens.
const TOKEN_FONT_PATH := "res://assets/fonts/PolygonParty-3KXM.ttf"
const TOKEN_DEFAULT_BG := Color(0.0980392, 0.156863, 0.227451)

@onready var _level_token_panel: PanelContainer = %LevelTokenPanel
@onready var _level_token: Label = %LevelToken
@onready var _level_name: Label = %LevelName
@onready var _level_desc: Label = %LevelDesc
@onready var _req_score_value: Label = %ReqScoreValue
@onready var _total_value: Label = %TotalValue
@onready var _points_value: Label = %PointsValue
@onready var _multi_value: Label = %MultiValue
@onready var _round_value: Label = %RoundValue
@onready var _moves_value: Label = %MovesValue
@onready var _cycles_value: Label = %CyclesValue
@onready var _money_value: Label = %MoneyValue
@onready var _shuffle_count: Label = %ShuffleCount
@onready var _status_label: Label = %StatusLabel
@onready var _home_button: Button = %HomeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _wiki_button: Button = %WikiButton
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _buttons_row: HBoxContainer = %ButtonsRow

var _service = null


func _ready() -> void:
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
	if _buttons_row:
		_buttons_row.resized.connect(_layout_action_buttons)
		_layout_action_buttons.call_deferred()


func bind_service(service) -> void:
	_service = service
	refresh_from_service(service)


func refresh_from_service(service = null) -> void:
	if service:
		_service = service
	if _service == null:
		return
	var gameplay = _service.get_gameplay()
	if _total_value:
		_total_value.text = _format_score(gameplay.current_score)
	if _req_score_value:
		_req_score_value.text = _format_score(gameplay.target_score)
	if _moves_value:
		_moves_value.text = str(gameplay.current_moves)
	if _round_value:
		_round_value.text = str(_service.get_current_round())
	if _points_value:
		_points_value.text = str(_service.get_step_points())
	if _multi_value:
		_multi_value.text = str(_service.get_step_multi())
	if _cycles_value:
		_cycles_value.text = "%d/%d" % [_service.get_round_in_floor(), _service.get_rounds_per_floor()]
	if _money_value:
		_money_value.text = "$%d" % _service.get_money()
	if _shuffle_count:
		_shuffle_count.text = str(_service.get_shuffles_remaining())
	_apply_level_meta(_service.get_active_level_meta())
	if _status_label:
		_status_label.text = _status_text(gameplay.status)


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
	if _level_token:
		_level_token.text = letter
		_level_token.add_theme_color_override("font_color", fg)
	if _level_token_panel:
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.set_corner_radius_all(14)
		_level_token_panel.add_theme_stylebox_override("panel", box)


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
	if ui and ui.has_method("set_base_view"):
		ui.set_base_view("title")


func _on_settings_pressed() -> void:
	var ui = _game_ui()
	if ui and ui.has_method("set_base_view"):
		ui.set_base_view("settings")


func _on_wiki_pressed() -> void:
	var ui = _game_ui()
	if ui and ui.has_method("set_base_view"):
		ui.set_base_view("collection")


func _on_shuffle_pressed() -> void:
	if _service and _service.has_method("invoke_function"):
		_service.invoke_function("TryUseShuffle", null)


## Sizes the action buttons so they always span the full sidebar width, splitting
## the row evenly regardless of how many buttons exist, and keeps each one square
## by driving its height from the computed per-button width.
func _layout_action_buttons() -> void:
	if _buttons_row == null:
		return
	var buttons: Array = []
	for child in _buttons_row.get_children():
		if child is Control and (child as Control).visible:
			buttons.append(child)
	var count := buttons.size()
	if count == 0:
		return
	var separation := float(_buttons_row.get_theme_constant("separation"))
	var total_width := _buttons_row.size.x
	var button_size := (total_width - separation * float(count - 1)) / float(count)
	if button_size <= 0.0:
		return
	for button in buttons:
		var control := button as Control
		control.custom_minimum_size = Vector2(0.0, button_size)
