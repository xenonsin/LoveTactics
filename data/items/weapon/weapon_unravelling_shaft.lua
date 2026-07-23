-- A bow, so it shoots at range with a dead point-blank band (docs/weapons.md). Its extra is the ground it
-- picks loose: where the shaft lands, hazard_unravelling is left behind, and everything standing in it
-- takes more from every magical hit.
--
-- Quest-only: `class` with no `price`.
--
-- The archer's contribution to somebody else's damage, delivered from further away than the somebody else
-- can reach. A mage's whole problem is range and exposure -- the Arcanum's shelf is full of things that
-- must be aimed from inside the fight -- and this lays the mage's setup for them from the back line, on a
-- square of the archer's choosing, several turns before the mage arrives.
--
-- It is the longest-reaching setup tool in the game, and unlike a status it does not travel with the
-- victim: the enemy can simply walk out of it. That is the trade. A debuff follows the body and this
-- follows the ground, so it is worth more against a line that has to hold a position and worth almost
-- nothing against skirmishers.
--
-- Unsided, and this one bites: your own line standing in it takes the extra magical damage too, which
-- against an enemy caster is a real way to lose people. It is a zone for the enemy's half of the board.
return {
    name = "The Unravelling Shaft",
    description = "Fires at range and picks the ground loose where it lands: everything standing there takes more from magic.",
    flavor = "The fletching is somebody's unpicked stole. The Cathedral has asked about this twice.",
    sprite = "assets/items/unravelling_shaft.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 7 },
        -- Under an iron bow's: this weapon's output is measured on the mage's turn, not on the archer's.
        damage = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
        effect = function(fx)
            fx.damage(fx.target)
            -- On the aimed cell rather than the body, for the reason weapon_witchlight_bow gives: the
            -- ground is the weapon, and it has to outlast whoever was standing on it.
            fx.placeHazard(fx.tx, fx.ty, "hazard_unravelling", { duration = 10 + fx.level })
        end,
    },
}
