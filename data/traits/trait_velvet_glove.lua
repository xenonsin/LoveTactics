-- THE VELVET GLOVE's rule (data/items/utility/utility_velvet_glove.lua): the velvet slime's Strip turned
-- outward, once. The bearer's first melee weapon hit each battle takes the target's armour off for the
-- rest of the fight. Nobody wears it -- it is simply off (Combat.strip's `discard`) -- and a body is
-- rebuilt for every fight, so nothing is taken home either.
return {
    name = "Velvet Glove",
    description = "Your first melee weapon hit each battle strips the target's armour off for the fight.",
    onCast = function(ctx)
        if ctx.trait.stacks > 0 or (ctx.damageDealt or 0) <= 0 then return end
        local item = ctx.item
        if not (item and item.type == "weapon") then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not (target and target.alive) or target.side == ctx.unit.side then return end
        if ctx.gap(target) > 1 then return end
        local taken = require("models.combat").strip(ctx.combat, ctx.unit, target, { only = "armor", discard = true })
        if #taken > 0 then ctx.trait.stacks = 1 end
    end,
}
