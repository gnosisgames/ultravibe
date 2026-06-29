shader_type canvas_item;

// Tiles a texture across the full rect and scrolls it over time. Aspect-aware
// so square source cells stay square regardless of window resolution. The
// owning control feeds its pixel size via `rect_size` (see scrolling_tiles_bg.gd).

uniform sampler2D tile_texture : repeat_enable, filter_linear_mipmap;
// How many times the tile repeats horizontally across the rect. Vertical
// repeats are derived from this and the rect aspect so cells stay square.
uniform float tiles_across : hint_range(0.5, 64.0) = 6.0;
// Scroll velocity in tile-space units per second.
uniform vec2 scroll_speed = vec2(0.04, 0.06);
// Extra rotation of the whole tiled pattern, in degrees.
uniform float rotation_degrees : hint_range(-180.0, 180.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
// Pixel size of the rect this material is drawn on; kept in sync by script.
uniform vec2 rect_size = vec2(1920.0, 1080.0);

vec2 rotate2(vec2 v, float deg) {
	float a = radians(deg);
	float s = sin(a);
	float c = cos(a);
	return mat2(vec2(c, -s), vec2(s, c)) * v;
}

void fragment() {
	float aspect = rect_size.x / max(rect_size.y, 0.001);

	// Scale UV so one horizontal tile == one vertical tile (square cells).
	vec2 uv = UV;
	uv.y /= aspect;

	uv = rotate2(uv - 0.5, rotation_degrees) + 0.5;

	vec2 tiled_uv = uv * tiles_across + TIME * scroll_speed;
	vec4 tex = texture(tile_texture, tiled_uv);
	COLOR = tex * tint;
}
