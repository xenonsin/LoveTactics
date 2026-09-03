# The shelf

Where an item sits, what it costs, and why neither is authored by hand any more.

Every priced item in the game names a **slot** (`unlockQuests`, the rung of its class's ladder it sits
on) and a **price**. Both used to be typed into the blueprint. Both are now derived, in one direction:

```
grade  ->  slot  ->  price
```

An item's **grade** is what it is worth. Its rank within its class sets its **slot**. Its slot sets
its **price**. Nothing flows the other way, and two specs enforce that.

- The grader: `models/grade.lua`
- The instrument: `& "E:\LOVE\lovec.exe" . grade-report [full | diff | explain ID | traits | apply]`
- The guard: `tests/grade_spec.lua`

> **The field is still called `unlockQuests` and no quest has opened a shelf for some time.** The name
> survived two re-cuts because renaming it means touching every priced blueprint in the game to change
> nothing, and a 485-file rename that subtracts nothing is 485 chances to be off by one. It means *the
> rung*, and the rung is a class level (**The slot**, below).
>
> On an item with no price it means nothing at all: an unpriced ware carries a `dropTier` instead —
> the same grade, spread along DEPTH rather than along a shelf, because a thing with no shelf to sit on
> still has a place it belongs (`tools/drop_tier.lua`, and `Spoils.lootCandidates` is what admits it).

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
`Balance.slotTarget` reads `unlockQuests` and *grants* the item its magnitude. So the power ladder
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
. grade-report apply        # 99 blueprints rewritten: unlockQuests + price
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

Each class's stock is ranked weakest-first and spread across `0 .. rungs - 1`, where **a rung is a level
of the class ladder** — `Discipline.CLASS_LEVEL_CAP`, nine rungs at every class. `tools/grade_report.lua`
reads the count off `models/class.lua`, so the shelf cannot disagree with the thing that opens it.

> **This is the second re-cut, and the first one is worth keeping in view.** A rung used to be *a job the
> house asked for* — its opener plus every quest a discipline hung off, six per house — and before that
> one rung per authored quest, twelve of them. Twelve meant two or three wares an errand at the bottom of
> a shelf, a job run for a tooltip. Six meant 10–15, an unlock you feel arriving. Nine means a little
> under ten, and the difference now is that the thing being counted is not work at all.

**A class is climbed by a BODY, not bought by a company.** `Discipline.classLevel` reads cumulative
technique — two a swing, banked by whoever is holding that class's gear — so what opens a rung is having
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
| **opening shelf** | five rehomed general goods, the healing potion, the prologue's teaching spell | contracts other specs assert |
| **ordering** | the Mammonite earners and spenders | its gate sits between the halves |
| **legality** | `armor_iron_plate` | its resist bag only fits the cap from slot 7 up |
| **hand-placed** | items the dry run cannot see | a human supplying the missing information |
| **reach** | `ability_polymorph` | what the verb *is*, not what it is worth |
| **family shape** | the eleven wards at 3, the eleven seals at 9 | a house teaches you to take the blow before it teaches you to refuse it |
| **cadence** | nine pieces backfilling slots 0–2 at five houses | the rungs the ward line vacated, and a gate that opens nothing is a reward nobody sees |

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

The **cadence** pins are what that placement cost. Eleven wards moving to slot 3 took eleven rows off
slots 0–2, and five houses came out with an early quest that opened one plain row or none — the
Colosseum and the Hunter's Lodge opened nothing whatever at quest 1. Handing the hole back to the
ranking does not close it: every candidate the grade offers drags its own magnitude rescale along and
vacates the rung it came from, so the hole walks a gate down per round. Which stock rises into 0–2 is
an authoring decision, so it is authored. Each backfill is taken from a rung that still opens two plain
rows without it, and eight of the nine carry no graded magnitude, so the move costs a slot and a price
and nothing else; the ninth is retuned to the rung it lands on.

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
& "E:\LOVE\lovec.exe" . grade-report apply        # rewrite unlockQuests + price
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
