-- THE YEARLING PELT: the chase, and the only piece on this list that is not taken off the sow.
--
-- It is the CUB's. That is the item, and it is the reason the mechanic reads without a line of
-- explanation: you are carrying the thing she would not leave, and it does to you what losing it did to
-- her. The Unseeing's list is named on the same rule -- for the THING that explains the rule rather than
-- for the rule itself (utility_the_iron_in_him is a shot somebody left in an animal) -- and this is the
-- sharpest case of it in the game, because the object and the trigger are the same fact.
--
-- WHICH ALSO MEANS THE FIGHT CAN REFUSE TO PAY IT. The cub does not always die: a company that leaves it
-- standing and kills her first watches it walk off the board (trait_orphaned), and there is no pelt.
-- Nothing in the code enforces that -- Spoils reads the body that fell -- it simply follows from her
-- being the one who dropped and the cub being the one who left. The chase is the piece you only get by
-- taking the road the fight was built to make you think twice about.
--
-- DEEPEST ON THE LIST, which is the whole of its drop-rate design. A floor picks a rank before it looks
-- at who died (Spoils.rankBand), so an item only drops on floors that reach its own tier and the ORDER
-- of the three numbers is the rarity -- there is no per-entry weight to author. Hide 4, claw 6, pelt 8:
-- the same ladder the Unseeing's three stand on, because it is the same kind of body on the same road.
return {
    name = "The Yearling Pelt",
    description = "Grants Bereft.",
    flavor = "She had a year in it. You have whatever is left of this fight.",
    sprite = "assets/items/utility_the_yearling_pelt.png",
    type = "utility",
    tags = { "trophy", "beast" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS: the house whose whole subject is what a company does
    -- once it has started losing people. `class` is the vendor shelf and never an equip gate -- anyone
    -- may carry it.
    class = "warlord",
    dropTier = 8,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    traits = { "trait_bereft" },
}
