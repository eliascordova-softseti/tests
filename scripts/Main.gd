extends Control
## Pantalla del juego: marcador, mensaje de turno y botón de reinicio.
## Toda la lógica del gato vive en Board.gd; aquí sólo se reacciona a sus señales.

@onready var _board: GatoBoard = $Margin/Layout/Board
@onready var _status: Label = $Margin/Layout/Status
@onready var _score: Label = $Margin/Layout/Footer/Score
@onready var _restart: Button = $Margin/Layout/Footer/Restart

var _wins_x := 0
var _wins_o := 0
var _draws := 0


func _ready() -> void:
	_board.move_made.connect(_on_move_made)
	_board.game_finished.connect(_on_game_finished)
	_restart.pressed.connect(_on_restart_pressed)
	_update_status()
	_update_score()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_on_restart_pressed()
		get_viewport().set_input_as_handled()


func _on_move_made(_cell: int, _player: int) -> void:
	_update_status()


func _on_game_finished(winner: int) -> void:
	match winner:
		GatoBoard.PLAYER_X:
			_wins_x += 1
		GatoBoard.PLAYER_O:
			_wins_o += 1
		_:
			_draws += 1
	_update_status()
	_update_score()


func _on_restart_pressed() -> void:
	_board.reset()
	_update_status()


func _update_status() -> void:
	if not _board.is_over:
		_status.text = "Turno de %s" % _player_name(_board.current_player)
	elif _board.winner == GatoBoard.EMPTY:
		_status.text = "Empate"
	else:
		_status.text = "¡Ganó %s!" % _player_name(_board.winner)


func _update_score() -> void:
	_score.text = "X: %d   ·   O: %d   ·   Empates: %d" % [_wins_x, _wins_o, _draws]


func _player_name(player: int) -> String:
	return "X" if player == GatoBoard.PLAYER_X else "O"
