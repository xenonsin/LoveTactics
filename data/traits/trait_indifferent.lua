-- INDIFFERENT: the troll's racial rule, carried on its grant (data/items/utility/utility_troll_blood.lua). Reviewed
-- 2026-10-04 ("Sloth's Bestiary").
--
-- Three hooks, one rule:
--   * the fight opens with status_indifferent on, which is the badge and the never-dodge (avoid -100);
--   * any wound tagged fire or acid marks the troll SCORCHED until its next turn;
--   * at the top of its own turn it regrows a fifth of its health unless it is scorched, and the mark clears.
--
-- The mark lives on the unit, not on a status, because it is bookkeeping between two of the troll's own hooks and
-- would only be a second badge saying the same thing. `notAReaction`: regrowth is not a reflex, so a troll that is
-- Stunned or asleep still knows it was burned (Trait.onDamaged keeps only those under hard control).
local REGROW = 0.2 -- a fifth of its health, each turn it was not burned

local function burned(tags)
    for _, t in ipairs(tags or {}) do
        if t == "fire" or t == "acid" then return true end
    end
    return false
end

return {
    name = "Indifferent",
    description = "Never dodge. Regrow a fifth of your health each turn, unless fire or acid reached you since your last.",
    notAReaction = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if u and u.alive then ctx.applyStatus(u, "status_indifferent", { applier = u }) end
    end,
    onDamaged = function(ctx)
        if (ctx.amount or 0) > 0 and burned(ctx.tags) then ctx.unit.trollScorched = true end
    end,
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        if u.trollScorched then
            u.trollScorched = nil
            return
        end
        local Combat = require("models.combat")
        local max = Combat.unreservedMax(u.char, "health")
        local missing = max - (u.char.stats.health.current or 0)
        if missing > 0 then ctx.heal(u, math.max(1, math.floor(max * REGROW))) end
    end,
}
