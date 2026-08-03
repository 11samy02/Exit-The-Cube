<p align="center">
  <img src="Assets/Logos/logo.svg" width="130" alt="Samy Abuaisheh">
</p>

<h1 align="center">EXIT THE CUBE</h1>

<p align="center">
  <b>Find the key. Reach the elevator. Don't get cut.</b><br>
  A first- and third-person maze runner where the walls are generated, the saws think,
  and every cube that died before you is still on the floor.
</p>

<p align="center">
  <img alt="Godot 4.7" src="https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white">
  <img alt="GDScript" src="https://img.shields.io/badge/GDScript-100%25-355570">
  <img alt="Levels" src="https://img.shields.io/badge/levels-100%20%2B%203%20tutorials-7b2fd6">
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Windows%20%7C%20Linux-2b2b40">
</p>

---

## Play it

Grab the latest build from **[Releases](https://github.com/11samy02/Exit-The-Cube/releases)** —
Windows (`.exe`) and Linux (`.x86_64`) are in there. No installer, unzip and run.

The current release is a **demo / pre-release**. It plays start to finish, it is just not done.

---

## What you actually do

You are a cube in a maze you have never seen, because the maze was built the moment you
pressed start. Somewhere in it is a **key**. Somewhere else is an **elevator** that will not
open without it. Between the two are **saw blades** that are not on rails.

Every attempt is timed and every death is counted. Both follow you across the whole campaign,
so a level is never really over — it is just the part of the run you already survived.

- **Die** → the level rebuilds itself around you and you start it again, with the clock still running.
- **Clear it** → the next level unlocks and your best time and lowest death count are written down.
- **Get greedy** → the roof is walkable, if you can get up there.

---

## The saws

A patrolling blade is furniture: you learn it once and it never surprises you again. These
don't patrol. Each one picks a cell it wants to be in, walks the corridors to get there, and
then decides again. There are five ways it can decide:

| Mind | What it does |
|---|---|
| **Hunter** | Runs you down while it can see you, remembers where you went, searches there before giving up |
| **Wanderer** | Picks a spot, walks there, picks another one |
| **Ambusher** | Aims at where you are *going*, so it arrives in the corridor you were about to take |
| **Warden** | Circles whatever you need next — the key first, then the exit. It doesn't chase, it camps |
| **Sweeper** | Always heads for the corner it has left alone the longest. Nowhere stays safe twice |

Because they walk the grid one leg at a time, a blade can never cut a corner through a wall —
and the route item can draw exactly what it is about to do.

---

## The items

Item spheres are scattered through the maze. You carry **one at a time**, and picking up a new
one throws away the old one. Each has a duration and a very short window where it matters.

| Item | Duration | What it does |
|---|---|---|
| **Pfeil** (Arrow) | 10 s | A floating arrow that points at whatever you still need |
| **Echo** | 6 s | The cube calls out; wave fronts run the corridors and draw the shortest way there |
| **Zahnrad** (Gear) | 10 s | Draws the routes of nearby blades — only the ones close enough to walk into |
| **Spirale** (Spiral) | 6 s | Every blade in the level winds down and stops. They still cut. It's now a maze of standing knives |
| **Glas** (Glass) | 8 s | Drops every glass pane into the floor. Shortcuts that are on nobody's map — until they come back up |
| **Herz** (Heart) | 8 s | The next blade you run into is destroyed instead of you, and it stays destroyed |
| **Tempo** (Speed) | 9 s | You run harder while every blade takes it easier |
| **Katze** (Cat) | 6 s | Rainbow rush mode. Faster, blades stop mattering, and the soundtrack changes |

---

## Things you might not notice at first

**The dead stay dead.** Every cube that burst on this level left ink on the walls and floor —
and it survives the reload. Walk through a fresh splatter and your underside picks the colour
up, then puts it back down step by step as footprints. The floor of a level you have fought
with for twenty minutes tells the whole story.

**The roof is real.** A handful of maze walls are glass panes. The Glass item drops them —
but they come back up on their own, and if you are standing in that cell when they do, you
ride one to the top. From up there the walls are a floor and the level can be walked *over*
instead of through. Nothing catches you if you step off, and a pane rising into a roof block
has nowhere to put whatever is standing on it.

**Two views, one button.** Third person to read the level, first person to thread a gap.
Switch any time.

**Every level is a file.** A level is a `MapData` resource: maze shape and size, how open it is,
whether it has a roof, how many saws with which minds, which items may drop, seeds for all of it.
The map scene never changes — only the resource it builds from.

---

## Controls

| | Keyboard | Gamepad |
|---|---|---|
| Move | `W` `A` `S` `D` | Left stick |
| Look | Mouse | Right stick |
| Switch view | `Space` | `Y` |
| Use item | `F` | `X` |
| Pause | `Esc` | `Back` / `Select` |
| Menus: confirm / back | `Enter` / `Esc` | `A` / `B` |
| Menus: switch tab, page levels | `PgUp` / `PgDn` | `LB` / `RB` |

Everything is rebindable in **Options → Controls**. Button prompts detect your pad and switch
glyphs to match — Xbox, PlayStation, Switch and Steam Deck are all recognised, and the Switch
layout has its A/B swap handled properly.

---

## Level select

<p align="center">
  <i>36 / 100 cleared, best time 1:17.66, fewest deaths 1.</i>
</p>

Cleared levels can be replayed on their own from the title screen. The picker shows your best
time and lowest death count per level, the whole campaign as a strip of pips, and it wraps at
both ends. Left/right steps through the deck, down drops to the buttons — the shoulder buttons
jump five levels at a time.

---

## Build it yourself

You need **Godot 4.7** (Forward+ renderer). No C#, no external modules, no build step.

```bash
git clone https://github.com/11samy02/Exit-The-Cube.git
cd Exit-The-Cube
godot -e project.godot     # or just open the folder in the Godot project manager
```

Press <kbd>F5</kbd> to run. The physics engine is set to **Jolt** and the Windows renderer to
**D3D12** in the project settings.

### Layout

```
Assets/      fonts, sounds, models, shaders, input prompt glyphs
Resources/   Maps/ — one .tres per level, plus Campaign.tres (the order)
             Items/ — one .tres per item
Scenes/      Enviroment/ (map, saw, key, elevator), Player/, Items/, Ui/, Audio/
Scripts/     one script per thing, same folders as above
```

The maze, the key, the exit, the saws, the items and the glass panes are each placed by their
own spawner node, in that order, and each one is told what the others already did — so the key
is never next to the exit and an item never lands on your spawn.

---

## Credits

**Game, code and design** — Samy Abuaisheh

Built with the **[Godot Engine](https://godotengine.org)**.

| | |
|---|---|
| Fonts | Orbitron & Rajdhani (Google Fonts, SIL Open Font License 1.1) |
| Input prompts | [Kenney](https://kenney.nl) — *Input Prompts 1.5A*, CC0 |
| Sound | Sound FX Starter Pack Vol. 1, Sonniss GDC Game Audio Bundle |
| Music | Spacewave pack |
| Cube steps | synthesised for this game, no licence needed |

Per-asset provenance and licence notes live next to the assets themselves, in
`Assets/Sounds/SOURCES.md`, `Assets/Fonts/SOURCES.md` and
`Assets/Ui/InputPrompts/SOURCES.md`.

**Known bugs:** nah its not a bug, its actually only me.
