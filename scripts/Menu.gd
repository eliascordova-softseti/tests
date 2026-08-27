extends Control
## Menú de arranque: elige a qué se juega. Cada botón cambia de escena; los
## juegos vuelven acá con su botón "Menú" o con Esc.

const GAMES := {
	"Gato": "res://scenes/Main.tscn",
	"Tetris": "res://scenes/Tetris.tscn",
}

@onready var _gato: Button = $Margin/Layout/Buttons/Gato
@onready var _tetris: Button = $Margin/Layout/Buttons/Tetris


func _ready() -> void:
	_gato.pressed.connect(_open.bind("Gato"))
	_tetris.pressed.connect(_open.bind("Tetris"))
	_gato.grab_focus()


## 1 y 2 abren los juegos sin usar el mouse.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var game := ""
	match event.keycode:
		KEY_1, KEY_KP_1:
			game = "Gato"
		KEY_2, KEY_KP_2:
			game = "Tetris"
		_:
			return
	# Marcar el evento antes de cambiar de escena: después este nodo ya está
	# saliendo del árbol y get_viewport() se queja.
	get_viewport().set_input_as_handled()
	_open(game)


func _open(game: String) -> void:
	get_tree().change_scene_to_file(GAMES[game])
