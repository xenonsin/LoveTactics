-- The Unwanted's fracture lines: the organ that cracks it open, and the floor around it with it.
--
-- AT EACH THRESHOLD IT CRACKS (trait_fracture_line; creature identity pass, 2026-11-19). Straight lines of glass
-- run three tiles out of each side of its body; every foe on a line is cut, and the lines are left as Glass
-- Shards (data/hazards/hazard_glass_shards.lua) that cut and strip whoever of the company ends a turn on them.
--
-- IT USED TO SHED GLASS-MOTES, a pair per threshold on trait_boss_phases -- which is The Long Winter's shape with
-- the drift-things swapped for motes, and the audit flagged the two apexes as one template (same-apex). The
-- Winter multiplies; the Unwanted now breaks the ground. Its bar is the telegraph: at two-thirds and at one-third,
-- do not be standing in line with a side of it. The old header's argument against splitting it into
-- character_homunculus_discard (cargo, never a combatant) is moot now that it splits into nothing at all.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Fracture Line",
    description = "At 2/3 and 1/3 health, cracks 3-tile lines from each side: 8 damage to foes on them, and Glass Shards.",
    flavor = "Cast in one piece, and not well. It has been coming apart since the day it cooled.",
    sprite = "assets/items/fracture_line.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_fracture_line" },
    cracks = { 0.66, 0.33 },
}
