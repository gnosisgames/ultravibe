# Ultravibe Match-3 — Unity Parity Gap & Sprint Plan

**Compared:** Godot `ultravibe/` vs Unity `old_unity/ultravibe_unity/`  
**Date:** 2026-07-06  
**Method:** Catalog counts, service/HUD inventory, code grep for stubs, CI test list vs extended suite.

---

## Executive summary

The Godot port is **far along** for a full Match-3 roguelike: core loop, 8×3 progression, shop-in-level-select, boons/consumables/upgrades, bosses/effects, collection, i18n, and audio are implemented. Data parity is strong (80 boons, 134 boards, 26 levels, 20 effects).

**Main gaps** are not “missing the game” but **finish-line items**: mid-run save/continue, real endless mode, CI/test harness aligned with Match-3, tooltip score preview, presentation polish, statistics audit, and per-boon golden verification.

Godot is **ahead** of Unity in places: **collection compendium**, **GoldenLuckyFind** run upgrade, **inventory sell UX** (right-click / glyph chips), **extra consumables** (33 vs 31).

---

## Parity matrix (high level)


| System                                         | Unity | Godot               | Status                                             |
| ---------------------------------------------- | ----- | ------------------- | -------------------------------------------------- |
| Match-3 core (swap, cascade, gravity, spawn)   | Yes   | Yes                 | **done**                                           |
| Irregular boards (134)                         | Yes   | Yes                 | **done**                                           |
| 8 floors × 3 rounds, objective table           | Yes   | Yes                 | **done**                                           |
| Level select + integrated shop                 | Yes   | Yes                 | **done**                                           |
| Skip / double-down / round-action rewards      | Yes   | Yes                 | **done**                                           |
| Boss profiles + reroll upcoming boss           | Yes   | Yes                 | **done**                                           |
| Match3 effects (20)                            | Yes   | Yes                 | **done** (per-effect apply/remove tests)           |
| Cell floors + 100-slot pool                    | Yes   | Yes                 | **partial** (stats sync tested)                    |
| Boons (80) + flavors (7)                       | Yes   | Yes                 | **partial** (runtime broad; per-boon gaps unknown) |
| Consumables (31)                               | Yes   | 33                  | **done+** (2 extra grant entries)                  |
| Run upgrades (8 Golden*)                       | Yes   | 9 (+ Lucky Find)    | **done+**                                          |
| Item upgrades (6 colors)                       | Yes   | Yes                 | **done**                                           |
| Shop buy / reroll / pricing / pity             | Yes   | Yes                 | **done**                                           |
| Inventory sell (boon + consumable)             | Yes   | Yes                 | **done** (recent)                                  |
| Reward stepwise payout UI                      | Yes   | Yes                 | **done**                                           |
| Heartbeat low-moves SFX                        | Yes   | Yes                 | **done**                                           |
| HUD rails (boons/consumables/upgrades)         | Yes   | Yes                 | **done**                                           |
| Gamepad board focus                            | Yes   | Yes                 | **done**                                           |
| Settings + rebind + CRT + i18n (13 langs)      | Yes   | Yes                 | **done**                                           |
| Run statistics (`Ephemeral.statistics`)        | Yes   | Partial             | **partial**                                        |
| Mid-run save on exit                           | Yes   | No                  | **missing**                                        |
| Continue from title                            | Yes   | Stub                | **missing**                                        |
| Endless mode (post–round 24)                   | Yes   | Placeholder restart | **missing**                                        |
| Tooltip score preview on hover                 | Yes   | Yes                 | **done**                                           |
| Score “fire” over target / metrics juice queue | Yes   | Sparkle escalation  | **done** (visual delta)                            |
| Collection / codex                             | No    | Yes                 | **godot-only** (keep)                              |
| Steam achievements                             | Stub  | No                  | **n/a** unless shipping Steam                      |
| Sandbox debug shop overrides                   | Yes   | Engine panel only   | **partial**                                        |
| CI regression suite                            | N/A   | 14 smoke + extended | **done** (seed + perf in extended)                 |
| Docs (`MIGRATION_STATUS`, `tests/README`)      | N/A   | Polyomino-era stale | **gap**                                            |


---

## Catalog parity (counts)


| Catalog              | Unity | Godot                 |
| -------------------- | ----- | --------------------- |
| boons                | 80    | 80                    |
| consumables          | 31    | 33                    |
| runUpgrades          | 8     | 9 (`GoldenLuckyFind`) |
| itemUpgrades         | 6     | 6                     |
| levels (Bosses)      | 26    | 26                    |
| match3Boards         | 134   | 134                   |
| match3Effects        | 20    | 20                    |
| match3CellFloorTypes | 5     | 5                     |
| boonFlavors          | 7     | 7                     |


