# The Seven Deadly Sins and the Demon Lord

The endgame is not bolted onto the progression loop — it *is* the progression loop, followed to its
end. Each of the seven class vendors sells you gear, ranks you up, and walks you toward the sin it has
been quietly serving the whole time. Kill all seven generals and the Gate Below opens.

This document is the bible for that arc, and the template for finishing it.

**Sloth is the reference line** — ten quests, twenty-three scenes, built. Copy its shape, and copy the
way it was authored: premise first, then how each quest bears on the companion *and* on the sin, then
the objective, then the unique item. Doing that caught a slot that duplicated an existing quest and a
slot whose premise could not survive the question *"why is this a fight?"*.

**Wrath is four quests of ten, and its line is soft-locked** — see *The Colosseum* below, where the
remaining six are specified along with what Ira and Saber actually are.

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
| mage | pride | humility — meets a spell with a better-practised self, not a bigger one; the mage who is never finished |
| priest | lust | devotion — gives what is offered, refuses what is not |
| alchemist | envy | kindness — grants others' power instead of coveting it |

**The virtue is the spine, never the label.** A sin gets to be a personified abstraction — *Ira,
the Unappeased*. A virtue does not; it is a person with an ordinary name, and the virtue shows in
how they fight and what they will not do, never in what they are called. A companion named for her
virtue is the exact mistake this section exists to forbid.

**Every companion is a woman, and so is every general** — the whole war of appetite and answer is
fought between women. Companions carry **gender-neutral** names (Rowan the knight, Saber the
gladiator, Kaya the hunter); generals keep the Latin sin-register (*Ira*). The virtue is buried in
the name, not stamped on it: *Saber* is a blade, and in another tongue (*ṣabr*) it is patience
itself; *Kaya* is an ordinary name that in another tongue (*kifāya*) is *enough* — temperance itself.

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

All seven companions now have blueprints on disk — Rowan (knight), Saber (gladiator), Amana (priest),
Gyeom (mage), Kaya (hunter), Ren (alchemist) and Clem (rogue) — each with its signature relic and its
recruit and finale scenes. What is not yet built is the *middle* of every line: slots 3–9, the
second-form finale mechanics, and the second relics. The same discipline applies: author one end to end
and copy its shape. See each line's *What is built, and what is not* for the exact state.

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

Ten per line, not four. The four-quest shape cannot fill the ladder: the Colosseum's four quests
totalled 85 reputation and rank 3 needs 100, so the line could not reach its own rank-3 quest.
**The authored template was a soft-lock**, and every line needed six new quests before anything
copied it. All sixty slots now exist (see *State of the pass*, below).

**There is no grind. No quest is `repeatable`, and none should be.** That is a design rule, not a
tuning decision, and it is the reason the ladder is built the way it is: standing is earned by
*authored* quests only, so a line's nine non-repeatable slots must reach rank 4 on their own. They
do — 245–325 reputation per line against a 200-point rank 4, with the tightest line (the Bastion's
235) still clearing it. Nothing anywhere requires the player to replay anything.

