shader_type canvas_item;

// Chunky-pixel snow: quantize the sampled UV to a coarse grid so the tiled snow
// reads as low-res pixel art (matching the old Unity board FX). pixel_size is the
// size of one "fat pixel" in source texels.
uniform float pixel_size : hint_range(1.0, 64.0) = 6.0;

void fragment() {
	vec2 tex_px = vec2(textureSize(TEXTURE, 0));
	vec2 grid = max(pixel_size, 1.0) / tex_px;
	vec2 quantized = (floor(UV / grid) + 0.5) * grid;
	COLOR = texture(TEXTURE, quantized) * COLOR;
}
