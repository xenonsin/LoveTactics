# Terrain

Fire Emblem has no facing. Its positional lever is **which tile you stand on**, and that is the trade
this project took: authored stats instead of a facing system, and terrain doing the work direction
would have done (the argument is in [accuracy.md](accuracy.md), under *Why Fire Emblem and not FFT*).

This file is the law of the ground. It exists because that law had been living in three places at
once — the header of [models/terrain.lua](../models/terrain.lua), a section of `accuracy.md`, and a
paragraph inside [models/arena.lua](../models/arena.lua) — which was survivable while a tile could
promise exactly two things and stopped being survivable when it could promise four.

## One table, two surfaces

`Terrain.TYPES` is the only terrain table. The overworld map and the battle board read the same rows,
so a river means one thing on both. Each row answers five questions:

| Field | |
|---|---|
| `moveCost` | terrain-weighted enter cost (Dijkstra reach + the initiative timeline) |
| `walkable` | may a unit occupy the tile at all |
| `sightCost` | how much it obstructs a line passing **through** it; summed, blocked at `Combat.SIGHT_BLOCK` |
| `bonus` | what it grants whoever **stands** here — see below |
| `tags` | what the ground is made of: `burnable`, `conductable` |

`index` and `color` are the default art. A biome's tileset may override either; it may **never**
override behaviour. A river you can walk across in one country and not another is not a rule, it is a
bug.

## What a tile may promise

`Combat.fieldBonus` aggregates a tile's `bonus` with any placed field object on the same square and
hands back one flat bag. The bag is generic on purpose — a smoke cloud or a vantage totem contributes
through the same seam with no new code — and that genericity was for a long time one-directional in
the worst way: **the bag accepted every key and two of them were read.** The tile tooltip carried its
own list of seven and printed whatever was non-zero, so a tile authored `bonus = { defense = 2 }`
displayed *"+2 Defense bonus"* to the player and moved no number in the fight. Nothing had gone wrong
only because nothing authored those keys.

So the legal set is **declared**, in `Terrain.BONUS_KEYS`, and each entry names its own read site:

| Key | Read by | |
|---|---|---|
| `avoid` | `Combat.terrainAvoid` | comes straight off an attacker's hit chance |
| `range` | `Combat.fieldRangeBonus` | **sighted abilities only** — a vantage lengthens a shot, never a swing |
| `defense` | `Combat.flatStat` | via the arrival stamp |
| `magicDefense` | `Combat.flatStat` | via the arrival stamp |

The list is **ordered**, and it is one list rather than a set plus a display order: the tooltip walks
it directly. Two ledgers of the same set drift the moment somebody adds to one of them, and the drift
is silent — the readout would simply stop mentioning the newest key while every spec about the *set*
stayed green. `tests/field_bonus_spec.lua` fails the build on a tile promising an undeclared key, on a
declared key with no read site, and on a declared key with no word for the player.

### The arrival stamp

`Combat.flatStat(unit, name)` is the single fold every effective stat is read through — mitigation,
the character sheet, the damage-breakdown tooltip, `Status`'s resist rating — and it takes no
`combat`, by a long-standing and correct design: a unit can be asked what its defence is without
anybody producing the battle it is standing in.

So the ground's contribution is **banked onto the unit** (`Combat.stampField` → `unit.field`), exactly
as `unit.bonus` banks the grid's contribution at setup, at the three moments the answer can move:

- **arrival** — `Combat.enterTile`, already the one chokepoint for a walk, a shove, a blink, a swap
  and a summon appearing;
- **placement** — `Combat.addUnit`;
- **turn start** — `Combat.startTurn`, the backstop for the ground changing under a body that never
  moved (only a field object appearing, which nothing shipped does yet).

The alternative — reading the tile at the mitigation site only, the way `terrainAvoid` is read at the
accuracy site only — would have left the character sheet quoting a defence the blow does not use.

### The ceiling on terrain armour

**+1, and exactly one tile carries it.** Fire Emblem's fort gives +2 against a Defence that runs 0–20;
ours runs **3–6** across the whole roster, so the same +2 is a third to two thirds of a body's entire
mitigation — far heavier than the forest's +20 avoid, which comes off a hit chance already sitting at
61–91%. A model game sets the magnitude only while the stat it was set against is the same width.

Armour on a second tile is a re-tier, and a re-tier obliges a rebalance. `Terrain.DEFENSE_CEILING`,
pinned by `tests/terrain_spec.lua`.

