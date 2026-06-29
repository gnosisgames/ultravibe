class_name UltravibeRewardSelectionView
extends GnosisUIElementView

## Post-round reward selection. Shows the current Ephemeral.rewardOffers row and
## grants the clicked offer through FallingBlockService.claim_reward_offer().

@onready var _round_label: Label = %RoundLabel
@onready var _offers_root: BoxContainer = %OffersRoot
@onready var _status_label: Label = %StatusLabel
@onready var _continue_button: Button = %ContinueButton

var _host: GnosisGodotEngine = null
var _fb: FallingBlockService = null
var _last_signature := ""

const ICON_ROOT := "res://assets/icons/"
const TYPE_COLORS := {
	"boon": Color(0.92, 0.78, 0.28),
	"consumable": Color(0.38, 0.78, 1.0),
	"ability": Color(0.62, 1.0, 0.62),
	"upgrade": Color(1.0, 0.62, 0.3)
}
const SPECIAL_ICON_IDS := {
	"ability:gridShift": "gridSwap"
}

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_continue_button.pressed.connect(_return_to_gameplay)
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		_refresh()

func _process(_delta: float) -> void:
	if visible:
		_refresh_if_changed()

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			break
		node = node.get_parent()
	_resolve_service()
	_refresh()

func _resolve_service() -> void:
	if _host and _host.engine:
		_fb = _host.engine.get_service("FallingBlock") as FallingBlockService

func _engine() -> GnosisEngine:
	return _host.engine if _host else null

func _ephemeral() -> GnosisNode:
	var eng := _engine()
	if eng == null or eng.state == null:
		return GnosisNode.new(null)
	return eng.state.root.get_node("Ephemeral")

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

func _refresh_if_changed() -> void:
	var signature := _build_signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	_refresh()

func _refresh() -> void:
	if _fb == null:
		_resolve_service()
	_clear_offers()

	var ep := _ephemeral()
	var current_round := _read_int(ep.get_node("fallingBlock").get_node("currentRound"), 1)
	_round_label.text = tr("ultravibe__reward__roundRewardNumbered") % maxi(1, current_round - 1)

	var offers := ep.get_node("rewardOffers")
	var choice_count := _read_int(ep.get_node("rewardChoiceCount"), 0)
	var selected := _read_int(ep.get_node("selectedRewardSlotIndex"), 0)
	var pending := _read_bool(ep.get_node("rewardSelectionPending"), false)

	if not pending:
		_status_label.text = tr("ultravibe__reward__noPending")
		_continue_button.visible = true
		return
	if not offers.is_valid() or offers.get_type() != GnosisValueType.LIST or offers.get_count() <= 0:
		_status_label.text = tr("ultravibe__reward__noneAvailable")
		_continue_button.visible = true
		return

	_status_label.text = tr("ultravibe__reward__chooseOne")
	_continue_button.visible = false
	var count := mini(choice_count if choice_count > 0 else offers.get_count(), offers.get_count())
	for i in range(count):
		var offer := offers.get_node(i)
		if not offer.is_valid():
			continue
		_add_offer_button(i, offer, i == selected)

func _add_offer_button(index: int, offer: GnosisNode, selected: bool) -> void:
	var type_id := _node_str(offer, "type")
	var item_id := _node_str(offer, "itemId")
	var details := _describe_offer(type_id, item_id)

	var button := Button.new()
	button.custom_minimum_size = Vector2(260, 360)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	button.tooltip_text = "%s\n%s" % [details.name, details.description]
	button.pressed.connect(func(): _claim(index))

	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 18
	card.offset_top = 18
	card.offset_right = -18
	card.offset_bottom = -18
	card.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_theme_constant_override("separation", 10)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(card)

	var chip := Label.new()
	chip.text = details.type_label
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_theme_color_override("font_color", TYPE_COLORS.get(type_id.to_lower(), Color.WHITE))
	chip.add_theme_font_size_override("font_size", 18)
	card.add_child(chip)

	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(0, 120)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon_wrap)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(104, 104)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not details.icon_path.is_empty():
		icon.texture = load(details.icon_path)
	icon_wrap.add_child(icon)

	var name_label := Label.new()
	name_label.text = details.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = details.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95))
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc_label)

	if selected:
		button.modulate = Color(1.08, 1.08, 1.08)
	_offers_root.add_child(button)

func _claim(index: int) -> void:
	if _fb == null:
		_status_label.text = tr("ultravibe__reward__serviceNotReady")
		return
	if _fb.claim_reward_offer(index):
		_status_label.text = tr("ultravibe__reward__claimed")
		_return_to_gameplay()
	else:
		_status_label.text = tr("ultravibe__reward__claimFailed")
	_refresh()

