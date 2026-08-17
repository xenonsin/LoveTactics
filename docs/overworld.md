# The Overworld

The board a **day** is run on: ground carved to suit its biome, one objective at the far end of a spur
for every piece of work posted there, stops scattered through it, and one rule about how you get home.
[docs/progression.md](progression.md) owns the campaign's economy — what a run pays and what a level
buys. This owns the run itself.

**A run is a ground, not a quest.** The player chooses *where* to spend the day; every quest the houses
have posted on that ground is standing on the board when the company arrives, each on its own dead end,
ticked off a checklist as they are taken. `Quest.trip` (`models/quest.lua`) is what builds that
descriptor, and the only thing it changes down here is that `map.objective` became `map.objectives`, a
list. A single-quest leg — the prologue's flight, the debut's walk, every descent floor — passes one and
comes through the generator as a list of one, so nothing about those boards moved.

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
| `Overworld:bestBox` | `models/overworld.lua` | Of every window containing the tile, the one with the most ground you can *cross* from it. |
| `Overworld:boxReach` | `models/overworld.lua` | How much of a window is reachable without leaving it — the measure above, and the one below. |
| `Arena.fromGrid` | `models/arena.lua` | Cuts that window, walls what it cannot reach, and hands it back as an ordinary layout. |
| `BattleMap:drawSurround` | `ui/battle_map.lua` | The rest of the map, dark and stopped, and the walls. |

Three consequences worth stating on their own:

- **The window is chosen, not centred.** Meet something at the mouth of a clearing and the board pulls
  into the clearing; get cornered in a corridor and it stays a corridor, because there was nothing
  better within reach.
- **The board is one piece of ground.** The ring is a wall, so a window laid across a ridge or the
  outside of a switchback holds two pockets that the map joins by a path running *round the outside* —
  and inside the lock that path is gone. Boards opened with a boar on one side of it and the company on
  the other, neither able to reach the other, and a `killAll` that could not be finished. So a window is
  now measured by what you can cross **from the tile the fight began on**, and whatever the cut leaves
  stranded, `Arena.fromGrid` walls. A board in pieces has to read as the small board it is.
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
| `weatherEdges` | eats a wandering coastline out of the rectangle the carve stopped against. Skipped for a layout that means its outline square (`ownsEdge`) |
| `placeRivers` → `thinBridges` | wandering water; a river over a path becomes a one-tile bridge. Skipped for a layout that lays its own (`ownsWater`) |
| `placeObjectiveAndGates` | one objective per piece of work: the deepest on a far dead end (~80% of max distance) with the gates + keys before it, the rest on the farthest remaining dead ends, held apart |
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

### The coastline

A carve fills the rectangle it is handed and stops at the margin, so every board used to come out framed
by a wall of exactly even thickness with four right angles in it — which on the open grounds is the most
prominent thing on the screen, and what it says is *architecture*. Six of the seven mean the opposite.

`weatherEdges` gives that frame a **coastline**: the wall's inner face wanders in and out along its whole
length, one to four tiles deep, in headlands and bays. The tiles stay square; the line they make does not.

- **A walk, not noise.** The first version was the cavern carve's own rule — fill the band with noise,
  smooth it with the 5-neighbour test — and on a plain it ate the entire band and handed back a smaller
  rectangle. Noise smoothed against a straight wall does not make a coast, it makes the wall thicker,
  because every tile against the frame already has three solid neighbours before the noise says anything.
  A depth that *walks* carries its own history: two thick here, five there, and neither where the last was.
- **It never sits at 0.** A stretch at depth 0 is a stretch of the original frame, straight and square
  and as long as the walk happened to hold there.
- **Nothing is ever cut off.** A bite is taken only where the trail can still get around it
  (`biteSafe`), and a dead end is spared outright — so the same rule reads as a deep bay on a plain and
  as barely a nibble in a maze, where a 1-wide corridor is all cut vertices. That is what lets one pass
  run over every layout instead of seven.
