-- FREEZE SOLID: the Rime Slime's rule (the creature identity pass, 2026-11-19). It replaced Torpor, a turn-order
-- shove that only showed up as the timeline quietly reshuffling.
--
-- When it dies it sets hard where it lay: its own tile and every empty tile beside it (orthogonally) become Ice
-- Walls -- the Snow Queen's pane (data/walls/ice_wall.lua): blocks a step, not a look, fades in five turns, and
-- fire melts it whole. So WHERE you kill it is the question. Killed in the corridor the company needs, it seals
-- the corridor; killed beside the healer, it walls her in. A body standing beside it is never walled over
-- (Wall.place refuses an occupied tile), only boxed.
--
-- onDeath, since a killing blow never reaches onDamaged (trait_death_throes_frost argues the same).
local SIDES = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

return {
    name = "Freeze Solid",
    grade = 0.5, -- weighed beside the rule (Grade.traitValue reads it): a death that walls off its own tile, fire undoes it
    description = "When it dies, its tile and the empty tiles beside it become Ice Walls. Fire melts them.",
    notAReaction = true,
    onDeath = function(ctx)
        local u = ctx.unit
        if not u then return end
        local Wall = require("models.wall")
        ctx.burst(u.x, u.y, { "ice" })
        local raised = 0
        for _, d in ipairs(SIDES) do
            if Wall.place(ctx.combat, u.x + d[1], u.y + d[2], "ice_wall", { side = u.side }) then
                raised = raised + 1
            end
        end
        if raised > 0 then
            ctx.log("action", string.format("%s freezes solid.", (u.char and u.char.name) or "It"), u)
        end
    end,
}
