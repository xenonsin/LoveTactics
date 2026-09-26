-- THE LAST RITE: what keeps Vesh standing, and what dead kobolds kneel to. Bone-Knit at its own toll --
-- a lethal blow is refused for 40 mana and he stands back up WHOLE, as often as his pool pays -- which is
-- the skeleton rule itself (the review's reading of "worse than skeleton": a phylactery was a fussier copy
-- of a rule the game already had). And the Lich flag, so the dead kobolds treat him as their dragon.
--
-- Bound and noSteal: this is what he IS. His pool is one number paying for three things -- his deaths, his
-- Foreclosures and the skeletons he calls (each reserves a fifth of it) -- so the company reads the whole
-- fight off his blue bar.
return {
    name = "The Last Rite",
    description = "Consume 40 mana when a blow would fell you, and stand back up at full health. Dead kobolds kneel to you.",
    flavor = "He said it over himself before the dwarves came down. Then he waited, and they came.",
    sprite = "assets/items/utility_the_last_rite.png",
    type = "utility",
    class = "creature",
    tags = { "dark" },
    noSteal = true,
    bound = true,
    traits = { "trait_bone_knit", "trait_lich" },
}
