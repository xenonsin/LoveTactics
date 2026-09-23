-- THREE ROWS: the Manticore's bite. A creature's natural weapon -- `natural` family, no contract,
-- unstealable (tests/spoils_spec.lua's creature-kit rule). Three rows of teeth, one behind the other: the
-- one thing Ctesias, Pliny and Aelian all agree the animal has.
--
-- NO RULE OF ITS OWN, and that is the design rather than a gap. It was pitched as the manticore's reload
-- -- tearing its quills back out of you to regrow its tail -- and cut on review (2026-09-23) for a tail on
-- a cooldown. What it keeps is its tag: it is PIERCE, so every quill in the body it bites makes it land
-- harder (status_quilled), exactly as it makes the company's arrows land harder on the manticore's
-- victims. Nothing here reads the stacks, because the status already does.
local Curve = require("models.curve")

return {
    name = "Three Rows",
    description = "A bite.",
    flavor = "The first row takes hold. The other two are for afterwards.",
    sprite = "assets/items/weapon_three_rows.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "physical", "melee", "pierce" },
    noSteal = true, -- the teeth are the manticore's
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
