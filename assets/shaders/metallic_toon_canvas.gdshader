shader_type canvas_item;

// Profesor Shader toon_metal port for TextureRect icons (MIT, METALLIC_TOON_LICENSE.txt).

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D color_ramp : repeat_disable, filter_nearest;
uniform vec3 light_direction = vec3(-0.35, -0.55, 0.75);

uniform vec3 specular_color : source_color = vec3(1.0);
uniform float specular_size : hint_range(1.0, 256.0) = 8.0;
uniform float specular_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float specular_strength : hint_range(0.0, 4.0) = 1.0;

uniform sampler2D noise_tex : repeat_enable;
uniform float noise_pow = 2.0;
uniform float noise_scl = 0.1;
uniform float rim_pow = 4.0;
uniform float rim_str = 1.0;
uniform float metal_blend : hint_range(0.0, 1.0) = 0.45;
uniform bool hud_icon_mode = false;
uniform vec3 metal_tint : source_color = vec3(1.0);
uniform float metal_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float metal_mask_sharpness : hint_range(0.5, 8.0) = 2.0;

void fragment() {
	vec4 albedo_tex = texture(TEXTURE, UV) * base_color;
	if (albedo_tex.a < 0.01) {
		discard;
	}

	vec3 sprite = albedo_tex.rgb;

	vec2 centered = (UV - 0.5) * 2.0;
	float r2 = dot(centered, centered);
	float dome_scale = hud_icon_mode ? 0.48 : 1.0;
	float xy_scale = hud_icon_mode ? 0.28 : 1.0;
	float dome_z = sqrt(max(0.001, 1.0 - r2 * dome_scale));
	vec3 n = normalize(vec3(centered * xy_scale, dome_z));

	vec3 l = normalize(light_direction);
	vec3 v = vec3(0.0, 0.0, 1.0);

	float ndotl = (dot(n, l) + 1.0) * 0.5;
	vec3 r = reflect(v, n);
	float noise = pow(texture(noise_tex, vec2(r.x, r.y) * noise_scl).r, noise_pow);
	float rim = pow(clamp((r.z + 1.0) * 0.5, 0.0, 1.0), rim_pow);
	float rim_and_reflection = clamp(noise + rim * rim_str, 0.0, 1.0);
	float final_diffuse = ndotl * rim_and_reflection;

	vec3 h = normalize(v + l);
	float spec = pow(max(dot(n, h), 0.0), specular_size);
	spec = step(specular_threshold, spec);

	vec3 toon = texture(color_ramp, vec2(final_diffuse, 0.5)).rgb * metal_tint;

	vec3 lit;
	if (hud_icon_mode) {
		float band = smoothstep(metal_threshold, 1.0, final_diffuse);
		band = pow(band, metal_mask_sharpness);
		float metal_mask = clamp(band + spec * 0.9, 0.0, 1.0);
		vec3 metal_sheen = mix(sprite, sprite * toon, 0.72);
		lit = mix(sprite, metal_sheen, metal_mask * metal_blend);
		lit += specular_color * spec * specular_strength;
	} else {
		vec3 metal = toon * mix(vec3(1.0), sprite, 0.65);
		lit = mix(sprite, metal, metal_blend) + specular_color * spec * specular_strength;
	}
	COLOR = vec4(lit, albedo_tex.a);
}
