class_name PlayHudAbilityCycler
extends Control

## Center bottom-bar zone: prev / current / next ability icons. Click a faded
## side icon to cycle it into focus (with a short tween); click the centered
## icon to use the selected ability.

const TOOLTIP_SCENE := preload("res://game/ui/widgets/tooltip_popup.tscn")
const ICON_ROOT := "res://assets/icons/abilities/"

@export var zone_width: float = 320.0
@export var center_size: float = 72.0
@export var side_size: float = 48.0
@export var side_alpha: float = 0.45
@export var transition_duration: float = 0.18
## How dim an icon gets while the shared cooldown is charging (fraction of its
## normal opacity). The bright "regenerated" copy fills up from the bottom.
@export_range(0.0, 1.0) var cooldown_charging_alpha: float = 0.3

var _service: FallingBlockService = null
var _tooltip: TooltipPopup = null
var _prev_icon: TextureRect = null
var _current_icon: TextureRect = null
var _next_icon: TextureRect = null
var _prev_hit: Button = null
var _current_hit: Button = null
var _next_hit: Button = null
var _prev_fill_clip: Control = null
var _current_fill_clip: Control = null
var _next_fill_clip: Control = null
var _prev_fill: TextureRect = null
var _current_fill: TextureRect = null
var _next_fill: TextureRect = null
var _cooldown_label: Label = null
var _last_signature := "__unset__"
var _tween: Tween = null
var _was_on_cooldown := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(zone_width, center_size + 16.0)
	_build_ui()
	_build_tooltip()
	set_process(true)

func bind_service(service: FallingBlockService) -> void:
	_service = service
	_last_signature = "__unset__"
	_refresh()

func _build_ui() -> void:
	_prev_icon = _make_icon_rect("PrevIcon", side_size, side_alpha)
	_current_icon = _make_icon_rect("CurrentIcon", center_size, 1.0)
	_next_icon = _make_icon_rect("NextIcon", side_size, side_alpha)
	add_child(_prev_icon)
	add_child(_current_icon)
	add_child(_next_icon)

	# Bright "regenerating" fill copies, revealed from the bottom while charging.
	# Added after the base icons so they draw on top of them.
	_prev_fill_clip = _make_fill_clip("PrevFillClip")
	_current_fill_clip = _make_fill_clip("CurrentFillClip")
	_next_fill_clip = _make_fill_clip("NextFillClip")
	_prev_fill = _prev_fill_clip.get_node("Fill")
	_current_fill = _current_fill_clip.get_node("Fill")
	_next_fill = _next_fill_clip.get_node("Fill")
	add_child(_prev_fill_clip)
	add_child(_current_fill_clip)
	add_child(_next_fill_clip)

	_prev_hit = _make_hit_button("PrevHit", side_size)
	_current_hit = _make_hit_button("CurrentHit", center_size)
	_next_hit = _make_hit_button("NextHit", side_size)
	_prev_hit.pressed.connect(_on_prev_pressed)
	_current_hit.pressed.connect(_on_current_pressed)
	_next_hit.pressed.connect(_on_next_pressed)
	_current_hit.mouse_entered.connect(_on_current_hovered)
	_current_hit.mouse_exited.connect(_hide_tooltip)
	add_child(_prev_hit)
	add_child(_current_hit)
	add_child(_next_hit)

	_cooldown_label = _make_cooldown_label()
	add_child(_cooldown_label)

	call_deferred("_layout_icons")

## A clip container holding a full-bright copy of an icon. The container is sized
## to reveal only the bottom fraction of the icon, so cooldown "fills up".
func _make_fill_clip(node_name: String) -> Control:
	var clip := Control.new()
	clip.name = node_name
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.visible = false
	var fill := TextureRect.new()
	fill.name = "Fill"
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(fill)
	return clip

func _make_cooldown_label() -> Label:
	var l := Label.new()
	l.name = "CooldownText"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l

