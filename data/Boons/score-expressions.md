# Match3 boon score expressions (`scoreCalculations`)

Finalize-step math for boons under `properties.scoreCalculations` is evaluated by `Match3ScoreExpr` (see `Assets/Game/Scripts/GnosisMatch3/Service/Match3ScoreExpr.cs`). **Tetris rule JSON** under `Assets/Resources/Data/Rules/Tetris/` still uses the older `type` / `fromContext` schema and is **not** covered here.

## Equip effects (`properties.effectApplication`)

Round-start, round-end, and move-end boon hooks read the **equipped inventory list** (per `instanceId` row), not `Ephemeral.match3.flags`.

| Value | Meaning |
|--------|---------|
| `perInstance` | Every equipped copy contributes (e.g. PassiveIncome, DoubleDown, Autocorrect). |
| `catalogOnce` | At most one contribution per catalog id (e.g. Backstabber, Simp, Hype Train, Manifestation shop dupes). |

Helpers: `Match3GnosisService.ForEachEquippedBoonSlotWithEffectApplication` in `Match3GnosisService.BoonEffectApplication.partial.cs`.

Equip invocations may call `Match3.ApplyBoonSlotCapacityDelta` / `Match3.ApplyConsumableSlotCapacityDelta` from `onActivateInvocations` / `onDeactivateInvocations` (e.g. **Wrong Chat**). Each equipped copy runs activate/deactivate when `effectApplication` is `perInstance`.

## Calc object

| Field | Required | Meaning |
|--------|----------|---------|
| `id` | recommended | Stable id for debugging |
| `phase` | yes | `"finalize"` (move-end), `"resolve_step"` (per cascade step or per scoring tile; see **resolve_step** below) |
| `parameters.trigger` | optional | `"item_destroyed"` — run only when a scoring-eligible tile is cleared in that step (juice on the boon bar immediately; bulk resolve-step pass skips these) |
| `when` | no | If present (string), calc runs only when this evaluates to true (see **Conditions**). Omit = always run. |
| `outcomes` | yes | List of `{ "op", "target", "value" }` (see **Outcomes**). |
| `parameters` | optional | Reserved for future use (e.g. shared literals for designers). |

### `properties.scaling.increments` (run-wide counters)

| `on` | When applied |
|------|----------------|
| `move_finalize` | Once per player move, before finalize score calcs (see `Match3GnosisService.ApplyBoonScalingIncrementsForFinalize`). |
| `resolve_step` | Once per cascade resolve step (see `ApplyBoonScalingIncrementsForResolveStep`). |
| `round_end` | Once when a round ends in **win or loss**, before `round_end` self-destructs. Payload uses current `score.movesRemaining` (unused moves). Optional numeric `scale` (default `1`) multiplies the resolved `from` value before adding to `counter`. |

When a counter actually increases, the boon bar shows **UP** in the same floating lane as the boon’s score effect (points / multi / money — inferred from `scoreCalculations` outcomes). For `move_finalize` / `resolve_step` increments this is queued and flushed at the start of that step’s score-calcs; for `incrementScalingCountersAfterApply` it is appended right after the proc step in `boonFinalizeSteps`. For events **outside** the move UI chain (`round_end` scaling increments, Red Flag / Looksmaxxing hooks, manual shuffle / Plot Armor, shop reroll / Clickbait, floor pool layout, item upgrades / Darwin), juice plays immediately via `TryPlayBoonScalingJuiceNow` (see `TryBankBoonSlotScalingCounter` with `preferImmediateJuice`). The HUD **`upgrade`** style is used for non-score effect procs (**Use**, round-budget boons) and item-level upgrades (e.g. Autocorrect **`+1`** only).

Example (Glow Up): bank `3 * movesRemaining` into `glowUpUnusedMovesPointsLifetime` each round end, then add that counter to `score.pointsTotal` every finalize.

## Outcomes

Each entry:

| Field | Values |
|--------|--------|
| `op` | `"add"` — add result to scalable target; `"multiply"` — multiply target by result (fractional factors use rounding rules in policy). |
| `target` | `"score.pointsTotal"`, `"score.multiTotal"`, or `"score.destroyedCount"`. |
| `value` | String expression, or a JSON number (treated as a numeric literal). |

If `value` is missing, empty, or **fails to parse/evaluate**, that outcome is **skipped** (no exception to gameplay).

## Bindings `{path}`

Inside `when` or `value`, **`{dotted.path}`** is replaced **before** math runs by reading the live store node and converting to a number (missing/invalid → `0` unless you bake a literal).

Prefixes (first segment):

- **`payload.`** — finalize payload built for this move (e.g. `payload.score.movesRemaining`, `payload.boons…`).
- **`ephemeral.`** — next segment is a top-level ephemeral key, then the rest of the path (e.g. `ephemeral.currencies.money.currentValue`, `ephemeral.statistics.match3.rounds.skipped`, `ephemeral.statistics.match3.shuffles.unused`).

