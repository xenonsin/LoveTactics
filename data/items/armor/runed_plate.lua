-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
return {
    name = "Runed Plate",
    description = "Plate etched with warding sigils, proof against blade and spell alike. Heavy armor: -2 movement.",
    sprite = "assets/items/runed_plate.png",
    type = "armor",
    class = "knight",
    price = 400,
    repRank = 3,
    -- Heavy tier: trades a little raw steel for a genuine guard against magic.
    bonus = { defense = 10, magicDefense = 6, movement = -2 },
    resist = { physical = 3, magical = 3 },
}
