# The Seven Deadly Sins and the Demon Lord

The endgame is not bolted onto the progression loop — it *is* the progression loop, followed to its
end. Each of the seven class vendors sells you gear, ranks you up, and walks you toward the sin it has
been quietly serving the whole time. Kill all seven generals and the Gate Below opens.

This document is the bible for that arc, and the template for finishing it. **Wrath is authored end to
end; the other six are not.** Copy its shape.

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
