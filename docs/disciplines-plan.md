# Disciplines — the exemplar slate

Working plan for building out the discipline system. The *contract* (blueprint format, the
shop-taxonomy rule) lives in [classes.md](classes.md#L237); this file is the **authoring slate**:
who each discipline's exemplar is, how you meet them, and which quest opens the shelf.

The system, all 37 blueprints, all 42 multiclass items and all 37 gate quests are built. What is not
is the **exemplar roster** — ~27 NPCs still standing in from the existing cast — plus the mechanics
still flagged ✗ below. This is the map, ordered so the rest can be walked one discipline at a time.

## The model (settled)

Two decisions shape everything below:

1. **Earned advancement (RO-inspired lattice).** A subclass is gated by one quest in its parent
   vendor's line. A **multiclass** is gated by first holding *one subclass from each parent* — that
   state opens a **capstone quest**, and clearing it unlocks the shelf. You cannot be sent to meet the
   ninja until you have already walked both a rogue branch and a mage branch. The tree enforces its own
   growth order: a multiclass whose parents have no subclass yet is unauthorable (dead gate).

2. **Every discipline has an exemplar NPC** — a character built *as* that discipline (their kit **is**
   its items), encountered in its unlock quest. You don't read that Ninja fuses two shelves; you watch
   Kaen do it, then get to build it. Disposition **varies per discipline** (boss / mentor / recruit),
   chosen to fit the story. Exemplars **reuse the roster where a character already embodies the thing**,
   and are authored fresh only for the gaps.

Blueprint gains one field:

```lua
return {
  name    = "Ninja",
  classes = { "rogue", "mage" },     -- 2 parents = multiclass
  exemplar = "character_kaen",       -- the ninja you first meet
  requiredQuests = { "the_shadowless" },        -- offered only once both parents have a subclass
}
```

## System status — built and green

The discipline **system** is implemented and passes `tests/discipline_spec.lua`. What remains is
*content*: the exemplar characters, the capstone quests, and the item rosters below.

- **Loader** — `models/discipline.lua` loads `data/disciplines/`; all 37 blueprints exist (16 subclasses
  + 21 multiclasses).
- **Growth tallies both parents** — using a discipline item records a cast for *every* parent class
  (`Combat.useItem` → `Discipline.growthClasses`), so a Ninja weapon grows both rogue *and* mage.
- **Tooltip** — an item's discipline shows in `ui/item_tooltip.lua`.
- **Vendor gating** — a discipline item is stocked on each parent shelf but stays locked (greyed) until
  `Discipline.isUnlocked` (its quests done; for a multiclass, a subclass of each parent already held).
- **Tagging invariant** — an item's `class` must be one of its discipline's parents. Enforced.

## The roots: base-class exemplars

The seven companions already are one exemplar per shelf. They are the tree's roots, not disciplines —
listed so the branches have something to branch *from*.

| Class | Companion | Character |
|---|---|---|
| fighter | Saber | `character_saber` |
| knight | Rowan | `character_knight` |
| rogue | Clem | `character_clem` |
| hunter | Kaya | `character_kaya` |
| mage | Gyeom | `character_mage` (Gyeom) |
| priest | Amana | `character_amana` |
| alchemist | Ren | `character_ren` |

## The subclasses (16)

Gate quests are the existing ones assigned in the last pass (one per discipline, no reuse). **E** =
exemplar already exists in the roster; **N** = needs a new character blueprint.

| Discipline | Parent | Exemplar | | Disposition | Gate quest |
|---|---|---|---|---|---|
| **Barbarian** | fighter | arena berserker | N | boss | `blood_in_the_sand` |
| **Warlord** | fighter | The Warlord (`character_warlord`) | E | boss | `warlord_keep` |
| **Sentinel** | knight | Knight in Grey (`character_grey_knight`) | E | mentor | `relief_column` |
| **Bulwark** | knight | Road-Captain (`character_greywatch_captain`) | E | mentor / ally | `held_position` |
| **Assassin** | rogue | a killer sent for you | N | boss | `accounts_settled` |
| **Thief** | rogue | a guild fence | N | recruit / mentor | `vault_heist` |
| **Druid** | hunter | a wild shapeshifter | N | mentor | `the_guide` |
| **Beastmaster** | hunter | Kaya (`character_kaya`)* | E | recruit | `sacred_stag` |
| **Trapper** | hunter | a woodland ambusher | N | boss | `the_silent_wood` |
| **Elementalist** | mage | Gyeom (`character_mage`)* | E | mentor | `grimoire_ruins` |
| **Summoner** | mage | a conjurer with an elemental court | N | boss | `donor_roll` |
| **Necromancer** | mage | a radical of the Arcanum | N | boss | `arcanum_the_radical` |
| **Monk** | priest | a fist-and-litany ascetic | N | mentor | `haunted_mill` |
| **Exorcist** | priest | Amana (`character_amana`)* | E | mentor / ally | `fallen_confessor` |
| **Poisoner** | alchemist | a vat-master | N | boss | `the_vats` |
| **Bombardier** | alchemist | a counterfeit-bomb runner | N | boss | `crucible_the_counterfeiter` |

\* Reusing a *companion* as a discipline exemplar changes the beat: the "first meet" is with someone
already in your party, so the unlock quest becomes a **companion quest** deepening them (Kaya learns to
call the pack; Amana learns to banish). Flagged as a choice, not baked — swap for a fresh NPC if you'd
rather keep companions as roots only. **10 new subclass NPCs** if the three starred reuses stand; 13 if
they don't.

## The multiclasses (21)

Each needs its two parent subclasses first (the "needs" column names the *parent classes* — any
subclass of each satisfies the gate), then a **capstone quest** that stages the exemplar.

**All 21 capstones are now on disk** and the table below names the real file for each. Until they
were, every multiclass was permanently locked rather than merely unbuilt: `Player.hasCompleted`
returns false for an id nothing defines, so `Discipline.isUnlocked` could never return true and all
42 multiclass items were unreachable stock. `tests/discipline_spec.lua` now fails the build if a gate
names a missing quest.

Each is a first pass — premise, objective and gates, with the fight staged around the discipline's
signature mechanic so the exemplar is a live demo rather than a paragraph. What they do **not** carry:
scenes (no conversation is authored, and `Conversation.play` asserts on an unknown id), `rewardItems`
(a discipline's payload is its shelf, which unlocking opens at both parent vendors — the quest is the
key, never the prize), and `rewardCharacter` for the recruit-disposition ones, which need their
exemplar's blueprint first. ~17 exemplars are still stand-ins from the existing roster, each called
out by name in its quest's header.

One thing the capstones deliberately do *not* encode: the both-parents rule. `Discipline.isUnlocked`
walks the parents itself, and a quest can only gate on prestige, sponsor standing and a list of
specific quest ids — there is no way to write "any fighter subclass and any knight subclass," and
naming two particular ones would lock out a player who took the other pair. So the quests are open on
standing and the *discipline* stays shut until the parents are real. Clearing a capstone early is
harmless. A quest-level gate that could express it would be new engine work.

| Discipline | Parents | Exemplar | | Disposition | Capstone quest (all written) |
|---|---|---|---|---|---|
| **Champion** | fighter × knight | Champion (`character_champion`) | E | boss | `champions_challenge` — The Champion's Challenge |
| **Duelist** | fighter × rogue | a swaggering blade-for-hire | N | recruit | `the_tavern_duel` — The Tavern Duel |
| **Skirmisher** | fighter × hunter | a raider outrider | N | boss | `the_running_fight` — The Running Fight |
| **Battlemage** | fighter × mage | a spell-and-steel veteran | N | boss | `the_broken_siege` — The Broken Siege |
| **Crusader** | fighter × priest | a holy-blade zealot | N | mentor / boss | `the_consecrated_march` — The Consecrated March |
| **Warbrewer** | fighter × alchemist | a berserker-draught brawler | N | boss | `the_fighting_cellar` — The Fighting Cellar |
| **Vanguard** | knight × rogue | a shieldbreaker turncoat | N | boss | `the_salted_gate` — The Salted Gate |
| **Warden** | knight × hunter | a march-warden | N | mentor | `the_border_watch` — The Border Watch |
| **Spellbreaker** | knight × mage | an anti-mage sword-oath | N | boss | `the_silenced_tower` — The Silenced Tower |
| **Paladin** | knight × priest | a sworn holy knight | N | mentor | `the_oath_at_the_altar` — The Oath at the Altar |
| **Plague Knight** | knight × alchemist | Forsworn Knight (`character_forsworn_knight`) | E | boss | `the_rot_beneath_the_plate` — The Rot Beneath the Plate |
| **Poacher** | rogue × hunter | a bounty-jumping trapper | N | recruit | `the_marked_quarry` — The Marked Quarry |
| **Ninja** | rogue × mage | Kaen | N | boss | `the_shadowless` — The Shadowless |
| **Inquisitor** | rogue × priest | a witch-finder | N | boss | `the_confession` — The Confession |
| **Saboteur** | rogue × alchemist | a demolitions ghost | N | recruit | `the_collapsed_vault` — The Collapsed Vault |
| **Shaman** | hunter × mage | a spirit-caller | N | mentor | `the_spirit_wood` — The Spirit Wood |
| **Totemist** | hunter × priest | a ward-carver | N | mentor | `the_standing_stones` — The Standing Stones |
| **Herbalist** | hunter × alchemist | a field-apothecary | N | recruit | `the_poisoned_glade` — The Poisoned Glade |
| **Theurge** | mage × priest | a channelling divine | N | mentor | `the_twin_liturgy` — The Twin Liturgy |
| **Artificer** | mage × alchemist | a sentry-engine builder | N | boss / mentor | `the_automaton_foundry` — The Automaton Foundry |
| **Apothecary** | priest × alchemist | Ren (`character_ren`)* | E | recruit | `apothecary_ren` — The Open Ward |

\* Apothecary (priest × alchemist) is what Ren already is — mends before she strikes. Reusing her makes
this multiclass a companion capstone. Same choice-not-baked note as the subclasses.

## Signature mechanics — what each discipline *does*

Each discipline owns a **unique mechanic**, not just a sharper shelf. To stay inside the "anyone carries
anything / identity is emergent" core, the mechanic **rides on the discipline's signature item** (the
existing signature-relic + trait-via-item pattern) — never a class title or resolver. Unlocking the
discipline puts that item on the shelf; equipping it grants the mechanic.

