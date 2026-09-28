-- THE GATE PAIR: the Nio's rule (data/encounters/encounter_wrath_the_nio.lua). When one of the pair falls, the
-- other takes every point of chi the fallen was holding (Asura.grant, which also lays Bursting on a pool that
-- fills). The kill order is the puzzle: the Open Mouth spends what it inherits, the Closed Mouth only fills.
return {
    name = "The Gate Pair",
    description = "When your twin falls, take all of its chi.",
    nio = true, -- the flag the twin is found by
    notAReaction = true,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen ~= u and fallen.side == u.side) then return end
        if not require("models.trait").flag(fallen, "nio") then return end
        local Asura = require("models.asura")
        local chi = Asura.chi(fallen)
        if chi <= 0 then return end
        local got = Asura.grant(ctx.combat, u, chi)
        if got > 0 then
            ctx.log("action", string.format("%s takes its twin's heat: +%d chi.",
                (u.char and u.char.name) or "It", got), u)
        end
    end,
}
