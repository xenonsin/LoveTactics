-- WILL NOT BE HURRIED: the Old Spruce's own (data/characters/character_old_spruce.lua; "Sloth's Bestiary",
-- 2026-10-04). It never attacks; its roots spread a tile each turn, and a body ending its turn beside it is Rooted
-- (trait_will_not_be_hurried).
--
-- `bound`, `noSteal`, `class = "creature"`: an organ, never kit. The body's trophy is the Spruce Staff.
return {
    name = "Will Not Be Hurried",
    description = "Never attacks. Each turn it grows one more tile of uncrossable root, and a body ending its turn beside it is Rooted.",
    flavor = "It has stood through four hundred winters and does not see why this one should be different.",
    sprite = "assets/items/utility_will_not_be_hurried.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true,
    traits = { "trait_will_not_be_hurried" },
}