**This evolves the classes.md contract** ("a discipline only adds stock"). It is the same debt that doc
names — "the growth tables are the weakest half of a class" — answered from the item side instead of a
growth table. classes.md's Disciplines section needs revising to say so.

Status of the underlying combat behavior: **✓** already in the engine · **~** partial (pieces exist,
the fusion is new) · **✗** a new system to build. This column is the real cost — ~20 of 37 mechanics
need engine work, so it drives build order far more than stock or quests do.

### Subclass mechanics

| Discipline | Signature mechanic | Engine |
|---|---|---|
| Barbarian | **Rage** — damage rises as your own HP falls; some strikes cost HP | ~ |
| Warlord | **Banner zones** — planted banners project stacking aura fields | ~ |
| Sentinel | **Intercept** — redirect adjacent allies' incoming hits onto yourself | ✓ |
| Bulwark | **Shove-lock** — knockback that also Halts the displaced | ~ |
| Assassin | **Blink-execute** — teleport to a wounded target, guaranteed finish, return | ~ |
| Thief | **Larceny** — strikes steal an item / buff / stat from the target | ~ |
| Druid | **Wildshape** — swap your kit for a beast form for N turns | ~ |
| Beastmaster | **Bond** — a persistent summoned beast that acts each turn under command | ~ |
| Trapper | **Hidden traps** — pre-placed tile triggers that fire on enemy entry | ~ |
| Elementalist | **Sigils** — aura tiles that reshape spells cast beside them | ✓ |
| Summoner | **Reserve court** — bank mana to field independent elementals | ✓ |
| Necromancer | **Corpse-raise** — the slain rise as your undead | ✗ |
| Monk | **Chi** — unarmed strikes build a charge spent on a burst | ~ |
| Exorcist | **Banish** — remove summons from the field, strip buffs and hazards | ✓ |
| Poisoner | **Coatings** — depleting weapon infusions applied between swings | ✓ |
| Bombardier | **Scatter bombs** — thrown consumables that seed hazards and chain-detonate | ~ |

