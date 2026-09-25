-- GULLET: the eater's half of status_swallowed -- the three ways a body comes back out that are about the
-- EATER rather than the clock. Carried by whatever does the swallowing (ability_swallow on the Giant Toad,
-- ability_the_gullet on a person), so the rule travels with the verb.
--
--   * a HEAVY BLOW -- one hit of a quarter of its health or more -- makes it throw up. The counterplay the
--     review named: your heaviest hitter's job is to empty the toad before the digestion adds up.
--   * a STUN does the same. Checked as the status lands, so a stun that does no damage still counts.
--   * its DEATH lets the body out, on the tile nearest where it fell.
--
-- `notAReaction`: a stunned toad is exactly the toad that must still spit, and Trait.onDamaged skips a
-- hard-controlled body's reactions unless the trait says it is not one.
local Status = require("models.status")
local Combat = setmetatable({}, { __index = function(_, k) return require("models.combat")[k] end })

local function letOut(combat, eater)
    local body = Combat.swallowedIn(combat, eater)
    if body then Status.remove(combat, body, "status_swallowed") end
end

return {
    name = "Gullet",
    description = "A blow of a quarter of its health, a stun, or its death makes it spit out what it swallowed.",
    notAReaction = true,
    share = 0.25, -- of maximum health, in one blow
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.swallowing) then return end
        local max = u.char.stats.health.max or 0
        if (ctx.amount or 0) >= max * ctx.param("share", 0.25) or Status.has(u, "status_stun") then
            letOut(ctx.combat, u)
        end
    end,
    onStatusApplied = function(ctx)
        if ctx.role ~= "recipient" or not (ctx.unit and ctx.unit.swallowing) then return end
        if ctx.status and ctx.status.id == "status_stun" then letOut(ctx.combat, ctx.unit) end
    end,
    onDeath = function(ctx)
        if ctx.unit and ctx.unit.swallowing then letOut(ctx.combat, ctx.unit) end
    end,
}
