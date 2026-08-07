# Classes

Every item answers one question before any other: **which shelf does it go on?** This file is the
contract that answers it. A new item picks a class and speaks that class's vocabulary; deviating is
allowed, but it must be a decision, not a drift.

`tests/class_spec.lua` enforces the tables below by sweeping every item blueprint, so a class that
quietly loses its weapons — or claims a keyword no item of its own actually has — fails the build.

## A class is a shelf with a point of view

An item's `class` decides **which vendor stocks it**, and nothing else. It never gates who may equip
it: anyone can carry anything (`models/item.lua`). That is not an oversight to be fixed later, it is
the point — it is what lets a player build a bespoke class by mixing shelves. A ninja is mage gear on
a rogue.

So a class does not say *who may carry this*. It says *what kind of answer this is*.

There are three different ideas in this codebase that all sound like "class", and they are decoupled
on purpose. Keep them apart:

| Idea | What it is | Where it lives |
|---|---|---|
| **`class`** | The vendor shelf. **What this file defines.** Never gates equipment. | `item.class`, `Item.CLASSES` |
| **weapon `family`** | The mechanic a weapon inherits — axes cleave, daggers bleed. | a tag; [weapons.md](weapons.md) |
| **growth class** | What a character *actually casts*, tallied per use. Emergent, never assigned. | `Character.recordUse` → `Growth.dominantClass` |

The third is why the other two can stay loose. Growth is earned by play: each character tallies which
class's items it casts, and on each level-up gains the stats of its most-used class. A knight you keep
casting Fireball with grows into a battlemage. The shelf you shop at and the character you become are
different things, and the gap between them is where builds live.

One class per deadly sin: each vendor's quest line ends facing its own (see [story.md](story.md)).

## The contract

| Class | Sin | Resource | Identity | Owns |
|---|---|---|---|---|
| `fighter` | wrath | stamina | Trades its own health and tempo for damage. Wrath is what happens directly in front of you. Also `Growth.NEUTRAL_CLASS` — every class-less creature grows as one. | `front` aoe, `stun`, `raw`, self-cost (Fury, Desperate Strike, Reckless), `frenzy`, banners, the extra action |
| `knight` | sloth | stamina + mana | The wall. It does not kill you, it decides where you stand — or whether you act at all. | `taunt`, `halted`, `knockback`, guard redirect (`oathward`/`martyr`/`sharesDamage`), `defending` wait-swap, **watched ground** (see below), armor |
| `rogue` | greed | stamina | Guile. Conditional multipliers, return-to-origin blinks, and taking what is not yours. | `guile`, `blink`, execute, `steal`, `bleed`, debuff-count scaling |
| `hunter` | gluttony | stamina | Setup, then payoff — and most of it gated on a bow beside it in the grid. | `mark`, `requiresAdjacent`, traps, animal summons, shapeshifting, `cripple`/`root` |
| `mage` | pride | mana | Elements, wind-ups, and remaking the ground itself. | `channel`, hazard creation, element tags, `reserve` summons, the **sigils** (`careful`/`twin`/`speedBonus`/`rangeBonus`) |
| `priest` | lust | mana | Zones and wards. Holds ground open and closes it to others. | `holy`, `negates`/`reflects`, `cleanse`/`dispel`, friendly hazards, revive, `unarmed` |
| `alchemist` | envy | mana | Covets others' power rather than casting its own: consumables and grid auras. | `consumesItem`, `poison`/`acid`, the `aura` block, **coatings** and **elixirs**, throwables |

**The Identity and Owns columns are said to the player, too.** The two are compressed into one
sentence per class in `Item.CLASSES` — the value side of that table *is* the blurb, rather than a
`true`, so the set of classes and the sentences describing them cannot drift apart the way two parallel
tables would — and read back through `Item.classDescription`. The shop prints it under the heading of
the vendor's base rack: the one place a player is told what a shelf *is* rather than what is on it.
`tests/class_spec.lua` pins that every class has one and that it fits the column it is drawn in.

**Owning a keyword is not a monopoly.** What the column means is: this is the class whose identity the
keyword expresses, and the shelf a new item built on it should default to. Overlap is expected —
alchemist's `weapon_envenomed_kris` bleeds on the rogue's own verb, and it is on the right shelf
because *what it does with* Bleed is envy's.

**The resource column is the same kind of claim** — the pool a class mainly spends, not a law it obeys.
Knight is genuinely hybrid, the rogue pays mana for two of its ten abilities, and half the casters'
weapons cost stamina so that a cornered mage is never disarmed. `tests/class_spec.lua` deliberately
does not assert it: a test that pinned one pool per class would be describing a tidier game than the
one that exists.

## A class item must speak its class's vocabulary

The corollary of the contract, and the direct analogue of weapons.md's *"a named weapon must do
something the base one cannot"*: if an item's only claim on a shelf is its flavor text, it is on the
wrong shelf.

Reach for a keyword the class owns. Borrowing across shelves is fine when the borrowing **is** the
point — but say so in a comment, the way `weapon_riposte_blade` explains being the one sword that does
not parry. An unexplained borrow is indistinguishable from a mistake.

## The weapon spread

Each class is a **family cluster, not a grab bag**. A shelf should read as a kind of armed person.

Because `class` never gated equipment, a weapon on the wrong shelf was always free to move — nothing
mechanical changes, only who stocks it. That is how fighter came to hold seven families and 53% of the
armed catalog while knight and alchemist held none: "melee" and "fighter" were never distinguished.

The sharpest line here is the old cleric taboo — **the faithful bear no edge**. Priest carries foci;
the knight carries the blade. The Cathedral's one sword is forged for somebody else (see below).

