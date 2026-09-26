-- LICH: what a dead kobold kneels to. A kobold that has died treats a lich as its dragon
-- (Devotion.isDragonTo): the Dragon's Eye near him, Fervor when he is struck, Forsaken when he is
-- destroyed. A living kobold does not kneel to him. The dragonkin trait's twin, and deliberately a second
-- flag rather than the same one -- the living would otherwise follow him too.
return {
    name = "Lich",
    description = "Dead kobolds who see you struck are driven to Fervor; dead kobolds who see you destroyed are Forsaken.",
    lich = true,
    notAReaction = true,
    onDamaged = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit and unit.alive) then return end
        local n = require("models.devotion").rally(combat, unit)
        if n > 0 then
            ctx.log("action", string.format("The dead kobolds see %s struck, and rage.",
                (unit.char and unit.char.name) or "their master"), unit)
        end
    end,
    onDeath = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit) then return end
        local n = require("models.devotion").forsake(combat, unit)
        if n > 0 then
            ctx.log("action", string.format("%s is destroyed, and the dead who served him are Forsaken.",
                (unit.char and unit.char.name) or "Their master"), unit)
        end
    end,
}
