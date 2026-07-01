class_name Match3Hud
extends Control

## Match-3 gameplay HUD. The left sidebar mirrors the Unity MainHud: boss/level
## card, stacked round total + last-match score, points x multi, round/moves/cycles/money,
## home/settings/wiki/shuffle action buttons. Values are pulled from Match3Service
## via refresh_from_service() (driven by the dispatcher on board reset/change).

const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const UltraGameUiNav = preload("res://game/ui/ultra_game_ui_nav.gd")
## Boss letter token font — mirrors the collection view boss tokens.
const TOKEN_FONT_PATH := "res://assets/fonts/PolygonParty-3KXM.ttf"
const TOKEN_DEFAULT_BG := Color(0.0980392, 0.156863, 0.227451)

## Group used by subscreen overlays (shop / level select / reward) to find this
## HUD and query the shared content frame.
const HUD_GROUP := "match3_hud"
## Uniform gap between the content frame and the sidebars (and between cards).
const FRAME_GAP := 32.0

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
@onready var _cycles_value: Label = %CyclesValue
@onready var _money_value: Label = %MoneyValue
@onready var _shuffle_count: Label = %ShuffleCount
@onready var _status_label: Label = %StatusLabel
@onready var _home_button: Button = %HomeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _wiki_button: Button = %WikiButton
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _boss_section: PanelContainer = %BossSection
@onready var _boons_bar: PanelContainer = %BoonsBar
@onready var _score_section: PanelContainer = %ScoreSection
@onready var _consumables_bar: PanelContainer = %ConsumablesBar
@onready var _board_host: Control = %BoardHost

var _service = null


func _ready() -> void:
	add_to_group(HUD_GROUP)
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
	if _boss_section:
		_boss_section.resized.connect(_on_frame_dirty)
	if _score_section:
		_score_section.resized.connect(_on_frame_dirty)
	if _boons_bar:
		_boons_bar.resized.connect(_on_frame_dirty)
	resized.connect(_on_frame_dirty)
	_on_frame_dirty.call_deferred()


## Re-runs sidebar + content-frame layout (e.g. after a subscreen overlay opens).
func relayout_content_frame() -> void:
	call_deferred("_on_frame_dirty")


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
	if _last_match_value:
		_last_match_value.text = _format_score(_service.get_last_move_score())
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


## Global rect of the shared subscreen content frame: spans the gap between the
## main sidebar panel and the consumable sidebar, with the height of the main
## sidebar panel. All subscreens (level select / reward) fill this.
func get_content_frame_rect() -> Rect2:
	if _score_section == null:
		return Rect2()
	var panel := _score_section.get_global_rect()
	var left := panel.position.x + panel.size.x + FRAME_GAP
	var top := panel.position.y
	var bottom := panel.position.y + panel.size.y
	var right := size.x - FRAME_GAP
	if _consumables_bar:
		right = _consumables_bar.get_global_rect().position.x - FRAME_GAP
	return Rect2(left, top, maxf(0.0, right - left), maxf(0.0, bottom - top))


## Level-select / shop planning region: same top and width as the main sidebar
## stats panel, but extends to the bottom of the HUD so the shop can use the
## vertical strip above the sidebar button row.
func get_planning_frame_rect() -> Rect2:
	var frame := get_content_frame_rect()
	if frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return frame
	var bottom := size.y - FRAME_GAP
	return Rect2(frame.position.x, frame.position.y, frame.size.x, maxf(0.0, bottom - frame.position.y))


## Play-field rect for the match-3 board: same horizontal bounds as
## get_content_frame_rect() but extends to the bottom of the HUD.
func get_board_frame_rect() -> Rect2:
	var frame := get_content_frame_rect()
	if frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return frame
	var bottom := size.y - FRAME_GAP
	return Rect2(frame.position.x, frame.position.y, frame.size.x, maxf(0.0, bottom - frame.position.y))


## Keeps the boons strip and consumable sidebar aligned with the main sidebar
## panels, then notifies overlays the frame may have moved.
func _on_frame_dirty() -> void:
	if _boss_section and _boons_bar:
		var boss_rect := _boss_section.get_global_rect()
		if boss_rect.size.y > 0.0:
			var frame := get_content_frame_rect()
			_boons_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
			var bar_pos := Vector2(boss_rect.end.x + FRAME_GAP, boss_rect.position.y)
			var bar_size := Vector2(_boons_bar.size.x, boss_rect.size.y)
			if frame.size.x > 0.0:
				bar_pos.x = frame.position.x
				bar_size.x = frame.size.x
			_boons_bar.position = bar_pos
			_boons_bar.size = bar_size
	if _consumables_bar and _score_section:
		var panel := _score_section.get_global_rect()
		# Skip while the sidebar panel has not been laid out yet, otherwise we
		# would collapse the consumable sidebar to zero height (it never recovers
		# during PLAYING because nothing re-triggers a resize).
		if panel.size.y > 0.0:
			_consumables_bar.offset_top = panel.position.y
			_consumables_bar.offset_bottom = panel.position.y + panel.size.y - size.y
	# Keep the board area on the exact same rect the subscreen overlays use, so
	# the board fills the level-select / reward region.
	if _board_host:
		var frame := get_board_frame_rect()
		if frame.size.x > 0.0 and frame.size.y > 0.0:
			_board_host.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_board_host.position = frame.position
			_board_host.size = frame.size
	content_frame_changed.emit()