| Class | Cluster | Weapons |
|---|---|---|
| `fighter` | axe + hammer + greatsword | `weapon_iron_axe`, `weapon_butchers_wedge`, `weapon_crimson_greataxe`, `weapon_iron_hammer`, `weapon_iron_greatsword` |
| `knight` | sword + spear + mace + shield | `weapon_iron_sword`, `weapon_riposte_blade`, `weapon_demon_bane`, `weapon_crescent_blade`, `weapon_iron_spear`, `weapon_mailpiercer`, `weapon_marching_standard`, `weapon_iron_mace` (+ `armor_bulwark_shield`, `armor_oathkeeper_shield`) |
| `rogue` | dagger | `weapon_iron_dagger`, `weapon_kingsblood_dagger`, `weapon_cutpurse_knife`, `weapon_slipknife` |
| `hunter` | bow + longbow | `weapon_iron_bow`, `weapon_iron_longbow`, `weapon_hornbow_of_the_hunt`, `weapon_quarrys_answer`, `weapon_stillhunter`, `weapon_hailfall_longbow` |
| `mage` | wand + staff | `weapon_wand`, `weapon_staff`, `weapon_emberwand`, `weapon_turning_year` |
| `priest` | censer + staff — no edge at all | `weapon_censer`, `weapon_censer_of_ashes`, `weapon_crozier`, `weapon_intercessors_staff` |
| `alchemist` | dagger + wand, both envenomed | `weapon_apothecarys_lancet`, `weapon_envenomed_kris`, `weapon_vitriol_wand` |

**Every class stocks at least three.** That is a floor, not a quota — fighter and knight carry more
because they are the armed shelves, and the catalog is free to grow unevenly. What the floor forbids
is a shelf with nothing on it.

Four notes on how this shook out:

- **The taboo is absolute: priest sells no edge of any kind.** `weapon_demon_bane` is the holy blade,
  and it is on the *knight's* shelf — the Cathedral consecrates the steel and the Bastion sells it.
  That is the rule stated from the other side rather than an exception to it: the faithful forge an
  edge, they just never carry one. A knight holding a holy blade is a crusader, which is what
  knight+priest is built from anyway.
- **The `censer` family is the Cathedral's alone.** A censer is a liturgical object; nobody else has
  any business swinging one — which is also why the priest's signature relic is already one
  (`utility_hallowed_censer`). Its two directions therefore live on the *same* shelf: `weapon_censer`
  blesses the ground it walks and `weapon_censer_of_ashes` chokes it. That is not a contradiction —
  "the faithful arm those who purge" is the shop's own line, and a faith with a punitive half is
  precisely what lust's shelf is. The object never changes; only the voice it is swung in.
- **Priest and alchemist racks are otherwise authored.** Nothing else in the catalog spoke lust or
  envy, and every borrowed alternative would have broken the corollary on day one. A plain hammer on
  the envy shelf is exactly the drift this file exists to stop.
- **The knight's two pikes each borrow one word, and say so.** `weapon_mailpiercer` spends
  fighter's `raw`, and `weapon_marching_standard` spends fighter's banner. Neither is on the wrong
  shelf, because of what the borrowed word is spent *on*: wrath pierces armour to kill faster and
  raises a standard to make a charge hit harder, while both of these answer *where do we stand* — one
  by making a shield wall un-stallable (and Halting the rank behind it, which is the knight's own
  word), the other by nailing the line to a square of ground. An unexplained borrow is
  indistinguishable from a mistake; these are the explanation.

## The armor spread

Armor answers the shelf question the same way weapons do, with one extra rule of its own.

**Every class shelf carries armor, and exactly five pieces of it are quest-only** — `class` with no
`price`, the shape described under *the tally, not the shelf* below. `tests/armor_spec.lua` pins it.
The five are the reward half: what finishing that vendor's line hands you rather than what its counter
sells. A shelf whose armour is entirely buyable has nothing to give for the work, and one that is
entirely quest-locked cannot be shopped at, so each shelf owes at least one priced piece too.

Signatures and generals' relics sit **outside** the count, exactly as they sit outside the weapon
families' ten. `armor_sworn_aegis` carries `class = "knight"` and no price and is still not one of the
knight's five: it is `bound`, nailed to one character's centre cell, and can never be earned or handed
over. A count of what a line pays out cannot include a thing nobody can be paid.

**And "quest-only" now means a quest actually hands it over.** For a long time it only meant *unpriced*
— no vendor stocks it, and `Spoils.lootCandidates` filters the random drop pool by price too, so an
unpriced item nobody named in a `rewardItems` list could not enter the game by any route at all. 94 of
them were in exactly that state: loading, passing the schema, counting toward the fives above, and
unreachable. Every one is now granted by a quest on its own shelf's vendor line, and
`tests/obtainable_spec.lua` fails the build if a new one appears without a source. The promise in the
paragraph above is a promise again rather than a claim.

| Class | Quest-only five | Sells |
|---|---|---|
| `fighter` | Last Stand Plate, Adrenal Harness, Blood-Fever Mail, Rally Coat, Reckless Cuirass | 4 |
| `knight` | Aegis Unbidden, Given Guard, Kept Wound, Martyr's Shield, Reflecting Shield | 14 |
| `rogue` | Cutpurse's Coat, Smokecloth Wrap, Slipstep Leathers, Opportunist's Harness, Unlit Hood | 1 |
| `hunter` | Kennelbound Jerkin, Quarryhide, Bogwalker's Coat, Ravener's Hide, Blindfold Cloak | 1 |
| `mage` | Sealed Coat, Gleaner's Mantle, Witchlight Shroud, Unravelling Habit, Gaunt Vigil Plate | 3 |
| `priest` | Reliquary Mantle, Interceding Stole, Hem of the Stayed Hand, Censer-Cloth Habit, Robes Unbidden | 2 |
| `alchemist` | Ichor Coat, Choking Apron, Everdraught Bandolier, Reagent Vest, Volatile Carapace | 4 |

