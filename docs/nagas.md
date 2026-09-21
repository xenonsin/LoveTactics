# The Mere — deep water, and the people who live in it

A faction, a tile that kills, and the axis both of them needed. Settled over three review rounds, then
built — all five stages are in the tree and the suite is green. What follows is the design and the
argument behind each decision; [what the build corrected](#what-the-build-corrected) is the last section,
because three things turned out not to work the way this document said they would.

**The load-bearing fact, and everything else is downstream of it:**

> Nobody walks into deep water. You get **put** there.

---

## The ground

### `deep` is unwalkable, and carries a `drowns` flag

One new row in `Terrain.TYPES` ([models/terrain.lua](../models/terrain.lua)):

```lua
deep = { moveCost = 1, walkable = false, sightCost = 0, tags = { "conductable" }, drowns = true }
```

`walkable = false` is the load-bearing half. Every generator carve, connectivity guard, deployment
filter and enemy path already reads unwalkable correctly, so a rolled channel can never cut a company
off from the stair by accident — which is exactly what a walkable-but-closed-per-unit tile would have
done, silently, on the boards where it mattered most. `moveCost = 1` is read by nobody but a swimmer.
`sightCost = 0` — you see across water and you shoot across it, and that is the counterplay to a body
standing in it.

It is [`river`](terrain.md#the-floors) with one new field on it, not a new kind of thing. The lethality
does not live in the terrain table; it lives in a hazard, below.

### `Combat.isAquatic` — a `swim` tag, scanned exactly where `flying` is

A grid scan for the tag, read at the same two chokepoints `Combat.isFlying` is read at (`moveGraph` and
the steered-route validator). A swimmer enters `water` and `deep` at cost 1 and may stop in either;
everywhere else it pays what anybody pays.

> **Flying says the ground stops mattering. Swimming says the water stops being ground.**
> The Zephyr Striders open every tile and charge one; this opens two tiles and charges one *there*.
> What it buys is a lane, not a map.

### A shove does not stop at the bank

`footprintCanShift` refuses unwalkable terrain because a body cannot *stand* there. Water is the one
landform a body can *fall into* — so a forced move (shove, throw, pull) whose next tile carries
`drowns` **carries**, and the hazard takes it. Every other unwalkable tile keeps the collision rule
exactly as it is.

**This is the whole mechanic.** A non-swimmer can never *walk* in, so forced movement is the only way
anyone ever meets the water — which is what makes deep water a threat the enemy delivers rather than a
suicide button on the player's own move overlay.

### The drowning is a hazard, stood on every deep tile automatically

`hazard_deep_water`, added to `Arena.TERRAIN_ZONES` beside the fort's renewal and the mire's quicksand.
Its `onEnter` drowns anything that is not aquatic and not flying. `Arena.terrainZones` consumes no rng,
so it runs on rolled and curated boards alike without moving a single draw.

Three things arrive free: `Hazard.tileBias` already steers the enemy planner away from hostile ground,
the field shader already draws a zone, and no new death plumbing is written. Ground that heals and
ground that bogs are both hazards already — one word per mechanic, and ground that kills is not the
exception.

### A drowned body is sealed, not downed

Drowning skips the incapacitated window and its countdown: there is no body lying on the water for
anyone to reach, and a revive cast aimed at open water is nonsense. Post-win `reviveFallenParty` still
carries it home, so it costs the fight and the trip — never the character. [The descent's law](the-count.md)
holds: a bad trip costs a body on the bench, never a bill.

### A flier crosses it and cannot drown

A body in the air is over the water, not in it — [terrain.md](terrain.md#a-flier-forfeits-the-tile)'s own
rule, held in both directions. Any other answer means the strongest movement item in the game acquires a
silent new failure mode on one tile.

### Where deep water appears

| Biome | Fill | Rise | Blocker |
|---|---|---|---|
| swamp | `mire` | `forest` | **`deep`** *(was `mountain`)* |
| underworld | `rough` | `hill` | **`deep`** *(was `mountain`)* — the flooded vault below Greed |

Same three draws in the same order, same seed, **same walkable print** — the board's topology does not
move one tile. What changes is what the walls are made of. `volcanic` already ships a non-mountain
blocker (`lava`), so this is a substitution the generator has done before, and there is no fourth
scatter to drift every stored seed.

1–3 channels per board, which is a lane and never an ocean. Nobody kites forever in three tiles of
water.

### What the tile owes the player

A new terrain type owes three things and `tests/terrain_art_spec.lua` fails on all three: a procedural
mark in [ui/terrain_art.lua](../ui/terrain_art.lua), an `ART` role (`river` — a biome's water, whatever
that water is made of), and a name plus description in [ui/tile_tooltip.lua](../ui/tile_tooltip.lua).

The description is not flavour here: **"Drowns anything that cannot swim."** A lethal tile that does
not say so on dwell is the one unforgivable version of this feature.

### The shallows soak

Every `water` tile stands an unowned `hazard_shallows` (`Arena.TERRAIN_ZONES`), which grants
`status_wet` on entry. Both halves already existed — the status ships, and `water` already conducts.

It is a zone rather than an end-of-turn check because that is what ground that does something to you
already is here, and because **Wet lingers**: you come out of the ford still soaked and dry on the
status's own fifteen ticks. Standing in the water simply refreshes it. The cost is worth naming — the
zone reads `hostile`, so every planner on every board with water on it now prefers to path around a
ford. That is the correct reading (a planner that walked its own line into a conductor would have a
bug), but it is a real change to boards that have existed for a long time.

---

## Race — the axis above class

The nagas arrived asking for a class of their own and the answer was that they are not a job. A naga
knight and a naga mage are both nagas, and neither fact tells you the other, which is the definition of
a second axis. `class` was the only taxonomy a body had that carried rules, and it was being used to say
something class cannot say.

`models/race.lua` + `data/races/*.lua`, auto-loaded by the registry like every other content folder.

### What a race may declare

A **closed** set, each field naming its own read site. `Race.FIELDS` is the declaration and a spec fails
in both directions: a field nothing reads, and a read site with no field.

| Field | Read by |
|---|---|
| `name` | every readout that says what a body is |
| `kind` | the coarse split every item rule already uses — see below |
| `tags` | `Combat.isAquatic` (`swim`), and the scan shape every innate rule after it uses |
| `resist` | `Combat.applyUnitPassives`, folded exactly as a creature's innate table is |
| `bonus` | `Combat.applyUnitPassives`, a **fixed** stat line — see below |
| `grants` | bound items seeded into the body's grid at instantiate |

[terrain.md](terrain.md#what-a-tile-may-promise) already taught why the set is closed: a generic bag
that accepted every key and read two of them printed *"+2 Defense bonus"* to the player and moved no
number in the fight, for years, because nothing had authored the key yet.

### Rules, and a fixed stat line — never a growth table

A race may carry a stat bonus. Three clauses keep it from becoming a class:

- **Fixed, never per level.** A growth table is what a body *became*; a race is what it *is*. That border
  is the whole of "not a class".
- **Bounded and declared**, the way the innate resist line already has a budget — so a race cannot
  quietly out-give a class.
- **`tools/balance_rescale.lua` must see it.** This is the clause that bites in silence: the rescale tool
  moves health to land a body inside its time-to-kill band, and a bonus it cannot see is a body it
  re-tunes against the wrong number, with nothing turning red.

A race's `resist` line is written to the **lowest rung that wears it** — the innate budget is capped per
rung (2 / 3 / 4 / 5, weaknesses twice as deep) and a race is rung-agnostic, so a table written at elite
magnitude would put its own chaff over budget the moment it was authored. A body may add its own line on
top within its own remaining budget.

### `kind` is deleted from blueprints

Every body declares a race; each race declares the `kind` the item rules read. The migration is
mechanical, which is why it is one pass rather than an incremental drift:

| Today | Bodies | Becomes |
|---|---:|---|
| `kind = "humanoid"` | 75 | `race = "human"`, and `"naga"` for the new four |
| `"beast"` · `"construct"` · `"elemental"` · `"undead"` · `"object"` | 77 | a race of the same name |
| `"demon"` | 16 | `race = "demon"` — and the holy rule moves onto it |

167 of the 168 blueprints declare a `kind` today; the exception is `character_saber_bout`, which shallow
copies `character_saber` and will inherit the race the same way — a case the migration must not break.

Eight race files on day one. `race = "wolf"` with `kind = "beast"` is a refinement that costs no second
pass. Every existing rule — the creature/bodied item split, the demon's holy line, the discipline gate —
keeps working against a field it no longer has to trust an author to type.

**One authored ledger.** `kind` was only ever a guess before it was declared: `tools/char_compose.lua`
inferred it from words in the id and defaulted to *"most portraitless enemies are people"*, which made
every wolf in the folder a humanoid as far as the code was concerned.

Moving the demon's holy rule onto `race = "demon"` is the other half of the same tidy: it is
[the one place `kind` was ever allowed to mean something mechanical](bestiary.md#a-demon-takes-holy-the-harder),
and it can now be stated once instead of asserted over sixteen blueprints.

### A race grants what it is made of

`Race.grants` seeds bound, unstealable items into a body's grid at instantiate. `data/races/naga.lua`
grants `utility_naga_coils`, which carries the `swim` tag.

This is deliberately not a second implementation of the rule. `Combat.isAquatic` keeps its existing grid
scan; there is no innate-or-carried fork to keep in step; the player can see **why** that body swims, on
the same surface they read everything else about it. And it generalises — `utility_demonic_essence`
stops being authored into sixteen demon grids and becomes one line on the demon race.

The cost is named rather than hidden: a granted item takes a grid cell. That is a real price for a
racial rule, and it is the same price the demons already pay.

### `data/races/naga.lua`

| Line | | Reads as |
|---|---:|---|
| `water` | **+2** | their own element runs off them |
| `lightning` | **−4** | and it is the thing they die to |
| `slash` | **+1** | scale turns a blade… |
| `impact` | **+1** | …and takes a club… |
| `pierce` | **−2** | …and a spearpoint finds the gaps between the plates |
| `movement` | **−1** | a body built for water, dragging itself over dry stone |
| `speed` | **+1** | and striking before you are ready, once it arrives |

Plus `kind = "humanoid"`, `tags = { "swim" }`, `grants = { "utility_naga_coils" }`.

The three physical lines **sum to zero**, as the innate contract requires, and every value sits inside
the rung-1 budget so the Shoalkin can wear the table unchanged.

**The `movement −1` is what prices the swim rule.** Free movement through water plus passage over ground
nobody else can cross is a large gift, and [the flying tag taught this the hard way](terrain.md#a-flier-forfeits-the-tile)
— it paid nothing for the ground and collected the forest's cover on top, so a tag sold as a trade was
pure upside until somebody noticed. It also makes the Mere read correctly on a board with no water on
it: they are worse there, and they know it, which is why every naga fight is fought where they chose.

**The `lightning −4` is load-bearing in two directions.** It is why the Tidecaller's own trick is the
answer to the Tidecaller, and it is why a fen board — mire, shallows and deep water, all three
conducting — is the most dangerous ground in the game *for the nagas standing on it*.

---

## The Mere

A faction name in [the bestiary](bestiary.md#the-factions) names a place or a body of people: the Host,
the Pit, the Undercroft, the Lodge. **The Mere** is the water under the fen and the people in it.

One sentence between the four of them: *the lancer soaks, the caller conducts, the undertow drags.*

### The plan is to drown you

Not a side effect of the kit — the thing the planner is actually trying to do. `targetPref =
"drownable"` ([models/ai.lua](../models/ai.lua)) ranks a foe by whether a channel sits one step along
the line between it and the caster, which is where a push or a pull would put it. Two tiles, both
directions, no knowledge of which item the rule is about.

It is a **preference and not a filter**, which is the seam doing the work. On a board with no water
every one of these rules still fires and the Mere is an ordinary pack with long spears — so they read
as people who chose their ground rather than as a gimmick that stops working when the ground changes.

The Undertow carries **both** lane casts for the same reason: Riptide drags a body toward the channel
she is standing in, Breaker drives one into the channel at its own back. With only the pull, a company
answers her by keeping the water behind itself.

### A naga is never Wet

`utility_naga_coils` carries `statusImmunity = { "status_wet" }`, and it is a fix as much as flavour.
Wet is `lightning +6` and the naga race is `lightning −4`, so a pack standing in its own channel would
take **ten extra** from a bolt — and the Tidecaller's own Stormwake arcs through every conducting tile
it touches, which on a fen board is all of them. Without the immunity the faction's whole plan is
suicide.

The player's counter is untouched: the race still takes lightning the harder, a fen board still
conducts, and a bolt through a channel still finds every naga in it. What comes off is only the
compounding, and only on the bodies that live there.

| Rung | Body | Health | Class | What it is |
|---|---|---:|---|---|
| 1 · chaff | **Shoalkin** <br> `character_shoalkin` | 20 | `rogue` | A bone knife and a tail. Numbers in the channel. |
| 2 · line | **Fen Lancer** <br> `character_fen_lancer` | 40 | `fighter` | Works the bank at reach 2 without leaving the water. |
| 2 · line | **Tidecaller** <br> `character_tidecaller` | 44 | `mage` † | Makes the floor the weapon. |
| 3 · elite | **The Undertow** <br> `character_undertow` | 96 | `fighter` | Displacement made flesh. It does not kill you; it moves you. |
| 4 · boss | **Nethrys, the Still Water** <br> `character_nethrys` | 168 | — | The channel *rises*. |

† **The Tidecaller's class declaration is gated on measurement.** The `mage` table grows damage +0
against an enemy scaling of +3, which is what made `class = "rogue"`
[unshippable on a bandit](bestiary.md#class-on-an-enemy-is-a-growth-declaration-not-a-label) — true in
the fiction, one line, obviously correct, and it left a level-20 body unable to hurt an armoured party.
Whether that bites a *caster* depends on how much of a cast's damage comes from the unit's `damage` stat
versus the item's own forge curve, and that has not been established. Declare `mage`, then run
`. balance` and `tests/enemy_scaling_spec.lua` on a mage-classed body at the level cap; the fallback is
`fighter` with the reason in the header. `personalGrowth` is **not** the patch — it is capped at two
points a level across all stats and its own header says it is an identity rather than a second class.

`fighter` is the safe declaration everywhere else: it is `Growth.NEUTRAL_CLASS`, the table every
unclassed body in the folder already grows on, so declaring it costs nothing and says something.

### The bodies

- **Shoalkin.** Bodied chaff: a `weapon_silt_knife` it drops, and the race's own coils. It exists to be
  in the water in numbers and to make the channel feel occupied. Chaff is the commonest hole in this
  bestiary, and a faction whose whole identity is *we are already in the water when you arrive* needs
  bodies to be already in it.
- **Fen Lancer.** [The spear family's rule](weapons.md#spear--knight) is that the status lands on the
  **far** tile — the point reaches past the near body to the rank behind. The Lancer's thrust leaves the
  far tile **Wet**. It stands in the water at reach 2 and works the bank, and it never has to come out.
  The family contract pays for itself: one authored weapon and the body's whole posture falls out of it,
  with no AI to write beyond *hold the water*.
- **Tidecaller.** Two casts: a brine bolt that soaks (`water`, `status_wet`), and a lightning cast that
  arcs through conductable ground. A fen board is mire, shallows and deep water — all three conduct — so
  it is a body that turns the floor into the weapon. **And the player's own lightning does the same thing
  back:** a pack standing in one channel is a pack standing in one conductor, and the race's `−4` is
  waiting for it. The Tidecaller teaches the board's rule by using it, and the answer to it is the rule.
- **The Undertow.** An elite rung is a discipline made flesh, and this one's discipline is
  **displacement**. It stands in deep water and pulls; `Combat.pull` already exists. A body dragged one
  tile toward a body standing in a channel is a body in the channel. Its grid is three items that read as
  one sentence — `weapon_undertow_pike`, `ability_riptide`, `utility_gillscale_wrap` — and all three come
  off it. The discipline gate is a purchase gate, not an equip gate, and the Wrap works the moment it
  falls.
- **Nethrys, the Still Water.** Her phase rule is that the channel *rises*: she turns `water` into `deep`
  around her, a tile at a time, until the board you deployed onto is not the board you are standing on.
  It is the only boss rule this tile makes possible and it would be wasted on anyone else.

### Encounters

- `encounter_the_shoal` — 3–5 Shoalkin and a Fen Lancer, thickening with the day, gated on
  `ctx.biome == "swamp"`.
- `encounter_the_undertow` — `kind = "elite"`, so it opens at `Arena.ELITE_CAP` rather than the four-body
  skirmish ceiling: the Undertow, two Lancers and a Tidecaller. A set-piece that opened at four would be
  the elite and a screen of two, which is not a screen.

Both composed by function over context, the shape `encounter_gluttony_fen_mouth` already ships. The unit
of authoring is the pack, not the body.

---

## What they drop

[The floor picks the rank; the body picks which item of that rank](drops.md#one-draw-two-steps). A
`drops` list is what a body is *known for* — one powerful piece at a low rate, not a complete catalogue.
Run `. drop-report` before authoring the lists and `. drop-tier` for every depth.

### `dropOnly` — sellable, and no counter will ever deal you one

A new flag, and it exists because `unstocked` is **deliberately** priceless in both directions: the file
argues it, and `tests/discovery_spec.lua` pins `sellValue == 0` on every named trophy — *a piece that
exists only where it fell has no market price in either direction.* That rule belongs to the beast
trophies and is not to be softened underneath them to fit six naga items.

So a second flag, saying a different thing:

| Flag | On the rack | Buy | Sell |
|---|---|---|---|
| `bound` | no | no | no |
| `unstocked` | greyed, "monster drop" | no | **no** |
| **`dropOnly`** | greyed, "monster drop" | no | **yes, the usual half** |

`unstocked` = *there is no market for this.* `dropOnly` = *the city does not stock it, but yours is worth
something.* Roughly two lines: `Vendor.lockReason` names it alongside `unstocked`, and `Vendor.stock`
already admits anything carrying a price.

It is **visible and greyed** rather than absent, because that argument is already written down in
[models/vendor.lua](../models/vendor.lua): unstocked pieces used to be invisible at every counter, and *a
player had no way to learn they existed short of meeting the creature.*

Every naga piece takes it, and carries a real house `class` for the shelf taxonomy — a spear is a spear,
and a classless unpriced item never gets a `dropTier` at all, so it would never drop.

### The pieces

| Item | | |
|---|---|---|
| `utility_gillscale_wrap` | **The trophy.** `tags = { "swim" }`. Deep water opens, shallows cost one, drowning cannot touch you. | Depth needs placing by hand: an item whose whole payload is a movement rule grades near zero, the same way a tag-immunity does. |
| `weapon_undertow_pike` | Spear. The far tile is **pulled one tile toward the bearer** — the exact inverse of `weapon_tidesbreak`, which soaks the far tile, drives the line back and steps its wielder into the gap. | The shelf ends with two water spears that read against each other: one pushes and advances, one pulls and holds. **It cannot drown anybody by itself** — see [what the build corrected](#what-the-build-corrected). |
| `ability_riptide` | A lane cast that drags every body in the lane one tile **toward** the caster. | |
| `ability_breaker` | Its twin *(named Breaker, not Surge: that id was already taken by an unrelated ability)* : the same lane, driven one tile **away**. | The geometry is why they are two weapons. Pull takes you into the channel the naga is standing in; push takes you into the channel behind you — so Breaker is the one that works when the nagas are on dry land. |
| `armor_scale_hauberk` | `water +3, ice +2, lightning −4`, and `bonus.movement = −1` because every armour costs a square of pace with no exceptions. | **No naga wears one.** It appears only in `drops`, never in a grid — which is what keeps the coat's `−4` from stacking with the race's. |
| `weapon_brackish_lance` | The Lancer's spear. Far tile left **Wet**. | The cheap piece that teaches the soak-then-conduct pairing in the first fight. |
| `weapon_silt_knife` | A dagger, so it bleeds — and it **strikes harder against a Wet target**. Grit in an open cut. | |

**Wet is the faction's shared verb**, which is what makes the Mere one sentence at every rung: the
Lancer soaks the rank behind, the Tidecaller soaks and conducts, the shallows soak anyone standing in
them, and the knife is what collects on it. Five Shoalkin working a soaked front is a real threat built
entirely out of pieces that already ship.

> **The knife deliberately does not tug.** "Pull the target one tile toward the wielder" is the better
> theme and the wrong rung: a Shoalkin adjacent to a bank tile is standing *in* the water, so one tug
> drowns you, and a pack of five would be chaff that deletes a party member. Displacement is the elite's
> verb and stays the elite's verb.

### Per-body lists

| Body | Known for |
|---|---|
| Shoalkin | Silt Knife |
| Fen Lancer | Brackish Lance · Scale Hauberk |
| Tidecaller | Riptide · Breaker · Scale Hauberk |
| The Undertow | Undertow Pike · Riptide · **Gillscale Wrap** *(low)* |

The Wrap is the piece the whole faction exists to hand over. **What it buys:** the Wrap and the Pike in
one grid means doing to the Mere exactly what the Mere did to you — and on a swamp board, the walls of
the arena become your road. **What it does not buy:** dry land. It is not the Zephyr Striders and must
never be tiered like them.

---

## Build order — all five stages shipped

| | Stage | Cost | Playable at the end of it |
|---:|---|---|---|
| 1 | **The ground** | one terrain row, one predicate, one exception in `footprintCanShift`, one hazard, two blocker swaps, three UI obligations | Swamp and underworld floors with channels that swallow a shoved body — **no naga on the board** |
| 2 | **The race axis** | `models/race.lua`, eight race files, `kind` deleted from 167 blueprints, a stat fold and a grant path | Nothing visible — and `kind` stops being a field an author can get wrong |
| 3 | **The cast** | four blueprints, two encounters, one measurement pass on the Tidecaller | The Mere fights you on its own ground |
| 4 | **The drops** | seven items, one new vendor flag, `. drop-tier` and `. drop-report` | You can take the lane off them |
| 5 | **Nethrys** | one boss blueprint, one phase rule that raises the channel | A mark whose fight changes the board you deployed onto |

**Stage 1 is the whole bet, and it is independent of every other stage.** If a channel that eats a
shoved body is not already a better swamp fight before a single naga exists, nothing under it is worth
building, and the decision to revisit is *a shove does not stop at the bank*.

## What the build corrected

Three things in this document turned out to be wrong when they met the engine, and the corrections are
better than what they replaced. Each is written into the file it belongs to as well.

**The pike cannot drown anybody.** Its drag puts the far body on the *aimed* tile, and a tile-targeted
cast is refused outright when that tile is not walkable (`"blocked tile"`) — so the one aim that would
put somebody in the channel is the one aim the weapon may never name. What drowns you is a **lane cast**:
a knockback along a lane never names the tile it ends on, so Riptide drags a body off the far bank into
the channel between. That is the better arrangement anyway, and it is the faction's own shape one rung
up — the pike sets up, the cast finishes. A weapon that both positioned and killed would have made the
Undertow's other two items decorations.

**`dropOnly` needs no `price` at all.** The plan said it kept one. It does not have to: `Vendor.foundPrice`
derives a found ware's worth from its `dropTier` exactly as it does for every other found ware, so the
flag's only job is to keep the piece off every rack. That keeps the shelf recut's law intact — only
abilities, consumables and a house's opening weapon carry a price — and makes the change about two lines.

**A drowned body needed a third fallen state.** `reviveFallenParty` carries out a body that is
`incapacitated or corpse`, and a drowned one is neither: it leaves nothing on the tile. Without naming
`sank` there, drowning would have been *permadeath by terrain*, arriving silently, in a mode whose
founding law ([the-count.md](the-count.md)) is that a bad trip costs a body on the bench and never a
character. `tests/deep_water_spec.lua` holds it.

### And one thing still open

A naga in the **player's** roster, wearing naga plate, sits at −8 lightning: the race's line and the
coat's, on the same body. That is left as a loadout the player built badly, which is the precedent this
codebase already sets for two conflicting movement items in one grid — *"not a case anyone has to
resolve."* The alternative is a guard that reads a body's race from inside an armour blueprint, which is
one item claiming to know about another sheet.

### And one gate that is a measurement, not a decision

The Tidecaller declares `class = "mage"`, whose table grows damage +0 a level against an enemy scaling of
+3. Whether that bites a *caster* depends on how much of a cast's damage comes from the unit's `damage`
stat versus the item's own forge curve, and that has not been established. Run `. balance` and
`tests/enemy_scaling_spec.lua` on a mage-classed body at the level cap before trusting it; the fallback is
`fighter`, with the reason written into the blueprint.
