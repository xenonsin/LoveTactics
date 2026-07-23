-- Roaring: the marker the Demon Champion's phase system raises at 66% health
-- (data/traits/trait_boss_phases.lua, seeded by data/items/utility/utility_demon_sigil.lua). It grants
-- nothing on its own -- it is a flag the Champion's AI reads (its `has_status`/`self` cast rule) so it
-- only ever winds up the Roar once the second stage of the fight has begun, and never in the opening.
-- Cleared when the fight moves on to the enrage stage at 33%.
--
-- Not a debuff (nothing to Cure), and its countdown is meaningless -- it lasts the stage, not a timer.
return {
    name = "Roaring",
    abbr = "Ror",
    description = "Drawing breath to call the horde. Break its concentration.",
    color = { 0.85, 0.35, 0.15 }, -- badge tint (ember orange)
    duration = 999,
    hideDuration = true,
    debuff = false,
}
