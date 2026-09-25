-- Dread: the Gilt Wyrm's helm of terror, worn as part of the body (data/characters/character_gilt_wyrm.lua).
-- The trait it carries is the same one the Aegishjalmur lends its bearer (data/traits/trait_helm_of_terror.lua):
-- foes near it lose their footing. Bound and natural -- an organ, not kit.
return {
    name = "Dread",
    description = "Foes within 2 of you move 2 fewer spaces.",
    flavor = "Nothing near it wants to be near it, and the feet know before the head does.",
    sprite = "assets/items/utility_wyrm_dread.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_helm_of_terror" },
}
