-- ECHO: one of the Siren's own (data/characters/character_siren.lua). A voice that carries somebody
-- else's words: when an ally who hears you casts an ability, you get a copy of it at half power, held
-- until you use it (trait_echo -- the Copycat's loan, pointed at your own side).
--
-- It is what the company's SIREN SONG became. That drop came back "rework" twice on review, and the
-- replacement Keno picked is this one.
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
return {
    name = "Echo",
    description = "When an ally who hears you casts an ability, you get a copy of it at half power until you use it.",
    flavor = "The mere gives back whatever is said over it, a little later and a little softer.",
    sprite = "assets/items/utility_echo.png",
    type = "utility",
    tags = { "arcane" },
    class = "priest",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_echo" },
}
