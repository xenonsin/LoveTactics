-- THE STILL HUNT: patience that pays. The count lives on status_still_hunt (laid here at the bell);
-- this reads it into the bearer's next blow as a FLAT bonus -- damageBonusVs only returns flat numbers --
-- of a quarter of the bearer's Damage per stack, so three turns of waiting add three quarters.
--
-- Carried by the Larder Mother (utility_the_still_hunt_beast) and by the player's drop off her
-- (utility_the_still_hunt): movement 3 and a web that brings prey to her mean she spends most of a
-- fight sitting still, and the archer who holds a post is paid the same way.
local SHARE = 0.25

return {
    name = "The Still Hunt",
    description = "Each turn ended without moving adds a stack, up to 3. Your next blow consumes them.",
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_still_hunt", { magnitude = 0 })
    end,
    damageBonusVs = function(ctx)
        local Status = require("models.status")
        local held = Status.get(ctx.unit, "status_still_hunt")
        local n = held and held.magnitude or 0
        if n <= 0 then return 0 end
        local Combat = require("models.combat")
        local damage = Combat.flatStat(ctx.unit, "damage") or 0
        return n * math.max(1, math.floor(damage * SHARE + 0.5))
    end,
}
