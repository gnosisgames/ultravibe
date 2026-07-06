# Ultravibe tests

Headless integration tests for the **Match-3** Godot port. Legacy Polyomino / falling-block tests are archived under [`_legacy_polyomino/`](_legacy_polyomino/README.md).

## Quick commands

```bash
cd ultravibe
source ../scripts/resolve_godot.sh

# Smoke CI (~14 boots, run often)
./tests/run_tests.sh

# Extended Match-3 mechanics (~38 boots, run before merges)
./tests/run_tests_extended.sh

# Single test
"$GODOT" --path . --headless --script res://tests/test_match3_core.gd
```

## Smoke suite (`run_tests.sh`)

| Test | Covers |
|------|--------|
| `test_config_catalogs` | Data manifests register in Gnosis store |
| `test_match3_core` | Catalogs, progression boot, shop, skip/DD, gameplay swap |
| `test_scene_format_guard` | `main.tscn` format stability |
| `test_project_packaging_smoke` | Export readiness artifacts |
| `test_localization_theme` | Theme + i18n fallback |
| `test_ui_focus` | View focus routing |
| `test_console_overlay` | Debug console |
| `test_audio_feedback` | SFX adapter |
| `test_game_ui_overlays` | Confirmation / overlay stack |
| `test_gamepad_player_assignment` | Device → player seats |
| `test_input_rebinding` | Keyboard assignments persist |
| `test_persistence_boundaries` | Run restart vs Persistent data |
| `test_continue_run` | Mid-run save / continue |
| `test_endless_mode` | `EnableEndlessMode` after victory |

## Extended suite (`run_tests_extended.sh`)

Match-3 mechanics depth: boon/consumable sell, shop polish, boss effects, item upgrades, lucky find, floor modifiers, boon finalize hooks, topology boons, catalogs, HUD flows. See the `EXTENDED_TESTS` array in `run_tests_extended.sh` for the full list.

## Isolation

Tests redirect persistent saves to `user://Saves/persistent_test.json` and run saves to `user://Saves/test_*` so local play settings are not overwritten.

## Parity docs

- [docs/parity/ULTRAVIBE_MATCH3_PARITY_SPRINTS.md](../docs/parity/ULTRAVIBE_MATCH3_PARITY_SPRINTS.md) — sprint backlog
- [docs/parity/mechanics-ledger.md](../docs/parity/mechanics-ledger.md) — system status map
