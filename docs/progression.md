# Progression

The goal, stated once: **the player must feel themselves getting stronger, and feel what it cost.**

This document is the campaign's shape — how long it is, what levels a body, what opens the town, and
how it ends. The BOARD a day is spent on is [docs/overworld.md](overworld.md); the two are separate
because they answer different questions and were rewritten at different times.

> **This is a rewrite.** The document it replaces described a campaign of 92 quests, all of them
> walked, in which every roster member levelled together off a global `prestige` and the ending was
> unlocked by collecting seven keys. None of that is true any more. What survives is kept below with
> its reasoning; what was reversed is recorded as reversed, because the arguments are worth more than
> the conclusions and several of them are still load-bearing.

## The three numbers

Prestige was one number doing three jobs badly. It is gone. Each job has its own now, and they cannot
be confused because they are not even the same kind of thing:

| | What it is | Where |
|---|---|---|
| **The day** | How long there is. Spent by *entering a ground*, never given back | `models/calendar.lua` |
| **Experience** | How strong a body is. Earned by acting and by felling, per character | `models/experience.lua` |
| **Standing** | How far into the story you are. A count of finished quests | `Player.standing` |

The split is the whole re-premise. Under prestige, *how far in* and *how strong* were the same number,
so every roster member was interchangeable at a given moment and a day spent anywhere but on a quest
grew nobody. Under a deadline the second half is fatal: a day that clears no objective — one spent
walking a ground for its caches and turning back — has to still be worth taking.

## The clock

**Forty days, and then he arrives.** There are more quests than there are days, so the campaign stops
being *finish everything* and becomes *choose what to finish* — which is the decision seven houses were
built to offer and never got to ask.

**A day buys a GROUND, and ENTERING spends it.** Not clearing an objective — entering. Take everything
posted there, take one thing and turn back with your pockets full, or get wiped, and the day is gone all
three ways.

**The expedition is a place, not a piece of work.** The board lists where the company can travel today;
the quests every house has posted on that ground are all standing on the map when you arrive, each at
the end of its own spur, ticked off a checklist as they are taken (`Quest.trip`,
[docs/overworld.md](overworld.md)). Clearing one pays *that* quest — gold, relic, that house's standing —
and leaves you on the map with the others still out there. So the greed dial is inside the day now as
well as across it: not only *which ground*, but *how much of it* before the company is too worn to
continue.

> **This replaced one quest, one run.** A quest was the expedition and the ground was a consequence of
> it, which meant the board asked its question the wrong way round — you picked a piece of work and were
> told where it happened. It also meant a house whose live quest sat on a shut ground was simply
> unavailable, and a day could only ever advance one house.

**Walking out is free**, and losing a fight is the whole of the risk — a wipe takes three quarters of
the run's coin and ore ([docs/overworld.md](overworld.md)). That is where the greed lives: pushing one
more spur is a bet against the *fight*, not against the walk home, and the answer changes with how much
you are already carrying.

**There is no fail state.** The last day is not a loss screen, it is the last battle, fought with
whatever company you assembled.

**The hub is free.** Shopping, forging, the Loadout, mending a wound, eating at the Cafe: no days. One
clock, not two — a hub that spent days would turn every visit to a shelf into arithmetic, and the
interesting decision is which expedition to take.

### Where forty came from

Derived, then ratified, and it is worth writing down because it is now load-bearing:

- A house's line reaches its slot 10 in **10–13 quests**, including its 0–3 on-ramp (`. progression-report`).
- At roughly three quarters of days on story work, forty days is about thirty quests — **2.7 lines**.

The target was *a player finishes two or three houses*, and that target is the actual judgement. It
rests on three things: it makes the solo-line rule bite (below), it leaves most of the campaign unseen
so a second run has a reason to exist, and anything approaching seven lines needs seventy-odd days,
which is not a constraint at all.

