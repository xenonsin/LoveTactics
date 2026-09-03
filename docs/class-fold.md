# The fold — one class ladder

Working plan for collapsing `class` and `discipline` into a single taxonomy of **46 classes**. The
system being folded is described in [classes.md](classes.md) and the authoring slate in
[disciplines-plan.md](disciplines-plan.md); this file is the *migration*, and it supersedes the
two-axis premise both of those are written on.

## The decision

**Everything is a class. The word `discipline` goes away, and so does the `classes` parent list.**

A job blueprint is a name, a description, an exemplar, and the levels it requires in other jobs:

```lua
-- data/classes/ninja.lua
return {
    name        = "Ninja",
    description = "...",
    exemplar    = "character_ninja",
    requires    = { thief = 3, elementalist = 3 },
}
```

A **root** is a class with no `requires`. There are eight of them: the seven the city was built on
(knight, fighter, mage, priest, rogue, hunter, alchemist) plus **creature**, which is where the kit
that belongs to no job goes. An item carries exactly one `class`, and it may name any of the 46.

### Why "class" survived and "discipline" did not

Four arguments, and the first is the only one that is about cost:

- **Half the data churn.** 344 items already say `class = "knight"`, and under this fold they are
  *correct as written* — zero edits. Only the 290 dual-tagged ones move. Folding the other way
  (everything becomes a `discipline`) means renaming all 344 **and** deleting the class line from all
  290: ~634 files against ~290.
- **The surviving word is the player-facing one.** `Item.classDisplayName` prints it on the tooltip
  and the shop's detail column, and the whole ladder is already class — `CLASS_LEVEL_CAP`,
  `classLevel`, `rosterLevel`, `growthClasses`. `models/class.lua` is a module named Discipline
  whose entire core vocabulary is class. Folding the other way means renaming the ladder too.
- **`class` is free now.** Its second meaning — *the vendor shelf that stocks this item* — died with
  the seven houses. There is one market, so the word is no longer doing two jobs, which is the only
  thing that made a second word necessary in the first place.
- **It unifies bodies with items.** The exemplars authored specifically to *be* a discipline cannot
  currently say so: `character_ninja` is `class = "rogue"`, `character_bulwark` is `class = "knight"`,
  `character_elementalist` is `class = "mage"`. One vocabulary and each of them says what it is, which
  is what the houses-to-classes commit was already reaching for.

### Why `classes` collapses into `requires`

The parent list does three jobs today. Two of them evaporate:

| job | after the fold |
|---|---|
| arity — subclass vs multiclass | `#requires` |
| which shelves an item lands on | gone; one market |
| the invariant that an item's `class` is one of its discipline's parents | gone; one field |

Everything downstream of arity falls out of `requires` directly: `subclassesOf(x)` becomes "jobs whose
requires name x", `missingParents` becomes "the unmet entries", and the shop's `Rogue x Mage` line is
read off the requirement keys.

**The cost of making requirements explicit is already owed.** All 38 blueprints carry `requiredLevel`
with exactly one key, and **32 of them are marked `-- pending`**. Only six gates are settled —
beastmaster, bulwark, elementalist, exorcist, sentinel and warlord, all at parent level 3–4. Every
crossing's real gate is unwritten today. Collapsing the field surfaces that work; it does not create
it.

### A `home` field was proposed and is not needed

An earlier cut of this plan gave each crossing a `home` root, on the reasoning that a two-parent job
has no single answer to "which house is this". Nothing asks any more:

- `Forge.ceilingFor` reads the item's own class level.
- `Market.stocksStaple` maps class to house to companion, but staples are roots only, so a crossing
  never reaches it.
- `Vendor.forClass` indexes the seven house vendors, and only roots have one.
- Growth already tallies the class itself (`growthClasses`), which is what retired the older
  "tallies both parents" rule.

`Class.rootsOf(id)` — the transitive closure of `requires` down to roots — covers the two places that
genuinely need the ancestry: the shop's path line, and the spec below that stops a crossing's gate
from silently weakening.

