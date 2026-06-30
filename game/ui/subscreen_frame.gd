extends RefCounted

## Loaded via preload as `SubscreenFrame` by the subscreen overlays (no global
## class_name so headless `--script` runs don't depend on the class cache).

## Shared helper that positions a subscreen overlay's content into the Match3
## HUD content frame (the rect between the main sidebar panel and the consumable
## sidebar, with the height of the main sidebar panel). Used by the level select,
## shop and reward overlays so they all occupy the same default region.

const HUD_GROUP := "match3_hud"


## Aligns `holder` to the HUD content frame. `view` is the overlay root (used to
## reach the scene tree). Returns true when a frame was applied.
static func apply(view: Control, holder: Control) -> bool:
	if view == null or holder == null or not view.is_inside_tree():
		return false
	var hud := view.get_tree().get_first_node_in_group(HUD_GROUP)
	if hud == null or not hud.has_method("get_content_frame_rect"):
		return false
	var rect: Rect2 = hud.get_content_frame_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.position = rect.position
	holder.size = rect.size
	return true


## Connects `callback` to the HUD's content_frame_changed signal (idempotent).
static func connect_changes(view: Control, callback: Callable) -> void:
	if view == null or not view.is_inside_tree():
		return
	var hud := view.get_tree().get_first_node_in_group(HUD_GROUP)
	if hud == null or not hud.has_signal("content_frame_changed"):
		return
	if not hud.is_connected("content_frame_changed", callback):
		hud.connect("content_frame_changed", callback)
