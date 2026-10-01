-- THE BURNING ONE: the Seraph's rule, worn on its wing and carried out on the drop (reviewed 2026-09-30, "Pride's
-- Bestiary"). Any foe that STARTS its turn beside the bearer Burns (status_burn).
--
-- An AURA ON THE TURN'S OPENING, and that is what separates it from the fires already in the game. Thorns and the
-- Backdraught answer a blow -- they cost the one who strikes. The Burning Halo burns whoever walks INTO its ring.
-- This one costs the one who STAYS: walk up, strike and walk off and it never touches you; end your turn in its
-- reach and the next one opens in flames. So the counterplay is the hit-and-run the rest of the spire punishes,
-- and the Seraph is the body that teaches it. Heard through Trait.onAnyTurnStart, past the actor's own status sweep.
--
-- Laid with the bearer as the applier, so the burn's opener is the Seraph.
return {
    name = "The Burning One",
    description = "Foes that start their turn next to you Burn.",
    notAReaction = true,
    onAnyTurnStart = function(ctx)
        local u, actor = ctx.unit, ctx.actor
        if not (u and u.alive and actor and actor.alive and actor.side ~= u.side) then return end
        local Combat = require("models.combat")
        if Combat.isOffTile(actor) or Combat.unitGap(u, actor) ~= 1 then return end
        ctx.applyStatus(actor, "status_burn", { applier = u })
    end,
}
