-- Cleave: a single wide swing that carves the three tiles directly in front of the wielder at once.
-- It can only be swung with a MELEE weapon sitting adjacent to it in the 3x3 item grid (a cleave
-- needs an edge to swing); range 1 picks the tile in front, which sets the facing the arc sweeps.
-- Combat.adjacencyMet gates the cast and Combat.adjacencyLinks draws the connector to the weapon.
-- Axes swing this innately -- their own attack IS a cleave (see data/items/weapon/crimson_greataxe).
return {
    name = "Cleave",
    description = "A wide swing that carves a 3x1 arc in front of you. Requires an adjacent melee weapon.",
    sprite = "assets/items/ability_cleave.png",
    type = "ability",
    tags = { "slash", "physical" },
    class = "fighter",
    price = 300,
    repRank = 3,
    activeAbility = {
        name = "Cleave",
        target = "tile",       -- aim an adjacent tile: it sets the facing the arc sweeps
        allowOccupied = true,  -- the tile in front may hold a foe -- it's the centre of the arc
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the caster's own tile
        speed = 5,
        cost = { stat = "stamina", amount = 12 },
        power = 8, -- per-target damage = power + the caster's Damage, minus Defense
        aoe = { shape = "front", width = 3 }, -- a 3-wide arc perpendicular to the facing
        requiresAdjacent = { type = "weapon", tag = "melee" }, -- a melee weapon must sit adjacent in the grid
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
