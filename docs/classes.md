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
| `fighter` | wrath | stamina | Trades its own health and tempo for damage. Wrath is what happens directly in front of you. Also `Growth.NEUTRAL_CLASS` — every class-less creature grows as one. | `front` aoe, `stun`, `raw`, self-cost (Fury, Desperate Strike), `frenzy`, banners |
| `knight` | sloth | stamina + mana | The wall. It does not kill you, it decides where you stand. | `taunt`, `knockback`, guard redirect (`oathward`/`martyr`), `defending` wait-swap, armor |
| `rogue` | greed | stamina | Guile. Conditional multipliers, return-to-origin blinks, and taking what is not yours. | `guile`, `blink`, execute, `steal`, `bleed`, debuff-count scaling |
| `hunter` | gluttony | stamina | Setup, then payoff — and most of it gated on a bow beside it in the grid. | `mark`, `requiresAdjacent`, traps, animal summons, shapeshifting, `cripple`/`root` |
| `mage` | pride | mana | Elements, wind-ups, and remaking the ground itself. | `channel`, hazard creation, element tags, `reserve` summons |
| `priest` | lust | mana | Zones and wards. Holds ground open and closes it to others. | `holy`, `negates`/`reflects`, `cleanse`/`dispel`, friendly hazards, revive, `unarmed` |
| `alchemist` | envy | mana | Covets others' power rather than casting its own: consumables and grid auras. | `consumesItem`, `poison`/`acid`, the `aura` block, throwables |

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
| `knight` | sword + spear + mace | `weapon_iron_sword`, `weapon_riposte_blade`, `weapon_demon_bane`, `weapon_iron_spear`, `weapon_iron_mace` |
| `rogue` | dagger | `weapon_iron_dagger`, `weapon_kingsblood_dagger`, `weapon_cutpurse_knife` |
| `hunter` | bow + longbow | `weapon_iron_bow`, `weapon_iron_longbow`, `weapon_hornbow_of_the_hunt` |
| `mage` | wand + staff | `weapon_wand`, `weapon_staff`, `weapon_emberwand` |
| `priest` | censer + staff — no edge at all | `weapon_censer`, `weapon_censer_of_ashes`, `weapon_crozier` |
| `alchemist` | dagger + wand, both envenomed | `weapon_apothecarys_lancet`, `weapon_envenomed_kris`, `weapon_vitriol_wand` |

**Every class stocks at least three.** That is a floor, not a quota — fighter and knight carry more
because they are the armed shelves, and the catalog is free to grow unevenly. What the floor forbids
is a shelf with nothing on it.

Three notes on how this shook out:

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

### `class` without `price`: the tally, not the shelf

`class` mostly means *sold by* — but it has a second job, and `weapon_parasitic_staff` is the one to
know about. It carries `class = "mage"` and **no price**: no vendor stocks it, because it is issued
gear (the mage's and the priest's default weapon, `Combat.defaultWeapon`). So what is the class doing?

It is what the strike **tallies** (`Combat.useItem` → `Character.recordUse`). A priest leaning on that
staff grows a little more arcane for it — and that is the growth system working, not leaking. The same
priest's default action is Jolt, a *mage* ability, and its starting kit spans three shelves. Mixed kits
are the design: *a knight you keep casting Fireball with grows into a battlemage.*

Two consequences worth holding on to:

- **A `price` with no `class` is a build failure** (`tests/progression_spec.lua`) — unbuyable dead data.
  The reverse is fine and meaningful: `class` with no `price` says "this tallies here, but nobody sells
  it." `armor_sworn_aegis`, the knight's bound relic, is the other one.
- **The weapon floor counts *sellable* weapons**, since a shelf you cannot buy from is not a shelf.

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

## Known debt

Recorded here so it stays a decision rather than drift:

- **knight owns 2 abilities** (`ability_push`, `ability_shout`). Its guard verbs are real but thin,
  and nothing about it yet reads specifically like *sloth*.
- **alchemist owns 2 abilities, and both are borrowed** (`ability_disarm`,
  `ability_summon_homunculus`). Its identity really lives in consumables (12 of 16) and grid auras.
  That is arguably *on theme* for envy — but it should be chosen, not inherited.
- **The 3×3 `aura` block is under-used.** `grantTags` / `requiresTags` / `amountBonus` / `lifesteal` /
  `preserve` is a full combinatorial vocabulary that about eight items touch. It is the most promising
  unexploited identity axis in the game, especially for alchemist.
- **The growth tables are the weakest half of a class.** Five of seven differ only in which resource
  pool they grow. They carry far less identity than the tables above.
- **`repRank` is misnamed.** Standing is counted in quests now, not reputation points; the field name
  is the last survivor of the old currency. A rename is mechanical and deliberately deferred.

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