### A flier forfeits the tile

A body in the air is **over** the wood, not in it: no cover, no vantage, no parapet — and no bog
either, because the rule is "the ground stops mattering" in both directions.

This is Fire Emblem's own rule and it is the trade the flying tag was missing. A Zephyr Strider
already pays nothing for the ground (every tile costs 1, unwalkable landforms open — `Combat.isFlying`)
and was collecting the forest's +20 and the hill's +1 on top of it. A tag sold as a trade was pure
upside.

**Placed field objects still apply.** A vantage totem or a banner's square is an object at the body's
own altitude rather than dirt under its feet, and nothing about being airborne puts you outside one —
which is also what keeps the rule from quietly gutting a future zone system.

## The floors

| Tile | Move | Sight | Avoid | Other | |
|---|---:|---:|---:|---|---|
| `ground` / `path` | 1 | 0 | — | | open field |
| `bridge` | 1 | 0 | — | | the only way over a river |
| `ice` | 1 | 0 | — | conducts | the only floor that doesn't tax a step |
| `forest` | 2 | 1 | +20 | burns | soft cover |
| `dune` | 2 | 1 | +20 | | the desert's cover — inert, the one piece that neither burns nor conducts |
| `drift` | 2 | 1 | +20 | conducts | the tundra's cover |
| `redoubt` | 2 | 0 | +10 | **defense +1**, renews | the built work |
| `rough` | 2 | 0 | +10 | | broken ground, a modest edge |
| `sand` | 2 | 0 | — | | forest's cost without forest's cover |
| `water` | 2 | 0 | — | conducts | a ford |
| `hill` | 3 | 2 | +30 | **range +1** | the best tile on the board, priced like it |
| `mire` | 3 | 0 | −10 | conducts, **mires** | the hill's exact inverse |

Solid: `thicket`, `grass`, `rock`, `mountain` (a flier crosses it), `river`, `lava`.

### The redoubt

Fire Emblem's terrain design has an anchor and it is not the forest — it is the **fort**: the square a
defender takes and an attacker has to dig them out of. Every cover tile here paid in *evasion*, which
is an answer for a body that would rather not be hit at all; nothing rewarded a body whose entire plan
is to be hit and stand there, which is a strange hole in a game with a knight house.

So it is priced against the hill and deliberately opposite to it. Cheaper to reach, worth nothing to a
shooter, `sightCost 0` (you can see out of a thing you stand *behind*), and the only ground in the game
that thickens armour. **The hill is the archer's tile; the redoubt is the wall's.**

### Ground that heals, and ground that bogs

Neither is a terrain key. Both are **hazards**, because a zone-granted status is what "this ground does
something to you" already means in this codebase — one word per mechanic. `models/arena.lua` walks the
finished board and stands a zone on each such tile (`Arena.TERRAIN_ZONES`, `Arena.terrainZones`):

- a **redoubt** stands `hazard_renewal`, granting Regeneration while you hold it;
- a **mire** stands `hazard_quicksand`, inflicting Mired — the mire was the one floor in the table
  defined entirely by subtraction, which made it ground nobody ever decided about, only routed around.

The zones are **unowned**, and that is the whole of what makes the fort a fort: `Hazard.allied` answers
true for a zone with no `side`, so it is allied to both companies. It belongs to whoever got there
first, and taking it off somebody is the same act as holding it.

Standing them costs the generator nothing: `Arena.terrainZones` walks the tiles and consumes **no rng
at all**, so it runs on the procedural and the curated paths alike without moving a single draw. The
field shader already draws them, and `Hazard.tileBias` already makes the enemy planner seek and avoid
them.

## Every country grows cover

A rolled board makes exactly **three** scatter calls (`Arena.generateLayout`): a fill (2–5 tiles), a
rise (1–3) and a blocker (1–3). Only the fill is ever cover in any quantity — and it was cover in two
biomes out of eight.

| Biome | Fill | Rise | Blocker | |
|---|---|---|---|---|
| `default` / `forest` | `forest` | `hill` | `mountain` | |
| `desert` | `dune` | `hill` | `mountain` | |
| `tundra` | `drift` | `hill` | `mountain` | |
| `volcanic` | `rough` | `hill` | `lava` | thin cover, but real |
| `swamp` | `mire` | `forest` | `mountain` | the hostile floor — see below |
| `castle` | `redoubt` | `hill` | `mountain` | Pride's circle |
| `underworld` | `rough` | `hill` | `mountain` | Greed's circle |
| `colosseum` | `sand` | `mountain` | `mountain` | bare on purpose |

