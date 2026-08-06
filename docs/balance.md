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

Its **attack budget** at a given standing is its attack stat plus its weapon's power at the forge
level a player of that standing could have reached. Everything else in the system is measured in
that number.

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
7. **The forge ceiling rises every quest** and reaches the top of the ladder before a line ends.
8. **Every quest at a house opens at least one shelf row it can actually sell.**

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
even when fought once), tier-0 placeholders, and bodies whose low damage is authored intent — and
when a body cannot reach its band without leaving its declared health rung, it says
`OVER-ARMOURED: fix its loadout` and stops, because a loadout is a content decision. Pass 4 in
particular should be read, not applied: the first time it ran it proposed arming a scarecrow.

In-battle, right-click a unit for **Damage table** (every weapon it holds against every foe on the
board, floored cells marked), **Forge +1**, and **Level up to…**.

## Known, and deliberately not fixed here

Several bodies fielded by name in quest compositions are **tier 0** — props and Wild Shape targets
whose statlines are placeholders nothing reads (`character_dire_bear` authors `health = 1` and says
so). Those fights really do spawn a one-health bear. `balance-report` names them rather than
rescaling them, because the fix is a content decision about what those encounters should field.
