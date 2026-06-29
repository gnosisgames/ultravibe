class_name FallingBlockFallSpeedDisplay
extends RefCounted

## Maps FallingBlockGravityCurve seconds-per-cell to the 0001-9999 HUD readout.
## Pure port of FallingBlockFallSpeedDisplay.cs.

const HUD_DISPLAY_MIN := 1
const HUD_DISPLAY_MAX := 9999

static func seconds_per_cell_to_hud_display(
	seconds_per_cell: float,
	difficulty_id: String = FallingBlockGravityCurve.DIFFICULTY_DEFAULT
) -> int:
	var display_range := FallingBlockGravityCurve.get_hud_display_range(difficulty_id)
	var slowest: float = display_range["slowest"]
	var fastest: float = display_range["fastest"]
	if fastest >= slowest:
		return HUD_DISPLAY_MAX
	var t := clampf(inverse_lerp(slowest, fastest, seconds_per_cell), 0.0, 1.0)
	var display := int(round(lerpf(float(HUD_DISPLAY_MIN), float(HUD_DISPLAY_MAX), t)))
	return clampi(display, HUD_DISPLAY_MIN, HUD_DISPLAY_MAX)
