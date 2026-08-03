# Schrift-Quellen

| Datei | Zweck | Herkunft |
|---|---|---|
| `Orbitron-Variable.ttf` | Titel, Buttons, Tab-Reiter | Google Fonts, `ofl/orbitron` |
| `Rajdhani-Regular.ttf` | Reserve | Google Fonts, `ofl/rajdhani` |
| `Rajdhani-Medium.ttf` | Standardschrift des Menue-Themes, Labels, Dropdowns | Google Fonts, `ofl/rajdhani` |
| `Rajdhani-Bold.ttf` | Reserve fuer Hervorhebungen | Google Fonts, `ofl/rajdhani` |

## Warum zwei Schriften

Orbitron ist eine reine Display-Schrift, breit und quadratisch. Als
Fliesstext im Optionsmenue wird sie schnell unleserlich, deshalb liegt sie
nur auf Titel und Buttons. Rajdhani traegt die Zeilen darunter, sie ist
schmal genug fuer lange Zeilen und passt vom Charakter dazu.

Orbitron ist ein **Variable Font**. Das Gewicht wird ueber `FontVariation`
gesetzt (`variation_opentype`, OpenType-Tag `wght` = 2003265652):
Theme 700 fuer Buttons und Reiter, Titel im Titelscreen 900.

## Lizenzen

Beide stehen unter der **SIL Open Font License 1.1**, die Lizenztexte liegen
als `OFL-Orbitron.txt` und `OFL-Rajdhani.txt` daneben.

Die OFL erlaubt Einbetten und kommerzielle Nutzung und verlangt **keine
Nennung im Spiel**. Sie verlangt nur, dass der Lizenztext bei der
Weitergabe der Schriftdatei dabei liegt - genau dafuer sind die beiden
`OFL-*.txt` hier. Beim Export bleiben sie im Projekt und damit im Paket.

Was die OFL verbietet: die Dateien unter dem Namen "Orbitron" bzw.
"Rajdhani" veraendert weiterzugeben, und sie einzeln zu verkaufen.
Beides betrifft das Spiel nicht.
