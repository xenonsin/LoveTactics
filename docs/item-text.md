# Item text

Every item blueprint carries two strings, and they have different jobs:

```lua
name = "Fire Bomb",
description = "Deals fire damage in the target area and inflicts Burn.",
flavor = "The Crucible sells it by the crate. The fire is chemistry, and it does the same to a wizard as to a knight.",
```

`description` answers **what does this do**. `flavor` answers **what does this mean**. A player who
reads only descriptions can play the game perfectly; a player who reads only flavor learns the world
and nothing about the fight. Neither one may do the other's job.

Read the description like a Magic: The Gathering card's **rules text**: plain, uniform, verb-first,
no atmosphere. Read the flavor like the *italic line under the rules box* — where all the prose
lives. If a description is doing anything a card's rules text would not, it is wrong.

The tooltip (`ui/item_tooltip.lua`) renders the description high, under the headline stat, and the
flavor last — italic, dimmed, below a separator — so the mechanical read is never behind the prose.

`tests/item_schema_spec.lua` enforces that both fields exist, differ, and that the description stays
under its length ceiling. `tests/item_text_style_spec.lua` enforces the mechanical style rules below
(banned filler, canonical durations, keyword capitalization, a status named-not-re-explained, and no
prose-frame lead like `Toggle:`) so they cannot quietly drift.

## description — what it does

1. **One sentence**, ideally under 12 words. Two only when a passive and an active both need saying.
2. **Lead with the verb**, third person: "Deals fire damage…", "Grants +2 Defense…", "Restores 20
   health.", "Inflicts Poison." Never a bare imperative ("Move…", "Strike…") and never a bare
   possessive lead ("Your spells…" → "Spells you cast…").
3. **Voice: `you`/`your` is the wielder, and only the wielder.** "Allies adjacent to you gain
   Blessed." / "Grants +1 Movement." (not "Move one extra tile each turn"). Foes are "foes" or
   "the target", never addressed as "you".
4. **Name the status, capitalized — then stop.** Never re-explain a status you just named:
   `"inflicts Frozen."`, not `"inflicts Frozen: delayed, and brittle to crush and fire."` The status's
   mechanics render in the **glossary column beside the tooltip**, which `models/glossary.lua` builds
   from the ability's *effect* — not from this text — so the definition appears whether or not you
   repeat it. Repeating it is pure duplication. (The lint bans the tell: a `<Status>:` restatement.)
   - **Readable noun, not the participle badge:** `Silence`, `Halt`, `Haste` — not `Silenced`,
     `Halted`, `Hasted`. The glossary links either way, and the noun reads as rules text.
   - **Verb by valence:** **inflicts** a debuff (`inflicts Poison`), **grants** a buff (`grants
     Haste`), **applies** a mixed/neutral one (`applies Reckless`, `applies Drunk`). A **positional**
     effect stays an action verb — `"Knocks a foe back"`, never `"inflicts Knockback"`.
   - **Never bury a status in a lowercase verb** — "poisons it", "roots it", "silences it" hide a word
     the glossary is standing by to define; name it. (A lowercase common-English use that is *not* the
     game status is fine — "the fire burns" — but if the item applies Burn, say Burn.)
   - Referring to a foe that *already carries* a status reads naturally as the capitalized adjective —
     "Executes a Rooted foe", "doubled against a Frozen foe" — and is correct; this rule is about
     *applying* a status, not naming one as a target condition.
5. **No prose framing — plainest concrete terms.** "A pot of volatile powder", "Wreathes you in
   smoke:", "The Golden Touch:", "Bloodied by a blow, you…" — that is flavor wearing a description's
   clothes. Cut it and move what survives to `flavor`. This holds *inside* the sentence too: name the
   plain game noun, never a coloured version of it. `gold`, not "a little coin loose for the party";
   "every foe it hits gives gold", not "pays the company coin". The coloring goes to `flavor`.
