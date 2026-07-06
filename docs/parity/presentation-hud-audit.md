# Presentation & HUD audit (Sprint 4)

Unity reference: `old_unity/ultravibe_unity/Assets/Game/Scripts/Match3Hud/`  
Godot: `game/match3/view/match3_hud*.gd`, `game/ui/inventory_tooltip_ui.gd`

**Automated checks:** `tests/test_presentation_hud.gd` (also `test_sprint6_ui.gd` for tooltip tags)

## Intentional visual delta: post-target “fire”

| Unity | Godot | Status |
|-------|-------|--------|
| `ScoreFire` shader/material on points/multi boxes | `Match3HudScoreEscalation` sparkle particles (`score_sparkle.gdshader`) | **replaced** (by design) |

Godot ramps sparkle intensity when banked or projected score crosses the round target and metrics keep increasing post-target. Behaviour is parity; the asset is **not** a port of Unity’s fire material.

## Tooltip score preview

| Rule | Unity | Godot | Status |
|------|-------|-------|--------|
| `${arg:scoreCalculationValueN}` in catalog copy | `GnosisScoreCalculationTooltipLocArgs` | `score_calculation_tooltip_loc_args.gd` | **match** |
| Hover equipped boon/consumable | `TooltipScorePreview` | `PlayHudIconBar` → `InventoryTooltipUi` → `CatalogLocalizationUi` | **match** |
| Shop offer preview | same arg resolver | `ShopCatalogUi.build_presentation` | **match** |
| Random preview reroll on hover | periodic reroll | `PlayHudIconBar._process` + `reroll_random_preview` | **match** |

## Metrics queue & input lock

| Rule | Unity | Godot | Status |
|------|-------|-------|--------|
| Step points/multi count-up during cascade | blocks input until done | `match3_dispatcher` `_busy` + `play_step_metrics_display` | **match** |
| Busy affordance | spinner / lock | `GameplayBusySpinner` when `Match3Dispatcher.is_busy()` | **match** |
| Bank transfer to total | animate then clear step metrics | `play_score_transfer_to_total` + sparkle fade | **match** |

## Round reward lines

| Step key | When | Test |
|----------|------|------|
| `match3__phrase__rewardInterest` | Interest preview > 0 | `test_shop_economy` |
| `match3__phrase__rewardCookieTime` | CookieTime equipped | `test_presentation_hud` |
| `match3__phrase__rewardPassiveIncome` | PassiveIncome equipped | `test_presentation_hud` |
| `match3__phrase__rewardDoubleDown` | DoubleDown equipped | `test_presentation_hud` |
| `match3__phrase__rewardSleeper` | Sleeper + unused shuffles | `test_presentation_hud` |
| Round / unused moves | stage reward + leftover moves | manual / reward view |

## Sidebar chrome

| Item | Unity | Godot | Status |
|------|-------|-------|--------|
| Quick restart hold | hold R / button | `RestartHoldButton` + `Match3HudHoldRestartButton` | **match** |
| Placeholder grid slot | n/a | removed (`PlaceholderButton` deleted) | **done** |

## Visual regression

Run `cd ultravibe && ./tools/capture_views.sh` and inspect `screenshots/_capture_*.png` after HUD changes.
