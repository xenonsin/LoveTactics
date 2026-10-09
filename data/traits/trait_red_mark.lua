-- RED MARK: the oni assassin's race item (data/items/utility/utility_red_mark.lua, "The Rift's Adventurers",
-- slice D). One action that both BLINKS the bearer (any tile crossed without walking -- Shadow Strike's step
-- home, a Blink) and FELLS a foe sends it Horn Out (status_horn_out), as the horn's own triggers do: not with a
-- snapped horn, and not twice.
--
-- Measured off two running tallies the engine already keeps -- `tilesBlinked` and `kill` -- compared across one
-- cast: the counts are written down when the fight opens, when the bearer's turn opens and after every cast it
-- makes, and a cast that moved both answers. Order inside the cast does not matter, so strike-then-blink and
-- blink-then-strike are the same finish.
local Status = require("models.status")

local function note(ctx)
    local Combat = require("models.combat")
    ctx.trait.seenBlink = Combat.tallyCount(ctx.unit, "tilesBlinked")
    ctx.trait.seenKill = Combat.tallyCount(ctx.unit, "kill")
end

return {
    name = "Red Mark",
    description = "A blink to finish a foe sends you Horn Out.",
    onCombatStart = note,
    onTurnStart = note,
    onCast = function(ctx)
        local u, t = ctx.unit, ctx.trait
        local Combat = require("models.combat")
        local blinked = Combat.tallyCount(u, "tilesBlinked") > (t.seenBlink or 0)
        local killed = Combat.tallyCount(u, "kill") > (t.seenKill or 0)
        note(ctx)
        if not (blinked and killed and u.alive) then return end
        if Status.has(u, "status_horn_snapped") or Status.has(u, "status_horn_out")
            or Status.has(u, "status_full_horn_out") then
            return
        end
        ctx.applyStatus(u, "status_horn_out", { applier = u })
        ctx.log("action", string.format("%s's horn comes out.", (u.char and u.char.name) or "The oni"), u)
    end,
}
