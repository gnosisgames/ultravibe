class_name UltravibeBootstrap
extends "res://addons/com.gnosisgames.gnosisengine/adapters/godot/gnosis_godot_engine.gd"

## Boots the Gnosis engine for Ultravibe: registers the data-driven configuration
## manifest, all progression/run services, and the FallingBlock + Deck game services.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"

const FallingBlockServiceScript = preload("res://game/services/falling_block_service.gd")
const FallingBlockDeckServiceScript = preload("res://game/services/falling_block_deck_service.gd")
const FallingBlockAdapterScript = preload("res://game/adapters/falling_block_adapter.gd")
const FeedbackAudioAdapterScript = preload("res://game/adapters/feedback_audio_adapter.gd")
const UltraMusicPlaylistAdapterScript = preload("res://game/adapters/ultra_music_playlist_adapter.gd")
const UltraDebugInfoOverlayScript = preload("res://game/ui/widgets/ultra_debug_info_overlay.gd")
const UltraDisplaySettingsScript = preload("res://game/ultra_display_settings.gd")
const TranslationBridgeScript = preload("res://addons/com.gnosisgames.gnosisengine/adapters/godot/gnosis_godot_translation_bridge.gd")
const UltraInputActions = preload("res://game/input/ultra_input_actions.gd")
const GnosisConsoleInputActions = preload("res://addons/com.gnosisgames.gnosisengine/input/gnosis_console_input_actions.gd")

var _falling_block_adapter: FallingBlockAdapter = null
var _feedback_audio_adapter: FeedbackAudioAdapter = null
var _music_playlist_adapter: UltraMusicPlaylistAdapter = null
var _debug_info_overlay: UltraDebugInfoOverlay = null
var _display_settings: UltraDisplaySettings = null
var _translation_bridge: GnosisGodotTranslationBridge = null

func _register_default_services(config: GnosisEngineConfig) -> void:
	super._register_default_services(config)

	# Point the Configuration service at the Ultravibe data manifest.
	config.data_base_path = "res://data"
	config.config_manifest_path = "res://data/configuration.json"
	config.asset_registry_paths = PackedStringArray(["res://data/asset_registry.json"])

	# Generic progression / run services (transient unless noted).
	_register(config, "Score", GnosisLifetime.TRANSIENT, "gnosis_score_service.gd")
	_register(config, "Currency", GnosisLifetime.TRANSIENT, "gnosis_currency_service.gd")
	_register(config, "Boon", GnosisLifetime.TRANSIENT, "gnosis_boon_service.gd")
	_register(config, "Consumable", GnosisLifetime.TRANSIENT, "gnosis_consumable_service.gd")
	_register(config, "Ability", GnosisLifetime.TRANSIENT, "gnosis_ability_service.gd")
	_register(config, "Upgrade", GnosisLifetime.TRANSIENT, "gnosis_upgrade_service.gd")
	_register(config, "Shop", GnosisLifetime.TRANSIENT, "gnosis_shop_service.gd")
	_register(config, "Scaling", GnosisLifetime.TRANSIENT, "gnosis_scaling_service.gd")
	_register(config, "Time", GnosisLifetime.TRANSIENT, "gnosis_time_service.gd")
	_register(config, "Seed", GnosisLifetime.TRANSIENT, "gnosis_seed_service.gd")
	_register(config, "Rule", GnosisLifetime.TRANSIENT, "gnosis_rule_service.gd")
	_register(config, "Statistic", GnosisLifetime.SINGLETON, "gnosis_statistic_service.gd")
	_register(config, "Animation", GnosisLifetime.SINGLETON, "gnosis_animation_service.gd")

	# Game-specific services.
	config.register_service("Deck", GnosisLifetime.TRANSIENT, func(): return FallingBlockDeckServiceScript.new())
	config.register_service("FallingBlock", GnosisLifetime.TRANSIENT, func(): return FallingBlockServiceScript.new())

func _register(config: GnosisEngineConfig, id: String, lifetime: int, file_name: String) -> void:
	var script: Script = load("%s/%s" % [ADDON, file_name])
	config.register_service(id, lifetime, func(): return script.new())

func _wire_adapters() -> void:
	UltraInputActions.ensure_input_map()
	GnosisConsoleInputActions.ensure_input_map()
	super._wire_adapters()
	_falling_block_adapter = _find_or_create_adapter(FallingBlockAdapterScript, "FallingBlockAdapter") as FallingBlockAdapter
	_feedback_audio_adapter = _find_or_create_adapter(FeedbackAudioAdapterScript, "FeedbackAudioAdapter") as FeedbackAudioAdapter
	_music_playlist_adapter = _find_or_create_adapter(UltraMusicPlaylistAdapterScript, "MusicPlaylistAdapter") as UltraMusicPlaylistAdapter
	_bind_falling_block_adapter()
	if _feedback_audio_adapter:
		_feedback_audio_adapter.bind_engine(engine)
		var anim := engine.get_service("Animation") as GnosisAnimationService
		if anim:
			_feedback_audio_adapter.bind_service(anim)
	_bind_music_playlist_adapter()
	_bind_hud()
	_configure_gameplay_input()

