shader_type canvas_item;

group_uniforms code_set_parameters;
uniform vec2 mouse_position;
uniform vec2 sprite_position;

group_uniforms _3D_Perspective;
uniform float fov : hint_range(1, 179) = 90;
uniform bool cull_back = true;
uniform float inset : hint_range(0, 1) = 0.0;
uniform float max_tilt : hint_range(0, 2.0) = 1.0;
uniform float max_distance = 500.0;
uniform bool hud_icon_mode = false;
uniform float hud_tilt_scale : hint_range(0.0, 1.0) = 0.35;

varying flat vec2 o;
varying vec3 p;

group_uniforms foil_uniforms;
uniform vec3 foilcolor : source_color;
uniform float threshold : hint_range(0.0, 2.0, 0.1) = 0.1;
uniform float fuzziness : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float period = 1.0;
uniform float scroll = 1.0;
uniform float normal_strength = 0.1;
uniform float effect_alpha_mult : hint_range(0, 1) = 1.0;
uniform float direction : hint_range(0, 1.0) = 0.5;

uniform sampler2D foil_mask;
uniform sampler2D gradient;
uniform sampler2D noise;
uniform sampler2D normal_map;

varying smooth vec2 direction_to;

float color_mask(vec3 mask, vec3 color, float mask_threshold, float mask_fuzziness) {
	float d = distance(mask, color);
	return clamp(1.0 - smoothstep(mask_threshold, mask_threshold + mask_fuzziness, d), 0.0, 1.0);
}

vec3 rotate_vector(vec3 v, float angleX, float angleY, float magnitude) {
	mat3 rotX = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, cos(angleX), -sin(angleX)),
		vec3(0.0, sin(angleX), cos(angleX))
	);
	mat3 rotY = mat3(
		vec3(cos(angleY), 0.0, sin(angleY)),
		vec3(0.0, 1.0, 0.0),
		vec3(-sin(angleY), 0.0, cos(angleY))
	);
	mat3 combinedRotation = rotX * rotY;
	vec3 rotatedVector = combinedRotation * v;
	return normalize(rotatedVector) * magnitude;
}

void vertex() {
	if (hud_icon_mode) {
		direction_to = vec2(0.0);
		float t = tan(fov / 360.0 * PI);
		p = vec3((UV - 0.5), 0.5 / t);
		o = vec2(0.0);
	} else {
		direction_to = mouse_position - sprite_position + vec2(1.0);
		float d = length(direction_to);
		float magnitude = min(max_tilt, d / max_distance);
		float angle = atan(direction_to.x, direction_to.y);
		float x_rota = abs(angle) / PI;
		float y_rota = abs(atan(direction_to.y, direction_to.x)) / PI;

		float sin_b = sin((-y_rota + 0.5) * magnitude * (PI / 2.0));
		float cos_b = cos((-y_rota + 0.5) * magnitude * (PI / 2.0));
		float sin_c = sin((x_rota - 0.5) * magnitude * (PI / 2.0));
		float cos_c = cos((x_rota - 0.5) * magnitude * (PI / 2.0));

		mat3 inv_rot_mat;
		inv_rot_mat[0][0] = cos_b;
		inv_rot_mat[0][1] = 0.0;
		inv_rot_mat[0][2] = -sin_b;
		inv_rot_mat[1][0] = sin_b * sin_c;
		inv_rot_mat[1][1] = cos_c;
		inv_rot_mat[1][2] = cos_b * sin_c;
		inv_rot_mat[2][0] = sin_b * cos_c;
		inv_rot_mat[2][1] = -sin_c;
		inv_rot_mat[2][2] = cos_b * cos_c;

		float t = tan(fov / 360.0 * PI);
		p = inv_rot_mat * vec3((UV - 0.5), 0.5 / t);
		float v = (0.5 / t) + 0.5;
		p.xy *= v * inv_rot_mat[2].z;
		o = v * inv_rot_mat[2].xy;
		VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE * t * (1.0 - inset);
	}
}

void fragment() {
	vec2 uv;
	vec2 adjusted_uv;
	if (hud_icon_mode) {
		adjusted_uv = UV;
		uv = UV - 0.5;
	} else {
		if (cull_back && p.z <= 0.0) {
			discard;
		}
		uv = (p.xy / p.z).xy - o;
		adjusted_uv = uv + 0.5;
	}

	vec4 albedo_tex = texture(TEXTURE, adjusted_uv);
	COLOR = albedo_tex;

	vec4 mask = texture(foil_mask, adjusted_uv);
	float texture_similarity;
	if (hud_icon_mode) {
		// Demo color_mask targets pale card art — colorful HUD icons need foil on all opaque pixels.
		float lum = dot(albedo_tex.rgb, vec3(0.299, 0.587, 0.114));
		texture_similarity = smoothstep(0.04, 0.2, albedo_tex.a) * smoothstep(0.06, 0.35, lum);
	} else {
		texture_similarity = color_mask(foilcolor, albedo_tex.rgb, threshold, fuzziness);
	}

	vec4 noise_tex = texture(noise, adjusted_uv);

	vec2 gradiant_sample;
	if (hud_icon_mode) {
		vec3 normal_map_tex = texture(normal_map, adjusted_uv).rgb * 2.0 - 1.0;
		gradiant_sample = vec2(
			0.25 + (uv.y * direction + uv.x * (1.0 - direction)) / 2.0 + normal_map_tex.x * normal_strength * 0.1,
			0.0
		);
	} else {
		float d = length(direction_to) + 1.0;
		float magnitude = min(max_tilt, d / max_distance);
		float angle = atan(direction_to.x, direction_to.y);
		float x_rota = abs(angle) / PI;
		float y_rota = abs(atan(direction_to.y, direction_to.x)) / PI;
		vec3 normal_map_tex = texture(normal_map, adjusted_uv).rgb * 2.0 - 1.0;
		vec3 normal = rotate_vector(vec3(1.0, 1.0, 1.0), x_rota, y_rota, magnitude * magnitude);
		normal = rotate_vector(normal, normal_map_tex.x, normal_map_tex.y, length(normal_map_tex)) * normal_strength;
		gradiant_sample = vec2(
			(0.25 + (normal.y * direction * 2.0 - normal.x * (1.0 - direction) * 2.0) / 2.0 + (uv.y * direction + uv.x * (1.0 - direction)) / 2.0),
			0.0
		);
		gradiant_sample += vec2(magnitude, 0.0) * scroll;
	}
	gradiant_sample = mod((gradiant_sample + adjusted_uv * period), 1.0);
	vec4 gradient_tex = texture(gradient, gradiant_sample);
	float noise_mix = hud_icon_mode ? 0.38 : 1.0;
	vec3 foil_rgb = gradient_tex.rgb * mix(vec3(1.0), noise_tex.rgb * 2.0, noise_mix);
	float strength = effect_alpha_mult * mask.r * texture_similarity;

	COLOR.rgb = mix(albedo_tex.rgb, foil_rgb, strength);
	if (!hud_icon_mode) {
		COLOR.a *= step(max(abs(uv.x), abs(uv.y)), 0.5);
	}
}
