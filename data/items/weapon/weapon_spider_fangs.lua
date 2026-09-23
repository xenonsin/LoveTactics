-- SPIDER FANGS: the Giant Spider's bite (and the brood's). A creature's natural weapon -- `natural`
-- family, no contract, unstealable (tests/spoils_spec.lua's creature-kit rule).
--
-- It does not fight what is still struggling; it fights what is stuck. So the bite lands half again as
-- hard on a Rooted body -- the Poacher's Kris rule, which is where the Lodge learned it -- and the web is
-- what makes a body Rooted (data/hazards/hazard_web.lua), and so is the Silk Shot beside it.
local Curve = require("models.curve")

local PINNED_BONUS = 0.5 -- +50% on a Rooted target

return {
    name = "Spider Fangs",
    description = "Inflicts Poison. Deal 50% more damage to a Rooted foe.",
    flavor = "The web does the work. This is only how it gets paid.",
    sprite = "assets/items/weapon_spider_fangs.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "physical", "melee", "pierce" },
    noSteal = true, -- the teeth are the spider's
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            local pinned = fx.hasStatus(fx.target, "status_root")
            local bonus = pinned and math.floor(fx.amount * PINNED_BONUS) or 0
            fx.damage(fx.target, { amount = fx.amount + bonus, inflicts = "status_poison" })
        end,
    },
}
