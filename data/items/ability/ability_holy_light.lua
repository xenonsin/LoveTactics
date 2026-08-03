-- Holy Light: a pillar of searing light over a 3x3 area, burning every ENEMY caught within with holy
-- (magical) damage. Unlike the mage's elemental blasts it spares allies standing in the light -- the
-- priest's one offensive spell, meant to be dropped into a knot of foes without fear of the party.
-- A ground-target area cast; hostile, so its footprint previews red.
local Curve = require("models.curve")

return {
    name = "Holy Light",
    description = "Sears enemies in area.",
    flavor = "The one spell the Cathedral trusts a priest to drop into a crowd.",
    sprite = "assets/items/ability_holy_light.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "priest",
    price = 340,
    unlockQuests = 6,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 3,
        speed = 4,
        windup = 6, -- the pillar gathers before it falls; enemies can scatter from the light
        cost = { stat = "mana", amount = 12 },
        damage = Curve.ramp(7), -- per-enemy damage = power + the caster's MagicDamage, minus MagicDefense
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
