extends Control
## Pantalla del Tetris: teclado, reloj y textos del panel.
## Las reglas viven en Tetris.gd; acá sólo se lee su estado y se reacciona a
## sus señales.

const MENU_SCENE := "res://scenes/Menu.tscn"

## Repetición al mantener izquierda/derecha o bajar: primero una pausa y
## después un paso cada tanto, como en los Tetris de siempre.
const REPEAT_DELAY := 0.17
const REPEAT_INTERVAL := 0.05

@onready var _view: TetrisView = $Margin/Layout/Play/Well
@onready var _preview: Control = $Margin/Layout/Play/Panel/NextBox/Box/Preview
@onready var _score: Label = $Margin/Layout/Play/Panel/ScoreBox/Box/Value
@onready var _level: Label = $Margin/Layout/Play/Panel/LevelBox/Box/Value
@onready var _lines: Label = $Margin/Layout/Play/Panel/LinesBox/Box/Value
@onready var _message: Label = $Margin/Layout/Message
@onready var _touch: HBoxContainer = $Margin/Layout/Touch
@onready var _menu_button: Button = $Margin/Layout/Footer/Menu
@onready var _restart: Button = $Margin/Layout/Footer/Restart

var _game: TetrisGame
## Ayuda de controles: cambia según haya teclado o pantalla táctil.
var _hint := "Flechas: mover y girar · ESPACIO soltar · P pausa · R nueva"
var _repeat_action := ""
var _repeat_timer := 0.0
## Se limpia solo: mensajes como "¡LÍNEA COMPLETADA!" duran un rato y se van.
var _flash_timer := 0.0


func _ready() -> void:
	_game = TetrisGame.new()
	_connect_game()
	_view.game = _game
	_menu_button.pressed.connect(_on_menu_pressed)
	_restart.pressed.connect(_restart_game)
	_setup_touch_controls()
	_refresh()


## En el celular no hay teclado: los botones sólo aparecen si la pantalla es
## táctil, así en escritorio no molestan.
func _setup_touch_controls() -> void:
	_touch.visible = DisplayServer.is_touchscreen_available()
	if not _touch.visible:
		return
	_hint = "Usá los botones de abajo para mover, girar y soltar"
	_touch.get_node("Left").pressed.connect(_apply.bind("left"))
	_touch.get_node("Right").pressed.connect(_apply.bind("right"))
	_touch.get_node("Down").pressed.connect(_apply.bind("down"))
	_touch.get_node("Rotate").pressed.connect(_on_touch_rotate)
	_touch.get_node("Drop").pressed.connect(_on_touch_drop)


func _on_touch_rotate() -> void:
	_game.rotate(1)
	_view.queue_redraw()


func _on_touch_drop() -> void:
	if _game.is_over:
		_restart_game()
	else:
		_game.hard_drop()
		_refresh()


func _connect_game() -> void:
	_game.lines_cleared.connect(_on_lines_cleared)
	_game.piece_locked.connect(_refresh)
	_game.game_over.connect(_on_game_over)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_update_message()

	if _game.is_over or _game.is_paused:
		return

	_process_repeat(delta)
	_game.tick(delta)
	_view.queue_redraw()
	_refresh_counters()


## Mantener una tecla mueve la pieza varias veces; el primer paso ya lo dio
## _unhandled_input, acá sólo se repite.
func _process_repeat(delta: float) -> void:
	if _repeat_action == "":
		return
	if not Input.is_key_pressed(_key_of(_repeat_action)):
		_repeat_action = ""
		return
	_repeat_timer -= delta
	while _repeat_timer <= 0.0:
		_repeat_timer += REPEAT_INTERVAL
		_apply(_repeat_action)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_ESCAPE:
		# El evento se marca antes de cambiar de escena: después este nodo ya
		# está saliendo del árbol y get_viewport() se queja.
		get_viewport().set_input_as_handled()
		_on_menu_pressed()
		return

	match event.keycode:
		KEY_R:
			_restart_game()
		KEY_P:
			_game.toggle_pause()
			_update_message()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _game.is_over:
				_restart_game()
			elif not _game.is_paused:
				_game.hard_drop()
				_refresh()
		KEY_LEFT, KEY_A:
			_start_repeat("left")
		KEY_RIGHT, KEY_D:
			_start_repeat("right")
		KEY_DOWN, KEY_S:
			_start_repeat("down")
		KEY_UP, KEY_W, KEY_X:
			_game.rotate(1)
		KEY_Z:
			_game.rotate(-1)
		_:
			return

	_view.queue_redraw()
	get_viewport().set_input_as_handled()


func _start_repeat(action: String) -> void:
	_apply(action)
	_repeat_action = action
	_repeat_timer = REPEAT_DELAY


func _apply(action: String) -> void:
	match action:
		"left":
			_game.move(-1)
		"right":
			_game.move(1)
		"down":
			_game.soft_drop()
	_view.queue_redraw()


func _key_of(action: String) -> Key:
	match action:
		"left":
			return KEY_LEFT
		"right":
			return KEY_RIGHT
		_:
			return KEY_DOWN


func _restart_game() -> void:
	_game.reset()
	_repeat_action = ""
	_flash_timer = 0.0
	_refresh()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_lines_cleared(count: int, _total: int) -> void:
	_message.text = "¡LÍNEA COMPLETADA!" if count < 4 else "¡TETRIS!"
	_message.modulate = Color("5ad469")
	_flash_timer = 0.9
	_refresh_counters()


func _on_game_over() -> void:
	_repeat_action = ""
	_update_message()


func _refresh() -> void:
	_refresh_counters()
	_update_message()
	_view.queue_redraw()


func _refresh_counters() -> void:
	_score.text = "%06d" % _game.score
	_level.text = "%02d" % _game.level
	_lines.text = "%03d" % _game.lines
	_preview.piece = _game.next_piece


func _update_message() -> void:
	_flash_timer = 0.0
	if _game.is_over:
		_message.text = "¡GAME OVER!  ENTER PARA JUGAR"
		_message.modulate = Color("ff5252")
	elif _game.is_paused:
		_message.text = "¡JUEGO EN PAUSA!  (P)"
		_message.modulate = Color("f7d154")
	else:
		_message.text = _hint
		_message.modulate = Color("8ea0bd")


## Si la ventana pierde el foco (cambiar de pestaña en el navegador), la
## partida se pausa sola en vez de seguir cayendo sin que nadie mire.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _game != null \
			and not _game.is_over and not _game.is_paused:
		_game.toggle_pause()
		_update_message()