func _return_to_gameplay() -> void:
	var ui := _game_ui()
	var eng := _engine()
	if ui and eng:
		UltraGameUiNav.transition_to_gameplay(ui, eng.store, "rewards", "slide_up")

func _describe_offer(type_id: String, item_id: String) -> Dictionary:
	var category := _category_for_type(type_id)
	var entry := _catalog_entry(category, item_id)
	var name := item_id.capitalize()
	var desc := type_id.capitalize()
	var sprite_id := ""
	if entry.is_valid():
		var metadata := entry.get_node("metadata")
		if metadata.is_valid():
			var name_key := _node_str(metadata, "nameKey")
			var desc_key := _node_str(metadata, "descriptionKey")
			sprite_id = _node_str(metadata, "spriteId")
			name = _localized(name_key, name)
			desc = _localized(desc_key, desc)
	return {
		"type_label": type_id.to_upper(),
		"name": name,
		"description": desc,
		"icon_path": _icon_path(type_id, category, item_id, sprite_id)
	}

func _icon_path(type_id: String, category: String, item_id: String, sprite_id: String) -> String:
	if category.is_empty():
		return ""
	var folder := "%s%s/" % [ICON_ROOT, category]
	var key := "%s:%s" % [type_id.to_lower(), item_id]
	var candidates: Array[String] = []
	if SPECIAL_ICON_IDS.has(key):
		candidates.append(SPECIAL_ICON_IDS[key])
	if not sprite_id.is_empty():
		candidates.append(sprite_id)
	if sprite_id.begins_with("consumable") and sprite_id.ends_with("Sprite"):
		var base := sprite_id.trim_prefix("consumable").trim_suffix("Sprite")
		candidates.append(base)
		candidates.append(base.capitalize())
	if sprite_id.begins_with("runUpgrade") and sprite_id.ends_with("Sprite"):
		var golden := sprite_id.trim_prefix("runUpgrade").trim_suffix("Sprite")
		candidates.append(golden)
		if golden == "GoldenFalling":
			candidates.append("discardUpgrade")
	candidates.append(item_id)
	candidates.append(item_id.capitalize())
	for candidate in candidates:
		var path := "%s%s.png" % [folder, candidate]
		if ResourceLoader.exists(path):
			return path
	return ""

func _category_for_type(type_id: String) -> String:
	match type_id.strip_edges().to_lower():
		"boon":
			return "boons"
		"consumable":
			return "consumables"
		"ability":
			return "abilities"
		"upgrade":
			return "upgrades"
	return ""

func _catalog_entry(category: String, item_id: String) -> GnosisNode:
	if category.is_empty() or item_id.is_empty():
		return GnosisNode.new(null)
	var eng := _engine()
	if eng == null:
		return GnosisNode.new(null)
	var config := eng.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node(category).get_node(item_id)

func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty():
		return fallback
	var eng := _engine()
	if eng == null:
		return fallback
	var localization := eng.get_service("Localization") as GnosisLocalizationService
	if localization == null:
		return fallback
	return _clean_rich_text(localization.get_string_value(key, fallback))

func _clean_rich_text(value: String) -> String:
	var text := value
	var tag_re := RegEx.new()
	if tag_re.compile("<[^>]+>") == OK:
		text = tag_re.sub(text, "", true)
	var arg_re := RegEx.new()
	if arg_re.compile("\\$\\{arg:[^}]+\\}") == OK:
		text = arg_re.sub(text, "?", true)
	return text

func _clear_offers() -> void:
	for child in _offers_root.get_children():
		child.free()

func _build_signature() -> String:
	var ep := _ephemeral()
	var parts: Array[String] = []
	parts.append(str(_read_bool(ep.get_node("rewardSelectionPending"), false)))
	parts.append(str(_read_int(ep.get_node("selectedRewardSlotIndex"), 0)))
	var offers := ep.get_node("rewardOffers")
	if offers.is_valid() and offers.get_type() == GnosisValueType.LIST:
		for i in range(offers.get_count()):
			var offer := offers.get_node(i)
			parts.append("%s:%s" % [_node_str(offer, "type"), _node_str(offer, "itemId")])
	return "|".join(parts)

func _node_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	return str(n.value) if n.is_valid() and n.value != null else ""

func _read_int(node: GnosisNode, default_value: int) -> int:
	if not node.is_valid() or node.value == null:
		return default_value
	return int(node.value)

func _read_bool(node: GnosisNode, default_value: bool) -> bool:
	if not node.is_valid() or node.get_type() != GnosisValueType.BOOL:
		return default_value
	return bool(node.value)
