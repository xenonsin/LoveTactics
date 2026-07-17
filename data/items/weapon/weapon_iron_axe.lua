-- The axe archetype: axes cleave (docs/weapons.md). Like data/items/weapon/weapon_crimson_greataxe.lua this
-- aims an adjacent TILE rather than a foe -- the aimed tile sets the facing, and the blow sweeps a
-- 3-wide arc perpendicular to it, hitting everything standing in the arc for full damage.
--
-- The entry-rank axe, and the one-handed one: where the greataxe is a two-handed capstone that trades
-- tempo for weight, the hatchet keeps a hand (and a grid slot) free and pays for its reach in raw
-- numbers instead -- per target it hits softer than an iron sword. It is worth carrying exactly when
-- there is more than one thing in front of you.
--
-- Note the arc does not care whose side it sweeps: fx.aoeUnits returns everyone in it, and this
-- effect filters nobody. Line your own people up behind the axe, not beside it.
return {
    name = "Iron Axe",
    description = "Cleaves a wide arc, cutting everything standing in front of you.",
    flavor = "The first axe anyone is handed. It asks only that you count what is in front of you before you swing.",
    sprite = "assets/items/hatchet.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "fighter",
    price = 110,
    repRank = 1,
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the facing the arc sweeps
        allowOccupied = true,  -- the tile in front may hold a foe -- it's the centre of the arc
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the wielder's own tile
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = { 5, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11 }, -- per target: softer than a sword, but it may hit three
        aoe = { shape = "front", width = 3 }, -- axes cleave innately: a 3-wide arc in front
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
