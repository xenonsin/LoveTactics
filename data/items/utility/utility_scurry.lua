-- SCURRY: the Kobold Skulker's footwork, and the drop off it (reviewed 2026-09-24/25, "The Kobolds of
-- Greed"). Round 2 took Keno's note on the round-1 piece -- "Too similar to wolf, I like it but add
-- something" -- and added HARRY: the step back is In and Out's, and the foe it leaves is Harried (-3
-- Defense until the next blow lands). A disengage that sets up whoever acts next (trait_scurry).
--
-- An unstocked trophy (tests/discovery_spec.lua's named TROPHIES), found on Greed's floors. The
-- skirmisher's shelf, beside In and Out, which is the half of it without the harry.
return {
    name = "Scurry",
    description = "After a melee blow lands, step back one tile, and inflict Harried on the foe you struck.",
    flavor = "Bite, back off, and let the next one bite. Nobody taught them that. Nobody had to.",
    sprite = "assets/items/utility_scurry.png",
    type = "utility",
    tags = { "trinket" },
    class = "skirmisher",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_scurry" },
}
