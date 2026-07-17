-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag (here, "magical").
return {
    name = "Silk Robes",
    description = "Light armor. Drinks in hostile magic, but little against steel.",
    flavor = "The Arcanum dresses its own in silk and calls it discipline.",
    sprite = "assets/items/silk_robes.png",
    type = "armor",
    class = "mage",
    price = 170,
    repRank = 2,
    -- Light tier for casters: little against steel, strong against spells.
    bonus = { magicDefense = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 } },
    resist = { magical = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
}
