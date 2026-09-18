-- Lifted off Second Water, and it is what makes the Glass's free body worth protecting.
--
-- THE PAIR. The Envious Glass stands a copy of your strongest foe on your side at the opening bell, and
-- the copy is the whole of its value -- once it is dead the relic has already spent itself. This hits
-- harder at anything with more health than you, and while a body you took still stands that condition is
-- LIFTED and everything takes the heavier blow (data/traits/trait_covetous_eye.lua): you already have
-- the thing you wanted, so nothing is beneath you.
--
-- Which turns killing the copy into the other side's best play, and keeping it alive into yours. The
-- Glass alone never gave anybody that decision.
--
-- IT WORKS ALONE. The things worth envying are the things standing between you and the stair, so on a
-- floor where you are outmatched it pays constantly -- and it pays least in the fights you were already
-- winning, which is the right way round.
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
local Curve = require("models.curve")

return {
    name = "The Second Vessel",
    description = "Increase damage by 5 against a foe with more health than you, or against any foe while your copy stands.",
    flavor = "The vats were run twice. This held what came off the second time, and the Crucible sold " ..
        "it as the first.",
    sprite = "assets/items/second_vessel.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    noSteal = true,
    traits = { "trait_covetous_eye" },
    bonus = { magicDefense = Curve.ramp(1, 11) },
}
