# The shelf

Where an item sits, whether it is for sale at all, and why none of it is authored by hand any more.

Every item names a **slot** (`unlockLevel`, its rank on its class's ladder). Most items name **no
price**, because most of the catalogue is priced from the other axis:

```
grade  ->  slot  ->  price        (abilities, consumables, a house's opening weapon)
grade  ->  slot  ->  unlockLevel     (everything else: weapons, utilities, armor)
                      |
                      +-- the depth the rift gives it up at
                      +-- the rung a counter deals it at, and what it charges
```

An item's **grade** is what it is worth. Its rank within its class sets its **slot**. For the small
priced half, the slot sets its **price**; for the rest, the grade sets the **depth**, and the depth
then answers both the shelf questions too. Nothing flows the other way, and two specs enforce that.

- The grader: `models/grade.lua`
- The instruments: `. grade-report [full | diff | explain ID | traits | apply]` and
  `. drop-tier [recut] [apply]`
- The guards: `tests/grade_spec.lua`, `tests/discovery_spec.lua`

> **The field is still called `unlockLevel` and no quest has opened a shelf for some time.** The name
> survived three re-cuts because renaming it means touching every blueprint in the game to change
> nothing, and a 485-file rename that subtracts nothing is 485 chances to be off by one. It means *the
> rung*, and the rung is a class level (**The slot**, below).
>
> **It stays on an unpriced ware, and that was learned the hard way.** It looks like shelf furniture
> once a thing is not for sale — but the rung IS the grade rank, and `models/balance.lua` reads it as
> the item's power level. Stripping it in the recut made two hundred blueprints answer slot 0, every
> one of them measured against the opening rung's budget. So the field stayed.
>
> **And it is still not the gate on an unpriced ware** — but for the opposite reason it was not before.
> It used to be no gate at all, because finding one was the whole gate. A found ware is gated on its
> rung now like everything else; that rung is just derived from `unlockLevel` rather than read off
> `unlockLevel`, because **145 of the 362 carry no `unlockLevel` at all** and of those that do, nine
> agree with their tier. The row reports what it was actually measured against as `rung`
> (`Vendor.lockReason`), and every reader that asks *how far must the class grow* reads that one.

---
## The recut, and the discovery gate that came off it

The recut took `price` off everything a house sold above its **opening weapon** — 362 blueprints — and
that half stands. Above the opener nothing carries an authored price; a weapon, a utility or a piece of
armor carries a `unlockLevel` instead, and what a counter charges is derived from it.

| Kind | Reaches the player by | Carries |
|---|---|---|
| Ability | bought, on the class ladder | `price`, `unlockLevel` |
| Consumable | bought — the stock decision before a descent has to be makeable | `price`, `unlockLevel` |
| Opening weapon (rung 0) | bought — the floor that re-arms a company holding nothing | `price`, `unlockLevel` |
| Weapon, utility, armor above that | bought at its rung, or **found early** | `unlockLevel` (the rung *and* the price) |
| A body's own trophy | **found, and only ever found** | `unlockLevel`, `unstocked` |

**The floor is the rung, not the word "iron".** Nine of the ten iron weapons sit at `unlockLevel = 0`,
but two houses have no iron anything — the Cathedral's rung 0 is a censer and the Alchemist's is a
lancet. Cutting on the name would leave two of seven classes with no purchasable weapon at all. Cutting
on the rung covers all seven exactly once and is derived, so a later re-cut of the ladder moves it.
`. drop-tier recut` reports what each house still sells and warns if a **root** class loses its floor.

### What came off: a found ware is no longer gated on having found one

The recut's second half was a **discovery gate**: a found ware stood on the rack named, silhouetted,
with the depth it falls at where its price would go, and no counter would deal one until the company
had *carried one out*. The argument was that a house should be a **want list** that sends the player
down a stair, where a catalogue was a checklist that sent them shopping.

**It was reversed, and by the obligation stated two paragraphs below it.** A shelf *guarantees* an item
is reachable and a drop table does not — and measured, **157 wares reached the player through the price
band's long tail alone**, 21 sat past the end of a boss queue, and 145 of the 362 carried no authored
rung to be placed by. A player who wanted the Lodge's kit had nowhere to go and get it. Meanwhile gold
bought abilities and draughts and nothing else.

So the two roads part by *when* rather than by *whether*:

> **The rift is the head start. The class ladder is the backstop.**

Grow a class and its shelf deals deeper, at a price. Go down and the same gear falls out for nothing,
at depths that reach well below the rung you have climbed to. A find is worth what it always was — it
is simply no longer the only door.

**So class level is the only gate.** `"rung"` reads it directly (`Quest.shelfRung`, the roster's best
holder in that class) and `"class"` reads it one step removed -- an earned discipline is itself unlocked
by class levels, so "grow the class" is the answer to both, at different distances.

Three refusals now, three words, one field (`Vendor.stock`'s `lockReason`):

| `lockReason` | What the player does about it |
|---|---|
| `"rung"` | grow the class |
| `"class"` | unlock the discipline |
| `"monster drop"` | go and kill the thing that carries it |

### The third: a body's own trophy is visible and never sold

`unstocked` is the one thing a found ware can say that keeps it off a counter forever (`Vendor.foundPrice`
answers nil, so `Vendor.sellValue` answers 0 too). That has not changed. **What changed is that it is now
ON the rack.**

Until 2026-09-20 a price of nil meant the piece never entered `Vendor.stock` at all, so the rarest things
in the game -- the boar's hide, the sow's pelt, the relic a general is put down for -- were *invisible* at
every counter. A player could not learn they existed short of meeting the creature.

A shelf that shows them and refuses them is a **want list** again, which is the job the discovery gate
used to do and did badly: that one shut a ware until you had already got one, which is a checklist
pretending to be a want list. This refusal is permanent and honest, it names a road rather than a lock --
*go and kill the body that carries it* -- and it costs the counter nothing, because a trophy was never
merchandise in either direction.

**There is one rung and it is `unlockLevel`** — the class level that opens a ware on a shelf, and the
floor the rift gives it up at, in one number. It used to be two. A priced ware named `unlockQuests`, a
grade rank carrying the name of a retired quest board; everything else named `dropTier`, a depth
counting from 1 where a class level counts from 0, so the gate read `price and unlockQuests or
dropTier - 1` and 231 blueprints carried both with nothing on them saying which governed. Measured
before folding, the two axes already agreed within a single rung on four fifths of the set, so they
were one ladder wearing two names and an off-by-one (`tools/ladder_fold`).

The fold also closed a hole nobody could see: `Balance.slotOf` read the priced field, which two fifths
of the catalogue did not carry, so those items were judged at slot 0 — the family's base magnitude,
which anything clears. Giving every ware its true rung put 84 of them under a real target for the
first time, most of them deep rift gear sitting at half the power their depth implies.

Rungs run `0..CLASS_LEVEL_CAP` and so do class levels. **Nothing is gated past the top of the ladder
that opens it**, and rung 0 is the opening rack — held from the first morning, and the one rung no
floor pays, because a floor pays what is deeper than nothing.

**What a found ware costs** is `Vendor.foundPrice`: its `unlockLevel` read as the slot it would have had,
off by one so the shallowest find prices level with a house's opener. `Vendor.sellValue` uses the same
figure, or a duplicate hauled out would be a thing the player could neither use twice nor sell.

### What stays rift-only: `unstocked`

The exception is small and authored one piece at a time: **what a body is known for**. The boar's hide,
the sow's pelt, the white wolf's teeth, the relic a general is put down for. `unstocked = true` makes
`Vendor.foundPrice` refuse to quote one, which refuses a sale in the same stroke — a piece that exists
only where it fell has no market price in either direction.

**It is shown and refused, not hidden** (see the third lock reason above). Until 2026-09-20 a nil price
also kept the row out of `Vendor.stock` entirely — *not greyed, gone* — which was a side effect of
having no price rather than a decision, and it meant the rarest pieces in the game could not be learned
about at any counter. `Vendor.stock` admits them on their `unlockLevel` now, and they wear
`lockReason = "monster drop"`. See [drops.md](drops.md#rift-only-pieces);
`tests/discovery_spec.lua` holds it.

Fourteen blueprints carry the flag. The seven generals' relics need none: they are `class = "creature"`
with no `unlockLevel`, so no counter could quote one to begin with.

**The obligation, which survives and is now met structurally.** A shelf *guarantees* an item is
reachable; a drop table does not. That sentence is why the gate came off: reachability was statistical
for a year and is structural again. Any item whose honest answer is "not at the depths people play" is
content that does not exist — and outside the fourteen, no item's answer is that any more.

**A floor hands over nothing ranked or gated deeper than it reaches** (`Spoils.depthOf`). Two numbers,
and the answer is the deeper of them:

| | Where it is read | What it answers |
|---|---|---|
| **Rank** | `unlockLevel`, or `unlockLevel + 1` for a priced ware | how dear a thing is |
| **Class gate** | the highest level in the class's `requires` (`Class.gateLevel`) | who is allowed it at all |

The second half is the one a grade cannot see and must not: the grader reads what a thing *does*, and a
grade that read a gate would be reading its own output. So a Warden charm with small numbers on it
graded shallow, and the deepest-gated kit in the game fell out of floor one — 26 earned-class items sat
at `unlockLevel` 1 or 2, one of them behind an eight-rung gate. A vendor already greys a crossing's stock
until the crossing is earned; the rift now refuses it for the same reason and reads the same field.

The gold band still applies on top for a priced ware. *How dear* and *how deep* are different
questions, and neither stands in for the other. The one place the rank half is loosened is a **sealed**
find: a chest exists to reach above the floor's own band, so it reaches `Spoils.SEALED_REACH` rungs past
it — but never past a class gate, which is skipping rather than reaching.

Related: [balance.md](balance.md) is about bodies against weapons — how hard a thing hits and how
much a body takes. This is about where a thing *belongs*. The two meet at one place: the slot a grade
assigns is the slot `Balance.slotTarget` then reads to grant the item its magnitude.

---
## Why this exists

Every shelf gate in the game was written by one pass, `tools/unlock_rescale.lua`, which ranked each
house's stock by `(retired wave enum, PRICE, id)` and spread it evenly by count.

**Price is a cost, not a grade.** Worse, it does not even sort by power — it sorts by *category*,
because the item types are priced on different scales for reasons that have nothing to do with
strength. A consumable is cheap *for being one-shot*; a passive utility is dear *for being
permanent*. Measured across the 484 priced items, that ordering produced:

| band | weapon | ability | armor | utility | consumable |
|---|---|---|---|---|---|
| early | 17% | 44% | 5% | 15% | 17% |
| mid | 9% | 54% | 6% | 22% | 7% |
| **late** | 16% | 36% | 8% | **35%** | **2%** |

The last third of every shelf came out a third passive charms, with consumables drained almost
entirely out of it. That is the sort key showing through, not a design.

It stopped being cosmetic when the slot became the grade (see [balance.md](balance.md), rule 8):
`Balance.slotTarget` reads `unlockLevel` and *grants* the item its magnitude. So the power ladder
was anchored on a field assigned by price — and `Balance.itemMagnitude` could not notice, because it
derives the target it checks from the same field it is checking.

## The utility stat pass, and the re-tier it caused

186 of 221 utilities now carry a `bonus`; 46 did before. The 140 added by
`tools/utility_stats.lua` are small flat modifiers chosen to reinforce what each item already does —
`movement` on every piece of footwear, `magicDamage` across the Arcanum's workings, `skill` on the
Lodge's aiming kit, `luck` on the Undercroft's guile — with a handful carrying a deliberate malus
where the item already describes a bargain.

**Why it matters here:** a utility with no stat at all was hard to weigh against one with a stat,
because the player had no common unit to compare them in. On a 3×3 grid where every cell is a
decision, that made the type read as two different kinds of item wearing one name.

**And it moved the shelf.** Adding graded value to 140 blueprints pushed **99 items out of the slot
their grade put them in** — 38 of which were pre-existing drift, and 61 caused by the pass. That was
settled the way the doc prescribes and in this order:

```
. grade-report apply        # 99 blueprints rewritten: unlockLevel + price
. balance-rescale 0 apply   # 29 magnitudes refitted to the slots that moved
```

Never stop after the first of those. A slot move *is* a magnitude change — `Balance.slotTarget` reads
the field `grade-report` just rewrote — so applying the grade alone leaves every moved item out of
band by construction, which is what the tool says on its way out.

It settles at **4 of 485** still wanting to move. Those are ±1 residue from the rescale feeding back
into the grades it was computed from, and chasing them oscillates: grade → slot → magnitude → grade.
Four is the resting state, not an unfinished job.

Two things the pass deliberately left alone: the 46 utilities that already carried a bonus (skipped
by inspection, so hand tuning survives a re-run), and the **35 classless ones**, which are creature
kit rather than shelf stock — "sheds a pair of petal-drifts as it is wounded", "on death: bursts". A
stat bonus on those is an enemy power buff and belongs to a bestiary pass. Worth knowing that 61 of
the 140 that *were* changed are carried by characters, so this already buffs some enemies as a side
effect.

---

## The grade

**The unit is damage**, against the reference body, at one fixed standing (`Grade.PRESTIGE`).
Everything converts through `Grade.turnValue()` — what one body's turn is worth in damage — so a
stun, a fireball and a `+3` charm are quoted on one scale. The authored knobs are in **turns** and
**percent**, which is what a designer can argue about; the arithmetic that turns those into damage
stays in the module.

**It is a margin, not a total.** An active item is graded on what it adds to the turn it is spent
on, *net of the swing it replaces* — spending your action on it means not swinging. A passive is
graded on what it adds to every turn, with nothing subtracted, because it costs no action.

**A grade may come out negative**, and that is a reading rather than a fault. An ability that spends
a whole turn to do less than a swing scores below zero and says so. `ability_pull` — one body hauled
one tile, no damage — is the standing example. Nothing is clamped: clamping would pile every weak
item at zero and take the ranking away exactly where it is most useful.

### It may never read the slot or the price

Not as a hint, not as a tiebreak. Both are downstream, and a grader that peeked at either would be
the tautology this file exists to break. `grade: the slot cannot move a grade` and
`grade: price cannot move a grade` assert it.

There is a second payoff: **166 quest rewards carry neither field**, and a grade leaning on them
could not have graded a single one.

### It may not read the item's own damage either

This one is subtler and it closed a real loop. Since the slot grants the magnitude, an item's damage
number says *which rung it is on* and nothing whatever about the item. Reading it closed the chain:
grade set the slot, the slot granted the magnitude, the magnitude fed the next grade. The pass still
converged — in about three rounds — but converging because a loop is damped is not the same as being
right.

So the magnitude is **overwritten with the family base's own unforged power** before the effect is
replayed. Two plain weapons of a family then grade identically, which is exactly the design's claim:
*two items sharing a slot share a magnitude; the effect is the whole of what distinguishes them.*

What survives normalization is everything that is really the item: how many bodies the blow reaches,
what it inflicts, what it leaves standing, what it multiplies itself by, what it drinks back, and
what it costs in tempo. `grade: an item's own damage cannot move its grade` asserts it.

> The ordinary blow needs no second subtraction — the margin already *is* one. A normalized
> single-target swing lands about what a turn is worth, pays a turn for itself, and comes out at
> nothing. Netting the baseline off as well would bill the same swing twice.

### Where the numbers come from

An item's effect is a Lua function, so it is not read by scanning source. It is **dry-run through
`Combat.abilityOutput`** — the same inert replay the inventory tooltip uses. That is the game's own
answer to "what does this do", it already handles AoE, carried statuses, summons and placed ground,
and it is preview-safe by construction.

- **Statuses** are valued off their own blueprint fields (duration, magnitude, the disable flags), so
  retuning a status in `data/status` moves every item that inflicts it. Capped per application by
  `Grade.STATUS_VALUE_CAP`: the components are additive, and Frozen sets four of them at once.
- **Traits** cannot be derived — they are hook functions — so each carries an authored weight in
  `Grade.TRAIT_GRADE`, in turns per fight.
- **Keywords the dry run cannot see** are read off the ability directly. `lifesteal` is folded into
  `Combat.dealDamage` rather than being an `fx` call, and it is the entire difference between the
  Crimson Greataxe and the iron axe it is meant to tower over.

---

## The slot

Each class's stock is ranked weakest-first and dealt across `0 .. rungs - 1`, where **a rung is a level
of the class ladder** — `Class.CLASS_LEVEL_CAP`, sixteen rungs at every class. `tools/grade_report.lua`
reads the count off `models/class.lua`, so the shelf cannot disagree with the thing that opens it.

### How many a rung deals, and why it is not the same number every rung

**`tools/shelf_curve.lua` owns the curve, and before it nothing did.** Two passes write `unlockLevel` —
`grade_report` deals a class's *priced* stock, `drop_tier` its *finds* — and a player meets the SUM of
the two at one counter. Neither could see the sum. Measured through `Vendor.stock` at the Bastion, the
rungs opened `5 2 5 1 3 3 9 4 3 5 7 5 7 2 6 0`: nine wares at knight 6, one at knight 3, and nothing at
all for fifteen floors of committed play. Across the seven houses **fifteen of the 112 rungs opened
nothing**.

Three things fixed it, and they are one change:

| | |
|---|---|
| **A ramp, shallow first** | A rung deals about a third at the bottom of the ladder what it deals at the top. A company's first morning holds a few hundred gold and can act on two or three choices; eight is a wall to read rather than a decision to make. Every rung is handed one ware before the ramp distributes the surplus, so a rung can never deal none. |
| **Rung 0 is the re-arm floor** | The graded spread starts at rung 1 (`SHELF_FLOOR`). Rung 0 holds a house's opener weapons and the wares an author has pinned as gated by nothing — the standing draughts, a torch, a rock, the prologue's teaching spell. It was the **fattest band in the game**, 56 wares against a mean of 41, because the spread dealt its bottom share there *on top of* the openers. It holds 28, and all but thirteen of those are supply. |
| **The finds are cut per class** | `drop_tier` used to rank every find in the game together and spread that one list over the depths. A tier is a CLASS level, so a house with a thin catalogue had its finds bunched wherever its grades fell in the global ranking. Cut per class, a floor gives up the gear that floor was fought at, for every class. |

The result, measured the same way — what each counter newly opens at rungs 0 to 15:

```
alchemist        7  2  2  2  2  2  3  2  2  2  2  3  2  2  3  2      (40)
arcanum          5  2  3  3  3  3  3  4  4  4  3  4  4  6  4  5      (60)
bastion          3  2  2  4  4  2  4  4  3  6  4  6  4  5  6  5      (64)
cathedral        1  2  2  3  2  3  3  2  3  4  2  3  4  3  4  3      (44)
colosseum        4  2  3  4  2  3  3  4  3  3  4  4  4  4  4  3      (54)
hunters_lodge    4  1  3  3  2  2  3  2  2  4  3  4  3  3  3  2      (44)
undercroft       3  1  2  3  3  1  2  2  2  3  2  4  2  3  1  2      (36)
```

The Crucible's seven on the opening rung are six standing draughts and its lancet; every other house's
is its opener weapons. Its *gear* at rung 0 is one piece, which is what the spec counts.

`tests/unlock_ladder_spec.lua` holds all three: every house-rung opens something **buyable**, the opening
rung stays a floor rather than a rack, and the city's top quarter deals more than its bottom quarter.

### Where the per-class cut stops

**A band thinner than the ladder keeps the rift's own global order.** A body's drop list is not one
class's — the boar hands over plague knight, beastmaster and necromancer gear — and within one list the
**tier is the rarity and nothing else** ([drops.md](drops.md)). Cut per class, a tier stops being
comparable across classes: a strong piece in a thin house comes out shallower than a weak piece in a fat
one. Applied to everything, that turned five chase pieces into common drops.

So the cut is per class only where a class can fill a ladder. Exactly the **seven root classes** carry
enough finds — 20 to 57 against fifteen tiers — and all forty disciplines carry ten or fewer. A band that
thin cannot shape a shelf whatever it is dealt, so it keeps the global grade order and the shelf loses
nothing. The threshold is the curve's own (`n >= rungs`), so the two cannot drift apart.

**An `unstocked` trophy is dealt in its own band** for the same kind of reason: it stands on the rack
named and greyed and is never for sale, so it cannot pay for a rung. Dealt together with the sellable
stock, a class level whose whole intake happened to be trophies opened nothing buyable — the Lodge had
one, where hunter 5 held the bristlehide and the ravener's hide and nothing else.

### And supply is not progression

The nine draughts on the town counter sit at rung 0 and are pinned there (`Grade.SLOT_PINS`, "standing
supply"). A rung is a **gate**, and a gate on a healing potion prices a need, which is the one thing
[economy.md](economy.md) says this game will not do. Three of the nine were already pinned and six were
not — not a decision, but rung 0 being fat enough that nobody had to say why. Thinning it took the six up
the ladder and `Market.isStaple`, which reads rung 0 to mean *what a body starts with*, came out selling
three draughts of nine with a mana potion behind alchemist 3. The proxy had expired; the pins say it
outright now.

> **This is the second re-cut, and the first one is worth keeping in view.** A rung used to be *a job the
> house asked for* — its opener plus every quest a discipline hung off, six per house — and before that
> one rung per authored quest, twelve of them. Twelve meant two or three wares an errand at the bottom of
> a shelf, a job run for a tooltip. Six meant 10–15, an unlock you feel arriving. Nine means a little
> under ten, and the difference now is that the thing being counted is not work at all.

**A class is climbed by a BODY, not bought by a company.** `Discipline.classLevel` reads cumulative
technique — two an action, banked into the class the body is standing in (`Class.techniqueFor`) — so what opens a rung is having
played the class, and the shelf reads the roster's best holder (`Quest.shelfRung`). Specializing one
character opens the deep end; spreading the same tally over four does not, which is the same reading the
forge ceiling and every other company-facing question about the ladder take.

**Level 0 IS rung 0**, with no offset. The old gate read the house's standing *less one*, because a
house's first errand was its opener and slot 0 was what the opener handed over — without the offset a
freshly opened door showed its bottom band *and* the band the opener had just earned. Nothing opens a
door any more, so a body with no commitment to a class sees that class's bottom band and nothing above
it, which is what a bottom band is for.

**The shelf and the descent are still one ladder read from two ends**, and the mechanism changed rather
than the claim. It used to be seating: an errand was found on the floor its own slot belonged to. It is
now the other direction — you climb a class by fighting with it, and you fight with it deeper as you go,
so the gear a floor buys is the gear that floor was fought at without anything having to place it.

**Two bands, spread separately.** The base shelf runs the whole ladder; the discipline cut starts at
slot 3. Spreading them together and clamping afterwards piles every low-grading discipline item onto
that one slot and starves the rungs beneath it — which
[balance.md](balance.md)'s rule 10 reads as a gate that opened nothing.

> No subclass unlocks before its parent class's third level (`requiredLevel`, `data/classes/*.lua`),
> so a discipline row at slot 0 is a *locked* row sitting in front of the stock a newcomer can actually
> buy. `Vendor.stock` sorts by slot then price, so a cheap one there becomes the first thing the shop
> shows and the first thing they cannot have.

**And the order answers the same thing from the other side now.** `Vendor.shelfOrder` — the one order
every counter in the city deals in, the house shelves through `Vendor.stock`, the town counter through
`Market.stock`, and the bands the shop cuts out of either — leads with **what is buyable** and only then
runs the ladder: rank, then price, then name, once through the open stock and once through the shut. A
band on a house shelf runs to sixty-odd rows with a handful of them open (the rail prints it: `4 / 64`),
and dealing those few strictly by rank scattered them through the greyed tiles, so the one question a
counter is opened with — *what can I buy* — was answered by reading the whole rack. Where the slot
placement above keeps a locked row off the bottom rung, this keeps it off the top of the rack. Nothing
is hidden: what the rift holds is the other half of what a shelf is for, and it gathers under the stock
rather than through it. The purse is deliberately not a key — a rack that re-dealt itself every time the
company's gold crossed a price would rearrange under the hand mid-purchase, and a tile already prices
itself against the purse in its own colour.

**One counter, seven ladders.** The seven house shelves are gone with the houses; there is one market
(`models/market.lua`), and it gates each ware on the level of ITS OWN class — `Vendor.stock` takes a
per-item rung function for exactly that. What the market puts out on a given morning is a fixed core
plus a roll deterministic from the day, and the tier it rolls against is the highest band that depth
reached, top class level, or total class levels implies.

### Fitness: does it answer what comes next?

Raw power is not the whole question. What you unlock at slot N has to be worth carrying into the
slot N+1 quest, and an item is worth nothing there — whatever it grades — if that quest fields bodies
that wall its damage type or shrug off the status it exists to apply.

`Grade.fitness(id, class, slot)` asks that, and the slot is a **parameter, never a lookup**: raw
power proposes a placement and fitness scores that proposal. One pass, in that order. Iterating the
two to a fixed point is deliberately not done — a ranking that feeds its own input is the mistake
above, arriving by a different road.

Most slots have no quest authored yet. A slot with nothing to face returns nil — no verdict, rather
than an invented one.

---

## The pins

Some slots are not the grade's to decide. Each is named one by one in `Grade.SLOT_PINS` with its
reason, rather than inferred, for the same reason `Balance.MAGNITUDE_WAIVERS` is: a heuristic that
swept these up would also sweep up things nobody decided, and the next author would have no way to
tell them apart.

| kind | what | why |
|---|---|---|
| **ladder anchors** | the twelve `Balance.FAMILY_BASE` weapons and `Balance.ABILITY_BASE` | they *are* the ruler |
| **opening shelf** | the rehomed general goods, the prologue's teaching spell | contracts other specs assert |
| **standing supply** | the nine draughts on the town counter | a rung is a gate, and a gate on a healing potion prices a need |
| **ordering** | the Mammonite earners and spenders | its gate sits between the halves |
| **legality** | `armor_iron_plate` | its resist bag only fits the cap from slot 3 up |
| **hand-placed** | items the dry run cannot see | a human supplying the missing information |
| **reach** | `ability_polymorph` | what the verb *is*, not what it is worth |
| **family shape** | the eleven wards at 3, the eleven seals at 9 | a house teaches you to take the blow before it teaches you to refuse it |
| **the chase** | seven entries on four bodies' drop lists | a chase is often a rule rather than a number, and the grader reads a rule low |

Read the anchors off `Balance` rather than typing them, so the pin list and the magnitude ladder can
never name different items.

The last three rows overrule a grade the tool can read perfectly well, so they carry the heaviest
burden of proof. Polymorph takes a body out of the fight outright, deterministically, with no
roll to survive — and *when a line hands that verb over* is a question about the shape of the line
rather than about power. Note what it is not: it is not a correction to a number. The number was
wrong too, and that was fixed where it was wrong — `status_polymorph` had no authored weight, so the
grader could only see the two flags the badge carries and read the strongest removal spell on the
shelf at half a turn. Fixing the misread moved it five rungs on merit; the pin holds the sixth.

The ward line is the same argument made about a whole family. The grade reads both halves LOW — a turn
spent to prevent less than a swing — and that is honest about the average turn and wrong about the
family, which does not exist for the average turn. A ward is bought for the one telegraphed blow the
fight turns on, and a dry run against a reference body has no telegraph in it. Left to the ranking the
line pooled at slot 0, which prices refusing a dragon's breath as opening-rack stock.

> **Both numbers read 1 and 4 for a year while every word of that argument said 3 and 9.** That is how
> to tell which of the two was the decision: 3 and 9 are what the family's shape means, what this table
> says, and what `models/grade.lua`'s own comment above the pins says. 1 and 4 are simply where a
> **six-rung** shelf could fit them (`31de4b73`, *A house sells six rungs now*) — a six-rung shelf has no
> 9 to put a seal on. The ladder is sixteen rungs and the numbers the design asks for exist again, so
> they are restored. It is also two wares off the **second rung of every house in the city**: a ward at 1
> made rung 1 a second opening rack, and the seals at 4 were a six-ware bulge in the middle of the
> Bastion's shallow end.

There **was** a ninth kind of pin here, and it is gone: a **cadence** block of nine pieces hand-placed
into slots 0–2 to backfill the rungs the ward line vacated, because *a gate that opens nothing is a
reward nobody sees*. The argument was good and the disease is cured upstream — nothing decided how many
wares a rung dealt, so holes fell where they fell and had to be filled one at a time.
[`tools/shelf_curve.lua`](../tools/shelf_curve.lua) decides it now and no rung in the city opens nothing.
Six of the nine also pinned to **rung 0**, which was cheap when rung 0 was the fattest band in the game
and is re-digging the hole now that it is the re-arm floor. Their own `why` lines dated them: every one
named a *quest* of a house that has posted none since the board was retired.

### Pin the anchors before the first apply

`Balance.slotAnchors` reads each family's two ends off its base weapon, and the ability group's off
`Balance.ABILITY_BASE`. Move one and **every target on its ladder moves with it.** The first run of
this pass let the grade send `ability_fire_bolt` to slot 8; the anchor went with it, every ability in
the game was retargeted off the raised base, a slot-0 Jolt came out hitting for sixty, and the
prologue's closing beat broke.

If an anchor's own magnitude has already drifted, restore it from git before re-running — the rescale
reads it as truth.

### An authored script must never share an item with a graded shelf

Jolt was the Arcanum's opening spell *and* the village lesson's teaching cast, so its weight answered
to choreography instead of to power and could never be priced as what it is. The fix is to **split
it**, not to pin the shelf item down to protect a script: `ability_minor_shock` carries the lesson's
numbers, and Jolt is graded for what it does.

### Anything a rule picks must be picked on a slot-free field

The "every house arms a newcomer" rule chooses an opening weapon for a house that sells no family
base. It first chose off the fitness-adjusted order — and fitness reads the proposed slot, so the
choice depended on the assignment it was feeding. The Crucible's two plain weapons traded the opening
seat every round and the pass sat in a 2-cycle forever. It picks on raw grade now.

---

## The price

`price = f(slot)`, times a per-type factor. Every item on a rung costs the same, and the only thing
that varies it is being **spent**: a consumable is one use and then gone, and pricing it level with a
weapon you keep would make it a purchase nobody sensible makes — which is the one true thing the old
price scale was saying.

Deliberately *not* scaled by the finer grade. Two items on a rung are meant to be a choice between
effects, and a price that separated them would put a thumb on that scale.

---

## Running it

Report first. Nothing here writes a blueprint until you say `apply`.

```powershell
& "E:\LOVE\lovec.exe" . grade-report              # per-house shelves, ranked
& "E:\LOVE\lovec.exe" . grade-report diff         # only what would move 3+ slots
& "E:\LOVE\lovec.exe" . grade-report explain ID   # one item's whole arithmetic
& "E:\LOVE\lovec.exe" . grade-report full         # ...plus quest rewards and the trait worksheet
& "E:\LOVE\lovec.exe" . grade-report apply        # rewrite unlockLevel + price
```

**It is iterative, not one-shot.** `apply` moves slots; moving slots leaves magnitudes out of band by
construction, because `Balance.slotTarget` reads the slot. So:

```powershell
& "E:\LOVE\lovec.exe" . grade-report apply
& "E:\LOVE\lovec.exe" . balance-rescale apply 0    # repeat until it reports 0 edits
& "E:\LOVE\lovec.exe" . balance-rescale apply 1    # then 2, 3, 4
```

...and repeat the whole loop until `grade-report diff` reports **0 items would move**. With the
anchors pinned and the grade blind to damage it reaches a fixed point in one round; if it does not,
something is being chosen on a field that is not slot-free.

**Finish on a magnitude pass, never on a grade apply.** The last thing to run must be
`balance-rescale apply 0`, because a slot move leaves the item's damage describing the rung it used to
be on — `tests/balance_spec.lua`'s *an item's magnitude is the one its unlock slot names* is what
catches a loop stopped one step early. Two or three sword and dagger rows may trade places forever
(identical grades, different fitness against what they face); that is the damping limit, not a fault.

**Anything keyed to the slot NUMBER breaks when the rung count changes**, and five things were: the
price ladder (`Grade.priceFor`), the standing the wielder is assumed to have (`Balance.prestigeForSlot`),
— through the price band — the descent's sealed finds, the forge ceiling (`Forge.ceilingFor`, which
climbed one rung per quest against a line that no longer runs that many, and so stopped every bench in
the game at `+9`), and the craft-stock bands (`Material.GRADE_BY_PRICE`, two absolute gold thresholds
that sat still while the prices under them moved, leaving one rung on steel and three on mythril). All
five read the slot as a *position* on whatever ladder it is on now, so re-cutting the shelf moves the
size of a step and never the span.

The last two were found by asking the question the other way round — *what else did the twelve-rung
shelf teach a number?* — because neither announced itself. The forge ceiling had a guard that measured
a line nobody can run ([balance.md](balance.md), rule 9); the craft bands had a spec asserting on three
prices no item carries. Both were green.

The rewrite deliberately does **not** touch magnitude. Doing both in one place would hide which of
the two decided any given number.

---

## What it cannot see

`Grade.of` marks an item **blind** when the boardless replay reported nothing at all. Ten items are:
they need board state a replay has none of — a planted charge, weapons beside them in the grid, a
purse, a corpse. Their number describes the *instrument*, not the item, so they are set aside rather
than ranked at the bottom, and they keep whatever slot a human gave them.

Four of the ten are Artificer or Saboteur — both "build a thing, then set it off" disciplines, which
is precisely the shape a dry run cannot follow. That is a cluster, not ten separate accidents.

A blind row with an `at` pin is **no longer blind**: a pin is a human supplying exactly the missing
information, so those rejoin the written set. Without that, a pin naming a set-aside item is silently
inert.

---

## Known, and deliberately not fixed here

**81 of the 111 trait weights were adopted from a classifier's seed rather than weighed.**
`Grade.TRAIT_ADOPTED` keeps that provenance, and the report marks every item resting on one with `~`.
Against the thirty that *were* judged by hand, the seed agreed exactly four times — wrong in both
directions, and biased worst on flag-only traits whose rule lives in `models/combat.lua` rather than
in the blueprint. Those 73 marked items are where a ranking is most likely to read wrong.

**Fitness has almost nothing to measure against.** Only the Bastion has quests authored densely
enough, and it reports that the knight's own opening weapons land 21–33% against what its slot-1
quest fields. The pins are right; what is mismatched is that quest's composition.

**Two statuses read as worth nothing**, and both are correct: Channeling and Given Guard are costs
their bearer pays, not boons.
