@tool
extends Control

## Lightweight passive child layer for FallingBlockBoardRenderer. It delegates its
## _draw back to a Callable so the renderer can paint isolated passes (e.g. the
## shadered snow drift) into separate CanvasItems. Keeping snow on its own layer
## lets a ShaderMaterial affect only the snow while preserving the draw order
## (cell background -> snow -> blocks/traits/ghost).

var draw_callback: Callable

func _draw() -> void:
	if draw_callback.is_valid():
		draw_callback.call(self)
