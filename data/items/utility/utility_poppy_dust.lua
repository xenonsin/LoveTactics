-- POPPY DUST: the Poppy-Moth's own (data/characters/character_poppy_moth.lua; "Sloth's Bestiary", 2026-10-04). It
-- carries the cloud -- struck or felled, every body beside it falls Asleep, on either side (trait_poppy_dust) --
-- and the wings, which are the `flying` tag (Combat.isFlying). Roots bar a flier all the same.
--
-- `bound`, `noSteal`, `class = "creature"`: an organ, never kit. The body's trophy is the Poppy Censer.
return {
    name = "Poppy Dust",
    description = "Flies. When struck, bursts: every body beside it falls Asleep, on either side.",
    flavor = "It does not mean anything by it. It is a moth.",
    sprite = "assets/items/utility_poppy_dust.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "flying" },
    bound = true,
    noSteal = true,
    traits = { "trait_poppy_dust" },
}
