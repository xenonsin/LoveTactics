# The Count

**The price on an expedition that ends with the floor unfinished.** One number on the descent run,
`models/descent.lua`, drawn on the Rift's own plate in the city. It climbs when the company comes back
up — by the stair or by dying — and falls when it goes deeper.

## What it is for

Every other event in the descent's loop is priced, and the table is now the whole of it:

| Event | What it is | What it costs |
|---|---|---|
| Healing | a need | nothing, and it stays that way |
| Setting a bone | a need | nothing, and it did not always — see below |
| **Climbing out** | **a decision** | **one mark** (`Descent.COUNT_STAIR`) |
| **A wipe** | **a failure** | **two marks** (`Descent.COUNT_WIPE`), and nothing else at all |

> **The third row used to break the law this page states, and so did the fourth.** Mending a wound was
> 120 gold at a counter; then a bed at the Inn, 60 a wound plus a day with the body out of the company.
> Both are a price on *needing to recover* — and a wipe wounds the whole expedition by construction, so
> the bill always landed on the company that had just lost. The Inn is deleted, the toll with it.
>
> **A wipe was the same error one row up, and much larger.** It took the haul as a guarded pack, three
> quarters of the run's forging stock, the whole run purse and a wound on every head — the most
> expensive line in the game, charged to the failure, in a document whose argument is that failures are
> not where you put the price. All of it is deleted: `Player.loseHaul`, `Descent.dropPack` and the pile
> system it fed, and the wound the rout inflicted (which the surface cleared for free a screen later
> anyway). **Losing takes nothing a company can carry.**

## Why a wipe still costs two

Because it has to cost *more than the stair*, and the reason is arithmetic rather than justice.

Both exits now leave the company holding exactly what it held. But a wipe happens **where the company
is standing**, and the stair has to be walked back to. Price them the same and dying is strictly the
cheaper way home — the optimal play becomes *loot until threatened, then throw the fight*. One extra
mark is the smallest thing that closes that, and it is paid on a clock rather than out of a pack.

It does bend this page's own law, and the bend is worth naming rather than hiding: one mark on a meter
most companies never approach is a different order of thing from haul + purse + wounds.

## What the rates measure, re-run with wipes in the tally

`COUNT_MAX` is 15. A new floor pays one mark off; a sealed circle pays `COUNT_SEAL` (2). Against the
stair at 1 and a wipe at 2:

| Play style | Per floor | Where it ends up |
|---|---|---|
| Pressing on | −1 | never leaves the lowest band |
| One withdrawal a floor | 0 | never leaves the lowest band either |
| Two a floor | 0 over a circle | the seals cancel it exactly |
| **Losing one floor in three** | **−⅓** | **still falls — a bad run is not a doomed one** |
| **Losing half its floors** | **0** | **break-even: the ceiling is never reached, but never recedes** |
| **Losing every floor** | **+1** | **the breach, in fifteen floors** |
| Shuttling (7 a floor) | +6 | full on floor three |

**The break-even is losing half your floors**, which is the number to watch. Below it the tally falls
whatever else the company does; above it, it climbs. That is a defensible line — a company losing more
than half its fights is a failing campaign and the Crown coming up the stair is the right ending for one
— but it does mean the player most likely to meet the breach is now the one having the worst time.
Combine it with a withdrawal a floor and a third of floors lost and the tally climbs at ⅔ a floor.

**If that reads badly in play, the dial is `COUNT_MAX`, not `COUNT_WIPE`.** Lowering the wipe to one
mark re-opens the suicide exit above; raising the ceiling costs nothing but patience.

## The count is now carrying the pacing alone

Worth saying out loud, because it was one of four pressures and is now the only one. A descent used to
be bounded in three other ways: a carry cap (the mule held 8-20 slots and had to be sent home), a
dropped pack on a wipe, and a purse that evaporated at every exit. All three are deleted. There is no
ceiling on a haul, no floor under a loss, and no coin that expires.

That is deliberate -- looting should feel unconstrained, and the mule was a bet-bounder for a bet
nobody collects on any more. But `models/mule.lua` was written around a sentence worth keeping in
view:

> nothing capped what could go INTO it, so the honest play was to hoover up every chest on every
> floor and carry an unbounded sack into the next fight. **A bet with no ceiling is not a bet.**

That play is back by construction. What is left holding the shape of a campaign is this number, so
the next pass over the descent should treat it as load-bearing rather than incidental.

## The fiction, which was already written

Iselle, in the first conversation of the game
(`data/conversations/prologue/conversation_prologue_sponsor.lua`):

> Nothing down there is born. It forms. That is the other half of the trade, and the Crown pays by the
> floor to keep the count down. We call it pruning.
>
> So the deep floors go unpruned. Then the count climbs, and what is down there comes up the stair and
> out into the country.
>
> Bellmere, four nights ago. That did not come over the hills, it came up out of this ground.

The number *is* that count, and the worked example is the fight the player has already fought. Nothing
new had to be invented; one line had to be repaired. It used to read *"They breed"*, which is untrue —
demons and monsters materialise out of the Demon Lord's power.

