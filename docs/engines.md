# Build engines

The 3x3 grid was meant to be a deck and its nine items a build. In play it was neither: a body cast
the one or two abilities that dealt the most damage, and the other seven cells were stat sticks. The
diagnosis was three things at once — one fungible cost pool, a subtractive damage formula that widens
the biggest hit's lead, and grid adjacency that was mostly a gate.

An **engine** is the deck-builder answer: a **build-up** the fight feeds, a **multiplier** that grows
it, and a **payoff** that spends it. Designed and reviewed with the author over three rounds on
2026-11-18; the code is `models/engine.lua`, the cases are `tests/engines_spec.lua`.

## The rules every engine keeps

- **Pieces are weak alone.** A multiplier with nothing to multiply does almost nothing, so collecting
  the set is a choice rather than a pile of the best numbers.
- **Every engine has a grid piece** — at least one item that reads its neighbours, so where it sits
  matters.
- **Scaling resets every fight.** A unit is rebuilt for every battle, and so is every tally, pool and
  trait stack an engine reads. (The Trophy Cord, the Sabertooth's drop, is the one deliberate exception:
  it scales over a whole trip.)
- **Each engine pays off in what its class is about.** Damage is one payoff among several; a payoff
  that only adds raw damage needs a reason. (The author denied "every payoff is damage" in round 1.)
- **Rework before adding.** Duplicates and stat-only items were reworked; an item with an identity of
  its own was kept and the piece made new ("keep both", eight times in round 2).
- **One engine per root shelf; leaves compound, twist, or own one.**
- **No charges or repeat penalties.** Option A of the first proposal was rejected outright.

## The nine engines

