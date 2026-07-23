# Weapon archetypes

Every weapon belongs to a **family**, and the family decides the base mechanics that weapon
inherits: axes cleave, hammers stun, daggers bleed. This file is the contract. A new weapon picks a
family and keeps its mechanics; deviating is allowed, but it must be a decision, not a drift.

`tests/weapon_spec.lua` enforces the table below by sweeping every weapon blueprint, so a new axe
that forgets to cleave fails the build rather than quietly becoming a worse sword.

## How a family is declared

The archetype is **a tag drawn from `Item.ARCHETYPES`** (`models/item.lua`), and a weapon carries
exactly one:

```lua
tags = { "dagger", "pierce", "physical", "melee" },
--        ^archetype ^hit-tag  ^school    ^reach
```

All four are peers in one flat list, and **position is never read** — `Item.archetype(item)` finds
the family by membership, so re-ordering an item's tags can never change what it is. The other three
are what the engine already reads: `magical` routes damage through Magic Damage / Magic Defense
(`models/combat.lua`), and armor `resist` keys off the hit tag and the school.

The family is deliberately *not* the same idea as `class` (`fighter`, `rogue`, …), which only says
which vendor stocks the item and never gates who may carry it. A hunter may absolutely buy a dagger.

## The contract

| Family | Base mechanic | Base weapon |
|---|---|---|
| `sword` | Average damage and speed, `hands = 1`, and it **parries**: answers an adjacent melee blow with one of its own, for a little stamina. The reference weapon the melee kit is tuned against — its edge is costing nothing up front, and leaving a hand free. | `weapon_iron_sword` |
| `greatsword` | **Channels** a turn, then lands on one tile for the heaviest hit in the game. `hands = 2`. Its own family, *not* a sword — it must not also parry. | `weapon_iron_greatsword` |
| `axe` | **Cleaves**: `aoe = { shape = "front", width = 3 }`, a 3-wide arc perpendicular to the aimed tile. Softer per target than a sword; worth it when more than one thing is in front of you. | `weapon_iron_axe` |
| `spear` | **Skewers a line**: `aoe = { shape = "line", length = 2 }`, the two tiles directly in front. `hands = 2`. | `weapon_iron_spear` |
| `mace` | **Knocks back** 2 tiles; a collision hurts everything in it. You buy the displacement, not the damage. | `weapon_iron_mace` |
| `hammer` | **Stuns**, and is ponderous (`speed` 7) — you buy the stun with your own tempo. `hands = 2`. | `weapon_iron_hammer` |
| `dagger` | **Quick** (`speed` 1–2) and applies **Bleed**. Modest damage; the wound does the rest. | `weapon_iron_dagger` |
| `bow` | **Ranged physical**. `requiresSight`, and `minRange = 2` — a bow has no point-blank shot. `hands = 2`, as every bow is. | `weapon_iron_bow` |
| `longbow` | **Channels** a turn to draw, then looses from `range = 5` — two tiles beyond a bow — keeping `requiresSight`, `minRange = 2` and `hands = 2`. Its own family, *not* a bow: the draw is the verb, and the reach is what pays for it. | `weapon_iron_longbow` |
| `wand` | **Ranged magical**. `requiresSight`, and *no* `minRange`: a wand needs only a direction, which is its whole claim over a bow. | `weapon_wand` |
| `staff` | Swaps **Wait → Focus** (`waitBehavior`): end the turn to recover mana. The swap *is* the weapon; the strike is a deliberate afterthought. | `weapon_staff` |
| `censer` | **Emits `incense`**: a square of ground around the bearer, lifted and laid again wherever they go. The smoke is the weapon and the strike an afterthought, as a staff's is — but where a staff's swap pays the bearer, a censer's ground pays whoever stands in it. | `weapon_censer` |
| `shield` | Swaps **Wait → Defend** (`waitBehavior`): brace for a burst of physical defense. Lives in `data/items/armor/`, not `weapon/`. | `armor_buckler` |
| `unarmed` | The player's bare fist. Reads `unarmedBonus` from "fist" charms in the grid. | `weapon_unarmed` |
| `natural` | A creature's own body — fangs, claws, an elemental's burning hands. Granted by a blueprint's `startingItems`, never sold or stolen (`noSteal`), and owes no shared mechanic beyond that. | `weapon_fangs`, `weapon_flame_fists` |

## Naming: the base weapon is `weapon_iron_x`

Every file under `data/items/` carries its **type as a prefix** — `weapon_`, `armor_`, `utility_`,
`consumable_`, `ability_` — because `models/registry.lua` keys blueprints by bare filename into one
flat namespace where the subfolder is invisible. Without the prefix, `consumable/net.lua` and a
future `weapon/net.lua` would silently collide. The prefix is the id, so the file's own name is the
only thing standing between the two.

**Every registry follows this rule**, not just items: `status_burn`, `trait_dodge`,
`character_knight`, `material_mythril`, `encounter_elite`, `conversation_wrath_intro`, `hazard_fire`.
The registries are separate tables and could not collide with each other, so this is a rule about
*reading* rather than about correctness: an id says what kind of thing it names, at the call site,
without the reader having to know which registry a bare `"wrath"` or `"mark"` came from. The game is
full of words that mean several things — `"charm"` is an item tag, `"wrath"` is a vendor's sin,
`"silenced"` is a refusal reason — and the prefix is what keeps a *registry id* distinguishable from
all of them at a glance.

Within that, each family's plain, undecorated weapon is named **`weapon_iron_<family>`** —
`weapon_iron_sword`, `weapon_iron_axe`, `weapon_iron_bow`. It is the family's reference
implementation: the mechanic and nothing else, the thing every other weapon in the family is
measured against.

**Every base weapon is `repRank = 1`.** A family's plain expression is stocked from the first visit and
what gates it is the purse, not the standing — `weapon_iron_greatsword` is rank 1 at 300 gold, which is
five times an iron sword and still on the shelf on day one.

## The shape of a family: ten weapons, five and five

Each of the thirteen shoppable families carries **ten** weapons, split down the middle:

