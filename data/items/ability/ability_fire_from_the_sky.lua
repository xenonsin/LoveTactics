-- FIRE FROM THE SKY: Avaritia's strafe as a spell (reviewed 2026-09-25, round 3, "Avaritia, the Unspent").
-- A TWO-TURN wind-up that marks a whole row or column of the board through the aimed tile
-- (models/hoard.lua's line), then burns every unit in it -- both sides -- and every tile of it, melting any
-- coin heap it crosses to Molten Gold. The biggest area in the game, paid for with the longest telegraph.
-- Unlike hers, the caster stays where it stood: it calls the fire down, it does not fly it.
--
-- A general's find: `unstocked`, on the mage's rack and never sold.
local Curve = require("models.curve")

return {
    name = "Fire from the Sky",
    description = "Winds up two turns, then burns every unit in a whole row or column, on both sides. The ground is left alight.",
    flavor = "The town heard it before it saw it, and saw it only once.",
    sprite = "assets/items/ability_fire_from_the_sky.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "mage",
    unlockLevel = 6,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 8,
        speed = 5,
        windup = 10, -- two turns: the line is painted, and everyone gets to read it twice
        cooldown = 30,
        cost = { stat = "mana", amount = 20 },
        damage = Curve.ramp(10, 26),
        aoe = {
            cells = function(combat, tx, ty, unit)
                return require("models.hoard").line(combat, unit, tx, ty)
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
