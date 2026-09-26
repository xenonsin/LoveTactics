-- MOB COURAGE: the goblin's second racial rule, carried on its grant (data/items/utility/utility_blood_feud.lua).
-- Approved in round 1 (2026-09-26) with Keno's note: "alpha or elite units are exceptions."
--
-- A goblin with no other goblin within two tiles Cowers (the existing status: it moves fewer tiles). It is
-- checked as each turn ends and when the fight opens, and the Cowering it lays lasts about a turn, so a
-- goblin that finds its kin again is brave again by its next move. The company's answer is to split them.
--
-- THE EXCEPTIONS ARE THE ELITE BAND (tier 3 and up, Balance.HEALTH_BANDS): the Hobgoblin, the Redcap, the
-- Bugbear and the King are not afraid of being alone, and a goblin never cowers in an arena with no other
-- goblin left to be afraid for -- only a body that HAS kin somewhere on the board can miss them.
local RADIUS = 2
local ELITE_TIER = 3
local TURN = 5 -- Status.TICKS_PER_TURN

local function check(ctx)
    local u, combat = ctx.unit, ctx.combat
    if not (u and u.alive and combat) then return end
    if (u.char and u.char.tier or 0) >= ELITE_TIER then return end
    local Combat = require("models.combat")
    local Trait = require("models.trait")
    local near, any = false, false
    for _, other in ipairs(combat.units or {}) do
        if other ~= u and other.alive and other.side == u.side and Trait.flag(other, "bloodFeud") then
            any = true
            if Combat.unitGap(u, other) <= RADIUS then near = true break end
        end
    end
    if any and not near then
        ctx.applyStatus(u, "status_cowering", { duration = TURN + 1 })
    end
end

return {
    name = "Mob Courage",
    description = "With no other goblin within 2, Cower. Alphas and elites never do.",
    notAReaction = true,
    onCombatStart = check,
    onAnyTurnEnd = check,
}
