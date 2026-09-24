-- MATED FOR LIFE: the Eyrie holds a pair, and when one falls the other eats it and fights on Gorged for the
-- rest of the battle. From the legend that griffins mate once and never again; the grief here is hunger,
-- which is what makes it Gluttony's. Approved on review (2026-09-23).
--
-- It is a real choice for the company: split the damage so the two fall close together, or finish one
-- and face the worse one. Only a body of the bearer's own kind counts -- a hawk falling is not a mate.
local Status = require("models.status")

return {
    name = "Mated for Life",
    description = "When its mate falls, it eats it and is Gorged.",
    onAnyDeath = function(ctx)
        local fallen, u = ctx.fallen, ctx.unit
        if not (fallen and u and u.alive) or fallen == u or fallen.side ~= u.side then return end
        if not (fallen.char and u.char and fallen.char.id == u.char.id) then return end
        require("models.combat").devour(ctx.combat, u, fallen)
        Status.apply(ctx.combat, u, "status_gorged", { duration = 999 })
        ctx.log("action", string.format("%s eats its mate, and turns on you.",
            (u.char and u.char.name) or "It"), u)
    end,
}
