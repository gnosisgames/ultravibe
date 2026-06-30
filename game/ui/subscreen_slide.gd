extends RefCounted

## Vertical slide helpers for Match3 subscreen overlays (Unity panel enter/exit parity).

const DURATION_SEC := 0.35


static func resolve_holder(view: Node) -> Control:
	if view == null:
		return null
	if view.has_method("get_subscreen_slide_holder"):
		var holder: Variant = view.call("get_subscreen_slide_holder")
		if holder is Control:
			return holder
	for path in ["Center", "Region"]:
		var node := view.get_node_or_null(path)
		if node == null and view.has_node("%" + path):
			node = view.get_node_or_null("%" + path)
		if node is Control:
			return node
	return null


static func supports(view: Node) -> bool:
	return resolve_holder(view) != null


static func apply_frame(view: Control, holder: Control) -> void:
	if view == null or holder == null:
		return
	var frame_script := load("res://game/ui/subscreen_frame.gd")
	if frame_script:
		frame_script.apply(view, holder)


static func slide_in(view: Control, holder: Control) -> Tween:
	apply_frame(view, holder)
	var rest := holder.position
	holder.position = rest + Vector2(0.0, holder.size.y)
	var tween := view.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(holder, "position", rest, DURATION_SEC)
	return tween


static func slide_out(view: Control, holder: Control) -> Tween:
	apply_frame(view, holder)
	var rest := holder.position
	var tween := view.create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(holder, "position", rest + Vector2(0.0, holder.size.y), DURATION_SEC)
	return tween