## What changes, by layer

| | now | after |
|---|---|---|
| `data/classes/` | 38 files | 46 (`data/classes/`, +7 roots, +creature) |
| item `class` | 634 items, 7 values | 749 items, 46 values |
| item `discipline` | 290 items | field deleted |
| `Item.CLASSES` | 7 ids to blurbs, in `models/item.lua` | deleted; blurbs move to the root blueprints |
| discipline `classes` | parent list | deleted |
| discipline `requiredLevel` | one key, 32 of 38 pending | `requires`, authored |

## The order

Steps 1–3 are the whole of "everything has a class", and every one of them is behaviour-preserving.

> **ALL SIX STEPS ARE DONE.** 749 items, every one of them carrying a class; 46 blueprints; one
> taxonomy; the module and folder renamed; the suite green at 2673. `tools/class_fold.lua` did the item
> data and the gates, `tools/class_rename.lua` did the rename — both dry-run by default, both kept as
> the record of what moved. What the doing taught is recorded under *What the migration actually cost*
> below; the plan is left as written so the two can be compared.
>
> **Step 5 moved nothing, and that is its result rather than its failure.** See *The judgment pass, and
> why it was already done*.

**1 — Roots exist.** Author eight blueprints (the seven, plus creature) with no `requires`, the seven
blurbs moved out of `Item.CLASSES`, and `creature` marked `playable = false` so it never offers itself
as a job. Add `Class.isRoot`. Carve roots out of the four spec cases that assume every class has
parents. No item is touched. **Pin: every root class is unlocked for a fresh player** — the market's
rotation pool empties otherwise, and nothing else in the tree would notice.

**2 — One field.** Move each of the 290 items' `discipline` value into `class`, deleting the old root
value. Re-point `Item.classOf` / `classDisplayName` / `classDescription` at the blueprint registry and
delete `Item.CLASSES`. Three predicates swap from "has a discipline" to "is not a root" —
`Forge.ceilingFor`, `weapon_spec`'s family exclusion, `Vendor.stock`'s `disciplineLocked`. Delete the
"an item's class is one of its discipline's parents" case; the invariant it guarded no longer exists.

**3 — Creature.** `class = "creature"` onto the classless kit. See the open call below on which of the
115 this actually covers.

**4 — `requires` replaces `classes`.** Author the 21 crossing gates for real, collapse the two fields
into one, and derive arity / roots / `missingParents` from it. **Pin: a class descended from two roots
names a requirement drawn from each** — see the risk below.

**5 — The judgment pass.** The ~125 items that should move off their root onto a deeper job. Fully
incremental now, one root at a time, because there is no longer an "untagged" state to lose an item
in: the root is always a valid answer, so a half-finished pass is merely conservative rather than
broken.

**6 — The rename.** The module and folder that own the 46 classes stop being called disciplines:
`models/class.lua`, `data/classes/`, and `tests/class_ladder_spec.lua` (which could not simply become
`class_spec` — that file already exists and keeps the seven houses' shelf contract, where this one
keeps the ladder). 157 files, 755 replacements, 3 `git mv`s. Pure mechanics, no behaviour, verified by
the suite alone. **Deliberately last and deliberately separable**: if it had ever been cut, the cost
would have been a badly named module rather than a broken fold.

> This paragraph originally read "`models/discipline.lua` to `models/class.lua`" and the rename tool
> rewrote both halves of it, leaving a sentence that moved a file to itself. A sweep that rewrites
> paths cannot tell a live reference from a description of the move — which is why the tool skips its
> own source, and why it does not touch doc PROSE at all. This is the one line it should have skipped
> and could not know to.

## The judgment pass, and why it was already done

Step 5 was scoped as "the ~125 items that should move off their root onto a deeper job." **None of them
moved.** The 125 was a count of what was ELIGIBLE — priced, on a root, above the opening rung, not a
weapon or a shield — and eligibility is not the same question as whether an item is in the wrong place.
Reading them answers it differently.

