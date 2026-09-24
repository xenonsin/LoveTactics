-- BOTTOMLESS GUT: the Sated's own loop, worn. A foe that dies beside you is eaten and you take a meal
-- (status_full): +2 Damage, +2 Defense, -1 Movement apiece, up to three. Where the Distended Girth starts
-- you full and empties, this starts you empty and fills. Approved on review (2026-09-23), with the note
-- "I like all of it".
--
-- A meal here carries no Speed, unlike the Sated's own: a charm that cost a company its turn order for a
-- kill would price the thing it is meant to reward.
local Status = require("models.status")

return {
    name = "Bottomless Gut",
    description = "A foe that dies beside you is eaten: gain a meal (+2 damage, +2 defense, -1 movement), up to 3.",
    meal = { damage = 2, defense = 2, movement = -1 },
    onAnyDeath = function(ctx)
        local fallen, u = ctx.fallen, ctx.unit
        if not (fallen and u and u.alive) or fallen.side == u.side then return end
        if ctx.gap(fallen) > 1 then return end
        Status.apply(ctx.combat, u, "status_full", { magnitude = 1, statBonus = ctx.def.meal })
        ctx.log("action", string.format("%s eats %s.", (u.char and u.char.name) or "It",
            (fallen.char and fallen.char.name) or "the body"), u)
    end,
}
