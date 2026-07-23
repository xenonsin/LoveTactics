-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- The first Beastmaster stock that is not a horn or a whistle: the wearer opens every battle with a
-- wolf beside them, free of any reservation (trait_wolf_companion). A whole extra body, delivered by
-- the armour slot -- which makes it, by some distance, the largest thing any single item in this game
-- hands a party at the opening bell.
--
-- Free of reservation is the load-bearing half. Every other summon in the catalog holds back a share
-- of its caster's pool for as long as it stands (models/summon.lua); this one costs nothing and holds
-- nothing, because it was never summoned -- it walked in with you. The price was paid at the kennel.
--
-- So the jerkin's own steel is nearly nothing, and should stay that way. What the wearer bought is a
-- second set of teeth on the board, and if it also made them hard to kill the Warren would sell
-- nothing else.
return {
    name = "Kennelbound Jerkin",
    description = "Start each battle with a wolf at your side, free of any reservation.",
    flavor = "The Warren does not lend animals. It decides, once, whether one will follow you.",
    sprite = "assets/items/armor_kennelbound_jerkin.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    traits = { "trait_wolf_companion" },
    bonus = { defense = { 2, 2, 3, 3, 4, 4, 4, 5, 5, 6, 6 } },
}
