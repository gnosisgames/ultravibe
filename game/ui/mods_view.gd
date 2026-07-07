class_name UltravibeModsView
extends GnosisUIElementView

const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")
const ModLoaderBridge := preload("res://addons/com.gnosisgames.gnosisengine/adapters/godot/gnosis_mod_loader_bridge.gd")
const ModListItemButton := preload("res://game/ui/widgets/mod_list_item_button.gd")

enum MainTab { INFO, CHANGELOG, SETTINGS }

@onready var _back_button: Button = %BackButton
@onready var _info_tab: Button = %InfoTab
@onready var _changelog_tab: Button = %ChangelogTab
@onready var _settings_tab: Button = %SettingsTab
@onready var _card: PanelContainer = %Card
@onready var _split: HBoxContainer = %Split
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _main_scroll: ScrollContainer = %MainScroll
@onready var _mods_list: VBoxContainer = %ModsList
@onready var _empty_label: Label = %EmptyLabel
@onready var _count_label: Label = %CountLabel
@onready var _info_page: VBoxContainer = %InfoPage
@onready var _changelog_page: VBoxContainer = %ChangelogPage
@onready var _settings_page: VBoxContainer = %SettingsPage
@onready var _detail_prompt: Label = %DetailPrompt
@onready var _detail_name: Label = %DetailName
@onready var _detail_meta: Label = %DetailMeta
@onready var _detail_description: Label = %DetailDescription
@onready var _changelog_body: Label = %ChangelogBody
@onready var _settings_body: Label = %SettingsBody

var _host: GnosisGodotEngine = null
var _summaries_by_id: Dictionary = {}
var _list_buttons: Dictionary = {}
var _selected_mod_id: String = ""
var _current_tab: int = MainTab.INFO

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_configure_scrollbars()
	_back_button.pressed.connect(_on_back_pressed)
	_info_tab.pressed.connect(func() -> void: _show_tab(MainTab.INFO))
	_changelog_tab.pressed.connect(func() -> void: _show_tab(MainTab.CHANGELOG))
	_settings_tab.pressed.connect(func() -> void: _show_tab(MainTab.SETTINGS))
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		_refresh_mod_list()
		call_deferred("_focus_entry_point")

func _focus_entry_point() -> void:
	if not is_visible_in_tree():
		return
	if _selected_mod_id.is_empty() or not _list_buttons.has(_selected_mod_id):
		if _info_tab:
			_info_tab.grab_focus()
		return
	var button := _list_buttons[_selected_mod_id] as ModListItemButton
	if button:
		button.grab_focus()

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			return
		node = node.get_parent()

func _game_ui() -> GnosisGameUIService:
	if _host and _host.engine:
		return _host.engine.get_service("GameUI") as GnosisGameUIService
	return null

func _localization() -> GnosisLocalizationService:
	if _host and _host.engine:
		return _host.engine.get_service("Localization") as GnosisLocalizationService
	return null

func _permanent_mod_service() -> GnosisPermanentModService:
	if _host and _host.engine:
		return _host.engine.get_service("PermanentMod") as GnosisPermanentModService
	return null

func _tr(key: String) -> String:
	var loc := _localization()
	if loc:
		return loc.get_string_value(key, key)
	return key

func _show_tab(tab: int) -> void:
	_current_tab = tab
	_info_tab.button_pressed = tab == MainTab.INFO
	_changelog_tab.button_pressed = tab == MainTab.CHANGELOG
	_settings_tab.button_pressed = tab == MainTab.SETTINGS
	_info_page.visible = tab == MainTab.INFO
	_changelog_page.visible = tab == MainTab.CHANGELOG
	_settings_page.visible = tab == MainTab.SETTINGS
	_refresh_main_content()
	call_deferred("_sync_scrollbars")

func _refresh_mod_list() -> void:
	if not is_node_ready() or _mods_list == null:
		return
	if _host == null:
		_resolve_host()
	var previous_id := _selected_mod_id
	for child in _mods_list.get_children():
		child.queue_free()
	_list_buttons.clear()
	_summaries_by_id.clear()
	var summaries := ModLoaderBridge.get_all_mod_summaries(_permanent_mod_service())
	var count := summaries.size()
	var has_mods := count > 0
	_empty_label.visible = not has_mods
	_split.visible = has_mods
	if not has_mods:
		_empty_label.text = _tr("ultravibe__mods__empty")
		_count_label.text = ""
		_clear_main_content()
		return
	_count_label.text = _tr("ultravibe__mods__count_one") if count == 1 else _tr("ultravibe__mods__count_many") % count
	for entry in summaries:
		var mod_id := str(entry.get("mod_id", ""))
		if mod_id.is_empty():
			continue
		_summaries_by_id[mod_id] = entry
		var button := _make_list_button(entry)
		_list_buttons[mod_id] = button
		_mods_list.add_child(button)
	var next_id := previous_id if _summaries_by_id.has(previous_id) else str(summaries[0].get("mod_id", ""))
	_select_mod(next_id, false)
	call_deferred("_sync_scrollbars")

func _configure_scrollbars() -> void:
	for scroll in [_list_scroll, _main_scroll]:
		if scroll:
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

func _sync_scrollbars() -> void:
	if not is_node_ready():
		return
	await get_tree().process_frame
	for scroll in [_list_scroll, _main_scroll]:
		if scroll == null:
			continue
		scroll.update_minimum_size()
		var vbar: VScrollBar = scroll.get_v_scroll_bar()
		if vbar:
			vbar.visible = vbar.max_value > vbar.page

