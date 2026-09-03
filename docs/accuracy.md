# Accuracy

Combat is not deterministic. A blow may miss, and a blow that lands may be a critical.

This reverses a founding decision of the project, so the reversal is worth stating plainly rather
than leaving to be inferred from the code. A fight whose every number is knowable in advance has one
right answer, and a player who finds it has stopped making decisions — they are executing a solved
position. The dice are there to keep the board a place where you weigh things.

The model is **Fire Emblem's**, not Final Fantasy Tactics'. Both were considered; the difference that
decided it is below.

## The four numbers

```
Hit   = weapon hit + skill*2 + luck/2
Avoid = speed*2 + luck + terrain
hit%  = clamp(Hit - Avoid, 0, 100)

Crit  = weapon crit + skill/2
Dodge = luck
crit% = clamp(Crit - Dodge, 0, 100)
```

All of it lives in the ACCURACY section of [models/combat.lua](../models/combat.lua) —
`Combat.hitChance`, `Combat.critChance`, `Combat.avoid`, `Combat.trueHit`. A critical multiplies the
**post-mitigation** wound by `Combat.CRIT_MULTIPLIER` (3).

### The two new stats

`skill` and `luck` are authored per blueprint on a **0–10 band**. Fire Emblem's own run 0–20, against
a Speed that also runs 0–20; ours are scaled to sit beside `defense` (3–6) and `speed` (0–9) rather
than tower over the numbers they are subtracted from.

They reach `flatStat` exactly as `defense` does, so a charm granting `bonus = { luck = 2 }` and a
status draining skill both work with no plumbing of their own.

**Neither one grows.** This is deliberate and pinned by `tests/growth_spec.lua`. Accuracy is read as a
*difference* — hit% is Hit minus Avoid — and enemies scale with the player, so a skill table climbing
on both sides of that subtraction cancels exactly: the numbers would move every level and the hit
chance would not. Worse, they would not cancel forever, since even a tenth of a point per level leaves
a 0–10 band inside one career. So skill and luck are what a body **is**, not what it becomes. The same
argument `movement` has always been held still by, arriving at the same place from a different
direction.

### The roster

All 153 combatant blueprints author both stats. `tests/data_spec.lua` fails the build over any that
doesn't, which is what keeps `Character.ACCURACY_STATS` a safety net rather than a shortcut — a body
added next month that quietly shipped at 4/4 wouldn't be undescribed so much as mechanically
interchangeable with every other unauthored body.

The pass was made with `& "E:\LOVE\lovec.exe" . accuracy-author` (dry run by default), which derives a
starting point from the `class`, `kind`, `archetype` and `tier` each blueprint already declares, then
lets ~20 named bodies overrule it. It **skips anything already authored**, so hand tuning survives a
re-run and the derivation never competes with judgement.

| House | Skill | Luck | |
|---|---:|---:|---|
| `hunter` | 8 | 4 | the aiming house — the shot goes where it was sent |
| `rogue` | 7 | 7 | the crit house, and the only one high in both |
| `alchemist` | 6 | 3 | careful hands, no fortune |
| `mage` | 5 | 4 | |
| `fighter` | 5 | 3 | |
| `knight` | 4 | 2 | the wall doesn't dodge — it already bought survival with plate |
| `priest` | 4 | 6 | blessed, in the only sense the engine can express |

A body with no class reads off its `kind` instead: `beast` 3/5 (instinct, hard to pin), `undead` 2/0
(no technique, no fortune — the reliable thing to crit), `construct` 6/0 (machined, and nothing ever
goes unexpectedly well for it), `demon` 6/5, `elemental` 3/6 (nothing solid to aim at), `object` 0/0.
Archetype adjusts skill only (`skirmish` +1, `support`/`defensive`/`guard`/`holdGround` −1) — posture
is about where you stand, and fortune doesn't care where you stood. Tier moves it by rung.

**A derived body caps at 8.** The last two points of the band are reserved for bodies with names,
which is what makes the override table mean anything: before the cap, the generic Archer out-shot Kaya
and the generic Bandit Chief tied Kaen.