Two notes on how this shook out:

- **Rogue and hunter sell one piece each, and that is deliberate rather than unfinished.** Both shelves
  had *no* armour at all before this pass, so the five quest-only pieces are most of what exists there
  — which reads correctly for the two sins whose gear is taken rather than ordered. If either shelf
  grows, it grows on the priced side; the five stay five.
- **The elemental coats are the Crucible's, not a general good.** `armor_salamander_hide`,
  `armor_stormcloth` and `armor_rimecloth` are the counterplay to fire, lightning and cold — and in
  this game those overwhelmingly arrive from a bomb, a stone or a spilled reagent. The house that sells
  the burning sells the coat, which is envy's voice and not a general good.

### Armor costs a square, and penalties stack

`Combat.applyUnitPassives` sums `bonus.movement` across the **whole 3×3 grid**, so a body wearing three
coats pays for three coats. That was always true and nothing asserted it, which is how the light tier
came to advertise *"at no cost to your pace"* while really meaning *"wear four of these"*.

So the rule is now stated and enforced (`tests/armor_spec.lua`):

| Tier | Movement |
|---|---|
| cloth (robes, wraps, habits, stoles, shrouds, mantles) | −1 |
| leather / hide | −1 |
| shield (buckler through tower) | −1 |
| medium (leather armor, chainmail, most plate) | −1 |
| heavy | −2 |

**Every piece is felt, and no armor ever grants movement.** There is no free rung. The table once had a
0 tier — *leather / hide cut for movement* — and shields sat off the table entirely at 0, which meant the
honest way to read the spread was "find the pieces that cost nothing and wear those", and because
penalties stack, four of them was a real build. What distinguishes a tier is **how much it protects**,
not whether you notice the weight.

A piece that hands a square *back* does not bend the cost table, it cancels it. The floor is −1, never a
positive. A discipline that wants to sell pace sells it as a charm, an ability, or a weapon that does not
close your move — which is why the Skirmisher's `armor_outriders_harness` buys an unanswerable opening
strike rather than the +1 it was first drafted with.

Two consequences worth naming, because they are the price of having no exceptions. Shields are inside the
rule, so a knight in chainmail and a buckler walks at 2 — on-theme for the wall, but it is a real cut to
the class that stacks the most armor. And `armor_hollow_crown` is `type = "armor"`, so the Demon Lord pays
a square for its crown and fights the last battle at 3.

**And every piece must buy that square back.** An armor grants `defense`, `magicDefense`, or a positive
`resist`; one that costs pace and returns nothing is not a trade-off, it is a trap. Pinned in the same
spec.

Base movement was raised to **4** on every character blueprint that had 3, to pay for it — deliberate
outliers (a planted banner's 0, the dire bear's ponderous 2) were left alone. The player's avatar
starts wearing `armor_leather_armor`, so the opening pace is 4 − 1 = 3, which is what the prologue's
fights are cut against.

`Combat.moveBudget` floors at 0. Over-armouring yourself into immobility is a legitimate outcome and is
left alone; a *negative* budget is not, because it reads as "less than planted" to the Dijkstra, to
Root, and to the reachable preview, and means nothing in any of them. The floor is in `moveBudget`
rather than in the fold, so the Loadout screen can still show a −5 and tell the player what they have
done to themselves.

### `class` without `price`: the tally, not the shelf

`class` mostly means *sold by* — but it has a second job, and `weapon_parasitic_staff` is the one to
know about. It carries `class = "mage"` and **no price**: no vendor stocks it, because it is issued
gear (the mage's and the priest's default weapon, `Combat.defaultWeapon`). So what is the class doing?

It is what the strike **tallies** (`Combat.useItem` → `Character.recordUse`). A priest leaning on that
staff grows a little more arcane for it — and that is the growth system working, not leaking. The same
priest's default action is Jolt, a *mage* ability, and its starting kit spans three shelves. Mixed kits
are the design: *a knight you keep casting Fireball with grows into a battlemage.*

Two consequences worth holding on to:

- **A `price` with no `class` is unbuyable dead data**, and `tests/progression_spec.lua` fails the
  build for it. There was a general store for a while and a classless price meant "the Cafe's" — the
  Cafe sells meals now (see below), so the escape hatch is closed and every price names a house. The
  reverse — `class` with no `price` — is fine and meaningful: it says "this tallies here, but nobody
  sells it." `armor_sworn_aegis`, the knight's bound relic, is one of those.
- **The weapon floor counts *sellable* weapons**, since a shelf you cannot buy from is not a shelf.

### There is no general store: seven shelves, and a kitchen

The **Cafe** used to be an eighth vendor that was not a class shelf — a rack for the classless priced
goods plus a resale counter carrying every `potion`, whichever house brewed it. It is neither now. It
declares `sells = false`, stocks nothing at all, and its whole offer is a **meal** bought before a
quest: see [meals.md](meals.md).

Two things about that belong in *this* file, because they are shelf rules rather than kitchen rules:

- **The five classless wares were given houses.** `utility_torch` → hunter (gluttony's vocabulary is
  knowing what is out there first, and a torch is the crudest instrument of it); `utility_boots_of_speed`
  → rogue (greed already owns every other boot that buys a square); `utility_stormglass_rod` → mage;
  `consumable_wellspring_sandals` → alchemist (a `consumesItem` stack that hands somebody else a
  resource back is envy twice over, and it is the party-wide reading of the Mana Potion the same house
  brews). `consumable_witchlight_flare` went to rogue in the same pass, on the argument that greed owns
  the hiding the flare answers, and has since moved to **alchemist**: a twist of ground glass thrown
  once to leave a hazard on the floor is a thing a house brews, and the mixing bench beat the
  nice line about a house selling the counter to its own trick. All five sit at `unlockQuests = 0`,
  because availability from the first visit was the one thing the general store was really providing.
