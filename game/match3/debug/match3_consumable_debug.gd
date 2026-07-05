class_name Match3ConsumableDebug
extends RefCounted

## Verbose, phase-numbered tracing for pre-play / in-run consumable use.
## Set ENABLED=false (or env ULTRA_CONSUMABLE_DEBUG=0) once the bug is found.

const PREFIX := "[CONSUMABLE_DBG]"
const LOG_FILE := "user://consumable_debug.log"

static var ENABLED := true
static var LOG_TO_FILE := false
static var INCLUDE_STACK := false
static var MAX_STACK_FRAMES := 10

static var _seq := 0
static var _active_use_id := -1
static var _active_consumable_id := ""
static var _active_slot_index := -1
static var _phase_counter := 0
static var _file_ready := false
static var _banner_shown := false


static func is_enabled() -> bool:
	if not ENABLED:
		return false
	var env := OS.get_environment("ULTRA_CONSUMABLE_DEBUG").strip_edges().to_lower()
	if env == "0" or env == "false" or env == "off":
		return false
	return true


## Called from engine addon code that cannot preload this script directly.
static func log_external(site: String, message: String) -> void:
	log_msg(-1, site, message)


static func begin_use(consumable_id: String, slot_index: int, extra: Dictionary = {}) -> int:
	if not is_enabled():
		return -1
	_seq += 1
	_active_use_id = _seq
	_active_consumable_id = consumable_id
	_active_slot_index = slot_index
	_phase_counter = 0
	var parts: PackedStringArray = []
	for key in extra.keys():
		parts.append("%s=%s" % [str(key), str(extra[key])])
	var extra_text := "" if parts.is_empty() else " | " + ", ".join(parts)
	log_msg(_active_use_id, "BEGIN", "consumable=%s slot=%d%s" % [consumable_id, slot_index, extra_text])
	return _active_use_id


static func end_use(outcome: String, extra: Dictionary = {}) -> void:
	if not is_enabled() or _active_use_id < 0:
		return
	var parts: PackedStringArray = [outcome]
	for key in extra.keys():
		parts.append("%s=%s" % [str(key), str(extra[key])])
	log_msg(_active_use_id, "END", ", ".join(parts))
	_active_use_id = -1
	_active_consumable_id = ""
	_active_slot_index = -1
	_phase_counter = 0


static func phase(site: String, detail: String, service = null, column = null, dispatcher = null) -> void:
	if not is_enabled():
		return
	_phase_counter += 1
	var ctx := _format_context(service, column, dispatcher)
	log_msg(_active_use_id, "P%02d %s" % [_phase_counter, site], "%s%s" % [detail, ctx])


static func log_msg(use_id: int, tag: String, message: String) -> void:
	if not is_enabled():
		return
	if not _banner_shown:
		_banner_shown = true
		print("%s === consumable tracing ON (filter console with '%s') log=%s ===" % [PREFIX, PREFIX, LOG_FILE])
	var ms := Time.get_ticks_msec()
	var id_part := "#%d" % use_id if use_id >= 0 else "#--"
	var active_part := ""
	if _active_use_id >= 0 and use_id != _active_use_id:
		active_part = " (active=#%d %s)" % [_active_use_id, _active_consumable_id]
	var stack_part := ""
	if INCLUDE_STACK:
		stack_part = "\n    stack: %s" % stack_top(MAX_STACK_FRAMES)
	var line := "%s t=%dms %s [%s] %s%s%s" % [PREFIX, ms, id_part, tag, message, active_part, stack_part]
	print(line)
	_write_file(line)


static func warn(site: String, message: String) -> void:
	if not is_enabled():
		return
	var line := "%s WARN [%s] %s | stack: %s" % [PREFIX, site, message, stack_top(6)]
	push_warning(line)
	print(line)
	_write_file(line)


static func fatal(site: String, message: String) -> void:
	if not is_enabled():
		return
	var line := "%s FATAL [%s] %s | stack: %s" % [PREFIX, site, message, stack_top(12)]
	push_error(line)
	print(line)
	_write_file(line)


