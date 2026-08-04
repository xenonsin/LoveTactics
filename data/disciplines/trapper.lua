-- Trapper -- hunter subclass.
-- Signature mechanic: Hidden traps -- pre-place tile triggers (root/damage) that fire on enemy entry.
-- (ability_bear_trap is the first stock.)
-- Exemplar: a woodland ambusher (character_trapper, NEW -- pending), met as a BOSS.
-- Gate: one quest in the hunter (Lodge) line -- the_silent_wood. See docs/disciplines-plan.md.
return {
    name    = "Trapper",
    description = "The ambusher. Pre-places tile triggers that root or wound whoever walks into them.",
    classes = { "hunter" },
    exemplar = "character_trapper_ambusher", -- character_trapper is the Colosseum debut spotter; dedicated exemplar authored
    requiredQuests = { "quest_hunters_lodge_slot_05" },
}
