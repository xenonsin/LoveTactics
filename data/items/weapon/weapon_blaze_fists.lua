-- BLAZE FISTS: the Blaze's natural weapon (models/storm.lua; "Fire, Lightning, and Dirty Thunder", 2026-09-27). A
-- physical blow with fire on it, as a demon's claws are ("demons burn"): `physical, slash`, with `fire` added at the
-- swing -- so a coat still stops it, a fire ward blunts it, and a DOUSED Blaze (status_doused) swings without it.
-- The element rides the cast rather than the item for exactly that: water takes the fire out of its hands.
--
-- It carries Storm-Kin, the rule that fuses a Blaze with an Arc beside it. `noSteal`: the fire is not yours to take.
local Curve = require("models.curve")

return {
    name = "Blaze Fists",
    description = "Strikes an adjacent foe with burning fists.",
    flavor = "It does not hold the fire. It is what the fire is doing.",
    sprite = "assets/items/weapon_blaze_fists.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "physical", "slash", "melee" },
    noSteal = true,
    traits = { "trait_storm_kin" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if fx.hasStatus(fx.user, "status_doused") then fx.damage(t) else fx.damage(t, { tags = { "fire" } }) end
        end,
    },
}
