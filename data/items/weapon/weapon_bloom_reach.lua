-- A bloom-wraith's reach: it strikes from cover and does not stay to be answered.
--
-- The forest is the ambush board -- open trails through thick cover -- so its line body is the one that
-- refuses a clean trade. `hitAndRun` gives ground after the blow, which means a melee counter thrown
-- once the whole action has resolved finds nothing in reach to answer (Combat.beginAnswers, and
-- data/items/weapon/weapon_wolf_fangs.lua makes the same argument at length).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")
local GIVE_GROUND = 1

return {
    name = "Bloom Reach",
    description = "Strikes an adjacent foe, then gives ground a tile.",
    flavor = "The grove has been here a long time and has learned not to be where you swing.",
    sprite = "assets/items/bloom_reach.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true,
    hitAndRun = GIVE_GROUND,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
            fx.retreat(fx.target, GIVE_GROUND)
        end,
    },
}