**"Pruning" survived that correction on purpose.** It is a gardening word for something that does not
grow, which is exactly right as trade slang: Iselle runs a digging house, from the outside an
infestation that comes back looks like something that grows back, and her line already frames it as a
nickname rather than a description. The wrong word costs nothing and pays off at the bottom of the hole.

## The three seams

```
climbing out        +1   Descent.climbOut    -- states/game.lua's ascent branch, the only caller
reaching a floor    -1   Descent.advance     -- the one place a floor number rises
sealing a circle    -2   Descent.clearFloor  -- inside the existing once-only general-floor guard
```

Floored at nought and capped at `Descent.COUNT_MAX`. The floor matters: a company that sealed everything
would otherwise bank a credit against withdrawals it has not made, and *"I may now come up eleven times
for free"* is a purse, not a pacing rule.

The payback rides `Descent.advance` rather than `game.enter` because that is the one function a floor
number rises in — so every way down pays back exactly once (the landing's stair, and a floor that gives
way), and **re-entering a floor the company climbed out of pays nothing**, because the number does not
move. The walk back to where they were is correctly worth zero.

A WIPE REACHES IT NOW. `Descent.climbOut` had one call site and the loss path deliberately was not it,
because a wipe already cost the haul, the purse and a wound on every head. It costs none of those any
more, so the exemption inverted: the rout charges `Descent.COUNT_WIPE` directly, and the count means an
expedition that ended with the floor unfinished — one meaning covering both exits, rather than a rule
with a carve-out for the worse way of doing it.

### What it produces

A full descent pays back 28 on its own — fourteen floors stepped onto, seven circles sealed.

The full table, wipes included, is at the top of this page under "What the rates measure". In brief:
one withdrawal a floor nets zero, two a floor is cancelled by the seals, three fills near the top by
the bottom of the rift, and seven is full on floor three.

`tests/count_spec.lua` pins these, measured at the worst moment of each floor rather than after the stair
has paid it back — a peak read post-descent flatters every play style equally and proves nothing.

**These ratios are provisional and are meant to be measured.** `COUNT_MAX = 15` is derived from a floor's
stop count, not from a played descent. It was 25, which was too slack — a full descent pays back 28 on
its own, so even a careless company finished around half full and the city never went dark on anybody.

**What the maximum does not do** is worth knowing before it is moved again: it does not touch the careful
player at all. One withdrawal a floor nets zero against the stair's own payback, and two a floor is
cancelled exactly by the seals, so both sit at nought whatever the ceiling is. The maximum decides how
fast the *careless* fill. If ordinary play should feel this, the dial is `COUNT_SEAL` (−2 → −1), not
`COUNT_MAX`.

## The readout

`ui/count_meter.lua`, one widget with three callers, so the player learns to read it once: the Rift card
in the plaza, the Rift screen's right-hand column under the purse, and the Way Up card underground.

**Marks rather than a bar.** The thing being shown is an integer that moves one step at a time; a
continuous fill would claim a continuous quantity and hide the step. Fifteen marks grouped in fives
are countable at a glance, and the whole budget is legible the first time it is seen. No numeral — the
fives carry the count, and a figure beside them says the same thing twice on a plate that also holds a
building's name.

**The Way Up card is the exception**, and takes the transition form — `11 → 12 of 15` — because there the
player is being told what a move they have not made yet would do. It sits on the panel's *prompt* rather
than on the option's description: `ui/panels/choice.lua` grows its box to fit a wrapped prompt and holds
every option card at a fixed 70px, so a third description line spills over the card below it.

**The change gets a beat.** The mark that just filled rises into the row from below over a quarter of a
second while the ones already lit sit still — vertical arrival into a horizontal row, so it reads as an
addition rather than a fill. Once, on the first draw after the number moved, never looping.

### Nothing before the first climb-out

The readout is hidden until the player takes the ascent stair for the first time. Not a threshold on the
number — their own act, which is the moment it becomes about something they did. Once revealed it stays,
even at nought, which is `Wound.everWounded`'s pattern and the Inn's own argument: the mark rather than
the ledger, or the readout comes off the plaza the morning after it was earned.

Two one-way marks, and they are deliberately not one:

- `player.climbedOut` — set the instant the stair is taken, because the marks have to be on screen while
  Iselle points at them. Gates the readout and the Way Up transition.
- `player.tallyTaught` — set when her scene has finished. Gates the scene, and survives a player quitting
  in the middle of it, which a flag passed through the state switch would not.

### The bands

| Band | Range | Marks | Text | The city |
|---|---|---|---|---|
| Low | 1–5 | green | — | unchanged |
| Climbing | 6–10 | yellow | — | the lamps begin to go out |
| Unpruned | 11–14 | orange | **Breach imminent** | darker still |
| — | 15 | red | **It is on the stair** | darkest |