**`Calendar.FINAL_DANGER` is anchored against forty days of income.** Moving the day count means
re-reading it, and `. board-report 12 xp` is the instrument. `Experience.STEP` used to be anchored the
same way and no longer is — see [The curve](#the-curve), where it collapsed into the descent's ladder.

> **The second bullet is out of date and the arithmetic behind it has to be redone.** It was written
> when a day bought one quest, so days and quests were the same number. A day buys a ground now, and a
> ground can carry several houses' live work — so a day a player spends well is worth two or three
> quests, and forty days reaches far more than thirty. That is a consequence of the change rather than
> an argument against it (the alternative, a day per objective, would have made a whole ground of work
> just a queue), but every number in this section is downstream of it: whether the target is still 2.7
> lines, whether forty is still the right span, and what the solo-line rule costs when spreading is
> cheaper per day than it used to be. `. progression-report` is the instrument and it has not been
> re-read. **This is the largest open item in the document.**

### The solo-line rule, which finally costs something

> A player may take one sin's line to its end without touching the other six, and depth is priced in
> difficulty rather than in permission.

That was settled long before the clock, and it was free to ignore: you could run all 92. Now it is the
game. `Quest.SLOT_FLOOR` fills a fight's `floorLevel` from how deep down a line it sits, so pushing one
house hard gets *hard* while spreading stays shallow — the pricing mechanism was already built and
already tuned for exactly this.

A solo run also forgoes the 21 crossings: `Discipline.isUnlocked` wants a subclass in each parent
class, so a player who never leaves one house reaches 16 of the 37 disciplines. Committing buys depth;
spreading buys the lattice.

## The curve

Levels are **earned per body**, by acting and by felling, resolved at the end of every fight.

`Experience.STEP = 10`, and there is **exactly one of it**. There used to be two — a campaign step of 3
measured against forty days of quest-board income, and a `DESCENT_STEP` of 10 anchored on the bottom of
the Gate — on the reasoning that two modes with two clocks must not share a constant. The Quest Board
is retired (`Building.RETIRED`) and the descent is the campaign now, so the mode that needed its own
number no longer ships, and all the split still bought was a branch every seam had to get right.

**Which they did not, and it is worth recording how it failed.** The pick was written
`game.descent and DESCENT_STEP or nil`, so any seam standing outside a run silently took the cheap
ladder:

| | |
|---|---|
| Act 0's four fights pay | ~48–84 a body (measured through `models/autobattle.lua`) |
| ...which on the campaign step was | **level 8** |
| ...and on the one step is | **level 3–4** |
| The first floor fights at | `Descent.OPENING_DANGER = 3` |

So the prologue handed the Gate a company five levels above the floor it was about to walk onto: over a
quarter of floor 1's stops read as *Beneath you* and offered to auto-resolve themselves
(`Muster.WALK_OVER`), and then — because `Growth.resolve` never levels a body down — that head start
cost four floors during which nobody gained a level at all. `Player.resolveLevels`, the load-time
catch-up, passed no step either, so a mid-descent save re-levelled its whole roster on the cheap curve
every time it loaded. **The tutorial's income was never the defect. The curve it was read on was.**

The step itself is anchored on the bottom of the descent: a floor is about six fights paying a body
roughly twelve apiece, so fifteen floors are ~1080, and reaching level 15 — what the Hollow Crown fights
at — costs `STEP × 15 × 14 / 2`. Ten puts a company that fights its way down exactly there and one short
of overshooting. `tests/experience_spec.lua` pins both ends of that ladder, the Crown and Act 0;
`tests/descent_level_spec.lua` walks all fifteen floors against it.

`. board-report 12 xp` still measures what a day of ordinary board fighting banks (22 a body), but it is
a cross-check now rather than the measurement the constant is derived from.

### Two rules the per-body curve forced

**A benched member earns half** (`Experience.BENCH_SHARE`). Not zero: the roster IS the company, it
travels whole, and `Combat.rotate` makes swapping the bench a live tactical decision. Bodies nobody
would rotate in make that mechanic decorative. Not full either — standing on the board is where the
risk is.

**A recruit joins on the company's median** (`Experience.medianOf`). Level 1 is a reward the player
cannot take, and under a deadline they will never get the spare days to fix it; matching the best member
is a free ride that makes a late recruit strictly better than an early one.

### Where a player reads it

**The victory panel** (`ui/panels/battle_summary.lua`) draws a bar per body that fought — the level it
walked in on, filling with what the fight paid it, rolling over and turning gold on a level-up.
`Experience.report` builds those rows off `combat.xpByChar`. The bench's share is named there too, as a
line under the bars: a panel that showed four bodies growing and said nothing about the other four
would teach exactly the habit the rotating field exists to break.

## What the world does

**The world hardens on the calendar, not on the company.** `Calendar.dangerLevel` ramps 1 → 22 across
the campaign and reads nothing about the party. That is the load-bearing half of the deadline: scaling
danger to the player refunds every day they squandered, because the fights get easier exactly as fast
as you fall behind.

Measured end to end: day 1 fields two wolves at level 1, day 20 four at level 10, day 40 four at 19.
(Ordinary stock sits under the headline because `Growth.ENEMY_LEVEL_LAG` still applies underneath —
the gap is what leaves an elite or a `floorLevel` somewhere to reach.)

The same day drives encounter gating (`minDay`), head-count formulas, the loot band and the overworld
marker's rating. `tools/day_migrate.lua` moved 110 `ctx.prestige` and 21 `minPrestige` across 108
blueprints in one auditable pass.

## What the town reads

**Standing is a count of finished quests**, and every authored gate still means what it always meant:
prestige started at 1 and rose by one a quest, so `Player.standing` reads back as `questsCompleted + 1`
and not one of the 91 quest gates or 12 building gates needed rewriting.

### The opening funnel

Three doors — the Cathedral, the Bastion and the Hunter's Lodge — carry
`unlockQuest = "quest_colosseum_slot_02"` alongside their standing threshold, so the funnel is two
Colosseum quests wide and the city arrives *after* the tutorial rather than during it. Standing 2 was
landing three shops on the debut's payout.

The Cathedral's is a story gate and reads as one (the player is carried into that building at the end
of the padded card and wakes up in it — [docs/story.md](story.md), *Raised, then kept*); the other two
are honest pacing, and are only two houses wide on purpose. **Everything above is untouched**, so the
Arcanum, the Undercroft and the Crucible still arrive on a tick and the early choice begins at quest 3.
Extending this to the remaining four houses is the staggering idea that was cut, and it stays cut.

