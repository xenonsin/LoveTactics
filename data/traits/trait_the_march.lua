-- THE MARCH: the orc War-Drummer's rule (data/items/utility/utility_the_march.lua). Approved as pitched
-- (2026-09-26, "The Orcs of Wrath").
--
-- Every other turn the drum sounds: at the end of the Drummer's turn, every orc on its side takes one free step
-- toward its nearest foe (models/march.lua). The turn before, it wears Drumbeat, so the company can read the
-- beat: step back on a drum turn and the step lands them short; set a trap where they will step; or kill the
-- Drummer.
return {
    name = "The March",
    description = "Every other turn the drum sounds, and every orc steps toward its nearest foe.",
    notAReaction = true,
    onTurnEnd = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and u.alive and combat) then return end
        local Status = require("models.status")
        if not Status.has(u, "status_drumbeat") then
            ctx.applyStatus(u, "status_drumbeat")
            return
        end
        ctx.clearStatus(u, "status_drumbeat")
        local Combat = require("models.combat")
        local line = {}
        for _, other in ipairs(combat.units or {}) do
            if other.alive and other.side == u.side and other.char and other.char.race == "orc" then
                line[#line + 1] = other
            end
        end
        local n = require("models.march").stepAll(combat, line, function(body, x, y)
            Combat.teleportUnit(combat, body, x, y, { silent = true, glide = true })
        end)
        ctx.log("action", string.format("The drum sounds. %d step forward.", n), u)
    end,
}
