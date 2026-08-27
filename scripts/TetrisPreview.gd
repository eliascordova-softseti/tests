extends Control
## Recuadro "SIGUIENTE": dibuja la próxima pieza centrada, con un margen para
## que no toque el borde del panel.

const PADDING := 10.0

var piece := TetrisGame.EMPTY:
	set(value):
		if piece != value:
			piece = value
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101624"))
	TetrisView.draw_preview(self, Rect2(Vector2.ONE * PADDING, size - Vector2.ONE * PADDING * 2.0), piece)
