# The Overworld

The board a quest is run on: a carved maze with an objective at the far end, stops scattered through
it, and one rule about how you get home. [docs/progression.md](progression.md) owns the campaign's
economy — what a run pays and what a level buys. This owns the run itself.

Every number below is reproducible with `& "E:\LOVE\lovec.exe" . board-report [n] [tiers]`, which rolls
`n` boards with the campaign's default map params and reports what the generator actually laid down.
The rule from [docs/roadmap.md](roadmap.md) applies with force here: **do not hand-derive a count from
the constants, roll the boards and read what they say.** This document exists partly because that was
not done once, and the wrong number was carried for a whole pass.

## The generation pipeline

`Overworld.generate` (`models/overworld.lua`), in order:

| Pass | What it does |
|---|---|
| `carveMaze` | recursive backtracker over a spaced node lattice → 1-tile corridors |
| `braid` | re-connects some dead ends into loops. **See the braid rate below** |
| `placeRivers` → `thinBridges` | wandering water; a river over a path becomes a one-tile bridge |
| `placeObjectiveAndGates` | objective on a far dead end (~80% of max distance), gates + keys before it |
| `placeCaches` | material caches take the spur ends **first** |
| `placeEncounters` | fights and texture fill the corridors between them |
| `guardBoons` | re-seats fights so most rewards stand behind one |
| `pruneDeadStubs` | trims spurs that ended in nothing (no RNG) |
| `assignEncounterTiers` | the pips the fog shows, drawn last so geometry never shifts |

`deriveDims` sizes the grid to the content, so a short errand does not sprawl. An authored board
(`Overworld.fromLayout`, `data/overworld/*.lua`) skips the lot.

## The board's contract

- **The objective is the only fight you must take.** `placeEncounters` keeps combat off the
  objective→start spine, so a wounded company can always route to the boss.
- **Every other fight is optional, and an optional fight should be attached to something worth
  having.** That is `guardBoons`: the boon at the end of the spur, the fight in the corridor to it.
- **The finds are guarded, never the services.** A shop behind a fight is friction; a rest behind one
  compounds exactly the wrong way.
- **Ascent maps opt out of both.** There combat *is* the route.

## What a run costs

The board's whole risk structure rests on a fight costing something that outlives it. For a long time
it did not, and that is worth stating plainly because every other rule here was built on top of the
gap:

> A camp restored **everything**, one was guaranteed every six stops, nothing priced time, and the only
> durable cost of a fight was a body actually going down. So any fight the company could win was free,
> and "should I take this detour" had one answer.

Two things fix it, and they are deliberately different in kind.

**`Player.CAMP_SHARE = 0.5`** — a camp gives back half of what is *missing*, never the whole of it
(`Player.camp`). A share rather than a flat amount, for two reasons: it scales with the company without
reading a level, and it **compounds** — halving a gap twice leaves a quarter — so a long board grinds
the company down even though every camp is generous. The hub still heals whole; going home is what
makes a company whole.

**Wounds** (`models/wound.lua`) cap the hub's refill, and cap the camp too. A camp can never top
someone past what the hub would give them.

The prior swing is worth recording: the rest guarantee originally **no-opped entirely** (it read a
random-draw weight as a density floor), so attrition was one-way and no board offered a refund. Fixing
that was right. It landed on a full refund at a guaranteed density, which is the other end.

## Getting out

**Walking out is free.** The company goes home with everything it picked up, and the only thing the day
cost is the day. **Losing a fight is the whole of the risk**: a wipe takes `Player.WIPE_LOSS` — three
quarters — of the run's gold and forging stock, and leaves the items, the wounds, and everything carried
in (`Player.loseHaul`, pinned by `tests/extraction_spec.lua`).

**This rule inverted, and the old one is worth recording.** It used to be that *the objective was the
only extract*: a wipe and a walk-out were the same event and both restored the company from an entry
snapshot, so a lost run was worth exactly nothing. That was correct while the board was a one-way trip —
without it, forfeiting the moment a run had paid out was the optimal way to bank a haul.

