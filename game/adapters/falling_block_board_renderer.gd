@tool
class_name FallingBlockBoardRenderer
extends Control

@export var cell_size: int = 24
@export var board_offset: Vector2 = Vector2(32, 32)

## Group used so the gameplay adapter can locate this renderer regardless of
## where it lives in the scene tree (it is centered inside a GameArea container).
const BOARD_RENDERER_GROUP := "falling_block_board"
const SpawnResolver = preload("res://game/services/falling_block_spawn_resolver.gd")
const PlayerRuntime = preload("res://game/services/falling_block_player_runtime.gd")

@export var center_in_rect: bool = true

## When enabled the cell size is derived from this control's rect each draw so
## the board fills the available space (minus [member fit_padding_ratio] on every
## edge) and is centered on both axes. Overrides the fixed [member cell_size].
@export var auto_fit: bool = false
## Fraction of the control's width/height kept as empty margin on each side when
## auto-fitting. 0.04 -> ~4% padding top/bottom/left/right.
@export var fit_padding_ratio: float = 0.04
@export var min_cell_size: int = 4

## Landing projection ("ghost") of the active piece, mirroring the Unity
## FallingBlockBoardRenderer ghost: the current piece's cells are projected to
## where a hard drop would settle and drawn behind the real blocks.
@export var render_ghost: bool = true
@export var render_coop_lane_dividers: bool = true
@export var coop_lane_divider_color := Color(1, 1, 1, 0.18)
@export var coop_lane_divider_width := 2.0
## Per-lane "P1".."P4" captions. Drawn small, BELOW each lane's next-piece preview
## (and below the blocks so falling/settled pieces occlude them). The preview sits
## on top so the upcoming ultravibe reads as the prominent element.
@export var render_coop_lane_labels: bool = true
@export var coop_lane_label_font_size: int = 26
@export var coop_lane_label_padding := Vector2(10.0, 28.0)
## Per-lane next-piece preview (co-op), drawn at the top of each lane so every
## player sees their own upcoming ultravibe. Radius is expressed in grid cells so
## it scales with the fitted board.
@export var render_coop_lane_previews: bool = true
@export var coop_lane_preview_radius_cells: float = 1.15
## Vertical gap between the bottom of the preview and the small player caption.
@export var coop_lane_preview_gap: float = 6.0
@export var ghost_variant_id: String = "ghost"
@export_range(0.0, 1.0) var ghost_alpha: float = 0.25
## Set by the gameplay adapter from the boss-effect runtime so effects such as
## the Skia/Mnemos blackout can hide the landing preview.
var ghost_suppressed: bool = false

## Center-bottom trait readout for the current falling piece. Each entry is a
## dictionary { "name": String, "color": Color, "texture": Texture2D }; the
## gameplay adapter refreshes this each frame from the trait-overlay resolver.
@export var render_trait_overlay: bool = true
## Fixed reserved width of the trait-name column, in grid cells. Every label is
## centered within this constant width (min == max), so short names like "SOFT"
## occupy the same span as long ones and the flanking icons stay pinned in place.
@export var trait_text_columns: float = 4.0
var trait_overlay_entries: Array = []

## Tiled snow drift drawn over the dark cell backgrounds and under blocks/ghost.
## Drifts toward the bottom-right, mirroring the Unity board FX. Rendered on its
## own child layer so the pixelation ShaderMaterial only touches the snow.
@export var render_snow: bool = true
@export_range(0.02, 1.0) var snow_tile_scale: float = 0.4
@export_range(0.0, 1.0) var snow_alpha: float = 0.28
@export var snow_speed: Vector2 = Vector2(3.0, 8.0)
@export_range(1.0, 64.0) var snow_pixel_size: float = 6.0:
	set(val):
		snow_pixel_size = val
		if _snow_layer and _snow_layer.material is ShaderMaterial:
			(_snow_layer.material as ShaderMaterial).set_shader_parameter("pixel_size", val)
var _snow_scroll := Vector2.ZERO

## Vertical gradient glow over the grid background (mirrors the Unity PlayView
## "VerticalGradientAdd" image: top-anchored, full board width, flipped 180 so the
## solid edge hugs the top and fades downward). Drawn additively below the blocks.
## Note: the Unity original was tinted black at ~0.25 alpha (a top shadow); this
## defaults to the theme blue per the desired look -- tweak the exports to taste.
@export var render_board_glow: bool = true
@export var board_glow_color: Color = Color(0.345098, 0.345098, 0.572549)
@export_range(0.0, 1.0) var board_glow_alpha: float = 0.5
## Fraction of the visible board height the glow spans from the top edge downward.
@export_range(0.0, 1.0) var board_glow_height_ratio: float = 0.45
## Flip the source vertically so the solid edge sits at the top (Unity's 180 spin).
@export var board_glow_flip_v: bool = true

## Scanlines overlay drawn over the grid background but under blocks.
@export var render_scanlines: bool = true
@export_range(0.0, 1.0) var scanlines_alpha: float = 0.25

## Level-progress backdrop: the bottom-most layer, sitting behind everything
## (even the BoardBg). It extends [member level_progress_padding] px beyond the
## board on every side so a colored frame shows around the playfield, lerping
## from the empty color (no progress) toward the theme primary / full color as
## the objective fills. Mirrors the old game's progress background.
@export var render_level_progress: bool = true
@export var level_progress_empty_color: Color = Color("aaaaaa")
@export var level_progress_full_color: Color = Color("217cda")
@export var level_progress_padding: float = 12.0
## How quickly the displayed fill eases toward the real progress ratio (per sec).
@export var level_progress_lerp_speed: float = 3.0
## Extra scale added at the peak of the pop when progress advances (0.06 -> +6%).
@export var level_progress_pop_scale: float = 0.06
## How fast the pop relaxes back to rest (higher = snappier).
@export var level_progress_pop_decay: float = 6.0
var _level_progress_display := 0.0
var _level_progress_target := 0.0
var _level_progress_pop := 0.0

## Top circular glow centered horizontally over the top of the grid.
@export var render_top_glow: bool = true
@export var top_glow_color: Color = Color(0.345098, 0.345098, 0.572549)
@export_range(0.0, 1.0) var top_glow_alpha: float = 96.0 / 255.0
@export var top_glow_size: Vector2 = Vector2(608, 608)
@export var top_glow_y_offset: float = 64.0

## Scalloped border centered horizontally over the top of the grid.
@export var render_scalloped_border: bool = true
@export var scalloped_border_color: Color = Color(0.345098, 0.345098, 0.572549)
@export_range(0.0, 1.0) var scalloped_border_alpha: float = 1.0
@export var scalloped_border_size: Vector2 = Vector2(656, 656)
@export var scalloped_border_y_offset: float = 4.0

## Segmented circle centered horizontally over the top of the grid.
@export var render_segmented_circle: bool = true
@export var segmented_circle_color: Color = Color(0.345098, 0.345098, 0.572549)
@export_range(0.0, 1.0) var segmented_circle_alpha: float = 1.0
@export var segmented_circle_size: Vector2 = Vector2(586, 586)
@export var segmented_circle_y_offset: float = 112.0

## Vertical Y-offset added to the round number label relative to the circle center.
@export var round_label_y_offset: float = 32.0
## Horizontal nudge for the round number label to correct optical off-centering.
@export var round_label_x_offset: float = -4.0
## Boss portrait shown in place of the round number during an active encounter.
@export var boss_portrait_size: float = 128.0
## Boss description shown below the portrait during an active encounter.
@export var boss_description_font_size: int = 12
## Gap (px) between the bottom of the boss portrait and the description text.
@export var boss_description_gap: float = 18.0
## Description text box width as a fraction of the board width.
@export_range(0.1, 1.0) var boss_description_width_ratio: float = 0.82

## Next-piece preview circle shown beside the round number / boss image.
@export var render_next_preview: bool = true
## Diameter (px, at baseline cell size) of the preview circle; scaled by deco_scale.
@export var next_preview_size: float = 92.0
## Horizontal position of the preview circle center as a fraction of board width.
@export_range(0.0, 1.0) var next_preview_center_x_ratio: float = 0.20
## Vertical nudge (px) for the preview center relative to the round-center y.
@export var next_preview_y_offset: float = 0.0
## Fraction of the circle radius the previewed piece is allowed to fill.
@export_range(0.1, 1.0) var next_preview_fill_ratio: float = 1.0
## Reference span used to size previewed blocks. Lower = larger blocks (small
## pieces fill more of the circle); the largest piece must still fit this span.
@export var next_preview_max_span: float = 3.0
## Opacity of the preview's black fill (matches BoardBg colour, but translucent).
@export_range(0.0, 1.0) var next_preview_bg_alpha: float = 0.38

## Rotation speeds in degrees per second for the circle layers.
@export var scalloped_border_rotation_speed: float = 10.0
@export var segmented_circle_rotation_speed: float = 15.0

## The decoration sizes/offsets (top glow, circles, round label) are authored
## against this cell size. When auto_fit changes the effective cell size they are
## scaled by effective_cell_size / this baseline so the chrome keeps the same
## proportions relative to the board instead of staying frozen at a fixed size.
const DECORATION_BASELINE_CELL_SIZE := 28.0

