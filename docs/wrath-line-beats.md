# The Wrath Line (The Colosseum) — story & scene beats

The single writing reference for the Colosseum's ten-slot line. Every scene file under
`data/conversations/colosseum_*` is a beat scaffold keyed to the beats below — write the dialogue over
the `BEAT:` strings, then run `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp the localization ids.

> Lives in `docs/`, so it is mirrored to the public GitHub wiki by `tools/wiki-sync.sh` on any commit
> that touches `docs/*.md` (see CLAUDE.md). Edit this source file, never the wiki page.

---

## Canon (revised 2026-07-28)

**Ira chose the pact.** She struck the bargain with the Demon Lord herself, because she was promised
freedom and the strength to take it. What she got was strength and an **uncontrollable rage** — not a
door out but a deeper cage, one with no key and no door at all. She traded the house's chains for the
rage's, and the rage's cannot be broken from the inside. This reverses the earlier "struck on her
behalf / she never chose" canon: her tragedy is now that she *did* choose, reached for the one thing
she ever wanted, and it devoured her.

**The only freedom left is death.** Because she chose the rage and cannot unchoose it, there is no
bargain to strike and nothing to give her — the person who wanted out is being drowned by the thing
she bargained for. Slot 10 is not "killing someone who never chose." It is a **release**: Saber ends
the one fight Ira can never walk off, and it is still right because it is the last door open.

**Foil:** Saber scales into full-health targets (end it fast); Ira scales as her own health falls (a
long trade wakes the rage). Every bout teaches the arithmetic the general examines at slot 10.

**Vendor serves its sin:** the Colosseum serves wrath by *selling tickets to it*. The Perennial
(stable; name still provisional) *owns* its fighters — it takes children and raises them as property,
bred and drilled to win and to kill on command and never once allowed to choose. The house is the
disease; Ira is its masterpiece, and its prisoner.

**Saber's spine:** *Everyone gets to walk off the sand.* Ira can't. The line ends by requiring Saber
to keep that promise the only way left — she can't walk Ira off, so she carries her off, by ending it.

---

## The line, in one arc

The player arrives on the Colosseum's sand with **no house** — the only team out there with nothing
behind it, which is the whole reason the line's companion will sign with them. They win their debut and
recruit **Saber**, a free-agent gladiator who fights for whoever books her because she loves the craft.

Over ten bouts the line reveals what the arena's reigning stable, **the Perennial**, actually is: not a
school but a house that **owns people** — that takes children and raises them into fighters who must
win and must kill and are never permitted to leave — and that the arena's patron, **Ira**, is its
masterpiece: the greatest fighter alive and a woman who has never in her life been allowed to choose
anything but how she swings. The line walks the player from "the sport is great" to "the sport is the
front for a house that keeps people," and ends by making Saber grant Ira the only freedom she can
still be given, which is death. That is not a twist. It is a mercy, and it is a price.

---

## The sin: wrath, and the house that serves it

The Colosseum serves wrath by **selling tickets to it**. Wrath here is not a woman — it is a **business
that discovered owned rage outperforms free morale**. The Perennial (name still provisional) is the
reigning stable: other houses recruit, buy and train; this one *keeps*. It takes the frontier's
orphans, its poor, and above all the refugees the war itself makes, and it raises them as property —
fighters who win and kill on the house's schedule and never their own, who are never once allowed to
stop — and it wins, and has for longer than anyone finds strange, because a fighter who cannot walk
away is worth more than one who can.

The appetite the house feeds is itself wrath. The crowd has learned to *hate* the refugees the war keeps
delivering to the gate — the same desperate the player was — and will pay to watch them put to the sword
(slot 2). So wrath has two faces here: the **owned rage** the house farms on the supply side, and the
**crowd's scapegoating hatred** it sells on the demand side. The house only ever prints what sells.

The house **cannot admit what it built**, because saying what Ira is means saying its champions are
*owned* — and the keeping is still going (there are children in the intake tonight). That is the vendor
serving its sin, and it is uglier than the Bastion's version: the Bastion *declined to notice* an
atrocity that had already happened; the Colosseum is **still running the intake**.

---

## Ira, the Unappeased — the general

**Who she is.** Manufactured by the Perennial to be its champion: trained since birth, ruthless,
superb — the house's masterpiece. But under the discipline is a whole person, and the one thing she
has ever wanted is to be **free** — to make her own decisions, to belong to herself. She does not. She
must fight, must win, must kill, on the house's schedule and never her own.

**The one place she was free.** Only on the sand, mid-bout, does she get to move on her own accord —
the single span of her life the house does not script move by move. So she fought, and fought
superbly, because combat was the only taste of freedom she was ever allowed. Her ferocity was never
obedience; it was the one door in the cage that opened. She kept her resentment **suppressed and
hidden** for years — a sullen wrath that was the secret engine of everything the crowd loved. Her
sullenness *was* her ferocity.

**Why nothing can settle her.** She wanted one thing, and every road to it has closed. The house never
freed her; the pact promised freedom and delivered a worse master. She cannot be *appeased* because the
thing she wants — to belong to herself — no longer exists for her: the rage owns her now. Keep this
**quiet and interior, never operatic**: the horror is a life spent owned, not a grievance to be paid.

**How she becomes a demon (canon).** She **chose** the pact. Promised freedom and the strength to seize
it, she bargained with the Demon Lord herself — and got strength and a rage she cannot govern. The
demon is not something done to her; it is **the bargain she made, come due** — the freedom she reached
for turned inside out. At 40% health the sullen restraint finally breaks and the rage takes the body
(phase two): the person who held the leash for twenty years is drowned by the thing she bought.

**Her two phases.** 1. **Sullen** — the human champion, resentment held down, still recognizably a
woman who wants out. 2. **Uncontrollable rage** — the demon, the pact come due, the person gone under.
The transform *is* the tragedy: it is the moment the freedom she chose finishes eating her.

**Her mechanics.** She is most dangerous not when winning but when **dying** — `trait_wrath_rising`
scales her damage with the fraction of health she is *missing*, plus a per-blow **contact** term (every
blow that lands feeds the rage the nearer she is to the end — the closer to gone, the less of the
person is left holding the leash). Her kit should read as immune to fear, charm, and pain-based effects
— **nothing controls her but the rage** — and the immunities are the *tragedy* (she cannot be reached,
only released), not the power. Phase two carries the rage rule off a heavier base, plus **The Only
Hour** (a telegraphed strike that doubles as she nears death) and **Run You Down** (an anti-kite hook —
the rage will not let the trade leave).

---

## Saber — the companion

**Who she is.** A **free agent of the sand** — no house, no program, come up nowhere in particular and
belonging to no one, which is exactly the point. She fights for whoever books her because she loves the
**craft**: the read, the moment, the pure self-expression of it. She is bright, warm, quick to laugh,
and she will take on anyone — she laughs in victory and in defeat alike, because the win was never the
thing; the fight was.

**Her personality and virtue.** Contentment worn as **joy**. She already has enough — every fight, the
one in front of her is enough — so time does not press on her and she never gets greedy for the kill.
That is patience: not endurance, not gritted teeth, but a person who wants nothing she does not already
have. Her patient style means promoters slot her on the **undercard**: she does not sell the fast,
bloody headline, so she fights the prelims, and she is happy there.

**Her relationship to Ira is sympathy, not recognition.** She was never in the program; she is not
looking at a version of herself. She is a **free fighter looking at a caged one**, and she is the
person in the building who most understands what has been taken from Ira — because freedom on the sand
is the whole of what fighting *means* to Saber. To her, a fighter who cannot choose to leave is the one
unbearable thing, and her sympathy is for a prisoner she can free by no door but the last one.

**What she stopped for.** Ordered once to execute helpless people to pad a card, she put her sword down
in front of a paying crowd — and the house had someone else finish it while she stood there. **The
people died anyway.** Her one great refusal saved no one and cost her the card and any house that
wanted a reliable name on a contract. It is why she signs only with a team that isn't a house, and why
she is on the sand between enforcers and the condemned before anyone asks.

**Her cost across the line.** Not complicity — she was never part of the machine. Her cost is that the
sport she loves turns out to be the front for a house that *keeps people*, and the one fighter she'd
most want to see free can be freed by no door but death. She spends the line learning that the arena
which is a joy to her is a cage to others, and at slot 10 she gives Ira the mercy she'd give anyone —
knowing Ira deserved a life instead.

---

## The foil, in arithmetic

> **Ira scales as her OWN health falls. Saber scales with her TARGET's health.** They are
> mathematically opposed on the same axis, and every bout from the debut onward teaches the player the
> lesson the general examines them on at slot 10.

- **Saber** (`weapon_first_motion`, her bound signature) hits hardest into a target at **full** health
  and falls off as they weaken: she ends things in one motion or not at all. Deliberately *not* an
  accumulate-by-idling design — dead turns are downtime, not patience. This is patience as a *verb*:
  pick the moment, commit, done. She is worthless in a long trade and devastating on the opening.
- **Ira** (`trait_wrath_rising`) wants the **long trade** — every blow wakes the rage, and she is most
  awake when dying. So the counterplay to Ira *is* Saber's whole method: **burst, do not grind.** Grind
  her down and you are only loosing the thing she cannot control.
- Under the numbers is the real foil: **freedom vs. bondage.** Saber fights because she is free and it
  is the truest expression of herself — she can walk off the sand any moment and stays only because she
  loves it. Ira fought because the sand was the only place she was ever free, and now she cannot walk
  off it at all. Saber ends a bout in one motion because nothing compels her to stay in it; Ira feeds on
  the long trade because she can never leave.
- **Saber's second relic (slot 8):** one strike per battle at full value regardless of the target's
  health, **whenever she chooses**. v1 lets the arithmetic pick her moment; v2 gives her the moment.
  *Patience becomes a choice* — the same move as Rowan's declared ward, in a different idiom, with no
  downtime anywhere in it. (Not yet written.)

---

## The ten slots

Legend: **N** narrative beat · **S** what it costs Saber · **Scenes** the scaffold files for the slot.

### Slot 1 — Debut on the Sand · `assassinate` Saber · BUILT
- **N** The nameless survivor's first bout is secretly Saber's audition of *them*. Beat her → she signs
  with the only house that isn't one. Tutorial for the foil arithmetic (her blow into full HP = the
  biggest number a new player has seen).
- **S** Nothing yet — she's enjoying herself.
- **Scenes** shipped: `conversation_wrath_intro`, `colosseum_debut_confront`, `arena_debut_event`,
  `arena_debut_kit`, `prologue_victory`, `arena_saber_joins`.

### Slot 2 — The Padded Card · `killAll` + protect
- **N** The promoter's "warm-up" is a slaughter dressed as a bout. The house has carded the capital's
  newest **refugees** — unarmed, desperate, off the same road the player fled down (see the prologue's
  arrival) — against its own hardened killers, because the crowd has learned to *hate* the people the
  war keeps pouring through the gate and will pay to watch the desperate bleed. **The village elder from
  the prologue is among them** — one of the people the player and Rowan carried out of the fire, swept
  off the bread line and onto the sand. The player fights on the refugees' side and *wins*: puts the
  carded killers down, every refugee still standing at the bell. And that is exactly why the horror
  lands — because they held, the crowd was denied its death the cheap way, so the house sends the one
  thing that never fails to fill a card. **Ira walks onto the sand and kills the refugees anyway** —
  wordless, obedient, the house's final answer. The first thing the player ever sees Ira do is take the
  walk-off away. (She does not speak; slot 7 is her first word, and the elder's death is scripted, not a
  fail-state — the player cannot save them here.)
  **And then she kills the party**, and the house *meant* her to. The crowd paid for a night of blood,
  the player's win threatened to send them home short, so the house put its patron on the sand to
  finish the card — and the card is whoever is still standing on it. The promoter is not surprised and
  does not try to call her off; his lines are the coldest in the scene. That is the lesson of the slot:
  the Colosseum will spend anyone in front of it, including its own new draw, because what it actually
  sells is the killing. The objective is already won when this plays, so what is lost is not the run,
  it is the company's lives *after* winning.
- **N (epilogue)** The venue and the stables are not the same people (*The league and the stables*),
  and the gap is what lets the story continue: the house spent a new draw for one night's crowd, and
  the stables with money on that draw did not agree. The party wakes in the **Cathedral**, raised
  because four of them paid the church's price the same night. The acolyte who performed the rite is **Amana**, and she
  is this slot's `rewardCharacter` — the priest's recruit moved off her own house's second slot (see
  *The other seven → Raised, then kept* and *The Cathedral* in `docs/story.md`). She leaves with them
  over the eleven refugees who came in on the same cart with nobody paying for **them**: she is the
  hand that writes the intake register, what she entered beside their names is *ascended to the Light*,
  and she carried them to the unmarked pit herself. The party is the only living witness to what
  happened out there. This slot is also the gate on the Cathedral itself — the building does not exist
  in the hub until this scene, so the first time the player sees the place is from a slab.
- **S** Saber knows this play cold — a veteran of the sand who has watched promoters run it for years —
  and is first down between the killers and the refugees, because everyone gets to walk off it. She
  holds her side, and wins it, and then watches Ira erase it. Her one law breaks in front of her for the
  first time, and it is the exact shape of the thing that broke her once already (slot 10, tags 30–32:
  *"they died anyway; someone else did it while she stood there"*) — done now by the fighter the line
  will end on. Then it breaks a second time, under her own feet. This is the seed slot 10 pays off.
- **Scenes** `conversation_colosseum_slot_02_intro` (scaffolded), `_outro` and `_join` (**written**).
  - *intro:* the promoter frames the "warm-up" and what the crowd is really here for; the player reads
    the far side — refugees, not fighters — and clocks the village elder among them; the house prints
    only what sells; Saber goes down first, between killers and refugees; the choice lands (hold the
    line, or let the slaughter run).
  - *outro:* the carded killers are down and the refugees are still standing, and *because* of that the
    house sends its patron; Ira cuts them down without a word and keeps walking; the promoter says the
    crowd wanted blood and the house does not send them home short; the scene ends on the avatar on
    their back, hearing the crowd cheer.
  - *join (`epilogue`):* the waking, the sponsors' coin, the eleven, the register, the pit; Amana asks
    to come. Played through the new `epilogue` seam on the quest (`states/game.lua`), which runs a
    second scene straight after the outro and holds the join banner across the first one — a recruit
    has no business in a scene where everyone dies.

### Slot 3 — Siege of Warlord's Keep · `assassinate` the Warlord
- **N** The Warlord once fought under the Colosseum's banner; they want him back or down. This is the
  sport at its genuine best — stable against a named fighter, an honest bout. The slot exists so the
  player *sees why Saber loves this* before the line charges it.
- **S** The player sees her joy.
- **Scenes** `colosseum_warlord_keep_intro`, `colosseum_warlord_keep_outro`.
  - *intro:* the vendor gives the job; this is a real bout with a name on the other side; Saber is alight.
  - *outro:* clean, great fight; Saber's joy on full display — the thing the line will later make her pay for.

### Slot 4 — The Perennial's Roster · `killAll`
- **N** The reigning stable puts four of its own on the card. They fight identically, none flinch, none
  celebrate. The player doesn't learn *why* yet — they just notice these four aren't fighting like
  people who are allowed to want anything.
- **S** Saber has fought Perennial fighters house-to-house for years and reads their openings cold —
  she knows the house style. What unsettles her isn't memory (she was never in it) — it's that these
  four move like people who aren't permitted to choose. She won't quite name it yet; changes the subject
  when asked. (The fighters deliberately don't speak — no confront.)
- **Scenes** `colosseum_perennial_roster_intro`, `colosseum_perennial_roster_outro`.
  - *intro:* the vendor puts the house's four on the card; watch how they fight, how they don't celebrate.
  - *outro:* Saber called every opening; the player asks how; she deflects (slot 5 pays it off).

### Slot 5 — The Intake · `reach`
- **N** The discovery: the *house*, not its output. An intake ledger — children received by year vs.
  the roster's wins on the facing page — kept with pride, because the house believes it's an academy.
- **S** Saber reads the ledger as the outsider who understands exactly what it is, and names it aloud:
  these aren't students, they're *owned* — the house buys children and never lets them leave. She loses
  the ability to tell herself the arena is clean.
- **Scenes** `colosseum_the_intake_intro`, `colosseum_the_intake_outro`.
  - *intro:* get into the intake hall and read the ledger; what it actually records.
  - *outro:* Saber names it — bought, not schooled; kept, not trained — and the sport she loves has an intake.
  - *(Owes the slot-5 unbuyable reward item — the intake register's counterpart.)*

### Slot 6 — Blood in the Sand · `killAll` + protect
- **N** The mirror of slot 2: now *the player* is the draw, and the promoter has padded *their* undercard
  as a courtesy — the way a house treats a headliner it wants to keep. Nobody asks permission; the card is
  already printed; the standing they need to reach Ira is paid for out of exactly this.
- **S** Afterward she asks — not rhetorically, she wants an answer — whether reaching Ira is worth
  feeding the house that made her: will they keep the top billing?
- **Scenes** `colosseum_blood_in_the_sand_intro`, `colosseum_blood_in_the_sand_outro`.
  - *intro:* you're the draw now; we padded your undercard as a courtesy; the card's already printed.
  - *outro:* Saber, afterward, wants a real answer — will you keep taking the billing?

### Slot 7 — No Third State · `survive` · THE TURN
- **N** The house schedules them onto the sand with Ira herself, three quests before they may kill her —
  not to win, just to survive to the bell. (The player first saw Ira at slot 2, wordless, doing the
  house's killing; here she is first *reachable*, and first speaks.) Ira is briefly reachable, and the
  discovery is that there's
  no bargain to strike: the house allows her two states, **win** and **kill**, and never a third — no
  *stop*, no *leave*. The one thing she ever wanted, to walk off, was never permitted, and now the pact
  she made has sealed even that. There is nothing to give her.
- **S** Saber has carried a hope that Ira could be freed some other way — and she watches the player
  reach her exactly as far as anyone can, which is not at all. The hope dies.
- **Scenes** `colosseum_no_third_state_intro`, **`colosseum_no_third_state_confront` (Ira speaks)**,
  `colosseum_no_third_state_outro`.
  - *intro:* you're on the sand with the patron; not expected to win; stay standing till the bell.
  - *confront:* Ira, scheduled, pulled off at the bell — the pre-echo of slot 10; briefly reachable and
    nothing to give her; she chose the one door out and it closed behind her.
  - *outro:* Saber watched the hope die; the turn lands.

### Slot 8 — Naming the Day · `assassinate`
- **N** Saber stops deferring. She demands the match, out loud, in front of people, and names the day.
  The house can't say yes and can't say what Ira is — so it *matches* her, against the fighter it keeps
  for people who ask questions in public. Patience becomes a **choice**.
- **S** Her second relic — patience as a verb, a chosen strike. *(Owes Saber's 2nd relic item.)*
- **Scenes** `colosseum_naming_the_day_intro`, `colosseum_naming_the_day_outro`.
  - *intro:* Saber names the day aloud; the house answers a question with a bout.
  - *outro:* waiting became choosing; the second relic lands.

### Slot 9 — What the House Does Instead · `assassinate` + protect
- **N** Cornered — the ledger's out, the day's named, the other houses are asking — the stable disposes
  of its own trainers on a card. Legal, sport, and by morning nothing left to ask about. Wrath's
  institutional face: it will spend anyone, including its architects, before it says a true sentence.
- **S** The same crime one more time — the house feeding the sand people who never chose to be there —
  and she won't let it be a show. The last quiet before slot 10.
- **Scenes** `colosseum_what_the_house_does_intro`, `colosseum_what_the_house_does_outro`.
  - *intro:* the house schedules its own trainers onto a disposal card; the player is the only one trying to stop it.
  - *outro:* killing Ira won't touch the machine; the Perennial keeps again within a year; the last quiet.

### Slot 10 — The Unappeased · `assassinate` Ira · CONFRONT SCAFFOLDED · FIGHT BUILT
- **N** The general. Ira speaks as the sullen human — the woman who wanted out; mid-fight, at 40%
  health, the pact she signed for freedom comes due and the rage takes her (phase two). Saber gives her
  the only freedom she can still be given, and it's still right — not because Ira couldn't choose, but
  because the thing she chose devoured her and death is the last door open.
- **S** She frees the one fighter she wishes she could have walked off the sand.
- **Scenes** `colosseum_general_wrath_confront` (scaffolded).

---

## Mechanics built this pass (non-dialogue)

- **Two-phase transform** — `trait_boss_phases` + a `phases` script on her Unappeased Heart
  (`utility_unappeased_heart`) sheds her into `character_general_wrath_demon` at 40% health. The trigger
  lives on her bound relic, so the looted mail never transforms the player. `models/combat.lua` now
  matches `assassinate` through a transform (engine fix; covers all seven generals).
- **Phase-two kit** — `ability_the_only_hour` (telegraphed signature, scales with her missing health),
  `ability_run_you_down` (anti-kite pull), beside her lifesteal greataxe cleave. Rage rule continues via
  `utility_unbound_heart` in the demon grid.
- Covered by `tests/general_wrath_spec.lua`.
- **Quest `epilogue`** — a second scene played straight after a quest's `outro`, before the hub or any
  follow-up leg (`states/game.lua`). Slot 2 needs it because the killing and the waking are one beat
  across two places, with no leg between them: more lines on the end of the outro would keep the party
  on the sand they just died on. Like `followUp` it defers the join banner to the second scene.

## Open threads
- Saber's **second relic** (slot 8) — not written.
- Slot 5 **unbuyable** reward item — not written.
- The **phase tell** log line on the transform — the moment the restraint breaks; left out for you to write.
- `docs/story.md` pact-rule section: flip Ira from the "never chose" exception to **an example of the
  rule (a human who pacted)**, and repair the Livia cross-reference that pairs them as inverses.
- Slots 2–9 stand-in enemy blueprints (Perennial fighters, culls) — `character_champion` /
  `character_survivor` placeholders, flagged in each quest header.
- Slot 2 **village elder** — reuses the prologue's `elder` cast id in dialogue; wants a bespoke
  board/protect blueprint (`character_village_elder`) so the person the player saved in the prologue is
  the one Ira cuts down. `character_survivor` stands in for them and the other refugees until then.
  **The elder has no settled gender**: nothing in `data/` or the prologue ever gives one, so the slot-2
  scenes are written around the pronoun rather than picking it. Decide it with the blueprint.
- Slot 2's **revival** raises four dead fighters at an altar whose power is Luxuria's blood. Whether
  the party owes the demon their lives from here on is unanswered on purpose; see *The Cathedral →
  What is built, and what is not* in `docs/story.md`.

## Companion coverage
Every scene should let recruited companions speak (companions-speak-in-every-scene standard). The
scaffolds carry Saber's block; `colosseum_general_wrath_confront` is the density model with the full
roster (`character_rowan`, `character_amana`, `character_gyeom`, `character_kaya`, `character_ren`,
`character_clem`), each gated by `when = { has = "character_<id>" }`. Add blocks per slot as you write.
