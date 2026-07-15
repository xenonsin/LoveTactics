-- Holy Light: a pillar of searing light over a 3x3 area, burning every ENEMY caught within with holy
-- (magical) damage. Unlike the mage's elemental blasts it spares allies standing in the light -- the
-- priest's one offensive spell, meant to be dropped into a knot of foes without fear of the party.
-- A ground-target area cast; hostile, so its footprint previews red.
return {
    name = "Holy Light",
    description = "Sear enemies in an area with holy light. Allies within are unharmed.",
    sprite = "assets/items/ability_holy_light.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "priest",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 3,
        speed = 4,
        channel = 3, -- the pillar gathers before it falls; enemies can scatter from the light
        cost = { stat = "mana", amount = 12 },
        damage = { 7, 8, 8, 9, 10, 11, 11, 12, 13, 13, 14 }, -- per-enemy damage = power + the caster's MagicDamage, minus MagicDefense
        aoe = { radius = 1, shape = "square" }, -- 3x3 pillar
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.damage(u)
                end
            end
        end,
    },
}
