# Game Modes — Forge-Style Architecture

> Design north star for the gamemode + map editor system. Living document.

## Core idea

A **map is a mode**. Geometry, entities, and gameplay rules live in the same
`.ogz` file. Players ship maps; modes ride along. No separate mode files, no
separate editor surface. This is how Halo Forge works, and it's why Forge maps
spread the way they did.

Generic modes (TDM, FFA, CTF) still exist as "templates" — rule presets that
can run on any map that has the required entity types (e.g. spawns).
User-authored maps that *embed* their own rules act as standalone modes.

## Three layers

```
Layer 0  in-engine ingredients     C++ entity types + hooks + scripted commands
Layer 1  CubeScript rule wiring    .cfg files that compose ingredients
Layer 2  in-editor rules panel     UI that writes Layer 1 for you
```

We build Layer 0 first, write modes by hand at Layer 1 to prove they work,
then add the editor UI at Layer 2 once we know the API surface.

## Entity types (Layer 0)

Existing RE entities we reuse:

- `playerstart` — spawn point (already supports team filter)
- `weapon` — weapon pickup
- `trigger` — generic volume / event source (already script-callable)
- `affinity` — flag/objective marker (CTF/capture)
- `route` — patrol/race waypoint
- `checkpoint` — capture point

New entity behaviors layered via `trigger` script IDs (no new entity type
needed yet — we use attrs as the type discriminator):

- **Kill volume** — `trigger` with script ID `9000`. Player entry → death.
- **Bounce volume** — `trigger` with script ID `9001`. Player entry → impulse out.
- **Score zone** — `trigger` with script ID `9002`. Player presence → score for team.
- **Mode anchor** — `trigger` with script ID `9999`. Map's "default rules"
  marker. Loaded once at map start, applies rules from its attrs.

If a category grows past ~3 attrs of config, we promote it to a real entity
type. For v0.1 the script-ID convention keeps things simple.

## Rule fields (Layer 1)

Every map can declare these via its `mode_anchor` trigger. If missing, mode
defaults apply (i.e. it falls back to a generic mode).

```
mode_anchor attrs:
  attrs[0] = 9999                  // anchor marker
  attrs[1] = win_condition         // see WIN_* below
  attrs[2] = score_cap             // int, 0 = no cap
  attrs[3] = time_limit_seconds    // int, 0 = no limit
  attrs[4] = loadout_policy        // see LOADOUT_* below
  attrs[5] = flags_bitmask         // perks, vehicles, melee_only, etc.
```

Enums:

- `WIN_LAST_STANDING` — eliminate-once, last alive wins
- `WIN_FIRST_TO_N_KILLS` — score-cap from attrs[2]
- `WIN_HOLD_ZONE` — accumulate time in score zones, cap from attrs[2]
- `WIN_HIGHEST_SCORE_AT_TIME` — time_limit from attrs[3]
- `LOADOUT_MELEE_ONLY` — spawn with melee, no other weapons
- `LOADOUT_ROTATING` — gun-game style, advance on kill
- `LOADOUT_FIXED` — spawn with a fixed list
- `LOADOUT_PICK10` — use saved class slot (year 2 feature, stubbed for now)

Flags bitmask:
- bit 0: perks allowed
- bit 1: vehicles allowed
- bit 2: friendly fire on
- bit 3: respawn enabled (off = elimination)

## Lifecycle hooks (Layer 1)

CubeScript callbacks the engine fires:

```
on_match_start         // before first player spawns
on_player_spawn $cn    // $cn = client number
on_player_kill $cn $tn // $cn killed $tn
on_player_death $cn    // any death (synonym for kill victim side)
on_trigger_<id>        // already exists, used for volumes
on_timer_<name>        // user-registered timers
on_match_end           // before scoreboard
```

`$cn` etc. set as transient vars during callback execution.

## Built-in modes (Layer 1, v0.1)

Each mode is a `.cfg` file in `config/modes/`:

- `sumo.cfg` — last-standing, melee, kill volumes around platform
- `gungame.cfg` — rotating loadout, first to cycle all weapons wins
- `infection.cfg` — asymmetric team, melee-only zombies grow in number
- `prophunt.cfg` — (later) hiders disguise as map props

## File layout

```
config/modes/
  framework.cfg          // hook dispatcher, registry
  helpers.cfg            // killplayer, giveweapon, setflag helpers
  sumo.cfg               // first mode
  gungame.cfg
  infection.cfg
data/maps/
  sumo_platform.ogz      // sample Sumo arena
  gungame_office.ogz     // sample Gun Game level
```

## Server authority

All mode logic runs **server-side** (in CubeScript executed on the dedicated
server or listen server). Client receives state diffs, never makes decisions.
Mode files validated at load — malformed rules (e.g. score_cap < 0) reject
with an error, no crash, no exploit.

## Roadmap link

- v0.1 (now): Layer 0 helpers, Layer 1 framework + Sumo
- v0.2: Gun Game + Infection
- v0.3: Editor rules panel (Layer 2)
- v0.5: Pick 10 loadouts (replaces `LOADOUT_PICK10` stub)
- v1.0: Vehicles, killstreaks, all integrated through this same hook system
- v2.0: Visual node editor as Layer 2.5

## Open questions

- Per-mode gunplay overrides (damage/recoil) — proposed: extra attrs on
  `mode_anchor` or a separate `gunplay_anchor` trigger. Defer until we have
  a second mode that needs them.
- Multi-round modes (best of N) — handled by `on_match_end` setting next
  match's state.
- Spectator / pre-game lobby UI — separate concern, lives in
  `config/ui/game/lobby.cfg` (doesn't exist yet, year 1 work).
