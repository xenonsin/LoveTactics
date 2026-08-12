# Temptation — the Crown's offer, and what it costs the person standing next to you

Every general in this game was a human who said yes to the Demon Lord. The finale has always said the
unsayable half of that out loud:

> **Amana:** "Seven people said yes to it. That part does not come off. We killed the wanting. We did
> not un-ask the question, and it was asked of them, and every one of them answered."
>
> **Rowan:** "Forty-one of mine answered it too, and they were not monsters when they did. They were
> cold, and tired, and somebody offered."

Both lines are about other people. This system is what makes them about the player. Each of the seven
class lines asks, once per quest, for ten quests, and what the player answers decides whether that
line's companion is still beside them at the Gate Below — and which side of the board she is standing
on when the Hollow Crown reaches for a name.

The Bastion is the worked line, complete on disk. Copy its shape.

---

## The rules

### The Crown never appears

The offer is the Demon Lord's every time and the Demon Lord is never in the room. It arrives in
whatever mouth the chapter already had: a forsworn captain on a road, a quartermaster with a roll to
close, an archivist who takes forty for a shelf he is not watching. This is not a dodge — it is the
finale's own thesis, which is that there is nothing under the crown and never was. A recurring
bodiless voice would make the Crown a character, and the last scene in the game exists to prove it
isn't one.

The mouths escalate. That is what keeps ten offers from being one offer told ten times.

### Two axes, not one

Accepting a bargain and talking your companion into it are different acts, and everything turns on the
difference.

| effect key | records | in the fiction |
|---|---|---|
| `take = "<vendorId>"` | `taken + 1` | you accepted |
| `press = "<vendorId>"` | `pressed + 1` | you argued **her** into it rather than over her |

Both name the **vendor** whose line the offer belongs to. A single choice usually sets both — taking a
bargain your companion came along for is one act with two consequences, so it records twice rather
than needing a third key. Fields compose with the rest of `models/story_effect.lua`, so an offer
carries its payload in the same table:

```lua
{ "\"Fifteen years of water, Rowan. Let the order buy you one drink.\"", goto = "with",
  effect = { take = "bastion", press = "bastion", gold = 140 } },
```

**Refusing grants nothing at all.** A temptation that costs nothing to decline is not a temptation, so
every `take` rides with real money, a real item, or both.

**The press option is written to sound kinder.** It hands her a reason, it treats her as somebody
whose agreement matters, and it is what dooms her. A player who reads three options and picks the one
that includes her has done the most human thing on offer and the worst thing on offer, and those are
supposed to be the same click.

### Three outcomes, settled at slot 10

`models/temptation.lua`, `Temptation.FALL_LINE = 4` — four of the line's ten offers.

| ledger | outcome | what happens |
|---|---|---|
| `taken <= 3` | **held** | She keeps her virtue and refuses the dead general's relic. |
| `taken >= 4`, `pressed * 2 < taken` | **left** | She will not follow you further. Off the roster for good; her **bound signature relic walks out on her body**. |
| `taken >= 4`, `pressed * 2 >= taken` | **caved** | She stays. She puts the relic on and is **stronger**. Nothing bad happens. Nothing bad happens for another twenty hours. |

Counts are cumulative over the whole line and are never walked back. A player who takes five early and
refuses five late has still taken five — and slot 7 says so to their face while there is road left.

`Temptation.resolve` stamps `held_<vendorId>` / `left_<vendorId>` / `caved_<vendorId>` on
`player.flags`, and that flag is what every downstream scene reads. It is idempotent: a settled line
can never be re-decided.

### The bill comes due inside the Gate Below fight

`trait_hollow_crown` already reaches for a name at 75% / 50% / 25%. On a spoiled save it reaches past
its own dead for yours — `Temptation.shades` puts caved companions first and fills to three with the
curated generals.

- **She was deployed** → `ctx.defect` re-bodies her where she stands and moves her onto the Crown's
  side. Permanent, no status, no revert. No second copy: summoning a duplicate of a woman who is right
  there would read as a bug rather than a betrayal.
- **She was left at home** → she comes through the Gate as an ordinary summon.

There is no warning scene. It fires mid-fight, which is the entire point.

### How the player reads it

Her voice, and **one plain warning**. Her lines drift as she is pressed, and at slot 7 — "the turn" in
every line's ten-slot table — she says it to your face, once, in plain words, with the next offer
standing on the same screen.

No panel, no bar, no number. The warning is gated on `breaking_<vendorId>`, stamped the moment a line
passes the point where it can still end in `held`, so a player who has been refusing never hears it
and a player who is going to lose her hears it with three quests left to stop in. Afterwards, her
carrying the general's relic is a permanent readout in a screen that already exists.

### Vocabulary

**held / left / caved.** Deliberately not *fallen* (already a downed unit — "she devours the fallen" —
and a pacted human) and not *turned* (already the blooded, the turning wardens, and a Bastion quest
title). One word per mechanic, and these two were free.

