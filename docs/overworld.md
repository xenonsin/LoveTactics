# The Overworld

The board a quest is run on: ground carved to suit its biome, an objective at the far end, stops
scattered through it, and one rule about how you get home. [docs/progression.md](progression.md) owns
the campaign's economy — what a run pays and what a level buys. This owns the run itself.

Every number below is reproducible with `& "E:\LOVE\lovec.exe" . board-report [n] [all | biome=ID]`,
which rolls `n` boards with the campaign's default map params and reports what the generator actually
laid down. `& "E:\LOVE\lovec.exe" . board-render <biome> [seed]` draws a single board twice — as ground,
and as fightability — because a mean cannot show you a shape. The rule from [docs/roadmap.md](roadmap.md)
applies with force here: **do not hand-derive a count from the constants, roll the boards and read what
they say.** This document exists partly because that was not done once, and the wrong number was carried
for a whole pass.

## One map

**A fight is taken on the tiles the company walked over.** There is no separate arena. When one begins
the board locks an 8×8 window of the map, walls close on the ring around it, and the company unfurls
onto ground that was already there.

That is possible because the two grids were already the same grid: 32 logical pixels a cell on the map,
64 in the arena, and eight tiles at double scale is the 512-pixel board battles have always occupied. So
the lock is a camera transform rather than a second board, and no ability range, TTK or AI weight had to
be re-tuned to allow it.

| Piece | Where | What it does |
|---|---|---|
| `models/terrain.lua` | one table | The ground, for both layers. Neither may hold a second opinion. |
| `Overworld:bestBox` | `models/overworld.lua` | Of every window containing the tile, the one with the most walkable ground. |
| `Arena.fromGrid` | `models/arena.lua` | Cuts that window and hands it back as an ordinary layout. |
| `BattleMap:drawSurround` | `ui/battle_map.lua` | The rest of the map, dark and stopped, and the walls. |

Three consequences worth stating on their own:

- **The window is chosen, not centred.** Meet something at the mouth of a clearing and the board pulls
  into the clearing; get cornered in a corridor and it stays a corridor, because there was nothing
  better within reach.
- **Your side is the side you arrived from.** A rolled board had no outside and so no "your side";
  `deployZoneFor`'s fixed block at the bottom centre existed because there was no better answer.
- **Two words became two tiles.** The map's `forest` was impassable wood and the board's was a tree you
  walk through for cover, so `thicket` is the wall and `forest` is the cover — and a glade wants both at
  once. The map's `water` was a barrier and the board's a wadeable ford, so `river` is the barrier and
  `water` stays the ford. Merge either pair the other way and something good dies: every river becomes
  crossable and bridges stop being doors, or the shallows become walls and take conduction with them.

### What that deleted

`Overworld:groundAt` voted over a 5×5 neighbourhood to *guess* what the ground was, and
`Arena.GROUND_PROFILES` picked scatter ranges so a rolled board would resemble it. The resemblance is
the thing now — the channel down the flank **is** the river, in the place it runs — so both are gone.

One guarantee went with them and was rehomed rather than lost: `band = "cross"` promised a crossing
exactly one free ford, tuned so water could never cut a board in half. That promise belongs to whichever
layout lays the water, and moving it immediately found a bug the old spec could not see, because it was
testing a board that no longer gets built — the tundra's leads sealed lobes off, 454 of 752 walkable
tiles unreachable on a board that passed every other check. `Floes.ford` repairs the crossings after all
the water is down.

## The generation pipeline

`Overworld.generate` (`models/overworld.lua`), in order:

| Pass | What it does |
|---|---|
| `layout.carve` | **per biome** — see The seven grounds below |
| `placeRivers` → `thinBridges` | wandering water; a river over a path becomes a one-tile bridge. Skipped for a layout that lays its own (`ownsWater`) |
| `placeObjectiveAndGates` | objective on a far dead end (~80% of max distance), gates + keys before it |
| `placeCaches` | material caches take the spur ends **first**, then the deepest ground off the road |
| `placeEncounters` | fights and texture fill the ground between them |
| `guardBoons` | re-seats fights so most rewards stand behind one |
| `pruneDeadStubs` | trims spurs that ended in nothing (no RNG) |
| `assignEncounterTiers` | the pips the fog shows, drawn last so geometry never shifts |
| `placePatrols` | lifts a share of the fights off their cells onto beats (opt-in) |

