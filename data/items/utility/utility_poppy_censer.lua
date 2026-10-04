-- POPPY CENSER: the Poppy-Moth's trophy (data/characters/character_poppy_moth.lua), on the Apothecary's shelf.
-- Approved on "Sloth's Bestiary" (2026-10-04). The moth's cloud in a company's hand: when the bearer is struck, the
-- foes beside it fall Asleep, and then it rests for 3 turns (trait_poppy_censer). Foes only, unlike the moth's.
--
-- A utility, not a censer weapon: it lays no incense and is not swung. `unstocked`: the body's own piece, visible
-- on its house's rack and never sold (docs/drops.md).
return {
    name = "Poppy Censer",
    description = "When you are struck, foes beside you fall Asleep. Then it rests for 3 turns.",
    flavor = "A brass cup of dried poppy, lit and hung at the belt. The apothecaries call it a sedative.",
    sprite = "assets/items/utility_poppy_censer.png",
    type = "utility",
    tags = { "charm" },
    class = "apothecary",
    unlockLevel = 10,
    unstocked = true,
    traits = { "trait_poppy_censer" },
}
