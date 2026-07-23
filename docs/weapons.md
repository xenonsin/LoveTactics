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
**extra** — a mechanic its base counterpart does not have:

| Weapon | Family | Its extra over the base |
|---|---|---|
| `weapon_riposte_blade` | sword | Swaps Parry for **Riposte** — the blow is *negated*, not traded, and answered anyway. |
| `weapon_demon_bane` | sword | Its blows carry the `holy` tag, which demonic flesh resists in the negative. |
| `weapon_crescent_blade` | sword | Looses the cut instead of landing it: a **3-tile line** of `magical` damage down the aimed direction, so the blade never reaches what it kills and armor never gets a say. Paid for out of **two pools at once** (see below) — the first weapon in the game that is. |
| `weapon_butchers_wedge` | axe | **`frenzy`**: every extra body in the arc raises what all of them take. Poor against one foe — the crowd is its damage stat. |
| `weapon_crimson_greataxe` | axe | **`lifesteal`**: drinks a third of everything the arc opens, so it heals most when most outnumbered. |
| `weapon_kingsblood_dagger` | dagger | Half the swing again through a foe **already bleeding**, and its own wound runs deeper (5, not 3). It takes what is already open. |
| `weapon_cutpurse_knife` | dagger | **Drains stamina** into the rogue. Stamina is what buys a foe's reflexes, so a few cuts in, its guard stops answering — for everyone. Worthless against a beast that had none. |
| `weapon_hornbow_of_the_hunt` | bow | Every tile past the point-blank band adds a fifth of the shot. It wants the whole field between you and the kill. |
| `weapon_parasitic_staff` | staff | Siphons mana on the **hit**, so Focus is its floor rather than its only recourse. |
| `weapon_crozier` | staff | `waitBehavior.covers`: Focus also feeds mana to every **adjacent ally**. A mage's staff answers *my* mana ran out; this one answers the party's. |
| `weapon_intercessors_staff` | staff | Names one ally at the start of battle, and every blow it lands **mends that ally** instead of the priest. Lifesteal pointed at somebody else — and the only healer in the game that heals by attacking. |
| `weapon_emberwand` | wand | Its bolt **leaves the ground alight**. Asks where the enemy is willing to stand rather than how hard it can hit — and the fire is unsided, so it is a wall you must be willing to stand behind. |
| `weapon_vitriol_wand` | wand | Lays **Acid** (−6 to both defenses). Declines to out-damage armor and removes it instead, so its damage stat is the rest of your party. Fire it first. |
| `weapon_envenomed_kris` | dagger | Bleed **and** Poison. Bleed taxes moving, Poison taxes waiting — together they close the door that standing still used to open. |
| `weapon_apothecarys_lancet` | dagger | The one dagger that **does not bleed** — it delivers Poison instead. A deviation, and deliberately so: Bleed is a question the victim answers by standing still, and Poison is not a question. |
| `weapon_censer_of_ashes` | censer | A **hostile** cloud: it chokes the smoke instead of blessing it, so the walk toward the enemy is itself the attack. |
| `armor_oathkeeper_shield` | shield | `waitBehavior.covers`: bracing also braces every **adjacent ally**. Where you plant decides who else gets the wall. |
| `weapon_quarrys_answer` | bow | **Shoots back.** The first weapon-borne counter that is not a blade — so the reach rule reads inverted: it answers what a sword never can, and its own `minRange` is a dead zone for the reply. Close on it and the reflex switches off. |
| `weapon_stillhunter` | bow | The only weapon carrying the **Overwatch** wait swap — the stance stops costing a grid cell (`utility_overwatch_scope`) and starts costing arrows: its curve is under iron's at every level. |
| `weapon_hailfall_longbow` | longbow | Looses **five arrows on five random tiles** of a 2-radius spread instead of one aimed shaft. Buys coverage, gives up the promise — and hits your own line, since falling arrows are not aimed. |
| `weapon_slipknife` | dagger | **Slipstep**: struck from any range, it arrives beside the attacker and cuts. The one reflex reach does not gate — what gates it is open ground next to whoever swung. |
| `weapon_mailpiercer` | spear | The line lands **`raw`** (no defense, no resist) and the **far** tile is left **Halted**. A bad spear against the unarmoured, and increasingly good against a wall. |
| `weapon_marching_standard` | spear | The thrust **plants a standard** — Rally ground for as long as the pole stands — when none of its own is up. Raised for free by a swing rather than by a turn, and it never silences the weapon that raised it (`noClaim`). |
| `weapon_turning_year` | wand | **Alternates fire and frost**, each half setting up the other (Frozen is brittle to fire) — a two-cast combo one caster plays alone. Its bearer can neither Burn nor Freeze. |
| `armor_bulwark_shield` | shield | A **reflex** rather than a stance: `trait_shield_shove` drives a melee attacker two tiles back. Deals nothing — the wall, the fire and the trap behind them do the talking. |

The two named shields are the axis worth reading together, and they are the same pattern the two axes
and the two censers already set: one family, one base, two named items pulling it in opposite
directions. The Oathkeeper spreads its brace outward to the line; the Bulwark keeps everything to
itself and spends it on the one foe that closed.

A good extra changes *how the weapon is played*, not how big its number is. The Hornbow inverts a bow's
usual pull toward the edge of its band; the Wedge turns being surrounded from a danger into the point.
Prefer that over a flat bonus.

Overlapping an existing charm is **fine** — a weapon may carry `lifesteal` natively even though the
Vampiric Strike charm grants it, and may apply statuses on hit. They stack rather than compete (a
Crimson Greataxe with a Vampiric Strike beside it drinks at 83%). The two axes above are the pattern
worth copying: one family, one base, and two named weapons pulling it in opposite directions —
`weapon_butchers_wedge` hits a crowd harder, `weapon_crimson_greataxe` lives through one.

The two censers are that same pattern: `weapon_censer` blesses the ground it walks and
`weapon_censer_of_ashes` chokes it. Both are the Cathedral's — the censer family belongs to one shelf
and no other (see [classes.md](classes.md)) — so the family's two directions say something about *lust*
rather than about two classes: the object never changes, only the voice it is swung in.

`weapon_crozier` and `armor_oathkeeper_shield` are worth reading together too: both spend
`waitBehavior.covers`, so one word means "and everyone beside you" on either half of the wait swap.

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
   `Item.resolveLevel`); `class` + `repRank` + `price` decide which vendor shelf stocks it.
5. Run `& "E:\LOVE\lovec.exe" . test` — the sweep in `tests/weapon_spec.lua` will tell you if you
   dropped the family's mechanic, and there is a case per named weapon pinning its extra.

Deviating from the contract is fine when it is the point of the weapon — but say so in a comment,
the way `weapon_riposte_blade` explains why it is the one sword that does not parry.
