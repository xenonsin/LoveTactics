-- Quest reward, slot 2 of the Bastion's line (data/quests/turned_back.lua). The Road-Captain's own
-- list: the nineteen who walked out of Greywatch with nothing rather than take Acedia's terms.
--
-- THE ARITHMETIC IS THE POINT, and it is laid across three quests for the player to do before Rowan
-- ever does. This roll says nineteen. Slot 5 hands over the Greywatch Muster Roll -- forty-one names,
-- which the order recites as martyrs (data/items/utility/utility_greywatch_muster_roll.lua). Slot 9
-- says what the forty-one actually counts: not days held, but the ones who said yes, one mark each.
--
-- Sixty men held that gate. Forty-one took the terms. Nineteen refused and were struck off the rolls
-- so the story would stay tidy. The Bastion commemorates the forty-one. It has never once read these
-- names aloud, and the only copy in the world was in a bandit's coat.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth
-- (docs/classes.md, "class without price"). No `traits` -- only four items in the ten carry a rule;
-- see data/items/utility/utility_closed_entry.lua for why.
--
-- The number lives in `flavor`, never in `description` (docs/item-text.md): a player who reads only
-- descriptions must lose no mechanical information, and this is not mechanical information. It is
-- the whole line, sitting in a tooltip, four quests early.
return {
    name = "The Names He Kept",
    description = "Grants bonus defense and stamina.",
    flavor = "Nineteen names in a dead man's coat, copied out by hand and carried fifteen years. " ..
        "The order has never read one of them aloud.",
    sprite = "assets/items/names_he_kept.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    --                       level:  0  1  2  3  4  5  6  7  8  9  10
    bonus = { defense = { 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6 },
              stamina = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 } },
}
