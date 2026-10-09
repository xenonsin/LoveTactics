-- THE TRIBUNAL: a Death Knight, an Erinys and a Pit Imp, ordinary traffic on the Crown's floor ("The Crown's
-- Bestiary", slice B, approved 2026-10-09). The lesson is whom to kill first, and in what order: the imp dies
-- beside the knight and closes over it as a barrier, the Fury punishes whatever the company did to get there, and
-- the knight is the body every other answer runs through.
--
-- FIXED: three bodies, no band. The question is the order, and a fourth body would only lengthen the answer.
--
-- AND NO `rung`: the Crown is the one floor under all seven circles, so the ground is the pin (encounter_the_bone_
-- orchard.lua says why).
return {
    name = "The Tribunal",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = { "character_death_knight", "character_erinys", "character_pit_imp" },
}
