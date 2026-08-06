# Balance

How the game's two number scales are held against each other.

[docs/vulnerability.md](vulnerability.md) and `models/growth.lua` argue why mitigation is
**subtractive**. Neither says what the offense scale is supposed to be, and for most of this
project's life nothing did — which is how they drifted about 2× apart. This page is the missing
half: what the player is assumed to throw, what a body is allowed to subtract from it, and how many
swings that should come to.

Every rule here is enforced by [`tests/balance_spec.lua`](../tests/balance_spec.lua). The prose and
the assertion are meant to say the same thing; if they ever disagree, the assertion is the one that
ships.

## Why this exists

`Combat.mitigatedDamage` is the only damage formula in the game, and it is purely subtractive:

```
base   = weaponPower(forgeLevel) + attackStat + unarmedBonus + charmBonus
damage = base − defense − Σ(resist per tag) + vulnerability      (floored, see below)
```

Because it subtracts, **a weapon's power and a body's armour are quantities in the same unit** and
have to be authored against each other. They never were. Weapon power was written on a 4–6 scale,
innate defense on a 1–22 one, armour bonuses on a third. At level 1 the avatar swung 18 into 27
points of mitigation and dealt the floor — and the campaign's second line opened with a quest marked
`Easy` fielding a body that beat the protagonist on attack, on armour and on health at once.

No change to the formula repairs that. A strictly better statline is a **content** defect, and the
only fix is the numbers.

## The reference loadout

Balance is measured against one kit, named by blueprint id in `Balance.REFERENCE` so it moves when
the real thing moves:

- `character_avatar` — the one body every save has
- `weapon_iron_sword` — which [docs/weapons.md](weapons.md) already calls "the reference weapon the
  rest of the melee kit is tuned against"
- `armor_leather_armor`

Its **attack budget** at a given standing is its attack stat plus its weapon's power **as bought** —
`Balance.FORGE_BASELINE = 0`, gear straight off the shelf. Everything else in the system is measured
in that number.

### Forging is headroom, not a toll

**A piece of gear is balanced for the content it unlocks into, unforged.** Something the shelf opens
after slot 1 must carry slot 2 on its own; the bench is what puts a player *ahead* of the curve, not
what gets them level with it. Rule 7 below enforces this directly.

The first version of this measured at the forge *ceiling*, reasoning that the reference should be "a
player who has kept up". That quietly made the bench mandatory — a body could sit inside its band on
paper while anyone who had not visited the Forge faced a wall, and the verification run caught it:
an unforged avatar took 8 swings to fell a Grey Knight the band had passed at 5. Baking the bench
into the yardstick also hides the question of whether its materials are earnable, because the budget
assumes the answer.

The reference is also **grown into what it swings**. Growth is apportioned across whatever a
character casts, and the neutral fallback table (fighter) has no magic side at all — so a magic probe
grown neutrally has its `magicDamage` frozen at level 1 while every enemy's `magicDefense` climbs,
and the report claims the Arcanum's own Fireball cannot hurt a mage. Physical probes take the neutral
default; the magic probe grows as a mage. Growing 100% into the probe weapon's *own* class was tried
and rejected: a sword is knight stock, the knight table gives `+1` damage a level, and a reference
committed entirely to one house is a stronger claim than any real player makes.

## The four probes

A body is measured against four real weapons, not one: `weapon_iron_sword` (slash),
`weapon_iron_spear` (pierce), `weapon_iron_mace` (impact) and `weapon_wand` (magic). All are on a
gate-0 shelf for under 200 gold, so each is a tool the player can really be holding.

Four rather than one because **a body that walls slash and folds to impact is not unbalanced, it is
a puzzle**, and the two have to be distinguishable. A probe names a weapon rather than a tag list so
it prices its own budget honestly — an early version measured spell tags against the *sword's*
power, and reported that armoured knights were reachable by a spell the reference loadout cannot
cast.

**The bands are judged on the best MELEE probe.** Judging on the best of all four is too generous —
a knight that every sword, spear and mace floors against still passes if a wand can hurt it, which
is exactly how the reported bug hid. Judging on the reference weapon alone is too strict; carrying a
different blade is the point of having a weapon roster. The starting company is two melee bodies,
every house's gate-0 shelf is pinned to sell a melee weapon, and no companion who casts arrives
before slot 2 of a line — so "the best thing a melee company could bring" is the honest bar.

## Time to kill

Hits from **one** reference attacker to fell a body, keyed by the blueprint's own `tier`, which
[docs/bestiary.md](bestiary.md) already uses to mean exactly this:

| tier | role  | hits  | what it is                                   |
|------|-------|-------|----------------------------------------------|
| 0    | —     | —     | off the ladder: a prop, an escortee, a worn shape |
| 1    | chaff | 1–2   | one verb, dies to a blow or two              |
| 2    | line  | 2–4   | the rank the protagonist stands in           |
| 3    | elite | 4–8   | a fight's centrepiece                        |
| 4    | boss  | 6–14  | a quest's ending                             |

Snappy on purpose: a four-strong field is a handful of exchanges rather than an attrition sink, and
a mistake costs a body rather than a few percent.

