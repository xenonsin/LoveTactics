-- Sap: a blow struck not to kill but to TAKE. It deals a little damage and saps a bite of stamina out of
-- the target and into the thief's own reserves -- the wind knocked out of one body and into another.
-- Larceny read as a stat rather than an item (compare Pickpocket, which lifts the thing in their hand,
-- and Drain Mana, which siphons the caster's pool): the three are the Undercroft saying "an item, a stat,
-- a resource" in three verbs, and this is the stamina one.
--
-- The drain is a flat bite (8, plus one per forge level) held apart from the strike's own damage on
-- purpose: the damage rides the attack stat like any blow, but a THEFT is a fixed measure -- you take
-- what you take, not a share of how hard you hit. A foe already out of stamina yields nothing
-- (Combat.drainResource reports what it actually took, and fx.restore hands back exactly that), so the
-- blow still lands but the theft comes up empty against a spent foe -- the correct shape for a tool that
-- lives off other people having something to take.
local Curve = require("models.curve")

return {
    name = "Sap",
    description = "Deals damage and drains the target's stamina into your own.",
    flavor = "The Undercroft's first lesson in economy: a man too winded to swing is a man you have already robbed.",
    sprite = "assets/items/ability_sap.png",
    type = "ability",
    tags = { "guile", "utility" },
    class = "rogue",
    discipline = "thief", -- deeper cut of the shelf: buyable only once the thief gate is cleared
    price = 200,
    unlockQuests = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15), -- the strike itself, attack-stat scaled like any blow
        effect = function(fx)
            fx.damage(fx.target)
            local want = 8 + fx.level -- the theft: a flat bite of stamina, sharpened by the forge
            local taken = fx.drain(fx.target, "stamina", want)
            fx.restore(fx.user, "stamina", taken)
        end,
    },
}
