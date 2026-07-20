-- Quest reward, slot 4 of the Bastion's line (data/quests/the_long_list.lua). The captain's entry,
-- struck through and initialled -- the order's paperwork for a man it has just had killed, handed
-- over as though it were a commendation.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth
-- (docs/classes.md, "class without price").
--
-- No `traits`. Only four items in the ten carry a rule -- the Relief Horn, the Muster Roll, the
-- Struck Name and the Pike -- because the 3x3 grid cannot hold ten passives and a mandatory item is
-- homework. This is a plain defense bonus a better shelf piece may honestly replace, and that is the
-- point of it: the line hands you ten things and only four of them ask for a cell forever.
return {
    name = "The Closed Entry",
    description = "Grants bonus defense.",
    flavor = "A name on the long list, struck through and initialled twice. The order files a killing " ..
        "the way it files a leave request.",
    sprite = "assets/items/closed_entry.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    --                  level:  0  1  2  3  4  5  6  7  8  9  10
    bonus = { defense = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 } },
}
