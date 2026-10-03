-- MASK OF CHAMPIONS (data/items/utility/utility_mask_of_champions.lua): the Faceless Champion's hand worn small
-- (reviewed 2026-10-01..03, "Envy's Bestiary", round 2). Three champions' reflexes carried, one worn at a time,
-- and the badge says which (models/stolen_faces.lua's REFLEXES):
--
--   UNTOUCHABLE         the Bladedancer's: every attack that rolls to hit is evaded until the first wound
--                       (status_untouchable). Marred once, the mask does not put it on again this fight.
--   THE CHALLENGE       the Pit-Fighter's: half damage from every foe but the challenger, the foe with the most
--                       health, named again each turn the bearer ends (status_the_challenge's `exempt`).
--   ANSWERS EVERY BLOW  the Griffin's: bite back at every melee blow for half your damage, free and
--                       unescalating (trait_answers_every_blow's own hook, gated on its badge).
--
-- It opens wearing Untouchable; the mask's own button swaps to the next, once a turn.
return {
    name = "Mask of Champions",
    description = "Carry three champions' reflexes and wear one at a time.",
    -- The Griffin's rule, gated on the badge, so the hover preview promises it only while it is worn.
    counter = { reach = "melee", requiresStatus = "status_answers_every_blow" },
    share = 0.5,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if u and u.alive and not require("models.stolen_faces").reflexWorn(u) then
            ctx.applyStatus(u, "status_untouchable", { applier = u })
        end
    end,
    onTurnEnd = function(ctx)
        if ctx.unit and ctx.unit.alive then require("models.stolen_faces").nameChallenger(ctx.combat, ctx.unit) end
    end,
    onDamaged = function(ctx)
        require("models.trait").defs.trait_answers_every_blow.onDamaged(ctx)
    end,
}