Keyed by **tier and nothing else**. Per-quest bands would be 92 more numbers to drift, and would let
the same body be graded differently in two fights — making "is this body balanced" a question with
no single answer.

`tier` also binds a health band (`Balance.HEALTH_BANDS`, enforced by `tests/bestiary_spec.lua`), and
the rescale may never move a body out of the rung it declares.

## The rules

1. **No body walls every melee weapon in the game.** If the best of sword, spear and mace floors
   against it, a melee company cannot hurt it at all.
2. **No body of the player's own rank outclasses the player.** A tier ≤ 2 body may not beat the
   reference loadout on attack *and* armour *and* health. An elite or a boss doing so is what an
   elite *is* — those are held by the TTK band instead.
3. **Every body that is meant to fight can hurt the player back.** Walls, objects and support units
   are exempt and declare it themselves (`Balance.isNonCombatant`: no offensive statline, or
   `archetype = "support"`); a handful of conjured constructs are named waivers in the spec, each
   quoting its own blueprint's prose.
4. **Time to kill lands inside the band for the body's tier.**
5. **An `Easy` quest fields nothing the starting company cannot fight.**
6. **No single armour walls a weapon by itself.** One piece may take at most
   `Balance.ARMOR_SHARE` (40%) of the attack budget off one weapon — defense bonus *plus* every
   resist that weapon's tags match.
7. **A weapon bought at one gate carries the next gate's fights, unforged.** Measured on the house's
   best plain damaging item — weapons *and* abilities, because for half the houses the ability *is*
   the weapon (the Arcanum sells no blade better than a gate-0 wand until quest 10; what its player
   swings is Fire Bolt, then Fireball).
8. **An item's magnitude scales with the gate that opens it, within its family.** See below.
9. **The forge ceiling rises every quest** and reaches the top of the ladder before a line ends.
10. **Every quest at a house opens at least two shelf rows it can actually sell**, while that house
    still has stock to come. The final opening gate is exempt — a shelf that is finishing has nothing
    left to spread.

### On rule 10 — a trickle then a flood

One row per quest was the original bar and it is too low. It catches a gate that opens *nothing*, but
passes a house that dribbles a single row for three quests running and then drops five at once, which
reads to the player as the shop not moving at all. The Cathedral was doing exactly that at gates 2, 3
and 4; the Arcanum at 3 and 4; the Undercroft at 4, 7, 9 and 10.

Counting **plain** (non-discipline) rows on purpose: a gate whose only additions are discipline stock
opens nothing for a player who has not unlocked the discipline.

### On rule 8 — item power against its gate

A character's attack stat grows every level, so a magnitude authored flat across the campaign quietly
stops mattering. The audit measured that directly: damage was **~0.45 of the wielder's stat on the
opening shelf and ~0.20 on the last one**, so a 400-gold late weapon was a smaller step than a
60-gold early one.

Held **per family**, never across them, and each family's level is read off **its base weapon** —
`docs/weapons.md`'s own S1 rows, the iron kit plus the three caster bases that carry no metal in their
names (`Balance.FAMILY_BASE`). A base is a deliberate authored statement of what an archetype costs
and returns:

| | | | | |
|---|---|---|---|---|
| greatsword **2.00** | hammer **1.00** | longbow **0.83** | mace **0.67** | spear **0.50** |
| sword **0.50** | wand **0.42** | dagger **0.42** | axe **0.42** | bow **0.42** |
| ability **0.40** | censer **0.33** | staff **0.33** | | |

One share across all weapons proposed cutting the iron greatsword 24 → 5. A **median** over early
exemplars was tried next and is also wrong: eight of thirteen families have one or two priced early
members, and with an even count the median takes the lower — so a family's level became its weaker
member, and the solver proposed halving the greatsword again. The base is the level; a median is an
accident of how many of an archetype happen to be cheap.

Abilities keep a median: "the ability shelf" is not one thing the way "the axe" is, and it has 32
early exemplars to afford one.

**Riders are detected, not listed.** An item is *plain* only if it declares no rider field, does not
out-reach its family's base, and its effect does exactly one unqualified `fx.damage(fx.target)` and
nothing else. Anything else is selling something and is allowed to sit low.

That test is structural because every attempt at a keyword list under-reached, six times over —
`knockback` passed inside a closure, a chi multiplier whose stated damage is only a floor, an AoE loop
over everything standing in a hazard, a top-level `waitBehavior` read only on `activeAbility`, the
censer family's `incense` block, and finally `weapon_harriers_bow`, whose rider is not an effect at
all but **+1 range over the iron bow** ("under the iron bow: the freedom is the price"). Each miss
proposed buffing a weapon whose own header explains why its number is small. Enumerating what a rider
can be is a losing game; recognising what *plain* looks like is a short list of structural facts.

**The audit's result: zero items needed changing.** The declining raw share is real, but it is not a
defect — the catalogue was already selling effects rather than numbers at late gates. `weapon_quietus`
is a gate-6 dagger at 330 gold with power 5 because what it sells is a kill that cannot be revived;
`weapon_long_fall` is a 2-power mace because "a mace that displaced this far AND hit for a mace's
damage would simply be the best knight weapon in the game."