- **The coast is padding, like the margin.** `generate` adds `EDGE_SURPLUS` tiles to every side before
  handing the rectangle to the carve, so the pass eats surplus rather than play area. Without it
  `. board-report` put the desert's walkable share at 40% against the 55% it was sized to hold, and the
  places a fight can actually go dropped from 4.7 a board to 2.8.
- **The castle keeps its corners** (`Rooms.ownsEdge`). A curtain wall was built square, and a stronghold
  with a coastline for a perimeter is not a stronghold.

## The board's contract

- **The objectives are the only fights you must take, and you need not take any of them.**
  `placeEncounters` keeps combat off the spine, and a loose patrol's beat never touches it either, so a
  wounded company can always route to a boss — or past one, to another. The spine is the **union** of
  the paths back from every end, so the road home is a road *network* and the rule reads the same across
  all of it.
- **Every other fight is optional, and an optional fight should be attached to something worth
  having.** That is `guardBoons`: the boon behind, the fight in the way.
- **Only the deepest approach is gated.** `keyCount` is authored per quest, so summing them across a
  ground would have a player hunting six keys to spend one day. The deepest end keeps its lock and the
  rest stand open — a door that cannot be opened is the one failure a day's ground must not produce.
- **An end that cannot get a spur still gets a tile, and says so.** When the board runs out of dead
  ends, the extra objective takes the farthest unclaimed walkable tile rather than being dropped: work
  the player travelled for must never be silently absent. `. board-report` counts these, because a
  board that keeps doing it is a sizing rule falling behind what a ground can hold. It sits around 8%
  today, concentrated in the room-carve grounds that have almost no degree-1 tiles at all.
- **A fight is never seated where a fight cannot happen.** See the fightability floor below.
- **The map remembers a place; it never remembers a body.** A landmark — a cache, a key, a gate, the
  objective pennant, a camp, a shop, a shrine, a scene — is a fact about the country, so once it has
  been found it stays on the map (`OverworldMap:mapped`, i.e. `seen`) and a detour can be planned from
  across the board. A live fight — combat or elite, un-cleared — draws only while its tile is lit *right
  now* (`OverworldMap:lit`, the same `inVision` test reveal lit it with), and so do patrols, their
  circuits and the hovered-fight readout: where a fight is standing is the question the fog is asked
  for, and a board that listed every one of them ahead would answer it. Put a fight down and its marker
  joins the remembered ground — it is no longer a body, it is a thing that happened here. Routing is
  gated by neither: `pathTo` crosses any `seen` tile, so you can walk home through the dark.
- **The finds are guarded, never the services.** A shop behind a fight is friction; a rest behind one
  compounds exactly the wrong way.
- **Ascent maps opt out.** There combat *is* the route.

## Can a battle happen here

The floor nothing used to check, because nothing used to need it. A locked board is 64 tiles of the map,
and what matters is how much of that is standing room.

| Term | Constant | What it means |
|---|---|---|
| **space** | `Overworld.BOX_OK = 32` | tiles you can *cross to* in the best window containing this one |
| **shape** | `Overworld.BOX_OPEN = 16` | how many of them are *open* — `Overworld:isOpen`, a full 3×3 of walkable around the tile. A corridor scores zero however long it runs |
| **floor** | `Overworld.BOX_MIN = 20` | below this there is nowhere to stand at all |

**Space is not shape, and the second number is the one that matters.** Before the layout pass, *open
ground read 0.0 on every ground in the game* — not one tile on any board had a full 3×3 around it,
because every layout was 1-wide corridors. And the failure had two faces: the loose grounds seated their
fights at ~20 of 64, at or below the bare minimum, while the tight ones scored 34 and were unfightable
anyway. Room for four bodies; no room for a decision.

**Both are floors. For a long time only the first one was.** The layouts were carving clearings
specifically so fights could happen in them — `glades` says so in its own header — and the seating rule
was scoring windows by walkable count, on which a lattice of 1-wide corridors ties a clearing. It could
not tell the two apart, so it seated fights in the corridors at the same rate as in the rooms it had
been given. The measured result: forest seated its fights on **8.4** open tiles of 64, swamp on 7.6, the
colosseum — an oval of bare sand — on 14.8. `Overworld:seatsFight` is now the single seam every pass
that *chooses* a seat asks, and it asks both questions at once, because the bug this exists to prevent
is a caller reading one number and believing it read the other.

