# Drops

Where a found item comes from, which body hands it over, and why the thing it is known for is the
rare one.

[shelf.md](shelf.md) settles what an item is *worth* and how deep it falls at. This is the other half:
**who drops it.** The two meet at one field — `unlockLevel` says how deep, a body's `drops` list says
whose.

> **A DROP IS A HEAD START, NOT A SOURCE OF RECORD.** This file was written while the rift was the only
> road to a weapon, a utility or a piece of armor: a counter would not deal one until the company had
> carried one out, so a hole in a drop table was content nobody could reach, and most of what follows
> is an audit of exactly that. That gate is gone ([shelf.md](shelf.md)) — a found ware is dealt at its
> class rung whether or not one has ever been hauled up — so **reachability is no longer what a drop
> list is for.** What it is for now is *early* and *free*: the rift pays gear at depths well below the
> rung the company has climbed to, and it pays it for nothing.
>
> Read the census below as a **legibility** measure rather than a coverage one. The question is still
> whether a body is known for something; it is no longer whether the item exists at all. The one place
> the old stakes survive is the [rift-only pieces](#rift-only-pieces) — those are still the only road.

The instrument is `. drop-report` ([tools/drop_report.lua](../tools/drop_report.lua)). Run it before
authoring anything here; it is the only pass in the tree that asks whether an item is reachable at all.

---

## One draw, two steps

**The floor picks the rank. The body picks which item of that rank.** In that order, and the order is
the whole design.

| | |
|---|---|
| **Step 1** | the floor's depth chooses a **rank** — its own rung, and one below (`Spoils.rankBand`). Decided before anything looks at who died, so a floor cannot pay gear that does not belong to it. |
| **Step 2** | the bodies standing there choose **which item of that rank**: what they are known for (`drops`), what they were holding, and their class's stock at that rank — the first two preferred (`BODY_PREFERENCE`). |

If nothing standing there has stock at that rank, the draw falls to anything at that rank. That is a
designed outcome, not a failure: the class ladders are deliberately incomplete, so this rung is how a
Priest body on floor 8 gets paid at all.

Consumables are drawn on a **separate supply track** off price rather than rank, so a potion never
occupies a rank slot — but it shares the fight's drop budget rather than adding to it
(`SUPPLY_SHARE`).

> **What this replaced**, and why: three pools — an authored list, the beaten bodies' grids, and a
> price band — blended by two independent probabilities. That arrangement decided an item's **rank**
> (how good) and its **identity** (what it is) in the same weighted draw, and those are different
> questions with different right answers. It is why every tuning pass landed on one and left the other
> alone — most sharply when correcting the band's inverted weight, an unambiguous bug fix that moved
> the measurement 7.6% → 9.6%, because the band was a quarter of the drops and the other three
> quarters had no depth relationship at all.
>
> **Six constants came out** — `AUTHORED_BIAS`, `CARRIED_BIAS`, `AUTHORED_FALLOFF`,
> `AUTHORED_STANDOUT_SHARE`, `DEPTH_MATCH_SPREAD`, `CARRIED_DEPTH_REACH` — along with the whole
> `authoredCandidates` helper. Four went in, and unlike the six they compose into a sentence.

### The band still exists, underneath

`Descent.DROPS` (a lieutenant's or a general's authored relic) is untouched and sits outside this
draw entirely. And the reachability picture below is still how the catalogue is audited — an item with
no body that knows it is reached through Step 2's third rung, which is the "long tail" the old band
named.

Measured (`. drop-report`), over the 429 items carrying a `unlockLevel`:

| route | at the start | now |
|---|---|---|
| drops (authored) | 0 | **160** |
| carried | 127 | 86 |
| boss list | 78 | **45** |
| band only | 224 | **138** |
| nothing | 0 | 0 |

**Not every item needs a body, and that is the decision.** The band is the long tail: 138 rows reach
the player only through it, and they are meant to. What matters is not total coverage but that each
body's list is *meaningful* and carries one powerful piece at a low rate — so the ~35-body figure in the
bill below is a quality target, not a precondition.

> **Deleting the band was decided and then un-decided, and the record is worth keeping.** It was
> approved in review as *"an authored list replaces the price-band fallback entirely"* — over an
> explicit recommendation to deny it, on the grounds that a wolf pack carries nothing priced and 88
> bodies would each need a complete list before anything shipped. It was never implemented for that
> reason, and the decision was reversed once the per-body work landed and showed what total coverage
> would actually cost. **The band is not a fallback waiting to be removed; it is the route the tail of
> the catalogue takes.**

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

> ### The order is authored and nothing enforces it — measured, 2026-09-21
>
> A floor picks a rank before it looks at who died, so within one list the depth **is** the drop rate:
> there is no per-entry weight, and the piece at the bottom of the list is the chase by sitting deepest
> and by nothing else. That is the design. It is not what the data says.
>
> Walked across **all 51 drop lists in the game, 66 entries sit shallower than the entry above them.**
> The promise is enforced on four bodies — the boar, the sow, the stag and the slime — because those
> four have a spec, and the other forty-seven have none. Nobody had walked the rest.
>
> The four guarded lists are held by hand, at the depths they were authored against
> (`Grade.SLOT_PINS`, "the chase pieces"). `tools/drop_tier.lua` cannot derive them: a chase is often a
> **rule** rather than a number — the Yearling Pelt carries Bereft and grades 1.6, under the claw it is
> supposed to be rarer than — and a grader that reached for a drop list would be reading the placement
> it is there to decide.
>
> **What is undecided is the other forty-seven**, and it is one question: does a body's list own its
> items' depths, and what happens when two bodies want different depths for the same piece? (The Yearling
> Pelt is on two lists already — the sow's and the Undertow's.) Until that is answered, a new drop list
> is authored in the knowledge that only its ORDER ON THE PAGE is authored; the depths come from the
> grade.

