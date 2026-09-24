-- MIMICRY: half of Envy's slime rule. The first foe to aim anything at it, it BECOMES -- their fighting
-- numbers and a copy of their weapon, on its own health and its own bound body (Combat.mimic). Heard on
-- onAnyCast, the moment a cast has resolved, so a blow it was immune to still counts as being looked at.
return {
    name = "Mimicry",
    description = "It becomes a copy of the first foe to target it, keeping its own health and body.",
    onAnyCast = function(ctx)
        local u, caster = ctx.unit, ctx.caster
        if not (u and u.alive and caster and caster.char) or caster.side == u.side then return end
        if ctx.unitAt(ctx.tx, ctx.ty) ~= u then return end
        require("models.combat").mimic(ctx.combat, u, caster)
    end,
}