### Multiclass mechanics — the fusion neither parent does alone

| Discipline | Signature mechanic | Engine |
|---|---|---|
| Champion | **Riposte-wall** — taunt, then counter every striker | ~ |
| Duelist | **Duel stance** — escalating bonus while locked 1v1 with one foe | ✗ |
| Skirmisher | **Hit-and-run** — reposition after a strike | ✗ |
| Battlemage | **Spellstrike** — fold a cantrip into a melee swing | ✗ |
| Crusader | **Smite** — holy melee vs demon/undead, heal on kill | ~ |
| Warbrewer | **Combat draught** — chug an elixir as a free action mid-fight | ~ |
| Vanguard | **Breach** — knockback that strips guard / armor, opening the line | ✗ |
| Warden | **Lockdown zone** — mark an area; entrants are Rooted / Halted | ~ |
| Spellbreaker | **Counterspell** — interrupt channels, negate the next nearby cast | ✗ |
| Paladin | **Ward aura** — persistent damage-reduction bubble on adjacent allies | ~ |
| Plague Knight | **Contagion** — melee spreads poison; standing beside you sickens | ~ |
| Poacher | **Snare-execute** — traps set up the blink-kill; bonus vs Rooted | ~ |
| Ninja | **Shadowclone** — blink between decoy clones and vanish from sight; strike from stealth | ✗ |
| Inquisitor | **Judgment** — mark a heretic; execute deals holy and dispels | ~ |
| Saboteur | **Planted charges** — stealth-place delayed bombs, detonate on cue | ~ |
| Shaman | **Spirit totems** — summoned spirits bound to hazards | ✗ |
| Totemist | **Ward totems** — planted totems projecting holy heal / negate zones | ✗ |
| Herbalist | **Field brewing** — convert field hazards / plants into consumables mid-fight | ✗ |
| Theurge | **Channelled miracle** — wind-up holy spells scaling with channel turns | ~ |
| Artificer | **Constructs** — deploy autonomous sentries / turrets | ~ |
| Apothecary | **Lent vitality** — elixirs that heal and lend party stats | ✓ |

