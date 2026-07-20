# The Seven Deadly Sins and the Demon Lord

The endgame is not bolted onto the progression loop — it *is* the progression loop, followed to its
end. Each of the seven class vendors sells you gear, ranks you up, and walks you toward the sin it has
been quietly serving the whole time. Kill all seven generals and the Gate Below opens.

This document is the bible for that arc, and the template for finishing it. **Wrath is authored end to
end; the other six are not.** Copy its shape.

**Sloth is built.** All ten quests, the characters, the traits, the items and twenty-three scenes are
on disk — see *The Bastion* below. It is the reference line, and the only one whose quests play a
conversation at all: `intro` (over the hub), `outro` (over the final battle frame) and an objective
`opening` (over the board, the one seam an antagonist can speak from).

**Slots 1 and 2 have been through a premise pass; slots 3–10 have not**, and each of those files
carries a `WIP` banner saying so. The pass is: state what is actually happening, how it bears on
Rowan *and* on sloth, what the objective is, and which unique item carries the narrative. It is worth
doing properly — it caught a slot 1 that duplicated an existing quest outright, and a slot 2 whose
premise could not survive the question *"why is this a fight?"*.

## The seven

Every vendor in `data/vendors/` declares a `sin`. Every vendor's rank-4 item (800 gold, unlocked at 200
reputation) closes its file comment by naming that sin's general *and the mechanic the general fights
with*. Those comments were written before the generals existed; they are the spec.

| Sin | Vendor | Class | Rank-4 foreshadow item | The general's rule |
|---|---|---|---|---|
| **wrath** | The Colosseum | fighter | Crimson Greataxe | grows on damage taken |
| **lust** | The Cathedral | priest | Censer of Dawn | takes what is not offered |
| **gluttony** | Hunter's Lodge | hunter | Hornbow of the Hunt | never stops being hungry |
| **sloth** | The Bastion | knight | Oathkeeper Shield | not idleness — the oath abandoned |
| **pride** | The Arcanum | mage | Codex of Hubris | answers every spell with your own |
| **greed** | The Undercroft | rogue | Kingsblood Dagger | lifts the kit out of your hands mid-fight |
| **envy** | The Crucible | alchemist | Philosopher's Stone | has no shape until it has seen yours |

### Greed and Envy are not the same sin

Greed wants the **thing**. It steals your dagger. Envy wants the thing's **property**, and would rather
you had neither. The Undercroft and the Crucible are balanced against exactly this line, and it is why
alchemy — transmutation, the base metal that wants to be gold, the borrowed quality — is Envy's craft
and not Greed's.

### Pride and Envy are not the same mechanic

Both copy. `ability_doppelganger` copies **yourself**, and it sits on the Arcanum's shelf because a
spell whose answer to every problem is a second copy of the caster is Pride. `philosophers_stone` copies
**someone else**, and it sits in the Crucible because that is Envy. Same engine call (`Summon.copy` vs
`Summon.copyOf`), opposite appetite.

## The Demon Lord

**The Hollow Crown** (`data/characters/character_demon_lord.lua`) has no sin of its own. The seven were its
appetites, and the whole game is spent taking them off it one at a time. Its stats are those of
something that has not needed to fight in a long while: an enormous health pool and almost nothing
behind it. Every threat in the final battle is borrowed — its trait `hollow_crown` puts the generals you
already killed back on as its health falls past 75%, 50%, and 25%.

The shades are summons, bound to the Crown. Kill it and they go with it, which is what keeps the
`assassinate` objective resolvable.

> **Authoring note:** `data/traits/trait_hollow_crown.lua` has a `shades` list. Today it names
> `general_wrath` and falls back on `warlord` / `champion` for the six generals that do not exist yet.
> **That list is the fight.** As each general is written, put it there.

## The seven keys

Each general drops **one unique, usable item** — a relic, not a matched set of trophies. They differ in
type, they differ in shape, and each **grants the trait its general fought you with**. Beat Wrath and
her rage is yours: the mail off her body makes *you* stronger the more you are hit. That is the payment
for a general, and it is the same trap it was when she wore it.

