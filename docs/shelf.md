# The shelf

Where an item sits, what it costs, and why neither is authored by hand any more.

Every priced item in the game names a **slot** (`unlockQuests`, the count of its house's quests you
must finish before it is on sale) and a **price**. Both used to be typed into the blueprint. Both are
now derived, in one direction:

```
grade  ->  slot  ->  price
```

An item's **grade** is what it is worth. Its rank within its house sets its **slot**. Its slot sets
its **price**. Nothing flows the other way, and two specs enforce that.

- The grader: `models/grade.lua`
- The instrument: `& "E:\LOVE\lovec.exe" . grade-report [full | diff | explain ID | traits | apply]`
- The guard: `tests/grade_spec.lua`

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

Each house's stock is ranked weakest-first and spread across `0 .. quests - 2` — the last two quests
of a line open nothing new, because gating anything on "finish the whole line" puts it out of reach
of the line that unlocks it.

**Two bands, spread separately.** The base shelf runs the whole line; the discipline cut starts at
slot 3. Spreading them together and clamping afterwards piles every low-grading discipline item onto
that one slot and starves the rungs beneath it — which
[balance.md](balance.md)'s rule 10 reads as a quest that opened nothing.

> No subclass unlocks before its line's third quest, so a discipline row at slot 0 is a *locked* row
> sitting in front of the stock a newcomer can actually buy. `Vendor.stock` sorts by slot then price,
> so a cheap one there becomes the first thing the shop shows and the first thing they cannot have.

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

Read the anchors off `Balance` rather than typing them, so the pin list and the magnitude ladder can
never name different items.

The last row is the only one that overrules a grade the tool can read perfectly well, so it carries the
heaviest burden of proof. Polymorph takes a body out of the fight outright, deterministically, with no
roll to survive — and *when a line hands that verb over* is a question about the shape of the line
rather than about power. Note what it is not: it is not a correction to a number. The number was
wrong too, and that was fixed where it was wrong — `status_polymorph` had no authored weight, so the
grader could only see the two flags the badge carries and read the strongest removal spell on the
shelf at half a turn. Fixing the misread moved it five rungs on merit; the pin holds the sixth.

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
