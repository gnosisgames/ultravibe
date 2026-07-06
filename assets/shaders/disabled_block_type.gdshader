shader_type canvas_item;

// Disabled/debuff tiles: neutral greyscale (R=G=B from Rec.709 luma).
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(vec3(lum), tex.a * COLOR.a);
}
