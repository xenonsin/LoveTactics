# Drops

Where a found item comes from, which body hands it over, and why the depth-banded random draw is
being deleted.

[shelf.md](shelf.md) settles what an item is *worth* and how deep it falls at. This is the other half:
**who drops it.** The two meet at one field — `dropTier` says how deep, a body's `drops` list says
whose.

The instrument is `. drop-report` ([tools/drop_report.lua](../tools/drop_report.lua)). Run it before
authoring anything here; it is the only pass in the tree that asks whether an item is reachable at all.

---

## The four routes

| route | what it is | authored? |
|---|---|---|
| **drops** | a per-body list on the character blueprint | yes — the route being built |
| **carried** | the body is holding one, so the carried pool can hand it over | incidental |
| **boss** | `Descent.DROPS` — a lieutenant's or a general's list | yes |
| **band** | the depth-banded random draw over everything in range | no — **being deleted** |

Measured today (`. drop-report`), over the 429 items carrying a `dropTier`:

```
drops (authored)        0     a body's own list
carried               127     a placed body is holding one
boss list              78     Descent.DROPS, walked unowned-first
BAND ONLY             224     <- the random draw
NOTHING                 0     <- no route at all
```

**Nothing reads as unreachable only because the band catches everything.** That is the whole reason the
number above is zero and the reason it is not reassuring: deleting the band turns those 224 rows into
items with no route, which is why the fallback cannot go until the bodies exist.

## Reachability is placement, not authoring

An item named on a body's list is not reachable unless some encounter seats that body, and an encounter
does not seat a body unless its `condition` passes somewhere on the calendar. So `. drop-report` takes
its census by sweeping `Encounter.pool` over real contexts and resolving each blueprint's own
`composition` — the same call the overworld makes — rather than by reading ids out of the files.

The difference is not academic. A read of the data finds 88 bodies; the sweep finds **83**, because five
sit in encounters that never actually pass. And **71 of the 154 character blueprints are never placed by
anything**, which no amount of reading the character folder can see.

```
83 of 154 blueprints placed          humanoid 36 · beast 18 · construct 10
                                     elemental 9 · demon 6 · undead 3 · object 1
5 bodies gated to each circle         (by the encounter's biome condition)
48 ungated                            appear on any floor, so no circle owns them
```

## A boss list is a queue, and position is reachability

`Descent.dropFor` walks a list and pays the **first piece not already owned**. That rule is right — a
body never hands you a duplicate while it still has something new — but it means a long list is a queue,
and a circle is visited once per descent. **An entry's position is a count of complete runs to that
circle.**

The seven generals carry 4–21 items each. **31 items sit past position 6**, thirteen of them behind
Acedia, whose twenty-first entry needs twenty-one separate descents to Sloth.

They got there honestly: when the Quest Board was retired, 64 unpriced pieces lost their only source in
one stroke and were parked on the generals. Every one belongs to its circle, so the *placement* is right
and the *concentration* is not. They move onto that circle's ordinary bodies; each general keeps her
authored relic — the first entry, the one the fight is about — and a circle stays a two-piece set.

> [shelf.md](shelf.md)'s standing obligation is what this measures against: *a shelf guarantees an item
> is reachable; a drop table does not, and any item whose honest answer is "not at the depths people
> play" is content that does not exist.*

## The `drops` field

On the character blueprint, like everything else — one Lua file per entity, a list rather than a table
so the order is the authored priority:

```lua
-- data/characters/character_the_gilt_wyrm.lua
drops = { "weapon_throughline", "armor_slipstep_leathers" },
```

Four rules, none of them new:

1. **Walked unowned-first**, exactly as `Descent.dropFor` does. The guarantee D2 never had.
2. **Creatures carry none.** [bestiary.md](bestiary.md)'s split: bodied chaff carry priced, lootable
   gear; creature chaff carry natural weapons only. A wolf is not a Beastmaster. The engine already
   enforces this economically — 33 items are `noSteal` and `Spoils` uses `price` as the shoppable
   marker. **Demons and undead are unstated there**, and that gap is 9 of the 83 placed bodies.
3. **A list is a pool, not a promise.** Whether anything drops stays with `models/spoils.lua`; `drops`
   only says what it draws from.
4. **The carried pool stays.** *You took his axe* is the best connection in the system
   (`CARRIED_BIAS = 0.75`). `drops` sits beside it: what a body is *known for*, over and above what it
   happened to be holding.

## The bill

```
429 items to place
 36 humanoid bodies placed      ->  11.9 items per list
 83 placed bodies in all        ->   5.2 items per list
```

A legible list is about five — long enough that a body is known for more than one thing, short enough to
read on a card, and roughly what a Monster Hunter reward table runs. **Landing at five needs ~86
gear-carrying bodies, against today's 36.**

So "each circle gets more bodies of its own" is not a separate nice-to-have. With the band deleted every
item must sit on a list, and the number of gear-carrying bodies *is* the list length. The two decisions
are one piece of work, and the bodies come first. Ten to twelve per circle lands it, and fills
[bestiary.md](bestiary.md)'s open chaff gap with the same authoring.

## What deleting the band costs

Narrower than it looks. `Spoils`' salvage floor is not a roll, so a fight never pays literally nothing
even with no band. What actually goes is **consumables as drops** — `CARRIED_BIAS` deliberately keeps a
slice of the band so potions turn up in fights against people who weren't carrying any.

That pushes consumables entirely onto the pre-descent stock decision and the road's Merchant, which
sharpens an intent [shelf.md](shelf.md) already states: *a consumable stays priced because the stock
decision before a descent has to be makeable.* If it reads badly in play, the dial is the Merchant's
stock, not the band coming back.

