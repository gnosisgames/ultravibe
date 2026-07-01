class_name Match3BoardFloatJuice
extends RefCounted

## Board floating text for gem clears (Unity FloatingTextPoint / FloatingTextMulti parity).

const DisplayTextScript = preload("res://game/match3/view/match3_score_floating_display_text.gd")
const FONT_PATH := "res://assets/fonts/Comic Lemon.otf"

const PRIMARY_LIFETIME := 0.6
const SECONDARY_DELAY_FACTOR := 0.5
const RISE_PX := 48.0
const GEM_SIZE := 48.0
const FADE_IN_DURATION := 0.2
const POP_SCALE := 1.2
const SETTLE_SCALE := 1.0

## Unity FloatingTextPoint / FloatingTextMulti background tints.
const COLOR_POINTS := Color(0.20392157, 0.43529412, 0.85490197)
const COLOR_MULTI := Color(0.8039216, 0.17254902, 0.34509805)
## Unity FloatingTextMoney — also used for styleId "upgrade" (consumable Use, boon procs).
const COLOR_MONEY := Color(0.9372549, 0.7490196, 0.015686275)
const COLOR_UPGRADE := COLOR_MONEY
const COLOR_DISABLED := Color(0.55, 0.58, 0.65)

static var _font: Font = null


static func spawn_destroy_gem_popups(
	parent: Control,
	anchor: Vector2,
	points_added: int,
	multi_added: int,
	item_type_id: String
) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if _is_disabled_item_type(item_type_id):
		_spawn_popup(parent, anchor, "\u00D7", COLOR_DISABLED, 0.0, false)
		return
	var has_points := points_added > 0
	var has_multi := multi_added > 0
	if not has_points and not has_multi:
		return
	if has_points:
		_spawn_popup(
			parent,
			anchor,
			DisplayTextScript.build_points_add(points_added),
			COLOR_POINTS,
			0.0,
			false
		)
	if has_multi:
		var delay := PRIMARY_LIFETIME * SECONDARY_DELAY_FACTOR if has_points else 0.0
		_spawn_popup(
			parent,
			anchor,
			DisplayTextScript.build_multi_add(multi_added),
			COLOR_MULTI,
			delay,
			false
		)


static func spawn_labeled_popup(
	parent: Control,
	anchor: Vector2,
	text: String,
	accent: Color,
	delay: float = 0.0
) -> void:
	_spawn_popup(parent, anchor, text, accent, delay, false)


## Screen-space popup (consumable bar, boon procs). Unity FloatingTextCanvas parity.
static func spawn_labeled_popup_global(
	host: Node,
	global_anchor: Vector2,
	text: String,
	accent: Color,
	delay: float = 0.0
) -> void:
	if host == null or not is_instance_valid(host):
		return
	if delay > 0.0:
		host.get_tree().create_timer(delay).timeout.connect(
			func() -> void:
				if is_instance_valid(host):
					_play_popup(host, global_anchor, text, accent, true)
		)
	else:
		_play_popup(host, global_anchor, text, accent, true)


static func _is_disabled_item_type(item_type_id: String) -> bool:
	return str(item_type_id).strip_edges().to_lower() == "disabled"


static func _spawn_popup(
	parent: Control,
	anchor: Vector2,
	text: String,
	accent: Color,
	delay: float,
	global_space: bool
) -> void:
	if text.is_empty():
		return
	if delay > 0.0:
		parent.get_tree().create_timer(delay).timeout.connect(
			func() -> void:
				if is_instance_valid(parent):
					_play_popup(parent, anchor, text, accent, global_space)
		)
	else:
		_play_popup(parent, anchor, text, accent, global_space)


static func _play_popup(host: Node, anchor: Vector2, text: String, accent: Color, global_space: bool) -> void:
	if _font == null:
		_font = load(FONT_PATH) as Font

	var wrap := Control.new()
	wrap.name = &"ScoreFloat"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.z_index = 1000 if global_space else 400
	wrap.top_level = global_space

	var gem := ColorRect.new()
	gem.name = &"Gem"
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.color = accent
	gem.custom_minimum_size = Vector2(GEM_SIZE, GEM_SIZE)
	gem.size = Vector2(GEM_SIZE, GEM_SIZE)
	gem.pivot_offset = Vector2(GEM_SIZE * 0.5, GEM_SIZE * 0.5)
	gem.rotation = deg_to_rad(45.0)
	wrap.add_child(gem)

	var label := Label.new()
	label.name = &"Text"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 1
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)

	wrap.add_child(label)
	var layer: Node = host.get_tree().root if global_space else host
	if layer == null:
		layer = host
	layer.add_child(wrap)

	label.reset_size()
	var text_size := label.get_combined_minimum_size()
	var pad := Vector2(14, 8)
	var box_w := maxf(GEM_SIZE, text_size.x + pad.x)
	var box_h := maxf(GEM_SIZE, text_size.y + pad.y)
	wrap.custom_minimum_size = Vector2(box_w, box_h)
	wrap.size = Vector2(box_w, box_h)
	wrap.pivot_offset = wrap.size * 0.5
	if global_space:
		wrap.global_position = anchor - wrap.pivot_offset
	else:
		wrap.position = anchor - wrap.pivot_offset

	gem.position = Vector2((box_w - GEM_SIZE) * 0.5, (box_h - GEM_SIZE) * 0.5)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	wrap.scale = Vector2.ZERO
	wrap.modulate = Color(1, 1, 1, 0)

	var dest_pos := (wrap.global_position if global_space else wrap.position) + Vector2(0, -RISE_PX)
	var tw := wrap.create_tween()
	tw.set_parallel(true)
	tw.tween_property(wrap, "scale", Vector2(POP_SCALE, POP_SCALE), FADE_IN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(wrap, "modulate:a", 1.0, FADE_IN_DURATION)
	tw.chain().tween_property(wrap, "scale", Vector2(SETTLE_SCALE, SETTLE_SCALE), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var pos_prop := "global_position" if global_space else "position"
	tw.chain().tween_property(wrap, pos_prop, dest_pos, maxf(0.15, PRIMARY_LIFETIME - FADE_IN_DURATION)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(wrap, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(wrap, "scale", Vector2(POP_SCALE * 1.05, POP_SCALE * 1.05), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(wrap.queue_free)
