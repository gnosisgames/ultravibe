class_name ShopOfferCard
extends PanelContainer

## Shop row cell: large catalog icon filling the tile, plain price text below (no chrome).

const BoonFlavorStickerScript = preload("res://game/ui/widgets/boon_flavor_sticker.gd")

const TILE_WIDTH := 132.0
const TILE_HEIGHT := 168.0
const GOLD := Color(0.937255, 0.74902, 0.0156863, 1)
const PRICE_FONT_SIZE := 27

signal buy_pressed


func _init() -> void:
	custom_minimum_size = Vector2(TILE_WIDTH, TILE_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func configure(font: Font, presentation: Dictionary, price: int) -> void:
	for child in get_children():
		child.queue_free()

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var icon_slot := Control.new()
	icon_slot.name = "IconSlot"
	icon_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_slot.custom_minimum_size = Vector2(TILE_WIDTH, TILE_HEIGHT - 36.0)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_slot)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := str(presentation.get("icon_path", ""))
	if not icon_path.is_empty():
		icon.texture = load(icon_path)
	else:
		icon.modulate = Color(0.3, 0.34, 0.42)
	icon_slot.add_child(icon)

	var positive_id := str(presentation.get("positive_flavor_id", "")).strip_edges()
	var negative_id := str(presentation.get("negative_flavor_id", "")).strip_edges()
	if not positive_id.is_empty() or not negative_id.is_empty():
		BoonFlavorStickerScript.apply_to_slot(
			icon_slot,
			{
				"positive_flavor_id": positive_id,
				"negative_flavor_id": negative_id,
			},
			icon_slot.custom_minimum_size.x,
		)

	var price_label := Label.new()
	price_label.text = "$%d" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		price_label.add_theme_font_override("font", font)
	price_label.add_theme_font_size_override("font_size", PRICE_FONT_SIZE)
	price_label.add_theme_color_override("font_color", GOLD)
	box.add_child(price_label)


func get_tooltip_anchor() -> Control:
	return self


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			buy_pressed.emit()
			accept_event()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			buy_pressed.emit()
			accept_event()