func _make_icon_rect(node_name: String, size: float, alpha: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1, 1, 1, alpha)
	icon.pivot_offset = Vector2(size * 0.5, size * 0.5)
	return icon

func _make_hit_button(node_name: String, size: float) -> Button:
	var hit := Button.new()
	hit.name = node_name
	hit.custom_minimum_size = Vector2(size, size)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	return hit

func _build_tooltip() -> void:
	_tooltip = TOOLTIP_SCENE.instantiate()
	add_child(_tooltip)
	_tooltip.top_level = true
	_tooltip.z_index = 60
	_tooltip.scale = Vector2.ZERO
	_tooltip.visible = false

func _process(_delta: float) -> void:
	_refresh_if_changed()
	_update_cooldown_visual()
	if _tooltip and _tooltip.visible:
		_tooltip.reset_size()
		_position_tooltip()

## Drives the shared-cooldown look every frame: dims each owned ability icon and
## reveals a bright copy from the bottom up as the cooldown regenerates. Applies
## to prev/current/next together, since the cooldown is shared across all of them.
func _update_cooldown_visual() -> void:
	var has_abilities := not _ability_ids().is_empty()
	var total := 0.0
	var remaining := 0.0
	if _service:
		total = _service.get_ability_cooldown_total_seconds()
		remaining = _service.get_ability_cooldown_remaining_seconds()
	var on_cd := has_abilities and total > 0.0 and remaining > 0.0
	var ready_frac := clampf(1.0 - remaining / total, 0.0, 1.0) if total > 0.0 else 0.0

	_apply_cooldown_to_icon(_current_icon, _current_fill_clip, _current_fill, on_cd, ready_frac, 1.0)
	_apply_cooldown_to_icon(_prev_icon, _prev_fill_clip, _prev_fill, on_cd, ready_frac, side_alpha)
	_apply_cooldown_to_icon(_next_icon, _next_fill_clip, _next_fill, on_cd, ready_frac, side_alpha)

	if _cooldown_label:
		if on_cd and _current_icon and _current_icon.visible:
			var r := _current_icon.get_rect()
			var lw := 34.0
			var lh := 22.0
			_cooldown_label.text = str(int(ceil(remaining)))
			_cooldown_label.size = Vector2(lw, lh)
			_cooldown_label.position = Vector2(r.position.x + r.size.x - lw + 3.0, r.position.y + r.size.y - lh + 3.0)
			_cooldown_label.visible = true
		else:
			_cooldown_label.visible = false

	# When the cooldown just ended, re-run a full refresh so icon opacities snap
	# back to their normal (non-charging) values.
	if _was_on_cooldown and not on_cd:
		_last_signature = "__unset__"
	_was_on_cooldown = on_cd

func _apply_cooldown_to_icon(icon: TextureRect, clip: Control, fill: TextureRect, on_cd: bool, ready_frac: float, base_alpha: float) -> void:
	if icon == null or clip == null or fill == null:
		return
	if not on_cd or not icon.visible or icon.texture == null:
		clip.visible = false
		return
	icon.modulate.a = base_alpha * cooldown_charging_alpha
	var r := icon.get_rect()
	var fill_h := r.size.y * ready_frac
	clip.visible = true
	clip.position = Vector2(r.position.x, r.position.y + r.size.y - fill_h)
	clip.size = Vector2(r.size.x, fill_h)
	fill.texture = icon.texture
	fill.size = r.size
	fill.position = Vector2(0.0, -(r.size.y - fill_h))
	fill.modulate = Color(1, 1, 1, base_alpha)

func _layout_icons() -> void:
	var h := size.y
	var cy := h - 16.0 - center_size * 0.5
	var cx := zone_width * 0.5
	var gap := 28.0

	_position_icon(_current_icon, _current_hit, Vector2(cx - center_size * 0.5, cy - center_size * 0.5), center_size)
	_position_icon(_prev_icon, _prev_hit, Vector2(cx - center_size * 0.5 - gap - side_size, cy - side_size * 0.5), side_size)
	_position_icon(_next_icon, _next_hit, Vector2(cx + center_size * 0.5 + gap, cy - side_size * 0.5), side_size)