> **A consequence of the split, recorded rather than smoothed over.** These doors AND their standing
> threshold used to be independent gates. They are not any more: finishing the padded card *is* two
> quests, which necessarily carries standing 3, past the Bastion's threshold of 2. The AND now does one
> gate's work. For a door to bite in both directions again it needs a threshold *above* the quest count
> its own `unlockQuest` implies.

### The shelf still moves every quest

Unchanged and still right. Stock keys on that vendor's own finished-quest count at per-quest
granularity — 474 priced items over 13 gates rather than clumps of 33/123/208/105 — so every quest
hands its house something new. A house's own base rack still opens to its last gate (the Arcanum is 56
rows deep at a fresh save even with locked paths folded shut); capping how far ahead it reads is still
an open call.

**Under the clock, shelves are shallower per run**, because fewer quests are finished. That is the same
bargain the disciplines make: committing buys depth, and the rest is what a second run is for.

## How it ends

**He comes on the last day whether anyone is ready or not.** The Gate Below used to require all seven
generals dead — seven keys, a count climbing from 1 of 7 that was the last stretch of the game. A
calendar cannot carry that: seven lines to their slot 10 is about seventy expeditions.

So the lock is gone and **the count changed job. It was permission; it is consequence.** Every general
still breathing stands beside him:

| Generals felled | Bodies in the last fight |
|---|---|
| 0 | 10 |
| 3 | 7 |
| 7 | 3 — the Crown and two guards |

`requiredQuests` on the finale is renamed `hintQuests` precisely so nothing mistakes them for keys
again, and the board shows the Gate from the first morning rather than from the first kill: a deadline
nobody can see is not a deadline.

The finale also pins its own `floorLevel = 22`. It never needed to before — the key chain implied
seventy finished quests, so anything asking "how deep is this fight" read it off the prerequisites. With
the keys gone that inference collapsed and the last fight in the game started measuring as an opening
skirmish, which is how the balance suite noticed.

