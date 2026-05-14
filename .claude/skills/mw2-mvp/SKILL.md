---
name: mw2-mvp
description: |
  Convert the Red Eclipse codebase into an MVP that *feels* like Call of Duty:
  Modern Warfare 2 (2009). Strips parkour, retunes the ground controller,
  enables ADS+sway, gates sprint on stamina, and reskins the in-game menus into
  the MW2 "Main Menu → Multiplayer → Barracks → Create-a-Class" flow.
  Use this skill whenever the user asks for an "MW2 feel", "old-CoD movement",
  "Create-a-Class menu", or "MW2 MVP build" against the Red Eclipse engine.
allowed-tools: Read, Edit, Write, Bash, TodoWrite, Agent
---

# MW2 (2009) MVP on Red Eclipse

## What this skill does

Red Eclipse is a Quake-lineage arena shooter built on Cube 2 / Tesseract.
Its physics core is already close to early-CoD: kinematic ellipsoid player,
fixed 200 Hz tick, networked prediction, hitzones, ragdolls. The parkour
layer on top (wallrun, climb, vault, dash, slide, kick, melee, pound, grab)
is what gives it the "modern" feel. **MW2 is what RE feels like with that
layer disabled and the ground controller slowed down.**

This skill performs that conversion as a *non-invasive overlay*: a single
`config/mw2.cfg` file plus a small CubeScript menu pack. No engine‑side
collision changes. No new C++ subsystems unless explicitly requested.

## Scope (MVP only)

In scope:

- Disable parkour impulses (`impulseaction 0`, `impulsemethod 0`).
- Retune ground movement: lower run speed, MW2-ish strafe/air accel,
  stamina-limited sprint via `movesprintdecay`.
- ADS via the existing `cookzoom` mechanic (secondary fire = zoom), with
  ADS speed penalty, lowered ADS spread, raised hipfire spread.
- FOV defaults to 80 (MW2 console-ish), zoomed FOV per weapon.
- Damage / TTK tuning: faster kills, hitzone multipliers closer to MW2.
- MW2-themed menu pack under `config/ui/mw2/`:
  - Main menu: Multiplayer / Barracks / Options / Quit
  - Barracks → Create-a-Class with 5 class slots
  - Primary / Secondary / Lethal / Tactical / 3× Perks
- An `autoexec.cfg` line that loads `mw2.cfg` so the overrides apply on launch.

Explicitly **out of scope** for the MVP:

- Killstreaks, killcam, prestige, anti-cheat.
- New weapon models, animations, sounds, maps.
- Prone (RE has no prone state; deliberately deferred).
- Dedicated-server matchmaking.
- Aim assist (PC build only).

## Files this skill writes

- `config/mw2.cfg` — all cvar overrides for MW2 feel.
- `config/ui/mw2/main.cfg` — themed main menu.
- `config/ui/mw2/createaclass.cfg` — Create-a-Class screen.
- `config/ui/mw2/perks.cfg` — perk picker (data-only).
- `config/ui/mw2/loadout_data.cfg` — class slot persistence.
- `data/autoexec.cfg` — single line `exec config/mw2.cfg`.

It must **not** rewrite engine source unless the user explicitly asks for
features that cvars cannot reach (prone, killstreaks, etc.).

## Key engine touchpoints

When making changes, prefer cvars in this order:

1. `src/game/vars.h` lists every gameplay var. Look here first.
2. `src/game/physics.cpp` — movement; the `IM_T_*` switch at lines 310–322
   and 408–421 is the parkour modifier list. `impulseaction`/`impulsemethod`
   gate the entire system, no edits needed.
3. `src/game/weapons.h` — per-weapon vars including `cookzoommin/max`,
   `spreadrunning/sprinting/zoom`, `recoil*`, `adstime` (does not exist
   yet — uses `cooktime` for ADS-in time).
4. `src/game/player.h` — `actortype` per-actor speed/health.
5. `config/ui/lib.cfg` — `ui_gameui_prettybutton` etc. for menu UI.

## Tuning targets (MW2 reference)

| Quantity | MW2 reference | RE equivalent var | MVP value |
|---|---|---|---|
| FOV (default) | 65 console / ~80 PC | `firstpersonfov` | 80 |
| FOV (ADS) | weapon-dependent | per-weapon `cookzoommax` | 55–65 |
| Base move speed | ~190 u/s | actor `maxspeed` | 75 (RE units) |
| Sprint multiplier | ~1.4× | `movesprint` | 1.4 |
| Sprint duration | ~4 s | `movesprintdecay` + actor `sprinttime` | decay 1.0, 4000 ms |
| Air control | very low | `moveaircoast` / `movestrafecoast` | raised coast |
| TTK | 0.2–0.5 s | per-weapon `damage` | +30–50% damage |
| Headshot mult | ~1.4× | hitzone head multiplier | 1.4 |
| Mantle | low ledges only | `stairheight` | 8 (down from default) |
| Parkour | none | `impulseaction 0`, `impulsemethod 0` | 0 / 0 |

## How to invoke

The driving prompt lives at `.claude/prompts/mw2-mvp.md`. Read it and
execute its steps in order. The prompt is self-contained and references
this skill for context.

## How to verify

1. Build the client: `cd src && make client -j$(nproc)`.
2. Run: `./redeclipse.sh -gmw2_offline`. (Add an autoexec; map content
   is unchanged.)
3. Expected: main menu reads "MULTIPLAYER / BARRACKS / OPTIONS / QUIT";
   sprint runs out in ~4 s; ADS via right mouse slows movement; no
   wallrun/dash possible regardless of input.

If the build environment lacks SDL2 dev headers, install
`libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libfreetype-dev
libopenal-dev libvorbis-dev libogg-dev libpng-dev libjpeg-dev` first.

## Non-goals reminder

If the user later asks for prone, killstreaks, killcam, or new weapons,
that is a *follow-up*, not part of this skill. Flag the scope expansion
back to the user before writing C++.