## The bestiary is the readout

There is no separate collection screen and no found-count on the rack. **A body's entry carries its drop
list, redacted until you have carried the piece out** — obtaining a drop reveals an entry, and the
redacted rows are what tell the player there is more to be found.

That is the same grammar `Vendor.stock` already uses for a ware you have not found: a named, silhouetted
row with the depth where its price would go (`lockReason = "undiscovered"`). One notation, two surfaces.

**Two ledgers, two questions.** `player.met` ([models/bestiary.lua](../models/bestiary.lua)) is which
bodies have been *fought*; `player.found` is which items have been *carried out*, and it already existed
because the counter reads it. The redaction is the join: a met body lists every row on its `drops`, and a
row not in `found` is drawn as a struck bar showing only its depth. Nothing new is remembered about
items.

**Met is stamped at the fight, not at the surface** — in `EncounterBattle.spoils`, so the fought path and
the walk-off path fill the book identically. `found` stays at the surface, and the split is deliberate:
what opens a shelf line is carrying a thing *out*, but what fills in an entry is having stood in front of
the body. A run that wipes on floor six has still met floors one to six.

**The panel never prints an unfound name.** The model hands one over so a found row can be drawn, and
printing it for an unfound row would be the husk leak in another material — the striking *is* the
information. The book opens from the Gate ([states/gate.lua](../states/gate.lua)), because that is where
the question gets asked.

## Salvage and the discovery ledger

A duplicate breaks down into its own house's stock rather than selling at half price — the junk becomes
depth on the thing you carry. A **first** copy may be salvaged too; that is a real choice rather than a
disposal chute.

**Which obliges one line.** `Player.recordFound` stamps at the *surface*, walking roster grids and the
stash — not at pickup. A piece salvaged underground is never in the stash when that fires, so without a
mark in the salvage path, salvaging a first copy silently burns that item's vendor line forever. The
Touchstone already set the precedent for refusing that: a sale there is not final, because *a shelf that
silently drops its oldest is a shelf that steals.*

## Rift-only pieces

The top of the found ladder is meant to be a handful of **authored rule-breakers** — pieces that sit on
no counter ever, drop only deep, and change what a body is allowed to do. That is what a Diablo unique
actually is, and `models/relic.lua` already argues the principle for the within-run layer: its three
rungs are *a gift, a trade, an inversion*, each a different **kind** of thing rather than a different
size.

**One flag was missing and now exists.** `unstocked = true` on a blueprint keeps a piece out of the
money economy in both directions: `Vendor.foundPrice` refuses to quote one, so no counter deals it
however many you have carried out, and `Vendor.sellValue` reads the same figure, so none will buy one
either. It is **not** `bound` — an unstocked piece is yours to carry, move, forge and break
([models/salvage.lua](../models/salvage.lua)); it simply is not merchandise. A piece that exists only
where it fell has no market price in either direction.

**Everything else about these is authoring, not engineering**, and that is worth stating because it was
not obvious until the flag was written. A rift-only piece needs no new item type, no new gate and no new
shelf rule — it is an unpriced blueprint with a deep `dropTier`, an `unstocked` flag, an authored trait,
a weight in `Grade.TRAIT_GRADE` (or a pin in `Grade.SLOT_PINS`), and a place on some body's list. Traits
are data files hanging off existing hooks (`onAnyDeath`, `onAnyCast`, `onAllyStrike`, `onDamaged`,
`onStatusApplied`, `onSummonLost`), with `ctx.damage`, `ctx.heal`, `ctx.applyStatus`, `ctx.summon` and
`ctx.log` to build from — so a new rule costs a file, not an engine change.

The natural home is the **first entry on a general's list**, beside her relic — the one place already
authored for *the piece this body pays for being put down*. Greed and Envy are the obvious candidates:
both came out of the trim holding a single entry.

## Where it stands

Measured after the first pass (`. drop-report`):

| route | before | now |
|---|---|---|
| `drops` (authored) | 0 | **160** |
| carried | 127 | 88 |
| boss list | 78 | **45** |
| **band only** | 224 | **136** |
| nothing | 0 | 0 |

Placement went from 83 bodies to **98** on seven new circle-gated encounters and no new blueprints —
eighteen class exemplars were authored and never seated. The longest boss queue fell from 21 to 11, and
items past reachable position from 31 to **21**.

**136 rows still rest on the band, so the band cannot go yet.** That is the whole of what is left: the
bill above wants ~35 more gear-carrying bodies, and until they exist deleting the fallback would strand
every one of those items.

## Running it

```powershell
& "E:\LOVE\lovec.exe" . drop-report                # the ledger
& "E:\LOVE\lovec.exe" . drop-report unreachable    # only what nothing pays
& "E:\LOVE\lovec.exe" . drop-report queued         # only what sits past the end of a boss queue
& "E:\LOVE\lovec.exe" . drop-report bosses         # what a general can now let go of
& "E:\LOVE\lovec.exe" . drop-report bodies         # the placement census on its own

& "E:\LOVE\lovec.exe" . drop-assign                # the proposed per-body lists
& "E:\LOVE\lovec.exe" . drop-assign full           # ...every body and its list
& "E:\LOVE\lovec.exe" . drop-assign apply          # write them onto the blueprints
```

`drop-report` writes nothing and has no `apply`: what to do about a hole is an authoring decision, not a
number a tool could compute. `drop-assign` is the one that writes, and it is a dry run until told.

Related: [shelf.md](shelf.md) · [bestiary.md](bestiary.md) · [economy.md](economy.md) ·
[identification.md](identification.md)