**Swap the carve, keep the pipeline.** Everything below the carve works on an arbitrary walkable graph
— it is all BFS over `pathNeighbors` — which is why seven grounds is a tractable amount of work rather
than seven generators. `deriveDims` sizes the grid to the content and to the layout's own `density`. An
authored board (`Overworld.fromLayout`, `data/overworld/*.lua`) skips the lot.

## The board's contract

- **The objective is the only fight you must take.** `placeEncounters` keeps combat off the
  objective→start spine, and a loose patrol's beat never touches it either, so a wounded company can
  always route to the boss.
- **Every other fight is optional, and an optional fight should be attached to something worth
  having.** That is `guardBoons`: the boon behind, the fight in the way.
- **A fight is never seated where a fight cannot happen.** See the fightability floor below.
- **The finds are guarded, never the services.** A shop behind a fight is friction; a rest behind one
  compounds exactly the wrong way.
- **Ascent maps opt out.** There combat *is* the route.

## Can a battle happen here

The floor nothing used to check, because nothing used to need it. A locked board is 64 tiles of the map,
and what matters is how much of that is standing room.

| Term | Constant | What it means |
|---|---|---|
| **space** | `Overworld.BOX_OK = 32` | walkable tiles in the best window containing this one. A fight is never *seated* below it |
| **shape** | `Overworld:isOpen` | a tile with a full 3×3 of walkable around it. A corridor scores zero however long it runs |
| **floor** | `Overworld.BOX_MIN = 20` | below this there is nowhere to stand at all |

**Space is not shape, and the second number is the one that matters.** Before the layout pass, *open
ground read 0.0 on every ground in the game* — not one tile on any board had a full 3×3 around it,
because every layout was 1-wide corridors. And the failure had two faces: the loose grounds seated their
fights at ~20 of 64, at or below the bare minimum, while the tight ones scored 34 and were unfightable
anyway. Room for four bodies; no room for a decision.

Two rules that had to be learned by breaking them:

- **A demotion that empties the board is worse than a thin fight.** Refusing every seat on a ground that
  clears nothing does not produce careful placement, it produces a board with no fights on it — which is
  what the desert and the tundra did the first time the rule ran.
- **Corridor contact stays legal.** The floor governs what the *generator* chooses, which is a different
  question from what the player walks into. Being caught mid-hall is the price of a mistake.

## The seven grounds

Each biome names a `layout` (`data/biomes/<id>.lua` → `models/layouts/<id>.lua`).

| Ground | Layout | What it is |
|---|---|---|
| forest | `glades` | the maze, opened into clearings where trails meet |
| swamp | `drowned` | the forest's carve, a third of the trail under shallows |
| castle | `rooms` | chambers and halls, cut by recursive splits, joined as a tree |
| underworld | `caverns` | cellular automata: wide bellies, pinched necks |
| volcanic | `rifts` | wide fractures meeting at fallen-in chambers |
| desert | `open` | a plain with ridges, and one walled ruin |
| tundra | `floes` | open flats quartered by meltwater, fords for doors |

Measured across 20 boards a ground:

| ground | fightable | sites | seat | open | under | guarded |
|---|---|---|---|---|---|---|
| castle | 100.0% | 4.5 | 57.0 | 40.2 | 0.00 | 38.0% |
| desert | 100.0% | 4.8 | 51.8 | 24.9 | 0.10 | 65.2% |
| forest | 91.6% | 5.6 | 41.0 | 12.3 | 0.60 | 62.4% |
| swamp | 86.8% | 3.4 | 36.1 | 7.3 | 1.30 | 65.6% |
| tundra | 100.0% | 5.5 | 55.1 | 25.2 | 0.00 | 65.6% |
| underworld | 100.0% | 5.9 | 62.5 | 51.5 | 0.00 | 71.4% |
| volcanic | 99.9% | 2.9 | 57.4 | 39.1 | 0.00 | 21.8% |

Three things a layout keeps being taught, each learned by getting it wrong first:

1. **A room over a dead end deletes the dead end.** Carving clearings at any lattice node took the
   forest's guarded share from 60% to 27%, which is the braid rate's failure reached from another
   direction. A glade opens a *through*-node and shrinks its radius to spare any spur end.
2. **A chain makes every room spine.** The castle's halls were a chain first, and guarded 1.6% of its
   boons — one route through every chamber means every doorway is on the objective road, and combat is
   kept off it. A tree branches, and the leaves are dead ends.
3. **A carve that has to be repaired afterwards is usually carved wrong.** The volcanic fractures each
   started at a random point and were stitched together after; the stitching corridors were then peeled
   back one tile per pass by `pruneDeadStubs`, which read as a hang. Each fracture starts on an existing
   one now, so the network is connected by construction.

