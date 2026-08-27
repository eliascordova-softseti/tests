class_name GatoBoard
extends Control
## Tablero de gato: guarda el estado de la partida, recibe los clics
## y se dibuja completo por código en _draw() (sin sprites ni assets).

signal move_made(cell: int, player: int)
signal game_finished(winner: int)

const EMPTY := 0
const PLAYER_X := 1
const PLAYER_O := 2

const WIN_LINES := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6],
]

const GRID_COLOR := Color("3a4256")
const X_COLOR := Color("ff6b6b")
const O_COLOR := Color("4dd4c0")
const WIN_COLOR := Color("f7d154")
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.06)

const MARK_ANIM_TIME := 0.18
const WIN_ANIM_TIME := 0.35

var cells: Array[int] = []
var current_player := PLAYER_X
var winner := EMPTY
var win_line: Array = []
var is_over := false

var _mark_progress: Array[float] = []
var _win_progress := 0.0
var _hovered := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	reset()


## Deja el tablero vacío y devuelve el turno a X.
func reset() -> void:
	cells.resize(9)
	cells.fill(EMPTY)
	_mark_progress.resize(9)
	_mark_progress.fill(0.0)
	current_player = PLAYER_X
	winner = EMPTY
	win_line = []
	is_over = false
	_win_progress = 0.0
	_hovered = -1
	queue_redraw()


## Coloca la marca del jugador en turno. Devuelve false si la jugada no es legal.
func place(cell: int) -> bool:
	if is_over or cell < 0 or cell > 8 or cells[cell] != EMPTY:
		return false

	cells[cell] = current_player
	_animate_mark(cell)
	move_made.emit(cell, current_player)

	var line := _winning_line(current_player)
	if not line.is_empty():
		winner = current_player
		win_line = line
		_finish()
	elif not cells.has(EMPTY):
		winner = EMPTY
		_finish()
	else:
		current_player = PLAYER_O if current_player == PLAYER_X else PLAYER_X

	queue_redraw()
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			place(_cell_at(event.position))
			accept_event()
	elif event is InputEventMouseMotion:
		var hovered := _cell_at(event.position)
		if hovered != _hovered:
			_hovered = hovered
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hovered != -1:
		_hovered = -1
		queue_redraw()


# --- Lógica ---------------------------------------------------------------

func _winning_line(player: int) -> Array:
	for line in WIN_LINES:
		if cells[line[0]] == player and cells[line[1]] == player and cells[line[2]] == player:
			return line
	return []


func _finish() -> void:
	is_over = true
	_win_progress = 0.0
	if not win_line.is_empty() and is_inside_tree():
		var tween := create_tween()
		tween.tween_interval(MARK_ANIM_TIME)
		tween.tween_method(_set_win_progress, 0.0, 1.0, WIN_ANIM_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	game_finished.emit(winner)


func _animate_mark(cell: int) -> void:
	_mark_progress[cell] = 0.0
	if not is_inside_tree():
		_mark_progress[cell] = 1.0
		return
	var tween := create_tween()
	tween.tween_method(_set_mark_progress.bind(cell), 0.0, 1.0, MARK_ANIM_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_mark_progress(value: float, cell: int) -> void:
	_mark_progress[cell] = value
	queue_redraw()


func _set_win_progress(value: float) -> void:
	_win_progress = value
	queue_redraw()


# --- Geometría ------------------------------------------------------------

## Cuadrado centrado más grande que cabe en el nodo.
func _board_rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func _cell_size() -> float:
	return _board_rect().size.x / 3.0


func _cell_center(cell: int) -> Vector2:
	var rect := _board_rect()
	var side := _cell_size()
	return rect.position + Vector2(cell % 3 + 0.5, cell / 3 + 0.5) * side


func _cell_at(pos: Vector2) -> int:
	var rect := _board_rect()
	if not rect.has_point(pos):
		return -1
	var side := _cell_size()
	var col := clampi(int((pos.x - rect.position.x) / side), 0, 2)
	var row := clampi(int((pos.y - rect.position.y) / side), 0, 2)
	return row * 3 + col


# --- Dibujo ---------------------------------------------------------------

func _draw() -> void:
	var rect := _board_rect()
	var side := _cell_size()

	if _hovered != -1 and not is_over and cells[_hovered] == EMPTY:
		var origin := rect.position + Vector2(_hovered % 3, _hovered / 3) * side
		draw_rect(Rect2(origin, Vector2(side, side)), HOVER_COLOR)

	_draw_grid(rect, side)

	for i in 9:
		if cells[i] == EMPTY:
			continue
		var progress: float = _mark_progress[i]
		if cells[i] == PLAYER_X:
			_draw_x(_cell_center(i), side * 0.24, progress, side * 0.075)
		else:
			_draw_o(_cell_center(i), side * 0.24, progress, side * 0.075)

	_draw_win_line(side)


func _draw_grid(rect: Rect2, side: float) -> void:
	var width := maxf(3.0, side * 0.03)
	var inset := side * 0.08
	for i in range(1, 3):
		var x := rect.position.x + side * i
		draw_line(Vector2(x, rect.position.y + inset), Vector2(x, rect.end.y - inset), GRID_COLOR, width, true)
		var y := rect.position.y + side * i
		draw_line(Vector2(rect.position.x + inset, y), Vector2(rect.end.x - inset, y), GRID_COLOR, width, true)


## Traza la X con dos líneas: la primera mitad de la animación dibuja un
## diagonal, la segunda mitad el otro.
func _draw_x(center: Vector2, radius: float, progress: float, width: float) -> void:
	var top_left := center + Vector2(-radius, -radius)
	var bottom_right := center + Vector2(radius, radius)
	var top_right := center + Vector2(radius, -radius)
	var bottom_left := center + Vector2(-radius, radius)

	var first := clampf(progress / 0.5, 0.0, 1.0)
	var second := clampf((progress - 0.5) / 0.5, 0.0, 1.0)

	if first > 0.0:
		draw_line(top_left, top_left.lerp(bottom_right, first), X_COLOR, width, true)
	if second > 0.0:
		draw_line(top_right, top_right.lerp(bottom_left, second), X_COLOR, width, true)


## Traza el círculo como un arco que crece desde arriba.
func _draw_o(center: Vector2, radius: float, progress: float, width: float) -> void:
	if progress <= 0.0:
		return
	var start := -PI * 0.5
	draw_arc(center, radius, start, start + TAU * progress, 48, O_COLOR, width, true)


func _draw_win_line(side: float) -> void:
	if win_line.is_empty() or _win_progress <= 0.0:
		return
	var from := _cell_center(win_line[0])
	var to := _cell_center(win_line[2])
	var direction := (to - from).normalized()
	from -= direction * side * 0.2
	to += direction * side * 0.2
	draw_line(from, from.lerp(to, _win_progress), WIN_COLOR, side * 0.05, true)
