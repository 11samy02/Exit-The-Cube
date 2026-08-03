# Sound-Quellen

Alle Effekt-Dateien werden mono und auf 44,1 kHz importiert (`force/mono`,
`force/max_rate` in den `.import`-Dateien), die Loops mit
`edit/loop_mode=2` (Forward). Die beiden Musik-Loops bleiben **stereo**, ein
Bett in Mono kollabiert auf die Bildmitte.

| Datei | Zweck | Herkunft |
|---|---|---|
| `music/OutOfTheOrbit.mp3` | Spielmusik, laeuft durchgehend im `Music`-Autoload | Spacewave-Pack |
| `music/Cat_Item.mp3` | Musik im Katzen-Modus, loest das Bett ab | Spacewave-Pack |
| `ambient_maze_loop.wav` | Ambient-Bett, laeuft am Player | Sound FX Starter Pack Vol. 1, `Environment/Nightmare Loop.wav`, zu Mono gemischt |
| `ambient_dream_loop_alt.wav` | Alternative, heller und weicher | Sound FX Starter Pack Vol. 1, `Environment/Dreamscape Loop.wav` |
| `ambient_cave_loop_alt.wav` | Alternative, feucht-hoehlig | Small Sound Kit, `Ambience/Amb_DungeCave_Generic_01.wav` |
| `step_cube_01..04.wav` | Landung des Wuerfels | erzeugt, siehe unten |
| `step_wood_knock_alt.wav` | Alternative Landung mit echtem Transienten | Sound FX Starter Pack Vol. 1, `Motions and Impacts/Impact Redwood.wav`, auf 0,05-0,27 s getrimmt |
| `Wind Loop.wav` | Saegeblatt-Rauschen, laeuft an jeder Saege | Sound FX Starter Pack Vol. 1, `Environment` (schon vorher im Projekt) |
| `saw_motor_loop.wav` | Motorenlauf, als zweite Ebene unter der Saege gedacht, noch nicht eingebunden | Sonniss GDC 2016 Part 5of6, `SoundHolder - Chainsaw/chainsaw gas big engine idle mono.wav` |

## Warum die Steps erzeugt und nicht ausgewaehlt sind

Ein Wuerfel, der landet, braucht: Attack 0 ms, Decay unter 250 ms, tiefen
Schwerpunkt, hohe Tonalitaet. In der gesamten Bibliothek gibt es keinen Sound
mit diesem Profil.

- Die Footsteps aus dem Small Sound Kit sind mit Schwerpunkt 3971 Hz und
  55 % Energie ueber 2 kHz Breitbandrauschen, also hoerbar eine Schuhsohle.
- Die SCI-FI-Impacts messen spektral ideal (`Impact_1`: 368 Hz, 88 % unter
  250 Hz), haben aber **880 ms Attack**. Sie schwellen an, statt zu schlagen.
  Bei 2,8 Hops pro Sekunde unbrauchbar.

Die vier `step_cube_*` sind daher synthetisch: Sinus mit kurzem Tonhoehenabfall
(220 / 200 / 240 / 210 Hz), exponentiell abfallende Huellkurve, dazu ein sehr
leiser Transient von 4 ms fuer die Definition. Gemessen: Schwerpunkt 181 bis
221 Hz, rund 81 % unter 250 Hz, 0 % ueber 2 kHz, Attack 0 ms, Decay 160 ms.

Erzeugt von `scratchpad/steps.py`, Funktion `cube_step(f0, decay, click_db)`.
Die Grundtoene lagen zuerst bei 152/138/166/145 Hz, das klang zu tief.

## Musik

In `music/` liegen fuenf Tracks aus dem Spacewave-Pack, eingebunden sind
zwei davon. `Arcade`, `NoGravity` und `Stars` liegen als Reserve daneben,
etwa fuer Menue oder Endscreen.

Beide eingebundenen Tracks stehen im Import auf `loop=true`. Ohne das Flag
greift zwar der `finished`-Fallback in `game_music.gd` und startet neu, das
ist am Loop-Punkt aber als Luecke zu hoeren.

Zugewiesen sind sie nicht im Code, sondern als Ressource:
`Scenes/Audio/music.tscn` -> `game_track`, `Resources/Items/rush.tres` ->
`music`. Jedes weitere Item kann ueber `ItemData.music` seinen eigenen Track
mitbringen.

Ein frueherer Versuch, Musik aus den Sonniss-Bundles zusammenzusetzen
(`music_maze_loop.wav`, `music_invincible_loop.wav` aus Bluezone-Pads und
einer Trailer-Sequenz), ist wieder raus. Die Bundles sind reine
SFX-Bibliotheken, ohne fertige Musik traegt daraus nichts als Track.

## Verworfene Ambients

`DRONE Server Room Loop` (Sonniss 2020) loopte zwar perfekt, besteht aber
grossteils aus Luefterrauschen und klingt dadurch nach Wind. Ersetzt durch
`Nightmare Loop`: 60 s lang, Loopnaht 1,0 dB, nur 3 % Energie ueber 2 kHz,
also praktisch kein Zischen.

Die `Drn_*`-Dateien aus `Small Sound Kit/Dark/` klingen dem Namen nach ideal
(`Abandoned_Lab`, `Autonomy`, `Chrom`), faden aber am Ende aus: 44 bis 63 dB
Differenz zwischen den ersten und letzten 500 ms. Als Loop wuerden sie pumpen.

## Lizenzen

- **Sonniss GDC Game Audio Bundle** (Saege): royalty-free, auch kommerziell.
  `License.pdf` und `Readme.txt` liegen im jeweiligen Archiv.
- **Sound FX Starter Pack Vol. 1** (Ambient, Wood-Knock): im Archiv liegt
  `Royalty-Free License (Link).pdf`.
- **Small Sound Kit** (Cave-Ambient): **keine** Lizenzdatei im Archiv. Vor einer
  Veroeffentlichung beim Anbieter pruefen.
- Die `step_cube_*` sind komplett erzeugt und damit lizenzfrei.

## Bearbeitung

`saw_motor_loop.wav` ist ein Benzinmotor im Leerlauf, kein Kreissaegeblatt.
Ueber `pitch_scale` um etwa 1.4 hochgezogen verliert er den Toeff-Charakter.
Wer ein echtes Kreissaegeblatt will: `CT_07_Carpenter_Tool_Small_Circular
Saw_Sawing_XY_(192_24).wav` aus Sonniss GDC 2018 Part 8of8, muss aber von Hand
auf einen Loop-Punkt getrimmt werden (Naht dort 15,4 dB).