---

## Known stubs in Godot (code)


| Location                               | Issue                                                            |
| -------------------------------------- | ---------------------------------------------------------------- |
| `ultravibe_bootstrap.gd`               | `continue_saved_run()` clears save, returns false                |
| `ultravibe_bootstrap.gd`               | `try_save_in_progress_run()` still FallingBlock-centric          |
| `game_over_view.gd`                    | Endless button restarts run (placeholder)                        |
| `tests/test_persistence_boundaries.gd` | Requires `FallingBlock` service — **fails on Match-3 bootstrap** |
| `data/Upgrades/`                       | Legacy Polyomino upgrades — **not in `configuration.json`**      |
| `docs/parity/*.md`                     | Falling-block ledgers — stale for Match-3                        |
| `MIGRATION_STATUS.md` (workspace root) | Polyomino-focused — stale for Ultravibe                          |


---

## Sprint plan (recommended order)

### Sprint 1 — Ship blockers: save, continue, endless, CI health

**Goal:** Player can leave and resume; endless works; CI reflects Match-3 reality.

- [x] **Match-3 run snapshot** — implement `Match3.capture_runtime_snapshot` / hydrate (replace FallingBlock in `GnosisRunSave` path).
- [x] **Continue from title** — wire `continue_saved_run()` to restore Ephemeral + re-enter level-select or in-round state.
- [x] **Save on exit** — `try_save_in_progress_run()` persists Match-3 mid-run (round, inventories, shop state, floor queue).
- [x] **Endless mode** — `EnableEndlessMode` sets `endlessModeEnabled`, refills moves instead of loss, floor UI `N–∞`, victory only when non-endless and round ≥ 24.
- [x] **Rewrite `test_persistence_boundaries.gd`** for Match-3 (discovery + input assignments + run restart); remove FallingBlock dependency.
- [x] **Fix or quarantine** `test_persistence_boundaries` in `run_tests.sh` until rewrite lands.

**Exit criteria:** Headless test proves save → load → same round/money/boons; endless toggles behavior; CI green.

---

### Sprint 2 — Test harness & parity ledger

**Goal:** Confidence to port “the rest” without manual play-only QA.

- [x] **Tier CI:** keep `run_tests.sh` fast (~~14); add `run_tests_extended.sh` for Match-3 mechanics (~~38 tests).
- [x] **Wire critical extended tests:** boon sell, consumable sell, lucky find upgrade, shop polish, boss effects, skip/DD, item upgrade grant.
- [x] **Replace `docs/parity/mechanics-ledger.md`** with Match-3 ledger (link this file).
- [x] **Update** workspace `MIGRATION_STATUS.md` Ultravibe section + `tests/README.md`.
- [x] **Delete or archive** `data/Upgrades/` (Polyomino) and `tests/_legacy_polyomino/` from active docs (keep folder, mark archived).

**Exit criteria:** One command runs smoke + optional extended; parity README points at Match-3.

---

### Sprint 3 — Shop & economy audit

**Goal:** Money loop matches Unity feel.

- [x] **Audit** interest payout on reward panel vs Unity `RoundReward` (cap, divisor, preview line).
- [x] **Audit** shop weights: boon 66% / consumable 34% / item upgrade % / run upgrade pity (`runUpgradePityEveryN`).
- [x] **Verify** free reroll bank, floor price inflation, max discount 50%.
- [x] **Statistics** — ensure `match3.shop.`*, `match3.rounds.`*, boss defeats increment like Unity.
- [x] **Tests** for interest + shop pity + sell-from-inventory refund amounts.

**Exit criteria:** Side-by-side run: same seed, same shop offers/prices within documented tolerance.

---

### Sprint 4 — Presentation & HUD polish

**Goal:** Unity-level juice and clarity.

- [x] **Tooltip score preview** — hover boon/consumable/upgrade shows projected score impact (Unity `TooltipScorePreview`).
- [x] **Score over target** — Godot sparkle escalation (`Match3HudScoreEscalation`); **not** Unity `ScoreFire` material (intentional replacement).
- [x] **Metrics queue** — step points/multi count-up blocks input until complete (audit `match3_hud` busy spinner vs Unity).
- [x] **Reward lines** — verify all dynamic steps: CookieTime, PassiveIncome, DoubleDown bonus, Sleeper, etc.
- [x] **Remove** `match3__hud__tooltip__placeholder` “Coming soon” sidebar slot (quick restart on `RestartHoldButton`).
- [x] **Visual capture** baseline (`tools/capture_views.sh`) for regression.

