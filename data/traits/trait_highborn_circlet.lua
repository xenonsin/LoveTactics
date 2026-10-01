-- THE HIGHBORN CIRCLET: the Elf Highborn's drop, worn (data/items/utility/utility_highborn_circlet.lua). Approved
-- 2026-09-30 ("Pride's Bestiary"). Will Not Admit the Wound in a company's hands: a full round without being struck
-- heals 15% and makes the wearer Composed (+2 Damage until struck, status_composed).
--
-- The round is measured as the Highborn's is (data/traits/trait_will_not_admit.lua): end of own turn to end of
-- own turn, with no blow drawing blood between them, the first turn's end only starting the count.
local SHARE = 0.15

return {
    name = "Highborn Circlet",
    description = "A full round without being struck heals 15% and makes you Composed.",
    notAReaction = true,
    onDamaged = function(ctx)
        if (ctx.amount or 0) > 0 then ctx.trait.struck = true end
    end,
    onTurnEnd = function(ctx)
        local t, u = ctx.trait, ctx.unit
        if t.counting and not t.struck and u and u.alive then
            local max = require("models.combat").unreservedMax(u.char, "health")
            ctx.heal(u, math.max(1, math.floor(max * SHARE)))
            ctx.applyStatus(u, "status_composed", { applier = u })
        end
        t.counting, t.struck = true, false
    end,
}
