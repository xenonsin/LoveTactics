-- SHED SKIN: the naga apothecary's race item (data/items/utility/utility_shed_skin.lua, "The Rift's
-- Adventurers", slice D). Once a fight, the first wound that leaves the bearer below half its health sheds
-- every status on it -- boon and bane alike, which is what a skin is -- and heals a fifth of its health.
--
-- Latched on the trait's own `stacks` (0 -> 1), like Second Wind. NOT A REACTION: a stunned naga still sheds,
-- and the Stun goes with the skin.
local SHARE = 0.2

return {
    name = "Shed Skin",
    description = "Once a fight, when you fall below half health, shed every status on you and heal a fifth of your health.",
    notAReaction = true,
    onDamaged = function(ctx)
        local u, t = ctx.unit, ctx.trait
        if not (u and u.alive) or (t.stacks or 0) > 0 then return end
        local Combat = require("models.combat")
        local hp = u.char and u.char.stats and u.char.stats.health
        local max = Combat.unreservedMax(u.char, "health")
        if not (hp and max > 0 and (hp.current or 0) * 2 < max) then return end
        t.stacks = 1
        local ids = {}
        for _, s in ipairs(u.statuses or {}) do ids[#ids + 1] = s.id end
        for _, id in ipairs(ids) do ctx.clearStatus(u, id) end
        ctx.log("action", string.format("%s sheds its skin.", (u.char and u.char.name) or "The naga"), u)
        ctx.heal(u, math.floor(max * SHARE))
    end,
}
