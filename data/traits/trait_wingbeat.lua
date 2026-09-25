-- WINGBEAT: Avaritia's Wing Buffet, for the company (the Wingbeat Mantle, data/items/utility/
-- utility_wingbeat_mantle.lua). Reviewed 2026-09-25: at the start of the wearer's turn every foe beside it
-- is thrown back 1 -- a backliner who keeps getting dived. Laid as the same status she wears, a throw of 1
-- where hers is 2.
return {
    name = "Wingbeat",
    description = "At the start of your turn, every foe beside you is knocked back 1.",
    onCombatStart = function(ctx)
        if not (ctx.combat and ctx.unit) then return end
        require("models.status").apply(ctx.combat, ctx.unit, "status_wing_buffet", { magnitude = 1 })
    end,
}
