-- THE CHAIN: the War Ogre's rule (data/items/utility/utility_the_chain.lua). Approved as pitched (2026-09-26, "The
-- Orcs of Wrath"): Wrath's "no control", made a choice the company holds.
--
-- While its Handler lives, the ogre stays within 3 tiles of it -- a turn that ends farther off, the chain drags
-- it back beside the Handler -- and goes for whatever the Handler last struck (`pointedAt`, set by
-- trait_holding_the_chain and read in AI.preempt). Kill the Handler and it is Unchained: +50% Damage, and each
-- turn it attacks the nearest body, orc or not (models/rampage.lua). Unchained in the middle of the orc line it
-- clears the line for you; next to your healer it does not.
local LEASH = 3

local function handlerOf(combat, u)
    local Trait = require("models.trait")
    for _, other in ipairs(combat.units or {}) do
        if other.alive and other ~= u and other.side == u.side and Trait.flag(other, "holdsTheChain") then
            return other
        end
    end
end

return {
    name = "The Chain",
    description = "Stays within 3 of its Handler and attacks what the Handler strikes. With the Handler dead, it is Unchained.",
    chained = true,
    notAReaction = true,
    onTurnEnd = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and u.alive and combat) then return end
        local Status = require("models.status")
        if Status.has(u, "status_unchained") then return end
        local handler = handlerOf(combat, u)
        if not handler then return end
        local Combat = require("models.combat")
        if Combat.unitGap(u, handler) <= LEASH then return end
        local fp = u.char and u.char.footprint or {}
        local x, y = Combat.openBlockNear(combat, handler.x, handler.y, fp.w or 1, fp.h or 1, { ignore = u, radius = 3 })
        if x then
            Combat.teleportUnit(combat, u, x, y, { silent = true, glide = true })
            ctx.log("action", string.format("The chain drags %s back.", (u.char and u.char.name) or "it"), u)
        end
    end,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen.side == u.side) then return end
        local Trait = require("models.trait")
        if not Trait.flag(fallen, "holdsTheChain") then return end
        local Status = require("models.status")
        if Status.has(u, "status_unchained") then return end
        local Combat = require("models.combat")
        local extra = math.max(1, math.floor(Combat.flatStat(u, "damage") * 0.5 + 0.5))
        ctx.applyStatus(u, "status_unchained", { statBonus = { damage = extra } })
        u.pointedAt = nil
        ctx.log("action", string.format("%s is Unchained.", (u.char and u.char.name) or "It"), u)
    end,
}
