-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag (e.g. a "slash" attack).
return {
    name = "Leather Armor",
    description = "Light protection against slashing blows.",
    sprite = "assets/items/leather.png",
    type = "armor",
    bonus = { defense = 4 },
    resist = { slash = 3, physical = 2 },
}