Three places choose a seat, and all three had to learn it separately:

- **`placeObjectiveAndGates`** — the fight nobody may skip, and the one that was worst. Every rule about
  an objective is about gateability, a strict dead end is what makes an end lockable, and gateability
  was allowed to be the *only* question: a spur tip is the least arena-shaped tile a board has. Forest
  objectives stood on **3.3** open tiles of 64. Room is a filter over the candidate ends, graded —
  arenas first, merely-standable second, and on a board with neither, the roomiest spur outright, with
  distance no longer deciding because there is nothing left to prefer it over.
- **`placeEncounters`** — a fight dealt onto a corridor looks ahead for a clearing among the candidates
  still free, and demotes to a non-combat stop only if the board has none.
- **`guardBoons`** — where nearly all of the corridor fights actually came from. A spur mouth is the
  likeliest tile on the map to be a hallway, and this pass was lifting fights *out* of the clearings
  `placeEncounters` had chosen and standing them in doorways: a one-end forest board put 92% of its
  fights on guard and 3.9 of 4.5 of them under the shape floor. See the guarded-boon section below for
  what refusing cost.

Three rules that had to be learned by breaking them:

- **A demotion that empties the board is worse than a thin fight.** Refusing every seat on a ground that
  clears nothing does not produce careful placement, it produces a board with no fights on it — which is
  what the desert and the tundra did the first time the rule ran.
- **Refusing to *move* a fight costs nothing.** Which is why `guardBoons` has no such escape hatch: the
  fight is not created by that pass, and declining to move it leaves it in the clearing it was already
  standing in. An unguarded cache is a free pickup; a guarded one fought for in a hallway is the failure.
- **Corridor contact stays legal.** The floor governs what the *generator* chooses, which is a different
  question from what the player walks into. Being caught mid-hall is the price of a mistake.

## The eight grounds

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
| colosseum | `sands` | one oval of floor, the house's furniture on it, the pens beneath |

**Seven of them are countries and one is a building.** The colosseum is the Colosseum's own bowl — the
ground eight of that house's ten slots are fought on — and it is the only board with no route on it at
all: no corridor, no branch, no long way round. What a bout costs is decided by what is standing on the
sand with you and where you were when it started. It needs the same thing `open` needed and gets it
from the fiction rather than from a patch: `placeObjectiveAndGates` insists on a strict dead end, an
oval has no cut vertex anywhere, and the cells under the stands are dead ends that mean something.

It is also the one ground that names its own two ends, through the layout hook `anchors` — the start,
and the *deepest* objective. Anything else the day has posted here takes a cell under the stands, which
is what those dead ends were always for. Found by
shape, the start is the walkable tile nearest the middle and the objective is a far dead end — which
here means beginning in the centre of the sand and holding the bout in a cage underneath, the arena
exactly inside out. So **the card is fought in the middle and the company walks in from the bottom**,
through the gate at the near edge, which is the longest approach the oval has. The gate chain goes with
it: a lock on the road to an objective standing in the open is walked around, so a board whose objective
is not a strict dead end places no keys at all. There are no locked doors in an arena.

Measured across 50 boards a ground, `. board-report 50 all`, **before → after the shape floor reached
the three seating passes**. `ends` is the same open figure for the objectives alone; `under` is fights a
board seated below either floor, and it must reach 0.

