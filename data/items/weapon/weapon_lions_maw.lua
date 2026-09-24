-- LION'S MAW: the Chimera's bite, and the lion is the body -- so this is the one mouth that walks. A
-- creature's natural weapon: `natural` family, no contract, unstealable.
--
-- IT EATS WHAT THE GOAT COOKED. +4 against a Burning foe, through trait_hearth_hunger (the same rule its
-- Battlemage drop carries at +3), so the bonus is summed by Trait.outgoingDamageBonus on the blow AND on
-- the hover, and the forecast shows it. The combo lives inside one body: the goat sets up, the lion
-- collects.
local Curve = require("models.curve")

return {
    name = "Lion's Maw",
    description = "A bite. Increase damage by 4 against a Burning foe.",
    flavor = "The goat cooks. The lion eats. The serpent watches the door.",
    sprite = "assets/items/weapon_lions_maw.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "physical", "melee", "slash" },
    noSteal = true,
    traits = { "trait_hearth_hunger" },
    traitParams = { magnitude = 4 },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
