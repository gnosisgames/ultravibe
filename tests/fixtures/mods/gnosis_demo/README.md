# Gnosis Demo Mod

Example **Gnosis data mod** (`res://tests/fixtures/mods/gnosis_demo/`). Not shipped in game exports.

## What it does

Merges **`ModDrizzle`** into `Persistent.configuration.boons` via `Data/persistent.json`:

- **Name:** Mod Drizzle
- **Effect:** +20 points at the end of each move (finalize phase)
- **Rarity:** common (appears in the shop boon pool)
- **Icon:** reuses Slop art (`boonSlopSprite`)

Open the title screen **Mods** view to see the mod listed. Start a run and check the shop — **Mod Drizzle** should appear alongside vanilla boons.

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Mod metadata + Mods screen UI settings |
| `Data/persistent.json` | Boon definition + i18n merge |

## Verify headless

```bash
cd ultravibe
source ../scripts/resolve_godot.sh
./tests/run_tests_mods.sh
```
