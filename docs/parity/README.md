# Unity-to-Godot Parity Ledger

This folder tracks mechanics parity between the Unity source of truth
(`01_unity/ultravibe`) and the Godot port (`ultravibe`).

## Files

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