6. **Never restate a row the tooltip already prints**: Power, Range, Speed, cost, Tags, Quantity all
   have their own rows. Say the *effect*; let the rows carry the numbers. A magnitude the rows do not
   show (a Bleed of 5, a heal of 20) is fair game and usually worth saying. The **target row** counts
   too: it already names who the ability hits, so drop "to a foe" / "on an ally" — a plain
   single-target line ends at the status (`"Inflicts Silence."`). Add a scope phrase *only* when the
   effect reaches past the aimed target: `"on adjacent foes"`, `"on nearby foes"`, `"on the attacker"`
   (a reactive). The **attack footprint** is a row too: the tooltip draws the `aoe` shape
   (`ui/footprint_diagram.lua`), so don't spell it out — cut `"the two tiles ahead"`, `"a wide arc"`,
   `"three tiles down the line"`, `"in the target area"`, keeping only per-tile nuance the picture
   can't carry (`"on the near tile"`, `"friend and foe"`). A *placed* zone or hazard (a 3×3 banner,
   a wall) is not the attack footprint and keeps its shape; so do knockback and range distances,
   which have their own rows. An area effect ends with the canonical scope phrase **`in area`**
   (`"Inflicts Frozen in area."`), not "in the target area" / "on everyone hit"; a foe-only or
   summoned-only filter is kept as the noun (`"Sears enemies in area."`), but "friend and foe" is not.
7. **Triggered effects use the trigger frame:** `On <trigger>: <effect>.` The trigger is the
   mechanical event — `On hit taken:`, `On damage dealt:`, `On death:`, `On a nearby cast:` — and the
   effect is the plain result. `"Every blow you land on a living foe steals gold."` → `"On damage
   dealt: gain gold."`; `"When you take a hit, you drink a healing potion."` → `"On hit taken: drink a
   healing potion."` This colon is a *mechanical* label, not the flavor frame rule 5 bans. A discrete
   event earns the frame; a continuous modifier (`"Blows deal extra damage while a foe is adjacent"`)
   does not.
8. **No lore.** No factions, no people, no history.

### Standardized effect forms

Several effect shapes have one canonical wording so the corpus reads uniform. Clauses under a frame
(`On <trigger>:`, `For each <X>:`) and directives (`Increase damage…`) are written imperatively.

- **Knockback is a named effect** — write `Knockback`, never "drives them back a pace" / "shoves back".
- **Scaling is a directive:** `Increase|Decrease damage for each <condition>.` — `"Increase damage for
  each foe in area."`, `"Increase damage for each foe you have killed this battle."` Never "lands
  harder for every…", "devastating against a lone foe, weaker for every extra body".
- **Per-object iteration:** `For each <X> in area <effect>.` — `"For each corpse in area consume it and heal."`
- **On-hit / on-damage riders take the trigger frame** (rule 7): a lifesteal / heal-on-hit reads
  `"On damage dealt: heal."`, not "heals you for a share of every wound".
- **Never restate the damage school.** Physical vs magical is a tag row: `"Deals magical damage and
  inflicts Hollowed."` → `"Inflicts Hollowed."`
- **AoE scope is `in area`.** The footprint draws the *shape*; the description ends an area effect
  with `in area` (`"Inflicts Frozen in area."`) — never "in the target area", "on everything it
  caught", "on everyone hit", and never "friend and foe". Keep only a filter noun (`"Sears enemies in
  area."`, `"Unmakes summoned creatures in area."`) or a within-footprint sub-selection (`"on the far tile"`).
- **Omit "Deals no damage."** Never state the absence of damage; drop the clause everywhere.
- **Damage is a row, not a clause.** The amount (Power row) and the type/school/element
  (physical/magical/fire/ice/lightning/holy — all tags) are never restated. When the line names a
  status or a hazard, drop the damage clause entirely: `"Deals ice damage and inflicts Frozen"` →
  `"Inflicts Frozen in area."` A pure-damage attack with no other effect keeps a bare `"Deals damage."`
- **A hazard is a glossary noun — name it, don't describe it.** Use the consistent verb **`Leaves`**:
  `"leaves the ground burning"` → `"Leaves Fire in area."`, `"sets the ground alight"` → `"leaves Fire
  where it lands."` (The glossary defines Fire, Quicksand, Rain, Sacred Ground… beside the tooltip.)