Relics carry no `class` and no `price`, so no vendor stocks them and none can be replaced. Each one's
`description` holds one fragment of the Gate Below's location. Seven fragments name the place.

**The relic is not the key.** What opens the Gate is `player.completedQuests["general_<sin>"]` — see
`questGate` in `models/quest.lua`. Relics are meant to be *worn*, and a key you can misplace in a
loadout screen is not a key. Moving, stashing, or losing a relic can never soft-lock the endgame.

`data/quests/the_gate_below.lua` names all seven in `requiredQuests`. Prestige and reputation are hard
gates (fail one and a quest is not on the board at all); `requiredQuests` is a **soft** lock. Kill your
first general and the Gate appears on the board `locked`, counting *1 of 7 keys* and reciting the one
fragment you have earned. Watching that count climb is the last stretch of the game.

> `map.keyCount` on a quest is the **overworld's** locked-door puzzle (`models/overworld.lua`) — an
> entirely different mechanic that happens to share the word. `the_gate_below` sets `keyCount = 0`.
> Do not lock the last door twice.

## The three acts

The seven-general arc above is the middle of a three-act shape, not the whole of it.

- **Act 0 — the prologue.** A village on the capital's outskirts, and the demons that burn it. It
  is the tutorial and the reason to care at once: the antagonist named, the first companion earned,
  the road to the city walked. It ends when the hub opens and the Adventurers' Guild sets the board
  in front of you. Linear by design — the overworld's locked doors and dead-end ambushes stay
  holstered until Act 1.
- **Act 1 — the seven.** This document. Open-ended: seven vendor lines, seven companions, seven
  generals, in whatever order standing allows.
- **Act 2 — the Gate Below.** `the_gate_below` and the Hollow Crown.

The Crown re-summons the generals you have killed as its health falls (see *The Demon Lord*) —
which is the whole reason the middle act is a general hunt and not a fetch list. **That logic has
to be spoken, or it isn't there.** Plant the Demon Lord as a named threat in the burning village;
let the Guild say the rest aloud when it opens the board — the Crown is only ever as strong as its
seven, and unmade one at a time it is hollow.

You do not play one of the seven. The protagonist is a made character — a survivor of the village,
no class of their own, growing into whatever they are cast as (`Growth.NEUTRAL_CLASS`). The player
picks their **body** (1 or 2 — a sprite set, never a gender label) and types their **name** at
character creation, before the first line is spoken (`states/character_creation.lua`).

The name is asked there rather than on the sand because **Rowan is already sworn to you when the
prologue opens** — she is the player's bodyguard and mentor, and she has to be able to say your
name in the burning village. A companion who knows you cannot call you "stranger." The arena
therefore names nobody; `arena_debut` still promises *"win it, and they will remember your name"* —
the crowd learning a name you already had is the promise, not the naming itself.

A line can address the avatar with the **`{name}` token**, substituted at display time in
`ui/dialogue.lua` (after localization, so a translator may move it where their grammar wants it).

## The other seven

Every general has a foil, and the foils are your party. Seven **main** companions, one per class,
each the heavenly virtue that answers its class's sin — and the answer is mechanical before it is
thematic. Ira grows on the blows she takes; her foil is the fighter who wins without trading them.
A general and her foil are the same wound with two answers, and the companion is the answer the
general refused.

| Class | General's sin | The companion answers with |
|---|---|---|
| fighter | wrath — *Ira* | patience — burst and restraint; win without trading blows |
| knight | sloth — the oath abandoned | diligence — the oath kept; the wall that holds its post |
| rogue | greed | charity — takes from the rich and keeps none of it |
| hunter | gluttony | temperance — the hunt that knows when to stop |
| mage | pride | humility — answers a spell with a ward, not a bigger spell |
| priest | lust | devotion — gives what is offered, refuses what is not |
| alchemist | envy | kindness — grants others' power instead of coveting it |

**The virtue is the spine, never the label.** A sin gets to be a personified abstraction — *Ira,
the Unappeased*. A virtue does not; it is a person with an ordinary name, and the virtue shows in
how they fight and what they will not do, never in what they are called. A companion named for her
virtue is the exact mistake this section exists to forbid.

