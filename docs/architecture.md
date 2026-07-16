# Architecture

LoveTactics is a LÖVE2D (Lua 5.1) game with no build step — the LÖVE runtime interprets
the source directly. Code is organized into layers, loaded via `require()`.

```
main.lua              entry point; forwards LÖVE callbacks; headless test entry
conf.lua              window config (1280x720, resizable); disables window in test mode
scale.lua             virtual-resolution letterbox scaling (1280x720 logical space)
states/               screens (menu, hub, game) + the state manager (init.lua)
ui/                   reusable input widgets (menu, building_map) ...
ui/panels/            ... and modal pop-up panels (quest_board, placeholder)
models/               logic + instantiation over the data layer
data/                 declarative blueprints, one Lua file per entity
tests/                headless spec suite + runner
assets/               images/audio referenced by path from data files
```

## State machine

`states/init.lua` is deliberately tiny:

```lua
function State.switch(state, ...)
    State.current = state
    if state.enter then state.enter(state, ...) end
end
```

A **state is just a table** that may define any LÖVE callback (`enter`, `update`, `draw`,
`keypressed`, `keyreleased`, `mousepressed`, `mousereleased`, `mousemoved`, `wheelmoved`,
`textinput`, `gamepadpressed`, `gamepadreleased`, `gamepadaxis`). `main.lua` declares each
`love.<callback>` once and forwards it to `State.current` if that state defines it. Two kinds of
wrapping happen there: `draw` is bracketed by `scale.lua`'s letterbox transform, and the mouse
callbacks have their coordinates converted from real-window to logical space (`Scale.toGame`) so
states always work in the 1280x720 design space. States are loaded on demand — no pre-registration:

```lua
State.switch(require("states.hub"))
```

There is no built-in `leave` hook; do any teardown before calling `State.switch`.

Screen flow: **menu → hub → (Quest Board → game → battle)**. `states/game.lua` is the
overworld a started quest transitions into; engaging a combat encounter there switches to
`states/battle.lua` (see *Combat: battle arenas* below).

## Three-input UI (project standard)

Every interactive screen must support **mouse, keyboard, and gamepad**. Rather than
re-implement this per screen, states forward their input callbacks to a widget that handles
all three:

