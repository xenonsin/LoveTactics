# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LoveTactics is a 2D tactics game built with [LÖVE2D](https://love2d.org/) (Love2D), a Lua game framework.

## Running the Game

```powershell
love .
```

Requires LÖVE2D to be installed and `love` available on PATH. On Windows, this may require the full path: `& "E:\LOVE\love.exe" .`

## Tests

Headless test suite (no window), run with the console build:

```powershell
& "E:\LOVE\lovec.exe" . test
```

Any `tests/*_spec.lua` file is auto-discovered by `tests/runner.lua`. Each spec returns a
list of `{ name, fn }` cases; `fn` uses `assert(...)` and is run under `pcall`. Exit code is
0 when all pass, 1 otherwise. See `tests/data_spec.lua` and `tests/hub_spec.lua` for the style.
Keep model/data logic free of `love.graphics` at require-time so it loads under headless tests.

## Framework

- **Engine:** LÖVE2D — callbacks defined in `main.lua` (e.g., `love.load`, `love.update`, `love.draw`, `love.keypressed`)
- **Language:** Lua 5.1 (LÖVE2D's embedded interpreter)
- **No build step** — Lua is interpreted at runtime by the LÖVE executable

## Architecture

The codebase is organized into layers loaded via `require()`. See
[docs/architecture.md](docs/architecture.md) for the full walkthrough; the summary:

- **`main.lua`** — entry point. Forwards every LÖVE callback to the current state and
  handles the headless test entry (`. test`).
- **`scale.lua`** — virtual-resolution scaling. The whole game is authored in a fixed
  **1280×720 logical space** and letterbox-scaled to the real (resizable) window; `main.lua`
  wraps `draw` in the transform and converts mouse coords back to logical space. Draw and
  position everything in 1280×720 coordinates — use `Scale.WIDTH`/`Scale.HEIGHT`, not
  `love.graphics.getWidth/Height`. F11 toggles fullscreen.
- **`states/`** — screens as plain tables with optional LÖVE callbacks (`enter`, `update`,
  `draw`, `keypressed`, `mousepressed`, `gamepadpressed`, …). `states/init.lua` is the
  minimal manager: `State.switch(state, ...)` sets the current state and calls its `enter`.
  Flow: `menu → hub → (Quest Board → game)`.
- **`ui/`** — reusable widgets that support **mouse + keyboard + gamepad** (project standard;
  see `ui/menu.lua`, `ui/building_map.lua`). Pop-up panels live in `ui/panels/`.
- **`models/`** — logic + instantiation over the data layer. `models/registry.lua` auto-loads
  a `data/<type>/` folder into a table keyed by filename. `models/sprite.lua` is a tolerant,
  memoized image loader (returns the path string if art is missing or `love.graphics` is absent).
- **`data/`** — declarative blueprints, one Lua file per entity (`characters/`, `items/`,
  `buildings/`, `quests/`, plus `player.lua`). Models copy these into mutable runtime state;
  blueprints stay immutable. Weapons additionally follow a per-family contract (axes cleave,
  daggers bleed) — see [docs/weapons.md](docs/weapons.md), enforced by `tests/weapon_spec.lua`.
- **`assets/`** — images/audio/maps referenced by path from data files (e.g.
  `assets/hub/city.png`), loaded lazily through `models/sprite.lua`.

### Hub city & pop-up panels

`states/hub.lua` is the town screen. Buildings are data-defined clickable hotspots
(`data/buildings/*.lua`, positioned in the 1280×720 logical space) rendered by the
`ui/building_map.lua` widget. Clicking a building opens a **modal pop-up panel** — an
overlay owned by the hub state (not a separate state), so the city stays visible behind it.
The hub tracks `activePanel` and routes input to it while open. Each building names a panel
module under `ui/panels/`; buildings without one fall back to `ui/panels/placeholder.lua`.
The city grows over time via each building's `unlockPrestige` (compared against the player's
prestige in `models/building.lua`). See [docs/adding-content.md](docs/adding-content.md) to
add a building, quest, or panel.
