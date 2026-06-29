class_name FallingBlockGameFlags
extends RefCounted

## Run toggles read from Ephemeral.fallingBlock.gameFlags.<key> (bool).
## Mirrors FallingBlockGameFlags.cs defaults.

const ORIGINAL_ONLY_BLOCK_COUNT := 4
const BOSS_ONLY_SPAWN_INTERVAL_SEC := 3

static func _read_flag(context, key: String, default_value: bool) -> bool:
	var fb := FallingBlockEphemeral.get_fb(context)
	var flags := fb.get_node("gameFlags")
	if flags.is_valid() and flags.get_type() == GnosisValueType.OBJECT:
		var v := flags.get_node(key)
		if v.is_valid() and v.get_type() == GnosisValueType.BOOL:
			return bool(v.value)
	return default_value

static func is_original_only(context) -> bool:
	return _read_flag(context, "originalOnly", false)

static func is_include_negatives(context) -> bool:
	return _read_flag(context, "includeNegatives", true)

static func is_negative_only(context) -> bool:
	return is_include_negatives(context) and _read_flag(context, "negativeOnly", false)

static func is_max_speed_only(context) -> bool:
	return _read_flag(context, "maxSpeedOnly", false)

static func is_include_discards(context) -> bool:
	return _read_flag(context, "includeDiscards", true)

static func is_infinite_discards(context) -> bool:
	return is_include_discards(context) and _read_flag(context, "infiniteDiscards", false)

static func is_include_bosses(context) -> bool:
	return _read_flag(context, "includeBosses", true)

static func is_boss_only(context) -> bool:
	return is_include_bosses(context) and _read_flag(context, "bossOnly", false)

static func is_include_rewards(context) -> bool:
	return _read_flag(context, "includeRewards", true)

static func is_include_boons(context) -> bool:
	return _read_flag(context, "includeBoons", true)

static func is_include_consumables(context) -> bool:
	return _read_flag(context, "includeConsumables", true)

static func is_include_upgrades(context) -> bool:
	return _read_flag(context, "includeUpgrades", true)

static func is_include_abilities(context) -> bool:
	return _read_flag(context, "includeAbilities", true)

static func is_include_special_ultravibes(context) -> bool:
	return _read_flag(context, "includeSpecialUltravibes", true)

# Maps a gameplayTag flag key to its current resolved value (mirrors FallingBlockGameFlags.IsFlagEnabled).
const _KNOWN_FLAG_DEFAULTS := {
	"originalOnly": false,
	"includeNegatives": true,
	"negativeOnly": false,
	"maxSpeedOnly": false,
	"includeDiscards": true,
	"infiniteDiscards": false,
	"includeBosses": true,
	"bossOnly": false,
	"includeRewards": true,
	"includeBoons": true,
	"includeConsumables": true,
	"includeUpgrades": true,
	"includeAbilities": true,
	"includeSpecialUltravibes": true,
}

static func is_known_flag_key(key: String) -> bool:
	return _KNOWN_FLAG_DEFAULTS.has(key.strip_edges())

static func is_flag_enabled(context, key: String) -> bool:
	var k := key.strip_edges()
	match k:
		"originalOnly": return is_original_only(context)
		"includeNegatives": return is_include_negatives(context)
		"negativeOnly": return is_negative_only(context)
		"maxSpeedOnly": return is_max_speed_only(context)
		"includeDiscards": return is_include_discards(context)
		"infiniteDiscards": return is_infinite_discards(context)
		"includeBosses": return is_include_bosses(context)
		"bossOnly": return is_boss_only(context)
		"includeRewards": return is_include_rewards(context)
		"includeBoons": return is_include_boons(context)
		"includeConsumables": return is_include_consumables(context)
		"includeUpgrades": return is_include_upgrades(context)
		"includeAbilities": return is_include_abilities(context)
		"includeSpecialUltravibes": return is_include_special_ultravibes(context)
	return bool(_KNOWN_FLAG_DEFAULTS.get(k, false))

## Filters a catalog entry via properties.gameplayTags against the run flags.
## Tag matching a known flag → entry allowed only when that flag is on; "!flag" → only when off.
static func is_catalog_entry_allowed(context, catalog_entry: GnosisNode) -> bool:
	if catalog_entry == null or not catalog_entry.is_valid():
		return true
	var props := catalog_entry.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return true
	var tags := props.get_node("gameplayTags")
	if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST or tags.get_count() == 0:
		return true
	for i in range(tags.get_count()):
		var item := tags.get_node(i)
		if not item.is_valid() or item.get_type() != GnosisValueType.STRING:
			continue
		var tag := str(item.value).strip_edges()
		if tag.is_empty():
			continue
		if tag.begins_with("!"):
			var neg_key := tag.substr(1).strip_edges()
			if is_known_flag_key(neg_key) and is_flag_enabled(context, neg_key):
				return false
			continue
		if is_known_flag_key(tag) and not is_flag_enabled(context, tag):
			return false
	return true
