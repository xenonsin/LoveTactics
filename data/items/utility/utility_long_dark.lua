-- The Long Winter's own cold, and the phase script that spreads it.
--
-- Built on trait_boss_phases. Each threshold sheds a pair of drift-things, which is the tundra's
-- escalation stated correctly: the apex does not get stronger, it gets more bodies that take TURNS off
-- you (data/items/weapon/weapon_drift_touch.lua). On the board where movement is free, being slowed is
-- the only real cost, and this manufactures more of it.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "The Long Dark",
    description = "Sheds a pair of drift-things as it is wounded.",
    flavor = "It is not waiting for anything. It has simply outlasted everything that was.",
    sprite = "assets/items/long_dark.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_boss_phases" },
    phases = {
        { at = 0.66, responses = {
            { kind = "summon", id = "character_drift_thing", count = 2 },
            { kind = "log", text = "The cold around the Long Winter thickens, and two pieces of it move." },
        } },
        { at = 0.33, responses = {
            { kind = "summon", id = "character_drift_thing", count = 2 },
            { kind = "log", text = "More of the drift stands up. None of it is in a hurry." },
        } },
    },
}
