# Match-3 port sign-off (Sprint 8)

**Status:** Pre-release — automated gates green; manual playtest pending.

## Automated gates

| Gate | Status | Evidence |
|------|--------|----------|
| Smoke CI (`run_tests.sh`) | ✅ | 14 headless boots |
| Extended CI (`run_tests_extended.sh`) | ✅ | ~50 mechanics tests |
| Golden seed regression | ✅ | `test_seed_regression.gd` (seed `424242`) |
| Boot perf budget | ✅ | `test_match3_boot_perf.gd` |
| Cascade perf budget | ✅ | `test_match3_cascade_perf.gd` |
| Save / continue / endless | ✅ | Sprint 1 tests |
| Shop / HUD / boons / bosses | ✅ | Sprints 3–6 audits |

## Manual gates (required before tag)

| Gate | Doc | Status |
|------|-----|--------|
| 24-round + endless + shop-heavy playtest | [playtest-checklist.md](playtest-checklist.md) | ☐ |
| KB/M + gamepad input matrix | playtest-checklist § Input | ☐ |
| Visual baseline (optional) | `tools/capture_views.sh` | ☐ |

## Intentional deltas vs Unity (keep)

| Item | Notes |
|------|-------|
| **Collection / codex** | Godot-only meta screen |
| **GoldenLuckyFind** | Extra run upgrade (clover) |
| **Kenney glyph sell chips** | Inventory UX |
| **Sparkle score escalation** | Replaces Unity `ScoreFire` shader |
| **Legacy `shop_view`** | Dev-only; shop lives in `level_select_view` |

## Deferred (Sprint 7 / platform)

- Collection unlock key audit vs Unity persistent stats
- Game flags / speedrun filters
- Export presets + Steam achievements
- Git release tags (engine + ultravibe) — **manual after playtest sign-off**

## Release tag checklist (when ready)

1. Complete playtest checklist; file issues for any P0/P1 findings.
2. `git tag -a vX.Y.Z -m "Ultravibe Match-3 parity release"` in `ultravibe/`.
3. Tag matching engine commit in `com.gnosisgames.gnosisengine/` if engine changed.
4. Update this doc: set **Status** to **Signed off** with date + tag.
