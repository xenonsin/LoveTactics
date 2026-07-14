-- A spear's innate reach: it strikes the TWO tiles directly in front of the wielder at once, skewering
-- whatever stands in the line. Like the greataxe's cleave (data/items/weapon/crimson_greataxe.lua) the
-- attack IS the weapon -- a weapon carrying a tile-target line footprint rather than a single adjacent
-- jab. Range 1 aims the tile in front, which sets the direction the thrust travels. Every spear built
-- from here should keep this 2-tile line: it is the defining trait of the spear.
return {
    name = "Spear",
    description = "A long thrust that spits the two tiles directly in front of you.",
    sprite = "assets/items/spear.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2, -- a two-handed polearm (Dual Wield can pair it only once forged to +5)
    class = "fighter",
    price = 140,
    repRank = 2,
    activeAbility = {
        name = "Thrust",
        target = "tile",       -- aim an adjacent tile: it sets the direction the thrust runs
        allowOccupied = true,  -- the first tile may hold a foe -- the thrust starts there and drives on
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the wielder's own tile
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 }, -- per-target damage = power + the wielder's Damage, minus Defense
        aoe = { shape = "line", length = 2 }, -- two tiles in a straight line away from the wielder
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
