class_name Match3ScoreFloatingDisplayText
extends RefCounted

## Formats floating labels (+N points, +N multi) for board score pops.


static func build_points_add(value: int) -> String:
	return _build_signed_add(value)


static func build_multi_add(value: int) -> String:
	return _build_signed_add(value)


static func _build_signed_add(value: int) -> String:
	var n := str(absi(value))
	if value < 0:
		return "-" + n
	return "+" + n