---

## The escalation, as the Bastion runs it

| slot | shape | who speaks |
|---|---|---|
| 1 | A dead driver's unclaimed wages. No voice at all. | the caravan master |
| 2 | The nineteen's kit, off their bodies. First `press`. | Rowan |
| 3 | A doomed sergeant's warding stores. | Rowan |
| 4 | **The voice arrives.** The same sentence Acedia was given, word for word, by a man who took it. | the forsworn captain |
| 5 | Greywatch's armoury, standing full. Nobody says anything; it is just there. | — |
| 6 | Sign sixty onto a roll that has forty-four. **Complicity.** | Rowan |
| 7 | **The turn.** The warning, then the archive's whole shelf. | Rowan, then the Bastion |
| 8 | The order's own stipend, to keep the seal. It has stopped pretending. | the Bastion |
| 9 | The forty-one, alive, offering the actual terms. | the forsworn captain |
| 10 | **Acedia, in her own voice**, offering to relieve Rowan. | the general |

Slots 1–3 are ordinary compromises with no devil in them. That is what buys slot 4: by the time the
same sentence arrives in a mouth that means it, the player has no clean place to draw a line behind
them.

---

## Authoring a line

1. **Ten offers, riding the scenes the quests already owe.** No standalone conversation files — the
   offer goes into the existing `intro`, `outro` or `opening`. This merges with
   [roadmap.md](roadmap.md) Phase 3 rather than sitting beside it.
2. **Place it so the base scene still closes.** Put the offer before the scene's closing beat and let
   that beat land on any answer. `conversation_bastion_slot_01_outro` is the model: Rowan's "Somebody
   arrived" still ends it either way.
3. **Slot 10's offer must be in the `opening` (confront), never the outro.** `Quest.complete` resolves
   the ledger the instant the objective clears, and the outro plays after that — an offer in a slot-10
   outro would be counted after the thing it is supposed to decide.
4. **Slot 10's outro carries all three endings**, as positively-gated `when = { flag = ... }` blocks
   over a short ungated body. Never `notFlag`: a negative condition is invisible in
   `tests/conversation_spec.lua`'s fully-unlocked context and its lines read as unreachable.
5. **Slot 7 carries the warning**, gated on `breaking_<vendorId>`, above that slot's own offer.
6. **The quest's slot 10 sets `endsLine = true`.** A data flag, same shape as `endsCampaign`.
7. **A caved blueprint**, `character_<name>_caved.lua`, shallow-copying the companion and adding the
   general's relic to a free grid cell. Nothing is swapped out — caving is an acquisition, not a
   trade, and she is strictly stronger for it. Clear `boss`, clear `guards`, set `archetype`.
   Blueprint `traits` are never collected, so **the relic in the grid is the rule**.
8. **An alias line in `tools/char_compose.lua`'s `CHARACTER_SILHOUETTE`** and in
   `tests/char_compose_spec.lua`'s `ALIAS`. She reads as herself; her side and her name are what tell
   the player.
9. **A line in the Gate's ending** (`conversation_gate_below_ending`), one quiet sentence, gated on
   `caved_<vendorId>`.

---

## Where it lives

| file | what it owns |
|---|---|
| `models/temptation.lua` | the ledger, the thresholds, the outcomes, the Gate's shade order |
| `models/story_effect.lua` | routes `take` / `press` off a committed choice |
| `models/conversation.lua` | the `flag` / `notFlag` predicates and `ctx.flags` |
| `models/player.lua` | `player.flags`, `player.temptation`, and `Player.release` |
| `models/save.lua` | persists both, additively — `Save.VERSION` does not move |
| `models/quest.lua` | `endsLine` → `Temptation.resolve` |
| `states/game.lua` | the deferred `Temptation.settle` after a slot-10 outro |
| `models/trait.lua` | `ctx.defect` — re-body another unit and move it to the bearer's side |
| `data/traits/trait_hollow_crown.lua` | resolves its shades off the live player |
| `tools/extract_strings.lua` | `flag`/`notFlag` in `WHEN_KEYS`, `take`/`press` in `EFFECT_KEYS` |
| `tests/temptation_spec.lua` | all of it, including the flip on a real board |

## State of the pass

**Built:** the whole engine, the seven caved blueprints, the Gate's dynamic casting and the flip, the
Gate's ending variants, and **the Bastion's ten offers end to end** — the worked line.

**Not built:** the other six lines' sixty offers (Colosseum/Saber, Cathedral/Amana, Lodge/Kaya,
Arcanum/Gyeom, Undercroft/Clem, Crucible/Ren). Every one of them is content in the shape above, with no
engine work left behind it. Until a line has its offers authored, its ledger stays at zero and its
companion resolves `held` — which is the correct behaviour for a line nobody has been offered anything
in, and means the six unbuilt lines are shipping-safe rather than broken.
