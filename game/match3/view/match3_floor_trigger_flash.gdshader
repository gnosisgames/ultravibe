shader_type canvas_item;

// Mixes the sprite toward solid white while keeping its alpha silhouette.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(col.rgb, vec3(1.0), flash), col.a);
}