### On rule 6, and why the resist loop was left alone

`Combat.mitigatedDamage` sums resists across **every** tag on the blow, and essentially every
physical weapon carries both a family tag and `physical`. So an armour written as `slash 3,
physical 2` really subtracts 5 from a sword, and its author had no way to see that.

Changing the summing was considered and rejected: it would silently redefine what every existing
resist number in the game means. Instead the rule is stated on the **total, per probe** — layering
is still allowed, adding up to a wall is not.

### When a body is judged

At the **earliest standing it is met at**, once per blueprint. That is where the player has least to
answer it with, and fixing it there fixes every later appearance. Later appearances read easier on
purpose: `Growth.ENEMY_LEVEL_LAG` exists so the company pulls ahead of common stock, and a band that
fought that would be arguing with `models/growth.lua`.

"Standing" is **not** `requiredPrestige`, which only gates entry to a line — every quest of the
Bastion's ten carries the same 2. `Balance.prestigeFor` takes the deepest of that gate, the
transitive `requiredQuests` count (prestige is a flat count of quests finished, so a quest with
eleven behind it cannot be met below prestige twelve), and `Quest.floorLevelFor`'s SLOT_FLOOR
ladder. Getting this wrong measured a slot-10 general against a tutorial budget.

## The damage floor

A hit always lands **more than zero** — a scratch still triggers counters, feeds Rimebitten, wakes a
sleeper and advances a boss phase ([docs/vulnerability.md](vulnerability.md)). The floor is
`Combat.MIN_DAMAGE_SHARE` (15%) of the blow rather than a flat 1, so a greatsword that loses the
arithmetic still lands harder than a dagger that loses it by the same margin. The old behaviour is
this rule at a share of 0. `Status.immuneToDamage` still short-circuits to a true 0 first, which is
what keeps Immune and Resistant different things.

It is a **net, not a mechanism**. Rule 1 asserts nothing reference-grade needs it.

## The tools

```powershell
& "E:\LOVE\lovec.exe" . balance-report [full | sim [n]]   # measure
& "E:\LOVE\lovec.exe" . balance-rescale [N] [apply]       # correct
& "E:\LOVE\lovec.exe" . test balance                      # guard
```

`balance-report` leads with its failure sections — walled to steel, unhittable, dominates, harmless
— because the point is to be read at the top and acted on. Everything it prints comes out of
`Combat.mitigatedDamage` itself: `models/balance.lua` measures **through** the formula rather than
reimplementing it, so the report cannot disagree with the game, and a change to the floor lands in
the report for free.

`sim` drives real fights through `EncounterBattle` + `Autobattle`, but `EncounterBattle.eligible`
refuses anything with an `objective` or `allies` — which is most quest objectives, including the one
that prompted all this. It measures the easier half and is never the headline.

`balance-rescale` runs four passes in order — armour, toughness, attack cap, harmless mirror — dry
by default, one pass per `apply` (each is measured against the last one's result, and the data model
only loads at startup). It rewrites the literal in the blueprint's source, so comments survive, and
never writes Lua that does not parse.

**It is a tool, not an oracle.** It refuses to touch companions (their statlines are the player's,
even when fought once), tier-0 placeholders, `Balance.FROZEN` bodies whose numbers another file's
arithmetic is written against, and bodies whose low damage is authored intent — and when a body
cannot reach its band without leaving its declared health rung, it says
`OVER-ARMOURED: fix its loadout` and stops, because a loadout is a content decision. Pass 4 in
particular should be read, not applied: the first time it ran it proposed arming a scarecrow.

`Balance.FROZEN` exists because a spec waiver is not enough — it says "do not judge this", and the
rescale needed "do not *touch* this". The demon grunt was waived in the spec, invisible to the tool,
and quietly retuned from defense 4 to 1; the prologue's parry lesson is written against those exact
numbers and two tutorial tests failed.

### Does a run pay for the rung it opened?

`balance-report`'s FORGE ECONOMY section measures it, at the floor — one run's objective, one elite
and four road fights, counting no caches. One item keeps pace comfortably: **1 run per early rung,
3 at the top of the ladder**, against a house line of 12–14 quests. The bill grows with depth
(`t+1` craft, `ceil(t/2)` house) while the payout per run is flat, which is the right shape.

The real constraint is **breadth, not depth**: a run funds about two early rungs, so a company of
four carrying two forgeables each cannot be kept level across the board. That is a choice about who
gets the good gear, and is the intended shape of the decision.

In-battle, right-click a unit for **Damage table** (every weapon it holds against every foe on the
board, floored cells marked), **Forge +1**, and **Level up to…**.

## Known, and deliberately not fixed here

Several bodies fielded by name in quest compositions are **tier 0** — props and Wild Shape targets
whose statlines are placeholders nothing reads (`character_dire_bear` authors `health = 1` and says
so). Those fights really do spawn a one-health bear. `balance-report` names them rather than
rescaling them, because the fix is a content decision about what those encounters should field.
