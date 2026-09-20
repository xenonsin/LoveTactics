-- DEADFALL: the Vengeful Spirit's blow, and the first time in this fight that anything it is wearing
-- can hurt anybody.
--
-- The Meandering Stag carries no weapon at all -- not a weak one, none, and `unarmed = false` on the
-- blueprint means it has no fists either. So this is not an upgrade to an attack, it is the arrival of
-- one, and the number is priced for that: 20 at the low end against the road's apexes at 15-24, on a
-- body the party has only had to OUTLAST until this moment. Half the fight was terrain.
--
-- ONE TILE, NOT A SWEEP, which is where it differs from every other antlered thing in the catalogue.
-- The Winter Hart sweeps a 3-wide front off a four-tile body because its bulk is the statement; this
-- body is 2x2 and moving at 6, and its statement is that it ARRIVES. A sweep would make standing apart
-- pointless, and standing apart is the only thing the party has left once the floor has turned.
--
-- IT ROOTS WHAT IT CATCHES, and that is the one line that makes the ground matter rather than merely
-- exist. A blighted board is survivable by walking; a body that cannot walk is standing in it. So the
-- blow does not need to be large -- it needs to leave somebody where the floor can finish the work,
-- which is the whole arrangement this fight has been building toward since the first tile it laid.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua). The player's version of
-- this fight is on the blueprint's `drops` list and is none of this.
local Curve = require("models.curve")

return {
    name = "Deadfall",
    description = "Strikes an adjacent foe and Roots it where it stands.",
    flavor = "The wood has been holding this up for ninety years. It stops.",
    sprite = "assets/items/weapon_deadfall.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "physical", "impact", "melee", "nature" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(20, 30),
        effect = function(fx)
            local target = fx.target
            if not target then return end
            fx.damage(target)
            -- Root and not Stun: a stunned body is shoved down the order and comes back, a rooted one
            -- is HELD, which is the only status that makes standing on bad ground a sentence rather
            -- than an inconvenience. It is also the honest reading of what a falling bough does.
            fx.applyStatus(target, "status_root")
        end,
    },
}
