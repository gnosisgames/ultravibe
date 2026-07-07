# Mods folder (player / modder content)

**Ultravibe ships with mod loading disabled by default.** Dev example mods live under `tests/fixtures/mods/` and are not included in exports.

## Enabling mods (development)

1. Run Godot or the game with `--enable-mods`
2. Open the title screen **Mods** view and enable each mod you want
3. Restart the game so data merges apply

## Shipping builds

Exported games exclude `mods/*` and `mods-unpacked/*` from the PCK. Players can drop mod packages next to the game executable (see engine `docs/MODDING.md`).
