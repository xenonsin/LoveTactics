-- MIRROR MASK's rule (data/items/utility/utility_mirror_mask.lua): each battle opens with a fragile copy
-- of the bearer standing beside them, and the Substitution flag makes the first blow meant for the bearer
-- land on it instead (Trait.trySubstitute trades their places).
return {
    name = "Mirror Mask",
    description = "Each battle opens with a fragile copy of you beside you; the first blow meant for you hits it instead.",
    substitutes = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        local x, y = ctx.openTileNear(u.x, u.y)
        if not x then return end
        require("models.summon").copy(ctx.combat, u, x, y, { decoy = true, fragile = true })
    end,
}
