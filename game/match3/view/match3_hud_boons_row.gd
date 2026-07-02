class_name Match3HudBoonsRow
extends PlayHudBoonsBar

## Top-strip boon inventory (centered row). Count label is overlaid; icons fill bar
## height with vertical bleed (negative padding) so squares read large like Unity.

const PANEL_HORIZONTAL_INSET := 16.0
## Icons extend past the strip chrome top/bottom (matches BoonsRow anchor offsets in tscn).
const VERTICAL_BLEED := 10.0
## Slightly under full bleed so icons match Unity strip scale.
const SIZE_FACTOR := 0.9
## Unity GnosisUIElementReorderableItem idle sway defaults.
const SWAY_ANGLE_DEG := 3.5
const SWAY_HALF_CYCLE_SEC := 3.2
const SWAY_ANGLE_VAR := 1.25
const SWAY_TIMING_VAR := 0.4

var _bar_panel: PanelContainer = null
var _last_layout_slot_size := -1.0


func _ready() -> void:
	show_capacity_dots = false
	float_offset = 0.0
	slot_gap = 14.0
	super._ready()
	resized.connect(_on_slot_layout_dirty)
	call_deferred("_resolve_bar_panel")
	call_deferred("_on_slot_layout_dirty")


func _resolve_bar_panel() -> void:
	var node: Node = get_parent()
	while node:
		if node is PanelContainer:
			_bar_panel = node as PanelContainer
			if not _bar_panel.resized.is_connected(_on_slot_layout_dirty):
				_bar_panel.resized.connect(_on_slot_layout_dirty)
			return
		node = node.get_parent()


func _compute_slot_size() -> float:
	# BoonsRow uses ±VERTICAL_BLEED anchor offsets — row height is the square size.
	var square := size.y
	if square < 8.0 and _bar_panel:
		square = _bar_panel.size.y + VERTICAL_BLEED * 2.0
	if square < 8.0:
		return -1.0
	if _bar_panel:
		var bar_inner_w := maxf(0.0, _bar_panel.size.x - PANEL_HORIZONTAL_INSET)
		var count := maxi(_entries().size(), 1)
		if count > 1 and bar_inner_w >= 8.0:
			var gap := float(slot_gap)
			var max_w := (bar_inner_w - gap * float(count - 1)) / float(count)
			if max_w >= 8.0:
				square = minf(square, max_w)
	return square * SIZE_FACTOR


func _on_slot_layout_dirty() -> void:
	var computed := _compute_slot_size()
	if computed < 8.0 or is_equal_approx(computed, _last_layout_slot_size):
		return
	_last_layout_slot_size = computed
	slot_size = computed
	force_refresh()


func _refresh() -> void:
	var computed := _compute_slot_size()
	if computed >= 8.0:
		slot_size = computed
		_last_layout_slot_size = computed
	super._refresh()


func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER


func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_CENTER


func _process(_delta: float) -> void:
	super._process(_delta)
	_tick_idle_sway()


func _tick_idle_sway() -> void:
	var time_sec := Time.get_ticks_msec() / 1000.0
	for slot in _slot_nodes:
		if slot == null or not is_instance_valid(slot):
			continue
		if slot.get_meta(&"sway_paused", false):
			continue
		if slot.size.x > 1.0 and slot.size.y > 1.0:
			slot.pivot_offset = slot.size * 0.5
		var max_angle: float = slot.get_meta(&"sway_max_angle", SWAY_ANGLE_DEG)
		var speed: float = slot.get_meta(&"sway_speed", PI / SWAY_HALF_CYCLE_SEC)
		var offset: float = slot.get_meta(&"sway_time_offset", 0.0)
		slot.rotation_degrees = sin((time_sec + offset) * speed) * max_angle


func _configure_slot_sway(slot: Control, index: int, details: Dictionary) -> void:
	var seed := index * 1315423911
	var item_id: String = str(details.get("name", ""))
	if not item_id.is_empty():
		seed = item_id.hash()
	var angle_scale := 1.0 + SWAY_ANGLE_VAR * (_sway_hash01(seed, 11) * 2.0 - 1.0)
	var timing_scale := 1.0 + SWAY_TIMING_VAR * (_sway_hash01(seed, 23) * 2.0 - 1.0)
	slot.set_meta(&"sway_max_angle", maxf(0.5, SWAY_ANGLE_DEG * angle_scale))
	slot.set_meta(
		&"sway_speed",
		PI / maxf(0.8, SWAY_HALF_CYCLE_SEC * timing_scale),
	)
	slot.set_meta(&"sway_time_offset", _sway_hash01(seed, 37) * TAU)
	slot.set_meta(&"sway_paused", false)


func _sway_hash01(seed: int, salt: int) -> float:
	var h := seed * 397 ^ salt * 0x2D2816FE
	h = (h ^ (h >> 16)) * 0x45D9F3B
	h ^= h >> 16
	return float(h & 0x7FFFFFFF) / float(0x7FFFFFFF)


func _make_slot(index: int, details: Dictionary) -> Control:
	var slot := super._make_slot(index, details)
	_configure_slot_sway(slot, index, details)
	var w := slot_size
	if w >= 8.0:
		slot.custom_minimum_size = Vector2(w, w + float_offset)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 0.0
			icon.offset_top = 0.0
			icon.offset_right = 0.0
			icon.offset_bottom = 0.0
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		var hit := slot.get_node_or_null("Hit") as Button
		if hit:
			hit.set_anchors_preset(Control.PRESET_FULL_RECT)
			hit.offset_left = 0.0
			hit.offset_top = 0.0
			hit.offset_right = 0.0
			hit.offset_bottom = 0.0
		var badge := slot.get_node_or_null("Count") as Label
		if badge:
			badge.offset_left = w - 28.0
			badge.offset_top = w - 20.0
			badge.offset_right = w + 2.0
			badge.offset_bottom = w + 2.0
	return slot