func _make_list_button(entry: Dictionary) -> ModListItemButton:
	var mod_id := str(entry.get("mod_id", ""))
	var display_name := str(entry.get("name", mod_id))
	var version := str(entry.get("version", ""))
	var active := bool(entry.get("active", true))
	var button := ModListItemButton.new()
	button.configure(mod_id, display_name, version, not active)
	button.mod_focused.connect(_select_mod)
	return button

func _select_mod(mod_id: String, grab_focus: bool = true) -> void:
	if not _summaries_by_id.has(mod_id):
		_clear_main_content()
		return
	_selected_mod_id = mod_id
	for id in _list_buttons.keys():
		var button := _list_buttons[id] as ModListItemButton
		if button:
			button.set_selected_state(id == mod_id)
	_refresh_main_content()
	if grab_focus and is_visible_in_tree():
		var selected := _list_buttons.get(mod_id) as ModListItemButton
		if selected and get_viewport().gui_get_focus_owner() != selected:
			selected.grab_focus()

func _refresh_main_content() -> void:
	if _selected_mod_id.is_empty() or not _summaries_by_id.has(_selected_mod_id):
		_clear_main_content()
		return
	var entry: Dictionary = _summaries_by_id[_selected_mod_id]
	match _current_tab:
		MainTab.INFO:
			_show_info(entry)
		MainTab.CHANGELOG:
			_show_changelog(entry)
		MainTab.SETTINGS:
			_show_settings(entry)

func _clear_main_content() -> void:
	_selected_mod_id = ""
	for id in _list_buttons.keys():
		var button := _list_buttons[id] as ModListItemButton
		if button:
			button.set_selected_state(false)
	_detail_prompt.visible = true
	_detail_prompt.text = _tr("ultravibe__mods__select_prompt")
	_detail_name.visible = false
	_detail_meta.visible = false
	_detail_description.visible = false
	_changelog_body.text = _tr("ultravibe__mods__select_prompt")
	_settings_body.text = _tr("ultravibe__mods__select_prompt")

func _show_info(entry: Dictionary) -> void:
	var mod_id := str(entry.get("mod_id", ""))
	var display_name := str(entry.get("name", mod_id))
	var version := str(entry.get("version", ""))
	var source := str(entry.get("source", ""))
	var active := bool(entry.get("active", true))
	var description := str(entry.get("description", "")).strip_edges()
	var website := str(entry.get("website_url", "")).strip_edges()
	_detail_prompt.visible = false
	_detail_name.visible = true
	_detail_meta.visible = true
	_detail_description.visible = true
	_detail_name.text = display_name if not display_name.is_empty() else mod_id
	var version_text := version if not version.is_empty() else "?"
	var source_key := "ultravibe__mods__source_gml" if source == "gml" else "ultravibe__mods__source_data"
	var status_key := "ultravibe__mods__status_active" if active else "ultravibe__mods__status_disabled"
	var meta := "%s · v%s · %s · %s" % [mod_id, version_text, _tr(source_key), _tr(status_key)]
	if not website.is_empty():
		meta += "\n%s" % website
	var authors: Array = entry.get("authors", [])
	if not authors.is_empty():
		meta += "\n%s: %s" % [_tr("ultravibe__mods__authors"), ", ".join(authors)]
	var tags: Array = entry.get("tags", [])
	if not tags.is_empty():
		meta += "\n%s: %s" % [_tr("ultravibe__mods__tags"), ", ".join(tags)]
	_detail_meta.text = meta
	if description.is_empty():
		description = _tr("ultravibe__mods__no_description")
	_detail_description.text = description

func _show_changelog(entry: Dictionary) -> void:
	var changelog := str(entry.get("changelog", "")).strip_edges()
	if changelog.is_empty():
		changelog = _tr("ultravibe__mods__changelog_empty")
	_changelog_body.text = changelog

func _show_settings(entry: Dictionary) -> void:
	var lines: PackedStringArray = []
	var active := bool(entry.get("active", true))
	var loadable := bool(entry.get("loadable", true))
	var status_key := "ultravibe__mods__status_active" if active else "ultravibe__mods__status_disabled"
	lines.append("%s: %s" % [_tr("ultravibe__mods__settings_status"), _tr(status_key)])
	lines.append("%s: %s" % [_tr("ultravibe__mods__settings_loadable"), _tr("ultravibe__mods__settings_value_yes" if loadable else "ultravibe__mods__settings_value_no")])
	var dependencies: Array = entry.get("dependencies", [])
	if dependencies.is_empty():
		lines.append("%s: %s" % [_tr("ultravibe__mods__settings_dependencies"), _tr("ultravibe__mods__settings_none")])
	else:
		lines.append("%s: %s" % [_tr("ultravibe__mods__settings_dependencies"), ", ".join(dependencies)])
	var game_versions: Array = entry.get("compatible_game_version", [])
	if not game_versions.is_empty():
		lines.append("%s: %s" % [_tr("ultravibe__mods__settings_game_versions"), ", ".join(game_versions)])
	var loader_versions: Array = entry.get("compatible_mod_loader_version", [])
	if not loader_versions.is_empty():
		lines.append("%s: %s" % [_tr("ultravibe__mods__settings_loader_versions"), ", ".join(loader_versions)])
	if bool(entry.get("has_config", false)):
		lines.append(_tr("ultravibe__mods__settings_has_config"))
	else:
		lines.append(_tr("ultravibe__mods__settings_empty"))
	_settings_body.text = "\n".join(lines)

func _on_back_pressed() -> void:
	var ui := _game_ui()
	if ui and _host and _host.engine:
		if ui.get_navigation_history_count() > 0:
			var params := _host.engine.store.create_object()
			params.set_key("transitionId", "slide_right")
			params.set_key("inDuration", 0.35)
			params.set_key("outDuration", 0.35)
			ui.invoke_function("PopView", params)
		else:
			UltraGameUiNav.return_to_title(ui)
