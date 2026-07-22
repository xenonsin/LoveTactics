-- Sublimitas's rule, and Pride's in one hook: "answers every spell with your own" (docs/story.md, "The
-- Arcanum", which flags this as the wired-but-unwritten onCast answer). The Unequalled has only to glance
-- at a working to own it, so a spell aimed at her is a spell she has already mastered -- and it simply
-- does not land. Where Lust takes what you held back and Gluttony feeds on the long trade, Pride
-- answers the *visible*: whatever you cast at her, where she can see it, she has the measure of.
--
-- SHIPPED FIDELITY: this is a counter-magic reflex (countersSpell -- Trait.tryCounterMagic unravels a
-- single-target spell aimed at the bearer, for mana and a cooldown), the same engine face as
-- data/traits/trait_counter_magic.lua. The full rule the chapter describes -- she LEARNS the spell on
-- sight and casts it back, then in her demon phase fills the board with copies of herself -- is deferred
-- new work (the glance-and-recast mirror; ability_doppelganger already ships the self-copy for her second
-- form). Until then the shipped read is the honest half of it: the spell you stake the fight on is the
-- spell that does nothing to her, so the counterplay is the sin as tactics -- do not show her your hand.
--
-- Like every general's rule it travels with the relic lifted off her body
-- (data/items/utility/utility_codex_unanswered.lua): carry the Codex and your foes' spells unravel on
-- you, and you become the thing you killed. The one mage it can never answer is the one who never shows
-- it anything worth taking (Gyeom, data/traits/trait_ledger_diligence.lua): a suppressed cast is read at
-- its suppressed value, and there is nothing there to have the measure of.
return {
    name = "Perfect Recall",
    description = "A single-target spell aimed at her is answered and unravelled -- she already knows it.",
    magnitude = 6,  -- ticks before she can answer another spell; short, because she is the Unequalled
    cost = { stat = "mana", amount = 12 }, -- paid on every firing; an empty pool means no answer
    countersSpell = true,
}
