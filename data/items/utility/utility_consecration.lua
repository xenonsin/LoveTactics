-- CONSECRATION: nothing takes hold of this body's kit (models/curse.lua's Curse.warded, docs/curses.md).
--
-- PREVENTION, WHICH IS NEITHER OF THE SYSTEM'S OTHER TWO VERBS. A Shaman manipulates and an Exorcist
-- ends; this stops a hex happening in the first place, and it is the only answer in the game that costs
-- neither a turn nor a fee. Traps, casts and the Touchstone's worst reveals all simply fail to land on
-- the body wearing it.
--
-- ASKED IN ONE PLACE. Curse.warded walks the bearer's grid and Combat.curseItem checks it before it even
-- looks for a cell -- so every vector in the game is refused by one clause rather than by four that
-- could drift, and the log says so out loud instead of reading as a run of bad luck.
--
-- IT COMPETES WITH THE COUNTING SHELF FOR THE SAME NINE CELLS, which is the decision it exists to
-- create. Ward the body or feed it: a cell spent on this is a cell not spent on The Gathered Weight, and
-- the two charms describe opposite companies. That is a better question than "is this good", and it is
-- the reason the ward is a charm rather than a rite.
--
-- THE SATCHEL IS NOT WARDED and cannot be -- a ward is worn by a BODY, and a hexed find sitting in the
-- stash has nobody wearing anything. Reading a bad husk at the Touchstone is still a gamble for
-- everybody, which keeps the identification bet intact.
return {
    name = "Consecration",
    description = "Nothing can lay a curse on this body's kit.",
    flavor = "Oil, salt, and a name said over each cell in turn. It takes most of a morning.",
    sprite = "assets/items/consecration.png",
    type = "utility",
    tags = { "charm", "holy" },
    class = "priest",
    unlockLevel = 2,
    curseWard = true,
}
