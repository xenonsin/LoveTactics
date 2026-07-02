# Architecture

LoveTactics is a LÖVE2D (Lua 5.1) game with no build step — the LÖVE runtime interprets
the source directly. Code is organized into layers, loaded via `require()`.

```
main.lua              entry point; forwards LÖVE callbacks; headless test entry
conf.lua              window config (800x600); disables the window in test mode
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
`love.<callback>` once and forwards it to `State.current` if that state defines it. States are
loaded on demand — there is no pre-registration:

```lua
State.switch(require("states.hub"))
```

There is no built-in `leave` hook; do any teardown before calling `State.switch`.

Screen flow: **menu → hub → (Quest Board → game)**. `states/game.lua` is currently a
placeholder that a started quest transitions into.

## Three-input UI (project standard)

Every interactive screen must support **mouse, keyboard, and gamepad**. Rather than
re-implement this per screen, states forward their input callbacks to a widget that handles
all three:

- **`ui/menu.lua`** — vertical button list. Mouse hover selects / click activates; up-down /
  W-S / D-pad / left-stick navigate; Enter/Space/A activate. `opts.centerX` places it off the
  screen center (used to seat the quest list inside a panel column).
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
which never happens in test mode.)

## Tests

`tests/runner.lua` auto-discovers `tests/*_spec.lua`. Each spec returns `{ name, fn }` cases;
`fn` raises via `assert` on failure and is run under `pcall`. Run headless:

```powershell
& "E:\LOVE\lovec.exe" . test
```

`main.lua` routes `. test` to the runner and exits with 0 (all pass) or 1 (any fail);
`conf.lua` disables the window for that arg.