Two things this table fixes, and they were both invisible:

- **The desert filled with sand and the tundra with ice**, neither worth a point of anybody's aim,
  which left 1–3 hills on 64 squares as the entire positional decision on those boards.
- **`castle` and `underworld` were not in the table at all** and fell through to the default, so a
  fortress circle and a cavern circle both rolled *woodland*. A fall-through that produces a playable
  board is the worst kind of hole: nothing crashes, nothing is empty, and the place is simply the wrong
  place for as long as nobody looks. `forest` is now written out too, identical to `default`, so
  `default` means what its name says — the answer for an id nothing declares.

**No fourth scatter.** The generator still makes three draws in the order it always did, so every
stored seed produces the board it always produced — the same shape, the same walls, the same walkable
print. What changed is what the tiles are *made of*, which is the only thing the palette has ever
decided.

**Two deliberate exceptions.** The **swamp** keeps its hostile fill: a mire that stopped punishing the
body standing in it would stop being a swamp, so its cover is the rise instead and is thinner on
purpose. The **colosseum** keeps its bare floor: an arena is swept between cards and the crowd paid to
watch an exchange, not two men hiding from each other. `tests/biome_spec.lua` names both, so the
allowance cannot spread by accident.

## Measure, then tune

```powershell
& "E:\LOVE\lovec.exe" . terrain-report [n] [move=N] [biome=ID]
```

Rolls `n` boards per biome and reports **how much cover a company can actually get to on its first
turn**. The columns that matter are `cover` (the supply) and `reach` (the take), kept apart because
they come apart — whenever the blocker walls a wood off, or the fill lands in the far corner — and the
fix for a supply problem (scatter more) is not the fix for a seating problem (scatter it nearer). One
number cannot tell them apart. `tools/board_report.lua` learned that lesson twice.

Reachability is **measured, not read**: the walk is a real Dijkstra over the tiles' own move costs from
the company's spawn block, so a forest behind a mountain correctly does not count.

**Do not re-tune the scatter counts without running it.** As of the parity pass it reads ~5.6 cover
tiles and ~1.4 reachable per board, with no reachable cover on about 20% of boards — a company that has
to spend a turn reaching cover is making a decision, not going without one.

## What the player sees

- **The tile tooltip** names the terrain, draws its mark beside the name, and lists every non-zero
  declared bonus in `Terrain.BONUS_KEYS`' own order — cover first, written as a percentage because that
  is the unit it is spent in.
- **A mark per terrain type** ([ui/terrain_art.lua](../ui/terrain_art.lua)), which is *texture* and
  never a verdict: it says what the ground is made of, shades itself off the tile's own tone, and is
  there whether or not anybody is deciding anything.
- **Cover pips inside the move band** (`BattleMap:drawCoverMarks`) — a shield pointing **up** on ground
  that answers for you, the same shape **inverted** on the mire. These *are* verdicts, so they obey the
  rules verdicts obey: the overlay's own colour, only while a move is being chosen, never on the bare
  board. The ground keeps its texture; the overlay gains a mark. A flier is shown none.
- **The ground named under the Hit row** ([ui/action_preview.lua](../ui/action_preview.lua)) — `−20 ·
  Forest` — because the panel was quoting terrain's result without ever mentioning its cause, and a
  player who had not gone reading concluded the weapon was bad. One gloss, shared with the tooltip
  through `TileTooltip.terrainName`, so a castle's Rampart is a Rampart on both surfaces.

## Both sides want the tile

Cover is only a decision if someone can take it from you.

`AI.riskScore` counts how many enemies can reach a candidate tile (`EXPOSURE`) and, since this pass,
**discounts that count by the cover underfoot** — a forest is worth a fifth off the whole term, a hill
very nearly a third. Expressed as a fraction rather than a bonus of its own because that is what cover
*is*: it does not make a tile safe, it makes every threat already counted there land less often. It
cuts both ways, so the same line that walks a body into the trees walks it around the bog.

The reposition fallback breaks ties by cover too, one rung above "fewer steps" — a posture that holds
ground should hold the best ground it can reach. The rung sits below distance and hazard bias on
purpose: cover is worth nothing on a tile that gave up the approach or stands in fire.

Target *choice* already weighed the odds (`Combat.landChance`) before any of this, which is why the AI
never shot into cover but would never stand in it.
