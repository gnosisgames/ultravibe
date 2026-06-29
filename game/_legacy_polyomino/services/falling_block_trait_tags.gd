class_name FallingBlockTraitTags
extends RefCounted

## Shared helpers for resolving gameplay traits on locked cells. Cells store a
## snapshot of their variant tags at spawn/conversion time, but callers should
## still fall back to the variant catalog when older cells only carry color tags.

static func tags_include(tag_list: Array, tag_id: String) -> bool:
	if tag_id.strip_edges().is_empty():
		return false
	var key := tag_id.strip_edges().to_lower()
	for tag in tag_list:
		if str(tag).strip_edges().to_lower() == key:
			return true
	return false

static func cell_has_tag(
	cell: FallingBlockModels.CellState,
	tag_id: String,
	variant_tags: Array = []
) -> bool:
	if cell == null or tag_id.strip_edges().is_empty():
		return false
	if tags_include(cell.tags, tag_id):
		return true
	return tags_include(variant_tags, tag_id)
