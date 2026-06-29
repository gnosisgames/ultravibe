class_name UltraDisplaySettings
extends Node

## Single owner for applying the persistent display/video settings to Godot.
##
## The Unity build drove these through dedicated components (VsyncComponent,
## resolution/monitor/window-mode coordinators, CRT post-process); none of that
## was ported, so the flags in Persistent.settings.* were dead. This node:
##   - enumerates the real monitors / resolutions / refresh rates at startup and
##     writes them into the settings option lists (so the Video tab dropdowns
##     have live data), and
##   - applies windowMode, vsyncEnabled, framerateCap, resolution, displayIndex,
##     and the Filter values (crtFilterEnabled, crtScanlinesStrength, vignetteIntensity) to the
##     scanline + vignette CRT shader material.
## Values are polled so changes from the Video tab take effect live.

const POLL_INTERVAL := 0.4

# Normalized (0..1) defaults for the subtle old-TV look.
const DEFAULT_SCANLINES := 0.0
const DEFAULT_VIGNETTE := 0.0
# Scanline density: lower Y gives chunkier, clearly visible lines.
const SCANLINE_RESOLUTION := Vector2(640.0, 240.0)

const STANDARD_RESOLUTIONS := [
	Vector2i(3840, 2160), Vector2i(2560, 1440), Vector2i(1920, 1080),
	Vector2i(1600, 900), Vector2i(1366, 768), Vector2i(1280, 720),
	Vector2i(1024, 576),
]

var crt_force_disabled := false

var _engine: GnosisEngine = null
var _crt_rect: ColorRect = null
var _crt_material: ShaderMaterial = null
var _accum := 0.0
var _last := {}

func set_crt_rect(rect: ColorRect) -> void:
	_crt_rect = rect
	if rect and rect.material is ShaderMaterial:
		_crt_material = rect.material as ShaderMaterial

func bind_engine(engine: GnosisEngine) -> void:
	_engine = engine
	if _is_headless():
		# Still drive the CRT material so headless render tests stay consistent,
		# but skip window/monitor mutations that need a real display.
		_apply_crt()
		return
	_enumerate_options()
	_apply_all(true)

func _process(delta: float) -> void:
	_accum += delta
	if _accum < POLL_INTERVAL:
		return
	_accum = 0.0
	if _engine and not _is_headless():
		_apply_all(false)

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

# --- Enumeration -----------------------------------------------------------

func _enumerate_options() -> void:
	var setting := _setting()
	if setting == null or _engine == null:
		return
	var store := _engine.store

	var screen_count := DisplayServer.get_screen_count()

	# Monitors.
	var monitors := store.create_list()
	for i in range(max(1, screen_count)):
		var sz := DisplayServer.screen_get_size(i)
		monitors.add("Display %d  (%d×%d)" % [i + 1, sz.x, sz.y])
	setting.replace_persistent_monitor_option_labels(monitors)

	# Resolutions: standard list capped to the active screen, plus its native size.
	var current_screen := DisplayServer.window_get_current_screen()
	var native := DisplayServer.screen_get_size(current_screen)
	var seen := {}
	var sizes: Array[Vector2i] = []
	if native.x > 0 and native.y > 0:
		sizes.append(native)
		seen[native] = true
	for res in STANDARD_RESOLUTIONS:
		if res.x <= native.x and res.y <= native.y and not seen.has(res):
			sizes.append(res)
			seen[res] = true
	var resolutions := store.create_list()
	for s in sizes:
		var obj := store.create_object()
		obj.set_key("text", "%d × %d" % [s.x, s.y])
		obj.set_key("width", s.x)
		obj.set_key("height", s.y)
		resolutions.add(obj)
	setting.replace_persistent_resolution_options_list(resolutions)

	# Refresh rates for the active screen.
	var rates := store.create_list()
	var hz := int(round(DisplayServer.screen_get_refresh_rate(current_screen)))
	if hz <= 0:
		hz = 60
	var rate_obj := store.create_object()
	rate_obj.set_key("text", "%d Hz" % hz)
	rate_obj.set_key("hz", hz)
	rates.add(rate_obj)
	setting.replace_persistent_refresh_rate_options_list(rates)

	# Clamp stored indices to the freshly built lists.
	_clamp_index("resolutionIndex", sizes.size())
	_clamp_index("displayIndex", max(1, screen_count))
	_clamp_index("refreshRateIndex", 1)

func _clamp_index(leaf: String, count: int) -> void:
	var idx := _read_int(leaf, 0)
	var clamped: int = clampi(idx, 0, max(0, count - 1))
	if clamped != idx:
		_setting().set_state_value("settings.%s" % leaf, clamped, true)

# --- Application -----------------------------------------------------------

func _apply_all(force: bool) -> void:
	_apply_window_mode(force)
	_apply_vsync(force)
	_apply_framerate_cap(force)
	_apply_monitor(force)
	_apply_resolution(force)
	_apply_crt()

func _changed(key: String, value: Variant) -> bool:
	if _last.has(key) and _last[key] == value:
		return false
	_last[key] = value
	return true

