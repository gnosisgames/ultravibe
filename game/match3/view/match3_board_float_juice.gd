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
const HUD_BELOW_SLOT_PADDING_PX := 8.0
const HUD_HOLD_SEC := 0.28
const HUD_OVERLAY_Z_INDEX := 4096
const HUD_BOON_FLOAT_SIZE_SCALE := 1.25
const HUD_FONT_SIZE := 24
const HUD_GEM_PAD := Vector2(14, 8)

enum PopupMotion {
	RISE, ## Board gem clears — pop then drift upward.
	HUD_SCALE_POP, ## Boon/consumable bar — bottom-center anchor, scale pop only (Unity FloatingTextUpgrade).
}

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
	delay: float = 0.0,
	motion: PopupMotion = PopupMotion.RISE
) -> void:
	_spawn_popup(parent, anchor, text, accent, delay, false, motion)


## Screen-space popup (consumable bar, boon procs). Unity FloatingTextCanvas parity.
static func spawn_labeled_popup_global(
	host: Node,
	global_anchor: Vector2,
	text: String,
	accent: Color,
	delay: float = 0.0,
	motion: PopupMotion = PopupMotion.HUD_SCALE_POP,
	size_scale: float = 1.0
) -> void:
	if host == null or not is_instance_valid(host):
		return
	if delay > 0.0:
		host.get_tree().create_timer(delay).timeout.connect(
			func() -> void:
				if is_instance_valid(host):
					_play_popup(host, global_anchor, text, accent, true, motion, size_scale)
		)
	else:
		_play_popup(host, global_anchor, text, accent, true, motion, size_scale)


## Bottom-center of a HUD slot, slightly below the icon (Unity TryComputeBoonSlotFloatingTextAnchor).
static func hud_slot_bottom_center_global(slot: Control) -> Vector2:
	return _hud_slot_bottom_center(slot, true)


static func hud_slot_bottom_center_local(slot: Control) -> Vector2:
	return _hud_slot_bottom_center(slot, false)


static func _hud_slot_bottom_center(slot: Control, global_space: bool) -> Vector2:
	if slot == null or not is_instance_valid(slot):
		return Vector2.ZERO
	var slot_size := slot.size
	if slot_size.x < 1.0 or slot_size.y < 1.0:
		slot_size = slot.custom_minimum_size
	var offset := Vector2(slot_size.x * 0.5, slot_size.y + HUD_BELOW_SLOT_PADDING_PX)
	if global_space:
		return slot.global_position + offset
	return slot.position + offset


static func _is_disabled_item_type(item_type_id: String) -> bool:
	return str(item_type_id).strip_edges().to_lower() == "disabled"


static func _spawn_popup(
	parent: Control,
	anchor: Vector2,
	text: String,
	accent: Color,
	delay: float,
	global_space: bool,
	motion: PopupMotion = PopupMotion.RISE
) -> void:
	if text.is_empty():
		return
	if delay > 0.0:
		parent.get_tree().create_timer(delay).timeout.connect(
			func() -> void:
				if is_instance_valid(parent):
					_play_popup(parent, anchor, text, accent, global_space, motion)
		)
	else:
		_play_popup(parent, anchor, text, accent, global_space, motion)


