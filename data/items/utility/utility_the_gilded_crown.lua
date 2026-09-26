-- THE GILDED CROWN: the first of the Gilded King's two trophies (2026-09-26, approved as written). The bearer
-- opens every fight GILDED (data/status/status_gilded.lua, through `openingBoon`): +3 Defense at the bell,
-- slower until it wears off, and COVETED -- every living dwarf's rules read `targetPref = "gilded"`, so in a
-- dwarf fight the whole line comes for the crown first.
--
-- So it is a tank's opening on a floor without dwarves and a lure on a floor with them: the player chooses
-- who eats the charge by choosing who wears it. Nothing else on it -- the crown is the status.
--
-- Unstocked (tests/discovery_spec.lua's TROPHIES): seen on the bulwark's rack, never sold.
return {
    name = "The Gilded Crown",
    description = "You open every fight Gilded.",
    flavor = "It was the last thing he could still put on. It is heavier than it looks.",
    sprite = "assets/items/utility_the_gilded_crown.png",
    type = "utility",
    tags = { "trinket" },
    class = "bulwark",
    unlockLevel = 6,
    unstocked = true,
    openingBoon = { id = "status_gilded" },
}
