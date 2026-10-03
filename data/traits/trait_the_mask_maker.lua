-- THE MASK-MAKER'S HAND (utility_mask_makers_hand): the Mask-Maker's rule. At the opening bell it deals its own hand
-- -- a shield, a healer, an archer and a caster (Masks.dealCompany) -- and hands it out; at the top of each of its
-- turns it hands it out again, so a body that has walked out of reach reads for itself once more; at its death
-- every body it masked goes back to Reshape (models/masks.lua).
--
-- A Faceless whose own opener has not fired yet still counts (it carries the race's trait), so the squad is masked
-- from the first turn whatever order the board seated them in.
return {
    name = "The Mask-Maker's Hand",
    description = "At the start of your turn, each Faceless ally within 3 wears a face from your hand, all different.",
    notAReaction = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        local Masks = require("models.masks")
        Masks.dealCompany(ctx.combat, u)
        Masks.handOut(ctx.combat, u)
    end,
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        require("models.masks").handOut(ctx.combat, u)
    end,
    onDeath = function(ctx)
        if not ctx.combat then return end
        require("models.masks").release(ctx.combat, ctx.unit)
    end,
}
