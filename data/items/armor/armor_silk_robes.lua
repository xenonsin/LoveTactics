-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag (here, "magical").
return {
    name = "Silk Robes",
    description = "Light armor. Drinks in hostile magic, but little against steel.",
    flavor = "The Arcanum dresses its own in silk and calls it discipline.",
    sprite = "assets/items/silk_robes.png",
    type = "armor",
    tags = { "cloth" },
    class = "mage",
    price = 170,
    repRank = 2,
    -- Light tier for casters: little against steel, strong against spells -- and a square of pace,
    -- because cloth costs one (see armor_padded_vest's header for why the light tier stopped being
    -- free, and tests/armor_spec.lua for the rule).
    bonus = { magicDefense = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 }, movement = -1 },
    resist = { magical = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
}
