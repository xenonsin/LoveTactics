-- The Rift-Born's seams, and the phase script that cuts the board in half.
--
-- Built on trait_boss_phases, whose `summon` response calls bodies onto open tiles beside the bearer.
-- Each threshold sheds a pair of ember-spits -- which is not a screen, it is TERRAIN: an ember-spit
-- leaves fire on the tile it dies on (data/traits/trait_cinderfall.lua), so every one you kill takes
-- another square of standing room away from you.
--
-- So the Rift-Born does not get stronger as it is cut. It gets a smaller room. Which is the honest
-- reading of an apex on the `rifts` carve, where there is no warren to block and denial has to come from
-- somewhere other than bulk.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Riftline",
    description = "Sheds a pair of ember-spits as it is wounded.",
    flavor = "The seam it came out of has not closed either.",
    sprite = "assets/items/riftline.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_boss_phases" },
    phases = {
        { at = 0.66, responses = {
            { kind = "summon", id = "character_ember_spit", count = 2 },
            { kind = "log", text = "The seam widens, and two more things climb out of it." },
        } },
        { at = 0.33, responses = {
            { kind = "summon", id = "character_ember_spit", count = 2 },
            { kind = "log", text = "The Rift-Born splits further. The room is getting smaller." },
        } },
    },
}
