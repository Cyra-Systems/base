# Prompt: build the MW2 (2009) MVP on Red Eclipse

You are working in this repository to ship the **first playable MVP** of a
Call of Duty: Modern Warfare 2 (2009)–style fork of Red Eclipse. Models,
textures, terrain, audio, and graphics are out of scope. The deliverable
is "boot the game, see an MW2-styled main menu, drop into an offline
match, the controller feels like MW2".

Use the `mw2-mvp` skill (`.claude/skills/mw2-mvp/SKILL.md`) and the repo
guide (`CLAUDE.md`) as your sources of truth. Do not re-plan the
conversion from scratch.

## Constraints

- **Cvars before code.** Every change you can make through `config/mw2.cfg`
  or a UI script, do it there. Do not edit C++ files unless a feature
  cannot be reached from cvars.
- **No engine edits.** `src/engine/**` is off-limits for this MVP.
- **No new gameplay subsystems.** Killstreaks, killcam, prone, prestige,
  anti-cheat — out of scope. If you find yourself reaching for any of
  these, stop and ask the user.
- **Must build.** When you're done, `make client` in `src/` must produce
  a runnable binary. Install build deps if missing.

## Steps

1. **Read** `CLAUDE.md` and `.claude/skills/mw2-mvp/SKILL.md` first.
2. **Create `config/mw2.cfg`** containing all gameplay overrides. The
   skill's tuning-targets table is the canonical list. Include:
   - Parkour off: `impulseaction 0`, `impulsemethod 0`, plus zeroed
     `impulse*meter` costs for safety.
   - Slowed strafe/air control via `movestrafecoast`, `moveaircoast`.
   - Sprint stamina: `movesprintdecay 1`, plus actor `sprinttime` if
     reachable from cvars.
   - FOV: `firstpersonfov 80`, `thirdpersonfov 90`.
   - Hipfire/ADS spread skew (look for `spreadstill`, `spreadzoom`).
   - Damage uplift via the global damage scalar if one exists; otherwise
     leave a TODO comment and move on.
   - Boot the MW2 menu: `gameui_panel_default = gameui_mw2_main_handler`.
3. **Create `config/ui/mw2/main.cfg`** — a faithful-feeling MW2 main menu:
   - Title block (no logo image, just stylised text).
   - Buttons (top-to-bottom): MULTIPLAYER, BARRACKS, OPTIONS, QUIT.
   - MULTIPLAYER → opens the existing `ui_gameui_maps` (offline match).
   - BARRACKS → opens `ui_gameui_mw2_barracks` (next file).
   - OPTIONS → opens `ui_gameui_settings`.
   - QUIT → existing `quit` confirm flow.
   - Re-use `ui_gameui_prettybutton`; do not invent new widgets.
4. **Create `config/ui/mw2/barracks.cfg`** — sub-menu with one button:
   "CREATE A CLASS" → opens `ui_gameui_mw2_createaclass`. Leaves room
   for Challenges/Leaderboards later.
5. **Create `config/ui/mw2/createaclass.cfg`** — five class slots
   (Class 1..5). Selecting a slot opens an edit panel with rows:
   - Primary weapon (dropdown of existing weapon names).
   - Secondary weapon (same list, filtered).
   - Lethal grenade (Frag / Semtex / Throwing Knife — Frag is the only
     one wired in RE; others stub to Frag with a TODO comment).
   - Tactical grenade (Flash / Stun / Smoke — Flash stubs to RE smoke).
   - Perk 1, Perk 2, Perk 3 (pickers from `config/ui/mw2/perks.cfg`).
   Persist selection via CubeScript aliases (`mw2_class_N_primary`, …);
   no protocol changes.
6. **Create `config/ui/mw2/perks.cfg`** — three lists of perks (no
   gameplay effect needed in the MVP, just the UX). Use MW2 names:
   - Slot 1: Marathon, Sleight of Hand, Scavenger, Bling, One Man Army
   - Slot 2: Stopping Power, Lightweight, Hardline, Cold-Blooded, Danger Close
   - Slot 3: Commando, Steady Aim, Scrambler, Ninja, Sit-Rep, Last Stand
7. **Wire load order.** Append `exec "config/mw2.cfg"` to `data/autoexec.cfg`
   if it exists, otherwise create it. Inside `mw2.cfg`, exec the four
   UI files under `config/ui/mw2/`.
8. **Build.**
   ```
   sudo apt-get install -y libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev \
       libfreetype-dev libopenal-dev libvorbis-dev libogg-dev libpng-dev \
       libjpeg-dev libavif-dev libwebp-dev libtiff-dev zlib1g-dev
   cd src && make client -j$(nproc)
   ```
   If the build fails, fix it. Common pitfalls:
   - Missing submodules — the `data/*` submodules are content, not code;
     the client links without them but maps won't load. Note this in
     the final report; do **not** clone submodules to "fix" it.
   - Discord/Steam optional libs — disable via `NO_DISCORD=1 NO_STEAM=1`
     env vars if linker complains.
9. **Smoke-check.** Run `bin/<arch>/redeclipse_server --help` (no display
   needed) to confirm the binary at least loads its symbols. Do not
   attempt to start the GL client headless — no DISPLAY here.
10. **Report.** Summarise: what built, what was stubbed, what menu paths
    are wired vs. cosmetic, and the single most important "next step"
    (almost certainly: damage/TTK tuning once you can actually play a
    bot match).

## Success criteria

- `config/mw2.cfg` exists and is sourced from `autoexec.cfg`.
- Four UI files exist under `config/ui/mw2/` and are exec'd by `mw2.cfg`.
- `gameui_panel_default` resolves to the new MW2 handler.
- `src/` builds cleanly (warnings OK, no errors).
- No edits to `src/engine/**`.
- No new C++ subsystems.

## Failure modes to avoid

- Don't try to add prone. It needs a new physent height state. Out of scope.
- Don't add aim assist. PC build.
- Don't replace weapon models or HUD textures. Out of scope.
- Don't touch `physframetime` or any networking constants.
- Don't `git push --force` or rewrite history.
