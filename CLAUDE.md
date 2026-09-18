# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Project Tactics is a 2D tactics game built with [LÖVE2D](https://love2d.org/) (Love2D), a Lua game framework.

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

A **syntax check alone** is much faster than the suite (which takes minutes) and is the right
first move after any hand edit to a `.lua` file:

```powershell
& "E:\LOVE\lovec.exe" . parse            # every .lua in the tree
& "E:\LOVE\lovec.exe" . parse models/gate.lua
```

It loads each file without running it and prints the first syntax error with its line; exit 1
if any file is bad.

## Wiki

The [GitHub wiki](https://github.com/xenonsin/LoveTactics/wiki) is a **generated mirror** of
`docs/` — never edit wiki pages by hand, edit the source doc. `tools/wiki-sync.sh` copies each
`docs/NAME.md` to a Title-Cased page, rewrites intra-doc links (preserving `#anchors`), and
regenerates `Home.md` + `_Sidebar.md`. A `post-commit` hook publishes automatically whenever a
commit touches `docs/*.md`; skip it once with `LOVETACTICS_WIKI_NOSYNC=1 git commit ...`.

After a fresh clone, two one-time steps (`.git/hooks` is not tracked, so the hook does not come
with the repo):

```bash
git clone https://github.com/xenonsin/LoveTactics.wiki.git ../LoveTactics.wiki
tools/wiki-sync.sh --install-hook
```

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
  Flow: `menu → hub → Gate → game`. **The campaign is the descent** (`states/gate.lua`,
  `models/descent.lua`): one rift of **15 floors** — seven circles of two, plus the Crown under them —
  fought a floor at a time, with the Gate at the edge of the city as its only door.

  **It is a PLACE, not a roll, and that is the load-bearing fact.** A floor's ground is dealt from the
  save's own seed and the depth alone, so floor three is the same floor three for the life of a
  playthrough; the boards a company has walked are kept whole on the player (`Descent.keepFloor` →
  `player.floors`) with their fog lifted, their caches spent and their found secret doors still found.
  The monsters re-arm and the places do not (`Descent.rearmFloor`) — Wizardry's own split, which that
  function's header argues in full. A stair whose guard fell stays open, so a company **re-enters at the
  deepest floor it has mapped** (`Descent.entryFloor`) rather than re-walking cleared ground.

  So a trip is not a run: you go down, attrit, and come back up to the **Ward** to rest a wound off (in
  descents, free) or buy it off (40g), and to the **Touchstone** to have what you found named. Wounds
  outlive the trip and the roster is unbounded, so a bad trip costs **a body on the bench**, never a
  bill — the law in [docs/the-count.md](docs/the-count.md). What a company carries down is what the four
  who walk down have in their grids; the stash stays in town.

  **A wipe costs the HAUL, and the haul is not gone — it is lying where you fell.** `Descent.dropPack`
  puts the trip's finds (`Player.atRisk`'s diff against the company as it walked in) on the tile the
  party died on, in that floor's kept board; walking back to it is how you get it, down ground whose
  fights have re-armed. Nothing the company owned when it walked in is ever taken, which is the law
  above held — and the retrieval is the first reason the game has to re-enter a floor it already
  cleared. `Descent.lostPacks` derives the readout by walking the boards, so there is no second ledger
  to go stale.

  See [docs/overworld.md](docs/overworld.md) for the floor it is walked on and
  [docs/identification.md](docs/identification.md) for what a floor pays.

  **Two systems are parked, and both are one flag or one file from coming back.** *Iselle's tally*
  (`Descent.COUNT_PARKED`) charged a mark for climbing out, which prices the loop this design is built
  on. *The Bounty Board* is demoted rather than deleted: its card lives with the seven houses
  (`data/buildings/bounty_board.lua`, the houses district) and posts a ground, a tier, a body and the
  **piece** it owes, as side work against a dungeon that is the real content. See
  [docs/bounties.md](docs/bounties.md).
- **`ui/`** — reusable widgets that support **mouse + keyboard + gamepad** (project standard;
  see `ui/menu.lua`, `ui/building_map.lua`). Pop-up panels live in `ui/panels/`.
- **`models/`** — logic + instantiation over the data layer. `models/registry.lua` auto-loads
  a `data/<type>/` folder into a table keyed by filename. `models/sprite.lua` is a tolerant,
  memoized image loader (returns the path string if art is missing or `love.graphics` is absent).