Four rules, none of them new:

1. **A body part is never on one.** [bestiary.md](bestiary.md)'s split: bodied chaff carry priced,
   lootable gear; creature chaff carry natural weapons only. A wolf is not a Beastmaster. The gate is
   `noSteal` — read directly by `Spoils`, and skipped by `tools/drop_tier.lua` so nothing mints one a
   depth. It used to be enforced as a side effect of `price`, which stopped being true at the recut and
   put all 92 natural weapons in the drop table in silence. **Demons and undead are unstated in the
   doc**, and that gap is 9 of the 98 placed bodies; `drop_assign` counts them as gear-carrying.
3. **A list is a pool, not a promise.** Whether anything drops stays with `models/spoils.lua`; `drops`
   only says what it draws from.
4. **A list is weighted, and its deepest entry is the chase.** `tools/drop_assign.lua` deals in two
   passes so every body gets one piece deeper than the rest of its list, and `Spoils` weighs that
   entry at an authored share of the whole (`AUTHORED_STANDOUT_SHARE`, 12%) rather than at whatever
   falls out of the depth gap — the gap is whatever a class's catalogue happens to offer, so pinning
   the share is what keeps "the thing this body is known for" worth the same everywhere. Measured:
   **4.5% of fights** against that body.
5. **A held entry declines; it is never re-picked.** The draw runs over the whole list at its authored
   weights, and if it lands on something the company already holds the authored route pays nothing and
   falls through. Filtering to unowned instead — `Descent.dropFor`'s rule, and right for a boss list of
   authored relics — quietly inverts the design on a weighted list: own the four commons and the pool
   is the standout alone, so the rarest thing on the body becomes its guaranteed next drop. That is a
   pity timer wearing a rarity's clothes. Measured, the rate holds at **4.4% with every common held**,
   and duplicates of held commons run at 0.07%. A farmed body goes quiet rather than raining
   duplicates. What made this safe to give up is [salvage](#salvage-and-the-discovery-ledger): a
   duplicate is stock, not a dead end.
6. **What it was holding counts too.** *You took his axe* is the best connection in the system, and it
   survives as a preferred answer **at its own rank** — so the axe is still the drop wherever the axe
   belongs to the floor, and a floor-eight corpse stops handing over a rusted blade.
7. **A body's prize is not preferred.** The deepest entry on a list competes on equal terms with its
   house's other stock at that rank. Preference says *this is its kit*, which is right for ordinary
   stock; applied to the prize it made the piece a body is known for the likeliest thing it pays on
   the one floor that can pay it — measured at 26% of fights, an errand rather than a chase.

### A pin, for what the deal cannot see

`. drop-assign apply` deals from scratch every time — that is what makes the lists auditable — so
anything a human put on one is gone the next time it runs, silently, and the list still reads as
derived. **`dropsPinned` on the body is the exception said out loud:** its ids are seated first,
count against the five, and come off the table so the deal cannot hand them to anybody else.

```lua
-- data/characters/character_fen_lancer.lua
dropsPinned = { "armor_scale_hauberk" },
```

The Scale Hauberk is why it exists. It is naga plate the nagas do not **wear** — a naga already
carries `lightning = -4` and the coat would take the same body to -8 — so falling off a lancer who
never had it on is the only way the race’s own armour reaches a player. No rule in `drop_assign`
can see that: the hauberk is knight stock and a lancer is not a knight, so every re-deal took it
off again. `tests/naga_spec.lua` is what noticed, which is the shape to copy — **pin it and pin it
in a spec**, or the next re-deal is the one nobody checks.

Pin the thing a body IS where the three dealing rules cannot reach it. Everything else is dealt.

### A third route: a trophy on a percent, outside the roll

`drops` and `Descent.DROPS` between them answer *what is this body known for* and *what does this
general owe*. Neither can say **"and sometimes it gives you the thing"** — a list entry competes for
the fight's one or two slots and only at its own rank, and a general's queue is guaranteed and unrolled.

`encounter.trophy = { id, chance }` is the third: a named piece, a flat percent, **added** to whatever
the fight rolled rather than drawn from it, paid at the one payout seam (`EncounterBattle.spoils`) so
the played and the walked-off fight cannot differ. It is **skipped once the company holds one**, which
is `Descent.dropFor`'s rule rather than the weighted list's — right here for the reason it is wrong
there: these are best-not-sum pieces, so a second copy is dead weight, and dealing dead weight in place
of an elite's ordinary roll would make the second of these fights pay *less* than an ordinary body.

One body carries one today — the Mimic's `Still Hungry`
([overworld.md](overworld.md#what-is-in-a-chest-and-what-is-in-some-of-them-instead)) — and the rate is
set against how few of that body exist rather than against how good the piece is: mimics do not re-arm,
so there are about three in a playthrough and nothing can farm them.

> **`unstocked` is a rule about SHOPS, not about the pool**, and every trophy's header glosses over it.
> A piece carrying a `unlockLevel` sits in the band's long tail like anything else — `anyAtRank` filters
> `bound` and `noSteal` and not this — so an ordinary fight at that rank can pay one, and so can a
> chest. That is one row out of a whole rank's catalogue and it is the same backstop all fifteen named
> trophies have had all along. What `unstocked` buys is that **no counter deals or buys one, ever**.

## The bill

```
429 items to place
 51 humanoid bodies placed      ->   8.4 items per list
 98 placed bodies in all        ->   4.4 items per list
```

A legible list is about five — long enough that a body is known for more than one thing, short enough to
read on a card, and roughly what a Monster Hunter reward table runs. Landing at five across the whole
catalogue would want ~86 gear-carrying bodies against today's 51, but the band carries the tail, so that
is a target rather than a bill.

Where it is worth spending anyway is **legibility**, not coverage. Wrath's entire rollable non-boss line
is `character_fighter` — every fight in that circle is the same body repeated, which a player notices
long before they notice a drop table. `. drop-assign` prints the per-class shortfall.

## What the band is still for

`Spoils`' salvage floor is not a roll, so a fight never pays literally nothing regardless. What the band
uniquely carries is **consumables** — now their own supply track, so potions turn up in fights against
people who weren't carrying any — and the long tail of stock no body is known for.

Were it ever removed, consumables would fall entirely to the pre-descent stock decision and the road's
Merchant, which sharpens an intent [shelf.md](shelf.md) already states: *a consumable stays priced
because the stock
decision before a descent has to be makeable.* If it reads badly in play, the dial is the Merchant's
stock, not the band coming back.

## The bestiary is the readout

There is no separate collection screen and no found-count on the rack. **A body's entry carries its drop
list, redacted until you have carried the piece out** — obtaining a drop reveals an entry, and the
redacted rows are what tell the player there is more to be found.

The grammar was borrowed from the shelf, which used to stand an unfound ware on the rack named and
silhouetted with the depth where its price would go — and **this is the only surface that speaks it
now.** The shelf's version came off with the discovery gate ([shelf.md](shelf.md)); nothing on a rack is
redacted any more. So the book is where the question survives, which suits it: *what has this company
seen* was always a bestiary question wearing a counter's clothes.

**Two ledgers, two questions.** `player.met` ([models/bestiary.lua](../models/bestiary.lua)) is which
bodies have been *fought*; `player.found` is which items have been *carried out*. The redaction is the
join: a met body lists every row on its `drops`, and a row not in `found` is drawn as a struck bar
showing only its depth. Nothing new is remembered about items.

`player.found` outlived the gate that created it — it was the counter's, and the counter stopped asking.
**It has one reader now**, which is worth knowing before anyone deletes it as dead: it looks vestigial
from `models/vendor.lua` and is load-bearing from here.

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

**This is the whole of what the rift alone still pays**, now that the shelf deals the rest of the
catalogue on the class rung. Everything else on a `drops` list is a head start; these are the only
pieces where the body is the sole road, for good, at any level and any purse.

The top of the found ladder is meant to be a handful of **authored rule-breakers** — pieces that sit on
no counter ever, drop only deep, and change what a body is allowed to do. That is what a Diablo unique
actually is, and the parked relic shelf already argued the principle for the within-run layer: its
three rungs were *a gift, a trade, an inversion*, each a different **kind** of thing rather than a
different size. The argument stands and the shelf does not — `models/relic.lua` is parked
([relics.md](relics.md)), and its inversions are now the eight `rules` items, which are exactly the
authored rule-breakers this section is asking for.

**The flag is `unstocked = true`**, and it keeps a piece out of the money economy in both directions:
`Vendor.foundPrice` refuses to quote one, so no counter deals it however many you have carried out, and
`Vendor.sellValue` reads the same figure, so none will buy one either.

**The counter still shows it.** `Vendor.stock` admits a trophy on its `unlockLevel` and greys it with
`lockReason = "monster drop"` — *"taken from the body that carries it"*, and the floor it falls around.
Before 2026-09-20 a nil price kept it out of the rack altogether, so a player had no way to learn a
trophy existed short of meeting the creature; a want list nobody can read is not one. What did **not**
change is the price, in either direction: visible is not the same as merchandise. It is **not** `bound` — an
unstocked piece is yours to carry, move, forge and break
([models/salvage.lua](../models/salvage.lua)); it simply is not merchandise. A piece that exists only
where it fell has no market price in either direction, and a duplicate is not a dead end because it
breaks down at the bench.

**It was written for a hypothetical and is now load-bearing.** The flag shipped with no user at all,
against the day somebody authored a unique. What made it live is the other direction entirely: once
every found ware reached a counter at its rung, a piece that should never reach one needed to say so,
and this was already the sentence for it.

### What carries it

**Fourteen blueprints**, and the rule is *what a body is known for* — a hand-written list on a hand-
written animal, not a list `. drop-assign` spread for coverage:

| Body | Pieces |
|---|---|
| `character_boar` | Bristlehide, the Unclosing Spear |
| `character_sow` | Winterhide, the Knapped Claw, the Yearling Pelt |
| `character_the_unseeing` | the Wake, the Treeline Horn, the Last Sounder |
| `character_white_wolf` | Mother's Howl, the Wood Remembers, the Second Bite |
| `character_wolf_alpha` | Ravener's Hide, In and Out |
| `character_wolf_grunt` | Runner's Hide |

**The seven generals' relics need no flag**, and that is worth knowing before anyone adds one: they are
`class = "creature"` with no `unlockLevel`, so no counter could quote one to begin with and `unstocked`
would be inert. The flag is for a piece that carries a real class and a real depth — one the shelf
*would* otherwise deal.

**One piece was deliberately left off.** `utility_endurance` is on the wolf grunt's list but reads as
plain hunter shelf stock at `unlockLevel 2`; it stays buyable, and the grunt dropping it early is exactly
what a head start is. A trophy is a thing named for the body. If it could sit on a rack without anyone
noticing, it is not one.

**Everything else about these is authoring, not engineering**, and that is worth stating because it was
not obvious until the flag was written. A rift-only piece needs no new item type, no new gate and no new
shelf rule — it is an unpriced blueprint with a deep `unlockLevel`, an `unstocked` flag, an authored trait,
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

**The band stays, and that is now a decision rather than a delay.** 136 rows rest on it alone, and the
author's call is that *not every item needs to be droppable by a character* — what matters is that each
body's list is meaningful and carries one powerful piece at a low rate. So the band is the long tail
and the ~35-body bill is a quality target rather than a precondition. Deleting the fallback was decided
in review and reversed; see *The four routes* above.

What is still worth doing for its own sake: **Wrath**, whose entire rollable non-boss line is
`character_fighter`, so every fight in that circle is the same body repeated — a legibility problem
before it is a drop problem.

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

```powershell
& "E:\LOVE\lovec.exe" . drop-sample               # what a floor actually pays, ROLLED
& "E:\LOVE\lovec.exe" . drop-sample 8             # one floor
& "E:\LOVE\lovec.exe" . drop-sample n=20000       # a wider sample
```

**`. drop-sample` is the one that rolls**, and it is the reason the redesign could be judged at all.
`drop-report` walks reachability and `drop-assign` walks assignment; neither throws a die, and every
real defect in this system has been invisible to both — the inverted band weight, the 74% carried
share, the flat lists, the 92 natural weapons in the pool. Each was found by a throwaway spec that
sampled the loop and printed a table, and each was deleted with it. This is that spec, kept.

It found the tier saturation the moment it existed: `min(CLASS_LEVEL_CAP, floor × LEVEL_PER_FLOOR)`
pinned at the cap from **floor 4**, so five of eight floors shared one rank band. `Spoils.rankBand`
spreads the ladder across the whole stack instead, and the report asks the model for the band rather
than recomputing it — an instrument that computes the thing it is checking is checking itself.

`drop-report` writes nothing and has no `apply`: what to do about a hole is an authoring decision, not a
number a tool could compute. `drop-assign` is the one that writes, and it is a dry run until told.

Related: [shelf.md](shelf.md) · [bestiary.md](bestiary.md) · [economy.md](economy.md) ·
[identification.md](identification.md)
