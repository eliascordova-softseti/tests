# Gato (tres en raya) — Godot 4

**Jugar: https://eliascordova-softseti.github.io/tests/**

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

## Exportar a web

El preset `Web` de `export_presets.cfg` ya esta configurado. Con las plantillas
de exportacion de Godot instaladas:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

Dos detalles que hacen que funcione en un servidor estatico cualquiera:

- Godot 4 necesita **aislamiento cross-origin** (`SharedArrayBuffer`). Si el
  servidor no manda `Cross-Origin-Opener-Policy` y `Cross-Origin-Embedder-Policy`,
  el juego no arranca. GitHub Pages no las manda.
- Por eso el preset inyecta `coi-serviceworker.js` via `html/head_include`: un
  service worker que agrega esas cabeceras del lado del cliente. Hay que copiar
  ese archivo junto al export.

Probado en Chromium con viewport de movil y eventos tactiles, con y sin cabeceras
del servidor: en ambos casos el juego carga y responde a los taps.

### Publicacion automatica

`.github/workflows/deploy-web.yml` exporta y publica en GitHub Pages en cada push.
Corre las pruebas antes de exportar, y cachea Godot para no bajar ~900 MB de
plantillas en cada corrida.

Pages ya quedo habilitado con `Source: GitHub Actions`; el primer deploy se
autoconfiguro solo.

Ojo con el peso: el export son ~35 MB, casi todo `index.wasm` (el runtime de
Godot). El juego en si son 48 KB. Es la primera carga; despues queda cacheado.

## Pruebas

```bash
godot --headless --path . --script res://tests/test_board.gd
```

Verifica victorias por fila y diagonal, empate, rechazo de jugadas ilegales y
alternancia de turnos. Sale con código 0 si todo pasa.