The mechanics are seeds, not final specs — enough to build against, ordered by the Engine column: ship
the ✓ disciplines first (zero new combat code), then the ~, then fund the ✗ as real features.

## The item roster — what a discipline unlocks

The exemplar is the pitch; the **item shelf is the payload**. Unlocking a discipline adds items to its
parent vendor(s) — that is the entire mechanical effect ([classes.md](classes.md#L237)). One rule
governs which items:

**A discipline is the locked deeper cut of its parent shelf, never a re-tag of the whole thing.** The
base class shelf stays open from the first visit; the discipline unlocks a *further* handful (3–6) that
speak the sharper reading. Tag too much and the base shelf empties out and nothing is buyable turn one.
So each discipline gets a small roster: some **existing** items moved behind the gate + some **new**
ones authored, and the exemplar's kit is drawn from that set — that is what makes them a living demo.

Items opt in with the top-level `discipline` field, and it is **sparse, not universal** — most items
carry none (they are the open base shelf). One invariant ties it to `class` (enforced by
`discipline_spec`):

> **An item's `class` must be one of its discipline's parent `classes`.**

A subclass item's `class` *is* its single parent. A multiclass item carries *one* parent as `class` (its
home shelf and growth tally) and appears on the *other* parent's shelf too via the discipline's
`classes` list. One class, one tally, two shelves. So authoring the rosters is an **audit pass over all
~466 items**: base shelf → leave `discipline` unset; locked deeper cut → set it and confirm `class` is a
parent; new signature/mechanic item → author it tagged.

Rosters for the deeper disciplines are authored as each is built; the three Tier-A shelves already have
their stock and are concrete now:

| Discipline | Existing items → tag `discipline` | Author new |
|---|---|---|
| **Elementalist** | the sigils — `utility_careful_sigil`, `utility_distant_sigil`, `utility_quickened_sigil`, `utility_twinned_sigil` | a capstone channelled-hazard spell (the exemplar's finisher) |
| **Poisoner** | coatings — `consumable_envenom`, `consumable_acid_bomb`, `consumable_crawler_mucus`, `consumable_thinblood_rime`* | a signature envenom the vat-master carries |
| **Bulwark** | the shoves — `ability_push`, `ability_shout`, `ability_heave`; `armor_halting_rank` | a knockback capstone / a wall relic |

\* These coatings are currently base-alchemist stock. Moving them behind the Poisoner gate removes them
from turn-one availability — a real decision. Alternative: leave the base coatings open and author *new*
Poisoner-only coatings, so the gate adds rather than takes away. Decide per shelf; the "adds rather than
takes away" reading is safer and is the default for the rest of the slate.

## Two items per multiclass (the approved set)

The **42 approved items** (author feedback rounds settled). Each carries `discipline = <id>`, sits on one
of its parents' shelves, and speaks the discipline's signature mechanic. Build status per item:

- **⌂ tagged** — an existing item re-homed into the discipline (done this session).
- **✓ buildable now** — expressible with mechanics the engine already has.
- **~ mostly there** — a small effect/status on top of existing pieces.
- **✗ needs a new mechanic** — blocked on the engine work in the mechanics tables above; a blueprint
  written now would be dead data, so these wait on their system.

| Discipline | Item A (shelf · type) | Item B (shelf · type) |
|---|---|---|
| Champion | Provoke — taunt adjacent on Defend *(knight · ability)* ~ | Reprisal — counter scales with attackers *(fighter · ability)* ~ |
| Duelist | En Garde — same-target damage stacks *(fighter · ability)* ✗ | Duelist's Edge — passive 1v1 damage boost + tell *(rogue · utility)* ✗ |
| Skirmisher | Harrying Strike — attack, then a free move *(fighter · ability)* ✗ | Skirmisher's Momentum — passive: bonus after moving *(hunter · utility)* ✗ |
| Battlemage | Spellstrike — grid aura: neighbours deal magic + elem. debuff *(mage · utility)* ~ | Arcane Cleave — melee that carries a spell *(fighter · ability)* ✗ |
| Crusader | Smite — holy strike, leaves consecrated ground *(priest · ability)* ~ | Zealous Charge — heal scales with adjacent enemies *(fighter · ability)* ~ |
| Warbrewer | Brawler's Bandolier — quaff as a free action *(fighter · utility)* ✗ | Berserker's Brew — extra attack, take more damage *(alchemist · consumable)* ~ |
| Vanguard | Shieldbreak — knockback that strips guard *(knight · ability)* ~ | Pry Open — strike strips armour *(rogue · ability)* ~ |
| Warden | March-Warden's Standard — a Halting zone *(knight · utility)* ~ | Warding Line — mark an area, Root entrants *(hunter · ability)* ~ |
| Spellbreaker | Null Field — negate the next nearby cast *(mage · ability)* ✗ | Mana Sunder — burn mana, lock out casting *(knight · ability)* ✗ |
| Paladin | Aegis of the Oath — damage-reduction aura *(knight · armor)* ✗ | Consecrate — protective bubble + smite *(priest · ability)* ✗ |
| Plague Knight | Miasmal Plate — enemies beside you are poisoned *(knight · armor)* ~ | Pestilent Flail — melee spreads poison *(alchemist · mace)* ~ |
| Poacher | Poacher's Kris — bonus vs Rooted *(rogue · dagger)* ✓ | Bolas — ranged Root *(hunter · ability)* ✓ |
| Ninja | Vanishing Strike — strike, blink away, vanish *(rogue · ability)* ✗ | Mirror Image — decoy clones + vanish *(mage · ability)* ✗ |
| Inquisitor | Confessor's Needle — execute: holy + dispel *(rogue · dagger)* ✓ | Mark of Heresy — mark a target *(priest · ability)* ✓ |
| Saboteur | Ghost Kit — detonate on signal *(rogue · utility)* ~ | Set Charge — stealth-place a delayed bomb *(alchemist · ability)* ~ |
| Shaman | Spirit Fetish — empowers spirits *(hunter · utility)* ✗ | Call Spirit — summon a hazard-bound spirit *(mage · ability)* ✗ |
| Totemist | Carved Stake — plants a ward totem *(hunter · utility)* ✗ | Raise Totem — holy heal/negate zone *(priest · ability)* ✗ |
| Herbalist | Wildcraft Poultice — nature heal/poison *(hunter · consumable)* ✓ | Field Brew — convert a hazard to a consumable *(alchemist · ability)* ✗ |
| Theurge | Invocation — channelled divine hazard *(mage · ability)* ~ | Litany Staff — holy scales with channel *(priest · staff)* ~ |
| Artificer | Emplace Sentry — an autonomous turret *(alchemist · ability)* ⌂ | Overcharge — a construct acts twice *(alchemist · ability)* ✗ |
| Apothecary | Transfusion — lend your vitality to an ally *(priest · ability)* ~ | Coveted Blood — cloud: allies' piercing hits bite harder *(alchemist · utility)* ⌂ |

**Implementation status: 31 of 42 authored and tested green** (the engine turned out to already carry
most mechanics — `silenced`, `invisible`, `sundered`, `taunt`, guard-redirect, `fx.copy`/`drain`/
`summon`/`retreat`, and the incense/aura/hazard systems). Done: Champion (Provoke, Reprisal), Vanguard
(Shieldbreak, Pry Open), Spellbreaker (Null Field, Mana Sunder), Ninja (Mirror Image, Vanishing Strike),
Crusader (Smite, Zealous Charge), Paladin (Consecrate, Aegis of the Oath), Plague Knight (Pestilent
Flail, Miasmal Plate), Poacher (Poacher's Kris, Bolas), Inquisitor (Confessor's Needle, Mark of Heresy),
Theurge (Invocation, Litany Staff), Battlemage (Arcane Cleave, Spellstrike), Apothecary (Transfusion,
Coveted Blood ⌂), plus one each for Artificer (Emplace Sentry ⌂), Saboteur (Set Charge), Warden (Warding
Line), Warbrewer (Berserker's Brew), Herbalist (Wildcraft Poultice), Shaman (Call Spirit), Skirmisher
(Harrying Strike).

**All 42 are now authored** — the final 11 shipped with **6 new supporting files** rather than engine
changes:

| New file | Serves |
|---|---|
| `data/hazards/hazard_halting_ground.lua` | March-Warden's Standard (Halts foes that cross) |
| `data/characters/character_field_standard.lua` | the standard's planted body |
| `data/characters/character_totem.lua` | Carved Stake + Raise Totem's planted body |
| `data/traits/trait_duelists_poise.lua` | Duelist's Poise (1v1 `damageBonusVs`) |
| `data/traits/trait_skirmishers_momentum.lua` | Skirmisher's Momentum (post-move `damageBonusVs`) |
| `data/traits/trait_brawlers_bandolier.lua` | Brawler's Bandolier (`onCast` haste-on-drink) |

### Deviations, recorded rather than hidden

- **"Duelist's Edge" → "Duelist's Poise"**: `weapon_duelists_edge.lua` already owns that name (a knight's
  binding blade), so the rogue passive took a distinct one.
- **Reprisal, Duelist's Poise, Skirmisher's Momentum, Brawler's Bandolier are `utility` charms, not
  abilities** — a reflex/passive attaches to a grid item, never to an active cast.
- **Aegis of the Oath and Miasmal Plate are `utility` charms carrying `incense`, not `armor`** — the
  walking-zone machine (the Coveted Blood's) is the right home, and it keeps them clear of armor_spec's
  quest-only count and movement tiers.
- **Pestilent Flail is homed `class = "knight"`** so its mace family reads true on its home shelf; the
  discipline still stocks it at the Crucible and growth still tallies both parents.
- **Faithful approximations** where the engine has no primitive, each said out loud in its file header:
  Brawler's Bandolier grants Haste on a drink (rather than a true free action); Overcharge Hastes a
  construct (rather than granting it a second turn); Ghost Kit detonates a chosen tile (rather than
  triggering previously-placed charges); Field Brew brews restorative *ground* (rather than converting a
  hazard into an inventory item); Spirit Fetish empowers spirits via a walking Rally zone.
- **Confessor's Needle omits its dispel half** — there is no single-target dispel primitive
  (`fx.dispel()` clears an AoE footprint); the header says so rather than guessing.

**Caveat:** the 31 pass structural/contract tests (they load, satisfy the tagging invariant, weapon
families, prices). Their `effect` functions follow verified in-engine patterns but have **not** been
runtime-verified in an actual fight — that wants a `/verify` playthrough pass.

## Content bill

| | Existing exemplar | New NPC | New quest |
|---|---|---|---|
| 16 subclasses | 5 (Warlord, Sentinel, Bulwark; +Kaya, Gyeom, Amana if starred reuses stand) | 10–13 | 0 (all gate on existing quests) |
| 21 multiclasses | 3 (Champion, Plague Knight, Apothecary) | ~17 | ~~21~~ **0 — all written** |

The quest column is paid. What is left of the bill is **exemplars**: ~27 NPCs across both tiers, each
currently a stand-in named in its quest's header. That is now the single largest outstanding item
here, ahead of the mechanics work, because a capstone whose exemplar is `character_bandit_chief`
demonstrates nothing — and demonstration is the entire argument for having capstones at all.

## Build order

The tree enforces most of it: no multiclass ships before both its parents have a subclass.

1. **Plumbing** — `data/disciplines/` loader, `discipline`/`exemplar` fields wired into item + vendor
   models, `tests/discipline_spec.lua`. Ship with **Elementalist** as the first live blueprint.
2. **Tier-A subclasses** — Elementalist, Poisoner, Bulwark (stock already exists; see classes.md).
3. **Remaining subclasses**, each with its exemplar + existing gate quest. Druid & Beastmaster wait on
   a shapeshift / animal-summon mechanic.
4. **Multiclasses**, once both parents have a subclass — start where an exemplar already exists
   (Champion, Plague Knight, Apothecary) so the first ones cost a quest, not a quest *and* a character.
   The quests themselves are done; step 4 is now an exemplar-authoring pass, in that same order.

## Open calls

- **Starred companion reuses** (Kaya→Beastmaster, Gyeom→Elementalist, Amana→Exorcist, Ren→Apothecary):
  keep companions as roots only, or let a few double as discipline exemplars via companion quests?
- ~~**Capstone quest count.**~~ **Settled: all 21 were written.** The lighter variant on offer was to
  let some multiclasses unlock the moment both parents are held (the prerequisite *is* the gate),
  reserving authored quests for the marquee pairs. It was not taken, for a reason worth recording:
  the gate quest was already named in every blueprint's `requiredQuests`, so the "lighter" option was
  not actually cheaper — it meant *removing* 17 gates and losing the exemplar meeting that is the
  whole pitch, versus writing 17 more quests around fights that were going to exist anyway. If the
  bill ever needs cutting, cut it at the exemplar NPCs instead; a stand-in in a real quest degrades
  much more gracefully than no quest at all.
- **Exemplar names** below the marquee (Kaen, the Warlord, the Forsworn Knight) are placeholders.
