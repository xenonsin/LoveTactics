-- PROVEN: the orc's racial rule (data/items/utility/utility_proven.lua), and Orc Scars' in a player's hand
-- (data/items/utility/utility_orc_scars.lua). Approved as pitched (2026-09-26, "The Orcs of Wrath").
--
-- A killing blow -- the fallen's lastAttacker, any weapon -- makes the bearer Proven: +2 Damage and +2 Defense
-- for the rest of the fight, three times at most (status_proven). A goblin punishes whoever hits its kin; an orc
-- is made stronger by every body the company lets fall.
return {
    name = "Proven",
    description = "A kill makes you Proven, up to 3 times.",
    notAReaction = true,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen.lastAttacker == u and fallen.side ~= u.side) then return end
        ctx.applyStatus(u, "status_proven")
    end,
}
