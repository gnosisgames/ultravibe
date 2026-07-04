extends SceneTree

func _initialize() -> void:
	var path := "res://screenshots/_capture_boons_metallic.png"
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("missing %s" % path)
		quit(1)
		return
	var im := tex.get_image()
	var regions: Array = [
		["icon0", 1480, 150, 1680, 310],
		["icon1", 1700, 150, 1900, 310],
		["icon2", 1920, 150, 2120, 310],
	]
	for entry in regions:
		var name: String = entry[0]
		var x0: int = entry[1]
		var y0: int = entry[2]
		var x1: int = entry[3]
		var y1: int = entry[4]
		var sub := im.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
		var count := 0
		var sr := 0.0
		var sg := 0.0
		var sb := 0.0
		var min_c := Vector3(999.0, 999.0, 999.0)
		var max_c := Vector3(-1.0, -1.0, -1.0)
		for y in sub.get_height():
			for x in sub.get_width():
				var c := sub.get_pixel(x, y)
				if c.a < 0.15:
					continue
				count += 1
				sr += c.r
				sg += c.g
				sb += c.b
				min_c.x = minf(min_c.x, c.r)
				min_c.y = minf(min_c.y, c.g)
				min_c.z = minf(min_c.z, c.b)
				max_c.x = maxf(max_c.x, c.r)
				max_c.y = maxf(max_c.y, c.g)
				max_c.z = maxf(max_c.z, c.b)
		if count == 0:
			print("%s: no opaque pixels" % name)
			continue
		var mean := Vector3(sr / count, sg / count, sb / count)
		print("%s count=%d mean=%s min=%s max=%s contrast=%s" % [
			name, count, mean, min_c, max_c, max_c - min_c,
		])
	quit(0)
