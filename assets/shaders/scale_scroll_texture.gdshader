shader_type canvas_item;

uniform sampler2D tile_texture;
uniform float tile_factor: hint_range(0.0, 100.0) = 1.0;
uniform vec2 tile_offset = vec2(0.0);
uniform float tile_rotation: hint_range(-360.0, 360.0, 0.1) = 0.0;
uniform float tile_rotation_speed: hint_range(0.0, 360.0, 0.01) = 0.0;
uniform float rotation: hint_range(-360.0, 360.0, 0.1) = 0.0;
uniform float tile_spacing: hint_range(-10.0, 10.0, 0.1) = 0.0;

uniform float scrolling_speed: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform vec2 scrolling_dir = vec2(0.5, 0.5);

varying vec4 modulate;

vec2 rotate(vec2 uv, float angle) {
    float s = sin(radians(angle));
    float c = cos(radians(angle));
    mat2 rot = mat2(vec2(c, -s), vec2(s, c));
    return rot * uv;
}

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 pattern_pixel_size = 1.0 / vec2(textureSize(tile_texture, 0));
	vec2 diff = pattern_pixel_size / TEXTURE_PIXEL_SIZE;

	vec4 in_tex = texture(TEXTURE, UV);

	// Tile UVs
	vec2 centered_uv = UV * 2.0 - 1.0;
	vec2 tiled_uv = centered_uv * tile_factor * diff;

	// Scrolling
	tiled_uv += normalize(scrolling_dir) * TIME * scrolling_speed;

	// Rotate (around center)
	tiled_uv = rotate(tiled_uv, rotation);

	// back to [0,1] range
	tiled_uv = tiled_uv * 0.5 + 0.5;
	tiled_uv += tile_offset;

	// Local coords inside a tile
	vec2 local_uv = fract(tiled_uv);

	// Rotate inside each tile
	local_uv = rotate(local_uv - 0.5, tile_rotation + TIME * tile_rotation_speed) + 0.5;

	// Spacing
	float scale = 1.0 - tile_spacing;
	local_uv = (local_uv - 0.5) * scale + 0.5;

	// Sample texture
	vec4 pattern_tex = texture(tile_texture, local_uv);

	COLOR.rgb = pattern_tex.rgb * modulate.rgb;
	COLOR.a = pattern_tex.a * in_tex.a * modulate.a;
}