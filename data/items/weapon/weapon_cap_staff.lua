-- The cap-staff: the Verger's rod of office, a heavy stalk with a hard cap on the end.
--
-- A verger walks in front of a procession with a staff and keeps order in the nave; this one keeps it
-- with the end of the staff. Slow and physical, and a demon's blow burns (docs/bestiary.md) -- `fire` on
-- the tags, the channel unmoved, so a coat still answers it. The staff is the Verger's afterthought: what
-- it is for is standing in front of the Thurifer and making the company hit it (weapon_call_to_order,
-- trait_spongeflesh).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Cap-Staff",
    description = "A slow, heavy blow to an adjacent foe.",
    flavor = "Order in the nave. There is always order in the nave.",
    sprite = "assets/items/cap_staff.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "fire", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
