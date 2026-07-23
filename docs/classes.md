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
| `knight` | sloth | stamina + mana | The wall. It does not kill you, it decides where you stand — or whether you act at all. | `taunt`, `halted`, `knockback`, guard redirect (`oathward`/`martyr`/`sharesDamage`), `defending` wait-swap, armor |
| `rogue` | greed | stamina | Guile. Conditional multipliers, return-to-origin blinks, and taking what is not yours. | `guile`, `blink`, execute, `steal`, `bleed`, debuff-count scaling |
| `hunter` | gluttony | stamina | Setup, then payoff — and most of it gated on a bow beside it in the grid. | `mark`, `requiresAdjacent`, traps, animal summons, shapeshifting, `cripple`/`root` |
| `mage` | pride | mana | Elements, wind-ups, and remaking the ground itself. | `channel`, hazard creation, element tags, `reserve` summons, the **sigils** (`careful`/`twin`/`speedBonus`/`rangeBonus`) |
| `priest` | lust | mana | Zones and wards. Holds ground open and closes it to others. | `holy`, `negates`/`reflects`, `cleanse`/`dispel`, friendly hazards, revive, `unarmed` |
| `alchemist` | envy | mana | Covets others' power rather than casting its own: consumables and grid auras. | `consumesItem`, `poison`/`acid`, the `aura` block, **coatings** and **elixirs**, throwables |

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
- **The elemental coats are the Crucible's, not the Market's.** `armor_salamander_hide`,
  `armor_stormcloth` and `armor_rimecloth` are the counterplay to fire, lightning and cold — and in
  this game those overwhelmingly arrive from a bomb, a stone or a spilled reagent. The house that sells
  the burning sells the coat, which is envy's voice and not a general good.

### Cloth costs a square, and penalties stack

`Combat.applyUnitPassives` sums `bonus.movement` across the **whole 3×3 grid**, so a body wearing three
coats pays for three coats. That was always true and nothing asserted it, which is how the light tier
came to advertise *"at no cost to your pace"* while really meaning *"wear four of these"*.

So the rule is now stated and enforced (`tests/armor_spec.lua`):

| Tier | Movement |
|---|---|
| cloth (robes, wraps, habits, stoles, shrouds, mantles) | **−1**, always |
| leather / hide cut for movement | 0 |
| medium (leather armor, chainmail, most plate) | −1 |
| heavy | −2 |

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

- **A `price` with no `class` is a *general good*, not a build failure** — it goes on the general
  store's shelf (see below). What `tests/progression_spec.lua` still forbids is a price that *nothing*
  stocks: a classless priced item must actually appear in the Market's stock. The reverse — `class`
  with no `price` — is fine and meaningful: it says "this tallies here, but nobody sells it."
  `armor_sworn_aegis`, the knight's bound relic, is one of those.
- **The weapon floor counts *sellable* weapons**, since a shelf you cannot buy from is not a shelf.

### The general store

There is an eighth vendor that is not a class shelf: the **Market** (`data/vendors/market.lua`,
`general = true`). It sells two things:

1. **The classless priced goods** — the mundane supplies no sin claims: a torch, the `Boots of Speed`.
   An item lands here by having a `price` and **no `class`**; `models/vendor.lua` (`Vendor.sells`)
   derives that stock exactly the way a class vendor derives its own, so a classless priced blueprint
   is all it takes.
2. **Resold potions** — anything bearing a tag in the Market's `stockTags` (today, `potion`), whatever
   house brews it. A healing potion is an alchemist item *and* a Market item; it appears on both
   shelves. This is the one place the shelves overlap on purpose.

It has no sin and a single reputation rung: nobody quests for the grocer's favour, so every ware is
available from the first visit — `Vendor.stock` ignores `repRank` for a general store, so even a
rank-2 alchemist Panacea is simply on the shelf. Two rules keep the resale from eroding the class shelf
it borrows from:

- **A resale is not a re-home.** The potion keeps its `class`, so it still *grows the alchemist's tally*
  and still *refines only at the alchemist* — `Vendor.canRefineHere` lets a consumable be honed at its
  own house alone, never at a shop that merely resells it. The Market's Upgrade tab is empty of potions.