**Every companion is a woman, and so is every general** — the whole war of appetite and answer is
fought between women. Companions carry **gender-neutral** names (Rowan the knight, Saber the
gladiator); generals keep the Latin sin-register (*Ira*). The virtue is buried in the name, not
stamped on it: *Saber* is a blade, and in another tongue (*ṣabr*) it is patience itself.

Companions are earned near the head of their vendor's line, each on its own — never behind another,
so no ordering can strand the endgame. Two are earned in the prologue, one per pattern:

- **Sworn beside you.** The knight fights at your shoulder in the burning village and stays when it
  is ash. An oath abandoned is sloth's general; an oath re-sworn to a stranger is the knight. What
  the oath makes her is the player's **bodyguard and mentor** — she guards the body she swore to and
  teaches the trade she already knows, so hers is the voice that warns, explains, and steps in front.
  That is a role, not a label: it shows in where she stands and what she says, never in a title.
- **Bested, then kept.** The first bout on the Colosseum's sand is against the house's own
  gatekeeper — a gladiator who has watched the arena and its patron, *Ira*, eat fighter after
  fighter, and who will not be eaten. She fights every newcomer looking for the pair who can beat
  her, because Ira is not a thing you walk up to alone. Beat her and she is yours, and her quarrel
  — the patron beneath the sand — is the Colosseum line you are standing at the foot of. You best a
  fighter in sport at the start of that line and kill one in earnest at its end; that rhyme is the
  point.

Like the generals, the six companions past the knight and the gladiator are not yet written. The
same discipline applies: author one end to end and copy its shape.

## The Bastion: sloth, designed

This is the second line worked out end to end, and it is load-bearing for the other five: it is where
the *vendor is quietly serving its sin* claim at the top of this file stops being a promise and
becomes a scene.

**The timeline is fifteen years, not thirty.** Rowan was a sixteen-year-old squire when Greywatch
fell and is thirty-one now; thirty put her the wrong side of fifty. Every file was moved.

**The arithmetic of the gate**, which is laid across three quests for the player to do before Rowan
ever does: **sixty** knights held Greywatch. When Acedia opened it and put the terms to her garrison,
**forty-one took them** and became her company. **Nineteen refused**, walked out with nothing, and the
Bastion would not have them back — nineteen knights returning with that story ends the martyr, and
the martyr is the only thing keeping the line manned. So the order struck them off and they turned to
the road. Slot 2 gives the player the nineteen (*The Names He Kept*); slot 5 gives them the
forty-one (*Greywatch Muster Roll*), which the order recites as a roll of martyrs; slot 9 says what
the forty-one actually counts. Nobody does the sum for the player.

### The Watch

The Bastion is not a shop that sells shields. It is the order that mans the line — a chain of warded
posts holding the demons out, each held by a knight sworn for life. **"Hold until relieved" is not a
battlefield formula. It is a vigil**, phrased that way because the thing on the other side never stops
pushing. The order's whole moral architecture rests on knights staying at posts that will kill them.

### Acedia, and what she did

She held the greatest post on the line and she was the order's living emblem — the doctrine is named
for her.

The Bastion wrote her post off. Rather than pay what her own oath cost, **she negotiated**: her life
and her company's lives, for the gate. No siege crisis, no last stand, no desperate hour. A deal. The
land beyond the fort — the towns the post existed to stand in front of — bought it.

**Her company said yes.** That is the mass version of the sin and the important half: she did not
merely set down her own oath, she took a whole company's with her, and every one of them chose it. The
price of the bargain was becoming what they had sworn to fight, and they took the terms anyway.
Corruption was the fee, not a misfortune. They are still a company, still disciplined, still wearing
the Bastion's forms in something else's service, and they are what meets the player at the end of the
line. They kept every part of the oath except the part that cost anything.

