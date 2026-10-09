-- MOUNTAIN'S ROOT: the dwarf bulwark's race item ("The Rift's Adventurers", slice D, approved 2026-10-09 as its
-- own item with a hard race gate). Stout already holds a dwarf in place and keeps its grid shut; this reaches
-- the same two refusals out to every ally standing beside it (trait_mountains_root, models/race_items.lua) --
-- the bulwark's whole job, done by refusing to be anywhere else.
--
-- `race = "dwarf"` is the one equip gate in the game (Character.canCarry): no other body may carry it, a
-- company dwarf included only because it IS one. No price: a rift find, dealt from the bulwark's shelf at the
-- class's own floor (Adventurers.floorOf), and carried by every dwarf bulwark the rift fields.
return {
    name = "Mountain's Root",
    description = "You cannot be moved or robbed, and neither can allies beside you.",
    flavor = "Stand close enough to a dwarf and the mountain stops moving for anyone.",
    sprite = "assets/items/utility_mountains_root.png",
    type = "utility",
    tags = { "charm" },
    class = "bulwark",
    race = "dwarf",
    unlockLevel = 3,
    traits = { "trait_mountains_root" },
}
