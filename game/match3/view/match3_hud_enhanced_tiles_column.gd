class_name Match3HudEnhancedTilesColumn
extends VBoxContainer

## Enhanced floor-type pool counts (Ephemeral.match3.floorModifierPool) — middle rail.

const TOOLTIP_SCENE := preload("res://game/ui/widgets/tooltip_popup.tscn")
const UltraUiFx = preload("res://game/ui/widgets/ultra_ui_fx.gd")
const Match3FloorSpritesScript = preload("res://game/match3/view/match3_floor_sprites.gd")
const Match3GameSpeedScript = preload("res://game/match3/core/match3_game_speed.gd")
const FloorTriggerFlashShader = preload("res://game/match3/view/match3_floor_trigger_flash.gdshader")
const COUNT_FONT := preload("res://assets/fonts/Comic Lemon.otf")
const COUNT_FONT_SIZE := 22
const ROW_GAP := Match3Hud.LEFT_RAIL_GAP
const ICON_SCALE := 0.88
const TRIGGER_PEAK_SCALE := 1.18
const TRIGGER_JUICE_SEC := 0.42

var _service: GnosisService = null
var _tooltip: TooltipPopup = null
var _row_nodes: Array[Control] = []
var _last_signature := "__unset__"
var _trigger_juice_tweens: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(ROW_GAP))
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(_on_rail_layout_changed)
	_build_tooltip()
	set_process(true)


func apply_left_rail_pack(slot: float, gap: float) -> void:
	add_theme_constant_override("separation", int(round(gap)))
	# Slot size is read via _rail_icon_size; stash on meta for that path.
	set_meta(&"left_rail_slot", slot)
	set_meta(&"left_rail_gap", gap)


func bind_service(service: GnosisService) -> void:
	_service = service
	_last_signature = "__unset__"
	_refresh()


func force_refresh() -> void:
	_last_signature = "__unset__"
	_refresh()


func play_trigger_juice(type_id: String) -> void:
	var id := type_id.strip_edges()
	if id.is_empty():
		return
	var row := _row_for_type_id(id)
	if row == null or not is_instance_valid(row):
		return
	var icon := row.get_node_or_null("Icon") as Control
	var target: Control = icon if icon else row
	_play_trigger_juice_on_control(target, id.to_lower())


func _process(_delta: float) -> void:
	if _should_skip_live_refresh():
		_hide_tooltip()
		return
	_refresh_if_changed()


func _should_skip_live_refresh() -> bool:
	if _service == null:
		return false
	if _service.has_method("is_consumable_use_presentation_active"):
		return _service.is_consumable_use_presentation_active()
	return false


func _relayout_row_sizes() -> void:
	var icon_size := _rail_icon_size()
	if icon_size < 8.0:
		return
	var draw_size := icon_size * ICON_SCALE
	for row in _row_nodes:
		if not is_instance_valid(row):
			continue
		row.custom_minimum_size = Vector2(icon_size, icon_size)
		var icon := row.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.custom_minimum_size = Vector2(draw_size, draw_size)
		for child in row.get_children():
			if child is Label:
				child.offset_left = -icon_size * 0.62
				child.offset_top = -icon_size * 0.46


func _refresh_if_changed() -> void:
	var signature := _build_signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	_refresh()


func _refresh() -> void:
	for row in _row_nodes:
		if row != null and is_instance_valid(row):
			var parent := row.get_parent()
			if parent:
				parent.remove_child(row)
			row.free()
	_row_nodes.clear()
	for child in get_children():
		if child is Control:
			remove_child(child)
			child.free()
	_hide_tooltip()
	var rows := _enhanced_pool_rows()
	visible = not rows.is_empty()
	for row_data in rows:
		_row_nodes.append(_make_row(row_data))
	call_deferred("_relayout_row_sizes")


