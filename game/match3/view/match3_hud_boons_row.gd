class_name Match3HudBoonsRow
extends PlayHudBoonsBar

## Top-strip boon inventory (centered row). Count label is overlaid on the bar chrome,
## not in the row layout, so icons can use the full panel height.

const PANEL_HORIZONTAL_INSET := 24.0
## SB_boons content_margin_top + content_margin_bottom (21 + 21).
const PANEL_VERTICAL_INSET := 42.0
const MIN_SLOT := 96.0
## Slight overscale so icons feel as large as the consumables sidebar tiles.
const SLOT_OVERFLOW := 1.08

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
	var row_h := size.y
	var row_w := size.x
	if _bar_panel:
		if row_h < 8.0:
			row_h = maxf(0.0, _bar_panel.size.y - PANEL_VERTICAL_INSET)
		if row_w < 8.0:
			row_w = maxf(0.0, _bar_panel.size.x - PANEL_HORIZONTAL_INSET)
	if row_h < 8.0 or row_w < 8.0:
		return -1.0
	var count := maxi(_entries().size(), 1)
	var gap := float(slot_gap)
	var by_height := row_h * SLOT_OVERFLOW
	var by_width := (row_w - gap * float(count - 1)) / float(count)
	return maxf(MIN_SLOT, minf(by_height, by_width))


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


func _make_slot(index: int, details: Dictionary) -> Control:
	var slot := super._make_slot(index, details)
	var w := slot_size
	if w >= 8.0:
		slot.custom_minimum_size = Vector2(w, w + float_offset)
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.offset_bottom = w
		var hit := slot.get_node_or_null("Hit") as Button
		if hit:
			hit.offset_bottom = w
		var badge := slot.get_node_or_null("Count") as Label
		if badge:
			badge.offset_left = w - 28.0
			badge.offset_top = w - 20.0
			badge.offset_right = w + 2.0
			badge.offset_bottom = w + 2.0
	return slot
