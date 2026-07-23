-- The Alchemist's entry-rank arm, and envy's plainest statement: a thin blade whose whole purpose is to
-- get something else inside you. A dagger, so it owes the family's quickness (docs/weapons.md) -- but it
-- is the one dagger that does NOT bleed, and that omission is the weapon.
--
-- A knife cuts. This one is a delivery mechanism, and the Alchemist would tell you the distinction
-- matters. Where data/items/weapon/weapon_iron_dagger.lua opens a wound and lets the victim's own
-- movement do the work, this opens nothing worth mentioning and leaves Poison behind instead: a clock
-- that runs whatever the victim does about it. Bleed is a question the victim gets to answer by standing
-- still; Poison is not a question.
--
-- Declining the family's defining mechanic is a deviation, and the contract asks that a deviation be a
-- decision said out loud rather than a drift -- so: this is the shelf where the blade is the cheap part.
-- data/items/weapon/weapon_envenomed_kris.lua is where the two ideas are finally bought together.
return {
    name = "Apothecary's Lancet",
    description = "Deals light damage and inflicts Poison, which burns on however the victim moves.",
    flavor = "The Alchemist calls it a delivery mechanism. It is, in fairness, a very small knife.",
    sprite = "assets/items/apothecarys_lancet.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "poison", "melee" },
    class = "alchemist",
    price = 90,
    -- Rank 1, and it must stay there: the Lancet is the ALCHEMIST shelf's entry weapon, and
    -- tests/class_spec.lua refuses a vendor that cannot arm a newcomer. The rank ladder is a property of
    -- a shelf, not of a family -- the dagger family spans two shelves, so it climbs 1/3/5 on the rogue's
    -- (Iron Dagger, Cutpurse, Throughline) and 1/4 on the alchemist's (this, Envenomed Kris), and each
    -- of those starts at 1 because `repRank` gates standing with one vendor rather than mastery of a
    -- weapon type.
    repRank = 1,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, as every dagger is
        cost = { stat = "stamina", amount = 5 },
        damage = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 }, -- the lightest blade in the game: it is not the point
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_poison")
        end,
    },
}
