extends SceneTree

## Quick headless check: item-upgrade sprite IDs resolve to emotion block art.

const CatalogSpritePathsScript := preload("res://game/ui/catalog_sprite_paths.gd")

func _init() -> void:
	var cases := {
		"upgradeBlueLevelUpSprite": "fear.png",
		"upgradeRedLevelUpSprite": "anger.png",
		"upgradeGreenLevelUpSprite": "disgust.png",
	}
	for sprite_id in cases:
		var path := CatalogSpritePathsScript.resolve_block_fallback(sprite_id)
		assert(path.ends_with(cases[sprite_id]), "Expected %s for %s, got %s" % [cases[sprite_id], sprite_id, path])
		assert(ResourceLoader.exists(path), "Missing texture: %s" % path)
	print("test_catalog_sprite_paths: OK")
	quit()
