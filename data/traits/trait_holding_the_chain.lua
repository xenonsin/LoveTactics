-- HOLDING THE CHAIN: the orc Beast-Handler's rule (data/items/utility/utility_holding_the_chain.lua). Whatever the
-- Handler strikes, its War Ogre goes for next (the ogre's `pointedAt`, read in AI.preempt). Its death is what
-- unchains the ogre (trait_the_chain).
return {
    name = "Holding the Chain",
    description = "Its War Ogre attacks whatever it strikes. If it falls, the ogre is Unchained.",
    holdsTheChain = true,
    notAReaction = true,
    onCast = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat and (ctx.damageDealt or 0) > 0 and ctx.tx) then return end
        local struck = require("models.combat").unitAt(combat, ctx.tx, ctx.ty)
        if not (struck and struck.alive and struck.side ~= u.side) then return end
        local Trait = require("models.trait")
        for _, other in ipairs(combat.units or {}) do
            if other.alive and other.side == u.side and Trait.flag(other, "chained") then other.pointedAt = struck end
        end
    end,
}
