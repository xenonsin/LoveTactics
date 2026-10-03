-- STONE HEART: the Homunculus's drop, an Apothecary's (data/items/utility/utility_stone_heart.lua; "Envy's
-- Bestiary", 2026-10-03, slice C). Its red stone turned to the bearer's use: each kill stores a Red Stone, to 3,
-- and a blow that would kill the bearer consumes one and leaves it at 1 health (Trait.trySurvive, `redStone`).
--
-- Built on the stone count rather than a second life, on the author's note "the drop already exists": a once-a-
-- battle rising is Second Wind, and this one is earned in the fight it is spent in.
return {
    name = "Stone Heart",
    description = "Each kill stores a Red Stone, to 3. A blow that would kill you consumes one and leaves you at 1.",
    redStone = true,
    onAnyDeath = function(ctx)
        local fallen, u = ctx.fallen, ctx.unit
        if not (fallen and u and u.alive) or fallen.side == u.side or fallen.lastAttacker ~= u then return end
        ctx.applyStatus(u, "status_red_stone", { magnitude = 1 })
    end,
}