Two blocks come off the top for reasons that were already written down:

- **22 are the ward line.** The Resistant/Immunity abilities are spread across all seven roots by an
  authored decision — a house wards what it deals — and re-homing any of them would undo it.
- **14 are plain armour.** Chainmail and Runed Plate are what a knight buys, not what a Bulwark earns.

That leaves 89, and the ones with the strongest mechanical pull to an earned class turn out, every
time, to be the BASE-SHELF COUNTERPART of something that class already holds:

| left on the root | the earned class already stocks |
|---|---|
| `consumable_fire_bomb`, `flask_of_liquid_fire` | Bombardier: acid, ice and lightning bombs |
| `ability_summon_golem`, `ability_summon_homunculus` | Artificer: emplace sentry, field assembly, recall construct |
| `consumable_fire_stone` (a depleting infusion) | Poisoner: envenom, crawler mucus, thinblood rime |
| `ability_shadow_step` (blink and strike) | Assassin: shadow strike, coup de grace |

The retag pass this file's predecessor describes took the deep half of each pair and deliberately left
the shallow half, under its own rule: *a discipline is the locked deeper cut of its parent shelf, never
a re-tag of the whole thing — tag too much and the base shelf empties out.* Moving `fire_bomb` to the
Bombardier leaves an alchemist with nothing to throw until the Bombardier unlocks, which is the exact
failure that rule exists to prevent.

The rest read as their root's own identity against their root's own blurb: the mage's 24 are elements,
control and caster gear, and the Elementalist's signature is SIGILS, which were tagged long ago; the
hunter's 10 are marks and bow work, which the hunter blurb names as hunter work; the priest's 13 are
heals, wards and revival, which is the priest.

**What would change the answer** is the roster-size decision this file has left open from the start:
rosters run 5–11 today against a stated target of 5–8, and a deliberate move to 9–15 would mean
authoring NEW deep cuts rather than re-homing base stock. That is content work, not a migration, and it
is the honest shape of what is left.

## What the migration actually cost

Four predicates were named in advance as things that would invert silently. **Nine did.** The pattern is
worth stating on its own, because step 5 will meet it again: every place that asked "is this the deep
cut" by testing `item.discipline ~= nil` answers FALSE FOREVER once there is one field, and none of them
raise. They were `Forge.ceilingFor`, `Forge`'s material bill, `Vendor.stock`'s lock, `Vendor.sells`'s
parent routing, `Market.isStaple`, the tooltip's tint, the forge panel's standing line, the hub's stash
filter, and the three report tools. They are all `Discipline.isEarned(class)` now — added as a function
precisely because writing the compound out nine times is nine chances to drop the existence half.

**The one the plan missed** was the forge's material bill. `materialsFor(target, price, class, discipline)`
took the taxonomy TWICE, and passing one field to the wrong parameter billed nothing at all:
`Material.houseFor("ninja")` is nil, `add` ignores a nil id, and a crossing's gear would have forged with
no house stock. It now takes one argument, because an argument you cannot give to the wrong parameter is
better than a comment saying which is which.

**Two spec cases were deleted rather than migrated**, and both for the same reason — the fold made their
failure mode unreachable, and a case that cannot fail is not coverage:

- *"a multiclass stocks at least one item on EACH parent's shelf."* There is no home parent to get wrong
  any more; `Vendor.sells` routes a crossing's stock to every parent by construction.
- *"every discipline-tagged item's class is one of its discipline's parents."* That was the invariant
  keeping two taxonomy fields from contradicting each other. One field cannot.

**Two findings the fold surfaced and did not fix**, both left as they were with the contract restored to
exactly what it asserted before:

- `character_miller_ghost` (undead) carries `ability_fireball`, which is mage stock. `tests/bestiary_spec`
  says creature kit is natural weapons only; it could not see this, because a root class was invisible to
  a test reading the sparse second field.