- **The Market sells no weapons and no abilities.** Those carry identity; the general store carries
  supplies and the potions everyone drinks. Its stock is classless gear plus resold consumables, and
  `Vendor.canUpgradeHere` refuses to hone anything here.

`tests/class_spec.lua` skips the general store in its family-cluster sweep (it is not a class shelf),
and `tests/progression_spec.lua` pins the whole arrangement.

### Monk, and why there is no fist weapon

There is no sellable fist family, and there should not be. `unarmed` is a single hidden instance found
by identity (`char.unarmed`, `unarmedDamageBonus`), and `natural` is a creature's own body — never
sold, never stolen (`models/item.lua`). A monk fist *weapon* would need a new archetype.

It does not need one. Unarmed power already flows through **fist charms in the 3×3 grid**
(`unarmedBonus`), which are utility items. Monk is a charm-driven discipline, and the priest's weapons
stay foci.

## Disciplines

A **discipline** is a named cluster of items across one or two shelves, unlocked by quests. It is a
shop taxonomy like `class` is — unlocking it adds stock, and shopping is how you build it. It is **not**
an assigned identity: there is no title, no resolver, no growth table. What you become is still decided
by what you cast (`models/growth.lua`); a discipline you have unlocked is a set of items on a shelf, and
the character those items grow you into stays emergent.

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
    classes = { "rogue", "mage" },     -- 2 = multiclass; 1 = subclass
    exemplar = "character_kaen",       -- the NPC built AS this discipline, met in its unlock quest
    requiredQuests = { "quest_the_shadowless" },
}
```

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

The item tooltip shows an item's discipline when it has one (`ui/item_tooltip.lua`), so the deeper cut is
legible on the shelf and in the grid.

### The subclasses

Each is built from keywords its parent **already owns**. A subclass is a sharper reading of the shelf,
not a new vocabulary.

| Parent | Subclasses |
|---|---|
| `fighter` | **Barbarian** (fury, self-harm, `frenzy`) · **Warlord** (banners, `hazard_rally`, inspiration) |
| `knight` | **Sentinel** (guard redirect: `oathward`/`martyr`) · **Bulwark** (taunt, knockback, `defending`) |
| `rogue` | **Assassin** (execute, blink-strike) · **Thief** (`steal`, pickpocket, drain) |
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
- **`repRank` is misnamed, and standing is still points.** The intent — and what an earlier version of
  this line claimed as done — is that standing be a **count of distinct completed quests per sponsor**
  (`ranks = { 0, 3, 6, 9 }`). `Player.addReputation` and `Vendor.rankFor` have never done that; they
  sum `rewardRep`. The consequence is live rather than cosmetic now that no quest is repeatable: every
  vendor line clears rank 4 on its authored quests (275–325 against 200), but rank 4 arrives a slot or
  two before the ninth, which loosens the rule that the standing putting the rank-4 relic on the shelf
  is the standing that lets you face what it was warning about. See *The ten slots* in
  [story.md](story.md). The rename is mechanical; the counting change is the real work.
- ~~**`data/disciplines/` does not exist yet.**~~ **Built.** All 37 blueprints (16 subclasses + 21
  multiclasses) load through `models/discipline.lua`, growth tallies both parents, the vendor gate
  greys locked stock, and every gate quest — both the 16 subclass gates and all 21 multiclass
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
2. Set `class`, `price` and `repRank`. A `price` with no `class` is unbuyable dead data and fails the
   build (`tests/progression_spec.lua`). Stock is *derived, not authored*: the right `class` is all it
   takes to put it on that vendor's shelf.
3. If it is a weapon, it also owes its **family**'s contract — see [weapons.md](weapons.md).
4. If it belongs to a discipline, add `discipline` and make sure the parent classes match.
5. Run `& "E:\LOVE\lovec.exe" . test`.

Deviating from this file is fine when the deviation is the point — but say so in a comment, the way
the weapons contract expects.
