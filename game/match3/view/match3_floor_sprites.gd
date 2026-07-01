class_name Match3FloorSprites
extends RefCounted

## Resolves enhanced cell-floor textures (Unity floorModifier paint parity).

const ICON_DIR := "res://assets/ui/backgrounds/"

const SPRITE_ID_PATHS := {
	"floorGoldSprite": "%sGold.png" % ICON_DIR,
	"floorSteelSprite": "%sSteel.png" % ICON_DIR,
	"floorLuckySprite": "%sLucky.png" % ICON_DIR,
	"floorBonusPointsSprite": "%sBonusPoints.png" % ICON_DIR,
	"floorBonusMultiSprite": "%sBonusMulti.png" % ICON_DIR,
}

const TYPE_ID_SPRITE_IDS := {
	"Gold": "floorGoldSprite",
	"Steel": "floorSteelSprite",
	"Lucky": "floorLuckySprite",
	"BonusPoints": "floorBonusPointsSprite",
	"BonusMulti": "floorBonusMultiSprite",
}

static var _texture_cache: Dictionary = {}


static func texture_for_floor_type(type_id: String, sprite_id: String = "") -> Texture2D:
	var tid := type_id.strip_edges()
	if tid.is_empty():
		return null
	var resolved_sprite_id := sprite_id.strip_edges()
	if resolved_sprite_id.is_empty():
		resolved_sprite_id = str(TYPE_ID_SPRITE_IDS.get(tid, ""))
	if resolved_sprite_id.is_empty():
		return null
	return texture_for_sprite_id(resolved_sprite_id)


static func texture_for_sprite_id(sprite_id: String) -> Texture2D:
	var sid := sprite_id.strip_edges()
	if sid.is_empty():
		return null
	if _texture_cache.has(sid):
		return _texture_cache[sid]
	var path: String = str(SPRITE_ID_PATHS.get(sid, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		_texture_cache[sid] = null
		return null
	var tex: Texture2D = load(path) as Texture2D
	_texture_cache[sid] = tex
	return tex