static func _play_popup(
	host: Node,
	anchor: Vector2,
	text: String,
	accent: Color,
	global_space: bool,
	motion: PopupMotion = PopupMotion.RISE,
	size_scale: float = 1.0
) -> void:
	if _font == null:
		_font = load(FONT_PATH) as Font

	size_scale = maxf(size_scale, 0.01)
	var gem_size := GEM_SIZE * size_scale
	var font_size := int(round(HUD_FONT_SIZE * size_scale))
	var pad := HUD_GEM_PAD * size_scale

	var wrap := Control.new()
	wrap.name = &"ScoreFloat"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gem := ColorRect.new()
	gem.name = &"Gem"
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.color = accent
	gem.custom_minimum_size = Vector2(gem_size, gem_size)
	gem.size = Vector2(gem_size, gem_size)
	gem.pivot_offset = Vector2(gem_size * 0.5, gem_size * 0.5)
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
	label.add_theme_font_size_override("font_size", font_size if motion == PopupMotion.HUD_SCALE_POP else HUD_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)

	wrap.add_child(label)
	var layer := _resolve_popup_parent(host, global_space, motion)
	var use_global_pos := global_space
	if motion == PopupMotion.HUD_SCALE_POP and layer != host:
		use_global_pos = true
		if not global_space and host is CanvasItem:
			anchor = (host as CanvasItem).get_global_transform_with_canvas() * anchor
	wrap.top_level = use_global_pos
	wrap.z_index = HUD_OVERLAY_Z_INDEX if motion == PopupMotion.HUD_SCALE_POP else (1000 if global_space else 400)
	layer.add_child(wrap)

	label.reset_size()
	var text_size := label.get_combined_minimum_size()
	var layout_pad := pad if motion == PopupMotion.HUD_SCALE_POP else HUD_GEM_PAD
	var layout_gem := gem_size if motion == PopupMotion.HUD_SCALE_POP else GEM_SIZE
	var box_w := maxf(layout_gem, text_size.x + layout_pad.x)
	var box_h := maxf(layout_gem, text_size.y + layout_pad.y)
	wrap.custom_minimum_size = Vector2(box_w, box_h)
	wrap.size = Vector2(box_w, box_h)
	wrap.pivot_offset = wrap.size * 0.5
	if use_global_pos:
		wrap.global_position = anchor - wrap.pivot_offset
	else:
		wrap.position = anchor - wrap.pivot_offset

	gem.position = Vector2((box_w - layout_gem) * 0.5, (box_h - layout_gem) * 0.5)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	wrap.scale = Vector2.ZERO
	wrap.modulate = Color(1, 1, 1, 0)

	var tw := wrap.create_tween()
	if motion == PopupMotion.HUD_SCALE_POP:
		tw.set_parallel(true)
		tw.tween_property(wrap, "scale", Vector2(POP_SCALE, POP_SCALE), FADE_IN_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(wrap, "modulate:a", 1.0, FADE_IN_DURATION)
		tw.chain().tween_property(wrap, "scale", Vector2(SETTLE_SCALE, SETTLE_SCALE), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_interval(HUD_HOLD_SEC)
		tw.chain().tween_property(wrap, "modulate:a", 0.0, 0.2)
		tw.parallel().tween_property(wrap, "scale", Vector2(POP_SCALE * 1.05, POP_SCALE * 1.05), 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(wrap.queue_free)
	else:
		var dest_pos := (wrap.global_position if use_global_pos else wrap.position) + Vector2(0, -RISE_PX)
		tw.set_parallel(true)
		tw.tween_property(wrap, "scale", Vector2(POP_SCALE, POP_SCALE), FADE_IN_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(wrap, "modulate:a", 1.0, FADE_IN_DURATION)
		tw.chain().tween_property(wrap, "scale", Vector2(SETTLE_SCALE, SETTLE_SCALE), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var pos_prop := "global_position" if use_global_pos else "position"
		tw.chain().tween_property(wrap, pos_prop, dest_pos, maxf(0.15, PRIMARY_LIFETIME - FADE_IN_DURATION)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(wrap, "modulate:a", 0.0, 0.2)
		tw.parallel().tween_property(wrap, "scale", Vector2(POP_SCALE * 1.05, POP_SCALE * 1.05), 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(wrap.queue_free)


static func _resolve_popup_parent(host: Node, global_space: bool, motion: PopupMotion) -> Node:
	if host == null or not is_instance_valid(host):
		return host
	if motion == PopupMotion.HUD_SCALE_POP:
		var hud_layer := _resolve_hud_overlay_layer(host)
		if hud_layer != null:
			return hud_layer
	if global_space:
		var tree := host.get_tree()
		if tree != null:
			return tree.root
	return host


static func _resolve_hud_overlay_layer(host: Node) -> CanvasLayer:
	var node: Node = host
	while node != null:
		if node.has_method("get_hud_tooltip_layer"):
			var layer = node.call("get_hud_tooltip_layer")
			if layer is CanvasLayer:
				return layer as CanvasLayer
		node = node.get_parent()
	return null
