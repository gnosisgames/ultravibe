class_name UltraDebugInfoOverlay
extends CanvasLayer

## Top-right developer readout driven by the Advanced settings tab:
## FPS, game build version, and device info. Each line is gated by its own
## Persistent.settings.* flag and polled so it reflects toggles immediately.
## Rendered as right-aligned rich text (no panel) with an outline for contrast.
##
## The FPS block mirrors the Unity GnosisFPSCounter: realtime FPS + frame time,
## rolling average, min/max since start, and per-level color coding.

const SHOW_FPS_KEY := "Persistent.settings.showFps"
const SHOW_VERSION_KEY := "Persistent.settings.showVersion"
const SHOW_DEVICE_INFO_KEY := "Persistent.settings.showDeviceInfo"

const SAMPLE_INTERVAL := 0.5
const WARNING_FPS := 50
const CRITICAL_FPS := 20
const AVERAGE_SAMPLES := 50
const MINMAX_INTERVALS_TO_SKIP := 3

const COLOR_NORMAL := Color(0.333333, 0.854902, 0.4, 1.0)
const COLOR_WARNING := Color(0.925490, 0.878431, 0.345098, 1.0)
const COLOR_CRITICAL := Color(0.976471, 0.356863, 0.356863, 1.0)
const COLOR_CREAM := Color(1, 1, 1, 1)
const COLOR_RENDER := Color(0.654902, 0.431373, 0.819608, 1.0)

var _engine: GnosisEngine = null
var _rich: RichTextLabel = null

var _interval_time := 0.0
var _interval_frames := 0
var _cur_fps := 0.0
var _cur_ms := 0.0
var _avg_raw := -1.0
var _avg_samples := 0
var _min_fps := -1
var _max_fps := -1
var _intervals_skipped := 0

func _ready() -> void:
	layer = 90
	_rich = RichTextLabel.new()
	_rich.bbcode_enabled = true
	_rich.fit_content = true
	_rich.scroll_active = false
	_rich.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rich.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rich.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_rich.offset_top = 16.0
	_rich.offset_right = -16.0
	_rich.custom_minimum_size = Vector2(360, 0)
	_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich.add_theme_color_override("default_color", COLOR_CREAM)
	_rich.add_theme_color_override("font_outline_color", Color(0.0784314, 0.137255, 0.227451, 1.0))
	_rich.add_theme_constant_override("outline_size", 6)
	_rich.add_theme_font_size_override("normal_font_size", 18)
	_rich.visible = false
	add_child(_rich)
	set_process(true)

func bind_engine(engine: GnosisEngine) -> void:
	_engine = engine
	_refresh()

func _process(delta: float) -> void:
	_interval_time += delta
	_interval_frames += 1
	if _interval_time < SAMPLE_INTERVAL:
		return
	_sample_fps()
	_interval_time = 0.0
	_interval_frames = 0
	_refresh()

func _sample_fps() -> void:
	if _interval_time <= 0.0:
		return
	_cur_fps = _interval_frames / _interval_time
	_cur_ms = 1000.0 / _cur_fps if _cur_fps > 0.0 else 0.0
	var rounded := int(round(_cur_fps))

	# Rolling average (matches the Unity sample-window blend).
	if _avg_raw < 0.0:
		_avg_raw = rounded
		_avg_samples = 1
	else:
		_avg_samples += 1
		var divisor := AVERAGE_SAMPLES + 1 if _avg_samples > AVERAGE_SAMPLES else _avg_samples
		_avg_raw += (rounded - _avg_raw) / float(divisor)

	# Skip the first few intervals so startup spikes don't poison min/max.
	if _intervals_skipped < MINMAX_INTERVALS_TO_SKIP:
		_intervals_skipped += 1
		return
	if _min_fps < 0 or rounded < _min_fps:
		_min_fps = rounded
	if _max_fps < 0 or rounded > _max_fps:
		_max_fps = rounded

func _refresh() -> void:
	if _rich == null:
		return
	if _is_splash_active():
		_rich.visible = false
		return
	var blocks: PackedStringArray = []
	if _flag(SHOW_FPS_KEY):
		blocks.append(_fps_block())
	if _flag(SHOW_VERSION_KEY):
		blocks.append(_cream(UltravibeGameInfo.display_version()))
	if _flag(SHOW_DEVICE_INFO_KEY):
		blocks.append(_cream("\n".join(_device_info_lines())))
	if blocks.is_empty():
		_rich.visible = false
		return
	_rich.visible = true
	_rich.text = "[right]%s[/right]" % "\n".join(blocks)