## Dampens how much the chrome grows under auto_fit. 1.0 = fully proportional to
## the fitted cell size; lower values keep the circles/glow smaller relative to
## the enlarged board.
@export_range(0.1, 1.0) var decoration_scale_factor: float = 0.62

## Folder holding per-variant block art, named "<spriteId>.png" where
## spriteId follows the "<variantId>Block" convention used by the data files.
const BLOCK_SPRITE_DIR := "res://assets/blocks/"

## Font shared with the animated UI buttons (rounded_square_btn) so the trait
## readout matches the rest of the HUD chrome rather than Godot's default font.
const OVERLAY_FONT := preload("res://assets/fonts/Comic Lemon.otf")
## Co-op lane header tints, indexed by player (matches the play HUD palette).
const COOP_LABEL_COLORS := [
	Color("3f80d6"),
	Color("e85a9a"),
	Color("f0a030"),
	Color("55dd66"),
]
const SNOW_TEXTURE := preload("res://assets/ui/board_fx/snow2.png")
const SNOW_SHADER := preload("res://game/adapters/board_snow.gdshader")
const BoardLayer := preload("res://game/adapters/falling_block_board_layer.gd")
const BOARD_GLOW_TEXTURE := preload("res://addons/com.gnosisgames.gnosisengine/assets/Sprites/VerticalGradientAdd.PNG")
const SCANLINES_TEXTURE := preload("res://assets/ui/scan-lines.png")
const FB := preload("res://game/services/falling_block_ephemeral.gd")
const BOSS_ICON_DIR := "res://assets/icons/bosses/"
## Next-piece preview frame artwork: a thin circle ring with a dotted ring on top,
## both tinted with the theme primary, over a flat black fill (matching BoardBg).
const NEXT_PREVIEW_CIRCLE_TEX := preload("res://assets/ui/hud/circles/circle_outline.png")
const NEXT_PREVIEW_BORDER_TEX := preload("res://assets/ui/hud/circles/circle_dotted.png")

## Legacy white line-clear flash (ported from the Unity board renderer, retuned
## for a more visible scale-pop). Each cleared cell flashes as a white silhouette
## that pops (overshoots) up in scale while fading out, staggered left->right by
## column. Fast and non-blocking.
const LINE_CLEAR_FLASH_SHADER := preload("res://game/adapters/line_clear_flash.gdshader")
## Per-cell animation length (seconds). Short like the original; the staggered
## start (below) is what makes the clear read as a left->right wave.
@export var line_clear_duration: float = 0.16
## Left->right stagger between columns (seconds). The key to the "native" feel:
## each column pops after the previous one rather than the whole line at once.
@export var line_clear_delay_per_cell: float = 0.028
## Scale the silhouette settles to; an overshoot briefly pushes past this for the
## "pop" before easing back down to it as the block fades away.
@export var line_clear_scale_peak: float = 1.35
## Fraction of the duration the silhouette stays fully opaque before it fades.
@export_range(0.0, 0.9) var line_clear_fade_start: float = 0.3

## Hard-drop placement flash (ported from the Unity blockPlacementFlash particle):
## a vertical "slam" streak the width of the piece and the height of the drop,
## flashing white -> variant colour then fading. Additive, non-blocking.
@export var render_placement_flash: bool = true
## Lifetime of the placement flash (seconds). Kept long enough to actually read.
@export var placement_flash_duration: float = 0.5
## Minimum streak height (cells) so soft locks still show a small flash.
@export var placement_flash_min_cells: float = 1.0
## Fraction of the lifetime spent blending from white to the variant colour.
@export_range(0.01, 1.0) var placement_flash_color_blend: float = 0.4
## Overall brightness multiplier for the additive streak.
@export_range(0.0, 2.0) var placement_flash_intensity: float = 0.5
## Safety cap on simultaneous flashes so a burst of locks can never cause lag.
@export var placement_flash_max_active: int = 8

var _grid_state: FallingBlockModels.GridState = null
## Child draw layers (created in _ready). Draw order: parent cell background ->
## glow (additive) -> snow (shaded) -> foreground (blocks/traits/ghost).
var _glow_layer: Control = null
var _scanlines_layer: Control = null
var _board_bg: ColorRect = null
var _progress_bg: ColorRect = null
var _progress_fill: ColorRect = null
var _top_glow: TextureRect = null
var _snow_layer: Control = null
var _fg_layer: Control = null
var _clip_container: Control = null
var _scalloped_border: TextureRect = null
var _segmented_circle: TextureRect = null
var _round_label: Label = null
var _boss_portrait: TextureRect = null
var _boss_description: Label = null
var _next_preview_layer: Control = null
var _next_preview_registry := UltravibeRegistry.new()
var _next_preview_registry_loaded := false
## Active white line-clear flashes; each entry is
## {x:int, y:int, variant:String, age:float, delay:float}.
var _lineclear_layer: Control = null
var _lineclear_fx: Array = []
## Active placement flashes; each entry is
## {center_x:float, bottom_y:int, columns:int, drop:float, variant:String, age:float}.
var _placement_flash_layer: Control = null
var _placement_flash_fx: Array = []
var _last_round_center_is_boss := false
## Layout snapshot computed by the parent _draw, read by the child layers so they
## stay aligned with the cells without recomputing.
var _last_origin := Vector2.ZERO
var _last_vis_height := 0
var _variant_colors := {
	"blue": Color(0.2, 0.5, 1.0),
	"red": Color(1.0, 0.25, 0.25),
	"green": Color(0.2, 0.85, 0.35),
	"orange": Color(1.0, 0.55, 0.1),
	"disabled": Color(0.45, 0.45, 0.45)
}
## Lazy texture cache keyed by lowercased variant id. Missing art is cached as
## null so we only hit the filesystem once per variant.
var _variant_textures := {}
var _boss_textures := {}

func _ready() -> void:
	add_to_group(BOARD_RENDERER_GROUP)
	_next_preview_registry.load_shapes()
	_next_preview_registry_loaded = true
	_build_layers()
	set_process(true)