func _enhanced_pool_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _service == null:
		return out
	var counts: Dictionary = {}
	if _service.has_method("get_enhanced_floor_tile_counts"):
		counts = _service.get_enhanced_floor_tile_counts()
	elif _service.context != null and _service.context.state != null:
		var m3 := _service.context.state.root.get_node("Ephemeral").get_node("match3")
		if m3.is_valid():
			var pool := m3.get_node("floorModifierPool")
			if pool.is_valid() and pool.get_type() == GnosisValueType.OBJECT:
				for type_id in _enhanced_floor_type_ids():
					var count_node := pool.get_node(type_id)
					var count := int(count_node.value) if count_node.is_valid() and count_node.value != null else 0
					if count > 0:
						counts[type_id] = count
	var type_ids: Array = counts.keys()
	type_ids.sort()
	for type_id in type_ids:
		var id := str(type_id).strip_edges()
		var count := int(counts[type_id])
		if id.is_empty() or count <= 0:
			continue
		out.append({
			"typeId": id,
			"count": count,
			"name": _localized_floor_name(id),
			"description": _localized_floor_description(id),
			"icon": _resolve_floor_sprite(id),
		})
	return out


func _enhanced_floor_type_ids() -> Array[String]:
	var out: Array[String] = []
	var config := _floor_types_catalog()
	if not config.is_valid() or config.get_type() != GnosisValueType.OBJECT:
		return out
	for type_id in config.get_keys():
		var id := str(type_id).strip_edges()
		if id.is_empty():
			continue
		var row := config.get_node(id)
		if not row.is_valid() or row.get_type() != GnosisValueType.OBJECT:
			continue
		var props := row.get_node("properties")
		if not props.is_valid():
			continue
		var tags := props.get_node("gameplayTags")
		if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST:
			continue
		for i in tags.get_count():
			if str(tags.get_node(i).value).strip_edges().to_lower() == "enhanced":
				out.append(id)
				break
	out.sort()
	return out


func _make_row(details: Dictionary) -> Control:
	var icon_size := _rail_icon_size()
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(icon_size, icon_size)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.set_meta(&"floor_type_id", str(details.get("typeId", "")))

	var icon := TextureRect.new()
	icon.name = &"Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_right = 0.0
	icon.offset_bottom = 0.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(icon_size * ICON_SCALE, icon_size * ICON_SCALE)
	var tex: Texture2D = details.get("icon", null)
	if tex:
		icon.texture = tex
		icon.modulate = Color.WHITE
	else:
		icon.texture = null
		icon.modulate = Color(1, 1, 1, 0.2)
	row.add_child(icon)

	var count := Label.new()
	count.text = str(details.get("count", 0))
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -icon_size * 0.62
	count.offset_top = -icon_size * 0.46
	count.offset_right = 4.0
	count.offset_bottom = 0.0
	count.add_theme_font_override("font", COUNT_FONT)
	count.add_theme_font_size_override("font_size", COUNT_FONT_SIZE)
	count.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	count.z_index = 1
	row.add_child(count)

	var hit := Button.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.offset_right = 0.0
	hit.offset_bottom = 0.0
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var name_text := str(details.get("name", ""))
	var desc_text := str(details.get("description", ""))
	hit.mouse_entered.connect(func() -> void: _show_tooltip(name_text, desc_text, row))
	hit.mouse_exited.connect(_hide_tooltip)
	row.add_child(hit)
	add_child(row)
	return row


func _rail_icon_size() -> float:
	var count := _enhanced_pool_rows().size()
	if count <= 0:
		count = maxi(_row_nodes.size(), 1)
	var available_h := size.y
	if available_h < 8.0:
		var parent := get_parent() as Control
		if parent and parent.size.y >= 8.0:
			available_h = parent.size.y
	var pack := Match3Hud.left_rail_pack_metrics(
		Match3Hud.left_rail_slot_extent_for(self),
		available_h,
		count,
		ROW_GAP
	)
	apply_left_rail_pack(pack.x, pack.y)
	return pack.x


func _on_rail_layout_changed() -> void:
	_relayout_row_sizes()


func _build_signature() -> String:
	var parts: PackedStringArray = []
	for row in _enhanced_pool_rows():
		parts.append("%s:%d" % [row.get("typeId", ""), int(row.get("count", 0))])
	return "|".join(parts)


func _row_for_type_id(type_id: String) -> Control:
	var needle := type_id.strip_edges().to_lower()
	if needle.is_empty():
		return null
	for row in _row_nodes:
		if not is_instance_valid(row):
			continue
		var row_id := str(row.get_meta(&"floor_type_id", "")).strip_edges().to_lower()
		if row_id == needle:
			return row
	return null


