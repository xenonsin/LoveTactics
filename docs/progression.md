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
| Emergent class | **Done** | `Growth.creditClass` grows a character into whatever gear it casts. It was surfaced nowhere at all in a fight; it now reads live under the actions grid as "Growing as Mage", so it can be steered rather than discovered |
| Gear & forge | **Done** | One bench, The Forge, reachable from the city; one bill, one ladder. Was two doors onto one ladder, one of which no building opened. Discipline stock is billed in technique and carries no ceiling at all |
| Shelf waves | **Done** | Stock keys on the vendor's own quest count (always correct), now at per-quest granularity: 474 items across 13 gates instead of clumps of 33 / 123 / 208 / 105 |
| Disciplines | **Done** | 37 of them, forming a COMPLETE lattice — 21 crossings = C(7,2), every pair of houses. A discipline is a currency (`char.technique`) banked per action and spent to forge its own gear, and the shelf reads as the tree: each section a path, with its shape, standing and what it still needs |
| Roster | **Done** | A company of 8 travels (`Player.MAX_PARTY`), 4 stand on the board (`Player.MAX_FIELD`), and `Combat.rotate` swaps the bench in mid-fight |

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
| carries a `class` | gold, `40 × target` | the standing of the house that sells it (`Quest.sponsorProgress` → `Vendor.tier`) |
| classless | gold | none; the materials are the only brake |

The discipline row used to read *gold*, capped at `Discipline.level + 2`. Both halves of that are gone,
for one reason: a quest spent playing a ninja bought the right to pay **the same gold a knight pays for
a knight thing**, and it bought it invisibly, at a bench, two quests later. That is a permission slip,
and permission slips are not felt. Billing the play itself closes the loop where the player can watch
it: fight as a ninja, bank ninja technique, forge the ninja kit. Keeping the ceiling *as well* would
charge twice for one rung, so it went with the gold.

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
discipline (a `free` ability does not end the turn, and nothing obliges a player to finish a fight),
and losing on purpose to farm a bank is undone by "Try Again" restoring the pre-fight snapshot — which
works only because technique rides in the *character* snapshot, pinned by a spec that says so.

`Discipline.level` survives, unchanged and no longer used by the forge: it still gates the shelf's
optional per-item `unlockLevel` (`Vendor.stock`).

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
- **done** — the battle summary names what the fight built, under what it was worth: gold, then
  technique, then loot. Three different things a won fight hands over.
- **done** — the Forge names the bank and who holds it ("Ninja — 62 held by Clem"), bills the row in
  technique, and its refusal names the verb that earns it.
- **done** — "Growing as **Mage**" sits under the actions grid (`CombatPanel:drawGrowthLine`), reading
  `Growth.creditClass` live: the class the *next* level-up will apply, moving as you cast. It had no
  reader outside `models/growth.lua` at all — the best idea in the system was computed every level-up
  and shown to nobody until the hub, after it was too late to steer. Deliberately kept **alongside**
  the technique floater rather than folded into it: the floater is a *delta* on a *wallet* (what that
  action banked, discipline stock only), this is a *standing* on a *vote* (what the character is
  becoming). It also covers plain class play, which the floater cannot — 375 of the 580 class-tagged
  item files carry no discipline, so the floater alone leaves most casting silent.

- **done** — the advancement panel shows its reasoning at both ends. When someone levels, each row
  names the credited class and what it bought ("as Sentinel  +3 Magic, +5 MP"). When **nobody** does —
  which its own header admits is most quests — it does not fall silent: the prestige bar names the
  level either side, the caption reads "0 / 2 prestige to the next level" and "+1 this quest", and the
  line under it says *"No one crossed a level this time — the company still gains."* A flat "No
  advancement" is kept only for a reward table carrying no prestige step at all, which draws no bar.

### 6 — Fix the rates — **done**

All three items are closed: the enemy count is capped, prestige is a flat quest count, and the roster
became a company of eight with a rotating field of four. The one thing this step did NOT settle is
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
`MAX_PARTY` in the back half. What landed instead splits the number in two: `Player.MAX_PARTY = 8` is
the **company** that travels, `Player.MAX_FIELD = 4` is how many of it stand on the board at once, and
`Combat.rotate` swaps the bench in mid-fight. So the roster stopped being a bench in the pejorative
sense and became one in the useful sense — every companion comes along, and which four are fighting is
a live tactical decision rather than a menu choice made before the quest.

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

## Known debt

Each item below was re-checked against the code on 2026-08-03; the biome entry closed and has moved to
the paragraph at the end.

- **A house's own class shelf still opens to its last gate** — the Arcanum is 56 rows deep at a fresh
  save even with every locked path folded shut. `Vendor.stock` has no look-ahead limit at all: it emits
  every item the vendor sells and marks the unaffordable ones `locked`. The base rack folds like any
  other section now, so a player *can* shut it by hand, but it still opens expanded; capping how far
  ahead it reads is an open call (step 4).
- **`char.growthBy` has no screen** that reads it as "Knight 3 / Mage 2". A discipline's standing now
  surfaces in three places — the shop's section headers, the Forge's detail pane ("Ninja — 62 held by
  Clem"), and the battle summary's technique rows — but the per-character ledger behind them does not.
  It is written by `Growth.creditClass`, persisted by `models/save.lua`, read by `Discipline` and by
  the specs, and by no UI module anywhere.
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