## Snow draws on its own child layer (with the pixelation shader) and the
## foreground (blocks/traits/ghost) on a second child above it, so the parent
## only paints the cell background. Child order == draw order.
func _build_layers() -> void:
	# Level-progress backdrop: a direct child of the renderer (NOT inside GridClip
	# so its padding ring is not clipped) pushed behind everything via
	# show_behind_parent. Sized/colored each draw from the objective progress.
	_progress_bg = get_node_or_null("ProgressBg") as ColorRect
	if _progress_bg == null:
		_progress_bg = ColorRect.new()
		_progress_bg.name = "ProgressBg"
		_progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_progress_bg.color = level_progress_empty_color
		add_child(_progress_bg)
	_progress_bg.show_behind_parent = true
	move_child(_progress_bg, 0)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_progress_bg.owner = get_tree().edited_scene_root
	# Primary-color fill that rises from the bottom over the gray base, mirroring
	# the old game's bottom-to-top objective fill. Lives inside the backdrop so it
	# inherits its padded rect and the advance scale-pop.
	_progress_fill = _progress_bg.get_node_or_null("ProgressFill") as ColorRect
	if _progress_fill == null:
		_progress_fill = ColorRect.new()
		_progress_fill.name = "ProgressFill"
		_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_progress_fill.color = level_progress_full_color
		_progress_bg.add_child(_progress_fill)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_progress_fill.owner = get_tree().edited_scene_root

	# Clip Container to mask glow and other layers to the exact grid rectangle
	_clip_container = get_node_or_null("GridClip")
	if _clip_container == null:
		_clip_container = Control.new()
		_clip_container.name = "GridClip"
		_clip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip_container.clip_contents = true
		add_child(_clip_container)
	move_child(_clip_container, 1)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_clip_container.owner = get_tree().edited_scene_root

	# Scalloped Border
	_scalloped_border = _resolve_layer("ScallopedBorder", TextureRect) as TextureRect
	if _scalloped_border == null:
		_scalloped_border = TextureRect.new()
		_scalloped_border.name = "ScallopedBorder"
		_scalloped_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scalloped_border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_scalloped_border.stretch_mode = TextureRect.STRETCH_SCALE
		_scalloped_border.texture = preload("res://assets/ui/hud/circles/circle_scalloped.png")
		_scalloped_border.modulate = Color(scalloped_border_color.r, scalloped_border_color.g, scalloped_border_color.b, scalloped_border_alpha)
		_clip_container.add_child(_scalloped_border)
	_clip_container.move_child(_scalloped_border, 0)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_scalloped_border.owner = get_tree().edited_scene_root

	# Segmented Circle
	_segmented_circle = _resolve_layer("SegmentedCircle", TextureRect) as TextureRect
	if _segmented_circle == null:
		_segmented_circle = TextureRect.new()
		_segmented_circle.name = "SegmentedCircle"
		_segmented_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_segmented_circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_segmented_circle.stretch_mode = TextureRect.STRETCH_SCALE
		_segmented_circle.texture = preload("res://assets/ui/hud/circles/circle_segmented.png")
		_segmented_circle.modulate = Color(segmented_circle_color.r, segmented_circle_color.g, segmented_circle_color.b, segmented_circle_alpha)
		_clip_container.add_child(_segmented_circle)
	_clip_container.move_child(_segmented_circle, 1)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_segmented_circle.owner = get_tree().edited_scene_root

	# Round Label
	_round_label = _resolve_layer("RoundLabel", Label) as Label
	if _round_label == null:
		_round_label = Label.new()
		_round_label.name = "RoundLabel"
		_round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_round_label.add_theme_font_override("font", preload("res://assets/fonts/Wimzik.otf"))
		_clip_container.add_child(_round_label)
	_round_label.add_theme_font_size_override("font_size", 128)
	_clip_container.move_child(_round_label, 2)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_round_label.owner = get_tree().edited_scene_root

	# Boss portrait (replaces the round number during an active encounter).
	_boss_portrait = _resolve_layer("BossPortrait", TextureRect) as TextureRect
	if _boss_portrait == null:
		_boss_portrait = TextureRect.new()
		_boss_portrait.name = "BossPortrait"
		_boss_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_boss_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_boss_portrait.visible = false
		_clip_container.add_child(_boss_portrait)
	_clip_container.move_child(_boss_portrait, 3)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_boss_portrait.owner = get_tree().edited_scene_root

	# Boss description (shown below the portrait during an active encounter).
	_boss_description = _resolve_layer("BossDescription", Label) as Label
	if _boss_description == null:
		_boss_description = Label.new()
		_boss_description.name = "BossDescription"
		_boss_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_boss_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_boss_description.custom_minimum_size = Vector2(200, 0)
		_boss_description.add_theme_font_override("font", preload("res://assets/fonts/Comic Lemon.otf"))
		_boss_description.visible = false
		_clip_container.add_child(_boss_description)
	_clip_container.move_child(_boss_description, 4)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_boss_description.owner = get_tree().edited_scene_root

	# Next-piece preview frame (sits on the same level as the round number / boss
	# image and, like them, below the foreground blocks so pieces occlude it).
	_next_preview_layer = _resolve_layer("NextPreviewLayer", BoardLayer) as Control
	if _next_preview_layer == null:
		_next_preview_layer = BoardLayer.new()
		_next_preview_layer.name = "NextPreviewLayer"
		_next_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_next_preview_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_clip_container.add_child(_next_preview_layer)
	_next_preview_layer.draw_callback = _draw_next_preview
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_next_preview_layer.owner = get_tree().edited_scene_root

	# Board Background (solid black behind cell backgrounds and scanlines)
	_board_bg = _resolve_layer("BoardBg", ColorRect) as ColorRect
	if _board_bg == null:
		_board_bg = ColorRect.new()
		_board_bg.name = "BoardBg"
		_board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_board_bg.color = Color(0, 0, 0, 1)
		_clip_container.add_child(_board_bg)
	_board_bg.show_behind_parent = true
	_clip_container.move_child(_board_bg, 0)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_board_bg.owner = get_tree().edited_scene_root

	# Top Glow
	_top_glow = _resolve_layer("TopGlow", TextureRect) as TextureRect
	if _top_glow == null:
		_top_glow = TextureRect.new()
		_top_glow.name = "TopGlow"
		_top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_top_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_top_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_top_glow.texture = preload("res://assets/ui/hud/frames/card_frame_glow.png")
		_top_glow.modulate = Color(top_glow_color.r, top_glow_color.g, top_glow_color.b, top_glow_alpha)
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_top_glow.material = glow_mat
		_clip_container.add_child(_top_glow)
	_clip_container.move_child(_top_glow, 1)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_top_glow.owner = get_tree().edited_scene_root

	# Scanlines
	_scanlines_layer = _resolve_layer("ScanlinesLayer", TextureRect) as TextureRect
	if _scanlines_layer == null:
		_scanlines_layer = TextureRect.new()
		_scanlines_layer.name = "ScanlinesLayer"
		_scanlines_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scanlines_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_scanlines_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_scanlines_layer.stretch_mode = TextureRect.STRETCH_TILE
		_scanlines_layer.texture = SCANLINES_TEXTURE
		_scanlines_layer.modulate = Color(1, 1, 1, scanlines_alpha)
		_clip_container.add_child(_scanlines_layer)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_scanlines_layer.owner = get_tree().edited_scene_root

	# Glow
	_glow_layer = _resolve_layer("BoardGlowLayer", TextureRect) as TextureRect
	if _glow_layer == null:
		_glow_layer = TextureRect.new()
		_glow_layer.name = "BoardGlowLayer"
		_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_glow_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_glow_layer.stretch_mode = TextureRect.STRETCH_SCALE
		_glow_layer.texture = BOARD_GLOW_TEXTURE
		_glow_layer.flip_v = board_glow_flip_v
		_glow_layer.modulate = Color(board_glow_color.r, board_glow_color.g, board_glow_color.b, board_glow_alpha)
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow_layer.material = glow_mat
		_clip_container.add_child(_glow_layer)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_glow_layer.owner = get_tree().edited_scene_root

	# Snow
	_snow_layer = _resolve_layer("SnowLayer", BoardLayer) as Control
	if _snow_layer == null:
		_snow_layer = BoardLayer.new()
		_snow_layer.name = "SnowLayer"
		_snow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_snow_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_snow_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = SNOW_SHADER
		mat.set_shader_parameter("pixel_size", snow_pixel_size)
		_snow_layer.material = mat
		_clip_container.add_child(_snow_layer)
	_snow_layer.draw_callback = _draw_snow_layer
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_snow_layer.owner = get_tree().edited_scene_root

	# Foreground
	_fg_layer = _resolve_layer("ForegroundLayer", BoardLayer) as Control
	if _fg_layer == null:
		_fg_layer = BoardLayer.new()
		_fg_layer.name = "ForegroundLayer"
		_fg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_clip_container.add_child(_fg_layer)
	_fg_layer.draw_callback = _draw_fg_layer
	# Always keep the block/ghost foreground as the top-most clip child so the
	# inline reward slots (a sibling living inside this clip) render behind the
	# falling pieces, mirroring the old game's layering.
	_clip_container.move_child(_fg_layer, _clip_container.get_child_count() - 1)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_fg_layer.owner = get_tree().edited_scene_root

	# Placement flash sits above the blocks too, with additive blending so the
	# white->variant "slam" streak reads as a glow over the board.
	_placement_flash_layer = _resolve_layer("PlacementFlashLayer", BoardLayer) as Control
	if _placement_flash_layer == null:
		_placement_flash_layer = BoardLayer.new()
		_placement_flash_layer.name = "PlacementFlashLayer"
		_placement_flash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_placement_flash_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		var slam_mat := CanvasItemMaterial.new()
		slam_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_placement_flash_layer.material = slam_mat
		_clip_container.add_child(_placement_flash_layer)
	_placement_flash_layer.draw_callback = _draw_placement_flash
	_clip_container.move_child(_placement_flash_layer, _clip_container.get_child_count() - 1)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_placement_flash_layer.owner = get_tree().edited_scene_root

	# Line-clear flash sits ABOVE the blocks (Unity sorted it normalBlocks + 5) so
	# the white silhouettes overlay the cells as they pop. A whitening shader makes
	# any drawn sprite/rect render as a solid-white, alpha-preserving flash.
	_lineclear_layer = _resolve_layer("LineClearFlashLayer", BoardLayer) as Control
	if _lineclear_layer == null:
		_lineclear_layer = BoardLayer.new()
		_lineclear_layer.name = "LineClearFlashLayer"
		_lineclear_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lineclear_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		var flash_mat := ShaderMaterial.new()
		flash_mat.shader = LINE_CLEAR_FLASH_SHADER
		_lineclear_layer.material = flash_mat
		_clip_container.add_child(_lineclear_layer)
	_lineclear_layer.draw_callback = _draw_lineclear_fx
	_clip_container.move_child(_lineclear_layer, _clip_container.get_child_count() - 1)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_lineclear_layer.owner = get_tree().edited_scene_root

