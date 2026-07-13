-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag (e.g. a "slash" attack).
return {
    name = "Leather Armor",
    description = "Boiled hide that turns aside a glancing blade. Medium armor: -1 movement.",
    sprite = "assets/items/leather.png",
    type = "armor",
    -- Medium tier: modest bulk, one square slower. Defense and resists are per-level tables (levels
    -- 0..10) the forge steps up; the movement penalty is flat (a single number never scales).
    --                  level:  0  1  2  3  4  5  6  7  8  9  10
    bonus = {
        defense = { 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
        movement = -1,
    },
    resist = {
        slash    = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
        physical = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 },
    },
}
