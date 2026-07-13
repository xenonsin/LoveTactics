-- Colosseum rank-4. The axe drinks what it spills: heavy, slow, and it hits harder the deeper
-- the fight goes. The Colosseum's masters do not say where the crimson comes from -- the first
-- hint that the arena's patron sin is Wrath, and that Wrath grows on damage taken.
return {
    name = "Crimson Greataxe",
    description = "A greataxe slick with a red that never dries. Devastating, and slow to swing.",
    sprite = "assets/items/crimson_greataxe.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "fighter",
    price = 800,
    repRank = 4,
    activeAbility = {
        name = "Cleave",
        target = "tile",       -- aim an adjacent tile: it sets the facing the arc sweeps
        allowOccupied = true,  -- the tile in front may hold a foe -- it's the centre of the arc
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the wielder's own tile
        speed = 6, -- ponderous: you pay for the damage in turn order
        cost = { stat = "stamina", amount = 16 },
        power = { 18, 20, 22, 23, 25, 27, 29, 31, 32, 34, 36 },
        aoe = { shape = "front", width = 3 }, -- axes cleave innately: a 3-wide arc in front
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
