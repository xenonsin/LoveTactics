-- THE THIRST: what the VAMPIRE TAG puts in the grid (Character.VAMPIRE_GRANT, seeded beside Grave-Cold the way the
-- undead tag seeds it). Wrath's vampires, 2026-09-26, "The Vampires of Wrath". A dry turn climbs the Thirst, and at
-- 3 the vampire is in Bloodlust; drawing blood heals it and ends it; it smells a bleeding foe (trait_the_thirst,
-- models/thirst.lua). Bound and unstealable: an organ, not kit.
return {
    name = "The Thirst",
    description = "Gain Thirst each turn you draw no living blood; at 3, Bloodlust. Drawing blood heals you and resets it.",
    flavor = "A dry tongue behind long teeth, and a throat that tightens every hour it goes without.",
    sprite = "assets/items/utility_the_thirst.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_thirst" },
}
