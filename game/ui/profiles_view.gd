class_name UltravibeProfilesView
extends "res://addons/com.gnosisgames.gnosisengine/adapters/godot/widgets/gnosis_profiles_view.gd"

const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")

func _ui_font() -> Font:
	return UI_FONT

func _panel_bg_color() -> Color:
	return Color(0.071, 0.063, 0.122, 0.97)

func _panel_border_color() -> Color:
	return Color(0.42, 0.22, 0.62, 1.0)

func _panel_shadow_color() -> Color:
	return Color(0.08, 0.04, 0.12, 1.0)

func _stats_panel_bg_color() -> Color:
	return Color(0.08, 0.05, 0.12, 0.98)

func _tab_idle_color() -> Color:
	return Color(0.34, 0.20, 0.52, 1.0)

func _tab_border_color() -> Color:
	return Color(0.14, 0.08, 0.22, 1.0)

func _title_outline_color() -> Color:
	return Color(0.42, 0.22, 0.62, 1.0)

func _title_shadow_color() -> Color:
	return Color(0.08, 0.04, 0.12, 1.0)

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
	return _achievement_count(profile, _is_profile_active(profile)) > 0 or _collection_count(profile, _is_profile_active(profile)) > 0

func _reset_profile(_profile: Dictionary) -> void:
	super._reset_profile(_profile)

func _is_profile_active(profile: Dictionary) -> bool:
	if _profile_svc == null:
		return false
	return str(profile.get("id", "")) == _profile_svc.get_active_profile_id()

func _achievement_count(profile: Dictionary, is_active: bool) -> int:
	var persistent := _persistent_branch(profile, is_active)
	var achievements: Variant = persistent.get("achievements", {})
	if not achievements is Dictionary:
		return 0
	var earned: Variant = achievements.get("earned", {})
	return earned.size() if earned is Dictionary else 0

func _collection_count(profile: Dictionary, is_active: bool) -> int:
	var persistent := _persistent_branch(profile, is_active)
	var collection: Variant = persistent.get("collection", {})
	if not collection is Dictionary:
		return 0
	var discovered: Variant = collection.get("discovered", {})
	return discovered.size() if discovered is Dictionary else 0