func _apply_window_mode(force: bool) -> void:
	var mode_index := _read_int("windowMode", 2)
	if not force and not _changed("windowMode", mode_index):
		return
	_last["windowMode"] = mode_index
	match mode_index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_vsync(force: bool) -> void:
	var enabled := _read_bool("vsyncEnabled", true)
	if not force and not _changed("vsync", enabled):
		return
	_last["vsync"] = enabled
	var mode := DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _apply_framerate_cap(force: bool) -> void:
	var vsync_on := _read_bool("vsyncEnabled", true)
	var cap := _read_int("framerateCap", 0)
	var state_key := "v%d_c%d" % [1 if vsync_on else 0, cap]
	if not force and not _changed("framerateCapEffective", state_key):
		return
	_last["framerateCapEffective"] = state_key
	# V-Sync already caps to the display refresh; ignore the stored cap while on.
	Engine.max_fps = 0 if vsync_on or cap <= 0 else cap

func _apply_monitor(force: bool) -> void:
	var idx := _read_int("displayIndex", 0)
	if not force and not _changed("displayIndex", idx):
		return
	_last["displayIndex"] = idx
	if idx >= 0 and idx < DisplayServer.get_screen_count():
		DisplayServer.window_set_current_screen(idx)

## Resolution only applies in windowed mode (fullscreen tracks the screen size).
func _apply_resolution(force: bool) -> void:
	var idx := _read_int("resolutionIndex", 0)
	var mode_index := _read_int("windowMode", 2)
	var key := "%d:%d" % [idx, mode_index]
	if not force and not _changed("resolution", key):
		return
	_last["resolution"] = key
	if mode_index != 0:
		return
	var options := _settings_node("resolutionOptions")
	if not options.is_valid() or options.get_type() != GnosisValueType.LIST:
		return
	if idx < 0 or idx >= options.get_count():
		return
	var entry := options.get_node(idx)
	var w := _node_int(entry, "width")
	var h := _node_int(entry, "height")
	if w > 0 and h > 0:
		DisplayServer.window_set_size(Vector2i(w, h))

## Drives only the scanline and vignette portions of the CRT overlay shader;
## every other effect (warp, grille, noise, aberration, discolor, roll, pixelate)
## is forced off so the filter is purely scanlines + vignette.
func _apply_crt() -> void:
	if _crt_material == null:
		return
	var enabled := _read_bool("crtFilterEnabled", false)
	var scanlines := _read_float("crtScanlinesStrength", DEFAULT_SCANLINES)
	var vignette := _read_float("vignetteIntensity", DEFAULT_VIGNETTE)

	var active := not crt_force_disabled and enabled and (scanlines > 0.01 or vignette > 0.01)
	if _crt_rect:
		_crt_rect.visible = active
	if not active:
		return

	_crt_material.set_shader_parameter("scanlines_opacity", scanlines)
	_crt_material.set_shader_parameter("scanlines_width", 0.25)
	_crt_material.set_shader_parameter("resolution", SCANLINE_RESOLUTION)
	_crt_material.set_shader_parameter("vignette_intensity", vignette)
	_crt_material.set_shader_parameter("vignette_opacity", 1.0)
	# Everything else off: this is a scanlines + vignette filter only.
	_crt_material.set_shader_parameter("warp_amount", 0.0)
	_crt_material.set_shader_parameter("grille_opacity", 0.0)
	_crt_material.set_shader_parameter("noise_opacity", 0.0)
	_crt_material.set_shader_parameter("static_noise_intensity", 0.0)
	_crt_material.set_shader_parameter("aberration", 0.0)
	_crt_material.set_shader_parameter("brightness", 1.0)
	_crt_material.set_shader_parameter("roll", false)
	_crt_material.set_shader_parameter("discolor", false)
	_crt_material.set_shader_parameter("pixelate", false)
	_crt_material.set_shader_parameter("clip_warp", false)

# --- Settings access -------------------------------------------------------

func _setting() -> GnosisSettingService:
	return _engine.get_service("Setting") as GnosisSettingService if _engine else null

func _settings_node(leaf: String) -> GnosisNode:
	if _engine == null:
		return GnosisNode.new(null)
	return _engine.state.root.get_node("Persistent.settings.%s" % leaf)

func _read_int(leaf: String, default_value: int) -> int:
	var node := _settings_node(leaf)
	if node.is_valid() and node.value != null and typeof(node.value) in [TYPE_INT, TYPE_FLOAT]:
		return int(node.value)
	return default_value

func _read_float(leaf: String, default_value: float) -> float:
	var node := _settings_node(leaf)
	if node.is_valid() and node.value != null and typeof(node.value) in [TYPE_INT, TYPE_FLOAT]:
		return float(node.value)
	return default_value

func _read_bool(leaf: String, default_value: bool) -> bool:
	var node := _settings_node(leaf)
	if node.is_valid() and node.value != null:
		return bool(node.value)
	return default_value

func _node_int(node: GnosisNode, key: String) -> int:
	var n := node.get_node(key)
	if n.is_valid() and n.value != null:
		return int(n.value)
	return 0