func _play_trigger_juice_on_control(control: Control, tween_key: String) -> void:
	if control == null or not is_instance_valid(control):
		return
	if _trigger_juice_tweens.has(tween_key):
		var old: Tween = _trigger_juice_tweens[tween_key]
		if old != null and old.is_running():
			old.kill()
	control.scale = Vector2.ONE
	if control.size.x > 1.0 and control.size.y > 1.0:
		control.pivot_offset = control.size * 0.5

	var flash_mat: ShaderMaterial = null
	if FloorTriggerFlashShader != null and control is TextureRect and (control as TextureRect).texture != null:
		flash_mat = ShaderMaterial.new()
		flash_mat.shader = FloorTriggerFlashShader
		flash_mat.set_shader_parameter("flash", 0.0)
		control.material = flash_mat

	var engine := Match3GameSpeedScript.engine_from_node(self)
	var juice_sec := Match3GameSpeedScript.scale_duration(engine, TRIGGER_JUICE_SEC, 0.18)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_trigger_juice_tweens[tween_key] = tw
	tw.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(control):
				return
			var wave := sin(PI * clampf(t, 0.0, 1.0))
			control.scale = Vector2.ONE * lerpf(1.0, TRIGGER_PEAK_SCALE, wave)
			if flash_mat != null:
				flash_mat.set_shader_parameter("flash", wave),
		0.0,
		1.0,
		juice_sec
	).set_trans(Tween.TRANS_LINEAR)
	tw.finished.connect(
		func() -> void:
			if is_instance_valid(control):
				control.scale = Vector2.ONE
				if control.material == flash_mat:
					control.material = null
			if _trigger_juice_tweens.get(tween_key) == tw:
				_trigger_juice_tweens.erase(tween_key)
	)


func _resolve_floor_sprite(type_id: String) -> Texture2D:
	var sprite_id := _metadata_string(type_id, "spriteId")
	var tex := Match3FloorSpritesScript.texture_for_floor_type(type_id, sprite_id)
	if tex:
		return tex
	var registry := _asset_registry()
	if registry and not sprite_id.is_empty():
		return registry.get_sprite(sprite_id)
	return null


func _localized_floor_name(type_id: String) -> String:
	return _localized(_metadata_string(type_id, "nameKey"), type_id)


func _localized_floor_description(type_id: String) -> String:
	return _localized(_metadata_string(type_id, "descriptionKey"), "")


func _metadata_string(type_id: String, key: String) -> String:
	if _service == null or _service.context == null:
		return ""
	var config := _floor_types_catalog()
	if not config.is_valid():
		return ""
	var row := config.get_node(type_id)
	if not row.is_valid():
		return ""
	var metadata := row.get_node("metadata")
	if not metadata.is_valid():
		return ""
	var node := metadata.get_node(key)
	if node.is_valid() and node.value != null:
		return str(node.value).strip_edges()
	return ""


func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty():
		return fallback
	if _service == null or _service.context == null or _service.context.engine == null:
		return fallback
	var loc = _service.context.engine.get_service("Localization")
	if loc == null or not loc.has_method("get_string_value"):
		return fallback
	return loc.get_string_value(key, fallback)


func _build_tooltip() -> void:
	_tooltip = TOOLTIP_SCENE.instantiate()
	add_child(_tooltip)
	_tooltip.top_level = true
	_tooltip.z_index = 60
	_tooltip.scale = Vector2.ZERO
	_tooltip.visible = false


func _show_tooltip(title: String, body: String, anchor: Control) -> void:
	if _tooltip == null or anchor == null or not is_instance_valid(anchor):
		return
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -4.0)
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip.visible = true
	_tooltip.set_content(title, body)
	_tooltip.reset_size()
	TooltipPopup.position_at_anchor(_tooltip, anchor, TooltipPopup.PIVOT_SIDE.RIGHT, 10.0)
	_tooltip.appear()


func _hide_tooltip() -> void:
	if _tooltip:
		_tooltip.disappear()


func _floor_types_catalog() -> GnosisNode:
	if _service == null:
		return GnosisNode.new(null)
	var config := _service.get_node("configuration", true)
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node("match3CellFloorTypes")


func _asset_registry() -> GnosisAssetRegistry:
	var host := UltraUiFx.resolve_host(self)
	if host:
		return host.asset_registry
	return null
