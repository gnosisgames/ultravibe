shader_type canvas_item;

// Legacy line-clear "WHITE" flash: renders whatever sprite/rect is drawn as a
// solid-white silhouette (keeping the source alpha), mirroring the Unity
// AllIn1 greyscale+white material used for the block clear FX. The per-draw
// modulate alpha (COLOR.a) drives the fade-out.
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(1.0, 1.0, 1.0, tex.a * COLOR.a);
}
