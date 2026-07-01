class_name Match3ScoreFloatingDisplayText
extends RefCounted

## Formats floating labels (+N points, +N multi) for board score pops.


static func build_points_add(value: int) -> String:
	return _build_signed_add(value)


static func build_multi_add(value: int) -> String:
	return _build_signed_add(value)


static func build_for_multi_op(op: String, value: float) -> String:
	if op.strip_edges().to_lower() == "multiply":
		if is_equal_approx(value, round(value)):
			return "x%d" % int(round(value))
		return "x%s" % str(snapped(value, 0.01)).trim_suffix("0").trim_suffix(".")
	return build_multi_add(int(round(value)))


static func _build_signed_add(value: int) -> String:
	var n := str(absi(value))
	if value < 0:
		return "-" + n
	return "+" + n
