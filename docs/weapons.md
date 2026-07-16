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
| `sword` | Average damage and speed, `hands = 1`, and it **parries**: answers an adjacent melee blow with one of its own, for a little stamina. The reference weapon the melee kit is tuned against — its edge is costing nothing up front, and leaving a hand free. | `iron_sword` |
| `greatsword` | **Channels** a turn, then lands on one tile for the heaviest hit in the game. `hands = 2`. Its own family, *not* a sword — it must not also parry. | `iron_greatsword` |
| `axe` | **Cleaves**: `aoe = { shape = "front", width = 3 }`, a 3-wide arc perpendicular to the aimed tile. Softer per target than a sword; worth it when more than one thing is in front of you. | `iron_axe` |
| `spear` | **Skewers a line**: `aoe = { shape = "line", length = 2 }`, the two tiles directly in front. `hands = 2`. | `iron_spear` |
| `mace` | **Knocks back** 2 tiles; a collision hurts everything in it. You buy the displacement, not the damage. | `iron_mace` |
| `hammer` | **Stuns**, and is ponderous (`speed` 7) — you buy the stun with your own tempo. `hands = 2`. | `iron_hammer` |
| `dagger` | **Quick** (`speed` 1–2) and applies **Bleed**. Modest damage; the wound does the rest. | `iron_dagger` |
| `bow` | **Ranged physical**. `requiresSight`, and `minRange = 2` — a bow has no point-blank shot. `hands = 2`, as every bow is. | `iron_bow` |
| `longbow` | **Channels** a turn to draw, then looses from `range = 5` — two tiles beyond a bow — keeping `requiresSight`, `minRange = 2` and `hands = 2`. Its own family, *not* a bow: the draw is the verb, and the reach is what pays for it. | `iron_longbow` |
| `wand` | **Ranged magical**. `requiresSight`, and *no* `minRange`: a wand needs only a direction, which is its whole claim over a bow. | `wand` |
| `staff` | Swaps **Wait → Focus** (`waitBehavior`): end the turn to recover mana. The swap *is* the weapon; the strike is a deliberate afterthought. | `staff` |
| `shield` | Swaps **Wait → Defend** (`waitBehavior`): brace for a burst of physical defense. Lives in `data/items/armor/`, not `weapon/`. | `buckler` |
| `unarmed` | The player's bare fist. Reads `unarmedBonus` from "fist" charms in the grid. | `unarmed` |
| `natural` | A creature's own body — fangs, claws, an elemental's burning hands. Granted by a blueprint's `startingItems`, never sold or stolen (`noSteal`), and owes no shared mechanic beyond that. | `fangs`, `flame_fists` |

## Naming: the base weapon is `iron_x`

Each family's plain, undecorated weapon is named **`iron_<family>`** — `iron_sword`, `iron_axe`,
`iron_bow`. It is the family's reference implementation: the mechanic and nothing else, the thing
every other weapon in the family is measured against.

The forged-metal families all follow it. `wand`, `staff` and `buckler` are the deliberate exceptions
— a wand and a staff are foci rather than forged blades ("Iron Wand" would be lying about the
object), and a buckler is a named kind of shield the way a hatchet is a named kind of axe. Creatures'
weapons (`natural`) are never "base" at all; nobody forges a wolf.

## A named weapon must do something the base one cannot

The corollary of the contract: if a weapon's only claim over `iron_<family>` is bigger numbers, it is
not a weapon, it is a `+n`. That is what the forge is for. Every named weapon therefore owes an
**extra** — a mechanic its base counterpart does not have:

| Weapon | Family | Its extra over the base |
|---|---|---|
| `riposte_blade` | sword | Swaps Parry for **Riposte** — the blow is *negated*, not traded, and answered anyway. |
| `demon_bane` | sword | Its blows carry the `holy` tag, which demonic flesh resists in the negative. |
| `butchers_wedge` | axe | **`frenzy`**: every extra body in the arc raises what all of them take. Poor against one foe — the crowd is its damage stat. |
| `crimson_greataxe` | axe | **`lifesteal`**: drinks a third of everything the arc opens, so it heals most when most outnumbered. |
| `kingsblood_dagger` | dagger | Half the swing again through a foe **already bleeding**, and its own wound runs deeper (5, not 3). It takes what is already open. |
| `hornbow_of_the_hunt` | bow | Every tile past the point-blank band adds a fifth of the shot. It wants the whole field between you and the kill. |
| `parasitic_staff` | staff | Siphons mana on the **hit**, so Focus is its floor rather than its only recourse. |
| `oathkeeper_shield` | shield | `waitBehavior.covers`: bracing also braces every **adjacent ally**. Where you plant decides who else gets the wall. |

