extends SceneTree

var failures := 0

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)

func _initialize() -> void:
	var board: GatoBoard = preload("res://scripts/Board.gd").new()
	root.add_child(board)
	board.size = Vector2(300, 300)
	board.reset()

	# 1. X gana la fila superior
	for cell in [0, 3, 1, 4, 2]:
		board.place(cell)
	check(board.is_over, "partida terminada tras 3 en raya")
	check(board.winner == GatoBoard.PLAYER_X, "gana X")
	check(board.win_line == [0, 1, 2], "linea ganadora 0-1-2")
	check(board.place(5) == false, "no se puede jugar tras terminar")

	# 2. Empate
	board.reset()
	check(not board.is_over and board.current_player == GatoBoard.PLAYER_X, "reset deja turno en X")
	for cell in [0, 4, 8, 2, 6, 3, 5, 7, 1]:
		check(board.place(cell), "jugada legal en %d" % cell)
	check(board.is_over, "partida terminada con tablero lleno")
	check(board.winner == GatoBoard.EMPTY, "empate")

	# 3. Jugadas ilegales y alternancia de turno
	board.reset()
	check(board.place(4), "primera jugada de X")
	check(board.current_player == GatoBoard.PLAYER_O, "el turno pasa a O")
	check(board.place(4) == false, "casilla ocupada rechazada")
	check(board.place(-1) == false and board.place(9) == false, "indice fuera de rango rechazado")
	check(board.current_player == GatoBoard.PLAYER_O, "jugada invalida no cambia el turno")

	# 4. O gana una diagonal
	board.reset()
	for cell in [0, 4, 1, 2, 5, 6]:
		board.place(cell)
	check(board.winner == GatoBoard.PLAYER_O, "gana O en diagonal")
	check(board.win_line == [2, 4, 6], "linea ganadora 2-4-6")

	print("\n%s" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	quit(failures)