func _position_icon(icon: TextureRect, hit: Button, pos: Vector2, size: float) -> void:
	if icon:
		icon.position = pos
		icon.size = Vector2(size, size)
		icon.pivot_offset = Vector2(size * 0.5, size * 0.5)
	if hit:
		hit.position = pos
		hit.size = Vector2(size, size)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_icons()

func _refresh_if_changed() -> void:
	var signature := _build_signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	_refresh()

func _refresh() -> void:
	var ids := _ability_ids()
	var current_id := _selected_id()
	var count := ids.size()

	if count == 0:
		_hide_tooltip()
		_set_icon_texture(_current_icon, "")
		_set_icon_texture(_prev_icon, "")
		_set_icon_texture(_next_icon, "")
		if _current_icon:
			_current_icon.visible = false
		if _current_fill_clip:
			_current_fill_clip.visible = false
		_set_sides_visible(false)
		_set_hits_enabled(false)
		_layout_icons()
		return

	var current_index := ids.find(current_id)
	if current_index < 0:
		current_index = 0

	var prev_id := ""
	var next_id := ""
	if count > 1:
		prev_id = str(ids[((current_index - 1) % count + count) % count])
		next_id = str(ids[(current_index + 1) % count])

	var display_id := str(ids[current_index]) if count > 0 else current_id
	_set_icon_texture(_current_icon, display_id)
	_set_icon_texture(_prev_icon, prev_id)
	_set_icon_texture(_next_icon, next_id)

	if _current_icon:
		_current_icon.visible = true
		_current_icon.scale = Vector2.ONE
		_current_icon.modulate = Color.WHITE
	if _prev_icon:
		_prev_icon.scale = Vector2.ONE
		_prev_icon.modulate.a = side_alpha
	if _next_icon:
		_next_icon.scale = Vector2.ONE
		_next_icon.modulate.a = side_alpha

	var show_sides := count > 1
	_set_sides_visible(show_sides)
	_set_hits_enabled(true)
	if _prev_hit:
		_prev_hit.visible = show_sides
	if _next_hit:
		_next_hit.visible = show_sides

	_layout_icons()

func _set_sides_visible(show: bool) -> void:
	if _prev_icon:
		_prev_icon.visible = show
	if _next_icon:
		_next_icon.visible = show

func _set_hits_enabled(enabled: bool) -> void:
	if _prev_hit:
		_prev_hit.disabled = not enabled
	if _current_hit:
		_current_hit.disabled = not enabled
	if _next_hit:
		_next_hit.disabled = not enabled

func _set_icon_texture(icon: TextureRect, ability_id: String) -> void:
	if icon == null:
		return
	if ability_id.is_empty():
		icon.texture = null
		return
	var path := _ability_icon_path(ability_id)
	icon.texture = load(path) if not path.is_empty() else null

func _on_prev_pressed() -> void:
	_cycle_to_side(-1)

func _on_next_pressed() -> void:
	_cycle_to_side(1)

func _cycle_to_side(direction: int) -> void:
	if _service == null:
		return
	var ids := _ability_ids()
	if ids.size() <= 1:
		return
	var current_index := ids.find(_selected_id())
	if current_index < 0:
		current_index = 0
	var next_index := (current_index + direction) % ids.size()
	if next_index < 0:
		next_index += ids.size()
	var next_id := str(ids[next_index])
	_service.select_ability_id(next_id)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED, -3.0)
	_play_cycle_tween(direction)
	_last_signature = "__unset__"
	_refresh()

