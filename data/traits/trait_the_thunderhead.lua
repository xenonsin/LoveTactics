-- THE THUNDERHEAD: the storm's organ (models/storm.lua; "Fire, Lightning, and Dirty Thunder", 2026-09-27/28).
--
--   ITS FIRE CARRIES ITS LIGHTNING  `fireConducts`: while it stands, every fire conducts as water does
--                                   (Combat.tileHasTag), so Wildfire grows the storm's reach
--   ASHFALL                         at the end of its turn, ash on 3 tiles toward its nearest foe (hazard_ash)
--   THE TEAR                        below half -- or on a blow that would fell it (Trait.trySurvive) -- it tears
--                                   back into its Blaze and Arc, once (Storm.tear)
--   ERUPTION                        once, at a third: the tiles beside it turn to lava and every body standing in
--                                   fire is struck (Storm.erupt)
--
-- `notAReaction`: these are what the storm IS, read off its own bar, and a stun must not skip them.
local Storm = require("models.storm")

return {
    name = "The Thunderhead",
    description = "Fire conducts its lightning. Drops ash that blocks sight and inflicts Blind. Tears in two at half; erupts at a third.",
    fireConducts = true,
    notAReaction = true,
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        local hp = u.char.stats.health
        if u.stormParts and not u.stormTorn and hp.current < hp.max / 2 then
            Storm.tear(ctx.combat, u)
            return
        end
        if not u.stormErupted and hp.current <= hp.max / 3 then
            u.stormErupted = true
            Storm.erupt(ctx.combat, u, true)
        end
    end,
    onTurnEnd = function(ctx) Storm.ashfall(ctx.combat, ctx.unit) end,
    onDeath = function(ctx) Storm.fallen(ctx.combat, ctx.unit) end,
}