It stopped being correct when the day became the unit. With a voluntary exit keeping everything, a total
wipe penalty turns the last fight before you turn back into an all-or-nothing coin flip, and the
sensible play is to leave after the first cache and never risk a second. A **majority** loss keeps the
bet live in both directions: one more spur risks most of what you are carrying rather than all of it, so
a bad roll is a bad day rather than a wasted one.

Three things a wipe deliberately does not touch:

- **The items.** A sword out of a chest is carried by a body, and the bodies came home. It is also what
  keeps a wipe from undoing the one reward the player can see and name.
- **The wounds.** An injury outliving the run that caused it is the whole mechanic (`models/wound.lua`).
- **What was brought in, and anything spent.** Only *gains* are at risk, so a company that spent more at
  the Merchant than it found walks home with its purse intact rather than being billed the difference.

The entry snapshot survives, because it is still how the loss is *measured* — whatever is held now minus
whatever was held then is what this run found. It is no longer what the company is restored to.

A **descent** still asks before you leave, and still means it: there is no city on the other side of one,
so climbing out early gives up the company as well as the haul.

### Overworld items

A small, deliberately open category: items whose whole effect is on the board. One shape so far
(`models/player.lua`, Overworld items):

| Shape | Field | Item | What it does |
|---|---|---|---|
| **Passive** | `visionRadius` | `utility_torch` | widens the fog while carried, spent by nothing |

Read off the roster's grids **and** the stash, because a board item belongs to the company rather than
to a body.

A **spent** shape lived here briefly: `extract`, on a Smoke Bolt, bought a walk-out that kept the haul
back when every exit but the objective voided it. Walking out is free now, so the charge had nothing
left to buy and went with the rule that justified it. A future spent item wants its own field and its
own reason.

## The arc

A board should get harder as it runs. It did not, and the reason is worth keeping because it is easy to
re-commit: **`assignEncounterTiers` runs after every placement pass and only stamps a number on what is
already there.** An elite was as likely on the doorstep as at the gate; the "difficulty ramp" was a
label on a flat board. Measured mean tier by fifth ran `2.66 / 2.62 / 2.50 / 2.70 / 2.85` — noise.

It was worse than a placement problem. `encounter_elite`'s weight was `ctx.prestige`, unbounded, against
the fixed 2–3 the ordinary road fights carried. Past prestige ~6 the elite *was* the ordinary fight —
measured at **76% of every board's combats** — so there was nothing left for it to be tougher than.

Three changes, at three levels:

1. **The weights saturate.** `encounter_elite` caps at 3, `encounter_forsworn` at 2. Growing more
   common with renown is right; growing without bound is not a rate, it is a replacement.
2. **Placement carries the arc.** `ELITE_MIN_DEPTH = 0.5` — an elite rolled onto the near half is
   re-seated as an ordinary fight. `ELITE_SHARE = 0.25` caps the rank as a fraction of stops, so no
   pool weight can make elites the ordinary case however a blueprint is authored. Both are expressed
   as *demotions*, so the encounter count and the quest's authored pool are untouched — the same move
   the spine and combat-share rules already make. `guardBoons` respects the depth rule when it moves a
   fight, or it would quietly undo the arc it was just given.
3. **The tier ramp is a gradient.** Depth in thirds gives all three pips to position, and rank is +1 on
   top. The random spike dropped 0.25 → 0.12, because at a quarter it was as strong as the depth term
   it was decorating.

Measured after: `1.17 / 1.55 / 2.19 / 2.69 / 3.00`.

## The braid rate, and how the guarded-boon knob was misdiagnosed

`Overworld.BRAID = 0.20`. This is the most load-bearing constant on the board and the least obvious.

`guardBoons` targets `GUARDED_BOON_SHARE = 0.8`. It was achieving **30%**, and the shortfall was
recorded for a whole pass as a shortage of *fights* — "what limits guarding is the SUPPLY OF FIGHTS".
That was wrong, and only measuring caught it. At the old braid rate of 0.55:

| | |
|---|---|
| dead ends per board | **2.0** — against 4.5 caches asking for one |
| boons with a real cut vertex beside them | **32.7%** |
| boons actually guarded | 29.7% — i.e. **92% of what the geometry permitted** |
| loose fights standing around unused | **3.1 per board** |

The pairing pass was working almost perfectly. The board had nowhere to put a guard. **Braiding
destroys exactly the geometry the offer rule needs**: a dead end is what a boon sits on and a cut vertex
is what a guard stands on, and every braid removes one.

