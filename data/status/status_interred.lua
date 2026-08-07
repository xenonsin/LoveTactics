-- Interred: the rites have been said over a body that is still walking, and the world has taken them
-- at their word. Nothing heals it any more -- every heal aimed at it lands as a wound of the same size,
-- whatever the source: a spell, a potion, a Regeneration tick, a Sanctuary's ground, a lifesteal drink.
-- Combat.applyHeal turns it around at the top, which is the funnel all of those run through, so one
-- flag catches them together and none of them can route around it.
--
-- THE STEP PAST THE UNCLOSING WOUND, and worth being exact about the difference, since the two look
-- like the same idea at two strengths and are not. A blocked heal costs the enemy healer a turn: they
-- cast, nothing happens, the board is where it was. An INVERTED heal costs them the target. It turns
-- the most reflexive decision in the game -- heal the one who is falling -- into the thing that fells
-- them, and it keeps doing it for as long as their healer keeps doing its job. The counterplay is not
-- a bigger heal, it is NOTICING: stop healing, and cure this instead.
--
-- Which is why it is not the cheap one. The Unclosing Wound rides in on a coated blade for the price of
-- a phial (data/items/consumable/consumable_thinblood_rime.lua); this costs the Arcanum's own necromancer
-- a cast, a heavy mana bill and a turn (data/items/ability/ability_early_rites.lua), and it is
-- `resistible = "magical"` -- warded by magicDefense and statusResist, halved on every repeat -- so the
-- second one said over the same body is a poor bargain.
--
-- A body under BOTH this and an Unclosing Wound is simply not healed: the block is checked first and
-- refuses outright. A heal that was never going to land cannot be turned around, and stacking the two
-- must never be worth more than either alone.
--
-- The undead do not wear this. Being past healing is a standing fact about a corpse rather than a
-- condition it caught, so it rides on data/traits/trait_grave_cold.lua and reads through the same
-- Combat.healingInverted question -- and, unlike this, cannot be cleansed off a thing that is dead.
return {
    name = "Interred",
    abbr = "Intr",
    description = "Interred: every heal lands as a wound instead.",
    color = { 0.612, 0.596, 0.318 }, -- badge tint (curdled grave-gold)
    duration = 8,                 -- ~1.5 turns: one healer's decision, not a healer taken away
    debuff = true,
    resistible = "magical",       -- warded by magicDefense + statusResist, halved on every repeat
    invertsHealing = true,
}