| ground | fightable | seat | open | ends | under | guarded |
|---|---|---|---|---|---|---|
| castle | 99.8 → 99.8% | 57.6 → 57.6 | 39.7 → 39.7 | 38.1 → 38.1 | 0.1 → 0.1 | 38.4 → 38.4% |
| colosseum | 63.1 → 63.1% | 51.6 → **54.4** | 14.8 → **19.7** | 16.0 → **17.3** | 4.3 → **1.1** | 56.8 → *17.3%* |
| desert | 80.8 → **82.4%** | 41.0 → **53.9** | 19.2 → **30.4** | 12.1 → **27.4** | 3.6 → **0.0** | 68.5 → *61.6%* |
| forest | 39.0 → **55.4%** | 32.1 → **49.6** | 8.4 → **23.9** | 3.3 → **19.5** | 6.4 → **0.8** | 67.4 → *32.7%* |
| swamp | 37.4 → **53.1%** | 31.9 → **50.1** | 7.6 → **24.0** | 4.0 → **20.3** | 6.8 → **0.7** | 71.5 → *35.9%* |
| tundra | 80.2 → **83.0%** | 39.0 → **53.4** | 14.9 → **27.3** | 7.8 → **24.1** | 4.5 → **0.0** | 68.0 → *61.9%* |
| underworld | 98.5 → **99.2%** | 48.3 → **54.3** | 34.0 → **37.5** | 23.1 → **28.4** | 1.3 → **0.0** | 68.2 → 67.7% |
| volcanic | 93.1 → **93.2%** | 49.7 → **53.0** | 28.2 → **32.5** | 22.5 → **27.7** | 1.7 → **0.0** | 53.9 → *45.3%* |

**The castle does not move, on any column, to the digit.** `rooms` carves no dead ends at all, so
neither the objective filter nor the cache preference has anything to choose between, and every door it
offers was already a room. It is the control in this experiment and it behaves like one.

**The underworld barely moves either, and that is the proof the geometry can give both.** `caverns` is
bellies and necks: its doors are wide, so demanding that a guard be able to fight where it stands costs
it half a point of guarded share. Every ground that lost a lot of guarded share lost it to the same
fact — a gate is a narrow place and an arena is a wide one, and on a maze they are rarely the same tile.

The colosseum is the outlier and worth reading rather than tuning away: its fights are *good* now
(a rendered board seats its thinnest at 20 open and its end at 30), but its boons live in the cells
under the stands and the mouths of those cells are the one narrow thing on the whole ground. It buys
better fights with fewer guarded rewards, on the one board where the fight is the entire point.

The coastline is what moved these off their pre-weathering numbers: a wandering wall touches more of the
ground beside it, so **open** is a few points down on the wide grounds while **sites** — how many
distinct places a fight can actually go — is where it was, which is the one that decides whether a board
is playable.

Three things a layout keeps being taught, each learned by getting it wrong first:

1. **A room over a dead end deletes the dead end.** Carving clearings at any lattice node took the
   forest's guarded share from 60% to 27%, which is the braid rate's failure reached from another
   direction. A glade opens a *through*-node and shrinks its radius to spare any spur end — **by one
   tile, not two.** It reserved two for a while, one for the spur end and one for the cut vertex beside
   it "that a guard has to be able to stand on", and that was right about which tile the guard takes and
   wrong about what standing there means: it reserved that tile as *corridor*, so the layout was
   deliberately putting every door it offered outside the room. At one, the clearing's rim is the cut
   vertex, the spur end keeps its single neighbour, and the fight in the doorway is fought in the glade
   behind it — forest fightability 39.8% → 56.5%, sites 4.6 → 6.5.
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
  punishment; one whose circuit you can read is a puzzle. Both are drawn **in sight only**, like every
  other mark: a body that walks is the last thing a map could honestly remember, so the read is a thing
  you take while you can see it rather than a tracker you keep across the board.

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

**One rest per six stops is a density, and a density is only right where the board is the run.** A
quest board's leg is: the party goes home from it, the hub makes them whole, so how much refund the
board owes really does track how big it is — eleven stops buys two camps, one per 2.3 fights. A descent
floor is a *segment*. There are fifteen of them and no hub in the stack, so its stop count says nothing
about the length of the run it belongs to, and the same fraction handed a 14–18 stop floor **three**
camps. Three is not a little more than one: camps compound, so three return about 53% of what a floor
cost against 25% for one, and fifteen floors of that is the free attrition `CAMP_SHARE` was cut to fix,
reintroduced one board lower. So a map may pin a flat `count` per kind via `params.guarantee`, overlaid
on the defaults rather than replacing them (`Descent.FLOOR_RESTS = 1` — the breather before the stair).
The two freed stops did not vanish: they fell to the combat-share cap, taking a floor from 8.5 fights
to 10.1.