**The row is a ladder, coloured per mark rather than per reading.** Mark *i* wears the colour of the band
a count of *i* falls into, so the meter has a fixed geography a player can learn: you can see the orange
marks waiting two groups along before lighting any of them. A meter that restained its whole row on each
band change would say *"it is bad now"* and never *"it is about to be"*.

The bands sit on 6 and 11 rather than on arithmetic thirds because the marks are drawn in fives, and a
boundary falling inside a group renders as four green and one yellow sitting together — which reads as an
off-by-one, not as a ladder. Measured on screen. At 6/11 the first group is wholly green, the second
wholly yellow, and the last is orange with a single red cap on the ceiling mark.

No new hues: three of the four come from `ui/colors.lua`'s enamel families (verdigris, bronze, ember) and
the middle step is the chrome's own `accentWeapon`. Green is the game's ally/heal colour and is
unambiguous here because this meter never draws on the board — on a city card it reads as the universal
"nothing to do here", which is what a low tally is.

**Most bands say nothing, and that is the point of a meter.** The marks already state where the tally
stands; a line of prose under them restating it in words is the same fact twice, and a card that always
carries a sentence has no way to raise its voice when it needs to. So the bottom two bands are marks
alone and the warning is the only text this readout ever draws — appearing two thirds of the way up,
where the number stops being bookkeeping, so that **its arrival is the signal**.

The top two **used to** share one string, on the argument that "Breach imminent" is as true at the ceiling
as one below it and that what a full tally ought to say differently is the ending firing — which was not
built, and a second string invented early is a promise to keep later. It is built (see **The breach**
below), so the promise is kept: the ceiling names the event and the band under it goes on warning, which
is the ladder doing its job. The orange band is the last morning on which the stair is still a way home.

The row of marks sits at the same y whether or not the warning is above it. A meter that slid up when
its text went away would be a readout that changes place, and the player would be re-finding it every
time the number crossed a band instead of reading it.

Spaced off `COUNT_MAX` in thirds, and `tests/count_spec.lua` pins that the top band begins exactly at the
maximum and that every band is reachable — dropping the ceiling without re-spacing these leaves three
bands nobody can reach, which is invisible in play and obvious in a spec.

Three of the four are legibility and nothing else. The city dims through a flat darkening laid over the
painted plaza (`CountMeter.CITY_DIM`), which is the cheapest true version of "the place is worse than it
was" and needs no per-building state; boarded windows and a thinner queue at the markets are the same
idea done properly, and they are art rather than code.

## The breach

**At the maximum the stair stops being an exit.** Take it and what is down there comes up with you, with
every general still unsealed beside it. `Descent.isBreached` is the one question that asks, and
`states/game.lua`'s ascent branch is where it is answered.

**It is the same tile and the same card.** The player walks back to the way up they have always walked
back to and presses it the way they always have; what changed is the answer. A screen of its own would
announce the breach before the tile did, and a marker on the map would let it be avoided — the whole
point is that the way out is what filled up.

**Who comes up** is `Descent.breachComposition`: the Hollow Crown, one general per unsealed circle, and a
horde of champions behind them that thickens with depth. Sized by what the player did, through the same
reading the retired day-forty finale was sized by (`Calendar.generalsStanding`) — seven standing is a
wall, none standing is a duel, and the only thing that shortens the list is having gone down and sealed
circles. The named bodies are listed first because `Arena.clampComposition` keeps one of every distinct id
ahead of repeated filler and yields outright when the distinct cast exceeds the ceiling: the generals
cannot be trimmed off by an arena cap, and the champions behind them are exactly what a cap is for.

**Winning it is winning the game.** It is the Crown, met three floors up in a corridor rather than on its
own ground, so it ends where the bottom ends — `Player.finishCampaign`, the run cleared, the credits with
New Game+ offered. Two roads, one ending.

**Losing it is a wipe**, with no special case at all: the company wakes at the Gate holding everything it
was holding, two further marks on a tally that was already full. That is what makes the breach a state
to fight out of rather than a game over — and the way out is down. Every new floor prunes a mark and every
circle sealed prunes two, so a company that walked itself into the ceiling can always walk itself back
under it. `tests/breach_spec.lua` pins that, along with the one thing the failure route could silently
skip: the way-up tile is borrowed for the length of the fight, and **both** exits hand it back, because
the losing one is the one that snapshots the floor into the company's map book.

### This is what replaced the deadline

The campaign used to end on a date. Forty days, bought one expedition at a time off a Quest Board, with
the demon lord landing on the fortieth and every unfelled general standing beside him. The board was
retired and the descent became the campaign; a clock that counted expeditions had nothing left to count,
and `models/calendar.lua` says what the day is now (a real unit — nights pass, wounds mend by them — with
no ceiling on it).

The ending it was pointing at did not need the date. This is the same fight, reached by what the company
did instead of by what the calendar said, which is also the harder thing to arrive at by accident.

## What is not built

**Fog decay**, held in reserve: cleared stops stay cleared, but fog closes over ground the company had not
reached while it was away. It prices the trip in the trip, which is what the ascent tile always intended.
Second lever — pulling both at once means learning nothing from either.