- **The potion resale is closed, and that was a hole in a ladder.** A general store ignores
  `unlockQuests` by design, so a Panacea gated at ten alchemist quests was on the grocer's counter from
  the first visit: the gate was authored, displayed, and walkable around by shopping next door. A potion
  is now sold by the house that brews it and nowhere else — which is why `consumable_healing_potion`
  dropped to `unlockQuests = 0`. Its gate had only ever decided *which door* a new player bought their
  first heal through, never whether they could.

`tests/class_spec.lua` skips a `sells = false` vendor in its family-cluster sweep, and
`tests/progression_spec.lua` pins that the Cafe's shelf is empty at any standing and that every priced
item names a class.

### Monk, and why there is no fist weapon

There is no sellable fist family, and there should not be. `unarmed` is a single hidden instance found
by identity (`char.unarmed`, `unarmedDamageBonus`), and `natural` is a creature's own body — never
sold, never stolen (`models/item.lua`). A monk fist *weapon* would need a new archetype.

It does not need one. Unarmed power already flows through **fist charms in the 3×3 grid**
(`unarmedBonus`), which are utility items. Monk is a charm-driven discipline, and the priest's weapons
stay foci.

What the charms lacked was anything to spend them on — for a long time Monk was the one shelf with no
active item at all, four passives and no button. That is now answered by **chi** (`Combat.chi`), a
single per-unit pool banked by landing *bare-handed* blows and by nothing else: `Combat.dealDamage`
tallies `unarmedHit` only when the weapon is the hidden `char.unarmed` instance, so picking up a sword
stops the charge. Chi is capped (`Combat.CHI_MAX`), so it cannot be hoarded across a whole battle, and
it is **one pool shared by every monk ability** rather than the per-item baseline the signature
`unlock` system keeps — which is why both monk actives gate on a plain `when` predicate and spend the
pool in their own effect. Flurry spends three and throws three fist strikes (so the charms scale all
three); Asura Strike spends *all* of it and scales the blow by what it took. A spend must be reached
through `fx.spendChi`, never `Combat.spendChi` directly, or the damage preview would empty the pool
under the cursor — the same rule the coatings follow.

## Disciplines

A **discipline** is a named cluster of items across one or two shelves, unlocked by quests. It is a
shop taxonomy like `class` is — unlocking it adds stock, and shopping is how you build it. It is **not**
an assigned identity: there is no title and no resolver. What you become is still decided by what you
cast (`models/growth.lua`); a discipline you have unlocked is a set of items on a shelf, and the
character those items grow you into stays emergent.

**A discipline is its own growth path.** Each has a `data/growth/<id>.lua` table of its own, and a
discipline item tallies the *discipline* rather than its parent class(es)
(`Discipline.growthClasses`). So a build leaning on Ninja stock grows into a ninja — a rogue/mage blend
neither base table expresses — and a Barbarian grows harder-hitting and thinner-skinned than the
fighter it branches from. This is still emergent, not assigned: you grow toward a discipline only by
*casting its gear*, which you can only do once its gate is cleared and its stock is on the shelf. The
unlock earns the path; use walks it. (This supersedes the earlier rule where a discipline item grew
both parent classes — it could, before every discipline had a table of its own.)

But a discipline is more than a sharper price list. **Each one owns a unique mechanic** — Elementalist's
sigils, the Ninja's elemental blink, the Necromancer's raised dead. That mechanic does not live in a
class table; it **rides on the discipline's signature item**, the way every combat trait already attaches
through the grid (`models/trait.lua`). Unlock the discipline, buy the item, equip it: the mechanic is
yours — carryable, and tallied by use like anything else. That is what keeps "anyone carries anything,
identity is emergent" true even though a discipline now *does* something. The full slate of mechanics,
exemplars and rosters is the authoring plan in [disciplines-plan.md](disciplines-plan.md); this section
is the contract it obeys.

Blueprints live in `data/disciplines/<id>.lua`:

```lua
return {
    name    = "Ninja",
    description = "Fights by not being where you strike. Blink away, leave a clone to take the blow, "
        .. "and stay unseen until the killing one.",
    classes = { "rogue", "mage" },     -- 2 = multiclass; 1 = subclass
    exemplar = "character_kaen",       -- the NPC built AS this discipline, met in its unlock quest
    requiredQuests = { "quest_the_shadowless" },
}
```

**`description` is the mechanic said out loud** — what the path is, then the one thing it does, in a
sentence or two (`Discipline.description`, pinned by `tests/discipline_spec.lua`). It is the same claim
as the "Signature mechanic" line in each blueprint's header comment, written for the player instead of
for us. The shop's Buy list collapses a locked path to its header, so the section detail is the only
room a player has to read what a discipline is *before* paying the gate for it: without this, that pane
names a price for a thing it never describes.

**Arity is the whole distinction, and it makes a dependency lattice, not a flat matrix:**

- **One parent = a subclass.** It deepens a shelf; its items live on that one vendor. Gated by **one
  quest in that vendor's line**.
- **Two parents = a multiclass.** One item on *each* parent's shelf — shopping both is literally how you
  build it (a ninja is mage gear on a rogue). Gated by **earned advancement**: you must already hold a
  subclass of *each* parent, and that is what opens the multiclass's **capstone quest**. You cannot be
  sent to meet the ninja until you have walked both a rogue branch and a mage branch. A multiclass whose
  parents have no subclass yet is unauthorable — its gate can never be satisfied, which is the build
  order the tree enforces on itself.

