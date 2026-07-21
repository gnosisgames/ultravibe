class_name Match3HudItemUpgradesColumn
extends PlayHudUpgradesBar

## Gem level upgrades — bottom left-rail third.
## Fit any count into the section height (shrink / negative gap), like consumables.


func _ready() -> void:
	show_capacity_dots = false
	float_offset = 0.0
	slot_gap = Match3Hud.LEFT_RAIL_GAP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(_on_rail_layout_changed)
	super._ready()


func apply_left_rail_pack(slot: float, gap: float) -> void:
	slot_size = slot
	slot_gap = gap
	add_theme_constant_override("separation", int(round(gap)))


func _bag() -> GnosisNode:
	return _ephemeral().get_node("upgrades").get_node("itemUpgrades")


func _inventory_list() -> GnosisNode:
	var bag := _bag()
	if not bag.is_valid():
		return GnosisNode.new(null)
	return bag.get_node("list")


func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_END


func _resolve_item_id(entry: GnosisNode) -> String:
	var upgrade_id := _node_str(entry, "upgradeId")
	if not upgrade_id.is_empty():
		return upgrade_id
	return super._resolve_item_id(entry)


func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_END


func _slot_size_flags_horizontal() -> int:
	return Control.SIZE_SHRINK_CENTER


func _slot_icon_fills_cell() -> bool:
	return false


func _slot_icon_stretch_mode() -> TextureRect.StretchMode:
	return TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _available_height() -> float:
	if has_meta(&"left_rail_budget_h"):
		var budget := float(get_meta(&"left_rail_budget_h"))
		if budget >= 8.0:
			return budget
	var section := get_parent() as Control
	if section and section.has_meta(&"left_rail_equal_h"):
		var equal_h := float(section.get_meta(&"left_rail_equal_h"))
		var style := section.get_theme_stylebox(&"panel") as StyleBox
		if style:
			equal_h -= style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
		if equal_h >= 8.0:
			return equal_h
	# Never pack against an inflated EXPAND_FILL height — that recreates 64px
	# slots that blow the equal-third rail during gameplay force_refresh.
	var available_h := size.y
	if section and section.size.y >= 8.0:
		available_h = mini(available_h if available_h >= 8.0 else section.size.y, section.size.y)
		var style := section.get_theme_stylebox(&"panel") as StyleBox
		if style:
			available_h -= style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	return maxf(available_h, 8.0)


func _resolve_slot_size() -> float:
	var count := _entries().size()
	if count <= 0:
		count = maxi(_slot_nodes.size(), 1)
	var pack := Match3Hud.left_rail_pack_metrics(
		Match3Hud.left_rail_slot_extent_for(self),
		_available_height(),
		count,
		Match3Hud.LEFT_RAIL_GAP
	)
	apply_left_rail_pack(pack.x, pack.y)
	return pack.x


func _refresh() -> void:
	super._refresh()
	# Immediate pack — don't wait for deferred/base NOTIFICATION after gameplay rebuilds.
	_relayout_slot_sizes()


func _make_slot(index: int, details: Dictionary) -> Control:
	var slot := super._make_slot(index, details)
	var w := slot_size
	if w < 8.0:
		w = _resolve_slot_size()
	if w < 8.0:
		return slot
	slot.custom_minimum_size = Vector2(w, w)
	slot.size = Vector2(w, w)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_END
	var icon := slot.get_node_or_null("Icon") as TextureRect
	if icon:
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 0.0
		icon.offset_top = 0.0
		icon.offset_right = 0.0
		icon.offset_bottom = 0.0
		icon.custom_minimum_size = Vector2(w, w)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var hit := slot.get_node_or_null("Hit") as Button
	if hit:
		hit.set_anchors_preset(Control.PRESET_FULL_RECT)
		hit.offset_left = 0.0
		hit.offset_top = 0.0
		hit.offset_right = 0.0
		hit.offset_bottom = 0.0
	return slot


func _relayout_slot_sizes() -> void:
	var cell_size := _resolve_slot_size()
	if cell_size < 8.0:
		return
	slot_size = cell_size
	for slot in _slot_nodes:
		if not is_instance_valid(slot):
			continue
		# Force a square cell so faces scale down instead of getting COVERED-cropped.
		slot.custom_minimum_size = Vector2(cell_size, cell_size)
		slot.size = Vector2(cell_size, cell_size)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_END
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 0.0
			icon.offset_top = 0.0
			icon.offset_right = 0.0
			icon.offset_bottom = 0.0
			icon.custom_minimum_size = Vector2(cell_size, cell_size)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var hit := slot.get_node_or_null("Hit") as Button
		if hit:
			hit.set_anchors_preset(Control.PRESET_FULL_RECT)
			hit.offset_left = 0.0
			hit.offset_top = 0.0
			hit.offset_right = 0.0
			hit.offset_bottom = 0.0
		var badge := slot.get_node_or_null("Count") as Label
		if badge:
			var badge_rect := _stack_badge_rect(cell_size)
			badge.offset_left = badge_rect.position.x
			badge.offset_top = badge_rect.position.y
			badge.offset_right = badge_rect.end.x
			badge.offset_bottom = badge_rect.end.y
			badge.add_theme_font_size_override(&"font_size", _stack_badge_font_size())
	queue_sort()
	queue_redraw()


func _stack_badge_font_size() -> int:
	return clampi(int(round(slot_size * 0.42)), 8, 22)


func _stack_badge_rect(slot_size: float) -> Rect2:
	return Rect2(slot_size - 36.0, slot_size - 28.0, 40.0, 32.0)


func _on_rail_layout_changed() -> void:
	_relayout_slot_sizes()
