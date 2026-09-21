-- Trapper -- hunter subclass.
-- Signature mechanic: Hidden traps -- pre-place tile triggers (root/damage) that fire on enemy entry.
-- (ability_bear_trap is the first stock.)
-- Exemplar: a woodland ambusher (character_trapper, NEW -- pending), met as a BOSS.
-- Gate: one quest in the hunter (Lodge) line -- the_silent_wood. See docs/disciplines-plan.md.
return {
    name    = "Trapper",
    description = "Prepares the ground before the fight reaches it. Traps are placed on tiles in advance "
        .. "and inflict Root or damage on whoever walks in.",
    exemplar = "character_trapper_ambusher", -- character_trapper is the Colosseum debut spotter; dedicated exemplar authored
    requires = { hunter = 7 },
}