func _play_cycle_tween(direction: int) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	var from_icon := _prev_icon if direction < 0 else _next_icon
	var to_icon := _current_icon
	if from_icon and to_icon:
		var from_scale := from_icon.scale
		var to_scale := to_icon.scale
		from_icon.scale = from_scale
		to_icon.scale = Vector2(0.85, 0.85)
		_tween.tween_property(from_icon, "modulate:a", side_alpha, transition_duration)
		_tween.tween_property(to_icon, "modulate:a", 1.0, transition_duration)
		_tween.tween_property(to_icon, "scale", to_scale, transition_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_current_pressed() -> void:
	if _service == null or _ability_ids().is_empty():
		return
	# Shared cooldown still charging: give a soft "not ready" cue, don't fire.
	if _service.is_ability_on_cooldown():
		UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -6.0)
		return
	_service.request_use_selected_ability()
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED, -1.0)

func _on_current_hovered() -> void:
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -4.0)
	_show_tooltip()

func _show_tooltip() -> void:
	if _tooltip == null or _service == null:
		return
	var ability_id := _selected_id()
	if ability_id.is_empty():
		return
	var details := _describe_ability(ability_id)
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip.grow_horizontal = Control.GROW_DIRECTION_END
	_tooltip.grow_vertical = Control.GROW_DIRECTION_END
	_tooltip.visible = true
	_tooltip.set_content(details.get("name", ""), details.get("description", ""))
	_tooltip.reset_size()
	_position_tooltip()
	_tooltip.appear()

func _position_tooltip() -> void:
	if _tooltip == null or _current_hit == null:
		return
	var slot_rect := _current_hit.get_global_rect()
	var size := _tooltip.size
	var x := slot_rect.position.x + (slot_rect.size.x - size.x) * 0.5
	var y := slot_rect.position.y - size.y - 14.0
	if y < 8.0:
		y = slot_rect.end.y + 14.0
	_tooltip.global_position = Vector2(x, y)
	_tooltip.pivot_offset = Vector2(size.x * 0.5, size.y)

func _hide_tooltip() -> void:
	if _tooltip:
		_tooltip.disappear()

# --- Data ---

func _ability_ids() -> Array:
	if _service == null:
		return []
	return _service.get_ability_ids()

func _selected_id() -> String:
	if _service == null:
		return ""
	return _service.get_selected_ability_id()

func _build_signature() -> String:
	var ids := _ability_ids()
	var parts: Array[String] = [_selected_id()]
	for id in ids:
		parts.append(str(id))
	return "|".join(parts)

func _describe_ability(ability_id: String) -> Dictionary:
	var name := ability_id.capitalize()
	var desc := ""
	if _service == null or _service.context == null:
		return {"name": name, "description": desc}
	var cfg := _service.context.state.root.get_node("Persistent.configuration.abilities").get_node(ability_id)
	if not cfg.is_valid():
		return {"name": name, "description": desc}
	var metadata := cfg.get_node("metadata")
	if metadata.is_valid():
		var localization := _service.context.engine.get_service("Localization") as GnosisLocalizationService
		if localization:
			var name_key := str(metadata.get_node("nameKey").value) if metadata.get_node("nameKey").is_valid() else ""
			var desc_key := str(metadata.get_node("descriptionKey").value) if metadata.get_node("descriptionKey").is_valid() else ""
			if not name_key.is_empty():
				name = localization.get_string_value(name_key, name)
			if not desc_key.is_empty():
				desc = localization.get_string_value(desc_key, desc)
	return {"name": name, "description": desc}

func _ability_icon_path(ability_id: String) -> String:
	var candidates: Array[String] = [ability_id, ability_id.capitalize()]
	if _service and _service.context:
		var cfg := _service.context.state.root.get_node("Persistent.configuration.abilities").get_node(ability_id)
		if cfg.is_valid():
			var metadata := cfg.get_node("metadata")
			if metadata.is_valid():
				var sprite_id := str(metadata.get_node("spriteId").value) if metadata.get_node("spriteId").is_valid() else ""
				if not sprite_id.is_empty():
					candidates.insert(0, sprite_id)
	for candidate in candidates:
		var path := "%s%s.png" % [ICON_ROOT, candidate]
		if ResourceLoader.exists(path):
			return path
	return ""
