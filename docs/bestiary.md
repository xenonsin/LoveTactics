# The bestiary — factions, rungs, and the discipline ladder

Working plan for the enemy catalogue. Where [disciplines-plan.md](disciplines-plan.md) is the
authoring slate for *what the player can become*, this is the slate for *what they fight* — and the
two are the same bill paid once. The discipline exemplar that plan owes ~27 of **is** this document's
Elite rung; authoring an enemy catalogue separately would mean writing that roster twice.

Nothing here is a new system. The rungs already exist in the numbers, the AI already arrives with the
items, and the encounter layer already composes packs. What is missing is the **naming**, the **gaps**,
and the rule for which bodies carry a discipline at all.

## The ladder already in the data

Sort every blueprint in `data/characters/` by health and four bands fall out with almost nothing
between them. This was never designed; it emerged, and it is close enough to a ×2 curve per rung to
be worth ratifying rather than replacing.

| Rung | `tier` | Health | Damage | What it is |
|---|---|---|---|---|
| **Chaff** | 1 | 10–30 | 0–10 | One verb, dies to one blow. Fills a footprint, makes an AoE feel good. |
| **Line** | 2 | 38–70 | 12–16 | A real weapon and one ability. The body a fight is *made of*. |
| **Elite** | 3 | 84–115 | 16–22 | A signature relic and a rule list that reads. The discipline made flesh. |
| **Boss** | 4 | 155+ | — | `boss = true`, a phase trait, an `assassinate` mark. A quest's ending. |

The demons are the only faction that walks all four (Imp 14 → Grunt 74 → Champion 115 → Lord 420),
which is why they are the one faction that reads as an army rather than a spawn list. Every other
faction is missing at least one rung, and **chaff is the commonest hole** — the Forsworn, the pit
companies and the Undercroft all field a Line body as their cheapest unit, so there is nothing in
those fights to swat.

`tier` is a **declared label, not a multiplier.** Nothing derives stats from it. This codebase tunes
by hand and defends the number in the header — `character_demon_grunt.lua` spends twenty lines
explaining why its 74 health is the sum of five authored blows and moves only when one of them does.
A tier field
that generated stats would quietly break exactly those beats. What the label buys instead:
encounter compositions written as budgets rather than hardcoded lists, and a spec that fails the
build when a body drifts out of its band.

## The rule for chaff: bodies carry disciplines, creatures don't

The single split that keeps the catalogue from becoming a class list with hit points.

- **Bodied chaff — humans and humanoids — carry priced, lootable, shareable gear.** Usually one cheap
  item off their faction's shelf; at the Line rung, sometimes one item off the *discipline's* shelf.
  This is what makes a pack legible before it acts: you see what the beaters are carrying and you
  know what the thing leading them is.
- **Creature chaff — beasts, summons, constructs — carry natural weapons only.** Unpriced, `noSteal`,
  outside every family roster, and **never** a discipline item. A wolf is not a Beastmaster; a wolf is
  what a Beastmaster *has*.

The engine already enforces this economically and did so before the rule was written: 33 items carry
`noSteal`, and `models/spoils.lua` uses `price` as the shoppable marker, so an unpriced natural weapon
can never enter the drop pool. The rule above is a naming of existing practice, not a new constraint.

The consequence worth stating out loud: **a pack that mixes both kinds is the default shape, not a
special case.** Basic hunters led by a Trapper is the canonical example — the human beaters carry
snares and bows off the Lodge shelf and drop them; the hounds and hawks with them carry teeth and
drop nothing; the Trapper at the back is the Elite whose relic is the reason the fight is shaped the
way it is. Three body kinds, one composition, and only one of them had to be authored for this fight.

## What each rung costs to author

The factoring that keeps this from being 37 disciplines × 4 rungs = 111 blueprints.

