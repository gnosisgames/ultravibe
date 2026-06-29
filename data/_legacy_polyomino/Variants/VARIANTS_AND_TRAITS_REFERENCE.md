Variant traits and ultravibe variants – reference for AI ideation

Block traits (what they do)

rigid - Piece cannot rotate if any block has this trait.
slippery - Block can slip through gaps when falling.
discardable - Piece can always be discarded; does not consume the secondary action.
undiscardable - Piece cannot be discarded; discard has no effect on this piece.
eternal - Survives line clears; falls normally when rows below clear. Full rows made only of eternal blocks do not trigger line clear. Can still be crushed (heavy vs soft), healed, or wiped by a full-grid clear (e.g. bomba).
hard - Cannot be crushed by heavy blocks; soft blocks can be crushed.
unpushable - Piece cannot be pushed by wind or other push mechanics.
soft - Can be pushed by bosses; can be crushed by heavy blocks.
heavy - When falling, crushes (destroys) all soft blocks in its path until hitting a hard block or the floor.
gyroscopic - Piece can rotate even when a boss/effect disables rotation globally.
ephemeral - After a random number of placements, this piece's blocks vanish without line clear or collapse.
unstable - When any line is cleared, this block has 50% chance to destroy itself.
contagious - Spreads to adjacent filled blocks and converts them to this variant (placement-interval effect).
expansive - Expands into adjacent empty cells on placement interval (e.g. Moss).
rising - Expands into adjacent empty cells vertically (up and down) on placement interval (e.g. Blightmoss).
immutable - Cannot be converted by other variants (e.g. Honeycomb spread).
sinking - Every few placements, block slips down one row if the cell below is empty.
linked - When this block is cleared, all 8-adjacent blocks with linked are also removed, then column collapse.
lucky - Each block: +1% chance for positive passive effects, -1% for negative (min 1% negative).
healing - Each placement, small chance to heal a random negative block into a special positive variant.
poisoning - Each placement, small chance (3%) to convert a random positive block into a random negative variant. Opposite of healing.


Ultravibe variants (by category)

Normal (base / neutral)

Blue - Base color; `basePoints` 10 and `baseMulti` 1 per cell (summed into pending on lock, banked on clear as `points × max(1, multi)`).
Green - Base color, no special behavior.
Orange - Base color, no special behavior.
Red - Base color, no special behavior.
Ghost - Traits: soft. `basePoints` 0, `baseMulti` 0 (no score contribution).
Disabled - `basePoints` 0, `baseMulti` 0.

Each variant JSON may define `basePoints`, `baseMulti`, `pointsPerLevel`, and `multiPerLevel` (per cell, summed on lock into `pendingPoints` / `pendingMulti`, banked on line clear). **Global variant level** lives in `Ephemeral.fallingBlock.variantLevels[variantId]` (starts at 1). Effective per-cell stats:

- `points(level) = basePoints + (level - 1) × pointsPerLevel`
- `multi(level) = baseMulti + (level - 1) × multiPerLevel`

Only **neutral** and **positive** variants are levelable. Gon consumables (e.g. `bluegon`, `brickgon`) call `SetFallingPieceVariant` then `AddVariantLevelDelta` (+1 for that type). Boon `spawnConversions` do **not** change levels.

Boon interceptors may adjust `objectivePoints` and `objectiveMulti` on `REQUEST_OBJECTIVE_CONTRIBUTION_FROM_LINE_CLEAR`; final round progress += `points × max(1, multi)`.

Positive (beneficial) — per-cell `basePoints` / `baseMulti` add to pending on lock and to cleared rows on line clear (same pipeline as normals; `0` on an axis = no change on that lane).

| Variant | basePoints | baseMulti | Bonus style |
|---------|------------|-----------|-------------|
| Lucky | 0 | +5 | Multi-only |
| Slime | +25 | 0 | Points-only |
| Moss | +18 | +2 | Balanced mixed |
| Brick | +40 | 0 | Heavy points-only |
| Trash | +10 | +2 | Light mixed |
| Honeycomb | +14 | +2 | Light mixed (nerfed) |
| Heart | +15 | +2 | Support mixed |
| Cog | +10 | +4 | Multi-lean mixed |

Lucky - Traits: soft, lucky. Improves odds of positive passive effects; chance to give SimpleTierReward per block.
Brick - Traits: rigid, hard, unpushable, heavy. Heavy crusher; chance per placement to add Multi per block.
Slime - Traits: slippery, soft. Slippery; chance per placement to add Points per block.
Trash - Traits: discardable, soft. Easy to discard; chance per placement to add SecondaryActions (extra discards).
Honeycomb - Traits: soft, gyroscopic, immutable, contagious. Spreads to adjacent filled cells; time interval gives BoonRandomIncrement, placement chance gives Points per block.
Heart - Traits: soft, healing. Chance to heal a negative block to positive; chance per placement to add BoonFriendship.
Moss - Traits: soft, expansive, gyroscopic. Expands into adjacent empty cells; chance per placement to add Points per block.
Cog - Traits: hard, linked, sinking, gyroscopic. Sinks into gaps below; clearing one linked block removes all 8-adjacent linked blocks; cannot be crushed.

Negative (harmful or risky) — per-cell `basePoints` / `baseMulti` subtract from pending on lock and from cleared rows on line clear. Stored pending and line-clear components are floored at **1** each (never below 1 while active).

| Variant | basePoints | baseMulti | Penalty style |
|---------|------------|-----------|----------------|
| Heartless | -8 | -1 | Light mixed (points + multi) |
| Blightmoss | 0 | -5 | Multi-only |
| Rust | -18 | -3 | Medium mixed |
| Obsidian | -50 | 0 | Heavy points-only |

Heartless - Traits: soft, poisoning. Chance per placement to add BoonFriendshipDrain (hurts friendship).
Rust - Traits: immutable, hard, contagious. Cannot be converted; spreads to adjacent filled blocks.
Blightmoss - Traits: soft, rising. Expands up and down into empty cells (negative counterpart to Moss).
Obsidian - Traits: negative, rigid, soft, eternal. Large points penalty per cell; survives line clears but can be crushed or healed.


Passive effect targets (for variants)

Effects are tied to triggers like OnPlacementInterval or OnTimeInterval. Common targets:

Points - score
Money - currency
Multi - multiplier
SecondaryActions - discard/extra actions
BoonFriendship / BoonFriendshipDrain
BoonValueDrain - drain boon strength
BoonRandomIncrement - random boon benefit
SimpleTierReward
FallingSpeedAddPerBlock
OnEphemeralVanish - when ephemeral blocks disappear