- **`ui/menu.lua`** — vertical button list. Mouse hover selects / click activates; up-down /
  W-S / D-pad / left-stick navigate; Enter/Space/A activate. `opts.centerX` places it off the
  screen center (used to seat the quest list inside a panel column). `opts.maxVisible` caps how
  many rows are drawn and **scrolls** the rest: the selection leads and the window follows, the
  wheel scrolls without moving the selection, PgUp/PgDn jump a windowful, and rows outside the
  window get no rect at all — so they fall out of hit-testing and drawing for free. A list that
  grows with content (the Quest Board, a vendor's shelf) must set it.
- **`ui/building_map.lua`** — clickable hotspots positioned over a background image (the hub
  city). Same input surface as the menu; left/right (and D-pad / left-stick X) cycle through
  unlocked buildings, skipping locked ones.

Widgets keep the three inputs in sync by having mouse hover update the same `selected` index
that keyboard/gamepad move. Colors follow a shared palette (gold = selected/highlight, muted
blue-grey = idle); see `ui/menu.lua` for the reference values.

### Modal pop-up panels

Panels (`ui/panels/*.lua`) are overlays **owned by a state**, not separate states, so the
screen behind them stays visible. A panel exposes the same widget interface
(`new`, `update`, `draw`, `mousemoved`, `mousepressed`, `keypressed`, `gamepadpressed`) plus an
`onClose` callback. The owning state (e.g. `states/hub.lua`) tracks `activePanel`, routes input
to it while open, and clears it on close. `ui/panels/quest_board.lua` reuses `ui/menu.lua` for
its quest list and draws a detail pane for the highlighted quest; `ui/panels/placeholder.lua` is
the generic "coming soon" fallback.

## Data-driven models

`models/registry.lua` scans a folder and requires every `.lua` file, returning a table keyed by
filename (the entity id):

```lua
Building.defs = Registry.load("data/buildings", "data.buildings")
-- data/buildings/quest_board.lua  ->  Building.defs.quest_board
```

Add content by dropping a new file in the folder — no registration needed.

**Blueprints in `data/` are immutable.** Models copy the relevant fields into fresh runtime
tables (e.g. `Character.instantiate`, `Building.list`, `Quest.available`) so gameplay never
mutates the source defs. Tests assert this (see `tests/data_spec.lua`, `tests/hub_spec.lua`).

`models/sprite.lua` resolves asset path strings to shared, memoized `love.graphics` images and
is deliberately tolerant: if the file is missing — or `love.graphics` is unavailable, as in a
headless test — it returns the path string instead of crashing. Callers check `type(...)`
before drawing.

**Keep `models/` and `data/` free of `love.graphics` at require-time.** The headless test
runner loads these modules with no window; touching graphics at load time would break it.
(Widgets and states may use `love.graphics` freely — they are only required when switched to,
which never happens in test mode.) `models/save.lua` uses `love.filesystem`, which *is*
available headless.

## Progression and persistence

`models/player.lua` owns **one live player per session**, `Player.active`, established by
`Player.start(fresh)` from the main menu — either a new game or the save file. States must read
it (`hub.enter` does `Player.active or Player.start()`) and never call `Player.new()`, which
discards all progress.

`models/save.lua` serializes a **lean schema of blueprint ids**, never live instances, into
`love.filesystem` (the save directory is named by `t.identity` in `conf.lua`). Loading
re-hydrates through `Character.instantiate` / `Item.instantiate`, so blueprints stay the source
of truth and a content edit flows into existing saves rather than corrupting them. Current
health/mana/stamina are *not* saved: `hub.enter` calls `Player.restore`, which refills the
roster, so attrition lasts a quest rather than a campaign and a loaded party is always whole.

The economy is one direction of dependency: `Quest` → `Player` → `Vendor` → `Item`. `Vendor`
resolves reputation ranks from a **points number, not a player**, which is what keeps `Player`
free to depend on it without a require cycle. Progress is written at the two points it changes —
`Quest.complete` (the objective-win branch of `states/game.lua`) and a vendor purchase.

## Combat: battle arenas

Engaging a combat encounter on the overworld (`states/game.lua` → `game:openEncounter`, for
the `combat` / `elite` / `objective` kinds) drops into an **8×8 battle arena**; the non-combat
kinds (`town` / `treasure`) keep the simple `ui/panels/encounter.lua` modal. The arena follows
the same three-layer split as the overworld:

- **`models/arena.lua`** — pure logic (only `love.math`, headless-safe). An arena is built from
  a *layout* (tile types + party/enemy spawn positions). Procedural generation and every curated
  file in `data/arenas/` tagged for the biome share one random pool, so a curated map and a fresh
  procedural map are both live outcomes each battle (`Arena.pickLayout`).
  `Arena.build(ctx, spec)` resolves the enemy roster from the encounter's
  `composition(ctx)`, binds party + enemy ids onto the layout's spawns, and returns
  `{ cols, rows, tiles[y][x]={type,moveCost,walkable}, party, enemies, objective, … }`.
  `Arena.TILE_PROPS` is the (intentionally small, extensible) tile palette — `ground`, `rough`
  (move penalty), `obstacle` (blocked). `Arena.serialize`/`Arena.save` write an arena back out
  as a curated `data/arenas/<id>.lua` for hand-editing (dev-only; see below).
- **`ui/battle_map.lua`** — renderer + three-input widget. Draws the grid flavoured by the
  quest's biome tileset (each arena tile type maps to an overworld tileset type for art, with a
  colored-rect fallback), overlays party/enemy tokens, and tracks a cursor.
- **`states/battle.lua`** — wires them together and owns the transitions. Victory resumes the
  *same* overworld (the tile is marked cleared; the objective completes the quest to the hub);
  a total party wipe or forfeit fails the quest back to the hub. These are supplied as
  `onWin`/`onLoss` closures from `game:openEncounter`, so `states/game.lua` owns the flow.

**Enemy composition** is authored per encounter as `composition = function(ctx)` (mirroring the
existing dynamic `weight`), returning a list of `data/characters/` ids that **scales with
`ctx.prestige`** — more foes, tougher rosters at higher renown. Enemies reuse the party-character
schema (`Character.instantiate`). The objective tile reads its roster + win condition from the
quest's `map.objective` (`composition` + `win = { type, target }`).

### Combat subsystems

`models/combat.lua` owns the rules; five sibling modules layer on top of it. Each is required by
`combat.lua` at load time and reaches *back* into it through a **lazy require inside its
functions**, so the dependency stays one-way and no require cycle forms. Follow that shape when
adding a sixth.

| Module | Lives in | What it adds |
|---|---|---|
| `models/status.lua` | `unit.statuses` | timed effects; tick down inside `Combat.rebase` |
| `models/trap.lua` | `combat.traps` | hidden tile objects, triggered by pathing over them |
| `models/hazard.lua` | `combat.hazards` | persistent per-cell area effects (fire, rain, sanctuary) |
| `models/summon.lua` | `combat.units` | characters placed on the field mid-battle |
| `models/trait.lua` | `unit.traits` | standing reactions: combat start, damage survived, cast, death |

