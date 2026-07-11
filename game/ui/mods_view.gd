class_name UltravibeModsView
extends "res://addons/com.gnosisgames.gnosisengine/adapters/godot/mods/gnosis_mods_view.gd"

## Ultravibe skin for the engine mods browser.

const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")
const BODY_FONT := preload("res://assets/fonts/Inter-Regular.ttf")
const BODY_FONT_PATH := "res://assets/fonts/Inter-Regular.ttf"
const ModListItemButtonScript := preload("res://game/ui/widgets/mod_list_item_button.gd")
const UltravibeModSettingsBuilder := preload("res://game/ui/ultravibe_mod_settings_builder.gd")
const EMPTY_ICON := "res://assets/icons/empty.png"

const PANEL_BG := Color(0.0980392, 0.156863, 0.227451, 1)
const PANEL_BORDER := Color(0.345098, 0.345098, 0.572549, 1)
const PANEL_SHADOW := Color(0.0784314, 0.137255, 0.227451, 1)
const MUTED_TEXT := Color(0.85, 0.85, 0.9, 1)

var _mods_card_theme_id: String = ""

func _ready() -> void:
	i18n_prefix = "ultravibe__mods__"
	title_i18n_key = "ultravibe__ui__mods"
	list_item_script = ModListItemButtonScript
	super._ready()

func _apply_card_theme(force: bool = false) -> void:
	if not force and _mods_card_theme_id == "ultravibe":
		return
	_mods_card_theme_id = "ultravibe"
	if _card == null:
		return
	_card.add_theme_stylebox_override("panel", _build_card_panel_style())

func _build_card_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.content_margin_left = 36.0
	box.content_margin_top = 30.0
	box.content_margin_right = 36.0
	box.content_margin_bottom = 30.0
	box.bg_color = PANEL_BG
	box.border_color = PANEL_BORDER
	box.shadow_color = PANEL_SHADOW
	box.set_border_width_all(4)
	box.set_corner_radius_all(20)
	box.shadow_size = 1
	box.shadow_offset = Vector2(4, 6)
	return box

func _create_settings_builder():
	var builder := UltravibeModSettingsBuilder.new()
	builder.label_font = UI_FONT
	return builder

func _resolve_ui_font() -> Font:
	return UI_FONT

func _resolve_body_text_font() -> Font:
	return BODY_FONT

func _resolve_changelog_body_font_path() -> String:
	return BODY_FONT_PATH

func _resolve_body_text_font_size() -> int:
	return 26

func _resolve_detail_name_font_size() -> int:
	return 42

func _resolve_detail_meta_font_size() -> int:
	return 21

func _resolve_body_text_font_weight() -> int:
	return 580

func _resolve_detail_name_font_weight() -> int:
	return 680

func _resolve_changelog_bold_font_weight() -> int:
	return 720

func _resolve_body_text_glyph_spacing() -> float:
	return -1.4

func _resolve_body_text_word_spacing() -> float:
	return -3.0

func _resolve_body_text_line_spacing() -> int:
	return 0

func _navigate_back() -> void:
	var ui := _game_ui()
	if ui and _host and _host.engine:
		if ui.get_navigation_history_count() > 0:
			super._navigate_back()
		else:
			UltraGameUiNav.return_to_title(ui)


func _empty_icon_path() -> String:
	return EMPTY_ICON

func _empty_tint() -> Color:
	return MUTED_TEXT
