# Bounties

The goal, stated once: **you should always be going somewhere for something specific.**

A **bounty** is a posting of work the company holds and spends. It names four things and nothing else:

| | |
|---|---|
| the **ground** | which biome the expedition is fought on |
| the **tier** | how hard, and what grade the find is |
| the **boss** | one named body standing at the end of it |
| the **piece** | the specific thing that body gives up |

The fusion, said once: **Monster Hunter names what you go for. Path of Exile decides how you get in and
how hard you make it.** The piece is the first half; the augment is the second.

`models/bounty.lua` owns the object, `data/bounties/*.lua` the authored ones,
`ui/panels/bounty_board.lua` the board, and `tests/bounty_spec.lua` is what keeps the three honest.

## Why the piece is the whole point

Every offer in this game pays the same currency, so a failed expedition costs *an amount of gold* —
which is indistinguishable from succeeding slightly less well. `docs/overworld.md` has said so in its
Known Debt for a long time: *"the floor is N copies of one offer at different prices, and route choice
cannot really exist until two boons can differ in kind."*

A posting that names a piece makes a loss cost a **named thing**, and nothing else — the company comes
home with everything it walked in with. That is the law in [economy.md](economy.md) held intact: a cost
on *recovery* is a tax on needing to recover, but the thing you did not get is not a cost at all.

## What a loss costs

The bounty, the augments staked on it, the consumables burned and the piece. **Nothing permanent.**

Every unit of that is something the player chose to spend, which is the whole design. A company that
augments a hunt past what it can take has *misjudged* something rather than been *charged* for losing.

## Two shapes, and the plain one is the common case

- **Synthesized** — the posting names a ground, a boss and what it pays, and `Bounty.questFor` builds
  the map. No quest blueprint exists or is needed. Every derived rung is one of these, which is what
  makes a ladder a data row per rung rather than a writing job.
- **Authored** — the posting names a `quest`, and that blueprint's map, climb and scenes are used
  instead. The seven house openers are these: work written before the board was, with set-piece
  encounters and scenes on both ends.

`quest` is optional rather than required because there are **seven** surviving quest blueprints and a
seven-house ladder needs far more rungs than that.

## Two ledgers, and they answer different questions

| | |
|---|---|
| `player.bounties` | **how many** of each posting are in hand. Spent on taking one, win or lose. This is the bet, and it is what can run out. |
| `player.completedQuests` | whether a posting has **ever** been finished, under its `bounty:` id. This is the ladder, and it never un-happens. |

A company that finishes a rung and then runs out of the postings above it has not lost the rung.

### The standing offer is the floor

One posting per house is `standing`: always on the board, infinite, never spent. A company that burns
every deeper posting it holds can always walk back to a house and take its opener again, so **running
dry is a setback and never a lock-out.** Everything above tier 1 is *found*, not posted.

### Sustain

Finishing a posting deals `DROPS_MIN`–`DROPS_MAX` (1–2) more into your hand, from the same house, at
this rung or the one above it. Above one on purpose: a rate of exactly one makes the stock a treadmill
that never grows, and the decision this system exists to create is *how much of a growing pile to spend
on going deeper*. `models/mule.lua` said it first — **a bet with no ceiling is not a bet.**

Counted in the house's own **rungs**, not in raw tiers. A ladder reads 1 / 3 / 5, so a raw `tier + 1`
window found nothing above the opener at all and the stock could never leave the ground.

## The ladder is the gate

There are **no seals and no fragments to assemble.** Finishing a house's bounties is what opens its
later ones, exactly as finishing a rank of hunts opens the next.

> **This reversed in review, and the reasoning is worth keeping.** The first design had a general opened
> by assembling N seals dropped by that house's work — Path of Exile's fragment set. Monster Hunter has
> no fragments: the ladder *is* the gate. A seal was a second gate doing the ladder's job, buying
> nothing and costing an object to author.

`Descent.GATES` survives, re-aimed: `worth` — *"she will not fight beneath herself"* — is exactly a rank
gate.

### The seven ladders are derived

`Descent.SINS` already names, per sin, the house that owns it, the ground it is fought on, the
lieutenant that holds its middle and the general at the end; `Descent.DROPS` names what each of those
pays. That is a whole ladder per house, authored, sitting in a table the rift was the only reader of.

So each house is **one authored opener plus `DERIVED_PER_HOUSE` (2) derived rungs** — a lieutenant at
tier 3 and an apex at tier 5. Fourteen files differing only in four ids would be fourteen chances to
drift; a real file at the derived id always wins, so a house that wants a hand-written apex writes one.