A plain coward is too small to be a general. The sin is not the cowardice — it is the **fifteen years
spent making the cowardice true**. She cannot hold *I was afraid to die*, so she built a doctrine over
it: no post is worth holding, relief never comes, the line was always a fiction. And then she went and
made it so. She walks the Watch telling knights exactly what she needs to be true, with the authority
of her name, and they set their shields down. The line is emptying because the woman who broke first
has to keep being right.

### The martyr

**Her name is on the Oathkeeper Shield, and the Bastion honors it.**
`data/items/armor/armor_oathkeeper_shield.lua` already ships the line — *"every Oathkeeper bears the
name of a knight who set theirs down; the Bastion keeps the list long, and reads it aloud."* The order
reads *set down* as **laid down**: died at the post. A roll of martyrs. The true reading is the other
one, and the Bastion recites a list of deserters as a list of saints. **The item needs no rewrite.**

So the doctrine that sends knights to die at their posts is sanctified by a woman who negotiated and
walked out, and fifteen years of deaths in her name were deaths for a fiction — a fiction which is also
the only thing keeping the line manned.

Which arms her with the one argument the player cannot easily answer, and it is an *acedia* argument
because it counsels doing nothing: *every knight on that line holds because of my name. Take it from
them and the Watch empties tonight. I do more for it as a lie than I ever did with a shield.*

**The Bastion knows.** Not ignorance — a decision. The leadership found out, weighed a hard truth
against a useful saint, and took the easier one. The order that preaches holding took the path of
least resistance about its own founder. That is the vendor serving its sin, and it is what the player
walks into at slot 8.

### Rowan, the same wound answered the other way

She was a squire on the relief column sent to Acedia's post, and it was ordered to turn back. She has
spent her life since being the relief that comes — which is why she rallies to a burning village that
is not hers, swears herself to a stranger, and stands in front of the body she swore to. She is
compulsively the arrival that failed to happen.

**She idolizes Acedia.** She swore on her name; every knight does. Her guilt is that she failed to
reach *her*.

The line's engine is that this survives each reveal until it doesn't, and the drama is watching her
defend the icon with progressively worse arguments. The fact that ends it: **Acedia opened the gate
before the relief was ever due.** There was no window to miss and no battle to arrive at. Rowan is
innocent, and she does not want to be — if she could not have come in time, there was nothing to come
*for*, and the martyr falls. She would rather be guilty. That refusal is slot 7 and it is the best
beat in the line.

The rank-4 shield names the general in its file comment, so the **player can connect it several quests
before Rowan does**. The gap is worth more than a simultaneous reveal; do not close it.

### Her oath

The vow that carries the line is the one she swore **to the player**, not the one the Bastion issued
her. "Hold until relieved" reads as procedure, because that is what it is — and the order's inability
to tell a regulation from a vow *is* the sin. Rowan recites it flat at slot 1, the way you recite
something you were handed.

Her own is two words, sworn in the ash of the prologue village (`data/conversations/prologue_flee.lua`):

> **We shall hold.**

The whole load is on the **we**. She does not promise to protect the player; she promises they are not
holding alone — the order's grammar, made plural. Its flaw is inside it: **she decided you were a "we"
without asking.** She would have said it to anyone burning that night, and you were never consulted.
It is also an apology aimed at the wrong person — she failed to reach Greywatch, so she is early for
you forever.

Oath two is **the same two words, meant at someone**. The wording never changes; what changes is that
she now *names* who she means by it, every fight — the first time she chooses rather than reflexes.
When she eventually names someone other than the player, that is the arc closing, not a betrayal.

The mechanics already say this and need no changes: `data/traits/trait_oathward.lua` sets `unit.guard`
**unconditionally, for whatever ally happens to be adjacent**, on a cooldown — undiscriminating by
design, which is the tell that oath one was never really about *you*. `trait_oathward_declared` is
stronger, uncooldowned, and one named unit only.

This is also what makes Acedia the exact inverse rather than a generic villain, and the code already
says so: `trait_unrelieved` **swears the party into pairs nobody chose** and bites whoever ends a turn
apart. Her entire mechanic is a forced *we* — a rigged demonstration that imposed bonds are a trap,
run on your own units. Rowan's *we* is offered; Acedia's is imposed. Same word, opposite authorship.

