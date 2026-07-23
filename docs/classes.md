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
shop taxonomy like `class` is — it adds stock, and that is all. There is no title, no resolver, no
growth table, no trait. What you become is still decided by what you cast.

Blueprints live in `data/disciplines/<id>.lua`:

```lua
return {
    name = "Ninja",
    classes = { "rogue", "mage" },  -- 2 = multiclass; 1 = subclass
    requiredQuests = { "quest_vault_heist", "quest_grimoire_ruins" },
}
```

**Arity is the whole distinction:**

- **One parent = a subclass.** It deepens a shelf. Its items live on that one vendor.
- **Two parents = a multiclass.** One item on *each* parent's shelf. Shopping both shelves is
  literally how you build the thing — a ninja exists because you bought mage gear for your rogue.

**The gate: one quest per parent**, each sponsored by that parent's vendor. A subclass hangs off one
quest in its vendor's line; a multiclass needs one from each, because you worked for both houses. The
arity that defines a discipline is also how it is earned.

Items opt in with a top-level `discipline` field — its own field, never a tag, for the same reason
`class` is (`tags` drive damage scaling and armor `resist`; a shop taxonomy in there is one typo away
from armor mitigating "ninja" damage).

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
- **`repRank` is misnamed.** Standing is counted in quests now, not reputation points; the field name
  is the last survivor of the old currency. A rename is mechanical and deliberately deferred.
- **`data/disciplines/` does not exist.** The blueprint format is specified above and 16 subclasses +
  21 multiclass pairs are named, and not one has been authored. Several items added in the
  Baldur's-Gate pass are the first legitimate stock for one (the sigils are Elementalist's, the
  coatings Poisoner's, the Bulwark's shove Bulwark's) — but a discipline needs its quest gate before
  it needs its shelf.

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