## The piece, and then the part

A drop in this game is a **whole item**, so a second copy of a sword you own is worth nothing. That does
not merely make a repeat run pointless — it undercuts "a piece" as a target, because a posting you would
only ever take once is one the board may as well delete the moment you take it.

**Monster Hunter's parts are this game's materials, not its items:**

- **First kill** → the named piece, once. `Quest.complete` promotes it to the front of the payout and
  the panel draws that row in the spotlight gold, so the promise the board made is kept out loud.
- **Every kill after** → the house's **apex trophy**, which the Forge demands for the deep rungs
  (`Forge.TROPHY_RUNG` = 8 of 10) of that house's own gear.

A trophy is a **third family of stock**. It carries `house` — the vendor — rather than `class`, because
`Material.houseFor` indexes house stock *by class* and a second material claiming `knight` would alias
Salt Iron. `Material.isTrophy` is what tells them apart.

## The dial

The one genuinely new mechanic. Before a posting is taken, the company may stake materials on making it
worse; each augment adds a danger and raises what the ground pays. See `models/augment.lua`.

Every danger rides a seam that already existed, which is what keeps this from becoming a second parallel
difficulty system:

| Augment term | Rides |
|---|---|
| `levels` | `quest.floorLevel` |
| `fights` | `map.encounters` |
| `elites` | `params.eliteShare` |
| `guard` | the objective's own composition, wrapped |

**Paid in materials** — the stock the Forge spends — so making a run richer is priced against the
upgrade you were saving for. That is PoE's currency-into-map without importing PoE's currency economy.

**Spent when the posting is taken, not when it is cleared**, so a run that ends badly ends with the stake
gone. It rides in the run snapshot (`Save.snapshotRun`) because a resume rebuilds the descriptor from the
id alone — without that, quitting and reloading would hand back the same expedition with the dangers
removed and the materials already spent.

`MAX_STAKED` is 3. The ceiling is the point rather than a limit on generosity: with no cap the honest
play is to stake everything affordable every time, which turns a decision into arithmetic.

## The season decides which houses are posting

[data/biome_windows.lua](../data/biome_windows.lua) gates **standing offers only**. A posting already in
hand is always on the board whatever the season says — it was paid for, and a schedule that could make it
unspendable would be taking back a bet already placed.

The table was **re-cut** for this. It was authored against ninety-two quests distributed very unevenly
(thirty-five in the castle), and under seven houses it produced two defects that are the same defect:
`underworld` was open three days in forty, and three openers sat in the swamp so the count that actually
matters — **houses posting** — fell to two on day 28 while the ground count looked fine at three. The
invariant was guarding the wrong noun.

Each ground now takes one 24-day span, staggered and wrapped. Measured: never fewer than **three houses
posting**, never fewer than **four grounds open**. The season repeats rather than running out.

## Known debt

- **The prologue no longer describes the game.** Act 0 ends with Rowan sending the player to "The
  Rift" — a building that is deleted — and explaining the world as unpruned deep floors, which is the
  count's fiction and the count is parked. The hub's bubble on the far side of that scene already says
  "the Bounty Board". See [roadmap.md](roadmap.md)'s Phase 0; it is the first thing a new player sees
  and the third time this seam has gone stale.

- ~~The rift still stands beside the board.~~ **Done.** The Rift card is deleted, the plaza is back to
  two doors on a fresh save, and `states/gate.lua` is reachable from the title screen's debug column.
  `unlockDepth` became `unlockExpeditions` and reads `Player.expeditionsOut` — bounties finished or
  floors descended, whichever is larger — so a save made while the rift was the game still opens the
  city it had earned. `models/descent.lua` is parked rather than cut: `Descent.SINS` and
  `Descent.DROPS` are what the seven ladders are derived from.
- **The derived rungs carry no description.** The board draws the block only when there is one, so they
  read as complete — house, ground, level, body, piece — but fourteen postings want a line each from the
  author. They are deliberately unwritten rather than generated.
- **The seven apex trophy names want the author's eye.** The mechanism is settled and the register is
  copied from the seven house stocks beside them; the words were written by the pass that built the
  system.
- **Nothing rolls the drop count against a seeded generator.** `Bounty.dealDrops` takes a `roll` so a
  caller can pin it, and `Quest.complete` currently lets it default to `math.random`.
- **A posting that names no guard cannot be augmented on the guard axis.** The term is skipped rather
  than guessed at; the seven authored openers are the ones this affects.
