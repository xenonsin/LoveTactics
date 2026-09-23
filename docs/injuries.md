# Injuries

What a body carries after it has been carried off a floor. `models/injury.lua`, `data/injuries/`,
`tests/injury_spec.lua`.

The rule the whole system is priced against is [the count](the-count.md)'s:

> A cost on recovery is a tax on NEEDING to recover, and needing to recover is what being bad at the
> game looks like.

Everything below is an attempt to make a bad trip *cost* something without charging for it.

## It was a number, and now it is a name

Until 2026-09-22 an injury was a tally. Every body that fell took the same 15% off its health pool,
a damage debuff arrived at two, a movement cut at three, and the only thing that varied was how many.
One kind of harm, three rungs deep — so "she has been carried out twice" was the whole of what the
game could say about a member, and two companies three trips in were hurt in exactly the same way.

There are seven kinds now, and which one a fall deals is rolled:

| | takes | reserves | weight |
|---|---|---|---|
| **Blood Loss** | — | health 15% | 30 |
| **Shattered Leg** | movement −2 | health 6% | 15 |
| **Torn Shoulder** | damage −3 | health 6% | 15 |
| **Cracked Ribs** | defense −3 | health 6% | 15 |
| **Rattled** | skill −3, speed −1 | health 6% | 10 |
| **Burst Lung** | staminaRegen −1 | health 6%, stamina 20% | 8 |
| **Ruptured Font** | magicDamage −3 | health 6%, mana 25% | 7 |

The weights sum to 100, so each one reads as its own percentage. Nothing enforces that — the draw
normalises over whatever is in the folder — but keeping it true is what lets a reader price a change
by looking at it.

**Blood Loss is the old meter, kept whole.** It is the commonest roll and the only one with no badge,
and both of those are the same decision: the dark band on the party strip has to be the thing a player
expects, so that a Shattered Leg drawing no band reads as *this one is different* rather than as a bug.
It is also what the prologue deals by name — see **Teaching** below.

## The two halves, unchanged

Nothing downstream learned a new mechanism, which is why seven kinds cost about as much code as one.

**The reserve** sets aside a share of a pool that cannot be healed into, in the fight as well as out of
it. `Injury.stamp` writes `char.injuryShare` and `Combat.unreservedMax` reads it, exactly as
`char.maxBonus` is written by the grid pass — so combat never learns what an injury is, and a summon or
an enemy with no player behind it is untouched. It was one number applied to health; it is a table per
pool now, because two of the seven are about the other pools by construction.

`max` itself is never written. That is the whole reason this is a reservation rather than a penalty on
the ceiling: max health is derived from level, growth and gear, so an injury written into it would have
to be un-written exactly on the way out and would fight every recomputation in between. A body whose
*ceiling* drops reads as permanently diminished; a body with part of its pool sealed reads as hurt.