func _process(delta: float) -> void:
	if _scalloped_border and render_scalloped_border:
		_scalloped_border.rotation_degrees += scalloped_border_rotation_speed * delta
	if _segmented_circle and render_segmented_circle:
		_segmented_circle.rotation_degrees += segmented_circle_rotation_speed * delta

	var presentation := _get_round_center_presentation()
	var is_boss := bool(presentation.is_boss)
	if is_boss != _last_round_center_is_boss:
		_last_round_center_is_boss = is_boss
		queue_redraw()

	# Keep the next-piece preview live as the spawn queue advances.
	if _next_preview_layer and render_next_preview:
		_next_preview_layer.queue_redraw()

	_advance_line_clear_fx(delta)
	_advance_placement_flash(delta)

	if render_level_progress:
		var target_ratio := _get_level_progress_ratio()
		# Advancing toward the next level kicks off a scale-pop on the backdrop.
		if target_ratio > _level_progress_target + 0.0005:
			_level_progress_pop = 1.0
		_level_progress_target = target_ratio
		if not is_equal_approx(_level_progress_display, target_ratio):
			var weight := clampf(level_progress_lerp_speed * delta, 0.0, 1.0)
			_level_progress_display = lerpf(_level_progress_display, target_ratio, weight)
			if absf(_level_progress_display - target_ratio) < 0.001:
				_level_progress_display = target_ratio
			# Drive the fill tint here (not just in _draw) so the color animates
			# every frame the value changes, independent of redraw timing.
			_apply_progress_color()
			queue_redraw()
		if _level_progress_pop > 0.0:
			_level_progress_pop = maxf(0.0, _level_progress_pop - level_progress_pop_decay * delta)
			_apply_progress_pop_scale()
			queue_redraw()

	if not render_snow:
		return
	# Negative scroll drifts the tile field toward the bottom-right of the board.
	_snow_scroll -= snow_speed * delta
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and auto_fit:
		queue_redraw()

## Cell size actually used for drawing. With auto_fit on it scales to the largest
## size that fits both axes (board aspect ratio preserved); otherwise the fixed
## exported cell_size is returned.
func _effective_cell_size() -> int:
	var w := 10
	var h := 20
	if _grid_state:
		w = _grid_state.width
		h = _visible_height()
	if not auto_fit:
		return cell_size
	var avail := size * (1.0 - 2.0 * fit_padding_ratio)
	var by_w := floori(avail.x / float(w))
	var by_h := floori(avail.y / float(h))
	return int(maxi(min_cell_size, mini(by_w, by_h)))

## Multiplier applied to the fixed-pixel decoration sizes/offsets so they track
## the fitted cell size. 1.0 when auto_fit is off (decorations keep authored size).
func _decoration_scale() -> float:
	if not auto_fit:
		return 1.0
	return (float(cell_size) / DECORATION_BASELINE_CELL_SIZE) * decoration_scale_factor

## Rows actually drawn: the playable area only, excluding the hidden spawn rows
## at the top of the grid so the board reads as the classic 20-tall well rather
## than exposing the 4-row spawn buffer.
func _visible_height() -> int:
	if _grid_state == null:
		return 0
	return maxi(1, _grid_state.height - _grid_state.hidden_rows)

## Resolves (and caches) the block sprite for a variant, or null when none ships.
func _texture_for_variant(variant_id: String) -> Texture2D:
	var key := variant_id.to_lower()
	if _variant_textures.has(key):
		return _variant_textures[key]
	var texture: Texture2D = null
	var path := "%s%sBlock.png" % [BLOCK_SPRITE_DIR, variant_id]
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_variant_textures[key] = texture
	return texture

func bind_grid_state(grid_state: FallingBlockModels.GridState) -> void:
	_grid_state = grid_state
	queue_redraw()

## Top-left of the board in local coordinates. When center_in_rect is on, the
## board is centered horizontally within this control and uses board_offset.y
## as a top margin so the main content sits in the middle of the screen.
func get_board_origin() -> Vector2:
	if not center_in_rect:
		return board_offset
	var w := 10
	var h := 20
	if _grid_state:
		w = _grid_state.width
		h = _visible_height()
	var cs := _effective_cell_size()
	var board_width := w * cs
	if auto_fit:
		var board_height := h * cs
		var origin_x := maxf(0.0, (size.x - board_width) * 0.5)
		var origin_y := maxf(0.0, (size.y - board_height) * 0.5)
		return Vector2(origin_x, origin_y)
	var fixed_origin_x := maxf(board_offset.x, (size.x - board_width) * 0.5)
	return Vector2(fixed_origin_x, board_offset.y)

func get_playfield_size() -> Vector2:
	var w := 10
	var h := 20
	if _grid_state:
		w = _grid_state.width
		h = _visible_height()
	var cs := _effective_cell_size()
	return Vector2(w * cs, h * cs)

func get_grid_width() -> int:
	return _grid_state.width if _grid_state else 10

## Number of playable rows (excludes hidden spawn rows). Used by the HUD to drive
## the board container's aspect ratio so co-op widens instead of shrinking to fit.
func get_visible_rows() -> int:
	return _visible_height() if _grid_state else 20

func _draw() -> void:
	var w := 10
	var h := 20
	if _grid_state:
		w = _grid_state.width
		h = _visible_height()
	# Keep the exported cell_size in sync with the fitted value so overlays that
	# read it (e.g. HUD anchoring) stay aligned with what we render.
	cell_size = _effective_cell_size()
	_last_vis_height = h
	_last_origin = get_board_origin()
	# The parent only paints the dark cell background; glow, snow and the
	# foreground (traits/blocks/ghost) live on child layers drawn above it in order.
	_draw_cell_backgrounds(self, _last_origin, _last_vis_height)
	
	var board_width := w * cell_size
	var board_height := h * cell_size
	var deco_scale := _decoration_scale()

	if _clip_container:
		_clip_container.position = _last_origin
		_clip_container.size = Vector2(board_width, board_height)

	if _progress_bg is ColorRect:
		_progress_bg.visible = render_level_progress
		if render_level_progress:
			var pad := level_progress_padding
			_progress_bg.position = _last_origin - Vector2(pad, pad)
			_progress_bg.size = Vector2(board_width + pad * 2.0, board_height + pad * 2.0)
			_apply_progress_color()
			_apply_progress_pop_scale()

	if _scalloped_border is TextureRect:
		_scalloped_border.visible = render_scalloped_border
		_scalloped_border.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var center_x := board_width * 0.5
		var sb_size := scalloped_border_size * deco_scale
		_scalloped_border.size = sb_size
		_scalloped_border.pivot_offset = sb_size * 0.5
		_scalloped_border.position = Vector2(
			center_x - sb_size.x * 0.5,
			scalloped_border_y_offset * deco_scale - sb_size.y * 0.5
		)
		var host := UltraUiFx.resolve_host(self)
		if host and "engine" in host and host.engine:
			var color := _get_theme_color("primary.neon", scalloped_border_color)
			_scalloped_border.modulate = Color(color.r, color.g, color.b, scalloped_border_alpha)
		elif not Engine.is_editor_hint():
			_scalloped_border.modulate = Color(scalloped_border_color.r, scalloped_border_color.g, scalloped_border_color.b, scalloped_border_alpha)

	if _segmented_circle is TextureRect:
		_segmented_circle.visible = render_segmented_circle
		_segmented_circle.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var center_x := board_width * 0.5
		var sc_size := segmented_circle_size * deco_scale
		_segmented_circle.size = sc_size
		_segmented_circle.pivot_offset = sc_size * 0.5
		_segmented_circle.position = Vector2(
			center_x - sc_size.x * 0.5,
			segmented_circle_y_offset * deco_scale - sc_size.y * 0.5
		)
		var host := UltraUiFx.resolve_host(self)
		if host and "engine" in host and host.engine:
			var color := _get_theme_color("primary.neon", segmented_circle_color)
			_segmented_circle.modulate = Color(color.r, color.g, color.b, segmented_circle_alpha)
		elif not Engine.is_editor_hint():
			_segmented_circle.modulate = Color(segmented_circle_color.r, segmented_circle_color.g, segmented_circle_color.b, segmented_circle_alpha)

	if _round_label is Label or _boss_portrait is TextureRect:
		_layout_round_center(board_width, deco_scale)

	if _board_bg is ColorRect:
		_board_bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_board_bg.position = Vector2.ZERO
		_board_bg.size = Vector2(board_width, board_height)

	if _top_glow is TextureRect:
		_top_glow.visible = render_top_glow
		_top_glow.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var center_x := board_width * 0.5
		var tg_size := top_glow_size * deco_scale
		_top_glow.size = tg_size
		_top_glow.position = Vector2(
			center_x - tg_size.x * 0.5,
			top_glow_y_offset * deco_scale - tg_size.y * 0.5
		)
		var host := UltraUiFx.resolve_host(self)
		if host and "engine" in host and host.engine:
			var color := _get_theme_color("primary.neon", top_glow_color)
			_top_glow.modulate = Color(color.r, color.g, color.b, top_glow_alpha)
		elif not Engine.is_editor_hint():
			_top_glow.modulate = Color(top_glow_color.r, top_glow_color.g, top_glow_color.b, top_glow_alpha)

	if _scanlines_layer is TextureRect:
		_scanlines_layer.visible = render_scanlines
		_scanlines_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_scanlines_layer.position = Vector2.ZERO
		_scanlines_layer.size = Vector2(board_width, board_height)
		var host := UltraUiFx.resolve_host(self)
		if host and "engine" in host and host.engine:
			var line_color := _get_theme_color("primary.neon", Color.WHITE)
			_scanlines_layer.modulate = Color(line_color.r, line_color.g, line_color.b, scanlines_alpha)
		elif not Engine.is_editor_hint():
			_scanlines_layer.modulate = Color(1, 1, 1, scanlines_alpha)

	if _glow_layer is TextureRect:
		_glow_layer.visible = render_board_glow
		_glow_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_glow_layer.position = Vector2.ZERO
		_glow_layer.size = Vector2(board_width, board_height * board_glow_height_ratio)
		_glow_layer.flip_v = board_glow_flip_v
		var host := UltraUiFx.resolve_host(self)
		if host and "engine" in host and host.engine:
			var glow_color := _get_theme_color("primary.neon", board_glow_color)
			_glow_layer.modulate = Color(glow_color.r, glow_color.g, glow_color.b, board_glow_alpha)
		elif not Engine.is_editor_hint():
			_glow_layer.modulate = Color(board_glow_color.r, board_glow_color.g, board_glow_color.b, board_glow_alpha)

	if _snow_layer:
		_snow_layer.visible = render_snow
		if render_snow:
			_snow_layer.queue_redraw()
	if _next_preview_layer:
		_next_preview_layer.visible = render_next_preview
		if render_next_preview:
			_next_preview_layer.queue_redraw()
	if _fg_layer:
		_fg_layer.queue_redraw()

