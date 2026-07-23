-- Trapper -- hunter subclass.
-- Signature mechanic: Hidden traps -- pre-place tile triggers (root/damage) that fire on enemy entry.
-- (ability_bear_trap is the first stock.)
-- Exemplar: a woodland ambusher (character_trapper, NEW -- pending), met as a BOSS.
-- Gate: one quest in the hunter (Lodge) line -- the_silent_wood. See docs/disciplines-plan.md.
return {
    name    = "Trapper",
    classes = { "hunter" },
    exemplar = "character_trapper", -- NEW, pending
    requiredQuests = { "the_silent_wood" },
}
