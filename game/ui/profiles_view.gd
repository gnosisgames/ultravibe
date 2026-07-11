class_name UltravibeProfilesView
extends "res://addons/com.gnosisgames.gnosisengine/adapters/godot/widgets/gnosis_profiles_view.gd"

const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")

func _ui_font() -> Font:
	return UI_FONT

func _panel_bg_color() -> Color:
	return Color(0.0980392, 0.156863, 0.227451, 1)

func _panel_border_color() -> Color:
	return Color(0.345098, 0.345098, 0.572549, 1)

func _panel_shadow_color() -> Color:
	return Color(0.0784314, 0.137255, 0.227451, 1)

func _stats_panel_bg_color() -> Color:
	return _panel_bg_color()

func _tab_idle_color() -> Color:
	return Color(0.345098, 0.345098, 0.572549, 1)

func _tab_border_color() -> Color:
	return Color(0.180392, 0.160784, 0.321569, 1)

func _title_outline_color() -> Color:
	return Color(0.345098, 0.345098, 0.572549, 1)

func _title_shadow_color() -> Color:
	return Color(0.192157, 0.192157, 0.270588, 1)

func _muted_label_color() -> Color:
	return Color(0.85, 0.9, 0.95, 1.0)

func _apply_panel_theme(force: bool = false) -> void:
	if not force and _panel_theme_id == "ultravibe":
		return
	_panel_theme_id = "ultravibe"
	if _card_panel:
		_card_panel.add_theme_stylebox_override("panel", _build_card_panel_style())
	if _stats_panel:
		_stats_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if _actions_divider:
		_actions_divider.color = _panel_border_color()

func _build_card_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.content_margin_left = 36.0
	box.content_margin_top = 30.0
	box.content_margin_right = 36.0
	box.content_margin_bottom = 30.0
	box.bg_color = _panel_bg_color()
	box.border_color = _panel_border_color()
	box.shadow_color = _panel_shadow_color()
	box.set_border_width_all(4)
	box.set_corner_radius_all(20)
	box.shadow_size = 1
	box.shadow_offset = Vector2(4, 6)
	return box

func _achievements_stat_enabled(_profile: Dictionary, _is_active: bool) -> bool:
	return true

func _get_extra_stat_a(_profile: Dictionary, _is_active: bool) -> Dictionary:
	return {"visible": false, "label_key": "", "value": ""}

func _get_extra_stat_b(profile: Dictionary, is_active: bool) -> Dictionary:
	return {
		"visible": true,
		"label_key": "ultravibe__profiles__stat_collection",
		"value": str(_collection_count(profile, is_active)),
	}

func _can_reset_profile(profile: Dictionary) -> bool:
	var is_active: bool = (
		_profile_svc != null
		and str(profile.get("id", "")) == str(_profile_svc.get_active_profile_id())
	)
	var persistent := _persistent_branch(profile, is_active)
	var achievement_count := 0
	var eng := _engine()
	if eng:
		var achievement_svc = eng.get_service("Achievement")
		if achievement_svc:
			achievement_count = achievement_svc.count_earned_in_persistent(persistent)
	return achievement_count > 0 or _collection_count(profile, is_active) > 0

func _reset_profile(_profile: Dictionary) -> void:
	super._reset_profile(_profile)

func _collection_count(profile: Dictionary, is_active: bool) -> int:
	var persistent := _persistent_branch(profile, is_active)
	var collection: Variant = persistent.get("collection", {})
	if not collection is Dictionary:
		return 0
	var discovered: Variant = collection.get("discovered", {})
	return discovered.size() if discovered is Dictionary else 0
