-- The Beloved's devotion, and the phase script that keeps sending more of it.
--
-- Every threshold sheds a pair of petal-drifts -- which in this circle is not a screen but a WORSENING
-- of the dilemma: more chaff means more reasons to hold your good ability, and holding it is what the
-- Suppliant's rule punishes. The apex does not get stronger; it makes the decision harder.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Beloved's Devotion",
    description = "Sheds a pair of petal-drifts as it is wounded.",
    flavor = "Whatever it was loved for, it has forgotten. It has not forgotten being loved.",
    sprite = "assets/items/beloveds_devotion.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_boss_phases" },
    phases = {
        { at = 0.66, responses = {
            { kind = "summon", id = "character_petal_drift", count = 2 },
            { kind = "log", text = "The grove sends more of itself, and none of it is worth killing." },
        } },
        { at = 0.33, responses = {
            { kind = "summon", id = "character_petal_drift", count = 2 },
            { kind = "log", text = "More still. The choice gets worse, not the fight." },
        } },
    },
}
