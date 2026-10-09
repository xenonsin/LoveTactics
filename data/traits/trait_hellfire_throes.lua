-- DEATH THROES (the Balor's fire): the Balor's rule, and the Bombardier's Last Breath once it is carried out
-- (data/items/utility/utility_balor_throes.lua, utility_last_breath.lua). Reviewed 2026-10-09 ("The Crown's
-- Bestiary", slice B).
--
-- When the bearer dies it explodes: `magnitude` fire to every body within `radius` of its whole footprint, its own
-- side included (models/crown_demons.lua's deathThroes). The counter is the review's own: finish it from range, or
-- bring it down in the middle of its own escort.
--
-- The Frost Worm's Death Throes freezes (trait_death_throes_frost); this one burns. onDeath, not onDamaged: the
-- killing blow never reaches onDamaged (trait_volatile argues the same).
return {
    name = "Death Throes",
    description = "When it dies, it explodes: fire damage to every body within 3, its own side included.",
    magnitude = 20,
    radius = 3,
    notAReaction = true,
    onDeath = function(ctx) require("models.crown_demons").deathThroes(ctx) end,
}