**Chaff and Line are per-faction. Elite is per-discipline. Boss is per-quest.** A cutpurse is a
cutpurse; it does not need a subclass. Author roughly two bodies per faction at the bottom and reuse
them across every discipline that faction fields. Only the Elite rung carries an identity specific
enough to need one body per discipline — see the section below for why the Boss rung does not.

**The unit of authoring is the pack, not the body.** `data/encounters/` already expresses this —
`encounter_forsworn.lua` is a captain plus prestige-scaled knights, composed by a function over
context. So one discipline ships as *1 Boss + 1 Elite + faction chaff you did not write*, and the
composition demonstrates the mechanic before the exemplar takes a turn. The Necromancer's escort is
the dead she raised.

**The tactics are free.** `models/ai.lua` ranks rule sources, and rank 2 is the item itself: *"it
rides on the item, so handing an NPC a weapon hands it the tactics for that weapon too… content
authors give a bandit a bomb and it starts lobbing it at clusters, with nothing else to write."* A
discipline enemy is a body plus that discipline's shelf. Authored AI is for the Boss rung and the
occasional Elite, not for the catalogue.

Net: the marginal cost of the whole bestiary over the exemplar bill already owed is **~27 Elites and
about a dozen faction chaff bodies.**

## The Elite is the discipline. The Boss is the quest's conclusion.

**Settled**, and it is the decision that sizes everything else. Every discipline gets its own Elite —
that is where the demonstration lives, and 37 of them is the actual catalogue. The Boss rung is *not*
per-discipline; it is what a quest ends on, and quests are the thing that needs one.

The two do not line up one-to-one, and the quest data says so plainly. Of the 37 discipline gate
quests, only **12 already end on `assassinate`** — an objective that structurally requires a named
mark to cut down:

| Objective | Count | Disciplines |
|---|---|---|
| `assassinate` | 12 | Artificer, Champion, Duelist, Inquisitor, Ninja, Plague Knight, Poacher, Skirmisher, Spellbreaker, Vanguard, Warbrewer, Warlord |
| `killAll` | 15 | Apothecary, Assassin, Barbarian, Battlemage, Bombardier, Crusader, Druid, Herbalist, Monk, Necromancer, Paladin, Poisoner, Summoner, Thief, Trapper |
| `hold` | 5 | Beastmaster, Bulwark, Theurge, Totemist, Warden |
| `survive` | 3 | Elementalist, Exorcist, Shaman |
| `reach` | 2 | Saboteur, Sentinel |

So the boss bill is **12, not 37** — and the 25 remaining gates are not missing a boss, they are
objectives that deliberately have no mark. Some would be actively worsened by acquiring one:
`the_inner_circle`'s header says the Adepts are interchangeable *and that this is the point*, and
`held_position` is a `hold` because the fight is about the ground, not a man. Promoting one of those
to `assassinate` is a per-quest authoring call with a story cost, not a gap to be filled by default.

The line that makes this mechanical rather than taste: **a body carries `boss = true` if and only if
it is an `assassinate` mark.** The flag already means something specific in the engine — immune to
Coup de Grace, Charm and Polymorph, so the assassinate win is earned by fighting rather than skipped
by a finisher (`character_demon_champion.lua`). Outside an assassinate objective the flag protects
nothing and only removes verbs from the player's kit.

Across all 94 quests, `assassinate` is already the commonest objective (43), so the marks the wider
game needs outnumber the discipline gates by three to one. Bosses are cheapest when a **line** shares
one recurring antagonist across its ten slots rather than each slot minting a new body.

## The factions

