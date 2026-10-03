-- THE TAPESTRY: Arachne's own (data/characters/character_arachne.lua; "Envy's Bestiary", 2026-10-03, slice C).
-- Every ability the company casts in her sight is a thread; at 3 threads of one she casts it back, once
-- (trait_the_tapestry, status_woven).
return {
    name = "The Tapestry",
    description = "Weaves each ability a foe in sight casts. At 3 threads of one, casts it back at the caster once.",
    flavor = "The goddess's was better. Nobody who has seen this one has said so.",
    sprite = "assets/items/utility_the_tapestry.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_the_tapestry" },
}
