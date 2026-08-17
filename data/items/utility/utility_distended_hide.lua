-- The Sated's hide, and the phase script that makes it the one fight in the descent that gets easier.
--
-- Built on trait_boss_phases, which reads its table off the RELIC in the bearer's grid rather than off
-- any Lua of its own -- so a phased body is authored by writing an item. Every response kind used here
-- already exists: `bonus` (a flat, permanent per-battle stat change) and `log`.
--
-- The magnitudes are NEGATIVE, which is the whole piece. Every other phase table in the game turns a
-- boss up at each threshold -- the Champion's Demon Sigil arms a Roar and then enrages; the Hollow
-- Crown summons three times. This one turns itself down: cut it and it deflates, losing the armour and
-- the weight that the meal put on it.
--
-- Read against Ira's Unappeased Heart it is the exact inverse, and that is why it belongs to Gluttony:
-- an appetite that has been satisfied is not a threat that escalates, it is one running down. A player
-- who commits everything into the first two turns is rewarded rather than punished, which is the
-- opposite lesson to the one Wrath's circle teaches -- and both are true, in their own stratum.
--
-- Natural kit: no class, no price, noSteal, outside every shelf (tests/bestiary_spec.lua).
return {
    name = "Distended Hide",
    description = "Sheds defense and damage as it is wounded.",
    flavor = "Most of a circle went in here. None of it made the thing faster.",
    sprite = "assets/items/distended_hide.png",
    type = "utility",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_boss_phases" },
    phases = {
        -- Two-thirds: the meal starts coming off it.
        { at = 0.66, responses = {
            { kind = "bonus", stat = "defense", amount = -4 },
            { kind = "log", text = "The Sated sags. Something it ate is coming back out." },
        } },
        -- One-third: it is a large animal that has been opened, and no longer much of an argument.
        { at = 0.33, responses = {
            { kind = "bonus", stat = "defense", amount = -4 },
            { kind = "bonus", stat = "damage", amount = -5 },
            { kind = "log", text = "The Sated deflates, and swings like something much smaller." },
        } },
    },
}
