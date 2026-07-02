shader_type canvas_item;

uniform sampler2D fire_texture : filter_linear, repeat_enable;
uniform float power = 100.0;
uniform float speed_y = -0.1;

void fragment() {
	if (power >= 99.0) {
		COLOR = vec4(0.0);
	} else {
		float intensity = clamp(1.0 - (power / 6.0), 0.0, 1.0);
		vec2 uv = UV + vec2(0.0, TIME * speed_y);
		vec4 sample_color = texture(fire_texture, uv);
		COLOR = vec4(sample_color.rgb, sample_color.a * intensity * 0.85);
	}
}
