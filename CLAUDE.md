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

The [GitHub wiki](https://github.com/xenonsin/LoveTactics/wiki) is a **generated reference to the
DATA** — never edit a wiki page by hand, edit the blueprint. It mirrored `docs/` until 2026-09-20 and
does not any more: the design docs argue about why the game is shaped this way and belong beside the
code that a change lands in, while a wiki is read by somebody who wants to know what a thing *does*.
`docs/` is untouched and still the design source; it is simply no longer published.

`& "E:\LOVE\lovec.exe" . wiki-gen` (`tools/wiki_gen.lua`) renders **58 pages**: every item by class
then by type (842 over 46 class pages), every body by kind (**the Bestiary** — 153 over 8), the Rift's
fifteen floors, and the indexes over all three, into the gitignored `wiki/`. Every number is read
through the model (`Item.instantiate` / `Item.growth` at each forge level, `Character.instantiate` for
a stat block), so a page cannot disagree with the game; a column no item in a section filled is
dropped from that table. `tools/wiki-sync.sh` builds and publishes it, and its prune step retires any
page that is no longer generated — which is what took the 38 doc pages down. `. wiki-gen` alone, or
`tools/wiki-sync.sh --build-only`, rebuilds `wiki/` without publishing anything.

**THE THREE KINDS OF PAGE CROSS-LINK, AND THAT IS WHAT THE BESTIARY IS FOR.** An item's *Dropped by*
cell links to the body's entry; that entry's *Carries* and *Drops* link back to the shelves those
pieces sit on; the Rift's composition rows link every name on every floor. A body is addressed by a
`##` heading rather than a table row because **a markdown row cannot carry an anchor** — which is the
one place these pages break the wiki's table idiom, and the reason they do. Each link is built from
the same heading text the section is titled with (`anchorOf`), and `tests/wiki_spec.lua` walks every
link on every page back to a heading that exists, with the slug rule written out a second time there
so the generator cannot grade itself.

**WHAT A BODY IS FIELDED BY IS MEASURED TWICE OVER, and both halves are needed.** The placement census
in `tools/drop_report` sweeps `Encounter.pool`, which is every body a floor can *roll*; a guardian, her
escort, a ward and the Crown are seated by `Descent` directly and are in no pool, so that sweep alone
calls a circle's general unfielded. `riftFloors()` walks the fifteen floors once — the same walk the
Rift page prints — and records who stands on each stair. 50 of the 153 blueprints are reachable by one
route or the other; the rest say *the rift never fields it* on their own entry rather than being left
off. That wording is the measurement and not a stronger claim: a scripted scene can still hand-place a
body (the prologue's demons), which neither sweep can see.

**TWO HOOKS KEEP IT HONEST, AND THEY TRIGGER ON DIFFERENT THINGS ON PURPOSE.** A `post-commit` hook
publishes whenever a commit touches **any `.lua`** — not just `data/`, because the pages are not a
copy of the blueprints: every number is computed through `Item.growth`, `Spoils.depthOf`, `Class` and
`Trait`, so a models-only commit can move every rank on all 46 pages. Resolved transitively that
dependency set is 71 files, so a hand-list would go stale the first time the renderer grows a
`require`; instead the **generated diff is the gate** — when the pages come out identical the sync
finds nothing to commit and the hook stays silent. Skip it once with `LOVETACTICS_WIKI_NOSYNC=1 git
commit ...`. Note it builds from the **working tree**, so uncommitted edits publish too.

The second is `tools/wiki-watch.sh`, a Claude Code `PostToolUse` hook wired in `.claude/settings.json`:
editing a blueprint under `data/items/`, `data/characters/`, `data/races/` or `data/encounters/`
rebuilds `wiki/` on the spot, and **fails the edit (exit 2) if the blueprint no longer loads** — so a
broken blueprint is reported against the edit that broke it rather than at commit time. That list is
deliberately short of the transitive truth; the post-commit hook above is the backstop for everything
else. `tests/wiki_spec.lua` holds the pages to their promises.

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

  So a trip is not a run: you go down, attrit, and come back up to the **Ward** to rest an injury off
  (in descents, free) or buy it off (40g), and to the **Touchstone** to have what you found named. An
  injury is one of **seven named kinds**, dealt off the save's own seed when a body is carried out -- a
  sealed share of a pool, a broken leg, a torn shoulder, a rattled head -- and they STACK, floored per
  stat so a veteran can be ruined and never made inert. Nothing in a fight lifts one: every badge is
  authored uncleansable, which closed a live hole where a Cure stripped the campaign's own attrition
  meter. See [docs/injuries.md](docs/injuries.md). Injuries outlive the trip and the roster is
  unbounded, so a bad trip costs **a body on the bench**, never a bill — the law in
  [docs/the-count.md](docs/the-count.md). What a company carries down is what the four
  who walk down have in their grids **and what is in the PACK** (`player.pack`); the stash stays in town.

  **THE BAG IS THE ONLY CONTAINER UNDERGROUND, AND IT IS WHERE EVERY FIND LANDS.** The law above was
  written before there was one, and it was enforced in exactly one place -- the Use panel -- while the
  Loadout screen went on showing the whole town shelf as a live drag source on floor nine. It is a real
  container now, packed at the Armory or at the Gate (`ui/panels/party.lua`'s `pool` opt puts a
  **Stash | Pack** switch over the column; underground the switch is not drawn, because there is
  nothing to switch to). `Player.stow` is the ONE seam that routes a grant -- a chest, a fight's
  spoils, a lift off a pocket, a pile picked back up -- so no other seam on the way in learns a rule;
  `Player.packOpen` is the flag, and it reads `descentRun.entry` rather than `descentRun`, because the
  run is seated the moment you walk onto the Gate screen and a company packing a bag there is still
  standing in the city. Both exits empty it onto the shelf (`Player.unpack`).

  **AND IT MADE ONE NUMBER INTO TWO, WHICH MUST NOT BE COLLAPSED AGAIN.** `Descent.carried` counts the
  BAG -- slots, rations included, against `Descent.carryMax` (**28**: twenty of finding plus eight of
  supplies) -- and is what the chest refusal and the *"Carrying n / max"* readout ask. `Descent.found`
  is the old diff against the entry snapshot -- quantities -- and is what the stair's toll
  (`Descent.tollFor`) and Still Hungry's bite ask. A toll priced against the bag would quote a share of
  the company's own draughts and then fail to take them, since `Player.takeAtRisk` only ever hands over
  finds: *a stair that could reach into somebody's hand for their sword would be a robbery rather than
  a price*. `tests/pack_spec.lua` holds both halves.

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
  on. *The Bounty Board* is parked: its blueprint is deleted (it stood on the houses' square, and that
  square is gone with the fold) while `models/bounty.lua` stays on disk and stays required by six
  models. It posted a ground, a tier, a body and the **piece** it owes, as side work against a dungeon
  that is the real content; if it comes back it comes back as a ROOM on a desk. See
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
  `tests/class_spec.lua`. An item's `unlockLevel` is its **grade rank, derived not authored** — what a
  thing is worth sets where it sits — and only three kinds of thing carry a `price` at all: abilities,
  consumables, and a house's opening weapon. **Everything else is found in the rift** -- and a counter
  deals it once the CLASS HAS GROWN THAT FAR. **Class level is the only gate on a shelf**
  (`Quest.shelfRung`, the roster's best holder): the rift is the head start, the class ladder is the
  backstop that guarantees the piece is reachable at all.

  **ONE LADDER, ONE FIELD, ONE RUNG PER FLOOR.** `unlockLevel` runs `0..Class.CLASS_LEVEL_CAP`, the cap
  is **15 — the floor count** (`Descent.FLOORS`), and a rung costs a floor and a quarter of
  committed play (`Class.CLASS_LEVEL_STEP = 50`, linear -- a floor measures 39.7, and the quarter on
  top is what a floor you can walk AGAIN costs). So the class level that buys a piece and the floor
  the rift gives it up at are the same number, which is what `tools/drop_tier.lua` always claimed and could not
  deliver while the cap was 8 against fifteen floors. It WAS two fields -- `unlockQuests` (a grade rank
  named for the retired quest board) and `dropTier` (a depth counting from 1) -- with 231 blueprints
  carrying both and an off-by-one between them; `tools/ladder_fold.lua` folded them and records the
  measurement that made it safe. Re-cutting the cap restretches the drop band, the forge ceiling, the
  market's rotation, the salvage span and the mastery scalar on its own; what it does NOT restretch is
  authored data, so a re-cut owes `. ladder-fold`, then `. balance-rescale apply 0`.

  **HOW MANY A RUNG DEALS IS A CURVE, AND `tools/shelf_curve.lua` OWNS IT.** Two passes write
  `unlockLevel` -- `. grade-report` deals a class's PRICED stock, `. drop-tier` its FINDS -- and the
  player meets the SUM at one counter, which neither could see. The shipped result was the Bastion
  opening `5 2 5 1 3 3 9 4 ...`, nine wares at knight 6 and **fifteen of the city's 112 rungs opening
  nothing at all**. One shape now governs both: a **ramp**, every rung handed one ware before the
  surplus is spread, so the front deals two or three where the deep end deals five or six. **Rung 0 is
  the re-arm floor** -- the graded spread starts at 1, and what sits below it is a house's opener plus
  what an author has pinned as gated by nothing (the nine standing draughts: a rung is a gate, and a
  gate on a healing potion prices a need). **And the finds are cut PER CLASS**, but only where a class
  can fill a ladder: the seven roots carry 20-57 finds, every discipline ten or fewer, and a band
  thinner than the ladder keeps the rift's GLOBAL grade order -- because a body's drop list spans many
  classes and within one list the tier IS the rarity ([docs/drops.md](docs/drops.md)). Re-spreading
  owes `. grade-report apply`, `. drop-tier apply`, `. balance-rescale apply 0`, iterated to a fixed
  point; `tests/unlock_ladder_spec.lua` holds the curve. There is no discovery gate -- a ware is not
  shut until you have carried one out, and `player.found` feeds the BESTIARY now, not a counter
  (removed 2026-09-19; docs/shelf.md narrates why).

  **Three lock reasons, one field** (`Vendor.lockReason`): `"rung"` (grow the class), `"class"` (unlock
  the discipline -- itself a class-level gate one step removed), and `"monster drop"`. The last is
  `unstocked`: a body's own trophy, which is **visible on the rack and never sold**. It used to be
  invisible -- no price meant it never entered `Vendor.stock` at all -- so the rarest pieces in the game
  could not be learned about at any counter. It is stocked and greyed now, and the price stays nil in
  BOTH directions (`Vendor.sellValue` answers 0): visible is not the same as merchandise. See [docs/shelf.md](docs/shelf.md) (`models/grade.lua`, `. grade-report`,
  `. drop-tier recut`). *Which body* hands a found item over is [docs/drops.md](docs/drops.md) —
  `. drop-report` measures reachability by placement, and is the pass to run before authoring a
  drop list. **That measurement is exported (`drop_report.sources()`) and printed on the wiki as the
  "Dropped by" column**, so the pages name the body a player can go and kill; it is ONE measurement
  on purpose, because a page naming a body the report calls unreachable would be a disagreement with
  nothing to show it. Today 85 of the 388 rift items come off a named body and the other 303 fall out
  of the depth-banded draw, which is why a blank cell there is an answer and not a gap.
  An item may also rewrite a **rule of the game** for its bearer (`rules`, `Item.RULE_NAMES`
  — health pinned at 1, no walking at all, mana paid in blood), open a fight wearing a status
  (`openingBoon`), or act *between* fights on an expedition (`encounterCleared`, `models/item_hook.lua`).
  All three arrived when the **relic shelf was parked** and its 25 surviving effects became items — see
  [docs/relics.md](docs/relics.md), which also records the 11 pure-stat relics that were cut and how to
  lift the park. `models/relic.lua` is still on disk and still loads; treat nothing in it as live.

  **A PIECE MAY ALSO BE CURSED, and a curse speaks the item's own vocabulary** (`models/curse.lua`,
  `data/curses/`, [docs/curses.md](docs/curses.md)). It is the mirror of *broken*: broken means the piece
  stops working and the Forge fixes it for gold; cursed means the piece works **against** you and the
  Cathedral's rite lifts it — free but costing two trips with the piece on the altar, or `Curse.fee` in
  gold to skip them, which is `models/injury.lua`'s law with an item where the body goes. A blueprint here
  declares the fields an ITEM declares (`bonus`, `resist`, `maxBonus`, `rules`, `traits`, `openingBoon`),
  so it folds in beside the piece at `Combat.applyUnitPassives` with no new balance surface; its one
  field of its own is `binds`, which makes `Item.isBound` answer true and thereby reuses every refusal in
  the game. Hexes arrive from a trap (`ctx.curse`), a cast (`fx.curse`), a blueprint born hexed
  (`curse = "..."`), or the Touchstone naming a find that was sealed with one.

  **AND A HEX IS A RESOURCE AS WELL AS A COST**, which is what keeps the Cathedral a decision rather
  than a chore. Three verbs, one per house, asserted over the shelf by `tests/curse_shelf_spec.lua`
  rather than only written down: the **Shaman** MANIPULATES (counts, moves, spreads, wakes, lends) and
  never ends one; the **Exorcist** ENDS and PREVENTS (the two rites, and `curseWard`); the **Cathedral**
  stays open to every company, priest or not, which is `docs/the-count.md`'s law holding. Counting rides
  `ab.counter` + `counterGates = false` -- the pair `weapon_last_word` already wears -- so the grid
  badge, the tooltip row and the effect's multiplier are one call. *Lifting is a high-level priest
  thing* needed no new gate: `Quest.shelfRung(player, "cathedral")` already reads the roster's best
  priest level, so a priced rite at a high `unlockLevel` is invisible until somebody has climbed it.
  **AN ABILITY MAY NOW BE CAST OUTSIDE A FIGHT** (`outOfCombat = true`, `Player.partyAbilities`). The
  overworld Use panel gathers it beside the draughts and `kind` tells them apart -- a *drink* spends a
  stack and is gone, a *cast* spends a pool that `Player.camp` partly refills. A road cast runs a
  second, smaller effect, **`roadEffect(ctx)`**, with a four-verb context (`heal`, `restore`,
  `liftCurse`, `say`): an ability's `effect` is written against Combat's forty-verb `fx` table, all of
  it about a board that does not exist out here, and faking one would be forty stubs that silently do
  nothing. It costs exactly what it costs in a fight -- no surcharge (authored 2026-09-20).
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
The hub tracks `activePanel` and routes input to it while open.

**SEVEN OF THE NINE CARDS ARE COUNTERS, and a counter is a shopkeeper with a DESK**
(`models/counter.lua`). Pressing a house plays what it owes you (`models/vendor_visit.lua` — the
greeting, any new discipline), then its **counter scene**, which ends on one node carrying `choices`:
the rooms behind that door. The `answer` on the committed choice names a room, the host opens that
panel, and **closing it returns to the desk** rather than to the plaza (`Conversation.play`'s
`opts.startAt`), so a player can set a bone, read a find and browse without the door shutting between
them. Only the Rift (a whole screen) and the Armory (one panel) are plain doors.

**A ROOM IS AN `offers` ENTRY** (`models/offer.lua`): `{ answer, panel, vendor?, gate?, quiet? }`. A desk
line shows when its room is open (`when = { offer = "mend" }`), and **a door is drawn when ANY non-quiet
room behind it is** — so the city grows *inside* doors as new lines rather than as new plates. A folded
room keeps its own `vendor`, which is why the Undercroft's desk can open the town counter beside the
fence's own shelf without the two shops merging.

**THE CITY IS PACED ON `trips` — descents begun (`Player.tripsHome`), never on depth.** `expeditionsOut`
is `max(bounties, deepest)`, and depth is bursty: measured, a company that dived to floor four on its
first trip came home to four doors at once and then three empty homecomings, while a floor-one farmer's
city froze forever. Trips climb one at a time, so **one room per homecoming** falls out of the unit.
Trips pace the city; depth paces the shelves. The schedule: counter 1, supper 2, forge 3, book 4,
study 5, reading (first unread find, or 6), duel (Saber's posting, or 7) — plus the mending, which is
Act 0's. The two backstops sit last on purpose, so inserting a room pushes them rather than colliding.
`quiet = true` lets a room open without announcing its house (every shelf is quiet — a class rung is a
reward the player cannot see), and `announce = {...}` is the one condition under which a quiet room
speaks up anyway. `gate = { any = {...} }` is the event-plus-backstop pattern.

**BUT A HOUSE IS PACED ON ITS CLASS, NOT ON ITS OTHER ROOMS.** A flatly quiet shelf meant the seven
class houses arrived in whatever order the rooms *behind* them were scheduled — fighter last because
**PvP** is last, not because fighter gear is late. **Declaring a class in the Roll — or hiring a body
born to one — opens the house that shelves it, on the spot** (`announce = { declared = true }`, asked
through `Vendor.shelves`, so a crossing opens both its parents' doors). Every trips gate above is
untouched underneath as the backstop: a company that declares nothing sees exactly that schedule. The
mark is **one-way** (`Class.taken`, persisted) — changing class back must never shrink the city.

**ONE BOARD, AND IT IS FULL AT NINE.** `Building.GRID.city` is three columns by three rows with the Rift
taking the taller middle slot: eight ring slots, filled by the Armory and the seven houses. Dropping a
tenth card in on top of another draws two plates over each other, which has shipped once already — so a
new room belongs on a desk, not on the board. (`GRID.houses` and the `district` field are gone with the
second board; `states/houses.lua` is deleted.) See
[docs/adding-content.md](docs/adding-content.md) to add a building, quest, or panel.

**`tools/extract_strings.lua` REGENERATES every conversation it stamps**, so a field it cannot serialize
is a field that silently vanishes the next time anyone adds a line — this ate per-choice `when` on all
seventeen desk options once. Teach `serializeChoice`/`WHEN_KEYS` in the same change that teaches the
resolver a new field; `tests/conversation_spec.lua` holds authored scenes to the tool's own key lists.
