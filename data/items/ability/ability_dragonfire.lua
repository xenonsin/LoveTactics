-- DRAGONFIRE: Avaritia's breath (reviewed 2026-09-25, "Avaritia, the Unspent"). ONE ITEM, HERS AND YOURS: she
-- carries this very piece (a monster may carry a root class's shelf stock -- the mage is a root), and it is
-- what she drops. A turn-long wind-up, then a cone five deep off the FACE of the caster's body
-- (models/hoard.lua's cone: 1, 3, 3, 5, 5 across off one tile, 2, 4, 4, 6, 6 off her 2x2) that burns
-- everything in it, leaves the ground alight and melts coin heaps to Molten Gold. The biggest cone in the
-- game, paid for with a telegraph and with FRIENDLY FIRE: it burns its caster's own side too -- her kobolds
-- included, so a wave can be baited into it.
--
-- A general's find: `unstocked`, on the mage's rack and never sold.
local Curve = require("models.curve")

local LENGTH = 5

return {
    name = "Dragonfire",
    description = "Winds up a turn, then breathes a wide cone of fire that burns both sides, sets the ground alight and melts coin heaps.",
    flavor = "It was never meant to be breathed by anything that has to stand in front of it.",
    sprite = "assets/items/ability_dragonfire.png",
    type = "ability",
    tags = { "fire", "magical", "breath" },
    class = "mage",
    unlockLevel = 6,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = LENGTH,
        speed = 5,
        windup = 5, -- a turn: the cone is committed here
        cooldown = 20,
        cost = { stat = "mana", amount = 14 },
        damage = Curve.ramp(10, 26),
        aoe = {
            cells = function(_, tx, ty, unit)
                if not unit then return { { x = tx, y = ty } } end
                return require("models.hoard").cone(unit, tx, ty, LENGTH)
            end,
        },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.alive then fx.damage(u, { inflicts = "status_burn" }) end
            end
            require("models.hoard").burnCells(fx, fx.aoeCells(), 3 + (fx.level or 0), 8 + (fx.level or 0))
        end,
    },
}