## Tags the falling-block action map as gameplay input. Keyboard/action-map
## fallback stays on Player1; gamepad events can resolve by device seat.
func _configure_gameplay_input() -> void:
	var input := get_adapter(GnosisGodotInputAdapter) as GnosisGodotInputAdapter
	if input == null:
		return
	var categories := {}
	var players := {}
	for action_name in UltraInputActions.action_names():
		var spec: Dictionary = UltraInputActions.BINDINGS[action_name]
		var category := str(spec.get("category", "gameplay"))
		categories[action_name] = category
		if category == "gameplay":
			players[action_name] = "P0"
	for action_name in GnosisConsoleInputActions.action_names():
		categories[action_name] = "console"
	input.action_category_overrides = categories
	input.action_player_overrides = players
	input.pause_action_name = "ultra_ui_cancel"
	input.device_player_overrides = {
		0: "P0",
		1: "P1",
		2: "P2",
		3: "P3",
	}

func _bind_falling_block_adapter() -> void:
	var svc := engine.get_service("FallingBlock") if engine else null
	if _falling_block_adapter:
		_falling_block_adapter.rebuild_player_states_from_ephemeral()
		_falling_block_adapter.bind_engine(engine)
		if svc:
			_falling_block_adapter.bind_service(svc)

func _bind_music_playlist_adapter() -> void:
	if _music_playlist_adapter and engine:
		_music_playlist_adapter.bind_engine(engine)
		_music_playlist_adapter.set_asset_registry(asset_registry)

func _rebind_transient_adapters() -> void:
	super._rebind_transient_adapters()
	_bind_falling_block_adapter()
	_bind_music_playlist_adapter()
	_bind_hud()

func continue_saved_run() -> bool:
	if not engine:
		return false
	var payload := GnosisRunSave.load_run_save()
	if payload.is_empty():
		return false
	var saved_ephemeral: Dictionary = {}
	var raw_ephemeral: Variant = payload.get("Ephemeral", {})
	if raw_ephemeral is Dictionary:
		saved_ephemeral = raw_ephemeral
	if saved_ephemeral.is_empty():
		# Without the saved Ephemeral branch (deck, queue, seed, score) the run
		# cannot be faithfully resumed; refuse rather than silently start fresh.
		GnosisRunSave.clear_run_save()
		return false
	var runtime_snapshot: Dictionary = payload.get("runtime", {})
	var config := engine.get_service("Configuration") as GnosisConfigurationService
	if config:
		config.prepare_continue_from_save(saved_ephemeral)
	engine.end_run()
	engine.destroy_non_permanent_services()
	engine.initialize_non_permanent_services()
	engine.start_run()
	# Guarantee the saved Ephemeral wins regardless of service init ordering: the
	# pending flag handles the in-start_run restore, and this re-applies it after
	# in case a service reset the branch. Idempotent.
	if config:
		config.load_ephemeral_from_dictionary(saved_ephemeral)
	_rebind_transient_adapters()
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	if fb:
		fb.resume_saved_run(runtime_snapshot)
	return true

func try_save_in_progress_run() -> bool:
	if not _should_save_run():
		return false
	return GnosisRunSave.save_in_progress_run(engine)

func _should_save_run() -> bool:
	if engine == null:
		return false
	var ui := engine.get_service("GameUI") as GnosisGameUIService
	if ui == null:
		return false
	if ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return false
	if not ui.get_active_overlay_state_for_view("game_over").is_empty():
		return false
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	if fb == null or fb.is_run_game_over():
		return false
	return true

func _exit_tree() -> void:
	try_save_in_progress_run()
	super._exit_tree()

func _bind_hud() -> void:
	var hud := get_node_or_null("UI/GameArea/Hud")
	var svc := engine.get_service("FallingBlock") if engine else null
	if hud and svc and hud.has_method("bind_service"):
		hud.bind_service(svc as FallingBlockService)

## Hard override: when true the CRT overlay stays hidden regardless of the
## crtFilterEnabled, crtScanlinesStrength, vignetteIntensity settings.
@export var disable_crt_overlay: bool = false

func _initialize_presentation() -> void:
	# Views (title / settings / engine_debug) are authored in main.tscn and join
	# the "gnosis_ui_view" group; the base class shows the configured startup view.
	if startup_view_id.is_empty():
		startup_view_id = "title"
	super._initialize_presentation()
	_ensure_translation_bridge()
	_ensure_debug_info_overlay()
	_ensure_display_settings()

func _ensure_translation_bridge() -> void:
	if _translation_bridge == null:
		_translation_bridge = TranslationBridgeScript.new()
		_translation_bridge.name = "TranslationBridge"
		add_child(_translation_bridge)
	_translation_bridge.bind_engine(engine)

func _ensure_debug_info_overlay() -> void:
	if _debug_info_overlay == null:
		_debug_info_overlay = UltraDebugInfoOverlayScript.new()
		_debug_info_overlay.name = "DebugInfoOverlay"
		add_child(_debug_info_overlay)
	_debug_info_overlay.bind_engine(engine)

func _ensure_display_settings() -> void:
	if _display_settings == null:
		_display_settings = UltraDisplaySettingsScript.new()
		_display_settings.name = "DisplaySettings"
		add_child(_display_settings)
	_display_settings.crt_force_disabled = disable_crt_overlay
	_display_settings.set_crt_rect(get_node_or_null("CRTLayer/CRT") as ColorRect)
	_display_settings.bind_engine(engine)
