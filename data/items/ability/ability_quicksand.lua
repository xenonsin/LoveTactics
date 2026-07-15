-- Quicksand: the mage churns a 3x3 patch of ground into sucking sand (data/hazards/hazard_quicksand.lua).
-- Any unit standing on it is Mired -- the opposite of Haste, doubling the time its steps and casts cost --
-- until it wades clear. Pure area denial: no damage, but it bogs down an advance and funnels foes onto
-- firmer ground (the enemy AI reads the sand as hostile and steps around it). A ground-target area cast.
return {
    name = "Quicksand",
    description = "Churn an area into quicksand: units within move and act at double the time cost.",
    sprite = "assets/items/ability_quicksand.png",
    type = "ability",
    tags = { "earth", "magical" },
    class = "mage",
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- an area cast may center on an occupied tile
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        aoe = { radius = 1, shape = "square" }, -- 3x3 patch of churned ground
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_quicksand")
            end
        end,
    },
}