- **Five on the vendor's shelf** — `class` + `price` + `repRank`, climbing the shelf's ladder. Rank 4 is
  the ceiling (every `data/vendors/` table is four rungs, and the general quests gate on rank 4 as "the
  highest standing"), so a family reads 1-2-3-4-4 with its two capstones sharing the top rung.
- **Five quest-only** — `class` and **no `price`**. The missing price is what makes it quest-only rather
  than merely expensive: `models/spoils.lua` builds the random drop pool out of every priced item, so an
  unpriced weapon can never fall out of a fight. The `class` stays, because it is also what the strike
  tallies toward for growth. They are granted through a quest's `rewardItems`.

**Signature and relic weapons do not count toward the ten.** A companion's signature (`weapon_first_motion`,
`weapon_borrowed_time`, `armor_sworn_aegis`) and a general's relic (`weapon_forsworn_pike`,
`weapon_gralloch_knife`) are tagged `signature` / `relic` and sit outside their family's roster entirely —
so authoring the signatures still owed to Kaya, Ren and Gyeom cannot make a family overflow.

The rank ladder is a property of a **shelf**, not of a family. The dagger family spans two vendors, so it
climbs 1/3/4 on the rogue's and 1/4 on the alchemist's — and each of those starts at 1 because
`tests/class_spec.lua` refuses a vendor that cannot arm a newcomer.

The forged-metal families all follow it. `weapon_wand`, `weapon_staff`, `weapon_censer` and
`armor_buckler` are the deliberate exceptions — a wand, a staff and a censer are foci rather than
forged blades ("Iron Censer" would be lying about the object), and a buckler is a named kind of shield
the way a hatchet is a named kind of axe. Creatures' weapons (`natural`) are never "base" at all;
nobody forges a wolf.