And her company said yes. **Forty-one people said "we" and then left** — that is slot 9, and it is the
strongest possible attack on the vow, because it is her own sentence in someone else's mouth, kept in
form and broken in substance.
3. **The oath with a decision in it.** Not owed to an order, an icon, or a name — only to the person in
   front of her. Earned at slot 8, and the reason it cannot be sworn to a name is that the name turned
   out to be Acedia's.

`data/traits/trait_oathward.lua` is oath 2 exactly: `onCombatStart` sets `unit.guard` unconditionally,
for whatever ally happens to be adjacent, on a cooldown. Reflexive, undiscriminating, thin.

**Oathward Declared** is oath 3: she *names* a ward at combat start. Stronger redirect, no cooldown,
that unit only — and nobody else gets anything. She can no longer be everywhere, and the player
chooses who she is for, every fight. When she eventually names someone other than `{name}`, that is
the arc closing, not a betrayal.

It is also the refutation of Acedia executed in a verb. Acedia's trait swears the player's party into
pairs they did not choose and punishes them for the arrangement — a rigged demonstration that imposed
bonds are a trap, run on your own units, by someone who needs the board to agree with her. Rowan walks
in having picked. *No post can be chosen* against *I chose this one*.

Two engine costs, neither large, both real: an in-place trait swap on a `bound` item (the Sworn Aegis
can never be replaced by a better shield — that is the point of it), and a combat-start target prompt
that works on mouse, keyboard, and gamepad like everything else in `ui/`. The cheap fallback is
auto-declaring the lowest-health ally, which keeps the mechanic and loses the choice — and the choice
is the character.

### The ten slots

Ten per line, not four. The four-quest shape cannot fill the ladder: the Colosseum's non-repeatable
quests total 85 reputation, rank 3 needs 100, and `blood_in_the_sand` — the grind meant to bridge
Champion to Legend — is itself gated at rank 3. **The authored template is a soft-lock**, and the
Wrath line needs six new quests before anything copies it.

The intended fix is to make standing a **count of distinct completed quests per sponsor** rather than
accumulated `rewardRep` points, which is what `docs/classes.md` already claims under Known debt and
the code has never done (`Player.addReputation`, `Vendor.rankFor`). Then `ranks = { 0, 3, 6, 9 }`,
rank 4 lands on the ninth, and slot 10 is the general gated behind it — preserving the rule that the
standing which puts the rank-4 item on the shelf is the standing that lets you face what it was
warning about. Repeatables must not count, or the grind walks back in.

| # | Slot | Rank | The Bastion's ten | What it costs Rowan |
|---|---|---|---|---|
| 1 | Introduction | 1 | **The Relief Column** — `protect` a supply train | recites the doctrine, names Acedia with reverence |
| 2 | The recruit | 1 | **The Ones Who Turned Back** — her old column's officers | admits she was the relief that never arrived |
| 3 | Complication | 1 | **Held Position** — `hold`; a garrison that will not stand down | first unease: is this what the icon makes? |
| 4 | Escalation | 2 | **The Long List** — `assassinate` a forsworn knight | the knight says something about Acedia; Rowan gets angry |
| 5 | The discovery | 2 | **What Greywatch Kept** — `reach`; the ruin | the gate was opened from inside — *she was betrayed* |
| 6 | Grind | 2 | **Muster** — `repeatable` bounty work | lines get shorter each repeat |
| 7 | **The turn** | 3 | **The Order That Was Given** — the archive | the gate opened before relief was due; she refuses absolution |
| 8 | The break | 3 | **The Bastion Knows** — the terms, under seal | nothing left to say; the Aegis is re-sworn here |
| 9 | The approach | 3 | **The Forty-First Day** — her company, alive | — |
| 10 | The general | 4 | **The Unrelieved** — `assassinate` | — |

The Aegis is re-sworn at 8, not after 10: the player needs Oathward Declared in hand for 9 and 10 or
the arc lands in a cutscene instead of on the board.

