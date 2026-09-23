-- CASTOFF: Moult rebuilt as a coat (armor_castoff_coat). Once, at half health, the wearer sheds every
-- harmful status and slips out of sight until their next turn (status_invisible). Mark forbids
-- Invisible, and the shedding takes the Mark off first -- which is the whole trick of it.
local AT = 0.5

return {
    name = "Castoff",
    description = "Once, at half health: sheds every harmful status and goes Invisible until your next turn.",
    onDamaged = function(ctx)
        if (ctx.trait.stacks or 0) > 0 then return end
        local unit = ctx.unit
        local hp = unit.char.stats.health
        if not (hp.max and hp.max > 0 and hp.current / hp.max <= AT) then return end
        ctx.trait.stacks = 1
        require("models.combat").cleanse(ctx.combat, unit)
        ctx.applyStatus(unit, "status_invisible")
        ctx.log("action", string.format("%s slips out of the coat.", (unit.char and unit.char.name) or "Unit"))
    end,
}