- Six items are ordinary player gear that carried no class and were swept into the creature bucket:
  `ability_haste`, `ability_omnislash`, `ability_pull`, `armor_padded_vest`, `consumable_wildcraft_reagent`,
  `utility_decoy`. All six are also genuinely unreachable — no price, no grant, no drop tier — and
  `tests/obtainable_spec` will say so the moment they are re-homed.

**And one accidental green, unrelated to the fold but found by it.** `tests/item_debug_menu_spec` had
never passed on its own: `Theme.body` memoizes by size, earlier specs stub `love.graphics.newFont` around
their own panels, and a STUB font was landing in the shared cache at the size this menu happens to ask
for. It stubs its own fonts now.

## What breaks silently

Four things that no current test would catch:

- **The forge ceiling.** `Forge.ceilingFor` returns `Item.MAX_LEVEL` — no ceiling at all — for any
  item with a discipline, because the technique price replaced the ceiling deliberately and stacking
  both was the double-charge that was removed. Give every item a class and, read naively, every item
  in the game loses its ceiling. The fix is a predicate swap, not a redesign: the branch tests
  `not Class.isRoot(item.class)` and both behaviours survive exactly as authored.
- **The weapon family roster.** `tests/weapon_spec.lua` enforces 13 families of exactly 5 shelf and 5
  quest weapons, *excluding* anything carrying a discipline. After the fold nothing carries one, so
  the exclusion never fires and every family counts past 5. Same swap: exclude weapons whose class is
  not a root.
- **The crossing gates.** `isUnlocked` enforces "hold a subclass of **each** parent" on top of the
  single `requiredLevel`, and that implicit rule is what stops a player meeting the Ninja before
  walking both a rogue branch and a mage branch. Write the crossings' `requires` with one key and all
  21 quietly get easier. This is what step 4's pin exists for.
- **The market going empty.** Every item's rotation eligibility keys off one lock after step 2. It is
  a no-op *by construction* — roots are always unlocked, so what is rollable does not move — but only
  as long as that stays true, which is what step 1's pin exists for.

## Counts

```
749  item files
     290  carry a discipline today (250 priced, 40 unpriced)
     344  carry a root class and no discipline  -- correct as written, zero edits
     115  carry neither                          -- step 3

 46  classes            8 roots + 17 subclasses + 21 crossings
 45  growth tables      data/growth/ already holds one per job; the 46th is creature's
```

## Open call: the classless residue

**The creature root does not cover all 115.** They split three ways:

- **89** are `noSteal`, and 72 sit in the `natural` / `unarmed` families — creature kit and boss phase
  machinery. These are what the creature root is for.
- **~12** are boss kit by any reading but carry neither marker: the demon abilities
  (`ability_demon_brimstone`, `_cleave`, `_roar`, `ability_self_destruct`, `utility_demon_sigil`,
  `utility_volatile_core`, `armor_hollow_crown`, `utility_unappeased_heart`, `utility_unbound_heart`).
  Creature root as well, but they need the marker adding so the reason is readable.
- **~12 are player gear with no job**, and these are the real call: `armor_leather_armor`,
  `armor_padded_vest`, `ability_haste`, `ability_pull`, `ability_rain`, `utility_decoy`,
  `utility_focus_stone`, `utility_gatekeepers_measure`, `utility_hallowed_censer`,
  `utility_overflowing_focus`, `consumable_wildcraft_reagent`, `weapon_gralloch_knife`.

Calling a padded vest creature kit would be a lie, and `class_spec` already records the reason these
are bare: *"`class` means sold by, so a weapon with no price rightly names no class —
weapon_parasitic_staff is issued to the mage and the priest both, and stamping it with either one
would make the OTHER grow wrong."* That argument is about the growth tally and it survives the fold
intact.

So the residue wants either a per-item call (twelve of them, cheap) or a second answer — a `common`
root for gear that is genuinely everyone's. **Not settled here.**