**New Game+ hands the time back.** It resets the calendar and the supper along with the quest ledger,
because a deadline is not a possession; it carries the company and its experience. `campaignsFinished`
is deliberately *not* reset — beating the game once cannot be undone by playing it again, and it is
what opens the Descent on the main menu.

## Where you can go this morning

`data/biome_windows.lua`, read through `models/biome_window.lua`. Each of the seven grounds is open for
an authored stretch of the forty days, three or four of them at once. **The board's rows are those
grounds** — travel is the only choice the panel offers now — each wearing what the number is *of*,
"3 days left", never a bare 3, with the last two mornings marked by a red edge on the row. A ground with
nothing posted on it draws no row at all: you cannot spend a day travelling somewhere purely to dig.

**The calendar made a day a choice of *what*; this makes it a choice of *where*.** With ninety-two
quests permanently on offer, which house to advance was a preference and never a deadline. A window is
a deadline: the swamp shuts on day 22 and the Crucible's leg sitting in it goes with it until day 32,
so wanting that leg costs today.

**A quest names a *set* of grounds, not one.** `map.biomes = { "tundra", "castle" }`; the older single
`map.biome` still reads, as a one-element set, so files widen a house at a time. This is forced by the
chain structure — a house's line is strict (`slot_05` names `slot_04`), so a house has exactly one live
quest and the whole board is seven to twelve quests wide. Pin each to one ground and a day's swamp
holds whichever houses' next slot happened to be swamp, which is usually none. `Quest.start` collapses
the set to the one ground the player travelled to, which is the single `map.biome` everything
downstream has always read.

**Two exemptions, both fail-open**, because the failure mode of a window system is a quest that
silently stops existing, and a quest that has vanished from the board is unfindable from inside the
game. The finale ignores the schedule outright — it is gated on the day and nothing else — and a quest
naming no ground at all is reachable from every open one.

**Measured, not guessed.** `& "E:\LOVE\lovec.exe" . biome-report` walks all forty days under both play
policies and reports whether every open ground held live work; `[full]` prints the day-by-day grid, and
a blocked day names the quests that were stranded and the grounds they were pinned to, which is the
widening pass's worklist. The first draft of the table was perfectly well formed — three grounds open
every day, no overlaps — and left **days 1 through 9 unplayable**, because the debut stands on the sand
and the desert did not open until day 10. `tests/biome_window_spec.lua` walks the same route and fails
on any blocked day, since nothing about the table's own shape can catch that.

> **Castle is deliberately the narrowest window** (18 days, fewer than any other ground) against
> **35 of the 92 quests authored there**. A schedule wide enough to carry that share would have propped
> the imbalance up instead of exposing it. Reading the names, "castle" has been doing duty as *indoors
> in town* — wards, vaults, towers, cellars, a tavern — so re-siting most of them is a fiction problem
> rather than a data one. Unfinished: the census in `. biome-report` is the ledger for it.

## Foraging, which is now what you carry off the ground

**There is no separate day of ore.** The caches on whatever ground you travelled to *are* the day's
foraging, and they bank when you leave (`game:bankHaul`). Each house's stock rides the caches of the
ground that house works, dealt round-robin across every house with a claim on it (`placeCaches`), so
travelling somewhere three houses are working pays all three — partially. The board does not grow to
fit them: `deriveDims` is content-sized, so three houses against four or five caches means no single
trip fills every quota, and "which spur do I still have the health for" is a real question with several
partial answers.

Which house works which ground is **authored** in `Request.BIOMES`: the Bastion a tundra, the Arcanum a
volcanic waste, the Lodge and the Cathedral a forest, the Crucible a swamp, the Colosseum the sand, the
Undercroft the castle. Never the underworld.

> **This used to be a hash of the vendor id.** Stable, which was the only property it needed while
> nothing displayed it. The windows made the mapping something the player reads and plans around, and
> an arbitrary answer to a visible question is just a wrong answer that happens to be consistent.

