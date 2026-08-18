-- Lifted off the Gralloch, and it is what the Maw's surplus is for.
--
-- THE PAIR. The Maw of the Unfed heals its wearer on every blow landed, and every point of that heal
-- past full is currently thrown away. This turns health above the halfway mark into damage
-- (data/traits/trait_larder.lua), so the two together invert the usual curve: the longer the trade runs
-- the harder you hit. That is what Gula was, and what the Maw on its own could never express -- it made
-- the surplus and had nothing to spend it on.
--
-- IT WORKS ALONE, and honestly: a company opens a fight at full health, so it pays from the first
-- exchange and thins as the fight takes its toll. It is the reward for being ahead, which is a real
-- thing to build toward even with no relic feeding it.
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
local Curve = require("models.curve")

return {
    name = "Larder Hook",
    description = "Your blows are heavier for every point of health you hold above half.",
    flavor = "The Gralloch hung its catch on this. Nothing on it was ever taken down.",
    sprite = "assets/items/larder_hook.png",
    type = "utility",
    tags = { "relic" },
    noSteal = true,
    traits = { "trait_larder" },
    bonus = { health = Curve.ramp(4, 14) },
}
