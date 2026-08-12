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
| **The day** | How long there is. Spent by *entering* an expedition, never given back | `models/calendar.lua` |
| **Experience** | How strong a body is. Earned by acting and by felling, per character | `models/experience.lua` |
| **Standing** | How far into the story you are. A count of finished quests | `Player.standing` |

The split is the whole re-premise. Under prestige, *how far in* and *how strong* were the same number,
so every roster member was interchangeable at a given moment and a day spent anywhere but on a quest
grew nobody. Under a deadline the second half is fatal: an expedition that forages has to still be
worth taking.

## The clock

**Forty days, and then he arrives.** There are more quests than there are days, so the campaign stops
being *finish everything* and becomes *choose what to finish* — which is the decision seven houses were
built to offer and never got to ask.

**A day is an expedition, and ENTERING spends it.** Not clearing the objective — entering. Take the
boss, break off with a Smoke Bolt, or get wiped, and the day is gone all three ways. That is the whole
greed dial: "push on or go home with what I have" only means something if going home costs the same
day that pushing on would have.

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

**`Calendar.FINAL_DANGER` and `Experience.STEP` are both anchored against forty days of income.**
Moving the day count means re-reading both, and `. board-report 12 xp` is the instrument.

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

`Experience.STEP = 3`, and it is anchored on a measurement rather than an estimate — which matters,
because the estimate was wrong by a factor of two. `. board-report 12 xp` fights every combat and elite
on a dozen rolled boards through `models/autobattle.lua` (the real loop, the real plan, the real
ordering) and reads what combat actually banked:

| | |
|---|---|
| Measured income | **22 experience a body a day** (the design note said 44) |
| Over forty days | 882, clearing every board entire |
| Which reaches | **level 23–24** at STEP 3 — near 20 for a run that skips a third of its fights |
| Against a world closing at | `Calendar.FINAL_DANGER = 22` |

At the old STEP of 6 that same income landed at level 17 — five short of the world — so a player who
fought everything still arrived outmatched. That is not a deadline, it is a wall.

The first measurement said **four** a day, and that was the harness lying rather than the game: the
opening roster is one body at level 1, and a lone level-1 Rowan against day-20 stock is dead in two
turns. The fix names the circularity rather than hiding it — to know what level a company reaches by
day N you need the curve being measured — and resolves it by **assuming parity**: level the company to
what the calendar says the world is worth, then ask what a day pays them.

**The descent keeps its own step** (`Experience.DESCENT_STEP = 6`). Its ladder is anchored on seven
floors, not on forty days, and sharing one constant meant every campaign retune silently re-tuned the
post-game.

### Two rules the per-body curve forced

**A benched member earns half** (`Experience.BENCH_SHARE`). Not zero: the roster IS the company, it
travels whole, and `Combat.rotate` makes swapping the bench a live tactical decision. Bodies nobody
would rotate in make that mechanic decorative. Not full either — standing on the board is where the
risk is.

**A recruit joins on the company's median** (`Experience.medianOf`). Level 1 is a reward the player
cannot take, and under a deadline they will never get the spare days to fix it; matching the best member
is a free ride that makes a late recruit strictly better than an early one.

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

## A day you do not want to give to a story

`models/request.lua`. A rolled board with no story attached, taken on behalf of a house you name, which
tags that house's stock on every cache and every fight's salvage. Without it the clock has one hand:
forty expeditions against ninety-two quests means constantly choosing which house to advance, and a day
you did not want to give to somebody's errand was a day you could not give to anything.

What it deliberately does not pay is most of the design — **no standing** (a house's standing drives its
shelf; paying it for foraging buys the catalogue without running a line), no quest ledger entry, no
relic, no companion, no discipline. 50 gold against the cheapest posted quest's 60, pinned against the
real minimum so the campaign can never become the inefficient way to earn.

Each house forages in its own country, fixed rather than rolled: the Bastion a forest, the Arcanum a
volcanic waste, the Lodge a swamp. Never the underworld. The rows do not appear on the last day.

> **This is the degenerate case of what was designed.** The intent was several requests on one
> expedition, with partial completion as the greed dial — *return any time to complete them all or only
> a few*. What exists is one request, one house, all-or-nothing. The multi-request version needs
> `params.houseMaterial` to become a LIST distributed across the caches a board already has (the board
> must not grow — `deriveDims` is content-sized), plus a per-request quota. Three requests against four
> or five caches is precisely the tension: you cannot fill them all without taking every cache,
> including the guarded ones at the ends of the deep spurs. Unbuilt.

## What survives from the old campaign, unchanged

These were settled before the clock and the clock did not disturb them. Kept short here; the reasoning
is in the code.

- **Stat growth is flat on purpose.** `models/growth.lua` proves linear growth against subtractive
  mitigation converges to a constant however it is tuned. Growth comes from gear, abilities,
  disciplines and roster — never from the curve. Do not go looking for a knob.
- **One bench, The Forge.** The only thing that raises an `item.level` and the only thing that spends
  materials. A vendor sells and buys back, nothing else.
- **Technique is earmarked.** Banked per house per character by playing that house's gear, spent at the
  Forge to buy depth. Gold buys breadth. *This is why a request run cannot pay technique* — the earmark
  ("ninja technique comes only from ninja play") is the entire justification for a second currency.
- **Materials tag where you went.** Craft stock by the item's own quality, house stock by the sponsoring
  house of the run — so running one house's line stocks the bench another house's gear will empty.
- **A level credits everything you cast.** `Growth.shares` apportions across every house cast since the
  last level, with per-stat remainders carried, so nothing is thrown away.
- **The disciplines are a complete lattice.** 21 crossings = C(7,2), every pair of houses. The shop's
  own section headers are the tree; a separate tree screen was cut and stays cut.

## Known debt

- **`docs/story.md` has not been re-read against the deadline.** The campaign now has a fixed span and
  an ending that fires on schedule with a variable final fight. Whether the story as written survives
  that framing is an authoring question nobody has asked yet, and it is the largest open item here.
- **The tuning is first-pass and wants play, not more measurement.** `Calendar.DAYS = 40`,
  `FINAL_DANGER = 22`, `Experience.STEP = 3`, `Player.CAMP_SHARE = 0.5`. The instruments exist; whether
  forty days *feels* like pressure or like a leash is the one question none of them answer.
- **The multi-request version of foraging is unbuilt** — see the note above. What ships is its
  one-request case.
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
