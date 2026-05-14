# Red Eclipse — MW2 (2009) MVP fork

This repository is a Red Eclipse checkout that is being repurposed into an
MVP whose gameplay *feels* like Call of Duty: Modern Warfare 2 (2009),
while still running on the unmodified Red Eclipse / Cube 2 / Tesseract
engine. Models, textures, terrain and graphics are explicitly **not** in
scope — only physics, controller feel, weapon handling, and the menu UX
flow are being reskinned.

If a task asks for the "MW2 conversion", "MW2 MVP", "Create-a-Class menu",
"old-CoD movement", or similar, use the **`mw2-mvp` skill** at
`.claude/skills/mw2-mvp/SKILL.md` and the driving prompt at
`.claude/prompts/mw2-mvp.md`. Do not re-derive the conversion plan from
scratch.

## Repo layout (engineer's-eye view)

```
src/
  engine/          # Tesseract engine. Treat as read-only for the MVP.
    physics.cpp    # Engine-side ellipsoid/octree collision. DO NOT EDIT.
    bih.cpp/.h     # BIH for mapmodel collision. DO NOT EDIT.
    mpr.h          # Minkowski Portal Refinement. DO NOT EDIT.
    rendergl.cpp   # FOV plumbing (`curfov`); changes propagate from game.
  game/            # Gameplay code. Editable, but prefer cvars first.
    physics.cpp    # Movement/parkour state machine, ~1.9k LOC.
                   # Parkour gates at impulseaction/impulsemethod (lines ~40).
                   # Impulse multipliers at lines 310-322 and 408-421.
    weapons.cpp    # Hitscan + projectile firing, recoil/spread accumulation.
    weapons.h      # Per-weapon vars (cookzoom*, spread*, recoil*).
    game.h         # gameent definition incl. sprinttime, impulse[IM_*].
    vars.h         # Global gameplay tunables (~800 cvars).
    player.h       # actortype table: maxspeed, health, sprinttime, etc.
    client.cpp     # Network protocol, command bindings.
    server.cpp     # Authoritative simulation + spawn logic.

config/
  defaults.cfg     # Default cvar values, loaded at startup.
  ui/
    lib.cfg        # ui_gameui_prettybutton, panels, helpers.
    game/main.cfg  # Default main menu — replaced by config/ui/mw2/main.cfg.
    game/*.cfg     # Settings, player setup, scoreboard, etc.

data/              # Submodules with maps/textures/models/sounds.
                   # Untouched by the MVP.
```

## Build

```
sudo apt-get install -y libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev \
    libfreetype-dev libopenal-dev libvorbis-dev libogg-dev libpng-dev \
    libjpeg-dev libavif-dev libwebp-dev libtiff-dev zlib1g-dev
cd src && make client -j$(nproc)
```

Output: `bin/<arch>/redeclipse`, runnable via `./redeclipse.sh` from repo
root. Add the `-x"exec config/mw2.cfg"` argument or place an
`autoexec.cfg` in the home dir so the MW2 overrides load on launch.

## What "MW2 feel" means here

1. **No parkour.** Wallrun, climb, vault, dash, slide, kick, pound, grab
   are gated by `impulseaction`/`impulsemethod`. Setting both to 0
   disables them at the cvar level without code changes.
2. **Slower, heavier ground movement.** Lower `actortype` max speed,
   raise air coast (less air control), slightly higher base ground
   friction. Strafe-jump is killed by the air-coast bump.
3. **Sprint stamina.** RE already has `movesprintdecay` and per-actor
   `sprinttime`. Set decay > 0 and `sprinttime` to ~4000 ms.
4. **ADS via existing zoom.** Weapons already cook into a zoom state on
   secondary fire (`W_C_ZOOM`). Wire MW2-style FOV pull-in and
   movement penalty on top of that — no new state machine needed.
5. **Faster TTK.** Bump per-weapon damage ~30–50%, tighten ADS spread,
   keep hipfire spread loose.
6. **MW2-styled menus.** Replace the default `gameui_main` handler with
   `ui_gameui_mw2_main`, which routes to a Create-a-Class panel
   (primary / secondary / lethal / tactical / 3× perks).

## What is explicitly NOT in the MVP

- Killstreaks (UAV, Predator, Harrier, AC‑130) — separate workstream.
- Killcam, theater mode.
- Prestige, XP, unlock progression.
- Prone — RE has no prone state; would need physent height work.
- Aim assist — PC kbd+mouse build.
- Anti-cheat.

If a task asks for any of the above, treat it as scope expansion and
confirm with the user before writing C++.

## Engine invariants to respect

- `physframetime` (5 ms) is sacred — networking depends on it. Don't change.
- All movement modifiers must funnel through `gameent::impulse[IM_*]` or
  the speed-multiplier path in `physics::modifyvelocity` so prediction
  stays consistent between client and server.
- New gameplay vars should use `GFVAR(IDF_GAMEMOD, ...)` so the server
  syncs them; `IDF_PERSIST` is for client-side preferences only.

## Branch & commit hygiene

- Active branch: `claude/unity-physics-port-assessment-g27E0`.
- Commit small, label MW2 changes with `mw2:` prefix.
- Don't open a PR unless explicitly asked.