Two poles worth knowing, because they are the band's only 10s and each is its sin stating itself:
**Sublimitas, the Unequalled** is skill 10 — Pride's claim is not that she is strong but that nobody is
better — and **Aurea, the Ever-Owed** is luck 10, so fortune itself is Greed's domain and every
attacker gives up their crit against her. Pride's line then descends the one column: the general at
10, The Peerless at 9, Marginalia at 8, all of them low on luck.

Measured across the finished roster, Avoid runs **median 11** (p25 8, p75 14, max 20). Against a
typical Hit of 92–102 that is 81–91% shown on open ground, and 61–71% in forest.

### Weapons

Every weapon family declares a `hit` and a `crit` (`Item.FAMILY_HIT` / `Item.FAMILY_CRIT` in
[models/item.lua](../models/item.lua)) — daggers 95/10 down to hammers 65/0 — and **any individual
weapon overrides either** by declaring its own field. That is how a killer edge is built. The family
is the right grain because it is already the grain every other weapon promise is made at (see
[weapons.md](weapons.md)).

Crit is 0 for ten of the fifteen families, and that is what keeps `×3` safe: a weapon that crits is a
recognizable thing rather than ambient noise.

## Why Fire Emblem and not FFT

FFT's accuracy is **derived and directional**: a weapon attack has no attacker accuracy stat at all,
hit is essentially `100 − evade`, and evasion is quartered when you strike from behind. That single
rule is why FFT plays as a positioning game.

It needs unit facing, which this game does not have and would have had to grow — a field set on move
and on attack, drawn on the tile (the board sprites are one painted PNG per unit, so the art cannot
show it), hashed, saved, and read by the AI.

Fire Emblem has no facing. Its positional lever is **which tile you stand on**, and that is the trade
this project took: authored stats instead of a facing system, and terrain doing the work direction
would have done.

## Terrain is the positional decision

| Tile | Avoid | |
|---|---:|---|
| `forest` | +20 | Already soft cover for line of sight — the two readings finally agree |
| `mountain` | +30 | Already grants `range = 1`; costs 3 to enter and now pays twice |
| `rough` | +10 | Broken ground, a modest edge |
| `mire` | −10 | The one negative: slow **and** exposed, the mountain's exact inverse |

Authored in `Terrain.TYPES` ([models/terrain.lua](../models/terrain.lua)) and read through
`Combat.fieldBonus`, which already aggregated tile bonuses and field objects into one bag for the
mountain's range. So a placed field or a smoke cloud can grant cover later with no new code.

A forest tile is worth about as much as the gap between a good weapon and a bad one. That is the
calibration that makes ground a thing you spend a turn to reach.

## What moves them

Both stats are flat, so gear reaches them through `item.bonus` and statuses through `statBonus`,
exactly as `defense` does. No plumbing of their own — but that also meant that on the day accuracy
shipped, **nothing in the game could move either one**, and half the point of a hit chance is the
things that change it.

**Four statuses**, each taking the half that matches what it already was:

| Status | | |
|---|---|---|
| **Blessing** | `skill +4` | The offensive benediction raised the damage of a swing while saying nothing about whether it connected. |
| **Aegis** | `luck +4` | The defensive one. Luck raises Avoid and blunts a crit, which is what a ward is *for* — this is the game's luck buff rather than a fifth status beside it. |
| **Mark** | `luck −4` | "Painted for the kill" used to only eat armour, which made it, in its own file's words, "mechanically identical to Acid". Now it makes a body easier to hit *and* easier to crit. |
| **Blind** | `skill −6` | See below. |

Blind is the interesting one. Its header used to open by apologising: *"Range is per ability, not a
flat stat, so this can't ride `statBonus` the way Cripple's movement cut does."* The game's blinding
effect did not affect whether you hit anything — it shortened your reach, which is a different
disability wearing the same name. It now cuts skill **and keeps the range cut**, making it the
heaviest debuff in the game: the two halves land on different builds (range bites an archer, skill
bites everyone), which is what stops it being a debuff that only punishes bows.

