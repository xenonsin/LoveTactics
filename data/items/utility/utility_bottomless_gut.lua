-- BOTTOMLESS GUT: the Sated's own loop, worn by a Barbarian (data/traits/trait_bottomless_gut.lua). A foe
-- that dies beside you is eaten: a meal, +2 Damage and +2 Defense for -1 Movement, up to three. Approved on
-- review (2026-09-23).
return {
    name = "Bottomless Gut",
    description = "A foe that dies beside you is eaten: gain a meal (+2 damage, +2 defense, -1 movement), up to 3.",
    flavor = "There is always room. There is, for some reason, always room.",
    sprite = "assets/items/utility_bottomless_gut.png",
    type = "utility",
    tags = { "charm" },
    class = "barbarian",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_bottomless_gut" },
}
