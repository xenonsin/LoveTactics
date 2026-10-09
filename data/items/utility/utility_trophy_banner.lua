-- TROPHY BANNER: the orc warlord's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). A kill an
-- ally makes inside the field of a banner the bearer planted makes the BEARER Proven (trait_trophy_banner):
-- the warlord is credited with every head taken under its standard, which is an orc's idea of command.
--
-- Gated to orcs (Character.canCarry). No price: a rift find on the warlord's shelf at the class's floor.
return {
    name = "Trophy Banner",
    description = "When an ally inside your banner's field makes a kill, you become Proven.",
    flavor = "Every tusk on the pole was taken by somebody else, and the warlord remembers each one as its own.",
    sprite = "assets/items/utility_trophy_banner.png",
    type = "utility",
    tags = { "banner" },
    class = "warlord",
    race = "orc",
    unlockLevel = 3,
    traits = { "trait_trophy_banner" },
}