**The size cap grew, 27×19 → 37×25 of play area.** The old reasoning was right for the board it was
written for — *every tile a choice, not a marathon warren* — but a stop was a marker then. A board
seating four or five fights has to contain four or five rooms with trail between them, and at the old
cap the compactness rule and the fightability floor were in direct conflict. Most of the added area is
room, which is crossed in three steps, rather than corridor, which was the marathon the cap guarded
against.

## The fights that walk

`models/patrol.lua`. A share of the board's combat lifts off its cell onto a beat.

**One player step is one patrol step.** Not `dt`. It keeps the board a thing you can stand still and
read, it keeps a run reproducible enough to spec and to resume, and it prices the walk in the board's own
currency — sweeping a spur costs six steps, and six steps is six patrol moves somewhere else. It also
means "the map locks during combat" needed no code: nothing ticks except on your step, and during a fight
you are not stepping.

- **Beat → Alert → Return.** Alert fires on line of sight down a corridor; the leash runs out and it
  walks home.
- **Never faster than the party.** Pace is a divisor on the tick, so rank buys *reach* rather than speed.
  That single cap is what keeps the contract: a company that keeps walking away cannot be caught in open
  corridor, so the only place a patrol can corner you is a dead end you chose to enter.
- **A guard's beat is its cut set** — exactly the tiles whose removal puts its boon out of reach. A long
  corridor gives it a real beat; a single-tile cut set gives a sentry that stands still. The guarantee
  survives by construction, and `tests/patrol_spec.lua` walks the board to prove it.
- **A loose beat never touches the spine.** Alert may cross it, because you can outwalk a patrol and a
  chase that stops at an invisible line is worse than no chase.
- **The circuit is drawn**, with the tile it occupies next. A moving fight you cannot predict is a
  punishment; one whose circuit you can read is a puzzle.

**Where it touched you is where it deploys.** A fight the company walks into opens as two lines facing
each other; one that caught them opens with the enemy on the side it arrived from — so being caught deep
in a spur puts it between the company and the way out. Same composition, at the same tier, as a
completely different problem, decided by how the approach was handled rather than by a roll. That is what
makes a moving fight worth having at all.

Patrols are **opt-in at the generator** (`params.patrols`). Lifting a fight off its cell changes what
`cell.encounter` means, and many specs read exactly that to assert what *placement* did; switching it on
underneath them would have every one read low, which is a change in the instrument rather than in the
board.

## What a run costs

The board's whole risk structure rests on a fight costing something that outlives it. For a long time
it did not, and that is worth stating plainly because every other rule here was built on top of the
gap:

> A camp restored **everything**, one was guaranteed every six stops, nothing priced time, and the only
> durable cost of a fight was a body actually going down. So any fight the company could win was free,
> and "should I take this detour" had one answer.

Two things fix it, and they are deliberately different in kind.

**`Player.CAMP_SHARE = 0.5`** — a camp gives back half of what is *missing*, never the whole of it
(`Player.camp`). A share rather than a flat amount, for two reasons: it scales with the company without
reading a level, and it **compounds** — halving a gap twice leaves a quarter — so a long board grinds
the company down even though every camp is generous. The hub still heals whole; going home is what
makes a company whole.

**Wounds** (`models/wound.lua`) cap the hub's refill, and cap the camp too. A camp can never top
someone past what the hub would give them.

The prior swing is worth recording: the rest guarantee originally **no-opped entirely** (it read a
random-draw weight as a density floor), so attrition was one-way and no board offered a refund. Fixing
that was right. It landed on a full refund at a guaranteed density, which is the other end.

## Getting out

**Walking out is free.** The company goes home with everything it picked up, and the only thing the day
cost is the day. **Losing a fight is the whole of the risk**: a wipe takes `Player.WIPE_LOSS` — three
quarters — of the run's gold and forging stock, and leaves the items, the wounds, and everything carried
in (`Player.loseHaul`, pinned by `tests/extraction_spec.lua`).

**This rule inverted, and the old one is worth recording.** It used to be that *the objective was the
only extract*: a wipe and a walk-out were the same event and both restored the company from an entry
snapshot, so a lost run was worth exactly nothing. That was correct while the board was a one-way trip —
without it, forfeiting the moment a run had paid out was the optimal way to bank a haul.

