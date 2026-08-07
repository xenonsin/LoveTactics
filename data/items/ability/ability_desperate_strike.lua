-- Desperate Strike (the recommended name for "power scales with health lost"): a cornered fighter
-- hits hardest. Its Power climbs with the fraction of health the caster is MISSING -- at full health it
-- is an ordinary blow (x1), at death's door it lands with double force (x2). Read live from the
-- caster's current/max health at the moment of the swing, so the more the fight has cost you, the more
-- each strike takes back.
local Curve = require("models.curve")

return {
    name = "Desperate Strike",
    description = "Increase damage by 1% per 1% of missing health.",
    flavor = "The Colosseum noticed the pattern long before it thought to sell it back to you.",
    sprite = "assets/items/ability_desperate_strike.png",
    type = "ability",
    tags = { "slash", "physical" },
    class = "fighter",
    discipline = "barbarian", -- deeper cut of the shelf: buyable only once the barbarian gate is cleared
    price = 620,
    unlockQuests = 9,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(13, 23), -- the base, at full health; scaled up by the missing fraction below
        effect = function(fx)
            local hp = fx.user.char.stats.health
            local ratio = (hp.max and hp.max > 0) and (hp.current / hp.max) or 1
            local missing = math.max(0, 1 - ratio)
            fx.damage(fx.target, { amount = fx.amount * (1 + missing) }) -- x1 full -> x2 at 0 HP
        end,
    },
}