The slog that braiding exists to prevent is handled better by `pruneDeadStubs`, which removes only the
spurs with *nothing at the end* — the actual complaint. Lowering the rate also makes the board slightly
*tighter*, since a braid carves wall into path and `deriveDims` fixes the footprint either way.

| At `. board-report 300` | braid 0.55 | braid 0.20 |
|---|---|---|
| dead ends | 2.0 | **3.9** |
| boons gateable | 32.7% | **72.6%** |
| boons guarded | 29.7% | **56.8%** |
| cache craft stock | 12.5 | **13.9** |

Material income goes **up**, because a guarded cache pays a bonus and far more of them are now guarded.

**The ratio was the wrong lever.** Cutting `cacheTarget` to force boons-per-fight toward 1.0 was tried
and rejected by measurement: it dropped material income by a third *and* lowered the absolute number of
guarded boons, because it removed boons rather than adding pairings. `boons per fight` is reported as
context only. `boons gateable` is the real ceiling.

Do not raise the braid rate without re-running the report.

## The city as the board's other half

Two things landed here that are about the run without being on the board.

**The Descent is the post-game.** It is a standalone mode — musters its own company, banks nothing,
levels on its own per-character XP — which is why the city was rightly the wrong door for it. But it
sat in the debug column, so a finished campaign had nowhere to land. It now appears on the main menu
once `Player.hasFinishedCampaign` is true, banked at the `endsCampaign` seam rather than at New Game+
(a player who watches the credits and returns to the menu has still beaten the game). It survives New
Game+: what the player has done cannot un-happen.

**A house may have a verb of its own.** Every door in the city did Buy and Sell and nothing else, which
is why the town stops changing once the last building opens — a new shop is only ever more rows. A
vendor may now declare a `service`, rendered as a third tab (`models/vendor.lua`, Services).

The Undercroft declares the first: the **Fence**. Hand over a piece, name what you want back of about
the same worth, pay a fee. Greed's verb exactly — nothing is made, nothing is destroyed, and the house
takes its cut. It is also the service an extraction game most needs, since a run that pays out in gear
produces duplicates by construction.

- It is a **choice, not a roll** — the player picks from the offers. A random return would make it a
  slot machine, and the board is already the slot machine.
- `SWAP_FEE = 0.6`, deliberately above the 50% a sell-back pays: a swap returns an *item* at the grade
  given up, with no second trip and no waiting on a gate. Under 50% the Sell tab would be decorative at
  the one house that has both.
- `SWAP_BAND = 0.35` — a band, not an exact match, because prices are derived from grade
  ([docs/shelf.md](shelf.md)) and land on arbitrary numbers.
- A service does **not** touch `item.level` and bills no materials. It is not a second Forge; see
  `models/vendor.lua`'s header for why that door stays closed.

**The other six houses have no service yet, and that is an authoring job rather than an engine one.**
The seam is a data field. Sketches only, deliberately unbuilt: the Crucible appraising a sealed find,
the Arcanum reading an unknown discipline off a piece, the Cafe standing a round.

## Known debt

- **Boons still outnumber fights ~1.4:1**, so even at 73% gateable the guard pass tops out around 57%.
  Closing the rest means more fights per board, which is a difficulty decision rather than a
  generation one.
- **No adjacency rule between stops of the same kind.** The only spacing is Manhattan ≥ 2 between any
  two encounters, so two crossroads in a row or a merchant beside a rest are both legal.
- **Nothing prices time on the board.** Once the fights are cleared there is no cost to sweeping every
  spur. PMD answers this with a hunger clock; that is the wrong shape for a 45-minute tactics run, and
  escalating reinforcement pressure is the version that would fit. Unbuilt, and not obviously needed
  now that attrition compounds.
- **Every offer on the board pays the same currency.** Materials from a cache, materials and gold from
  a fight — so the board is N copies of one offer at different prices, and route *choice* cannot really
  exist until two boons can differ in kind. The largest open item here, and it is a content question
  rather than a generator one.
- **No biome has a tileset drawn yet** — all seven fall back to coloured rects. See
  [docs/art-assets.md](art-assets.md).
