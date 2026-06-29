# Ultravibe Test Suite Documentation

This directory contains integration and regression tests for the Godot port of Ultravibe. All tests are designed to be run headlessly using Godot.

## Test Categorization & Map

Below is a breakdown of all integration tests in the suite:

### Core Engine & Infrastructure
* **[test_full_boot.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_full_boot.gd)**: Verifies the entire Gnosis runtime engine boots, initializes all singletons and services, and displays the correct startup view.
* **[test_config_catalogs.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_config_catalogs.gd)**: Ensures the data-driven configuration files and catalogs register correctly under the Gnosis store.
* **[test_scene_format_guard.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_scene_format_guard.gd)**: A syntax guard to prevent scene formatting errors and check script associations.
* **[test_project_packaging_smoke.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_project_packaging_smoke.gd)**: Verifies essential build artifacts and configuration files exist for project export.
* **[test_persistence_boundaries.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_persistence_boundaries.gd)**: Ensures persistent state remains correctly bounded and is written cleanly.

### Gameplay Logic & Mechanics
* **[test_falling_block_core.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_falling_block_core.gd)**: Validates core tetris/block falling grid operations, matches, and row clears.
* **[test_fall_speed.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_fall_speed.gd)**: Verifies the block fall speed calculations increase correctly as level/score rises.
* **[test_lock_delay_feel.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_lock_delay_feel.gd)**: Tests the player input response window/latency (lock delay) before a piece is finalized on the grid.
* **[test_round_rewards.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_round_rewards.gd)**: Checks that progression reward offers are correctly generated, selected, and applied to player decks.
* **[test_boon_score.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_boon_score.gd)**: Verifies passive boons score multiplier logic and stat increases.
* **[test_discards_consumables.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_discards_consumables.gd)**: Validates deck drawing, discarding, and active item consumable effects.
* **[test_bosses.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_bosses.gd)**: Ensures the boss schedule, encounter timers, and boss visual state transitions work.

### UI & Presentation Layer
* **[test_play_hud_smoke.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_play_hud_smoke.gd)**: Smoke tests the gameplay HUD interface.
* **[test_game_ui_overlays.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_game_ui_overlays.gd)**: Verifies menu overlays, modal popups, and dialog confirmation flows.
* **[test_ui_focus.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_ui_focus.gd)**: Focus navigation routing across the game menus.
* **[test_console_overlay.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_console_overlay.gd)**: Confirms the debug console console overlay toggles and prints outputs.
* **[test_audio_feedback.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_audio_feedback.gd)**: Verifies sounds play on action, volume levels, and audio track routing.
* **[test_localization_theme.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_localization_theme.gd)**: Verifies the Theme service applies visual changes and the i18n localization service falls back to English when translations are missing.
* **[test_game_over_flow.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_game_over_flow.gd)**: Ensures game over screens trigger correctly and smoothly transition out.

### Input Management
* **[test_gameplay_input_routing.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_gameplay_input_routing.gd)**: Routes physical controllers and keypresses to active gameplay adapters.
* **[test_gamepad_player_assignment.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_gamepad_player_assignment.gd)**: Automatically assigns gamepad inputs to specific player slots.
* **[test_input_rebinding.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_input_rebinding.gd)**: Verifies custom keyboard rebindings are saved to state and applied into the engine's `InputMap`.
* **[test_discard_single_press.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_discard_single_press.gd)**: Verifies single-tap vs long-press discard behavior.

### System Verification & Parity
* **[test_e2e_run.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_e2e_run.gd)**: An end-to-end simulation of a full gameplay loop from start to defeat.
* **[test_parity_invocations.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_parity_invocations.gd)**: Confirms API methods and event payloads align with the old Unity codebase.
* **[test_parity_boss_effects.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_parity_boss_effects.gd)**: Validates parity in boss visual effect timing.
* **[test_parity_coop.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_parity_coop.gd)**: Verifies the co-op system matches old multiplayer parameters.
* **[test_parity_content_catalog.gd](file:///Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/ultravibe/tests/test_parity_content_catalog.gd)**: Checks game content data catalog properties align.

## Test Cleanliness & Isolation

To prevent local game development configurations (such as custom player profiles or keyboard assignments) from being polluted or overwritten when tests run, the Gnosis engine is updated to isolate test execution:
- **Persistent State**: Redirects persistent state files during any test run to `user://Saves/persistent_test.json` instead of writing to `user://Saves/persistent.json`.
- **Run Saves**: Redirects all current run save files to `user://Saves/test_*`.

This ensures you can run the test suite at any time and resume playing without needing to manually reset to defaults!
