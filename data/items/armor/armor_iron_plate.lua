-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
return {
    name = "Iron Plate",
    description = "Heavy armor. Physical blows glance away.",
    flavor = "The most steel a body can carry, and the Bastion will sell you every ounce of it.",
    sprite = "assets/items/iron_plate.png",
    type = "armor",
    class = "fighter",
    price = 380,
    repRank = 3,
    -- Heavy tier: the most steel a body can carry, and it shows in the pace.
    bonus = { defense = { 13, 14, 16, 17, 18, 20, 21, 22, 23, 25, 26 }, movement = -2 },
    resist = { physical = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 }, slash = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 }, pierce = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 } },
}
