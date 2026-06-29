shader_type canvas_item;

uniform vec4 fill_color: source_color;
uniform float progress: hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	// Called for every vertex the material is visible on.
}
void fragment() {
	vec4 in_tex = texture(TEXTURE, UV);
	COLOR.rgb = fill_color.rgb * step(UV.x, progress);
	COLOR.a = in_tex.a * step(UV.x, progress);
}

