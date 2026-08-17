-- ANSWERED ONCE: Pride's rule, one rank down, and the Marginalia's opening state.
--
-- Sublimitas's Codex Unanswered deflects a single-target spell aimed at her ENTIRELY, for mana, on a
-- cooldown (data/traits/trait_counter_magic.lua) -- so a caster-heavy party finds its whole plan
-- refused, repeatedly, and has to work out why mid-fight.
--
-- This deflects the FIRST one and then never again. Which is enough to teach the lesson -- your caster
-- will be answered here -- without spending the rest of the fight teaching it. Then the stair goes down
-- to a body that does it every time it can pay.
--
-- Implemented with the same `countersSpell` flag the parent uses, so it runs through the identical seam
-- in combat rather than through a second, parallel one. What makes it lesser is the enormous cooldown:
-- longer than any fight, so the reflex is spent the moment it fires.
return {
    name = "Answered Once",
    description = "The first spell aimed at it is unravelled entirely, and no others.",
    cooldown = 9999, -- spent on firing: longer than any fight, which is what "once" means here
    cost = { stat = "mana", amount = 8 },
    countersSpell = true,
}
