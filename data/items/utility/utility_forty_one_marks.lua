-- Quest reward, slot 9 of the Bastion's line (data/quests/forty_first_day.lua). A gatepost splinter
-- off Greywatch, forty-one strokes cut into it.
--
-- The order teaches the number as forty-one days held. It is not. It is forty-one people who said
-- yes, one mark each, cut by Acedia's own hand so that nobody could claim afterwards they had been
-- carried (data/conversations/bastion_forty_first_day_confront.lua). The same tally the Greywatch
-- Muster Roll's flavor already misreads at slot 5 -- the player has been carrying the wrong reading
-- for four quests by the time this arrives.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth
-- (docs/classes.md, "class without price"). No `traits` -- see utility_closed_entry.lua.
return {
    name = "Forty-One Marks",
    description = "Grants bonus damage.",
    flavor = "The order teaches it as forty-one days held. She cut them herself, one for each of " ..
        "them, so that no one could ever say they had been carried.",
    sprite = "assets/items/forty_one_marks.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    --                 level:  0  1  2  3  4  5  6  7  8  9  10
    bonus = { damage = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 } },
}