**Drunk** also gained `skill −3` — swing harder, connect less, which is the trade its flavour always
described. It gives the Crucible a shelf that argues with itself: the same house sells the Wine that
costs you aim and the Mastery that sells it back.

**Nine utilities** carry a passive bonus, in the four houses the roster already made responsible for
accuracy:

| | Skill | | Luck |
|---|---|---|---|
| Hunter's Lodge | Marksman's Lens `+3`, Overwatch Scope `+3` | Cathedral | Untroubled Mind `+3`, Sealed Reliquary `+2` |
| Undercroft | Duelist's Poise `+2` | Undercroft | Opportunist's Charm `+3`, Skimmer's Cut `+2` |
| Arcanum | Careful Sigil `+2` | | |
| Crucible | Alchemic Mastery `+2` | | |

The Bastion and the Colosseum sell none, deliberately. The knight house is authored at luck 2 — the
lowest in the game — because the wall does not dodge and should not be paid for it twice; wrath is
the same argument pointed the other way. A lever every house sells is a tax, not a lever.

### Accuracy gear does not forge

Every one of those is a **plain number**, not a curve, and it cannot be otherwise. `Curve.ramp`
refuses a span under 10, so no legal ramping skill curve exists at any base — it would have to run
2 → 12 and leave the 0–10 band climbing. A shallow hand-written curve is the other way out and was
tried first; `tests/curve_spec.lua` refused it, correctly, because an item whose only magnitude holds
at eight of ten levels still charges the bench for all ten.

So what the forge sells is more of a number, and these numbers have nowhere to go. That is the honest
shape rather than a limitation worked around.

### Pricing them

`Grade.STAT_VALUE` gained both, and they are the only two entries in that table that were **derived
rather than judged** — one turn is 9.0 damage against the reference body, so:

```
skill  +2 Hit  -> +1.14% of a landed turn (after 2RN)
       +0.5 crit point x 2 extra multiples -> +1.00%     = 0.19  ->  0.2

luck   -1 Hit against you -> 0.57% less taken
       -1 crit point off every attacker x 2 -> 2.00%     = 0.23  ->  0.25
```

**Luck is worth more than skill**, structurally: skill adds *half* a crit point per point where luck
denies a *whole* one. Most of luck's value is in the crits that never happen to you, not the blows
that miss — which is why it reads as a defensive stat that quietly does something offensive-feeling.

Without those entries `Grade.statSwing` falls through to a generic `or 0.4`, and since `unlockQuests`
and `price` are derived from the grade, every accuracy item in the game would have been shelved by an
unconsidered fallback.

## True hit: the one place the game lies

The number on screen is the raw difference. The die behind it **averages two draws**
(`Combat.trueHit`), which is Fire Emblem's "2RN".

A single draw makes the displayed number honest and the game feel like it cheats: at a shown 75%, one
swing in four misses, and a player who watches two 75%s miss in a row concludes the number is
decoration. Averaging two bends the real odds toward what the number *claims* — a shown 75% lands
87.25%, a shown 30% lands 17.7%, and 50% is the fixed point. Plans that look good are reliable; plans
that look desperate feel desperate.

`Combat.landChance` returns the real probability in closed form. Anything that **weighs** an outcome
rather than reporting it wants that one — the enemy planner above all, which would otherwise
systematically over-value long shots in exactly the range where the player can watch it make bad
choices. Anything that **shows** a number to the player wants `Combat.hitChance`; the flattery only
works while the number on screen is the plain one.

## What never rolls

- **Heals, buffs, summons, movement.** Only a blow aimed at an unwilling body asks the dice.
- **Anything on your own side.** A staff never misses the ally it mends. Without this rule a heal
  would roll against the avoid your companion built to survive the enemy — the better the body, the
  worse your medic. It also makes friendly fire *harsher*: a blast that catches your own man catches
  him for certain.
