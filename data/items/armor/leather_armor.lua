-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag (e.g. a "slash" attack).
return {
    name = "Leather Armor",
    description = "Boiled hide that turns aside a glancing blade. Medium armor: -1 movement.",
    sprite = "assets/items/leather.png",
    type = "armor",
    -- Medium tier: modest bulk, one square slower.
    bonus = { defense = 4, movement = -1 },
    resist = { slash = 3, physical = 2 },
}
