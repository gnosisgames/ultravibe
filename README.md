# Ultravibe (Godot)

Falling-block roguelike built on the shared [Gnosis Engine](../com.gnosisgames.gnosisengine/).

**Migration handoff:** see [../MIGRATION_STATUS.md](../MIGRATION_STATUS.md) for completed sprints, test list, known issues, and next steps.

## Setup

This project expects the engine as a **sibling folder**:

```text
02_godot/
├── com.gnosisgames.gnosisengine/
└── ultravibe/          ← this project
    └── addons/
        └── com.gnosisgames.gnosisengine -> ../../com.gnosisgames.gnosisengine
```

The addon symlink is already configured. Open `ultravibe/` as the Godot project root (not the engine repo).

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

## Structure

| Path | Purpose |
|------|---------|
| `game/` | Game-specific services, adapters, core systems |
| `data/` | Configuration manifest, JSON catalogs, i18n |
| `tests/` | Integration tests for the Ultravibe port |
| `main.tscn` | Entry scene (`UltravibeBootstrap`) |

Engine code (`core/`, `services/`, `adapters/`) lives only in `com.gnosisgames.gnosisengine/`.
