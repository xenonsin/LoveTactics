-- The Beastlord's Bond: a braided cord of hair, feather and hide worn at the throat, carrying the trait
-- of the same name (data/traits/trait_beastlords_bond.lua). While it is in the grid, every creature the
-- bearer has fielded and that is standing within three tiles is healed a little each time the bearer
-- acts.
--
-- It answers the one thing every conjuring build actually loses to, which is not damage but ATTRITION.
-- A summoned body arrives, does its work, and is whittled down by chip damage, hazards and area fire
-- until it winks out -- and the only existing answer is to spend another turn and another reservation
-- calling a replacement. This makes the menagerie you already have worth keeping alive.
--
-- IT DOES NOT KNOW WHAT A BEAST IS. The rule is written against `summoned`, so it heals the
-- Beastmaster's wolf and hawk and the Summoner's elementals identically. An item can only carry ONE
-- discipline (docs/classes.md), so its home is the Lodge's shelf and its `class` is hunter -- but a
-- mage-side conjurer who has cleared the Beastmaster gate can buy it and get exactly the same effect,
-- which is the "anyone carries anything" rule doing the work it exists to do. It is the one charm on
-- either shelf that is worth more the more shelves your build is standing on.
--
-- The cost is the grid slot and the leash. It grants no stats, nothing at all in a fight you field
-- nothing in, and nothing for creatures you have walked away from -- the bond reaches as far as you can
-- keep them, and a handler who abandons the pack is carrying a dead cord.
return {
    name = "Beastlord's Bond",
    description = "Each time you act, creatures you have summoned within 3 tiles are healed.",
    flavor = "Braided from the pack itself. The Lodge will not tell you which parts, and you will not ask twice.",
    sprite = "assets/items/beastlords_bond.png",
    type = "utility",
    tags = { "charm", "beast" },
    class = "hunter",
    discipline = "beastmaster", -- deeper cut of the shelf: buyable only once the beastmaster gate is cleared
    price = 345,
    unlockQuests = 2,
    traits = { "trait_beastlords_bond" },
}
