-- A censer, so the smoke is the weapon (docs/weapons.md): a square of ground around the bearer, lifted
-- and laid again wherever they walk (Combat.layIncense). Its cloud is hazard_muster -- allies standing in
-- it are braced, and enemies standing in it are left open.
--
-- The only zone in the game that does both jobs from one square, which is what earns it the rung. Every
-- other cloud on the shelf picks a side: incense blesses your line, choking smoke poisons theirs. This one
-- is a single fact about the ground that reads as a buff or a debuff depending on who is standing in it --
-- so a priest walking into a melee helps the people they are standing with and hurts the people they are
-- standing against, without having to aim anything.
--
-- Which makes it the aggressive censer, and the one that wants the priest at the front. The blessing
-- censer rewards allies who come to you; this rewards you going to them.
local Curve = require("models.curve")

return {
    name = "Censer of the Mustered Field",
    description = "Braces adjacent allies and inflicts Exposed on adjacent foes.",
    flavor = "The Cathedral swings it at the head of a column. Nobody has ever been sure whether that is a blessing or a threat.",
    sprite = "assets/items/censer_mustered.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "melee" },
    class = "priest",
    price = 560,
    unlockQuests = 8,
    incense = {
        hazard = "hazard_muster",
        radius = 1, -- the 3x3 the priest stands in the middle of; radius never scales with the forge
        amount = Curve.ramp(3, 13),
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(10, 20), -- feeble on purpose: the smoke is the weapon
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