**Every discipline has an exemplar** — a character built as that discipline (their kit *is* its items),
met in the quest that unlocks it. You do not read that a Ninja fuses two shelves; you watch one do it,
then get to build it. Disposition varies (boss, mentor, recruit); exemplars reuse the roster where a
character already embodies the thing (`character_warlord` is the Warlord, `character_champion` the
Champion) and are authored fresh for the gaps.

### Items opt in, and the field stays sparse

Items join a discipline with a top-level `discipline` field — its own field, never a tag, for the same
reason `class` is (`tags` drive damage scaling and armor `resist`; a shop taxonomy in there is one typo
away from armor mitigating "ninja" damage).

The field is **optional and sparse**. A discipline is the *locked deeper cut* of its parent shelf, never
a re-tag of the whole thing: the base shelf stays open from the first visit and the discipline adds a
further handful behind the gate. Tag too much and the base shelf empties and nothing is buyable turn
one, so most items carry no `discipline` at all. One invariant ties the field to `class`:

> **An item's `class` must be one of its discipline's parent `classes`.**

A subclass item's `class` *is* its single parent. A multiclass item carries *one* of its two parents as
`class` — its home shelf — while the discipline's `classes` list stocks it on the *other* parent's shelf
too, once unlocked. One class, two shelves.

**Growth is where a discipline item is not "one class."** Using it tallies **all** of its discipline's
parent classes (`Combat.useItem` → `Discipline.growthClasses`), so a Ninja weapon grows *both* rogue and
mage — a multiclass advances the fusion, not one half of it. That is still "what you become is decided by
what you cast": the cast simply counts for both houses. `tests/discipline_spec.lua` enforces the
class-parent invariant, so a mistagged item fails the build instead of silently vanishing off its shelf.

**Every surface that shows an item names its discipline.** The hover tooltip carries a `Discipline` row
(`ui/item_tooltip.lua`) — which covers the grid, the Armory, loot reveals, the combat log and dialogue
rewards, since they all hover the same tooltip. The two panels that build their own detail column instead
of hovering — the shop shelf (`ui/panels/shop.lua`) and the forge (`ui/panels/forge.lua`) — print the
name opposite the item's type line, via `ItemTooltip.printDiscipline`. That helper and
`Discipline.displayName` are the single owners of the wording and the tint, so no surface can drift or
print a raw id; `tests/discipline_spec.lua` pins that every tagged item resolves to a name.

### Every discipline stocks five, on both parents' shelves

Two floors, both enforced by `tests/discipline_spec.lua`:

> **A discipline stocks at least five priced items** — and **a multiclass stocks at least one on each
> parent's shelf.**

The first replaced an older "at least one buyable item," which was only ever a check against a *dead*
shelf. It could not see the real failure, which is a shelf that unlocks and hands you one cast and two
charms: three is too few to read as a build, and for a long while every multiclass had **two**. The
second is the failure nobody was looking for at all — six multiclasses had every item on one parent, so
the other vendor announced a discipline and then sold nothing for it. Artificer and Plague Knight each
had a completely empty parent.

The rosters that answer both are in [disciplines-plan.md](disciplines-plan.md). Three rules from those
passes belong here rather than there, because they bind any future roster.

**A discipline's items are authored, never retagged — unless the base shelf is holding the discipline's
own mechanic.** The multiclass pass wrote all 63 of its items new, because pulling another 63 off the
deep shelves would have emptied the racks the disciplines are supposed to sit *behind*. That rule stands
as the default. What it never covered is the reverse direction: an item already on the open shelf whose
behaviour **is** a discipline's named signature mechanic. Warden's Oath was Sentinel's Intercept, stated
word for word, sold from turn four. The base-shelf audit that followed moved seventeen of those, and the
bar it used is the bar for any future pull — *is*, not *is compatible with*. Everything else about the
retag rules holds: deep shelf only, no weapons and no shields (both are counted in family rosters of
exactly five, and a `discipline` tag drops an item out of that count), one discipline per item.

**A banner belongs to Paladin or Warlord.** Those two disciplines own the *object*, and this rule decides
by object rather than by mechanic — Pincer Banner's behaviour is a Follow-Up ally-strike reflex and it is
Warlord's anyway, because the thing is a banner. The destination follows the item's `class`: a fighter
banner is Warlord's, and a knight or priest banner is Paladin's, Warlord being fighter-only. Two carve-outs
survive it, both because a test would fail: `weapon_marching_standard` is a spear and tagging it drops
that family below its five-on-a-shelf roster, so a discipline banner-weapon has to be authored; and
`ability_march_wardens_standard` is tagged `summon` rather than `banner` and is one of only two knight-side
Warden items, so moving it would strip a parent shelf bare.

~~**A discipline consumable never wears the `potion` tag.**~~ **Moot, and kept because the shape of the
bug is worth remembering.** The Cafe used to resell anything in its `stockTags` and, as a general store,
ignored `unlockQuests` entirely — so a gated draught tagged `potion` sat on the grocer's shelf from the
first visit: the gate authored, displayed, and buyable around. Three discipline consumables tripped it
and `tests/progression_spec.lua` caught them. The resale is gone (see *There is no general store*
above), so the tag is free again. The lesson that outlives it is the general one: **a second shelf that
carries an item by tag rather than by class inherits none of that item's gates**, and any future
cross-stocking rule owes an answer to what happens to the gate.

### Watched ground: a zone of control, sold rather than granted

The knight's row above promises a shelf that *"does not kill you, it decides where you stand"*, and for
a long time every tool it had for that cost an action. A knight who spent its turn *being a wall* spent
it on nothing: a body bars its own tile and not one square more.

**Watched ground** is the answer, and it is a borrowing from Fire Emblem and *Those Who Rule* with two
things about it changed. A unit holding the **Overwatch** stance taxes every tile orthogonally beside
it — enemies pay `zone` extra to enter (`Combat.watchTax`, spent by `Combat.stepTerrainCost`).