It stopped being correct when the day became the unit. With a voluntary exit keeping everything, a total
wipe penalty turns the last fight before you turn back into an all-or-nothing coin flip, and the
sensible play is to leave after the first cache and never risk a second. A **majority** loss keeps the
bet live in both directions: one more spur risks most of what you are carrying rather than all of it, so
a bad roll is a bad day rather than a wasted one.

Three things a wipe deliberately does not touch:

- **The items.** A sword out of a chest is carried by a body, and the bodies came home. It is also what
  keeps a wipe from undoing the one reward the player can see and name.
- **The wounds.** An injury outliving the run that caused it is the whole mechanic (`models/wound.lua`).
- **What was brought in, and anything spent.** Only *gains* are at risk, so a company that spent more at
  the Merchant than it found walks home with its purse intact rather than being billed the difference.

The entry snapshot survives, because it is still how the loss is *measured* — whatever is held now minus
whatever was held then is what this run found. It is no longer what the company is restored to.

A **descent** still asks before you leave, and still means it: there is no city on the other side of one,
so climbing out early gives up the company as well as the haul.

### Overworld items

A small, deliberately open category: items whose whole effect is on the board. One shape so far
(`models/player.lua`, Overworld items):

| Shape | Field | Item | What it does |
|---|---|---|---|
| **Passive** | `visionRadius` | `utility_torch` | widens the fog while carried, spent by nothing |

Read off the roster's grids **and** the stash, because a board item belongs to the company rather than
to a body.

A **spent** shape lived here briefly: `extract`, on a Smoke Bolt, bought a walk-out that kept the haul
back when every exit but the objective voided it. Walking out is free now, so the charge had nothing
left to buy and went with the rule that justified it. A future spent item wants its own field and its
own reason.

## The arc

A board should get harder as it runs. It did not, and the reason is worth keeping because it is easy to
re-commit: **`assignEncounterTiers` runs after every placement pass and only stamps a number on what is
already there.** An elite was as likely on the doorstep as at the gate; the "difficulty ramp" was a
label on a flat board. Measured mean tier by fifth ran `2.66 / 2.62 / 2.50 / 2.70 / 2.85` — noise.

It was worse than a placement problem. `encounter_elite`'s weight was `ctx.prestige`, unbounded, against
the fixed 2–3 the ordinary road fights carried. Past prestige ~6 the elite *was* the ordinary fight —
measured at **76% of every board's combats** — so there was nothing left for it to be tougher than.

Three changes, at three levels:

1. **The weights saturate.** `encounter_elite` caps at 3, `encounter_forsworn` at 2. Growing more
   common with renown is right; growing without bound is not a rate, it is a replacement.
2. **Placement carries the arc.** `ELITE_MIN_DEPTH = 0.5` — an elite rolled onto the near half is
   re-seated as an ordinary fight. `ELITE_SHARE = 0.25` caps the rank as a fraction of stops, so no
   pool weight can make elites the ordinary case however a blueprint is authored. Both are expressed
   as *demotions*, so the encounter count and the quest's authored pool are untouched — the same move
   the spine and combat-share rules already make. `guardBoons` respects the depth rule when it moves a
   fight, or it would quietly undo the arc it was just given.
3. **The tier ramp is a gradient.** Depth in thirds gives all three pips to position, and rank is +1 on
   top. The random spike dropped 0.25 → 0.12, because at a quarter it was as strong as the depth term
   it was decorating.

Measured after: `1.17 / 1.55 / 2.19 / 2.69 / 3.00`.

## The braid rate, and how the guarded-boon knob was misdiagnosed

`Overworld.BRAID = 0.20`. This is the most load-bearing constant on the board and the least obvious.

`guardBoons` targets `GUARDED_BOON_SHARE = 0.8`. It was achieving **30%**, and the shortfall was
recorded for a whole pass as a shortage of *fights* — "what limits guarding is the SUPPLY OF FIGHTS".
That was wrong, and only measuring caught it. At the old braid rate of 0.55:

| | |
|---|---|
| dead ends per board | **2.0** — against 4.5 caches asking for one |
| boons with a real cut vertex beside them | **32.7%** |
| boons actually guarded | 29.7% — i.e. **92% of what the geometry permitted** |
| loose fights standing around unused | **3.1 per board** |

The pairing pass was working almost perfectly. The board had nowhere to put a guard. **Braiding
destroys exactly the geometry the offer rule needs**: a dead end is what a boon sits on and a cut vertex
is what a guard stands on, and every braid removes one.

The slog that braiding exists to prevent is handled better by `pruneDeadStubs`, which removes only the
spurs with *nothing at the end* — the actual complaint. Lowering the rate also makes the board slightly
*tighter*, since a braid carves wall into path and `deriveDims` fixes the footprint either way.

