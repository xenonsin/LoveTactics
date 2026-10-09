-- MOUNTAIN'S ROOT: the dwarf bulwark's race item (data/items/utility/utility_mountains_root.lua, "The Rift's
-- Adventurers", slice D). Stout's two refusals -- no shove, no theft -- reached out one tile to the line.
--
-- A FLAG AND NO HOOK, for the reason trait_nothing_to_hold's header gives: being moved and being robbed are
-- questions the engine asks at its own seams (Status.blocksForcedMove, Combat.steal, Combat.strip), and a
-- second answer kept in a hook would drift from the first. models/race_items.lua's `rooted` is the one
-- reader; it counts the bearer and every ally standing beside it, and a Sundered bearer holds nobody.
return {
    name = "Mountain's Root",
    description = "You cannot be moved or robbed, and neither can allies beside you.",
    mountainsRoot = true,
}
