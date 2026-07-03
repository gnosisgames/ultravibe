shader_type canvas_item;
render_mode unshaded, blend_mix;

// Solid metric-box tint — bypasses default particle texture/vertex color modulation.
uniform vec4 box_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int shape_type : hint_range(0, 2) = 0;

float sd_circle(vec2 p, float r) {
	return length(p) - r;
}

// Equilateral triangle pointing up, centered in the unit quad.
float sd_triangle_up(vec2 p) {
	const float k = 1.732050808; // sqrt(3)
	p.x = abs(p.x) - 0.42;
	p.y = p.y + 0.28;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) * 0.5;
	}
	p.x -= clamp(p.x, -0.42, 0.42);
	return -length(p) * sign(p.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	bool inside = false;

	if (shape_type == 0) {
		inside = max(abs(p.x), abs(p.y)) <= 0.92;
	} else if (shape_type == 1) {
		inside = sd_circle(p, 0.92) <= 0.0;
	} else {
		inside = sd_triangle_up(p) <= 0.0;
	}

	if (!inside) {
		discard;
	}
	COLOR = box_color;
}
