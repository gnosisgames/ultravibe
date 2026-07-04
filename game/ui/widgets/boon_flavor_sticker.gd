class_name BoonFlavorSticker
extends RefCounted

## Corner sticker sprites for rolled boon flavors (positive top-right, negative top-left).

const SPRITE_ROOT := "res://assets/flavors/"
const POSITIVE_NODE_NAME := "PositiveFlavorSticker"
const NEGATIVE_NODE_NAME := "NegativeFlavorSticker"

## Fraction of slot width/height for the sticker art.
const SIZE_FRACTION := 0.44
## How far the sticker bleeds past the slot corner (fraction of slot size).
const CORNER_BLEED_FRACTION := 0.1
## Extra static tilt so stickers read as peeled-on labels (slot idle sway adds on top).
const POSITIVE_TILT_DEG := -14.0
const NEGATIVE_TILT_DEG := 14.0

## Legacy catalog ids from pre-rename saves still resolve to sticker art.
const LEGACY_SPRITE_STEMS: Dictionary = {
	"bonuspoints": "clout",
	"bonusmulti": "hype",
	"steel": "magnetic",
}


static func apply_to_slot(slot: Control, details: Dictionary, slot_size: float) -> void:
	if slot == null or slot_size < 8.0:
		return
	var positive_id := str(details.get("positive_flavor_id", "")).strip_edges()
	var negative_id := str(details.get("negative_flavor_id", "")).strip_edges()
	_attach_corner_sticker(slot, POSITIVE_NODE_NAME, positive_id, slot_size, true)
	_attach_corner_sticker(slot, NEGATIVE_NODE_NAME, negative_id, slot_size, false)


static func texture_for_flavor(flavor_id: String) -> Texture2D:
	var stem := _sprite_stem(flavor_id)
	if stem.is_empty():
		return null
	var path := "%s%s.png" % [SPRITE_ROOT, stem]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _attach_corner_sticker(
	slot: Control,
	node_name: String,
	flavor_id: String,
	slot_size: float,
	positive: bool,
) -> void:
	var existing := slot.get_node_or_null(node_name) as Control
	if existing:
		existing.queue_free()
	var tex := texture_for_flavor(flavor_id)
	if tex == null:
		return
	var sticker_size := slot_size * SIZE_FRACTION
	var bleed := slot_size * CORNER_BLEED_FRACTION
	var sticker := TextureRect.new()
	sticker.name = node_name
	sticker.texture = tex
	sticker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sticker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sticker.custom_minimum_size = Vector2(sticker_size, sticker_size)
	sticker.size = Vector2(sticker_size, sticker_size)
	if positive:
		sticker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		sticker.offset_left = -sticker_size + bleed
		sticker.offset_top = -bleed
		sticker.offset_right = bleed
		sticker.offset_bottom = sticker_size - bleed
		sticker.rotation_degrees = POSITIVE_TILT_DEG
	else:
		sticker.set_anchors_preset(Control.PRESET_TOP_LEFT)
		sticker.offset_left = -bleed
		sticker.offset_top = -bleed
		sticker.offset_right = sticker_size - bleed
		sticker.offset_bottom = sticker_size - bleed
		sticker.rotation_degrees = NEGATIVE_TILT_DEG
	sticker.pivot_offset = Vector2(sticker_size, sticker_size) * 0.5
	var icon := slot.get_node_or_null("Icon")
	var insert_index := slot.get_child_count()
	if icon:
		insert_index = icon.get_index() + 1
	slot.add_child(sticker)
	slot.move_child(sticker, insert_index)
	sticker.z_index = 2


static func _sprite_stem(flavor_id: String) -> String:
	var key := flavor_id.strip_edges().to_lower()
	if key.is_empty():
		return ""
	if LEGACY_SPRITE_STEMS.has(key):
		return str(LEGACY_SPRITE_STEMS[key])
	return key
