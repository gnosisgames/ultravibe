# Ultravibe — Agent Notes

Full workspace context: **[../AGENTS.md](../AGENTS.md)** (read that first in new chats).

## Engine submodule

Path: `addons/com.gnosisgames.gnosisengine` (tracks engine `main`).

- Engine commits: `cd addons/com.gnosisgames.gnosisengine` → commit/push engine repo → bump submodule in ultravibe.
- Pull latest engine: `git submodule update --remote --merge addons/com.gnosisgames.gnosisengine`

See `addons/com.gnosisgames.gnosisengine/docs/GAME_INTEGRATION.md` and workspace `.cursor/skills/engine-submodule/SKILL.md`.

## Testing

- **Do NOT** run the full integration suite after every minor code change — it is slow (~22 headless Godot boots).
- Run tests when the user asks, or once at the end of a substantial change.
- Command: `../scripts/resolve_godot.sh && ./tests/run_tests.sh`

## Visual verification

After UI changes: `./tools/capture_views.sh` → read `screenshots/_capture_*.png`.

## Test isolation

Tests redirect persistent state to `user://Saves/persistent_test.json` so your local saves are not overwritten.
