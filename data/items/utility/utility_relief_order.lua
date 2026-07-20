-- Quest reward, slot 7 of the Bastion's line (data/quests/the_order_given.lua) -- THE TURN. The
-- relief order cut for Greywatch, out of the archive and out of its seal: issued the nineteenth,
-- for a gate that was opened from the inside on the fourteenth.
--
-- Five days. There was no window to miss and no battle to arrive at, which means Rowan is innocent,
-- which is the one thing she cannot accept (docs/story.md, "Rowan"). The player is holding the proof
-- for the rest of the game.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth
-- (docs/classes.md, "class without price"). No `traits` -- see utility_closed_entry.lua on why only
-- four of the ten carry a rule.
--
-- The two dates live in `flavor`, not `description`, per docs/item-text.md: a player who reads only
-- descriptions must lose no mechanical information, and a player who reads only flavor must learn
-- the world. This is the second kind of line and it is the most load-bearing one in the game.
return {
    name = "The Relief Order, Unsealed",
    description = "Grants bonus defense and magic defense.",
    flavor = "Issued the nineteenth, countersigned by two hands. The gate was opened on the " ..
        "fourteenth. There was nothing to be late for.",
    sprite = "assets/items/relief_order.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    --                       level:  0  1  2  3  4  5  6  7  8  9  10
    bonus = { defense =      { 2, 2, 3, 3, 3, 4, 4, 5, 5, 5, 6 },
              magicDefense = { 2, 2, 3, 3, 3, 4, 4, 5, 5, 5, 6 } },
}
