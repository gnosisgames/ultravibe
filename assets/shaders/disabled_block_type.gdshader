shader_type canvas_item;

// Unity AllIn1 disabledBlockType parity: full greyscale with optional luminosity lift
// so dark gem colors (purple) stay visible grey, not crushed to black.
uniform float greyscale_blend : hint_range(0.0, 1.0) = 1.0;
uniform float greyscale_luminosity : hint_range(-0.5, 0.5) = 0.28;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	lum = clamp(lum + greyscale_luminosity, 0.0, 1.0);
	vec3 grey = vec3(lum) * tint_color.rgb;
	tex.rgb = mix(tex.rgb, grey, greyscale_blend);
	COLOR = tex * COLOR;
}
