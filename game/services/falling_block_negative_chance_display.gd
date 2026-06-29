class_name FallingBlockNegativeChanceDisplay
extends RefCounted

## Maps negativeUltravibeChance percent to the 0001-9999 HUD readout (run min ->
## max). Pure port of FallingBlockNegativeChanceDisplay.cs.

const HUD_DISPLAY_MIN := 1
const HUD_DISPLAY_MAX := 9999

const DEFAULT_MIN_PERCENT := 1
const DEFAULT_MAX_PERCENT := 25

static func percent_to_hud_display(
	percent_chance: int,
	min_percent: int = DEFAULT_MIN_PERCENT,
	max_percent: int = DEFAULT_MAX_PERCENT
) -> int:
	min_percent = maxi(0, min_percent)
	max_percent = maxi(min_percent, max_percent)
	if max_percent <= min_percent:
		return HUD_DISPLAY_MAX if percent_chance >= max_percent else HUD_DISPLAY_MIN
	var t := clampf(inverse_lerp(float(min_percent), float(max_percent), float(percent_chance)), 0.0, 1.0)
	var display := int(round(lerpf(float(HUD_DISPLAY_MIN), float(HUD_DISPLAY_MAX), t)))
	return clampi(display, HUD_DISPLAY_MIN, HUD_DISPLAY_MAX)
