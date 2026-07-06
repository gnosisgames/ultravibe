# Shop & economy audit (Sprint 3)

Unity reference: `old_unity/ultravibe_unity/Assets/Game/Scripts/Match3Shop/`  
Godot: `game/match3/services/match3_shop_service.gd`, `gnosis_currency_service.gd`

**Automated checks:** `tests/test_shop_economy.gd` (also `test_shop_polish.gd`, `test_boon_sell.gd`, `test_consumable_sell.gd`)

## Interest (round reward preview)

| Rule | Unity | Godot | Status |
|------|-------|-------|--------|
| Formula | `min(balance, cap) / divisor` | `_compute_interest_delta` | **match** |
| Default cap | 25 | `interestBaseCap` 25 | **match** |
| Default divisor | 5 | `interestRateDivisor` 5 | **match** |
| Reward step key | `match3__phrase__rewardInterest` | same | **match** |
| Stat `currency.money.interest` | incremented on grant | `ApplyInterestOnce` + reward grant | **match** |

## Core shop weights

| Tuning | Unity default | Godot default | Status |
|--------|---------------|---------------|--------|
| Boon slot source | 66% | `boonWeightPercent` 66 | **match** |
| Consumable source | 34% | `consumableWeightPercent` 34 | **match** |
| Item upgrade source | 0% (data-driven) | `itemUpgradeWeightPercent` 0 | **match** |
| Run upgrade roll | 120‰ | `runUpgradeShopChancePermille` 120 | **match** |
| Run upgrade pity | every 5 shops | `runUpgradePityEveryN` 5 | **match** |
| Boon rarity weights | 70 / 25 / 5 | same | **match** |

## Pricing

| Rule | Unity | Godot | Status |
|------|-------|-------|--------|
| Max discount | 50% clamp | `maxShopDiscountPercent` 0.5 | **match** |
| Floor inflation | per-floor % on base | `priceInflationPerFloorPercent` | **match** |
| Min price | 1 | `minPrice` 1 | **match** |
| Core base price | 4 | `core.basePrice` 4 | **match** |
| Reroll base / step | 5 + 2×count | same | **match** (see `test_shop_polish`) |
| Free reroll bank | consumes before paid | `freeRerollCount` | **match** (see `test_shop_polish`) |

## Inventory sell

| Rule | Unity | Godot | Status |
|------|-------|-------|--------|
| Sell refund | ~50% of buy | `max(1, buyPrice / 2)` | **match** |
| Boon sell | Deactivate + refund | `test_boon_sell` | **match** |
| Consumable sell | Remove + refund | `test_consumable_sell` | **match** |
| Sale statistic | shop sales counter | `match3.shop.sales.total` | **match** |

## Statistics counters

| Key | When incremented | Test |
|-----|------------------|------|
| `match3.shop.purchases.total` | Core shop buy (non-run-upgrade) | `test_shop_economy` |
| `match3.shop.upgrades.purchased.total` | Run upgrade purchase | manual / shop flow |
| `match3.shop.rerolls.total` | Paid/free reroll | `test_shop_polish` |
| `match3.shop.sales.total` | Inventory sell | `test_shop_economy` |
| `match3.rounds.played` | PlayLevel | `test_match3_core` |
| `match3.rounds.skipped` | SkipLevel | `test_skip_*` |
| `match3.rounds.bossesDefeated` | Boss round win | boss tests |
| `currency.money.interest` | Interest grant | `test_shop_economy` |

## Known tolerances

- Offer **contents** are seed-driven; parity tests verify tuning constants and pity injection, not exact SKU lists per seed.
- Side-by-side seed regression (full shop SKU match) remains a manual QA step until golden-seed harness lands (Sprint 8).
