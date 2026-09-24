-- CALDERA PLATE's rule (data/items/armor/armor_caldera_plate.lua): once a battle, the first blow that
-- takes the bearer below half health makes them boil over -- every adjacent foe is set Burning.
return {
    name = "Caldera Plate",
    description = "Once per battle, dropping below half health burns every adjacent foe.",
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) or ctx.trait.stacks > 0 then return end
        local hp = u.char.stats.health
        if hp.current * 2 >= hp.max then return end
        ctx.trait.stacks = 1
        for _, other in ipairs(ctx.unitsNear(u.x, u.y, 1)) do
            if other ~= u and other.alive and other.side ~= u.side then
                ctx.applyStatus(other, "status_burn", { applier = u })
            end
        end
        ctx.log("action", string.format("%s boils over.", (u.char and u.char.name) or "It"), u)
    end,
}
