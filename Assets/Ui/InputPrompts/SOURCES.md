# Controller-Icons

Alles aus **Kenney "Input Prompts" 1.5A** (kenney.nl). Uebernommen ist
jeweils der Ordner `Double` (die 2x-PNGs, 128 px), die Vektor- und
1x-Varianten liegen nur im Originalarchiv.

| Ordner | Original im Archiv | Wird gezeigt bei |
|---|---|---|
| `Keyboard/` | `Keyboard & Mouse/Double` | Tastatur und Maus |
| `Xbox/` | `Xbox Series/Double` | Xbox-Pads **und allen unbekannten Pads** |
| `PlayStation/` | `PlayStation Series/Double` | DualShock, DualSense |
| `Switch/` | `Nintendo Switch/Double` | Switch Pro, Joy-Con |
| `SteamDeck/` | `Steam Deck/Double` | Steam Deck |
| `Generic/` | `Generic/Double` | derzeit nichts, siehe unten |

## Erkennung

`Scripts/Ui/input_icons.gd` liest `Input.get_joy_name()` und sucht darin
nach Stichworten (`dualsense`, `nintendo`, `xbox`, `steam deck`, ...). Die
Liste steht als `DEVICE_KEYWORDS` im Skript, spezifische Eintraege zuerst.

Ein Pad, das in keine Kategorie faellt, bekommt die **Xbox-Glyphen**. Der
`Generic/`-Ordner hat keine A/B/X/Y-Tasten, nur einen namenlosen Knopf -
damit waere ein Prompt weniger wert als gar keiner. Auf dem PC meldet sich
ohnehin fast jedes No-Name-Pad im Xbox-Layout.

## Nintendo-Tastenbelegung

Godot benennt Pad-Tasten nach dem Xbox-Layout: `JOY_BUTTON_A` ist immer die
**untere** Taste. Auf einem Switch-Pad ist die untere Taste aber B. Die
Tabelle `JOY_BUTTONS[Device.SWITCH]` dreht das deshalb um
(A -> `switch_button_b`, B -> `switch_button_a`, X -> `switch_button_y`,
Y -> `switch_button_x`). Wer die Tabelle anfasst: das ist Absicht, kein
Vertipper.

## Lizenz

**CC0 1.0 Universal** (Public Domain), Volltext in `Kenney-License.txt`.

Nutzung privat, im Unterricht und kommerziell erlaubt, **eine Nennung ist
ausdruecklich nicht noetig**. Kenney freut sich darueber, verlangt sie aber
nicht. Damit koennen die Icons ohne weitere Auflagen im veroeffentlichten
Spiel liegen.
