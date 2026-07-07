class_name UltravibeModsView
extends "res://addons/com.gnosisgames.gnosisengine/adapters/godot/mods/gnosis_mods_view.gd"

## Ultravibe skin for the engine mods browser.

const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")
const BODY_FONT := preload("res://assets/fonts/Inter-Regular.ttf")
const BODY_FONT_PATH := "res://assets/fonts/Inter-Regular.ttf"
const ModListItemButtonScript := preload("res://game/ui/widgets/mod_list_item_button.gd")
const UltravibeModSettingsBuilder := preload("res://game/ui/ultravibe_mod_settings_builder.gd")

func _ready() -> void:
	i18n_prefix = "ultravibe__mods__"
	title_i18n_key = "ultravibe__ui__mods"
	list_item_script = ModListItemButtonScript
	super._ready()

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