**The badges** are statuses stamped at spawn through the same seam a relic's opening boon uses
(`states/game.lua`'s `resolveOpening`). One per kind, authored in `data/status/`.

## Three rules that make stacking safe

Injuries **stack** — a body can break the same leg twice, and it bites again. Three things stop that
becoming a spiral.

**Every pool has a floor.** `Injury.FLOOR` caps the total reserve at 45% of any pool. Below about half,
a member is not a risk to field — they are simply not fieldable — and the injury stops being a cost the
player is choosing to carry and becomes one they are working around.

**Every stat has one too.** `Injury.STAT_FLOOR` is the same law for the badges, and it is what stacking
made necessary: the reserve always had a floor and the stat cuts did not, so six bad trips would have
read −12 movement and a body that cannot leave its tile. A cut can never take a stat below a quarter of
what the body's own blueprint says it is, and never below 1. Measured against the *character's* base
rather than its equipped total, deliberately — a floor that moved with gear would mean taking a shield
off could deepen an old injury.

The clamp is spent shallowest-first and **the badge shows what was actually taken**: two Shattered Legs
on a body with movement 4 read −3, not −4 with a silent correction somewhere downstream. A badge that
promises a number the body is not paying is the same defect as a damage breakdown that does not add up.

**Duplicates are one badge.** `Status.apply` refreshes rather than stacking instances, so nine effects
handed over would land as one −2 and the ledger would be lying. `Injury.combatEffects` sums them and
hands one over — which is also the honest readout: the player wants to know what their leg is worth
now, not that it was broken twice.

## Nothing in a fight lifts one

The count-based meter stamped `status_cripple` at three wounds — and Cripple is `debuff = true`, which
means `Status.cleanse` strips it. **One Cure lifted the campaign's entire attrition meter for the rest
of the fight**, and neither the ability nor the meter knew it was happening.

Every injury status is authored `debuff = false`. `tests/injury_spec.lua` asserts it over the whole
catalogue rather than over the one id that used to be wrong, because the next author to reach for a
convenient existing badge will reach for a cleansable one.

The second reason they carry their own names: a permanent condition and a two-turn debuff must not read
the same. A player who sees `Crp` has learned to wait it out.

## The roll is seeded

Which injury a body takes is a hash of the save's seed, the depth, who fell and how many they already
carry — never `math.random`. This is the same rule the floors keep: a floor's ground is dealt from the
seed and the depth alone, so floor three is the same floor three for the life of a playthrough. An
injury is the other thing a trip hands you.

A live roll would make save-scumming the optimal way to play a meter whose entire job is to make you
live with what happened, and it would make every spec that touches an injury a coin flip.

The count is in the mix, so a body carried out twice on one floor does not take the same injury twice
for free. Duplicates are still possible; what this stops is the degenerate case where they are certain.

**There is no `fits` gate.** A Ruptured Font can land on a fighter with five mana. That was asked and
denied at review, and what stands in its place is the rule that every kind reserves health as well as
whatever else it does — so no roll ever costs a body nothing, which would read as a bug rather than as
luck.

## Which bone comes off

Neither room that sets one asks. A camp's bind (`Injury.mend`) takes one off **every** body carrying
one; the Ward's press (`Injury.treat`) takes one off the body you pressed. Neither names the injury,
because a picker would turn a stop that is meant to be a weigh — bind, or heal, or sharpen, or study —
into a small optimisation puzzle about which of four bars to nudge.

So the answer is a **stated rule** instead: *a field dressing sets what a field dressing can set*. The
shallowest first, by `severity` (`Injury.sorted`). Rattled goes before Blood Loss. Both rooms keep it,
so the player learns it once.

The reading happens elsewhere: the body card (`ui/body_tooltip.lua`) names every injury with what it
is costing, and the deployment picker shows the count with the card on hover. Those are the two
surfaces a player is standing on when the question is *do I send this one*.

## What it costs to end one

`Injury.TREAT_COST` (40g) sets a bone now; `Injury.REST_DESCENTS` (2 trips per injury) sets it for
nothing. **Neither price moves with the kind.** Charging more for a Shattered Leg than for Blood Loss
would tax the worse luck, and the worse luck already cost the player the injury. Gold buys speed, never
recovery — which is the line the count's law draws, and the reason this is the third attempt at a Ward
and the first one that was legal.

## Two marks, two lessons

`player.injured` arms the bubble that teaches the dark band. `player.injuredBadge` arms the one that
teaches a badge the strip cannot draw. Two one-time flags need two ledgers: one flag read twice would
spend the second lesson on the first injury — which is Blood Loss by script, and has no badge.

**The prologue's scripted casualty takes Blood Loss by name, never a roll.** The coach bubble on the far
side of that fight points at the dark band on Rowan's bar; a rolled Shattered Leg draws no band, and the
one teaching moment the whole mechanic gets would be an arrow pointing at nothing. The roll starts on
floor one, where the second bubble is waiting for it. Both paths deal it — the played prologue
(`states/game.lua`'s objective branch) and the skip (`states/prologue.lua`).

## Adding an eighth

A file in `data/injuries/`, and a status in `data/status/` if it carries a badge. `tests/injury_spec.lua`
asserts the contract over the folder, so a blueprint missing a field fails there rather than at the bell:

- `name`, `description` — what the body card and the Notes print
- `severity` — where it sits in the shallowest-first order
- `weight` — its share of the roll (keep the set summing to 100)
- `reserve` — `{ stat = share }`, and **it must include health**, or the kind is free on some bodies
- `effects` — `{ { id = "status_..." } }`, and the status must be `debuff = false` with a lasting duration
