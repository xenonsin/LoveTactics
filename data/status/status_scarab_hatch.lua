-- HATCHING: the clock on a scarab egg (character_scarab_egg), laid in a coin heap by the Brood Queen.
-- Two turns, read off the badge's hourglass; when it runs out the egg splits into two Gilded Scarabs
-- (Scarab.hatch). Breaking the egg first is the answer -- it has little health and no way to move.
--
-- Hatches only on a NATURAL expiry: Status fires onExpire on every removal path, and an egg that was
-- broken took this status with it.
return {
    name = "Hatching",
    abbr = "Hatch",
    description = "Hatches into two Gilded Scarabs when the time runs out.",
    color = { 0.76, 0.62, 0.30 },
    duration = 10, -- two turns at Status.TICKS_PER_TURN
    onExpire = function(ctx)
        local egg = ctx.unit
        if not (ctx.combat and egg and egg.alive) or (ctx.status.remaining or 0) > 0 then return end
        local Combat = require("models.combat")
        local x, y, side = egg.x, egg.y, egg.side
        local level = egg.char and egg.char.level
        egg.hatched = true
        Combat.fell(ctx.combat, egg)
        require("models.scarab").hatch(ctx.combat, x, y, side, 2, level)
    end,
}
