# Progression

The goal, stated once: **the player must feel themselves getting stronger.** The hub city is meant to
carry that feeling the way a job system does — run a house's quests, earn on the way, come back and
buy what just opened — with a Hades-shaped loop around it: accrue during the run, spend when you
return.

This document is the strategy for getting there and the ledger of what is actually true today. The
interactive version, with per-item keep/cut decisions, is the
[progression plan artifact](https://claude.ai/code/artifact/8208bddd-4367-4473-9a6c-5eb5d5a04769).

## What is deliberately NOT the problem

**Stat growth is flat on purpose, and the reasoning is right.** `models/growth.lua` proves that linear
growth against subtractive mitigation converges to a constant no matter how it is tuned, and that a
hard enemy-level ceiling diverges catastrophically (a knight needing 302 hits). `ENEMY_LEVEL_LAG = 0.9`
is a considered answer, not a wobble. Do not go looking for a knob here.

The consequence is the whole of this document: growth's own header names the real carriers — *"growth
within a run comes from gear, abilities, disciplines and roster"* — and all four of those were starved,
hidden, or half-wired. The one axis that was never meant to carry the feeling was the only one the
player could see. **All seven steps below have since landed.** The last of them asked how long the
campaign should be and answered that the length was never the problem — what came out of it instead is
the rule that a single sin's line can be run to its end alone, priced in difficulty rather than in
permission. The diagnosis table marks what is closed, and "Known debt" at the end is what the closed
steps left behind.

## The diagnosis

| Axis | State | What is true |
|---|---|---|
| Level & stats | By design | Flat, correctly, for the reason above |
| Emergent class | **Done** | `Growth.creditClass` grows a character into whatever gear it casts. In-fight it reads through the growth floaters over the bodies ("+1 Knight" per action); the standing read-out that once sat under the actions grid was removed as clutter |
| Gear & forge | **Done** | One bench, The Forge, reachable from the city; one bill, one ladder. Was two doors onto one ladder, one of which no building opened. Discipline stock is billed in technique and carries no ceiling at all |
| Shelf waves | **Done** | Stock keys on the vendor's own quest count (always correct), now at per-quest granularity: 474 items across 13 gates instead of clumps of 33 / 123 / 208 / 105 |
| Disciplines | **Done** | 37 of them, forming a COMPLETE lattice — 21 crossings = C(7,2), every pair of houses. A discipline is a currency (`char.technique`) banked per action and spent to forge its own gear, and the shelf reads as the tree: each section a path, with its shape, standing and what it still needs |
| Roster | **Done** | The whole roster travels, 4 stand on the board (`Player.MAX_FIELD`), and `Combat.rotate` swaps the bench in mid-fight |
| Outgrown fights | **Done** | `models/muster.lua` rates both sides by effective stats with gear folded in; a marker's pips count the steps a fight stands above the company, and at 200%+ it goes calm and offers to be walked off (step 8) |

### The payout cadence is the root cause

Quests pay ~1.5 prestige against 3 per level, so **half of all quests level nobody** —
`ui/panels/advancement.lua` says so in its own header. Against the references:

| Game | Pays out | Per battle |
|---|---|---|
| FF Tactics | JP, per individual action | ~30 |
| Fire Emblem | XP per unit, per hit | 5–15 |
| Triangle Strategy | Weapon upgrades, small and discrete | 1–2 |
| **LoveTactics** | Gold and 1.5 prestige, at the hub, after ~45 minutes | **1** |

Every reward in this game happens after the fighting, once. That is the thing to change.

### The hub reaches about half its goal

What works: shelf stock unlocks on that vendor's completed-quest count, and locked stock is *shown*
with a "complete N more of this house's quests" hint (`ui/panels/shop.lua`). Locked buildings tease the
same way, drawn greyed as `"? (prestige N)"` (`ui/building_map.lua`). The instinct is right and it is
implemented properly.

What does not: **the entire city unlocks by prestige 4** — across the thirteen buildings, eight open at
1 (the Forge and the Draft Yard joined them after this was written), two at 2, two at 3 and one at 4,
reached about three quests in. For the remaining ~89 quests the town never changes again. And seven independent four-rung shelves climbed in parallel mean the player is never far
up anything; FFT's job tree is *one* tree, which is why unlocking anything in it feels like the
character sheet opening.

## Decisions taken

1. **One bench: The Forge.** *(Reversed. An earlier draft folded the smith INTO the vendors — each
   house forging what it sells. The reversal is deliberate: two doors onto one `item.level` meant two
   bills, two ceilings, and no single place to look, and spreading that across seven shops makes it
   seven of each.* `models/forge.lua` *is now the only thing that raises a level and the only thing
   that spends materials; a vendor sells and buys back, nothing else. The panel and model the old
   blacksmith already had were complete — they had simply never had a door in the city.)*
2. **Items unlock on that vendor's quest count, finely.** The keying was always correct; the
   granularity was not. The `{ 0, 3, 6, 10 }` enum is retired for per-quest values, so every quest
   hands its house something new.
3. **Buildings open early; disciplines and items carry the gating.** Flatten `unlockPrestige`.
   Note the cost: line *availability* has to take over the staggering job, or the player meets seven
   lines on quest one. **Deferred** — see step 4, which also corrects what is doing the staggering
   today.
4. **Materials encode where you went, and which house you ran.** Not a depth tax. Two families, two
   different jobs — see below. The old `Material.TIER_BY_LEVEL`, which graded by forge depth, is
   retired rather than repaired.

### Why materials at all

A second currency earns its place only when it tags a source the player can route toward. The
references are unanimous on this and split on whether to have one at all:

- **FFT and classic Fire Emblem tax nothing** — gear is bought outright, and FFT's second currency
  (JP) buys *abilities inside a job*, a different sink entirely rather than a tax on the same one.
  FFT's source-tagging lives in Poach and Move-Find Item: what you chose to fight, and where you chose
  to stand, determine what the shop will sell you.
- **Hades, Three Houses and Triangle Strategy tag by source** — and Hades is strictest: one sink per
  currency, one source per currency, and **the source is telegraphed before you commit**, so you route
  your run by what you are saving for.

What no reference does is gate upgrades behind a material tiered by upgrade depth — which is exactly
what `Material.TIER_BY_LEVEL` did. Mythril meant "you are deep in the ladder", which the ladder
already said. That mapping is gone. What replaced it is two families, because a material has exactly
two jobs and one table could not do both (`models/material.lua`):

| Family | What it is | What decides it |
|---|---|---|
| **Craft stock** | iron scrap / steel ingot / mythril — the volume | the **item's own quality** (its price), so a mythril blade wants mythril from its very first rung and a rusted knife never wants any |
| **House stock** | one per class/sin — the gate | the **item's class**; and where it drops is the **sponsoring house of the quest you ran**, so running the Bastion's line stocks the bench that the Arcanum's gear will empty |

### The bill, and what caps it

`Forge.upgradeCost` bills three tracks for a rung: a **currency**, craft stock by quality, and house
stock by class — **and for a discipline item, every parent house's stock at double the plain rate**.
That is the discipline gate expressed as a bill rather than a lock: a multiclass piece cannot be forged
deep unless you ran both lines it descends from. It falls out of `Discipline.parents`, so not one of the
205 discipline-tagged item files gained a field.

The currency track has two forms, and never both at once:

| Item | Pays | Ceiling |
|---|---|---|
| carries a `discipline` | **technique** in that discipline, `10 × target` | none — the price is the brake |
| carries a `class` | **technique** in that class, `10 × target` | the standing of the house that sells it (`Quest.sponsorProgress` → `Vendor.tier`) |
| classless | gold, `40 × target` | none; the materials are the only brake |

The discipline row used to read *gold*, capped at `Discipline.level + 2`. Both halves of that are gone,
for one reason: a quest spent playing a ninja bought the right to pay **the same gold a knight pays for
a knight thing**, and it bought it invisibly, at a bench, two quests later. That is a permission slip,
and permission slips are not felt. Billing the play itself closes the loop where the player can watch
it: fight as a ninja, bank ninja technique, forge the ninja kit. Keeping the ceiling *as well* would
charge twice for one rung, so it went with the gold.

**That argument was never actually about disciplines**, so it now covers the whole shelf. Fight as a
knight, forge the knight kit. What falls out is a clean division of labour where there had been an
arbitrary one: **gold buys breadth** (a vendor hands you a thing you did not have), **technique buys
depth** (a bench makes a thing you already carry better). Gold keeps its sinks — the shelves, the
overworld caches, the purse abilities — and stops being the answer to two different questions. The
class ceiling *survives* the move, and is not the double-charge the discipline ceiling was: that one
measured play, which is exactly what the price now measures, while this one measures campaign standing.
Two axes, one gate each.

Why a second currency at all, when gold already exists: **gold is fungible.** Four hundred coin off a
wolf pack and four hundred off a discipline elite are the same four hundred, so every choice the player
made earning them flattens into one pool. Technique is earmarked — ninja technique comes only from
ninja play and forges only ninja gear — so committing a run to something accumulates into *that thing*
rather than into a number. That earmarking is the entire justification; a currency that did not
earmark would just be a discount.

It is **per character** (`char.technique`), banked by `Character.recordTechnique` from
`Combat.useItem`, and a bill draws the whole cost off the single strongest holder
(`Discipline.techniqueHolder`). Per-character rather than pooled because a shared pot would make
putting one cheap discipline item on all four bodies accrue four times as fast — spreading would
strictly dominate committing, the exact inversion the old max-across-roster read existed to prevent.
Billed to the strongest rather than to the carrier because gear circulates here (a stash, a loadout
panel, and selling a unit returns its gear), and carrier-pays would strand a fresh recruit with
un-forgeable loot.

Two grind doors, both shut: `Discipline.TECHNIQUE_PER_BATTLE` caps what one fight can bank in one
house (a `free` ability does not end the turn, and nothing obliges a player to finish a fight), and
losing on purpose to farm a bank is undone by "Try Again" restoring the pre-fight snapshot — which
works only because the ledger rides in the *character* snapshot, pinned by a spec that says so.

### One ledger, three readings

Technique used to sit beside two other per-character tallies — `classUse` (the career title) and
`classUseSinceLevel` (what the next level-up applied) — on the stated ground that *"a vote and a bank
cannot share a counter"*, since spending the bank would destroy the vote. They also shared a **key
space**: `Discipline.growthClasses` files a discipline item under the discipline, so a character
playing assassin gear carried `classUse.assassin` **and** `technique.assassin` — two unrelated numbers
under one word, stacked as two near-identical lists on the character sheet.

The objection was only ever about spending, and the fix is the one FFT's JP already uses: keep what was
**earned** monotonic, and track what was **spent** beside it.

| field | what it is |
|---|---|
| `char.technique[key]` | earned, never decremented. The numerator of everything below |
| `char.techniqueSpent[key]` | what the Forge has billed. Available to spend is the difference |
| `char.techniqueAtLevel[key]` | a checkpoint taken when the last level landed, so the level-up reads the delta since |

Consequences worth knowing. **The per-battle cap now bounds the level-up reading too**, since they are
one number — thirty actions of one house in a single fight is far past the point commitment has been
demonstrated, and the anti-grind rule is stated in one place instead of two. **The class-vote floater is
gone**: it existed only to cover the silence technique left when it spoke for discipline stock alone
(233 of 638 item files, all of it locked content), so an opening hand of plain gear banked and floated
nothing. One currency, one award per action, one floater.

`Discipline.level` still gates the shelf's optional per-item `unlockLevel` (`Vendor.stock`), and now
**floors** a `growthBy` booked in shares (below). No data file authors an `unlockLevel` yet, so that
tightening is latent rather than live.

### A level credits everything you cast

`Growth.resolve` used to take the argmax of the since-level reading, apply that one class's table, and
**discard the rest** — casting knight 11 and mage 10 threw away all ten mage casts. 51% of the play
decided 100% of the level, so there was no gradient anywhere: every cast was worthless except the one
that crossed the threshold. It is also why the numbers meant nothing. Only `count > bestCount` was ever
read, so `Knight 14` meant "more than 11" and not one thing besides.

A level is now apportioned across everything cast since the last one (`Growth.shares`), with per-stat
remainders carried in `char.growthCarry` so the stats stay whole numbers and nothing is thrown away.
Two levels at 50/50 land exactly where one level of each would.

Three properties hold it up, each pinned by a spec:

- **The survivability floor comes along for free.** Survivability is *linear* in a growth table, so a
  convex combination of tables that each clear `Growth.meetsSurvivabilityFloor` clears it too. Blending
  cannot reopen the hole that rule exists to close.
- **Determinism.** Float addition is not associative, so shares and gains are summed over **sorted
  keys**. `models/build.lua` promises `(id, ledger, level)` rebuilds the identical character on any
  machine and `state_hash` compares peers mid-duel; an unsorted sum is the same character with different
  stats on another machine — exactly the failure `leaderOf`'s tie-break already guards against.
- **Stats only ever rise.** Unchanged, and still why history is never re-apportioned: doing so would let
  a character that changed direction *lose* max health on a level-up.

`growthBy` is booked in shares to match, so the ledger of levels agrees with the stats it summarizes.

The one thing a blend cannot be is a **title**, because a title is singular — "Growing as Knight and a
bit of Mage" is not a title. That tension was first settled by keeping the sheet's title winner-take-all
over the *career* ledger (`Growth.dominantClass`), and that turned out to be the wrong half to keep: see
"The sheet says one thing" below.

## The plan, in dependency order

### 1 — One upgrade bench: The Forge — **done**

`data/buildings/forge.lua` opens `ui/panels/forge.lua` from the city's bottom row, at prestige 1.
`models/forge.lua` is the single bench: gear and abilities per instance, consumables per recipe, three
categories on one segment strip (the same widget the shop uses for Buy/Sell, down to the Tab and LB/RB
bindings). It charges 40× gold a rung — the smith's rate; the vendor's 60× went with the door.

`models/vendor.lua` lost its whole upgrade block. What the Forge borrows back is `Vendor.tier`:
standing with a house is the ceiling on how far its gear forges.

### 2 — Materials as a reason to leave the path — **done**

- **Caches placed like keys.** `Overworld:placeCaches` is `placeKeys`'s pattern with a different
  payload — candidate filter, shuffled placement, silent partial fallback on a cramped board.
- **On the dead ends the objective did not take.** It runs *after* `placeEncounters`, so it pays out
  the spurs nothing else claimed, and *before* `pruneDeadStubs`, which now treats a cache as reason
  enough to keep a corridor alive.
- **Tagged on two axes.** *Which* stock is the quest's sponsoring house. *How much* — and which craft
  grade — scales with `Overworld:spineDistances`, a multi-source BFS off the critical path.
  Deliberately **relative to the deepest detour that board offers**: absolute tile counts do not
  survive a braided maze, where one twenty-tile spur off a short spine turns a single tile into a
  campaign's worth of ore. Both counts are capped (craft 1–4, house 1–3) — the far cache is *better*,
  never a windfall.
- **Banked at the objective, not on pickup.** The haul rides on the map widget (`cacheHaul`) and merges
  into `Quest.complete`'s existing `rewardMaterials` path, so it inherits the double-payout guard and
  the advancement panel names it with the rest of the spoils. Abandoning a run forfeits its haul, which
  is what stops a cache being farmed by restarting the quest.
- `deriveDims` counts caches in its content sum, or maps would get denser rather than larger.

### 2a — The run is an extraction — **done**

The cache rule above was right and too narrow. Materials were held to the objective so a cache could not
be farmed by restarting a quest, but everything *else* a run picked up — chest loot, a fight's spoils and
salvage, gold — was granted and saved on pickup. A failed quest dropped `activeRun` and nothing else, so
the company walked home with the lot. That made forfeiting before the objective the optimal play, and it
made every risk judgment on the board decorative: the correct answer to *should I take this fight* was
always yes, because losing cost nothing but time.

**What you carry is only yours if you get out with it.** One rule, applied to the whole haul:

- **The objective is the only extract.** Clearing it drops the run — and with it the rollback point —
  so the finds become permanent alongside `Quest.complete`'s gold, prestige and reward items.
- **Every other exit voids the run.** A wipe and a walk-out are the same event; they differ only in how
  the player got there. `states/game.lua`'s `rollbackRun` restores the company from an entry snapshot
  taken once at run start (`Save.snapshot`, parked on `activeRun.entry` and serialized with it).
- **Finds stay live the whole run.** Nothing is deferred into a holding pen: a chest's sword lands in the
  stash and equips at the Loadout immediately. What the rollback changes is not where loot goes, only
  whether it survives the way out. This is why the fix is a snapshot rather than a ledger — no grant seam
  had to learn a new rule, including ones added later.
- **Gold *spent* comes back too.** Otherwise a forfeit launders run gold into permanent hub goods.
- **The company's own kit is never at stake.** The snapshot *is* the state walked in with, so restoring
  it can only take back what the run added. A lost expedition costs what it found, never what it brought.
- **The stake is on screen.** A "Carried this run" readout is computed by diffing the live company
  against the entry snapshot (`game:refreshHaul`), and both the turn-back prompt and the defeat panel
  name the loss in the same words (`game:haulPhrase`). A stake nobody can see is not a bet.

Pinned by `tests/extraction_spec.lua`.

### 2b — A fight in front of the reward — **done**

Placement used to make a fight and a reward **alternatives**: `placeCaches` ran after `placeEncounters`
specifically to pay out the dead ends the encounters had not claimed. They are a **pair** now — the boon
at the end of the spur, the fight in the corridor to it — so a detour is one priced offer instead of two
unrelated tiles. `Overworld:guardBoons` runs after both and re-seats fights that are already placed, so
the encounter count the map was sized around never moves.

- **The gate is checked, not assumed.** A guard is only seated where removing its tile actually
  disconnects the boon from the start. The tempting shortcut — take the neighbour nearest the spine —
  silently assumes every boon ends a degree-1 spur, and produces guards the player walks around on a
  braided board.
- **Seeing the guard reveals what it is for.** Handled in `Overworld:reveal`, so every fog source gets
  it. A reward you cannot see behind a fight is not an offer.
- **The finds are guarded, never the services.** A shop behind a fight is friction, and rest is the
  pressure valve the extraction rule above makes necessary.
- **Guards live off the spine**, so this and the combat-free-spine rule reinforce each other. What falls
  out is the board's contract: **the objective is the only fight you must take; every other fight is
  optional, and an optional fight should be attached to something worth having.**

> **Open knob.** How *many* boons end up guarded is set by the content mix, not by this pass. A board
> carries roughly two and a half boons per fight (`cacheTarget` is half the encounter count, and the
> pool's finds take a further share of what survives `combatShare`), so even perfect deployment leaves
> most boons loose. `tests/guarded_boon_spec.lua` pins what the pass owns — that nearly every available
> fight is spent guarding something — and deliberately does not pin the boon-side share. Moving it means
> moving `cacheTarget` and `combatShare`, which changes both what a run is worth and what it costs.

#### …and a floor under every fight

The cache answers *why leave the path*. It does not answer *why the fight on the path was worth having*,
and until `Spoils.materials` there were fights that answered it with nothing: gold is a number on a
panel, and the loot roll's first drop lands a little over half the time, so close to half of all common
fights paid out nothing the player could carry home. A fight costs HP, consumables and a real chance of
losing the run. **Every won fight now leaves forging stock behind** — including the objective, which
takes this half through the run's haul while its gold, items and levels still flow through
`Quest.complete`.

It is **computed, never rolled**: no RNG, no zero case, and deliberately no per-encounter override, so
nothing can author the floor away. Two knobs, both at the top of `models/spoils.lua`:

| | Craft stock | House stock |
|---|---|---|
| common fight | 1 | — |
| elite / objective | 2 | 1 |

*Which* craft grade is the encounter's **difficulty tier** — the tell the fog already shows before you
commit — bumped a grade for an elite or an objective. What you beat decides what it leaves; forge depth
still decides nothing, per `Material.TIER_BY_LEVEL` above. *Which* house is the run's sponsor, the same
value the caches are laid out with, so a run's fights and its dead ends pay into one house.

The floor stays **under** the cache on purpose (1–4 craft and 1–3 house at the deepest detour). Leaving
the path has to remain the thing that stocks the Forge; this is a floor, not a rival, and
`tests/spoils_spec.lua` pins that ordering so a later tuning pass cannot quietly invert it. Loot and
salvage share one card grid on the victory panel, items first — one answer to one question.

### 3 — A shelf that moves every quest — **done**

- `tools/unlock_rescale.lua` (`. unlock-rescale [apply]`) rewrote 339 gates. 474 priced items now
  spread over 13 gate values (37–48 each) instead of clumping at 33 / 123 / 208 / 105.
- Per house, the **base** shelf spreads over `0 .. Q-2` (a line's last two quests are the payoff, not a
  gate); the **discipline** cut starts at 3, since no discipline unlocks before a line's third quest
  and a locked row at gate 0 only sits in front of the stock a newcomer can actually buy. One pin
  survives the spread: every house must sell a non-discipline weapon at gate 0, or it is a class you
  cannot start playing.
- Disciplines have a level (see "The bill, and what caps it" above). The broad shelf gates on quest
  count; `Vendor.stock` also honours an optional per-item `unlockLevel` against discipline level —
  the mechanism is in, defaulting to 0, so per-item authoring can follow with no migration.

### 4 — Open the doors, gate the goods — **resolved, mostly by cutting it**

- Flatten `unlockPrestige` to 1 — **still open, and now noise.** Four tiers of doors that all open by
  quest 3 buy nothing either way.
- Stagger line *availability* to replace what buildings were doing — **cut.** It manufactures direction
  by removing early choice, and it compresses the back half against the Gate's seven keys. Step 3
  already fixed the half that was felt: the shelf moves every quest, so the town does change.
- A discipline tree screen — **cut, and replaced.** See below.

#### The lattice is complete, and the shelf was already banded by it

The step was written on the premise that seven houses are seven shallow parallel ladders. They are not.
The 21 multiclass disciplines are exactly **C(7,2)** — every pair of houses produces exactly one
discipline, no gaps, no duplicates, six crossings per house. `Discipline.isUnlocked` has always enforced
it and the Forge has always billed both parent houses' materials for a crossing's gear. The tree was
built; nothing drew it.

It did not need a screen, because `ui/panels/shop.lua` was **already** banding the Buy list by
discipline and ordering sections by gate depth. The ladder existed and only the rungs were unlabelled.
So the state went onto those headers: the path's shape (`Rogue x Mage`), its standing (technique level,
or locked), and an open/total count. `Shop:lockReason` stopped saying *"unlock the Ninja path first"* —
which restates the lock — and now names the missing half **and the house that teaches it**: *"Locked:
needs a mage path (The Arcanum)."* A prerequisite became a place.

Two model additions carry it. `Discipline.missingParents` is the half of `isUnlocked` the UI could never
ask for — that function answers "may I?", which makes a locked row a wall; this names what is missing,
which makes it a direction. And the class → house lookup moved to `Vendor.forClass`, the one owner now
that the Forge and the shop both ask it.

#### Why the hub map is not the other half

The obvious companion — light a house's crossings on the city map — is **cut**, and completeness is
why. Because every pair of houses crosses, selecting any house lights *all six others*, every time.
"Which houses pair with here" has the same answer at every building, and a constant is not a signal.
The same C(7,2) property that makes the finding elegant makes the map view empty. (The town layout
makes it worse — seven houses in a 4×3 grid with six unrelated buildings interleaved — but that is the
lesser objection.)

If the hub should say anything it is **state, not adjacency**: a `3 / 9 paths` badge per house, which
varies per building and moves as you play. Not built.

#### Every path folds, and a locked one starts folded

Left expanded, a shelf listed every path its house touches with all of its stock — measured across the
seven vendors at a fresh save, **9–13 screens and 67–104 unbuyable rows**, worst at the Arcanum with 110
rows of which 104 were locked. Thirteen screens to reach about six affordable items.

All the reading is in the header, so a path the player has not unlocked **starts** showing its header
and nothing else. Rows held by nothing worse than this house's quest count stay visible **inside an
open path** — "complete 2 more" is a near thing, and near things pull.

Shut is a default and not a verdict. Each header is a real row that takes the cursor and folds its
section — a caret pointing right when it is shut and down when it is open, worked by Enter, A, or a
click, so all three input methods reach it. The locked stock is the whole *argument* for earning a
path, and a player who wants to see what the Ninja road actually buys them can open it and read every
greyed row. An opened section is pulled to the top of the scroll window, so it unfolds where it can be
seen. Folds are the player's, hold for as long as the shop is open, and are re-defaulted per build —
a path unlocked mid-session opens on its own rather than staying shut because it was locked when the
shelf was first drawn.

| At a fresh save | Rows before | Rows after | Screens |
|---|---|---|---|
| The Arcanum | 110 | **56** | 13.3 → 7.3 |
| The Cathedral | 94 | 52 | 11.4 → 6.8 |
| The Bastion | 79 | 36 | 9.8 → 5.0 |
| The Colosseum | 76 | 32 | 9.4 → 4.6 |
| The Crucible | 76 | 35 | 9.4 → 4.9 |
| The Undercroft | 70 | 28 | 8.8 → 4.1 |
| Hunter's Lodge | 71 | 25 | 9.0 → 3.9 |

A fold takes its rows' requirement text with it, so the header carries it instead: `Shop:pathMeta`
prints *"Rogue x Mage — needs The Arcanum"* on the band, naming the house when the player is **one**
path away, which is the case they can act on. Two away, the shape has already named both halves. With
the header selected, the detail column says the same thing at length — the shape, how much stock is
behind it, how much of that is open, and the full lock reason — so a shut path is never a dead end.

What remains is the base shelf itself: the Arcanum still opens 56 rows deep because a house's own class
stock is shown to its last gate. That is the pre-existing "show locked stock, flagged" policy rather
than anything the paths added, and capping how far ahead it reads is a separate call.

One correction to the framing above, found while scoping this: buildings are **not** the only thing
staggering which lines exist. Every quest carries a `requiredPrestige` equal to its house's
`unlockPrestige` — Cathedral and Colosseum all 1 (27 quests), Bastion and Hunter's Lodge all 2 (27),
Arcanum and Undercroft all 3 (24), Alchemist all 4 (13), flat down *every* quest of each line, the ten
numbered slots and the 2–4 named capstones alike. The doors and the board
gate on the same four numbers, so flattening `unlockPrestige` alone would not change which lines a
player meets. Now that prestige is a flat quest count, those gates read exactly: the whole city and all
seven lines open after **3 quests**.

### 5 — Pay inside the battle — **done**

The diagnosis this step answers is the payout cadence above: every reward in the game landed after the
fighting, once, at the hub. **Discipline technique** is the fix for the second bullet, and it went in
stronger than the bullet described — not a reading of the existing tally, but a currency the bench
actually bills (see "The bill, and what caps it"). What that buys, felt in order:

- **done** — technique accrues per action, capped per battle. The FFT JP borrowing, adapted: JP cannot
  buy abilities here, because an ability is a transferable item in a grid and per-character ability
  learning would break "anyone can carry anything". So it buys the **rung** instead of the ability.
- **done** — it floats over the caster as it lands (`+2 Ninja`, the same channel as damage numbers), so
  the reward is visible in the fight rather than reconstructed at a bench.
- **superseded** — a second, quieter floater (`+1 Knight`, `Combat.noteGrowthVote`) once covered the
  silence technique left behind. Only 233 of 638 item files declare a discipline, and disciplines are
  *locked* content, so an opening campaign hand — `weapon_iron_sword` is `class = "knight"` with no
  discipline — banked nothing and floated nothing. Two awards meant a precedence rule (technique won the
  slot, so one action was never reported twice under one name) and two colours carrying the units apart.
  **Every house banks the same currency now**, so there is one award, one floater, one colour, and the
  rule deleted itself. See "One ledger, three readings".
- **done** — the battle summary names what the fight built, under what it was worth: gold, then
  technique, then loot. Three different things a won fight hands over. Now that class keys bank too, an
  ordinary fight with no discipline gear on the field finally reports something here.
- **done** — the Forge names the bank and who holds it ("Ninja — 62 held by Clem"), bills the row in
  technique, and its refusal names the verb that earns it.
- **done** — the character sheet reads the ledger back (`ui/panels/party.lua`) as the two things a
  player acts on: each house's **claim on the coming level**, and what it has **to spend**. The career
  total is deliberately *not* shown. Nothing reads it — a level-up reads only the delta since the last
  one, and the Forge bills the bank — so printing it would put the one figure nothing acts on beside the
  two that are acted on. The claim is a **percentage** because the fraction is all the model reads: a
  level arrives on prestige, so twenty casts and two hundred in the same proportions grow the identical
  character and a magnitude would imply a rate that does not exist. It is the same number the
  advancement panel reports when the level lands, so the sheet predicts that screen exactly.
- **done** — *the sheet says one thing.* Those two readings first shipped as **two right-aligned columns
  of one table** (`of next lv` / `to spend`) under a title naming `Growth.dominantClass`, and that sheet
  did not survive contact: it read `Growing as Hunter` directly above `Alchemist 33% · Hunter 25%`. Both
  statements were true and they described **different windows of time** — the title the whole career, the
  column the delta since the last level-up — and nothing on screen said so. Two fixes, one cause:
  - The title is the **present** now. "Growing" is present-progressive, so it takes its name from the
    leader of the reading a level-up actually applies (`Party.growthShares`) rather than from the career
    ledger. When nothing has been cast since the last level the clause is **dropped** rather than
    falling back to the innate class, which would print a claim the player never earned.
  - The percentages are **gone**, and so are the column heads that named them. That pairing was tried in
    every arrangement it had — two right-aligned columns with heads, then lifted out into a sentence
    under the member's name (`33% Alchemist · 25% Hunter · …`), then back — and the conclusion was that
    the second number was never worth its keep. A bank of **50 Hunter against 16 Alchemist already says
    which house this body lives in**; the percentage restated the same standing in a second unit, and
    every attempt to keep the two legible side by side cost a header row, a partitive, and a paragraph
    of explanation. The ledger is one figure per house, ranked. Nothing needs a head.
  The career leader is now shown nowhere, and is not missed: it named a thing no decision reads. The
  claim on the coming level is still what a level-up reads (`Growth.shares`) and still what the
  advancement panel reports when it lands — it is simply not a number the sheet has to print.
- **done** — *the sheet shows what the level buys.* The percentages answer "which houses", and raised a
  question they could not settle: **33% Alchemist of what**. Until this landed, the only way to find out
  what a level was worth was to take it and compare. Point at the "Growing as X" clause — the clause is
  a handle — and every stat the coming level moves shows where it is going: `Attack 16 → 17`,
  `HP 77/77 → 80` (a resource row moves its ceiling, so the target is the new max alone).

  **It is a transition, not an addition, and it is not always on.** Both of those were learned by
  shipping the opposite. The forecast first sat there permanently as a green `+3` beside each value,
  which is the universal *this is buffed right now* idiom, and it read as exactly that. The equip delta
  gets away with the same glyph only because it lives for as long as the gesture that causes it — so the
  forecast borrows that property (it appears while the handle is engaged) and drops the grammar (an
  arrow to the value it becomes cannot describe a bonus already in effect). Gating it on the growth
  clause also ties the numbers to the sentence that explains them.

  Hover is the mouse path; **G** and gamepad **LS** pin it, and clicking the clause pins it too, so a
  mouse user can read the whole column without holding the pointer still on one line. A hover nobody
  knows about is a feature nobody has, so the toggle is spelt out in the prompt bar for every device.

  Two properties make it worth the pixels rather than merely decorative:
  - **It is not an estimate.** `Growth.applyLevelBlend` and the forecast are one function (`blendGains`,
    pure), run against the same shares and the same carry. A separate preview implementation would be
    free to drift from the outcome; there is no second implementation to drift. Being pure is also what
    makes it safe to call every frame — a forecast that banked its remainder as it went would advance a
    character *by being looked at*.
  - **It is honest about the carry**, which is why this cannot be eyeballed off a growth table. A stat
    earning half a point a level arrives as +1 every *other* level, so the forecast legitimately differs
    between two levels that grew identically. That is the carry becoming visible for the first time —
    `char.growthCarry` was previously a number the player could feel and never see.

- **done** — *the sheet prints the stat a body actually fights at, and says where it came from.* It did
  not use to. The focus sheet printed `char.stats` — blueprint plus banked level-ups — while equipped
  gear reached the number only when `Combat.applyUnitPassives` ran at the start of a battle. A member
  reading **Attack 17** with a spear and a hauberk in the grid swung for **22**, and no surface anywhere
  in the game said so; the sheet quietly described the body with its kit taken off. `Party.statTotal`
  folds the gear in, so the row is the real figure.

  Hovering a row then opens `ui/stat_tooltip.lua` and itemises it (`Party.statSources`): the body first
  — blueprint and level-ups as **one** row, because "what this character is worth naked" is one fact and
  the split between them is a storage detail of `Growth.resolve` — then one row per piece of gear that
  moves it. `Base 17 / Iron Sword +6 / Chainmail −1`. **No total row**: the parts sum to the figure
  printed on the row the tooltip is anchored to, and `statTotal` reads this very list, so the two cannot
  disagree.

  A row with **no gear on it still gets a box**, showing its one part. Suppressing that case was the
  first cut — `Base 4` under a row already reading `Magic 4` looked like a wasted hover — but it makes
  the tooltip *unreliable*, and an unreliable tooltip is worse than a redundant one: a player who points
  at a stat, gets nothing, and cannot tell "nothing modifies this" apart from "hovering does not work
  here" has been taught to stop pointing at things. The single row says it on its own.
- **done** — *the TECHNIQUE caption explains its own currency.* Hovering the heading opens
  `ui/note_tooltip.lua` (a titled block of prose — the other tooltips in `ui/` all itemise a *thing*;
  this one answers "what is this section counting?"). Three short paragraphs, in the order a player
  meets them: technique is practice banked per house and capped per battle; it is what the Forge bills
  to raise an item a rung, paid by whichever member holds the most of that house rather than by the
  item's carrier; and what a member has been casting lately is also what its next level-up is made of.
  `Theme.caption` now returns the word's rect so any caption can be a hover target without the caller
  re-deriving a tracked width. The list underneath is legible on its own — a house and a ranked figure —
  but nothing else on the sheet said where that figure comes *from*, and "technique" is the one word
  here that is neither gold nor experience and is earned and spent in two entirely different places.

  **Two different fields feed it, and reading the wrong one is silent.** A flat stat is raised by
  `item.bonus` (→ `unit.bonus`, `Combat.flatStat`); a resource CEILING is raised by `item.maxBonus`
  instead (→ `char.maxBonus`, `Combat.unreservedMax`) — Toughness, Endurance, Attunement. A reader that
  checked only `bonus` would report nothing on exactly the three rows whose ceilings a player most wants
  accounted for, so `tests/party_spec.lua` pins both directions: a `bonus.health` must raise no ceiling,
  a `maxBonus.health` must. For a resource the sheet moves the ceiling only — `77/89` — so a wounded
  member still reads as wounded, as it already did against the unraised max.

  Statuses are absent on purpose rather than forgotten — `Status.statBonus` is a battle-time reading of
  a live unit, and nothing on this screen is in a battle. Mouse only: the stat block is not a focus
  region, so a pad has no cursor to put on a row, and inventing one would be a navigation change rather
  than a tooltip. The forecast above — the reading a player *steers* by — is on every device; this is
  the reference lookup beside it.
- **reverted** — a "Growing as **Mage**" line briefly sat under the actions grid, reading
  `Growth.creditClass` live (the class the *next* level-up will apply, moving as you cast). It was
  removed: the growth floaters over the bodies already say the vote is being counted, and a second
  standing read-out in the action panel was one line too many for the space. If the standing ever needs
  surfacing again, the party panel already shows it (`ui/panels/party.lua`).

- **done** — the advancement panel shows its reasoning at both ends. When someone levels, each row
  names how the level was apportioned and what it bought ("as Knight 52% · Mage 48%  +3 HP, +2 Magic";
  plainly "as Sentinel" when one house took the whole level). When **nobody** does —
  which its own header admits is most quests — it does not fall silent: the prestige bar names the
  level either side, the caption reads "0 / 2 prestige to the next level" and "+1 this quest", and the
  line under it says *"No one crossed a level this time — the company still gains."* A flat "No
  advancement" is kept only for a reward table carrying no prestige step at all, which draws no bar.

### 6 — Fix the rates — **done**

All three items are closed: the enemy count is capped, prestige is a flat quest count, and the roster
became the marching company itself, with a rotating field of four. The one thing this step did NOT settle is
whether every quest should land a level — that turned out to be a question about how long the campaign
is, which is step 7.

**Cap the enemy count — done.** The estimate in this document was badly low. Measured over all 92
objectives at the campaign's ~138 prestige, the average fight opened with **57 bodies** and the worst
(`quest_cathedral_the_consecrated_march`) with **121** — not the 48 quoted here, because a composition
may run *several* scaling loops (that one grows demon grunts at `/2` and imps at `/3` on top of a named
champion), and each compounds. New Game+ carries prestige forward, so a second run doubled it again.

Two things made it wrong rather than merely untuned. Enemies **already scale** —
`Growth.ENEMY_LEVEL_LAG` holds ordinary stock at 0.9× the player's level — so head-count was adding
difficulty on top of a curve that was already doing the job. And head-count is **super-linear**: four
units against seventy eat seventy attacks a round and land four.

The fix is a ceiling by authored difficulty, in `models/arena.lua`:

| `difficulty` | Quests | Cap |
|---|---|---|
| Easy | 4 | 6 |
| Normal | 25 | 9 |
| Hard | 63 | 12 |

No new field — `difficulty` already existed on every quest and was display-only. `Arena.clampComposition`
cuts the list at `Arena.build`, and it keeps the **named cast** (the first occurrence of each distinct
id) before any filler, because 43 quests win by `assassinate` and clamping the target away is a softlock
rather than a difficulty change. A hand-authored list of distinct names outranks the cap: the ceiling
exists to stop a *formula* running away, not to overrule an author. The clamp is applied to the enemy
list only, not to `allies`, which are an authored escort. Average after: **10.5**.

It also surfaced an authoring mismatch worth a pass later: `quest_bastion_slot_01` is marked **Easy**
and was fielding **73** bodies. The tiers are now load-bearing, so the four Easy and 25 Normal labels
should be re-read against what those fights actually are.

**Prestige is a flat count of quests completed — done.** `rewardPrestige` was an authored field on all
92 blueprints paying 1, 2, 3 or (the Gate) 10, back-loaded so slots 7–10 of each line paid double. The
field is **deleted**, not set to 1 everywhere: a constant cannot drift, and the weighting it encoded was
invisible anyway — prestige is never shown per-quest, and "this one mattered more" was already being
said far better by what a late quest actually hands over. `Quest.PRESTIGE_PER_QUEST = 1` is now the
whole rule, so prestige literally means *how many quests you have finished*.

`PRESTIGE_PER_LEVEL` moved 3 → 2 to hold the endpoint. Measured after the change:

| | Before | After |
|---|---|---|
| Campaign prestige | 138 (authored, 4 different values) | **92** (= quest count) |
| End level | 46 | **46** |
| Quests per level | ~2 (irregular) | **2.04 (every second quest, always)** |
| New Game+ | 276 → cap | 184 → cap |

What changed is **regularity, not destination**. Holding at 3 would have quietly ended the campaign at
level 31. This does *not* by itself fix "half of all quests level nobody" — the rate is 0.5 levels/quest
either way — but the cadence is now predictable and the advancement bar can be read as "one more quest".
Making *every* quest land a level needs `PRESTIGE_PER_LEVEL = 1`, which gives 92 levels against a cap of
50 and a 42-quest dead stretch; that is a campaign-length decision, so it belonged to step 7 — **which
has since closed it. The rate stays at 2.** With the length settled at 92, one prestige a level would
end the campaign 43 levels past the cap.

**The roster — done, and answered better than this document asked.** The bullet here proposed widening
a company cap in the back half. What landed instead removed the cap entirely: the **roster is the
company** and travels whole, `Player.MAX_FIELD = 4` is how many of it stand on the board at once, and
`Combat.rotate` swaps the bench in mid-fight. So the roster stopped being a bench in the pejorative
sense and became one in the useful sense — every companion comes along, and which four are fighting is
a live tactical decision rather than a menu choice made before the quest.

(An intermediate step here capped the travelling company at eight and had you fill it on a hub screen,
`states/party_select.lua`. That screen is gone: it asked you to choose eight of nine without a board in
front of you, and then the deployment phase asked the same question properly ten seconds later.)

### 7 — Only now, decide the campaign's length — **done. The answer was "not the length"**

**The decisions, taken 2026-08-04.** The step asked how long the campaign should be. The measurement
answered that it is long enough, and that the thing actually worth changing was a rule about *shape*:

> **A player may take one sin's line to its end without touching the other six, and depth is priced in
> difficulty rather than in permission.**

That rule is the step's real output. What follows from it:

1. **The length is 92, settled.** Both play policies walk all 92 quests and not one is silent — every
   quest hands over a level, a shelf row, a discipline, a companion or an item, with no dead run of even
   two. Nothing in the data argues for a cut.
2. **The reserve shape is retired.** "8 slots per line, 5 of 7 lines for the Gate" was chosen as the last
   count needing no retune of the unlock values, and that was derived against ten quests a house. A house
   is 12–14 once its named capstones are counted, and the shelf spreads over `0 .. Q-2` of the *whole*
   sponsor count, so cutting slots moves the gates regardless. The property that made 8 the number does
   not exist.
3. **`PRESTIGE_PER_LEVEL = 1` is closed, not deferred.** 92 quests at one prestige a level is 92 levels
   against a ceiling of 50; the campaign ends at 47, leaving three levels of headroom. It does not fit,
   and step 6 no longer defers the question here.
4. **The on-ramp stays.** A line costs 0–3 quests from anywhere before it opens (Colosseum 0; Cathedral,
   Bastion and Hunter's Lodge 1; Arcanum and Undercroft 2; Alchemist 3), because prestige is a flat count
   of quests finished. "Without touching the other sins" means *from the point the line opens*, not from
   quest one — three quests is an on-ramp, not a wall, and flattening it would stop the town changing at
   all.
5. **A solo run forgoes the 21 crossings, and that is the trade.** `Discipline.isUnlocked` requires a
   subclass held in each parent class, so a player who never leaves one house reaches 16 of the 37
   disciplines. Committing buys depth; spreading buys the lattice. The discipline drought that breadth
   play shows in its middle tenths is the other half of that same bargain rather than purely a defect.

**What shipped for it.** `tools/progression_report.lua` gained a solo walk — one house at a time,
numbered slots only, on-ramp capped — and it measured **0 of 7 lines finishing alone**, six stopping dead
at slot 6. Fourteen gates caused it, two per house: slot 6 asked for six of its house's quests when the
chain supplied five, slot 10 asked for ten when the chain supplied nine, and each shortfall could only be
met with a capstone, every one of which names another house. They are deleted, and all seven lines now
run alone on nothing but their entry cost.

The brake that replaces them is `Quest.SLOT_FLOOR`, filling a `floorLevel` field that was wired end to
end and authored on zero of 92 quests. It is derived from a fight's depth rather than typed into seventy
files, and tuned against the solo pace because that is the only player it binds. The quest board warns
with it, in red when the company is under it — and while there, started drawing the relic and the
companion a quest grants, neither of which any screen had ever read.

*A consequence worth knowing:* every surviving `requiredSponsorQuests` in the campaign is now satisfied
by its own line's chain — slot 7 asks for 6 and the six before it supply 6. The mechanism is live and no
authored quest exercises it. It is kept as documentation of intent; the spec that covers it now builds
its own quest rather than borrowing a real one.

---

#### How the answer was reached

*The step as originally written, kept because the reasoning behind the answer is worth more than the
answer.* Re-measure quest count against the fixed curve; the right length is whatever keeps a step
arriving every battle or two. Cutting first would be cutting to fit a broken shape. The shape held in
reserve — since retired, see decision 2 above — was **8 slots per line** and **5 of 7 lines required**
for the Gate.

The measurement now exists: `tools/progression_report.lua` (`. progression-report [full]`) walks the
board quest by quest and reports what arrives at each — level, shelf rows, discipline, companion, item
— under two play policies, **committed** (one house at a time) and **breadth** (round-robin). It
counts neither gold nor technique: all 92 quests pay gold, so counting it would mark every quest a step
and find nothing; technique and materials accrue per action and per detour, which are real steps but
ones campaign length cannot move. What it found, in order of what it changes:

**The campaign could not be finished, and nothing said so.** `quest_cathedral_slot_03` required 3 of
the Cathedral's quests when only slots 1 and 2 could precede it — all four of the house's named
capstones require slot 3 itself. Every other house starts that ladder at slot 4, where the chain
already supplies the count. So the Cathedral was unfinishable from slot 3 down, taking with it slot 10
(one of the Gate Below's seven keys), two cross-line capstones, and the ending: **15 of 92 quests dead,
including the last one.** The gate is deleted; the line now matches the other six.

It survived because a spec asserted it. `tests/progression_spec.lua` proved the gate opened by
completing `quest_cathedral_the_twin_liturgy` as the third Cathedral quest — a capstone that itself
requires slot 3. The fixture was circular, so the case passed from a board position no player can stand
in. That is the lesson worth keeping: **a gate tested from an unreachable state proves nothing.** The
case now runs on slot 6, where the count genuinely exceeds the chain, and
`tests/progression_report_spec.lua` walks the whole campaign under both policies so a quest that stops
being reachable fails the suite.

**Length is not the defect.** With the deadlock cleared, both policies walk all 92 quests and **not one
of them is silent** — every quest hands over at least one of a level, a shelf row, a discipline, a
companion or an item, and there is no dead run of even two. The reserve shape's premise, that the back
half goes quiet, is not what the data says.

**Order is the defect.** The two policies reach identical totals — 46 levels, 551 shelf rows, all 37
disciplines, 6 companions — and distribute them very differently:

| By tenth of the campaign | Committed | Breadth |
|---|---|---|
| Disciplines | 2–6 per tenth, never zero | **0 in tenths 6, 7 and 8** — a ~28-quest drought, then 6 and 8 dumped at the end |
| Companions | spread 2 / 1 / 1 / 1 | **all 6 inside the first fifth** |

So the player who commits to a house gets the smooth curve, and the player who spreads — the more
natural reading of a board showing seven lines — gets every companion up front and then a third of the
game with no new discipline. Nothing in the game steers toward the former. **Cutting quests would not
touch this**, and a shorter campaign would carry the same shape in less space.

What the curve reads today, measured against the code:

| | Value | Where |
|---|---|---|
| Quests | **92** — 91 across seven lines, plus the Gate | `data/quests/` |
| Per line | **12–14**, not 10: ten numbered slots plus 2–4 named capstones, all sponsored | e.g. Bastion 13, Cathedral 14, Arcanum 12 |
| Prestige | 1 per quest, flat | `Quest.PRESTIGE_PER_QUEST` |
| Levels | one per 2 prestige — 46 crossed, **ending at 47** (this doc said 46 above; 92 quests take prestige to 93, and `1 + floor(92/2)` is 47) | `Growth.PRESTIGE_PER_LEVEL = 2` |
| Ceiling | **50** | `Growth.LEVEL_CAP` |
| The Gate | all **7** slot-10 quests, no partial | `quest_the_gate_below.requiredQuests` |

Those two rows are what retired the reserve shape and closed the level-rate question — decisions 2 and 3
above. The named capstones mean a line is 12–14 quests long, so "8 slots per line" cuts only the
numbered slots and leaves a house at 10–12, while the shelf spreads over `0 .. Q-2` of the sponsor's
**whole** count, so the gates move either way. And three levels of headroom is all the room a
`PRESTIGE_PER_LEVEL = 1` argument has to fit inside; it needs 43 more.

#### What came out of it, and what did not

- **Naming the path a line opens — done.** The quest board says *"Path: Barbarian, Warlord"*, which is
  the answer to "why commit here rather than spread" and had only ever been said on the shop's shelves.
  Re-gating disciplines onto crossings was considered for the same job and **cut**: it pushes players
  *across* houses, which is the opposite of the solo-line rule.
- **Spreading the companions — not done, and it needs an authoring call.** All six grants sit at slot 1
  or 2 of their house, and only six of the seven houses grant one (the Bastion's Rowan starts with the
  player). Moving one is not a data edit: each grant rides a quest whose whole premise *is* the
  recruitment ("The Guide" is how Kaya is met), and the slots immediately after it are written assuming
  that companion is present — Kaya appears in Hunter's Lodge 3 and 4, Amana in Cathedral 4 and 5, Clem
  in Undercroft 3 and 4. Moving the beat means rewriting those scenes. Worth noting the rule change cuts
  both ways here: under a solo run a companion at slot 2 is the *only* one that player will ever get,
  which makes its placement more load-bearing, not less.
- **Re-reading the difficulty labels — measured, and the alarm was overstated.** This document said
  `quest_bastion_slot_01` was "marked Easy and fielding 73 bodies". That count is taken at end-campaign
  prestige; a first run meets that quest at prestige 1–3, where its formula yields three or four bodies
  and Easy is accurate. What the measurement did turn up is bigger and different: **87 of 92 quests grow
  their head-count from `ctx.prestige`, and `Arena.clampComposition` caps every tier — 6 / 9 / 12 —
  by prestige 6, 12 and 18 respectively.** Past that the formulas are dead weight and head-count is a
  constant per difficulty tier. So `difficulty` is now the *only* head-count dial in the game, which
  makes a considered pass over the 92 labels worth doing — but it is a design pass, not a correction,
  and it wants the author rather than a sweep.

### 8 — Stop making the player replay fights they have already won — **done**

The last thing eating a run's pacing was not a payout at all. A trail fight you have outgrown still
costs a deployment phase and a dozen turns to collect its gold, and the interesting question — *do I
spend health here, before the boss?* — has already been answered by the time the board loads. That is
the definition of a fight that should not be played.

Two things were missing, and they turned out to be one thing read twice.

**A ruler.** Nothing rated a body's strength, and level cannot: `Player.syncLevels` pins every roster
member to one prestige-derived level, and stat growth is flat by design (the top of this document), so
two companies at the same level differ only in what they are carrying. So `models/muster.lua` rates a
body by its **effective stats with gear folded in** — `Character.statTotal`, the same numbers the
Loadout sheet prints, which is what makes the reading checkable by a player who wonders about it. One
function is applied to both sides; the far side's bodies are minted with `Growth.spawn` at the level the
fight will actually spawn them at, so it is not an estimate of the enemy, it *is* the enemy.

The score is never printed. It surfaces only as a **margin in percent** (100 = an even match) and the
band that margin falls in:

| Band | Margin | Reads as | Pips | Marker |
|---|---|---|---|---|
| `above3` | under 40% | far above you | ●●● | red |
| `above2` | 40–60% | two steps above you | ●● | red |
| `above1` | 60–85% | a step above you | ● | red |
| `even` | 85–200% | an even fight — it will cost you | — | red |
| `beneath` | **200%+** | nothing here left to spend | — | **calm** |

The scale is **one-sided on purpose**. Being further ahead than `beneath` changes nothing you would do
— the fight is already skippable — so there is one band for it and no ladder of increasingly emphatic
safety. Only the half where the fight is a real fight is graded. That is also why `even` spans so wide:
"you are somewhat ahead" and "you are dead level" are the same decision.

**Two readings of that one number.** Continuously, it draws the marker on an overworld stop
(`ui/overworld_map.lua`): the **box colour** says whether this is a fight at all — hostile red, or a
calm slate once you have outgrown it — and the **pips** say how many steps above you it stands, none at
all for a fight that is even or beneath you. Against the threshold, the same number gates the offer:
`Muster.WALK_OVER` is deliberately the floor of the top band and not a constant of its own, so the
marker that goes calm and the option that appears cannot drift into disagreeing about the same tile.
The HUD also names the hovered (or adjacent) fight in words — `"Dire Wolf - Tier 2 - A step above you"`
— since a glyph is the read across the whole board and a word is the read at the moment of deciding.

**What the pips count changed, and that is the point.** They used to count the authored TIER, which is a
fact about the encounter table rather than about this run: the same three dots whether the company
walked in naked or fully forged. Counting *steps above you* instead means the mark moves as the company
does. The tier is not lost — it is named in the HUD line, where an absolute number can sit without
competing with the glyph.

Two failures on the way here are worth keeping, because both are easy to re-commit:

- The old pips said one thing **twice**: count *and* colour were both the tier. Giving the colour away
  looked like a free upgrade — one glyph, two facts — but it removed the redundancy that was the only
  reason the glyph worked. At a 32px tile a pip is under 2px across; nobody was ever counting them,
  they were reading "red" for tier 3. Pips are now `s * 0.09` on a dark seat, sized to be counted.
- An intermediate design put the tier in a **numeral badge**. It read well, but it answered the wrong
  question — the player wants to know where a fight stands relative to *them*, not its absolute rating.
  (It also surfaced a font trap: `Theme.display` is Alegreya with **old-style** figures, so digits are
  x-height and "3" hangs below the baseline. Use `Theme.body` — Alegreya Sans, lining figures — for any
  standalone numeral.)

**What the offer does.** Stepping onto a fight beneath you opens a two-option prompt instead of entering
it. Auto-resolve builds the same fight the battle state would (`models/encounter_battle.lua`, lifted out
of `states/battle.lua` for exactly this reason), stands the company where Auto-Fill would have, fires
the same opening abilities and relics, and runs every turn through the same AI that drives an enemy
(`models/autobattle.lua`). Then it pays through the same grant seam, and the victory panel opens over
the overworld.

**It is not free, and that is the point.** Party characters ride into the simulation by reference, as
they do in any battle, so health and mana come off the roster, potions are drunk, technique banks, purse
gold is spent and a theft lands in the stash — through the ordinary code paths, because there is no
second set of them. Walking a fight off buys you the *clicking*, not the *attrition*. What it cannot
cost you is the run: the gate is high enough that the outcome is a formality, so a simulation that goes
badly is still finished as a victory (`Combat.reviveFallenParty` carries the fallen out at a sliver of
health, exactly as a won battle does). A bad roll reads as a mauling, which is an honest price.

Scope is `combat` and `elite` only. The quest objective is always played, and so is any encounter
carrying `allies` or an `objective` of its own — those have a win clock driven by `states/battle.lua`
rather than by `models/combat.lua`, and a headless loop would never be told they had ended.

## Known debt

Each item below was re-checked against the code on 2026-08-03; the biome entry closed and has moved to
the paragraph at the end.

- **A house's own class shelf still opens to its last gate** — the Arcanum is 56 rows deep at a fresh
  save even with every locked path folded shut. `Vendor.stock` has no look-ahead limit at all: it emits
  every item the vendor sells and marks the unaffordable ones `locked`. The base rack folds like any
  other section now, so a player *can* shut it by hand, but it still opens expanded; capping how far
  ahead it reads is an open call (step 4).
- **`char.growthBy` has no screen** that reads it as "Knight 3 / Mage 2". Narrower than it was: the
  per-character *technique* ledger now has one (`ui/panels/party.lua`), and a discipline's standing
  already surfaced in the shop's section headers, the Forge's detail pane ("Ninja — 62 held by Clem")
  and the battle summary. What is still unread is `growthBy` specifically — the count of **levels**
  credited per house, which is a different unit from the ledger beside it and is now booked in
  fractional shares. It is written by `Growth.resolve`, persisted by `models/save.lua`, read by
  `Discipline.level` and by the specs, and by no UI module anywhere.
- **The difficulty labels were never re-read, and now they are the only head-count dial there is.**
  Still 4 Easy, 25 Normal, 63 Hard. The original entry here claimed `quest_bastion_slot_01` was "Easy
  and fielding 73 bodies"; measured properly, that count is taken at end-campaign prestige and a first
  run meets that quest at prestige 1–3, where it fields three or four. The real finding is different:
  **87 of 92 quests grow their head-count from `ctx.prestige`, and `Arena.clampComposition` pins every
  tier — 6 / 9 / 12 — from prestige 6, 12 and 18 respectively.** Past that the formulas do nothing and
  head-count is a constant per tier, so the label *is* the fight's size. A considered pass over the 92
  is a design job for the author, not a sweep.
- **The companion joins all sit at slot 1–2**, six of them, in six of the seven houses (the Bastion's
  Rowan starts with the player). Under breadth play that spends the largest reward budget in the game
  inside the first fifth; under a solo run it means the one companion a player gets arrives almost
  immediately. Moving one is not a data edit — each grant rides the quest that *is* the recruitment, and
  the slots after it are written assuming that companion is present. It needs an authoring pass.
- **The seven house materials have no art.** The three craft grades (iron scrap, steel ingot, mythril)
  have their PNGs; all seven house stocks — chrism wax, ember slag, green sinew, gutter silver,
  leyglass, quicksalt, salt iron — do not. `models/sprite.lua` resolves a missing file to its path
  rather than crashing, so they work and look like nothing. See `docs/art-assets.md`.
- **No biome has a tileset drawn yet.** All seven resolve `assets/overworld/<id>.png` to a path string
  and fall back to coloured rects, so the boards below differ in shape and hazard but not yet in
  appearance. Tracked in `docs/art-assets.md` and `docs/commission-terrain-tileset.md`; noted here
  because it is what remains of the entry above it.

Closed since this document was written: `Material.TIER_BY_LEVEL` (retired with the depth ladder), the
unreachable blacksmith (it is The Forge, and it has a door), the four-value shelf enum, and **the
two-biome campaign**. That last one read "92 quests run on two biomes (62 castle, 30 forest)" and was
called the ceiling on how far step 2 could carry, since a cache only pays you for leaving the path if
the places differ. There are now **seven** biomes and the split is castle 35, forest 16, tundra 13,
desert 11, swamp 10, volcanic 7, underworld 1. They differ generatively rather than cosmetically —
each `data/biomes/<id>.lua` sets its own maze `spacing`, river count, battle floor and signature
hazard (desert's quicksand mires, tundra's black ice), so the detour that a cache sits on is a
different walk in each. What is left of the item is art, above.