### Run statistics (`ephemeral.statistics.match3`)

- **`moves.used`** — player swaps committed this run (incremented each move).
- **`moves.unused`** — sum of moves left at the end of each round (win/loss).
- **`shuffles.used`** — manual shuffles consumed this run.
- **`shuffles.unused`** — sum of manual shuffles left at the end of each round (win/loss).

Per-round leftovers are still on **`ephemeral.match3.currentMoves`** / **`currentShuffles`** during play and finalize; the statistics above are **cumulative across the run**.
- **`parameters.`** — calc `parameters` object.
- **`persistent.`** — persistent store root by name.

There are **no** bare variable names—only `{path}` placeholders.

### `payload.score` round-move helpers (finalize / resolve-step payloads)

- **`movesRemaining`** — moves left after the current move is committed (same moment as **All In**’s last-move check).
- **`movesPerformedThisRound`** — committed player moves this round (`1` on the first move, `2` on the second, …).
- **`isFirstMoveOfRound`** — `1` when `movesPerformedThisRound == 1`, else `0` (**Sus**).

### `payload.score` topology helpers (finalize / resolve-step payloads)

- **`topologyMatch5PlusComponentCount`** — number of orthogonally connected match components in the payload’s `MatchResult` list with **tile count ≥ 5** (includes straight lines, L/T/+, irregular five-tile shapes, and larger clusters; one count per component).
- **`hasTopologyMatch5Plus`** — `1` if `topologyMatch5PlusComponentCount > 0`, else `0`.

Axis-only and five-tile intersection breakdowns (`axisStraightMatch5OrLongerCount`, `intersectionLShape5Count`, …) remain available for boons that care about shape-specific rules.

Per-component triggers (set only during `match_component` calcs):

- **`lastAxisStraightMatch3`** / **`lastAxisStraightMatch4`** / **`lastAxisStraightMatch5OrLonger`** — `1` when the current topology component is that axis straight-line tier, else `0`.

### Palette temperature (scoring-eligible clears this move)

- **`coldDestroyedCount`** — tiles cleared that count for score with item id `green`, `blue`, or `purple`.
- **`warmDestroyedCount`** — tiles cleared that count for score with item id `red`, `orange`, or `pink`.
- **`lastDestroyedIsCold`** / **`lastDestroyedIsWarm`** — `1` on the tile just cleared when `parameters.trigger` is `item_destroyed` (for `when` clauses).
- **`destroyedByItemId.<itemId>`** — per-color counts (e.g. `{payload.score.destroyedByItemId.blue}`).

**Freeze** / **Hot** use `phase: "resolve_step"` with `parameters.trigger: "item_destroyed"` and `when` on `lastDestroyedIsCold` / `lastDestroyedIsWarm`. Outcome values use `4 * {payload.score.coldDestroyedCount}` / `21 * {payload.score.warmDestroyedCount}` so tooltips show move totals; each destroy binds that count to `1` for the calc so you get +4 Mult / +21 Points per tile with floating text on the boon slot.

**Block** / **Aura** / **Friendzoned** (and similar axis-line boons) use `parameters.trigger: "match_component"`. The engine runs the calc once per pure horizontal/vertical line component in each cascade clear step (`lastAxisStraightMatch3`, `lastAxisStraightMatch4`, `lastAxisStraightMatch5OrLonger`). L/T/+/irregular shapes do not fire these. Multiply outcomes stack per matching component in the step (three match-3 lines → ×3 applied three times). Boons that need a **whole-move** condition (e.g. two match-3 on the same move — **Copypasta**, **Echo Chamber**) stay on `phase: "finalize"`.

### `properties.contributionEchoes` (listener boons)

Equipped boons can react to other score contributions without hard-coded catalog ids in C#.

| `listen` field | Meaning |
|----------------|---------|
| `source` | `boon_score_step` — after another boon's resolve/finalize step; `cell_floor_finalize_step` — after each cell-floor finalize step (e.g. Steel). |
| `contributor` | For boon source: `other_boon` (default). |
| `contributorGameplayTag` | Contributor must have this `properties.gameplayTags` entry (e.g. `uncommon` for **Iconic**). |
| `excludeSelf` | Default `true`: listener ignores its own steps. |
| `floorTypeId` | For cell-floor source: match `Match3CellFloorTypes` id (e.g. `Steel`, `Gold`). |

| Echo field | Meaning |
|------------|---------|
| `outcomes` | Same shape as `scoreCalculations` outcomes; updates `payload.score` when the trigger fires. |
| `upgradeDisplayText` | If set to `up` / `UP`, shows **UP** in the echo’s points/multi lane (from echo `outcomes` targets). Other text uses the **`upgrade`** style (item upgrades only). |