**It is a cost, not a wall.** A watched tile is dear, never forbidden. A fast body can still shove
through by spending its whole move on it, which is a decision; a hard stop is only ever a "no". And
because the tax is just `moveCost`, every counter already existed: a flier never reads the ground at
all, and `Status.costMultiplier` discounts a whole walk, so Hasted answers it without a line of code.
No immunity status was authored, and none should be.

**It is bought, not universal, and the board size is why.** The field is 8×8 (`Arena.COLS`) with four
bodies a side (`Combat.MAX_FIELD`) and movement 3–4 after armour. Four bodies at x = 2, 4, 6, 8 already
leave no gap wider than a tile — so the flanking problem a universal zone *solves* barely exists here,
while the harm is exact: four projectors a side would control half the board and lock the fight on turn
two. FE and TWR run 15×10+ maps with 8–12 units, where a line genuinely cannot cover its own flanks.
Ours can. **Do not make this global.** One or two watchers on a field is a shape; sixteen is a stalemate.

Three items declare it, and the numbers say what each one is:

| Item | `zone` | Reads as |
|---|---|---|
| `utility_held_ground` (knight · Bulwark) | 2 | one square of road, made a bog |
| `utility_overwatch_scope` (hunter) | 1 | a wide band, watched lightly |
| `weapon_stillhunter` (hunter) | 1 | the same |

The two sentries gained theirs after the fact, deliberately: Overwatch cost a whole turn for a
*conditional* shot, and the enemy answered by walking around the firing line for free. Giving the
stance ground closes that, and the two halves feed each other without being wired together — dear
ground means more steps spent in the band, and more steps means more shots.

**Because the tax is `moveCost`, it is also initiative** (a move bills its path cost as time), so wading
past a watcher puts the walker further down the order. That is the mechanic's real teeth and the reason
the magnitudes are small.

**Measured in the window, not chosen on paper.** One `zone = 2` watcher against a 4-movement body on an
open 8×8 board removes **one or two tiles** from a 26-tile reachable set, and turns any tile that cost
exactly the full budget into one the walker cannot afford. So on open ground it is a nudge, and the
lock-down failure this section was scoped against does not happen at 2 — a body ringed by four watchers
still walks (`tests/twr_import_spec.lua` pins that). Where it bites is the doorway, which is the whole
point of a zone of control: it is supposed to be nearly invisible in a field and decisive in a gap. If
a future pass finds it too quiet, **raise the item's `zone`, never make the rule global** — the board
arithmetic above does not change.

### A live passive reads the board, not the past

Every trait hook is an *event* — struck, cast, killed — and banks its result through `ctx.addBonus`,
which writes `unit.bonus` for the rest of the battle. That is right for *"sharpens with every blow it
takes"* and wrong for *"stands stronger the more allies flank it"*: the second is a claim about the
board, and a board changes twice a turn.

So a trait may instead declare **`live`**, a pure function returning stat deltas, summed by
`Trait.liveBonus` and folded into `Combat.flatStat` beside the equipment and status terms:

```lua
live = function(ctx) return { defense = 2 * ctx.count(1, "enemy") } end
```

`ctx` offers reads only — `count(radius, "ally"|"enemy")`, `countWounded(...)`, `missing()`. **`live`
must be pure**, the same contract `adjacencyAura` carries and for the same reason: both damage previews
and the inventory tooltip call `flatStat` on every hover frame, so a passive that banked or logged
anything under the cursor would be a bug that reads as one. In particular a `live` trait must never
call `ctx.addBonus` — `flatStat` already sums that bucket, so it would count every neighbour twice.

`trait_formation_fighter` was the trait that named this gap (its header used to apologise for having no
per-turn hook) and is the one it was closed for; it now rises as a rank forms and falls as it breaks.
`trait_against_the_odds` and `trait_saviors_watch` were authored `live` from the start.
`trait_wrath_rising` was deliberately **left** as a ratchet — it is priced as one.

### Two items may change what the ground costs

`models/arena.lua` has priced forest at 2 and mountain at 3 since the first arena, and for most of the
project nothing in the catalog cared. Two fields now do, both read by `Combat.terrainEase` and both
**caps** rather than discounts, so neither can make a tile cheaper than open field:

- **`terrainEase`** — the most the ground may charge its *wearer* (`utility_trackless_boots`).
- **`escortsMovement`** — the same cap, granted to *allies* stepping through a tile beside the bearer
  (`utility_surveyors_chain`). It deliberately does **not** help its own carrier: being the bridge means
  being the one already standing in the bog.

Neither eases the watch tax, which is added *after* the cap. Good boots answer bad footing; they do not
answer a spear pointed at you.

### One place prices a tile

`Combat.stepTerrainCost` is the single reader, and this matters more than it looks. There used to be
three derivations — `moveGraph` (the Dijkstra behind the move overlay) and `Combat.planMoveVia` (a
hand-steered route) each fused their own copy of the arithmetic into a legality loop, and
`stepTerrainCost` stated it a third time for a walk cut short. That was survivable while the only term
was the tile. The moment a tile's price could depend on the board it became a promise the overlay makes
and the route breaks. **Add a term there and all three learn it at once; add it anywhere else and they
disagree.** `tests/twr_import_spec.lua` pins that the two route-finders price a watched tile identically.

One consequence to respect: the grid-derived halves are **cached per unit** (keyed on `unit.char`, so a
shapeshift invalidates it). That is not a nicety — `stepTerrainCost` runs per tile inside a Dijkstra
that runs per candidate move inside the AI's search, and `Character.eachItem` allocates.

### A charge is a named pool with a public price