**Ten slots against three win types will read as the same quest seventy times.** The objective
resolver (`models/combat.lua`, `states/battle.lua`) knows `killAll`, `assassinate`, and `survive`. It
wants `protect` (a named unit lives), `reach` (get a unit to a tile), and `hold` (control tiles for n
turns) before the quests are written, not after. `hold` is the knight's entire thesis and is currently
unsayable.

Slots 7 and 8 are what a four-quest line never had room for, and they are the ones that make the claim
at the top of this file true. Every other line owes the same pair.

### The relic

**The Forsworn Pike** — a spear, no `class`, no `price`, carrying Acedia's trait. It differs in type
from Wrath's armor, as the seven keys require. Worn, it swears the bearer's party to each other:
bolstered together, punished apart. Strong, and it makes the party immobile — the same trap it was
when she carried it.

`gateHint = "past the gate that was opened from within"`.

Three other unbuyable items across the ten, and no more, or the 3×3 grid drowns: a **Relief Horn** at
slot 1 (swap places with an adjacent ally; their Wait becomes Defend), a **Greywatch Muster Roll** at
slot 5 (grid bonus scaling with adjacent allies), and one from slot 8. All carry `class = "knight"`
with no `price` — unbuyable, and still tallying toward knight growth (see `docs/classes.md`).

## Authoring the remaining six lines

### The line

The reputation ladder (0 / 40 / 100 / 200) doubles as the chapter clock. Wrath's line, as authored:

1. `arena_debut` — the introduction, prestige 1
2. `warlord_keep` — the escalation, prestige 3
3. `blood_in_the_sand` — `repeatable`, rank-3 gated: the grind from Champion to Legend
4. `general_wrath` — rank-**4** gated (Legend), prestige 5. The same standing that finally puts the
   Crimson Greataxe on the shelf is the standing that lets you face what the Greataxe was warning about.

A general's quest always carries `requiredRep = { vendor, rank = 4 }`, `rewardItems = { <relic> }`, a
`gateHint`, and `win = { type = "assassinate", target = <general id> }`. Assassinate, not `killAll`: the
guard is a wall to get through, not a thing to grind down.

### The engine cost, per general

Two of the six need **no engine work at all**. Start there.

| Sin | What the general needs | Engine |
|---|---|---|
| greed | an ability whose effect calls `fx.steal(fx.target)` | **none** — see `ability_pickpocket` |
| gluttony | an ability that calls `fx.heal(fx.user)` on hit | **none** — see `parasitic_staff` |
| envy | `ctx.copyOf(strongestPartyMember, ...)` from an `onCombatStart` trait | **none** — `Summon.copyOf` exists |
| pride | a trait hooking `onCast` to answer a spell with itself | hook is wired; write the trait |
| lust | a trait that seizes what was not offered | hook is wired; write the trait |
| sloth | a trait that punishes the abandoned oath | hook is wired; write the trait |

All four trait hooks (`onCombatStart`, `onDamaged`, `onCast`, `onDeath`) are dispatched from
`models/combat.lua` already. Writing a general is a `data/traits/<id>.lua` file, a
`data/characters/general_<sin>.lua` blueprint that names it in `traits`, a relic that names the same
trait, and a quest. Nothing in `models/` should need to change.

### The pattern, in four files

Read these together — they are one idea spread across the layers:

- `data/traits/trait_wrath_rising.lua` — the rule. `onDamaged` banks a damage bonus via `ctx.addBonus`.
- `data/status/status_wrath.lua` — the tell. Grants **nothing**; it exists so the player can watch the badge
  climb and understand, before it is too late, that they are the one sharpening her.
- `data/characters/character_general_wrath.lua` — modest opening stats, deliberately soft to magic. A Warlord hits
  harder on turn one. The danger is not what she starts as.
- `data/items/armor/armor_mail_of_the_unappeased.lua` — the relic, carrying `traits = { "trait_wrath_rising" }`.

The status is not the mechanic. A `statBonus` there would double-count the trait's own `addBonus`, and a
status cannot scale its bonus by magnitude anyway (`Status.statBonus` reads a static def table).
