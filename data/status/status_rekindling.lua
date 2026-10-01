-- REKINDLING: the clock on a Phoenix's Ember (data/characters/character_phoenix_ember.lua; "Pride's Bestiary",
-- 2026-09-30). Three turns on the badge's hourglass; when it runs out the Ember catches and the Phoenix stands
-- on its tile again, whole (PrideElites.rise). Breaking the Ember first is the answer, and the only end there is.
--
-- Rises only on a NATURAL expiry, as the scarab egg hatches: Status fires onExpire on every removal path, and
-- an Ember that was broken took this status with it.
return {
    name = "Rekindling",
    abbr = "Kndl",
    description = "Rises again as the Phoenix, at full health, when the time runs out.",
    color = { 0.900, 0.420, 0.140 }, -- badge tint (ember orange)
    duration = 15, -- three turns at Status.TICKS_PER_TURN
    onExpire = function(ctx)
        local ember = ctx.unit
        if not (ctx.combat and ember and ember.alive) or (ctx.status.remaining or 0) > 0 then return end
        require("models.pride_elites").rise(ctx.combat, ember)
    end,
}