The Monk's chi was the first of these and stayed the only one for a long time: a per-unit charge banked
by one specific act and spent by that discipline's abilities. It is now the general form
(`Combat.chargePool` / `Combat.spendCharge`, reached from an effect as `fx.chargePool` /
`fx.spendCharge`), and an item declares its own pool in data:

```lua
charge = { key = "zeal", from = { "kill", "healDone" }, max = 8 },
```

`from` names tallies (`Combat.tally`: `kill`, `hitDealt`, `hitTaken`, `damageDealt`, `damageTaken`,
`healDone`, `cast`, `turnTaken`, `allyDown`, `unarmedHit`). Every declaration of a key across the
bearer's grid merges — `from` unions, the highest `max` wins — so a second charm can *deepen* a pool
rather than opening a rival one. Chi is now this mechanism with a built-in definition, so the monk files
did not change.

Two rules the pool inherits from chi, and one it added:

- **Capped, and derived rather than stored.** A charge that grew all battle would make the last turn the
  only one that mattered. Overflow past `max` is never banked.
- **A spend reaches it through `fx.spendCharge`, never `Combat.spendCharge`.** The damage preview runs
  effects against an inert context; a pool that emptied itself under the cursor is a bug that reads as
  one. Same rule the coatings follow.
- **It is `chargePool`, not `charge`.** `Combat.charge` is already the Charge ability — pinning a body
  and driving it down the lane — and it has an `fx.charge` of its own. The pool took the longer name
  rather than shadow a working function.
- **A pool banks from a tally, never from carrying one particular weapon.** Zeal takes any kill and any
  nearby heal, so a Crusader who spent the fight healing still arrives at the payoff — the pool is the
  discipline's, not one item's admission fee. This is why `from` is a list.
- **A spender declares the pool it spends.** An ability that consumes Zeal banks Zeal, off the same
  tally its `unlock.text` names — buy it, equip it, and the mechanic works. The first three spenders
  (Reckoning, Answering Blow, Coup Droit) declared nothing and were inert until the player *also* owned
  the discipline's charm, which is a 380g item quietly sold as the back half of a purchase nobody
  announced. The charms keep their job through the merge: they **widen** the sources (the Vow banks what
  the whole column does, not just what you did) and **deepen** the cap (the spender's own max is
  deliberately the shallowest of the set). What no item may be is another item's on-switch.
  `tests/charge_spec.lua` scans every item source for this: name a key in `chargePool` / `spendCharge`
  and you must declare it in the same file, chi excepted (the engine declares that one). A `resetOn`
  clause travels with the spender too — it is per-item, so a pool that forfeits only when the charm is
  present is a different bargain than the one the numbers were priced for.
- **And a banker pays a dividend on the pool it banks.** The rule above reads in both directions, and was
  enforced in one for a long while: the spenders were fixed and the *widening charms* were left as pure
  `charge` declarations — Crowd's Favour, Reading the Blade, the Vow of the March, three 380–400g items
  whose entire content was a number some other purchase had to arrive to drain. Bought alone each did
  nothing whatsoever, which is the same half-a-mechanic sale with the halves swapped. So every banker now
  carries a `live` trait that **reads its pool without spending it** — Still Standing, Watching the
  Shoulder, Kept Faith, alongside the Tabard's Zealot's Mercy, which is where the shape came from: *the
  interest a pool pays while you hold it.* Reading rather than spending is what keeps the two halves one
  build — the spender still empties the pool, so cashing in drops the dividend the same instant, and
  sitting on a full purse stays a real thing to be doing. `tests/charge_spec.lua` scans for this too: an
  item that declares a `charge` must also give its bearer an `activeAbility` or a `trait`.

### A free action does not close the turn

`ab.free = true` says a cast bills no initiative and leaves the turn open — distinct from
`fx.grantExtraAction`, which hands back a turn *after* banking the full price of the action that ended
it. One is free, the other is bought on credit.

**One per turn** (`Combat.FREE_ACTIONS_PER_TURN`, tracked on `combat.turn`), because the resource costs
on a free ability bound how often you can afford it but not how often you can *press* it — a zero-cost
free action would loop forever. `Combat.itemBlockReason` greys the second one, so the limit is visible
in the grid rather than discovered by a dead click.

**A `soleAction` free ability is still the turn's action.** A plain free action (the Battle Tonic) is an
*extra* — it leaves your normal action untouched, drunk between doing things. An attack cannot be that
without handing out two attacks a turn (fire the free shot, then swing a real weapon too). So the
Harrier's Bow adds `soleAction = true`: it fires for free — no initiative, no move spent — but it
*latches* `unit.actionSpent`, and `Combat.itemBlockReason` then refuses every other item. Only the move
it left open remains. "Fire, then ride" means exactly that: fire, then *only* ride.

### The subclasses

Each is built from keywords its parent **already owns**. A subclass is a sharper reading of the shelf,
not a new vocabulary.

| Parent | Subclasses |
|---|---|
| `fighter` | **Barbarian** (fury, self-harm, `frenzy`) · **Warlord** (banners, `hazard_rally`, inspiration) |
| `knight` | **Sentinel** (guard redirect: `oathward`/`martyr`) · **Bulwark** (taunt, knockback, `defending`) |
| `rogue` | **Assassin** (execute, blink-strike) · **Thief** (`steal`, pickpocket, drain) · **Mammonite** (the purse: gold spent and banked as a combat resource) |
| `hunter` | **Druid** (shapeshifting) · **Beastmaster** (animal summons) · **Trapper** (traps) |
| `mage` | **Elementalist** (`channel`, hazards) · **Summoner** (`reserve`) · **Necromancer** (raise dead, `dark`) |
| `priest` | **Monk** (`unarmed`) · **Exorcist** (banish, dispel) |
| `alchemist` | **Poisoner** (envenom, `poison`/`acid`) · **Bombardier** (throwables, `consumesItem`) |