Playback order at move end: all cell-floor steps (each followed by matching echoes), then all `boonFinalizeSteps` in order (including echoes chained after boon steps, e.g. Iconic after an Uncommon proc).

### `resolve_step` vs `finalize`

- **`resolve_step`** — after each cascade clear step (and optionally per scoring tile when `trigger` is `item_destroyed`). Contributions go to `boonResolveSteps` (in-step juice).
- **`finalize`** — once at move end before the score popup. Contributions go to `boonFinalizeSteps`.

## Operators (after substitution)

- Binary: `+` `-` `*` `/` `^` (`^` is power, **right-associative**: `2^3^2` = `2^(3^2)`).
- Unary: `+` `-` on primaries.
- Parentheses: `( … )`.
- Whitespace is ignored.

## Functions (case-insensitive)

| Call | Meaning |
|------|---------|
| `pow(a, b)` | `Math.Pow(a, b)` |
| `min(a, b)` | `Math.Min(a, b)` |
| `max(a, b)` | `Math.Max(a, b)` |
| `floor(x)` | `Math.Floor(x)` — **one** argument |

More helpers can be added in `Match3ScoreExpr` the same way if needed.

## `when` (conditions)

- If `when` is absent or blank → calc **always** runs.
- Otherwise the string is evaluated as:
  - **Comparison**: supports `<=`, `>=`, `==`, `!=`, `<`, `>` (longer operators are matched first). Left and right sides are full math expressions (including `{bindings}`).
  - **No comparison token**: true if the expression evaluates to a **non-zero** number.

Examples:

- `{payload.score.movesRemaining} == 0`
- `{payload.score.isFirstMoveOfRound} > 0` (first committed move of the round; see **Sus**)
- `{ephemeral.statistics.match3.rounds.skipped} > 0`

## Worked examples (current boons)

**All In** — ×4 mult only on last move of the round:

```json
"when": "{payload.score.movesRemaining} == 0",
"outcomes": [{ "op": "multiply", "target": "score.multiTotal", "value": "4" }]
```

**Sus** — ×2 mult only on the first move of the round:

```json
"when": "{payload.score.isFirstMoveOfRound} > 0",
"outcomes": [{ "op": "multiply", "target": "score.multiTotal", "value": "2" }]
```

**Iconic** — multiply mult by 1.5^(count of uncommon tags on active boons):

```json
"outcomes": [{ "op": "multiply", "target": "score.multiTotal", "value": "pow(1.5, {payload.boons.properties.gameplayTags.uncommon})" }]
```

**Sigma Male (Bull)** — add points from cash:

```json
"outcomes": [{ "op": "add", "target": "score.pointsTotal", "value": "2 * {ephemeral.currencies.money.currentValue}" }]
```

**Speedrun** — mult factor `1 + 0.25` per skipped round:

```json
"outcomes": [{ "op": "multiply", "target": "score.multiTotal", "value": "1 + 0.25 * {ephemeral.statistics.match3.rounds.skipped}" }]
```

**Oversharing** — add mult equal to consumables used this run (`Statistic` / consumable service maintains `ephemeral.statistics.consumables.used.total`):

```json
"outcomes": [{ "op": "add", "target": "score.multiTotal", "value": "{ephemeral.statistics.consumables.used.total}" }]
```

**Using `floor` / `min` / `max`** (illustrative):

```text
floor({ephemeral.currencies.money.currentValue} / 10)
max(1, {payload.score.movesRemaining})
min(100, 5 * {ephemeral.statistics.match3.rounds.skipped})
```

## Tooltip previews (`scoreCalculationValue1`, …)

Inventory/shop tooltips evaluate each outcome’s `value` expression (same bindings as finalize). Use in i18n as `${arg:scoreCalculationValue1}` (second outcome → `scoreCalculationValue2`, etc.).

- **`randInt` / `randFloat`**: preview uses a `Random` seeded from the boon `instanceId` (or catalog id in the shop), so the sample is stable per boon until the row changes.
- **`when` with random**: only the outcome `value` is previewed (e.g. Brainrot shows scaled +Mult, not whether the 1-in-10 proc rolled).

Prefer `${arg:scoreCalculationValue1}` in the main description instead of hard-coded ranges like `+1–48` so translators keep one string.

## Optional next steps

- Add a **short comment block** at the top of `Match3ScoreExpr.cs` duplicating the “one screen” summary above (keep this `.md` as the full reference).
- Put **one canonical example** under a boon’s `parameters` field for copy-paste (not read by the engine today—documentation only).

---

*Last aligned with boon JSON using `op` / `value` / `when` and `Match3ScoreExpr` builtins: `pow`, `min`, `max`, `floor`.*
