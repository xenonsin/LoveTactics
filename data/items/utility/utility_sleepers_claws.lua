-- SLEEPER'S CLAWS: the Ground Sloth's trophy (data/characters/character_ground_sloth.lua), on the Monk's shelf.
-- Approved 2026-10-04 on "Sloth's Bestiary", slice A: "Each turn you end without attacking banks a blow, up to 3.
-- Your next attack strikes once more per blow banked."
--
-- A FIST, AND SO A CHARM. The review called it a fist weapon; the monk's shelf has no weapon family (docs/classes.md:
-- "a monk fist weapon would need a new archetype"), and every fist piece on it is a "fist"-tagged charm that works
-- the bare hand (Swift Fist, Iron Fist). So this is one more: the bank is earned by trait_sleepers_claws and spent
-- by weapon_unarmed, which lands once more per banked blow. A crafted weapon spends nothing, as Swift Fist doubles
-- nothing for one.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Sleeper's Claws",
    description = "Each turn you end without attacking banks a blow, up to 3. Your next bare-handed strike lands once more per blow.",
    flavor = "The monks call it patience. The sloth that grew them never called it anything.",
    sprite = "assets/items/utility_sleepers_claws.png",
    type = "utility",
    tags = { "fist" },
    class = "monk",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_sleepers_claws" },
}