func _fps_block() -> String:
	var fps := int(round(_cur_fps))
	var fps_hex := _level_color(fps).to_html(false)
	var line := "[color=#%s]FPS: %d [%.1f MS][/color]" % [fps_hex, fps, _cur_ms]

	var avg := int(round(_avg_raw)) if _avg_raw >= 0.0 else fps
	var avg_ms := 1000.0 / avg if avg > 0 else 0.0
	line += "\n[color=#%s]AVG: %d [%.1f MS][/color]" % [_level_color(avg).to_html(false), avg, avg_ms]

	if _min_fps >= 0 and _max_fps >= 0:
		line += "\n[color=#%s]MIN: %d[/color]  [color=#%s]MAX: %d[/color]" % [
			_level_color(_min_fps).to_html(false), _min_fps,
			_level_color(_max_fps).to_html(false), _max_fps,
		]
	return line

func _level_color(fps: int) -> Color:
	if fps <= CRITICAL_FPS:
		return COLOR_CRITICAL
	if fps < WARNING_FPS:
		return COLOR_WARNING
	return COLOR_NORMAL

func _cream(text: String) -> String:
	return "[color=#%s]%s[/color]" % [COLOR_CREAM.to_html(false), text]

func _flag(path: String) -> bool:
	if _engine == null:
		return false
	var node := _engine.state.root.get_node(path)
	return bool(node.value) if node.is_valid() and node.value != null else false


func _is_splash_active() -> bool:
	if _engine == null:
		return false
	var ui := _engine.get_service("GameUI") as GnosisGameUIService
	if ui == null:
		return false
	return ui.get_base_view_id().strip_edges().to_lower() == "splash"

## Mirrors the Unity GnosisDeviceInfo readout as closely as Godot's APIs allow.
## (Godot does not expose shader model or total VRAM, so those are omitted.)
func _device_info_lines() -> PackedStringArray:
	var lines: PackedStringArray = []

	var os_name := OS.get_name()
	var os_version := OS.get_version()
	var distro := OS.get_distribution_name()
	var os_line := "OS: %s" % os_name
	if not distro.is_empty() and distro != os_name:
		os_line += " (%s)" % distro
	if not os_version.is_empty():
		os_line += " %s" % os_version
	os_line += " [%s]" % Engine.get_architecture_name()
	lines.append(os_line)

	var cpu := OS.get_processor_name().strip_edges()
	if cpu.is_empty():
		cpu = "Unknown CPU"
	lines.append("CPU: %s [%d cores]" % [cpu, OS.get_processor_count()])

	var gpu := RenderingServer.get_video_adapter_name()
	var vendor := RenderingServer.get_video_adapter_vendor()
	var gpu_line := "GPU: %s" % gpu
	if not vendor.is_empty():
		gpu_line += " (%s)" % vendor
	gpu_line += " [%s]" % _adapter_type_name(RenderingServer.get_video_adapter_type())
	lines.append(gpu_line)

	var api := RenderingServer.get_video_adapter_api_version()
	if not api.is_empty():
		lines.append("API: %s" % api)

	var vram_used := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	if vram_used > 0:
		lines.append("VRAM used: %d MB" % int(vram_used / 1048576))

	var mem := OS.get_memory_info()
	var physical := int(mem.get("physical", -1))
	if physical > 0:
		lines.append("RAM: %.1f GB" % (physical / 1073741824.0))

	var screen := DisplayServer.screen_get_size()
	var win := DisplayServer.window_get_size()
	var refresh := DisplayServer.screen_get_refresh_rate()
	var dpi := DisplayServer.screen_get_dpi()
	var scr_line := "SCR: %dx%d" % [screen.x, screen.y]
	if refresh > 0.0:
		scr_line += "@%dHz" % roundi(refresh)
	scr_line += " [win %dx%d" % [win.x, win.y]
	if dpi > 0:
		scr_line += ", %d DPI" % dpi
	scr_line += "]"
	lines.append(scr_line)

	lines.append("Godot %s  |  Gnosis v%s" % [Engine.get_version_info().get("string", "?"), GnosisEngine.VERSION])
	return lines

func _adapter_type_name(adapter_type: int) -> String:
	match adapter_type:
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			return "Integrated"
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			return "Discrete"
		RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
			return "Virtual"
		RenderingDevice.DEVICE_TYPE_CPU:
			return "CPU"
		_:
			return "Other"