func _draw_snow_layer(ci: CanvasItem) -> void:
	var w := 10
	if _grid_state:
		w = _grid_state.width
	if _last_vis_height <= 0:
		return
	var board_size := Vector2(w * cell_size, _last_vis_height * cell_size)
	_draw_tiled_snow_layer(ci, Rect2(_last_origin, board_size), SNOW_TEXTURE, _snow_scroll, snow_alpha)

func _draw_fg_layer(ci: CanvasItem) -> void:
	if _grid_state == null or _grid_state.width <= 0 or _last_vis_height <= 0:
		return
	if render_coop_lane_dividers:
		_draw_coop_lane_dividers(ci, _last_vis_height)
	# Lane headers draw before the blocks so pieces fall in front of them, yet they
	# still sit above the board decorations (round number, glow) on this layer.
	if render_coop_lane_labels:
		_draw_coop_lane_labels(ci)
	# Each lane's upcoming piece, drawn just under its header (also behind blocks).
	if render_coop_lane_previews:
		_draw_coop_lane_previews(ci)
	# Trait overlay sits below blocks so falling/settled pieces occlude it.
	if render_trait_overlay and not trait_overlay_entries.is_empty():
		_draw_trait_overlay(ci, Vector2.ZERO, _last_vis_height)
	_draw_blocks(ci, Vector2.ZERO, _last_vis_height)
	# Ghost only fills empty cells (never real blocks); drawing it last keeps it
	# visible while still reading as "behind" the settled stack and active piece.
	if render_ghost and not ghost_suppressed:
		_draw_ghost(ci, Vector2.ZERO, _last_vis_height)

## Next-piece preview: a black-filled circle (matching BoardBg) framed by a thin
## ring and a dotted ring (both theme-primary), with the upcoming ultravibe drawn
## inside using the real block sprites. Positioned to the right of the round
## number / boss image and, like them, rendered below the foreground blocks.
func _draw_next_preview(ci: CanvasItem) -> void:
	if not render_next_preview:
		return
	if _grid_state == null or _grid_state.width <= 0 or _last_vis_height <= 0:
		return
	# In co-op each lane shows its own preview (drawn under the lane label on the
	# foreground layer), so skip the single centered circle entirely.
	if _read_configured_player_count() >= 2:
		return
	var board_w := float(_grid_state.width) * cell_size
	var deco_scale := _decoration_scale()
	var diameter := next_preview_size * deco_scale
	var radius := diameter * 0.5
	if radius <= 0.0:
		return
	# Keep the whole circle inside the board even when the ratio sits near an edge.
	var center_x := clampf(board_w * next_preview_center_x_ratio, radius, maxf(radius, board_w - radius))
	var center := Vector2(
		center_x,
		(segmented_circle_y_offset + round_label_y_offset + next_preview_y_offset) * deco_scale
	)
	# The black disc + ring + dotted border, then the upcoming piece inside it.
	_draw_preview_disc(ci, center, radius)
	_draw_next_ultravibe(ci, center, radius, _get_next_piece_entry())

