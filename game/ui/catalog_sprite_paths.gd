class_name CatalogSpritePaths
extends RefCounted

## Shared sprite path resolution for catalog entries (Unity asset-registry parity).

const BLOCK_ICON_DIR := "res://assets/blocks/"

## Item-upgrade level-up grants use colored gem emotion art from assets/blocks/.
const ITEM_UPGRADE_SPRITE_BLOCKS := {
	"upgradeorangelevelupsprite": "joy",
	"upgraderedlevelupsprite": "anger",
	"upgradepurplelevelupsprite": "sadness",
	"upgradebluelevelupsprite": "fear",
	"upgradegreenlevelupsprite": "disgust",
	"upgradepinklevelupsprite": "love",
}


const ITEM_UPGRADE_ID_BLOCKS := {
	"orangelevelup": "joy",
	"redlevelup": "anger",
	"purplelevelup": "sadness",
	"bluelevelup": "fear",
	"greenlevelup": "disgust",
	"pinklevelup": "love",
	"luckyfindboosti": "luckyBlock",
	"luckyfindboostii": "goldBlock",
}


const ITEM_UPGRADE_DIRECT_SPRITES := {
	"upgradeluckyfindboostisprite": "res://assets/blocks/luckyBlock.png",
	"upgradeluckyfindboostiisprite": "res://assets/blocks/goldBlock.png",
}


static func resolve_block_fallback(sprite_id: String) -> String:
	var block_name := str(ITEM_UPGRADE_SPRITE_BLOCKS.get(sprite_id.strip_edges().to_lower(), ""))
	if block_name.is_empty():
		return ""
	var path := "%s%s.png" % [BLOCK_ICON_DIR, block_name]
	return path if ResourceLoader.exists(path) else ""


static func resolve_item_upgrade_icon(sprite_id: String, item_id: String = "") -> String:
	var direct := str(ITEM_UPGRADE_DIRECT_SPRITES.get(sprite_id.strip_edges().to_lower(), ""))
	if not direct.is_empty() and ResourceLoader.exists(direct):
		return direct
	var path := resolve_block_fallback(sprite_id)
	if not path.is_empty():
		return path
	var block_name := str(ITEM_UPGRADE_ID_BLOCKS.get(item_id.strip_edges().to_lower(), ""))
	if block_name.is_empty():
		return ""
	path = "%s%s.png" % [BLOCK_ICON_DIR, block_name]
	return path if ResourceLoader.exists(path) else ""
