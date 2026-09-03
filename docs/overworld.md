# The Overworld

The floor a **descent** is walked on: a small grid of places, an end for every piece of work standing
down here, and one rule about how you get home. [docs/progression.md](progression.md) owns the
campaign's economy — what a run pays and what a level buys. This owns the floor itself.

**One cell is one place, and it holds at most one thing** — a fight, a find, a camp, a gate, a piece of
posted work, or the stair. Stepping onto it *is* arriving. A blocked cell is not a wall you walk around;
it is somewhere that is not there, and what it buys is the floor's silhouette and its chokepoints.

Every number below is reproducible with `& "E:\LOVE\lovec.exe" . board-report [n] [descent [floor=N]]`,
which rolls `n` floors with the mode's own params and reports what the generator actually laid down.
`& "E:\LOVE\lovec.exe" . board-render <biome> [seed] [size=N]` draws a single floor twice — as ground,
and as step-distance from the way in — because a mean cannot show you a shape. The rule from
[docs/roadmap.md](roadmap.md) applies with force here: **do not hand-derive a count, roll the floors and
read what they say.** This document exists partly because that was not done once, and the wrong number
was carried for a whole pass.

## What this replaced, and why it had already lost its argument

For a long run of passes a board was a **rectangle with corridors carved through it**: eight per-biome
carves (`models/layouts/`), a coastline eaten out of the frame, rivers laid over it with bridges thinned
to one tile, barren spurs pruned, and a share of the fights lifted onto patrol beats. It was carefully
built and every invariant held. A descent floor came out **40×40 — 931 walkable tiles carrying thirteen
stops, one every thirty tiles, with the stair a forty-step walk from the door.** What it produced was
transit.

Two things had already knocked the props out from under it.

**The fight stopped reading the map.** For a stretch a battle was fought on an 8×8 *window of the map
itself*: the lock closed around the tile the fight began on, walls fell on the ring, and the company
unfurled onto ground that was already there. It bought real continuity and it cost shape — the ground
you happen to be standing on when something finds you is not an arena, and the one fight nobody may
decline sits on a strict dead end by rule, which is the least arena-shaped tile a board has. So a fight
builds its own board now (`models/arena.lua`), and the overworld under it contributes the biome and
nothing else. Which means the tile-level terrain the carve existed to produce **feeds nothing
mechanical.**

**The room had already become the unit.** The lattice carve that came last put one encounter in each
chamber, lit a chamber whole on entry, drew the floor as a plan of its chambers, and — explicitly —
gated on the room:

> `guardBoons` wants a tile whose removal cuts a boon off… A board of rooms has none — every interior
> tile has four walkable neighbours… **The gate was never going to be a tile on a board like this. It is
> the room.**

A 40×40 floor of ten-tile sectors is a 4×4 grid of places wearing 1,600 cells. The grid is that
admission, finished.

### What survived, and why

- **One terrain table** (`models/terrain.lua`). `river` means one thing on both surfaces, and the arenas
  still use every type in it. The map now uses exactly two: `path` is a place, `thicket` is a cell that
  is not there. Both are the tileset's own names, which is why walkability, the renderer and the save
  needed no edit.
- **Every placement pass**, because they were always graph-generic: the caches, the stops, the
  guarantees, the combat budget, the tier arc. They ran on BFS over `pathNeighbors` then and they run on
  it now. **Swap the shape, keep the pipeline** was the old rule for adding a ground; it turned out to be
  the rule for deleting all eight.
- **One connected region, owned by the pass that shapes the floor.** Nothing downstream repairs it:
  `computeStart` takes a place without asking which piece it is in, so a floor in two pieces is silently
  a floor half the size and reads as a small floor rather than as a bug.
- **The fog**, adjacency-wide — see below.
- **Gates and keys**, which are no longer hoped for. See The gate is built, not found.

### What went with it

The eight layouts and the layout contract, the coastline (`weatherEdges`), the rivers and bridges, the
corridor carvers, `decorate`, `pruneDeadStubs`, `guardBoons`, the patrols (`models/patrol.lua`), the
room layer, and line-of-sight (`models/vision.lua`) — shadowcasting needs walls to cast against and
there are none. Roughly **5,900 lines** left the map layer.

Two of those are worth naming as losses rather than removals:

- **A fight guarded nothing for a while, and that was wrong.** `guardBoons` stood a fight in front of
  most rewards; at the cut it was putting 38% of a floor's boons behind one, and it went with the
  geometry it read. The replacement argument was that a fight pays for itself in spoils and levels —
  Dream Quest's own model. That turned out to be true and not enough: *a fight that pays for itself is a
  fight you take when you feel like it*, so a floor read as a shopping list. See **The fights that block
  the way**.
