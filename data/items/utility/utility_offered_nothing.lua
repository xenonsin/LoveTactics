-- THE SUPPLIANT'S BOWL: Luxuria's rule, cut down, and the Lust mini sin's whole reason to exist.
--
-- Luxuria's Reliquary Unbidden draws off the stamina and mana a foe HELD BACK on every hit
-- (data/traits/trait_rapture.lua) -- unconditionally, so a party husbanding resources is feeding her and
-- has no way to notice.
--
-- So the honour-guard floor only drains a body that held its turn, and then stops asking:
--
--   from the bell   The Unasked: it drains whoever spent nothing (data/traits/trait_unasked.lua)
--   at 50%          it drains regardless, which is Luxuria's baseline
--
-- THAT IS THE RULE FOR THE WHOLE TIER: a mini sin's second phase is its general's first. The phase hands
-- over the general's own trait rather than a lesser copy, so the back half of the fight is literally what
-- waits at the bottom of the stair.
--
-- She is the Unbidden -- the one who was never asked. This one asks: named for the office rather than
-- for the mechanic, which is how the whole tier is named.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Offered Nothing",
    description = "Drains a foe that spent nothing, and once wounded drains regardless.",
    flavor = "It has been holding the bowl out for a very long time and has stopped minding what goes in.",
    sprite = "assets/items/offered_nothing.png",
    type = "utility",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_unasked", "trait_boss_phases" },
    phases = {
        { at = 0.5, responses = {
            { kind = "summon", id = "character_petal_drift", count = 2 },
            { kind = "bonus", stat = "magicDamage", amount = 6 },
            { kind = "log", text = "The Suppliant stops asking." },
        } },
    },
}
