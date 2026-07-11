class_name UltraAchievementProgress
extends RefCounted

const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")

const TITLE_FONT_SIZE := 18
const TITLE_OUTLINE_SIZE := 7
const GALLERY_FONT_SIZE := 40
const GALLERY_OUTLINE_SIZE := 10

static func counts(achievement_service) -> Vector2i:
	if achievement_service == null:
		return Vector2i.ZERO
	var earned: int = int(achievement_service.get_earned_count())
	var total: int = achievement_service.list_catalog_ids().size()
	return Vector2i(maxi(0, earned), maxi(0, total))

static func label(achievement_service) -> String:
	var progress := counts(achievement_service)
	return "%d/%d" % [progress.x, progress.y]

static func apply_title_style(label: Label) -> void:
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.98, 0.96, 1.0, 1.0))
	label.add_theme_constant_override("outline_size", TITLE_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color(0.42, 0.22, 0.62, 1.0))

static func apply_gallery_style(label: Label) -> void:
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", GALLERY_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))
	label.add_theme_constant_override("outline_size", GALLERY_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color(0.345098, 0.345098, 0.572549, 1.0))
