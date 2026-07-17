-- Long-Fuse Reagent: a volatile primer with no ability of its own. Through the 3x3 item grid it
-- lengthens the THROW of the consumables sitting adjacent to it (diagonals included) -- a Fire Bomb
-- beside it reaches a tile further, turning a short lob into a real ranged option. Like every aura
-- charm it is dead weight alone; slot it next to the throwable you want to keep at arm's length.
--
-- See Combat.adjacencyRangeBonus -- the same bonus is folded into the range gate, the targeting
-- highlight, the target scan, and the AI, so the reach the charm promises is the reach the cast gets.
return {
    name = "Long-Fuse Reagent",
    description = "Adjacent consumables can be thrown one tile further.",
    flavor = "Dead weight on its own. Slot it beside the thing you would rather keep at arm's length.",
    sprite = "assets/items/long_fuse_reagent.png",
    type = "utility",
    tags = { "arcane" },
    class = "alchemist",
    price = 200,
    repRank = 2,
    aura = {
        appliesTo = { "consumable" }, -- only the throwables it sits beside
        rangeBonus = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 },               -- added to the neighbor consumable's ability range
    },
}