- **Armor-piercing is one phrase: `Damage ignores armor.`** Never describe it ("cuts through armor
  rather than at it", "ignoring armour entirely", "no ward turns it").
- **`Summon` is the verb for creating a creature** (not Raises / Calls / Binds / Conjures), and its
  side + control read as adjectives: **`allied`/`enemy`** and **`uncontrollable`** (a creature that
  acts on its own AI). `"Raises corpses as zombies that fight for you but obey no orders"` →
  `"For each corpse in area, summon an allied, uncontrollable zombie."`
- **`Consume` is the verb for spending a resource** (not Spends): `"Spends all Defiance…"` →
  `"Consume all Defiance…"`
- **A wind-up / channeled ability uses the prefix `Channeled: <effect>.`** — replaces "Winds up,
  then…", "Drawn over a full turn". (`Channeled:` and `Toggle:` are mechanical labels, **exempt** from
  the banned prose frames — which are only `Triggered:`/`Passive:`/`Active:`.)
- **Range is a row — don't state it.** Drop `"at range"`, `"at long range"`, `"a foe two tiles off"`;
  the Range row and diagram carry reach.
- **Scaling uses specific math, never a vague magnitude or a flavor threshold. Always read the exact
  coefficient from the effect code.** `"up to double at death's door"` → `"Increase damage by 1% per
  1% of missing health."`; `"far harder for every kill"` → `"Increase damage by 25% per kill"`;
  `"harder for the mana held"` → `"Increase damage by 1 per 10 mana the target holds."` Banned: "at
  death's door", "far harder", "devastating". (A per-unit bonus that is level-scaled — `3 + level` —
  stays unit-form, `"for each …"`, since no single number is true across the forge.)
- **A moving field (censer/cloak aura) grants its status to adjacent units.** Don't narrate the
  field: `"Carries red smoke with you: allies standing in it gain Bloodsong."` →
  `"Grants Bloodsong to adjacent allies."` (`Inflicts … on adjacent foes` for a hostile field;
  `on adjacent units` when it hits both sides). A field with no unit-status (Darkness blocks sight)
  keeps its hazard name: `"Carries Darkness with you."`

## Durations — say them the way a card does

Magic never says "for a while". Timing is either a **fixed phrase** or **implied by the condition**,
and everything vague is banned. Match the situation to a form:

| Situation | Card analog | Our wording |
|---|---|---|
| A status with its own tick countdown (Burn, Poison, Root, Stun…) | a keyworded ability | **No duration phrase.** `"inflicts Burn."` — the tooltip's hourglass row carries the ticks. |
| An effect that lasts the whole fight | "for the rest of the game" | **`this battle`** — the one canonical form (not "for the rest of the battle", not "most of the battle"). |
| A one-round self effect | "until your next turn" | **`until your next turn`**. |
| A continuous effect while a mechanical condition holds | a static ability | **No duration phrase — the condition IS the duration.** `"Allies adjacent to you gain Blessed."` The leash is `adjacent to you`. |
| A genuinely conditional window | "as long as ~" | **`while <mechanical condition>`** — the condition must be mechanical (adjacency, a named status, an HP threshold), never a flavor object. `"while a foe is adjacent"` ✓ / `"while the smoke holds"` ✗. |

**Banned in descriptions** (lint-enforced): `for a while`, `a short while`, `for a time`, `briefly`, `for most of
the battle`, `most of the battle`, `for the rest of the battle` (use `this battle`), `a sliver`,
`far more`, `far deeper`, `greater power`, and any "while the <flavor thing> holds". A vague
comparative magnitude (`far more`, `greater power`) earns a concrete number only when the tooltip
does not already show it; otherwise drop the comparative and let the row speak.

## Before / after

Real lines, and what the rules make of them:

> ✗ `"Wreathes you in smoke: allies standing beside you are Blessed."`
> ✓ `"Allies adjacent to you gain Blessed."` — the smoke goes to `flavor`.