## Getting out

**Walking out is free.** The company goes home with everything it picked up, and the only thing the day
cost is the day. **Losing a fight is the whole of the risk**: a wipe takes `Player.WIPE_LOSS` — three
quarters — of the run's gold and forging stock, and leaves the items, the wounds, and everything carried
in (`Player.loseHaul`, pinned by `tests/extraction_spec.lua`).

**This rule inverted twice, and both old ones are worth recording.** First: *the objective was the only
extract*, a wipe and a walk-out were the same event, and both restored the company from an entry
snapshot — so a lost run was worth exactly nothing. That was correct while the board was a one-way trip;
without it, forfeiting the moment a run had paid out was the optimal way to bank a haul.

Then the objective stopped being an exit at all. A day's ground carries several of them, and a player
may clear none — so extraction moved to **leaving**, whichever way you leave. What that fixed on the way
past: the caches' ore was banked by `Quest.complete`, so walking out with a full pack paid nothing,
which said the exact opposite of the line above it. The ore and the Cafe's supper are the day's rather
than any one quest's, and both settle at the exit (`game:bankHaul`). Clearing one piece of work pays
*that* work — its gold, its relic, its house's standing — and leaves you on the map with the rest still
out there.

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

**And then the ceiling moved again, downward, on purpose.** `boons gateable` is the ceiling on how many
boons *can* be guarded; it is not the ceiling on how many *should* be, because a guard is a fight and a
fight has to happen somewhere. Once `guardBoons` had to seat on ground that clears the shape floor, the
achieved share fell on every maze-like ground — forest 67.4% → 32.7%, swamp 71.5% → 35.9%, the colosseum
56.8% → 17.3% — while the wide grounds barely noticed (underworld 68.2% → 67.7%). The trade is stated
plainly because it is a trade: **a gate is a narrow place and an arena is a wide one**, and where a board
cannot offer a tile that is both, it now keeps the fight in the clearing and lets the cache sit loose.

Two things soften it, both of them pairings made *earlier* rather than rules relaxed later:

- `placeCaches` prefers dead ends whose one neighbour can hold a fight, so the boons land where a
  pairing is possible instead of being sorted out afterwards (desert +10 points, tundra +15).
- `glades` shrinks a clearing by one tile rather than two (above), so a maze's doors are rims of rooms.

Do not "fix" the remaining gap by relaxing the seat floor. The share is a structural nicety; the fight
being playable is the contract.

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
- **The castle and the volcanic guard ~38-45% of their boons** against 62-68% on the wide grounds. Both
  carve wide connected ground, so the spine runs through most of it and combat is kept off the spine.
  Preferring deeper ground for caches took the castle from 18% to 38%; the rest is layout tuning
  (branchier halls, more leaf chambers), not a rule change. **Raising the guard's reach does not help** —
  measured flat at 28 tiles, so the limit is that no *off-spine* gating tile exists, and the beat-guard
  idea would have to seat a guard on the spine, which breaks the one contract the board cannot lose.
- **The maze grounds now guard only ~33-36% of their boons**, and the colosseum 17%, because a guard has
  to be able to fight where it stands. That is the trade recorded above and it is deliberate; what is
  still open is whether `glades` and `sands` can be carved so that more of their doors are rooms, which
  is layout work rather than a rule change.
- **The forest and the swamp still seat ~0.8 fights a board under the shape floor**, the worst two of
  the eight, and it is the same fact as their fightability sitting near 55% while every other ground is
  past 80%: half their trail is warren. The escape hatch is doing its job (a board that clears nothing
  still gets fights) — the layouts have not caught up.
- **Every offer on the board pays the same currency.** Materials from a cache, materials and gold from
  a fight — so the board is N copies of one offer at different prices, and route *choice* cannot really
  exist until two boons can differ in kind. The largest open item here, and it is a content question
  rather than a generator one.
- **No biome has a tileset drawn yet** — all seven fall back to coloured rects. See
  [docs/art-assets.md](art-assets.md).