**Exit criteria:** Screenshot diff checklist vs Unity for HUD, reward, shop, level-select.

---

### Sprint 5 — Boon & consumable depth

**Goal:** All 80 boons + 33 consumables behave per JSON (not just happy path).

- [x] **Contribution echoes** — golden tests for top echo pairs (finalize + score-step).
- [x] **Boon spot-check matrix** — prioritize high-risk: scaling counters, round effects, self-destruct, floor conversions, `perInstance` vs `catalogOnce`.
- [x] **Flavor chips** — Rental round cost, Perishable destroy, Steel/Ghost/Eternal rules.
- [x] **Consumable presentation** — juice timing, echo tracking (`echoLastRuneOrItemUpgradeGrantConsumableId`).
- [x] **Balance reports** — run `tools/match3_round_balance_report.gd` after boon fixes.

**Exit criteria:** Ledger marks each boon tag category tested; zero P0 boon bugs in playtest script.

---

### Sprint 6 — Bosses, effects & boards

**Goal:** Boss identity and effect modifiers feel identical.

- [x] **Per-effect tests** for all 20 `match3Effects` (disable color, half moves, shuffle each move, score restrictions, etc.).
- [x] **Boss onRoundStart/End invocations** — spot-check named bosses (e.g. Mister Beastus `lose_money_each_match`).
- [x] **Board difficulty pools** — easy/normal/hard selection matches floor stage type.
- [x] **Floor modifier pool UI** — tile panel counts sync with pool + grid (audit `sync_floor_modifier_tile_statistics_`*).

**Exit criteria:** Boss round playtest checklist (8 bosses minimum); effect test file covers 20/20.

---

### Sprint 7 — Meta, collection & platform

**Goal:** Ship-ready meta layer.

- [ ] **Collection discovery** — verify unlock on first acquire matches persistent keys Unity would have used for stats.
- [ ] **Game flags** (14) — play-mode toggles in UI match Unity filters.
- [ ] **Filters / gamemode** — speedrun excludes `time` tag, etc.
- [ ] **Export presets** — macOS/Windows templates if targeting release.
- [ ] **Steam** (optional) — achievements stub parity only if shipping.

**Exit criteria:** Collection tabs accurate; flags change runtime; export smoke build boots.

---

### Sprint 8 — Full port sign-off

**Goal:** Declare Unity parity for gameplay scope.

- [x] **Playtest script** — [playtest-checklist.md](playtest-checklist.md) (24-round + endless + shop-heavy; manual).
- [x] **Seed regression** — `test_seed_regression.gd` (round rewards, shop offers, lucky find @ seed 424242).
- [x] **Performance** — `test_match3_boot_perf.gd`, `test_match3_cascade_perf.gd`; [performance-budgets.md](performance-budgets.md).
- [x] **Cleanup** — `shop_view` documented as dev-only legacy ([README.md](README.md#legacy-ui-routes)).
- [ ] **Tag release** in engine + ultravibe repos (manual after playtest).

**Exit criteria:** [sign-off.md](sign-off.md) automated gates green; manual checklist complete before tag.

---

## Intentional deltas (keep in Godot)


| Item                           | Notes                                                                  |
| ------------------------------ | ---------------------------------------------------------------------- |
| **Collection screen**          | Godot addition — no Unity equivalent                                   |
| **GoldenLuckyFind**            | Run upgrade (clover); Unity had no Lucky Find upgrade in `runUpgrades` |
| **Kenney input glyphs**        | Godot tooltip sell chips                                               |
| **Post-target score juice**    | Sparkle particle escalation replaces Unity `ScoreFire` shader          |
| **Polyomino `data/Upgrades/`** | Remove; not part of Ultravibe                                          |


---

## Quick wins (any sprint)

- Delete `luckyGuardSurgeUpgrade` ✅ (done)
- Move Lucky Find to `runUpgrades` ✅ (done)
- Commit engine Kenney glyphs ✅ (done)
- Fix `test_persistence_boundaries` (Sprint 1)
- Update `docs/parity/README.md` pointer to this file (Sprint 2)

---

## Reference paths


|                | Path                                               |
| -------------- | -------------------------------------------------- |
| Unity game     | `old_unity/ultravibe_unity/Assets/Game/`           |
| Unity data     | `old_unity/ultravibe_unity/Assets/Resources/Data/` |
| Godot services | `ultravibe/game/match3/services/`                  |
| Godot data     | `ultravibe/data/`                                  |
| Godot tests    | `ultravibe/tests/test_*.gd`                        |
| CI runner      | `ultravibe/tests/run_tests.sh`                     |


