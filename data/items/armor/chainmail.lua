-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
return {
    name = "Chainmail",
    description = "Interlocked rings that shrug off cuts and thrusts. Medium armor: -1 movement.",
    sprite = "assets/items/chainmail.png",
    type = "armor",
    class = "knight",
    price = 130,
    repRank = 1,
    -- Medium tier: better all-round steel than leather, still one square slower. Defense and resists
    -- are per-level tables (levels 0..10) the forge steps up; the movement penalty is flat.
    --                  level:  0  1  2   3   4   5   6   7   8   9  10
    bonus = {
        defense = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        movement = -1,
    },
    resist = {
        slash    = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
        pierce   = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
        physical = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 },
    },
}
