-- THE HEXBRAND: a staff, so it swaps Wait into Focus (docs/weapons.md) -- and its strike is the one
-- weapon in the game that lays a curse (models/curse.lua).
--
-- THE FAMILY CONTRACT IS THE POINT, NOT AN OBLIGATION. A staff's swap IS the weapon and the strike is a
-- deliberate afterthought, which is exactly the shape a hexing weapon wants: the hex is slow, cheap,
-- weak in damage and worth swinging for the rider alone. A shaman carrying this stands in the line,
-- meditates most turns, and occasionally reaches out and ruins something's sword.
--
-- IT NAMES NO HEX, so the shallow end of the ladder is rolled (Combat.curseItem's default) -- the same
-- reading ability_lay_the_hex takes and for the same reason. A weapon swings every turn it is not
-- Focusing, and a repeatable cast that could deal The Anchor would be a lock with no cost at all.
--
-- ONE HEX PER PIECE, WHICH MEANS THIS RUNS OUT. Curse.canAfflict refuses a piece that is already cursed,
-- so a brand swung at the same soldier over and over hexes its way through that grid and then finds
-- nothing -- and says so. That is a real ceiling and it is the right one: the weapon is a way to degrade
-- one body over a long fight, not a way to delete it.
local Curve = require("models.curve")

return {
    name = "The Hexbrand",
    description = "Replaces Wait with Focus, and every blow curses a piece of what it strikes.",
    flavor = "Charred at one end from the first thing it was asked to bind, which did not want to go.",
    sprite = "assets/items/hexbrand.png",
    type = "weapon",
    tags = { "staff", "magical", "dark", "melee" },
    class = "shaman",
    unlockLevel = 8,
    waitBehavior = {
        kind = "focus",
        mana = Curve.ramp(7, 18),
        speed = 10,
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(9, 20),
        effect = function(fx)
            fx.damage(fx.target)
            fx.curse(fx.target)
        end,
    },
}
