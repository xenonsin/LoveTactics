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
  requiredQuests = { "quest_undercroft_the_shadowless" },        -- offered only once both parents have a subclass
}
```

## System status — built and green

The discipline **system** is implemented and passes `tests/class_ladder_spec.lua`. What remains is
*content*: the exemplar characters, the capstone quests, and the item rosters below.

- **Loader** — `models/class.lua` loads `data/classes/`; all 38 blueprints exist (17 subclasses
  + 21 multiclasses).
- **Its own growth path** — every discipline has a `data/growth/<id>.lua` table, and a discipline item
  tallies the *discipline* (`Combat.useItem` → `Discipline.growthClasses`), so a Ninja build grows on
  the ninja table — a rogue/mage blend, not both parents at once. (This replaced the older "tallies
  both parents" rule, which existed only because disciplines had no table of their own.)
- **Tooltip** — an item's discipline shows in `ui/item_tooltip.lua`.
- **Vendor gating** — a discipline item is stocked on each parent shelf but stays locked (greyed) until
  `Discipline.isUnlocked` (its quests done; for a multiclass, a subclass of each parent already held).
- **Unlock announcement** — the next time the player opens a parent shop after a discipline unlocks, the
  vendor plays a one-time "the shelf just grew" scene naming it (`data/conversations/discipline_unlocked_<vendor>.lua`,
  driven from `states/hub.lua` via `Discipline.pendingAnnouncements` + `Player.announcedDisciplines`). One
  scene per shop speaks every discipline through the `{discipline}` token; a two-parent discipline
  announces at whichever shop is opened first.
- **Tagging invariant** — an item's `class` must be one of its discipline's parents. Enforced.

## The roots: base-class exemplars

The seven companions already are one exemplar per shelf. They are the tree's roots, not disciplines —
listed so the branches have something to branch *from*.

| Class | Companion | Character |
|---|---|---|
| fighter | Saber | `character_saber` |
| knight | Rowan | `character_rowan` |
| rogue | Clem | `character_clem` |
| hunter | Kaya | `character_kaya` |
| mage | Gyeom | `character_mage` (Gyeom) |
| priest | Amana | `character_amana` |
| alchemist | Ren | `character_ren` |

## The subclasses (17)

One existing quest per discipline, no reuse, and — the rule that moved nine of them — **never earlier
than slot 3 of its line**. A discipline handed over on a line's first or second quest is not earned
advancement; it is a welcome gift, collected before the player has done anything with the base shelf,
and it makes this whole lattice decorative. By slot 3 a line has introduced itself, handed over its
companion, and asked for something. `tests/class_ladder_spec.lua` derives the slot by walking the line's
chain and fails the build below the floor.

**E** = exemplar already exists in the roster; **N** = needs a new character blueprint.

| Discipline | Parent | Exemplar | | Disposition | Gate quest |
|---|---|---|---|---|---|
| **Barbarian** | fighter | arena berserker | N | boss | `blood_in_the_sand` · slot 6 |
| **Warlord** | fighter | The Warlord (`character_warlord`) | E | boss | `warlord_keep` · slot 3 |
| **Sentinel** | knight | Knight in Grey (`character_grey_knight`) | E | mentor | `greywatch` · slot 5 |
| **Bulwark** | knight | Road-Captain (`character_greywatch_captain`) | E | mentor / ally | `held_position` · slot 3 |
| **Assassin** | rogue | a killer sent for you | N | boss | `accounts_settled` · slot 5 |
| **Thief** | rogue | a guild fence | N | recruit / mentor | `one_client` · slot 4 |
| **Mammonite** | rogue | Collections Contractor (`character_mammonite`) | E | recruit | `quarter_end` · slot 6 |
| **Druid** | hunter | a wild shapeshifter | N | mentor | `the_manufactured_cull` · slot 4 |
| **Beastmaster** | hunter | Kaya (`character_kaya`)* | E | recruit | `the_starving_dark` · slot 3 |
| **Trapper** | hunter | a woodland ambusher | N | boss | `the_silent_wood` · slot 5 |
| **Elementalist** | mage | Gyeom (`character_mage`)* | E | mentor | `the_praised_working` · slot 3 |
| **Summoner** | mage | a conjurer with an elemental court | N | boss | `donor_roll` · slot 5 |
| **Necromancer** | mage | an Adept of the inner circle | N | boss | `the_inner_circle` · slot 4 |
| **Monk** | priest | a fist-and-litany ascetic | N | mentor | `purge_in_the_fold` · slot 4 |
| **Exorcist** | priest | Amana (`character_amana`)* | E | mentor / ally | `rite_of_ashes` · slot 3 |
| **Poisoner** | alchemist | a vat-master | N | boss | `the_vats` · slot 5 |
| **Bombardier** | alchemist | a counterfeit-bomb runner | N | boss | `by_the_dram` · slot 4 |

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
42 multiclass items were unreachable stock. `tests/class_ladder_spec.lua` now fails the build if a gate
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
| **Champion** | fighter × knight | Champion (`character_champion`) | E | boss | `quest_colosseum_champions_challenge` — The Champion's Challenge |
| **Duelist** | fighter × rogue | a swaggering blade-for-hire | N | recruit | `quest_colosseum_the_tavern_duel` — The Tavern Duel |
| **Skirmisher** | fighter × hunter | a raider outrider | N | boss | `quest_hunters_lodge_the_running_fight` — The Running Fight |
| **Battlemage** | fighter × mage | a spell-and-steel veteran | N | boss | `quest_arcanum_the_broken_siege` — The Broken Siege |
| **Crusader** | fighter × priest | a holy-blade zealot | N | mentor / boss | `quest_cathedral_the_consecrated_march` — The Consecrated March |
| **Warbrewer** | fighter × alchemist | a berserker-draught brawler | N | boss | `quest_colosseum_the_fighting_cellar` — The Fighting Cellar |
| **Vanguard** | knight × rogue | a shieldbreaker turncoat | N | boss | `quest_bastion_the_salted_gate` — The Salted Gate |
| **Warden** | knight × hunter | a march-warden | N | mentor | `quest_bastion_the_border_watch` — The Border Watch |
| **Spellbreaker** | knight × mage | an anti-mage sword-oath | N | boss | `quest_arcanum_the_silenced_tower` — The Silenced Tower |
| **Paladin** | knight × priest | a sworn holy knight | N | mentor | `quest_cathedral_the_oath_at_the_altar` — The Oath at the Altar |
| **Plague Knight** | knight × alchemist | Forsworn Knight (`character_forsworn_knight`) | E | boss | `quest_bastion_the_rot_beneath_the_plate` — The Rot Beneath the Plate |
| **Poacher** | rogue × hunter | a bounty-jumping trapper | N | recruit | `quest_hunters_lodge_the_marked_quarry` — The Marked Quarry |
| **Ninja** | rogue × mage | Kaen | N | boss | `quest_undercroft_the_shadowless` — The Shadowless |
| **Inquisitor** | rogue × priest | a witch-finder | N | boss | `quest_cathedral_the_confession` — The Confession |
| **Saboteur** | rogue × alchemist | a demolitions ghost | N | recruit | `quest_undercroft_the_collapsed_vault` — The Collapsed Vault |
| **Shaman** | hunter × mage | a spirit-caller | N | mentor | `quest_hunters_lodge_the_spirit_wood` — The Spirit Wood |
| **Totemist** | hunter × priest | a ward-carver | N | mentor | `quest_hunters_lodge_the_standing_stones` — The Standing Stones |
| **Herbalist** | hunter × alchemist | a field-apothecary | N | recruit | `quest_alchemist_the_poisoned_glade` — The Poisoned Glade |
| **Theurge** | mage × priest | a channelling divine | N | mentor | `quest_cathedral_the_twin_liturgy` — The Twin Liturgy |
| **Artificer** | mage × alchemist | a sentry-engine builder | N | boss / mentor | `quest_alchemist_the_automaton_foundry` — The Automaton Foundry |
| **Apothecary** | priest × alchemist | Ren (`character_ren`)* | E | recruit | `quest_alchemist_apothecary_ren` — The Open Ward |

\* Apothecary (priest × alchemist) is what Ren already is — heals before she strikes. Reusing her makes
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
| Monk | **Chi** — unarmed strikes build a charge spent on a burst | ✓ |
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

**All 16 subclass rosters are now tagged** (82 existing items, drawn from each parent's deep shelf and
assigned by signature mechanic). Before this pass every subclass unlocked an *empty* cut: the 21
multiclasses carried their two items each, but the 16 subclasses had zero, so the first sixteen rungs
of the earned-advancement lattice paid out nothing. `tests/class_ladder_spec.lua` now fails the build if
any discipline has no priced item.

The **Mammonite** (17th subclass) was retagged later and by the same rules — 7 priced wares plus the
unpriced Cutpurse's Coat, all of them already-shipped rogue money items, none rebalanced. See the
reversed bullet under *Judgment calls* below.

Three rules shaped the pass, and they are the rules for any future retag:

- **Deep shelf only — rank 2 and up, never turn-one.** Tagging an item removes it from turn-one
  availability, so the roster is drawn from the *locked* part of the parent shelf a player already
  needs standing to reach. That is the "adds rather than takes away" default made concrete: the gate
  moves the deep cut behind an *earlier* unlock, it does not strip the opening shelf.
- **No weapons, no shields.** Both are counted in family rosters of exactly five
  (`tests/weapon_spec.lua`), and a `discipline` tag is excluded from that count — tagging one would
  drop its family to four and fail the build. A discipline weapon has to be authored as an *addition*
  (as the multiclass signatures were), never a retag of base stock. So subclass rosters are abilities,
  utilities, consumables, and non-shield armour.
- **Each item to exactly one discipline**, chosen by mechanic — the sigils to Elementalist, the fist
  charms to Monk, the elemental summons to Summoner, the traps to Trapper, the coatings to Poisoner,
  the bombs to Bombardier, and so on.

**Every subclass now stocks at least five.** The retag pass left counts running 3–8, with Warlord,
Thief and Necromancer on three apiece — the shelves whose parent's deep non-weapon stock is genuinely
shallow, flagged here as the ones that "most want a couple of authored additions later." They got
them. Three is too few to read as a *build*: a discipline you unlocked should hand you a shelf to shop,
not one cast and two charms.

Ten items were authored to lift the six shelves that sat under five, and the roster now runs **5–8
across all sixteen** (92 items):

| Shelf | Was | Added | Now |
|---|---|---|---|
| Warlord | 3 | Muster Banner *(ability)*, War Drums *(consumable)* | 5 |
| Thief | 3 | Sap *(ability)*, Shakedown *(ability)* | 5 |
| Necromancer | 3 | Corpse Burst *(ability)*, Charnel Reliquary *(utility)* | 5 |
| Druid | 4 | Wild Shape: Raven *(ability)* | 5 |
| Beastmaster | 4 | Beastlord's Bond *(utility)* | 5 |
| Monk | 4 | Flurry *(ability)*, Asura Strike *(ability)* | 6 |

The additions obey the same rules as the retag pass, with one difference worth stating: a *retag* had
to come off the parent's deep shelf, but an **authored** item may be new stock — which is the only way
a shallow shelf could ever have been deepened. The no-weapons rule still holds *for the tagged item*:
the Druid's raven form carries a natural ranged weapon, but that is creature gear (classless, unpriced,
`noSteal`, outside every family roster) and the tagged item is the Wild Shape ability.

Two of them are worth calling out as design rather than stock:

- **Monk's pair made the shelf pressable at all.** It was four passive fist charms with nothing to
  spend them on — the one discipline with no active item. Flurry and Asura Strike are both built on
  **chi**, which is now real (see the mechanics table above).
- **Beastlord's Bond is written against `summoned`, not against beasts**, so it heals a Beastmaster's
  wolf and a Summoner's elementals with one rule. A `discipline` field names only one owner, so its
  home is the Lodge — but nothing in its behaviour knows that, which is "anyone carries anything"
  earning its keep.

The multiclass side has since been brought to the same floor — see the next section.

## Five per multiclass: the settled slate

The multiclasses shipped with **two items each** while every subclass ran five to eight. Three is too
few to read as a build, and the argument that retired it is the one the subclass pass already made:
*a discipline you unlocked should hand you a shelf to shop, not one cast and two charms.* Two is
worse than three.

So the 21 multiclasses were taken to **five apiece** — 63 authored items, settled over four rounds of
author review. Two shelves ended at six, which is inside the subclass range and deliberate in both
cases (noted below).

Three rules governed the pass, and the first is the one that cost the most:

- **Authored, never retagged.** The subclass pass drew its rosters off each parent's *deep shelf*.
  That stock is spent: pulling another 63 would empty the base shelves the disciplines are supposed
  to sit behind. Every item here is new.
- **Both parent shelves must be stocked.** Six multiclasses had all their items on one parent, which
  meant the other vendor unlocked a discipline and then sold nothing for it. Artificer (mage) and
  Plague Knight (alchemist) were the worst — a completely empty parent.
  `tests/class_ladder_spec.lua` now fails the build on it.
- **Each item owes the mechanic, not the shelf.** A `+n` on the right vendor is still the thing the
  forge already sells. Where a pitch could only produce one, the answer was to move the behaviour out
  of an item entirely — which is where the five rules below came from.

### The five rules the pass settled

Each of these started as a note on a single item and generalized into a contract. They are worth more
than the items that prompted them:

| | Rule | Where it lives |
|---|---|---|
| **R1** | **Armor never grants movement.** The movement tiers in the armor spread are a cost table; an armor that pays movement back undoes them. | [classes.md](classes.md) armor spread |
| **R2** | **A charge pool banks from a generic tally, never from carrying one weapon.** Zeal banks on kills *and* heals, so a Crusader who spent the fight healing still reaches the payoff. | `Combat.chargeDef` |
| **R3** | **`status_mark` gains `preventsInvisible`.** The rule belongs in the debuff, not in a lamp you have to buy — it now holds for everyone who applies Mark. | `data/status/status_mark.lua` |
| **R4** | **Contagion is a passive, not an active.** Standing beside you spreads what you carry; you never press a button for it. | `plague_knight` roster |
| **R5** | **Poison needs payoffs before Plague Knight is real.** Contagion was spreading a status almost nothing read. Rot-Fume Gauntlet now scales with how many enemies are poisoned; the Poisoner shelf owes the same audit. | open thread |

### Two findings that changed the systems bill

- **Channels already break without an interrupt system.** `Combat.interruptChannel` exists and is
  already called from knockback ([combat.lua:2841](../models/combat.lua)), displacement, dismissal and
  death, and seven statuses carry `interruptsChannel`. So S5's veto half was only ever needed for
  *instant* casts — and every active anti-magic item was turned down in review as too punishing.
  **S5 shrank to `fx.dispelUnit`**, which cut the AI work that was its real cost.
- **Sunder is rare and knockback is everywhere.** 19 items cause knockback; only five things in the
  catalog apply Sundered. So Vanguard's charm turning every shove into a Sunder is not a convenience —
  it is what makes the discipline's mechanic exist at all, and it replaced two weaker items.

### Build status per item

- **⌂ tagged** — an existing item re-homed into the discipline.
- **✓ buildable now** — expressible with mechanics the engine already has.
- **~ mostly there** — a small effect/status on top of existing pieces.
- **✗ needs a new mechanic** — blocked on the engine work in the mechanics tables above.

### The original two

Kept as its own table because these are the ones already on disk; the three that follow each are the
new stock.

| Discipline | Item A (shelf · type) | Item B (shelf · type) |
|---|---|---|

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

### The three that take each shelf to five

| Discipline | + Item | + Item | + Item |
|---|---|---|---|
| Champion | Defiant Stand — taunt adjacent, bank Defiance per hit taken *(knight · ability)* S1 | Answering Blow — spend all Defiance, strike every adjacent *(fighter · ability)* S1 | Crowd's Favour — Defiance also banks when an ally beside you is struck *(fighter · utility)* S1 |
| Duelist | Coup Droit — spend Tempo, damage × spent, duelbound only *(fighter · ability)* S1 | Main-Gauche — parries bank Tempo *(rogue · dagger)* S1 | Reading the Blade — bank Tempo per repeat strike; empties if you switch target *(fighter · utility)* S1 |
| Skirmisher | Running Shot — damage scales with tiles moved this turn *(hunter · ability)* ✓ | Outrider's Harness — first post-move strike Exposes and cannot be answered *(fighter · armor)* ~ | Harrier's Bow — the shot does not close your movement *(hunter · bow)* ~ |
| Battlemage | Resonant Grip — strikes carry the element of your last cast *(fighter · utility)* ~ | Arcane Conduit — adjacent grid items cast harder, spending Arcane *(mage · utility)* S1 | *(Spellstrike and Arcane Cleave stand)* |
| Crusader | Vow of the March — bank Zeal on any kill or nearby heal *(priest · utility)* S1 | Reckoning — spend Zeal: holy blow that heals every adjacent ally *(fighter · ability)* S1 | Crusader's Tabard — heal-on-kill scales with Zeal held *(fighter · armor)* S1 |
| Warbrewer | Battle Tonic — free action, restores stamina *(alchemist · consumable)* S2 | Field Still — brews a draught into your grid each turn *(fighter · utility)* S4 | Round for the House — your draughts also reach adjacent allies at half *(fighter · utility)* ✓ |
| Vanguard | Breaker's Harness — knockbacks into a wall Stun *(knight · armor)* ~ | Breaker's Wedge — **any** knockback you inflict Sunders *(knight · utility)* ✓ | Stripped Plate — armour you Sunder is added to yours *(rogue · utility)* ~ |
| Warden | Warden's Writ — every hazard you place also Halts *(knight · utility)* ~ | Beat the Bounds — foes standing in **any** hazard are Rooted and damaged *(hunter · ability)* ✓ | Marchstone — incense: the ground you stand on counts as your hazard *(hunter · utility)* ✓ |
| Spellbreaker | Silencing Blade — Silences; damage scales with target mana *(knight · sword)* ~ | Dampening Oath — enemy casts within 3 cost double mana *(knight · utility)* ~ | Spell Eater + Empty Vessel — absorb magic for mana; execute the mana-dry *(mage · utility ×2)* ~ |
| Paladin | Lay On Hands — heal + Aegis, pull their debuffs onto yourself *(priest · ability)* ~ | Oathkeeper's Litany — lasting damage-reduction aura *(priest · ability)* ~ | Vow-Marked Plate — every debuff you carry hardens you *(knight · armor)* ~ |
| Plague Knight | Contagion — poisoned foes infect their neighbours *(alchemist · utility)* R4 | Plaguebearer's Draught — poison yourself; spread on contact *(alchemist · consumable)* ~ | Rot-Fume Gauntlet — damage scales with the poisoned on the field *(knight · utility)* R5 |
| Poacher | Throatcut — execute the Rooted or Crippled; refunds on a kill *(rogue · ability)* ✓ | Quarry's Due — anything caught in your traps is Marked *(hunter · utility)* ✓ | The Long Wait — attacks on Rooted or Marked cannot be countered *(rogue · utility)* ~ |
| Ninja | Shadow Step — swap places with one of your clones *(mage · ability)* ✓ | Substitution — a blow kills a standing clone instead; you take its tile *(rogue · utility)* ~ | Smoke Mantle — Invisible at turn start if you did not attack *(rogue · armor)* ~ |
| Inquisitor | Sentence — execute a Marked target; holy, dispels *(priest · ability)* S5 | The Question — steal a buff off a Marked target *(rogue · ability)* S5 | The Pyre — every Marked enemy on the field burns at once *(priest · ability)* ✓ |
| Saboteur | Detonator — set off every charge you planted *(rogue · ability)* S3 | Sapper's Line — three charges in a line, two-turn fuse *(alchemist · consumable)* S3 | Collapse — destroy a wall or prop, hazard the rubble *(alchemist · ability)* ~ |
| Shaman | Bind Spirit — bind a spirit to a hazard; it follows *(mage · ability)* ~ | Ancestor Mask — spirits inherit your hazards' element *(hunter · utility)* ~ | Ghost-Wind — spirits pass walls unharmed and feed on hazards *(hunter · utility)* ~ |
| Totemist | Totem of Renewal — a totem whose ground grants Regeneration allies carry away *(priest · ability)* ✓ | Totem-Carver's Kit — totems gain health and radius *(hunter · utility)* ✓ | Ley Line — a totem's effect floods the line to another totem *(priest · ability)* ~ |
| Herbalist | Distil — consume a hazard tile, gain a matching consumable *(alchemist · ability)* S4 | Bitterroot Draught — cleanse + immunity to the hazard you stand in *(alchemist · consumable)* ✓ | Culler's Kit — an enemy you kill leaves a reagent in your grid *(hunter · utility)* S4 |
| Theurge | The Long Prayer — channel; the sanctified zone grows each turn *(priest · ability)* ~ | Vigil Beads — your channels cannot be interrupted *(mage · utility)* ~ | Benediction — a channelled heal that bursts over the party *(priest · ability)* ~ |
| Artificer | Field Assembly — build a construct from a consumable; it attacks with its effect *(mage · ability)* S4 | Recall Construct — dismiss for half refund, redeploy in range *(mage · ability)* ✓ | Salvage Rig — a destroyed construct bursts and refunds mana *(alchemist · utility)* ~ |
| Apothecary | Borrowed Hands — your magic attack becomes the party's highest *(alchemist · consumable)* ✓ | The Shared Ledger — those you heal borrow your defense *(priest · utility)* ~ | The Tithe — copy every buff your allies carry onto yourself *(alchemist · consumable)* ~ |

**Built and green.** All 37 disciplines now stock five or more (`tests/class_ladder_spec.lua` pins the
floor and the per-parent rule), and every multiclass sells something at *both* its parents. The five
systems shipped as four and a half — S5 shrank to `fx.dispelUnit` when the interrupt half turned out to
have no consumer.

Three names had to move, and they are recorded rather than hidden — the deeper cut always yields to the
shelf a player meets first, the same precedent "Duelist's Edge" → "Duelist's Poise" set:

| Drafted as | Shipped as | Because |
|---|---|---|
| Shadow Step *(ninja)* | **Shadow Trade** | `ability_shadow_step` is a rogue base-shelf blink |
| Collapse *(saboteur)* | **Bring It Down** | `ability_collapse` is a mage's board-folding pull |
| Duelist's Edge *(duelist)* | **Duelist's Poise** | `weapon_duelists_edge` is a knight's binding blade |

**Two shelves stand at six**, both deliberate and both inside the subclass range:

- **Ninja** adds **Scatterlight** *(mage · ability)* — plant three clones on random nearby tiles and swap
  with one at random. Randomness you chose to enter is a different thing from randomness done to you,
  and `fx.random` draws from the battle's own sequence so a replay scatters identically.
- **Spellbreaker** keeps **both** Spell Eater and Empty Vessel. Worth recording that the shelf is now
  six passives and no active of its own: every *active* anti-magic item was turned down in review. That
  is a coherent reading — an anti-mage is a condition the enemy walks into rather than a button — but
  it is a choice, not an oversight.

**Implementation status (the original 42): 31 of 42 authored and tested green** (the engine turned out to already carry
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

## The base-shelf audit: seventeen items that were already somebody's discipline

The two passes above built the rosters *outward* — subclasses drew from each parent's deep shelf,
multiclasses were authored new. Neither looked in the other direction: at items sitting on the OPEN
shelf whose behaviour **is** a discipline's named signature mechanic. Warden's Oath is Sentinel's
Intercept stated word for word, on sale from turn four; The Gagging Storm is Spellbreaker's Counterspell
laid as ground.

All 264 priced base-class items were swept against the 37 mechanics tables. The bar was deliberately
high — *is*, not *is compatible with* — and seventeen cleared it. Priest 52 → 47, knight 36 → 31,
alchemist 35 → 34, mage 56 → 54, fighter 32 → 30, rogue 28 → 27, hunter 25 → 24.

| Item | Shelf | → | Why |
|---|---|---|---|
| Warden's Oath *(armor)* | knight | **Sentinel** | Intercept, verbatim: the first hit each turn on an adjacent ally is taken by you |
| The Gaunt Vigil *(ability)* | knight | **Spellbreaker** | a standing tax on casting; its own header calls it "the knight's version" of answering a mage |
| Skeptic's Harness *(armor)* | knight | **Spellbreaker** | the sword-oath's plate: forswear the craft, ward against it |
| The Grasping Hollow *(ability)* | knight | **Warden** | the Lockdown zone itself — ground that Roots whatever crosses it |
| Drill Standard *(utility)* | knight | **Paladin** | the banner rule |
| Pincer Banner *(utility)* | fighter | **Warlord** | the banner rule |
| Whirlplate *(armor)* | fighter | **Champion** | Riposte-wall: on melee hit taken, cut every adjacent foe |
| Break Off *(ability)* | hunter | **Skirmisher** | Hit-and-run, third member of a set whose other two were already gated |
| The Gagging Storm *(ability)* | mage | **Spellbreaker** | Counterspell as ground; it shatters the channels standing in it |
| Second Utterance *(utility)* | mage | **Theurge** | the Channelled miracle's other half, beside Vigil Beads |
| Spike Trap *(ability)* | rogue | **Poacher** | the rogue half of Snare-execute; Trapper can't take it (parent is hunter) |
| Alchemist's Bandolier *(utility)* | alchemist | **Warbrewer** | Combat draught: a quaff that costs no turn, beside Brawler's Bandolier |
| Sacred Banner *(ability)* | priest | **Paladin** | the banner rule |
| Renewal Banner *(ability)* | priest | **Paladin** | the banner rule |
| Martyr's Icon *(utility)* | priest | **Paladin** | the Ward aura's thesis: your body in place of the one beside you |
| Censer of Dawn *(utility)* | priest | **Crusader** | Smite as an aura — the Cathedral consecrating somebody else's steel |
| The Burning Halo *(utility)* | priest | **Crusader** | the armed faithful's ring; it asks a priest to stand in the line |

**The banner rule is new and it decides by object, not by mechanic.** A banner belongs to Paladin or
Warlord; the destination follows the item's `class`, Warlord being fighter-only. Pincer Banner moves on
it despite its behaviour being a Follow-Up ally-strike reflex. The rule is written up in
[classes.md](classes.md#L363). Two banners survive it because a test would fail:
`weapon_marching_standard` is a spear (tagging it drops that family below its five-on-a-shelf roster,
so a discipline banner-weapon must be authored) and `ability_march_wardens_standard` is tagged `summon`
rather than `banner` and is one of only two knight-side Warden items.

**A third banner escaped it for a duller reason: the sweep read prices.** `armor_rally_coat` is a
fighter banner — a worn one, laying `hazard_rally` as it walks — and it is *quest-only*, so it was not
among the 264 priced items the audit looked at. It carries `discipline = "warlord"` now, unpriced, the
same shape as Cutpurse's Coat below: for growth and identity, never for the rack. The move costs
nothing anywhere else, because the coat's source is the Warlord's own gate quest (Siege of Warlord's
Keep, slot 3) — the shelf opens and the reward lands on the same beat. The general lesson is the one
worth keeping: **an audit scoped to what is for sale cannot see the half of a shelf that is given
away.**

### Round two: the strict pass on the Arcanum and the Cathedral

Round one's bar left mage at 54 and priest at 47 — still the two longest shelves by a distance. A second
pass ran on those two only, with the bar dropped to *the discipline is a better home than the open
shelf*. Eleven more moved. The ward-line split above did the heavy lifting on the count; this did the
coherence.

| Item | Shelf | → | Why |
|---|---|---|---|
| Graven Circle *(ability)* | mage | **Elementalist** | the sigils are Elementalist's own; this is the circle they are cut in |
| The Answering Din *(ability)* | mage | **Elementalist** | the earth storm, beside Blizzard / Meteor / Thunder |
| Unraveller's Sigil *(utility)* | mage | **Spellbreaker** | the aimed spell is unravelled outright — Counterspell, sold openly |
| Mirrorsilk *(armor)* | mage | **Spellbreaker** | the same deflection worn rather than carried; the pair should not split |
| Cinderstride Boots *(utility)* | mage | **Elementalist** | element as terrain: real, unsided Fire laid behind every step |
| Tidewalker Boots *(utility)* | mage | **Elementalist** | the water twin of the Cinderstride |
| Pilgrim's Sandals *(utility)* | priest | **Theurge** | a divine hazard laid by walking rather than by casting |
| Anathema *(ability)* | priest | **Inquisitor** | Judgment — the naming that holds a body open for somebody else's execute |
| Binding Grace *(ability)* | priest | **Monk** | its own header: the monk is the one body that pays nothing for the second clause |
| Keen Senses *(ability)* | priest | **Monk** | the answer that lands *before* the blow — a martial reflex, not a liturgical one |
| The Stayed Hand *(utility)* | priest | **Exorcist** | Banish turned inward: strip what is riding the body, then lift it out of reach |

**Mage 45 → 39, priest 38 → 33.** Two of the eleven overturn round-one findings on purpose, and both are
worth flagging as decisions rather than drift: **Anathema** was kept in round one to preserve the
one-Vulnerable-opener-per-shelf parity, and gating it makes the holy opener the only locked member of
that set; **Keen Senses** is argued in its own header as a priest's item and not a duelist's, precisely
because it is priced in stamina.

**Two disciplines are now well past the 5–8 band: Spellbreaker and Elementalist, at eleven each.** That
is a consequence rather than a plan — anti-magic is genuinely knight × mage, and the sigils genuinely are
Elementalist's — but it should be revisited before either grows again. Monk is at nine, Theurge seven.

Five were denied, and three of them matter:

- **Sanctuary** and **Holy Light** *(priest → Theurge)*. Holy Light carries `windup = 6` and is the only
  wind-up holy spell in the game, which made it Theurge's on the mechanic. It is also the priest's *one*
  offensive spell — gating it means base priest cannot hurt anybody until two lines are walked. The
  identity cost outweighed the fit, and Sanctuary went with it so the Cathedral keeps consecrated ground.
- **Blink** *(mage → Ninja)*. The keyword fits (`classes.md` gives `blink` to the rogue) but the mechanic
  does not: it is a `moveBehavior`, a stance rather than a cast, and Ninja's roster is clones and stealth.
Two **merges** were done rather than moves. Warding Censer and Warding Chasuble both granted
`trait_guardians_blessing`; Reliquary of Grace and Vestments of the Open Hand both granted
`trait_sanctified_presence` — each pair one rule sold twice, five ranks apart, one worn and one slotted.
The two utilities were retired and the armour kept in both cases, on the rule that settled it:

> **When one trait has a worn carrier and a slotted one on the same shelf, keep the worn one.** The
> armour is the version that costs something — a chest slot and a square of pace — against a grid cell
> that was free to anyone with a spare one. A shelf that sells one rule twice is selling a spelling
> rather than a choice.

Worth knowing what the merge gave up, since it is not nothing: `utility_hallowed_censer` and
`utility_reliquary_kept_trust` still carry Sanctified Presence from a grid cell, but both are unpriced
quest stock — so the *bought* slotted build is gone for both traits. That is the intended trade (a second
spelling belongs in quest stock, not on the rack), not an oversight. Priest 33 → 31.

### Three denied in round one, and the reasons are worth keeping

- **Shield Bash** *(knight → Champion)*. Defend-and-punish next to Champion's Provoke, but gated at q3
  it is the shallowest thing the sweep found, and Champion did not need it.
- **Summon Golem** and **Summon Homunculus** *(alchemist → Artificer)*. A deliberate pair — one buys a
  thing that does not die, the other a thing whose worth is what it leaves when it does — and the golem's
  own header already argues why a guard is envy's and not the knight's. Moving both would also raise
  whether they should turn autonomous like every other Artificer construct, which is a behaviour change
  rather than a shelf move.

### Checked and left alone across both rounds

- **The 22 elemental ward items are a systematic family, and no discipline could take them.** Priest
  carried 11 `Resistant: <type>` and mage 11 `Immunity: <type>`, one per damage type — a third of each
  shelf's ability list. Gating any subset splits a set that only works complete, and gating all eleven
  puts a class's own named keyword behind a quest. **Answered a different way instead:** the line was
  split across all seven shelves by damage type, on the rule *a house wards against what it deals*
  ([vulnerability.md](vulnerability.md#the-ward-line)). Mage 54 → 45, priest 47 → 38, and the six other
  shelves each gained two or four. It is the only change in either pass that moved a `class` rather than
  adding a `discipline`.
- **The Vulnerable openers are one per shelf by design** — Rend, Crack the Guard, Barbed Dart, Forsake,
  Anathema, Oil Flask. Anathema reads like Inquisitor stock; pulling it makes the holy opener the only
  gated one in a set built on parity.
- **Fire Bomb sitting apart from the Acid / Ice / Lightning bombs is correct.** Those three are
  Bombardier's; Fire Bomb is base at q1 / 70g. That is the never-turn-one rule working, not a gap.
- **Two items argue against their own gating in their own headers** — the Guttering Lamp ("rank 2 and
  cheap … a survival floor rather than a build piece") and Binding Grace, whose design is that a knight,
  a monk and nobody else wants it.
- ~~**The rogue's purse kit stays base.** Blood Money, The Gilded Wound, Grease Palms, Skimmer's Cut and
  The Ledger's Due are the greed identity itself, not a deeper cut of it.~~ **Reversed — it is the
  Mammonite** (`data/classes/mammonite.lua`, a 17th subclass, gated on Quarter-End · slot 6). The
  call was right about the identity and wrong about the shelf. The kit grew to eight wares on one
  resource nothing else in the game touches (`Combat.spendPurse` / `Combat.bounty`), and a resource that
  changes how you fight the *whole battle* is not a flavour of rogue — it is an opt-in with its own
  growth table, which is what a discipline is here. A player who wants it wants all eight; a player who
  does not wants none. Its two existing tiers survived the move untouched: the **earners** (The Ledger's
  Due, A Price on the Head, Skimmer's Cut) sit at q4–q7 and the **spenders** (Blood Money, The Gilded
  Wound, Grease Palms, The Open Account) at q9, so slot 6 lands the gate between the halves — the shelf
  opens on the income side and completes once Aurea falls. Not one `unlockQuests` moved. Cutpurse's Coat
  is tagged too, unpriced, for growth and identity rather than stock.

## Content bill

| | Existing exemplar | New NPC | New quest |
|---|---|---|---|
| 17 subclasses | 6 (Warlord, Sentinel, Bulwark, Mammonite; +Kaya, Gyeom, Amana if starred reuses stand) | 10–13 | 0 (all gate on existing quests) |
| 21 multiclasses | 3 (Champion, Plague Knight, Apothecary) | ~17 | ~~21~~ **0 — all written** |

The quest column is paid. What is left of the bill is **exemplars**: ~27 NPCs across both tiers, each
currently a stand-in named in its quest's header. That is now the single largest outstanding item
here, ahead of the mechanics work, because a capstone whose exemplar is `character_bandit_chief`
demonstrates nothing — and demonstration is the entire argument for having capstones at all.

## Build order

The tree enforces most of it: no multiclass ships before both its parents have a subclass.

1. **Plumbing** — `data/classes/` loader, `discipline`/`exemplar` fields wired into item + vendor
   models, `tests/class_ladder_spec.lua`. Ship with **Elementalist** as the first live blueprint.
2. **Tier-A subclasses** — Elementalist, Poisoner, Bulwark (stock already exists; see classes.md).
3. **Remaining subclasses**, each with its exemplar + existing gate quest. Druid & Beastmaster wait on
   a shapeshift / animal-summon mechanic.
4. **Multiclasses**, once both parents have a subclass — start where an exemplar already exists
   (Champion, Plague Knight, Apothecary) so the first ones cost a quest, not a quest *and* a character.
   The quests themselves are done; step 4 is now an exemplar-authoring pass, in that same order.

## Open calls

- ~~**Starred companion reuses** (Kaya→Beastmaster, Gyeom→Elementalist, Amana→Exorcist, Ren→Apothecary):
  keep companions as roots only, or let a few double as discipline exemplars via companion quests?~~
  **Settled: companions stay roots only.** Dedicated bodies were authored — `character_apothecary`,
  `character_beastmaster`, `character_elementalist`, `character_exorcist` — and the four `exemplar` pointers
  repointed off the companions. Ninja also got its own body (`character_ninja`, "The Shadowless"); Kaen
  stays the marquee named boss of the unlock quest. Every discipline now has a body distinct from the seven
  roots, and each carries its own sprite + composed silhouette (see
  [art-assets.md](art-assets.md), the discipline-silhouette tier).
- ~~**Capstone quest count.**~~ **Settled: all 21 were written.** The lighter variant on offer was to
  let some multiclasses unlock the moment both parents are held (the prerequisite *is* the gate),
  reserving authored quests for the marquee pairs. It was not taken, for a reason worth recording:
  the gate quest was already named in every blueprint's `requiredQuests`, so the "lighter" option was
  not actually cheaper — it meant *removing* 17 gates and losing the exemplar meeting that is the
  whole pitch, versus writing 17 more quests around fights that were going to exist anyway. If the
  bill ever needs cutting, cut it at the exemplar NPCs instead; a stand-in in a real quest degrades
  much more gracefully than no quest at all.
- **Exemplar names** below the marquee (Kaen, the Warlord, the Forsworn Knight) are placeholders.
