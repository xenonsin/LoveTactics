-- COCYTUS WING: Superbia's Fall for a person (reviewed over three rounds, "Pride's Generals"). The ring of tiles
-- around the caster freezes into Black Ice for three turns, and anyone who crosses it is Crippled
-- (hazard_black_ice). The caster's own tile stays clear.
--
-- An Elementalist's cast: ground laid around the body that laid it, so the mage is the one standing in the middle
-- of a field nobody wants to walk across. The ice has no allegiance -- it cripples the caster's own line too.
--
-- `unstocked`: a trophy, seen on the rack and never sold (docs/drops.md).
local ICE_TICKS = 15 -- three turns at Status.TICKS_PER_TURN (5); a literal, since status.lua loads after items

return {
    name = "Cocytus Wing",
    description = "Freeze the tiles in a ring around you: Black Ice for 3 turns.",
    flavor = "The last thing she did with her wings was fold them. The lake has not thawed since.",
    sprite = "assets/items/ability_cocytus_wing.png",
    type = "ability",
    tags = { "magical", "ice" },
    class = "elementalist",
    unlockLevel = 13,
    unstocked = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        support = true, -- it lands no damage
        cost = { stat = "mana", amount = 10 },
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                if not (c.x == fx.user.x and c.y == fx.user.y) then
                    fx.placeHazard(c.x, c.y, "hazard_black_ice", { duration = ICE_TICKS })
                end
            end
        end,
    },
}