- **`data/`** — declarative blueprints, one Lua file per entity (`characters/`, `items/`,
  `buildings/`, `quests/`, plus `player.lua`). Models copy these into mutable runtime state;
  blueprints stay immutable. Weapons additionally follow a per-family contract (axes cleave,
  daggers bleed) — see [docs/weapons.md](docs/weapons.md), enforced by `tests/weapon_spec.lua`.
  Every item also belongs to a **class**, which is the vendor shelf that stocks it and never an equip
  gate (anyone can carry anything) — see [docs/classes.md](docs/classes.md), enforced by
  `tests/class_spec.lua`. An item's `unlockQuests` is its **grade rank, derived not authored** — what a
  thing is worth sets where it sits — and only three kinds of thing carry a `price` at all: abilities,
  consumables, and a house's opening weapon. **Everything else is found in the rift** (`dropTier`) and
  a counter stocks it only once the company has carried one out (`Player.recordFound`, `Vendor.stock`'s
  `lockReason`). See [docs/shelf.md](docs/shelf.md) (`models/grade.lua`, `. grade-report`,
  `. drop-tier recut`). *Which body* hands a found item over is [docs/drops.md](docs/drops.md) —
  `. drop-report` measures reachability by placement, and is the pass to run before authoring a
  drop list. An item may also rewrite a **rule of the game** for its bearer (`rules`, `Item.RULE_NAMES`
  — health pinned at 1, no walking at all, mana paid in blood), open a fight wearing a status
  (`openingBoon`), or act *between* fights on an expedition (`encounterCleared`, `models/item_hook.lua`).
  All three arrived when the **relic shelf was parked** and its 25 surviving effects became items — see
  [docs/relics.md](docs/relics.md), which also records the 11 pure-stat relics that were cut and how to
  lift the park. `models/relic.lua` is still on disk and still loads; treat nothing in it as live.
  `data/meals/` is the one content type that is *not* an item: the Cafe's supper,
  one per day out, worn by the whole company — see [docs/meals.md](docs/meals.md).
  There is **one currency**, gold — no valuables to carry out and sell, no scrip; an end simply pays a
  richer purse (`Spoils.endPurse`) — and what keeps an underground purchase from being priced against a
  permanent upgrade is a ceiling rather than a second purse (`Spoils.askingPrice`). See
  [docs/economy.md](docs/economy.md); `tests/economy_spec.lua` is what keeps it that way.
- **`assets/`** — images/audio/maps referenced by path from data files (e.g.
  `assets/hub/city.png`), loaded lazily through `models/sprite.lua`. A missing file resolves to its
  path string rather than crashing, so art can land incrementally — which also means the art debt is
  invisible without a sweep. [docs/art-assets.md](docs/art-assets.md) holds the specs, sourcing and
  artist brief; `& "E:\LOVE\lovec.exe" . art-report` counts what is still outstanding.
- **`art/`** — hand-made and commissioned art, **tracked** (where `assets/` is gitignored build output).
  `. art-build` regenerates every composed icon and token unconditionally, then copies `art/` over
  `assets/` so drawn art wins by landing second; `. art-build stale` fails when `assets/` is behind its
  inputs — run it after any re-tier, since `repRank` drives an icon's frame and pips. `art/bases/` is the
  exception: those SVGs are composer *input*, the drawn replacements for the game-icons.net stand-ins,
  and `. art-source` reports how many of the 410 shipped silhouettes are still third-party.

### Hub city & pop-up panels

`states/hub.lua` is the town screen. Buildings are data-defined clickable hotspots
(`data/buildings/*.lua`, positioned in the 1280×720 logical space) rendered by the
`ui/building_map.lua` widget. Clicking a building opens a **modal pop-up panel** — an
overlay owned by the hub state (not a separate state), so the city stays visible behind it.
The hub tracks `activePanel` and routes input to it while open. Each building names a panel
module under `ui/panels/`; buildings without one fall back to `ui/panels/placeholder.lua`.
The city grows over time via each building's `unlockPrestige` (compared against the player's
prestige in `models/building.lua`), and several doors carry a second gate on top of it —
`unlockAnyHouse`, `unlockExpeditions`, `unlockWound`, `unlockUnidentified` — so a card arrives on the
trip that gives the player the problem it solves.

**Two districts, and the city one is FULL.** `Building.GRID.city` is three columns by three rows with
the Gate taking the taller middle slot: nine slots, nine cards, the last one claimed by the Inn. A new
plaza card therefore needs a slot freed or the grid re-laid — dropping one in on top of another draws
two plates over each other, which has shipped once already. `Building.GRID.houses` is the second board,
reached through the Houses card: the seven shopfronts, plus the Bounty Board on a row of its own beneath
them. See [docs/adding-content.md](docs/adding-content.md) to add a building, quest, or panel.
