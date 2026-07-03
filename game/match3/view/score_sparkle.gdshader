shader_type canvas_item;
render_mode unshaded, blend_mix;

// Solid metric-box tint — bypasses default particle texture/vertex color modulation.
uniform vec4 box_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	COLOR = box_color;
}
