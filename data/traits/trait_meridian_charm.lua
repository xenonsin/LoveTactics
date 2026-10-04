-- MERIDIAN CHARM: the Noonday Demon's trophy, carried (utility_meridian_charm; "Sloth's Bestiary", 2026-10-04,
-- slice C). Foes within 3 that deal no damage on their turn lose 3 damage, stacking, until they deal some. The
-- Demon's own Listless at a shorter reach, and without the shame: the charm only weighs (models/sloth_bog.lua).
return {
    name = "Meridian Charm",
    description = "Foes within 3 that deal no damage on their turn gain Listless.",
    reach = 3,
    notAReaction = true,
    onAnyTurnEnd = function(ctx)
        require("models.sloth_bog").idleTurn(ctx.combat, ctx.unit, ctx.actor, ctx.param("reach", 3), false)
    end,
}
