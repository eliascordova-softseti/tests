class_name TetrisGame
extends RefCounted
## Reglas del Tetris, sin nada de Godot visual: una grilla de enteros, la pieza
## en juego y el reloj de caída. Se puede instanciar y probar sin abrir ventana.
##
## La grilla guarda 0 para vacío y 1..7 para el color del tetriminó que ocupa la
## celda (mismos índices que PIECES y que las columnas del atlas de sprites).

signal lines_cleared(count: int, total: int)
signal piece_locked()
signal level_changed(level: int)
signal game_over()

const COLUMNS := 10
const ROWS := 20

const EMPTY := 0
const I := 1
const J := 2
const L := 3
const O := 4
const S := 5
const Z := 6
const T := 7

## Las cuatro rotaciones de cada pieza como offsets (columna, fila) respecto de
## su esquina superior izquierda. Están escritas a mano —y no generadas girando
## una matriz— para que coincidan exactamente con la hoja de sprites.
const SHAPES := {
	I: [
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)],
		[Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	],
	J: [
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
	],
	L: [
		[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
	],
	O: [
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
	],
	S: [
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	],
	Z: [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
	],
	T: [
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	],
}

## Puntos por cantidad de líneas hechas de una vez, multiplicados por el nivel.
const LINE_SCORES := [0, 100, 300, 500, 800]
const LINES_PER_LEVEL := 10
const SOFT_DROP_POINTS := 1
const HARD_DROP_POINTS := 2

## Segundos entre caídas automáticas según el nivel (1..15+).
const BASE_FALL_TIME := 0.8
const FALL_TIME_STEP := 0.05
const MIN_FALL_TIME := 0.08

var grid: Array[int] = []
var piece := EMPTY
var next_piece := EMPTY
var piece_position := Vector2i.ZERO
var piece_rotation := 0
var score := 0
var lines := 0
var level := 1
var is_over := false
var is_paused := false

var _fall_timer := 0.0
## Bolsa de 7 piezas barajadas: garantiza que no salgan cinco S seguidas.
var _bag: Array[int] = []
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	reset()


## Deja el tablero vacío y arranca una partida nueva.
func reset() -> void:
	grid.resize(COLUMNS * ROWS)
	grid.fill(EMPTY)
	score = 0
	lines = 0
	level = 1
	is_over = false
	is_paused = false
	_fall_timer = 0.0
	_bag.clear()
	next_piece = _take_from_bag()
	_spawn()


func cell(column: int, row: int) -> int:
	if column < 0 or column >= COLUMNS or row < 0 or row >= ROWS:
		return EMPTY
	return grid[row * COLUMNS + column]


## Celdas que ocupa la pieza en juego, en coordenadas del tablero.
func piece_cells() -> Array[Vector2i]:
	return _cells_of(piece, piece_rotation, piece_position)


## Dónde caería la pieza si se soltara ahora (la "sombra" del tablero).
func ghost_cells() -> Array[Vector2i]:
	var drop := piece_position
	while _fits(piece, piece_rotation, drop + Vector2i(0, 1)):
		drop += Vector2i(0, 1)
	return _cells_of(piece, piece_rotation, drop)


## Avanza el reloj de caída. `delta` en segundos.
func tick(delta: float) -> void:
	if is_over or is_paused:
		return
	_fall_timer += delta
	var interval := fall_interval()
	while _fall_timer >= interval:
		_fall_timer -= interval
		_step_down()
		if is_over:
			return


func fall_interval() -> float:
	return maxf(MIN_FALL_TIME, BASE_FALL_TIME - FALL_TIME_STEP * (level - 1))


## Mueve la pieza en horizontal. Devuelve false si choca.
func move(direction: int) -> bool:
	if is_over or is_paused or direction == 0:
		return false
	var target := piece_position + Vector2i(signi(direction), 0)
	if not _fits(piece, piece_rotation, target):
		return false
	piece_position = target
	return true


