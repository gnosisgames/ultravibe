# Playtest checklist (Sprint 8 sign-off)

Manual QA scripts for Unity parity sign-off. Run on a **release candidate** build (not headless). Check both **keyboard/mouse** and **gamepad** where noted.

Record: build commit, date, tester, input device, any deltas vs Unity.

---

## Script A — Standard 24-round run (~45–60 min)

**Goal:** Full progression loop without endless mode.

1. New run from title; note starting money and first shop offers.
2. **Level select:** verify floor preview (3 rounds, boss skull on round 3), round-action reward icon, integrated shop offers.
3. **Round 1 (normal):** swap, cascade, score HUD, boon/consumable rails, floor modifier column if applicable.
4. **Skip** a skippable round (non-boss); confirm money cost and floor advance.
5. **Double-down** once; confirm higher target and reward on clear.
6. **Boss round:** confirm boss theme, match3 effect active, cannot skip.
7. **Reward panel:** stepwise payout (base, interest, CookieTime/PassiveIncome if owned, boon echoes).
8. Repeat floors 2–8; hit at least **8 distinct boss profiles**.
9. **Round 24 victory:** run-complete screen (not endless).
10. **Statistics:** spot-check `match3.shop.*`, `match3.rounds.*`, boss defeats in ephemeral stats.

**Pass:** No blockers; mechanics match expected JSON behavior; no soft-lock.

---

## Script B — Endless branch (~15 min after Script A or seeded save)

**Goal:** Post-victory endless continuation.

1. Complete round 24 (or use debug/save at victory).
2. Enable **Endless mode** from game-over / victory flow.
3. Confirm floor UI shows **N–∞**, moves refill on loss instead of game over.
4. Play 2+ rounds past 24; confirm no erroneous run-complete until player ends run.
5. Verify `endlessModeEnabled` clears terminal win flags (no stuck victory overlay).

**Pass:** Endless behaves per `EnableEndlessMode` (see `test_endless_mode.gd`).

---

## Script C — Shop-heavy run (~30 min)

**Goal:** Economy loop under reroll/pity/sell pressure.

1. New run; prioritize shop on every level-select stop.
2. **Reroll** until free bank exhausted; confirm price increments.
3. Buy boons, consumables, item upgrade grants, and (when offered) run upgrade.
4. Trigger **run-upgrade pity** (5 shops without run upgrade) if not seen naturally.
5. **Sell** boon and consumable from inventory (right-click / glyph chip); confirm 50% refund.
6. Use **GoldenShoppingBag** or discount boons if acquired; confirm cap at 50% max discount.
7. **Reroll upcoming boss** consumable once; confirm boss preview changes.
8. Finish at least floor 3 with 10+ shop transactions.

**Pass:** Pricing, pity, refunds, and stats match `test_shop_economy.gd` / `shop-economy-audit.md`.

---

## Input coverage

| Area | KB/M | Gamepad |
|------|------|---------|
| Board swap / focus | ☐ | ☐ |
| Level select navigation | ☐ | ☐ |
| Shop buy / reroll | ☐ | ☐ |
| Inventory sell | ☐ | ☐ |
| Pause / settings | ☐ | ☐ |
| Reward panel advance | ☐ | ☐ |

---

## Known intentional deltas (not bugs)

See [sign-off.md](sign-off.md) and sprint doc **Intentional deltas** table (collection, GoldenLuckyFind, sparkle vs ScoreFire, glyph sell chips).

---

## Automated pre-check (run before manual session)

```bash
cd ultravibe
source ../scripts/resolve_godot.sh
./tests/run_tests.sh
./tests/run_tests_extended.sh
```

Seed + perf spot checks:

```bash
"$GODOT" --path . --headless --script res://tests/test_seed_regression.gd
"$GODOT" --path . --headless --script res://tests/test_match3_boot_perf.gd
"$GODOT" --path . --headless --script res://tests/test_match3_cascade_perf.gd
```
