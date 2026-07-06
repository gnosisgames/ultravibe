# Archived — Polyomino falling-block tests

These tests targeted the legacy `FallingBlock` service under `game/_legacy_polyomino/`.  
Ultravibe boots **Match-3** only; they are **not** run in CI.

Run manually if touching legacy code:

```bash
"$GODOT" --path . --headless --script res://tests/_legacy_polyomino/test_falling_block_core.gd
```

Active suites: `tests/run_tests.sh` (smoke) and `tests/run_tests_extended.sh` (Match-3).
