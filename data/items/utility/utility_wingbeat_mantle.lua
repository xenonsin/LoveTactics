-- WINGBEAT MANTLE: a strip of Avaritia's wing, lifted off her (reviewed 2026-09-25, "Avaritia, the
-- Unspent"). Her Wing Buffet at a tile's reach (data/traits/trait_wingbeat.lua): whoever comes to stand
-- against the wearer is thrown back at the start of its turn.
--
-- A general's find: `unstocked`, on the skirmisher's rack (the house of keeping your distance).
return {
    name = "Wingbeat Mantle",
    description = "At the start of your turn, every foe beside you is knocked back 1.",
    flavor = "It still stirs when anything comes too close, as if the rest of her were somewhere behind it.",
    sprite = "assets/items/utility_wingbeat_mantle.png",
    type = "utility",
    tags = { "wind" },
    class = "skirmisher",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_wingbeat" },
}
