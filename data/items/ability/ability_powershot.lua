-- Power Shot: brace a bow and loose a single overdrawn arrow that punches straight through a row of
-- foes -- four tiles in a line, everything on them skewered. It can only be loosed with a RANGED
-- weapon sitting adjacent to it in the 3x3 item grid (the arrow needs a bow to fire it); range 1
-- picks the tile in front, which sets the direction the shot travels. Combat.adjacencyMet gates the
-- cast and Combat.adjacencyLinks draws the connector line to the bow that satisfies it.
return {
    name = "Power Shot",
    description = "Looses an arrow piercing a line four tiles long. Needs an adjacent ranged weapon.",
    flavor = "The overdraw is the whole shot. The Lodge counts the bodies afterward, in a line.",
    sprite = "assets/items/ability_powershot.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the direction the line travels
        allowOccupied = true,  -- the first tile may hold a foe -- the arrow starts there and drives on
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the caster's own tile
        speed = 4,
        channel = 2, -- the overdraw takes two ticks to brace; hard control breaks the draw
        cost = { stat = "stamina", amount = 10 },
        damage = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 }, -- per-target damage = power + the caster's Damage, minus Defense
        aoe = { shape = "line", length = 4 }, -- four tiles in a straight line away from the caster
        requiresAdjacent = { type = "weapon", tag = "ranged" }, -- a ranged weapon must sit adjacent in the grid
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
