# Performance budgets (Sprint 8)

Headless budgets for CI regression. Update baselines when catalog size or boot path changes materially.

**Automated tests:** `test_match3_boot_perf.gd`, `test_match3_cascade_perf.gd`

## Headless boot

| Metric | Budget | Test |
|--------|--------|------|
| `main.tscn` → engine + Match3 service ready | **8 s** | `test_match3_boot_perf` (12 frames warmup) |

Measured on dev Mac (Godot 4.7 mono, `--headless`). Interactive editor boot is slower; this budget is CI-oriented.

## Cascade simulation (gameplay core, no presentation)

| Board | Cells | Moves sampled | Max cascade steps / move | Total wall-clock |
|-------|-------|---------------|--------------------------|------------------|
| `grid10x10_dr` | 10×10 | 12 horizontal swaps | ≤ 40 | shared **3 s** |
| `hard2Split` | 11×9 irregular | 12 horizontal swaps | ≤ 40 | shared **3 s** |

Stress path: `Match3Gameplay.process_move` only (no `match3_dispatcher` animation timings).

Largest catalog boards for perf: dense `grid10x10_dr`, tall irregular `hard2Split`, wide `bigTower` (manual spot-check if needed).

## Presentation (manual)

Dispatcher cascade durations (`match3_dispatcher.gd`) are not in CI. Use `tools/capture_views.sh` after HUD changes.

## When to tighten budgets

- After removing unused boot scenes (e.g. legacy `shop_view` from `main.tscn`)
- After board catalog shrink
- Do **not** tighten on debug logging builds
