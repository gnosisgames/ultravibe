class_name PlayHudUpgradesBar
extends PlayHudIconBar

## Topbar run-upgrades inventory (right zone): read-only icons with hover tooltips
## and an x2/x3 stack-count badge on the bottom-right. Icons sit centered within
## the bar (no floating), and the bag is unbounded so no capacity dots are drawn.

@export var upgrade_icon_size: float = 38.0

const STACK_BADGE_FONT_PATH := "res://assets/fonts/Comic Lemon.otf"

var _badge_font: Font = null

func _ready() -> void:
	show_capacity_dots = false
	slot_size = upgrade_icon_size
	# No upward float: the topbar has nothing above it to overflow into.
	float_offset = 0.0
	_badge_font = load(STACK_BADGE_FONT_PATH) as Font
	super._ready()

## Right-aligned so the upgrades cluster hugs the right edge of the topbar.
func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_END

## Center each icon vertically in the bar instead of bottom-anchoring it.
func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_CENTER

func _inventory_category() -> String:
	return "upgrades"

func _bag() -> GnosisNode:
	return _ephemeral().get_node("upgrades").get_node("run")

func _inventory_list() -> GnosisNode:
	var bag := _bag()
	if not bag.is_valid():
		return GnosisNode.new(null)
	return bag.get_node("list")

## Run upgrades stack, so the owned count becomes the x2/x3 badge.
func _slot_stack_count(details: Dictionary) -> int:
	return int(details.get("count", 1))


func _stack_badge_font() -> Font:
	return _badge_font


func _stack_badge_font_size() -> int:
	return maxi(18, int(round(slot_size * 0.46)))


func _tooltip_prefer_side() -> TooltipPopup.PIVOT_SIDE:
	return TooltipPopup.PIVOT_SIDE.RIGHT
