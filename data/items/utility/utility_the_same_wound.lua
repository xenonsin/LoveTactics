-- THE SAME WOUND: what a bear has instead of a technique, and the carrier for trait_fury_swipes.
--
-- The natural cousin of utility_feral_instinct -- a passive utility whose whole effect is the trait it
-- grants -- and it sits in a bear's loadout for the same reason: born with, never bought. Where the
-- Instinct is a reflex (struck, it strikes back), this is a HABIT: it does not look for a new place to
-- start. Both beasts that carry it are doing the identical thing at different sizes, which is what makes
-- the cub a lesson rather than filler (data/characters/character_bear.lua, character_sow.lua).
--
-- No `class` beyond `creature`, no `price`, no `dropTier`, `noSteal`. Creature kit carries no axis at
-- all, which is what keeps a boss's own rule out of the drop pool and off the Market's shelf -- the
-- seventeen-item lesson docs/bestiary.md spends a section on. A bear's habit is not a trinket anybody
-- can lift off it.
return {
    name = "The Same Wound",
    description = "Each landed blow on the same body deepens Fury Swipes, up to 4.",
    flavor = "It does not look for a new place to start.",
    sprite = "assets/items/the_same_wound.png",
    type = "utility",
    class = "creature",
    tags = { "beast", "natural" },
    noSteal = true, -- a habit, not a trinket: there is nothing here to pick
    traits = { "trait_fury_swipes" },
}
