-- TAIL SWEEP: Avaritia's ordinary blow (reviewed 2026-09-25, "Avaritia, the Unspent"). A 2x2 body does not
-- reach out with one claw: the sweep takes every foe standing against her footprint, corners included, so
-- crowding her costs everyone who crowds. Paired with her Wing Buffet: spread out, and come in one or two at
-- a time. Creature kit.
local Curve = require("models.curve")

return {
    name = "Tail Sweep",
    description = "Deals damage to every foe beside you.",
    flavor = "The hoard shifts under it like a tide going out.",
    sprite = "assets/items/weapon_tail_sweep.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(12, 24),
        aoe = {
            cells = function(_, tx, ty, unit)
                if not unit then return { { x = tx, y = ty } } end
                return require("models.hoard").ring(unit)
            end,
        },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.side ~= fx.user.side then fx.damage(u) end
            end
        end,
    },
}