- **Traps, hazards, burn ticks, collisions** — everything reaching `Combat.dealFlatDamage` with no
  attacker. The environment stays deterministic, which is what lets the route preview keep promising
  exactly what it draws when it walks a party into quicksand.
- **`alwaysHits`** — the escape hatch for a signature that must land.
- **Striking yourself.** A bomb under your own feet does not miss.

## A miss is a clean miss

Nothing lands. No damage, no on-hit status, no lifesteal, no counter provoked, no tally banked. The
swing still costs its resources and its place in the timeline.

Mechanically this rides the **existing voided-hit path**: a barrier, a per-type immunity and the Dodge
reflex have all returned 0 from around the same place since long before the dice existed, so every
downstream gate (`dealt > 0`) already handled a blow that drew no blood. The hit roll sits in
`Combat.dealDamage` immediately above `dealFlatDamage` — the last point at which nothing has happened
yet.

A signature gated on `hitDealt` is therefore now gated on landing the blow, which is what that tally's
name always said.

## Determinism, which did not go away

The battle's generator was already seeded per-fight and replays exactly (`Combat.newRandom`,
[models/seed.lua](../models/seed.lua)). Dice did not cost that. Three things protect it:

- **`combat.draws` is hashed state.** Every aimed blow spends two draws to decide whether it lands and
  a third if it did, so the generator's *position* is a fact two peers must agree about — and they can
  disagree about it while the board still looks identical. `models/state_hash.lua` carries the count,
  so a divergence is loud at the moment it happens instead of surfacing several turns later as a
  damage number that reads like bad luck.
- **A preview consumes no draws.** The dry-run effect context hands abilities
  `random = function() return 1 end`, and `hitChance` / `critChance` are pure reads. This matters more
  than it sounds: two peers watching one duel do not share a mouse, and a preview that rolled would
  let one player's idle hovering reroll the other's next swing. Pinned by
  `tests/determinism_spec.lua`.
- **`Netplay.VERSION` went to 3.** The stream is untouched but how much of it a fight *consumes*
  changed completely, so peers across the change are refused at the handshake rather than desyncing on
  the first turn.

Saves are unaffected — no save stores mid-battle state, so there was no `Save.VERSION` bump.

## `Combat.FORCE_HIT`, and why the suite needs it

With this flag set, nothing rolls: every aimed blow connects and nothing crits — exactly how the game
behaved before accuracy.

`tests/runner.lua` sets it before **every case in the suite**. The reason is that ~2,600 specs are
about what an ability *does* — Cleave carves a 3×1 arc, Shadow Strike blinks the caster home, a
hammer's stun rides the blow — and none of them is about whether the swing connected. Left to the dice
they would not test accuracy, they would merely *flake*: the same assertion passing and failing on
different days for a reason none of them mentions.

That pinning is also a trap, and `tests/accuracy_spec.lua` is the answer to it: without a spec that
turns the flag off, the entire system would sit outside the suite's reachable domain and every
assertion about it would be green for the wrong reason. That file clears the flag in each case, and
its last case proves the flag itself still works.

It is deliberately **not** a difficulty option. A player-facing "never miss" would make every number on
the character sheet mean something different, and the game would then owe two balance passes.

## What the player sees

- **Hit% and crit% on the action preview**, directly under the damage they qualify
  ([ui/action_preview.lua](../ui/action_preview.lua)). The hit row is tinted by how bad the gamble is
  — comfortable at 80+, amber below, red under 50 — so the panel answers "is this a good idea" before
  the number is read.
- **Neither row is drawn when it carries no information.** Hit is omitted at 100% (a heal, a
  self-cast, an ally, an `alwaysHits` signature); crit is omitted at 0. Their *absence* is the
  statement that the blow is sure.
- **A MISS float** on the struck tile in cool steel — nothing happened to that body, and the reds are
  reserved for things that did.
- **A crit floats in warm gold at the size a killing blow uses.** What a crit and a kill have in
  common is that both are rare and both decide something, so they share an emphasis; the colour is
  what keeps them apart. Red is what happened to the body, gold is what the dice did.