- **The ambush is gone with the patrols.** "Where it touched you is where it deploys" needed a fight
  that could walk up behind you, and being caught deep in a spur is not a thing a grid of places can do
  to you. What survives is the half that did not need a beat: the company deploys on the side they
  walked in from, read off the step that brought them (`ui/overworld_map.lua`'s `entryEdge`).

## The generation pipeline

`Overworld.generate` (`models/overworld.lua`), in order:

| Pass | What it does |
|---|---|
| `hollow` | blocks about a quarter of the cells, refusing any block that would strand a place |
| `longestWalk` | the way in and the guardian are the two ends of the floor's longest walk |
| `placeObjectiveAndGates` | the stair on the farthest place, the rest of the day's work on the farthest remaining, held apart |
| `chokeAndGate` | blocks the deepest end's other approaches until one remains — that cell is the gate |
| `placeKeys` | keys strictly nearer the way in than the gate |
| `markSpine` | every end's walk back to the start, unioned — the road combat is kept off |
| `placeCaches` | the finds take the dead ends **first**, then the deepest ground off the road |
| `placeEncounters` | the stops fill the places between them, no two sharing a side |
| `blockRoutes` | most of the fights move onto the one way through something |
| `freeTheDoor` | ...and come back off it until the way in has somewhere to go that is not a fight |
| `assignEncounterTiers` | the pips the fog shows, drawn last so geometry never shifts |
| `placeSecrets` | ...and the places that read as absent until somebody looks |
| `placeExit` | the way back up, on the place the company walked in on |

`deriveDims` sizes the grid when a caller does not pin one; a descent floor always pins
(`Descent.floorDims`). An authored floor (`Overworld.fromLayout`, `data/overworld/*.lua`) skips the lot.

### The silhouette

`Overworld.BLOCK_SHARE = 0.25`. Both halves of that matter. Blocked cells are what give a floor a shape
instead of a rectangle, and — far more load-bearing — they are the only source of a **chokepoint**: on a
full grid every interior cell has four neighbours, nothing is an articulation point, and a gate could be
walked around. That is the same failure the room carve hit from the other direction.

**The guarantee is affordable outright rather than argued.** A floor is a hundred and forty-four cells
at the very deepest, so every candidate block is tested by re-flooding the whole floor and counting.
A hundred-odd floods of a hundred-odd cells is nothing, and it means the invariant holds by construction
on every seed rather than on the seeds a spec happened to roll. A quarter rather than a third because the pass *refuses* a block that
strands anything, so a share pitched too high does not make a more interesting floor — it makes a pass
that spends its candidates being refused and stops wherever it happens to.

### The door and the guardian are the two ends of the longest walk

`Overworld:longestWalk` picks the rim place with the deepest floor behind it; the guardian then takes the
far end of that same walk. **The floor asks for its whole depth, rather than for whatever depth an
arbitrary door happened to open onto.**

It was a coin flip — the way in was a *random* rim place and the guardian was the farthest place from
*that* — so the crossing was the eccentricity of an arbitrary cell rather than the floor's own diameter.
`. board-report` reports both, and the gap was real:

| | crossing | longest the floor has | |
|---|---|---|---|
| random rim start | 17.85 | 20.10 | **89%** |
| longest walk | 20.10 | 20.10 | **100%** |

Floor 15 the same: 24.45 of 24.50. About a ninth of every floor's depth was going unused, and more than
that on a roll that put the door mid-edge.

**The rim constraint stays and is not free** — the true diameter may run corner to corner through the
middle. A floor is a place you walk *into*: entering at the middle would put the stair three steps away
in every direction and leave no depth to spend. On these silhouettes it costs nothing anyway, because the
diameter's endpoints are on the rim.

**The tie is broken by the seed, not by the scan**, and that is the half that took a second pass to get
right. Several rim places usually reach the same maximum, so taking the first one found resolved every
tie the same way — and the scan runs outward from `y = 1`. Measured: **four starts in five landed on the
top row**, and every floor became a walk downward. A positional tie-break is not neutral, it is a bias
with no author. Choosing among the tied places with the floor's own rng restores the variety the random
start had — which is the only part of it worth keeping — while the depth stays maximal.

### The gate is built, not found

A gate on open ground is not a gate: lock a cell with two ways round it and the player has spent a key
hunt on a door they can walk past. The old board asked a maze for an articulation point and took what it
got — and where it got nothing, the chain was skipped and the key bought nothing.

`chokeAndGate` blocks the deepest end's other neighbours one at a time, keeping only blocks that leave
the floor in one piece and never blocking the last one. What is left is a cell whose removal genuinely
cuts the end off, and that cell is the gate. A chain of K gates walks back from it, and **each link has
to earn the same guarantee** — `Overworld:cuts` asks the question directly, with the cell blocked, rather
than inferring it from a degree count. `tests/floor_grid_spec.lua` holds it to all of that on thirty
seeds: one approach, the approach is the gate, blocking it cuts the end off, and the key is on the near
side.

**A descent floor sets `keyCount = 0` and takes none of it** (`Descent.floorQuest`: *a floor is not a
lock puzzle: the stair is always reachable*). That is an authored call about the descent, not a limit of
the shape — the machinery is there and pinned the moment a floor asks for it.

## The floor's contract

- **On a campaign ground, the objectives are the only fights you must take, and you need not take any of
  them.** `placeEncounters` keeps combat off the spine — the union of the walks back from every end — so
  a wounded company can always route to an end, or past one, to another.

  **A descent floor opts out, and always did.** It sets `ascent`, where *combat is the route*: fights may
  stand on the spine, and `blockRoutes` puts most of them across the one way through something. That is
  the whole difference between a day out and a descent — down here the floor is what you have to get
  through, not a set of offers you pick from. What survives for both is the half that matters after a bad
  fight: **a fight you have cleared is a place you can walk through**, so the road back to the way up can
  never be shut behind you.
- **Two kinds of end, two marks.** Everything downstream calls an end an `objective`, but a floor can
  carry an end that belongs to the *place* and an end that belongs to a *name*, and usually carries
  both: the guard standing on the stair down, and the errand a house asked for. `ui/overworld_map.lua`
  splits them at the draw, off the `questId` posted work already carries: a **pennant** for the floor's
  own end, a **writ** for posted work, both in the same gold because both are things the descent ends
  at.
- **A writ says whose it is before it is fought, and asks.** Stepping toward posted work opens a scene
  naming the house and reading its own description out (`models/errand.lua`, `states/game.lua`'s
  `askErrand`), and it ends on a question: take it on, or leave it standing. It asks **before** the step
  commits, so refusing costs nothing at all — which is what makes it a refusal rather than a toll.
- **An end that cannot get a place still gets counted.** When the floor runs out, `crowdedEnds` says so;
  work the player travelled for must never be silently absent, and a floor that keeps doing it is a
  sizing rule falling behind.
- **The stops do not share a side.** The spacing rule used to be a derived Poisson radius, because a
  floor's stops were darts thrown at nine hundred tiles and darts clump. A place is a stop's own unit
  now, so the only question left is whether two stops are adjacent — and nothing can stack, because a
  place holds one thing by construction. It relaxes to "adjacent allowed" on a floor too crowded to meet
  it, the same graceful partial every pass takes.
- **The finds are guarded, never the services.** A shop behind a fight is friction; a rest behind one
  compounds exactly the wrong way. With `guardBoons` gone this survives as a placement rule rather than
  a pass: nothing ever stands in front of a camp.

### The fog

**The floor plan is not a secret; what is standing in it is.**

The fog was opaque over unwalked ground for as long as a board was a country you crossed — the shape of
the country *was* the discovery, a junction opened as you reached it, and shadowcasting meant a wall
could hide what was behind it. A grid of places has no walls to cast against and nothing to hide behind.
Black it out and there is no route to choose, which is the whole of what you do with the floor.

So an unread place is **veiled**, not covered — three tiers, all of them see-through:

| Tier | Alpha | What it means |
|---|---|---|
| unread | 0.66 | a place you know is there and have never stood beside |
| read | 0.42 | read once and remembered; its marker draws, the ground is dim |
| lit | — | adjacent right now |

**Everything found is remembered, fights included.** Once a place has been read, what is standing in it
stays on the map — a fight marker on dark ground is drawn, and the hovered readout names it. Discovery
is the cost; memory is the reward for having paid it.

That was two rules once, and the split died with the patrols. A landmark was a fact about the country
and was kept; a **live fight** was a *body*, drew only while its tile was lit, and went out with the
light — because a share of every board's combat lifted onto a beat and moved a tile for every step the
company took, so a remembered fight marker really would have been a lie about a body that had gone
somewhere else. Nothing on a floor moves any more. Holding fights to the old rule did not preserve a
mystery; it made the one mark the player most needs for routing the one mark that would not stay put,
on a floor a fifth full read one step at a time. `ui/overworld_map.lua`'s `markedStop` is the whole of
the rule, and `hoveredFight` asks the same question — a readout that answered where no marker is drawn
would turn the pointer into a probe you sweep across the dark.

`Overworld:reveal` marks a place read at **one step** — Dream Quest's adjacency reveal — and
**nothing widens it.** `Player.VISION = 1`, flat, on a rolled floor and an authored one alike.

That is a rule with a history and two casualties, both worth naming. Sight was a base of 2, raised by
the best `visionRadius` in the company's packs (a torch read 3) and by Gyeom's Ledger on top, so a
kitted party saw four. Every part of that was right for a **tile** board, where three tiles of trail was
a neighbourhood and the thing being hidden was the shape of the country. A cell is a place: one step is
four places, two is a dozen, four is a whole floor from the doorway — and since the silhouette is given
at arrival, the only thing left to discover is what is *standing* in each place, which is exactly what
must be found by going. **A radius that reaches past your own neighbours answers the floor's only
question for free.**

It is flat rather than a base under a cap, because a cap invites a bonus that silently does nothing. Two
things consequently give nothing on this axis any more: `utility_torch` (its only effect) and the vision
half of Gyeom's Ledger. If sight is ever to be bought again it has to buy something other than distance
— the obvious candidate is the dark, below.

**The dark takes it to nothing.** `game.darkFor` used to cut a radius of two-to-four down to one; against
a flat one it would take nothing at all, and a hazard that costs the player nothing has been silently
deleted. At **0** the company reads only the place it stands in and steps into whatever is beside it
blind — the same bite, expressed in the new number.

**A cell that is not there takes no fog at all**, and it is drawn in the biome's own material — the
forest's canopy, the underworld's basalt, the tundra's drift. The floor was cut out of that material,
and a dungeon whose walls do not say where you are is a dungeon anywhere. The same stone tiles past the
edge of the play area to the edges of the screen, so the floor sits *in* a country rather than on a black
page; the play area is framed by a seam rather than by a change of material. That surround is a **draw,
not cells** — nothing out there is walkable, routable or saved, because a picture frame made of real
cells is a rectangle of nothing that every placement pass, every BFS and every save has to be taught to
ignore.

The mass is **dimmed**, and the dim is *derived per biome* rather than set:

    darkest place = lum(floor colour) × (1 − FOG_UNREAD)
    mass          = MASS_BELOW × that
    dim           = mass ÷ lum(fill colour)

**One constant cannot do this job**, and the way it fails is worth keeping. A biome authors its fill
against its floor the way a *country* reads: the forest's canopy is darker than its trail, and the
tundra's snow drift (0.86, 0.89, 0.93) is far brighter than its trodden snow — correct on a map you
cross. Dim every biome by the same 0.45 and that relationship survives, so the forest reads right while
the tundra and the desert come out with the mass brighter than the floor: the board inverts and reads as
bright fields with dark paths between them. Solving for the relationship instead lets every biome keep
its hue and lets none of them out-brighten the floor. The solved dims run from **0.19** (tundra, a drift
that had a long way to come down) to **0.65** (underworld, basalt that was already nearly there).
`tests/floor_mass_spec.lua` asserts both halves over all eight grounds — the mass reads darker than the
darkest a place gets, and no ground's mass is flattened to the same shade of black as another's.

The mass is also **tiled**, seams and all, rather than filled. A flat field of a dark colour reads as
black however carefully the hue was chosen, because the eye has nothing in it to measure against; the
seam is what makes it courses of stone. This is the one thing on the floor whose look never changes —
what is not there cannot become better known.

**The unread tier was set by looking, and was wrong first.** It was 0.78, tuned by eye on a 6×6 floor
where one step lights a good share of the board. On a 10×10 about **ninety-five per cent of the floor is
unread when the company walks in**, so that tier *is* the picture — and at 0.78 a place kept so little of
its own colour that the mass beside it was barely a different black. The worst case for a fog tier is
arrival, and arrival is the frame to tune it on.

That number is now load-bearing twice over: the mass is solved *against* it, so deepening the veil
without moving the mass would quietly give away the guarantee above. Both live as named constants in
`ui/overworld_map.lua` for exactly that reason.

### The whole floor is on the screen

There is no camera. It scrolled while a board was a country; then it *held*, one chamber at a time,
cutting at every doorway — which was the room layer admitting that a floor is a set of discrete places
rather than a surface. `Overworld.BOARD_EXTENT = 608` sizes the cells so that every floor, 10×10 or
12×12, fills the same frame: 61 logical pixels a cell at the top of the descent, 50 at the bottom.

**It is the height that binds** — the title sits above the board and the control hint below it — so
growing a floor past about a dozen a side costs cell size rather than screen. That is the real ceiling on
how big a floor can get: not the frame, but the point at which a marker plate and its tier pips stop
being readable. `tests/floor_grid_spec.lua` holds the floor at 44 pixels a cell.

What that buys is the thing the minimap was drawn to fake. Which places you have seen and which routes
reach them was a 150-pixel diagram in the corner because the real board could not answer it. The board
**is** the plan, and the diagram is gone with the scroll.

A fight is no longer **pinned** to where it was found, either, and that is worth recording because it
looked like a principle and was a coincidence: a vaults chamber and a battle board were both eight tiles
at 64 logical pixels, so handing over the room's top-left made them one rectangle. Pinning an 8×8 arena
to a 61-pixel cell hangs most of it off the side of the screen. The continuity is bought elsewhere
now — the fight opens over the floor it was found on, scrimmed rather than covered, with the company
deploying on the side they walked in from.

## How big a floor is

Rolled, `. board-report 20 descent [floor=N]`:

| | grid | places | full | stops | fights in all | steps to the stair |
|---|---|---|---|---|---|---|
| floor 1 | 10×10 | 75 of 100 | 20.5% | 13.0 | 6 | **20.1** |
| floor 15 | 12×12 | 108 of 144 | 17.0% | 16.0 | 9 | **24.5** |

Against the lattice it replaced: floor 1 was 26×26 with 385 walkable tiles and its deepest point 32
tiles out; floor 15 was 33×33 with 589 and 40. The stop budget did not move — `Descent.FLOOR_FIGHTS` is
still six climbing to nine, argued from Dream Quest and Darkest Dungeon. **Forty tiles of corridor became
twenty steps of decision**, which is not a shorter crossing so much as a crossing made of choices
rather than of ground.

**Sight is what sets ten.** It was six, and six was defensible on its own terms: twenty-seven places,
nine steps corner to corner, about half of them holding something. What broke it was the fog. One step
of sight (`Player.VISION`) reads a six-a-side floor out almost completely on the way to the stair — the
floor was *known* by the time it was crossed, so there was never anything left to have explored, and the
one decision the fog exists to create never arose. Seventy-five places and a twenty-step crossing is a
floor you have to **choose how much of to see.** The two numbers are one decision.

`Descent.floorDims` grows the floor **four cells of span across the whole run**, on alternating axes:
10×10 ×3 / 11×10 ×3 / 11×11 ×3 / 12×11 ×3 / 12×12 ×3. Four cells and not a *share*, deliberately: a
proportional rate would have grown when the first floor went from six a side to ten, re-pricing the
bottom as a side effect of a decision about the top. The endpoint holds its own meaning.

**A bigger floor is a thinner one, not a longer sitting**, and the `full` column above is where that is
read — 20.5% at the top, 17.0% at the bottom, against 57% when the floor was six a side. The fights are the
length of the sitting and the places are how much floor there is to spend them across; those are separate
numbers on purpose, and this is the one to read if the floor ever feels empty rather than unexplored. The
knobs, in the order to reach for them: the stop budget (`Descent.FLOOR_FIGHTS`, `FLOOR_TEXTURE`), then
`Overworld.BLOCK_SHARE`, then the grid.

## The fights that block the way

**Most of a floor's fights stand in the only way to something.** `Overworld:blockRoutes`, run after the
stops are seated and before the tiers are stamped.

The complaint that produced it, in the player's words: *"I can reveal the entire map then selectively
choose what to encounter."* Every stop on a grid of places is optional by construction — a cell holds one
thing and you step onto it or you do not — so a floor whose fights are scattered on open ground is a
shopping list, and reading the map is the only skill it asks for. Losing `guardBoons` with the carve made
that total.

**It was never a supply problem**, and that is the part worth keeping. `. board-report` counts the two
things separately — `cuts`, how many places are the only way to something, and `blocked by a fight`, how
many of them a fight is standing on:

| | cuts a floor offers | with a fight on one |
|---|---|---|
| before | 13.95 | 0.85 — **6%** |
| after | 13.95 | 3.00 — **22%** (and 60% of the floor's fights, which is the target) |

The chokepoints were always there. Nothing was being seated on them. That is the same question the
guarded-boon knob got wrong for a whole pass in the other direction, and the only reason it was cheap to
get right this time is that the instrument reports supply and take apart.

**A cut, not a neighbour.** `guardBoons` stood a fight *beside* a reward and hoped the geometry made it a
gate. This asks directly — take this place away, and is anything now out of reach? — so a blocking fight
blocks by proof. The candidates are then sorted by **how much they strand**: a cut holding back half the
floor is a route decision, one holding back a single dead end is a fight in front of a cupboard.

Four rules it may not break, each of which it broke first:

- **It moves fights, it never adds them.** The floor's budget is authored (`Descent.FLOOR_FIGHTS`) and a
  pass that seated extra fights to make a point would quietly re-price the sitting. Stop count, fight
  count, boons and services are all unmoved across the change.
- **It never moves an authored stop.** A quest names those, and on an ascent the placement *is* the
  content — the outer ring first, the thing leaning on the gate last. Moving one is not a re-seating, it
  is a rewrite. `placeEncounters` records which cells it authored (`authoredCells`, generation-only
  scaffolding like `spineKeys`) and this reads it.
- **It never moves an elite shallow.** The floor's difficulty arc is carried by placement
  (`ELITE_MIN_DEPTH`), so picking an elite up and putting it down on a doorstep chokepoint would undo the
  arc it was just given. A shallow cut takes an ordinary fight instead. The old guarded-boon pass had to
  learn this too.
- **A campaign ground keeps its open road.** There the objectives are the only fights you must take, so
  combat stays off the spine and a cut on it is not a candidate. **A descent floor sets `ascent`, where
  combat *is* the route** — and that is the only place a fight may stand across the way down. This is the
  contract above being *scoped* rather than dropped: you can still always retreat to the way up, because
  a fight you have cleared is a place you can walk through.

`BLOCKING_SHARE = 0.6` — most, not all. An unbroken rule turns the floor into a checklist and teaches the
player to read markers instead of the ground; the loose remainder is what keeps a find on the road
feeling like a find, and what makes a blocked one read as a decision rather than a toll booth.

### A fight may not pen the company in at the door

**The pass turned on the player, and the instrument is the only reason it was caught.** `stranded`
measures the side *away* from the company, so a cut that holds back sixty of seventy-five places is not a
fight guarding a wing — it is a fight standing between the company and the whole rest of the floor, with
the company in the pocket. Sorting candidates by "most stranded first" therefore reached for the mouth of
the entrance every time:

| | places reachable from the door without fighting | floors that pen you in |
|---|---|---|
| before `blockRoutes` | 44.45 | 13% |
| with it, unguarded | **11.00** | **75%** |
| with both rules | **54.90** | **0%** |

Three floors in four opened with the company's only move being a battle it had not chosen. Nothing in
the code reads wrong; one report line said it outright.

Two rules answer it, at two scales:

- **`MAX_GATED = 0.5`** — no single fight may hold back more than half the floor. A fight gates a wing, a
  spur, a pocket; it does not gate the floor.
- **`Overworld:freeTheDoor`** — the per-cut cap cannot see two fights boxing the entrance *between* them,
  so the floor is asked as a floor, once, at the end: walking from the door and refusing every battle,
  how much can be reached? Short of **`MIN_FREE_AT_DOOR = 0.25`**, fights come back off their chokepoints
  until it is enough. It is a retreat rather than a repair — the pass gives back what it should not have
  taken, most recent choice first.

  It also relocates a fight **it never moved**, and that is deliberate: giving back only its own choices
  left the 13% the ordinary seating penned on its own. The rule is about the door, not about which pass
  put the fight there. A relocated fight goes to the deepest free place on the floor — far from the door,
  and the likeliest to be worth walking to.

The guarantee costs almost nothing: blocking fights fall from 2.92 to 2.75 a floor.
`tests/blocking_spec.lua` holds all five rules.

## The grounds are a look, not a shape

Eight biomes remain and each still names a tileset and the arenas a fight on it rolls. **None of them
names a shape any more.** The forest was a maze opened into glades, the castle was chambers cut by
recursive splits, the tundra was flats quartered by meltwater — eight carves, and they were the argument
for eight grounds. There is one shape now, and `tests/biome_spec.lua` asserts the *inverse* of what it
used to: same seed, same silhouette, different art. Asserting distinct geometry would be asserting the
layouts back.

Only the descent rolls floors, and it rolls `underworld`. The other seven are what a fight is fought on.

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

## A fight budget, not a combat share

`params.combatShare` holds combat to a fraction of the stop count and re-seats the overflow as texture.
That is the right instrument for a **roadside**, where the question really is what fraction of a walk is
fighting, and the board's one objective is the day's work rather than part of the mix.

It is the wrong one wherever a caller has to count the fights on the **whole** board, and a descent floor
is exactly that caller. Its ends are seated by `placeObjectiveAndGates` — a different pass, running after
`placeEncounters` — so no fraction of the stop count can see them. And a floor has several: the stair,
one per errand a house has asked for down here, and one per door still shut on the first circle
(`Descent.floorObjectives`). Under a share those were **free**.

Measured, at the 14–18 stops and 0.75 share this replaced:

| | rolled fights | ends | fights in all |
|---|---|---|---|
| floor 1 | 11.3 | stair + 3 openers | **15.7** |
| floors 3–11 | 11.3 | stair + up to 4 errands | 12–16 |
| deep floors | 11.3 | stair | 12.3 |

Measured after, at floors 1 / 4 / 8 / 12 / 15: **6 / 7 / 8 / 8 / 9** fights in all, with `services` flat
at 5.6–5.8 throughout.

Fifteen floors of that is about two hundred fights in a run. The header that justified the setting
claimed it "lands six or seven fights" — derived by multiplying two constants, never rolled — and it was
out by nearly double, because the guarantee pass seats far fewer texture stops than the arithmetic
assumed and a cap does not bind when the pool is fight-heavy underneath it.

The density was also buying nothing, measured while `guardBoons` still existed: at 11.3 fights only
**20.9%** of them stood in front of a reward, against **45%** at 5, because that pass was supply-limited
by the boons rather than by the fights. The pass is gone and the finding is not — **a thinner floor
makes each fight more likely to mean something**, which is the reasoning the budget below still rests
on.

So a floor names an **absolute** budget and the generator takes it as `params.combatBudget`, which wins
over the share where both are given:

- `Descent.FLOOR_FIGHTS = 6` — every fight on the **first** floor, ends included. Six is a Dream Quest
  level and a Darkest Dungeon medium dungeon, and there is no hub in the stack, so it is spent fifteen
  times over.
- `Descent.FLOOR_FIGHTS_DEEP = 9` — and what the bottom holds. `Descent.floorFights(f)` interpolates and
  rounds: **6/6/6/7/7/7/7/8/8/8/8/8/9/9/9**, four rungs held three or four floors apart. The climb is
  deliberately small, because depth already buys difficulty on every other axis — the stock is grown to
  `Descent.dangerLevel`, the stair carries a general rather than a lieutenant, the board widens a tile a
  floor, and the company has been walking since floor one. A steep ramp here charges twice for the same
  descent. But *flat* was wrong too: floor fifteen laid out exactly as many fights as floor one on a
  rectangle a third larger, and a count that never moves is a count the player stops reading. The
  endpoint is authored rather than a per-floor step, so changing `FLOORS_PER_CIRCLE` restretches the ramp
  instead of silently re-pricing the bottom. Whole run: **113 fights**, against 90 flat and ~200 before.
- `Descent.FLOOR_ROLLED_MIN = 2` — the floor under it. A board whose only fights are its objectives is
  four markers on dead ends with empty trail between them, so an errand-heavy floor overshoots six and is
  the longer sitting. The ends are the work you came down for; the two rolled fights are the ground.
- `Descent.FLOOR_TEXTURE = 6` — the non-fight stops, **added** to the rolled fights rather than shared
  with them. A stop count with a share over it lets a fight and a merchant compete for the same tile, so
  capping the fights hard would have re-seated all of them as merchants; two separate numbers cannot do
  that to each other. (Caches are pinned separately again — `Descent.FLOOR_CACHES` — so material income
  does not move: cache craft held at 16.7 against 17.4 across the cut.)

`. board-report N descent` counts the ends now (`ends`, `FIGHTS IN ALL`) and takes `ends=N` to stand in
for the errands a nil player cannot have asked for. It had never once seen one before.

## The stairs, both ways

**The stair is found under the guardian.** A floor's own end is a body standing at the far end of the
road; beating it is what turns that place into the way down (`Descent.openStair`, which renames the cell
at that moment and only then).

It did not read that way, and the leak was the **name**. The end was called `"The Stair Down — <Sin>"`,
and a board names its end on the marker and in the hovered readout — so the moment the fog lifted off
that place the player had been told where the exit was and what it was for, before ever meeting the thing
holding it. The end is named for **who stands on it** now: the circle's general on her own floor, her
lieutenant on the floors above, read off the character blueprint by `Descent.guardianName` — which is the
landing card's own function, so the name on the marker and the name the landing reports are one string
and cannot drift.

| | before | after |
|---|---|---|
| floor 1's end | "The Stair Down — Lust" | **"The Suppliant"** |
| floor 2's end | "The Stair Down — Lust" | **"Luxuria, the Unbidden"** |
| once the guard falls | — | "The Stair Down" |

**And the stairs run both ways.** `Descent.retreat` takes the company up one floor, to the floor above
and the stair they came down by. The way up used to offer exactly one thing — end the expedition — so a
company that wanted to walk back to a pack it dropped two floors above had to climb out of the rift and
re-descend from the top. The floors are kept precisely so they can be walked again (`Descent.keepFloor`);
the only thing missing was the door back to them.

Three rules it needs to be honest:

- **It costs one on the tally**, symmetrically with `Descent.advance` taking one off. Going down prunes
  the rift by one; if coming back up were free, a company could walk a stair up and down between two
  floors and drive the count to zero for the price of the walking. That would make the tally a purse
  rather than a statement about the state of the rift — the exact thing `Descent.countBy`'s own header
  refuses. **A round trip is now worth exactly nothing.**
- **You come out on the stair you came down by**, not at the floor's entrance. Arriving at the far end of
  ground the company already crossed would be a teleport wearing a staircase, and it would hand back for
  free the walk that going up is supposed to cost. `run.arriveAt` carries the cell — read off the kept
  board's own `objective`, which is what `openStair` converted — and `states/game.lua` consumes it once,
  at the door.
- **Floor one's way up is the way OUT**, and offers no retreat: there is no floor zero, and the card that
  ends the expedition is a different card.

`tests/stair_spec.lua` holds all of it, including the one that would be easiest to lose in a retune: no
floor may name its end with the word *Stair* before the fight.

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

A floor should get harder as it runs. It did not, and the reason is worth keeping because it is easy to
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
   the spine and combat-share rules already make.
3. **The tier ramp is a gradient.** Depth in thirds gives all three pips to position, and rank is +1 on
   top. The random spike dropped 0.25 → 0.12, because at a quarter it was as strong as the depth term
   it was decorating.

Measured on the grid, floor 1, thirty rolls: `1.13 / 1.73 / 2.10 / 2.85 / 3.00`. It **rose** across the
change — the tile board's `1.17 / 1.55 / 2.19 / 2.69 / 3.00` was measured over nine hundred tiles, where
a fifth of the board by distance is a wide band and the depth term is diluted across it. Nine steps of
places is a short, legible ladder, and the arc reads as one.

## The braid rate, and how the guarded-boon knob was misdiagnosed

**Both the knob and the pass it tuned are gone.** This section is kept because the *method* is the point
and it is the one this document exists to teach.

`Overworld.BRAID` set how many of a maze's dead ends were knocked through into loops, and `guardBoons`
targeted `GUARDED_BOON_SHARE = 0.8` — a fight standing in front of most rewards. It was achieving
**30%**, and the shortfall was recorded for a whole pass as a shortage of *fights*: "what limits
guarding is the SUPPLY OF FIGHTS". That was wrong, and only measuring caught it. At the old braid rate:

| | |
|---|---|
| dead ends per board | **2.0** — against 4.5 caches asking for one |
| boons with a real cut vertex beside them | **32.7%** |
| boons actually guarded | 29.7% — i.e. **92% of what the geometry permitted** |
| loose fights standing around unused | **3.1 per board** |

The pairing pass was working almost perfectly. The board had nowhere to put a guard. Braiding destroys
exactly the geometry the offer rule needs, and dropping the rate to 0.20 took gateable boons from 32.7%
to 72.6% and guarded from 29.7% to 56.8% — while material income went **up**, because a guarded cache
paid a bonus and far more of them were now guarded.

Three lessons outlived the code:

- **A knob that is not achieving its target may not be the knob.** The number that diagnosed this was
  `boons gateable` — the geometric ceiling — and nobody would have thought to report it while the
  diagnosis was "not enough fights".
- **The obvious lever was the wrong one, and measurement said so.** Cutting `cacheTarget` to force
  boons-per-fight toward 1.0 dropped material income by a third *and* lowered the absolute number of
  guarded boons, because it removed boons rather than adding pairings.
- **Then the ceiling moved again, downward, on purpose** — once a guard had to be able to fight where it
  stood, the achieved share fell on every maze-like ground (forest 67.4% → 32.7%) while the wide grounds
  barely noticed. **A gate is a narrow place and an arena is a wide one.** That tension is what the room
  layer was reaching for when it moved the gate off the tile and onto the chamber, and it is what the
  grid resolved by taking the gate off geometry the generator hoped for and building it on purpose
  (see The gate is built, not found).
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

- **A fight is not attached to anything any more.** `guardBoons` was the pass that made an optional
  fight worth taking — the boon behind, the fight in the way — and it went with the geometry it read.
  The replacement is Dream Quest's: a fight pays for itself in spoils and levels. Whether that is enough
  to make a fight on a floor a *decision* rather than a tax is the largest open question the change
  leaves, and it is a content question (what a fight pays) rather than a generator one.
- **Two and a half spurs a floor end in nothing** — 59% of dead ends pay for the walk, against 63%
  before `blockRoutes` (so the pass costs four points of it, and the other thirty-seven were always
  there). The old board had a whole pass for this, `pruneDeadStubs`, which trimmed any spur that
  terminated in nothing; a grid has none, because its dead ends are *places* rather than corridor and
  cutting one changes the silhouette. The two candidate fixes are `hollow` refusing a block that would
  make a barren leaf, or placement guaranteeing every leaf pays. `. board-report`'s `...ending in
  nothing` row is the instrument; it is measured now and not yet fixed.
- **The Translation can drop you behind a fight you have not cleared.** Blocking fights are safe to walk
  *past* by construction — you cannot reach ground beyond one without clearing it, so the road home is
  always cleared ground. The one route that skips that reasoning is the hazard that moves you: it lands
  on a `seen`, empty place, which may sit in a region whose only mouth still holds an uncleared fight.
  Not a soft-lock — the fight is winnable and the party chose to be down here — but it is the one way the
  mode can *force* a fight on a company that was walking away from one. Cheap fix if it bites: prefer a
  destination in the same region as the way up.
- **A floor is a fifth full** — 20.5% at the top of the descent, 17.0% at the bottom — because the grid
  is sized by what one step of sight can be asked to explore and the stop budget is authored from what a
  sitting should cost. Those are the right two questions asked separately, but nothing has yet asked
  whether sixty empty places on a first floor read as *unexplored* or as *empty*. It needs playing, not
  measuring; the `full` column is where the answer gets written down.
- **No adjacency rule between stops of the same kind.** Two stops may not share a side, but nothing
  stops two merchants two steps apart.
- **Every offer on the floor pays the same currency.** Materials from a cache, materials and gold from a
  fight — so the floor is N copies of one offer at different prices, and route *choice* cannot really
  exist until two boons can differ in kind. The largest open item here, unchanged by the shape, and a
  content question rather than a generator one.
- **The eight biomes no longer differ in anything but art**, which makes the seven the descent does not
  roll dead weight on the map side. They still name the arenas a fight is fought on, so they are not
  unused — but "a ground" is now a much thinner idea than the word suggests.
- **No biome has a tileset drawn yet** — all eight fall back to coloured rects, which on a grid of
  places is more visible than it was on a warren: a place is sixty pixels square and mostly flat colour.
  See [docs/art-assets.md](art-assets.md).
- **A torch buys nothing, and neither does half of Gyeom's Ledger.** Sight is flat at one step and
  nothing widens it, so `utility_torch`'s only effect is gone while the item is still on the Lodge's
  shelf at 80 gold describing itself as *"Extends the party's vision on the overworld"*. The obvious
  repair is the one its own flavour text already names — the dark now takes sight to **zero**, and a
  torch is "the oldest answer to the dark" — but that is a content call, not a consequence of this
  change, so it is written down rather than made.
- **The prologue's flight is four cells by three.** It re-authored cleanly and every beat survived, but
  a tutorial that teaches the walk on nine places is teaching it at the smallest scale the game has. Play
  it before assuming it still teaches what it used to.
