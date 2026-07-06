# Ultravibe (Godot)

Falling-block roguelike built on the shared [Gnosis Engine](../com.gnosisgames.gnosisengine/).

**Migration handoff:** see [../MIGRATION_STATUS.md](../MIGRATION_STATUS.md) for completed sprints, test list, known issues, and next steps.

## Setup

This project uses the engine as a git submodule at:

- `addons/com.gnosisgames.gnosisengine` (tracks engine `main`)

Clone with submodules:

```bash
git clone --recurse-submodules <ultravibe-repo-url>
```

Or if already cloned:

```bash
git submodule update --init --recursive
```

To pull latest engine changes (for early development workflow):

```bash
git submodule update --remote --merge addons/com.gnosisgames.gnosisengine
```

## Run

```bash
source ../scripts/resolve_godot.sh   # finds Godot_mono.app on this Mac
"$GODOT" --path .
```

Controls: A/D move, Z/X rotate, S soft drop, Space hard drop.

## Tests

```bash
source ../scripts/resolve_godot.sh
./tests/run_tests.sh
```

After adding or moving scripts:

```bash
"$GODOT" --path . --headless --import
```

## UI screenshots

```bash
./tools/capture_views.sh   # writes screenshots/_capture_*.png
```

See **[../AGENTS.md](../AGENTS.md)** for full agent/workspace docs.

## Export (Windows, macOS, Linux, Android, iOS)

Presets: `export_presets.cfg`. Docs: **[docs/EXPORT.md](docs/EXPORT.md)**. Shared templates: **`../templates/godot-export/`**.

```bash
source ../scripts/resolve_godot.sh
./tools/export_build.sh macOS              # one platform
./tools/export_all_local.sh                # all presets this Mac can build
```

## Structure

| Path | Purpose |
|------|---------|
| `game/` | Game-specific services, adapters, core systems |
| `data/` | Configuration manifest, JSON catalogs, i18n |
| `tests/` | Integration tests for the Ultravibe port |
| `main.tscn` | Entry scene (`UltravibeBootstrap`) |

Engine code (`core/`, `services/`, `adapters/`) lives in the submodule at `addons/com.gnosisgames.gnosisengine/`.