static func stack_top(max_depth: int = 8) -> String:
	var frames := get_stack()
	if frames.size() <= 1:
		return "(no stack)"
	var parts: PackedStringArray = []
	var limit := mini(frames.size(), max_depth + 1)
	for i in range(1, limit):
		var frame: Dictionary = frames[i]
		var source := str(frame.get("source", "?"))
		if source.begins_with("res://"):
			source = source.trim_prefix("res://")
		parts.append("%s:%d %s()" % [source, int(frame.get("line", 0)), str(frame.get("function", "?"))])
	return " <- ".join(parts)


static func service_snapshot(service) -> String:
	if service == null:
		return "service=null"
	var parts: PackedStringArray = []
	if service.has_method("is_consumable_use_presentation_active"):
		parts.append("presentation=%s" % str(service.is_consumable_use_presentation_active()))
	if service.has_method("get_current_status"):
		parts.append("status=%d" % int(service.get_current_status()))
	if service.has_method("get_current_round"):
		parts.append("round=%d" % int(service.get_current_round()))
	if service.has_method("_is_board_grid_ready"):
		parts.append("grid_ready=%s" % str(service._is_board_grid_ready()))
	elif service.has_method("get_gameplay"):
		var gp = service.get_gameplay()
		if gp != null and gp.has_method("is_grid_allocated"):
			parts.append("grid_allocated=%s" % str(gp.is_grid_allocated()))
	if service.has_method("get_gameplay"):
		var gp2 = service.get_gameplay()
		if gp2 != null:
			parts.append("board=%dx%d" % [int(gp2.width), int(gp2.height)])
	if service.has_method("_consumable_list_count"):
		parts.append("bag_count=%d" % int(service._consumable_list_count()))
	return "{%s}" % ", ".join(parts)


static func column_snapshot(column) -> String:
	if column == null:
		return "column=null"
	var parts: PackedStringArray = []
	if "_juice_running" in column:
		parts.append("juice=%s" % str(column._juice_running))
	if "_defer_inventory_refresh" in column:
		parts.append("defer=%s" % str(column._defer_inventory_refresh))
	if "_drag_active" in column:
		parts.append("drag=%s" % str(column._drag_active))
	if column.has_method("get"):
		var slots = column.get("_slot_nodes")
		if slots is Array:
			parts.append("slots=%d" % slots.size())
	if "_last_signature" in column:
		parts.append("sig=%s" % str(column._last_signature).substr(0, 48))
	return "{%s}" % ", ".join(parts)


static func dispatcher_snapshot(dispatcher) -> String:
	if dispatcher == null:
		return "dispatcher=null"
	var parts: PackedStringArray = []
	if "_busy" in dispatcher:
		parts.append("busy=%s" % str(dispatcher._busy))
	if "_width" in dispatcher:
		parts.append("view=%dx%d" % [int(dispatcher._width), int(dispatcher._height)])
	if dispatcher.has_method("is_busy"):
		parts.append("is_busy=%s" % str(dispatcher.is_busy()))
	return "{%s}" % ", ".join(parts)


static func slot_snapshot(slot: Control) -> String:
	if slot == null:
		return "slot=null"
	if not is_instance_valid(slot):
		return "slot=FREED"
	var parent_name: String = slot.get_parent().name if slot.get_parent() else "none"
	return "slot(id=%d valid=%s parent=%s pos=%s size=%s)" % [
		slot.get_instance_id(),
		str(is_instance_valid(slot)),
		parent_name,
		str(slot.global_position),
		str(slot.size),
	]


static func _format_context(service, column, dispatcher) -> String:
	var chunks: PackedStringArray = []
	if service != null:
		chunks.append("svc=" + service_snapshot(service))
	if column != null:
		chunks.append("col=" + column_snapshot(column))
	if dispatcher != null:
		chunks.append("disp=" + dispatcher_snapshot(dispatcher))
	if chunks.is_empty():
		return ""
	return " | " + " ".join(chunks)


static func _write_file(line: String) -> void:
	if not LOG_TO_FILE:
		return
	if not _file_ready:
		_file_ready = true
		var clear := FileAccess.open(LOG_FILE, FileAccess.WRITE)
		if clear:
			clear.store_line("# consumable debug log started t=%d" % Time.get_ticks_msec())
			clear.close()
	var file := FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line.replace("\n    stack:", " | stack:"))
	file.close()
