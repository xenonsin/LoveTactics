-- FLOWWALKER'S SOLES: the Blaze's Of the Flows, walking half only (models/storm.lua; "Fire, Lightning, and Dirty
-- Thunder", 2026-09-27), and one of the three things it drops. The bearer walks lava as ground and may end a move
-- on it -- the author's note on the row ("standing in lava is okay") -- which is the Blaze's own rule without the
-- mending. Nothing else in the game crosses lava but a flier.
--
-- The `lavawalk` tag and nothing more: Combat.isLavaborn reads it off the grid as `swim` is read for a naga. A
-- Skirmisher's, because it is a way in and a way out that nobody else on the board has.
return {
    name = "Flowwalker's Soles",
    description = "You walk lava as if it were ground, and may stand in it.",
    flavor = "The soles are the easy part. It is the feet that have to believe it.",
    sprite = "assets/items/utility_flowwalkers_soles.png",
    type = "utility",
    tags = { "lavawalk" },
    class = "skirmisher",
    unlockLevel = 7,
    unstocked = true,
}
