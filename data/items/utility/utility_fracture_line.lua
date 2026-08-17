-- The Unwanted's fracture lines, and the phase script that shatters it.
--
-- Built on trait_boss_phases, whose `summon` response calls bodies onto open tiles beside the bearer.
-- Every threshold crossed sheds a pair of glass-motes: the apex does not get stronger as it is cut, it
-- gets MORE, which is a different problem from the one the health bar suggests.
--
-- IT SHATTERS INTO MOTES, not into character_homunculus_discard. The discard is CARGO -- a `protect`
-- objective that stands where it is put with a holdGround posture -- and its own header spends a
-- paragraph on why it must never be fielded as a combatant. Splitting into it would have rebuilt the
-- exact bug this pass removed from Gluttony's honour-guard slot. The motes are the circle's own swarm
-- and behave like something that just came off a larger piece of glass.
--
-- Which also feeds the circle's real rule: every mote it sheds is another body stripping blessings, and
-- what the stripping decides is who Second Water's mirror finds weakest.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Fracture Line",
    description = "Sheds a pair of glass-motes as it is wounded.",
    flavor = "Cast in one piece, and not well. It has been coming apart since the day it cooled.",
    sprite = "assets/items/fracture_line.png",
    type = "utility",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_boss_phases" },
    phases = {
        { at = 0.66, responses = {
            { kind = "summon", id = "character_glass_mote", count = 2 },
            { kind = "log", text = "A crack runs through the Unwanted, and two pieces of it walk away." },
        } },
        { at = 0.33, responses = {
            { kind = "summon", id = "character_glass_mote", count = 2 },
            { kind = "log", text = "The Unwanted comes further apart, and there is more of it than before." },
        } },
    },
}
