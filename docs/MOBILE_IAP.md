# Mobile in-app purchases (Ultravibe)

Plugins are **installed in the project** (like GodotSteam). They are not something you configure only in the Godot editor UI without files on disk.

## What is installed

| Platform | Plugin | Path |
|----------|--------|------|
| **Android** | [GodotGooglePlayBilling](https://github.com/godot-sdk-integrations/godot-google-play-billing) | `addons/GodotGooglePlayBilling/` |
| **iOS** | [godot-storekit2](https://github.com/godot-sdk-integrations/godot-storekit2) | `ios/plugins/godot-storekit2/` |

Re-install or update:

```bash
cd ultravibe
chmod +x tools/install_mobile_iap.sh
./tools/install_mobile_iap.sh
```

## Enabled in project

- `project.godot` → **GodotGooglePlayBilling** plugin enabled
- `export_presets.cfg` → Android uses Gradle; iOS has `plugins/godot-storekit2=true`, min iOS **15.0** (StoreKit 2)

## What you still do manually (stores)

Plugins let the **game talk to Google/Apple**. You still need store setup:

1. **Google Play Console** — create app `com.gnosisgames.ultravibe`, add in-app product `ultravibe_full_unlock` (non-consumable), upload a build to internal testing
2. **App Store Connect** — create app, add IAP `com.gnosisgames.ultravibe.full` (non-consumable)
3. Test on real devices with sandbox/test accounts (IAP does not work in the desktop editor)

Product IDs live in `data/edition.mobile.json`.

## Code status

- **Engine:** `GnosisEditionStoreHost` + `GnosisGooglePlayStoreBridge` — auto-wired on mobile by `GnosisGodotEngine`
- **Game:** `UltraEditionPolicy` (trial time limit) + product IDs in `data/edition.mobile.json`
- Game over shows **Unlock** / **Restore** while the mobile trial is active (via `GnosisEditionService`)
- **iOS:** bridge registers but billing is not implemented yet (returns unavailable)

## Export

```bash
cd ultravibe
./tools/setup_android_sdk.sh          # once
./tools/export_android_apk.sh         # debug APK for sideload
./tools/export_android_aab.sh         # release AAB (needs .secrets/ keystore)
```

## Google searches (for reference)

- `GodotGooglePlayBilling`
- `godot-storekit2 StoreKit 2`
