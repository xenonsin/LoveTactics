-- TOAD SPIT: the Giant Toad's answer to a body it cannot reach. A glob of spittle thrown three or four
-- tiles, just past the Tongue Lash, that sticks where it lands (status_mired: every step and cast costs
-- double, and gaining it stops the walk). Settled on review 2026-09-25: "Spit is good as an attack if the
-- toad can't reach".
--
-- PLAIN SPIT, NOT THE MEAL. A toad that is holding a body keeps holding it: spitting never costs it its
-- Full, because the swallow is the whole reason it is dangerous and a ranged poke must not undo it.
--
-- AND IT FEEDS THE LOOP. A Mired body is one the toad's next Pull or hop reaches, so the thing it does
-- when it cannot reach you is what makes you reachable. Not the Sated's Retch, which is a cone that eats
-- armour (status_acid): this is one target, and it takes where you can go rather than what you wear.
local Curve = require("models.curve")

return {
    name = "Spit",
    description = "Spits at a foe 3 to 4 tiles away, dealing damage and inflicting Mired.",
    flavor = "It does not have to reach you. It only has to slow you down until it can.",
    sprite = "assets/items/ability_toad_spit.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "physical", "water" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 3, -- inside that the tongue reaches, and the tongue poisons
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(3, 13),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_mired" })
        end,
    },
}
