-- FLASHPAN: the Arc's Thunderclap (trait_thunderclap; "Fire, Lightning, and Dirty Thunder", 2026-09-27), and one of
-- the three things it drops. The first body your lightning strikes each turn is Blinded. Blind came from the
-- Burning Halo and a few casts; never, until this, as a rider on lightning.
return {
    name = "Flashpan",
    description = "Your lightning inflicts Blind on the first body it strikes each turn.",
    flavor = "The thunder is only noise. It is the light you remember.",
    sprite = "assets/items/utility_flashpan.png",
    type = "utility",
    tags = { "lightning" },
    class = "mage",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_thunderclap" },
}
