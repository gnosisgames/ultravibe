# Mission stakes — difficulty ladder (White first)

Ten cumulative run difficulties using polyomino **mission** sprites.  
Sprites: `res://assets/ui/missions/<id>.png` (formerly `poly.png` → **`white.png`**).

Inspired by [Balatro stakes](https://balatrowiki.org/w/Stakes): each tier **keeps all prior modifiers**; beat stake *N* to unlock *N+1*.

---

## Progression path

```text
White → Opal → Bronze → Silver → Gold → Ruby → Emerald → Sapphire → Amethyst → Obsidian
  1       2       3        4       5      6        7          8          9          10
```

- **White** — entry stake. Uses the legacy Poly mission art, renamed.
- **Obsidian** — capstone mission tier.

---

## Tier table (modifiers)

*Rules not defined yet — `modifiers` is `{}` in each `data/Stakes/*.json`. Design cumulative rules before implementation.*

| # | Mission | Sprite |
|---|---------|--------|
| 1 | **White** | `white.png` |
| 2 | **Opal** | `opal.png` |
| 3 | **Bronze** | `bronze.png` |
| 4 | **Silver** | `silver.png` |
| 5 | **Gold** | `gold.png` |
| 6 | **Ruby** | `ruby.png` |
| 7 | **Emerald** | `emerald.png` |
| 8 | **Sapphire** | `sapphire.png` |
| 9 | **Amethyst** | `amethyst.png` |
| 10 | **Obsidian** | `obsidian.png` |

---

## Unlock flow

- `persistent.maxUnlockedMissionStakeIndex` starts at `0` (**White** only).
- Win full run on stake *N* → unlock *N+1*.
- Locked stakes: greyed mission sprite + “Beat {previous} to unlock”.

---

## Runtime hooks

| Modifier key | Apply in |
|--------------|----------|
| `targetMult` | Target score resolver |
| `floorTargetGrowthMult` | Per-floor multiplier |
| `normalRoundGoldMultiplier` | Round-clear rewards |
| `bonusShufflesPerRound` | Round start shuffles |
| `luckyFindPermanentDelta` | `luckyFindTuning` at run start |
| `shopEternalChancePercent` / `shopPerishableChancePercent` / `shopRentalChancePercent` | Boon flavor rolls |
| `bossMovesDelta` | Boss stage move budget |

Data: `data/Stakes/index.json`.

---

## UI

- Run setup: mission row **White → Obsidian**.
- HUD: active mission icon + localized name.
- i18n: `data/i18n/Missions/en.json`.

---

## Related

- Sprites: `01_unity/polyomino/Assets/Game/Art/Sprites/Missions/` (poly → white rename in Godot)
- Balance tooling: `tools/match3_round_balance_report.sh`