Slot 6 used to be where the grind lived, and it is the slot the rule improves most. The beat it
carries — *the player becomes the hand that buries the evidence / empties the wood / feeds the next
working* — is an accusation exactly once and a chore every time after; farming it teaches the player
to tune out the thing it exists to say. Every slot 6 is now a single commissioned job with a date on
it (a feast, a term's end, a first frost, a quarter close, a muster Sunday), which says the same
sentence harder and ends.

The remaining ladder debt is the *shape*, not the reachability: on the points ladder, rank 4 now
lands a slot or two before the ninth, which loosens the rule that the standing putting the rank-4
item on the shelf is the standing that lets you face what it was warning about. The intended fix is
unchanged and is now the only thing that restores it — make standing a **count of distinct completed
quests per sponsor** rather than accumulated `rewardRep` points, which is what `docs/classes.md`
already claims under Known debt and the code has never done (`Player.addReputation`,
`Vendor.rankFor`). Then `ranks = { 0, 3, 6, 9 }`, rank 4 lands on the ninth, and slot 10 is the
general gated behind it. With no repeatables left, the old caveat (*repeatables must not count, or
the grind walks back in*) is moot: every quest counts, because every quest is authored.

| # | Slot | Rank | The Bastion's ten | What it costs Rowan |
|---|---|---|---|---|
| 1 | Introduction | 1 | **The Relief Column** — `protect` a supply train | recites the doctrine, names Acedia with reverence |
| 2 | The recruit | 1 | **The Ones Who Turned Back** — her old column's officers | admits she was the relief that never arrived |
| 3 | Complication | 1 | **Held Position** — `hold`; a garrison that will not stand down | first unease: is this what the icon makes? |
| 4 | Escalation | 2 | **The Long List** — `assassinate` a forsworn knight | the knight says something about Acedia; Rowan gets angry |
| 5 | The discovery | 2 | **What Greywatch Kept** — `reach`; the ruin | the gate was opened from inside — *she was betrayed* |
| 6 | Complicity | 2 | **Muster** — `assassinate`; the roll closed for the season's oath | the tent is half empty and nobody remarks on it |
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

## The Colosseum: wrath, designed

Four quests of this line ship; the other six are unwritten, and the section below is the spec. It is
the third line worked out end to end, and it exists to prove the *vendor is quietly serving its sin*
claim a second time in a completely different register: the Bastion serves sloth by **declining to
notice**, and the Colosseum serves wrath by **selling tickets to it**.

**The line was soft-locked, and that was a shipping bug rather than a design note.** `arena_debut`
paid 25 reputation and `warlord_keep` 60 — 85 total, against a `blood_in_the_sand` gated at rank 3
(100) and a `general_wrath` at rank 4 (200). There was no way to earn the fifteen points that
unlocked the quest that earned the rest. Six more quests was the fix, which is the same reason the
Bastion has ten, and they are now on disk: the line pays 325 across its nine.

### The league and the stables

The Colosseum is a venue and a league; it is not the fighters. The real powers are the **stables** —
houses with rosters, records, and dynasties, who put teams on the sand against each other. This is the
Roman shape and it should stay: a *ludus* under a *lanista*, competing school against school. What a
vendor's patronage actually buys the player is a stable's backing, which is why the shelf is the
shelf.

The player arrives with **no house**. That matters: they are the only team on the sand with nothing
behind it, and it is the entire reason the line's companion will sign with them.

### The Perennial, and what it manufactures

*(Name provisional — it wants to sound like an institution a champion would be proud to wear, not a
villain's lair.)*

The reigning stable, champions for longer than anyone finds strange. Other houses recruit, buy and
train. **This one produces.** It takes children and makes instruments, and it has been winning for a
very long time because its product does not feel anything.

That is the sin, and it is a business rather than a person: **wrath is not a woman here, it is a
house that discovered rage outperforms morale.** Ira is not the Perennial's victim. She is its
masterpiece.

### Ira, and the one thing that ever reached her

Blind from birth. Raised in the program: no fear response, no pain response, no attachment — nothing
that could interfere with the work. She was superb, and she felt nothing about it, and that was the
specification.

Then something got through, and what got through was **anger**.

Not joy, not grief, not love. The first sensation of her life was rage — overwhelming, and *hers*, and
the only evidence ever placed in her hands that there was a person inside the instrument. **She has
been chasing it since.** Not for revenge. Because it is the only proof she exists.

**What triggered it should stay small and bureaucratic, never operatic.** A handler assigned to her
broke protocol — talked to her, described things to her, gave her a name. The first attachment of her
life. The stable noticed, and **reassigned them.** Not a murder. A form.

She has never learned where they went, whether they are alive, or whether they think of her. Which is
crueller than a death and is the mechanical heart of the sin: **there is no one to be paid by.** No
grave to visit, no throat to cut, no confession that would settle it. The debt cannot be closed
because there is no debtor, so the only thing she can still do about it is feel it — and the only way
to feel anything is to be hit.

**Her rule is that, and it is already half-built.** `data/traits/trait_wrath_rising.lua` currently
banks a bonus `onDamaged`; it wants rewriting so damage scales as her **health falls**. The
difference is characterisation, not tuning: the threshold for sensation is that high. She has to be
nearly destroyed before anything reaches her. She is not most dangerous when winning — she is most
*awake* when dying, and she goes looking for it.

Her kit should also be immune to fear, charm, and pain-based effects. Not because she is strong.
Because **nothing gets in.** The immunities are the tragedy, not the power.

### The house that cannot admit what it built

The Perennial does not fear Ira and does not appease her. It **schedules** her, and it cannot afford
to say what she is, because saying it means saying what the program is.

That is the vendor serving its sin, and it is uglier than the Bastion's version. The Bastion took the
easy path about something that had already happened. The Colosseum is **still running the intake**.

### Saber, the same machine answered the other way

She came out of the same program, and the conditioning **failed on her**. She kept flinching, kept
caring about the wrong things, felt everything they were trying to burn out. So she was washed out
and put to ordinary use — a fighter, not an instrument.

Which means she has spent her life being told that feeling is a defect, and her virtue is not
temperament but **the discipline she invented to survive having emotions in a place that punished
them.** She could not stop feeling, so she learned to hold. That is patience, earned rather than
possessed, and it is exactly the answer Ira refused.

**She escaped, and she kept fighting anyway, because she loves it.** Not the killing — the craft, the
read, the moment. The sport was never what was wrong. She fights for whoever books her, house to
house, a free agent of the sand.

**What she stopped for.** Ordered to execute helpless people to pad a card, she put the sword down in
front of a paying crowd — and the house had someone else finish it while she stood there. **The
people died anyway.** Her one great moral act saved no one and cost her the card, her name, and any
house that wanted a reliable name on a contract. She has never known whether it was courage or vanity.

**Her flaw, and it is not sullenness.** She loves the thing that makes Iras. Every superb bout she
gives the crowd is an argument that the arena is fine — she is the acceptable face of it, the free
agent who proves you can do this cleanly. The machine that built Ira exists because the sport sells.
She tells herself the two are separable. They are not, and the back half of the line is where she has
to hold that.

**Her relationship to Ira is recognition, not love, and they were never partners.** Saber is not
grieving a friend; she is looking at the version of herself the process completed, and she is the only
person in the building who understands that the thing under the sand is a *manufactured woman* rather
than a monster.

### What the line does to her

Saber's whole identity is one sentence: **I do not kill people who cannot choose.**

Ira cannot choose. Blind from birth, raised into numbness, handed exactly one feeling and no equipment
for any other. In the only sense this story recognises, she is **the most helpless person in the
building** — and Saber has to kill her anyway.

The line ends by requiring her to break the rule she is built out of, and the cost is that **it is
still right**. That is not a twist. It is a price.

**The turn (slot 7) is the fact that kills Saber's hope of freeing her:** there is no third state. The
program did not leave one. Freedom, for Ira, is a return to the numbness — she is not choosing rage
over peace, she is choosing existence over nothing, and she has already tried the alternative for
twenty years. Somewhere in that scene Ira is briefly reachable, and what surfaces is neither a monster
nor a plea:

> *I know what you're offering. I had it. There was no one in it.*

**She must never ask to die.** That would let Saber off. She wants to keep feeling, right to the end,
and Saber has to do it to her regardless.

### Her ability, and why it is the whole line in arithmetic

> **Ira scales as her own health falls. Saber scales with her target's health.**

Saber hits hardest against a target at **full** health and falls off as they weaken: she ends things
in one motion or not at all. Deliberately *not* an accumulate-by-idling design — dead turns are not
patience, they are downtime. This is patience as a verb: pick the moment, commit, done.

The two of them are **mathematically opposed on the same axis**, and every bout from the debut onward
is teaching the player the lesson the general will examine them on. Ira wants a long trade because
every blow wakes her up; Saber is worthless in a long trade and devastating on the opening.

**Her second relic, late in the line:** one strike per battle at full value regardless of the target's
health, **whenever she chooses**. v1 lets the arithmetic pick her moment; v2 gives her the moment.
*Patience becomes a choice of when* — the same move as Rowan's declared ward, in a different idiom,
with no downtime anywhere in it.

She currently has **no signature item and no trait at all** (`data/characters/character_saber.lua` is
a greatsword, a potion, and seven empty cells). Both relics are new work.

### The ten slots

| # | Slot | Rank | The Colosseum's ten | What it costs Saber |
|---|---|---|---|---|
| 1 | Introduction | 1 | **Debut on the Sand** — beat the hired veteran; she signs with the only house that isn't one | nothing yet; she is enjoying herself |
| 2 | The recruit | 1 | **The Padded Card** — `killAll`+`protect`; the card padded with slaughter | says nothing about why she knows |
| 3 | Complication | 1 | stable against stable, the sport at its best | the player learns why she loves it |
| 4 | Escalation | 2 | **The Perennial's Roster** — `killAll`; met as opponents | she recognises the training and won't say so |
| 5 | The discovery | 2 | **The Intake** — `reach`; the program, not its output | admits she came out of it |
| 6 | Complicity | 2 | **Blood in the Sand** — `killAll`+`protect`; the player is the draw now, and their undercard is padded for them | implicates them both; she asks whether they will keep the billing |
| 7 | **The turn** | 3 | **No Third State** — `survive`; Ira, briefly reachable | the hope dies |
| 8 | The break | 3 | **Naming the Day** — `assassinate`; she stops deferring | second relic; patience becomes a choice |
| 9 | The approach | 3 | **What the House Does Instead** — `assassinate`; the stable cornered | — |
| 10 | The general | 4 | **The Unappeased** — `assassinate` | she kills someone who cannot choose |

`arena_debut`, `warlord_keep`, `blood_in_the_sand` and `general_wrath` exist and map onto 1, 3-ish, 6
and 10; the rest is new. Slot 7 needs Ira to speak **without being a fight**, and the only seam for
antagonist dialogue is currently attached to a battle (`map.objective.opening`) — that is a small
engine question, not a design one.

### The relic

**Mail of the Unappeased** ships, carrying her rule, and its text tracks the trait.
`gateHint = "beneath the sand, where the roaring was loudest"` is written and correct.

### What is built, and what is not

**Built:** the arithmetic on both sides — `trait_wrath_rising` (health curve + per-blow contact term)
and `weapon_first_motion` (Saber's bound signature, scaling with the *target's* health), covered by
tests in `tests/trait_spec.lua` and `tests/weapon_spec.lua`. Slot 1 (`arena_debut`) is rebuilt
premise-first and grants Saber through the quest's own `rewardCharacter`.

**Not built:** slots 2–5 and 7–9 (six new quests), Saber's second relic, and every scene past the
debut.

### Open questions, deliberately unresolved

Three things are placeholders, and the line should not go much further before they are settled —
slots 2–4 are where the player meets the house properly, and all three land there.

1. **The stable's name.** "The Perennial" throughout this section is a placeholder. It wants to sound
   like an institution a champion would be proud to wear, not a villain's lair.
2. **Ira's handler** — the one who broke protocol, gave her a name, and was *reassigned by form*. Who
   they were and what the paperwork said. This is load-bearing rather than colour: it is the reason
   nothing can settle her, because there is no debtor and no grave, only a filing decision.
3. **Slot 7's seam.** The turn needs Ira to speak *without being a fight*, and every antagonist
   seam that exists is attached to a battle (`map.objective.opening`, `states/battle.lua`'s
   `openingConversation`). A quest-level `opening` plays over the overworld and could carry it, but
   the scene wants staging closer to a hub panel. Small engine question, unanswered.

### One rejected option, and why

Her rule feeds **damage only**, never defense or speed. Making the blow-count term raise her survivability
would punish the player twice for the same mistake — grinding her down is already the losing line, and
a boss who also grows tankier as you do it gives them no readable way out. The fight has to stay
legible: one number climbing, one lesson (*end it fast or do not start*), and a counterplay the player
has been holding since the debut bout.

## The Cathedral: lust, designed

The fourth line worked out end to end, and it proves the *vendor is quietly serving its sin* claim in
a third register. The Bastion serves sloth by **declining to notice**; the Colosseum serves wrath by
**selling tickets**; the Cathedral serves lust by **hiding it at the altar** — a beloved, working
faith with an atrocity buried at its top, known to almost no one.

### The church, and what almost no one sees

To nearly everyone the Cathedral is exactly what it appears: a **beloved, functioning church.**
People attend, keep its feasts, and revere its **holy warriors** — the *anointed*, orphans and
refugees it took in and raised into selfless soldiers who gladly die fighting demons. Taking in the
frontier's orphans, its poor, and above all the **refugees the war itself produces** is a public,
honored charity — the road out of poverty a family is proud to give a child to. (It is the devshirme
in a cassock; and, like Claymore's Organization, the institution quietly profits from the disaster it
fights.) Taken children are sorted onto two tracks: most are made **anointed** — soldiers, and
**blooded**; a few are kept back as **acolytes** — clergy, and **never blooded.**

**The great majority of the clergy, and every worshipper, are ordinary and sincere and know none of
what follows.** This is not a mask over a dungeon. It is a real faith with a secret held by a small
inner circle around its Saint. Most people are just normal — which is what makes the rot so hard to
name and harder to prove.

### The blooding

The "holy" magic that makes an anointed is **Luxuria's demonic blood**, and the rite that puts it
into a child — the **blooding** — kills many of them. Three outcomes, and the church has a face for
each:

- **It takes.** The child becomes an obedient super-soldier, seeded with the demon's blood and hers
  to command at a word — and *unaware of it,* believing itself holy. These are the anointed the world
  cheers.
- **It takes wrong.** The child becomes a feral, half-made thing. The church hunts these and calls
  them **demons from the wild** — the very "corruption" it hires the player to purge.
- **It kills.** The body is carted off and **dumped in an unmarked pit.** The intake register writes
  the child down as *ascended to the Light.* The roll of the church's glorious dead is its casualty
  list, read as a roll of saints — the same trick the Bastion plays with its martyrs, and it needs no
  more invention than that.

### Luxuria, the Unbidden — the demon at the altar

Luxuria is a **human who made a pact with the Demon Lord** (see *Every general is a fallen human*,
below), gaining the power she now passes off as holiness. She did not rise through the Cathedral;
she **infiltrated** it and took the seat of its most revered living **Saint** — the one who blesses,
which is to say bloods, every soldier. Behind the beloved institution's back she has seeded the whole
anointed order as a **sleeper army**, to turn on humanity when the Gate reopens. The demons do not
only besiege the walls; the church has grown them a blade behind it and calls it holy.

Her rule is **"takes what is not offered,"** and it is already half-built on disk. `trait_rapture`
(`data/traits/trait_rapture.lua`) drinks the stamina and mana a target was **hoarding** and takes it
into herself as health — so a party that husbands resources for the big turn feeds her the whole
time. The counterplay is the sin read as tactics: **spend; let nothing sit unspent near her.** The
finale adds a second half — she **turns the blooded**: a unit she has drained enough flips to her
side (reusing `status_charm`), the "army turns on humankind" made playable. The one soul she can
never touch is Amana, who **carries none of her blood** (see the foil, below). See *Engine work* in
the plan and the drain-and-turn note; both are new work over the shipped Rapture.

**Killing her frees nothing automatically.** The blooded stay blooded and hers; the sleeper army is a
standing threat that survives into Act 2 (`the_gate_below` / the Hollow Crown). You cannot break ten
thousand seedings from the outside.

### Amana, the witness — the same sin answered the other way

Amana is an **acolyte, not a soldier** — clergy track, **never blooded.** There was never any of
Luxuria's blood in her to command, so there is nothing in her to turn: her immunity is not willpower
and not a corruption she fought off, **she is simply not one of the made.** (This is the plainer, and
better, version of the foil-immunity the Colosseum states for Saber, whose conditioning merely
*failed*.) `trait_devotion_unbidden` makes charm and seizure **shed off her** for exactly that reason
— no blood, nothing to seize.

What sets her against the Cathedral is what she **saw** — what almost no one in the church ever
learns. Close enough to the blooding rites (which few acolytes witness) to work out what they do to
children, she found the feral failures hunted as "demons from the wild," and she found the **pits.**
She could not unsee it, and when she began sheltering children marked for the blooding, the church
branded her a **fallen** Confessor and sent the player to purge her. She is a **witness who broke, not
a chosen one who resisted.**

Her quieter cost is the mark of the house that raised her: taken as a child, **renamed for a virtue**
(*Amana* — Arabic *amāna*, a trust returned intact — is the Cathedral's brand, not her name), taught
to want **nothing** for herself. The line's quiet question is whether she can keep **one** thing
without it being a theft. The answer is her birth-name, and the finale is where she keeps it.

### The line's rhyme, and the finale

Every line has a rhyme; the Cathedral **opens and closes on "refuses what is not offered."** At the
head Amana refuses to let the faith **take** a stranger (the recruit fight). At the end Luxuria — who
holds the intake rolls and knows the birth-name behind the cloth — offers Amana **her own self back,**
*"Kneel, and it is yours again."* It is a taking dressed as a gift: to accept the name from the hand
that dumps children in pits is to let the monster be the one who *gives* Amana a self, and so be owed.
Amana refuses — and the refusal is a **choice of character,** not a mechanic. Her shipped lines carry
it: *"That name is not yours to give… I gave it to myself. And that, I am keeping."*
(`data/conversations/cathedral_general_lust_confront.lua` — **needs a rewrite**: it currently frames
Luxuria as Amana's emptied cohort-sister, which the *outside demon* decision above has retired.)

### The ten slots

Ten against the four-rank ladder (`ranks = { 0, 40, 100, 200 }`; Penitent → Acolyte → Confessor →
Saint), the general behind rank 4 — the same standing that puts the **Censer of Dawn** on the shelf,
whose file comment is the spec. Reuses four shipped quests; six are new. Amana's plea at slot 2 tells
the player *what* is happening; the middle makes them **see it** and trace it upward, to the one fact
Amana cannot yet face (slot 7): the Saint she still believes in is the demon.

| # | Slot | Rank | The Cathedral's ten | What it costs / reveals |
|---|---|---|---|---|
| 1 | Introduction | 1 | **The Haunted Mill** — `assassinate` | child ghosts scream clues about the church's sins; horror planted before it is understood |
| 2 | The recruit | 1 | **The Fallen Confessor** — `killAll` | bested, Amana stays your hand and her **plea reveals the truth**; she joins |
| 3 | Complication | 1 | **The Rite of Ashes** — `survive` | hold consecrated ground; why must the censer burn throughout? |
| 4 | Escalation | 2 | **The Purge in the Fold** — `killAll` | the "corrupted" are **failed bloodings** — the church's own children |
| 5 | The discovery | 2 | **The Roll of the Given** — `reach`/`killAll` | the register of "ascended saints" set against the **pit** — it is a casualty list |
| 6 | Complicity | 2 | **Cleansing Work** — `killAll`; the diocese tidied before the Feast of the Ascended | purge the failed bloodings; the player becomes the hand that buries the evidence |
| 7 | **The turn** | 3 | *(no fight)* | **the Saint knew; the Saint is the demon** — Amana's last belief falls |
| 8 | The break | 3 | **The Kept Trust** — `assassinate` | the Kept-Trust beat: she keeps one thing for herself, and it is not a theft |
| 9 | The approach | 3 | **The Saint Unmasked** — `assassinate` | the scale of what her death will **not** stop |
| 10 | The general | 4 | **Luxuria, the Unbidden** — `assassinate` | two-phase (human Saint → demon); she turns your anointed escort; the sleepers remain |

`haunted_mill`, `rite_of_ashes`, `fallen_confessor` and `general_lust` exist; slots 4–9, the recruit
**plea** scene (a post-battle `outro`), and every mid-line scene are new. Slot 7 needs the antagonist
to **speak without a fight** — the same seam flagged for Wrath's slot 7. The rep-ladder soft-lock is
gone with the ten slots on disk (the nine pay 305 against a 200-point rank 4); what is left is the
ladder's *shape*, which still wants standing as a **count of distinct completed quests**
(`ranks = { 0, 3, 6, 9 }`) to put rank 4 back on the ninth.

### The relic, and the other unbuyables

**Reliquary of the Unbidden** (`utility_reliquary_unbidden.lua`, ships) — the vessel of Luxuria's
blood, carrying `trait_rapture` for whoever lifts it, `gateHint` written. Two other unbuyables across
the middle, no more (the 3×3 grid budget): an **intake register** at slot 5 (grid bonus scaling with
adjacent allies, à la the Muster Roll) and one from slot 8. All carry `class = "priest"`, no `price`.

### What is built, and what is not

**Built:** both ends — `fallen_confessor` (recruit, `rewardCharacter = character_amana`) and
`general_lust` (finale, rank-4, drops the Reliquary + `gateHint`); the characters; Amana's signature
`utility_reliquary_kept_trust`; the traits `trait_rapture` / `trait_devotion_unbidden`; the two
confront scenes; `tests/devotion_spec.lua`.

**Not built:** slots 4–9 (six quests) and their scenes; the recruit **plea** `outro`; the
`character_anointed` / `character_anointed_failed` / `character_child_ghost` blueprints; the
finale kit rework (**drain-and-turn**, and the **two-phase transform**); and the finale-scene
rewrite. See the plan for the authoring order.

## The Hunter's Lodge: gluttony, designed

The fifth line worked out end to end. It proves *the vendor is quietly serving its sin* in a fourth
register. The Bastion serves sloth by **declining to notice**; the Colosseum serves wrath by
**selling tickets**; the Cathedral serves lust by **hiding it at the altar**; the Hunter's Lodge
serves gluttony two ways at once — it **licenses the excess as a cull** (pest work, population
control, *the beast was dangerous*), and it **lionizes the hunter who never stops** as its greatest
legend. Gluttony here is not a bottomless stomach; it is **waste** — killing far past need, for the
trophy and the thrill, and leaving the rest to rot. The truest gluttony is *too much,* not merely
*hungry.*

### The Lodge, and what almost no one sees

To nearly everyone the Lodge is exactly what it appears: a **genuinely useful guild.** It clears the
real dangerous beasts, it feeds the town, it pays honest coin for hard, respected work, and **most of
its hunters take only the bounties that need taking.** The rot is not the rank and file. It is the
**thing the Lodge does to its greatest,** known to a small circle at the top, and it is the reason
the **bounty board never closes.**

**The Grand Hunters all turn into beasts.** Rank 4 — the title every tracker is raised to want — is a
fattening. Hunt the sacred long enough, kill enough wardens of the deep wood, and the hunter
*becomes* one: the apex predator at the center of the wild, the very thing the Lodge exists to hunt.
And that is not the disaster it looks like. **It is the business model.** When the sacred beasts run
low, the Lodge's own legends become the next game; the board never closes because the prey renews
itself from the hunters' own ranks. The Lodge makes monsters the way a farm makes meat and calls the
making an honor. Some of the wardens of the deep wood the player is sent to *cull* are the Grand
Hunters of years past — trophies on the wall that used to have names. This is not a mask over a
slaughterhouse; it is a respected craft that eats its own greatest and celebrates the eating, and
that is what makes the rot so hard to name.

### Gula, the cursed hunter — the appetite in the deep wood

Gula was, once, exactly what the Lodge still worships: **the finest hunter the region ever produced,
celebrated and real** — and she is the Grand Hunter turning *now,* the current head of the cull's
own harvest. Every Grand Hunter turns, and most turn into a mere beast — powerful, mindless, the next
year's game. Gula did not. She made a **pact with the Demon Lord** (see *Every general is a fallen
human*, below), and so she did not merely turn; she became the **general** — the crowned apex of the
apexes, keeping mind enough to go on hunting for the pleasure of it. What the bargain gave her was
not more strength. It was **appetite:** it turned the *pleasure* of the kill into a compulsion that
sates less each time and demands the next one sooner. She has killed her way through the whole deep
wood since, and wasted nearly all of it — the thrill is the point, never the meat — and she is now
mostly the beast at its center, exactly the fate the Lodge warns of, cultivates, and denies.
(Bloodborne's rule made literal: *the more you hunt, the more beast you become;* Erysichthon, whom
Famine ate alive for felling the sacred grove; Actaeon, the hunter run down as a stag by his own
hounds.)

Her rule is **"never stops,"** and she is the cheapest general on the board to build: **heal-on-hit**
— every blow she lands feeds her, `fx.heal(fx.user)`, the mechanic already shipped on
`weapon_parasitic_staff` (no new engine work). The counterplay is the sin read as tactics: **starve
her.** Do not feed the long trade — burst her down, kill clean and fast, deny her the grind; a party
that stands and swings turn after turn only fattens her. Temperance as tactics is the discipline to
**stop feeding the hunt.**

**Killing her frees nothing automatically.** The deep wood she stripped does not grow back, and the
appetite is the Lodge's, not hers alone: kill Gula and the Lodge simply crowns its next Grand Hunter,
who will in time make the wood its next beast. The cycle is institutional, and you cannot end a
practice by killing one of its products — nor un-eat a forest.

### Kaya, the one who stops — the wild's own answer

Kaya is a hunter **intertwined with the deep wood.** She lives in it, not at the Lodge, and she hunts
**for food, never for sport:** she takes only what she needs, wastes nothing, and the wild does not
turn against her (the Ainu ethic of Golden Kamuy's Asirpa; Mononoke's San, who runs with wolves — as
Kaya runs with the one on her Wolfsong Horn). Her name is Arabic *kifāya,* **sufficiency, "it is
enough,"** the virtue buried and not stamped, the way *Saber* is patience and *Amana* is a trust
(character_saber.lua, character_amana.lua). Same craft as Gula, opposite answer: gluttony never
stops; temperance is **the hunt that knows when to stop.**

She is **not Gula's kin, shares no origin with her, and is not the Lodge's outcast** — she is simply
the wild's own hunter, the one who was never greedy. She joins the party as a **guide.** The Lodge's
board pushes the player deeper and deeper after the "greatest game," and no outsider reaches the
heart of the deep wood — where the beast the Lodge worships now ranges — without someone the wild
knows. Kaya agrees to lead them, for her own reason: the thing devouring the wood is devouring the
living world she is part of, and temperance is the only thing that ends gluttony. Her recruit quest
is a **guide-join, not a purge** — she and her wolf turn back the wild that would swallow the player,
and she takes them in. (No branded-fugitive beat; the Lodge and Kaya are not at open war — her
quarrel is with the *sin,* the wanton devouring, not the guild's rank and file.)

Her foil-immunity, stated as cleanly as Amana's *"simply not one of the made"*: Gula's hunger feeds
on **excess** — on the hunter who takes more than the kill needs. **There is nothing on Kaya to
eat.** She carries no surplus, holds nothing back, kills clean and for food alone; when Gula strikes
her the hunger finds no purchase. Not willpower, not a corruption she fought off — she simply **wants
for nothing,** and you cannot glut on that. This rides on her bound relic, not on her blueprint (a
blueprint's own `traits` are never collected — models/trait.lua).

And it is the same reason she is **the one hunter who will never turn.** The turning is the wage of
excess — hunt the sacred past need and you become it — so a hunter who never takes past need is a
Grand Hunter the curse cannot claim. Kaya is exactly the tracker the Lodge would love to crown, and
she is proof the beast is a *choice,* not a fate: the honor they offer their greatest is the very
thing she declines. (This is why the Lodge covets her and cannot make her; it is not open war, it is
a door she keeps shut.)

Her quiet cost and question are the temperance beat in personal form. She kills only for need, and
the hardest thing the wood ever asks of her is a kill that is *not* for food: **Gula must die for the
wild to live.** The question is whether taking that one life betrays the balance she keeps — and the
answer is that **necessity, not appetite, is what temperance is for.** She takes the one shot that is
needed, cleanly, and lays the bow down. That is why the last arrow at the finale is hers.

### The line's rhyme, and the finale

Every line has a rhyme; the Hunter's Lodge **opens and closes on "enough."** At the head Kaya is the
guide who **kills only for what she needs** and passes up every trophy the board would pay for —
restraint shown, not preached. At the end Gula, half-turned and never sated, **recognizes Kaya as a
hunter of the same wild,** and offers her the pact's oldest promise: the hunt without end, the trophy
without limit — *"take it, and you never have to stop again."* To accept is to become the beast. Kaya
refuses — the refusal is a **choice of character,** not a mechanic — then looses **the one shot that
is needed and no more,** and lays the bow down. She is the one who knows *enough.*

### The ten slots

Ten against the four-rank ladder (`ranks = { 0, 40, 100, 200 }`; Tracker → Stalker → Beastslayer →
Grand Hunter), the general behind rank 4 — the same standing that puts the **Hornbow of the Hunt** on
the shelf, whose file comment is the spec. One shipped quest is reused (`sacred_stag`); the rest are
new. The middle makes the player **see** the board never closes and trace it inward, to the deep wood
and the one fact Kaya cannot yet face (slot 7): the beasts she culls were hunters, the honor is a
fattening, and the Lodge grows its own game from its own greatest.

| # | Slot | Rank | The Lodge's ten | What it costs / reveals |
|---|---|---|---|---|
| 1 | Introduction | 1 | **The Sacred Stag** — `assassinate` *(ships)* | the Lodge wants the white stag's antlers; the herd calls it something else — unease planted before it is named |
| 2 | The recruit | 1 | **[The Guide]** — `survive`/co-op | pushed deep after a bounty, the player is nearly swallowed by the wild; Kaya and her wolf turn it back, and she agrees to **guide** them toward the beast at the wood's heart. She joins (guide-join, not a purge) |
| 3 | Complication | 1 | **The Starving Dark** — `hold` | camped deeper in; hold through the night against the beasts Gula's spreading kills have driven mad and starving |
| 4 | Escalation | 2 | **The Manufactured Cull** — `killAll`+`protect` | a "dangerous beast" bounty is a mother over her young / a beast that never threatened anyone — the cull is **manufactured** |
| 5 | The discovery | 2 | **The Silent Wood** — `reach`/`killAll` | the bounty ledger against a wood gone quiet — a record of **extinction** — and one "beast" on the wall **wore a Grand Hunter's name:** the game is the guild's own |
| 6 | Complicity | 2 | **Closing the Board** — `killAll`; the book cleared before first frost, with a supper after | the player becomes the **hand that empties the wood**, and it will be full again in spring |
| 7 | **The turn** | 3 | *(no fight)* | **the beast at the wood's heart is Gula,** and every Grand Hunter turns — the honor is a fattening, the Lodge farms its own; Kaya learns what the crown she'd be offered really is (there but for restraint) |
| 8 | The break | 3 | **One Shot, and Stop** — `assassinate` | the temperance beat: Kaya takes **one** shot and stops — stopping is not quitting |
| 9 | The approach | 3 | **Into the Deep Wood** — `assassinate` | into the deep wood; the scale of what her death will **not** undo — a wild already stripped |
| 10 | The general | 4 | **Gula** — `assassinate` | two-phase (human huntress → the beast she became); she **devours the fallen** to heal; the stripped wild remains |

`sacred_stag` exists; the recruit (slot 2), the finale (slot 10), the recruit `outro` (Kaya's terms
— why she'll guide you), and every mid-line scene are new. Slot 7 needs the antagonist to **speak
without a fight** — the same seam flagged for Wrath's and Lust's slot 7. The rep-ladder soft-lock is
gone with the ten slots on disk (the nine pay 285 against a 200-point rank 4); what is left is the
ladder's *shape*, which still wants standing as a **count of distinct completed quests**.

### The relic, and Kaya's signature

**The general's drop — Maw of the Unfed** (parallel to the Reliquary of the Unbidden): a trophy taken
from the warden Gula killed to begin her fall, now the vessel of her appetite — carrying the
heal-on-hit trait for whoever lifts it, `noSteal`, no `class`, no `price`, `gateHint` written into
its flavor and consumed by `the_gate_below`. Her grid weapon beside it is a **gralloch knife** (the
gutting blade read as consumption — heal-on-hit), gluttony's reading of the hunter's kit the way the
Censer of Ashes is lust's.

**Kaya's signature is the Wolfsong Horn** (`utility_wolfsong_horn.lua`), and it is built. A wolf
fields itself at her side at the opening bell (`trait_wolf_companion`) — one wolf, granted once and
**never resummoned.** Riding on the same relic is her signature, the **Quieting Howl**: it does not
kill, it *stops* — "the hunt that knows when to stop" turned on the enemy. The horn **charges as the
wolf draws blood** (the summon's damage banks onto her, the new `companionDamage` tally) and can be
sounded **only while the wolf still stands**; when it is, every foe within two tiles of Kaya *or* her
wolf is **rooted**. A dead wolf silences the howl — her control is only as alive as the bond is — and
it re-locks after each use, so a wolf that keeps biting can raise it again. (Built on the
conditional-unlock signature system, as on Rowan's `armor_sworn_aegis`; a `when` + `count` gate keys
it to a living, bloodied wolf — see `Combat.unlockReady`.)

Read as tactics against Gula: rooting the ring lets a kiting archer break the long trade instead of
feeding a heal-on-hit foe — temperance as the counter to gluttony.

The wolves fight like a pack now: a wolf's bite **gives ground a tile and slips any melee counter**
(`weapon_wolf_fangs`, the hit-and-run every wolf makes — companion, grunt, and alpha alike), which
falls out of the answer-timing rule for free (a counter is thrown only once the swing has fully
resolved, and re-checks reach; a wolf a tile away is out of it — `Combat.beginAnswers`).

Still to fold in when the general is built: the **temperance trait** that makes Gula's hunger find no
purchase on Kaya (*nothing to eat*), the way Amana's reliquary carries `trait_devotion_unbidden`. The
earlier **Wolfsong Spirit true-call** (a blood-price summon) is retired from the horn; its blueprint
(`character_wolfsong_spirit`) and `trait_blood_price` are shelved, kept for later reuse.

### Gula and the two late rules

Gula obeys both all-general rules (see *Every general is a fallen human*, below). **Human first form
→ demonic second:** the human huntress sheds into the **beast she has been becoming** — the apex
monster at the center of the deep wood, the thing the Lodge exists to hunt. Her transform is not just
her own; it is the Lodge's whole engine shown once and live — **the turning every Grand Hunter
undergoes,** here made a boss fight instead of a slow disappearance into the wood. Her beast form
should share a **visual lineage** with the lesser turned hunters the mid-line meets — the shape the
wild takes when a Grand Hunter goes under, Gula simply the apex of it — so the finale reads as *the
biggest of a kind the player already fears,* not a one-off monster (uses the shared
two-phase-transform subsystem, not yet built). **The second finale mechanic** (parallel to Luxuria
turning the blooded): she **devours the fallen** — any downed unit adjacent to her, even her own
hunters, is consumed to heal her toward full: gluttony that eats everything, including its own. Both
are deferred, flagged as new work.

### What is built, and what is not

**Built:** the `hunters_lodge` building + vendor (`sin = "gluttony"`), `growth/hunter`, the rank-4
foreshadow relic `weapon_hornbow_of_the_hunt`, the *wild-game* beast roster (`character_stag_beast`,
`character_boar`, `character_wolf_alpha`, `character_dire_bear` — ordinary animals, the honest
bounties), and the `fx.heal(fx.user)` exemplar (`weapon_parasitic_staff`). Both characters —
`character_kaya` (temperance hunter, Wolfsong Horn centered, recruited as a **guide** so no
`boss = true` — nothing fights her) and `character_general_gluttony` (**Gula**, `boss = true`). Gula's
rule `trait_ravenous` (the shipped heal-on-hit half, `onCast`) on her **Maw of the Unfed** relic
(rank-4 drop, `noSteal`, `gateHint = "at the heart of the wood the hunt hollowed out"`), plus her
`weapon_gralloch_knife` (heal-on-hit inline). Kaya's Wolfsong Horn was already forged. Three of the ten
quests — slot 1 (`sacred_stag`), the recruit slot 2 (`the_guide`, a `survive` guide-join,
`rewardCharacter = "character_kaya"`), slot 5 (`the_silent_wood`), and slot 10 (`general_gluttony`,
rank-4 gated, drops the Maw + `gateHint`). `general_gluttony` is in `the_gate_below` `requiredQuests`.
Four conversations — `vendor_hunters_lodge_intro`, `hunters_lodge_the_guide_confront`, `kaya_joins`,
`hunters_lodge_general_gluttony_confront`. Coverage in `tests/gluttony_spec.lua`.

**Not built:** a **`character_turned_hunter`** beast blueprint (the *named* former Grand Hunter, distinct
from the wild-game roster — the "beast that wore a name" at slot 5 and the wardens at slot 9), built to
share Gula's phase-two design language; Kaya's **temperance-immunity** fold-in on the Horn (moot until
the general's devour mechanic it answers exists); the **devour-the-fallen** finale mechanic and the
**two-phase transform** into the beast; and the six mid-line quests and scenes — slots 3, 4, 6, 7, 8, 9
(slot 7 is the *speak-without-a-fight* seam shared with the other lines).

## The Crucible: envy, designed

The sixth line worked out end to end, and the last of the seven vendors to open (prestige 4 — *you do
not envy until you have seen what the other six own*). It proves *the vendor is quietly serving its
sin* in a register none of the others use. The Bastion serves sloth by **declining to notice**; the
Colosseum serves wrath by **selling tickets**; the Cathedral serves lust by **hiding it at the
altar**; the Hunter's Lodge serves gluttony by **licensing the excess as a cull**. The Crucible serves
envy by **preaching a philosophy that dissolves the crime** — a comforting, popular teaching that makes
the theft not-count before it is even seen.

The well is unusually deep, and one touchstone is almost unfair for an alchemy game: **Fullmetal
Alchemist's Envy** — a homunculus with no true form who wears others' shapes, sin incarnate, whose real
self is a small wretched thing. The game already ships a `character_homunculus` on this very shelf;
FMA's sins *are* homunculi. Around it: **Dante's Terrace of the Envious** (*Purgatorio* — the envious
walk with their eyes sewn shut with iron wire, in stone-grey, because in life they could not bear to
look on another's good); **Snow White's mirror** (*fairest of them all* — poison rather than be
second); **Cain** (the first envy, the favored offering, the fratricide); and **The Thing** (perfect
imitation, no original left).

### The college, and what almost no one sees

To nearly everyone the Crucible is exactly what it appears: a **genuinely useful college** — it refines
gear and brews medicine (the game's refine and panacea live here), and most of its members do honest,
respected work. The rot is not the rank and file. It is the **Great Work** at the top, known to a small
circle.

The alchemist's oldest dream is not gold. It is **making a person from base matter** — a homunculus
with a soul. The college has chased it for generations and failed: the things come out **hollow** — they
mimic, they wear faces, and there is *no one inside*. The comforting public philosophy is the cover:
*"excellence is a substance, not a self; no one is born better; the self is a formula, and anything can
be transferred."* That teaching is genuinely popular and genuinely consoling — and it is the exact
license to keep making counterfeit people, because if a self is just inventory, a made one is as good as
a born one and a failed one is only a spoiled batch. The **discards** — hollow, envious, eyes sewn shut —
are dumped, and they are the *"corrupted things from the wild"* the player is hired to purge early. This
is not a mask over a dungeon; it is a respected craft that cannot admit its product isn't people, and
that denial is the sin.

### Livia, the Unborn — the homunculus who wants to be real

Livia is the college's masterpiece: the one homunculus that got far enough to **want**. What she wanted
was the single thing that cannot be decanted into a flask — a *self*, a soul, to be *born* and not made.
She did not pact for power. She pacted with the Demon Lord for **humanity** — and the bargain's cruelty
(Ira's numbness, Gula's appetite) is exact: it gave her the power to **copy any human perfectly** —
shape, skill, manner — and never once to *be* one. She can be anyone and is no one. **"Has no shape
until it has seen yours"** is literal to the bone: she has no self, only the humans she wears, and she
envies the one thing she can never counterfeit — an interior. She will settle for wearing yours.

The name keeps the Latin sin-register (Ira, Luxuria, Gula, Acedia) with the meaning buried rather than
stamped: **Livia**, from *lividus / livor* — **livid, the leaden blue-grey pallor of envy** (Rome's
colour for it, not our green) and the bloodless colour of a corpse. For a hollow made thing with no
blood of its own, "the leaden one" is the name and the complexion at once. Epithet **the Unborn** — a
made thing that envies the born.

### Her kit — covet, then spoil

Envy has two motions and they are opposites, which is the whole sin: **COPY** is the aspiration (*I want
to be you*); **LEVEL** is the spite (*and if I can't, no one is above me*). Every ability is one or the
other, and both are **Ren's toolkit run backwards** — Ren gives, lifts, and mends; Livia takes, drags
down, and blocks. A foil answered move for move.

| Ability | Verb | What it does | Engine |
|---|---|---|---|
| **Covetous Reflection** | copy | `onCombatStart`, copies your **strongest** unit, not fragile — the rank-4 spec, pre-written on the shelf | ships (`Summon.copyOf`) |
| **The Counterfeit Host** | copy | phase two: summons **blank homunculi**, each inert until it **sees** a unit of yours (line-of-sight — *you cannot covet what you cannot see*), then takes its shape and fights as a fragile copy | ships (summon + `copyOf` + `requiresSight`) |
| **The Envious Pall** | level | drags whoever currently **towers** down toward your weakest — the exact inverse of Ren's gild | new trait, small |
| **Covet** | take | strips a unit's **buffs and wears them herself**; if she already carries them, she **destroys** them (*would rather you had neither*) | new strip-variant over the shipped cleanse |
| **Grudge** | spoil | lays **Grudged** on a unit: it **cannot be healed** while it holds | new `noHeal` status flag, checked in `Combat.heal` |

Two phases (`models/transform.lua`, which now ships): **phase one** she wears a copy of your strongest
and passes as one of you, with only a whisper of the Pall; **phase two** the borrowed shape **sloughs
off** and the homunculus underneath is revealed — faceless, running-quicksilver, no one home (FMA's true
form / the noppera-bō) — and the Host, Covet and Grudge all come online. The board fills with
counterfeits of your own party, your healing dies, and your buffs walk over to the enemy.

The counterplay is envy read as tactics, and it is Ren's kit that solves it: **make yourselves not
worth copying and not worth robbing.** Do not let one unit tower (she copies it) and do not stack power
into a pair (she covets it, then spoils it). Ren compresses the party *upward* — a flat, high,
self-sufficient plateau — faster than the Pall can drag it *down*. When nothing towers, the Glass finds
nothing to wear; Livia collapses into her own hollow shape, and *that* is the kill-window.

### Ren, the honest alchemist — the same craft answered the other way

Ren (from 仁, *rén / jin* — **humaneness, benevolence, the quality of being fully human**; the virtue
buried and not stamped, the way *Saber* is patience and *Kaya* is sufficiency) is the alchemist who does
the real Work the honest way. She is **not the college's outcast and shares no history with Livia** —
like Kaya to Gula, she is simply the one who was never envious. She **refuses to make homunculi**; she
makes the base noble by **spending herself to lift others**, and she can partly *undo* the college's
counterfeiting — restore a discard, shield a batch marked for the vats — which is why the college wants
her silenced.

Her virtue is *"grants others' power instead of coveting it,"* and it is a clean mechanical inversion of
Livia: the general copies your strongest **onto herself**; Ren copies your strongest **onto your
weakest**, keeping nothing. Envy levels down; kindness levels up; same engine, opposite beneficiary.

Her flaw is kindness's dark edge, and it is purely thematic (no shared past needed): **the giver who
never receives stays forever above, needed by all and in no one's debt** — envy's own mirror, a quiet
superiority. Being needed is her safety. The line makes her do the hardest thing for her: **receive.**

### The line's rhyme, and the finale

Every line has a rhyme; the Crucible opens and closes on **"has no shape of its own."** At the head Ren
proves a self is made real by *giving* — she pours herself into a discard and a person comes back. At
the end Livia, stripped to her hollow shape, does the one thing envy can never do: she **asks** — *how do
you make it look like nothing?* — and Ren, whose whole virtue is giving power away for free, **would**.
But a pact-hollowed homunculus can hold nothing; there is no one left in her to receive it.

So the defeat is **not** FMA's (their Envy self-destructs in shame). Livia dies **seen.** The thing she
spent everything to steal — a self, to be regarded as real — is the one thing Ren can give *without it
being a theft*: Ren **sees her, names her as real,** treats the hollow thing as a someone. It is the
human regard Livia could never counterfeit, handed over freely — and she dies anyway. That is the cost,
and it is Ren's Kaya-beat: **kindness can grant regard; it cannot grant a soul.** You can see the hollow
into dignity; you cannot fill it. Ren has to end her regardless, and carries that generosity has a
floor — not because kindness failed, but because the pact left no one home to keep the gift.

### The ten slots

Ten against the four-rank ladder (`ranks = { 0, 40, 100, 200 }`; Puffer → Distiller → Transmuter →
Philosopher), the general behind rank 4 — the same standing that puts the **Philosopher's Stone** on the
shelf, whose file comment is the spec. Nothing of the line ships yet; all ten are new. The middle makes
the player **see** the manufacture and trace it inward, to the vats and the one fact Ren cannot yet face
(slot 7): the thing at the centre is not a monster but a made person who will never be real.

| # | Slot | Rank | Objective | The Crucible's ten | What it costs / reveals |
|---|---|---|---|---|---|
| 1 | Introduction | 1 | `assassinate`/`killAll` | **The Runaway Reagent** — recover a stolen "ingredient" | it is a *person* — a discarded homunculus, eyes sewn shut; horror planted, unexplained |
| 2 | The recruit | 1 | `killAll` | **The Counterfeiter** — Ren, branded a heretic for giving the Work away free and sheltering discards | bested, her plea reveals the manufacture; she joins; says nothing of Livia yet |
| 3 | Complication | 1 | `protect` | **The Self-Made Master** — a patron wearing a bought quality, coming apart | proof of the lie: borrowed property **rots** — her honest method vindicated, and she pities him |
| 4 | Escalation | 2 | `killAll` | **By the Dram** — buyers and enforcers wielding purchased gifts; the first blank homunculi | she sees the Work done brilliantly and hates that it *works* |
| 5 | The discovery | 2 | `reach`/`killAll` | **The Vats** — the manufactory; the philosophy laid bare, the discards with sewn eyes | she was once *offered* perfection and refused to be perfected at another's cost |
| 6 | Complicity | 2 | `killAll` | **Spoiled Batch** — a term's-end writedown; the college's own porters have started refusing | the player becomes the hand that buries the college's failures |
| 7 | **The turn** | 3 | *(no fight)* | **Nobody Home** — Livia *is* the thesis: a made thing that will never be real; her death frees nothing, the *philosophy* is the engine | her hope dies — that kindness can *give* Livia a way out |
| 8 | The break | 3 | `assassinate` | **What Ren Kept** — second relic earned here | she stops giving reflexively; she learns to receive |
| 9 | The approach | 3 | `assassinate` | **The Open Formula** — the college doesn't hide, it *proselytises*, and offers the player the tincture | the scale her death won't undo — every gift already sold, every discard already in the vat |
| 10 | The general | 4 | `assassinate` | **Livia, the Unborn** — two-phase; copy, Pall, Host, Covet, Grudge | she ends someone she can only *see*, not *fill* |

Slot 7 needs the antagonist to **speak without a fight** — the same seam flagged for Wrath's, Lust's
and Gluttony's slot 7. The rep-ladder soft-lock is gone with the ten slots on disk (the nine pay 275
against a 200-point rank 4 — the tightest line of the seven); what is left is the ladder's *shape*,
which still wants standing as a **count of distinct completed quests** (`ranks = { 0, 3, 6, 9 }`).

### The relic, and Ren's signature

**The general's key — the Envious Glass** (a mirror — Snow White): differs in type from the others (a
looking-glass, not armour or a spear). Worn, `onCombatStart` copies the **strongest enemy** onto your
side, *not fragile* — the completed Great Work the shop only ever sold you a fragile imitation of
(`utility_philosophers_stone` is the puffer's fake; its own comment promises *"it will point this very
ability at your strongest, and it will not be fragile then"*). The same trap it was when she wore it:
you fight in borrowed shapes and never your own. No `class`, no `price`; `gateHint` a fragment of the
Gate Below's location.

**Ren's signature — the Aqua Vitae** (the alchemists' *water of life*): a conditional-unlock signature
(per the system on Rowan's Aegis and Kaya's Horn). It charges on a *"given"* tally — power and healing
she has poured into allies — and when ready she **transmutes an ally**: copies your strongest onto a
weaker unit, the benevolent inversion of the Glass. Its second form, earned at slot 8, is the arc in a
verb: the one who only ever gave can, once, **be gilded in return** — the giver lets herself receive.

**Unbuyables** across the line (the relic, the signature, and no more than two others — the 3×3 grid
budget): an **intake ledger** at slot 5 and one from slot 8, both `class = "alchemist"` with no `price`
(unbuyable, still tallying toward alchemist growth — see `docs/classes.md`).

### Livia and the two systemic rules

Livia obeys the **two-phase** rule cleanly and is arguably its most literal consumer — the homunculus
that sheds a stolen human shape for the thing underneath is a transform, not a metaphor
(`models/transform.lua`, which ships).

She **breaks the *fallen human* rule on purpose, and is its second flagged exception.** Rule one is
*every general was a human who pacted*; Ira is the standing exception — *a human made into a thing, who
never chose.* Livia is the **exact inverse**: *a thing that wants to be human, who did choose* — she
pacted, and for humanity rather than power. The two bracket the rule from opposite ends, and that is
design, not drift: state it, do not smooth it.

### What is built, and what is not

**Built:** the `alchemist` building + vendor (`sin = "envy"`, opens last at prestige 4),
`growth/alchemist`, the rank-4 foreshadow relic `utility_philosophers_stone` (the fragile imitation, its
comment the boss spec), and the homunculus exemplar (`character_homunculus`, `ability_summon_homunculus`);
the copy and transform engines ship (`Summon.copyOf`, `models/transform.lua`). Both characters —
`character_ren` (kindness alchemist, `boss = true` at her recruit per the Amana pattern) and
`character_general_envy` (**Livia**, `boss = true`). Livia's rule `trait_covetous_reflection` (the
shipped phase-one copy, `onCombatStart` copies your strongest, *not fragile*) on her **Envious Glass**
relic (rank-4 drop, `noSteal`, `gateHint = "below the vats, where the shapeless envy the shaped"`).
Ren's signature `utility_aqua_vitae` (bound, `unlock = { event = "healDone", count = 3 }`, grants the
party a copy of its strongest — the benevolent inversion of the Glass). Three of the ten quests — the
recruit slot 2 (`crucible_the_counterfeiter`, `rewardCharacter = "character_ren"`, `killAll`), slot 5
(`the_vats`), and slot 10 (`general_envy`, rank-4 gated, drops the Glass + `gateHint`). `general_envy`
is in `the_gate_below` `requiredQuests`. Four conversations — `vendor_alchemist_intro`,
`crucible_the_counterfeiter_confront`, `ren_joins`, `crucible_general_envy_confront`. Coverage in
`tests/envy_spec.lua`.

**Not built:** the three phase-two mechanics (the **Envious Pall** trait, the **Covet** buff-strip over
the shipped cleanse, and the **Grudge** `noHeal` status); a `character_blank_homunculus` for the
Counterfeit Host; the **two-phase transform** (the borrowed shape sloughing off); Ren's second,
receive-in-return form of the Aqua Vitae; and the six mid-line quests and scenes — slots 3, 4, 6, 7, 8, 9
(slot 7 is the *speak-without-a-fight* seam).

## The Arcanum: pride, designed

The seventh line worked out end to end, and the last of the sins to get its chapter. It proves *the
vendor is quietly serving its sin* in a register the other six do not use. The Bastion serves sloth by
**declining to notice**; the Colosseum serves wrath by **selling tickets**; the Cathedral serves lust
by **hiding it at the altar**; the Hunter's Lodge serves gluttony by **licensing the excess**; the
Crucible serves envy by **coveting from below** — and the Arcanum serves pride by **standing above
judgment.** Its rot is not buried in a crypt and it is not a secret held by a small circle. It is done
in the open, and tolerated, because the Arcanum is simply **too useful to rein in.**

The direct model is **Frieren** — *Fern and Frieren against the pride of the demons.* Aura the
Guillotine weighs power on her scales, a contest of the mana a mage lets her *see*, and is certain the
balance falls her way; Frieren beats her by having spent a century holding her true mana suppressed, so
the proud demon fatally underestimates her and her own ability turns on her. That is this whole line:
**pride that judges by the surface, humility that keeps its depth hidden, and the proud undone by the
certainty of having measured you.** (As the other lines credit Claymore, Bloodborne, Golden Kamuy and
Mononoke, this one is Frieren's.)

### The Arcanum, and what it is allowed to do

To nearly everyone the Arcanum is exactly what it appears — and more than the other houses ever were: a
**genuinely indispensable institution.** It wins the realm's wars, breaks its sieges, turns back its
plagues, and its great mages are **famous**, sought as consultants by the crown itself. There is no
mask here and no hidden dungeon. Its masters practise **necromancy, blood magic, human and corpse
experimentation, resurrection, and battlefield-flattening catastrophe** in the light, and the powerful
**know**, and look away, because the results are worth more than the scruple. That is the sin, and it
is worse than a secret: *no one else can do what we do, so nothing we do can be wrong.* Pride made
institutional, and shared by everyone who benefits — a whole realm's blind eye, bought with usefulness.

The great majority of the Arcanum's scholars are ordinary and sincere and take only the work that
needs taking. The rot is not the rank and file; it is the **thing the celebrated do to reach the top,
in full view,** and the reason no one stops them is that everyone above them is a customer.

### The cost, catalogued

Two prices are paid so the Arcanum can know everything. The first is its own: the **researchers**, the
brilliant few driven ever deeper into forbidden work until their minds break — the deep stacks are full
of them. The second is everyone else's: the **subjects** of the necromancy and the blood magic, the
bodies the resurrections are practised on. Both are written down, and the register that hides them in
plain sight is an **honor roll** — *"those who gave themselves to the work,"* a list of donors to
knowledge, read as a roll of the noble dead. It is the same trick the Bastion plays with its martyrs,
the Cathedral with its ascended saints, the Lodge with its named trophies: a casualty list recited as
an honor. It needs no more invention than the naming.

### Sublimitas, the Unequalled — the pride at the summit

Sublimitas is a **human who made a pact with the Demon Lord** (see *Every general is a fallen human*,
below), and the bargain's boon is **perfect comprehension**: she has only to *glance* at a working once
to know its principles and cast it herself. She is, truly, the greatest mage of the age — celebrated,
real, earned in her own eyes — and that is exactly the trap. **Perfection is a ceiling.** A mind that
has decided there is nothing left for it to learn cannot be told anything, can admit no wrong, and will
do **anything** to keep the summit it is certain it deserves. She is **Aura's pride**: she measures
every mage by what they *show* her, weighs it against herself, and is sure the scale falls her way.

Her rule is the shipped foreshadow — **"answers every spell with your own"** — and it is a `onCast`
answer written against the wired hook (see *Authoring the remaining six lines*): whatever the party
throws at her *where she can see it*, she has already mastered, and turns back. It is pride that can
only ever answer **the visible.** She also brings a devastating **original** kit — catastrophe magic,
and **necromancy that raises the fallen (yours or hers) as her thralls**, the second-form mechanic that
parallels Luxuria turning the blooded and Gula devouring the fallen. Two-phase, per the all-general
rule: the human Archmage sheds into a demon who **fills the board with copies of herself**
(`ability_doppelganger` / `Summon.copy`, already shipped) — *the only necessary mind, made literal.*

The counterplay is the sin read as tactics: **do not show her your hand.** A party of flashy nukers
feeds the mirror; the spell you stake the fight on is the spell she gives back. What she cannot answer
is the mage who never shows her anything worth taking.

**Killing her frees nothing automatically.** The dead she raised do not lie back down at her death, the
subjects do not return, and the appetite is the Arcanum's, not hers alone — kill Sublimitas and the
house crowns its next Unequalled, because the realm still wants what only this place can do. You cannot
end a practice by killing its finest product.

### Gyeom, the same summit reached the other way

Gyeom is **not a prodigy** — she is Fern. She showed no special gift; she simply worked, every day, on
the one principle that she need only **do her best, not be the best,** and be a little better than
yesterday. Years of that made her formidable, and she *still* holds that she has more to learn — which
is the whole of her, the virtue buried and not stamped (Korean **謙**, *humility*, the I Ching's hexagram
of Modesty, the way *Saber* is patience and *Kaya* is enough). And like **Frieren** she **conceals**:
she keeps her true strength held down, never casts to impress, and so reads to any proud eye as a weak
mage not worth measuring.

She came up inside the Arcanum and would not adopt its one rationalization. She is the one who refused
to call the human cost acceptable just because it was useful — she obstructed the work and sheltered
those marked for it — so the crown-backed Arcanum branded her a **dangerous radical** and sent the
player to bring her in. She is a **witness who broke**, but hers is the refusal of a collective excuse,
not the exposure of a secret: everyone already knows, and she is the one who will not agree.

Her **foil-immunity, stated as cleanly as Amana's "not one of the made" and Kaya's "nothing to eat":**
Sublimitas answers and copies only what is **shown** — and *Gyeom shows nothing.* You can glance a
spell; you cannot glance the ten thousand hours she never put on display. It is not willpower and not a
corruption resisted — she simply does not fight to be seen.

Her quiet cost and question are the humility beat in personal form. The Arcanum measures a mind by what
it flashes in an instant, and beside Sublimitas her slow, hidden way looks like **mediocrity** — she
has to hold, against genius itself, that the slope is worth more than the summit, and that what you
keep back is worth more than what you show. The finale is where she keeps it, and reveals it.

### The line's rhyme, and the finale

Every line has a rhyme; the Arcanum **opens and closes on what is kept back.** At the head Gyeom meets
a problem not with a bigger spell but with a better-practised self she does not show off — restraint
and concealment as one gesture. At the end Sublimitas, certain to the last that one glance has measured
her, offers the one thing pride can give: **completion.** *"You grind over a lifetime toward what I can
hand you in an afternoon. Glance with me. Be finished. Be the greatest, and never strive again."* To
accept is to stop — to trade the slope for the ceiling and become the next Unequalled.

Gyeom refuses — the refusal is a **choice of character,** not a mechanic — and **releases what she
never showed,** the reveal the proud eye never thought to wonder about (Frieren against the scales):
*"You saw everything I showed you. You never once wondered what I kept."* And the campaign has been
earning that line's mechanical truth all along: a diligently-fielded, concealed Gyeom is the depth the
glance could not read. *The Unequalled measured everyone, and was undone by the one she was sure she
had already measured; that certainty is her whole poverty.*

### The ten slots

Ten against the four-rank ladder (`ranks = { 0, 40, 100, 200 }`; Apprentice → Adept → Magus →
Archmage), the general behind rank 4 — the same standing that puts the **Codex of Hubris** on the shelf,
whose file comment is the spec. One shipped quest is reused (`grimoire_ruins`); the rest are new. The
middle makes the player **see** what the realm excuses and trace it to the summit — to the one fact
Gyeom will not yet weigh (slot 7): the greatest mage of the age is genuinely that great, and that is
precisely why she can hear no objection.

| # | Slot | Rank | The Arcanum's ten | What it costs / reveals |
|---|---|---|---|---|
| 1 | Introduction | 1 | **The Sunken Sanctum** — `killAll` *(ships, `grimoire_ruins`)* | the Arcanum wants its book back and cares nothing for the looters or the dead — it values knowing over people |
| 2 | The recruit | 1 | **[The Radical]** — `killAll` | sent to bring in a "weak" branded mage; she lets the player think they have her, reveals she was never showing her hand — and stays it anyway; her plea reveals the cost the realm excuses; she joins |
| 3 | Complication | 1 | **The Praised Working** — `survive` | a working the crown praised — and the subjects it was practised on; the cost the beneficiaries never see |
| 4 | Escalation | 2 | **The Inner Circle** — `killAll` | the inner circle's Adepts met mid-experiment; necromancy and blood magic firsthand |
| 5 | The discovery | 2 | **The Donor Roll** — `reach`/`killAll` | the honor roll of "those who gave themselves to the work" set against what became of them — it is a casualty list |
| 6 | Complicity | 2 | **The Requisition** — `reach`; one sealed order for one named working | the player fills it without reading it, then is told what it was for — as a courtesy, because the Magus is proud of it |
| 7 | **The turn** | 3 | *(no fight)* | Sublimitas glances a working and reproduces it flawlessly — she is **not a fraud**; that is why she never stops and hears no objection. She measures Gyeom at a glance and dismisses her, and Gyeom must not correct her |
| 8 | The break | 3 | **The Slope** — `assassinate` | Gyeom chooses the slope over the summit, deliberately; **second relic** (practice that persists) — improvement becomes a stance |
| 9 | The approach | 3 | **The Next Unequalled** — `assassinate` | the scale of what her death will **not** undo — the subjects do not return, and the Arcanum will crown a new Unequalled |
| 10 | The general | 4 | **Sublimitas, the Unequalled** — `assassinate` | two-phase (human Archmage → self-copying demon); she answers what you show and raises your fallen — until Gyeom releases what was concealed; the work survives her |

Slot 7 needs the antagonist to **speak without a fight** — the same seam flagged for Wrath's, Lust's,
Gluttony's and Envy's slot 7. The rep-ladder soft-lock is gone with the ten slots on disk (the nine
pay 285 against a 200-point rank 4); what is left is the ladder's *shape*, which still wants standing
as a **count of distinct completed quests**.

### The relic, and Gyeom's signatures

**The general's drop — the Codex Unanswered** (a tome, differing in type from the armor / spear / mail /
reliquary / bow / glass of the others): the vessel of Sublimitas's rule, carrying **"answers every
spell with your own"** for whoever lifts it — worn, *you* now turn back what your foes cast at you, the
same trap it was for her. `noSteal`, no `class`, no `price`, `gateHint` written into its flavor and
consumed by `the_gate_below` (`"where the shelves answer only themselves"`).

**Gyeom's signature is the Ledger** (`utility_ledger.lua`) — a grimoire she writes herself, bound, in
the grid's center: **concealment, and release.** She fights **suppressed** — her displayed magic reads
low, so enemy targeting and the mirror alike treat her as negligible — while **every action she takes
banks a small, permanent gain** (a stacking *Diligence*), so she peaks **late**, the exact inverse of
Saber's one-motion front-load. It is a conditional-unlock signature, as on Rowan's `armor_sworn_aegis`
and Kaya's `utility_wolfsong_horn`: after she has done her best enough times (`unlock = { event =
"castMade", count = N }`), the **Release** opens — she drops the suppression and her accumulated power
lands at once, on the enemy that dismissed her. The immunity is the concealment itself, and needs no
second hook — she is read at her suppressed value, and a spell answered off her is answered off nothing.

**Gyeom's second relic** (late, the stance, parallel to Saber's chosen strike and Rowan's declared
ward): her practice **persists across battles** — Diligence carries forward, so a diligently-fielded
Gyeom grows into a genuinely great mage over the campaign, *improve every day* made literal. The
within-battle stacking is cheap; the cross-battle persistence touches `models/save.lua` and is new
work, flagged below.

Two or three other unbuyables across the middle, no more (the 3×3 grid budget), all `class = "mage"`
with no `price` — unbuyable, still tallying toward mage growth (see `docs/classes.md`).

### Sublimitas and the two late rules

Sublimitas obeys both all-general rules (see *Every general is a fallen human*, below). **Human first
form → demonic second:** the celebrated Archmage sheds into the demon the pact made of her, and the
new form's signature is the shipped `ability_doppelganger` writ large — **she fills the board with
copies of herself,** pride's answer to every problem being another of her. **The second finale
mechanic** (parallel to Luxuria turning the blooded and Gula devouring the fallen): her **necromancy
raises the fallen** — any downed unit, yours or her own, rises to her side and fights on. Both are
deferred, flagged as new work.

### What is built, and what is not

**Built:** the `arcanum` building + vendor (`sin = "pride"`), `growth/mage`, the rank-4 foreshadow relic
`utility_codex_of_hubris`, and the Pride exemplar spell `ability_doppelganger` (`Summon.copy`). Both
characters — `character_gyeom` (humility mage, the Ledger centered, `boss = true` at her recruit like
Amana and Saber) and `character_general_pride` (**Sublimitas**, `boss = true`). Both traits —
Sublimitas's `trait_perfect_recall` (the `onCast` answer on the Codex Unanswered, shipped as a
counter-magic reflex; the full learn-and-recast is deferred) and Gyeom's `trait_ledger_diligence`
(bank-per-action + the four-cast Release on the Ledger). The relics — `utility_codex_unanswered`
(rank-4 drop, carries `trait_perfect_recall`, `gateHint = "where the shelves answer only themselves"`)
and `utility_ledger` (Gyeom's bound signature, `unlock = { event = "cast", count = 4 }`). Four of the
ten quests — slot 1 (`grimoire_ruins`), the recruit slot 2 (`arcanum_the_radical`,
`rewardCharacter = "character_gyeom"`, `killAll`), slot 5 (`donor_roll`), and slot 10 (`general_pride`,
rank-4 gated, drops the Codex + `gateHint`). Four conversations — `vendor_arcanum_intro`,
`arcanum_the_radical_confront`, `gyeom_joins` (the join banner), and `arcanum_general_pride_confront`.
`general_pride` is in `the_gate_below` `requiredQuests` **and** Sublimitas is in `trait_hollow_crown`
`shades`. Coverage in `tests/pride_spec.lua` (Diligence banks and compounds; the Ledger releases at the
fourth cast; Perfect Recall answers a spell and lets a sword through).

**Not built:** the `status_pride` tell; the two-phase transform (human Archmage → self-copying demon)
and its phase-two kit (`ability_doppelganger` writ large + the raise-the-fallen necromancy finale
mechanic); the full glance-and-recast mirror over the shipped counter-magic reflex; Gyeom's second
relic (the cross-battle Diligence persistence, touching `models/save.lua`); and the six mid-line quests
and scenes — slots 3, 4, 6, 7, 8, 9 (slot 7 is the *speak-without-a-fight* seam shared with the other
lines).

## The Undercroft: greed, designed

The seventh line worked out end to end, and the last — the sin the other six were quietly funding all
along. It proves *the vendor is quietly serving its sin* in the one register none of the others use, and
that register is the **absence** of a register. The Bastion serves sloth by **declining to notice**; the
Colosseum serves wrath by **selling tickets**; the Cathedral serves lust by **hiding it at the altar**;
the Hunter's Lodge serves gluttony by **licensing the excess**; the Crucible serves envy by **preaching a
philosophy that dissolves the crime**; the Arcanum serves pride by **standing above judgment**. Every one
of those is a concealment or a justification — a thing done in the dark, or an argument for why the light
is fine. **Greed needs neither.** The Undercroft serves greed by **being the way of the world** — the one
rot that hides in nothing, because everyone was raised inside it and calls it common sense. *A debt is a
debt. The market. Everyone has their price.* You do not purge this one. You were born owing it.

The well is old and mostly moral rather than fantastical: **King Midas** (the touch that turns bread and
daughter to dead gold — the power to *have* everything is the exact thing that makes having anything
impossible); **Smaug and Thorin's dragon-sickness** (*The Hobbit* — the hoard counted and never spent,
and the sickness that takes whoever sits on the gold); **Kaiji** (Fukumoto) and **Arlong Park** (*One
Piece* — debt-slavery, and the freedom you are made to buy and never allowed to keep); **Scrooge and
Marley** ("the chain I forged in life," link by link of cash-boxes and ledgers) and **Shylock's bond**
(the pound of flesh — debt as ownership of a body, and unarguably lawful); and, for the shape of the
thing at the summit, **Mammon** (Milton's demon of wealth, eyes forever down on the golden pavement) and
**Dante's avaricious**, bound face-down in the dirt because in life they fixed on the earth. (The
Crucible took the sewn eyes for envy; greed gets the face in the ground. As the other lines credit
Claymore, Bloodborne, Golden Kamuy, Mononoke, FMA and Frieren, this one is Midas's and Marley's.)

### The Bank, and what everyone already accepts

An *undercroft* is the vaulted cellar beneath a great building, and the name is the structure. On top, in
daylight, stands **the Bank** — a beloved, indispensable institution, name on the hospital and the
library, the coin the city keeps and the credit the frontier runs on. Beneath it, "no sign, no door
you'd notice," is the **Undercroft** the player actually ranks up through: the deniable firm of fixers
and quiet killers the Bank keeps on retainer for the rare soul the law and the money cannot reach. The
vendor's own word for its trade is *theft and quiet murder* — and that is the tail, not the body.

Because the body is legal. The Bank makes the great money the way the great money is really made: it
**buys the government** — lobbies for the statutes that make what it does lawful by construction, funds
the crown's war against the demons and holds its debt — and it **makes owing it the natural order.** It
does not pick your pocket in an alley; it holds the note on your house, your city's water, your king's
campaign. Corruption is not its crime, it is its product, sold back to everyone as prudence and
prosperity. (It funds the disaster it profits from — the note the Cathedral and Claymore's Organization
already sound in this world.)

**The great majority of the Bank's people are ordinary and sincere and believe every word of it** —
which is the whole difficulty. There is no dungeon to expose and no secret to leak, because nothing is
hidden. The rot is that everyone agrees, and the agreement is invisible to the people inside it. That is
what makes greed the hardest of the seven to *name*: you cannot point at a crypt. You can only refuse to
keep calling the water dry.

Its casualty-list-read-as-an-honor-roll — the trick every line plays (the Bastion's martyrs, the
Cathedral's ascended saints, the Lodge's named trophies, the Arcanum's donor roll) — is the register of
**accounts settled in full**: the Bank's proud roll of debts cleared and depositors paid, which is a list
of the indentured worked to death and the noncompliant quietly closed. It needs no more invention than
the naming.

### Aurea, the Ever-Owed — the greed at the summit

Aurea is a **human who made a pact with the Demon Lord** (see *Every general is a fallen human*, below),
and she was, first, a **debtor**: ruined and owned, the thing at the bottom of an institution like her
own. She did not pact for power. She pacted **never to owe again — to be the one everyone owes, forever**
— and the bargain's cruelty is Midas's exactly: everyone does, and she can keep or feel or spend none of
it. She is the world's creditor and starves at her own table; like Smaug she counts a hoard she cannot
use; being owed is the only sensation the pact left her, so she must keep calling it in, because every
note collected is the only proof she is no longer the debtor she was. "Enough" is the thing the pact
switched off.

The name keeps the Latin sin-register (Ira, Luxuria, Gula, Acedia, Livia, Sublimitas) with the meaning
buried rather than stamped: **Aurea**, from *aureus / aurum* — **golden, of gold** — the hoard's own
substance worn as a name, and a real name at that (a saint's, which is the disguise: her human form is
the city's beloved philanthropist, greed dressed in generosity's costume, the robber baron with his name
on the almshouse). Epithet **the Ever-Owed** — everyone owes her, and the owing never ends.

Her rule is the shipped foreshadow — the Kingsblood Dagger's *"lifts the kit out of your hands
mid-fight"* — grown into a whole boss economy, and it is greed made a single number: **her gold.** She
opens the fight rich, and that gold is her armor, her strength, and her fuel at once. **While she is rich
she cannot be killed:** a blow is *paid off* — the damage comes out of her gold, not her flesh, the wealth
buying off the wound — and she strikes like the tyrant she is. **Everything she does costs gold:** hiring
**assassins** and **men-at-arms** onto the board, casting, and the **Golden Touch** itself. She digs her
own grave to threaten you; every summon is survivability spent.

The Golden Touch is how she claws it back — `fx.steal`, fantasy-skinned: her strike turns a unit's kit to
gold and takes it into her purse, so *"taking your gear"* is now *how she stays alive*, and denying the
gilding starves her. And the gold she spends, spills, or has stolen off her **drops as piles on the
board** — the fight's tug-of-war: grab them to deny her refill and fuel your own side; she sends her
bought men to reclaim them.

**Drain her to zero and the ward is gone.** Only then does a blow reach her, and there is almost nothing
behind the gold — a slow, soft mortal. The ruined debtor who pacted never to be poor dies **exactly as
poor as she began**, which is the pact's cruelty cashed out in the win condition. The whole fight is one
legible sentence — **make her poor, then break her** — over three levers: deny her gildings, hold the
loose gold, out-drain her with Clem. It stays the clean side of the *Greed and Envy are not the same sin*
line at the top of this file: Aurea takes the **thing** (your gear, turned to gold), where Livia's Covet
takes the thing's **property** and would rather you had neither.

**Killing her frees no one automatically.** The notes do not cancel themselves at her death; the laws she
bought stay bought; the government still owes; the Bank crowns a new owner and the credit runs on. You
cannot end a practice by killing its richest product, and you cannot kill an idea a whole realm calls
common sense.

### Clem, the same craft answered the other way

Clem is a rogue whose craft is the Undercroft's own: she was its **finest blade** — the Bank's quiet hand
when a debtor would not comply — until she broke on a contract she could not fulfil, and turned the whole
craft around. She now infiltrates the Bank's holdings to **cancel debt**: burn the notes, forge the
clean-slate writ, spirit the ruined away before the men come. The collector became the jubilee, and she is the only one
who *can*, because she learned the machine from the enforcement side — she knows which note to burn,
which magistrate is bought, where the true ledger is kept. She is **not the general's kin and shares no
origin with her**; like Kaya to Gula and Ren to Livia, she is simply the one who would not keep calling
it normal. She is a **witness who broke** (the Amana / Gyeom pattern), and the class used honestly.

Her name keeps the companions' rule — gender-neutral, virtue buried and not stamped (the way *Saber* is
patience, *Kaya* is enough, *Amana* is a trust, *Ren* is humaneness, *Gyeom* is humility): **Clem**, from
*clementia* — **mercy, clemency, the power to release a debt or a sentence.** For an enforcer who became
the jubilee, a name that is clemency worn as a plain nickname — hard as a blade on the tongue, mercy
underneath — is the whole of her. (It is the one companion root drawn from Latin rather than the East;
it reads as an ordinary English name and never as the generals' sin-register, so the split holds where it
counts, on the screen — the way *Rowan* and *Saber* already do.)

Her virtue is caritas in its real sense — *selfless love, giving with no ledger* — and it is greed-shaped:
her whole life was transactions and blood, every life a price and every death a settled account, so
**grace is the thing she cannot compute** — doing something for someone and not writing it down. Her
debt-forgiving *is* caritas made literal: release, not redistribution, the clean inverse of a general who
made even her own soul a deal.

Her answer to Aurea is **not an immunity.** Greed is a contest over a resource, so the foil is a contest,
not a switch — a deliberate departure from the other six companions' clean immunities (Amana's "not one
of the made," Kaya's "nothing to eat," Gyeom's "shows nothing"), and worth stating outright the way the
doc flags Ira and Livia as rule-exceptions. And the resource is **time.** Aurea **buys** it — every summon
and every action is time she pays for out of her hoard, gold turned into presence on the board. Clem
**mints** it and gives it away — every kill quickens the whole party (her signature, below), a tempo she
keeps none of. The same economy, opposite direction: greed concentrates, charity distributes, exactly as
Ren and Livia are one copy pointed at opposite beneficiaries.

She is the party's **tempo**, not its shield. Aurea can gild Clem like anyone; Clem's edge is that her
kills speed everyone while the tempo never stays with her — *that* is "keeps nothing," a playstyle rather
than a trait flag. You could win the fight without her, only slower: a party that acts more drains the
purse faster, and every hired blade Clem cuts down is gold Aurea already spent, wasted the instant it
falls. And it is exactly why the Bank marked her — the one killer who turns a death into everyone's gain
instead of a fee owed is living proof the whole engine runs in reverse, the idea the Bank cannot let
circulate.

Her quiet cost and question are the caritas beat in personal form, and they are distinct from Ren's (the
giver who will not *receive*): Clem's trouble is not receiving, it is that she **forgives every debt but her
own.** The ledger-mind persists — she is still trying to *pay off* what she did as the Bank's blade, and
she is the one debtor she refuses to release, because she believes the lives she took can only be paid,
never forgiven. The line makes her do the unbearable thing for a transaction-mind: **accept a gift she
cannot repay** — to be forgiven for free, and to stop collecting on herself. Refusing your own jubilee is
only the ledger wearing a hair shirt.

### The line's rhyme, and the finale

Every line has a rhyme; the Undercroft **opens and closes on what is owed.** At the head Clem cancels a
stranger's debt and walks away wanting nothing for it — caritas shown, not preached, and the ledger
proved optional. At the end Aurea — who holds every note in the city, and (the reveal) **Clem's own** —
offers the one thing greed can give: her account, **closed.** *"You have never once been able to forgive
your own debt. I hold it. Kneel, and I mark it paid."* It is a taking dressed as a gift, the exact move
Luxuria makes offering Amana her name back: to let the monster be the one who *absolves* you is to be
owned by the absolution, and so to owe her everything. Clem refuses — the refusal is a **choice of
character,** not a mechanic — and does the thing she never could: she forgives **herself,** for free,
needing no hand to clear it, and in the same motion burns the Bank's master ledger, the largest jubilee
there is — every debt in the city cancelled at once. The one thing she keeps (the Kept-Trust beat,
Amana's kept name) is not a possession: it is the party, `{name}` — one account she chooses to hold.
*"I'll owe you this one. Not because you can call it. Because I want to."* The transaction-mind holding a
single open account on purpose, which is love and not debt.

That burning has to be **Clem's** act and not the kill's, because killing Aurea cancels nothing (see above)
— which is what makes the freeing cost what it costs, and what leaves slot 9's scale standing: a new
Bank, the bought laws, the way of the world.

### The ten slots

Ten against the four-rank ladder (`ranks = { 0, 40, 100, 200 }`; Cutpurse → Prowler → Shadow →
Guildmaster), the general behind rank 4 — the same standing that puts the **Kingsblood Dagger** on the
shelf, whose file comment is the spec. One shipped quest is reused (`vault_heist`); the rest are new. The
middle makes the player **see** that the contracts all have one client, and trace it up to the summit —
to the one fact Clem cannot yet face (slot 7): the debt is the pact, not the gold, so the kill frees no
one; and the Bank holds her own note.

| # | Slot | Rank | The Undercroft's ten | What it costs / reveals |
|---|---|---|---|---|
| 1 | Introduction | 1 | **The Vault Beneath** — `assassinate` *(ships, `vault_heist`)* | the job's no robbery — the "merchant prince" is in the Bank's ledger too; you were sent to *collect.* Everything here is owed to someone you haven't met |
| 2 | The recruit | 1 | **[Clem]** — `killAll` | the Bank's own retired blade, now burning its writs, marked for it; bested, her plea reveals the machine; she joins |
| 3 | Complication | 1 | **Working It Off** — `killAll`+`protect` | a debtor "recruited" to work it off; the cut that never clears, shown |
| 4 | Escalation | 2 | **One Client** — `killAll` | the trace-up: the contracts all have one client — the outlaws are the establishment |
| 5 | The discovery | 2 | **Accounts Settled in Full** — `reach`/`killAll` | the Bank's roll of debts cleared set against the indentured dead — a casualty list read as an honor roll |
| 6 | Complicity | 2 | **Quarter-End** — `killAll`; every route in the city runs on one night | the player *is* the hand the Bank hires, at a posted rate, paid on completion |
| 7 | **The turn** | 3 | *(no fight)* | killing Aurea cancels no notes — the debt is the pact; and the Bank holds Clem's own. Her hope dies: that she can simply *take* freedom back |
| 8 | The break | 3 | **Her Own Note** — `assassinate` | Clem sets down her own debt; **second relic** (Borrowed Time keeps one kill's tempo for herself) |
| 9 | The approach | 3 | **A New Bank** — `assassinate` | the scale her death won't undo — a new Bank, the laws still bought |
| 10 | The general | 4 | **Aurea, the Ever-Owed** — `assassinate` | two-phase; her **gold** is ward, strength and fuel — untouchable while rich, she buys off blows and hires blades with it; bankrupt her (deny gildings, hold the loose gold, out-drain with Clem) and she transforms, then falls. Drops the **Bottomless Purse** + `gateHint` |

`vault_heist` exists and maps onto slot 1; the recruit (slot 2), the finale (slot 10), the recruit
`outro` (Clem's terms — why she'll turn on the house that made her), and every mid-line scene are new. Slot
7 needs the antagonist to **speak without a fight** — the same seam flagged for Wrath's, Lust's,
Gluttony's, Envy's and Pride's slot 7. The rep-ladder soft-lock is gone with the ten slots on disk
(the nine pay 285 against a 200-point rank 4); what is left is the ladder's *shape*, which still wants
standing as a **count of distinct completed quests** (`ranks = { 0, 3, 6, 9 }`).

### The relic, and Clem's signature

**The general's drop — the Bottomless Purse** (a purse that is never full — greed's own vessel, and a type
of its own beside the armor / spear / mail / reliquary / bow / mirror / tome of the others). It carries
the **Golden Touch** for whoever lifts it — worn, *you* now gild your foes and take their kit to gold,
warded by the hoard you pile up and unable to stop taking, the same trap it was when she carried it.
`noSteal`, no `class`, no `price`, `gateHint = "beneath the vault that was never full"`, written into its
flavor and consumed by `the_gate_below`.

**Clem's signature is Borrowed Time** (`weapon_borrowed_time.lua` — a blade, like Saber's, so the
killer's own tool sits at her grid's centre; never a cleanse, which is the priest's verb, not the
rogue's). *Time is money, and she gives it away.* It runs on two parts, the way Rowan's Aegis and Kaya's
Horn do:

- **The engine (a trait):** when a foe Clem downs falls, the **whole party gains Haste** — her lethality
  is everyone's tempo. Haste is the Undercroft's own rogue verb already (`trait_opportunist`, on the
  Opportunist's Charm), so it reads as an assassin's momentum, never a blessing. She keeps none of it: the
  time is spent on the party.
- **The active (conditional-unlock):** a **mercy-stroke** — an execute on a wounded foe (the assassin's
  coup, and her name in a verb: *clementia → coup de grâce*) that secures the kill and so reliably lights
  the engine. Charged on the shipped `kill` tally (`unlock = { event = "kill", count = N }` — no new seam,
  unlike a bespoke "forgiven" event); the marquee grants a larger burst — extra Haste, or a free step —
  across the party.

Its second form, earned at slot 8, is the arc in a verb (Rowan's declared ward, Saber's chosen strike,
Gyeom's persistence): the one who spends every kill on others may, **once, keep the tempo for herself.**
The hardest thing she ever takes is a share of her own work.

Two other unbuyables across the middle, no more (the 3×3 grid budget): a **Common Purse** at slot 5 (grid
bonus scaling with adjacent allies, à la the Muster Roll — a share spread, not a hoard held) and one from
slot 8. Both carry `class = "rogue"` with no `price` — unbuyable, still tallying toward rogue growth (see
`docs/classes.md`).

### The gold, in numbers

Starting points for tuning, not gospel — but the shape *is* the design. Damage is dealt into her **gold,
not her flesh**, one-for-one after her defense mitigates it, and only a gold pool at zero exposes the
little that is behind it.

| Quantity | Value | Why |
|---|---|---|
| Gold (the ward), phase 1 | **300** | the fight's real health bar — a party's several rounds of damage, offset by her refills; tune upward if a rank-4 party out-scales it |
| True HP (exposed only at 0 gold) | **40** | almost nothing behind the money — a soft mortal, killable in a turn once broke |
| Defense / magic defense | **14 / 12** | mitigates *before* gold absorbs; armour still matters |
| Damage (personal) | **12** | low — she does not duel, she *buys* blades; her threat is the board she pays for |
| Movement / speed | **3 / 4** | slow; a hoard does not chase — she sits on the purse |

**Her every ability costs gold** (her basic weapon strike is free, so she is never fully harmless — just
defanged and exposed once broke):

| Action | Gold | Effect |
|---|---|---|
| **Golden Touch** (Gild) | **20** | begins turning a unit's kit to gold; if it *sets* (a turn later, undisrupted) the item is taken and its **worth (~40) added to her gold** — a landed gild turns a profit, a *denied* one is 20 poured out for nothing |
| **Hire a man-at-arms** | **25** | a durable body onto the board (below) |
| **Hire an assassin** | **40** | a fast striker onto the board (below) |
| **Gilded Reign** (phase 2 only) | **50** | the Midas-horror gilds every adjacent unit at once — a mass theft, her panic-spend when cornered |

So her gold only climbs if her gildings land and her piles are reclaimed. **Deny both and she cannot stay
solvent** — which is the whole fight: protect your kit (starve the gilds), and reach the loose gold first.

**Gold piles.** Every hired blade carries the gold she paid for it: kill one and that gold **spills as a
pile** on its tile (man-at-arms ~15, assassin ~25). A party unit that steps onto a pile **banks it** (off
the board, denied her); Aurea or a blade that reaches it first **reclaims it** (back into her gold). Clem's
kills therefore pay twice — the party hastes (Borrowed Time) *and* fresh gold drops for you to bank — which
is why cutting down her paid blades is never wasted, even as they respawn on her coin.

**The two-phase, and the trap in it.** The first time her gold hits **0** she does not die — she transforms
(the Midas-horror), **pulls every loose pile on the board into a fresh purse** (a base ~250, plus whatever
gold you left lying around), and re-arms. Bankrupt her again and she falls. The board's lesson: **bank the
piles before you break phase one**, or you hand the horror its second fortune. Greed punished for hoarding;
the player punished for leaving money on the floor.

**Her grid.** Centre: the **Bottomless Purse** (bound — it carries the gold ward and the Golden Touch).
Beside it the **Kingsblood Dagger** (her own blade, its bleed her only free action) and the two hire-a-blade
abilities (`ability_hire_men`, `ability_hire_assassin`). The dagger and the summon-ability frame ship; the
gold ward, the gold-cost gating, the piles and the transform are the bespoke work.

### The hired blades

Her spending has to *matter*, so the two summons pull the party opposite ways — one walls you off the purse,
one dives your drainers:

- **Man-at-arms** (`character_man_at_arms`, ~25 gold) — slow, durable, modest damage: high HP and defense.
  Bought to **wall the party off from Aurea** and to **reclaim gold piles** (its idle job is walking loose
  gold home). Drops ~15 on death. Less a threat than a *cost you must pay* to reach her — and the coin you
  get back for paying it.
- **Assassin** (`character_hired_assassin`, ~40 gold) — fast, fragile, high-damage; **dives the backline**:
  your archers, your drainers, Clem herself. The pricey blade she spends when she wants a *kill*, not a
  wall. Drops ~25 on death. Killing one is a windfall — haste and a fat pile — but you must survive it first.

Both are ordinary hired humans, not demons (`boss = false`, killable and lootable), and they are the
**shipped-engine** half of the fight: ordinary summon abilities that happen to charge in gold rather than
mana. They are the roster the player learns to prioritise — kill the assassin to stop the bleeding, kill the
man-at-arms to open the road and bank its coin.

### Aurea's play

She is a coward who buys safety, and her AI has to read as exactly that — she never spends herself when she
can spend a coin. In priority order:

1. **Stay solvent.** Gold is her life; every other choice bends to keeping it above zero. Low and
   threatened, she pulls back toward her piles and her men rather than trade blows.
2. **Gild for profit.** Prefer the richest target in reach — most items, most worth — and re-gild an
   already-gilded unit to *collect* (the two-step). A gild that will not pay (a lone, cheap, or
   about-to-be-freed target) is not worth the 20.
3. **Wall when pressured.** Party closing on her purse → hire a man-at-arms to body-block the lane. She
   would always rather you kill a thing she paid for than reach her.
4. **Cut the drain.** Hire an assassin at whoever empties her fastest — the backline, the drainer, Clem —
   when she wants a kill rather than a wall.
5. **Reclaim.** Idle gold on the board is unbearable to her: she or her men walk loose piles home whenever
   it is safe.
6. **Hold, don't chase.** Move 3 and a free dagger — she holds near her wealth and strikes in person only
   when cornered.
7. **Panic (broke / phase 2).** At the brink she empties the purse to survive: Gilded Reign into a crowd, a
   flurry of hires, anything to re-ward before the killing blow.

This is richer than the `ai` rule table (`priority/act/targetPref/when`, as on `character_general_lust`)
can express on its own — spending gold by board-state is a decision the simple resolver does not make — so
Aurea's play is part of the **bespoke** boss work, not a data-only `ai` block. The tell to preserve: she is
never brave, only rich.

### Aurea and the two systemic rules

Aurea obeys both all-general rules (see *Every general is a fallen human*, below), and fits the first
**cleanly** — a human who pacted, no exception needed (unlike Ira and Livia). **Human first form →
demonic second:** the beloved philanthropist sheds into the **Midas-horror** — a thing of living gold that
starves at its own hoard. Its **trigger is the gold itself:** the first time you **bankrupt** her she does
not fall — she transforms, violently pulls every gold pile on the board into a fresh purse, and re-arms.
Bankrupt her again and she dies.

**The second finale mechanic** (parallel to Luxuria turning the blooded, Gula devouring the fallen, and
Sublimitas raising them) is the **gold economy itself:** a purse that wards her, gates her every action,
refills on the Golden Touch, and drops as board loot — the one general whose health you cannot swing at
directly, only *empty.* This is a **bespoke finale subsystem** — real new engine, on the order of the
Hollow Crown's custom trait (`trait_hollow_crown`), built over the shared two-phase-transform
(`models/transform.lua`). It supersedes the engine table's "greed needs no engine" note: the bare
take-a-thing (`fx.steal`) ships, but the gold *economy* around it does not. Flagged as new work.

### Clem, statted

A glass-cannon skirmisher — the fixer who must never be caught: high speed and damage, low health, on
`rogue` growth (`speed +1, damage +2, stamina +3, health +3` a level). `boss = true` only at her recruit
fight (slot 2), where she is the objective; a party member after, like Amana and Saber.

Her 3×3 is built for the tempo loop — soften, kill, hand the speed to the team:

- **Borrowed Time** (centre, bound) — the signature: haste-on-kill and the mercy-stroke (above).
- **A poison dagger** (`weapon_envenomed_kris`) — the setup: bleed and poison soften a target into the band
  where the mercy-stroke lands, so the kill that feeds the engine is one she *manufactures* rather than
  waits for.
- **Shadow Step / Shadow Strike** (`ability_shadow_step`, `ability_shadow_strike`) — the fixer's
  infiltration and her reach: close on a wounded backliner and finish it, the assassin's engage.
- **A way out** (`consumable_smoke_bomb` or `utility_feather_boots`) — she strikes into the middle of the
  board and has to survive leaving it.

The loop *is* the character: **poison to soften → mercy-stroke to kill → the whole party (her included)
hastes → act again.** Remaining cells fill with rogue growth. Note the deliberate restraint — she carries
the Opportunist's Charm's *tempo* fantasy but not the Charm itself; two haste engines stacked would spin the
fight out, and Borrowed Time is the one that says who she is.

### The scenes

Four conversations carry the line, each a beat the chapter has already argued, staged:

- **`vendor_undercroft_intro`** (first shop visit) — the fixer's front: no sign, no door you'd notice,
  everything inside belonged to someone else. It sells *family* — *we look after our own* — over a floor
  that owns everyone on it. If Clem is already recruited she cuts in, naming the lie she used to enforce.
- **The recruit** (slot 2, a post-battle `outro`) — bested, Clem stays the player's hand, and her plea is
  the reveal: the guild is the Bank's blade, the debt is the pact, and she was its finest edge until she
  broke. She joins — the *"[Clem has joined your Party]"* banner (`Conversation.pendingJoins`).
- **The turn** (slot 7, *no fight*) — Aurea speaks without a battle (the seam every line's slot 7 needs):
  killing her cancels no notes, the debt is the pact and not the gold, and — the private cut — *the Bank
  holds Clem's own.* Her hope dies, that she can simply take freedom back.
- **The confront** (slot 10) — the finale from *the rhyme*: Aurea offers Clem her account closed; Clem
  refuses, forgives herself, burns the master ledger, and keeps the one thing she chooses — `{name}`.
  Staged over the general's battle frame.

Slot 7's *speak-without-a-fight* is the shared engine question flagged across Wrath, Lust, Gluttony, Envy
and Pride — a quest-level `opening` over the board, wanting staging closer to a hub panel.

### Building the gold subsystem

The one large piece, in dependency order — a note for whoever builds it, not a promise it ships:

1. **The gold field + the ward.** Give the unit a `gold` pool (seeded from the Bottomless Purse). In the
   damage path (`Combat.dealFlatDamage`), *after* mitigation, if `gold > 0` subtract the blow from gold
   instead of health; only overflow past zero reaches HP. Gate it behind a trait/flag so none but Aurea
   ever wards this way.
2. **Gold as an ability cost.** Extend the cost check (`cost = { stat = "gold", amount = N }`, through
   `Combat.itemBlockReason` / `useItem`) to read the `gold` pool — so *broke = greyed-out summons and gild*
   falls straight out of the existing resource gate.
3. **Gild's two-step refill.** Model the set the way the Kingsblood reads bleed: first cast applies
   `status_gilded`; a second cast on an already-gilded target *takes* the item and adds its worth to gold.
   Cure the status between and nothing is taken — which sidesteps the trap that `onExpire` fires on Cure
   too (the reason the earlier "lien on a timer" was wrong).
4. **The hired blades.** Ordinary summon abilities (`Summon`, shipped), charged in gold by step 2; their
   blueprints (`character_man_at_arms`, `character_hired_assassin`) are plain humans.
5. **Gold piles.** A board object modelled on hazards/zones (`models/hazard.lua`): dropped at a dying
   blade's tile (`killUnit`), banked when a party unit ends its move on it, reclaimed when Aurea or a blade
   does (a move-end check).
6. **The transform.** On the first `gold == 0`, `Transform.apply` (ships) to the Midas-horror, pull every
   pile into a fresh purse, and set the phase flag so the *second* zero is lethal.
7. **Clem's Borrowed Time.** A kill-hook trait (the `kill` tally seam) that hastes the party, plus the
   mercy-stroke active (`unlock = { event = "kill" }`). No new engine beyond the hook.

Then the usual: `tools/extract_strings.lua`, and a `tests/*_spec.lua` mirroring `tests/devotion_spec.lua`
that at minimum pins the ward redirect, the gold cost gate, and the haste-on-kill.

### What is built, and what is not

**Built:** the `undercroft` building + vendor (`sin = "greed"`), `growth/rogue`, the rank-4 foreshadow
relic `weapon_kingsblood_dagger` (its comment the boss spec), the steal exemplar `ability_pickpocket`
(`fx.steal`) with the `stealPriority` / Decoy-bait system around it, and the rogue kit that reads as
greed (`weapon_cutpurse_knife`, `utility_opportunists_charm` / `trait_opportunist`, `utility_decoy`,
`weapon_envenomed_kris`). Both characters — `character_clem` (caritas rogue, Borrowed Time centered,
`boss = true` at her recruit) and `character_general_greed` (**Aurea**, `boss = true`). Aurea's rule
ships as the **Golden Touch** — an `fx.steal` active on her **Bottomless Purse** relic (rank-4 drop,
`noSteal`, `gateHint = "beneath the vault that was never full"`), the *take-a-thing* half of her design;
greed's rule is an ability, not a trait, so the Purse carries the active rather than a passive. Clem's
signature `weapon_borrowed_time` (bound, `unlock = { event = "kill", count = 3 }`, a mercy-stroke that
hastes the whole party — the haste rides the active's effect, since the engine dispatches no `onKill`).
Three of the ten quests — slot 1 (`vault_heist`), the recruit slot 2 (`undercroft_clem`,
`rewardCharacter = "character_clem"`, `killAll`), slot 5 (`accounts_settled`), and slot 10
(`general_greed`, rank-4 gated, drops the Purse + `gateHint`). `general_greed` is in `the_gate_below`
`requiredQuests`. Four conversations — `vendor_undercroft_intro`, `undercroft_clem_confront`,
`clem_joins`, `undercroft_general_greed_confront`. Coverage in `tests/greed_spec.lua`.

**Not built:** above all the **bespoke gold subsystem** — the one large piece: a gold pool that *wards*
Aurea (blows subtracted from gold, not HP, until zero), *gates* her every action (the Golden Touch and
each hired-blade summon cost gold), *refills* on the Golden Touch, and *drops as gold-pile pickups* on
the board, plus the **bankruptcy-triggered two-phase transform** (first zero → Midas-horror re-arms;
second zero → death). New engine on the order of `trait_hollow_crown`, over `models/transform.lua`.
Aurea is statted here as an ordinary single-phase general with a real HP pool rather than the
gold-warded soft mortal the full design calls for. Also: her **hired-blade summons** (assassins,
men-at-arms) as gold-cost abilities and their blueprints; Clem's fully-passive haste-on-any-kill and her
**keep-the-tempo** slot-8 upgrade; the **Common Purse** unbuyable; and the six mid-line quests and scenes
— slots 3, 4, 6, 7, 8, 9 (slot 7 is the *speak-without-a-fight* seam). Aurea is **not** in
`trait_hollow_crown` `shades` (the curated firing trio stays Wrath, Sloth, Pride — see that trait).

## Every general is a fallen human, and every general fight has two phases

Two rules decided late, and they govern **all seven** generals — put here so the other lines inherit
them:

1. **Every general was a human who made a pact with the Demon Lord.** The sin is what the bargain made
   of them; the Hollow Crown's seven appetites are seven people who said yes. Luxuria is written this
   way (a human who pacted for demonic power, then infiltrated the Cathedral). Acedia fits cleanly —
   she already *negotiated* a corrupting bargain. **Ira does not, as written** — the Colosseum chapter
   makes her a *manufactured* woman who "never chose," and that is a deliberate, load-bearing part of
   her tragedy. Leave the contradiction standing until it is resolved on purpose: either Ira is the
   one general the rule spares, or her "pact" is the Perennial's, struck on her behalf. **Do not quietly
   rewrite her to fit.** **Livia (Envy) is a second, deliberate exception, and Ira's exact inverse** — a
   *thing that wants to be human and did choose* against Ira's *human made into a thing who never chose*.
   The two bracket the rule from opposite ends on purpose; see *The Crucible* above. **Sublimitas
   (Pride) fits cleanly** — a human who pacted for perfect comprehension and became certain of her own
   summit; see *The Arcanum* above.

2. **Every general fight is two-phase — a human first form, then a demonic second form with more
   abilities.** The **reusable two-phase-transform subsystem** this wants now **ships** as
   `models/transform.lua` (used so far only by polymorph — pig/bear): at a health threshold the general
   swaps form (sprite/stats via `Transform.apply`), gains new traits/abilities, and optionally bursts.
   It carries the continuity a threshold swap needs (the pools travel by reference; the shape's traits
   re-attach) — build the general transform against it and against the health-threshold precedent in
   `trait_hollow_crown` (which re-summons generals as the Crown's health falls past 75/50/25%). No
   general consumes it yet; Luxuria and Livia are the first two (the beloved Saint sheds into her demon
   shape; the homunculus sheds its stolen human one), with Sublimitas a natural third — the Archmage
   sheds into the demon who fills the board with copies of herself.

## Every scene makes room for the party you actually have

A third rule decided late, and it governs **every conversation in the game**, not just the seven lines:

**If a companion is recruited, they get a voice in the scene.** A scene authored for the avatar and one
vendor plays the same way whether you arrived alone or with six people at your back, and that is the
single fastest way to make a party feel like luggage. Write every scene for the **full roster**, and let
`Conversation.resolve` pare it down to the save it plays in — a companion who has not joined is neither
on stage nor in the script, and the scene closes over the gap cleanly.

The mechanism is already there and is documented in
[docs/adding-content.md](adding-content.md#gating-a-scene-on-progress): a conditional `cast` entry plus
a `when = { has = "character_<id>" }` **block** in the script. `vendor_cathedral_intro` is the shape to
copy — the base scene is quartermaster and avatar; recruit Amana and a three-line block opens up where
she and her old church talk past each other, and the vendor's closing line lands on either version.

What a companion's interjection is *for*, in rough order of value:

1. **The sin they answer.** Every companion is the other answer to one general's sin (Amana/lust,
   Saber/wrath, Kaya/gluttony, Ren/envy, Gyeom/pride, Clem/greed, Rowan/sloth — see the chapters
   above). Put them in front of their own sin whenever a scene touches it. Amana in the Cathedral,
   Clem near money, Gyeom near anyone certain they are right. Those are the lines that cost nothing to
   write and carry the whole thesis.
2. **The room they know.** A companion recruited out of a chapter has standing in that chapter's
   buildings forever after — they know the quartermaster's name, they know which shelf is a lie.
3. **Each other.** Two recruited companions with different reads on the same scene is the cheapest
   characterisation in the game, and the only place the party exists as a *group* rather than a list of
   people who each got one moment.

Rules of thumb:

- **Gate the exchange, not the line.** One block, one condition, all the lines that stand or fall
  together — otherwise someone retorts to a remark nobody made. `tests/conversation_spec.lua` enforces
  the half of this it can prove (a gated speaker may only speak inside a block requiring them) and that
  every authored line is reachable in a fully-unlocked save; the rest is on the author.
- **The base scene must still work.** A block is an addition, never load-bearing. Whatever the scene
  had to establish, establish it in the ungated lines, and let the closing beat land on either version.
- **One or two blocks, not seven.** Every recruited companion having something to say and *all of them
  saying it* are different things — a scene where six people queue up to comment is worse than one
  where the right person speaks. Pick who has standing here.
- **Exceptions are the scenes where they are provably absent**: the prologue and `tutorial_*` (nobody is
  recruited yet), and a companion's own `*_joins` scene (they are the subject, and the roster check has
  not flipped yet at the moment it plays — other companions already recruited still belong in it).

The existing scenes are **not** all up to this rule. The one-time shop greetings
(`vendor_<id>_intro`) are — each already joins its own chapter's companion in. Most quest
`intro`/`outro` scenes are not, including much of the sloth line, which was written before there was a
roster to write for. Retrofitting is a per-scene pass, cheap, and worth doing whenever a
line is being touched for another reason.

## Authoring the remaining six lines

### State of the pass: all sixty slots now exist on disk

**37 new quest blueprints** landed in one pass, filling every empty slot across the six lines — the
Colosseum's 2/4/5/7/8/9, the Cathedral's 4–9, the Lodge's 3/4/6/7/8/9, the Crucible's 1/3/4/6/7/8/9,
the Arcanum's 3/4/6/7/8/9 and the Undercroft's 3/4/6/7/8/9. Every ten-slot table above now names a real
file. What each one carries and what it deliberately does not:

- **Premise-first headers.** Each file opens with what is actually happening, how it bears on the
  companion *and* on the sin, why it is a fight at all, and why its objective is the one it is — the
  standard `relief_column` set, and the check `the_long_list` is still flagged as never having passed.
- **No dangling references.** No `intro` / `outro` / `opening` is named anywhere in the 37, because
  `Conversation.play` asserts on an unknown id, and no `rewardItems`, because every unbuyable those
  slots owe (slot 5's register, slot 8's second relics for Saber, Kaya, Ren, Gyeom and Clem) is still
  unwritten and a dead id is worse than none. **Scenes and relics are the next pass, not this one.**
- **Existing blueprints only.** Where a slot wants a body that does not exist — the Perennial's
  fighters, the anointed, the turning wardens, the topped-up buyers, the Bank's chartered security —
  the header names the wanted blueprint and the file stands in with a shipped one. Every stand-in is
  called out in its own header rather than left to be discovered.
- **Slot 7 takes the shippable reading.** The no-fight seam is still unbuilt, so each turn is staged
  as a battle its `opening` will carry, and each of the six says so in its header. Three of them —
  wrath, pride, greed — turned out *better* for it: `survive` against Ira and against Sublimitas
  teaches each finale's counterplay at a survivable price, and greed's `hold` over the true ledger
  lets the book do the talking, which is right for the one sin whose villain is an arrangement.
- **Objective spread.** `killAll` / `assassinate` / `survive` / `hold` / `reach`, with `protect`
  composed under six of them — the "ten slots against three win types" complaint the Bastion's table
  raises is answered by using all five the resolver now knows.
- **One deviation, recorded.** This document called both the Cathedral's and the Crucible's slot 6
  *Cleansing Work*; two quests cannot share a name on one board, so the Crucible's took the college's
  own term, **Spoiled Batch**. Noted in its file header too.

### The grind is gone, everywhere

A second pass removed **every** `repeatable` quest, including the two that shipped before this work.
The rule is stated at *The ten slots* above and enforced in `models/quest.lua`'s header: nothing sets
the field, and the engine still honours it only so a stray def cannot misbehave. What moved:

| Was | Now | Slot |
|---|---|---|
| `muster` — another name off the roll, forever | **Muster** — the roll closed for the season's oath; the tent is half empty | Bastion 6 |
| `blood_in_the_sand` — "win, and win again" | **Blood in the Sand** — the player is the draw, and their undercard is padded *for* them | Colosseum 6 |
| `cleansing_work` — endless sightings | **Cleansing Work** — the diocese tidied before the Feast of the Ascended | Cathedral 6 |
| `bounty_work` — the board never empties | **Closing the Board** — the book cleared before first frost, supper after | Lodge 6 |
| `spoiled_batch` — standard rate, per batch | **Spoiled Batch** — a term's-end writedown the college's own porters refused | Crucible 6 |
| `fetching_work` — requisitions without end | **The Requisition** — one sealed order, filled unread, explained afterwards as a courtesy | Arcanum 6 |
| `collection_work` — run the routes | **Quarter-End** — every route in the city on one night, posted rate | Undercroft 6 |

Two of those were the strongest arguments for the rule. `muster`'s theme was *the repetition itself*
— Rowan's lines shorter each run — which asks a player to farm a quest in order to feel something
about farming it, and almost nobody replays a cleared bounty, so the beat was delivered to a design
document rather than to a player. `blood_in_the_sand` was the soft-lock: the rung meant to carry a
player from Champion to Legend, gated at Champion. Both are better as one authored night.

Reputation was retuned with them — the old grind rates (15) became story rates (30/40), so a
sponsor's authored quests short of its general now pay **275 (the Crucible) to 325 (the Colosseum)**
against a 200-point rank 4, with the other five at 285–305.
Every line clears its own ladder without replaying anything, which is the whole requirement. What
this does *not* fix is the ladder's shape: rank 4 now lands a slot or two early, and only the
count-based standing (`ranks = { 0, 3, 6, 9 }`) puts it back on the ninth. That is engine work in
`Player.addReputation` / `Vendor.rankFor`, it is unchanged by any of this, and no quest has to move
when it happens.

### The line

The reputation ladder (0 / 40 / 100 / 200) doubles as the chapter clock. Wrath's line **as currently
on disk** — four quests, and see *The Colosseum* above for why that is a soft-lock and what the ten
should be:

1. `arena_debut` — the introduction, prestige 1
2. `warlord_keep` — the escalation, prestige 3
3. `blood_in_the_sand` — rank-3 gated: the night the player becomes the draw (was the line's grind)
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
