-- ALREADY KNOWN: Sublimitas's rule, which replaced her mana-priced Counter Magic (reviewed 2026-10-01). She made
-- her pact for perfect comprehension, so she has only to SEE a working to have it.
--
--   SEEN      every spell cast within her sight, by anyone, either side, becomes Known (status_already_known)
--   KNOWN     a Known spell aimed at her is unravelled before it begins: no damage, no rider, the caster still
--             paid (Trait.tryUnravelKnown, asked from resolveCast beside the cast ward)
--   UNSEEN    a spell she has not seen lands in full -- she learns it on the far side of the cast -- and is
--             Known from then on
--   STEEL     a basic weapon attack is never learned, however it is tagged (Trait.isSpell)
--
-- Single target, like every ward that answers a cast: an area spell aims at nobody, so a Rain still lands on
-- her. THE COUNTERPLAY is the sin read as tactics: show her each spell once, where it counts, and never twice.
--
-- It rides on her organ (utility_already_known) and on the Codex Unanswered, the mage trophy she drops.
return {
    name = "Already Known",
    description = "Spells cast in your sight become Known. A Known spell aimed at you is unravelled.",
    unravelsKnown = true, -- read by Trait.tryUnravelKnown
    onAnyCast = function(ctx)
        require("models.trait").learnSpell(ctx.combat, ctx.unit, ctx.caster, ctx.castItem)
    end,
}
