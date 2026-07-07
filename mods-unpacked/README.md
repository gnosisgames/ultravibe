# Godot Mod Loader (unpacked)

Place development mods here. Each mod is a folder named `{namespace}-{name}` with:

- `manifest.json` — GML metadata ([format](https://wiki.godotmodding.com/guides/modding/mod_files))
- `mod_main.gd` — entrypoint (`extends Node`, `_init()` required)

See `GnosisGames-Example/` for a minimal template.

**Shipped builds:** modders drop `.zip` files next to the game executable under a `mods/` folder.

**Gnosis data mods** (JSON merges, no script hooks) still live under `res://mods/` — see engine `docs/MODDING.md`.
