-- THE WITCH'S TAINT: the oni's second racial rule, carried on its grant (utility_oni_blood). Reviewed 2026-09-26
-- ("The Oni of Wrath"), after Re:Zero's premise that an oni can smell the witch on a body.
--
-- A foe carrying a hex -- a cursed piece in its grid (Curse.isCursed) or the Cursed status on its body -- is
-- struck for 25% more by every oni, and the AI sends an oni that can reach one at it before anything else
-- (AI.preempt reads `witchsTaint`). So a hexed body is BAIT, and moving a hex (the Shaman's shelf), ending one
-- (the Cathedral, the Exorcist) or warding one off becomes an answer to a clan.
--
-- The bonus is read at blow time and is pure, since the forecast asks it on every hover.
local SHARE = 0.25

local Taint = {}

-- Does `u` carry the witch's taint?
function Taint.carries(u)
    if not u then return false end
    local Status = require("models.status")
    if Status.has(u, "status_cursed") then return true end
    local Curse = require("models.curse")
    for _, item in pairs((u.char and u.char.inventory) or {}) do
        if item and Curse.isCursed(item) then return true end
    end
    return false
end

return {
    name = "The Witch's Taint",
    description = "Strike a foe that carries a hex for 25% more, and hunt it first.",
    witchsTaint = true,
    notAReaction = true,
    share = SHARE,
    carries = Taint.carries,
    damageBonusVs = function(ctx)
        if not (ctx.unit and ctx.target and ctx.target.side ~= ctx.unit.side) then return 0 end
        if not Taint.carries(ctx.target) then return 0 end
        local Combat = require("models.combat")
        local power = Combat.flatStat(ctx.unit, "damage")
        return math.max(1, math.floor(power * ctx.param("share", SHARE) + 0.5))
    end,
}
