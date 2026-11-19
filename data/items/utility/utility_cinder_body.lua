-- What a CINDER SLIME is (data/characters/character_cinder_slime.lua): Wrath's slime body -- proof against
-- steel, adapting to elements, and it leaves a trail of fire wherever it walks (trait_cinder_trail).
--
-- It erupted at five hits taken until the creature identity pass (2026-11-19), which was the Asura chi's
-- "chipping it charges it" printed again. The trail is a rule the board shows: you can see where it has been.
return {
    name = "Cinder Body",
    description = "Voids blades, points and blows. Takes on elements. Every tile it steps through catches Fire.",
    flavor = "It has been angry for a very long time, and it is not finished.",
    sprite = "assets/items/cinder_body.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_cinder_trail" },
}
