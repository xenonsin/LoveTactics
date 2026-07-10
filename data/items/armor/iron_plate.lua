-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
return {
    name = "Iron Plate",
    description = "A wall of forged plate. Physical blows glance away. Heavy armor: -2 movement.",
    sprite = "assets/items/iron_plate.png",
    type = "armor",
    class = "fighter",
    price = 380,
    repRank = 3,
    -- Heavy tier: the most steel a body can carry, and it shows in the pace.
    bonus = { defense = 13, movement = -2 },
    resist = { physical = 4, slash = 4, pierce = 4 },
}