## Gira la pieza en sentido horario (+1) o antihorario (-1), probando los
## desplazamientos laterales clásicos si la rotación no entra donde está.
func rotate(direction: int = 1) -> bool:
	if is_over or is_paused:
		return false
	var target := posmod(piece_rotation + signi(direction), 4)
	for kick in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i(2, 0), Vector2i(-2, 0), Vector2i.UP]:
		if _fits(piece, target, piece_position + kick):
			piece_rotation = target
			piece_position += kick
			return true
	return false


## Baja un casillero por decisión del jugador: suma puntos y reinicia el reloj.
func soft_drop() -> bool:
	if is_over or is_paused:
		return false
	_fall_timer = 0.0
	if _fits(piece, piece_rotation, piece_position + Vector2i(0, 1)):
		piece_position += Vector2i(0, 1)
		score += SOFT_DROP_POINTS
		return true
	_lock()
	return false


## Suelta la pieza hasta el fondo de una y la fija.
func hard_drop() -> int:
	if is_over or is_paused:
		return 0
	var distance := 0
	while _fits(piece, piece_rotation, piece_position + Vector2i(0, 1)):
		piece_position += Vector2i(0, 1)
		distance += 1
	score += distance * HARD_DROP_POINTS
	_lock()
	return distance


func toggle_pause() -> void:
	if not is_over:
		is_paused = not is_paused


# --- Interno --------------------------------------------------------------

func _step_down() -> void:
	if _fits(piece, piece_rotation, piece_position + Vector2i(0, 1)):
		piece_position += Vector2i(0, 1)
	else:
		_lock()


## Fija la pieza en la grilla, limpia líneas y saca la siguiente.
func _lock() -> void:
	for c in piece_cells():
		if c.y >= 0 and c.y < ROWS and c.x >= 0 and c.x < COLUMNS:
			grid[c.y * COLUMNS + c.x] = piece
	piece_locked.emit()

	var cleared := _clear_lines()
	if cleared > 0:
		# Jugando no se pueden hacer más de 4 líneas de una, pero un tablero
		# armado a mano (las pruebas) sí puede: se paga como un tetris.
		score += LINE_SCORES[mini(cleared, LINE_SCORES.size() - 1)] * level
		lines += cleared
		var new_level: int = lines / LINES_PER_LEVEL + 1
		if new_level != level:
			level = new_level
			level_changed.emit(level)
		lines_cleared.emit(cleared, lines)

	_spawn()


func _clear_lines() -> int:
	var kept: Array[int] = []
	var cleared := 0
	for row in range(ROWS - 1, -1, -1):
		var full := true
		for column in COLUMNS:
			if grid[row * COLUMNS + column] == EMPTY:
				full = false
				break
		if full:
			cleared += 1
		else:
			for column in COLUMNS:
				kept.append(grid[row * COLUMNS + column])
	if cleared == 0:
		return 0
	# `kept` quedó de abajo hacia arriba: se reescribe la grilla en ese orden y
	# lo que sobra arriba queda vacío.
	grid.fill(EMPTY)
	var row_index := ROWS - 1
	for i in range(0, kept.size(), COLUMNS):
		for column in COLUMNS:
			grid[row_index * COLUMNS + column] = kept[i + column]
		row_index -= 1
	return cleared


func _spawn() -> void:
	piece = next_piece
	next_piece = _take_from_bag()
	piece_rotation = 0
	piece_position = Vector2i(3, 0)
	_fall_timer = 0.0
	if not _fits(piece, piece_rotation, piece_position):
		is_over = true
		game_over.emit()


func _take_from_bag() -> int:
	if _bag.is_empty():
		_bag = [I, J, L, O, S, Z, T]
		for i in range(_bag.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp := _bag[i]
			_bag[i] = _bag[j]
			_bag[j] = tmp
	return _bag.pop_back()


func _cells_of(kind: int, rotation_index: int, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if kind == EMPTY:
		return result
	for offset in SHAPES[kind][rotation_index]:
		result.append(origin + offset)
	return result


func _fits(kind: int, rotation_index: int, origin: Vector2i) -> bool:
	for c in _cells_of(kind, rotation_index, origin):
		if c.x < 0 or c.x >= COLUMNS or c.y >= ROWS:
			return false
		if c.y >= 0 and grid[c.y * COLUMNS + c.x] != EMPTY:
			return false
	return true
