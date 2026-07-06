# Unity-to-Godot Parity Ledger

This folder tracks mechanics parity between the Unity source of truth
(`old_unity/ultravibe_unity`) and the Godot port (`ultravibe`).

## Primary handoff (Match-3)

- **[ULTRAVIBE_MATCH3_PARITY_SPRINTS.md](ULTRAVIBE_MATCH3_PARITY_SPRINTS.md)** — gap analysis + sprint backlog (2026-07-06)

## Legacy (Falling-block / Polyomino era)

- [mechanics-ledger.md](mechanics-ledger.md) — system-by-system status
- [invocations-ledger.md](invocations-ledger.md) — every `FallingBlock.*` function referenced by JSON data
- [invocations-extract.txt](invocations-extract.txt) — raw extraction from `data/`

## Status keys

| Status | Meaning |
|---|---|
| **done** | Unity behavior identified, Godot executes it, parity test exists |
| **partial** | Core path works; edge cases or secondary hooks remain |
| **missing** | Not implemented in Godot |
| **data-only** | JSON/catalog exists but gameplay code does not run it |
| **n/a** | Intentionally omitted (e.g. vestigial hold piece) |

## Legacy UI routes

| View | Status | Notes |
|------|--------|-------|
| `level_select_view` | **active** | Integrated shop (`ShopSection`, `ShopOffers`) |
| `shop_view` | **dev-only / legacy** | Registered in `main.tscn` but **not pushed** by `match3_play_adapter`; normal play never routes here |

## Parity tests

| Test | Covers |
|---|---|
| `tests/test_parity_invocations.gd` | AddBaseDiscardsDelta, AddVariantLevelDelta, SetFallingPieceVariant, hammer row clear, ChangeFallSpeed |
| `tests/test_parity_boss_effects.gd` | ReduceGravitySpeed, InvertControls, DisableRotation rule registration |
| `tests/test_parity_coop.gd` | Lane bounds, split-lane row clearing |
| `tests/test_parity_content_catalog.gd` | All 19 FallingBlock functions registered; catalog counts |
| `tests/helpers/parity_harness.gd` | Seeded grid + invoke helpers |

## Working rule

A mechanic is **not done** until a focused Godot test or golden scenario proves it.