A good extra changes *how the weapon is played*, not how big its number is. The Hornbow inverts a bow's
usual pull toward the edge of its band; the Wedge turns being surrounded from a danger into the point.
Prefer that over a flat bonus.

Overlapping an existing charm is **fine** — a weapon may carry `lifesteal` natively even though the
Vampiric Strike charm grants it, and may apply statuses on hit. They stack rather than compete (a
Crimson Greataxe with a Vampiric Strike beside it drinks at 83%). The two axes above are the pattern
worth copying: one family, one base, and two named weapons pulling it in opposite directions —
`butchers_wedge` hits a crowd harder, `crimson_greataxe` lives through one.

## Keywords

A keyword is a **declarative field on an `activeAbility`** that the model implements, so any weapon or
ability can opt into the mechanic by naming it — no per-file code, and the damage preview understands
it for free. Prefer one over hand-rolling the same logic in an `effect`.

| Keyword | Meaning |
|---|---|
| `channel = n` | Wind up for `n` ticks; the cast resolves on the wielder's next turn, and hard control breaks it. |
| `aoe = { shape, … }` | The area the cast covers: `square`, `diamond`, `line` (length), `front` (width). |
| `frenzy = f` | Every body the area catches **beyond the first** adds `f` of the magnitude to what *each* of them takes. Counts bodies, not enemies — an ally in the arc feeds it too. |
| `lifesteal = f` | The user heals `f` of everything the cast deals. Adds to a Vampiric Strike aura rather than overriding it. |
| `minRange = n` | A dead zone: the cast cannot be aimed closer than `n`. |
| `requiresSight` | Needs a clear line (`Combat.hasLineOfSight`); terrain cover blocks it. |
| `requiresAdjacent = { type, tag }` | Only usable with a matching item beside it in the 3×3 grid. |
| `consumesItem` | Spends one of the stack on use. |

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
`fx.aoeUnits`). Three are worth knowing about:

**Wait swaps** (`staff`, `shield`). An item declaring `waitBehavior = { kind = "focus" | "defend" |
"overwatch", … }` changes what its holder's Wait button does — `Combat.waitBehavior` scans the grid
and first-in-inventory wins. The payoff key (`mana` / `defense` / `stamina`) scales with the item's
upgrade level; `speed` deliberately does not, since an upgrade should never buy back tempo.

**Bleed** (`dagger`). The game's one *positional* debuff: it fires from `onEnterTile`, so it damages
once per tile the victim crosses and not at all for standing still. A bleeding unit chooses between
its position and its health. It is `raw` (armor-piercing) — armor turns a blade, but does nothing
about a wound already open, and a mitigated tick would floor at 1 against every armored foe and stop
meaning anything. Being *dragged* bleeds (a mace shove costs the victim two tiles it never chose);
**blinking does not**, which is exactly the premium a blink should command. See `Combat.enterTile`'s
`reason` argument.

**Parry / Riposte** (`sword`). Every sword answers a melee blow. The two reflexes differ in kind:

- `parry` (`data/traits/parry.lua`) — a **trade**: take the hit, then answer it. 4 stamina, 20-tick
  cooldown.
- `riposte` (`data/traits/riposte.lua`) — **not** a trade: the blow is turned aside so it deals
  nothing *and* is answered. 6 stamina, 16-tick cooldown, and the only reflex in the game that both
  negates and counters. It fires pre-mitigation from `Trait.tryRiposte` (beside Dodge and Smoke
  Screen), because a hook only ever fires on a blow that already landed.

A sword carries **one** of them, never both — `riposte_blade` swaps parry out for riposte, and that
swap is the whole of what its price buys. Both decline to answer a blow that is itself a reaction
(`Trait.isReacting`), or two swordsmen would volley counters on every exchange.

### Pricing a triggered reflex

Every triggered reflex — `parry`, `riposte`, and the priest's `keen_senses` — is priced in **both** a
`cost = { stat, amount }` and a `magnitude` cooldown, paid through `payCost` in `models/trait.lua`
(hooks reach it as `ctx.pay()`). The two are different levers and a reflex wants both: the cooldown
paces answers **within** an exchange, the stamina bounds them **across** a battle. Cost is always the
**last** gate — check suppression, range and cooldown first, or a reflex that then declines has
silently billed its bearer. A def with no `cost` is free (the passive reflexes — `dodge`,
`melee_counter`, `ranged_counter` — still are).

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
the way `riposte_blade` explains why it is the one sword that does not parry.
