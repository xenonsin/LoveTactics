-- SERPENT'S STRIKE: the bite a coiled serpent head throws for the body it grows from. Carried by the ITEM
-- that grows the head (utility_chimera_serpent on the Chimera, utility_serpent_head on a Beastmaster),
-- because the blow it answers lands on the BODY -- a head stands on no tile and is never the one struck.
--
-- It answers only while the body is Poised (status_tail_poised, laid by the serpent's own turn), only a
-- melee blow, and only while the serpent that grew from this item is still alive: a broken tail bites
-- nobody, whatever coil it left behind. The bite is flat (a reflex, not a swing -- the thorn's shape) and
-- Poisons; it spends the coil and feeds the serpent, clearing its hunger (status_starving).
--
-- A reflex like every counter, so it is suppressed on a body too rattled to answer: stun the body and the
-- tail goes quiet with it. The head's own turn is not -- it keeps coiling.
local function serpentOf(ctx)
    local Combat = require("models.combat")
    for _, head in ipairs(Combat.headsOf(ctx.combat, ctx.unit)) do
        if head.headItem == ctx.item then return head end
    end
end

return {
    name = "Serpent's Strike",
    description = "While the tail is poised, the first foe to strike this body in melee is bitten and poisoned.",
    counter = { reach = "melee", requiresStatus = "status_tail_poised", applies = "status_poison" },
    bite = 6, -- the flat blow, before mitigation; the Poison is the point
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        local serpent = serpentOf(ctx)
        if not serpent then return end
        if not ctx.pay() then return end
        local attacker = ctx.attacker
        ctx.clearStatus(ctx.unit, "status_tail_poised")
        ctx.log("action", string.format("%s strikes back at %s!",
            (serpent.char and serpent.char.name) or "The serpent",
            (attacker.char and attacker.char.name) or "the attacker"), { serpent, attacker })
        ctx.damage(attacker, ctx.param("bite", 6), { "physical", "pierce", "bite" })
        if attacker.alive then ctx.applyStatus(attacker, "status_poison") end
        ctx.clearStatus(serpent, "status_starving") -- it has eaten
    end,
}