| Engine | Shelf | Build-up | Multiplier | Payoff | Grid piece |
|---|---|---|---|---|---|
| Bloodletting | rogue | Bleed **stacks** (`status_bleed`'s `count`, apart from its per-tile bite) | Widen the Wound doubles them | Exsanguinate: 3 raw a stack | Serrated Whetstone: blades beside it add a stack per hit |
| Tempo | fighter | quick actions (speed 2 or less) since you last walked, the `tempo` pool | Afterimage Cloak: every quick action raises barrier | Cascade: one blow per Tempo, up to 6 | Whetted Edge: quick weapons beside it hit harder |
| Blood Price | barbarian | health lost on your own turn (`selfWound`), the `blood` pool | Sanguine Font: +3 to the next ability per point | Red Tithe (stamina), Scab (heal on a kill), Butcher's Tally (own kills) | Wound Gift: abilities beside it are paid in health when stamina is short |
| Reaper | hunter | kills | — | Reaper's Ledger: refund + 2 free steps; Carrion Mark: next action 2 sooner | Reaper's Ledger: kills by a weapon beside it |
| Storm Vessel | mage | a Storm a turn, the `storm` pool | Deep Vessel: holds 5 beside a Storm Vessel; Static Focus: +1 magic damage per Storm spent | the spell beside the vessel: +50% per Storm; Outpour: 4 mana per Storm | Storm Vessel itself |
| Overflow | priest | healing past full, banked by the **healer** as `radiance` | Brimming Chalice: overheal becomes barrier | Reliquary of Tallies: a heal; and one item per leaf (below) | Censer Chain: heals beside it splash for half |
| Rampart | knight | an **amount** of barrier (the Crown's pooled barrier, made general) | Bastion Plate: it no longer wears off; Entrench doubles it | Shield Slam: raw damage equal to it | Rampart Buckle: each shield beside it raises 3 when you are hit |
| Reactions | alchemist | Oiled, Chilled, Wet, laid by one body | Reagent Vest: statuses from items beside it last a turn longer | fire on Oiled explodes; a hammer or axe on Chilled shatters armour to 0; Arc Rod jumps to Wet | Reagent Vest |
| Grid jokers | spread | where things sit | Mirror Shard copies, Keystone raises, Relay Sigil chains | Hollow Idol: +2 per empty cell | all four |

Tempo is one pool with the Duelist's (the author's call, round 2): Coup Droit spends what a fighter
banks, and a Duelist's quick actions bank as well as its repeat strikes.

## Leaves

| Leaf | How | Piece |
|---|---|---|
| Duelist | compounds Tempo | shares the pool |
| Skirmisher | twists Tempo: walking keeps it | Harrying Strike carries `trait_tempo_on_the_move` |
| Barbarian | owns Blood Price | the barbarian shelf |
| Poacher | joins Bloodletting to Reaper | Hemophage Charm: a fallen foe's Bleed jumps to its nearest ally |
| Battlemage | compounds Storm | an enchanted (`magical`) blade beside the Storm Vessel spends it too |
| Sentinel | compounds Rampart | Warden's Oath: a blow taken for an ally banks as barrier |
| Paladin | twists Rampart; Overflow payoff | Aegis of Plenty: Radiance as barrier for allies beside you, and your barrier covers them |
| Crusader | Overflow payoff | Judgement: Radiance as raw holy damage |
| Monk | Overflow payoff; grid joker | Overflowing Cup (overheal banks chi); Hollow Idol |
| Theurge | Overflow payoff | Votive Flame: Radiance becomes wind-up held |
| Apothecary | compounds Overflow | an elixir that heals past full banks Radiance like any heal (the healer is whoever poured it) |
| Bombardier | compounds Reactions | Reactive Salts: bombs leave Rime, Shallows or an Oil Slick |
| Ninja | grid joker | Mirror Shard |
| Elementalist | grid joker | Relay Sigil |
| Warlord | grid joker | Keystone (centre slot only) |
| Artificer | — | a machine version of the Storm Vessel, later (round 3 note) |

**The audit of the leaves that already ran an engine** (approved in round 2) found the Monk (chi) and
the Mammonite (gold) complete, and three gaps, each closed by extending an item already on the shelf:

| Leaf | Gap | Closed by |
|---|---|---|
| Necromancer | no multiplier: nothing made a corpse worth more | Charnel Reliquary: each corpse a Corpse Burst consumes adds 3 more |
| Summoner | a weak payoff: a summon cashed in only for mana and health | Offering Bone: the consumed summon's health also hits every foe beside it |
| Theurge | Invocation ignored the hold | Invocation: 2 more per tick held, so a Votive Flame lands as fire |

Two notes the audit left for later: the Monk has no piece that makes a point of chi worth more (only
more hits), and most of the Mammonite's multipliers reward holding gold against payoffs that spend it.

## Where the engines touch combat

`models/engine.lua` owns every rule; `models/combat.lua` carries one call per seam and nothing about
what an engine is.

- **castAmount** reads the Storm multiplier and the Keystone's forge step on all three cast paths, so
  the forecast quotes what the cast lands.
- **resolveCast** calls `Engine.afterCast` (Tempo's `quickAction` tally, the Storm spend, Quickened
  spent) and runs the Relay Sigil's far end through itself with the turn left unbilled.
- **dealFlatDamage** calls `Engine.afterWound` (self-wounds, Oiled, Chilled) and, at a felling blow,
  `Engine.onFell` while the body still wears its wounds (Hemophage, Carrion Mark, the killer's
  `onKill` traits).
- **applyHeal** credits overflow to `opts.healer` (`Engine.overheal`); the cast's `fx.heal` names the
  healer.
- **abilityCosts / spendCost**: the Wound Gift's blood price, and any health price paid on your turn
  is a self-wound.
- **walkOut** forfeits pools declaring `resetOn = "moved"`.
- **Trait.attach** copies the traits to a Mirror Shard's right.
- The pooled barrier (`models/crown_demons.lua`) reads a sharing Paladin beside the struck body in
  both its forecast and its soak.

An ability effect reaches a mutation only through `fx.engine` (`Engine.live` on the real cast,
`Engine.inert` on a dry run) and reads through `models/engine.lua` directly.

## What enemies ask for

The bestiary pass is measured, not authored, in `tests/engines_spec.lua`'s last case: every engine
has foes on the shipped roster that it answers. Armour walls ask for Bloodletting, Exsanguinate and
Shield Slam (raw) or a Rime Draught; packs ask for Tempo and the Reaper; long fights and stair bosses
ask for the Storm Vessel and Blood Price; fights on wet or flammable ground ask for Reactions.
