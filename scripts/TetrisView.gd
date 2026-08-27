class_name TetrisView
extends Control
## Dibuja una partida de Tetris con los sprites de `assets/tetris/blocks.png`.
##
## El atlas son dos filas de 32x32: arriba los siete bloques (mismo orden que
## las constantes de TetrisGame, columna = pieza - 1) y abajo sus versiones
## apagadas, que se usan para la sombra de caída.

const ATLAS := preload("res://assets/tetris/blocks.png")
const TILE := 32
const GHOST_ROW := 1

const WELL_COLOR := Color("101624")
const GRID_COLOR := Color("1c2438")
const FRAME_COLOR := Color("6d7793")

var game: TetrisGame:
	set(value):
		game = value
		queue_redraw()

## Si es true dibuja la sombra de dónde va a caer la pieza.
var show_ghost := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Lado en píxeles de una celda con el tamaño actual del nodo.
func cell_side() -> float:
	if game == null:
		return 0.0
	return minf(size.x / game.COLUMNS, size.y / game.ROWS)


## Rectángulo del pozo, centrado y con la proporción 10x20 intacta.
func well_rect() -> Rect2:
	if game == null:
		return Rect2()
	var side := cell_side()
	var well := Vector2(side * game.COLUMNS, side * game.ROWS)
	return Rect2((size - well) * 0.5, well)


func _draw() -> void:
	if game == null:
		return
	var rect := well_rect()
	var side := cell_side()

	draw_rect(rect, WELL_COLOR)
	_draw_grid(rect, side)

	for row in game.ROWS:
		for column in game.COLUMNS:
			var kind := game.cell(column, row)
			if kind != TetrisGame.EMPTY:
				_draw_block(rect, side, column, row, kind, 0)

	if show_ghost and not game.is_over:
		for c in game.ghost_cells():
			_draw_block(rect, side, c.x, c.y, game.piece, GHOST_ROW)

	if not game.is_over:
		for c in game.piece_cells():
			_draw_block(rect, side, c.x, c.y, game.piece, 0)

	draw_rect(rect, FRAME_COLOR, false, maxf(2.0, side * 0.06))


func _draw_grid(rect: Rect2, side: float) -> void:
	for column in range(1, game.COLUMNS):
		var x := rect.position.x + side * column
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), GRID_COLOR, 1.0)
	for row in range(1, game.ROWS):
		var y := rect.position.y + side * row
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), GRID_COLOR, 1.0)


## Las filas por encima del tablero (y < 0) no se dibujan: ahí es donde
## aparecen las piezas antes de entrar al pozo.
func _draw_block(rect: Rect2, side: float, column: int, row: int, kind: int, atlas_row: int) -> void:
	if row < 0:
		return
	var target := Rect2(rect.position + Vector2(column, row) * side, Vector2(side, side))
	draw_texture_rect_region(ATLAS, target, _atlas_region(kind, atlas_row))


static func _atlas_region(kind: int, atlas_row: int) -> Rect2:
	return Rect2(Vector2((kind - 1) * TILE, atlas_row * TILE), Vector2(TILE, TILE))


## Tope del lado de un bloque en la vista previa. Sin él, en un panel alto la
## pieza siguiente saldría más grande que las del tablero.
const PREVIEW_MAX_TILE := 34.0


## Dibuja una pieza suelta (la de "SIGUIENTE") centrada dentro de `area`.
static func draw_preview(canvas: CanvasItem, area: Rect2, kind: int) -> void:
	if kind == TetrisGame.EMPTY:
		return
	var cells: Array = TetrisGame.SHAPES[kind][0]
	var min_cell := Vector2i(4, 4)
	var max_cell := Vector2i(-1, -1)
	for c in cells:
		min_cell = Vector2i(mini(min_cell.x, c.x), mini(min_cell.y, c.y))
		max_cell = Vector2i(maxi(max_cell.x, c.x), maxi(max_cell.y, c.y))
	var span := Vector2(max_cell - min_cell) + Vector2.ONE
	var side: float = minf(minf(area.size.x / span.x, area.size.y / span.y), PREVIEW_MAX_TILE)
	var origin := area.position + (area.size - span * side) * 0.5
	for c in cells:
		var target := Rect2(origin + Vector2(c - min_cell) * side, Vector2(side, side))
		canvas.draw_texture_rect_region(ATLAS, target, _atlas_region(kind, 0))
