# Match 3 localization (`Resources/i18n/Match3`)

Locale files mirror `availableLanguages.json` (one JSON file per language code).

Keys follow **`match3__phrase__<descriptor>`** (double underscores between segments), consistent with **`core__phrase__*`** in Core.

## Keys

| Key | Purpose |
| --- | --- |
| `match3__phrase__rewardRoundBoss` | Round reward line from boss/stage `rewardAmount` |
| `match3__phrase__rewardUnusedMoves` | `$1` per two remaining moves at round win (rounded up; e.g. 5 moves → `$3`) |
| `match3__phrase__rewardInterest` | Interest line: amount from `Currency.CalculateInterestAmount` at payout build time (before boss/unused grants) |

Wire-up: `Match3GnosisService.RoundRewardReasonBossBase` / `RoundRewardReasonUnusedMoves` / `RoundRewardReasonInterest`. UI resolves via `GnosisLocalizationService` (`MainHud.ResolveLocalizedText`).
