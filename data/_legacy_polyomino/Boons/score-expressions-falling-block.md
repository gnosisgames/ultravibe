# Falling Block boon score expressions (`scoreCalculations`)

Boon math under `properties.scoreCalculations` uses the shared engine evaluator **`GnosisScoreExpr`** (same parser as Ultravibe Match3). Evaluated by `FallingBlockGnosisService` — not the Rule service.

Legacy boons that still use `onActivateInvocations` → `Rule.AddRule` continue to work; prefer `scoreCalculations` for points/multi tweaks.

## Equip effects (`properties.effectApplication`)

Hooks that run per equipped slot (scaling increments, future `fallingBlockRoundEffectId` sync, catalog-specific C# hooks) read the **inventory list** (per `instanceId` row), not ephemeral flags.

| Value | Meaning |
|--------|---------|
| `perInstance` | Every equipped copy contributes (e.g. two **Poly** slots both add placement multi). |
| `catalogOnce` | At most one contribution per catalog id per pass (default when omitted). |

Helpers: `FallingBlockEffectApplication` and `FallingBlockGnosisService.ForEachEquippedBoonSlotWithEffectApplication` in `FallingBlockGnosisService.BoonEffectApplication.partial.cs`.

**Score calcs:** `properties.scoreCalculations` still evaluate **every equipped slot** (same as Ultravibe Match3 finalize calcs). Set `effectApplication` on the boon when non-score hooks should stack or dedupe.

## Round-end hooks (`FACT_FALLING_BLOCK_ROUND_ADVANCED`)

Some boons (e.g. **Santa**) no longer use `Rule.AddRule` on activate. They declare `"effectApplication": "perInstance"` and are handled in C# when a round completes — same idea as Match3 **CookieTime** / **PassiveIncome** in `AppendDynamicRoundRewardSteps` (`ForEachEquippedBoonSlotWithEffectApplication`).

| Boon | Behavior |
|------|----------|
| `santa` | `Consumable.RollRandomConsumable` once per equipped copy |
| `bob` | `Deck.AddDeckEntry` (Square4 + brick) once per equipped copy |
| `bounty` | `Deck.AddRandomDeckEntry` once per equipped copy |
| `duplicator` | `Deck.DuplicateRandomDeckEntry` once per equipped copy |
| `sunflower` | 1 in 3 → negative chance −1 scaling step (`TryApplyNegativeChanceScalingSteps(-1)`) |

Implementation: `FallingBlockGnosisService.BoonRoundEnd.partial.cs`, `RunScalingSteps.partial.cs`.

Future boons can use `TryApplyFallSpeedScalingSteps(-1)` for the same pattern on fall speed.

## Placement hooks (`FACT_FALLING_BLOCK_PIECE_LOCKED`)

| Boon | Behavior |
|------|----------|
| `meow` | 1 in 32 per equipped copy → `Consumable.RollRandomConsumable` |
| `mirror` | 1% per equipped copy → `Deck.AddDeckEntry` (same shape as locked piece) |
| `retro` | each 4-block (original tetromino) placement → −1s global ability cooldown |

Implementation: `FallingBlockGnosisService.BoonPieceLocked.partial.cs`. Each copy rolls chance independently (`perInstance`) where applicable.

Grid mutation on lock (Wizard, Urf): `BoonHooks.Placement.partial.cs` in `RunAfterLockCommon`.

## Line-clear hooks (`on_line_clear` ability, before score calcs)

| Boon | Chance | Condition | Ability |
|------|--------|-----------|---------|
| `pirate` | 1 in 3 | line clear included Trash (`discardable`) | +1 discard |
| `rage` | 1 in 2 | line clear while `currentDiscards <= 0` | +1 discard |
| `slayer` | 1 in 2 | Quadra (`rawLinesCleared == 4`) | `Consumable.RollRandomConsumable` |
| `eagle` | always | `clearedLineMaxGridY > 12` | −5s global ability cooldown |
| `ranger` | 1 in 4 | `rawLinesCleared >= 1` | −4s global ability cooldown |

Implementation: `FallingBlockGnosisService.BoonHooks.LineClear.partial.cs` (called from `ApplyBoonScoreCalculationsOnLineClear`). Rage runs first so the zero-discard gate uses bank at clear time. Ability CD: `TryReduceGlobalAbilityRemainingCooldownSeconds` in `Abilities.partial.cs`.

## Consumable-use hooks (`FACT_CONSUMABLE_USED` ability, before score calcs)

| Boon | Chance | Condition | Ability |
|------|--------|-----------|---------|
| `mushroom` | 1 in 3 | any consumable use | +1 discard |

Implementation: `FallingBlockGnosisService.BoonScoreConsumable.partial.cs`.

## Reward / shop offers

`FallingBlockRunCatalogOfferPolicy` filters reward-row boon pools: owned catalog ids are excluded when `boons.default.allowDuplicates` is false (`ephemeral.json`; ultravibe default). `GnosisBoonService.ActivateBoon` also rejects adding a `boonId` already in the inventory.

## Phases

| `phase` | When it runs | Targets |
|---------|----------------|---------|
| `on_placement` | After lock, once pending points/multi are updated from the placed piece | `score.pendingPoints`, `score.pendingMulti` → written back to `ephemeral.fallingBlock.pendingPoints` / `pendingMulti`. **Order:** all equipped **add** outcomes, then all **multiply** outcomes (slot order within each pass). |
| `on_line_clear` | Before `REQUEST_OBJECTIVE_CONTRIBUTION_FROM_LINE_CLEAR` rule interceptors | `score.pointsTotal`, `score.multiTotal` (cleared rows + pending baseline) |
| `on_consumable_use` | After `FACT_CONSUMABLE_USED` (run consumable counter already incremented) | `score.pendingPoints`, `score.pendingMulti` → ephemeral pending. Same `{ephemeral.statistics.*}` bindings as line clear; only the **target** differs (pending vs totals). |
| `on_boss_defeated` | After `FACT_FALLING_BLOCK_ROUND_ADVANCED` when the completed round was a boss round (`bossEncountersSurvivedThisRun` already incremented) | `score.pendingPoints`, `score.pendingMulti` → ephemeral pending |
| `on_discard` | *Reserved — not wired yet* | TBD |

## Calc object

| Field | Required | Meaning |
|--------|----------|---------|
| `id` | recommended | Debug id |
| `phase` | yes | `on_placement` or `on_line_clear` |
| `when` | no | Expression; omit = always run (see Ultravibe `score-expressions.md` for syntax) |
| `outcomes` | yes | `{ "op", "target", "value" }` list |
| `parameters` | optional | Merged into binding context as `parameters.*` |

## Outcomes

| Field | Values |
|--------|--------|
| `op` | `add`, `multiply` |
| `target` | `score.pointsTotal`, `score.multiTotal`, `score.pendingPoints`, `score.pendingMulti` |
| `value` | String expression or JSON number |

Final round progress after line clear is still **`pointsTotal × max(1, multiTotal)`** (then legacy rule interceptors may adjust further).

## Bindings `{path}`

Same rules as Match3 (see `ultravibe/Assets/Resources/Data/Boons/score-expressions.md`):

- **`payload.`** — phase-specific payload
  - **`on_placement`:** `placement.lockPieceBlockCount`, `placement.lockPieceMaxGridY` (highest grid row index occupied by the locking piece), `placement.touchesBorder` (`1` if any locked cell is on the grid edge), `placement.withoutRotation` (`1` = no rotations this piece), `placement.withoutHorizontalMove` (`1` = no horizontal moves this piece), `placement.horizontalMoves`, `placement.rotationCount` (session counts for the locking piece), `placement.secondsSinceSpawn` (seconds from active-piece spawn to lock, `-1` if unknown), `placement.hardDrop` (player hard-drop lock only; boss auto-drops are `false`), `placement.ultravibeIsSquare4` / `placement.ultravibeIsLine4` (`1` when the locked shape matches), `placement.tags.<tag>` (per-block variant + ultravibe config tag counts on the locking piece, e.g. `color_red`, `lucky`, `square`), `grid.maxColumnTopGridY` (highest locked row index among all columns after lock), `score.pendingPoints`, `score.pendingMulti`
  - **`on_line_clear`:** `rawLinesCleared`, `lineClearDistinctVariantCount`, `lineClearRgbOnly`, `lineClear.tags.*` (per-block counts in cleared rows, e.g. `color_green`), `clearedBlockCount`, …
- **`ephemeral.fallingBlock.`** — nested falling-block leaves (`currentDiscards`, `deckLength`, `pendingPoints`, … use path `ephemeral.fallingBlock.<leaf>`)
- **`ephemeral.`** — other top-level ephemeral keys (`statistics`, `boons`, `timers.tetrisRunElapsed.value` for run clock in seconds, …)
- **`parameters.`** — calc parameters object

## Examples

**Poly** — +3 Multi per block on placement:

```json
{
  "id": "poly_add_multi_per_block_on_placement",
  "phase": "on_placement",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingMulti",
    "value": "3 * {payload.placement.lockPieceBlockCount}"
  }]
}
```

**Glitch** — random 1–16 Multi per block on placement:

```json
{
  "id": "glitch_random_multi_per_block_on_placement",
  "phase": "on_placement",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingMulti",
    "value": "randInt(1, 16) * {payload.placement.lockPieceBlockCount}"
  }]
}
```

**Hacker** — random 1–31 Points per block on placement:

```json
{
  "id": "hacker_random_points_per_block_on_placement",
  "phase": "on_placement",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingPoints",
    "value": "randInt(1, 31) * {payload.placement.lockPieceBlockCount}"
  }]
}
```

**Helmet** — +10 Points on placement when the piece was hard dropped (`placement.hardDrop`):

```json
{
  "id": "helmet_add_pending_points_on_hard_drop_placement",
  "phase": "on_placement",
  "when": "{payload.placement.hardDrop}",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingPoints",
    "value": "10"
  }]
}
```

**Gnome** — +12 Multi on placement when the locked piece has at most 4 blocks:

```json
{
  "id": "gnome_add_pending_multi_small_poly_on_placement",
  "phase": "on_placement",
  "when": "{payload.placement.lockPieceBlockCount} > 0 && {payload.placement.lockPieceBlockCount} <= 4",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingMulti",
    "value": "12"
  }]
}
```

**Red Lover** — +3 Multi per Red-family block on placement:

```json
{
  "id": "red_lover_add_pending_multi_per_red_block_on_placement",
  "phase": "on_placement",
  "outcomes": [{ "op": "add", "target": "score.pendingMulti", "value": "3 * {payload.placement.tags.color_red}" }]
}
```

(Green / Blue / Orange lovers use `color_green`, `color_blue`, `color_orange` the same way.)

**Half** — +4 Multi on line clear per disabled block cleared (`lineClear.tags.disabled`). Disabled spawn on negative pieces stays on Rule:

```json
{
  "id": "half_add_multi_per_disabled_block_on_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} >= 1",
  "outcomes": [{
    "op": "add",
    "target": "score.multiTotal",
    "value": "4 * {payload.lineClear.tags.disabled}"
  }]
}
```

**Darwin** — ×1 Multi base on line clear, +1 multiplier per ultravibe ever added to the deck this run (`entriesAdded`):

```json
{
  "id": "darwin_mult_multi_by_deck_entries_added_on_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} >= 1",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "1 + {ephemeral.statistics.tetris.deck.entriesAdded}"
  }]
}
```

**Boomer** — ×1 Multi base on line clear, +3 multiplier per ultravibe ever removed from the deck this run (`entriesRemoved`). Discard destroy stays on Rule:

```json
{
  "id": "boomer_mult_multi_by_deck_entries_removed_on_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} >= 1",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "1 + 3 * {ephemeral.statistics.tetris.deck.entriesRemoved}"
  }]
}
```

**Shroomup** — same formula on consumable use (pending) and line clear (`multiTotal`): +4 × run consumables used:

```json
{
  "id": "shroomup_add_pending_multi_on_consumable_use",
  "phase": "on_consumable_use",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingMulti",
    "value": "4 * {ephemeral.statistics.consumables.used.total}"
  }]
},
{
  "id": "shroomup_add_multi_per_consumable_used_on_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} >= 1",
  "outcomes": [{
    "op": "add",
    "target": "score.multiTotal",
    "value": "4 * {ephemeral.statistics.consumables.used.total}"
  }]
}
```

**Miner** — +1 pending Multi on placement to start, +1 more per 100 blocks placed this run (`1 + floor(blocks ÷ 100)`; sum of `blockCount.blocksN × N`; stats include the locking piece):

```json
{
  "id": "miner_add_multi_per_blocks_hundreds_on_placement",
  "phase": "on_placement",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingMulti",
    "value": "1 + floor((2 * {ephemeral.statistics.tetris.ultravibePlaced.blockCount.blocks2} + 3 * {ephemeral.statistics.tetris.ultravibePlaced.blockCount.blocks3} + 4 * {ephemeral.statistics.tetris.ultravibePlaced.blockCount.blocks4} + 5 * {ephemeral.statistics.tetris.ultravibePlaced.blockCount.blocks5} + 6 * {ephemeral.statistics.tetris.ultravibePlaced.blockCount.blocks6} + 7 * {ephemeral.statistics.tetris.ultravibePlaced.blockCount.blocks7} + 8 * {ephemeral.statistics.tetris.ultravibePlaced.blockCount.blocks8} + 9 * {ephemeral.statistics.tetris.ultravibePlaced.blockCount.blocks9}) / 100)"
  }]
}
```

**Disco** — ×3 Multi on line clear when the deck has at least 8 special (positive variant) stack entries:

```json
{
  "id": "disco_mult_multi_on_line_clear_eight_plus_special_stack",
  "phase": "on_line_clear",
  "when": "{ephemeral.statistics.tetris.deck.present.summary.positiveVariantEntries} >= 8",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "3"
  }]
}
```

**Buddy** — +8 pending Points on placement per equipped Boon slot (`8 × filledSlotsCount`; 5 Boons → +40):

```json
{
  "id": "buddy_add_pending_points_per_filled_boon_slot_on_placement",
  "phase": "on_placement",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingPoints",
    "value": "8 * {ephemeral.boons.filledSlotsCount}"
  }]
}
```

**Chief** — +3 pending Points on placement per boss defeated this run (`3 × bossEncountersSurvivedThisRun`):

```json
{
  "id": "chief_add_pending_points_per_boss_defeated_on_placement",
  "phase": "on_placement",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingPoints",
    "value": "3 * {ephemeral.fallingBlock.bossEncountersSurvivedThisRun}"
  }]
}
```

**Black Hole** — +1 pending Point on placement per discard used this run (`totalDiscardsUsed`):

```json
{
  "id": "black_hole_add_pending_points_per_discard_used_on_placement",
  "phase": "on_placement",
  "outcomes": [{
    "op": "add",
    "target": "score.pendingPoints",
    "value": "{ephemeral.statistics.totalDiscardsUsed}"
  }]
}
```

**Cloud** — ×1.2 pending Multi on placement in the top half of the grid (`lockPieceMaxGridY > 10`):

```json
{
  "id": "cloud_mult_pending_multi_on_high_placement",
  "phase": "on_placement",
  "when": "{payload.placement.lockPieceMaxGridY} > 10",
  "outcomes": [{
    "op": "multiply",
    "target": "score.pendingMulti",
    "value": "1.2"
  }]
}
```

**Eagle** — ×1.5 pending Multi on placement in the top high of the grid (`lockPieceMaxGridY > 15`):

```json
{
  "id": "eagle_mult_pending_multi_on_top_placement",
  "phase": "on_placement",
  "when": "{payload.placement.lockPieceMaxGridY} > 15",
  "outcomes": [{
    "op": "multiply",
    "target": "score.pendingMulti",
    "value": "1.5"
  }]
}
```

**Lamma** — ×1.5 pending Multi every 6th ultravibe placed (`ultravibePlaced.total` already includes this placement; fires at 6, 12, 18, …):

```json
{
  "id": "lamma_mult_pending_multi_every_sixth_ultravibe_placement",
  "phase": "on_placement",
  "when": "{ephemeral.statistics.tetris.ultravibePlaced.total} % 6 == 0",
  "outcomes": [{
    "op": "multiply",
    "target": "score.pendingMulti",
    "value": "1.5"
  }]
}
```

**Microchip** — ×3 Multi on RGB line clear (`payload.lineClearRgbOnly`; cleared rows contain Red, Green, and Blue):

```json
{
  "id": "microchip_mult_multi_on_rgb_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.lineClearRgbOnly}",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "3"
  }]
}
```

**Doggy** — ×3 Multi on Triple line clear (`rawLinesCleared == 3`):

```json
{
  "id": "doggy_mult_multi_on_triple_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} == 3",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "3"
  }]
}
```

**Albert** — ×4 Multi on Quadra line clear (`rawLinesCleared == 4`):

```json
{
  "id": "albert_mult_multi_on_quad_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} == 4",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "4"
  }]
}
```

**Lone Wolf** — ×20 Multi on Monochrome line clear (`lineClearDistinctVariantCount == 1`; one block variant in cleared rows):

```json
{
  "id": "lone_wolf_mult_multi_on_monochrome_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} >= 1 && {payload.lineClearDistinctVariantCount} == 1",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "20"
  }]
}
```

**Dragon** — ×10 Multi on Penta line clear (`rawLinesCleared == 5`):

```json
{
  "id": "dragon_mult_multi_on_penta_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} == 5",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "10"
  }]
}
```

**Ninja** — ×2 Multi on Double line clear (`rawLinesCleared == 2`):

```json
{
  "id": "ninja_mult_multi_on_double_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} == 2",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "2"
  }]
}
```

**Rage** — ability-only: 1 in 2 on line clear while `currentDiscards <= 0` → +1 Discard (C# in `BoonHooks.LineClear.partial.cs`; no `scoreCalculations`).

**Mad Titan** — ×1 Multi per ultravibe slot below 10 in your stack on line clear (`10 - deckLength` when `deckLength < 10`; e.g. 6 ultravibes → ×4):

```json
{
  "id": "mad_titan_mult_multi_per_stack_slot_below_ten_on_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} >= 1 && {ephemeral.fallingBlock.deckLength} < 10",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "10 - {ephemeral.fallingBlock.deckLength}"
  }]
}
```

**Lonely Knight** — ×1 plus ×1 per empty Boon slot on line clear (`multiTotal`):

```json
{
  "id": "lonely_knight_mult_multi_by_empty_boon_slots_on_line_clear",
  "phase": "on_line_clear",
  "when": "{payload.rawLinesCleared} >= 1",
  "outcomes": [{
    "op": "multiply",
    "target": "score.multiTotal",
    "value": "1 + {ephemeral.boons.emptySlotsCount}"
  }]
}
```

**Retro** — ability-only: each 4-block tetromino placement → −1s global ability cooldown (C# in `BoonHooks.Placement.partial.cs`; gate matches `lockPieceBlockCount == 4` / `blocks4`).

**Chip** — ×1.25 pending multi on placement when no discards (runs in the multiply pass after other placement adds, e.g. Poly):

```json
{
  "id": "chip_mult_pending_on_placement_zero_discards",
  "phase": "on_placement",
  "when": "{ephemeral.fallingBlock.currentDiscards} <= 0",
  "outcomes": [{ "op": "multiply", "target": "score.pendingMulti", "value": "1.25" }]
}
```

On `on_placement`, all equipped boons run **add** outcomes first (slot order), then **multiply** outcomes — so Chip scales variant + Poly (etc.) pending multi, not just base cells.

**Hot Potato** — +15 pending Multi on placement when no discards left (`currentDiscards <= 0`):

```json
{
  "id": "hot_potato_add_pending_multi_on_placement_zero_discards",
  "phase": "on_placement",
  "when": "{ephemeral.fallingBlock.currentDiscards} <= 0",
  "outcomes": [{ "op": "add", "target": "score.pendingMulti", "value": "15" }]
}
```

## Migration from rules

| Old rule outcome | New score calc |
|------------------|----------------|
| `MATH_ADD` → `objectiveDelta` | `add` → `score.pointsTotal` (prefer explicit points, not legacy delta) |
| `MATH_MULTIPLY` → `objectiveDelta` | `multiply` → `score.multiTotal` or `score.pointsTotal` depending on design |

Remove `Rule.AddRule` / `RemoveRuleById` from `onActivateInvocations` when fully migrated.

## Tooltip previews (`scoreCalculationValue1`, …)

Inventory/shop tooltips evaluate each outcome’s `value` expression (same bindings as gameplay). Use in i18n as `${arg:scoreCalculationValue1}` (second outcome → `scoreCalculationValue2`, etc.).

- Wrap stat copy in semantic tags: `<multi>…</multi>`, `<point>…</point>`, `<chance>…</chance>` (same as Ultravibe / HUD).
- **`randInt` / `randFloat`**: preview uses a `Random` seeded from the boon `instanceId` (or catalog id in the shop); Glitch tooltips refresh while open when the preview is random.
- Prefer `${arg:scoreCalculationValue1}` for live totals (e.g. Poly “Currently +12 Multi” for a 4-block preview) instead of hard-coded ranges.

`FallingBlockGnosisService` registers a gameplay preview payload with `placement.lockPieceBlockCount` (active piece, else 4) and current pending score fields.

## `properties.scaling` (run counters)

| Field | Meaning |
|--------|---------|
| `counters` | Named ints on the equipped inventory row (persist for the run). |
| `increments[]` | `{ "on", "when"?, "counter", "delta" \| "from" }` — bumps a counter before score calcs for that phase. |

| `on` (Falling Block) | When applied |
|------------------------|----------------|
| `on_placement` | After lock, **before** placement `scoreCalculations` (add pass, then multiply pass). |
| `on_line_clear` | After line-clear stats, **before** line-clear `scoreCalculations`. |
| `round_end` | On `FACT_FALLING_BLOCK_ROUND_ADVANCED` (round just completed), before round-end boon hooks. |

Tooltip i18n: `${arg:currentIncrement00}` … maps to sorted `scaling.counters` keys (`00` = first key). No Falling Block boons use this yet.

## Future

- `on_discard` phase hook (same pattern as `on_consumable_use`: evaluate run-stat expressions, write `pendingMulti` / `pendingPoints`)
- Boon bar juice / contribution steps (Match3 `boonFinalizeSteps`) for floating +N on slot