Beware the ids that are also **tags** (`weapon_iron_dagger`'s id vs. the `dagger` archetype tag) and the
utility items that grant a **same-named trait** (`utility_second_wind` grants trait `trait_second_wind`).
The prefix keeps all three apart: the tag stays bare, and each registry's id wears its own kind.

The prefix is *only* for registry ids. Namespaces that are not registries keep their bare words —
a growth `class` (`class = "knight"`, from `data/growth/`), an item `tag`, an encounter `kind`
(`kind = "elite"`), a refusal `reason`, a vendor's `sin`. `character_knight` and the `knight` growth
class are different things that happen to share a word, and only the first is an id.

## A named weapon must do something the base one cannot

The corollary of the contract: if a weapon's only claim over `iron_<family>` is bigger numbers, it is
not a weapon, it is a `+n`. That is what the forge is for. Every named weapon therefore owes an
**extra** — a mechanic its base counterpart does not have.

The rosters below are the whole catalog. **S** is a shelf weapon (with its `repRank`); **Q** is
quest-only. Each family's base weapon is rank 1 and listed first; signature and relic weapons sit
outside the count and are not listed here.

### `sword` — knight
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_iron_sword` | the base: parries, one-handed |
| S2 | `weapon_riposte_blade` | Swaps Parry for **Riposte** — the blow is *negated*, not traded, and answered anyway. |
| S3 | `weapon_demon_bane` | Its blows carry the `holy` tag, which demonic flesh resists in the negative. |
| S4 | `weapon_crescent_blade` | Looses the cut instead of landing it: a **3-tile line** of `magical` damage down the aimed direction, so the blade never reaches what it kills and armor never gets a say. Paid for out of **two pools at once**. |
| S4 | `weapon_duelists_edge` | Its parry **binds instead of cutting** (`status_duelbound`): whoever swung cannot walk away from the exchange. Deals nothing — it answers a skirmisher's whole plan. |
| Q | `weapon_wardens_tongue` | Every parry also **braces the allies beside you**. `covers` spoken through a reflex: the enemy chooses when it fires. |
| Q | `weapon_unclosing_edge` | Its parry deals nothing and opens a wound that **cannot be healed** (`status_unclosing_wound`). Takes the enemy healer off one body. |
| Q | `weapon_sunderers_answer` | Its parry **silences every trait and reflex** the attacker carries (`status_sundered`). Unplugs one side of an answerer's duel. |
| Q | `weapon_splitglass_saber` | Its parry cuts back **and raises Splitglass on the bearer** — answering is also warding, until the escalating price empties the pool. |
| Q | `weapon_lending_blade` | The swing **moves armour**: `status_given_guard` off the target, `status_lent_guard` onto an ally beside you. Worthless fighting alone. |

### `greatsword` — fighter
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_iron_greatsword` | the base: channels 2, heaviest single-tile hit |
| S2 | `weapon_headsmans_cleaver` | **Half the telegraph** (channel 1), and full weight only into a foe under half health. The closer to Saber's opener. |
| S3 | `weapon_bellowing_edge` | The impact **taunts** every foe within two tiles onto you — the family's telegraph turned into a plan for the next one. |
| S4 | `weapon_sealed_hour` | `status_sealed_hour`: all damage and healing on that body is **held, then settles at once**. Wastes the enemy healer; terrible for finishing. |
| S4 | `weapon_avalanche` | The only greatsword whose wind-up **length is chosen**: two extra ticks widen the fall from one tile to a 3-wide arc. |
| Q | `weapon_long_count` | Harder for **every turn taken this battle** (`turnTaken`). The deliberate opposite of the First Motion — it pays for outlasting a fight, not opening one. |
| Q | `weapon_whitening` | The blow lands **`magical`**: the heaviest hit in the game, aimed at the stat plate armour never raised. |
| Q | `weapon_the_stillness` | The landing tile becomes `hazard_stillness` — a hole in the enemy turn order that is a fact about a *square*, so nothing can cleanse it. |
| Q | `weapon_kingsfall` | `steadfast`: **nothing breaks the wind-up.** The control still lands in full — only the cancellation is refused. |
| Q | `weapon_given_hour` | The blow **hands the turn it cost to an adjacent ally** (`grantExtraAction`). The only weapon that gives burst to somebody else. |

### `axe` — fighter
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_iron_axe` | the base: cleaves a 3-wide front arc |
| S2 | `weapon_tithe_axe` | Every body the arc opens **pays the company coin** (`Combat.bounty`). The crowd is the payroll. |
| S3 | `weapon_butchers_wedge` | **`frenzy`**: every extra body in the arc raises what all of them take. Poor against one foe — the crowd is its damage stat. |
| S4 | `weapon_crimson_greataxe` | **`lifesteal`**: drinks a third of everything the arc opens, so it heals most when most outnumbered. |
| S4 | `weapon_splitting_maul` | The arc leaves everything **Conjoined** — each of them takes half of every wound the others suffer. Turns the party's single-target damage into area damage. |
| Q | `weapon_reapers_due` | Harder for **every foe already killed this battle** — and an axe is the weapon that fills that counter fastest. |
| Q | `weapon_carrion_axe` | The swing **eats corpses** in its arc and mends the wielder. Pays out of the dead, so it works on an empty swing. |
| Q | `weapon_hollow_arc` | The arc lands **`magical`** *and* leaves `status_hollowed` — so it sets itself up, and makes your own knight's sword useless on those bodies. |
| Q | `weapon_ledgemans_axe` | Knockback on the **outer two tiles only**: one swing splits a rank of three and leaves the centre standing alone. Manufactures a duel. |
| Q | `weapon_wolfs_portion` | **Inverted frenzy** ⚠️: devastating into one body, falling off hard for every extra. The family's duel weapon, and a stated deviation. |

### `spear` — knight
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_iron_spear` | the base: skewers a 2-tile line |
| S2 | `weapon_boar_spear` | The crossbar: the **near** tile is Rooted and cannot back off the point. |
| S3 | `weapon_exposing_pike` | The line is left **Exposed** (+8 from every pierce hit) — and pierce is what every spear, bow and half the daggers already carry. Its damage stat is the party. |
| S4 | `weapon_mailpiercer` | The line lands **`raw`** (no defense, no resist) and the **far** tile is left **Halted**. |
| S4 | `weapon_marching_standard` | The thrust **plants a standard** — Rally ground for as long as the pole stands. Raised for free by a swing, and it never silences the weapon that raised it (`noClaim`). |
| Q | `weapon_second_rank` | Reaches a **third tile while an ally stands directly behind you**. The pike drill as a weapon — the only item that reads the tile at your back. |
| Q | `weapon_disarming_pike` | Both tiles are **Disarmed**: no weapon usable, bare fists still fine. Worthless against a beast, which is the honest reading of a disarm. |
| Q | `weapon_knell_point` | The **far** tile is marked for death (`status_knell`). Must be thrust *through* somebody, so the enemy's own front rank gates it. |
| Q | `weapon_tidesbreak` | Soaks the line (`water`, `status_wet`), drives it back a pace, and **the bearer steps into the gap** — the only weapon that advances its wielder. |
| Q | `weapon_sworn_lance` | Both tiles are **sworn to each other**: either that ends a turn apart bleeds for it. Acedia's rule, taken off her — the line is what pairs them. |

### `mace` — knight
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_iron_mace` | the base: shoves 2 tiles, collisions hurt |
| S2 | `weapon_bell_hammer` | One tile of shove, **double collision damage**. Worthless in the open, enormous against a wall. |
| S3 | `weapon_wetstone_mace` | Lands `lightning` and leaves the target **Wet** — so its own second swing is worth six more. Self-comboing. |
| S4 | `weapon_gathering_bell` | **Drags them toward you** instead of away. Everything the party prices around adjacency wants the enemy gathered. |
| S4 | `weapon_long_fall` | **Four tiles** of shove and almost no damage. Pure board control; the party has to be built to collect. |
| Q | `weapon_shepherds_crook` | Shoves an **ally** two tiles and deals nothing to anyone ⚠️. Movement is the scarcest thing in this game and nothing else gives it back. |
| Q | `weapon_debt_bell` | The collision hits **everything adjacent to where they land**. The body is the ordnance; the aim decides who pays. |
| Q | `weapon_rimebell` | The tiles they are **dragged across** freeze over. The only zone painted with somebody else's body. |
| Q | `weapon_answering_bell` | Carries `trait_shield_shove`: **shoves whoever strikes it**. A body nobody can stay next to. |
| Q | `weapon_suspension_mace` | `status_suspended` instead of a shove — displacement in **time**. Your party cannot touch it either. |

### `hammer` — fighter
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_iron_hammer` | the base: stuns, ponderous (speed 7) |
| S2 | `weapon_tinkers_maul` | **Strips the brace and the wards** (Defending, both barriers, Splitglass) before it stuns. The can-opener for a shield wall. |
| S3 | `weapon_frostfall_hammer` | **Freezes instead of stunning** — and Freeze is +6 to `impact`, which this hammer is. Its own second swing is the payoff. |
| S4 | `weapon_sleepers_maul` | **Sleep** instead of a stun: far longer, and broken the moment anyone hits it. Asks the whole party not to. |
| S4 | `weapon_slow_verdict` | **Speed 10**, the slowest swing in the game, for double stun duration. The family's bargain at full volume. |
| Q | `weapon_anvil_of_the_ninth` | A huge stun that also leaves the **wielder Halted**. Halted still moves and still answers, which is where the dead beat goes. |
| Q | `weapon_mired_maul` | The impact tile becomes `hazard_quicksand`: makes them late, then makes being late expensive. |
| Q | `weapon_bellfounders_hammer` | The **only AoE stun** — full on the target, a shorter one on the ring. The axe's argument imported into the hammer's. |
| Q | `weapon_unspent_blow` | **Banks** its stun; every third swing spends all three at once, `raw`. The hammer's answer to armour. |
| Q | `weapon_tempo_debt` | No stun — it **re-opens your own turn** instead ⚠️. The family's trade run backwards. |

### `dagger` — rogue / alchemist
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_iron_dagger` | the base: quick, and it bleeds |
| S1 | `weapon_apothecarys_lancet` | The one dagger that **does not bleed** — Poison instead. Bleed is a question the victim answers by standing still; Poison is not a question. |
| S3 | `weapon_cutpurse_knife` | **Drains stamina** into the rogue. Stamina buys a foe's reflexes, so its guard stops answering — for everyone. |
| S4 | `weapon_envenomed_kris` | Bleed **and** Poison. One taxes moving, the other taxes waiting. |
| S4 | `weapon_throughline` | The thrust **carries into the tile behind**, scaling per adjacent dagger. A dagger that refuses to be single-target. |
| Q | `weapon_kingsblood_dagger` | Half the swing again through a foe **already bleeding**, and its own wound runs deeper (5, not 3). |
| Q | `weapon_slipknife` | **Slipstep**: struck from any range, it arrives beside the attacker and cuts. The one reflex reach does not gate. |
| Q | `weapon_thin_place` | The strike lands **`magical`** and the Bleed stays **`raw`** — two different defenses in one swing, on one pool. |
| Q | `weapon_nightjar` | A **kill** makes the rogue Unseen until its next turn. Kill, vanish, cross the field, kill. |
| Q | `weapon_mired_kris` | Bleed **and Mired**: walking costs blood and acting costs double. There is no correct move left. |

### `bow` — hunter
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_iron_bow` | the base: ranged, `requiresSight`, `minRange` 2 |
| S2 | `weapon_limning_bow` | Leaves the target **Limned** — targetable however well it hides. Stops the assassin vanishing afterwards. |
| S3 | `weapon_stillhunter` | The only weapon carrying the **Overwatch** wait swap — the stance stops costing a grid cell and starts costing arrows. |
| S4 | `weapon_quarrys_answer` | **Shoots back.** The reach rule inverted: its own `minRange` is a dead zone for the reply, so closing switches the reflex off. |
| S4 | `weapon_hornbow_of_the_hunt` | Every tile past the point-blank band adds a fifth of the shot. It wants the whole field between you and the kill. |
| Q | `weapon_witchlight_bow` | Leaves **lit ground** where the shaft lands: anti-stealth as area denial, and it outlives whoever was standing there. |
| Q | `weapon_corvids_bow` | **Blinds**: the target's own abilities stop reaching. The only counter in the game to range as such. |
| Q | `weapon_struck_ledger` | **Prices** the target — lit up, and worth coin when it falls. Its output is measured in the campaign layer. |
| Q | `weapon_windward` | Hardest at the **edge of its dead zone**, falling off with distance ⚠️. The exact inverse of the Hornbow. |
| Q | `weapon_unravelling_shaft` | Leaves `hazard_unravelling` under the target — the mage's setup, laid from the back line several turns early. |

### `longbow` — hunter
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_iron_longbow` | the base: channels, range 5, `minRange` 2 |
| S2 | `weapon_wardens_longbow` | The **draw's depth is chosen** (`windup`) — up to three extra ticks, each adding a quarter of the shot. |
| S3 | `weapon_piercing_draw` | The shaft runs a **3-tile line** and lands **`raw`**. The hunter's answer to heavy infantry in a corridor. |
| S4 | `weapon_hailfall_longbow` | **Five arrows on five random tiles** of a 2-radius spread. Buys coverage, gives up the promise — and hits your own line. |
| S4 | `weapon_long_silence` | **Silences** at five tiles. Not an interrupt — a way of deciding their *second* spell does not happen. |
| Q | `weapon_held_breath` | `channelStatus`: **drawing makes the archer Unseen**, through the exact turn the enemy would have used to punish the draw. |
| Q | `weapon_sunfall` | Lands burning and leaves `hazard_burning_halo` — the one zone that scorches *and* blinds, so a rank in it stops shooting. |
| Q | `weapon_knell_shaft` | **Marks for death** at five tiles. Ignores the health bar entirely, and the answer is a cleanse — a turn their healer spends not healing. |
| Q | `weapon_deadfall_bow` | The draw **arms a trap** instead of loosing. Resolves against a prediction rather than a body. |
| Q | `weapon_last_word` | Far harder for **every ally who has fallen** (`allyDown`). The one weapon that gets stronger as the run goes wrong. |

### `wand` — mage / alchemist
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_wand` | the base: ranged magical, no `minRange` |
| S2 | `weapon_emberwand` | Its bolt **leaves the ground alight**. Asks where the enemy is willing to stand — and the fire is unsided. |
| S3 | `weapon_vitriol_wand` | Lays **Acid** (−6 to both defenses). Declines to out-damage armor and removes it instead. Fire it first. |
| S4 | `weapon_turning_year` | **Alternates fire and frost**, each half setting up the other. Its bearer can neither Burn nor Freeze. |
| S4 | `weapon_conductor` | **Arcs to every soaked body on the field.** Soaks nobody itself — it collects on the knight's Wetstone Mace and Tidesbreak. |
| Q | `weapon_unravelling_wand` | The bolt is **`physical`** — no ward turns it — and leaves `status_unravelled` for every spell that follows. |
| Q | `weapon_swineherds_wand` | **Polymorph**: it can walk, and it can do nothing else. The hardest single piece of control in the game. |
| Q | `weapon_sealed_ward_wand` | Aimed at an **ally** ⚠️, deals nothing: seals them so the next single-target spell at them is refused outright. |
| Q | `weapon_reflecting_wand` | Aimed at an **ally**: the next single-target spell at them **rebounds onto its caster**. The greedy read where the Sealed Ward is the safe one. |
| Q | `weapon_second_utterance_wand` | Lets one ally's next **channelled** working resolve instantly. Deletes the telegraph a greatsword or longbow pays. |

### `staff` — mage / priest
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `weapon_staff` | the base: Wait → Focus |
| S2 | `weapon_parasitic_staff` | Siphons mana on the **hit**, so Focus is its floor rather than its only recourse. |
| S3 | `weapon_crozier` | `waitBehavior.covers`: Focus also feeds mana to every **adjacent ally**. A mage's staff answers *my* mana ran out; this one answers the party's. |
| S4 | `weapon_intercessors_staff` | Names one ally at the start of battle, and every blow it lands **mends that ally**. The only healer in the game that heals by attacking. |
| S4 | `weapon_warding_staff` | `waitBehavior.status`: Focus also raises a **Magical Barrier**. Answers the turn a mage is most likely to die on. |
| Q | `weapon_graven_circle_staff` | `waitBehavior.hazard`: Focus **cuts sigils** into the ground. Gives a caster a position worth defending — and one they can be driven off. |
| Q | `weapon_overchannelled_staff` | `waitBehavior.toll`: **double the mana, paid in blood.** Stops the mage running out of mana and starts it running out of health. |
| Q | `weapon_iron_crook` | Its strike is **`physical`/`impact`** ⚠️ — no ward turns it and no silence stops it. The Arcanum's answer to being gagged. |
| Q | `weapon_renewal_staff` | Focus lays `hazard_renewal`: mana for you, **health for whoever stands there**, including people who arrive later. |
| Q | `weapon_gag_crook` | `waitBehavior.afflicts` — `covers` pointed **outward**: Focus cuts every adjacent enemy off from magic. The one hostile wait swap. |

### `censer` — priest
| | Weapon | Which cloud it walks |
|---|---|---|
| S1 | `weapon_censer` | the base: `hazard_incense`, allies Blessed |
| S2 | `weapon_censer_of_the_mustered_field` | `hazard_muster` — allies braced *and* enemies open. The only zone that does both jobs from one square. |
| S3 | `weapon_censer_of_ashes` | A **hostile** cloud (`hazard_choking`): it chokes the smoke instead of blessing it, so walking toward the enemy is itself the attack. |
| S4 | `weapon_censer_of_cold_light` | `hazard_witchlight` — a walking lamp. Anti-stealth that does not have to target what it reveals. |
| S4 | `weapon_censer_of_the_red_hour` | `hazard_bloodsong` — allies drink back what they deal. Rewards a priest who pushes into the melee. |
| Q | `weapon_drowned_censer` | `hazard_rain` — the **unsided** one. Worth everything beside the Conductor and actively harmful beside a fire mage. |
| Q | `weapon_censer_of_the_grasping_hollow` | `hazard_grasping_hollow` — ground that walks *and* holds. Nobody can disengage from the least threatening body on the board. |
| Q | `weapon_censer_of_the_unravelling` | `hazard_unravelling` — a mobile amplifier for the party's mage, centred on a priest who is therefore always standing in it. |
| Q | `weapon_sealed_censer` | `hazard_gagging_storm` — a carried anti-caster bubble that cannot be resisted or cleansed. Turns off your own mage too. |
| Q | `weapon_censer_of_the_hollow_dark` | `hazard_darkness` — a walking wall against every `requiresSight` weapon, in both directions. Its strike is `dark`. |

### `shield` — knight *(lives in `data/items/armor/`)*
| | Weapon | Its extra over the base |
|---|---|---|
| S1 | `armor_buckler` | the base: Wait → Defend |
| S2 | `armor_tower_shield` | The deepest brace on the shelf, and it **roots the holder**. A commitment to the square rather than the turn. |
| S3 | `armor_bulwark_shield` | A **reflex** rather than a stance: `trait_shield_shove` drives a melee attacker two tiles back. Deals nothing — the wall, the fire and the trap behind them do the talking. |
| S4 | `armor_oathkeeper_shield` | `waitBehavior.covers`: bracing also braces every **adjacent ally**. Where you plant decides who else gets the wall. |
| S4 | `armor_shared_bulwark` | Lays `hazard_shared_bulwark`: covered **ground**, so allies who arrive later are covered too. |
| Q | `armor_martyrs_shield` | `coversStatus`: bracing takes **half of every wound your neighbours suffer**. The furthest `covers` can be pushed. |
| Q | `armor_reflecting_shield` | Bracing is a **mirror** — the next single-target physical blow rebounds. The shield-side pair to the Reflecting Wand. |
| Q | `armor_given_guard` | Bracing **gives the guard away**: `lent_guard` to every ally, `given_guard` on yourself. The only shield that leaves the holder worse off. |
| Q | `armor_kept_wound_shield` | Bracing **swallows** the next few blows and gives it all back at once. Converts an unsurvivable burst into a healing check. |
| Q | `armor_aegis_unbidden` | The only shield that braces against **magic** (`status_aegis` + a `magical` resist). The family's blind spot, filled. |

A good extra changes *how the weapon is played*, not how big its number is. The Hornbow inverts a bow's
usual pull toward the edge of its band; the Wedge turns being surrounded from a danger into the point.
Prefer that over a flat bonus. ⚠️ marks a **deliberate deviation** from the family contract — each of
those files says so in its own header, the way `weapon_riposte_blade` explains why it is the one sword
that does not parry.

Overlapping an existing charm is **fine** — a weapon may carry `lifesteal` natively even though the
Vampiric Strike charm grants it, and may apply statuses on hit. They stack rather than compete (a
Crimson Greataxe with a Vampiric Strike beside it drinks at 83%).

**Pairs are the unit of design here, not weapons.** The pattern the two axes set — one family, one base,
two named items pulling it in opposite directions — is now the whole catalog's shape, and the most useful
ones cross shelves:

- `armor_oathkeeper_shield` spreads its brace outward; `armor_bulwark_shield` keeps everything to itself
  and spends it on the one foe that closed.
- `weapon_censer` blesses the ground it walks and `weapon_censer_of_ashes` chokes it. Both are the
  Cathedral's — the censer family belongs to one shelf and no other (see [classes.md](classes.md)) — so
  the family's two directions say something about *lust* rather than about two classes: the object never
  changes, only the voice it is swung in.
- `weapon_crozier` and `armor_oathkeeper_shield` both spend `waitBehavior.covers`, so one word means "and
  everyone beside you" on either half of the wait swap — and `weapon_gag_crook` is that word aimed at the
  enemy instead.
- `weapon_first_motion` pays for opening a fight and `weapon_long_count` for outlasting one; the same
  arithmetic with the sign flipped, on a signature and a shelf weapon.
- `weapon_hornbow_of_the_hunt` wants the whole field between you and the kill; `weapon_windward` wants
  none of it.
- `weapon_wetstone_mace` (knight) soaks and shocks alone, `weapon_tidesbreak` (knight) soaks a rank and
  does nothing with it, `weapon_drowned_censer` (priest) soaks whatever it walks past, and
  `weapon_conductor` (mage) soaks nobody and collects on all three. One combo, four shelves.
- `weapon_sealed_hour` schedules a kill and `armor_kept_wound_shield` schedules a rescue, off the same
  hold-it-then-settle machinery.

### Weapons that change school

A family's school is a default, not a law. Six weapons cross it deliberately, and each states so in its
header. What they buy is the same in every case — the defense the target actually stacked stops
applying — and what they cost is everything that half of the game brings with it.

| Weapon | Family | Lands as | What it dodges | What it now fears |
|---|---|---|---|---|
| `weapon_crescent_blade` | sword | `magical` | armor, `resist physical` | Silence, wards, `resist magical` |
| `weapon_whitening` | greatsword | `magical` | armor | as above |
| `weapon_hollow_arc` | axe | `magical` | armor — and it applies `status_hollowed`, so it sets *itself* up | as above |
| `weapon_thin_place` | dagger | `magical` strike, `raw` bleed | both, in one swing | a ward stops the stab but never the wound |
| `weapon_unravelling_wand` | wand | `physical` | wards, barriers, `resist magical` | armor, `resist physical` |
| `weapon_iron_crook` | staff | `physical`/`impact` | wards, and Silence entirely | armor |

The line every one of them draws: what deviates is the school of the **wound**, never of the **work**. A
Whitening still costs stamina and an Unravelling Wand still costs mana — so a Silence still gags the wand
and never the greatsword, and `Combat.isMagicItem` keeps reading the price rather than the tags.

The elemental tags are the softer version of the same move. `weapon_frostfall_hammer` (`ice`) freezes and
then shatters its own ice, because Freeze is +6 against `impact`; `weapon_wetstone_mace` (`lightning`)
soaks and then conducts; `weapon_sunfall` (`fire`) and `weapon_censer_of_the_hollow_dark` (`dark`) pick up
whatever the target's armor happens to resist. A hit tag is free to declare and every one of them is a
line in somebody's `resist` table.

## Keywords

A keyword is a **declarative field on an `activeAbility`** that the model implements, so any weapon or
ability can opt into the mechanic by naming it — no per-file code, and the damage preview understands
it for free. Prefer one over hand-rolling the same logic in an `effect`.

| Keyword | Meaning |
|---|---|
| `channel = n` | Wind up for `n` ticks; the cast resolves on the wielder's next turn, and hard control breaks it. Exactly `n` — walking first never stretches the telegraph, the move cost is charged past the resolution instead. |
| `aoe = { shape, … }` | The area the cast covers: `square`, `diamond`, `line` (length), `front` (width). |
| `frenzy = f` | Every body the area catches **beyond the first** adds `f` of the magnitude to what *each* of them takes. Counts bodies, not enemies — an ally in the arc feeds it too. |
| `lifesteal = f` | The user heals `f` of everything the cast deals. Adds to a Vampiric Strike aura rather than overriding it. |
| `minRange = n` | A dead zone: the cast cannot be aimed closer than `n`. |
| `requiresSight` | Needs a clear line (`Combat.hasLineOfSight`); terrain cover blocks it. |
| `requiresAdjacent = { type, tag }` | Only usable with a matching item beside it in the 3×3 grid. |
| `consumesItem` | Spends one of the stack on use. |
| `windup = { min, max }` | The channel's length is **chosen at cast**, between `min` and `max` extra ticks; the effect reads `fx.windup`. `weapon_avalanche` spends it on footprint, `weapon_wardens_longbow` on damage. |
| `channelStatus = id` | A status the caster gains **on commit** and carries through the wind-up. The half an `effect` cannot reach — an effect runs when the cast resolves, and this has to land before the enemy's turn to punish the tell (`weapon_held_breath`). |
| `steadfast` | The wind-up **cannot be interrupted**. The control still lands in full; only the cancellation is refused, so a stun aimed at it is insufficient rather than wasted (`weapon_kingsfall`). |

### What a neighbouring item can do to a cast

The keywords above are declared **on the ability**. The `aura` block is the mirror of them, declared on
a *neighbour* — the same mechanics reached from the other side of the grid, so an item can sharpen a
cast it does not own. `grantTags` / `requiresTags` / `exceptTags` / `status` / `amountBonus` /
`rangeBonus` / `speedBonus` / `lifesteal` / `preserve` / `careful` / `twin`; the full contract lives in
`data/items/consumable/consumable_fire_stone.lua` and the two kinds of item that carry one (the
permanent **charm** and the spent **coating**) are in [classes.md](classes.md).

Two of them are worth knowing here because they change what a cast *is* rather than what it is worth:

- **`careful`** narrows `fx.aoeUnits` to the caster's enemies (`Combat.castUnits`), so a blast steps
  over your own line. It does **not** narrow `aoeCells` — the sigil steers the blast, never the ground
  it leaves behind, which is the same rule the banner/trail/incense family already runs on.
- **`twin`** forks a single-target cast into one more body beside its target (`Combat.twinTarget`),
  gated on the very `Combat.isSingleTarget` the counter rules read. The fork re-enters the same
  `fx.damage` the first hit went through, so it inherits every aura tag, on-hit status and lifesteal
  the original carried — and cannot fork again.

`speedBonus` is folded into `Combat.actionSpeed`, the single reader the timeline ghost, the hover
preview and the live `endTurn` all quote, and floored there at 1. **No arrangement of the grid may make
an action free** — a zero-speed cast would let a unit act, keep initiative 0, and act forever, so the
rule is made unreachable by arithmetic rather than by a warning.

### The extra action

`Combat.grantExtraAction(unit, n)` re-opens a turn instead of ending it. It is a fact about a *unit*,
not a property of the ability that granted it, so an ability (`ability_surge`), a trait and a boss
phase all reach for the same three lines.

What it buys is **order, not time**. Every tick the surged action would have cost is banked as
`Combat.tempoDebt` and paid in full when the unit finally stops, so acting twice lands you
correspondingly further down the timeline — you have spent tomorrow's turn today. What the player
gains is two actions with no enemy beat between them, which is what burst has always been for. It
grants no second walk: the turn re-opens with the move already spent.

That is the honest shape of "extra action" in a game with no action points. Initiative is the only
currency here, and there is nothing else for it to cost.

### Paying for a cast out of more than one pool

`activeAbility.cost` may name **one** pool or **several**, and the two forms are the same field:

```lua
cost = { stat = "stamina", amount = 8 }        -- one pool (nearly everything)
cost = { { stat = "mana",    amount = 4 },     -- several, ALL paid on every use
         { stat = "stamina", amount = 6 } }
```

`Item.costs` normalizes both to a list, and everything downstream — pricing (`Combat.abilityCosts`),
the affordability gate (`costBlock`), the spend (`Combat.spendCosts`), the answer price
(`Trait.answerCost`) and all four places the UI draws a cost — iterates that list. So a multi-pool
weapon cannot be affordable in one place and unaffordable in another, and no data file needs to know
which shape it is written in.

Three consequences worth knowing, all of which fall out rather than being special-cased:

- **It is all-or-nothing.** Every pool must cover its share or the cast is refused, and the message
  names the first that fell short. A weapon spending mana and stamina is stopped by an empty arm as
  surely as by an empty head.
- **Any mana in the price makes it sorcery.** `Combat.isMagicItem`, the silence gate, and the
  Silence-interrupts-a-channel rule all ask "does this draw on mana *at all*", so a half-stamina
  working is still gagged by a Silence.
- **An answer costs both.** Since an answer is billed the answering weapon's own `cost`
  (`Trait.answerCost`), a `weapon_crescent_blade` parry drains mana and stamina together, with the
  round's escalation applied to each. A blade that guards a doorway on two pools empties faster than
  one that guards it on one — which is the price of the reach.

`frenzy` and `lifesteal` both fold in at a single funnel — `castAmount` and `adjacencyAura`
respectively (`models/combat.lua`) — which is what keeps the number a tooltip promises identical to
the one the swing delivers, across all three cast paths (preview, `strikeWith`, `resolveCast`).

`unarmed` and `natural` are distinct on purpose. The fist charms find the player's bare hands **by
identity** (`char.unarmed`, see `unarmedDamageBonus` in `models/combat.lua`), not by tag — so tagging
a wolf's fangs `unarmed` would not feed it those bonuses, it would only make them undisarmable by
accident.

## The mechanisms behind the contract

Most families need no engine support — they are an `activeAbility` shape (`aoe`, `range`, `channel`,
`speed`) plus an `effect(fx)` that calls an existing helper (`fx.knockback`, `fx.applyStatus`,
`fx.aoeUnits`). Four are worth knowing about.

Note that the three below are **item-level** fields, not `activeAbility` ones, so they are not keywords
in the sense the table above means: they describe what carrying the thing does, rather than what casting
it does. That is the actual shared idea behind these families — for a staff, a shield and a censer, the
strike is the afterthought and the *having* is the weapon.

**Wait swaps** (`staff`, `shield`). An item declaring `waitBehavior = { kind = "focus" | "defend" |
"overwatch" | "perform", … }` changes what its holder's Wait button does — `Combat.waitBehavior` scans
the grid and first-in-inventory wins. The payoff key (`mana` / `defense` / `stamina` / `covers` /
`duration` / `amount`) scales with the item's upgrade level; `speed` deliberately does not, since an
upgrade should never buy back tempo. `covers` spreads the payoff to adjacent allies and reads the same
on both halves — a wall for `armor_oathkeeper_shield`, mana for `weapon_crozier`.

A stance has no `effect` to hook, so a named staff or shield whose extra lands on the *meditation* or the
*brace* has nowhere else to put it. Five more declarative keys cover that, and they read the same on both
halves of the swap:

| Key | Meaning | Where |
|---|---|---|
| `status` | What the swapper gains besides the ordinary payoff. | `weapon_warding_staff` (a ward), `armor_tower_shield` (a root — a *cost*, not a gift), `armor_aegis_unbidden` |
| `coversStatus` | The same, handed to adjacent allies rather than the holder. `covers` spreads the payoff's **size**; this spreads its **kind**. | `armor_martyrs_shield`, `armor_given_guard` |
| `afflicts` | `covers` pointed **outward**: applied to every adjacent *enemy*. The one hostile wait swap. | `weapon_gag_crook` |
| `hazard = { id, radius, … }` | Ground laid under the swapper. It **plants and leaves it** — deliberately not `incense`, since a censer's cloud is lifted and re-laid on every step, and that lifting is exactly what separates the two families. | `weapon_graven_circle_staff`, `weapon_renewal_staff` |
| `toll = { stat, amount }` | A resource the swap **spends**, for a stance that trades one pool for another. A drain, not damage: nothing mitigates it and it cannot kill. | `weapon_overchannelled_staff` |

`toll` deliberately does *not* scale with the forge while its payoff does, so upgrading makes the bargain
better rather than merely bigger — the decision a weapon asks should get easier to answer correctly, never
harder.

A swap is **not a weapon family**, and two of the four are granted by plain utility charms
(`utility_focus_stone`, `utility_overwatch_scope`, `utility_hunting_horn`). Reach for a charm before a
new archetype: a family owes a base weapon, a strike and a row in the table above, and none of that is
worth authoring for a thing whose whole mechanic is that you are *not* swinging it.

`perform` is the odd one and the only **cycle**: `Combat.perform` sounds the next air in the item's
`songs` list on the bearer and every ally within `earshot`, then advances a cursor kept on the *unit*
(so a horn handed to somebody else starts over). The other three do the same thing on every press; this
does a different thing each time, in a fixed order — which is why the button names the next air rather
than the verb, and why the whole cycle is listed in the tooltip. Reaching the air you want costs the
turns spent walking through the ones you did not, and `earshot` does not scale with the forge for the
same reason a censer's radius does not.

**Incense** (`censer`). An item declaring `incense = { hazard, radius, amount }` lays that hazard in a
square around its bearer, **owned by them**, and `Combat.layIncense` lifts the previous cloud by
owner+id before laying the next. That lifting is the entire mechanic: without it the smoke would pile up
into a wake, which is what `trail` already is. Three ways to hold ground, one machine:

| | Owned by | Lifted? | Reads as |
|---|---|---|---|
| a **banner** (`hazard_rally`) | a body planted in it | on the owner's death | ground that **stays** |
| a **trail** (Pilgrim's Sandals) | nobody | never — it outlives your passing | ground you **leave behind** |
| **incense** (`censer`) | the bearer | every time they move | ground that **walks** |

It is laid from `Combat.enterTile` *before* that function's `Hazard.reap` — the bearer stands in the
middle of its own cloud, and reaping first would strip the blessing it is in the act of granting (the
same ordering `layTrail` needs, and for the same reason). Unlike a trail it ignores `reason` entirely:
smoke is carried rather than pressed by feet, so it keeps up with a blink. It is laid again from
`Combat.rebase`, which is the half movement cannot cover — a bearer who never moves, and construction.
`amount` scales with the forge; `radius` deliberately does not, on the same principle as `speed` above:
an upgrade buys a stronger blessing, never a wider one.

**Bleed** (`dagger`). The game's one *positional* debuff: it fires from `onEnterTile`, so it damages
once per tile the victim crosses and not at all for standing still. A bleeding unit chooses between
its position and its health. It is `raw` (armor-piercing) — armor turns a blade, but does nothing
about a wound already open, and a mitigated tick would floor at 1 against every armored foe and stop
meaning anything. Being *dragged* bleeds (a mace shove costs the victim two tiles it never chose);
**blinking does not**, which is exactly the premium a blink should command. See `Combat.enterTile`'s
`reason` argument.

**Parry / Riposte** (`sword`). Every sword answers a blow it can reach. The two reflexes differ in kind:

- `parry` (`data/traits/trait_parry.lua`) — a **trade**: take the hit, then answer it.
- `riposte` (`data/traits/trait_riposte.lua`) — **not** a trade: the blow is turned aside so it deals
  nothing *and* is answered. The only reflex in the game that both negates and counters. It fires
  pre-mitigation from `Trait.tryRiposte` (beside Dodge and Smoke Screen), because a hook only ever
  fires on a blow that already landed.

A sword carries **one** of them, never both — `weapon_riposte_blade` swaps parry out for riposte, and that
swap is the whole of what its price buys. Both decline to answer a blow that is itself a reaction
(`Trait.isReacting`), or two swordsmen would volley counters on every exchange.

### Pricing a triggered reflex

**Reach is the gate, and the only one.** A defender answers a blow struck from a tile it can reach back
at. *Which* reach depends on where the reflex came from: a **weapon-borne** counter — the sword's Parry —
answers only within *its own weapon's* band, so a bow sharing the grid does not lend the blade two
tiles (*"how can the bow parry?"*). A counter granted by a **utility** with no weapon of its own — the
Reprisal Quiver's Ranged Counter — answers with whatever weapon in the grid can reach, via
`Combat.answeringWeapon`, which honours each weapon's `minRange` dead zone as well as its range. Both
paths gate on `Trait.mayCounter`. Nothing recharges; there are no cooldowns on anything that answers
with a blow. That is deliberate and it is the point: the answer to *"why didn't I get countered?"* has to be
a fact the player can see on the board before committing, not a hidden timer. An archer cannot answer
a foe in its face, and closing that distance is the counter to a counter.

Two consequences fall out of this rather than being tuned in:

- **An answer is a swing, so it costs what a swing costs** — the answering weapon's own
  `activeAbility.cost`, read by `Trait.answerCost`. A dagger answers for 4, an iron sword for 8, a
  greatsword for 16. Nobody maintains a second table, and the greatsword's "must not also parry" rule
  above holds by economics instead of by exception.
- **Each answer in a round costs double the last** (capped at ×8), reset when the bearer next acts.
  This is what paces answers *within* an exchange now that the cooldowns are gone, and it does it in a
  pool the player can watch drain rather than a clock they cannot see. Stand in a doorway against
  three foes and you answer the first at price, the second at double, the third at quadruple — and
  then you are out.

A reflex that does **not** swing — `thorns` reflecting a share of the blow off its spikes,
`shield_bash` landing a stun — has no weapon in the motion to read a price off, so it pays its own
declared `cost` instead (escalated the same way). Cost is always the **last** gate: check suppression,
reach and friendly fire first, or a reflex that then declines has silently billed its bearer.

### The one reflex that refuses the question: `closes`

`counter = { closes = true }` (`weapon_slipknife`'s Slipstep) does not reach across the gap, it
**crosses it** — the bearer arrives beside whoever struck it and swings from there. Distance stops
gating, and three readers change together so the rule stays one rule:

- **`Trait.mayCounter`** asks for open ground beside the attacker instead of a band. That is still a
  fact the player can read off the board before committing — fight it from inside a press and the
  knife has nowhere to appear — which is the whole point of having no timers here.
- **`Trait.answerCost`** prices it at **one tile**, because that is where the swing is actually thrown
  from. Without that, an answer to a bowshot across the field would be read off a weapon that never
  swung, and across a gap nothing covers, off *no* weapon — i.e. free.
- **`Trait.counterPreview`** weighs it at one tile for the same reason, so the hover warning quotes the
  knife the player is about to eat rather than a dash.

It is deliberately not a negation: it fires from the ordinary `onDamaged` hook, so the blow lands in
full and a *killing* blow goes unanswered. What it buys is a cut and a position — including, half the
time, standing in the open next to the thing that just shot you.

Cooldowns still exist and are still the right tool for reflexes that **negate** a blow rather than
answer it — `dodge`, `smoke_screen`, `counter_magic` — plus the non-combat reflexes (`cleansing_ward`,
`opportunist`, the `oathward` redirect). Those are mitigations, not a second beat in an exchange, and
a free always-on mitigation would be untouchable.

## Adding a weapon

1. Pick a family and put its tag in `tags`, with the school / hit / reach tags beside it.
2. Copy the base weapon's `activeAbility` shape and keep the family's mechanic.
3. Give it an **extra** the base weapon does not have (see above). If you cannot name one, what you
   are holding is a `+n` of the base weapon, and the forge already sells that. Reach for a keyword
   first; hand-roll in the `effect` only when no keyword fits.
4. Author `damage` as a per-level curve over levels 0–10 (see `models/item.lua`'s
   `Item.resolveLevel`).
5. Decide which half of the ten it is:
   - **Shelf** — set `class`, `price` and `repRank` (1–4; rank 4 is the vendor ceiling).
   - **Quest-only** — set `class` and **no `price`**. The missing price is the whole mechanism: it keeps
     the weapon out of the spoils pool (`models/spoils.lua`), while `class` still tallies it toward
     growth. Grant it from a quest's `rewardItems`.
   - **A signature or a general's relic** — tag it `signature` / `relic`, and it sits outside the
     family's ten entirely.
6. Run `& "E:\LOVE\lovec.exe" . test` — the sweep in `tests/weapon_spec.lua` will tell you if you
   dropped the family's mechanic, and there is a case per named weapon pinning its extra.

Deviating from the contract is fine when it is the point of the weapon — but say so in a comment,
the way `weapon_riposte_blade` explains why it is the one sword that does not parry. The catalog's
current deviations are marked ⚠️ in the rosters above.
