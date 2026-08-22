# Identification

Some of what the rift hands up cannot be read. It goes into the satchel as an **Unidentified Weapon**,
sits there unusable, and rides back up the stair to a counter in the city called **The Touchstone**,
which names it for a fee.

The point of the delay is not the delay. It is that **identification is how the rift pays above its own
price band.**

## Why the feature exists

A descent's gear comes off its floors — the Gate's shelf is draughts and a spare blade, and always was
([models/gate.lua](../models/gate.lua)). That put every piece of gear the game can hand over inside one
band: `Spoils.bandPrice` caps what a stop may drop, so a floor could never pay anything dearer than the
road it stood on. An unidentified piece is drawn richer than the band allows, or off a body carrying
something better than the band would ever have rolled, and the fee is what turns that luck into gear.

The second thing it buys is weight on a decision the descent already wanted to make heavier. The way up
is a fixture on every floor, and a floor you climb out of keeps its stair standing open
([models/descent.lua](../models/descent.lua)). A satchel of unnamed blades is therefore a reason to
climb out — the thing `Descent.account` says the extraction prompt was missing.

Wizardry's Boltac, and the lineage is not decoration: `models/gate.lua` opens by arguing that the Gate
*is* Wizardry's castle, a stair with a lamp over it at the edge of a town that holds the counters. This
is one of those counters.

## What is hidden

**The forge level, and nothing else.** An unidentified piece is a real blueprint at a real level, both
decided the moment it dropped; what the player is not shown is which blueprint and which level.

Rolling **bonus stats** onto a found piece — Diablo's affixes, the obvious first cut — was considered
and rejected, for three reasons that are all about this codebase rather than about the idea:

| | |
|---|---|
| **price is derived** | grade → slot → price ([shelf.md](shelf.md), `models/grade.lua`). An item whose power was rolled has a `price` that is a lie, and `Vendor.sellValue` — half of price — pays the wrong number for it forever after. |
| **balance is one unit** | a blow and a coat are one subtractive quantity, measured through `Combat.mitigatedDamage` ([balance.md](balance.md)). Unbudgeted power injects straight into the single figure the whole curve is tuned on. |
| **items are verbs** | an instance carries `aura`, `trail`, `charge`, `waitBehavior`, `traits`, `terrainEase`. A rolled `+2 power` is the least readable thing one of them could gain, and it competes with nothing already on the object. |

The forge level has none of those problems because the game already owns it: every magnitude resolves
per level off an authored curve ([models/curve.lua](../models/curve.lua)), the `+n` rides on the name,
and a save already carries it. A found `+3` axe is a fully-tuned object with no new balance surface, and
is indistinguishable from one bought at that level and hammered up to it — because it *is* one.

## The husk

A sealed instance is **built from nothing rather than stripped down**, and that direction is the whole
leak defence. Sealing by clearing fields off a real instance is a whitelist maintained by hand in the
wrong direction: the day somebody adds a field to `Item.instantiate` — a constructor that already copies
thirty-odd — the new one leaks through every husk in the game and nothing says so.

What survives is exactly what the player may know:

- `type` — which is what the card says: *Unidentified Weapon / Armor / Utility / Ability*
- `id` and `level` — the answer, carried but never drawn
- `unidentified` — **the floor it was found on**, not a boolean

Note what is absent and what it buys for free. No `tags`, so `Item.archetype` answers nil and the
Armory's weapon-family filter chips cannot name the blade. No `discipline`, so its house chip cannot
either. No `price`, so `Vendor.sellValue` refuses to quote it. No `traits`, `aura` or `activeAbility`, so
there is nothing for a tooltip to spill.

**Consumables are never sealed.** A stack merges by id, and two unnamed potions have no id to merge on
without giving away that they are the same potion.

## Where they come from

The split is the honest reading of `models/spoils.lua`'s own doctrine — loot comes off the bodies first —
rather than an exception to it.

