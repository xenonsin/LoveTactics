-- The Lindworm's Heart: Sigurd roasted the dragon's heart, burned his thumb on it, tasted the blood and
-- understood the birds -- and the birds told him the smith meant to kill him. Off the Gilt Wyrm
-- (data/characters/character_gilt_wyrm.lua), reviewed 2026-09-25 with the note "have it go on cooldown":
-- every three turns, not once a fight.
--
-- The warning is the Dodge reflex's machinery (Trait.tryEvade) with the one difference that makes it a
-- warning rather than footwork: it slips ANY blow, a spell included (data/traits/trait_birds_warning.lua).
return {
    name = "The Lindworm's Heart",
    description = "Evade the next attack of any kind, then 3 turns before you can again.",
    flavor = "Taste it and the birds start making sense. Most of what they say is about you.",
    sprite = "assets/items/utility_lindworm_heart.png",
    type = "utility",
    class = "hunter",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_birds_warning" },
}
