-- Bond: Stand Firm -- the other half of an A-rank bond with the avatar (models/bond.lua). When either
-- partner falls, the one still standing surges: Haste and Aegis for two turns.
--
-- Both ends carry it: an A-rank partner (for the avatar's fall) and the avatar itself whenever it holds an
-- A-rank bond with somebody on the board (for that partner's). Handed out per fight by Bond.traitsFor --
-- never authored on a blueprint.
local SURGE_TICKS = 10 -- two turns (Status.TICKS_PER_TURN = 5)

return {
    name = "Stand Firm",
    description = "When your A-rank bond partner falls, gain Haste and Aegis for 2 turns.",
    onAnyDeath = function(ctx)
        local me, fallen = ctx.unit, ctx.fallen
        if not (fallen and fallen.char and me.char) or fallen.side ~= me.side then return end
        local Combat = require("models.combat")
        local AVATAR = "character_avatar"
        local partner
        if me.char.id == AVATAR then partner = fallen
        elseif fallen.char.id == AVATAR then partner = me
        else return end
        if Combat.bondRank(ctx.combat, partner) ~= "A" then return end
        ctx.applyStatus(me, "status_hasted", { duration = SURGE_TICKS })
        ctx.applyStatus(me, "status_aegis", { duration = SURGE_TICKS })
        ctx.log("action", string.format("%s stands firm!", me.char.name or "Unit"))
    end,
}
