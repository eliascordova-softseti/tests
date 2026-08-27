# Gato (tres en raya) — Godot 4

Juego de gato para **dos jugadores en local**. El tablero se dibuja por completo
desde código con `_draw()`: no hay sprites ni assets externos, así que el proyecto
funciona apenas se abre.

![tablero](docs/captura.png)

## Requisitos

- Godot **4.x** (probado con 4.2.2 estable). No hace falta nada más.

## Cómo jugar

1. Abrí el proyecto en Godot (`Importar` → elegir `project.godot`).
2. Ejecutá con **F5**.
3. Hacé clic en una casilla para poner tu marca. X siempre empieza.
4. **R** o el botón *Reiniciar* empieza una partida nueva. El marcador acumulado
   (X / O / empates) se conserva entre partidas.

## Estructura

| Archivo | Qué hace |
| --- | --- |
| `project.godot` | Configuración: escena principal, tamaño de ventana, renderer. |
| `scenes/Main.tscn` | Interfaz: mensaje de turno, tablero, marcador y botón. |
| `scripts/Board.gd` | Estado de la partida (`GatoBoard`), detección de ganador, input y dibujado. |
| `scripts/Main.gd` | Conecta las señales del tablero con los textos de la interfaz. |
| `tests/test_board.gd` | Pruebas de la lógica, sin abrir ventana. |

`Board.gd` no sabe nada de la interfaz: expone las señales `move_made(cell, player)`
y `game_finished(winner)`, y el estado en `cells`, `current_player`, `winner`,
`win_line` e `is_over`. Agregar una IA después es escribir algo que llame a
`board.place(cell)` cuando sea el turno de O.

## Pruebas

```bash
godot --headless --path . --script res://tests/test_board.gd
```

Verifica victorias por fila y diagonal, empate, rechazo de jugadas ilegales y
alternancia de turnos. Sale con código 0 si todo pasa.
