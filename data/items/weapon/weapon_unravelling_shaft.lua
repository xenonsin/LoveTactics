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
--
-- It aims a TILE (`target = "tile"`, `allowOccupied`) and not a body, for the reason
-- data/items/weapon/weapon_deadfall_bow.lua does: a weapon whose sale is the square it leaves behind
-- cannot be restricted to squares somebody is already standing on. The whole use -- lighting the doorway
-- the enemy has to come through, several turns before the mage arrives -- is a shot at empty ground, and
-- as an `enemy`-target ability it was the one shot this bow could not take. Occupied cells stay legal
-- because the arrow is still an arrow: loose it at a body and the shaft goes through them and the ground
-- under them is picked loose all the same.
local Curve = require("models.curve")

return {
    name = "The Unravelling Shaft",
    description = "Leaves Unravelling ground where it lands.",
    flavor = "The fletching is somebody's unpicked stole. The Cathedral has asked about this twice.",
    sprite = "assets/items/unravelling_shaft.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "tile",       -- the square, not the body: the ground is what is being bought
        allowOccupied = true,  -- and a square somebody is standing on is still a square (see above)
        range = 3,
        minRange = 2,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 7 },
        -- Under an iron bow's: this weapon's output is measured on the mage's turn, not on the archer's.
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            -- Nobody there on an empty-ground shot, and that is the intended shot: fx.damage takes the
            -- nil and reports nothing rather than throwing, so the hazard below is the whole cast.
            fx.damage(fx.target)
            -- On the aimed cell rather than the body, for the reason weapon_witchlight_bow gives: the
            -- ground is the weapon, and it has to outlast whoever was standing on it.
            fx.placeHazard(fx.tx, fx.ty, "hazard_unravelling", { duration = 10 + fx.level })
        end,
    },
}
