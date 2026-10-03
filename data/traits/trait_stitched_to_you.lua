-- STITCHED TO YOU: the Patchwork's rule, on its organ (data/items/utility/utility_stitched_to_you.lua). Reviewed
-- 2026-10-01..03 ("Envy's Bestiary", round 1).
--
-- Whoever last struck it is Conjoined to it -- the existing status, the mage's binding -- so half of every wound
-- the Patchwork takes reaches that body (Combat.echoWound). The stitch moves to each new attacker
-- (models/envy_oneoffs.lua's restitch). Moved once the blow has landed, so the wound that moves it is felt by the
-- body that held it until then: at that moment, that was whoever last struck it.
--
-- `notAReaction`: a stunned Patchwork is no less sewn to you.
return {
    name = "Stitched to You",
    description = "Whoever last struck it is Conjoined to it. The stitch moves to each new attacker.",
    notAReaction = true,
    onDamaged = function(ctx)
        local u, foe = ctx.unit, ctx.attacker
        if u and u.alive and foe then require("models.envy_oneoffs").restitch(ctx.combat, u, foe) end
    end,
}