### The multiclass pairs

|  | knight | rogue | hunter | mage | priest | alchemist |
|---|---|---|---|---|---|---|
| **fighter** | Champion | Duelist | Skirmisher | **Battlemage** | Crusader | Warbrewer |
| **knight** | — | Vanguard | Warden | Spellbreaker | **Paladin** | Plague Knight |
| **rogue** |  | — | Poacher | **Ninja** | Inquisitor | Saboteur |
| **hunter** |  |  | — | Shaman | Totemist | Herbalist |
| **mage** |  |  |  | — | Theurge | **Artificer** |
| **priest** |  |  |  |  | — | Apothecary |

Battlemage and Ninja are not new inventions — the codebase named them years before it could sell them
(`models/growth.lua`, `models/item.lua`). Naming a pair here is cheap; **earning** it is not. A pair
gets items when its mechanics justify them, and each item still owes the corollary above. A pair that
can only produce a `+n` is not ready.

## Two kinds of aura item: the charm and the coating

Every item may carry an `aura` block, aggregated by `adjacencyAura` and read by the eight cells around
it. What decides whether it lasts forever is the item's **`type`**, and nothing else:

| | `type` | Lifetime | Priced as |
|---|---|---|---|
| a **charm** | `utility` | permanent — one of nine cells, for the rest of the campaign | a build decision |
| a **coating** | `consumable` | a stack; every deliberate cast it sharpens takes one off it | a fight decision |

`Combat.auraSpent` stops an empty coating applying and `Combat.spendAuras` bills it — deliberately
split from `adjacencyAura`, which must stay pure because the damage preview calls it on every hover. A
satchel that emptied itself under the cursor would be a bug that read as one.

A **reflex does not spend a coating**: a parry thrown with an infused blade still burns and takes
nothing off the stack. A coating is something you apply *between* swings, and an answer is not a swing
you had time to prepare for.

That split is what lets a coating be worth more per use than a permanent fixture safely could be, and
it gives the Crucible something to sell you again next week. The Fire Stone and Envenom were charms
until they became the pair the distinction was drawn for.

The full field list lives in `data/items/consumable/consumable_fire_stone.lua`, which is the file that
owns the contract.

## Known debt

Recorded here so it stays a decision rather than drift:

- **The growth tables are the weakest half of a class.** Five of seven differ only in which resource
  pool they grow. They carry far less identity than the tables above. *This is now the largest
  outstanding gap in this file.*
- ~~**`repRank` is misnamed, and standing is still points.**~~ **Done.** Standing is now literally a
  **count of the completed quests a vendor sponsors** (`Quest.sponsorProgress`); there is no reputation
  score and no rank titles. Each item names how many of the vendor's quests must be finished before it
  is on sale (`unlockQuests`, on the item, default 0). The shop shows "Quests Completed: N" in place of
  the old rank name, and each locked row says how many more of the house's quests (or which discipline
  path) unlock it. The waves open at `Vendor.TIERS = { 0, 3, 6, 10 }`, which also caps the
  ability/recipe upgrade bench. See *The ten slots* in [story.md](story.md).
- ~~**`data/disciplines/` does not exist yet.**~~ **Built.** All 38 blueprints (17 subclasses + 21
  multiclasses) load through `models/discipline.lua`, growth tallies both parents, the vendor gate
  greys locked stock, and every gate quest — both the 17 subclass gates and all 21 multiclass
  capstones — exists on disk. `tests/discipline_spec.lua` pins the structure and both gate tiers.
  What remains is content rather than plumbing: ~27 exemplar NPCs are still stand-ins, and about
  half the signature mechanics are approximations their item headers admit to. See
  [disciplines-plan.md](disciplines-plan.md).

### Settled by the Baldur's-Gate import pass

Kept here rather than deleted, because what a debt looked like when it was paid is worth reading:

- ~~**knight owns 2 abilities**~~ — now five (`push`, `shout`, `stand_down`, `shared_burden`, plus the
  `Bulwark`'s shove and the `Unyielding Seal`). The shelf reads as sloth now, and it does it by
  *inflicting* the sin rather than suffering it: `status_halted` takes an enemy's turn away without
  touching its body, and deliberately leaves its reflexes alone so it is not a second Stun.
- ~~**alchemist owns 2 abilities, and both are borrowed**~~ — the answer turned out not to be more
  abilities. It was to make the consumables *say something*: coatings that run out, elixirs that lend
  you somebody else's stat, and the Coveted Blood, whose damage stat is the rest of your party.
- ~~**The 3×3 `aura` block is under-used**~~ — the vocabulary is now `grantTags` / `requiresTags` /
  `exceptTags` / `amountBonus` / `rangeBonus` / `speedBonus` / `lifesteal` / `preserve` / `careful` /
  `twin`, and the mage's five sigils exist to spend it. `speedBonus` is the interesting one: it is the
  only aura field that touches initiative, which is the one currency nobody gets back.

## Adding an item to a class

1. Pick the shelf from **The contract**, and use a keyword that shelf owns. If you cannot name one,
   you have the wrong shelf — or a `+n`, which the forge already sells.
2. Set `class`, `price` and `unlockQuests` (how many of the vendor's quests unlock it; 0 = opening
   shelf). A `price` with no `class` is unbuyable dead data and fails the
   build (`tests/progression_spec.lua`). Stock is *derived, not authored*: the right `class` is all it
   takes to put it on that vendor's shelf.
3. If it is a weapon, it also owes its **family**'s contract — see [weapons.md](weapons.md).
4. If it belongs to a discipline, add `discipline` and make sure the parent classes match.
5. Run `& "E:\LOVE\lovec.exe" . test`.

Deviating from this file is fine when the deviation is the point — but say so in a comment, the way
the weapons contract expects.
