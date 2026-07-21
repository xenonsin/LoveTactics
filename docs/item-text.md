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

The tooltip (`ui/item_tooltip.lua`) renders the description high, under the headline stat, and the
flavor last — italic, dimmed, below a separator — so the mechanical read is never behind the prose.

`tests/item_schema_spec.lua` sweeps every blueprint and enforces both fields exist, that they differ,
and that the description stays under its length ceiling.

## description — what it does

1. **One sentence**, ideally under 12 words. Two only when a passive and an active both need saying.
2. **Lead with the verb.** "Deals fire damage…", "Grants +2 defense…", "Restores 20 health."
   Not "A pot that, when thrown, deals…".
3. **Name game nouns exactly as the UI spells them**, capitalized: Burn, Bleed, Defending, Mana.
   A status named here must match the `name` in its `data/status/<id>.lua`, or the player is hunting
   a word the game never shows them again.
4. **No prose framing.** "A pot of volatile powder", "A slender blade that has changed hands" — that
   is flavor wearing a description's clothes. Cut it and move what survives to `flavor`.
5. **Never restate a row the tooltip already prints**: Power, Range, Speed, cost, Tags, Quantity all
   have their own rows. Say the *effect*; let the rows carry the numbers. A magnitude the rows do not
   show (a Bleed of 5, a heal of 20) is fair game and usually worth saying.
6. **No lore.** No factions, no people, no history.

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
description: one mechanical sentence, lead with the verb, name game nouns exactly, no lore. The gate
text itself (`unlock.text`) and the cost/Range/Speed rows carry the rest — don't restate them.
`tests/item_schema_spec.lua` requires this string on every unlock- or windup-gated ability. A plain
spell whose whole item *is* the ability lets the top `description` speak for it and omits this.

## flavor — what it means

1. **One or two sentences.** It has the tooltip's last word, so it should be worth reading.
2. **It must reveal something about the world** — who made it, who wants it, what it cost, what it
   says about a sin or a faction. A prettier restatement of the mechanic is a failed flavor line:

   > ✗ `flavor = "It burns those it touches."` — the description already said that.
   > ✓ `flavor = "The Crucible sells it by the crate. The fire is chemistry, and it does the same to a wizard as to a knight."`

3. **Source it from the file's own comment block.** Most blueprints already open with several lines
   of lore that has never been rendered. Compress that; do not invent new canon. Where the comment
   names a vendor or a sin (the Crucible, the Undercroft, Greed), keep that thread — those map to the
   seven vendors in `docs/story.md`, and the flavor lines are how a player ever feels that mapping.
4. **Never mechanically load-bearing.** A player who skips every flavor line loses no information
   they need. If a rule only appears in flavor, it is in the wrong field.

## Where the text shows up

| Surface | description | flavor |
|---|---|---|
| Item tooltip (`ui/item_tooltip.lua`) | under the headline stat | italic, last, after a separator |
| Shop panel (`ui/panels/shop.lua`) | yes | italic, beneath it |
| Blacksmith panel (`ui/panels/blacksmith.lua`) | yes | italic, beneath it |

The italic is faked with a shear transform, not an italic font — the project ships no font asset and
LÖVE's default face has no italic. `ItemTooltip.printFlavor` owns that math; call it rather than
re-deriving the shear, and note it reserves horizontal room for the slant's overhang.