**Traits vs. statuses.** A trait is the *rule*; a status is the *stacking effect* it applies. Statuses
are timed, refreshable, and render as removable badges; traits are innate, permanent, and invisible.
Traits come off a character blueprint (`traits = { "wrath_rising" }`) **or off any item in the 3x3
grid**, which is how a boss's relic hands its rule to whoever wears it. `onDamaged` fires after
mitigation and only on a survivor — the blow that kills you grants no rage, and a health-threshold
phase never triggers on a corpse. A per-unit, per-hook reentrancy flag and a depth cap keep a
retaliation from recursing. The damage preview routes through `Combat.computeDamage`, never
`dealFlatDamage`, so hovering a target never advances a trait.

**Who drives a unit** is `unit.control` — `"player"`, `"ai"`, or `"none"` (a decoy: it holds a
slot in the turn order and burns a tick, but never acts). `states/battle.lua` branches on
`Combat.isPlayerControlled(unit)`, *not* on `unit.side`, so a player's summon takes an interactive
turn and an enemy's is AI-run with no extra wiring.

**Reservation** (`Combat.reserve`) commits part of a resource for as long as a summon lives. It
lowers the *ceiling* `current` may reach — `Combat.unreservedMax(char, stat) = max - reserved` —
and never touches `max`, so percentage-of-maximum modifiers stay honest. Reservations live on the
`char`, beside the `{max,current}` pools they constrain; they are cleared at battle setup and
released by the death path when either the summon or its summoner falls. `Combat.restoreResource`
and `Combat.applyHeal` are the only places the ceiling is enforced.

**One summon per item.** The unit `fx.summon` / `fx.copy` creates is stamped onto the item that
called it, and `Combat.activeSummon(item)` reads it back for as long as it lives. That is the whole
mechanism behind "you may not recast a summon while its creature stands": `Combat.itemBlockReason`
reports `kind = "active"`, which grays the slot, refuses the cast, and hides the ability from the AI.
It needs no bookkeeping on death — the unit's own `alive` flag retires the claim — and battle setup
wipes any claim a surviving summon left on a party item.

**Summon duration** is optional and measured in ticks. `Summon.tick` sits beside `Status.tick` and
`Hazard.tick` in `Combat.rebase`, counting `unit.summonRemaining` down by the elapsed clock; at zero
the creature fades via `Combat.dismiss`. A summon with no `duration` has no countdown and stands
until it is killed. `Combat.dismiss` is the single path for leaving the field short of dying — the
summoner fell, or the binding lapsed — and it cascades to anything that summon was itself sustaining.

**Ability prices** all flow through `Combat.abilityCost(unit, ab)`, which folds in any status
`costMultiplier` (Haste). A reservation is not a price, and is deliberately never discounted.

**Arriving on a tile** is one function, `Combat.enterTile`: it springs an opposing trap and fires the
on-entry effect of any hazard there. Every way a unit can come to occupy a tile goes through it —
`Combat.moveUnit` (per path tile), forced movement (`Combat.knockback` / `Combat.pull`, which moves a
unit with no turn and no move cost), and `Summon.spawn` / `Summon.copy`. So being shoved across a
spike trap, or conjured on top of one, is exactly as dangerous as walking over it. A summon can
therefore die on arrival: `fx.summon` / `fx.copy` bind the ability's reservation and its
`activeSummon` claim only to a creature that survived, or the caster would hold mana for a corpse.

Its `reason` argument says *how* the unit got there — `"walk"` (a metered step), `"forced"` (shoved,
pulled, trampled), or nil (a blink, a swap, a summon's arrival: no ground crossed). Traps, hazards,
and auras ignore it, since the ground does not care how you came to stand on it; only
`Status.onEnterTile` reads it, which is what makes Bleed cost blood per tile crossed under a unit's
own weight while a blink escapes it clean. It defaults to nil, so a forgetful call site fires nothing.

**The `fx` context is built three times** in `combat.lua`: for real in `Combat.useItem`, and once
each as a non-mutating dry run in `Combat.previewAbility` (the aimed hover preview) and
`Combat.abilityOutput` (the inventory tooltip). Both dry runs are `pcall`-guarded, so **a new `fx`
helper must be added to all three** — otherwise the guarded replay swallows a nil-call and the
tooltips silently go blank.

## Tests

`tests/runner.lua` auto-discovers `tests/*_spec.lua`. Each spec returns `{ name, fn }` cases;
`fn` raises via `assert` on failure and is run under `pcall`. Run headless:

```powershell
& "E:\LOVE\lovec.exe" . test
```

`main.lua` routes `. test` to the runner and exits with 0 (all pass) or 1 (any fail);
`conf.lua` disables the window for that arg.