## The next-preview backdrop: a translucent black disc (board-background colour
## dimmed via alpha) framed by the theme-primary ring and dotted border. Shared by
## the solo centered preview and every co-op per-lane preview.
func _draw_preview_disc(ci: CanvasItem, center: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	var diameter := radius * 2.0
	ci.draw_circle(center, radius, Color(0, 0, 0, next_preview_bg_alpha))
	var tint := _get_theme_color("primary.neon", segmented_circle_color)
	var box := Rect2(center - Vector2(radius, radius), Vector2(diameter, diameter))
	if NEXT_PREVIEW_CIRCLE_TEX:
		ci.draw_texture_rect(NEXT_PREVIEW_CIRCLE_TEX, box, false, tint)
	if NEXT_PREVIEW_BORDER_TEX:
		ci.draw_texture_rect(NEXT_PREVIEW_BORDER_TEX, box, false, tint)

## Paints a queued piece's blocks centered at [param center], inscribed in a circle
## of [param radius]. Uses a universal cell size (NEXT_PREVIEW_MAX_SPAN) so every
## piece's blocks render at a consistent on-screen size, matching the pause deck.
func _draw_next_ultravibe(ci: CanvasItem, center: Vector2, radius: float, piece: Dictionary) -> void:
	var poly_id := str(piece.get("ultravibe_id", ""))
	var variant_id := str(piece.get("variant_id", ""))
	if poly_id.is_empty() or not _next_preview_registry_loaded:
		return
	var info := _next_preview_registry.get_shape(poly_id)
	if info == null or info.block_offsets.is_empty():
		return
	var min_x := info.block_offsets[0].x
	var min_y := info.block_offsets[0].y
	var max_x := info.block_offsets[0].x
	var max_y := info.block_offsets[0].y
	for off in info.block_offsets:
		min_x = mini(min_x, off.x)
		min_y = mini(min_y, off.y)
		max_x = maxi(max_x, off.x)
		max_y = maxi(max_y, off.y)
	var cols := float(max_x - min_x + 1)
	var rows := float(max_y - min_y + 1)
	# Square inscribed in the circle (side = radius * sqrt(2)), trimmed by the fill
	# ratio so blocks never touch the ring.
	var inner := radius * sqrt(2.0) * next_preview_fill_ratio
	var cell := inner / maxf(1.0, next_preview_max_span)
	if cell <= 0.0:
		return
	var gap := maxf(1.0, cell * 0.06)
	var top_left := center - Vector2(cols, rows) * cell * 0.5
	var texture := _texture_for_variant(variant_id)
	var color: Color = _variant_colors.get(variant_id.to_lower(), Color(0.75, 0.75, 0.85))
	for off in info.block_offsets:
		var pos := top_left + Vector2(float(off.x - min_x), float(off.y - min_y)) * cell
		var rect := Rect2(pos, Vector2(cell - gap, cell - gap))
		if texture != null:
			ci.draw_texture_rect(texture, rect, false)
		else:
			ci.draw_rect(rect, color)

## Head of the next-pieces spawn queue as {ultravibe_id, variant_id}, or empty.
func _draw_coop_lane_dividers(ci: CanvasItem, vis_height: int) -> void:
	var count := _read_configured_player_count()
	if count < 2 or _grid_state == null:
		return
	var dividers := SpawnResolver.lane_divider_columns(_grid_state.width, count)
	if dividers.is_empty():
		return
	var height_px := float(vis_height) * float(cell_size)
	for col in dividers:
		var x := float(col) * float(cell_size)
		ci.draw_line(Vector2(x, 0.0), Vector2(x, height_px), coop_lane_divider_color, coop_lane_divider_width)

## Horizontal center for a lane's preview+caption stack. The first half of
## players (by lane index) hug the left edge of their lane; the rest hug the
## right edge -- 2P: P1 left / P2 right; 3P: P1+P2 left / P3 right;
## 4P: P1+P2 left / P3+P4 right. Returns < 0 if bounds are invalid.
func _coop_lane_stack_center_x(lane: int, count: int, radius: float) -> float:
	var bmin: Array = []
	var bmax: Array = []
	if not PlayerRuntime.try_get_lane_bounds(_grid_state.width, count, lane, bmin, bmax):
		return -1.0
	var lane_left := float(bmin[0]) * float(cell_size)
	var lane_right := float(int(bmax[0]) + 1) * float(cell_size)
	var left_side_count := ceili(float(count) / 2.0)
	if lane < left_side_count:
		return lane_left + coop_lane_label_padding.x + radius
	return lane_right - coop_lane_label_padding.x - radius

## Small per-lane "P1".."P4" caption, drawn centered just below each lane's
## next-piece preview (the preview is the prominent element above it).
func _draw_coop_lane_labels(ci: CanvasItem) -> void:
	var count := _read_configured_player_count()
	if count < 2 or _grid_state == null:
		return
	var font_size := maxi(1, coop_lane_label_font_size)
	var ascent := OVERLAY_FONT.get_ascent(font_size)
	var radius := maxf(1.0, coop_lane_preview_radius_cells * float(cell_size))
	var preview_bottom := coop_lane_label_padding.y + radius * 2.0
	var caption_baseline := preview_bottom + coop_lane_preview_gap + ascent
	for lane in range(count):
		var center_x := _coop_lane_stack_center_x(lane, count, radius)
		if center_x < 0.0:
			continue
		var text := "P%d" % (lane + 1)
		var text_w := OVERLAY_FONT.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x
		var pos := Vector2(center_x - text_w * 0.5, caption_baseline)
		var color: Color = COOP_LABEL_COLORS[lane] if lane < COOP_LABEL_COLORS.size() else Color.WHITE
		ci.draw_string(
			OVERLAY_FONT, pos, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
		)

## Draws each lane's own next-piece preview at the top of the lane, with the small
## "P1".."P4" caption rendered beneath it (see [method _draw_coop_lane_labels]).
func _draw_coop_lane_previews(ci: CanvasItem) -> void:
	var count := _read_configured_player_count()
	if count < 2 or _grid_state == null or not _next_preview_registry_loaded:
		return
	var radius := maxf(1.0, coop_lane_preview_radius_cells * float(cell_size))
	var center_y := coop_lane_label_padding.y + radius
	for lane in range(count):
		var piece := _get_next_piece_entry(PlayerRuntime.build_player_id(lane))
		if piece.is_empty():
			continue
		var center_x := _coop_lane_stack_center_x(lane, count, radius)
		if center_x < 0.0:
			continue
		var center := Vector2(center_x, center_y)
		_draw_preview_disc(ci, center, radius)
		_draw_next_ultravibe(ci, center, radius, piece)

func _read_configured_player_count() -> int:
	var host := UltraUiFx.resolve_host(self)
	if host == null or not ("engine" in host) or host.engine == null:
		return 1
	var eph := host.engine.state.root.get_node("Ephemeral")
	if not eph.is_valid():
		return 1
	var mode := FB.read_string(eph.get_node("mode"), PlayerRuntime.MODE_SOLO)
	var configured := FB.read_int(eph.get_node("playerCount"), 1)
	return PlayerRuntime.resolve_player_count(mode, configured)

func _get_next_piece_entry(player_id: String = PlayerRuntime.PLAYER_ID_PREFIX + "0") -> Dictionary:
	var host := UltraUiFx.resolve_host(self)
	if host == null or not ("engine" in host) or host.engine == null:
		return {}
	var falling_block = host.engine.get_service("FallingBlock")
	if falling_block == null or falling_block.context == null:
		return {}
	# Per-player queues live under nextPiecesQueues.<playerId>; solo reads "P0".
	var queues := FB.get_fb_node(falling_block.context, "nextPiecesQueues")
	if not queues.is_valid() or queues.get_type() != GnosisValueType.OBJECT:
		return {}
	var key := player_id if not player_id.is_empty() else PlayerRuntime.PLAYER_ID_PREFIX + "0"
	var queue := queues.get_node(key)
	if not queue.is_valid() or queue.get_type() != GnosisValueType.LIST or queue.get_count() <= 0:
		return {}
	var entry := queue.get_node(0)
	if not entry.is_valid():
		return {}
	return {
		"ultravibe_id": _next_node_str(entry, "ultravibeId"),
		"variant_id": _next_node_str(entry, "variantId"),
	}

func _next_node_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	if n.is_valid() and n.value != null:
		return str(n.value)
	return ""

## Queues a white flash for each cleared cell. `cells` is an Array of
## {x:int, y:int (visible row), variant:String}. Non-blocking; the flashes
## animate themselves out via _advance_line_clear_fx / _draw_lineclear_fx.
func play_line_clear_flash(cells: Array) -> void:
	if cells.is_empty():
		return
	for cell in cells:
		var x := int(cell.get("x", 0))
		var y := int(cell.get("y", 0))
		_lineclear_fx.append({
			"x": x,
			"y": y,
			"variant": str(cell.get("variant", "")),
			"age": 0.0,
			# Stagger left->right by column, matching the Unity per-cell delay.
			"delay": maxf(0.0, float(x) * line_clear_delay_per_cell),
		})
	if _lineclear_layer:
		_lineclear_layer.queue_redraw()

func _advance_line_clear_fx(delta: float) -> void:
	if _lineclear_fx.is_empty():
		return
	var survivors: Array = []
	for fx in _lineclear_fx:
		fx.age += delta
		# Lifetime = stagger delay + full animation duration.
		if fx.age < fx.delay + line_clear_duration:
			survivors.append(fx)
	_lineclear_fx = survivors
	if _lineclear_layer:
		_lineclear_layer.queue_redraw()

## Draws each active flash as a white silhouette of the cleared block. The scale
## eases across the WHOLE duration with an OutBack overshoot (a visible "pop"
## that briefly punches past the peak then settles), while the alpha holds and
## then fades. The layer's whitening shader renders the sprite as solid white.
func _draw_lineclear_fx(ci: CanvasItem) -> void:
	if _lineclear_fx.is_empty() or _grid_state == null or _last_vis_height <= 0:
		return
	var vis_height := _last_vis_height
	var dur := maxf(0.01, line_clear_duration)
	var fade_start := clampf(line_clear_fade_start, 0.0, 0.95)
	for fx in _lineclear_fx:
		var local: float = float(fx.age) - float(fx.delay)
		if local < 0.0:
			continue
		var t: float = clampf(local / dur, 0.0, 1.0)
		# OutBack overshoot drives the pop: scale punches above the peak early then
		# settles back to it, reading as a snappy "pop" rather than a flat hold.
		var scale := lerpf(1.0, line_clear_scale_peak, _ease_out_back(t))
		var alpha := 1.0
		if t > fade_start:
			var fp: float = (t - fade_start) / (1.0 - fade_start)
			# Ease-in fade so the block stays bright through the pop, then drops off.
			alpha = lerpf(1.0, 0.0, fp * fp)
		var gy: int = int(fx.y)
		if gy < 0 or gy >= vis_height:
			continue
		var cx: float = float(fx.x) * cell_size
		var cy: float = float(vis_height - 1 - gy) * cell_size
		var center := Vector2(cx + cell_size * 0.5, cy + cell_size * 0.5)
		var sized := cell_size * scale
		var rect := Rect2(center - Vector2(sized, sized) * 0.5, Vector2(sized, sized))
		var texture := _texture_for_variant(str(fx.variant))
		# The layer shader forces RGB to white; modulate alpha drives the fade.
		var tint := Color(1.0, 1.0, 1.0, alpha)
		if texture != null:
			ci.draw_texture_rect(texture, rect, false, tint)
		else:
			ci.draw_rect(rect, tint)

## Back-eased ease-out (overshoots above 1.0 then settles), used for the scale pop.
func _ease_out_back(x: float) -> float:
	const C1 := 1.70158
	const C3 := C1 + 1.0
	var xm := x - 1.0
	return 1.0 + C3 * xm * xm * xm + C1 * xm * xm

## Queues a hard-drop placement flash for a piece that just locked. `center_x` is
## the piece's horizontal center (grid columns), `bottom_y` its landing row,
## `columns` its width, `drop` the cells fallen (streak height). Non-blocking.
func play_placement_flash(center_x: float, bottom_y: int, columns: int, drop: float, variant: String) -> void:
	if not render_placement_flash:
		return
	_placement_flash_fx.append({
		"center_x": center_x,
		"bottom_y": bottom_y,
		"columns": maxi(1, columns),
		"drop": maxf(placement_flash_min_cells, drop),
		"variant": variant,
		"age": 0.0,
	})
	# Bound the active set so a rapid string of locks can never pile up work.
	while _placement_flash_fx.size() > maxi(1, placement_flash_max_active):
		_placement_flash_fx.pop_front()
	if _placement_flash_layer:
		_placement_flash_layer.queue_redraw()

func _advance_placement_flash(delta: float) -> void:
	if _placement_flash_fx.is_empty():
		return
	var dur := maxf(0.01, placement_flash_duration)
	var survivors: Array = []
	for fx in _placement_flash_fx:
		fx.age += delta
		if fx.age < dur:
			survivors.append(fx)
	_placement_flash_fx = survivors
	if _placement_flash_layer:
		_placement_flash_layer.queue_redraw()

## Draws each placement flash as a vertical streak spanning the full piece width
## (every column lights up), anchored at the landing row and rising up the fall
## path for the drop distance. A bottom->top alpha gradient makes the impact
## brightest, the colour blends white->variant, and the streak eases out.
func _draw_placement_flash(ci: CanvasItem) -> void:
	if _placement_flash_fx.is_empty() or _grid_state == null or _last_vis_height <= 0:
		return
	var vis_height := _last_vis_height
	var dur := maxf(0.01, placement_flash_duration)
	var blend := clampf(placement_flash_color_blend, 0.01, 1.0)
	for fx in _placement_flash_fx:
		var t: float = clampf(float(fx.age) / dur, 0.0, 1.0)
		# Quick white->variant colour blend, then a soft ease-out fade.
		var color_t: float = clampf(t / blend, 0.0, 1.0)
		var variant_color: Color = _variant_colors.get(str(fx.variant).to_lower(), Color(0.75, 0.85, 1.0))
		var col := Color.WHITE.lerp(variant_color, color_t)
		var fade: float = 1.0 - (t * t)
		var base_alpha: float = fade * placement_flash_intensity
		if base_alpha <= 0.0:
			continue
		var half_w: float = float(fx.columns) * cell_size * 0.5
		var height: float = maxf(1.0, float(fx.drop)) * cell_size
		var center_px: float = (float(fx.center_x) + 0.5) * cell_size
		# Bottom edge of the landing row (y grows downward on screen).
		var bottom_py: float = float(vis_height - int(fx.bottom_y)) * cell_size
		var top_py: float = bottom_py - height
		var points := PackedVector2Array([
			Vector2(center_px - half_w, bottom_py),
			Vector2(center_px + half_w, bottom_py),
			Vector2(center_px + half_w, top_py),
			Vector2(center_px - half_w, top_py),
		])
		var bottom_col := Color(col.r, col.g, col.b, base_alpha)
		var top_col := Color(col.r, col.g, col.b, 0.0)
		ci.draw_polygon(points, PackedColorArray([bottom_col, bottom_col, top_col, top_col]))

func _draw_cell_backgrounds(ci: CanvasItem, origin: Vector2, vis_height: int) -> void:
	var w := 10
	if _grid_state:
		w = _grid_state.width
	var grid_alpha := _get_theme_float("background.grid.alpha", 32.0) / 255.0
	var cell_color := Color(0.12, 0.12, 0.16, grid_alpha)
	for y in range(vis_height):
		for x in range(w):
			var rect := Rect2(
				origin + Vector2(x * cell_size, (vis_height - 1 - y) * cell_size),
				Vector2(cell_size - 1, cell_size - 1)
			)
			ci.draw_rect(rect, cell_color)

func _draw_tiled_snow_layer(ci: CanvasItem, board_rect: Rect2, texture: Texture2D, scroll: Vector2, alpha: float) -> void:
	if texture == null or alpha <= 0.0 or not board_rect.has_area():
		return
	var tex_size := texture.get_size() * snow_tile_scale
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var snow_color := _get_theme_color("primary.neon", Color.WHITE)
	var modulate := Color(snow_color.r, snow_color.g, snow_color.b, 1.0)
	var start_x := board_rect.position.x + fposmod(scroll.x, tex_size.x) - tex_size.x
	var start_y := board_rect.position.y + fposmod(scroll.y, tex_size.y) - tex_size.y
	var y := start_y
	while y < board_rect.end.y:
		var x := start_x
		while x < board_rect.end.x:
			var tile_rect := Rect2(Vector2(x, y), tex_size)
			var clip := tile_rect.intersection(board_rect)
			if clip.has_area():
				var uv_origin := (clip.position - tile_rect.position) / snow_tile_scale
				var uv_size := clip.size / snow_tile_scale
				ci.draw_texture_rect_region(texture, clip, Rect2(uv_origin, uv_size), modulate)
			x += tex_size.x
		y += tex_size.y

func _draw_blocks(ci: CanvasItem, origin: Vector2, vis_height: int) -> void:
	for y in range(vis_height):
		for x in range(_grid_state.width):
			var cell: FallingBlockModels.CellState = _grid_state.cells[y * _grid_state.width + x]
			if cell == null or cell.block_id.is_empty():
				continue
			var rect := Rect2(
				origin + Vector2(x * cell_size, (vis_height - 1 - y) * cell_size),
				Vector2(cell_size - 1, cell_size - 1)
			)
			var texture := _texture_for_variant(cell.variant_id)
			if texture != null:
				# Active (still-falling) cells are brightened slightly so the
				# current piece reads apart from the settled stack.
				var modulate := Color.WHITE if cell.is_locked else Color(1.2, 1.2, 1.2)
				ci.draw_texture_rect(texture, rect, false, modulate)
			else:
				var color: Color = _variant_colors.get(cell.variant_id.to_lower(), Color(0.75, 0.75, 0.85))
				if not cell.is_locked:
					color = color.lightened(0.15)
				ci.draw_rect(rect.grow(-2), color)

## Center-bottom stack of the active piece's traits, drawn between the cell
## background and the blocks so falling/settled pieces occlude it. Each row is an
## icon, the localized trait name (in its tint colour), and a trailing icon --
## the Unity TraitItem layout ([icon] NAME [icon]).
func _draw_trait_overlay(ci: CanvasItem, origin: Vector2, vis_height: int) -> void:
	var font: Font = OVERLAY_FONT if OVERLAY_FONT != null else get_theme_default_font()
	if font == null:
		return
	var board_width_px := _grid_state.width * cell_size
	var board_height_px := vis_height * cell_size
	var center_x := board_width_px * 0.5
	# Small, unobtrusive readout (Unity TraitItem was ~20px icons / 18-28px text on
	# a much larger board): keep it well under a single cell so it whispers rather
	# than shouts, while staying legible.
	var icon_size := maxf(8.0, cell_size * 0.42)
	# Clear breathing room between the centered text column and its flanking icons.
	var gap := maxf(6.0, cell_size * 0.32)
	var font_size := int(maxf(8.0, cell_size * 0.36))
	var row_height := maxf(icon_size, float(font_size)) + gap
	var rows := trait_overlay_entries.size()
	# Reserve a constant text-column width (min == max) so every label is centered
	# in the same span and the leading/trailing icons stay pinned in two fixed
	# vertical columns regardless of name length. Only widen if a label would
	# otherwise overflow the reserved width (e.g. "UNDISCARDABLE").
	var text_col_width := maxf(0.0, cell_size * trait_text_columns)
	var labels: Array[String] = []
	for entry in trait_overlay_entries:
		var label := String(entry.get("name", "")).to_upper()
		labels.append(label)
		text_col_width = maxf(text_col_width, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var row_width := icon_size + gap + text_col_width + gap + icon_size
	var row_left := center_x - row_width * 0.5
	var text_col_left := row_left + icon_size + gap
	var icon2_left := text_col_left + text_col_width + gap
	var total_height := rows * row_height
	# Anchor the stack low on the board (~70% down) so it reads as "center-bottom".
	var center_y := origin.y + board_height_px * 0.7
	var start_y := center_y - total_height * 0.5
	for i in range(rows):
		var entry: Dictionary = trait_overlay_entries[i]
		var color: Color = entry.get("color", Color.WHITE)
		var texture: Texture2D = entry.get("texture", null)
		var row_center_y := start_y + row_height * float(i) + row_height * 0.5
		if texture != null:
			var isz := Vector2(icon_size, icon_size)
			var icon_y := row_center_y - icon_size * 0.5
			ci.draw_texture_rect(texture, Rect2(Vector2(row_left, icon_y), isz), false, color)
			ci.draw_texture_rect(texture, Rect2(Vector2(icon2_left, icon_y), isz), false, color)
		var baseline_y := row_center_y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		ci.draw_string(font, Vector2(text_col_left, baseline_y), labels[i], HORIZONTAL_ALIGNMENT_CENTER, text_col_width, font_size, color)

## Projects each active (unlocked) piece to its hard-drop landing position and
## paints translucent ghost cells there. Mirrors Unity RenderGhostPieces: the
## max downward shift is found by repeatedly testing a one-cell move, allowing
## overlap only with cells of the same active piece.
func _draw_ghost(ci: CanvasItem, origin: Vector2, vis_height: int) -> void:
	# Group the active piece cells by their owning piece instance (co-op may have
	# more than one falling piece at a time).
	var pieces := {}
	for i in range(_grid_state.cells.size()):
		var cell: FallingBlockModels.CellState = _grid_state.cells[i]
		if cell == null or cell.block_id.is_empty() or cell.is_locked:
			continue
		if cell.piece_instance_id.is_empty():
			continue
		var bucket: Array = pieces.get(cell.piece_instance_id, [])
		bucket.append(Vector2i(i % _grid_state.width, i / _grid_state.width))
		pieces[cell.piece_instance_id] = bucket

	var ghost_texture := _texture_for_variant(ghost_variant_id)
	for piece_id in pieces:
		var positions: Array = pieces[piece_id]
		var shift := _ghost_landing_shift(positions, piece_id)
		if shift == 0:
			continue
		for pos in positions:
			var gy: int = pos.y + shift
			if gy < 0 or gy >= vis_height:
				continue
			var target: FallingBlockModels.CellState = _grid_state.cells[gy * _grid_state.width + pos.x]
			# Real blocks always win the cell; only paint the ghost on empties.
			if target != null and not target.block_id.is_empty():
				continue
			var rect := Rect2(
				origin + Vector2(pos.x * cell_size, (vis_height - 1 - gy) * cell_size),
				Vector2(cell_size - 1, cell_size - 1)
			)
			if ghost_texture != null:
				ci.draw_texture_rect(ghost_texture, rect, false, Color(1, 1, 1, ghost_alpha))
			else:
				ci.draw_rect(rect.grow(-2), Color(1, 1, 1, ghost_alpha))

## Largest negative (downward) shift the given active-piece cells can take while
## staying in-bounds and only overlapping their own (unlocked) piece cells.
func _ghost_landing_shift(positions: Array, piece_id: String) -> int:
	var shift := 0
	while true:
		var test_shift := shift - 1
		var can_move := true
		for pos in positions:
			var ty: int = pos.y + test_shift
			if ty < 0 or ty >= _grid_state.height or pos.x < 0 or pos.x >= _grid_state.width:
				can_move = false
				break
			var target: FallingBlockModels.CellState = _grid_state.cells[ty * _grid_state.width + pos.x]
			if target == null or target.block_id.is_empty():
				continue
			# Blocked by anything that is not part of this still-falling piece.
			if target.piece_instance_id != piece_id or target.is_locked:
				can_move = false
				break
		if not can_move:
			break
		shift = test_shift
	return shift

func _localized_boss_description(key: String) -> String:
	if key.strip_edges().is_empty():
		return ""
	var host := UltraUiFx.resolve_host(self)
	if host and "engine" in host and host.engine:
		var localization = host.engine.get_service("Localization")
		if localization:
			return localization.get_string_value(key, "")
	return ""

func _get_theme_color(property_name: String, default_color: Color) -> Color:
	var host := UltraUiFx.resolve_host(self)
	if host and "engine" in host and host.engine:
		var theme_service = host.engine.get_service("Theme")
		if theme_service:
			var hex: String = theme_service.get_theme_property(property_name, "")
			if not hex.is_empty():
				return Color.from_string(hex, default_color)
	return default_color

func _get_theme_float(property_name: String, default_value: float) -> float:
	var host := UltraUiFx.resolve_host(self)
	if host and "engine" in host and host.engine:
		var theme_service = host.engine.get_service("Theme")
		if theme_service:
			return theme_service.get_theme_property_float(property_name, default_value)
	return default_value

func _resolve_layer(node_name: String, type_cls) -> Node:
	# 1. Check if already inside the clip container
	if _clip_container == null:
		return null
	var node = _clip_container.get_node_or_null(node_name)
	if node:
		return node
	# 2. Check if it exists as a direct child of BoardRenderer (old location)
	var old_node = get_node_or_null(node_name)
	if old_node:
		if not is_instance_of(old_node, type_cls):
			old_node.free()
			return null
		else:
			old_node.reparent(_clip_container)
			return old_node
	return null

func _get_current_round() -> int:
	var host := UltraUiFx.resolve_host(self)
	if host and "engine" in host and host.engine:
		var falling_block = host.engine.get_service("FallingBlock")
		if falling_block and falling_block.context:
			return FB.get_fb_int(falling_block.context, "currentRound", 1)
	return 1

func _apply_progress_pop_scale() -> void:
	if _progress_bg == null:
		return
	# Scale from the center so the backdrop breathes symmetrically.
	_progress_bg.pivot_offset = _progress_bg.size * 0.5
	_progress_bg.scale = Vector2.ONE * (1.0 + level_progress_pop_scale * _level_progress_pop)

## Fills the backdrop from the bottom up with the theme primary color over the
## gray base, sized by the lerped display ratio. Called from both _process (so
## the fill animates as lines clear) and _draw (so it stays correct across
## relayouts/theme changes).
func _apply_progress_color() -> void:
	if not (_progress_bg is ColorRect):
		return
	_progress_bg.color = level_progress_empty_color
	if not (_progress_fill is ColorRect):
		return
	var full_color := level_progress_full_color
	var host := UltraUiFx.resolve_host(self)
	if host and "engine" in host and host.engine:
		full_color = _get_theme_color("primary.neon", level_progress_full_color)
	_progress_fill.color = full_color
	# Rise from the bottom edge: height tracks the ratio, anchored to the base bottom.
	var ratio := clampf(_level_progress_display, 0.0, 1.0)
	var total := _progress_bg.size
	var fill_height := total.y * ratio
	_progress_fill.position = Vector2(0.0, total.y - fill_height)
	_progress_fill.size = Vector2(total.x, fill_height)
	_progress_fill.visible = ratio > 0.0

func _get_level_progress_ratio() -> float:
	var host := UltraUiFx.resolve_host(self)
	if host and "engine" in host and host.engine:
		var falling_block = host.engine.get_service("FallingBlock")
		if falling_block and falling_block.context:
			var ctx = falling_block.context
			var progress := float(FB.get_fb_int(ctx, "roundLinesCurrent", 0))
			var target := float(FB.get_fb_int(ctx, "roundLinesNeeded", FallingBlockRoundLines.BASE_LINES_PER_ROUND))
			if target > 0.0:
				return clampf(progress / target, 0.0, 1.0)
	return 0.0

func _get_round_center_presentation() -> Dictionary:
	var is_boss := false
	var sprite_id := ""
	var level_id := ""
	var description_key := ""
	var host := UltraUiFx.resolve_host(self)
	if host and "engine" in host and host.engine:
		var falling_block = host.engine.get_service("FallingBlock")
		if falling_block and falling_block.context:
			var ctx = falling_block.context
			is_boss = FB.get_fb_bool(ctx, "roundIsBossRound", false) or FB.get_fb_bool(ctx, "bossEncounterIsActive", false)
			sprite_id = FB.get_fb_string(ctx, "roundSpriteId", "")
			level_id = FB.get_fb_string(ctx, "bossEncounterLevelId", "")
			description_key = FB.get_fb_string(ctx, "roundDescriptionKey", "")
	return {
		"is_boss": is_boss,
		"boss_sprite_id": sprite_id,
		"boss_level_id": level_id,
		"boss_description_key": description_key,
	}

func _layout_round_center(board_width: float, deco_scale: float) -> void:
	if not render_segmented_circle:
		if _round_label:
			_round_label.visible = false
		if _boss_portrait:
			_boss_portrait.visible = false
		if _boss_description:
			_boss_description.visible = false
		return

	var label_size := Vector2(300, 160) * deco_scale
	var center_x := board_width * 0.5
	var label_pos := Vector2(
		center_x - label_size.x * 0.5 + round_label_x_offset * deco_scale,
		(segmented_circle_y_offset + round_label_y_offset) * deco_scale - label_size.y * 0.5
	)
	var presentation := _get_round_center_presentation()
	var boss_texture := _texture_for_boss(str(presentation.boss_sprite_id), str(presentation.boss_level_id))
	var show_boss: bool = bool(presentation.is_boss) and boss_texture != null

	if _round_label is Label:
		_round_label.visible = not show_boss
		if not show_boss:
			_round_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_round_label.size = label_size
			_round_label.add_theme_font_size_override("font_size", int(128 * deco_scale))
			_round_label.position = label_pos
			_round_label.text = str(_get_current_round())
			var host := UltraUiFx.resolve_host(self)
			if host and "engine" in host and host.engine:
				var color := _get_theme_color("primary.neon", segmented_circle_color)
				_round_label.add_theme_color_override("font_color", color)
			elif not Engine.is_editor_hint():
				_round_label.add_theme_color_override("font_color", segmented_circle_color)

	var portrait_size := Vector2.ONE * boss_portrait_size * deco_scale
	if _boss_portrait is TextureRect:
		_boss_portrait.visible = show_boss
		if show_boss:
			_boss_portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_boss_portrait.size = portrait_size
			_boss_portrait.position = label_pos + label_size * 0.5 - portrait_size * 0.5
			_boss_portrait.texture = boss_texture
			_boss_portrait.modulate = Color.WHITE

	if _boss_description is Label:
		var description := _localized_boss_description(str(presentation.boss_description_key))
		var has_description := show_boss and not description.is_empty()
		_boss_description.visible = has_description
		if has_description:
			var desc_width := board_width * boss_description_width_ratio
			var desc_height := label_size.y
			var center_point := label_pos + label_size * 0.5
			var desc_pos := Vector2(
				center_x - desc_width * 0.5,
				center_point.y + portrait_size.y * 0.5 + boss_description_gap * deco_scale
			)
			_boss_description.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_boss_description.custom_minimum_size = Vector2(desc_width, 0)
			_boss_description.size = Vector2(desc_width, desc_height)
			_boss_description.position = desc_pos
			_boss_description.add_theme_font_size_override("font_size", int(boss_description_font_size * deco_scale))
			_boss_description.text = description
			var desc_color := _get_theme_color("primary.neon", segmented_circle_color)
			_boss_description.add_theme_color_override("font_color", desc_color)

func _texture_for_boss(sprite_id: String, level_id: String) -> Texture2D:
	var candidates: Array[String] = []
	if not sprite_id.is_empty():
		candidates.append(sprite_id)
	if not level_id.is_empty():
		candidates.append(level_id)
		candidates.append(level_id.capitalize())
	for candidate in candidates:
		var key := candidate.to_lower()
		if _boss_textures.has(key):
			return _boss_textures[key]
		var path := "%s%s.png" % [BOSS_ICON_DIR, candidate]
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			_boss_textures[key] = texture
			return texture
	var cache_key := sprite_id if not sprite_id.is_empty() else level_id
	if not cache_key.is_empty():
		_boss_textures[cache_key.to_lower()] = null
	return null