| At `. board-report 300` | braid 0.55 | braid 0.20 |
|---|---|---|
| dead ends | 2.0 | **3.9** |
| boons gateable | 32.7% | **72.6%** |
| boons guarded | 29.7% | **56.8%** |
| cache craft stock | 12.5 | **13.9** |

Material income goes **up**, because a guarded cache pays a bonus and far more of them are now guarded.

**The ratio was the wrong lever.** Cutting `cacheTarget` to force boons-per-fight toward 1.0 was tried
and rejected by measurement: it dropped material income by a third *and* lowered the absolute number of
guarded boons, because it removed boons rather than adding pairings. `boons per fight` is reported as
context only. `boons gateable` is the real ceiling.

Do not raise the braid rate without re-running the report.

## The city as the board's other half

Two things landed here that are about the run without being on the board.

**The Descent is the post-game.** It is a standalone mode — musters its own company, banks nothing,
levels on its own per-character XP — which is why the city was rightly the wrong door for it. But it
sat in the debug column, so a finished campaign had nowhere to land. It now appears on the main menu
once `Player.hasFinishedCampaign` is true, banked at the `endsCampaign` seam rather than at New Game+
(a player who watches the credits and returns to the menu has still beaten the game). It survives New
Game+: what the player has done cannot un-happen.

**A house may have a verb of its own.** Every door in the city did Buy and Sell and nothing else, which
is why the town stops changing once the last building opens — a new shop is only ever more rows. A
vendor may now declare a `service`, rendered as a third tab (`models/vendor.lua`, Services).

The Undercroft declares the first: the **Fence**. Hand over a piece, name what you want back of about
the same worth, pay a fee. Greed's verb exactly — nothing is made, nothing is destroyed, and the house
takes its cut. It is also the service an extraction game most needs, since a run that pays out in gear
produces duplicates by construction.

- It is a **choice, not a roll** — the player picks from the offers. A random return would make it a
  slot machine, and the board is already the slot machine.
- `SWAP_FEE = 0.6`, deliberately above the 50% a sell-back pays: a swap returns an *item* at the grade
  given up, with no second trip and no waiting on a gate. Under 50% the Sell tab would be decorative at
  the one house that has both.
- `SWAP_BAND = 0.35` — a band, not an exact match, because prices are derived from grade
  ([docs/shelf.md](shelf.md)) and land on arbitrary numbers.
- A service does **not** touch `item.level` and bills no materials. It is not a second Forge; see
  `models/vendor.lua`'s header for why that door stays closed.

**The other six houses have no service yet, and that is an authoring job rather than an engine one.**
The seam is a data field. Sketches only, deliberately unbuilt: the Crucible appraising a sealed find,
the Arcanum reading an unknown discipline off a piece, the Cafe standing a round.

## Known debt

- **Boons still outnumber fights ~1.4:1**, so even at 73% gateable the guard pass tops out around 57%.
  Closing the rest means more fights per board, which is a difficulty decision rather than a
  generation one.
- **No adjacency rule between stops of the same kind.** The only spacing is Manhattan ≥ 2 between any
  two encounters, so two crossroads in a row or a merchant beside a rest are both legal.
- ~~**Nothing prices time on the board.**~~ **Closed by the step clock.** Every step the company takes
  is a step something else takes, so sweeping every spur costs patrol moves. The hunger clock this entry
  used to reach for was the wrong shape; the board's own currency turned out to be the right one.
- **The castle and the volcanic guard ~20-38% of their boons** against 62-71% everywhere else. Both
  carve wide connected ground, so the spine runs through most of it and combat is kept off the spine.
  Preferring deeper ground for caches took the castle from 18% to 38%; the rest is layout tuning
  (branchier halls, more leaf chambers), not a rule change. **Raising the guard's reach does not help** —
  measured flat at 28 tiles, so the limit is that no *off-spine* gating tile exists, and the beat-guard
  idea would have to seat a guard on the spine, which breaks the one contract the board cannot lose.
- **The swamp still seats ~1.3 fights a board under the fightability floor**, the worst of the seven.
- **Every offer on the board pays the same currency.** Materials from a cache, materials and gold from
  a fight — so the board is N copies of one offer at different prices, and route *choice* cannot really
  exist until two boons can differ in kind. The largest open item here, and it is a content question
  rather than a generator one.
- **No biome has a tileset drawn yet** — all seven fall back to coloured rects. See
  [docs/art-assets.md](art-assets.md).