> **It also used to be a whole expedition.** `models/request.lua` offered a rolled board with no story
> on it, taken for one named house, and the quest board drew a "Forage for the Bastion" row per house.
> That was right when a day bought one quest: a day you did not want to give to somebody's errand was
> otherwise a day you could not give to anything. It cannot survive a day that buys a whole ground —
> against a trip clearing three quests *and* hauling the same caches, nobody would ever choose it again.
> So the rows are gone and the design's own stated intent arrived instead: the multi-house distribution
> was written up here as unbuilt, needing "`params.houseMaterial` to become a LIST distributed across
> the caches a board already has". `placeCaches` had grown exactly that and nothing ever passed it one.
>
> What went with the rows: no board row can pay **standing** — a house's standing drives its shelf, and
> buying the catalogue without running a line was always the thing foraging must not do. That is now
> true by construction rather than by a carve-out in the payout, since the only thing that writes the
> quest ledger is a quest.

## What survives from the old campaign, unchanged

These were settled before the clock and the clock did not disturb them. Kept short here; the reasoning
is in the code.

- **Stat growth is flat on purpose.** `models/growth.lua` proves linear growth against subtractive
  mitigation converges to a constant however it is tuned. Growth comes from gear, abilities,
  disciplines and roster — never from the curve. Do not go looking for a knob.
- **One bench, The Forge.** The only thing that raises an `item.level` and the only thing that spends
  materials. A vendor sells and buys back, nothing else.
- **Technique is earmarked.** Banked per house per character by playing that house's gear, spent at the
  Forge to buy depth. Gold buys breadth. *This is why walking a ground cannot pay technique* — the
  earmark ("ninja technique comes only from ninja play") is the entire justification for a second
  currency, so a day of hauling ore pays ore.
- **Materials tag where you went.** Craft stock by the item's own quality, house stock by the houses
  working the ground you walked — so a day out stocks the bench another house's gear will empty.
- **A level credits everything you cast.** `Growth.shares` apportions across every house cast since the
  last level, with per-stat remainders carried, so nothing is thrown away.
- **The disciplines are a complete lattice.** 21 crossings = C(7,2), every pair of houses. The shop's
  own section headers are the tree; a separate tree screen was cut and stays cut.

## Known debt

- **`docs/story.md` has not been re-read against the deadline.** The campaign now has a fixed span and
  an ending that fires on schedule with a variable final fight. Whether the story as written survives
  that framing is an authoring question nobody has asked yet, and it is the largest open item here.
- **The tuning is first-pass and wants play, not more measurement.** `Calendar.DAYS = 40`,
  `FINAL_DANGER = 22`, `Experience.STEP = 10`, `Player.CAMP_SHARE = 0.5`. The instruments exist; whether
  forty days *feels* like pressure or like a leash is the one question none of them answer.
- **The day's span has not been re-priced against a ground buying several quests.** See
  *Where forty came from*. Everything downstream of "forty days is about thirty quests" needs walking
  again with `. progression-report`, and this is the one item that could move `Calendar.DAYS` itself.
- **A ground can hold seven houses' live work at once**, and `. board-report` says roughly 8% of ends
  already land on open trail instead of a spur because the board ran out of dead ends. It degrades
  gracefully and it is counted, but if a full board reads as a slog the honest fix is a cap on how many
  ends one day may carry, and there is no cap today.
- **`requiredPrestige` and `unlockPrestige` still carry the old name** in 91 quests and 12 buildings.
  They read `Player.standing` and mean exactly what they always meant; the rename is cosmetic and was
  deliberately not bundled with a behaviour change.
- **`char.growthBy` has no screen.** Written by `Growth.resolve`, persisted, read by `Discipline.level`
  and the specs, and by no UI anywhere.
- **The companion joins all sit at slot 1–2** of six of the seven houses. Under the clock this is closer
  to a feature than a defect — which companions you get follows from which lines you chose, and every
  scene is authored for a partial roster — but nobody has re-read it deliberately.
- **The difficulty labels were never re-read.** Still 4 Easy, 25 Normal, 63 Hard, and since
  `Arena.clampComposition` pins every tier the label *is* the fight's size. A design pass for the author.
- **The seven house materials have no art**, and no biome has a tileset. See
  [docs/art-assets.md](art-assets.md).