| source | chance | the id is drawn from |
|---|---|---|
| an ordinary won fight | 15% | the carried pool |
| an elite | 35% | the carried pool |
| a treasure chest | 35% | **above** the band |

**Off a body**, the fight is its own answer to what it should pay: you took his axe, you simply cannot
read it yet, so the seal hides the *quality* and the connection survives intact. A roster carrying
nothing sealable — a wolf pack, whose fangs are unpriced — pays nothing, which needs no special case.

**Out of a chest**, there is no body to connect to and nothing for a carried draw to preserve. That is
exactly the room this feature needed: a cache seals something dearer than anything the road could
otherwise hand over.

Two things are deliberately absent. **Stair guardians** already pay an authored piece off
`Descent.DROPS`; rolling a husk on top would put two rewards on one body and make the authored one the
consolation prize. And **the campaign seals nothing at all** — `Spoils.rollSealed` pays nothing without
a `floorLevel`. A mystery blade on a road whose shop is three stops away is a delayed reward with
nowhere to collect it.

At most one per stop. Two off one fight makes the counter a chore, and the second is never the one the
player remembers.

## The roll

```
cap    = min(10, 1 + ceil(floor / 2))     -- how high a piece found this deep may read
level  = 1, then each further rung is a 45% coin flip that mostly fails
```

**A floor of one. No duds.** Every reading lands at least a rung above base, so the fee always buys
something and the gamble is *how far* rather than *whether*. A dud outcome would make the counter a slot
machine that sometimes charges you for nothing.

Depth is the only thing the player spends to raise the ceiling, which is the descent's own question
restated in gear. On floor 7 the distribution reads `+1` 55%, `+2` 25%, `+3` 11%, and a tail past what
the bench can reach — a descent-era Forge ceiling sits near `+3`, so most readings land inside what the
Forge could have done and the tail beats it outright. Found gear that outruns the bench is the reward;
the bench then refusing to touch it is the price.

## The bill

```
fee = 60 + 20 × floor
```

**It reads the floor and never the item**, and that is not a simplification — it is the only price that
works. A fee derived from what the piece is actually worth prints the answer on the price tag: a player
who sees one husk quoted at ninety and another at four hundred has identified both without paying for
either. The bill may only ever read facts the player already has, and the floor is the one fact the husk
is allowed to carry.

**The counter buys unnamed goods for exactly what it charges to name them.** One number, two directions.
The symmetry makes selling and naming come out roughly even in gold, which puts the choice where it
belongs — **sell when you are broke, name it when you want the thing.** Without the alternative the fee is
a toll: a click standing between a drop and the item, charged for nothing but the delay.

### Buying it back

A sale is not final. What she takes goes onto her **shelf**, and you can have it back — for **half again
what she paid** (`BUYBACK_MARKUP = 1.5`): sell a floor-13 piece for 320, and it is 480 to redeem.

That premium is the whole of what makes a sale a decision rather than a deposit. At par the counter is a
locker — sell the satchel on the way in, take the gold, redeem whatever you still want later, and the
question the room exists to ask (*name this one, or let it go*) is never actually asked, because letting
it go costs nothing. The markup is the price of having been wrong, and it is small enough to pay when you
were. A doubling would make the first sale unrecoverable in practice, which is the same as having no
buy-back at all.

**She keeps only the last six** (`SHELF_MAX`). A second limit behind the price, not the main one: it stops
the shelf becoming an unbounded second stash the save has to carry and the panel has to draw. The oldest
falls off when a sale pushes past the cap, and what falls off is gone — so the panel always draws the
whole shelf, and **names the piece that fell** in the notice. A shelf that silently drops its oldest is a
shelf that steals; the player chose to sell, they did not choose to lose the other one.

A piece that goes and comes back is *the same object* — same blueprint, same rolled level, same floor.
Selling is a decision about a particular thing, and a redeemed piece that had been quietly re-rolled would
make it a decision about nothing.

