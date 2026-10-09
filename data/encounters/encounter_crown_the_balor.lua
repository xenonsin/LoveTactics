-- THE BALOR: the great fire demon with a Chain Fiend and two Pit Imps, an elite on the Crown's floor ("The Crown's
-- Bestiary", slice B, approved 2026-10-09). The lesson is where it dies: its Death Throes strike every tile within 3,
-- its own side included, so the company finishes it from range -- or drops it in the middle of its own escort --
-- while the fiend's chain keeps hauling somebody into the ring.
--
-- FIXED, the review's own count: the escort is what the blast is dropped into, and it is pinned in
-- tests/encounter_spec.lua for that reason.
--
-- AND NO `rung`: the Crown is the one floor under all seven circles, so the ground is the pin (encounter_the_bone_
-- orchard.lua says why).
return {
    name = "The Balor",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = { "character_balor", "character_chain_fiend", "character_pit_imp", "character_pit_imp" },
}