Each vendor line's antagonists are the disciplines of that shelf — you fight the discipline, then you
are allowed to buy it, and the unlock quest is already in that line by construction
([disciplines-plan.md](disciplines-plan.md#L78) forces slot 3 or later). Each faction names its own
rungs; `tier` is the machine-readable spine underneath, so **compositions mix freely across factions**
without the names having to agree.

**E** = the body exists · **N** = needs authoring.

### The Host — demons

The complete one, and the model for the rest. No disciplines: demons have no shelf, and giving them
one would make the host read as a guild.

| Rung | Name | | |
|---|---|---|---|
| 1 | Imp · Bomblet | E | `character_demon_imp`, `character_demon_bomblet` |
| 2 | Grunt | E | `character_demon_grunt` — the sturdiest common enemy in the game, deliberately |
| 3 | Champion | E | `character_demon_champion` — three phases, all of it in the Sigil |
| 4 | The Hollow Crown | E | `character_demon_lord` |

### The Forsworn — Bastion (knight)

Disciplines: **Sentinel · Bulwark · Vanguard · Plague Knight**

| Rung | Name | | |
|---|---|---|---|
| 1 | Levy | N | the gap — a knightly company with no footmen |
| 2 | Forsworn Knight | E | `character_forsworn_knight` |
| 3 | Forsworn Captain | E | `character_forsworn_captain` |
| 4 | Oathbreaker | N | one recurring mark for the line, not one per discipline |

### The Pit — Colosseum (fighter)

Disciplines: **Barbarian · Warlord · Duelist · Skirmisher · Champion · Crusader · Battlemage · Warbrewer**

| Rung | Name | | |
|---|---|---|---|
| 1 | Hopeful | N | |
| 2 | Bladesworn | N | `character_bandit` stands in |
| 3 | Champion | E | `character_champion`, `character_ogre` |
| 4 | The Warlord | E | `character_warlord` |

### The Undercroft — rogue

Disciplines: **Thief · Assassin · Mammonite · Ninja · Inquisitor · Saboteur · Poacher**

| Rung | Name | | |
|---|---|---|---|
| 1 | Cutpurse | N | the gap |
| 2 | Bandit · Archer | E | `character_bandit`, `character_archer` |
| 3 | Bandit Chief | E | `character_bandit_chief` |
| 4 | — | N | one recurring mark for the line; `quest_undercroft_the_shadowless` and `quest_cathedral_the_confession` both want one |

### The Arcanum — mage

Disciplines: **Necromancer · Summoner · Elementalist · Spellbreaker · Shaman · Theurge**

| Rung | Name | | |
|---|---|---|---|
| 1 | Zombie · the elementals | E | creature rung — no discipline gear, by the rule above |
| 2 | Adept | E | `character_mage` stands in |
| 3 | Magister | N | per discipline |
| 4 | Archon | N | the inner circle's Necromancer is already named in her gate quest |

### The Cathedral — priest

Disciplines: **Monk · Exorcist · Inquisitor · Crusader · Paladin · Theurge · Totemist**

| Rung | Name | | |
|---|---|---|---|
| 1 | Penitent | N | the gap. `character_gaunt_vigil` was listed here and is not a body at all — its own header calls it "a standing object rather than a fighter", a ward a knight drives into the ground. It is `kind = "object"`, rung 0 |
| 2 | Sworn | E | `character_priest`, `character_bastion_sworn` |
| 3 | Confessor | N | per discipline |
| 4 | Luxuria, the Unbidden | E | `character_general_lust` |

### The Crucible — alchemist

Disciplines: **Poisoner · Bombardier · Artificer · Saboteur · Warbrewer · Herbalist · Apothecary**

| Rung | Name | | |
|---|---|---|---|
| 1 | Homunculus · Blightstake · Ordnance Sentry | E | creature/construct rung |
| 2 | Vat-hand | N | the gap — every body here is a construct |
| 3 | Vat-master | N | named in `the_vats` |
| 4 | Livia, the Unborn | E | `character_general_envy` |

### The Lodge and the wilds — hunter

The two-body-kind faction, and the one that proves the chaff rule. Disciplines: **Trapper · Druid ·
Beastmaster · Warden · Poacher · Herbalist**

| Rung | Bodied | | Creature | |
|---|---|---|---|---|
| 1 | Beater | N | Hawk · Raven | E |
| 2 | Hunter | N | Wolf · Boar | E |
| 3 | Trapper · Houndmaster | N | Alpha Wolf · Ancient Stag | E |
| 4 | Master of the Hunt | N | Wolfsong Spirit | E |

### The Greywatch — the faction that fights beside you

`character_grey_knight`, `character_greywatch_captain`, `character_greywatch_refuser`,
`character_siege_breaker`. Listed because they field bodies at rungs 2–3 and because both the Sentinel
and Bulwark exemplars are drawn from them as **mentors, not bosses**. A faction can hold a rung
without ever being an enemy, and the tier label should not imply hostility.

## Everything is shareable — and what that costs

The goal is that an item the player watches an enemy use is an item the player can eventually hold.
Three findings about how the engine currently handles that, in ascending order of how much work they
imply.

**1. The discipline gate is a purchase gate, not an equip gate — so this already works.**
`Discipline.isUnlocked` is consulted only inside `models/class.lua`, driving vendor stocking. It
never reaches equip. So a looted discipline item is usable the moment it drops, which is coherent
with the "anyone carries anything" core in [classes.md](classes.md): **the lattice gates reliable
supply, not access.** You can carry the Necromancer's reliquary off her corpse; you cannot *shop* for
one until you have earned the shelf. That is a better reward for beating her than a gold pile, and it
needs no engine change.

**2. "Shareable" literally means "give it a price."** `Spoils.lootCandidates` builds its pool from
every item with `price > 0` and no `bound` flag. Unpriced is the exclusion mechanism, and it is doing
three different jobs at once — natural weapons, bound relics, and quest items are all unpriced. When
authoring an Elite's kit, the default is **priced and unbound**; exceptions need a reason from the
list below.

**3. ~~The gap: spoils do not drop what the enemy was carrying.~~ Built.** Loot *was* a price-banded
random draw over all items in the game, with no connection to the roster that was beaten. That was
invisible while enemies carried interchangeable stock — nobody covets a bandit's iron sword — and the
bestiary would have made it visible everywhere at once, because the entire pitch of a discipline
Elite is *I want the thing he just used*.

`models/spoils.lua` now draws from the **carried pool**: the priced, unbound items in the beaten
roster's grids, one entry per item carried, so four bandits with iron swords make an iron sword four
times as likely. Three details worth keeping straight:

- **No price band applies to a carried drop.** Beat something wielding a relic and the relic is the
  reward. The band still governs the fallback.
- **`bound` is still honoured**, which is exactly what keeps a boss's phase machinery out of the
  player's hands (`utility_demon_sigil` and its `trait_boss_phases`) without a second exclusion list.
- **The fallback is not a legacy path.** A creature pack carries nothing priced by the rule above, so
  the band is the only thing standing between a wolf fight and paying nothing. `CARRIED_BIAS = 0.75`
  keeps a slice of the band even against loaded bodies, so consumables still restock from fights
  against people who weren't carrying any.

`tests/spoils_spec.lua` pins all three (carried drops dominate; an unpriced roster still pays; a
bound relic never drops).

### The exceptions, and the test for one

An item stays exclusive only where sharing it would be incoherent, not merely strong:

- **Body parts.** Natural weapons, claws, a beast's bite. Already handled: unpriced + `noSteal`.
- **Boss machinery.** The phase engine, not the effect it produces — `utility_demon_sigil` carries
  `trait_boss_phases` and is `bound`, and handing the player a three-stage phase machine is nonsense
  rather than a balance problem. Note the deliberately narrow scope: the Champion's *Heave* is a
  generic throw the player can carry, and its file says so.
- **A mechanic that is good enough to be worth an exception.** Left open on purpose. The bar: it must
  read better as *this creature's alone* than as a shelf item, and the file header has to say which.
  Everything else gets a price.

## The ratification pass

Step 2 of the build order, run over all 107 blueprints. It was scoped as a labelling pass — "no number
moves" — and it mostly was, but three of the things it turned up are worth more than the labels.

### Two declared fields, and why they had to be declared

- **`kind`** — `humanoid` · `beast` · `demon` · `undead` · `construct` · `elemental` · `object`. This
  existed already, but only as a *guess*: `tools/char_compose.lua` inferred it from words in the id, and
  its own fallback was "most portraitless enemies are people". Every wolf, boar, hawk and stag in the
  folder was therefore a humanoid as far as the code was concerned — which is the exact line the
  creature rule above is drawn along, so the rule could not have been checked at all. Declared, it costs
  one line per body and makes the rule mechanical.
- **`tier`** — 1 chaff · 2 line · 3 elite · 4 boss, and **0 for a body that is not on the ladder**: a
  prop, an escortee, or a shape worn by Wild Shape. Rung 0 is declared rather than left absent so that
  "this will never fight" and "nobody has labelled this" stay different states.

**The bands had to be widened to be checkable.** The table at the top of this document was read off a
sort of the folder and left real gaps between the rungs — nothing covered 31–37, 71–83 or 116–154, and
bodies live in all three. The spec's bands are contiguous instead (1–30 / 31–80 / 81–154 / 155+), so
every health value has exactly one legal rung and the assertion is a constraint rather than a band a
body can quietly fall between.

### `class` on an enemy is a growth declaration, not a label

The finding that changed the pass. The obvious tidy-up — every humanoid names the shelf it fights from —
turns out to be a balance change wearing a taxonomy change, because `class` is the growth table an enemy
climbs (`models/growth.lua`, `Growth.creditClass`). The tables say why:

| | health | damage | defense |
|---|---|---|---|
| knight | +6 | +1 | +2 |
| fighter *(`Growth.NEUTRAL_CLASS`, the classless fallback)* | +4 | +3 | — |
| rogue | +3 | +2 | — |
| hunter | +3 | +2 | — |

A rogue gains +2 damage a level against a knight's +2 defense. **They cancel exactly**, so a
rogue-classed body's post-mitigation damage never rises at all while its target gains +6 health a level.
Declaring `class = "rogue"` on `character_bandit` — true in the fiction, one line, obviously correct —
made a level-20 bandit unable to hurt an armoured party, which `tests/enemy_scaling_spec.lua` caught
immediately. Only the classless fighter fallback (+3) outpaces armour, and that is the sole reason
ordinary stock has been scaling: *every un-classed body in the folder has been growing as a fighter, and
none of them said so.*

So the shelf is declared **where something reads it** — on the bodies that name a `discipline` — and the
plain chaff keeps the fallback, with the reason written into `character_bandit.lua` rather than left for
the next person to rediscover. The seven sin generals stay classless for the same reason plus a second
one: they are outside the class system by design, and `tools/char_compose.lua` reserves a silhouette
bucket for exactly "a boss that is not one of the seven".

The open thread this leaves: **the rogue and hunter growth tables cannot carry a body whose offense is a
base weapon.** A player rogue compensates with abilities; an enemy holding one dagger does not. That is
a growth-table question, not a bestiary one, but the bestiary is where it surfaced.

### The Elite rung was the hole, and it was one line deep

Three bodies were carrying chaff kits at rungs that are supposed to be the demonstration:

| Body | Was | Now |
|---|---|---|
| **Bandit Chief** *(Undercroft elite)* | 105 health, one iron sword | a **Thief**: Shakedown, Sap, and the Cutpurse's Tally, which prices every blow by what has already been lifted off the target. He keeps the iron sword his men carry — there is no chief's blade on the rogue shelf, and what makes him the chief is the other hand |
| **The Breachward** *(the mark of the knight line's slot 1)* | 84 health and an **empty grid**, so it swung `weapon_unarmed` — the generic bare fist whose own flavour reads "it has never once been enough" | `weapon_stone_fists`, a natural weapon, per the creature rule |
| **Forsworn Captain** *(Forsworn elite)* | 98 health, mace and shield | a **Sentinel**. Her header already claimed Intercept word for word — "covers every adjacent ally" — and now carries it: Warden's Oath and The Lent Aegis |

No stat moved on any of the three. The Chief is also the case that answers the growth finding above: he
can afford to be a rogue precisely because his kit scales on *debuffs* rather than on raw damage.

### One rule from step 2 was NOT built, on purpose

The sketch asked for "`boss = true` appears only on a body some quest names as an `assassinate` mark."
It is not asserted, because the flag is already doing a second job the sketch did not account for: four
**companions** carry it (Clem, Amana, Gyeom, Ren) since they are recruited out of boss fights, and a
dozen Elites carry it at tier 3. `boss` and `tier 4` are not the same claim and the data says so. Pinning
the rule means first deciding what the flag means on a recruitable body — a separate call.

## Build order

1. ~~**The drop path**~~ **— done.** Character-sourced spoils, so beating a discipline pays out in
   its shelf. Built first because every rung below depends on loot meaning something.
2. ~~**Ratify the ladder.**~~ **— done.** All 107 bodies declare `tier` *and* `kind`, and
   `tests/bestiary_spec.lua` pins the rules. See "The ratification pass" below for what the labelling
   actually turned up, which was more than labels.
3. **Fill the chaff holes** — the Forsworn levy, the pit hopeful, the cutpurse, the vat-hand, the
   Lodge beater. Five bodies, cheap, and they make five factions read as armies. Do this before any
   Elite: an Elite with nothing to lead is just a stat block.
4. **The first seven Elites, ordered by the Engine column of
   [disciplines-plan.md](disciplines-plan.md#L180), not by faction.** Sentinel, Elementalist,
   Summoner, Monk, Exorcist, Poisoner, Apothecary are all marked ✓ — zero new combat code. Ship those,
   see whether "an Elite is a discipline made flesh" reads at the table, and only then commit to
   twenty-seven. This slice also does the runtime verification the discipline items have never had:
   [disciplines-plan.md](disciplines-plan.md#L386) concedes all 42 multiclass items pass structural
   tests but have "not been runtime-verified in an actual fight." Putting them on enemies is how they
   get fought.
5. **The remaining 30 Elites**, in faction order so each pack ships with its own chaff already
   standing. This is the exemplar bill, and at the Elite rung it costs a body rather than a body
   plus phase machinery.
6. **The 12 bosses**, for the gate quests that already end on `assassinate` — plus whichever of the
   other 25 gates get promoted, one story call at a time.

## Open calls

- **Enemy-first mechanics.** ~20 of 37 signature mechanics are marked ✗ (new engine work). The *enemy*
  half of Corpse-raise or Wildshape needs the combat path and an AI rule — not the shelf item, growth
  table, tooltip or Tactics-tab integration. Building the enemy first proves the mechanic on half the
  surface area and lands the player item on a system that has already been under fire. This inverts
  step 3 of disciplines-plan.md's build order, so it wants a decision rather than a default.
- ~~**Does the Boss rung need a body per discipline, or per faction?**~~ **Settled: Elite per
  discipline, Boss per quest conclusion.** See the section above.
- **Which of the 25 non-`assassinate` gate quests get promoted to a mark?** A per-quest story call.
  The ones to leave alone are the ones whose header already argues for facelessness.
- **Rung-1 loot pressure, now that drops come off the bodies.** Bodied chaff carrying shelf items is
  a gold faucet with extra steps — and the carried-drop path makes that sharper than it was, because
  what chaff carries is now what chaff pays. Either chaff carries cheap priced gear and the fight
  pays little because the gear is worth little (self-limiting, honest, and the drop pool stays
  connected to the fiction), or chaff carries unpriced kit and only the Line rung up actually pays.
  The first now looks better than it did when this was written as an open call.