It is billed in **gold**, which keeps the Forge's division of labour intact: gold buys *breadth* (a thing
you did not have), technique buys *depth* (a thing you carry, made better), a bond buys *identity*. A
reading hands you a thing you did not have.

## The counter

`data/buildings/the_touchstone.lua`, on the plaza at `490, 480` — directly under The Rift, so what comes
up the stair walks straight into it. It arrives on the first thing nobody can name
(`unlockUnidentified`), the most literal of the six gates the city grows on: the player finds the thing,
cannot use it, and *then* the door is there.

It is a **bench, not a shelf** — it takes something you already own and changes it, the way the Forge
does — so `ui/panels/touchstone.lua` lists what you brought in, one row selected, and the one thing that
can be done to it underneath. Two tabs: the SATCHEL (what you carry — Identify, or Sell) and SOLD (what
she is still holding — Buy back). The Sold tab is not drawn while the shelf is empty, and neither is the
strip: one tab is not a choice. An empty list draws no buttons at all; a control appears where it can be
used.

It also keeps a **keeper**. The left column carries her portrait, her name, the purse and her own line,
laid out exactly as the Cafe's is — every door in this city that offers anything is a person you stand in
front of, and a room that laid out its offer with nobody in it would be the one counter in the city that
was a vending machine. The missing-portrait placeholder takes **no sin tint**: the seven houses colour
theirs by their sin, and this counter is not one of the seven.

It declares a vendor id without keeping a shelf (`sells = false`, the Cafe's own trick), which buys the
whole first-visit greeting path for free and is also what keeps the door standing once it has been
walked through.

## The reading

`ui/panels/identify_reveal.lua` is the Rift's crossing in another material — four beats, in the same
order, for the same reasons. That reveal tells the player a **rank** and this one tells them a **level**,
and a player who has learned to read one should not have to learn the other from scratch. What separates
them is the substance: a rift is air and light, so it breathes and its shape is a ring; this is metal on
stone under a lamp, so it is struck.

| beat | length | what happens | cue |
|---|---|---|---|
| **gather** | ~0.7s | the lamp comes down and the streak is drawn across the slab. Identical every time, carrying no information — the tell needs something to differ from. | `stone.read` |
| **tell** | ~0.55s | the level declares itself in **two channels at once**: the light takes the level's colour, and the marks strike in one at a time. Hue alone fails on a dim panel and for a colour vision deficiency; a count does not. | `stone.mark`, pitched up per mark |
| **surge** | varies | the slab floods, for a length set by the level — so duration is information too. | `stone.reveal` |
| **piece** | held | the item: true name with its `+n`, and its full sheet. | |

The result is decided long before any of this. The panel has already spent the fee and un-husked the
item; what the animation does is **withhold a fact it already holds**. A reveal that rolled at the end of
its own animation would be a reveal a player could close and reopen to reroll.

**The glass breaks on an overshoot.** A piece that climbs its whole ladder, on a floor deep enough for
that to mean something, cracks the lamp over the counter and throws it. Both halves of that rule are
load-bearing: floor one caps at two, so hitting the cap there is a coin flip, and spending the rarest
animation in the game on the commonest outcome would spend it for nothing.

Skippable from the first frame. A player on their fortieth reading is not being taught anything by the
light.

## Files

| | |
|---|---|
| `models/identify.lua` | the roll, the husk, the fee, the reading, the shelf. Pure model, headless-safe. |
| `models/spoils.lua` | `Spoils.rollSealed` — which stops pay one, and out of which pool |
| `models/save.lua` | `unidentified` on an item, written only when set; and `touchstoneShelf` on the profile |
| `models/player.lua` | `takeFromStash` refuses a husk — the single funnel every equip path goes through |
| `ui/panels/touchstone.lua` | the counter: two tabs, three verbs |
| `ui/panels/identify_reveal.lua` | the four beats |
| `data/buildings/the_touchstone.lua`, `data/vendors/touchstone.lua` | the door and its keeper |
| `tests/identify_spec.lua` | including the leak test: a husk's name never contains the true one |
