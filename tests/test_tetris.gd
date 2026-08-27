extends SceneTree
## Pruebas de las reglas del Tetris, sin abrir ventana:
## godot --headless --path . --script res://tests/test_tetris.gd

var failures := 0

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)


## Llena una fila entera menos la columna `hole`.
func fill_row(game: TetrisGame, row: int, hole: int) -> void:
	for column in TetrisGame.COLUMNS:
		if column != hole:
			game.grid[row * TetrisGame.COLUMNS + column] = TetrisGame.O


func row_string(game: TetrisGame, row: int) -> String:
	var out := ""
	for column in TetrisGame.COLUMNS:
		out += str(game.cell(column, row))
	return out


func _initialize() -> void:
	var TetrisScript := preload("res://scripts/Tetris.gd")

	# 1. Tablero nuevo: vacío, con pieza y con una siguiente distinta de vacío.
	var game: TetrisGame = TetrisScript.new(1234)
	var occupied := 0
	for i in game.grid:
		if i != TetrisGame.EMPTY:
			occupied += 1
	check(game.grid.size() == TetrisGame.COLUMNS * TetrisGame.ROWS, "grilla de 10x20")
	check(occupied == 0, "tablero nuevo vacío")
	check(game.piece != TetrisGame.EMPTY and game.next_piece != TetrisGame.EMPTY, "hay pieza y siguiente")
	check(game.score == 0 and game.lines == 0 and game.level == 1, "marcador en cero")

	# 2. Todas las rotaciones de todas las piezas tienen 4 celdas dentro de 4x4.
	var shapes_ok := true
	for kind in TetrisGame.SHAPES:
		for rotation_index in 4:
			var cells: Array = TetrisGame.SHAPES[kind][rotation_index]
			if cells.size() != 4:
				shapes_ok = false
			for c in cells:
				if c.x < 0 or c.x > 3 or c.y < 0 or c.y > 3:
					shapes_ok = false
	check(shapes_ok, "las 7 piezas tienen 4 bloques en cada rotación")

	# 3. Los límites laterales frenan la pieza en vez de dejarla salir.
	game = TetrisScript.new(7)
	var moves := 0
	while game.move(-1):
		moves += 1
		check(moves < 20, "mover a la izquierda termina")
	var min_x := 99
	for c in game.piece_cells():
		min_x = mini(min_x, c.x)
	check(min_x == 0, "la pieza frena pegada al borde izquierdo")
	moves = 0
	while game.move(1):
		moves += 1
		check(moves < 20, "mover a la derecha termina")
	var max_x := -1
	for c in game.piece_cells():
		max_x = maxi(max_x, c.x)
	check(max_x == TetrisGame.COLUMNS - 1, "la pieza frena pegada al borde derecho")

	# 4. Girar cuatro veces vuelve a la rotación inicial.
	game = TetrisScript.new(7)
	for i in 4:
		game.rotate(1)
	check(game.piece_rotation == 0, "cuatro giros vuelven al inicio")

	# 5. Soltar la pieza la deja apoyada en el piso y suma puntos.
	game = TetrisScript.new(42)
	var dropped := game.piece
	var distance := game.hard_drop()
	check(distance > 0, "el hard drop recorre distancia")
	check(game.score == distance * TetrisGame.HARD_DROP_POINTS, "el hard drop suma puntos")
	var landed := 0
	for i in game.grid:
		if i != TetrisGame.EMPTY:
			landed += 1
	check(landed == 4, "la pieza fijada ocupa 4 celdas")
	var bottom_row := ""
	for column in TetrisGame.COLUMNS:
		bottom_row += str(game.cell(column, TetrisGame.ROWS - 1))
	check(bottom_row.count(str(dropped)) > 0, "la pieza quedó apoyada en el piso")

	# 6. La sombra cae hasta donde caería la pieza.
	game = TetrisScript.new(9)
	var ghost := game.ghost_cells()
	var ghost_max_y := -1
	for c in ghost:
		ghost_max_y = maxi(ghost_max_y, c.y)
	check(ghost_max_y == TetrisGame.ROWS - 1, "la sombra llega al fondo del pozo vacío")

	# 7. Una fila completa desaparece, suma puntos y baja lo de arriba.
	game = TetrisScript.new(1)
	var last := TetrisGame.ROWS - 1
	fill_row(game, last, 0)
	game.grid[(last - 1) * TetrisGame.COLUMNS + 5] = TetrisGame.T
	game.piece = TetrisGame.I
	game.piece_rotation = 1
	game.piece_position = Vector2i(-2, TetrisGame.ROWS - 4)
	# Los lambdas de GDScript capturan las variables por valor, así que los
	# avisos se juntan en un Array (que sí es una referencia compartida).
	var cleared_events: Array[int] = []
	game.lines_cleared.connect(func(count: int, _total: int) -> void: cleared_events.append(count))
	game.hard_drop()
	check(cleared_events == [1], "la señal lines_cleared avisa 1 línea")
	check(game.lines == 1, "el contador de líneas sube")
	check(game.score >= TetrisGame.LINE_SCORES[1], "la línea suma al menos 100 puntos")
	# La I vertical dejó tres bloques más en la columna 0, que también bajan.
	check(row_string(game, last) == "1000070000", "lo de arriba baja una fila")

	# 8. Cuatro líneas de una vez valen más que cuatro líneas sueltas.
	game = TetrisScript.new(2)
	for row in range(TetrisGame.ROWS - 4, TetrisGame.ROWS):
		fill_row(game, row, 9)
	game.piece = TetrisGame.I
	game.piece_rotation = 1
	game.piece_position = Vector2i(7, 0)
	game.hard_drop()
	check(game.lines == 4, "el tetris hace 4 líneas")
	check(game.score >= TetrisGame.LINE_SCORES[4], "el tetris paga %d puntos" % TetrisGame.LINE_SCORES[4])
	var empty_after := 0
	for i in game.grid:
		if i == TetrisGame.EMPTY:
			empty_after += 1
	check(empty_after == TetrisGame.COLUMNS * TetrisGame.ROWS, "las 4 filas desaparecen enteras")

	# 9. Cada 10 líneas sube el nivel y la caída se acelera.
	game = TetrisScript.new(3)
	var slow := game.fall_interval()
	game.lines = 9
	fill_row(game, TetrisGame.ROWS - 1, 9)
	game.piece = TetrisGame.I
	game.piece_rotation = 1
	game.piece_position = Vector2i(7, 0)
	game.hard_drop()
	check(game.level == 2, "el nivel sube a las 10 líneas")
	check(game.fall_interval() < slow, "el nivel 2 cae más rápido que el 1")

	# 10. Con la pila hasta arriba, la partida termina.
	game = TetrisScript.new(4)
	# Todo lleno menos la columna 0, para que no se limpie ninguna línea.
	for row in range(2, TetrisGame.ROWS):
		fill_row(game, row, 0)
	var over_events: Array[int] = []
	game.game_over.connect(func() -> void: over_events.append(1))
	game.hard_drop()
	check(game.is_over, "la partida termina cuando no entra la pieza")
	check(over_events.size() == 1, "se emite game_over")
	check(game.move(1) == false and game.rotate() == false, "no se juega después del game over")

	# 11. En pausa nada se mueve.
	game = TetrisScript.new(5)
	var before := game.piece_position
	game.toggle_pause()
	game.tick(10.0)
	check(game.is_paused and game.piece_position == before, "en pausa la pieza no cae")
	game.toggle_pause()
	game.tick(game.fall_interval())
	check(game.piece_position.y == before.y + 1, "al despausar vuelve a caer")

	# 12. La bolsa de 7 reparte las 7 piezas antes de repetir ninguna.
	game = TetrisScript.new(6)
	var seen := {game.piece: true, game.next_piece: true}
	for i in 12:
		game.hard_drop()
		seen[game.next_piece] = true
	check(seen.size() == 7, "en 14 piezas salieron las 7 formas")

	# 13. Reiniciar deja todo como al principio.
	game = TetrisScript.new(8)
	game.hard_drop()
	game.hard_drop()
	game.reset()
	occupied = 0
	for i in game.grid:
		if i != TetrisGame.EMPTY:
			occupied += 1
	check(occupied == 0 and game.score == 0 and game.level == 1 and not game.is_over, "reset limpia la partida")

	if failures == 0:
		print("\nTodo OK (tetris)")
	else:
		print("\n%d prueba(s) fallaron (tetris)" % failures)
	quit(1 if failures > 0 else 0)
