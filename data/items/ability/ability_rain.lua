-- Rain: the mage calls down a downpour over an area, leaving a Rain hazard on every tile in the
-- blast (data/hazards/hazard_rain.lua). Units that enter it are left Wet -- vulnerable to lightning
-- -- so the classic follow-up is a Jolt into the soaked cluster. Being water-tagged, the cast also
-- douses any fire it falls on (see Combat.useItem's water-douse). A ground-target area cast
-- (target = "tile", allowOccupied): aim at any walkable cell in range, occupied or not.
return {
    name = "Rain",
    description = "Summon a downpour over an area, soaking those within (Wet: +lightning damage).",
    sprite = "assets/items/ability_rain.png",
    type = "ability",
    tags = { "water", "magical" },
    activeAbility = {
        name = "Rain",
        target = "tile",
        allowOccupied = true, -- an area cast may center on an occupied tile
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        aoe = { radius = 1, shape = "square" }, -- 3x3 downpour, corners included
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_rain")
            end
        end,
    },
}