> ✗ `"Raises an ally's defenses for most of the battle, and makes them proof against Halt."`
> ✓ `"Grants Defending and immunity to Halt this battle."` — the target row already says it's an ally.

> ✗ `"Skewers the two tiles ahead, and roots whatever is on the near one in place."`
> ✓ `"Hits the two tiles ahead and inflicts Root on the near one."`

> ✗ `"Move one extra tile each turn."`
> ✓ `"Grants +1 Movement."`

> ✗ `"Deals holy damage. Demonic flesh takes far more."`
> ✓ `"Deals holy damage, doubled against demons."` — only if 2× is the real value; otherwise drop
> the clause and let the damage row carry it.

## activeAbility.description — what a signature does

Most items are covered by the two strings above. An item that carries a **conditional/signature**
active — one gated by `activeAbility.unlock` (Weather N blows) or `activeAbility.windup` (a held
wind-up) — needs a third: the ability's own effect, because the shield's passive guard is not its
sweep. Put it on the ability, not the item:

```lua
activeAbility = {
    description = "Strikes every adjacent foe and shoves them two tiles back.",
    unlock = { event = "hitTaken", count = 4, text = "Weather 4 blows" },
    ...
}
```

The tooltip renders it directly under the ability heading, above the stat rows and the unlock gate,
so a player reading "Weather 4 blows (2/4)" also learns what earning it buys. Same rules as the item
description: one mechanical sentence, lead with the verb, name game nouns exactly, controlled
durations, no lore. The gate text itself (`unlock.text`) and the cost/Range/Speed rows carry the
rest — don't restate them. `tests/item_schema_spec.lua` requires this string on every unlock- or
windup-gated ability. A plain spell whose whole item *is* the ability lets the top `description`
speak for it and omits this.

## flavor — what it means

1. **One or two sentences.** It has the tooltip's last word, so it should be worth reading.
2. **It must reveal something about the world** — who made it, who wants it, what it cost, what it
   says about a sin or a faction. A prettier restatement of the mechanic is a failed flavor line:

   > ✗ `flavor = "It burns those it touches."` — the description already said that.
   > ✓ `flavor = "The Crucible sells it by the crate. The fire is chemistry, and it does the same to a wizard as to a knight."`

3. **This is where the stripped atmosphere lands.** When a rule above pulls a phrase out of a
   description ("Wreathes you in smoke", "The smoke goes where the priest goes"), that imagery
   usually belongs in flavor — as long as it still reveals something about the world and does not
   just re-describe the effect.
4. **Source it from the file's own comment block.** Most blueprints already open with several lines
   of lore that has never been rendered. Compress that; do not invent new canon. Where the comment
   names a vendor or a sin (the Crucible, the Undercroft, Greed), keep that thread — those map to the
   seven vendors in `docs/story.md`, and the flavor lines are how a player ever feels that mapping.
5. **Never mechanically load-bearing.** A player who skips every flavor line loses no information
   they need. If a rule only appears in flavor, it is in the wrong field.

## Where the text shows up

| Surface | description | flavor |
|---|---|---|
| Item tooltip (`ui/item_tooltip.lua`) | under the headline stat | italic, last, after a separator |
| Shop panel (`ui/panels/shop.lua`) | yes | italic, beneath it |
| Blacksmith panel (`ui/panels/blacksmith.lua`) | yes | italic, beneath it |

A **status** or **keyword** description is item text too, and it reaches the player through the same
two surfaces: the glossary (`ui/glossary_panel.lua`) prints the `description` off `data/status/*.lua`
and `data/keywords/*.lua` verbatim beside the item tooltip and at the foot of the shop's detail pane.
Write those lines to the rules above — mechanical, one sentence, no flavor. Keep them **short**: the
shop's docked form runs the name and the description together on one wrapped line in a 344px column,
so a rambling status description is what pushes a third definition off the panel.

The flavor line is rendered in a real italic face (`Alegreya Sans Italic`) via `Theme.bodyItalic`;
`ItemTooltip.printFlavor` owns the layout and reserves room for the slant's overhang. Call it rather
than re-deriving the metrics.
